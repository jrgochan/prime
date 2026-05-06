//! GPU Cholesky-based d² computation.
//!
//! Computes d²_N = 1 - b^T G_N^{-1} b using Cholesky factorization.
//!
//! ## Precision Tiers
//!
//! | Tier | Method | Precision | Speed | VRAM |
//! |------|--------|-----------|-------|------|
//! | 1 | cuSOLVER dpotrf/dpotrs | ~15 digits | Fast | N²×8 |
//! | 2 | DD Cholesky (CUDA kernel) | ~31 digits | Moderate | 2×N²×8 |
//! | 3 | DS Cholesky (CUDA kernel) | ~14 digits | Very fast | 2×N²×4 |
//! | 4 | QS Cholesky (CUDA kernel) | ~28 digits | Fast | 4×N²×4 |

use std::ffi::c_int;
use super::ffi;

/// Result from any Cholesky-based d² computation.
#[derive(Debug, Clone)]
pub struct CholeskyResult {
    /// d²_N = 1 - b^T G_N^{-1} b
    pub d_sq: f64,
    /// Column where factorization failed (0 = success).
    pub fail_col: i32,
    /// GPU computation time in seconds.
    pub gpu_time_secs: f64,
    /// Precision tier used.
    pub method: &'static str,
    /// Approximate number of correct digits.
    pub precision_digits: u32,
}

/// Compute d² via standard f64 Cholesky (cuSOLVER dpotrf + dpotrs).
///
/// Input: row-major Gram matrix (N×N) and b vector.
/// Output: d² = 1 - b^T G^{-1} b (~15 digit precision).
///
/// VRAM: N² × 8 bytes (matrix) + workspace.
pub fn d_sq_f64(gram_data: &[f64], b: &[f64], dim: usize) -> Result<CholeskyResult, String> {
    let n = dim as c_int;
    let matrix_bytes = dim * dim * 8;
    let vec_bytes = dim * 8;

    // Convert row-major to column-major
    let mut col_major = vec![0.0f64; dim * dim];
    for i in 0..dim {
        for j in 0..dim {
            col_major[j * dim + i] = gram_data[i * dim + j];
        }
    }

    unsafe {
        let start = std::time::Instant::now();

        let mut handle: ffi::CusolverDnHandle = std::ptr::null_mut();
        if ffi::cusolverDnCreate(&mut handle) != 0 {
            return Err("cusolverDnCreate failed".into());
        }

        let mut d_a: *mut f64 = std::ptr::null_mut();
        let mut d_b: *mut f64 = std::ptr::null_mut();
        let mut d_info: *mut c_int = std::ptr::null_mut();

        ffi::cudaMalloc(&mut d_a, matrix_bytes);
        ffi::cudaMalloc(&mut d_b, vec_bytes);
        ffi::cudaMalloc(&mut d_info as *mut *mut c_int as *mut *mut f64, 4);

        ffi::cudaMemcpy(d_a, col_major.as_ptr(), matrix_bytes, ffi::MEMCPY_HOST_TO_DEVICE);
        ffi::cudaMemcpy(d_b, b.as_ptr(), vec_bytes, ffi::MEMCPY_HOST_TO_DEVICE);

        // Cholesky factorization
        let mut lwork: c_int = 0;
        ffi::cusolverDnDpotrf_bufferSize(handle, ffi::FillMode::Lower, n, d_a, n, &mut lwork);

        let mut d_work: *mut f64 = std::ptr::null_mut();
        ffi::cudaMalloc(&mut d_work, lwork as usize * 8);

        let s = ffi::cusolverDnDpotrf(handle, ffi::FillMode::Lower, n, d_a, n, d_work, lwork, d_info);
        ffi::cudaDeviceSynchronize();

        let mut info_val: c_int = 0;
        ffi::cudaMemcpy(
            &mut info_val as *mut c_int as *mut f64,
            d_info as *const f64, 4, ffi::MEMCPY_DEVICE_TO_HOST,
        );

        if s != 0 || info_val != 0 {
            ffi::cudaFree(d_a); ffi::cudaFree(d_b);
            ffi::cudaFree(d_work); ffi::cudaFree(d_info as *mut f64);
            ffi::cusolverDnDestroy(handle);
            return Err(format!("dpotrf failed: status={}, info={}", s, info_val));
        }

        // Solve L L^T x = b
        let s = ffi::cusolverDnDpotrs(handle, ffi::FillMode::Lower, n, 1, d_a, n, d_b, n, d_info);
        ffi::cudaDeviceSynchronize();

        if s != 0 {
            ffi::cudaFree(d_a); ffi::cudaFree(d_b);
            ffi::cudaFree(d_work); ffi::cudaFree(d_info as *mut f64);
            ffi::cusolverDnDestroy(handle);
            return Err(format!("dpotrs failed: {}", s));
        }

        // Compute b^T x on GPU
        let mut blas_handle: ffi::CublasHandle = std::ptr::null_mut();
        let mut dot_result = 0.0f64;
        let mut d_b_orig: *mut f64 = std::ptr::null_mut();
        ffi::cudaMalloc(&mut d_b_orig, vec_bytes);
        ffi::cudaMemcpy(d_b_orig, b.as_ptr(), vec_bytes, ffi::MEMCPY_HOST_TO_DEVICE);

        if ffi::cublasCreate_v2(&mut blas_handle) == 0 {
            ffi::cublasDdot_v2(blas_handle, n, d_b_orig, 1, d_b, 1, &mut dot_result);
            ffi::cublasDestroy_v2(blas_handle);
        } else {
            let mut x = vec![0.0f64; dim];
            ffi::cudaMemcpy(x.as_mut_ptr(), d_b, vec_bytes, ffi::MEMCPY_DEVICE_TO_HOST);
            dot_result = b.iter().zip(x.iter()).map(|(bi, xi)| bi * xi).sum();
        }

        let gpu_time = start.elapsed().as_secs_f64();

        ffi::cudaFree(d_a); ffi::cudaFree(d_b); ffi::cudaFree(d_b_orig);
        ffi::cudaFree(d_work); ffi::cudaFree(d_info as *mut f64);
        ffi::cusolverDnDestroy(handle);

        Ok(CholeskyResult {
            d_sq: 1.0 - dot_result,
            fail_col: 0,
            gpu_time_secs: gpu_time,
            method: "GPU_Cholesky_f64",
            precision_digits: 15,
        })
    }
}

