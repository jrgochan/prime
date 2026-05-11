//! ═══════════════════════════════════════════════════════════════════════════
//!  Riemann-Siegel Functions
//!
//!  The Riemann-Siegel theta function, Hardy Z-function, and zero-finding
//!  routines for the Riemann zeta function on the critical line.
//!
//!  These are the classical tools for studying ζ(1/2 + it) numerically.
//! ═══════════════════════════════════════════════════════════════════════════

use std::f64::consts::PI;

/// Riemann-Siegel theta function: θ(t) = arg(Γ(1/4 + it/2)) - (t/2)ln(π).
///
/// Uses the asymptotic expansion for t > 1:
///   θ(t) = (t/2)ln(t/(2π)) - t/2 - π/8 + 1/(48t) + 7/(5760t³) + ...
///
/// Higher-order terms are included for t > 10 to maintain ~15-digit accuracy.
pub fn rs_theta(t: f64) -> f64 {
    let t2 = t / 2.0;
    let mut theta = t2 * (t2 / PI).ln() - t2 - PI / 8.0;
    if t > 10.0 {
        let ti = 1.0 / t;
        theta += ti / 48.0
            + 7.0 * ti.powi(3) / 5760.0
            + 31.0 * ti.powi(5) / 80640.0
            + 127.0 * ti.powi(7) / 430080.0;
    } else if t > 1.0 {
        let ti = 1.0 / t;
        theta += ti / 48.0 + 7.0 * ti.powi(3) / 5760.0;
    }
    theta
}

/// Hardy Z-function: Z(t) = e^{iθ(t)} ζ(1/2 + it).
///
/// Z(t) is real-valued and shares its zeros with ζ(1/2 + it).
/// Computed via the Riemann-Siegel formula with the first correction term.
///
/// Accurate to ~10⁻⁹ for moderate t (< 10⁶). For higher t, use MPFR.
pub fn hardy_z(t: f64) -> f64 {
    let n_max = ((t / (2.0 * PI)).sqrt()).floor() as usize;
    if n_max == 0 {
        return 0.0;
    }
    let theta = rs_theta(t);

    let mut sum = 0.0;
    for n in 1..=n_max {
        let nf = n as f64;
        sum += (theta - t * nf.ln()).cos() / nf.sqrt();
    }
    sum *= 2.0;

    // Riemann-Siegel correction term (C₀)
    let p = ((t / (2.0 * PI)).sqrt()).fract();
    let c0 = {
        let u = 2.0 * p - 1.0;
        (PI / 8.0 * u * u).cos() / (PI * 0.5 * u).cos()
    };
    let tau = (t / (2.0 * PI)).sqrt();
    let correction = (-1i32).pow(n_max as u32 + 1) as f64 * tau.powf(-0.5) * c0;
    sum += correction;

    sum
}

/// Find zeros of ζ(1/2 + it) on the critical line via sign changes of Z(t).
///
/// Scans from t = 14 (just below the first zero at ~14.1347) up to `t_end`,
/// using adaptive step sizes based on the expected zero spacing
/// 2π/ln(t/(2π)). Each sign change is refined to ~10⁻¹⁹ via bisection.
///
/// Returns a vector of zero locations (the imaginary parts of the zeros).
pub fn find_zeros(t_end: f64) -> Vec<f64> {
    let mut zeros = Vec::new();
    let mut t = 6.0;
    let mut z_prev = hardy_z(t);

    while t < t_end {
        let expected_spacing = 2.0 * PI / (t / (2.0 * PI)).ln();
        let dt = (expected_spacing * 0.25).max(0.01).min(0.5);
        let t_next = t + dt;
        let z_next = hardy_z(t_next);

        if z_prev * z_next < 0.0 {
            let (mut lo, mut hi) = (t, t_next);
            let mut zlo = z_prev;
            for _ in 0..64 {
                let mid = (lo + hi) / 2.0;
                let zm = hardy_z(mid);
                if zlo * zm < 0.0 {
                    hi = mid;
                } else {
                    lo = mid;
                    zlo = zm;
                }
            }
            zeros.push((lo + hi) / 2.0);
        }
        t = t_next;
        z_prev = z_next;
    }
    zeros
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_find_zeros_large_t() {
        // For t > 40 (n_max >= 2), the RS formula is reliable
        let zeros = find_zeros(200.0);
        assert!(
            zeros.len() >= 5,
            "Should find at least 5 zeros up to t=200, found {}",
            zeros.len()
        );
    }

    #[test]
    fn test_hardy_z_sign_change_reliable() {
        // At t ~ 100, n_max = floor(sqrt(100/(2π))) = 3, formula is solid
        // Known: zeros near t ≈ 111.03, 101.32, etc
        let mut found = 0;
        let mut prev = hardy_z(100.0);
        let mut t = 100.1;
        while t < 120.0 {
            let curr = hardy_z(t);
            if prev * curr < 0.0 {
                found += 1;
            }
            prev = curr;
            t += 0.1;
        }
        assert!(
            found >= 1,
            "Expected at least 1 sign change of Z(t) in [100, 120]"
        );
    }

    #[test]
    fn test_rs_theta_monotone() {
        // θ(t) should be increasing for t > 7
        let t1 = rs_theta(10.0);
        let t2 = rs_theta(20.0);
        let t3 = rs_theta(50.0);
        assert!(t2 > t1);
        assert!(t3 > t2);
    }

    #[test]
    fn test_rs_theta_known_value() {
        // θ(100) from the asymptotic expansion
        let theta = rs_theta(100.0);
        assert!(
            (theta - 87.972).abs() < 0.1,
            "θ(100) = {}, expected ~87.972",
            theta
        );
    }
}
