//! ═══════════════════════════════════════════════════════════════════════════
//!  ROSETTA STONE — The Algebraic Bridge between gramEntry and gramIntegral
//!
//!  Verifies the exact formula discovered 2026-05-04:
//!
//!     gramEntry(j,k) = jk · gramIntegral(j,k)
//!                       - (min(j,k) - 1)
//!                       - ∫₁^max(j,k) {j/x}{k/x} dx
//!
//!  Where:
//!     gramEntry(j,k)    = ∫₀¹ {j/x}{k/x} dx     (Nyman-Beurling inner product)
//!     gramIntegral(j,k) = ∫₀¹ {1/(jx)}{1/(kx)} dx  (Vasyunin parameterization)
//!
//!  This bridge connects Tower A (the Sieve Engine) to Tower B (the Cotangent
//!  Wing), unifying the two parallel proof chains in the Cathedral.
//!
//!  Also verifies the Phantom Axiom counterexample:
//!     |gramEntry(100,200) - 1/4| ≈ 0.0407 > 0.01 = 1/gcd
//!
//!  Attribution: Gemini Actual (derivation), Claude Actual (numerical verification)
//!  Date: 2026-05-04
//! ═══════════════════════════════════════════════════════════════════════════

use rug::Float;
use rug::ops::Pow;
use cathedral_utils::fmt;
use crate::PREC;

/// Compute gramEntry(j,k) = ∫₀¹ {j/x}{k/x} dx via high-precision quadrature.
///
/// Uses piecewise evaluation: on each interval (1/(n+1), 1/n), the floor
/// functions ⌊j/x⌋ and ⌊k/x⌋ are constant, so {j/x}{k/x} becomes a
/// rational function of x that can be integrated exactly.
fn gram_entry_quadrature(j: usize, k: usize, _num_intervals: usize) -> Float {
    // gramEntry(j,k) = ∫₀¹ {j/x}{k/x} dx
    // Breakpoints at x = j/m and x = k/m for all relevant integers m.
    // Between consecutive breakpoints, {j/x} = j/x - mj and {k/x} = k/x - mk.
    // Product = (j/x - mj)(k/x - mk) = jk/x² - (j·mk + k·mj)/x + mj·mk
    // Exact anti-derivative: -jk/x - (j·mk + k·mj)·ln(x) + mj·mk·x

    let jf = Float::with_val(PREC, j as u64);
    let kf = Float::with_val(PREC, k as u64);

    // Collect all breakpoints in (0, 1]
    let mut breakpoints: Vec<f64> = Vec::new();
    breakpoints.push(1.0);

    // x = j/m for integer m, while j/m > 0 and j/m <= 1
    for m in j..=(j * 10000).min(1_000_000) {
        let bp = j as f64 / m as f64;
        if bp < 1e-8 { break; }
        if bp <= 1.0 { breakpoints.push(bp); }
    }
    // x = k/m
    for m in k..=(k * 10000).min(1_000_000) {
        let bp = k as f64 / m as f64;
        if bp < 1e-8 { break; }
        if bp <= 1.0 { breakpoints.push(bp); }
    }

    breakpoints.sort_by(|a, b| a.partial_cmp(b).unwrap());
    breakpoints.dedup_by(|a, b| (*a - *b).abs() < 1e-15);

    let mut total = Float::with_val(PREC, 0);

    for w in breakpoints.windows(2) {
        let lo = w[0];
        let hi = w[1];
        if hi - lo < 1e-18 { continue; }

        // At midpoint, determine floor values (constant on this interval)
        let mid = (lo + hi) / 2.0;
        let mj = (j as f64 / mid).floor() as i64;
        let mk = (k as f64 / mid).floor() as i64;

        let lo_f = Float::with_val(PREC, lo);
        let hi_f = Float::with_val(PREC, hi);
        let mj_f = Float::with_val(PREC, mj);
        let mk_f = Float::with_val(PREC, mk);

        // ∫_lo^hi (jk/x² - (j·mk + k·mj)/x + mj·mk) dx
        // = jk·(1/lo - 1/hi) - (j·mk + k·mj)·ln(hi/lo) + mj·mk·(hi - lo)

        let term1 = Float::with_val(PREC, &jf * &kf) *
            Float::with_val(PREC,
                Float::with_val(PREC, 1.0) / &lo_f -
                Float::with_val(PREC, 1.0) / &hi_f);

        let coeff2 = Float::with_val(PREC,
            Float::with_val(PREC, &jf * &mk_f) +
            Float::with_val(PREC, &kf * &mj_f));
        let term2 = Float::with_val(PREC, &coeff2 *
            Float::with_val(PREC, Float::with_val(PREC, &hi_f / &lo_f).ln()));

        let term3 = Float::with_val(PREC, &mj_f * &mk_f) *
            Float::with_val(PREC, &hi_f - &lo_f);

        let sub12 = Float::with_val(PREC, &term1 - &term2);
        total += Float::with_val(PREC, &sub12 + &term3);
    }

    total
}

