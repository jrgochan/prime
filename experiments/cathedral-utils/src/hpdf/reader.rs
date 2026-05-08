//! HPDF reader — load and query Cathedral HDF5 files.

use hdf5::File as H5File;
use ndarray::Array1;
use std::path::Path;
use std::time::Instant;

use super::helpers::{read_str_attr, read_str_opt, read_scalar_opt, sha256_hex};
use super::HPDF_MAGIC;

/// An opened HPDF file for reading.
pub struct HpdfReader {
    file: H5File,
    dim: usize,
    max_n: usize,
}

impl HpdfReader {
    /// Open an HPDF file for reading.
    ///
    /// Accepts both v1 (CATHEDRAL_HPDF_V1) and v2 (CATHEDRAL_HPDF_V2) files.
    pub fn open(path: &Path) -> hdf5::Result<Self> {
        let file = H5File::open(path)?;

        let format: String = read_str_attr(&file, "format")?;
        assert!(
            format == HPDF_MAGIC || format == "CATHEDRAL_HPDF_V1",
            "Not a valid HPDF file (magic={format}, expected {HPDF_MAGIC} or V1)"
        );

        let dim: u64 = file.attr("dim")?.read_scalar()?;
        let max_n: u64 = file.attr("max_n")?.read_scalar()?;

        Ok(Self { file, dim: dim as usize, max_n: max_n as usize })
    }

    /// Matrix dimension (N-1).
    pub fn dim(&self) -> usize { self.dim }

    /// Maximum N parameter.
    pub fn max_n(&self) -> usize { self.max_n }

    /// HPDF format version stored in the file.
    pub fn version(&self) -> u32 {
        read_scalar_opt::<u32>(&self.file, "version").unwrap_or(1)
    }

    /// MPFR precision bits used for construction.
    pub fn precision(&self) -> hdf5::Result<u32> {
        let gram = self.file.group("gram")?;
        Ok(gram.attr("precision")?.read_scalar()?)
    }

    /// Check whether this HPDF file contains DD (double-double) lo-word data.
    ///
    /// When true, the file stores both `/gram/upper_triangle` (hi) and
    /// `/gram/upper_triangle_lo` (lo), giving ~31-digit precision per entry.
    pub fn has_dd(&self) -> bool {
        self.file.group("gram")
            .ok()
            .and_then(|g| read_scalar_opt::<u32>(&g, "dd_stored"))
            .unwrap_or(0) != 0
    }

    /// Read the upper triangle back into a full symmetric dim×dim matrix.
    pub fn read_gram_full(&self) -> hdf5::Result<Vec<f64>> {
        let t0 = Instant::now();
        let ds = self.file.dataset("gram/upper_triangle")?;
        let tri: Array1<f64> = ds.read_1d()?;
        let tri = tri.to_vec();

        let dim = self.dim;
        let mut mat = vec![0.0f64; dim * dim];
        let mut idx = 0;
        for row in 0..dim {
            for col in row..dim {
                let v = tri[idx];
                mat[row * dim + col] = v;
                mat[col * dim + row] = v;
                idx += 1;
            }
        }

        eprintln!("  \x1b[32m✓\x1b[0m HPDF gram read: {dim}×{dim} ({:.1}s)",
            t0.elapsed().as_secs_f64());
        Ok(mat)
    }

    /// Read the DD lo-word upper triangle into a full symmetric dim×dim matrix.
    ///
    /// Returns `None` if this HPDF file does not contain DD data.
    pub fn read_gram_lo_full(&self) -> hdf5::Result<Option<Vec<f64>>> {
        if !self.has_dd() {
            return Ok(None);
        }
        let ds = self.file.dataset("gram/upper_triangle_lo")?;
        let tri: Array1<f64> = ds.read_1d()?;
        let tri = tri.to_vec();

        let dim = self.dim;
        let mut mat = vec![0.0f64; dim * dim];
        let mut idx = 0;
        for row in 0..dim {
            for col in row..dim {
                let v = tri[idx];
                mat[row * dim + col] = v;
                mat[col * dim + row] = v;
                idx += 1;
            }
        }
        Ok(Some(mat))
    }

