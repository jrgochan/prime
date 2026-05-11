//! # Cathedral Utilities
//!
//! Shared library for the Cathedral numerical experiment suite.
//! Consolidates number theory, Gram matrix, spectral analysis,
//! Vasyunin formula, sieve witnesses, and certificate generation
//! into a single dependency.
//!
//! ## Modules
//!
//! - [`arith`] — Number theory primitives (gcd, sieve, Möbius, Liouville, factorize)
//! - [`abel`] — Abel summation engine (discrete summation by parts)
//! - [`constants`] — Mathematical constants (γ, ζ(2/3), digamma, harmonic, quadrature)
//! - [`coprime`] — Coprime pair generation and standard test datasets
//! - [`gram`] — Gram matrix engine (f64/MPFR, build-once, disk cache)
//! - [`lanczos`] — Lanczos iteration for partial eigendecomposition
//! - [`linalg`] — Dense linear algebra primitives (matvec, shifted matvec)
//! - [`mertens`] — Mertens function, Chebyshev θ/ψ, witness vectors
//! - [`rsvd`] — Randomized SVD (Halko-Martinsson-Tropp) for partial eigendecomp
//! - [`spectral`] — Eigendecomposition and participation ratio
//! - [`vasyunin`] — Vasyunin cotangent formula for Gram entries
//! - [`fitting`] — Curve fitting (linear regression, power-law, log-decay)
//! - [`certificate`] — JSON/TSV output generation
//! - [`cache`] — Binary matrix serialization to/from disk
//! - [`fmt`] — Terminal formatting constants
//! - [`gcd_decomp`] — GCD-class decomposition for Gram block structure
//! - [`gpu`] — GPU acceleration via CUDA/cuSOLVER/cuBLAS (feature-gated)
//! - [`hpdf`] — HDF5-based high-precision data format (feature-gated)
//! - [`octonion`] — Octonion algebra and prime-to-octonion encoding
//! - [`ooc`] — Out-of-core Gram matrix operations (disk-streamed)
//! - [`riemann_siegel`] — Riemann-Siegel theta, Hardy Z-function, zero finder
//! - [`spectral_stats`] — Random matrix theory diagnostics (GUE/GOE/GSE)

pub mod abel;
pub mod arith;
pub mod cache;
pub mod certificate;
pub mod constants;
pub mod coprime;
pub mod dd;
pub mod fitting;
pub mod fmt;
pub mod gcd_decomp;
pub mod gram;
pub mod gpu;
#[cfg(feature = "hpdf")]
pub mod hpdf;
pub mod jacobi;
pub mod lanczos;
pub mod linalg;
pub mod mertens;
pub mod octonion;
pub mod ooc;
pub mod riemann_siegel;
pub mod rsvd;
pub mod spectral;
pub mod spectral_stats;
pub mod vasyunin;
