//! Spot-check verification — compare stored entries against f64 recomputation.

use cathedral_utils::hpdf::HpdfReader;
use crate::common::*;

/// Run a spot-check of stored entries against live f64 recomputation.
///
/// Returns (abs_err, rel_err, pass).
pub fn verify_spot_check(reader: &HpdfReader) -> (f64, f64, bool) {
    let dim = reader.dim();
    let n_checks = std::cmp::min(1000, dim * dim);
    let (abs, rel) = reader
        .verify_spot_check(n_checks)
        .expect("Spot-check failed");
    println!(
        "  {GREEN}✓{RESET} Spot-check ({n_checks} entries): abs={abs:.2e}, rel={rel:.2e}"
    );

    // Precision-aware pass/fail threshold
    let stored_precision = reader.precision().unwrap_or(0);
    let prov = reader.read_provenance().ok();
    let is_dd_built = prov
        .as_ref()
        .map_or(false, |p| p.builder.contains("DD"));

    let spot_threshold = if stored_precision > 0 {
        println!(
            "    {DIM}(note: file built at {stored_precision}-bit MPFR; f64 baseline is less accurate){RESET}"
        );
        1e-3
    } else if is_dd_built {
        println!(
            "    {DIM}(note: DD-built file; expected ~1e-8 ceiling from DD→f64 truncation){RESET}"
        );
        1e-7
    } else {
        1e-14
    };

    let pass = abs < spot_threshold;
    (abs, rel, pass)
}

/// Verify the b-vector against recomputation.
/// Returns the max error.
pub fn verify_b_vector(reader: &HpdfReader, dim: usize) -> f64 {
    use cathedral_utils::arith;
    let b = reader.read_b_vector().unwrap();
    let b_ref = arith::b_vector(dim);
    let b_err: f64 = b
        .iter()
        .zip(b_ref.iter())
        .map(|(a, b)| (a - b).abs())
        .fold(0.0, f64::max);
    println!("  {GREEN}✓{RESET} b-vector max error: {b_err:.2e}");
    b_err
}
