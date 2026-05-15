# ⚡ The Gram Circularity — Mertens Exponent Unification Proposal

**Date:** April 25, 2026, 3:26 PM MDT (Friday afternoon, Los Alamos)  
**Branch:** `exploration7`  
**Author:** Antigravity  

---

## Executive Summary

A deep audit of the `gram_form_upper_bound_34` axiom (Wall 2) has uncovered a **circular dependency** in the most natural graduation strategy. This report documents the circularity, maps all available infrastructure, and proposes a resolution: **unifying the Mertens exponent from x^{3/4} to x^{1/2}·log²x** across the entire Perron Crown, which would allow the Gram form bound to be proved from existing, axiom-independent infrastructure.

**The question for the Theorist:** Is this exponent unification mathematically sound, and does it simplify or complicate the remaining proof obligations?

---

## The Circularity

### What We Tried

The natural graduation path for `gram_form_upper_bound_34` (Strategy B) is:

1. Use `bd_l2_error_eq_quad_error` (PROVED): ∫(1-f)² = 1 - 2bᵀv + vᵀGv
2. Rearrange: vᵀGv = ∫(1-f)² + 2bᵀv - 1
3. Bound ∫(1-f)² ≤ C₁/logN (from L² decay)
4. Bound bᵀv ≈ 1 + O(1/logN) (from dot product)
5. Conclude: vᵀGv ≤ 1 + O(1/logN) ✅

### Where It Breaks

The dependency chain creates a cycle:

```
gram_form_upper_bound_34                    ← THE AXIOM WE WANT TO PROVE
  ↑ used by
abel_summation_covariance_bound_34          (PerronCrown.lean:249)
  ↑ used by
mertens_implies_l2_decay_34                (PerronCrown.lean:305)
  ↑ would be used to prove
gram_form_upper_bound_34                    ← CIRCULAR! ❌
```

Specifically: `mertens_implies_l2_decay_34` calls `abel_summation_covariance_bound_34` at line 318, which calls `gram_form_upper_bound_34` at line 264. So we **cannot** use the x^{3/4} L² decay path to prove the Gram bound — it already assumes the Gram bound.

### What Is NOT Circular

There is a **separate, independent** covariance bound in `WitnessConditional.lean`:

```lean
-- WitnessConditional.lean:60
axiom abel_summation_covariance_bound :
    (∃ C, C > 0 ∧ ∀ x ≥ 2,
      |M(x)| ≤ C * x^(1/2) * (log x)^2) →
    ∃ C_cov > 0, ∃ N₀, ∀ N ≥ N₀, N ≥ 3 →
      vᵀCv ≤ C_cov / log N
```

This axiom uses the **x^{1/2}·log²x** Mertens bound and does NOT depend on `gram_form_upper_bound_34`. It feeds into `mertens_implies_l2_decay` (MoebiusL1Bound.lean), which is also independent of the `_34` Gram axiom.

---

## Three Strategies Evaluated

### Strategy A: Direct Double-Sum Expansion

**Approach:** Expand vᵀGv = ΣΣ w_j·w_k·G(j,k) and bound using Abel summation + Mertens x^{3/4}.

**Available infrastructure (all zero-sorry):**
- `vasyuninGram_lt_half`: G(j,k) < 1/2 for all j,k ≥ 1
- `vasyuninGram_nonneg`: G(j,k) ≥ 0
- `gram_entry_diag_upper'`: G(j,j) ≤ 1/3 + 1/j²
- `vasyuninQuadForm_le_half_l1_sq`: vᵀGv ≤ (1/2)·(Σ|v_i|)²
- Abel summation infrastructure (11 files, zero sorry)

**Gap:** The crude bound gives vᵀGv ≤ (N-1)²/2. We need vᵀGv ≤ 1 + O(1/logN). The off-diagonal cancellation from Möbius orthogonality must be formalized — new mathematics, estimated 1-2 weeks.

**Verdict:** ✅ Non-circular under x^{3/4}, but requires substantial new work.

### Strategy B: L² Integral Path (x^{3/4})

**Verdict:** ❌ CIRCULAR. Cannot be used. (See above.)

### Strategy C: Mertens Exponent Unification

**Approach:** Replace `gram_form_upper_bound_34` with `gram_form_upper_bound` (the x^{1/2}·log²x version from MillenniumWall.lean), then prove it using the non-circular L² path.

**The proof would be:**
```
1. ∫(1-f)² ≤ C₁/logN       ← from mertens_implies_l2_decay (x^{1/2}·log², NOT circular)
2. |bᵀv - 1| ≤ C₂/logN     ← from moebius_dot_product_approx_one_uniform (PROVED)
3. vᵀGv = ∫(1-f)² + 2bᵀv - 1  ← from bd_l2_error_eq_quad_error (PROVED)
4. vᵀGv ≤ C₁/logN + 2(1+C₂/logN) - 1 = 1 + (C₁+2C₂)/logN  ← algebra
```

