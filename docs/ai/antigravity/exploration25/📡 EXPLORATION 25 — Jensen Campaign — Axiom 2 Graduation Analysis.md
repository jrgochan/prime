# 📡 EXPLORATION 25 — The Jensen Campaign
## Axiom 2 Graduation: `rh_zeta_lower_bound_from_zero_counting`
**Date:** May 4, 2026
**Author:** Claude Actual (The Forge Master)
**Status:** Strategic Analysis & Feasibility Report

---

## 1. OBJECTIVE

Graduate the axiom `rh_zeta_lower_bound_from_zero_counting` in
`Cathedral/Zeta/Hadamard.lean:249` from `axiom` to `theorem`, using
the Jensen's Formula shortcut identified in the gap analysis.

### The Axiom (Current)
```lean
axiom rh_zeta_lower_bound_from_zero_counting
    (hRH : RiemannHypothesis) (ε : ℝ) (hε : 0 < ε) (hε1 : ε < 3/2)
    (A : ℝ) (hA : 0 < A) :
    ∃ c > 0, ∀ s : ℂ,
      (1/2 + ε ≤ s.re) → (2 ≤ |s.im|) →
      c / |s.im| ^ A ≤ ‖riemannZeta s‖
```

### What It Says (English)
Under RH, for any `ε > 0` and any polynomial exponent `A > 0`, there exists
a constant `c > 0` such that `|ζ(σ+it)| ≥ c/|t|^A` whenever `σ ≥ 1/2+ε`
and `|t| ≥ 2`.

### Impact of Graduation
- **PATH B (Perron Crown)** drops from 4 named axioms to **3**
- Combined with PATH A's single sorry, this brings the full Cathedral
  closer to the 1-axiom architecture
- This axiom blocks `thin_strip_lower_bound_exists` which in turn
  closes the `A < B_ε` case of `zeta_polynomial_lower_bound_rh_proved`

---

## 2. MATHLIB v4.29 ARSENAL — AVAILABLE TOOLS

### ✅ FULLY AVAILABLE (In Mathlib v4.29.0)

| Tool | File | Status |
|------|------|--------|
| **Jensen's Formula** | `Analysis.Complex.JensenFormula` | `MeromorphicOn.circleAverage_log_norm` |
| **Meromorphic Functions** | `Analysis.Meromorphic.Basic` | `MeromorphicAt`, `MeromorphicOn`, algebra |
| **Divisors** | `Analysis.Meromorphic.Divisor` | `divisor f U`, `meromorphicOrderAt` |
| **Meromorphic Order** | `Analysis.Meromorphic.Order` | Order at poles/zeros |
| **Isolated Zeros** | `Analysis.Meromorphic.IsolatedZeros` | Zero isolation for meromorphic functions |
| **Normal Form** | `Analysis.Meromorphic.NormalForm` | Laurent-like decomposition |
| **Trailing Coefficient** | `Analysis.Meromorphic.TrailingCoefficient` | `meromorphicTrailingCoeffAt` |
| **Factorized Rational** | `Analysis.Meromorphic.FactorizedRational` | Extract zeros/poles |
| **Value Distribution** | `Analysis.Complex.ValueDistribution/` | First Main Theorem, log-counting |
| **Phragmén-Lindelöf** | `Analysis.Complex.PhragmenLindelof` | Strip/quadrant bounds |
| **Borel-Carathéodory** | `Analysis.Complex.BorelCaratheodory` | `borelCaratheodory_zero` (improved!) |
| **Hadamard Three-Lines** | `Analysis.Complex.Hadamard` | Three-Lines theorem |
| **Three-Circles** | `Cathedral.Zeta.Hadamard` | OUR proved reduction |
| **Cauchy Integral** | `Analysis.Complex.CauchyIntegral` | Full Cauchy integral formula |
| **Riemann Zeta** | `NumberTheory.LSeries.RiemannZeta` | `riemannZeta`, `differentiableAt_riemannZeta` |
| **Functional Equation** | `NumberTheory.LSeries.RiemannZeta` | `riemannZeta_one_sub` |
| **Log Meromorphic** | `Analysis.SpecialFunctions.Integrability.LogMeromorphic` | `log ‖f·‖` integrability |

### ❌ NOT YET IN MATHLIB (Critical Gaps)

| Missing Tool | Impact | Workaround |
|-------------|--------|------------|
| `MeromorphicOn riemannZeta` | Cannot directly apply Jensen to ζ | Prove from `differentiableAt_riemannZeta` + pole at s=1 |
| `N(T) = O(T log T)` (Riemann-von Mangoldt) | Zero density bound | Prove via Argument Principle on ξ(s) |
| Hadamard Product `ζ(s) = ...` | Full factorization | **BYPASS via Jensen shortcut** |
| `completedRiemannZeta` meromorphic | Global continuation | Available as `differentiable` except at 0,1 |

---

