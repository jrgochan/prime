//! Cathedral RL Environment: The Gram Form as a Gymnasium
//!
//! The environment state is a weight vector v ∈ ℝ^{N-1}.
//! The action space is perturbations δv to the weight vector.
//! The reward is the negative of the quadratic form distance:
//!   reward = -(1 - 2bᵀv + vᵀGv)
//!
//! An optimal policy minimizes d² = 1 - 2bᵀv + vᵀGv.
//! The Cathedral proves: if d² → 0 along a subsequence, then RH is true.
//!
//! ## Matrix Loading Strategy
//!
//! Three sources, checked in order of preference:
//!   1. HPDF (.h5)  — highest precision, with embedded metadata
//!   2. Binary cache (.bin) — fast load, CATHEDRA format
//!   3. Recompute  — fallback, O(N²) time

use cathedral_utils::arith;
#[cfg(feature = "hpdf")]
use cathedral_utils::hpdf;
#[cfg(feature = "gpu")]
use cathedral_utils::gpu;
use cathedral_utils::gram;
use cathedral_utils::mertens;
use serde::{Deserialize, Serialize};
#[cfg(feature = "hpdf")]
use std::path::PathBuf;
#[cfg(feature = "gpu")]
use std::sync::Arc;

/// The state of the RL environment at a given matrix dimension N.
pub struct CathedralEnv {
    /// Matrix dimension N (Gram matrix is (N-1)×(N-1))
    pub n: usize,
    /// Gram matrix in row-major order, dim = (N-1)×(N-1)
    pub gram_data: Vec<f64>,
    /// DD lo-word matrix (from HPDF). When present, G[i,j] ≈ gram_data[i,j] + gram_lo[i,j]
    /// giving ~31 decimal digits of precision per entry.
    pub gram_lo: Option<Vec<f64>>,
    /// Mean vector b (vasyuninMeanEntry values)
    pub b_vec: Vec<f64>,
    /// Current weight vector v
    pub v: Vec<f64>,
    /// Möbius table
    pub mu: Vec<i8>,
    /// Dimension of the vector space = N-1
    pub dim: usize,
    /// Step counter
    pub step: usize,
    /// Maximum steps per episode
    pub max_steps: usize,
    /// Best d² seen so far this episode
    pub best_d2: f64,
    /// The baseline d² from the standard log-cutoff witness
    pub baseline_d2: f64,
    /// Source of the Gram matrix data
    pub source: String,
    /// GPU bilinear engine (if GPU is enabled and initialized)
    #[cfg(feature = "gpu")]
    pub gpu_engine: Option<Arc<gpu::bilinear::BilinearEngine>>,
    /// GPU chunked matvec state for out-of-core CG (matrices larger than VRAM).
    /// Used when BilinearEngine can't fit the full matrix.
    #[cfg(feature = "gpu")]
    pub gpu_matvec: Option<gpu::matvec::MatvecState>,
}

/// Observation returned to the agent
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Observation {
    pub d2: f64,
    pub vtgv: f64,
    pub btv: f64,
    pub step: usize,
    pub n: usize,
    pub best_d2: f64,
    pub improvement_over_baseline: f64,
}

/// Step result
#[derive(Clone, Debug)]
pub struct StepResult {
    pub obs: Observation,
    pub reward: f64,
    pub done: bool,
}

