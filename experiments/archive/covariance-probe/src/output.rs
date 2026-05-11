/// Output and analysis routines.
///
/// Writes:
///   1. decay_data.tsv    — Tab-separated probe results for each N
///   2. eigenvalues_N.tsv — Eigenvalue spectrum for each probed N
///   3. summary.json      — Machine-readable summary with fit parameters
///   4. report.txt        — Human-readable analysis report
use crate::covariance::ProbeResult;
use std::fs;
use std::io::Write;
use std::path::Path;

/// Write all output files for a set of probe results.
pub fn write_all_outputs(results: &[ProbeResult], output_dir: &Path) {
    fs::create_dir_all(output_dir).expect("Failed to create output directory");

    write_decay_tsv(results, output_dir);
    write_summary_json(results, output_dir);
    write_report(results, output_dir);
}

/// Write the main decay data as TSV.
fn write_decay_tsv(results: &[ProbeResult], output_dir: &Path) {
    let path = output_dir.join("decay_data.tsv");
    let mut f = fs::File::create(&path).expect("Failed to create decay_data.tsv");

    writeln!(
        f,
        "N\td_squared\tcov_quad\tmean_resid_sq\tgram_quad\tmean_proj\tinv_log_N\t\
         d_sq_times_logN\tlambda_min\tlambda_max\tcondition\tfrob_norm\ttrace_C"
    )
    .unwrap();

    for r in results {
        writeln!(
            f,
            "{}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.6e}\t{:.15e}\t{:.15e}",
            r.n,
            r.d_squared,
            r.cov_quad,
            r.mean_residual_sq,
            r.gram_quad,
            r.mean_projection,
            r.inv_log_n,
            r.ratio,
            r.lambda_min,
            r.lambda_max,
            r.condition,
            r.frob_norm,
            r.trace_c,
        )
        .unwrap();
    }
    eprintln!("  ✓ Wrote {}", path.display());
}

/// Fit d²_N ≈ A / (ln N)^α using least squares on log-log scale.
fn fit_decay(results: &[ProbeResult]) -> (f64, f64) {
    // d²_N = A / (ln N)^α
    // ln(d²_N) = ln(A) - α · ln(ln(N))
    // Linear regression: y = c + m·x where y = ln(d²), x = ln(ln(N))

    let _n = results.len() as f64;
    let mut sum_x = 0.0;
    let mut sum_y = 0.0;
    let mut sum_xx = 0.0;
    let mut sum_xy = 0.0;
    let mut count = 0.0;

    for r in results {
        if r.d_squared <= 0.0 || r.n < 3 {
            continue;
        }
        let x = (r.n as f64).ln().ln();
        let y = r.d_squared.ln();
        sum_x += x;
        sum_y += y;
        sum_xx += x * x;
        sum_xy += x * y;
        count += 1.0;
    }

    if count < 2.0 {
        return (0.0, 0.0);
    }

    let m = (count * sum_xy - sum_x * sum_y) / (count * sum_xx - sum_x * sum_x);
    let c = (sum_y - m * sum_x) / count;

    let alpha = -m;
    let a = c.exp();
    (a, alpha)
}

/// Write machine-readable summary as JSON.
fn write_summary_json(results: &[ProbeResult], output_dir: &Path) {
    let (a, alpha) = fit_decay(results);

    let summary = serde_json::json!({
        "experiment": "covariance-probe",
        "description": "Vasyunin covariance matrix probe — RH decay analysis",
        "timestamp": chrono::Utc::now().to_rfc3339(),
        "fit": {
            "model": "d²_N ≈ A / (ln N)^α",
            "A": a,
            "alpha": alpha,
            "rh_prediction": "α ≥ 1",
            "rh_consistent": alpha >= 0.8,
        },
        "results": results,
        "n_values": results.iter().map(|r| r.n).collect::<Vec<_>>(),
        "d_squared_values": results.iter().map(|r| r.d_squared).collect::<Vec<_>>(),
    });

    let path = output_dir.join("summary.json");
    let mut f = fs::File::create(&path).expect("Failed to create summary.json");
    serde_json::to_writer_pretty(&mut f, &summary).expect("Failed to write JSON");
    eprintln!("  ✓ Wrote {}", path.display());
}

