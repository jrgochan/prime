//! # certified-distance — Production-Grade d²_N Certification Pipeline
//!
//! Computes d²_N = 1 - b^T G_N^{-1} b for the Nyman-Beurling equivalence,
//! with multi-tier verification and independently verifiable certificates.
//!
//! ## Commands
//!
//! ```text
//! certified-distance certify <N>              Certify a single N
//! certified-distance sweep                    Certify all cached matrices
//! certified-distance verify <cert.json>       Verify a certificate
//! certified-distance lean-export <dir>        Generate Lean axiom file
//! certified-distance report <dir>             Human-readable summary
//! certified-distance discover                 List all discoverable matrices
//! ```

mod certify;
mod report;

use std::path::PathBuf;

fn main() {
    println!();
    println!("╔══════════════════════════════════════════════════════════════════════╗");
    println!("║  🏛️  CERTIFIED DISTANCE — Cathedral d²_N Pipeline v1.0.0           ║");
    println!("║                                                                     ║");
    println!("║  Produces independently verifiable certificates for:                ║");
    println!("║    d²_N = 1 - b^T G_N^{{-1}} b  (Nyman-Beurling distance)            ║");
    println!("║                                                                     ║");
    println!("║  Cathedral Core Team — May 2026                                     ║");
    println!("╚══════════════════════════════════════════════════════════════════════╝");
    println!();

    let args: Vec<String> = std::env::args().collect();
    if args.len() < 2 {
        print_usage();
        std::process::exit(1);
    }

    // Standard search paths for cached matrices
    let search_paths = default_search_paths();

    match args[1].as_str() {
        "certify" => {
            if args.len() < 3 {
                eprintln!("Usage: certified-distance certify <N> [--source <path>]");
                std::process::exit(1);
            }
            let max_n: usize = args[2].parse().expect("N must be a number");
            let explicit_source = parse_flag_str(&args, "--source");
            let output_dir = parse_flag_str(&args, "--output")
                .unwrap_or_else(|| "certificates".to_string());

            certify::certify_single(max_n, explicit_source, &search_paths, &output_dir);
        }

        "build-dd" => {
            if args.len() < 3 {
                eprintln!("Usage: certified-distance build-dd <N> [--precision <bits>]");
                std::process::exit(1);
            }
            let max_n: usize = args[2].parse().expect("N must be a number");
            let precision: u32 = parse_flag_str(&args, "--precision")
                .and_then(|s| s.parse().ok())
                .unwrap_or(256);

            build_dd_matrix(max_n, precision);
        }

        "sweep" => {
            let output_dir = parse_flag_str(&args, "--output")
                .unwrap_or_else(|| "certificates".to_string());
            certify::sweep_all(&search_paths, &output_dir);
        }

        "discover" => {
            let sources = cathedral_utils::ooc::discover_matrices(&search_paths);
            if sources.is_empty() {
                println!("  No cached matrices found in:");
                for p in &search_paths {
                    println!("    {}", p.display());
                }
                return;
            }
            println!("  Found {} cached matrices:", sources.len());
            println!();
            println!("  {:>8} {:>8} {:>10} {:>10}  {}", "N", "dim", "format", "size", "path");
            println!("  {} {} {} {}  {}",
                "─".repeat(8), "─".repeat(8), "─".repeat(10), "─".repeat(10), "─".repeat(40));
            for s in &sources {
                let format = match s.format {
                    cathedral_utils::ooc::MatrixFormat::Hpdf => "HPDF",
                    cathedral_utils::ooc::MatrixFormat::Ooc => "OOC",
                    cathedral_utils::ooc::MatrixFormat::DdCache => "DD",
                    cathedral_utils::ooc::MatrixFormat::Legacy => "Legacy",
                };
                let size = format_bytes(s.file_size);
                println!("  {:>8} {:>8} {:>10} {:>10}  {}",
                    s.max_n, s.dim, format, size, s.path.display());
            }
        }

        "report" => {
            let dir = args.get(2).map(|s| s.as_str()).unwrap_or("certificates");
            report::generate_report(dir);
        }

        "lean-export" => {
            let dir = args.get(2).map(|s| s.as_str()).unwrap_or("certificates");
            report::lean_export(dir);
        }

        "verify" => {
            if args.len() < 3 {
                eprintln!("Usage: certified-distance verify <cert.json>");
                std::process::exit(1);
            }
            report::verify_certificate(&args[2]);
        }

        _ => {
            eprintln!("Unknown command: {}", args[1]);
            print_usage();
            std::process::exit(1);
        }
    }
}

fn print_usage() {
    eprintln!("Usage:");
    eprintln!("  certified-distance certify <N>              Certify d²_N for a specific N");
    eprintln!("  certified-distance build-dd <N>             Build DD-precision Gram matrix");
    eprintln!("  certified-distance sweep                    Certify all cached matrices");
    eprintln!("  certified-distance discover                 List discoverable matrices");
    eprintln!("  certified-distance report [dir]             Human-readable summary");
    eprintln!("  certified-distance lean-export [dir]        Generate Lean axiom file");
    eprintln!("  certified-distance verify <cert.json>       Verify a certificate");
    eprintln!();
    eprintln!("Options:");
    eprintln!("  --source <path>    Explicit matrix file path");
    eprintln!("  --output <dir>     Output directory (default: certificates/)");
    eprintln!("  --precision <bits> MPFR precision for build-dd (default: 256)");
}

