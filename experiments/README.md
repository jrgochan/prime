# Experiments

Numerical verification and computational experiments supporting the Cathedral proof architecture.

## Directory Structure

### `gram-matrix/` — Gram Matrix Verification
Numerical experiments directly supporting the `offdiag_excess_sum_le` axiom.

| Experiment | Description | Key Result |
|-----------|-------------|------------|
| `gcd-sum-audit/` | GCD sum and off-diagonal excess verification (N ≤ 100k) | Sum ≈ −n/2, 18× safety margin |
| `selberg-validation/` | Selberg sieve weight validation, eigenvalue scaling | NB distance ∝ 1/log N confirmed |

### `spectral/` — Spectral Analysis
Eigenvalue structure and spectral gap experiments.

| Experiment | Description |
|-----------|-------------|
| `g2-spectral/` | G₂ Lie algebra spectral analysis |
| `spectral-fourier/` | Fourier-theoretic spectral decomposition |
| `parity-schur/` | Parity decomposition and Schur complement verification |

### `algebraic/` — Algebraic Structure Explorations
Algebraic approaches to the Gram matrix and RH.

| Experiment | Description |
|-----------|-------------|
| `quaternion-rh/` | Quaternionic reformulation exploration |
| `cross-class-verifier/` | Cross-class and Schur bridge verification |

### `numerical/` — Large-Scale Numerical Verification
Comprehensive numerical experiments.

| Experiment | Description |
|-----------|-------------|
| `weil-explicit/` | Large monolith: 47 Rust modules covering Weil explicit formula, GUE statistics, octonionic decorrelation, Nyman-Beurling criterion, operator theory, and more |

## Building

Each experiment is a standalone Rust project:

```bash
cd experiments/<category>/<name>
cargo run --release
```

## Relationship to Cathedral

The experiments provide **numerical evidence** for the Cathedral axioms but are not
part of the formal proof chain. The formal proofs live in `proofs/Cathedral/`.
