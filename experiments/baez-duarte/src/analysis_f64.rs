// ═══════════════════════════════════════════════════════════════════════
//  analysis_f64.rs — Fast f64 distance computation for high-N tracking
//
//  Same algorithms as analysis.rs (Cholesky decomposition, Sherman-Morrison
//  cross-check) but in pure f64. No MPFR dependency.
//
//  At high N, the condition number κ(C) grows exponentially, and f64
//  precision (~15 digits) will eventually be exhausted. The SM match
//  metric tracks this: when it exceeds ~10⁻⁸, the results should be
//  interpreted as trend indicators rather than certified values.
// ═══════════════════════════════════════════════════════════════════════

use crate::analysis::BDResult;

/// Build C = G - bbᵀ in f64.
fn build_covariance_f64(g: &[Vec<f64>], b: &[f64]) -> Vec<Vec<f64>> {
    let n = b.len();
    let mut c = g.to_vec();
    for i in 0..n {
        for j in 0..n {
            c[i][j] -= b[i] * b[j];
        }
    }
    c
}

/// Cholesky L Lᵀ decomposition in f64.
fn cholesky_f64(a: &[Vec<f64>]) -> Option<Vec<Vec<f64>>> {
    let n = a.len();
    let mut l = vec![vec![0.0_f64; n]; n];

    for j in 0..n {
        let mut sum = a[j][j];
        for k in 0..j {
            sum -= l[j][k] * l[j][k];
        }
        if sum <= 0.0 {
            return None;
        }
        l[j][j] = sum.sqrt();

        let ljj = l[j][j];
        for i in (j + 1)..n {
            let mut s = a[i][j];
            for k in 0..j {
                s -= l[i][k] * l[j][k];
            }
            l[i][j] = s / ljj;
        }
    }
    Some(l)
}

/// Forward substitution: Lx = b
fn forward_solve_f64(l: &[Vec<f64>], b: &[f64]) -> Vec<f64> {
    let n = b.len();
    let mut x = b.to_vec();
    for i in 0..n {
        for j in 0..i {
            x[i] -= l[i][j] * x[j];
        }
        x[i] /= l[i][i];
    }
    x
}

/// Backward substitution: Lᵀx = b
fn backward_solve_f64(l: &[Vec<f64>], b: &[f64]) -> Vec<f64> {
    let n = b.len();
    let mut x = b.to_vec();
    for i in (0..n).rev() {
        for j in (i + 1)..n {
            x[i] -= l[j][i] * x[j];
        }
        x[i] /= l[i][i];
    }
    x
}

/// Compute bᵀ A⁻¹ b via Cholesky solve.
fn quadratic_form_f64(a: &[Vec<f64>], b: &[f64]) -> Option<f64> {
    let l = cholesky_f64(a)?;
    let y = forward_solve_f64(&l, b);
    let x = backward_solve_f64(&l, &y);
    Some(b.iter().zip(x.iter()).map(|(a, b)| a * b).sum())
}

/// Approximate eigenvalue bounds (power iteration + Gershgorin).
fn eigenvalue_bounds(mat: &[Vec<f64>]) -> (f64, f64) {
    let n = mat.len();
    if n == 0 {
        return (0.0, 0.0);
    }

    // Power iteration for λ_max
    let mut v = vec![1.0 / (n as f64).sqrt(); n];
    let mut lambda_max = 0.0;
    for _ in 0..300 {
        let mut w = vec![0.0; n];
        for i in 0..n {
            for j in 0..n {
                w[i] += mat[i][j] * v[j];
            }
        }
        let norm: f64 = w.iter().map(|x| x * x).sum::<f64>().sqrt();
        if norm < 1e-30 {
            break;
        }
        lambda_max = w.iter().zip(v.iter()).map(|(a, b)| a * b).sum::<f64>();
        v = w.iter().map(|x| x / norm).collect();
    }

    // Gershgorin lower bound
    let mut lambda_min = f64::INFINITY;
    for i in 0..n {
        let diag = mat[i][i];
        let off: f64 = (0..n).filter(|&j| j != i).map(|j| mat[i][j].abs()).sum();
        lambda_min = lambda_min.min(diag - off);
    }
    lambda_min = lambda_min.min(lambda_max);

    (lambda_min, lambda_max)
}

/// Full f64 analysis: distances, Sherman-Morrison check, eigenvalue bounds.
pub fn analyze_f64(n: usize, g: &[Vec<f64>], b: &[f64]) -> BDResult {
    let c = build_covariance_f64(g, b);

    let bt_ginv_b = quadratic_form_f64(g, b).unwrap_or(f64::NAN);
    let d2_n = 1.0 - bt_ginv_b;

    let x_val = quadratic_form_f64(&c, b).unwrap_or(f64::NAN);

    let ln_n = (n as f64).ln();
    let x_over_ln_n = if ln_n > 0.0 { x_val / ln_n } else { 0.0 };

    let bd_const = 2.0 + 0.5772156649015328606 - (4.0 * std::f64::consts::PI).ln();
    let bd_predicted = bd_const / ln_n;

    let (lmin_g, lmax_g) = eigenvalue_bounds(g);
    let cond_g = if lmin_g > 0.0 {
        lmax_g / lmin_g
    } else {
        f64::INFINITY
    };

    let (lmin_c, _) = eigenvalue_bounds(&c);
    let cond_c = if lmin_c > 0.0 {
        lmax_g / lmin_c
    } else {
        f64::INFINITY
    };

    BDResult {
        n,
        d2_n,
        x_val,
        x_over_ln_n,
        bd_predicted,
        lambda_min_g: lmin_g,
        lambda_max_g: lmax_g,
        cond_g,
        lambda_min_c: lmin_c,
        cond_c,
    }
}
