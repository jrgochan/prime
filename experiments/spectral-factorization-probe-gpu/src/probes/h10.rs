//! H10: Dark Sector Crossover Timing
//!
//! Tests whether the Kosterlitz-Thouless crossover from Poisson to GOE
//! statistics in the even sublattice shifts when restricted to factor
//! multiples of the target semiprime.
//!
//! The physics paper (§5.3) identifies a universal crossover at N_c(m) ≈ 60·m/φ(m).
//! If factor structure modifies this crossover, it encodes factor information.

use super::GramCache;
use crate::keygen::SemiprimeKey;
use crate::results::*;

/// Compute nearest-neighbor spacing ratio r = min(s_i, s_{i+1}) / max(s_i, s_{i+1}).
/// For GOE: mean r ≈ 0.5307; for Poisson: mean r ≈ 0.3863.
fn mean_spacing_ratio(eigenvalues: &[f64]) -> f64 {
    if eigenvalues.len() < 3 {
        return 0.0;
    }
    let mut spacings: Vec<f64> = Vec::new();
    for i in 1..eigenvalues.len() {
        let s = eigenvalues[i] - eigenvalues[i - 1];
        if s > 0.0 {
            spacings.push(s);
        }
    }
    if spacings.len() < 2 {
        return 0.0;
    }

    let mut ratios = Vec::new();
    for i in 0..spacings.len() - 1 {
        let (a, b) = (spacings[i], spacings[i + 1]);
        if a > 0.0 && b > 0.0 {
            ratios.push(a.min(b) / a.max(b));
        }
    }
    if ratios.is_empty() {
        return 0.0;
    }
    ratios.iter().sum::<f64>() / ratios.len() as f64
}

/// GOE fraction: 0.0 = pure Poisson, 1.0 = pure GOE
fn goe_fraction(mean_r: f64) -> f64 {
    const R_POISSON: f64 = 0.3863;
    const R_GOE: f64 = 0.5307;
    ((mean_r - R_POISSON) / (R_GOE - R_POISSON)).clamp(0.0, 1.0)
}

pub fn h10_dark_sector_crossover(keys: &[SemiprimeKey], cache: &GramCache) -> Vec<H10Result> {
    println!("  [H10] Dark Sector Crossover Timing (GPU)");
    println!("  ─────────────────────────────────────────");
    let mut results = Vec::new();

    for key in keys.iter().take(3) {
        let p = key.p as usize;
        if p > 500 {
            println!(
                "    N={}: p={} too large for crossover scan, skipping",
                key.n, p
            );
            continue;
        }

        // Scan across increasing M to find the Poisson→GOE crossover
        let probe_dims: Vec<usize> = vec![50, 80, 120, 160, 200, 300, 400, 600, 800, 1000]
            .into_iter()
            .filter(|&d| d <= 2000)
            .collect();

        let mut full_entries: Vec<CrossoverEntry> = Vec::new();
        let mut restricted_entries: Vec<CrossoverEntry> = Vec::new();

        for &m in &probe_dims {
            let dim = m - 1;
            let ger = match cache.get_eigen(dim) {
                Some(r) => r,
                None => continue,
            };

            // Full spectrum spacing ratio
            let mean_r_full = mean_spacing_ratio(&ger.eigenvalues);
            let goe_full = goe_fraction(mean_r_full);

            full_entries.push(CrossoverEntry {
                dim: m,
                mean_spacing_ratio: mean_r_full,
                goe_fraction: goe_full,
            });

            // Restricted to even sublattice (multiples of 2)
            // and then to factor-p sublattice (multiples of p)
            // For the restricted test: extract eigenvalues of the p-sublattice submatrix
            // We use the full eigenvalues filtered by index pattern as a proxy
            // (True sublattice eigen requires submatrix extraction, done below)
            let p_indices: Vec<usize> = (0..dim).filter(|i| (i + 2) % p == 0).collect();
            if p_indices.len() >= 5 {
                // Extract p-sublattice submatrix
                let sub_dim = p_indices.len();
                let gram_arc = cache.get_gram(dim);
                let gram = &*gram_arc;
                let mut sub_mat = vec![0.0f64; sub_dim * sub_dim];
                for (si, &i) in p_indices.iter().enumerate() {
                    for (sj, &j) in p_indices.iter().enumerate() {
                        sub_mat[si * sub_dim + sj] = gram[i * dim + j];
                    }
                }
                // CPU eigen for small sublattice
                let sub_eig = cathedral_utils::spectral::full_eigen(&sub_mat, sub_dim);
                let mean_r_sub = mean_spacing_ratio(&sub_eig.0);
                let goe_sub = goe_fraction(mean_r_sub);

                restricted_entries.push(CrossoverEntry {
                    dim: m,
                    mean_spacing_ratio: mean_r_sub,
                    goe_fraction: goe_sub,
                });
            }
        }

        // Find crossover point (GOE fraction crosses 0.5)
        let full_crossover = full_entries
            .iter()
            .position(|e| e.goe_fraction >= 0.5)
            .map(|i| full_entries[i].dim);
        let restricted_crossover = restricted_entries
            .iter()
            .position(|e| e.goe_fraction >= 0.5)
            .map(|i| restricted_entries[i].dim);

        let crossover_shift = match (full_crossover, restricted_crossover) {
            (Some(fc), Some(rc)) => Some(rc as f64 / fc as f64),
            _ => None,
        };

        println!("    N={} = {}×{}", key.n, key.p, key.q);
        println!("      Full spectrum crossover:");
        for e in &full_entries {
            println!(
                "        M={:5}: <r>={:.4}, GOE%={:.1}%{}",
                e.dim,
                e.mean_spacing_ratio,
                e.goe_fraction * 100.0,
                if (e.goe_fraction - 0.5).abs() < 0.1 {
                    " ← CROSSOVER"
                } else {
                    ""
                }
            );
        }
        println!("      Factor-p sublattice crossover:");
        for e in &restricted_entries {
            println!(
                "        M={:5}: <r>={:.4}, GOE%={:.1}%{}",
                e.dim,
                e.mean_spacing_ratio,
                e.goe_fraction * 100.0,
                if (e.goe_fraction - 0.5).abs() < 0.1 {
                    " ← CROSSOVER"
                } else {
                    ""
                }
            );
        }
        if let Some(shift) = crossover_shift {
            println!("      Crossover shift ratio: {:.3}", shift);
        } else {
            println!("      Crossover shift: indeterminate (insufficient data)");
        }
        println!(
            "      Signal: {}\n",
            crossover_shift
                .map(|s| if (s - 1.0).abs() > 0.3 {
                    "weak 〜"
                } else {
                    "null ∅"
                })
                .unwrap_or("null ∅")
        );

        results.push(H10Result {
            n: key.n,
            p: key.p,
            q: key.q,
            full_crossover_dim: full_crossover,
            restricted_crossover_dim: restricted_crossover,
            crossover_shift,
            full_entries,
            restricted_entries,
        });
    }
    results
}
