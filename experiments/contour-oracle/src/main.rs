//! # Contour Oracle: The Three-Term Decomposition Experiment
//!
//! Numerically verifies the Theorist's prediction:
//!
//! The Mellin integral on the critical line decomposes as:
//!   (1/2π) ∫ |1 - ζ(1/2+it) W_N(1/2+it)|² / |1/2+it|² dt
//!   = Term1 - 2·Term2 + Term3
//!
//! where:
//!   Term1 = (1/2π) ∫ 1/|s|² dt → 2 (exact)
//!   Term2 = (1/2π) ∫ Re(ζ·W_N)/|s|² dt → 2 (so 2·Term2 → 4)
//!   Term3 = (1/2π) ∫ |ζ·W_N|²/|s|² dt → 2 + O(1/log N)
//!
//! The interference: 2 - 4 + 2 = 0, leaving O(1/log N).

use num_complex::Complex64;
use rayon::prelude::*;
use std::f64::consts::PI;

/// Approximate ζ(s) using the Euler-Maclaurin formula with N_terms terms.
/// For Re(s) > 0, we use the functional equation reflection.
fn zeta_approx(s: Complex64, n_terms: usize) -> Complex64 {
    // For s on the critical line (Re(s) = 1/2), use the approximate
    // functional equation: ζ(s) ≈ Σ_{n≤N} n^{-s} + χ(s) Σ_{n≤N} n^{-(1-s)}
    // where χ(s) = π^{s-1/2} Γ((1-s)/2) / Γ(s/2)
    //
    // For simplicity, use the partial Dirichlet series with enough terms:
    // ζ(s) ≈ Σ_{n=1}^{N} n^{-s} + N^{1-s}/(s-1) + N^{-s}/2
    //       - s/(12·N^{s+1}) + ... (Euler-Maclaurin)

    let n = n_terms as f64;

    // Partial sum
    let mut sum = Complex64::new(0.0, 0.0);
    for k in 1..=n_terms {
        sum += Complex64::new(k as f64, 0.0).powc(-s);
    }

    // Euler-Maclaurin correction terms
    let n_c = Complex64::new(n, 0.0);
    let correction = n_c.powc(Complex64::new(1.0, 0.0) - s) / (s - Complex64::new(1.0, 0.0))
        + n_c.powc(-s) * Complex64::new(0.5, 0.0)
        - s * n_c.powc(-s - Complex64::new(1.0, 0.0)) / Complex64::new(12.0, 0.0);

    sum + correction
}

/// Compute the BD Möbius weights: v_k = (μ(k)/k) · (1 - log(k)/log(N))
fn moebius(n: usize) -> i64 {
    if n == 1 { return 1; }
    let mut n = n;
    let mut factors = 0i64;
    let mut d = 2;
    while d * d <= n {
        if n % d == 0 {
            n /= d;
            factors += 1;
            if n % d == 0 { return 0; } // square factor
        }
        d += 1;
    }
    if n > 1 { factors += 1; }
    if factors % 2 == 0 { 1 } else { -1 }
}

fn bd_weight(k: usize, n_bd: usize) -> f64 {
    let mu = moebius(k) as f64;
    let log_n = (n_bd as f64).ln();
    if log_n == 0.0 { return 0.0; }
    mu / (k as f64) * (1.0 - (k as f64).ln() / log_n)
}

/// W_N(s) = Σ_{k=1}^{N-1} v_k · k^{-s}
fn dirichlet_poly(s: Complex64, n_bd: usize) -> Complex64 {
    let mut sum = Complex64::new(0.0, 0.0);
    for k in 1..n_bd {
        let vk = bd_weight(k, n_bd);
        if vk.abs() > 1e-15 {
            sum += Complex64::new(vk, 0.0) * Complex64::new(k as f64, 0.0).powc(-s);
        }
    }
    sum
}

