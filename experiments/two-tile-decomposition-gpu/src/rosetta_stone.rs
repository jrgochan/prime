//! ═══════════════════════════════════════════════════════════════════════════
//!  ROSETTA STONE — gramEntry ↔ gramIntegral Bridge at f64 precision
//!
//!  Verifies the exact formula:
//!     gramEntry(j,k) = jk · gramIntegral(j,k)
//!                       - (min(j,k) - 1)
//!                       - ∫₁^max(j,k) {j/x}{k/x} dx
//!
//!  This bridges Tower A (Sieve Engine) and Tower B (Cotangent Wing).
//!
//!  Also verifies the Phantom Axiom counterexample.
//!
//!  Attribution: Gemini Actual (derivation), Claude Actual (verification)
//! ═══════════════════════════════════════════════════════════════════════════

use cathedral_utils::fmt;
use cathedral_utils::gram::gram_entry_f64;

#[derive(Debug, Clone)]
pub struct BridgeResult {
    pub j: usize,
    pub k: usize,
    pub gram_entry: f64,
    pub gram_integral: f64,
    pub jk_gram_integral: f64,
    pub min_minus_1: f64,
    pub correction: f64,
    pub bridge_prediction: f64,
    pub bridge_error: f64,
    pub phantom_dist: f64,
    pub phantom_bound: f64,
    pub phantom_violated: bool,
}

/// Compute gramEntry(j,k) = ∫₀¹ {j/x}{k/x} dx via piecewise exact integration.
fn gram_entry_quadrature(j: usize, k: usize) -> f64 {
    let jf = j as f64;
    let kf = k as f64;

    // Collect breakpoints in (0, 1]
    let mut breakpoints: Vec<f64> = vec![1.0];
    let limit = (j.max(k) * 10000).min(500_000);
    for m in j..=limit {
        let bp = jf / m as f64;
        if bp < 1e-8 { break; }
        if bp <= 1.0 { breakpoints.push(bp); }
    }
    for m in k..=limit {
        let bp = kf / m as f64;
        if bp < 1e-8 { break; }
        if bp <= 1.0 { breakpoints.push(bp); }
    }

    breakpoints.sort_by(|a, b| a.partial_cmp(b).unwrap());
    breakpoints.dedup_by(|a, b| (*a - *b).abs() < 1e-15);

    let mut total = 0.0_f64;
    for w in breakpoints.windows(2) {
        let lo = w[0];
        let hi = w[1];
        if hi - lo < 1e-18 { continue; }

        let mid = (lo + hi) / 2.0;
        let mj = (jf / mid).floor();
        let mk = (kf / mid).floor();

        // ∫ (jk/x² - (j·mk + k·mj)/x + mj·mk) dx
        let term1 = jf * kf * (1.0/lo - 1.0/hi);
        let coeff2 = jf * mk + kf * mj;
        let term2 = coeff2 * (hi/lo).ln();
        let term3 = mj * mk * (hi - lo);

        total += term1 - term2 + term3;
    }
    total
}

/// Compute ∫₁^max(j,k) {j/x}{k/x} dx (finite correction).
fn finite_correction(j: usize, k: usize) -> f64 {
    let m = j.max(k);
    if m <= 1 { return 0.0; }

    let jf = j as f64;
    let kf = k as f64;

    let mut breakpoints: Vec<f64> = vec![1.0, m as f64];
    for n in 1..=j {
        let bp = jf / n as f64;
        if bp > 1.0 && bp < m as f64 { breakpoints.push(bp); }
    }
    for n in 1..=k {
        let bp = kf / n as f64;
        if bp > 1.0 && bp < m as f64 { breakpoints.push(bp); }
    }
    breakpoints.sort_by(|a, b| a.partial_cmp(b).unwrap());
    breakpoints.dedup_by(|a, b| (*a - *b).abs() < 1e-12);

    let mut total = 0.0_f64;
    for w in breakpoints.windows(2) {
        let lo = w[0];
        let hi = w[1];
        if hi - lo < 1e-15 { continue; }

        let mid = (lo + hi) / 2.0;
        let mj = (jf / mid).floor();
        let mk = (kf / mid).floor();

        let term1 = jf * kf * (1.0/lo - 1.0/hi);
        let coeff2 = jf * mk + kf * mj;
        let term2 = coeff2 * (hi/lo).ln();
        let term3 = mj * mk * (hi - lo);

        total += term1 - term2 + term3;
    }
    total
}

