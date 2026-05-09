//! Mertens function and related PNT summatory functions.
//!
//! These are the central shared implementations used by all Cathedral
//! experiments. Previously duplicated across 8+ experiments.
//!
//! ## Functions
//!
//! - [`mertens_values`] — M(n) = Σ_{k=1}^{n} μ(k)
//! - [`mertens_profile`] — Normalized Mertens statistics |M(x)|/(√x·(ln x)²)
//! - [`log_cutoff_weights`] — Selberg/Baez-Duarte witness weights w_k = -μ(k)·(1 - ln(k)/ln(N))
//! - [`witness_vector`] — Full witness vector for the Nyman-Beurling functional
//! - [`chebyshev_theta`] — θ(x) = Σ_{p≤x} ln(p)
//! - [`chebyshev_psi`] — ψ(x) = Σ_{p^k≤x} ln(p)

/// Mertens function: M(n) = Σ_{k=1}^{n} μ(k)
///
/// Returns a vector where m[i] = M(i) = Σ_{k=1}^{i} μ(k).
/// Uses the precomputed Möbius table from [`super::arith::mobius_table`].
///
/// # Example
/// ```
/// let mu = cathedral_utils::arith::mobius_table(100);
/// let m = cathedral_utils::mertens::mertens_values(&mu);
/// assert_eq!(m[1], 1);   // M(1) = μ(1) = 1
/// assert_eq!(m[2], 0);   // M(2) = μ(1) + μ(2) = 1 + (-1) = 0
/// assert_eq!(m[10], -1); // M(10) = -1
/// ```
pub fn mertens_values(mu: &[i8]) -> Vec<i64> {
    let mut m = vec![0i64; mu.len()];
    for i in 1..mu.len() {
        m[i] = m[i - 1] + mu[i] as i64;
    }
    m
}

/// Mertens function at a single point: M(x) = Σ_{k=1}^{⌊x⌋} μ(k)
pub fn mertens_at(mu: &[i8], x: f64) -> i64 {
    let n = x.floor() as usize;
    if n >= mu.len() { return 0; }
    let mut s = 0i64;
    for k in 1..=n {
        s += mu[k] as i64;
    }
    s
}

/// Mertens profile statistics for analytic number theory.
#[derive(Debug, Clone)]
pub struct MertensProfile {
    /// x value
    pub x: usize,
    /// M(x)
    pub m_x: i64,
    /// |M(x)| / √x
    pub normalized: f64,
    /// |M(x)| / (√x · (ln x)²) — the Mertens hypothesis ratio
    pub mertens_ratio: f64,
}

/// Compute Mertens profile up to max_x.
///
/// Returns profile data at logarithmically-spaced sample points,
/// plus the global maximum of |M(x)|/(√x·(ln x)²).
pub fn mertens_profile(mu: &[i8], max_x: usize) -> (Vec<MertensProfile>, f64) {
    let m = mertens_values(mu);
    let mut profiles = Vec::new();
    let mut max_ratio = 0.0f64;

    for x in 10..=max_x.min(m.len() - 1) {
        let mx = m[x];
        let xf = x as f64;
        let ratio = (mx as f64).abs() / (xf.sqrt() * xf.ln().powi(2));
        max_ratio = max_ratio.max(ratio);

        // Sample at logarithmic intervals
        if x <= 100 || x % (x / 100).max(1) == 0 || x == max_x.min(m.len() - 1) {
            profiles.push(MertensProfile {
                x,
                m_x: mx,
                normalized: (mx as f64).abs() / xf.sqrt(),
                mertens_ratio: ratio,
            });
        }
    }

    (profiles, max_ratio)
}

/// Log-cutoff Möbius witness weights for Nyman-Beurling approximant.
///
/// w_k = -μ(k) · (1 - ln(k)/ln(N))  for k = 1, ..., N-1
///
/// These are the Selberg/Baez-Duarte witness coefficients that appear
/// in the Cathedral's forward direction proof.
pub fn log_cutoff_weights(n: usize, mu: &[i8]) -> Vec<f64> {
    let ln_n = (n as f64).ln();
    (1..n).map(|k| {
        if k >= mu.len() || mu[k] == 0 { return 0.0; }
        let weight = 1.0 - (k as f64).ln() / ln_n;
        -(mu[k] as f64) * weight
    }).collect()
}

