# ⚡ EXPLORATION REPORT 14: Zero Sorries — The Contour Is Closed

**Date**: April 22, 2026  
**Phase**: Horizontal Contour Vanishing — Final Sorry Elimination  
**Status**: ZetaConvexity.lean: 0 sorries, 0 errors, 0 warnings. Cathedral: 3,587 jobs clean.

---

## 🏆 The Result

`Cathedral/White/Infrastructure/ZetaConvexity.lean` now contains **zero `sorry` placeholders**.

Every theorem in the file — from `rh_zeta_ne_zero` through `perron_horizontal_contour_vanishes` — is either fully proved or depends on the single remaining axiom `zeta_polynomial_lower_bound_rh` (the deep analytical fact requiring Borel-Carathéodory or Hadamard factorization, neither of which exist in Mathlib).

**This session eliminated 3 sorries in total**: the `perron_integrand_bound_with_zeta` axiom (Report 13), the `IntervalIntegrable` sorry, and the small-T sorry.

---

## 🔬 What Was Proved

### Sorry 1: Small-T Bound → Eliminated via `squeeze_zero'`

**The problem**: The original `squeeze_zero` required `∀ T, ∫ ‖integrand‖ ≤ K · T^{ε₀-1}` for ALL T, including small T where we don't have the pointwise bound (the bound hypothesis `hbound` only applies when `T ≥ max(T₀, 1)`).

**The fix**: Switched from `squeeze_zero` to `squeeze_zero'`, which accepts **eventually** conditions:

```lean
-- Before (requires ∀ T):
apply squeeze_zero
· intro T; ...  -- nonneg: works for all T ✓
· intro T; ...  -- upper bound: FAILS for small T ✗

-- After (requires ∀ᶠ T in atTop):
apply squeeze_zero'
· exact Filter.Eventually.of_forall fun T => ...  -- nonneg: works for all T ✓
· apply Filter.Eventually.mono (Filter.eventually_ge_atTop (max T₀ 1))
  intro T hT; ...  -- upper bound: only for T ≥ max(T₀, 1) ✓
```

**Mathematical justification**: We only need the sandwich inequality eventually — the limit `T → ∞` doesn't care about finitely many values of T.

**Key Mathlib discovery**: `squeeze_zero'` at `Topology.MetricSpace.Pseudo.Lemmas:32`.

---

### Sorry 2: IntervalIntegrable → Eliminated via `mono_fun'` + `ContinuousOn`

**The problem**: Show that `σ ↦ ‖x^(σ+Ti) / ((σ+Ti) · ζ(σ+Ti))‖` is interval integrable on `[σ₀, c]`.

**The fix**: Two-part proof using `IntervalIntegrable.mono_fun'`:

#### Part A: AEStronglyMeasurable (measurability)

The function `σ ↦ x^(σ+Ti) / ((σ+Ti) · ζ(σ+Ti))` is **continuous** on `(σ₀, c)`, hence measurable.

This required proving `ContinuousOn` by decomposing into pieces:

```
σ ↦ ↑σ + ↑T * I              — continuous (continuous_ofReal.add continuous_const)
    ↓
s ↦ x^s                       — continuous (ContinuousOn.const_cpow, x ≠ 0)
s ↦ ζ(s)                      — continuous (differentiableAt_riemannZeta, s ≠ 1)
s ↦ s · ζ(s)                  — continuous (ContinuousOn.mul)
    ↓
(f, g) ↦ f / g                — continuous (ContinuousOn.div, g ≠ 0)
```

**Critical verification**: `s = σ + Ti ≠ 1` because `Im(s) = T ≥ 1 > 0 = Im(1)`.

**Critical verification**: `s · ζ(s) ≠ 0` because:
- `s ≠ 0`: since `Im(s) = T ≥ 1 > 0 = Im(0)`
- `ζ(s) ≠ 0`: by `rh_zeta_ne_zero hRH` since `Re(s) = σ ≥ σ₀ > 1/2` and `s ≠ 1`

**Key insight**: The ζ nonvanishing used `rh_zeta_ne_zero`, our own theorem from §1 of the same file. The proof feeds back on itself — the zero-free region proved at the top of the file is consumed at the bottom to establish continuity.

#### Part B: Norm bound a.e.

```lean
apply (ae_restrict_mem measurableSet_uIoc).mono
intro σ hσ
simp only [Real.norm_of_nonneg (norm_nonneg _)]
exact h_pw σ (Set.uIoc_subset_uIcc hσ)
```

Since `mono_fun'` works on the restricted measure `volume.restrict (Ι σ₀ c)`, we only need the bound for `σ ∈ Ι σ₀ c ⊆ uIcc σ₀ c`, where `h_pw` (from `perron_integrand_bound_with_zeta`) directly applies.

---

## 📐 The Complete Architecture

```
ZetaConvexity.lean (347 lines, 0 sorry)
═══════════════════════════════════════

§1. RH → Zero-Free Region
    ├── not_trivial_zero_of_re_pos (private lemma)
    └── rh_zeta_ne_zero ✅
        "ζ(s) ≠ 0 for Re(s) > 1/2 under RH"

§2. Differentiability
    └── inv_zeta_differentiableAt ✅
        "1/ζ differentiable for Re > 1/2"

§3. The Deep Analytical Fact
    └── zeta_polynomial_lower_bound_rh 🔶 AXIOM
        "|ζ(s)| ≥ c/|t|^A under RH"
        (Requires Borel-Carathéodory, not in Mathlib)

§4. Conditional Bounds
    └── inv_zeta_bound_under_rh ✅
        "|1/ζ(s)| ≤ C·|t|^ε under RH"

§5. Pointwise Integrand Bound
    └── perron_integrand_bound_with_zeta ✅  ← was axiom
        "‖x^s/(s·ζ(s))‖ ≤ x^c · C · T^{ε-1}"

§6. Horizontal Contour Vanishing
    └── perron_horizontal_contour_vanishes ✅  ← was 2 sorry
        "∫ horizontal → 0 as T → ∞"
        Uses: squeeze_zero' + ContinuousOn + rh_zeta_ne_zero
```

