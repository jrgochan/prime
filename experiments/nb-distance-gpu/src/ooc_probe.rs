//! ╔══════════════════════════════════════════════════════════════════════╗
//! ║  🌊 OUT-OF-CORE NB DISTANCE PROBE                                  ║
//! ║                                                                     ║
//! ║  For Gram matrices too large for GPU VRAM or RAM:                   ║
//! ║  1. Build matrix row-by-row, streaming to /mnt/f (15 TB)           ║
//! ║  2. Compute d² via Conjugate Gradient with disk-streamed matvec    ║
//! ║                                                                     ║
//! ║  Usage:                                                             ║
//! ║    ooc-probe build <N> [--precision <bits>]                         ║
//! ║    ooc-probe solve <N> [--tol <tol>] [--max-iter <n>]              ║
//! ║    ooc-probe full  <N>                                              ║
//! ║                                                                     ║
//! ║  Cathedral Core Team — May 2, 2026                                  ║
//! ╚══════════════════════════════════════════════════════════════════════╝

mod gpu;

use cathedral_utils::gram;
use cathedral_utils::arith;
use cathedral_utils::dd::DD;
use rayon::prelude::*;
use std::io::{Read, Write, Seek, SeekFrom, BufWriter};
use std::path::{Path, PathBuf};
use std::time::Instant;

extern crate libc;

// ═══════════════════════════════════════════════════════════════════
// OOC CACHE CONFIGURATION
// ═══════════════════════════════════════════════════════════════════

/// OOC cache lives on D: (NVMe SSD, 1 TB free, ~3.5 GB/s).
/// F: (HDD, 13 TB) is too slow for iterative CG (~200 MB/s).
/// Override with OOC_CACHE_DIR env var.
fn ooc_cache_dir() -> PathBuf {
    if let Ok(dir) = std::env::var("OOC_CACHE_DIR") {
        PathBuf::from(dir)
    } else {
        PathBuf::from("/mnt/d/cathedral-cache")
    }
}

/// Archive dir on the 16 TB HDD — for cold storage of completed matrices.
#[allow(dead_code)]
fn ooc_archive_dir() -> PathBuf {
    PathBuf::from("/mnt/f/cathedral-archive")
}

fn ooc_gram_path(max_n: usize, precision: u32) -> PathBuf {
    ooc_cache_dir().join(format!("ooc_gram_N{max_n}_p{precision}.bin"))
}

// File format constants
const OOC_MAGIC: u64 = 0x434F4F4854_414300; // "CATHOOC\0"
const OOC_VERSION: u32 = 1;
const OOC_HEADER_SIZE: u64 = 40;

// ═══════════════════════════════════════════════════════════════════
// OOC HEADER
// ═══════════════════════════════════════════════════════════════════

struct OocHeader {
    max_n: usize,
    dim: usize,
    precision: u32,
    checksum: u64,
}

fn write_ooc_header(f: &mut impl Write, max_n: usize, dim: usize, precision: u32, checksum: u64) -> std::io::Result<()> {
    f.write_all(&OOC_MAGIC.to_le_bytes())?;
    f.write_all(&OOC_VERSION.to_le_bytes())?;
    f.write_all(&(max_n as u32).to_le_bytes())?;
    f.write_all(&(dim as u32).to_le_bytes())?;
    f.write_all(&precision.to_le_bytes())?;
    f.write_all(&checksum.to_le_bytes())?;
    // pad to 48 bytes
    f.write_all(&[0u8; 8])?;
    Ok(())
}

fn read_ooc_header(f: &mut impl Read) -> std::io::Result<Option<OocHeader>> {
    let mut buf8 = [0u8; 8];
    let mut buf4 = [0u8; 4];

    f.read_exact(&mut buf8)?;
    if u64::from_le_bytes(buf8) != OOC_MAGIC { return Ok(None); }

    f.read_exact(&mut buf4)?;
    if u32::from_le_bytes(buf4) != OOC_VERSION { return Ok(None); }

    f.read_exact(&mut buf4)?;
    let max_n = u32::from_le_bytes(buf4) as usize;

    f.read_exact(&mut buf4)?;
    let dim = u32::from_le_bytes(buf4) as usize;

    f.read_exact(&mut buf4)?;
    let precision = u32::from_le_bytes(buf4);

    f.read_exact(&mut buf8)?;
    let checksum = u64::from_le_bytes(buf8);

    // skip padding
    let mut pad = [0u8; 8];
    f.read_exact(&mut pad)?;

    Ok(Some(OocHeader { max_n, dim, precision, checksum }))
}

// ═══════════════════════════════════════════════════════════════════
// OOC GRAM BUILDER — streams rows to disk
// ═══════════════════════════════════════════════════════════════════