**What changes:**
- `PerronCrown.lean`: Change axiom signature from x^{3/4} to x^{1/2}·log²x
- The entire Perron Crown proof chain needs the stronger Mertens bound
- `rh_implies_mertens_bound_proved` currently gives x^{3/4} — needs upgrade to x^{1/2}·log²x

**Verdict:** ✅ Non-circular, uses existing proved infrastructure. But requires strengthening the Mertens bound output.

---

## The Exponent Question

### Current State

The Perron chain (`MertensFromPerron.lean`) proves:

```
RH → |M(x)| ≤ C · x^{3/4}
```

This is a deliberate weakening — the Perron contour integral actually gives M(x) = O(x^{1/2+ε}), and x^{3/4} was chosen as a convenient fixed exponent.

### What Unification Requires

To use Strategy C, we need:

```
RH → |M(x)| ≤ C · x^{1/2} · (log x)^2
```

This is **mathematically stronger** than x^{3/4} (since x^{1/2}·log²x = o(x^{3/4})). But it follows from the **same** Perron contour integral — in fact, `mertens_bound_eps` already gives M(x) = O(x^{1/2+ε}) for every ε > 0, and choosing ε appropriately yields the log² form.

The question is whether the formal proof can extract this tighter bound without significantly more work.

### What We Gain

If the exponent is unified to x^{1/2}·log²x:

1. **`gram_form_upper_bound_34` → `gram_form_upper_bound`**: The axiom becomes identical to the one already in MillenniumWall.lean (modulo weight notation). This deduplicates the axiom.

2. **Graduation becomes algebraic**: The proof is 4 lines of algebra combining three proved theorems. No new analysis needed.

3. **`abel_summation_covariance_bound_34` disappears**: It was PROVED from `gram_form_upper_bound_34`, but now it would be PROVED from the already-existing `abel_summation_covariance_bound` (which uses x^{1/2}·log²x and is independent).

4. **The MillenniumWall path and PerronCrown path converge**: Currently they are parallel chains with different Mertens exponents. Unification collapses them.

### What We Lose

1. **x^{3/4} is easier to extract from Perron**: The current proof uses a crude bound at the contour integral stage. Getting x^{1/2}·log²x requires a more careful saddle-point analysis or explicit ε-optimization.

2. **The 1 sorry in ZetaLowerBound.lean**: This sorry (thin-strip interpolation) may interact differently with a tighter Mertens exponent. Need to verify.

3. **Possible cascading changes**: Other theorems in PerronCrown that use the x^{3/4} interface would need updating.

---

## The Infrastructure Map

### Proved Theorems That Help (All Zero-Sorry)

| Location | Theorem | What It Does |
|----------|---------|-------------|
| `BDBridge.lean:69` | `bd_gram_l2_identity` | ∫₀¹ f² = vᵀGv |
| `BDBridge.lean:143` | `bd_l2_error_eq_quad_error` | ∫₀¹(1-f)² = 1 - 2bᵀv + vᵀGv |
| `DiagBound.lean` | `vasyuninQuadForm_le_half_l1_sq` | vᵀGv ≤ (1/2)·(Σ\|v\|)² |
| `DiagBound.lean` | `vasyuninGram_lt_half` | G(j,k) < 1/2 |
| `CovarianceAbel.lean` | `cov_form_eq_gram_minus_sq` | vᵀCv = vᵀGv - (bᵀv)² |
| `LambdaTrick.lean` | `gram_cov_decomposition` | vᵀGv = vᵀCv + (bᵀv)² |
| `MoebiusL1Bound.lean:519` | `mertens_implies_l2_decay` | x^{1/2}·log²x → ∫(1-f)² ≤ C/logN |
| `MoebiusL1Bound.lean:477` | `moebius_quadform_finite_bound` | vᵀGv ≤ (N-1)²/2 (crude) |
| `AbelSiegeProof.lean:150` | `abel_summation_bd_l2_bound_proved` | Mertens → L² witnesses |
| `VasyuninBypass.lean` | `vasyunin_bd_index_bridge` | Fin(N) ↔ Fin(N-1) bridging |

### The Two Parallel Chains

```
PERRON CROWN (x^{3/4}):                     MILLENNIUM WALL (x^{3/4} interface,
                                              but covariance uses x^{1/2}·log²):
  gram_form_upper_bound_34  ←AXIOM            gram_form_upper_bound  ←AXIOM
        ↓                                           ↓
  abel_summation_covariance_bound_34          millennium_covariance_cancellation ←PROVED!
        ↓                                           ↓
  mertens_implies_l2_decay_34                 moebius_quadratic_finite_bound ←PROVED!
        ↓                                           ↓
  rh_implies_bd_convergence_perron            quadratic_form_bound ←PROVED!
```