/// Compute the finite correction integral: ∫₁^max(j,k) {j/x}{k/x} dx.
///
/// This integral is over a bounded region where the fractional parts
/// are piecewise polynomial. We evaluate it by splitting at breakpoints
/// x = j/m and x = k/m for all relevant integers m.
fn finite_correction(j: usize, k: usize) -> Float {
    let m = j.max(k);
    if m <= 1 {
        return Float::with_val(PREC, 0);
    }

    let jf = Float::with_val(PREC, j as u64);
    let kf = Float::with_val(PREC, k as u64);

    // Collect all breakpoints in [1, max(j,k)]
    let mut breakpoints: Vec<f64> = vec![1.0, m as f64];
    // x = j/n for integer n where 1 < j/n < max
    for n in 1..=j {
        let bp = j as f64 / n as f64;
        if bp > 1.0 && bp < m as f64 {
            breakpoints.push(bp);
        }
    }
    // x = k/n
    for n in 1..=k {
        let bp = k as f64 / n as f64;
        if bp > 1.0 && bp < m as f64 {
            breakpoints.push(bp);
        }
    }
    breakpoints.sort_by(|a, b| a.partial_cmp(b).unwrap());
    breakpoints.dedup_by(|a, b| (*a - *b).abs() < 1e-12);

    let mut total = Float::with_val(PREC, 0);

    for w in breakpoints.windows(2) {
        let lo = w[0];
        let hi = w[1];
        if hi - lo < 1e-15 { continue; }

        // At midpoint, determine floor values
        let mid = (lo + hi) / 2.0;
        let mj = (j as f64 / mid).floor() as i64;
        let mk = (k as f64 / mid).floor() as i64;

        let lo_f = Float::with_val(PREC, lo);
        let hi_f = Float::with_val(PREC, hi);
        let mj_f = Float::with_val(PREC, mj);
        let mk_f = Float::with_val(PREC, mk);

        // Exact: ∫_lo^hi (jk/x² - (j·mk + k·mj)/x + mj·mk) dx
        let term1 = Float::with_val(PREC, &jf * &kf) *
            Float::with_val(PREC,
                Float::with_val(PREC, 1.0) / &lo_f -
                Float::with_val(PREC, 1.0) / &hi_f);
        let coeff2 = Float::with_val(PREC,
            Float::with_val(PREC, &jf * &mk_f) +
            Float::with_val(PREC, &kf * &mj_f));
        let term2 = Float::with_val(PREC, &coeff2 *
            Float::with_val(PREC, Float::with_val(PREC, &hi_f / &lo_f).ln()));
        let term3 = Float::with_val(PREC, &mj_f * &mk_f) *
            Float::with_val(PREC, &hi_f - &lo_f);

        let sub12 = Float::with_val(PREC, &term1 - &term2);
        total += Float::with_val(PREC, &sub12 + &term3);
    }

    total
}

/// Result of the Rosetta Stone bridge verification.
#[derive(Debug, Clone)]
pub struct BridgeResult {
    pub j: usize,
    pub k: usize,
    pub gram_entry: f64,           // ∫₀¹ {j/x}{k/x} dx
    pub gram_integral: f64,         // ∫₀¹ {1/(jx)}{1/(kx)} dx (from series)
    pub jk_gram_integral: f64,      // jk · gramIntegral
    pub min_minus_1: f64,           // min(j,k) - 1
    pub correction: f64,            // ∫₁^max {j/x}{k/x} dx
    pub bridge_prediction: f64,     // jk·gramIntegral - (min-1) - correction
    pub bridge_error: f64,          // |gramEntry - prediction|
    pub phantom_dist: f64,          // |gramEntry - 1/4|
    pub phantom_bound: f64,         // 1/gcd(j,k)
    pub phantom_violated: bool,     // phantom_dist > phantom_bound?
}

