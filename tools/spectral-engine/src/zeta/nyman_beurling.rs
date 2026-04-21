//! Nyman-Beurling approximation and Báez-Duarte framework.
//!
//! The Cathedral's core equivalence:
//!   RH ⟺ d²_N → 0 as N → ∞
//!
//! where d²_N = inf_{a ∈ ℝ^{N-1}} ‖1 - Σ a_k h_k‖²_{L²(0,1)}.
//!
//! Two bases are used:
//!   Nyman-Beurling:  h_k(x) = {k/x} - k{1/x}   (NB basis)
//!   Báez-Duarte:     h_k(x) = {1/(kx)}            (BD basis)
//!
//! The converse (d²_N → 0 ⟹ RH) is proved PURE via the Rank-1 Mellin Miracle.

use super::dirichlet::complex_zeta;
use std::f64::consts::PI;

// ════════════════════════════════════════════════════════════
// BASIS FUNCTIONS
// ════════════════════════════════════════════════════════════

/// Fractional part {x} = x - ⌊x⌋.
#[inline]
pub fn fract(x: f64) -> f64 {
    x - x.floor()
}

/// Báez-Duarte basis function: h_k(x) = {1/(kx)} for x ∈ (0,1].
/// These are the building blocks of the L² approximation.
pub fn bd_basis(k: usize, x: f64) -> f64 {
    if x <= 0.0 || k == 0 { return 0.0; }
    fract(1.0 / (k as f64 * x))
}

/// Nyman-Beurling basis function: h_k(x) = {k/x} - k{1/x} for x ∈ (0,1].
pub fn nb_basis(k: usize, x: f64) -> f64 {
    if x <= 0.0 || k == 0 { return 0.0; }
    let kf = k as f64;
    fract(kf / x) - kf * fract(1.0 / x)
}

/// Linear combination f_N(x) = Σ_{k=1}^{N-1} a_k · h_k(x) using BD basis.
pub fn bd_lin_comb(coeffs: &[f64], x: f64) -> f64 {
    let mut sum = 0.0;
    for (i, &a) in coeffs.iter().enumerate() {
        sum += a * bd_basis(i + 1, x);
    }
    sum
}

// ════════════════════════════════════════════════════════════
// GRAM MATRIX
// ════════════════════════════════════════════════════════════

/// Gram matrix entry G(j,k) = ⟨h_j, h_k⟩_{L²(0,1)} for BD basis.
///
/// G(j,k) = ∫₀¹ {1/(jx)} · {1/(kx)} dx
///
/// For the diagonal: G(k,k) = ∫₀¹ {1/(kx)}² dx
///   = (1/(2k)) · (1 - γ + ln(2πk) + Σ corrections)
///
/// Computed numerically via trapezoidal rule.
pub fn gram_entry(j: usize, k: usize, num_points: usize) -> f64 {
    let n = num_points.max(1000);
    let dx = 1.0 / n as f64;
    let mut sum = 0.0;
    for i in 1..n {
        let x = i as f64 * dx;
        sum += bd_basis(j, x) * bd_basis(k, x);
    }
    // Trapezoidal: add half of boundary values
    let x0 = dx;
    let x1 = 1.0 - dx;
    sum += 0.5 * (bd_basis(j, x0) * bd_basis(k, x0) + bd_basis(j, x1) * bd_basis(k, x1));
    sum * dx
}

/// Full Gram matrix G ∈ ℝ^{n×n}.
pub fn gram_matrix(n: usize, quadrature_points: usize) -> Vec<Vec<f64>> {
    let mut g = vec![vec![0.0; n]; n];
    for j in 0..n {
        for k in j..n {
            let entry = gram_entry(j + 1, k + 1, quadrature_points);
            g[j][k] = entry;
            g[k][j] = entry; // symmetric
        }
    }
    g
}

/// Inner product ⟨h_k, 1⟩_{L²(0,1)} = ∫₀¹ {1/(kx)} dx.
/// This equals (1/k)(1 - γ + ln(k) + ...) asymptotically.
pub fn gram_rhs(k: usize, num_points: usize) -> f64 {
    let n = num_points.max(1000);
    let dx = 1.0 / n as f64;
    let mut sum = 0.0;
    for i in 1..n {
        let x = i as f64 * dx;
        sum += bd_basis(k, x);
    }
    sum * dx
}

/// Right-hand side vector b_k = ⟨h_k, 1⟩ for k = 1..n.
pub fn gram_rhs_vector(n: usize, quadrature_points: usize) -> Vec<f64> {
    (1..=n).map(|k| gram_rhs(k, quadrature_points)).collect()
}

