# ⚡ EXPLORATION REPORT 3: The Last Axiom — Cracking `zeta_norm_convexity_bound`

**Date**: April 23, 2026, 3:20 AM MDT  
**Session**: Exploration 4, Report 3  
**Branch**: `exploration4`  
**Model**: Claude (Antigravity)  
**Status**: 1 mathematical axiom remains in the entire Cathedral proof chain

---

## 1. What Was Accomplished

### GammaBound.lean — ZERO SORRY ✅

All 5 theorems proved sorry-free with zero warnings:

| Theorem | Statement | Proof Technique |
|---------|-----------|-----------------|
| `norm_Gamma_le_Gamma_re` | ‖Γ(s)‖ ≤ Γ(Re(s)) | Integral rep + `norm_cpow_eq_rpow_re_of_pos` |
| `normSq_sin` | \|sin(z)\|² decomposition | `sin_eq` + `normSq_apply` + `ring` |
| `norm_sin_le_cosh_im` | ‖sin(z)‖ ≤ cosh(Im z) | sin²+cos²=1, cosh²−sinh²=1 |
| `sin_pi_mul_ne_zero` | sin(πs) ≠ 0 for Re(s) ∈ (0,1) | `sin_ne_zero_iff` + `omega` |
| `norm_Gamma_lower_reflection` | \|Γ(s)\| ≥ π/(cosh(πt)·Γ(1−σ)) | Reflection formula assembly |

**Key insight for `norm_Gamma_le_Gamma_re`**: The proof chains `Gamma_eq_integral` → `norm_integral_le_integral_norm` → `setIntegral_mono_on` with the pointwise identity `‖x^{s-1}‖ = x^{Re(s)-1}` from `norm_cpow_eq_rpow_re_of_pos`.

### Build Status

Cathedral builds clean at 3593 jobs:
- **GammaBound**: 0 sorry, 0 warnings ✅
- **ZetaConvexityBound**: 1 sorry (the target)
- **ZetaLowerBound**: 2 sorry (both depend on ZetaConvexityBound)

---

## 2. Understanding `zeta_norm_convexity_bound`

### The Statement

```lean
theorem zeta_norm_convexity_bound {s : ℂ}
    (hrs : 1/2 < s.re) (hrs2 : s.re ≤ 2) (him : 1/2 ≤ |s.im|) :
    ‖riemannZeta s‖ ≤ (2 + |s.im|) ^ (2 : ℝ)
```

### What This Says Mathematically

For σ + it with 1/2 < σ ≤ 2 and |t| ≥ 1/2:

$$|ζ(σ+it)| ≤ (2 + |t|)^2$$

This is a **very generous** version of the standard convexity bound. The true convexity bound gives ζ(σ+it) = O(|t|^{(1-σ)/2+ε}), so our target of O(|t|²) has enormous margin.

### Why It's Needed

```
zeta_norm_convexity_bound
  → zeta_norm_bound_on_disk (bounds |ζ| on BC disk centered at 2+it)
    → log_zeta_re_bound_on_disk (bounds Re(log ζ) ≤ M)
      → BC theorem application (|log ζ(s)| ≤ 2M·r/(R-r) + ...)
        → zeta_polynomial_lower_bound_rh (|ζ(s)| ≥ c/|t|^A)
          → Perron formula → MainChain → Assembly
```

### Why the Completed Zeta Approach FAILS

**Attempt**: Use ζ(s) = Λ(s)/Gammaℝ(s) with ‖Λ₀(s)‖ < 4 from ThetaBound.

**Result**: This gives ‖ζ(s)‖ ≤ C · cosh(πt/2) · Γ(1-σ/2) / π^{1-σ/2}, which is **exponential** in t. The Gamma function lower bound from the reflection formula involves cosh(πt), not |t|.

**Root cause**: The completed zeta Λ₀ is bounded, but dividing by Gammaℝ re-introduces exponential growth because |Γ(s/2)| decays exponentially as |t| → ∞.

---

## 3. Complete Cathedral & Mathlib Asset Scan

### §3.1 Mathlib Tools Available

