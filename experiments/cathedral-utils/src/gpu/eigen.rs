//! GPU eigendecomposition via cuSOLVER.
//!
//! Provides safe wrappers around cuSOLVER's `dsyevd` for symmetric matrices.
//! Three modes:
//! - Full eigendecomposition (eigenvalues + eigenvectors)
//! - Spectral projections (eigenvalues + V^T b, no eigenvector download)
//! - Eigenvalues only (minimal VRAM, ~2× faster)

use std::ffi::c_int;
use std::ptr;
use super::ffi;

/// Result of full GPU eigendecomposition.
pub struct EigenResult {
    /// Eigenvalues in ascending order.
    pub eigenvalues: Vec<f64>,
    /// Eigenvectors as column-major N×N matrix.
    pub eigenvectors: Vec<f64>,
    /// GPU computation time in seconds.
    pub gpu_time_secs: f64,
}

/// Result of spectral projection — eigenvalues + projection amplitudes.
/// The eigenvector matrix stays on GPU; only c = V^T b is downloaded.
pub struct SpectralResult {
    /// Eigenvalues in ascending order.
    pub eigenvalues: Vec<f64>,
    /// c_k = ⟨b, v_k⟩ — projection of b onto each eigenvector.
    pub projections: Vec<f64>,
    /// GPU computation time in seconds.
    pub gpu_time_secs: f64,
}

/// Full symmetric eigendecomposition on GPU.
///
/// Input: row-major Gram matrix (N×N).
/// Output: eigenvalues (ascending) + eigenvectors (column-major).
///
/// VRAM: ~2 × N² × 8 bytes (matrix + workspace).
/// For N=20,000: ~6 GB VRAM.
pub fn syevd(gram_data: &[f64], n: usize) -> Result<EigenResult, String> {
    let n_i32 = n as c_int;
    let matrix_bytes = n * n * 8;
    let vec_bytes = n * 8;

    // Convert row-major to column-major for cuSOLVER
    let mut col_major = vec![0.0f64; n * n];
    for i in 0..n {
        for j in 0..n {
            col_major[j * n + i] = gram_data[i * n + j];
        }
    }

    unsafe {
        let start = std::time::Instant::now();

        let mut handle: ffi::CusolverDnHandle = ptr::null_mut();
        let status = ffi::cusolverDnCreate(&mut handle);
        if status != 0 {
            return Err(format!("cusolverDnCreate failed: {}", status));
        }

        let mut d_a: *mut f64 = ptr::null_mut();
        let mut d_w: *mut f64 = ptr::null_mut();
        let mut d_info: *mut c_int = ptr::null_mut();

        let s1 = ffi::cudaMalloc(&mut d_a, matrix_bytes);
        let s2 = ffi::cudaMalloc(&mut d_w, vec_bytes);
        let s3 = ffi::cudaMalloc(&mut d_info as *mut *mut c_int as *mut *mut f64, 4);
        if s1 != 0 || s2 != 0 || s3 != 0 {
            ffi::cusolverDnDestroy(handle);
            return Err(format!("cudaMalloc failed: {},{},{}", s1, s2, s3));
        }

        ffi::cudaMemcpy(d_a, col_major.as_ptr(), matrix_bytes, ffi::MEMCPY_HOST_TO_DEVICE);

        let mut lwork: c_int = 0;
        ffi::cusolverDnDsyevd_bufferSize(
            handle, ffi::EigMode::Vec, ffi::FillMode::Lower,
            n_i32, d_a, n_i32, d_w, &mut lwork,
        );

        let mut d_work: *mut f64 = ptr::null_mut();
        ffi::cudaMalloc(&mut d_work, lwork as usize * 8);

        let status = ffi::cusolverDnDsyevd(
            handle, ffi::EigMode::Vec, ffi::FillMode::Lower,
            n_i32, d_a, n_i32, d_w, d_work, lwork, d_info,
        );
        ffi::cudaDeviceSynchronize();

        if status != 0 {
            ffi::cudaFree(d_a); ffi::cudaFree(d_w);
            ffi::cudaFree(d_work); ffi::cudaFree(d_info as *mut f64);
            ffi::cusolverDnDestroy(handle);
            return Err(format!("cusolverDnDsyevd failed: {}", status));
        }

        let mut eigenvalues = vec![0.0f64; n];
        let mut eigenvectors = vec![0.0f64; n * n];
        ffi::cudaMemcpy(eigenvalues.as_mut_ptr(), d_w, vec_bytes, ffi::MEMCPY_DEVICE_TO_HOST);
        ffi::cudaMemcpy(eigenvectors.as_mut_ptr(), d_a, matrix_bytes, ffi::MEMCPY_DEVICE_TO_HOST);

        let gpu_time = start.elapsed().as_secs_f64();

        ffi::cudaFree(d_a); ffi::cudaFree(d_w);
        ffi::cudaFree(d_work); ffi::cudaFree(d_info as *mut f64);
        ffi::cusolverDnDestroy(handle);

        Ok(EigenResult { eigenvalues, eigenvectors, gpu_time_secs: gpu_time })
    }
}

