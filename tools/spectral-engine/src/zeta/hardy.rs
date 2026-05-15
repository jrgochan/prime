//! Hardy Z-function and Riemann-Siegel formula.
//!
//! Z(t) = e^{iθ(t)} · ζ(½ + it)
//!
//! Z(t) is real-valued and its sign changes correspond exactly
//! to zeros of ζ on the critical line.
//!
//! The Riemann-Siegel theta function:
//!   θ(t) = arg(Γ(¼ + it/2)) - (t/2)·ln(π)
//!
//! Gram points g_n: θ(g_n) = nπ — used for zero isolation.

use super::dirichlet::complex_zeta;
use std::f64::consts::PI;

// ════════════════════════════════════════════════════════════
// RIEMANN-SIEGEL THETA
// ════════════════════════════════════════════════════════════

/// Riemann-Siegel theta function:
///   θ(t) = Im(ln Γ(¼ + it/2)) - (t/2)·ln(π)
///
/// Approximation via Stirling's series:
///   θ(t) ≈ (t/2)·ln(t/(2πe)) - π/8 + 1/(48t) + 7/(5760t³) + ...
pub fn theta(t: f64) -> f64 {
    if t.abs() < 1.0 {
        // Small t: use direct computation
        return theta_direct(t);
    }
    
    let t_abs = t.abs();
    
    // Stirling approximation (accurate for t > 10)
    let mut result = (t_abs / 2.0) * ((t_abs / (2.0 * PI * std::f64::consts::E)).ln())
        - PI / 8.0;
    
    // Higher-order Stirling corrections
    result += 1.0 / (48.0 * t_abs);
    result += 7.0 / (5760.0 * t_abs * t_abs * t_abs);
    result += 31.0 / (80640.0 * t_abs.powi(5));
    
    if t < 0.0 { -result } else { result }
}

/// Direct theta computation for small t (via numerical Γ).
fn theta_direct(t: f64) -> f64 {
    // For small t, use the series for arg(Γ(1/4 + it/2))
    // ψ₁ = digamma at s = 1/4 + it/2
    // This is a rough approximation; for production use a proper Γ implementation
    let s_re = 0.25;
    let s_im = t / 2.0;
    
    // Approximate via Im(ln Γ(s)) using Stirling
    let r = (s_re * s_re + s_im * s_im).sqrt();
    let phi = s_im.atan2(s_re);
    
    let result = (r.ln() - 1.0) * s_im + phi * (s_re - 0.5) - (t / 2.0) * PI.ln();
    result
}

// ════════════════════════════════════════════════════════════
// HARDY Z-FUNCTION
// ════════════════════════════════════════════════════════════

/// Hardy Z-function: Z(t) = e^{iθ(t)} · ζ(½ + it).
///
/// Z(t) is REAL-VALUED. Its sign changes correspond to zeros of ζ
/// on the critical line Re(s) = ½.
///
/// Uses N terms of the Dirichlet series for ζ.
pub fn hardy_z(t: f64, terms: usize) -> f64 {
    let th = theta(t);
    let (zeta_re, zeta_im) = complex_zeta(0.5, t, terms);
    
    // Z(t) = Re(e^{iθ} · ζ) = ζ_re · cos(θ) - ζ_im · sin(θ)
    zeta_re * th.cos() - zeta_im * th.sin()
}

/// Compute Z(t) via Riemann-Siegel formula (higher accuracy for large t).
///
/// Z(t) = 2·Σ_{n=1}^{N} n^{-1/2} · cos(θ(t) - t·ln(n)) + R(t)
///
/// where N = ⌊√(t/(2π))⌋ and R(t) is the remainder term.
pub fn hardy_z_riemann_siegel(t: f64) -> f64 {
    let t_abs = t.abs();
    if t_abs < 2.0 {
        return hardy_z(t, 100);
    }
    
    let n_max = (t_abs / (2.0 * PI)).sqrt().floor() as usize;
    let th = theta(t_abs);
    
    let mut sum = 0.0;
    for n in 1..=n_max.max(1) {
        let nf = n as f64;
        sum += nf.powf(-0.5) * (th - t_abs * nf.ln()).cos();
    }
    sum *= 2.0;
    
    // First-order Riemann-Siegel correction
    let p = (t_abs / (2.0 * PI)).sqrt();
    let p_fract = p - p.floor();
    // C₀(p) ≈ cos(2π(p²-p-1/16)) / cos(2πp)
    let c0_num = (2.0 * PI * (p_fract * p_fract - p_fract - 1.0 / 16.0)).cos();
    let c0_den = (2.0 * PI * p_fract).cos();
    if c0_den.abs() > 0.01 {
        let correction = (-1.0_f64).powi(n_max as i32 + 1)
            * (t_abs / (2.0 * PI)).powf(-0.25)
            * c0_num / c0_den;
        sum += correction;
    }
    
    if t < 0.0 { -sum } else { sum }
}

// ════════════════════════════════════════════════════════════
// GRAM POINTS
// ════════════════════════════════════════════════════════════

/// Find Gram point g_n where θ(g_n) = nπ.
///
/// Uses Newton's method starting from the asymptotic approximation:
///   g_n ≈ 2π · exp(W(n/e) + 1) where W is the Lambert W function.
///   Rough: g_n ≈ 2πn / ln(n/(2πe))  for large n.
pub fn gram_point(n: usize) -> f64 {
    if n == 0 {
        return 17.845599; // g₀ ≈ 17.846
    }
    
    let nf = n as f64;
    let target = nf * PI;
    
    // Initial guess using asymptotic formula
    let mut t = if nf > 5.0 {
        2.0 * PI * nf / (nf / (2.0 * PI * std::f64::consts::E)).ln()
    } else {
        17.8 + nf * 3.5 // rough for small n
    };
    
    // Newton iteration: θ(t) = target
    // θ'(t) ≈ (1/2)·ln(t/(2π))
    for _ in 0..30 {
        let th = theta(t);
        let deriv = 0.5 * (t / (2.0 * PI)).ln();
        if deriv.abs() < 1e-20 { break; }
        let dt = (target - th) / deriv;
        t += dt;
        if dt.abs() < 1e-12 { break; }
    }
    
    t
}

