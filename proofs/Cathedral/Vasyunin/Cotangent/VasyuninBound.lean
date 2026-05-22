/-
  Cathedral/Vasyunin/Cotangent/VasyuninBound.lean

  ## The Vasyunin Sum Bound: |V(a,b)| ≤ Σ |cot(πm/a)|

  The Vasyunin cotangent sum is:
    V(a,b) = Σ_{m=1}^{a-1} {mb/a} · cot(πm/a)

  Since 0 ≤ {mb/a} < 1 for coprime a,b (and ≤ 1 always), each term
  satisfies |{mb/a} · cot(πm/a)| ≤ |cot(πm/a)|.

  By the triangle inequality:
    |V(a,b)| ≤ Σ_{m=1}^{a-1} |cot(πm/a)|

  This provides an unconditional bound on the off-diagonal Gram terms.

  Created: May 20, 2026 (The Thulium Session)
-/

import Cathedral.Vasyunin.Defs
import Mathlib.Algebra.Order.BigOperators.Group.Finset
import Mathlib.Tactic

noncomputable section
open Finset

namespace Cathedral.Vasyunin.Bound

-- ════════════════════════════════════════════════
-- PART I: FRACTIONAL PART BOUND
-- ════════════════════════════════════════════════

/-- The fractional part is bounded: 0 ≤ {x} < 1. -/
lemma fract_abs_le_one (x : ℝ) : |Int.fract x| ≤ 1 := by
  rw [abs_le]
  constructor
  · linarith [Int.fract_nonneg x]
  · linarith [Int.fract_lt_one x]

/-- The fractional part of a natural number quotient is non-negative. -/
lemma fract_nat_div_nonneg (m b a : ℕ) : 0 ≤ Int.fract ((m * b : ℕ) / (a : ℝ)) :=
  Int.fract_nonneg _

/-- The fractional part of a natural number quotient is < 1. -/
lemma fract_nat_div_lt_one (m b a : ℕ) : Int.fract ((m * b : ℕ) / (a : ℝ)) < 1 :=
  Int.fract_lt_one _

-- ════════════════════════════════════════════════
-- PART II: POINTWISE BOUND
-- ════════════════════════════════════════════════

/-- Each term of the Vasyunin sum is bounded by |cot(πm/a)|.

    |{mb/a} · cot(πm/a)| ≤ 1 · |cot(πm/a)| = |cot(πm/a)|

    Uses: 0 ≤ {x} < 1, so |{x}| ≤ 1. -/
lemma vasyunin_term_bound (m b a : ℕ) :
    |Int.fract ((m * b : ℕ) / (a : ℝ)) * cot (Real.pi * m / a)| ≤
    |cot (Real.pi * m / a)| := by
  rw [abs_mul]
  calc |Int.fract ((m * b : ℕ) / (a : ℝ))| * |cot (Real.pi * ↑m / ↑a)|
      ≤ 1 * |cot (Real.pi * ↑m / ↑a)| := by
        apply mul_le_mul_of_nonneg_right (fract_abs_le_one _) (abs_nonneg _)
    _ = |cot (Real.pi * ↑m / ↑a)| := one_mul _

-- ════════════════════════════════════════════════
-- PART III: THE SUM BOUND
-- ════════════════════════════════════════════════

/-- **THE VASYUNIN SUM BOUND**: |V(a,b)| ≤ Σ |cot(πm/a)|.

    For a ≥ 2:
      |vasyuninSum a b| ≤ Σ_{m ∈ Ico 1 a} |cot(π·m/a)|

    Proof: Triangle inequality + pointwise bound.

    This is unconditional (no coprimality needed).
    Zero sorry. -/
theorem vasyuninSum_abs_le (a b : ℕ) (ha : 2 ≤ a) :
    |vasyuninSum a b| ≤
    ∑ m ∈ Ico 1 a, |cot (Real.pi * m / a)| := by
  unfold vasyuninSum
  simp only [show ¬(a ≤ 1) from by omega, ↓reduceIte]
  calc |∑ m ∈ Ico 1 a,
        Int.fract ((m * b : ℕ) / (a : ℝ)) * cot (Real.pi * m / a)|
      ≤ ∑ m ∈ Ico 1 a,
        |Int.fract ((m * b : ℕ) / (a : ℝ)) * cot (Real.pi * m / a)| :=
        abs_sum_le_sum_abs _ (Ico 1 a)
    _ ≤ ∑ m ∈ Ico 1 a, |cot (Real.pi * ↑m / ↑a)| := by
        apply Finset.sum_le_sum
        intro m _
        exact vasyunin_term_bound m b a

-- ════════════════════════════════════════════════
-- PART IV: CRUDE BOUND (a-1 terms)
-- ════════════════════════════════════════════════

/-- The number of terms in V(a,b) is exactly a-1.
    |Ico 1 a| = a - 1. -/
lemma ico_card (a : ℕ) (_ha : 2 ≤ a) : (Ico 1 a).card = a - 1 := by
  simp [Nat.card_Ico]

/-- **CRUDE BOUND**: |V(a,b)| ≤ (a-1) · max_m |cot(πm/a)|.

    The maximum of |cot(πm/a)| over 1 ≤ m ≤ a-1 occurs at m=1
    (or m=a-1), where it equals cot(π/a).

    We state this as: |V| ≤ (a-1) · C for any C that bounds all terms. -/
theorem vasyuninSum_abs_le_card_mul_sup (a b : ℕ) (ha : 2 ≤ a) (C : ℝ) (_hC : 0 ≤ C)
    (hbound : ∀ m ∈ Ico 1 a, |cot (Real.pi * m / a)| ≤ C) :
    |vasyuninSum a b| ≤ (a - 1 : ℕ) * C := by
  calc |vasyuninSum a b|
      ≤ ∑ m ∈ Ico 1 a, |cot (Real.pi * ↑m / ↑a)| :=
        vasyuninSum_abs_le a b ha
    _ ≤ ∑ _m ∈ Ico 1 a, C := by
        apply Finset.sum_le_sum
        intro m hm; exact hbound m hm
    _ = (Ico 1 a).card * C := by
        rw [Finset.sum_const, nsmul_eq_mul]
    _ = (a - 1 : ℕ) * C := by
        rw [ico_card a ha]

-- ════════════════════════════════════════════════
-- PART V: GRAM OFF-DIAGONAL BOUND
-- ════════════════════════════════════════════════

/-- The V+V sum is bounded by twice the individual bound.
    |V(a,b) + V(b,a)| ≤ |V(a,b)| + |V(b,a)| -/
theorem vasyuninSum_sum_abs_le (a b : ℕ) (ha : 2 ≤ a) (hb : 2 ≤ b) :
    |vasyuninSum a b + vasyuninSum b a| ≤
    ∑ m ∈ Ico 1 a, |cot (Real.pi * m / a)| +
    ∑ m ∈ Ico 1 b, |cot (Real.pi * m / b)| :=
  calc |vasyuninSum a b + vasyuninSum b a|
      ≤ |vasyuninSum a b| + |vasyuninSum b a| := abs_add_le _ _
    _ ≤ _ := add_le_add (vasyuninSum_abs_le a b ha) (vasyuninSum_abs_le b a hb)

end Cathedral.Vasyunin.Bound