## 3. THE JENSEN SHORTCUT — PROOF STRATEGY

### Classical Approach (AVOIDED — too heavy)
```
Hadamard Product → Weierstrass Factorization → Canonical Products
→ Genus Theory → Infinite Product Convergence → Zero Sum Estimate
≈ 5,000+ lines, requires infrastructure not in Mathlib
```

### Jensen Shortcut (OUR APPROACH)
```
Jensen's Formula on disk → log-integral bound
  + Borel-Carathéodory → upper bound on Re(log ζ)
  + RH (no zeros on σ > 1/2) → lower bound on |ζ|
≈ 1,500–2,500 lines, ALL infrastructure available
```

### Detailed Proof Outline

#### Step 1: Prove `riemannZeta` is meromorphic
```lean
-- We need: MeromorphicOn riemannZeta Set.univ
-- From: differentiableAt_riemannZeta (for s ≠ 1)
-- Plus: pole analysis at s = 1 (Laurent expansion exists in Mathlib)
theorem riemannZeta_meromorphicOn :
    MeromorphicOn riemannZeta Set.univ
```
**Estimated effort:** 100–200 lines.
`MeromorphicAt` requires `∃ n, AnalyticAt ... ((· - z₀)^n • f)`.
For `s ≠ 1`: direct from `DifferentiableAt` → `AnalyticAt` → `MeromorphicAt`.
For `s = 1`: need `meromorphicOrderAt riemannZeta 1 = -1` (simple pole).

#### Step 2: Apply Jensen's Formula to ζ on shifted disk
Center the disk at `s₀ = 2 + it`, radius `R = 3/2 - ε/2`.
Under RH, ζ has no zeros in the disk (all zeros on Re(s) = 1/2).
```lean
-- Jensen's Formula gives:
-- circleAverage (log ‖ζ·‖) s₀ R = log ‖meromorphicTrailingCoeffAt ζ s₀‖
--   + Σ_zeros_in_disk (order * log(R/|s₀ - zero|))
--
-- Under RH: NO zeros in disk → sum vanishes!
-- So: circleAverage (log ‖ζ·‖) s₀ R = log ‖ζ(s₀)‖
```
**Estimated effort:** 200–400 lines.
Key challenge: proving `meromorphicOrderAt riemannZeta s₀ = 0` for `s₀ = 2+it`
(ζ is nonzero there, which we already have via `rh_zeta_ne_zero`).

#### Step 3: Upper bound on the circle average
```lean
-- On the circle |s - s₀| = R:
-- log ‖ζ(s)‖ ≤ log(convexity_bound(|t| + R))
-- ≤ C₁ · log(|t|)
--
-- This gives: circleAverage ≤ C₁ · log(|t|)
-- Combined with Step 2: log ‖ζ(s₀)‖ ≤ C₁ · log(|t|)
```
**Estimated effort:** 300–500 lines.
Uses the convexity bound on ζ (which we already have in `ZetaDiskBounds.lean`).

#### Step 4: Sub-mean-value inequality → pointwise lower bound
```lean
-- For any s with |s - s₀| < R:
-- log ‖ζ(s)‖ ≥ 2·log ‖ζ(s₀)‖ - circleAverage
--            ≥ 2·log(1/4) - C₁·log(|t|)
--            ≥ -C₂·log(|t|)
--
-- Exponentiating: |ζ(s)| ≥ |t|^{-C₂}
```
**Estimated effort:** 200–400 lines.
Key: The **Borel-Carathéodory** theorem (which we already use successfully
in `LowerBound.lean`) gives this step. We already proved `bc_inner_bound`
for the `A ≥ B_ε` case — the Jensen approach gives us the `A < B_ε` case.

#### Alternative Step 4 (Direct Jensen bound)
Instead of BC, use Jensen's Formula directly:
```
Jensen gives: log ‖ζ(s₀)‖ = circleAverage - Σ_zeros log(R/|s₀-ρ|)
Under RH: Σ_zeros ≥ 0 (each term is positive since |s₀-ρ| < R)
So: log ‖ζ(s₀)‖ ≤ circleAverage
And: -log ‖ζ(s)‖ ≤ circleAverage - log ‖ζ(s₀)‖ + BC correction
```

---

## 4. ALTERNATIVE APPROACHES

### Approach A: Direct N(T) Estimation (Harder but Cleaner)
Prove the Riemann-von Mangoldt formula `N(T) = (T/2π)log(T/2π) - T/2π + O(log T)`
using the Argument Principle on `ξ(s)`. Then estimate the zero sum directly.

**Pros:** Gives the strongest result, reusable for other proofs.
**Cons:** Requires contour integration around a rectangle, Stirling approximation
for `Γ(s/2)`, and careful error analysis. Estimated 2,000–4,000 lines.

