//! ═══════════════════════════════════════════════════════════════════════════
//!  Prime Harmonics Engine
//!
//!  Computational twin of `Cathedral/Spectral/PrimeHarmonics.lean`.
//!
//!  Each prime p is a spinning oscillator on the critical line:
//!  - **Phase**: `e^{-it·log(p)}` (unit circle)
//!  - **Amplitude**: `p^{-σ}` (at σ = ½: `1/√p`)
//!  - **Winding**: `t·log(p)/(2π)` (complete rotations)
//!
//!  The core type [`PrimeOscillatorBank`] precomputes `log(p)` and `1/√p`
//!  for fast evaluation of interference sums across a range of heights.
//!
//!  ## Lean Correspondence
//!
//!  | Lean definition              | Rust function                        |
//!  |------------------------------|--------------------------------------|
//!  | `primeOscillator p t`        | `PrimeOscillatorBank::oscillator()`  |
//!  | `windingCount p t`           | `PrimeOscillatorBank::winding()`     |
//!  | `amplitude p σ`              | `PrimeOscillatorBank::amplitude()`   |
//!  | `dampedOscillator p t`       | `PrimeOscillatorBank::damped()`      |
//!  | `interferenceSumOver ps t`   | `PrimeOscillatorBank::interference()`|
//! ═══════════════════════════════════════════════════════════════════════════

use rayon::prelude::*;
use std::f64::consts::PI;

// ═══════════════════════════════════════════════════════════════════
// SEGMENTED SIEVE — Memory-efficient prime enumeration for 10B+ scale
// ═══════════════════════════════════════════════════════════════════

/// Segmented sieve of Eratosthenes — enumerate all primes up to `limit`.
///
/// Uses O(√N) memory for the small-prime sieve, plus O(segment_size) working
/// memory per segment. Returns the full list of primes.
///
/// At 10B this uses ~1 MB working memory instead of 10 GB for a flat sieve.
pub fn segmented_sieve(limit: usize) -> Vec<usize> {
    if limit < 2 {
        return vec![];
    }

    // For small limits, fall back to flat sieve
    if limit <= 10_000_000 {
        let sieve = crate::arith::sieve_primes(limit);
        return (2..=limit).filter(|&n| sieve[n]).collect();
    }

    let sqrt_limit = (limit as f64).sqrt() as usize + 1;

    // Phase 1: sieve small primes up to √limit
    let small_sieve = crate::arith::sieve_primes(sqrt_limit);
    let small_primes: Vec<usize> = (2..=sqrt_limit).filter(|&n| small_sieve[n]).collect();

    // Start with small primes
    let mut primes = small_primes.clone();

    // Phase 2: segmented sieve in parallel chunks
    let segment_size: usize = 1 << 20; // 1M per segment (~1 MB)
    let num_segments = (limit - sqrt_limit) / segment_size + 1;

    // Process segments in parallel, collect results
    let mut segment_primes: Vec<Vec<usize>> = (0..num_segments)
        .into_par_iter()
        .map(|seg_idx| {
            let seg_start = sqrt_limit + 1 + seg_idx * segment_size;
            let seg_end = (seg_start + segment_size - 1).min(limit);
            if seg_start > limit {
                return vec![];
            }

            let seg_len = seg_end - seg_start + 1;
            let mut is_prime = vec![true; seg_len];

            for &p in &small_primes {
                // Find first multiple of p >= seg_start
                let start = if seg_start.is_multiple_of(p) {
                    seg_start
                } else {
                    seg_start + p - (seg_start % p)
                };
                let start = if start == p { start + p } else { start };

                let mut j = start;
                while j <= seg_end {
                    is_prime[j - seg_start] = false;
                    j += p;
                }
            }

            let mut local_primes = Vec::new();
            for i in 0..seg_len {
                if is_prime[i] {
                    local_primes.push(seg_start + i);
                }
            }
            local_primes
        })
        .collect();

    // Merge in order
    for seg in &mut segment_primes {
        primes.append(seg);
    }

    primes
}

// ═══════════════════════════════════════════════════════════════════
// CORE TYPES
// ═══════════════════════════════════════════════════════════════════

