//! GPU eigendecomposition via cuSOLVER FFI.
//!
//! Uses cuSOLVER's dsyevd (symmetric eigenvalue decomposition, double precision)
//! to solve G v = λ v for the full spectrum of the Gram matrix.
//!
//! This is 100-300x faster than CPU nalgebra for N > 2000.

use std::ffi::c_int;
use std::ptr;

// cuSOLVER types
type CusolverDnHandle = *mut std::ffi::c_void;
type CudaStream = *mut std::ffi::c_void;

#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq)]
#[allow(dead_code)]
enum CusolverEigMode {
    NoVec = 0,
    Vec = 1,
}

#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq)]
#[allow(dead_code)]
enum CublasFillMode {
    Upper = 0,
    Lower = 1,
}

// FFI declarations
#[link(name = "cusolver")]
extern "C" {
    fn cusolverDnCreate(handle: *mut CusolverDnHandle) -> c_int;
    fn cusolverDnDestroy(handle: CusolverDnHandle) -> c_int;
    fn cusolverDnDsyevd_bufferSize(
        handle: CusolverDnHandle,
        jobz: CusolverEigMode,
        uplo: CublasFillMode,
        n: c_int,
        a: *const f64,
        lda: c_int,
        w: *const f64,
        lwork: *mut c_int,
    ) -> c_int;
    fn cusolverDnDsyevd(
        handle: CusolverDnHandle,
        jobz: CusolverEigMode,
        uplo: CublasFillMode,
        n: c_int,
        a: *mut f64,
        lda: c_int,
        w: *mut f64,
        work: *mut f64,
        lwork: c_int,
        devInfo: *mut c_int,
    ) -> c_int;
    // Cholesky factorization: A = L L^T
    fn cusolverDnDpotrf_bufferSize(
        handle: CusolverDnHandle,
        uplo: CublasFillMode,
        n: c_int,
        a: *mut f64,
        lda: c_int,
        lwork: *mut c_int,
    ) -> c_int;
    fn cusolverDnDpotrf(
        handle: CusolverDnHandle,
        uplo: CublasFillMode,
        n: c_int,
        a: *mut f64,
        lda: c_int,
        work: *mut f64,
        lwork: c_int,
        devInfo: *mut c_int,
    ) -> c_int;
    // Cholesky solve: L L^T X = B
    fn cusolverDnDpotrs(
        handle: CusolverDnHandle,
        uplo: CublasFillMode,
        n: c_int,
        nrhs: c_int,
        a: *const f64,
        lda: c_int,
        b: *mut f64,
        ldb: c_int,
        devInfo: *mut c_int,
    ) -> c_int;
}

// CUDA runtime FFI
#[link(name = "cudart")]
extern "C" {
    fn cudaMalloc(devPtr: *mut *mut f64, size: usize) -> c_int;
    fn cudaFree(devPtr: *mut f64) -> c_int;
    fn cudaMemcpy(dst: *mut f64, src: *const f64, count: usize, kind: c_int) -> c_int;
    fn cudaDeviceSynchronize() -> c_int;
    fn cudaGetDeviceProperties_v2(prop: *mut CudaDeviceProp, device: c_int) -> c_int;
}

// cuBLAS for dot product
type CublasHandle = *mut std::ffi::c_void;

#[link(name = "cublas")]
extern "C" {
    fn cublasCreate_v2(handle: *mut CublasHandle) -> c_int;
    fn cublasDestroy_v2(handle: CublasHandle) -> c_int;
    fn cublasDdot_v2(
        handle: CublasHandle,
        n: c_int,
        x: *const f64,
        incx: c_int,
        y: *const f64,
        incy: c_int,
        result: *mut f64,
    ) -> c_int;
    fn cublasDgemv_v2(
        handle: CublasHandle,
        trans: c_int, // 0=NoTrans, 1=Trans
        m: c_int,
        n: c_int,
        alpha: *const f64,
        a: *const f64,
        lda: c_int,
        x: *const f64,
        incx: c_int,
        beta: *const f64,
        y: *mut f64,
        incy: c_int,
    ) -> c_int;
    fn cublasDscal_v2(
        handle: CublasHandle,
        n: c_int,
        alpha: *const f64,
        x: *mut f64,
        incx: c_int,
    ) -> c_int;
    fn cublasDaxpy_v2(
        handle: CublasHandle,
        n: c_int,
        alpha: *const f64,
        x: *const f64,
        incx: c_int,
        y: *mut f64,
        incy: c_int,
    ) -> c_int;
    fn cublasDnrm2_v2(
        handle: CublasHandle,
        n: c_int,
        x: *const f64,
        incx: c_int,
        result: *mut f64,
    ) -> c_int;
}

const CUDA_MEMCPY_HOST_TO_DEVICE: c_int = 1;
const CUDA_MEMCPY_DEVICE_TO_HOST: c_int = 2;

// Minimal device properties struct (only what we need)
#[repr(C)]
struct CudaDeviceProp {
    name: [u8; 256],
    total_global_mem: usize,
    _padding: [u8; 1024], // padding for the rest of the struct
}

/// GPU device info
pub struct GpuInfo {
    pub name: String,
    pub vram_mb: usize,
}

/// Detect and report GPU info
pub fn detect_gpu() -> Option<GpuInfo> {
    unsafe {
        let mut prop: CudaDeviceProp = std::mem::zeroed();
        let status = cudaGetDeviceProperties_v2(&mut prop, 0);
        if status != 0 {
            return None;
        }
        let name = std::ffi::CStr::from_ptr(prop.name.as_ptr() as *const i8)
            .to_string_lossy()
            .to_string();
        let vram_mb = prop.total_global_mem / (1024 * 1024);
        Some(GpuInfo { name, vram_mb })
    }
}

/// Result of GPU eigendecomposition
pub struct GpuEigenResult {
    /// Eigenvalues in ascending order
    pub eigenvalues: Vec<f64>,
    /// Eigenvectors as column-major N×N matrix
    pub eigenvectors: Vec<f64>,
    /// GPU time in seconds
    pub gpu_time_secs: f64,
}

