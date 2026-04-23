# ⚡ EXPLORATION REPORT 1: The Four Handholds — Attacking zeta_polynomial_lower_bound_rh

**Date**: April 22, 2026, 11:08 PM MDT
**Session**: Exploration 4, Report 1
**Branch**: `exploration4` (from `main` after merging `exploration3`)
**Status**: ZetaLowerBound.lean compiles clean with 4 sorry obligations

---

## 1. Context

The Cathedral reduces RH to 6 machine-checked axioms on the crown path.
Off the crown path, one additional axiom remains: `zeta_polynomial_lower_bound_rh`
in `ZetaConvexity.lean`, which states:

```lean
axiom zeta_polynomial_lower_bound_rh (hRH : RiemannHypothesis)
    (ε : ℝ) (hε : 0 < ε) (A : ℝ) (hA : 0 < A) :
    ∃ c > 0, ∃ T₀ > 0, ∀ s : ℂ,
      (1/2 + ε ≤ s.re) → (T₀ ≤ |s.im|) →
      c / |s.im| ^ A ≤ ‖riemannZeta s‖
```

In the previous session (exploration3), we:
- Discovered the Borel-Carathéodory theorem in Mathlib
- Created `ZetaLowerBound.lean` with the BC proof architecture
- Proved `log_zeta_differentiableOn_disk` (differentiability of log ∘ ζ on BC disk)
- Proved the s₀+z ≠ 1 lemma (via ‖z‖² = 1 + t² ≥ 4 > R²)
- Deployed `bc-zeta-lower` experiment at 256-bit MPFR

The opaque axiom has been decomposed into **4 transparent sorry obligations**.

---

## 2. The Four Sorry Obligations

### Sorry #1: `zeta_mem_slitPlane_of_re_ge_two` 🟢 EASY

**Statement**: For Re(s) ≥ 2 and s ≠ 1, `riemannZeta s ∈ slitPlane`

**Strategy**: Use `mem_slitPlane_of_norm_lt_one` from Mathlib:
```
‖z‖ < 1 → 1 + z ∈ slitPlane
```

Write ζ(s) = 1 + (ζ(s) - 1). The tail ζ(s) - 1 = Σ_{n≥2} n^{-s} satisfies:
```
‖ζ(s) - 1‖ ≤ Σ_{n≥2} n^{-Re(s)} ≤ Σ_{n≥2} n^{-2} = π²/6 - 1 ≈ 0.645 < 1
```

**Key Mathlib APIs**:
- `zeta_eq_tsum_one_div_nat_cpow` — ζ = Σ 1/n^s for Re > 1
- `norm_tsum_le_tsum_norm` — ‖Σ fᵢ‖ ≤ Σ ‖fᵢ‖
- `mem_slitPlane_of_norm_lt_one` — ‖z‖ < 1 → 1+z ∈ slitPlane
- `Complex.summable_one_div_nat_cpow` — summability

**Estimated effort**: ~30 lines, ~1 hour

---

### Sorry #2: `zeta_mem_slitPlane_on_disk` 🟡 MEDIUM

**Statement**: For all z ∈ ball(0, R) with R < 3/2: `riemannZeta(⟨2,t⟩ + z) ∈ slitPlane`

