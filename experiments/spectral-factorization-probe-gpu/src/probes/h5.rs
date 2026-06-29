//! H5: Composite Anchoring / Factor Shadow
//!
//! Tests whether factor primes show anomalous avoidance
//! in the ground-state eigenvector density ranking.

use super::GramCache;
use crate::keygen::SemiprimeKey;
use crate::results::*;
use cathedral_utils::arith;

pub fn h5_composite_anchoring(keys: &[SemiprimeKey], cache: &GramCache) -> Vec<H5Result> {
    println!("  [H5] Composite Anchoring / Factor Shadow (GPU)");
    println!("  ───────────────────────────────────────────────");
    let mut results = Vec::new();
    for key in keys.iter().take(5) {
        let m = ((key.p as usize) * 3).min(5000).max(50);
        let dim = m - 1;
        let ger = match cache.get_eigen(dim) {
            Some(r) => r,
            None => continue,
        };
        let ground = &ger.ground_state;
        let full_pr = cathedral_utils::spectral::participation_ratio(ground);
        let sieve = arith::sieve_primes(m);
        let mut prime_weights: Vec<(usize, f64, bool)> = Vec::new();
        for d in 2..m {
            if !sieve[d] {
                continue;
            }
            let mult_count = (0..dim).filter(|i| (i + 2) % d == 0).count();
            if mult_count == 0 {
                continue;
            }
            let weight: f64 = (0..dim)
                .filter(|i| (i + 2) % d == 0)
                .map(|i| ground[i] * ground[i])
                .sum();
            prime_weights.push((d, weight / mult_count as f64, key.n % d as u64 == 0));
        }
        prime_weights.sort_by(|a, b| a.1.partial_cmp(&b.1).unwrap());
        println!(
            "    N={} = {}×{}, M={}, PR={:.4} [{:.2}s GPU]",
            key.n,
            key.p,
            key.q,
            m,
            full_pr,
            ger.build_time + ger.eigen_time
        );
        println!("      Prime divisor density ranking (low = avoided):");
        let top_avoided: Vec<PrimeDensityEntry> = prime_weights
            .iter()
            .take(10)
            .enumerate()
            .map(|(i, &(d, density, is_f))| {
                println!(
                    "        #{}: d={:5} density={:.6e} {}",
                    i + 1,
                    d,
                    density,
                    if is_f { "← FACTOR" } else { "" }
                );
                PrimeDensityEntry {
                    prime: d,
                    density,
                    is_factor: is_f,
                }
            })
            .collect();
        let p_rank = prime_weights
            .iter()
            .position(|(d, _, _)| *d == key.p as usize);
        if let Some(rank) = p_rank {
            println!(
                "      Factor p={} rank: {}/{}",
                key.p,
                rank + 1,
                prime_weights.len()
            );
        }
        println!();
        results.push(H5Result {
            n: key.n,
            p: key.p,
            q: key.q,
            m,
            participation_ratio: full_pr,
            build_time_s: ger.build_time,
            eigen_time_s: ger.eigen_time,
            factor_p_rank: p_rank,
            total_primes: prime_weights.len(),
            top_avoided,
        });
    }
    results
}
