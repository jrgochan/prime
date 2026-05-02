//! ═══════════════════════════════════════════════════════════════════════════
//!  VASYUNIN GRAM FORMULA — 512-bit MPFR
//!
//!  Computes vasyuninGramFormula(a,b) from DigammaReflection.lean:
//!
//!    G(a,b) = (ln(2π) - γ)/2 · (1/a + 1/b)
//!           + (a - b)/(2ab) · ln(b/a)
//!           - π/(2ab) · (V(a,b) + V(b,a))
//!           - 1/(ab)
//!
//!  where V(a,b) = Σ_{m=1}^{a-1} {mb/a} · cot(πm/a)
//! ═══════════════════════════════════════════════════════════════════════════

use rug::Float;
use crate::series::{PREC, fp, fu};

fn euler_gamma() -> Float {
    Float::with_val(PREC, Float::parse(
        "0.57721566490153286060651209008240243104215933593992359880576723488486772677766467093694706329174674951463144724980708248096002660994734781858523379167699675108317261469978709305302790384075517494058752865137988627021838402797693994305675900571875993107680741340424965261263658754861789629453447100513915661453"
    ).unwrap())
}

/// V(a,b) = Σ_{m=1}^{a-1} {mb/a} · cot(πm/a)
fn vasyunin_cot_sum(a: usize, b: usize) -> Float {
    if a <= 1 { return Float::with_val(PREC, 0); }
    let af = fu(a);
    let bf = fu(b);
    let pi = Float::with_val(PREC, rug::float::Constant::Pi);
    let mut sum = Float::with_val(PREC, 0);
    for m in 1..a {
        let mf = fu(m);
        let mb = Float::with_val(PREC, &mf * &bf);
        let quot = Float::with_val(PREC, &mb / &af);
        let floor = Float::with_val(PREC, quot.clone().floor());
        let frac = Float::with_val(PREC, &quot - &floor);
        let angle = Float::with_val(PREC, Float::with_val(PREC, &pi * &mf) / &af);
        let cos_v = Float::with_val(PREC, angle.clone().cos());
        let sin_v = Float::with_val(PREC, angle.sin());
        if sin_v.is_zero() { continue; }
        let cot_v = Float::with_val(PREC, &cos_v / &sin_v);
        sum += Float::with_val(PREC, &frac * &cot_v);
    }
    sum
}

/// vasyuninGramFormula(a,b) — the closed-form target value.
pub fn vasyunin_gram_formula(a: usize, b: usize) -> Float {
    let af = fu(a);
    let bf = fu(b);
    let gamma = euler_gamma();
    let pi = Float::with_val(PREC, rug::float::Constant::Pi);
    let two_pi = Float::with_val(PREC, fp(2) * &pi);
    let l2p = Float::with_val(PREC, two_pi.ln());

    // Term 1: (ln(2π) - γ)/2 · (1/a + 1/b)
    let c = Float::with_val(PREC, &l2p - &gamma);
    let inv_sum = Float::with_val(PREC,
        Float::with_val(PREC, fp(1) / &af) + Float::with_val(PREC, fp(1) / &bf));
    let term1 = Float::with_val(PREC, Float::with_val(PREC, &c / fu(2)) * &inv_sum);

    // Term 2: (a-b)/(2ab) · ln(b/a)
    let ab = Float::with_val(PREC, &af * &bf);
    let diff = Float::with_val(PREC, &af - &bf);
    let log_ratio = Float::with_val(PREC, Float::with_val(PREC, &bf / &af).ln());
    let term2 = Float::with_val(PREC,
        Float::with_val(PREC, &diff * &log_ratio) / Float::with_val(PREC, &ab * fu(2)));

    // Term 3: -π/(2ab) · (V(a,b) + V(b,a))
    let v1 = vasyunin_cot_sum(a, b);
    let v2 = vasyunin_cot_sum(b, a);
    let v_sum = Float::with_val(PREC, &v1 + &v2);
    let term3 = Float::with_val(PREC,
        Float::with_val(PREC, &pi * &v_sum) / Float::with_val(PREC, &ab * fu(2)));

    // Term 4: -1/(ab)
    let term4 = Float::with_val(PREC, fp(1) / &ab);

    // G = term1 + term2 - term3 - term4
    let mut result = Float::with_val(PREC, &term1 + &term2);
    result -= &term3;
    result -= &term4;
    result
}
