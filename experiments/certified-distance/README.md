# 🏛️ certified-distance

Production-grade certified d²_N computation pipeline for the Cathedral formal verification project.

## What It Does

Computes **d²_N = 1 - b^T G_N^{-1} b** (the Nyman-Beurling distance) with multi-tier verification and produces independently verifiable JSON certificates.

The Nyman-Beurling criterion states that the Riemann Hypothesis is equivalent to:

> **d²_N → 0 as N → ∞**

Each certificate includes:
- **Distance computation** with GPU Cholesky or CPU fallback
- **Cross-validation** at higher precision (DD, QS Cholesky when available)
- **Spectral analysis** (λ_min, λ_max, condition number)
- **Monotonicity verification** against previous certificates
- **Matrix checksums** (SHA-256) for reproducibility
- **Lean-consumable claims** for formal verification

## Usage

```bash
# Certify a single N (auto-discovers cached matrices)
certified-distance certify 5000

# Certify using an explicit matrix file
certified-distance certify 40000 --source /path/to/dd_gram_N40000_mpfr256.bin

# Certify all cached matrices (sweep)
certified-distance sweep

# List discoverable matrices
certified-distance discover

# Verify an existing certificate
certified-distance verify certificates/cert_N5000.json

# Generate human-readable report
certified-distance report certificates/

# Generate Lean axiom file
certified-distance lean-export certificates/
```

## Building

```bash
# Without GPU (Mac development)
cargo build --release

# With GPU (WSL + CUDA)
cargo build --release --features gpu
```

## Certificate Format (v2)

```json
{
  "format": "cathedral-certified-distance-v2",
  "version": "1.0.0",
  "N": 5000,
  "dim": 4999,
  "distance": {
    "d_sq": 0.040872511101054,
    "method": "CPU_Cholesky_nalgebra",
    "precision_digits": 15,
    "compute_time_secs": 2.3,
    "cross_check": null
  },
  "spectrum": {
    "lambda_min": 3.5278e-7,
    "lambda_min_positive": true,
    "lambda_max": 5.4218,
    "condition_number": 1.537e7,
    "compute_time_secs": 8.1
  },
  "monotonicity": {
    "previous_n": 3000,
    "previous_d_sq": 0.041025,
    "strictly_decreased": true,
    "decrease_amount": 1.53e-4
  },
  "verification": {
    "matrix_source": "dd_gram_N5000_mpfr256.bin",
    "matrix_sha256": "a1b2c3d4...",
    "gram_formula": "G[j,k] = ∫₀¹ {1/(jx)}{1/(kx)} dx",
    "b_vector_formula": "b[j] = ∫₀¹ {1/(jx)} dx"
  },
  "lean_claims": [
    "nbDistSq' 5000 < 0.0409",
    "0 < lambdaMin 5000"
  ]
}
```

## Architecture

```
cathedral-utils/          ← Shared library
├── src/gpu/              ← Centralized CUDA bindings (feature-gated)
│   ├── ffi.rs            ← Raw FFI: cuSOLVER, cuBLAS, CUDA runtime
│   ├── eigen.rs          ← Eigendecomposition (syevd, spectral projections)
│   ├── cholesky.rs       ← Cholesky solver (f64, DD, DS, QS)
│   └── matvec.rs         ← GPU matvec for OOC CG solver
├── src/ooc.rs            ← Out-of-core format, matrix discovery
└── src/*.rs              ← Gram matrix, arithmetic, cache, etc.

certified-distance/       ← This experiment
├── src/main.rs           ← CLI entry point
├── src/certify.rs        ← Multi-tier certification logic
├── src/report.rs         ← Report generation, Lean export, verification
└── certificates/         ← Output directory
```
