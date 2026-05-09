//! # GPU Acceleration Module
//!
//! Centralized CUDA/cuSOLVER/cuBLAS bindings for all Cathedral experiments.
//! Gated behind the `gpu` feature flag — compiles to no-ops without CUDA.
//!
//! ## Submodules
//!
//! - [`ffi`] — Raw FFI declarations (cuSOLVER, cuBLAS, CUDA runtime)
//! - [`eigen`] — Symmetric eigendecomposition (full spectrum + spectral projections)
//! - [`cholesky`] — Cholesky-based d² computation (f64, DD, DS, QS precision tiers)
//! - [`matvec`] — GPU-accelerated matrix-vector multiply (for OOC CG solver)
//!
//! ## Usage
//!
//! ```rust,ignore
//! use cathedral_utils::gpu;
//!
//! if let Some(info) = gpu::detect() {
//!     println!("GPU: {} ({} MB)", info.name, info.vram_mb);
//!     let result = gpu::eigen::syevd(&gram_data, n)?;
//! }
//! ```

#[cfg(feature = "gpu")]
pub mod ffi;

#[cfg(feature = "gpu")]
pub mod eigen;

#[cfg(feature = "gpu")]
pub mod cholesky;

#[cfg(feature = "gpu")]
pub mod matvec;

#[cfg(feature = "gpu")]
pub mod bilinear;

/// GPU device information.
#[derive(Debug, Clone)]
pub struct GpuInfo {
    pub name: String,
    pub vram_mb: usize,
}

/// Detect available GPU. Returns `None` if no CUDA device is found
/// or if compiled without the `gpu` feature.
#[cfg(feature = "gpu")]
pub fn detect() -> Option<GpuInfo> {
    ffi::detect_gpu()
}

#[cfg(not(feature = "gpu"))]
pub fn detect() -> Option<GpuInfo> {
    None
}

/// Check if GPU support is compiled in.
pub fn is_available() -> bool {
    cfg!(feature = "gpu")
}
