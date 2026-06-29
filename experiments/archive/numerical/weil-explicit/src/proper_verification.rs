#![allow(unused, dead_code, non_snake_case)]
use nalgebra::{DMatrix, DVector, SymmetricEigen};
use rayon::prelude::*;
use std::f64::consts::PI;

// ══════════════════════════════════════════════════════════════════════
// PROPER d²_N VERIFICATION WITH nalgebra
//
// Uses THREE independent methods to compute the NB distance:
//
// Method 1: Spectral decomposition via nalgebra's SymmetricEigen
//    d²_N = 1 - Σ (b·v_i)²/λ_i  (eigenvalues + eigenvectors of 2n×2n)
//
// Method 2: Cholesky solve via nalgebra (for positive definite matrices)
//    G = LL†, solve Gc = b, d² = 1 - b†c
//
// Method 3: Direct quadrature (independent numerical integration)
//    ||1 - Σ c_k f_k(x)||²  computed by midpoint rule
//
// All three must agree for the result to be trustworthy.
// ══════════════════════════════════════════════════════════════════════

fn frac_part(x: f64) -> f64 {
    x - x.floor()
}

fn gram_entry_real(j: usize, k: usize, n_pts: usize) -> f64 {
    let (jf, kf) = (j as f64, k as f64);
    let dx = 1.0 / n_pts as f64;
    let mut s = 0.0f64;
    for i in 0..n_pts {
        let x = (i as f64 + 0.5) * dx;
        s += frac_part(jf / x) * frac_part(kf / x);
    }
    s * dx
}

fn gram_entry_fourier(j: usize, k: usize, alpha: f64, n_pts: usize) -> (f64, f64) {
    let (jf, kf) = (j as f64, k as f64);
    let diff = (j as f64 - k as f64) * alpha;
    let dx = 1.0 / n_pts as f64;
    let (mut sr, mut si) = (0.0f64, 0.0f64);
    for i in 0..n_pts {
        let x = (i as f64 + 0.5) * dx;
        let base = frac_part(jf / x) * frac_part(kf / x);
        let phase = diff / x;
        sr += base * phase.cos();
        si += base * phase.sin();
    }
    (sr * dx, si * dx)
}

fn nb_target_real(k: usize, n_pts: usize) -> f64 {
    let kf = k as f64;
    let dx = 1.0 / n_pts as f64;
    let mut s = 0.0f64;
    for i in 0..n_pts {
        let x = (i as f64 + 0.5) * dx;
        s += frac_part(kf / x);
    }
    s * dx
}

fn nb_target_complex(k: usize, alpha: f64, n_pts: usize) -> (f64, f64) {
    let kf = k as f64;
    let dx = 1.0 / n_pts as f64;
    let (mut sr, mut si) = (0.0f64, 0.0f64);
    for i in 0..n_pts {
        let x = (i as f64 + 0.5) * dx;
        let f = frac_part(kf / x);
        let phase = -alpha * kf / x;
        sr += f * phase.cos();
        si += f * phase.sin();
    }
    (sr * dx, si * dx)
}

/// Direct quadrature of ||1 - Σ c_k f_k||²
fn nb_residual_direct(c_re: &[f64], c_im: &[f64], alpha: f64, dim: usize, n_pts: usize) -> f64 {
    let dx = 1.0 / n_pts as f64;
    let mut total = 0.0f64;
    for i in 0..n_pts {
        let x = (i as f64 + 0.5) * dx;
        let (mut ar, mut ai) = (0.0f64, 0.0f64);
        for j in 0..dim {
            let k = j + 2;
            let fv = frac_part(k as f64 / x);
            let phase = alpha * k as f64 / x;
            let (cp, sp) = (phase.cos(), phase.sin());
            ar += fv * (c_re[j] * cp - c_im[j] * sp);
            ai += fv * (c_re[j] * sp + c_im[j] * cp);
        }
        total += (1.0 - ar).powi(2) + ai.powi(2);
    }
    total * dx
}

