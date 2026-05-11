// ═══════════════════════════════════════════════════════════════════════
//  analysis.rs — Spectral analysis and distance computation
//
//  Lean bridge:
//    proofs/Cathedral/Assembly/MainChain.lean
//      theorem nyman_beurling_equivalence_mellin : RH ↔ d²_N → 0
//    proofs/Cathedral/LinearAlgebra/ShermanMorrison.lean
//      d²_N = 1/(1 + bᵀC⁻¹b)  where  C = G - bbᵀ
//
//  Given G (Gram, symmetric PD) and b (mean vector), computes:
//    d²_N = 1 - bᵀ G⁻¹ b     (Nyman-Beurling distance via Cholesky)
//    X = bᵀ C⁻¹ b            (Sherman-Morrison cross-check)
//    C = G - bbᵀ              (covariance matrix)
//
//  The Sherman-Morrison identity guarantees d²_N = 1/(1+X).
//  Agreement to ~17 digits validates the 512-bit computation.
//
//  Cholesky LLᵀ factorization is used instead of full matrix inversion:
//    - 2× fewer FLOPs than LU decomposition
//    - Numerically stable for symmetric positive definite systems
//    - Never forms G⁻¹ explicitly (solves G⁻¹b via back-substitution)
// ═══════════════════════════════════════════════════════════════════════

use rug::Float;

use crate::gram::PREC;

/// Result of the distance computation for a single N.
/// Each field maps to a quantity in the Lean formalization.
#[allow(dead_code)]
pub struct BDResult {
    pub n: usize,
    /// d²_N = 1 - bᵀG⁻¹b  (MainChain.lean: distance_sq)
    pub d2_n: f64,
    /// X = bᵀC⁻¹b  (ShermanMorrison.lean: quadratic_form)
    pub x_val: f64,
    /// X / ln(N)  (BaezDuarte.lean: should converge to 1/C ≈ 21.64)
    pub x_over_ln_n: f64,
    /// C/ln(N)  where C = 1/(2+γ-ln4π) ≈ 0.0462
    pub bd_predicted: f64,
    /// Approximate smallest eigenvalue of G (display only)
    pub lambda_min_g: f64,
    /// Approximate largest eigenvalue of G (display only)
    pub lambda_max_g: f64,
    /// Condition number κ(G) ≈ λ_max/λ_min
    pub cond_g: f64,
    /// Approximate smallest eigenvalue of C (display only)
    pub lambda_min_c: f64,
    /// Condition number κ(C)
    pub cond_c: f64,
}

/// Build C = G - bbᵀ  (covariance matrix).
///
/// Lean: LinearAlgebra/ShermanMorrison.lean
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
///
/// Returns L (lower triangular) or None if A is not PD.
/// Lean: the PD property is proved in Vasyunin/Matrix/GramPSD.lean.
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
            return None;
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
fn cholesky_solve(a: &[Vec<Float>], b: &[Float]) -> Option<Vec<Float>> {
    let l = cholesky(a)?;
    let y = forward_solve(&l, b);
    Some(backward_solve(&l, &y))
}

/// Compute bᵀ A⁻¹ b via Cholesky solve (never forms A⁻¹ explicitly).
///
/// This is the key quantity: for G, it gives 1 - d²_N.
/// For C = G - bbᵀ, it gives X = bᵀC⁻¹b (Sherman-Morrison test).
fn quadratic_form(a: &[Vec<Float>], b: &[Float]) -> Option<f64> {
    let x = cholesky_solve(a, b)?;
    let mut dot = Float::with_val(PREC, 0u32);
    for i in 0..b.len() {
        dot += Float::with_val(PREC, &b[i] * &x[i]);
    }
    Some(dot.to_f64())
}

/// Approximate eigenvalue bounds via Gershgorin circles + power iteration.
/// These are for display only — the Cholesky is the numerically reliable path.
fn eigenvalue_bounds_f64(mat: &[Vec<Float>]) -> (f64, f64) {
    let n = mat.len();
    if n == 0 {
        return (0.0, 0.0);
    }

    let m: Vec<Vec<f64>> = mat
        .iter()
        .map(|row| row.iter().map(|x| x.to_f64()).collect())
        .collect();

    // Power iteration for λ_max
    let mut v = vec![1.0 / (n as f64).sqrt(); n];
    let mut lambda_max = 0.0;
    for _ in 0..300 {
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

    // Gershgorin lower bound
    let mut lambda_min = f64::INFINITY;
    for i in 0..n {
        let diag = m[i][i];
        let off: f64 = (0..n).filter(|&j| j != i).map(|j| m[i][j].abs()).sum();
        let lower = diag - off;
        if lower < lambda_min {
            lambda_min = lower;
        }
    }
    lambda_min = lambda_min.min(lambda_max);

    (lambda_min, lambda_max)
}

/// Run the full analysis for dimension N.
///
/// Returns a BDResult containing all quantities needed for the
/// certificate: d²_N, X, X/ln(N), eigenvalue bounds.
pub fn analyze(n: usize, g: &[Vec<Float>], b: &[Float]) -> BDResult {
    let euler_gamma = 0.5772156649015328606_f64;

    // C = G - bbᵀ
    let c = build_covariance(g, b);

    // bᵀ G⁻¹ b via Cholesky (never forms G⁻¹)
    let bt_ginv_b = quadratic_form(g, b).unwrap_or(f64::NAN);
    let d2_n = 1.0 - bt_ginv_b;

    // bᵀ C⁻¹ b via Cholesky (Sherman-Morrison cross-check)
    let x_val = quadratic_form(&c, b).unwrap_or(f64::NAN);

    let ln_n = (n as f64).ln();
    let x_over_ln_n = if ln_n > 0.0 { x_val / ln_n } else { 0.0 };

    // Báez-Duarte prediction: d²_N ≈ C/ln(N)
    // where C = 1/(2 + γ - ln(4π)) ≈ 0.0462
    // Lean: IntegralBasis/BaezDuarte.lean
    let bd_const = 2.0 + euler_gamma - (4.0 * std::f64::consts::PI).ln();
    let bd_predicted = bd_const / ln_n;

    // Eigenvalue bounds (approximate, for display/certificate only)
    let (lmin_g, lmax_g) = eigenvalue_bounds_f64(g);
    let cond_g = if lmin_g > 0.0 {
        lmax_g / lmin_g
    } else {
        f64::INFINITY
    };

    let (lmin_c, _) = eigenvalue_bounds_f64(&c);
    let cond_c = if lmin_c > 0.0 {
        lmax_g / lmin_c // approximate
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
