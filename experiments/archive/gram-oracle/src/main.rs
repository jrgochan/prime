#![allow(unused, dead_code)]
//! # Gram Oracle: Numerical Verification of bd_gram_form_bound
//!
//! Computes the Báez-Duarte L² error:
//!   E(N) = 1 - 2·bᵀv + vᵀGv
//!
//! where:
//!   v_k = -μ(k)·ln(N/k) / (k·ln N)   (BD Möbius weights)
//!   b_k = ∫₀¹ {1/(kx)} dx             (Vasyunin mean vector)
//!   G_{jk} = ∫₀¹ {1/(jx)}·{1/(kx)} dx (Vasyunin Gram matrix)
//!
//! Goal: Verify that E(N) ≤ C / ln(N) for some explicit C,
//! supporting the axiom `bd_gram_form_bound`.

use rayon::prelude::*;
use std::f64::consts::PI;

const EULER_GAMMA: f64 = 0.5772156649015329;

// ═══════════════════════════════════════
// §1. MÖBIUS FUNCTION via SIEVE
// ═══════════════════════════════════════

/// Compute μ(k) for k = 0..n via sieve of Eratosthenes variant
fn mobius_sieve(n: usize) -> Vec<i32> {
    let mut mu = vec![0i32; n + 1];
    let mut is_prime = vec![true; n + 1];
    let mut prime_count = vec![0u32; n + 1]; // number of distinct prime factors
    let mut square_free = vec![true; n + 1];

    mu[1] = 1;

    for p in 2..=n {
        if !is_prime[p] {
            continue;
        }
        // p is prime
        for multiple in (p..=n).step_by(p) {
            is_prime[multiple] = multiple == p;
            prime_count[multiple] += 1;
        }
        // Mark multiples of p² as not square-free
        let p2 = p * p;
        if p2 <= n {
            for multiple in (p2..=n).step_by(p2) {
                square_free[multiple] = false;
            }
        }
    }

    for k in 1..=n {
        if !square_free[k] {
            mu[k] = 0;
        } else {
            mu[k] = if prime_count[k].is_multiple_of(2) { 1 } else { -1 };
        }
    }

    mu
}

// ═══════════════════════════════════════
// §2. BD MÖBIUS WEIGHTS
// ═══════════════════════════════════════

/// v_k = -μ(k) · ln(N/k) / (k · ln(N))
fn bd_weights(n: usize, mu: &[i32]) -> Vec<f64> {
    let ln_n = (n as f64).ln();
    (1..n)
        .map(|k| {
            let mu_k = mu[k] as f64;
            -mu_k * ((n as f64) / (k as f64)).ln() / ((k as f64) * ln_n)
        })
        .collect()
}

// ═══════════════════════════════════════
// §3. VASYUNIN MEAN VECTOR
// ═══════════════════════════════════════

/// b_k = ∫₀¹ {1/(kx)} dx
///
/// Using the exact formula: ∫₀¹ {θ/x} dx = 1 - γ + Σ_{n=1}^{⌊θ⌋} (1/n - ln((n+1)/n)·θ/n)
/// For θ = 1/k:
///   When k ≥ 1: ∫₀¹ {1/(kx)} dx computed via substitution u = 1/(kx):
///   = (1/k) ∫₁^∞ {u} / u² du = (1/k) Σ_{n=1}^∞ ∫_n^{n+1} (u-n)/u² du
///   = (1/k) Σ_{n=1}^∞ [ln((n+1)/n) - 1/(n+1)]
///   = (1/k) [1 - γ]  (by standard identity)
///
/// Actually: ∫₀¹ {1/(kx)} dx = 1 - γ - (H_k - ln k - γ)/k + correction
/// Simplest: compute numerically via quadrature
fn vasyunin_mean(k: usize) -> f64 {
    // High-precision quadrature: ∫₀¹ {1/(kx)} dx
    let n_points = 100_000;
    let mut sum = 0.0f64;
    for i in 0..n_points {
        let x = (i as f64 + 0.5) / n_points as f64;
        let val = 1.0 / (k as f64 * x);
        let frac = val - val.floor();
        sum += frac;
    }
    sum / n_points as f64
}

// ═══════════════════════════════════════
// §4. VASYUNIN GRAM MATRIX
// ═══════════════════════════════════════