/// Build and return the 2n×2n real symmetric embedding as a nalgebra DMatrix
fn build_embedded_gram(dim: usize, alpha: f64, n_pts: usize) -> (DMatrix<f64>, DVector<f64>) {
    let m = 2 * dim;

    // Compute complex Gram entries
    let entries: Vec<((usize, usize), (f64, f64))> = (0..dim)
        .into_par_iter()
        .flat_map(|j| {
            (j..dim).into_par_iter().map(move |k| {
                if alpha == 0.0 {
                    ((j, k), (gram_entry_real(j + 2, k + 2, n_pts), 0.0))
                } else {
                    let (re, im) = gram_entry_fourier(j + 2, k + 2, alpha, n_pts);
                    ((j, k), (re, im))
                }
            })
        })
        .collect();

    let mut gre = vec![vec![0.0; dim]; dim];
    let mut gim = vec![vec![0.0; dim]; dim];
    for ((j, k), (re, im)) in &entries {
        gre[*j][*k] = *re;
        gre[*k][*j] = *re;
        gim[*j][*k] = *im;
        gim[*k][*j] = -*im;
    }

    // Build 2n×2n embedding
    let mut mat = DMatrix::<f64>::zeros(m, m);
    for i in 0..dim {
        for j in 0..dim {
            mat[(i, j)] = gre[i][j];
            mat[(i, dim + j)] = -gim[i][j];
            mat[(dim + i, j)] = gim[i][j];
            mat[(dim + i, dim + j)] = gre[i][j];
        }
    }

    // Build target vector
    let mut b = DVector::<f64>::zeros(m);
    if alpha == 0.0 {
        for j in 0..dim {
            b[j] = nb_target_real(j + 2, n_pts);
            b[dim + j] = 0.0;
        }
    } else {
        for j in 0..dim {
            let (re, im) = nb_target_complex(j + 2, alpha, n_pts);
            b[j] = re;
            b[dim + j] = im;
        }
    }

    (mat, b)
}

// ══════════════════════════════════════════════════════════════════════

