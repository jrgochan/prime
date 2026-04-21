//! Zeta function library — the computational foundation of the Cathedral.
//!
//! This module provides Rust implementations of every mathematical construct
//! used in the Cathedral's formal proof of the Riemann Hypothesis.
//!
//! ## Module Map → Cathedral Axioms
//!
//! | Module           | Cathedral Axioms Covered              |
//! |------------------|---------------------------------------|
//! | `zeros`          | Zero database (LMFDB, 200 entries)    |
//! | `arithmetic`     | μ(n), Λ(n), Li(x), primes            |
//! | `dirichlet`      | ζ(s,N), partial sums, χ(s), ∏ₚ       |
//! | `mertens`        | M(x), PNT sums, Abel summation       |
//! | `nyman_beurling` | BD/NB basis, Gram matrix, d²_N, Mellin|
//! | `vasyunin`       | Off-diagonal integrals, covariance    |
//! | `hardy`          | Z(t), θ(t), Gram points, η(s)        |
//!
//! All zeros sourced from LMFDB / Odlyzko tables.
//! Precision: f64 (≈15 significant digits).

pub mod zeros;
pub mod arithmetic;
pub mod dirichlet;
pub mod mertens;
pub mod nyman_beurling;
pub mod vasyunin;
pub mod hardy;
