//! b-Projection Analysis — How the inner product vector b distributes
//! across the eigenspaces of the Gram matrix.
//!
//! KEY INSIGHT: d² = 1 - bᵀG⁻¹b = 1 - Σᵢ |b·vᵢ|²/λᵢ
//! where (λᵢ, vᵢ) are eigenvalue/eigenvector pairs of G.
//!
//! If small eigenvalues have SMALL projections |b·vᵢ|², the sum
//! can converge even though 1/λᵢ is huge. This is the mechanism
//! that makes d²→0 despite λ_min→0.
//!
//! PARALLEL version using rayon for Gram matrix construction.

use cathedral_utils::gram;
use rayon::prelude::*;
use std::time::Instant;

/// Compute b_i = ∫₀¹ {1/((i+1)x)} dx via high-precision numerical integration.
/// This equals 1 - γ - ψ(1 + 1/(i+1)) for the BD basis, but we compute
/// it numerically for safety.
fn compute_b_vector(dim: usize) -> Vec<f64> {
    // b_i = ∫₀¹ fract(1/((i+1)x)) dx
    // For the BD basis h_k(x) = {1/(kx)}, b_k = ∫₀¹ {1/(kx)} dx
    // = Σ_{n=1}^∞ [1/k - ⌊n/k⌋·ln(1+1/n) + ... ] (same series as gram_entry(k,1) almost)
    // Actually, b_k = ∫₀¹ {1/(kx)} dx = (1 + γ + ψ(k))/k - but let's use the
    // series that cathedral-utils uses for consistency.
    //
    // Actually the simplest: b_k = gramEntry(k, ∞) in some sense, but really
    // b_k = ∫₀¹ {1/(kx)} · 1 dx. The "1" function has {1/(1·x)} as basis for k=1.
    //
    // From Defs.lean: basisInnerProd N i = ∫₀¹ fract(1/((i+1)·x)) dx
    // This is just the integral of a single fractional part function.
    //
    // Known closed form: ∫₀¹ {1/(kx)} dx = 1 - γ - ln(k)/k + H_{k-1}/k
    // But let's compute via numerical quadrature for correctness.

    let npts = 500_000usize;
    (0..dim).into_par_iter().map(|i| {
        let k = (i + 1) as f64;
        let mut sum = 0.0f64;
        for n in 1..=npts {
            let x = (n as f64 - 0.5) / npts as f64;
            let arg = 1.0 / (k * x);
            let frac = arg - arg.floor();
            sum += frac;
        }
        sum / npts as f64
    }).collect()
}

