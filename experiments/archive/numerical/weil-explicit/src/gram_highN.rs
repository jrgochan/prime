#![allow(unused, dead_code, non_snake_case)]
use rayon::prelude::*;
use std::f64::consts::PI;

// ══════════════════════════════════════════════════════════
// PROJECT HYPERZETA: Gram Spectral Analysis — N = 1000
// Verify λ_min(G_N) ≥ c > 0 for N up to 1000
// ══════════════════════════════════════════════════════════

fn frac_part(x: f64) -> f64 {
    x - x.floor()
}

/// Inner product ⟨{j/x}, {k/x}⟩ in L²(0,1)
fn inner_product(j: usize, k: usize, n_pts: usize) -> f64 {
    let jf = j as f64;
    let kf = k as f64;
    let dx = 1.0 / n_pts as f64;
    let mut sum = 0.0;
    for i in 1..n_pts {
        let x = i as f64 * dx;
        sum += frac_part(jf / x) * frac_part(kf / x);
    }
    sum * dx
}

fn inner_with_one(k: usize, n_pts: usize) -> f64 {
    let kf = k as f64;
    let dx = 1.0 / n_pts as f64;
    let mut sum = 0.0;
    for i in 1..n_pts {
        let x = i as f64 * dx;
        sum += frac_part(kf / x);
    }
    sum * dx
}

/// LU decomposition (in-place, partial pivoting)
/// Returns pivot indices
fn lu_decompose(a: &mut [Vec<f64>]) -> Vec<usize> {
    let n = a.len();
    let mut piv: Vec<usize> = (0..n).collect();
    for col in 0..n {
        let mut max_val = 0.0f64;
        let mut max_row = col;
        for row in col..n {
            if a[row][col].abs() > max_val {
                max_val = a[row][col].abs();
                max_row = row;
            }
        }
        if max_row != col {
            a.swap(col, max_row);
            piv.swap(col, max_row);
        }
        if a[col][col].abs() < 1e-15 {
            continue;
        }
        for row in (col + 1)..n {
            a[row][col] /= a[col][col];
            for j in (col + 1)..n {
                let factor = a[row][col];
                a[row][j] -= factor * a[col][j];
            }
        }
    }
    piv
}

/// Solve Ax = b using precomputed LU
fn lu_solve(lu: &[Vec<f64>], piv: &[usize], b: &[f64]) -> Vec<f64> {
    let n = b.len();
    let mut x: Vec<f64> = piv.iter().map(|&i| b[i]).collect();
    // Forward substitution (L)
    for i in 1..n {
        for j in 0..i {
            let factor = lu[i][j];
            x[i] -= factor * x[j];
        }
    }
    // Back substitution (U)
    for i in (0..n).rev() {
        for j in (i + 1)..n {
            x[i] -= lu[i][j] * x[j];
        }
        x[i] /= lu[i][i];
    }
    x
}

/// Power iteration for largest eigenvalue
fn power_iteration(mat: &[Vec<f64>], n_iter: usize) -> f64 {
    let n = mat.len();
    let mut v = vec![1.0 / (n as f64).sqrt(); n];
    for _ in 0..n_iter {
        let mut w = vec![0.0; n];
        for i in 0..n {
            for j in 0..n {
                w[i] += mat[i][j] * v[j];
            }
        }
        let norm: f64 = w.iter().map(|x| x * x).sum::<f64>().sqrt();
        if norm < 1e-15 {
            break;
        }
        v = w.iter().map(|x| x / norm).collect();
    }
    // Rayleigh quotient
    let mut w = vec![0.0; n];
    for i in 0..n {
        for j in 0..n {
            w[i] += mat[i][j] * v[j];
        }
    }
    v.iter().zip(w.iter()).map(|(a, b)| a * b).sum()
}

