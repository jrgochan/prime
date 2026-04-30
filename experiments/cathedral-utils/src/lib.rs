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
//! - [`gram`] — Gram matrix engine (f64/MPFR, build-once, disk cache)
//! - [`spectral`] — Eigendecomposition and participation ratio
//! - [`vasyunin`] — Vasyunin cotangent formula for Gram entries
//! - [`fitting`] — Curve fitting (linear regression, power-law, log-decay)
//! - [`certificate`] — JSON/TSV output generation
//! - [`cache`] — Binary matrix serialization to/from disk
//! - [`fmt`] — Terminal formatting constants

pub mod arith;
pub mod cache;
pub mod certificate;
pub mod fitting;
pub mod fmt;
pub mod gram;
pub mod spectral;
pub mod vasyunin;
