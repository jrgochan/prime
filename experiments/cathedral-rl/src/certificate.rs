//! Certified output generation for Cathedral RL runs.
//!
//! Produces machine-readable JSON certificates that constitute
//! verifiable numerical evidence for the Gram form inequality:
//!
//!   vᵀG_N v ≤ 1 + K/ln(N)
//!
//! Each certificate captures:
//!   - The mathematical claim being tested
//!   - Baseline vs optimized witness metrics
//!   - The Pythagorean identity verification: d²_opt + vᵀGv_opt ≈ 1
//!   - K_eff values across the HC number sweep
//!   - SHA-256 content hash for tamper detection
//!
//! ## Certificate Structure
//!
//! ```text
//! {
//!   "experiment": "cathedral-rl",
//!   "claim": "Gram form inequality: vᵀG_N v ≤ 1 + K/ln(N)",
//!   "pythagorean_identity": "d²_opt + vᵀGv_opt = 1",
//!   "sha256": "...",
//!   "runs": [ ... ]
//! }
//! ```
//!
//! This follows the established certificate pattern from
//! `nb-distance`, `covariance-decay`, and `siegel-walfisz`.

use crate::output::RunResult;
use serde::Serialize;
use sha2::{Digest, Sha256};
use std::io::Write;
use std::path::Path;
use std::time::Duration;

// ═══════════════════════════════════════════════════════════════
// CERTIFICATE DATA STRUCTURES
// ═══════════════════════════════════════════════════════════════

/// A certified RL optimization result for one value of N.
#[derive(Debug, Clone, Serialize)]
pub struct CertifiedRun {
    /// Matrix dimension parameter
    pub n: usize,
    /// Vector space dimension (N-1)
    pub dim: usize,
    /// Agent strategy used
    pub agent: String,

    // ─── Baseline (Möbius log-cutoff witness) ───────────────────
    pub baseline_d2: f64,
    pub baseline_vtgv: f64,
    pub baseline_btv: f64,

    // ─── Optimized (CG-converged witness) ───────────────────────
    pub optimal_d2: f64,
    pub optimal_vtgv: f64,
    pub optimal_btv: f64,

    // ─── Derived quantities ─────────────────────────────────────
    /// Pythagorean check: d²_opt + vᵀGv_opt (should equal 1.0)
    pub pythagorean_sum: f64,
    /// Pythagorean residual: |d²_opt + vᵀGv_opt - 1|
    pub pythagorean_residual: f64,
    /// Effective K in vᵀGv ≤ 1 + K/ln(N)
    pub k_eff: f64,
    /// ln(N) for reference
    pub ln_n: f64,
    /// Whether the K=1 Gram bound is satisfied
    pub gram_bound_k1: bool,
    /// Whether vᵀGv < 1 (strictly subcritical)
    pub vtgv_subcritical: bool,
    /// Improvement ratio: (baseline_d2 - optimal_d2) / baseline_d2
    pub improvement_pct: f64,

    // ─── Solver metadata ────────────────────────────────────────
    pub total_steps: usize,
    pub wall_time_s: f64,
    /// Matvec throughput (matvecs/sec)
    pub matvec_rate: f64,
}

