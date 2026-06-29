//! H9: Participation Ratio at Factor Harmonics
//!
//! Tests whether the participation ratio PR(ψ_0) of the ground-state
//! eigenvector deviates from the universal α ≈ 0.47 when the matrix
//! dimension M is a multiple of a factor of N.
//!
//! The physics paper identifies α ≈ 0.47 as the arithmetic-GOE constant.
//! If factors create localization resonances, PR would deviate at M = kp.

use super::GramCache;
use crate::keygen::SemiprimeKey;
use crate::results::*;
use cathedral_utils::spectral;

pub fn h9_participation_ratio_harmonics(keys: &[SemiprimeKey], cache: &GramCache) -> Vec<H9Result> {
    println!("  [H9] Participation Ratio at Factor Harmonics (GPU)");
    println!("  ───────────────────────────────────────────────────");
    let mut results = Vec::new();

    for key in keys.iter().take(5) {
        let p = key.p as usize;

        // Generate probe dimensions: factor harmonics kp and nearby non-harmonics kp±1
        let mut probe_points: Vec<(usize, bool)> = Vec::new(); // (dim, is_harmonic)
        for k in 2..=6 {
            let harmonic = k * p;
            if harmonic > 2500 {
                break;
            }
            // Factor harmonic
            probe_points.push((harmonic, true));
            // Adjacent non-harmonics for comparison
            if harmonic > 3 {
                probe_points.push((harmonic - 1, false));
            }
            if harmonic < 2500 {
                probe_points.push((harmonic + 1, false));
            }
        }

        if probe_points.is_empty() {
            println!("    N={}: no tractable harmonics for p={}", key.n, p);
            continue;
        }

        let mut pr_entries: Vec<ParticipationEntry> = Vec::new();

        for &(m, is_harmonic) in &probe_points {
            let dim = m - 1;
            if dim < 3 {
                continue;
            }
            let ger = match cache.get_eigen(dim) {
                Some(r) => r,
                None => continue,
            };
            let pr = spectral::participation_ratio(&ger.ground_state);
            let alpha = pr * dim as f64; // IPR-normalized

            pr_entries.push(ParticipationEntry {
                dim: m,
                participation_ratio: pr,
                alpha_normalized: alpha,
                is_factor_harmonic: is_harmonic,
                eigen_time_s: ger.eigen_time,
            });
        }

        // Compute mean α at harmonics vs non-harmonics
        let harmonic_alphas: Vec<f64> = pr_entries
            .iter()
            .filter(|e| e.is_factor_harmonic)
            .map(|e| e.alpha_normalized)
            .collect();
        let nonharmonic_alphas: Vec<f64> = pr_entries
            .iter()
            .filter(|e| !e.is_factor_harmonic)
            .map(|e| e.alpha_normalized)
            .collect();

        let mean_harmonic = if harmonic_alphas.is_empty() {
            0.0
        } else {
            harmonic_alphas.iter().sum::<f64>() / harmonic_alphas.len() as f64
        };
        let mean_nonharmonic = if nonharmonic_alphas.is_empty() {
            0.0
        } else {
            nonharmonic_alphas.iter().sum::<f64>() / nonharmonic_alphas.len() as f64
        };
        let alpha_deviation = if mean_nonharmonic > 0.0 {
            (mean_harmonic - mean_nonharmonic).abs() / mean_nonharmonic
        } else {
            0.0
        };

        println!("    N={} = {}×{}", key.n, key.p, key.q);
        for e in &pr_entries {
            println!(
                "      M={:5}: PR={:.6}, α={:.4} {}",
                e.dim,
                e.participation_ratio,
                e.alpha_normalized,
                if e.is_factor_harmonic {
                    "← HARMONIC"
                } else {
                    ""
                }
            );
        }
        println!(
            "      Mean α at harmonics:     {:.4} ({} points)",
            mean_harmonic,
            harmonic_alphas.len()
        );
        println!(
            "      Mean α at non-harmonics: {:.4} ({} points)",
            mean_nonharmonic,
            nonharmonic_alphas.len()
        );
        println!("      Relative deviation: {:.4}", alpha_deviation);
        println!(
            "      Signal: {}\n",
            if alpha_deviation > 0.10 {
                "weak 〜"
            } else {
                "null ∅"
            }
        );

        results.push(H9Result {
            n: key.n,
            p: key.p,
            q: key.q,
            mean_harmonic_alpha: mean_harmonic,
            mean_nonharmonic_alpha: mean_nonharmonic,
            alpha_deviation,
            entries: pr_entries,
        });
    }
    results
}