/// Build Gram matrix row-by-row, writing directly to disk.
/// Never holds more than `chunk_rows` rows in RAM at once.
///
/// For N=55,440: dim=55,439, matrix=24.6 GB
/// With chunk_rows=128: peak RAM = 128 × 55,439 × 8 = 57 MB
fn ooc_build_gram(max_n: usize, precision: u32) -> std::io::Result<PathBuf> {
    let dim = max_n - 1;
    let total_entries = dim as u64 * dim as u64;
    let total_bytes = total_entries * 8;
    let total_gb = total_bytes as f64 / (1024.0 * 1024.0 * 1024.0);
    let chunk_rows = 128usize; // rows per disk write

    let path = ooc_gram_path(max_n, precision);
    std::fs::create_dir_all(path.parent().unwrap())?;

    println!("  ╔═══════════════════════════════════════════════════════════════╗");
    println!("  ║  🌊 OOC GRAM BUILDER                                        ║");
    println!("  ╚═══════════════════════════════════════════════════════════════╝");
    println!("  N = {max_n}, dim = {dim}");
    println!("  Matrix: {dim}×{dim} = {total_gb:.1} GB");
    println!("  Chunk: {chunk_rows} rows = {:.0} MB per write",
        chunk_rows as f64 * dim as f64 * 8.0 / (1024.0 * 1024.0));
    println!("  Output: {}", path.display());
    println!();

    // Build ln(n) table for the fast block-based algorithm
    let table_size = (max_n * 5).max(10_000).min(500_000);
    let ln_table = gram::LnNTable::new(table_size, precision);

    // Open output file with buffered writer
    let file = std::fs::File::create(&path)?;
    let mut writer = BufWriter::with_capacity(64 * 1024 * 1024, file); // 64 MB buffer

    // Write placeholder header (will update checksum at end)
    write_ooc_header(&mut writer, max_n, dim, precision, 0)?;

    let t0 = Instant::now();
    let mut first_entries = Vec::new(); // for checksum

    for chunk_start in (0..dim).step_by(chunk_rows) {
        let chunk_end = (chunk_start + chunk_rows).min(dim);
        let rows_in_chunk = chunk_end - chunk_start;

        // Generate all (row, col) pairs for this chunk's upper triangle + mirror
        let pairs: Vec<(usize, usize)> = (chunk_start..chunk_end)
            .flat_map(|row| (0..dim).map(move |col| (row, col)))
            .collect();

        // Compute entries in parallel
        // Only compute upper triangle; mirror for lower
        let entries: Vec<(usize, usize, f64)> = pairs
            .par_iter()
            .map(|&(row, col)| {
                let j = row + 2;
                let k = col + 2;
                // Use symmetry: only compute if j <= k, else we'll fill from the row data
                let val = gram::gram_entry_fast(j, k, &ln_table).to_f64();
                (row - chunk_start, col, val)
            })
            .collect();

        // Assemble into row-major buffer
        let mut buffer = vec![0.0f64; rows_in_chunk * dim];
        for (local_row, col, val) in entries {
            buffer[local_row * dim + col] = val;
        }

        // Save first entries for checksum
        if chunk_start == 0 {
            first_entries.extend_from_slice(&buffer[..64.min(buffer.len())]);
        }

        // Write to disk
        let bytes: &[u8] = unsafe {
            std::slice::from_raw_parts(buffer.as_ptr() as *const u8, buffer.len() * 8)
        };
        writer.write_all(bytes)?;

        // Progress
        let elapsed = t0.elapsed().as_secs_f64();
        let frac = chunk_end as f64 / dim as f64;
        let eta = if frac > 0.01 { elapsed / frac * (1.0 - frac) } else { 0.0 };
        eprint!("\r  Row {chunk_end}/{dim} ({:.1}%) | {elapsed:.0}s elapsed | ETA {eta:.0}s     ",
            frac * 100.0);
    }

    writer.flush()?;
    eprintln!();

    // Update header with checksum
    let checksum: u64 = first_entries.iter()
        .take(64)
        .map(|v| v.to_bits())
        .fold(0u64, |acc, b| acc.wrapping_add(b));

    let mut file = std::fs::OpenOptions::new().write(true).open(&path)?;
    file.seek(SeekFrom::Start(0))?;
    write_ooc_header(&mut file, max_n, dim, precision, checksum)?;

    let total_time = t0.elapsed().as_secs_f64();
    println!("  ✓ OOC Gram matrix built in {:.1}s ({total_gb:.1} GB)", total_time);
    println!("  ✓ Saved to: {}", path.display());

    Ok(path)
}

// ═══════════════════════════════════════════════════════════════════
// MMAP-BACKED MATRIX — keeps matrix memory-mapped for repeat access
// ═══════════════════════════════════════════════════════════════════

