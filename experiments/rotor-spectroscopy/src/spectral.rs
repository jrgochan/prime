//! ═══════════════════════════════════════════════════════════════════════════
//!  SPECTRAL ANALYSIS: 512-bit MPFR · Massively Parallel
//!
//!  Validates: GallagherMVT.lean, FrequencySeparation.lean
//!  Physics:   Completeness relation, dispersion relation, Van Hove
//! ═══════════════════════════════════════════════════════════════════════════

use rug::Float;
use rayon::prelude::*;

use crate::weights::P;

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

/// |D_N(1/2+it)|² in 512-bit MPFR
/// D_N(s) = Σ v_k · k^{-s} where s = 1/2 + it
pub fn dirichlet_poly_norm_sq_mpfr(weights: &[Float], t: f64) -> f64 {
    let t_mpfr = Float::with_val(P, t);
    let mut re = Float::with_val(P, 0);
    let mut im = Float::with_val(P, 0);

    for (i, vk) in weights.iter().enumerate() {
        if *vk == 0.0 { continue; }
        let k = (i + 1) as f64;
        let k_mpfr = Float::with_val(P, k);
        // k^{-1/2} = 1/sqrt(k)
        let k_sqrt = k_mpfr.clone().sqrt();
        let k_inv_sqrt = Float::with_val(P, k_sqrt.recip());
        let vk_amp = Float::with_val(P, vk * &k_inv_sqrt);
        // phase = t · ln(k)
        let phase = Float::with_val(P, &t_mpfr * k_mpfr.ln());
        let (sin_p, cos_p) = phase.sin_cos(Float::new(P));
        let re_term = Float::with_val(P, &vk_amp * &cos_p);
        let im_term = Float::with_val(P, &vk_amp * &sin_p);
        re += re_term;
        im -= im_term;
    }
    let re_sq = Float::with_val(P, &re * &re);
    let im_sq = Float::with_val(P, &im * &im);
    let norm_sq = Float::with_val(P, re_sq + im_sq);
    norm_sq.to_f64()
}

/// f64 fast path for |D_N(1/2+it)|²
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

/// Per-channel |D_N^{(chi)}(1/2+it)|² with 512-bit MPFR
pub fn channel_dirichlet_norm_sq_mpfr(
    weights: &[Float], chi_table: &[i8; 8], t: f64
) -> f64 {
    let t_mpfr = Float::with_val(P, t);
    let mut re = Float::with_val(P, 0);
    let mut im = Float::with_val(P, 0);

    for (i, vk) in weights.iter().enumerate() {
        let k = i + 1;
        let c = chi_table[k % 8];
        if c == 0 || *vk == 0.0 { continue; }
        let k_mpfr = Float::with_val(P, k as f64);
        let k_sqrt = k_mpfr.clone().sqrt();
        let k_inv_sqrt = Float::with_val(P, k_sqrt.recip());
        let vk_amp = Float::with_val(P, vk * &k_inv_sqrt);
        let cvk_amp = Float::with_val(P, &vk_amp * c as f64);
        let phase = Float::with_val(P, &t_mpfr * k_mpfr.ln());
        let (sin_p, cos_p) = phase.sin_cos(Float::new(P));
        let re_term = Float::with_val(P, &cvk_amp * &cos_p);
        let im_term = Float::with_val(P, &cvk_amp * &sin_p);
        re += re_term;
        im -= im_term;
    }
    let re_sq = Float::with_val(P, &re * &re);
    let im_sq = Float::with_val(P, &im * &im);
    let norm_sq = Float::with_val(P, re_sq + im_sq);
    norm_sq.to_f64()
}

/// Gallagher MVT validation — massively parallel over integration panels
pub struct GallagherResult {
    pub n: usize,
    pub sum_vk_sq: f64,
    pub integral: f64,
    pub relative_error: f64,
    pub t_max: f64,
    pub n_panels: usize,
}

fn fejer_kernel(t: f64, delta: f64) -> f64 {
    let x = delta * t / 2.0;
    if x.abs() < 1e-12 {
        delta / (2.0 * std::f64::consts::PI)
    } else {
        delta * (x.sin() / x).powi(2) / (2.0 * std::f64::consts::PI)
    }
}

pub fn gallagher_validate(n: usize, weights_f64: &[f64], t_max: f64) -> GallagherResult {
    let sum_vk_sq: f64 = weights_f64.iter().map(|v| v * v).sum();
    let delta = 1.0 / (n as f64 + 1.0);
    let n_panels = ((t_max * 4.0) as usize).max(400).min(20000);
    let dt = 2.0 * t_max / n_panels as f64;

    // Massively parallel: each panel is independent
    let integral: f64 = (0..n_panels).into_par_iter().map(|i| {
        let a = -t_max + i as f64 * dt;
        let b = a + dt;
        gl8_integrate(&|t| {
            dirichlet_poly_norm_sq(weights_f64, t) * fejer_kernel(t, delta)
        }, a, b)
    }).sum();

    let relative_error = if sum_vk_sq > 0.0 {
        (integral - sum_vk_sq).abs() / sum_vk_sq
    } else { 0.0 };

    GallagherResult { n, sum_vk_sq, integral, relative_error, t_max, n_panels }
}

/// Dispersion relation: min |log(j) - log(k)| for 1 ≤ k < j ≤ N
pub struct DispersionResult {
    pub n: usize,
    pub min_gap: f64,
    pub min_gap_mpfr: f64,        // 512-bit verification
    pub theoretical_bound: f64,
    pub ratio: f64,
    pub pair: (usize, usize),
}

pub fn dispersion_relation(n: usize) -> DispersionResult {
    let theoretical_bound = 1.0 / (n as f64 + 1.0);

    // The minimum is always at consecutive integers near the top: log((N)/(N-1))
    // But verify with MPFR for certification
    let k = n - 1;
    let gap_mpfr = {
        let a = Float::with_val(P, n).ln();
        let b = Float::with_val(P, k).ln();
        (a - b).to_f64()
    };

    let min_gap = ((n as f64) / (k as f64)).ln();
    let ratio = min_gap / theoretical_bound;

    DispersionResult {
        n, min_gap, min_gap_mpfr: gap_mpfr,
        theoretical_bound, ratio, pair: (n, k),
    }
}

/// Spectral profile — massively parallel over t values, 512-bit MPFR
pub fn spectral_profile_mpfr(
    weights: &[Float], t_values: &[f64]
) -> Vec<(f64, f64, [f64; 4])> {
    t_values.par_iter().map(|&t| {
        let total = dirichlet_poly_norm_sq_mpfr(weights, t);
        let mut channels = [0.0f64; 4];
        for i in 0..4 {
            channels[i] = channel_dirichlet_norm_sq_mpfr(
                weights, &crate::characters::CHI_TABLE[i], t
            );
        }
        (t, total, channels)
    }).collect()
}

/// f64 fast path for spectral profile
pub fn spectral_profile(weights: &[f64], t_values: &[f64]) -> Vec<(f64, f64, [f64; 4])> {
    t_values.par_iter().map(|&t| {
        let total = dirichlet_poly_norm_sq(weights, t);
        let mut channels = [0.0f64; 4];
        for i in 0..4 {
            channels[i] = channel_dirichlet_norm_sq_f64(
                weights, &crate::characters::CHI_TABLE[i], t
            );
        }
        (t, total, channels)
    }).collect()
}

fn channel_dirichlet_norm_sq_f64(weights: &[f64], chi_table: &[i8; 8], t: f64) -> f64 {
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
