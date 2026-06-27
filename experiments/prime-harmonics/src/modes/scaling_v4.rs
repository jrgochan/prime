//! # Scaling Mode v4: Incremental Cholesky from OOC mmap'd Gram matrix
//!
//! ## Architecture
//!
//! Reads from the OOC binary via memory-mapped I/O. The OS page cache handles
//! what stays in RAM — we never load the full matrix.
//!
//! ## KEY OPTIMIZATION: Blocked Parallel Forward Solve
//!
//! Instead of solving L·w = g one row at a time (sequential, cache-unfriendly),
//! we process BLOCKS of B=256 rows:
//!
//! ```text
//! For each block [bs, bs+B):
//!   Step 1 (PARALLEL, ~99% of work):
//!     For each row i in block, in parallel:
//!       g[i] -= dot(L[i, 0..bs], w[0..bs])    // independent per row!
//!
//!   Step 2 (sequential, ~1% of work):
//!     Small B×B triangular solve within the block
//! ```
//!
//! Step 1 is embarrassingly parallel across B rows, each doing a dot product
//! of length `block_start`. At dim=50K with B=256 and 16 cores: 16× speedup!
//!
//! THE MONOTONICITY THEOREM (Gemini, May 30 2026):
//!   d²(N) = d²(N-1) - y²_new
//!   Since y²_new ≥ 0, d²_opt is STRICTLY MONOTONICALLY DECREASING.

extern crate libc;

use rayon::prelude::*;
use std::io::Read;
use std::path::{Path, PathBuf};
use std::time::Instant;

const EULER_GAMMA: f64 = 0.5772156649015329;

// OOC file format constants (must match ooc_probe.rs)
const OOC_MAGIC: u64 = 0x434F4F4854_414300;
const OOC_VERSION: u32 = 1;
const OOC_HEADER_SIZE: usize = 40;

/// Block size for the blocked forward solve.
/// 256 = 16 rows per core on a 16-core machine, good balance of
/// parallelism (step 1) vs sequential overhead (step 2: 256²/2 = 32K flops).
const BLOCK_SIZE: usize = 256;

/// BD b-vector entry: b_k = (ln(k) + 1 - γ) / k
#[inline]
fn b_entry(k: usize) -> f64 {
    ((k as f64).ln() + 1.0 - EULER_GAMMA) / k as f64
}

/// Packed lower-triangular index: L[row, col] → flat index
#[inline(always)]
fn l_idx(row: usize, col: usize) -> usize {
    row * (row + 1) / 2 + col
}

/// Memory-mapped OOC Gram matrix for zero-copy access.
struct MmapGram {
    data: *const f64,
    mmap_base: *mut libc::c_void,
    dim: usize,
    _mmap_len: usize,
}

impl MmapGram {
    fn open(path: &Path) -> Result<Self, String> {
        use std::os::unix::io::AsRawFd;

        let file = std::fs::File::open(path)
            .map_err(|e| format!("Cannot open {}: {}", path.display(), e))?;
        let file_len = file
            .metadata()
            .map_err(|e| format!("Cannot stat: {e}"))?
            .len() as usize;

        // Read and validate header
        let mut f = std::io::BufReader::new(&file);
        let mut buf8 = [0u8; 8];
        let mut buf4 = [0u8; 4];

        f.read_exact(&mut buf8)
            .map_err(|e| format!("Read error: {e}"))?;
        if u64::from_le_bytes(buf8) != OOC_MAGIC {
            return Err("Invalid OOC magic".into());
        }

        f.read_exact(&mut buf4)
            .map_err(|e| format!("Read error: {e}"))?;
        if u32::from_le_bytes(buf4) != OOC_VERSION {
            return Err("Unknown OOC version".into());
        }

        f.read_exact(&mut buf4)
            .map_err(|e| format!("Read error: {e}"))?;
        let max_n = u32::from_le_bytes(buf4) as usize;

        f.read_exact(&mut buf4)
            .map_err(|e| format!("Read error: {e}"))?;
        let dim = u32::from_le_bytes(buf4) as usize;

        eprintln!("  OOC header: max_n={max_n}, dim={dim}");

        let expected = OOC_HEADER_SIZE + dim * dim * 8;
        if file_len < expected {
            return Err(format!("File too small: {file_len} < {expected}"));
        }

        let fd = file.as_raw_fd();
        let ptr = unsafe {
            libc::mmap(
                std::ptr::null_mut(),
                file_len,
                libc::PROT_READ,
                libc::MAP_SHARED, // SHARED: no copy-on-write page duplication
                fd,
                0,
            )
        };

        if ptr == libc::MAP_FAILED {
            return Err(format!("mmap failed: {}", std::io::Error::last_os_error()));
        }

        // Sequential access — we read rows in order
        unsafe {
            libc::madvise(ptr, file_len, libc::MADV_SEQUENTIAL);
        }

        let data_ptr = unsafe { (ptr as *const u8).add(OOC_HEADER_SIZE) as *const f64 };
        std::mem::forget(file);

        Ok(MmapGram {
            data: data_ptr,
            mmap_base: ptr,
            dim,
            _mmap_len: file_len,
        })
    }

