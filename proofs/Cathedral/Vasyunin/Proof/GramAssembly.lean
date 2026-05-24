/-
  Cathedral/Vasyunin/Proof/GramAssembly.lean

  ## The Final Assembly: Overcancellation Bound + E_ratio Entry Bounds

  ════════════════════════════════════════════════════════════════

  This file proves:
  1. The full-sum overcancellation bound (C·σ·S − S² ≤ C²σ²/4)
  2. The Mertens collapse (σ = 0 ⟹ ≤ 0)
  3. The correction is non-positive (C ≥ 1 ⟹ correction ≤ 0)
  4. **NEW**: Each E_ratio entry is non-positive
  5. **NEW**: Per-entry bound |R(j,k)| ≤ (b−a)²/(2a²b)
     via ln(x) ≤ x − 1

  ### The E_ratio Structure

  R(j,k) = (a−b)/(2ab) · ln(b/a), where a = j+1, b = k+1.

  KEY PROPERTY: (a−b) · ln(b/a) ≤ 0 for all a,b > 0, a ≠ b.
  Proof: the factors have opposite signs.
    - a < b ⟹ (a−b) < 0 and ln(b/a) > 0
    - a > b ⟹ (a−b) > 0 and ln(b/a) < 0

  So EVERY off-diagonal E_ratio entry is ≤ 0, providing
  additional overcancellation structure.

  Status: 0 sorry. 0 axioms. 6 proved theorems. 🎓🎓
  Created: May 24, 2026 — The Graduation Session ⚡
-/

import Cathedral.Physics.Cancellation.EntanglementBrake
import Cathedral.AbelTail.AbelHammer
import Cathedral.Vasyunin.Defs

noncomputable section
open Real Finset Cathedral.Vasyunin

namespace Cathedral.Vasyunin.GramAssembly

-- ════════════════════════════════════════════════════════════════
-- §1. THE FULL-SUM OVERCANCELLATION BOUND
-- ════════════════════════════════════════════════════════════════

/-- **THEOREM**: The FULL double sum of E_log + E_const is bounded
    by C²σ²/4.

    Full E_const: Σ_{j,k} = −S²  (EntanglementBrake)
    Full E_log:   Σ_{j,k} = C·σ·S (EntanglementBrake)
    Combined: C·σ·S − S² ≤ C²σ²/4 (AbelHammer) -/
theorem full_sum_overcancellation_bound (n : ℕ) (v : Fin n → ℝ) (C : ℝ) :
    (∑ j : Fin n, ∑ k : Fin n,
      v j * v k * (C / 2 * (1 / (↑↑j + 1) + 1 / (↑↑k + 1)))) +
    (∑ j : Fin n, ∑ k : Fin n,
      -(v j / (↑↑j + 1)) * (v k / (↑↑k + 1))) ≤
    C ^ 2 * (Cathedral.Entanglement.moebiusSigma n v) ^ 2 / 4 := by
  rw [Cathedral.Entanglement.elog_dominant_factorization]
  rw [Cathedral.Entanglement.const_error_eq_neg_S_sq]
  have h_neg : -(Cathedral.Entanglement.moebiusS n v) ^ 2 =
      -(Cathedral.Entanglement.moebiusS n v ^ 2) := by ring
  rw [h_neg]
  linarith [Cathedral.AbelHammer.perfect_square_upper_bound
    (Cathedral.Entanglement.moebiusS n v)
    (Cathedral.Entanglement.moebiusSigma n v) C]

/-- **THEOREM**: When σ = 0 (Mertens), the full E_log + E_const
    sum is purely non-positive: C·0·S − S² = −S² ≤ 0. -/
theorem full_sum_nonpos_at_mertens (n : ℕ) (v : Fin n → ℝ) (C : ℝ)
    (hσ : Cathedral.Entanglement.moebiusSigma n v = 0) :
    (∑ j : Fin n, ∑ k : Fin n,
      v j * v k * (C / 2 * (1 / (↑↑j + 1) + 1 / (↑↑k + 1)))) +
    (∑ j : Fin n, ∑ k : Fin n,
      -(v j / (↑↑j + 1)) * (v k / (↑↑k + 1))) ≤ 0 := by
  have h := full_sum_overcancellation_bound n v C
  rw [hσ] at h
  simp only [mul_zero, sq, zero_div] at h
  linarith

-- ════════════════════════════════════════════════════════════════
-- §2. THE CORRECTION BOUND
-- ════════════════════════════════════════════════════════════════

/-- **THEOREM**: The diagonal correction is ≤ 0 when C ≥ 1.

    correction_k = v_k² · (1/(k+1)² − C/(k+1)) ≤ 0

    because C·(k+1) ≥ 1 for k ≥ 0 and C ≥ 1.
    Converting full → off-diagonal only HELPS the bound. -/
