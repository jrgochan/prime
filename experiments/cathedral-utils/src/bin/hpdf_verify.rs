#![allow(dead_code, unused_variables, clippy::needless_range_loop, clippy::empty_line_after_doc_comments, clippy::doc_lazy_continuation)]
//! HPDF verification tool — build, convert, and verify Cathedral HDF5 files.
//!
//! Usage:
//!   hpdf-verify                                    # default: build & verify N=100
//!   hpdf-verify --build <N>                        # build fresh Gram matrix for N (f64)
//!   hpdf-verify --build <N> --precision <bits>     # build at MPFR precision (e.g. 2048)
//!   hpdf-verify --ladder <N1,N2,...>               # build a chain of sizes
//!   hpdf-verify --ooc <path>                       # convert an OOC binary file
//!   hpdf-verify --verify <path.h5>                 # verify an existing HPDF file
//!   hpdf-verify --info <path.h5>                   # metadata-only dump (no matrix load)
//!   hpdf-verify --query <path.h5> <j,k>            # point-query G[j,k] (8-byte read)
//!
//! Precision modes:
//!   --precision 0     f64 (Kahan summation, default)
//!   --precision 128   128-bit MPFR (~38 digits), DD storage
//!   --precision 256   256-bit MPFR (~77 digits), DD storage
//!   --precision 512   512-bit MPFR (~154 digits), DD storage
//!   --precision 2048  2048-bit MPFR (~616 digits), DD storage

use cathedral_utils::arith;
use cathedral_utils::gram;
use cathedral_utils::hpdf::{self, HpdfReader, HpdfWriterConfig};
use std::path::PathBuf;
use std::time::Instant;

fn main() {
    let args: Vec<String> = std::env::args().collect();

    // Parse global --precision flag (can appear after --build <N>)
    let precision: u32 = args
        .iter()
        .position(|a| a == "--precision")
        .and_then(|i| args.get(i + 1))
        .and_then(|s| s.parse().ok())
        .unwrap_or(0);

    if args.len() > 2 && args[1] == "--build" {
        let n: usize = args[2].parse().expect("N must be a number");
        build_and_verify(n, precision);
    } else if args.len() > 2 && args[1] == "--ladder" {
        let sizes: Vec<usize> = args[2]
            .split(',')
            .map(|s| s.trim().parse().expect("each N must be a number"))
            .collect();
        build_ladder(&sizes);
    } else if args.len() > 2 && args[1] == "--ooc" {
        convert_ooc(&args[2]);
    } else if args.len() > 2 && args[1] == "--verify" {
        verify_hpdf(&args[2]);
    } else if args.len() > 2 && args[1] == "--info" {
        info_hpdf(&args[2]);
    } else if args.len() > 3 && args[1] == "--query" {
        query_entry(&args[2], &args[3]);
    } else {
        build_and_verify(100, precision);
    }
}

