//! Output formatting and result serialization.
//!
//! Handles the Cathedral RL banner, single-run result cards,
//! sweep tables, and JSON serialization.

use serde::Serialize;
use std::io::Write;

// ═══════════════════════════════════════════════════════════════
// ANSI COLOR CONSTANTS
// ═══════════════════════════════════════════════════════════════

pub const BOLD: &str = "\x1b[1m";
pub const DIM: &str = "\x1b[2m";
pub const CYAN: &str = "\x1b[36m";
pub const GREEN: &str = "\x1b[32m";
pub const YELLOW: &str = "\x1b[33m";
pub const RED: &str = "\x1b[31m";
pub const MAGENTA: &str = "\x1b[35m";
pub const WHITE: &str = "\x1b[97m";
pub const RESET: &str = "\x1b[0m";

// ═══════════════════════════════════════════════════════════════
// RUN RESULT
// ═══════════════════════════════════════════════════════════════

/// Complete result of a single RL optimization run.
#[derive(Debug, Clone, Serialize)]
pub struct RunResult {
    pub n: usize,
    pub dim: usize,
    pub agent: String,
    pub baseline_d2: f64,
    pub baseline_vtgv: f64,
    pub baseline_btv: f64,
    pub optimal_d2: f64,
    pub optimal_vtgv: f64,
    pub optimal_btv: f64,
    pub improvement: f64,
    pub improvement_pct: f64,
    pub gram_bound_satisfied: bool,
    pub total_steps: usize,
    pub wall_time_s: f64,
    /// Effective K in vᵀGv ≤ 1 + K/ln(N)
    pub k_eff: f64,
    /// ln(N) for reference
    pub ln_n: f64,
    /// Matvec throughput (matvecs/sec)
    pub matvec_rate: f64,
}

// ═══════════════════════════════════════════════════════════════
// DISPLAY FUNCTIONS
// ═══════════════════════════════════════════════════════════════

/// Print the Cathedral RL startup banner.
pub fn print_banner() {
    println!();
    println!("  {BOLD}{CYAN}╔═══════════════════════════════════════════════════════════════════════╗{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}{WHITE}CATHEDRAL RL — Gram Form Optimization Engine{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {DIM}The Riemann Hypothesis, reduced to a matrix inequality:{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {DIM}  Show that vᵀG_N v ≤ 1 + K/ln(N){RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {DIM}  for the Möbius-weighted witness vector v.{RESET}");
    println!("  {BOLD}{CYAN}╚═══════════════════════════════════════════════════════════════════════╝{RESET}");
    println!();
}

/// Print the single-run result card.
pub fn print_single_result(r: &RunResult) {
    println!();
    println!("  {BOLD}{CYAN}  ┌───────────────────────────────────────────────────────────────┐{RESET}");
    println!("  {BOLD}{CYAN}  │{RESET}  {BOLD}{WHITE}CATHEDRAL RL RESULT — N={}{RESET}", r.n);
    println!("  {BOLD}{CYAN}  ├───────────────────────────────────────────────────────────────┤{RESET}");
    println!("  {BOLD}{CYAN}  │{RESET}  Agent:          {}", r.agent.to_uppercase());
    println!("  {BOLD}{CYAN}  │{RESET}  Dimension:      {} × {}", r.dim, r.dim);
    println!("  {BOLD}{CYAN}  │{RESET}  Total steps:    {}", r.total_steps);
    println!("  {BOLD}{CYAN}  │{RESET}  Wall time:      {:.1}s", r.wall_time_s);
    println!("  {BOLD}{CYAN}  ├───────────────────────────────────────────────────────────────┤{RESET}");
    println!("  {BOLD}{CYAN}  │{RESET}  {BOLD}Baseline (log-cutoff witness):{RESET}");
    println!("  {BOLD}{CYAN}  │{RESET}    d²    = {:.10e}", r.baseline_d2);
    println!("  {BOLD}{CYAN}  │{RESET}    vᵀGv  = {:.10}", r.baseline_vtgv);
    println!("  {BOLD}{CYAN}  │{RESET}    bᵀv   = {:.10}", r.baseline_btv);
    println!("  {BOLD}{CYAN}  │{RESET}  {BOLD}Optimized:{RESET}");
    println!("  {BOLD}{CYAN}  │{RESET}    d²    = {:.10e}", r.optimal_d2);
    println!("  {BOLD}{CYAN}  │{RESET}    vᵀGv  = {:.10}", r.optimal_vtgv);
    println!("  {BOLD}{CYAN}  │{RESET}    bᵀv   = {:.10}", r.optimal_btv);
    println!("  {BOLD}{CYAN}  ├───────────────────────────────────────────────────────────────┤{RESET}");

    if r.optimal_vtgv < 1.0 {
        println!("  {BOLD}{CYAN}  │{RESET}  {GREEN}✓ vᵀGv < 1 — GRAM BOUND TRIVIALLY SATISFIED{RESET}");
        println!("  {BOLD}{CYAN}  │{RESET}  {GREEN}  K_eff = {:.4} (negative — subcritical){RESET}", r.k_eff);
    } else if r.gram_bound_satisfied {
        println!("  {BOLD}{CYAN}  │{RESET}  {GREEN}✓ GRAM BOUND SATISFIED (K=1){RESET}");
        println!("  {BOLD}{CYAN}  │{RESET}  {GREEN}  K_eff = {:.4}{RESET}", r.k_eff);
    } else {
        println!("  {BOLD}{CYAN}  │{RESET}  {YELLOW}⚠ vᵀGv > 1 + 1/ln(N){RESET}");
        println!("  {BOLD}{CYAN}  │{RESET}  {YELLOW}  K_eff = {:.4} (needs K > {:.1} in axiom){RESET}", r.k_eff, r.k_eff);
    }

    println!("  {BOLD}{CYAN}  │{RESET}  Improvement:    {:.6e} ({:.2}%)", r.improvement, r.improvement_pct);
    println!("  {BOLD}{CYAN}  │{RESET}  Matvec rate:    {:.0} mv/s", r.matvec_rate);
    println!("  {BOLD}{CYAN}  │{RESET}  ln(N):          {:.4}", r.ln_n);
    println!("  {BOLD}{CYAN}  └───────────────────────────────────────────────────────────────┘{RESET}");
    println!();
}

