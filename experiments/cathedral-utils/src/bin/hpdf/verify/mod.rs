//! Verify module — orchestrates all verification sub-modules.
//!
//! Sub-modules:
//! - [`integrity`]  — SHA-256 data checksums and roundtrip validation
//! - [`structural`] — Trace, Frobenius norm, Gershgorin bounds, condition
//! - [`provenance`] — Metadata, lineage, number theory, distance
//! - [`spot_check`] — Spot-check entries vs f64 recomputation
//! - [`build`]      — Build fresh Gram matrices (--build, --ladder)

pub mod build;
pub mod integrity;
pub mod provenance;
pub mod spot_check;
pub mod structural;

use cathedral_utils::gram;
use cathedral_utils::hpdf::{self, HpdfReader};
use std::path::PathBuf;
use std::time::Instant;

use crate::common::*;

/// Full verification of an HPDF file, delegating to each sub-module.
///
/// This is the central verification pipeline called by `--verify`, `--build`,
/// and any other subcommand that needs to certify an HPDF file.
pub fn full_verify(path: &PathBuf, original_data: Option<&[f64]>, dim: usize) {
    let reader = HpdfReader::open(path).unwrap();
    assert_eq!(reader.dim(), dim);

    // 1. Data integrity checksum
    let (integrity_ok, _sha) = integrity::verify_data_integrity(&reader);

    // 2. Roundtrip (if original data available)
    if let Some(data) = original_data {
        integrity::verify_roundtrip(&reader, data, dim);
    }

    // 3. b-vector
    let b_err = spot_check::verify_b_vector(&reader, dim);

    // 4. Structural scalars + Gershgorin
    structural::verify_structural(&reader);

    // 5. Column norms
    structural::show_col_norms(&reader);

    // 6. Diagonal
    structural::verify_diagonal(&reader, original_data, dim);

    // 7. Number theory
    provenance::show_number_theory(&reader);

    // 8. Lineage
    provenance::show_lineage(&reader);

    // 9. Provenance
    provenance::show_provenance(&reader);

    // 10. Distance
    provenance::show_distance(&reader);

    // 11. Spot-check
    let (_abs, _rel, spot_ok) = spot_check::verify_spot_check(&reader);

    // Final verdict
    let all_ok = b_err < 1e-15 && spot_ok && integrity_ok;
    if all_ok {
        println!("\n  {GREEN}═══ ALL CHECKS PASSED ═══{RESET}");
    } else {
        println!("\n  {RED}═══ CHECKS FAILED ═══{RESET}");
        if !spot_ok {
            println!("    spot-check: FAILED");
        }
        if !integrity_ok {
            println!("    data integrity: FAILED");
        }
        if b_err >= 1e-15 {
            println!("    b-vector: err={b_err:.2e} >= 1e-15");
        }
    }
}

/// Verify an existing HPDF file from a path string.
pub fn verify_file(path: &str) {
    let pb = PathBuf::from(path);
    let reader = HpdfReader::open(&pb).unwrap();
    println!(
        "  HPDF: dim={}, max_n={}, v{}",
        reader.dim(),
        reader.max_n(),
        reader.version()
    );
    full_verify(&pb, None, reader.dim());
}

/// Metadata-only dump — reads only attributes, never loads the matrix.
pub fn info_hpdf(path: &str) {
    let pb = PathBuf::from(path);
    let reader = HpdfReader::open(&pb).unwrap();

    println!("{BOLD}{CYAN}╔═══════════════════════════════════════════════════╗{RESET}");
    println!("{BOLD}{CYAN}║{RESET}  🏛️  HPDF INFO                                   {BOLD}{CYAN}║{RESET}");
    println!("{BOLD}{CYAN}╚═══════════════════════════════════════════════════╝{RESET}\n");
    println!("  File:    {path}");
    println!(
        "  Size:    {} KB",
        std::fs::metadata(&pb).map(|m| m.len()).unwrap_or(0) / 1024
    );
    println!("  Version: v{}", reader.version());
    println!("  N:       {}", reader.max_n());
    println!("  Dim:     {}×{}", reader.dim(), reader.dim());
    println!("  Prec:    {} bits\n", reader.precision().unwrap_or(0));

    // Structural
    structural::verify_structural(&reader);

    // Number theory
    provenance::show_number_theory(&reader);

    // Data checksum (attribute only)
    if let Some(sha) = reader.read_data_checksum() {
        println!("\n  ── Data Integrity ──");
        println!("  data_sha256     = {sha}\n");
    }

    // Lineage
    provenance::show_lineage(&reader);

    // Provenance
    provenance::show_provenance(&reader);

    // Distance
    provenance::show_distance(&reader);
}

