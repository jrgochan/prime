# Experiments — Numerical Validation & Certification

Rust-based numerical experiments that validate the Cathedral's formal
proofs to high precision. Each experiment is a standalone Cargo project.

## Certification Pipeline (Direction 5.1)

The certified witness engine produces JSON certificates that formally
bridge the Rust computational engine to the Lean 4 proof architecture.

```bash
cd spectral/rank1-interference
cargo run --release --bin certified    # ~5 min on M2 Max
# Output: results/certificates/*.json
```

Each certificate links to the specific Lean theorem it validates:
- `lambdaMin_antitone_ge2` — eigenvalue positivity chain
- `existential_implies_infimum` — witness evaluation
- `forward_bridge_from_lambda_trick` — Rayleigh growth

## Experiment Tiers

### Tier 1: Critical Path (validate axioms on the main proof chain)

| Experiment | What it validates | Precision | Lean axiom |
|---|---|---|---|
| `spectral/rank1-interference/certified` ⭐ | Master certification | 256-bit MPFR | Multiple |
| `vasyunin-integral/` | Gram entry G(j,k) via FTC | 256-bit MPFR | `vasyuninGramEntry` |
| `covariance-probe/` | Eigenvalue decay λ_min ~ c/ln N | 128-bit | `millennium_covariance_cancellation` |
| `gram-oracle/` | BD L² error 1-2bᵀv+vᵀGv | 128-bit | `witness_l2_error_decay_gram` |
| `baez-duarte/` | BD distance X/ln N → 21.649 | 512-bit | `nyman_beurling_equivalence_mellin` |
| `abel-bridge/` | Abel summation verification | 64-bit | `abel_mertens_tail_raw` |

### Tier 2: Structural Validation

| Experiment | What it validates | Lean file |
|---|---|---|
| `spectral/rank1-interference/highprec` | Rank-1, λ_eff, R ratio | `FiniteDimReduction.lean` |
| `spectral/parity-schur/` | Lichnerowicz decomposition | `ParitySchur.lean` |
| `spectral/offdiag-excess/` | Off-diagonal bounds | `GramBounds.lean` |
| `spectral-analyzer/` | Witness comparison | `WitnessConditional.lean` |
| `spectral/lambda-eff/` | λ_eff growth | `ClassRestriction.lean` |
| `gram-matrix/selberg-validation/` | Selberg constants | `BilinearSieve.lean` |

### Tier 3: Exploratory

| Experiment | What it explores |
|---|---|
| `spectral/g2-spectral/` | G₂ Lie group action on octonionic structures |
| `spectral/spectral-fourier/` | Riemann-Siegel zero computation |
| `numerical/weil-explicit/` | 40+ sub-experiments (legacy) |
| `algebraic/` | Quaternionic/cross-class structures |

### Tier 4: Historical (superseded)

| Experiment | Superseded by |
|---|---|
| `vasyunin/` (attacks 8-10) | `vasyunin-integral/` |
| `mobius-basis/` (attack 5) | `covariance-probe/` |
| `contour-oracle/` | `abel-bridge/` + `covariance-probe/` |

## Quick Start

Each experiment is a standalone Rust project:

```bash
cd vasyunin-integral
cargo run --release    # ~30 seconds
```

Results are written to `results/` or `output/` or `*.json`.

## Key Results

### Certified Witness Engine (April 22, 2026)
256-bit MPFR certification for N=10..1000:
- All Gram matrices positive definite ✓
- λ_min monotonically non-increasing ✓
- All d²_N > 0 ✓
- S²/Q → Báez-Duarte constant ≈ 21.649 ✓

### Vasyunin Integral (April 20, 2026)
256-bit MPFR verification of all 60 Gram matrix entries G(j,k)
for j,k ≤ 10, matching the Vasyunin cotangent formula to 6–7
decimal digits.

### BD Distance
Q_N/ln N monotonically increases toward C ≈ 21.649, confirming
the Báez-Duarte constant to 4 significant digits at N = 5000.

### High-Precision Spectral (April 21, 2026)
256-bit verification of spectral claims for N=50..2000:
- Rank-1 conjecture REFUTED (decay from 98.6% to 90.7%)
- λ_eff growth confirmed logarithmic, not linear
- f64 precision validated to < 5e-14
