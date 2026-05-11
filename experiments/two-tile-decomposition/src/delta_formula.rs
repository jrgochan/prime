//! ═══════════════════════════════════════════════════════════════════════════
//!  EXACT DELTA FORMULA — Closed-form Δ(m) for two-tile corrections
//!
//!  For coprime (a,b) with a < b, the two-tile correction is:
//!
//!    Δ(m) = -(1/a)·log(a(m+1) / (a(m+1) - s)) + m·s / (a(m+1)·(a(m+1) - s))
//!
//!  where s = (am mod b) + a - b  (the "overshoot" — positive for two-tile rows)
//!
//!  DERIVATION:
//!    The crossing point is x_c = 1/(b(q+1)) where q = ⌊am/b⌋.
//!    rowTerm uses tile index q everywhere; the exact integral splits at x_c.
//!    Δ = [F_{q+1}(x_c) - F_q(x_c)] - [F_{q+1}(row_lo) - F_q(row_lo)]
//!    Since F_{n+1}(x) - F_n(x) = -(1/a)·log(x) + m·x, this simplifies to:
//!    Δ = -(1/a)·log(x_c/row_lo) + m·(x_c - row_lo)
//!    With x_c = 1/(a(m+1)-s) and row_lo = 1/(a(m+1)):
//!    Δ = -(1/a)·log(a(m+1)/(a(m+1)-s)) + m·s/(a(m+1)·(a(m+1)-s))
//! ═══════════════════════════════════════════════════════════════════════════

use crate::PREC;
use crate::compute::fu;
use rug::Float;

/// Compute the overshoot s = (am mod b) + a - b for row m.
/// Returns None if the row is single-tile (s ≤ 0).
#[inline]
pub fn overshoot(a: usize, b: usize, m: usize) -> Option<usize> {
    let r = (a * m) % b;
    if r + a >= b && r > 0 {
        Some(r + a - b)
    } else if r == 0 && a >= b {
        // Edge case: r=0 means b|am, but a < b by hypothesis, so single-tile
        None
    } else if r + a >= b && r == 0 {
        // r=0: am divisible by b, a < b → a(m+1) = am + a, no crossing
        None
    } else {
        None
    }
}

/// Compute Δ(m) using the exact closed-form formula.
///
/// Δ(m) = -(1/a)·log(a(m+1) / (a(m+1) - s)) + m·s / (a(m+1)·(a(m+1) - s))
///
/// Returns zero for single-tile rows.
pub fn delta_exact(a: usize, b: usize, m: usize) -> Float {
    let s = match overshoot(a, b, m) {
        Some(s) => s,
        None => return Float::with_val(PREC, 0),
    };

    let af = fu(a);
    let m1 = fu(m + 1);
    let sf = fu(s);

    // a(m+1)
    let am1 = Float::with_val(PREC, &af * &m1);
    // a(m+1) - s
    let am1_s = Float::with_val(PREC, &am1 - &sf);

    // log term: -(1/a) · log(a(m+1) / (a(m+1) - s))
    let ratio = Float::with_val(PREC, &am1 / &am1_s);
    let log_val = Float::with_val(PREC, ratio.ln());
    let log_term = Float::with_val(PREC, -Float::with_val(PREC, &log_val / &af));

    // linear term: m·s / (a(m+1) · (a(m+1) - s))
    let mf = fu(m);
    let num = Float::with_val(PREC, &mf * &sf);
    let den = Float::with_val(PREC, &am1 * &am1_s);
    let lin_term = Float::with_val(PREC, &num / &den);

    Float::with_val(PREC, &log_term + &lin_term)
}

/// Residue class info for a single (a,b) pair.
#[derive(Debug, Clone)]
pub struct ResidueClassResult {
    pub r: usize,
    pub s: usize,
    pub count: usize,
    pub sum_delta_exact: f64,
    pub sum_delta_numerical: f64,
    pub max_pointwise_error: f64,
}

/// Per-pair result from the delta formula certification.
#[derive(Debug, Clone)]
pub struct DeltaFormulaResult {
    pub a: usize,
    pub b: usize,
    pub max_pointwise_error: f64,
    pub total_delta_exact: f64,
    pub total_delta_numerical: f64,
    pub formula_vs_numerical_error: f64,
    pub residue_classes: Vec<ResidueClassResult>,
}