/// Perform symmetric eigendecomposition on GPU using cuSOLVER.
///
/// Input: row-major Gram matrix data (N×N, stored as &[f64] of length N*N)
/// Output: eigenvalues (ascending) and eigenvectors (column-major)
pub fn gpu_syevd(gram_data: &[f64], n: usize) -> Result<GpuEigenResult, String> {
    let n_i32 = n as c_int;
    let matrix_bytes = n * n * std::mem::size_of::<f64>();

    // Convert from row-major to column-major (cuSOLVER expects column-major)
    let mut col_major = vec![0.0f64; n * n];
    for i in 0..n {
        for j in 0..n {
            col_major[j * n + i] = gram_data[i * n + j];
        }
    }

    unsafe {
        let start = std::time::Instant::now();

        // Create cuSOLVER handle
        let mut handle: CusolverDnHandle = ptr::null_mut();
        let status = cusolverDnCreate(&mut handle);
        if status != 0 {
            return Err(format!("cusolverDnCreate failed: {}", status));
        }

        // Allocate device memory
        let mut d_a: *mut f64 = ptr::null_mut();
        let mut d_w: *mut f64 = ptr::null_mut();
        let mut d_info: *mut c_int = ptr::null_mut();

        let s1 = cudaMalloc(&mut d_a, matrix_bytes);
        let s2 = cudaMalloc(&mut d_w, n * std::mem::size_of::<f64>());
        let s3 = cudaMalloc(
            &mut d_info as *mut *mut c_int as *mut *mut f64,
            std::mem::size_of::<c_int>(),
        );
        if s1 != 0 || s2 != 0 || s3 != 0 {
            return Err(format!("cudaMalloc failed: {}, {}, {}", s1, s2, s3));
        }

        // Copy matrix to device
        cudaMemcpy(
            d_a,
            col_major.as_ptr(),
            matrix_bytes,
            CUDA_MEMCPY_HOST_TO_DEVICE,
        );

        // Query workspace size
        let mut lwork: c_int = 0;
        cusolverDnDsyevd_bufferSize(
            handle,
            CusolverEigMode::Vec,
            CublasFillMode::Lower,
            n_i32,
            d_a,
            n_i32,
            d_w,
            &mut lwork,
        );

        // Allocate workspace
        let mut d_work: *mut f64 = ptr::null_mut();
        cudaMalloc(&mut d_work, lwork as usize * std::mem::size_of::<f64>());

        // Run eigendecomposition!
        let status = cusolverDnDsyevd(
            handle,
            CusolverEigMode::Vec,
            CublasFillMode::Lower,
            n_i32,
            d_a,
            n_i32,
            d_w,
            d_work,
            lwork,
            d_info,
        );
        cudaDeviceSynchronize();

        if status != 0 {
            cudaFree(d_a);
            cudaFree(d_w);
            cudaFree(d_work);
            cudaFree(d_info as *mut f64);
            cusolverDnDestroy(handle);
            return Err(format!("cusolverDnDsyevd failed: {}", status));
        }

        // Copy results back
        let mut eigenvalues = vec![0.0f64; n];
        let mut eigenvectors = vec![0.0f64; n * n];
        cudaMemcpy(
            eigenvalues.as_mut_ptr(),
            d_w,
            n * 8,
            CUDA_MEMCPY_DEVICE_TO_HOST,
        );
        cudaMemcpy(
            eigenvectors.as_mut_ptr(),
            d_a,
            matrix_bytes,
            CUDA_MEMCPY_DEVICE_TO_HOST,
        );

        let gpu_time = start.elapsed().as_secs_f64();

        // Cleanup
        cudaFree(d_a);
        cudaFree(d_w);
        cudaFree(d_work);
        cudaFree(d_info as *mut f64);
        cusolverDnDestroy(handle);

        Ok(GpuEigenResult {
            eigenvalues,
            eigenvectors,
            gpu_time_secs: gpu_time,
        })
    }
}

/// Result of GPU spectral projection — eigenvalues + projection amplitudes only.
/// Does NOT download the full N×N eigenvector matrix.
pub struct GpuSpectralResult {
    /// Eigenvalues in ascending order (cuSOLVER sorts them)
    pub eigenvalues: Vec<f64>,
    /// c_k = ⟨b, v_k⟩ — projection of b onto each eigenvector
    pub projections: Vec<f64>,
    /// GPU time in seconds
    pub gpu_time_secs: f64,
}

/// GPU spectral projections: eigendecomposition + V^T b entirely on GPU.
///
/// For N=40,000 this uses ~12.8 GB VRAM (matrix) + ~320 KB (eigenvalues)
/// plus workspace. The eigenvector matrix stays on GPU — we compute
/// `c = V^T b` via cuBLAS dgemv and only download eigenvalues + c.
///
/// This avoids the 12.8 GB device→host transfer of the eigenvector matrix.
pub fn gpu_spectral_projections(
    gram_data: &[f64],
    n: usize,
    b: &[f64],
) -> Result<GpuSpectralResult, String> {
    let n_i32 = n as c_int;
    let matrix_bytes = n * n * 8;
    let vec_bytes = n * 8;

    // For symmetric matrices, row-major = column-major (A = A^T),
    // so we can skip the transpose for the Gram matrix!
    // cuSOLVER dsyevd only reads the lower triangle anyway.

    unsafe {
        let start = std::time::Instant::now();

        // Create handles
        let mut solver_handle: CusolverDnHandle = ptr::null_mut();
        let mut blas_handle: CublasHandle = ptr::null_mut();
        let s = cusolverDnCreate(&mut solver_handle);
        if s != 0 {
            return Err(format!("cusolverDnCreate failed: {}", s));
        }
        let s = cublasCreate_v2(&mut blas_handle);
        if s != 0 {
            cusolverDnDestroy(solver_handle);
            return Err(format!("cublasCreate failed: {}", s));
        }

        // Allocate GPU memory
        let mut d_a: *mut f64 = ptr::null_mut(); // matrix → eigenvectors after dsyevd
        let mut d_w: *mut f64 = ptr::null_mut(); // eigenvalues
        let mut d_b: *mut f64 = ptr::null_mut(); // b vector
        let mut d_c: *mut f64 = ptr::null_mut(); // c = V^T b (projections)
        let mut d_info: *mut c_int = ptr::null_mut();

        let s1 = cudaMalloc(&mut d_a, matrix_bytes);
        let s2 = cudaMalloc(&mut d_w, vec_bytes);
        let s3 = cudaMalloc(&mut d_b, vec_bytes);
        let s4 = cudaMalloc(&mut d_c, vec_bytes);
        let s5 = cudaMalloc(&mut d_info as *mut *mut c_int as *mut *mut f64, 4);
        if s1 != 0 || s2 != 0 || s3 != 0 || s4 != 0 || s5 != 0 {
            return Err(format!(
                "cudaMalloc failed: {},{},{},{},{}",
                s1, s2, s3, s4, s5
            ));
        }

        // Upload matrix and b vector
        cudaMemcpy(
            d_a,
            gram_data.as_ptr(),
            matrix_bytes,
            CUDA_MEMCPY_HOST_TO_DEVICE,
        );
        cudaMemcpy(d_b, b.as_ptr(), vec_bytes, CUDA_MEMCPY_HOST_TO_DEVICE);

        let t_upload = start.elapsed().as_secs_f64();
        eprintln!(
            "  GPU upload: {:.1}s ({:.0} MB)",
            t_upload,
            matrix_bytes as f64 / 1e6
        );

        // Query workspace size
        let mut lwork: c_int = 0;
        cusolverDnDsyevd_bufferSize(
            solver_handle,
            CusolverEigMode::Vec,
            CublasFillMode::Lower,
            n_i32,
            d_a,
            n_i32,
            d_w,
            &mut lwork,
        );
        eprintln!(
            "  cuSOLVER workspace: {} MB",
            (lwork as usize * 8) / (1024 * 1024)
        );

        let mut d_work: *mut f64 = ptr::null_mut();
        let s = cudaMalloc(&mut d_work, lwork as usize * 8);
        if s != 0 {
            return Err(format!(
                "cudaMalloc workspace failed: {} ({} MB)",
                s,
                (lwork as usize * 8) / (1024 * 1024)
            ));
        }

        // ═══ EIGENDECOMPOSITION ═══
        // After this, d_a contains eigenvectors (column-major) and d_w contains eigenvalues
        let t_eigen_start = std::time::Instant::now();
        let status = cusolverDnDsyevd(
            solver_handle,
            CusolverEigMode::Vec,
            CublasFillMode::Lower,
            n_i32,
            d_a,
            n_i32,
            d_w,
            d_work,
            lwork,
            d_info,
        );
        cudaDeviceSynchronize();
        let t_eigen = t_eigen_start.elapsed().as_secs_f64();
        eprintln!("  GPU eigendecomposition: {:.1}s", t_eigen);

        // Free workspace immediately to reclaim VRAM
        cudaFree(d_work);

        if status != 0 {
            cudaFree(d_a);
            cudaFree(d_w);
            cudaFree(d_b);
            cudaFree(d_c);
            cudaFree(d_info as *mut f64);
            cusolverDnDestroy(solver_handle);
            cublasDestroy_v2(blas_handle);
            return Err(format!("cusolverDnDsyevd failed: {}", status));
        }

        // ═══ SPECTRAL PROJECTIONS ═══
        // c = V^T b where V is stored column-major in d_a
        // cublasDgemv: y = α * op(A) * x + β * y
        // We want c = V^T * b, so trans=1 (Transpose), m=n, n=n
        let alpha = 1.0f64;
        let beta_val = 0.0f64;
        let t_proj_start = std::time::Instant::now();
        let s = cublasDgemv_v2(
            blas_handle,
            1, // CUBLAS_OP_T = transpose
            n_i32,
            n_i32,
            &alpha,
            d_a,
            n_i32, // V (column-major eigenvectors)
            d_b,
            1, // b vector
            &beta_val,
            d_c,
            1, // c = V^T b output
        );
        cudaDeviceSynchronize();
        let t_proj = t_proj_start.elapsed().as_secs_f64();
        eprintln!("  GPU V^T b projection: {:.3}s", t_proj);

        if s != 0 {
            eprintln!("  ⚠ cublasDgemv failed ({}), falling back to host", s);
        }

        // Download eigenvalues and projections (tiny: 2 × N × 8 bytes)
        let mut eigenvalues = vec![0.0f64; n];
        let mut projections = vec![0.0f64; n];
        cudaMemcpy(
            eigenvalues.as_mut_ptr(),
            d_w,
            vec_bytes,
            CUDA_MEMCPY_DEVICE_TO_HOST,
        );
        cudaMemcpy(
            projections.as_mut_ptr(),
            d_c,
            vec_bytes,
            CUDA_MEMCPY_DEVICE_TO_HOST,
        );

        let gpu_time = start.elapsed().as_secs_f64();

        // Cleanup all GPU memory
        cudaFree(d_a);
        cudaFree(d_w);
        cudaFree(d_b);
        cudaFree(d_c);
        cudaFree(d_info as *mut f64);
        cusolverDnDestroy(solver_handle);
        cublasDestroy_v2(blas_handle);

        eprintln!("  GPU total: {:.1}s", gpu_time);

        Ok(GpuSpectralResult {
            eigenvalues,
            projections,
            gpu_time_secs: gpu_time,
        })
    }
}

