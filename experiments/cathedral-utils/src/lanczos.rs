//! # Lanczos Iteration for Partial Eigendecomposition
//!
//! Extracts the bottom-k eigenvalues and eigenvectors of a symmetric
//! positive-definite matrix using the Lanczos algorithm with full
//! reorthogonalization.
//!
//! ## Key Functions
//!
//! - [`lanczos_bottom_k`] — Main entry point: returns (eigenvalues, eigenvectors)
//! - [`lanczos_tridiag`] — Builds the Lanczos tridiagonal matrix
//! - [`tridiag_eigenvalues`] — Extracts eigenvalues from a tridiagonal matrix
//!
//! ## Complexity
//!
//! - Time: O(m × cost_of_matvec + m² × N) for m Lanczos steps
//! - Memory: O(m × N) for the Lanczos vectors
//!
//! ## References
//!
//! - Lanczos, C. (1950). "An iteration method for the solution of the
//!   eigenvalue problem of linear differential and integral operators."
//! - Paige, C.C. (1971). "The computation of eigenvalues and eigenvectors
//!   of very large sparse matrices." (CG–Lanczos connection)

use rayon::prelude::*;

/// Result of a Lanczos eigendecomposition.
#[derive(Debug, Clone)]
pub struct LanczosResult {
    /// Eigenvalues (sorted ascending).
    pub eigenvalues: Vec<f64>,
    /// Eigenvectors as column-major dense matrix (N × k).
    /// `eigenvectors[i * dim + j]` = j-th component of i-th eigenvector.
    pub eigenvectors: Vec<Vec<f64>>,
    /// Number of Lanczos iterations actually performed.
    pub iterations: usize,
    /// Residual norms for convergence assessment.
    pub residual_norms: Vec<f64>,
}

/// Tridiagonal matrix from Lanczos recurrence.
#[derive(Debug, Clone)]
pub struct TridiagMatrix {
    /// Diagonal entries α_j = v_j^T A v_j.
    pub alpha: Vec<f64>,
    /// Off-diagonal entries β_j = ‖w_j‖.
    pub beta: Vec<f64>,
    /// Number of Lanczos steps completed.
    pub m: usize,
}

/// Build the Lanczos tridiagonal matrix via m iterations.
///
/// `matvec` computes A·v → result (the caller provides this closure).
/// `dim` is the matrix dimension N.
/// `m` is the number of Lanczos steps (typically 2k..4k for k desired eigenvalues).
/// `start` is an optional starting vector (if None, uses a deterministic one).
///
/// Returns the tridiagonal matrix AND the Lanczos basis vectors (for eigenvector recovery).
pub fn lanczos_tridiag<F>(
    matvec: &F,
    dim: usize,
    m: usize,
    start: Option<&[f64]>,
) -> (TridiagMatrix, Vec<Vec<f64>>)
where
    F: Fn(&[f64], &mut [f64]),
{
    let m = m.min(dim); // Can't exceed matrix dimension

    let mut alpha = Vec::with_capacity(m);
    let mut beta = Vec::with_capacity(m);
    let mut basis: Vec<Vec<f64>> = Vec::with_capacity(m + 1);

    // Starting vector (deterministic for reproducibility)
    let mut v: Vec<f64> = if let Some(s) = start {
        s.to_vec()
    } else {
        // Use 1/√N uniform vector — has good overlap with smooth eigenvectors
        let val = 1.0 / (dim as f64).sqrt();
        vec![val; dim]
    };

    // Normalize
    let norm = dot(&v, &v).sqrt();
    for x in &mut v {
        *x /= norm;
    }
    basis.push(v.clone());

    let mut w = vec![0.0f64; dim];

    for j in 0..m {
        // w = A · v_j
        matvec(&basis[j], &mut w);

        // α_j = v_j^T · w
        let a_j = dot(&basis[j], &w);
        alpha.push(a_j);

        // w = w - α_j · v_j - β_{j-1} · v_{j-1}
        for i in 0..dim {
            w[i] -= a_j * basis[j][i];
            if j > 0 {
                w[i] -= beta[j - 1] * basis[j - 1][i];
            }
        }

        // Full reorthogonalization (critical for numerical stability)
        // Two passes of modified Gram-Schmidt
        for _pass in 0..2 {
            for k in 0..=j {
                let coeff = dot(&w, &basis[k]);
                for i in 0..dim {
                    w[i] -= coeff * basis[k][i];
                }
            }
        }

        // β_j = ‖w‖
        let b_j = dot(&w, &w).sqrt();

        if b_j < 1e-14 {
            // Invariant subspace found — Lanczos converged early
            beta.push(0.0);
            break;
        }

        beta.push(b_j);

        // v_{j+1} = w / β_j
        let mut v_next = vec![0.0; dim];
        for i in 0..dim {
            v_next[i] = w[i] / b_j;
        }
        basis.push(v_next);
    }

    let actual_m = alpha.len();
    (
        TridiagMatrix {
            alpha,
            beta,
            m: actual_m,
        },
        basis,
    )
}

