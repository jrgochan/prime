//! # GPU Bilinear Form Engine
//!
//! GPU-accelerated computation of bilinear forms for the Möbius Microscope:
//!
//!   vᵀGv  — the Nyman-Beurling distance (core RH metric)
//!   U(N)  — Σ μ(j)μ(k) G(j,k)              (untapered ground state)
//!   L(N)  — Σ μ(j)μ(k) ln(j) G(j,k)        (linear taper)
//!   Q(N)  — Σ μ(j)μ(k) ln(j)ln(k) G(j,k)   (quadratic taper)
//!
//! All four can be computed from a single GPU matrix-vector multiply:
//!   1. Upload Gram matrix G (dim×dim) to GPU
//!   2. Compute  y = G @ v       via cuBLAS dsymv
//!   3. Compute  vᵀGv = vᵀ · y   via cuBLAS ddot
//!   4. Compute  U = μᵀ · Gμ     (with taper weight vectors)
//!
//! For large N where the matrix doesn't fit in VRAM, we use chunk-based
//! processing via the existing MatvecState infrastructure.

use std::ffi::c_int;
use std::time::Instant;
use super::ffi;

/// Results from GPU bilinear form computation.
#[derive(Debug, Clone)]
pub struct BilinearResult {
    /// vᵀGv computed on GPU (the core Nyman-Beurling metric)
    pub vtgv: f64,
    /// U(N) = Σ μ(j)μ(k) G(j,k)
    pub u_sum: f64,
    /// L(N) = Σ μ(j)μ(k) ln(j) G(j,k)
    pub l_sum: f64,
    /// Q(N) = Σ μ(j)μ(k) ln(j)ln(k) G(j,k)
    pub q_sum: f64,
    /// GPU wall time in seconds
    pub gpu_secs: f64,
}

/// GPU state for bilinear form computation.
/// Manages GPU memory for the Gram matrix and weight vectors.
pub struct BilinearEngine {
    blas_handle: ffi::CublasHandle,
    /// Device pointer to the full symmetric Gram matrix (column-major for cuBLAS)
    d_gram: *mut f64,
    /// Device pointer for intermediate vector (y = G @ x)
    d_y: *mut f64,
    /// Dimension of the matrix
    dim: usize,
}

impl BilinearEngine {
    /// Create engine and upload the Gram matrix to GPU.
    ///
    /// `gram_data` must be a full `dim × dim` symmetric matrix in row-major order.
    /// (Symmetric matrices are identical in row-major and column-major.)
    ///
    /// VRAM usage: dim² × 8 (matrix) + dim × 8 (scratch vector)
    pub fn new(gram_data: &[f64], dim: usize) -> Result<Self, String> {
        if gram_data.len() != dim * dim {
            return Err(format!(
                "gram_data length {} != dim²={}", gram_data.len(), dim * dim
            ));
        }

        let matrix_bytes = dim * dim * 8;
        let vec_bytes = dim * 8;

        unsafe {
            let start = Instant::now();

            let mut blas_handle: ffi::CublasHandle = std::ptr::null_mut();
            let s = ffi::cublasCreate_v2(&mut blas_handle);
            if s != 0 {
                return Err(format!("cublasCreate failed: {}", s));
            }

            let mut d_gram: *mut f64 = std::ptr::null_mut();
            let mut d_y: *mut f64 = std::ptr::null_mut();

            let s1 = ffi::cudaMalloc(&mut d_gram, matrix_bytes);
            let s2 = ffi::cudaMalloc(&mut d_y, vec_bytes);
            if s1 != 0 || s2 != 0 {
                ffi::cublasDestroy_v2(blas_handle);
                return Err(format!("cudaMalloc failed: {},{}", s1, s2));
            }

            // Upload Gram matrix
            ffi::cudaMemcpy(
                d_gram, gram_data.as_ptr(),
                matrix_bytes, ffi::MEMCPY_HOST_TO_DEVICE,
            );

            let upload_secs = start.elapsed().as_secs_f64();
            eprintln!("    GPU Gram upload: {:.2}s ({:.0} MB)",
                upload_secs, matrix_bytes as f64 / 1e6);

            Ok(BilinearEngine { blas_handle, d_gram, d_y, dim })
        }
    }

