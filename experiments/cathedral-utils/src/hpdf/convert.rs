//! Converters — OOC binary → HPDF, submatrix extraction.

use std::path::Path;
use std::time::Instant;

use super::helpers::sha256_hex;
use super::metadata::LineageInfo;
use super::writer::{write_hpdf, HpdfWriterConfig};
use super::HPDF_VERSION;

/// Convert a CATHOOC binary file to HPDF format.
///
/// Reads the OOC file, computes SHA-256, writes HPDF with all metadata.
pub fn convert_ooc_to_hpdf(
    ooc_path: &Path,
    hpdf_path: &Path,
    include_number_theory: bool,
) -> hdf5::Result<u64> {
    use sha2::{Sha256, Digest};
    use std::io::{Read, Seek};

    eprintln!("  \x1b[2m▸ Converting OOC → HPDF\x1b[0m");
    eprintln!("  \x1b[2m  Source: {}\x1b[0m", ooc_path.display());

    // Read OOC header
    let mut f = std::fs::File::open(ooc_path)
        .map_err(|e| format!("Cannot open OOC: {e}"))
        .expect("open ooc");
    let header = crate::ooc::read_header(&mut f)
        .expect("read header")
        .expect("valid CATHOOC magic");

    eprintln!("  \x1b[2m  OOC: max_n={}, dim={}, prec={}\x1b[0m",
        header.max_n, header.dim, header.precision);

    // SHA-256
    let sha_t0 = Instant::now();
    let mut hasher = Sha256::new();
    let mut sha_file = std::fs::File::open(ooc_path).expect("sha open");
    let mut buf = vec![0u8; 8 * 1024 * 1024];
    loop {
        let n = sha_file.read(&mut buf).expect("sha read");
        if n == 0 { break; }
        hasher.update(&buf[..n]);
    }
    let sha_hex = format!("{:x}", hasher.finalize());
    eprintln!("  \x1b[2m  SHA-256: {}... ({:.1}s)\x1b[0m",
        &sha_hex[..16], sha_t0.elapsed().as_secs_f64());

    // Read matrix data
    eprintln!("  \x1b[2m  Reading matrix ({} GB)...\x1b[0m",
        header.dim * header.dim * 8 / 1_073_741_824);
    let data_t0 = Instant::now();
    let mut data_file = std::fs::File::open(ooc_path).expect("data open");
    data_file.seek(std::io::SeekFrom::Start(crate::ooc::HEADER_SIZE)).expect("seek");

    let n_entries = header.dim * header.dim;
    let mut data = vec![0.0f64; n_entries];
    let data_bytes = unsafe {
        std::slice::from_raw_parts_mut(data.as_mut_ptr() as *mut u8, n_entries * 8)
    };
    data_file.read_exact(data_bytes).expect("read matrix data");
    eprintln!("  \x1b[2m  Loaded ({:.1}s)\x1b[0m", data_t0.elapsed().as_secs_f64());

    let config = HpdfWriterConfig {
        max_n: header.max_n,
        precision: header.precision,
        source_sha256: sha_hex,
        builder: format!("cathedral-utils convert_ooc_to_hpdf v{HPDF_VERSION}"),
        include_number_theory,
    };

    write_hpdf(hpdf_path, &data, &config)
}

/// Extract a submatrix of dimension `sub_n - 1` from a larger matrix
/// and write it as a new HPDF file, with lineage tracking back to the parent.
pub fn extract_submatrix_hpdf(
    source_data: &[f64],
    source_dim: usize,
    sub_n: usize,
    source_precision: u32,
    source_sha: &str,
    hpdf_path: &Path,
) -> hdf5::Result<u64> {
    let sub_dim = sub_n - 1;
    assert!(sub_dim <= source_dim, "sub_n must be <= source dim + 1");

    let mut sub_data = vec![0.0f64; sub_dim * sub_dim];
    for row in 0..sub_dim {
        for col in 0..sub_dim {
            sub_data[row * sub_dim + col] = source_data[row * source_dim + col];
        }
    }

    let config = HpdfWriterConfig {
        max_n: sub_n,
        precision: source_precision,
        source_sha256: source_sha.to_string(),
        builder: format!("cathedral-utils extract_submatrix N={sub_n}"),
        include_number_theory: sub_n <= 10_000,
    };

    let size = write_hpdf(hpdf_path, &sub_data, &config)?;

    // Stamp lineage into the newly written file
    let lineage = LineageInfo {
        parent_path: source_sha.to_string(),
        parent_sha256: source_sha.to_string(),
        parent_max_n: source_dim + 1,
        derivation: format!("submatrix_extraction(N={sub_n} from N={})", source_dim + 1),
    };
    let file = hdf5::File::open_rw(hpdf_path)?;
    super::metadata::write_lineage(&file, &lineage)?;

    Ok(size)
}

/// Extract a submatrix with full lineage from an existing HPDF file.
///
/// This reads the parent HPDF, extracts the submatrix, and records
/// the parent's file path and SHA-256 for chain-of-trust verification.
pub fn extract_from_hpdf(
    parent_path: &Path,
    sub_n: usize,
    output_path: &Path,
) -> hdf5::Result<u64> {
    use std::io::Read;

    // Compute parent file SHA
    let parent_sha = {
        use sha2::{Sha256, Digest};
        let mut hasher = Sha256::new();
        let mut f = std::fs::File::open(parent_path).expect("open parent");
        let mut buf = vec![0u8; 8 * 1024 * 1024];
        loop {
            let n = f.read(&mut buf).expect("sha read");
            if n == 0 { break; }
            hasher.update(&buf[..n]);
        }
        format!("{:x}", hasher.finalize())
    };

    let reader = super::HpdfReader::open(parent_path)?;
    let parent_dim = reader.dim();
    let parent_max_n = reader.max_n();
    let parent_prec = reader.precision().unwrap_or(0);
    assert!(sub_n <= parent_max_n, "sub_n must be <= parent max_n");

    let gram = reader.read_gram_full()?;
    let sub_dim = sub_n - 1;
    let mut sub_data = vec![0.0f64; sub_dim * sub_dim];
    for row in 0..sub_dim {
        for col in 0..sub_dim {
            sub_data[row * sub_dim + col] = gram[row * parent_dim + col];
        }
    }

    // Compute SHA of the sub-data for the source field
    let sub_bytes: &[u8] = unsafe {
        std::slice::from_raw_parts(sub_data.as_ptr() as *const u8, sub_data.len() * 8)
    };
    let sub_sha = sha256_hex(sub_bytes);

    let config = HpdfWriterConfig {
        max_n: sub_n,
        precision: parent_prec,
        source_sha256: sub_sha,
        builder: format!("cathedral-utils extract_from_hpdf N={sub_n}"),
        include_number_theory: sub_n <= 10_000,
    };

    let size = write_hpdf(output_path, &sub_data, &config)?;

    // Stamp lineage
    let lineage = LineageInfo {
        parent_path: parent_path.to_string_lossy().to_string(),
        parent_sha256: parent_sha,
        parent_max_n,
        derivation: format!("submatrix_extraction(N={sub_n} from N={parent_max_n})"),
    };
    let file = hdf5::File::open_rw(output_path)?;
    super::metadata::write_lineage(&file, &lineage)?;

    Ok(size)
}
