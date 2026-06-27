#![allow(clippy::needless_range_loop, clippy::doc_lazy_continuation)]
//! ═══════════════════════════════════════════════════════════════════════════
//!  PRIME FRACTAL SPECTRAL PROBE
//!
//!  Tests the multiplicative self-similarity of the Gram matrix:
//!    λ_min(G_N[mult of p]) ≈ (1/p) · λ_min(G_{N/p})
//!
//!  Pushes to N=100+ using the fast f64 Gram engine + LAPACK eigensolvers.
//!
//!  Key measurements:
//!  1. Self-similarity ratios for primes p=2,3,5,7
//!  2. Eigenvalue drop dichotomy (prime vs composite)
//!  3. Correction term decay with N
//!  4. Prime Fractal Dimension estimate: D where Σ p^{-D} = 1
//! ═══════════════════════════════════════════════════════════════════════════

use cathedral_utils::gram;
use rayon::prelude::*;

/// Build the (N-1)×(N-1) Gram matrix using fast f64 entries.
fn build_gram_f64(n: usize) -> Vec<f64> {
    let dim = n - 1;
    let mut g = vec![0.0f64; dim * dim];
    // Parallel row computation
    let rows: Vec<Vec<f64>> = (0..dim)
        .into_par_iter()
        .map(|i| {
            let j = i + 1;
            let mut row = vec![0.0f64; dim];
            for k_idx in i..dim {
                let k = k_idx + 1;
                let val = gram::gram_entry_f64(j, k);
                row[k_idx] = val;
            }
            row
        })
        .collect();
    // Fill symmetric matrix
    for i in 0..dim {
        for k_idx in i..dim {
            g[i * dim + k_idx] = rows[i][k_idx];
            g[k_idx * dim + i] = rows[i][k_idx];
        }
    }
    g
}

/// Extract submatrix for indices that are multiples of p.
/// G_N[mult of p] = G_{jp, kp} for j,k = 1,...,floor(N/p)
fn extract_prime_submatrix(g: &[f64], n: usize, p: usize) -> (Vec<f64>, usize) {
    let dim = n - 1;
    // Indices in 0-based that correspond to multiples of p
    // Index i in G corresponds to j = i+1, so multiples of p are i = p-1, 2p-1, 3p-1, ...
    let indices: Vec<usize> = (0..dim).filter(|&i| (i + 1) % p == 0).collect();
    let sub_dim = indices.len();
    if sub_dim == 0 {
        return (vec![], 0);
    }
    let mut sub = vec![0.0f64; sub_dim * sub_dim];
    for (si, &i) in indices.iter().enumerate() {
        for (sj, &j) in indices.iter().enumerate() {
            sub[si * sub_dim + sj] = g[i * dim + j];
        }
    }
    (sub, sub_dim)
}

/// Compute eigenvalues using symmetric eigenvalue decomposition (dsyev).
/// Returns sorted eigenvalues (ascending).
fn eigenvalues(matrix: &[f64], dim: usize) -> Vec<f64> {
    if dim == 0 {
        return vec![];
    }
    // Use nalgebra for eigenvalue computation
    let mat = nalgebra::DMatrix::from_row_slice(dim, dim, matrix);
    let eigen = mat.symmetric_eigen();
    let mut vals: Vec<f64> = eigen.eigenvalues.iter().copied().collect();
    vals.sort_by(|a, b| a.partial_cmp(b).unwrap());
    vals
}

/// Check if n is prime (simple trial division).
fn is_prime(n: usize) -> bool {
    if n < 2 { return false; }
    if n < 4 { return true; }
    if n.is_multiple_of(2) || n.is_multiple_of(3) { return false; }
    let mut i = 5;
    while i * i <= n {
        if n.is_multiple_of(i) || n.is_multiple_of(i + 2) { return false; }
        i += 6;
    }
    true
}

