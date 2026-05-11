// siegel-walfisz/src/moebius_ap.rs
//
// Möbius sums decomposed by character: Σ μ(k)·χ(k)·ln^j(k)/k
// This is the key connection to our PNT axioms.
//
// ALL inner loops are parallelized via rayon chunk decomposition
// for full CPU utilization at large N.
//
// Incremental computation: test points are computed by summing
// over ranges [prev+1..N] and accumulating, so the total work
// is O(max_N) instead of O(num_points × max_N).

use crate::characters::chi8;
use rayon::prelude::*;
use rug::Float;

const PREC: u32 = 512;

/// Minimum chunk size — below this, overhead dominates
const MIN_CHUNK: usize = 50_000;

/// Compute chunk boundaries for parallel decomposition of [lo..hi]
fn chunk_ranges_in(lo: usize, hi: usize) -> Vec<(usize, usize)> {
    if hi < lo {
        return vec![];
    }
    let len = hi - lo + 1;
    let num_threads = rayon::current_num_threads();
    let chunk_size = (len / num_threads).max(MIN_CHUNK);
    let mut ranges = Vec::new();
    let mut start = lo;
    while start <= hi {
        let end = (start + chunk_size - 1).min(hi);
        ranges.push((start, end));
        start = end + 1;
    }
    ranges
}

