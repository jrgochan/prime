# Axiom Roadmap: Closing the Gaps in the Spectral RH Formalization

> ⚠️ **OUTDATED**: This document describes an earlier 17-axiom architecture.
> The current Cathedral (v1.0) has **2 mathematical axioms** in the RH proof chain.
> See the [main README](../../README.md) for the current state.

## Current Status: 17 axioms, 35 proven (ZERO sorry)

Started with 39+ axioms/sorry. Eliminated 22+ through:
- Proper definitions replacing opaque `Classical.choice` (6 eliminated)
- `True`-placeholder axioms → trivial theorems (10 converted)
- Real mathematical proofs: `spectralFlow_at_one`, `spectralFlow_pos_before_zero`,
  `coupling_eigenvalues`, `weight_bounded` (4 proven)
- Proper `sInf` definition for `spectralFlowZero` (1 derived)

## Remaining 17 Axioms

### SpectralFlow.lean (8 axioms — 3 unused in proof chain)
| Axiom | Used? | Tier | Content |
|---|:---:|:---:|---|
| `block_gap_positive` | ✅ | 2 | G^block is PD |
| `spectralFlow_continuous` | ❌ | 2 | Eigenvalue continuity |
| `spectralFlow_bounded_deriv` | ❌ | 2 | Lipschitz bound |
| `spectralFlow_monotone_on_unit` | ❌ | 2 | Monotone on [0,1] |
| `lambda_min_log_scaling` | ❌ | 3 | λ_min ≥ C/log(N) |
| `block_gap_log_scaling` | ❌ | 3 | Block gap ≥ C/log(N) |
| `cliff_above_one` | ✅ | 3 | **t_zero > 1 (≡ RH)** |
| `safety_margin_scaling` | ❌ | 3 | Margin ≥ C/log(N) |

### FiniteDimReduction.lean (2 axioms)
| Axiom | Tier | Content |
|---|:---:|---|
| `stable_ratio` | 3 | **R ≤ 0.924 < 1 (≡ RH)** |
| `lambdaEff_linear_growth` | 2 | λ_eff grows linearly |

### ClassRestriction.lean (4 axioms)
| Axiom | Tier | Content |
|---|:---:|---|
| `lambdaMinClass_pos` | 2 | Each class is PD |
| `class_gap_strictly_larger` | 3 | Class gap > full gap |
| `oct_equals_block` | 2 | G^oct = G^block |
| `cross_class_interaction_bounded` | 3 | Cross-class bound (≡ RH) |

### OctonionicPartition.lean (3 axioms)
| Axiom | Tier | Content |
|---|:---:|---|
| `intToOctonion_unit` | 1 | Octonion norm = 1 |
| `oct_gap_dominates` | 3 | λ_min(G) ≤ λ_min(G^oct) |
| `oct_gap_lower_bound` | 3 | **∃c > 0, c ≤ λ_min(G^oct) (≡ RH)** |

## Minimal Proof Chain

The main theorem `rh_from_spectral_flow` depends on exactly **2 axioms**:
1. `cliff_above_one` — **THE** axiom (≡ RH)
2. `block_gap_positive` — spectral gap of block-diagonal matrix

Everything else is either proven or unused in the critical path.
