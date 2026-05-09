//! Build subcommand — construct fresh Gram matrices and write to HPDF.

use cathedral_utils::gram;
use cathedral_utils::hpdf::{self, HpdfReader, HpdfWriterConfig};
use rayon::prelude::*;
use std::path::PathBuf;
use std::time::Instant;

use crate::common::*;

/// Build a fresh Gram matrix for the given N and verify it.
pub fn build_and_verify(max_n: usize, precision: u32) {
    let dim = max_n - 1;
    let use_mpfr = precision > 0;
    let prec_label = if use_mpfr {
        format!("{precision}-bit MPFR → DD")
    } else {
        "f64 (Kahan)".to_string()
    };

    println!("{BOLD}{CYAN}╔═══════════════════════════════════════════════════════════╗{RESET}");
    println!(
        "{BOLD}{CYAN}║{RESET}  🏛️  HPDF BUILD & VERIFY — N={:<6}  [{:<18}] {BOLD}{CYAN}║{RESET}",
        max_n, prec_label
    );
    println!("{BOLD}{CYAN}╚═══════════════════════════════════════════════════════════╝{RESET}\n");

    let out_dir = PathBuf::from("cache/hpdf");
    std::fs::create_dir_all(&out_dir).unwrap();

    if use_mpfr {
        build_mpfr(max_n, precision, dim, &out_dir);
    } else {
        build_f64(max_n, dim, &out_dir);
    }
}

fn build_mpfr(max_n: usize, precision: u32, dim: usize, out_dir: &PathBuf) {
    let effective_digits = (precision as f64 * 0.30103).floor() as u32;
    println!("  ── MPFR Build Configuration ──");
    println!("  MPFR precision  = {precision} bits (~{effective_digits} decimal digits)");
    println!(
        "  Matrix size     = {dim}×{dim} ({} unique entries)",
        dim * (dim + 1) / 2
    );
    println!("  Storage format  = DD (hi + lo words, ~31 digit roundtrip)");
    println!("  Method          = block-based fast algorithm (telescoping sums)\n");

    let table_size = (max_n * 5).max(10_000);
    println!("  Step 1/4: Building ln(n) table (n ≤ {table_size}, {precision}-bit)...");
    let t_table = Instant::now();
    let ln_n_table = gram::LnNTable::new(table_size, precision);
    println!(
        "  ✓ ln(n) table ready ({:.2}s)\n",
        t_table.elapsed().as_secs_f64()
    );

    println!("  Step 2/4: Computing Gram matrix at {precision}-bit MPFR...");
    let t_build = Instant::now();
    let (data_hi, data_lo, built_dim) = gram::GramMatrix::build_fast_dd(max_n, &ln_n_table);
    assert_eq!(built_dim, dim);
    println!(
        "  ✓ Gram matrix built in {:.2}s\n",
        t_build.elapsed().as_secs_f64()
    );

    // Cross-validate
    println!("  Step 3/4: Cross-validating MPFR vs f64...");
    let mut max_mpfr_f64_err = 0.0f64;
    let mut max_lo_magnitude = 0.0f64;
    let mut sum_lo_sq = 0.0f64;
    let check_count = std::cmp::min(500, dim * dim);
    for idx in 0..check_count {
        let hash = (idx.wrapping_mul(2654435761)) % (dim * dim);
        let row = hash / dim;
        let col = hash % dim;
        let mpfr_hi = data_hi[row * dim + col];
        let f64_val = gram::gram_entry_f64(row + 2, col + 2);
        let err = (mpfr_hi - f64_val).abs();
        max_mpfr_f64_err = max_mpfr_f64_err.max(err);
        let lo_mag = data_lo[row * dim + col].abs();
        max_lo_magnitude = max_lo_magnitude.max(lo_mag);
        sum_lo_sq += lo_mag * lo_mag;
    }
    let rms_lo = (sum_lo_sq / check_count as f64).sqrt();
    println!("  ✓ MPFR vs f64: max_err={max_mpfr_f64_err:.2e} ({check_count} entries)");
    println!("    DD lo-word: max={max_lo_magnitude:.2e}, RMS={rms_lo:.2e}");
    if max_mpfr_f64_err > 1e-10 {
        println!("    ⚠ Large discrepancy — f64 Kahan summation has limited precision here");
    } else {
        println!("    → f64 and MPFR agree to within expected f64 tolerance");
    }
    println!();

    let path = out_dir.join(format!("gram_N{max_n}_p{precision}.h5"));
    println!("  Step 4/4: Writing HPDF [DD] to {}...", path.display());

    let sha_input = format!("mpfr_{precision}_block_fast");
    let config = HpdfWriterConfig {
        max_n,
        precision,
        source_sha256: sha_input,
        builder: format!("hpdf build {max_n} --precision {precision}"),
        include_number_theory: max_n <= 100_000,
    };

    let size = hpdf::write_hpdf_dd(&path, &data_hi, &data_lo, &config).unwrap();
    println!("  ✓ File: {} ({} KB)\n", path.display(), size / 1024);

    super::full_verify(&path, Some(&data_hi), dim);

    println!("\n  ── DD Precision Summary ──");
    println!("  MPFR source     = {precision}-bit (~{effective_digits} digits)");
    println!("  DD hi storage   = f64 (52-bit mantissa, ~15.9 digits)");
    println!("  DD lo residual  = f64 (captures next ~15.9 digits)");
    println!("  Combined        = ~31 significant decimal digits");
    println!("  lo-word max     = {max_lo_magnitude:.4e}");
    println!("  lo-word RMS     = {rms_lo:.4e}");
}