    /// Read both hi and lo words as (hi_matrix, lo_matrix).
    ///
    /// If the file has no DD data, `lo_matrix` will be all zeros.
    /// This is the preferred way to load DD Gram data for DD Cholesky.
    pub fn read_gram_full_dd(&self) -> hdf5::Result<(Vec<f64>, Vec<f64>)> {
        let hi = self.read_gram_full()?;
        let lo = self.read_gram_lo_full()?
            .unwrap_or_else(|| vec![0.0f64; self.dim * self.dim]);
        Ok((hi, lo))
    }

    // ── Point Query API ─────────────────────────────────────────
    //
    // The upper triangle is packed row-major: for a dim×dim symmetric
    // matrix, entry G[row, col] (0-indexed, row ≤ col) is at flat offset:
    //
    //   idx = row × dim − row×(row−1)/2 + (col − row)
    //
    // HDF5 hyperslab selection lets us read exactly that single f64
    // (8 bytes) from disk — O(1) random access with zero full-matrix load.

    /// Compute the flat index into the packed upper triangle for entry (row, col).
    ///
    /// Both row and col are 0-indexed into the dim×dim matrix.
    /// Automatically handles symmetry: if row > col, they are swapped.
    fn tri_index(&self, row: usize, col: usize) -> usize {
        let (r, c) = if row <= col { (row, col) } else { (col, row) };
        debug_assert!(c < self.dim, "col {c} out of range (dim={})", self.dim);
        r * self.dim - r * (r.wrapping_sub(1)) / 2 + (c - r)
    }

    /// Read a single matrix entry G[j, k] without loading the full matrix.
    ///
    /// `j` and `k` are **Gram indices** (2-based): G[j,k] where j,k ∈ {2, ..., max_n}.
    /// Internally converts to 0-based matrix coordinates and performs a single
    /// 8-byte HDF5 hyperslab read.
    ///
    /// ```text
    /// reader.read_gram_entry(2, 2)  →  G[2,2] = ∫₀¹ {1/(2x)}² dx
    /// reader.read_gram_entry(3, 5)  →  G[3,5] = ∫₀¹ {1/(3x)}{1/(5x)} dx
    /// ```
    pub fn read_gram_entry(&self, j: usize, k: usize) -> hdf5::Result<f64> {
        assert!(j >= 2 && j <= self.max_n, "j={j} out of range [2, {}]", self.max_n);
        assert!(k >= 2 && k <= self.max_n, "k={k} out of range [2, {}]", self.max_n);

        let row = j - 2;
        let col = k - 2;
        let idx = self.tri_index(row, col);

        let ds = self.file.dataset("gram/upper_triangle")?;
        let slice = ds.read_slice_1d::<f64, _>(ndarray::s![idx..idx + 1])?;
        Ok(slice[0])
    }

    /// Read a single matrix entry by 0-based matrix coordinates.
    ///
    /// `row` and `col` are 0-indexed: G_mat[row, col] corresponds to
    /// Gram index G[row+2, col+2].
    pub fn read_entry_raw(&self, row: usize, col: usize) -> hdf5::Result<f64> {
        assert!(row < self.dim && col < self.dim,
            "({row},{col}) out of range for dim={}", self.dim);

        let idx = self.tri_index(row, col);
        let ds = self.file.dataset("gram/upper_triangle")?;
        let slice = ds.read_slice_1d::<f64, _>(ndarray::s![idx..idx + 1])?;
        Ok(slice[0])
    }

    /// Read a full row of the Gram matrix (0-indexed) via targeted slice reads.
    ///
    /// Returns a Vec of length `dim` containing all G_mat[row, 0..dim].
    /// More efficient than `read_gram_full()` when you only need one row.
    pub fn read_gram_row(&self, row: usize) -> hdf5::Result<Vec<f64>> {
        assert!(row < self.dim, "row {row} out of range (dim={})", self.dim);
        let ds = self.file.dataset("gram/upper_triangle")?;
        let dim = self.dim;
        let mut result = vec![0.0f64; dim];

        // Entries where this row is the "upper" index: G[row, col] for col >= row
        // These are contiguous in the packed triangle starting at tri_index(row, row).
        let start = self.tri_index(row, row);
        let count = dim - row;
        let upper_slice = ds.read_slice_1d::<f64, _>(ndarray::s![start..start + count])?;
        for (i, &v) in upper_slice.iter().enumerate() {
            result[row + i] = v;
        }

        // Entries where this row is the "lower" index: G[r, row] for r < row
        // These are scattered — one entry per earlier row.
        for r in 0..row {
            let idx = self.tri_index(r, row);
            let v = ds.read_slice_1d::<f64, _>(ndarray::s![idx..idx + 1])?;
            result[r] = v[0];
        }

        Ok(result)
    }

