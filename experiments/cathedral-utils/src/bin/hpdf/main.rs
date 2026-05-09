//! ═══════════════════════════════════════════════════════════════════════════
//!  HPDF — Cathedral High-Precision Data Format Multi-Tool
//!
//!  Unified CLI for building, verifying, querying, and analyzing HPDF files.
//!  Designed for extensibility: each analysis mode lives in its own module.
//!
//!  Usage:
//!    hpdf build <N> [--precision <bits>]      Build a fresh Gram matrix
//!    hpdf build-streaming <N> [--precision P] Streaming build (half RAM usage)
//!    hpdf verify <path.h5>                    Full verification suite
//!    hpdf info <path.h5>                      Metadata-only dump
//!    hpdf query <path.h5> <j,k>              Point-query G[j,k]
//!    hpdf taper <path.h5> [--json]           Taper sum analysis
//!    hpdf taper --all [--json]               Analyze all cached files
//!    hpdf ladder <N1,N2,...>                  Build a chain of sizes
//!    hpdf ooc <path>                          Convert OOC binary to HPDF
//! ═══════════════════════════════════════════════════════════════════════════

mod common;
mod taper;
mod verify;

use common::*;
use std::path::Path;

fn main() {
    let args: Vec<String> = std::env::args().collect();

    if args.len() < 2 || args[1] == "--help" || args[1] == "-h" {
        print_usage();
        return;
    }

    // Parse global flags
    let emit_json = args.iter().any(|a| a == "--json");
    let precision: u32 = args
        .iter()
        .position(|a| a == "--precision")
        .and_then(|i| args.get(i + 1))
        .and_then(|s| s.parse().ok())
        .unwrap_or(0);

    match args[1].as_str() {
        // ── Build ────────────────────────────────────────────────────────
        "build" | "--build" => {
            if args.len() < 3 {
                eprintln!("Usage: hpdf build <N> [--precision <bits>]");
                std::process::exit(1);
            }
            let n: usize = args[2].parse().expect("N must be a number");
            verify::build::build_and_verify(n, precision);
        }

        // ── Build Streaming ──────────────────────────────────────────────
        "build-streaming" | "--build-streaming" => {
            if args.len() < 3 {
                eprintln!("Usage: hpdf build-streaming <N> [--precision <bits>]");
                std::process::exit(1);
            }
            let n: usize = args[2].parse().expect("N must be a number");
            verify::build::build_streaming(n, precision);
        }

        // ── Ladder ───────────────────────────────────────────────────────
        "ladder" | "--ladder" => {
            if args.len() < 3 {
                eprintln!("Usage: hpdf ladder <N1,N2,...>");
                std::process::exit(1);
            }
            let sizes: Vec<usize> = args[2]
                .split(',')
                .map(|s| s.trim().parse().expect("each N must be a number"))
                .collect();
            verify::build::build_ladder(&sizes);
        }

        // ── Verify ───────────────────────────────────────────────────────
        "verify" | "--verify" => {
            if args.len() < 3 {
                eprintln!("Usage: hpdf verify <path.h5>");
                std::process::exit(1);
            }
            verify::verify_file(&args[2]);
        }

        // ── Info ─────────────────────────────────────────────────────────
        "info" | "--info" => {
            if args.len() < 3 {
                eprintln!("Usage: hpdf info <path.h5>");
                std::process::exit(1);
            }
            verify::info_hpdf(&args[2]);
        }

        // ── Query ────────────────────────────────────────────────────────
        "query" | "--query" => {
            if args.len() < 4 {
                eprintln!("Usage: hpdf query <path.h5> <j,k>");
                std::process::exit(1);
            }
            verify::query_entry(&args[2], &args[3]);
        }

        // ── OOC Convert ──────────────────────────────────────────────────
        "ooc" | "--ooc" => {
            if args.len() < 3 {
                eprintln!("Usage: hpdf ooc <path>");
                std::process::exit(1);
            }
            verify::convert_ooc(&args[2]);
        }

        // ── Taper Analysis ───────────────────────────────────────────────
        "taper" | "--taper" => {
            run_taper(&args[2..], emit_json);
        }

        // ── Legacy: bare path → verify ───────────────────────────────────
        other if other.ends_with(".h5") => {
            verify::verify_file(other);
        }

        // ── Legacy: bare number → build ──────────────────────────────────
        other if other.parse::<usize>().is_ok() => {
            let n: usize = other.parse().unwrap();
            verify::build::build_and_verify(n, precision);
        }

        _ => {
            eprintln!("Unknown subcommand: {}", args[1]);
            print_usage();
            std::process::exit(1);
        }
    }
}