/// GPU eigenvalues-only: dsyevd with NoVec mode.
///
/// This uses dramatically less workspace than the full eigendecomposition
/// (no eigenvector storage needed). For N=40,000:
/// - Full (Vec):   12.8 GB matrix + ~12 GB workspace = ~25 GB (exceeds 24 GB VRAM)
/// - NoVec:        12.8 GB matrix + ~1 GB workspace = ~14 GB (fits!)
///
/// After this, you can get d² from Cholesky and use the eigenvalue distribution
/// for the spectral analysis.
pub fn gpu_eigenvalues_only(gram_data: &[f64], n: usize) -> Result<(Vec<f64>, f64), String> {
    let n_i32 = n as c_int;
    let matrix_bytes = n * n * 8;
    let vec_bytes = n * 8;

    unsafe {
        let start = std::time::Instant::now();

        let mut handle: CusolverDnHandle = ptr::null_mut();
        let s = cusolverDnCreate(&mut handle);
        if s != 0 {
            return Err(format!("cusolverDnCreate failed: {}", s));
        }

        let mut d_a: *mut f64 = ptr::null_mut();
        let mut d_w: *mut f64 = ptr::null_mut();
        let mut d_info: *mut c_int = ptr::null_mut();

        let s1 = cudaMalloc(&mut d_a, matrix_bytes);
        let s2 = cudaMalloc(&mut d_w, vec_bytes);
        let s3 = cudaMalloc(&mut d_info as *mut *mut c_int as *mut *mut f64, 4);
        if s1 != 0 || s2 != 0 || s3 != 0 {
            return Err(format!("cudaMalloc failed: {},{},{}", s1, s2, s3));
        }

        cudaMemcpy(
            d_a,
            gram_data.as_ptr(),
            matrix_bytes,
            CUDA_MEMCPY_HOST_TO_DEVICE,
        );

        let t_upload = start.elapsed().as_secs_f64();
        eprintln!(
            "  GPU upload: {:.1}s ({:.0} MB)",
            t_upload,
            matrix_bytes as f64 / 1e6
        );

        // NoVec mode — much smaller workspace
        let mut lwork: c_int = 0;
        cusolverDnDsyevd_bufferSize(
            handle,
            CusolverEigMode::NoVec,
            CublasFillMode::Lower,
            n_i32,
            d_a,
            n_i32,
            d_w,
            &mut lwork,
        );
        let ws_mb = (lwork as usize * 8) / (1024 * 1024);
        eprintln!("  cuSOLVER workspace (NoVec): {} MB", ws_mb);

        let mut d_work: *mut f64 = ptr::null_mut();
        let s = cudaMalloc(&mut d_work, lwork as usize * 8);
        if s != 0 {
            cudaFree(d_a);
            cudaFree(d_w);
            cudaFree(d_info as *mut f64);
            cusolverDnDestroy(handle);
            return Err(format!("workspace alloc failed: {} ({} MB)", s, ws_mb));
        }

        let t_eigen_start = std::time::Instant::now();
        let status = cusolverDnDsyevd(
            handle,
            CusolverEigMode::NoVec,
            CublasFillMode::Lower,
            n_i32,
            d_a,
            n_i32,
            d_w,
            d_work,
            lwork,
            d_info,
        );
        cudaDeviceSynchronize();
        let t_eigen = t_eigen_start.elapsed().as_secs_f64();
        eprintln!("  GPU eigenvalues (NoVec): {:.1}s", t_eigen);

        cudaFree(d_work);
        cudaFree(d_a);

        if status != 0 {
            cudaFree(d_w);
            cudaFree(d_info as *mut f64);
            cusolverDnDestroy(handle);
            return Err(format!("cusolverDnDsyevd NoVec failed: {}", status));
        }

        let mut eigenvalues = vec![0.0f64; n];
        cudaMemcpy(
            eigenvalues.as_mut_ptr(),
            d_w,
            vec_bytes,
            CUDA_MEMCPY_DEVICE_TO_HOST,
        );

        let gpu_time = start.elapsed().as_secs_f64();
        cudaFree(d_w);
        cudaFree(d_info as *mut f64);
        cusolverDnDestroy(handle);

        eprintln!("  GPU eigenvalues total: {:.1}s", gpu_time);
        Ok((eigenvalues, gpu_time))
    }
}

