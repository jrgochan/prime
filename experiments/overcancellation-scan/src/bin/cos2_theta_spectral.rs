// overcancellation-scan/src/bin/cos2_theta_spectral.rs
//
// ╔═══════════════════════════════════════════════════════════════════╗
// ║  COS²θ SPECTRAL STATISTICS — The Acoustic Alignment Probe       ║
// ║                                                                   ║
// ║  For each HPDF Gram matrix G_N, compute:                        ║
// ║    • λ_min and the minimum eigenvector v_min                     ║
// ║    • The cross-correlation g_N = last column of G_N              ║
// ║    • cos²θ = |⟨g, v_min⟩|² / ‖g‖²                              ║
// ║    • Schur complement S_N = G[N,N] - gᵀG⁻¹g                    ║
// ║    • eigenDrop δ_N = λ_min(G_{N-1}) - λ_min(G_N)               ║
// ║    • Drop formula check: δ vs cos²θ · ‖g‖² / S                 ║
// ║                                                                   ║
// ║  Then analyze cos²θ spectral statistics:                         ║
// ║    • Power law fit: cos²θ ~ C · N^α                             ║
// ║    • Prime vs composite conditional distributions               ║
// ║    • Level spacing statistics (GOE? GUE? Poisson?)              ║
// ║    • Correlation with divisor count d(N)                        ║
// ║                                                                   ║
// ║  Uses precomputed HPDF .h5 Gram matrices up to N=55440         ║
// ╚═══════════════════════════════════════════════════════════════════╝

use cathedral_utils::gram;
use rayon::prelude::*;
use std::time::Instant;

// ─── Arithmetic helpers ───

fn is_prime(n: usize) -> bool {
    if n < 2 { return false; }
    if n < 4 { return true; }
    if n % 2 == 0 || n % 3 == 0 { return false; }
    let mut i = 5;
    while i * i <= n {
        if n % i == 0 || n % (i + 2) == 0 { return false; }
        i += 6;
    }
    true
}

fn num_divisors(n: usize) -> usize {
    let mut count = 0;
    let mut d = 1;
    while d * d <= n {
        if n % d == 0 {
            count += 1;
            if d != n / d { count += 1; }
        }
        d += 1;
    }
    count
}

fn is_highly_composite(n: usize) -> bool {
    let dn = num_divisors(n);
    (1..n).all(|k| num_divisors(k) < dn)
}

// ─── Linear algebra helpers ───