/// Print the sweep summary table row.
pub fn print_sweep_row(result: &RunResult) {
    let bound_marker = if result.gram_bound_satisfied {
        format!("{GREEN}  ✓  {RESET}")
    } else if result.optimal_vtgv < 1.0 {
        format!("{GREEN} ✓✓  {RESET}")
    } else {
        format!("{RED}  ✗  {RESET}")
    };

    println!(
        "  {DIM}  │{RESET} {:>8} {DIM}│{RESET} {:>6} {DIM}│{RESET} {:>16.10e} {DIM}│{RESET} {:>16.10e} {DIM}│{RESET} {:>16.10} {DIM}│{RESET} {:>8.3} {DIM}│{RESET}{}{DIM}│{RESET}",
        result.n, result.dim, result.baseline_d2, result.optimal_d2,
        result.optimal_vtgv, result.k_eff, bound_marker,
    );
}

/// Print the sweep table header.
pub fn print_sweep_header() {
    println!("  {DIM}  ┌──────────┬────────┬──────────────────┬──────────────────┬──────────────────┬──────────┬────────┐{RESET}");
    println!("  {DIM}  │    N     │  dim   │   baseline d²    │   optimal d²     │      vᵀGv        │  K_eff   │ bound? │{RESET}");
    println!("  {DIM}  ├──────────┼────────┼──────────────────┼──────────────────┼──────────────────┼──────────┼────────┤{RESET}");
}

/// Print the sweep table footer and summary.
pub fn print_sweep_summary(results: &[RunResult]) {
    println!("  {DIM}  └──────────┴────────┴──────────────────┴──────────────────┴──────────────────┴──────────┴────────┘{RESET}");
    println!();

    let all_satisfied = results.iter().all(|r| r.gram_bound_satisfied);
    let all_vtgv_lt_1 = results.iter().all(|r| r.optimal_vtgv < 1.0);
    let best = results.iter().min_by(|a, b| a.optimal_d2.partial_cmp(&b.optimal_d2).unwrap());
    let worst = results.iter().max_by(|a, b| a.optimal_vtgv.partial_cmp(&b.optimal_vtgv).unwrap());

    println!("  {BOLD}{CYAN}  ┌───────────────────────────────────────────────────────────────┐{RESET}");
    println!("  {BOLD}{CYAN}  │{RESET}  {BOLD}{WHITE}CATHEDRAL RL SWEEP RESULTS{RESET}");
    println!("  {BOLD}{CYAN}  ├───────────────────────────────────────────────────────────────┤{RESET}");
    println!("  {BOLD}{CYAN}  │{RESET}  HC numbers tested:  {}", results.len());
    if let Some(best) = best {
        println!("  {BOLD}{CYAN}  │{RESET}  Best d²:           {:.10e}  (N={})", best.optimal_d2, best.n);
    }
    if let Some(worst) = worst {
        println!("  {BOLD}{CYAN}  │{RESET}  Worst vᵀGv:        {:.10}  (N={})", worst.optimal_vtgv, worst.n);
    }
    println!("  {BOLD}{CYAN}  │{RESET}  All vᵀGv < 1:      {}", if all_vtgv_lt_1 {
        format!("{GREEN}YES ✓{RESET}")
    } else {
        format!("{YELLOW}NO{RESET}")
    });
    println!("  {BOLD}{CYAN}  │{RESET}  Gram bound (K=1):  {}", if all_satisfied {
        format!("{GREEN}ALL SATISFIED ✓{RESET}")
    } else {
        format!("{YELLOW}SOME VIOLATIONS{RESET}")
    });
    println!("  {BOLD}{CYAN}  └───────────────────────────────────────────────────────────────┘{RESET}");
    println!();
}

// ═══════════════════════════════════════════════════════════════
// SERIALIZATION
// ═══════════════════════════════════════════════════════════════

/// Write any Serialize-able data to a JSON file.
pub fn write_json<T: Serialize>(path: &str, data: &T) {
    match serde_json::to_string_pretty(data) {
        Ok(json) => {
            if let Ok(mut f) = std::fs::File::create(path) {
                f.write_all(json.as_bytes()).ok();
                println!("  {GREEN}✓{RESET} Results written to {path}");
            }
        }
        Err(e) => eprintln!("  {RED}✗{RESET} Failed to serialize results: {e}"),
    }
}
