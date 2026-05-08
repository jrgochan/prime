//! Gram matrix construction with cache-aware loading.
//!
//! The Lean `vasyuninGramMatrix N` uses indices 1..N (via Fin N, i.val+1).
//! Cached .bin files from cathedral-utils use indices 2..N.
//! We bridge this by building the full 1..N matrix:
//!   - Load cached (N-1)×(N-1) block for indices 2..N
//!   - Compute the k=1 row/column fresh
//!
//! Supports four cache formats (priority order):
//!   0. HPDF (gram_N{n}.h5) — HDF5 with DD hi+lo (~31 digits) ★ PREFERRED
//!   1. DD cache (dd_gram_N{n}_mpfr256.bin) — double-double hi+lo
//!   2. OOC cache (ooc_gram_N{n}_p{p}.bin) — CATHOOC row-major f64
//!   3. Legacy MPFR cache (gram_N{n}_mpfr{p}.bin) — f64

use cathedral_utils::cache;
use cathedral_utils::gram;
use cathedral_utils::hpdf;
use cathedral_utils::ooc;
use rayon::prelude::*;
use std::io::{Read, Seek, SeekFrom};

/// Our augmented Gram matrix with indices 1..N.
/// `data[i * dim + j]` = G(i+1, j+1) for i,j = 0..dim-1.
pub struct FullGram {
    pub data: Vec<f64>,
    pub dim: usize,   // = N (the Lean dimension)
    pub max_n: usize,  // = N
}

impl FullGram {
    /// Extract the N×N upper-left submatrix (indices 1..n) as contiguous dense.
    /// Uses parallel row-wise copy for large N.
    pub fn submatrix(&self, n: usize) -> Vec<f64> {
        assert!(n <= self.dim);
        if n == self.dim {
            return self.data.clone();
        }
        let stride = self.dim;
        let src = &self.data;
        let mut sub = vec![0.0f64; n * n];
        // Parallel row copy — each row is independent
        sub.par_chunks_mut(n)
            .enumerate()
            .for_each(|(i, row)| {
                row.copy_from_slice(&src[i * stride..i * stride + n]);
            });
        sub
    }

    /// Single entry G(j,k) where j,k are 1-based.
    #[inline]
    pub fn entry(&self, j: usize, k: usize) -> f64 {
        self.data[(j - 1) * self.dim + (k - 1)]
    }

    /// Stride-based quadratic form vᵀ G[0..n, 0..n] v without extracting submatrix.
    /// Parallelized over rows — each row computes v[i] * (G[i,:] · v) independently.
    pub fn quad_form_strided(&self, v: &[f64], n: usize) -> f64 {
        let stride = self.dim;
        let data = &self.data;
        (0..n).into_par_iter()
            .map(|i| {
                let row_start = i * stride;
                let mut row_sum = 0.0f64;
                for j in 0..n {
                    row_sum += v[j] * data[row_start + j];
                }
                v[i] * row_sum
            })
            .sum()
    }

    /// Stride-based matrix-vector multiply: out = G[0..n, 0..n] * x.
    /// Parallelized over rows — each output element is independent.
    pub fn matvec_strided(&self, x: &[f64], out: &mut [f64], n: usize) {
        let stride = self.dim;
        let data = &self.data;
        out[..n].par_iter_mut()
            .enumerate()
            .for_each(|(i, out_i)| {
                let row_start = i * stride;
                let mut sum = 0.0f64;
                for j in 0..n {
                    sum += data[row_start + j] * x[j];
                }
                *out_i = sum;
            });
    }
}

