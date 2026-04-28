//! ═══════════════════════════════════════════════════════════════════════════
//!  SPECTRAL ANALYSIS: GALLAGHER MVT + DISPERSION RELATION
//!
//!  Validates: GallagherMVT.lean, FrequencySeparation.lean
//!  Physics:   Completeness relation, dispersion relation, Van Hove
//! ═══════════════════════════════════════════════════════════════════════════

use rayon::prelude::*;

// GL8 quadrature nodes and weights
const GL8: [(f64, f64); 8] = [
    (-0.96028985649753623, 0.10122853629037626),
    (-0.79666647741362674, 0.22238103445337447),
    (-0.52553240991632899, 0.31370664587788729),
    (-0.18343464249564980, 0.36268378337836198),
    ( 0.18343464249564980, 0.36268378337836198),
    ( 0.52553240991632899, 0.31370664587788729),
    ( 0.79666647741362674, 0.22238103445337447),
    ( 0.96028985649753623, 0.10122853629037626),
];

fn gl8_integrate<F: Fn(f64) -> f64>(f: &F, a: f64, b: f64) -> f64 {
    let half = (b - a) / 2.0;
    let mid = (a + b) / 2.0;
    let mut s = 0.0;
    for &(node, weight) in &GL8 {
        s += weight * f(mid + half * node);
    }
    s * half
}

/// |D_N(1/2+it)|² = |Σ v_k · k^{-1/2-it}|²
pub fn dirichlet_poly_norm_sq(weights: &[f64], t: f64) -> f64 {
    let mut re = 0.0f64;
    let mut im = 0.0f64;
    for (i, &vk) in weights.iter().enumerate() {
        if vk == 0.0 { continue; }
        let k = (i + 1) as f64;
        let amp = vk / k.sqrt();
        let phase = t * k.ln();
        re += amp * phase.cos();
        im -= amp * phase.sin();
    }
    re * re + im * im
}

/// Per-channel |D_N^{(chi)}(1/2+it)|² where D_N^{(chi)} uses χ-weighted coefficients
pub fn channel_dirichlet_norm_sq(weights: &[f64], chi_table: &[i8; 8], t: f64) -> f64 {
    let mut re = 0.0f64;
    let mut im = 0.0f64;
    for (i, &vk) in weights.iter().enumerate() {
        let k = i + 1;
        let c = chi_table[k % 8] as f64;
        let cvk = c * vk;
        if cvk == 0.0 { continue; }
        let amp = cvk / (k as f64).sqrt();
        let phase = t * (k as f64).ln();
        re += amp * phase.cos();
        im -= amp * phase.sin();
    }
    re * re + im * im
}

/// Gallagher MVT validation:
/// ∫ |D_N(t)|² · K_δ(t) dt ≈ Σ |v_k|²
/// where K_δ is the Fejér kernel with δ = 1/(N+1)
pub struct GallagherResult {
    pub n: usize,
    pub sum_vk_sq: f64,       // Σ|v_k|²
    pub integral: f64,        // ∫|D_N|² · K_δ dt / (2π)
    pub relative_error: f64,  // |integral - sum| / sum
    pub t_max: f64,
}

/// Fejér kernel: K_δ(t) = δ · sinc²(δt/2) · (1/(2π))
fn fejer_kernel(t: f64, delta: f64) -> f64 {
    let x = delta * t / 2.0;
    if x.abs() < 1e-12 {
        delta / (2.0 * std::f64::consts::PI)
    } else {
        delta * (x.sin() / x).powi(2) / (2.0 * std::f64::consts::PI)
    }
}

pub fn gallagher_validate(n: usize, weights: &[f64], t_max: f64) -> GallagherResult {
    let sum_vk_sq: f64 = weights.iter().map(|v| v * v).sum();
    let delta = 1.0 / (n as f64 + 1.0);
    let n_panels = (t_max as usize).max(200).min(10000);
    let dt = 2.0 * t_max / n_panels as f64;

    let integral: f64 = (0..n_panels).into_par_iter().map(|i| {
        let a = -t_max + i as f64 * dt;
        let b = a + dt;
        gl8_integrate(&|t| {
            dirichlet_poly_norm_sq(weights, t) * fejer_kernel(t, delta)
        }, a, b)
    }).sum();

    let relative_error = if sum_vk_sq > 0.0 {
        (integral - sum_vk_sq).abs() / sum_vk_sq
    } else { 0.0 };

    GallagherResult { n, sum_vk_sq, integral, relative_error, t_max }
}

/// Dispersion relation: min |log(j) - log(k)| for 1 ≤ k < j ≤ N
pub struct DispersionResult {
    pub n: usize,
    pub min_gap: f64,           // actual minimum gap
    pub theoretical_bound: f64, // 1/(N+1)
    pub ratio: f64,             // min_gap / bound (should be ≥ 1)
    pub pair: (usize, usize),   // (j, k) achieving minimum
}

pub fn dispersion_relation(n: usize) -> DispersionResult {
    let theoretical_bound = 1.0 / (n as f64 + 1.0);
    let mut min_gap = f64::INFINITY;
    let mut pair = (0, 0);

    // Minimum gap is always between consecutive integers: log(k+1) - log(k) = log(1+1/k)
    // which is minimized at k = N-1
    for k in 1..n {
        let gap = ((k + 1) as f64).ln() - (k as f64).ln();
        if gap < min_gap {
            min_gap = gap;
            pair = (k + 1, k);
        }
    }

    let ratio = min_gap / theoretical_bound;
    DispersionResult { n, min_gap, theoretical_bound, ratio, pair }
}

/// Spectral profile: |D_N(1/2+it)|² at sampled t values
pub fn spectral_profile(weights: &[f64], t_values: &[f64]) -> Vec<(f64, f64, [f64; 4])> {
    t_values.iter().map(|&t| {
        let total = dirichlet_poly_norm_sq(weights, t);
        let mut channels = [0.0f64; 4];
        for i in 0..4 {
            channels[i] = channel_dirichlet_norm_sq(weights, &super::characters::CHI_TABLE[i], t);
        }
        (t, total, channels)
    }).collect()
}
