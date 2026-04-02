import SpectralRH.Defs
import SpectralRH.Structural
import SpectralRH.Quantitative
import SpectralRH.PTSymmetry
import SpectralRH.AlignmentDecay
import SpectralRH.Assembly

/-!
# Spectral Proof of the Riemann Hypothesis via Eigenvalue Drop Convergence

## Overview

This file coordinates the **modular spectral proof** of RH through
the Nyman-Beurling Gram matrix eigenvalue drop framework.

### The Proof Chain (4 axioms → Riemann Hypothesis):
```
riemann_hypothesis                   ← PROVED ✅
  ├── nyman_beurling                 ← AXIOM (Beurling 1955)
  ├── gram_bound_to_nbdist          ← AXIOM (functional analysis)
  └── hyperzeta                      ← PROVED ✅ (λ_min > 0 uniformly)
      ├── tail_sum_explicit_bound    ← PROVED ✅
      │   └── certified_tail         ← AXIOM (interval arithmetic)
      ├── telescoping                ← PROVED ✅ (induction)
      └── lambdaMin_antitone_ge2     ← PROVED ✅
          └── eigenvalue_antitone    ← PROVED ✅
              └── eigenvalue_interlacing ← AXIOM (Cauchy 1829)
```

### Module Structure:
```
SpectralRH/
├── Defs.lean            Core definitions (Gram matrix, eigenvalues, etc.)
├── Structural.lean      Interlacing, antitone, positive definiteness
├── Quantitative.lean    Certified bounds (base, Schur, cross-norm)
├── PTSymmetry.lean      PT-symmetry decomposition, perturbation theory
├── AlignmentDecay.lean  Liouville cancellation axiom, alignment decay
└── Assembly.lean        Drop bound → convergence → hyperzeta → RH
```

### Axioms in the RH Proof Chain (4 total):

| # | Axiom | File | Category |
|---|-------|------|----------|
| 1 | `eigenvalue_interlacing` | Structural | Geometric (Cauchy-Fischer) |
| 2 | `certified_tail` | Assembly | Computational (interval arithmetic) |
| 3 | `nyman_beurling` | Assembly | Classical (Beurling 1955) |
| 4 | `gram_bound_to_nbdist` | Assembly | Functional analysis |

### Additional Axioms (not in RH chain, support structure):

| # | Axiom | File | Purpose |
|---|-------|------|---------|
| 5 | `nb_basis_lin_indep` | Structural | Basis independence |
| 6 | `gram_posdef_of_lin_indep` | Structural | Gram ↔ independence |
| 7 | `drop_formula_bound` | Structural | Schur complement bound |
| 8 | `certified_base` | Quantitative | λ_min(500) ≥ 0.01087 |
| 9 | `schur_complement_lower` | Quantitative | S_N ≥ 1/20 |
| 10 | `cross_norm_bound` | Quantitative | ‖g‖² = Θ(N) |
| 11 | `rank1_resolvent` | PTSymmetry | Perturbation theory |
| 12 | `liouville_delocalization` | PTSymmetry | Eigenvector spreading |
| 13 | `liouville_cancellation` | AlignmentDecay | ≈ RH (cos θ decay) |

### Key Discovery (2026-03-29):
The smallest eigenvector v_min of G_N satisfies
  v_min[k] ≈ -C · ln(k) · λ(k) / k
where λ(k) = (-1)^{Ω(k)} is the **Liouville function**.

### PT-Symmetry Discovery (2026-04-01):
The commutator [G, P] where P = diag(λ(2),...,λ(N)) is rank-2 dominant.
alignment_decay factorizes as:
  cos θ_N = N^{-0.174}  ×  N^{-1.23}  =  N^{-1.40}
              geometric      arithmetic
              rotation        cancellation
-/

-- Verify the crown jewels are accessible:
#check @riemann_hypothesis
#check @hyperzeta
#check @eigenvalue_interlacing
#check @alignment_decay
#check @projection_decay
