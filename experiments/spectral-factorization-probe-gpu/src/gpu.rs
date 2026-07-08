//! GPU eigendecomposition and Gram build via CUDA FFI.
//!
//! Reuses the Cathedral GPU infrastructure:
//! - cuSOLVER dsyevd for symmetric eigendecomposition
//! - cuBLAS for V^T b projections and matrix-vector ops
//! - Custom CUDA kernel for DD-precision Gram matrix construction
//!
//! RTX 4090: 24 GB VRAM, 16384 CUDA cores, compute capability 8.9

use std::ffi::c_int;
use std::ptr;

// ═══════════════════════════════════════════════════════════════
// CUDA TYPE ALIASES
// ═══════════════════════════════════════════════════════════════

type CusolverDnHandle = *mut std::ffi::c_void;
type CublasHandle = *mut std::ffi::c_void;

#[repr(C)]
#[derive(Debug, Clone, Copy)]
enum CusolverEigMode {
    NoVec = 0,
    Vec = 1,
}

#[repr(C)]
#[derive(Debug, Clone, Copy)]
enum CublasFillMode {
    #[allow(dead_code)]
    Upper = 0,
    Lower = 1,
}

// ═══════════════════════════════════════════════════════════════
// FFI DECLARATIONS
// ═══════════════════════════════════════════════════════════════

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
}

#[link(name = "cudart")]
extern "C" {
    fn cudaMalloc(devPtr: *mut *mut f64, size: usize) -> c_int;
    fn cudaFree(devPtr: *mut f64) -> c_int;
    fn cudaMemcpy(dst: *mut f64, src: *const f64, count: usize, kind: c_int) -> c_int;
    fn cudaDeviceSynchronize() -> c_int;
    fn cudaGetDeviceProperties_v2(prop: *mut CudaDeviceProp, device: c_int) -> c_int;
}