// ═══════════════════════════════════════════════════════════════
// GPU LANCZOS — bottom-k eigenvalues via cuBLAS matvec
// ═══════════════════════════════════════════════════════════════

/// Result of GPU Lanczos iteration.
pub struct GpuLanczosResult {
    /// Bottom-k eigenvalues (ascending order)
    pub eigenvalues: Vec<f64>,
    /// Ritz vectors in the Lanczos basis (m × k matrix, row-major)
    /// Multiply by basis to get full eigenvectors
    pub ritz_vectors: Vec<Vec<f64>>,
    /// Lanczos basis vectors (m vectors of length N, stored on HOST)
    pub basis: Vec<Vec<f64>>,
    /// GPU time in seconds
    pub gpu_time_secs: f64,
    /// Number of Lanczos iterations actually performed
    pub iterations: usize,
}

/// GPU Lanczos for bottom-k eigenvalues using spectral shift.
///
/// The matrix G stays on GPU. The Lanczos iteration uses:
///   - cublasDgemv for y = G·x  (the dominant cost, ~O(N²) per step)
///   - cublasDdot for dot products
///   - cudaMemcpy for basis vector download (O(N) per step)
///
/// VRAM budget at N=40,000:
///   - Matrix: N² × 8 = 12.8 GB
///   - Vectors: 3 × N × 8 = 960 KB (v_j, v_{j-1}, w)
///   - Total: ~12.8 GB  (fits in 24 GB easily!)
///
/// Compare with dsyevd(Vec): ~25 GB (exceeds 24 GB VRAM)
///
/// The m basis vectors are downloaded to HOST memory (m × N × 8 bytes).
/// For m=300, N=40K: 300 × 40K × 8 = 96 MB — trivial.
///
/// After m iterations, the m×m tridiagonal matrix is eigendecomposed on CPU
/// (instant for m ≤ 1000), and the top-k Ritz values of (σI-G) give the
/// bottom-k eigenvalues of G.
pub fn gpu_lanczos_bottom_k(
    d_gram: *const f64, // GPU pointer — matrix already uploaded
    dim: usize,
    k: usize, // number of bottom eigenvalues
    m: usize, // Lanczos subspace dimension (typically 15*k)
    blas_handle: CublasHandle,
) -> Result<GpuLanczosResult, String> {
    use cathedral_utils::lanczos;

    let n_i32 = dim as c_int;
    let vec_bytes = dim * 8;
    let m_actual = m.min(dim);
    let start = std::time::Instant::now();

    // Estimate sigma from diagonal (download diagonal only)
    let mut diag = vec![0.0f64; dim];
    for i in 0..dim {
        unsafe {
            cudaMemcpy(
                diag.as_mut_ptr().add(i),
                (d_gram as *const f64).add(i * dim + i),
                8,
                CUDA_MEMCPY_DEVICE_TO_HOST,
            );
        }
    }
    let trace: f64 = diag.iter().sum();
    let sigma = trace * 1.1;

    unsafe {
        // Allocate GPU vectors: v_curr, v_prev, w
        let mut d_v_curr: *mut f64 = ptr::null_mut();
        let mut d_v_prev: *mut f64 = ptr::null_mut();
        let mut d_w: *mut f64 = ptr::null_mut();

        let s1 = cudaMalloc(&mut d_v_curr, vec_bytes);
        let s2 = cudaMalloc(&mut d_v_prev, vec_bytes);
        let s3 = cudaMalloc(&mut d_w, vec_bytes);
        if s1 != 0 || s2 != 0 || s3 != 0 {
            return Err(format!("cudaMalloc failed: {},{},{}", s1, s2, s3));
        }

        // Initialize v_0 = random unit vector
        let mut v0 = vec![0.0f64; dim];
        let seed = 0x12345678u64;
        for i in 0..dim {
            // Simple deterministic initialization
            let x = ((seed
                .wrapping_mul(i as u64 + 1)
                .wrapping_add(0x9E3779B97F4A7C15)) as f64)
                / (u64::MAX as f64)
                - 0.5;
            v0[i] = x;
        }
        let norm: f64 = v0.iter().map(|x| x * x).sum::<f64>().sqrt();
        for x in &mut v0 {
            *x /= norm;
        }

        cudaMemcpy(d_v_curr, v0.as_ptr(), vec_bytes, CUDA_MEMCPY_HOST_TO_DEVICE);

        // Zero v_prev
        let zeros = vec![0.0f64; dim];
        cudaMemcpy(
            d_v_prev,
            zeros.as_ptr(),
            vec_bytes,
            CUDA_MEMCPY_HOST_TO_DEVICE,
        );

        // Lanczos tridiagonal coefficients
        let mut alphas = Vec::with_capacity(m_actual);
        let mut betas = Vec::with_capacity(m_actual + 1);
        betas.push(0.0);

        // Basis vectors (downloaded to host)
        let mut basis: Vec<Vec<f64>> = Vec::with_capacity(m_actual);

        let alpha_one = 1.0f64;
        let beta_zero = 0.0f64;

        for j in 0..m_actual {
            // Download current basis vector to host
            let mut v_host = vec![0.0f64; dim];
            cudaMemcpy(
                v_host.as_mut_ptr(),
                d_v_curr,
                vec_bytes,
                CUDA_MEMCPY_DEVICE_TO_HOST,
            );
            basis.push(v_host);

            // w = G · v_curr  via cuBLAS dgemv
            // Since G is stored row-major on GPU (symmetric, so row=col),
            // use NoTrans: w = G * v_curr
            cublasDgemv_v2(
                blas_handle,
                0, // CUBLAS_OP_N
                n_i32,
                n_i32,
                &alpha_one,
                d_gram,
                n_i32,
                d_v_curr,
                1,
                &beta_zero,
                d_w,
                1,
            );
            cudaDeviceSynchronize();

            // Apply spectral shift: w = sigma * v_curr - w
            // (w now contains G*v, we want (σI-G)*v = σ*v - G*v)
            // w[i] = sigma * v_curr[i] - w[i]
            // Using cuBLAS: w = -1*w + sigma*v_curr
            // First: w = -w (scale by -1), then w += sigma * v_curr
            let neg_one = -1.0f64;
            // cublasDscal: w = -1 * w
            cublasDscal_v2(blas_handle, n_i32, &neg_one, d_w, 1);
            // cublasDaxpy: w = w + sigma * v_curr
            cublasDaxpy_v2(blas_handle, n_i32, &sigma, d_v_curr, 1, d_w, 1);

            // α_j = v_curr^T · w  via cuBLAS ddot
            let mut alpha_j = 0.0f64;
            cublasDdot_v2(blas_handle, n_i32, d_v_curr, 1, d_w, 1, &mut alpha_j);
            alphas.push(alpha_j);

            // w = w - α_j * v_curr - β_{j-1} * v_prev
            let neg_alpha = -alpha_j;
            cublasDaxpy_v2(blas_handle, n_i32, &neg_alpha, d_v_curr, 1, d_w, 1);
            if j > 0 {
                let neg_beta = -betas[j];
                cublasDaxpy_v2(blas_handle, n_i32, &neg_beta, d_v_prev, 1, d_w, 1);
            }

            // Full reorthogonalization against all previous basis vectors
            for prev in 0..basis.len() {
                // Upload basis[prev] to d_v_prev temporarily
                cudaMemcpy(
                    d_v_prev,
                    basis[prev].as_ptr(),
                    vec_bytes,
                    CUDA_MEMCPY_HOST_TO_DEVICE,
                );
                let mut overlap = 0.0f64;
                cublasDdot_v2(blas_handle, n_i32, d_w, 1, d_v_prev, 1, &mut overlap);
                let neg_overlap = -overlap;
                cublasDaxpy_v2(blas_handle, n_i32, &neg_overlap, d_v_prev, 1, d_w, 1);
            }

            // β_j = ‖w‖  via cuBLAS dnrm2
            let mut beta_j = 0.0f64;
            cublasDnrm2_v2(blas_handle, n_i32, d_w, 1, &mut beta_j);

            if beta_j < 1e-14 {
                eprintln!("  GPU Lanczos: invariant subspace found at step {}", j);
                break;
            }
            betas.push(beta_j);

            // v_prev = v_curr, v_curr = w / β_j
            // Swap pointers
            std::mem::swap(&mut d_v_prev, &mut d_v_curr);
            // v_curr = w / β_j
            let inv_beta = 1.0 / beta_j;
            cudaMemcpy(d_v_curr, d_w as *const f64, vec_bytes, 2); // device-to-device? No, use scale
                                                                   // Actually: copy w to v_curr, then scale
                                                                   // cudaMemcpyDeviceToDevice = 3
            let d2d: c_int = 3;
            cudaMemcpy(d_v_curr, d_w as *const f64, vec_bytes, d2d);
            cublasDscal_v2(blas_handle, n_i32, &inv_beta, d_v_curr, 1);
        }

        // Free GPU vectors
        cudaFree(d_v_curr);
        cudaFree(d_v_prev);
        cudaFree(d_w);

        let gpu_time = start.elapsed().as_secs_f64();
        let m_done = basis.len();

        // Build tridiagonal matrix and eigendecompose on CPU
        let tri = lanczos::TridiagMatrix {
            alpha: alphas,
            beta: betas,
            m: m_done,
        };
        let (ritz_values, ritz_vectors) = lanczos::tridiag_eigen(&tri);

        // Top-k of (σI-G) = bottom-k of G
        let n_ritz = ritz_values.len();
        let top_start = n_ritz.saturating_sub(k);
        let mut eigenvalues: Vec<f64> = ritz_values[top_start..]
            .iter()
            .map(|&lam| sigma - lam)
            .collect();
        eigenvalues.sort_by(|a, b| a.partial_cmp(b).unwrap());

        let selected_ritz: Vec<Vec<f64>> = (top_start..n_ritz)
            .map(|i| ritz_vectors[i].clone())
            .collect();

        Ok(GpuLanczosResult {
            eigenvalues,
            ritz_vectors: selected_ritz,
            basis,
            gpu_time_secs: gpu_time,
            iterations: m_done,
        })
    }
}