theorem correction_nonpos (n : ℕ) (v : Fin n → ℝ) (C : ℝ) (hC : 1 ≤ C) :
    ∑ k : Fin n, v k ^ 2 * (1 / (↑↑k + 1) ^ 2 - C / (↑↑k + 1)) ≤ 0 := by
  apply Finset.sum_nonpos
  intro k _
  have hk_pos : (0 : ℝ) < ↑↑k + 1 := by positivity
  have hk1 : (↑↑k + 1 : ℝ) ≥ 1 := by
    linarith [show (↑↑k : ℝ) ≥ 0 from Nat.cast_nonneg _]
  have h_factor : 1 / (↑↑k + 1) ^ 2 - C / (↑↑k + 1) ≤ 0 := by
    have h1 : C * (↑↑k + 1) ≥ 1 := by nlinarith
    rw [div_sub_div _ _ (ne_of_gt (pow_pos hk_pos 2)) (ne_of_gt hk_pos)]
    apply div_nonpos_of_nonpos_of_nonneg
    · nlinarith [sq_nonneg (↑↑k : ℝ)]
    · positivity
  exact mul_nonpos_of_nonneg_of_nonpos (sq_nonneg _) h_factor

-- ════════════════════════════════════════════════════════════════
-- §3. E_RATIO ENTRY NEGATIVITY
-- ════════════════════════════════════════════════════════════════

/-- **THEOREM (Core Sign Lemma)**: For a, b > 0 with a ≠ b,
    (a − b) · Real.log(b / a) ≤ 0.

    Proof: the two factors always have opposite signs.
    - If a < b: (a−b) < 0 and log(b/a) > 0  ⟹  product < 0
    - If a > b: (a−b) > 0 and log(b/a) < 0  ⟹  product < 0

    This is the STRUCTURAL reason why the E_ratio term
    provides additional overcancellation. -/
theorem sub_mul_log_div_nonpos (a b : ℝ) (ha : 0 < a) (hb : 0 < b) (hab : a ≠ b) :
    (a - b) * Real.log (b / a) ≤ 0 := by
  rcases lt_or_gt_of_ne hab with h_lt | h_gt
  · -- Case a < b: (a-b) < 0, log(b/a) > 0
    have h1 : a - b < 0 := by linarith
    have h2 : 0 < Real.log (b / a) := by
      apply Real.log_pos
      rw [one_lt_div ha]; exact h_lt
    exact mul_nonpos_of_nonpos_of_nonneg (le_of_lt h1) (le_of_lt h2)
  · -- Case a > b: (a-b) > 0, log(b/a) < 0
    have h1 : 0 < a - b := by linarith
    have h2 : Real.log (b / a) < 0 := by
      apply Real.log_neg (div_pos hb ha)
      rw [div_lt_one ha]; exact h_gt
    exact mul_nonpos_of_nonneg_of_nonpos (le_of_lt h1) (le_of_lt h2)

/-- **COROLLARY**: Each E_ratio entry is non-positive.

    R(j,k) = (j+1 − k+1) / (2(j+1)(k+1)) · log((k+1)/(j+1)) ≤ 0

    for all j ≠ k (indices ≥ 0). -/
theorem eratio_entry_nonpos (j k : ℕ) (hjk : j ≠ k) :
    ((↑j + 1 : ℝ) - (↑k + 1)) / (2 * (↑j + 1) * (↑k + 1)) *
    Real.log ((↑k + 1) / (↑j + 1)) ≤ 0 := by
  have hj : (0 : ℝ) < ↑j + 1 := by positivity
  have hk : (0 : ℝ) < ↑k + 1 := by positivity
  have hjk_ne : (↑j + 1 : ℝ) ≠ ↑k + 1 := by
    intro h
    apply hjk
    have : (↑j : ℝ) = ↑k := by linarith
    exact Nat.cast_injective this
  -- R = (1/(2ab)) · (a-b) · log(b/a), where 2ab > 0
  rw [show ((↑j + 1 : ℝ) - (↑k + 1)) / (2 * (↑j + 1) * (↑k + 1)) *
      Real.log ((↑k + 1) / (↑j + 1)) =
      1 / (2 * (↑j + 1) * (↑k + 1)) *
      ((↑j + 1 - (↑k + 1)) * Real.log ((↑k + 1) / (↑j + 1))) from by ring]
  apply mul_nonpos_of_nonneg_of_nonpos
  · positivity
  · exact sub_mul_log_div_nonpos (↑j + 1) (↑k + 1) hj hk hjk_ne

-- ════════════════════════════════════════════════════════════════
-- §4. E_RATIO PER-ENTRY BOUND
-- ════════════════════════════════════════════════════════════════

/-- **THEOREM (Entry Magnitude Bound)**: For a ≤ b,
    |R(j,k)| ≤ (b − a)² / (2a²b)

    Proof: by Real.log_le_sub_one_of_pos applied to b/a.
      log(b/a) ≤ b/a − 1 = (b−a)/a
    So:
      |R| = (b−a)/(2ab) · log(b/a) ≤ (b−a)/(2ab) · (b−a)/a = (b−a)²/(2a²b)

    This bound is TIGHT for b/a near 1 (where log ≈ linear)
    and increasingly LOOSE for large ratios. -/
