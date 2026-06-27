// ═══════════════════════════════════════════════════════════════════════
//  gram_f64.rs — Fast f64 Gram matrix for high-N convergence tracking
//
//  Lean bridge:
//    proofs/Cathedral/Assembly/MainChain.lean
//    proofs/Cathedral/IntegralBasis/BaezDuarte.lean
//
//  Same mathematical formula as gram.rs (512-bit MPFR), but using
//  native f64 (53-bit, ~15 decimal digits). This trades certification
//  precision for raw speed:
//
//    512-bit MPFR (gram.rs):  N=500 in 37 min, SM match ~10⁻¹⁷
//    f64 (this file):         N=5000+ in minutes, SM match ~10⁻¹²
//
//  The f64 mode is designed for convergence trend analysis — watching
//  X/ln(N) oscillate and tighten around 21.649 as N → ∞. The MPFR
//  mode remains the gold standard for Lean proof certification.
//
//  At very high N (>3000), the Gram matrix condition number κ(G) exceeds
//  10¹², and f64 Cholesky will lose significant digits. This is expected
//  and documented in the output.
// ═══════════════════════════════════════════════════════════════════════

use rayon::prelude::*;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::time::Instant;

use crate::arithmetic::gcd;

/// Euler-Mascheroni constant γ to f64 precision.
const EULER_GAMMA: f64 = 0.577_215_664_901_532_9;

/// Mean vector entry: b_k = (ln(k) + 1 - γ) / k
pub fn mean_entry_f64(k: usize) -> f64 {
    let kf = k as f64;
    (kf.ln() + 1.0 - EULER_GAMMA) / kf
}

/// Build mean vector b[0..n] = [b_1, ..., b_n].
pub fn build_mean_vector_f64(n: usize) -> Vec<f64> {
    (1..=n).map(mean_entry_f64).collect()
}

/// Precompute ln(1 + 1/n) cache in f64.
/// Much faster than MPFR — a single allocation + trivial math.
pub fn precompute_ln1p_cache_f64(max_n: usize) -> Vec<f64> {
    let t0 = Instant::now();
    let cache_size = (max_n * max_n).min(200_000).max(50_000);
    eprint!("  Precomputing {} ln1p values (f64)... ", cache_size);

    let cache: Vec<f64> = (0..=cache_size)
        .map(|n| {
            if n == 0 {
                f64::INFINITY
            } else {
                (1.0 / n as f64).ln_1p()
            }
        })
        .collect();

    eprintln!("done in {:.3}s", t0.elapsed().as_secs_f64());
    cache
}

/// Compute G(j,k) in f64 — same algorithm as gram_entry_mpfr but ~100× faster.
///
/// For high N the tail terms are negligible so we can use smaller T_direct.
pub fn gram_entry_f64(j: usize, k: usize, ln_cache: &[f64]) -> f64 {
    let jf = j as f64;
    let kf = k as f64;
    let inv_jk = 1.0 / (jf * kf);

    let lcm_jk = j / gcd(j, k) * k;
    // For f64, 3 full periods + minimum 2000 is sufficient
    // Cap lower than MPFR since we don't need 154-digit precision
    let t_direct = (lcm_jk * 3).max(2_000).min(200_000);

    let mut total = 0.0_f64;

    for n in 1..=t_direct {
        let a = (n / j) as f64;
        let b = (n / k) as f64;

        let ln_term = if n < ln_cache.len() {
            ln_cache[n]
        } else {
            (1.0 / n as f64).ln_1p()
        };

        let coeff = a / kf + b / jf;
        let nf = n as f64;
        let ab_frac = if n / j > 0 && n / k > 0 {
            a * b / (nf * (nf + 1.0))
        } else {
            0.0
        };

        total += inv_jk - coeff * ln_term + ab_frac;
    }

    // Tail correction
    let d = gcd(j, k) as f64;
    let tail_mean = 0.25 + d * d / (12.0 * jf * kf);
    let t_f = t_direct as f64;
    total += tail_mean / t_f;
    total += tail_mean / (2.0 * t_f * t_f);

    total
}

/// Build the full N×N Gram matrix in f64 with rayon parallelism.
pub fn build_gram_matrix_f64(n: usize, ln_cache: &[f64]) -> Vec<Vec<f64>> {
    let t0 = Instant::now();

    let pairs: Vec<(usize, usize)> = (0..n).flat_map(|i| (i..n).map(move |j| (i, j))).collect();
    let total = pairs.len();
    let computed = AtomicUsize::new(0);
    let threads = rayon::current_num_threads();

    eprintln!(
        "    Building {0}×{0} Gram matrix ({1} entries, {2} threads, f64)...",
        n, total, threads
    );

    let entries: Vec<(usize, usize, f64)> = pairs
        .par_iter()
        .map(|&(i, j)| {
            let val = gram_entry_f64(i + 1, j + 1, ln_cache);
            let c = computed.fetch_add(1, Ordering::Relaxed) + 1;
            if c.is_multiple_of(1000) || c == total {
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

    let mut g = vec![vec![0.0_f64; n]; n];
    for (i, j, val) in entries {
        g[i][j] = val;
        if i != j {
            g[j][i] = val;
        }
    }

    eprintln!(
        "\r    G: Done in {:.1}s ({} entries, {} cores, f64)              ",
        t0.elapsed().as_secs_f64(),
        total,
        threads
    );

    g
}
