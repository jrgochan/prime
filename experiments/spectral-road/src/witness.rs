//! Sieve witness constructions for the Nyman-Beurling distance d²_N.
//!
//! Computes d²_N = ||1 - f_N||² = 1 - 2⟨1, f_N⟩ + ⟨f_N, f_N⟩
//!            = 1 - 2 c^T b + c^T G c
//!
//! where c_k are sieve-derived coefficients and G is the Gram matrix.
//!
//! Four witness families:
//! - **Selberg** (D = √N, ℓ=1): classical, hits parity barrier at N~75
//! - **GPY** (D = N^{2/3}, ℓ=2): Goldston-Pintz-Yıldırım, extends further
//! - **Maynard** (D = N^{0.9}, ℓ=3): Maynard-Tao, pushes parity barrier hardest
//! - **Liouville** (D = N^{0.9}, ℓ=3): Uses λ(k)=(-1)^Ω(k) instead of μ(k)
//!     to preserve mass on non-squarefree composites (Gemini's insight)

use crate::arith;
use crate::gram::GramMatrix;

// ═══════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════

/// The type of sieve used to construct trial functions.
#[derive(Debug, Clone, Copy)]
pub enum SieveType {
    /// Classical Selberg sieve: D = N^{1/2}, smooth cutoff order ℓ = 1.
    Selberg,
    /// Goldston-Pintz-Yıldırım: D = N^{2/3}, ℓ = 2.
    GPY,
    /// Maynard-Tao style: D = N^{0.9}, ℓ = 3. Pushes past the parity barrier.
    Maynard,
    /// Liouville-Maynard: like Maynard but uses λ(k)=(-1)^Ω(k) instead of μ(k).
    /// Does NOT zero out non-squarefree composites — preserves vacuum mass.
    Liouville,
}

impl SieveType {
    /// Returns (theta, ell) — the sieve level exponent and cutoff order.
    fn params(&self) -> (f64, u32) {
        match self {
            SieveType::Selberg => (0.5, 1),
            SieveType::GPY => (2.0 / 3.0, 2),
            SieveType::Maynard => (0.9, 3),
            SieveType::Liouville => (0.9, 3),
        }
    }

    pub fn name(&self) -> &'static str {
        match self {
            SieveType::Selberg => "Selberg",
            SieveType::GPY => "GPY",
            SieveType::Maynard => "Maynard",
            SieveType::Liouville => "Liouville",
        }
    }

    /// Whether this sieve uses the Liouville function instead of Möbius.
    fn uses_liouville(&self) -> bool {
        matches!(self, SieveType::Liouville)
    }
}

/// Result of evaluating a sieve witness at a given N.
#[derive(Debug)]
pub struct WitnessResult {
    pub n: usize,
    pub sieve_type: &'static str,
    pub d_level: usize,
    pub ell: u32,
    pub d2_n: f64,
    pub f_norm_sq: f64,
    pub one_f_inner: f64,
}

// ═══════════════════════════════════════════════════════════════
// LIOUVILLE FUNCTION
// ═══════════════════════════════════════════════════════════════

/// Compute λ(n) = (-1)^Ω(n) for n = 0..=max_n.
///
/// Ω(n) = total number of prime factors with multiplicity.
/// Unlike μ(n), λ(n) is never zero — it preserves mass on all integers.
fn liouville_table(max_n: usize) -> Vec<i8> {
    let mut omega = vec![0u32; max_n + 1];
    // Sieve to count prime factors with multiplicity
    for p in 2..=max_n {
        // Check if p is prime (omega[p] == 0 means not yet touched by a smaller prime)
        if omega[p] != 0 {
            continue; // not prime
        }
        // p is prime: add 1 to omega for each multiple of p, 2 for p², etc.
        let mut pk = p;
        while pk <= max_n {
            for m in (pk..=max_n).step_by(pk) {
                omega[m] += 1;
            }
            // prevent overflow for large p
            if pk > max_n / p {
                break;
            }
            pk *= p;
        }
    }

    (0..=max_n)
        .map(|n| if omega[n] % 2 == 0 { 1i8 } else { -1i8 })
        .collect()
}

// ═══════════════════════════════════════════════════════════════
// COEFFICIENT CONSTRUCTION
// ═══════════════════════════════════════════════════════════════

/// Compute sieve coefficients c_k for k = 2, ..., N.
///
/// c_k = (1/k) · Σ_{d | k, d ≤ D} w_d · F(ln(d)/ln(D))
///
/// where w_d = μ(d) for Selberg/GPY/Maynard, w_d = λ(d) for Liouville,
/// and F(x) = max(0, 1-x)^ℓ is the smooth cutoff.
pub fn sieve_coefficients(n: usize, sieve: SieveType) -> Vec<f64> {
    let dim = n - 1;
    let (theta, ell) = sieve.params();
    let d_max = (n as f64).powf(theta) as usize;
    let log_d = (d_max.max(2) as f64).ln();

    // Choose the arithmetic weight function
    let mu = arith::mobius_table(d_max + 1);
    let liou = if sieve.uses_liouville() {
        Some(liouville_table(d_max + 1))
    } else {
        None
    };

    (0..dim)
        .map(|i| {
            let k = i + 2;
            let mut s = 0.0f64;
            for d in 1..=d_max.min(k) {
                if k % d != 0 || d >= mu.len() {
                    continue;
                }

                let weight = if let Some(ref lv) = liou {
                    lv[d] as f64
                } else {
                    if mu[d] == 0 {
                        continue;
                    }
                    mu[d] as f64
                };

                let log_ratio = (d as f64).ln() / log_d;
                let cutoff = (1.0 - log_ratio).max(0.0);
                let lambda_d = weight * cutoff.powi(ell as i32);
                s += lambda_d;
            }
            s / k as f64
        })
        .collect()
}

// ═══════════════════════════════════════════════════════════════
// DISTANCE COMPUTATION
// ═══════════════════════════════════════════════════════════════

/// Evaluate d²_N for a given set of coefficients using the full Gram matrix.
///
/// d²_N = 1 - 2 c^T b + c^T G c
pub fn witness_distance(gram: &GramMatrix, n: usize, coeffs: &[f64]) -> WitnessResult {
    let (sub, dim) = gram.extract_submatrix(n);
    let b = arith::b_vector(dim);

    // c^T G c — the quadratic form (full matrix, not diagonal)
    let mut f_norm_sq = 0.0f64;
    for i in 0..dim {
        for j in 0..dim {
            f_norm_sq += coeffs[i] * sub[i * dim + j] * coeffs[j];
        }
    }

    // c^T b — the linear term
    let one_f_inner: f64 = coeffs.iter().zip(b.iter()).map(|(c, b)| c * b).sum();

    let d2_n = 1.0 - 2.0 * one_f_inner + f_norm_sq;

    WitnessResult {
        n,
        sieve_type: "",
        d_level: 0,
        ell: 0,
        d2_n,
        f_norm_sq,
        one_f_inner,
    }
}

/// Compare all four sieve witnesses at a given N.
pub fn compare_witnesses(gram: &GramMatrix, n: usize) -> Vec<WitnessResult> {
    [
        SieveType::Selberg,
        SieveType::GPY,
        SieveType::Maynard,
        SieveType::Liouville,
    ]
    .iter()
    .map(|&sieve| {
        let (theta, ell) = sieve.params();
        let d_level = (n as f64).powf(theta) as usize;
        let coeffs = sieve_coefficients(n, sieve);
        let mut result = witness_distance(gram, n, &coeffs);
        result.sieve_type = sieve.name();
        result.d_level = d_level;
        result.ell = ell;
        result
    })
    .collect()
}