// ═══════════════════════════════════════════════════════════════
// GPU f64 CHOLESKY via cuSOLVER — d² = 1 - b^T G^{-1} b
// ═══════════════════════════════════════════════════════════════

/// Compute d² = 1 - b^T G_N^{-1} b entirely on GPU using cuSOLVER Cholesky.
/// This is ~100x faster than nalgebra for N > 2000.
///
/// Uses dpotrf (Cholesky factorization) + dpotrs (triangular solve).
pub fn gpu_cholesky_d2(gram_data: &[f64], b: &[f64], dim: usize) -> Result<f64, String> {
    let n = dim as c_int;
    let matrix_bytes = dim * dim * 8;
    let vec_bytes = dim * 8;

    // Convert from row-major to column-major for cuSOLVER
    let mut col_major = vec![0.0f64; dim * dim];
    for i in 0..dim {
        for j in 0..dim {
            col_major[j * dim + i] = gram_data[i * dim + j];
        }
    }

    unsafe {
        // Create cuSOLVER handle
        let mut handle: CusolverDnHandle = ptr::null_mut();
        if cusolverDnCreate(&mut handle) != 0 {
            return Err("cusolverDnCreate failed".into());
        }

        // Allocate device memory
        let mut d_a: *mut f64 = ptr::null_mut();
        let mut d_b: *mut f64 = ptr::null_mut();
        let mut d_info: *mut c_int = ptr::null_mut();

        cudaMalloc(&mut d_a, matrix_bytes);
        cudaMalloc(&mut d_b, vec_bytes);
        cudaMalloc(&mut d_info as *mut *mut c_int as *mut *mut f64, 4);

        // Copy data to device
        cudaMemcpy(
            d_a,
            col_major.as_ptr(),
            matrix_bytes,
            CUDA_MEMCPY_HOST_TO_DEVICE,
        );
        cudaMemcpy(d_b, b.as_ptr(), vec_bytes, CUDA_MEMCPY_HOST_TO_DEVICE);

        // Query workspace size for Cholesky
        let mut lwork: c_int = 0;
        cusolverDnDpotrf_bufferSize(handle, CublasFillMode::Lower, n, d_a, n, &mut lwork);

        let mut d_work: *mut f64 = ptr::null_mut();
        cudaMalloc(&mut d_work, lwork as usize * 8);

        // Cholesky factorization: A = L L^T
        let s = cusolverDnDpotrf(
            handle,
            CublasFillMode::Lower,
            n,
            d_a,
            n,
            d_work,
            lwork,
            d_info,
        );
        cudaDeviceSynchronize();

        // Check if Cholesky succeeded
        let mut info_val: c_int = 0;
        cudaMemcpy(
            &mut info_val as *mut c_int as *mut f64,
            d_info as *const f64,
            4,
            CUDA_MEMCPY_DEVICE_TO_HOST,
        );

        if s != 0 || info_val != 0 {
            cudaFree(d_a);
            cudaFree(d_b);
            cudaFree(d_work);
            cudaFree(d_info as *mut f64);
            cusolverDnDestroy(handle);
            return Err(format!("dpotrf failed: status={}, info={}", s, info_val));
        }

        // Solve L L^T x = b  (result overwrites d_b)
        let s = cusolverDnDpotrs(handle, CublasFillMode::Lower, n, 1, d_a, n, d_b, n, d_info);
        cudaDeviceSynchronize();

        if s != 0 {
            cudaFree(d_a);
            cudaFree(d_b);
            cudaFree(d_work);
            cudaFree(d_info as *mut f64);
            cusolverDnDestroy(handle);
            return Err(format!("dpotrs failed: status={}", s));
        }

        // Compute b^T x on GPU using cuBLAS
        let mut blas_handle: CublasHandle = ptr::null_mut();
        let mut dot_result = 0.0f64;

        // Copy original b to device (d_b was overwritten with x)
        let mut d_b_orig: *mut f64 = ptr::null_mut();
        cudaMalloc(&mut d_b_orig, vec_bytes);
        cudaMemcpy(d_b_orig, b.as_ptr(), vec_bytes, CUDA_MEMCPY_HOST_TO_DEVICE);

        if cublasCreate_v2(&mut blas_handle) == 0 {
            cublasDdot_v2(blas_handle, n, d_b_orig, 1, d_b, 1, &mut dot_result);
            cublasDestroy_v2(blas_handle);
        } else {
            // Fallback: copy x back to host and compute dot product there
            let mut x = vec![0.0f64; dim];
            cudaMemcpy(x.as_mut_ptr(), d_b, vec_bytes, CUDA_MEMCPY_DEVICE_TO_HOST);
            dot_result = b.iter().zip(x.iter()).map(|(bi, xi)| bi * xi).sum();
        }

        // Cleanup
        cudaFree(d_a);
        cudaFree(d_b);
        cudaFree(d_b_orig);
        cudaFree(d_work);
        cudaFree(d_info as *mut f64);
        cusolverDnDestroy(handle);

        Ok(1.0 - dot_result)
    }
}

