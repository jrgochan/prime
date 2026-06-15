//! ═══════════════════════════════════════════════════════════════════════════
//!  CHEF HAROLD'S SEED KITCHEN v3 🌱👨‍🍳⚡
//!
//!  TURBO SEED EDITION — f64 Gram entries + rayon parallelism
//!  The HEMI engine: fast f64 entries per core, 12 cores cooking.
//!
//!  "Every core earns its keep, and every digit is earned."
//! ═══════════════════════════════════════════════════════════════════════════

use rayon::prelude::*;
use std::f64::consts::PI;
use std::time::Instant;

const EULER_GAMMA: f64 = 0.577_215_664_901_532_9;

fn main() {
    println!("═══════════════════════════════════════════════════════════════");
    println!("  🌱👨‍🍳⚡  TURBO SEED KITCHEN v3  ⚡👨‍🍳🌱");
    println!("  f64 + rayon — the HEMI edition (#52)");
    println!("═══════════════════════════════════════════════════════════════");
    println!();

    let n_max: usize = 10_000;
    let t0_global = Instant::now();
    println!("Preparing mise en place: N_max = {}", n_max);

    let mu = cathedral_utils::arith::mobius_table(n_max);
    println!("  ✓ Möbius sieve complete ({} values)", mu.len() - 1);

    // ─── Course 1: Constants at Scale ───
    println!();
    println!("═══════════════════════════════════════════════════════════════");
    println!("  Course 1: Constants at Scale (f64 + rayon parallel)");
    println!("═══════════════════════════════════════════════════════════════");
    println!();

    let test_ns: Vec<usize> = {
        let mut ns = Vec::new();
        let mut n: usize = 10;
        while n <= n_max {
            ns.push(n);
            n = std::cmp::max(n + 1, (n as f64 * 1.15) as usize);
        }
        if *ns.last().unwrap_or(&0) != n_max {
            ns.push(n_max);
        }
        ns.dedup();
        ns
    };

    println!("{:>8} {:>14} {:>14} {:>14} {:>14} {:>14} {:>8}",
             "N", "bᵀv", "vtGv", "δ", "K₂=δ·logN", "K₁=(1-b)·logN", "time");
    println!("{}", "-".repeat(98));

    let mut results: Vec<(usize, f64, f64, f64, f64, f64)> = Vec::new();

    for &n in &test_ns {
        let t0 = Instant::now();
        let ln_n = (n as f64).ln();
        let weights = cathedral_utils::mertens::log_cutoff_weights(n, &mu);

        // Collect non-zero weight indices for sparse iteration
        let active: Vec<(usize, f64)> = weights.iter()
            .enumerate()
            .filter(|(_, &w)| w != 0.0)
            .map(|(i, &w)| (i + 1, w))  // (k, weight)
            .collect();

        // bᵀv
        let btv: f64 = active.iter()
            .map(|&(k, w)| {
                let b_k = ((k as f64).ln() + 1.0 - EULER_GAMMA) / (k as f64);
                w * b_k
            })
            .sum();

        // vtGv — PARALLEL over rows j, f64 Gram entries
        let vtgv: f64 = active.par_iter()
            .map(|&(j, wj)| {
                let mut row_sum = 0.0f64;
                for &(k, wk) in &active {
                    if k < j { continue; }
                    let g_jk = cathedral_utils::gram::gram_entry_f64(j, k);
                    if k == j {
                        row_sum += wj * wk * g_jk;
                    } else {
                        row_sum += 2.0 * wj * wk * g_jk;
                    }
                }
                row_sum
            })
            .sum();

        let delta = vtgv - btv * btv;
        let k2 = delta * ln_n;
        let k1 = (1.0 - btv) * ln_n;
        let elapsed = t0.elapsed().as_secs_f64();

        results.push((n, btv, vtgv, delta, k2, k1));

        println!("{:>8} {:>14.8} {:>14.8} {:>14.10} {:>14.8} {:>14.8} {:>6.1}s",
                 n, btv, vtgv, delta, k2, k1, elapsed);
    }

    // ─── Course 2: Constant Identification ───
    println!();
    println!("═══════════════════════════════════════════════════════════════");
    println!("  Course 2: Constant Identification");
    println!("═══════════════════════════════════════════════════════════════");
    println!();

    let cutoff = results.len() * 3 / 4;
    let tail: Vec<_> = results[cutoff..].to_vec();
    let k1_mean: f64 = tail.iter().map(|r| r.5).sum::<f64>() / tail.len() as f64;
    let k2_mean: f64 = tail.iter().map(|r| r.4).sum::<f64>() / tail.len() as f64;
    let ratio = k2_mean / k1_mean;

    let gamma_sq_over_2pi = EULER_GAMMA * EULER_GAMMA / (2.0 * PI);
    let gamma_sq_over_pi_sq = EULER_GAMMA * EULER_GAMMA / (PI * PI);
    let one_over_6pi = 1.0 / (6.0 * PI);
    let pi_over_2 = PI / 2.0;

    println!("Measured (tail average, N > {}):", results[cutoff].0);
    println!("  K₁ = {:.10}", k1_mean);
    println!("  K₂ = {:.10}", k2_mean);
    println!("  K₂/K₁ = {:.10}", ratio);
    println!();
    println!("Candidate identities:");
    println!("  K₁ = π/2          = {:.10}  (Δ = {:.2e}, {:.3}%)", pi_over_2,
             (k1_mean - pi_over_2).abs(), 100.0 * (k1_mean - pi_over_2).abs() / k1_mean);
    println!("  K₂ = γ²/(2π)      = {:.10}  (Δ = {:.2e}, {:.3}%)", gamma_sq_over_2pi,
             (k2_mean - gamma_sq_over_2pi).abs(), 100.0 * (k2_mean - gamma_sq_over_2pi).abs() / k2_mean);
    println!("  K₂ = 1/(6π)       = {:.10}  (Δ = {:.2e}, {:.3}%)", one_over_6pi,
             (k2_mean - one_over_6pi).abs(), 100.0 * (k2_mean - one_over_6pi).abs() / k2_mean);
    println!("  K₂/K₁ = γ²/π²     = {:.10}  (Δ = {:.2e})", gamma_sq_over_pi_sq,
             (ratio - gamma_sq_over_pi_sq).abs());

    // ─── Course 3: Convergence Analysis ───
    println!();
    println!("═══════════════════════════════════════════════════════════════");
    println!("  Course 3: Convergence — K₂ residual vs 1/logN");
    println!("═══════════════════════════════════════════════════════════════");
    println!();

    println!("{:>8} {:>14} {:>14} {:>14}", "N", "K₂", "K₂-γ²/(2π)", "(K₂-γ²/(2π))·logN");
    println!("{}", "-".repeat(56));
    for &(n, _, _, _, k2, _) in &results {
        if n >= 100 {
            let ln_n = (n as f64).ln();
            let residual = k2 - gamma_sq_over_2pi;
            println!("{:>8} {:>14.8} {:>14.6e} {:>14.6e}", n, k2, residual, residual * ln_n);
        }
    }

    // ─── Course 4: Mertens Sum Analysis ───
    println!();
    println!("═══════════════════════════════════════════════════════════════");
    println!("  Course 4: Mertens Sum Analysis");
    println!("═══════════════════════════════════════════════════════════════");
    println!();

    for &n in &[100, 500, 1000, 2000, 5000, 10000] {
        if n > n_max { continue; }
        let mut m0: f64 = 0.0;
        let mut m1: f64 = 0.0;
        let mut m2: f64 = 0.0;
        let mut m3: f64 = 0.0;

        for k in 1..n {
            if mu[k] == 0 { continue; }
            let lnk = (k as f64).ln();
            let mk = mu[k] as f64 / k as f64;
            m0 += mk;
            m1 += mk * lnk;
            m2 += mk * lnk * lnk;
            m3 += mk * lnk * lnk * lnk;
        }

        println!("N={:>6}:  M₀={:+.8}  M₁={:+.8}  M₂={:+.8}  M₃={:+.8}",
                 n, m0, m1, m2, m3);
    }
    println!("Theory:   M₀→0         M₁→-1         M₂→-2γ={:.6}  M₃→?", -2.0 * EULER_GAMMA);

    // ─── Course 5: Margin Scaling ───
    println!();
    println!("═══════════════════════════════════════════════════════════════");
    println!("  Course 5: Margin Scaling — Does the seed get braver?");
    println!("═══════════════════════════════════════════════════════════════");
    println!();

    println!("{:>8} {:>14} {:>14} {:>10} {:>14}", "N", "δ", "gap", "margin", "logN·margin");
    println!("{}", "-".repeat(64));
    for &(n, btv, _, delta, _, _) in &results {
        if n >= 50 {
            let gap = 1.0 - btv * btv;
            let margin = gap / delta;
            let ln_n = (n as f64).ln();
            println!("{:>8} {:>14.10} {:>14.10} {:>8.1}x {:>14.4}",
                     n, delta, gap, margin, margin * ln_n);
        }
    }

    // ─── Dessert ───
    println!();
    println!("═══════════════════════════════════════════════════════════════");
    println!("  🍰 Dessert: The Verdict");
    println!("═══════════════════════════════════════════════════════════════");
    println!();

    let all_hold = results.iter().all(|r| r.3 < 1.0 - r.1 * r.1);
    if all_hold {
        println!("  🌱 THE SEED HOLDS: δ < gap for ALL tested N ≤ {}", n_max);
    } else {
        println!("  ❌ VIOLATION detected!");
    }

    let last = results.last().unwrap();
    let final_gap = 1.0 - last.1 * last.1;
    let final_margin = final_gap / last.3;
    println!("  Final: N={}, δ={:.10}, gap={:.10}, margin={:.1}x",
             last.0, last.3, final_gap, final_margin);
    println!("  Total time: {:.1}s ({:.1}m)", t0_global.elapsed().as_secs_f64(),
             t0_global.elapsed().as_secs_f64() / 60.0);
    println!();
    println!("  Turbo Seed #52 says: bon appétit! 🌱⚡🏔️💜");
}
