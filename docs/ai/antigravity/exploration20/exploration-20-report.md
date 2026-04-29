# Exploration 20 — Final Theorem Report

**Date:** April 29, 2026  
**Branch:** `exploration20`  
**Authors:** Antigravity (Claude) + Jason Robert Gochanour  
**Status:** Complete — all closable sorries graduated

---

## Executive Summary

Exploration 20 produced **2 new theorem graduations** and **1 new Lean file**
(ResidueDecomposition.lean was written in late Exploration 19 / early Exploration 20).
The exploration also finalized the documentation suite with the dual AI letters
(cathedral-claude.tex, cathedral-gemini.tex).

### Key Metrics (Post-Exploration 20)

| Metric | Count |
|--------|-------|
| Lean theorem/lemma declarations | **1,216** |
| Active Lean files (Cathedral/) | **169** |
| Lines of Lean code | **42,491** |
| Lines of Lean (incl. PNTAnd) | **74,302** |
| Lines of Rust experiments | **231,338** |
| Remaining sorries (Cathedral/) | **6** |
| Sorries on crown path | **0** |
| Crown axioms | **2** (Mellin) / **4** (Perron) |

---

## Theorems Graduated in Exploration 20

### 1. `blockDiag_quadForm_decomp_mod` (ResidueDecomposition.lean)

**Statement:** For any modulus m and vector v, the quadratic form of the
block-diagonal Gram matrix equals the sum of class-restricted quadratic forms:

```
v^T G^{block}_m v = Σ_r v_r^T G v_r
```

**Proof strategy:** Unfold dotProduct/classRestrict_mod to raw Finset.sum,
factor the outer indicator via ite_mul, collapse using Finset.sum_ite_eq'
with Nat→Fin conversion, then case-split on class membership.

**Difficulty:** 11 iterations. The mathematical content is trivial but Lean's
ite/Fin coercion layers required careful term-level manipulation.

**Impact:** Enables `block_gap_dominates_mod` — the generalization of the
octonionic gap theorem to arbitrary moduli.

### 2. `ipr_lower_bound` (ParticipationRatio.lean)

**Statement:** For any unit vector v ∈ ℝⁿ, the inverse participation ratio
satisfies IPR(v) ≥ 1/n.

**Proof strategy:** Direct application of `sq_sum_le_card_mul_sum_sq` from
Mathlib.Algebra.Order.Chebyshev (Cauchy-Schwarz for finite sums).

**Difficulty:** 1 iteration after finding the Mathlib lemma.

**Impact:** Completes the IPR bounds triple (upper, lower, PR range) with
zero sorry, zero axioms.

---

## Remaining Sorries — Classification

### Category A: Blocked by Upstream (3 sorries)

These require a **forward Tauberian theorem** that does not exist in Mathlib 4.28.
They become closable if/when PNTAnd's Wiener-Ikehara implementation closes its
own 2 sorries.

| File | Sorry | Statement |
|------|-------|-----------|
| `PNT/Bridge.lean` | `pnt_mu_log_div_k_derived` | Σ μ(k)·ln(k)/k → -1 |
| `PNT/Bridge.lean` | `pnt_mu_log_sq_div_k_derived` | Σ μ(k)·ln²(k)/k → -2γ |
| `PNT/LogBridge.lean` | `frac_error_isLittleO` | Floor error is o(N) |

**Isolation:** None of these block MainChain.lean (zero sorries on crown path).

### Category B: Deliberately Deprecated (3 sorries)

These are artifacts of the pre-v11 spatial approach, which was **superseded
by the Mellin Crown architecture**. Some are mathematically false.

| File | Sorry | Status |
|------|-------|--------|
| `Covariance/CovarianceAbel.lean` | `gram_form_bound_raw` | DEPRECATED (spatial approach) |
| `Covariance/CovarianceAbel.lean` | assembly step | DEPRECATED (spatial approach) |
| `Covariance/QuadFormIdentity.lean` | `deprecated_gramEntry_growth_bound` | NUMERICALLY FALSE |