    /// Compute the bilinear form xᵀGx for a given weight vector x.
    ///
    /// Uses cuBLAS dsymv (symmetric matrix-vector multiply):
    ///   y = G @ x      (dsymv: O(dim²) FLOPs, massively parallel)
    ///   result = xᵀ · y (ddot: O(dim) FLOPs)
    pub fn bilinear(&self, x: &[f64]) -> Result<f64, String> {
        if x.len() != self.dim {
            return Err(format!("x length {} != dim {}", x.len(), self.dim));
        }

        let dim = self.dim;
        let n = dim as c_int;
        let alpha = 1.0f64;
        let beta = 0.0f64;

        unsafe {
            // Upload x vector
            let mut d_x: *mut f64 = std::ptr::null_mut();
            let s = ffi::cudaMalloc(&mut d_x, dim * 8);
            if s != 0 { return Err(format!("cudaMalloc for x failed: {}", s)); }
            ffi::cudaMemcpy(d_x, x.as_ptr(), dim * 8, ffi::MEMCPY_HOST_TO_DEVICE);

            // y = G @ x  (dsymv — symmetric, so row/col major doesn't matter)
            // cuBLAS: y = alpha * A * x + beta * y
            // We use column-major lower triangle
            ffi::cublasDgemv_v2(
                self.blas_handle,
                ffi::OP_N,
                n, n,
                &alpha,
                self.d_gram, n,
                d_x, 1,
                &beta,
                self.d_y, 1,
            );

            // result = xᵀ · y
            let mut result = 0.0f64;
            ffi::cublasDdot_v2(
                self.blas_handle,
                n,
                d_x, 1,
                self.d_y, 1,
                &mut result,
            );

            ffi::cudaFree(d_x);
            Ok(result)
        }
    }

    /// Compute the full taper decomposition on GPU.
    ///
    /// Given the weight vector v and the Möbius/log vectors, this computes:
    ///   vᵀGv  = v ᵀ @ G @ v
    ///   U     = μ ᵀ @ G @ μ
    ///   L     = (μ·ln) ᵀ @ G @ μ    (asymmetric: uses ln(j) not ln(k))
    ///   Q     = (μ·ln) ᵀ @ G @ (μ·ln)
    ///
    /// Uses Lean-aligned k=1..N basis:
    ///   μ[i] = μ(i+1), ln[i] = ln(i+1)
    ///
    /// This requires 4 GPU matvec + 4 dot products = 4 × O(dim²).
    /// On RTX 4090 at dim=55K, each matvec takes ~0.1s ⟹ total ~0.4s.
    pub fn compute_taper(
        &self,
        weights: &[f64],      // v[i] = witness weight for index i+1 (k=1..N)
        mu: &[i8],            // μ[k] for k=0..N, we use k=1..N
    ) -> Result<BilinearResult, String> {
        let dim = self.dim;
        let start = Instant::now();

        // Build the four weight vectors for the bilinear forms (k=1..N):
        // w_v[i]   = weights[i]                           (witness vector)
        // w_mu[i]  = μ(i+1)                               (Möbius vector)
        // w_ml[i]  = μ(i+1) · ln(i+1)                    (log-weighted Möbius)

        let mut w_mu = vec![0.0f64; dim];
        let mut w_ml = vec![0.0f64; dim];  // μ·ln

        for i in 0..dim {
            let k = i + 1;  // k=1..N (Lean-aligned)
            if k < mu.len() {
                let mu_k = mu[k] as f64;
                let ln_k = (k as f64).ln();
                w_mu[i] = mu_k;
                w_ml[i] = mu_k * ln_k;
            }
        }

        // 1. vᵀGv
        let vtgv = self.bilinear(weights)?;
        eprintln!("    GPU vᵀGv = {:.10}  ({:.3}s)", vtgv, start.elapsed().as_secs_f64());

        // 2. U = μᵀGμ
        let u_sum = self.bilinear(&w_mu)?;
        eprintln!("    GPU U    = {:.10}  ({:.3}s)", u_sum, start.elapsed().as_secs_f64());

        // 3. L = (μ·ln)ᵀ G μ  — NOTE: L is asymmetric in j/k, but due to
        //    symmetry of G, we have Σ μj·μk·lnj·G(j,k) = (μ·ln)ᵀ·G·μ.
        //    This is NOT the same as μᵀ·G·(μ·ln) which gives Σ μj·μk·lnk·G(j,k).
        //    By symmetry of G, both give the same value (relabeling j↔k).
        //    So L = (μ·ln)ᵀ · G · μ = μᵀ · G · (μ·ln)
        let l_sum = self.bilinear_asymmetric(&w_ml, &w_mu)?;
        eprintln!("    GPU L    = {:.10}  ({:.3}s)", l_sum, start.elapsed().as_secs_f64());

        // 4. Q = (μ·ln)ᵀ G (μ·ln)
        let q_sum = self.bilinear(&w_ml)?;
        eprintln!("    GPU Q    = {:.10}  ({:.3}s)", q_sum, start.elapsed().as_secs_f64());

        let gpu_secs = start.elapsed().as_secs_f64();
        eprintln!("    GPU taper total: {:.3}s", gpu_secs);

        Ok(BilinearResult { vtgv, u_sum, l_sum, q_sum, gpu_secs })
    }

