//! ═══════════════════════════════════════════════════════════════════════════
//!  CATHEDRAL GRAM SCALING ORACLE v2
//!  Algebraic Autopsy · GCD-Class Decomposition · Cross-N Scaling
//!
//!  "You open the 107 GB binary file. You reverse-engineer the α≈0.855
//!   scaling limit strictly using the algebraic, rational properties
//!   of the Gram matrix. You bypass the complex plane entirely."
//!                                      — Gemini Actual, May 4 2026
//!
//!  MODES:
//!    1. Block decomposition: GCD-class analysis at a single N
//!    2. Cross-N sweep: compute λ_min(G_N) for multiple cached N values
//!       and fit the true global scaling exponent
//!
//!  PARALLELISM:
//!    - Small blocks (dim ≤ 1000): parallel via rayon (many cores, small tasks)
//!    - Large blocks (dim > 1000): sequential, LAPACK uses all cores internally
//!    - dsyevr for λ_min only: orders of magnitude faster than full decomp
//!
//!  Hardware: Apple M2 Max, 96 GB RAM, 12 cores
//! ═══════════════════════════════════════════════════════════════════════════

mod alpha_fit;
mod block_spectrum;
mod certificate;
mod gcd_decomp;

use cathedral_utils::cache;
use cathedral_utils::fmt::*;
use cathedral_utils::gram::GramMatrix;
use std::time::Instant;

// ═══════════════════════════════════════════════════════════════
// CONFIGURATION
// ═══════════════════════════════════════════════════════════════

/// Maximum block dimension for eigendecomposition.
const MAX_EIGEN_DIM: usize = 5_000;

/// N values for cross-N sweep (ascending).
/// Must have cached matrices available.
const CROSS_N_SCHEDULE: &[usize] = &[100, 200, 500, 1000, 2000, 5000, 10000, 20000, 40000];

#[allow(dead_code)]
/// Try to load a cached Gram matrix. Returns (data, dim).
fn load_cached_gram(max_n: usize) -> Option<(Vec<f64>, usize)> {
    // Try DD cache first
    let dd_path = cache::dd_gram_cache_path(max_n, 256);
    if dd_path.exists() {
        if let Some((hi, _lo, dim)) = cache::load_dd_gram(&dd_path) {
            return Some((hi, dim));
        }
    }
    // Try standard cache
    for prec in [256u32, 512, 128, 106, 0] {
        let path = cache::gram_cache_path(max_n, prec);
        if path.exists() {
            if let Some(gm) = cache::load_gram(&path) {
                return Some((gm.data, gm.max_dim));
            }
        }
    }
    None
}

/// Build a Gram matrix from scratch.
fn build_gram(max_n: usize) -> (Vec<f64>, usize) {
    let gm = GramMatrix::build(max_n, None);
    (gm.data, gm.max_dim)
}