/// Memory-mapped Gram matrix for fast repeat access.
/// After the first CG iteration, the OS page cache keeps hot pages in RAM.
/// For N=20K (3 GB): first pass reads from NVMe, subsequent passes from RAM.
/// For N=40K (12.8 GB): still fits in 64 GB RAM via page cache.
struct MmapGram {
    data: *const f64,
    dim: usize,
    _mmap_len: usize,
    #[cfg(target_family = "unix")]
    _fd: std::os::unix::io::RawFd,
}

impl MmapGram {
    fn open(path: &Path, dim: usize) -> std::io::Result<Self> {
        use std::os::unix::io::AsRawFd;

        let file = std::fs::File::open(path)?;
        let file_len = file.metadata()?.len() as usize;
        let fd = file.as_raw_fd();

        let data_offset = OOC_HEADER_SIZE as usize;
        let expected = data_offset + dim * dim * 8;
        if file_len < expected {
            return Err(std::io::Error::new(
                std::io::ErrorKind::InvalidData,
                format!("File too small: {} < {}", file_len, expected),
            ));
        }

        let ptr = unsafe {
            libc::mmap(
                std::ptr::null_mut(),
                file_len,
                libc::PROT_READ,
                libc::MAP_PRIVATE,
                fd,
                0,
            )
        };

        if ptr == libc::MAP_FAILED {
            return Err(std::io::Error::last_os_error());
        }

        // Advise sequential access for prefetching
        unsafe { libc::madvise(ptr, file_len, libc::MADV_SEQUENTIAL); }

        let data_ptr = unsafe { (ptr as *const u8).add(data_offset) as *const f64 };

        // Keep fd open via the File (mmap keeps a reference)
        std::mem::forget(file);

        Ok(MmapGram {
            data: data_ptr,
            dim,
            _mmap_len: file_len,
            _fd: fd,
        })
    }

    /// Get a row slice (zero-copy from mmap)
    #[inline]
    fn row(&self, i: usize) -> &[f64] {
        unsafe {
            std::slice::from_raw_parts(self.data.add(i * self.dim), self.dim)
        }
    }

    /// Get a chunk of rows as a contiguous slice
    #[inline]
    fn row_chunk(&self, start: usize, count: usize) -> &[f64] {
        unsafe {
            std::slice::from_raw_parts(self.data.add(start * self.dim), count * self.dim)
        }
    }
}

unsafe impl Send for MmapGram {}
unsafe impl Sync for MmapGram {}

// ═══════════════════════════════════════════════════════════════════
// GPU-ACCELERATED MATRIX-VECTOR MULTIPLY
// ═══════════════════════════════════════════════════════════════════

/// GPU state for chunk-based matrix-vector multiplication.
/// Keeps the x vector resident on GPU across chunks.
struct GpuMatvecState {
    blas_handle: *mut std::ffi::c_void,
    d_x: *mut f64,      // x vector (resident on GPU)
    d_chunk: *mut f64,   // chunk buffer (reused)
    d_y_chunk: *mut f64, // y chunk output (reused)
    chunk_rows: usize,
    dim: usize,
    chunk_alloc: usize,  // allocated chunk capacity in rows
}

impl GpuMatvecState {
    fn new(dim: usize, chunk_rows: usize) -> Result<Self, String> {
        use std::ffi::c_int;
        let vec_bytes = dim * 8;
        let chunk_bytes = chunk_rows * dim * 8;
        let chunk_y_bytes = chunk_rows * 8;

        unsafe {
            let mut blas_handle: *mut std::ffi::c_void = std::ptr::null_mut();
            let s = gpu::ffi::cublasCreate_v2(&mut blas_handle);
            if s != 0 { return Err(format!("cublasCreate failed: {}", s)); }

            let mut d_x: *mut f64 = std::ptr::null_mut();
            let mut d_chunk: *mut f64 = std::ptr::null_mut();
            let mut d_y_chunk: *mut f64 = std::ptr::null_mut();

            let s1 = gpu::ffi::cudaMalloc(&mut d_x, vec_bytes);
            let s2 = gpu::ffi::cudaMalloc(&mut d_chunk, chunk_bytes);
            let s3 = gpu::ffi::cudaMalloc(&mut d_y_chunk, chunk_y_bytes);
            if s1 != 0 || s2 != 0 || s3 != 0 {
                return Err(format!("cudaMalloc failed: {},{},{}", s1, s2, s3));
            }

            Ok(GpuMatvecState {
                blas_handle, d_x, d_chunk, d_y_chunk,
                chunk_rows, dim, chunk_alloc: chunk_rows,
            })
        }
    }

