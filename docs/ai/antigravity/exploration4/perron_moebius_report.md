# PerronMoebius Proof Chain — Handoff Report for Theorist

**Date**: 2026-04-23  
**Branch**: `exploration4`  
**Build Status**: ✅ `lake build Cathedral.Assembly.MertensFromPerron` — 3479 jobs, zero errors  
**File**: `proofs/Cathedral/White/Infrastructure/Perron/PerronMoebius.lean` (512 lines)

---

## 1. Goal

Formalize in Lean 4 (Mathlib) the classical Mertens function bound:

> **Theorem** (RH ⟹ Mertens bound): Assuming the Riemann Hypothesis,  
> for every ε > 0 there exists C > 0 such that |M(x)| ≤ C · x^{1/2 + ε} for all x ≥ 2.

Where M(x) = ∑_{n ≤ x} μ(n) is the summatory Möbius function.

The proof route is Perron's formula + contour shifting under RH:

```
M(x) ≈ (1/2πi) ∫_{Re=c} x^s / (s·ζ(s)) ds       [Perron formula]
     = (1/2πi) ∫_{Re=σ₀} x^s / (s·ζ(s)) ds + o(1)  [contour shift to σ₀ = 1/2+ε]
     ≤ C · x^{σ₀}                                    [ζ(s) ≠ 0 for Re > 1/2 under RH]
     = C · x^{1/2+ε}
```

---

## 2. What's Proved (Zero Sorry)

### Fully Proved Lemmas (11 lemmas)

| # | Lemma | Lines | What it does |
|---|-------|-------|-------------|
| 1 | `perron_moebius_integrand_diffAt` | 54-69 | DifferentiableAt for x^s/(s·ζ(s)) at s ≠ 1 with Re(s) > 1/2 under RH |
| 2 | `conj_sigma_sub_ti` | 158-163 | σ + (-T)i = conj(σ + Ti) for real σ, T |
| 3 | `arg_natCast'` | 165-169 | arg(n : ℂ) = 0 for n : ℕ |
| 4 | `conj_natCast_cpow` | 171-179 | conj(n^s) = n^(conj s) for n : ℕ |
| 5 | `conj_lseries_term` | 181-190 | conj(f(n)/n^s) = f(n)/(n^(conj s)) for 1-valued arith functions |
| 6 | `riemannZeta_conj_re_gt` | 192-208 | ζ(conj s) = conj(ζ(s)) for Re(s) > 1 (via L-series) |
| 7 | `perron_horiz_neg_eq_pos` | 223-240 | ‖horiz at -T‖ = ‖horiz at T‖ (modulo riemannZeta_conj sorry) |
| 8 | `perron_moebius_contour_shift` | 251-289 | **MAIN**: Contour shift ‖∫_{Re=c} - ∫_{Re=σ₀}‖ → 0 (zero new sorry!) |
| 9 | `perron_integrand_intervalIntegrable` | 297-313 | y^(c+tI)/(c+tI) is IntervalIntegrable on [-T,T] |
| 10 | `finite_sum_integral_swap` | 315-367 | ∑ a(n)·P(x/n) = (1/2π)∫ ∑ a(n)(x/n)^s/s dt |
| 11 | `sum_range_eq_sum_Icc` | 370-379 | Finset reindexing: ∑_{range N} f(i+1) = ∑_{Icc 1 N} f(i) |
| 12 | `partial_sum_minus_lseries` | 381-395 | Tail extraction: ∑_{Icc 1 N} - LSeries = -(tail from N+1) |
| 13 | `mertens_bound_eps_implies_original` | 500-512 | eps-form ⟹ original statement (format conversion) |

### Proved Assemblies (leveraging sub-lemmas)

| Assembly | What it proves | Sub-lemma sorry it inherits |
|----------|---------------|---------------------------|
| `perron_moebius_rect` | Rectangle identity via CG | integrand_continuousOn, IntervalIntegrable ×2 |
| `perron_moebius_contour_shift` | Contour integral difference → 0 | riemannZeta_conj |
| `moebius_partial_sum_approx` (partial) | Steps 1-3 of tail bound | rpow_tail_bound |

---

## 3. Remaining Sorry (5 Independent, 8 Tokens)

### Sorry #1: `integrand_continuousOn` (Line 48)

```lean
private lemma perron_moebius_integrand_continuousOn (_hRH : RiemannHypothesis)
    (x sigma0 c T : ℝ) (hx : 1 < x) (hsigma0 : 1/2 < sigma0)
    (hc : 1 < c) (hsigma0_c : sigma0 < c) (hT : 0 < T) :
    ContinuousOn (fun s => (x : ℂ) ^ s / (s * riemannZeta s))
      (Set.uIcc sigma0 c ×ℂ Set.uIcc (-T) T) := by
  sorry
```

