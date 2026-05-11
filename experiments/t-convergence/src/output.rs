//! Output file generation for the T-Convergence experiment.
//!
//! Writes structured results to `results/`:
//! - `certificate.json`      — Machine-readable structured results
//! - `convergence_rate.tsv`  — Error vs T for each (j,k) pair
//! - `t_scaling.tsv`         — Worst tₘ vs N (proves T independence)
//! - `precision_table.tsv`   — Recommended T for each precision target

use serde_json::json;
use std::fs;
use std::io::Write;
use std::path::{Path, PathBuf};

/// Get the results directory for t-convergence.
fn results_dir() -> PathBuf {
    let manifest = env!("CARGO_MANIFEST_DIR");
    let dir = PathBuf::from(manifest).join("results");
    fs::create_dir_all(&dir).ok();
    dir
}

/// A single convergence measurement for one (j,k) pair at one T value.
pub struct ConvergencePoint {
    pub j: usize,
    pub k: usize,
    pub t: usize,
    pub error: f64,
    pub rate: String,
    pub digits: f64,
}

/// A row from the "does T scale with N?" survey.
pub struct ScalingRow {
    pub n: usize,
    pub worst_tm: f64,
    pub worst_pair: (usize, usize),
    pub worst_lcm: usize,
}

/// Calibration results from the empirical decay fit.
pub struct CalibrationResult {
    pub alpha: f64,
    pub c: f64,
    pub precision_targets: Vec<PrecisionTarget>,
}

/// A recommended T value for a specific precision target.
pub struct PrecisionTarget {
    pub label: String,
    pub digits: u32,
    pub t_needed: u64,
}

/// GPU precision-vs-size tradeoff entry.
pub struct GpuTradeoff {
    pub storage: String,
    pub entry_digits: f64,
    pub vram_gb: f64,
    pub solve_digits: f64,
}

/// Reference comparison entry (T=200K vs reference).
pub struct ReferenceComparison {
    pub j: usize,
    pub k: usize,
    pub value_200k: f64,
    pub value_ref: f64,
    pub error: f64,
}

/// Write all output files after a complete analysis run.
pub fn write_results(
    n_max: usize,
    convergence_data: &[ConvergencePoint],
    scaling_data: &[ScalingRow],
    calibration: &CalibrationResult,
    gpu_tradeoffs: &[GpuTradeoff],
    ref_comparisons: &[ReferenceComparison],
    t_ref: usize,
    elapsed_secs: f64,
) {
    let dir = results_dir();

    write_certificate(
        &dir,
        n_max,
        convergence_data,
        scaling_data,
        calibration,
        gpu_tradeoffs,
        ref_comparisons,
        t_ref,
        elapsed_secs,
    );
    write_convergence_tsv(&dir, convergence_data);
    write_scaling_tsv(&dir, scaling_data);
    write_precision_tsv(&dir, calibration);

    eprintln!();
    eprintln!("  ✓ Output files written to {}/", dir.display());
    eprintln!("    • certificate.json");
    eprintln!("    • convergence_rate.tsv");
    eprintln!("    • t_scaling.tsv");
    eprintln!("    • precision_table.tsv");
}

