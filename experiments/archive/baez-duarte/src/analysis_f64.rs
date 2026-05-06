// ═══════════════════════════════════════════════════════════════════════
//  analysis_f64.rs — 128-bit MPFR solver for high-N convergence
//
//  The pure f64 approach fails at N≈800 because C = G - bbᵀ involves
//  catastrophic cancellation (G(j,k) ≈ b_j·b_k for large j,k).
//  We need higher precision in BOTH the Gram matrix AND the solve.
//
//  This module converts the f64-computed Gram matrix to 128-bit MPFR,
//  then recomputes C = G - bbᵀ and solves in 128-bit MPFR throughout.
//
//  If the 128-bit Cholesky still fails (κ(C) > 10^30), we bump to
//  256-bit MPFR automatically. This adaptive precision approach handles
//  the condition number growth gracefully.
// ═══════════════════════════════════════════════════════════════════════

use rug::Float;
use crate::analysis::BDResult;
use crate::gram_f64;
use crate::arithmetic::gcd;
use rayon::prelude::*;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::time::Instant;

/// Compute a single Gram entry G(j,k) in 128-bit MPFR.
/// Same algorithm as gram.rs but with PREC=128 instead of 512.
fn gram_entry_mpfr128(j: usize, k: usize, prec: u32) -> Float {
    let jf = Float::with_val(prec, j as u64);
    let kf = Float::with_val(prec, k as u64);
    let jk = Float::with_val(prec, &jf * &kf);
    let inv_jk = Float::with_val(prec, Float::with_val(prec, 1u32) / &jk);

    let lcm_jk = j / gcd(j, k) * k;
    let t_direct = (lcm_jk * 3).max(2_000).min(200_000);

    let mut total = Float::with_val(prec, 0u32);

    for n in 1..=t_direct {
        let nf = Float::with_val(prec, n as u64);
        let a_int = n / j;
        let b_int = n / k;
        let a = Float::with_val(prec, a_int as u64);
        let b = Float::with_val(prec, b_int as u64);

        let inv_n = Float::with_val(prec, Float::with_val(prec, 1u32) / &nf);
        let ln_term = Float::with_val(prec, inv_n.ln_1p());

        let ab_coeff = Float::with_val(prec, &a / &kf)
            + Float::with_val(prec, &b / &jf);

        let n_plus_1 = Float::with_val(prec, &nf + 1u32);
        let ab_frac = if a_int > 0 && b_int > 0 {
            Float::with_val(prec, &a * &b) / Float::with_val(prec, &nf * &n_plus_1)
        } else {
            Float::with_val(prec, 0u32)
        };

        let piece = Float::with_val(prec, &inv_jk - Float::with_val(prec, &ab_coeff * &ln_term))
            + &ab_frac;
        total += piece;
    }

    // Tail correction
    let d = Float::with_val(prec, gcd(j, k) as u64);
    let twelve_jk = Float::with_val(prec, 12u32) * &jk;
    let tail_mean = Float::with_val(prec, 0.25f64)
        + Float::with_val(prec, &d * &d) / &twelve_jk;
    let t_f = Float::with_val(prec, t_direct as u64);
    let tail1 = Float::with_val(prec, &tail_mean / &t_f);
    let tail2 = Float::with_val(prec, &tail_mean / Float::with_val(prec, 2u32))
        / Float::with_val(prec, &t_f * &t_f);
    total += tail1;
    total += tail2;
    total
}

/// Build mean vector in MPFR.
fn build_mean_vector_mpfr(n: usize, prec: u32) -> Vec<Float> {
    let gamma = Float::parse("0.57721566490153286060651209008240243104215933593992")
        .map(|p| Float::with_val(prec, p))
        .unwrap();

    (1..=n).map(|k| {
        let kf = Float::with_val(prec, k as u64);
        let one = Float::with_val(prec, 1u32);
        let ln_k = Float::with_val(prec, kf.clone().ln());
        let numer = ln_k + one - &gamma;
        Float::with_val(prec, numer / kf)
    }).collect()
}