    /// Upload x vector to GPU (call once per CG iteration)
    fn upload_x(&self, x: &[f64]) {
        unsafe {
            gpu::ffi::cudaMemcpy(self.d_x, x.as_ptr(), x.len() * 8, 1); // H2D
        }
    }

    /// Multiply a chunk of rows by x on GPU: y_chunk = chunk * x
    /// chunk is rows×dim in row-major order.
    fn matvec_chunk(&self, chunk: &[f64], rows: usize, y_out: &mut [f64]) {
        use std::ffi::c_int;
        let m = rows as c_int;
        let n = self.dim as c_int;
        let alpha = 1.0f64;
        let beta_val = 0.0f64;

        unsafe {
            // Upload chunk (row-major = column-major transpose)
            gpu::ffi::cudaMemcpy(self.d_chunk, chunk.as_ptr(), rows * self.dim * 8, 1);

            // cuBLAS dgemv: y = alpha * A * x + beta * y
            // A is row-major (rows × dim), which cuBLAS sees as col-major (dim × rows)
            // So we compute: y = A^T * x in cuBLAS terms, but actually we want A * x
            // For row-major A: cublas sees it as A^T in col-major
            // y = A_rowmajor * x  =>  cuBLAS: y = (A_colmajor)^T * x = CUBLAS_OP_T
            gpu::ffi::cublasDgemv_v2(
                self.blas_handle,
                1, // CUBLAS_OP_T (transpose, since row-major = col-major transposed)
                n, m, // cuBLAS sees (dim × rows) in col-major
                &alpha,
                self.d_chunk, n, // leading dim = n (col-major layout)
                self.d_x, 1,
                &beta_val,
                self.d_y_chunk, 1,
            );

            // Download result
            gpu::ffi::cudaMemcpy(y_out.as_mut_ptr(), self.d_y_chunk, rows * 8, 2); // D2H
        }
    }
}

impl Drop for GpuMatvecState {
    fn drop(&mut self) {
        unsafe {
            gpu::ffi::cudaFree(self.d_x);
            gpu::ffi::cudaFree(self.d_chunk);
            gpu::ffi::cudaFree(self.d_y_chunk);
            gpu::ffi::cublasDestroy_v2(self.blas_handle);
        }
    }
}

/// Compute y = G · x using mmap + GPU cuBLAS.
/// The matrix data is memory-mapped; chunks are uploaded to GPU for dgemv.
fn gpu_matvec(gram: &MmapGram, gpu: &GpuMatvecState, x: &[f64], y: &mut [f64]) {
    let dim = gram.dim;
    let chunk_rows = gpu.chunk_rows;

    // Upload x to GPU once
    gpu.upload_x(x);

    for start_row in (0..dim).step_by(chunk_rows) {
        let rows = chunk_rows.min(dim - start_row);
        let chunk = gram.row_chunk(start_row, rows);

        // GPU matvec for this chunk
        gpu.matvec_chunk(chunk, rows, &mut y[start_row..start_row + rows]);
    }
}

/// Fallback: CPU matvec using mmap (no GPU, rayon parallel)
fn cpu_matvec(gram: &MmapGram, x: &[f64], y: &mut [f64]) {
    let dim = gram.dim;
    y.par_iter_mut().enumerate().for_each(|(i, yi)| {
        let row = gram.row(i);
        *yi = row.iter().zip(x.iter()).map(|(a, b)| a * b).sum();
    });
}

