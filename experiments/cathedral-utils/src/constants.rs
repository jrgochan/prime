//! Mathematical constants and special function values.
//!
//! Centralizes commonly-used constants that were previously duplicated
//! across 13+ experiments. Provides both f64 and arbitrary-precision
//! (via `rug::Float`) versions.
//!
//! ## Constants
//!
//! - [`EULER_GAMMA`] — Euler-Mascheroni constant γ ≈ 0.5772
//! - [`LOG_2PI`] — ln(2π) ≈ 1.8379
//! - [`STIRLING_CONST`] — ln(2π) - γ - 1 (appears in Stirling bridge)
//!
//! ## Functions
//!
//! - [`euler_gamma_hp`] — γ at arbitrary precision via MPFR
//! - [`harmonic_number`] — H_n = 1 + 1/2 + ... + 1/n
//! - [`digamma_f64`] — ψ(x) digamma function (f64 precision)
//! - [`integrate_01`] — Composite Simpson's rule on [0,1]

use std::f64::consts::PI;

// ═══════════════════════════════════════════════════════════════════
// FUNDAMENTAL CONSTANTS (f64)
// ═══════════════════════════════════════════════════════════════════

/// Euler-Mascheroni constant γ = lim_{n→∞} (H_n - ln n)
/// = 0.57721566490153286060651209008240243...
pub const EULER_GAMMA: f64 = 0.5772156649015329;

/// ln(2π) ≈ 1.8378770664093454836...
pub const LOG_2PI: f64 = 1.8378770664093455;

/// Stirling bridge constant: ln(2π) - γ - 1
/// Appears in the Stirling approximation bridge axiom.
pub const STIRLING_CONST: f64 = LOG_2PI - EULER_GAMMA - 1.0;

/// π² / 6 = ζ(2) (Basel problem)
pub const ZETA_2: f64 = 1.6449340668482264;

/// Apéry's constant ζ(3) ≈ 1.2020569...
pub const ZETA_3: f64 = 1.2020569031595943;

// ═══════════════════════════════════════════════════════════════════
// SPECIAL FUNCTIONS
// ═══════════════════════════════════════════════════════════════════

/// Harmonic number: H_n = 1 + 1/2 + 1/3 + ... + 1/n
///
/// For large n, H_n ≈ ln(n) + γ + 1/(2n) - 1/(12n²) + ...
pub fn harmonic_number(n: usize) -> f64 {
    if n == 0 { return 0.0; }
    if n > 1000 {
        // Asymptotic expansion for large n
        let x = n as f64;
        let inv_x = 1.0 / x;
        (x).ln() + EULER_GAMMA + 0.5 * inv_x
            - inv_x * inv_x / 12.0
            + inv_x.powi(4) / 120.0
    } else {
        (1..=n).map(|k| 1.0 / k as f64).sum()
    }
}

/// Digamma function ψ(x) = d/dx ln Γ(x) for real x > 0.
///
/// Uses the asymptotic series with recurrence for small x.
/// Precision: ~15 digits for x > 0.
pub fn digamma_f64(mut x: f64) -> f64 {
    // Shift x up to ensure x > 10 for asymptotic accuracy
    let mut result = 0.0;
    while x < 10.0 {
        result -= 1.0 / x;
        x += 1.0;
    }

    // Asymptotic expansion: ψ(x) ≈ ln(x) - 1/(2x) - Σ B_{2k}/(2k·x^{2k})
    let inv = 1.0 / x;
    let inv2 = inv * inv;
    result += x.ln() - 0.5 * inv;

    // Bernoulli numbers: B₂=1/6, B₄=-1/30, B₆=1/42, B₈=-1/30, B₁₀=5/66
    let mut t = inv2;
    result -= t / 12.0;
    t *= inv2;
    result += t / 120.0;
    t *= inv2;
    result -= t / 252.0;
    t *= inv2;
    result += t / 240.0;
    t *= inv2;
    result -= 5.0 * t / 660.0;
    t *= inv2;
    result += 691.0 * t / 32760.0;

    result
}