/// Like gpu_cholesky_d2 but takes the full matrix with leading dimension stride.
/// Extracts the dim×dim upper-left submatrix during row→column-major conversion.
/// Avoids a separate submatrix allocation.
pub fn gpu_cholesky_d2_strided(
    full_data: &[f64],
    lda: usize,
    dim: usize,
    b: &[f64],
) -> Result<f64, String> {
    let n = dim as c_int;
    let matrix_bytes = dim * dim * 8;
    let vec_bytes = dim * 8;

    // Convert from row-major (with stride lda) to column-major (packed dim×dim)
    let mut col_major = vec![0.0f64; dim * dim];
    for i in 0..dim {
        for j in 0..dim {
            col_major[j * dim + i] = full_data[i * lda + j];
        }
    }

    unsafe {
        let mut handle: CusolverDnHandle = ptr::null_mut();
        if cusolverDnCreate(&mut handle) != 0 {
            return Err("cusolverDnCreate failed".into());
        }

        let mut d_a: *mut f64 = ptr::null_mut();
        let mut d_b: *mut f64 = ptr::null_mut();
        let mut d_info: *mut c_int = ptr::null_mut();

        cudaMalloc(&mut d_a, matrix_bytes);
        cudaMalloc(&mut d_b, vec_bytes);
        cudaMalloc(&mut d_info as *mut *mut c_int as *mut *mut f64, 4);

        cudaMemcpy(
            d_a,
            col_major.as_ptr(),
            matrix_bytes,
            CUDA_MEMCPY_HOST_TO_DEVICE,
        );
        cudaMemcpy(d_b, b.as_ptr(), vec_bytes, CUDA_MEMCPY_HOST_TO_DEVICE);

        let mut lwork: c_int = 0;
        cusolverDnDpotrf_bufferSize(handle, CublasFillMode::Lower, n, d_a, n, &mut lwork);
        let mut d_work: *mut f64 = ptr::null_mut();
        cudaMalloc(&mut d_work, lwork as usize * 8);

        let s = cusolverDnDpotrf(
            handle,
            CublasFillMode::Lower,
            n,
            d_a,
            n,
            d_work,
            lwork,
            d_info,
        );
        cudaDeviceSynchronize();

        let mut info_val: c_int = 0;
        cudaMemcpy(
            &mut info_val as *mut c_int as *mut f64,
            d_info as *const f64,
            4,
            CUDA_MEMCPY_DEVICE_TO_HOST,
        );
        if s != 0 || info_val != 0 {
            cudaFree(d_a);
            cudaFree(d_b);
            cudaFree(d_work);
            cudaFree(d_info as *mut f64);
            cusolverDnDestroy(handle);
            return Err(format!("dpotrf failed: status={}, info={}", s, info_val));
        }

        let s = cusolverDnDpotrs(handle, CublasFillMode::Lower, n, 1, d_a, n, d_b, n, d_info);
        cudaDeviceSynchronize();
        if s != 0 {
            cudaFree(d_a);
            cudaFree(d_b);
            cudaFree(d_work);
            cudaFree(d_info as *mut f64);
            cusolverDnDestroy(handle);
            return Err(format!("dpotrs failed: status={}", s));
        }

        let mut blas_handle: CublasHandle = ptr::null_mut();
        let mut dot_result = 0.0f64;
        let mut d_b_orig: *mut f64 = ptr::null_mut();
        cudaMalloc(&mut d_b_orig, vec_bytes);
        cudaMemcpy(d_b_orig, b.as_ptr(), vec_bytes, CUDA_MEMCPY_HOST_TO_DEVICE);

        if cublasCreate_v2(&mut blas_handle) == 0 {
            cublasDdot_v2(blas_handle, n, d_b_orig, 1, d_b, 1, &mut dot_result);
            cublasDestroy_v2(blas_handle);
        } else {
            let mut x = vec![0.0f64; dim];
            cudaMemcpy(x.as_mut_ptr(), d_b, vec_bytes, CUDA_MEMCPY_DEVICE_TO_HOST);
            dot_result = b.iter().zip(x.iter()).map(|(bi, xi)| bi * xi).sum();
        }

        cudaFree(d_a);
        cudaFree(d_b);
        cudaFree(d_b_orig);
        cudaFree(d_work);
        cudaFree(d_info as *mut f64);
        cusolverDnDestroy(handle);

        Ok(1.0 - dot_result)
    }
}

// ═══════════════════════════════════════════════════════════════
// GPU DD CHOLESKY — d² = 1 - b^T G^{-1} b at ~31 digit precision
// ═══════════════════════════════════════════════════════════════

#[link(name = "ddcholesky")]
extern "C" {
    fn gpu_dd_cholesky_d2(
        gram_hi: *const f64,
        gram_lo: *const f64,
        b: *const f64,
        dim: c_int,
        fail_col: *mut c_int,
    ) -> f64;
}

pub struct GpuCholeskyResult {
    pub d2: f64,
    pub fail_col: i32, // 0 = success, >0 = failed at this column
    pub gpu_time_secs: f64,
}

/// Perform DD Cholesky on GPU: d² = 1 - b^T G_N^{-1} b
///
/// Input: DD Gram matrix (hi + lo), b vector
/// Output: d² at ~31 digit precision, computed entirely on GPU
pub fn gpu_dd_cholesky(
    gram_hi: &[f64],
    gram_lo: &[f64],
    b: &[f64],
    dim: usize,
) -> Result<GpuCholeskyResult, String> {
    if gram_hi.len() != dim * dim || gram_lo.len() != dim * dim {
        return Err(format!(
            "Gram size mismatch: {} vs {}×{}",
            gram_hi.len(),
            dim,
            dim
        ));
    }
    if b.len() < dim {
        return Err(format!("b vector too short: {} < {}", b.len(), dim));
    }

    unsafe {
        let start = std::time::Instant::now();
        let mut fail_col: c_int = 0;

        let d2 = gpu_dd_cholesky_d2(
            gram_hi.as_ptr(),
            gram_lo.as_ptr(),
            b.as_ptr(),
            dim as c_int,
            &mut fail_col,
        );

        let gpu_time = start.elapsed().as_secs_f64();

        Ok(GpuCholeskyResult {
            d2,
            fail_col: fail_col as i32,
            gpu_time_secs: gpu_time,
        })
    }
}

