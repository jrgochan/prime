//! ═══════════════════════════════════════════════════════════════════════════
//!  TWO-TILE DECOMPOSITION VALIDATOR v2
//!  512-bit MPFR · Exact Piecewise FTC · Parallel Rayon
//!
//!  Cathedral experiment validating the four-way decomposition:
//!
//!    gramIntegral(a,b) = strip + Σ' actualRowIntegral(n+1)
//!                      = strip + Σ' rowTerm(n+1) + Σ' Δ(n+1)
//!                      = strip + stirling/b + fractTarget/a + Σ' Δ(n+1)
//!
//!  For each coprime (a,b) with a < b, computes:
//!    §1. gramIntegral(a,b)           — exact piecewise FTC
//!    §2. strip(a,b)                  — (a-1)/(ab)
//!    §3. Σ' actualRowIntegral(n+1)   — sum of exact row integrals
//!    §4. Σ' rowTerm(n+1)             — sum of single-tile approximations
//!    §5. Σ' Δ(n+1)                   — two-tile correction (actual - rowTerm)
//!    §6. stirling/b                  — (log(2π) - γ - 1)/b
//!    §7. fractTarget(a,b)/a          — residue-class evaluation
//!    §8. vasyuninGramFormula(a,b)     — closed-form target
//!
//!  Validates:
//!    A. gramIntegral ≈ strip + Σ' actual          (structural identity)
//!    B. Σ' actual ≈ Σ' rowTerm + Σ' Δ             (decomposition identity)
//!    C. gramIntegral ≈ gramFormula                (the Vasyunin identity)
//!    D. Tail convergence: Σ'Δ(M) ≈ Δ_exact + C/(M)
//!
//!  Usage:
//!    cargo run --release                     # Standard 18 pairs, M=250k
//!    cargo run --release -- --pairs extended  # Extended 127 pairs, M=250k
//!    cargo run --release -- --pairs large     # Large 775 pairs, M=250k
//!    cargo run --release -- -M 100000         # Standard pairs, M=100k
//!    cargo run --release -- --pairs extended -M 100000  # Extended, M=100k
//!    cargo run --release -- --max-b 30 -M 50000   # Custom: all pairs b≤30, M=50k
//! ═══════════════════════════════════════════════════════════════════════════

mod compute;
mod formula;
mod analysis;
mod delta_formula;
mod actual_eval;
mod gram_crossref;
mod class_eval;
mod honest_algebra;
mod rosetta_stone;
mod axiom_graduation;

use std::time::Instant;
use rayon::prelude::*;
use cathedral_utils::fmt;
use cathedral_utils::certificate;
use cathedral_utils::coprime;

/// MPFR precision in bits.
pub const PREC: u32 = 1024;

/// Default maximum row index for the tsum computation.
pub const DEFAULT_MAX_M: usize = 250_000;

