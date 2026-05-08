//! ═══════════════════════════════════════════════════════════════
//!  MÖBIUS CANCELLATION MICROSCOPE v2.0
//!  10 decompositions of vᵀGv — parallel row-streaming engine.
//!
//!  v2: Supports HPDF files (DD-lossless ~31-digit precision),
//!  OOC row-streaming for large N, and Gram bound analysis.
//!
//!  Usage:
//!    moebius-microscope 100 500 1000     (compute Gram on-the-fly)
//!    moebius-microscope --hpdf cache/hpdf/gram_N1000.h5
//!    moebius-microscope --hpdf cache/hpdf/gram_N10000.h5
//! ═══════════════════════════════════════════════════════════════

mod decomp;
mod output;

use clap::Parser;

#[derive(Parser)]
#[command(name = "moebius-microscope", version = "2.0.0")]
#[command(about = "Möbius Cancellation Microscope — decompose vᵀGv")]
struct Cli {
    /// N values to analyze (compute Gram on-the-fly at f64 precision)
    #[arg(value_name = "N")]
    ns: Vec<usize>,

    /// Path(s) to HPDF file(s) for DD-lossless precision.
    /// When set, N is read from the HPDF metadata.
    #[arg(long = "hpdf", value_name = "PATH")]
    hpdf_paths: Vec<String>,

    /// Output directory for results
    #[arg(long, default_value = "results")]
    output: String,
}

fn main() {
    let cli = Cli::parse();

    eprintln!("╔═══════════════════════════════════════════════════╗");
    eprintln!("║  MÖBIUS CANCELLATION MICROSCOPE v2.0              ║");
    eprintln!("║  10 decompositions · HPDF/DD · Parallel           ║");
    eprintln!("╚═══════════════════════════════════════════════════╝");

    std::fs::create_dir_all(&cli.output).unwrap();

    // Mode 1: HPDF files (high-precision row-streaming)
    #[cfg(feature = "hpdf")]
    for path_str in &cli.hpdf_paths {
        let path = std::path::Path::new(path_str);
        if !path.exists() {
            eprintln!("  ⚠ HPDF file not found: {path_str}");
            continue;
        }
        match decomp::run_microscope_hpdf(path) {
            Ok(d) => {
                output::write_all(&d, &cli.output).unwrap();
            }
            Err(e) => eprintln!("  ✗ HPDF error: {e}"),
        }
    }

    #[cfg(not(feature = "hpdf"))]
    if !cli.hpdf_paths.is_empty() {
        eprintln!("  ⚠ HPDF support not compiled. Rebuild with:");
        eprintln!("    cargo build --release --features hpdf");
    }

    // Mode 2: On-the-fly computation (f64 precision)
    let ns: Vec<usize> = if cli.ns.is_empty() && cli.hpdf_paths.is_empty() {
        vec![100, 500]
    } else {
        cli.ns.clone()
    };

    for &n in &ns {
        if n < 10 {
            eprintln!("  ⚠ Skip N={n} (too small)");
            continue;
        }
        let d = decomp::run_microscope(n);
        output::write_all(&d, &cli.output).unwrap();
    }

    eprintln!("\n═══ ALL COMPLETE ═══");
}