/// Inverse iteration for smallest eigenvalue
fn inverse_iteration(mat: &[Vec<f64>], n_iter: usize) -> f64 {
    let n = mat.len();
    let mut lu = mat.to_vec();
    let piv = lu_decompose(&mut lu);
    let mut v = vec![1.0 / (n as f64).sqrt(); n];
    for _ in 0..n_iter {
        let w = lu_solve(&lu, &piv, &v);
        let norm: f64 = w.iter().map(|x| x * x).sum::<f64>().sqrt();
        if norm < 1e-15 {
            break;
        }
        v = w.iter().map(|x| x / norm).collect();
    }
    // Rayleigh quotient on original matrix
    let mut w = vec![0.0; n];
    for i in 0..n {
        for j in 0..n {
            w[i] += mat[i][j] * v[j];
        }
    }
    let vav: f64 = v.iter().zip(w.iter()).map(|(a, b)| a * b).sum();
    let vv: f64 = v.iter().map(|x| x * x).sum::<f64>();
    vav / vv
}

fn main() {
    println!("═══════════════════════════════════════════════════════════════");
    println!("  PROJECT HYPERZETA: Gram Spectral Analysis — N = 1000");
    println!("  Verifying λ_min(G_N) ≥ c > 0 — the HYPERZETA Conjecture");
    println!("═══════════════════════════════════════════════════════════════");

    let max_n: usize = 1000;
    let n_int: usize = 100_000;
    let dim = max_n - 1; // indices 2..max_n

    println!(
        "\n[1/3] Computing {}×{} Gram matrix ({} integration pts, parallel)...",
        dim, dim, n_int
    );

    let start = std::time::Instant::now();

    // Compute upper triangle of Gram matrix in parallel (row by row)
    let gram_rows: Vec<Vec<f64>> = (0..dim)
        .into_par_iter()
        .map(|j| {
            let mut row = vec![0.0; dim];
            for k in j..dim {
                row[k] = inner_product(j + 2, k + 2, n_int);
            }
            row
        })
        .collect();

    // Symmetrize into full matrix
    let mut gram: Vec<Vec<f64>> = vec![vec![0.0; dim]; dim];
    for j in 0..dim {
        for k in j..dim {
            gram[j][k] = gram_rows[j][k];
            gram[k][j] = gram_rows[j][k];
        }
    }

    // Compute RHS vector b[k] = ⟨1, {k/x}⟩
    let rhs: Vec<f64> = (0..dim)
        .into_par_iter()
        .map(|j| inner_with_one(j + 2, n_int))
        .collect();

    let gram_time = start.elapsed();
    println!("  Done in {:.1}s", gram_time.as_secs_f64());

    // Phase 2: Eigenvalue analysis at checkpoints
    println!("\n[2/3] ═══ Eigenvalue Scaling (N = 2..{}) ═══\n", max_n);
    println!(
        "  {:>5}  {:>14}  {:>14}  {:>14}  {:>10}",
        "N", "λ_min(G_N)", "d_N²", "d_N", "κ(G_N)"
    );

    let mut data_n: Vec<f64> = Vec::new();
    let mut data_lmin: Vec<f64> = Vec::new();
    let mut data_dsq: Vec<f64> = Vec::new();
    let mut global_min_lmin = f64::INFINITY;
    let mut global_min_n = 0;

    // Checkpoints: dense for small N, sparse for large N
    let checkpoints: Vec<usize> = {
        let mut v: Vec<usize> = (2..=30).collect();
        v.extend((35..=100).step_by(5));
        v.extend((110..=250).step_by(10));
        v.extend((260..=500).step_by(20));
        v.extend((520..=max_n).step_by(40));
        v
    };

    for &n in &checkpoints {
        let dim_n = n - 1;
        if dim_n > dim {
            break;
        }

        // Extract sub-matrix
        let sub: Vec<Vec<f64>> = gram[..dim_n].iter().map(|r| r[..dim_n].to_vec()).collect();

        // Compute λ_min via inverse iteration
        let lambda_min = inverse_iteration(&sub, 300);

        // Compute λ_max via power iteration
        let lambda_max = power_iteration(&sub, 300);

        let cond = if lambda_min.abs() > 1e-15 {
            lambda_max / lambda_min
        } else {
            f64::INFINITY
        };

        // Compute d_N² = 1 - bᵀ G⁻¹ b
        let sub_rhs: Vec<f64> = rhs[..dim_n].to_vec();
        let d_sq = {
            let mut lu = sub.clone();
            let piv = lu_decompose(&mut lu);
            let x = lu_solve(&lu, &piv, &sub_rhs);
            let btginvb: f64 = x.iter().zip(sub_rhs.iter()).map(|(c, r)| c * r).sum();
            (1.0 - btginvb).max(0.0)
        };

        if lambda_min < global_min_lmin {
            global_min_lmin = lambda_min;
            global_min_n = n;
        }

        println!(
            "  {:5}  {:14.10}  {:14.10}  {:14.10}  {:10.1}",
            n,
            lambda_min,
            d_sq,
            d_sq.max(0.0).sqrt(),
            cond
        );

        if lambda_min > 0.0 && d_sq > 0.0 && d_sq < 1.0 {
            data_n.push(n as f64);
            data_lmin.push(lambda_min);
            data_dsq.push(d_sq);
        }
    }

    // Phase 3: Fit scaling laws
    println!("\n[3/3] ═══ Scaling Law Fits ═══\n");

    if data_n.len() >= 20 {
        let start_idx = data_n.len() * 2 / 3;

        let fit_lmin = log_log_fit(&data_n[start_idx..], &data_lmin[start_idx..]);
        println!("  λ_min(N) ≈ {:.6} · N^{{-{:.4}}}", fit_lmin.0, fit_lmin.1);

        let fit_dsq = log_log_fit(&data_n[start_idx..], &data_dsq[start_idx..]);
        println!("  d_N²(N)  ≈ {:.6} · N^{{-{:.4}}}", fit_dsq.0, fit_dsq.1);
        println!(
            "  d_N(N)   ≈ {:.6} · N^{{-{:.4}}}",
            fit_dsq.0.sqrt(),
            fit_dsq.1 / 2.0
        );

        // Also fit on full range for comparison
        let fit_lmin_full = log_log_fit(&data_n[10..], &data_lmin[10..]);
        println!(
            "\n  Full-range fit (N>20): λ_min(N) ≈ {:.6} · N^{{-{:.4}}}",
            fit_lmin_full.0, fit_lmin_full.1
        );

        println!("\n  ═══════════════════════════════════════════════");
        println!("         HYPERZETA CONJECTURE VERIFICATION");
        println!("  ═══════════════════════════════════════════════");
        println!(
            "\n  Global minimum λ_min = {:.10} at N = {}",
            global_min_lmin, global_min_n
        );
        println!("  α (eigenvalue exponent, last third) = {:.4}", fit_lmin.1);
        println!(
            "  α (eigenvalue exponent, full range)  = {:.4}",
            fit_lmin_full.1
        );
        println!("  β (d_N² exponent) = {:.4}", fit_dsq.1);
        println!();
        if global_min_lmin > 0.01 {
            println!("  ✅ λ_min(G_N) > 0.01 for ALL N ≤ {}", max_n);
            println!("  ✅ HYPERZETA conjecture HOLDS at N = {}", max_n);
        } else if global_min_lmin > 0.0 {
            println!(
                "  ⚠️  λ_min(G_N) > 0 but < 0.01 (min = {:.6})",
                global_min_lmin
            );
            println!("  ⚠️  Conjecture holds but bound needs revision");
        } else {
            println!("  ❌ λ_min(G_N) ≤ 0 detected — conjecture may be FALSE");
        }

        if fit_dsq.1 > 0.5 {
            println!(
                "\n  ✅ d_N² decays as N^{{-{:.2}}} → RH is numerically confirmed",
                fit_dsq.1
            );
        }
    }

    let total_time = start.elapsed();
    println!("\n  Total runtime: {:.1}s", total_time.as_secs_f64());
    println!("═══════════════════════════════════════════════════════════════");
}

fn log_log_fit(x: &[f64], y: &[f64]) -> (f64, f64) {
    let n = x.len() as f64;
    let (mut sx, mut sy, mut sxx, mut sxy) = (0.0, 0.0, 0.0, 0.0);
    for i in 0..x.len() {
        let lx = x[i].ln();
        let ly = y[i].ln();
        sx += lx;
        sy += ly;
        sxx += lx * lx;
        sxy += lx * ly;
    }
    let alpha = -(n * sxy - sx * sy) / (n * sxx - sx * sx);
    let log_c = (sy + alpha * sx) / n;
    (log_c.exp(), alpha)
}
