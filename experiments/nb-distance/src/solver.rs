//! Linear algebra solver for the unconstrained Nyman-Beurling distance.
//!
//! Given the Gram matrix G_N and target vector b, computes:
//!   d²_N = 1 - b^T G_N^{-1} b
//!
//! This is the EXACT minimum L² distance from the constant function 1
//! to the span of {ρ_2, ..., ρ_N} — no envelope restriction, no sieve.
//!
//! RH ⟺ d²_N → 0 as N → ∞.

use nalgebra::{DMatrix, DVector};

/// Full result for a single N.
#[derive(Debug, Clone)]
pub struct DistanceResult {
    pub n: usize,
    /// Unconstrained minimum: d²_N = 1 - b^T G^{-1} b
    pub d2: f64,
    /// Optimal coefficients c* = G^{-1} b
    pub coeffs: Vec<f64>,
    /// Smallest eigenvalue of G_N
    pub lambda_min: f64,
    /// Largest eigenvalue of G_N
    pub lambda_max: f64,
    /// Condition number κ(G_N) = λ_max / λ_min
    pub condition: f64,
    /// ||c*||² = c^T c (coefficient energy)
    pub coeff_energy: f64,
    /// ||c*||₁ = Σ|cₖ| (coefficient mass)
    pub coeff_mass: f64,
    /// b^T c* (projection magnitude)
    pub projection: f64,

    // ═══ Delocalization metrics for v_min ═══
    /// ||v_min||_∞ (max absolute component of the ground-state eigenvector)
    pub vmin_linf: f64,
    /// D(N) = ||v_min||_∞ · √(N-1)  (delocalization ratio; bounded ⟹ delocalized)
    pub delocalization_ratio: f64,
    /// IPR = Σ v_i⁴ / (Σ v_i²)² (inverse participation ratio; 1/N for uniform)
    pub ipr: f64,
    /// |⟨b, v_min⟩| (projection of target b onto ground-state eigenvector)
    pub b_vmin_proj: f64,
}

/// Compute the unconstrained NB distance for a given N.
///
/// Uses Cholesky decomposition (G is symmetric positive definite).
/// Falls back to LU if Cholesky fails.
pub fn compute_distance(
    gram_data: &[f64],
    dim: usize,
    b: &[f64],
    n: usize,
) -> DistanceResult {
    let g = DMatrix::from_fn(dim, dim, |i, j| gram_data[i * dim + j]);
    let bv = DVector::from_column_slice(&b[..dim]);

    // Solve G c = b
    let coeffs_vec = if let Some(chol) = g.clone().cholesky() {
        chol.solve(&bv)
    } else {
        // Fallback: LU decomposition
        g.clone().lu().solve(&bv).unwrap_or_else(|| DVector::zeros(dim))
    };

    // d² = 1 - b^T c
    let projection = bv.dot(&coeffs_vec);
    let d2 = 1.0 - projection;

    // Eigendecomposition for conditioning + delocalization
    let eig = g.symmetric_eigen();
    let eigenvalues = &eig.eigenvalues;
    let lambda_min = eigenvalues.iter().cloned().fold(f64::INFINITY, f64::min);
    let lambda_max = eigenvalues.iter().cloned().fold(f64::NEG_INFINITY, f64::max);
    let condition = if lambda_min > 1e-30 { lambda_max / lambda_min } else { f64::INFINITY };

    // Find ground-state eigenvector (v_min)
    let min_idx = eigenvalues.iter()
        .enumerate()
        .min_by(|a, b| a.1.partial_cmp(b.1).unwrap())
        .map(|(i, _)| i)
        .unwrap_or(0);

    let v_min = eig.eigenvectors.column(min_idx);

    // Delocalization metrics
    let vmin_linf = v_min.iter().cloned().fold(0.0f64, |acc, x| acc.max(x.abs()));
    let delocalization_ratio = vmin_linf * (dim as f64).sqrt();
    let v4_sum: f64 = v_min.iter().map(|x| x.powi(4)).sum();
    let v2_sum: f64 = v_min.iter().map(|x| x.powi(2)).sum();
    let ipr = if v2_sum > 0.0 { v4_sum / (v2_sum * v2_sum) } else { 1.0 };
    let b_vmin_proj: f64 = bv.dot(&DVector::from_column_slice(v_min.as_slice())).abs();

    let coeffs: Vec<f64> = coeffs_vec.iter().cloned().collect();
    let coeff_energy: f64 = coeffs.iter().map(|c| c * c).sum();
    let coeff_mass: f64 = coeffs.iter().map(|c| c.abs()).sum();

    DistanceResult {
        n,
        d2,
        coeffs,
        lambda_min,
        lambda_max,
        condition,
        coeff_energy,
        coeff_mass,
        projection,
        vmin_linf,
        delocalization_ratio,
        ipr,
        b_vmin_proj,
    }
}
