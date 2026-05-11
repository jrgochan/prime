//! Spectral analysis: eigenvalue decay, participation ratio, dipole detection.
//!
//! This module extracts physics from the Gram matrix eigensystem:
//! - Eigenvalue decay rates (power-law vs. log-decay fits)
//! - Participation ratio (QUE vs. Anderson localization)
//! - Arithmetic dipole detection (sign-cancellation in b-vector projection)

use crate::arith;
use crate::gram::GramMatrix;

// ═══════════════════════════════════════════════════════════════
// DATA STRUCTURES
// ═══════════════════════════════════════════════════════════════

/// Result of eigenvalue computation for a single N.
pub struct EigenResult {
    pub n: usize,
    pub dim: usize,
    pub lambda_min: f64,
    pub lambda_2: f64,
    pub lambda_3: f64,
    pub gap: f64,
    pub eigvec_min: Vec<f64>,
    pub method: &'static str,
    pub elapsed: f64,
}

/// Vacuum geometry measurements for a single N.
pub struct VacuumGeometry {
    pub n: usize,
    pub pr: f64,
    pub pr_over_n: f64,
    pub v_inf: f64,
    pub v_inf_sqrt_n: f64,
    pub b_dot_v: f64,
    pub peak_k: usize,
    pub peak_ratio: f64,
}

/// Dipole analysis of the ground-state eigenvector.
#[allow(dead_code)]
pub struct DipoleAnalysis {
    pub pos_sum: f64,
    pub neg_sum: f64,
    pub net: f64,
    pub cancellation_ratio: f64,
    pub components: Vec<DipoleComponent>,
}

/// A single component of the dipole.
#[allow(dead_code)]
pub struct DipoleComponent {
    pub k: usize,
    pub v_k: f64,
    pub b_k: f64,
    pub contribution: f64,
    pub running_sum: f64,
    pub factorization: String,
}

/// Decay rate fit results.
pub struct DecayFit {
    pub power_c: f64,
    pub power_alpha: f64,
    pub power_r2: f64,
    pub log_beta: f64,
    pub log_r2: f64,
}

// ═══════════════════════════════════════════════════════════════
// EIGENVALUE DECAY
// ═══════════════════════════════════════════════════════════════

/// Compute eigenvalues for all test N values from the prebuilt Gram matrix.
pub fn eigenvalue_sweep(gram: &GramMatrix, test_ns: &[usize]) -> Vec<EigenResult> {
    let mut results = Vec::new();

    for &n in test_ns {
        let t = std::time::Instant::now();
        let (sub, dim) = gram.extract_submatrix(n);

        let (lambda_min, lambda_2, lambda_3, eigvec, method) = if dim <= 2000 {
            let (eigs, v_min) = crate::gram::full_eigen(&sub, dim);
            (
                eigs[0],
                eigs.get(1).copied().unwrap_or(0.0),
                eigs.get(2).copied().unwrap_or(0.0),
                v_min,
                "full_eigen",
            )
        } else {
            let (lmin, v) = crate::gram::inverse_power_iteration(&sub, dim, 500, 1e-14);
            (lmin, 0.0, 0.0, v, "inv_power")
        };

        let gap = if lambda_min.abs() > 1e-30 && lambda_2 != 0.0 {
            lambda_2 / lambda_min
        } else {
            f64::NAN
        };

        results.push(EigenResult {
            n,
            dim,
            lambda_min,
            lambda_2,
            lambda_3,
            gap,
            eigvec_min: eigvec,
            method,
            elapsed: t.elapsed().as_secs_f64(),
        });
    }

    results
}

/// Fit decay models to eigenvalue data.
pub fn fit_decay(results: &[EigenResult]) -> DecayFit {
    let fit_data: Vec<(f64, f64)> = results
        .iter()
        .filter(|r| r.lambda_min > 0.0 && r.n >= 30)
        .map(|r| (r.n as f64, r.lambda_min))
        .collect();

    let (mut power_c, mut power_alpha, mut power_r2) = (0.0, 0.0, 0.0);
    let (mut log_beta, mut log_r2) = (0.0, 0.0);

    // Power law: λ ~ C · N^{-α}
    let log_data: Vec<(f64, f64)> = fit_data.iter().map(|(n, l)| (n.ln(), l.ln())).collect();
    if log_data.len() >= 3 {
        let (slope, intercept, r2) = arith::linreg(&log_data);
        power_alpha = -slope;
        power_c = intercept.exp();
        power_r2 = r2;
    }

    // Log decay: λ ~ C / (log N)^β
    let loglog_data: Vec<(f64, f64)> = fit_data
        .iter()
        .map(|(n, l)| (n.ln().ln(), l.ln()))
        .collect();
    if loglog_data.len() >= 3 {
        let (slope, _intercept, r2) = arith::linreg(&loglog_data);
        log_beta = -slope;
        log_r2 = r2;
    }

    DecayFit {
        power_c,
        power_alpha,
        power_r2,
        log_beta,
        log_r2,
    }
}