---

## 🧬 The Self-Reference

The most beautiful moment in this proof is the self-reference: `perron_horizontal_contour_vanishes` at line 232 uses `rh_zeta_ne_zero` from line 50 — a theorem proved 180 lines earlier in the same file — to establish that the denominator `s · ζ(s)` is nonzero, which is needed for the `ContinuousOn.div` call, which is needed for `AEStronglyMeasurable`, which is needed for `IntervalIntegrable`, which is needed for `integral_mono_on`, which establishes the upper bound in the squeeze.

The proof chain:

```
rh_zeta_ne_zero → ContinuousOn.div → ContinuousOn.norm
    → ContinuousOn.aestronglyMeasurable → IntervalIntegrable.mono_fun'
    → integral_mono_on → squeeze_zero' → Tendsto → QED
```

Every link is verified. There are no gaps.

---

## 📊 The Scoreboard

### Before This Session
| Item | Status |
|------|--------|
| `perron_integrand_bound_with_zeta` | 🔴 **Axiom** |
| `IntervalIntegrable` | 🔴 Sorry |
| Small-T bound | 🔴 Sorry |
| `zeta_polynomial_lower_bound_rh` | 🔶 Axiom |

### After This Session
| Item | Status | How |
|------|--------|-----|
| `perron_integrand_bound_with_zeta` | ✅ **Proved** | norm decomposition + factored inequality |
| `IntervalIntegrable` | ✅ **Proved** | ContinuousOn + mono_fun' + rh_zeta_ne_zero |
| Small-T bound | ✅ **Proved** | squeeze_zero' (eventually) |
| `zeta_polynomial_lower_bound_rh` | 🔶 Axiom | Requires Borel-Carathéodory |

**Net result**: 1 axiom eliminated, 2 sorries eliminated. File is sorry-free.

---

## 🔮 What Remains

The entire `ZetaConvexity.lean` file now depends on exactly **one** axiom:

```lean
axiom zeta_polynomial_lower_bound_rh (hRH : RiemannHypothesis)
    (ε : ℝ) (hε : 0 < ε) (A : ℝ) (hA : 0 < A) :
    ∃ c > 0, ∃ T₀ > 0, ∀ s : ℂ,
      (1/2 + ε ≤ s.re) → (T₀ ≤ |s.im|) →
      c / |s.im| ^ A ≤ ‖riemannZeta s‖
```

This states: under RH, `|ζ(s)|` has a polynomial lower bound away from the critical line. It's Titchmarsh Chapter 14, Theorem 14.2. The standard proof uses:

1. **Hadamard factorization** of `ξ(s)` → bounds on `ζ'/ζ` → integration gives log|ζ| bounds
2. Alternatively: **Borel-Carathéodory** applied to `log ζ(s)` in a disk

Neither the Hadamard product formula for entire functions of finite order, nor the Borel-Carathéodory theorem, exist in Mathlib as of April 2026. Formalizing either would be a significant contribution to the mathematical library.

### The Broader Picture

With `ZetaConvexity.lean` sorry-free, the `rh_implies_mertens_bound` proof path has one fewer axiom on its critical path. The remaining work involves:

1. **Resolving `zeta_polynomial_lower_bound_rh`** (Borel-Carathéodory — future work)
2. **The Mertens assembly** — connecting the contour vanishing to the actual M(x) bound using Perron's formula
3. **The Vasyunin path** — connecting Mertens bounds to L² decay of Báez-Duarte

---

## 💡 Lessons Learned

### 1. `squeeze_zero'` > `squeeze_zero`
When proving `Tendsto f atTop (nhds 0)` by squeezing, prefer `squeeze_zero'` unless youknow the bounds hold for ALL inputs. In analytic number theory, bounds typically hold for "sufficiently large" parameters, making `squeeze_zero'` the natural choice.

### 2. Measurability requires continuity which requires nonvanishing which requires RH
The deepest surprise was that `IntervalIntegrable` — seemingly a "mechanical" step — required invoking `rh_zeta_ne_zero`. This is because:
- Integrability needs measurability
- Measurability follows from continuity
- Continuity of `f/g` requires `g ≠ 0`
- `g = s · ζ(s) ≠ 0` requires `ζ(s) ≠ 0` for `Re(s) > 1/2`
- `ζ(s) ≠ 0` for `Re(s) > 1/2` IS the Riemann Hypothesis

So even the *well-definedness* of the contour integral depends on RH. This is analytically obvious (the integrand has a pole where ζ vanishes) but seeing it appear as a formal dependency in the type checker is striking.

### 3. `ae_restrict_mem` is the restricted measure workhorse
When proving `∀ᵐ x ∂(μ.restrict s), P x` and you know `∀ x ∈ s, P x`, use:
```lean
apply (ae_restrict_mem hs_meas).mono
intro x hx
exact ...
```
This avoids the trap of `ae_of_all` (which gives ∀ x, not just x ∈ s).

### 4. `ContinuousAt.comp` for function compositions
When showing `ContinuousAt (f ∘ g) x`, use:
```lean
exact ContinuousAt.comp (hf : ContinuousAt f (g x)) (hg : ContinuousAt g x)
```
Not `comp_continuousWithinAt` or other variants — `ContinuousAt.comp` unifies cleanly.

---

*"The contour is closed. Every point on the path is verified. The only gap is the depth of the zeta function itself." — The Cathedral*
