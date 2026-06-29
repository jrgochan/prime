//! H7: Condition Number Fingerprint
//!
//! Tests whether κ(G_M) shows anomalous structure at M ~ p or M ~ q
//! for a semiprime N = p·q, compared to non-factor positions.
//!
//! The condition number κ = λ_max / λ_min is governed by the Marchenko-Pastur
//! distribution with arithmetic corrections. If factors create a κ-resonance,
//! it would be detectable as a discontinuity at M values related to p or q.

use super::GramCache;
use crate::keygen::SemiprimeKey;
use crate::results::*;

/// Window radius around each probe point for eigenvalue computation.
const WINDOW_RADIUS: usize = 3;

pub fn h7_condition_number_fingerprint(keys: &[SemiprimeKey], cache: &GramCache) -> Vec<H7Result> {
    println!("  [H7] Condition Number Fingerprint (GPU)");
    println!("  ────────────────────────────────────────");
    let mut results = Vec::new();

    for key in keys.iter().take(5) {
        // We probe κ(G_M) at M near the smaller factor p
        // and compare to κ at nearby non-factor dimensions.
        let p = key.p as usize;

        // Skip if p is too large for tractable eigendecomp
        if p > 2000 {
            println!("    N={}: p={} too large for κ probe, skipping", key.n, p);
            continue;
        }

        // Clamp probe range to [max(10, p-WINDOW), p+WINDOW]
        let lo = p.saturating_sub(WINDOW_RADIUS).max(10);
        let hi = (p + WINDOW_RADIUS).min(3000);

        let mut kappa_at_factor: Option<f64> = None;
        let mut kappa_values: Vec<ConditionEntry> = Vec::new();

        for m in lo..=hi {
            let dim = m - 1;
            let ger = match cache.get_eigen(dim) {
                Some(r) => r,
                None => continue,
            };
            let evals = &ger.eigenvalues;
            if evals.is_empty() {
                continue;
            }

            // λ_min is the first (cuSOLVER sorts ascending)
            let lambda_min = evals[0].abs().max(1e-300);
            let lambda_max = evals[evals.len() - 1].abs().max(1e-300);
            let kappa = lambda_max / lambda_min;
            let is_factor_dim = key.n % m as u64 == 0;

            if m == p {
                kappa_at_factor = Some(kappa);
            }

            kappa_values.push(ConditionEntry {
                dim: m,
                kappa,
                lambda_min: evals[0],
                lambda_max: evals[evals.len() - 1],
                is_factor_dim,
            });
        }

        // Compute statistics: mean κ at non-factor dims vs factor dims
        let non_factor_kappas: Vec<f64> = kappa_values
            .iter()
            .filter(|e| !e.is_factor_dim)
            .map(|e| e.kappa)
            .collect();
        let factor_kappas: Vec<f64> = kappa_values
            .iter()
            .filter(|e| e.is_factor_dim)
            .map(|e| e.kappa)
            .collect();

        let mean_nf = if non_factor_kappas.is_empty() {
            0.0
        } else {
            non_factor_kappas.iter().sum::<f64>() / non_factor_kappas.len() as f64
        };
        let mean_f = if factor_kappas.is_empty() {
            0.0
        } else {
            factor_kappas.iter().sum::<f64>() / factor_kappas.len() as f64
        };
        let kappa_ratio = if mean_nf > 0.0 { mean_f / mean_nf } else { 1.0 };

        println!("    N={} = {}×{}", key.n, key.p, key.q);
        println!("      Probed κ(G_M) for M in [{}, {}]", lo, hi);
        for e in &kappa_values {
            println!(
                "        M={:5}: κ={:.4e}  λ_min={:.4e}  λ_max={:.4e} {}",
                e.dim,
                e.kappa,
                e.lambda_min,
                e.lambda_max,
                if e.is_factor_dim {
                    "← FACTOR DIM"
                } else {
                    ""
                }
            );
        }
        println!(
            "      κ at factor dims: mean={:.4e} ({} dims)",
            mean_f,
            factor_kappas.len()
        );
        println!(
            "      κ at non-factor:  mean={:.4e} ({} dims)",
            mean_nf,
            non_factor_kappas.len()
        );
        println!("      Factor/non-factor κ ratio: {:.4}", kappa_ratio);
        println!(
            "      Signal: {}\n",
            if (kappa_ratio - 1.0).abs() > 0.5 {
                "weak 〜"
            } else {
                "null ∅"
            }
        );

        results.push(H7Result {
            n: key.n,
            p: key.p,
            q: key.q,
            probe_lo: lo,
            probe_hi: hi,
            kappa_at_factor_p: kappa_at_factor,
            mean_factor_kappa: mean_f,
            mean_nonfactor_kappa: mean_nf,
            kappa_ratio,
            entries: kappa_values,
        });
    }
    results
}
