# cathedral-utils

Shared library for the Cathedral numerical experiments.

## What It Provides

Core mathematical routines used across 50+ experiment binaries:

| Module | Content |
|--------|---------|
| `gram.rs` | Gram matrix construction `G(j,k) = ∫₀¹ {1/jx}{1/kx} dx` |
| `vasyunin.rs` | Vasyunin cotangent formula for Gram entries |
| `dd.rs` | Double-double (31-digit) arithmetic via Dekker-Knuth |
| `jacobi.rs` | Eigenvalue decomposition (MPFR-backed Jacobi rotations) |
| `lanczos.rs` | Lanczos iteration for large sparse eigenvalue problems |
| `mertens.rs` | Mertens function and Möbius sum evaluation |
| `abel.rs` | Abel summation infrastructure |
| `spectral.rs` | Spectral analysis utilities |
| `certificate.rs` | JSON certificate generation for Lean oracle axioms |
| `arith.rs` | Arithmetic functions (divisor sums, totient, etc.) |
| `hpdf/` | High-Precision Decimal Float backend |
| `gpu/` | CUDA acceleration for Gram matrix builds |

## Binaries

- **`gram-builder`** — Build and export Gram matrices at arbitrary N
- **`hpdf`** — High-precision decimal float computation pipeline

## Usage

This is a library crate — it's used as a dependency by the other experiments:

```toml
[dependencies]
cathedral-utils = { path = "../cathedral-utils" }
```
