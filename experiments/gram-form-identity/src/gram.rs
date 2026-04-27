//! Gram entry computation and number-theoretic helpers

use std::f64::consts::PI;

/// Euler-Mascheroni constant
pub const GAMMA: f64 = 0.5772156649015329;

/// log(2π) - γ
pub const A: f64 = 1.2608571238732776; // ln(2π) - γ

fn gcd(a: u64, b: u64) -> u64 {
    if b == 0 { a } else { gcd(b, a % b) }
}

/// Vasyunin sum V(a,b) = Σ_{m=1}^{a-1} {mb/a} · cot(πm/a)
pub fn vasyunin_sum(a: u64, b: u64) -> f64 {
    if a <= 1 { return 0.0; }
    let af = a as f64;
    let bf = b as f64;
    (1..a).map(|m| {
        let mf = m as f64;
        let frac = (mf * bf / af).fract();
        let frac = if frac < 0.0 { frac + 1.0 } else { frac };
        frac / (PI * mf / af).tan()
    }).sum()
}

/// Gram entry G(j,k) — closed form from Vasyunin
pub fn gram_entry(j: u64, k: u64) -> f64 {
    let jf = j as f64;
    let kf = k as f64;
    if j == k {
        A / jf - 1.0 / (jf * jf)
    } else {
        let d = gcd(j, k);
        let jp = j / d;
        let kp = k / d;
        let df = d as f64;
        let term1 = A / 2.0 * (1.0 / jf + 1.0 / kf);
        let term2 = (jf - kf) / (2.0 * jf * kf) * (kf / jf).ln();
        let term3 = PI * df / (2.0 * jf * kf) *
            (vasyunin_sum(jp, kp) + vasyunin_sum(kp, jp));
        let term4 = 1.0 / (jf * kf);
        term1 + term2 - term3 - term4
    }
}

/// BD weight: v_k = -μ(k) · (1 - log(k)/log(N))
pub fn bd_weight(mu_k: i8, k: u64, log_n: f64) -> f64 {
    -(mu_k as f64) * (1.0 - (k as f64).ln() / log_n)
}

/// Mean vector entry: b_k = (log(k) + 1 - γ) / k
pub fn mean_entry(k: u64) -> f64 {
    ((k as f64).ln() + 1.0 - GAMMA) / k as f64
}

/// S₁(M) = Σ_{k=1}^M μ(k)/k
pub fn s1(mu: &[i8], m: usize) -> f64 {
    (1..=m).map(|k| mu[k] as f64 / k as f64).sum()
}

/// S₂(M) = Σ_{k=1}^M μ(k)·log(k)/k
pub fn s2(mu: &[i8], m: usize) -> f64 {
    (1..=m).map(|k| mu[k] as f64 * (k as f64).ln() / k as f64).sum()
}

/// S₃(M) = Σ_{k=1}^M μ(k)·log²(k)/k
pub fn s3(mu: &[i8], m: usize) -> f64 {
    (1..=m).map(|k| {
        let logk = (k as f64).ln();
        mu[k] as f64 * logk * logk / k as f64
    }).sum()
}

/// Evaluate f_N(x) = Σ_{k=1}^{N-1} v_k · {1/(kx)}
/// where {y} = y - floor(y) is the fractional part
pub fn f_n_at(x: f64, weights: &[f64]) -> f64 {
    if x <= 0.0 { return 0.0; }
    let mut sum = 0.0;
    for k in 1..weights.len() {
        let w = weights[k];
        if w == 0.0 { continue; }
        let y = 1.0 / (k as f64 * x);
        let frac = y - y.floor();
        sum += w * frac;
    }
    sum
}

/// Compute vᵀGv = ∫₀¹ f_N(x)² dx via midpoint quadrature
/// This is O(N·n_pts) instead of O(N²) for the Gram matrix approach
pub fn vtgv_by_integral(weights: &[f64], n_pts: usize) -> f64 {
    let dx = 1.0 / n_pts as f64;
    (0..n_pts).map(|i| {
        let x = (i as f64 + 0.5) * dx;
        let f = f_n_at(x, weights);
        f * f * dx
    }).sum()
}

/// Compute bᵀv = ∫₀¹ f_N(x) dx via midpoint quadrature
pub fn btv_by_integral(weights: &[f64], n_pts: usize) -> f64 {
    let dx = 1.0 / n_pts as f64;
    (0..n_pts).map(|i| {
        let x = (i as f64 + 0.5) * dx;
        f_n_at(x, weights) * dx
    }).sum()
}

/// Precompute BD weights vector for a given N
pub fn precompute_weights(n: usize, mu: &[i8]) -> Vec<f64> {
    let m = n - 1;
    let log_n = (n as f64).ln();
    (0..=m).map(|k| {
        if k == 0 { 0.0 } else { bd_weight(mu[k], k as u64, log_n) }
    }).collect()
}

