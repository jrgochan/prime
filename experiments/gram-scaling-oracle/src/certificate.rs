//! ═══════════════════════════════════════════════════════════════════════════
//!  CERTIFICATE OUTPUT — Certified JSON + TSV Results
//!
//!  Follows Cathedral standards: all numerical results are written to
//!  structured files with full metadata for reproducibility.
//! ═══════════════════════════════════════════════════════════════════════════

use std::fs;
use std::io::Write;

use crate::alpha_fit::AlphaResults;
use crate::block_spectrum::BlockSpectralResult;
use crate::gcd_decomp::GcdDecomposition;

const RESULTS_DIR: &str = "results";

/// Write all certified results to disk.
pub fn write_all(
    max_n: usize,
    decomp: &GcdDecomposition,
    block_results: &[BlockSpectralResult],
    alpha: &AlphaResults,
) {
    fs::create_dir_all(RESULTS_DIR).ok();

    write_summary_json(max_n, decomp, alpha);
    write_block_tsv(block_results);
    write_scaling_tsv(alpha);

    println!("  {GREEN}✓{RESET} Results written to {RESULTS_DIR}/");
    println!("    ├── oracle_summary_N{max_n}.json");
    println!("    ├── block_spectrum_N{max_n}.tsv");
    println!("    └── scaling_data_N{max_n}.tsv");
}

/// Write the master summary JSON certificate.
fn write_summary_json(
    max_n: usize,
    decomp: &GcdDecomposition,
    alpha: &AlphaResults,
) {
    let path = format!("{RESULTS_DIR}/oracle_summary_N{max_n}.json");
    let mut f = fs::File::create(&path).expect("Failed to create summary JSON");

    let timestamp = chrono::Utc::now().to_rfc3339();

    writeln!(f, "{{").unwrap();
    writeln!(f, "  \"format\": \"cathedral-gram-scaling-oracle-v1\",").unwrap();
    writeln!(f, "  \"timestamp\": \"{timestamp}\",").unwrap();
    writeln!(f, "  \"N\": {max_n},").unwrap();
    writeln!(f, "  \"gcd_classes\": {},", decomp.classes.len()).unwrap();
    writeln!(f, "  \"global_lambda_min\": {:.15e},", alpha.global_lambda_min).unwrap();
    writeln!(f, "  \"scaling\": {{").unwrap();
    writeln!(f, "    \"alpha_power_law\": {:.10},", alpha.alpha_power).unwrap();
    writeln!(f, "    \"r2_power_law\": {:.10},", alpha.r2_power).unwrap();
    writeln!(f, "    \"alpha_log_decay\": {:.10},", alpha.alpha_log).unwrap();
    writeln!(f, "    \"r2_log_decay\": {:.10}", alpha.r2_log).unwrap();
    writeln!(f, "  }},").unwrap();
    writeln!(f, "  \"three_circles_target\": {{").unwrap();
    writeln!(f, "    \"alpha\": 0.855,").unwrap();
    writeln!(f, "    \"description\": \"Interpolation exponent from Hadamard Three-Circles (eps=0.5)\"").unwrap();
    writeln!(f, "  }},").unwrap();
    writeln!(f, "  \"block_count\": {},", alpha.block_scaling.len()).unwrap();
    writeln!(f, "  \"machine\": \"Apple M2 Max, 96 GB RAM\"").unwrap();
    writeln!(f, "}}").unwrap();
}

/// Write per-block spectral data as TSV.
fn write_block_tsv(block_results: &[BlockSpectralResult]) {
    let n = block_results.iter().map(|r| r.dim).max().unwrap_or(0);
    let path = format!("{RESULTS_DIR}/block_spectrum_N{n}.tsv");
    let mut f = fs::File::create(&path).expect("Failed to create block TSV");

    writeln!(f, "gcd_class\tdim\tlambda_min\tlambda_max\ttrace\tfrobenius_norm\tcondition").unwrap();
    for r in block_results {
        let cond = if r.lambda_min > 1e-15 { r.lambda_max / r.lambda_min } else { f64::INFINITY };
        writeln!(f, "{}\t{}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.6e}",
                 r.gcd_class, r.dim, r.lambda_min, r.lambda_max, r.trace, r.frobenius_norm, cond).unwrap();
    }
}

/// Write scaling data for cross-block analysis.
fn write_scaling_tsv(alpha: &AlphaResults) {
    let path = format!("{RESULTS_DIR}/scaling_data.tsv");
    let mut f = fs::File::create(&path).expect("Failed to create scaling TSV");

    writeln!(f, "gcd_class\tdim\tlambda_min\tln_dim\tln_lambda_min").unwrap();
    for &(d, dim, lm) in &alpha.block_scaling {
        writeln!(f, "{}\t{}\t{:.15e}\t{:.10}\t{:.10}",
                 d, dim, lm, (dim as f64).ln(), lm.ln()).unwrap();
    }
}

// Terminal colors
const GREEN: &str = "\x1b[32m";
const RESET: &str = "\x1b[0m";
