#![allow(
    dead_code,
    unused_variables,
    unused_imports,
    unused_assignments,
    clippy::needless_range_loop,
    clippy::doc_lazy_continuation,
    non_snake_case,
    clippy::empty_line_after_doc_comments
)]
// overcancellation-scan/src/bin/cathedral_constant_probe.rs
//
// ╔════════════════════════════════════════════════════════════════════╗
// ║  CATHEDRAL CONSTANT PROBE                                        ║
// ║                                                                    ║
// ║  Phase 1: Extract the Cathedral Constant vᵀRv / logN → C         ║
// ║  Phase 2: Dual-Skeleton Eigenvalue Comparison (B₁ vs B₂)          ║
// ║                                                                    ║
// ║  B₁ skeleton: gcd(j,k)² / (12·j·k)   [RH lives here]            ║
// ║  B₂ skeleton: gcd(j,k)⁴ / (180·j²·k²) [Smith PD proved here]   ║
// ║                                                                    ║
// ║  Key questions:                                                    ║
// ║  1. Does vᵀRv / logN → constant? What is it?                     ║
// ║  2. Does vᵀA₁v dominate vᵀL₁v for the Möbius witness?           ║
// ║  3. What are λ_min(A₁_N), λ_min(A₂_N), λ_min(G_N)?             ║
// ╚════════════════════════════════════════════════════════════════════╝

use cathedral_utils::arith::gcd;
use cathedral_utils::arith::mobius_table;
use nalgebra::{DMatrix, DVector, SymmetricEigen};
use std::time::Instant;

// ════════════════════════════════════════════════════
// ARITHMETIC FUNCTIONS
// ════════════════════════════════════════════════════



/// J₂(d) = d² · Π_{p|d} (1 - 1/p²)
fn jordan_totient2(d: usize) -> f64 {
    if d == 0 {
        return 0.0;
    }
    let d_f = d as f64;
    let mut result = d_f * d_f;
    let mut n = d;
    let mut p = 2usize;
    while p * p <= n {
        if n.is_multiple_of(p) {
            result *= 1.0 - 1.0 / (p as f64 * p as f64);
            while n.is_multiple_of(p) {
                n /= p;
            }
        }
        p += 1;
    }
    if n > 1 {
        result *= 1.0 - 1.0 / (n as f64 * n as f64);
    }
    result
}

/// BD log-cutoff weight: w(k, N) = 1 - ln(k)/ln(N)
fn log_weight(k: usize, n: usize) -> f64 {
    if k >= n {
        return 0.0;
    }
    1.0 - (k as f64).ln() / (n as f64).ln()
}

/// Witness vector entry: v(k) = -μ(k) · w(k, N) / k
fn witness_entry(mu_k: i8, k: usize, n: usize) -> f64 {
    -(mu_k as f64) * log_weight(k, n) / (k as f64)
}

/// Divisor coefficient y_d = Σ_{d|k, k≤N} v(k)
fn divisor_coeff_raw(mu: &[i8], d: usize, n: usize) -> f64 {
    let mut sum = 0.0f64;
    let mut k = d;
    while k <= n {
        let mu_k = mu[k];
        if mu_k != 0 {
            sum += witness_entry(mu_k, k, n);
        }
        k += d;
    }
    sum
}

// ════════════════════════════════════════════════════
// MATRIX CONSTRUCTION
// ════════════════════════════════════════════════════

/// Build the B₁ skeleton: A₁(j,k) = gcd(j,k)² / (12·j·k)
/// This is ∫₀¹ B₁({jx})·B₁({kx}) dx where B₁(x) = x - 1/2
fn build_b1_skeleton(n: usize) -> DMatrix<f64> {
    let mut m = DMatrix::zeros(n, n);
    for j in 0..n {
        for k in 0..n {
            let jj = j + 1;
            let kk = k + 1;
            let g = gcd(jj, kk) as f64;
            m[(j, k)] = g * g / (12.0 * jj as f64 * kk as f64);
        }
    }
    m
}

/// Build the B₂ skeleton: A₂(j,k) = gcd(j,k)⁴ / (180·j²·k²)
/// This is ∫₀¹ B₂({jx})·B₂({kx}) dx where B₂(x) = x² - x + 1/6
fn build_b2_skeleton(n: usize) -> DMatrix<f64> {
    let mut m = DMatrix::zeros(n, n);
    for j in 0..n {
        for k in 0..n {
            let jj = j + 1;
            let kk = k + 1;
            let g = gcd(jj, kk) as f64;
            let g4 = g * g * g * g;
            m[(j, k)] = g4 / (180.0 * (jj as f64).powi(2) * (kk as f64).powi(2));
        }
    }
    m
}