impl CathedralEnv {
    /// Create a new environment at dimension N.
    ///
    /// Attempts to load the Gram matrix from cached sources:
    ///   1. HPDF (.h5) file in experiments/cache/hpdf/
    ///   2. Binary cache (.bin) in experiments/cache/
    ///   3. Recompute from scratch (expensive for large N)
    pub fn new(n: usize, max_steps: usize) -> Self {
        let dim = n - 1;
        let mu = arith::mobius_table(n + 1);

        let t0 = std::time::Instant::now();
        let (gram_data, gram_lo, source) = load_gram_matrix(n, dim);
        let load_secs = t0.elapsed().as_secs_f64();
        let mb = (gram_data.len() * 8) as f64 / (1024.0 * 1024.0);
        eprintln!("  ✓ Gram matrix loaded: {source} ({mb:.1} MB, {load_secs:.2}s)");
        if gram_lo.is_some() {
            eprintln!("  ✓ DD lo-words loaded (~31-digit precision available)");
        }

        // Build mean vector b
        // b_i = (log(i+1) + 1 - γ) / (i+1) for the BD basis
        let gamma = 0.5772156649015329;
        let b_vec: Vec<f64> = (0..dim)
            .map(|i| {
                let k = (i + 2) as f64;
                (k.ln() + 1.0 - gamma) / k
            })
            .collect();

        // Start with the standard log-cutoff witness
        let v = mertens::witness_vector(n, &mu);

        let mut env = Self {
            n,
            gram_data,
            gram_lo,
            b_vec,
            v,
            mu,
            dim,
            step: 0,
            max_steps,
            best_d2: f64::INFINITY,
            baseline_d2: 0.0,
            source,
            #[cfg(feature = "gpu")]
            gpu_engine: None,
            #[cfg(feature = "gpu")]
            gpu_matvec: None,
        };

        // Compute baseline d²
        env.baseline_d2 = env.compute_d2();
        env.best_d2 = env.baseline_d2;
        env
    }

    /// Initialize GPU acceleration. Call after construction if --gpu is set.
    ///
    /// For matrices that fit in VRAM, uses the full BilinearEngine (fastest).
    /// For matrices too large for VRAM, falls back to MatvecState which
    /// streams the matrix through GPU in row-chunks — still much faster than
    /// CPU, just requires PCIe transfers per CG step.
    #[cfg(feature = "gpu")]
    pub fn init_gpu(&mut self) -> Result<(), String> {
        if let Some(info) = gpu::detect() {
            eprintln!("  GPU detected: {} ({} MB VRAM)", info.name, info.vram_mb);

            // Try full-matrix BilinearEngine first
            if gpu::bilinear::BilinearEngine::can_fit(self.dim, info.vram_mb) {
                let engine = gpu::bilinear::BilinearEngine::new(&self.gram_data, self.dim)?;
                self.gpu_engine = Some(Arc::new(engine));
                eprintln!("  \x1b[32m✓\x1b[0m GPU BilinearEngine initialized (dim={})", self.dim);
                return Ok(());
            }

            // Matrix too large for full upload — use chunked MatvecState
            let matrix_gb = (self.dim * self.dim * 8) as f64 / 1e9;
            let vram_gb = info.vram_mb as f64 / 1024.0;
            eprintln!("  Matrix {:.1} GB > {:.1} GB VRAM — using chunked GPU matvec", matrix_gb, vram_gb);

            // Calculate chunk size: use 80% of VRAM for the chunk buffer
            let usable_bytes = (info.vram_mb as usize * 1024 * 1024) * 80 / 100;
            let x_bytes = self.dim * 8;
            let avail = usable_bytes.saturating_sub(x_bytes + self.dim * 8); // subtract x and y_chunk
            let chunk_rows = avail / (self.dim * 8);
            let chunk_rows = chunk_rows.min(self.dim).max(1);
            let n_chunks = (self.dim + chunk_rows - 1) / chunk_rows;

            eprintln!("  Chunk config: {} rows/chunk, {} chunks per matvec", chunk_rows, n_chunks);

            let state = gpu::matvec::MatvecState::new(self.dim, chunk_rows)?;
            self.gpu_matvec = Some(state);
            eprintln!("  \x1b[32m✓\x1b[0m GPU MatvecState initialized (dim={}, chunked)", self.dim);
            Ok(())
        } else {
            Err("No GPU detected".to_string())
        }
    }

