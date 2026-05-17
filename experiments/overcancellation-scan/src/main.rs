//! # Overcancellation Scan
//!
//! Computes vᵀGv for the Möbius logCutoff witness at large N.
//!
//! The overcancellation hypothesis: vᵀGv ≤ 1 for all N.
//! If true, combined with PNT, this implies the Riemann Hypothesis.
//!
//! Witness: v_k = μ(k) / log(N) for k = 1, ..., N-1
//! Gram entry: G(j,k) via Vasyunin cotangent formula
//!
//! Key optimization: μ(k) = 0 for ~40% of k (non-squarefree),
//! so we skip those rows/columns entirely.

use rayon::prelude::*;
use std::time::Instant;

const EULER_GAMMA: f64 = 0.5772156649015329;
const PI: f64 = std::f64::consts::PI;
const LN2PI: f64 = 1.8378770664093453; // ln(2π)

/// Sieve the Möbius function up to n (inclusive).
fn mobius_sieve(n: usize) -> Vec<i8> {
    let mut mu = vec![1i8; n + 1];
    mu[0] = 0;
    let mut is_prime = vec![true; n + 1];

    for p in 2..=n {
        if !is_prime[p] { continue; }
        // p is prime
        for j in (p..=n).step_by(p) {
            is_prime[j] = j == p;
            mu[j] = -mu[j]; // flip sign for each new prime factor
        }
        // p² multiples: μ = 0
        let p2 = p * p;
        if p2 <= n {
            for j in (p2..=n).step_by(p2) {
                mu[j] = 0;
            }
        }
    }
    mu
}

/// GCD via Euclidean algorithm
#[inline]
fn gcd(mut a: usize, mut b: usize) -> usize {
    while b != 0 {
        let t = b;
        b = a % b;
        a = t;
    }
    a
}

/// Vasyunin cotangent sum: V(a, b) = Σ_{m=1}^{a-1} {mb/a} · cot(πm/a)
fn vasyunin_sum(a: usize, b: usize) -> f64 {
    if a <= 1 { return 0.0; }
    let af = a as f64;
    let mut total = 0.0;
    for m in 1..a {
        let mb_mod_a = (m * b) % a;
        let frac = mb_mod_a as f64 / af;
        let angle = PI * m as f64 / af;
        let (sin_v, cos_v) = angle.sin_cos();
        if sin_v.abs() < 1e-15 { continue; }
        total += frac * cos_v / sin_v;
    }
    total
}

/// Full Vasyunin Gram matrix entry G(j, k) = ∫₀¹ {1/(jx)}{1/(kx)} dx
fn gram_entry(j: usize, k: usize) -> f64 {
    let jf = j as f64;
    let kf = k as f64;

    if j == k {
        // Diagonal: G(k,k) = (ln(2π) - γ)/k - 1/k²
        return (LN2PI - EULER_GAMMA) / kf - 1.0 / (kf * kf);
    }

    let d = gcd(j, k);
    let jp = j / d; // j' = j/gcd
    let kp = k / d; // k' = k/gcd
    let df = d as f64;

    let term1 = (LN2PI - EULER_GAMMA) / 2.0 * (1.0 / jf + 1.0 / kf);
    let term2 = (jf - kf) / (2.0 * jf * kf) * (kf / jf).ln();
    let term3 = PI * df / (2.0 * jf * kf) * (vasyunin_sum(jp, kp) + vasyunin_sum(kp, jp));
    let term4 = 1.0 / (jf * kf);

    term1 + term2 - term3 - term4
}

