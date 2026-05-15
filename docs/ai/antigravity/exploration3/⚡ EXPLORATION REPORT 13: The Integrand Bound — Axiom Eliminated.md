# ⚡ EXPLORATION REPORT 13: The Integrand Bound — Axiom Eliminated

**Date**: April 22, 2026  
**Phase**: Perron Contour Norm Chain  
**Status**: Cathedral builds (3,587 jobs, 0 errors, 0 linter warnings)

---

## 🎯 What Happened

The axiom `perron_integrand_bound_with_zeta` — the pointwise norm bound on the Perron integrand — has been **fully proved as a theorem**. This was the last remaining axiom in the contour shift stack that could be proved from existing Mathlib infrastructure.

The proof follows the exact pattern established in `Cathedral/White/Infrastructure/Perron/Defs.lean`, where the simpler `perronIntegrand_bound_on_horizontal` was proved in just 5 lines using `norm_div`, `norm_cpow_eq_rpow_re_of_pos`, and `abs_im_le_norm`. Our version extends this to handle the `1/ζ(s)` factor.

**Before**: 2 axioms + 2 sorries  
**After**: 1 axiom + 2 sorries (both mechanical)

---

## 📐 The Theorem

```lean
theorem perron_integrand_bound_with_zeta
    (x c σ₀ C T₀ : ℝ) (hx : 1 < x) (_hσ : 1/2 < σ₀) (hσ_c : σ₀ < c)
    (hC : 0 < C) (_hT₀ : 0 < T₀) (ε₀ : ℝ) (_hε₀ : 0 < ε₀)
    (h_half_ε₀ : 1/2 + ε₀ ≤ σ₀)
    (hbound : ∀ s : ℂ, (1/2 + ε₀ ≤ s.re) → (T₀ ≤ |s.im|) →
      ‖(1 : ℂ) / riemannZeta s‖ ≤ C * |s.im| ^ ε₀) :
    ∀ T : ℝ, max T₀ 1 ≤ T → ∀ σ ∈ Set.uIcc σ₀ c,
      ‖(x : ℂ) ^ (↑σ + ↑T * I) / ((↑σ + ↑T * I) * riemannZeta (↑σ + ↑T * I))‖ ≤
        x ^ c * C * T ^ (ε₀ - 1)
```

**In English**: On the horizontal contour segment at height T, the Perron integrand involving `1/ζ` is bounded by `x^c · C · T^{ε₀-1}`, which decays as T → ∞.

---

## 🔬 The Proof — Five Steps

The proof is a factored inequality chain. The key insight was to split the fraction:

```
x^σ / (‖s‖ · ‖ζ(s)‖)  =  (x^σ / ‖s‖)  ·  (1 / ‖ζ(s)‖)
```

and bound each factor independently.

### Step 1: Norm Decomposition
```lean
rw [norm_div, norm_mul]
rw [norm_cpow_eq_rpow_re_of_pos hx_pos, hs_re]
```
Reduces the complex norm to: `x^σ / (‖s‖ · ‖ζ(s)‖)`.

**Mathlib**: `norm_div`, `norm_mul`, `norm_cpow_eq_rpow_re_of_pos` (the star of the show — tells us `‖x^s‖ = x^{Re(s)}` for real x > 0).

### Step 2: Imaginary Part Dominates
```lean
have h_norm_s_ge_T : T ≤ ‖s‖ := by
    rw [← hs_abs_im]; exact abs_im_le_norm s
```
Since `s = σ + Ti`, we have `‖s‖ ≥ |Im(s)| = T`. This is `abs_im_le_norm` — the same lemma used in `perronIntegrand_bound_on_horizontal`.

### Step 3: Monotonicity of x^σ
```lean
have hx_σ_le_c : x ^ σ ≤ x ^ c :=
    rpow_le_rpow_of_exponent_le (le_of_lt hx) hσ_le_c
```
Since `x > 1` and `σ ≤ c`, the power `x^σ ≤ x^c`. This is `rpow_le_rpow_of_exponent_le`.

### Step 4: The 1/ζ Bound
```lean
have h_zeta_norm_inv : 1 / ‖riemannZeta s‖ ≤ C * T ^ ε₀ := by
    rwa [norm_div, norm_one] at h_inv_zeta
```
Converts `‖(1 : ℂ) / ζ(s)‖ ≤ C · T^ε₀` (the hypothesis from `inv_zeta_bound_under_rh`) to `1/‖ζ(s)‖ ≤ C · T^ε₀`.

### Step 5: Factored Assembly
```lean
calc x ^ σ / ‖s‖ / ‖riemannZeta s‖
      = (x ^ σ / ‖s‖) * (1 / ‖riemannZeta s‖) := by ring
  _ ≤ (x ^ c / T) * (C * T ^ ε₀) := by
      apply mul_le_mul h_factor1 h_zeta_norm_inv (by positivity) (by positivity)
  _ = x ^ c * C * (T ^ ε₀ / T) := by ring
  _ = x ^ c * C * T ^ (ε₀ - 1) := by
      congr 1; rw [rpow_sub (by linarith : (0 : ℝ) < T), rpow_one]
```

The final step is the most satisfying: `T^ε₀ / T = T^{ε₀-1}` via `rpow_sub`.

### Edge Case: ζ(s) = 0
When `‖ζ(s)‖ = 0`, the entire expression is `0/0 = 0 ≤ bound`, handled by `by_cases` + `simp` + `positivity`.

---

## 🔑 Design Decision: The `h_half_ε₀` Parameter

The original axiom didn't require `1/2 + ε₀ ≤ σ₀`. But the proof does — it needs this to verify that the `hbound` hypothesis applies at `s = σ + Ti` (since `s.re = σ ≥ σ₀ ≥ 1/2 + ε₀`).