    /// Create environment from a specific HPDF file path.
    #[cfg(feature = "hpdf")]
    pub fn from_hpdf(path: &std::path::Path, max_steps: usize) -> Result<Self, String> {
        let t0 = std::time::Instant::now();
        let reader = hpdf::HpdfReader::open(path)
            .map_err(|e| format!("Failed to open HPDF: {e}"))?;

        let n = reader.max_n();
        let dim = reader.dim();
        let gram_data = reader.read_gram_full()
            .map_err(|e| format!("Failed to read Gram: {e}"))?;

        let mu = reader.read_mobius()
            .unwrap_or_else(|_| arith::mobius_table(n + 1));

        let b_vec = reader.read_b_vector()
            .unwrap_or_else(|_| {
                let gamma = 0.5772156649015329;
                (0..dim).map(|i| {
                    let k = (i + 2) as f64;
                    (k.ln() + 1.0 - gamma) / k
                }).collect()
            });

        let v = mertens::witness_vector(n, &mu);
        let source = format!("HPDF: {}", path.display());
        let load_secs = t0.elapsed().as_secs_f64();
        let mb = (gram_data.len() * 8) as f64 / (1024.0 * 1024.0);
        eprintln!("  ✓ Gram matrix loaded: {source} ({mb:.1} MB, {load_secs:.2}s)");

        // Load DD lo-words if available
        let gram_lo = reader.read_gram_lo_full()
            .ok()
            .flatten();
        if gram_lo.is_some() {
            eprintln!("  ✓ DD lo-words loaded (~31-digit precision available)");
        }

        let mut env = Self {
            n, gram_data, gram_lo, b_vec, v, mu, dim,
            step: 0, max_steps,
            best_d2: f64::INFINITY,
            baseline_d2: 0.0,
            source,
            #[cfg(feature = "gpu")]
            gpu_engine: None,
            #[cfg(feature = "gpu")]
            gpu_matvec: None,
        };

        env.baseline_d2 = env.compute_d2();
        env.best_d2 = env.baseline_d2;
        Ok(env)
    }

    /// Create environment from a binary cache file path.
    pub fn from_cache(path: &std::path::Path, max_steps: usize) -> Result<Self, String> {
        use cathedral_utils::cache;

        let gram = cache::load_gram(path)
            .ok_or_else(|| format!("Failed to load cache: {}", path.display()))?;

        let n = gram.max_n;
        let dim = gram.max_dim;
        let gram_data = gram.data;
        let mu = arith::mobius_table(n + 1);

        let gamma = 0.5772156649015329;
        let b_vec: Vec<f64> = (0..dim)
            .map(|i| {
                let k = (i + 2) as f64;
                (k.ln() + 1.0 - gamma) / k
            })
            .collect();

        let v = mertens::witness_vector(n, &mu);
        let source = format!("Binary: {}", path.display());
        let mb = (gram_data.len() * 8) as f64 / (1024.0 * 1024.0);
        eprintln!("  ✓ Gram matrix loaded: {source} ({mb:.1} MB)");

        let mut env = Self {
            n, gram_data, gram_lo: None, b_vec, v, mu, dim,
            step: 0, max_steps,
            best_d2: f64::INFINITY,
            baseline_d2: 0.0,
            source,
            #[cfg(feature = "gpu")]
            gpu_engine: None,
            #[cfg(feature = "gpu")]
            gpu_matvec: None,
        };

        env.baseline_d2 = env.compute_d2();
        env.best_d2 = env.baseline_d2;
        Ok(env)
    }

    /// Reset the environment (start new episode with standard witness)
    pub fn reset(&mut self) -> Observation {
        self.v = mertens::witness_vector(self.n, &self.mu);
        self.step = 0;
        self.best_d2 = self.baseline_d2;
        self.observe()
    }

    /// Reset with a random perturbation of the standard witness
    pub fn reset_perturbed(&mut self, noise_scale: f64) -> Observation {
        let baseline = mertens::witness_vector(self.n, &self.mu);
        let mut rng = rand::thread_rng();
        use rand_distr::{Distribution, Normal};
        let normal = Normal::new(0.0, noise_scale).unwrap();
        self.v = baseline
            .iter()
            .map(|&vi| vi + normal.sample(&mut rng))
            .collect();
        self.step = 0;
        self.best_d2 = self.compute_d2();
        self.observe()
    }

    /// Take a step: apply perturbation δv to the current weight vector
    pub fn step_action(&mut self, delta_v: &[f64]) -> StepResult {
        assert_eq!(delta_v.len(), self.dim);

        // Apply perturbation
        for (vi, &dv) in self.v.iter_mut().zip(delta_v.iter()) {
            *vi += dv;
        }

        self.step += 1;

        let d2 = self.compute_d2();
        if d2 < self.best_d2 {
            self.best_d2 = d2;
        }

        let reward = self.compute_reward(d2);
        let done = self.step >= self.max_steps;

        StepResult {
            obs: self.observe(),
            reward,
            done,
        }
    }

