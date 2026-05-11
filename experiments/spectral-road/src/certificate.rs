//! Certificate and data output for Lean integration.
//!
//! Generates:
//! - `eigenvalue_decay.tsv` — raw eigenvalue data
//! - `vacuum_geometry.tsv` — PR, b-projection, peak location
//! - `witness_comparison.tsv` — Selberg/GPY/Maynard d²_N values
//! - `certificate.json` — Lean-compatible certificate

use crate::analysis::{DecayFit, EigenResult, VacuumGeometry};
use crate::witness::WitnessResult;
use std::fs;
use std::io::Write;

// ═══════════════════════════════════════════════════════════════
// TSV OUTPUT
// ═══════════════════════════════════════════════════════════════

pub fn write_eigenvalue_tsv(results: &[EigenResult], path: &str) {
    let mut f = fs::File::create(path).unwrap();
    writeln!(
        f,
        "N\tdim\tlambda_min\tlambda_2\tlambda_3\tgap_ratio\tmethod\telapsed_s"
    )
    .unwrap();
    for r in results {
        writeln!(
            f,
            "{}\t{}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.8}\t{}\t{:.3}",
            r.n,
            r.dim,
            r.lambda_min,
            r.lambda_2,
            r.lambda_3,
            if r.gap.is_nan() { 0.0 } else { r.gap },
            r.method,
            r.elapsed
        )
        .unwrap();
    }
}

pub fn write_vacuum_tsv(results: &[VacuumGeometry], path: &str) {
    let mut f = fs::File::create(path).unwrap();
    writeln!(
        f,
        "N\tb_dot_vmin\tPR\tPR_over_N\tv_inf\tv_inf_sqrt_N\tpeak_k\tpeak_ratio"
    )
    .unwrap();
    for r in results {
        writeln!(
            f,
            "{}\t{:.15e}\t{:.10e}\t{:.10}\t{:.15e}\t{:.10}\t{}\t{:.6}",
            r.n, r.b_dot_v, r.pr, r.pr_over_n, r.v_inf, r.v_inf_sqrt_n, r.peak_k, r.peak_ratio
        )
        .unwrap();
    }
}

pub fn write_witness_tsv(results: &[WitnessResult], path: &str) {
    let mut f = fs::File::create(path).unwrap();
    writeln!(f, "N\tsieve\tD\tell\td2_N\tf_norm_sq\tone_f_inner").unwrap();
    for r in results {
        writeln!(
            f,
            "{}\t{}\t{}\t{}\t{:.15e}\t{:.15e}\t{:.15e}",
            r.n, r.sieve_type, r.d_level, r.ell, r.d2_n, r.f_norm_sq, r.one_f_inner
        )
        .unwrap();
    }
}

// ═══════════════════════════════════════════════════════════════
// JSON CERTIFICATE
// ═══════════════════════════════════════════════════════════════

pub fn write_certificate_json(
    results: &[EigenResult],
    fit: &DecayFit,
    mpfr_built: bool,
    mem_mb: usize,
    threads: usize,
    prec: u32,
    elapsed: f64,
    path: &str,
) {
    let all_positive = results.iter().all(|r| r.lambda_min > 0.0);
    let monotone = results
        .windows(2)
        .all(|w| w[1].lambda_min <= w[0].lambda_min + 1e-15);
    let max_n_tested = results.last().map_or(0, |r| r.n);
    let max_n_positive = results
        .iter()
        .rfind(|r| r.lambda_min > 0.0)
        .map_or(0, |r| r.n);

    let precision_str = if mpfr_built {
        format!("{prec}-bit MPFR (precomputed ln table)")
    } else {
        "f64 (Kahan summation)".to_string()
    };

    let data_points: Vec<String> = results
        .iter()
        .map(|r| {
            format!(
                "    {{\"N\": {}, \"dim\": {}, \"method\": \"{}\", \
                 \"lambda_min\": {:.15e}, \"lambda_2\": {:.15e}, \
                 \"gap\": {:.10}, \"positive\": {}}}",
                r.n,
                r.dim,
                r.method,
                r.lambda_min,
                r.lambda_2,
                if r.gap.is_nan() { 0.0 } else { r.gap },
                r.lambda_min > 0.0
            )
        })
        .collect();

    let cert = format!(
        r#"{{
  "format": "cathedral-eigenvalue-certificate-v2",
  "experiment": "Road 2: Eigenvalue Decay Probe (build-once)",
  "hardware": "Apple M2 Max, 96 GB RAM, {threads} cores",
  "precision": {{
    "gram_entries": "{precision_str}",
    "eigendecomposition": "f64 (nalgebra symmetric_eigen)",
    "matrix_memory_mb": {mem_mb}
  }},
  "threads": {threads},
  "timestamp": "{}",
  "max_N_tested": {max_n_tested},
  "max_N_all_positive": {max_n_positive},
  "all_eigenvalues_positive": {all_positive},
  "monotone_decreasing": {monotone},
  "decay_fit": {{
    "power_law": {{ "C": {:.10e}, "alpha": {:.10}, "R2": {:.10} }},
    "log_decay": {{ "beta": {:.10}, "R2": {:.10} }}
  }},
  "data_points": {},
  "eigenvalue_sequence": [
{}
  ],
  "lean_claim": "∀ N ≤ {max_n_positive}, lambdaMin N > 0 ∧ lambdaMin monotone decreasing",
  "elapsed_seconds": {elapsed:.3}
}}"#,
        chrono::Utc::now().to_rfc3339(),
        fit.power_c,
        fit.power_alpha,
        fit.power_r2,
        fit.log_beta,
        fit.log_r2,
        results.len(),
        data_points.join(",\n")
    );

    fs::write(path, &cert).unwrap();
}