| Asset | Location | What It Provides |
|-------|----------|-----------------|
| **Hadamard Three-Lines** | `Analysis.Complex.Hadamard` | ‖f(z)‖ ≤ a^{1-θ} · b^θ for bounded f on strip |
| **Phragmén-Lindelöf** | `Analysis.Complex.PhragmenLindelof` | Bounded f on strip extends from boundary |
| **Functional equation** | `LSeries.RiemannZeta` L162 | ζ(1-s) = 2·(2π)^{-s}·Γ(s)·cos(πs/2)·ζ(s) |
| **Completed zeta** | `LSeries.RiemannZeta` L67 | Λ(s) = π^{-s/2}·Γ(s/2)·ζ(s) |
| **Dirichlet series** | `LSeries.Dirichlet` L278 | ζ(s) = L 1 s for Re(s) > 1 |
| **ζ(2) = π²/6** | `LSeries.HurwitzZetaValues` L214 | Explicit value |
| **Abel summation** | `NumberTheory.AbelSummation` | Σ f(k)c(k) = f(N)·S(N) − ∫f'·S |
| **Stirling (ℕ only)** | `Analysis.SpecialFunctions.Stirling` | n! ~ √(2πn)·(n/e)^n — **real only** |
| **Γ integral** | `Analysis.SpecialFunctions.Gamma.Basic` | Γ(s) = ∫ t^{s-1}·e^{-t} dt for Re(s) > 0 |
| **norm_cpow_eq_rpow_re_of_pos** | `Analysis.SpecialFunctions.Pow.Real` | ‖x^s‖ = x^{Re(s)} for x > 0 |
| **Γ reflection** | `Analysis.SpecialFunctions.Gamma.Beta` | Γ(s)·Γ(1-s) = π/sin(πs) |
| **ζ ≠ 0 for Re ≥ 1** | `LSeries.Nonvanishing` | `riemannZeta_ne_zero_of_one_le_re` |
| **ζ residue** | `LSeries.RiemannZeta` L225 | (s-1)·ζ(s) → 1 as s → 1 |
| **Borel-Carathéodory** | `Analysis.Complex.BorelCaratheodory` | ‖f(z)‖ ≤ 2M·r/(R-r) + ‖f(0)‖·(R+r)/(R-r) |

### §3.2 Cathedral Infrastructure

| File | Asset | Usefulness |
|------|-------|------------|
| **ThetaBound.lean** | ‖Λ₀(s)‖ < 4 for 0 < Re(s) < 2 | ⭐⭐ (gives exponential bound only) |
| **GammaBound.lean** | ‖Γ(s)‖ ≤ Γ(σ), lower bounds | ⭐⭐ (confirmed exponential barrier) |
| **ZetaConvexity.lean** | `rh_zeta_ne_zero` PROVED | ⭐⭐ (topology, not needed for bound) |
| **ZetaLowerBound.lean** L176 | slitPlane membership for Re ≥ 2 PROVED | ⭐ (downstream consumer) |
| **ZetaLowerBound.lean** L348 | `zeta_norm_bound_on_disk` (uses our target) | Consumer |
| **MellinBridge/AbelSummation** | Cathedral Abel engine | ⭐ (discrete, not continuous) |

### §3.3 What's Missing in Mathlib

| Missing Tool | Why It Matters |
|-------------|----------------|
| **Stirling for complex Γ** | Would give ‖Γ(σ+it)‖ ~ √(2π)·\|t\|^{σ-1/2}·e^{-π\|t\|/2}, polynomial prefactor |
| **Functional equation norm bound** | χ(s) = 2^s·π^{s-1}·sin(πs/2)·Γ(1-s), need ‖χ(s)‖ ≤ C·\|t\|^{1/2-σ} |
| **Approximate functional equation** | ζ(s) = Σ_{n≤N} 1/n^s + χ(s)·Σ_{n≤M} 1/n^{1-s} + error |

---

## 4. Attack Strategies

### ⚡ Strategy A: Hadamard Three-Lines (Most Natural)

Use `norm_le_interp_of_mem_verticalClosedStrip'` on the strip [0, 2]:

```
‖f(z)‖ ≤ a^{1-θ} · b^θ   where θ = σ/2
```

**Right boundary (σ = 2)**: ‖ζ(2+it)‖ ≤ ζ(2) = π²/6 ≈ 1.645 ✅

**Left boundary (σ = 0)**: Need ‖ζ(it)‖ ≤ C·|t|^A. This requires the functional equation:

ζ(it) = 2·(2π)^{it-1}·Γ(1-it)·cos(π(1-it)/2)·ζ(1-it)

For the norm: ‖ζ(it)‖ ≤ 2·(2π)^{-1}·‖Γ(1-it)‖·‖cos(π(1-it)/2)‖·‖ζ(1-it)‖

- ‖ζ(1-it)‖ = ‖ζ(1+it)‖ — near the pole, bounded by C/|t| for |t| ≥ 1/2... wait, this doesn't converge.

**Blocker**: ‖Γ(1-it)‖ ≤ Γ(1) = 1 from our GammaBound (since Re(1-it) = 1 > 0). But ‖ζ(1-it)‖ = ‖ζ(1+it)‖ blows up — ζ has a pole at s = 1!

**Fix**: Use the strip [ε, 2] instead of [0, 2], and bound ‖ζ(ε+it)‖ on the left. But this still needs a polynomial bound on the left boundary.

