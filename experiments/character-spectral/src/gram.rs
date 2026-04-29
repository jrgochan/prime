//! Gram matrix construction, channel projection, and eigenvalue extraction.
//!
//! Builds the Nyman–Beurling Gram matrix G(j,k) using the exact Vasyunin
//! sum expansion in 128-bit MPFR. Projects to character sub-matrices and
//! extracts eigenvalues via MPFR Jacobi rotation.

use rayon::prelude::*;
use rug::Float;
use rug::ops::CompleteRound;

/// MPFR precision bits
pub const PREC: u32 = 128;

/// GCD helper
fn gcd(a: usize, b: usize) -> usize {
    if b == 0 { a } else { gcd(b, a % b) }
}

/// Compute a single Gram matrix entry G(j,k) using the exact Vasyunin formula.
pub fn gram_entry(j: usize, k: usize) -> Float {
    let jf = Float::with_val(PREC, j as u64);
    let kf = Float::with_val(PREC, k as u64);
    let jk = Float::with_val(PREC, &jf * &kf);
    let inv_jk = Float::with_val(PREC, Float::with_val(PREC, 1u32) / &jk);

    let lcm_jk = j / gcd(j, k) * k;
    let t_direct = (lcm_jk * 3).max(2_000).min(200_000);

    let mut total = Float::with_val(PREC, 0u32);

    for n in 1..=t_direct {
        let nf = Float::with_val(PREC, n as u64);
        let a_int = n / j;
        let b_int = n / k;
        let a = Float::with_val(PREC, a_int as u64);
        let b = Float::with_val(PREC, b_int as u64);

        let inv_n = Float::with_val(PREC, Float::with_val(PREC, 1u32) / &nf);
        let ln_term = Float::with_val(PREC, inv_n.ln_1p());

        let ab_coeff =
            Float::with_val(PREC, &a / &kf) + Float::with_val(PREC, &b / &jf);

        let n_plus_1 = Float::with_val(PREC, &nf + 1u32);
        let ab_frac = if a_int > 0 && b_int > 0 {
            Float::with_val(PREC, &a * &b) / Float::with_val(PREC, &nf * &n_plus_1)
        } else {
            Float::with_val(PREC, 0u32)
        };

        let piece =
            Float::with_val(PREC, &inv_jk - Float::with_val(PREC, &ab_coeff * &ln_term))
                + &ab_frac;
        total += piece;
    }

    // Tail correction
    let d = Float::with_val(PREC, gcd(j, k) as u64);
    let twelve_jk = Float::with_val(PREC, 12u32) * &jk;
    let tail_mean =
        Float::with_val(PREC, 0.25f64) + Float::with_val(PREC, &d * &d) / &twelve_jk;
    let t_f = Float::with_val(PREC, t_direct as u64);
    let tail1 = Float::with_val(PREC, &tail_mean / &t_f);
    let tail2 = Float::with_val(PREC, &tail_mean / Float::with_val(PREC, 2u32))
        / Float::with_val(PREC, &t_f * &t_f);
    total += tail1;
    total += tail2;
    total
}

/// Build the full Gram matrix in MPFR. Indices 2..=n, stored as flat row-major.
/// Returns (matrix, dim) where dim = n-1.
pub fn build_gram_matrix_mpfr(n: usize) -> (Vec<Float>, usize) {
    let dim = n - 1;
    let total = dim * (dim + 1) / 2;

    eprintln!(
        "    Building {dim}×{dim} Gram matrix ({total} entries, {PREC}-bit MPFR)..."
    );

    // Compute upper triangle entries in parallel
    let entries: Vec<((usize, usize), Float)> = (0..dim)
        .into_par_iter()
        .flat_map(|row| {
            (row..dim)
                .map(move |col| {
                    let j = row + 2;
                    let k = col + 2;
                    let val = gram_entry(j, k);
                    ((row, col), val)
                })
                .collect::<Vec<_>>()
        })
        .collect();

    // Assemble symmetric matrix (row-major, MPFR)
    let mut mat: Vec<Float> = (0..dim * dim)
        .map(|_| Float::with_val(PREC, 0.0))
        .collect();

    for ((r, c), v) in entries {
        mat[c * dim + r] = v.clone();
        mat[r * dim + c] = v;
    }

    (mat, dim)
}

/// Project the full Gram matrix to a sub-matrix on the given index set.
///
/// `indices` are the actual values (e.g. k=3,5,7,...), not offsets.
/// The full matrix has row/col for k=2..=n, so k maps to offset k-2.
pub fn project_gram(full_mat: &[Float], full_dim: usize, indices: &[usize]) -> Vec<Float> {
    let sub_dim = indices.len();
    let mut sub: Vec<Float> = (0..sub_dim * sub_dim)
        .map(|_| Float::with_val(PREC, 0.0))
        .collect();

    for (si, &ki) in indices.iter().enumerate() {
        let ri = ki - 2; // offset into full matrix
        for (sj, &kj) in indices.iter().enumerate() {
            let rj = kj - 2;
            sub[si * sub_dim + sj] = full_mat[ri * full_dim + rj].clone();
        }
    }

    sub
}

