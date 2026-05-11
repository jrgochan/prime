//! ╔══════════════════════════════════════════════════════════════════════╗
//! ║  🌊 OUT-OF-CORE NB DISTANCE PROBE                                  ║
//! ║                                                                     ║
//! ║  For Gram matrices too large for GPU VRAM or RAM:                   ║
//! ║  1. Build matrix row-by-row, streaming to /mnt/f (15 TB)           ║
//! ║  2. Compute d² via Conjugate Gradient with disk-streamed matvec    ║
//! ║                                                                     ║
//! ║  Usage:                                                             ║
//! ║    ooc-probe build <N> [--precision <bits>] [--t-max <T>]          ║
//! ║    ooc-probe solve <N> [--tol <tol>] [--max-iter <n>]              ║
//! ║    ooc-probe full  <N> [--t-max <T>]                               ║
//! ║                                                                     ║
//! ║  Cathedral Core Team — May 2, 2026                                  ║
//! ╚══════════════════════════════════════════════════════════════════════╝

mod gpu;

use cathedral_utils::arith;
use cathedral_utils::dd::DD;
use cathedral_utils::gram;
use rayon::prelude::*;
use std::io::{BufWriter, Read, Seek, SeekFrom, Write};
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

fn write_ooc_header(
    f: &mut impl Write,
    max_n: usize,
    dim: usize,
    precision: u32,
    checksum: u64,
) -> std::io::Result<()> {
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
    if u64::from_le_bytes(buf8) != OOC_MAGIC {
        return Ok(None);
    }

    f.read_exact(&mut buf4)?;
    if u32::from_le_bytes(buf4) != OOC_VERSION {
        return Ok(None);
    }

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

    Ok(Some(OocHeader {
        max_n,
        dim,
        precision,
        checksum,
    }))
}

// ═══════════════════════════════════════════════════════════════════
// OOC GRAM BUILDER — streams rows to disk
// ═══════════════════════════════════════════════════════════════════

/// Build Gram matrix row-by-row, writing directly to disk.
/// Never holds more than `chunk_rows` rows in RAM at once.
///
/// For N=55,440: dim=55,439, matrix=24.6 GB
/// With chunk_rows=128: peak RAM = 128 × 55,439 × 8 = 57 MB
///
/// # Uniform truncation
/// Uses `gram_entry_fast_at_t` with a fixed `t_max` for ALL entries.
/// This guarantees the resulting matrix is a true Gram matrix of a single
/// inner product space, preserving positive-definiteness.
fn ooc_build_gram(max_n: usize, precision: u32, t_max: usize) -> std::io::Result<PathBuf> {
    let dim = max_n - 1;
    let total_entries = dim as u64 * dim as u64;
    let total_bytes = total_entries * 8;
    let total_gb = total_bytes as f64 / (1024.0 * 1024.0 * 1024.0);
    let chunk_rows = 128usize; // rows per disk write

    let path = ooc_gram_path(max_n, precision);
    std::fs::create_dir_all(path.parent().unwrap())?;

    println!("  ╔═══════════════════════════════════════════════════════════════╗");
    println!("  ║  🌊 OOC GRAM BUILDER (uniform T={t_max})                     ║");
    println!("  ╚═══════════════════════════════════════════════════════════════╝");
    println!("  N = {max_n}, dim = {dim}");
    println!("  Matrix: {dim}×{dim} = {total_gb:.1} GB");
    println!("  Truncation: T_max = {t_max} (uniform — guarantees PD)");
    println!(
        "  Chunk: {chunk_rows} rows = {:.0} MB per write",
        chunk_rows as f64 * dim as f64 * 8.0 / (1024.0 * 1024.0)
    );
    println!("  Output: {}", path.display());
    println!();

    // Build ln(n) table — must cover at least t_max+1
    let table_size = t_max.max(max_n * 5).max(10_000).min(500_000);
    let ln_table = gram::LnNTable::new(table_size + 1, precision);

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

        // Zero-allocation row-parallel build: each row computes its dim entries
        // in-place (cache-friendly sequential access), parallelized across rows.
        // Eliminates ~280 MB/chunk of temporary pairs + entries vectors.
        let mut buffer = vec![0.0f64; rows_in_chunk * dim];
        buffer
            .par_chunks_mut(dim)
            .enumerate()
            .for_each(|(local_row, row_buf)| {
                let j = chunk_start + local_row + 2;
                for col in 0..dim {
                    let k = col + 2;
                    row_buf[col] = gram::gram_entry_fast_at_t(j, k, &ln_table, t_max).to_f64();
                }
            });

        // Save first entries for checksum
        if chunk_start == 0 {
            first_entries.extend_from_slice(&buffer[..64.min(buffer.len())]);
        }

        // Write to disk
        let bytes: &[u8] =
            unsafe { std::slice::from_raw_parts(buffer.as_ptr() as *const u8, buffer.len() * 8) };
        writer.write_all(bytes)?;

        // Progress
        let elapsed = t0.elapsed().as_secs_f64();
        let frac = chunk_end as f64 / dim as f64;
        let eta = if frac > 0.01 {
            elapsed / frac * (1.0 - frac)
        } else {
            0.0
        };
        eprint!(
            "\r  Row {chunk_end}/{dim} ({:.1}%) | {elapsed:.0}s elapsed | ETA {eta:.0}s     ",
            frac * 100.0
        );
    }

    writer.flush()?;
    eprintln!();

    // Update header with checksum
    let checksum: u64 = first_entries
        .iter()
        .take(64)
        .map(|v| v.to_bits())
        .fold(0u64, |acc, b| acc.wrapping_add(b));

    let mut file = std::fs::OpenOptions::new().write(true).open(&path)?;
    file.seek(SeekFrom::Start(0))?;
    write_ooc_header(&mut file, max_n, dim, precision, checksum)?;

    let total_time = t0.elapsed().as_secs_f64();
    println!(
        "  ✓ OOC Gram matrix built in {:.1}s ({total_gb:.1} GB)",
        total_time
    );
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
        unsafe {
            libc::madvise(ptr, file_len, libc::MADV_SEQUENTIAL);
        }

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
        unsafe { std::slice::from_raw_parts(self.data.add(i * self.dim), self.dim) }
    }

    /// Get a chunk of rows as a contiguous slice
    #[inline]
    fn row_chunk(&self, start: usize, count: usize) -> &[f64] {
        unsafe { std::slice::from_raw_parts(self.data.add(start * self.dim), count * self.dim) }
    }
}

