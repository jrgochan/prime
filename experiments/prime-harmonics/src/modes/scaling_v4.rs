//! # Scaling Mode v4: Incremental Cholesky from OOC mmap'd Gram matrix
//!
//! Reads from the OOC binary (built by `ooc-probe build`) via memory-mapped I/O.
//! The OS page cache handles what stays in RAM — we never load the full matrix.
//!
//! KEY TRICK: G is symmetric, so G(i, new_row) = G(new_row, i).
//! Row new_row is contiguous in the row-major layout → cache-friendly!
//! We read row new_row and extract the first new_row entries.
//!
//! Memory: O(N²/2) for L triangle + O(N) for z, w vectors.
//! Disk: OOC binary stays on NVMe, accessed via mmap.
//!
//! THE MONOTONICITY THEOREM (Gemini, May 30 2026):
//!   d²(N) = d²(N-1) - y²_new
//!   Since y²_new ≥ 0, d²_opt is STRICTLY MONOTONICALLY DECREASING.
//!
//! Created: May 30, 2026 — The OOC Engine

extern crate libc;

use std::io::Read;
use std::path::{Path, PathBuf};
use std::time::Instant;

const EULER_GAMMA: f64 = 0.5772156649015329;

// OOC file format constants (must match ooc_probe.rs)
const OOC_MAGIC: u64 = 0x434F4F4854_414300;
const OOC_VERSION: u32 = 1;
const OOC_HEADER_SIZE: usize = 48; // 8+4+4+4+4+8+8+8 = 48 bytes with padding

/// BD b-vector entry: b_k = (ln(k) + 1 - γ) / k
fn b_entry(k: usize) -> f64 {
    ((k as f64).ln() + 1.0 - EULER_GAMMA) / k as f64
}

/// Memory-mapped OOC Gram matrix for zero-copy access.
struct MmapGram {
    data: *const f64,
    dim: usize,
    _mmap_len: usize,
}

impl MmapGram {
    fn open(path: &Path) -> Result<Self, String> {
        use std::os::unix::io::AsRawFd;

        let file = std::fs::File::open(path)
            .map_err(|e| format!("Cannot open {}: {}", path.display(), e))?;
        let file_len = file.metadata()
            .map_err(|e| format!("Cannot stat: {e}"))?
            .len() as usize;

        // Read and validate header
        let mut f = std::io::BufReader::new(&file);
        let mut buf8 = [0u8; 8];
        let mut buf4 = [0u8; 4];

        f.read_exact(&mut buf8).map_err(|e| format!("Read error: {e}"))?;
        let magic = u64::from_le_bytes(buf8);
        if magic != OOC_MAGIC {
            return Err(format!("Invalid magic: {magic:#x} != {OOC_MAGIC:#x}"));
        }

        f.read_exact(&mut buf4).map_err(|e| format!("Read error: {e}"))?;
        let version = u32::from_le_bytes(buf4);
        if version != OOC_VERSION {
            return Err(format!("Unknown version: {version}"));
        }

        f.read_exact(&mut buf4).map_err(|e| format!("Read error: {e}"))?;
        let max_n = u32::from_le_bytes(buf4) as usize;

        f.read_exact(&mut buf4).map_err(|e| format!("Read error: {e}"))?;
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
                libc::MAP_PRIVATE,
                fd,
                0,
            )
        };

        if ptr == libc::MAP_FAILED {
            return Err(format!("mmap failed: {}", std::io::Error::last_os_error()));
        }

        // Advise random access (we'll be jumping around for columns)
        unsafe {
            libc::madvise(ptr, file_len, libc::MADV_RANDOM);
        }

        let data_ptr = unsafe { (ptr as *const u8).add(OOC_HEADER_SIZE) as *const f64 };

        // Keep fd alive
        std::mem::forget(file);

        Ok(MmapGram {
            data: data_ptr,
            dim,
            _mmap_len: file_len,
        })
    }

    /// Get entry G(row, col) — zero copy from mmap
    #[inline(always)]
    fn get(&self, row: usize, col: usize) -> f64 {
        unsafe { *self.data.add(row * self.dim + col) }
    }

    /// Get a contiguous row slice — zero copy
    #[inline]
    fn row(&self, i: usize) -> &[f64] {
        unsafe { std::slice::from_raw_parts(self.data.add(i * self.dim), self.dim) }
    }
}

unsafe impl Send for MmapGram {}
unsafe impl Sync for MmapGram {}

