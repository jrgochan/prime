//! ═══════════════════════════════════════════════════════════════════════════
//!  CATHEDRAL GRAM MATRIX ENGINE v2
//!  Build-once, Extract-many · Precomputed ln table · Hardware-optimized
//!
//!  KEY INSIGHT: G_N is the (N-1)×(N-1) upper-left submatrix of G_M for M > N.
//!  So we build G_max ONCE and extract submatrices for ALL smaller N.
//!  This eliminates redundant computation across the test schedule.
//!
//!  Hardware: Apple M2 Max, 96 GB RAM, 12 cores
//!    - 10000×10000 f64 matrix = 800 MB (fits easily)
//!    - Precomputed ln table at 512-bit ≈ 10 MB for 100K entries
//!    - Parallel rayon over 12 cores
//!
//!  Precision tiers:
//!    Tier 1 (N ≤ 500):  f64 Gram entries (Kahan summation)
//!    Tier 2 (N > 500):  512-bit MPFR Gram entries → f64 storage
//! ═══════════════════════════════════════════════════════════════════════════

use rayon::prelude::*;
use rug::{Assign, Float};

use crate::arith;

/// Default MPFR precision in bits.
pub const DEFAULT_PRECISION: u32 = 512;

/// Backward-compatible alias.
pub const P: u32 = DEFAULT_PRECISION;

// ═══════════════════════════════════════════════════════════════
// HARDWARE CONSTANTS (Apple M2 Max, 96 GB)
// ═══════════════════════════════════════════════════════════════

/// Maximum matrix dimension we can store in RAM.
/// 96 GB = ~12 billion f64. A 50000×50000 matrix = 20 GB. Conservative limit.
#[allow(dead_code)]
pub const MAX_STORABLE_DIM: usize = 30_000;

/// Maximum series truncation point for ln table.
pub const MAX_LN_TABLE: usize = 200_000;

/// Uniform truncation horizon for all Gram entry computations.
///
/// All Gram entry functions use this same T so that the resulting matrix
/// G_N(T) = <f_j, f_k>_T is a Gram matrix of a single inner product space,
/// guaranteeing positive semi-definiteness by construction.
///
/// This matches the GPU kernel's uniform strategy. Setting different T per
/// entry breaks the inner-product structure and can destroy PD.
pub const DEFAULT_T_UNIFORM: usize = 200_000;

// ═══════════════════════════════════════════════════════════════
// PRECOMPUTED LN TABLE (ln(1+1/n) — used by original algorithm)
// ═══════════════════════════════════════════════════════════════

pub struct LnTable {
    values: Vec<Float>,
    pub max_n: usize,
    pub precision: u32,
}

impl LnTable {
    /// Create a new ln(1+1/n) table at the given precision.
    pub fn with_precision(max_n: usize, precision: u32) -> Self {
        let p = precision;
        let cap = max_n.min(MAX_LN_TABLE);
        eprintln!("  \x1b[2m▸ Precomputing ln(1+1/n) table for n ≤ {cap} at {p}-bit...\x1b[0m");
        let t0 = std::time::Instant::now();
        let values: Vec<Float> = (0..=cap)
            .into_par_iter()
            .map(|n| {
                if n == 0 {
                    Float::with_val(p, 0)
                } else {
                    let nf = Float::with_val(p, n as u64);
                    let ratio = Float::with_val(
                        p,
                        Float::with_val(p, 1u32)
                            + Float::with_val(p, Float::with_val(p, 1u32) / &nf),
                    );
                    ratio.ln()
                }
            })
            .collect();
        eprintln!(
            "  \x1b[32m✓\x1b[0m ln table ready ({cap} entries, {:.1}s)",
            t0.elapsed().as_secs_f64()
        );
        Self {
            values,
            max_n: cap,
            precision: p,
        }
    }

    /// Create a new ln table at the default 512-bit precision.
    pub fn new(max_n: usize) -> Self {
        Self::with_precision(max_n, DEFAULT_PRECISION)
    }

    #[inline]
    pub fn get(&self, n: usize) -> &Float {
        &self.values[n.min(self.max_n)]
    }
}

// ═══════════════════════════════════════════════════════════════
// PRECOMPUTED LN(N) TABLE — for block-based fast algorithm
// ═══════════════════════════════════════════════════════════════

/// Table of ln(n) for n = 0..max_n+1 at MPFR precision.
/// Used by the block-based fast Gram entry algorithm.
/// KEY IDENTITY: Σ_{n=a}^{b} ln(1+1/n) = ln(b+1) - ln(a)  [telescoping!]
pub struct LnNTable {
    /// ln_n[n] = ln(n) at MPFR precision. ln_n[0] = 0 (unused).
    ln_n: Vec<Float>,
    pub max_n: usize,
    pub precision: u32,
}

impl LnNTable {
    /// Build ln(n) table for n = 0..=max_val at given MPFR precision.
    pub fn new(max_val: usize, precision: u32) -> Self {
        let p = precision;
        eprintln!(
            "  \x1b[2m▸ Precomputing ln(n) table for n ≤ {} at {p}-bit...\x1b[0m",
            max_val
        );
        let t0 = std::time::Instant::now();
        let ln_n: Vec<Float> = (0..=max_val)
            .into_par_iter()
            .map(|n| {
                if n == 0 {
                    Float::with_val(p, 0)
                } else {
                    Float::with_val(p, n as u64).ln()
                }
            })
            .collect();
        eprintln!(
            "  \x1b[32m✓\x1b[0m ln(n) table ready ({} entries, {:.2}s)",
            max_val,
            t0.elapsed().as_secs_f64()
        );
        Self {
            ln_n,
            max_n: max_val,
            precision: p,
        }
    }

    /// ln(n) at MPFR precision.
    #[inline]
    pub fn ln(&self, n: usize) -> &Float {
        &self.ln_n[n.min(self.max_n)]
    }
}

// ═══════════════════════════════════════════════════════════════
// UTILITIES
// ═══════════════════════════════════════════════════════════════

#[inline(always)]
fn fast_ln1p_inv(n: f64) -> f64 {
    if n < 32.0 {
        (1.0 + 1.0 / n).ln()
    } else {
        let x = 1.0 / n;
        x * (1.0 - x * (0.5 - x * (1.0 / 3.0 - x * (0.25 - x * (0.2 - x * (1.0 / 6.0))))))
    }
}

// ═══════════════════════════════════════════════════════════════
// GRAM ENTRY COMPUTATION
// ═══════════════════════════════════════════════════════════════

