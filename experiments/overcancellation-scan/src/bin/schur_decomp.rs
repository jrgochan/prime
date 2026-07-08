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
//! SCHUR DECOMPOSITION PROBE — Eigenvalue Drop Anatomy
//!
//! For each N, when we extend G_{N-1} to G_N by adding the N-th basis function:
//!   G_N = [[G_{N-1}, g], [gᵀ, γ]]
//! where g_i = ⟨h_i, h_N⟩ and γ = ⟨h_N, h_N⟩.
//!
//! The Schur complement S_N = γ - gᵀ G_{N-1}⁻¹ g measures
//! how much "new information" h_N adds.
//!
//! The eigenvalue drop δ_N is controlled by:
//!   δ_N ≤ ‖G_{N-1}⁻¹ g‖² · λ_min² / S_N    (perturbation bound)
//!
//! But more precisely, the drop relates to the min-eigenvector projection:
//!   δ_N ≈ |⟨v_min, g⟩|² / (S_N · (γ_eff - δ_N))
//!
//! We test whether δ_N ~ d(N)² / N³ by decomposing into:
//!   (1) Schur complement S_N (how "new" is h_N?)
//!   (2) Projection |⟨v_min, g⟩|² (does the new function push the min eigenvalue?)
//!   (3) Arithmetic factor d(N) (divisor count of N)

use cathedral_utils::gram;
use rayon::prelude::*;
use std::time::Instant;

fn build_gram(n: usize) -> Vec<f64> {
    let dim = n - 1;
    let upper: Vec<(usize, usize)> = (0..dim)
        .flat_map(|j| (j..dim).map(move |k| (j, k)))
        .collect();
    let entries: Vec<(usize, usize, f64)> = upper
        .par_iter()
        .map(|&(j, k)| (j, k, gram::gram_entry_f64(j + 1, k + 1)))
        .collect();
    let mut g = vec![0.0f64; dim * dim];
    for (j, k, val) in entries {
        g[j * dim + k] = val;
        g[k * dim + j] = val;
    }
    g
}

fn num_divisors(n: usize) -> usize {
    let mut count = 0;
    let mut d = 1;
    while d * d <= n {
        if n.is_multiple_of(d) {
            count += 1;
            if d != n / d {
                count += 1;
            }
        }
        d += 1;
    }
    count
}

fn is_prime(n: usize) -> bool {
    if n < 2 {
        return false;
    }
    if n < 4 {
        return true;
    }
    if n.is_multiple_of(2) || n.is_multiple_of(3) {
        return false;
    }
    let mut i = 5;
    while i * i <= n {
        if n.is_multiple_of(i) || n.is_multiple_of(i + 2) {
            return false;
        }
        i += 6;
    }
    true
}

