//! GPU-accelerated matrix-vector multiply for OOC CG solver.
//!
//! Computes y = G · x where G is memory-mapped from disk.
//! The matrix is processed in chunks that fit GPU VRAM.

use std::ffi::c_int;
use super::ffi;

/// GPU state for chunk-based matrix-vector multiplication.
/// Keeps the x vector resident on GPU across chunks.
pub struct MatvecState {
    blas_handle: ffi::CublasHandle,
    d_x: *mut f64,
    d_chunk: *mut f64,
    d_y_chunk: *mut f64,
    pub chunk_rows: usize,
    pub dim: usize,
}

impl MatvecState {
    /// Create a new GPU matvec state.
    ///
    /// Allocates GPU buffers for the x vector and a chunk of matrix rows.
    /// `chunk_rows` controls the tradeoff between GPU utilization and VRAM usage.
    pub fn new(dim: usize, chunk_rows: usize) -> Result<Self, String> {
        let vec_bytes = dim * 8;
        let chunk_bytes = chunk_rows * dim * 8;
        let chunk_y_bytes = chunk_rows * 8;

        unsafe {
            let mut blas_handle: ffi::CublasHandle = std::ptr::null_mut();
            let s = ffi::cublasCreate_v2(&mut blas_handle);
            if s != 0 { return Err(format!("cublasCreate failed: {}", s)); }

            let mut d_x: *mut f64 = std::ptr::null_mut();
            let mut d_chunk: *mut f64 = std::ptr::null_mut();
            let mut d_y_chunk: *mut f64 = std::ptr::null_mut();

            let s1 = ffi::cudaMalloc(&mut d_x, vec_bytes);
            let s2 = ffi::cudaMalloc(&mut d_chunk, chunk_bytes);
            let s3 = ffi::cudaMalloc(&mut d_y_chunk, chunk_y_bytes);
            if s1 != 0 || s2 != 0 || s3 != 0 {
                ffi::cublasDestroy_v2(blas_handle);
                return Err(format!("cudaMalloc failed: {},{},{}", s1, s2, s3));
            }

            Ok(MatvecState {
                blas_handle, d_x, d_chunk, d_y_chunk,
                chunk_rows, dim,
            })
        }
    }

    /// Upload x vector to GPU (call once per CG iteration).
    pub fn upload_x(&self, x: &[f64]) {
        unsafe {
            ffi::cudaMemcpy(self.d_x, x.as_ptr(), x.len() * 8, ffi::MEMCPY_HOST_TO_DEVICE);
        }
    }

    /// Multiply a chunk of rows by x on GPU: y_chunk = chunk × x.
    ///
    /// `chunk` is `rows × dim` in row-major order.
    pub fn matvec_chunk(&self, chunk: &[f64], rows: usize, y_out: &mut [f64]) {
        let m = rows as c_int;
        let n = self.dim as c_int;
        let alpha = 1.0f64;
        let beta_val = 0.0f64;

        unsafe {
            // Upload chunk
            ffi::cudaMemcpy(self.d_chunk, chunk.as_ptr(), rows * self.dim * 8, ffi::MEMCPY_HOST_TO_DEVICE);

            // cuBLAS dgemv: row-major A → col-major A^T
            // y = A_rowmajor * x  ⟹  cuBLAS: y = (A_colmajor)^T * x
            ffi::cublasDgemv_v2(
                self.blas_handle,
                ffi::OP_T,
                n, m,
                &alpha,
                self.d_chunk, n,
                self.d_x, 1,
                &beta_val,
                self.d_y_chunk, 1,
            );

            // Download result
            ffi::cudaMemcpy(y_out.as_mut_ptr(), self.d_y_chunk, rows * 8, ffi::MEMCPY_DEVICE_TO_HOST);
        }
    }
}

impl Drop for MatvecState {
    fn drop(&mut self) {
        unsafe {
            ffi::cudaFree(self.d_x);
            ffi::cudaFree(self.d_chunk);
            ffi::cudaFree(self.d_y_chunk);
            ffi::cublasDestroy_v2(self.blas_handle);
        }
    }
}

// Safety: GPU handles are thread-safe in the CUDA runtime model
unsafe impl Send for MatvecState {}
unsafe impl Sync for MatvecState {}
