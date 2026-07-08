//! H1: GCD-Stratum Eigenvector Correlation
//!
//! Tests whether the ground-state eigenvector of G_M concentrates
//! weight on indices that share factors with N = p·q.

use super::{next_non_factor_prime, GramCache};
use crate::keygen::SemiprimeKey;
use crate::results::*;

pub fn h1_gcd_stratum_eigenvector(keys: &[SemiprimeKey], cache: &GramCache) -> Vec<H1Result> {
    println!("  [H1] GCD-Stratum Eigenvector Correlation (GPU)");
    println!("  ───────────────────────────────────────────────");
    let mut results = Vec::new();
    let mut factor_pr_sum = 0.0;
    let mut random_pr_sum = 0.0;
    let mut count = 0usize;

    for key in keys.iter().take(10) {
        let m = ((key.n as f64).sqrt() as usize).min(2000).max(50);
        let dim = m - 1;
        let ger = match cache.get_eigen(dim) {
            Some(r) => r,
            None => continue,
        };
        let ground = &ger.ground_state;

        let p_weight: f64 = (0..dim)
            .filter(|i| (i + 2) % key.p as usize == 0)
            .map(|i| ground[i] * ground[i])
            .sum();
        let rand_p = next_non_factor_prime(key.p, key.n);
        let rand_weight: f64 = (0..dim)
            .filter(|i| (i + 2) % rand_p as usize == 0)
            .map(|i| ground[i] * ground[i])
            .sum();

        let p_count = (0..dim).filter(|i| (i + 2) % key.p as usize == 0).count();
        let r_count = (0..dim).filter(|i| (i + 2) % rand_p as usize == 0).count();
        let p_density = if p_count > 0 {
            p_weight / p_count as f64
        } else {
            0.0
        };
        let r_density = if r_count > 0 {
            rand_weight / r_count as f64
        } else {
            0.0
        };
        let ratio = if r_density > 0.0 {
            p_density / r_density
        } else {
            f64::INFINITY
        };

        println!(
            "    N={}: p={} density={:.6e}, p'={} density={:.6e}, ratio={:.3} [M={}, {:.2}s]",
            key.n,
            key.p,
            p_density,
            rand_p,
            r_density,
            ratio,
            m,
            ger.build_time + ger.eigen_time
        );

        results.push(H1Result {
            n: key.n,
            p: key.p,
            q: key.q,
            dim,
            lambda_min: ger.eigenvalues[0],
            factor_density: p_density,
            nonfactor_density: r_density,
            density_ratio: ratio,
            build_time_s: ger.build_time,
            eigen_time_s: ger.eigen_time,
        });
        factor_pr_sum += p_density;
        random_pr_sum += r_density;
        count += 1;
    }
    if count > 0 && random_pr_sum > 0.0 {
        let avg_ratio = (factor_pr_sum / count as f64) / (random_pr_sum / count as f64);
        println!(
            "    ▸ Average factor/non-factor density ratio: {:.4}",
            avg_ratio
        );
        println!(
            "    ▸ Signal: {}\n",
            if avg_ratio > 1.5 {
                "STRONG ⚡"
            } else if avg_ratio > 1.1 {
                "weak 〜"
            } else {
                "null ∅"
            }
        );
    } else {
        println!("    ▸ Insufficient data\n");
    }
    results
}