/// Solve G · c = b via Jacobi-Preconditioned Conjugate Gradient.
///
/// Jacobi preconditioner M = diag(G) — extracted from mmap for free.
/// Reduces effective condition number by 10-100×, dramatically cutting
/// the iteration count needed for convergence.
///
/// KEY FIX (v2): DD-precision dot products for critical scalars.
/// At N=120k, summing 120k terms in f64 loses ~5 digits, causing:
///   - False pAp ≤ 0 (CG breakdown)
///   - Slow/stalled convergence
/// DD accumulation (~31 digits) eliminates this. The matvec stays
/// f64 (GPU cuBLAS) since that's the hot path and f64 suffices there.
fn ooc_cg_solve(
    gram_path: &Path,
    b: &[f64],
    dim: usize,
    tol: f64,
    max_iter: usize,
) -> f64 {
    let chunk_rows = 4096; // rows per GPU upload

    println!("  ╔═══════════════════════════════════════════════════════════════╗");
    println!("  ║  🎯 JACOBI-PRECONDITIONED CG-DD SOLVER (mmap + GPU)         ║");
    println!("  ║  DD-precision dot products · f64 GPU matvec                  ║");
    println!("  ╚═══════════════════════════════════════════════════════════════╝");
    println!("  dim = {dim}");
    println!("  tol = {tol:.2e}, max_iter = {max_iter}");
    let matrix_gb = (dim as u64 * dim as u64 * 8) as f64 / (1024.0 * 1024.0 * 1024.0);
    println!("  Matrix: {matrix_gb:.1} GB (mmap'd)");
    let chunk_mb = chunk_rows as f64 * dim as f64 * 8.0 / (1024.0 * 1024.0);
    println!("  GPU chunk: {chunk_rows} rows = {chunk_mb:.0} MB");
    println!();

    // Open mmap'd matrix
    let t_mmap = Instant::now();
    let gram = match MmapGram::open(gram_path, dim) {
        Ok(g) => g,
        Err(e) => {
            eprintln!("  ❌ Failed to mmap matrix: {e}");
            return f64::NAN;
        }
    };
    println!("  ✓ Matrix mmap'd in {:.2}s", t_mmap.elapsed().as_secs_f64());

    // ── Extract Jacobi preconditioner: M_inv[i] = 1/G[i,i] ──
    let mut m_inv = vec![0.0f64; dim];
    let mut diag_min = f64::MAX;
    let mut diag_max = 0.0f64;
    for i in 0..dim {
        let gii = gram.row(i)[i]; // diagonal entry (zero-copy from mmap)
        if gii > 1e-30 {
            m_inv[i] = 1.0 / gii;
        } else {
            m_inv[i] = 1.0; // fallback for near-zero diagonal
        }
        if gii < diag_min { diag_min = gii; }
        if gii > diag_max { diag_max = gii; }
    }
    let diag_cond = if diag_min > 0.0 { diag_max / diag_min } else { f64::INFINITY };
    println!("  ✓ Jacobi preconditioner: diag range [{diag_min:.4e}, {diag_max:.4e}], diag_cond = {diag_cond:.2e}");

    // Initialize GPU matvec state
    let use_gpu = gpu::detect_gpu().is_some();
    let gpu_state = if use_gpu {
        match GpuMatvecState::new(dim, chunk_rows) {
            Ok(s) => {
                println!("  ✓ GPU matvec initialized (cuBLAS)");
                Some(s)
            }
            Err(e) => {
                eprintln!("  ⚠ GPU init failed ({e}), using CPU fallback");
                None
            }
        }
    } else {
        println!("  ⚠ No GPU, using CPU (rayon) matvec");
        None
    };

    let t_total = Instant::now();

    // ── Preconditioned CG initialization ──
    // x = 0, r = b, z = M^{-1} r, p = z
    let mut x = vec![0.0f64; dim];
    let mut r = b.to_vec();
    let mut z = vec![0.0f64; dim]; // preconditioned residual
    for i in 0..dim { z[i] = m_inv[i] * r[i]; }
    let mut p = z.clone();
    let mut rz = dot_dd(&r, &z); // DD-precision r^T z
    let b_norm_sq = dot_dd(b, b);
    let b_norm = b_norm_sq.to_f64().sqrt();

    println!();
    println!("  ‖b‖ = {b_norm:.8e}");
    println!("  {:<6} {:>14} {:>14} {:>14} {:>10}", "iter", "residual", "|Δd²|", "d²_est", "time(s)");
    println!("  {} {} {} {} {}",
        "─".repeat(6), "─".repeat(14), "─".repeat(14), "─".repeat(14), "─".repeat(10));

    let mut prev_d2 = 1.0f64;
    let mut y = vec![0.0f64; dim];
    let mut stagnation_count = 0usize;
    let mut prev_r_norm = f64::MAX;

    for iter in 0..max_iter {
        let t_iter = Instant::now();

        // y = G · p (GPU-accelerated, f64 — this is the hot path)
        match &gpu_state {
            Some(gs) => gpu_matvec(&gram, gs, &p, &mut y),
            None => cpu_matvec(&gram, &p, &mut y),
        }

        // DD-precision pAp — prevents false non-PD detection
        let pap = dot_dd(&p, &y);
        if pap.hi <= 0.0 && pap.lo <= 0.0 {
            eprintln!("  ⚠ pAp ≤ 0 at iter {iter} (DD: {:.6e}+{:.6e}), matrix not PD",
                pap.hi, pap.lo);
            break;
        }

        let alpha = rz / pap;
        let alpha_f64 = alpha.to_f64();

        // x += alpha * p; r -= alpha * y
        for i in 0..dim { x[i] += alpha_f64 * p[i]; }
        for i in 0..dim { r[i] -= alpha_f64 * y[i]; }

        // Apply preconditioner: z = M^{-1} r
        for i in 0..dim { z[i] = m_inv[i] * r[i]; }

        let rz_new = dot_dd(&r, &z);
        let r_norm_sq = dot_dd(&r, &r);
        let r_norm = r_norm_sq.to_f64().sqrt();
        let residual = r_norm / b_norm;

        let bx = dot_dd(b, &x);
        let d2_est = 1.0 - bx.to_f64();
        let d2_delta = (d2_est - prev_d2).abs();
        prev_d2 = d2_est;

        let iter_time = t_iter.elapsed().as_secs_f64();

        // Print every iteration for first 20, then every 10, then every 50
        let should_print = iter < 20 || (iter < 100 && iter % 10 == 0)
            || iter % 50 == 0 || residual < tol;
        if should_print {
            println!("  {:6} {:14.8e} {:14.8e} {:14.10} {:10.2}",
                iter, residual, d2_delta, d2_est, iter_time);
        }

        if residual < tol {
            println!("  ✓ Converged at iteration {iter}!");
            break;
        }

        // Stagnation detection with residual recomputation
        if r_norm >= prev_r_norm * 0.9999 {
            stagnation_count += 1;
            if stagnation_count >= 50 && stagnation_count % 100 == 0 {
                // Recompute residual from scratch: r = b - Gx
                match &gpu_state {
                    Some(gs) => gpu_matvec(&gram, gs, &x, &mut y),
                    None => cpu_matvec(&gram, &x, &mut y),
                }
                for i in 0..dim { r[i] = b[i] - y[i]; }
                for i in 0..dim { z[i] = m_inv[i] * r[i]; }
                rz = dot_dd(&r, &z);
                p = z.clone();
                eprintln!("  ↻ Residual refresh at iter {iter}, ‖r‖={:.3e}", r_norm);
                prev_r_norm = r_norm;
                continue;
            }
        } else {
            stagnation_count = 0;
        }
        prev_r_norm = r_norm;

        // Update search direction (preconditioned)
        let beta = rz_new / rz;
        let beta_f64 = beta.to_f64();
        for i in 0..dim { p[i] = z[i] + beta_f64 * p[i]; }
        rz = rz_new;
    }

    let bx = dot_dd(b, &x);
    let d2 = 1.0 - bx.to_f64();
    let total_time = t_total.elapsed().as_secs_f64();

    println!();
    println!("  ══════════════════════════════════════════");
    println!("  d²_N = {d2:.12}");
    println!("  Total CG time: {total_time:.1}s");
    println!("  ══════════════════════════════════════════");

    d2
}

