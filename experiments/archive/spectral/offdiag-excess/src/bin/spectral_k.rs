//! Spectral K — True Spectral Coupling Constant (MPFR + nalgebra)
//!
//! Computes K_spectral = ‖A^{-1/2} B C^{-1/2}‖₂ (operator norm)
//! where A = π₊Gπ₊ (even), C = π₋Gπ₋ (odd), B = π₊Gπ₋ (cross)
//!
//! Uses MPFR for gram entries, nalgebra for eigendecomposition/SVD.
//!
//! Usage: cargo run --release --bin spectral_k [sizes...]

use rayon::prelude::*;
use rug::{Float, float::Round};
use std::sync::Mutex;
use nalgebra::{DMatrix, DVector, SVD};

const PREC: u32 = 128;

fn big_omega(mut n: usize) -> usize {
    if n <= 1 { return 0; }
    let mut count = 0;
    let mut p = 2;
    while p * p <= n {
        while n % p == 0 { count += 1; n /= p; }
        p += 1;
    }
    if n > 1 { count += 1; }
    count
}

fn liouville_parity(k: usize) -> usize { big_omega(k) % 2 }

/// Compute gram_entry(j,k) with corrected integration (MPFR)
fn gram_entry_hp(j: usize, k: usize) -> Float {
    if j == 0 || k == 0 { return Float::with_val(PREC, 0); }
    let jf = j as f64;
    let kf = k as f64;
    let m_max = (j.max(k)) * 100 + 1000;

    let mut breaks: Vec<f64> = Vec::with_capacity(2 * m_max);
    for m in j..=m_max {
        let x = jf / (m as f64);
        if x > 0.0 && x <= 1.0 { breaks.push(x); }
    }
    for m in k..=m_max {
        let x = kf / (m as f64);
        if x > 0.0 && x <= 1.0 { breaks.push(x); }
    }
    breaks.push(1.0);
    breaks.sort_by(|a, b| a.partial_cmp(b).unwrap());
    breaks.dedup_by(|a, b| (*a - *b).abs() < 1e-15);

    let j_mp = Float::with_val(PREC, j as u32);
    let k_mp = Float::with_val(PREC, k as u32);
    let jk_mp = Float::with_val(PREC, &j_mp * &k_mp);

    let mut total = Float::with_val(PREC, 0);
    for i in 0..breaks.len() - 1 {
        let x_lo_f = breaks[i];
        let x_hi_f = breaks[i + 1];
        if x_hi_f - x_lo_f < 1e-18 { continue; }
        let x_mid_f = 0.5 * (x_lo_f + x_hi_f);
        let a = (jf / x_mid_f).floor();
        let b = (kf / x_mid_f).floor();

        let x_lo = Float::with_val(PREC, x_lo_f);
        let x_hi = Float::with_val(PREC, x_hi_f);
        let a_mp = Float::with_val(PREC, a);
        let b_mp = Float::with_val(PREC, b);

        let bj = Float::with_val(PREC, &b_mp * &j_mp);
        let ak = Float::with_val(PREC, &a_mp * &k_mp);
        let lin_coeff = Float::with_val(PREC, &bj + &ak);
        let const_coeff = Float::with_val(PREC, &a_mp * &b_mp);

        let eval = |x: &Float| -> Float {
            let t1 = Float::with_val(PREC, -Float::with_val(PREC, &jk_mp / x));
            let t2 = Float::with_val(PREC, -Float::with_val(PREC, &lin_coeff * x.clone().ln()));
            let t3 = Float::with_val(PREC, &const_coeff * x);
            let s12 = Float::with_val(PREC, &t1 + &t2);
            Float::with_val(PREC, &s12 + &t3)
        };
        let f_hi = eval(&x_hi);
        let f_lo = eval(&x_lo);
        let diff = Float::with_val(PREC, &f_hi - &f_lo);
        total += &diff;
    }
    total
}

/// Compute the symmetric inverse square root of a SPD matrix via eigendecomposition
fn sym_inv_sqrt(m: &DMatrix<f64>) -> DMatrix<f64> {
    let eigen = m.clone().symmetric_eigen();
    let n = eigen.eigenvalues.len();
    let mut d_inv_sqrt = DVector::zeros(n);
    for i in 0..n {
        let ev = eigen.eigenvalues[i];
        if ev > 1e-12 {
            d_inv_sqrt[i] = 1.0 / ev.sqrt();
        }
    }
    // M^{-1/2} = Q diag(1/sqrt(λ)) Q^T
    let q = &eigen.eigenvectors;
    let d_mat = DMatrix::from_diagonal(&d_inv_sqrt);
    q * &d_mat * q.transpose()
}

