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
//!  Hardware: Apple M2 Max, 96 GB RAM, 12 cores
//! ═══════════════════════════════════════════════════════════════════════════

mod alpha_fit;
mod block_spectrum;
mod certificate;
mod gcd_decomp;

use cathedral_utils::gram::GramMatrix;
use nalgebra::DMatrix;
use std::time::Instant;

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

/// Convert a Cathedral GramMatrix to nalgebra DMatrix<f64>.
fn gram_to_nalgebra(gm: &GramMatrix) -> DMatrix<f64> {
    let dim = gm.max_dim;
    DMatrix::from_fn(dim, dim, |i, j| gm.data[i * dim + j])
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let max_n: usize = args.get(1).and_then(|s| s.parse().ok()).unwrap_or(200);

    println!();
    println!("  {BOLD}{CYAN}╔═══════════════════════════════════════════════════════════════════════╗{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}{WHITE}CATHEDRAL GRAM SCALING ORACLE v1{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  Algebraic Autopsy · GCD-Class Decomposition · α Extraction");
    println!("  {BOLD}{CYAN}║{RESET}  N = {max_n}  ·  Certified Results  ·  rayon parallel");
    println!("  {BOLD}{CYAN}╚═══════════════════════════════════════════════════════════════════════╝{RESET}");
    println!();

    let t_total = Instant::now();

    // ═══════════════════════════════════════════════════════════════
    // §1. BUILD GRAM MATRIX
    // ═══════════════════════════════════════════════════════════════
    println!("  {BOLD}{MAGENTA}§1{RESET}  {BOLD}Building Gram Matrix G_N ...{RESET}");
    let t0 = Instant::now();
    let gm = GramMatrix::build(max_n, None);
    let mat = gram_to_nalgebra(&gm);
    println!("  {DIM}     Built {max_n}×{max_n} Gram matrix ({} entries) in {:.2}s{RESET}",
             gm.max_dim * gm.max_dim, t0.elapsed().as_secs_f64());
    println!();

    // ═══════════════════════════════════════════════════════════════
    // §2. GCD-CLASS DECOMPOSITION
    // ═══════════════════════════════════════════════════════════════
    println!("  {BOLD}{MAGENTA}§2{RESET}  {BOLD}GCD-Class Decomposition ...{RESET}");
    let t0 = Instant::now();
    let decomp = gcd_decomp::decompose(max_n);
    println!("  {DIM}     Found {} GCD classes in {:.2}s{RESET}",
             decomp.classes.len(), t0.elapsed().as_secs_f64());

    // Print the top classes by size
    let mut sorted_classes: Vec<_> = decomp.classes.iter().collect();
    sorted_classes.sort_by(|a, b| b.1.len().cmp(&a.1.len()));
    println!();
    println!("  {BOLD}  Top GCD classes by size:{RESET}");
    println!("  {DIM}  ┌──────┬──────────┬───────────────────────────┐{RESET}");
    println!("  {DIM}  │ gcd  │   size   │ fraction of N             │{RESET}");
    println!("  {DIM}  ├──────┼──────────┼───────────────────────────┤{RESET}");
    for (d, indices) in sorted_classes.iter().take(15) {
        let frac = indices.len() as f64 / max_n as f64;
        println!("  {DIM}  │{RESET} {d:>4} {DIM}│{RESET} {:<8} {DIM}│{RESET} {:.4}                      {DIM}│{RESET}",
                 indices.len(), frac);
    }
    println!("  {DIM}  └──────┴──────────┴───────────────────────────┘{RESET}");
    println!();

    // ═══════════════════════════════════════════════════════════════
    // §3. BLOCK SPECTRAL ANALYSIS
    // ═══════════════════════════════════════════════════════════════
    println!("  {BOLD}{MAGENTA}§3{RESET}  {BOLD}Block Spectral Analysis ...{RESET}");
    let t0 = Instant::now();
    let block_results = block_spectrum::analyze_blocks(&mat, &decomp, max_n);
    println!("  {DIM}     Analyzed {} blocks in {:.2}s{RESET}",
             block_results.len(), t0.elapsed().as_secs_f64());
    println!();

    // Display results
    println!("  {BOLD}  Block eigenvalue summary:{RESET}");
    println!("  {DIM}  ┌──────┬──────┬──────────────┬──────────────┬──────────────┐{RESET}");
    println!("  {DIM}  │ gcd  │ dim  │   λ_min      │   λ_max      │  condition   │{RESET}");
    println!("  {DIM}  ├──────┼──────┼──────────────┼──────────────┼──────────────┤{RESET}");
    for br in block_results.iter().take(20) {
        let cond = if br.lambda_min > 1e-15 { br.lambda_max / br.lambda_min } else { f64::INFINITY };
        println!("  {DIM}  │{RESET} {:<4} {DIM}│{RESET} {:<4} {DIM}│{RESET} {:>12.6e} {DIM}│{RESET} {:>12.6e} {DIM}│{RESET} {:>12.2e} {DIM}│{RESET}",
                 br.gcd_class, br.dim, br.lambda_min, br.lambda_max, cond);
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
    println!("  {BOLD}{CYAN}  │{RESET}  λ_min(G_N):        {:<20.12e}           {BOLD}{CYAN}│{RESET}", alpha_results.global_lambda_min);
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
