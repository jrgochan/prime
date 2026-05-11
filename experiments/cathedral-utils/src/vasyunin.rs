//! Vasyunin cotangent formula for Gram matrix entries.
//!
//! The Vasyunin formula expresses G(j,k) as a cotangent sum,
//! providing an independent verification path for the direct
//! series computation in `gram.rs`.

use crate::arith;

/// Gram entry via Vasyunin cotangent formula.
///
/// G(j,k) = (gcd(j,k))² / (2·j·k) · Σ_{m=1}^{lcm-1} cot(πm/j)·cot(πm/k) / lcm
///
/// This is numerically less stable than the direct series for large j,k
/// but provides a valuable cross-check.
pub fn gram_entry_vasyunin(j: usize, k: usize) -> f64 {
    let g = arith::gcd(j, k);
    let l = arith::lcm(j, k);
    if l == 0 {
        return 0.0;
    }

    let mut sum = 0.0f64;
    for m in 1..l {
        let cot_j = cot(std::f64::consts::PI * m as f64 / j as f64);
        let cot_k = cot(std::f64::consts::PI * m as f64 / k as f64);
        sum += cot_j * cot_k;
    }

    let g2 = (g * g) as f64;
    let jk2 = 2.0 * (j as f64) * (k as f64);
    g2 / jk2 * sum / l as f64
}

/// Cotangent function: cot(x) = cos(x)/sin(x).
#[inline]
fn cot(x: f64) -> f64 {
    let s = x.sin();
    if s.abs() < 1e-30 {
        0.0
    } else {
        x.cos() / s
    }
}

