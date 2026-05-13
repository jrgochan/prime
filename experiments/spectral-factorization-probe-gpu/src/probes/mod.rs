//! GPU-accelerated Cathedral hypothesis probes for semiprime factorization.
//!
//! Each probe lives in its own submodule for easy iteration.
//! Shared infrastructure (Gram cache, HPDF loading, utilities) lives here.

pub mod h1;
pub mod h2;
pub mod h3;
pub mod h4;
pub mod h5;
pub mod h6;
pub mod ssh_probe;

// Re-export probe entry points
pub use h1::h1_gcd_stratum_eigenvector;
pub use h2::h2_optimal_weight_structure;
pub use h3::h3_vasyunin_cotangent_anomaly;
pub use h4::h4_mobius_local_structure;
pub use h5::h5_composite_anchoring;
pub use h6::h6_quadratic_form_probe;

use crate::gpu;
use rayon::prelude::*;
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};

// ═══════════════════════════════════════════════════════════════
// GRAM CACHE — HPDF loading + block-algorithm fallback
// ═══════════════════════════════════════════════════════════════

/// Available HPDF files, sorted by max_n ascending for efficient lookup.
struct HpdfIndex {
    /// (max_n, path) sorted ascending by max_n
    files: Vec<(usize, PathBuf)>,
}

impl HpdfIndex {
    fn scan(dir: &Path) -> Option<Self> {
        let mut files = Vec::new();
        for entry in std::fs::read_dir(dir).ok()?.flatten() {
            let name = entry.file_name().to_string_lossy().to_string();
            if let Some(n_str) = name.strip_prefix("gram_N").and_then(|s| s.strip_suffix(".h5")) {
                if let Ok(n) = n_str.parse::<usize>() {
                    files.push((n, entry.path()));
                }
            }
        }
        if files.is_empty() { return None; }
        files.sort_by_key(|&(n, _)| n);
        Some(HpdfIndex { files })
    }

    /// Find the smallest file with max_n >= needed.
    fn best_file_for(&self, needed_max_n: usize) -> Option<&(usize, PathBuf)> {
        self.files.iter().find(|(n, _)| *n >= needed_max_n)
    }

    fn max_n(&self) -> usize {
        self.files.last().map(|(n, _)| *n).unwrap_or(0)
    }
}

/// Thread-safe cache for Gram matrices + eigendecompositions.
/// Avoids redundant builds when multiple probes need the same dimension.
pub struct GramCache {
    cache: Mutex<HashMap<usize, Arc<GramEigenResult>>>,
    /// Flat Gram matrices (no eigen) for H6-style quadratic form work
    gram_only_cache: Mutex<HashMap<usize, Arc<Vec<f64>>>>,
    hpdf_index: Option<HpdfIndex>,
}

pub struct GramEigenResult {
    pub gram: Vec<f64>,
    pub eigenvalues: Vec<f64>,
    pub ground_state: Vec<f64>,
    pub build_time: f64,
    pub eigen_time: f64,
}

impl GramCache {
    /// Create a new cache, scanning for available HPDF files.
    pub fn new(hpdf_dir: Option<&Path>) -> Self {
        let hpdf_index = hpdf_dir
            .filter(|d| d.exists())
            .and_then(HpdfIndex::scan);

        if let Some(ref idx) = hpdf_index {
            eprintln!("  [GramCache] HPDF: {} files, max N={}", idx.files.len(), idx.max_n());
        } else if hpdf_dir.is_some() {
            eprintln!("  [GramCache] No HPDF files found");
        }

        GramCache {
            cache: Mutex::new(HashMap::new()),
            gram_only_cache: Mutex::new(HashMap::new()),
            hpdf_index,
        }
    }

    /// Get or build a Gram matrix + eigendecomposition for the given dimension.
    pub fn get_eigen(&self, dim: usize) -> Option<Arc<GramEigenResult>> {
        // Check cache first
        {
            let cache = self.cache.lock().unwrap();
            if let Some(result) = cache.get(&dim) {
                eprintln!("    [Cache] Gram {}×{} eigendecomp HIT", dim, dim);
                return Some(Arc::clone(result));
            }
        }

        // Build it
        let result = self.build_eigen(dim)?;
        let arc = Arc::new(result);
        self.cache.lock().unwrap().insert(dim, Arc::clone(&arc));
        Some(arc)
    }

    /// Get or build a raw Gram matrix (no eigendecomp) for quadratic form work.
    pub fn get_gram(&self, dim: usize) -> Arc<Vec<f64>> {
        // Check gram-only cache
        {
            let cache = self.gram_only_cache.lock().unwrap();
            if let Some(gram) = cache.get(&dim) {
                eprintln!("    [Cache] Gram {}×{} matrix HIT", dim, dim);
                return Arc::clone(gram);
            }
        }
        // Check eigen cache (it has the gram too)
        {
            let cache = self.cache.lock().unwrap();
            if let Some(result) = cache.get(&dim) {
                return Arc::new(result.gram.clone());
            }
        }

        // Build it
        let t0 = std::time::Instant::now();
        let gram = self.build_gram(dim);
        let t = t0.elapsed().as_secs_f64();
        eprintln!("    [Gram] Built {}×{} in {:.3}s", dim, dim, t);
        let arc = Arc::new(gram);
        self.gram_only_cache.lock().unwrap().insert(dim, Arc::clone(&arc));
        arc
    }