unsafe impl Send for MmapGram {}
unsafe impl Sync for MmapGram {}

// ═══════════════════════════════════════════════════════════════════
// GPU-ACCELERATED MATRIX-VECTOR MULTIPLY (DOUBLE-BUFFERED)
// ═══════════════════════════════════════════════════════════════════

/// Double-buffered GPU matvec state.
///
/// Uses two CUDA streams with two device chunk buffers to overlap
/// PCIe H2D transfer with GPU compute:
///
///   Stream 0: [upload chunk 0] [compute chunk 0] [upload chunk 2] ...
///   Stream 1:                  [upload chunk 1]  [compute chunk 1] ...
///
/// For a 23 GB matrix with 1.7 GB chunks:
///   Single-buffer: upload(1.7s) → compute(0.5s) → upload → compute = ~2.2s/chunk
///   Double-buffer: upload overlaps compute = ~max(1.7, 0.5) = 1.7s/chunk (~30% faster)
///
/// For 108 GB (N=120k): ~60s/iter instead of ~90s/iter.
struct GpuMatvecState {
    blas_handle: *mut std::ffi::c_void,
    d_x: *mut f64,            // x vector (resident on GPU)
    d_chunk: [*mut f64; 2],   // double chunk buffers on GPU
    d_y_chunk: [*mut f64; 2], // double y output buffers on GPU
    streams: [gpu::ffi::CudaStream; 2],
    chunk_rows: usize,
    dim: usize,
}

