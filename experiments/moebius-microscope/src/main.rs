//! ═══════════════════════════════════════════════════════════════
//!  MÖBIUS CANCELLATION MICROSCOPE v3.1
//!  12 decompositions · parallel row-streaming engine.
//!
//!  v3.1: GPU-accelerated bilinear forms (cuBLAS dsymv + ddot)
//!        + §5 Taper Cancellation Tracker
//!        for analyzing U(N) - 2L(N)/lnN → 1 (≡ RH).
//!
//!  Supports HPDF files (DD-lossless ~31-digit precision),
//!  OOC row-streaming for large N, GPU acceleration, and Gram bound analysis.
//!
//!  Usage:
//!    moebius-microscope 100 500 1000            (compute Gram on-the-fly)
//!    moebius-microscope --hpdf cache/hpdf/*.h5  (CPU HPDF mode)
//!    moebius-microscope --gpu  cache/hpdf/*.h5  (GPU-accelerated mode)
//! ═══════════════════════════════════════════════════════════════

mod decomp;
mod output;

use clap::Parser;

#[derive(Parser)]
#[command(name = "moebius-microscope", version = "3.1.0")]
#[command(about = "Möbius Cancellation Microscope — decompose vᵀGv + taper tracker")]
struct Cli {
    /// N values to analyze (compute Gram on-the-fly at f64 precision)
    #[arg(value_name = "N")]
    ns: Vec<usize>,

    /// Path(s) to HPDF file(s) for DD-lossless precision (CPU mode).
    /// When set, N is read from the HPDF metadata.
    #[arg(long = "hpdf", value_name = "PATH")]
    hpdf_paths: Vec<String>,

    /// Path(s) to HPDF file(s) for GPU-accelerated processing.
    /// Uses cuBLAS for bilinear forms (vᵀGv, U, L, Q).
    /// Requires --features gpu and CUDA-capable GPU.
    #[arg(long = "gpu", value_name = "PATH")]
    gpu_paths: Vec<String>,

    /// Output directory for results
    #[arg(long, default_value = "results")]
    output: String,
}

fn main() {
    let cli = Cli::parse();

    let has_gpu = cfg!(feature = "gpu");
    let gpu_tag = if has_gpu { " · GPU ready" } else { "" };

    eprintln!("╔═══════════════════════════════════════════════════╗");
    eprintln!("║  MÖBIUS CANCELLATION MICROSCOPE v3.1              ║");
    eprintln!(
        "║  12 decompositions · HPDF/DD · Taper Tracker{:>5} ║",
        gpu_tag
    );
    eprintln!("╚═══════════════════════════════════════════════════╝");

    std::fs::create_dir_all(&cli.output).unwrap();

    // Mode 0: GPU-accelerated HPDF processing (highest priority)
    #[cfg(feature = "gpu")]
    for path_str in &cli.gpu_paths {
        let path = std::path::Path::new(path_str);
        if !path.exists() {
            eprintln!("  ⚠ HPDF file not found: {path_str}");
            continue;
        }
        match decomp::gpu_runner::run_microscope_gpu(path) {
            Ok(d) => {
                output::write_all(&d, &cli.output).unwrap();
            }
            Err(e) => eprintln!("  ✗ GPU error: {e}"),
        }
    }

    #[cfg(not(feature = "gpu"))]
    if !cli.gpu_paths.is_empty() {
        eprintln!("  ⚠ GPU support not compiled. Rebuild with:");
        eprintln!("    cargo build --release --features gpu");
        eprintln!("  Falling back to CPU HPDF mode...");
        // Fall through to HPDF CPU processing
        #[cfg(feature = "hpdf")]
        for path_str in &cli.gpu_paths {
            let path = std::path::Path::new(path_str);
            if !path.exists() {
                eprintln!("  ⚠ HPDF file not found: {path_str}");
                continue;
            }
            match decomp::runners::run_microscope_hpdf(path) {
                Ok(d) => {
                    output::write_all(&d, &cli.output).unwrap();
                }
                Err(e) => eprintln!("  ✗ HPDF error: {e}"),
            }
        }
    }

    // Mode 1: HPDF files (high-precision row-streaming, CPU)
    #[cfg(feature = "hpdf")]
    for path_str in &cli.hpdf_paths {
        let path = std::path::Path::new(path_str);
        if !path.exists() {
            eprintln!("  ⚠ HPDF file not found: {path_str}");
            continue;
        }
        match decomp::runners::run_microscope_hpdf(path) {
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
    let ns: Vec<usize> =
        if cli.ns.is_empty() && cli.hpdf_paths.is_empty() && cli.gpu_paths.is_empty() {
            vec![100, 500]
        } else {
            cli.ns.clone()
        };

    for &n in &ns {
        if n < 10 {
            eprintln!("  ⚠ Skip N={n} (too small)");
            continue;
        }
        let d = decomp::runners::run_microscope(n);
        output::write_all(&d, &cli.output).unwrap();
    }

    eprintln!("\n═══ ALL COMPLETE ═══");
}