fn main() {
    println!("╔══════════════════════════════════════════════════════════════╗");
    println!("║   b-PROJECTION ANALYSIS — Eigenspace Distribution          ║");
    println!("║   Key: d² = 1 - Σ |b·vᵢ|²/λᵢ                             ║");
    println!("╚══════════════════════════════════════════════════════════════╝");
    println!();

    let test_ns: Vec<usize> = vec![
        10, 20, 30, 50, 80, 100, 150, 200, 300, 500,
    ];

    // ══════════════════════════════════════════════════
    // PART 1: Summary table
    // ══════════════════════════════════════════════════
    println!("  PART 1: Summary");
    println!("  {:>5} {:>10} {:>10} {:>10} {:>12} {:>12} {:>12}",
        "N", "λ_min", "|b·v_min|²", "ratio", "d²", "bottom5%", "top5%");
    println!("  {}", "─".repeat(80));

    for &n in &test_ns {
        let t0 = Instant::now();
        let dim = n - 1;

        // Build Gram matrix (parallel)
        let upper_indices: Vec<(usize, usize)> = (0..dim)
            .flat_map(|j| (j..dim).map(move |k| (j, k)))
            .collect();
        let entries: Vec<(usize, usize, f64)> = upper_indices
            .par_iter()
            .map(|&(j, k)| (j, k, gram::gram_entry_f64(j + 1, k + 1)))
            .collect();
        let mut g_flat = vec![0.0f64; dim * dim];
        for (j, k, val) in entries {
            g_flat[j * dim + k] = val;
            g_flat[k * dim + j] = val;
        }

        // Eigenvalue decomposition
        let mat = nalgebra::DMatrix::from_row_slice(dim, dim, &g_flat);
        let eig = mat.symmetric_eigen();

        // Sort eigenvalues and get corresponding eigenvector columns
        let mut eig_pairs: Vec<(f64, Vec<f64>)> = (0..dim).map(|i| {
            let eigenval = eig.eigenvalues[i];
            let eigvec: Vec<f64> = (0..dim).map(|r| eig.eigenvectors[(r, i)]).collect();
            (eigenval, eigvec)
        }).collect();
        eig_pairs.sort_by(|a, b| a.0.partial_cmp(&b.0).unwrap());

        // Compute b vector
        let b = compute_b_vector(dim);
        let b_norm_sq: f64 = b.iter().map(|x| x * x).sum();

        // Compute projections |b·vᵢ|²
        let projections: Vec<f64> = eig_pairs.iter().map(|(_, v)| {
            let dot: f64 = b.iter().zip(v.iter()).map(|(bi, vi)| bi * vi).sum();
            dot * dot
        }).collect();

        // Compute d² = 1 - Σ |b·vᵢ|²/λᵢ
        let b_ginv_b: f64 = eig_pairs.iter().zip(projections.iter())
            .map(|((lam, _), proj)| proj / lam)
            .sum();
        let d_sq = 1.0 - b_ginv_b;

        // Bottom 5% of eigenvalues
        let bottom_count = (dim as f64 * 0.05).ceil() as usize;
        let bottom_proj: f64 = projections[..bottom_count].iter().sum();
        let bottom_frac = bottom_proj / b_norm_sq;

        // Top 5% of eigenvalues
        let top_proj: f64 = projections[dim - bottom_count..].iter().sum();
        let top_frac = top_proj / b_norm_sq;

        let lam_min = eig_pairs[0].0;
        let b_vmin_sq = projections[0];
        let ratio = b_vmin_sq / lam_min;
        let elapsed = t0.elapsed().as_secs_f64();

        println!("  {:5} {:10.2e} {:10.2e} {:10.4e} {:12.6e} {:10.4}% {:10.4}%  ({:.1}s)",
            n, lam_min, b_vmin_sq, ratio, d_sq,
            bottom_frac * 100.0, top_frac * 100.0, elapsed);
    }

    // ══════════════════════════════════════════════════
    // PART 2: Detailed eigenspace distribution for a few N values
    // ══════════════════════════════════════════════════
    println!();
    println!("  PART 2: Detailed Eigenspace Distribution");

    for &n in &[50, 200, 500] {
        let dim = n - 1;

        let upper_indices: Vec<(usize, usize)> = (0..dim)
            .flat_map(|j| (j..dim).map(move |k| (j, k)))
            .collect();
        let entries: Vec<(usize, usize, f64)> = upper_indices
            .par_iter()
            .map(|&(j, k)| (j, k, gram::gram_entry_f64(j + 1, k + 1)))
            .collect();
        let mut g_flat = vec![0.0f64; dim * dim];
        for (j, k, val) in entries {
            g_flat[j * dim + k] = val;
            g_flat[k * dim + j] = val;
        }

        let mat = nalgebra::DMatrix::from_row_slice(dim, dim, &g_flat);
        let eig = mat.symmetric_eigen();

        let mut eig_pairs: Vec<(f64, Vec<f64>)> = (0..dim).map(|i| {
            let eigenval = eig.eigenvalues[i];
            let eigvec: Vec<f64> = (0..dim).map(|r| eig.eigenvectors[(r, i)]).collect();
            (eigenval, eigvec)
        }).collect();
        eig_pairs.sort_by(|a, b| a.0.partial_cmp(&b.0).unwrap());

        let b = compute_b_vector(dim);
        let b_norm_sq: f64 = b.iter().map(|x| x * x).sum();

        let projections: Vec<f64> = eig_pairs.iter().map(|(_, v)| {
            let dot: f64 = b.iter().zip(v.iter()).map(|(bi, vi)| bi * vi).sum();
            dot * dot
        }).collect();

        println!();
        println!("  ── N = {} (dim = {}) ──", n, dim);
        println!("  ‖b‖² = {:.6}", b_norm_sq);
        println!("  {:>5} {:>12} {:>12} {:>12} {:>12} {:>12}",
            "rank", "λᵢ", "|b·vᵢ|²", "|b·vᵢ|²/‖b‖²", "|b·vᵢ|²/λᵢ", "cum d² contrib");

        let mut cum_contrib = 0.0f64;
        // Show first 10, last 5, and any eigenvalue where projection > 1% of ‖b‖²
        let show_first = 10.min(dim);
        let show_last = 5.min(dim);

        for i in 0..dim {
            let lam = eig_pairs[i].0;
            let proj = projections[i];
            let frac = proj / b_norm_sq;
            let contrib = proj / lam;
            cum_contrib += contrib;

            if i < show_first || i >= dim - show_last || frac > 0.01 {
                println!("  {:5} {:12.4e} {:12.4e} {:12.6}% {:12.4e} {:12.6e}",
                    i + 1, lam, proj, frac * 100.0, contrib, cum_contrib);
            } else if i == show_first {
                println!("  {:>5} {:>12} {:>12} {:>12} {:>12}", "...", "...", "...", "...", "...");
            }
        }

        // Key scaling: |b·v_min|² vs λ_min
        let b_vmin_sq = projections[0];
        let lam_min = eig_pairs[0].0;
        println!();
        println!("  KEY RATIO: |b·v_min|²/λ_min = {:.6e} / {:.6e} = {:.6e}",
            b_vmin_sq, lam_min, b_vmin_sq / lam_min);
        println!("  If this ratio → 0 as N → ∞, then the min-eigenvalue");
        println!("  contribution to bᵀG⁻¹b vanishes, enabling d² → 0.");
    }

    // ══════════════════════════════════════════════════
    // PART 3: Scaling of |b·v_min|² and the ratio
    // ══════════════════════════════════════════════════
    println!();
    println!("══════════════════════════════════════════════════════════════");
    println!("  PART 3: Scaling of |b·v_min|² and |b·v_min|²/λ_min");
    println!("══════════════════════════════════════════════════════════════");
    println!();
    println!("  {:>5} {:>12} {:>12} {:>12} {:>12} {:>12}",
        "N", "λ_min", "|b·v_min|²", "ratio", "N²·|bv|²", "N²·ratio");
    println!("  {}", "─".repeat(75));

    let scaling_ns: Vec<usize> = vec![10, 20, 30, 50, 80, 100, 150, 200, 300, 500];
    let mut ratio_log_data: Vec<(f64, f64)> = Vec::new();
    let mut proj_log_data: Vec<(f64, f64)> = Vec::new();

    for &n in &scaling_ns {
        let dim = n - 1;
        let upper_indices: Vec<(usize, usize)> = (0..dim)
            .flat_map(|j| (j..dim).map(move |k| (j, k)))
            .collect();
        let entries: Vec<(usize, usize, f64)> = upper_indices
            .par_iter()
            .map(|&(j, k)| (j, k, gram::gram_entry_f64(j + 1, k + 1)))
            .collect();
        let mut g_flat = vec![0.0f64; dim * dim];
        for (j, k, val) in entries {
            g_flat[j * dim + k] = val;
            g_flat[k * dim + j] = val;
        }
        let mat = nalgebra::DMatrix::from_row_slice(dim, dim, &g_flat);
        let eig = mat.symmetric_eigen();
        let mut eig_pairs: Vec<(f64, usize)> = (0..dim)
            .map(|i| (eig.eigenvalues[i], i)).collect();
        eig_pairs.sort_by(|a, b| a.0.partial_cmp(&b.0).unwrap());

        let b = compute_b_vector(dim);
        let min_idx = eig_pairs[0].1;
        let lam_min = eig_pairs[0].0;
        let v_min: Vec<f64> = (0..dim).map(|r| eig.eigenvectors[(r, min_idx)]).collect();
        let dot: f64 = b.iter().zip(v_min.iter()).map(|(bi, vi)| bi * vi).sum();
        let b_vmin_sq = dot * dot;
        let ratio = b_vmin_sq / lam_min;

        println!("  {:5} {:12.4e} {:12.4e} {:12.4e} {:12.4} {:12.4}",
            n, lam_min, b_vmin_sq, ratio,
            (n as f64).powi(2) * b_vmin_sq,
            (n as f64).powi(2) * ratio);

        if n >= 10 {
            ratio_log_data.push(((n as f64).ln(), ratio.ln()));
            proj_log_data.push(((n as f64).ln(), b_vmin_sq.ln()));
        }
    }

    // Fit power laws
    println!();
    for (label, data) in [("b·v_min|²", &proj_log_data), ("|b·v_min|²/λ_min", &ratio_log_data)] {
        if data.len() >= 3 {
            let n_pts = data.len() as f64;
            let sx: f64 = data.iter().map(|(x, _)| x).sum();
            let sy: f64 = data.iter().map(|(_, y)| y).sum();
            let sxy: f64 = data.iter().map(|(x, y)| x * y).sum();
            let sx2: f64 = data.iter().map(|(x, _)| x * x).sum();
            let alpha = (n_pts * sxy - sx * sy) / (n_pts * sx2 - sx * sx);
            let log_c = (sy - alpha * sx) / n_pts;
            let mean_y = sy / n_pts;
            let ss_tot: f64 = data.iter().map(|(_, y)| (y - mean_y).powi(2)).sum();
            let ss_res: f64 = data.iter()
                .map(|(x, y)| (y - (alpha * x + log_c)).powi(2)).sum();
            let r2 = 1.0 - ss_res / ss_tot;
            println!("  |{label}| ≈ {:.4} · N^({:.4})   R² = {:.6}", log_c.exp(), alpha, r2);
        }
    }

    println!();
    println!("  If |b·v_min|²/λ_min → 0, the small eigenvalue contribution is harmless.");
    println!("  If |b·v_min|²/λ_min → const, it contributes a fixed amount to bᵀG⁻¹b.");
    println!("  If |b·v_min|²/λ_min → ∞, the small eigenvalue DOMINATES (bad for d²→0).");
}