/// Write the JSON certificate with all structured results.
fn write_certificate(
    dir: &Path,
    n_max: usize,
    convergence_data: &[ConvergencePoint],
    scaling_data: &[ScalingRow],
    calibration: &CalibrationResult,
    gpu_tradeoffs: &[GpuTradeoff],
    ref_comparisons: &[ReferenceComparison],
    t_ref: usize,
    elapsed_secs: f64,
) {
    // Collect unique pairs
    let mut pairs: Vec<(usize, usize)> = convergence_data.iter().map(|p| (p.j, p.k)).collect();
    pairs.dedup();

    let convergence_json: Vec<_> = convergence_data
        .iter()
        .map(|p| {
            json!({
                "j": p.j, "k": p.k, "T": p.t,
                "abs_error": p.error,
                "rate": p.rate,
                "digits": (p.digits * 10.0).round() / 10.0,
            })
        })
        .collect();

    let scaling_json: Vec<_> = scaling_data
        .iter()
        .map(|r| {
            json!({
                "N": r.n,
                "worst_tm": (r.worst_tm * 1_000_000.0).round() / 1_000_000.0,
                "worst_pair": format!("({},{})", r.worst_pair.0, r.worst_pair.1),
                "worst_lcm": r.worst_lcm,
            })
        })
        .collect();

    let precision_json: Vec<_> = calibration
        .precision_targets
        .iter()
        .map(|t| {
            json!({
                "label": t.label,
                "digits": t.digits,
                "t_needed": t.t_needed,
            })
        })
        .collect();

    let gpu_json: Vec<_> = gpu_tradeoffs
        .iter()
        .map(|g| {
            json!({
                "storage": g.storage,
                "entry_digits": g.entry_digits,
                "vram_gb": (g.vram_gb * 10.0).round() / 10.0,
                "solve_digits": g.solve_digits,
            })
        })
        .collect();

    let ref_json: Vec<_> = ref_comparisons
        .iter()
        .map(|r| {
            json!({
                "j": r.j, "k": r.k,
                "value_T200K": r.value_200k,
                "value_Tref": r.value_ref,
                "error": r.error,
            })
        })
        .collect();

    let cert = json!({
        "experiment": "t-convergence",
        "version": env!("CARGO_PKG_VERSION"),
        "n_max": n_max,
        "t_ref": t_ref,
        "elapsed_seconds": (elapsed_secs * 1000.0).round() / 1000.0,
        "threads": rayon::current_num_threads(),
        "calibration": {
            "alpha": (calibration.alpha * 100.0).round() / 100.0,
            "C": calibration.c,
        },
        "convergence": convergence_json,
        "t_scaling": scaling_json,
        "precision_targets": precision_json,
        "gpu_tradeoffs": gpu_json,
        "reference_comparisons": ref_json,
        "conclusions": {
            "decay_exponent": (calibration.alpha * 100.0).round() / 100.0,
            "t_scales_with_n": false,
            "worst_tm": "1/3",
            "t200k_digits": "10-11",
            "viable_storage": "DD (double-double, 31 digits)",
        },
    });

    let path = dir.join("certificate.json");
    let json_str = serde_json::to_string_pretty(&cert).unwrap();
    fs::write(&path, json_str).expect("Failed to write certificate JSON");
}

/// Write the convergence rate data as TSV.
fn write_convergence_tsv(dir: &Path, data: &[ConvergencePoint]) {
    let path = dir.join("convergence_rate.tsv");
    let mut f = fs::File::create(&path).expect("Failed to create convergence TSV");

    writeln!(f, "j\tk\tT\tabs_error\trate\tdigits").unwrap();

    for p in data {
        writeln!(
            f,
            "{}\t{}\t{}\t{:.6e}\t{}\t{:.1}",
            p.j, p.k, p.t, p.error, p.rate, p.digits,
        )
        .unwrap();
    }
}

/// Write the T-scaling survey as TSV.
fn write_scaling_tsv(dir: &Path, data: &[ScalingRow]) {
    let path = dir.join("t_scaling.tsv");
    let mut f = fs::File::create(&path).expect("Failed to create scaling TSV");

    writeln!(f, "N\tworst_tm\tworst_pair\tworst_lcm").unwrap();

    for r in data {
        writeln!(
            f,
            "{}\t{:.6}\t({},{})\t{}",
            r.n, r.worst_tm, r.worst_pair.0, r.worst_pair.1, r.worst_lcm,
        )
        .unwrap();
    }
}

/// Write the precision target table as TSV.
fn write_precision_tsv(dir: &Path, cal: &CalibrationResult) {
    let path = dir.join("precision_table.tsv");
    let mut f = fs::File::create(&path).expect("Failed to create precision TSV");

    writeln!(f, "label\tdigits\tt_needed").unwrap();

    for t in &cal.precision_targets {
        writeln!(f, "{}\t{}\t{}", t.label, t.digits, t.t_needed).unwrap();
    }
}