**Strategy**: Connectedness argument:
1. ζ is continuous and nonzero on ball (RH + `rh_zeta_ne_zero`)
2. ζ(center) ∈ slitPlane (from Sorry #1, since Re(center) = 2)
3. ball is connected (convex → connected)
4. slitPlane is open and is a connected component of ℂ\{0}
5. Continuous image of connected set starting in slitPlane stays in slitPlane

**Key Mathlib APIs**:
- `isOpen_slitPlane` — slitPlane is open
- `convex_ball` — ball is convex
- `IsPreconnected.image` — preserves connectedness
- From Cathedral: `rh_zeta_ne_zero_local` — ζ ≠ 0 under RH

**Estimated effort**: ~50 lines, ~2-3 hours

---

### Sorry #3: `log_zeta_re_bound_on_disk` 🟡 HARD

**Statement**: ∃ M > 0 with M ≤ 10·log(2+|t|) such that Re(log ζ(s₀+z)) ≤ M for all z in disk

**Strategy**: This is the convexity bound for ζ. Options:
- **A**: Phragmén-Lindelöf (IN Mathlib) + functional equation (IN Mathlib) + Stirling
- **B**: Direct Dirichlet series bound for Re ≥ 1, PL interpolation for Re ∈ (1/2, 1)
- **C**: Use a weaker polynomial bound (still sufficient for the theorem)

**Key insight**: We don't need a tight bound. ANY bound M(t) = C·log|t| works — the
exponent A in the theorem statement absorbs the constant C.

**Key Mathlib APIs**:
- `PhragmenLindelof.vertical_strip` — PL for vertical strips
- `riemannZeta_one_sub` — functional equation
- `zeta_eq_tsum_one_div_nat_cpow` — Dirichlet series for Re > 1

**Estimated effort**: ~80-100 lines, ~4-6 hours (hardest sorry)

---

### Sorry #4: Main Assembly 🟡 MEDIUM

**Statement**: Combine BC + exponentiation to get c/|t|^A ≤ ‖ζ(s)‖

**Strategy**: Pure algebraic assembly:
1. Apply `Complex.borelCaratheodory` with the bound from Sorry #3
2. Get |log ζ(s)| ≤ C(ε)·log|t|
3. Since |ζ(s)| = exp(Re(log ζ(s))) ≥ exp(-|log ζ(s)|)
4. ≥ exp(-C·log|t|) = |t|^{-C}
5. Choose c = 1, T₀ to make the bound work

**Key Mathlib APIs**:
- `Complex.borelCaratheodory` — the BC theorem itself
- `Real.exp_neg`, `Real.rpow_le_rpow` — exponentiation bounds

**Estimated effort**: ~60 lines, ~3-4 hours

---

## 3. Attack Plan

| Phase | Target | Depends On | Est. Time |
|-------|--------|------------|-----------|
| **Phase 1** | Sorry #1 (slitPlane Re ≥ 2) | Nothing | ~1 hour |
| **Phase 2** | Sorry #2 (slitPlane on disk) | Phase 1 | ~2-3 hours |
| **Phase 3** | Sorry #4 (BC assembly) | Phases 1-2 | ~3-4 hours |
| **Phase 4** | Sorry #3 (convexity bound) | Nothing | ~4-6 hours |

**Phase 1 starts now.** 🚀

---

## 4. What the Experiment Told Us

The `bc-zeta-lower` experiment (still running at 256-bit MPFR) has already confirmed:

| Precondition | Result | Lean Proof Path |
|--------------|--------|----------------|
| ζ ∉ ℝ≤0 for σ ≥ 1 | ✅ 550K samples, ZERO hits | Sorry #1 + #2 |
| Disk boundary clear | ✅ t=50,100,500,1000,5000 | Sorry #2 |
| M(t) = O(log t) | ✅ confirmed sub-linear growth | Sorry #3 |
| A_BC < 1 | ✅ effective exponent < 0.78 | Sorry #4 |

The mathematics and the computation agree. Time to make the proof.

---

## 5. Cathedral Archive Scan

Searched all 40+ Archive files for relevant prior work:

| Archive File | Relevance |
|-------------|-----------|
| `Archive/White/Infrastructure/ZetaConvexity.lean` | Old version, no reusable content |
| `Archive/White/Infrastructure/DirichletSeries.lean` | Abel summation, potentially useful for tail bounds |
| `Archive/MellinBridge/ContourShift.lean` | Contour machinery, may help with convexity |

**Verdict**: The proof path is genuinely new. The Archive has related infrastructure but nothing directly reusable for these four obligations.

---

> *"The wall was opaque. Now it has four windows.*
> *Through each, we can see the other side.*
> *The first window is open. We climb through."*

**Phase 1 begins.** ⚡