#[link(name = "cublas")]
extern "C" {
    fn cublasCreate_v2(handle: *mut CublasHandle) -> c_int;
    fn cublasDestroy_v2(handle: CublasHandle) -> c_int;
    fn cublasDgemv_v2(
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

const CUDA_MEMCPY_HOST_TO_DEVICE: c_int = 1;
const CUDA_MEMCPY_DEVICE_TO_HOST: c_int = 2;

#[repr(C)]
struct CudaDeviceProp {
    name: [u8; 256],
    total_global_mem: usize,
    _padding: [u8; 1024],
}

// ═══════════════════════════════════════════════════════════════
// PUBLIC API
// ═══════════════════════════════════════════════════════════════

/// GPU device info.
pub struct GpuInfo {
    pub name: String,
    pub vram_mb: usize,
}

/// Detect GPU hardware.
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

/// Result of GPU eigendecomposition.
pub struct GpuEigenResult {
    /// Eigenvalues in ascending order (cuSOLVER sorts them).
    pub eigenvalues: Vec<f64>,
    /// Eigenvectors as column-major N×N matrix (on host).
    pub eigenvectors: Vec<f64>,
    /// GPU time in seconds.
    pub gpu_time_secs: f64,
}

/// Full GPU eigendecomposition via cuSOLVER dsyevd.
///
/// Input: row-major symmetric matrix.
/// Output: eigenvalues (ascending) + eigenvectors (column-major).
pub fn gpu_eigen(gram_data: &[f64], n: usize) -> Result<GpuEigenResult, String> {
    let n_i32 = n as c_int;
    let matrix_bytes = n * n * 8;

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
        let s2 = cudaMalloc(&mut d_w, n * 8);
        let s3 = cudaMalloc(&mut d_info as *mut *mut c_int as *mut *mut f64, 4);
        if s1 != 0 || s2 != 0 || s3 != 0 {
            return Err(format!("cudaMalloc failed: {},{},{}", s1, s2, s3));
        }

        // Upload (symmetric → row-major = col-major)
        cudaMemcpy(
            d_a,
            gram_data.as_ptr(),
            matrix_bytes,
            CUDA_MEMCPY_HOST_TO_DEVICE,
        );

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

        let mut d_work: *mut f64 = ptr::null_mut();
        let ws = cudaMalloc(&mut d_work, lwork as usize * 8);
        if ws != 0 {
            cudaFree(d_a);
            cudaFree(d_w);
            cudaFree(d_info as *mut f64);
            cusolverDnDestroy(handle);
            return Err(format!("workspace alloc failed: {}", ws));
        }

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

        cudaFree(d_work);

        if status != 0 {
            cudaFree(d_a);
            cudaFree(d_w);
            cudaFree(d_info as *mut f64);
            cusolverDnDestroy(handle);
            return Err(format!("cusolverDnDsyevd failed: {}", status));
        }

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

        cudaFree(d_a);
        cudaFree(d_w);
        cudaFree(d_info as *mut f64);
        cusolverDnDestroy(handle);

        Ok(GpuEigenResult {
            eigenvalues,
            eigenvectors,
            gpu_time_secs: gpu_time,
        })
    }
}

/// GPU spectral projections: eigendecomp + V^T b on GPU.
///
/// Returns eigenvalues + projection amplitudes c_k = ⟨b, v_k⟩
/// without downloading the full eigenvector matrix.
pub struct GpuProjectionResult {
    pub eigenvalues: Vec<f64>,
    pub projections: Vec<f64>,
    pub gpu_time_secs: f64,
}

pub fn gpu_spectral_projections(
    gram_data: &[f64],
    n: usize,
    b: &[f64],
) -> Result<GpuProjectionResult, String> {
    let n_i32 = n as c_int;
    let matrix_bytes = n * n * 8;
    let vec_bytes = n * 8;

    unsafe {
        let start = std::time::Instant::now();

        let mut solver: CusolverDnHandle = ptr::null_mut();
        let mut blas: CublasHandle = ptr::null_mut();
        cusolverDnCreate(&mut solver);
        cublasCreate_v2(&mut blas);

        let mut d_a: *mut f64 = ptr::null_mut();
        let mut d_w: *mut f64 = ptr::null_mut();
        let mut d_b: *mut f64 = ptr::null_mut();
        let mut d_c: *mut f64 = ptr::null_mut();
        let mut d_info: *mut c_int = ptr::null_mut();

        cudaMalloc(&mut d_a, matrix_bytes);
        cudaMalloc(&mut d_w, vec_bytes);
        cudaMalloc(&mut d_b, vec_bytes);
        cudaMalloc(&mut d_c, vec_bytes);
        cudaMalloc(&mut d_info as *mut *mut c_int as *mut *mut f64, 4);

        cudaMemcpy(
            d_a,
            gram_data.as_ptr(),
            matrix_bytes,
            CUDA_MEMCPY_HOST_TO_DEVICE,
        );
        cudaMemcpy(d_b, b.as_ptr(), vec_bytes, CUDA_MEMCPY_HOST_TO_DEVICE);

        // Eigendecomposition
        let mut lwork: c_int = 0;
        cusolverDnDsyevd_bufferSize(
            solver,
            CusolverEigMode::Vec,
            CublasFillMode::Lower,
            n_i32,
            d_a,
            n_i32,
            d_w,
            &mut lwork,
        );

        let mut d_work: *mut f64 = ptr::null_mut();
        cudaMalloc(&mut d_work, lwork as usize * 8);

        cusolverDnDsyevd(
            solver,
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
        cudaFree(d_work);

        // V^T b projection via cuBLAS
        let alpha = 1.0f64;
        let beta_val = 0.0f64;
        cublasDgemv_v2(
            blas, 1, // CUBLAS_OP_T
            n_i32, n_i32, &alpha, d_a, n_i32, d_b, 1, &beta_val, d_c, 1,
        );
        cudaDeviceSynchronize();

        // Download only eigenvalues + projections (tiny)
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

        cudaFree(d_a);
        cudaFree(d_w);
        cudaFree(d_b);
        cudaFree(d_c);
        cudaFree(d_info as *mut f64);
        cusolverDnDestroy(solver);
        cublasDestroy_v2(blas);

        Ok(GpuProjectionResult {
            eigenvalues,
            projections,
            gpu_time_secs: gpu_time,
        })
    }
}
