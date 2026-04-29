//! ═══════════════════════════════════════════════════════════════════════════
//!  DIRICHLET CHARACTERS MOD 8 — The Stained Glass Rotors
//!
//!  Validates: GallagherPartition.lean `χ₈_orthogonality`, `discrete_energy_partition`
//!  Physics:   4 orthogonal syndrome channels partitioning prime spectral energy
//! ═══════════════════════════════════════════════════════════════════════════

/// The 4 Dirichlet characters mod 8.
///   k mod 8:  0  1  2  3  4  5  6  7
///   χ₀:       0  1  0  1  0  1  0  1   (principal)
///   χ₁:       0  1  0  1  0 -1  0 -1
///   χ₂:       0  1  0 -1  0  1  0 -1
///   χ₃:       0  1  0 -1  0 -1  0  1
pub const CHI_TABLE: [[i8; 8]; 4] = [
    [0, 1, 0, 1, 0, 1, 0, 1],
    [0, 1, 0, 1, 0, -1, 0, -1],
    [0, 1, 0, -1, 0, 1, 0, -1],
    [0, 1, 0, -1, 0, -1, 0, 1],
];

pub const CHI_NAMES: [&str; 4] = ["χ₀ (principal)", "χ₁", "χ₂", "χ₃"];

/// Channel display names for output
pub const CHANNEL_NAMES: [&str; 6] = [
    "Full G_N",
    "χ₀ (principal)",
    "χ₁",
    "χ₂",
    "χ₃",
    "Dark (even)",
];

#[inline]
pub fn chi(chi_idx: usize, k: usize) -> i8 {
    CHI_TABLE[chi_idx][k % 8]
}

/// Verify orthogonality: Σ_{k=0..7} χ_i(k)·χ_j(k) = 0 for i≠j, = φ(8)=4 for i=j
/// Returns Vec of (i, j, sum, expected, ok)
pub fn verify_orthogonality() -> Vec<(usize, usize, i32, i32, bool)> {
    let mut results = Vec::new();
    for i in 0..4 {
        for j in 0..4 {
            let sum: i32 = (0..8)
                .map(|k| CHI_TABLE[i][k] as i32 * CHI_TABLE[j][k] as i32)
                .sum();
            let expected = if i == j { 4 } else { 0 };
            results.push((i, j, sum, expected, sum == expected));
        }
    }
    results
}

/// Get the Gram matrix indices (values of k in 2..=n) where χ_i(k) ≠ 0.
/// These form the rows/columns of the character-projected sub-matrix.
///
/// NOTE: All 4 characters mod 8 have the same support (odd integers),
/// so channel_indices returns the same set for all chi_idx.
/// The character WEIGHTING G_χ(j,k) = χ(j)·G(j,k)·χ(k) is a similarity
/// transform D·G·D where D = diag(χ), and since D² = I, this preserves
/// eigenvalues. The channels are spectrally identical.
pub fn channel_indices(n: usize, chi_idx: usize) -> Vec<usize> {
    (2..=n).filter(|&k| chi(chi_idx, k) != 0).collect()
}

/// Get indices where k is odd (the "light sector" visible to all characters).
pub fn odd_indices(n: usize) -> Vec<usize> {
    (2..=n).filter(|k| k % 2 == 1).collect()
}

/// Get indices where k is even (the "dark sector" invisible to all characters).
pub fn even_indices(n: usize) -> Vec<usize> {
    (2..=n).filter(|k| k % 2 == 0).collect()
}

// ═══════════════════════════════════════════════
// RESIDUE CLASS DECOMPOSITION MOD 8
// ═══════════════════════════════════════════════
// Unlike character projections (which are spectrally trivial),
// residue class partitions select DIFFERENT sub-matrices of G_N,
// creating genuinely distinct spectral structures.

pub const RESIDUE_CLASSES: [usize; 4] = [1, 3, 5, 7];
pub const RESIDUE_NAMES: [&str; 4] = ["k≡1(8)", "k≡3(8)", "k≡5(8)", "k≡7(8)"];

/// Get indices where k ≡ r (mod 8). These are genuinely different sub-matrices.
pub fn residue_indices(n: usize, r: usize) -> Vec<usize> {
    (2..=n).filter(|&k| k % 8 == r).collect()
}
