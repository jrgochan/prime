//! # Cathedral HPDF — High-Precision Data Format
//!
//! HDF5-backed storage for Gram matrices and associated precomputed data.
//! Bundles the matrix, b-vector, structural metadata, number-theoretic
//! tables, spectral invariants, and provenance into a single self-describing file.
//!
//! ## File Layout (v2)
//!
//! ```text
//! ROOT attrs: { format, version, max_n, dim }
//!
//! /gram/upper_triangle    [M, float64]   — packed upper triangle (row-major), hi words
//! /gram/upper_triangle_lo [M, float64]   — packed upper triangle (row-major), DD lo words (optional)
//! /gram/attrs: { max_n, dim, precision, entry_formula, data_sha256,
//!                dd_stored, data_lo_sha256 }
//!
//! /b_vector               [dim, float64] — b_k = (ln(k+2)+1-γ)/(k+2)
//! /b_vector/attrs: { norm, norm_squared, sum, max_entry, min_entry, formula }
//!
//! /structure/diagonal     [dim, float64] — G[j,j]
//! /structure/row_sums     [dim, float64] — Σ_k G[j,k]
//! /structure/col_norms    [dim, float64] — ‖G[:,k]‖₂
//! /structure/attrs: { diagonal_min, diagonal_max, trace, frobenius_norm,
//!                     condition_estimate, off_diagonal_max, off_diagonal_avg,
//!                     gershgorin_lambda_min, gershgorin_lambda_max }
//!
//! /number_theory/mobius   [max_n+1, int8]   — μ(n)
//! /number_theory/totient  [max_n+1, uint32] — φ(n)
//! /number_theory/primes   [π(max_n), uint32]
//! /number_theory/attrs: { prime_count, factorization, max_n,
//!                         divisor_count, divisor_sum, is_highly_composite }
//!
//! /provenance/attrs: { timestamp, builder, precision, source_sha256,
//!                      hpdf_version, git_commit, hostname,
//!                      build_time_secs, rust_version, target_arch, target_os }
//!
//! /lineage/attrs: { parent_path, parent_sha256, parent_max_n,
//!                   derivation, timestamp }  (optional, for derived files)
//!
//! /distance/attrs: { d_squared, solver, iterations, residual_norm,
//!                    converged, bt_x, solution_dim, history_len, timestamp }
//! /distance/solution_vector      [dim, float64]  (optional, post-solve)
//! /distance/convergence_history  [iters, float64] (optional, post-solve)
//! ```
//!
//! ## Feature Gate
//!
//! This module requires the `hpdf` feature:
//! ```toml
//! cathedral-utils = { path = "../cathedral-utils", features = ["hpdf"] }
//! ```

pub mod convert;
pub mod helpers;
pub mod metadata;
pub mod reader;
pub mod writer;

// ── Constants ──

/// HPDF file format version.
pub const HPDF_VERSION: u32 = 2;

/// Magic string stored as an attribute for format identification.
pub const HPDF_MAGIC: &str = "CATHEDRAL_HPDF_V2";

// ── Public re-exports ──

pub use convert::{convert_ooc_to_hpdf, extract_from_hpdf, extract_submatrix_hpdf};
pub use metadata::{stamp_distance, stamp_microscope, DistanceResult, MicroscopeResult};
pub use reader::{
    DataIntegrity, DistanceScalars, HpdfProvenance, HpdfReader, LineageInfo as ReadLineageInfo,
    NumberTheoryAttrs, StructuralScalars,
};
pub use writer::{
    write_hpdf, write_hpdf_dd, write_hpdf_dd_from_triangle, write_hpdf_from_triangle,
    HpdfWriterConfig,
};

