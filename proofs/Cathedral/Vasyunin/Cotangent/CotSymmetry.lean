/-
  Cathedral/Vasyunin/Cotangent/CotSymmetry.lean

  ## The Cotangent Sum Vanishes: Σ_{m=1}^{a-1} cot(πm/a) = 0

  This is the foundational symmetry that connects the Vasyunin
  cotangent sum V(a,b) to the cotangent Dedekind sum S₁(b,a).

  Proof: The involution m ↦ a−m satisfies
    cot(π(a−m)/a) = cot(π − πm/a) = −cot(πm/a)
  so each pair (m, a−m) cancels.

  Consequence: V(a,b) = S₁(b,a), because replacing {mb/a} by
  ((mb/a)) = {mb/a} − 1/2 adds (1/2)·Σ cot(πm/a) = 0.

  Created: May 19, 2026 (The Thulium Session)
-/

import Mathlib.Data.Real.Basic
import Mathlib.Analysis.SpecialFunctions.Trigonometric.Basic
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Cathedral.Vasyunin.Defs

noncomputable section
open Real Finset

namespace Cathedral.Vasyunin

-- ════════════════════════════════════════════════
-- PART I: COTANGENT SYMMETRY PRIMITIVES
-- ════════════════════════════════════════════════

/-- Cotangent of (π − x) equals negative cotangent of x.
    Proof: cos(π − x) = −cos(x) and sin(π − x) = sin(x). -/
theorem cot_pi_sub (x : ℝ) : cot (π - x) = -cot x := by
  unfold cot
  rw [Real.cos_pi_sub, Real.sin_pi_sub]
  ring

-- ════════════════════════════════════════════════
-- PART II: THE MAIN THEOREM
-- ════════════════════════════════════════════════

/-- Helper: for m ∈ Ico 1 a with a ≥ 2, we have m ≤ a - 1 < a,
    so (a - m : ℕ) = a - m and it lies in Ico 1 a. -/
private lemma Ico_reflect_mem {a m : ℕ} (_ha : 2 ≤ a) (hm : m ∈ Ico 1 a) :
    a - m ∈ Ico 1 a := by
  rw [Finset.mem_Ico] at hm ⊢
  omega

/-- Helper: a - (a - m) = m for m ≤ a. -/
private lemma sub_sub_cancel {a m : ℕ} (hm : m ∈ Ico 1 a) :
    a - (a - m) = m := by
  rw [Finset.mem_Ico] at hm
  omega

/-- Helper: Nat cast of (a - m) equals (a : ℝ) - (m : ℝ) when m < a. -/
private lemma cast_sub_of_mem {a m : ℕ} (hm : m ∈ Ico 1 a) :
    (↑(a - m) : ℝ) = (↑a : ℝ) - ↑m := by
  rw [Finset.mem_Ico] at hm
  exact Nat.cast_sub (by omega)

/-- The sum of cotangents vanishes: Σ_{m=1}^{a-1} cot(πm/a) = 0.

    Proof: The involution m ↦ a − m on {1, ..., a−1} pairs each
    term with its negation via cot(π − x) = −cot(x).

    This is the key symmetry that connects the Vasyunin cotangent sum
    V(a,b) to the cotangent Dedekind sum S₁(b,a). -/
theorem cot_sum_vanishes (a : ℕ) (ha : 2 ≤ a) :
    ∑ m ∈ Ico 1 a, cot (π * ↑m / ↑a) = 0 := by
  apply Finset.sum_involution (fun m _ => a - m)
  · -- Cancellation: f(m) + f(g(m)) = 0
    intro m hm
    have ha_ne : (a : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
    have hsub : (↑(a - m) : ℝ) = ↑a - ↑m := cast_sub_of_mem hm
    suffices h : cot (π * ↑(a - m) / ↑a) = -cot (π * ↑m / ↑a) by linarith
    rw [hsub]
    rw [show π * (↑a - ↑m) / (↑a : ℝ) = π - π * ↑m / ↑a from by
      rw [mul_sub, sub_div, mul_div_cancel_right₀ _ ha_ne]]
    exact cot_pi_sub _
  · -- Non-fixpoint: f(m) ≠ 0 → g(m) ≠ m
    -- When a - m = m, i.e. a = 2m, we have cot(πm/a) = cot(π/2) = cos(π/2)/sin(π/2) = 0
    intro m hm hne
    rw [Finset.mem_Ico] at hm
    intro heq
    apply hne
    have h2m : a = 2 * m := by omega
    have hm_ne : (m : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
    suffices π * ↑m / ↑a = π / 2 by rw [this]; unfold cot; rw [Real.cos_pi_div_two]; simp
    rw [h2m]
    push_cast
    rw [show (2 : ℝ) * ↑m = ↑m * 2 from by ring]
    rw [show π * ↑m / (↑m * 2) = π / 2 from by rw [mul_comm π, mul_div_mul_left _ _ hm_ne]]
  · -- Membership: a - m ∈ Ico 1 a
    intro m hm
    exact Ico_reflect_mem ha hm
  · -- Involution: a - (a - m) = m
    intro m hm
    exact sub_sub_cancel hm

end Cathedral.Vasyunin
