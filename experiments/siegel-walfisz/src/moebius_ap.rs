// siegel-walfisz/src/moebius_ap.rs
//
// Möbius sums decomposed by character: Σ μ(k)·χ(k)·ln^j(k)/k
// This is the key connection to our PNT axioms.

use rug::Float;
use crate::characters::chi8;

const PREC: u32 = 512;

/// Compute the character-twisted Möbius sums in 512-bit MPFR:
///   S₁(χ, N) = Σ_{k=1}^{N} μ(k)·χ(k)/k
///   S₂(χ, N) = Σ_{k=1}^{N} μ(k)·χ(k)·ln(k)/k
///
/// For the principal character (i=0), these reduce to:
///   S₁(χ₁, N) = Σ μ(k)/k → 0  (PNT axiom 1, PROVED)
///   S₂(χ₁, N) = Σ μ(k)·ln(k)/k → -1  (PNT axiom 2)
///
/// For non-principal χ:
///   S₁(χ, N) → 0                 (L(1,χ) ≠ 0 → convergent)
///   S₂(χ, N) → -L'(1,χ)/L(1,χ)² (derivative of 1/L at s=1)
///
/// Returns (s1, s2) as f64
pub fn character_moebius_sums(
    chi_idx: usize,
    mu: &[i8],
    n: usize,
) -> (f64, f64) {
    let mut s1 = Float::with_val(PREC, 0.0);
    let mut s2 = Float::with_val(PREC, 0.0);

    for k in 1..=n {
        let mu_k = mu[k] as i64;
        if mu_k == 0 {
            continue;
        }
        let chi_k = chi8(chi_idx, k);
        if chi_k == 0 {
            continue;
        }
        let coeff = mu_k * chi_k;
        let k_f = Float::with_val(PREC, k as f64);
        let ln_k = Float::with_val(PREC, k_f.clone().ln());
        let inv_k = Float::with_val(PREC, 1.0) / &k_f;

        let term1 = Float::with_val(PREC, coeff as f64) * &inv_k;
        let term2 = Float::with_val(PREC, &term1 * &ln_k);

        s1 += &term1;
        s2 += &term2;
    }

    (s1.to_f64(), s2.to_f64())
}

/// Compute the full (untwisted) Möbius sums — our PNT axioms:
///   S₁(N) = Σ μ(k)/k → 0
///   S₂(N) = Σ μ(k)·ln(k)/k → -1
///   S₃(N) = Σ μ(k)·ln²(k)/k → -2γ
///
/// Returns (s1, s2, s3)
pub fn pnt_moebius_sums(mu: &[i8], n: usize) -> (f64, f64, f64) {
    let mut s1 = Float::with_val(PREC, 0.0);
    let mut s2 = Float::with_val(PREC, 0.0);
    let mut s3 = Float::with_val(PREC, 0.0);

    for k in 1..=n {
        let mu_k = mu[k] as i64;
        if mu_k == 0 {
            continue;
        }
        let k_f = Float::with_val(PREC, k as f64);
        let ln_k = Float::with_val(PREC, k_f.clone().ln());
        let ln_k_sq = Float::with_val(PREC, ln_k.clone().square());
        let inv_k = Float::with_val(PREC, 1.0) / &k_f;

        let base = Float::with_val(PREC, mu_k as f64) * &inv_k;
        let t2 = Float::with_val(PREC, &base * &ln_k);
        let t3 = Float::with_val(PREC, &base * &ln_k_sq);

        s1 += &base;
        s2 += &t2;
        s3 += &t3;
    }

    (s1.to_f64(), s2.to_f64(), s3.to_f64())
}

/// Decompose PNT sum S₂ by residue class mod 8:
///   S₂(N; a) = Σ_{k ≡ a (mod 8)} μ(k)·ln(k)/k
///
/// If Siegel-Walfisz holds, S₂(N; a) → -1/4 for each odd a.
/// Returns [S₂(1), S₂(3), S₂(5), S₂(7)] and their sum
pub fn pnt_s2_by_residue(mu: &[i8], n: usize) -> ([f64; 4], f64) {
    let mut sums = [Float::with_val(PREC, 0.0),
                    Float::with_val(PREC, 0.0),
                    Float::with_val(PREC, 0.0),
                    Float::with_val(PREC, 0.0)];

    for k in 1..=n {
        let mu_k = mu[k] as i64;
        if mu_k == 0 || k % 2 == 0 {
            continue;
        }
        let k_f = Float::with_val(PREC, k as f64);
        let ln_k = Float::with_val(PREC, k_f.clone().ln());
        let inv_k = Float::with_val(PREC, 1.0) / &k_f;
        let term = Float::with_val(PREC, mu_k as f64) * &inv_k * &ln_k;

        let idx = match k % 8 {
            1 => 0,
            3 => 1,
            5 => 2,
            7 => 3,
            _ => continue,
        };
        sums[idx] += &term;
    }

    let total = sums.iter().fold(Float::with_val(PREC, 0.0), |acc, x| {
        Float::with_val(PREC, &acc + x)
    });

    (
        [sums[0].to_f64(), sums[1].to_f64(), sums[2].to_f64(), sums[3].to_f64()],
        total.to_f64(),
    )
}