fn main() {
    let n_max: usize = std::env::args()
        .nth(1)
        .and_then(|s| s.parse().ok())
        .unwrap_or(80);

    println!("═══════════════════════════════════════════════════════════════");
    println!("  PRIME FRACTAL SPECTRAL PROBE — Rust/f64");
    println!("  N_max = {}", n_max);
    println!("═══════════════════════════════════════════════════════════════\n");

    // ═══════════════════════════════════════════════════════════════
    // Phase 1: Build Gram matrices and track λ_min
    // ═══════════════════════════════════════════════════════════════
    println!("Phase 1: λ_min(G_N) evolution");
    println!("─────────────────────────────────────────────────");

    let mut lambda_mins: Vec<(usize, f64)> = Vec::new();

    for n in 3..=n_max {
        let g = build_gram_f64(n);
        let dim = n - 1;
        let eigs = eigenvalues(&g, dim);
        let lmin = eigs[0];
        lambda_mins.push((n, lmin));
        if n <= 30 || n % 10 == 0 || is_prime(n) {
            println!(
                "  N={:4}: λ_min = {:.10e}  |  λ_min·ln(N) = {:.8}  {}",
                n,
                lmin,
                lmin * (n as f64).ln(),
                if is_prime(n) { "← PRIME" } else { "" }
            );
        }
    }
    println!();

    // ═══════════════════════════════════════════════════════════════
    // Phase 2: Self-similarity ratios for primes p=2,3,5,7
    // ═══════════════════════════════════════════════════════════════
    println!("Phase 2: Multiplicative self-similarity");
    println!("─────────────────────────────────────────────────");

    let primes_to_test = [2, 3, 5, 7, 11, 13, 17, 19, 23];

    for &p in &primes_to_test {
        println!("\n  Prime p = {}:", p);
        println!("  {:>6} {:>14} {:>14} {:>10} {:>10}",
                 "N", "λ_sub", "λ_ref", "ratio", "1/p");

        // Dynamic test schedule based on N_max
        let multipliers = [6, 8, 10, 12, 15, 20, 25, 30, 40, 50];
        for &m in &multipliers {
            let n = m * p;
            if n > n_max { continue; }
            let n_ref = n / p;
            if n_ref < 3 { continue; }

            let g_n = build_gram_f64(n);
            let (sub, sub_dim) = extract_prime_submatrix(&g_n, n, p);
            if sub_dim < 2 { continue; }

            let eigs_sub = eigenvalues(&sub, sub_dim);
            let lmin_sub = eigs_sub[0];

            // Reference: λ_min(G_{N/p})
            let g_ref = build_gram_f64(n_ref);
            let dim_ref = n_ref - 1;
            let eigs_ref = eigenvalues(&g_ref, dim_ref);
            let lmin_ref = eigs_ref[0];

            let ratio = if lmin_ref.abs() > 1e-20 { lmin_sub / lmin_ref } else { f64::NAN };
            let predicted = 1.0 / p as f64;

            println!(
                "  {:6} {:14.8e} {:14.8e} {:10.6} {:10.6}",
                n, lmin_sub, lmin_ref, ratio, predicted
            );
        }
    }
    println!();

    // ═══════════════════════════════════════════════════════════════
    // Phase 3: Eigenvalue drop dichotomy
    // ═══════════════════════════════════════════════════════════════
    println!("Phase 3: Eigenvalue drop δ_N (prime vs composite)");
    println!("─────────────────────────────────────────────────");
    println!("  {:>6} {:>14} {:>10} {:>8}", "N", "δ_N", "δ·N", "type");

    let mut prime_drops = Vec::new();
    let mut composite_drops = Vec::new();

    for i in 1..lambda_mins.len() {
        let (n, lmin) = lambda_mins[i];
        let (_, lmin_prev) = lambda_mins[i - 1];
        let delta = lmin_prev - lmin;
        let kind = if is_prime(n) { "PRIME" } else { "comp" };

        if is_prime(n) {
            prime_drops.push(delta);
        } else {
            composite_drops.push(delta);
        }

        if n <= 40 || (n <= n_max && (is_prime(n) || n % 10 == 0)) {
            println!(
                "  {:6} {:14.8e} {:10.6} {:>8}",
                n, delta, delta * n as f64, kind
            );
        }
    }

    let avg_prime = prime_drops.iter().sum::<f64>() / prime_drops.len() as f64;
    let avg_comp = composite_drops.iter().sum::<f64>() / composite_drops.len() as f64;
    println!("\n  Average prime drop:     {:.8e}", avg_prime);
    println!("  Average composite drop: {:.8e}", avg_comp);
    println!("  Ratio (prime/comp):     {:.2}x", avg_prime / avg_comp);
    println!();

    // ═══════════════════════════════════════════════════════════════
    // Phase 4: Correction term decay
    // ═══════════════════════════════════════════════════════════════
    println!("Phase 4: Self-similarity correction term decay");
    println!("─────────────────────────────────────────────────");
    println!("  For p=2: |λ_sub - (1/2)·λ_ref| vs N");

    let p = 2;
    for n in (10..=n_max).step_by(5) {
        let n_ref = n / p;
        if n_ref < 3 { continue; }

        let g_n = build_gram_f64(n);
        let (sub, sub_dim) = extract_prime_submatrix(&g_n, n, p);
        if sub_dim < 2 { continue; }
        let eigs_sub = eigenvalues(&sub, sub_dim);
        let lmin_sub = eigs_sub[0];

        let g_ref = build_gram_f64(n_ref);
        let dim_ref = n_ref - 1;
        let eigs_ref = eigenvalues(&g_ref, dim_ref);
        let lmin_ref = eigs_ref[0];

        let correction = (lmin_sub - lmin_ref / p as f64).abs();
        let relative = if lmin_ref.abs() > 1e-20 { correction / (lmin_ref / p as f64) } else { f64::NAN };

        println!(
            "  N={:4}: |correction| = {:.8e}  relative = {:.4}%",
            n, correction, relative * 100.0
        );
    }
    println!();

    // ═══════════════════════════════════════════════════════════════
    // Phase 5: Prime Fractal Dimension estimate
    // ═══════════════════════════════════════════════════════════════
    println!("Phase 5: Prime Fractal Dimension D");
    println!("─────────────────────────────────────────────────");
    println!("  Finding D such that Σ_p p^{{-D}} = 1");

    // Collect primes up to 10000
    let primes: Vec<usize> = (2..=10000).filter(|&n| is_prime(n)).collect();
    println!("  Using {} primes up to 10000", primes.len());

    // Binary search for D
    let mut d_lo = 1.0f64;
    let mut d_hi = 3.0f64;

    for _ in 0..100 {
        let d_mid = (d_lo + d_hi) / 2.0;
        let sum: f64 = primes.iter().map(|&p| (p as f64).powf(-d_mid)).sum();
        if sum > 1.0 {
            d_lo = d_mid;
        } else {
            d_hi = d_mid;
        }
    }
    let d_fractal = (d_lo + d_hi) / 2.0;
    let sum_check: f64 = primes.iter().map(|&p| (p as f64).powf(-d_fractal)).sum();

    println!("  D ≈ {:.10}", d_fractal);
    println!("  Σ p^{{-D}} = {:.10} (should be ≈ 1.0)", sum_check);
    println!("  Compare: log(3)/log(2) = {:.6} (Sierpinski gasket)", (3.0f64).ln() / (2.0f64).ln());
    println!("  Compare: log(4)/log(2) = {:.6} (Sierpinski tetrahedron)", 2.0);
    println!();

    println!("═══════════════════════════════════════════════════════════════");
    println!("  PROBE COMPLETE");
    println!("═══════════════════════════════════════════════════════════════");
}
