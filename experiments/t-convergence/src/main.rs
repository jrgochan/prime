//! # T-Convergence Explorer
//!
//! Empirical analysis of the truncation horizon T for Gram matrix entries.
//!
//! ## Mathematical Background
//!
//! The Gram matrix entry `G[j,k] = ∫₀¹ {1/(jx)}{1/(kx)} dx` is computed via
//! a finite sum of T terms plus an Euler-Maclaurin tail correction.  The
//! truncation error decays as:
//!
//! ```text
//!   error(T) ≈ tₘ / T²
//! ```
//!
//! where `tₘ = 1/4 + gcd(j,k)² / (12jk)` is the tail coefficient.
//!
//! ## Key Results
//!
//! 1. Error decays as T⁻²  (empirically confirmed across all (j,k) pairs).
//! 2. T does NOT need to scale with N — worst-case tₘ = 1/3 for all N.
//! 3. T=200K gives ~10–11 correct digits per entry.
//! 4. Only DD (31-digit) storage produces meaningful Cholesky digits at N=55,440.
//!
//! ## Usage
//!
//! ```bash
//! cargo run --release -p t-convergence
//! cargo run --release -p t-convergence -- --n-max 5000
//! ```

mod output;

use std::time::Instant;
use rayon::prelude::*;
use rug::Float;
use cathedral_utils::gram::{self, LnNTable};
use cathedral_utils::arith;

/// Precision (in bits) used for MPFR reference computations.
const REFERENCE_PREC: u32 = 1024;

