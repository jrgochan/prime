//! H2: Optimal Weight Vector
//!
//! Tests whether the Möbius-weighted basis vector concentrates
//! anomalous weight at factor indices of N = p·q.

use crate::keygen::SemiprimeKey;
use crate::results::*;
use cathedral_utils::arith;
use rayon::prelude::*;

pub fn h2_optimal_weight_structure(keys: &[SemiprimeKey]) -> Vec<H2Result> {
    println!("  [H2] Optimal Weight Vector at Factor Indices (parallel)");
    println!("  ────────────────────────────────────────────────────────");
    let raw: Vec<_> = keys
        .par_iter()
        .take(10)
        .filter_map(|key| {
            let m = ((key.p as usize) * 3).min(5000).max(50);
            let mu = arith::mobius_table(m);
            let ln_n = (key.n as f64).ln();
            let mut weights: Vec<(usize, f64)> = (2..m)
                .map(|k| {
                    let mu_k = if k < mu.len() { mu[k] as f64 } else { 0.0 };
                    (k, (-mu_k * (1.0 - (k as f64).ln() / ln_n)).abs())
                })
                .collect();
            weights.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap());
            let p_rank = weights.iter().position(|(k, _)| *k == key.p as usize);
            let q_rank = if (key.q as usize) < m {
                weights.iter().position(|(k, _)| *k == key.q as usize)
            } else {
                None
            };
            let p_weight = weights
                .iter()
                .find(|(k, _)| *k == key.p as usize)
                .map(|(_, w)| *w)
                .unwrap_or(0.0);
            let median_weight = weights
                .get(weights.len() / 2)
                .map(|(_, w)| *w)
                .unwrap_or(1.0);
            let ratio = if median_weight > 0.0 {
                p_weight / median_weight
            } else {
                0.0
            };
            Some(H2Result {
                n: key.n,
                p: key.p,
                q: key.q,
                m,
                p_rank,
                q_rank,
                p_weight,
                median_weight,
                weight_ratio: ratio,
                total_weights: weights.len(),
            })
        })
        .collect();
    for r in &raw {
        println!(
            "    N={}: p={} rank={}/{}, |w_p|={:.6e}, median={:.6e}, ratio={:.2}{}",
            r.n,
            r.p,
            r.p_rank.map(|x| x + 1).unwrap_or(0),
            r.total_weights,
            r.p_weight,
            r.median_weight,
            r.weight_ratio,
            if let Some(qr) = r.q_rank {
                format!(", q={} rank={}", r.q, qr + 1)
            } else {
                String::new()
            }
        );
    }
    println!();
    raw
}