impl From<&RunResult> for CertifiedRun {
    fn from(r: &RunResult) -> Self {
        let pythagorean_sum = r.optimal_d2 + r.optimal_vtgv;
        Self {
            n: r.n,
            dim: r.dim,
            agent: r.agent.clone(),
            baseline_d2: r.baseline_d2,
            baseline_vtgv: r.baseline_vtgv,
            baseline_btv: r.baseline_btv,
            optimal_d2: r.optimal_d2,
            optimal_vtgv: r.optimal_vtgv,
            optimal_btv: r.optimal_btv,
            pythagorean_sum,
            pythagorean_residual: (pythagorean_sum - 1.0).abs(),
            k_eff: r.k_eff,
            ln_n: r.ln_n,
            gram_bound_k1: r.gram_bound_satisfied,
            vtgv_subcritical: r.optimal_vtgv < 1.0,
            improvement_pct: r.improvement_pct,
            total_steps: r.total_steps,
            wall_time_s: r.wall_time_s,
            matvec_rate: r.matvec_rate,
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// CERTIFICATE GENERATION
// ═══════════════════════════════════════════════════════════════

/// Full certificate for a sweep of HC numbers.
#[derive(Debug, Clone, Serialize)]
pub struct Certificate {
    pub experiment: String,
    pub description: String,
    pub claim: String,
    pub pythagorean_identity: String,
    pub equivalence: String,
    pub schedule: Vec<usize>,
    pub elapsed_seconds: f64,
    pub all_gram_bound_k1: bool,
    pub all_vtgv_subcritical: bool,
    pub max_k_eff: f64,
    pub max_pythagorean_residual: f64,
    pub runs: Vec<CertifiedRun>,
    pub sha256: String,
}

/// Generate and write a certificate for a set of RL results.
pub fn write_certificate(
    path: &Path,
    results: &[RunResult],
    elapsed: Duration,
) -> std::io::Result<()> {
    let runs: Vec<CertifiedRun> = results.iter().map(CertifiedRun::from).collect();
    let schedule: Vec<usize> = results.iter().map(|r| r.n).collect();

    let all_k1 = runs.iter().all(|r| r.gram_bound_k1);
    let all_sub = runs.iter().all(|r| r.vtgv_subcritical);
    let max_k = runs
        .iter()
        .map(|r| r.k_eff)
        .fold(f64::NEG_INFINITY, f64::max);
    let max_pyth_res = runs
        .iter()
        .map(|r| r.pythagorean_residual)
        .fold(0.0f64, f64::max);

    // Build the certificate without the hash first
    let mut cert = Certificate {
        experiment: "cathedral-rl".to_string(),
        description: "RL-optimized Gram form inequality for Nyman-Beurling distance".to_string(),
        claim: "vᵀG_N v ≤ 1 + K/ln(N) for the optimal witness vector".to_string(),
        pythagorean_identity: "d²_opt + vᵀGv_opt = 1 (projection theorem in L²(0,1))".to_string(),
        equivalence: "RH ⟺ d²_N → 0 as N → ∞".to_string(),
        schedule,
        elapsed_seconds: elapsed.as_secs_f64(),
        all_gram_bound_k1: all_k1,
        all_vtgv_subcritical: all_sub,
        max_k_eff: max_k,
        max_pythagorean_residual: max_pyth_res,
        runs,
        sha256: String::new(), // placeholder
    };

    // Serialize, hash, then embed hash
    let pre_hash_json = serde_json::to_string_pretty(&cert).map_err(std::io::Error::other)?;
    let mut hasher = Sha256::new();
    hasher.update(pre_hash_json.as_bytes());
    let hash = format!("{:x}", hasher.finalize());
    cert.sha256 = hash.clone();

    // Write final certificate
    let cert_json = serde_json::to_string_pretty(&cert).map_err(std::io::Error::other)?;

    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)?;
    }
    let mut f = std::fs::File::create(path)?;
    f.write_all(cert_json.as_bytes())?;

    // Print summary
    print_certificate_summary(&cert);

    Ok(())
}

/// Print the certificate summary to stdout.
fn print_certificate_summary(cert: &Certificate) {
    const BOLD: &str = "\x1b[1m";
    const CYAN: &str = "\x1b[36m";
    const GREEN: &str = "\x1b[32m";
    const YELLOW: &str = "\x1b[33m";
    const WHITE: &str = "\x1b[97m";
    const RESET: &str = "\x1b[0m";
    const SEP: &str = "═══════════════════════════════════════════════════════════════";

    println!();
    println!("  {BOLD}{CYAN}{SEP}{RESET}");
    println!("  {BOLD}{CYAN}  CATHEDRAL RL — CERTIFICATE{RESET}");
    println!("  {BOLD}{CYAN}{SEP}{RESET}");
    println!("  {BOLD}{WHITE}Claim:{RESET}     {}", cert.claim);
    println!(
        "  {BOLD}{WHITE}Identity:{RESET}  {}",
        cert.pythagorean_identity
    );
    println!("  {BOLD}{WHITE}Schedule:{RESET}  {:?}", cert.schedule);
    println!();

    // Pythagorean identity check
    println!("  {BOLD}Pythagorean identity verification:{RESET}");
    for run in &cert.runs {
        let check = if run.pythagorean_residual < 1e-10 {
            format!("{GREEN}✓{RESET}")
        } else if run.pythagorean_residual < 1e-6 {
            format!("{YELLOW}~{RESET}")
        } else {
            "✗".to_string()
        };
        println!(
            "    N={:>6}: d²+vᵀGv = {:.12}  |res| = {:.2e}  {check}",
            run.n, run.pythagorean_sum, run.pythagorean_residual
        );
    }

    println!();

    // K_eff summary
    let subcrit_verdict = if cert.all_vtgv_subcritical {
        format!("{GREEN}ALL vᵀGv < 1 (subcritical) ✓{RESET}")
    } else if cert.all_gram_bound_k1 {
        format!("{GREEN}ALL satisfy K=1 bound ✓{RESET}")
    } else {
        format!("{YELLOW}Max K_eff = {:.4}{RESET}", cert.max_k_eff)
    };
    println!("  {BOLD}Gram bound:{RESET} {subcrit_verdict}");
    println!(
        "  {BOLD}Max Pythagorean residual:{RESET} {:.2e}",
        cert.max_pythagorean_residual
    );
    println!("  {BOLD}SHA-256:{RESET}  {}", cert.sha256);
    println!("  {BOLD}{CYAN}{SEP}{RESET}");
    println!();
}