// ═══════════════════════════════════════════════════════════════
// GPU DS-f32 CHOLESKY — ~14 digits at native f32 speed (64× faster)
// ═══════════════════════════════════════════════════════════════

#[link(name = "dscholesky")]
extern "C" {
    fn gpu_ds_cholesky_d2(
        gram_hi: *const f64,
        gram_lo: *const f64,
        b: *const f64,
        dim: c_int,
        fail_col: *mut c_int,
    ) -> f64;
}

/// DS-f32 Cholesky on GPU: ~14 digits at f32 speed
/// Input: f64 DD Gram (converted to f32 DS internally)
pub fn gpu_ds_cholesky(
    gram_hi: &[f64],
    gram_lo: &[f64],
    b: &[f64],
    dim: usize,
) -> Result<GpuCholeskyResult, String> {
    if gram_hi.len() != dim * dim || gram_lo.len() != dim * dim {
        return Err(format!(
            "Gram size mismatch: {} vs {}×{}",
            gram_hi.len(),
            dim,
            dim
        ));
    }
    if b.len() < dim {
        return Err(format!("b vector too short: {} < {}", b.len(), dim));
    }
    unsafe {
        let start = std::time::Instant::now();
        let mut fail_col: c_int = 0;
        let d2 = gpu_ds_cholesky_d2(
            gram_hi.as_ptr(),
            gram_lo.as_ptr(),
            b.as_ptr(),
            dim as c_int,
            &mut fail_col,
        );
        let gpu_time = start.elapsed().as_secs_f64();
        Ok(GpuCholeskyResult {
            d2,
            fail_col: fail_col as i32,
            gpu_time_secs: gpu_time,
        })
    }
}

// ═══════════════════════════════════════════════════════════════
// GPU QS-f32 CHOLESKY — ~28 digits at native f32 speed
// ═══════════════════════════════════════════════════════════════

#[link(name = "qscholesky")]
extern "C" {
    fn gpu_qs_cholesky_d2(
        gram_hi: *const f64,
        gram_lo: *const f64,
        b: *const f64,
        dim: c_int,
        fail_col: *mut c_int,
    ) -> f64;
}

/// QS-f32 Cholesky on GPU: ~28 digits at f32 speed
/// Input: f64 DD Gram (converted to QS-f32 internally)
pub fn gpu_qs_cholesky(
    gram_hi: &[f64],
    gram_lo: &[f64],
    b: &[f64],
    dim: usize,
) -> Result<GpuCholeskyResult, String> {
    if gram_hi.len() != dim * dim || gram_lo.len() != dim * dim {
        return Err(format!(
            "Gram size mismatch: {} vs {}×{}",
            gram_hi.len(),
            dim,
            dim
        ));
    }
    if b.len() < dim {
        return Err(format!("b vector too short: {} < {}", b.len(), dim));
    }
    unsafe {
        let start = std::time::Instant::now();
        let mut fail_col: c_int = 0;
        let d2 = gpu_qs_cholesky_d2(
            gram_hi.as_ptr(),
            gram_lo.as_ptr(),
            b.as_ptr(),
            dim as c_int,
            &mut fail_col,
        );
        let gpu_time = start.elapsed().as_secs_f64();
        Ok(GpuCholeskyResult {
            d2,
            fail_col: fail_col as i32,
            gpu_time_secs: gpu_time,
        })
    }
}

// ═══════════════════════════════════════════════════════════════
// GPU GRAM MATRIX BUILD — block-based telescoping at QS-f32
// ═══════════════════════════════════════════════════════════════

#[link(name = "gramgpu")]
extern "C" {
    fn gpu_build_gram_qs(
        ln_v0: *const f32,
        ln_v1: *const f32,
        ln_v2: *const f32,
        ln_v3: *const f32,
        ln_size: c_int,
        gram_hi: *mut f64,
        gram_lo: *mut f64,
        dim: c_int,
    ) -> c_int;

    fn gpu_gram_max_n() -> c_int;
}

pub struct GpuGramResult {
    pub gram_hi: Vec<f64>,
    pub gram_lo: Vec<f64>,
    pub dim: usize,
    pub build_time_secs: f64,
}

/// Build QS-f32 Gram matrix entirely on GPU.
/// Input: ln(n) table as (hi, lo) f64 pairs from MPFR.
/// The f64 pairs are split into 4 f32 components for QS.
/// Output: DD Gram at ~28 digit precision.
pub fn gpu_build_gram(ln_table: &[(f64, f64)], dim: usize) -> Result<GpuGramResult, String> {
    let ln_size = ln_table.len();

    // Convert f64 DD pairs → QS-f32 (4 floats per value)
    let mut v0 = Vec::with_capacity(ln_size);
    let mut v1 = Vec::with_capacity(ln_size);
    let mut v2 = Vec::with_capacity(ln_size);
    let mut v3 = Vec::with_capacity(ln_size);
    for &(hi, lo) in ln_table {
        let a = hi as f32;
        let b = (hi - a as f64) as f32;
        let rem = lo + (hi - a as f64 - b as f64);
        let c = rem as f32;
        let d = (rem - c as f64) as f32;
        v0.push(a);
        v1.push(b);
        v2.push(c);
        v3.push(d);
    }

    let mut gram_hi = vec![0.0f64; dim * dim];
    let mut gram_lo = vec![0.0f64; dim * dim];

    let start = std::time::Instant::now();

    let ret = unsafe {
        gpu_build_gram_qs(
            v0.as_ptr(),
            v1.as_ptr(),
            v2.as_ptr(),
            v3.as_ptr(),
            (ln_size - 1) as c_int,
            gram_hi.as_mut_ptr(),
            gram_lo.as_mut_ptr(),
            dim as c_int,
        )
    };

    if ret != 0 {
        return Err(format!("GPU Gram build failed with code {}", ret));
    }

    let build_time = start.elapsed().as_secs_f64();
    Ok(GpuGramResult {
        gram_hi,
        gram_lo,
        dim,
        build_time_secs: build_time,
    })
}

/// Max N that fits in GPU VRAM for QS Gram build.
pub fn gpu_gram_max_dim() -> usize {
    unsafe { gpu_gram_max_n() as usize }
}

// ═══════════════════════════════════════════════════════════════
// GPU DD-f64 GRAM BUILD — log1p bypass, no ln table needed
// ═══════════════════════════════════════════════════════════════

#[link(name = "gramgpudd")]
extern "C" {
    fn gpu_build_gram_dd(gram_hi: *mut f64, gram_lo: *mut f64, dim: c_int, t_max: c_int) -> c_int;

    fn gpu_build_gram_dd_rows(
        gram_hi: *mut f64,
        gram_lo: *mut f64,
        dim: c_int,
        t_max: c_int,
        row_start: c_int,
        n_rows: c_int,
    ) -> c_int;

    fn gpu_upload_gram(gram_hi: *const f64, dim: c_int) -> c_int;

    fn gpu_cholesky_d2_resident(sub_dim: c_int, b_host: *const f64, fail_col: *mut c_int) -> f64;

    fn gpu_free_gram();

    fn gpu_has_resident_gram() -> c_int;
}