    /// Apply a coordinate-wise action: perturb a single index
    pub fn step_coordinate(&mut self, index: usize, delta: f64) -> StepResult {
        assert!(index < self.dim);
        self.v[index] += delta;
        self.step += 1;

        let d2 = self.compute_d2();
        if d2 < self.best_d2 {
            self.best_d2 = d2;
        }

        let reward = self.compute_reward(d2);
        let done = self.step >= self.max_steps;

        StepResult {
            obs: self.observe(),
            reward,
            done,
        }
    }

    /// Compute d² = 1 - 2bᵀv + vᵀGv
    pub fn compute_d2(&self) -> f64 {
        let btv = self.compute_btv();
        let vtgv = self.compute_vtgv();
        1.0 - 2.0 * btv + vtgv
    }

    /// Compute bᵀv
    pub fn compute_btv(&self) -> f64 {
        self.b_vec
            .iter()
            .zip(self.v.iter())
            .map(|(&b, &v)| b * v)
            .sum()
    }

    /// Compute vᵀGv — dispatches to GPU if available
    pub fn compute_vtgv(&self) -> f64 {
        #[cfg(feature = "gpu")]
        if let Some(ref engine) = self.gpu_engine {
            return engine.bilinear(&self.v).unwrap_or_else(|e| {
                eprintln!("  GPU bilinear failed: {e}, falling back to CPU");
                self.compute_vtgv_cpu()
            });
        }
        self.compute_vtgv_cpu()
    }

    /// CPU fallback for vᵀGv — exploits symmetry of G.
    ///
    /// Since G is symmetric, vᵀGv = Σ_i G[i,i]·v[i]² + 2·Σ_{i<j} G[i,j]·v[i]·v[j].
    /// This halves the number of multiplications compared to full O(N²) iteration.
    fn compute_vtgv_cpu(&self) -> f64 {
        let dim = self.dim;
        let mut result = 0.0f64;

        // Diagonal contribution: Σ G[i,i] · v[i]²
        for i in 0..dim {
            result += self.gram_data[i * dim + i] * self.v[i] * self.v[i];
        }

        // Off-diagonal contribution (upper triangle only): 2 · Σ_{i<j} G[i,j] · v[i] · v[j]
        for i in 0..dim {
            let vi = self.v[i];
            let row_offset = i * dim;
            let mut off_diag = 0.0f64;
            for j in (i + 1)..dim {
                off_diag += self.gram_data[row_offset + j] * self.v[j];
            }
            result += 2.0 * vi * off_diag;
        }

        result
    }

    /// Compute the gradient ∇_v d² = -2b + 2Gv
    pub fn gradient_d2(&self) -> Vec<f64> {
        let gv = self.matvec(&self.v);
        let mut grad = vec![0.0f64; self.dim];
        for i in 0..self.dim {
            grad[i] = -2.0 * self.b_vec[i] + 2.0 * gv[i];
        }
        grad
    }

    /// Compute Gx (matrix-vector product) — dispatches to GPU if available.
    /// This is the hot path for CG iteration: each CG step requires one matvec.
    pub fn matvec(&self, x: &[f64]) -> Vec<f64> {
        let mut result = vec![0.0f64; self.dim];
        self.matvec_into(x, &mut result);
        result
    }

