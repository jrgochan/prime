#![allow(unused, dead_code, non_snake_case)]
use rayon::prelude::*;

// ══════════════════════════════════════════════════════════
// OPERATOR THEORY ANALYSIS
//
// The Gram matrix G_N is the finite-rank restriction of an
// integral operator T on L²(0,1):
//
//   (Tf)(x) = ∫₀¹ K_N(x,y) f(y) dy
//   K_N(x,y) = Σ_{k=2}^{N+1} {k/x}{k/y}
//
// Key questions:
// 1. Does v_min(x) ≈ ψ(x) for a "universal" eigenfunction ψ?
// 2. How does v_min evolve as N grows?
// 3. What controls the projection gᵀ v_min?
// 4. Can we decompose the drop into operator-theoretic quantities?
// ══════════════════════════════════════════════════════════

fn frac_part(x: f64) -> f64 { x - x.floor() }

fn gram_entry(j: usize, k: usize, n_pts: usize) -> f64 {
    let jf = j as f64;
    let kf = k as f64;
    let dx = 1.0 / n_pts as f64;
    let mut sum = 0.0f64;
    for i in 0..n_pts {
        let x = (i as f64 + 0.5) * dx;
        sum += frac_part(jf / x) * frac_part(kf / x);
    }
    sum * dx
}

fn lu_decompose(a: &mut Vec<Vec<f64>>) -> Vec<usize> {
    let n = a.len();
    let mut piv: Vec<usize> = (0..n).collect();
    for col in 0..n {
        let mut max_row = col;
        for row in (col+1)..n {
            if a[row][col].abs() > a[max_row][col].abs() { max_row = row; }
        }
        if max_row != col { a.swap(col, max_row); piv.swap(col, max_row); }
        if a[col][col].abs() < 1e-15 { continue; }
        for row in (col+1)..n {
            a[row][col] /= a[col][col];
            let f = a[row][col];
            for j in (col+1)..n { a[row][j] -= f * a[col][j]; }
        }
    }
    piv
}

fn lu_solve(lu: &[Vec<f64>], piv: &[usize], b: &[f64]) -> Vec<f64> {
    let n = b.len();
    let mut x: Vec<f64> = piv.iter().map(|&i| b[i]).collect();
    for i in 1..n { for j in 0..i { let f = lu[i][j]; x[i] -= f * x[j]; } }
    for i in (0..n).rev() {
        for j in (i+1)..n { x[i] -= lu[i][j] * x[j]; }
        x[i] /= lu[i][i];
    }
    x
}

// Inverse iteration for k smallest eigenvalues
fn smallest_eigenpairs(mat: &[Vec<f64>], k: usize, n_iter: usize) -> Vec<(f64, Vec<f64>)> {
    let n = mat.len();
    let mut results = Vec::new();
    let mut deflated = mat.to_vec();

    for _ in 0..k {
        let mut lu = deflated.clone();
        let piv = lu_decompose(&mut lu);
        let mut v = vec![1.0 / (n as f64).sqrt(); n];
        // Perturb to avoid converging to zero
        for i in 0..n { v[i] += 0.001 * ((i * 7 + 3) % 11) as f64 / 11.0; }
        let norm0: f64 = v.iter().map(|x| x*x).sum::<f64>().sqrt();
        for x in v.iter_mut() { *x /= norm0; }

        for _ in 0..n_iter {
            let w = lu_solve(&lu, &piv, &v);
            let norm: f64 = w.iter().map(|x| x*x).sum::<f64>().sqrt();
            if norm < 1e-15 { break; }
            v = w.iter().map(|x| x / norm).collect();
        }
        let mut w = vec![0.0; n];
        for i in 0..n { for j in 0..n { w[i] += mat[i][j] * v[j]; } }
        let lam: f64 = v.iter().zip(w.iter()).map(|(a, b)| a * b).sum();
        results.push((lam, v.clone()));

        // Deflate: A' = A - λ v vᵀ  (but in a numerically stable way)
        // Actually for finding the next eigenvalue, shift instead
        let shift = lam * 1.5;
        for i in 0..n {
            for j in 0..n {
                deflated[i][j] = mat[i][j] - shift * v[i] * v[j];
                // Also subtract previous eigenvectors
                for prev in &results[..results.len()-1] {
                    deflated[i][j] -= prev.0 * 1.5 * prev.1[i] * prev.1[j];
                }
            }
        }
    }
    results
}

