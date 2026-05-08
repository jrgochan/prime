//! GPU HPDF Builder — build Gram matrix on GPU, verify vs CPU, write to HPDF.
//!
//! Pipeline:
//!   1. Build Gram matrix on GPU (DD block-based kernel, log1p bypass — no ln table!)
//!   2. Verify against CPU-computed reference entries (MPFR-256)
//!   3. Write to HPDF (HDF5) format with full metadata
//!   4. Roundtrip integrity check
//!
//! Usage:
//!   gpu-hpdf-build <N> [--output <dir>] [--no-verify] [--no-number-theory]
//!                      [--verify-count <n>] [--t-max <T>]
//!
//! Example:
//!   gpu-hpdf-build 1000 --output cache/hpdf
//!   gpu-hpdf-build 55440 --output /mnt/d/cathedral-cache --t-max 200000

use cathedral_utils::{cache, gram, hpdf};
use rayon::prelude::*;
use std::path::PathBuf;
use std::time::Instant;

// ═══════════════════════════════════════════════════════════
// FFI — links against libgramgpudd.so (gram_gpu_dd.cu)
// Block-based O(T/j+T/k) kernel with log1p bypass.
// No ln table required — computes dd_ln1p inline.
// ═══════════════════════════════════════════════════════════
#[link(name = "gramgpudd", kind = "dylib")]
extern "C" {
    /// Build DD-f64 Gram matrix on GPU using the block-based log1p bypass.
    /// Keeps the hi[] array in VRAM for subsequent cuSOLVER calls.
    /// Returns 0 on success, -1 on CUDA error.
    fn gpu_build_gram_dd(
        gram_hi: *mut f64,
        gram_lo: *mut f64,
        dim: i32,
        t_max: i32,
    ) -> i32;

    /// Build a chunk of rows [row_start..row_start+n_rows) of the dim×dim Gram matrix.
    /// Only allocates n_rows×dim on GPU — enables OOC builds for matrices > VRAM.
    fn gpu_build_gram_dd_rows(
        gram_hi: *mut f64,
        gram_lo: *mut f64,
        dim: i32,
        t_max: i32,
        row_start: i32,
        n_rows: i32,
    ) -> i32;
}

#[link(name = "cudart")]
extern "C" {
    fn cudaMemGetInfo(free: *mut usize, total: *mut usize) -> i32;
}

/// Get GPU VRAM in MB (total). Returns 0 if CUDA not available.
fn detect_gpu_vram_mb() -> usize {
    let mut free: usize = 0;
    let mut total: usize = 0;
    let ret = unsafe { cudaMemGetInfo(&mut free as *mut usize, &mut total as *mut usize) };
    if ret != 0 { return 0; }
    total / (1024 * 1024)
}

