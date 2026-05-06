// ═══════════════════════════════════════════════════════════════════════
//  gram.rs — Báez-Duarte Gram matrix with 512-bit MPFR
//
//  Lean bridge:
//    proofs/Cathedral/Vasyunin/Matrix/GramPSD.lean
//    proofs/Cathedral/Covariance/GramFormProof.lean
//
//  G(j,k) = ∫₁^∞ {u/j}{u/k}/u² du
//
//  On each integer interval [n, n+1):
//    ⌊u/j⌋ = ⌊n/j⌋ = A,  ⌊u/k⌋ = ⌊n/k⌋ = B
//    {u/j} = u/j - A,      {u/k} = u/k - B
//
//  Piece(n) = 1/(jk) - (A/k + B/j)·ln(1+1/n) + AB/(n(n+1))
//
//  Performance: The innermost loop calls ln1p(1/n) for each n.
//  Since all N(N+1)/2 parallel Gram entries share the same set of
//  ln1p values, we precompute them once into a shared read-only
//  cache, eliminating ~99% of MPFR transcendental calls.
//
//  Tail: After T_direct terms (≥ 3 full periods of lcm(j,k)),
//  the remainder is bounded by M/T + M/(2T²) where
//    M = 1/4 + gcd(j,k)²/(12jk)
//  is the mean of {u/j}{u/k} over one period.
// ═══════════════════════════════════════════════════════════════════════

use rayon::prelude::*;
use rug::Float;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::time::Instant;

use crate::arithmetic::gcd;

/// Precision in bits for all MPFR operations.
/// 512 bits ≈ 154 decimal digits — far beyond what f64 (53-bit, 16 digits)
/// can provide. This ensures the Cholesky factorization and Sherman-Morrison
/// cross-check remain stable even at N=1000+ where κ(C) ~ 10^8.
pub const PREC: u32 = 512;

/// Euler-Mascheroni constant γ to 512-bit precision.
/// Used in the mean vector b_k = (ln(k) + 1 - γ) / k.
pub fn euler_gamma() -> Float {
    Float::parse("0.57721566490153286060651209008240243104215933593992")
        .map(|p| Float::with_val(PREC, p))
        .unwrap()
}

/// Mean vector entry: b_k = (ln(k) + 1 - γ) / k
///
/// This is the closed-form inner product ⟨1, h_k⟩ where h_k(x) = {1/(kx)}.
/// Proved in: Vasyunin/Defs.lean, IntegralBasis/BaezDuarte.lean
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

/// Precomputed cache of ln(1 + 1/n) values in 512-bit MPFR.
///
/// Since every Gram entry G(j,k) sums over the same set of integers n,
/// and ln1p(1/n) depends only on n (not on j,k), we compute these once
/// and share the immutable slice across all rayon threads.
///
/// For N_max=500, this eliminates ~125,000 × 5,000 = 625 million
/// redundant MPFR ln1p calls, reducing them to a single pass of ~200,000.
pub fn precompute_ln1p_cache(max_n: usize) -> Vec<Float> {
    let t0 = Instant::now();
    // Maximum T_direct any entry will need
    // For entry G(N,N), lcm(N,N)=N, so T_direct = max(3*N, 5000)
    // We also need to handle coprime pairs: lcm(N-1,N) = N(N-1)
    // Cap at 200,000 to match gram_entry_mpfr's cap
    let cache_size = (max_n * max_n).min(200_000).max(50_000);

    eprint!("  Precomputing {} ln1p values ({}-bit)... ", cache_size, PREC);

    let cache: Vec<Float> = (0..=cache_size)
        .into_par_iter()
        .map(|n| {
            if n == 0 {
                Float::with_val(PREC, f64::INFINITY) // ln1p(1/0) — unused sentinel
            } else {
                let inv_n = Float::with_val(PREC, Float::with_val(PREC, 1u32) / Float::with_val(PREC, n as u64));
                Float::with_val(PREC, inv_n.ln_1p())
            }
        })
        .collect();

    eprintln!("done in {:.2}s", t0.elapsed().as_secs_f64());
    cache
}