/// Build a DD-precision Gram matrix (MPFR → hi/lo pairs) and cache it.
///
/// This is the key fix for N > 40000: f64 Gram entries lose enough precision
/// that the matrix appears non-PD. DD entries (hi + lo, ~31 digits) preserve
/// positive-definiteness for the CG solver.
fn build_dd_matrix(max_n: usize, precision: u32) {
    use cathedral_utils::{gram, cache};
    use std::time::Instant;

    let dim = max_n - 1;
    let mem_gb = (dim as u64 * dim as u64 * 16) / (1024 * 1024 * 1024);

    println!("  ┌─────────────────────────────────────────────────────────────┐");
    println!("  │  BUILDING DD GRAM MATRIX  N = {:>6}                        │", max_n);
    println!("  │  dim = {:>6}  precision = {:>4}-bit  ~{:>3} GB               │", dim, precision, mem_gb);
    println!("  └─────────────────────────────────────────────────────────────┘");
    println!();

    // Check if already cached
    let cache_path = cache::dd_gram_cache_path(max_n, precision);
    if cache_path.exists() {
        let size = std::fs::metadata(&cache_path).map(|m| m.len()).unwrap_or(0);
        println!("  ⚠ DD cache already exists: {} ({:.1} GB)",
            cache_path.display(), size as f64 / 1_073_741_824.0);
        println!("  Delete the file to rebuild.");
        return;
    }

    let t0 = Instant::now();

    // Step 1: Build ln(n) table at MPFR precision
    let ln_table = gram::LnNTable::new(max_n, precision);

    // Step 2: Build DD Gram matrix (MPFR computation → hi/lo split)
    let (hi, lo, built_dim) = gram::GramMatrix::build_fast_dd(max_n, &ln_table);
    assert_eq!(built_dim, dim);

    // Step 3: Cache to disk
    match cache::save_dd_gram(&cache_path, &hi, &lo, dim, max_n, precision) {
        Ok(()) => {
            let total = t0.elapsed().as_secs_f64();
            println!();
            println!("  ✓ DD Gram matrix built and cached in {:.1}s", total);
            println!("  ✓ Path: {}", cache_path.display());
            println!("  ✓ Size: {:.1} GB", (hi.len() + lo.len()) as f64 * 8.0 / 1_073_741_824.0);

            // Validate: check diagonal is positive
            let mut min_diag = f64::MAX;
            let mut max_diag = f64::MIN;
            for i in 0..dim {
                let d = hi[i * dim + i] + lo[i * dim + i];
                min_diag = min_diag.min(d);
                max_diag = max_diag.max(d);
            }
            println!("  ✓ Diagonal range: [{:.6e}, {:.6e}]", min_diag, max_diag);
            if min_diag > 0.0 {
                println!("  ✓ All diagonal entries positive");
            } else {
                println!("  ⚠ WARNING: negative diagonal entries detected!");
            }
        }
        Err(e) => {
            eprintln!("  ✗ Failed to save: {}", e);
        }
    }
}

fn default_search_paths() -> Vec<PathBuf> {
    let mut paths = vec![
        // Standard experiment cache
        PathBuf::from("../cache"),
        PathBuf::from("../../experiments/cache"),
        // HPDF cache subdirectory
        PathBuf::from("../cache/hpdf"),
        PathBuf::from("../../experiments/cache/hpdf"),
        // Cathedral-utils cache (where hpdf-verify writes)
        PathBuf::from("../cathedral-utils/cache/hpdf"),
        // OOC cache on NVMe
        PathBuf::from("/mnt/d/cathedral-cache"),
        // Archive on HDD
        PathBuf::from("/mnt/f/cathedral-archive"),
    ];

    // Add home-relative paths
    if let Ok(home) = std::env::var("HOME") {
        paths.push(PathBuf::from(format!("{}/code/github.com/jrgochan/prime/experiments/cache", home)));
        paths.push(PathBuf::from(format!("{}/code/github.com/jrgochan/prime/experiments/cache/hpdf", home)));
        paths.push(PathBuf::from(format!("{}/code/github.com/jrgochan/prime/experiments/cathedral-utils/cache/hpdf", home)));
    }

    // Environment override
    if let Ok(extra) = std::env::var("CATHEDRAL_CACHE_DIR") {
        paths.push(PathBuf::from(extra));
    }

    paths
}

fn parse_flag_str(args: &[String], flag: &str) -> Option<String> {
    args.windows(2)
        .find(|w| w[0] == flag)
        .map(|w| w[1].clone())
}

fn format_bytes(bytes: u64) -> String {
    if bytes >= 1_073_741_824 {
        format!("{:.1} GB", bytes as f64 / 1_073_741_824.0)
    } else if bytes >= 1_048_576 {
        format!("{:.0} MB", bytes as f64 / 1_048_576.0)
    } else if bytes >= 1024 {
        format!("{:.0} KB", bytes as f64 / 1024.0)
    } else {
        format!("{} B", bytes)
    }
}