/// Build or load the full Gram matrix for indices 1..max_n.
pub fn build_or_load_gram(max_n: usize, _mu: &[i8]) -> FullGram {
    let dim = max_n;
    let inner_dim = max_n - 1; // cached matrix dimension (indices 2..max_n)

    // Try loading from binary cache (indices 2..max_n)
    let cached = try_load_cached(max_n);

    // Allocate full matrix (indices 1..max_n)
    eprintln!("  ▸ Allocating {dim}×{dim} matrix ({:.1} GB)...",
        dim as f64 * dim as f64 * 8.0 / 1e9);
    let mut data = vec![0.0f64; dim * dim];

    if let Some(cached_data) = cached {
        eprintln!("  ▸ Augmenting cached {}×{} matrix with k=1 row/column...",
            inner_dim, inner_dim);
        let src_stride = if cached_data.len() == inner_dim * inner_dim {
            inner_dim
        } else {
            // Data from OOC submatrix extraction may have different stride
            inner_dim
        };
        // Copy cached block into positions [1..dim-1, 1..dim-1] using fast memcpy
        for i in 0..inner_dim {
            let dst_start = (i + 1) * dim + 1;
            let src_start = i * src_stride;
            data[dst_start..dst_start + inner_dim]
                .copy_from_slice(&cached_data[src_start..src_start + inner_dim]);
        }
        // Explicitly drop to free ~12GB before computing k=1 row
        drop(cached_data);
        eprintln!("  ✓ Cache data copied and freed");
    } else {
        eprintln!("  ▸ Building {dim}×{dim} Gram matrix from scratch (parallel)...");
        // Build the inner block (indices 2..max_n) in parallel
        let pairs: Vec<(usize, usize)> = (0..inner_dim)
            .flat_map(|i| (i..inner_dim).map(move |j| (i, j)))
            .collect();
        let entries: Vec<(usize, usize, f64)> = pairs.par_iter()
            .map(|&(i, j)| {
                let val = gram::gram_entry_f64(i + 2, j + 2);
                (i, j, val)
            })
            .collect();
        for (i, j, val) in entries {
            data[(i + 1) * dim + (j + 1)] = val;
            data[(j + 1) * dim + (i + 1)] = val;
        }
    }

    // Compute k=1 row/column fresh (always needed)
    eprintln!("  ▸ Computing k=1 row ({dim} entries)...");
    let row1: Vec<f64> = (0..dim).into_par_iter()
        .map(|j| gram::gram_entry_f64(1, j + 1))
        .collect();

    for j in 0..dim {
        data[j] = row1[j];         // row 0 (k=1)
        data[j * dim] = row1[j];   // col 0 (k=1), symmetric
    }

    FullGram { data, dim, max_n }
}

