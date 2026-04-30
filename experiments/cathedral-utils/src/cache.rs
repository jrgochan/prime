//! Binary disk cache for large data structures.
//!
//! Saves and loads Gram matrices to/from binary files, avoiding
//! expensive recomputation. A 2000×2000 matrix (30 MB) loads in
//! milliseconds instead of ~50 minutes.
//!
//! ## Cache Location
//!
//! Cache files are stored in `experiments/cache/` at the workspace root.
//! This directory is gitignored for large binary files.
//!
//! ## Format
//!
//! ```text
//! [magic: u64]     — 0x4341544845445241 ("CATHEDRA")
//! [version: u32]   — format version (currently 1)
//! [max_n: u32]     — maximum N used to build the matrix
//! [precision: u32] — MPFR precision bits (0 for f64)
//! [dim: u32]       — matrix dimension (= max_n - 1)
//! [checksum: u64]  — sum of first 64 f64 values as u64 bits
//! [data: f64×dim²] — row-major matrix data
//! ```

use crate::gram::GramMatrix;
use std::io::{Read, Write};
use std::path::{Path, PathBuf};

const MAGIC: u64 = 0x4341544845445241; // "CATHEDRA"
const VERSION: u32 = 1;

/// Get the default cache directory path.
///
/// Resolves to `experiments/cache/` relative to the workspace root.
/// Uses CARGO_MANIFEST_DIR (set at compile time) to find the workspace.
pub fn cache_dir() -> PathBuf {
    let manifest = env!("CARGO_MANIFEST_DIR"); // e.g. .../experiments/cathedral-utils
    PathBuf::from(manifest)
        .parent()                              // .../experiments/
        .unwrap_or(Path::new("."))
        .join("cache")
}

/// Compute the default cache file path for a Gram matrix.
pub fn gram_cache_path(max_n: usize, precision: u32) -> PathBuf {
    let prec_str = if precision == 0 { "f64".to_string() } else { format!("mpfr{precision}") };
    cache_dir().join(format!("gram_N{max_n}_{prec_str}.bin"))
}

/// Compute a simple checksum from the first 64 entries.
fn checksum(data: &[f64]) -> u64 {
    data.iter()
        .take(64)
        .map(|v| v.to_bits())
        .fold(0u64, |acc, b| acc.wrapping_add(b))
}

/// Save a GramMatrix to a binary cache file.
pub fn save_gram(path: &Path, gram: &GramMatrix) -> std::io::Result<()> {
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)?;
    }

    let mut f = std::fs::File::create(path)?;
    let precision = gram.precision;

    f.write_all(&MAGIC.to_le_bytes())?;
    f.write_all(&VERSION.to_le_bytes())?;
    f.write_all(&(gram.max_n as u32).to_le_bytes())?;
    f.write_all(&precision.to_le_bytes())?;
    f.write_all(&(gram.max_dim as u32).to_le_bytes())?;
    f.write_all(&checksum(&gram.data).to_le_bytes())?;

    // Write f64 data as raw bytes
    let bytes: &[u8] = unsafe {
        std::slice::from_raw_parts(
            gram.data.as_ptr() as *const u8,
            gram.data.len() * 8,
        )
    };
    f.write_all(bytes)?;

    let mb = gram.data.len() * 8 / (1024 * 1024);
    eprintln!("  \x1b[32m✓\x1b[0m Gram matrix cached to {} ({} MB)", path.display(), mb);
    Ok(())
}

/// Load a GramMatrix from a binary cache file.
///
/// Returns `None` if the file doesn't exist, has wrong magic/version,
/// or the checksum doesn't match.
pub fn load_gram(path: &Path) -> Option<GramMatrix> {
    let mut f = std::fs::File::open(path).ok()?;

    let mut buf8 = [0u8; 8];
    let mut buf4 = [0u8; 4];

    // Read and validate header
    f.read_exact(&mut buf8).ok()?;
    if u64::from_le_bytes(buf8) != MAGIC {
        eprintln!("  \x1b[33m⚠\x1b[0m Cache file has wrong magic");
        return None;
    }

    f.read_exact(&mut buf4).ok()?;
    let version = u32::from_le_bytes(buf4);
    if version != VERSION {
        eprintln!("  \x1b[33m⚠\x1b[0m Cache file version {version} != expected {VERSION}");
        return None;
    }

    f.read_exact(&mut buf4).ok()?;
    let max_n = u32::from_le_bytes(buf4) as usize;

    f.read_exact(&mut buf4).ok()?;
    let precision = u32::from_le_bytes(buf4);

    f.read_exact(&mut buf4).ok()?;
    let dim = u32::from_le_bytes(buf4) as usize;

    f.read_exact(&mut buf8).ok()?;
    let expected_checksum = u64::from_le_bytes(buf8);

    // Read matrix data
    let mut data = vec![0.0f64; dim * dim];
    let bytes: &mut [u8] = unsafe {
        std::slice::from_raw_parts_mut(
            data.as_mut_ptr() as *mut u8,
            data.len() * 8,
        )
    };
    f.read_exact(bytes).ok()?;

    // Validate checksum
    let actual_checksum = checksum(&data);
    if actual_checksum != expected_checksum {
        eprintln!("  \x1b[33m⚠\x1b[0m Cache checksum mismatch!");
        return None;
    }

    let mb = data.len() * 8 / (1024 * 1024);
    eprintln!(
        "  \x1b[32m✓\x1b[0m Gram matrix loaded from cache ({} MB, N={max_n}, {})",
        mb,
        if precision > 0 { format!("MPFR-{precision}") } else { "f64".to_string() }
    );

    Some(GramMatrix {
        data,
        max_dim: dim,
        max_n,
        mpfr_built: precision > 0,
        precision,
    })
}