/// Full witness vector v for the d² = 1 - 2bᵀv + vᵀGv quadratic form.
///
/// v[i] corresponds to index i+2 (since Gram matrix uses j,k ≥ 2).
pub fn witness_vector(n: usize, mu: &[i8]) -> Vec<f64> {
    let ln_n = (n as f64).ln();
    let dim = n - 1;
    (0..dim).map(|i| {
        let k = i + 2;
        if k >= mu.len() { return 0.0; }
        let mu_k = mu[k] as f64;
        let weight = 1.0 - (k as f64).ln() / ln_n;
        -mu_k * weight
    }).collect()
}

/// Full witness vector v for k=1..N (Lean-aligned basis).
///
/// v[i] corresponds to index i+1 (k=1 has index 0).
/// This matches the Lean definition of logCutoffWitness which sums k=1..N.
///
/// v_k = -μ(k) · (1 - ln(k)/ln(N))
///
/// For k=1: v_1 = -μ(1) · (1 - 0) = -1  (the critical stabilizer)
pub fn witness_vector_full(n: usize, mu: &[i8]) -> Vec<f64> {
    let ln_n = (n as f64).ln();
    (0..n).map(|i| {
        let k = i + 1;
        if k >= mu.len() { return 0.0; }
        let mu_k = mu[k] as f64;
        let weight = 1.0 - (k as f64).ln() / ln_n;
        -mu_k * weight
    }).collect()
}

/// Chebyshev theta function: θ(x) = Σ_{p ≤ x, p prime} ln(p)
pub fn chebyshev_theta(is_prime: &[bool], x: usize) -> f64 {
    let mut theta = 0.0f64;
    for p in 2..=x.min(is_prime.len() - 1) {
        if is_prime[p] {
            theta += (p as f64).ln();
        }
    }
    theta
}

/// Chebyshev psi function: ψ(x) = Σ_{p^k ≤ x} ln(p)
///
/// This equals Σ_{n≤x} Λ(n) where Λ is the von Mangoldt function.
pub fn chebyshev_psi(is_prime: &[bool], x: usize) -> f64 {
    let mut psi = 0.0f64;
    for p in 2..=x.min(is_prime.len() - 1) {
        if !is_prime[p] { continue; }
        let ln_p = (p as f64).ln();
        let mut pk = p;
        while pk <= x {
            psi += ln_p;
            if pk > x / p { break; } // overflow protection
            pk *= p;
        }
    }
    psi
}

/// Compute the quadratic form Q(N) = 1 - 2bᵀv + vᵀGv.
///
/// This is the key quantity in the Nyman-Beurling equivalence:
/// RH ⟺ inf_N Q(N) = 0.
pub fn quadratic_form(
    gram: &[f64], b: &[f64], v: &[f64], dim: usize,
) -> f64 {
    // bᵀv
    let bt_v: f64 = b.iter().zip(v.iter()).map(|(bi, vi)| bi * vi).sum();

    // vᵀGv
    let mut vt_gv = 0.0f64;
    for i in 0..dim {
        let mut row_sum = 0.0f64;
        for j in 0..dim {
            row_sum += v[j] * gram[i * dim + j];
        }
        vt_gv += v[i] * row_sum;
    }

    1.0 - 2.0 * bt_v + vt_gv
}

// ═══════════════════════════════════════════════════════════════════
// NYMAN-BEURLING APPROXIMANT
// ═══════════════════════════════════════════════════════════════════

/// Evaluate the Nyman-Beurling approximant f_N(x) = Σ_{k=1}^{N-1} w_k · {1/(kx)}
///
/// where {y} = y - ⌊y⌋ is the fractional part.
///
/// This is the function whose L² distance from the indicator function
/// on [0,1] gives d²_N. The witness weights w_k come from
/// [`log_cutoff_weights`].
pub fn f_n_at(x: f64, weights: &[f64]) -> f64 {
    if x <= 0.0 { return 0.0; }
    let mut sum = 0.0;
    for (k_minus_1, &w) in weights.iter().enumerate() {
        if w == 0.0 { continue; }
        let k = (k_minus_1 + 1) as f64;
        let y = 1.0 / (k * x);
        sum += w * (y - y.floor());
    }
    sum
}