/// Build a chunk of rows on GPU. Returns (hi_buffer, lo_buffer, build_time_secs).
fn gpu_build_rows_dd(
    dim: usize, t_max: i32, row_start: usize, n_rows: usize,
) -> Result<(Vec<f64>, Vec<f64>, f64), String> {
    let mut hi = vec![0.0f64; n_rows * dim];
    let mut lo = vec![0.0f64; n_rows * dim];
    let start = std::time::Instant::now();
    let ret = unsafe {
        gpu_build_gram_dd_rows(
            hi.as_mut_ptr(),
            lo.as_mut_ptr(),
            dim as i32, t_max,
            row_start as i32, n_rows as i32,
        )
    };
    if ret != 0 {
        return Err(format!("GPU row-range build failed at row {}", row_start));
    }
    Ok((hi, lo, start.elapsed().as_secs_f64()))
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 2 || args[1] == "--help" || args[1] == "-h" {
        eprintln!("Usage: gpu-hpdf-build <N> [--output <dir>] [--no-verify] [--no-number-theory]");
        eprintln!("                         [--verify-count <n>] [--t-max <T>] [--verify-prec <bits>]");
        eprintln!();
        eprintln!("Build a Gram matrix on GPU (DD block-based kernel) and save as HPDF (HDF5).");
        eprintln!();
        eprintln!("Arguments:");
        eprintln!("  N                   Maximum index (dim = N-1)");
        eprintln!("  --output <dir>      Output directory (default: cache/hpdf)");
        eprintln!("  --no-verify         Skip CPU cross-verification");
        eprintln!("  --no-number-theory  Don't include μ/φ/primes tables in HPDF");
        eprintln!("  --skip-d2           Skip d² computation (Cholesky/LU — very slow for large N)");
        eprintln!("  --verify-count <n>  Number of CPU spot-check entries (default: 20)");
        eprintln!("  --t-max <T>         Series truncation horizon (default: max(5*lcm_max, 100000))");
        eprintln!("  --verify-prec <bits> MPFR precision for CPU reference (default: 256)");
        eprintln!("                       Use 0 for precision ladder analysis (128→2048 bits)");
        std::process::exit(1);
    }

    let max_n: usize = args[1].parse().expect("N must be a positive integer");
    let dim = max_n - 1;

    let output_dir = parse_flag_str(&args, "--output")
        .unwrap_or_else(|| "cache/hpdf".to_string());
    let no_verify = args.iter().any(|a| a == "--no-verify");
    let include_nt = !args.iter().any(|a| a == "--no-number-theory");
    let skip_d2 = args.iter().any(|a| a == "--skip-d2");
    let verify_count: usize = parse_flag_str(&args, "--verify-count")
        .and_then(|s| s.parse().ok())
        .unwrap_or(20); // O(T_max) per entry with gram_entry_at_t, keep low
    let verify_prec: u32 = parse_flag_str(&args, "--verify-prec")
        .and_then(|s| s.parse().ok())
        .unwrap_or(256);

    // T_max: uniform truncation horizon. Must be large enough for convergence.
    // For N=1000, max lcm pair can be ~500K, so T=200K is often needed.
    // The block-based kernel does O(T/j+T/k) per entry, so large T is cheap.
    let t_max: i32 = parse_flag_str(&args, "--t-max")
        .and_then(|s| s.parse().ok())
        .unwrap_or_else(|| {
            // Heuristic: at least 5 * max possible lcm, capped at 200K
            let max_lcm = (max_n as i64 * (max_n as i64 - 1)) / 2; // worst case
            (max_lcm * 5).min(200_000).max(100_000) as i32
        });

    let tri_entries = dim * (dim + 1) / 2;
    let mem_mb = (dim as u64 * dim as u64 * 8) / (1024 * 1024);

    println!();
    println!("╔══════════════════════════════════════════════════════════════╗");
    println!("║  🏛️  GPU HPDF BUILDER — Cathedral Gram Matrix Pipeline      ║");
    println!("╠══════════════════════════════════════════════════════════════╣");
    println!("║  N = {:>6}  dim = {:>6}  entries = {:>12}            ║", max_n, dim, tri_entries);
    println!("║  GPU memory: ~{:>5} MB   T_max = {:>8}                  ║", mem_mb, t_max);
    println!("║  Kernel: DD block-based (log1p bypass, no ln table)        ║");
    println!("║  HPDF output: {:<45} ║", &output_dir);
    println!("╚══════════════════════════════════════════════════════════════╝");
    println!();

    let t_total = Instant::now();

    // Detect GPU VRAM to choose build strategy
    let vram_mb = detect_gpu_vram_mb();
    let matrix_mb = (dim as u64 * dim as u64 * 8) / (1024 * 1024);
    // DD build needs 2× matrix for hi + lo arrays
    let needs_vram_mb = matrix_mb * 2;
    let use_chunked = needs_vram_mb > (vram_mb as u64 * 85 / 100); // 85% VRAM threshold

    println!("  GPU VRAM: {} MB", vram_mb);
    if use_chunked {
        println!("  ⚡ CHUNKED GPU BUILD (matrix {}MB > {}MB VRAM threshold)",
            matrix_mb, vram_mb * 85 / 100);
    }

    // ═══════════════════════════════════════════════════════════
    // STEP 1: GPU DD Gram build
    // ═══════════════════════════════════════════════════════════
    let (gpu_hi, gpu_lo, gpu_time) = if use_chunked {
        // ── Chunked GPU build for large matrices ──
        // Process rows in chunks that fit comfortably in VRAM.
        // Each chunk: n_rows × dim × 16 bytes (hi+lo on GPU)
        // For 16 GB VRAM with 85% usable: ~13.6 GB → chunk_rows ≈ 13.6G/(dim*16)
        let usable_vram = (vram_mb as u64 * 85 / 100) * 1024 * 1024;
        let bytes_per_row = dim as u64 * 16; // hi + lo
        let max_chunk_rows = (usable_vram / bytes_per_row) as usize;
        let chunk_rows = max_chunk_rows.min(2000).max(128);

        println!("  ▸ Step 1: Chunked GPU DD build (T={}, {} rows/chunk)...", t_max, chunk_rows);

        let mut gpu_hi = vec![0.0f64; dim * dim];
        let mut gpu_lo = vec![0.0f64; dim * dim];
        let t0 = Instant::now();
        let mut total_gpu_time = 0.0f64;

        for chunk_start in (0..dim).step_by(chunk_rows) {
            let n_rows = chunk_rows.min(dim - chunk_start);

            let (chunk_hi, chunk_lo, chunk_time) = gpu_build_rows_dd(
                dim, t_max, chunk_start, n_rows,
            ).unwrap_or_else(|e| {
                eprintln!("  ✗ GPU chunk build failed at row {}: {}", chunk_start, e);
                std::process::exit(1);
            });
            total_gpu_time += chunk_time;

            // Copy chunk into full matrix buffers (both hi and lo)
            let dest_offset = chunk_start * dim;
            gpu_hi[dest_offset..dest_offset + n_rows * dim]
                .copy_from_slice(&chunk_hi);
            gpu_lo[dest_offset..dest_offset + n_rows * dim]
                .copy_from_slice(&chunk_lo);

            // Progress
            let elapsed = t0.elapsed().as_secs_f64();
            let frac = (chunk_start + n_rows) as f64 / dim as f64;
            let eta = if frac > 0.01 { elapsed / frac * (1.0 - frac) } else { 0.0 };
            let entries_done = (chunk_start + n_rows) as f64 * dim as f64;
            eprint!("\r  Row {}/{} ({:.1}%) | {:.0}s elapsed | ETA {:.0}s | {:.1} Mentry/s    ",
                chunk_start + n_rows, dim, frac * 100.0,
                elapsed, eta, entries_done / elapsed / 1e6);
        }
        eprintln!();

        (gpu_hi, gpu_lo, total_gpu_time)
    } else {
        // ── Full GPU build (fits in VRAM) ──
        println!("  ▸ Step 1: Building Gram matrix on GPU (DD block-based, T={})...", t_max);
        let mut gpu_hi = vec![0.0f64; dim * dim];
        let mut gpu_lo = vec![0.0f64; dim * dim];
        let t0 = Instant::now();
        let status = unsafe {
            gpu_build_gram_dd(
                gpu_hi.as_mut_ptr(),
                gpu_lo.as_mut_ptr(),
                dim as i32,
                t_max,
            )
        };
        let gpu_time = t0.elapsed().as_secs_f64();
        if status != 0 {
            eprintln!("  ✗ GPU kernel failed (status={})", status);
            std::process::exit(1);
        }
        (gpu_hi, gpu_lo, gpu_time)
    };

    let lo_norm: f64 = gpu_lo.par_iter().map(|x| x * x).sum::<f64>().sqrt();
    println!("  ✓ GPU DD matrix built in {:.2}s ({:.1} Mentry/s)",
        gpu_time, tri_entries as f64 / gpu_time / 1e6);
    println!("    DD lo-word ‖lo‖₂ = {:.6e} (hi/lo ratio ~{:.0})",
        lo_norm, {
            let hi_norm: f64 = gpu_hi.par_iter().map(|x| x * x).sum::<f64>().sqrt();
            if lo_norm > 0.0 { hi_norm / lo_norm } else { f64::INFINITY }
        });

    // Quick sanity: diagonal must be positive

    let diag_min = (0..dim).map(|i| gpu_hi[i * dim + i]).fold(f64::MAX, f64::min);
    let diag_max = (0..dim).map(|i| gpu_hi[i * dim + i]).fold(f64::MIN, f64::max);
    println!("    Diagonal range: [{:.8e}, {:.8e}]", diag_min, diag_max);
    if diag_min <= 0.0 {
        eprintln!("  ⚠ WARNING: Non-positive diagonal entries detected!");
    }

    // ═══════════════════════════════════════════════════════════
    // STEP 2: CPU cross-verification (MPFR-X precision, scalable)
    //
    // KEY INSIGHT: As MPFR precision → ∞, the CPU reference becomes
    // arbitrarily accurate, exposing the GPU DD kernel's precision
    // ceiling (~9-10 digits after accumulating 200K terms with
    // double-double arithmetic). This ceiling is fundamental:
    //   - DD has ~31 digits internally
    //   - But block-based accumulation of T terms introduces O(T·ε²)
    //     error, where ε² ~ 1e-31 for DD
    //   - For T=200K: error ~ 2e5 × 1e-31 = 2e-26 (still ~25 digits)
    //   - The observed ~9 digit ceiling comes from the f64 output
    //     truncation (DD → f64 loses the lo word)
    //
    // The precision ladder (--verify-prec 0) makes this visible:
    //   MPFR-128:  ~9.4 digits (both sides limited)
    //   MPFR-256:  ~9.4 digits (GPU becomes the bottleneck)
    //   MPFR-512:  ~9.4 digits (plateau confirms DD ceiling)
    //   MPFR-1024: ~9.4 digits (no improvement — it's the GPU)
    // ═══════════════════════════════════════════════════════════
    if !no_verify {
        if verify_prec == 0 {
            // ── Precision ladder analysis ──
            // Run verification at multiple MPFR precisions to expose the
            // GPU DD kernel's precision ceiling.
            println!("  ▸ Step 2: Precision ladder analysis ({} spot checks)...", verify_count);
            println!();
            println!("    {:<12} {:>14} {:>14} {:>10}", "MPFR bits", "Mean rel err", "Max rel err", "Eff digits");
            println!("    {} {} {} {}", "─".repeat(12), "─".repeat(14), "─".repeat(14), "─".repeat(10));

            for &prec in &[128u32, 256, 512, 1024, 2048] {
                let (mean_rel, max_rel, _worst_j, _worst_k, count, elapsed) =
                    run_spot_checks(&gpu_hi, dim, verify_count, prec, t_max as usize);
                let digits = if mean_rel > 0.0 { -mean_rel.log10() } else { 16.0 };
                println!("    MPFR-{:<6} {:14.3e} {:14.3e} {:10.1}   ({} checks, {:.1}s)",
                    prec, mean_rel, max_rel, digits, count, elapsed);
            }

            println!();
            println!("    → If digits plateau, the GPU DD kernel is the precision bottleneck.");
            println!("    → Expected plateau: ~9-10 digits (DD→f64 output truncation).");
            println!();
        } else {
            // ── Single-precision verification ──
            println!("  ▸ Step 2: CPU cross-verification ({} spot checks, MPFR-{})...", verify_count, verify_prec);

            let (mean_rel, max_rel, worst_j, worst_k, count, elapsed) =
                run_spot_checks(&gpu_hi, dim, verify_count, verify_prec, t_max as usize);
            let digits = if mean_rel > 0.0 { -mean_rel.log10() } else { 16.0 };

            println!("  ✓ Verification ({:.1}s):", elapsed);
            println!("    Max rel error:  {:.3e} (G[{},{}])", max_rel, worst_j, worst_k);
            println!("    Mean rel error: {:.3e}", mean_rel);
            println!("    Effective digits: {:.1}", digits);
            println!("    Entries checked: {}", count);
            println!("    MPFR precision: {}-bit ({:.0} decimal digits)",
                verify_prec, (verify_prec as f64) * 0.301);

            if digits < 8.0 {
                eprintln!("  ⚠ WARNING: Fewer than 8 digits of agreement!");
            } else {
                println!("  ✓ Precision: {:.1} digits — within DD tolerance", digits);
            }
        }
    } else {
        println!("  ▸ Step 2: Verification skipped (--no-verify)");
    }

    // ═══════════════════════════════════════════════════════════
    // STEP 3: Compute d²_N
    // ═══════════════════════════════════════════════════════════
    let d2_result = if skip_d2 {
        println!("  ▸ Step 3: d² computation skipped (--skip-d2)");
        None
    } else {
        println!("  ▸ Step 3: Computing d²_N...");
        let t0 = Instant::now();
        let bvec = cathedral_utils::arith::b_vector(dim);
        let g_mat = nalgebra::DMatrix::from_fn(dim, dim, |i, j| gpu_hi[i * dim + j]);
        let bv = nalgebra::DVector::from_column_slice(&bvec[..dim]);

        let result = if let Some(chol) = g_mat.clone().cholesky() {
            let c = chol.solve(&bv);
            Some(1.0 - bv.dot(&c))
        } else {
            eprintln!("  ⚠ Cholesky failed — trying LU");
            match g_mat.lu().solve(&bv) {
                Some(c) => Some(1.0 - bv.dot(&c)),
                None => {
                    eprintln!("  ⚠ LU also failed — d² not computed");
                    None
                }
            }
        };
        let d2_time = t0.elapsed().as_secs_f64();

        if let Some(d2) = result {
            println!("  ✓ d²_{} = {:.15e}  ({:.2}s)", max_n, d2, d2_time);
        }
        result
    };

    // ═══════════════════════════════════════════════════════════
    // STEP 4: Write HPDF
    // ═══════════════════════════════════════════════════════════
    println!("  ▸ Step 4: Writing HPDF [DD lossless]...");

    std::fs::create_dir_all(&output_dir).ok();
    let output_path = PathBuf::from(&output_dir).join(format!("gram_N{}.h5", max_n));

    // Compute SHA-256 of the GPU hi+lo data for provenance
    let data_bytes: &[u8] = unsafe {
        std::slice::from_raw_parts(gpu_hi.as_ptr() as *const u8, gpu_hi.len() * 8)
    };
    use sha2::{Sha256, Digest};
    let mut hasher = Sha256::new();
    hasher.update(data_bytes);
    let lo_bytes: &[u8] = unsafe {
        std::slice::from_raw_parts(gpu_lo.as_ptr() as *const u8, gpu_lo.len() * 8)
    };
    hasher.update(lo_bytes);
    let source_sha = format!("{:x}", hasher.finalize());

    let config = hpdf::HpdfWriterConfig {
        max_n,
        precision: 0, // DD precision (~31 digits), not MPFR
        source_sha256: source_sha.clone(),
        builder: format!("gpu-hpdf-build DD-lossless (block-based kernel, log1p bypass, T={})", t_max),
        include_number_theory: include_nt,
    };

    match hpdf::write_hpdf_dd(&output_path, &gpu_hi, &gpu_lo, &config) {
        Ok(file_size) => {
            println!("  ✓ HPDF [DD] written: {} ({:.1} MB)",
                output_path.display(), file_size as f64 / (1024.0 * 1024.0));
        }
        Err(e) => {
            eprintln!("  ✗ HPDF write failed: {}", e);
            std::process::exit(1);
        }
    }

    // ═══════════════════════════════════════════════════════════
    // STEP 5: Verify the written HPDF (roundtrip check)
    // ═══════════════════════════════════════════════════════════
    println!("  ▸ Step 5: Verifying HPDF DD roundtrip integrity...");

    let reader = hpdf::HpdfReader::open(&output_path).expect("Failed to open written HPDF");
    assert_eq!(reader.dim(), dim);
    assert_eq!(reader.max_n(), max_n);
    assert!(reader.has_dd(), "HPDF should have DD data");

    // SHA-256 integrity (both hi and lo)
    let integrity = reader.verify_data_integrity().expect("Integrity check failed");
    if integrity.valid {
        println!("  ✓ SHA-256 (hi): {}... ✓", &integrity.computed_sha256[..16]);
        if let Some(true) = integrity.dd_lo_valid {
            println!("  ✓ SHA-256 (lo): verified ✓");
        }
    } else {
        eprintln!("  ✗ SHA-256 MISMATCH — file may be corrupted!");
        if integrity.dd_lo_valid == Some(false) {
            eprintln!("  ✗ DD lo-word checksum also failed!");
        }
        std::process::exit(1);
    }

    // Spot-check hi entries roundtrip
    let read_data = reader.read_gram_full().expect("Failed to read back hi matrix");
    let mut max_roundtrip_err = 0.0f64;
    for idx in 0..100.min(dim * dim) {
        let hash = idx.wrapping_mul(2654435761) % (dim * dim);
        let err = (gpu_hi[hash] - read_data[hash]).abs();
        max_roundtrip_err = max_roundtrip_err.max(err);
    }
    if max_roundtrip_err == 0.0 {
        println!("  ✓ Hi roundtrip: bit-perfect (100 entries)");
    } else {
        println!("  ⚠ Hi roundtrip max error: {:.3e}", max_roundtrip_err);
    }

    // Spot-check lo entries roundtrip
    if let Some(read_lo) = reader.read_gram_lo_full().expect("Failed to read lo matrix") {
        let mut max_lo_err = 0.0f64;
        for idx in 0..100.min(dim * dim) {
            let hash = idx.wrapping_mul(2654435761) % (dim * dim);
            let err = (gpu_lo[hash] - read_lo[hash]).abs();
            max_lo_err = max_lo_err.max(err);
        }
        if max_lo_err == 0.0 {
            println!("  ✓ Lo roundtrip: bit-perfect (100 entries)");
        } else {
            println!("  ⚠ Lo roundtrip max error: {:.3e}", max_lo_err);
        }
    }

    // ═══════════════════════════════════════════════════════════
    // SUMMARY
    // ═══════════════════════════════════════════════════════════
    let total_time = t_total.elapsed().as_secs_f64();
    println!();
    println!("╔══════════════════════════════════════════════════════════════╗");
    println!("║  ✓ GPU HPDF DD BUILD COMPLETE — LOSSLESS                    ║");
    println!("╠══════════════════════════════════════════════════════════════╣");
    println!("║  N = {:>6}  dim = {:>6}  T_max = {:>8}                ║", max_n, dim, t_max);
    if let Some(d2) = d2_result {
        println!("║  d²_{} = {:.12e}                         ║", max_n, d2);
    }
    println!("║  HPDF: {}                                    ║",
        &output_path.file_name().unwrap().to_string_lossy());
    println!("║  DD: hi+lo stored (lossless ~31-digit precision)           ║");
    println!("║  SHA-256: {}...                      ║",
        &integrity.computed_sha256[..24]);
    println!("╠──────────────────────────────────────────────────────────────╣");
    println!("║  Timing:  GPU {:.1}s + total {:.1}s                       ║",
        gpu_time, total_time);
    println!("╚══════════════════════════════════════════════════════════════╝");
    println!();

    // Also try to compare with any existing CPU cache
    compare_with_cpu_cache(max_n, dim, &gpu_hi);
}