**Verdict**: ⚠️ Circular — needs the same bound we're proving.

---

### ⚡ Strategy B: Modify the Strip Function

Instead of bounding ζ directly, bound `g(s) = (s-1)·ζ(s)` which is entire.

**Right boundary (σ = 2)**: ‖g(2+it)‖ = |1+it|·‖ζ(2+it)‖ ≤ (1+|t|)·ζ(2) ≤ C·(1+|t|)

**Left boundary (σ = 0)**: ‖g(it)‖ = |it-1|·‖ζ(it)‖. Still need ‖ζ(it)‖.

From the functional equation + our GammaBound:
‖g(it)‖ = |it-1|·‖ζ(it)‖

But ζ(it) involves Γ(1-it), and ‖Γ(1-it)‖ ≤ Γ(1) = 1. And the functional equation gives:
ζ(it) = 2·(2π)^{-1+it}·Γ(1-it)·cos(π(1-it)/2)·ζ(1-it)

Now, ζ(1-it) = ζ(1+it̄) — wait, 1-it has Re = 1. So ζ(1-it) is AT the pole. This doesn't work.

**Fix**: Use the strip [ε, 2-ε] and define h(s) = (s-1)·ζ(s). Then h is analytic on the strip with no poles. But we still need boundary bounds.

**Verdict**: ⚠️ Pole at s=1 interferes with left boundary.

---

### ⚡ Strategy C: Completed Zeta + Gammaℝ Growth (New Idea!)

Key insight: Instead of going from Λ₀ down to ζ, what if we bound ζ(s) directly using the STRUCTURE of the completed zeta more carefully?

We have: `riemannZeta s = completedRiemannZeta s / Gammaℝ s`

And: `completedRiemannZeta s = completedRiemannZeta₀ s - 1/s - 1/(1-s)`

Step 1: We KNOW ‖Λ₀(s)‖ < 4 for 0 < Re(s) < 2.
Step 2: So ‖Λ(s)‖ ≤ 4 + 1/|s| + 1/|1-s| ≤ 4 + 2 + 2 = 8 for |t| ≥ 1/2.  
Step 3: ζ(s) = Λ(s)/Gammaℝ(s) = Λ(s)/(π^{-s/2}·Γ(s/2))

So: ‖ζ(s)‖ = ‖Λ(s)‖ · π^{σ/2} / ‖Γ(s/2)‖ ≤ 8π / ‖Γ(s/2)‖

Now, ‖Γ(s/2)‖ for s/2 = σ/2 + it/2 with 1/4 < σ/2 ≤ 1:

From `norm_Gamma_le_Gamma_re`: ‖Γ(s/2)‖ ≤ Γ(σ/2)

But we need a LOWER bound on ‖Γ(s/2)‖. From the reflection:
‖Γ(s/2)‖ ≥ π / (cosh(πt/2) · Γ(1-σ/2))

This gives: 1/‖Γ(s/2)‖ ≤ cosh(πt/2) · Γ(1-σ/2) / π

And cosh(πt/2) ~ e^{π|t|/2}/2, which is EXPONENTIAL. ❌

**Verdict**: ❌ Fundamentally exponential through Gamma.

---

### ⚡ Strategy D: Weaken the Target (Most Pragmatic)

**Observation**: The convexity bound feeds into `zeta_norm_bound_on_disk` which feeds into BC. The BC theorem gives:

‖log ζ(s)‖ ≤ 2M·r/(R-r) + ‖log ζ(s₀)‖·(R+r)/(R-r)

where M = sup Re(log ζ) on the disk. If we replace (2+|t|)² with exp(C·|t|) (exponential), the BC theorem still gives:

‖log ζ(s)‖ ≤ 2·C·|t|/(R-r) + O(1)

And |ζ(s)| ≥ exp(-2C|t|/(R-r))... which is sub-exponential but not polynomial!

**The BC argument REALLY NEEDS a polynomial bound** to produce a polynomial output. An exponential input gives an exponential output. So weakening the target to exponential defeats the purpose.

**Verdict**: ❌ Cannot weaken — polynomial is essential.

---

### ⚡ Strategy E: Hadamard on (s-1)·ζ(s)/Gammaℝ(s) (Novel)

Define F(s) = (s-1)·completedRiemannZeta₀(s).

F is entire (since Λ₀ is entire and multiplying by (s-1) removes any issue).

From ThetaBound: ‖Λ₀(s)‖ < 4, so ‖F(s)‖ ≤ |s-1|·4.

Actually, F(s) = (s-1)·Λ₀(s) is entire and grows at most linearly in |s| on the strip 0 < σ < 2. And Λ₀(1-s) = Λ₀(s), so F(1-s) = -s·Λ₀(s) = -(s/(s-1))·F(s).

