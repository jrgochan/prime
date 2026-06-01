# Path E: Spectral/Overcancellation — The Wave Converse

## Status: ANALYZED (Partial results, overcancellation hypothesis rejected)

## Overview

Path E approaches RH through the **spectral structure** of the Gram matrix
and the **eta convergence** of the alternating zeta function. It combines
three independent lenses on the zeros of ζ:

1. **Wave converse** (MirrorConverse.lean): Off-line zeros create standing waves
2. **Eta convergence** (EtaConvergence.lean): Alternating series convergence rate
3. **Quadruplet symmetry** (CircleQuadruplet.lean): Klein four-group of zeros

## What's Proved (Zero Axioms)

### Standing Wave / Mass Gap

```lean
-- MirrorConverse.lean
theorem wave_converse :
    σ ≠ 1/2 → irreducible standing wave (mass gap > 0)
```

If a zero ρ = σ + iγ exists with σ ≠ 1/2, then the Mellin residual
at ρ creates a permanent, irreducible standing wave in L²(0,1) with
mass gap ε(σ) = |σ - 1/2| > 0.

This standing wave prevents d²_N → 0, contradicting the converse direction.

### Eta Convergence

```lean
-- EtaConvergence.lean
theorem rpow_neg_antitone :
    n^{-σ} is decreasing (alternating series test applies)
```

The eta function η(s) = Σ (-1)^{n+1} n^{-s} converges for σ > 0
by the alternating series test. At σ = 1/2, the convergence rate is
O(1/√N), which is unconditional and confirmed numerically at N=10⁸.

### Quadruplet Symmetry

```lean
-- CircleQuadruplet.lean
theorem zero_center_quadruplet :
    ζ(ρ) = 0 ↔ ζ(1-ρ) = 0 ∧ ζ(ρ̄) = 0 ∧ ζ(1-ρ̄) = 0
```

Zeros of ζ come in quadruplets: {ρ, 1-ρ, ρ̄, 1-ρ̄}.
On the critical line (σ=1/2), these collapse to pairs {ρ, ρ̄}.

## The Overcancellation Hypothesis (REJECTED)

The original Path E hypothesis was:

> **Overcancellation**: v^T G v ≤ 1 for all N ≥ N₀

This was **rejected** by GPU experiments (Exploration 36):
- v^T G v > 1 at large N (the anomaly v^T Δ v exceeds 0)
- The overcancellation bound fails because v^T Δ v peaks around N ≈ 200

The corrected statement (the Crown Axiom) is:
v^T G v ≤ 1 + C/log N (allowing logarithmic overshoot)

## Connection to Path B (GCD Strata)

### Spectral Structure of the Anomaly

The anomaly Δ = G - R has a spectral expansion in terms of the
**Gauss map** T: x ↦ {1/x}. GPU experiments (Exploration 32) showed:

- The Gram matrix follows **GOE statistics** (β=1, real symmetric)
- NOT GUE (β=2, complex Hermitian) as initially hypothesized
- The spectral gap of T controls the anomaly decay rate

### GCD Strata as Gauss Map Orbits

The GCD stratum d corresponds to pairs (j,k) with gcd(j,k) = d.
Under the Gauss map, the continued fraction expansion of k/j
determines the orbit. The stratum d captures the "d-th level" of
this dynamical system.

From tonight's results:
- The Ramanujan kernel is the **invariant part** (d-independent)
- The anomaly is the **non-invariant part** (depends on the orbit)
- The spectral gap contracts the non-invariant part exponentially

### The 100% Sign Agreement Prediction

Combining the spectral analysis with Path B:

```
GPU: 88% sign agreement at N = 55,440
     12% anomaly concentrated at d=2 (Higgs)

Tonight: R kernel is d-independent     (PROVED)
         Möbius weights are d-independent (PROVED)
         ∴ ONLY Δ causes disagreement  (PROVED)

Prediction: As N → ∞, anomaly Δ_d → 0 for all d
            ∴ sign agreement → 100%
            ∴ RH
```

## What Path E Adds

Path E doesn't provide a direct closure mechanism, but it gives:

1. **Structural constraints** on zeros (quadruplet, wave, mass gap)
2. **Spectral framework** for the anomaly (GOE, Gauss map eigenfunctions)
3. **Numerical validation** (eta convergence rate matches prediction)

These are **diagnostic tools** rather than **proof tools**. They tell us
WHERE the zeros are (empirically) and WHAT HAPPENS if they're off-line,
but they don't FORCE them onto the line.

## The Three Lenses Combined

```
Lens 1 (Wave):     Off-line zero → permanent mass gap → d² ↛ 0
Lens 2 (Eta):      Alternating convergence at 1/√N → zeros exist on line
Lens 3 (Quadruplet): Zeros have fourfold symmetry → structural constraint
```

None individually proves RH. Together they provide:
- **Consistency check**: All three agree with RH
- **Impossibility of gross violations**: Off-line zeros would be detectable
- **Rate predictions**: The anomaly decay rate matches spectral gap predictions

## Difficulty Assessment

| Component | Status | Notes |
|-----------|--------|-------|
| Wave converse | ✅ PROVED | Standing wave from off-line zeros |
| Eta convergence | ✅ PROVED | Alternating series at σ=1/2 |
| Quadruplet symmetry | ✅ PROVED | Klein four-group |
| Overcancellation | ❌ REJECTED | v^T G v > 1 at large N |
| Spectral gap → closure | 🔧 OPEN | Needs Gauss map eigenvalue theory |

## Verdict

Path E is a **supporting path**, not a primary closure mechanism.
Its value is in providing **independent evidence** and **structural
constraints** that inform the strategy on Paths B and D.

The most promising use of Path E: formalize the **Gauss map spectral gap**
and connect it to the anomaly decay in Path B's Leg 3. The spectral gap
(second eigenvalue |λ₂| ≈ 0.303) would give an **exponential decay**
of anomaly strata, which is much stronger than the needed O(1/log N).

## Key References

- Beurling, A. "The collected works of Arne Beurling" (1989)
- Mayer, D.H. "Continued fractions and related transformations" (1991)
- Conrey, J.B. "The Riemann Hypothesis" (2003)
- Baladi, V. "Positive transfer operators and decay of correlations" (2000)