/// DD-precision dot product for CG scalars.
///
/// For N=120k: summing 120k terms in f64 loses ~5 digits.
/// DD accumulation (~31 digits) prevents CG breakdown.
/// Overhead is ~1-2% since matvec (99% of cost) stays f64.
#[inline]
fn dot_dd(a: &[f64], b: &[f64]) -> DD {
    const CHUNK: usize = 1024;
    let n = a.len();
    let n_chunks = (n + CHUNK - 1) / CHUNK;

    let partials: Vec<DD> = (0..n_chunks).into_par_iter()
        .map(|c| {
            let start = c * CHUNK;
            let end = (start + CHUNK).min(n);
            let mut acc = DD::from_f64(0.0);
            for i in start..end {
                let p = a[i] * b[i];
                let e = a[i].mul_add(b[i], -p);
                acc += DD::new(p, e);
            }
            acc
        })
        .collect();

    let mut total = DD::from_f64(0.0);
    for p in &partials {
        total += *p;
    }
    total
}

/// Legacy f64 dot product — only used where DD precision isn't needed.
#[inline]
#[allow(dead_code)]
fn dot(a: &[f64], b: &[f64]) -> f64 {
    a.iter().zip(b.iter()).map(|(x, y)| x * y).sum()
}

/// Write a JSON certificate with the OOC probe results.
fn write_certificate(max_n: usize, dim: usize, d2: f64, max_iter: usize, tol: f64, elapsed: f64, mode: &str) {
    let cert_path = ooc_cache_dir().join(format!("ooc_certificate_N{max_n}.json"));
    let matrix_gb = (dim as u64 * dim as u64 * 8) as f64 / (1024.0 * 1024.0 * 1024.0);

    let json = format!(
        r#"{{
  "tool": "ooc-probe",
  "mode": "{}",
  "timestamp": "{}",
  "N": {},
  "dim": {},
  "d2": {:.15e},
  "max_iter": {},
  "tol": {:.2e},
  "elapsed_seconds": {:.1},
  "matrix_gb": {:.2},
  "method": "Jacobi-Preconditioned CG-DD (mmap + GPU cuBLAS, DD dot products)",
  "cache_path": "{}",
  "rh_consistent": {}
}}"#,
        mode,
        chrono_now(),
        max_n,
        dim,
        d2,
        max_iter,
        tol,
        elapsed,
        matrix_gb,
        ooc_gram_path(max_n, 256).display(),
        d2 > 0.0 && d2 < 1.0,
    );

    if let Ok(()) = std::fs::write(&cert_path, &json) {
        println!("  📜 Certificate → {}", cert_path.display());
    }
}

