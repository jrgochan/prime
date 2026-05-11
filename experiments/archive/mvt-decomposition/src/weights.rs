//! High-precision weight computation at 512-bit MPFR

use rug::Float;

pub const P: u32 = 512;

/// Log-cutoff Möbius weights: w_k = -μ(k)·(1 - ln(k)/ln(N))
pub fn log_cutoff_weights(n: usize, mu: &[i8]) -> Vec<Float> {
    let log_n = Float::with_val(P, n as u64).ln();
    (1..n)
        .map(|k| {
            if mu[k] == 0 {
                return Float::with_val(P, 0);
            }
            let log_k = Float::with_val(P, k as u64).ln();
            let taper = Float::with_val(P, 1u32) - Float::with_val(P, &log_k / &log_n);
            Float::with_val(P, -(mu[k] as f64)) * &taper
        })
        .collect()
}

/// BD Dirichlet coefficients in f64: aₙ = -μ(n)·(1-log(n)/log(N))/√n
pub fn bd_dirichlet_coeffs(n: usize, mu: &[i8]) -> Vec<f64> {
    let log_n = (n as f64).ln();
    (0..n)
        .map(|k| {
            if k == 0 {
                return 0.0;
            }
            if mu[k] == 0 {
                return 0.0;
            }
            let taper = 1.0 - (k as f64).ln() / log_n;
            if taper <= 0.0 {
                return 0.0;
            }
            -(mu[k] as f64) * taper / (k as f64).sqrt()
        })
        .collect()
}