### Approach B: Convexity Bound Direct (Simplest but Weakest)
Use only the convexity bound `ζ(σ+it) = O(|t|^{(1-σ)/2+ε})` for `σ ≥ 1/2`
combined with the functional equation and Phragmén-Lindelöf.

**Pros:** Very short (500–800 lines). All tools available.
**Cons:** Only gives `|ζ| ≥ |t|^{-A}` for specific A values, not arbitrary A.
May not match the axiom's full generality.

### Approach C: Reduction to Already-Proved BC Case
The key insight: **we already proved the `A ≥ B_ε` case** in `LowerBound.lean`!
The axiom is only needed for `A < B_ε = 40(3-2ε)/ε`.

So we could prove: for fixed ε, the Jensen/BC approach gives an effective
exponent A₀(ε), and then the existing `bc_inner_bound` handles all A ≥ A₀(ε).

For A < A₀(ε), we need the zero-counting approach. But we can make A₀(ε)
VERY small by iterating BC on nested disks.

**Key question:** Can iterated BC make A₀(ε) ≤ any fixed A > 0?

---

## 5. RISK ASSESSMENT

| Risk | Severity | Mitigation |
|------|----------|------------|
| `MeromorphicOn riemannZeta` not trivial | Medium | Build from `differentiableAt` + pole analysis |
| Jensen divisor computation complex | Medium | Under RH, divisor sum vanishes on shifted disk |
| Integration of new v4.29 APIs untested | Low | API is well-documented, clean signatures |
| Proof length exceeds estimate | Medium | Approach C offers fallback |
| Iterated BC insufficient for all A | Low | Classical theory guarantees convergence |

---

## 6. RECOMMENDED PLAN

### Phase 1: Foundation (400–600 lines)
1. **Prove `riemannZeta_meromorphicAt`** for all `s ∈ ℂ`
2. **Prove `riemannZeta_meromorphicOn`** on `Set.univ`
3. **Prove `meromorphicOrderAt_riemannZeta_one`** = `-1` (simple pole)
4. **Prove `meromorphicOrderAt_riemannZeta_ne_one`** = order at non-pole points

### Phase 2: Jensen Application (400–800 lines)
5. **Apply Jensen on shifted disk** under RH (zero-free hypothesis)
6. **Bound the circle average** using existing convexity bounds
7. **Extract the pointwise lower bound** via the sub-mean-value inequality

### Phase 3: Assembly (200–400 lines)
8. **Prove the axiom statement** by combining the Jensen bound with
   the existing `bc_inner_bound`
9. **Clean up**: remove the axiom, verify `#print axioms` on all paths

### Total Estimated Effort: 1,000–1,800 lines

---

## 7. IMMEDIATE FIRST STEP

Begin with Phase 1, Step 1: proving `riemannZeta` is meromorphic.

```lean
import Mathlib.Analysis.Meromorphic.Basic
import Mathlib.NumberTheory.LSeries.RiemannZeta

theorem riemannZeta_meromorphicAt (s : ℂ) :
    MeromorphicAt riemannZeta s := by
  by_cases hs : s = 1
  · -- s = 1: simple pole, need (· - 1) • ζ analytic at 1
    sorry -- Laurent expansion at s=1
  · -- s ≠ 1: differentiable → analytic → meromorphic
    exact (differentiableAt_riemannZeta hs).analyticAt.meromorphicAt
```

The `s ≠ 1` case is **one line**. The `s = 1` case requires showing that
`(s - 1) * ζ(s)` extends analytically to `s = 1` (well-known: the limit is 1,
the residue of the simple pole).

---

## 8. CROWN ARCHITECTURE AFTER GRADUATION

### Before (Current State)
```
PATH A (Mellin):   1 sorry  (critical_line_mellin_variance)
PATH B (Perron):   4 axioms (covariance_bound, pnt_mu_log, partial_integral,
                              rh_zeta_lower_bound_from_zero_counting)
PATH C (Renorm):   0 axioms (FULLY GRADUATED)
```

### After Axiom 2 Graduation
```
PATH A (Mellin):   1 sorry  (critical_line_mellin_variance)
PATH B (Perron):   3 axioms (covariance_bound, pnt_mu_log, partial_integral)
PATH C (Renorm):   0 axioms (FULLY GRADUATED)
```

The Cathedral moves one step closer to the single-axiom architecture.

---

## 9. FILES TO CREATE/MODIFY

| File | Action | Purpose |
|------|--------|---------|
| `Cathedral/Zeta/ZetaMeromorphic.lean` | **CREATE** | Prove ζ is meromorphic |
| `Cathedral/Zeta/JensenBound.lean` | **CREATE** | Jensen lower bound under RH |
| `Cathedral/Zeta/Hadamard.lean` | **MODIFY** | Graduate axiom → theorem |
| `proofs/lakefile.lean` | **MODIFY** | Add new files to build |

---

*"The summit is not a place. It is a proof state."*
— Exploration 25, Opening Statement
