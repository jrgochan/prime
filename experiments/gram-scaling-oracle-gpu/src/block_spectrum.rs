//! ═══════════════════════════════════════════════════════════════════════════
//!  GCD-BLOCK SPECTRAL ANALYSIS
//!
//!  For N too large to store the full matrix (N > ~90K on 64 GB RAM),
//!  we decompose into GCD blocks and analyze each independently.
//!
//!  GCD class d: indices {d, 2d, 3d, ..., ⌊N/d⌋·d}
//!  Block dimension: ⌊N/d⌋
//!
//!  The block submatrix G^{(d)}_{ij} = G_{id, jd} is built on-the-fly
//!  using `gram_entry_f64()` — no full matrix storage needed.
//!
//!  Execution tiers:
//!    dim ≤ max_gpu_dim: GPU cuSOLVER dsyevd (NoVec)
//!    dim > max_gpu_dim: CPU OpenBLAS dsyevr (λ_min only)
//! ═══════════════════════════════════════════════════════════════════════════

use rayon::prelude::*;
use cathedral_utils::gram::gram_entry_f64;
use std::time::Instant;
use std::sync::atomic::{AtomicUsize, Ordering};

/// Result of spectral analysis on a single GCD block.
#[derive(Debug, Clone)]
pub struct BlockResult {
    pub gcd_class: usize,
    pub dim: usize,
    pub lambda_min: f64,
    pub compute_secs: f64,
    pub mode: &'static str,
}

/// Build the Gram submatrix for GCD class d at a given N.
///
/// Indices: {d, 2d, 3d, ..., ⌊N/d⌋·d}
/// Matrix entries: G_{id, jd} for i,j ∈ 1..=⌊N/d⌋
///
/// Returns (flat row-major data, dimension).
pub fn build_block_matrix(n: usize, d: usize) -> (Vec<f64>, usize) {
    let block_dim = n / d;
    if block_dim < 2 { return (vec![], 0); }

    let total = block_dim * (block_dim + 1) / 2;
    let t0 = Instant::now();

    // Build upper triangle in parallel, then mirror
    let pairs: Vec<(usize, usize)> = (0..block_dim)
        .flat_map(|i| (i..block_dim).map(move |j| (i, j)))
        .collect();

    let done = AtomicUsize::new(0);
    let entries: Vec<((usize, usize), f64)> = pairs
        .par_iter()
        .map(|&(i, j)| {
            let ji = (i + 1) * d; // actual index = (i+1)*d
            let jj = (j + 1) * d;
            let val = gram_entry_f64(ji, jj);

            let count = done.fetch_add(1, Ordering::Relaxed);
            if block_dim > 500 && count % (total / 20).max(1) == 0 && count > 0 {
                eprint!("\r    d={d} dim={block_dim}: {count}/{total} ({:.0}%) {:.0}s    ",
                    count as f64 / total as f64 * 100.0, t0.elapsed().as_secs_f64());
            }

            ((i, j), val)
        })
        .collect();

    let mut data = vec![0.0f64; block_dim * block_dim];
    for ((r, c), v) in entries {
        data[r * block_dim + c] = v;
        data[c * block_dim + r] = v;
    }

    if block_dim > 500 {
        eprintln!("\r    d={d} dim={block_dim}: built in {:.1}s                              ",
            t0.elapsed().as_secs_f64());
    }

    (data, block_dim)
}

