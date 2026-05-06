# Exploration 25 — Final Report

**Date**: May 3–5, 2026  
**Branch**: `exploration25`  
**Status**: ✅ SEALED — Ready to merge

---

## Executive Summary

Exploration 25 achieved two landmark results for the Cathedral proof architecture:

1. **The Vasyunin Identity** — `sum_perClass_eq_deltaTarget_algebraic` proved (zero sorry), closing the hardest lemma in the Cotangent evaluation chain
2. **Axiom Graduation** — `gramIntegral_eq_formula_ge2` graduated from axiom → theorem, reducing the Cathedral axiom count from **4 → 3**

The `#print axioms nyman_beurling_equivalence` now shows:

```
[covariance_bound_from_mertens_34,
 pnt_mu_div_k,
 pnt_mu_log_div_k,
 propext, Classical.choice, Quot.sound]
```

**3 Cathedral axioms + 3 Lean kernel axioms. Zero sorryAx.**

---

## Major Accomplishments

### 1. The Staircase Telescope (May 3)

**File**: `ColumnSumEval.lean`

Proved the indicator-filter equivalence lemma that converts Finset-filtered sums over two-tile residue classes into explicit per-class evaluations. This was a combinatorial bottleneck requiring:

- Indicator-based proof via `Finset.filter` → `Finset.sum_filter`
- 6 helper lemmas for coprimality, divisibility, and remainder arithmetic
- Bijection between filtered index set and explicit class enumeration

### 2. Assembly of the Nine Rewrites (May 3–4)

**File**: `DeltaDirectEval.lean`

Constructed the evaluation pipeline for `sum_perClass_eq_deltaTarget_algebraic`:

- **S₁–S₄ decomposition**: Split the per-class limit into four component sums
- **9 evaluation hypotheses**: Each involving logΓ, digamma, fractional parts, and cotangent sums
- **Abel Cancellation discovery**: The `AbelLogΓ` terms cancel between S₁ and the fractional target

### 3. GPU Certifier v3 — 12,032 Pairs (May 4)

**Experiment**: `two-tile-decomposition-gpu`

Verified the Vasyunin Gram identity numerically at 1024-bit MPFR precision for all 12,032 coprime pairs with `a < b ≤ 200`. This provided independent certification that the algebraic identity is correct before attempting the formal proof.

### 4. The Vasyunin Identity — PROVED (May 5)

**File**: `DeltaDirectEval.lean`, lines 1263–1495  
**Theorem**: `sum_perClass_eq_deltaTarget_algebraic`

The hardest lemma in the Cathedral. Proved via the **Symmetric Weighted Digamma Reflection** strategy:

#### Proof Architecture

```
Step 1: Evaluate fractional part sums → (b-1)/2
Step 2: Gauss logΓ multiplication → log(2π), log(b), Γ(1)
Step 3: Apply weighted digamma reflection (h_wdr) for modulus b
Step 4: Reindex digamma sums (range b → Icc 1 (b-1) + boundary)
Step 5: Apply real_digamma_sum for modulus b → γ, log(b)
Step 6: Evaluate ψ(1) = -γ
Step 7: Apply SYMMETRIC weighted digamma reflection (h_wdr_sym) for modulus a
Step 8: Apply real_digamma_sum for modulus a → γ, log(a)
Step 9: Expand log(b/a) → log(b) - log(a)
Step 10: Factor 1/b from per-class digamma sum
Step 11: field_simp + ring
```

#### Critical Design Decisions

1. **Substitution ordering**: Analytical substitutions (h_wdr, digamma sums, ψ(1)=-γ) must occur **before** `field_simp`. Applying `field_simp` first converts `r/b` to `r * b⁻¹`, creating pattern mismatches for `rw`.

2. **Symmetric reflection**: The identity requires **both** `weighted_digamma_reflection_solve_general b a` (for the SBA terms) AND its symmetric version `weighted_digamma_reflection_solve_general a b` (for the SAB terms). This was the critical missing insight.

3. **ring fragility**: After a clean build, `field_simp` produced inconsistent argument orderings (`a*x*b⁻¹` vs `a*b⁻¹*x`). Fixed by:
   - Expanding `log(b/a) → log(b) - log(a)` before `field_simp`
   - Factoring `1/b` out of the per-class ψ sum using `Finset.mul_sum`
   - This ensures `field_simp + ring` produces consistent forms

### 5. Axiom Graduation — gramIntegral (May 5)

**File**: `AlgebraicLimit.lean`

The `axiom gramIntegral_eq_formula_ge2` was a cycle-breaking stub introduced in May 2, 2026. The proof existed downstream in `TwoTileEval.gramIntegral_eq_formula_coprime`, but it was believed that importing `TwoTileEval` into `AlgebraicLimit` would create a cycle.

**Discovery**: The import cycle **does not exist**. Tracing the DAG:

