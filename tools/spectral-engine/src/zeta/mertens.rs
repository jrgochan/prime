//! Mertens function and Prime Number Theorem asymptotics.
//!
//! M(x) = Σ_{n≤x} μ(n) — the Mertens function.
//! RH ⟺ M(x) = O(x^{1/2+ε}) for all ε > 0.
//!
//! The Cathedral proves the tighter bound:
//!   RH ⟹ |M(x)| = O(x^{1/2+ε})
//! (not just the weaker O(x^{3/4}) used in rh_implies_mertens_34).

use super::arithmetic::mobius;

/// Euler-Mascheroni constant γ ≈ 0.5772156649...
pub const EULER_MASCHERONI: f64 = 0.5772156649015329;

// ════════════════════════════════════════════════════════════
// MERTENS FUNCTION
// ════════════════════════════════════════════════════════════

/// M(x) = Σ_{n=1}^{⌊x⌋} μ(n) — the Mertens function.
///
/// Under RH: |M(x)| = O(x^{1/2+ε}) for all ε > 0.
/// Unconditionally: |M(x)| = O(x · exp(-c·√(ln x))) (PNT).
pub fn mertens(x: f64) -> i64 {
    let n = x.floor() as usize;
    let mut sum = 0i64;
    for k in 1..=n {
        sum += mobius(k) as i64;
    }
    sum
}

/// Mertens ratio: M(x) / x^α for testing growth bounds.
/// α = 0.5 tests the RH prediction; α = 0.75 tests the weaker bound.
pub fn mertens_ratio(x: f64, alpha: f64) -> f64 {
    let m = mertens(x) as f64;
    if x <= 1.0 { return 0.0; }
    m / x.powf(alpha)
}

/// Compute M(x)/√x — should stay bounded under RH.
/// The Mertens conjecture (|M(x)| < √x, disproved by Odlyzko-te Riele 1985)
/// fails, but |M(x)| = O(x^{1/2+ε}) is equivalent to RH.
pub fn mertens_normalized(x: f64) -> f64 {
    mertens_ratio(x, 0.5)
}

/// Tabulate M(x) for x = 1, 2, ..., n.
/// Returns Vec of (x, M(x)) pairs.
pub fn mertens_table(n: usize) -> Vec<(usize, i64)> {
    let mut table = Vec::with_capacity(n);
    let mut sum = 0i64;
    for k in 1..=n {
        sum += mobius(k) as i64;
        table.push((k, sum));
    }
    table
}

// ════════════════════════════════════════════════════════════
// PNT ASYMPTOTICS (Tier 2 axioms)
// ════════════════════════════════════════════════════════════

/// PNT asymptotic: Σ_{k=1}^{N} μ(k)/k.
/// Unconditionally → 0 as N → ∞ (equivalent to PNT).
/// Axiom: `pnt_mu_div_k`
pub fn pnt_mu_sum_1(n: usize) -> f64 {
    let mut sum = 0.0f64;
    for k in 1..=n {
        sum += mobius(k) as f64 / k as f64;
    }
    sum
}

/// PNT asymptotic: Σ_{k=1}^{N} μ(k)·ln(k)/k.
/// Unconditionally → -1 as N → ∞.
/// Axiom: `pnt_mu_log_div_k`
pub fn pnt_mu_sum_log(n: usize) -> f64 {
    let mut sum = 0.0f64;
    for k in 1..=n {
        let kf = k as f64;
        sum += mobius(k) as f64 * kf.ln() / kf;
    }
    sum
}

/// PNT asymptotic: Σ_{k=1}^{N} μ(k)·ln²(k)/k.
/// Unconditionally → -2γ as N → ∞ where γ is Euler-Mascheroni.
/// Axiom: `pnt_mu_log_sq_div_k`
pub fn pnt_mu_sum_log_sq(n: usize) -> f64 {
    let mut sum = 0.0f64;
    for k in 1..=n {
        let kf = k as f64;
        let ln_k = kf.ln();
        sum += mobius(k) as f64 * ln_k * ln_k / kf;
    }
    sum
}

// ════════════════════════════════════════════════════════════
// ABEL SUMMATION (Tier 3: abel_mertens_tail_raw)
// ════════════════════════════════════════════════════════════

/// Abel summation: Σ_{n=a}^{b} f(n)·g(n)
/// = [S(b)·g(b) - S(a-1)·g(a)] - ∫_a^b S(t)·g'(t) dt
///
/// where S(n) = Σ_{k=1}^{n} f(k).
///
/// This computes the partial sums form directly.
/// For the tail bound: uses Mertens + PNT → N^{-1/4} decay.
pub fn abel_summation_mertens_tail(n: usize) -> f64 {
    // Σ_{k=N+1}^{∞} μ(k)/k ≈ -Σ_{k=1}^{N} μ(k)/k
    // Under RH, the tail decays as O(N^{-1/2+ε})
    // The axiom uses the weaker N^{-1/4} bound
    let partial = pnt_mu_sum_1(n);
    // The tail is -partial (by PNT, full sum = 0)
    -partial
}

/// Generic Abel summation: given partial sums S(n) and a smooth function g,
/// compute Σ_{n=1}^{N} a(n)·g(n) via summation by parts.
pub fn abel_summation(partial_sums: &[f64], g: &dyn Fn(f64) -> f64, n: usize) -> f64 {
    if n == 0 || partial_sums.is_empty() { return 0.0; }
    let nn = n.min(partial_sums.len());
    
    // S(N)·g(N) - Σ_{k=1}^{N-1} S(k)·(g(k+1) - g(k))
    let mut result = partial_sums[nn - 1] * g(nn as f64);
    for k in 0..nn - 1 {
        let delta_g = g((k + 2) as f64) - g((k + 1) as f64);
        result -= partial_sums[k] * delta_g;
    }
    result
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn mertens_small_values() {
        // M(1)=1, M(2)=0, M(3)=-1, M(4)=-1, M(5)=-2, M(6)=-1
        assert_eq!(mertens(1.0), 1);
        assert_eq!(mertens(2.0), 0);
        assert_eq!(mertens(3.0), -1);
        assert_eq!(mertens(4.0), -1);
        assert_eq!(mertens(5.0), -2);
        assert_eq!(mertens(6.0), -1);
    }

    #[test]
    fn mertens_grows_slowly() {
        // M(100) should be small relative to 100^{0.5} ≈ 10
        let m = mertens(100.0);
        assert!(m.abs() < 15, "M(100) = {} is too large", m);
    }

    #[test]
    fn pnt_sum_1_converges() {
        // Σ μ(k)/k for k=1..1000 should be close to 0
        let s = pnt_mu_sum_1(1000);
        assert!(s.abs() < 0.1, "Σ μ(k)/k = {} (should be near 0)", s);
    }

    #[test]
    fn pnt_sum_log_converges() {
        // Σ μ(k)ln(k)/k for k=1..1000 should approach -1
        let s = pnt_mu_sum_log(1000);
        assert!((s - (-1.0)).abs() < 0.2, "Σ μ(k)ln(k)/k = {} (should be near -1)", s);
    }

    #[test]
    fn pnt_sum_log_sq_converges() {
        // Σ μ(k)ln²(k)/k for k=1..1000 should approach -2γ ≈ -1.1544
        let s = pnt_mu_sum_log_sq(1000);
        let target = -2.0 * EULER_MASCHERONI;
        assert!((s - target).abs() < 0.5, "Σ μ(k)ln²(k)/k = {} (should be near {})", s, target);
    }
}
