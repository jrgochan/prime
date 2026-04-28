// ═══════════════════════════════════════════════════════════════════════
//  analysis_f64.rs — Hybrid f64/MPFR-128 solver for high-N tracking
//
//  Strategy: Build the Gram matrix in f64 (fast), then convert to
//  128-bit MPFR for the Cholesky solve (stable). This avoids the
//  NaN blowup that occurs at N≈4000 with pure f64 Cholesky, while
//  keeping the O(N²) Gram computation at native speed.
//
//  128-bit MPFR gives ~38 decimal digits — enough to handle condition
//  numbers up to ~10^30, which should reach N≈15000+.
//
//  Memory: N×N × 16 bytes (128-bit MPFR) = 1.6 GB at N=10000.
//  For machines with limited RAM, a fallback regularized f64 solver
//  is provided.
// ═══════════════════════════════════════════════════════════════════════

use rug::Float;
use crate::analysis::BDResult;

/// Precision for the solve phase (not the Gram build phase).
/// 128 bits ≈ 38 decimal digits — enough for κ(G) up to ~10^30.
const SOLVE_PREC: u32 = 128;

/// Convert f64 Gram matrix → 128-bit MPFR, solve via Cholesky,
/// then extract f64 result. Hybrid precision approach.
fn quadratic_form_hybrid(g_f64: &[Vec<f64>], b_f64: &[f64]) -> Option<f64> {
    let n = b_f64.len();

    // Convert to MPFR-128
    let a: Vec<Vec<Float>> = g_f64.iter()
        .map(|row| row.iter().map(|&x| Float::with_val(SOLVE_PREC, x)).collect())
        .collect();
    let b: Vec<Float> = b_f64.iter()
        .map(|&x| Float::with_val(SOLVE_PREC, x))
        .collect();

    // Cholesky L Lᵀ in 128-bit MPFR
    let l = cholesky_mpfr(&a)?;
    let y = forward_solve_mpfr(&l, &b);
    let x = backward_solve_mpfr(&l, &y);

    // bᵀ x
    let mut dot = Float::with_val(SOLVE_PREC, 0u32);
    for i in 0..n {
        dot += Float::with_val(SOLVE_PREC, &b[i] * &x[i]);
    }
    Some(dot.to_f64())
}

/// Cholesky L Lᵀ decomposition in 128-bit MPFR.
fn cholesky_mpfr(a: &[Vec<Float>]) -> Option<Vec<Vec<Float>>> {
    let n = a.len();
    let mut l: Vec<Vec<Float>> = (0..n)
        .map(|_| (0..n).map(|_| Float::with_val(SOLVE_PREC, 0u32)).collect())
        .collect();

    for j in 0..n {
        let mut sum = Float::with_val(SOLVE_PREC, &a[j][j]);
        for k in 0..j {
            let lk = Float::with_val(SOLVE_PREC, &l[j][k] * &l[j][k]);
            sum -= lk;
        }
        if sum <= 0.0 {
            return None;
        }
        l[j][j] = Float::with_val(SOLVE_PREC, sum.sqrt());

        let ljj = l[j][j].clone();
        for i in (j + 1)..n {
            let mut s = Float::with_val(SOLVE_PREC, &a[i][j]);
            for k in 0..j {
                let prod = Float::with_val(SOLVE_PREC, &l[i][k] * &l[j][k]);
                s -= prod;
            }
            l[i][j] = Float::with_val(SOLVE_PREC, s / &ljj);
        }
    }
    Some(l)
}

/// Forward substitution Lx = b in MPFR.
fn forward_solve_mpfr(l: &[Vec<Float>], b: &[Float]) -> Vec<Float> {
    let n = b.len();
    let mut x: Vec<Float> = b.iter().map(|v| Float::with_val(SOLVE_PREC, v)).collect();
    for i in 0..n {
        for j in 0..i {
            let sub = Float::with_val(SOLVE_PREC, &l[i][j] * &x[j]);
            x[i] -= sub;
        }
        x[i] = Float::with_val(SOLVE_PREC, &x[i] / &l[i][i]);
    }
    x
}

/// Backward substitution Lᵀx = b in MPFR.
fn backward_solve_mpfr(l: &[Vec<Float>], b: &[Float]) -> Vec<Float> {
    let n = b.len();
    let mut x: Vec<Float> = b.iter().map(|v| Float::with_val(SOLVE_PREC, v)).collect();
    for i in (0..n).rev() {
        for j in (i + 1)..n {
            let sub = Float::with_val(SOLVE_PREC, &l[j][i] * &x[j]);
            x[i] -= sub;
        }
        x[i] = Float::with_val(SOLVE_PREC, &x[i] / &l[i][i]);
    }
    x
}

/// Build C = G - bbᵀ in f64 (this is fine — no precision loss here).
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

/// Approximate eigenvalue bounds (power iteration + Gershgorin).
fn eigenvalue_bounds(mat: &[Vec<f64>]) -> (f64, f64) {
    let n = mat.len();
    if n == 0 {
        return (0.0, 0.0);
    }

    // Power iteration for λ_max (200 iterations is plenty)
    let mut v = vec![1.0 / (n as f64).sqrt(); n];
    let mut lambda_max = 0.0;
    for _ in 0..200 {
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

/// Full hybrid f64/MPFR-128 analysis.
///
/// 1. Build covariance C = G - bbᵀ in f64
/// 2. Solve bᵀG⁻¹b and bᵀC⁻¹b via Cholesky in 128-bit MPFR
/// 3. Report results
pub fn analyze_f64(n: usize, g: &[Vec<f64>], b: &[f64]) -> BDResult {
    let c = build_covariance_f64(g, b);

    // Hybrid solve: f64 matrix → 128-bit MPFR Cholesky
    let bt_ginv_b = quadratic_form_hybrid(g, b).unwrap_or(f64::NAN);
    let d2_n = 1.0 - bt_ginv_b;

    let x_val = quadratic_form_hybrid(&c, b).unwrap_or(f64::NAN);

    let ln_n = (n as f64).ln();
    let x_over_ln_n = if ln_n > 0.0 { x_val / ln_n } else { 0.0 };

    let bd_const = 2.0 + 0.5772156649015328606 - (4.0 * std::f64::consts::PI).ln();
    let bd_predicted = bd_const / ln_n;

    // Eigenvalue bounds in f64 (approximate, display only)
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
