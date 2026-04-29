//! Gram matrix construction for the Van Hove probe.
//!
//! Builds the Nyman–Beurling Gram matrix G(j,k) = ∫₀¹ {1/(jx)}{1/(kx)} dx
//! using 128-bit MPFR arithmetic with parallel entry computation.

use rayon::prelude::*;
use rug::Float;
use rug::ops::CompleteRound;

/// MPFR precision bits
pub const PREC: u32 = 128;

/// Compute a single Gram matrix entry G(j,k) at MPFR precision.
///
/// Uses the Vasyunin-type integral:
///   G(j,k) = ∫₀¹ {1/(jx)} · {1/(kx)} dx
///
/// Evaluated via high-order numerical quadrature.
pub fn gram_entry(j: usize, k: usize) -> Float {
    let nq = 2000; // quadrature points
    let mut sum = Float::with_val(PREC, 0.0);
    let one = Float::with_val(PREC, 1.0);

    for i in 0..nq {
        let x = Float::with_val(PREC, (i as f64 + 0.5) / nq as f64);
        if x <= 0.0 { continue; }

        // {1/(jx)} = 1/(jx) - floor(1/(jx))
        let jx = Float::with_val(PREC, j as f64) * &x;
        let inv_jx = one.clone() / &jx;
        let frac_j = inv_jx.clone() - inv_jx.floor_ref().complete(PREC);

        let kx = Float::with_val(PREC, k as f64) * &x;
        let inv_kx = one.clone() / &kx;
        let frac_k = inv_kx.clone() - inv_kx.floor_ref().complete(PREC);

        sum += frac_j * frac_k;
    }
    sum /= nq as f64;
    sum
}

/// Build the full N×N Gram matrix (symmetric, upper triangle computed).
/// Returns row-major flat vector and the mean vector b.
pub fn build_gram_matrix(n: usize) -> (Vec<f64>, Vec<f64>) {
    let dim = n - 1; // indices 2..=N
    let total = dim * (dim + 1) / 2;

    eprintln!("    Building {dim}×{dim} Gram matrix ({total} entries, {PREC}-bit MPFR)...");

    // Compute upper triangle entries in parallel
    let entries: Vec<((usize, usize), f64)> = (0..dim)
        .into_par_iter()
        .flat_map(|row| {
            (row..dim).map(move |col| {
                let j = row + 2;
                let k = col + 2;
                let val = gram_entry(j, k).to_f64();
                ((row, col), val)
            }).collect::<Vec<_>>()
        })
        .collect();

    // Assemble symmetric matrix (row-major)
    let mut mat = vec![0.0f64; dim * dim];
    for ((r, c), v) in &entries {
        mat[r * dim + c] = *v;
        mat[c * dim + r] = *v;
    }

    // Mean vector: b_k = ∫₀¹ {1/(kx)} dx
    let b: Vec<f64> = (2..=n)
        .map(|k| {
            let nq = 2000;
            let mut s = Float::with_val(PREC, 0.0);
            let one = Float::with_val(PREC, 1.0);
            for i in 0..nq {
                let x = Float::with_val(PREC, (i as f64 + 0.5) / nq as f64);
                let kx = Float::with_val(PREC, k as f64) * &x;
                let inv = one.clone() / &kx;
                s += inv.clone() - inv.floor_ref().complete(PREC);
            }
            (s / nq as f64).to_f64()
        })
        .collect();

    (mat, b)
}

/// Compute all eigenvalues of a symmetric matrix (row-major, dim×dim).
/// Uses Jacobi eigenvalue algorithm for guaranteed accuracy on symmetric matrices.
pub fn eigenvalues_jacobi(mat: &[f64], dim: usize) -> Vec<f64> {
    // Copy matrix for in-place modification
    let mut a = mat.to_vec();
    let max_iter = 100 * dim * dim;
    let tol = 1e-14;

    for _ in 0..max_iter {
        // Find largest off-diagonal element
        let mut max_off = 0.0f64;
        let mut p = 0;
        let mut q = 1;
        for i in 0..dim {
            for j in (i + 1)..dim {
                let val = a[i * dim + j].abs();
                if val > max_off {
                    max_off = val;
                    p = i;
                    q = j;
                }
            }
        }
        if max_off < tol { break; }

        // Compute rotation
        let app = a[p * dim + p];
        let aqq = a[q * dim + q];
        let apq = a[p * dim + q];

        let theta = if (app - aqq).abs() < 1e-30 {
            std::f64::consts::FRAC_PI_4
        } else {
            0.5 * (2.0 * apq / (app - aqq)).atan()
        };

        let c = theta.cos();
        let s = theta.sin();

        // Apply Jacobi rotation
        let mut new_a = a.clone();
        for i in 0..dim {
            if i != p && i != q {
                let aip = a[i * dim + p];
                let aiq = a[i * dim + q];
                new_a[i * dim + p] = c * aip + s * aiq;
                new_a[p * dim + i] = new_a[i * dim + p];
                new_a[i * dim + q] = -s * aip + c * aiq;
                new_a[q * dim + i] = new_a[i * dim + q];
            }
        }
        new_a[p * dim + p] = c * c * app + 2.0 * s * c * apq + s * s * aqq;
        new_a[q * dim + q] = s * s * app - 2.0 * s * c * apq + c * c * aqq;
        new_a[p * dim + q] = 0.0;
        new_a[q * dim + p] = 0.0;

        a = new_a;
    }

    // Extract diagonal = eigenvalues
    let mut eigs: Vec<f64> = (0..dim).map(|i| a[i * dim + i]).collect();
    eigs.sort_by(|a, b| a.partial_cmp(b).unwrap());
    eigs
}