const DD_MAGIC: u64 = 0x5F5F444448544143; // "CATHDD__"
const DD_VERSION: u32 = 1;

/// Compute the default cache file path for a DD Gram matrix.
pub fn dd_gram_cache_path(max_n: usize, precision: u32) -> PathBuf {
    cache_dir().join(format!("dd_gram_N{max_n}_mpfr{precision}.bin"))
}

/// Save a DD Gram matrix (hi/lo f64 pairs) to a binary cache file.
///
/// Format:
/// ```text
/// [magic: u64]     — 0x5F5F444448544143 ("CATHDD__")
/// [version: u32]   — format version (currently 1)
/// [max_n: u32]     — maximum N used to build
/// [precision: u32] — MPFR precision bits used to build
/// [dim: u32]       — matrix dimension (= max_n - 1)
/// [checksum: u64]  — checksum of first 64 hi values
/// [hi: f64×dim²]   — DD high part, row-major
/// [lo: f64×dim²]   — DD low part, row-major
/// ```
pub fn save_dd_gram(path: &Path, hi: &[f64], lo: &[f64], dim: usize, max_n: usize, precision: u32) -> std::io::Result<()> {
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)?;
    }

    let mut f = std::fs::File::create(path)?;

    f.write_all(&DD_MAGIC.to_le_bytes())?;
    f.write_all(&DD_VERSION.to_le_bytes())?;
    f.write_all(&(max_n as u32).to_le_bytes())?;
    f.write_all(&precision.to_le_bytes())?;
    f.write_all(&(dim as u32).to_le_bytes())?;
    f.write_all(&checksum(hi).to_le_bytes())?;

    // Write hi and lo as raw bytes
    let hi_bytes: &[u8] = unsafe {
        std::slice::from_raw_parts(hi.as_ptr() as *const u8, hi.len() * 8)
    };
    let lo_bytes: &[u8] = unsafe {
        std::slice::from_raw_parts(lo.as_ptr() as *const u8, lo.len() * 8)
    };
    f.write_all(hi_bytes)?;
    f.write_all(lo_bytes)?;

    let mb = (hi.len() + lo.len()) * 8 / (1024 * 1024);
    eprintln!("  \x1b[32m✓\x1b[0m DD Gram cached to {} ({} MB)", path.display(), mb);
    Ok(())
}

/// Load a DD Gram matrix from a binary cache file.
///
/// Returns `None` if the file doesn't exist, has wrong magic/version,
/// or the checksum doesn't match. Returns `(hi, lo, dim)`.
pub fn load_dd_gram(path: &Path) -> Option<(Vec<f64>, Vec<f64>, usize)> {
    let mut f = std::fs::File::open(path).ok()?;

    let mut buf8 = [0u8; 8];
    let mut buf4 = [0u8; 4];

    // Read and validate header
    f.read_exact(&mut buf8).ok()?;
    if u64::from_le_bytes(buf8) != DD_MAGIC { return None; }

    f.read_exact(&mut buf4).ok()?;
    if u32::from_le_bytes(buf4) != DD_VERSION { return None; }

    f.read_exact(&mut buf4).ok()?;
    let _max_n = u32::from_le_bytes(buf4) as usize;

    f.read_exact(&mut buf4).ok()?;
    let _precision = u32::from_le_bytes(buf4);

    f.read_exact(&mut buf4).ok()?;
    let dim = u32::from_le_bytes(buf4) as usize;

    f.read_exact(&mut buf8).ok()?;
    let expected_checksum = u64::from_le_bytes(buf8);

    // Read hi
    let mut hi = vec![0.0f64; dim * dim];
    let hi_bytes: &mut [u8] = unsafe {
        std::slice::from_raw_parts_mut(hi.as_mut_ptr() as *mut u8, hi.len() * 8)
    };
    f.read_exact(hi_bytes).ok()?;

    // Read lo
    let mut lo = vec![0.0f64; dim * dim];
    let lo_bytes: &mut [u8] = unsafe {
        std::slice::from_raw_parts_mut(lo.as_mut_ptr() as *mut u8, lo.len() * 8)
    };
    f.read_exact(lo_bytes).ok()?;

    // Validate checksum
    if checksum(&hi) != expected_checksum {
        eprintln!("  \x1b[33m⚠\x1b[0m DD cache checksum mismatch!");
        return None;
    }

    let mb = (hi.len() + lo.len()) * 8 / (1024 * 1024);
    eprintln!(
        "  \x1b[32m✓\x1b[0m DD Gram loaded from cache ({} MB, dim={dim})",
        mb
    );

    Some((hi, lo, dim))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_checksum_deterministic() {
        let data = vec![1.0, 2.0, 3.0, 4.0];
        assert_eq!(checksum(&data), checksum(&data));
    }
}
