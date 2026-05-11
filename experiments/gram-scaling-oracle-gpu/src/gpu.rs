//! ═══════════════════════════════════════════════════════════════════════════
//!  GPU EIGENDECOMPOSITION — cuSOLVER FFI
//!
//!  GPU-accelerated symmetric eigenvalue decomposition via cuSOLVER dsyevd.
//!  Follows the proven Cathedral FFI pattern from nb-distance-gpu.
//!
//!  Provides two modes:
//!    1. NoVec: eigenvalues only (smallest workspace, fits larger matrices)
//!    2. Vec:   eigenvalues + eigenvectors (for spectral projections)
//!
//!  On RTX 4090 (24 GB VRAM):
//!    - NoVec fits up to N ≈ 54,000 (23 GB matrix + ~1 GB workspace)
//!    - Vec fits up to N ≈ 39,000 (12 GB matrix + ~12 GB workspace)
//!
//! ═══════════════════════════════════════════════════════════════════════════

use std::ffi::c_int;
use std::ptr;
use std::time::Instant;

// ═══════════════════════════════════════════════════════════════
// cuSOLVER FFI TYPES
// ═══════════════════════════════════════════════════════════════

type CusolverDnHandle = *mut std::ffi::c_void;

#[repr(C)]
#[derive(Debug, Clone, Copy)]
#[allow(dead_code)]
enum CusolverEigMode {
    NoVec = 0,
    Vec = 1,
}

#[repr(C)]
#[derive(Debug, Clone, Copy)]
#[allow(dead_code)]
enum CublasFillMode {
    Upper = 0,
    Lower = 1,
}

// ═══════════════════════════════════════════════════════════════
// cuSOLVER FFI DECLARATIONS
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

// ═══════════════════════════════════════════════════════════════
// CUDA RUNTIME FFI
// ═══════════════════════════════════════════════════════════════

#[link(name = "cudart")]
extern "C" {
    fn cudaMalloc(devPtr: *mut *mut f64, size: usize) -> c_int;
    fn cudaFree(devPtr: *mut f64) -> c_int;
    fn cudaMemcpy(dst: *mut f64, src: *const f64, count: usize, kind: c_int) -> c_int;
    fn cudaDeviceSynchronize() -> c_int;
    fn cudaGetDeviceProperties_v2(prop: *mut CudaDeviceProp, device: c_int) -> c_int;
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

/// Detect and report GPU info.
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

/// Check if a matrix of dimension `dim` fits in GPU VRAM for NoVec mode.
/// NoVec needs: dim² × 8 (matrix) + ~2×dim×8 (workspace).
pub fn can_fit_novec(dim: usize, vram_mb: usize) -> bool {
    let matrix_mb = (dim * dim * 8) / (1024 * 1024);
    let workspace_mb = matrix_mb / 10 + 64; // rough estimate
    matrix_mb + workspace_mb < vram_mb
}

/// GPU eigenvalues-only via cuSOLVER dsyevd (NoVec mode).
///
/// Returns ALL eigenvalues sorted ascending, computed entirely on GPU.
/// Uses minimal workspace — fits matrices up to ~54K dim on 24 GB VRAM.
///
/// Input: row-major symmetric matrix (for symmetric, row = column major).
pub fn gpu_eigenvalues_only(data: &[f64], dim: usize) -> Result<(Vec<f64>, f64), String> {
    let n = dim as c_int;
    let matrix_bytes = dim * dim * 8;
    let vec_bytes = dim * 8;

    unsafe {
        let start = Instant::now();

        // Create cuSOLVER handle
        let mut handle: CusolverDnHandle = ptr::null_mut();
        let s = cusolverDnCreate(&mut handle);
        if s != 0 { return Err(format!("cusolverDnCreate failed: {}", s)); }

        // Allocate device memory
        let mut d_a: *mut f64 = ptr::null_mut();
        let mut d_w: *mut f64 = ptr::null_mut();
        let mut d_info: *mut c_int = ptr::null_mut();

        let s1 = cudaMalloc(&mut d_a, matrix_bytes);
        let s2 = cudaMalloc(&mut d_w, vec_bytes);
        let s3 = cudaMalloc(&mut d_info as *mut *mut c_int as *mut *mut f64, 4);
        if s1 != 0 || s2 != 0 || s3 != 0 {
            cusolverDnDestroy(handle);
            return Err(format!("cudaMalloc failed: {},{},{}", s1, s2, s3));
        }

        // Upload matrix to GPU
        cudaMemcpy(d_a, data.as_ptr(), matrix_bytes, CUDA_MEMCPY_HOST_TO_DEVICE);

        let t_upload = start.elapsed().as_secs_f64();
        eprintln!("    GPU upload: {:.1}s ({:.0} MB)", t_upload, matrix_bytes as f64 / 1e6);

        // Query workspace size (NoVec — much smaller than Vec)
        let mut lwork: c_int = 0;
        cusolverDnDsyevd_bufferSize(
            handle, CusolverEigMode::NoVec, CublasFillMode::Lower,
            n, d_a, n, d_w, &mut lwork,
        );
        let ws_mb = (lwork as usize * 8) / (1024 * 1024);
        eprintln!("    cuSOLVER workspace (NoVec): {} MB", ws_mb);

        let mut d_work: *mut f64 = ptr::null_mut();
        let s = cudaMalloc(&mut d_work, lwork as usize * 8);
        if s != 0 {
            cudaFree(d_a); cudaFree(d_w); cudaFree(d_info as *mut f64);
            cusolverDnDestroy(handle);
            return Err(format!("workspace alloc failed: {} ({} MB)", s, ws_mb));
        }

        // ═══ RUN EIGENDECOMPOSITION ═══
        let t_eigen = Instant::now();
        let status = cusolverDnDsyevd(
            handle, CusolverEigMode::NoVec, CublasFillMode::Lower,
            n, d_a, n, d_w, d_work, lwork, d_info,
        );
        cudaDeviceSynchronize();
        let eigen_secs = t_eigen.elapsed().as_secs_f64();
        eprintln!("    GPU eigenvalues (NoVec): {:.1}s", eigen_secs);

        // Free matrix + workspace immediately
        cudaFree(d_work);
        cudaFree(d_a);

        if status != 0 {
            cudaFree(d_w); cudaFree(d_info as *mut f64);
            cusolverDnDestroy(handle);
            return Err(format!("cusolverDnDsyevd NoVec failed: {}", status));
        }

        // Download eigenvalues
        let mut eigenvalues = vec![0.0f64; dim];
        cudaMemcpy(eigenvalues.as_mut_ptr(), d_w, vec_bytes, CUDA_MEMCPY_DEVICE_TO_HOST);

        let gpu_time = start.elapsed().as_secs_f64();
        cudaFree(d_w); cudaFree(d_info as *mut f64);
        cusolverDnDestroy(handle);

        eprintln!("    GPU total: {:.1}s", gpu_time);
        Ok((eigenvalues, gpu_time))
    }
}

/// Extract λ_min from GPU eigenvalue computation.
/// Returns (λ_min, gpu_time_secs).
pub fn gpu_lambda_min(data: &[f64], dim: usize) -> Result<(f64, f64), String> {
    let (eigenvalues, time) = gpu_eigenvalues_only(data, dim)?;
    Ok((eigenvalues[0], time))
}