/// A single prime's phase state at a given height.
#[derive(Debug, Clone)]
pub struct PrimePhase {
    /// The prime number
    pub p: usize,
    /// log(p)
    pub log_p: f64,
    /// Amplitude: p^{-σ} (at σ=½: 1/√p)
    pub amplitude: f64,
    /// Winding count: t·log(p)/(2π)
    pub winding: f64,
    /// Fractional part of winding (position on unit circle, 0..1)
    pub frac_winding: f64,
    /// Real part of damped oscillator
    pub phase_re: f64,
    /// Imaginary part of damped oscillator
    pub phase_im: f64,
    /// Cumulative interference norm after adding this prime
    pub cumulative_norm: f64,
    /// Change in norm from previous prime
    pub delta_norm: f64,
}

/// Precomputed prime oscillator bank for fast interference computation.
///
/// Stores `log(p)` and `1/√p` for each prime, avoiding redundant computation
/// when sweeping over many heights.
///
/// # Example
///
/// ```rust
/// use cathedral_utils::harmonics::PrimeOscillatorBank;
///
/// let bank = PrimeOscillatorBank::new(10_000);
/// println!("Loaded {} primes", bank.len());
///
/// // Interference at the first zeta zero
/// let (re, im) = bank.interference(14.134725, bank.len());
/// let norm = (re * re + im * im).sqrt();
/// println!("|Σ| at t₀ = {:.6}", norm);
/// ```
pub struct PrimeOscillatorBank {
    /// The prime numbers
    pub primes: Vec<usize>,
    /// log(p) for each prime (precomputed for speed)
    pub log_p: Vec<f64>,
    /// 1/√p for each prime (amplitude at σ = ½)
    pub inv_sqrt_p: Vec<f64>,
}

impl PrimeOscillatorBank {
    /// Create a new oscillator bank with all primes up to `limit`.
    ///
    /// For limits up to 10M, uses the flat sieve from `arith`.
    /// For larger limits (100M+), uses a parallel segmented sieve.
    pub fn new(limit: usize) -> Self {
        let primes = segmented_sieve(limit);
        let log_p: Vec<f64> = primes.par_iter().map(|&p| (p as f64).ln()).collect();
        let inv_sqrt_p: Vec<f64> = primes
            .par_iter()
            .map(|&p| 1.0 / (p as f64).sqrt())
            .collect();

        PrimeOscillatorBank {
            primes,
            log_p,
            inv_sqrt_p,
        }
    }

    /// Create from a pre-built list of primes.
    pub fn from_primes(primes: Vec<usize>) -> Self {
        let log_p: Vec<f64> = primes.par_iter().map(|&p| (p as f64).ln()).collect();
        let inv_sqrt_p: Vec<f64> = primes
            .par_iter()
            .map(|&p| 1.0 / (p as f64).sqrt())
            .collect();
        PrimeOscillatorBank {
            primes,
            log_p,
            inv_sqrt_p,
        }
    }

    /// Number of primes in the bank.
    #[inline]
    pub fn len(&self) -> usize {
        self.primes.len()
    }

    /// Whether the bank is empty.
    #[inline]
    pub fn is_empty(&self) -> bool {
        self.primes.is_empty()
    }

    // ═══════════════════════════════════════════════════════════════
    // SINGLE-PRIME FUNCTIONS
    // ═══════════════════════════════════════════════════════════════

    /// Pure oscillator: e^{-it·log(p)} = (cos(θ), sin(θ))
    ///
    /// Corresponds to `primeOscillator p t` in Lean.
    #[inline(always)]
    pub fn oscillator(&self, idx: usize, t: f64) -> (f64, f64) {
        let phase = -t * self.log_p[idx];
        (phase.cos(), phase.sin())
    }

    /// Winding count: t·log(p)/(2π) — number of complete rotations.
    ///
    /// Corresponds to `windingCount p t` in Lean.
    #[inline(always)]
    pub fn winding(&self, idx: usize, t: f64) -> f64 {
        t * self.log_p[idx] / (2.0 * PI)
    }

    /// Amplitude at real part σ: p^{-σ}.
    ///
    /// Corresponds to `amplitude p σ` in Lean.
    #[inline]
    pub fn amplitude(&self, idx: usize, sigma: f64) -> f64 {
        (self.primes[idx] as f64).powf(-sigma)
    }

