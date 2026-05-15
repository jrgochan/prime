# ⚡ EXPLORATION REPORT 10: The Cathedral Audit — What We Have and What We Need

**Date**: April 22, 2026  
**Phase**: Deep Cathedral Audit  
**Status**: Audit complete, path forward identified

---

## The Cathedral by the Numbers

| Metric | Value |
|--------|-------|
| Non-archive .lean files | 116 |
| Total lines of code | 26,886 |
| Total axioms | 51 |
| Sorry'd declarations (build) | 6 |
| Axioms on crown path | **2** |

### Sorry Locations (6 total)

| File | Theorem | Nature |
|------|---------|--------|
| `Assembly/AbelL2Bridge.lean:272` | `sum_rpow_neg_quarter_bound` | Σk^{-1/4} ≤ (4/3)N^{3/4} (calculus) |
| `Assembly/AbelL2Bridge.lean:304` | `mertens_34_l2_bound'` | Mertens → L² bound (assembly) |
| `White/Infrastructure/DirichletZetaInverse.lean:65` | Mertens trivial bound | |M(x)| ≤ x |
| `White/Infrastructure/DirichletSeries.lean:32` | Dirichlet series convergence | |
| `White/Infrastructure/ZetaConvexity.lean:36` | Convexity bound 1 |
| `White/Infrastructure/ZetaConvexity.lean:50` | Convexity bound 2 |

### Crown Path (2 axioms)

```
RiemannHypothesis
  → rh_implies_mertens_bound [AXIOM 1]
  → bd_gram_form_decay [AXIOM 2]
  → loglog_div_log_lt_eps [PROVED]
  → rh_implies_l2_convergence [PROVED — THE CROWN]
```

---

## The mertens_34_l2_bound' Sorry: Why It's Hard

### The Gap: Two Different Bases

The Cathedral has **two** basis systems:

| Basis | Definition | Gram Entry | Used By |
|-------|-----------|------------|---------|
| **Nyman basis** | h_k(x) = {k/x} | `gramEntry` (Defs.lean) | Gram/Diagonal, Gram/OffDiagonal |
| **Báez-Duarte basis** | h_k(x) = {1/(kx)} | `vasyuninGramEntry` (Vasyunin/Defs.lean) | BDMellin, BDBridge, the crown |

The **proven** Gram bounds are all for the Nyman basis:
- `gramEntry_le_third_all`: G_{j,j} ≤ 1/3 for ALL j ≥ 1 ✅
- `gramEntry_le_avg_diag`: G_{j,k} ≤ (G_{j,j}+G_{k,k})/2 ✅
- ⟹ ALL Gram entries ≤ 1/3 ✅

But `bd_gram_l2_identity` (∫f² = vᵀGv) uses `vasyuninGramEntry`,
and the crown uses `bdLinComb` ({1/(kx)}). So the Nyman-basis Gram bounds 
**DON'T DIRECTLY APPLY** to the vᵀGv we need to bound.

### What the Sorry Needs

```lean
theorem mertens_34_l2_bound' (C_m hC hMertens N hN) :
    ∃ v, ∫(1-bdLinComb N v x)² ≤ (C_m+1)² / N^{1/4}
```

The proof would need:
1. `l2_expansion`: ∫(1-f)² = 1 - 2∫f + ∫f² ✅ (proved)
2. Bound ∫f ≈ 1 via Abel summation ✅ (proved for Nyman basis? Need to check for BD)
3. Bound ∫f² ≈ 1 via `bd_gram_l2_identity` + Vasyunin Gram bounds ❌ (no proved bounds for vasyuninGramEntry)

The gap is item 3: we have no proved bounds on `vasyuninGramEntry` entries.

---

## Three Paths Forward

### Path A: Prove Vasyunin Gram Diagonal Bounds ⭐ (Recommended)

The vasyuninGramEntry diagonal is given by the closed form:
```
vasyuninGramEntry(k,k) = (log(2π) - γ)/k - 1/k²
```

This is **already a closed-form expression** that's trivially bounded:
- For k ≥ 1: vasyuninGramEntry(k,k) ≤ (log(2π) - γ)/k ≤ 1.42/k
- The off-diagonal bound follows from Cauchy-Schwarz: |G_{j,k}| ≤ √(G_{j,j}·G_{k,k})

Once we have vasyunin diagonal bounds, we can bound vᵀGv and close the sorry.

