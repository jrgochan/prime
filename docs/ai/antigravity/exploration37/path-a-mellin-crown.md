# Path A: Mellin Crown — The Classical Approach

## Status: ANALYZED (Crown axiom path, well-understood)

## Overview

Path A is the **classical** approach to the Nyman-Beurling criterion.
It uses the Mellin transform to connect the L²(0,1) distance to the
Dirichlet series behavior of ζ(s) near the critical line.

The chain:
```
RH → M(x) = O(x^{1/2+ε}) → |Σ μ(k)/k^s| bounded for σ > 1/2
   → v^T G v ≤ 1 + C/log N → d²_N → 0 at rate 1/log N
```

## The Crown Axiom

```lean
axiom discrete_riemann_hypothesis :
    ∃ C_cov : ℝ, C_cov > 0 ∧ ∃ N₀ : ℕ, ∀ N : ℕ, N ≥ N₀ →
      N ≥ 3 →
      dotProduct (logCutoffWitness N)
        ((vasyuninCovMatrix N).mulVec (logCutoffWitness N)) ≤ C_cov / Real.log ↑N
```

This says the covariance matrix C = G - bb^T has v^T C v ≤ C/log N.

## Infrastructure in the Cathedral

### Proved (0 sorry)
- `nyman_beurling_converse` (Separation.lean): d²→0 ⟹ RH
- `rank1_lower_bound` (BDMellin.lean): Off-line zeros create permanent mass gap
- `bdMoebiusWeight_norm_bound` (BDMellin.lean): Witness norm control
- `moebius_mean_finite_bound` (AbelMean.lean): |b^Tv - 1| ≤ K/log N
- `linear_mean_bound` (AbelMean.lean): Integral mean → 1

### Axiom
- `discrete_riemann_hypothesis`: THE Crown (≡ RH in forward direction)

## Connection to Path B (GCD Strata)

After tonight's results, the Crown Axiom decomposes as:

```
v^T C v = v^T G v - (b^T v)²
        = [Σ R_d + Σ Δ_d] - (b^T v)²    ← gram_strata_decomposition
        = [Leg 2] + [Leg 3] - [Leg 1]
```

Path A's Crown axiom IS the conjunction of Legs 1-3 from Path B.
The Mellin approach doesn't decompose the problem — it uses RH directly.

## Verdict

Path A is the **most direct** but also the **most circular**: it assumes
RH in the forward direction. The value of Path A is in the converse
(which is proved with zero axioms) and in the infrastructure it provides
for other paths.

**Path A is not a path to proving RH. It's a path to showing RH implies d²→0.**
The interesting direction (d²→0 implies RH) is the converse, which is done.