    /// Damped oscillator on critical line: (1/√p)·e^{-it·log(p)}.
    ///
    /// Corresponds to `dampedOscillator p t` in Lean.
    #[inline(always)]
    pub fn damped(&self, idx: usize, t: f64) -> (f64, f64) {
        let (re, im) = self.oscillator(idx, t);
        (self.inv_sqrt_p[idx] * re, self.inv_sqrt_p[idx] * im)
    }

    // ═══════════════════════════════════════════════════════════════
    // INTERFERENCE SUMS — SEQUENTIAL
    // ═══════════════════════════════════════════════════════════════

    /// Interference sum using first `n` primes: Σ_{k=0}^{n-1} damped(k, t).
    ///
    /// Returns (Re, Im) of the complex sum.
    /// Corresponds to `interferenceSumOver primes t` in Lean.
    pub fn interference(&self, t: f64, n: usize) -> (f64, f64) {
        let n = n.min(self.len());
        let mut sum_re = 0.0;
        let mut sum_im = 0.0;
        for i in 0..n {
            let phase = -t * self.log_p[i];
            sum_re += self.inv_sqrt_p[i] * phase.cos();
            sum_im += self.inv_sqrt_p[i] * phase.sin();
        }
        (sum_re, sum_im)
    }

    /// |interference sum| using first `n` primes.
    pub fn interference_norm(&self, t: f64, n: usize) -> f64 {
        let (re, im) = self.interference(t, n);
        (re * re + im * im).sqrt()
    }

    /// |interference sum| using ALL primes in the bank.
    #[inline]
    pub fn interference_norm_all(&self, t: f64) -> f64 {
        self.interference_norm(t, self.len())
    }

    /// Maximum constructive interference (at t=0): Σ 1/√p.
    pub fn max_interference(&self, n: usize) -> f64 {
        self.inv_sqrt_p[..n.min(self.len())].iter().sum()
    }

    // ═══════════════════════════════════════════════════════════════
    // INTERFERENCE SUMS — PARALLEL (LUDICROUS MODE)
    //
    // Split the prime sum across all available cores.
    // Each core computes a partial (Re, Im) sum, then reduce.
    // ═══════════════════════════════════════════════════════════════

    /// Parallel interference sum using ALL primes.
    ///
    /// Splits the prime array across cores via rayon.
    /// Each chunk computes a partial sum, then they're reduced.
    /// ~12x faster on M2 Max (8P + 4E cores).
    pub fn interference_par(&self, t: f64) -> (f64, f64) {
        // Chunk size tuned for L1 cache: 64KB / (8+8) bytes ≈ 4096 entries
        let chunk = 4096;
        self.log_p
            .par_chunks(chunk)
            .zip(self.inv_sqrt_p.par_chunks(chunk))
            .map(|(logs, amps)| {
                let mut re = 0.0f64;
                let mut im = 0.0f64;
                for i in 0..logs.len() {
                    let phase = -t * logs[i];
                    re += amps[i] * phase.cos();
                    im += amps[i] * phase.sin();
                }
                (re, im)
            })
            .reduce(|| (0.0, 0.0), |(r1, i1), (r2, i2)| (r1 + r2, i1 + i2))
    }

    /// Parallel |interference| using ALL primes.
    pub fn interference_norm_par(&self, t: f64) -> f64 {
        let (re, im) = self.interference_par(t);
        (re * re + im * im).sqrt()
    }

    /// Maximum interference computed in parallel.
    pub fn max_interference_par(&self) -> f64 {
        self.inv_sqrt_p
            .par_chunks(4096)
            .map(|chunk| chunk.iter().sum::<f64>())
            .sum()
    }

    // ═══════════════════════════════════════════════════════════════
    // PARALLEL SWEEPS
    // ═══════════════════════════════════════════════════════════════

    /// Parallel energy sweep: each height evaluated independently across cores.
    ///
    /// For large prime banks (>100K primes), this gives ~12x speedup.
    pub fn energy_sweep_par(&self, t_start: f64, t_end: f64, steps: usize) -> Vec<(f64, f64)> {
        let dt = (t_end - t_start) / steps as f64;
        (0..=steps)
            .into_par_iter()
            .map(|step| {
                let t = t_start + dt * step as f64;
                (t, self.interference_norm_par(t))
            })
            .collect()
    }