/// Fast f64 Gram entry with Kahan compensated summation.
pub fn gram_entry_f64(j: usize, k: usize) -> f64 {
    let jf = j as f64;
    let kf = k as f64;
    let inv_jk = 1.0 / (jf * kf);
    let inv_kf = 1.0 / kf;
    let inv_jf = 1.0 / jf;
    let g = arith::gcd(j, k);
    let lcm_jk = (j / g) * k;
    let t_direct = DEFAULT_T_UNIFORM;
    let min_terms = (lcm_jk * 3).max(2_000);

    let (mut total, mut comp) = (0.0f64, 0.0f64);
    for n in 1..=t_direct {
        let nf = n as f64;
        let a_int = n / j;
        let b_int = n / k;
        let ln_term = fast_ln1p_inv(nf);
        let ab_coeff = (a_int as f64) * inv_kf + (b_int as f64) * inv_jf;
        let ab_frac = if a_int > 0 && b_int > 0 {
            (a_int as f64) * (b_int as f64) / (nf * (nf + 1.0))
        } else {
            0.0
        };
        let term = inv_jk - ab_coeff * ln_term + ab_frac;
        let y = term - comp;
        let t = total + y;
        comp = (t - total) - y;
        total = t;

        // Adaptive early-exit: series converged to working precision
        if n > min_terms && n % 1000 == 0 && term.abs() < total.abs() * 1e-16 {
            break;
        }
    }

    let d = g as f64;
    let tail_mean = 0.25 + d * d / (12.0 * jf * kf);
    let inv_t = 1.0 / t_direct as f64;
    total += tail_mean * inv_t
        + tail_mean * 0.5 * inv_t * inv_t
        + tail_mean * (1.0 / 6.0) * inv_t * inv_t * inv_t;
    total
}

/// Standalone MPFR Gram entry — no pre-built ln table required.
///
/// Computes ln(1+1/n) inline at `prec` bits of precision.
/// Slower than [`gram_entry_mpfr`] for batch computation, but ideal
/// for one-off evaluations or small experiments that don't want to
/// manage a precomputed ln table.
///
/// # Example
/// ```rust,no_run
/// use cathedral_utils::gram::gram_entry_standalone;
/// let g22 = gram_entry_standalone(2, 2, 256);
/// assert!((g22.to_f64() - 0.1957).abs() < 0.001);
/// ```
pub fn gram_entry_standalone(j: usize, k: usize, prec: u32) -> Float {
    let p = prec;
    let jf = Float::with_val(p, j as u64);
    let kf = Float::with_val(p, k as u64);
    let jk = Float::with_val(p, &jf * &kf);
    let inv_jk = Float::with_val(p, Float::with_val(p, 1u32) / &jk);
    let inv_jf = Float::with_val(p, Float::with_val(p, 1u32) / &jf);
    let inv_kf = Float::with_val(p, Float::with_val(p, 1u32) / &kf);

    let g = arith::gcd(j, k);
    let lcm_jk = (j / g) * k;
    let t_direct = DEFAULT_T_UNIFORM;

    let mut total = Float::with_val(p, 0u32);
    let min_terms = (lcm_jk * 2).max(1_000);

    // Pre-allocate scratch to avoid heap allocations in the hot loop
    let mut scratch_ab = Float::with_val(p, 0);
    let mut scratch_bj = Float::with_val(p, 0);
    let mut scratch_term = Float::with_val(p, 0);

    for n in 1..=t_direct {
        let a_int = n / j;
        let b_int = n / k;

        // ln(1+1/n) computed inline at full precision
        let nf = Float::with_val(p, n as u64);
        let inv_n = Float::with_val(p, Float::with_val(p, 1u32) / &nf);
        let ln_term = Float::with_val(p, inv_n.ln_1p());

        // ab_coeff = (a/k + b/j) · ln(1+1/n)
        scratch_ab.assign(a_int as u64);
        scratch_ab *= &inv_kf;
        scratch_bj.assign(b_int as u64);
        scratch_bj *= &inv_jf;
        scratch_ab += &scratch_bj;
        scratch_ab *= &ln_term;

        // term = 1/(jk) - ab_coeff
        scratch_term.assign(&inv_jk);
        scratch_term -= &scratch_ab;

        // + floor fraction: a_int * b_int / (n * (n+1))
        if a_int > 0 && b_int > 0 {
            let mut frac = Float::with_val(p, (a_int * b_int) as u64);
            let mut denom = Float::with_val(p, n as u64);
            denom *= (n + 1) as u64;
            frac /= &denom;
            scratch_term += &frac;
        }

        total += &scratch_term;

        // Adaptive early-exit
        if n > min_terms && n % 500 == 0 {
            let ratio = scratch_term.to_f64().abs() / total.to_f64().abs();
            if ratio < 1e-18 {
                break;
            }
        }
    }

    // Euler-Maclaurin tail correction (3 terms)
    let d = Float::with_val(p, g as u64);
    let d_sq = Float::with_val(p, &d * &d);
    let twelve_jk = Float::with_val(p, Float::with_val(p, 12u32) * &jk);
    let tail_frac = Float::with_val(p, &d_sq / &twelve_jk);
    let tail_mean = Float::with_val(p, Float::with_val(p, 0.25f64) + &tail_frac);
    let t_f = Float::with_val(p, t_direct as u64);
    let inv_t = Float::with_val(p, Float::with_val(p, 1u32) / &t_f);
    let inv_t2 = Float::with_val(p, &inv_t * &inv_t);
    let inv_t3 = Float::with_val(p, &inv_t2 * &inv_t);
    total += Float::with_val(p, &tail_mean * &inv_t);
    total += Float::with_val(
        p,
        Float::with_val(p, &tail_mean * Float::with_val(p, 0.5f64)) * &inv_t2,
    );
    let sixth = Float::with_val(p, Float::with_val(p, 1u32) / Float::with_val(p, 6u32));
    total += Float::with_val(p, Float::with_val(p, &tail_mean * &sixth) * &inv_t3);

    total
}

/// MPFR Gram entry with explicit truncation horizon `t_max`.
///
/// Same algorithm as [`gram_entry_standalone`] but forces `t_direct = t_max`
/// for ALL entries, regardless of lcm(j,k). This matches the GPU kernel's
/// uniform truncation strategy, enabling apples-to-apples verification.
///
/// The GPU uses uniform T to preserve positive-definiteness of the inner
/// product space. For cross-verification, we must use the same T.
pub fn gram_entry_at_t(j: usize, k: usize, prec: u32, t_max: usize) -> Float {
    let p = prec;
    let jf = Float::with_val(p, j as u64);
    let kf = Float::with_val(p, k as u64);
    let jk = Float::with_val(p, &jf * &kf);
    let inv_jk = Float::with_val(p, Float::with_val(p, 1u32) / &jk);
    let inv_jf = Float::with_val(p, Float::with_val(p, 1u32) / &jf);
    let inv_kf = Float::with_val(p, Float::with_val(p, 1u32) / &kf);

    let g = arith::gcd(j, k);
    let lcm_jk = (j / g) * k;
    let t_direct = t_max;

    let mut total = Float::with_val(p, 0u32);
    let min_terms = (lcm_jk * 2).max(1_000);

    let mut scratch_ab = Float::with_val(p, 0);
    let mut scratch_bj = Float::with_val(p, 0);
    let mut scratch_term = Float::with_val(p, 0);

    for n in 1..=t_direct {
        let a_int = n / j;
        let b_int = n / k;

        let nf = Float::with_val(p, n as u64);
        let inv_n = Float::with_val(p, Float::with_val(p, 1u32) / &nf);
        let ln_term = Float::with_val(p, inv_n.ln_1p());

        scratch_ab.assign(a_int as u64);
        scratch_ab *= &inv_kf;
        scratch_bj.assign(b_int as u64);
        scratch_bj *= &inv_jf;
        scratch_ab += &scratch_bj;
        scratch_ab *= &ln_term;

        scratch_term.assign(&inv_jk);
        scratch_term -= &scratch_ab;

        if a_int > 0 && b_int > 0 {
            let mut frac = Float::with_val(p, (a_int * b_int) as u64);
            let mut denom = Float::with_val(p, n as u64);
            denom *= (n + 1) as u64;
            frac /= &denom;
            scratch_term += &frac;
        }

        total += &scratch_term;

        if n > min_terms && n % 500 == 0 {
            let ratio = scratch_term.to_f64().abs() / total.to_f64().abs();
            if ratio < 1e-18 {
                break;
            }
        }
    }

    // Euler-Maclaurin tail correction (3 terms)
    let d = Float::with_val(p, g as u64);
    let d_sq = Float::with_val(p, &d * &d);
    let twelve_jk = Float::with_val(p, Float::with_val(p, 12u32) * &jk);
    let tail_frac = Float::with_val(p, &d_sq / &twelve_jk);
    let tail_mean = Float::with_val(p, Float::with_val(p, 0.25f64) + &tail_frac);
    let t_f = Float::with_val(p, t_direct as u64);
    let inv_t = Float::with_val(p, Float::with_val(p, 1u32) / &t_f);
    let inv_t2 = Float::with_val(p, &inv_t * &inv_t);
    let inv_t3 = Float::with_val(p, &inv_t2 * &inv_t);
    total += Float::with_val(p, &tail_mean * &inv_t);
    total += Float::with_val(
        p,
        Float::with_val(p, &tail_mean * Float::with_val(p, 0.5f64)) * &inv_t2,
    );
    let sixth = Float::with_val(p, Float::with_val(p, 1u32) / Float::with_val(p, 6u32));
    total += Float::with_val(p, Float::with_val(p, &tail_mean * &sixth) * &inv_t3);

    total
}

