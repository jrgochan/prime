//! HPDF writer — builds self-describing HDF5 files from raw Gram data.
//!
//! Supports optional DD (double-double) lo-word storage for lossless
//! ~31-digit precision roundtrip.  When `dd_lo` data is provided,
//! a second dataset `/gram/upper_triangle_lo` is written alongside
//! the hi-word, with its own SHA-256 checksum.

use hdf5::File as H5File;
use ndarray::Array1;
use std::path::Path;
use std::time::Instant;

use super::helpers::{write_str_attr, write_scalar_attr, sha256_hex};
use super::metadata::{StructuralStats, BVectorStats};
use super::{HPDF_MAGIC, HPDF_VERSION};

/// Configuration for HPDF file generation.
pub struct HpdfWriterConfig {
    /// Maximum N (matrix indices are 2..=max_n).
    pub max_n: usize,
    /// MPFR precision bits used to build the matrix (0 = f64).
    pub precision: u32,
    /// SHA-256 hex digest of the source binary file.
    pub source_sha256: String,
    /// Builder identification string.
    pub builder: String,
    /// Whether to include number-theory tables (μ, φ, primes).
    pub include_number_theory: bool,
}

/// Write a Gram matrix and metadata to an HPDF (HDF5) file.
///
/// `data` is the full dim×dim row-major matrix (only upper triangle is stored).
/// Returns the number of bytes written.
pub fn write_hpdf(
    path: &Path,
    data: &[f64],
    config: &HpdfWriterConfig,
) -> hdf5::Result<u64> {
    write_hpdf_inner(path, data, None, config)
}

/// Write a Gram matrix with DD lo-word data to an HPDF (HDF5) file.
///
/// Both `data_hi` and `data_lo` are full dim×dim row-major matrices.
/// The upper triangle of each is extracted and stored as:
///   - `/gram/upper_triangle`    (hi words)
///   - `/gram/upper_triangle_lo` (lo words)
///
/// Together they represent each entry as `value = hi + lo` with ~31
/// significant decimal digits (double-double precision).
pub fn write_hpdf_dd(
    path: &Path,
    data_hi: &[f64],
    data_lo: &[f64],
    config: &HpdfWriterConfig,
) -> hdf5::Result<u64> {
    write_hpdf_inner(path, data_hi, Some(data_lo), config)
}

/// Write an HPDF file from pre-computed upper triangle data (f64 only).
///
/// `upper_tri` is a flat array of dim*(dim+1)/2 entries in row-major
/// upper-triangle order. This avoids the full dim×dim matrix allocation,
/// halving RAM usage for large matrices.
///
/// For N=83,160: uses 27.7 GB instead of 55.3 GB.
pub fn write_hpdf_from_triangle(
    path: &Path,
    upper_tri: &[f64],
    config: &HpdfWriterConfig,
) -> hdf5::Result<u64> {
    write_hpdf_triangle_inner(path, upper_tri, None, config)
}

/// Write an HPDF file from pre-computed upper triangle data with DD lo-words.
///
/// Both `upper_tri_hi` and `upper_tri_lo` are flat arrays of dim*(dim+1)/2
/// entries in row-major upper-triangle order.
///
/// For N=83,160: uses 55.4 GB (27.7 hi + 27.7 lo) instead of 110.6 GB.
pub fn write_hpdf_dd_from_triangle(
    path: &Path,
    upper_tri_hi: &[f64],
    upper_tri_lo: &[f64],
    config: &HpdfWriterConfig,
) -> hdf5::Result<u64> {
    write_hpdf_triangle_inner(path, upper_tri_hi, Some(upper_tri_lo), config)
}