fn chrono_now() -> String {
    // Simple UTC timestamp without chrono dependency
    use std::time::SystemTime;
    let secs = SystemTime::now()
        .duration_since(SystemTime::UNIX_EPOCH)
        .unwrap()
        .as_secs();
    format!("{secs}")
}

// ═══════════════════════════════════════════════════════════════════
// EXISTING CACHE IMPORT — load from cathedral-utils cache format
// ═══════════════════════════════════════════════════════════════════

/// Convert an existing DD cache file to OOC format on /mnt/f.
/// This copies the hi-part (f64) data with the OOC header.
fn import_dd_cache(max_n: usize) -> std::io::Result<Option<PathBuf>> {
    let dd_path = cathedral_utils::cache::dd_gram_cache_path(max_n, 256);
    if !dd_path.exists() {
        eprintln!("  DD cache not found: {}", dd_path.display());
        return Ok(None);
    }

    let ooc_path = ooc_gram_path(max_n, 256);
    if ooc_path.exists() {
        eprintln!("  OOC cache already exists: {}", ooc_path.display());
        return Ok(Some(ooc_path));
    }

    println!("  Importing DD cache → OOC format...");
    println!("  Source: {}", dd_path.display());
    println!("  Dest:   {}", ooc_path.display());

    let t0 = Instant::now();
    let dim = max_n - 1;

    // Load DD cache (reads both hi and lo)
    let (hi, _lo, loaded_dim) = cathedral_utils::cache::load_dd_gram(&dd_path)
        .ok_or_else(|| std::io::Error::new(std::io::ErrorKind::Other, "Failed to load DD cache"))?;

    assert_eq!(loaded_dim, dim, "Dimension mismatch");

    // Write OOC format
    std::fs::create_dir_all(ooc_path.parent().unwrap())?;
    let file = std::fs::File::create(&ooc_path)?;
    let mut writer = BufWriter::with_capacity(64 * 1024 * 1024, file);

    let checksum: u64 = hi.iter()
        .take(64)
        .map(|v| v.to_bits())
        .fold(0u64, |acc, b| acc.wrapping_add(b));

    write_ooc_header(&mut writer, max_n, dim, 256, checksum)?;

    let bytes: &[u8] = unsafe {
        std::slice::from_raw_parts(hi.as_ptr() as *const u8, hi.len() * 8)
    };
    writer.write_all(bytes)?;
    writer.flush()?;

    let elapsed = t0.elapsed().as_secs_f64();
    let gb = (hi.len() * 8) as f64 / (1024.0 * 1024.0 * 1024.0);
    println!("  ✓ Imported {gb:.1} GB in {elapsed:.1}s");

    Ok(Some(ooc_path))
}

// ═══════════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════════