/// Spectral projections on GPU: eigenvalues + V^T b, without downloading V.
///
/// Saves ~N² × 8 bytes of device→host transfer by computing c = V^T b
/// via cuBLAS dgemv directly on GPU.
///
/// VRAM: ~N² × 8 (matrix) + workspace + 3 vectors.
pub fn spectral_projections(
    gram_data: &[f64], n: usize, b: &[f64],
) -> Result<SpectralResult, String> {
    let n_i32 = n as c_int;
    let matrix_bytes = n * n * 8;
    let vec_bytes = n * 8;

    unsafe {
        let start = std::time::Instant::now();

        let mut solver_handle: ffi::CusolverDnHandle = ptr::null_mut();
        let mut blas_handle: ffi::CublasHandle = ptr::null_mut();

        if ffi::cusolverDnCreate(&mut solver_handle) != 0 {
            return Err("cusolverDnCreate failed".into());
        }
        if ffi::cublasCreate_v2(&mut blas_handle) != 0 {
            ffi::cusolverDnDestroy(solver_handle);
            return Err("cublasCreate failed".into());
        }

        let mut d_a: *mut f64 = ptr::null_mut();
        let mut d_w: *mut f64 = ptr::null_mut();
        let mut d_b: *mut f64 = ptr::null_mut();
        let mut d_c: *mut f64 = ptr::null_mut();
        let mut d_info: *mut c_int = ptr::null_mut();

        ffi::cudaMalloc(&mut d_a, matrix_bytes);
        ffi::cudaMalloc(&mut d_w, vec_bytes);
        ffi::cudaMalloc(&mut d_b, vec_bytes);
        ffi::cudaMalloc(&mut d_c, vec_bytes);
        ffi::cudaMalloc(&mut d_info as *mut *mut c_int as *mut *mut f64, 4);

        // For symmetric matrices, row-major = column-major
        ffi::cudaMemcpy(d_a, gram_data.as_ptr(), matrix_bytes, ffi::MEMCPY_HOST_TO_DEVICE);
        ffi::cudaMemcpy(d_b, b.as_ptr(), vec_bytes, ffi::MEMCPY_HOST_TO_DEVICE);

        // Eigendecomposition
        let mut lwork: c_int = 0;
        ffi::cusolverDnDsyevd_bufferSize(
            solver_handle, ffi::EigMode::Vec, ffi::FillMode::Lower,
            n_i32, d_a, n_i32, d_w, &mut lwork,
        );

        let mut d_work: *mut f64 = ptr::null_mut();
        ffi::cudaMalloc(&mut d_work, lwork as usize * 8);

        let status = ffi::cusolverDnDsyevd(
            solver_handle, ffi::EigMode::Vec, ffi::FillMode::Lower,
            n_i32, d_a, n_i32, d_w, d_work, lwork, d_info,
        );
        ffi::cudaDeviceSynchronize();
        ffi::cudaFree(d_work);

        if status != 0 {
            ffi::cudaFree(d_a); ffi::cudaFree(d_w);
            ffi::cudaFree(d_b); ffi::cudaFree(d_c);
            ffi::cudaFree(d_info as *mut f64);
            ffi::cusolverDnDestroy(solver_handle);
            ffi::cublasDestroy_v2(blas_handle);
            return Err(format!("cusolverDnDsyevd failed: {}", status));
        }

        // c = V^T b via cuBLAS dgemv (V stays on GPU)
        let alpha = 1.0f64;
        let beta_val = 0.0f64;
        ffi::cublasDgemv_v2(
            blas_handle, ffi::OP_T,
            n_i32, n_i32,
            &alpha, d_a, n_i32,
            d_b, 1, &beta_val, d_c, 1,
        );
        ffi::cudaDeviceSynchronize();

        // Download eigenvalues + projections (tiny: 2 × N × 8 bytes)
        let mut eigenvalues = vec![0.0f64; n];
        let mut projections = vec![0.0f64; n];
        ffi::cudaMemcpy(eigenvalues.as_mut_ptr(), d_w, vec_bytes, ffi::MEMCPY_DEVICE_TO_HOST);
        ffi::cudaMemcpy(projections.as_mut_ptr(), d_c, vec_bytes, ffi::MEMCPY_DEVICE_TO_HOST);

        let gpu_time = start.elapsed().as_secs_f64();

        ffi::cudaFree(d_a); ffi::cudaFree(d_w);
        ffi::cudaFree(d_b); ffi::cudaFree(d_c);
        ffi::cudaFree(d_info as *mut f64);
        ffi::cusolverDnDestroy(solver_handle);
        ffi::cublasDestroy_v2(blas_handle);

        Ok(SpectralResult { eigenvalues, projections, gpu_time_secs: gpu_time })
    }
}

