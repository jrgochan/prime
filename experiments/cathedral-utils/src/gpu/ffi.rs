//! Raw FFI declarations for CUDA runtime, cuSOLVER, and cuBLAS.
//!
//! These are the low-level bindings used by the higher-level modules.
//! Application code should use [`super::eigen`], [`super::cholesky`], etc.

use std::ffi::c_int;

// ═══════════════════════════════════════════════════════════════════
// CUDA RUNTIME
// ═══════════════════════════════════════════════════════════════════

pub const MEMCPY_HOST_TO_DEVICE: c_int = 1;
pub const MEMCPY_DEVICE_TO_HOST: c_int = 2;

#[repr(C)]
pub struct CudaDeviceProp {
    pub name: [u8; 256],
    pub total_global_mem: usize,
    _padding: [u8; 1024],
}

#[link(name = "cudart")]
extern "C" {
    pub fn cudaMalloc(dev_ptr: *mut *mut f64, size: usize) -> c_int;
    pub fn cudaFree(dev_ptr: *mut f64) -> c_int;
    pub fn cudaMemcpy(dst: *mut f64, src: *const f64, count: usize, kind: c_int) -> c_int;
    pub fn cudaDeviceSynchronize() -> c_int;
    pub fn cudaGetDeviceProperties_v2(prop: *mut CudaDeviceProp, device: c_int) -> c_int;
}

// ═══════════════════════════════════════════════════════════════════
// cuSOLVER
// ═══════════════════════════════════════════════════════════════════

pub type CusolverDnHandle = *mut std::ffi::c_void;

#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum EigMode {
    NoVec = 0,
    Vec = 1,
}

#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum FillMode {
    Upper = 0,
    Lower = 1,
}

#[link(name = "cusolver")]
extern "C" {
    pub fn cusolverDnCreate(handle: *mut CusolverDnHandle) -> c_int;
    pub fn cusolverDnDestroy(handle: CusolverDnHandle) -> c_int;

    // Symmetric eigendecomposition
    pub fn cusolverDnDsyevd_bufferSize(
        handle: CusolverDnHandle,
        jobz: EigMode,
        uplo: FillMode,
        n: c_int,
        a: *const f64,
        lda: c_int,
        w: *const f64,
        lwork: *mut c_int,
    ) -> c_int;

    pub fn cusolverDnDsyevd(
        handle: CusolverDnHandle,
        jobz: EigMode,
        uplo: FillMode,
        n: c_int,
        a: *mut f64,
        lda: c_int,
        w: *mut f64,
        work: *mut f64,
        lwork: c_int,
        dev_info: *mut c_int,
    ) -> c_int;

    // Cholesky factorization
    pub fn cusolverDnDpotrf_bufferSize(
        handle: CusolverDnHandle,
        uplo: FillMode,
        n: c_int,
        a: *mut f64,
        lda: c_int,
        lwork: *mut c_int,
    ) -> c_int;

    pub fn cusolverDnDpotrf(
        handle: CusolverDnHandle,
        uplo: FillMode,
        n: c_int,
        a: *mut f64,
        lda: c_int,
        work: *mut f64,
        lwork: c_int,
        dev_info: *mut c_int,
    ) -> c_int;

    // Cholesky solve
    pub fn cusolverDnDpotrs(
        handle: CusolverDnHandle,
        uplo: FillMode,
        n: c_int,
        nrhs: c_int,
        a: *const f64,
        lda: c_int,
        b: *mut f64,
        ldb: c_int,
        dev_info: *mut c_int,
    ) -> c_int;
}

// ═══════════════════════════════════════════════════════════════════
// cuBLAS
// ═══════════════════════════════════════════════════════════════════

pub type CublasHandle = *mut std::ffi::c_void;

/// cuBLAS operation flags
pub const OP_N: c_int = 0; // No transpose
pub const OP_T: c_int = 1; // Transpose