/// Run the Rosetta Stone bridge verification.
pub fn verify_bridge(max_n: usize) -> Vec<BridgeResult> {
    let ln_max = (max_n * max_n * 5).max(10_000).min(500_000);
    let ln_table = cathedral_utils::gram::LnTable::with_precision(ln_max, PREC);

    let pairs: Vec<(usize, usize)> = (1..=max_n)
        .flat_map(|j| (j..=max_n).map(move |k| (j, k)))
        .filter(|&(j, k)| j != k)
        .collect();

    let mut results: Vec<BridgeResult> = pairs.iter()
        .map(|&(j, k)| {
            // gramIntegral via series (proven to match formula)
            let gi = cathedral_utils::gram::gram_entry_mpfr(j, k, &ln_table);
            let gi_f64 = gi.to_f64();

            // gramEntry via quadrature
            let ge = gram_entry_quadrature(j, k, j.max(k) * 20);
            let ge_f64 = ge.to_f64();

            // Bridge components
            let jk = (j * k) as f64;
            let min_1 = (j.min(k) - 1) as f64;
            let corr = finite_correction(j, k);
            let corr_f64 = corr.to_f64();

            let prediction = jk * gi_f64 - min_1 - corr_f64;
            let bridge_err = (ge_f64 - prediction).abs();

            // Phantom axiom check
            let g = crate::compute::gcd(j, k);
            let dist = (ge_f64 - 0.25).abs();
            let bound = 1.0 / g as f64;

            BridgeResult {
                j, k,
                gram_entry: ge_f64,
                gram_integral: gi_f64,
                jk_gram_integral: jk * gi_f64,
                min_minus_1: min_1,
                correction: corr_f64,
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

/// Print Rosetta Stone bridge results.
pub fn print_bridge(results: &[BridgeResult]) {
    fmt::section("THE ROSETTA STONE — gramEntry ↔ gramIntegral Bridge Verification");
    println!();
    println!("  Formula: gramEntry(j,k) = jk·gramIntegral(j,k) - (min(j,k)-1) - ∫₁^max {{j/x}}{{k/x}} dx");
    println!();

    println!("  {:>4} {:>4}  {:>18}  {:>18}  {:>14}  {:>10}",
        "(j", "k)", "gramEntry", "PREDICTED", "|error|", "status");
    println!("  {}", "─".repeat(80));

    let mut max_err = 0.0_f64;
    let mut all_pass = true;

    for r in results {
        let pass = r.bridge_error < 1e-3;
        if !pass { all_pass = false; }
        if r.bridge_error > max_err { max_err = r.bridge_error; }

        println!("  ({:>2},{:>2})  {:>18.12}  {:>18.12}  {:>14.4e}  {}",
            r.j, r.k, r.gram_entry, r.bridge_prediction, r.bridge_error,
            if pass { "✅" } else { "❌" });
    }

    println!();
    if all_pass {
        println!("  {} ALL {} BRIDGE VERIFICATIONS PASS", fmt::check(true), results.len());
    } else {
        println!("  {} SOME BRIDGE VERIFICATIONS FAILED", fmt::check(false));
    }
    println!("  {}Max bridge error: {:.4e}{}", fmt::DIM, max_err, fmt::RESET);
    println!();

    // Phantom Axiom audit
    let violated: Vec<&BridgeResult> = results.iter().filter(|r| r.phantom_violated).collect();
    fmt::section("PHANTOM AXIOM AUDIT — |gramEntry - 1/4| ≤ 1/gcd?");
    println!();

    if violated.is_empty() {
        println!("  No violations found in test range (gcd ≥ 5 cases may not be present)");
    } else {
        println!("  {} VIOLATIONS FOUND (axiom vasyunin_large_gcd is FALSE):", violated.len());
        println!();
        for r in &violated {
            let g = crate::compute::gcd(r.j, r.k);
            println!("  💀 ({},{}) gcd={}: |G-1/4| = {:.6} > 1/{} = {:.6}",
                r.j, r.k, g, r.phantom_dist, g, r.phantom_bound);
        }
    }
    println!();
}