    /// Parallel minima finding.
    ///
    /// Step 1: parallel sweep to get all norms.
    /// Step 2: sequential scan for local minima.
    pub fn find_minima_par(
        &self,
        t_start: f64,
        t_end: f64,
        steps: usize,
        threshold_frac: f64,
    ) -> Vec<(f64, f64)> {
        let dt = (t_end - t_start) / steps as f64;
        let threshold = self.max_interference_par() * threshold_frac;

        // Parallel evaluation of ALL heights at once
        let norms: Vec<f64> = (0..=steps)
            .into_par_iter()
            .map(|step| {
                let t = t_start + dt * step as f64;
                self.interference_norm_par(t)
            })
            .collect();

        // Sequential local-minima scan
        let mut minima = Vec::new();
        for i in 1..norms.len().saturating_sub(1) {
            if norms[i] < norms[i - 1] && norms[i] < norms[i + 1] && norms[i] < threshold {
                let t = t_start + dt * i as f64;
                minima.push((t, norms[i]));
            }
        }
        minima
    }

    // ═══════════════════════════════════════════════════════════════
    // PHASE PORTRAIT (sequential — inherently cumulative)
    // ═══════════════════════════════════════════════════════════════

    /// Compute the full phase portrait at height `t` for the first `n` primes.
    ///
    /// Returns a vector of [`PrimePhase`] structs showing each prime's
    /// contribution and the cumulative interference norm.
    pub fn phase_portrait(&self, t: f64, n: usize) -> Vec<PrimePhase> {
        let n = n.min(self.len());
        let mut result = Vec::with_capacity(n);
        let mut cum_re = 0.0;
        let mut cum_im = 0.0;
        let mut prev_norm = 0.0;

        for i in 0..n {
            let w = self.winding(i, t);
            let (damp_re, damp_im) = self.damped(i, t);
            cum_re += damp_re;
            cum_im += damp_im;
            let norm = (cum_re * cum_re + cum_im * cum_im).sqrt();

            result.push(PrimePhase {
                p: self.primes[i],
                log_p: self.log_p[i],
                amplitude: self.inv_sqrt_p[i],
                winding: w,
                frac_winding: w - w.floor(),
                phase_re: damp_re,
                phase_im: damp_im,
                cumulative_norm: norm,
                delta_norm: norm - prev_norm,
            });
            prev_norm = norm;
        }
        result
    }

    // ═══════════════════════════════════════════════════════════════
    // NON-PARALLEL SWEEPS (kept for small-bank fast path)
    // ═══════════════════════════════════════════════════════════════

    /// Sweep the interference norm over a range of heights (sequential).
    pub fn energy_sweep(&self, t_start: f64, t_end: f64, steps: usize) -> Vec<(f64, f64)> {
        let dt = (t_end - t_start) / steps as f64;
        (0..=steps)
            .map(|step| {
                let t = t_start + dt * step as f64;
                (t, self.interference_norm_all(t))
            })
            .collect()
    }

    /// Sweep returning full complex values: (t, Re, Im, |Σ|).
    pub fn energy_sweep_complex(
        &self,
        t_start: f64,
        t_end: f64,
        steps: usize,
    ) -> Vec<(f64, f64, f64, f64)> {
        let dt = (t_end - t_start) / steps as f64;
        (0..=steps)
            .map(|step| {
                let t = t_start + dt * step as f64;
                let (re, im) = self.interference(t, self.len());
                let norm = (re * re + im * im).sqrt();
                (t, re, im, norm)
            })
            .collect()
    }

    /// Find local minima (sequential version).
    pub fn find_minima(
        &self,
        t_start: f64,
        t_end: f64,
        steps: usize,
        threshold_frac: f64,
    ) -> Vec<(f64, f64)> {
        let dt = (t_end - t_start) / steps as f64;
        let threshold = self.max_interference(self.len()) * threshold_frac;
        let mut minima = Vec::new();

        let mut prev_prev = self.interference_norm_all(t_start);
        let mut prev = self.interference_norm_all(t_start + dt);

        for step in 2..=steps {
            let t = t_start + dt * step as f64;
            let curr = self.interference_norm_all(t);

            if prev < curr && prev < prev_prev && prev < threshold {
                minima.push((t_start + dt * (step - 1) as f64, prev));
            }

            prev_prev = prev;
            prev = curr;
        }
        minima
    }
}

// ═══════════════════════════════════════════════════════════════════
// UTILITY FUNCTIONS
// ═══════════════════════════════════════════════════════════════════