/// Compute vᵀGv = ∫₀¹ f_N(x)² dx via midpoint quadrature.
///
/// This is O(N·n_pts) instead of O(N²) for the Gram matrix approach,
/// useful for cross-checking or when the full matrix isn't available.
pub fn vtgv_by_integral(weights: &[f64], n_pts: usize) -> f64 {
    let dx = 1.0 / n_pts as f64;
    (0..n_pts).map(|i| {
        let x = (i as f64 + 0.5) * dx;
        let f = f_n_at(x, weights);
        f * f * dx
    }).sum()
}

/// Compute bᵀv = ∫₀¹ f_N(x) dx via midpoint quadrature.
pub fn btv_by_integral(weights: &[f64], n_pts: usize) -> f64 {
    let dx = 1.0 / n_pts as f64;
    (0..n_pts).map(|i| {
        let x = (i as f64 + 0.5) * dx;
        f_n_at(x, weights) * dx
    }).sum()
}

// ═══════════════════════════════════════════════════════════════════
// PNT PARTIAL SUMS
// ═══════════════════════════════════════════════════════════════════

/// S₁(M) = Σ_{k=1}^{M} μ(k)/k
///
/// PNT target: S₁(∞) = 0 (equivalent to PNT).
pub fn pnt_s1(mu: &[i8], m: usize) -> f64 {
    (1..=m.min(mu.len() - 1)).map(|k| mu[k] as f64 / k as f64).sum()
}

/// S₂(M) = Σ_{k=1}^{M} μ(k)·ln(k)/k
///
/// PNT target: S₂(∞) = -1.
pub fn pnt_s2(mu: &[i8], m: usize) -> f64 {
    (1..=m.min(mu.len() - 1)).map(|k| {
        mu[k] as f64 * (k as f64).ln() / k as f64
    }).sum()
}

/// S₃(M) = Σ_{k=1}^{M} μ(k)·ln²(k)/k
///
/// PNT target: S₃(∞) = -2γ (where γ is Euler-Mascheroni).
pub fn pnt_s3(mu: &[i8], m: usize) -> f64 {
    (1..=m.min(mu.len() - 1)).map(|k| {
        let logk = (k as f64).ln();
        mu[k] as f64 * logk * logk / k as f64
    }).sum()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::arith;

    #[test]
    fn test_mertens_values() {
        let mu = arith::mobius_table(100);
        let m = mertens_values(&mu);
        assert_eq!(m[1], 1);
        assert_eq!(m[2], 0);
        assert_eq!(m[3], -1);
        assert_eq!(m[4], -1);
        assert_eq!(m[5], -2);
        assert_eq!(m[6], -1);
        assert_eq!(m[10], -1);
    }

    #[test]
    fn test_log_cutoff_weights() {
        let mu = arith::mobius_table(20);
        let w = log_cutoff_weights(10, &mu);
        // w[0] corresponds to k=1, μ(1)=1
        assert!(w[0] < 0.0); // -μ(1) * (1 - 0/ln10) = -1
        // k=4: μ(4)=0, so w[3]=0
        assert_eq!(w[3], 0.0);
    }

    #[test]
    fn test_chebyshev_theta() {
        let sieve = arith::sieve_primes(100);
        let theta = chebyshev_theta(&sieve, 10);
        // θ(10) = ln(2) + ln(3) + ln(5) + ln(7) ≈ 5.347
        assert!((theta - 5.347).abs() < 0.01);
    }

    #[test]
    fn test_pnt_sums() {
        let mu = arith::mobius_table(10000);
        let s1 = pnt_s1(&mu, 10000);
        let s2 = pnt_s2(&mu, 10000);
        // S₁ should be close to 0, S₂ close to -1
        assert!(s1.abs() < 0.1, "S₁(10000) = {}", s1);
        assert!((s2 + 1.0).abs() < 0.2, "S₂(10000) = {}", s2);
    }

    #[test]
    fn test_f_n_at() {
        let mu = arith::mobius_table(20);
        let w = log_cutoff_weights(10, &mu);
        // f_N(0.5) should be finite
        let val = f_n_at(0.5, &w);
        assert!(val.is_finite());
        // f_N at x=0 should be 0 (guarded)
        assert_eq!(f_n_at(0.0, &w), 0.0);
    }
}