fn build_f64(max_n: usize, dim: usize, out_dir: &PathBuf) {
    println!("  Building Gram matrix N={max_n} (dim={dim})...");
    let t0 = Instant::now();

    // Parallelize over upper-triangle (row, col) pairs for optimal load balance
    let pairs: Vec<(usize, usize)> = (0..dim)
        .flat_map(|row| (row..dim).map(move |col| (row, col)))
        .collect();
    let entries: Vec<((usize, usize), f64)> = pairs
        .par_iter()
        .map(|&(row, col)| {
            ((row, col), gram::gram_entry_f64(row + 2, col + 2))
        })
        .collect();

    let mut data = vec![0.0f64; dim * dim];
    for ((r, c), v) in entries {
        data[r * dim + c] = v;
        data[c * dim + r] = v;
    }
    println!("  ✓ Built in {:.2}s (parallel)", t0.elapsed().as_secs_f64());

    let path = out_dir.join(format!("gram_N{max_n}.h5"));
    let config = HpdfWriterConfig {
        max_n,
        precision: 0,
        source_sha256: "recomputed_f64".to_string(),
        builder: format!("hpdf build {max_n}"),
        include_number_theory: max_n <= 100_000,
    };

    let size = hpdf::write_hpdf(&path, &data, &config).unwrap();
    println!("  File: {} ({} KB)\n", path.display(), size / 1024);

    super::full_verify(&path, Some(&data), dim);
}

