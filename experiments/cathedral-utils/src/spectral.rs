//! Eigendecomposition and spectral analysis utilities.
//!
//! Wraps nalgebra's symmetric eigen solver with Cathedral-standard
//! interfaces for eigenvalue sweeps, inverse power iteration, and
//! participation ratio computation.

/// Full eigendecomposition via nalgebra symmetric_eigen.
///
/// Returns (sorted_eigenvalues, ground_state_eigenvector).
/// Eigenvalues are sorted ascending (λ_min first).
pub fn full_eigen(mat: &[f64], dim: usize) -> (Vec<f64>, Vec<f64>) {
    let m = nalgebra::DMatrix::from_row_slice(dim, dim, mat);
    let eigen = m.symmetric_eigen();
    let mut eigs: Vec<(f64, usize)> = eigen
        .eigenvalues
        .iter()
        .enumerate()
        .map(|(i, &v)| (v, i))
        .collect();
    eigs.sort_by(|a, b| a.0.partial_cmp(&b.0).unwrap());
    let min_idx = eigs[0].1;
    let v_min: Vec<f64> = eigen.eigenvectors.column(min_idx).iter().copied().collect();
    (eigs.iter().map(|(v, _)| *v).collect(), v_min)
}

/// Inverse power iteration for λ_min on a stored matrix.
///
/// More efficient than full eigendecomposition for large matrices
/// when only the smallest eigenvalue is needed.
pub fn inverse_power_iteration(
    mat: &[f64],
    dim: usize,
    max_iter: usize,
    tol: f64,
) -> (f64, Vec<f64>) {
    let g = nalgebra::DMatrix::from_row_slice(dim, dim, mat);
    let lu = g.clone().lu();
    let mut v = nalgebra::DVector::from_fn(dim, |i, _| ((i * 7 + 13) % 97) as f64 - 48.0);
    v /= v.norm();
    let mut lambda = 0.0f64;

    for _ in 0..max_iter {
        let w = match lu.solve(&v) {
            Some(w) => w,
            None => break,
        };
        let new_lambda = 1.0 / v.dot(&w);
        let w_norm = w.norm();
        v = w / w_norm;
        if (new_lambda - lambda).abs() < tol * lambda.abs().max(1e-30) {
            break;
        }
        lambda = new_lambda;
    }
    let gv = &g * &v;
    let rq = v.dot(&gv) / v.dot(&v);
    (rq, v.iter().copied().collect())
}

/// Participation ratio: PR = 1/IPR where IPR = Σ v_i⁴.
///
/// QUE predicts PR ~ N (delocalized). Anderson localization predicts plateau.
#[inline]
pub fn participation_ratio(v: &[f64]) -> f64 {
    let ipr: f64 = v.iter().map(|x| x.powi(4)).sum();
    if ipr > 0.0 {
        1.0 / ipr
    } else {
        0.0
    }
}