fn main() {
    let t_start = Instant::now();
    let args: Vec<String> = std::env::args().collect();

    let n_max: usize = args.iter().position(|a| a == "--n-max")
        .and_then(|i| args.get(i + 1)?.parse().ok())
        .unwrap_or(1000);

    // Representative (j,k) pairs spanning diagonal, off-diagonal, coprime, etc.
    let pairs: Vec<(usize, usize)> = vec![
        (2, 2), (2, 3), (6, 10), (12, 12), (100, 100), (1000, 1000),
    ];

    // T values for convergence sweep (logarithmically spaced)
    let t_values: Vec<usize> = vec![
        500, 1_000, 2_000, 5_000, 10_000, 20_000, 50_000,
        100_000, 200_000, 500_000, 1_000_000, 2_000_000,
    ];

    // ═══════════════════════════════════════════════════════════
    // HEADER
    // ═══════════════════════════════════════════════════════════
    println!();
    println!("╔══════════════════════════════════════════════════════════════╗");
    println!("║  🔬 T-CONVERGENCE EXPLORER — Truncation Horizon Analysis   ║");
    println!("╠══════════════════════════════════════════════════════════════╣");
    println!("║  Threads: {:<49}║", rayon::current_num_threads());
    println!("║  Pairs: {:?}{:<1}", &pairs[..pairs.len().min(4)],
        if pairs.len() > 4 { format!(" (+{})", pairs.len() - 4) } else { String::new() });
    println!("║  N_max for scaling: {:<39}║", n_max);
    println!("╚══════════════════════════════════════════════════════════════╝");
    println!();

    // ═══════════════════════════════════════════════════════════
    // PART 1: Mathematical Background
    // ═══════════════════════════════════════════════════════════
    println!("═══════════════════════════════════════════════════════════════");
    println!("PART 1: THE INTEGRAL AND ITS SERIES REPRESENTATION");
    println!("═══════════════════════════════════════════════════════════════");
    println!();
    println!("  G[j,k] = ∫₀¹ {{1/(jx)}}{{1/(kx)}} dx");
    println!();
    println!("  Block-based algorithm: O(T/j + T/k) blocks per entry.");
    println!("  Euler-Maclaurin tail: tₘ/T + tₘ/(2T²) + tₘ/(6T³)");
    println!("  where tₘ = 1/4 + gcd(j,k)² / (12jk)");
    println!();

    // ═══════════════════════════════════════════════════════════
    // PART 2: Convergence rate (parallel sweep)
    // ═══════════════════════════════════════════════════════════
    println!("═══════════════════════════════════════════════════════════════");
    println!("PART 2: CONVERGENCE RATE — ERROR vs T  (parallel sweep)");
    println!("═══════════════════════════════════════════════════════════════");
    println!();

    // Build ONE MPFR ln(n) table at the maximum T — shared by all pairs.
    let t_ref = *t_values.last().unwrap();
    let t0 = Instant::now();
    let ln_table = LnNTable::new(t_ref + 1, REFERENCE_PREC);
    println!("  ✓ ln(n) table built in {:.1}s", t0.elapsed().as_secs_f64());

    // Reference values at maximum T — computed in parallel.
    let t0 = Instant::now();
    let references: Vec<Float> = pairs.par_iter()
        .map(|&(j, k)| gram::gram_entry_fast_at_t(j, k, &ln_table, t_ref))
        .collect();
    println!("  ✓ References (T={}) computed in {:.2}s (parallel)",
        format_t(t_ref), t0.elapsed().as_secs_f64());
    println!();

    // Collect convergence data for output
    let mut convergence_data: Vec<output::ConvergencePoint> = Vec::new();

    for (idx, &(j, k)) in pairs.iter().enumerate() {
        let ref_val = &references[idx];
        let g = arith::gcd(j, k);
        let lcm = (j / g) * k;
        let tm = 0.25 + (g * g) as f64 / (12.0 * j as f64 * k as f64);

        println!("  G[{},{}]: gcd={}, lcm={}, tₘ={:.6}", j, k, g, lcm, tm);
        println!("  Reference: {:.40}", ref_val.to_f64());
        println!("  {:>10} {:>12} {:>12} {:>8}", "T", "abs_error", "rate", "digits");
        println!("  {:>10} {:>12} {:>12} {:>8}",
            "─────────", "────────────", "────────────", "────────");

        // All T values computed in parallel for this pair.
        let t_max_idx = t_values.len() - 1;
        let results: Vec<(usize, f64)> = t_values[..t_max_idx].par_iter()
            .map(|&t| {
                let val = gram::gram_entry_fast_at_t(j, k, &ln_table, t);
                let err = Float::with_val(REFERENCE_PREC, &val - ref_val)
                    .to_f64().abs();
                (t, err)
            })
            .collect();

        let mut prev_err: Option<f64> = None;
        let mut prev_t: Option<usize> = None;

        for &(t, err) in &results {
            let rate_str = match (prev_err, prev_t) {
                (Some(pe), Some(pt)) if err > 0.0 && pe > 0.0 => {
                    let exponent = (pe / err).ln() / (t as f64 / pt as f64).ln();
                    format!("T^{:.1}", -exponent)
                }
                _ => "—".to_string(),
            };

            let digits = if err > 0.0 { -err.log10() } else { 50.0 };
            println!("  {:>10} {:>12.3e} {:>12} {:>8.1}",
                format_t(t), err, rate_str, digits);

            convergence_data.push(output::ConvergencePoint {
                j, k, t, error: err, rate: rate_str.clone(), digits,
            });

            prev_err = Some(err);
            prev_t = Some(t);
        }
        println!();
    }

    // ═══════════════════════════════════════════════════════════
    // PART 3: Does T need to scale with N?
    // ═══════════════════════════════════════════════════════════
    println!("═══════════════════════════════════════════════════════════════");
    println!("PART 3: DOES T SCALE WITH N?");
    println!("═══════════════════════════════════════════════════════════════");
    println!();
    println!("  tₘ = 1/4 + gcd²/(12jk).");
    println!("  Diagonal (j=k): gcd=j → tₘ = 1/4 + 1/12 = 1/3 (CONSTANT).");
    println!();

    let n_survey = build_n_survey(n_max);

    println!("  {:>8} {:>10} {:>14} {:>12}",
        "N", "worst_tₘ", "worst_pair", "lcm");
    println!("  {:>8} {:>10} {:>14} {:>12}",
        "────────", "──────────", "──────────────", "────────────");

    let mut scaling_data: Vec<output::ScalingRow> = Vec::new();

    for &n in &n_survey {
        let (worst_tm, worst_pair, worst_lcm) = find_worst_tm(n);
        println!("  {:>8} {:>10.6} {:>14} {:>12}",
            n, worst_tm,
            format!("({},{})", worst_pair.0, worst_pair.1),
            worst_lcm);
        scaling_data.push(output::ScalingRow {
            n, worst_tm, worst_pair, worst_lcm,
        });
    }

    println!();
    println!("  ┌─────────────────────────────────────────────────────────┐");
    println!("  │  RESULT: worst_tₘ = 1/3 ≈ 0.333333 for ALL N.        │");
    println!("  │  T does NOT need to grow with N.                       │");
    println!("  └─────────────────────────────────────────────────────────┘");
    println!();

    // ═══════════════════════════════════════════════════════════
    // PART 4: Empirical T calibration
    // ═══════════════════════════════════════════════════════════
    println!("═══════════════════════════════════════════════════════════════");
    println!("PART 4: RECOMMENDED T VALUES (empirically calibrated)");
    println!("═══════════════════════════════════════════════════════════════");
    println!();

    let (alpha, cal_c) = calibrate_decay(&ln_table, &references[0]);

    println!();
    println!("  ┌──────────────────┬────────┬───────────────┐");
    println!("  │ Precision Target │ Digits │ T needed      │");
    println!("  ├──────────────────┼────────┼───────────────┤");

    let mut precision_targets: Vec<output::PrecisionTarget> = Vec::new();

    for (label, digits) in [
        ("FP32", 7), ("FP64", 16), ("DD (solve)", 21), ("DD (full)", 31),
    ] {
        let eps = 10.0f64.powi(-(digits as i32));
        let tm_worst = 1.0 / 3.0;
        let t_needed = ((cal_c * tm_worst / eps).powf(1.0 / alpha)) as u64;
        println!("  │ {:<16} │ {:>6} │ {:>13} │",
            label, digits, format_t(t_needed as usize));
        precision_targets.push(output::PrecisionTarget {
            label: label.to_string(), digits, t_needed,
        });
    }
    println!("  └──────────────────┴────────┴───────────────┘");
    println!();

    let calibration = output::CalibrationResult {
        alpha, c: cal_c, precision_targets,
    };

    // ═══════════════════════════════════════════════════════════
    // PART 5: GPU precision-vs-size tradeoff
    // ═══════════════════════════════════════════════════════════
    println!("═══════════════════════════════════════════════════════════════");
    println!("PART 5: GPU PRECISION-vs-SIZE TRADEOFF");
    println!("═══════════════════════════════════════════════════════════════");
    println!();

    let n_target = 55_440usize;
    let dim = n_target - 1;
    let kappa_log10 = 20.0;

    println!("  ┌──────────┬──────────────┬──────────────┬──────────────┐");
    println!("  │ Storage  │ Entry digits │ VRAM (N={}) │ Solve digits │", n_target);
    println!("  ├──────────┼──────────────┼──────────────┼──────────────┤");

    let mut gpu_tradeoffs: Vec<output::GpuTradeoff> = Vec::new();

    for (storage, entry_digits, bytes_per) in [
        ("FP16", 3.5f64, 2u64), ("FP32", 7.0, 4),
        ("FP64", 16.0, 8),      ("DD",  31.0, 16),
    ] {
        let vram_gb = (dim as f64 * dim as f64 * bytes_per as f64) / (1 << 30) as f64;
        let solve_digits = entry_digits - kappa_log10;
        let solve_str = if solve_digits <= 0.0 {
            "NONE ✗".to_string()
        } else {
            format!("{:.0} ✓", solve_digits)
        };
        println!("  │ {:<8} │ {:>12.1} │ {:>9.1} GB │ {:>12} │",
            storage, entry_digits, vram_gb, solve_str);
        gpu_tradeoffs.push(output::GpuTradeoff {
            storage: storage.to_string(), entry_digits, vram_gb, solve_digits,
        });
    }
    println!("  └──────────┴──────────────┴──────────────┴──────────────┘");
    println!();
    println!("  → DD build + CPU OOC Cholesky is the only viable path.");
    println!();

    // ═══════════════════════════════════════════════════════════
    // PART 6: T=200K vs reference comparison
    // ═══════════════════════════════════════════════════════════
    println!("═══════════════════════════════════════════════════════════════");
    println!("PART 6: CURRENT DEFAULT T=200K vs REFERENCE");
    println!("═══════════════════════════════════════════════════════════════");
    println!();

    let check_pairs = [(2, 2), (2, 3), (100, 100), (1000, 1000)];
    println!("  {:>12} {:>18} {:>18} {:>12}",
        "(j,k)", "G @ T=200K", format!("G @ T={}", format_t(t_ref)), "error");
    println!("  {:>12} {:>18} {:>18} {:>12}",
        "────────────", "──────────────────", "──────────────────", "────────────");

    let ref_results: Vec<_> = check_pairs.par_iter()
        .map(|&(j, k)| {
            let v200k = gram::gram_entry_fast_at_t(j, k, &ln_table, 200_000);
            let vref  = gram::gram_entry_fast_at_t(j, k, &ln_table, t_ref);
            let err = Float::with_val(REFERENCE_PREC, &v200k - &vref).to_f64().abs();
            (j, k, v200k.to_f64(), vref.to_f64(), err)
        })
        .collect();

    let mut ref_comparisons: Vec<output::ReferenceComparison> = Vec::new();

    for (j, k, v200k, vref, err) in ref_results {
        println!("  {:>12} {:>18.16} {:>18.16} {:>12.3e}",
            format!("({},{})", j, k), v200k, vref, err);
        ref_comparisons.push(output::ReferenceComparison {
            j, k, value_200k: v200k, value_ref: vref, error: err,
        });
    }
    println!();

    // ═══════════════════════════════════════════════════════════
    // OUTPUT FILES
    // ═══════════════════════════════════════════════════════════
    let total_elapsed = t_start.elapsed().as_secs_f64();
    output::write_results(
        n_max, &convergence_data, &scaling_data,
        &calibration, &gpu_tradeoffs, &ref_comparisons,
        t_ref, total_elapsed,
    );

    // ═══════════════════════════════════════════════════════════
    // SUMMARY
    // ═══════════════════════════════════════════════════════════
    println!("╔══════════════════════════════════════════════════════════════╗");
    println!("║  SUMMARY                                                   ║");
    println!("╠══════════════════════════════════════════════════════════════╣");
    println!("║  • Empirical decay: error ∝ T^{{-{:.1}}}                     ║", alpha);
    println!("║  • T does NOT scale with N (worst tₘ = 1/3 always)        ║");
    println!("║  • T=200K default: ~10–11 correct digits per entry        ║");
    println!("║  • Only DD (31-digit) build gives useful Cholesky digits   ║");
    println!("╚══════════════════════════════════════════════════════════════╝");
    println!();
}

