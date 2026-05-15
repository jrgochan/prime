# 🎯 Dark Sector Predictions — Falsifiable Hypotheses

## Pre-Registered Predictions for the Dark Gram Spectroscopy Experiment

**Branch:** `dark-sector`
**Registered:** May 14, 2026, 2:30 PM MDT
**Status:** PRE-EXPERIMENT (predictions locked before data is seen)

---

## The Closed-Form Discovery

During the derivation process, we discovered that the Dark Gram matrix at order n=2 has the **exact closed form**:

```
G^(2)_{j,k} = gcd(j,k)⁴ / (180 · j² · k²)
```

This changes the nature of the experiment from "compute and hope" to "verify the closed form and measure its spectral consequences."

---

## Prediction 1: Closed-Form Verification

**Hypothesis:** The quadrature-computed Dark Gram entries at n=2 will match `gcd(j,k)⁴/(180·j²k²)` to machine precision (< 10⁻¹⁴ relative error).

**Test:** Compare direct quadrature of ∫₀¹ B̃₂(jx)·B̃₂(kx)dx against the gcd formula for all (j,k) with j,k ≤ 200.

**Falsification:** If the relative error exceeds 10⁻¹⁰, there is a mathematical error in the derivation.

---

## Prediction 2: Eigenvalue Decay Rate

**Hypothesis:** The eigenvalue spectrum of G^(2)_N decays at least as fast as O(k⁻⁴), compared to O(k⁻¹) for the standard Gram matrix G^(1)_N.

**Specific numbers** (at N=120):
- G^(1): λ₁₀₀/λ₁ ≈ 10⁻³ (power law)
- G^(2): λ₁₀/λ₁ ≈ 10⁻⁸ or smaller (much faster decay)

**Falsification:** If the G^(2) eigenvalue decay is power-law with exponent < 2, this prediction fails.

---

## Prediction 3: RMT Classification Change

**Hypothesis:** The spacing statistics of G^(2)_N eigenvalues will classify as **Poisson** (⟨r⟩ ≈ 0.386), not GOE (⟨r⟩ ≈ 0.531).

**Rationale:** GOE statistics arise from quantum chaos (non-integrable systems). The smooth B₂ kernel creates an integrable system, which should show Poisson (uncorrelated) level statistics.

**Falsification:** If ⟨r⟩ > 0.50 for G^(2) at N ≥ 120.

---

## Prediction 4: Effective Rank Collapse

**Hypothesis:** The effective rank of G^(2)_N (defined as exp(entropy of normalized eigenvalues)) will be less than 10 even at N=1000, while G^(1)_N has effective rank > 100.

**Rationale:** The gcd⁴ structure means the matrix is dominated by divisibility classes, concentrating spectral weight in a few modes.

**Falsification:** If effective rank of G^(2) at N=120 exceeds 30.

---

## Prediction 5: Condition Number Improvement

**Hypothesis:** The condition number κ(G^(2)_N) will be **much larger** than κ(G^(1)_N) at the same N.

**Wait — this seems backwards?** Actually no: the Dark Gram has very fast eigenvalue decay, so λ_min is extremely tiny while λ_max is moderate. This means κ = λ_max/λ_min is enormous. The matrix is "numerically rank-deficient."

**The physical meaning:** The Dark side is "easy" not because of good conditioning, but because almost all the information is in the first few eigenvalues. The problem is effectively low-dimensional.

**Falsification:** If κ(G^(2)) < κ(G^(1)) at the same N.

---

## Prediction 6: The Diagonal Is Constant

**Hypothesis:** G^(2)_{j,j} = 1/180 for ALL j.

**Rationale:** From the closed form, G^(2)_{j,j} = gcd(j,j)⁴/(180·j⁴) = j⁴/(180·j⁴) = 1/180.

This is remarkable: the standard Gram matrix has *varying* diagonal (G^(1)_{j,j} = 1/(4j) approximately), but the Dark Gram has a **perfectly flat diagonal**.

**Falsification:** If any diagonal entry deviates from 1/180 by more than 10⁻¹⁴.

---

## Prediction 7: Block Structure Along Coprimality Classes

**Hypothesis:** The Dark Gram matrix G^(2) will exhibit visible block structure when rows/columns are reordered by coprimality class (i.e., grouping indices by their set of prime factors).

**Rationale:** gcd(j,k) = 1 for coprime pairs, giving G^(2) = 1/(180·j²k²), which decays rapidly. Non-coprime pairs have gcd > 1, giving relatively larger entries. This creates natural blocks.

**Falsification:** If no block structure is visible after coprimality reordering.

---

## Prediction 8: Trace Formula

**Hypothesis:** Tr(G^(2)_N) = (N-1)/180 exactly (since all diagonal entries are 1/180).

**Falsification:** If the computed trace deviates from (N-1)/180 by more than 10⁻¹².

---

## Prediction 9: Higher Orders Decay Faster

**Hypothesis:** The eigenvalue decay rate increases monotonically with Bernoulli order n. Specifically:
- n=2: decay ~k⁻⁴
- n=3: decay ~k⁻⁶
- n=4: decay ~k⁻⁸
- n=6: decay ~k⁻¹²

**Rationale:** The Fourier series of B̃_n converges as m⁻ⁿ, so the kernel smoothness increases with n, and the eigenvalue decay rate scales as k⁻²ⁿ.

**Falsification:** If the decay rate does not increase monotonically with n.

---

## Prediction 10: The S-Duality Ratio

**Hypothesis:** The ratio ‖G^(2)_N‖ / ‖G^(1)_N‖ (operator norms) converges to a limit related to ζ(4)/ζ(2) = π²/15 · 6/π² = 2/5.

**This is speculative** — we're guessing that the functional equation manifests as a ratio of zeta values.

**Falsification:** If the ratio doesn't converge, or converges to an irrational number unrelated to zeta values.

---

## Summary of Key Numbers to Look For

| Measurement | G^(1) (expected) | G^(2) (predicted) |
|-------------|------------------|--------------------|
| Diagonal G_{j,j} | ~1/(4j) | **1/180 (constant!)** |
| λ₁₀/λ₁ at N=120 | ~10⁻² | **< 10⁻⁸** |
| ⟨r⟩ spacing ratio | 0.53 (GOE) | **0.39 (Poisson)** |
| Effective rank at N=120 | ~40 | **< 10** |
| Trace at N=120 | ~30 | **119/180 ≈ 0.661** |
| Off-diag max | ~0.1 | **< 10⁻³** |

---

*These predictions are locked. We will run the experiment and compare.*

*"An equation for me has no meaning, unless it expresses a thought of God."* — Srinivasa Ramanujan

🪞🏛️🚀