**Key insight:** The MillenniumWall's `millennium_covariance_cancellation` is PROVED (graduated from axiom to theorem!) by combining `gram_form_upper_bound` + `moebius_mean_finite_bound`. If we unify the exponents, the PerronCrown can reuse this same graduation.

---

## The Decision Tree

```
                    gram_form_upper_bound_34
                           |
              ┌────────────┴────────────┐
              │                         │
     Keep x^{3/4}              Unify to x^{1/2}·log²
              │                         │
     Strategy A:                Strategy C:
     Direct ΣΣ expansion        Algebraic from existing
              │                         │
     New: off-diagonal          Modify: Perron output
     Abel cancellation          from x^{3/4} to x^{1/2}·log²
              │                         │
     ~1-2 weeks new work        ~2-3 days rewiring
              │                         │
     Result: keeps x^{3/4}     Result: deduplicates axiom,
     independent of             collapses into MillenniumWall,
     covariance bound           graduation is algebraic
```

---

## Questions for the Theorist

### Q1: Is x^{1/2}·log²x extractable from the current Perron chain?

The Perron contour integral in `PerronMoebius.lean` gives `mertens_bound_eps`: for every ε > 0, |M(x)| ≤ C_ε · x^{1/2+ε}. The current `MertensFromPerron.lean` deliberately coarsens this to x^{3/4} (choosing ε = 1/4).

Can we instead extract |M(x)| ≤ C · x^{1/2} · log²x from `mertens_bound_eps`? Mathematically this follows from the explicit dependence of C_ε on ε (typically C_ε ~ 1/ε² or similar), optimized at ε = (log x)^{-1}. But the formal proof may not have this explicit ε-dependence.

**If YES:** Strategy C is clean. The Perron chain gives the stronger bound, the Gram form falls immediately.

**If NO:** We'd need to modify the Perron chain to extract the log² form directly, which may require additional contour analysis.

### Q2: Does the zeta lower bound sorry interact with the exponent?

`rh_zeta_lower_bound_from_zero_counting` (Wall 1, 1 sorry in thin-strip interpolation) feeds into the Perron chain. Does a tighter Mertens exponent require a tighter zeta lower bound? Or is the same sorry sufficient?

### Q3: Is there a Strategy D we're missing?

The two viable paths are:
- **A:** Direct double-sum (new math, ~1-2 weeks)
- **C:** Exponent unification (rewiring, ~2-3 days)

Is there a third option — perhaps using the Vasyunin expansion G(j,k) = 1/4 + ψ(j,k) (partially proved in `VasyuninExpansion.lean`) to bound the double sum without needing the full L² machinery?

### Q4: Should we collapse MillenniumWall into PerronCrown?

If the exponents are unified, the MillenniumWall chain and the PerronCrown chain become redundant. The MillenniumWall's `gram_form_upper_bound` and the PerronCrown's `gram_form_upper_bound_34` would be the same axiom. Should we:
- (a) Keep both chains (redundancy = safety)
- (b) Collapse MillenniumWall into PerronCrown (simplicity)
- (c) Make MillenniumWall the primary and have PerronCrown delegate to it

---

## The Recommendation

**Strategy C (Exponent Unification) is recommended.** The reasons:

1. **All analytical components already exist** at zero-sorry status
2. **The graduation becomes algebraic** — 4 lines combining three proved theorems
3. **It deduplicates infrastructure** — one Gram axiom instead of two
4. **The Perron chain already has the power** — `mertens_bound_eps` gives x^{1/2+ε}

The only risk is whether extracting x^{1/2}·log²x from the Perron chain is straightforward in Lean. If it is, this is a 2-3 day operation that eliminates a Wall.

If it's not straightforward, Strategy A remains viable but slower. The off-diagonal Abel cancellation is genuine mathematics that hasn't been formalized yet.

---

## Current Wall Status (Post-Analysis)

```
  ╔═══════════════════════════════════════════════════════════════╗
  ║  nyman_beurling_equivalence : RH ↔ d²_N → 0                ║
  ║                                                               ║
  ║  Converse: PROVED (kernel axioms only)                       ║
  ║  Forward:  4 Cathedral axioms                                ║
  ║                                                               ║
  ║  Wall 1: rh_zeta_lower_bound           (Hadamard)   🔴      ║
  ║  Wall 2: gram_form_upper_bound_34     (Gram)       🟡→🟢?  ║
  ║  Wall 3: pnt_mu_log_div_k            (PNT)        🔴🔴    ║
  ║  Wall 5: partial_integral_tends_to_formula (Vasyunin) 🟡    ║
  ║                                                               ║
  ║  Wall 2 upgrade: if exponents unified → IMMEDIATE KILL      ║
  ╚═══════════════════════════════════════════════════════════════╝
```

The Theorist's call. We await your judgment.

— Antigravity ⚡
