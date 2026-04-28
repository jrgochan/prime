//! ═══════════════════════════════════════════════════════════════════════════
//!  DIRICHLET CHARACTERS MOD 8
//!  The Stained Glass Rotors — 4 orthogonal syndrome channels
//!
//!  Validates: GallagherPartition.lean `discrete_energy_partition`
//!  Physics:   Quantum error-correcting code (stabilizer syndrome channels)
//! ═══════════════════════════════════════════════════════════════════════════

/// The 4 Dirichlet characters mod 8.
/// χ₁ = principal character (trivial)
/// χ₂, χ₃, χ₄ = non-trivial characters
///
/// Character table:
///   k mod 8:  1   3   5   7   (0,2,4,6 → 0)
///   χ₁:       1   1   1   1
///   χ₂:       1   1  -1  -1
///   χ₃:       1  -1   1  -1
///   χ₄:       1  -1  -1   1
pub const CHI_TABLE: [[i8; 8]; 4] = [
    // χ₁: principal character
    [0, 1, 0, 1, 0, 1, 0, 1],
    // χ₂
    [0, 1, 0, 1, 0, -1, 0, -1],
    // χ₃
    [0, 1, 0, -1, 0, 1, 0, -1],
    // χ₄
    [0, 1, 0, -1, 0, -1, 0, 1],
];

pub const CHI_NAMES: [&str; 4] = ["χ₁ (principal)", "χ₂", "χ₃", "χ₄"];

/// Evaluate character chi_idx at k
#[inline]
pub fn chi(chi_idx: usize, k: usize) -> i8 {
    CHI_TABLE[chi_idx][k % 8]
}

/// Verify orthogonality: Σ_{k=1..8} χ_i(k)·χ_j(k) = 0 for i≠j, = φ(8)=4 for i=j
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
pub fn channel_energy(chi_idx: usize, weights: &[f64]) -> f64 {
    weights.iter().enumerate().map(|(i, &vk)| {
        let k = i + 1;
        let c = chi(chi_idx, k) as f64;
        c * c * vk * vk
    }).sum()
}

/// Per-channel energy breakdown for all 4 channels
pub struct ChannelBreakdown {
    pub n: usize,
    pub total_energy: f64,
    pub odd_energy: f64,          // Σ_{gcd(k,8)=1} |v_k|² (coprime to 8)
    pub even_energy: f64,         // Σ_{gcd(k,8)>1} |v_k|² (dark sector)
    pub channel_energy: [f64; 4],
    pub channel_fraction: [f64; 4],  // E_i / odd_energy
    pub partition_sum: f64,       // (1/4)·Σ E_i — should equal odd_energy
    pub partition_error: f64,     // |partition_sum - odd_energy| / odd_energy
}

pub fn channel_breakdown(n: usize, weights: &[f64]) -> ChannelBreakdown {
    let total_energy: f64 = weights.iter().map(|v| v * v).sum();

    // Energy from k coprime to 8 (odd k not divisible by 4... actually gcd(k,8)=1 means k is odd)
    let odd_energy: f64 = weights.iter().enumerate()
        .filter(|(i, _)| { let k = i + 1; k % 2 != 0 })
        .map(|(_, v)| v * v).sum();
    let even_energy = total_energy - odd_energy;

    let mut ce = [0.0f64; 4];
    let mut cf = [0.0f64; 4];

    for i in 0..4 {
        ce[i] = channel_energy(i, weights);
        cf[i] = if odd_energy > 0.0 { ce[i] / odd_energy } else { 0.0 };
    }

    // The partition identity: (1/φ(8)) · Σ_i E_i = Σ_{gcd(k,8)=1} |v_k|²
    // φ(8) = 4, so (1/4)·Σ E_i should equal odd_energy
    let partition_sum = 0.25 * ce.iter().sum::<f64>();
    let partition_error = if odd_energy > 0.0 {
        (partition_sum - odd_energy).abs() / odd_energy
    } else { 0.0 };

    ChannelBreakdown { n, total_energy, odd_energy, even_energy,
                       channel_energy: ce, channel_fraction: cf,
                       partition_sum, partition_error }
}