/// MPFR Gram entry using precomputed ln table — optimized.
///
/// Precision is taken from the ln_table.
/// Uses pre-allocated scratch floats to avoid heap allocations in the hot loop.
/// Includes adaptive early-exit when the series has converged.
pub fn gram_entry_mpfr(j: usize, k: usize, ln_table: &LnTable) -> Float {
    let p = ln_table.precision;

    // Pre-compute constants (allocated once)
    let jf = Float::with_val(p, j as u64);
    let kf = Float::with_val(p, k as u64);
    let inv_jk = Float::with_val(p, 1u32) / Float::with_val(p, &jf * &kf);
    let inv_jf = Float::with_val(p, 1u32) / &jf;
    let inv_kf = Float::with_val(p, 1u32) / &kf;

    let g = arith::gcd(j, k);
    let lcm_jk = (j / g) * k;
    let t_direct = DEFAULT_T_UNIFORM.min(ln_table.max_n);

    // Pre-allocate scratch variables (reused every iteration)
    let mut total = Float::with_val(p, 0);
    let mut scratch_a = Float::with_val(p, 0);
    let mut scratch_b = Float::with_val(p, 0);
    let mut scratch_ab = Float::with_val(p, 0);
    let mut scratch_term = Float::with_val(p, 0);
    let mut scratch_frac = Float::with_val(p, 0);
    let mut scratch_denom = Float::with_val(p, 0);

    // Minimum terms before early-exit check (ensure accuracy)
    let min_terms = (lcm_jk * 3).max(2_000);

    for n in 1..=t_direct {
        let a_int = n / j;
        let b_int = n / k;
        let ln_term = ln_table.get(n);

        // scratch_a = (a_int / k) * ln_term
        scratch_a.assign(a_int as u64);
        scratch_a *= &inv_kf;

        // scratch_b = (b_int / j) * ln_term
        scratch_b.assign(b_int as u64);
        scratch_b *= &inv_jf;

        // scratch_ab = (scratch_a + scratch_b) * ln_term
        scratch_ab.assign(&scratch_a);
        scratch_ab += &scratch_b;
        scratch_ab *= ln_term;

        // scratch_term = inv_jk - scratch_ab
        scratch_term.assign(&inv_jk);
        scratch_term -= &scratch_ab;

        // Add floor fraction: a_int * b_int / (n * (n+1))
        if a_int > 0 && b_int > 0 {
            scratch_frac.assign((a_int * b_int) as u64);
            scratch_denom.assign(n as u64);
            scratch_denom *= (n + 1) as u64;
            scratch_frac /= &scratch_denom;
            scratch_term += &scratch_frac;
        }

        total += &scratch_term;

        // Adaptive early-exit: if term is negligible relative to total
        if n > min_terms && n % 500 == 0 {
            let ratio = scratch_term.to_f64().abs() / total.to_f64().abs();
            if ratio < 1e-18 {
                break;
            }
        }
    }

    // Euler-Maclaurin tail correction (3 terms)
    let jk = Float::with_val(p, &jf * &kf);
    let d = Float::with_val(p, g as u64);
    let d_sq = Float::with_val(p, &d * &d);
    let twelve_jk = Float::with_val(p, Float::with_val(p, 12u32) * &jk);
    let tail_frac = Float::with_val(p, &d_sq / &twelve_jk);
    let tail_mean = Float::with_val(p, Float::with_val(p, 0.25f64) + &tail_frac);
    let t_f = Float::with_val(p, t_direct as u64);
    let inv_t = Float::with_val(p, Float::with_val(p, 1u32) / &t_f);
    let inv_t2 = Float::with_val(p, &inv_t * &inv_t);
    let inv_t3 = Float::with_val(p, &inv_t2 * &inv_t);
    total += Float::with_val(p, &tail_mean * &inv_t);
    total += Float::with_val(
        p,
        Float::with_val(p, &tail_mean * Float::with_val(p, 0.5f64)) * &inv_t2,
    );
    let sixth = Float::with_val(p, Float::with_val(p, 1u32) / Float::with_val(p, 6u32));
    total += Float::with_val(p, Float::with_val(p, &tail_mean * &sixth) * &inv_t3);
    total
}

// ═══════════════════════════════════════════════════════════════
// BLOCK-BASED FAST GRAM ENTRY — O(T/j + T/k) instead of O(T)
//
// Uses telescoping identities to reduce per-entry work:
//   Σ_{n=a}^b ln(1+1/n) = ln(b+1) - ln(a)       → 2 table lookups
//   Σ_{n=a}^b 1/(n(n+1)) = 1/a - 1/(b+1)         → 2 divisions
//
// Between consecutive breakpoints of ⌊n/j⌋ and ⌊n/k⌋, the floor
// values are constant, so each block is O(1) MPFR operations.
// Total blocks per entry: O(T/j + T/k) ≈ 10-100 for large j,k.
// ═══════════════════════════════════════════════════════════════