/// Analyze all GCD blocks for a given N.
///
/// Strategy:
///   - Skip blocks with dim < 2 (trivial)
///   - Skip d=1 if dim > max_dim_limit (would need 107 GB for N=120K)
///   - Large blocks: GPU if fits in VRAM, else CPU
///   - Small blocks: parallel via rayon (CPU eigenvalues_all)
///
/// Returns sorted block results.
pub fn analyze_all_blocks(
    n: usize,
    vram_mb: usize,
    max_block_dim: usize,
) -> Vec<BlockResult> {
    let t0 = Instant::now();

    // Determine which d values to process
    let mut blocks_to_process: Vec<(usize, usize)> = Vec::new(); // (d, dim)
    for d in 1..=n {
        let dim = n / d;
        if dim < 2 { break; } // all subsequent d values will also have dim < 2
        if dim > max_block_dim {
            eprintln!("    ⚠ Skipping d={d} (dim={dim} > max_block_dim={max_block_dim})");
            continue;
        }
        blocks_to_process.push((d, dim));
    }

    // Sort largest first for better progress visibility
    blocks_to_process.sort_by(|a, b| b.1.cmp(&a.1));

    let total_blocks = blocks_to_process.len();
    eprintln!("    Processing {total_blocks} GCD blocks (max dim = {})",
        blocks_to_process.first().map(|b| b.1).unwrap_or(0));

    // Threshold for GPU vs CPU
    let max_gpu_dim = if vram_mb > 0 {
        // NoVec needs ~dim² × 8 bytes for matrix + ~10% workspace
        // 24 GB VRAM → ~54K dim for NoVec
        ((vram_mb as f64 * 1024.0 * 1024.0 * 0.85 / 8.0).sqrt() as usize).min(54000)
    } else {
        0
    };

    let sequential_threshold = 5000; // blocks above this run sequentially

    // Split into large (sequential) and small (parallel) groups
    let (large, small): (Vec<_>, Vec<_>) = blocks_to_process.into_iter()
        .partition(|&(_, dim)| dim > sequential_threshold);

    let mut results = Vec::with_capacity(total_blocks);

    // Process LARGE blocks sequentially
    for (i, (d, dim)) in large.iter().enumerate() {
        eprintln!("    [{}/{}] d={d} dim={dim} → building submatrix...",
            i + 1, large.len());

        let (data, actual_dim) = build_block_matrix(n, *d);
        if actual_dim < 2 { continue; }

        let mem_gb = (actual_dim * actual_dim * 8) as f64 / (1024.0 * 1024.0 * 1024.0);

        // Choose GPU or CPU
        let (lmin, secs, mode) = if actual_dim <= max_gpu_dim {
            eprintln!("    [{}/{}] d={d} dim={actual_dim} ({mem_gb:.2} GB) → GPU cuSOLVER...",
                i + 1, large.len());
            match crate::gpu::gpu_lambda_min(&data, actual_dim) {
                Ok((lmin, time)) => (lmin, time, "GPU"),
                Err(e) => {
                    eprintln!("    ⚠ GPU failed ({e}), falling back to CPU...");
                    let (lmin, time) = crate::cpu::full_matrix_lambda_min(&data, actual_dim);
                    (lmin, time, "CPU_fallback")
                }
            }
        } else {
            eprintln!("    [{}/{}] d={d} dim={actual_dim} ({mem_gb:.2} GB) → CPU dsyevr(λ_min)...",
                i + 1, large.len());
            let (lmin, time) = crate::cpu::full_matrix_lambda_min(&data, actual_dim);
            (lmin, time, "CPU")
        };

        eprintln!("    [{}/{}] d={d} dim={actual_dim} → λ_min = {lmin:.6e} ({secs:.1}s {mode})",
            i + 1, large.len());

        results.push(BlockResult {
            gcd_class: *d, dim: actual_dim, lambda_min: lmin,
            compute_secs: secs, mode,
        });
        drop(data);
    }

    // Process SMALL blocks in parallel via rayon
    if !small.is_empty() {
        eprintln!("    Processing {} small blocks in parallel...", small.len());
        let done = AtomicUsize::new(0);
        let small_results: Vec<BlockResult> = small.par_iter()
            .filter_map(|&(d, _dim)| {
                let (data, actual_dim) = build_block_matrix(n, d);
                if actual_dim < 2 { return None; }

                let t = Instant::now();
                let evals = crate::cpu::eigenvalues_all(&data, actual_dim);
                let secs = t.elapsed().as_secs_f64();
                if evals.is_empty() { return None; }
                let lmin = evals[0];

                let count = done.fetch_add(1, Ordering::Relaxed);
                if small.len() > 100 && count % (small.len() / 10).max(1) == 0 {
                    eprint!("\r    small blocks: {count}/{} ({:.0}%)    ",
                        small.len(), count as f64 / small.len() as f64 * 100.0);
                }

                Some(BlockResult {
                    gcd_class: d, dim: actual_dim, lambda_min: lmin,
                    compute_secs: secs, mode: "CPU_parallel",
                })
            })
            .collect();

        if small.len() > 100 { eprintln!(); }
        results.extend(small_results);
    }

    results.sort_by_key(|r| r.gcd_class);

    let elapsed = t0.elapsed().as_secs_f64();
    let global_lmin = results.iter().map(|r| r.lambda_min).fold(f64::INFINITY, f64::min);
    eprintln!("    Block analysis complete: {} blocks in {elapsed:.1}s", results.len());
    eprintln!("    Global block λ_min = {global_lmin:.6e}");

    results
}