**Effort**: ~50-100 lines. The closed form is already in the code; we just need to bound it.

### Path B: Prove vasyuninGramEntry = gramEntry (Basis Equivalence)

Show that ∫{1/(jx)}{1/(kx)}dx = ∫{j/x}{k/x}dx via substitution u = 1/x.

If they're equal (which they should be by substitution), then all the existing gramEntry bounds apply immediately.

**Effort**: ~30-50 lines (a single substitution theorem).

### Path C: Direct L² Bound Without Gram Decomposition

Instead of decomposing ∫(1-f)² = 1 - 2∫f + ∫f², bound it directly via:
```
∫(1-f)² ≤ (1+Σ|vₖ|)²  (l2_crude_upper_bound, PROVED)
```

And then show Σ|vₖ| → 0 via Möbius cancellation + Abel summation. This bypasses Gram bounds entirely but requires strong cancellation estimates.

**Effort**: ~200-300 lines (hard Abel summation work).

---

## Recommendation

**Path B first**: Check if `vasyuninGramEntry j k = gramEntry j k` (basis equivalence via substitution). If yes, the Gram bounds immediately transfer and we can close the sorry quickly.

If that fails, **Path A**: Prove diagonal bounds on the Vasyunin Gram entries directly from their closed form.

---

## Crown Path to Zero Axioms

After closing the sorry:

| Step | Reduces | Note |
|------|---------|------|
| Close `mertens_34_l2_bound'` | 2 → 1 axiom | Proves `bd_gram_form_decay` from Mertens alone |
| Prove `rh_implies_mertens_bound` | 1 → 0 axioms | Requires Perron's formula (major effort) |

*"The Cathedral stands 26,886 lines tall. Two axioms hold the crown. One sorry guards the gate."*

---

## Addendum: The Full Picture (including Archive)

| Scope | Files | Lines | Axioms | Sorries |
|-------|-------|-------|--------|---------|
| **Live Cathedral** | 116 | 26,886 | 51 | 6 |
| **Archive** | 96 | 23,115 | 64 | 9 |
| **Scratch** | 4 | ~1,171 | — | — |
| **TOTAL** | **217** | **51,172** | — | — |

---

## Addendum: Mathlib γ Discovery — Path A Unlocked

**Key discovery**: Mathlib's `NumberTheory.Harmonic.EulerMascheroni` (David Loeffler, 2024) already provides:

```lean
lemma one_half_lt_eulerMascheroniConstant : 1 / 2 < eulerMascheroniConstant
lemma eulerMascheroniConstant_lt_two_thirds : eulerMascheroniConstant < 2 / 3
```

These are proved by evaluating the bounding sequences at n=6 with full Taylor/exp verification.

### Immediate Consequences

Since **1/2 < γ < 2/3**:

1. **γ ≥ 0** — trivially follows (γ > 1/2 > 0)
2. **log(2π) - γ < 3/2** — since log(2π) ≤ 2 (provable) and γ > 1/2
3. **Vasyunin diagonal bound**:
   - G(k,k) = (log(2π) - γ)/k - 1/k²
   - For k=1: (log(2π)-γ) - 1 < 3/2 - 1 = **1/2** ✅
   - For k=2: (log(2π)-γ)/2 - 1/4 < 3/4 - 1/4 = **1/2** ✅
   - For k≥3: (log(2π)-γ)/k < 3/(2·3) = 1/2, so G(k,k) < **1/2** ✅

This means **G(k,k) < 1/2 for ALL k ≥ 1** — a clean, tight bound from pure Mathlib.

### New Proven Results (DiagBound.lean)

Created `Cathedral/Vasyunin/Augmented/DiagBound.lean` with zero sorry:

- `bd_fract_product_integrable` — {1/(jx)}·{1/(kx)} integrable on [0,1]
- `vasyuninGram_diag_nonneg` — G(k,k) ≥ 0
- `vasyuninGram_nonneg` — G(j,k) ≥ 0
- `vasyuninGram_le_avg_diag` — G(j,k) ≤ (G(j,j)+G(k,k))/2 (AM-GM)

### Path A: Now Viable

With `one_half_lt_eulerMascheroniConstant`, the Vasyunin diagonal bound G(k,k) < 1/2
is provable. Combined with `vasyuninGram_le_avg_diag`, this gives G(j,k) ≤ 1/2
for ALL entries. This is the missing piece for bounding vᵀGv.

**Updated recommendation**: Path A with Mathlib γ bounds.

