/-
  Cathedral/White/Infrastructure/SummabilityHelpers.lean

  ## Summability Helpers for Real Power Series

  Lightweight (pre-proved) lemmas about summability of 1/n^c and related bounds.
  These are compiled once with generous heartbeats, then imported by downstream
  consumers (like HalfIntegerPerron.lean) as pre-proved facts, avoiding
  re-elaboration of the expensive synthesis in the heavier import context.

  ### Key results
  * `rpow_inv_summable` : ∑ (n^c)⁻¹ converges for c > 1
  * `rpow_inv_tsum_pos` : the tsum is positive
  * `rpow_inv_partial_le_tsum` : finite partial sums ≤ tsum
  * `div_rpow_eq_mul_inv` : (X/n)^c = X^c · (n^c)⁻¹
  * `mul_rpow_eq_rpow_succ` : X · X^c = X^{c+1}

  ### Dependencies: Mathlib only (no Cathedral imports).
-/

import Mathlib

set_option maxHeartbeats 800000

noncomputable section
open Real BigOperators Finset

namespace Cathedral.Perron.SummabilityHelpers

-- ═══════════════════════════════════════════
-- §1. Summability of 1/n^c
-- ═══════════════════════════════════════════

/-- `∑_{n=0}^∞ (n^c)⁻¹` converges for `c > 1`. -/
theorem rpow_inv_summable {c : ℝ} (hc : 1 < c) :
    Summable (fun n : ℕ => ((n : ℝ) ^ c)⁻¹) :=
  Real.summable_nat_rpow_inv.mpr hc

/-- Each term `(n^c)⁻¹ ≥ 0`. -/
lemma rpow_inv_nonneg (c : ℝ) (n : ℕ) :
    0 ≤ ((n : ℝ) ^ c)⁻¹ :=
  inv_nonneg.mpr (rpow_nonneg (Nat.cast_nonneg' n) c)

/-- The tsum `∑ (n^c)⁻¹ > 0` for `c > 1` (the n=1 term is 1). -/
theorem rpow_inv_tsum_pos {c : ℝ} (hc : 1 < c) :
    0 < ∑' n : ℕ, ((n : ℝ) ^ c)⁻¹ := by
  have h1 : (((1 : ℕ) : ℝ) ^ c)⁻¹ = 1 := by simp
  calc 0 < (((1 : ℕ) : ℝ) ^ c)⁻¹ := by rw [h1]; exact one_pos
    _ ≤ ∑' n : ℕ, ((n : ℝ) ^ c)⁻¹ :=
        (rpow_inv_summable hc).le_tsum 1 (fun n _ => rpow_inv_nonneg c n)

/-- Finite partial sums are bounded by the tsum. -/
theorem rpow_inv_partial_le_tsum {c : ℝ} (hc : 1 < c) (s : Finset ℕ) :
    ∑ n ∈ s, ((n : ℝ) ^ c)⁻¹ ≤ ∑' n : ℕ, ((n : ℝ) ^ c)⁻¹ :=
  (rpow_inv_summable hc).sum_le_tsum s (fun n _ => rpow_inv_nonneg c n)

-- ═══════════════════════════════════════════
-- §2. Power/Division Algebra (reusable)
-- ═══════════════════════════════════════════

/-- `(X/n)^c = X^c · (n^c)⁻¹` for `X > 0` and `n > 0`. -/
lemma div_rpow_eq_mul_inv {X : ℝ} {n : ℕ} (hX : 0 < X) (hn : 0 < n) (c : ℝ) :
    (X / ↑n) ^ c = X ^ c * ((n : ℝ) ^ c)⁻¹ := by
  rw [div_rpow hX.le (Nat.cast_pos.mpr hn).le]; ring

/-- `X · X^c = X^{c+1}` for `X > 0`. -/
lemma mul_rpow_eq_rpow_succ {X : ℝ} (hX : 0 < X) (c : ℝ) :
    X * X ^ c = X ^ (c + 1) := by
  have := rpow_add hX c 1
  rw [rpow_one] at this; linarith

end Cathedral.Perron.SummabilityHelpers
