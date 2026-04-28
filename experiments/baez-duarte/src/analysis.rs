// ═══════════════════════════════════════════════════════════════════════
//  analysis.rs — Spectral analysis and distance computation
//
//  Given G (Gram) and b (mean vector), computes:
//    C = G - bbᵀ              (covariance matrix)
//    d²_N = 1 - bᵀ G⁻¹ b     (Nyman-Beurling distance)
//    X = bᵀ C⁻¹ b            (Sherman-Morrison test)
//
//  Uses Cholesky factorization for PD matrices (2× faster than LU,
//  numerically superior for symmetric positive definite systems).
// ═══════════════════════════════════════════════════════════════════════

use rug::Float;

use crate::gram::PREC;

/// Result of the distance computation for a single N.
pub struct BDResult {
    pub n: usize,
    pub d2_n: f64,
    pub x_val: f64,
    pub x_over_ln_n: f64,
    pub bd_predicted: f64,
    pub lambda_min_g: f64,
    pub lambda_max_g: f64,
    pub cond_g: f64,
    pub lambda_min_c: f64,
    pub cond_c: f64,
    pub g_11: f64,
    pub b_norm_sq: f64,
}

/// Build C = G - bbᵀ
pub fn build_covariance(g: &[Vec<Float>], b: &[Float]) -> Vec<Vec<Float>> {
    let n = b.len();
    let mut c: Vec<Vec<Float>> = g
        .iter()
        .map(|row| row.iter().map(|x| Float::with_val(PREC, x)).collect())
        .collect();

    for i in 0..n {
        for j in 0..n {
            let bb = Float::with_val(PREC, &b[i] * &b[j]);
            c[i][j] -= bb;
        }
    }
    c
}

/// Cholesky decomposition: A = L Lᵀ for symmetric positive definite A.
/// Returns L (lower triangular) or None if A is not PD.
fn cholesky(a: &[Vec<Float>]) -> Option<Vec<Vec<Float>>> {
    let n = a.len();
    let mut l: Vec<Vec<Float>> = (0..n)
        .map(|_| (0..n).map(|_| Float::with_val(PREC, 0u32)).collect())
        .collect();

    for j in 0..n {
        // L[j][j] = sqrt(A[j][j] - Σ_{k<j} L[j][k]²)
        let mut sum = Float::with_val(PREC, &a[j][j]);
        for k in 0..j {
            let lk = Float::with_val(PREC, &l[j][k] * &l[j][k]);
            sum -= lk;
        }
        if sum <= 0.0 {
            return None; // Not positive definite
        }
        l[j][j] = Float::with_val(PREC, sum.sqrt());

        // L[i][j] = (A[i][j] - Σ_{k<j} L[i][k]·L[j][k]) / L[j][j]
        let ljj = l[j][j].clone();
        for i in (j + 1)..n {
            let mut s = Float::with_val(PREC, &a[i][j]);
            for k in 0..j {
                let prod = Float::with_val(PREC, &l[i][k] * &l[j][k]);
                s -= prod;
            }
            l[i][j] = Float::with_val(PREC, s / &ljj);
        }
    }
    Some(l)
}

/// Solve Lx = b by forward substitution.
fn forward_solve(l: &[Vec<Float>], b: &[Float]) -> Vec<Float> {
    let n = b.len();
    let mut x: Vec<Float> = b.iter().map(|v| Float::with_val(PREC, v)).collect();
    for i in 0..n {
        for j in 0..i {
            let sub = Float::with_val(PREC, &l[i][j] * &x[j]);
            x[i] -= sub;
        }
        x[i] = Float::with_val(PREC, &x[i] / &l[i][i]);
    }
    x
}

/// Solve Lᵀx = b by backward substitution.
fn backward_solve(l: &[Vec<Float>], b: &[Float]) -> Vec<Float> {
    let n = b.len();
    let mut x: Vec<Float> = b.iter().map(|v| Float::with_val(PREC, v)).collect();
    for i in (0..n).rev() {
        for j in (i + 1)..n {
            let sub = Float::with_val(PREC, &l[j][i] * &x[j]);
            x[i] -= sub;
        }
        x[i] = Float::with_val(PREC, &x[i] / &l[i][i]);
    }
    x
}

/// Solve A x = b via Cholesky: A = LLᵀ → Ly = b, Lᵀx = y.
/// Returns x or None if Cholesky fails.
fn cholesky_solve(a: &[Vec<Float>], b: &[Float]) -> Option<Vec<Float>> {
    let l = cholesky(a)?;
    let y = forward_solve(&l, b);
    Some(backward_solve(&l, &y))
}

/// Compute bᵀ A⁻¹ b via Cholesky solve (without forming A⁻¹).
fn quadratic_form(a: &[Vec<Float>], b: &[Float]) -> Option<f64> {
    let x = cholesky_solve(a, b)?;
    let mut dot = Float::with_val(PREC, 0u32);
    for i in 0..b.len() {
        dot += Float::with_val(PREC, &b[i] * &x[i]);
    }
    Some(dot.to_f64())
}