/// Build a ladder of HPDF files at multiple sizes.
pub fn build_ladder(sizes: &[usize]) {
    println!("{BOLD}{CYAN}╔═══════════════════════════════════════════════════╗{RESET}");
    println!(
        "{BOLD}{CYAN}║{RESET}  🏛️  HPDF LADDER — {} sizes                     {BOLD}{CYAN}║{RESET}",
        sizes.len()
    );
    println!("{BOLD}{CYAN}╚═══════════════════════════════════════════════════╝{RESET}\n");

    let out_dir = PathBuf::from("cache/hpdf");
    std::fs::create_dir_all(&out_dir).unwrap();

    let max_n = *sizes.iter().max().unwrap();
    let dim = max_n - 1;

    println!("  Building master matrix N={max_n} (dim={dim})...");
    let t0 = Instant::now();

    // Parallelize over upper-triangle (row, col) pairs
    let pairs: Vec<(usize, usize)> = (0..dim)
        .flat_map(|row| (row..dim).map(move |col| (row, col)))
        .collect();
    let entries: Vec<((usize, usize), f64)> = pairs
        .par_iter()
        .map(|&(row, col)| {
            ((row, col), gram::gram_entry_f64(row + 2, col + 2))
        })
        .collect();

    let mut data = vec![0.0f64; dim * dim];
    for ((r, c), v) in entries {
        data[r * dim + c] = v;
        data[c * dim + r] = v;
    }
    println!("  ✓ Master built in {:.2}s (parallel)\n", t0.elapsed().as_secs_f64());

    let mut sorted = sizes.to_vec();
    sorted.sort();
    sorted.dedup();

    for &n in sorted.iter().rev() {
        println!("  ┌── N={n} ──");
        let path = out_dir.join(format!("gram_N{n}.h5"));

        if n == max_n {
            let config = HpdfWriterConfig {
                max_n: n,
                precision: 0,
                source_sha256: "recomputed_f64".to_string(),
                builder: format!("hpdf ladder (master N={max_n})"),
                include_number_theory: n <= 100_000,
            };
            let size = hpdf::write_hpdf(&path, &data, &config).unwrap();
            println!("  │  Written: {} KB", size / 1024);
        } else {
            let size = hpdf::extract_submatrix_hpdf(
                &data,
                dim,
                n,
                0,
                &format!("extracted_from_N{max_n}"),
                &path,
            )
            .unwrap();
            println!("  │  Extracted from N={max_n}: {} KB", size / 1024);
        }

        let reader = HpdfReader::open(&path).unwrap();
        let sub_dim = n - 1;
        let n_checks = std::cmp::min(500, sub_dim * sub_dim);
        let (abs, rel) = reader.verify_spot_check(n_checks).unwrap();
        println!("  │  Spot-check ({n_checks} entries): abs={abs:.2e}, rel={rel:.2e}");

        if n < max_n {
            let sub_data = reader.read_gram_full().unwrap();
            let mut max_err = 0.0f64;
            for row in 0..sub_dim {
                for col in 0..sub_dim {
                    max_err = f64::max(
                        max_err,
                        (data[row * dim + col] - sub_data[row * sub_dim + col]).abs(),
                    );
                }
            }
            println!("  │  vs master: max_err={max_err:.2e}");
        }

        if let Ok(ss) = reader.read_structural_scalars() {
            println!(
                "  │  trace={:.6}, ‖G‖_F={:.6}, κ_est={:.2}",
                ss.trace, ss.frobenius_norm, ss.condition_estimate
            );
            if let (Some(g_min), Some(g_max)) =
                (ss.gershgorin_lambda_min, ss.gershgorin_lambda_max)
            {
                println!("  │  Gershgorin: λ∈[{g_min:.6}, {g_max:.6}]");
            }
        }

        let status = if abs < 1e-14 {
            format!("{GREEN}✓{RESET}")
        } else {
            format!("{RED}✗{RESET}")
        };
        println!("  └── {status} N={n} verified\n");
    }

    println!("  ═══ LADDER COMPLETE ═══");
    println!("  Files in: {}/", out_dir.display());
    for &n in &sorted {
        let path = out_dir.join(format!("gram_N{n}.h5"));
        let sz = std::fs::metadata(&path).map(|m| m.len()).unwrap_or(0);
        println!("    {} ({} KB)", path.display(), sz / 1024);
    }
}

/// Build a single Gram matrix using streaming upper-triangle-only construction.
///
/// This avoids allocating the full dim×dim matrix, halving RAM usage.
/// Essential for large N where the full matrix exceeds available RAM:
///
///   N=83,160:  full=55 GB, triangle=28 GB (fits in 62 GB!)
///   N=110,880: full=98 GB, triangle=49 GB (fits in 62 GB!)
///
/// With `--precision P` (P > 0), builds at P-bit MPFR → DD precision.
pub fn build_streaming(max_n: usize, precision: u32) {
    let dim = max_n - 1;
    let tri_len = dim * (dim + 1) / 2;
    let use_mpfr = precision > 0;
    let prec_label = if use_mpfr {
        format!("{precision}-bit MPFR → DD")
    } else {
        "f64 (Kahan)".to_string()
    };

    let tri_gb = (tri_len * 8) as f64 / 1e9;
    let dd_tri_gb = (tri_len * 16) as f64 / 1e9;

    println!("{BOLD}{CYAN}╔═══════════════════════════════════════════════════════════╗{RESET}");
    println!(
        "{BOLD}{CYAN}║{RESET}  🏛️  HPDF STREAMING BUILD — N={:<6}  [{:<18}] {BOLD}{CYAN}║{RESET}",
        max_n, prec_label
    );
    println!("{BOLD}{CYAN}╚═══════════════════════════════════════════════════════════╝{RESET}\n");

    println!("  ── Streaming Build Configuration ──");
    println!("  Matrix dimension  = {dim}×{dim}");
    println!("  Upper triangle    = {tri_len} entries ({tri_gb:.1} GB)");
    if use_mpfr {
        println!("  DD storage        = {dd_tri_gb:.1} GB (hi + lo)");
    }
    println!("  Mode              = streaming (no full dim×dim allocation)");
    println!("  Parallelism       = Rayon (all cores)\n");

    let out_dir = PathBuf::from("cache/hpdf");
    std::fs::create_dir_all(&out_dir).unwrap();

    if use_mpfr {
        build_streaming_dd(max_n, precision, dim, &out_dir);
    } else {
        build_streaming_f64(max_n, dim, &out_dir);
    }
}

