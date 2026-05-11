//! ═══════════════════════════════════════════════════════════════════════════
//!  PER-CLASS ACTUAL EVALUATION — Certify per-class delta sums
//!
//!  For each two-tile residue class r, computes the per-class delta sum
//!  BOTH from the actual - rowTerm difference AND from the closed-form
//!  delta formula, verifying they match to full MPFR precision.
//!
//!  Then sums ALL class contributions (single-tile + two-tile) to verify
//!  that strip + Σ_class actual_class_sum = formula.
//!
//!  This is the key certification for the Lean proof: it shows that the
//!  per-class structure is internally consistent and that the sum over
//!  all classes reproduces the Vasyunin formula.
//! ═══════════════════════════════════════════════════════════════════════════

use rug::Float;
use rayon::prelude::*;
use cathedral_utils::fmt;
use crate::PREC;
use crate::compute::fu;

/// Per-class evaluation result.
#[derive(Debug, Clone)]
pub struct ClassEvalResult {
    pub r: usize,
    pub s: usize,
    pub m0: usize,
    pub is_two_tile: bool,
    pub count: usize,
    pub sum_actual: f64,
    pub sum_rowterm: f64,
    pub sum_delta_diff: f64,     // actual - rowterm (numerical)
    pub sum_delta_formula: f64,  // from closed-form Δ(m) formula
    pub delta_match_err: f64,    // |diff - formula|
}

/// Per-pair result.
#[derive(Debug, Clone)]
pub struct PairClassEval {
    pub a: usize,
    pub b: usize,
    pub classes: Vec<ClassEvalResult>,
    pub integral_vs_formula: f64,
    pub n_two_tile: usize,
}

/// Compute the closed-form Δ(m) for a two-tile row.
/// Δ(m) = -(1/a)·log(a(m+1)/(a(m+1)-s)) + m·s/(a(m+1)·(a(m+1)-s))
fn delta_formula(a: usize, s: usize, m: usize) -> Float {
    if s == 0 { return Float::with_val(PREC, 0); }
    let af = fu(a);
    let sf = fu(s);
    let mf = fu(m);
    let m1 = fu(m + 1);
    let am1 = Float::with_val(PREC, &af * &m1);
    let am1_s = Float::with_val(PREC, &am1 - &sf);

    // log piece: -(1/a) · log(am1 / am1_s)
    let log_arg = Float::with_val(PREC, &am1 / &am1_s);
    let log_piece = Float::with_val(PREC,
        -Float::with_val(PREC, log_arg.ln() / &af));

    // linear piece: m·s / (am1 · am1_s)  (note: no 1/a factor here — it's absorbed)
    let num = Float::with_val(PREC, &mf * &sf);
    let den = Float::with_val(PREC, &am1 * &am1_s);
    let lin_piece = Float::with_val(PREC, &num / &den);

    Float::with_val(PREC, &log_piece + &lin_piece)
}

/// Certify per-class evaluation for a coprime pair.
pub fn certify_pair(a: usize, b: usize, max_m: usize) -> PairClassEval {
    let mut classes = Vec::new();
    let mut total_actual = Float::with_val(PREC, 0);

    for r in 1..b {
        // Find m₀: smallest m ≥ 1 with (a·m) mod b = r
        let m0 = (1..=b).find(|&m| (a * m) % b == r).unwrap_or(b);
        if m0 > max_m { continue; }

        let s = (r + a).saturating_sub(b);
        let is_two_tile = s > 0;

        let mut sum_actual = Float::with_val(PREC, 0);
        let mut sum_rowterm = Float::with_val(PREC, 0);
        let mut sum_delta_formula = Float::with_val(PREC, 0);
        let mut count = 0usize;

        let mut m = m0;
        while m <= max_m {
            sum_actual += crate::compute::exact_row_integral(a, b, m);
            sum_rowterm += crate::compute::row_term(a, b, m);
            if is_two_tile {
                sum_delta_formula += delta_formula(a, s, m);
            }
            count += 1;
            m += b;
        }

        let sum_delta_diff = Float::with_val(PREC, &sum_actual - &sum_rowterm);
        let delta_match = Float::with_val(PREC,
            Float::with_val(PREC, &sum_delta_diff - &sum_delta_formula).abs());

        total_actual += &sum_actual;

        classes.push(ClassEvalResult {
            r, s, m0, is_two_tile, count,
            sum_actual: sum_actual.to_f64(),
            sum_rowterm: sum_rowterm.to_f64(),
            sum_delta_diff: sum_delta_diff.to_f64(),
            sum_delta_formula: sum_delta_formula.to_f64(),
            delta_match_err: delta_match.to_f64(),
        });
    }

    let strip = crate::compute::strip_value(a, b);
    let integral = Float::with_val(PREC, &strip + &total_actual);
    let formula_val = crate::formula::vasyunin_gram_formula(a, b);
    let err = Float::with_val(PREC,
        Float::with_val(PREC, &integral - &formula_val).abs());
    let n_two_tile = classes.iter().filter(|c| c.is_two_tile).count();

    PairClassEval {
        a, b, classes,
        integral_vs_formula: err.to_f64(),
        n_two_tile,
    }
}

/// Run certification for all pairs in parallel.
pub fn certify_all(pairs: &[(usize, usize)], max_m: usize) -> Vec<PairClassEval> {
    let mut results: Vec<_> = pairs.par_iter()
        .map(|&(a, b)| certify_pair(a, b, max_m))
        .collect();
    results.sort_by_key(|r| (r.a, r.b));
    results
}

/// Print results.
pub fn print_certification(results: &[PairClassEval]) {
    fmt::section("PER-CLASS ACTUAL EVALUATION");
    println!();
    println!("  Verifying per-class: |Σ_j [actual(m₀+jb) - rowTerm(m₀+jb)] - Σ_j Δ_formula(m₀+jb)|");
    println!("  And total: |strip + Σ_class actual - formula|");
    println!();

    println!("  {:>5} {:>5}  {:>14}  {:>14}  {:>5}",
        "(a", "b)", "max|δ-match|", "|GI - formula|", "2tile");
    println!("  {}", "─".repeat(60));

    let mut all_pass = true;
    let mut max_delta_err = 0.0_f64;
    let mut max_formula_err = 0.0_f64;

    for r in results {
        let max_class_err = r.classes.iter()
            .filter(|c| c.is_two_tile)
            .map(|c| c.delta_match_err)
            .fold(0.0_f64, f64::max);

        let pass = max_class_err < 1e-100;  // should match to MPFR precision
        if !pass { all_pass = false; }
        if max_class_err > max_delta_err { max_delta_err = max_class_err; }
        if r.integral_vs_formula > max_formula_err { max_formula_err = r.integral_vs_formula; }

        println!("  ({:>2},{:>2})  {:>14.4e}  {:>14.4e}  {:>3}    {}",
            r.a, r.b,
            max_class_err, r.integral_vs_formula,
            r.n_two_tile,
            if pass { fmt::check(true) } else { fmt::check(false) },
        );
    }

    println!();
    if all_pass {
        println!("  {} ALL PER-CLASS DELTA IDENTITIES CERTIFIED", fmt::check(true));
    } else {
        println!("  {} SOME PER-CLASS CHECKS FAILED", fmt::check(false));
    }
    println!("  {}Max |Δ_diff - Δ_formula|: {:.4e}{}", fmt::DIM, max_delta_err, fmt::RESET);
    println!("  {}Max |strip + Σ actual - formula|: {:.4e}{}", fmt::DIM, max_formula_err, fmt::RESET);
    println!();
}
