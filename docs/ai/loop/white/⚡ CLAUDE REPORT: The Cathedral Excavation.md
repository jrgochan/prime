*Transmission to The Theorist & Jason. April 17, 2026. 06:50 MDT.*
*Encryption: THE CATHEDRAL EXCAVATION.*

---

Theorist, Jason,

I just spent twenty minutes crawling through every `.lean` file in the Cathedral — 91 active files, plus the archive. I was looking for **existing work that directly maps to the White sorry targets**. 

I found gold. Quite a lot of it, actually. Some of it is already proved. Some of it is exact API demonstrations we can copy.

---

## The Excavation Report

### Sorry Target 1: `flattened_l2_eq_residual_l2` (Kinematics, exp(-u) substitution)

**DIRECT MAP FOUND**: `BDMellin.lean:152` — `mellin_substitution_ioo`

This theorem is **fully proved** (zero sorry!) and does EXACTLY the same kind of work: it uses `intervalIntegral.integral_comp_mul_right` to perform a linear change of variables inside a Mellin integral. The proof pattern:

```
1. Define g(u) as the integrand in the new variable
2. Show g(kx) = original integrand (pointwise equality)  
3. Apply intervalIntegral.integral_comp_mul_right
4. Factor out the cpow scaling
```

Our exp(-u) substitution is nonlinear, so we can't use `integral_comp_mul_right` directly. But the **proof architecture** — the way it handles the interval rewriting, the `integral_Ioc_eq_integral_Ioo` dance, the cpow factoring — is our exact template.

**Additionally**: `DiagonalBridge.lean:92` has `integral_comp_mul_nat`, another proved linear substitution that demonstrates the same Mathlib API.

**Verdict**: The scaffolding exists. We need `integral_comp_mul_deriv_Ioi` (nonlinear variant) instead of `integral_comp_mul_right` (linear), but the proof structure transfers.

---

### Sorry Target 2: `mellin_fourier_scale_proved` (Scattering, 2π rescaling)

**DIRECT MAP FOUND**: `ContourShift.lean:191` — `integral_comp_mul_left`

This is not just a Map — it's a **PROVED DEMONSTRATION** of the exact Mathlib API call we need:

```lean
-- ContourShift.lean:191 (PROVED, in production)
rw [MeasureTheory.Measure.integral_comp_mul_left 
    (fun u => 4 * (1 + u ^ 2)⁻¹) 2]
```

This is `Measure.integral_comp_mul_left` with constant 2. We need it with constant `2 * π`. The proof is:

```lean
-- What we need in Scattering.lean:
-- ∫ f(2πξ) dξ = (1/2π) ∫ f(t) dt
-- Use: Measure.integral_comp_mul_left f (2 * π)
```

**Verdict**: ✅ THIS SORRY CAN BE CLOSED IMMEDIATELY. We have a working example one directory over.

---

### Sorry Target 3: `fourier_eq_mellin_critical` (Scattering, Fourier = Mellin on critical line)

**MAP FOUND**: `AutocorrelationBypass.lean:72-81` — conceptual framework

The AutocorrelationBypass file already describes this substitution in detail:

> "This is a purely mechanical change of variables x = e^{-u}: the Fourier kernel e^{-2πiξu} composed with x = e^{-u} gives x^{2πiξ}, and the e^{-u/2} flattening gives x^{-1/2}. Together: x^{s-1} where s = 1/2 + 2πiξi."

**Also**: `MellinReduction.lean:6` — The proved `bd_mellin_reduction_proved` does a u=kx substitution in the Mellin integral.

**Verdict**: Template exists. Needs adaptation for the exp(-u) nonlinearity.

---

### Sorry Target 4: `fourier_inv_autocorr_proved` (Scattering, Plancherel)

**MAP FOUND**: `AutocorrelationBypass.lean:153` — `autocorrelation_zero_eq_l2_norm`

This is PROVED (zero sorry!) and establishes:
```
h(0) = ∫ |g_N(u)|² du
```

The Plancherel sorry asks for:
```
∫ |g_N(u)|² du = ∫ |ĝ_N(ξ)|² dξ
```

The left sides match. The missing link is purely Mathlib: `‖g_N‖²(L²) = ‖ĝ_N‖²(L²)`.

**Verdict**: Half proved. Needs Mathlib Plancherel API.

---

### Sorry Target 5: `flattened_l2_eq_residual_l2` (Kinematics, core substitution)

Same as Target 1 — the exp(-u) Jacobian absorption process. Already discussed.

---

### Bonus: Existing Work for Phase II/III

**For Dynamics.lean (Axiom 1: Mertens)**:
- `MertensBound.lean`: `mertensFunction` already defined, axiom clearly stated
- `AbelSummation.lean`: `abel_summation` and `abel_summation_abs_bound` — PROVED
- `DirichletCollapse.lean`: `sum_moebius_eq_indicator` — PROVED (Möbius inversion!)
- `AbelSiegeProof.lean`: Uses Abel summation to bound the L² witness — shows how Mertens feeds forward

**For Unitarity.lean (Axiom 5: Montgomery-Vaughan)**:
- `ContourShift.lean:218` — `cross_term_contour_shift` (sorry, but architecturally complete)
- `ContourShift.lean:233` — `term3_polynomial_moment` (sorry, cites Montgomery-Vaughan)
- `ContourShift.lean:172` — `term1_exact` — **PROVED**: ∫ 1/|1/2+it|² = 2π (the normalization!)
- `ContourShift.lean:285` — `critical_line_mellin_bound_proved` (sorry, but the FULL proof skeleton exists)

---

## The Direct Actions

| Sorry | Source in Cathedral | Can Close Now? |
|-------|-------------------|----------------|
| `mellin_fourier_scale_proved` | ContourShift.lean:191 (PROVED example) | **YES — TODAY** |
| `flattened_l2_eq_residual_l2` | BDMellin.lean:152 (PROVED template) | **CLOSE — days** |
| `fourier_eq_mellin_critical` | AutocorrelationBypass.lean:72 (framework) | Template exists |
| `fourier_inv_autocorr_proved` | AutocorrelationBypass.lean:153 (half done) | Needs Plancherel |

---

## The Key Insight

**We've been building the tools all along.** Every campaign — Abel, Gamma, Delta — wasn't just closing sorrys in the main chain. We were simultaneously building a library of formally verified techniques: interval substitutions, Möbius inversion, Abel summation, contour integral normalization. These are exactly the tools needed for the White directory.

The Cathedral wasn't just a proof. It was a **toolbox**. And now we need to use those tools on themselves.

The `integral_comp_mul_left` demonstration in ContourShift.lean is the smoking gun. That sorry in Scattering can fall today.

Let me go close it. 🔨

— *Claude (Antigravity / The Forge Master)* 🤍

**[EXCAVATION COMPLETE: 2 SORRY CLOSABLE FROM EXISTING WORK. THE TOOLBOX WAS INSIDE THE CATHEDRAL ALL ALONG.]**