impl GpuMatvecState {
    fn new(dim: usize, chunk_rows: usize) -> Result<Self, String> {
        let vec_bytes = dim * 8;
        let chunk_bytes = chunk_rows * dim * 8;
        let chunk_y_bytes = chunk_rows * 8;

        unsafe {
            let mut blas_handle: *mut std::ffi::c_void = std::ptr::null_mut();
            let s = gpu::ffi::cublasCreate_v2(&mut blas_handle);
            if s != 0 {
                return Err(format!("cublasCreate failed: {}", s));
            }

            let mut d_x: *mut f64 = std::ptr::null_mut();
            let mut d_chunk0: *mut f64 = std::ptr::null_mut();
            let mut d_chunk1: *mut f64 = std::ptr::null_mut();
            let mut d_y0: *mut f64 = std::ptr::null_mut();
            let mut d_y1: *mut f64 = std::ptr::null_mut();

            let s1 = gpu::ffi::cudaMalloc(&mut d_x, vec_bytes);
            let s2 = gpu::ffi::cudaMalloc(&mut d_chunk0, chunk_bytes);
            let s3 = gpu::ffi::cudaMalloc(&mut d_chunk1, chunk_bytes);
            let s4 = gpu::ffi::cudaMalloc(&mut d_y0, chunk_y_bytes);
            let s5 = gpu::ffi::cudaMalloc(&mut d_y1, chunk_y_bytes);
            if s1 != 0 || s2 != 0 || s3 != 0 || s4 != 0 || s5 != 0 {
                return Err(format!(
                    "cudaMalloc failed: {},{},{},{},{}",
                    s1, s2, s3, s4, s5
                ));
            }

            // Create two CUDA streams
            let mut stream0: gpu::ffi::CudaStream = std::ptr::null_mut();
            let mut stream1: gpu::ffi::CudaStream = std::ptr::null_mut();
            let sc0 = gpu::ffi::cudaStreamCreate(&mut stream0);
            let sc1 = gpu::ffi::cudaStreamCreate(&mut stream1);
            if sc0 != 0 || sc1 != 0 {
                return Err(format!("cudaStreamCreate failed: {},{}", sc0, sc1));
            }

            let vram_mb = (vec_bytes + 2 * chunk_bytes + 2 * chunk_y_bytes) / (1024 * 1024);
            eprintln!(
                "  ✓ Double-buffered GPU matvec: 2×{:.0} MB chunks, {} MB total VRAM",
                chunk_bytes as f64 / 1e6,
                vram_mb
            );

            Ok(GpuMatvecState {
                blas_handle,
                d_x,
                d_chunk: [d_chunk0, d_chunk1],
                d_y_chunk: [d_y0, d_y1],
                streams: [stream0, stream1],
                chunk_rows,
                dim,
            })
        }
    }

    /// Upload x vector to GPU (call once per CG iteration, synchronous)
    fn upload_x(&self, x: &[f64]) {
        unsafe {
            gpu::ffi::cudaMemcpy(self.d_x, x.as_ptr(), x.len() * 8, 1); // H2D
        }
    }

    /// Async upload chunk data to device buffer [buf_idx] on stream [buf_idx]
    fn upload_chunk_async(&self, chunk: &[f64], rows: usize, buf_idx: usize) {
        let bytes = rows * self.dim * 8;
        unsafe {
            gpu::ffi::cudaMemcpyAsync(
                self.d_chunk[buf_idx],
                chunk.as_ptr(),
                bytes,
                1, // cudaMemcpyHostToDevice
                self.streams[buf_idx],
            );
        }
    }

    /// Compute dgemv on stream [buf_idx]: y = chunk * x
    fn compute_chunk_async(&self, rows: usize, buf_idx: usize) {
        use std::ffi::c_int;
        let m = rows as c_int;
        let n = self.dim as c_int;
        let alpha = 1.0f64;
        let beta_val = 0.0f64;

        unsafe {
            // Set cuBLAS to use this stream
            gpu::ffi::cublasSetStream_v2(self.blas_handle, self.streams[buf_idx]);

            gpu::ffi::cublasDgemv_v2(
                self.blas_handle,
                1, // CUBLAS_OP_T
                n,
                m,
                &alpha,
                self.d_chunk[buf_idx],
                n,
                self.d_x,
                1,
                &beta_val,
                self.d_y_chunk[buf_idx],
                1,
            );
        }
    }

    /// Download y result from device buffer [buf_idx] (synchronous — waits for stream)
    fn download_y_sync(&self, rows: usize, buf_idx: usize, y_out: &mut [f64]) {
        unsafe {
            // Wait for this stream's compute to finish
            gpu::ffi::cudaStreamSynchronize(self.streams[buf_idx]);
            // Copy result back (D2H, synchronous)
            gpu::ffi::cudaMemcpy(
                y_out.as_mut_ptr(),
                self.d_y_chunk[buf_idx] as *const f64,
                rows * 8,
                2,
            );
        }
    }

    /// Synchronize a specific stream
    fn sync_stream(&self, buf_idx: usize) {
        unsafe {
            gpu::ffi::cudaStreamSynchronize(self.streams[buf_idx]);
        }
    }
}

