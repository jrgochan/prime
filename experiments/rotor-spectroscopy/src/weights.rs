//! ═══════════════════════════════════════════════════════════════════════════
//!  BD WEIGHTS — 512-bit MPFR precision
//!
//!  Validates: CalcBounds.lean `bd_weights_log_taper`
//!  Physics:   Bartlett window / UV cutoff coefficients
//! ═══════════════════════════════════════════════════════════════════════════

use rayon::prelude::*;
use rug::Float;

pub const P: u32 = 512;

/// Log-cutoff Möbius weights: v_k = -μ(k)·(1 - ln(k)/ln(N))
/// Computed in 512-bit MPFR, returned as f64 for energy computations
pub fn bd_weights(n: usize, mu: &[i8]) -> Vec<f64> {
    let log_n = Float::with_val(P, n).ln();
    (1..n)
        .map(|k| {
            if mu[k] == 0 {
                return 0.0;
            }
            let log_k = Float::with_val(P, k).ln();
            let ratio = Float::with_val(P, &log_k / &log_n);
            let taper = Float::with_val(P, 1.0) - ratio;
            if taper <= 0.0 {
                return 0.0;
            }

            -(mu[k] as f64) * taper.to_f64()
        })
        .collect()
}

/// High-precision weights kept as Float for spectral computations
pub fn bd_weights_mpfr(n: usize, mu: &[i8]) -> Vec<Float> {
    let log_n = Float::with_val(P, n).ln();
    (1..n)
        .map(|k| {
            if mu[k] == 0 {
                return Float::with_val(P, 0);
            }
            let log_k = Float::with_val(P, k).ln();
            let ratio = Float::with_val(P, &log_k / &log_n);
            let taper = Float::with_val(P, 1.0) - ratio;
            if taper <= 0.0 {
                return Float::with_val(P, 0);
            }
            let mut v = taper;
            if mu[k] == 1 {
                v = -v;
            } // v_k = -μ(k) · taper
            v
        })
        .collect()
}

/// Residue class statistics for the 8 classes mod 8
pub struct ResidueStats {
    pub class_energy: [f64; 8],
    pub class_count: [usize; 8],
    pub class_fraction: [f64; 8],
    pub total_energy: f64,
}

pub fn residue_class_stats(_n: usize, weights: &[f64]) -> ResidueStats {
    // Parallel accumulation over chunks
    let chunk_size = (weights.len() / rayon::current_num_threads()).max(256);
    let partial: Vec<([f64; 8], [usize; 8])> = weights
        .par_chunks(chunk_size)
        .enumerate()
        .map(|(ci, chunk)| {
            let base = ci * chunk_size;
            let mut ce = [0.0f64; 8];
            let mut cc = [0usize; 8];
            for (i, &vk) in chunk.iter().enumerate() {
                let k = base + i + 1;
                let r = k % 8;
                if vk != 0.0 {
                    ce[r] += vk * vk;
                    cc[r] += 1;
                }
            }
            (ce, cc)
        })
        .collect();

    let mut class_energy = [0.0f64; 8];
    let mut class_count = [0usize; 8];
    for (ce, cc) in &partial {
        for r in 0..8 {
            class_energy[r] += ce[r];
            class_count[r] += cc[r];
        }
    }

    let total_energy: f64 = class_energy.iter().sum();
    let mut class_fraction = [0.0f64; 8];
    for r in 0..8 {
        class_fraction[r] = if total_energy > 0.0 {
            class_energy[r] / total_energy
        } else {
            0.0
        };
    }

    ResidueStats {
        class_energy,
        class_count,
        class_fraction,
        total_energy,
    }
}