/// G_{jk} = ∫₀¹ {1/(jx)} · {1/(kx)} dx
///
/// The Vasyunin exact formula uses cotangent sums, but for numerical
/// verification, high-precision quadrature suffices.
fn vasyunin_gram_entry(j: usize, k: usize) -> f64 {
    let n_points = 50_000; // Sufficient for our precision needs
    let mut sum = 0.0f64;
    for i in 0..n_points {
        let x = (i as f64 + 0.5) / n_points as f64;
        let val_j = 1.0 / (j as f64 * x);
        let frac_j = val_j - val_j.floor();
        let val_k = 1.0 / (k as f64 * x);
        let frac_k = val_k - val_k.floor();
        sum += frac_j * frac_k;
    }
    sum / n_points as f64
}

// ═══════════════════════════════════════
// §5. THE COMPUTATION
// ═══════════════════════════════════════

/// Compute E(N) = 1 - 2·bᵀv + vᵀGv
fn compute_error(n: usize) -> (f64, f64, f64, f64) {
    let mu = mobius_sieve(n);
    let v = bd_weights(n, &mu);
    let dim = v.len(); // N-1

    eprintln!("  N={}: Computing mean vector (dim={})...", n, dim);

    // Compute bᵀv
    let bt_v: f64 = (0..dim)
        .into_par_iter()
        .map(|i| {
            let k = i + 1;
            vasyunin_mean(k) * v[i]
        })
        .sum();

    eprintln!("  N={}: Computing Gram quadratic form...", n);

    // Compute vᵀGv using parallel rows
    let vt_gv: f64 = (0..dim)
        .into_par_iter()
        .map(|i| {
            let j = i + 1;
            let mut row_sum = 0.0f64;
            for q in 0..dim {
                let k = q + 1;
                if v[i].abs() < 1e-15 || v[q].abs() < 1e-15 {
                    continue;
                }
                row_sum += v[q] * vasyunin_gram_entry(j, k);
            }
            v[i] * row_sum
        })
        .sum();

    let error = 1.0 - 2.0 * bt_v + vt_gv;
    let ln_n = (n as f64).ln();
    let ratio = error * ln_n;

    (error, bt_v, vt_gv, ratio)
}

// ═══════════════════════════════════════
// §6. MERTENS FUNCTION CHECK
// ═══════════════════════════════════════

fn mertens_function(n: usize, mu: &[i32]) -> i64 {
    mu[1..=n].iter().map(|&m| m as i64).sum()
}

fn main() {
    println!("╔══════════════════════════════════════════════════════╗");
    println!("║  GRAM ORACLE: bd_gram_form_bound Verification       ║");
    println!("║  E(N) = 1 - 2bᵀv + vᵀGv  vs  C/ln(N)              ║");
    println!("╚══════════════════════════════════════════════════════╝");
    println!();

    // Compute Mertens function to find C_m
    let max_n = 10000;
    let mu = mobius_sieve(max_n);

    println!("═══ Mertens Function Check ═══");
    let mut max_mertens_ratio = 0.0f64;
    for &n in &[100, 500, 1000, 2000, 5000, 10000] {
        let m = mertens_function(n, &mu);
        let bound = (n as f64).sqrt() * ((n as f64).ln()).powi(2);
        let ratio = (m as f64).abs() / bound;
        if ratio > max_mertens_ratio {
            max_mertens_ratio = ratio;
        }
        println!(
            "  M({:>5}) = {:>5}  |M|/√N·log²N = {:.6}  bound = {:.1}",
            n, m, ratio, bound
        );
    }
    println!("  Max C_m ratio: {:.6}", max_mertens_ratio);
    println!();

    // Compute E(N) for various N
    println!("═══ Gram Form Error E(N) = 1 - 2bᵀv + vᵀGv ═══");
    println!(
        "{:>6} {:>12} {:>12} {:>12} {:>12} {:>12}",
        "N", "E(N)", "bᵀv", "vᵀGv", "1/ln(N)", "E·ln(N)"
    );
    println!("{}", "-".repeat(78));

    let test_ns: Vec<usize> = vec![10, 20, 30, 50, 75, 100, 150, 200, 300, 500];

    for &n in &test_ns {
        let (error, bt_v, vt_gv, ratio) = compute_error(n);
        let inv_ln = 1.0 / (n as f64).ln();
        println!(
            "{:>6} {:>12.8} {:>12.8} {:>12.8} {:>12.8} {:>12.6}",
            n, error, bt_v, vt_gv, inv_ln, ratio
        );
    }

    println!();
    println!("═══ Analysis ═══");
    println!("If E(N)·ln(N) → C as N → ∞, then bd_gram_form_bound holds with constant C.");
    println!("The axiom requires C ≤ (C_m + 1)².");
    println!();
    println!("The Gram Oracle has spoken. 🔮");
}