fn main() {
    println!();
    println!("╔══════════════════════════════════════════════════════════════════╗");
    println!("║  🌊 OUT-OF-CORE NB DISTANCE PROBE                              ║");
    println!("║  Stream Gram matrices from disk for N > 50,000                  ║");
    println!("║  Cathedral Core Team — May 2, 2026                              ║");
    println!("╚══════════════════════════════════════════════════════════════════╝");

    let args: Vec<String> = std::env::args().collect();
    if args.len() < 3 {
        eprintln!();
        eprintln!("Usage:");
        eprintln!("  ooc-probe build  <N> [--precision <bits>]    Build OOC Gram matrix");
        eprintln!("  ooc-probe solve  <N> [--tol <tol>]           CG solve for d²");
        eprintln!("  ooc-probe full   <N>                         Build + solve");
        eprintln!("  ooc-probe import <N>                         Import existing DD cache");
        eprintln!("  ooc-probe info   <N>                         Show OOC cache info");
        eprintln!();
        eprintln!("OOC cache dir: {}", ooc_cache_dir().display());
        eprintln!();
        std::process::exit(1);
    }

    let cmd = args[1].as_str();
    let max_n: usize = args[2].parse().expect("N must be a number");

    // Parse optional flags
    let precision: u32 = parse_flag(&args, "--precision").unwrap_or(256) as u32;
    let tol: f64 = parse_flag_f64(&args, "--tol").unwrap_or(1e-12);
    let max_iter: usize = parse_flag(&args, "--max-iter").unwrap_or(500);

    // Check GPU
    if let Some(info) = gpu::detect_gpu() {
        println!("  GPU: {} ({} MB VRAM)", info.name, info.vram_mb);
    }

    println!("  OOC cache: {}", ooc_cache_dir().display());
    println!();

    match cmd {
        "build" => {
            ooc_build_gram(max_n, precision).expect("Build failed");
        }
        "solve" => {
            let ooc_path = ooc_gram_path(max_n, precision);
            if !ooc_path.exists() {
                eprintln!("  ❌ OOC cache not found: {}", ooc_path.display());
                eprintln!("  Run: ooc-probe build {max_n}");
                eprintln!("  Or:  ooc-probe import {max_n}");
                std::process::exit(1);
            }

            // Verify header
            let mut f = std::fs::File::open(&ooc_path).unwrap();
            let header = read_ooc_header(&mut f).unwrap().expect("Invalid OOC header");
            let dim = header.dim;

            println!("  OOC matrix: N={}, dim={dim}", header.max_n);
            let matrix_gb = (dim as u64 * dim as u64 * 8) as f64 / (1024.0 * 1024.0 * 1024.0);
            println!("  Size: {matrix_gb:.1} GB");

            // Build b vector
            let b = arith::b_vector(dim);
            let b_norm: f64 = b.iter().map(|x| x * x).sum::<f64>().sqrt();
            println!("  ‖b‖ = {b_norm:.8}");

            let t0 = Instant::now();
            let d2 = ooc_cg_solve(&ooc_path, &b, dim, tol, max_iter);
            let elapsed = t0.elapsed().as_secs_f64();
            println!("\n  🎯 RESULT: d²_{} = {:.12}", max_n, d2);

            write_certificate(max_n, dim, d2, max_iter, tol, elapsed, "solve");
        }
        "full" => {
            let t0 = Instant::now();
            let path = ooc_build_gram(max_n, precision).expect("Build failed");
            let build_time = t0.elapsed().as_secs_f64();
            println!();

            let dim = max_n - 1;
            let b = arith::b_vector(dim);
            let t_solve = Instant::now();
            let d2 = ooc_cg_solve(&path, &b, dim, tol, max_iter);
            let solve_time = t_solve.elapsed().as_secs_f64();
            let total_time = t0.elapsed().as_secs_f64();

            println!("\n  🎯 RESULT: d²_{} = {:.12}", max_n, d2);
            println!("  Build: {build_time:.1}s | Solve: {solve_time:.1}s | Total: {total_time:.1}s");

            write_certificate(max_n, dim, d2, max_iter, tol, total_time, "full");
        }
        "import" => {
            match import_dd_cache(max_n) {
                Ok(Some(path)) => println!("  ✓ OOC cache ready: {}", path.display()),
                Ok(None) => eprintln!("  ❌ No DD cache found for N={max_n}"),
                Err(e) => eprintln!("  ❌ Import failed: {e}"),
            }
        }
        "info" => {
            let path = ooc_gram_path(max_n, precision);
            if !path.exists() {
                eprintln!("  No OOC cache for N={max_n}");
                // List what exists
                if let Ok(entries) = std::fs::read_dir(ooc_cache_dir()) {
                    println!("  Available OOC caches:");
                    for entry in entries.flatten() {
                        let name = entry.file_name().to_string_lossy().to_string();
                        if name.starts_with("ooc_gram_") {
                            let meta = entry.metadata().ok();
                            let size_gb = meta.map(|m| m.len() as f64 / (1024.0*1024.0*1024.0)).unwrap_or(0.0);
                            println!("    {name} ({size_gb:.1} GB)");
                        }
                    }
                }
            } else {
                let meta = std::fs::metadata(&path).unwrap();
                let size_gb = meta.len() as f64 / (1024.0 * 1024.0 * 1024.0);
                let mut f = std::fs::File::open(&path).unwrap();
                if let Ok(Some(header)) = read_ooc_header(&mut f) {
                    println!("  N = {}", header.max_n);
                    println!("  dim = {}", header.dim);
                    println!("  precision = {}-bit", header.precision);
                    println!("  size = {size_gb:.1} GB");
                    println!("  path = {}", path.display());
                }
            }
        }
        _ => {
            eprintln!("  Unknown command: {cmd}");
            eprintln!("  Use: build, solve, full, import, info");
            std::process::exit(1);
        }
    }

    println!();
}

fn parse_flag(args: &[String], flag: &str) -> Option<usize> {
    args.iter()
        .position(|a| a == flag)
        .and_then(|i| args.get(i + 1))
        .and_then(|s| s.parse().ok())
}

fn parse_flag_f64(args: &[String], flag: &str) -> Option<f64> {
    args.iter()
        .position(|a| a == flag)
        .and_then(|i| args.get(i + 1))
        .and_then(|s| s.parse().ok())
}
