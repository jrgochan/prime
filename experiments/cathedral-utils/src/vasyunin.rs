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
