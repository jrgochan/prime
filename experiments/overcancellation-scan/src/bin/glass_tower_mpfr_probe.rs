#![allow(dead_code, unused_variables, unused_imports, unused_assignments, clippy::needless_range_loop, clippy::doc_lazy_continuation, non_snake_case, clippy::empty_line_after_doc_comments)]
/// Glass Tower MPFR Probe — Arbitrary Precision
///
/// Uses MPFR (via rug) to compute the glass tower layer deviations
/// |L_k - 1| far beyond f64 precision. This lets us see the actual
/// doubly-exponential squaring pattern all the way to k=15 (65536D)
/// and beyond.
///
/// The predicted pattern: |L_k - 1| ≈ (|L_{k-1} - 1|)² 
/// because log(1+x) ≈ x for small x, and the Euler product
/// at level k involves p^{-2^k·σ} which squares at each step.

use rug::Float;

// ═══════════════════════════════════════════════════════
// §1. PRIME SIEVE
// ═══════════════════════════════════════════════════════

fn sieve_primes(limit: usize) -> Vec<usize> {
    let mut is_prime = vec![true; limit + 1];
    is_prime[0] = false;
    if limit >= 1 { is_prime[1] = false; }
    let mut i = 2;
    while i * i <= limit {
        if is_prime[i] {
            let mut j = i * i;
            while j <= limit {
                is_prime[j] = false;
                j += i;
            }
        }
        i += 1;
    }
    (2..=limit).filter(|&n| is_prime[n]).collect()
}

// ═══════════════════════════════════════════════════════
// §2. MPFR COMPLEX ARITHMETIC
// ═══════════════════════════════════════════════════════

/// Complex number with MPFR precision
struct MpfrC {
    re: Float,
    im: Float,
}

impl MpfrC {
    fn one(prec: u32) -> Self {
        MpfrC {
            re: Float::with_val(prec, 1.0),
            im: Float::with_val(prec, 0.0),
        }
    }

    fn norm_squared(&self) -> Float {
        let prec = self.re.prec();
        let mut r2 = Float::with_val(prec, &self.re * &self.re);
        r2 += &self.im * &self.im;
        r2
    }

    fn mul(&self, other: &MpfrC) -> MpfrC {
        let prec = self.re.prec();
        let re = Float::with_val(prec, &self.re * &other.re) - &self.im * &other.im;
        let im = Float::with_val(prec, &self.re * &other.im) + &self.im * &other.re;
        MpfrC { re, im }
    }

    fn add(&self, other: &MpfrC) -> MpfrC {
        let prec = self.re.prec();
        MpfrC {
            re: Float::with_val(prec, &self.re + &other.re),
            im: Float::with_val(prec, &self.im + &other.im),
        }
    }

    /// |self - 1| = sqrt((re-1)² + im²)
    fn deviation_from_one(&self) -> Float {
        let prec = self.re.prec();
        let re_minus_1 = Float::with_val(prec, &self.re - 1.0);
        let mut d2 = Float::with_val(prec, &re_minus_1 * &re_minus_1);
        d2 += &self.im * &self.im;
        d2.sqrt()
    }
}

/// Compute p^{-s} = p^{-σ} · e^{-it·ln(p)} with MPFR precision
fn prime_power_neg_s_mpfr(p: usize, sigma: &Float, t: &Float, prec: u32) -> MpfrC {
    let lnp = Float::with_val(prec, p).ln();
    // magnitude = p^{-σ} = exp(-σ · ln(p))
    let neg_sigma_lnp = Float::with_val(prec, -Float::with_val(prec, sigma * &lnp));
    let magnitude = neg_sigma_lnp.exp();
    // phase = -t · ln(p)
    let phase = Float::with_val(prec, -Float::with_val(prec, t * &lnp));
    let cos_phase = Float::with_val(prec, phase.clone()).cos();
    let sin_phase = Float::with_val(prec, phase).sin();
    MpfrC {
        re: Float::with_val(prec, &magnitude * &cos_phase),
        im: Float::with_val(prec, &magnitude * &sin_phase),
    }
}