**Mathematical content**: The integrand x^s/(s·ζ(s)) must be continuous on the closed rectangle [σ₀, c] × [-T, T].

**Why it's hard**: 
- On `{1}ᶜ`: ζ is analytic (`analyticOn_riemannZeta`), so f is continuous away from s=1. ✅
- **At s = 1**: ζ has a simple pole, so 1/(s·ζ(s)) → 0 as s→1 (removable singularity). But Lean's `riemannZeta 1` is defined as a finite value (not ∞), so `f(1)` is a finite nonzero number. The issue is proving `lim_{s→1} f(s) = f(1)`, which requires knowing the specific value of `riemannZeta 1` in Lean's definition.
- If σ₀ > 1 (instead of > 1/2), then s=1 is outside the rectangle and this sorry vanishes. But the RH application needs σ₀ = 1/2 + ε.

**Corollaries**: 2 `IntervalIntegrable` sorry at lines 137-138 (follow from this).

**Required by**: `perron_moebius_rect` (Cauchy-Goursat application).

**Question for Theorist**: 
1. Can we restructure to avoid ContinuousOn at s=1? E.g., split the rectangle into sub-rectangles avoiding s=1?
2. Is there a way to use `differentiableAt_riemannZeta` + some removable singularity theorem to get ContinuousOn?
3. Does Lean's `hurwitzZetaEven 0` (= `riemannZeta`) have continuity properties we can leverage?

---

### Sorry #2: `riemannZeta_conj` (Line 216)

```lean
private lemma riemannZeta_conj (s : ℂ) :
    riemannZeta (starRingEnd ℂ s) = starRingEnd ℂ (riemannZeta s) := by
  sorry
```

**Mathematical content**: Schwarz reflection for ζ: ζ(s̄) = ζ(s)̄ for all s.

**What we have**: 
- **PROVED** for Re(s) > 1 as `riemannZeta_conj_re_gt` via L-series conjugation
- For general s: needs analytic continuation

