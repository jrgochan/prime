/-
  Cathedral/Vasyunin/Cotangent/FractReflection.lean

  ## Graduating fract_reflection_coprime

  Proves: {m(a−b)/a} = 1 − {mb/a} for coprime a,b with 1 ≤ m < a.
  Created: May 20, 2026 (The Thulium Session — Graduation)
-/

import Mathlib.Data.Real.Basic
import Mathlib.Data.Real.Archimedean
import Mathlib.Algebra.Order.Floor.Ring
import Mathlib.Data.Nat.GCD.Basic
import Mathlib.Order.Interval.Finset.Nat
import Mathlib.Tactic

noncomputable section
open Finset

namespace Cathedral.Vasyunin.FractReflection

-- ════════════════════════════════════════════════
-- STEP 1: The arithmetic rewrite in ℝ
-- ════════════════════════════════════════════════

lemma fract_arg_eq (m a b : ℕ) (ha : 2 ≤ a) (hba : b < a) :
    ((m * (a - b) : ℕ) : ℝ) / (a : ℝ) =
    (m : ℝ) - ((m * b : ℕ) : ℝ) / (a : ℝ) := by
  have ha0 : (a : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
  have hle : b ≤ a := le_of_lt hba
  field_simp
  push_cast [Nat.cast_sub hle]
  ring

-- ════════════════════════════════════════════════
-- STEP 2: Non-divisibility from coprimality
-- ════════════════════════════════════════════════

lemma coprime_not_dvd_mul (a b m : ℕ) (_ha : 2 ≤ a) (hm1 : 1 ≤ m) (hma : m < a)
    (hcop : Nat.Coprime a b) :
    ¬(a ∣ m * b) := by
  intro h
  have ham : a ∣ m := (hcop.dvd_mul_right).mp h
  obtain ⟨k, rfl⟩ := ham
  -- a * k < a with k ≥ 1 → false
  have hk1 : 1 ≤ k := by nlinarith
  have : a ≤ a * k := Nat.le_mul_of_pos_right a (by omega)
  omega

-- ════════════════════════════════════════════════
-- STEP 3: Non-zero fract from non-divisibility
-- ════════════════════════════════════════════════

lemma fract_ne_zero_of_not_dvd (a : ℕ) (mb : ℕ) (ha : 2 ≤ a)
    (hnd : ¬(a ∣ mb)) :
    Int.fract ((mb : ℝ) / (a : ℝ)) ≠ 0 := by
  intro hf
  apply hnd
  rw [Int.fract_eq_zero_iff] at hf
  obtain ⟨z, hz⟩ := hf
  have ha0 : (a : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
  have hza : (mb : ℝ) = (z : ℝ) * (a : ℝ) := by
    field_simp at hz; linarith
  have hz_nn : (0 : ℤ) ≤ z := by
    by_contra hlt
    simp only [not_le] at hlt
    nlinarith [Nat.cast_nonneg (α := ℝ) mb, show (0 : ℝ) < a from by positivity,
               show (z : ℝ) < 0 from Int.cast_lt_zero.mpr hlt]
  have hmb_int : (mb : ℤ) = z * (a : ℤ) := by exact_mod_cast hza
  -- a ∣ mb: need to show mb = a * q for some q
  refine ⟨z.toNat, ?_⟩
  zify [Int.toNat_of_nonneg hz_nn]
  linarith [hmb_int, mul_comm z (a : ℤ)]

-- ════════════════════════════════════════════════
-- STEP 4: THE COMPLETE GRADUATION
-- ════════════════════════════════════════════════

/-- **GRADUATED**: {m(a−b)/a} = 1 − {mb/a} for coprime a,b.

    Zero sorry. Zero axioms. -/
theorem fract_reflection_coprime (a b m : ℕ) (ha : 2 ≤ a) (hm : m ∈ Ico 1 a)
    (hcop : Nat.Coprime a b) (hb : b < a) :
    Int.fract ((m * (a - b) : ℕ) / (a : ℝ)) =
    1 - Int.fract ((m * b : ℕ) / (a : ℝ)) := by
  have hm1 : 1 ≤ m := (Finset.mem_Ico.mp hm).1
  have hma : m < a := (Finset.mem_Ico.mp hm).2
  rw [fract_arg_eq m a b ha hb]
  have hrw : (m : ℝ) - ((m * b : ℕ) : ℝ) / (a : ℝ) =
      -(((m * b : ℕ) : ℝ) / (a : ℝ)) + ↑m := by push_cast; ring
  rw [hrw, Int.fract_add_natCast, Int.fract_neg]
  exact fract_ne_zero_of_not_dvd a (m * b) ha
    (coprime_not_dvd_mul a b m ha hm1 hma hcop)

end Cathedral.Vasyunin.FractReflection