/// Certify the exact delta formula for a given coprime pair.
///
/// For each row m from 1 to max_m:
///   1. Compute Δ(m) via the exact formula
///   2. Compute Δ(m) via piecewise FTC (numerical)
///   3. Verify they match to machine precision
///   4. Accumulate by residue class
pub fn certify_delta_formula(a: usize, b: usize, max_m: usize) -> DeltaFormulaResult {
    let mut total_exact = Float::with_val(PREC, 0);
    let mut total_numerical = Float::with_val(PREC, 0);
    let mut max_error = Float::with_val(PREC, 0);

    // Residue class accumulators
    let mut class_exact: std::collections::HashMap<usize, Float> = std::collections::HashMap::new();
    let mut class_numerical: std::collections::HashMap<usize, Float> =
        std::collections::HashMap::new();
    let mut class_max_err: std::collections::HashMap<usize, Float> =
        std::collections::HashMap::new();
    let mut class_count: std::collections::HashMap<usize, usize> = std::collections::HashMap::new();

    for m in 1..=max_m {
        let r = (a * m) % b;
        let n_hi = (a * m) / b;
        let n_lo = (a * (m + 1)) / b;
        let is_two_tile = n_hi != n_lo;

        if !is_two_tile {
            continue;
        }

        // Exact formula
        let d_exact = delta_exact(a, b, m);

        // Numerical (piecewise FTC)
        let actual = crate::compute::exact_row_integral(a, b, m);
        let rt = crate::compute::row_term(a, b, m);
        let d_numerical = Float::with_val(PREC, &actual - &rt);

        // Error
        let err = Float::with_val(PREC, Float::with_val(PREC, &d_exact - &d_numerical).abs());
        if err > max_error {
            max_error = err.clone();
        }

        total_exact += &d_exact;
        total_numerical += &d_numerical;

        // Accumulate by residue class
        *class_exact
            .entry(r)
            .or_insert_with(|| Float::with_val(PREC, 0)) += &d_exact;
        *class_numerical
            .entry(r)
            .or_insert_with(|| Float::with_val(PREC, 0)) += &d_numerical;
        let e = class_max_err
            .entry(r)
            .or_insert_with(|| Float::with_val(PREC, 0));
        if err > *e {
            *e = err;
        }
        *class_count.entry(r).or_default() += 1;
    }

    let formula_err = Float::with_val(
        PREC,
        Float::with_val(PREC, &total_exact - &total_numerical).abs(),
    );

    let mut residue_classes: Vec<ResidueClassResult> = Vec::new();
    for r in 0..b {
        if let Some(count) = class_count.get(&r) {
            // Compute s from r directly
            let s = if r + a >= b && r > 0 { r + a - b } else { 0 };
            residue_classes.push(ResidueClassResult {
                r,
                s,
                count: *count,
                sum_delta_exact: class_exact.get(&r).map(|f| f.to_f64()).unwrap_or(0.0),
                sum_delta_numerical: class_numerical.get(&r).map(|f| f.to_f64()).unwrap_or(0.0),
                max_pointwise_error: class_max_err.get(&r).map(|f| f.to_f64()).unwrap_or(0.0),
            });
        }
    }

    DeltaFormulaResult {
        a,
        b,
        max_pointwise_error: max_error.to_f64(),
        total_delta_exact: total_exact.to_f64(),
        total_delta_numerical: total_numerical.to_f64(),
        formula_vs_numerical_error: formula_err.to_f64(),
        residue_classes,
    }
}

/// Print certification results for a set of pairs.
pub fn print_certification(results: &[DeltaFormulaResult]) {
    use cathedral_utils::fmt;

    fmt::section("DELTA FORMULA CERTIFICATION");
    println!();
    println!("  Verifying: Δ(m) = -(1/a)·log(a(m+1)/(a(m+1)-s)) + m·s/(a(m+1)·(a(m+1)-s))");
    println!();

    println!(
        "  {:>5} {:>5}  {:>16}  {:>16}  {:>14}  {:>8}",
        "(a", "b)", "Σ'Δ (formula)", "Σ'Δ (FTC)", "|error|", "classes"
    );
    println!("  {}", "─".repeat(80));

    let mut all_pass = true;
    for r in results {
        let pass = r.max_pointwise_error < 1e-40;
        if !pass {
            all_pass = false;
        }
        println!(
            "  ({:>2},{:>2})  {:>16.10e}  {:>16.10e}  {:>14.4e}  {:>4} cls  {}",
            r.a,
            r.b,
            r.total_delta_exact,
            r.total_delta_numerical,
            r.max_pointwise_error,
            r.residue_classes.len(),
            if pass {
                fmt::check(true)
            } else {
                fmt::check(false)
            },
        );

        // Print residue class detail
        for rc in &r.residue_classes {
            println!(
                "    {}r={}, s={}: Σ={:>14.10e}, count={}, max_err={:.2e}{}",
                fmt::DIM,
                rc.r,
                rc.s,
                rc.sum_delta_exact,
                rc.count,
                rc.max_pointwise_error,
                fmt::RESET
            );
        }
    }

    println!();
    if all_pass {
        println!(
            "  {} ALL DELTA FORMULA IDENTITIES CERTIFIED",
            fmt::check(true)
        );
        println!(
            "  {}Maximum pointwise |Δ_formula - Δ_FTC| < 10⁻⁴⁰{}",
            fmt::DIM,
            fmt::RESET
        );
    } else {
        println!("  {} SOME CERTIFICATIONS FAILED", fmt::check(false));
    }
    println!();
}