// ═══════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;
    use crate::gram;

    #[test]
    fn test_roundtrip_small() {
        let max_n = 20;
        let dim = max_n - 1;
        let mut data = vec![0.0f64; dim * dim];
        for i in 0..dim {
            for j in i..dim {
                let v = gram::gram_entry_f64(i + 2, j + 2);
                data[i * dim + j] = v;
                data[j * dim + i] = v;
            }
        }

        let dir =
            std::env::temp_dir().join(format!("cathedral_hpdf_roundtrip_{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join("test_N20.h5");

        let config = HpdfWriterConfig {
            max_n,
            precision: 0,
            source_sha256: "test".to_string(),
            builder: "test".to_string(),
            include_number_theory: true,
        };

        write_hpdf(&path, &data, &config).unwrap();

        let reader = HpdfReader::open(&path).unwrap();
        assert_eq!(reader.dim(), dim);
        assert_eq!(reader.max_n(), max_n);
        assert_eq!(reader.version(), 2);

        // Roundtrip fidelity
        let read_data = reader.read_gram_full().unwrap();
        for i in 0..dim * dim {
            assert!(
                (data[i] - read_data[i]).abs() < 1e-15,
                "Mismatch at {i}: {} vs {}",
                data[i],
                read_data[i]
            );
        }

        // Data integrity checksum
        let integrity = reader.verify_data_integrity().unwrap();
        assert!(
            integrity.valid,
            "Data checksum mismatch: stored={:?}, computed={}",
            integrity.stored_sha256, integrity.computed_sha256
        );

        // b-vector
        let b = reader.read_b_vector().unwrap();
        assert_eq!(b.len(), dim);

        // Structural scalars with Gershgorin bounds
        let ss = reader.read_structural_scalars().unwrap();
        assert!(ss.trace > 0.0);
        assert!(ss.frobenius_norm > 0.0);
        assert!(ss.condition_estimate > 1.0);
        assert!(ss.gershgorin_lambda_min.is_some());
        assert!(ss.gershgorin_lambda_max.is_some());
        let g_min = ss.gershgorin_lambda_min.unwrap();
        let g_max = ss.gershgorin_lambda_max.unwrap();
        assert!(
            g_max > g_min,
            "Gershgorin: λ_max={g_max} should > λ_min={g_min}"
        );

        // Column norms
        let cn = reader.read_col_norms().unwrap();
        assert_eq!(cn.len(), dim);
        assert!(cn.iter().all(|&v| v > 0.0));

        // Number theory
        let mu = reader.read_mobius().unwrap();
        assert_eq!(mu[1], 1);
        assert_eq!(mu[2], -1);
        assert_eq!(mu[4], 0);

        // Number theory attributes
        let nt = reader.read_number_theory_attrs().unwrap().unwrap();
        assert!(nt.prime_count > 0);
        assert!(nt.divisor_count > 0);
        assert!(!nt.factorization.is_empty());

        // Provenance
        let prov = reader.read_provenance().unwrap();
        assert_eq!(prov.builder, "test");
        assert!(!prov.git_commit.is_empty());

        // No distance yet
        assert!(reader.read_distance().unwrap().is_none());
        // No lineage (not derived)
        assert!(reader.read_lineage().unwrap().is_none());

        std::fs::remove_file(&path).ok();
    }

    #[test]
    fn test_point_query() {
        let max_n = 15;
        let dim = max_n - 1;
        let mut data = vec![0.0f64; dim * dim];
        for i in 0..dim {
            for j in i..dim {
                let v = gram::gram_entry_f64(i + 2, j + 2);
                data[i * dim + j] = v;
                data[j * dim + i] = v;
            }
        }

        let dir = std::env::temp_dir().join(format!("cathedral_hpdf_query_{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join("test_N15_query.h5");

        let config = HpdfWriterConfig {
            max_n,
            precision: 0,
            source_sha256: "test".to_string(),
            builder: "test".to_string(),
            include_number_theory: false,
        };

        write_hpdf(&path, &data, &config).unwrap();
        let reader = HpdfReader::open(&path).unwrap();

        // Verify every single entry via point query
        for j in 2..=max_n {
            for k in 2..=max_n {
                let stored = reader.read_gram_entry(j, k).unwrap();
                let expected = gram::gram_entry_f64(j, k);
                assert!(
                    (stored - expected).abs() < 1e-15,
                    "Point query G[{j},{k}]: stored={stored}, expected={expected}"
                );
            }
        }

        // Row read
        let row = reader.read_gram_row(0).unwrap();
        assert_eq!(row.len(), dim);
        for (col, &v) in row.iter().enumerate() {
            let expected = gram::gram_entry_f64(2, col + 2);
            assert!(
                (v - expected).abs() < 1e-15,
                "Row read [0,{col}]: got={v}, expected={expected}"
            );
        }

        // Submatrix read
        let sub = reader.read_gram_submatrix(0, 2, 0, 2).unwrap();
        assert_eq!(sub.len(), 9); // 3×3
        for i in 0..3 {
            for j_idx in 0..3 {
                let expected = gram::gram_entry_f64(i + 2, j_idx + 2);
                assert!((sub[i * 3 + j_idx] - expected).abs() < 1e-15);
            }
        }

        std::fs::remove_file(&path).ok();
    }

    #[test]
    fn test_dd_roundtrip() {
        let max_n = 15;
        let dim = max_n - 1;

        // Build hi and lo matrices (lo = small perturbation to simulate DD)
        let mut hi = vec![0.0f64; dim * dim];
        let mut lo = vec![0.0f64; dim * dim];
        for i in 0..dim {
            for j in i..dim {
                let v = gram::gram_entry_f64(i + 2, j + 2);
                hi[i * dim + j] = v;
                hi[j * dim + i] = v;
                // lo word: small correction (~1e-16 scale)
                let lv = v * 1e-16;
                lo[i * dim + j] = lv;
                lo[j * dim + i] = lv;
            }
        }

        let dir = std::env::temp_dir().join(format!("cathedral_hpdf_dd_{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join("test_N15_dd.h5");

        let config = HpdfWriterConfig {
            max_n,
            precision: 0,
            source_sha256: "test_dd".to_string(),
            builder: "test_dd".to_string(),
            include_number_theory: false,
        };

        write_hpdf_dd(&path, &hi, &lo, &config).unwrap();

        let reader = HpdfReader::open(&path).unwrap();
        assert_eq!(reader.dim(), dim);
        assert!(reader.has_dd(), "DD flag should be set");

        // Read hi — same as normal
        let read_hi = reader.read_gram_full().unwrap();
        for i in 0..dim * dim {
            assert!(
                (hi[i] - read_hi[i]).abs() < 1e-15,
                "Hi mismatch at {i}: {} vs {}",
                hi[i],
                read_hi[i]
            );
        }

        // Read lo
        let read_lo = reader.read_gram_lo_full().unwrap();
        assert!(read_lo.is_some(), "DD lo data should be present");
        let read_lo = read_lo.unwrap();
        for i in 0..dim * dim {
            assert!(
                (lo[i] - read_lo[i]).abs() < 1e-30,
                "Lo mismatch at {i}: {} vs {}",
                lo[i],
                read_lo[i]
            );
        }

        // Combined read
        let (rh, rl) = reader.read_gram_full_dd().unwrap();
        assert_eq!(rh.len(), dim * dim);
        assert_eq!(rl.len(), dim * dim);

        // Integrity (both hi and lo)
        let integrity = reader.verify_data_integrity().unwrap();
        assert!(integrity.valid, "Overall integrity failed");
        assert_eq!(integrity.dd_lo_valid, Some(true), "DD lo integrity failed");

        std::fs::remove_file(&path).ok();
    }
}