```
TwoTileEval → TsumDirectEval → DeltaDirectEval → {ColumnSumEval, WeightedDigammaGeneral, ...}
```

None of these files import `AlgebraicLimit`, `ConvergenceAxioms`, or `LogDigammaBridge`. Therefore `AlgebraicLimit` can safely import `TwoTileEval`.

**Result**: axiom replaced with:
```lean
theorem gramIntegral_eq_formula_ge2 ... :=
  TwoTileEval.gramIntegral_eq_formula_coprime a b (by omega) hb hab hcop
```

---

## Axiom Audit (v19)

### Crown Path (`nyman_beurling_equivalence`)

| # | Axiom | Domain | Status |
|---|-------|--------|--------|
| 1 | `covariance_bound_from_mertens_34` | Abel summation | Active — PNT-family |
| 2 | `pnt_mu_div_k` | PNT: Σμ(k)/k → 0 | Active — PNT-family |
| 3 | `pnt_mu_log_div_k` | PNT: Σμ(k)ln(k)/k → -1 | Active — PNT-family |

### Graduated in exploration25

| Axiom | Mechanism | Date |
|-------|-----------|------|
| `gramIntegral_eq_formula_ge2` | Import cycle nonexistent → TwoTileEval | May 5, 2026 |

### Previously Graduated

| Axiom | Mechanism | Date |
|-------|-----------|------|
| `rh_zeta_lower_bound_from_zero_counting` | Littlewood Maneuver | May 4, 2026 |
| `sorryAx` | Converted to explicit axiom | May 5, 2026 |
| `selberg_delange_decay` | α=1 mean-field | April 30, 2026 |
| `gram_form_upper_bound_34` | Variance decomposition | April 25, 2026 |

### Reduction History

```
v1  (March 2026):    6 axioms
v5  (April 18):      1 axiom (One Crown)
v11 (April 26):      2 axioms (Mellin Crown)
v15 (April 30):      4 axioms (Triple Path + transparent)
v18 (May 5 AM):      4 axioms (sorryAx eliminated)
v19 (May 5 PM):      3 axioms (gramIntegral graduated) ← CURRENT
```

---

## GPU Experiment Results (WSL — RTX 4090)

### Gram Scaling Oracle — λ_min Eigenvalue Tracking

| N | λ_min | Mode | Time |
|---|-------|------|------|
| 100 | 1.201e-4 | GPU cuSOLVER | 0.1s |
| 200 | 3.168e-5 | GPU cuSOLVER | <0.1s |
| 500 | 7.366e-6 | GPU cuSOLVER | <0.1s |
| 1,000 | 4.244e-6 | GPU cuSOLVER | <0.1s |
| 2,000 | -6.464e-6 | GPU cuSOLVER | 0.1s |
| 5,000 | 3.528e-7 | GPU cuSOLVER | 0.6s |
| 10,000 | 2.533e-7 | GPU cuSOLVER | 3.5s |
| 20,000 | 1.945e-7 | GPU cuSOLVER | 23.5s |
| 40,000 | 1.564e-7 | CPU OpenBLAS | 2507s |

- **Power-law fit**: α ≈ 1.13 (R² = 0.960)
- **Log-decay fit**: α ≈ 8.32 (R² = 0.986) — better fit
- **N=60,000**: Matrix build was at 99% completion at session end

The N=2000 negative eigenvalue is a known double-precision artifact (DD precision at that scale gives positive).

---

## Files Modified

### Core Proof Files
- `DeltaDirectEval.lean` — The Vasyunin Identity proof
- `AlgebraicLimit.lean` — Axiom graduation (axiom → theorem)
- `MainChain.lean` — Audit updated to v19

### Supporting Infrastructure (from earlier in exploration25)
- `ColumnSumEval.lean` — Staircase telescope
- `WeightedDigammaGeneral.lean` — Symmetric digamma reflections
- `FractSeriesEval.lean` — Digamma sum identities
- `GeneralResidueEval.lean` — Per-class limit evaluations
- `FractTargetEval.lean` — Fractional target closed forms

---

## Build Certification

```
lake build → 8442 jobs, 0 errors, 0 sorry on crown path
lake env lean DeltaDirectEval.lean → 0 errors, warnings only (deprecated push_neg)
#print axioms nyman_beurling_equivalence → 3 Cathedral + 3 kernel
```

---

## Next Steps (Exploration 26)

1. **Vasyunin Cotangent Refactor** — The directory has grown to 30+ files; consolidate and clean the architecture
2. **PNT Axiom Investigation** — Assess feasibility of graduating `pnt_mu_div_k` and `pnt_mu_log_div_k`
3. **N=60K Eigenvalue** — Collect the GPU result when the matrix build completes
4. **Covariance Axiom Path** — Investigate whether a direct Abel summation proof of `covariance_bound_from_mertens_34` exists that doesn't go through the deprecated `gram_form_upper_bound`
