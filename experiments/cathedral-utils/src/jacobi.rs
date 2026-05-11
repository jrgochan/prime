//! ═══════════════════════════════════════════════════════════════════════════
//!  MPFR JACOBI EIGENDECOMPOSITION
//!  Extended-precision eigensolver for symmetric matrices.
//!
//!  Returns BOTH eigenvalues AND eigenvectors — critical for Route C
//!  spectral analysis where f64 eigendecomposition loses ~7 digits
//!  at condition number κ ~ 10⁷.
//!
//!  Algorithm: Cyclic Jacobi (sweep all (p,q) pairs) with threshold
//!  skipping. Quadratic convergence per sweep. O(N² · sweeps) total.
//!
//!  Memory: 2 × dim² × sizeof(Float) for matrix + eigenvectors.
//!  At 1024-bit, dim=3000 → ~2.3 GB for the matrix alone.
//! ═══════════════════════════════════════════════════════════════════════════

use rug::{Assign, Float};

/// Result of an MPFR Jacobi eigendecomposition.
pub struct JacobiResult {
    /// Eigenvalues sorted ascending.
    pub eigenvalues: Vec<f64>,
    /// Eigenvectors as Vec<Vec<f64>>, matching eigenvalue order.
    /// eigenvectors[k] is the k-th eigenvector (unit norm in MPFR).
    pub eigenvectors: Vec<Vec<f64>>,
    /// Number of sweeps performed.
    pub sweeps: usize,
    /// Final off-diagonal Frobenius norm (convergence indicator).
    pub final_off_norm: f64,
}

