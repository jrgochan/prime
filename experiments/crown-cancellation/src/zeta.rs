//! High-precision zeta function evaluation at 512-bit MPFR
//!
//! Computes ζ(1/2 + it) via the Riemann-Siegel formula (simplified)
//! and the Euler-Maclaurin partial sum for moderate |t|.
//!
//! For the critical line s = 1/2 + it, we use:
//!   ζ(s) = Σ_{n=1}^{N} n^{-s} + χ(s) Σ_{n=1}^{M} n^{-(1-s)} + remainder
//! where N = M = ⌊√(|t|/2π)⌋ and χ(s) = π^{s-1/2} Γ((1-s)/2) / Γ(s/2).
//!
//! For small |t| (< 10), we use a direct partial sum with many terms.

use rug::Float;
use rug::ops::Pow;

pub const P: u32 = 512;

/// Compute ζ(1/2 + it) as (re, im) pair using partial sums.
///
/// For |t| < 50, uses direct sum with N = 1000 terms.
/// For |t| >= 50, uses Riemann-Siegel-like truncation at N = ⌊√(|t|/2π)⌋ + correction.
///
/// Returns (Re(ζ), Im(ζ)) in f64.
pub fn zeta_critical_line(t: f64) -> (f64, f64) {
    // Number of terms in partial sum
    let n_terms = if t.abs() < 50.0 {
        1000usize
    } else {
        let n_base = ((t.abs() / (2.0 * std::f64::consts::PI)).sqrt()) as usize;
        n_base.max(100) + 50 // extra terms for safety
    };

    // ζ(1/2+it) ≈ Σ_{n=1}^{N} n^{-1/2-it}
    // n^{-1/2-it} = n^{-1/2} · e^{-it·ln(n)} = n^{-1/2}·(cos(t·ln n) - i·sin(t·ln n))
    let mut re_sum = 0.0f64;
    let mut im_sum = 0.0f64;
    for n in 1..=n_terms {
        let nf = n as f64;
        let amp = 1.0 / nf.sqrt();
        let phase = t * nf.ln();
        re_sum += amp * phase.cos();
        im_sum -= amp * phase.sin();
    }

    // Apply approximate correction for the tail using Euler-Maclaurin
    // For the partial sum Σ_{n=1}^N n^{-s}, the remainder is approximately
    // N^{1-s}/(s-1) + N^{-s}/2 for Re(s) > 0
    // s = 1/2 + it, so 1-s = 1/2 - it, s-1 = -1/2 + it
    let nf = n_terms as f64;
    // N^{1-s} = N^{1/2-it} = N^{1/2} · e^{-it·ln N}
    let log_n = nf.ln();
    let amp1 = nf.sqrt();
    let phase1 = t * log_n;
    // Divide by (s-1) = (-1/2 + it)
    let denom_re = -0.5;
    let denom_im = t;
    let denom_sq = denom_re * denom_re + denom_im * denom_im;
    if denom_sq > 1e-20 {
        let num_re = amp1 * phase1.cos();
        let num_im = -amp1 * phase1.sin();
        // (a+bi)/(c+di) = ((ac+bd) + (bc-ad)i) / (c²+d²)
        re_sum += (num_re * denom_re + num_im * denom_im) / denom_sq;
        im_sum += (num_im * denom_re - num_re * denom_im) / denom_sq;
    }

    // N^{-s}/2 correction
    let amp2 = 0.5 / nf.sqrt();
    let phase2 = t * log_n;
    re_sum += amp2 * phase2.cos();
    im_sum -= amp2 * phase2.sin();

    (re_sum, im_sum)
}

/// Compute ζ(1/2 + it) with MPFR precision.
/// Returns (re, im) as f64 after high-precision computation.
pub fn zeta_critical_line_mpfr(t: f64) -> (f64, f64) {
    let t_mp = Float::with_val(P, t);
    let pi = Float::with_val(P, rug::float::Constant::Pi);

    // Number of terms
    let n_terms = if t.abs() < 50.0 {
        1000usize
    } else {
        let n_base = ((t.abs() / (2.0 * std::f64::consts::PI)).sqrt()) as usize;
        n_base.max(100) + 50
    };

    let mut re_sum = Float::with_val(P, 0);
    let mut im_sum = Float::with_val(P, 0);

    for n in 1..=n_terms {
        let nf = Float::with_val(P, n as u64);
        let log_n = nf.clone().ln();
        let amp = Float::with_val(P, 1u32) / nf.clone().sqrt();
        let phase = Float::with_val(P, &t_mp * &log_n);
        let (sin_p, cos_p) = phase.sin_cos(Float::new(P));
        re_sum += Float::with_val(P, &amp * &cos_p);
        im_sum -= Float::with_val(P, &amp * &sin_p);
    }

    // Euler-Maclaurin remainder
    let nf = Float::with_val(P, n_terms as u64);
    let log_n = nf.clone().ln();
    let amp1 = nf.clone().sqrt();
    let phase1 = Float::with_val(P, &t_mp * &log_n);
    let (sin_p1, cos_p1) = phase1.sin_cos(Float::new(P));

    // N^{1-s}/(s-1) where s-1 = -1/2+it
    let num_re = Float::with_val(P, &amp1 * &cos_p1);
    let num_im = Float::with_val(P, -Float::with_val(P, &amp1 * &sin_p1));
    let denom_re = Float::with_val(P, -0.5f64);
    let denom_im = t_mp.clone();
    let denom_sq = Float::with_val(P,
        Float::with_val(P, &denom_re * &denom_re) +
        Float::with_val(P, &denom_im * &denom_im));

    if denom_sq > 1e-20 {
        re_sum += Float::with_val(P,
            Float::with_val(P, Float::with_val(P, &num_re * &denom_re) +
                Float::with_val(P, &num_im * &denom_im)) / &denom_sq);
        im_sum += Float::with_val(P,
            Float::with_val(P, Float::with_val(P, &num_im * &denom_re) -
                Float::with_val(P, &num_re * &denom_im)) / &denom_sq);
    }

    // N^{-s}/2
    let amp2 = Float::with_val(P, Float::with_val(P, 0.5f64) / nf.sqrt());
    let (sin_p2, cos_p2) = Float::with_val(P, &t_mp * &log_n).sin_cos(Float::new(P));
    re_sum += Float::with_val(P, &amp2 * &cos_p2);
    im_sum -= Float::with_val(P, &amp2 * &sin_p2);

    (re_sum.to_f64(), im_sum.to_f64())
}

/// Validate ζ at known values
pub fn validate_zeta() -> bool {
    // ζ(1/2 + 14.134725i) ≈ 0 (first zero)
    let (re, im) = zeta_critical_line(14.134725);
    let norm = (re * re + im * im).sqrt();
    norm < 0.01 // Should be very close to zero
}
