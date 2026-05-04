//! 256-bit MPFR Riemann zeta and its derivative.
//!
//! Extracted from bc-zeta-lower. Provides:
//! - `zeta(s)` via Euler-Maclaurin with 8 correction terms
//! - `zeta_deriv(s)` via central finite difference
//! - `zeta_log_deriv(s)` = ζ'/ζ(s)

use rug::float::Round;
use rug::Float;
use std::f64::consts::PI;

pub const P: u32 = 256;

// ─── Complex arithmetic at 256-bit ───

pub type C256 = (Float, Float);

pub fn c_new(re: f64, im: f64) -> C256 {
    (Float::with_val(P, re), Float::with_val(P, im))
}

pub fn c_add(a: &C256, b: &C256) -> C256 {
    (Float::with_val(P, &a.0 + &b.0), Float::with_val(P, &a.1 + &b.1))
}

pub fn c_sub(a: &C256, b: &C256) -> C256 {
    (Float::with_val(P, &a.0 - &b.0), Float::with_val(P, &a.1 - &b.1))
}

pub fn c_mul(a: &C256, b: &C256) -> C256 {
    (
        Float::with_val(P, Float::with_val(P, &a.0 * &b.0) - Float::with_val(P, &a.1 * &b.1)),
        Float::with_val(P, Float::with_val(P, &a.0 * &b.1) + Float::with_val(P, &a.1 * &b.0)),
    )
}

pub fn c_div(a: &C256, b: &C256) -> C256 {
    let d = Float::with_val(P, Float::with_val(P, &b.0 * &b.0) + Float::with_val(P, &b.1 * &b.1));
    (
        Float::with_val(P, Float::with_val(P, Float::with_val(P, &a.0 * &b.0) + Float::with_val(P, &a.1 * &b.1)) / &d),
        Float::with_val(P, Float::with_val(P, Float::with_val(P, &a.1 * &b.0) - Float::with_val(P, &a.0 * &b.1)) / &d),
    )
}

pub fn c_scale(a: &C256, s: &Float) -> C256 {
    (Float::with_val(P, &a.0 * s), Float::with_val(P, &a.1 * s))
}

pub fn c_abs(z: &C256) -> Float {
    Float::with_val(P, (Float::with_val(P, &z.0 * &z.0) + Float::with_val(P, &z.1 * &z.1)).sqrt())
}

pub fn c_to_f64(z: &C256) -> (f64, f64) {
    (z.0.to_f64_round(Round::Nearest), z.1.to_f64_round(Round::Nearest))
}

fn c_pow_neg(n: usize, s: &C256) -> C256 {
    let ln_n = Float::with_val(P, Float::with_val(P, n as u64).ln());
    let re_exp = Float::with_val(P, -Float::with_val(P, &s.0 * &ln_n));
    let im_exp = Float::with_val(P, -Float::with_val(P, &s.1 * &ln_n));
    let mag = Float::with_val(P, re_exp.exp());
    let cos_v = Float::with_val(P, im_exp.clone().cos());
    let sin_v = Float::with_val(P, im_exp.sin());
    (Float::with_val(P, &mag * &cos_v), Float::with_val(P, &mag * &sin_v))
}

fn c_pochhammer(s: &C256, k: usize) -> C256 {
    let mut result = c_new(1.0, 0.0);
    for i in 0..k {
        let shift = c_new(i as f64, 0.0);
        let factor = c_add(s, &shift);
        result = c_mul(&result, &factor);
    }
    result
}

const BERNOULLI_NUM: [i64; 8] = [1, -1, 1, -1, 5, -691, 7, -3617];
const BERNOULLI_DEN: [i64; 8] = [6, 30, 42, 30, 66, 2730, 6, 510];

/// Compute ζ(s) via Euler-Maclaurin at 256-bit MPFR.
pub fn zeta_hp(s: &C256, n_terms: usize) -> C256 {
    let one = c_new(1.0, 0.0);
    let _half = c_new(0.5, 0.0);

    let mut sum = c_new(0.0, 0.0);
    for k in 1..=n_terms {
        sum = c_add(&sum, &c_pow_neg(k, s));
    }

    let one_minus_s = c_sub(&one, s);
    let ln_n = Float::with_val(P, Float::with_val(P, n_terms as u64).ln());
    let re_1ms = Float::with_val(P, &one_minus_s.0 * &ln_n);
    let im_1ms = Float::with_val(P, &one_minus_s.1 * &ln_n);
    let mag = Float::with_val(P, re_1ms.exp());
    let n_1ms = (Float::with_val(P, &mag * &Float::with_val(P, im_1ms.clone().cos())),
                 Float::with_val(P, &mag * &Float::with_val(P, im_1ms.sin())));
    let integral = c_div(&n_1ms, &c_sub(s, &one));

    let midpoint = c_scale(&c_pow_neg(n_terms, s), &Float::with_val(P, 0.5));

    let mut em = c_new(0.0, 0.0);
    for j in 0..8 {
        let two_k = 2 * (j + 1);
        let mut fact: f64 = 1.0;
        for i in 1..=two_k { fact *= i as f64; }
        let coeff = (BERNOULLI_NUM[j] as f64) / (BERNOULLI_DEN[j] as f64) / fact;
        let rising = c_pochhammer(s, two_k - 1);
        let shift = c_add(s, &c_new((two_k - 1) as f64, 0.0));
        let power = c_pow_neg(n_terms, &shift);
        em = c_add(&em, &c_scale(&c_mul(&rising, &power), &Float::with_val(P, coeff)));
    }

    c_add(&c_add(&c_add(&sum, &integral), &midpoint), &em)
}

/// Adaptive N based on |Im(s)|.
pub fn zeta(s_re: f64, s_im: f64) -> C256 {
    let n = std::cmp::max(200, (s_im.abs() / (2.0 * PI) * 1.5) as usize + 100);
    zeta_hp(&c_new(s_re, s_im), n)
}

/// |ζ(s)| as f64.
pub fn zeta_norm(s_re: f64, s_im: f64) -> f64 {
    c_abs(&zeta(s_re, s_im)).to_f64_round(Round::Nearest)
}

/// ζ'(s) via central difference: (ζ(s+h) - ζ(s-h)) / (2h) with h = 1e-8.
pub fn zeta_deriv(s_re: f64, s_im: f64) -> C256 {
    let h = 1e-8;
    // Differentiate in the real direction (Cauchy-Riemann: same as complex derivative)
    let zp = zeta(s_re + h, s_im);
    let zm = zeta(s_re - h, s_im);
    let diff = c_sub(&zp, &zm);
    c_scale(&diff, &Float::with_val(P, 1.0 / (2.0 * h)))
}

/// ζ'/ζ(s) = deriv(ζ)(s) / ζ(s), returned as (re, im) in f64.
pub fn zeta_log_deriv(s_re: f64, s_im: f64) -> (f64, f64) {
    let z = zeta(s_re, s_im);
    let zd = zeta_deriv(s_re, s_im);
    let ratio = c_div(&zd, &z);
    c_to_f64(&ratio)
}

/// |ζ'/ζ(s)| as f64.
pub fn zeta_log_deriv_norm(s_re: f64, s_im: f64) -> f64 {
    let (re, im) = zeta_log_deriv(s_re, s_im);
    (re * re + im * im).sqrt()
}