/// Block-based fast Gram entry computation.
/// Uses precomputed ln(n) table to exploit telescoping sums.
/// Complexity: O(T/j + T/k) MPFR ops instead of O(T).
pub fn gram_entry_fast(j: usize, k: usize, ln_table: &LnNTable) -> Float {
    let p = ln_table.precision;
    let g = arith::gcd(j, k);
    let _lcm_jk = (j / g) * k;
    let t_direct = DEFAULT_T_UNIFORM.min(ln_table.max_n - 1);

    let jf = Float::with_val(p, j as u64);
    let kf = Float::with_val(p, k as u64);
    let inv_jk = Float::with_val(p, Float::with_val(p, 1u32) / Float::with_val(p, &jf * &kf));
    let inv_j = Float::with_val(p, Float::with_val(p, 1u32) / &jf);
    let inv_k = Float::with_val(p, Float::with_val(p, 1u32) / &kf);

    // Collect breakpoints where ⌊n/j⌋ or ⌊n/k⌋ changes.
    // Between consecutive breakpoints, both floor values are constant.
    let mut breakpoints = Vec::with_capacity(t_direct / j + t_direct / k + 4);
    breakpoints.push(1usize);
    for m in 1..=(t_direct / j + 1) {
        let bp = m * j;
        if bp <= t_direct {
            breakpoints.push(bp);
        }
    }
    for m in 1..=(t_direct / k + 1) {
        let bp = m * k;
        if bp <= t_direct {
            breakpoints.push(bp);
        }
    }
    breakpoints.push(t_direct + 1);
    breakpoints.sort_unstable();
    breakpoints.dedup();

    let mut total = Float::with_val(p, 0);
    let mut scratch = Float::with_val(p, 0);

    for w in 0..breakpoints.len() - 1 {
        let n1 = breakpoints[w];
        let n2 = breakpoints[w + 1]; // exclusive upper bound
        if n1 > t_direct {
            break;
        }
        let n2 = n2.min(t_direct + 1);
        if n1 >= n2 {
            continue;
        }

        let a = n1 / j; // ⌊n/j⌋ constant in [n1, n2)
        let b = n1 / k; // ⌊n/k⌋ constant in [n1, n2)
        let count = (n2 - n1) as u64;

        // Term 1: count/(jk)
        scratch.assign(&inv_jk);
        scratch *= count;
        total += &scratch;

        // Term 2: -(a/k + b/j) * [ln(n2) - ln(n1)]  [telescoping!]
        if a > 0 || b > 0 {
            // coeff = a/k + b/j
            let coeff_val = (a as f64) / (k as f64) + (b as f64) / (j as f64);
            if coeff_val > 0.0 {
                let mut coeff = Float::with_val(p, a as u64);
                coeff *= &inv_k;
                let mut bj = Float::with_val(p, b as u64);
                bj *= &inv_j;
                coeff += &bj;
                // ln_sum = ln(n2) - ln(n1)
                scratch.assign(ln_table.ln(n2));
                scratch -= ln_table.ln(n1);
                coeff *= &scratch;
                total -= &coeff;
            }
        }

        // Term 3: a*b * [1/n1 - 1/n2]  [telescoping of 1/(n(n+1))]
        if a > 0 && b > 0 {
            let ab = (a as u64) * (b as u64);
            // 1/n1 - 1/n2
            scratch.assign(n2 as u64);
            let mut inv_n1 = Float::with_val(p, n1 as u64);
            // (n2 - n1) / (n1 * n2)
            let diff = (n2 - n1) as u64;
            scratch *= &inv_n1; // scratch = n1 * n2
            inv_n1.assign(diff); // reuse as numerator
            inv_n1 /= &scratch; // inv_n1 = (n2-n1)/(n1*n2)
            inv_n1 *= ab;
            total += &inv_n1;
        }
    }

    // Euler-Maclaurin tail correction (3 terms)
    let jk = Float::with_val(p, &jf * &kf);
    let d = Float::with_val(p, g as u64);
    let d_sq = Float::with_val(p, &d * &d);
    let twelve_jk = Float::with_val(p, Float::with_val(p, 12u32) * &jk);
    let tail_frac = Float::with_val(p, &d_sq / &twelve_jk);
    let tail_mean = Float::with_val(p, Float::with_val(p, 0.25f64) + &tail_frac);
    let t_f = Float::with_val(p, t_direct as u64);
    let inv_t = Float::with_val(p, Float::with_val(p, 1u32) / &t_f);
    let inv_t2 = Float::with_val(p, &inv_t * &inv_t);
    let inv_t3 = Float::with_val(p, &inv_t2 * &inv_t);
    total += Float::with_val(p, &tail_mean * &inv_t);
    total += Float::with_val(
        p,
        Float::with_val(p, &tail_mean * Float::with_val(p, 0.5f64)) * &inv_t2,
    );
    let sixth = Float::with_val(p, Float::with_val(p, 1u32) / Float::with_val(p, 6u32));
    total += Float::with_val(p, Float::with_val(p, &tail_mean * &sixth) * &inv_t3);
    total
}

/// Block-based fast Gram entry with **uniform** truncation horizon `t_max`.
///
/// Same O(T/j + T/k) block-based algorithm as [`gram_entry_fast`], but forces
/// `t_direct = t_max` for ALL entries regardless of lcm(j,k). This matches
/// the GPU kernel's uniform truncation strategy, preserving the inner-product
/// space structure and guaranteeing positive-definiteness of the resulting
/// Gram matrix.
///
/// # Why uniform T matters
/// The Gram matrix G_N(T) is an inner product matrix for the truncated
/// Nyman-Beurling functions at horizon T. When T varies per entry (adaptive),
/// G_N is no longer a Gram matrix of any single inner product space, breaking
/// positive-definiteness. With uniform T, G_N(T) = F^T F where F has columns
/// from the same function space, guaranteeing PD.
///
/// # Performance
/// For large j,k, block count ≈ T/j + T/k, so entries with j=k=27720
/// and T=200K need only ~15 blocks. Much faster than the O(T) naive loop.
pub fn gram_entry_fast_at_t(j: usize, k: usize, ln_table: &LnNTable, t_max: usize) -> Float {
    let p = ln_table.precision;
    let g = arith::gcd(j, k);
    let t_direct = t_max.min(ln_table.max_n - 1);

    let jf = Float::with_val(p, j as u64);
    let kf = Float::with_val(p, k as u64);
    let inv_jk = Float::with_val(p, Float::with_val(p, 1u32) / Float::with_val(p, &jf * &kf));
    let inv_j = Float::with_val(p, Float::with_val(p, 1u32) / &jf);
    let inv_k = Float::with_val(p, Float::with_val(p, 1u32) / &kf);

    // Collect breakpoints where ⌊n/j⌋ or ⌊n/k⌋ changes.
    let mut breakpoints = Vec::with_capacity(t_direct / j + t_direct / k + 4);
    breakpoints.push(1usize);
    for m in 1..=(t_direct / j + 1) {
        let bp = m * j;
        if bp <= t_direct {
            breakpoints.push(bp);
        }
    }
    for m in 1..=(t_direct / k + 1) {
        let bp = m * k;
        if bp <= t_direct {
            breakpoints.push(bp);
        }
    }
    breakpoints.push(t_direct + 1);
    breakpoints.sort_unstable();
    breakpoints.dedup();

    let mut total = Float::with_val(p, 0);
    let mut scratch = Float::with_val(p, 0);

    for w in 0..breakpoints.len() - 1 {
        let n1 = breakpoints[w];
        let n2 = breakpoints[w + 1];
        if n1 > t_direct {
            break;
        }
        let n2 = n2.min(t_direct + 1);
        if n1 >= n2 {
            continue;
        }

        let a = n1 / j;
        let b = n1 / k;
        let count = (n2 - n1) as u64;

        // Term 1: count/(jk)
        scratch.assign(&inv_jk);
        scratch *= count;
        total += &scratch;

        // Term 2: -(a/k + b/j) * [ln(n2) - ln(n1)]
        if a > 0 || b > 0 {
            let coeff_val = (a as f64) / (k as f64) + (b as f64) / (j as f64);
            if coeff_val > 0.0 {
                let mut coeff = Float::with_val(p, a as u64);
                coeff *= &inv_k;
                let mut bj = Float::with_val(p, b as u64);
                bj *= &inv_j;
                coeff += &bj;
                scratch.assign(ln_table.ln(n2));
                scratch -= ln_table.ln(n1);
                coeff *= &scratch;
                total -= &coeff;
            }
        }

        // Term 3: a*b * [1/n1 - 1/n2]
        if a > 0 && b > 0 {
            let ab = (a as u64) * (b as u64);
            scratch.assign(n2 as u64);
            let mut inv_n1 = Float::with_val(p, n1 as u64);
            let diff = (n2 - n1) as u64;
            scratch *= &inv_n1;
            inv_n1.assign(diff);
            inv_n1 /= &scratch;
            inv_n1 *= ab;
            total += &inv_n1;
        }
    }

    // Euler-Maclaurin tail correction (3 terms)
    let jk = Float::with_val(p, &jf * &kf);
    let d = Float::with_val(p, g as u64);
    let d_sq = Float::with_val(p, &d * &d);
    let twelve_jk = Float::with_val(p, Float::with_val(p, 12u32) * &jk);
    let tail_frac = Float::with_val(p, &d_sq / &twelve_jk);
    let tail_mean = Float::with_val(p, Float::with_val(p, 0.25f64) + &tail_frac);
    let t_f = Float::with_val(p, t_direct as u64);
    let inv_t = Float::with_val(p, Float::with_val(p, 1u32) / &t_f);
    let inv_t2 = Float::with_val(p, &inv_t * &inv_t);
    let inv_t3 = Float::with_val(p, &inv_t2 * &inv_t);
    total += Float::with_val(p, &tail_mean * &inv_t);
    total += Float::with_val(
        p,
        Float::with_val(p, &tail_mean * Float::with_val(p, 0.5f64)) * &inv_t2,
    );
    let sixth = Float::with_val(p, Float::with_val(p, 1u32) / Float::with_val(p, 6u32));
    total += Float::with_val(p, Float::with_val(p, &tail_mean * &sixth) * &inv_t3);
    total
}

