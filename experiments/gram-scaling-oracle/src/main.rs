//! ═══════════════════════════════════════════════════════════════════════════
//!  CATHEDRAL GRAM SCALING ORACLE v1
//!  Algebraic Autopsy · GCD-Class Decomposition · Spectral Structure
//!
//!  "You open the 107 GB binary file. You reverse-engineer the α≈0.855
//!   scaling limit strictly using the algebraic, rational properties
//!   of the Gram matrix. You bypass the complex plane entirely."
//!                                      — Gemini Actual, May 4 2026
//!
//!  Architecture:
//!    gcd_decomp.rs    — GCD-class block decomposition of G_N
//!    block_spectrum.rs — Eigenvalue analysis within coprimality blocks
//!    alpha_fit.rs      — α extraction from cross-block scaling
//!    certificate.rs    — JSON + TSV certified output
//!
//!  Scaling modes:
//!    N ≤ 500:    Build from scratch (f64 Gram, sub-second)
//!    N ≤ 5000:   Load/build standard cache, full eigendecomp
//!    N ≤ 40000:  Load DD cache, eigendecomp blocks with dim ≤ MAX_EIGEN_DIM
//!    N ≤ 120000: Load OOC cache, eigendecomp blocks with dim ≤ MAX_EIGEN_DIM
//!
//!  Hardware: Apple M2 Max, 96 GB RAM, 12 cores
//! ═══════════════════════════════════════════════════════════════════════════

mod alpha_fit;
mod block_spectrum;
mod certificate;
mod gcd_decomp;

use cathedral_utils::cache;
use cathedral_utils::gram::GramMatrix;
use nalgebra::DMatrix;
use std::time::Instant;

// ═══════════════════════════════════════════════════════════════
// CONFIGURATION
// ═══════════════════════════════════════════════════════════════

/// Maximum block dimension for full eigendecomposition.
/// nalgebra symmetric_eigen is O(n³) — dim=5000 takes ~30s, dim=10000 takes ~240s.
/// Beyond this, blocks are skipped for eigenvalue analysis.
const MAX_EIGEN_DIM: usize = 5_000;

// ═══════════════════════════════════════════════════════════════
// TERMINAL FORMATTING
// ═══════════════════════════════════════════════════════════════
const BOLD: &str = "\x1b[1m";
const DIM: &str = "\x1b[2m";
const CYAN: &str = "\x1b[36m";
const GREEN: &str = "\x1b[32m";
#[allow(dead_code)]
const YELLOW: &str = "\x1b[33m";
const MAGENTA: &str = "\x1b[35m";
const WHITE: &str = "\x1b[97m";
#[allow(dead_code)]
const RED: &str = "\x1b[31m";
const RESET: &str = "\x1b[0m";

/// Try to load a cached Gram matrix from disk.
/// Searches: dd_gram first (higher precision), then standard cache.
fn load_cached_gram(max_n: usize) -> Option<(Vec<f64>, usize)> {
    // Try DD cache first (dd_gram_N{max_n}_mpfr256.bin)
    let dd_path = cache::dd_gram_cache_path(max_n, 256);
    if dd_path.exists() {
        println!("  {DIM}     Loading DD cache: {}{RESET}", dd_path.display());
        if let Some((hi, _lo, dim)) = cache::load_dd_gram(&dd_path) {
            println!("  {GREEN}✓{RESET} DD Gram loaded ({dim}×{dim}, {} GB)",
                     (hi.len() * 8) / (1024 * 1024 * 1024));
            return Some((hi, dim));
        }
    }

    // Try standard cache (gram_N{max_n}_mpfr256.bin or similar)
    for prec in [256u32, 512, 128, 106, 0] {
        let path = cache::gram_cache_path(max_n, prec);
        if path.exists() {
            println!("  {DIM}     Loading cache: {}{RESET}", path.display());
            if let Some(gm) = cache::load_gram(&path) {
                let dim = gm.max_dim;
                return Some((gm.data, dim));
            }
        }
    }

    None
}

/// Build a Gram matrix from scratch (for small N).
fn build_gram(max_n: usize) -> (Vec<f64>, usize) {
    let gm = GramMatrix::build(max_n, None);
    let dim = gm.max_dim;
    (gm.data, dim)
}