/// Parse CLI arguments and return (pairs, max_m).
fn parse_args() -> (Vec<coprime::CoprimePair>, usize, Option<usize>, Option<usize>) {
    let args: Vec<String> = std::env::args().collect();
    let mut max_m = DEFAULT_MAX_M;
    let mut pair_set = "standard".to_string();
    let mut custom_max_b: Option<usize> = None;
    let mut crossref_n: Option<usize> = None;
    let mut rosetta_n: Option<usize> = None;

    let mut i = 1;
    while i < args.len() {
        match args[i].as_str() {
            "--pairs" | "-p" => {
                i += 1;
                if i < args.len() { pair_set = args[i].clone(); }
            }
            "--max-m" | "-M" => {
                i += 1;
                if i < args.len() {
                    max_m = args[i].parse().expect("Invalid M value");
                }
            }
            "--max-b" | "-B" => {
                i += 1;
                if i < args.len() {
                    custom_max_b = Some(args[i].parse().expect("Invalid max_b value"));
                }
            }
            "--crossref" | "-X" => {
                i += 1;
                if i < args.len() {
                    crossref_n = Some(args[i].parse().expect("Invalid crossref N value"));
                }
            }
            "--rosetta" | "-R" => {
                i += 1;
                if i < args.len() {
                    rosetta_n = Some(args[i].parse().expect("Invalid rosetta N value"));
                }
            }
            "--help" | "-h" => {
                println!("Two-Tile Decomposition Validator v2");
                println!();
                println!("Usage: two-tile-decomposition [OPTIONS]");
                println!();
                println!("Options:");
                println!("  --pairs, -p <SET>   Pair dataset: standard|extended|large|stress (default: standard)");
                println!("  --max-b, -B <N>     Generate all coprime pairs with b ≤ N");
                println!("  --max-m, -M <N>     Max row index (default: 250000)");
                println!("  --crossref, -X <N>  Cross-reference FTC vs gram_entry_mpfr for j,k ≤ N");
                println!("  --rosetta, -R <N>   Rosetta Stone bridge: gramEntry ↔ gramIntegral for j,k ≤ N");
                println!("  --help, -h          Show this help");
                println!();
                println!("Datasets:");
                println!("  standard   18 pairs (a,b ≤ 9)     — axiom graduation validated");
                println!("  extended  127 pairs (a,b ≤ 20)    — full small-index coverage");
                println!("  large     775 pairs (a,b ≤ 50)    — comprehensive");
                println!("  stress   3043 pairs (a,b ≤ 100)   — exhaustive stress test");
                println!();
                println!("Cross-reference:");
                println!("  --crossref 20       Compare FTC decomposition vs cathedral-utils");
                println!("                      for ALL (j,k) with 1 ≤ j < k ≤ N");
                std::process::exit(0);
            }
            _ => {
                eprintln!("Unknown argument: {}", args[i]);
                std::process::exit(1);
            }
        }
        i += 1;
    }

    let pairs = if let Some(max_b) = custom_max_b {
        coprime::generate(max_b)
    } else {
        match pair_set.as_str() {
            "standard" => coprime::standard_pairs(),
            "extended" => coprime::extended_pairs(),
            "large" => coprime::large_pairs(),
            "stress" => coprime::stress_pairs(),
            _ => {
                eprintln!("Unknown pair set: {pair_set}. Use standard|extended|large|stress.");
                std::process::exit(1);
            }
        }
    };

    (pairs, max_m, crossref_n, rosetta_n)
}