/// Build the TRUE Vasyunin-BD Gram matrix using the integral formula:
///   G(j,k) = ∫₀¹ {1/(jx)}·{1/(kx)} dx
///
/// Computed via the Vasyunin closed form:
///   ∫₀¹ {1/(jx)}·{1/(kx)} dx = (1/2) - (1/2)(j+k)/(jk)
///     + Σ_{m=1}^{j-1} Σ_{n=1}^{k-1} gcd(m,n)/(jk)   [for j≤k]
///
/// Actually, the simplest correct formula for FRANEL basis:
///   f_k(x) = {1/(kx)} - 1/(2k)  (centered fractional part)
///   G(j,k) = ⟨f_j, f_k⟩ = ∫₀¹ {1/(jx)}·{1/(kx)} dx - 1/(4jk)
///
/// For the actual BD distance, the basis is:
///   e_k(x) = ρ(1/(kx))  where ρ(x) = {x} - 1/2
///
/// The Gram matrix entries are computed by direct numerical integration.
fn build_gram_matrix_numerical(n: usize) -> DMatrix<f64> {
    let num_points = 10000; // integration points
    let mut m = DMatrix::zeros(n, n);

    for j in 0..n {
        for k in j..n {
            let jj = (j + 1) as f64;
            let kk = (k + 1) as f64;

            // Numerical integration of ∫₀¹ ρ(1/(jx))·ρ(1/(kx)) dx
            // where ρ(t) = {t} - 1/2
            let mut integral = 0.0f64;
            let dx = 1.0 / num_points as f64;

            for i in 1..=num_points {
                let x = (i as f64 - 0.5) * dx; // midpoint rule
                let fj = (1.0 / (jj * x)).fract() - 0.5;
                let fk = (1.0 / (kk * x)).fract() - 0.5;
                integral += fj * fk * dx;
            }

            m[(j, k)] = integral;
            m[(k, j)] = integral;
        }
    }
    m
}