// ═══════════════════════════════════════════════════════════════
// DOUBLE-DOUBLE GRAM ENGINE (Pure Rust, ~31 decimal digits)
// ~5-10x faster than MPFR for equivalent precision.
// ═══════════════════════════════════════════════════════════════

use crate::dd::DD;

/// Precomputed ln(1+1/n) table at double-double precision.
pub struct DDLnTable {
    values: Vec<DD>,
    pub max_n: usize,
}

impl DDLnTable {
    pub fn new(max_n: usize) -> Self {
        let cap = max_n.min(MAX_LN_TABLE);
        eprintln!("  \x1b[2m▸ Precomputing DD ln(1+1/n) table for n ≤ {cap}...\x1b[0m");
        let t0 = std::time::Instant::now();
        let values: Vec<DD> = (0..=cap)
            .into_par_iter()
            .map(|n| {
                if n == 0 {
                    DD::from_f64(0.0)
                } else {
                    DD::ln1p_inv(n as u64)
                }
            })
            .collect();
        eprintln!(
            "  \x1b[32m✓\x1b[0m DD ln table ready ({cap} entries, {:.1}s)",
            t0.elapsed().as_secs_f64()
        );
        Self { values, max_n: cap }
    }

    #[inline]
    pub fn get(&self, n: usize) -> DD {
        self.values[n.min(self.max_n)]
    }
}

/// Double-double Gram entry using precomputed DD ln table.
///
/// Same algorithm as gram_entry_mpfr but uses pure-Rust double-double
/// arithmetic (~31 decimal digits) instead of MPFR.
pub fn gram_entry_dd(j: usize, k: usize, ln_table: &DDLnTable) -> f64 {
    let jf = DD::from_u64(j as u64);
    let kf = DD::from_u64(k as u64);
    let inv_jk = DD::from_f64(1.0) / (jf * kf);
    let inv_jf = DD::from_f64(1.0) / jf;
    let inv_kf = DD::from_f64(1.0) / kf;

    let g = arith::gcd(j, k);
    let lcm_jk = (j / g) * k;
    let t_direct = DEFAULT_T_UNIFORM.min(ln_table.max_n);

    let mut total = DD::from_f64(0.0);
    let min_terms = (lcm_jk * 3).max(2_000);

    for n in 1..=t_direct {
        let a_int = n / j;
        let b_int = n / k;
        let ln_term = ln_table.get(n);

        // ab_coeff = (a_int/k + b_int/j)
        let a_coeff = DD::from_u64(a_int as u64) * inv_kf;
        let b_coeff = DD::from_u64(b_int as u64) * inv_jf;
        let ab_coeff = (a_coeff + b_coeff) * ln_term;

        // term = 1/(jk) - ab_coeff
        let mut term = inv_jk - ab_coeff;

        // Floor fraction: a_int * b_int / (n * (n+1))
        if a_int > 0 && b_int > 0 {
            let num = DD::from_u64((a_int * b_int) as u64);
            let denom = DD::from_u64(n as u64) * DD::from_u64((n + 1) as u64);
            term += num / denom;
        }

        total += term;

        // Adaptive early-exit
        if n > min_terms && n % 500 == 0 {
            let ratio = term.hi.abs() / total.hi.abs();
            if ratio < 1e-20 {
                break;
            }
        }
    }

    // Euler-Maclaurin tail
    let d = g as f64;
    let jkf = (j * k) as f64;
    let tail_mean = 0.25 + d * d / (12.0 * jkf);
    let inv_t = 1.0 / t_direct as f64;
    let tail = tail_mean * inv_t
        + tail_mean * 0.5 * inv_t * inv_t
        + tail_mean * (1.0 / 6.0) * inv_t * inv_t * inv_t;
    total += DD::from_f64(tail);

    total.to_f64()
}

// ═══════════════════════════════════════════════════════════════
// BUILD-ONCE GRAM MATRIX
// G_N is upper-left (N-1)×(N-1) submatrix of G_max.
// We build G_max ONCE and extract submatrices for all test N.
// ═══════════════════════════════════════════════════════════════

/// The stored full Gram matrix. Build once, query many.
pub struct GramMatrix {
    /// Row-major storage: mat[i * max_dim + j] = G(i+2, j+2)
    pub data: Vec<f64>,
    /// Maximum dimension (= max_N - 1)
    pub max_dim: usize,
    /// Maximum N used
    pub max_n: usize,
    /// Whether MPFR was used for construction
    pub mpfr_built: bool,
    /// MPFR precision bits used (0 for f64)
    pub precision: u32,
}