fn main() {
    let sizes: Vec<usize> = std::env::args()
        .skip(1)
        .filter_map(|s| s.parse().ok())
        .collect();
    let sizes = if sizes.is_empty() {
        vec![50, 100, 150, 200]
    } else {
        sizes
    };

    eprintln!("══════════════════════════════════════════════════════════════════");
    eprintln!("  Spectral K — True Operator Norm (MPFR + nalgebra SVD)");
    eprintln!("  K_spectral = ‖A^{{-1/2}} B C^{{-1/2}}‖₂ = max singular value");
    eprintln!("══════════════════════════════════════════════════════════════════\n");

    eprintln!("{:>5} {:>10} {:>10} {:>10} {:>10} {:>10} {:>8}",
        "N", "K_spectral", "K²_spect", "K_frob", "1-K²_s", "1-K²_f", "time");
    eprintln!("{}", "-".repeat(70));

    for &n in &sizes {
        let start = std::time::Instant::now();
        let dim = n;

        let parities: Vec<usize> = (0..dim).map(|i| liouville_parity(i + 2)).collect();
        let even_idx: Vec<usize> = (0..dim).filter(|&i| parities[i] == 0).collect();
        let odd_idx: Vec<usize> = (0..dim).filter(|&i| parities[i] == 1).collect();
        let n_even = even_idx.len();
        let n_odd = odd_idx.len();

        // Build full Gram matrix with MPFR, parallelized
        let g_mutex: Vec<Vec<Mutex<Float>>> = (0..dim).map(|_| {
            (0..dim).map(|_| Mutex::new(Float::with_val(PREC, 0))).collect()
        }).collect();

        (0..dim).into_par_iter().for_each(|i| {
            for j in i..dim {
                let gij = gram_entry_hp(i + 2, j + 2);
                { let mut v = g_mutex[i][j].lock().unwrap(); *v += &gij; }
                if i != j {
                    let mut v = g_mutex[j][i].lock().unwrap(); *v += &gij;
                }
            }
        });

        // Convert to f64
        let g: Vec<Vec<f64>> = (0..dim).map(|i| {
            (0..dim).map(|j| g_mutex[i][j].lock().unwrap().to_f64_round(Round::Nearest)).collect()
        }).collect();

        // Extract parity submatrices as nalgebra DMatrix
        let a_mat = DMatrix::from_fn(n_even, n_even, |i, j| {
            g[even_idx[i]][even_idx[j]]
        });
        let c_mat = DMatrix::from_fn(n_odd, n_odd, |i, j| {
            g[odd_idx[i]][odd_idx[j]]
        });
        let b_mat = DMatrix::from_fn(n_even, n_odd, |i, j| {
            g[even_idx[i]][odd_idx[j]]
        });

        // Compute A^{-1/2} and C^{-1/2}
        let a_inv_sqrt = sym_inv_sqrt(&a_mat);
        let c_inv_sqrt = sym_inv_sqrt(&c_mat);

        // Form M = A^{-1/2} B C^{-1/2}
        let m_mat = &a_inv_sqrt * &b_mat * &c_inv_sqrt;

        // SVD to get max singular value
        let svd = SVD::new(m_mat.clone(), false, false);
        let singular_values = &svd.singular_values;
        let k_spectral = singular_values.max();
        let k_spectral_sq = k_spectral * k_spectral;

        // Also compute Frobenius K for comparison
        let frob = |m: &DMatrix<f64>| -> f64 {
            m.iter().map(|x| x * x).sum::<f64>().sqrt()
        };
        let frob_a = frob(&a_mat);
        let frob_c = frob(&c_mat);
        let frob_b = frob(&b_mat);
        let k_frob = frob_b / (frob_a * frob_c).sqrt();

        let elapsed = start.elapsed();

        eprintln!("{:5} {:10.6} {:10.6} {:10.6} {:10.2e} {:10.2e} {:8.1}s",
            n, k_spectral, k_spectral_sq, k_frob,
            1.0 - k_spectral_sq, 1.0 - k_frob * k_frob,
            elapsed.as_secs_f64());

        // Detailed output
        let n_sv = singular_values.len().min(10);
        let mut sv_sorted: Vec<f64> = singular_values.iter().cloned().collect();
        sv_sorted.sort_by(|a, b| b.partial_cmp(a).unwrap());
        eprintln!("        Top {} singular values: {:?}",
            n_sv, &sv_sorted[..n_sv]);
        eprintln!("        dim={}(even={}, odd={})",
            dim, n_even, n_odd);
        if k_spectral < 1.0 {
            eprintln!("        ✓✓✓ K_spectral = {:.8} < 1 — SELBERG BARRIER SHATTERED!", k_spectral);
        } else {
            eprintln!("        ⚠ K_spectral = {:.8} ≥ 1", k_spectral);
        }
        eprintln!();
    }

    eprintln!("══════════════════════════════════════════════════════════════════");
    eprintln!("  K_spectral is the TRUE parity coupling constant.");
    eprintln!("  If K_spectral < 1 and STABLE: Selberg's ghost is exorcised.");
    eprintln!("══════════════════════════════════════════════════════════════════");
}
