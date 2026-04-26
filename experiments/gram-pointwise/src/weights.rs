//! High-precision weight and f_N(x) computation at 512-bit MPFR

use rug::Float;

pub const P: u32 = 512;

/// Log-cutoff Möbius weights: w_k = -μ(k)·(1 - ln(k)/ln(N))
pub fn log_cutoff_weights(n: usize, mu: &[i8]) -> Vec<Float> {
    let log_n = Float::with_val(P, n as u64).ln();
    (1..n).map(|k| {
        if mu[k] == 0 { return Float::with_val(P, 0); }
        let log_k = Float::with_val(P, k as u64).ln();
        let taper = Float::with_val(P, 1u32) - Float::with_val(P, &log_k / &log_n);
        Float::with_val(P, -(mu[k] as f64)) * &taper
    }).collect()
}

/// f_N(x) = Σ_{k=1}^{N-1} w_k · {1/(kx)}
pub fn f_n_at(x: &Float, w: &[Float]) -> Float {
    let mut sum = Float::with_val(P, 0);
    for (i, wk) in w.iter().enumerate() {
        if wk.is_zero() { continue; }
        let k = (i + 1) as u64;
        let kx = Float::with_val(P, k) * x;
        let inv = Float::with_val(P, 1u32) / &kx;
        let frac = Float::with_val(P, &inv - inv.clone().floor());
        sum += Float::with_val(P, wk * &frac);
    }
    sum
}

/// Partial sum of weights: A(K) = Σ_{k=1}^{K} w_k
pub fn weight_partial_sums(w: &[Float]) -> Vec<Float> {
    let mut ps = vec![Float::with_val(P, 0)];
    for wk in w {
        let prev = ps.last().unwrap().clone();
        ps.push(Float::with_val(P, &prev + wk));
    }
    ps
}
