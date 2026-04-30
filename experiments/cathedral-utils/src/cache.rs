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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_checksum_deterministic() {
        let data = vec![1.0, 2.0, 3.0, 4.0];
        assert_eq!(checksum(&data), checksum(&data));
    }
}