/// Compute character-twisted Möbius partial sum over range [lo..hi]:
///   Σ_{k=lo}^{hi} μ(k)·χ(k)/k  and  Σ_{k=lo}^{hi} μ(k)·χ(k)·ln(k)/k
///
/// PARALLEL via rayon chunk decomposition.
fn character_moebius_range(chi_idx: usize, mu: &[i8], lo: usize, hi: usize) -> (Float, Float) {
    let ranges = chunk_ranges_in(lo, hi);

    let partial_sums: Vec<(Float, Float)> = ranges
        .par_iter()
        .map(|&(clo, chi)| {
            let mut s1 = Float::with_val(PREC, 0.0);
            let mut s2 = Float::with_val(PREC, 0.0);

            for k in clo..=chi {
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
            (s1, s2)
        })
        .collect();

    let mut total_s1 = Float::with_val(PREC, 0.0);
    let mut total_s2 = Float::with_val(PREC, 0.0);
    for (s1, s2) in partial_sums {
        total_s1 += &s1;
        total_s2 += &s2;
    }
    (total_s1, total_s2)
}

/// Compute character-twisted Möbius sums at a single N.
/// For backward compatibility.
pub fn character_moebius_sums(chi_idx: usize, mu: &[i8], n: usize) -> (f64, f64) {
    let (s1, s2) = character_moebius_range(chi_idx, mu, 1, n);
    (s1.to_f64(), s2.to_f64())
}

/// Compute character-twisted Möbius sums INCREMENTALLY at sorted test points.
///
/// Instead of computing Σ_{1..N₁}, Σ_{1..N₂}, ... independently (total work: Σ Nᵢ),
/// we compute Σ_{1..N₁}, then add Σ_{N₁+1..N₂}, etc. (total work: max(Nᵢ)).
///
/// Returns Vec<(f64, f64)> of (S₁, S₂) at each test point.
pub fn character_moebius_incremental(
    chi_idx: usize,
    mu: &[i8],
    test_points: &[usize],
) -> Vec<(f64, f64)> {
    let mut results = Vec::with_capacity(test_points.len());
    let mut acc_s1 = Float::with_val(PREC, 0.0);
    let mut acc_s2 = Float::with_val(PREC, 0.0);
    let mut prev = 0usize;

    for &n in test_points {
        if n > prev {
            let (ds1, ds2) = character_moebius_range(chi_idx, mu, prev + 1, n);
            acc_s1 += &ds1;
            acc_s2 += &ds2;
        }
        results.push((acc_s1.to_f64(), acc_s2.to_f64()));
        prev = n;
    }
    results
}

/// Compute PNT Möbius partial sum over range [lo..hi]:
///   Σ μ(k)/k,  Σ μ(k)·ln(k)/k,  Σ μ(k)·ln²(k)/k
fn pnt_moebius_range(mu: &[i8], lo: usize, hi: usize) -> (Float, Float, Float) {
    let ranges = chunk_ranges_in(lo, hi);

    let partial_sums: Vec<(Float, Float, Float)> = ranges
        .par_iter()
        .map(|&(clo, chi)| {
            let mut s1 = Float::with_val(PREC, 0.0);
            let mut s2 = Float::with_val(PREC, 0.0);
            let mut s3 = Float::with_val(PREC, 0.0);

            for k in clo..=chi {
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
            (s1, s2, s3)
        })
        .collect();

    let mut total_s1 = Float::with_val(PREC, 0.0);
    let mut total_s2 = Float::with_val(PREC, 0.0);
    let mut total_s3 = Float::with_val(PREC, 0.0);
    for (s1, s2, s3) in partial_sums {
        total_s1 += &s1;
        total_s2 += &s2;
        total_s3 += &s3;
    }
    (total_s1, total_s2, total_s3)
}

/// Compute PNT Möbius sums at a single N (backward compat).
pub fn pnt_moebius_sums(mu: &[i8], n: usize) -> (f64, f64, f64) {
    let (s1, s2, s3) = pnt_moebius_range(mu, 1, n);
    (s1.to_f64(), s2.to_f64(), s3.to_f64())
}

/// Compute PNT Möbius sums INCREMENTALLY at sorted test points.
pub fn pnt_moebius_incremental(mu: &[i8], test_points: &[usize]) -> Vec<(f64, f64, f64)> {
    let mut results = Vec::with_capacity(test_points.len());
    let mut acc_s1 = Float::with_val(PREC, 0.0);
    let mut acc_s2 = Float::with_val(PREC, 0.0);
    let mut acc_s3 = Float::with_val(PREC, 0.0);
    let mut prev = 0usize;

    for &n in test_points {
        if n > prev {
            let (ds1, ds2, ds3) = pnt_moebius_range(mu, prev + 1, n);
            acc_s1 += &ds1;
            acc_s2 += &ds2;
            acc_s3 += &ds3;
        }
        results.push((acc_s1.to_f64(), acc_s2.to_f64(), acc_s3.to_f64()));
        prev = n;
    }
    results
}

/// S₂ residue decomposition partial sum over [lo..hi]
fn s2_residue_range(mu: &[i8], lo: usize, hi: usize) -> [Float; 4] {
    let ranges = chunk_ranges_in(lo, hi);

    let partial_sums: Vec<[Float; 4]> = ranges
        .par_iter()
        .map(|&(clo, chi)| {
            let mut sums = [
                Float::with_val(PREC, 0.0),
                Float::with_val(PREC, 0.0),
                Float::with_val(PREC, 0.0),
                Float::with_val(PREC, 0.0),
            ];

            for k in clo..=chi {
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
            sums
        })
        .collect();

    let mut totals = [
        Float::with_val(PREC, 0.0),
        Float::with_val(PREC, 0.0),
        Float::with_val(PREC, 0.0),
        Float::with_val(PREC, 0.0),
    ];
    for chunk in partial_sums {
        for i in 0..4 {
            totals[i] += &chunk[i];
        }
    }
    totals
}

/// S₂ residue decomposition at a single N (backward compat).
pub fn pnt_s2_by_residue(mu: &[i8], n: usize) -> ([f64; 4], f64) {
    let totals = s2_residue_range(mu, 1, n);
    let total = totals.iter().fold(Float::with_val(PREC, 0.0), |acc, x| {
        Float::with_val(PREC, &acc + x)
    });
    (
        [
            totals[0].to_f64(),
            totals[1].to_f64(),
            totals[2].to_f64(),
            totals[3].to_f64(),
        ],
        total.to_f64(),
    )
}

/// S₂ residue decomposition INCREMENTALLY at sorted test points.
pub fn s2_residue_incremental(mu: &[i8], test_points: &[usize]) -> Vec<([f64; 4], f64)> {
    let mut results = Vec::with_capacity(test_points.len());
    let mut acc = [
        Float::with_val(PREC, 0.0),
        Float::with_val(PREC, 0.0),
        Float::with_val(PREC, 0.0),
        Float::with_val(PREC, 0.0),
    ];
    let mut prev = 0usize;

    for &n in test_points {
        if n > prev {
            let delta = s2_residue_range(mu, prev + 1, n);
            for i in 0..4 {
                acc[i] += &delta[i];
            }
        }
        let total = acc.iter().fold(Float::with_val(PREC, 0.0), |a, x| {
            Float::with_val(PREC, &a + x)
        });
        results.push((
            [
                acc[0].to_f64(),
                acc[1].to_f64(),
                acc[2].to_f64(),
                acc[3].to_f64(),
            ],
            total.to_f64(),
        ));
        prev = n;
    }
    results
}