/// Load or build a Gram matrix.
fn get_gram(max_n: usize) -> (Vec<f64>, usize) {
    if let Some(cached) = load_cached_gram(max_n) {
        cached
    } else {
        build_gram(max_n)
    }
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let max_n: usize = args.get(1).and_then(|s| s.parse().ok()).unwrap_or(200);
    let max_eigen_dim: usize = args
        .get(2)
        .and_then(|s| s.parse().ok())
        .unwrap_or(MAX_EIGEN_DIM);

    println!();
    println!("  {BOLD}{CYAN}╔═══════════════════════════════════════════════════════════════════════╗{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}{WHITE}CATHEDRAL GRAM SCALING ORACLE v2{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  Algebraic Autopsy · Cross-N Scaling · LAPACK Accelerated");
    println!("  {BOLD}{CYAN}║{RESET}  N = {max_n}  ·  max eigen dim = {max_eigen_dim}  ·  dsyevr + dsyevd");
    println!("  {BOLD}{CYAN}╚═══════════════════════════════════════════════════════════════════════╝{RESET}");
    println!();

    let t_total = Instant::now();

    // ═══════════════════════════════════════════════════════════════
    // §1. CROSS-N SWEEP — TRUE GLOBAL α
    //
    // Compute λ_min(G_N) for multiple N values using cached matrices.
    // This gives the TRUE scaling because we measure the actual minimum
    // eigenvalue of the full matrix at each N.
    // ═══════════════════════════════════════════════════════════════
    println!("  {BOLD}{MAGENTA}§1{RESET}  {BOLD}Cross-N Sweep — True Global λ_min(G_N) ...{RESET}");

    // Determine which N values to sweep (up to our target N)
    let sweep_ns: Vec<usize> = CROSS_N_SCHEDULE
        .iter()
        .filter(|&&n| n <= max_n)
        .cloned()
        .collect();

    let mut cross_n_data: Vec<(usize, f64)> = Vec::new();

    println!("  {DIM}     Schedule: {:?}{RESET}", sweep_ns);
    println!();

    for &n in &sweep_ns {
        let t0 = Instant::now();
        eprint!("  {DIM}     N={n:<6} → loading...{RESET}");

        let (data, dim) = get_gram(n);
        let load_time = t0.elapsed().as_secs_f64();

        eprint!("\r  {DIM}     N={n:<6} ({dim}×{dim}, {:.1}s load) → computing λ_min via dsyevr...{RESET}          ",
                load_time);

        let t1 = Instant::now();
        let lmin = block_spectrum::full_matrix_lambda_min(&data, dim);
        let eigen_time = t1.elapsed().as_secs_f64();

        eprintln!("\r  {GREEN}✓{RESET} N={n:<6} dim={dim:<6} λ_min = {lmin:<20.12e}  ({load_time:.1}s load + {eigen_time:.1}s eigen)          ");

        cross_n_data.push((n, lmin));

        // Free memory immediately for large matrices
        drop(data);
    }
    println!();

    // Fit the cross-N scaling
    println!("  {BOLD}  Cross-N Scaling Fit:{RESET}");
    let cross_ns: Vec<f64> = cross_n_data.iter().map(|&(n, _)| n as f64).collect();
    let cross_lmins: Vec<f64> = cross_n_data.iter().map(|&(_, lm)| lm).collect();

    let (_, alpha_power, r2_power) = if cross_ns.len() >= 3 {
        cathedral_utils::fitting::power_law_fit(&cross_ns, &cross_lmins)
    } else {
        (0.0, 0.0, 0.0)
    };

    let (_, alpha_log, r2_log) = if cross_ns.len() >= 3 {
        cathedral_utils::fitting::log_decay_fit(&cross_ns, &cross_lmins)
    } else {
        (0.0, 0.0, 0.0)
    };

    println!("    Power law:  λ_min(G_N) ~ c · N^(-{alpha_power:.4})   R² = {r2_power:.6}");
    println!("    Log decay:  λ_min(G_N) ~ c / (ln N)^{alpha_log:.4}    R² = {r2_log:.6}");
    println!("    Target α:   0.855 (Three-Circles prediction)");
    if r2_log > r2_power {
        println!("    {GREEN}→ Log-decay model fits better{RESET}");
    } else {
        println!("    {GREEN}→ Power-law model fits better{RESET}");
    }
    println!();

    // ═══════════════════════════════════════════════════════════════
    // §2. LOAD PRIMARY MATRIX + GCD DECOMPOSITION
    // ═══════════════════════════════════════════════════════════════
    println!("  {BOLD}{MAGENTA}§2{RESET}  {BOLD}Loading Primary Matrix G_{max_n} ...{RESET}");
    let t0 = Instant::now();
    let (data, dim) = get_gram(max_n);
    let mem_gb = (data.len() * 8) as f64 / (1024.0 * 1024.0 * 1024.0);
    println!(
        "  {DIM}     {dim}×{dim} ({mem_gb:.2} GB) in {:.2}s{RESET}",
        t0.elapsed().as_secs_f64()
    );

    let t0 = Instant::now();
    let decomp = gcd_decomp::decompose(max_n);
    println!(
        "  {DIM}     {}/{} GCD classes in {:.2}s{RESET}",
        decomp.classes.len(),
        max_n,
        t0.elapsed().as_secs_f64()
    );

    let eigen_eligible: usize = decomp
        .classes
        .values()
        .filter(|indices| {
            let valid = indices
                .iter()
                .filter(|&&j| j >= 2 && j <= max_n && (j - 2) < dim)
                .count();
            valid >= 2 && valid <= max_eigen_dim
        })
        .count();
    println!("  {DIM}     Blocks for eigendecomp: {eigen_eligible}{RESET}");
    println!();

    // ═══════════════════════════════════════════════════════════════
    // §3. BLOCK SPECTRAL ANALYSIS
    // ═══════════════════════════════════════════════════════════════
    println!(
        "  {BOLD}{MAGENTA}§3{RESET}  {BOLD}Block Spectral Analysis (hybrid parallel) ...{RESET}"
    );
    let t0 = Instant::now();
    let block_results =
        block_spectrum::analyze_blocks_raw(&data, dim, &decomp, max_n, max_eigen_dim);
    println!(
        "  {DIM}     Analyzed {} blocks in {:.2}s{RESET}",
        block_results.len(),
        t0.elapsed().as_secs_f64()
    );
    println!();

    // Display top blocks
    println!("  {BOLD}  Block eigenvalue summary:{RESET}");
    println!("  {DIM}  ┌──────┬──────┬──────────────┬──────────────┬──────────────┐{RESET}");
    println!("  {DIM}  │ gcd  │ dim  │   λ_min      │   λ_max      │  condition   │{RESET}");
    println!("  {DIM}  ├──────┼──────┼──────────────┼──────────────┼──────────────┤{RESET}");
    for br in block_results.iter().take(20) {
        let cond = if br.lambda_min > 1e-15 {
            br.lambda_max / br.lambda_min
        } else {
            f64::INFINITY
        };
        println!("  {DIM}  │{RESET} {:<4} {DIM}│{RESET} {:<4} {DIM}│{RESET} {:>12.6e} {DIM}│{RESET} {:>12.6e} {DIM}│{RESET} {:>12.2e} {DIM}│{RESET}",
                 br.gcd_class, br.dim, br.lambda_min, br.lambda_max, cond);
    }
    if block_results.len() > 20 {
        println!("  {DIM}  │ ...  │ ...  │   ...        │   ...        │   ...        │{RESET}");
    }
    println!("  {DIM}  └──────┴──────┴──────────────┴──────────────┴──────────────┘{RESET}");
    println!();

    // ═══════════════════════════════════════════════════════════════
    // §4. α EXTRACTION (block-level)
    // ═══════════════════════════════════════════════════════════════
    println!("  {BOLD}{MAGENTA}§4{RESET}  {BOLD}Block-Level α Extraction ...{RESET}");
    let alpha_results = alpha_fit::extract_alpha(&block_results, max_n);

    // ═══════════════════════════════════════════════════════════════
    // §5. MASTER RESULTS
    // ═══════════════════════════════════════════════════════════════
    println!();
    println!(
        "  {BOLD}{CYAN}  ┌───────────────────────────────────────────────────────────────┐{RESET}"
    );
    println!("  {BOLD}{CYAN}  │{RESET}  {BOLD}{WHITE}SCALING ORACLE — MASTER RESULTS{RESET}                             {BOLD}{CYAN}│{RESET}");
    println!(
        "  {BOLD}{CYAN}  ├───────────────────────────────────────────────────────────────┤{RESET}"
    );
    println!("  {BOLD}{CYAN}  │{RESET}  {BOLD}CROSS-N SCALING (TRUE GLOBAL):{RESET}                              {BOLD}{CYAN}│{RESET}");
    println!(
        "  {BOLD}{CYAN}  │{RESET}    N range:         {:?}{:<20}{BOLD}{CYAN}│{RESET}",
        *sweep_ns.first().unwrap_or(&0),
        format!("..{}", sweep_ns.last().unwrap_or(&0))
    );
    println!("  {BOLD}{CYAN}  │{RESET}    {BOLD}{YELLOW}α (power law):   {alpha_power:<12.6}{RESET}  R² = {r2_power:.6}          {BOLD}{CYAN}│{RESET}");
    println!("  {BOLD}{CYAN}  │{RESET}    {BOLD}{YELLOW}α (log decay):   {alpha_log:<12.6}{RESET}  R² = {r2_log:.6}          {BOLD}{CYAN}│{RESET}");
    println!("  {BOLD}{CYAN}  │{RESET}                                                            {BOLD}{CYAN}│{RESET}");
    println!("  {BOLD}{CYAN}  │{RESET}  {BOLD}BLOCK-LEVEL SCALING:{RESET}                                       {BOLD}{CYAN}│{RESET}");
    println!("  {BOLD}{CYAN}  │{RESET}    Blocks analyzed: {:<10}                              {BOLD}{CYAN}│{RESET}", block_results.len());
    println!("  {BOLD}{CYAN}  │{RESET}    α (power law):   {:<12.6}  R² = {:.6}          {BOLD}{CYAN}│{RESET}",
             alpha_results.alpha_power, alpha_results.r2_power);
    println!("  {BOLD}{CYAN}  │{RESET}    α (log decay):   {:<12.6}  R² = {:.6}          {BOLD}{CYAN}│{RESET}",
             alpha_results.alpha_log, alpha_results.r2_log);
    println!("  {BOLD}{CYAN}  │{RESET}                                                            {BOLD}{CYAN}│{RESET}");
    println!("  {BOLD}{CYAN}  │{RESET}  {BOLD}TARGET:{RESET} α ≈ 0.855 (Three-Circles / Parseval Mirror)        {BOLD}{CYAN}│{RESET}");
    println!(
        "  {BOLD}{CYAN}  └───────────────────────────────────────────────────────────────┘{RESET}"
    );
    println!();

    // Cross-N data table
    println!("  {BOLD}  Cross-N λ_min data:{RESET}");
    println!("  {DIM}  ┌──────────┬──────────────────────┬────────────┐{RESET}");
    println!("  {DIM}  │    N     │      λ_min(G_N)      │   ln(N)    │{RESET}");
    println!("  {DIM}  ├──────────┼──────────────────────┼────────────┤{RESET}");
    for &(n, lm) in &cross_n_data {
        println!("  {DIM}  │{RESET} {n:>8} {DIM}│{RESET} {lm:>20.12e} {DIM}│{RESET} {:<10.4} {DIM}│{RESET}",
                 (n as f64).ln());
    }
    println!("  {DIM}  └──────────┴──────────────────────┴────────────┘{RESET}");
    println!();

    // ═══════════════════════════════════════════════════════════════
    // §6. CERTIFIED OUTPUT
    // ═══════════════════════════════════════════════════════════════
    println!("  {BOLD}{MAGENTA}§6{RESET}  {BOLD}Writing Certified Results ...{RESET}");
    certificate::write_all(max_n, &decomp, &block_results, &alpha_results);

    // Write cross-N data
    certificate::write_cross_n(
        max_n,
        &cross_n_data,
        alpha_power,
        r2_power,
        alpha_log,
        r2_log,
    );

    let elapsed = t_total.elapsed().as_secs_f64();
    println!();
    println!("  {BOLD}{GREEN}  ══════════════════════════════════════════════════════{RESET}");
    println!("  {BOLD}{GREEN}  ORACLE COMPLETE{RESET}  ·  N = {max_n}  ·  {elapsed:.1}s total");
    println!("  {BOLD}{GREEN}  ══════════════════════════════════════════════════════{RESET}");
    println!();
}
