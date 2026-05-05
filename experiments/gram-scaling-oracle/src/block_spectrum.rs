//! ═══════════════════════════════════════════════════════════════════════════
//!  BLOCK SPECTRAL ANALYSIS
//!
//!  For each GCD class d, extract the Gram submatrix G^{(d)} consisting of
//!  rows/columns indexed by multiples of d, then compute eigenvalues.
//!
//!  Key insight: if the α≈0.855 scaling limit arises from the algebraic
//!  structure, it should be visible in how λ_min of each block scales
//!  with the block dimension.
//! ═══════════════════════════════════════════════════════════════════════════

use nalgebra::DMatrix;
use rayon::prelude::*;

use crate::gcd_decomp::GcdDecomposition;

/// Result of spectral analysis on a single GCD block.
#[derive(Debug, Clone)]
pub struct BlockSpectralResult {
    /// The GCD class divisor d.
    pub gcd_class: usize,
    /// Dimension of the block (number of multiples of d in {1,...,N}).
    pub dim: usize,
    /// Minimum eigenvalue of the block submatrix.
    pub lambda_min: f64,
    /// Maximum eigenvalue of the block submatrix.
    pub lambda_max: f64,
    /// All eigenvalues (sorted ascending).
    pub eigenvalues: Vec<f64>,
    /// Trace of the block submatrix.
    pub trace: f64,
    /// Frobenius norm of the block submatrix.
    pub frobenius_norm: f64,
}

/// Extract the submatrix of `full_mat` at the given row/column indices.
/// The indices are in 1..=N (from GCD decomposition), but the Gram matrix
/// stores G(2,...,N) as a (N-1)×(N-1) matrix with 0-based indexing.
/// So index j in GCD space maps to row (j-2) in the Gram matrix, but only
/// if j >= 2 (index 1 is not in the Gram matrix).
fn extract_submatrix(full_mat: &DMatrix<f64>, indices: &[usize]) -> DMatrix<f64> {
    // Filter to indices >= 2 (the Gram matrix starts at index 2)
    let valid_indices: Vec<usize> = indices.iter()
        .filter(|&&j| j >= 2 && j - 2 < full_mat.nrows())
        .cloned()
        .collect();
    let n = valid_indices.len();
    if n == 0 {
        return DMatrix::zeros(0, 0);
    }
    let mut sub = DMatrix::zeros(n, n);
    for (i, &ri) in valid_indices.iter().enumerate() {
        for (j, &ci) in valid_indices.iter().enumerate() {
            // GCD index j maps to Gram row j-2
            sub[(i, j)] = full_mat[(ri - 2, ci - 2)];
        }
    }
    sub
}

/// Compute eigenvalues of a symmetric matrix using nalgebra.
fn eigenvalues_symmetric(mat: &DMatrix<f64>) -> Vec<f64> {
    let eigen = mat.clone().symmetric_eigen();
    let mut evals: Vec<f64> = eigen.eigenvalues.iter().cloned().collect();
    evals.sort_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));
    evals
}

/// Analyze all GCD-class blocks of the Gram matrix.
///
/// For each divisor d with ≥ 2 multiples in {1,...,N}, extract the
/// submatrix and compute its spectrum.
pub fn analyze_blocks(
    full_mat: &DMatrix<f64>,
    decomp: &GcdDecomposition,
    _max_n: usize,
) -> Vec<BlockSpectralResult> {
    // Collect classes with enough indices for meaningful analysis
    let classes: Vec<_> = decomp.classes.iter()
        .filter(|(_, indices)| indices.len() >= 2)
        .collect();

    // Parallel spectral analysis of each block
    let results: Vec<BlockSpectralResult> = classes.par_iter()
        .filter_map(|(&d, indices)| {
            let sub = extract_submatrix(full_mat, indices);
            if sub.nrows() < 2 {
                return None; // Skip blocks too small for eigenvalue analysis
            }
            let trace = sub.trace();
            let frobenius_norm = sub.iter().map(|x| x * x).sum::<f64>().sqrt();
            let eigenvalues = eigenvalues_symmetric(&sub);

            let lambda_min = eigenvalues.first().copied().unwrap_or(0.0);
            let lambda_max = eigenvalues.last().copied().unwrap_or(0.0);

            Some(BlockSpectralResult {
                gcd_class: d,
                dim: sub.nrows(),
                lambda_min,
                lambda_max,
                eigenvalues,
                trace,
                frobenius_norm,
            })
        })
        .collect();

    // Sort by gcd_class for consistent output
    let mut results = results;
    results.sort_by_key(|r| r.gcd_class);
    results
}

/// Compute the full-matrix eigenvalue spectrum (for comparison).
pub fn full_spectrum(mat: &DMatrix<f64>) -> Vec<f64> {
    eigenvalues_symmetric(mat)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_extract_submatrix() {
        // 4×4 identity
        let mat = DMatrix::identity(4, 4);
        let indices = vec![1, 3]; // 1-based
        let sub = extract_submatrix(&mat, &indices);
        assert_eq!(sub.nrows(), 2);
        assert_eq!(sub[(0, 0)], 1.0);
        assert_eq!(sub[(0, 1)], 0.0);
        assert_eq!(sub[(1, 1)], 1.0);
    }

    #[test]
    fn test_eigenvalues_symmetric() {
        let mat = DMatrix::identity(3, 3);
        let evals = eigenvalues_symmetric(&mat);
        assert_eq!(evals.len(), 3);
        for &e in &evals {
            assert!((e - 1.0).abs() < 1e-10);
        }
    }
}
