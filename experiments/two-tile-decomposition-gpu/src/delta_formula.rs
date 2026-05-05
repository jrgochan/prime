//! ═══════════════════════════════════════════════════════════════════════════
//!  DELTA FORMULA — Closed-form Δ(m) verification at f64 precision
//!
//!  For each two-tile row m, verifies:
//!    Δ(m) = -(1/a)·ln(a(m+1)/(a(m+1)-s)) + m·s/(a(m+1)·(a(m+1)-s))
//!  matches the numerical difference (exact_row_integral - rowTerm).
//!
//!  Accumulates by residue class for structural analysis.
//! ═══════════════════════════════════════════════════════════════════════════

use rayon::prelude::*;
use cathedral_utils::fmt;
use crate::compute;

#[derive(Debug, Clone)]
pub struct ResidueClassResult {
    pub r: usize,
    pub s: usize,
    pub count: usize,
    pub sum_delta_exact: f64,
    pub sum_delta_numerical: f64,
    pub max_pointwise_error: f64,
}

#[derive(Debug, Clone)]
pub struct DeltaFormulaResult {
    pub a: usize,
    pub b: usize,
    pub max_pointwise_error: f64,
    pub total_delta_exact: f64,
    pub total_delta_numerical: f64,
    pub formula_vs_numerical_error: f64,
    pub n_classes: usize,
}

pub fn certify_pair(a: usize, b: usize, max_m: usize) -> DeltaFormulaResult {
    let mut total_exact = 0.0_f64;
    let mut total_numerical = 0.0_f64;
    let mut max_error = 0.0_f64;
    let mut n_classes_seen = std::collections::HashSet::new();

    for m in 1..=max_m {
        let r = (a * m) % b;
        let n_hi = (a * m) / b;
        let n_lo = (a * (m + 1)) / b;
        if n_hi == n_lo { continue; }

        n_classes_seen.insert(r);

        let d_exact = compute::delta_exact(a, b, m);
        let actual = compute::exact_row_integral(a, b, m);
        let rt = compute::row_term(a, b, m);
        let d_numerical = actual - rt;

        let err = (d_exact - d_numerical).abs();
        if err > max_error { max_error = err; }

        total_exact += d_exact;
        total_numerical += d_numerical;
    }

    DeltaFormulaResult {
        a, b,
        max_pointwise_error: max_error,
        total_delta_exact: total_exact,
        total_delta_numerical: total_numerical,
        formula_vs_numerical_error: (total_exact - total_numerical).abs(),
        n_classes: n_classes_seen.len(),
    }
}

pub fn certify_all(pairs: &[(usize, usize)], max_m: usize) -> Vec<DeltaFormulaResult> {
    let mut results: Vec<_> = pairs.par_iter()
        .map(|&(a, b)| certify_pair(a, b, max_m))
        .collect();
    results.sort_by_key(|r| (r.a, r.b));
    results
}

pub fn print_certification(results: &[DeltaFormulaResult]) {
    fmt::section("§1. DELTA FORMULA CERTIFICATION");
    println!();
    println!("  Verifying: Δ(m) = -(1/a)·ln(a(m+1)/(a(m+1)-s)) + m·s/(a(m+1)·(a(m+1)-s))");
    println!();

    if results.len() <= 200 {
        println!("  {:>5} {:>5}  {:>16}  {:>16}  {:>14}  {:>6}",
            "(a", "b)", "Σ'Δ (formula)", "Σ'Δ (FTC)", "|error|", "cls");
        println!("  {}", "─".repeat(75));

        for r in results {
            let pass = r.max_pointwise_error < 1e-8;
            println!("  ({:>2},{:>2})  {:>16.10e}  {:>16.10e}  {:>14.4e}  {:>4}  {}",
                r.a, r.b,
                r.total_delta_exact, r.total_delta_numerical,
                r.max_pointwise_error, r.n_classes,
                if pass { fmt::check(true) } else { fmt::check(false) },
            );
        }
        println!();
    }

    let max_err = results.iter().map(|r| r.max_pointwise_error).fold(0.0_f64, f64::max);
    let all_pass = max_err < 1e-8;

    if all_pass {
        println!("  {} ALL DELTA FORMULA IDENTITIES CERTIFIED across {} pairs",
            fmt::check(true), results.len());
    } else {
        let n_fail = results.iter().filter(|r| r.max_pointwise_error >= 1e-8).count();
        println!("  {} {} failures", fmt::check(false), n_fail);
    }
    println!("  Max |Δ_formula - Δ_FTC|: {:.4e}", max_err);
    println!();
}