    /// Read a contiguous submatrix G[r0..r1, c0..c1] (0-indexed, inclusive).
    ///
    /// Returns a flat (r1-r0+1)×(c1-c0+1) row-major array.
    pub fn read_gram_submatrix(
        &self,
        r0: usize, r1: usize,
        c0: usize, c1: usize,
    ) -> hdf5::Result<Vec<f64>> {
        assert!(r1 < self.dim && c1 < self.dim && r0 <= r1 && c0 <= c1);
        let rows = r1 - r0 + 1;
        let cols = c1 - c0 + 1;
        let mut result = vec![0.0f64; rows * cols];

        for i in 0..rows {
            for j in 0..cols {
                result[i * cols + j] = self.read_entry_raw(r0 + i, c0 + j)?;
            }
        }
        Ok(result)
    }

    /// Read the b-vector.
    pub fn read_b_vector(&self) -> hdf5::Result<Vec<f64>> {
        Ok(self.file.dataset("b_vector")?.read_1d::<f64>()?.to_vec())
    }

    /// Read the diagonal of G.
    pub fn read_diagonal(&self) -> hdf5::Result<Vec<f64>> {
        Ok(self.file.dataset("structure/diagonal")?.read_1d::<f64>()?.to_vec())
    }

    /// Read the column L2 norms.
    pub fn read_col_norms(&self) -> hdf5::Result<Vec<f64>> {
        Ok(self.file.dataset("structure/col_norms")?.read_1d::<f64>()?.to_vec())
    }

    /// Read the Möbius table μ(n) for n=0..max_n.
    pub fn read_mobius(&self) -> hdf5::Result<Vec<i8>> {
        Ok(self.file.dataset("number_theory/mobius")?.read_1d::<i8>()?.to_vec())
    }

    /// Read the prime list.
    pub fn read_primes(&self) -> hdf5::Result<Vec<u32>> {
        Ok(self.file.dataset("number_theory/primes")?.read_1d::<u32>()?.to_vec())
    }

    /// Read provenance metadata.
    pub fn read_provenance(&self) -> hdf5::Result<HpdfProvenance> {
        let prov = self.file.group("provenance")?;
        Ok(HpdfProvenance {
            timestamp: read_str_attr(&prov, "timestamp")?,
            builder: read_str_attr(&prov, "builder")?,
            precision: prov.attr("precision")?.read_scalar()?,
            source_sha256: read_str_attr(&prov, "source_sha256")?,
            git_commit: read_str_opt(&prov, "git_commit").unwrap_or_default(),
            hostname: read_str_opt(&prov, "hostname").unwrap_or_default(),
            build_time_secs: read_scalar_opt::<f64>(&prov, "build_time_secs").unwrap_or(0.0),
        })
    }

    /// Read structural scalar attributes.
    pub fn read_structural_scalars(&self) -> hdf5::Result<StructuralScalars> {
        let s = self.file.group("structure")?;
        Ok(StructuralScalars {
            trace: s.attr("trace")?.read_scalar()?,
            frobenius_norm: s.attr("frobenius_norm")?.read_scalar()?,
            condition_estimate: s.attr("condition_estimate")?.read_scalar()?,
            off_diag_max: s.attr("off_diagonal_max")?.read_scalar()?,
            off_diag_avg: read_scalar_opt::<f64>(&s, "off_diagonal_avg").unwrap_or(0.0),
            diag_min: s.attr("diagonal_min")?.read_scalar()?,
            diag_max: s.attr("diagonal_max")?.read_scalar()?,
            gershgorin_lambda_min: read_scalar_opt::<f64>(&s, "gershgorin_lambda_min"),
            gershgorin_lambda_max: read_scalar_opt::<f64>(&s, "gershgorin_lambda_max"),
        })
    }

