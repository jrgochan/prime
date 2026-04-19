/// Covariance matrix assembly and quadratic form computation.
///
/// C = G - bb^T   (Schur complement — the skeleton of RH)
/// d²_N = 1 - 2⟨b,w⟩ + w^T G w  (the Nyman-Beurling distance)
///      = (1 - w^T b)² + w^T C w   (variance decomposition)

use crate::gram::{gram_entry, mean_entry};
use nalgebra::{DMatrix, DVector};
use rayon::prelude::*;

/// Result of probing the covariance matrix at dimension N.
#[derive(Debug, Clone, serde::Serialize)]
pub struct ProbeResult {
    pub n: usize,
    /// d²_N = 1 - 2⟨b,w⟩ + w^T G w (the full NB distance squared)
    pub d_squared: f64,
    /// The covariance part: w^T C w
    pub cov_quad: f64,
    /// The mean part: (1 - w^T b)²
    pub mean_residual_sq: f64,
    /// w^T G w (Gram quadratic form)
    pub gram_quad: f64,
    /// w^T b (mean projection)
    pub mean_projection: f64,
    /// 1/ln(N) for comparison
    pub inv_log_n: f64,
    /// Ratio d²_N / (1/ln N)
    pub ratio: f64,
    /// Smallest eigenvalue of C
    pub lambda_min: f64,
    /// Largest eigenvalue of C
    pub lambda_max: f64,
    /// Condition number
    pub condition: f64,
    /// Frobenius norm of C
    pub frob_norm: f64,
    /// Trace of C
    pub trace_c: f64,
}

/// Build the (N-1) × (N-1) Gram matrix G in parallel.
/// The BD basis uses k = 1..N-1 (N-1 dimensional).
/// G[i][j] = gram_entry(i+1, j+1) for i,j in 0..N-2.
pub fn build_gram_matrix(n: usize) -> DMatrix<f64> {
    let dim = n - 1; // N-1 dimensional
    let n_entries = dim * (dim + 1) / 2;
    let entries: Vec<(usize, usize, f64)> = (0..n_entries)
        .into_par_iter()
        .map(|idx| {
            let (i, j) = linear_to_upper_triangle(idx, dim);
            let val = gram_entry(i + 1, j + 1);
            (i, j, val)
        })
        .collect();

    let mut g = DMatrix::zeros(dim, dim);
    for (i, j, val) in entries {
        g[(i, j)] = val;
        g[(j, i)] = val;
    }
    g
}

/// Build the mean vector b ∈ ℝ^{N-1}.
/// b_j = (ln(j) + γ) / j for j = 1..N-1.
pub fn build_mean_vector(n: usize) -> DVector<f64> {
    let dim = n - 1;
    DVector::from_fn(dim, |i, _| mean_entry(i + 1))
}

/// Build the covariance matrix C = G - bb^T.
pub fn build_covariance(g: &DMatrix<f64>, b: &DVector<f64>) -> DMatrix<f64> {
    let bbt = b * b.transpose();
    g - bbt
}

/// Build the Báez-Duarte-Möbius weight vector.
///
/// From BDWeights.lean:
///   v(i) = -μ(i+1) · (1 - ln(i+1)/ln(N))
///
/// for i = 0..N-2, so k = i+1 ranges over {1, ..., N-1}.
pub fn build_bd_weight(n: usize, mu: &[i32]) -> DVector<f64> {
    let dim = n - 1;
    let ln_n = (n as f64).ln();
    DVector::from_fn(dim, |i, _| {
        let k = i + 1; // 1-indexed basis element
        let kf = k as f64;
        let log_weight = 1.0 - kf.ln() / ln_n;
        -(mu[k] as f64) * log_weight
    })
}

/// Full probe at dimension N.
pub fn probe(n: usize, mu: &[i32]) -> ProbeResult {
    assert!(n >= 3, "N must be at least 3");
    let ln_n = (n as f64).ln();
    let inv_log_n = 1.0 / ln_n;

    // Build matrices (dimension N-1)
    let g = build_gram_matrix(n);
    let b = build_mean_vector(n);
    let c = build_covariance(&g, &b);

    // Build weight vector
    let w = build_bd_weight(n, mu);

    // Quadratic forms
    // d²_N = 1 - 2⟨b,w⟩ + w^T G w
    let gw = &g * &w;
    let gram_quad = w.dot(&gw);
    let mean_projection = w.dot(&b);
    let d_squared = 1.0 - 2.0 * mean_projection + gram_quad;

    // Covariance part: w^T C w = d²_N - (1 - w^T b)²
    let cw = &c * &w;
    let cov_quad = w.dot(&cw);
    let mean_residual_sq = (1.0 - mean_projection).powi(2);

    // Eigenvalue analysis
    let eig = c.clone().symmetric_eigen();
    let eigenvalues = eig.eigenvalues;

    let lambda_min = eigenvalues.iter().copied().fold(f64::INFINITY, f64::min);
    let lambda_max = eigenvalues
        .iter()
        .copied()
        .fold(f64::NEG_INFINITY, f64::max);
    let condition = if lambda_min.abs() > 1e-15 {
        (lambda_max / lambda_min).abs()
    } else {
        f64::INFINITY
    };

    let frob_norm = c.iter().map(|x| x * x).sum::<f64>().sqrt();
    let trace_c = (0..c.nrows()).map(|i| c[(i, i)]).sum();

    let ratio = d_squared * ln_n;

    ProbeResult {
        n,
        d_squared,
        cov_quad,
        mean_residual_sq,
        gram_quad,
        mean_projection,
        inv_log_n,
        ratio,
        lambda_min,
        lambda_max,
        condition,
        frob_norm,
        trace_c,
    }
}

/// Map a linear index to upper triangle coordinates (i, j) with i ≤ j.
fn linear_to_upper_triangle(idx: usize, n: usize) -> (usize, usize) {
    let mut count = 0;
    let mut i = 0;
    loop {
        let row_len = n - i;
        if count + row_len > idx {
            let j = i + (idx - count);
            return (i, j);
        }
        count += row_len;
        i += 1;
    }
}