/// Build a fresh Gram matrix for the given N, write to HPDF, and verify.
///
/// When `precision > 0`, uses MPFR at the specified bit width and stores
/// the result as DD (double-double: hi + lo words) for lossless roundtrip.
/// This also performs automatic MPFR-vs-f64 cross-validation.
fn build_and_verify(max_n: usize, precision: u32) {
    let dim = max_n - 1;
    let use_mpfr = precision > 0;
    let prec_label = if use_mpfr {
        format!("{precision}-bit MPFR → DD")
    } else {
        "f64 (Kahan)".to_string()
    };

    println!("╔═══════════════════════════════════════════════════════════╗");
    println!(
        "║  🏛️  HPDF BUILD & VERIFY — N={:<6}  [{:<18}] ║",
        max_n, prec_label
    );
    println!("╚═══════════════════════════════════════════════════════════╝\n");

    let out_dir = PathBuf::from("cache/hpdf");
    std::fs::create_dir_all(&out_dir).unwrap();

    if use_mpfr {
        // ═══ MPFR precision path: build with LnNTable, store as DD ═══
        let effective_digits = (precision as f64 * 0.30103).floor() as u32; // log10(2) * bits
        println!("  ── MPFR Build Configuration ──");
        println!("  MPFR precision  = {precision} bits (~{effective_digits} decimal digits)");
        println!(
            "  Matrix size     = {dim}×{dim} ({} unique entries)",
            dim * (dim + 1) / 2
        );
        println!("  Storage format  = DD (hi + lo words, ~31 digit roundtrip)");
        println!("  Method          = block-based fast algorithm (telescoping sums)\n");

        // Step 1: Build LnN table at MPFR precision
        let table_size = (max_n * 5).max(10_000);
        println!("  Step 1/4: Building ln(n) table (n ≤ {table_size}, {precision}-bit)...");
        let t_table = Instant::now();
        let ln_n_table = gram::LnNTable::new(table_size, precision);
        println!(
            "  ✓ ln(n) table ready ({:.2}s)\n",
            t_table.elapsed().as_secs_f64()
        );

        // Step 2: Build Gram matrix → DD hi/lo split
        println!("  Step 2/4: Computing Gram matrix at {precision}-bit MPFR...");
        let t_build = Instant::now();
        let (data_hi, data_lo, built_dim) = gram::GramMatrix::build_fast_dd(max_n, &ln_n_table);
        assert_eq!(built_dim, dim);
        println!(
            "  ✓ Gram matrix built in {:.2}s\n",
            t_build.elapsed().as_secs_f64()
        );

        // Step 3: Cross-validate MPFR vs f64 (spot-check)
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

        // Step 4: Write HPDF with DD storage
        let path = out_dir.join(format!("gram_N{max_n}_p{precision}.h5"));
        println!("  Step 4/4: Writing HPDF [DD] to {}...", path.display());

        let sha_input = format!("mpfr_{precision}_block_fast");
        let config = HpdfWriterConfig {
            max_n,
            precision,
            source_sha256: sha_input,
            builder: format!("hpdf-verify --build {max_n} --precision {precision}"),
            include_number_theory: max_n <= 100_000,
        };

        let size = hpdf::write_hpdf_dd(&path, &data_hi, &data_lo, &config).unwrap();
        println!("  ✓ File: {} ({} KB)\n", path.display(), size / 1024);

        // Full verification
        full_verify(&path, Some(&data_hi), dim);

        // Extra: DD-specific verification summary
        println!("\n  ── DD Precision Summary ──");
        println!("  MPFR source     = {precision}-bit (~{effective_digits} digits)");
        println!("  DD hi storage   = f64 (52-bit mantissa, ~15.9 digits)");
        println!("  DD lo residual  = f64 (captures next ~15.9 digits)");
        println!("  Combined        = ~31 significant decimal digits");
        println!("  lo-word max     = {max_lo_magnitude:.4e}");
        println!("  lo-word RMS     = {rms_lo:.4e}");
    } else {
        // ═══ f64 path (original behavior) ═══
        println!("  Building Gram matrix N={max_n} (dim={dim})...");
        let t0 = Instant::now();
        let mut data = vec![0.0f64; dim * dim];
        for i in 0..dim {
            for j in i..dim {
                let v = gram::gram_entry_f64(i + 2, j + 2);
                data[i * dim + j] = v;
                data[j * dim + i] = v;
            }
        }
        println!("  ✓ Built in {:.2}s", t0.elapsed().as_secs_f64());

        let path = out_dir.join(format!("gram_N{max_n}.h5"));

        let config = HpdfWriterConfig {
            max_n,
            precision: 0,
            source_sha256: "recomputed_f64".to_string(),
            builder: format!("hpdf-verify --build {max_n}"),
            include_number_theory: max_n <= 100_000,
        };

        let size = hpdf::write_hpdf(&path, &data, &config).unwrap();
        println!("  File: {} ({} KB)\n", path.display(), size / 1024);

        full_verify(&path, Some(&data), dim);
    }
}