    /// Get a contiguous row slice — zero copy from mmap
    #[inline]
    fn row(&self, i: usize) -> &[f64] {
        unsafe { std::slice::from_raw_parts(self.data.add(i * self.dim), self.dim) }
    }

    /// Release page cache for rows we've already read.
    /// This prevents the mmap'd file from competing with L triangle for RAM.
    fn dontneed_rows(&self, start_row: usize, count: usize) {
        if count == 0 { return; }
        let page_size = 4096usize;
        let byte_offset = start_row * self.dim * 8;
        let byte_len = count * self.dim * 8;
        // Align to page boundary
        let aligned_start = byte_offset & !(page_size - 1);
        let aligned_len = ((byte_offset + byte_len + page_size - 1) & !(page_size - 1)) - aligned_start;
        unsafe {
            let base = (self.mmap_base as *const u8).add(OOC_HEADER_SIZE + aligned_start);
            libc::madvise(base as *mut libc::c_void, aligned_len, libc::MADV_DONTNEED);
        }
    }
}

unsafe impl Send for MmapGram {}
unsafe impl Sync for MmapGram {}

// ═══════════════════════════════════════════════════════════════════
// BLOCKED PARALLEL FORWARD SOLVE
// ═══════════════════════════════════════════════════════════════════

/// Solve L · w = g where L is lower triangular in packed format.
///
/// Uses blocked algorithm: process BLOCK_SIZE rows at a time.
/// Step 1 (parallel via par_chunks_mut): apply previous columns.
///   Each rayon task processes a BATCH of rows (not one per task),
///   minimizing synchronization overhead to ~num_threads tasks.
/// Step 2 (sequential): small internal triangular solve.
///
/// Returns w.
fn blocked_forward_solve(l_data: &[f64], g: &[f64], n: usize) -> Vec<f64> {
    let mut g_work = g.to_vec();
    let mut w = vec![0.0f64; n];

    // Cast pointer to usize for thread safety (usize is Send+Sync).
    let l_base: usize = l_data.as_ptr() as usize;
    let num_threads = rayon::current_num_threads();

    for block_start in (0..n).step_by(BLOCK_SIZE) {
        let block_end = (block_start + BLOCK_SIZE).min(n);
        let block_len = block_end - block_start;

        // ── Step 1: Apply previous columns ──
        // Only parallelize when dot products are long enough to amortize overhead.
        // Threshold: block_start * block_len > ~1M flops (empirically tuned).
        if block_start > 2048 && block_len > 1 {
            let w_prev = &w[..block_start];
            let g_block = &mut g_work[block_start..block_end];

            // Compute chunk size: aim for ~num_threads chunks (one per core).
            // Each chunk processes multiple consecutive L rows → great cache locality
            // since packed L rows are contiguous in memory.
            let rows_per_chunk = block_len.div_ceil(num_threads);

            g_block
                .par_chunks_mut(rows_per_chunk.max(1))
                .enumerate()
                .for_each(|(chunk_idx, chunk)| {
                    let chunk_start = block_start + chunk_idx * rows_per_chunk;
                    for (local_i, g_val) in chunk.iter_mut().enumerate() {
                        let i = chunk_start + local_i;
                        let l_start = i * (i + 1) / 2;
                        let l_slice = unsafe {
                            std::slice::from_raw_parts(
                                (l_base as *const f64).add(l_start),
                                block_start,
                            )
                        };

                        let dot: f64 = l_slice
                            .iter()
                            .zip(w_prev.iter())
                            .map(|(&a, &b)| a * b)
                            .sum();

                        *g_val -= dot;
                    }
                });
        } else if block_start > 0 {
            // SEQUENTIAL: faster for small block_start (avoids rayon overhead)
            let w_prev = &w[..block_start];
            for local_i in 0..block_len {
                let i = block_start + local_i;
                let l_start = i * (i + 1) / 2;
                let l_slice = &l_data[l_start..l_start + block_start];
                let dot: f64 = l_slice
                    .iter()
                    .zip(w_prev.iter())
                    .map(|(&a, &b)| a * b)
                    .sum();
                g_work[i] -= dot;
            }
        }

        // ── Step 2: Sequential triangular solve within block ──
        for i in block_start..block_end {
            let l_start = l_idx(i, 0);
            if i > block_start {
                let l_slice = &l_data[l_start + block_start..l_start + i];
                let w_slice = &w[block_start..i];
                let dot: f64 = l_slice
                    .iter()
                    .zip(w_slice.iter())
                    .map(|(&a, &b)| a * b)
                    .sum();
                g_work[i] -= dot;
            }
            w[i] = g_work[i] / l_data[l_idx(i, i)];
        }
    }

    w
}

