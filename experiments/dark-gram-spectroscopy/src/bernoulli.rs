//! ═══════════════════════════════════════════════════════════════════════════
//!  BERNOULLI POLYNOMIAL ENGINE
//!
//!  Evaluation of Bernoulli polynomials B_n(x) and their periodized
//!  versions B̃_n(x) = B_n({x}).
//!
//!  All formulas verified in Lean 4 (Cathedral/Physics/DarkGramMatrix.lean):
//!    B₁ = X - 1/2         (Polynomial.bernoulli_one)
//!    B₂ = X² - X + 1/6    (B2_explicit — PROVED)
//!    B'_n = n·B_{n-1}      (derivative_bernoulli_add_one)
//! ═══════════════════════════════════════════════════════════════════════════

/// Bernoulli numbers B_0, B_1, B_2, ..., B_max.
/// Uses the standard convention: B_1 = -1/2.
pub fn bernoulli_numbers(max: usize) -> Vec<f64> {
    let mut b = vec![0.0f64; max + 1];
    b[0] = 1.0;
    for m in 1..=max {
        let mut s = 0.0;
        for k in 0..m {
            // B_m = -1/(m+1) · Σ_{k=0}^{m-1} C(m+1, k) · B_k
            s += binomial(m + 1, k) as f64 * b[k];
        }
        b[m] = -s / (m + 1) as f64;
    }
    b
}

/// Evaluate B_n(x) for x ∈ [0,1].
///
/// Uses the explicit expansion:
///   B_n(x) = Σ_{k=0}^{n} C(n,k) · B_k · x^{n-k}
pub fn bernoulli_poly(n: usize, x: f64, bernoulli_nums: &[f64]) -> f64 {
    let mut result = 0.0;
    for k in 0..=n {
        result += binomial(n, k) as f64 * bernoulli_nums[k] * x.powi((n - k) as i32);
    }
    result
}

/// Evaluate B̃_n(x) = B_n({x}) — the periodized Bernoulli polynomial.
///
/// {x} = x - floor(x) is the fractional part.
/// For n=1: this is the sawtooth wave (discontinuous).
/// For n≥2: this is continuous (the Dark Engine).
#[inline]
pub fn bernoulli_periodic(n: usize, x: f64, bernoulli_nums: &[f64]) -> f64 {
    let frac = x - x.floor();
    bernoulli_poly(n, frac, bernoulli_nums)
}

/// Hardcoded B₂(x) = x² - x + 1/6.
/// From Lean: B2_explicit (PROVED, zero sorry).
#[inline]
pub fn b2(x: f64) -> f64 {
    x * x - x + 1.0 / 6.0
}

/// Hardcoded B₃(x) = x³ - 3x²/2 + x/2.
#[inline]
pub fn b3(x: f64) -> f64 {
    x * x * x - 1.5 * x * x + 0.5 * x
}

/// Hardcoded B₄(x) = x⁴ - 2x³ + x² - 1/30.
#[inline]
pub fn b4(x: f64) -> f64 {
    let x2 = x * x;
    x2 * x2 - 2.0 * x2 * x + x2 - 1.0 / 30.0
}

/// Hardcoded B₆(x) = x⁶ - 3x⁵ + 5x⁴/2 - x²/2 + 1/42.
#[inline]
pub fn b6(x: f64) -> f64 {
    let x2 = x * x;
    let x3 = x2 * x;
    let x4 = x2 * x2;
    x4 * x2 - 3.0 * x4 * x + 2.5 * x4 - 0.5 * x2 + 1.0 / 42.0
}

/// Periodized B̃_n for specific hardcoded orders (fast path).
#[inline]
pub fn bernoulli_periodic_fast(n: usize, x: f64) -> f64 {
    let frac = x - x.floor();
    match n {
        1 => frac - 0.5,
        2 => b2(frac),
        3 => b3(frac),
        4 => b4(frac),
        6 => b6(frac),
        _ => panic!("bernoulli_periodic_fast: unsupported order {n}"),
    }
}

/// Binomial coefficient C(n, k).
fn binomial(n: usize, k: usize) -> u64 {
    if k > n {
        return 0;
    }
    let k = k.min(n - k);
    let mut result = 1u64;
    for i in 0..k {
        result = result * (n - i) as u64 / (i + 1) as u64;
    }
    result
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_bernoulli_numbers() {
        let b = bernoulli_numbers(6);
        assert!((b[0] - 1.0).abs() < 1e-15);
        assert!((b[1] - (-0.5)).abs() < 1e-15);
        assert!((b[2] - (1.0 / 6.0)).abs() < 1e-15);
        assert!(b[3].abs() < 1e-15); // B_3 = 0
        assert!((b[4] - (-1.0 / 30.0)).abs() < 1e-15);
        assert!(b[5].abs() < 1e-15); // B_5 = 0
        assert!((b[6] - (1.0 / 42.0)).abs() < 1e-15);
    }

    #[test]
    fn test_b2_matches_lean() {
        // From DarkGramMatrix.lean: B₂ = X² - X + 1/6
        for &x in &[0.0, 0.25, 0.5, 0.75, 1.0] {
            let expected = x * x - x + 1.0 / 6.0;
            assert!((b2(x) - expected).abs() < 1e-15, "B₂({x}) mismatch");
        }
    }

    #[test]
    fn test_b2_at_zero_and_one() {
        // B₂(0) = 1/6, B₂(1) = 1/6 (periodic!)
        assert!((b2(0.0) - 1.0 / 6.0).abs() < 1e-15);
        assert!((b2(1.0) - 1.0 / 6.0).abs() < 1e-15);
    }
}