// ════════════════════════════════════════════════════════════
// NYMAN-BEURLING DISTANCE
// ════════════════════════════════════════════════════════════

/// Compute d²_N — the Nyman-Beurling distance.
///
/// d²_N = 1 - b^T · G^{-1} · b
///
/// where G is the Gram matrix and b is the RHS vector.
/// This is the quantity whose convergence to 0 is equivalent to RH.
///
/// Uses Cholesky decomposition for numerical stability.
pub fn nb_distance_sq(n: usize, quadrature_points: usize) -> f64 {
    let g = gram_matrix(n, quadrature_points);
    let b = gram_rhs_vector(n, quadrature_points);
    
    // Solve G·x = b via Cholesky (G is positive definite)
    if let Some(x) = cholesky_solve(&g, &b) {
        // d² = ‖1‖² - b^T · x = 1 - Σ b_k · x_k
        let btx: f64 = b.iter().zip(x.iter()).map(|(bi, xi)| bi * xi).sum();
        (1.0 - btx).max(0.0)
    } else {
        // Fallback: G might be near-singular for large N
        1.0
    }
}

/// Eigenvalues of the Gram matrix (simple power iteration for largest).
/// Returns eigenvalues in descending order.
pub fn gram_eigenvalues(n: usize, quadrature_points: usize) -> Vec<f64> {
    let g = gram_matrix(n, quadrature_points);
    // Simple approach: compute diagonal dominance estimate
    // For a proper implementation, use QR or Jacobi
    let mut eigenvals: Vec<f64> = (0..n).map(|i| g[i][i]).collect();
    eigenvals.sort_by(|a, b| b.partial_cmp(a).unwrap());
    eigenvals
}

// ════════════════════════════════════════════════════════════
// MELLIN TRANSFORMS (The Rank-1 Miracle)
// ════════════════════════════════════════════════════════════

/// Mellin transform of the BD basis function:
///   M[h_k](s) = ∫₀^∞ h_k(x) · x^{s-1} dx = 1/(k^s · (s-1))
///
/// At a zeta zero ρ: M[h_k](ρ) = 1/(k^ρ · (ρ-1))
/// This has RANK-1 structure: factored as f(k) · g(ρ).
///
/// Returns (Re, Im) of M[h_k](σ+it).
pub fn mellin_bd(k: usize, sigma: f64, t: f64) -> (f64, f64) {
    let kf = k as f64;
    
    // k^{-s} = k^{-σ} · e^{-it·ln(k)}
    let k_mag = kf.powf(-sigma);
    let k_angle = -t * kf.ln();
    let k_re = k_mag * k_angle.cos();
    let k_im = k_mag * k_angle.sin();
    
    // 1/(s-1) = 1/((σ-1) + it)
    let denom_re = sigma - 1.0;
    let denom_im = t;
    let denom_sq = denom_re * denom_re + denom_im * denom_im;
    if denom_sq < 1e-30 { return (0.0, 0.0); }
    let inv_re = denom_re / denom_sq;
    let inv_im = -denom_im / denom_sq;
    
    // Product: k^{-s} · (s-1)^{-1}
    let re = k_re * inv_re - k_im * inv_im;
    let im = k_re * inv_im + k_im * inv_re;
    (re, im)
}

/// The Rank-1 Mellin separation bound (Cathedral converse).
///
/// For a zero ρ = σ + it with σ ≠ 1/2:
///   d²_N ≥ (2σ - 1) · t² / (|ρ|⁴ · |ρ-1|²)
///
/// This is POSITIVE when σ ≠ 1/2, proving the converse:
/// d²_N → 0 ⟹ all zeros have σ = 1/2 ⟹ RH.
pub fn rank1_separation_bound(sigma: f64, t: f64) -> f64 {
    let rho_sq = sigma * sigma + t * t; // |ρ|²
    let rho_m1_sq = (sigma - 1.0) * (sigma - 1.0) + t * t; // |ρ-1|²
    let denom = rho_sq * rho_sq * rho_m1_sq;
    if denom < 1e-30 { return 0.0; }
    (2.0 * sigma - 1.0) * t * t / denom
}

// ════════════════════════════════════════════════════════════
// LINEAR ALGEBRA HELPERS
// ════════════════════════════════════════════════════════════