fn main() {
    println!("╔════════════════════════════════════════════════════════════╗");
    println!("║  CATHEDRAL CONSTANT PROBE                                 ║");
    println!("║  Phase 1: Smith sum convergence                           ║");
    println!("║  Phase 2: B₁ vs B₂ skeleton eigenvalue comparison         ║");
    println!("╚════════════════════════════════════════════════════════════╝");
    println!();

    // ════════════════════════════════════════════════════
    // PHASE 1: Cathedral Constant Extraction
    // ════════════════════════════════════════════════════

    let timer = Instant::now();

    let test_ns: Vec<usize> = vec![
        100, 500, 1000, 5000, 10_000, 50_000, 100_000, 500_000, 1_000_000,
    ];
    let max_n = *test_ns.last().unwrap();

    println!("Phase 1: Sieving Möbius function up to {}...", max_n);
    let mu = mobius_table(max_n);
    println!("  Done in {:.2}s", timer.elapsed().as_secs_f64());
    println!();

    println!("┌──────────────┬──────────────┬──────────────┬──────────────┬──────────────┐");
    println!("│       N      │   12·vᵀRv    │    vᵀRv      │    logN      │  vᵀRv/logN   │");
    println!("├──────────────┼──────────────┼──────────────┼──────────────┼──────────────┤");

    for &n in &test_ns {
        // Smith sum: (1/12) Σ J₂(d) · y_d²
        let mut smith_sum = 0.0f64;
        for d in 1..=n {
            let yd = divisor_coeff_raw(&mu, d, n);
            let j2d = jordan_totient2(d);
            smith_sum += j2d * yd * yd;
        }
        let v_r_v = smith_sum / 12.0;
        let log_n = (n as f64).ln();
        let ratio = v_r_v / log_n;

        println!(
            "│ {:>12} │ {:>12.8} │ {:>12.8} │ {:>12.6} │ {:>12.8} │",
            n, smith_sum, v_r_v, log_n, ratio
        );
    }

    println!("└──────────────┴──────────────┴──────────────┴──────────────┴──────────────┘");
    println!();
    println!("  Cathedral Constant ≈ lim vᵀRv / logN");
    println!("  (Look for convergence in the last column)");
    println!();

    // ════════════════════════════════════════════════════
    // PHASE 2: Dual-Skeleton Eigenvalue Comparison
    // ════════════════════════════════════════════════════

    println!("═══════════════════════════════════════════════════════════════");
    println!("Phase 2: Dual-Skeleton Eigenvalue Comparison");
    println!("═══════════════════════════════════════════════════════════════");
    println!();

    let eigen_ns: Vec<usize> = vec![10, 20, 50, 100, 200];

    println!("┌──────┬──────────────┬──────────────┬──────────────┬──────────────┬──────────────┐");
    println!("│  N   │ λ_min(G_num) │  λ_min(B₁)   │  λ_min(B₂)   │ λ_min·logN   │  ‖L₁‖_op     │");
    println!("├──────┼──────────────┼──────────────┼──────────────┼──────────────┼──────────────┤");

    for &n in &eigen_ns {
        let timer2 = Instant::now();

        // Build all three matrices
        let g_num = build_gram_matrix_numerical(n);
        let a1 = build_b1_skeleton(n);
        let a2 = build_b2_skeleton(n);

        // L₁ = G - A₁ (perturbation in B₁ space)
        let l1 = &g_num - &a1;

        // Eigenvalue decomposition
        let eig_g = SymmetricEigen::new(g_num.clone());
        let eig_a1 = SymmetricEigen::new(a1.clone());
        let eig_a2 = SymmetricEigen::new(a2.clone());
        let eig_l1 = SymmetricEigen::new(l1.clone());

        let lambda_min_g = eig_g.eigenvalues.min();
        let lambda_min_a1 = eig_a1.eigenvalues.min();
        let lambda_min_a2 = eig_a2.eigenvalues.min();
        let l1_op_norm = eig_l1
            .eigenvalues
            .iter()
            .map(|x| x.abs())
            .fold(0.0f64, f64::max);

        let log_n = (n as f64).ln();

        println!(
            "│ {:>4} │ {:>12.8} │ {:>12.8} │ {:>12.8} │ {:>12.8} │ {:>12.8} │",
            n,
            lambda_min_g,
            lambda_min_a1,
            lambda_min_a2,
            lambda_min_g * log_n,
            l1_op_norm
        );

        eprintln!("  N={}: done in {:.2}s", n, timer2.elapsed().as_secs_f64());
    }

    println!("└──────┴──────────────┴──────────────┴──────────────┴──────────────┴──────────────┘");
    println!();

    // ════════════════════════════════════════════════════
    // PHASE 2b: Restricted Rayleigh Quotient (Möbius subspace)
    // ════════════════════════════════════════════════════

    println!("═══════════════════════════════════════════════════════════════");
    println!("Phase 2b: Restricted Rayleigh Quotient on Möbius Subspace");
    println!("  Key test: does vᵀL₁v → 0 faster than vᵀA₁v?");
    println!("═══════════════════════════════════════════════════════════════");
    println!();

    println!("┌──────┬──────────────┬──────────────┬──────────────┬──────────────┬──────────────┐");
    println!("│  N   │   vᵀGv       │   vᵀA₁v      │   vᵀL₁v      │ |vᵀL₁v/vᵀA₁v| │   vᵀA₂v     │");
    println!("├──────┼──────────────┼──────────────┼──────────────┼──────────────┼──────────────┤");

    for &n in &eigen_ns {
        // Build the Möbius witness vector
        let mut v = DVector::zeros(n);
        for k in 1..=n {
            if mu[k] != 0 {
                v[k - 1] = witness_entry(mu[k], k, n);
            }
        }

        // Build matrices
        let g_num = build_gram_matrix_numerical(n);
        let a1 = build_b1_skeleton(n);
        let a2 = build_b2_skeleton(n);
        let l1 = &g_num - &a1;

        // Compute bilinear forms
        let vtgv = v.dot(&(&g_num * &v));
        let vta1v = v.dot(&(&a1 * &v));
        let vtl1v = v.dot(&(&l1 * &v));
        let vta2v = v.dot(&(&a2 * &v));

        let ratio = if vta1v.abs() > 1e-15 {
            (vtl1v / vta1v).abs()
        } else {
            f64::INFINITY
        };

        println!(
            "│ {:>4} │ {:>12.8} │ {:>12.8} │ {:>12.8} │ {:>12.8} │ {:>12.8} │",
            n, vtgv, vta1v, vtl1v, ratio, vta2v
        );
    }

    println!("└──────┴──────────────┴──────────────┴──────────────┴──────────────┴──────────────┘");
    println!();
    println!("  If |vᵀL₁v/vᵀA₁v| → 0 as N → ∞:");
    println!("    The Möbius oscillations ANNIHILATE the smooth perturbation");
    println!("    → The B₁ skeleton controls the quadratic form on the Möbius subspace");
    println!("    → vᵀGv ≈ vᵀA₁v → spectral gap from arithmetic structure alone");
    println!();

    // ════════════════════════════════════════════════════
    // PHASE 2c: Eigenvalue scaling laws
    // ════════════════════════════════════════════════════

    println!("═══════════════════════════════════════════════════════════════");
    println!("Phase 2c: Eigenvalue Scaling Laws");
    println!("═══════════════════════════════════════════════════════════════");
    println!();

    println!("┌──────┬──────────────┬──────────────┬──────────────┬──────────────┐");
    println!("│  N   │ λ_min·logN   │ λ_min·N      │ λ_min·√N     │ λ_min·N²     │");
    println!("├──────┼──────────────┼──────────────┼──────────────┼──────────────┤");

    for &n in &eigen_ns {
        let g_num = build_gram_matrix_numerical(n);
        let eig_g = SymmetricEigen::new(g_num);
        let lmin = eig_g.eigenvalues.min();
        let nf = n as f64;

        println!(
            "│ {:>4} │ {:>12.8} │ {:>12.8} │ {:>12.8} │ {:>12.8} │",
            n,
            lmin * nf.ln(),
            lmin * nf,
            lmin * nf.sqrt(),
            lmin * nf * nf
        );
    }

    println!("└──────┴──────────────┴──────────────┴──────────────┴──────────────┘");
    println!("  Look for which column stabilizes → reveals λ_min decay rate");
    println!();

    println!("Total time: {:.2}s", timer.elapsed().as_secs_f64());
}
