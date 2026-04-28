// hilbert-spectral/src/hilbert.rs
//
// Hilbert matrix construction and spectral analysis
//
// The discrete Hilbert matrix H_N has entries:
//   H(m,n) = 1/(m-n)  for m ≠ n,  H(m,m) = 0
//
// Its operator norm ‖H_N‖ → π as N → ∞ (Schur, 1911).
// This is the fundamental constant underlying the Montgomery-Vaughan
// Hilbert inequality used in the Cathedral proof.

use nalgebra::{DMatrix, DVector, SymmetricEigen};

/// Build the antisymmetric Hilbert kernel matrix H_N.
/// H(i,j) = 1/(i-j) for i ≠ j, 0 for i = j.
/// The matrix is real and antisymmetric: H(i,j) = -H(j,i).
///
/// For operator norm computation, we use H^T H (which is symmetric positive semidefinite).
pub fn build_hilbert_kernel(n: usize) -> DMatrix<f64> {
    DMatrix::from_fn(n, n, |i, j| {
        if i == j {
            0.0
        } else {
            1.0 / (i as f64 - j as f64)
        }
    })
}

/// Build the SYMMETRIC Hilbert matrix (Hilbert's original):
/// H(i,j) = 1/(i+j+1) for 0-indexed, or 1/(i+j-1) for 1-indexed.
/// Its largest eigenvalue → π as N → ∞.
pub fn build_symmetric_hilbert(n: usize) -> DMatrix<f64> {
    DMatrix::from_fn(n, n, |i, j| {
        1.0 / (i as f64 + j as f64 + 1.0)
    })
}

/// Build the Montgomery-Vaughan kernel with log-separation:
/// K(m,n) = 1/|log(m+1) - log(n+1)| for m ≠ n (0-indexed, +1 for positivity)
/// K(m,m) = 0
/// Row sums of this kernel approximate π·(n+1) for large N.
pub fn build_mv_kernel(n: usize) -> DMatrix<f64> {
    DMatrix::from_fn(n, n, |i, j| {
        if i == j {
            0.0
        } else {
            let li = ((i + 1) as f64).ln();
            let lj = ((j + 1) as f64).ln();
            1.0 / (li - lj).abs()
        }
    })
}

/// Compute the operator norm ‖A‖ = max singular value = √(max eigenvalue of A^T A).
/// For an antisymmetric matrix, this equals the largest singular value.
pub fn operator_norm(a: &DMatrix<f64>) -> f64 {
    let ata = a.transpose() * a;
    let eigen = SymmetricEigen::new(ata);
    eigen.eigenvalues.iter()
        .cloned()
        .fold(0.0f64, f64::max)
        .sqrt()
}

/// Compute all eigenvalues of a symmetric matrix, sorted descending.
pub fn eigenvalues_descending(a: &DMatrix<f64>) -> Vec<f64> {
    let eigen = SymmetricEigen::new(a.clone());
    let mut eigs: Vec<f64> = eigen.eigenvalues.iter().cloned().collect();
    eigs.sort_by(|a, b| b.partial_cmp(a).unwrap());
    eigs
}

/// Compute row sums of absolute values: R_i = Σ_{j≠i} |K(i,j)|
pub fn row_sums(a: &DMatrix<f64>) -> Vec<f64> {
    (0..a.nrows()).map(|i| {
        (0..a.ncols()).map(|j| a[(i, j)].abs()).sum()
    }).collect()
}

/// Power iteration to estimate largest singular value (for large matrices).
/// Returns (estimated norm, number of iterations).
pub fn power_iteration_norm(a: &DMatrix<f64>, max_iter: usize, tol: f64) -> (f64, usize) {
    let n = a.ncols();
    let ata = a.transpose() * a;

    // Random-ish starting vector
    let mut v = DVector::from_fn(n, |i, _| (i as f64 + 1.0).sin());
    v.normalize_mut();

    let mut lambda = 0.0;
    for iter in 0..max_iter {
        let w = &ata * &v;
        let new_lambda = w.norm();
        v = w / new_lambda;

        if (new_lambda - lambda).abs() / new_lambda.max(1e-15) < tol {
            return (new_lambda.sqrt(), iter + 1);
        }
        lambda = new_lambda;
    }
    (lambda.sqrt(), max_iter)
}

/// Compute the Schur test bound: max(max_row_sum, max_col_sum).
/// For a symmetric matrix, this is just the max row sum.
pub fn schur_test_bound(a: &DMatrix<f64>) -> f64 {
    let rsums = row_sums(a);
    rsums.iter().cloned().fold(0.0f64, f64::max)
}