    /// Zero-allocation matvec: compute y = Gx, writing into a pre-allocated buffer.
    ///
    /// This avoids the per-step Vec allocation in the CG hot path. At N=5040,
    /// each CG step saves a ~40 KB allocation; over 5000 steps that's ~200 MB
    /// of allocation churn eliminated.
    ///
    /// For the GPU path, we still get a Vec from cuBLAS and copy into `out`.
    /// The CPU path writes directly into `out` with zero allocation.
    pub fn matvec_into(&self, x: &[f64], out: &mut [f64]) {
        debug_assert_eq!(x.len(), self.dim);
        debug_assert_eq!(out.len(), self.dim);

        // Path 1: Full-matrix BilinearEngine (fastest)
        #[cfg(feature = "gpu")]
        if let Some(ref engine) = self.gpu_engine {
            match engine.matvec(x) {
                Ok(result) => {
                    out.copy_from_slice(&result);
                    return;
                }
                Err(e) => {
                    eprintln!("  GPU matvec failed: {e}, falling back to CPU");
                }
            }
        }

        // Path 2: Chunked GPU matvec (out-of-core)
        #[cfg(feature = "gpu")]
        if let Some(ref state) = self.gpu_matvec {
            state.upload_x(x);
            let dim = self.dim;
            let chunk_rows = state.chunk_rows;
            let mut row_offset = 0;
            while row_offset < dim {
                let rows_this = (chunk_rows).min(dim - row_offset);
                let chunk_start = row_offset * dim;
                let chunk_end = chunk_start + rows_this * dim;
                state.matvec_chunk(
                    &self.gram_data[chunk_start..chunk_end],
                    rows_this,
                    &mut out[row_offset..row_offset + rows_this],
                );
                row_offset += rows_this;
            }
            return;
        }

        self.matvec_cpu_into(x, out);
    }

    /// CPU matvec: y = Gx exploiting symmetry G = Gᵀ.
    ///
    /// For a symmetric N×N matrix, the standard row-major matvec reads N²
    /// elements. By processing only the upper triangle, we halve memory
    /// bandwidth — each off-diagonal element G[i,j] contributes to both
    /// y[i] += G[i,j]·x[j] and y[j] += G[i,j]·x[i] simultaneously.
    ///
    /// This is the critical hot path for CG: each CG step calls matvec once.
    /// At N=5040 (dim=5039), each full matvec reads ~194 MB; the symmetric
    /// version reads ~97 MB, and the inner loop is auto-vectorized by LLVM.
    fn matvec_cpu(&self, x: &[f64]) -> Vec<f64> {
        let dim = self.dim;
        let mut result = vec![0.0f64; dim];
        self.matvec_cpu_kernel(x, &mut result);
        result
    }

    /// Zero-allocation CPU matvec: y = Gx, writing into `out`.
    fn matvec_cpu_into(&self, x: &[f64], out: &mut [f64]) {
        // Zero the output buffer before accumulating
        for v in out.iter_mut() { *v = 0.0; }
        self.matvec_cpu_kernel(x, out);
    }

    /// Core matvec kernel using Rayon parallel row-wise dot products.
    ///
    /// Each row i computes result[i] = Σ_j G[i,j] * x[j] independently,
    /// which is trivially parallel. On a 12-core Apple Silicon, this gives
    /// ~6-10x speedup over the single-threaded symmetric kernel despite
    /// reading 2x more data (full matrix instead of upper triangle).
    ///
    /// Uses Kahan compensated summation for each row to maintain precision.
    #[inline(always)]
    fn matvec_cpu_kernel(&self, x: &[f64], result: &mut [f64]) {
        use rayon::prelude::*;
        let dim = self.dim;
        let gram = &self.gram_data;

        // Parallel row-wise dot products
        result.par_iter_mut().enumerate().for_each(|(i, yi)| {
            let row_start = i * dim;
            let row = &gram[row_start..row_start + dim];

            // Kahan compensated dot product for precision
            let mut sum = 0.0f64;
            let mut comp = 0.0f64;
            for j in 0..dim {
                let y_val = row[j] * x[j] - comp;
                let t = sum + y_val;
                comp = (t - sum) - y_val;
                sum = t;
            }
            *yi = sum;
        });
    }

    /// Extract the diagonal of the Gram matrix: diag[i] = G[i,i].
    /// Used for Jacobi preconditioning in CG (M⁻¹ = diag(1/G_ii)).
    pub fn gram_diagonal(&self) -> Vec<f64> {
        (0..self.dim)
            .map(|i| self.gram_data[i * self.dim + i])
            .collect()
    }