/// Handle the taper subcommand with --all support.
fn run_taper(rest: &[String], emit_json: bool) {
    // Filter out --json from the path list
    let paths: Vec<&str> = rest
        .iter()
        .filter(|a| *a != "--json" && !a.starts_with("--precision"))
        .map(|s| s.as_str())
        .collect();

    if paths.is_empty() || paths[0] == "--help" {
        eprintln!("Usage: hpdf taper <path.h5> [...] [--json]");
        eprintln!("       hpdf taper --all [--json]");
        std::process::exit(1);
    }

    if paths[0] == "--all" {
        // Scan for cached HPDF files
        match find_cache_dir() {
            Some(dir) => {
                let files = find_hpdf_files(&dir);
                if files.is_empty() {
                    eprintln!("  No HPDF files found in {}", dir.display());
                    std::process::exit(1);
                }
                println!(
                    "\n  {BOLD}{CYAN}╔═══════════════════════════════════════════════════════╗{RESET}"
                );
                println!(
                    "  {BOLD}{CYAN}║{RESET}  {BOLD}{WHITE}CATHEDRAL TAPER SUM ANALYZER{RESET}"
                );
                println!(
                    "  {BOLD}{CYAN}║{RESET}  {DIM}Scanning {} files in {}{RESET}",
                    files.len(),
                    dir.display()
                );
                println!(
                    "  {BOLD}{CYAN}╚═══════════════════════════════════════════════════════╝{RESET}"
                );
                let path_refs: Vec<&Path> = files.iter().map(|p| p.as_path()).collect();
                taper::run(&path_refs, emit_json);
            }
            None => {
                eprintln!("  No cache/hpdf/ directory found");
                std::process::exit(1);
            }
        }
    } else {
        println!(
            "\n  {BOLD}{CYAN}╔═══════════════════════════════════════════════════════╗{RESET}"
        );
        println!(
            "  {BOLD}{CYAN}║{RESET}  {BOLD}{WHITE}CATHEDRAL TAPER SUM ANALYZER{RESET}"
        );
        println!(
            "  {BOLD}{CYAN}║{RESET}  {DIM}Exploration 30 · Taper Decomposition{RESET}"
        );
        println!(
            "  {BOLD}{CYAN}╚═══════════════════════════════════════════════════════╝{RESET}"
        );
        let path_refs: Vec<&Path> = paths.iter().map(|p| Path::new(*p)).collect();
        taper::run(&path_refs, emit_json);
    }
}

fn print_usage() {
    println!(
        "
  {BOLD}{CYAN}HPDF — Cathedral High-Precision Data Format Multi-Tool{RESET}

  {BOLD}SUBCOMMANDS:{RESET}
    build  <N> [--precision <bits>]   Build a fresh Gram matrix and verify
    build-streaming <N> [--prec P]   Streaming build (half RAM, for large N)
    verify <path.h5>                  Full verification suite
    info   <path.h5>                  Metadata-only dump (no matrix load)
    query  <path.h5> <j,k>           Point-query G[j,k] (8-byte read)
    taper  <path.h5> [--json]        Taper sum analysis (certified output)
    taper  --all [--json]            Analyze all cached HPDF files
    ladder <N1,N2,...>               Build a chain of sizes
    ooc    <path>                     Convert OOC binary to HPDF

  {BOLD}GLOBAL FLAGS:{RESET}
    --precision <bits>   MPFR precision (0=f64, 128/256/512/2048)
    --json               Emit certified JSON to results/hpdf/
    --help               Show this help
"
    );
}