/// Character-WEIGHTED Gram projection: G_χ(j,k) = χ(j) · G(j,k) · χ(k).
///
/// Unlike `project_gram` which only selects indices, this multiplies each entry
/// by the character values at both row and column indices. Since χ(k) ∈ {-1, 0, 1},
/// this flips signs of off-diagonal elements, creating genuinely different spectral
/// structures per character channel.
///
/// The resulting matrix is still real symmetric (since χ is real-valued).
pub fn project_gram_weighted(
    full_mat: &[Float],
    full_dim: usize,
    indices: &[usize],
    chi_fn: &dyn Fn(usize) -> i8,
) -> Vec<Float> {
    let sub_dim = indices.len();
    let mut sub: Vec<Float> = (0..sub_dim * sub_dim)
        .map(|_| Float::with_val(PREC, 0.0))
        .collect();

    for (si, &ki) in indices.iter().enumerate() {
        let ri = ki - 2;
        let ci = chi_fn(ki) as f64; // χ(j)
        for (sj, &kj) in indices.iter().enumerate() {
            let rj = kj - 2;
            let cj = chi_fn(kj) as f64; // χ(k)
            let mut val = full_mat[ri * full_dim + rj].clone();
            val *= ci * cj; // G_χ(j,k) = χ(j) · G(j,k) · χ(k)
            sub[si * sub_dim + sj] = val;
        }
    }

    sub
}


/// Jacobi eigenvalue algorithm in MPFR arithmetic.
pub fn eigenvalues_jacobi_mpfr(mat: &[Float], dim: usize) -> Vec<f64> {
    if dim == 0 {
        return vec![];
    }
    if dim == 1 {
        return vec![mat[0].to_f64()];
    }

    let mut a: Vec<Float> = mat.to_vec();
    let max_iter = 200 * dim * dim;
    let tol = Float::with_val(PREC, 1e-30);

    for _sweep in 0..max_iter {
        // Find largest off-diagonal element
        let mut max_off = Float::with_val(PREC, 0.0);
        let mut p = 0usize;
        let mut q = 1usize;

        for i in 0..dim {
            for j in (i + 1)..dim {
                let val = a[i * dim + j].clone().abs();
                if val > max_off {
                    max_off = val;
                    p = i;
                    q = j;
                }
            }
        }

        if max_off < tol {
            break;
        }

        // Compute Jacobi rotation angle
        let app = a[p * dim + p].clone();
        let aqq = a[q * dim + q].clone();
        let apq = a[p * dim + q].clone();

        let diff = Float::with_val(PREC, &app - &aqq);
        let (c, s): (Float, Float) = if diff.clone().abs() < Float::with_val(PREC, 1e-60)
        {
            let half = Float::with_val(PREC, 0.5f64);
            let sqrt2_inv = Float::with_val(PREC, half.sqrt_ref());
            (sqrt2_inv.clone(), sqrt2_inv)
        } else {
            let tau = Float::with_val(PREC, 2.0) * &apq / &diff;
            let theta: Float = Float::with_val(PREC, tau.atan_ref());
            let half_theta: Float = theta / 2u32;
            let cos_t = Float::with_val(PREC, half_theta.cos_ref());
            let sin_t = Float::with_val(PREC, half_theta.sin_ref());
            (cos_t, sin_t)
        };

        // Save old values for rotation
        let mut old_ip: Vec<Float> = Vec::with_capacity(dim);
        let mut old_iq: Vec<Float> = Vec::with_capacity(dim);
        for i in 0..dim {
            old_ip.push(a[i * dim + p].clone());
            old_iq.push(a[i * dim + q].clone());
        }

        for i in 0..dim {
            if i != p && i != q {
                let new_ip = Float::with_val(PREC, &c * &old_ip[i])
                    + Float::with_val(PREC, &s * &old_iq[i]);
                let new_iq = Float::with_val(PREC, &c * &old_iq[i])
                    - Float::with_val(PREC, &s * &old_ip[i]);
                a[i * dim + p] = new_ip.clone();
                a[p * dim + i] = new_ip;
                a[i * dim + q] = new_iq.clone();
                a[q * dim + i] = new_iq;
            }
        }

        let c2 = Float::with_val(PREC, &c * &c);
        let s2 = Float::with_val(PREC, &s * &s);
        let cs2 = Float::with_val(PREC, 2.0) * &c * &s * &apq;

        a[p * dim + p] =
            Float::with_val(PREC, &c2 * &app) + &cs2 + Float::with_val(PREC, &s2 * &aqq);
        a[q * dim + q] =
            Float::with_val(PREC, &s2 * &app) - &cs2 + Float::with_val(PREC, &c2 * &aqq);
        a[p * dim + q] = Float::with_val(PREC, 0.0);
        a[q * dim + p] = Float::with_val(PREC, 0.0);
    }

    let mut eigs: Vec<f64> = (0..dim).map(|i| a[i * dim + i].to_f64()).collect();
    eigs.sort_by(|a, b| a.partial_cmp(b).unwrap());
    eigs
}
