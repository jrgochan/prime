/// Vasyunin Gram matrix computation.
///
/// The exact discrete Gram entry from the Cathedral's Defs.lean:
///
///   G(j,k) = (ln(2π) - γ)/2 · (1/j + 1/k)
///            + (j-k)/(2jk) · ln(k/j)
///            - πd/(2jk) · (V(j',k') + V(k',j'))
///            - 1/(jk)                                   when j ≠ k
///
///   G(j,j) = (ln(2π) - γ)/j - 1/j²                    when j = k
///
/// where d = gcd(j,k), j' = j/d, k' = k/d,
/// and V(a,b) = Σ_{m=1}^{a-1} frac(m·b/a) · cot(π·m/a)
use std::f64::consts::PI;

/// Euler-Mascheroni constant γ ≈ 0.5772156649...
pub const EULER_GAMMA: f64 = 0.577_215_664_901_532_9;

/// ln(2π) ≈ 1.8378770664...
pub const LN_TWO_PI: f64 = 1.837_877_066_409_345_6;

/// Compute the Vasyunin cotangent sum V(a, b).
/// V(a, b) = Σ_{m=1}^{a-1} frac(m·b/a) · cot(π·m/a)
///
/// For a ≤ 1, returns 0.
pub fn vasyunin_sum(a: usize, b: usize) -> f64 {
    if a <= 1 {
        return 0.0;
    }
    let af = a as f64;
    let bf = b as f64;
    let mut sum = 0.0;
    for m in 1..a {
        let mf = m as f64;
        let frac_part = (mf * bf / af).fract();
        // Adjust for negative frac (Rust's fract can be negative for negative inputs)
        let frac_part = if frac_part < 0.0 {
            frac_part + 1.0
        } else {
            frac_part
        };
        let cot_val = 1.0 / (PI * mf / af).tan();
        sum += frac_part * cot_val;
    }
    sum
}

/// Compute the Gram matrix entry G(j, k).
/// j, k are 1-indexed natural numbers.
pub fn gram_entry(j: usize, k: usize) -> f64 {
    let jf = j as f64;
    let kf = k as f64;

    if j == k {
        // Diagonal: G(j,j) = (ln(2π) - γ)/j - 1/j²
        (LN_TWO_PI - EULER_GAMMA) / jf - 1.0 / (jf * jf)
    } else {
        let d = gcd(j, k);
        let jp = j / d;
        let kp = k / d;
        let df = d as f64;

        // Term 1: (ln(2π) - γ)/2 · (1/j + 1/k)
        let term1 = (LN_TWO_PI - EULER_GAMMA) / 2.0 * (1.0 / jf + 1.0 / kf);

        // Term 2: (j-k)/(2jk) · ln(k/j)
        let term2 = (jf - kf) / (2.0 * jf * kf) * (kf / jf).ln();

        // Term 3: πd/(2jk) · (V(j',k') + V(k',j'))
        let term3 = PI * df / (2.0 * jf * kf) * (vasyunin_sum(jp, kp) + vasyunin_sum(kp, jp));

        // Term 4: 1/(jk)
        let term4 = 1.0 / (jf * kf);

        term1 + term2 - term3 - term4
    }
}

/// Compute the mean vector entry b_j = (ln(j) + γ) / j
pub fn mean_entry(j: usize) -> f64 {
    let jf = j as f64;
    (jf.ln() + EULER_GAMMA) / jf
}

fn gcd(a: usize, b: usize) -> usize {
    let mut a = a;
    let mut b = b;
    while b != 0 {
        let t = b;
        b = a % b;
        a = t;
    }
    a
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_gram_diagonal() {
        // G(1,1) = ln(2π) - γ - 1 ≈ 0.26066
        let g11 = gram_entry(1, 1);
        assert!((g11 - 0.2607).abs() < 0.001, "G(1,1) = {}", g11);
    }

    #[test]
    fn test_gram_offdiag() {
        // G(1,2) ≈ 0.2722 (verified in Attack 7 with MPFR)
        let g12 = gram_entry(1, 2);
        assert!((g12 - 0.2722).abs() < 0.001, "G(1,2) = {}", g12);
    }

    #[test]
    fn test_gram_22() {
        // G(2,2) = (ln(2π) - γ)/2 - 1/4 ≈ 0.3803
        let g22 = gram_entry(2, 2);
        assert!((g22 - 0.3803).abs() < 0.001, "G(2,2) = {}", g22);
    }

    #[test]
    fn test_mean_entry() {
        // b_1 = (ln(1) + γ) / 1 = γ ≈ 0.5772
        let b1 = mean_entry(1);
        assert!((b1 - EULER_GAMMA).abs() < 1e-10);
    }
}
