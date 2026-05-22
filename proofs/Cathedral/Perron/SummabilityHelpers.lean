/-
  Cathedral/Perron/SummabilityHelpers.lean

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

-- ═══════════════════════════════════════════
-- §3. Shifted p-series (for ZeroResonanceBridge)
-- ═══════════════════════════════════════════

/-- `∑_{n=0}^∞ (((n+k):ℕ)^c)⁻¹` converges for `c > 1` and any shift `k`.
    Uses comp_injective: a subseries of a summable nonneg series is summable. -/
theorem shifted_rpow_inv_summable {c : ℝ} (hc : 1 < c) (k : ℕ) :
    Summable (fun n : ℕ => (((n : ℝ) + (k : ℝ)) ^ c)⁻¹) := by
  have h_inj : Function.Injective (· + k : ℕ → ℕ) := fun a b h => Nat.add_right_cancel h
  have h_sub := (rpow_inv_summable hc).comp_injective h_inj
  -- h_sub : Summable ((fun n => (↑n ^ c)⁻¹) ∘ (· + k))
  -- Need: Summable (fun n => ((↑n + ↑k) ^ c)⁻¹)
  exact h_sub.congr (fun n => by simp only [Function.comp, Nat.cast_add])

/-- `∑_{n=0}^∞ C / ((n+k)^α)` converges for `α > 1`, `C > 0`, `k ≥ 1`.
    Direct corollary used by ZeroResonanceBridge.summable_drops_from_trend. -/
theorem shifted_pseries_summable {C α : ℝ} (_hC : 0 < C) (hα : 1 < α)
    (k : ℕ) :
    Summable (fun n : ℕ => C / ((n : ℝ) + (k : ℝ)) ^ α) := by
  -- C / x^α = C * (x^α)⁻¹
  have h := shifted_rpow_inv_summable hα k
  exact (h.mul_left C).congr (fun n => by rw [div_eq_mul_inv])

end Cathedral.Perron.SummabilityHelpers
