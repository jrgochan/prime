//! H6: Quadratic Form Restriction Probe
//!
//! Tests whether masking factor-prime multiples from the witness
//! vector produces an anomalously large perturbation in d².

use super::GramCache;
use crate::keygen::SemiprimeKey;
use crate::results::*;
use cathedral_utils::arith;
use rayon::prelude::*;

pub fn h6_quadratic_form_probe(keys: &[SemiprimeKey], cache: &GramCache) -> Vec<H6Result> {
    println!("  [H6] Quadratic Form Restriction Probe (GPU)");
    println!("  ────────────────────────────────────────────");
    let mut results = Vec::new();
    for key in keys.iter().take(5) {
        let m = ((key.p as usize) * 3).min(5000).max(50);
        let dim = m - 1;
        let mu = arith::mobius_table(m);
        let v = cathedral_utils::mertens::witness_vector(m, &mu);
        let b = arith::b_vector(dim);
        let gram_mat = cache.get_gram(dim);
        let d2_full = cathedral_utils::mertens::quadratic_form(&gram_mat, &b, &v, dim);
        let sieve = arith::sieve_primes(m.min(2000));
        let primes: Vec<usize> = (2..m.min(2000)).filter(|&d| sieve[d]).collect();
        let raw: Vec<(usize, f64, f64, bool)> = primes
            .par_iter()
            .map(|&d| {
                let mut v_m = v.clone();
                for i in 0..dim {
                    if (i + 2) % d == 0 {
                        v_m[i] = 0.0;
                    }
                }
                let d2_m = cathedral_utils::mertens::quadratic_form(&gram_mat, &b, &v_m, dim);
                (d, d2_m, (d2_m - d2_full).abs(), key.n % d as u64 == 0)
            })
            .collect();
        let mut sorted = raw;
        sorted.sort_by(|a, b| b.2.partial_cmp(&a.2).unwrap());

        println!(
            "    N={} = {}×{}, d²_full = {:.8}",
            key.n, key.p, key.q, d2_full
        );
        println!("      Top-10 primes by |Δd²| when their multiples are masked:");
        let top_deltas: Vec<MaskDeltaEntry> = sorted
            .iter()
            .take(10)
            .enumerate()
            .map(|(i, &(d, d2_m, delta, is_f))| {
                println!(
                    "        #{}: p={:5} |Δd²|={:.6e}  d²_masked={:.8} {}",
                    i + 1,
                    d,
                    delta,
                    d2_m,
                    if is_f { "← FACTOR" } else { "" }
                );
                MaskDeltaEntry {
                    prime: d,
                    delta_d2: delta,
                    d2_masked: d2_m,
                    is_factor: is_f,
                }
            })
            .collect();
        let p_rank = sorted.iter().position(|(d, _, _, _)| *d == key.p as usize);
        if let Some(rank) = p_rank {
            println!(
                "      Factor p={} rank: {}/{}",
                key.p,
                rank + 1,
                sorted.len()
            );
        }
        println!();
        results.push(H6Result {
            n: key.n,
            p: key.p,
            q: key.q,
            m,
            d2_full,
            factor_p_rank: p_rank,
            total_primes: sorted.len(),
            top_deltas,
        });
    }
    results
}
