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
    eprintln!("  certified-distance sweep                    Certify all cached matrices");
    eprintln!("  certified-distance discover                 List discoverable matrices");
    eprintln!("  certified-distance report [dir]             Human-readable summary");
    eprintln!("  certified-distance lean-export [dir]        Generate Lean axiom file");
    eprintln!("  certified-distance verify <cert.json>       Verify a certificate");
    eprintln!();
    eprintln!("Options:");
    eprintln!("  --source <path>    Explicit matrix file path");
    eprintln!("  --output <dir>     Output directory (default: certificates/)");
}

fn default_search_paths() -> Vec<PathBuf> {
    let mut paths = vec![
        // Standard experiment cache
        PathBuf::from("../cache"),
        PathBuf::from("../../experiments/cache"),
        // OOC cache on NVMe
        PathBuf::from("/mnt/d/cathedral-cache"),
        // Archive on HDD
        PathBuf::from("/mnt/f/cathedral-archive"),
    ];

    // Add home-relative paths
    if let Ok(home) = std::env::var("HOME") {
        paths.push(PathBuf::from(format!("{}/code/github.com/jrgochan/prime/experiments/cache", home)));
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
