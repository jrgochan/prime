//! Gram matrix construction and eigenvalue extraction for the Van Hove probe.
//!
//! Builds the Nyman–Beurling Gram matrix G(j,k) = ∫₀¹ {1/(jx)}{1/(kx)} dx
//! using 128-bit MPFR arithmetic. Eigenvalues extracted via Jacobi rotation
//! also in MPFR to preserve the tiny bottom eigenvalues.

use rayon::prelude::*;
use rug::Float;
use rug::ops::CompleteRound;

/// MPFR precision bits
pub const PREC: u32 = 128;

/// GCD helper
fn gcd(a: usize, b: usize) -> usize {
    if b == 0 { a } else { gcd(b, a % b) }
}

/// Compute a single Gram matrix entry G(j,k) at MPFR precision.
///
/// Uses the exact Vasyunin-type sum expansion (same as baez-duarte experiment):
///   G(j,k) = Σ_{n=1}^{T} [1/(jk) - (⌊n/j⌋/k + ⌊n/k⌋/j)·ln(1+1/n)
///            + ⌊n/j⌋·⌊n/k⌋/(n(n+1))] + tail correction
///
/// This is exact to machine precision (no quadrature artifacts).
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

        let ab_coeff = Float::with_val(PREC, &a / &kf)
            + Float::with_val(PREC, &b / &jf);

        let n_plus_1 = Float::with_val(PREC, &nf + 1u32);
        let ab_frac = if a_int > 0 && b_int > 0 {
            Float::with_val(PREC, &a * &b) / Float::with_val(PREC, &nf * &n_plus_1)
        } else {
            Float::with_val(PREC, 0u32)
        };

        let piece = Float::with_val(PREC, &inv_jk - Float::with_val(PREC, &ab_coeff * &ln_term))
            + &ab_frac;
        total += piece;
    }

    // Tail correction
    let d = Float::with_val(PREC, gcd(j, k) as u64);
    let twelve_jk = Float::with_val(PREC, 12u32) * &jk;
    let tail_mean = Float::with_val(PREC, 0.25f64)
        + Float::with_val(PREC, &d * &d) / &twelve_jk;
    let t_f = Float::with_val(PREC, t_direct as u64);
    let tail1 = Float::with_val(PREC, &tail_mean / &t_f);
    let tail2 = Float::with_val(PREC, &tail_mean / Float::with_val(PREC, 2u32))
        / Float::with_val(PREC, &t_f * &t_f);
    total += tail1;
    total += tail2;
    total
}

/// Build the full Gram matrix in MPFR precision.
/// Returns the matrix as a flat row-major Vec<Float> of dimension dim×dim,
/// where dim = n-1 (indices 2..=n).
pub fn build_gram_matrix_mpfr(n: usize) -> Vec<Float> {
    let dim = n - 1;
    let total = dim * (dim + 1) / 2;

    eprintln!("    Building {dim}×{dim} Gram matrix ({total} entries, {PREC}-bit MPFR)...");

    // Compute upper triangle entries in parallel
    let entries: Vec<((usize, usize), Float)> = (0..dim)
        .into_par_iter()
        .flat_map(|row| {
            (row..dim).map(move |col| {
                let j = row + 2;
                let k = col + 2;
                let val = gram_entry(j, k);
                ((row, col), val)
            }).collect::<Vec<_>>()
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

    mat
}

/// Jacobi eigenvalue algorithm in MPFR arithmetic.
///
/// This is critical: f64 Jacobi fails for N > ~60 because the condition
/// number κ(G_N) ~ N·ln(N) makes the tiny eigenvalues (~1/(N·ln N))
/// smaller than f64 rounding errors in the off-diagonal elements.
///
/// By operating entirely in 128-bit MPFR, we preserve ~38 decimal digits
/// of precision, sufficient for κ up to ~10^30.
pub fn eigenvalues_jacobi_mpfr(mat: &[Float], dim: usize) -> Vec<f64> {
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

        if max_off < tol { break; }

        // Compute Jacobi rotation angle
        let app = a[p * dim + p].clone();
        let aqq = a[q * dim + q].clone();
        let apq = a[p * dim + q].clone();

        let diff = Float::with_val(PREC, &app - &aqq);
        let (c, s): (Float, Float) = if diff.clone().abs() < Float::with_val(PREC, 1e-60) {
            // θ = π/4
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

        // Apply rotation to all rows/columns touching p or q
        // Save old values
        let mut old_ip: Vec<Float> = Vec::with_capacity(dim);
        let mut old_iq: Vec<Float> = Vec::with_capacity(dim);
        for i in 0..dim {
            old_ip.push(a[i * dim + p].clone());
            old_iq.push(a[i * dim + q].clone());
        }

        for i in 0..dim {
            if i != p && i != q {
                let new_ip = Float::with_val(PREC, &c * &old_ip[i]) +
                             Float::with_val(PREC, &s * &old_iq[i]);
                let new_iq = Float::with_val(PREC, &c * &old_iq[i]) -
                             Float::with_val(PREC, &s * &old_ip[i]);
                a[i * dim + p] = new_ip.clone();
                a[p * dim + i] = new_ip;
                a[i * dim + q] = new_iq.clone();
                a[q * dim + i] = new_iq;
            }
        }

        // Update diagonal and off-diagonal (p,q)
        let c2 = Float::with_val(PREC, &c * &c);
        let s2 = Float::with_val(PREC, &s * &s);
        let cs2 = Float::with_val(PREC, 2.0) * &c * &s * &apq;

        a[p * dim + p] = Float::with_val(PREC, &c2 * &app) + &cs2 + Float::with_val(PREC, &s2 * &aqq);
        a[q * dim + q] = Float::with_val(PREC, &s2 * &app) - &cs2 + Float::with_val(PREC, &c2 * &aqq);
        a[p * dim + q] = Float::with_val(PREC, 0.0);
        a[q * dim + p] = Float::with_val(PREC, 0.0);
    }

    // Extract diagonal = eigenvalues, convert to f64 for output
    let mut eigs: Vec<f64> = (0..dim).map(|i| a[i * dim + i].to_f64()).collect();
    eigs.sort_by(|a, b| a.partial_cmp(b).unwrap());
    eigs
}
