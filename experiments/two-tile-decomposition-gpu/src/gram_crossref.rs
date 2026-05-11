//! ═══════════════════════════════════════════════════════════════════════════
//!  GRAM CROSS-REFERENCE — FTC decomposition vs cathedral-utils series
//!
//!  Independent validation: piecewise FTC computation should match
//!  gram_entry_f64 (direct series summation) to f64 precision.
//!
//!  Three-way comparison: FTC, series, Vasyunin formula.
//! ═══════════════════════════════════════════════════════════════════════════

use crate::compute;
use cathedral_utils::fmt;
use cathedral_utils::gram::gram_entry_f64;
use rayon::prelude::*;

#[derive(Debug, Clone)]
pub struct CrossRefResult {
    pub j: usize,
    pub k: usize,
    pub a: usize,
    pub b: usize,
    pub gcd_val: usize,
    pub ftc_value: f64,
    pub series_value: f64,
    pub formula_value: f64,
    pub err_ftc_series: f64,
    pub err_ftc_formula: f64,
}

pub fn cross_reference(max_n: usize, max_m: usize) -> Vec<CrossRefResult> {
    let pairs: Vec<(usize, usize)> = (1..=max_n)
        .flat_map(|j| ((j + 1)..=max_n).map(move |k| (j, k)))
        .collect();

    println!(
        "  {}Cross-referencing {} pairs at M={}...{}",
        fmt::DIM,
        pairs.len(),
        max_m,
        fmt::RESET
    );

    let mut results: Vec<CrossRefResult> = pairs
        .par_iter()
        .map(|&(j, k)| {
            let g = cathedral_utils::arith::gcd(j, k);
            let a = j / g;
            let b = k / g;

            // Method 1: Piecewise FTC
            let strip = compute::strip_value(j, k);
            let sum_actual: f64 = (1..=max_m)
                .map(|m| compute::exact_row_integral(j, k, m))
                .sum();
            let ftc_value = strip + sum_actual;

            // Method 2: Direct series (cathedral-utils)
            let series_value = gram_entry_f64(j, k);

            // Method 3: Vasyunin formula
            let formula_value = compute::vasyunin_gram_formula(j, k);

            CrossRefResult {
                j,
                k,
                a,
                b,
                gcd_val: g,
                ftc_value,
                series_value,
                formula_value,
                err_ftc_series: (ftc_value - series_value).abs(),
                err_ftc_formula: (ftc_value - formula_value).abs(),
            }
        })
        .collect();

    results.sort_by_key(|r| (r.j, r.k));
    results
}

pub fn print_cross_reference(results: &[CrossRefResult]) {
    fmt::section("§4. GRAM CROSS-REFERENCE: FTC vs SERIES vs FORMULA");
    println!();
    println!("  Comparing piecewise FTC against gram_entry_f64 (cathedral-utils)");
    println!("  {} pairs at f64 precision", results.len());
    println!();

    if results.len() <= 200 {
        println!(
            "  {:>4} {:>4}  {:>22}  {:>22}  {:>14}  {:>14}",
            "(j", "k)", "FTC (decomposition)", "Series (direct)", "|FTC-series|", "|FTC-formula|"
        );
        println!("  {}", "─".repeat(100));

        for r in results {
            let pass = r.err_ftc_series < 1e-3;
            println!(
                "  ({:>2},{:>2})  {:>22.15}  {:>22.15}  {:>14.4e}  {:>14.4e}  {}",
                r.j,
                r.k,
                r.ftc_value,
                r.series_value,
                r.err_ftc_series,
                r.err_ftc_formula,
                if pass {
                    fmt::check(true)
                } else {
                    fmt::check(false)
                }
            );
        }
        println!();
    }

    let max_err_series = results
        .iter()
        .map(|r| r.err_ftc_series)
        .fold(0.0_f64, f64::max);
    let max_err_formula = results
        .iter()
        .map(|r| r.err_ftc_formula)
        .fold(0.0_f64, f64::max);
    let all_pass = max_err_series < 1e-3;

    if all_pass {
        println!(
            "  {} ALL {} CROSS-REFERENCES MATCH",
            fmt::check(true),
            results.len()
        );
    } else {
        println!("  {} SOME CROSS-REFERENCES FAILED", fmt::check(false));
    }
    println!("  Max |FTC - series|:  {:.4e}", max_err_series);
    println!("  Max |FTC - formula|: {:.4e}", max_err_formula);
    println!();
}