    /// Read the data SHA-256 checksum (if present).
    pub fn read_data_checksum(&self) -> Option<String> {
        let gram = self.file.group("gram").ok()?;
        read_str_opt(&gram, "data_sha256")
    }

    /// Verify data integrity: recompute SHA-256 of the stored upper triangle
    /// and compare against the embedded checksum.
    ///
    /// If DD lo-word data is present, also verifies the lo triangle checksum.
    pub fn verify_data_integrity(&self) -> hdf5::Result<DataIntegrity> {
        let ds = self.file.dataset("gram/upper_triangle")?;
        let tri: Array1<f64> = ds.read_1d()?;
        let tri_vec = tri.to_vec();

        let tri_bytes: &[u8] = unsafe {
            std::slice::from_raw_parts(tri_vec.as_ptr() as *const u8, tri_vec.len() * 8)
        };
        let computed_sha = sha256_hex(tri_bytes);

        let stored_sha = self.read_data_checksum();
        let mut valid = stored_sha.as_ref().map(|s| s == &computed_sha).unwrap_or(false);

        // Also verify DD lo-word checksum if present
        let mut lo_valid = None;
        if self.has_dd() {
            if let Ok(lo_ds) = self.file.dataset("gram/upper_triangle_lo") {
                let lo_tri: Array1<f64> = lo_ds.read_1d()?;
                let lo_vec = lo_tri.to_vec();
                let lo_bytes: &[u8] = unsafe {
                    std::slice::from_raw_parts(lo_vec.as_ptr() as *const u8, lo_vec.len() * 8)
                };
                let computed_lo = sha256_hex(lo_bytes);
                let gram = self.file.group("gram")?;
                let stored_lo = read_str_opt(&gram, "data_lo_sha256");
                let lo_ok = stored_lo.as_ref().map(|s| s == &computed_lo).unwrap_or(false);
                lo_valid = Some(lo_ok);
                if !lo_ok {
                    valid = false;
                }
            }
        }

        Ok(DataIntegrity {
            computed_sha256: computed_sha,
            stored_sha256: stored_sha,
            valid,
            dd_lo_valid: lo_valid,
        })
    }

    /// Read lineage metadata (if this file was derived from another).
    pub fn read_lineage(&self) -> hdf5::Result<Option<LineageInfo>> {
        match self.file.group("lineage") {
            Ok(g) => Ok(Some(LineageInfo {
                parent_path: read_str_attr(&g, "parent_path")?,
                parent_sha256: read_str_attr(&g, "parent_sha256")?,
                parent_max_n: g.attr("parent_max_n")?.read_scalar::<u64>()? as usize,
                derivation: read_str_attr(&g, "derivation")?,
            })),
            Err(_) => Ok(None),
        }
    }

    /// Read distance result (if solved).
    pub fn read_distance(&self) -> hdf5::Result<Option<DistanceScalars>> {
        match self.file.group("distance") {
            Ok(d) => Ok(Some(DistanceScalars {
                d_squared: d.attr("d_squared")?.read_scalar()?,
                solver: read_str_attr(&d, "solver")?,
                iterations: d.attr("iterations")?.read_scalar()?,
                residual_norm: d.attr("residual_norm")?.read_scalar()?,
                converged: d.attr("converged")?.read_scalar::<u32>()? != 0,
                bt_x: read_scalar_opt::<f64>(&d, "bt_x"),
            })),
            Err(_) => Ok(None),
        }
    }

    /// Read the solution vector x = G⁻¹b (if stored).
    pub fn read_solution_vector(&self) -> hdf5::Result<Option<Vec<f64>>> {
        match self.file.dataset("distance/solution_vector") {
            Ok(ds) => Ok(Some(ds.read_1d::<f64>()?.to_vec())),
            Err(_) => Ok(None),
        }
    }

    /// Read the convergence history (residual at each iteration).
    pub fn read_convergence_history(&self) -> hdf5::Result<Option<Vec<f64>>> {
        match self.file.dataset("distance/convergence_history") {
            Ok(ds) => Ok(Some(ds.read_1d::<f64>()?.to_vec())),
            Err(_) => Ok(None),
        }
    }