/// Convert raw Vec<f64> storage to nalgebra DMatrix.
fn raw_to_nalgebra(data: &[f64], dim: usize) -> DMatrix<f64> {
    DMatrix::from_fn(dim, dim, |i, j| data[i * dim + j])
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let max_n: usize = args.get(1).and_then(|s| s.parse().ok()).unwrap_or(200);
    let max_eigen_dim: usize = args.get(2).and_then(|s| s.parse().ok()).unwrap_or(MAX_EIGEN_DIM);

    println!();
    println!("  {BOLD}{CYAN}╔═══════════════════════════════════════════════════════════════════════╗{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}{WHITE}CATHEDRAL GRAM SCALING ORACLE v1{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  Algebraic Autopsy · GCD-Class Decomposition · α Extraction");
    println!("  {BOLD}{CYAN}║{RESET}  N = {max_n}  ·  max eigen dim = {max_eigen_dim}  ·  rayon parallel");
    println!("  {BOLD}{CYAN}╚═══════════════════════════════════════════════════════════════════════╝{RESET}");
    println!();

    let t_total = Instant::now();

    // ═══════════════════════════════════════════════════════════════
    // §1. LOAD OR BUILD GRAM MATRIX
    // ═══════════════════════════════════════════════════════════════
    println!("  {BOLD}{MAGENTA}§1{RESET}  {BOLD}Loading Gram Matrix G_N ...{RESET}");
    let t0 = Instant::now();

    let (data, dim) = if let Some(cached) = load_cached_gram(max_n) {
        cached
    } else {
        println!("  {DIM}     No cache found, building from scratch ...{RESET}");
        build_gram(max_n)
    };

    let mem_gb = (data.len() * 8) as f64 / (1024.0 * 1024.0 * 1024.0);
    println!("  {DIM}     Matrix: {dim}×{dim} ({mem_gb:.2} GB) loaded in {:.2}s{RESET}",
             t0.elapsed().as_secs_f64());
    println!();

    // ═══════════════════════════════════════════════════════════════
    // §2. GCD-CLASS DECOMPOSITION
    // ═══════════════════════════════════════════════════════════════
    println!("  {BOLD}{MAGENTA}§2{RESET}  {BOLD}GCD-Class Decomposition ...{RESET}");
    let t0 = Instant::now();
    let decomp = gcd_decomp::decompose(max_n);
    println!("  {DIM}     Found {} GCD classes in {:.2}s{RESET}",
             decomp.classes.len(), t0.elapsed().as_secs_f64());

    // Count how many blocks are within eigen dim limit
    let eigen_eligible: usize = decomp.classes.values()
        .filter(|indices| {
            let valid = indices.iter().filter(|&&j| j >= 2 && j <= max_n).count();
            valid >= 2 && valid <= max_eigen_dim
        })
        .count();
    let skipped = decomp.classes.len() - eigen_eligible;
    println!("  {DIM}     Blocks eligible for eigendecomp: {eigen_eligible} (skipping {skipped} too large/small){RESET}");

    // Print the top classes by size
    let mut sorted_classes: Vec<_> = decomp.classes.iter().collect();
    sorted_classes.sort_by(|a, b| b.1.len().cmp(&a.1.len()));
    println!();
    println!("  {BOLD}  Top GCD classes by size:{RESET}");
    println!("  {DIM}  ┌──────┬──────────┬────────────┬──────────┐{RESET}");
    println!("  {DIM}  │ gcd  │   size   │ frac of N  │ eigen?   │{RESET}");
    println!("  {DIM}  ├──────┼──────────┼────────────┼──────────┤{RESET}");
    for (d, indices) in sorted_classes.iter().take(15) {
        let valid = indices.iter().filter(|&&j| j >= 2 && j <= max_n).count();
        let frac = indices.len() as f64 / max_n as f64;
        let eigen = if valid >= 2 && valid <= max_eigen_dim { format!("{GREEN}yes{RESET}") }
                    else { format!("{DIM}skip{RESET}") };
        println!("  {DIM}  │{RESET} {d:>4} {DIM}│{RESET} {:<8} {DIM}│{RESET} {:.4}     {DIM}│{RESET} {eigen}     {DIM}│{RESET}",
                 indices.len(), frac);
    }
    println!("  {DIM}  └──────┴──────────┴────────────┴──────────┘{RESET}");
    println!();

    // ═══════════════════════════════════════════════════════════════
    // §3. BLOCK SPECTRAL ANALYSIS
    // ═══════════════════════════════════════════════════════════════
    println!("  {BOLD}{MAGENTA}§3{RESET}  {BOLD}Block Spectral Analysis (max dim = {max_eigen_dim}) ...{RESET}");
    let t0 = Instant::now();
    let block_results = block_spectrum::analyze_blocks_raw(&data, dim, &decomp, max_n, max_eigen_dim);
    println!("  {DIM}     Analyzed {} blocks in {:.2}s{RESET}",
             block_results.len(), t0.elapsed().as_secs_f64());
    println!();

    // Display results
    println!("  {BOLD}  Block eigenvalue summary:{RESET}");
    println!("  {DIM}  ┌──────┬──────┬──────────────┬──────────────┬──────────────┐{RESET}");
    println!("  {DIM}  │ gcd  │ dim  │   λ_min      │   λ_max      │  condition   │{RESET}");
    println!("  {DIM}  ├──────┼──────┼──────────────┼──────────────┼──────────────┤{RESET}");
    for br in block_results.iter().take(25) {
        let cond = if br.lambda_min > 1e-15 { br.lambda_max / br.lambda_min } else { f64::INFINITY };
        println!("  {DIM}  │{RESET} {:<4} {DIM}│{RESET} {:<4} {DIM}│{RESET} {:>12.6e} {DIM}│{RESET} {:>12.6e} {DIM}│{RESET} {:>12.2e} {DIM}│{RESET}",
                 br.gcd_class, br.dim, br.lambda_min, br.lambda_max, cond);
    }
    if block_results.len() > 25 {
        println!("  {DIM}  │ ...  │ ...  │   ...        │   ...        │   ...        │{RESET}");
    }
    println!("  {DIM}  └──────┴──────┴──────────────┴──────────────┴──────────────┘{RESET}");
    println!();

    // ═══════════════════════════════════════════════════════════════
    // §4. CROSS-BLOCK α EXTRACTION
    // ═══════════════════════════════════════════════════════════════
    println!("  {BOLD}{MAGENTA}§4{RESET}  {BOLD}Cross-Block α Extraction ...{RESET}");
    let alpha_results = alpha_fit::extract_alpha(&block_results, max_n);

    println!();
    println!("  {BOLD}{CYAN}  ┌─────────────────────────────────────────────────────────┐{RESET}");
    println!("  {BOLD}{CYAN}  │{RESET}  {BOLD}{WHITE}SCALING ORACLE RESULTS{RESET}                                 {BOLD}{CYAN}│{RESET}");
    println!("  {BOLD}{CYAN}  ├─────────────────────────────────────────────────────────┤{RESET}");
    println!("  {BOLD}{CYAN}  │{RESET}  N = {max_n:<10}                                      {BOLD}{CYAN}│{RESET}");
    println!("  {BOLD}{CYAN}  │{RESET}  GCD classes:       {:<10}                       {BOLD}{CYAN}│{RESET}", decomp.classes.len());
    println!("  {BOLD}{CYAN}  │{RESET}  Blocks analyzed:   {:<10}                       {BOLD}{CYAN}│{RESET}", block_results.len());
    println!("  {BOLD}{CYAN}  │{RESET}  λ_min (smallest block): {:<16.12e}       {BOLD}{CYAN}│{RESET}", alpha_results.global_lambda_min);
    println!("  {BOLD}{CYAN}  │{RESET}  {BOLD}{YELLOW}α (power law):     {:<20.6}{RESET}           {BOLD}{CYAN}│{RESET}", alpha_results.alpha_power);
    println!("  {BOLD}{CYAN}  │{RESET}  {BOLD}{YELLOW}α (log decay):     {:<20.6}{RESET}           {BOLD}{CYAN}│{RESET}", alpha_results.alpha_log);
    println!("  {BOLD}{CYAN}  │{RESET}  R² (power law):    {:<20.6}           {BOLD}{CYAN}│{RESET}", alpha_results.r2_power);
    println!("  {BOLD}{CYAN}  │{RESET}  R² (log decay):    {:<20.6}           {BOLD}{CYAN}│{RESET}", alpha_results.r2_log);
    println!("  {BOLD}{CYAN}  │{RESET}  Target α:          0.855 (Three-Circles)             {BOLD}{CYAN}│{RESET}");
    println!("  {BOLD}{CYAN}  └─────────────────────────────────────────────────────────┘{RESET}");
    println!();

    // ═══════════════════════════════════════════════════════════════
    // §5. CERTIFIED OUTPUT
    // ═══════════════════════════════════════════════════════════════
    println!("  {BOLD}{MAGENTA}§5{RESET}  {BOLD}Writing Certified Results ...{RESET}");
    certificate::write_all(max_n, &decomp, &block_results, &alpha_results);

    let elapsed = t_total.elapsed().as_secs_f64();
    println!();
    println!("  {BOLD}{GREEN}  ══════════════════════════════════════════════════════{RESET}");
    println!("  {BOLD}{GREEN}  ORACLE COMPLETE{RESET}  ·  N = {max_n}  ·  {elapsed:.2}s total");
    println!("  {BOLD}{GREEN}  ══════════════════════════════════════════════════════{RESET}");
    println!();
}