fn main() {
    println!("╔══════════════════════════════════════════════════════════════════╗");
    println!("║  PROPER d²_N VERIFICATION WITH nalgebra                        ║");
    println!("║  Three independent methods must agree                          ║");
    println!("╚══════════════════════════════════════════════════════════════════╝\n");

    let total_start = std::time::Instant::now();
    let n_pts = 150_000;

    let test_alphas = vec![
        0.0, 0.05, 0.1, 0.15, 0.2, 0.3, 0.5, 0.7, 0.8, 0.85, 0.9, 1.0, 1.5, 2.0,
    ];

    // ════════════════════════════════════════════════════════════════
    // TEST A: Detailed analysis at N = 100
    // ════════════════════════════════════════════════════════════════
    let max_n: usize = 100;
    let dim = max_n - 1;

    println!("═══════════════════════════════════════════════════════════════════");
    println!(
        "  TEST A: Three-method comparison at N = {} (dim = {})",
        max_n, dim
    );
    println!("═══════════════════════════════════════════════════════════════════\n");

    println!(
        "  {:>5} │ {:>14} {:>14} {:>14} │ {:>10} {:>10} {:>7} │ {:>8}",
        "α", "d² spectral", "d² Cholesky", "d² quadrature", "λ_min", "λ_max", "κ", "||c||"
    );
    println!(
        "  {}┼{}┼{}┼{}",
        "─".repeat(6),
        "─".repeat(45),
        "─".repeat(30),
        "─".repeat(10)
    );

    for &alpha in &test_alphas {
        let start = std::time::Instant::now();

        let (mat, bvec) = build_embedded_gram(dim, alpha, n_pts);

        // ── Method 1: Spectral decomposition ──────────────────────
        let eig = SymmetricEigen::new(mat.clone());
        let eigenvalues = &eig.eigenvalues;
        let eigenvectors = &eig.eigenvectors;

        // d² = 1 - Σ (b·v_i)²/λ_i  (summing over ALL 2n eigenvalues)
        let mut spectral_sum = 0.0f64;
        for i in 0..eigenvalues.len() {
            let lam = eigenvalues[i];
            if lam.abs() > 1e-15 {
                let bvi: f64 = bvec.dot(&eigenvectors.column(i));
                spectral_sum += bvi * bvi / lam;
            }
        }
        let d2_spectral = (1.0 - spectral_sum).max(-1e-10);

        // Extract eigenvalue statistics
        let mut sorted_eigs: Vec<f64> = eigenvalues.iter().cloned().collect();
        sorted_eigs.sort_by(|a, b| a.partial_cmp(b).unwrap());
        let lmin = sorted_eigs[0];
        let lmax = sorted_eigs[sorted_eigs.len() - 1];
        let kappa = if lmin.abs() > 1e-15 {
            (lmax / lmin).abs()
        } else {
            f64::INFINITY
        };

        // ── Method 2: Cholesky solve ──────────────────────────────
        let d2_cholesky;
        let c_norm_val;
        let chol_result = nalgebra::linalg::Cholesky::new(mat.clone());
        if let Some(chol) = chol_result {
            let c = chol.solve(&bvec);
            let btc = bvec.dot(&c);
            d2_cholesky = (1.0 - btc).max(-1e-10);
            c_norm_val = c.norm();
        } else {
            // Not positive definite — fall back to LU
            let lu = mat.clone().lu();
            match lu.solve(&bvec) {
                Some(c) => {
                    let btc = bvec.dot(&c);
                    d2_cholesky = (1.0 - btc).max(-1e-10);
                    c_norm_val = c.norm();
                }
                None => {
                    d2_cholesky = f64::NAN;
                    c_norm_val = f64::NAN;
                }
            }
        }

        // ── Method 3: Direct quadrature ───────────────────────────
        // Get coefficients from the best available solve
        let c_vec;
        let chol2 = nalgebra::linalg::Cholesky::new(mat.clone());
        if let Some(chol) = chol2 {
            c_vec = chol.solve(&bvec);
        } else {
            let lu = mat.clone().lu();
            c_vec = lu.solve(&bvec).unwrap_or(DVector::zeros(2 * dim));
        }
        let c_re: Vec<f64> = c_vec.rows(0, dim).iter().cloned().collect();
        let c_im: Vec<f64> = c_vec.rows(dim, dim).iter().cloned().collect();
        let d2_quadrature = nb_residual_direct(&c_re, &c_im, alpha, dim, n_pts);

        let time = start.elapsed().as_secs_f64();

        // Agreement check
        let agree_sc = (d2_spectral - d2_cholesky).abs();
        let agree_sq = (d2_spectral - d2_quadrature).abs();
        let status = if agree_sc < 0.001 && agree_sq < 0.01 {
            "✅"
        } else if agree_sc < 0.01 {
            "⚠️"
        } else {
            "❌"
        };

        println!(
            "  {:5.2} │ {:14.8} {:14.8} {:14.8} │ {:10.6} {:10.4} {:7.1} │ {:8.4}  {} ({:.1}s)",
            alpha,
            d2_spectral,
            d2_cholesky,
            d2_quadrature,
            lmin,
            lmax,
            kappa,
            c_norm_val,
            status,
            time
        );
    }

    // ════════════════════════════════════════════════════════════════
    // TEST B: d²_N convergence across N
    // ════════════════════════════════════════════════════════════════
    println!("\n═══════════════════════════════════════════════════════════════════");
    println!("  TEST B: d²_N convergence (spectral method) for key α values");
    println!("═══════════════════════════════════════════════════════════════════\n");

    let n_sizes = vec![50, 75, 100, 150, 200, 250];
    let key_alphas = vec![0.0, 0.1, 0.2, 0.5, 0.8, 1.0];

    // Header
    print!("  {:>5} │", "N");
    for &a in &key_alphas {
        print!(" {:>12}", format!("α={:.1}", a));
    }
    println!();
    println!("  {}┼{}", "─".repeat(6), "─".repeat(13 * key_alphas.len()));

    for &max_n in &n_sizes {
        let dim = max_n - 1;
        print!("  {:5} │", max_n);

        for &alpha in &key_alphas {
            let (mat, bvec) = build_embedded_gram(dim, alpha, n_pts);
            let eig = SymmetricEigen::new(mat);
            let eigenvalues = &eig.eigenvalues;
            let eigenvectors = &eig.eigenvectors;

            let mut spectral_sum = 0.0f64;
            for i in 0..eigenvalues.len() {
                let lam = eigenvalues[i];
                if lam.abs() > 1e-15 {
                    let bvi: f64 = bvec.dot(&eigenvectors.column(i));
                    spectral_sum += bvi * bvi / lam;
                }
            }
            let d2 = (1.0 - spectral_sum).max(0.0);
            print!(" {:12.8}", d2);
        }
        println!();
    }

    // ════════════════════════════════════════════════════════════════
    // TEST C: λ_min convergence (verified with nalgebra)
    // ════════════════════════════════════════════════════════════════
    println!("\n═══════════════════════════════════════════════════════════════════");
    println!("  TEST C: λ_min convergence (nalgebra SymmetricEigen)");
    println!("═══════════════════════════════════════════════════════════════════\n");

    // Header
    print!("  {:>5} │", "N");
    for &a in &key_alphas {
        print!(" {:>12}", format!("α={:.1}", a));
    }
    println!();
    println!("  {}┼{}", "─".repeat(6), "─".repeat(13 * key_alphas.len()));

    for &max_n in &n_sizes {
        let dim = max_n - 1;
        print!("  {:5} │", max_n);

        for &alpha in &key_alphas {
            let (mat, _) = build_embedded_gram(dim, alpha, n_pts);
            let eig = SymmetricEigen::new(mat);
            let mut eigs: Vec<f64> = eig.eigenvalues.iter().cloned().collect();
            eigs.sort_by(|a, b| a.partial_cmp(b).unwrap());

            // For the 2n×2n embedding, eigenvalues come in pairs
            // Extract distinct (take every other)
            let lmin = eigs[0];
            print!(" {:12.8}", lmin);
        }
        println!();
    }

    // ════════════════════════════════════════════════════════════════
    // TEST D: Ratio test ⟨r⟩ with nalgebra eigenvalues
    // ════════════════════════════════════════════════════════════════
    println!("\n═══════════════════════════════════════════════════════════════════");
    println!("  TEST D: Ratio test ⟨r⟩ with nalgebra eigenvalues");
    println!("═══════════════════════════════════════════════════════════════════\n");

    print!("  {:>5} │", "N");
    for &a in &key_alphas {
        print!(" {:>12}", format!("α={:.1}", a));
    }
    println!();
    println!("  {}┼{}", "─".repeat(6), "─".repeat(13 * key_alphas.len()));

    for &max_n in &[75, 100, 150, 200] {
        let dim = max_n - 1;
        print!("  {:5} │", max_n);

        for &alpha in &key_alphas {
            let (mat, _) = build_embedded_gram(dim, alpha, n_pts);
            let eig = SymmetricEigen::new(mat);
            let mut eigs: Vec<f64> = eig.eigenvalues.iter().cloned().collect();
            eigs.sort_by(|a, b| a.partial_cmp(b).unwrap());

            // Extract distinct eigenvalues (remove Kramers pairs from 2n×2n)
            let distinct = extract_distinct(&eigs, 1e-8);
            let rm = ratio_mean(&distinct);

            let class = classify(rm);
            print!(" {:6.4} {:>5}", rm, class);
        }
        println!();
    }

    // ════════════════════════════════════════════════════════════════
    // TEST E: Fine α scan of d²_N at N=100
    // ════════════════════════════════════════════════════════════════
    println!("\n═══════════════════════════════════════════════════════════════════");
    println!("  TEST E: Fine α scan of d²_N at N=100 (spectral method)");
    println!("═══════════════════════════════════════════════════════════════════\n");

    let dim = 99;
    println!(
        "  {:>6} {:>14} {:>12} {:>12} {:>8}",
        "α", "d²_N", "λ_min", "κ", "Status"
    );
    println!("  {}", "─".repeat(55));

    for i in 0..=40 {
        let alpha = i as f64 * 0.05;
        let (mat, bvec) = build_embedded_gram(dim, alpha, n_pts);
        let eig = SymmetricEigen::new(mat);
        let eigenvalues = &eig.eigenvalues;
        let eigenvectors = &eig.eigenvectors;

        let mut spectral_sum = 0.0f64;
        for i in 0..eigenvalues.len() {
            let lam = eigenvalues[i];
            if lam.abs() > 1e-15 {
                let bvi: f64 = bvec.dot(&eigenvectors.column(i));
                spectral_sum += bvi * bvi / lam;
            }
        }
        let d2 = (1.0 - spectral_sum).max(0.0);

        let mut sorted_eigs: Vec<f64> = eigenvalues.iter().cloned().collect();
        sorted_eigs.sort_by(|a, b| a.partial_cmp(b).unwrap());
        let lmin = sorted_eigs[0];
        let lmax = sorted_eigs[sorted_eigs.len() - 1];
        let kappa = if lmin.abs() > 1e-15 {
            lmax / lmin
        } else {
            f64::INFINITY
        };

        let status = if d2 < 1e-8 {
            "≡0"
        } else if d2 < 0.01 {
            "≈0"
        } else {
            "≫0"
        };

        println!(
            "  {:6.2} {:14.10} {:12.8} {:12.1} {:>8}",
            alpha, d2, lmin, kappa, status
        );
    }

    // ────────── Verdict ──────────
    println!("\n╔══════════════════════════════════════════════════════════════════╗");
    println!("║                PROPER VERIFICATION VERDICT                      ║");
    println!("╠══════════════════════════════════════════════════════════════════╣");
    println!("║                                                                ║");
    println!("║  Three methods compared:                                       ║");
    println!("║    1. Spectral: d² = 1 - Σ(b·vᵢ)²/λᵢ  (eigenvectors)        ║");
    println!("║    2. Cholesky: d² = 1 - b†·G⁻¹·b      (LL† factorization)   ║");
    println!("║    3. Quadrature: ||1-Σcₖfₖ||²          (direct integration)  ║");
    println!("║                                                                ║");
    println!("║  ✅ = all three agree   ⚠️ = methods 1,2 agree but not 3      ║");
    println!("║  ❌ = disagreement (numerical instability)                     ║");
    println!("║                                                                ║");
    println!("║  The spectral method is the most numerically stable because    ║");
    println!("║  it doesn't require solving a linear system.                   ║");
    println!("║                                                                ║");
    println!("╚══════════════════════════════════════════════════════════════════╝\n");

    println!(
        "  Total time: {:.1}s\n",
        total_start.elapsed().as_secs_f64()
    );
}