/// Try loading a cached Gram matrix from the binary cache.
/// Returns the (N-1)×(N-1) matrix data as a Vec<f64>.
fn try_load_cached(max_n: usize) -> Option<Vec<f64>> {
    let inner_dim = max_n - 1;

    // ── 0. HPDF files (preferred — DD hi+lo for ~31 digits) ──────────
    let hpdf_dir = cache::cache_dir().join("hpdf");
    // Try exact match first, then larger files
    for &n in &[max_n, 55440, 40000, 20000, 10000, 5000, 3000, 2000, 1000] {
        if n < max_n { continue; }
        let path = hpdf_dir.join(format!("gram_N{n}.h5"));
        if path.exists() {
            eprintln!("  ▸ Found HPDF: {} (N={n})", path.display());
            if let Ok(reader) = hpdf::HpdfReader::open(&path) {
                if reader.max_n() >= max_n {
                    let has_dd = reader.has_dd();
                    if has_dd {
                        eprintln!("    DD lo-word data available → loading hi+lo (~31 digits)");
                        if let Ok((hi, lo)) = reader.read_gram_full_dd() {
                            // Merge hi + lo into single f64 vector
                            // This captures the full DD precision in the most significant
                            // 15.9 digits, with the lo word correcting the last few bits.
                            let merged: Vec<f64> = hi.iter().zip(lo.iter())
                                .map(|(&h, &l)| h + l)
                                .collect();
                            // Extract submatrix if needed
                            let src_dim = reader.dim();
                            if src_dim == inner_dim {
                                return Some(merged);
                            } else if src_dim > inner_dim {
                                let mut sub = vec![0.0f64; inner_dim * inner_dim];
                                for i in 0..inner_dim {
                                    sub[i * inner_dim..(i + 1) * inner_dim]
                                        .copy_from_slice(&merged[i * src_dim..i * src_dim + inner_dim]);
                                }
                                return Some(sub);
                            }
                        }
                    } else {
                        eprintln!("    No DD data — loading hi only (~16 digits)");
                        if let Ok(data) = reader.read_gram_full() {
                            let src_dim = reader.dim();
                            if src_dim == inner_dim {
                                return Some(data);
                            } else if src_dim > inner_dim {
                                let mut sub = vec![0.0f64; inner_dim * inner_dim];
                                for i in 0..inner_dim {
                                    sub[i * inner_dim..(i + 1) * inner_dim]
                                        .copy_from_slice(&data[i * src_dim..i * src_dim + inner_dim]);
                                }
                                return Some(sub);
                            }
                        }
                    }
                }
            }
        }
    }

    // ── 1. OOC p512 cache ────────────────────────────────────────────
    let ooc_dir = cache::cache_dir().join("gram");
    let ooc_path = ooc::gram_path(&ooc_dir, max_n, 512);
    if ooc_path.exists() {
        eprintln!("  ▸ Found OOC p512 cache: {} ({:.1} GB)", ooc_path.display(),
            std::fs::metadata(&ooc_path).map(|m| m.len() as f64 / 1e9).unwrap_or(0.0));
        if let Some(data) = try_load_ooc(&ooc_path, inner_dim) {
            return Some(data);
        }
    }
    // Try larger OOC caches and extract submatrix (p512 preferred)
    for &big_n in &[55440usize, 40000, 20000, 10000] {
        if big_n <= max_n { continue; }
        for &prec in &[512u32, 256] {
            let path = ooc::gram_path(&ooc_dir, big_n, prec);
            if path.exists() {
                eprintln!("  ▸ Found OOC p{prec} cache N={big_n}, extracting {inner_dim}×{inner_dim} submatrix...");
                if let Some(data) = try_load_ooc_submatrix(&path, inner_dim) {
                    return Some(data);
                }
            }
        }
    }

    // ── 2. DD cache (merge hi+lo) ────────────────────────────────────
    let dd_path = cache::dd_gram_cache_path(max_n, 256);
    if dd_path.exists() {
        eprintln!("  ▸ Found DD cache: {} ({:.1} GB)", dd_path.display(),
            std::fs::metadata(&dd_path).map(|m| m.len() as f64 / 1e9).unwrap_or(0.0));
        if let Some((hi, lo, dim)) = cache::load_dd_gram(&dd_path) {
            if dim == inner_dim {
                eprintln!("    Merging hi+lo (~31 digits)");
                let merged: Vec<f64> = hi.iter().zip(lo.iter())
                    .map(|(&h, &l)| h + l)
                    .collect();
                return Some(merged);
            }
        }
    }

    // 3. Try standard f64 cache
    let f64_path = cache::gram_cache_path(max_n, 0);
    if f64_path.exists() {
        eprintln!("  ▸ Found f64 cache: {}", f64_path.display());
        if let Some(gm) = cache::load_gram(&f64_path) {
            if gm.max_dim == inner_dim {
                return Some(gm.data);
            }
        }
    }

    // 4. Try various MPFR precisions
    for prec in [256, 512, 1024, 64, 106] {
        let path = cache::gram_cache_path(max_n, prec);
        if path.exists() {
            eprintln!("  ▸ Found MPFR-{prec} cache: {}", path.display());
            if let Some(gm) = cache::load_gram(&path) {
                if gm.max_dim == inner_dim {
                    return Some(gm.data);
                }
            }
        }
    }

    // ── 5. Larger DD caches (merge hi+lo) ────────────────────────────
    for &big_n in &[40000, 20000, 10000, 5000, 3000, 2000, 1000] {
        if big_n <= max_n { continue; }
        let dd_path = cache::dd_gram_cache_path(big_n, 256);
        if dd_path.exists() {
            eprintln!("  ▸ Found larger DD cache N={big_n}, extracting submatrix...");
            if let Some((hi, lo, dim)) = cache::load_dd_gram(&dd_path) {
                if dim >= inner_dim {
                    let mut sub = vec![0.0f64; inner_dim * inner_dim];
                    for i in 0..inner_dim {
                        for j in 0..inner_dim {
                            sub[i * inner_dim + j] = hi[i * dim + j] + lo[i * dim + j];
                        }
                    }
                    return Some(sub);
                }
            }
        }
    }

    None
}