/// Extract eigenvalues and eigenvectors from a tridiagonal matrix.
///
/// Uses nalgebra's symmetric eigendecomposition on the dense m×m
/// tridiagonal matrix (instant for m ≤ few thousand).
pub fn tridiag_eigen(tri: &TridiagMatrix) -> (Vec<f64>, Vec<Vec<f64>>) {
    let m = tri.m;
    if m == 0 {
        return (vec![], vec![]);
    }

    // Build dense m×m tridiagonal matrix
    let mut mat = nalgebra::DMatrix::<f64>::zeros(m, m);
    for i in 0..m {
        mat[(i, i)] = tri.alpha[i];
        if i + 1 < m && i < tri.beta.len() {
            mat[(i, i + 1)] = tri.beta[i];
            mat[(i + 1, i)] = tri.beta[i];
        }
    }

    let eigen = mat.symmetric_eigen();

    // Sort by eigenvalue ascending
    let mut indexed: Vec<(f64, usize)> = eigen
        .eigenvalues
        .iter()
        .enumerate()
        .map(|(i, &v)| (v, i))
        .collect();
    indexed.sort_by(|a, b| a.0.partial_cmp(&b.0).unwrap());

    let eigenvalues: Vec<f64> = indexed.iter().map(|(v, _)| *v).collect();
    let eigenvectors: Vec<Vec<f64>> = indexed
        .iter()
        .map(|(_, idx)| (0..m).map(|row| eigen.eigenvectors[(row, *idx)]).collect())
        .collect();

    (eigenvalues, eigenvectors)
}

/// Extract the bottom-k eigenvalues and eigenvectors of a symmetric matrix
/// using Lanczos iteration with full reorthogonalization.
///
/// # Arguments
/// - `matvec`: closure that computes A·v → result
/// - `dim`: matrix dimension N
/// - `k`: number of bottom eigenvalues desired
/// - `m`: Lanczos subspace dimension (if 0, defaults to min(4k, N))
///
/// # Returns
/// A [`LanczosResult`] with the bottom-k eigenvalues and eigenvectors.
pub fn lanczos_bottom_k<F>(matvec: &F, dim: usize, k: usize, m: usize) -> LanczosResult
where
    F: Fn(&[f64], &mut [f64]) + Sync,
{
    let m = if m == 0 { (4 * k).min(dim) } else { m.min(dim) };

    // Build Lanczos tridiagonal
    let (tri, basis) = lanczos_tridiag(matvec, dim, m, None);
    let actual_m = tri.m;

    // Eigendecompose the tridiagonal
    let (ritz_values, ritz_vectors) = tridiag_eigen(&tri);

    // Take bottom k
    let k = k.min(ritz_values.len());
    let eigenvalues = ritz_values[..k].to_vec();

    // Map Ritz vectors back to original space (parallelized over k vectors)
    // v_i = Σ_j ritz_vec[i][j] * basis[j]
    let results: Vec<(Vec<f64>, f64)> = (0..k)
        .into_par_iter()
        .map(|i| {
            let mut v = vec![0.0f64; dim];
            let rv = &ritz_vectors[i];
            let rv_len = rv.len().min(basis.len());
            for j in 0..rv_len {
                let coeff = rv[j];
                for idx in 0..dim {
                    v[idx] += coeff * basis[j][idx];
                }
            }

            // Compute residual norm: ‖A·v - λ·v‖
            let mut av = vec![0.0f64; dim];
            matvec(&v, &mut av);
            let lambda = eigenvalues[i];
            let mut res_sq = 0.0;
            for idx in 0..dim {
                let r = av[idx] - lambda * v[idx];
                res_sq += r * r;
            }
            (v, res_sq.sqrt())
        })
        .collect();

    let mut eigenvectors = Vec::with_capacity(k);
    let mut residual_norms = Vec::with_capacity(k);
    for (v, res) in results {
        eigenvectors.push(v);
        residual_norms.push(res);
    }

    LanczosResult {
        eigenvalues,
        eigenvectors,
        iterations: actual_m,
        residual_norms,
    }
}

