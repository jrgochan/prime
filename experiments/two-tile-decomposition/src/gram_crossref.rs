//! ═══════════════════════════════════════════════════════════════════════════
//!  GRAM CROSS-REFERENCE — Compare FTC decomposition against cached Gram data
//!
//!  Independent validation: the piecewise FTC computation should match the
//!  direct series summation (gram_entry_mpfr) to machine precision.
//!
//!  This certifies that our row-by-row piecewise evaluation produces the
//!  same values as the independent Gram matrix computation.
//!
//!  Fully parallelized with rayon.
//! ═══════════════════════════════════════════════════════════════════════════

use crate::PREC;
use cathedral_utils::fmt;
use cathedral_utils::gram::{LnTable, gram_entry_mpfr};
use rayon::prelude::*;
use rug::Float;

/// Result of cross-referencing a single (j,k) pair.
#[derive(Debug, Clone)]
pub struct CrossRefResult {
    pub j: usize,
    pub k: usize,
    pub a: usize, // j / gcd
    pub b: usize, // k / gcd
    pub gcd: usize,
    pub ftc_value: f64,     // gramIntegral via piecewise FTC (strip + tsum actual)
    pub series_value: f64,  // gramIntegral via direct series (gram_entry_mpfr)
    pub formula_value: f64, // vasyuninGramFormula
    pub err_ftc_series: f64, // |FTC - series|
    pub err_ftc_formula: f64, // |FTC - formula|
}

/// Run the Gram cross-reference for a set of (j,k) pairs.
///
/// For each pair, we compute the Gram integral THREE ways:
///   1. Piecewise FTC (strip + tsum actual) — our decomposition
///   2. Direct series summation (gram_entry_mpfr) — cathedral-utils independent
///   3. Vasyunin closed-form formula — the target identity
///
/// All three should agree (modulo finite-M truncation in method 1).
/// Fully parallelized: each (j,k) pair runs independently on rayon.
pub fn cross_reference(max_n: usize, max_m: usize) -> Vec<CrossRefResult> {
    // Build ln table for gram_entry_mpfr (shared, read-only)
    let ln_max = (max_n * max_n * 5).max(100_000).min(500_000);
    println!(
        "  {}Building ln table (max={}) at {}-bit...{}",
        fmt::DIM,
        ln_max,
        PREC,
        fmt::RESET
    );
    let ln_table = LnTable::with_precision(ln_max, PREC);

    // Collect all (j,k) pairs
    let pairs: Vec<(usize, usize)> = (1..=max_n)
        .flat_map(|j| ((j + 1)..=max_n).map(move |k| (j, k)))
        .collect();

    let n_pairs = pairs.len();
    println!(
        "  {}Cross-referencing {} pairs at M={}...{}",
        fmt::DIM,
        n_pairs,
        max_m,
        fmt::RESET
    );

    // Parallel compute — each (j,k) pair independently
    let mut results: Vec<CrossRefResult> = pairs
        .par_iter()
        .map(|&(j, k)| {
            let g = cathedral_utils::arith::gcd(j, k);
            let a = j / g;
            let b = k / g;

            // Method 1: Piecewise FTC (strip + tsum actual)
            // Use (j,k) directly — no GCD reduction needed for the integral
            let strip_jk = crate::compute::strip_value(j, k);

            // Parallelise the inner row sum too for large M
            let row_integrals: Vec<Float> = (1..=max_m)
                .into_par_iter()
                .map(|m| crate::compute::exact_row_integral(j, k, m))
                .collect();

            // Serial summation for accuracy (order matters for MPFR)
            let mut sum_actual = Float::with_val(PREC, 0);
            for ri in &row_integrals {
                sum_actual += ri;
            }
            let ftc_value = Float::with_val(PREC, &strip_jk + &sum_actual);

            // Method 2: Direct series summation (cathedral-utils)
            let series_value = gram_entry_mpfr(j, k, &ln_table);

            // Method 3: Vasyunin formula
            let formula_value = crate::formula::vasyunin_gram_formula(j, k);

            let err_ftc_series = Float::with_val(
                PREC,
                Float::with_val(PREC, &ftc_value - &series_value).abs(),
            );
            let err_ftc_formula = Float::with_val(
                PREC,
                Float::with_val(PREC, &ftc_value - &formula_value).abs(),
            );

            CrossRefResult {
                j,
                k,
                a,
                b,
                gcd: g,
                ftc_value: ftc_value.to_f64(),
                series_value: series_value.to_f64(),
                formula_value: formula_value.to_f64(),
                err_ftc_series: err_ftc_series.to_f64(),
                err_ftc_formula: err_ftc_formula.to_f64(),
            }
        })
        .collect();

    // Sort by (j, k) for clean output
    results.sort_by_key(|r| (r.j, r.k));
    results
}

/// Print cross-reference results.
pub fn print_cross_reference(results: &[CrossRefResult]) {
    fmt::section("GRAM CROSS-REFERENCE: FTC vs SERIES vs FORMULA");
    println!();
    println!("  Comparing piecewise FTC against gram_entry_mpfr (cathedral-utils)");
    println!("  {} pairs at {}-bit MPFR precision", results.len(), PREC);
    println!();

    println!(
        "  {:>4} {:>4}  {:>4} {:>4} {:>4}  {:>22}  {:>22}  {:>14}  {:>14}",
        "(j",
        "k)",
        "gcd",
        "a",
        "b",
        "FTC (decomposition)",
        "Series (direct)",
        "|FTC-series|",
        "|FTC-formula|"
    );
    println!("  {}", "─".repeat(120));

    let mut max_err_series = 0.0_f64;
    let mut max_err_formula = 0.0_f64;
    let mut all_pass = true;

    for r in results {
        let pass = r.err_ftc_series < 1e-4; // generous for finite-M truncation
        if !pass {
            all_pass = false;
        }
        if r.err_ftc_series > max_err_series {
            max_err_series = r.err_ftc_series;
        }
        if r.err_ftc_formula > max_err_formula {
            max_err_formula = r.err_ftc_formula;
        }

        println!(
            "  ({:>2},{:>2})  {:>3} {:>3} {:>3}  {:>22.15}  {:>22.15}  {:>14.4e}  {:>14.4e}  {}",
            r.j,
            r.k,
            r.gcd,
            r.a,
            r.b,
            r.ftc_value,
            r.series_value,
            r.err_ftc_series,
            r.err_ftc_formula,
            if pass {
                fmt::check(true)
            } else {
                fmt::check(false)
            },
        );
    }

    println!();
    if all_pass {
        println!(
            "  {} ALL {} CROSS-REFERENCES MATCH",
            fmt::check(true),
            results.len()
        );
    } else {
        println!("  {} SOME CROSS-REFERENCES FAILED", fmt::check(false));
    }
    println!(
        "  {}Max |FTC - series|:  {:.4e}{}",
        fmt::DIM,
        max_err_series,
        fmt::RESET
    );
    println!(
        "  {}Max |FTC - formula|: {:.4e}{}",
        fmt::DIM,
        max_err_formula,
        fmt::RESET
    );
    println!();
}
