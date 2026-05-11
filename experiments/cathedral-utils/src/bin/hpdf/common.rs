//! Common types and utilities shared across all HPDF subcommands.
//!
//! Provides:
//! - `HpdfContext`: loaded Gram matrix + metadata, shared across analyses
//! - `Certificate`: machine-readable JSON output for Lean bridge
//! - `CertificateWriter`: writes certified results to `results/hpdf/`
//! - ANSI formatting constants
//! - Möbius sieve

use cathedral_utils::hpdf::HpdfReader;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::path::{Path, PathBuf};
use std::time::Instant;

// ── ANSI formatting ──────────────────────────────────────────────────────────

pub const BOLD: &str = "\x1b[1m";
pub const RESET: &str = "\x1b[0m";
pub const GREEN: &str = "\x1b[32m";
pub const RED: &str = "\x1b[31m";
pub const CYAN: &str = "\x1b[36m";
pub const YELLOW: &str = "\x1b[33m";
pub const DIM: &str = "\x1b[2m";
pub const WHITE: &str = "\x1b[97m";
pub const MAGENTA: &str = "\x1b[35m";

// ── Möbius sieve ─────────────────────────────────────────────────────────────

/// Compute Möbius function μ(n) for n = 0..=max via linear sieve.
pub fn mobius_sieve(n: usize) -> Vec<i8> {
    let mut mu = vec![0i8; n + 1];
    let mut is_prime = vec![true; n + 1];
    let mut primes = Vec::new();
    mu[1] = 1;
    for i in 2..=n {
        if is_prime[i] {
            primes.push(i);
            mu[i] = -1;
        }
        for &p in &primes {
            let ip = i * p;
            if ip > n {
                break;
            }
            is_prime[ip] = false;
            if i % p == 0 {
                mu[ip] = 0;
                break;
            } else {
                mu[ip] = -mu[i];
            }
        }
    }
    mu
}

// ── HpdfContext ──────────────────────────────────────────────────────────────

/// A loaded HPDF file with Gram matrix, Möbius table, and metadata.
///
/// This is the shared context passed to every analysis subcommand.
pub struct HpdfContext {
    /// Path to the source H5 file.
    pub path: PathBuf,
    /// SHA-256 hash of the file on disk.
    pub file_sha256: String,
    /// The full Gram matrix G(j,k) for j,k ∈ {2,...,max_n}, row-major.
    pub gram: Vec<f64>,
    /// Dimension of the Gram matrix (max_n - 1).
    pub dim: usize,
    /// Maximum N value (the Gram matrix covers j,k ∈ {2,...,max_n}).
    pub max_n: usize,
    /// Precision in bits (0 = f64, 512 = MPFR, etc.)
    pub precision: u32,
    /// Möbius function μ(n) for n = 0..=max_n.
    pub mu: Vec<i8>,
    /// ln(max_n).
    pub log_n: f64,
    /// Wall-clock time to load the file.
    pub load_time_secs: f64,
}

impl HpdfContext {
    /// Load an HPDF file into a fully populated context.
    pub fn load(path: &Path) -> Result<Self, String> {
        let t0 = Instant::now();

        // SHA-256 of file on disk
        let file_bytes =
            std::fs::read(path).map_err(|e| format!("Failed to read {}: {e}", path.display()))?;
        let file_sha256 = format!("{:x}", Sha256::digest(&file_bytes));
        drop(file_bytes); // free memory before loading the matrix

        let reader = HpdfReader::open(path).map_err(|e| format!("Failed to open HPDF: {e}"))?;
        let dim = reader.dim();
        let max_n = reader.max_n();
        let precision = reader.precision().unwrap_or(0);

        let mem_gb = (dim * dim * 8) as f64 / 1e9;
        println!(
            "  {DIM}dim={dim}, max_N={max_n}, prec={precision}-bit, matrix={mem_gb:.1} GB{RESET}"
        );

        let gram = reader
            .read_gram_full()
            .map_err(|e| format!("Failed to read Gram matrix: {e}"))?;
        let load_time = t0.elapsed().as_secs_f64();
        println!("  {GREEN}✓{RESET} Gram loaded ({load_time:.1}s)");

        let mu = mobius_sieve(max_n);
        let log_n = (max_n as f64).ln();

        Ok(HpdfContext {
            path: path.to_path_buf(),
            file_sha256,
            gram,
            dim,
            max_n,
            precision,
            mu,
            log_n,
            load_time_secs: load_time,
        })
    }
}

