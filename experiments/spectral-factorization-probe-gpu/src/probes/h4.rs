//! H4: Möbius/Liouville Local Structure
//!
//! Tests whether the arithmetic neighborhood of N = p·q shows
//! anomalous Mertens function behavior or squarefree density.

use super::next_non_factor_prime;
use crate::keygen::SemiprimeKey;
use crate::results::*;
use cathedral_utils::arith;

pub fn h4_mobius_local_structure(keys: &[SemiprimeKey]) -> Vec<H4Result> {
    println!("  [H4] Möbius/Liouville Local Structure (parallel)");
    println!("  ─────────────────────────────────────────────────");
    let mut results = Vec::new();
    for key in keys.iter().take(5) {
        if key.n > 2_000_000 { continue; }
        let n = key.n as usize;
        let window = (n / 10).min(2000).max(50);
        let hi = (n + window).min(n + 2000);
        let mu = arith::mobius_table(hi);
        let lambda = arith::liouville_table(hi);

        let (mut m_sum, mut l_sum, mut m_at_n, mut l_at_n) = (0i64, 0i64, 0i64, 0i64);
        for k in 1..=hi.min(mu.len() - 1) {
            m_sum += mu[k] as i64; l_sum += lambda[k] as i64;
            if k == n { m_at_n = m_sum; l_at_n = l_sum; }
        }
        let omega_n = arith::big_omega(n);
        let mu_n = if n < mu.len() { mu[n] } else { 0 };
        let lambda_n = if n < lambda.len() { lambda[n] } else { 0 };

        println!("    N={} = {}×{}", key.n, key.p, key.q);
        println!("      μ(N)={}, λ(N)={}, Ω(N)={}, M(N)={}, L(N)={}", mu_n, lambda_n, omega_n, m_at_n, l_at_n);

        let m_diff_p: Option<i64> = if n + (key.p as usize) <= hi && n + (key.p as usize) < mu.len() {
            Some((n+1..=n + key.p as usize).filter(|&k| k < mu.len()).map(|k| mu[k] as i64).sum::<i64>())
        } else { None };
        let r = next_non_factor_prime(key.p, key.n) as usize;
        let m_diff_r: Option<i64> = if n + r <= hi && n + r < mu.len() {
            Some((n+1..=n + r).filter(|&k| k < mu.len()).map(|k| mu[k] as i64).sum::<i64>())
        } else { None };
        if let (Some(dp), Some(dr)) = (m_diff_p, m_diff_r) {
            println!("      ΔM(N→N+p) = {}, ΔM(N→N+{}) = {}, diff = {}", dp, r, dr, (dp - dr).unsigned_abs());
        }
        let p = key.p as usize;
        let sqfree_count = (n.saturating_sub(p)..=(n+p).min(hi.min(mu.len() - 1)))
            .filter(|&k| k > 0 && k < mu.len() && mu[k] != 0).count();
        let expected_sqfree = (2 * p + 1) as f64 * 6.0 / std::f64::consts::PI.powi(2);
        let sqfree_ratio = sqfree_count as f64 / expected_sqfree;
        println!("      Squarefree in [N-p, N+p]: {} (expected {:.1}), ratio={:.3}\n", sqfree_count, expected_sqfree, sqfree_ratio);

        results.push(H4Result {
            n: key.n, p: key.p, q: key.q, mu_n, lambda_n, big_omega: omega_n,
            mertens_n: m_at_n, liouville_sum_n: l_at_n,
            delta_m_p: m_diff_p, delta_m_rand: m_diff_r,
            sqfree_count, expected_sqfree, sqfree_ratio,
        });
    }
    results
}