#[link(name = "cublas")]
extern "C" {
    pub fn cublasCreate_v2(handle: *mut CublasHandle) -> c_int;
    pub fn cublasDestroy_v2(handle: CublasHandle) -> c_int;

    pub fn cublasDdot_v2(
        handle: CublasHandle,
        n: c_int,
        x: *const f64,
        incx: c_int,
        y: *const f64,
        incy: c_int,
        result: *mut f64,
    ) -> c_int;

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

// ═══════════════════════════════════════════════════════════════════
// CUSTOM CUDA KERNELS (DD, DS, QS Cholesky + Gram build)
// Auto-compiled by build.rs from src/gpu/cuda/*.cu
// The cfg flag `has_cuda_kernels` is set by build.rs when nvcc succeeds.
// ═══════════════════════════════════════════════════════════════════

#[cfg(has_cuda_kernels)]
#[link(name = "ddcholesky")]
extern "C" {
    pub fn gpu_dd_cholesky_d2(
        gram_hi: *const f64,
        gram_lo: *const f64,
        b: *const f64,
        dim: c_int,
        fail_col: *mut c_int,
    ) -> f64;
}

#[cfg(has_cuda_kernels)]
#[link(name = "dscholesky")]
extern "C" {
    pub fn gpu_ds_cholesky_d2(
        gram_hi: *const f64,
        gram_lo: *const f64,
        b: *const f64,
        dim: c_int,
        fail_col: *mut c_int,
    ) -> f64;
}

#[cfg(has_cuda_kernels)]
#[link(name = "qscholesky")]
extern "C" {
    pub fn gpu_qs_cholesky_d2(
        gram_hi: *const f64,
        gram_lo: *const f64,
        b: *const f64,
        dim: c_int,
        fail_col: *mut c_int,
    ) -> f64;
}

#[cfg(has_cuda_kernels)]
#[link(name = "gramgpu")]
extern "C" {
    pub fn gpu_build_gram_qs(
        ln_v0: *const f32,
        ln_v1: *const f32,
        ln_v2: *const f32,
        ln_v3: *const f32,
        ln_size: c_int,
        gram_hi: *mut f64,
        gram_lo: *mut f64,
        dim: c_int,
    ) -> c_int;

    pub fn gpu_gram_max_n() -> c_int;
}

#[cfg(has_cuda_kernels)]
#[link(name = "qqcholesky")]
extern "C" {
    pub fn gpu_qq_cholesky_d2(
        gram_hi: *const f64,
        gram_lo: *const f64,
        b: *const f64,
        dim: c_int,
        fail_col: *mut c_int,
    ) -> f64;
}

#[cfg(has_cuda_kernels)]
#[link(name = "grammatvec")]
extern "C" {
    /// Allocate device vectors for matrix-free matvec.
    pub fn gram_matvec_alloc(dim: c_int, d_x: *mut *mut f64, d_y: *mut *mut f64) -> c_int;
    /// Free device vectors.
    pub fn gram_matvec_free(d_x: *mut f64, d_y: *mut f64);
    /// Upload x vector to device.
    pub fn gram_matvec_upload_x(d_x: *mut f64, h_x: *const f64, dim: c_int);
    /// Download y vector from device.
    pub fn gram_matvec_download_y(d_y: *const f64, h_y: *mut f64, dim: c_int);
    /// Execute matrix-free matvec on GPU: y = G · x.
    pub fn gram_matvec_exec(d_x: *mut f64, d_y: *mut f64, dim: c_int, t_max: c_int);
    /// Full matvec: upload, compute, download.
    pub fn gram_matvec_full(
        d_x: *mut f64, d_y: *mut f64,
        h_x: *const f64, h_y: *mut f64,
        dim: c_int, t_max: c_int,
    );
}

// ═══════════════════════════════════════════════════════════════════
// GPU DETECTION
// ═══════════════════════════════════════════════════════════════════

/// Detect GPU and return device info, or None if no CUDA device found.
pub fn detect_gpu() -> Option<super::GpuInfo> {
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
        Some(super::GpuInfo { name, vram_mb })
    }
}