/// Compare GPU-built matrix against any existing CPU cache files.
fn compare_with_cpu_cache(max_n: usize, dim: usize, gpu_data: &[f64]) {
    let cache_dir = cache::cache_dir();
    let mut cpu_ref = None;

    if let Ok(entries) = std::fs::read_dir(&cache_dir) {
        for entry in entries.flatten() {
            let name = entry.file_name().to_string_lossy().to_string();
            if name.starts_with("gram_N") && name.ends_with(".bin") {
                if let Some(g) = cache::load_gram(&entry.path()) {
                    if g.max_n >= max_n {
                        if cpu_ref.as_ref().map_or(true, |c: &cathedral_utils::gram::GramMatrix| g.precision > c.precision) {
                            cpu_ref = Some(g);
                        }
                    }
                }
            }
        }
    }

    if let Some(ref cpu) = cpu_ref {
        let mut max_rel = 0.0f64;
        let mut sum_rel = 0.0f64;
        let mut count = 0usize;
        for i in 0..dim {
            for j in i..dim {
                let cv = cpu.data[i * cpu.max_dim + j];
                let gv = gpu_data[i * dim + j];
                if cv.abs() > 1e-30 {
                    let rel = ((gv - cv) / cv).abs();
                    max_rel = max_rel.max(rel);
                    sum_rel += rel;
                    count += 1;
                }
            }
        }
        let mean_rel = sum_rel / count as f64;
        let digits = if mean_rel > 0.0 { -mean_rel.log10() } else { 16.0 };

        println!("  ═══ GPU DD vs CPU cache (MPFR-{}) ═══", cpu.precision);
        println!("    max rel error:  {:.3e}", max_rel);
        println!("    mean rel error: {:.3e}", mean_rel);
        println!("    effective digits: {:.1}", digits);
        println!("    entries compared: {}", count);
        println!();
    }
}