/// Internal implementation — optionally stores DD lo-word data.
fn write_hpdf_inner(
    path: &Path,
    data: &[f64],
    dd_lo: Option<&[f64]>,
    config: &HpdfWriterConfig,
) -> hdf5::Result<u64> {
    let dim = config.max_n - 1;
    assert_eq!(data.len(), dim * dim, "data length must be dim²");
    if let Some(lo) = dd_lo {
        assert_eq!(lo.len(), dim * dim, "dd_lo length must be dim²");
    }
    let t0 = Instant::now();

    let has_dd = dd_lo.is_some();
    eprintln!("  \x1b[2m▸ Writing HPDF{}: {} (dim={dim})\x1b[0m",
        if has_dd { " [DD]" } else { "" }, path.display());

    let file = H5File::create(path)?;

    // ── Root attributes ──
    write_str_attr(&file, "format", HPDF_MAGIC)?;
    write_scalar_attr(&file, "version", HPDF_VERSION)?;
    write_scalar_attr(&file, "max_n", config.max_n as u64)?;
    write_scalar_attr(&file, "dim", dim as u64)?;

    // ── /gram group — upper triangle storage ──
    let gram_grp = file.create_group("gram")?;
    write_str_attr(&gram_grp, "entry_formula",
        "G[j,k] = integral_0^1 {1/(jx)}{1/(kx)} dx")?;
    write_scalar_attr(&gram_grp, "precision", config.precision)?;
    write_scalar_attr(&gram_grp, "max_n", config.max_n as u64)?;
    write_scalar_attr(&gram_grp, "dim", dim as u64)?;
    // Mark whether DD lo-word data is present
    write_scalar_attr(&gram_grp, "dd_stored", if has_dd { 1u32 } else { 0u32 })?;

    let tri_len = dim * (dim + 1) / 2;
    let mut upper_tri = Vec::with_capacity(tri_len);
    for row in 0..dim {
        for col in row..dim {
            upper_tri.push(data[row * dim + col]);
        }
    }
    eprintln!("  \x1b[2m  Upper triangle (hi): {tri_len} entries ({} MB)\x1b[0m",
        tri_len * 8 / (1024 * 1024));

    // Compute SHA-256 of the raw triangle bytes for self-integrity verification.
    // This lets us detect corruption even after the file has been modified
    // (e.g., distance stamped) since it checksums only the matrix data.
    let tri_bytes: &[u8] = unsafe {
        std::slice::from_raw_parts(upper_tri.as_ptr() as *const u8, tri_len * 8)
    };
    let data_sha = sha256_hex(tri_bytes);
    write_str_attr(&gram_grp, "data_sha256", &data_sha)?;

    let tri_arr = Array1::from(upper_tri);
    gram_grp.new_dataset_builder()
        .with_data(&tri_arr)
        .create("upper_triangle")?;

    // ── DD lo-word: /gram/upper_triangle_lo ──
    if let Some(lo_data) = dd_lo {
        let mut upper_tri_lo = Vec::with_capacity(tri_len);
        for row in 0..dim {
            for col in row..dim {
                upper_tri_lo.push(lo_data[row * dim + col]);
            }
        }
        eprintln!("  \x1b[2m  Upper triangle (lo): {tri_len} entries ({} MB)\x1b[0m",
            tri_len * 8 / (1024 * 1024));

        let lo_bytes: &[u8] = unsafe {
            std::slice::from_raw_parts(upper_tri_lo.as_ptr() as *const u8, tri_len * 8)
        };
        let lo_sha = sha256_hex(lo_bytes);
        write_str_attr(&gram_grp, "data_lo_sha256", &lo_sha)?;

        let lo_arr = Array1::from(upper_tri_lo);
        gram_grp.new_dataset_builder()
            .with_data(&lo_arr)
            .create("upper_triangle_lo")?;
    }

    // ── /b_vector — with enriched stats ──
    let b_stats = BVectorStats::compute(dim);
    b_stats.write_to_file(&file)?;

    // ── /structure — full structural metadata ──
    eprintln!("  \x1b[2m  Computing structural metadata...\x1b[0m");
    let stats = StructuralStats::compute(data, dim);
    let struct_grp = file.create_group("structure")?;
    stats.write_to_group(&struct_grp)?;

    // ── /number_theory (optional) ──
    if config.include_number_theory {
        super::metadata::write_number_theory(&file, config.max_n)?;
    }

    // ── /provenance — enriched ──
    let build_time = t0.elapsed().as_secs_f64();
    super::metadata::write_provenance(
        &file,
        &config.builder,
        config.precision,
        &config.source_sha256,
        build_time,
    )?;

    drop(file);

    let file_size = std::fs::metadata(path).map(|m| m.len()).unwrap_or(0);
    let elapsed = t0.elapsed().as_secs_f64();
    eprintln!("  \x1b[32m✓\x1b[0m HPDF{} written: {} ({} MB, {:.1}s)",
        if has_dd { " [DD]" } else { "" },
        path.display(), file_size / (1024 * 1024), elapsed);

    Ok(file_size)
}