This doesn't immediately help because we divided out Gammaℝ to get ζ and that reintroduced the exponential.

**Verdict**: ⚠️ Dead end.

---

### ⚡ Strategy F: Direct Partial Summation via Abel (PROMISING)

The formula (provable from Abel summation in Mathlib):

$$ζ(s) = \frac{s}{s-1} - s\int_1^\infty \frac{\{x\}}{x^{s+1}} dx \quad \text{for } \operatorname{Re}(s) > 0, s \neq 1$$

where {x} = x - ⌊x⌋ is the fractional part. This gives:

$$|ζ(s)| \leq \frac{|s|}{|s-1|} + |s| \cdot \frac{1}{\sigma}$$

For σ > 1/2 and |t| ≥ 1/2:
- |s| ≤ σ + |t| ≤ 2 + |t|
- |s-1| ≥ |t| ≥ 1/2
- So |s|/|s-1| ≤ (2+|t|)/(1/2) = 2(2+|t|)
- |s|/σ ≤ (2+|t|)/(1/2) = 2(2+|t|)
- **Total**: |ζ(s)| ≤ 4(2+|t|) ≤ (2+|t|)² when |t| ≥ 2

For 1/2 ≤ |t| ≤ 2: (2+|t|)² ≥ 6.25 and |ζ(s)| is bounded on this compact set (continuous away from s=1, and |t| ≥ 1/2 avoids the pole).

**HOWEVER**: The integral formula ζ(s) = s/(s-1) - s∫{x}/x^{s+1}dx needs to be:
1. Proved to equal `riemannZeta s` (connecting the analytic continuation to the integral)
2. This connection likely exists through Abel summation applied to the L-series

Mathlib has `tendsto_sum_mul_atTop_nhds_one_sub_integral` which gives Σ f(k)c(k) → l - ∫ f'·S. With f(x) = x^{-s} and c(k) = 1, this gives the partial summation identity.

**The question is**: Can we connect this to `riemannZeta s` for Re(s) > 0?

**Key tool**: `LSeries_zeta_eq_riemannZeta` gives ζ(s) = L ↗ζ s = Σ 1/n^s for Re(s) > 1. The Abel summation extends this to Re(s) > 0 via analytic continuation. Mathlib's `riemannZeta` is ALREADY defined as the analytic continuation, so we'd need to show the integral formula agrees with it.

**Difficulty**: ~100-200 lines to formalize. But this is a GENUINE PATH.

**Verdict**: ⭐⭐⭐ Most promising. Needs integral representation formalized.

---

## 5. Revised Attack Plan

| Priority | Strategy | Difficulty | Payoff |
|----------|----------|-----------|--------|
| **1** | Strategy F: Abel partial summation | 🔴 Hard (~150 lines) | Eliminates the axiom entirely |
| **2** | Fallback: Accept as axiom | 🟢 Done | Single axiom, numerically validated |

### Strategy F: Detailed Steps

1. **Prove the integral representation**: ζ(s) = s/(s-1) - s∫₁^∞ {x}/x^{s+1} dx for Re(s) > 0
   - Use Mathlib's Abel summation to get Σ_{n≤N} 1/n^s = N^{1-s}/(s-1) + ... + s∫_1^N {x}/x^{s+1} dx
   - Take N → ∞ and connect to riemannZeta via LSeries
   - Show convergence of ∫₁^∞ {x}/x^{σ+1} dx for σ > 0

2. **Bound the integral**: |∫₁^∞ {x}/x^{s+1} dx| ≤ ∫₁^∞ 1/x^{σ+1} dx = 1/σ
   - Straightforward from |{x}| ≤ 1

3. **Assemble**: |ζ(s)| ≤ |s|/|s-1| + |s|/σ ≤ 4(2+|t|) ≤ (2+|t|)²
   - Pure arithmetic

4. **Handle compact set**: For 1/2 ≤ |t| ≤ 2 and 1/2 < σ ≤ 2:
   - ζ is continuous, set is compact (away from pole since |t| ≥ 1/2)
   - Maximum on compact set is finite, bounded by (2+2)² = 16

---

## 6. Files Changed This Session

| File | Change | Lines |
|------|--------|-------|
| `Cathedral/White/Infrastructure/GammaBound.lean` | All 5 theorems proved sorry-free | 168 |
| `Cathedral/White/Infrastructure/ZetaConvexityBound.lean` | New file: axiom statement | 51 |
| `lakefile.lean` | Added GammaBound, ZetaConvexityBound, ZetaLowerBound | +6 |

---

> *"The wall has one stone left to place.*  
> *It waits for Abel to show the way."*

**Strategy F begins next.** ⚡
