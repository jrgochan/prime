//! H8: Eigenvalue Interlacing Anomaly
//!
//! Tests whether the Cauchy interlacing inequality
//!   λ_min(G_{N+1}) ≤ λ_min(G_N)
//! shows anomalous "stuttering" when M crosses a factor of the target semiprime.
//!
//! The interlacing property is universal (Cauchy) and should not encode
//! specific divisibility information. If it does, factors would be
//! detectable via Δλ_min anomalies.

use super::GramCache;
use crate::keygen::SemiprimeKey;
use crate::results::*;

/// Number of steps on each side of the factor to sample.
const SCAN_RADIUS: usize = 5;

pub fn h8_eigenvalue_interlacing(keys: &[SemiprimeKey], cache: &GramCache) -> Vec<H8Result> {
    println!("  [H8] Eigenvalue Interlacing Anomaly (GPU)");
    println!("  ──────────────────────────────────────────");
    let mut results = Vec::new();

    for key in keys.iter().take(5) {
        let p = key.p as usize;

        if p > 2000 {
            println!(
                "    N={}: p={} too large for interlacing scan, skipping",
                key.n, p
            );
            continue;
        }

        let lo = p.saturating_sub(SCAN_RADIUS).max(4);
        let hi = (p + SCAN_RADIUS).min(3000);

        // Collect λ_min at each dimension M in [lo, hi]
        let mut lambda_mins: Vec<(usize, f64)> = Vec::new();
        for m in lo..=hi {
            let dim = m - 1;
            let ger = match cache.get_eigen(dim) {
                Some(r) => r,
                None => continue,
            };
            if !ger.eigenvalues.is_empty() {
                lambda_mins.push((m, ger.eigenvalues[0]));
            }
        }

        // Compute step-to-step deltas
        let mut interlacing_entries: Vec<InterlacingEntry> = Vec::new();
        for i in 1..lambda_mins.len() {
            let (m_prev, lm_prev) = lambda_mins[i - 1];
            let (m_curr, lm_curr) = lambda_mins[i];
            let delta = lm_curr - lm_prev;
            let is_factor_crossing = key.n % m_curr as u64 == 0;

            interlacing_entries.push(InterlacingEntry {
                m_from: m_prev,
                m_to: m_curr,
                lambda_min_from: lm_prev,
                lambda_min_to: lm_curr,
                delta_lambda: delta,
                is_factor_crossing,
            });
        }

        // Compare Δλ at factor crossings vs non-factor crossings
        let factor_deltas: Vec<f64> = interlacing_entries
            .iter()
            .filter(|e| e.is_factor_crossing)
            .map(|e| e.delta_lambda.abs())
            .collect();
        let nonfactor_deltas: Vec<f64> = interlacing_entries
            .iter()
            .filter(|e| !e.is_factor_crossing)
            .map(|e| e.delta_lambda.abs())
            .collect();

        let mean_factor_delta = if factor_deltas.is_empty() {
            0.0
        } else {
            factor_deltas.iter().sum::<f64>() / factor_deltas.len() as f64
        };
        let mean_nonfactor_delta = if nonfactor_deltas.is_empty() {
            0.0
        } else {
            nonfactor_deltas.iter().sum::<f64>() / nonfactor_deltas.len() as f64
        };
        let stutter_ratio = if mean_nonfactor_delta > 0.0 {
            mean_factor_delta / mean_nonfactor_delta
        } else {
            1.0
        };

        println!("    N={} = {}×{}", key.n, key.p, key.q);
        println!("      Interlacing scan M ∈ [{}, {}]:", lo, hi);
        for e in &interlacing_entries {
            println!(
                "        M={:4}→{:4}: Δλ_min={:+.6e} {}",
                e.m_from,
                e.m_to,
                e.delta_lambda,
                if e.is_factor_crossing {
                    "← FACTOR CROSSING"
                } else {
                    ""
                }
            );
        }
        println!(
            "      Mean |Δλ| at factor crossings: {:.4e}",
            mean_factor_delta
        );
        println!(
            "      Mean |Δλ| at non-factor:       {:.4e}",
            mean_nonfactor_delta
        );
        println!("      Stutter ratio: {:.4}", stutter_ratio);
        println!(
            "      Signal: {}\n",
            if (stutter_ratio - 1.0).abs() > 1.0 {
                "weak 〜"
            } else {
                "null ∅"
            }
        );

        results.push(H8Result {
            n: key.n,
            p: key.p,
            q: key.q,
            scan_lo: lo,
            scan_hi: hi,
            mean_factor_delta,
            mean_nonfactor_delta,
            stutter_ratio,
            entries: interlacing_entries,
        });
    }
    results
}
