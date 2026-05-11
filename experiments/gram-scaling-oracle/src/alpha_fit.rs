//! ═══════════════════════════════════════════════════════════════════════════
//!  α EXTRACTION — SCALING EXPONENT FITS
//!
//!  The key question: does the eigenvalue decay of the Gram matrix follow
//!  a sub-logarithmic law with exponent α ≈ 0.855?
//!
//!  We fit multiple models:
//!    1. Power law:   λ_min(G_N) ~ c · N^(-α_power)
//!    2. Log decay:   λ_min(G_N) ~ c / (ln N)^β
//!    3. Sub-log:     λ_min(G_N) ~ c / (ln N)^α  with α < 1
//!
//!  And compare the extracted α to the Three-Circles prediction:
//!    α = log(R₂) / log(R₃) ≈ 0.855  (for ε = 0.5)
//! ═══════════════════════════════════════════════════════════════════════════

use cathedral_utils::fitting;
use cathedral_utils::fmt::*;
use crate::block_spectrum::BlockSpectralResult;

/// Results from α extraction.
#[derive(Debug, Clone)]
pub struct AlphaResults {
    /// Global minimum eigenvalue of the full matrix.
    pub global_lambda_min: f64,
    /// α from power-law fit on block λ_min vs block dimension.
    pub alpha_power: f64,
    /// R² of power-law fit.
    pub r2_power: f64,
    /// β from log-decay fit.
    pub alpha_log: f64,
    /// R² of log-decay fit.
    pub r2_log: f64,
    /// Per-block scaling data: (d, dim, λ_min).
    pub block_scaling: Vec<(usize, usize, f64)>,
    /// Cross-N scaling data for multi-N analysis: (N, λ_min(G_N)).
    pub cross_n_scaling: Vec<(usize, f64)>,
}

/// Extract the scaling exponent α from block spectral results.
///
/// Strategy: use the coprime class (d=1) blocks at different effective N
/// to track how λ_min scales. Also fit across all block sizes.
pub fn extract_alpha(
    block_results: &[BlockSpectralResult],
    _max_n: usize,
) -> AlphaResults {
    // Global λ_min is from the d=1 class (full matrix equivalent)
    let global_lambda_min = block_results
        .iter()
        .find(|r| r.gcd_class == 1)
        .map(|r| r.lambda_min)
        .unwrap_or(0.0);

    // Collect (dim, λ_min) pairs for blocks with dim >= 3
    let block_scaling: Vec<(usize, usize, f64)> = block_results
        .iter()
        .filter(|r| r.dim >= 3 && r.lambda_min > 0.0)
        .map(|r| (r.gcd_class, r.dim, r.lambda_min))
        .collect();

    // Power-law fit: λ_min ~ c · dim^(-α)
    let ns: Vec<f64> = block_scaling.iter().map(|&(_, d, _)| d as f64).collect();
    let vals: Vec<f64> = block_scaling.iter().map(|&(_, _, lm)| lm).collect();

    let (_, alpha_power, r2_power) = if ns.len() >= 3 {
        fitting::power_law_fit(&ns, &vals)
    } else {
        (0.0, 0.0, 0.0)
    };

    // Log-decay fit: λ_min ~ c / (ln dim)^β
    let (_, alpha_log, r2_log) = if ns.len() >= 3 {
        fitting::log_decay_fit(&ns, &vals)
    } else {
        (0.0, 0.0, 0.0)
    };

    // Also do a multi-N analysis using block dimensions as "effective N"
    // The d=1 block has dim = N, d=2 has dim = N/2, d=3 has dim = N/3, etc.
    // So the block at d gives us "N_eff = N/d" with its own λ_min.
    let cross_n_scaling: Vec<(usize, f64)> = block_results
        .iter()
        .filter(|r| r.dim >= 3 && r.lambda_min > 0.0)
        .map(|r| (r.dim, r.lambda_min))
        .collect();

    println!("  {BOLD}  Scaling fits:{RESET}");
    println!("    Power law:  λ_min ~ c · dim^(-{:.4})   R² = {:.4}", alpha_power, r2_power);
    println!("    Log decay:  λ_min ~ c / (ln dim)^{:.4}  R² = {:.4}", alpha_log, r2_log);
    println!("    Target α:   0.855 (Three-Circles prediction)");
    if r2_log > r2_power {
        println!("    {GREEN}→ Log-decay model fits better (R² = {:.4} > {:.4}){RESET}", r2_log, r2_power);
    } else {
        println!("    {YELLOW}→ Power-law model fits better (R² = {:.4} > {:.4}){RESET}", r2_power, r2_log);
    }

    AlphaResults {
        global_lambda_min,
        alpha_power,
        r2_power,
        alpha_log,
        r2_log,
        block_scaling,
        cross_n_scaling,
    }
}

// Terminal colors (same as main.rs)
