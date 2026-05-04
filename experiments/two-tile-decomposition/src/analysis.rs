//! ═══════════════════════════════════════════════════════════════════════════
//!  Analysis — tail convergence, Σ'Δ exact values, result reporting
//! ═══════════════════════════════════════════════════════════════════════════

use cathedral_utils::fmt;
use serde::Serialize;

// ─────────────────────────────────────────────────────────────────────────
// RESULT STRUCT
// ─────────────────────────────────────────────────────────────────────────

/// Results for a single coprime pair (a,b).
#[derive(Debug, Clone, Serialize)]
pub struct PairResult {
    pub a: usize,
    pub b: usize,
    pub gram_integral: f64,
    pub gram_formula: f64,
    pub strip: f64,
    pub sum_actual: f64,
    pub sum_rowterm: f64,
    pub sum_delta: f64,
    pub stirling_over_b: f64,
    pub fract_target_over_a: f64,
    pub decomposition: f64,
    pub err_integral_vs_formula: f64,
    pub err_integral_vs_decomposition: f64,
    pub n_two_tile_rows: usize,
    pub time_ms: f64,
}

impl PairResult {
    /// Convert to JSON for certificate output.
    pub fn to_json(&self, max_m: usize) -> serde_json::Value {
        serde_json::json!({
            "a": self.a,
            "b": self.b,
            "gram_integral": self.gram_integral,
            "gram_formula": self.gram_formula,
            "strip": self.strip,
            "sum_actual": self.sum_actual,
            "sum_rowterm": self.sum_rowterm,
            "sum_delta": self.sum_delta,
            "stirling_over_b": self.stirling_over_b,
            "fract_target_over_a": self.fract_target_over_a,
            "decomposition": self.decomposition,
            "err_integral_vs_formula": self.err_integral_vs_formula,
            "err_integral_vs_decomposition": self.err_integral_vs_decomposition,
            "n_two_tile_rows": self.n_two_tile_rows,
            "time_ms": self.time_ms,
            "max_m": max_m,
        })
    }

    /// Convert to TSV row.
    pub fn to_tsv_row(&self) -> Vec<String> {
        vec![
            self.a.to_string(),
            self.b.to_string(),
            format!("{:.15}", self.gram_integral),
            format!("{:.15}", self.gram_formula),
            format!("{:.15}", self.strip),
            format!("{:.15}", self.sum_actual),
            format!("{:.15}", self.sum_rowterm),
            format!("{:.15}", self.sum_delta),
            format!("{:.15}", self.stirling_over_b),
            format!("{:.15}", self.fract_target_over_a),
            format!("{:.6e}", self.err_integral_vs_formula),
            format!("{:.6e}", self.err_integral_vs_decomposition),
            self.n_two_tile_rows.to_string(),
            format!("{:.1}", self.time_ms),
        ]
    }

    /// Compute the exact Σ'Δ value from the formula.
    /// exact = formula - strip - stirling/b - fractTarget/a
    pub fn sigma_delta_exact(&self) -> f64 {
        self.gram_formula - self.strip - self.stirling_over_b - self.fract_target_over_a
    }

    /// Compute the tail error: numeric - exact.
    pub fn tail_error(&self) -> f64 {
        self.sum_delta - self.sigma_delta_exact()
    }

    /// Predicted tail coefficient: C = (4a+1)(a-1)/(12a²b).
    /// The tail behaves as tail(M) ≈ -C/M.
    pub fn predicted_tail(&self, max_m: usize) -> f64 {
        let a = self.a as f64;
        let b = self.b as f64;
        let c = (4.0 * a + 1.0) * (a - 1.0) / (12.0 * a * a * b);
        -c / max_m as f64
    }
}

// ─────────────────────────────────────────────────────────────────────────
// TAIL CONVERGENCE ANALYSIS
// ─────────────────────────────────────────────────────────────────────────

/// Print tail convergence analysis to stdout.
pub fn print_tail_convergence(results: &[PairResult], max_m: usize) {
    fmt::section("TAIL CONVERGENCE LAW");
    println!();
    println!("  {}Predicted: tail(M) = -(4a+1)(a-1)/(12a²bM){}", fmt::DIM, fmt::RESET);
    println!();
    println!("  {:>8}  {:>14}  {:>14}  {:>10}  {:>6}",
        "(a,b)", "tail_actual", "tail_predicted", "ratio", "pass");
    println!("  {}", "─".repeat(66));

    let mut all_pass = true;
    for r in results {
        if r.a == 1 { continue; } // a=1 has zero Σ'Δ

        let tail_actual = r.tail_error();
        let tail_pred = r.predicted_tail(max_m);
        let ratio = if tail_pred.abs() > 1e-20 {
            tail_actual / tail_pred
        } else {
            f64::NAN
        };
        let pass = (ratio + 1.0).abs() < 0.01; // ratio should be ~-1.0
        if !pass { all_pass = false; }

        println!("  ({:>2},{:>2})  {:>14.6e}  {:>14.6e}  {:>10.4}  {}",
            r.a, r.b, tail_actual, tail_pred, ratio, fmt::check(pass));
    }

    println!();
    if all_pass {
        println!("  {}{}All tail ratios = -1.0000 ± 0.01 ✓{}",
            fmt::BOLD, fmt::GREEN, fmt::RESET);
    } else {
        println!("  {}{}WARNING: Some tail ratios deviate!{}",
            fmt::BOLD, fmt::RED, fmt::RESET);
    }
    println!();
}

/// Generate tail convergence rows for TSV output.
pub fn tail_convergence_rows(results: &[PairResult], max_m: usize) -> Vec<Vec<String>> {
    results.iter()
        .filter(|r| r.a > 1)
        .map(|r| {
            let tail = r.tail_error();
            let pred = r.predicted_tail(max_m);
            let ratio = if pred.abs() > 1e-20 { tail / pred } else { f64::NAN };
            vec![
                r.a.to_string(),
                r.b.to_string(),
                format!("{:.10}", r.sum_delta),
                format!("{:.10}", r.sigma_delta_exact()),
                format!("{:.6e}", tail),
                format!("{:.6e}", pred),
                format!("{:.4}", ratio),
            ]
        })
        .collect()
}

// ─────────────────────────────────────────────────────────────────────────
// Σ'Δ EXACT VALUES
// ─────────────────────────────────────────────────────────────────────────

/// Print Σ'Δ exact values grouped by a.
pub fn print_sigma_delta_exact(results: &[PairResult]) {
    fmt::section("Σ'Δ EXACT VALUES (from formula)");
    println!();
    println!("  {}SD_exact = formula - strip - stirling/b - fractTarget/a{}", fmt::DIM, fmt::RESET);
    println!();

    let mut last_a = 0;
    for r in results {
        if r.a == 1 { continue; }

        if r.a != last_a {
            if last_a != 0 { println!(); }
            println!("  {}a = {}:{}", fmt::BOLD, r.a, fmt::RESET);
            last_a = r.a;
        }

        let sd = r.sigma_delta_exact();
        println!("    b={}: Σ'Δ = {:>16.10}", r.b, sd);
    }
    println!();
}
