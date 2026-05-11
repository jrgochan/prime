//! Certificate generation for the NB distance probe.
//!
//! Produces machine-readable JSON and human-readable TSV that
//! constitute verifiable evidence for or against d²_N → 0.

use crate::solver::DistanceResult;
use std::io::Write;
use std::path::Path;

/// Write the full TSV data file.
pub fn write_tsv(path: &Path, results: &[DistanceResult]) -> std::io::Result<()> {
    let mut f = std::fs::File::create(path)?;
    writeln!(
        f,
        "N\td2_N\tlambda_min\tlambda_max\tcondition\tcoeff_energy\tcoeff_mass\tprojection"
    )?;
    for r in results {
        writeln!(
            f,
            "{}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.6e}\t{:.10e}\t{:.10e}\t{:.15e}",
            r.n,
            r.d2,
            r.lambda_min,
            r.lambda_max,
            r.condition,
            r.coeff_energy,
            r.coeff_mass,
            r.projection
        )?;
    }
    Ok(())
}

/// Write the certificate JSON.
pub fn write_certificate(
    path: &Path,
    results: &[DistanceResult],
    precision: u32,
    fit_alpha: f64,
    fit_c: f64,
    fit_r2: f64,
) -> std::io::Result<()> {
    let mut f = std::fs::File::create(path)?;
    let max_n = results.last().map_or(0, |r| r.n);
    let min_d2 = results.iter().map(|r| r.d2).fold(f64::INFINITY, f64::min);
    let all_positive = results.iter().all(|r| r.d2 > 0.0);
    let monotone_after_10 = results
        .windows(2)
        .filter(|w| w[0].n >= 10)
        .all(|w| w[1].d2 <= w[0].d2 + 1e-10);

    writeln!(f, "{{")?;
    writeln!(f, "  \"experiment\": \"Nyman-Beurling Distance Probe\",")?;
    writeln!(
        f,
        "  \"description\": \"Unconstrained L² distance: d²_N = 1 - b^T G_N^{{-1}} b\","
    )?;
    writeln!(f, "  \"equivalence\": \"RH ⟺ d²_N → 0 as N → ∞\",")?;
    writeln!(f, "  \"b_vector\": \"b_k = (ln k + 1 - γ) / k\",")?;
    writeln!(f, "  \"gram_precision_bits\": {},", precision)?;
    writeln!(f, "  \"max_n\": {},", max_n)?;
    writeln!(f, "  \"num_points\": {},", results.len())?;
    writeln!(f, "  \"min_d2\": {:.15e},", min_d2)?;
    writeln!(f, "  \"all_d2_positive\": {},", all_positive)?;
    writeln!(
        f,
        "  \"monotone_decreasing_after_10\": {},",
        monotone_after_10
    )?;
    writeln!(f, "  \"decay_fit\": {{")?;
    writeln!(f, "    \"model\": \"d²_N ~ C · N^(-α)\",")?;
    writeln!(f, "    \"C\": {:.10e},", fit_c)?;
    writeln!(f, "    \"alpha\": {:.10},", fit_alpha)?;
    writeln!(f, "    \"R2\": {:.10}", fit_r2)?;
    writeln!(f, "  }},")?;

    // Write individual data points
    writeln!(f, "  \"data\": [")?;
    for (i, r) in results.iter().enumerate() {
        let comma = if i + 1 < results.len() { "," } else { "" };
        writeln!(
            f,
            "    {{\"N\": {}, \"d2\": {:.15e}, \"lambda_min\": {:.10e}, \"kappa\": {:.6e}}}{comma}",
            r.n, r.d2, r.lambda_min, r.condition
        )?;
    }
    writeln!(f, "  ]")?;
    writeln!(f, "}}")?;
    Ok(())
}