/// Compute d² via DD Cholesky (~31 digit precision).
///
/// Input: DD Gram matrix (hi + lo components), b vector.
/// Requires the `custom_kernels` feature and compiled CUDA libraries.
#[cfg(has_cuda_kernels)]
pub fn d_sq_dd(
    gram_hi: &[f64], gram_lo: &[f64], b: &[f64], dim: usize,
) -> Result<CholeskyResult, String> {
    if gram_hi.len() != dim * dim || gram_lo.len() != dim * dim {
        return Err(format!("Gram size mismatch: {} vs {}²", gram_hi.len(), dim));
    }
    if b.len() < dim {
        return Err(format!("b vector too short: {} < {}", b.len(), dim));
    }

    unsafe {
        let start = std::time::Instant::now();
        let mut fail_col: c_int = 0;
        let d2 = ffi::gpu_dd_cholesky_d2(
            gram_hi.as_ptr(), gram_lo.as_ptr(), b.as_ptr(),
            dim as c_int, &mut fail_col,
        );
        let gpu_time = start.elapsed().as_secs_f64();

        Ok(CholeskyResult {
            d_sq: d2,
            fail_col: fail_col as i32,
            gpu_time_secs: gpu_time,
            method: "GPU_DD_Cholesky_31digit",
            precision_digits: 31,
        })
    }
}

/// Compute d² via QS Cholesky (~28 digit precision at f32 speed).
#[cfg(has_cuda_kernels)]
pub fn d_sq_qs(
    gram_hi: &[f64], gram_lo: &[f64], b: &[f64], dim: usize,
) -> Result<CholeskyResult, String> {
    if gram_hi.len() != dim * dim || gram_lo.len() != dim * dim {
        return Err(format!("Gram size mismatch: {} vs {}²", gram_hi.len(), dim));
    }

    unsafe {
        let start = std::time::Instant::now();
        let mut fail_col: c_int = 0;
        let d2 = ffi::gpu_qs_cholesky_d2(
            gram_hi.as_ptr(), gram_lo.as_ptr(), b.as_ptr(),
            dim as c_int, &mut fail_col,
        );
        let gpu_time = start.elapsed().as_secs_f64();

        Ok(CholeskyResult {
            d_sq: d2,
            fail_col: fail_col as i32,
            gpu_time_secs: gpu_time,
            method: "GPU_QS_Cholesky_28digit",
            precision_digits: 28,
        })
    }
}

/// Compute d² via DS Cholesky (~14 digit precision, fastest).
#[cfg(has_cuda_kernels)]
pub fn d_sq_ds(
    gram_hi: &[f64], gram_lo: &[f64], b: &[f64], dim: usize,
) -> Result<CholeskyResult, String> {
    if gram_hi.len() != dim * dim || gram_lo.len() != dim * dim {
        return Err(format!("Gram size mismatch: {} vs {}²", gram_hi.len(), dim));
    }

    unsafe {
        let start = std::time::Instant::now();
        let mut fail_col: c_int = 0;
        let d2 = ffi::gpu_ds_cholesky_d2(
            gram_hi.as_ptr(), gram_lo.as_ptr(), b.as_ptr(),
            dim as c_int, &mut fail_col,
        );
        let gpu_time = start.elapsed().as_secs_f64();

        Ok(CholeskyResult {
            d_sq: d2,
            fail_col: fail_col as i32,
            gpu_time_secs: gpu_time,
            method: "GPU_DS_Cholesky_14digit",
            precision_digits: 14,
        })
    }
}