/// Full eigendecomposition of a symmetric matrix using MPFR Jacobi rotations.
///
/// # Arguments
/// * `mat` — flat row-major symmetric matrix (dim×dim) in f64
/// * `dim` — matrix dimension
/// * `prec` — MPFR precision in bits (e.g. 256, 512, 1024)
///
/// # Returns
/// `JacobiResult` with eigenvalues (ascending) and eigenvectors.
///
/// # Complexity
/// O(dim² × sweeps × dim) where sweeps ≈ 5-20 typically.
/// At dim=3000, prec=256: ~5-15 minutes.
/// At dim=3000, prec=1024: ~20-60 minutes.
pub fn eigen_jacobi_mpfr(mat: &[f64], dim: usize, prec: u32) -> JacobiResult {
    if dim == 0 {
        return JacobiResult {
            eigenvalues: vec![],
            eigenvectors: vec![],
            sweeps: 0,
            final_off_norm: 0.0,
        };
    }
    if dim == 1 {
        return JacobiResult {
            eigenvalues: vec![mat[0]],
            eigenvectors: vec![vec![1.0]],
            sweeps: 0,
            final_off_norm: 0.0,
        };
    }

    let p = prec;

    // ── Convert f64 matrix to MPFR ──────────────────────────────
    eprintln!("    [MPFR Jacobi] Converting {dim}×{dim} matrix to {p}-bit MPFR...");
    let mut a: Vec<Float> = mat.iter().map(|&v| Float::with_val(p, v)).collect();

    // ── Initialize eigenvector accumulator as identity ───────────
    // V starts as I; each rotation R is accumulated: V ← V · R
    let mut eigvecs: Vec<Float> = (0..dim * dim)
        .map(|idx| {
            let r = idx / dim;
            let c = idx % dim;
            if r == c {
                Float::with_val(p, 1.0)
            } else {
                Float::with_val(p, 0.0)
            }
        })
        .collect();

    let max_sweeps = 200;
    let tol = Float::with_val(p, Float::i_exp(1, -(p as i32 / 2)));
    let tol_sq = Float::with_val(p, &tol * &tol);

    // Scratch variables to avoid allocations in hot loop
    let mut off_norm_sq = Float::with_val(p, 0.0);
    let mut final_off_norm = 0.0f64;
    let mut sweep_count = 0usize;

    for sweep in 0..max_sweeps {
        // ── Compute off-diagonal Frobenius norm² ────────────────
        off_norm_sq.assign(0.0);
        for i in 0..dim {
            for j in (i + 1)..dim {
                let v = &a[i * dim + j];
                off_norm_sq += Float::with_val(p, v * v);
            }
        }
        final_off_norm = off_norm_sq.to_f64().sqrt();

        if off_norm_sq < tol_sq {
            eprintln!("    [MPFR Jacobi] Converged at sweep {sweep}: off-diag norm = {final_off_norm:.3e}");
            break;
        }

        if sweep % 5 == 0 || sweep < 3 {
            eprintln!("    [MPFR Jacobi] Sweep {sweep}: off-diag Frobenius = {final_off_norm:.6e}");
        }

        // ── Threshold for skipping near-zero elements ───────────
        let thresh = Float::with_val(p, &off_norm_sq / (dim * dim) as u64).sqrt();

        // ── Cyclic sweep over all (p, q) pairs ──────────────────
        for pp in 0..dim {
            for qq in (pp + 1)..dim {
                let apq_abs = a[pp * dim + qq].clone().abs();
                if apq_abs < thresh {
                    continue;
                }

                let app = a[pp * dim + pp].clone();
                let aqq = a[qq * dim + qq].clone();
                let apq = a[pp * dim + qq].clone();

                // ── Compute rotation (c, s) ─────────────────────
                let diff = Float::with_val(p, &app - &aqq);
                let (c, s) = if diff.clone().abs()
                    < Float::with_val(p, Float::i_exp(1, -(p as i32 * 3 / 4)))
                {
                    // θ ≈ π/4
                    let half = Float::with_val(p, 0.5f64);
                    let sqrt2_inv = Float::with_val(p, half.sqrt_ref());
                    (sqrt2_inv.clone(), sqrt2_inv)
                } else {
                    let tau = Float::with_val(p, 2.0) * &apq / &diff;
                    let theta: Float = Float::with_val(p, tau.atan_ref());
                    let half_theta: Float = theta / 2u32;
                    let cos_t = Float::with_val(p, half_theta.cos_ref());
                    let sin_t = Float::with_val(p, half_theta.sin_ref());
                    (cos_t, sin_t)
                };

                // ── Apply rotation to matrix A ──────────────────
                // Save old columns pp, qq
                let mut old_ip: Vec<Float> = Vec::with_capacity(dim);
                let mut old_iq: Vec<Float> = Vec::with_capacity(dim);
                for i in 0..dim {
                    old_ip.push(a[i * dim + pp].clone());
                    old_iq.push(a[i * dim + qq].clone());
                }

                for i in 0..dim {
                    if i != pp && i != qq {
                        let new_ip = Float::with_val(p, &c * &old_ip[i])
                            + Float::with_val(p, &s * &old_iq[i]);
                        let new_iq = Float::with_val(p, &c * &old_iq[i])
                            - Float::with_val(p, &s * &old_ip[i]);
                        a[i * dim + pp] = new_ip.clone();
                        a[pp * dim + i] = new_ip;
                        a[i * dim + qq] = new_iq.clone();
                        a[qq * dim + i] = new_iq;
                    }
                }

                // Update diagonal entries
                let c2 = Float::with_val(p, &c * &c);
                let s2 = Float::with_val(p, &s * &s);
                let cs2 = Float::with_val(p, 2.0) * &c * &s * &apq;

                a[pp * dim + pp] =
                    Float::with_val(p, &c2 * &app) + &cs2 + Float::with_val(p, &s2 * &aqq);
                a[qq * dim + qq] =
                    Float::with_val(p, &s2 * &app) - &cs2 + Float::with_val(p, &c2 * &aqq);
                a[pp * dim + qq] = Float::with_val(p, 0.0);
                a[qq * dim + pp] = Float::with_val(p, 0.0);

                // ── Accumulate rotation into eigenvectors ────────
                // V[:, pp] ← c·V[:, pp] + s·V[:, qq]
                // V[:, qq] ← -s·V[:, pp] + c·V[:, qq]
                for i in 0..dim {
                    let vp = eigvecs[i * dim + pp].clone();
                    let vq = eigvecs[i * dim + qq].clone();
                    eigvecs[i * dim + pp] =
                        Float::with_val(p, &c * &vp) + Float::with_val(p, &s * &vq);
                    eigvecs[i * dim + qq] =
                        Float::with_val(p, &c * &vq) - Float::with_val(p, &s * &vp);
                }
            }
        }

        sweep_count = sweep + 1;
    }

    // ── Extract eigenvalues (diagonal) and eigenvectors ─────────
    let mut indexed: Vec<(f64, usize)> = (0..dim).map(|i| (a[i * dim + i].to_f64(), i)).collect();
    indexed.sort_by(|a, b| a.0.partial_cmp(&b.0).unwrap());

    let eigenvalues: Vec<f64> = indexed.iter().map(|(v, _)| *v).collect();
    let eigenvectors: Vec<Vec<f64>> = indexed
        .iter()
        .map(|(_, idx)| (0..dim).map(|i| eigvecs[i * dim + idx].to_f64()).collect())
        .collect();

    eprintln!(
        "    [MPFR Jacobi] Done: {} sweeps, off-diag = {:.3e}, λ_min = {:.6e}, λ_max = {:.6e}",
        sweep_count,
        final_off_norm,
        eigenvalues[0],
        eigenvalues.last().unwrap_or(&0.0)
    );

    JacobiResult {
        eigenvalues,
        eigenvectors,
        sweeps: sweep_count,
        final_off_norm,
    }
}