// ═══════════════════════════════════════════════════════════════════
// MAIN SWEEP
// ═══════════════════════════════════════════════════════════════════

pub fn run(ooc_path: &str, max_n: usize) {
    eprintln!();
    eprintln!("{}", "═".repeat(70));
    eprintln!("SCALING v4 — Blocked Parallel Cholesky from OOC mmap'd Gram");
    eprintln!("{}", "═".repeat(70));
    eprintln!();

    let path = PathBuf::from(ooc_path);
    if !path.exists() {
        let alt = PathBuf::from(format!(
            "/mnt/d/cathedral-cache/ooc_gram_N{max_n}_p256.bin"
        ));
        if alt.exists() {
            eprintln!("  Found OOC file: {}", alt.display());
            return run_inner(&alt, max_n);
        }
        eprintln!("  ❌ OOC file not found: {}", path.display());
        std::process::exit(1);
    }
    run_inner(&path, max_n);
}

fn run_inner(path: &Path, max_n: usize) {
    let max_dim = max_n - 1;

    eprintln!("Rayon threads: {}", rayon::current_num_threads());
    eprintln!("Block size: {BLOCK_SIZE}");
    eprintln!("Incremental sweep: N = 2 to {max_n}");
    eprintln!(
        "L triangle: {} entries ({:.1} GB)",
        max_dim * (max_dim + 1) / 2,
        max_dim as f64 * (max_dim + 1) as f64 / 2.0 * 8.0 / 1e9
    );
    eprintln!("OOC source: {}", path.display());
    eprintln!();

    // ═══ Open mmap'd Gram ═══
    let t_mmap = Instant::now();
    let gram = MmapGram::open(path).expect("Failed to open OOC Gram matrix");
    eprintln!(
        "  ✓ mmap'd in {:.2}s (dim={})",
        t_mmap.elapsed().as_secs_f64(),
        gram.dim
    );

    let max_dim = max_dim.min(gram.dim);
    let effective_max = max_dim + 1;

    // ═══ Precompute number theory ═══
    let t_nt = Instant::now();

    let mut is_prime = vec![true; effective_max + 1];
    is_prime[0] = false;
    if effective_max >= 1 {
        is_prime[1] = false;
    }
    for i in 2..=effective_max {
        if is_prime[i] {
            let mut j = i * i;
            while j <= effective_max {
                is_prime[j] = false;
                j += i;
            }
        }
    }

    let mut tau = vec![0u32; effective_max + 1];
    for i in 1..=effective_max {
        let mut j = i;
        while j <= effective_max {
            tau[j] += 1;
            j += i;
        }
    }

    let mut is_hcn = vec![false; effective_max + 1];
    let mut max_tau: u32 = 0;
    for n in 1..=effective_max {
        if tau[n] > max_tau {
            max_tau = tau[n];
            is_hcn[n] = true;
        }
    }
    eprintln!("  Number theory: {:.2}s", t_nt.elapsed().as_secs_f64());

    // ═══ Precompute b_vector ═══
    let b_full: Vec<f64> = (0..max_dim).map(|i| b_entry(i + 2)).collect();

    // ═══ Allocate L triangle ═══
    let tri_size = max_dim * (max_dim + 1) / 2;
    eprintln!(
        "  Allocating L triangle: {tri_size} entries ({:.1} GB)...",
        tri_size as f64 * 8.0 / 1e9
    );
    let mut l_data: Vec<f64> = vec![0.0; tri_size];
    let mut z: Vec<f64> = Vec::with_capacity(max_dim);
    let mut norm_z_sq: f64 = 0.0;
    eprintln!("  Allocated. Starting sweep...");
    eprintln!();

    println!("# Dense d²_opt — Blocked Parallel Cholesky v4 (OOC mmap)");
    println!("# Source: {}", path.display());
    println!("# Block size: {BLOCK_SIZE}, threads: {}", rayon::current_num_threads());
    println!("# Monotonicity: d²(N) = d²(N-1) - y²_new");
    println!("N\td2_opt\tln_N\td2_lnN\td2_ln2N\ty2_new\tis_prime\tis_hcn\ttau\tclass");

    let t_sweep = Instant::now();

    for dim in 1..=max_dim {
        let n = dim + 1;
        let new_row = dim - 1;

        if new_row == 0 {
            // First entry: trivial
            let g00 = gram.row(0)[0];
            let s = g00.sqrt();
            l_data[l_idx(0, 0)] = s;
            let z0 = b_full[0] / s;
            z.push(z0);
            norm_z_sq = z0 * z0;
        } else {
            // Read row `new_row` from mmap (contiguous, cache-friendly!)
            // G is symmetric: row[i] = G(new_row, i) = G(i, new_row)
            let gram_row = gram.row(new_row);

            // ── BLOCKED PARALLEL FORWARD SOLVE ──
            let w = blocked_forward_solve(&l_data, &gram_row[..new_row], new_row);

            // Release the mmap'd page cache for rows we've consumed.
            // This prevents the 75 GB file from evicting L triangle pages.
            // Release in batches of 1024 rows to amortize syscall overhead.
            if new_row % 1024 == 0 && new_row >= 1024 {
                gram.dontneed_rows(new_row - 1024, 1024);
            }

            // s = sqrt(G(new_row, new_row) - ‖w‖²)
            // Parallel w_norm_sq for large dim
            let w_norm_sq: f64 = if new_row > 10000 {
                w.par_chunks(4096)
                    .map(|chunk| chunk.iter().map(|x| x * x).sum::<f64>())
                    .sum()
            } else {
                w.iter().map(|x| x * x).sum()
            };

            let diag = gram_row[new_row];
            let s_sq = diag - w_norm_sq;

            if s_sq <= 0.0 {
                eprintln!("  ⚠ N={n}: Cholesky breakdown (s²={s_sq:.2e}), skipping");
                let l_row_start = l_idx(new_row, 0);
                l_data[l_row_start..l_row_start + new_row].copy_from_slice(&w);
                l_data[l_idx(new_row, new_row)] = 1e-15;
                z.push(0.0);
                continue;
            }
            let s = s_sq.sqrt();

            // Store new row of L
            let l_row_start = l_idx(new_row, 0);
            l_data[l_row_start..l_row_start + new_row].copy_from_slice(&w);
            l_data[l_idx(new_row, new_row)] = s;

            // z_new — parallel dot product for large dim
            let wt_z: f64 = if new_row > 10000 {
                w.par_chunks(4096)
                    .zip(z.par_chunks(4096))
                    .map(|(wc, zc)| wc.iter().zip(zc.iter()).map(|(&a, &b)| a * b).sum::<f64>())
                    .sum()
            } else {
                w.iter().zip(z.iter()).map(|(&a, &b)| a * b).sum()
            };
            let z_new = (b_full[new_row] - wt_z) / s;

            z.push(z_new);
            norm_z_sq += z_new * z_new;
        }

        let d2 = 1.0 - norm_z_sq;
        let ln_n = (n as f64).ln();
        let d2_ln = d2 * ln_n;
        let d2_ln2 = d2 * ln_n * ln_n;
        let y2_new = if z.is_empty() {
            0.0
        } else {
            z.last().unwrap().powi(2)
        };
        let p = if is_prime[n] { 1 } else { 0 };
        let h = if is_hcn[n] { 1 } else { 0 };
        let t = tau[n];
        let class = if is_hcn[n] {
            "HCN"
        } else if is_prime[n] {
            "prime"
        } else {
            "comp"
        };

        println!(
            "{n}\t{d2:.12e}\t{ln_n:.6}\t{d2_ln:.10}\t{d2_ln2:.10}\t{y2_new:.12e}\t{p}\t{h}\t{t}\t{class}"
        );

        if dim % 5000 == 0 || (dim <= 100 && dim % 10 == 0) {
            let elapsed = t_sweep.elapsed().as_secs_f64();
            let rate = dim as f64 / elapsed;
            let frac_done = (dim as f64).powi(3) / (max_dim as f64).powi(3);
            let eta = if frac_done > 0.001 {
                elapsed / frac_done * (1.0 - frac_done)
            } else {
                0.0
            };
            let hrs = eta / 3600.0;
            eprintln!(
                "  N={n} (dim={dim}) d²={d2:.8e} y²={y2_new:.4e} | {elapsed:.0}s ({rate:.1} N/s) ETA {hrs:.1}h [{:.1}% work done]",
                frac_done * 100.0
            );
        }
    }

    let total = t_sweep.elapsed().as_secs_f64();
    let rate = max_dim as f64 / total;
    eprintln!();
    eprintln!(
        "Done: {} values in {:.1}s = {:.2}h ({rate:.0} N/s)",
        max_dim,
        total,
        total / 3600.0
    );
    eprintln!(
        "Memory: L triangle = {} entries ({:.1} GB)",
        tri_size,
        tri_size as f64 * 8.0 / 1e9
    );
}