/// Eigenvalues only (NoVec mode) — much less VRAM than full decomposition.
///
/// For N=40,000: uses ~12.8 GB matrix + ~1 GB workspace ≈ 14 GB (fits RTX 4090).
/// Full mode would need ~25 GB (doesn't fit).
pub fn eigenvalues_only(gram_data: &[f64], n: usize) -> Result<(Vec<f64>, f64), String> {
    let n_i32 = n as c_int;
    let matrix_bytes = n * n * 8;
    let vec_bytes = n * 8;

    unsafe {
        let start = std::time::Instant::now();

        let mut handle: ffi::CusolverDnHandle = ptr::null_mut();
        if ffi::cusolverDnCreate(&mut handle) != 0 {
            return Err("cusolverDnCreate failed".into());
        }

        let mut d_a: *mut f64 = ptr::null_mut();
        let mut d_w: *mut f64 = ptr::null_mut();
        let mut d_info: *mut c_int = ptr::null_mut();

        ffi::cudaMalloc(&mut d_a, matrix_bytes);
        ffi::cudaMalloc(&mut d_w, vec_bytes);
        ffi::cudaMalloc(&mut d_info as *mut *mut c_int as *mut *mut f64, 4);

        ffi::cudaMemcpy(d_a, gram_data.as_ptr(), matrix_bytes, ffi::MEMCPY_HOST_TO_DEVICE);

        let mut lwork: c_int = 0;
        ffi::cusolverDnDsyevd_bufferSize(
            handle, ffi::EigMode::NoVec, ffi::FillMode::Lower,
            n_i32, d_a, n_i32, d_w, &mut lwork,
        );

        let mut d_work: *mut f64 = ptr::null_mut();
        let s = ffi::cudaMalloc(&mut d_work, lwork as usize * 8);
        if s != 0 {
            ffi::cudaFree(d_a); ffi::cudaFree(d_w);
            ffi::cudaFree(d_info as *mut f64);
            ffi::cusolverDnDestroy(handle);
            return Err(format!("workspace alloc failed: {}", s));
        }

        let status = ffi::cusolverDnDsyevd(
            handle, ffi::EigMode::NoVec, ffi::FillMode::Lower,
            n_i32, d_a, n_i32, d_w, d_work, lwork, d_info,
        );
        ffi::cudaDeviceSynchronize();

        ffi::cudaFree(d_work);
        ffi::cudaFree(d_a);

        if status != 0 {
            ffi::cudaFree(d_w); ffi::cudaFree(d_info as *mut f64);
            ffi::cusolverDnDestroy(handle);
            return Err(format!("cusolverDnDsyevd NoVec failed: {}", status));
        }

        let mut eigenvalues = vec![0.0f64; n];
        ffi::cudaMemcpy(eigenvalues.as_mut_ptr(), d_w, vec_bytes, ffi::MEMCPY_DEVICE_TO_HOST);

        let gpu_time = start.elapsed().as_secs_f64();
        ffi::cudaFree(d_w); ffi::cudaFree(d_info as *mut f64);
        ffi::cusolverDnDestroy(handle);

        Ok((eigenvalues, gpu_time))
    }
}
