//! Compensated Arithmetic — Kahan summation for numerical stability.
//!
//! Standard floating-point summation of N terms accumulates O(N·ε)
//! roundoff error. Kahan (compensated) summation reduces this to O(ε),
//! independent of N.
//!
//! At dim=55,439, naive summation loses ~4 decimal digits of precision
//! in dot products. Kahan summation recovers them with negligible
//! overhead (~2 extra FLOPs per term).
//!
//! ## References
//!
//! - W. Kahan, "Further remarks on reducing truncation errors",
//!   Commun. ACM 8(1):40, 1965.
//! - N. Higham, "Accuracy and Stability of Numerical Algorithms",
//!   2nd ed., SIAM, 2002, §4.3.

/// Kahan-compensated dot product: Σ a[i] * b[i].
///
/// Standard summation of N terms accumulates O(N·ε) roundoff error.
/// Kahan summation reduces this to O(ε) — independent of N.
/// At dim=55,439, this recovers ~4 decimal digits of precision.
#[inline]
pub fn dot_kahan(a: &[f64], b: &[f64]) -> f64 {
    debug_assert_eq!(a.len(), b.len());
    let mut sum = 0.0f64;
    let mut comp = 0.0f64; // running compensation for lost low-order bits
    for i in 0..a.len() {
        let y = a[i] * b[i] - comp;
        let t = sum + y;
        comp = (t - sum) - y;
        sum = t;
    }
    sum
}

/// Kahan-compensated squared norm: Σ a[i]².
#[inline]
pub fn norm2_kahan(a: &[f64]) -> f64 {
    let mut sum = 0.0f64;
    let mut comp = 0.0f64;
    for i in 0..a.len() {
        let y = a[i] * a[i] - comp;
        let t = sum + y;
        comp = (t - sum) - y;
        sum = t;
    }
    sum
}

/// Kahan-compensated norm: sqrt(Σ a[i]²).
#[inline]
pub fn norm_kahan(a: &[f64]) -> f64 {
    norm2_kahan(a).sqrt()
}