/// Internal implementation for pre-computed upper triangle data.
///
/// Accepts the upper triangle directly (no full matrix needed),
/// enabling streaming builds that halve RAM usage.
fn write_hpdf_triangle_inner(
    path: &Path,
    upper_tri: &[f64],
    dd_lo_tri: Option<&[f64]>,
    config: &HpdfWriterConfig,
) -> hdf5::Result<u64> {
    let dim = config.max_n - 1;
    let tri_len = dim * (dim + 1) / 2;
    assert_eq!(upper_tri.len(), tri_len,
        "upper_tri length {} != expected {} for dim={}",
        upper_tri.len(), tri_len, dim);
    if let Some(lo) = dd_lo_tri {
        assert_eq!(lo.len(), tri_len, "dd_lo_tri length must equal tri_len");
    }
    let t0 = Instant::now();

    let has_dd = dd_lo_tri.is_some();
    eprintln!("  \x1b[2m▸ Writing HPDF{} (from triangle): {} (dim={dim})\x1b[0m",
        if has_dd { " [DD]" } else { "" }, path.display());

    let file = H5File::create(path)?;

    // ── Root attributes ──
    write_str_attr(&file, "format", HPDF_MAGIC)?;
    write_scalar_attr(&file, "version", HPDF_VERSION)?;
    write_scalar_attr(&file, "max_n", config.max_n as u64)?;
    write_scalar_attr(&file, "dim", dim as u64)?;

    // ── /gram group ──
    let gram_grp = file.create_group("gram")?;
    write_str_attr(&gram_grp, "entry_formula",
        "G[j,k] = integral_0^1 {1/(jx)}{1/(kx)} dx")?;
    write_scalar_attr(&gram_grp, "precision", config.precision)?;
    write_scalar_attr(&gram_grp, "max_n", config.max_n as u64)?;
    write_scalar_attr(&gram_grp, "dim", dim as u64)?;
    write_scalar_attr(&gram_grp, "dd_stored", if has_dd { 1u32 } else { 0u32 })?;

    // SHA-256 of upper triangle hi-words
    let tri_bytes: &[u8] = unsafe {
        std::slice::from_raw_parts(upper_tri.as_ptr() as *const u8, tri_len * 8)
    };
    let data_sha = sha256_hex(tri_bytes);
    write_str_attr(&gram_grp, "data_sha256", &data_sha)?;

    eprintln!("  \x1b[2m  Upper triangle (hi): {tri_len} entries ({} MB)\x1b[0m",
        tri_len * 8 / (1024 * 1024));

    let tri_arr = Array1::from_vec(upper_tri.to_vec());
    gram_grp.new_dataset_builder()
        .with_data(&tri_arr)
        .create("upper_triangle")?;

    // ── DD lo-words ──
    if let Some(lo_tri) = dd_lo_tri {
        let lo_bytes: &[u8] = unsafe {
            std::slice::from_raw_parts(lo_tri.as_ptr() as *const u8, tri_len * 8)
        };
        let lo_sha = sha256_hex(lo_bytes);
        write_str_attr(&gram_grp, "data_lo_sha256", &lo_sha)?;

        eprintln!("  \x1b[2m  Upper triangle (lo): {tri_len} entries ({} MB)\x1b[0m",
            tri_len * 8 / (1024 * 1024));

        let lo_arr = Array1::from_vec(lo_tri.to_vec());
        gram_grp.new_dataset_builder()
            .with_data(&lo_arr)
            .create("upper_triangle_lo")?;
    }

    // ── /b_vector ──
    let b_stats = BVectorStats::compute(dim);
    b_stats.write_to_file(&file)?;

    // ── /structure — compute from triangle data ──
    eprintln!("  \x1b[2m  Computing structural metadata from triangle...\x1b[0m");
    // We need the diagonal for structural stats. Extract from upper triangle.
    let mut diag = vec![0.0f64; dim];
    let mut tri_offset = 0;
    for row in 0..dim {
        diag[row] = upper_tri[tri_offset]; // first element of each row's triangle
        tri_offset += dim - row;
    }
    // Compute trace and Frobenius norm from triangle
    let trace: f64 = diag.iter().sum();
    let mut frob_sq = 0.0f64;
    for i in 0..tri_len {
        let val = upper_tri[i];
        frob_sq += val * val;
        // Off-diagonal elements appear twice in the full matrix
        // Check if this is a diagonal element
        // (we count it once; off-diag gets doubled)
    }
    // Actually need to identify which elements are diagonal vs off-diagonal
    // The diagonal elements are at positions 0, dim, dim+(dim-1), ...
    // Simpler: double everything then subtract the diagonal once
    let diag_sq: f64 = diag.iter().map(|d| d * d).sum();
    let full_frob_sq = 2.0 * frob_sq - diag_sq; // 2× triangle - diagonal
    let frobenius = full_frob_sq.sqrt();

    let struct_grp = file.create_group("structure")?;
    write_scalar_attr(&struct_grp, "trace", trace)?;
    write_scalar_attr(&struct_grp, "frobenius_norm", frobenius)?;
    write_scalar_attr(&struct_grp, "dim", dim as u64)?;
    write_scalar_attr(&struct_grp, "diagonal_min", diag.iter().cloned().fold(f64::INFINITY, f64::min))?;
    write_scalar_attr(&struct_grp, "diagonal_max", diag.iter().cloned().fold(f64::NEG_INFINITY, f64::max))?;

    // ── /number_theory (optional) ──
    if config.include_number_theory {
        super::metadata::write_number_theory(&file, config.max_n)?;
    }

    // ── /provenance ──
    let build_time = t0.elapsed().as_secs_f64();
    super::metadata::write_provenance(
        &file,
        &config.builder,
        config.precision,
        &config.source_sha256,
        build_time,
    )?;

    drop(file);

    let file_size = std::fs::metadata(path).map(|m| m.len()).unwrap_or(0);
    let elapsed = t0.elapsed().as_secs_f64();
    eprintln!("  \x1b[32m✓\x1b[0m HPDF{} (triangle) written: {} ({} MB, {:.1}s)",
        if has_dd { " [DD]" } else { "" },
        path.display(), file_size / (1024 * 1024), elapsed);

    Ok(file_size)
}