/// Load an OOC matrix that exactly matches the requested dimension.
fn try_load_ooc(path: &std::path::Path, inner_dim: usize) -> Option<Vec<f64>> {
    let mut f = std::fs::File::open(path).ok()?;
    let header = ooc::read_header(&mut f).ok()??;

    if header.dim != inner_dim {
        return None;
    }

    eprintln!("  ▸ Loading OOC: {}×{} (p={})...", header.dim, header.dim, header.precision);
    let count = inner_dim * inner_dim;
    let mut data = vec![0.0f64; count];
    let bytes = unsafe {
        std::slice::from_raw_parts_mut(data.as_mut_ptr() as *mut u8, count * 8)
    };
    f.read_exact(bytes).ok()?;

    Some(data)
}

/// Extract a submatrix from a larger OOC file using streaming (row-by-row) reads.
/// Only reads the rows/columns we need — avoids loading the full 24.6GB into RAM.
fn try_load_ooc_submatrix(path: &std::path::Path, inner_dim: usize) -> Option<Vec<f64>> {
    let mut f = std::fs::File::open(path).ok()?;
    let header = ooc::read_header(&mut f).ok()??;

    if header.dim < inner_dim {
        return None;
    }

    let src_dim = header.dim;
    eprintln!("  ▸ Streaming OOC submatrix: {inner_dim}×{inner_dim} from {src_dim}×{src_dim} (p={})...",
        header.precision);

    let mut data = vec![0.0f64; inner_dim * inner_dim];
    let row_bytes = inner_dim * 8; // bytes we need per row
    let src_row_bytes = src_dim * 8; // bytes per row in source

    for i in 0..inner_dim {
        // Seek to start of row i in the source file
        let offset = ooc::HEADER_SIZE + (i as u64) * (src_row_bytes as u64);
        f.seek(SeekFrom::Start(offset)).ok()?;

        // Read only inner_dim entries from this row
        let dst = &mut data[i * inner_dim..(i + 1) * inner_dim];
        let bytes = unsafe {
            std::slice::from_raw_parts_mut(dst.as_mut_ptr() as *mut u8, row_bytes)
        };
        f.read_exact(bytes).ok()?;

        if i % 5000 == 0 && i > 0 {
            eprintln!("    Row {i}/{inner_dim} ({:.1}%)", i as f64 / inner_dim as f64 * 100.0);
        }
    }

    eprintln!("  ✓ OOC submatrix loaded ({:.1} GB)", inner_dim as f64 * inner_dim as f64 * 8.0 / 1e9);
    Some(data)
}

/// Compute the mean vector b where b_k = (ln(k) + 1 - γ) / k.
pub fn mean_vector(n: usize) -> Vec<f64> {
    let gamma = 0.5772156649015329; // Euler-Mascheroni
    (0..n).map(|i| {
        let k = (i + 1) as f64;
        (k.ln() + 1.0 - gamma) / k
    }).collect()
}

/// Compute the log-cutoff witness vector:
/// v_k = -μ(k) * (1 - ln(k)/ln(N)) for k = 1..N.
pub fn witness_vector(n: usize, mu: &[i8]) -> Vec<f64> {
    let ln_n = (n as f64).ln();
    (0..n).map(|i| {
        let k = i + 1;
        if k >= mu.len() || mu[k] == 0 { return 0.0; }
        let weight = 1.0 - (k as f64).ln() / ln_n;
        -(mu[k] as f64) * weight
    }).collect()
}
