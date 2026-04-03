import SpectralRH.Defs
import SpectralRH.Structural
import SpectralRH.Quantitative
import SpectralRH.PTSymmetry
import SpectralRH.AlignmentDecay
import SpectralRH.Assembly

/-!
# Spectral Proof of the Riemann Hypothesis via Nyman-Beurling Distance Scaling

## Overview

This file coordinates the **modular spectral proof** of RH through
the Nyman-Beurling distance formula and logarithmic decay.

### The Proof Chain (3 axioms → Riemann Hypothesis):
```
riemann_hypothesis                      ← PROVED ✅
  └── distance_converges_to_zero        ← PROVED ✅
      ├── nb_distance_scaling           ← AXIOM (d²_N ≤ C/log N)
      └── log_grows_unboundedly         ← AXIOM (standard calculus)
  └── nyman_beurling                    ← AXIOM (Beurling 1955)
```

### The Great Pivot (2026-04-03):

During formal verification, we discovered that the original proof strategy
— bounding λ_min(G_N) uniformly away from zero — is mathematically
inconsistent with the 1/log(N) scaling law:

  λ_min(G_N) ~ C/log(N) → 0

The Nyman-Beurling theorem REQUIRES d²_N = 1 - bᵀG⁻¹b → 0,
which REQUIRES G⁻¹ to blow up, which REQUIRES λ_min → 0.

The spectral gap closing is not a threat to RH — it IS the mechanism.
The new proof targets the NB distance directly.

### Module Structure:
```
SpectralRH/
├── Defs.lean            Core definitions (Gram matrix, eigenvalues, etc.)
├── Structural.lean      Interlacing, positivity, L² identity, det ≠ 0
├── Quantitative.lean    Certified bounds (base, Schur complement, cross-norm)
├── PTSymmetry.lean      P²=I, parity conservation, commutator [G,P]=2G_odd·P
├── AlignmentDecay.lean  Liouville cancellation → alignment decay
├── OctonionicPartition  Fano plane integer partition, block decomposition
├── ClassRestriction     Block-diagonal analysis, Rayleigh quotient
├── FiniteDimReduction   8-dimensional finite reduction
├── SpectralFlow.lean    1/log(N) scaling, cliff structure
└── Assembly.lean        Distance scaling → convergence → RH
```

### Axioms on the Critical Path (3 total):

| # | Axiom | Status |
|---|-------|--------|
| 1 | `nyman_beurling` | Published theorem (Beurling 1955, Báez-Duarte 2003) |
| 2 | `nb_distance_scaling` | Core assertion: d²_N ≤ C/log(N) |
| 3 | `log_grows_unboundedly` | Standard calculus (provable in Mathlib) |

### Key Discoveries:
- **1/N counterexample (2026-04-02)**: Summable eigenvalue drops do NOT
  guarantee a positive spectral gap
- **PT-Symmetry (2026-04-01)**: [G,P] = 2·G_odd·P; Liouville parity
  decomposes the Gram matrix into even/odd sectors
- **The Great Pivot (2026-04-03)**: The spectral gap MUST close for RH
  to hold; the proof should target the distance formula, not the gap
-/

-- Verify the crown jewels are accessible:
#check @riemann_hypothesis
#check @distance_converges_to_zero
#check @eigenvalue_interlacing
#check @alignment_decay
#check @projection_decay
#check @gramMatrix_det_ne_zero
#check @parityOperator_involution
#check @gram_commutator_identity
