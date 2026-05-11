//! Data integrity verification — SHA-256 checksums and roundtrip validation.

use crate::common::*;
use cathedral_utils::hpdf::HpdfReader;

/// Verify the data integrity checksum stored in the HPDF file.
/// Returns (valid, computed_sha256).
pub fn verify_data_integrity(reader: &HpdfReader) -> (bool, String) {
    match reader.verify_data_integrity() {
        Ok(integrity) => {
            if integrity.valid {
                println!(
                    "  {GREEN}✓{RESET} Data SHA-256: {}... (verified)",
                    &integrity.computed_sha256[..16]
                );
                (true, integrity.computed_sha256)
            } else if integrity.stored_sha256.is_none() {
                println!("  {YELLOW}⚠{RESET} No data checksum (v1 file)");
                (true, integrity.computed_sha256) // v1 files pass by default
            } else {
                println!("  {RED}✗ DATA CHECKSUM MISMATCH!{RESET}");
                println!("    stored:   {:?}", integrity.stored_sha256);
                println!("    computed: {}", integrity.computed_sha256);
                (false, integrity.computed_sha256)
            }
        }
        Err(e) => {
            println!("  {RED}✗ Integrity check failed: {e}{RESET}");
            (false, String::new())
        }
    }
}

/// Verify roundtrip accuracy: compare stored matrix against original data.
pub fn verify_roundtrip(reader: &HpdfReader, original_data: &[f64], dim: usize) -> f64 {
    let read_data = reader.read_gram_full().unwrap();
    let max_err: f64 = (0..dim * dim)
        .map(|i| (original_data[i] - read_data[i]).abs())
        .fold(0.0, f64::max);
    println!("  {GREEN}✓{RESET} Roundtrip max error: {max_err:.2e}");
    max_err
}
