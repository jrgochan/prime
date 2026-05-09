//! Structural scalar verification — trace, Frobenius norm, Gershgorin bounds.

use cathedral_utils::hpdf::HpdfReader;
use crate::common::*;

/// Verify and display structural scalars (trace, ‖G‖_F, κ, Gershgorin).
/// Returns true if Gershgorin certifies positive definiteness.
pub fn verify_structural(reader: &HpdfReader) -> bool {
    let mut pd = false;
    if let Ok(ss) = reader.read_structural_scalars() {
        println!("  {GREEN}✓{RESET} trace = {:.10}", ss.trace);
        println!("  {GREEN}✓{RESET} ‖G‖_F = {:.10}", ss.frobenius_norm);
        println!(
            "  {GREEN}✓{RESET} κ_est = {:.4} (diag ratio)",
            ss.condition_estimate
        );
        println!(
            "  {GREEN}✓{RESET} off-diag max = {:.10}, avg = {:.10}",
            ss.off_diag_max, ss.off_diag_avg
        );
        if let (Some(g_min), Some(g_max)) = (ss.gershgorin_lambda_min, ss.gershgorin_lambda_max) {
            println!(
                "  {GREEN}✓{RESET} Gershgorin: λ ∈ [{g_min:.10}, {g_max:.10}]"
            );
            if g_min > 0.0 {
                println!("    → positive definite (by Gershgorin)");
                pd = true;
            }
        }
        // New v2 fields
        if let (Some(n1), Some(ni)) = (ss.matrix_1_norm, ss.matrix_inf_norm) {
            println!("  {GREEN}✓{RESET} ‖G‖₁ = {n1:.10}, ‖G‖_∞ = {ni:.10}");
        }
        if let Some(ddr) = ss.diagonal_dominance_ratio {
            let label = if ddr > 1.0 { "diag dominant ✓" } else { "NOT diag dominant" };
            println!("  {GREEN}✓{RESET} diag dominance ratio = {ddr:.6} ({label})");
        }
        if let (Some(emin), Some(emax)) = (ss.entry_min, ss.entry_max) {
            println!("  {GREEN}✓{RESET} entry range = [{emin:.10}, {emax:.10}]");
        }
        if let (Some(em), Some(ev)) = (ss.entry_mean, ss.entry_variance) {
            println!("  {GREEN}✓{RESET} entry mean = {em:.10}, var = {ev:.4e}");
        }
        if let Some(sr) = ss.symmetry_residual {
            println!("  {GREEN}✓{RESET} symmetry residual = {sr:.2e}");
        }
        if let Some(dsq) = ss.diag_sum_sq {
            println!("  {GREEN}✓{RESET} Σ G_ii² = {dsq:.10}");
        }
    }
    pd
}

/// Display column norms.
pub fn show_col_norms(reader: &HpdfReader) {
    if let Ok(cn) = reader.read_col_norms() {
        println!(
            "  {GREEN}✓{RESET} col_norms: {} entries, range [{:.6}, {:.6}]",
            cn.len(),
            cn.iter().cloned().fold(f64::INFINITY, f64::min),
            cn.iter().cloned().fold(f64::NEG_INFINITY, f64::max)
        );
    }
}

/// Verify diagonal against stored data.
pub fn verify_diagonal(reader: &HpdfReader, original_data: Option<&[f64]>, dim: usize) {
    let diag = reader.read_diagonal().unwrap();
    if let Some(data) = original_data {
        let d_err: f64 = diag
            .iter()
            .enumerate()
            .map(|(i, &d)| (d - data[i * dim + i]).abs())
            .fold(0.0, f64::max);
        println!("  {GREEN}✓{RESET} diagonal max error: {d_err:.2e}");
    }
}