impl GramMatrix {
    /// Build the full Gram matrix for indices {2,...,max_n}.
    /// Automatically selects f64 or MPFR based on max_n.
    /// For max_n ≤ 500: uses f64 (sub-second)
    /// For max_n > 500: uses MPFR with precomputed ln table
    pub fn build(max_n: usize, ln_table: Option<&LnTable>) -> Self {
        let dim = max_n - 1;
        let total_entries = dim * (dim + 1) / 2;
        let mem_mb = (dim * dim * 8) / (1024 * 1024);
        let t0 = std::time::Instant::now();

        let use_mpfr = ln_table.is_some();
        let prec = ln_table.map(|t| t.precision).unwrap_or(0);

        eprintln!("  \x1b[2m▸ Building {dim}×{dim} Gram matrix ({total_entries} unique entries, ~{mem_mb} MB)\x1b[0m");
        eprintln!(
            "  \x1b[2m  Precision: {}\x1b[0m",
            if use_mpfr {
                format!("{prec}-bit MPFR (precomputed ln)")
            } else {
                "f64 (Kahan summation)".to_string()
            }
        );

        // Generate all upper-triangle (row, col) pairs for entry-level parallelism.
        // This gives much better load balance than row-level parallelism because
        // early rows (j=2,3) have vastly more work per entry than late rows.
        let pairs: Vec<(usize, usize)> = (0..dim)
            .flat_map(|row| (row..dim).map(move |col| (row, col)))
            .collect();

        let done = std::sync::atomic::AtomicUsize::new(0);

        let entries: Vec<((usize, usize), f64)> = pairs
            .par_iter()
            .map(|&(row, col)| {
                let val = if use_mpfr {
                    gram_entry_mpfr(row + 2, col + 2, ln_table.unwrap()).to_f64()
                } else {
                    gram_entry_f64(row + 2, col + 2)
                };

                // Progress tracking
                let count = done.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
                if dim > 200 && count % (total_entries / 100).max(1) == 0 && count > 0 {
                    let elapsed = t0.elapsed().as_secs_f64();
                    let frac = count as f64 / total_entries as f64;
                    let eta = elapsed / frac * (1.0 - frac);
                    eprint!("\r  \x1b[2m  {count}/{total_entries} entries ({:.0}%) ETA {eta:.0}s\x1b[0m     ", frac * 100.0);
                }

                ((row, col), val)
            })
            .collect();

        if dim > 200 {
            eprintln!();
        }

        let mut data = vec![0.0f64; dim * dim];
        for ((r, c), v) in entries {
            data[r * dim + c] = v;
            data[c * dim + r] = v;
        }

        eprintln!(
            "  \x1b[32m✓\x1b[0m Gram matrix built in {:.1}s",
            t0.elapsed().as_secs_f64()
        );

        Self {
            data,
            max_dim: dim,
            max_n,
            mpfr_built: use_mpfr,
            precision: prec,
        }
    }

    /// Build using the FAST block-based algorithm — O(T/j+T/k) per entry.
    /// Uses precomputed ln(n) table to exploit telescoping sums.
    /// For N=10000: ~50-200x faster than the standard MPFR approach.
    pub fn build_fast(max_n: usize, ln_n_table: &LnNTable) -> Self {
        let dim = max_n - 1;
        let total_entries = dim * (dim + 1) / 2;
        let mem_mb = (dim * dim * 8) / (1024 * 1024);
        let prec = ln_n_table.precision;
        let t0 = std::time::Instant::now();

        eprintln!("  \x1b[2m▸ Building {dim}×{dim} Gram matrix ({total_entries} entries, ~{mem_mb} MB)\x1b[0m");
        eprintln!("  \x1b[2m  Method: FAST block-based ({prec}-bit MPFR, telescoping sums)\x1b[0m");

        let pairs: Vec<(usize, usize)> = (0..dim)
            .flat_map(|row| (row..dim).map(move |col| (row, col)))
            .collect();

        let done = std::sync::atomic::AtomicUsize::new(0);

        let entries: Vec<((usize, usize), f64)> = pairs
            .par_iter()
            .map(|&(row, col)| {
                let val = gram_entry_fast(row + 2, col + 2, ln_n_table).to_f64();

                let count = done.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
                if dim > 200 && count % (total_entries / 100).max(1) == 0 && count > 0 {
                    let elapsed = t0.elapsed().as_secs_f64();
                    let frac = count as f64 / total_entries as f64;
                    let eta = elapsed / frac * (1.0 - frac);
                    eprint!("\r  \x1b[2m  {count}/{total_entries} entries ({:.0}%) ETA {eta:.0}s\x1b[0m     ", frac * 100.0);
                }

                ((row, col), val)
            })
            .collect();

        if dim > 200 {
            eprintln!();
        }

        let mut data = vec![0.0f64; dim * dim];
        for ((r, c), v) in entries {
            data[r * dim + c] = v;
            data[c * dim + r] = v;
        }

        eprintln!(
            "  \x1b[32m✓\x1b[0m Gram matrix built in {:.1}s",
            t0.elapsed().as_secs_f64()
        );

        Self {
            data,
            max_dim: dim,
            max_n,
            mpfr_built: true,
            precision: prec,
        }
    }

    /// Build using the FAST block-based algorithm, storing in DD precision.
    /// Returns (data_hi, data_lo) where each entry = hi + lo at ~31 digit accuracy.
    /// The MPFR-128 result is split: hi = f64(result), lo = f64(result - hi).
    pub fn build_fast_dd(max_n: usize, ln_n_table: &LnNTable) -> (Vec<f64>, Vec<f64>, usize) {
        let dim = max_n - 1;
        let total_entries = dim * (dim + 1) / 2;
        let mem_mb = (dim * dim * 16) / (1024 * 1024);
        let prec = ln_n_table.precision;
        let t0 = std::time::Instant::now();

        eprintln!("  \x1b[2m▸ Building {dim}×{dim} Gram matrix DD ({total_entries} entries, ~{mem_mb} MB)\x1b[0m");
        eprintln!("  \x1b[2m  Method: FAST block-based ({prec}-bit MPFR → DD pairs)\x1b[0m");

        let pairs: Vec<(usize, usize)> = (0..dim)
            .flat_map(|row| (row..dim).map(move |col| (row, col)))
            .collect();

        let done = std::sync::atomic::AtomicUsize::new(0);

        let entries: Vec<((usize, usize), (f64, f64))> = pairs
            .par_iter()
            .map(|&(row, col)| {
                let mpfr_val = gram_entry_fast(row + 2, col + 2, ln_n_table);
                let hi = mpfr_val.to_f64();
                // lo = exact_value - hi (captures the residual)
                let lo = {
                    let mut residual = mpfr_val;
                    residual -= hi;
                    residual.to_f64()
                };

                let count = done.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
                if dim > 200 && count % (total_entries / 100).max(1) == 0 && count > 0 {
                    let elapsed = t0.elapsed().as_secs_f64();
                    let frac = count as f64 / total_entries as f64;
                    let eta = elapsed / frac * (1.0 - frac);
                    eprint!("\r  \x1b[2m  {count}/{total_entries} entries ({:.0}%) ETA {eta:.0}s\x1b[0m     ", frac * 100.0);
                }

                ((row, col), (hi, lo))
            })
            .collect();

        if dim > 200 {
            eprintln!();
        }

        let mut data_hi = vec![0.0f64; dim * dim];
        let mut data_lo = vec![0.0f64; dim * dim];
        for ((r, c), (hi, lo)) in entries {
            data_hi[r * dim + c] = hi;
            data_hi[c * dim + r] = hi;
            data_lo[r * dim + c] = lo;
            data_lo[c * dim + r] = lo;
        }

        eprintln!(
            "  \x1b[32m✓\x1b[0m Gram matrix DD built in {:.1}s",
            t0.elapsed().as_secs_f64()
        );

        (data_hi, data_lo, dim)
    }