    fn observe(&self) -> Observation {
        let vtgv = self.compute_vtgv();
        let btv = self.compute_btv();
        let d2 = 1.0 - 2.0 * btv + vtgv;
        Observation {
            d2,
            vtgv,
            btv,
            step: self.step,
            n: self.n,
            best_d2: self.best_d2,
            improvement_over_baseline: self.baseline_d2 - d2,
        }
    }

    fn compute_reward(&self, d2: f64) -> f64 {
        // Reward = negative distance (agent wants to minimize d²)
        // Plus bonus for beating the baseline
        let base_reward = -d2;
        let bonus = if d2 < self.baseline_d2 {
            (self.baseline_d2 - d2) * 10.0
        } else {
            0.0
        };
        base_reward + bonus
    }
}

// ═══════════════════════════════════════════════════════════════
// MATRIX LOADING — cascaded source selection
// ═══════════════════════════════════════════════════════════════

/// Try to load a Gram matrix from the best available source.
/// Returns (data, source_description).
fn load_gram_matrix(n: usize, _dim: usize) -> (Vec<f64>, Option<Vec<f64>>, String) {
    // 1. Try HPDF (.h5) file — includes DD lo-words when available
    #[cfg(feature = "hpdf")]
    {
        let hpdf_path = hpdf_cache_path(n);
        if hpdf_path.exists() {
            eprintln!("  Loading HPDF: {}...", hpdf_path.display());
            if let Ok(reader) = hpdf::HpdfReader::open(&hpdf_path) {
                if let Ok(data) = reader.read_gram_full() {
                    let lo = reader.read_gram_lo_full().ok().flatten();
                    return (data, lo, format!("HPDF({})", hpdf_path.file_name().unwrap().to_string_lossy()));
                }
            }
            eprintln!("  ⚠ HPDF load failed, trying binary cache...");
        }
    }

    // 2. Try binary cache (.bin) — try f64 first, then any precision
    {
        use cathedral_utils::cache;
        let cache_path = cache::gram_cache_path(n, 0);
        if cache_path.exists() {
            eprintln!("  Loading binary cache: {}...", cache_path.display());
            if let Some(gram) = cache::load_gram(&cache_path) {
                return (gram.data, None, format!("cache(f64, N={})", n));
            }
        }

        // Try mpfr precisions in preference order
        for prec in &[64u32, 128, 256, 512, 106, 1024] {
            let cache_path = cache::gram_cache_path(n, *prec);
            if cache_path.exists() {
                eprintln!("  Loading binary cache: {}...", cache_path.display());
                if let Some(gram) = cache::load_gram(&cache_path) {
                    return (gram.data, None, format!("cache(mpfr{}, N={})", prec, n));
                }
            }
        }
    }

    // 3. Recompute from scratch
    let dim = n - 1;
    eprintln!("  Building Gram matrix G_{n} ({dim}×{dim}) from scratch...");
    let data = build_gram_f64(dim);
    (data, None, format!("recomputed(f64, N={n})"))
}

/// Get the HPDF cache path for a given N.
#[cfg(feature = "hpdf")]
fn hpdf_cache_path(n: usize) -> PathBuf {
    let manifest = env!("CARGO_MANIFEST_DIR");
    PathBuf::from(manifest)
        .parent()
        .unwrap()
        .join("cache")
        .join("hpdf")
        .join(format!("gram_N{n}.h5"))
}

/// Build the (N-1)×(N-1) Gram matrix using f64 entries.
/// Indices 2..=N, stored as 0-indexed: gram[i][j] = G(i+2, j+2)
fn build_gram_f64(dim: usize) -> Vec<f64> {
    use rayon::prelude::*;

    let mut data = vec![0.0f64; dim * dim];

    // Compute upper triangle in parallel (symmetric matrix)
    let entries: Vec<(usize, usize, f64)> = (0..dim)
        .into_par_iter()
        .flat_map(|i| {
            (i..dim)
                .map(|j| {
                    let val = gram::gram_entry_f64(i + 2, j + 2);
                    (i, j, val)
                })
                .collect::<Vec<_>>()
        })
        .collect();

    for (i, j, val) in entries {
        data[i * dim + j] = val;
        if i != j {
            data[j * dim + i] = val;
        }
    }

    data
}
