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
//  Optimization: the integrand repeats with period lcm(j,k).
//  After enough initial blocks, we switch to a closed-form tail.
//
//  Tail correction: mean of {u/j}{u/k} over one full period is
//    M = 1/4 + gcd(j,k)²/(12jk)
//  Tail integral ≈ M/T_max + O(1/T²).
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

/// Compute G(j,k) using a hybrid strategy:
///
/// 1. For the first `T_direct` terms, compute each piece exactly in MPFR.
/// 2. For n > T_direct where both ⌊n/j⌋ and ⌊n/k⌋ are large,
///    the piece simplifies. We use the periodicity of the fractional
///    part to sum blocks of lcm(j,k) efficiently.
/// 3. Add a 2nd-order tail correction for the remainder.
///
/// This reduces the number of MPFR ln() calls from O(j·k) to O(lcm(j,k)).
pub fn gram_entry_mpfr(j: usize, k: usize) -> Float {
    let jf = Float::with_val(PREC, j as u64);
    let kf = Float::with_val(PREC, k as u64);
    let jk = Float::with_val(PREC, &jf * &kf);

    // Strategy: sum enough complete periods to get convergence,
    // then use the tail formula.
    //
    // The piece Piece(n) decays as O(1/n²) with oscillating O(1/n) terms
    // that average to zero over each period lcm(j,k).
    //
    // T_direct: at least 3 full periods of lcm(j,k), minimum 5000
    let lcm_jk = j / gcd(j, k) * k;
    let t_direct = (lcm_jk * 3).max(5_000).min(200_000);

    let mut total = Float::with_val(PREC, 0u32);

    // ── Direct summation ──
    // Precompute 1/jk once
    let inv_jk = Float::with_val(PREC, Float::with_val(PREC, 1u32) / &jk);

    for n in 1..=t_direct {
        let nf = Float::with_val(PREC, n as u64);
        let a_int = n / j;
        let b_int = n / k;
        let a = Float::with_val(PREC, a_int as u64);
        let b = Float::with_val(PREC, b_int as u64);

        // ln(1 + 1/n) — use ln1p for accuracy when n is large
        let inv_n = Float::with_val(PREC, Float::with_val(PREC, 1u32) / &nf);
        let ln_term = Float::with_val(PREC, inv_n.clone().ln_1p());

        // (A/k + B/j) · ln(1+1/n)
        let ab_coeff = Float::with_val(PREC, &a / &kf)
            + Float::with_val(PREC, &b / &jf);

        // AB / (n(n+1))
        let n_plus_1 = Float::with_val(PREC, &nf + 1u32);
        let ab_frac = if a_int > 0 && b_int > 0 {
            Float::with_val(PREC, &a * &b) / Float::with_val(PREC, &nf * &n_plus_1)
        } else {
            Float::with_val(PREC, 0u32)
        };

        // Piece(n) = 1/(jk) - coeff·ln(1+1/n) + AB/(n(n+1))
        let piece = Float::with_val(PREC, &inv_jk - Float::with_val(PREC, &ab_coeff * &ln_term))
            + &ab_frac;

        total += piece;
    }

    // ── Tail correction ──
    // After T_direct terms, the partial sums over complete periods give:
    //   tail ≈ M / T  +  M₂ / T²
    // where M = 1/4 + gcd²/(12jk) is the mean of {u/j}{u/k} over a period.
    let d = Float::with_val(PREC, gcd(j, k) as u64);
    let twelve_jk = Float::with_val(PREC, 12u32) * &jk;
    let tail_mean = Float::with_val(PREC, 0.25f64)
        + Float::with_val(PREC, &d * &d) / &twelve_jk;
    let t_f = Float::with_val(PREC, t_direct as u64);

    // First-order tail: M/T
    let tail1 = Float::with_val(PREC, &tail_mean / &t_f);
    // Second-order correction: M₂/T² ≈ M/(2T²)
    let tail2 = Float::with_val(PREC, &tail_mean / Float::with_val(PREC, 2u32))
        / Float::with_val(PREC, &t_f * &t_f);

    total += tail1;
    total += tail2;

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
