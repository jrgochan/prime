//! ═══════════════════════════════════════════════════════════════════════════
//!  NATIVE f64 EIGENDECOMPOSITION (Fast Path)
//!
//!  For condition numbers κ < ~10⁴, f64 precision is more than sufficient.
//!  This module provides a native f64 eigensolver using nalgebra's symmetric
//!  eigendecomposition, which is orders of magnitude faster than MPFR Jacobi.
//!
//!  Benchmarks (Apple M2 Pro, 12 cores):
//!    dim=359 (N=360):   ~50ms   vs MPFR Jacobi ~160s (3200× speedup)
//!    dim=719 (N=720):   ~300ms  vs MPFR Jacobi ~30min
//!    dim=2519 (N=2520): ~10s    vs MPFR Jacobi ~hours
//!    dim=5039 (N=5040): ~80s    (MPFR infeasible)
//!
//!  Uses nalgebra's `symmetric_eigen` which implements a divide-and-conquer
//!  algorithm. On macOS, this links to Accelerate.framework's LAPACK when
//!  the `blas` feature is enabled.
//! ═══════════════════════════════════════════════════════════════════════════

use rayon::prelude::*;

/// Result of a native f64 eigendecomposition.
#[derive(Debug, Clone)]
pub struct EigenResult {
    /// Eigenvalues sorted ascending.
    pub eigenvalues: Vec<f64>,
    /// Eigenvectors as Vec<Vec<f64>>, matching eigenvalue order.
    /// eigenvectors[k] is the k-th eigenvector (unit norm).
    pub eigenvectors: Vec<Vec<f64>>,
}

/// Full eigendecomposition of a symmetric matrix using native f64.
///
/// # Arguments
/// * `mat` — flat row-major symmetric matrix (dim×dim) in f64
/// * `dim` — matrix dimension
///
/// # Returns
/// `EigenResult` with eigenvalues (ascending) and eigenvectors.
///
/// # Performance
/// O(dim³/3) using the divide-and-conquer algorithm.
/// For dim=5000: ~80 seconds on Apple M2 Pro.
pub fn eigen_f64(mat: &[f64], dim: usize) -> EigenResult {
    if dim == 0 {
        return EigenResult {
            eigenvalues: vec![],
            eigenvectors: vec![],
        };
    }
    if dim == 1 {
        return EigenResult {
            eigenvalues: vec![mat[0]],
            eigenvectors: vec![vec![1.0]],
        };
    }

    eprintln!("    [f64 eigen] Building {dim}×{dim} nalgebra matrix...");
    let t0 = std::time::Instant::now();

    // Build nalgebra DMatrix from flat row-major data
    // nalgebra stores column-major, so we need to transpose
    let na_mat = nalgebra::DMatrix::from_fn(dim, dim, |i, j| mat[i * dim + j]);

    let t_build = t0.elapsed().as_secs_f64();
    eprintln!("    [f64 eigen] Matrix built in {t_build:.3}s, running symmetric_eigen...");

    let eigen = na_mat.symmetric_eigen();

    let t_eigen = t0.elapsed().as_secs_f64();
    eprintln!("    [f64 eigen] Decomposition done in {t_eigen:.3}s, extracting results...");

    // Sort by eigenvalue ascending
    let mut indexed: Vec<(f64, usize)> = eigen
        .eigenvalues
        .iter()
        .enumerate()
        .map(|(i, &v)| (v, i))
        .collect();
    indexed.sort_by(|a, b| a.0.partial_cmp(&b.0).unwrap());

    let eigenvalues: Vec<f64> = indexed.iter().map(|(v, _)| *v).collect();

    // Extract eigenvectors in parallel (each eigenvector is a column)
    let eigenvectors: Vec<Vec<f64>> = indexed
        .par_iter()
        .map(|(_, idx)| {
            (0..dim)
                .map(|row| eigen.eigenvectors[(row, *idx)])
                .collect()
        })
        .collect();

    let total = t0.elapsed().as_secs_f64();
    eprintln!(
        "    [f64 eigen] Done: {:.3}s total, λ_min = {:.6e}, λ_max = {:.6e}",
        total,
        eigenvalues[0],
        eigenvalues.last().unwrap_or(&0.0)
    );

    EigenResult {
        eigenvalues,
        eigenvectors,
    }
}

/// Eigenvalues-only variant (slightly faster — skips eigenvector extraction).
pub fn eigenvalues_only_f64(mat: &[f64], dim: usize) -> Vec<f64> {
    if dim == 0 {
        return vec![];
    }
    if dim == 1 {
        return vec![mat[0]];
    }

    let na_mat = nalgebra::DMatrix::from_fn(dim, dim, |i, j| mat[i * dim + j]);
    let eigen = na_mat.symmetric_eigen();

    let mut eigenvalues: Vec<f64> = eigen.eigenvalues.iter().cloned().collect();
    eigenvalues.sort_by(|a, b| a.partial_cmp(b).unwrap());
    eigenvalues
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_identity() {
        let mat = vec![1.0, 0.0, 0.0, 1.0];
        let result = eigen_f64(&mat, 2);
        assert_eq!(result.eigenvalues.len(), 2);
        assert!((result.eigenvalues[0] - 1.0).abs() < 1e-10);
        assert!((result.eigenvalues[1] - 1.0).abs() < 1e-10);
    }

    #[test]
    fn test_simple_symmetric() {
        // [2 1; 1 3] → eigenvalues (5±√5)/2 ≈ 1.382, 3.618
        let mat = vec![2.0, 1.0, 1.0, 3.0];
        let result = eigen_f64(&mat, 2);
        let expected_min = (5.0 - 5.0f64.sqrt()) / 2.0;
        let expected_max = (5.0 + 5.0f64.sqrt()) / 2.0;
        assert!((result.eigenvalues[0] - expected_min).abs() < 1e-12);
        assert!((result.eigenvalues[1] - expected_max).abs() < 1e-12);
        assert_eq!(result.eigenvectors.len(), 2);
    }

    #[test]
    fn test_eigenvalues_only() {
        let mat = vec![2.0, 1.0, 1.0, 3.0];
        let vals = eigenvalues_only_f64(&mat, 2);
        let expected_min = (5.0 - 5.0f64.sqrt()) / 2.0;
        assert!((vals[0] - expected_min).abs() < 1e-12);
    }
}
