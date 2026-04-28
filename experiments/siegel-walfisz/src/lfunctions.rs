// siegel-walfisz/src/lfunctions.rs
//
// L-function computation: L(s, χ) = Σ χ(n)/n^s
// 512-bit MPFR for critical computations

use rug::Float;
use rug::ops::Pow;
use crate::characters::chi8;

const PREC: u32 = 512;

/// Compute L(s, χᵢ) via direct summation Σ_{n=1}^{N} χᵢ(n)/n^s
/// using 512-bit MPFR.
/// Returns (L_value_re, L_value_im) — for real s, im = 0.
pub fn l_function_real(i: usize, s: f64, n_terms: usize) -> f64 {
    let mut sum = Float::with_val(PREC, 0.0);
    for n in 1..=n_terms {
        let chi_val = chi8(i, n);
        if chi_val == 0 {
            continue;
        }
        let n_f = Float::with_val(PREC, n as f64);
        let s_f = Float::with_val(PREC, s);
        let pow_val = Float::with_val(PREC, n_f.pow(&s_f));
        let term = pow_val;
        let inv = Float::with_val(PREC, 1.0) / &term;
        if chi_val == 1 {
            sum += &inv;
        } else {
            sum -= &inv;
        }
    }
    sum.to_f64()
}

/// Compute L(s, χᵢ) on the critical line s = 1/2 + it
/// via direct summation with 512-bit MPFR.
/// Returns |L(1/2+it, χ)|²
pub fn l_function_critical_line_sq(i: usize, t: f64, n_terms: usize) -> f64 {
    let mut sum_re = Float::with_val(PREC, 0.0);
    let mut sum_im = Float::with_val(PREC, 0.0);
    let half = Float::with_val(PREC, 0.5);

    for n in 1..=n_terms {
        let chi_val = chi8(i, n);
        if chi_val == 0 {
            continue;
        }
        let n_f = Float::with_val(PREC, n as f64);
        let ln_n = Float::with_val(PREC, n_f.clone().ln());

        // n^{1/2}
        let n_half = Float::with_val(PREC, n_f.pow(&half));
        let amplitude = Float::with_val(PREC, 1.0) / &n_half;

        // phase = -t·ln(n)
        let t_f = Float::with_val(PREC, t);
        let neg_t = Float::with_val(PREC, -&t_f);
        let phase = Float::with_val(PREC, &neg_t * &ln_n);
        let cos_phase = Float::with_val(PREC, phase.clone().cos());
        let sin_phase = Float::with_val(PREC, phase.sin());

        let re_term = Float::with_val(PREC, &amplitude * &cos_phase);
        let im_term = Float::with_val(PREC, &amplitude * &sin_phase);

        if chi_val == 1 {
            sum_re += &re_term;
            sum_im += &im_term;
        } else {
            sum_re -= &re_term;
            sum_im -= &im_term;
        }
    }

    let re = sum_re.to_f64();
    let im = sum_im.to_f64();
    re * re + im * im
}

/// Verify the zero-free region: check that |L(σ+it, χ)| > 0
/// for σ ≥ 1 - c/log(|t|+2) at sampled points.
/// Returns (all_nonzero, min_abs_value, min_point_sigma, min_point_t)
pub fn verify_zero_free_region(
    i: usize,
    c: f64,
    t_samples: &[f64],
    n_terms: usize,
) -> (bool, f64, f64, f64) {
    let mut min_val = f64::INFINITY;
    let mut min_sigma = 0.0;
    let mut min_t = 0.0;
    let mut all_ok = true;

    for &t in t_samples {
        let sigma = 1.0 - c / (t.abs() + 2.0).ln();
        if sigma <= 0.5 {
            continue; // below critical line, not relevant
        }
        let l_sq = l_function_at_sigma_t(i, sigma, t, n_terms);
        if l_sq < min_val {
            min_val = l_sq;
            min_sigma = sigma;
            min_t = t;
        }
        if l_sq < 1e-20 {
            all_ok = false;
        }
    }
    (all_ok, min_val.sqrt(), min_sigma, min_t)
}

/// Compute |L(σ+it, χ)|² via direct summation
fn l_function_at_sigma_t(i: usize, sigma: f64, t: f64, n_terms: usize) -> f64 {
    let mut sum_re = 0.0f64;
    let mut sum_im = 0.0f64;

    for n in 1..=n_terms {
        let chi_val = chi8(i, n) as f64;
        if chi_val == 0.0 {
            continue;
        }
        let ln_n = (n as f64).ln();
        let amplitude = chi_val * (-(sigma) * ln_n).exp();
        let phase = -t * ln_n;
        sum_re += amplitude * phase.cos();
        sum_im += amplitude * phase.sin();
    }
    sum_re * sum_re + sum_im * sum_im
}
