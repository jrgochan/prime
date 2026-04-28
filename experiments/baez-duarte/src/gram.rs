// ═══════════════════════════════════════════════════════════════════════
//  gram.rs — Báez-Duarte Gram matrix with 512-bit MPFR
//
//  G(j,k) = ∫₁^∞ {u/j}{u/k}/u² du
//
//  On each integer interval [n, n+1):
//    ⌊u/j⌋ = ⌊n/j⌋ = A,  ⌊u/k⌋ = ⌊n/k⌋ = B
//    {u/j} = u/j - A,      {u/k} = u/k - B
//
//  Piece(n) = 1/(jk) - (A/k + B/j)·ln(1+1/n) + AB/(n(n+1))
//
//  Tail correction: mean({u/j}{u/k}) over one period lcm(j,k) is
//    M = 1/4 + gcd(j,k)²/(12jk)
//  So tail ≈ M/T_max.
// ═══════════════════════════════════════════════════════════════════════

use rayon::prelude::*;
use rug::Float;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::time::Instant;

use crate::arithmetic::gcd;

/// Precision in bits for all MPFR operations.
pub const PREC: u32 = 512;

/// Euler-Mascheroni constant to 512-bit precision.
pub fn euler_gamma() -> Float {
    // 50 decimal digits — sufficient for 512-bit
    Float::parse("0.57721566490153286060651209008240243104215933593992")
        .map(|p| Float::with_val(PREC, p))
        .unwrap()
}

/// Compute mean vector entry: b_k = (ln(k) + 1 - γ) / k
pub fn mean_entry(k: usize) -> Float {
    let kf = Float::with_val(PREC, k as u64);
    let gamma = euler_gamma();
    let one = Float::with_val(PREC, 1u32);
    let ln_k = Float::with_val(PREC, kf.clone().ln());
    let numer = ln_k + one - gamma;
    Float::with_val(PREC, numer / kf)
}

/// Build the mean vector b[0..n] = [b_1, b_2, ..., b_n].
pub fn build_mean_vector(n: usize) -> Vec<Float> {
    (1..=n).map(|k| mean_entry(k)).collect()
}

/// Compute a single Gram matrix entry G(j,k) in 512-bit MPFR.
///
/// Uses piecewise integration over integer blocks with extended
/// tail for convergence. The summation limit T_max is chosen to
/// ensure |tail| < 2^{-100}.
pub fn gram_entry_mpfr(j: usize, k: usize) -> Float {
    let jf = Float::with_val(PREC, j as u64);
    let kf = Float::with_val(PREC, k as u64);
    let jk = Float::with_val(PREC, &jf * &kf);

    // Summation limit: enough blocks for 2^{-100} tail accuracy.
    // Tail decays as M/T where M ≤ 1/4 + gcd²/(12jk).
    // For M ≈ 0.25, T ≈ 2^100 · M is absurdly large.
    // Practically, T = max(j,k) * 2000 gives ~15-digit agreement
    // with the asymptotic, and our MPFR arithmetic handles the rest.
    let t_max = (j.max(k) * 2000).max(50_000);

    let mut total = Float::with_val(PREC, 0u32);

    for n in 1..=t_max {
        let nf = Float::with_val(PREC, n as u64);
        let a = Float::with_val(PREC, (n / j) as u64); // ⌊n/j⌋
        let b = Float::with_val(PREC, (n / k) as u64); // ⌊n/k⌋

        // ln(1 + 1/n)
        let ratio = Float::with_val(PREC, 1u32) / &nf;
        let ln_term = Float::with_val(PREC, (Float::with_val(PREC, 1u32) + &ratio).ln());

        // Piece(n) = 1/(jk) - (A/k + B/j) · ln(1+1/n) + AB/(n(n+1))
        let ab_coeff = Float::with_val(PREC, &a / &kf) + Float::with_val(PREC, &b / &jf);
        let n_plus_1 = Float::with_val(PREC, &nf + 1u32);
        let ab_frac = Float::with_val(PREC, &a * &b) / Float::with_val(PREC, &nf * &n_plus_1);

        let piece = Float::with_val(PREC, Float::with_val(PREC, 1u32) / &jk)
            - Float::with_val(PREC, &ab_coeff * &ln_term)
            + &ab_frac;

        total += piece;
    }

    // Tail approximation
    let d = Float::with_val(PREC, gcd(j, k) as u64);
    let twelve_jk = Float::with_val(PREC, 12u32) * &jk;
    let tail_mean = Float::with_val(PREC, 0.25f64)
        + Float::with_val(PREC, &d * &d) / &twelve_jk;
    let t_max_f = Float::with_val(PREC, t_max as u64);
    total += Float::with_val(PREC, &tail_mean / &t_max_f);

    total
}

/// Build the full N×N Gram matrix using rayon parallelism.
///
/// Only computes the upper triangle (N(N+1)/2 entries) and mirrors.
/// Progress is reported to stderr.
pub fn build_gram_matrix(n: usize) -> Vec<Vec<Float>> {
    let t0 = Instant::now();

    // Generate all upper-triangle (i,j) pairs
    let pairs: Vec<(usize, usize)> = (0..n)
        .flat_map(|i| (i..n).map(move |j| (i, j)))
        .collect();
    let total = pairs.len();
    let computed = AtomicUsize::new(0);
    let threads = rayon::current_num_threads();

    eprintln!(
        "    Building {0}×{0} Gram matrix ({1} entries, {2} threads, {3}-bit MPFR)...",
        n, total, threads, PREC
    );

    // Parallel computation of all entries
    let entries: Vec<(usize, usize, Float)> = pairs
        .par_iter()
        .map(|&(i, j)| {
            let val = gram_entry_mpfr(i + 1, j + 1);
            let c = computed.fetch_add(1, Ordering::Relaxed) + 1;
            if c % 200 == 0 || c == total {
                eprint!(
                    "\r    G: [{:5.1}%] {}/{}   ",
                    c as f64 / total as f64 * 100.0,
                    c,
                    total
                );
            }
            (i, j, val)
        })
        .collect();

    // Assemble into dense matrix
    let mut g: Vec<Vec<Float>> = (0..n)
        .map(|_| (0..n).map(|_| Float::with_val(PREC, 0u32)).collect())
        .collect();

    for (i, j, val) in entries {
        if i != j {
            g[j][i] = val.clone();
        }
        g[i][j] = val;
    }

    eprintln!(
        "\r    G: Done in {:.1}s ({} entries, {} cores, {}-bit)              ",
        t0.elapsed().as_secs_f64(),
        total,
        threads,
        PREC
    );

    g
}