fn main() {
    let t0 = Instant::now();
    let n_threads = rayon::current_num_threads();
    let (pairs, max_m, crossref_n, rosetta_n) = parse_args();

    fmt::header(
        "TWO-TILE DECOMPOSITION VALIDATOR v2",
        "gramIntegral = strip + Σ'rowTerm + Σ'Δ",
        PREC,
        n_threads,
    );
    println!("  {}M = {} rows per tsum{}", fmt::DIM, max_m, fmt::RESET);
    coprime::print_summary(&pairs);
    println!();

    std::fs::create_dir_all("results").unwrap();

    // ═══════════════════════════════════════════════════════════════
    // §1. COMPUTE ALL PAIRS
    // ═══════════════════════════════════════════════════════════════

    fmt::section("FOUR-WAY DECOMPOSITION");
    println!();

    println!("  {:>5} {:>5}  {:>22}  {:>22}  {:>22}  {:>14}  {:>14}  {:>14}",
        "(a", "b)", "gramIntegral", "gramFormula", "strip+rowTerm+Δ",
        "|GI - GF|", "|GI - decomp|", "Σ'Δ");
    println!("  {}", "─".repeat(140));

    let n_pairs = pairs.len();
    let mut results: Vec<analysis::PairResult> = Vec::new();

    for (idx, pair) in pairs.iter().enumerate() {
        let (a, b) = (pair.a, pair.b);

        let t = Instant::now();

        // §1: Strip value
        let strip = compute::strip_value(a, b);

        // §2: Compute exact row integrals and rowTerms IN PARALLEL
        let row_data: Vec<(rug::Float, rug::Float, rug::Float, bool)> = (1..=max_m)
            .into_par_iter()
            .map(|m| {
                let actual = compute::exact_row_integral(a, b, m);
                let rt = compute::row_term(a, b, m);
                let delta = rug::Float::with_val(PREC, &actual - &rt);
                let n_hi = (a * m) / b;
                let n_lo = (a * (m + 1)) / b;
                let is_two_tile = n_hi != n_lo;
                (actual, rt, delta, is_two_tile)
            })
            .collect();

        // Reduce sums (serial — summation order matters for accuracy)
        let mut sum_actual = rug::Float::with_val(PREC, 0);
        let mut sum_rowterm = rug::Float::with_val(PREC, 0);
        let mut sum_delta = rug::Float::with_val(PREC, 0);
        let mut n_two_tile = 0usize;

        for (actual, rt, delta, is_two_tile) in &row_data {
            sum_actual += actual;
            sum_rowterm += rt;
            sum_delta += delta;
            if *is_two_tile { n_two_tile += 1; }
        }

        // §3: gramIntegral = strip + sum_actual
        let gram_integral = rug::Float::with_val(PREC, &strip + &sum_actual);

        // §4: Stirling and fractTarget
        let stir = formula::stirling_const();
        let stir_over_b = rug::Float::with_val(PREC, &stir / compute::fu(b));
        let ft = formula::fract_target(a, b);
        let ft_over_a = rug::Float::with_val(PREC, &ft / compute::fu(a));

        // §5: Vasyunin formula
        let gram_formula = formula::vasyunin_gram_formula(a, b);

        // §6: Decomposition check
        let decomp = rug::Float::with_val(PREC,
            rug::Float::with_val(PREC,
                rug::Float::with_val(PREC, &strip + &stir_over_b) + &ft_over_a
            ) + &sum_delta
        );

        // Errors
        let err_gi_gf = rug::Float::with_val(PREC,
            rug::Float::with_val(PREC, &gram_integral - &gram_formula).abs());
        let err_gi_decomp = rug::Float::with_val(PREC,
            rug::Float::with_val(PREC, &gram_integral - &decomp).abs());

        let elapsed_ms = t.elapsed().as_secs_f64() * 1000.0;

        println!("  ({:>2},{:>2})  {:>22.15}  {:>22.15}  {:>22.15}  {:>14.4e}  {:>14.4e}  {:>14.10}  ({:.0}ms, {} 2-tile)  [{}/{}]",
            a, b,
            gram_integral.to_f64(), gram_formula.to_f64(), decomp.to_f64(),
            err_gi_gf.to_f64(), err_gi_decomp.to_f64(),
            sum_delta.to_f64(),
            elapsed_ms, n_two_tile,
            idx + 1, n_pairs);

        results.push(analysis::PairResult {
            a, b,
            gram_integral: gram_integral.to_f64(),
            gram_formula: gram_formula.to_f64(),
            strip: strip.to_f64(),
            sum_actual: sum_actual.to_f64(),
            sum_rowterm: sum_rowterm.to_f64(),
            sum_delta: sum_delta.to_f64(),
            stirling_over_b: stir_over_b.to_f64(),
            fract_target_over_a: ft_over_a.to_f64(),
            decomposition: decomp.to_f64(),
            err_integral_vs_formula: err_gi_gf.to_f64(),
            err_integral_vs_decomposition: err_gi_decomp.to_f64(),
            n_two_tile_rows: n_two_tile,
            time_ms: elapsed_ms,
        });
    }

    println!();

    // ═══════════════════════════════════════════════════════════════
    // §2. TAIL CONVERGENCE ANALYSIS
    // ═══════════════════════════════════════════════════════════════

    analysis::print_tail_convergence(&results, max_m);

    // ═══════════════════════════════════════════════════════════════
    // §3. Σ'Δ EXACT VALUES (only for small sets)
    // ═══════════════════════════════════════════════════════════════

    if results.len() <= 50 {
        analysis::print_sigma_delta_exact(&results);
    } else {
        println!("  {}Skipping Σ'Δ detail ({}+ pairs — see TSV output){}", fmt::DIM, results.len(), fmt::RESET);
        println!();
    }

    // ═══════════════════════════════════════════════════════════════
    // §5. DELTA FORMULA CERTIFICATION
    // ═══════════════════════════════════════════════════════════════

    // Certify exact Δ(m) closed-form against piecewise FTC for all a ≥ 2 pairs
    let cert_pairs: Vec<_> = pairs.iter().filter(|p| p.a >= 2).collect();
    if !cert_pairs.is_empty() {
        println!();
        let cert_results: Vec<delta_formula::DeltaFormulaResult> = cert_pairs
            .par_iter()
            .map(|p| delta_formula::certify_delta_formula(p.a, p.b, max_m))
            .collect();

        delta_formula::print_certification(&cert_results);

        // Write delta certification TSV
        let delta_headers = &["a", "b", "max_pointwise_err", "total_exact",
            "total_numerical", "formula_err", "n_classes"];
        let delta_rows: Vec<Vec<String>> = cert_results.iter().map(|r| vec![
            r.a.to_string(), r.b.to_string(),
            format!("{:.6e}", r.max_pointwise_error),
            format!("{:.15e}", r.total_delta_exact),
            format!("{:.15e}", r.total_delta_numerical),
            format!("{:.6e}", r.formula_vs_numerical_error),
            r.residue_classes.len().to_string(),
        ]).collect();
        certificate::write_tsv("results/delta_certification.tsv", delta_headers, &delta_rows);
    }

    // ═══════════════════════════════════════════════════════════════
    // §6. ALGEBRAIC IDENTITY CERTIFICATION
    //     strip + stirling/b + fractTarget/a + Σ'Δ = formula
    // ═══════════════════════════════════════════════════════════════

    // Certify the full algebraic identity for all a ≥ 2 pairs
    if !cert_pairs.is_empty() {
        println!();
        let eval_results: Vec<actual_eval::ActualEvalResult> = cert_pairs
            .par_iter()
            .map(|p| actual_eval::certify_actual_eval(p.a, p.b, max_m))
            .collect();

        actual_eval::print_certification(&eval_results);

        // Write algebraic identity TSV
        let eval_headers = &["a", "b", "strip", "stirling_b", "ft_a",
            "tsum_delta", "formula", "lhs", "identity_err",
            "gap_algebraic", "gap_numerical", "gap_match"];
        let eval_rows: Vec<Vec<String>> = eval_results.iter().map(|r| vec![
            r.a.to_string(), r.b.to_string(),
            format!("{:.15e}", r.strip),
            format!("{:.15e}", r.stirling_over_b),
            format!("{:.15e}", r.fract_target_over_a),
            format!("{:.15e}", r.tsum_delta),
            format!("{:.15e}", r.formula),
            format!("{:.15e}", r.lhs),
            format!("{:.6e}", r.identity_error),
            format!("{:.15e}", r.gap_algebraic),
            format!("{:.15e}", r.gap_numerical),
            format!("{:.6e}", r.gap_match),
        ]).collect();
        certificate::write_tsv("results/algebraic_identity.tsv", eval_headers, &eval_rows);
    }

    // ═══════════════════════════════════════════════════════════════
    // §4. WRITE RESULTS
    // ═══════════════════════════════════════════════════════════════

    let json_results: Vec<serde_json::Value> = results.iter()
        .map(|r| r.to_json(max_m))
        .collect();

    let summary = serde_json::json!({
        "experiment": "Two-Tile Decomposition Validator v2",
        "precision_bits": PREC,
        "max_m": max_m,
        "n_pairs": results.len(),
        "n_threads": n_threads,
        "timestamp": chrono::Utc::now().to_rfc3339(),
        "elapsed_seconds": t0.elapsed().as_secs_f64(),
        "results": json_results,
    });

    certificate::write_json("results/summary.json", &summary);

    // TSV output
    let headers = &["a", "b", "gram_integral", "gram_formula", "strip",
        "sum_actual", "sum_rowterm", "sum_delta", "stirling_over_b",
        "fract_target_over_a", "err_vs_formula", "err_vs_decomp",
        "n_two_tile", "time_ms"];
    let rows: Vec<Vec<String>> = results.iter().map(|r| r.to_tsv_row()).collect();
    certificate::write_tsv("results/decomposition.tsv", headers, &rows);

    // Tail analysis TSV
    let tail_headers = &["a", "b", "sd_numeric", "sd_exact", "tail_error",
        "tail_predicted", "ratio"];
    let tail_rows: Vec<Vec<String>> = analysis::tail_convergence_rows(&results, max_m);
    certificate::write_tsv("results/tail_analysis.tsv", tail_headers, &tail_rows);

    println!();
    fmt::section("SUMMARY");
    println!();
    println!("  {}Total time: {:.1}s{}", fmt::BOLD, t0.elapsed().as_secs_f64(), fmt::RESET);
    println!("  {}Pairs: {}{}", fmt::DIM, results.len(), fmt::RESET);
    println!("  {}Threads: {}{}", fmt::DIM, n_threads, fmt::RESET);
    println!("  {}Precision: {}-bit MPFR{}", fmt::DIM, PREC, fmt::RESET);
    println!("  {}Max M: {}{}", fmt::DIM, max_m, fmt::RESET);
    println!();
    println!("  Results:");
    println!("    {} results/summary.json", fmt::check(true));
    println!("    {} results/decomposition.tsv", fmt::check(true));
    println!("    {} results/tail_analysis.tsv", fmt::check(true));
    println!("    {} results/delta_certification.tsv", fmt::check(true));
    println!("    {} results/algebraic_identity.tsv", fmt::check(true));

    // ═══════════════════════════════════════════════════════════════
    // §8. PER-CLASS DELTA logΓ DECOMPOSITION
    // ═══════════════════════════════════════════════════════════════

    if !cert_pairs.is_empty() {
        println!();
        let class_input: Vec<(usize, usize)> = cert_pairs.iter()
            .map(|p| (p.a, p.b)).collect();
        let class_results = class_eval::certify_all(&class_input, max_m);
        class_eval::print_certification(&class_results);
    }

    // ═══════════════════════════════════════════════════════════════
    // §9. HONEST ALGEBRA — ∑ perClassLimit = deltaTarget (DIRECT)
    //     No circular bootstrap. Pure algebraic evaluation.
    // ═══════════════════════════════════════════════════════════════

    if !cert_pairs.is_empty() {
        println!();
        let ha_input: Vec<(usize, usize)> = cert_pairs.iter()
            .map(|p| (p.a, p.b)).collect();
        let ha_results = honest_algebra::certify_all(&ha_input);
        honest_algebra::print_certification(&ha_results);

        // Write honest algebra TSV
        let ha_headers = &["a", "b", "n_two_tile",
            "beta_full", "beta_once", "s_perm",
            "piece1_logG_beta", "piece2_logG_alpha", "piece3_digamma",
            "piece1_gauss_err",
            "sum_pcl", "delta_target", "identity_err"];
        let ha_rows: Vec<Vec<String>> = ha_results.iter().map(|r| vec![
            r.a.to_string(), r.b.to_string(), r.n_two_tile.to_string(),
            r.beta_covers_full_range.to_string(),
            r.beta_each_once.to_string(),
            r.s_is_permutation.to_string(),
            format!("{:.15e}", r.piece1_log_gamma_beta),
            format!("{:.15e}", r.piece2_log_gamma_alpha),
            format!("{:.15e}", r.piece3_digamma),
            format!("{:.6e}", r.piece1_gauss_error),
            format!("{:.15e}", r.sum_per_class_limit),
            format!("{:.15e}", r.delta_target),
            format!("{:.6e}", r.identity_error),
        ]).collect();
        certificate::write_tsv("results/honest_algebra.tsv", ha_headers, &ha_rows);
        println!("    {} results/honest_algebra.tsv", fmt::check(true));
    }

    println!();

    // ═══════════════════════════════════════════════════════════════
    // §7. GRAM CROSS-REFERENCE (optional)
    // ═══════════════════════════════════════════════════════════════

    if let Some(n) = crossref_n {
        println!();
        let crossref_results = gram_crossref::cross_reference(n, max_m.min(50_000));
        gram_crossref::print_cross_reference(&crossref_results);

        // Write cross-reference TSV
        let xref_headers = &["j", "k", "gcd", "a", "b",
            "ftc_value", "series_value", "formula_value",
            "err_ftc_series", "err_ftc_formula"];
        let xref_rows: Vec<Vec<String>> = crossref_results.iter().map(|r| vec![
            r.j.to_string(), r.k.to_string(), r.gcd.to_string(),
            r.a.to_string(), r.b.to_string(),
            format!("{:.15e}", r.ftc_value),
            format!("{:.15e}", r.series_value),
            format!("{:.15e}", r.formula_value),
            format!("{:.6e}", r.err_ftc_series),
            format!("{:.6e}", r.err_ftc_formula),
        ]).collect();
        certificate::write_tsv("results/gram_crossref.tsv", xref_headers, &xref_rows);
        println!("    {} results/gram_crossref.tsv", fmt::check(true));
    }

    // ═══════════════════════════════════════════════════════════════
    // §8. ROSETTA STONE — gramEntry ↔ gramIntegral BRIDGE (optional)
    // ═══════════════════════════════════════════════════════════════

    if let Some(n) = rosetta_n {
        println!();
        let bridge_results = rosetta_stone::verify_bridge(n);
        rosetta_stone::print_bridge(&bridge_results);

        // Write bridge TSV
        let bridge_headers = &["j", "k", "gramEntry", "gramIntegral",
            "jk_gramIntegral", "min_minus_1", "correction",
            "bridge_prediction", "bridge_error",
            "phantom_dist", "phantom_bound", "phantom_violated"];
        let bridge_rows: Vec<Vec<String>> = bridge_results.iter().map(|r| vec![
            r.j.to_string(), r.k.to_string(),
            format!("{:.15e}", r.gram_entry),
            format!("{:.15e}", r.gram_integral),
            format!("{:.15e}", r.jk_gram_integral),
            format!("{:.6}", r.min_minus_1),
            format!("{:.15e}", r.correction),
            format!("{:.15e}", r.bridge_prediction),
            format!("{:.6e}", r.bridge_error),
            format!("{:.6e}", r.phantom_dist),
            format!("{:.6e}", r.phantom_bound),
            r.phantom_violated.to_string(),
        ]).collect();
        certificate::write_tsv("results/rosetta_stone.tsv", bridge_headers, &bridge_rows);
        println!("    {} results/rosetta_stone.tsv", fmt::check(true));
    }

    // ═══════════════════════════════════════════════════════════════
    // §10. AXIOM GRADUATION CERTIFIER
    //      gramIntegral_eq_formula_ge2 — The last Cathedral axiom
    // ═══════════════════════════════════════════════════════════════

    if !cert_pairs.is_empty() {
        println!();
        let grad_input: Vec<(usize, usize)> = cert_pairs.iter()
            .map(|p| (p.a, p.b)).collect();
        let grad_results = axiom_graduation::certify_all(&grad_input);
        axiom_graduation::print_certification(&grad_results);

        // Write graduation TSV
        let grad_headers = &["a", "b", "n_two_tile",
            "beta_bij", "s_perm", "overshoot_id",
            "gauss_lgA_err", "gauss_lgB_err", "gauss_dA_err", "gauss_dB_err",
            "telescope_lg_err", "telescope_psi_err",
            "beta_duality_pw", "beta_duality_sum_err",
            "sum_pcl", "delta_target", "identity_err", "certified"];
        let grad_rows: Vec<Vec<String>> = grad_results.iter().map(|r| vec![
            r.a.to_string(), r.b.to_string(), r.n_two_tile.to_string(),
            r.beta_bijection.to_string(),
            r.s_permutation.to_string(),
            r.overshoot_identity.to_string(),
            format!("{:.6e}", r.gauss_loggamma_a_err),
            format!("{:.6e}", r.gauss_loggamma_b_err),
            format!("{:.6e}", r.gauss_digamma_a_err),
            format!("{:.6e}", r.gauss_digamma_b_err),
            format!("{:.6e}", r.telescope_loggamma_err),
            format!("{:.6e}", r.telescope_digamma_err),
            r.beta_duality_pointwise.to_string(),
            format!("{:.6e}", r.beta_duality_sum_err),
            format!("{:.15e}", r.sum_pcl),
            format!("{:.15e}", r.delta_target),
            format!("{:.6e}", r.identity_err),
            r.certified.to_string(),
        ]).collect();
        certificate::write_tsv("results/axiom_graduation.tsv", grad_headers, &grad_rows);
        println!("    {} results/axiom_graduation.tsv", fmt::check(true));
    }

    println!();
}
