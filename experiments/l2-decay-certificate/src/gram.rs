//! Gram matrix entry computation via high-precision quadrature.
//!
//! G_{j,k} = ∫₀¹ {1/(jx)} · {1/(kx)} dx
//! b_k     = ∫₀¹ {1/(kx)} dx
//!
//! Uses adaptive Gauss-Legendre quadrature with breakpoints at every
//! discontinuity x = 1/(j·m) and x = 1/(k·m).

use rug::Float;
use crate::sieve::P;

/// Fractional part of a Float
fn fract_val(x: &Float) -> Float {
    let floor_val = x.clone().floor();
    Float::with_val(P, x - floor_val)
}

/// 8-point Gauss-Legendre nodes and weights on [-1,1]
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

/// Gram matrix entry G_{j,k} = ∫₀¹ {1/(jx)} · {1/(kx)} dx
/// Exact piecewise-smooth integration with breakpoints.
pub fn gram_entry(j: usize, k: usize) -> Float {
    let j_f_inv = Float::with_val(P, 1u32) / Float::with_val(P, j as u64);
    let k_f_inv = Float::with_val(P, 1u32) / Float::with_val(P, k as u64);

    let max_jk = std::cmp::max(j, k);
    let mut bp = breakpoints(j, k, max_jk);
    bp.push(Float::with_val(P, 0));
    bp.push(Float::with_val(P, 1));
    bp.sort_by(|a, b| a.partial_cmp(b).unwrap());
    bp.dedup();

    let mut total = Float::with_val(P, 0);
    for i in 0..bp.len() - 1 {
        let a = &bp[i];
        let b = &bp[i + 1];
        if b <= a { continue; }
        let half_len = Float::with_val(P, Float::with_val(P, b - a) / 2);
        let mid = Float::with_val(P, Float::with_val(P, a + b) / 2);

        for &(node, weight) in &GL8 {
            let x = Float::with_val(P, &mid + Float::with_val(P, node) * &half_len);
            if x <= 0 { continue; }
            let fj = fract_val(&Float::with_val(P, &j_f_inv / &x));
            let fk = fract_val(&Float::with_val(P, &k_f_inv / &x));
            let prod = Float::with_val(P, &fj * &fk);
            let wt = Float::with_val(P, prod * Float::with_val(P, weight));
            total += Float::with_val(P, wt * &half_len);
        }
    }
    total
}

/// Mean vector entry b_k = ∫₀¹ {1/(kx)} dx
pub fn mean_entry(k: usize) -> Float {
    let k_f_inv = Float::with_val(P, 1u32) / Float::with_val(P, k as u64);

    let mut bp: Vec<Float> = Vec::new();
    bp.push(Float::with_val(P, 0));
    for m in 1..=(2 * k) {
        let v = Float::with_val(P, 1u32) / Float::with_val(P, (k * m) as u64);
        if v > 0 && v < 1 { bp.push(v); }
    }
    bp.push(Float::with_val(P, 1));
    bp.sort_by(|a, b| a.partial_cmp(b).unwrap());
    bp.dedup();

    let mut total = Float::with_val(P, 0);
    for i in 0..bp.len() - 1 {
        let a = &bp[i];
        let b = &bp[i + 1];
        if b <= a { continue; }
        let half_len = Float::with_val(P, Float::with_val(P, b - a) / 2);
        let mid = Float::with_val(P, Float::with_val(P, a + b) / 2);
        for &(node, weight) in &GL8 {
            let x = Float::with_val(P, &mid + Float::with_val(P, node) * &half_len);
            if x <= 0 { continue; }
            let fk = fract_val(&Float::with_val(P, &k_f_inv / &x));
            let wt = Float::with_val(P, &fk * Float::with_val(P, weight));
            total += Float::with_val(P, wt * &half_len);
        }
    }
    total
}

/// Compute breakpoints where {1/(jx)} or {1/(kx)} has a discontinuity
fn breakpoints(j: usize, k: usize, max_jk: usize) -> Vec<Float> {
    let mut bp = Vec::new();
    for m in 1..=(2 * max_jk) {
        let bp_j = Float::with_val(P, 1u32) / Float::with_val(P, (j * m) as u64);
        let bp_k = Float::with_val(P, 1u32) / Float::with_val(P, (k * m) as u64);
        if bp_j > 0 && bp_j < 1 { bp.push(bp_j); }
        if bp_k > 0 && bp_k < 1 { bp.push(bp_k); }
    }
    bp
}
