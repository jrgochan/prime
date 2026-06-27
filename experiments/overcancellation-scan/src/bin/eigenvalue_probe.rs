#![allow(dead_code, unused_variables, unused_imports, unused_assignments, clippy::needless_range_loop, clippy::doc_lazy_continuation, non_snake_case, clippy::empty_line_after_doc_comments)]
//! Eigenvalue scaling probe for the BD-basis Gram matrix.
//!
//! PARALLEL VERSION — uses rayon to build Gram matrix entries in parallel.
//! On Apple M2 Max (12 cores), this gives ~8-10x speedup.
//!
//! Goal: determine the true scaling of λ_min(G_N) to sync the
//! `gram_eigenvalue_log_scaling` axiom to the BD basis.

use cathedral_utils::gram;
use rayon::prelude::*;
use std::time::Instant;

fn main() {
    println!("╔══════════════════════════════════════════════════════════════╗");
    println!("║   EIGENVALUE SCALING PROBE v2 — PARALLEL (rayon)           ║");
    println!("║   BD Basis Gram Matrix: λ_min(G_N) ∝ N^α                  ║");
    println!("╚══════════════════════════════════════════════════════════════╝");
    println!();

    let test_ns: Vec<usize> = vec![
        3, 5, 8, 10, 15, 20, 30, 40, 50, 60, 80, 100,
        120, 150, 200, 250, 300, 400, 500, 600, 750, 1000,
    ];

    println!("  {:>5} {:>5} {:>14} {:>14} {:>12} {:>10} {:>10} {:>8}",
        "N", "dim", "λ_min", "λ_max", "κ", "log·λ_min", "N²·λ_min", "secs");
    println!("  {}", "─".repeat(90));

    let mut log_data: Vec<(f64, f64)> = Vec::new();

    for &n in &test_ns {
        let t0 = Instant::now();
        let dim = n - 1;

        // Build upper triangle indices for parallel dispatch
        let upper_indices: Vec<(usize, usize)> = (0..dim)
            .flat_map(|j| (j..dim).map(move |k| (j, k)))
            .collect();

        // Parallel Gram matrix construction using rayon
        let entries: Vec<(usize, usize, f64)> = upper_indices
            .par_iter()
            .map(|&(j, k)| {
                let val = gram::gram_entry_f64(j + 1, k + 1);
                (j, k, val)
            })
            .collect();

        // Scatter into flat matrix
        let mut g_flat = vec![0.0f64; dim * dim];
        for (j, k, val) in entries {
            g_flat[j * dim + k] = val;
            g_flat[k * dim + j] = val;
        }

        // Eigenvalue decomposition using nalgebra
        let mat = nalgebra::DMatrix::from_row_slice(dim, dim, &g_flat);
        let eig = mat.symmetric_eigen();
        let mut eigenvalues: Vec<f64> = eig.eigenvalues.iter().copied().collect();
        eigenvalues.sort_by(|a, b| a.partial_cmp(b).unwrap());

        let lam_min = eigenvalues[0];
        let lam_max = eigenvalues[dim - 1];
        let kappa = if lam_min > 0.0 { lam_max / lam_min } else { f64::INFINITY };
        let log_n = (n as f64).ln();
        let elapsed = t0.elapsed().as_secs_f64();

        println!("  {:5} {:5} {:14.8} {:14.8} {:12.1} {:10.6} {:10.4} {:8.1}",
            n, dim, lam_min, lam_max, kappa,
            log_n * lam_min, (n as f64).powi(2) * lam_min, elapsed);

        if n >= 10 {
            log_data.push(((n as f64).ln(), lam_min.ln()));
        }
    }

    println!();
    println!("══════════════════════════════════════════════════════════════");
    println!("  POWER LAW FIT: λ_min ≈ C · N^α");
    println!("══════════════════════════════════════════════════════════════");

    if log_data.len() >= 2 {
        let n_pts = log_data.len() as f64;
        let sum_x: f64 = log_data.iter().map(|(x, _)| x).sum();
        let sum_y: f64 = log_data.iter().map(|(_, y)| y).sum();
        let sum_xy: f64 = log_data.iter().map(|(x, y)| x * y).sum();
        let sum_x2: f64 = log_data.iter().map(|(x, _)| x * x).sum();

        let alpha = (n_pts * sum_xy - sum_x * sum_y) / (n_pts * sum_x2 - sum_x * sum_x);
        let log_c = (sum_y - alpha * sum_x) / n_pts;
        let c = log_c.exp();

        // R² goodness of fit
        let mean_y = sum_y / n_pts;
        let ss_tot: f64 = log_data.iter().map(|(_, y)| (y - mean_y).powi(2)).sum();
        let ss_res: f64 = log_data.iter()
            .map(|(x, y)| (y - (alpha * x + log_c)).powi(2)).sum();
        let r_squared = 1.0 - ss_res / ss_tot;

        println!();
        println!("  α = {:.4}  (exponent)", alpha);
        println!("  C = {:.6}  (coefficient)", c);
        println!("  R² = {:.6}", r_squared);
        println!("  λ_min ≈ {:.4} · N^({:.4})", c, alpha);
        println!();

        // Compare with theoretical models
        println!("  ┌─────────────────────────────────────────────────┐");
        println!("  │ MODEL COMPARISON                                │");
        println!("  ├─────────────────────────────────────────────────┤");
        println!("  │ Old axiom:  λ_min ≥ c/log(N)  (α = 0, log)    │");
        println!("  │ Data fit:   λ_min ≈ {:.3}/N^{:.2}   (power law) │", c, -alpha);
        if alpha > -1.5 {
            println!("  │ VERDICT: Slower than 1/N^1.5 — axiom may hold │");
        } else if alpha > -2.5 {
            println!("  │ VERDICT: ~1/N^2 — axiom c/log(N) too strong   │");
            println!("  │ UPDATE: λ_min ≥ c/N² matches data             │");
        } else {
            println!("  │ VERDICT: Faster than 1/N^2 — investigate!     │");
        }
        println!("  └─────────────────────────────────────────────────┘");
    }
}