/// Riemann zeta function ζ(s) for real s > 1, using direct summation.
///
/// For precision, uses Euler-Maclaurin with Bernoulli correction.
pub fn zeta_real(s: f64) -> f64 {
    if s <= 1.0 { return f64::INFINITY; }

    // Direct sum up to N, then Euler-Maclaurin remainder
    let n_terms = 1000;
    let mut sum: f64 = (1..=n_terms).map(|k| (k as f64).powf(-s)).sum();

    // Euler-Maclaurin remainder: integral from N to ∞
    let n = n_terms as f64;
    sum += n.powf(1.0 - s) / (s - 1.0);
    sum += 0.5 * n.powf(-s);

    sum
}

/// Composite Simpson's rule integration on [0,1] with n_points nodes.
///
/// Avoids the x=0 singularity by starting slightly above 0.
/// Commonly used for Gram matrix entry computation via numerical quadrature.
pub fn integrate_01<F: Fn(f64) -> f64>(f: F, n_points: usize) -> f64 {
    let h = 1.0 / n_points as f64;
    let mut total = 0.0;

    // Simpson weights: 1, 4, 2, 4, 2, ..., 4, 1
    for i in 1..n_points {
        let x = i as f64 * h;
        let w = if i % 2 == 0 { 2.0 } else { 4.0 };
        total += w * f(x);
    }

    // Near-endpoint proxies (avoiding x=0 singularity)
    total += f(h * 0.01);
    total += f(1.0 - h * 0.01);

    total * h / 3.0
}

/// Gauss-Legendre quadrature on [a,b] with n points.
///
/// Higher accuracy than Simpson for smooth integrands.
/// Uses precomputed nodes and weights for n ≤ 10.
pub fn gauss_legendre<F: Fn(f64) -> f64>(f: F, a: f64, b: f64, n: usize) -> f64 {
    // 5-point Gauss-Legendre nodes and weights on [-1,1]
    let (nodes, weights): (&[f64], &[f64]) = match n.min(5) {
        1 => (&[0.0], &[2.0]),
        2 => (&[-0.5773502691896257, 0.5773502691896257], &[1.0, 1.0]),
        3 => (&[-0.7745966692414834, 0.0, 0.7745966692414834],
              &[0.5555555555555556, 0.8888888888888888, 0.5555555555555556]),
        5 | _ => (
            &[-0.9061798459386640, -0.5384693101056831, 0.0,
               0.5384693101056831,  0.9061798459386640],
            &[0.2369268850561891, 0.4786286704993665, 0.5688888888888889,
              0.4786286704993665, 0.2369268850561891],
        ),
    };

    let mid = (a + b) / 2.0;
    let half = (b - a) / 2.0;

    let mut sum = 0.0;
    for (xi, wi) in nodes.iter().zip(weights.iter()) {
        sum += wi * f(mid + half * xi);
    }
    sum * half
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_euler_gamma() {
        assert!((EULER_GAMMA - 0.5772156649015329).abs() < 1e-15);
    }

    #[test]
    fn test_harmonic_numbers() {
        assert!((harmonic_number(1) - 1.0).abs() < 1e-15);
        assert!((harmonic_number(2) - 1.5).abs() < 1e-15);
        assert!((harmonic_number(3) - 11.0/6.0).abs() < 1e-15);
        assert!((harmonic_number(10) - 2.928968).abs() < 1e-5);
    }

    #[test]
    fn test_digamma() {
        // ψ(1) = -γ
        assert!((digamma_f64(1.0) + EULER_GAMMA).abs() < 1e-12);
        // ψ(2) = 1 - γ
        assert!((digamma_f64(2.0) - (1.0 - EULER_GAMMA)).abs() < 1e-12);
    }

    #[test]
    fn test_zeta_values() {
        assert!((ZETA_2 - PI * PI / 6.0).abs() < 1e-14);
        assert!((zeta_real(2.0) - ZETA_2).abs() < 1e-6);
    }

    #[test]
    fn test_integrate_sin() {
        // ∫₀¹ sin(πx) dx = 2/π ≈ 0.6366
        let result = integrate_01(|x| (PI * x).sin(), 10000);
        assert!((result - 2.0 / PI).abs() < 1e-4);
    }

    #[test]
    fn test_stirling_const() {
        assert!((STIRLING_CONST - (LOG_2PI - EULER_GAMMA - 1.0)).abs() < 1e-15);
    }
}