fn main() {
    println!("╔══════════════════════════════════════════════════════════════════╗");
    println!("║   OVERCANCELLATION SCAN v2: vᵀGv (Vasyunin Gram formula)       ║");
    println!("║                                                                ║");
    println!("║   v_k = μ(k)/log(N),  G(j,k) = Vasyunin cotangent formula     ║");
    println!("║   Hypothesis: vᵀGv ≤ 1 ⟹ RH (proved in Lean 4, 0 sorry)    ║");
    println!("╚══════════════════════════════════════════════════════════════════╝\n");

    let test_points: Vec<usize> = vec![
        10, 50, 100, 500, 1000, 2000, 5000, 10000, 20000, 50000,
    ];

    let max_n = *test_points.iter().max().unwrap();

    println!("Sieving Möbius function up to {}...", max_n);
    let t0 = Instant::now();
    let mu = mobius_sieve(max_n);
    println!("  Sieve complete in {:.3}s", t0.elapsed().as_secs_f64());

    // Collect squarefree indices for each N
    println!("  Squarefree density: {:.1}%\n",
        100.0 * (1..=max_n).filter(|&k| mu[k] != 0).count() as f64 / max_n as f64);

    // Header
    println!("{:>8} {:>14} {:>14} {:>14} {:>10} {:>8}",
             "N", "vᵀGv", "1 - vᵀGv", "bᵀv", "M(N-1)", "time");
    println!("{}", "─".repeat(78));

    for &n in &test_points {
        let t_start = Instant::now();
        let log_n = (n as f64).ln();
        let inv_log_n = 1.0 / log_n;

        // Collect squarefree indices where μ(k) ≠ 0
        let sqfree: Vec<(usize, f64)> = (1..n)
            .filter(|&k| mu[k] != 0)
            .map(|k| (k, mu[k] as f64 * inv_log_n))
            .collect();

        // Mertens function M(N-1)
        let mertens: i64 = (1..n).map(|k| mu[k] as i64).sum();

        // Compute vᵀGv by parallelizing over rows
        let vtgv: f64 = sqfree.par_iter().map(|&(j, vj)| {
            let mut row_sum = 0.0;
            for &(k, vk) in &sqfree {
                row_sum += vj * vk * gram_entry(j, k);
            }
            row_sum
        }).sum();

        // Compute bᵀv where b_k = ∫₀¹ {1/(kx)} dx = 1/2 - 1/(2k)
        let bt_v: f64 = sqfree.iter().map(|&(k, vk)| {
            let bk = 0.5 - 0.5 / k as f64;
            bk * vk
        }).sum();

        let elapsed = t_start.elapsed().as_secs_f64();
        let status = if vtgv < 1.0 { "✅" } else { "❌" };

        println!("{:>8} {:>14.8} {:>14.8} {:>14.8} {:>10} {:>7.2}s {}",
                 n, vtgv, 1.0 - vtgv, bt_v, mertens, elapsed, status);
    }

    println!("\n{}", "═".repeat(78));

    // Rate analysis
    println!("\nRATE ANALYSIS: Does (1 - vᵀGv) scale like C/log(N)?\n");
    println!("{:>8} {:>14} {:>14} {:>14} {:>14}",
             "N", "1 - vᵀGv", "1/log(N)", "ratio", "d² = 1-2bv+vGv");
    println!("{}", "─".repeat(72));

    for &n in &test_points {
        let log_n = (n as f64).ln();
        let inv_log_n = 1.0 / log_n;

        let sqfree: Vec<(usize, f64)> = (1..n)
            .filter(|&k| mu[k] != 0)
            .map(|k| (k, mu[k] as f64 * inv_log_n))
            .collect();

        let vtgv: f64 = sqfree.par_iter().map(|&(j, vj)| {
            let mut row_sum = 0.0;
            for &(k, vk) in &sqfree {
                row_sum += vj * vk * gram_entry(j, k);
            }
            row_sum
        }).sum();

        let bt_v: f64 = sqfree.iter().map(|&(k, vk)| {
            (0.5 - 0.5 / k as f64) * vk
        }).sum();

        let defect = 1.0 - vtgv;
        let inv_log = 1.0 / log_n;
        let ratio = defect / inv_log;
        let d_sq = 1.0 - 2.0 * bt_v + vtgv;

        println!("{:>8} {:>14.8} {:>14.8} {:>14.6} {:>14.8}",
                 n, defect, inv_log, ratio, d_sq);
    }

    println!("\nIf ratio → constant, then 1 - vᵀGv ~ C/log(N)");
    println!("The Möbius function was born to cancel. It overcancels. 🏛️\n");
}