/// Build DD-f64 Gram matrix on GPU using the log1p bypass.
///
/// The kernel now uses **Smart T_direct**: adaptive truncation per entry
/// (T = max(50*max(j,k), 10000)) instead of uniform T=100000, reducing
/// loop work for small j,k entries while ensuring EM tail accuracy.
///
/// After building, the hi[] array stays resident in GPU VRAM for
/// subsequent gpu_cholesky_resident() calls.
///
/// t_max: maximum T_direct cutoff (typically 100000).
pub fn gpu_build_gram_dd_f64(dim: usize, t_max: usize) -> Result<GpuGramResult, String> {
    let mut gram_hi = vec![0.0f64; dim * dim];
    let mut gram_lo = vec![0.0f64; dim * dim];

    let start = std::time::Instant::now();

    let ret = unsafe {
        gpu_build_gram_dd(
            gram_hi.as_mut_ptr(),
            gram_lo.as_mut_ptr(),
            dim as c_int,
            t_max as c_int,
        )
    };

    if ret != 0 {
        return Err(format!("GPU DD Gram build failed with code {}", ret));
    }

    let build_time = start.elapsed().as_secs_f64();
    Ok(GpuGramResult {
        gram_hi,
        gram_lo,
        dim,
        build_time_secs: build_time,
    })
}

/// Build a chunk of rows of the Gram matrix on GPU using the log1p bypass.
///
/// Only computes rows [row_start..row_start+n_rows) of the full dim×dim matrix.
/// GPU allocates only n_rows×dim on device — trivial VRAM usage.
///
/// Returns (hi_buffer, build_time_secs) where hi_buffer has n_rows*dim entries.
pub fn gpu_build_gram_dd_rows_f64(
    dim: usize,
    t_max: usize,
    row_start: usize,
    n_rows: usize,
) -> Result<(Vec<f64>, f64), String> {
    let mut gram_hi = vec![0.0f64; n_rows * dim];

    let start = std::time::Instant::now();

    let ret = unsafe {
        gpu_build_gram_dd_rows(
            gram_hi.as_mut_ptr(),
            std::ptr::null_mut(), // lo not needed for f64 output
            dim as c_int,
            t_max as c_int,
            row_start as c_int,
            n_rows as c_int,
        )
    };

    if ret != 0 {
        return Err(format!("GPU DD row-range build failed with code {}", ret));
    }

    let build_time = start.elapsed().as_secs_f64();
    Ok((gram_hi, build_time))
}

/// Upload a host-side Gram matrix to GPU VRAM (for cached loads).

/// After this, gpu_cholesky_resident() can run without PCIe matrix transfers.
pub fn gpu_upload_gram_resident(gram_hi: &[f64], dim: usize) -> Result<(), String> {
    let ret = unsafe { gpu_upload_gram(gram_hi.as_ptr(), dim as c_int) };
    if ret != 0 {
        Err(format!("gpu_upload_gram failed with code {}", ret))
    } else {
        Ok(())
    }
}

/// Compute d² = 1 - b^T G_sub^{-1} b entirely on GPU, using the
/// device-resident Gram matrix. No matrix data crosses PCIe — only
/// the b vector (tiny) and the scalar result.
///
/// The function:
/// 1. Extracts the sub_dim×sub_dim upper-left submatrix on GPU
/// 2. Transposes to column-major on GPU (via CUDA kernel)
/// 3. Runs cuSOLVER dpotrf + dpotrs
/// 4. Computes b^T x via cuBLAS ddot
/// 5. Returns d² = 1 - b^T x
pub fn gpu_cholesky_resident(sub_dim: usize, b: &[f64]) -> Result<f64, String> {
    let mut fail_col: c_int = 0;
    let d2 = unsafe { gpu_cholesky_d2_resident(sub_dim as c_int, b.as_ptr(), &mut fail_col) };

    if fail_col != 0 || d2.is_nan() {
        Err(format!("GPU resident Cholesky failed at col {}", fail_col))
    } else {
        Ok(d2)
    }
}

/// Check if a Gram matrix is resident on the GPU.
/// Returns the dimension if resident, 0 if not.
pub fn gpu_resident_gram_dim() -> usize {
    unsafe { gpu_has_resident_gram() as usize }
}

/// Free the device-resident Gram matrix.
pub fn gpu_free_resident_gram() {
    unsafe {
        gpu_free_gram();
    }
}

// ═══════════════════════════════════════════════════════════════════
// PUBLIC FFI — raw CUDA/cuBLAS access for OOC probe
// ═══════════════════════════════════════════════════════════════════

/// Public access to raw CUDA/cuBLAS FFI for use by ooc_probe's GPU matvec.
///
/// Includes stream APIs for double-buffered async pipeline:
///   Stream A: upload chunk[N]   → compute chunk[N]
///   Stream B: upload chunk[N+1] → (overlaps with A's compute)
pub mod ffi {
    use std::ffi::c_int;

    /// Opaque CUDA stream handle.
    pub type CudaStream = *mut std::ffi::c_void;

    #[link(name = "cudart")]
    extern "C" {
        pub fn cudaMalloc(devPtr: *mut *mut f64, size: usize) -> c_int;
        pub fn cudaFree(devPtr: *mut f64) -> c_int;
        pub fn cudaMemcpy(dst: *mut f64, src: *const f64, count: usize, kind: c_int) -> c_int;

        // ── Stream management ──
        pub fn cudaStreamCreate(stream: *mut CudaStream) -> c_int;
        pub fn cudaStreamDestroy(stream: CudaStream) -> c_int;
        pub fn cudaStreamSynchronize(stream: CudaStream) -> c_int;

        // ── Async memory copy (requires pinned host memory or pageable with stream) ──
        pub fn cudaMemcpyAsync(
            dst: *mut f64,
            src: *const f64,
            count: usize,
            kind: c_int,
            stream: CudaStream,
        ) -> c_int;

        // ── Page-locked host memory for true async overlap ──
        pub fn cudaMallocHost(ptr: *mut *mut f64, size: usize) -> c_int;
        pub fn cudaFreeHost(ptr: *mut f64) -> c_int;

        // ── Device synchronization ──
        pub fn cudaDeviceSynchronize() -> c_int;
    }

    pub type CublasHandle = *mut std::ffi::c_void;

    #[link(name = "cublas")]
    extern "C" {
        pub fn cublasCreate_v2(handle: *mut CublasHandle) -> c_int;
        pub fn cublasDestroy_v2(handle: CublasHandle) -> c_int;

        /// Set the CUDA stream used by subsequent cuBLAS calls.
        /// This is the key to overlapping compute with transfer.
        pub fn cublasSetStream_v2(handle: CublasHandle, stream: CudaStream) -> c_int;

        pub fn cublasDgemv_v2(
            handle: CublasHandle,
            trans: c_int,
            m: c_int,
            n: c_int,
            alpha: *const f64,
            a: *const f64,
            lda: c_int,
            x: *const f64,
            incx: c_int,
            beta: *const f64,
            y: *mut f64,
            incy: c_int,
        ) -> c_int;
    }
}