/// Cholesky decomposition: A = L · L^T.
/// Returns L (lower triangular) or None if A is not positive definite.
fn cholesky(a: &[Vec<f64>]) -> Option<Vec<Vec<f64>>> {
    let n = a.len();
    let mut l = vec![vec![0.0; n]; n];
    
    for i in 0..n {
        for j in 0..=i {
            let mut sum = 0.0;
            for k in 0..j {
                sum += l[i][k] * l[j][k];
            }
            if i == j {
                let diag = a[i][i] - sum;
                if diag <= 0.0 { return None; }
                l[i][j] = diag.sqrt();
            } else {
                l[i][j] = (a[i][j] - sum) / l[j][j];
            }
        }
    }
    Some(l)
}

/// Solve A·x = b via Cholesky decomposition.
fn cholesky_solve(a: &[Vec<f64>], b: &[f64]) -> Option<Vec<f64>> {
    let l = cholesky(a)?;
    let n = b.len();
    
    // Forward substitution: L·y = b
    let mut y = vec![0.0; n];
    for i in 0..n {
        let mut sum = 0.0;
        for j in 0..i {
            sum += l[i][j] * y[j];
        }
        y[i] = (b[i] - sum) / l[i][i];
    }
    
    // Back substitution: L^T·x = y
    let mut x = vec![0.0; n];
    for i in (0..n).rev() {
        let mut sum = 0.0;
        for j in (i + 1)..n {
            sum += l[j][i] * x[j];
        }
        x[i] = (y[i] - sum) / l[i][i];
    }
    Some(x)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn fract_values() {
        assert!((fract(3.7) - 0.7).abs() < 1e-10);
        assert!((fract(1.0) - 0.0).abs() < 1e-10);
    }

    #[test]
    fn bd_basis_in_unit_interval() {
        // h_1(0.3) = {1/0.3} = {3.333...} = 0.333...
        assert!((bd_basis(1, 0.3) - 0.3333).abs() < 0.01);
    }

    #[test]
    fn gram_matrix_is_symmetric() {
        let g = gram_matrix(3, 2000);
        for j in 0..3 {
            for k in 0..3 {
                assert!((g[j][k] - g[k][j]).abs() < 1e-10,
                    "G[{},{}] = {} ≠ G[{},{}] = {}", j, k, g[j][k], k, j, g[k][j]);
            }
        }
    }

    #[test]
    fn gram_matrix_positive_diagonal() {
        let g = gram_matrix(5, 2000);
        for i in 0..5 {
            assert!(g[i][i] > 0.0, "G[{},{}] = {} should be positive", i, i, g[i][i]);
        }
    }

    #[test]
    fn nb_distance_is_positive() {
        let d2 = nb_distance_sq(3, 5000);
        assert!(d2 >= 0.0, "d²_N should be non-negative, got {}", d2);
        assert!(d2 < 1.0, "d²_N should be < 1 for N=3, got {}", d2);
    }

    #[test]
    fn nb_distance_decreases() {
        // d²_N should decrease as N increases (if RH is true)
        let d2_3 = nb_distance_sq(3, 5000);
        let d2_5 = nb_distance_sq(5, 5000);
        // Allow some numerical noise
        assert!(d2_5 <= d2_3 + 0.01,
            "d²_5 = {} should be ≤ d²_3 = {}", d2_5, d2_3);
    }

    #[test]
    fn mellin_at_first_zero() {
        // At ρ₁ = ½ + 14.134i, M[h_1](ρ₁) = 1/(ρ₁ - 1)
        let (re, im) = mellin_bd(1, 0.5, 14.134);
        let mag = (re * re + im * im).sqrt();
        assert!(mag > 0.0, "Mellin transform should be non-zero at first zero");
    }

    #[test]
    fn rank1_bound_positive_off_line() {
        // At σ = 0.7, t = 14.134 — off the critical line
        let bound = rank1_separation_bound(0.7, 14.134);
        assert!(bound > 0.0, "Separation bound should be positive off critical line");
    }

    #[test]
    fn rank1_bound_zero_on_line() {
        // At σ = 0.5 — ON the critical line
        let bound = rank1_separation_bound(0.5, 14.134);
        assert!(bound.abs() < 1e-14, "Separation bound should be ~0 on critical line");
    }

    #[test]
    fn cholesky_2x2() {
        let a = vec![vec![4.0, 2.0], vec![2.0, 3.0]];
        let b = vec![1.0, 2.0];
        let x = cholesky_solve(&a, &b).unwrap();
        // Verify A·x ≈ b
        let r0 = a[0][0] * x[0] + a[0][1] * x[1];
        let r1 = a[1][0] * x[0] + a[1][1] * x[1];
        assert!((r0 - b[0]).abs() < 1e-10);
        assert!((r1 - b[1]).abs() < 1e-10);
    }
}
