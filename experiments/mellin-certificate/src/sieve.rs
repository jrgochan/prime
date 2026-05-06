//! MPFR-precision weight computation — delegates sieving to cathedral-utils

use rug::Float;

pub const P: u32 = 256;

/// Log-cutoff Möbius weights: w_k = -μ(k) · (1 - ln(k)/ln(N))
/// Matches Lean's `bdMoebiusWeight N i = -μ(i+1) · logWeight(N, i+1)`
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
/// The Nyman-Beurling approximant.
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