/// Digamma-based Gram entry (alternative formula via log-digamma bridge).
///
/// Uses ψ(x) = -γ + Σ_{n=1}^∞ (1/n - 1/(n+x-1)) for cross-verification.
pub fn gram_entry_digamma(j: usize, k: usize) -> f64 {
    let jf = j as f64;
    let kf = k as f64;
    let g = arith::gcd(j, k) as f64;

    // Simplified digamma-based formula for small j,k
    let mut sum = 0.0f64;
    let t_max = 10_000;
    for n in 1..=t_max {
        let nf = n as f64;
        let term = 1.0 / (jf * kf)
            - (n / j) as f64 / kf * (1.0 + 1.0 / nf).ln()
            - (n / k) as f64 / jf * (1.0 + 1.0 / nf).ln()
            + if n / j > 0 && n / k > 0 {
                (n / j) as f64 * (n / k) as f64 / (nf * (nf + 1.0))
            } else {
                0.0
            };
        sum += term;
    }

    // Tail correction
    let tail = 0.25 + g * g / (12.0 * jf * kf);
    sum += tail / t_max as f64;
    sum
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_digamma_reasonable() {
        // Verify digamma formula produces reasonable positive values
        // for small Gram entries
        for j in 2..=5 {
            for k in j..=5 {
                let d = gram_entry_digamma(j, k);
                assert!(d > 0.0, "G({j},{k}) should be positive, got {d}");
                assert!(d < 1.0, "G({j},{k}) should be < 1, got {d}");
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MPFR-PRECISION VASYUNIN FORMULA
//
// G(j,k) = (ln(2π)-γ)/2 · (1/j + 1/k)
//        + (j-k)/(2jk) · ln(k/j)
//        - πd/(2jk) · (V(j',k') + V(k',j'))
//        - 1/(jk)
//
// where d = gcd(j,k), j' = j/d, k' = k/d.
// ═══════════════════════════════════════════════════════════════════

/// Vasyunin cotangent sum at MPFR precision:
/// V(a,b) = Σ_{m=1}^{a-1} {mb/a} · cot(πm/a)
pub fn vasyunin_cot_sum_mpfr(a: usize, b: usize, prec: u32) -> rug::Float {
    use rug::Float;
    let p = prec;
    if a <= 1 {
        return Float::with_val(p, 0);
    }
    let pi = Float::with_val(p, rug::float::Constant::Pi);
    let af = Float::with_val(p, a as u64);
    let mut total = Float::with_val(p, 0);

    for m in 1..a {
        let mb_mod_a = (m * b) % a;
        let frac = Float::with_val(p, mb_mod_a as u64) / &af;
        let angle = Float::with_val(p, &pi * m as u64) / &af;
        let (sin_v, cos_v) = angle.sin_cos(Float::new(p));
        if sin_v.to_f64().abs() < 1e-30 {
            continue;
        }
        let cot_v = Float::with_val(p, &cos_v / &sin_v);
        total += Float::with_val(p, &frac * &cot_v);
    }
    total
}

/// Gram matrix entry via the closed-form Vasyunin cotangent formula
/// at arbitrary MPFR precision.
///
/// Uses the exact formula:
/// ```text
/// G(j,k) = (ln(2π)-γ)/2 · (1/j + 1/k)
///        + (j-k)/(2jk) · ln(k/j)
///        - πd/(2jk) · (V(j/d, k/d) + V(k/d, j/d))
///        - 1/(jk)
/// ```
///
/// For diagonal: G(k,k) = (ln(2π)-γ)/k - 1/k²
///
/// # Example
/// ```rust,no_run
/// use cathedral_utils::vasyunin::gram_entry_vasyunin_mpfr;
/// let g23 = gram_entry_vasyunin_mpfr(2, 3, 256);
/// assert!(g23.to_f64() > 0.0);
/// ```
pub fn gram_entry_vasyunin_mpfr(j: usize, k: usize, prec: u32) -> rug::Float {
    use rug::Float;
    let p = prec;
    let gamma = crate::constants::euler_gamma_mpfr(p);
    let l2p = crate::constants::ln2pi_mpfr(p);
    let pi = Float::with_val(p, rug::float::Constant::Pi);
    let jf = Float::with_val(p, j as u64);
    let kf = Float::with_val(p, k as u64);

    if j == k {
        // G(k,k) = (ln(2π)-γ)/k - 1/k²
        let a = Float::with_val(p, &l2p - &gamma);
        let b = Float::with_val(p, &a / &jf);
        let c = Float::with_val(p, Float::with_val(p, 1u32) / Float::with_val(p, &jf * &jf));
        return Float::with_val(p, b - c);
    }

    let jk = Float::with_val(p, &jf * &kf);
    let d = arith::gcd(j, k);
    let jp = j / d;
    let kp = k / d;
    let df = Float::with_val(p, d as u64);

    // Term 1: (ln(2π)-γ)/2 · (1/j + 1/k)
    let coeff = Float::with_val(p, Float::with_val(p, &l2p - &gamma) / 2u32);
    let inv_sum = Float::with_val(
        p,
        Float::with_val(p, Float::with_val(p, 1u32) / &jf)
            + Float::with_val(p, Float::with_val(p, 1u32) / &kf),
    );
    let term1 = Float::with_val(p, &coeff * &inv_sum);

    // Term 2: (j-k)/(2jk) · ln(k/j)
    let diff = Float::with_val(p, &jf - &kf);
    let two_jk = Float::with_val(p, Float::with_val(p, 2u32) * &jk);
    let log_ratio = Float::with_val(p, Float::with_val(p, &kf / &jf).ln());
    let term2 = Float::with_val(p, Float::with_val(p, &diff / &two_jk) * &log_ratio);

    // Term 3: -πd/(2jk) · (V(j',k') + V(k',j'))
    let v1 = vasyunin_cot_sum_mpfr(jp, kp, p);
    let v2 = vasyunin_cot_sum_mpfr(kp, jp, p);
    let v_sum = Float::with_val(p, &v1 + &v2);
    let pi_d = Float::with_val(p, &pi * &df);
    let term3 = Float::with_val(p, Float::with_val(p, &pi_d / &two_jk) * &v_sum);

    // Term 4: -1/(jk)
    let term4 = Float::with_val(p, Float::with_val(p, 1u32) / &jk);

    // G = term1 + term2 - term3 - term4
    let mut result = Float::with_val(p, &term1 + &term2);
    result -= &term3;
    result -= &term4;
    result
}
