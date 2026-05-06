//! Out-of-core Gram matrix operations.
//!
//! For matrices too large for RAM or GPU VRAM, this module provides:
//! - Binary file format with checksums (CATHOOC format)
//! - Memory-mapped matrix access for zero-copy row reads
//! - Matrix discovery: finds all cached matrices across all storage tiers
//!
//! ## File Format
//!
//! ```text
//! [8 bytes] Magic: 0x434F4F4854_414300 ("CATHOOC\0")
//! [4 bytes] Version: 1
//! [4 bytes] max_n (u32)
//! [4 bytes] dim (u32)
//! [4 bytes] precision (u32)
//! [8 bytes] checksum (u64)
//! [8 bytes] padding
//! [dim*dim*8 bytes] matrix data (row-major f64)
//! ```

use std::path::{Path, PathBuf};
use std::io::{Read, Write};

/// File format magic number: "CATHOOC\0"
pub const MAGIC: u64 = 0x434F4F4854_414300;
pub const VERSION: u32 = 1;
pub const HEADER_SIZE: u64 = 40;

/// Header for an OOC Gram matrix file.
#[derive(Debug, Clone)]
pub struct Header {
    pub max_n: usize,
    pub dim: usize,
    pub precision: u32,
    pub checksum: u64,
}

/// Write an OOC header to a writer.
pub fn write_header(w: &mut impl Write, max_n: usize, dim: usize, precision: u32, checksum: u64) -> std::io::Result<()> {
    w.write_all(&MAGIC.to_le_bytes())?;
    w.write_all(&VERSION.to_le_bytes())?;
    w.write_all(&(max_n as u32).to_le_bytes())?;
    w.write_all(&(dim as u32).to_le_bytes())?;
    w.write_all(&precision.to_le_bytes())?;
    w.write_all(&checksum.to_le_bytes())?;
    w.write_all(&[0u8; 8])?; // padding
    Ok(())
}

/// Read an OOC header from a reader.
pub fn read_header(r: &mut impl Read) -> std::io::Result<Option<Header>> {
    let mut buf8 = [0u8; 8];
    let mut buf4 = [0u8; 4];

    r.read_exact(&mut buf8)?;
    if u64::from_le_bytes(buf8) != MAGIC { return Ok(None); }

    r.read_exact(&mut buf4)?;
    if u32::from_le_bytes(buf4) != VERSION { return Ok(None); }

    r.read_exact(&mut buf4)?;
    let max_n = u32::from_le_bytes(buf4) as usize;

    r.read_exact(&mut buf4)?;
    let dim = u32::from_le_bytes(buf4) as usize;

    r.read_exact(&mut buf4)?;
    let precision = u32::from_le_bytes(buf4);

    r.read_exact(&mut buf8)?;
    let checksum = u64::from_le_bytes(buf8);

    let mut pad = [0u8; 8];
    r.read_exact(&mut pad)?;

    Ok(Some(Header { max_n, dim, precision, checksum }))
}

/// Get the standard OOC cache path for a given N and precision.
pub fn gram_path(cache_dir: &Path, max_n: usize, precision: u32) -> PathBuf {
    cache_dir.join(format!("ooc_gram_N{max_n}_p{precision}.bin"))
}

/// A discovered matrix source on disk.
#[derive(Debug, Clone)]
pub struct MatrixSource {
    /// Path to the matrix file.
    pub path: PathBuf,
    /// Matrix dimension parameter (N, where dim = N-1).
    pub max_n: usize,
    /// Dimension of the matrix (N-1).
    pub dim: usize,
    /// File format.
    pub format: MatrixFormat,
    /// File size in bytes.
    pub file_size: u64,
}

/// Format of a cached matrix file.
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum MatrixFormat {
    /// OOC format: row-major f64 with CATHOOC header.
    Ooc,
    /// DD cache format: hi + lo f64 arrays with custom header.
    DdCache,
    /// Legacy single-precision cache.
    Legacy,
}

/// Discover all cached Gram matrices in standard locations.
///
/// Searches:
/// 1. OOC cache directory (typically /mnt/d/cathedral-cache/)
/// 2. DD cache directory (experiments/cache/)
/// 3. Any additional paths provided
pub fn discover_matrices(search_paths: &[PathBuf]) -> Vec<MatrixSource> {
    let mut sources = Vec::new();

    for dir in search_paths {
        if !dir.exists() { continue; }

        if let Ok(entries) = std::fs::read_dir(dir) {
            for entry in entries.flatten() {
                let path = entry.path();
                if !path.is_file() { continue; }

                let name = path.file_name().unwrap_or_default().to_string_lossy();
                let file_size = entry.metadata().map(|m| m.len()).unwrap_or(0);

                // OOC format: ooc_gram_N{n}_p{p}.bin
                if name.starts_with("ooc_gram_N") && name.ends_with(".bin") {
                    if let Some(n) = parse_n_from_filename(&name, "ooc_gram_N", "_p") {
                        sources.push(MatrixSource {
                            path: path.clone(),
                            max_n: n,
                            dim: n - 1,
                            format: MatrixFormat::Ooc,
                            file_size,
                        });
                    }
                }

                // DD cache format: dd_gram_N{n}_mpfr{p}.bin
                if name.starts_with("dd_gram_N") && name.ends_with(".bin") {
                    if let Some(n) = parse_n_from_filename(&name, "dd_gram_N", "_mpfr") {
                        sources.push(MatrixSource {
                            path: path.clone(),
                            max_n: n,
                            dim: n - 1,
                            format: MatrixFormat::DdCache,
                            file_size,
                        });
                    }
                }

                // Legacy format: gram_N{n}_mpfr{p}.bin
                if name.starts_with("gram_N") && name.contains("_mpfr") && name.ends_with(".bin") {
                    if let Some(n) = parse_n_from_filename(&name, "gram_N", "_mpfr") {
                        sources.push(MatrixSource {
                            path: path.clone(),
                            max_n: n,
                            dim: n - 1,
                            format: MatrixFormat::Legacy,
                            file_size,
                        });
                    }
                }
            }
        }
    }

    // Sort by N
    sources.sort_by_key(|s| s.max_n);

    // Deduplicate: prefer DD > OOC > Legacy for the same N
    sources.dedup_by(|b, a| {
        if a.max_n == b.max_n {
            // Keep the higher-precision format
            match (a.format, b.format) {
                (MatrixFormat::DdCache, _) => true, // keep a (DD)
                (_, MatrixFormat::DdCache) => { *a = b.clone(); true } // replace with b (DD)
                (MatrixFormat::Ooc, _) => true,
                _ => true,
            }
        } else {
            false
        }
    });

    sources
}

fn parse_n_from_filename(name: &str, prefix: &str, suffix_start: &str) -> Option<usize> {
    let after_prefix = name.strip_prefix(prefix)?;
    let n_str = after_prefix.split(suffix_start).next()?;
    n_str.parse().ok()
}

/// Compute a checksum of the first 64 f64 values.
pub fn compute_checksum(data: &[f64]) -> u64 {
    data.iter()
        .take(64)
        .map(|v| v.to_bits())
        .fold(0u64, |acc, b| acc.wrapping_add(b))
}