fn main() {
    println!("═══════════════════════════════════════════════════════════════");
    println!("  OPERATOR THEORY ANALYSIS");
    println!("  Understanding v_min evolution and the integral operator");
    println!("═══════════════════════════════════════════════════════════════");

    let n_pts = 200_000;
    let start = std::time::Instant::now();

    // ────────────────────────────────────────────────────────
    // Phase 1: Compute large Gram matrix (N=1000)
    // ────────────────────────────────────────────────────────
    let max_n: usize = 1000;
    println!("\n[1/5] Computing {}×{} Gram matrix ({} pts)...",
        max_n-1, max_n-1, n_pts);
    let dim = max_n - 1;
    let gram_upper: Vec<Vec<f64>> = (0..dim).into_par_iter().map(|j| {
        let mut row = vec![0.0; dim];
        for k in j..dim { row[k] = gram_entry(j + 2, k + 2, n_pts); }
        row
    }).collect();
    let mut gram = vec![vec![0.0; dim]; dim];
    for j in 0..dim {
        for k in j..dim {
            gram[j][k] = gram_upper[j][k];
            gram[k][j] = gram_upper[j][k];
        }
    }
    println!("  Done in {:.1}s", start.elapsed().as_secs_f64());

    // ────────────────────────────────────────────────────────
    // Phase 2: Eigenvector evolution
    // Track how v_min changes as N grows
    // ────────────────────────────────────────────────────────
    println!("\n[2/5] Eigenvector evolution analysis...\n");

    let checkpoints = [50, 100, 150, 200, 250, 300, 400, 500, 600, 700, 800, 900, 999];
    let mut prev_v: Option<Vec<f64>> = None;
    let mut prev_lam = 0.0;
    let mut eigvec_data: Vec<(usize, f64, Vec<f64>)> = Vec::new();

    println!("  {:>5} {:>12} {:>12} {:>12} {:>10} {:>10}",
        "N", "λ_min", "||Δv||", "Σv_min", "v[2]", "v[N/2]");

    for &n in &checkpoints {
        let d = n - 1;
        let sub: Vec<Vec<f64>> = gram[..d].iter().map(|r| r[..d].to_vec()).collect();
        let pairs = smallest_eigenpairs(&sub, 1, 500);
        let (lam, v) = &pairs[0];

        // Ensure consistent sign (v[0] > 0)
        let sign = if v[0] >= 0.0 { 1.0 } else { -1.0 };
        let v_signed: Vec<f64> = v.iter().map(|x| x * sign).collect();

        let v_sum: f64 = v_signed.iter().sum();
        let v_half = if d / 2 < v_signed.len() { v_signed[d / 2].abs() } else { 0.0 };

        let delta_v = if let Some(ref pv) = prev_v {
            let min_len = pv.len().min(v_signed.len());
            let diff_sq: f64 = (0..min_len)
                .map(|i| (pv[i] - v_signed[i]).powi(2)).sum::<f64>();
            diff_sq.sqrt()
        } else { 0.0 };

        println!("  {:5} {:12.8} {:12.6} {:12.6} {:10.6} {:10.6}",
            n, lam, delta_v, v_sum, v_signed[0].abs(), v_half);

        eigvec_data.push((n, *lam, v_signed.clone()));
        prev_v = Some(v_signed);
        prev_lam = *lam;
    }

    // ────────────────────────────────────────────────────────
    // Phase 3: Universal eigenfunction test
    // Does v_min[k] ≈ ψ(k/N) for rescaled k?
    // ────────────────────────────────────────────────────────
    println!("\n[3/5] Universal eigenfunction test...\n");
    println!("  If v_min[k] = ψ(k/N), plotting at fixed k/N should collapse:");
    println!("  {:>5} {:>8} {:>10} {:>10} {:>10} {:>10} {:>10}",
        "k/N", "N=100", "N=200", "N=300", "N=500", "N=700", "N=999");

    let ratios = [0.05, 0.10, 0.20, 0.30, 0.50, 0.70, 0.90];
    for &r in &ratios {
        print!("  {:5.2}", r);
        for &(n, _, ref v) in &eigvec_data {
            let k = ((n as f64 - 1.0) * r) as usize;
            if k < v.len() {
                // Scale by sqrt(N) to remove normalization effect
                let scaled = v[k] * (v.len() as f64).sqrt();
                print!(" {:10.4}", scaled);
            } else {
                print!(" {:>10}", "—");
            }
        }
        println!();
    }

    // ────────────────────────────────────────────────────────
    // Phase 4: Spectral gap and perturbation bounds
    // ────────────────────────────────────────────────────────
    println!("\n[4/5] Spectral gap analysis...\n");

    println!("  {:>5} {:>12} {:>12} {:>12} {:>12}",
        "N", "λ₁", "λ₂", "gap", "gap/λ₁");

    for &n in &[50, 100, 200, 300, 500, 700, 999] {
        let d = n - 1;
        let sub: Vec<Vec<f64>> = gram[..d].iter().map(|r| r[..d].to_vec()).collect();
        let pairs = smallest_eigenpairs(&sub, 2, 500);
        if pairs.len() >= 2 {
            let lam1 = pairs[0].0;
            let lam2 = pairs[1].0;
            let gap = lam2 - lam1;
            println!("  {:5} {:12.8} {:12.8} {:12.8} {:12.6}",
                n, lam1, lam2, gap, gap / lam1);
        }
    }

    // ────────────────────────────────────────────────────────
    // Phase 5: Drop prediction from operator theory
    // ────────────────────────────────────────────────────────
    println!("\n[5/5] Operator-theoretic drop analysis...\n");

    println!("  For EVERY N from 2 to 999, compute:");
    println!("  δ_N, |gᵀv|, Schur, ||g - proj||, normalized projection\n");

    println!("  {:>5} {:>10} {:>10} {:>10} {:>10} {:>12}",
        "N", "δ_N", "|gᵀv|/||g||", "Schur", "||g||", "δ·N");

    let mut drop_data: Vec<(usize, f64, f64, f64)> = Vec::new();
    let mut prev_lam_all = gram[0][0]; // G_2 = 1x1 matrix

    for n in 3..=max_n {
        let d = n - 1; // dim of G_N
        let sub: Vec<Vec<f64>> = gram[..d].iter().map(|r| r[..d].to_vec()).collect();

        // Quick eigenvalue by inverse iteration
        let mut lu = sub.clone();
        let piv = lu_decompose(&mut lu);
        let mut v = vec![1.0 / (d as f64).sqrt(); d];
        for _ in 0..300 {
            let w = lu_solve(&lu, &piv, &v);
            let norm: f64 = w.iter().map(|x| x*x).sum::<f64>().sqrt();
            if norm < 1e-15 { break; }
            v = w.iter().map(|x| x / norm).collect();
        }
        let mut w = vec![0.0; d];
        for i in 0..d { for j in 0..d { w[i] += sub[i][j] * v[j]; } }
        let lam: f64 = v.iter().zip(w.iter()).map(|(a, b)| a * b).sum();

        let drop = if n > 2 { (prev_lam_all - lam).max(0.0) } else { 0.0 };

        if n > 3 {
            // Cross-correlation g for adding f_n to G_{n-1}
            let d_prev = n - 2;
            let g: Vec<f64> = (0..d_prev).map(|k| gram[n-2][k]).collect();
            let g_norm: f64 = g.iter().map(|x| x*x).sum::<f64>().sqrt();

            // Quick v_min of G_{n-1}
            let sub_prev: Vec<Vec<f64>> = gram[..d_prev].iter()
                .map(|r| r[..d_prev].to_vec()).collect();
            let mut lu_p = sub_prev.clone();
            let piv_p = lu_decompose(&mut lu_p);
            let mut vp = vec![1.0 / (d_prev as f64).sqrt(); d_prev];
            for _ in 0..300 {
                let w = lu_solve(&lu_p, &piv_p, &vp);
                let norm: f64 = w.iter().map(|x| x*x).sum::<f64>().sqrt();
                if norm < 1e-15 { break; }
                vp = w.iter().map(|x| x / norm).collect();
            }
            let g_dot_v: f64 = g.iter().zip(vp.iter()).map(|(a, b)| a * b).sum();
            let cos_theta = g_dot_v.abs() / g_norm;

            // Schur
            let x_sol = lu_solve(&lu_p, &piv_p, &g);
            let gtx: f64 = g.iter().zip(x_sol.iter()).map(|(a,b)| a*b).sum();
            let gamma = gram[n-2][n-2];
            let schur = gamma - gtx;

            drop_data.push((n, drop, cos_theta, schur));

            // Print selected N values
            if n <= 20 || n % 100 == 0 || (n >= 990) {
                println!("  {:5} {:10.2e} {:10.6} {:10.6} {:10.6} {:12.6}",
                    n, drop, cos_theta, schur, g_norm, drop * n as f64);
            }
        }
        prev_lam_all = lam;
    }

    // Fit cos(θ) = |gᵀv|/||g|| scaling
    println!("\n  ═══ ALIGNMENT SCALING ═══\n");
    let fit_data: Vec<(f64, f64)> = drop_data.iter()
        .filter(|(n, _, cos, _)| *n >= 20 && *cos > 1e-10)
        .map(|(n, _, cos, _)| (*n as f64, *cos))
        .collect();

    if fit_data.len() >= 10 {
        let nf = fit_data.len() as f64;
        let slnx: f64 = fit_data.iter().map(|(n, _)| n.ln()).sum();
        let slny: f64 = fit_data.iter().map(|(_, c)| c.ln()).sum();
        let slnx2: f64 = fit_data.iter().map(|(n, _)| n.ln().powi(2)).sum();
        let slnxy: f64 = fit_data.iter().map(|(n, c)| n.ln() * c.ln()).sum();
        let slope = (nf * slnxy - slnx * slny) / (nf * slnx2 - slnx * slnx);
        let intercept = (slny - slope * slnx) / nf;
        println!("  cos(θ) = |gᵀv|/||g|| ∝ N^({:.4})", slope);
        println!("  (this is the alignment between g and v_min)");
        println!("  Fit: {:.6} · N^({:.4})", intercept.exp(), slope);

        if slope < -0.3 {
            println!("\n  ✅ Alignment DECREASES with N!");
            println!("     g becomes increasingly orthogonal to v_min.");
            println!("     This is the operator-theoretic explanation for convergence.");
        }
    }

    // Fit drop · N scaling (should be ∝ N^{-α} for some α>0)
    println!("\n  ═══ DROP SCALING ═══\n");
    let drop_fit: Vec<(f64, f64)> = drop_data.iter()
        .filter(|(n, d, _, _)| *n >= 20 && *d > 1e-15)
        .map(|(n, d, _, _)| (*n as f64, *d))
        .collect();

    if drop_fit.len() >= 10 {
        // Use log-log linear regression
        let nf = drop_fit.len() as f64;
        let slnx: f64 = drop_fit.iter().map(|(n, _)| n.ln()).sum();
        let slny: f64 = drop_fit.iter().map(|(_, d)| d.ln()).sum();
        let slnx2: f64 = drop_fit.iter().map(|(n, _)| n.ln().powi(2)).sum();
        let slnxy: f64 = drop_fit.iter().map(|(n, d)| n.ln() * d.ln()).sum();
        let slope = (nf * slnxy - slnx * slny) / (nf * slnx2 - slnx * slnx);
        let intercept = (slny - slope * slnx) / nf;
        println!("  δ_N ∝ N^({:.4})  (envelope of all N)", slope);
        println!("  Fit: {:.6} · N^({:.4})", intercept.exp(), slope);

        if slope < -1.0 {
            println!("\n  ✅ Drop exponent {:.4} < -1 ⟹ Σ δ_N CONVERGES!", slope);
            println!("     (Even without restricting to HC numbers)");
        }
    }

    // δ_N · N product analysis
    println!("\n  ═══ δ·N PRODUCT ═══\n");
    println!("  If δ_N = O(1/N^α), then δ·N = O(N^{{1-α}})");
    let mut windows: Vec<(usize, f64)> = Vec::new();
    for window_start in (0..drop_data.len()).step_by(100) {
        let window_end = (window_start + 100).min(drop_data.len());
        let sum_drop: f64 = drop_data[window_start..window_end].iter()
            .map(|(_, d, _, _)| d).sum();
        let n_mid = drop_data[(window_start + window_end) / 2].0;
        windows.push((n_mid, sum_drop));
    }

    println!("  {:>5} {:>12} {:>12}", "N_mid", "Σ_window δ", "ratio");
    for i in 0..windows.len() {
        let ratio = if i > 0 { windows[i].1 / windows[i-1].1 } else { 0.0 };
        println!("  {:5} {:12.6} {:12.4}",
            windows[i].0, windows[i].1, ratio);
    }

    println!("\n  Total time: {:.1}s", start.elapsed().as_secs_f64());
    println!("═══════════════════════════════════════════════════════════════");
}