fn build_streaming_f64(max_n: usize, dim: usize, out_dir: &PathBuf) {
    println!("  Step 1/2: Computing upper triangle (f64)...");
    let t0 = Instant::now();
    let upper_tri = gram::build_upper_triangle_f64(max_n);
    println!("  ✓ Upper triangle computed in {:.2}s\n", t0.elapsed().as_secs_f64());

    let path = out_dir.join(format!("gram_N{max_n}.h5"));
    println!("  Step 2/2: Writing HPDF to {}...", path.display());
    let config = HpdfWriterConfig {
        max_n,
        precision: 0,
        source_sha256: "streaming_f64".to_string(),
        builder: format!("hpdf build-streaming {max_n}"),
        include_number_theory: max_n <= 100_000,
    };

    let size = hpdf::write_hpdf_from_triangle(&path, &upper_tri, &config).unwrap();
    println!("  ✓ File: {} ({} MB)\n", path.display(), size / (1024 * 1024));

    // Spot-check against recomputed entries
    println!("  Verifying...");
    let reader = HpdfReader::open(&path).unwrap();
    let n_checks = std::cmp::min(500, dim * dim);
    let (abs, rel) = reader.verify_spot_check(n_checks).unwrap();
    println!("  ✓ Spot-check ({n_checks} entries): abs={abs:.2e}, rel={rel:.2e}");
    if abs < 1e-14 {
        println!("  {GREEN}✓{RESET} N={max_n} verified\n");
    } else {
        println!("  {RED}✗{RESET} N={max_n} verification failed (abs={abs:.2e})\n");
    }
}

fn build_streaming_dd(max_n: usize, precision: u32, dim: usize, out_dir: &PathBuf) {
    let table_size = (max_n * 5).max(10_000);
    println!("  Step 1/3: Building ln(n) table (n ≤ {table_size}, {precision}-bit)...");
    let t_table = Instant::now();
    let ln_n_table = gram::LnNTable::new(table_size, precision);
    println!("  ✓ ln(n) table ready ({:.2}s)\n", t_table.elapsed().as_secs_f64());

    println!("  Step 2/3: Computing upper triangle DD ({precision}-bit MPFR)...");
    let t_build = Instant::now();
    let (upper_tri_hi, upper_tri_lo, built_dim) = gram::build_upper_triangle_fast_dd(max_n, &ln_n_table);
    assert_eq!(built_dim, dim);
    println!("  ✓ Upper triangle DD computed in {:.2}s\n", t_build.elapsed().as_secs_f64());

    let path = out_dir.join(format!("gram_N{max_n}.h5"));
    println!("  Step 3/3: Writing HPDF [DD] to {}...", path.display());
    let config = HpdfWriterConfig {
        max_n,
        precision,
        source_sha256: format!("streaming_mpfr_{precision}_block_fast"),
        builder: format!("hpdf build-streaming {max_n} --precision {precision}"),
        include_number_theory: max_n <= 100_000,
    };

    let size = hpdf::write_hpdf_dd_from_triangle(&path, &upper_tri_hi, &upper_tri_lo, &config).unwrap();
    println!("  ✓ File: {} ({} MB)\n", path.display(), size / (1024 * 1024));

    // Spot-check
    println!("  Verifying...");
    let reader = HpdfReader::open(&path).unwrap();
    let n_checks = std::cmp::min(500, dim * dim);
    let (abs, rel) = reader.verify_spot_check(n_checks).unwrap();
    println!("  ✓ Spot-check ({n_checks} entries): abs={abs:.2e}, rel={rel:.2e}");
    assert!(reader.has_dd(), "DD data should be present");
    println!("  ✓ DD lo-words present");
    if abs < 1e-6 {
        println!("  {GREEN}✓{RESET} N={max_n} verified (MPFR vs f64 within expected tolerance)\n");
    } else {
        println!("  {RED}✗{RESET} N={max_n} verification failed (abs={abs:.2e})\n");
    }
}