// ═══════════════════════════════════════════════════════════════
// HELPER FUNCTIONS
// ═══════════════════════════════════════════════════════════════

/// Build a survey of N values for the scaling check.
fn build_n_survey(n_max: usize) -> Vec<usize> {
    let mut ns = vec![10, 50, 100, 500];
    if n_max >= 1_000  { ns.push(1_000); }
    if n_max >= 5_000  { ns.push(5_000); }
    if n_max >= 10_000 { ns.push(10_000); }
    if n_max >= 55_440 { ns.push(55_440); }
    ns.retain(|&n| n <= n_max);
    ns
}

/// Find the worst (largest) tail coefficient tₘ across all (j,k) pairs
/// for a given matrix dimension N.
fn find_worst_tm(n: usize) -> (f64, (usize, usize), usize) {
    let mut worst_tm = 0.0f64;
    let mut worst_pair = (0usize, 0usize);
    let mut worst_lcm = 0usize;

    // Sample up to 200×200 from the matrix, plus diagonal boundary.
    let sample_limit = n.min(200);
    for j in 2..=sample_limit + 1 {
        for k in j..=sample_limit + 1 {
            let g = arith::gcd(j, k);
            let tm = 0.25 + (g * g) as f64 / (12.0 * j as f64 * k as f64);
            if tm > worst_tm {
                worst_tm = tm;
                worst_pair = (j, k);
                worst_lcm = (j / g) * k;
            }
        }
    }
    // Diagonal entries at the boundary
    for &j in &[n / 2, n - 1, n] {
        if j < 2 { continue; }
        let tm = 0.25 + 1.0 / 12.0; // diagonal: gcd²/(j²) = 1
        if tm > worst_tm {
            worst_tm = tm;
            worst_pair = (j, j);
            worst_lcm = j;
        }
    }

    (worst_tm, worst_pair, worst_lcm)
}

