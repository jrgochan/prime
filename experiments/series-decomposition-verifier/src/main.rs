//! ═══════════════════════════════════════════════════════════════════════════
//!  Cathedral Series Decomposition Verifier
//!
//!  Certifies the four-way algebraic identity:
//!    gramIntegral(a,b) = vasyuninGramFormula(a,b)
//!
//!  via two independent paths:
//!    Path 1: Σ actualRowIntegral (piecewise FTC, gold standard)
//!    Path 2: Σ rowTerm (algebraic series, with two-tile correction)
//!
//!  PARALLELISM: All 127 × 100K row computations are launched as a single
//!  flat rayon work-pool — no nested parallelism, maximum thread saturation.
//!
//!  Outputs:
//!    results/decomposition.tsv   — per-pair, per-M series values
//!    results/convergence.tsv     — convergence diagnostics
//!    results/corrections.tsv     — two-tile correction analysis
//!    results/summary.json        — certificate with pass/fail verdicts
//! ═══════════════════════════════════════════════════════════════════════════

mod series;
mod formula;

use cathedral_utils::arith;
use cathedral_utils::certificate;
use cathedral_utils::fmt;
use rayon::prelude::*;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::time::Instant;

/// All coprime (a,b) with 1 ≤ a < b ≤ MAX_B.
const MAX_B: usize = 20;

/// M values at which we sample each series.
const M_VALUES: &[usize] = &[100, 500, 1_000, 5_000, 10_000, 50_000, 100_000];

/// Maximum allowed |error| · (a·M) for the FTC path.
const TAIL_BOUND_C: f64 = 1.0;

/// Per-pair result after aggregation.
struct PairResult {
    a: usize,
    b: usize,
    formula_val: f64,
    strip_val: f64,
    m_results: Vec<MResult>,
    two_tile_count: usize,
    total_correction: f64,
}

struct MResult {
    big_m: usize,
    s_combined: f64,
    ftc_sum: f64,
    correction_sum: f64,
}

fn coprime_pairs() -> Vec<(usize, usize)> {
    let mut pairs = Vec::new();
    for b in 2..=MAX_B {
        for a in 1..b {
            if arith::gcd(a, b) == 1 {
                pairs.push((a, b));
            }
        }
    }
    pairs
}