/// Compute continued fraction expansion of a real number.
///
/// Returns the first `max_terms` coefficients [a₀; a₁, a₂, ...].
/// For irrational numbers (like log(p₁)/log(p₂) for distinct primes),
/// the expansion never terminates.
pub fn continued_fraction(x: f64, max_terms: usize) -> Vec<i64> {
    let mut coeffs = Vec::new();
    let mut val = x;
    for _ in 0..max_terms {
        let a = val.floor() as i64;
        coeffs.push(a);
        let frac = val - a as f64;
        if frac.abs() < 1e-12 {
            break;
        }
        val = 1.0 / frac;
        if val.abs() > 1e12 {
            break;
        }
    }
    coeffs
}

/// Golden-section search for the minimum of `f` on `[a, b]`.
///
/// Returns `(x_min, f(x_min))` accurate to `tol`.
pub fn golden_section_min<F: Fn(f64) -> f64>(f: &F, a: f64, b: f64, tol: f64) -> (f64, f64) {
    let gr = (5.0_f64.sqrt() - 1.0) / 2.0;
    let mut a = a;
    let mut b = b;
    let mut c = b - gr * (b - a);
    let mut d = a + gr * (b - a);
    let mut fc = f(c);
    let mut fd = f(d);

    while (b - a).abs() > tol {
        if fc < fd {
            b = d;
            d = c;
            fd = fc;
            c = b - gr * (b - a);
            fc = f(c);
        } else {
            a = c;
            c = d;
            fc = fd;
            d = a + gr * (b - a);
            fd = f(d);
        }
    }
    let x = (a + b) / 2.0;
    (x, f(x))
}

// ═══════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_bank_creation() {
        let bank = PrimeOscillatorBank::new(100);
        assert_eq!(bank.primes[0], 2);
        assert_eq!(bank.primes[1], 3);
        assert_eq!(bank.primes[2], 5);
        assert_eq!(bank.len(), 25); // π(100) = 25
    }

    #[test]
    fn test_oscillator_unit_norm() {
        let bank = PrimeOscillatorBank::new(100);
        for i in 0..bank.len() {
            let (re, im) = bank.oscillator(i, 42.0);
            let norm = (re * re + im * im).sqrt();
            assert!(
                (norm - 1.0).abs() < 1e-14,
                "Oscillator norm = {}, expected 1.0",
                norm
            );
        }
    }

    #[test]
    fn test_constructive_at_zero() {
        // At t=0, all oscillators point east: sum = Σ 1/√p
        let bank = PrimeOscillatorBank::new(100);
        let expected: f64 = bank.inv_sqrt_p.iter().sum();
        let actual = bank.interference_norm_all(0.0);
        assert!(
            (actual - expected).abs() < 1e-10,
            "At t=0: got {}, expected {}",
            actual,
            expected
        );
    }

    #[test]
    fn test_winding_at_zero() {
        let bank = PrimeOscillatorBank::new(100);
        assert!((bank.winding(0, 0.0)).abs() < 1e-15);
    }

    #[test]
    fn test_phase_portrait() {
        let bank = PrimeOscillatorBank::new(100);
        let portrait = bank.phase_portrait(14.134725, 10);
        assert_eq!(portrait.len(), 10);
        assert_eq!(portrait[0].p, 2);
        assert!((portrait[0].amplitude - 1.0 / 2.0_f64.sqrt()).abs() < 1e-10);
    }

    #[test]
    fn test_continued_fraction_rational() {
        // 3/2 = [1; 2]
        let cf = continued_fraction(1.5, 10);
        assert_eq!(cf, vec![1, 2]);
    }

    #[test]
    fn test_continued_fraction_sqrt2() {
        // √2 = [1; 2, 2, 2, ...]
        let cf = continued_fraction(2.0_f64.sqrt(), 6);
        assert_eq!(cf[0], 1);
        for &a in &cf[1..] {
            assert_eq!(a, 2);
        }
    }

    #[test]
    fn test_golden_section() {
        // Minimum of (x - 3)² on [0, 10]
        let (x, _fx) = golden_section_min(&|x: f64| (x - 3.0).powi(2), 0.0, 10.0, 1e-10);
        assert!((x - 3.0).abs() < 1e-8);
    }
}