pub fn verify_bridge(max_n: usize) -> Vec<BridgeResult> {
    let pairs: Vec<(usize, usize)> = (1..=max_n)
        .flat_map(|j| (j..=max_n).map(move |k| (j, k)))
        .filter(|&(j, k)| j != k)
        .collect();

    let mut results: Vec<BridgeResult> = pairs.iter()
        .map(|&(j, k)| {
            let gi = gram_entry_f64(j, k); // series-based gramIntegral
            let ge = gram_entry_quadrature(j, k);

            let jk = (j * k) as f64;
            let min_1 = (j.min(k) - 1) as f64;
            let corr = finite_correction(j, k);

            let prediction = jk * gi - min_1 - corr;
            let bridge_err = (ge - prediction).abs();

            let g = cathedral_utils::arith::gcd(j, k);
            let dist = (ge - 0.25).abs();
            let bound = 1.0 / g as f64;

            BridgeResult {
                j, k,
                gram_entry: ge,
                gram_integral: gi,
                jk_gram_integral: jk * gi,
                min_minus_1: min_1,
                correction: corr,
                bridge_prediction: prediction,
                bridge_error: bridge_err,
                phantom_dist: dist,
                phantom_bound: bound,
                phantom_violated: g >= 5 && dist > bound,
            }
        })
        .collect();

    results.sort_by_key(|r| (r.j, r.k));
    results
}

pub fn print_bridge(results: &[BridgeResult]) {
    fmt::section("§5. ROSETTA STONE — gramEntry ↔ gramIntegral Bridge");
    println!();
    println!("  Formula: gramEntry(j,k) = jk·gramIntegral(j,k) - (min(j,k)-1) - ∫₁^max {{j/x}}{{k/x}} dx");
    println!();

    if results.len() <= 200 {
        println!("  {:>4} {:>4}  {:>18}  {:>18}  {:>14}",
            "(j", "k)", "gramEntry", "PREDICTED", "|error|");
        println!("  {}", "─".repeat(70));

        for r in results {
            let pass = r.bridge_error < 1e-3;
            println!("  ({:>2},{:>2})  {:>18.12}  {:>18.12}  {:>14.4e}  {}",
                r.j, r.k, r.gram_entry, r.bridge_prediction, r.bridge_error,
                if pass { "✅" } else { "❌" });
        }
        println!();
    }

    let max_err = results.iter().map(|r| r.bridge_error).fold(0.0_f64, f64::max);
    let all_pass = max_err < 1e-3;

    if all_pass {
        println!("  {} ALL {} BRIDGE VERIFICATIONS PASS", fmt::check(true), results.len());
    } else {
        println!("  {} SOME BRIDGE VERIFICATIONS FAILED", fmt::check(false));
    }
    println!("  Max bridge error: {:.4e}", max_err);
    println!();

    // Phantom Axiom audit
    let violated: Vec<&BridgeResult> = results.iter().filter(|r| r.phantom_violated).collect();
    fmt::section("PHANTOM AXIOM AUDIT — |gramEntry - 1/4| ≤ 1/gcd?");
    println!();
    if violated.is_empty() {
        println!("  No violations found in test range");
    } else {
        println!("  {} VIOLATIONS FOUND:", violated.len());
        for r in &violated {
            let g = cathedral_utils::arith::gcd(r.j, r.k);
            println!("  💀 ({},{}) gcd={}: |G-1/4| = {:.6} > 1/{} = {:.6}",
                r.j, r.k, g, r.phantom_dist, g, r.phantom_bound);
        }
    }
    println!();
}