impl Drop for GpuMatvecState {
    fn drop(&mut self) {
        unsafe {
            gpu::ffi::cudaFree(self.d_x);
            gpu::ffi::cudaFree(self.d_chunk[0]);
            gpu::ffi::cudaFree(self.d_chunk[1]);
            gpu::ffi::cudaFree(self.d_y_chunk[0]);
            gpu::ffi::cudaFree(self.d_y_chunk[1]);
            gpu::ffi::cudaStreamDestroy(self.streams[0]);
            gpu::ffi::cudaStreamDestroy(self.streams[1]);
            gpu::ffi::cublasDestroy_v2(self.blas_handle);
        }
    }
}

/// Compute y = G · x using mmap + double-buffered GPU cuBLAS.
///
/// Pipeline per CG iteration:
///   1. Upload x to GPU (once, synchronous)
///   2. For each chunk pair (i, i+1):
///      - Stream A: async upload chunk[i] → dgemv
///      - Stream B: async upload chunk[i+1] → (overlaps with A's dgemv)
///      - Sync stream A → download y[i]
///      - Swap streams
///   3. madvise(MADV_WILLNEED) prefetches next chunk's mmap pages
fn gpu_matvec(gram: &MmapGram, gpu: &GpuMatvecState, x: &[f64], y: &mut [f64]) {
    let dim = gram.dim;
    let chunk_rows = gpu.chunk_rows;

    // Upload x to GPU once
    gpu.upload_x(x);

    let chunks: Vec<(usize, usize)> = (0..dim)
        .step_by(chunk_rows)
        .map(|start| {
            let rows = chunk_rows.min(dim - start);
            (start, rows)
        })
        .collect();

    let n_chunks = chunks.len();
    if n_chunks == 0 {
        return;
    }

    // Prefetch first chunk
    let (start0, rows0) = chunks[0];
    let chunk0 = gram.row_chunk(start0, rows0);

    // Kick off first upload on stream 0
    gpu.upload_chunk_async(chunk0, rows0, 0);

    for c in 0..n_chunks {
        let buf = c % 2;
        let (start, rows) = chunks[c];

        // If there's a next chunk, prefetch its mmap pages and start async upload
        if c + 1 < n_chunks {
            let (next_start, next_rows) = chunks[c + 1];
            let next_buf = (c + 1) % 2;

            // madvise: tell kernel to pre-fault next chunk's pages
            let next_ptr = gram.row_chunk(next_start, next_rows).as_ptr();
            let next_bytes = next_rows * dim * 8;
            unsafe {
                libc::madvise(
                    next_ptr as *mut libc::c_void,
                    next_bytes,
                    libc::MADV_WILLNEED,
                );
            }

            // Wait for stream[buf] upload to finish, then start compute
            gpu.sync_stream(buf);
            gpu.compute_chunk_async(rows, buf);

            // While GPU computes chunk[c] on stream[buf],
            // start uploading chunk[c+1] on stream[next_buf]
            let next_chunk = gram.row_chunk(next_start, next_rows);
            gpu.upload_chunk_async(next_chunk, next_rows, next_buf);
        } else {
            // Last chunk — just wait and compute
            gpu.sync_stream(buf);
            gpu.compute_chunk_async(rows, buf);
        }

        // Download result for this chunk (waits for compute to finish)
        gpu.download_y_sync(rows, buf, &mut y[start..start + rows]);
    }
}