/// Extract Lanczos tridiagonal coefficients from CG iteration history.
///
/// Given the CG α_k and β_k coefficients from solving Ax = b,
/// reconstruct the Lanczos tridiagonal matrix T whose eigenvalues
/// approximate those of A.
///
/// The CG–Lanczos connection (Paige 1971):
///   T[j,j]   = 1/α_j + β_j/α_{j-1}    (diagonal)
///   T[j,j+1] = √β_{j+1} / α_j           (off-diagonal)
pub fn cg_to_lanczos(cg_alphas: &[f64], cg_betas: &[f64]) -> TridiagMatrix {
    let m = cg_alphas.len();
    let mut alpha = Vec::with_capacity(m);
    let mut beta = Vec::with_capacity(m);

    for j in 0..m {
        // Diagonal: 1/α_j + β_j/α_{j-1}
        let diag = 1.0 / cg_alphas[j]
            + if j > 0 {
                cg_betas[j] / cg_alphas[j - 1]
            } else {
                0.0
            };
        alpha.push(diag);

        // Off-diagonal: √(β_{j+1}) / α_j
        if j + 1 < m {
            let off = (cg_betas[j + 1]).sqrt() / cg_alphas[j];
            beta.push(off);
        }
    }

    TridiagMatrix { alpha, beta, m }
}

/// Inner product of two vectors.
#[inline]
fn dot(a: &[f64], b: &[f64]) -> f64 {
    a.iter().zip(b.iter()).map(|(x, y)| x * y).sum()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_lanczos_diagonal_matrix() {
        // Simple test: diagonal matrix with known eigenvalues
        let dim = 100;
        let eigenvalues: Vec<f64> = (1..=dim).map(|i| i as f64).collect();

        let matvec = |v: &[f64], out: &mut [f64]| {
            for i in 0..dim {
                out[i] = eigenvalues[i] * v[i];
            }
        };

        let result = lanczos_bottom_k(&matvec, dim, 5, 80);

        // Bottom 5 eigenvalues should be 1, 2, 3, 4, 5
        assert_eq!(result.eigenvalues.len(), 5);
        for (i, &lambda) in result.eigenvalues.iter().enumerate() {
            let expected = (i + 1) as f64;
            assert!(
                (lambda - expected).abs() < 1e-6,
                "eigenvalue {i}: expected {expected}, got {lambda}"
            );
        }
    }

    #[test]
    fn test_tridiag_eigen_small() {
        // 3×3 tridiagonal: [[2, 1, 0], [1, 2, 1], [0, 1, 2]]
        let tri = TridiagMatrix {
            alpha: vec![2.0, 2.0, 2.0],
            beta: vec![1.0, 1.0],
            m: 3,
        };
        let (vals, _) = tridiag_eigen(&tri);
        // Eigenvalues: 2 - √2, 2, 2 + √2
        let expected = [2.0 - 2.0f64.sqrt(), 2.0, 2.0 + 2.0f64.sqrt()];
        for (v, e) in vals.iter().zip(expected.iter()) {
            assert!((v - e).abs() < 1e-12, "expected {e}, got {v}");
        }
    }

    #[test]
    fn test_cg_to_lanczos_identity() {
        // For identity matrix CG: α_k = 1, β_k = 0
        // Lanczos diagonal should be 1/1 + 0 = 1
        let alphas = vec![1.0; 10];
        let betas = vec![0.0; 10];
        let tri = cg_to_lanczos(&alphas, &betas);
        for &a in &tri.alpha {
            assert!((a - 1.0).abs() < 1e-14);
        }
    }
}
