//! ═══════════════════════════════════════════════════════════════════════════
//!  CLASS EVAL — Per-class delta sum verification at f64 precision
//!
//!  For each residue class r mod b, sums Δ(m₀+jb) over j and verifies:
//!    |Σ_j (actual - rowTerm) - Σ_j Δ_formula| < ε
//!  Then checks: |strip + Σ_class actual - vasyuninFormula| < ε
//! ═══════════════════════════════════════════════════════════════════════════

use rayon::prelude::*;
use cathedral_utils::fmt;
use crate::compute;

#[derive(Debug, Clone)]
pub struct ClassResult {
    pub r: usize,
    pub s: usize,
    pub m0: usize,
    pub is_two_tile: bool,
    pub count: usize,
    pub sum_actual: f64,
    pub sum_delta_diff: f64,
    pub sum_delta_formula: f64,
    pub delta_match_err: f64,
}

#[derive(Debug, Clone)]
pub struct PairClassEval {
    pub a: usize,
    pub b: usize,
    pub max_delta_err: f64,
    pub integral_vs_formula: f64,
    pub n_two_tile: usize,
    pub n_classes: usize,
}

pub fn certify_pair(a: usize, b: usize, max_m: usize) -> PairClassEval {
    let mut total_actual = 0.0_f64;
    let mut max_delta_err = 0.0_f64;
    let mut n_two_tile = 0usize;
    let mut n_classes = 0usize;

    for r in 1..b {
        let m0 = match (1..=b).find(|&m| (a * m) % b == r) {
            Some(m0) if m0 <= max_m => m0,
            _ => continue,
        };

        let s = (r + a).saturating_sub(b);
        let is_tt = s > 0;
        if is_tt { n_two_tile += 1; }
        n_classes += 1;

        let mut sum_actual = 0.0;
        let mut sum_delta_diff = 0.0;
        let mut sum_delta_formula = 0.0;
        let mut m = m0;

        while m <= max_m {
            let actual = compute::exact_row_integral(a, b, m);
            let rt = compute::row_term(a, b, m);
            sum_actual += actual;
            sum_delta_diff += actual - rt;
            if is_tt {
                sum_delta_formula += compute::delta_exact(a, b, m);
            }
            m += b;
        }

        total_actual += sum_actual;
        let delta_err = (sum_delta_diff - sum_delta_formula).abs();
        if delta_err > max_delta_err { max_delta_err = delta_err; }
    }

    let strip = compute::strip_value(a, b);
    let integral = strip + total_actual;
    let formula = compute::vasyunin_gram_formula(a, b);
    let formula_err = (integral - formula).abs();

    PairClassEval {
        a, b,
        max_delta_err,
        integral_vs_formula: formula_err,
        n_two_tile, n_classes,
    }
}

pub fn certify_all(pairs: &[(usize, usize)], max_m: usize) -> Vec<PairClassEval> {
    let mut results: Vec<_> = pairs.par_iter()
        .map(|&(a, b)| certify_pair(a, b, max_m))
        .collect();
    results.sort_by_key(|r| (r.a, r.b));
    results
}

pub fn print_certification(results: &[PairClassEval]) {
    fmt::section("§2. PER-CLASS ACTUAL EVALUATION");
    println!();
    println!("  Verifying: |Σ_j [actual - rowTerm] - Σ_j Δ_formula| < ε per class");
    println!("  And total: |strip + Σ_class actual - formula| < ε");
    println!();

    if results.len() <= 200 {
        println!("  {:>5} {:>5}  {:>14}  {:>14}  {:>5}",
            "(a", "b)", "max|δ-match|", "|GI - formula|", "2tile");
        println!("  {}", "─".repeat(60));

        for r in results {
            let pass = r.max_delta_err < 1e-8;
            println!("  ({:>2},{:>2})  {:>14.4e}  {:>14.4e}  {:>3}    {}",
                r.a, r.b, r.max_delta_err, r.integral_vs_formula,
                r.n_two_tile,
                if pass { fmt::check(true) } else { fmt::check(false) },
            );
        }
        println!();
    }

    let max_delta = results.iter().map(|r| r.max_delta_err).fold(0.0_f64, f64::max);
    let max_formula = results.iter().map(|r| r.integral_vs_formula).fold(0.0_f64, f64::max);
    let all_pass = max_delta < 1e-8;

    if all_pass {
        println!("  {} ALL PER-CLASS DELTA IDENTITIES CERTIFIED", fmt::check(true));
    } else {
        println!("  {} SOME PER-CLASS CHECKS FAILED", fmt::check(false));
    }
    println!("  Max |Δ_diff - Δ_formula|: {:.4e}", max_delta);
    println!("  Max |strip + Σ actual - formula|: {:.4e}", max_formula);
    println!();
}