/// Eigenvalues-only variant (no eigenvector accumulation — ~2x faster).
///
/// Use this when you only need eigenvalues for λ_min certification.
pub fn eigenvalues_only_jacobi_mpfr(mat: &[f64], dim: usize, prec: u32) -> Vec<f64> {
    if dim == 0 {
        return vec![];
    }
    if dim == 1 {
        return vec![mat[0]];
    }

    let p = prec;
    let mut a: Vec<Float> = mat.iter().map(|&v| Float::with_val(p, v)).collect();

    let max_sweeps = 200;
    let tol_sq = Float::with_val(p, Float::i_exp(1, -(p as i32)));
    let mut off_norm_sq = Float::with_val(p, 0.0);

    for sweep in 0..max_sweeps {
        off_norm_sq.assign(0.0);
        for i in 0..dim {
            for j in (i + 1)..dim {
                let v = &a[i * dim + j];
                off_norm_sq += Float::with_val(p, v * v);
            }
        }

        if off_norm_sq < tol_sq {
            break;
        }

        let thresh = Float::with_val(p, &off_norm_sq / (dim * dim) as u64).sqrt();

        if sweep % 10 == 0 {
            eprintln!(
                "    [Jacobi vals-only] Sweep {sweep}: off-diag = {:.6e}",
                off_norm_sq.to_f64().sqrt()
            );
        }

        for pp in 0..dim {
            for qq in (pp + 1)..dim {
                let apq_abs = a[pp * dim + qq].clone().abs();
                if apq_abs < thresh {
                    continue;
                }

                let app = a[pp * dim + pp].clone();
                let aqq = a[qq * dim + qq].clone();
                let apq = a[pp * dim + qq].clone();

                let diff = Float::with_val(p, &app - &aqq);
                let (c, s) = if diff.clone().abs()
                    < Float::with_val(p, Float::i_exp(1, -(p as i32 * 3 / 4)))
                {
                    let half = Float::with_val(p, 0.5f64);
                    let sqrt2_inv = Float::with_val(p, half.sqrt_ref());
                    (sqrt2_inv.clone(), sqrt2_inv)
                } else {
                    let tau = Float::with_val(p, 2.0) * &apq / &diff;
                    let theta: Float = Float::with_val(p, tau.atan_ref());
                    let half_theta: Float = theta / 2u32;
                    (
                        Float::with_val(p, half_theta.cos_ref()),
                        Float::with_val(p, half_theta.sin_ref()),
                    )
                };

                let old_ip: Vec<Float> = (0..dim).map(|i| a[i * dim + pp].clone()).collect();
                let old_iq: Vec<Float> = (0..dim).map(|i| a[i * dim + qq].clone()).collect();

                for i in 0..dim {
                    if i != pp && i != qq {
                        let new_ip = Float::with_val(p, &c * &old_ip[i])
                            + Float::with_val(p, &s * &old_iq[i]);
                        let new_iq = Float::with_val(p, &c * &old_iq[i])
                            - Float::with_val(p, &s * &old_ip[i]);
                        a[i * dim + pp] = new_ip.clone();
                        a[pp * dim + i] = new_ip;
                        a[i * dim + qq] = new_iq.clone();
                        a[qq * dim + i] = new_iq;
                    }
                }

                let c2 = Float::with_val(p, &c * &c);
                let s2 = Float::with_val(p, &s * &s);
                let cs2 = Float::with_val(p, 2.0) * &c * &s * &apq;

                a[pp * dim + pp] =
                    Float::with_val(p, &c2 * &app) + &cs2 + Float::with_val(p, &s2 * &aqq);
                a[qq * dim + qq] =
                    Float::with_val(p, &s2 * &app) - &cs2 + Float::with_val(p, &c2 * &aqq);
                a[pp * dim + qq] = Float::with_val(p, 0.0);
                a[qq * dim + pp] = Float::with_val(p, 0.0);
            }
        }
    }

    let mut eigs: Vec<f64> = (0..dim).map(|i| a[i * dim + i].to_f64()).collect();
    eigs.sort_by(|a, b| a.partial_cmp(b).unwrap());
    eigs
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_identity_2x2() {
        let mat = vec![1.0, 0.0, 0.0, 1.0];
        let result = eigen_jacobi_mpfr(&mat, 2, 128);
        assert_eq!(result.eigenvalues.len(), 2);
        assert!((result.eigenvalues[0] - 1.0).abs() < 1e-10);
        assert!((result.eigenvalues[1] - 1.0).abs() < 1e-10);
    }

    #[test]
    fn test_simple_symmetric() {
        // [2 1; 1 3] → eigenvalues (5±√5)/2 ≈ 1.382, 3.618
        let mat = vec![2.0, 1.0, 1.0, 3.0];
        let result = eigen_jacobi_mpfr(&mat, 2, 256);
        let expected_min = (5.0 - 5.0f64.sqrt()) / 2.0;
        let expected_max = (5.0 + 5.0f64.sqrt()) / 2.0;
        assert!((result.eigenvalues[0] - expected_min).abs() < 1e-12);
        assert!((result.eigenvalues[1] - expected_max).abs() < 1e-12);
        assert_eq!(result.eigenvectors.len(), 2);
    }
}