**Why it's hard**:
- `conj : ℂ → ℂ` is NOT ℂ-analytic (it's anti-holomorphic), so the Identity Theorem for analytic functions doesn't directly apply
- The composition `s ↦ conj(ζ(conj s))` IS ℂ-analytic, so one could try: show `ζ(s)` and `conj(ζ(conj s))` are both analytic on `{1}ᶜ`, agree on `{Re > 1}`, and apply the Identity Theorem. BUT: `{1}ᶜ` in ℂ needs to be shown preconnected (complement of a point is connected in ℂ)
- Alternative: use `completedRiemannZeta₀` (which is entire) and show it has real Taylor coefficients

**Mathlib tools available**:
- `AnalyticOnNhd.eqOn_of_preconnected_of_eventuallyEq` — the Identity Theorem (requires ℂ-analyticity of both sides)
- `analyticOn_riemannZeta : AnalyticOnNhd ℂ riemannZeta {1}ᶜ`
- `completedRiemannZeta₀_one_sub` — functional equation
- `differentiable_completedZeta₀` — ξ₀ is entire

**Used by**: Only `perron_horiz_neg_eq_pos` (equating ‖horiz at T‖ = ‖horiz at -T‖).

**Bypass option**: Restructure `perron_moebius_contour_shift` to bound the two horizontal integrals independently instead of equating them. Both vanish by `perron_horizontal_contour_vanishes`.

**Question for Theorist**:
1. Can we prove `AnalyticOnNhd ℂ (fun s => conj (riemannZeta (conj s))) {1}ᶜ`? The composition of conj ∘ f ∘ conj preserves ℂ-analyticity (two orientation reversals cancel). Is this in Mathlib?
2. Is `IsPreconnected ({1}ᶜ : Set ℂ)` provable? (The complement of a point in ℂ ≅ ℝ² should be path-connected.)
3. Would the functional equation approach be simpler? Using `completedRiemannZeta₀_one_sub` + Gamma function conjugation?

---

### Sorry #3: `rpow_tail_bound` (embedded in `moebius_partial_sum_approx`, Line 420)

```lean
-- The tail bound reduces to this after decomposition:
-- ∑' (n : ℕ), (1 : ℝ) / ((n : ℝ) + ↑N + 1) ^ σ ≤ (↑N : ℝ) ^ (1 - σ) / (σ - 1)
-- for σ > 1
```

**Mathematical content**: The integral test: ∑_{n > N} 1/n^σ ≤ ∫_N^∞ x^{-σ} dx = N^{1-σ}/(σ-1).

**Mathlib tools we've identified**:
- `AntitoneOn.sum_le_integral` from `Mathlib.Analysis.SumIntegralComparisons`:
  ```
  For antitone f on [x₀, x₀+a]: ∑_{i<a} f(x₀+i+1) ≤ ∫_{x₀}^{x₀+a} f(x)
  ```
- `integral_Ioi_rpow_of_lt` from `Mathlib.Analysis.SpecialFunctions.ImproperIntegrals`:
  ```
  For a < -1 and c > 0: ∫_{Ioi c} t^a = -c^{a+1}/(a+1)
  ```
- Sign simplification: `-N^{-σ+1}/(-σ+1) = N^{1-σ}/(σ-1)` via `neg_div_neg_eq` ✅ verified

**Why it's still hard**: 
- `AntitoneOn.sum_le_integral` gives a FINITE sum bound: `∑_{n<K} f(N+n+1) ≤ ∫_N^{N+K} f(x)`
- We need to take K→∞ on both sides to get `tsum ≤ ∫_N^∞`
- This limiting step requires: monotone convergence for the LHS (tsum = limit of partial sums) and interval integral → Ioi integral for the RHS
- The bookkeeping for this limit passage is the main challenge

**Used by**: `moebius_partial_sum_approx` → `truncated_perron_for_moebius` → `mertens_bound_eps`

**This is the critical path sorry** — closing it cascades through the entire assembly chain.

**Question for Theorist**:
1. Is there a more direct bound on `tsum` that avoids the K→∞ limit passage? E.g., a "tsum_le_integral" lemma in Mathlib?
2. Can we use `Real.summable_one_div_nat_rpow` (summability for p > 1) together with some remainder estimate?
3. Would a geometric comparison `1/n^σ ≤ (N/n)^σ · 1/N^σ` be simpler to formalize?

---

### Sorry #4: `truncated_perron_for_moebius` (Line 464)

```lean
theorem truncated_perron_for_moebius (x c : ℝ) (hx : 2 ≤ x) (hc : 1 < c) :
    ∃ K > 0, ∀ T : ℝ, 1 ≤ T →
      |(↑(summatoryMoebius x : ℤ) : ℝ)| ≤
        (1 / (2 * Real.pi)) *
          ∫ t in (-T)..T,
            ‖(x : ℂ) ^ (↑c + ↑t * I) /
              ((↑c + ↑t * I) * riemannZeta (↑c + ↑t * I))‖ +
        K * x ^ c / T := by
  sorry
```

**Mathematical content**: Assembly of Perron formula + Möbius inversion.

**Sub-components available**:
- `perron_formula_error_bound` — error term K·x^c/T ✅ PROVED
- `finite_sum_integral_swap` — sum-integral swap ✅ PROVED  
- `moebius_partial_sum_approx` — partial sum ≈ 1/ζ(s) (blocked by #3)

**Blocked by**: Sorry #3 (rpow_tail_bound)

---

### Sorry #5: `mertens_bound_eps` (Line 492)

```lean
theorem mertens_bound_eps (hRH : RiemannHypothesis) (eps : ℝ) (heps : 0 < eps) :
    ∃ C : ℝ, C > 0 ∧ ∀ x : ℝ, x ≥ 2 →
      |((summatoryMoebius x : ℤ) : ℝ)| ≤ C * x ^ ((1 : ℝ)/2 + eps) := by
  sorry
```

**Mathematical content**: Final assembly combining contour shift + truncated Perron + Lindelöf bound.

**Sub-components available**:
- `perron_moebius_contour_shift` ✅ PROVED (assembly)
- `truncated_perron_for_moebius` — blocked by #4
- `inv_zeta_bound_under_rh` ✅ PROVED

**Blocked by**: Sorry #4

---

## 4. Dependency Graph

```
#1 ContinuousOn ──→ rect integrability ×2 ──→ perron_moebius_rect
                                                      │
#2 Schwarz refl ──→ horiz_neg_eq_pos ──────→ perron_moebius_contour_shift ✅
                                                      │
#3 rpow_tail ──→ partial_sum_approx ──→ #4 truncated_perron ──→ #5 mertens_bound_eps
```

**Critical path**: #3 → #4 → #5 (closing rpow_tail_bound cascades to the final theorem)

**Isolated sorry**: #1 (ContinuousOn) and #2 (Schwarz) are structurally independent — needed for the proof but don't block other sorry from being addressed.

---

## 5. Key Techniques Already Used

1. **Off-countable Cauchy-Goursat** (`integral_boundary_rect_eq_zero_of_differentiable_on_off_countable`): Allows a countable exceptional set {1} where differentiability fails. This completely avoids removable singularity arguments at the ζ pole.

2. **Complex algebra via `ring_nf` + `eq_neg_of_add_eq_zero_right`**: Replaced `linarith` (which doesn't work on ℂ) for rearranging the CG identity A - B + IC - ID = 0.

3. **Sum-integral swap via `integral_finset_sum`**: For finite sums, the swap of ∑ and ∫ is automatic (no Fubini needed).

4. **Tail extraction via `Summable.sum_add_tsum_nat_add`**: Splits `∑' n, f(n) = ∑_{n<N} f(n) + ∑' n, f(n+N)`.

5. **L-series machinery**: `moebius_lseries_eq_inv_zeta`, `moebius_lseries_summable`, `LSeries.term` — all from `DirichletZetaInverse.lean`.

---

## 6. Specific Questions for the Theorist

### High Priority (blocking the critical path)

**Q1 (rpow_tail_bound)**: What's the cleanest way to prove the integral test in Lean 4?
- We have `AntitoneOn.sum_le_integral` for finite sums and `integral_Ioi_rpow_of_lt` for the improper integral
- The gap is the K→∞ limit passage: `∑_{n<K} f(n) ≤ ∫_0^K f(x)` → `tsum f ≤ ∫_0^∞ f(x)`
- Is there a monotone convergence theorem for this? Or a direct `tsum_le_integral_Ioi` somewhere?

**Q2 (truncated_perron assembly)**: Once rpow_tail_bound is closed, the assembly theorem combines:
- Perron formula error bound (PROVED)
- Sum-integral swap (PROVED) 
- Partial sum approximation (would be PROVED)
- What's the cleanest way to handle the measure theory bookkeeping for replacing ∑ μ(n)/n^s with 1/ζ(s) inside the integral?

### Medium Priority (structural)

**Q3 (riemannZeta_conj)**: Is there a proof strategy that avoids both:
- The Schwarz reflection principle (not in Mathlib)
- The Identity Theorem (requires ℂ-analyticity, but conj is anti-holomorphic)

Specifically: can we show `AnalyticOnNhd ℂ (fun s => starRingEnd ℂ (riemannZeta (starRingEnd ℂ s))) {1}ᶜ` and then apply the Identity Theorem with `riemannZeta`?

**Q4 (ContinuousOn at s=1)**: The Cauchy-Goursat theorem needs ContinuousOn on the closed rectangle. If s=1 is in the interior (when σ₀ < 1 < c), we need continuity at s=1. Can this be approached via:
- The Laurent expansion of ζ at s=1? (ζ(s) = 1/(s-1) + γ + O(s-1), so x^s/(s·ζ(s)) → x/(γ + ...) ?)
- A removable singularity theorem? (Riemann's removable singularity for bounded analytic functions)
- Defining a modified function that equals f away from 1 and is defined to be the limit at 1?

### Low Priority (nice to have)

**Q5 (bypass Schwarz)**: If riemannZeta_conj is too hard, the contour shift could be restructured to bound:
```
‖∫ horiz_top‖ + ‖∫ horiz_bot‖ ≤ 2 · ‖∫ horiz_top‖
```
by showing `‖∫ horiz_bot‖ ≤ ‖∫ horiz_top‖` directly (or just bounding each independently). The current proof uses equality; a ≤ bound would suffice. Is this easier to prove?

**Q6 (alternative proof path)**: Is there a way to get M(x) = O(x^{1/2+ε}) that avoids the Perron formula entirely? E.g., via the explicit formula for ψ(x) and Möbius inversion? The spectral approach (Cathedral/White/Infrastructure/SpectralRH/) has different machinery.

---

## 7. Files to Share

### Essential (the proof chain)
1. `proofs/Cathedral/White/Infrastructure/Perron/PerronMoebius.lean` — **THE main file** (512 lines)
2. `proofs/Cathedral/White/Infrastructure/DirichletZetaInverse.lean` — L-series = 1/ζ (103 lines)
3. `proofs/Cathedral/White/Infrastructure/Perron/Formula.lean` — Perron formula imports (61 lines)

### For context (proved dependencies)
4. `proofs/Cathedral/White/Infrastructure/ZetaConvexity.lean` — horizontal contour vanishing (344 lines)
5. `proofs/Cathedral/Assembly/MertensFromPerron.lean` — top-level theorem assembly (135 lines)

### Archive references (read-only templates)
6. `proofs/Cathedral/Archive/HighFrequencyTrap/MellinBridge/FloorMellin.lean` — Abel summation patterns (343 lines)
7. `proofs/Cathedral/Archive/HighFrequencyTrap/MellinBridge/AbelSummation.lean` — Discrete summation-by-parts (140 lines)

---

## 8. Lean/Mathlib Version

```
-- From lakefile.lean:
-- Lean 4 with Mathlib (current HEAD)
-- Key Mathlib imports: MeasureTheory, Analysis.Complex, NumberTheory.LSeries
```

The proof builds with `lake build` on branch `exploration4`.