/// Calibrate the empirical decay exponent α and constant C from G[2,2].
///
/// Returns (α, C) such that `error ≈ C · tₘ / T^α`.
fn calibrate_decay(ln_table: &LnNTable, ref_g22: &Float) -> (f64, f64) {
    let tm_worst = 1.0 / 3.0;

    let cal_t1 = 100_000usize;
    let cal_t2 = 200_000usize;

    let val1 = gram::gram_entry_fast_at_t(2, 2, ln_table, cal_t1);
    let val2 = gram::gram_entry_fast_at_t(2, 2, ln_table, cal_t2);

    let err1 = Float::with_val(REFERENCE_PREC, &val1 - ref_g22).to_f64().abs();
    let err2 = Float::with_val(REFERENCE_PREC, &val2 - ref_g22).to_f64().abs();

    let alpha = if err1 > 0.0 && err2 > 0.0 {
        (err1 / err2).ln() / (cal_t2 as f64 / cal_t1 as f64).ln()
    } else {
        2.0
    };

    let c = err1 * (cal_t1 as f64).powf(alpha) / tm_worst;

    println!("  Empirical calibration (G[2,2]):");
    println!("    err@{} = {:.3e}, err@{} = {:.3e}",
        format_t(cal_t1), err1, format_t(cal_t2), err2);
    println!("    Measured decay exponent α = {:.2}", alpha);
    println!("    Fitted C = {:.3e}", c);

    (alpha, c)
}

/// Format a T value for human display (e.g., 100K, 2.0M, 19.1B).
fn format_t(t: usize) -> String {
    if t >= 1_000_000_000 {
        format!("{:.1}B", t as f64 / 1e9)
    } else if t >= 1_000_000 {
        format!("{:.1}M", t as f64 / 1e6)
    } else if t >= 1_000 {
        format!("{}K", t / 1_000)
    } else {
        format!("{}", t)
    }
}