    /// Build full MPFR-precision Gram matrix (no f64 conversion).
    /// Returns (Vec<Float>, dim) where Float has `prec` bits.
    /// Used for MPFR Cholesky when DD precision (~31 digits) isn't enough.
    pub fn build_fast_mpfr(max_n: usize, ln_n_table: &LnNTable) -> (Vec<Float>, usize) {
        let dim = max_n - 1;
        let total_entries = dim * (dim + 1) / 2;
        let prec = ln_n_table.precision;
        let bytes_per = (prec as usize).div_ceil(8) + 16; // rough estimate
        let mem_mb = (dim * dim * bytes_per) / (1024 * 1024);
        let t0 = std::time::Instant::now();

        eprintln!("  \x1b[2m▸ Building {dim}×{dim} full MPFR Gram ({total_entries} entries, ~{mem_mb} MB)\x1b[0m");
        eprintln!("  \x1b[2m  Method: FAST block-based ({prec}-bit MPFR, full precision)\x1b[0m");

        let pairs: Vec<(usize, usize)> = (0..dim)
            .flat_map(|row| (row..dim).map(move |col| (row, col)))
            .collect();

        let done = std::sync::atomic::AtomicUsize::new(0);

        let entries: Vec<((usize, usize), Float)> = pairs
            .par_iter()
            .map(|&(row, col)| {
                let val = gram_entry_fast(row + 2, col + 2, ln_n_table);

                let count = done.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
                if dim > 200 && count % (total_entries / 100).max(1) == 0 && count > 0 {
                    let elapsed = t0.elapsed().as_secs_f64();
                    let frac = count as f64 / total_entries as f64;
                    let eta = elapsed / frac * (1.0 - frac);
                    eprint!("\r  \x1b[2m  {count}/{total_entries} entries ({:.0}%) ETA {eta:.0}s\x1b[0m     ", frac * 100.0);
                }

                ((row, col), val)
            })
            .collect();

        if dim > 200 {
            eprintln!();
        }

        let zero = Float::with_val(prec, 0.0);
        let mut data: Vec<Float> = vec![zero; dim * dim];
        for ((r, c), val) in entries {
            data[c * dim + r] = val.clone();
            data[r * dim + c] = val;
        }

        eprintln!(
            "  \x1b[32m✓\x1b[0m MPFR Gram matrix built in {:.1}s ({prec}-bit)",
            t0.elapsed().as_secs_f64()
        );

        (data, dim)
    }

    /// Build using double-double arithmetic (~31 digits, pure Rust).
    /// ~5-10x faster than MPFR for the same effective precision.
    pub fn build_dd(max_n: usize, dd_table: &DDLnTable) -> Self {
        let dim = max_n - 1;
        let total_entries = dim * (dim + 1) / 2;
        let mem_mb = (dim * dim * 8) / (1024 * 1024);
        let t0 = std::time::Instant::now();

        eprintln!("  \x1b[2m▸ Building {dim}×{dim} Gram matrix ({total_entries} unique entries, ~{mem_mb} MB)\x1b[0m");
        eprintln!("  \x1b[2m  Precision: double-double (~31 digits, pure Rust)\x1b[0m");

        let pairs: Vec<(usize, usize)> = (0..dim)
            .flat_map(|row| (row..dim).map(move |col| (row, col)))
            .collect();

        let done = std::sync::atomic::AtomicUsize::new(0);

        let entries: Vec<((usize, usize), f64)> = pairs
            .par_iter()
            .map(|&(row, col)| {
                let val = gram_entry_dd(row + 2, col + 2, dd_table);

                let count = done.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
                if dim > 200 && count % (total_entries / 100).max(1) == 0 && count > 0 {
                    let elapsed = t0.elapsed().as_secs_f64();
                    let frac = count as f64 / total_entries as f64;
                    let eta = elapsed / frac * (1.0 - frac);
                    eprint!("\r  \x1b[2m  {count}/{total_entries} entries ({:.0}%) ETA {eta:.0}s\x1b[0m     ", frac * 100.0);
                }

                ((row, col), val)
            })
            .collect();

        if dim > 200 {
            eprintln!();
        }

        let mut data = vec![0.0f64; dim * dim];
        for ((r, c), v) in entries {
            data[r * dim + c] = v;
            data[c * dim + r] = v;
        }

        eprintln!(
            "  \x1b[32m✓\x1b[0m Gram matrix built in {:.1}s",
            t0.elapsed().as_secs_f64()
        );

        Self {
            data,
            max_dim: dim,
            max_n,
            mpfr_built: false,
            precision: 106,
        }
    }

    /// Extract the (n-1)×(n-1) submatrix for G_n.
    /// This is FREE — just a view into the existing data.
    pub fn extract_submatrix(&self, n: usize) -> (Vec<f64>, usize) {
        assert!(
            n <= self.max_n,
            "Cannot extract N={n} from matrix built for N={}",
            self.max_n
        );
        let dim = n - 1;
        let mut sub = vec![0.0f64; dim * dim];
        for i in 0..dim {
            for j in 0..dim {
                sub[i * dim + j] = self.data[i * self.max_dim + j];
            }
        }
        (sub, dim)
    }

    /// Get a single entry G(j, k) from the stored matrix.
    #[allow(dead_code)]
    #[inline]
    pub fn get(&self, j: usize, k: usize) -> f64 {
        let i = j - 2;
        let l = k - 2;
        self.data[i * self.max_dim + l]
    }

    /// Memory usage in MB
    pub fn mem_mb(&self) -> usize {
        (self.data.len() * 8) / (1024 * 1024)
    }
}

// ═══════════════════════════════════════════════════════════════
// STREAMING UPPER-TRIANGLE-ONLY BUILDERS
//
// For large N where the full dim×dim matrix exceeds available RAM,
// these functions compute only the upper triangle directly.
//
// Memory comparison for N=83,160 (dim=83,159):
//   Full matrix:    55.3 GB (dim² × 8)
//   Upper triangle: 27.7 GB (dim(dim+1)/2 × 8)  ← half the RAM!
//
// For DD, upper triangle needs 55.4 GB (hi + lo) — tight but
// feasible on 64 GB machines.
// ═══════════════════════════════════════════════════════════════