    /// Read number-theory attributes (non-table scalars).
    pub fn read_number_theory_attrs(&self) -> hdf5::Result<Option<NumberTheoryAttrs>> {
        match self.file.group("number_theory") {
            Ok(nt) => Ok(Some(NumberTheoryAttrs {
                factorization: read_str_opt(&nt, "factorization").unwrap_or_default(),
                divisor_count: read_scalar_opt::<u64>(&nt, "divisor_count").unwrap_or(0),
                divisor_sum: read_scalar_opt::<u64>(&nt, "divisor_sum").unwrap_or(0),
                is_highly_composite: read_scalar_opt::<u32>(&nt, "is_highly_composite")
                    .map(|v| v != 0).unwrap_or(false),
                prime_count: read_scalar_opt::<u64>(&nt, "prime_count").unwrap_or(0),
            })),
            Err(_) => Ok(None),
        }
    }

    /// Spot-check `n_checks` entries against f64 recomputation.
    /// Returns (max_abs_error, max_rel_error).
    pub fn verify_spot_check(&self, n_checks: usize) -> hdf5::Result<(f64, f64)> {
        let gram = self.read_gram_full()?;
        let dim = self.dim;
        let mut max_abs = 0.0f64;
        let mut max_rel = 0.0f64;

        for i in 0..n_checks {
            let hash = (i.wrapping_mul(2654435761)) % (dim * dim);
            let row = hash / dim;
            let col = hash % dim;
            let stored = gram[row * dim + col];
            let recomputed = crate::gram::gram_entry_f64(row + 2, col + 2);
            let abs_err = (stored - recomputed).abs();
            let rel_err = if recomputed.abs() > 1e-30 {
                abs_err / recomputed.abs()
            } else { abs_err };
            max_abs = max_abs.max(abs_err);
            max_rel = max_rel.max(rel_err);
        }
        Ok((max_abs, max_rel))
    }
}

// ═══════════════════════════════════════════════════════════════
// DATA TYPES
// ═══════════════════════════════════════════════════════════════

/// Provenance metadata from an HPDF file.
#[derive(Debug, Clone)]
pub struct HpdfProvenance {
    pub timestamp: String,
    pub builder: String,
    pub precision: u32,
    pub source_sha256: String,
    pub git_commit: String,
    pub hostname: String,
    pub build_time_secs: f64,
}

/// Structural scalar invariants from /structure attrs.
#[derive(Debug, Clone)]
pub struct StructuralScalars {
    pub trace: f64,
    pub frobenius_norm: f64,
    pub condition_estimate: f64,
    pub off_diag_max: f64,
    pub off_diag_avg: f64,
    pub diag_min: f64,
    pub diag_max: f64,
    pub gershgorin_lambda_min: Option<f64>,
    pub gershgorin_lambda_max: Option<f64>,
}

/// Distance result from /distance group.
#[derive(Debug, Clone)]
pub struct DistanceScalars {
    pub d_squared: f64,
    pub solver: String,
    pub iterations: u64,
    pub residual_norm: f64,
    pub converged: bool,
    /// bᵀx = bᵀG⁻¹b — satisfies d² = 1 - bᵀx.
    pub bt_x: Option<f64>,
}

/// Data integrity check result.
#[derive(Debug, Clone)]
pub struct DataIntegrity {
    pub computed_sha256: String,
    pub stored_sha256: Option<String>,
    pub valid: bool,
    /// DD lo-word integrity: Some(true) = verified, Some(false) = corrupt, None = no DD data.
    pub dd_lo_valid: Option<bool>,
}

/// Number-theory scalar attributes.
#[derive(Debug, Clone)]
pub struct NumberTheoryAttrs {
    pub factorization: String,
    pub divisor_count: u64,
    pub divisor_sum: u64,
    pub is_highly_composite: bool,
    pub prime_count: u64,
}

/// Lineage information for derived files.
#[derive(Debug, Clone)]
pub struct LineageInfo {
    pub parent_path: String,
    pub parent_sha256: String,
    pub parent_max_n: usize,
    pub derivation: String,
}