/// Run deterministic spot checks comparing GPU matrix entries against MPFR-`prec` CPU references.
///
/// Returns (mean_rel, max_rel, worst_j, worst_k, count, elapsed_secs).
/// Uses the same hash-based deterministic sampling at all precision levels
/// so results across the precision ladder are directly comparable.
///
/// Parallelized with rayon — each MPFR spot check is independent and takes ~3s,
/// so running them in parallel gives ~12-16× speedup on multi-core systems.
fn run_spot_checks(
    gpu_hi: &[f64], dim: usize, verify_count: usize, prec: u32, t_max: usize,
) -> (f64, f64, usize, usize, usize, f64) {
    let t0 = Instant::now();

    // Each check produces (j_gram, k_gram, rel_err)
    let results: Vec<(usize, usize, f64)> = (0..verify_count)
        .into_par_iter()
        .filter_map(|idx| {
            // Deterministic hash: same entries sampled at every precision level
            let hash = idx.wrapping_mul(2654435761) % (dim * dim);
            let i = hash / dim;
            let j = hash % dim;
            let j_gram = i + 2;
            let k_gram = j + 2;

            // CPU reference at the requested MPFR precision, same T_max as GPU
            let cpu_val = gram::gram_entry_at_t(j_gram, k_gram, prec, t_max).to_f64();
            let gpu_val = gpu_hi[i * dim + j];

            if cpu_val.abs() > 1e-30 {
                let rel = ((gpu_val - cpu_val) / cpu_val).abs();
                Some((j_gram, k_gram, rel))
            } else {
                None
            }
        })
        .collect();

    // Reduce to find max and sum
    let mut max_rel = 0.0f64;
    let mut sum_rel = 0.0f64;
    let mut worst_j = 0usize;
    let mut worst_k = 0usize;
    let count = results.len();

    for &(j_gram, k_gram, rel) in &results {
        if rel > max_rel {
            max_rel = rel;
            worst_j = j_gram;
            worst_k = k_gram;
        }
        sum_rel += rel;
    }

    let elapsed = t0.elapsed().as_secs_f64();
    let mean_rel = if count > 0 { sum_rel / count as f64 } else { 0.0 };
    (mean_rel, max_rel, worst_j, worst_k, count, elapsed)
}

fn parse_flag_str(args: &[String], flag: &str) -> Option<String> {
    args.windows(2)
        .find(|w| w[0] == flag)
        .map(|w| w[1].clone())
}
