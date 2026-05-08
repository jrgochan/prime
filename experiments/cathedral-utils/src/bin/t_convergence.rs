//! ═══════════════════════════════════════════════════════════════════════════
//!  T-CONVERGENCE EXPLORER (Parallel)
//!  Empirical analysis of the truncation horizon T for Gram matrix entries.
//!
//!  Uses the O(T/j + T/k) block-based fast algorithm with rayon parallelism
//!  for all T sweeps. Completes in seconds, not minutes.
//!
//!  Usage:
//!    cargo run --release --bin t-convergence [--n-max <N>]
//! ═══════════════════════════════════════════════════════════════════════════

use std::time::Instant;
use rayon::prelude::*;
use rug::Float;
use cathedral_utils::gram::{self, LnNTable};
use cathedral_utils::arith;

const REFERENCE_PREC: u32 = 1024; // bits for reference computation

fn main() {
    let args: Vec<String> = std::env::args().collect();

    let n_max: usize = args.iter().position(|a| a == "--n-max")
        .and_then(|i| args.get(i + 1)?.parse().ok())
        .unwrap_or(1000);

    let pairs: Vec<(usize, usize)> = vec![
        (2, 2), (2, 3), (6, 10), (12, 12), (100, 100), (1000, 1000),
    ];

    println!();
    println!("╔══════════════════════════════════════════════════════════════╗");
    println!("║  🔬 T-CONVERGENCE EXPLORER (Parallel) — Horizon Analysis   ║");
    println!("╠══════════════════════════════════════════════════════════════╣");
    println!("║  Pairs: {:?}{}", &pairs[..pairs.len().min(4)],
        if pairs.len() > 4 { format!(" (+{})", pairs.len() - 4) } else { String::new() });
    println!("║  N_max for scaling: {:<39}║", n_max);
    println!("╚══════════════════════════════════════════════════════════════╝");
    println!();

    // ═══════════════════════════════════════════════════════════
    // PART 1: Explanation
    // ═══════════════════════════════════════════════════════════
    println!("═══════════════════════════════════════════════════════════════");
    println!("PART 1: THE INTEGRAL AND ITS SERIES REPRESENTATION");
    println!("═══════════════════════════════════════════════════════════════");
    println!();
    println!("  G[j,k] = ∫₀¹ {{1/(jx)}}{{1/(kx)}} dx");
    println!();
    println!("  Block-based algorithm: O(T/j + T/k) blocks per entry.");
    println!("  Euler-Maclaurin tail: tm/T + tm/(2T²) + tm/(6T³)");
    println!("  where tm = 1/4 + gcd(j,k)² / (12jk)");
    println!();

    // ═══════════════════════════════════════════════════════════
    // PART 2: Convergence rate — PARALLEL
    // ═══════════════════════════════════════════════════════════
    println!("═══════════════════════════════════════════════════════════════");
    println!("PART 2: CONVERGENCE RATE — ERROR vs T  (parallel sweep)");
    println!("═══════════════════════════════════════════════════════════════");
    println!();

    let t_values: Vec<usize> = vec![
        500, 1_000, 2_000, 5_000, 10_000, 20_000, 50_000,
        100_000, 200_000, 500_000, 1_000_000, 2_000_000,
    ];

    // Build ONE ln(n) table at max T — shared across all computations
    let t_ref = *t_values.last().unwrap();
    let t0 = Instant::now();
    let ln_table = LnNTable::new(t_ref + 1, REFERENCE_PREC);
    println!("  ✓ ln(n) table built in {:.1}s", t0.elapsed().as_secs_f64());

    // Compute reference values at the maximum T — in parallel
    let t0 = Instant::now();
    let references: Vec<Float> = pairs.par_iter()
        .map(|&(j, k)| gram::gram_entry_fast_at_t(j, k, &ln_table, t_ref))
        .collect();
    println!("  ✓ References (T={}) computed in {:.2}s (parallel)", t_ref, t0.elapsed().as_secs_f64());
    println!();

    for (idx, &(j, k)) in pairs.iter().enumerate() {
        let ref_val = &references[idx];
        let g = arith::gcd(j, k);
        let lcm = (j / g) * k;
        let tm = 0.25 + (g * g) as f64 / (12.0 * j as f64 * k as f64);

        println!("  G[{},{}]: gcd={}, lcm={}, tm={:.6}", j, k, g, lcm, tm);
        println!("  Reference: {:.40}", ref_val.to_f64());
        println!("  {:>10} {:>12} {:>12} {:>8}", "T", "abs_error", "rate", "digits");
        println!("  {:>10} {:>12} {:>12} {:>8}", "─────────", "────────────", "────────────", "────────");

        // Compute all T values in parallel for this pair
        let t_max_minus_1 = t_values.len() - 1;
        let results: Vec<(usize, f64)> = t_values[..t_max_minus_1].par_iter()
            .map(|&t| {
                let val = gram::gram_entry_fast_at_t(j, k, &ln_table, t);
                let err = Float::with_val(REFERENCE_PREC, &val - ref_val).to_f64().abs();
                (t, err)
            })
            .collect();

        let mut prev_err: Option<f64> = None;
        let mut prev_t: Option<usize> = None;

        for &(t, err) in &results {
            let rate_str = if let (Some(pe), Some(pt)) = (prev_err, prev_t) {
                if err > 0.0 && pe > 0.0 {
                    let exponent = (pe / err).ln() / (t as f64 / pt as f64).ln();
                    format!("T^{:.1}", -exponent)
                } else {
                    "—".to_string()
                }
            } else {
                "—".to_string()
            };

            let digits = if err > 0.0 { -err.log10() } else { 50.0 };

            println!("  {:>10} {:>12.3e} {:>12} {:>8.1}",
                format_t(t), err, rate_str, digits);

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
    println!("  tm = 1/4 + gcd²/(12jk).");
    println!("  Diagonal (j=k): gcd=j → tm = 1/4 + 1/12 = 1/3 (CONSTANT).");
    println!();

    let n_survey: Vec<usize> = {
        let mut ns = vec![10, 50, 100, 500];
        if n_max >= 1000 { ns.push(1000); }
        if n_max >= 5000 { ns.push(5000); }
        if n_max >= 10000 { ns.push(10000); }
        if n_max >= 55440 { ns.push(55440); }
        ns.retain(|&n| n <= n_max);
        ns
    };

    println!("  {:>8} {:>10} {:>14} {:>12}", "N", "worst_tm", "worst_pair", "lcm");
    println!("  {:>8} {:>10} {:>14} {:>12}", "────────", "──────────", "──────────────", "────────────");

    for &n in &n_survey {
        let mut worst_tm = 0.0f64;
        let mut worst_pair = (0usize, 0usize);
        let mut worst_lcm = 0usize;

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
        for &j in &[n/2, n-1, n] {
            if j < 2 { continue; }
            let tm = 0.25 + 1.0 / 12.0; // diagonal: gcd²/(j²) = 1
            if tm > worst_tm {
                worst_tm = tm;
                worst_pair = (j, j);
                worst_lcm = j;
            }
        }

        println!("  {:>8} {:>10.6} {:>14} {:>12}",
            n, worst_tm, format!("({},{})", worst_pair.0, worst_pair.1), worst_lcm);
    }

    println!();
    println!("  ┌─────────────────────────────────────────────────────────┐");
    println!("  │  RESULT: worst_tm = 1/3 ≈ 0.333333 for ALL N.         │");
    println!("  │  T does NOT need to grow with N.                       │");
    println!("  └─────────────────────────────────────────────────────────┘");
    println!();

    // ═══════════════════════════════════════════════════════════
    // PART 4: Empirical T recommendation
    // ═══════════════════════════════════════════════════════════
    println!("═══════════════════════════════════════════════════════════════");
    println!("PART 4: RECOMMENDED T VALUES (empirically calibrated)");
    println!("═══════════════════════════════════════════════════════════════");
    println!();

    // Calibrate from G[2,2] at T=100K vs reference
    let cal_t = 100_000usize;
    let cal_val = gram::gram_entry_fast_at_t(2, 2, &ln_table, cal_t);
    let cal_err = Float::with_val(REFERENCE_PREC, &cal_val - &references[0]).to_f64().abs();
    let tm_worst = 1.0 / 3.0;

    // Empirical: error ≈ C · tm / T^α, measure α from two points
    let cal_val2 = gram::gram_entry_fast_at_t(2, 2, &ln_table, 200_000);
    let cal_err2 = Float::with_val(REFERENCE_PREC, &cal_val2 - &references[0]).to_f64().abs();
    let alpha = if cal_err2 > 0.0 && cal_err > 0.0 {
        (cal_err / cal_err2).ln() / (200_000.0f64 / 100_000.0).ln()
    } else { 2.0 };
    let cal_c = cal_err * (cal_t as f64).powf(alpha) / tm_worst;

    println!("  Empirical calibration (G[2,2]):");
    println!("    err@100K = {:.3e}, err@200K = {:.3e}", cal_err, cal_err2);
    println!("    Measured decay exponent α = {:.2}", alpha);
    println!("    Fitted C = {:.3e}", cal_c);
    println!();

    println!("  ┌──────────────────┬────────┬───────────────┐");
    println!("  │ Precision Target │ Digits │ T needed      │");
    println!("  ├──────────────────┼────────┼───────────────┤");
    for (label, digits) in [
        ("FP32", 7), ("FP64", 16), ("DD (solve)", 21), ("DD (full)", 31),
    ] {
        let eps = 10.0f64.powi(-(digits as i32));
        let t_needed = ((cal_c * tm_worst / eps).powf(1.0 / alpha)) as u64;
        println!("  │ {:<16} │ {:>6} │ {:>13} │",
            label, digits, format_t(t_needed as usize));
    }
    println!("  └──────────────────┴────────┴───────────────┘");
    println!();

    // ═══════════════════════════════════════════════════════════
    // PART 5: GPU precision-vs-size tradeoff
    // ═══════════════════════════════════════════════════════════
    println!("═══════════════════════════════════════════════════════════════");
    println!("PART 5: GPU PRECISION-vs-SIZE TRADEOFF");
    println!("═══════════════════════════════════════════════════════════════");
    println!();

    let n_target = 55440usize;
    let dim = n_target - 1;
    let kappa_log10 = 20.0;

    println!("  ┌──────────┬──────────────┬──────────────┬──────────────┐");
    println!("  │ Storage  │ Entry digits │ VRAM (N={}) │ Solve digits │", n_target);
    println!("  ├──────────┼──────────────┼──────────────┼──────────────┤");
    for (storage, entry_digits, bytes_per) in [
        ("FP16", 3.5f64, 2u64),
        ("FP32", 7.0, 4),
        ("FP64", 16.0, 8),
        ("DD", 31.0, 16),
    ] {
        let vram_gb = (dim as f64 * dim as f64 * bytes_per as f64) / (1024.0 * 1024.0 * 1024.0);
        let solve_digits = entry_digits - kappa_log10;
        let solve_str = if solve_digits <= 0.0 {
            "NONE ✗".to_string()
        } else {
            format!("{:.0} ✓", solve_digits)
        };
        println!("  │ {:<8} │ {:>12.1} │ {:>9.1} GB │ {:>12} │",
            storage, entry_digits, vram_gb, solve_str);
    }
    println!("  └──────────┴──────────────┴──────────────┴──────────────┘");
    println!();
    println!("  → DD build + CPU OOC Cholesky is the only viable path.");
    println!();

    // ═══════════════════════════════════════════════════════════
    // PART 6: Compare T=200K (default) vs T=2M (reference)
    // ═══════════════════════════════════════════════════════════
    println!("═══════════════════════════════════════════════════════════════");
    println!("PART 6: CURRENT DEFAULT T=200K vs REFERENCE");
    println!("═══════════════════════════════════════════════════════════════");
    println!();
    println!("  {:>12} {:>18} {:>18} {:>12}", "(j,k)", "G @ T=200K", "G @ T=2M", "error");
    println!("  {:>12} {:>18} {:>18} {:>12}", "────────────", "──────────────────", "──────────────────", "────────────");

    let check_pairs = vec![(2,2), (2,3), (100,100), (1000,1000)];
    let check_results: Vec<_> = check_pairs.par_iter()
        .map(|&(j, k)| {
            let v200k = gram::gram_entry_fast_at_t(j, k, &ln_table, 200_000);
            let v2m = gram::gram_entry_fast_at_t(j, k, &ln_table, t_ref);
            let err = Float::with_val(REFERENCE_PREC, &v200k - &v2m).to_f64().abs();
            (j, k, v200k.to_f64(), v2m.to_f64(), err)
        })
        .collect();

    for (j, k, v200k, v2m, err) in check_results {
        println!("  {:>12} {:>18.16} {:>18.16} {:>12.3e}",
            format!("({},{})", j, k), v200k, v2m, err);
    }
    println!();

    // ═══════════════════════════════════════════════════════════
    // SUMMARY
    // ═══════════════════════════════════════════════════════════
    println!("╔══════════════════════════════════════════════════════════════╗");
    println!("║  SUMMARY                                                   ║");
    println!("╠══════════════════════════════════════════════════════════════╣");
    println!("║  • Empirical decay: error ∝ T^{{-{:.1}}}                     ║", alpha);
    println!("║  • T does NOT scale with N (worst tm = 1/3 always)         ║");
    println!("║  • T=200K default: ~{:.0} correct digits per entry          ║",
        if cal_err2 > 0.0 { -cal_err2.log10() } else { 50.0 });
    println!("║  • Only DD (31-digit) build gives useful Cholesky digits   ║");
    println!("╚══════════════════════════════════════════════════════════════╝");
    println!();
}

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