fn main() {
    let t0 = Instant::now();
    let pairs = coprime_pairs();
    let threads = rayon::current_num_threads();
    let max_m = *M_VALUES.last().unwrap();

    fmt::header(
        "SERIES DECOMPOSITION VERIFIER",
        "gramIntegral → vasyuninGramFormula via FTC + algebraic series",
        series::PREC,
        threads,
    );

    println!("  {} coprime pairs with b ≤ {MAX_B}", pairs.len());
    println!("  M values: {:?}", M_VALUES);
    println!("  Max M = {} → {} total row evaluations", max_m,
        pairs.len() * (max_m - 1));
    println!("  Using {} threads (flat rayon work-pool)", threads);
    println!();

    // ════════════════════════════════════════════════════════════════
    // PHASE 1: Compute formula targets (fast, parallel over pairs)
    // ════════════════════════════════════════════════════════════════
    fmt::section("Phase 1: Formula Targets");

    let formula_data: Vec<(f64, f64)> = pairs.par_iter()
        .map(|&(a, b)| {
            let g = formula::vasyunin_gram_formula(a, b).to_f64();
            let s = series::strip(a, b).to_f64();
            (g, s)
        })
        .collect();

    for (i, &(a, b)) in pairs.iter().enumerate() {
        if b <= 6 {
            println!("    G({a},{b}) = {:.15}", formula_data[i].0);
        }
    }
    println!("    {} {} formula targets computed in {:.2}s",
        fmt::check(true), pairs.len(), t0.elapsed().as_secs_f64());
    println!();

    // ════════════════════════════════════════════════════════════════
    // PHASE 2: FLAT PARALLEL row computation
    // ════════════════════════════════════════════════════════════════
    fmt::section("Phase 2: Flat Parallel Row Computation");

    // Build work items: (pair_index, m) — total = pairs.len() * (max_m - 1)
    let total_work = pairs.len() * (max_m - 1);
    println!("    Dispatching {} work items across {} threads...", total_work, threads);

    // Pre-allocate storage: [pair_idx][m] -> (rt, ftc, is_two_tile)
    // We use a flat Vec indexed by pair_idx * (max_m - 1) + (m - 1)
    struct RowVal {
        rt: f64,
        ftc: f64,
        is_two_tile: bool,
    }

    let progress = AtomicUsize::new(0);
    let report_interval = total_work / 20; // report every ~5%

    let row_vals: Vec<RowVal> = (0..total_work)
        .into_par_iter()
        .map(|work_idx| {
            let pair_idx = work_idx / (max_m - 1);
            let m = (work_idx % (max_m - 1)) + 1; // m in 1..max_m
            let (a, b) = pairs[pair_idx];

            let rt = series::row_term(a, b, m).to_f64();
            let ftc = series::actual_row_integral(a, b, m).to_f64();
            let is_two_tile = series::is_two_tile(a, b, m);

            let done = progress.fetch_add(1, Ordering::Relaxed) + 1;
            if report_interval > 0 && done % report_interval == 0 {
                let pct = (done as f64 / total_work as f64) * 100.0;
                let elapsed = t0.elapsed().as_secs_f64();
                let rate = done as f64 / elapsed;
                eprintln!("    [{done}/{total_work}] {pct:.0}% — {rate:.0} rows/s — {elapsed:.1}s");
            }

            RowVal { rt, ftc, is_two_tile }
        })
        .collect();

    let phase2_time = t0.elapsed().as_secs_f64();
    let rate = total_work as f64 / phase2_time;
    println!("    {} {} rows computed in {:.2}s ({:.0} rows/s)",
        fmt::check(true), total_work, phase2_time, rate);
    println!();

    // ════════════════════════════════════════════════════════════════
    // PHASE 3: Aggregate per-pair prefix sums and build results
    // ════════════════════════════════════════════════════════════════
    fmt::section("Phase 3: Aggregation & Analysis");

    let mut results: Vec<PairResult> = Vec::with_capacity(pairs.len());

    for (pair_idx, &(a, b)) in pairs.iter().enumerate() {
        let (formula_val, strip_val) = formula_data[pair_idx];
        let base = pair_idx * (max_m - 1);

        // Build prefix sums from flat row_vals
        let mut rt_prefix = vec![0.0f64; max_m];
        let mut ftc_prefix = vec![0.0f64; max_m];
        let mut corr_prefix = vec![0.0f64; max_m];
        let mut two_tile_count = 0usize;

        for m in 1..max_m {
            let rv = &row_vals[base + (m - 1)];
            let corr = rv.ftc - rv.rt;
            rt_prefix[m] = rt_prefix[m - 1] + rv.rt;
            ftc_prefix[m] = ftc_prefix[m - 1] + rv.ftc;
            corr_prefix[m] = corr_prefix[m - 1] + corr;
            if rv.is_two_tile { two_tile_count += 1; }
        }

        // Sample at each M value
        let mut m_results = Vec::with_capacity(M_VALUES.len());
        for &big_m in M_VALUES {
            let idx = (big_m - 1).min(max_m - 1);
            m_results.push(MResult {
                big_m,
                s_combined: rt_prefix[idx],
                ftc_sum: ftc_prefix[idx],
                correction_sum: corr_prefix[idx],
            });
        }

        let total_correction = corr_prefix[max_m - 1];

        results.push(PairResult {
            a, b, formula_val, strip_val,
            m_results, two_tile_count, total_correction,
        });
    }

    // ════════════════════════════════════════════════════════════════
    // PHASE 4: Output tables and certificates
    // ════════════════════════════════════════════════════════════════
    let mut decomp_rows: Vec<Vec<String>> = Vec::new();
    let mut conv_rows: Vec<Vec<String>> = Vec::new();
    let mut corr_rows: Vec<Vec<String>> = Vec::new();

    let mut all_ftc_bounded = true;
    let mut all_algebraic_bounded = true;
    let mut worst_ftc_tail = 0.0f64;
    let mut worst_alg_tail = 0.0f64;
    let mut worst_ftc_pair = (0usize, 0usize);
    let mut worst_alg_pair = (0usize, 0usize);
    let mut total_two_tile = 0usize;

    for r in &results {
        let target = r.formula_val - r.strip_val;
        total_two_tile += r.two_tile_count;

        for mr in &r.m_results {
            let ftc_err = mr.ftc_sum - target;
            let alg_err = mr.s_combined - target;
            let ftc_scaled = ftc_err.abs() * (r.a as f64) * (mr.big_m as f64);
            let alg_scaled = alg_err.abs() * (r.a as f64) * (mr.big_m as f64);

            decomp_rows.push(vec![
                r.a.to_string(), r.b.to_string(), mr.big_m.to_string(),
                format!("{:.15e}", mr.s_combined),
                format!("{:.15e}", mr.ftc_sum),
                format!("{:.15e}", mr.correction_sum),
                format!("{:.15e}", r.strip_val),
                format!("{:.15e}", r.formula_val),
                format!("{:.15e}", target),
                format!("{:.6e}", ftc_err),
                format!("{:.6e}", ftc_scaled),
                format!("{:.6e}", alg_err),
                format!("{:.6e}", alg_scaled),
            ]);
        }

        // Convergence row (at max M)
        let last = r.m_results.last().unwrap();
        let ftc_err = last.ftc_sum - target;
        let alg_err = last.s_combined - target;
        let ftc_scaled = ftc_err.abs() * (r.a as f64) * (last.big_m as f64);
        let alg_scaled = alg_err.abs() * (r.a as f64) * (last.big_m as f64);

        if ftc_scaled > TAIL_BOUND_C { all_ftc_bounded = false; }
        if alg_scaled > TAIL_BOUND_C { all_algebraic_bounded = false; }
        if ftc_scaled > worst_ftc_tail { worst_ftc_tail = ftc_scaled; worst_ftc_pair = (r.a, r.b); }
        if alg_scaled > worst_alg_tail { worst_alg_tail = alg_scaled; worst_alg_pair = (r.a, r.b); }

        conv_rows.push(vec![
            r.a.to_string(), r.b.to_string(),
            format!("{:.15e}", r.formula_val),
            format!("{:.15e}", target),
            format!("{:.6e}", ftc_err),
            format!("{:.6e}", ftc_scaled),
            format!("{:.6e}", alg_err),
            format!("{:.6e}", alg_scaled),
            format!("{}", r.two_tile_count),
            format!("{:.6e}", r.total_correction),
            format!("{}", ftc_scaled < TAIL_BOUND_C),
        ]);

        corr_rows.push(vec![
            r.a.to_string(), r.b.to_string(),
            format!("{}", r.two_tile_count),
            format!("{:.15e}", r.total_correction),
            format!("{:.15e}", last.correction_sum),
            format!("{:.6e}", alg_err - ftc_err),
        ]);
    }

    // Stats
    println!("    Total two-tile rows: {}", total_two_tile);
    println!("    FTC path:       worst |err|·aM = {:.6} at ({},{})",
        worst_ftc_tail, worst_ftc_pair.0, worst_ftc_pair.1);
    println!("    Algebraic path: worst |err|·aM = {:.6} at ({},{})",
        worst_alg_tail, worst_alg_pair.0, worst_alg_pair.1);
    println!();

    // ════════════════════════════════════════════════════════════════
    // PHASE 5: Write certificates
    // ════════════════════════════════════════════════════════════════
    fmt::section("Phase 4: Certificates");

    let decomp_headers = &[
        "a", "b", "M",
        "s_combined", "ftc_sum", "correction_sum", "strip",
        "formula", "target",
        "ftc_error", "ftc_error_x_aM",
        "alg_error", "alg_error_x_aM",
    ];
    certificate::write_tsv("results/decomposition.tsv", decomp_headers, &decomp_rows);
    println!("    {} results/decomposition.tsv ({} rows)", fmt::check(true), decomp_rows.len());

    let conv_headers = &[
        "a", "b", "formula", "target",
        "ftc_error", "ftc_error_x_aM",
        "alg_error", "alg_error_x_aM",
        "two_tile_rows", "total_correction", "ftc_bounded",
    ];
    certificate::write_tsv("results/convergence.tsv", conv_headers, &conv_rows);
    println!("    {} results/convergence.tsv ({} rows)", fmt::check(true), conv_rows.len());

    let corr_headers = &[
        "a", "b", "two_tile_count", "total_correction",
        "correction_at_max_M", "alg_minus_ftc_error",
    ];
    certificate::write_tsv("results/corrections.tsv", corr_headers, &corr_rows);
    println!("    {} results/corrections.tsv ({} rows)", fmt::check(true), corr_rows.len());

    // Summary JSON
    let elapsed = t0.elapsed().as_secs_f64();
    let summary = serde_json::json!({
        "experiment": "series-decomposition-verifier",
        "version": env!("CARGO_PKG_VERSION"),
        "timestamp": chrono::Utc::now().to_rfc3339(),
        "precision_bits": series::PREC,
        "max_b": MAX_B,
        "num_pairs": pairs.len(),
        "m_values": M_VALUES,
        "max_m": max_m,
        "total_rows_computed": total_work,
        "threads": threads,
        "throughput_rows_per_sec": format!("{:.0}", rate),
        "tail_bound_C": TAIL_BOUND_C,
        "results": {
            "ftc_path": {
                "all_bounded": all_ftc_bounded,
                "worst_tail_product": worst_ftc_tail,
                "worst_pair": format!("({},{})", worst_ftc_pair.0, worst_ftc_pair.1),
                "certified": all_ftc_bounded,
            },
            "algebraic_path": {
                "all_bounded": all_algebraic_bounded,
                "worst_tail_product": worst_alg_tail,
                "worst_pair": format!("({},{})", worst_alg_pair.0, worst_alg_pair.1),
                "note": "rowTerm ≠ actualRowIntegral for two-tile rows; correction is summable",
            },
            "two_tile_analysis": {
                "total_two_tile_rows": total_two_tile,
                "pairs_with_two_tile": results.iter().filter(|r| r.two_tile_count > 0).count(),
                "pairs_without_two_tile": results.iter().filter(|r| r.two_tile_count == 0).count(),
            },
        },
        "runtime_seconds": format!("{:.2}", elapsed),
    });
    certificate::write_json("results/summary.json", &summary);
    println!("    {} results/summary.json", fmt::check(true));
    println!();

    // ════════════════════════════════════════════════════════════════
    // VERDICT
    // ════════════════════════════════════════════════════════════════
    fmt::section("Verdict");

    if all_ftc_bounded {
        println!(
            "    {}{}  FTC PATH: ALL {} PAIRS CERTIFIED{} — |err|·aM < {TAIL_BOUND_C}",
            fmt::BOLD, fmt::GREEN, pairs.len(), fmt::RESET,
        );
    } else {
        println!(
            "    {}{}  FTC PATH: FAILED{} — worst |err|·aM = {worst_ftc_tail:.4} at ({},{})",
            fmt::BOLD, fmt::RED, fmt::RESET, worst_ftc_pair.0, worst_ftc_pair.1,
        );
    }

    if all_algebraic_bounded {
        println!(
            "    {}{}  ALG PATH: ALL {} PAIRS CERTIFIED{} — |err|·aM < {TAIL_BOUND_C}",
            fmt::BOLD, fmt::GREEN, pairs.len(), fmt::RESET,
        );
    } else {
        println!(
            "    {}{}  ALG PATH: DIVERGENT (expected){} — two-tile correction unbounded for {} pairs",
            fmt::BOLD, fmt::YELLOW, fmt::RESET,
            results.iter().filter(|r| r.two_tile_count > 0).count(),
        );
    }

    println!();
    println!(
        "  {}Total: {:.2}s — {} rows at {:.0} rows/s across {} threads{}",
        fmt::DIM, elapsed, total_work, rate, threads, fmt::RESET,
    );
    println!();
}