// ── Certificate output ──────────────────────────────────────────────────────

/// A certified result that can be written to JSON for Lean bridge consumption.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Certificate {
    /// Which subcommand produced this certificate (e.g., "hpdf taper").
    pub tool: String,
    /// Tool version.
    pub version: String,
    /// ISO 8601 timestamp.
    pub timestamp: String,
    /// Path to the input H5 file.
    pub input_file: String,
    /// SHA-256 hash of the input file.
    pub input_sha256: String,
    /// Maximum N value in the Gram matrix.
    pub max_n: usize,
    /// MPFR precision in bits (0 = f64).
    pub precision: u32,
    /// Subcommand-specific results.
    pub results: serde_json::Value,
    /// Total wall-clock runtime in seconds.
    pub runtime_secs: f64,
}

impl Certificate {
    /// Create a new certificate stub for the given context and subcommand.
    pub fn new(ctx: &HpdfContext, subcommand: &str) -> Self {
        let now = chrono_timestamp();
        Certificate {
            tool: format!("hpdf {subcommand}"),
            version: env!("CARGO_PKG_VERSION").to_string(),
            timestamp: now,
            input_file: ctx.path.display().to_string(),
            input_sha256: ctx.file_sha256.clone(),
            max_n: ctx.max_n,
            precision: ctx.precision,
            results: serde_json::json!({}),
            runtime_secs: 0.0,
        }
    }

    /// Write this certificate to `results/hpdf/<subcommand>_N<max_n>.json`.
    pub fn write(&self, subcommand: &str, max_n: usize) -> PathBuf {
        let dir = results_dir();
        std::fs::create_dir_all(&dir).ok();
        let path = dir.join(format!("{subcommand}_N{max_n}.json"));
        let json = serde_json::to_string_pretty(self).expect("Failed to serialize certificate");
        std::fs::write(&path, json).expect("Failed to write certificate");
        path
    }
}

/// Get the results directory for certified HPDF output.
fn results_dir() -> PathBuf {
    // Try workspace-relative path first
    let candidates = ["results/hpdf", "../results/hpdf"];
    for c in &candidates {
        let p = PathBuf::from(c);
        if p.parent().map(|pp| pp.exists()).unwrap_or(false) {
            std::fs::create_dir_all(&p).ok();
            return p;
        }
    }
    // Fallback: create results/hpdf in CWD
    let p = PathBuf::from("results/hpdf");
    std::fs::create_dir_all(&p).ok();
    p
}

/// ISO 8601 timestamp (no chrono dependency — uses basic formatting).
fn chrono_timestamp() -> String {
    use std::process::Command;
    Command::new("date")
        .args(["-u", "+%Y-%m-%dT%H:%M:%SZ"])
        .output()
        .ok()
        .and_then(|o| String::from_utf8(o.stdout).ok())
        .map(|s| s.trim().to_string())
        .unwrap_or_else(|| "unknown".to_string())
}

// ── Utilities ────────────────────────────────────────────────────────────────

/// Scan a directory for HPDF files, sorted by N.
pub fn find_hpdf_files(dir: &Path) -> Vec<PathBuf> {
    let mut files: Vec<_> = std::fs::read_dir(dir)
        .into_iter()
        .flatten()
        .filter_map(|e| e.ok())
        .filter(|e| e.path().extension().map(|x| x == "h5").unwrap_or(false))
        .map(|e| e.path())
        .collect();

    files.sort_by_key(|p| {
        p.file_stem()
            .and_then(|s| s.to_str())
            .and_then(|s| s.strip_prefix("gram_N"))
            .and_then(|s| s.split('_').next())
            .and_then(|s| s.parse::<usize>().ok())
            .unwrap_or(0)
    });

    files
}

/// Find the HPDF cache directory.
pub fn find_cache_dir() -> Option<PathBuf> {
    let candidates = ["cache/hpdf", "../cache/hpdf", "experiments/cache/hpdf"];
    for c in &candidates {
        let p = PathBuf::from(c);
        if p.exists() {
            return Some(p);
        }
    }
    None
}

/// Print a standardized section header.
pub fn section_header(num: u32, title: &str, elapsed_secs: f64) {
    println!("\n  {BOLD}{CYAN}═══ §{num}. {title} ({elapsed_secs:.1}s) ═══{RESET}");
}