/// Eigenvalues via power/inverse iteration on f64 projection.
/// (For display only — the actual computation uses Cholesky.)
fn eigenvalue_bounds_f64(mat: &[Vec<Float>]) -> (f64, f64) {
    let n = mat.len();
    if n == 0 {
        return (0.0, 0.0);
    }

    // Convert to f64 for eigenvalue estimation
    let m: Vec<Vec<f64>> = mat
        .iter()
        .map(|row| row.iter().map(|x| x.to_f64()).collect())
        .collect();

    // Power iteration for λ_max
    let mut v = vec![1.0 / (n as f64).sqrt(); n];
    let mut lambda_max = 0.0;
    for _ in 0..200 {
        let mut w = vec![0.0; n];
        for i in 0..n {
            for j in 0..n {
                w[i] += m[i][j] * v[j];
            }
        }
        let norm: f64 = w.iter().map(|x| x * x).sum::<f64>().sqrt();
        if norm < 1e-30 {
            break;
        }
        lambda_max = w.iter().zip(v.iter()).map(|(a, b)| a * b).sum::<f64>();
        v = w.iter().map(|x| x / norm).collect();
    }

    // Inverse iteration for λ_min (shift-and-invert with LU)
    // Simple approach: use Gershgorin for lower bound estimate
    let mut lambda_min = f64::INFINITY;
    for i in 0..n {
        let diag = m[i][i];
        let off: f64 = (0..n).filter(|&j| j != i).map(|j| m[i][j].abs()).sum();
        let lower = diag - off;
        if lower < lambda_min {
            lambda_min = lower;
        }
    }
    // Refine: try inverse iteration
    let mut v = vec![1.0 / (n as f64).sqrt(); n];
    // Shift by lambda_min estimate
    let shift = lambda_min.max(0.0) * 0.5;
    let mut ms = m.clone();
    for i in 0..n {
        ms[i][i] -= shift;
    }
    // Simple LU for shifted system
    // (we only need approximate eigenvalue for display)
    for _ in 0..50 {
        // Solve (M - σI)w = v approximately via Jacobi
        let mut w = v.clone();
        for _ in 0..20 {
            let mut w_new = v.clone();
            for i in 0..n {
                let mut s = v[i];
                for j in 0..n {
                    if j != i {
                        s -= ms[i][j] * w[j];
                    }
                }
                w_new[i] = if ms[i][i].abs() > 1e-30 {
                    s / ms[i][i]
                } else {
                    s
                };
            }
            w = w_new;
        }
        let norm: f64 = w.iter().map(|x| x * x).sum::<f64>().sqrt();
        if norm < 1e-30 {
            break;
        }
        let rayleigh: f64 = w
            .iter()
            .zip(v.iter())
            .map(|(a, b)| a * b)
            .sum::<f64>()
            / norm;
        if rayleigh.abs() > 1e-30 {
            lambda_min = shift + 1.0 / rayleigh;
        }
        v = w.iter().map(|x| x / norm).collect();
    }

    // Ensure reasonable bounds
    lambda_min = lambda_min.min(lambda_max);

    (lambda_min, lambda_max)
}

/// Run the full analysis for dimension N.
pub fn analyze(
    n: usize,
    g: &[Vec<Float>],
    b: &[Float],
) -> BDResult {
    let euler_gamma = 0.5772156649015328606_f64;

    // bᵀ b
    let mut b_norm_sq = Float::with_val(PREC, 0u32);
    for bi in b {
        b_norm_sq += Float::with_val(PREC, bi * bi);
    }

    // C = G - bbᵀ
    let c = build_covariance(g, b);

    // bᵀ G⁻¹ b via Cholesky
    let bt_ginv_b = quadratic_form(g, b).unwrap_or(f64::NAN);
    let d2_n = 1.0 - bt_ginv_b;

    // bᵀ C⁻¹ b via Cholesky (Sherman-Morrison check)
    let x_val = quadratic_form(&c, b).unwrap_or(f64::NAN);

    let ln_n = (n as f64).ln();
    let x_over_ln_n = if ln_n > 0.0 { x_val / ln_n } else { 0.0 };

    // Báez-Duarte prediction: d²_N ≈ 1/(2 + γ - ln(4π)) / ln(N)
    let bd_const = 2.0 + euler_gamma - (4.0 * std::f64::consts::PI).ln();
    let bd_predicted = bd_const / ln_n;

    // Eigenvalue bounds (for display)
    let (lmin_g, lmax_g) = eigenvalue_bounds_f64(g);
    let cond_g = if lmin_g > 0.0 {
        lmax_g / lmin_g
    } else {
        f64::INFINITY
    };

    let (lmin_c, lmax_c) = eigenvalue_bounds_f64(&c);
    let cond_c = if lmin_c > 0.0 {
        lmax_c / lmin_c
    } else {
        f64::INFINITY
    };

    let g_11 = g[0][0].to_f64();

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
        g_11,
        b_norm_sq: b_norm_sq.to_f64(),
    }
}