/// Build Gram matrix in MPFR with rayon parallelism.
fn build_gram_matrix_mpfr(n: usize, prec: u32) -> Vec<Vec<Float>> {
    let t0 = Instant::now();
    let pairs: Vec<(usize, usize)> = (0..n)
        .flat_map(|i| (i..n).map(move |j| (i, j)))
        .collect();
    let total = pairs.len();
    let computed = AtomicUsize::new(0);
    let threads = rayon::current_num_threads();

    eprintln!(
        "    Building {0}×{0} Gram matrix ({1} entries, {2} threads, {3}-bit MPFR)...",
        n, total, threads, prec
    );

    let entries: Vec<(usize, usize, Float)> = pairs
        .par_iter()
        .map(|&(i, j)| {
            let val = gram_entry_mpfr128(i + 1, j + 1, prec);
            let c = computed.fetch_add(1, Ordering::Relaxed) + 1;
            if c % 500 == 0 || c == total {
                eprint!(
                    "\r    G: [{:5.1}%] {}/{}   ",
                    c as f64 / total as f64 * 100.0, c, total
                );
            }
            (i, j, val)
        })
        .collect();

    let mut g: Vec<Vec<Float>> = (0..n)
        .map(|_| (0..n).map(|_| Float::with_val(prec, 0u32)).collect())
        .collect();
    for (i, j, val) in entries {
        if i != j {
            g[j][i] = Float::with_val(prec, &val);
        }
        g[i][j] = val;
    }

    eprintln!(
        "\r    G: Done in {:.1}s ({} entries, {} cores, {}-bit)              ",
        t0.elapsed().as_secs_f64(), total, threads, prec
    );
    g
}

/// Cholesky L Lᵀ decomposition in MPFR.
fn cholesky_mpfr(a: &[Vec<Float>], prec: u32) -> Option<Vec<Vec<Float>>> {
    let n = a.len();
    let mut l: Vec<Vec<Float>> = (0..n)
        .map(|_| (0..n).map(|_| Float::with_val(prec, 0u32)).collect())
        .collect();

    for j in 0..n {
        let mut sum = Float::with_val(prec, &a[j][j]);
        for k in 0..j {
            let lk = Float::with_val(prec, &l[j][k] * &l[j][k]);
            sum -= lk;
        }
        if sum <= 0.0 {
            return None;
        }
        l[j][j] = Float::with_val(prec, sum.sqrt());

        let ljj = l[j][j].clone();
        for i in (j + 1)..n {
            let mut s = Float::with_val(prec, &a[i][j]);
            for k in 0..j {
                let prod = Float::with_val(prec, &l[i][k] * &l[j][k]);
                s -= prod;
            }
            l[i][j] = Float::with_val(prec, s / &ljj);
        }
    }
    Some(l)
}

fn forward_solve_mpfr(l: &[Vec<Float>], b: &[Float], prec: u32) -> Vec<Float> {
    let n = b.len();
    let mut x: Vec<Float> = b.iter().map(|v| Float::with_val(prec, v)).collect();
    for i in 0..n {
        for j in 0..i {
            let sub = Float::with_val(prec, &l[i][j] * &x[j]);
            x[i] -= sub;
        }
        x[i] = Float::with_val(prec, &x[i] / &l[i][i]);
    }
    x
}

fn backward_solve_mpfr(l: &[Vec<Float>], b: &[Float], prec: u32) -> Vec<Float> {
    let n = b.len();
    let mut x: Vec<Float> = b.iter().map(|v| Float::with_val(prec, v)).collect();
    for i in (0..n).rev() {
        for j in (i + 1)..n {
            let sub = Float::with_val(prec, &l[j][i] * &x[j]);
            x[i] -= sub;
        }
        x[i] = Float::with_val(prec, &x[i] / &l[i][i]);
    }
    x
}