    fn build_eigen(&self, dim: usize) -> Option<GramEigenResult> {
        let t0 = std::time::Instant::now();
        let gram_mat = self.build_gram(dim);
        let t_build = t0.elapsed().as_secs_f64();

        eprintln!("    [GPU] Eigendecomp {}×{} on GPU...", dim, dim);
        match gpu::gpu_eigen(&gram_mat, dim) {
            Ok(eig) => {
                let total = t0.elapsed().as_secs_f64();
                eprintln!(
                    "    [GPU] Done: build={:.3}s, eigen={:.3}s, total={:.3}s, λ_min={:.6e}",
                    t_build, eig.gpu_time_secs, total, eig.eigenvalues[0]
                );
                let ground: Vec<f64> = (0..dim).map(|i| eig.eigenvectors[i]).collect();
                Some(GramEigenResult {
                    gram: gram_mat, eigenvalues: eig.eigenvalues, ground_state: ground,
                    build_time: t_build, eigen_time: eig.gpu_time_secs,
                })
            }
            Err(e) => {
                eprintln!("    [GPU] Eigen failed: {}, falling back to CPU", e);
                let eig = cathedral_utils::eigen::eigen_f64(&gram_mat, dim);
                if eig.eigenvalues.is_empty() { return None; }
                Some(GramEigenResult {
                    gram: gram_mat, eigenvalues: eig.eigenvalues,
                    ground_state: eig.eigenvectors[0].clone(),
                    build_time: t_build, eigen_time: t0.elapsed().as_secs_f64() - t_build,
                })
            }
        }
    }

    /// Build Gram matrix: try HPDF first, then CPU Kahan fallback.
    fn build_gram(&self, dim: usize) -> Vec<f64> {
        let max_n = dim + 1; // Gram indices are 2..=dim+1, so max_n = dim+1

        // Try HPDF loading
        #[cfg(feature = "hpdf")]
        if let Some(gram) = self.try_load_hpdf(dim, max_n) {
            return gram;
        }

        // Fallback: CPU build with f64 Kahan (same as before, but parallel)
        eprintln!("    [CPU] Building {}×{} Gram matrix (f64 Kahan)...", dim, dim);
        let entries: Vec<(usize, usize, f64)> = (0..dim)
            .into_par_iter()
            .flat_map(|i| {
                (i..dim).map(move |j| {
                    let g = cathedral_utils::gram::gram_entry_f64(i + 2, j + 2);
                    (i, j, g)
                }).collect::<Vec<_>>()
            })
            .collect();
        let mut mat = vec![0.0f64; dim * dim];
        for (i, j, g) in entries { mat[i * dim + j] = g; mat[j * dim + i] = g; }
        mat
    }

    /// Try to load from an HPDF file: full load + in-memory submatrix extraction.
    ///
    /// The upstream `read_gram_submatrix` does entry-by-entry HDF5 reads (O(dim²) I/O),
    /// so we always load the full file matrix and extract in memory instead.
    #[cfg(feature = "hpdf")]
    fn try_load_hpdf(&self, dim: usize, max_n: usize) -> Option<Vec<f64>> {
        use cathedral_utils::hpdf::reader::HpdfReader;

        let idx = self.hpdf_index.as_ref()?;
        let (file_n, path) = idx.best_file_for(max_n)?;

        eprintln!("    [HPDF] Loading from gram_N{}.h5 (need {}×{}) ...", file_n, dim, dim);
        let t0 = std::time::Instant::now();
        let reader = HpdfReader::open(path).ok()?;
        let file_dim = reader.dim();

        if file_dim < dim {
            eprintln!("    [HPDF] File dim {} < needed {}, skipping", file_dim, dim);
            return None;
        }

        // Load full matrix (single bulk I/O read)
        let full_mat = reader.read_gram_full().ok()?;

        if file_dim == dim {
            eprintln!("    [HPDF] Loaded full {}×{} in {:.3}s", dim, dim, t0.elapsed().as_secs_f64());
            return Some(full_mat);
        }

        // Extract upper-left dim×dim submatrix in memory
        let mut sub = vec![0.0f64; dim * dim];
        for i in 0..dim {
            sub[i * dim..i * dim + dim].copy_from_slice(&full_mat[i * file_dim..i * file_dim + dim]);
        }
        eprintln!(
            "    [HPDF] Extracted {}×{} from {}×{} in {:.3}s",
            dim, dim, file_dim, file_dim, t0.elapsed().as_secs_f64()
        );
        Some(sub)
    }
}

// ═══════════════════════════════════════════════════════════════
// UTILITY FUNCTIONS — shared across probes
// ═══════════════════════════════════════════════════════════════

pub fn vasyunin_sum(m: u64, n: u64) -> f64 {
    if m <= 1 { return 0.0; }
    let mut sum = 0.0f64;
    for j in 1..m {
        let frac = ((j * (n % m)) % m) as f64 / m as f64;
        let cot = 1.0 / (std::f64::consts::PI * j as f64 / m as f64).tan();
        sum += frac * cot;
    }
    sum
}

pub fn next_non_factor_prime(start: u64, n: u64) -> u64 {
    let mut p = start + 2;
    loop {
        if is_prime_u64(p) && n % p != 0 { return p; }
        p += if p % 2 == 0 { 1 } else { 2 };
        if p > start + 1000 { return start + 1; }
    }
}

pub fn is_prime_u64(n: u64) -> bool {
    if n < 2 { return false; } if n < 4 { return true; }
    if n % 2 == 0 || n % 3 == 0 { return false; }
    let mut i = 5u64;
    while i * i <= n { if n % i == 0 || n % (i + 2) == 0 { return false; } i += 6; }
    true
}

pub fn percentile(data: &[f64], pct: f64) -> f64 {
    if data.is_empty() { return 0.0; }
    let mut sorted = data.to_vec();
    sorted.sort_by(|a, b| a.partial_cmp(b).unwrap());
    let idx = ((pct / 100.0) * (sorted.len() - 1) as f64) as usize;
    sorted[idx.min(sorted.len() - 1)]
}