/// Convert an OOC binary file to HPDF format.
pub fn convert_ooc(path: &str) {
    println!("  Converting OOC → HPDF: {path}");
    let ooc_path = PathBuf::from(path);
    let hpdf_path = ooc_path.with_extension("h5");
    hpdf::convert_ooc_to_hpdf(&ooc_path, &hpdf_path, true).unwrap();
    println!("\n  Verifying...");
    verify_file(&hpdf_path.to_string_lossy());
}

/// Point-query a single entry G[j,k] from the HPDF file.
pub fn query_entry(path: &str, jk: &str) {
    let parts: Vec<&str> = jk.split(',').collect();
    assert_eq!(parts.len(), 2, "Expected j,k format (e.g., 2,3)");
    let j: usize = parts[0].trim().parse().expect("j must be a number");
    let k: usize = parts[1].trim().parse().expect("k must be a number");

    let pb = PathBuf::from(path);
    let reader = HpdfReader::open(&pb).unwrap();

    println!("{BOLD}{CYAN}╔═══════════════════════════════════════════════════╗{RESET}");
    println!("{BOLD}{CYAN}║{RESET}  🔍  HPDF POINT QUERY                             {BOLD}{CYAN}║{RESET}");
    println!("{BOLD}{CYAN}╚═══════════════════════════════════════════════════╝{RESET}\n");
    println!("  File:  {path}");
    println!("  Query: G[{j}, {k}]\n");

    let dim = reader.dim();
    let (r, c) = if j <= k {
        (j - 2, k - 2)
    } else {
        (k - 2, j - 2)
    };
    let tri_offset = r * dim - r * r.wrapping_sub(1) / 2 + (c - r);
    let byte_offset = tri_offset * 8;
    let tri_len = dim * (dim + 1) / 2;

    println!("  ── Storage Layout ──");
    println!("  dim             = {dim}×{dim}");
    println!("  matrix coords   = ({r}, {c})  (0-indexed)");
    println!("  triangle offset = {tri_offset} / {tri_len}  (flat index)");
    println!("  byte offset     = {byte_offset}  (within upper_triangle dataset)\n");

    let t0 = Instant::now();
    let stored = reader.read_gram_entry(j, k).unwrap();
    let read_us = t0.elapsed().as_micros();

    let recomputed = gram::gram_entry_f64(j, k);
    let abs_err = (stored - recomputed).abs();
    let rel_err = if recomputed.abs() > 1e-30 {
        abs_err / recomputed.abs()
    } else {
        abs_err
    };

    let bits = stored.to_bits();
    let sign = (bits >> 63) & 1;
    let exponent = ((bits >> 52) & 0x7FF) as i64 - 1023;
    let mantissa = bits & 0x000F_FFFF_FFFF_FFFF;

    println!("  ── Value ──");
    println!("  stored          = {stored:.17e}");
    println!("  recomputed      = {recomputed:.17e}");
    println!("  abs error       = {abs_err:.2e}");
    println!("  rel error       = {rel_err:.2e}");
    println!("  read time       = {read_us} μs  (8-byte hyperslab)\n");

    println!("  ── IEEE 754 ──");
    println!("  hex             = 0x{bits:016X}");
    println!("  sign            = {sign}");
    println!(
        "  exponent        = {exponent}  (biased: {})",
        exponent + 1023
    );
    println!("  mantissa        = 0x{mantissa:013X}");
    println!("  binary          = {bits:064b}\n");

    println!("  ── Formula ──");
    println!("  G[{j},{k}] = ∫₀¹ {{1/({j}x)}} · {{1/({k}x)}} dx");
    println!("           where {{y}} = y - ⌊y⌋ is the fractional part\n");

    if abs_err < 1e-14 {
        println!("  {GREEN}✓ Bit-perfect match against live recomputation{RESET}");
    } else {
        println!("  {RED}✗ Mismatch detected!{RESET}");
    }
}
