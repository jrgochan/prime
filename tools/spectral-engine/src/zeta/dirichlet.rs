//! Dirichlet series and zeta function computation.
//!
//! ζ(s, N) — truncated Dirichlet series
//! χ(s)   — completed zeta multiplier (functional equation)

use std::f64::consts::PI;

/// Compute ζ(σ + it) using N terms of the Dirichlet series.
/// Returns (Re, Im).
pub fn complex_zeta(sigma: f64, t: f64, n: usize) -> (f64, f64) {
    let mut re = 0.0f64;
    let mut im = 0.0f64;
    for k in 1..=n {
        let kf = k as f64;
        let magnitude = kf.powf(-sigma);
        let angle = -t * kf.ln();
        re += magnitude * angle.cos();
        im += magnitude * angle.sin();
    }
    (re, im)
}

/// Partial sum S_N(s) = Σₙ₌₁ᴺ n⁻ˢ, returning running (Re, Im) at each step.
/// Useful for Cornu spiral visualization.
pub fn partial_sums(sigma: f64, t: f64, n: usize) -> Vec<(f64, f64)> {
    let mut sums = Vec::with_capacity(n);
    let mut re = 0.0f64;
    let mut im = 0.0f64;
    for k in 1..=n {
        let kf = k as f64;
        let magnitude = kf.powf(-sigma);
        let angle = -t * kf.ln();
        re += magnitude * angle.cos();
        im += magnitude * angle.sin();
        sums.push((re, im));
    }
    sums
}

/// Chi function χ(s) from the functional equation: ζ(s) = χ(s)·ζ(1-s).
/// χ(s) = 2^s · π^(s-1) · sin(πs/2) · Γ(1-s)
/// Returns (|χ|, arg(χ)) in polar form (approximate).
pub fn chi_magnitude(sigma: f64, t: f64) -> f64 {
    // |χ(σ+it)| ≈ (2π)^σ · (t/(2πe))^(½-σ) for large t
    if t.abs() < 1.0 { return 1.0; }
    let log_chi = sigma * (2.0 * PI).ln()
        + (0.5 - sigma) * (t.abs() / (2.0 * PI * std::f64::consts::E)).ln();
    log_chi.exp()
}

/// Euler product approximation: ∏ₚ≤P (1 - p⁻ˢ)⁻¹
/// Returns (Re, Im) using the first `num_primes` primes.
pub fn euler_product(sigma: f64, t: f64, primes: &[usize]) -> (f64, f64) {
    let mut re = 1.0f64;
    let mut im = 0.0f64;
    for &p in primes {
        let pf = p as f64;
        let mag = pf.powf(-sigma);
        let angle = -t * pf.ln();
        // (1 - p^{-s})^{-1}: compute 1/(1 - mag·e^{i·angle})
        let denom_re = 1.0 - mag * angle.cos();
        let denom_im = mag * angle.sin();
        let denom_sq = denom_re * denom_re + denom_im * denom_im;
        if denom_sq < 1e-20 { continue; }
        // Multiply (re + i·im) by (denom_re + i·denom_im) / denom_sq
        let new_re = (re * denom_re + im * denom_im) / denom_sq;
        let new_im = (im * denom_re - re * denom_im) / denom_sq;
        re = new_re;
        im = new_im;
    }
    (re, im)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn zeta_at_2() {
        // ζ(2) = π²/6 ≈ 1.6449, converges slowly
        let (re, im) = complex_zeta(2.0, 0.0, 10000);
        assert!((re - PI * PI / 6.0).abs() < 0.001);
        assert!(im.abs() < 1e-10);
    }

    #[test]
    fn partial_sums_length() {
        let sums = partial_sums(0.5, 14.134, 50);
        assert_eq!(sums.len(), 50);
    }

    #[test]
    fn euler_product_converges() {
        let primes = super::super::arithmetic::primes_up_to_count(100);
        let (re, _im) = euler_product(2.0, 0.0, &primes);
        // Should approximate ζ(2) ≈ 1.6449
        assert!((re - 1.6449).abs() < 0.01);
    }
}
