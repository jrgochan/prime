# Experiments — Numerical Validation

Rust-based numerical experiments that validate the Cathedral's formal
proofs to high precision. Each experiment is a standalone Cargo project.

## Which Experiment Should I Run?

| Experiment | What it validates | Precision |
|-----------|-------------------|-----------|
| `vasyunin-integral/` | Gram matrix entries G(j,k) via piecewise FTC | 256-bit MPFR (6–7 digits) |
| `covariance-probe/` | Eigenvalue decay λ_min ~ c/ln N | 128-bit MPFR |
| `gram-oracle/` | Original spectral Gram computation | 128-bit |
| `baez-duarte/` | BD distance Q_N/ln N → 21.65 | 64-bit |
| `abel-bridge/` | Abel summation numerical verification | 64-bit |
| `spectral-analyzer/` | Eigenvalue distribution analysis | 128-bit |
| `contour-oracle/` | Contour integral validation | 128-bit |
| `mobius-basis/` | Möbius weight optimization | 64-bit |

## Quick Start

Each experiment is a standalone Rust project:

```bash
cd vasyunin-integral
cargo run --release    # ~30 seconds
```

Results are written to `results.json` and/or `results.tsv`.

## Key Results

### Vasyunin Integral (April 20, 2026)
256-bit MPFR verification of all 60 Gram matrix entries G(j,k)
for j,k ≤ 10, matching the Vasyunin cotangent formula to 6–7
decimal digits.

### BD Distance
Q_N/ln N monotonically increases toward C ≈ 21.65, confirming
the Báez-Duarte constant to 4 significant digits at N = 5000.

### Additional Experiments

The `spectral/`, `algebraic/`, `numerical/`, and `gram-matrix/`
subdirectories contain earlier explorations that informed the
proof architecture.