/// Compute the three integrals for a given N and truncation T.
fn compute_three_terms(n_bd: usize, t_max: f64, n_points: usize, zeta_terms: usize) -> (f64, f64, f64, f64) {
    let dt = 2.0 * t_max / (n_points as f64);

    // Parallel computation with rayon
    let results: Vec<(f64, f64, f64, f64)> = (0..n_points)
        .into_par_iter()
        .map(|i| {
            let t = -t_max + (i as f64 + 0.5) * dt;
            let s = Complex64::new(0.5, t);
            let s_norm_sq = 0.25 + t * t;

            if s_norm_sq < 1e-12 { return (0.0, 0.0, 0.0, 0.0); }

            // ζ(s) and W_N(s)
            let zeta_s = zeta_approx(s, zeta_terms);
            let w_n = dirichlet_poly(s, n_bd);
            let zeta_w = zeta_s * w_n;

            // Term 1: 1/|s|²
            let t1 = 1.0 / s_norm_sq;

            // Term 2: Re(ζ·W_N)/|s|²
            let t2 = zeta_w.re / s_norm_sq;

            // Term 3: |ζ·W_N|²/|s|²
            let t3 = zeta_w.norm_sqr() / s_norm_sq;

            // Total: |1 - ζW|²/|s|²
            let residual = Complex64::new(1.0, 0.0) - zeta_w;
            let total = residual.norm_sqr() / s_norm_sq;

            (t1 * dt, t2 * dt, t3 * dt, total * dt)
        })
        .collect();

    let mut sum1 = 0.0;
    let mut sum2 = 0.0;
    let mut sum3 = 0.0;
    let mut sum_total = 0.0;

    for (t1, t2, t3, tt) in results {
        sum1 += t1;
        sum2 += t2;
        sum3 += t3;
        sum_total += tt;
    }

    // Multiply by 1/(2π)
    let factor = 1.0 / (2.0 * PI);
    (sum1 * factor, sum2 * factor, sum3 * factor, sum_total * factor)
}

fn main() {
    println!("╔════════════════════════════════════════════════════════════╗");
    println!("║     CONTOUR ORACLE: Three-Term Decomposition Experiment  ║");
    println!("║     Verifying the Interference Pattern                   ║");
    println!("╚════════════════════════════════════════════════════════════╝");
    println!();

    let zeta_terms = 500;   // Terms in Euler-Maclaurin approximation
    let n_points = 500_000; // Integration points
    let t_max = 500.0;      // Truncation height

    println!("Parameters: ζ terms = {}, integration points = {}, T = {}", zeta_terms, n_points, t_max);
    println!();

    println!("┌──────┬──────────────┬──────────────┬──────────────┬──────────────┬──────────────┐");
    println!("│  N   │   Term 1     │  2·Term 2    │   Term 3     │ 1-2·2+3      │ Total (dir)  │");
    println!("│      │  (→ 2)       │  (→ 4)       │  (→ 2+ε)     │ (→ 0+ε)      │  d²_N        │");
    println!("├──────┼──────────────┼──────────────┼──────────────┼──────────────┼──────────────┤");

    for &n_bd in &[10, 20, 50, 100, 200, 500, 1000] {
        let (t1, t2, t3, total) = compute_three_terms(n_bd, t_max, n_points, zeta_terms);
        let reconstructed = t1 - 2.0 * t2 + t3;
        let log_n = (n_bd as f64).ln();

        println!(
            "│ {:>4} │ {:>12.8} │ {:>12.8} │ {:>12.8} │ {:>12.8} │ {:>12.8} │",
            n_bd, t1, 2.0 * t2, t3, reconstructed, total
        );

        // Also show the ratio to 1/log(N)
        if n_bd >= 20 {
            println!(
                "│      │              │              │              │ ×ln(N)={:>5.3} │ ×ln(N)={:>5.3} │",
                reconstructed * log_n, total * log_n
            );
        }
    }

    println!("└──────┴──────────────┴──────────────┴──────────────┴──────────────┴──────────────┘");
    println!();
    println!("The Theorist's prediction:");
    println!("  Term 1 → 2 (exact)");
    println!("  2·Term 2 → 4 (from below)");
    println!("  Term 3 → 2 (from above)");
    println!("  Interference: 2 - 4 + 2 = 0, residual = O(1/log N)");
}