fn main() {
    let t_start = Instant::now();

    println!("╔══════════════════════════════════════════════════════════════╗");
    println!("║   SCHUR DECOMPOSITION PROBE — Drop Anatomy                 ║");
    println!("║   Testing: δ_N ~ d(N)² / N³  via Schur complement         ║");
    println!("║   BD Basis · cathedral-utils · rayon                       ║");
    println!("╚══════════════════════════════════════════════════════════════╝");
    println!();

    let max_n: usize = 500;
    let start_n: usize = 4; // Need N≥4 so G_{N-1} is at least 2×2

    // Build the full Gram matrix once
    let t0 = Instant::now();
    let full_dim = max_n - 1;
    let full_gram = build_gram(max_n);
    println!(
        "  [Built {}×{} Gram matrix in {:.1}s]",
        full_dim,
        full_dim,
        t0.elapsed().as_secs_f64()
    );
    println!();

    // ══════════════════════════════════════════════════
    // PART 1: Schur complement + drop decomposition
    // ══════════════════════════════════════════════════

    println!("  PART 1: Schur Complement Decomposition");
    println!(
        "  {:>5} {:>10} {:>10} {:>10} {:>10} {:>10} {:>10} {:>5}",
        "N", "δ_N", "S_N", "|gᵀvmin|²", "d(N)", "δ·N³", "δ·N³/d²", "type"
    );
    println!("  {}", "─".repeat(80));

    struct DropRecord {
        n: usize,
        drop: f64,
        schur: f64,
        g_vmin_sq: f64,
        d_n: usize,
        n_cubed_drop: f64,
        normalized: f64, // δ·N³/d(N)²
    }

    let mut records: Vec<DropRecord> = Vec::new();
    let mut prev_lmin = 0.0f64;
    let mut prev_vmin: Vec<f64> = Vec::new();

    for n in 3..=max_n {
        let dim = n - 1;

        // Extract G_N submatrix
        let mut sub = vec![0.0f64; dim * dim];
        for j in 0..dim {
            for k in 0..dim {
                sub[j * dim + k] = full_gram[j * full_dim + k];
            }
        }

        // Eigendecomposition of G_N
        let mat = nalgebra::DMatrix::from_row_slice(dim, dim, &sub);
        let eig = mat.symmetric_eigen();

        // Find min eigenvalue and eigenvector
        let mut min_idx = 0;
        let mut lmin = eig.eigenvalues[0];
        for i in 1..dim {
            if eig.eigenvalues[i] < lmin {
                lmin = eig.eigenvalues[i];
                min_idx = i;
            }
        }
        let v_min: Vec<f64> = (0..dim).map(|r| eig.eigenvectors[(r, min_idx)]).collect();

        if n >= start_n && !prev_vmin.is_empty() {
            let drop = (prev_lmin - lmin).max(0.0);
            let d_n = num_divisors(n);
            let dim_prev = n - 2; // dim of G_{N-1}

            // g vector: last column of G_N restricted to first dim_prev rows
            // g_i = gramEntry(i+1, dim) = gramEntry(i+1, n-1) for i=0..dim_prev-1
            let g_vec: Vec<f64> = (0..dim_prev)
                .map(|i| full_gram[i * full_dim + (dim - 1)])
                .collect();

            // γ = G(dim-1, dim-1) = gramEntry(n-1, n-1)
            let gamma = full_gram[(dim - 1) * full_dim + (dim - 1)];

            // Schur complement S = γ - gᵀ G_{N-1}⁻¹ g
            // Build G_{N-1}
            let mut sub_prev = vec![0.0f64; dim_prev * dim_prev];
            for j in 0..dim_prev {
                for k in 0..dim_prev {
                    sub_prev[j * dim_prev + k] = full_gram[j * full_dim + k];
                }
            }
            let mat_prev = nalgebra::DMatrix::from_row_slice(dim_prev, dim_prev, &sub_prev);
            let g_dvec = nalgebra::DVector::from_column_slice(&g_vec);

            // G_{N-1}⁻¹ g via solve
            let schur = if let Some(inv_prev) = mat_prev.clone().try_inverse() {
                let inv_g = &inv_prev * &g_dvec;
                let gt_inv_g = g_dvec.dot(&inv_g);
                gamma - gt_inv_g
            } else {
                f64::NAN
            };

            // Projection of g onto the CURRENT min eigenvector of G_N
            // |⟨v_min(G_N), g_extended⟩|²
            // where g_extended = [g; 0] padded to dim of G_N... actually
            // we want the projection differently.
            //
            // The relevant quantity: how much does the new basis function
            // project onto the min eigenvector of G_{N-1}?
            // |⟨v_min(G_{N-1}), g⟩|² where v_min(G_{N-1}) is the prev min eigenvector
            let g_vmin_sq = if prev_vmin.len() == dim_prev {
                let dot: f64 = prev_vmin.iter().zip(g_vec.iter()).map(|(v, g)| v * g).sum();
                dot * dot
            } else {
                f64::NAN
            };

            let n_cubed_drop = (n as f64).powi(3) * drop;
            let normalized = if d_n > 0 {
                n_cubed_drop / (d_n as f64 * d_n as f64)
            } else {
                f64::NAN
            };

            let ntype = if d_n >= 16 {
                "HC"
            } else if d_n >= 8 {
                "hc"
            } else if is_prime(n) {
                "P"
            } else {
                ""
            };

            // Print significant rows
            let show = n <= 30 || n % 50 == 0 || n == max_n || drop > 5e-6 || d_n >= 12;

            if show {
                println!(
                    "  {:5} {:10.2e} {:10.2e} {:10.2e} {:10} {:10.4} {:10.4} {:>5}",
                    n, drop, schur, g_vmin_sq, d_n, n_cubed_drop, normalized, ntype
                );
            }

            records.push(DropRecord {
                n,
                drop,
                schur,
                g_vmin_sq,
                d_n,
                n_cubed_drop,
                normalized,
            });
        }

        prev_lmin = lmin;
        prev_vmin = v_min;

        if n % 100 == 0 {
            eprintln!("  ... N={} ({:.0}s)", n, t_start.elapsed().as_secs_f64());
        }
    }

    // ══════════════════════════════════════════════════
    // PART 2: Scaling Analysis
    // ══════════════════════════════════════════════════

    println!();
    println!("══════════════════════════════════════════════════════════════");
    println!("  PART 2: Scaling Analysis");
    println!("══════════════════════════════════════════════════════════════");

    // Test if δ·N³/d(N)² is bounded
    let valid: Vec<&DropRecord> = records
        .iter()
        .filter(|r| r.n >= 10 && r.drop > 1e-15 && r.normalized.is_finite())
        .collect();

    if !valid.is_empty() {
        let norm_vals: Vec<f64> = valid.iter().map(|r| r.normalized).collect();
        let avg = norm_vals.iter().sum::<f64>() / norm_vals.len() as f64;
        let max = norm_vals.iter().cloned().fold(f64::NEG_INFINITY, f64::max);
        let min = norm_vals.iter().cloned().fold(f64::INFINITY, f64::min);

        println!();
        println!("  δ_N · N³ / d(N)² statistics (N ≥ 10):");
        println!("    avg = {:.4}", avg);
        println!("    min = {:.4}", min);
        println!("    max = {:.4}", max);
        println!("    range = [{:.4}, {:.4}]", min, max);

        if max < 10.0 * avg {
            println!();
            println!("  ┌─────────────────────────────────────────────────┐");
            println!("  │ δ_N · N³ / d(N)² appears BOUNDED               │");
            println!("  │ → δ_N ≲ C · d(N)² / N³                         │");
            println!("  │ → Σ δ_N ≲ C · Σ d(N)²/N³ < ∞                  │");
            println!("  │ → λ_min(G_N) = λ_min(G_N₀) - Σ δ_k ≥ c/N²    │");
            println!("  └─────────────────────────────────────────────────┘");
        }
    }

    // Schur complement scaling: S_N ~ 1/N ?
    println!();
    println!("  Schur complement S_N scaling:");
    let schur_data: Vec<(f64, f64)> = records
        .iter()
        .filter(|r| r.n >= 10 && r.schur > 1e-15)
        .map(|r| ((r.n as f64).ln(), r.schur.ln()))
        .collect();

    if schur_data.len() >= 5 {
        let n_pts = schur_data.len() as f64;
        let sx: f64 = schur_data.iter().map(|(x, _)| x).sum();
        let sy: f64 = schur_data.iter().map(|(_, y)| y).sum();
        let sxy: f64 = schur_data.iter().map(|(x, y)| x * y).sum();
        let sx2: f64 = schur_data.iter().map(|(x, _)| x * x).sum();
        let alpha = (n_pts * sxy - sx * sy) / (n_pts * sx2 - sx * sx);
        let log_c = (sy - alpha * sx) / n_pts;
        let mean_y = sy / n_pts;
        let ss_tot: f64 = schur_data.iter().map(|(_, y)| (y - mean_y).powi(2)).sum();
        let ss_res: f64 = schur_data
            .iter()
            .map(|(x, y)| (y - (alpha * x + log_c)).powi(2))
            .sum();
        let r2 = 1.0 - ss_res / ss_tot;
        println!(
            "    S_N ≈ {:.4} · N^({:.4})    R² = {:.6}",
            log_c.exp(),
            alpha,
            r2
        );
    }

    // |gᵀv_min|² scaling
    println!();
    println!("  Projection |gᵀv_min|² scaling:");
    let proj_data: Vec<(f64, f64)> = records
        .iter()
        .filter(|r| r.n >= 10 && r.g_vmin_sq > 1e-30 && r.g_vmin_sq.is_finite())
        .map(|r| ((r.n as f64).ln(), r.g_vmin_sq.ln()))
        .collect();

    if proj_data.len() >= 5 {
        let n_pts = proj_data.len() as f64;
        let sx: f64 = proj_data.iter().map(|(x, _)| x).sum();
        let sy: f64 = proj_data.iter().map(|(_, y)| y).sum();
        let sxy: f64 = proj_data.iter().map(|(x, y)| x * y).sum();
        let sx2: f64 = proj_data.iter().map(|(x, _)| x * x).sum();
        let alpha = (n_pts * sxy - sx * sy) / (n_pts * sx2 - sx * sx);
        let log_c = (sy - alpha * sx) / n_pts;
        let mean_y = sy / n_pts;
        let ss_tot: f64 = proj_data.iter().map(|(_, y)| (y - mean_y).powi(2)).sum();
        let ss_res: f64 = proj_data
            .iter()
            .map(|(x, y)| (y - (alpha * x + log_c)).powi(2))
            .sum();
        let r2 = 1.0 - ss_res / ss_tot;
        println!(
            "    |gᵀv_min|² ≈ {:.4} · N^({:.4})    R² = {:.6}",
            log_c.exp(),
            alpha,
            r2
        );
    }

    // ══════════════════════════════════════════════════
    // PART 3: d(N)²-normalized drop by windows
    // ══════════════════════════════════════════════════

    println!();
    println!("══════════════════════════════════════════════════════════════");
    println!("  PART 3: Divisor-Normalized Drops by Window");
    println!("══════════════════════════════════════════════════════════════");
    println!();
    println!(
        "  {:>10} {:>12} {:>12} {:>12} {:>12}",
        "window", "avg δ·N³", "avg δN³/d²", "max δN³/d²", "Σd²/N³"
    );

    let windows: Vec<(usize, usize)> = vec![
        (10, 50),
        (50, 100),
        (100, 200),
        (200, 300),
        (300, 400),
        (400, 500),
    ];
    for (lo, hi) in &windows {
        let in_w: Vec<&DropRecord> = records
            .iter()
            .filter(|r| r.n >= *lo && r.n < *hi && r.drop > 1e-15)
            .collect();
        if in_w.is_empty() {
            continue;
        }

        let avg_n3d = in_w.iter().map(|r| r.n_cubed_drop).sum::<f64>() / in_w.len() as f64;
        let avg_norm = in_w.iter().map(|r| r.normalized).sum::<f64>() / in_w.len() as f64;
        let max_norm = in_w
            .iter()
            .map(|r| r.normalized)
            .fold(f64::NEG_INFINITY, f64::max);

        // Also compute Σ d(N)²/N³ for this window (the convergent series bound)
        let sum_d2_n3: f64 = (*lo..*hi)
            .map(|n| {
                let d = num_divisors(n) as f64;
                d * d / (n as f64).powi(3)
            })
            .sum();

        println!(
            "  {:>4}-{:<4} {:12.4} {:12.4} {:12.4} {:12.6}",
            lo, hi, avg_n3d, avg_norm, max_norm, sum_d2_n3
        );
    }

    // Compute the full partial sum Σ d(N)²/N³ for N=4..max_n
    let full_sum: f64 = (4..=max_n)
        .map(|n| {
            let d = num_divisors(n) as f64;
            d * d / (n as f64).powi(3)
        })
        .sum();
    println!();
    println!("  Σ_{{N=4}}^{{{}}} d(N)²/N³ = {:.6}", max_n, full_sum);
    println!("  Known: Σ_{{N=1}}^∞ d(N)²/N³ = ζ(3)·(ζ(3/2))²/ζ(3) ... converges to ~2.5");
    println!("  → If δ_N ≤ C·d(N)²/N³, then Σ δ_N converges.");

    println!();
    println!("  Total runtime: {:.1}s", t_start.elapsed().as_secs_f64());
    println!();
}