    /// Compute the asymmetric bilinear form xᵀGy.
    ///
    /// Uses: y_temp = G @ y, then result = xᵀ · y_temp
    pub fn bilinear_asymmetric(&self, x: &[f64], y: &[f64]) -> Result<f64, String> {
        if x.len() != self.dim || y.len() != self.dim {
            return Err(format!("vector length mismatch"));
        }

        let dim = self.dim;
        let n = dim as c_int;
        let alpha = 1.0f64;
        let beta = 0.0f64;

        unsafe {
            let mut d_x: *mut f64 = std::ptr::null_mut();
            let mut d_y_vec: *mut f64 = std::ptr::null_mut();
            let s1 = ffi::cudaMalloc(&mut d_x, dim * 8);
            let s2 = ffi::cudaMalloc(&mut d_y_vec, dim * 8);
            if s1 != 0 || s2 != 0 {
                return Err(format!("cudaMalloc failed"));
            }

            ffi::cudaMemcpy(d_x, x.as_ptr(), dim * 8, ffi::MEMCPY_HOST_TO_DEVICE);
            ffi::cudaMemcpy(d_y_vec, y.as_ptr(), dim * 8, ffi::MEMCPY_HOST_TO_DEVICE);

            // temp = G @ y
            ffi::cublasDgemv_v2(
                self.blas_handle,
                ffi::OP_N,
                n, n,
                &alpha,
                self.d_gram, n,
                d_y_vec, 1,
                &beta,
                self.d_y, 1,  // reuse scratch buffer
            );

            // result = xᵀ · temp
            let mut result = 0.0f64;
            ffi::cublasDdot_v2(
                self.blas_handle,
                n,
                d_x, 1,
                self.d_y, 1,
                &mut result,
            );

            ffi::cudaFree(d_x);
            ffi::cudaFree(d_y_vec);
            Ok(result)
        }
    }

    /// Compute the matrix-vector product y = G @ x on the GPU.
    ///
    /// Uses cuBLAS dgemv. This is the GPU-accelerated equivalent of the
    /// CPU matvec in CathedralEnv, enabling GPU-accelerated CG iteration.
    pub fn matvec(&self, x: &[f64]) -> Result<Vec<f64>, String> {
        if x.len() != self.dim {
            return Err(format!("x length {} != dim {}", x.len(), self.dim));
        }

        let dim = self.dim;
        let n = dim as c_int;
        let alpha = 1.0f64;
        let beta = 0.0f64;

        unsafe {
            // Upload x vector
            let mut d_x: *mut f64 = std::ptr::null_mut();
            let s = ffi::cudaMalloc(&mut d_x, dim * 8);
            if s != 0 { return Err(format!("cudaMalloc for x failed: {}", s)); }
            ffi::cudaMemcpy(d_x, x.as_ptr(), dim * 8, ffi::MEMCPY_HOST_TO_DEVICE);

            // y = G @ x
            ffi::cublasDgemv_v2(
                self.blas_handle,
                ffi::OP_N,
                n, n,
                &alpha,
                self.d_gram, n,
                d_x, 1,
                &beta,
                self.d_y, 1,
            );

            // Download result
            let mut result = vec![0.0f64; dim];
            ffi::cudaMemcpy(
                result.as_mut_ptr(),
                self.d_y as *const f64,
                dim * 8,
                ffi::MEMCPY_DEVICE_TO_HOST,
            );

            ffi::cudaFree(d_x);
            Ok(result)
        }
    }

    /// Check if a Gram matrix of dimension `dim` fits in GPU VRAM.
    /// Needs dim² × 8 (matrix) + 3 × dim × 8 (vectors).
    pub fn can_fit(dim: usize, vram_mb: usize) -> bool {
        let matrix_mb = (dim * dim * 8) / (1024 * 1024);
        let vectors_mb = (3 * dim * 8) / (1024 * 1024);
        matrix_mb + vectors_mb + 256 < vram_mb  // 256 MB headroom
    }
}

impl Drop for BilinearEngine {
    fn drop(&mut self) {
        unsafe {
            ffi::cudaFree(self.d_gram);
            ffi::cudaFree(self.d_y);
            ffi::cublasDestroy_v2(self.blas_handle);
        }
    }
}

// Safety: GPU handles are thread-safe in the CUDA runtime model
unsafe impl Send for BilinearEngine {}
unsafe impl Sync for BilinearEngine {}
