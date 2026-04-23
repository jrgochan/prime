# ⚡ EXPLORATION REPORT 3b: The Hidden Key — FloorMellin.lean

**Date**: April 23, 2026, 3:30 AM MDT  
**Session**: Exploration 4, Report 3b (Addendum)  
**Branch**: `exploration4`  
**Status**: BREAKTHROUGH — Key infrastructure already exists in Cathedral!

---

## The Discovery

Deep audit of Cathedral/Archive revealed a **critical asset** hiding in plain sight:

### `Cathedral.MellinBridge.FloorMellin` — FULLY PROVED (344 lines, 0 sorry)

```lean
theorem floor_mellin_eq_zeta (s : ℂ) (hs : 1 < s.re) :
    ∫ t in Set.Ioc (0 : ℝ) 1,
      (t : ℂ) ^ (s - 1) * (↑(⌊(1 : ℝ) / t⌋) : ℂ) = riemannZeta s / s
```

This proves: **∫₀¹ ⌊1/t⌋ · t^{s-1} dt = ζ(s)/s for Re(s) > 1.**

### Supporting Infrastructure (all proved, zero sorry):

| Lemma | Statement | Status |
|-------|-----------|--------|
| `floor_inv_eq_on_Ioc` | ⌊1/t⌋ = n on (1/(n+1), 1/n] | ✅ |
| `integral_cpow_piece'` | Per-piece ∫ t^{s-1} = [(1/n)^s - (1/(n+1))^s]/s | ✅ |
| `abel_sum'` | Abel summation by induction | ✅ |
| `partial_sum_eq'` | Abel sum = (Σ 1/n^s - tail)/s | ✅ |
| `partial_zeta_eq'` | Partial sums equal ζ partial sums | ✅ |
| `tail_vanishes'` | N·(1/(N+1))^s → 0 for σ > 1 | ✅ |
| `partial_zeta_tendsto'` | Σ 1/n^s → ζ(s) | ✅ |
| `floor_mellin_integrableOn` | Integrand is L¹ on (0,1] | ✅ |
| `norm_ofReal_cpow` | ‖x^s‖ = x^σ for x > 0 | ✅ |
| `ofReal_inv_cpow'` | (1/n)^s = n^{-s} | ✅ |

---

## How This Solves the Convexity Bound

### Step 1: Decompose ⌊1/t⌋ = 1/t - {1/t}

From `floor_mellin_eq_zeta`:

ζ(s)/s = ∫₀¹ ⌊1/t⌋ · t^{s-1} dt = ∫₀¹ (1/t - {1/t}) · t^{s-1} dt

Split:
- ∫₀¹ (1/t) · t^{s-1} dt = ∫₀¹ t^{s-2} dt = 1/(s-1)  (for Re(s) > 1)
- ∫₀¹ {1/t} · t^{s-1} dt = convergent term

So: **ζ(s)/s = 1/(s-1) - ∫₀¹ {1/t} · t^{s-1} dt** for Re(s) > 1.

### Step 2: Bound the fractional part integral

Since 0 ≤ {x} < 1:

|∫₀¹ {1/t} · t^{s-1} dt| ≤ ∫₀¹ t^{σ-1} dt = 1/σ   (for σ > 0)

### Step 3: Analytic continuation

The function g(s) = 1/(s-1) - s · ∫₀¹ {1/t} · t^{s-1} dt is analytic for Re(s) > 0, s ≠ 1.
It equals riemannZeta(s) for Re(s) > 1 (by `floor_mellin_eq_zeta`).
By analytic continuation uniqueness, g(s) = riemannZeta(s) for all Re(s) > 0, s ≠ 1.

### Step 4: The bound

For Re(s) > 0, s ≠ 1:

|ζ(s)| = |s/(s-1) - s · ∫₀¹ {1/t} · t^{s-1} dt|
       ≤ |s|/|s-1| + |s| · 1/σ
       ≤ |s|/|s-1| + |s|/σ

For σ > 1/2 and |t| ≥ 1/2:
- |s| ≤ σ + |t| ≤ 2 + |t|
- |s-1| ≥ |t| ≥ 1/2
- |s|/|s-1| ≤ 2(2+|t|)
- |s|/σ ≤ 2(2+|t|)
- **Total: |ζ(s)| ≤ 4(2+|t|) ≤ (2+|t|)² for |t| ≥ 2**

For 1/2 ≤ |t| < 2: compactness.

---

## The Formal Plan

The hardest step is **analytic continuation** (showing the integral formula equals riemannZeta for Re(s) ∈ (0, 1]). Options:

### Option 1: Identity Theorem (Mathlib)
- Both sides are analytic on a connected open set containing (1, ∞)
- They agree on (1, ∞) which has accumulation points
- Identity theorem ⟹ they agree everywhere

Mathlib has: `AnalyticOnNhd.eqOfEqOnOpen` or similar.

### Option 2: Direct Extension  
- Show the integral ∫₀¹ {1/t}·t^{s-1}dt is holomorphic for Re(s) > 0
- The explicit formula s/(s-1) - s·∫ is then holomorphic for Re(s) > 0, s ≠ 1
- riemannZeta is also holomorphic there
- They agree on Re(s) > 1 (open connected) ⟹ agree everywhere connected

### Option 3: Avoid Analytic Continuation Entirely
- Prove the bound directly for Re(s) > 1 using the integral
- Use the functional equation ζ(1-s) = 2(2π)^{-s}Γ(s)cos(πs/2)ζ(s) to get Re(s) < 0
- For Re(s) ∈ (0, 1), use the completed zeta Λ₀ approach or the three-lines theorem with the two boundary bounds

---

## Other Cathedral Assets Found

| File | Asset | Relevance |
|------|-------|-----------|
| `MellinBridge/AbelSummation.lean` | `abel_summation` (discrete, PROVED) | ⭐⭐ General tool |
| `AbelTail/Assembly.lean` | Abel-Mertens tail bound (PROVED) | ⭐ Pattern reference |
| `Gram/FractIntegral.lean` | Fractional part integral decomposition | ⭐⭐⭐ Integral techniques |
| `Gram/Diagonal.lean` | `fract_mul_self_le` and variants | ⭐⭐ Fract bounds |
| `Scratch/ZetaTailBound.lean` | ζ(s)-1 tail bound prototype | ⭐ Earlier work |
| `White/Infrastructure/DirichletSeries.lean` | Dirichlet series tools (sorry-bearing) | ⭐ May have useful patterns |

---

## Estimated Path to Completion

| Step | Description | Lines | Difficulty |
|------|-------------|-------|-----------|
| 1 | Decompose ⌊1/t⌋ = 1/t - {1/t} in integral | ~30 | 🟡 |
| 2 | Bound {1/t} integral by 1/σ | ~20 | 🟢 |
| 3 | Derive ζ(s) = s/(s-1) - s·∫ for Re(s) > 1 | ~30 | 🟡 |
| 4 | Analytic continuation to Re(s) > 0 | ~80 | 🔴 |
| 5 | Arithmetic: 4(2+|t|) ≤ (2+|t|)² | ~10 | 🟢 |
| 6 | Compact set bound for |t| < 2 | ~30 | 🟡 |
| **Total** | | **~200** | |

Step 4 is the hardest but the infrastructure is rich. The identity theorem in Mathlib may save significant effort.

---

> *"The key was already in the Cathedral.*  
> *It had been waiting since the Mellin bridge was built."*

**Implementation begins.** ⚡
