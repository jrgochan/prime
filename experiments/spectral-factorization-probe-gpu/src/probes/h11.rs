//! H11: Sherman-Morrison Factor Sensitivity
//!
//! Tests whether the Sherman-Morrison formula d² = 1 - bᵀG⁻¹b shows
//! anomalous numerical sensitivity to perturbations at factor-indexed
//! positions of the b vector.
//!
//! If factor positions are "pressure points," small ε-perturbations
//! there would produce disproportionate |Δd²| compared to random positions.

use super::GramCache;
use crate::keygen::SemiprimeKey;
use crate::results::*;
use cathedral_utils::arith;

/// Perturbation magnitude for sensitivity analysis.
const EPSILON: f64 = 1e-6;

pub fn h11_sherman_morrison_sensitivity(keys: &[SemiprimeKey], cache: &GramCache) -> Vec<H11Result> {
    println!("  [H11] Sherman-Morrison Factor Sensitivity (GPU)");
    println!("  ────────────────────────────────────────────────");
    let mut results = Vec::new();

    for key in keys.iter().take(5) {
        let m = ((key.p as usize) * 3).min(3000).max(50);
        let dim = m - 1;

        let mu = arith::mobius_table(m);
        let v = cathedral_utils::mertens::witness_vector(m, &mu);
        let b = arith::b_vector(dim);
        let gram_arc = cache.get_gram(dim);
        let gram = &*gram_arc;

        // Compute baseline d²
        let d2_base = cathedral_utils::mertens::quadratic_form(gram, &b, &v, dim);

        // Perturb b at various positions and measure Δd²
        let mut sensitivity_entries: Vec<SensitivityEntry> = Vec::new();
        let sieve = arith::sieve_primes(m.min(2000));
        let test_primes: Vec<usize> = (2..m.min(2000)).filter(|&d| sieve[d]).collect();

        for &p_test in test_primes.iter().take(100) {
            let idx = p_test - 2; // b is indexed from k=2
            if idx >= dim { continue; }

            // Perturb b[idx] by ε
            let mut b_perturbed = b.clone();
            b_perturbed[idx] += EPSILON;

            let d2_perturbed = cathedral_utils::mertens::quadratic_form(gram, &b_perturbed, &v, dim);
            let delta_d2 = (d2_perturbed - d2_base).abs();
            let is_factor = key.n % p_test as u64 == 0;

            sensitivity_entries.push(SensitivityEntry {
                prime: p_test,
                delta_d2,
                sensitivity: delta_d2 / EPSILON, // normalized sensitivity
                is_factor,
            });
        }

        // Sort by sensitivity (descending)
        sensitivity_entries.sort_by(|a, b| b.sensitivity.partial_cmp(&a.sensitivity).unwrap());

        // Find factor rank
        let factor_rank = sensitivity_entries.iter()
            .position(|e| e.prime == key.p as usize);

        // Compute statistics
        let factor_sensitivities: Vec<f64> = sensitivity_entries.iter()
            .filter(|e| e.is_factor)
            .map(|e| e.sensitivity)
            .collect();
        let nonfactor_sensitivities: Vec<f64> = sensitivity_entries.iter()
            .filter(|e| !e.is_factor)
            .map(|e| e.sensitivity)
            .collect();

        let mean_factor = if factor_sensitivities.is_empty() { 0.0 }
            else { factor_sensitivities.iter().sum::<f64>() / factor_sensitivities.len() as f64 };
        let mean_nonfactor = if nonfactor_sensitivities.is_empty() { 0.0 }
            else { nonfactor_sensitivities.iter().sum::<f64>() / nonfactor_sensitivities.len() as f64 };
        let sensitivity_ratio = if mean_nonfactor > 0.0 { mean_factor / mean_nonfactor } else { 1.0 };

        println!("    N={} = {}×{}, M={}, d²_base={:.8}", key.n, key.p, key.q, m, d2_base);
        println!("      Top-10 most sensitive positions (ε={:.0e}):", EPSILON);
        for (i, e) in sensitivity_entries.iter().take(10).enumerate() {
            println!("        #{}: p={:5} |Δd²/ε|={:.6e} {}",
                i + 1, e.prime, e.sensitivity,
                if e.is_factor { "← FACTOR" } else { "" });
        }
        if let Some(rank) = factor_rank {
            println!("      Factor p={} sensitivity rank: {}/{}", key.p, rank + 1, sensitivity_entries.len());
        }
        println!("      Mean factor sensitivity:     {:.6e}", mean_factor);
        println!("      Mean non-factor sensitivity: {:.6e}", mean_nonfactor);
        println!("      Sensitivity ratio: {:.4}", sensitivity_ratio);
        println!("      Signal: {}\n",
            if sensitivity_ratio > 2.0 { "STRONG ⚡" }
            else if sensitivity_ratio > 1.3 { "weak 〜" }
            else { "null ∅" });

        results.push(H11Result {
            n: key.n,
            p: key.p,
            q: key.q,
            dim: m,
            epsilon: EPSILON,
            d2_base,
            factor_p_rank: factor_rank,
            total_probes: sensitivity_entries.len(),
            mean_factor_sensitivity: mean_factor,
            mean_nonfactor_sensitivity: mean_nonfactor,
            sensitivity_ratio,
            top_entries: sensitivity_entries.into_iter().take(10).collect(),
        });
    }
    results
}