pub fn run(ooc_path: &str, max_n: usize) {
    eprintln!();
    eprintln!("{}", "═".repeat(70));
    eprintln!("SCALING v4 — Incremental Cholesky from OOC mmap'd Gram");
    eprintln!("{}", "═".repeat(70));
    eprintln!();

    let path = PathBuf::from(ooc_path);
    if !path.exists() {
        // Try to find it in the default OOC cache
        let alt = PathBuf::from(format!("/mnt/d/cathedral-cache/ooc_gram_N{max_n}_p256.bin"));
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
    let effective_max = max_n;
    let max_dim = effective_max - 1;

    eprintln!("Incremental sweep: N = 2 to {effective_max}");
    eprintln!("L triangle: {} entries ({:.1} GB)",
        max_dim * (max_dim + 1) / 2,
        max_dim as f64 * (max_dim + 1) as f64 / 2.0 * 8.0 / 1e9);
    eprintln!("OOC source: {}", path.display());
    eprintln!();

    // ═══ Open mmap'd Gram ═══
    let t_mmap = Instant::now();
    let gram = MmapGram::open(path).expect("Failed to open OOC Gram matrix");
    eprintln!("  ✓ mmap'd in {:.2}s (dim={})", t_mmap.elapsed().as_secs_f64(), gram.dim);

    if gram.dim < max_dim {
        eprintln!("  ⚠ OOC dim {} < requested dim {}, capping", gram.dim, max_dim);
    }
    let max_dim = max_dim.min(gram.dim);
    let effective_max = max_dim + 1;

    // ═══ Precompute number theory ═══
    let t_nt = Instant::now();

    let mut is_prime = vec![true; effective_max + 1];
    is_prime[0] = false;
    if effective_max >= 1 { is_prime[1] = false; }
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
    eprintln!("  Allocating L triangle: {tri_size} entries ({:.1} GB)...",
        tri_size as f64 * 8.0 / 1e9);
    let mut l_data: Vec<f64> = vec![0.0; tri_size];
    let mut z: Vec<f64> = Vec::with_capacity(max_dim);
    let mut norm_z_sq: f64 = 0.0;
    eprintln!("  Allocated. Starting sweep...");
    eprintln!();

    #[inline(always)]
    fn l_idx(row: usize, col: usize) -> usize {
        row * (row + 1) / 2 + col
    }

    println!("# Dense d²_opt — Incremental Cholesky v4 (OOC mmap)");
    println!("# Source: {}", path.display());
    println!("# Monotonicity: d²(N) = d²(N-1) - y²_new");
    println!("N\td2_opt\tln_N\td2_lnN\td2_ln2N\ty2_new\tis_prime\tis_hcn\ttau\tclass");

    let t_sweep = Instant::now();

    for dim in 1..=max_dim {
        let n = dim + 1;
        let new_row = dim - 1;

        if new_row == 0 {
            let g00 = gram.get(0, 0);
            let s = g00.sqrt();
            l_data[l_idx(0, 0)] = s;
            let z0 = b_full[0] / s;
            z.push(z0);
            norm_z_sq = z0 * z0;
        } else {
            // KEY TRICK: Read row `new_row` from mmap (contiguous, cache-friendly!)
            // G is symmetric, so row[i] = G(new_row, i) = G(i, new_row)
            let gram_row = gram.row(new_row);

            // Forward solve L * w = g
            let mut w: Vec<f64> = Vec::with_capacity(new_row);
            for i in 0..new_row {
                let l_row_start = l_idx(i, 0);
                let mut sum = gram_row[i]; // G(new_row, i) = G(i, new_row)
                for j in 0..i {
                    sum -= l_data[l_row_start + j] * w[j];
                }
                w.push(sum / l_data[l_idx(i, i)]);
            }

            // s = sqrt(G(new_row, new_row) - ‖w‖²)
            let w_norm_sq: f64 = w.iter().map(|x| x * x).sum();
            let diag = gram_row[new_row];
            let s_sq = diag - w_norm_sq;

            if s_sq <= 0.0 {
                eprintln!("  ⚠ N={n}: Cholesky breakdown (s²={s_sq:.2e}), skipping");
                for j in 0..new_row {
                    l_data[l_idx(new_row, j)] = w[j];
                }
                l_data[l_idx(new_row, new_row)] = 1e-15;
                z.push(0.0);
                continue;
            }
            let s = s_sq.sqrt();

            // Store new row of L
            let l_row_start = l_idx(new_row, 0);
            l_data[l_row_start..l_row_start + new_row].copy_from_slice(&w);
            l_data[l_idx(new_row, new_row)] = s;

            // z_new
            let wt_z: f64 = w.iter().zip(z.iter()).map(|(wi, zi)| wi * zi).sum();
            let z_new = (b_full[new_row] - wt_z) / s;

            z.push(z_new);
            norm_z_sq += z_new * z_new;
        }

        let d2 = 1.0 - norm_z_sq;
        let ln_n = (n as f64).ln();
        let d2_ln = d2 * ln_n;
        let d2_ln2 = d2 * ln_n * ln_n;
        let y2_new = if z.is_empty() { 0.0 } else { z.last().unwrap().powi(2) };
        let p = if is_prime[n] { 1 } else { 0 };
        let h = if is_hcn[n] { 1 } else { 0 };
        let t = tau[n];
        let class = if is_hcn[n] { "HCN" }
            else if is_prime[n] { "prime" }
            else { "comp" };

        println!("{n}\t{d2:.12e}\t{ln_n:.6}\t{d2_ln:.10}\t{d2_ln2:.10}\t{y2_new:.12e}\t{p}\t{h}\t{t}\t{class}");

        if dim % 5000 == 0 || (dim <= 100 && dim % 10 == 0) {
            let elapsed = t_sweep.elapsed().as_secs_f64();
            let rate = dim as f64 / elapsed;
            // True ETA uses cubic scaling: remaining ∝ (max³ - dim³)/(dim³) × elapsed
            let frac_done = (dim as f64).powi(3) / (max_dim as f64).powi(3);
            let eta = if frac_done > 0.001 { elapsed / frac_done * (1.0 - frac_done) } else { 0.0 };
            let hrs = eta / 3600.0;
            eprintln!("  N={n} (dim={dim}) d²={d2:.8e} y²={y2_new:.4e} | {elapsed:.0}s ({rate:.1} N/s) ETA {hrs:.1}h [{:.1}% work done]",
                frac_done * 100.0);
        }
    }

    let total = t_sweep.elapsed().as_secs_f64();
    let rate = max_dim as f64 / total;
    eprintln!();
    eprintln!("Done: {} values in {:.1}s = {:.2}h ({rate:.0} N/s)", max_dim, total, total/3600.0);
    eprintln!("Memory: L triangle = {} entries ({:.1} GB)",
        tri_size, tri_size as f64 * 8.0 / 1e9);
}