// ── Utility functions ────────────────────────────────────────────────

fn extract_distinct(eigenvalues: &[f64], tol: f64) -> Vec<f64> {
    let mut d = Vec::new();
    let mut i = 0;
    while i < eigenvalues.len() {
        d.push(eigenvalues[i]);
        if i + 1 < eigenvalues.len() && (eigenvalues[i + 1] - eigenvalues[i]).abs() < tol {
            i += 2;
        } else {
            i += 1;
        }
    }
    d
}

fn ratio_mean(ev: &[f64]) -> f64 {
    if ev.len() < 3 {
        return 0.0;
    }
    let mut ratios = Vec::new();
    for i in 0..(ev.len() - 2) {
        let s1 = ev[i + 1] - ev[i];
        let s2 = ev[i + 2] - ev[i + 1];
        if s1 > 1e-15 && s2 > 1e-15 {
            ratios.push(s1.min(s2) / s1.max(s2));
        }
    }
    if ratios.is_empty() {
        0.0
    } else {
        ratios.iter().sum::<f64>() / ratios.len() as f64
    }
}

fn classify(rm: f64) -> &'static str {
    let d = [
        ("Poi", 0.3863),
        ("GOE", 0.5307),
        ("GUE", 0.5996),
        ("GSE", 0.6744),
    ];
    d.iter()
        .min_by(|a, b| (rm - a.1).abs().partial_cmp(&(rm - b.1).abs()).unwrap())
        .unwrap()
        .0
}