// ═══════════════════════════════════════════════════════════════
// VACUUM GEOMETRY
// ═══════════════════════════════════════════════════════════════

/// Compute all vacuum geometry measurements for a given N.
pub fn vacuum_geometry(gram: &GramMatrix, n: usize) -> Option<VacuumGeometry> {
    if n < 3 {
        return None;
    }
    let (sub, dim) = gram.extract_submatrix(n);
    if dim > 2000 {
        return None;
    }

    let (_, v_min) = crate::gram::full_eigen(&sub, dim);
    let b = arith::b_vector(dim);

    let b_dot_v: f64 = b.iter().zip(v_min.iter()).map(|(bi, vi)| bi * vi).sum();

    let ipr: f64 = v_min.iter().map(|v| v.powi(4)).sum();
    let pr = 1.0 / ipr;
    let v_inf = v_min.iter().map(|v| v.abs()).fold(0.0f64, f64::max);

    let (peak_idx, _) = v_min
        .iter()
        .enumerate()
        .max_by(|(_, a), (_, b)| a.abs().partial_cmp(&b.abs()).unwrap())
        .unwrap();
    let peak_k = peak_idx + 2;

    Some(VacuumGeometry {
        n,
        pr,
        pr_over_n: pr / n as f64,
        v_inf,
        v_inf_sqrt_n: v_inf * (dim as f64).sqrt(),
        b_dot_v,
        peak_k,
        peak_ratio: peak_k as f64 / n as f64,
    })
}

/// Participation ratio: PR = 1 / Σ v_i⁴.
///
/// QUE predicts PR ~ N (delocalized). Anderson localization predicts plateau.
#[inline]
#[allow(dead_code)]
pub fn participation_ratio(v: &[f64]) -> f64 {
    let ipr: f64 = v.iter().map(|x| x.powi(4)).sum();
    if ipr > 0.0 {
        1.0 / ipr
    } else {
        0.0
    }
}

// ═══════════════════════════════════════════════════════════════
// DIPOLE ANALYSIS
// ═══════════════════════════════════════════════════════════════

/// Analyze the arithmetic dipole structure of the ground-state eigenvector.
///
/// The "dipole" is the sign-cancellation pattern where heavy fermions
/// pair up with opposite signs, producing near-zero ⟨b, v_min⟩ despite
/// each individual |b_k · v_k| being macroscopic.
pub fn dipole_analysis(v: &[f64], num_components: usize) -> DipoleAnalysis {
    let b = arith::b_vector(v.len());

    // Sort by weight magnitude
    let mut indexed: Vec<(usize, f64)> =
        v.iter().enumerate().map(|(i, &val)| (i + 2, val)).collect();
    indexed.sort_by(|a, b| b.1.abs().partial_cmp(&a.1.abs()).unwrap());

    let mut pos_sum = 0.0f64;
    let mut neg_sum = 0.0f64;
    let mut running = 0.0f64;
    let mut components = Vec::new();

    for &(k, v_k) in indexed.iter().take(num_components) {
        let b_k = b[k - 2];
        let contrib = b_k * v_k;
        running += contrib;
        if contrib > 0.0 {
            pos_sum += contrib;
        } else {
            neg_sum += contrib;
        }

        components.push(DipoleComponent {
            k,
            v_k,
            b_k,
            contribution: contrib,
            running_sum: running,
            factorization: arith::factorize(k),
        });
    }

    let total_magnitude = pos_sum - neg_sum; // pos - neg (since neg is negative)
    let cancellation_ratio = if total_magnitude.abs() > 1e-30 {
        running.abs() / total_magnitude
    } else {
        0.0
    };

    DipoleAnalysis {
        pos_sum,
        neg_sum,
        net: running,
        cancellation_ratio,
        components,
    }
}