/// Compute G(j,k) in 512-bit MPFR using the precomputed ln1p cache.
///
/// The fractional-part integral decomposes into a sum over integer blocks:
///   G(j,k) = Σ_{n=1}^{T} Piece(n)  +  tail(T)
///
/// where Piece(n) = 1/(jk) - (⌊n/j⌋/k + ⌊n/k⌋/j)·ln(1+1/n) + ⌊n/j⌋⌊n/k⌋/(n(n+1))
///
/// The integrand is periodic with period lcm(j,k). After 3 full periods,
/// the oscillating O(1/n) terms have averaged out and we switch to the
/// closed-form tail.
///
/// Lean formalization of this identity:
///   Gram/FractIntegral.lean, Covariance/GramFormProof.lean
pub fn gram_entry_mpfr(j: usize, k: usize, ln_cache: &[Float]) -> Float {
    let jf = Float::with_val(PREC, j as u64);
    let kf = Float::with_val(PREC, k as u64);
    let jk = Float::with_val(PREC, &jf * &kf);

    // Number of direct-summation terms.
    // At least 3 full periods of lcm(j,k) for oscillation averaging,
    // minimum 5000 for small j,k accuracy, capped at 200,000.
    let lcm_jk = j / gcd(j, k) * k;
    let t_direct = (lcm_jk * 3).max(5_000).min(200_000);

    let mut total = Float::with_val(PREC, 0u32);

    // Precomputed 1/(jk) — used in every iteration
    let inv_jk = Float::with_val(PREC, Float::with_val(PREC, 1u32) / &jk);

    for n in 1..=t_direct {
        let nf = Float::with_val(PREC, n as u64);
        let a_int = n / j;
        let b_int = n / k;
        let a = Float::with_val(PREC, a_int as u64);
        let b = Float::with_val(PREC, b_int as u64);

        // ln(1 + 1/n) from precomputed cache (or compute if beyond cache)
        let ln_term = if n < ln_cache.len() {
            Float::with_val(PREC, &ln_cache[n])
        } else {
            let inv_n = Float::with_val(PREC, Float::with_val(PREC, 1u32) / &nf);
            Float::with_val(PREC, inv_n.ln_1p())
        };

        // (⌊n/j⌋/k + ⌊n/k⌋/j) · ln(1+1/n)
        let ab_coeff = Float::with_val(PREC, &a / &kf)
            + Float::with_val(PREC, &b / &jf);

        // ⌊n/j⌋·⌊n/k⌋ / (n(n+1))
        let n_plus_1 = Float::with_val(PREC, &nf + 1u32);
        let ab_frac = if a_int > 0 && b_int > 0 {
            Float::with_val(PREC, &a * &b) / Float::with_val(PREC, &nf * &n_plus_1)
        } else {
            Float::with_val(PREC, 0u32)
        };

        // Piece(n) = 1/(jk) - coeff·ln(1+1/n) + ⌊n/j⌋⌊n/k⌋/(n(n+1))
        let piece = Float::with_val(PREC, &inv_jk - Float::with_val(PREC, &ab_coeff * &ln_term))
            + &ab_frac;

        total += piece;
    }

    // ── Tail correction ──
    // Mean of {u/j}{u/k} over one period lcm(j,k):
    //   M = 1/4 + gcd(j,k)²/(12jk)
    // Remainder: M/T + M/(2T²)
    let d = Float::with_val(PREC, gcd(j, k) as u64);
    let twelve_jk = Float::with_val(PREC, 12u32) * &jk;
    let tail_mean = Float::with_val(PREC, 0.25f64)
        + Float::with_val(PREC, &d * &d) / &twelve_jk;
    let t_f = Float::with_val(PREC, t_direct as u64);

    // First-order tail: M/T
    let tail1 = Float::with_val(PREC, &tail_mean / &t_f);
    // Second-order correction: M/(2T²)
    let tail2 = Float::with_val(PREC, &tail_mean / Float::with_val(PREC, 2u32))
        / Float::with_val(PREC, &t_f * &t_f);

    total += tail1;
    total += tail2;

    total
}

/// Build the full N×N Gram matrix using rayon parallelism.
///
/// Only computes the upper triangle (N(N+1)/2 entries) and mirrors.
/// Each entry is computed in parallel using the shared ln1p cache,
/// saturating all available cores.
///
/// The Gram matrix is symmetric positive definite (proved in
/// Vasyunin/Matrix/GramPSD.lean), which is why Cholesky works in analysis.rs.
pub fn build_gram_matrix(n: usize, ln_cache: &[Float]) -> Vec<Vec<Float>> {
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

    // Parallel computation — each (i,j) pair is independent,
    // sharing only the immutable ln_cache slice
    let entries: Vec<(usize, usize, Float)> = pairs
        .par_iter()
        .map(|&(i, j)| {
            let val = gram_entry_mpfr(i + 1, j + 1, ln_cache);
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

    // Assemble into dense symmetric matrix
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
