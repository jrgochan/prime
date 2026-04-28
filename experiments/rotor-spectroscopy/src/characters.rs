//! ═══════════════════════════════════════════════════════════════════════════
//!  DIRICHLET CHARACTERS MOD 8 — Massively Parallel
//!  The Stained Glass Rotors — 4 orthogonal syndrome channels
//!
//!  Validates: GallagherPartition.lean `discrete_energy_partition`
//!  Physics:   Quantum error-correcting code (stabilizer syndrome channels)
//! ═══════════════════════════════════════════════════════════════════════════

use rayon::prelude::*;

/// The 4 Dirichlet characters mod 8.
///   k mod 8:  0  1  2  3  4  5  6  7
///   χ₁:       0  1  0  1  0  1  0  1   (principal)
///   χ₂:       0  1  0  1  0 -1  0 -1
///   χ₃:       0  1  0 -1  0  1  0 -1
///   χ₄:       0  1  0 -1  0 -1  0  1
pub const CHI_TABLE: [[i8; 8]; 4] = [
    [0, 1, 0, 1, 0, 1, 0, 1],
    [0, 1, 0, 1, 0, -1, 0, -1],
    [0, 1, 0, -1, 0, 1, 0, -1],
    [0, 1, 0, -1, 0, -1, 0, 1],
];

pub const CHI_NAMES: [&str; 4] = ["χ₁ (principal)", "χ₂", "χ₃", "χ₄"];

#[inline]
pub fn chi(chi_idx: usize, k: usize) -> i8 {
    CHI_TABLE[chi_idx][k % 8]
}

/// Verify orthogonality: Σ_{k=0..7} χ_i(k)·χ_j(k) = 0 for i≠j, = φ(8)=4 for i=j
pub fn verify_orthogonality() -> Vec<(usize, usize, i32, bool)> {
    let mut results = Vec::new();
    for i in 0..4 {
        for j in 0..4 {
            let sum: i32 = (0..8).map(|k| {
                CHI_TABLE[i][k] as i32 * CHI_TABLE[j][k] as i32
            }).sum();
            let expected = if i == j { 4 } else { 0 };
            results.push((i, j, sum, sum == expected));
        }
    }
    results
}

/// Per-channel energy: E_i(N) = Σ_{k=1}^{N-1} |χ_i(k)|² · v_k²
/// Parallel over chunks for large N
pub fn channel_energy(chi_idx: usize, weights: &[f64]) -> f64 {
    let chunk_size = (weights.len() / rayon::current_num_threads()).max(256);
    weights.par_chunks(chunk_size)
        .enumerate()
        .map(|(ci, chunk)| {
            let base = ci * chunk_size;
            chunk.iter().enumerate().map(|(i, &vk)| {
                let k = base + i + 1;
                let c = chi(chi_idx, k) as f64;
                c * c * vk * vk
            }).sum::<f64>()
        }).sum()
}

/// Per-channel energy breakdown for all 4 channels
pub struct ChannelBreakdown {
    pub n: usize,
    pub total_energy: f64,
    pub odd_energy: f64,
    pub even_energy: f64,
    pub channel_energy: [f64; 4],
    pub channel_fraction: [f64; 4],
    pub partition_sum: f64,
    pub partition_error: f64,
}

pub fn channel_breakdown(n: usize, weights: &[f64]) -> ChannelBreakdown {
    let total_energy: f64 = weights.par_iter().map(|v| v * v).sum();

    let odd_energy: f64 = weights.par_iter().enumerate()
        .filter(|(i, _)| { let k = i + 1; k % 2 != 0 })
        .map(|(_, v)| v * v).sum();
    let even_energy = total_energy - odd_energy;

    // Compute all 4 channels in parallel
    let ce: Vec<f64> = (0..4usize).into_par_iter()
        .map(|i| channel_energy(i, weights))
        .collect();
    let mut channel_e = [0.0f64; 4];
    let mut channel_f = [0.0f64; 4];
    for i in 0..4 {
        channel_e[i] = ce[i];
        channel_f[i] = if odd_energy > 0.0 { ce[i] / odd_energy } else { 0.0 };
    }

    let partition_sum = 0.25 * ce.iter().sum::<f64>();
    let partition_error = if odd_energy > 0.0 {
        (partition_sum - odd_energy).abs() / odd_energy
    } else { 0.0 };

    ChannelBreakdown {
        n, total_energy, odd_energy, even_energy,
        channel_energy: channel_e, channel_fraction: channel_f,
        partition_sum, partition_error,
    }
}