**These should NOT be closed.** They are historical artifacts kept for
reference. Closing them would require proving false statements.

---

## Theorems That Could Be Written

The following are new theorems that could be formalized in the current
infrastructure, organized by feasibility.

### Tier 1: Immediately Formalizable (Pure Algebra/Analysis)

These require only existing Mathlib + Cathedral infrastructure.

#### ~~1. IPR Monotonicity Under Projection~~ — RETRACTED

> **This theorem is FALSE.** The original claim was that projecting a
> vector to fewer components increases IPR. This is wrong in both directions:
>
> - **Raw IPR** (Σvᵢ⁴) *decreases* under projection (fewer positive terms).
>   This is now proved as `ipr_le_of_mask`.
> - **Normalized IPR** (Σvᵢ⁴/(Σvᵢ²)²) can go *either way*.
>
> **Counterexample:** v = (1, 1, 10), S = {1,2}:
> - Normalized IPR(v) = 10002/10404 ≈ 0.96
> - Normalized IPR(v|_S) = 2/4 = 0.50
> - IPR *decreased* — the outlier v₃=10 dominated the full vector's IPR.
>
> The correct theorems about IPR and restriction are:
> - `ipr_le_of_mask` ✅ — raw IPR decreases under masking
> - `ipr_lower_bound` ✅ — normalized IPR ≥ 1/n for unit vectors
> - `ipr_nonneg` ✅ — raw IPR ≥ 0


#### 2. Gram Entry Symmetry — ✅ PROVED as `gramEntry_comm`
```
theorem gramEntry_comm (j k : ℕ) : gramEntry j k = gramEntry k j
```
Proved in `Defs.lean` via `congr`/`ext`/`ring`.

#### 3. Block-Diagonal Trace Identity — ✅ PROVED as `blockDiag_trace_eq_gram_trace`
```
theorem blockDiag_trace_eq_gram_trace (N m : ℕ) :
    Matrix.trace (gramMatrixBlockDiag_mod N m) = Matrix.trace (gramMatrix N)
```
Proved in `ResidueDecomposition.lean` via `sum_congr`/`simp` (diagonal trivially matches).

#### 4. Class Restriction Orthogonality — ✅ PROVED as `classRestrict_mod_orthogonal`
```
theorem classRestrict_mod_orthogonal (N m : ℕ) (_hm : 0 < m)
    (r₁ r₂ : Fin m) (hr : r₁ ≠ r₂) (v : Fin (N-1) → ℝ) :
    dotProduct (classRestrict_mod N m r₁ v) (classRestrict_mod N m r₂ v) = 0
```
Proved in `ResidueDecomposition.lean` via `split_ifs`/`Fin.ext`/`ring`.

#### 5. IPR of Uniform Vector — ✅ PROVED as `ipr_uniform`
```
theorem ipr_uniform {n : ℕ} (hn : 0 < n) :
    ipr (fun _ : Fin n => (1 : ℝ) / Real.sqrt n) = 1 / (n : ℝ)
```
Proved in `ParticipationRatio.lean` via `sq_sqrt`/`field_simp`.

#### 6. IPR of Basis Vector — ✅ PROVED as `ipr_basis`
```
theorem ipr_basis {n : ℕ} (k : Fin n) :
    ipr (fun i : Fin n => if i = k then (1 : ℝ) else 0) = 1
```
Proved in `ParticipationRatio.lean` via `conv`/`split_ifs`/`sum_ite_eq'`.

#### Additional Theorems (not in original report)
- `ipr_nonneg` ✅ — raw IPR ≥ 0 (`positivity`)
- `ipr_le_of_mask` ✅ — raw IPR decreases under masking (`sum_le_sum`/`positivity`)

### Tier 2: Requires Moderate Infrastructure