/// Build the Gram matrix G_N (parallel, exact BD formula)
fn build_gram(n: usize) -> Vec<f64> {
    let dim = n - 1;
    let upper_indices: Vec<(usize, usize)> = (0..dim)
        .flat_map(|j| (j..dim).map(move |k| (j, k)))
        .collect();
    let entries: Vec<(usize, usize, f64)> = upper_indices
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

/// Full eigen-decomposition: returns (eigenvalues, eigenvectors as columns)
fn full_eigen(g_flat: &[f64], dim: usize) -> (Vec<f64>, nalgebra::DMatrix<f64>) {
    let mat = nalgebra::DMatrix::from_row_slice(dim, dim, g_flat);
    let eig = mat.symmetric_eigen();
    let eigenvalues: Vec<f64> = eig.eigenvalues.iter().cloned().collect();
    (eigenvalues, eig.eigenvectors)
}

/// Compute λ_min and minimum eigenvector
fn lambda_min_with_vec(g_flat: &[f64], dim: usize) -> (f64, Vec<f64>) {
    let mat = nalgebra::DMatrix::from_row_slice(dim, dim, g_flat);
    let eig = mat.symmetric_eigen();
    let mut min_idx = 0;
    let mut min_val = eig.eigenvalues[0];
    for i in 1..dim {
        if eig.eigenvalues[i] < min_val {
            min_val = eig.eigenvalues[i];
            min_idx = i;
        }
    }
    let v: Vec<f64> = (0..dim).map(|r| eig.eigenvectors[(r, min_idx)]).collect();
    (min_val, v)
}

/// Dot product
fn dot(a: &[f64], b: &[f64]) -> f64 {
    a.iter().zip(b.iter()).map(|(x, y)| x * y).sum()
}

/// Norm squared
fn norm_sq(v: &[f64]) -> f64 {
    v.iter().map(|x| x * x).sum()
}

/// Extract sub-matrix (top-left dim×dim corner)
fn extract_submatrix(full: &[f64], full_dim: usize, dim: usize) -> Vec<f64> {
    let mut sub = vec![0.0f64; dim * dim];
    for j in 0..dim {
        for k in 0..dim {
            sub[j * dim + k] = full[j * full_dim + k];
        }
    }
    sub
}

/// Linear regression in log-log space: y = C * x^α
fn power_law_fit(data: &[(f64, f64)]) -> (f64, f64, f64) {
    let n = data.len() as f64;
    let sx: f64 = data.iter().map(|(x, _)| x.ln()).sum();
    let sy: f64 = data.iter().map(|(_, y)| y.ln()).sum();
    let sxy: f64 = data.iter().map(|(x, y)| x.ln() * y.ln()).sum();
    let sx2: f64 = data.iter().map(|(x, _)| x.ln().powi(2)).sum();
    let alpha = (n * sxy - sx * sy) / (n * sx2 - sx * sx);
    let log_c = (sy - alpha * sx) / n;
    let c = log_c.exp();
    let mean_y = sy / n;
    let ss_tot: f64 = data.iter().map(|(_, y)| (y.ln() - mean_y).powi(2)).sum();
    let ss_res: f64 = data.iter()
        .map(|(x, y)| (y.ln() - (alpha * x.ln() + log_c)).powi(2)).sum();
    let r2 = 1.0 - ss_res / ss_tot;
    (c, alpha, r2)
}

// ─── Data structure ───

#[derive(Debug, Clone)]
struct AlignmentData {
    n: usize,
    lambda_min: f64,
    cos2_theta: f64,
    g_norm_sq: f64,
    schur: f64,
    eigen_drop: f64,
    drop_formula: f64, // cos²θ · ‖g‖² / S
    d_n: usize,
    is_prime: bool,
}

fn main() {
    let t_start = Instant::now();

    println!("╔═══════════════════════════════════════════════════════════════════╗");
    println!("║  COS²θ SPECTRAL STATISTICS — The Acoustic Alignment Probe       ║");
    println!("║  Does the alignment follow GOE statistics?                       ║");
    println!("║  BD Basis · cathedral-utils · HPDF-backed                        ║");
    println!("╚═══════════════════════════════════════════════════════════════════╝");
    println!();

    // ══════════════════════════════════════════════════
    // PHASE 1: Consecutive N analysis (N=3..600, direct computation)
    // ══════════════════════════════════════════════════

    println!("══════════════════════════════════════════════════════════════");
    println!("  PHASE 1: Consecutive cos²θ for N = 3..600 (direct Gram)");
    println!("══════════════════════════════════════════════════════════════");

    let max_n: usize = 600;
    let start_n: usize = 3;

    let t0 = Instant::now();
    let full_gram = build_gram(max_n);
    let full_dim = max_n - 1;
    println!("  [Built {}×{} Gram matrix in {:.1}s]", full_dim, full_dim, t0.elapsed().as_secs_f64());

    println!();
    println!("  {:>5} {:>12} {:>12} {:>12} {:>12} {:>10} {:>5} {:>4}",
        "N", "λ_min", "cos²θ", "‖g‖²", "Schur", "δ_N", "d(N)", "P?");
    println!("  {}", "─".repeat(85));

    let mut results: Vec<AlignmentData> = Vec::new();
    let mut prev_lmin = 0.0f64;

    for n in start_n..=max_n {
        let dim = n - 1;
        let sub = extract_submatrix(&full_gram, full_dim, dim);
        let (lmin, _v_min) = lambda_min_with_vec(&sub, dim);

        // Cross-correlation: g[i] = G[i, dim-1] (last column of sub, excluding diagonal)
        // Actually, g is the last column of G_N that connects G_{N-1} to the new vector.
        // In the bordered matrix [[G_{N-1}, g], [gᵀ, γ]], g[i] = gramEntry(i+1, N-1)
        // which is sub[i * dim + (dim-1)] for i = 0..dim-2
        let prev_dim = if dim > 1 { dim - 1 } else { 0 };
        let g_vec: Vec<f64> = (0..prev_dim).map(|i| sub[i * dim + prev_dim]).collect();
        let g_nsq = norm_sq(&g_vec);

        // The diagonal entry γ = G[N-1, N-1]
        let gamma = sub[prev_dim * dim + prev_dim];

        // cos²θ: projection of g onto v_min of G_{N-1}
        // We need v_min of G_{N-1}, not G_N
        let cos2 = if prev_dim >= 2 && g_nsq > 1e-30 {
            let prev_sub = extract_submatrix(&full_gram, full_dim, prev_dim);
            let (_, v_min_prev) = lambda_min_with_vec(&prev_sub, prev_dim);
            let proj = dot(&g_vec, &v_min_prev);
            proj * proj / g_nsq
        } else {
            0.0
        };

        // Schur complement S = γ - gᵀ G_{N-1}⁻¹ g
        // For simplicity, estimate via S ≈ γ - ‖g‖²/λ_max(G_{N-1})
        // Actually, let's compute it properly for small N
        let schur = if prev_dim >= 2 {
            let prev_sub = extract_submatrix(&full_gram, full_dim, prev_dim);
            let prev_mat = nalgebra::DMatrix::from_row_slice(prev_dim, prev_dim, &prev_sub);
            match prev_mat.clone().try_inverse() {
                Some(inv) => {
                    let g_col = nalgebra::DVector::from_row_slice(&g_vec);
                    let inv_g = &inv * &g_col;
                    gamma - g_col.dot(&inv_g)
                }
                None => gamma // fallback
            }
        } else {
            gamma
        };

        let drop = if n > start_n { (prev_lmin - lmin).max(0.0) } else { 0.0 };
        let drop_formula = if schur.abs() > 1e-20 { cos2 * g_nsq / schur } else { 0.0 };
        let dn = num_divisors(n);

        let datum = AlignmentData {
            n, lambda_min: lmin, cos2_theta: cos2,
            g_norm_sq: g_nsq, schur, eigen_drop: drop,
            drop_formula, d_n: dn, is_prime: is_prime(n),
        };

        // Print selected rows
        let show = n <= 20 || n % 50 == 0 || n == max_n
            || (is_prime(n) && n <= 100) || dn >= 12;
        if show {
            println!("  {:5} {:12.4e} {:12.4e} {:12.4e} {:12.4e} {:10.2e} {:5} {:>4}",
                n, lmin, cos2, g_nsq, schur, drop, dn,
                if datum.is_prime { "P" } else { "" });
        }

        results.push(datum);
        prev_lmin = lmin;

        if n % 100 == 0 && n > 30 {
            eprintln!("  ... N={} done ({:.0}s total)", n, t_start.elapsed().as_secs_f64());
        }
    }

    // ══════════════════════════════════════════════════
    // PHASE 2: cos²θ Scaling Analysis
    // ══════════════════════════════════════════════════

    println!();
    println!("══════════════════════════════════════════════════════════════");
    println!("  PHASE 2: cos²θ Power Law Scaling");
    println!("══════════════════════════════════════════════════════════════");

    let fit_data: Vec<(f64, f64)> = results.iter()
        .filter(|d| d.n >= 20 && d.cos2_theta > 1e-20)
        .map(|d| (d.n as f64, d.cos2_theta))
        .collect();

    if fit_data.len() >= 10 {
        let (c, alpha, r2) = power_law_fit(&fit_data);
        println!();
        println!("  ALL N:  cos²θ ≈ {:.4} · N^({:.4})    R² = {:.6}", c, alpha, r2);

        // Prime-only fit
        let prime_data: Vec<(f64, f64)> = results.iter()
            .filter(|d| d.n >= 20 && d.is_prime && d.cos2_theta > 1e-20)
            .map(|d| (d.n as f64, d.cos2_theta))
            .collect();
        if prime_data.len() >= 5 {
            let (cp, ap, rp) = power_law_fit(&prime_data);
            println!("  PRIMES: cos²θ ≈ {:.4} · N^({:.4})    R² = {:.6}", cp, ap, rp);
        }

        // Composite-only fit
        let comp_data: Vec<(f64, f64)> = results.iter()
            .filter(|d| d.n >= 20 && !d.is_prime && d.cos2_theta > 1e-20)
            .map(|d| (d.n as f64, d.cos2_theta))
            .collect();
        if comp_data.len() >= 5 {
            let (cc, ac, rc) = power_law_fit(&comp_data);
            println!("  COMPS:  cos²θ ≈ {:.4} · N^({:.4})    R² = {:.6}", cc, ac, rc);
        }
    }

    // ══════════════════════════════════════════════════
    // PHASE 3: Drop Formula Verification
    // ══════════════════════════════════════════════════

    println!();
    println!("══════════════════════════════════════════════════════════════");
    println!("  PHASE 3: Drop Formula — δ vs cos²θ·‖g‖²/S");
    println!("══════════════════════════════════════════════════════════════");
    println!();
    println!("  {:>5} {:>12} {:>12} {:>10}",
        "N", "δ_actual", "δ_formula", "ratio");
    println!("  {}", "─".repeat(45));

    for d in results.iter().filter(|d| d.n >= 5 && d.eigen_drop > 1e-15) {
        let show = d.n <= 20 || d.n % 100 == 0 || d.n == max_n || d.is_prime && d.n <= 100;
        if show {
            let ratio = if d.drop_formula > 1e-20 { d.eigen_drop / d.drop_formula } else { 0.0 };
            println!("  {:5} {:12.4e} {:12.4e} {:10.4}",
                d.n, d.eigen_drop, d.drop_formula, ratio);
        }
    }

    // ══════════════════════════════════════════════════
    // PHASE 4: Prime vs Composite Conditional Statistics
    // ══════════════════════════════════════════════════

    println!();
    println!("══════════════════════════════════════════════════════════════");
    println!("  PHASE 4: Prime vs Composite cos²θ Distributions");
    println!("══════════════════════════════════════════════════════════════");

    let prime_cos2: Vec<f64> = results.iter()
        .filter(|d| d.is_prime && d.n >= 20 && d.cos2_theta > 1e-20)
        .map(|d| d.cos2_theta)
        .collect();
    let comp_cos2: Vec<f64> = results.iter()
        .filter(|d| !d.is_prime && d.n >= 20 && d.cos2_theta > 1e-20)
        .map(|d| d.cos2_theta)
        .collect();

    if !prime_cos2.is_empty() && !comp_cos2.is_empty() {
        let prime_mean: f64 = prime_cos2.iter().sum::<f64>() / prime_cos2.len() as f64;
        let comp_mean: f64 = comp_cos2.iter().sum::<f64>() / comp_cos2.len() as f64;
        let prime_std: f64 = (prime_cos2.iter().map(|x| (x - prime_mean).powi(2)).sum::<f64>()
            / prime_cos2.len() as f64).sqrt();
        let comp_std: f64 = (comp_cos2.iter().map(|x| (x - comp_mean).powi(2)).sum::<f64>()
            / comp_cos2.len() as f64).sqrt();

        println!();
        println!("  {:>12} {:>10} {:>12} {:>12} {:>12}",
            "Category", "Count", "Mean cos²θ", "Std Dev", "CV");
        println!("  {}", "─".repeat(60));
        println!("  {:>12} {:>10} {:12.4e} {:12.4e} {:12.4}",
            "Primes", prime_cos2.len(), prime_mean, prime_std,
            if prime_mean > 0.0 { prime_std / prime_mean } else { 0.0 });
        println!("  {:>12} {:>10} {:12.4e} {:12.4e} {:12.4}",
            "Composites", comp_cos2.len(), comp_mean, comp_std,
            if comp_mean > 0.0 { comp_std / comp_mean } else { 0.0 });
        println!("  {:>12} {:>10} {:12.4}",
            "Ratio P/C", "", prime_mean / comp_mean);
    }

    // ══════════════════════════════════════════════════
    // PHASE 5: cos²θ · N Normalized — Does it converge?
    // ══════════════════════════════════════════════════

    println!();
    println!("══════════════════════════════════════════════════════════════");
    println!("  PHASE 5: Normalized cos²θ — Testing cos²θ · N^β stabilization");
    println!("══════════════════════════════════════════════════════════════");
    println!();

    // If cos²θ ~ C/N^α, then cos²θ · N^α → C
    // Try several normalizations
    for &beta in &[0.5, 1.0, 1.5, 2.0] {
        let normalized: Vec<(usize, f64)> = results.iter()
            .filter(|d| d.n >= 50 && d.cos2_theta > 1e-20)
            .map(|d| (d.n, d.cos2_theta * (d.n as f64).powf(beta)))
            .collect();

        if normalized.len() >= 10 {
            let vals: Vec<f64> = normalized.iter().map(|(_, v)| *v).collect();
            let mean: f64 = vals.iter().sum::<f64>() / vals.len() as f64;
            let std: f64 = (vals.iter().map(|x| (x - mean).powi(2)).sum::<f64>()
                / vals.len() as f64).sqrt();
            let cv = if mean > 0.0 { std / mean } else { f64::INFINITY };

            // Check trend: compare first half vs second half
            let half = normalized.len() / 2;
            let first_half: f64 = normalized[..half].iter().map(|(_, v)| v).sum::<f64>() / half as f64;
            let second_half: f64 = normalized[half..].iter().map(|(_, v)| v).sum::<f64>()
                / (normalized.len() - half) as f64;

            println!("  β={:.1}: cos²θ·N^β  mean={:.4e}  std={:.4e}  CV={:.4}  trend={:.4} (2nd/1st half)",
                beta, mean, std, cv, second_half / first_half);
        }
    }

    // ══════════════════════════════════════════════════
    // PHASE 6: Level Spacing Statistics of cos²θ
    // ══════════════════════════════════════════════════

    println!();
    println!("══════════════════════════════════════════════════════════════");
    println!("  PHASE 6: Level Spacing of cos²θ (GOE/GUE/Poisson test)");
    println!("══════════════════════════════════════════════════════════════");

    // Sort cos²θ values and compute nearest-neighbor spacings
    let mut sorted_cos2: Vec<f64> = results.iter()
        .filter(|d| d.n >= 20 && d.cos2_theta > 1e-20)
        .map(|d| d.cos2_theta.ln())  // Work in log scale
        .collect();
    sorted_cos2.sort_by(|a, b| a.partial_cmp(b).unwrap());

    if sorted_cos2.len() >= 20 {
        let spacings: Vec<f64> = sorted_cos2.windows(2)
            .map(|w| (w[1] - w[0]).abs())
            .collect();
        let mean_s: f64 = spacings.iter().sum::<f64>() / spacings.len() as f64;
        let normalized_spacings: Vec<f64> = spacings.iter().map(|s| s / mean_s).collect();

        // Compute <r> ratio (ratio of consecutive spacings — a standard RMT diagnostic)
        // For GOE: <r> ≈ 0.5307
        // For GUE: <r> ≈ 0.6027
        // For Poisson: <r> ≈ 0.3863
        let r_ratios: Vec<f64> = normalized_spacings.windows(2)
            .map(|w| {
                let s_n = w[0];
                let s_n1 = w[1];
                s_n.min(s_n1) / s_n.max(s_n1)
            })
            .collect();
        let mean_r: f64 = r_ratios.iter().sum::<f64>() / r_ratios.len() as f64;

        // P(s=0) test: fraction of very small spacings
        // GOE has level repulsion (P(s→0) → 0), Poisson doesn't
        let small_frac = normalized_spacings.iter()
            .filter(|&&s| s < 0.1).count() as f64 / normalized_spacings.len() as f64;

        // Variance of spacings
        let var_s: f64 = normalized_spacings.iter()
            .map(|s| (s - 1.0).powi(2)).sum::<f64>() / normalized_spacings.len() as f64;

        println!();
        println!("  Spacing analysis ({} spacings from {} cos²θ values):", spacings.len(), sorted_cos2.len());
        println!();
        println!("  ⟨r⟩ ratio = {:.4}", mean_r);
        println!("    GOE  prediction: 0.5307");
        println!("    GUE  prediction: 0.6027");
        println!("    Poisson predict: 0.3863");
        println!();
        println!("  P(s < 0.1) = {:.4}", small_frac);
        println!("    GOE/GUE have level repulsion → P(s→0) ≈ 0");
        println!("    Poisson has clustering → P(s→0) ≈ 0.10");
        println!();
        println!("  Var(s/⟨s⟩) = {:.4}", var_s);
        println!("    GOE: ~0.286,  Poisson: ~1.000");

        // Classification
        let classification = if (mean_r - 0.5307).abs() < 0.05 {
            "GOE (β=1)"
        } else if (mean_r - 0.6027).abs() < 0.05 {
            "GUE (β=2)"
        } else if (mean_r - 0.3863).abs() < 0.05 {
            "Poisson (uncorrelated)"
        } else {
            "Intermediate / unknown"
        };

        println!();
        println!("  ┌──────────────────────────────────────────────┐");
        println!("  │ CLASSIFICATION: {:<30} │", classification);
        println!("  └──────────────────────────────────────────────┘");
    }

    // ══════════════════════════════════════════════════
    // PHASE 7: Divisor Correlation
    // ══════════════════════════════════════════════════

    println!();
    println!("══════════════════════════════════════════════════════════════");
    println!("  PHASE 7: cos²θ vs d(N) — Arithmetic Correlation");
    println!("══════════════════════════════════════════════════════════════");
    println!();

    // Group by divisor count and compute mean cos²θ
    let mut by_divisor: std::collections::HashMap<usize, Vec<f64>> = std::collections::HashMap::new();
    for d in results.iter().filter(|d| d.n >= 20 && d.cos2_theta > 1e-20) {
        by_divisor.entry(d.d_n).or_default().push(d.cos2_theta);
    }

    let mut divisor_groups: Vec<(usize, usize, f64)> = by_divisor.iter()
        .map(|(&d, vals)| {
            let mean: f64 = vals.iter().sum::<f64>() / vals.len() as f64;
            (d, vals.len(), mean)
        })
        .collect();
    divisor_groups.sort_by_key(|&(d, _, _)| d);

    println!("  {:>6} {:>8} {:>14} {:>12}",
        "d(N)", "count", "mean cos²θ", "ratio/d=2");
    println!("  {}", "─".repeat(45));

    let base_mean = divisor_groups.iter()
        .find(|&&(d, _, _)| d == 2)
        .map(|&(_, _, m)| m)
        .unwrap_or(1.0);

    for &(d, count, mean) in &divisor_groups {
        if count >= 3 {
            println!("  {:6} {:8} {:14.4e} {:12.4}",
                d, count, mean, mean / base_mean);
        }
    }

    println!();
    println!("  Total runtime: {:.1}s", t_start.elapsed().as_secs_f64());
    println!();
}