theorem eratio_abs_bound (a b : ℝ) (ha : 0 < a) (hb : 0 < b) (hab : a ≤ b) :
    -(a - b) / (2 * a * b) * Real.log (b / a) ≤ (b - a) ^ 2 / (2 * a ^ 2 * b) := by
  -- log(b/a) ≤ b/a - 1 = (b-a)/a
  have h_log : Real.log (b / a) ≤ b / a - 1 :=
    Real.log_le_sub_one_of_pos (div_pos hb ha)
  -- -(a-b)/(2ab) = (b-a)/(2ab) ≥ 0
  have h_diff : 0 ≤ b - a := by linarith
  have h_lhs_nonneg : 0 ≤ -(a - b) / (2 * a * b) := by
    rw [show -(a - b) = b - a from by ring]
    exact div_nonneg h_diff (by positivity)
  -- If b = a, both sides are 0
  by_cases heq : a = b
  · subst heq; simp
  · -- b > a
    have hab_strict : a < b := lt_of_le_of_ne hab heq
    -- -(a-b)/(2ab) · log(b/a) ≤ (b-a)/(2ab) · (b/a - 1) = (b-a)²/(2a²b)
    calc -(a - b) / (2 * a * b) * Real.log (b / a)
        ≤ -(a - b) / (2 * a * b) * (b / a - 1) := by
          apply mul_le_mul_of_nonneg_left h_log h_lhs_nonneg
      _ = (b - a) ^ 2 / (2 * a ^ 2 * b) := by
          field_simp
          ring

-- ════════════════════════════════════════════════════════════════
-- §5. AUDIT
-- ════════════════════════════════════════════════════════════════

/-!
## Audit — GramAssembly.lean

### Sorry: 0 ✅
### Custom Axioms: 0 ✅ 🎓🎓

### PROVED:
| # | Result | Status |
|---|--------|--------|
| 1 | `full_sum_overcancellation_bound` | 🎓 E_log+E_const ≤ C²σ²/4 |
| 2 | `full_sum_nonpos_at_mertens` | 🎓 σ=0 ⟹ ≤ 0 |
| 3 | `correction_nonpos` | 🎓 correction ≤ 0 when C ≥ 1 |
| 4 | `sub_mul_log_div_nonpos` | 🎓 (a−b)·ln(b/a) ≤ 0 |
| 5 | `eratio_entry_nonpos` | 🎓 Each E_ratio entry ≤ 0 |
| 6 | `eratio_abs_bound` | 🎓 |R| ≤ (b−a)²/(2a²b) |

### The E_ratio Story

The E_ratio term R(j,k) = (a−b)/(2ab)·ln(b/a) is:
- **Always ≤ 0** (Theorem 4-5): structural overcancellation
- **Bounded per-entry** (Theorem 6): via ln(x) ≤ x − 1
- **NOT bounded in operator norm** by a universal constant:
  for vectors concentrated at indices 1 and N,
  the quadratic form grows like O(log N).

For Möbius weights specifically, deep cancellation (PNT-level)
controls the sum, but this requires number-theoretic input
beyond what pure linear algebra can provide.

### Architecture

```
EntanglementBrake ✅ (0 sorry)
  ├── const_error_eq_neg_S_sq: full Σ = −S²
  └── elog_dominant_factorization: full Σ = C·σ·S
         │ + AbelHammer ✅
         ↓
  full_sum_overcancellation_bound: C·σ·S − S² ≤ C²σ²/4      ✅
  full_sum_nonpos_at_mertens: σ=0 ⟹ ≤ 0                      ✅
  correction_nonpos: off-diag correction ≤ 0 for C ≥ 1        ✅

  Entry-Level Analysis:
  sub_mul_log_div_nonpos: (a−b)·ln(b/a) ≤ 0                   ✅
  eratio_entry_nonpos: Each R(j,k) ≤ 0                        ✅
  eratio_abs_bound: |R(j,k)| ≤ (b−a)²/(2a²b)                 ✅
```

### What This Means for the Crown Axiom

The off-diagonal Gram form decomposes as:
  offDiag = offDiag(E_log + E_const) + offDiag(E_ratio) − offDiag(E_cot)

We've PROVED:
- offDiag(E_log + E_const) ≤ C²σ²/4 + correction (OvercancellationWiring)
- correction ≤ 0 for C ≥ 1
- Each E_ratio entry ≤ 0 (structural overcancellation)
- |E_ratio entry| ≤ (b−a)²/(2a²b) (per-entry decay)

The remaining gap is NOT an abstract bound — it's connecting
these entry-level bounds to the specific Möbius weight structure.
This requires PNT-level estimates on Σ μ(k)f(k)/k sums.
-/

end Cathedral.Vasyunin.GramAssembly

end