/// Find the first `count` Gram points.
pub fn gram_points(count: usize) -> Vec<f64> {
    (0..count).map(gram_point).collect()
}

/// Count sign changes of Z(t) in [a, b] — gives a lower bound on zero count.
pub fn count_sign_changes(a: f64, b: f64, num_samples: usize, terms: usize) -> usize {
    let dt = (b - a) / num_samples as f64;
    let mut changes = 0;
    let mut prev_sign = hardy_z(a, terms) >= 0.0;
    
    for i in 1..=num_samples {
        let t = a + i as f64 * dt;
        let current_sign = hardy_z(t, terms) >= 0.0;
        if current_sign != prev_sign {
            changes += 1;
        }
        prev_sign = current_sign;
    }
    
    changes
}

/// Verify that the n-th zero is near the tabulated value
/// by checking Z(γₙ) ≈ 0.
pub fn verify_zero(gamma: f64, terms: usize) -> f64 {
    hardy_z(gamma, terms).abs()
}

// ════════════════════════════════════════════════════════════
// ETA FUNCTION (Dirichlet eta, for analytic continuation)
// ════════════════════════════════════════════════════════════

/// Dirichlet eta function: η(s) = Σ_{n=1}^{N} (-1)^{n+1} / n^s
///
/// Related to zeta: η(s) = (1 - 2^{1-s}) · ζ(s)
/// Converges for Re(s) > 0 (wider than ζ's Re(s) > 1).
pub fn eta(sigma: f64, t: f64, terms: usize) -> (f64, f64) {
    let mut re = 0.0f64;
    let mut im = 0.0f64;
    for n in 1..=terms {
        let nf = n as f64;
        let sign = if n % 2 == 1 { 1.0 } else { -1.0 };
        let mag = sign * nf.powf(-sigma);
        let angle = -t * nf.ln();
        re += mag * angle.cos();
        im += mag * angle.sin();
    }
    (re, im)
}

/// Euler-Maclaurin accelerated eta (for faster convergence).
pub fn eta_accelerated(sigma: f64, t: f64, terms: usize) -> (f64, f64) {
    // Borwein acceleration: use binomial weights
    let n = terms;
    let mut d = vec![0.0f64; n + 1];
    d[0] = 1.0;
    for k in 1..=n {
        d[k] = d[k - 1] * (n + k - 1) as f64 * (n - k + 1) as f64
            / ((2 * k) as f64 * (2 * k - 1) as f64);
    }
    let d_n = d[n];
    
    let mut re = 0.0f64;
    let mut im = 0.0f64;
    for k in 0..n {
        let sign = if k % 2 == 0 { 1.0 } else { -1.0 };
        let kf = (k + 1) as f64;
        let mag = sign * (d[k] - d_n) / (d_n * kf.powf(sigma));
        let angle = -t * kf.ln();
        re += mag * angle.cos();
        im += mag * angle.sin();
    }
    
    re = -re;
    im = -im;
    (re, im)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::zeta::zeros::ZEROS;

    #[test]
    fn theta_is_increasing() {
        // θ(t) is increasing for t > 0
        let t1 = theta(10.0);
        let t2 = theta(20.0);
        let t3 = theta(50.0);
        assert!(t2 > t1, "θ(20) = {} should be > θ(10) = {}", t2, t1);
        assert!(t3 > t2, "θ(50) = {} should be > θ(20) = {}", t3, t2);
    }

    #[test]
    fn hardy_z_near_first_zero() {
        // Z(14.134...) ≈ 0 (first zero)
        let z = hardy_z(ZEROS[0], 200);
        assert!(z.abs() < 0.5, "Z(γ₁) = {} should be near 0", z);
    }

    #[test]
    fn hardy_z_sign_change() {
        // Z should change sign near γ₁ ≈ 14.134
        let z_before = hardy_z(13.0, 200);
        let z_after = hardy_z(15.0, 200);
        assert!(z_before * z_after < 0.0,
            "Z should change sign: Z(13)={}, Z(15)={}", z_before, z_after);
    }

    #[test]
    fn gram_point_0() {
        // g₀ ≈ 17.8456
        let g0 = gram_point(0);
        assert!((g0 - 17.8456).abs() < 0.01,
            "g₀ = {} should be ≈ 17.8456", g0);
    }

    #[test]
    fn eta_at_1() {
        // η(1) = ln(2) ≈ 0.6931
        let (re, im) = eta(1.0, 0.0, 10000);
        assert!((re - 2.0_f64.ln()).abs() < 0.01,
            "η(1) = {} should be ln(2) = {}", re, 2.0_f64.ln());
        assert!(im.abs() < 1e-10);
    }

    #[test]
    fn verify_first_three_zeros() {
        // Check that Z is small at the first 3 tabulated zeros
        for i in 0..3 {
            let residual = verify_zero(ZEROS[i], 200);
            assert!(residual < 1.0,
                "Z(γ_{}) residual = {} should be small", i + 1, residual);
        }
    }

    #[test]
    fn count_zeros_in_range() {
        // There should be ≥ 1 sign change between t=13 and t=16
        let changes = count_sign_changes(13.0, 16.0, 100, 200);
        assert!(changes >= 1,
            "Should find ≥1 sign change in [13,16], found {}", changes);
    }
}