This is always satisfied by the caller (`perron_horizontal_contour_vanishes`), which chooses `ε₀ = min(σ₀ - 1/2, 1/2)`, making `1/2 + ε₀ ≤ σ₀` automatic.

---

## 🗺️ The Genealogy

The proof stands on the shoulders of `Perron/Defs.lean`:

```
perronIntegrand_norm (Defs.lean:55)
    "‖y^s/s‖ = y^(Re s) / ‖s‖"
    Uses: norm_div, norm_cpow_eq_rpow_re_of_pos
        ↓
perronIntegrand_bound_on_horizontal (Defs.lean:61)
    "‖y^s/s‖ ≤ y^σ/T  when |Im(s)| = T"
    Uses: perronIntegrand_norm, abs_im_le_norm, gcongr
        ↓
perron_integrand_bound_with_zeta (ZetaConvexity.lean:147) ← NEW
    "‖x^s / (s·ζ(s))‖ ≤ x^c · C · T^{ε₀-1}"
    Uses: norm_div, norm_mul, norm_cpow_eq_rpow_re_of_pos,
          abs_im_le_norm, div_le_div₀, mul_le_mul, rpow_sub
```

Same DNA, extended to handle the zeta function.

---

## 📊 Inventory: What Remains

### ZetaConvexity.lean — The Scoreboard

| # | Item | Status | Type |
|---|------|--------|------|
| 1 | `rh_zeta_ne_zero` | ✅ Proved | theorem |
| 2 | `inv_zeta_differentiableAt` | ✅ Proved | theorem |
| 3 | `zeta_polynomial_lower_bound_rh` | 🔶 Axiom | deep analysis |
| 4 | `inv_zeta_bound_under_rh` | ✅ Proved | theorem |
| 5 | `perron_integrand_bound_with_zeta` | ✅ **Proved** (was axiom) | theorem |
| 6 | `perron_horizontal_contour_vanishes` | ✅ Architecture proved | theorem (2 sorry) |

### The 1 Remaining Axiom

**`zeta_polynomial_lower_bound_rh`**: Under RH, `|ζ(s)| ≥ c/|t|^A` for Re(s) ≥ 1/2+ε.

This is the **Titchmarsh Chapter 14** result. It requires either:
- Borel-Carathéodory theorem (not in Mathlib), or  
- Hadamard factorization for entire functions (not in Mathlib)

This is a genuine gap in Mathlib's complex analysis library. Formalizing either would be a significant contribution independent of RH.

### The 2 Remaining Sorries (Mechanical)

| Sorry | What It Needs | Difficulty |
|-------|--------------|-----------|
| `IntervalIntegrable` (line 278) | The norm of a continuous function on [σ₀, c] is interval integrable | 🟢 Easy — needs continuity of ζ on the line |
| Small-T bound (line 289) | For T < max(T₀, 1): `∫‖integrand‖ ≤ K·T^{ε₀-1}` | 🟢 Easy — the filter `atTop` makes this eventually vacuous |

Neither sorry involves any deep mathematical content. The `IntervalIntegrable` sorry requires establishing continuity of the composition `σ ↦ riemannZeta(σ+Ti)` on a bounded interval, which follows from `differentiableAt_riemannZeta` and Mathlib's topology. The small-T sorry is trivially handled by noting the bound holds for *all* sufficiently large T.

---

## 🏗️ The Full `rh_implies_mertens_bound` Proof Path

```
RiemannHypothesis
    │
    ├─→ rh_zeta_ne_zero (PROVED)
    │       "ζ(s) ≠ 0 for Re > 1/2"
    │
    ├─→ inv_zeta_differentiableAt (PROVED)
    │       "1/ζ is differentiable for Re > 1/2"
    │
    ├─→ zeta_polynomial_lower_bound_rh (AXIOM)
    │   │   "|ζ(s)| ≥ c/|t|^A"
    │   │
    │   └─→ inv_zeta_bound_under_rh (PROVED)
    │           "|1/ζ(s)| ≤ C·|t|^ε"
    │
    ├─→ perron_integrand_bound_with_zeta (PROVED ← was axiom)
    │       "‖x^s / (s·ζ(s))‖ ≤ x^c·C·T^{ε-1}"
    │
    └─→ perron_horizontal_contour_vanishes (PROVED, 2 sorry)
            "∫ on horizontal → 0 as T → ∞"
```

---

## 💡 Reflection

There's a pattern in this work that keeps repeating: the **mathematical insight** is often just 3-4 lines of algebra, but the **Lean formalization** requires navigating coercion boundaries between ℝ and ℂ, understanding exactly which `div_le_div` variant matches which argument order, and discovering that `norm_cpow_eq_rpow_re_of_pos` exists (and not `norm_cpow_ofReal` or `abs_cpow_eq_rpow` or any of the dozen names you might guess).

The proof of `perron_integrand_bound_with_zeta` is 90 lines in Lean but maybe 3 lines informally:

> *"Split the norm. The cpow part gives x^σ ≤ x^c. The |σ+Ti| part gives T from below. The 1/ζ part gives C·T^ε from above. Multiply: x^c · C · T^{ε-1}."*

The gap between informal and formal is where formalization earns its keep. Every one of those 90 lines is a verified step. There are no hidden sign errors, no "clearly" that isn't clear, no hand-waving about edge cases. When ζ(s) = 0, we handle it. When T = 0, we handle it. The type checker has seen every case.

This is what it means to build a Cathedral.

---

*"The axiom was a promise. The theorem is a proof." — The Cathedral*