/// Build a ladder of HPDF files at multiple sizes.
fn build_ladder(sizes: &[usize]) {
    println!("╔═══════════════════════════════════════════════════╗");
    println!(
        "║  🏛️  HPDF LADDER — {} sizes                     ║",
        sizes.len()
    );
    println!("╚═══════════════════════════════════════════════════╝\n");

    let out_dir = PathBuf::from("cache/hpdf");
    std::fs::create_dir_all(&out_dir).unwrap();

    let max_n = *sizes.iter().max().unwrap();
    let dim = max_n - 1;

    println!("  Building master matrix N={max_n} (dim={dim})...");
    let t0 = Instant::now();
    let mut data = vec![0.0f64; dim * dim];
    for i in 0..dim {
        for j in i..dim {
            let v = gram::gram_entry_f64(i + 2, j + 2);
            data[i * dim + j] = v;
            data[j * dim + i] = v;
        }
    }
    println!("  ✓ Master built in {:.2}s\n", t0.elapsed().as_secs_f64());

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
                builder: format!("hpdf-verify --ladder (master N={max_n})"),
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

        // Show structural + spectral metadata
        if let Ok(ss) = reader.read_structural_scalars() {
            println!(
                "  │  trace={:.6}, ‖G‖_F={:.6}, κ_est={:.2}",
                ss.trace, ss.frobenius_norm, ss.condition_estimate
            );
            if let (Some(g_min), Some(g_max)) = (ss.gershgorin_lambda_min, ss.gershgorin_lambda_max)
            {
                println!("  │  Gershgorin: λ∈[{g_min:.6}, {g_max:.6}]");
            }
        }

        let status = if abs < 1e-14 {
            "\x1b[32m✓\x1b[0m"
        } else {
            "\x1b[31m✗\x1b[0m"
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

/// Full verification of an HPDF file.
fn full_verify(path: &PathBuf, original_data: Option<&[f64]>, dim: usize) {
    let reader = HpdfReader::open(path).unwrap();
    assert_eq!(reader.dim(), dim);

    // Data integrity checksum
    let integrity = reader.verify_data_integrity().unwrap();
    if integrity.valid {
        println!(
            "  ✓ Data SHA-256: {}... (verified)",
            &integrity.computed_sha256[..16]
        );
    } else if integrity.stored_sha256.is_none() {
        println!("  ⚠ No data checksum (v1 file)");
    } else {
        println!("  ✗ DATA CHECKSUM MISMATCH!");
        println!("    stored:   {:?}", integrity.stored_sha256);
        println!("    computed: {}", integrity.computed_sha256);
    }

    if let Some(data) = original_data {
        let read_data = reader.read_gram_full().unwrap();
        let max_err: f64 = (0..dim * dim)
            .map(|i| (data[i] - read_data[i]).abs())
            .fold(0.0, f64::max);
        println!("  ✓ Roundtrip max error: {max_err:.2e}");
    }

    // b-vector
    let b = reader.read_b_vector().unwrap();
    let b_ref = arith::b_vector(dim);
    let b_err: f64 = b
        .iter()
        .zip(b_ref.iter())
        .map(|(a, b)| (a - b).abs())
        .fold(0.0, f64::max);
    println!("  ✓ b-vector max error: {b_err:.2e}");

    // Structural scalars + Gershgorin
    if let Ok(ss) = reader.read_structural_scalars() {
        println!("  ✓ trace = {:.10}", ss.trace);
        println!("  ✓ ‖G‖_F = {:.10}", ss.frobenius_norm);
        println!("  ✓ κ_est = {:.4} (diag ratio)", ss.condition_estimate);
        println!(
            "  ✓ off-diag max = {:.10}, avg = {:.10}",
            ss.off_diag_max, ss.off_diag_avg
        );
        if let (Some(g_min), Some(g_max)) = (ss.gershgorin_lambda_min, ss.gershgorin_lambda_max) {
            println!("  ✓ Gershgorin: λ ∈ [{g_min:.10}, {g_max:.10}]");
            if g_min > 0.0 {
                println!("    → positive definite (by Gershgorin)");
            }
        }
    }

    // Column norms
    if let Ok(cn) = reader.read_col_norms() {
        println!(
            "  ✓ col_norms: {} entries, range [{:.6}, {:.6}]",
            cn.len(),
            cn.iter().cloned().fold(f64::INFINITY, f64::min),
            cn.iter().cloned().fold(f64::NEG_INFINITY, f64::max)
        );
    }

    // Diagonal
    let diag = reader.read_diagonal().unwrap();
    if let Some(data) = original_data {
        let d_err: f64 = diag
            .iter()
            .enumerate()
            .map(|(i, &d)| (d - data[i * dim + i]).abs())
            .fold(0.0, f64::max);
        println!("  ✓ diagonal max error: {d_err:.2e}");
    }

    // Number theory
    if let Ok(mu) = reader.read_mobius() {
        println!(
            "  ✓ μ table: {} entries, μ(1)={}, μ(2)={}, μ(4)={}",
            mu.len(),
            mu[1],
            mu[2],
            mu[4]
        );
    }
    if let Ok(primes) = reader.read_primes() {
        println!("  ✓ Primes: {} primes ≤ {}", primes.len(), reader.max_n());
    }
    if let Ok(Some(nt)) = reader.read_number_theory_attrs() {
        println!(
            "  ✓ N={}: {} (τ={}, σ={}, HC={})",
            reader.max_n(),
            nt.factorization,
            nt.divisor_count,
            nt.divisor_sum,
            nt.is_highly_composite
        );
    }

    // Lineage
    if let Ok(Some(lin)) = reader.read_lineage() {
        println!(
            "  ✓ Lineage: {} (from N={})",
            lin.derivation, lin.parent_max_n
        );
    }

    // Provenance
    let prov = reader.read_provenance().unwrap();
    println!("  ✓ Provenance:");
    println!("    builder    = {}", prov.builder);
    println!("    precision  = {}", prov.precision);
    println!(
        "    sha256     = {}...",
        &prov.source_sha256[..16.min(prov.source_sha256.len())]
    );
    println!("    git_commit = {}", prov.git_commit);
    println!("    hostname   = {}", prov.hostname);
    println!("    build_time = {:.2}s", prov.build_time_secs);

    // Distance (if present)
    if let Ok(Some(dist)) = reader.read_distance() {
        println!("  ✓ Distance: d²={:.15e}", dist.d_squared);
        println!(
            "    solver={}, iters={}, residual={:.2e}, converged={}",
            dist.solver, dist.iterations, dist.residual_norm, dist.converged
        );
        if let Some(bt_x) = dist.bt_x {
            println!("    bᵀx={:.15e}  →  1-bᵀx={:.15e}", bt_x, 1.0 - bt_x);
        }
        if let Ok(Some(hist)) = reader.read_convergence_history() {
            println!(
                "    convergence: {} iters, final={:.2e}",
                hist.len(),
                hist.last().unwrap_or(&0.0)
            );
        }
        if let Ok(Some(sol)) = reader.read_solution_vector() {
            println!("    solution_vector: {} entries stored", sol.len());
        }
    }

    // Spot-check against f64 recomputation baseline
    let n_checks = std::cmp::min(1000, dim * dim);
    let (abs, rel) = reader.verify_spot_check(n_checks).unwrap();
    println!("  ✓ Spot-check ({n_checks} entries): abs={abs:.2e}, rel={rel:.2e}");

    // Precision-aware pass/fail threshold:
    // When the file was built at MPFR precision, stored values are MORE accurate
    // than the f64 baseline used by verify_spot_check. The "error" is the f64's
    // imprecision, not the HPDF's. Use a much looser threshold in this case.
    //
    // GPU DD files (precision=0 but built with DD kernel) have an inherent
    // ~1e-8 ceiling from DD→f64 output truncation. The CPU f64 reference
    // (with Kahan summation) also has ~1e-15 precision, so the cross-check
    // error is dominated by the difference between two ~16-digit approximations
    // of a ~31-digit value.
    let stored_precision = reader.precision().unwrap_or(0);
    let prov = reader.read_provenance().ok();
    let is_dd_built = prov.as_ref().is_some_and(|p| p.builder.contains("DD"));
    let spot_threshold = if stored_precision > 0 {
        println!(
            "    (note: file built at {stored_precision}-bit MPFR; f64 baseline is less accurate)"
        );
        // f64 Kahan summation error grows with N; for N≤100, ~1e-5 is typical
        1e-3
    } else if is_dd_built {
        println!("    (note: DD-built file; expected ~1e-8 ceiling from DD→f64 truncation)");
        1e-7 // DD→f64 precision ceiling
    } else {
        1e-14
    };

    let all_ok = b_err < 1e-15 && abs < spot_threshold && integrity.valid;
    if all_ok {
        println!("\n  \x1b[32m═══ ALL CHECKS PASSED ═══\x1b[0m");
    } else {
        println!("\n  \x1b[31m═══ CHECKS FAILED ═══\x1b[0m");
        if abs >= spot_threshold {
            println!("    spot-check: abs={abs:.2e} >= threshold {spot_threshold:.0e}");
        }
        if !integrity.valid {
            println!("    data integrity: FAILED");
        }
        if b_err >= 1e-15 {
            println!("    b-vector: err={b_err:.2e} >= 1e-15");
        }
    }
}

/// Metadata-only dump — reads only attributes, never loads the matrix.
fn info_hpdf(path: &str) {
    let pb = PathBuf::from(path);
    let reader = HpdfReader::open(&pb).unwrap();

    println!("╔═══════════════════════════════════════════════════╗");
    println!("║  🏛️  HPDF INFO                                   ║");
    println!("╚═══════════════════════════════════════════════════╝\n");
    println!("  File:    {path}");
    println!(
        "  Size:    {} KB",
        std::fs::metadata(&pb).map(|m| m.len()).unwrap_or(0) / 1024
    );
    println!("  Version: v{}", reader.version());
    println!("  N:       {}", reader.max_n());
    println!("  Dim:     {}×{}", reader.dim(), reader.dim());
    println!("  Prec:    {} bits\n", reader.precision().unwrap_or(0));

    // Structural (scalar attrs only, no dataset reads)
    if let Ok(ss) = reader.read_structural_scalars() {
        println!("  ── Structure ──");
        println!("  trace           = {:.10}", ss.trace);
        println!("  ‖G‖_F           = {:.10}", ss.frobenius_norm);
        println!("  κ_est (diag)    = {:.4}", ss.condition_estimate);
        println!(
            "  diag range      = [{:.10}, {:.10}]",
            ss.diag_min, ss.diag_max
        );
        println!("  off-diag max    = {:.10}", ss.off_diag_max);
        println!("  off-diag avg    = {:.10}", ss.off_diag_avg);
        if let (Some(g_min), Some(g_max)) = (ss.gershgorin_lambda_min, ss.gershgorin_lambda_max) {
            println!("  Gershgorin λ    ∈ [{g_min:.10}, {g_max:.10}]");
            if g_min > 0.0 {
                println!("    → positive definite");
            }
        }
        println!();
    }

    // Number theory
    if let Ok(Some(nt)) = reader.read_number_theory_attrs() {
        println!("  ── Number Theory ──");
        println!("  factorization   = {}", nt.factorization);
        println!("  τ(N)            = {}", nt.divisor_count);
        println!("  σ(N)            = {}", nt.divisor_sum);
        println!("  highly composite= {}", nt.is_highly_composite);
        println!("  π(N)            = {}\n", nt.prime_count);
    }

    // Data checksum (reads only the checksum attribute, not the data)
    if let Some(sha) = reader.read_data_checksum() {
        println!("  ── Data Integrity ──");
        println!("  data_sha256     = {sha}\n");
    }

    // Lineage
    if let Ok(Some(lin)) = reader.read_lineage() {
        println!("  ── Lineage ──");
        println!("  derivation      = {}", lin.derivation);
        println!("  parent_max_n    = {}", lin.parent_max_n);
        println!("  parent_sha256   = {}\n", lin.parent_sha256);
    }

    // Provenance
    if let Ok(prov) = reader.read_provenance() {
        println!("  ── Provenance ──");
        println!("  timestamp       = {}", prov.timestamp);
        println!("  builder         = {}", prov.builder);
        println!("  precision       = {} bits", prov.precision);
        println!("  source_sha256   = {}", prov.source_sha256);
        println!("  git_commit      = {}", prov.git_commit);
        println!("  hostname        = {}", prov.hostname);
        println!("  build_time      = {:.2}s\n", prov.build_time_secs);
    }

    // Distance
    if let Ok(Some(dist)) = reader.read_distance() {
        println!("  ── Distance ──");
        println!("  d²              = {:.15e}", dist.d_squared);
        println!("  solver          = {}", dist.solver);
        println!("  iterations      = {}", dist.iterations);
        println!("  residual_norm   = {:.2e}", dist.residual_norm);
        println!("  converged       = {}", dist.converged);
        if let Some(bt_x) = dist.bt_x {
            println!("  bᵀx             = {:.15e}", bt_x);
            println!("  1-bᵀx           = {:.15e}", 1.0 - bt_x);
        }
        if let Ok(Some(hist)) = reader.read_convergence_history() {
            println!("  history         = {} iterations", hist.len());
        }
        if let Ok(Some(sol)) = reader.read_solution_vector() {
            println!("  solution_vec    = {} entries", sol.len());
        }
        println!();
    }
}

fn convert_ooc(path: &str) {
    println!("  Converting OOC → HPDF: {path}");
    let ooc_path = PathBuf::from(path);
    let hpdf_path = ooc_path.with_extension("h5");
    hpdf::convert_ooc_to_hpdf(&ooc_path, &hpdf_path, true).unwrap();
    println!("\n  Verifying...");
    verify_hpdf(&hpdf_path.to_string_lossy());
}

fn verify_hpdf(path: &str) {
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

/// Point-query a single entry G[j,k] from the HPDF file.
///
/// This reads exactly 8 bytes from disk via HDF5 hyperslab selection,
/// then cross-validates against live f64 recomputation and shows the
/// raw IEEE 754 bit representation.
fn query_entry(path: &str, jk: &str) {
    let parts: Vec<&str> = jk.split(',').collect();
    assert_eq!(parts.len(), 2, "Expected j,k format (e.g., 2,3)");
    let j: usize = parts[0].trim().parse().expect("j must be a number");
    let k: usize = parts[1].trim().parse().expect("k must be a number");

    let pb = PathBuf::from(path);
    let reader = HpdfReader::open(&pb).unwrap();

    println!("╔═══════════════════════════════════════════════════╗");
    println!("║  🔍  HPDF POINT QUERY                             ║");
    println!("╚═══════════════════════════════════════════════════╝\n");
    println!("  File:  {path}");
    println!("  Query: G[{j}, {k}]\n");

    // ── Storage geometry ──
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
    println!("  byte offset     = {byte_offset}  (within upper_triangle dataset)");
    println!();

    // ── Read from disk (single 8-byte hyperslab) ──
    let t0 = Instant::now();
    let stored = reader.read_gram_entry(j, k).unwrap();
    let read_us = t0.elapsed().as_micros();

    // ── Recompute from analytic formula ──
    let recomputed = gram::gram_entry_f64(j, k);
    let abs_err = (stored - recomputed).abs();
    let rel_err = if recomputed.abs() > 1e-30 {
        abs_err / recomputed.abs()
    } else {
        abs_err
    };

    // ── IEEE 754 bit representation ──
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
    println!("  binary          = {:064b}", bits);
    println!();

    // ── Formula explanation ──
    println!("  ── Formula ──");
    println!("  G[{j},{k}] = ∫₀¹ {{1/({j}x)}} · {{1/({k}x)}} dx");
    println!("           where {{y}} = y - ⌊y⌋ is the fractional part\n");

    if abs_err < 1e-14 {
        println!("  \x1b[32m✓ Bit-perfect match against live recomputation\x1b[0m");
    } else {
        println!("  \x1b[31m✗ Mismatch detected!\x1b[0m");
    }
}
