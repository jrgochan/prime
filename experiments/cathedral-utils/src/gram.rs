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

// ═══════════════════════════════════════════════════════════════
// PRECOMPUTED LN TABLE
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
                if n == 0 { Float::with_val(p, 0) }
                else {
                    let nf = Float::with_val(p, n as u64);
                    let ratio = Float::with_val(p, Float::with_val(p, 1u32) + Float::with_val(p, Float::with_val(p, 1u32) / &nf));
                    ratio.ln()
                }
            })
            .collect();
        eprintln!("  \x1b[32m✓\x1b[0m ln table ready ({cap} entries, {:.1}s)", t0.elapsed().as_secs_f64());
        Self { values, max_n: cap, precision: p }
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
// UTILITIES
// ═══════════════════════════════════════════════════════════════

#[inline(always)]
fn fast_ln1p_inv(n: f64) -> f64 {
    if n < 32.0 { (1.0 + 1.0 / n).ln() }
    else {
        let x = 1.0 / n;
        x * (1.0 - x * (0.5 - x * (1.0/3.0 - x * (0.25 - x * (0.2 - x * (1.0/6.0))))))
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
    let t_direct = (lcm_jk * 3).max(2_000).min(50_000);

    let (mut total, mut comp) = (0.0f64, 0.0f64);
    for n in 1..=t_direct {
        let nf = n as f64;
        let a_int = n / j;
        let b_int = n / k;
        let ln_term = fast_ln1p_inv(nf);
        let ab_coeff = (a_int as f64) * inv_kf + (b_int as f64) * inv_jf;
        let ab_frac = if a_int > 0 && b_int > 0 {
            (a_int as f64) * (b_int as f64) / (nf * (nf + 1.0))
        } else { 0.0 };
        let term = inv_jk - ab_coeff * ln_term + ab_frac;
        let y = term - comp; let t = total + y; comp = (t - total) - y; total = t;
    }

    let d = g as f64;
    let tail_mean = 0.25 + d * d / (12.0 * jf * kf);
    let inv_t = 1.0 / t_direct as f64;
    total += tail_mean * inv_t + tail_mean * 0.5 * inv_t * inv_t + tail_mean * (1.0/6.0) * inv_t * inv_t * inv_t;
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
    let t_direct = (lcm_jk * 5).max(5_000).min(100_000).min(ln_table.max_n);

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
    total += Float::with_val(p, Float::with_val(p, &tail_mean * Float::with_val(p, 0.5f64)) * &inv_t2);
    let sixth = Float::with_val(p, Float::with_val(p, 1u32) / Float::with_val(p, 6u32));
    total += Float::with_val(p, Float::with_val(p, &tail_mean * &sixth) * &inv_t3);
    total
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
        eprintln!("  \x1b[2m  Precision: {}\x1b[0m", if use_mpfr { format!("{prec}-bit MPFR (precomputed ln)") } else { "f64 (Kahan summation)".to_string() });

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

        if dim > 200 { eprintln!(); }

        let mut data = vec![0.0f64; dim * dim];
        for ((r, c), v) in entries {
            data[r * dim + c] = v;
            data[c * dim + r] = v;
        }

        eprintln!("  \x1b[32m✓\x1b[0m Gram matrix built in {:.1}s", t0.elapsed().as_secs_f64());

        Self { data, max_dim: dim, max_n, mpfr_built: use_mpfr, precision: prec }
    }

    /// Extract the (n-1)×(n-1) submatrix for G_n.
    /// This is FREE — just a view into the existing data.
    pub fn extract_submatrix(&self, n: usize) -> (Vec<f64>, usize) {
        assert!(n <= self.max_n, "Cannot extract N={n} from matrix built for N={}", self.max_n);
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
// VALIDATION
// ═══════════════════════════════════════════════════════════════

/// Compare f64 vs MPFR Gram entries for a sample of (j,k) pairs.
/// Returns (max_relative_error, mean_relative_error).
pub fn validate_f64_vs_mpfr(n: usize, ln_table: &LnTable) -> (f64, f64) {
    let dim = n - 1;
    let mut pairs = Vec::new();
    for i in 0..dim.min(5) { for j in i..dim.min(5) { pairs.push((i + 2, j + 2)); } }
    let mid = dim / 2 + 2;
    pairs.push((mid, mid)); pairs.push((2, mid)); pairs.push((mid, n));
    pairs.push((n - 1, n)); pairs.push((n, n));
    pairs.dedup();

    let (mut max_rel, mut sum_rel, mut count) = (0.0f64, 0.0f64, 0usize);
    for (j, k) in &pairs {
        let f64_val = gram_entry_f64(*j, *k);
        let mpfr_val = gram_entry_mpfr(*j, *k, ln_table).to_f64();
        if mpfr_val.abs() > 1e-30 {
            let rel = ((f64_val - mpfr_val) / mpfr_val).abs();
            max_rel = max_rel.max(rel); sum_rel += rel; count += 1;
        }
    }
    (max_rel, if count > 0 { sum_rel / count as f64 } else { 0.0 })
}