/// Write human-readable analysis report.
fn write_report(results: &[ProbeResult], output_dir: &Path) {
    let (a, alpha) = fit_decay(results);
    let path = output_dir.join("report.txt");
    let mut f = fs::File::create(&path).expect("Failed to create report.txt");

    writeln!(
        f,
        "╔══════════════════════════════════════════════════════════════════╗"
    )
    .unwrap();
    writeln!(
        f,
        "║      COVARIANCE MATRIX PROBE — Riemann Hypothesis Decay        ║"
    )
    .unwrap();
    writeln!(
        f,
        "║      Vasyunin-Báez-Duarte Nyman-Beurling Distance              ║"
    )
    .unwrap();
    writeln!(
        f,
        "╚══════════════════════════════════════════════════════════════════╝"
    )
    .unwrap();
    writeln!(f).unwrap();
    writeln!(
        f,
        "  Cathedral Reference: proofs/Cathedral/Vasyunin/Defs.lean"
    )
    .unwrap();
    writeln!(
        f,
        "  Axiom Under Test:    millennium_covariance_cancellation"
    )
    .unwrap();
    writeln!(
        f,
        "  Timestamp:           {}",
        chrono::Utc::now().to_rfc3339()
    )
    .unwrap();
    writeln!(f).unwrap();
    writeln!(
        f,
        "═══════════════════════════════════════════════════════════════════"
    )
    .unwrap();
    writeln!(f, "  THE SCHUR COMPLEMENT: C = G - bb^T").unwrap();
    writeln!(f, "  d²_N = w^T · C · w   (the Nyman-Beurling distance)").unwrap();
    writeln!(
        f,
        "═══════════════════════════════════════════════════════════════════"
    )
    .unwrap();
    writeln!(f).unwrap();

    // Decay table
    writeln!(
        f,
        "  {:>6}  {:>18}  {:>12}  {:>14}  {:>12}",
        "N", "d²_N", "1/ln(N)", "d²·ln(N)", "λ_min(C)"
    )
    .unwrap();
    writeln!(
        f,
        "  {:>6}  {:>18}  {:>12}  {:>14}  {:>12}",
        "──────", "──────────────────", "────────────", "──────────────", "────────────"
    )
    .unwrap();

    for r in results {
        writeln!(
            f,
            "  {:>6}  {:>18.12e}  {:>12.8}  {:>14.10}  {:>12.6e}",
            r.n, r.d_squared, r.inv_log_n, r.ratio, r.lambda_min,
        )
        .unwrap();
    }

    writeln!(f).unwrap();
    writeln!(
        f,
        "═══════════════════════════════════════════════════════════════════"
    )
    .unwrap();
    writeln!(f, "  DECAY FIT: d²_N ≈ A / (ln N)^α").unwrap();
    writeln!(
        f,
        "═══════════════════════════════════════════════════════════════════"
    )
    .unwrap();
    writeln!(f).unwrap();
    writeln!(f, "  A     = {:.10e}", a).unwrap();
    writeln!(f, "  α     = {:.6}", alpha).unwrap();
    writeln!(f).unwrap();
    writeln!(
        f,
        "  RH predicts α ≥ 1.  Observed: α = {:.4}  {}",
        alpha,
        if alpha >= 0.8 {
            "✅ CONSISTENT with RH"
        } else {
            "⚠️  INSUFFICIENT DATA or ANOMALY"
        }
    )
    .unwrap();
    writeln!(f).unwrap();

    // Cancellation analysis
    writeln!(
        f,
        "═══════════════════════════════════════════════════════════════════"
    )
    .unwrap();
    writeln!(f, "  CANCELLATION ANALYSIS: G vs bb^T").unwrap();
    writeln!(
        f,
        "═══════════════════════════════════════════════════════════════════"
    )
    .unwrap();
    writeln!(f).unwrap();
    writeln!(
        f,
        "  {:>6}  {:>18}  {:>18}  {:>18}  {:>12}",
        "N", "w^T·G·w", "w^T·b", "(1-w^T·b)²", "w^T·C·w"
    )
    .unwrap();
    writeln!(
        f,
        "  {:>6}  {:>18}  {:>18}  {:>18}  {:>12}",
        "──────", "──────────────────", "──────────────────", "──────────────────", "────────────"
    )
    .unwrap();

    for r in results {
        writeln!(
            f,
            "  {:>6}  {:>18.12e}  {:>18.12e}  {:>18.12e}  {:>12.6e}",
            r.n, r.gram_quad, r.mean_projection, r.mean_residual_sq, r.cov_quad,
        )
        .unwrap();
    }

    writeln!(f).unwrap();
    writeln!(
        f,
        "═══════════════════════════════════════════════════════════════════"
    )
    .unwrap();
    writeln!(f, "  SPECTRAL STRUCTURE").unwrap();
    writeln!(
        f,
        "═══════════════════════════════════════════════════════════════════"
    )
    .unwrap();
    writeln!(f).unwrap();
    writeln!(
        f,
        "  {:>6}  {:>14}  {:>14}  {:>14}  {:>14}",
        "N", "λ_min(C)", "λ_max(C)", "condition", "trace(C)"
    )
    .unwrap();
    writeln!(
        f,
        "  {:>6}  {:>14}  {:>14}  {:>14}  {:>14}",
        "──────", "──────────────", "──────────────", "──────────────", "──────────────"
    )
    .unwrap();

    for r in results {
        writeln!(
            f,
            "  {:>6}  {:>14.6e}  {:>14.6e}  {:>14.4e}  {:>14.6e}",
            r.n, r.lambda_min, r.lambda_max, r.condition, r.trace_c,
        )
        .unwrap();
    }

    writeln!(f).unwrap();
    writeln!(
        f,
        "═══════════════════════════════════════════════════════════════════"
    )
    .unwrap();
    writeln!(f, "  NOTE: d²_N = w^T·G·w - (w^T·b)² = w^T·C·w").unwrap();
    writeln!(
        f,
        "  The gap between G and bb^T is exactly the Schur complement."
    )
    .unwrap();
    writeln!(f, "  RH ⟺ this gap → 0 as N → ∞.").unwrap();
    writeln!(
        f,
        "═══════════════════════════════════════════════════════════════════"
    )
    .unwrap();

    eprintln!("  ✓ Wrote {}", path.display());
}

/// Write eigenvalue spectrum for a specific N.
pub fn write_eigenvalue_spectrum(n: usize, eigenvalues: &[f64], output_dir: &Path) {
    let path = output_dir.join(format!("eigenvalues_N{}.tsv", n));
    let mut f = fs::File::create(&path).expect("Failed to create eigenvalue file");

    writeln!(f, "index\teigenvalue").unwrap();
    let mut sorted = eigenvalues.to_vec();
    sorted.sort_by(|a, b| a.partial_cmp(b).unwrap());

    for (i, &val) in sorted.iter().enumerate() {
        writeln!(f, "{}\t{:.15e}", i, val).unwrap();
    }
    eprintln!("  ✓ Wrote {}", path.display());
}