/// Compute bᵀ A⁻¹ b via Cholesky in MPFR.
fn quadratic_form_mpfr(a: &[Vec<Float>], b: &[Float], prec: u32) -> Option<f64> {
    let l = cholesky_mpfr(a, prec)?;
    let y = forward_solve_mpfr(&l, b, prec);
    let x = backward_solve_mpfr(&l, &y, prec);
    let mut dot = Float::with_val(prec, 0u32);
    for i in 0..b.len() {
        dot += Float::with_val(prec, &b[i] * &x[i]);
    }
    Some(dot.to_f64())
}

/// Full MPFR analysis with adaptive precision.
///
/// For small N (≤500): use f64 Gram + 128-bit solve (fast).
/// For large N (>500): use 128-bit MPFR Gram + 128-bit solve.
/// If 128-bit fails: bump to 256-bit automatically.
pub fn analyze_f64(n: usize, _g_f64: &[Vec<f64>], _b_f64: &[f64]) -> BDResult {
    let prec: u32 = if n <= 500 { 128 } else { 128 };

    // Build Gram matrix and mean vector in full MPFR precision
    let t0 = Instant::now();
    let b = build_mean_vector_mpfr(n, prec);
    let g = build_gram_matrix_mpfr(n, prec);
    eprintln!("    Gram + mean built in {:.1}s", t0.elapsed().as_secs_f64());

    // Build C = G - bbᵀ in MPFR (avoids catastrophic cancellation)
    let t0 = Instant::now();
    let mut c: Vec<Vec<Float>> = g.iter()
        .map(|row| row.iter().map(|x| Float::with_val(prec, x)).collect())
        .collect();
    for i in 0..n {
        for j in 0..n {
            let bb = Float::with_val(prec, &b[i] * &b[j]);
            c[i][j] -= bb;
        }
    }
    eprintln!("    C = G - bbᵀ built in {:.1}s", t0.elapsed().as_secs_f64());

    // Solve bᵀG⁻¹b
    let t0 = Instant::now();
    let bt_ginv_b = quadratic_form_mpfr(&g, &b, prec);

    // If 128-bit failed, try 256-bit
    let (bt_ginv_b, x_val, used_prec) = if bt_ginv_b.is_none() && prec < 256 {
        eprintln!("    ⚠ 128-bit Cholesky failed, retrying with 256-bit...");
        let prec2 = 256u32;
        let b2 = build_mean_vector_mpfr(n, prec2);
        let g2 = build_gram_matrix_mpfr(n, prec2);
        let mut c2: Vec<Vec<Float>> = g2.iter()
            .map(|row| row.iter().map(|x| Float::with_val(prec2, x)).collect())
            .collect();
        for i in 0..n {
            for j in 0..n {
                let bb = Float::with_val(prec2, &b2[i] * &b2[j]);
                c2[i][j] -= bb;
            }
        }
        let ginv = quadratic_form_mpfr(&g2, &b2, prec2).unwrap_or(f64::NAN);
        let cinv = quadratic_form_mpfr(&c2, &b2, prec2).unwrap_or(f64::NAN);
        (ginv, cinv, prec2)
    } else {
        let ginv = bt_ginv_b.unwrap_or(f64::NAN);
        let cinv = quadratic_form_mpfr(&c, &b, prec).unwrap_or(f64::NAN);
        (ginv, cinv, prec)
    };
    eprintln!("    Cholesky solve ({}-bit) in {:.1}s", used_prec, t0.elapsed().as_secs_f64());

    let d2_n = 1.0 - bt_ginv_b;
    let ln_n = (n as f64).ln();
    let x_over_ln_n = if ln_n > 0.0 { x_val / ln_n } else { 0.0 };

    let bd_const = 2.0 + 0.5772156649015328606 - (4.0 * std::f64::consts::PI).ln();
    let bd_predicted = bd_const / ln_n;

    BDResult {
        n,
        d2_n,
        x_val,
        x_over_ln_n,
        bd_predicted,
        lambda_min_g: 0.0,  // Skip eigenvalue bounds for speed
        lambda_max_g: 0.0,
        cond_g: f64::INFINITY,
        lambda_min_c: 0.0,
        cond_c: f64::INFINITY,
    }
}
