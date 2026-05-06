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
//! - [`coprime`] — Coprime pair generation and standard test datasets
//! - [`gram`] — Gram matrix engine (f64/MPFR, build-once, disk cache)
//! - [`mertens`] — Mertens function, Chebyshev θ/ψ, witness vectors
//! - [`spectral`] — Eigendecomposition and participation ratio
//! - [`vasyunin`] — Vasyunin cotangent formula for Gram entries
//! - [`fitting`] — Curve fitting (linear regression, power-law, log-decay)
//! - [`certificate`] — JSON/TSV output generation
//! - [`cache`] — Binary matrix serialization to/from disk
//! - [`fmt`] — Terminal formatting constants
//! - [`gpu`] — GPU acceleration via CUDA/cuSOLVER/cuBLAS (feature-gated)
//! - [`ooc`] — Out-of-core Gram matrix operations (disk-streamed)

pub mod abel;
pub mod arith;
pub mod cache;
pub mod certificate;
pub mod coprime;
pub mod dd;
pub mod fitting;
pub mod fmt;
pub mod gram;
pub mod gpu;
pub mod mertens;
pub mod ooc;
pub mod spectral;
pub mod vasyunin;
