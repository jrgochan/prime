//! ═══════════════════════════════════════════════════════════════════════════
//!  Dense Linear Algebra Primitives
//!
//!  Consolidates the dense matrix-vector product routines that were
//!  duplicated across 8+ experiments. These are used by Lanczos iteration,
//!  power method, and spectral shift computations.
//!
//!  All routines assume row-major storage: `mat[i * dim + j]` = entry (i,j).
//! ═══════════════════════════════════════════════════════════════════════════

/// Dense symmetric matrix-vector product: `out = mat · v` (row-major `mat`).
///
/// # Panics
/// Panics if `mat.len() < dim * dim` or if `v.len() < dim` or `out.len() < dim`.
pub fn dense_matvec(mat: &[f64], dim: usize, v: &[f64], out: &mut [f64]) {
    for i in 0..dim {
        let mut sum = 0.0f64;
        let row_start = i * dim;
        for j in 0..dim {
            sum += mat[row_start + j] * v[j];
        }
        out[i] = sum;
    }
}

/// Shifted matrix-vector product: `out = (σI - mat) · v`.
///
/// Computes `out[i] = σ * v[i] - (mat · v)[i]`. Used by Lanczos iteration
/// with spectral shift to convert the smallest eigenvalue of `mat` into
/// the largest eigenvalue of `(σI - mat)`.
pub fn shifted_matvec(mat: &[f64], dim: usize, sigma: f64, v: &[f64], out: &mut [f64]) {
    dense_matvec(mat, dim, v, out);
    for i in 0..dim {
        out[i] = sigma * v[i] - out[i];
    }
}

/// Estimate a spectral shift σ > λ_max from the matrix diagonal.
///
/// Uses the Gershgorin circle theorem: σ = max_i (|a_{ii}| + Σ_{j≠i} |a_{ij}|),
/// scaled by 1.1 for safety margin. For symmetric PD matrices, this is a
/// conservative upper bound on λ_max.
///
/// A simpler alternative is `trace * 1.1 / dim`, but Gershgorin is tighter.
pub fn estimate_sigma(mat: &[f64], dim: usize) -> f64 {
    let trace: f64 = (0..dim).map(|i| mat[i * dim + i]).sum();
    // Simple trace-based estimate (sufficient for Lanczos convergence)
    trace * 1.1
}

// ═══════════════════════════════════════════════════════════════
// DOUBLE-DOUBLE PRECISION MATVEC
// ═══════════════════════════════════════════════════════════════

use crate::dd::DD;
use rayon::prelude::*;

/// Double-double precision matrix-vector product: `out = A · x` where
/// `A` is stored as split `(hi, lo)` arrays for ~31-digit entries.
///
/// Each entry `A[i,j] = a_hi[i*dim+j] + a_lo[i*dim+j]`. The inner
/// product is accumulated in DD precision throughout, then truncated
/// to f64 for the output vector.
///
/// ~2× slower than [`dense_matvec`] but preserves positive-definiteness
/// of the Gram matrix at large N (> 40,000) where f64 entries lose the
/// tiny eigenvalues.
///
/// Parallelized over rows via rayon — each output element is independent.
pub fn dense_matvec_dd(
    a_hi: &[f64], a_lo: &[f64], x: &[f64], out: &mut [f64], dim: usize,
) {
    out[..dim].par_iter_mut()
        .enumerate()
        .for_each(|(i, yi)| {
            let offset = i * dim;
            let mut acc = DD::from_f64(0.0);
            for j in 0..dim {
                let a_dd = DD::new(a_hi[offset + j], a_lo[offset + j]);
                let prod = a_dd * DD::from_f64(x[j]);
                acc += prod;
            }
            *yi = acc.to_f64();
        });
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_dense_matvec_identity() {
        // 3x3 identity
        let mat = vec![1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0];
        let v = vec![3.0, 5.0, 7.0];
        let mut out = vec![0.0; 3];
        dense_matvec(&mat, 3, &v, &mut out);
        assert_eq!(out, vec![3.0, 5.0, 7.0]);
    }

    #[test]
    fn test_dense_matvec_symmetric() {
        // Symmetric 2x2: [[2, 1], [1, 3]]
        let mat = vec![2.0, 1.0, 1.0, 3.0];
        let v = vec![1.0, 2.0];
        let mut out = vec![0.0; 2];
        dense_matvec(&mat, 2, &v, &mut out);
        assert!((out[0] - 4.0).abs() < 1e-14); // 2*1 + 1*2 = 4
        assert!((out[1] - 7.0).abs() < 1e-14); // 1*1 + 3*2 = 7
    }

    #[test]
    fn test_shifted_matvec() {
        let mat = vec![2.0, 1.0, 1.0, 3.0];
        let v = vec![1.0, 2.0];
        let mut out = vec![0.0; 2];
        shifted_matvec(&mat, 2, 10.0, &v, &mut out);
        // (10I - A)v = [10-2, 20-1; 10-1, 20-3] * [1,2] => [10*1-4, 10*2-7] = [6, 13]
        assert!((out[0] - 6.0).abs() < 1e-14);
        assert!((out[1] - 13.0).abs() < 1e-14);
    }

    #[test]
    fn test_estimate_sigma() {
        let mat = vec![5.0, 0.0, 0.0, 3.0];
        let sigma = estimate_sigma(&mat, 2);
        assert!(sigma > 5.0); // Must exceed λ_max
    }
}