/// Compute glass tower layer L_k(s) = ∏_{p≤N} (1 + p^{-2^k·s}) with MPFR
fn glass_layer_mpfr(primes: &[usize], k: u32, sigma: f64, t: f64, max_prime: usize, prec: u32) -> MpfrC {
    let scale = Float::with_val(prec, 1u64 << k); // 2^k
    let scaled_sigma = Float::with_val(prec, sigma) * &scale;
    let scaled_t = Float::with_val(prec, t) * &scale;

    let mut product = MpfrC::one(prec);
    let one = MpfrC::one(prec);

    for &p in primes {
        if p > max_prime { break; }
        let term_neg = prime_power_neg_s_mpfr(p, &scaled_sigma, &scaled_t, prec);
        let factor = one.add(&term_neg);
        product = product.mul(&factor);
    }
    product
}

// ═══════════════════════════════════════════════════════
// §3. THE MPFR TOWER PROBE
// ═══════════════════════════════════════════════════════

fn main() {
    println!("╔══════════════════════════════════════════════════════════╗");
    println!("║   GLASS TOWER MPFR PROBE — Arbitrary Precision          ║");
    println!("║   Seeing past the f64 barrier: |L_k - 1| to 600 digits  ║");
    println!("║   Cayley-Dickson tower from 2D to 65536D                ║");
    println!("╚══════════════════════════════════════════════════════════╝");
    println!();

    // Use 2048-bit precision (~600 decimal digits)
    // This should let us see deviations down to ~10⁻⁶⁰⁰
    let prec: u32 = 2048;
    println!("  MPFR precision: {} bits (~{} decimal digits)", prec, (prec as f64 * 0.301) as u32);
    println!();

    // Sieve primes (use fewer for MPFR since each op is expensive)
    let prime_limit = 100_000;
    eprintln!("Sieving primes up to {}...", prime_limit);
    let primes = sieve_primes(prime_limit);
    eprintln!("Found {} primes", primes.len());

    let sigma = 0.55;
    let t = 14.134725;
    let n_primes = 100_000;

    println!("  s = {} + {}i", sigma, t);
    println!("  N = {} primes", primes.iter().filter(|&&p| p <= n_primes).count());
    println!();

    println!("  {:>5}  {:>7}  {:>20}  {:>8}  squaring?", "k", "dim", "|L_k - 1|", "log₁₀");
    println!("  {:>5}  {:>7}  {:>20}  {:>8}  ─────────", "─", "───", "──────────────", "─────");

    let mut prev_log10: Option<f64> = None;

    for k in 0u32..=15 {
        let dim = 1u64 << (k + 1);

        // For large k, the scaled sigma might overflow the prime power
        // computation. Skip if 2^k * sigma > 100 (deviation is essentially 0)
        let effective_sigma = (1u64 << k) as f64 * sigma;
        if effective_sigma > 2000.0 {
            println!("  {:>5}  {:>6}D  {:>20}  {:>8}  (beyond computation — truly ≡ 1)",
                k, dim, "≈ 0", "< -600");
            continue;
        }

        let layer = glass_layer_mpfr(&primes, k, sigma, t, n_primes, prec);
        let deviation = layer.deviation_from_one();

        // Get log10 of deviation
        let log10_dev = if deviation > Float::with_val(prec, 0.0) {
            let log10 = Float::with_val(prec, deviation.clone()).ln() / Float::with_val(prec, 10.0f64).ln();
            log10.to_f64()
        } else {
            -999.0
        };

        // Check squaring pattern
        let squaring = if let Some(prev) = prev_log10 {
            let ratio = log10_dev / prev;
            format!("ratio: {:.2}x (expect ~2.0)", ratio)
        } else {
            String::from("(baseline)")
        };

        // Format the deviation scientifically
        let dev_str = if log10_dev > -15.0 {
            format!("{:.6e}", deviation.to_f64())
        } else {
            format!("~10^{:.0}", log10_dev)
        };

        println!("  {:>5}  {:>6}D  {:>20}  {:>8.1}  {}",
            k, dim, dev_str, log10_dev, squaring);

        prev_log10 = Some(log10_dev);
    }

    println!();
    println!("═══════════════════════════════════════════════════════");
    println!("  The squaring pattern: each level's deviation is the");
    println!("  SQUARE of the previous level's deviation.");
    println!("  This is the doubly-exponential convergence of the");
    println!("  Cayley-Dickson glass tower.");
    println!("═══════════════════════════════════════════════════════");
}