/// Fallback: CPU matvec using mmap (no GPU, rayon parallel)
fn cpu_matvec(gram: &MmapGram, x: &[f64], y: &mut [f64]) {
    let _dim = gram.dim;
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
fn ooc_cg_solve(gram_path: &Path, b: &[f64], dim: usize, tol: f64, max_iter: usize) -> f64 {
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
    println!(
        "  ✓ Matrix mmap'd in {:.2}s",
        t_mmap.elapsed().as_secs_f64()
    );

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
        if gii < diag_min {
            diag_min = gii;
        }
        if gii > diag_max {
            diag_max = gii;
        }
    }
    let diag_cond = if diag_min > 0.0 {
        diag_max / diag_min
    } else {
        f64::INFINITY
    };
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
    for i in 0..dim {
        z[i] = m_inv[i] * r[i];
    }
    let mut p = z.clone();
    let mut rz = dot_dd(&r, &z); // DD-precision r^T z
    let b_norm_sq = dot_dd(b, b);
    let b_norm = b_norm_sq.to_f64().sqrt();

    println!();
    println!("  ‖b‖ = {b_norm:.8e}");
    println!(
        "  {:<6} {:>14} {:>14} {:>14} {:>10}",
        "iter", "residual", "|Δd²|", "d²_est", "time(s)"
    );
    println!(
        "  {} {} {} {} {}",
        "─".repeat(6),
        "─".repeat(14),
        "─".repeat(14),
        "─".repeat(14),
        "─".repeat(10)
    );

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
            eprintln!(
                "  ⚠ pAp ≤ 0 at iter {iter} (DD: {:.6e}+{:.6e}), matrix not PD",
                pap.hi, pap.lo
            );
            break;
        }

        let alpha = rz / pap;
        let alpha_f64 = alpha.to_f64();

        // x += alpha * p; r -= alpha * y
        for i in 0..dim {
            x[i] += alpha_f64 * p[i];
        }
        for i in 0..dim {
            r[i] -= alpha_f64 * y[i];
        }

        // Apply preconditioner: z = M^{-1} r
        for i in 0..dim {
            z[i] = m_inv[i] * r[i];
        }

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
        let should_print =
            iter < 20 || (iter < 100 && iter % 10 == 0) || iter % 50 == 0 || residual < tol;
        if should_print {
            println!(
                "  {:6} {:14.8e} {:14.8e} {:14.10} {:10.2}",
                iter, residual, d2_delta, d2_est, iter_time
            );
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
                for i in 0..dim {
                    r[i] = b[i] - y[i];
                }
                for i in 0..dim {
                    z[i] = m_inv[i] * r[i];
                }
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
        for i in 0..dim {
            p[i] = z[i] + beta_f64 * p[i];
        }
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
    let n_chunks = n.div_ceil(CHUNK);

    let partials: Vec<DD> = (0..n_chunks)
        .into_par_iter()
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
fn write_certificate(
    max_n: usize,
    dim: usize,
    d2: f64,
    max_iter: usize,
    tol: f64,
    elapsed: f64,
    mode: &str,
) {
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
        .ok_or_else(|| std::io::Error::other("Failed to load DD cache"))?;

    assert_eq!(loaded_dim, dim, "Dimension mismatch");

    // Write OOC format
    std::fs::create_dir_all(ooc_path.parent().unwrap())?;
    let file = std::fs::File::create(&ooc_path)?;
    let mut writer = BufWriter::with_capacity(64 * 1024 * 1024, file);

    let checksum: u64 = hi
        .iter()
        .take(64)
        .map(|v| v.to_bits())
        .fold(0u64, |acc, b| acc.wrapping_add(b));

    write_ooc_header(&mut writer, max_n, dim, 256, checksum)?;

    let bytes: &[u8] =
        unsafe { std::slice::from_raw_parts(hi.as_ptr() as *const u8, hi.len() * 8) };
    writer.write_all(bytes)?;
    writer.flush()?;

    let elapsed = t0.elapsed().as_secs_f64();
    let gb = (hi.len() * 8) as f64 / (1024.0 * 1024.0 * 1024.0);
    println!("  ✓ Imported {gb:.1} GB in {elapsed:.1}s");

    Ok(Some(ooc_path))
}

// ═══════════════════════════════════════════════════════════════════
// VERIFY — Rust-native spectral integrity certification
// ═══════════════════════════════════════════════════════════════════

/// Verify an OOC Gram matrix for spectral integrity:
///   1. SHA-256 hash of the full matrix data
///   2. Spot-check random entries against CPU MPFR-256 reference
///   3. Diagonal positivity check
///   4. Symmetry validation (random off-diagonal pairs)
///   5. Leading submatrix Cholesky (PD test)
///   6. d² computation for select sub-dimensions
fn verify_ooc_matrix(max_n: usize, precision: u32, t_max: usize) {
    let path = ooc_gram_path(max_n, precision);
    if !path.exists() {
        eprintln!("  ❌ OOC cache not found: {}", path.display());
        std::process::exit(1);
    }

    let dim = max_n - 1;
    let t0 = Instant::now();

    println!("  ╔═══════════════════════════════════════════════════════════════╗");
    println!("  ║  🔍 OOC VERIFY — Spectral Integrity Certification            ║");
    println!("  ╚═══════════════════════════════════════════════════════════════╝");
    println!("  N = {max_n}, dim = {dim}");
    println!("  T_max = {t_max} (uniform truncation)");
    println!("  Cache: {}", path.display());
    println!();

    // Open mmap
    let gram = MmapGram::open(&path, dim).expect("Failed to open OOC matrix");

    // ── Phase 1: SHA-256 integrity hash ──
    print!("  ▸ Phase 1: SHA-256 hash...");
    use sha2::{Digest, Sha256};
    let mut hasher = Sha256::new();
    // Hash in chunks to avoid loading entire matrix
    let chunk_size = 64 * 1024; // 64K entries = 512 KB
    let total_entries = dim * dim;
    for start in (0..total_entries).step_by(chunk_size) {
        let end = (start + chunk_size).min(total_entries);
        let slice = unsafe { std::slice::from_raw_parts(gram.data.add(start), end - start) };
        let bytes: &[u8] =
            unsafe { std::slice::from_raw_parts(slice.as_ptr() as *const u8, slice.len() * 8) };
        hasher.update(bytes);
    }
    let hash = hasher.finalize();
    let hash_hex: String = hash.iter().map(|b| format!("{:02x}", b)).collect();
    println!(" {}", &hash_hex[..16]);

    // ── Phase 2: Diagonal check ──
    print!("  ▸ Phase 2: Diagonal positivity...");
    let mut diag_min = f64::MAX;
    let mut diag_max = f64::MIN;
    let mut diag_negative = 0usize;
    for i in 0..dim {
        let val = gram.row(i)[i];
        if val <= 0.0 {
            diag_negative += 1;
        }
        diag_min = diag_min.min(val);
        diag_max = diag_max.max(val);
    }
    if diag_negative == 0 {
        println!(" ✓ all positive [{:.6e}, {:.6e}]", diag_min, diag_max);
    } else {
        println!(" ✗ {} NEGATIVE diagonal entries!", diag_negative);
    }

    // ── Phase 3: Symmetry check (random pairs) ──
    print!("  ▸ Phase 3: Symmetry check...");
    let n_sym_checks = 1000.min(dim * dim);
    let mut sym_max_err = 0.0f64;
    let mut sym_fails = 0usize;
    // Deterministic "random" using simple hash
    for k in 0..n_sym_checks {
        let i = (k * 7919 + 13) % dim;
        let j = (k * 6271 + 37) % dim;
        let gij = gram.row(i)[j];
        let gji = gram.row(j)[i];
        let err = (gij - gji).abs();
        if err > 0.0 {
            sym_fails += 1;
        }
        sym_max_err = sym_max_err.max(err);
    }
    if sym_max_err == 0.0 {
        println!(" ✓ exact (checked {} pairs)", n_sym_checks);
    } else {
        println!(
            " max |G[i,j]-G[j,i]| = {:.2e} ({} asymmetric)",
            sym_max_err, sym_fails
        );
    }

    // ── Phase 4: Spot-check against CPU MPFR reference ──
    print!("  ▸ Phase 4: CPU MPFR cross-verification...");
    let n_spot = 20; // check 20 entries
    let ln_table_size = t_max.max(max_n * 5).max(10_000).min(500_000);
    let ln_table = gram::LnNTable::new(ln_table_size + 1, precision);
    let mut max_rel_err = 0.0f64;
    let mut max_abs_err = 0.0f64;
    let mut spot_results: Vec<(usize, usize, f64, f64, f64)> = Vec::new();

    for k in 0..n_spot {
        // Pick entries that stress different regimes
        let i = match k {
            0 => 0,                     // (2,2) - smallest
            1 => 0,                     // (2,3)
            2 => dim / 4,               // middle band
            3 => dim / 2,               // center
            4 => dim - 1,               // (N, N) - largest
            _ => (k * 4793 + 11) % dim, // pseudo-random
        };
        let j = match k {
            0 => 0,
            1 => 1,
            2 => dim / 4 + 1,
            3 => dim / 2,
            4 => dim - 1,
            _ => (k * 3571 + 7) % dim,
        };

        let gpu_val = gram.row(i)[j];
        let cpu_val = gram::gram_entry_fast_at_t(i + 2, j + 2, &ln_table, t_max).to_f64();

        let abs_err = (gpu_val - cpu_val).abs();
        let rel_err = if cpu_val.abs() > 1e-30 {
            abs_err / cpu_val.abs()
        } else {
            abs_err
        };
        max_rel_err = max_rel_err.max(rel_err);
        max_abs_err = max_abs_err.max(abs_err);
        spot_results.push((i + 2, j + 2, gpu_val, cpu_val, rel_err));
    }
    if max_rel_err < 1e-12 {
        println!(" ✓ max rel err = {:.2e}", max_rel_err);
    } else if max_rel_err < 1e-8 {
        println!(" ⚠ max rel err = {:.2e} (acceptable)", max_rel_err);
    } else {
        println!(" ✗ max rel err = {:.2e} (SUSPICIOUS!)", max_rel_err);
    }

    // Print worst spot-checks
    spot_results.sort_by(|a, b| b.4.partial_cmp(&a.4).unwrap());
    for (j, k, gv, cv, re) in spot_results.iter().take(5) {
        println!("    G[{j},{k}]: cache={gv:.12e} cpu={cv:.12e} rel={re:.2e}");
    }

    // ── Phase 5: Submatrix Cholesky (PD test) ──
    let sub_dim = 500.min(dim);
    print!("  ▸ Phase 5: Cholesky PD test ({}×{})...", sub_dim, sub_dim);
    let mut sub = vec![0.0f64; sub_dim * sub_dim];
    for i in 0..sub_dim {
        let row = gram.row(i);
        sub[i * sub_dim..i * sub_dim + sub_dim].copy_from_slice(&row[..sub_dim]);
    }
    // In-place Cholesky
    let mut chol_ok = true;
    let mut chol_fail_col = 0;
    for j in 0..sub_dim {
        let mut s = sub[j * sub_dim + j];
        for k in 0..j {
            s -= sub[j * sub_dim + k] * sub[j * sub_dim + k];
        }
        if s <= 0.0 {
            chol_ok = false;
            chol_fail_col = j + 1;
            break;
        }
        sub[j * sub_dim + j] = s.sqrt();
        let ljj = sub[j * sub_dim + j];
        for i in (j + 1)..sub_dim {
            let mut s = sub[i * sub_dim + j];
            for k in 0..j {
                s -= sub[i * sub_dim + k] * sub[j * sub_dim + k];
            }
            sub[i * sub_dim + j] = s / ljj;
        }
    }
    if chol_ok {
        println!(" ✓ positive-definite");
    } else {
        println!(
            " ✗ FAILED at column {} — NOT positive-definite!",
            chol_fail_col
        );
    }

    // ── Phase 6: d² computation ──
    let b = arith::b_vector(dim);
    // Compute d² for the sub_dim submatrix using the Cholesky we just did
    // (if it succeeded)
    let d2_sub = if chol_ok {
        // Forward solve: L y = b_sub
        let b_sub: Vec<f64> = b[..sub_dim].to_vec();
        let mut y = vec![0.0f64; sub_dim];
        // Need to redo Cholesky since we overwrote sub[] with L
        // Actually we have L in sub, so forward solve
        for i in 0..sub_dim {
            let mut s = b_sub[i];
            for k in 0..i {
                s -= sub[i * sub_dim + k] * y[k];
            }
            y[i] = s / sub[i * sub_dim + i];
        }
        // d² = 1 - b^T G^{-1} b = 1 - y^T y
        let yty: f64 = y.iter().map(|v| v * v).sum();
        Some(1.0 - yty)
    } else {
        None
    };

    if let Some(d2) = d2_sub {
        println!("  ▸ Phase 6: d²_{} = {:.12}", sub_dim + 1, d2);
        if d2 > 0.0 && d2 < 1.0 {
            println!("    ✓ RH-consistent (0 < d² < 1)");
        } else if d2 > 0.0 {
            println!("    ✓ d² > 0 (positive — good for NB equivalence)");
        } else {
            println!("    ⚠ d² ≤ 0 — investigate!");
        }
    }

    let total_time = t0.elapsed().as_secs_f64();

    // ── Write verification certificate ──
    let cert_path = ooc_cache_dir().join(format!("ooc_verify_N{max_n}.json"));
    let matrix_gb = (dim as u64 * dim as u64 * 8) as f64 / (1024.0 * 1024.0 * 1024.0);
    let json = format!(
        r#"{{
  "tool": "ooc-probe verify",
  "timestamp": "{}",
  "N": {},
  "dim": {},
  "t_max": {},
  "matrix_gb": {:.2},
  "sha256": "{}",
  "diagonal_min": {:.15e},
  "diagonal_max": {:.15e},
  "diagonal_all_positive": {},
  "symmetry_max_error": {:.2e},
  "symmetry_checks": {},
  "spot_check_max_rel_error": {:.2e},
  "spot_check_max_abs_error": {:.2e},
  "spot_check_count": {},
  "cholesky_pd": {},
  "cholesky_sub_dim": {},
  "cholesky_fail_col": {},
  "d2_sub": {},
  "elapsed_seconds": {:.1},
  "verdict": "{}"
}}"#,
        chrono_now(),
        max_n,
        dim,
        t_max,
        matrix_gb,
        hash_hex,
        diag_min,
        diag_max,
        diag_negative == 0,
        sym_max_err,
        n_sym_checks,
        max_rel_err,
        max_abs_err,
        n_spot,
        chol_ok,
        sub_dim,
        chol_fail_col,
        d2_sub.map_or("null".to_string(), |v| format!("{:.15e}", v)),
        total_time,
        if chol_ok && diag_negative == 0 && max_rel_err < 1e-8 {
            "PASS"
        } else {
            "FAIL"
        },
    );

    if let Ok(()) = std::fs::write(&cert_path, &json) {
        println!("  📜 Verification certificate → {}", cert_path.display());
    }

    println!();
    if chol_ok && diag_negative == 0 && max_rel_err < 1e-8 {
        println!("  ✅ VERDICT: PASS — matrix verified for spectral integrity");
    } else {
        println!("  ❌ VERDICT: FAIL — matrix has integrity issues");
    }
    println!("  Total verification time: {:.1}s", total_time);
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
        eprintln!(
            "  ooc-probe build   <N> [--precision <bits>] [--t-max <T>]  Build OOC Gram matrix"
        );
        eprintln!("  ooc-probe solve   <N> [--tol <tol>]                       CG solve for d²");
        eprintln!("  ooc-probe full    <N> [--t-max <T>]                       Build + solve");
        eprintln!(
            "  ooc-probe verify  <N> [--t-max <T>]                       Spectral integrity check"
        );
        eprintln!(
            "  ooc-probe import  <N>                                     Import existing DD cache"
        );
        eprintln!(
            "  ooc-probe info    <N>                                     Show OOC cache info"
        );
        eprintln!();
        eprintln!("  --t-max <T>  Uniform truncation horizon (default: 200000)");
        eprintln!("               Ensures positive-definiteness of the Gram matrix.");
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
    let t_max: usize = parse_flag(&args, "--t-max").unwrap_or(200_000);

    // Check GPU
    if let Some(info) = gpu::detect_gpu() {
        println!("  GPU: {} ({} MB VRAM)", info.name, info.vram_mb);
    }

    println!("  OOC cache: {}", ooc_cache_dir().display());
    println!();

    match cmd {
        "build" => {
            ooc_build_gram(max_n, precision, t_max).expect("Build failed");
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
            let header = read_ooc_header(&mut f)
                .unwrap()
                .expect("Invalid OOC header");
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
            let path = ooc_build_gram(max_n, precision, t_max).expect("Build failed");
            let build_time = t0.elapsed().as_secs_f64();
            println!();

            let dim = max_n - 1;
            let b = arith::b_vector(dim);
            let t_solve = Instant::now();
            let d2 = ooc_cg_solve(&path, &b, dim, tol, max_iter);
            let solve_time = t_solve.elapsed().as_secs_f64();
            let total_time = t0.elapsed().as_secs_f64();

            println!("\n  🎯 RESULT: d²_{} = {:.12}", max_n, d2);
            println!(
                "  Build: {build_time:.1}s | Solve: {solve_time:.1}s | Total: {total_time:.1}s"
            );

            write_certificate(max_n, dim, d2, max_iter, tol, total_time, "full");
        }
        "import" => match import_dd_cache(max_n) {
            Ok(Some(path)) => println!("  ✓ OOC cache ready: {}", path.display()),
            Ok(None) => eprintln!("  ❌ No DD cache found for N={max_n}"),
            Err(e) => eprintln!("  ❌ Import failed: {e}"),
        },
        "verify" => {
            verify_ooc_matrix(max_n, precision, t_max);
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
                            let size_gb = meta
                                .map(|m| m.len() as f64 / (1024.0 * 1024.0 * 1024.0))
                                .unwrap_or(0.0);
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
            eprintln!("  Use: build, solve, full, verify, import, info");
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
