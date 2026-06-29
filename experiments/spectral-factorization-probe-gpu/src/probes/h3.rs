//! H3: Vasyunin Cotangent Sum Anomaly
//!
//! Tests whether V(m, N) vanishes at exact divisors of N,
//! providing a spectral fingerprint of the factor lattice.

use super::{percentile, vasyunin_sum};
use crate::keygen::SemiprimeKey;
use crate::results::*;
use rayon::prelude::*;

pub fn h3_vasyunin_cotangent_anomaly(keys: &[SemiprimeKey]) -> Vec<H3Result> {
    println!("  [H3] Vasyunin Cotangent Sum Anomaly (parallel scan to √N)");
    println!("  ──────────────────────────────────────────────────────────");
    let mut results = Vec::new();
    for key in keys.iter().take(5) {
        let t0 = std::time::Instant::now();
        let scan_limit = ((key.n as f64).sqrt() as u64).min(100_000);
        let candidates: Vec<u64> = (2..=scan_limit).collect();
        let vasyunin_results: Vec<(u64, f64, bool)> = candidates
            .par_iter()
            .map(|&m| {
                let v = vasyunin_sum(m, key.n);
                (m, v.abs(), key.n % m == 0)
            })
            .collect();

        let mut anomalies = Vec::new();
        let mut non_factor_sums = Vec::new();
        for &(m, v_abs, is_div) in &vasyunin_results {
            if is_div {
                anomalies.push((m, v_abs));
            } else {
                non_factor_sums.push(v_abs);
            }
        }
        let scan_time = t0.elapsed().as_secs_f64();
        let median_nf = percentile(&non_factor_sums, 50.0);
        let p90_nf = percentile(&non_factor_sums, 90.0);

        println!(
            "    N={} = {}×{} (scanned {} candidates in {:.2}s)",
            key.n, key.p, key.q, scan_limit, scan_time
        );
        println!(
            "      Non-factor |V(m,N)| median={:.4e}, p90={:.4e}",
            median_nf, p90_nf
        );

        anomalies.sort_by(|a, b| a.0.cmp(&b.0));
        let factor_anomalies: Vec<VasyuninAnomaly> = anomalies
            .iter()
            .map(|&(m, v)| {
                let label = if m == key.p {
                    " ← FACTOR p"
                } else if m == key.q {
                    " ← FACTOR q"
                } else {
                    " (divisor)"
                };
                println!("      V({}, N) = {:.4e}{}", m, v, label);
                VasyuninAnomaly {
                    m,
                    v_abs: v,
                    is_factor_p: m == key.p,
                    is_factor_q: m == key.q,
                    is_divisor: true,
                }
            })
            .collect();

        let min_factor_v = anomalies
            .iter()
            .map(|(_, v)| *v)
            .fold(f64::INFINITY, f64::min);
        let false_positives = non_factor_sums
            .iter()
            .filter(|&&v| v <= min_factor_v * 1.1)
            .count();
        let perfect = false_positives == 0 && !anomalies.is_empty();
        println!(
            "      False positives (|V| ≤ factor level): {}/{}\n",
            false_positives,
            non_factor_sums.len()
        );

        results.push(H3Result {
            n: key.n,
            p: key.p,
            q: key.q,
            scan_limit,
            scan_time_s: scan_time,
            median_nonfactor: median_nf,
            p90_nonfactor: p90_nf,
            factor_anomalies,
            false_positive_count: false_positives,
            total_nonfactors: non_factor_sums.len(),
            perfect_separation: perfect,
        });
    }
    results
}