/// Build only the upper triangle at f64 precision.
///
/// Returns a flat Vec<f64> of length dim*(dim+1)/2 in row-major
/// upper-triangle order: G[0,0], G[0,1], ..., G[0,dim-1], G[1,1], ...
///
/// This avoids the full dim×dim allocation, halving RAM usage.
pub fn build_upper_triangle_f64(max_n: usize) -> Vec<f64> {
    let dim = max_n - 1;
    let tri_len = dim * (dim + 1) / 2;
    let mem_mb = (tri_len * 8) / (1024 * 1024);
    let t0 = std::time::Instant::now();

    eprintln!(
        "  \x1b[2m▸ Building upper triangle (dim={dim}, {tri_len} entries, ~{mem_mb} MB)\x1b[0m"
    );
    eprintln!("  \x1b[2m  Method: f64 Kahan (streaming, no full matrix)\x1b[0m");

    let mut upper_tri = vec![0.0f64; tri_len];
    let done = std::sync::atomic::AtomicUsize::new(0);

    // Process row by row; within each row, parallelize over columns
    let mut offset = 0;
    for row in 0..dim {
        let len = dim - row;
        let slice = &mut upper_tri[offset..offset + len];

        slice.par_iter_mut().enumerate().for_each(|(i, val)| {
            let col = row + i;
            *val = gram_entry_f64(row + 2, col + 2);

            let count = done.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
            if count % (tri_len / 100).max(1) == 0 && count > 0 {
                let elapsed = t0.elapsed().as_secs_f64();
                let frac = count as f64 / tri_len as f64;
                let eta = elapsed / frac * (1.0 - frac);
                eprint!(
                    "\r  \x1b[2m  {count}/{tri_len} entries ({:.0}%) ETA {eta:.0}s\x1b[0m     ",
                    frac * 100.0
                );
            }
        });

        offset += len;
    }

    eprintln!(
        "\r  \x1b[32m✓\x1b[0m Upper triangle built in {:.1}s ({mem_mb} MB)          ",
        t0.elapsed().as_secs_f64()
    );
    upper_tri
}

/// Build only the upper triangle using the FAST block-based algorithm.
///
/// Returns (upper_tri_hi, upper_tri_lo, dim) where each entry = hi + lo
/// at ~31 digit accuracy. Uses O(T/j + T/k) per entry.
///
/// For N=83,160: uses ~55 GB (27.7 GB hi + 27.7 GB lo) instead of
/// 110 GB for two full dim×dim matrices.
pub fn build_upper_triangle_fast_dd(
    max_n: usize,
    ln_n_table: &LnNTable,
) -> (Vec<f64>, Vec<f64>, usize) {
    let dim = max_n - 1;
    let tri_len = dim * (dim + 1) / 2;
    let mem_mb = (tri_len * 16) / (1024 * 1024);
    let prec = ln_n_table.precision;
    let t0 = std::time::Instant::now();

    eprintln!(
        "  \x1b[2m▸ Building upper triangle DD (dim={dim}, {tri_len} entries, ~{mem_mb} MB)\x1b[0m"
    );
    eprintln!("  \x1b[2m  Method: FAST block-based ({prec}-bit MPFR → DD, streaming)\x1b[0m");

    let mut upper_tri_hi = vec![0.0f64; tri_len];
    let mut upper_tri_lo = vec![0.0f64; tri_len];
    let done = std::sync::atomic::AtomicUsize::new(0);

    // Process in row bands for better Rayon utilization
    let band_size = 256.min(dim);
    let mut offset = 0;

    for band_start in (0..dim).step_by(band_size) {
        let band_end = (band_start + band_size).min(dim);

        // Compute this band's entries in parallel
        let band_entries: Vec<Vec<(f64, f64)>> = (band_start..band_end)
            .into_par_iter()
            .map(|row| {
                (row..dim)
                    .map(|col| {
                        let mpfr_val = gram_entry_fast(row + 2, col + 2, ln_n_table);
                        let hi = mpfr_val.to_f64();
                        let lo = {
                            let mut residual = mpfr_val;
                            residual -= hi;
                            residual.to_f64()
                        };

                        let count = done.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
                        if count % (tri_len / 100).max(1) == 0 && count > 0 {
                            let elapsed = t0.elapsed().as_secs_f64();
                            let frac = count as f64 / tri_len as f64;
                            let eta = elapsed / frac * (1.0 - frac);
                            eprint!("\r  \x1b[2m  {count}/{tri_len} entries ({:.0}%) ETA {eta:.0}s\x1b[0m     ", frac * 100.0);
                        }

                        (hi, lo)
                    })
                    .collect()
            })
            .collect();

        // Write band results to upper triangle arrays
        for (local_row, row_entries) in band_entries.iter().enumerate() {
            for (i, &(hi, lo)) in row_entries.iter().enumerate() {
                upper_tri_hi[offset + i] = hi;
                upper_tri_lo[offset + i] = lo;
            }
            let row = band_start + local_row;
            offset += dim - row;
        }
    }

    eprintln!(
        "\r  \x1b[32m✓\x1b[0m Upper triangle DD built in {:.1}s ({mem_mb} MB)          ",
        t0.elapsed().as_secs_f64()
    );

    (upper_tri_hi, upper_tri_lo, dim)
}

// ═══════════════════════════════════════════════════════════════
// VALIDATION
// ═══════════════════════════════════════════════════════════════

/// Compare f64 vs MPFR Gram entries for a sample of (j,k) pairs.
/// Returns (max_relative_error, mean_relative_error).
pub fn validate_f64_vs_mpfr(n: usize, ln_table: &LnTable) -> (f64, f64) {
    let dim = n - 1;
    let mut pairs = Vec::new();
    for i in 0..dim.min(5) {
        for j in i..dim.min(5) {
            pairs.push((i + 2, j + 2));
        }
    }
    let mid = dim / 2 + 2;
    pairs.push((mid, mid));
    pairs.push((2, mid));
    pairs.push((mid, n));
    pairs.push((n - 1, n));
    pairs.push((n, n));
    pairs.dedup();

    let (mut max_rel, mut sum_rel, mut count) = (0.0f64, 0.0f64, 0usize);
    for (j, k) in &pairs {
        let f64_val = gram_entry_f64(*j, *k);
        let mpfr_val = gram_entry_mpfr(*j, *k, ln_table).to_f64();
        if mpfr_val.abs() > 1e-30 {
            let rel = ((f64_val - mpfr_val) / mpfr_val).abs();
            max_rel = max_rel.max(rel);
            sum_rel += rel;
            count += 1;
        }
    }
    (
        max_rel,
        if count > 0 {
            sum_rel / count as f64
        } else {
            0.0
        },
    )
}

// ═══════════════════════════════════════════════════════════════
// CONVENIENCE BUILDER: build_gram_matrix_f64
//
// Free function that builds a dense f64 Gram matrix in parallel.
// Replaces the duplicated `build_gram_f64(n)` in 12+ experiments.
// ═══════════════════════════════════════════════════════════════

/// Build a dense f64 Gram matrix G_N as a flat `Vec<f64>` (row-major).
///
/// Returns `(data, dim)` where `dim = n - 1` and indices map as
/// `data[i * dim + j] = G(i+2, j+2)`.
///
/// Uses rayon for parallel entry computation with Kahan-compensated
/// summation via [`gram_entry_f64`].
///
/// # Example
/// ```rust,no_run
/// let (mat, dim) = cathedral_utils::gram::build_gram_matrix_f64(100);
/// assert_eq!(dim, 99);
/// assert_eq!(mat.len(), 99 * 99);
/// ```
pub fn build_gram_matrix_f64(n: usize) -> (Vec<f64>, usize) {
    let dim = n - 1;
    let entries: Vec<((usize, usize), f64)> = (0..dim)
        .into_par_iter()
        .flat_map(|row| {
            (row..dim)
                .map(move |col| ((row, col), gram_entry_f64(row + 2, col + 2)))
                .collect::<Vec<_>>()
        })
        .collect();

    let mut mat = vec![0.0f64; dim * dim];
    for ((r, c), v) in entries {
        mat[r * dim + c] = v;
        mat[c * dim + r] = v;
    }
    (mat, dim)
}