#### 7. Spectral Gap Monotonicity in Modulus
```
theorem spectral_gap_monotone_mod (N m₁ m₂ : ℕ) (hN : 2 ≤ N)
    (hm₁ : 0 < m₁) (hm₂ : 0 < m₂) (hdvd : m₁ ∣ m₂) :
    lambdaMinBlock_mod N m₁ ≤ lambdaMinBlock_mod N m₂
```
**Difficulty:** Hard. If m₁ | m₂, then the mod-m₂ partition refines the mod-m₁
partition, so the block-diagonal matrix for m₂ is "more diagonal" and has
larger minimum eigenvalue.

#### 8. Gram Matrix Positive Semi-Definiteness (Direct)
```
theorem gram_pos_semidef (N : ℕ) (v : Fin (N-1) → ℝ) :
    0 ≤ realQuadForm (gramMatrix N) v
```
**Difficulty:** Medium-Hard. The Gram matrix is a Grammian (by construction),
so it's PSD. Requires connecting the matrix definition to the inner product
structure of {1/(kx)} functions.

#### 9. Residue Decomposition Norm Bound
```
theorem residue_norm_bound (N m : ℕ) (hm : 0 < m) (v : Fin (N-1) → ℝ) :
    ∑ r : Fin m, dotProduct (classRestrict_mod N m r v) (classRestrict_mod N m r v)
    = dotProduct v v
```
**Difficulty:** Medium. Already stated as `classRestrict_mod_partition`, but
could be strengthened with explicit L² norm equality.

### Tier 3: Conjectural / Requires New Infrastructure

#### 10. GOE Ratio Constant (Experimental)
```
-- Would require formalizing eigenvalue statistics
theorem pr_ratio_bounded_away :
    ∀ N ≥ 100, 0.4 < mean_pr(G_N) / (↑(N-1) / 3) ∧
    mean_pr(G_N) / (↑(N-1) / 3) < 0.6
```
**Difficulty:** Very Hard. Requires formalizing mean PR over all eigenvectors
and computing it numerically. Could be done as a certified computation.

#### 11. Cross-Term Spectral Perturbation
```
-- G = G^block + G^cross, bound ||G^cross|| spectrally
theorem cross_term_bounded (N m : ℕ) :
    ∀ v, |realQuadForm (gramMatrixCross N m) v| ≤ C * dotProduct v v
```
**Difficulty:** Very Hard. The cross-term perturbation theory is the key
to understanding how far the block-diagonal approximation is from exact.

---

## New Files Created in Exploration 20

| File | Lines | Theorems | Sorry |
|------|-------|----------|-------|
| `Cathedral/Spectral/ResidueDecomposition.lean` | 251 | 4 | 0 |
| `papers/public/cathedral-gemini.tex` | 175 | — | — |

## Files Modified in Exploration 20

| File | Change |
|------|--------|
| `papers/public/cathedral-letter.tex` → `cathedral-claude.tex` | Renamed |
| `Cathedral/Spectral/ParticipationRatio.lean` | `ipr_lower_bound` graduated |

---

## Recommendation

The Cathedral's formal proof infrastructure is at a **stable plateau**:

1. **Crown path:** Zero sorry, zero unsoundness. Ship-ready.
2. **Off-crown sorries:** 3 blocked by upstream (Tauberian), 3 deprecated.
3. **New theorems:** Tier 1 items (4-6 theorems) are immediately
   formalizable with 1-2 iterations each. Tier 2 items would extend
   the spectral analysis but don't affect the crown.
4. **Paper updates needed:** Theorem count (666 → 1,216 after recount),
   line counts, sorry status should be synchronized.

**The wall is real for sorry graduation. But the frontier for new theorems
is wide open in the spectral analysis domain.**

---

*Report generated by Antigravity (Claude), April 29, 2026.*  
*Exploration 20, Los Alamos, New Mexico.*
