//! ═══════════════════════════════════════════════════════════════════════════
//!  Vasyunin closed-form formula and special function evaluation
//! ═══════════════════════════════════════════════════════════════════════════

use rug::Float;
use crate::PREC;
use crate::compute::{fp, fu};
use cathedral_utils::arith::gcd;
use cathedral_utils::constants;

// ─────────────────────────────────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────────────────────────────────

/// Euler-Mascheroni constant γ at 512-bit precision (from precomputed digits).

/// log(2π) at MPFR precision.

/// Stirling constant: log(2π) - γ - 1.
pub fn stirling_const() -> Float {
    let l2p = constants::ln2pi_mpfr(PREC);
    let g = constants::euler_gamma_mpfr(PREC);
    Float::with_val(PREC, Float::with_val(PREC, &l2p - &g) - fp(1))
}

// ─────────────────────────────────────────────────────────────────────────
// VASYUNIN COTANGENT SUM
// ─────────────────────────────────────────────────────────────────────────

/// Vasyunin cotangent sum: V(a,b) = Σ_{m=1}^{a-1} {mb/a} · cot(πm/a).
///
/// For a=1, V = 0 (empty sum).
fn vasyunin_cot_sum(a: usize, b: usize) -> Float {
    if a <= 1 { return Float::with_val(PREC, 0); }
    let af = fu(a);
    let pi = Float::with_val(PREC, rug::float::Constant::Pi);
    let mut sum = Float::with_val(PREC, 0);
    for m in 1..a {
        let mb_mod_a = (m * b) % a;
        let frac = Float::with_val(PREC, Float::with_val(PREC, mb_mod_a as u64) / &af);
        let angle = Float::with_val(PREC, &pi * Float::with_val(PREC, m as u64) / &af);
        let cos_val = Float::with_val(PREC, angle.clone().cos());
        let sin_val = Float::with_val(PREC, angle.sin());
        if sin_val.is_zero() { continue; }
        let cot_val = Float::with_val(PREC, &cos_val / &sin_val);
        sum += Float::with_val(PREC, &frac * &cot_val);
    }
    sum
}

// ─────────────────────────────────────────────────────────────────────────
// VASYUNIN GRAM FORMULA
// ─────────────────────────────────────────────────────────────────────────

/// The Vasyunin closed-form formula for G(a,b) = ∫₀¹ {1/(ax)}{1/(bx)} dx.
///
/// For coprime a, b:
///   G(a,b) = (log(2π) - γ)/2 · (1/a + 1/b)
///          + (a-b)/(2ab) · log(b/a)
///          - πd/(2ab) · (V(a/d, b/d) + V(b/d, a/d))
///          - 1/(ab)
///
/// where d = gcd(a,b), V is the Vasyunin cotangent sum.
pub fn vasyunin_gram_formula(a: usize, b: usize) -> Float {
    let g = gcd(a, b);
    let a0 = a / g;
    let b0 = b / g;
    let af = fu(a);
    let bf = fu(b);
    let df = fu(g);
    let gamma = constants::euler_gamma_mpfr(PREC);
    let l2p = constants::ln2pi_mpfr(PREC);
    let pi = Float::with_val(PREC, rug::float::Constant::Pi);

    // Term 1: (log(2π)-γ)/2 · (1/a + 1/b)
    let half_coeff = Float::with_val(PREC, Float::with_val(PREC, &l2p - &gamma) / fu(2));
    let inv_sum = Float::with_val(PREC,
        Float::with_val(PREC, fp(1) / &af) + Float::with_val(PREC, fp(1) / &bf));
    let term1 = Float::with_val(PREC, &half_coeff * &inv_sum);

    // Term 2: (a-b)/(2ab) · ln(b/a)
    let ab = Float::with_val(PREC, &af * &bf);
    let diff = Float::with_val(PREC, &af - &bf);
    let ratio = Float::with_val(PREC, Float::with_val(PREC, &bf / &af).ln());
    let two_ab = Float::with_val(PREC, &ab * fu(2));
    let term2 = Float::with_val(PREC, Float::with_val(PREC, &diff * &ratio) / &two_ab);

    // Term 3: πd/(2ab) · (V(a/d, b/d) + V(b/d, a/d))
    let v1 = vasyunin_cot_sum(a0, b0);
    let v2 = vasyunin_cot_sum(b0, a0);
    let v_sum = Float::with_val(PREC, &v1 + &v2);
    let pi_d = Float::with_val(PREC, &pi * &df);
    let term3 = Float::with_val(PREC, Float::with_val(PREC, &pi_d * &v_sum) / &two_ab);

    // Term 4: 1/(ab)
    let term4 = Float::with_val(PREC, fp(1) / &ab);

    let sum12 = Float::with_val(PREC, &term1 + &term2);
    Float::with_val(PREC, Float::with_val(PREC, &sum12 - &term3) - &term4)
}

// ─────────────────────────────────────────────────────────────────────────
// FRACT TARGET (residue-class evaluation)
// ─────────────────────────────────────────────────────────────────────────

/// fractTarget(a,b) = Σ_{r=1}^{b-1} {ar/b} · (logΓ(r/b) - logΓ((r+1)/b) + (1/b)·ψ((r+1)/b))
///
/// Uses MPFR ln_gamma and digamma for high-precision evaluation.
pub fn fract_target(a: usize, b: usize) -> Float {
    let bf = fu(b);
    let mut sum = Float::with_val(PREC, 0);

    for r in 1..b {
        let rf = fu(r);
        let r1f = fu(r + 1);

        // {ar/b} = (ar mod b) / b
        let ar_mod_b = (a * r) % b;
        let frac = Float::with_val(PREC, fu(ar_mod_b) / &bf);

        // logΓ(r/b)
        let arg1 = Float::with_val(PREC, &rf / &bf);
        let lg1 = Float::with_val(PREC, arg1.ln_gamma());

        // logΓ((r+1)/b)
        let arg2 = Float::with_val(PREC, &r1f / &bf);
        let lg2 = Float::with_val(PREC, arg2.clone().ln_gamma());

        // ψ((r+1)/b) = digamma((r+1)/b)
        let psi = Float::with_val(PREC, arg2.digamma());

        // logΓ(r/b) - logΓ((r+1)/b) + (1/b)·ψ((r+1)/b)
        let lg_diff = Float::with_val(PREC, &lg1 - &lg2);
        let psi_term = Float::with_val(PREC, &psi / &bf);
        let bracket = Float::with_val(PREC, &lg_diff + &psi_term);

        sum += Float::with_val(PREC, &frac * &bracket);
    }
    sum
}
