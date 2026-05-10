/-
  Cathedral/Analysis/FloorFract.lean

  ## FLOOR-FRACT INFRASTRUCTURE — Bridge between ℕ division and ℝ fractional parts

  Provides the critical missing infrastructure for converting between
  natural number floor division and real-valued fractional parts.

  ### Key Results (ALL PROVED, 0 sorry)

  1. **int_floor_eq_nat_div**: ⌊(a * m : ℝ) / b⌋ = (a * m / b : ℕ)
  2. **nat_div_cast_eq**: ↑(a*m/b : ℕ) = am/b - {am/b}
  3. **int_fract_eq_nat_mod_div**: {(a*m : ℝ)/b} = (a*m % b : ℝ) / b
  4. **floor_step_eq_frac_diff**: J(m) = a/b + {am/b} - {a(m+1)/b}
  5. **int_fract_eq_zero_iff**: {am/b} = 0 ↔ b ∣ am

  Uses Mathlib lemmas:
  - `Int.floor_div_natCast`: ⌊a / ↑n⌋ = ⌊a⌋ / n
  - `Int.floor_natCast`: ⌊↑n⌋ = n
  - `Int.fract_div_natCast_eq_div_natCast_mod`: {↑m / ↑n} = ↑(m % n) / ↑n

  Created: May 5, 2026 — Unblocking the Staircase Telescope & Beta Duality
-/

import Mathlib.Algebra.Order.Floor.Semifield
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Tactic

noncomputable section
open Finset

namespace Cathedral.Analysis.FloorFract

-- ════════════════════════════════════════════════
-- §1. NAT.DIV ↔ INT.FLOOR BRIDGE
-- ════════════════════════════════════════════════

/-- **Core bridge**: ⌊am/b⌋ = (a*m / b : ℕ) as integers.

    Chain: ⌊↑(am) / ↑b⌋ = ⌊↑(am)⌋ / b = (am : ℤ) / b = ↑(am / b : ℕ). -/
lemma int_floor_eq_nat_div (a m b : ℕ) :
    ⌊((a * m : ℕ) : ℝ) / (b : ℝ)⌋ = ((a * m / b : ℕ) : ℤ) := by
  rw [Int.floor_div_natCast, Int.floor_natCast]
  exact_mod_cast rfl

/-- Version with product form (a : ℝ) * (m : ℝ). -/
lemma int_floor_eq_nat_div' (a m b : ℕ) :
    ⌊((a : ℝ) * (m : ℝ)) / (b : ℝ)⌋ = ((a * m / b : ℕ) : ℤ) := by
  rw [show (a : ℝ) * (m : ℝ) = ((a * m : ℕ) : ℝ) from by push_cast; ring]
  exact int_floor_eq_nat_div a m b

/-- **Cast bridge**: ↑(a*m/b : ℕ) = am/b - {am/b} in ℝ. -/
lemma nat_div_cast_eq (a m b : ℕ) :
    ((a * m / b : ℕ) : ℝ) = ((a * m : ℕ) : ℝ) / (b : ℝ) -
    Int.fract (((a * m : ℕ) : ℝ) / (b : ℝ)) := by
  have h_fa := Int.floor_add_fract (((a * m : ℕ) : ℝ) / (b : ℝ))
  have h_floor := int_floor_eq_nat_div a m b
  have h_cast : (⌊((a * m : ℕ) : ℝ) / (b : ℝ)⌋ : ℝ) = ((a * m / b : ℕ) : ℝ) := by
    rw [Int.floor_div_natCast, Int.floor_natCast]
    push_cast; rfl
  linarith

-- ════════════════════════════════════════════════
-- §2. NAT.MOD ↔ INT.FRACT BRIDGE
-- ════════════════════════════════════════════════

/-- **Fract-mod bridge**: {↑(a*m) / ↑b} = (a*m % b : ℝ) / b.

    Uses `Int.fract_div_natCast_eq_div_natCast_mod` directly. -/
lemma int_fract_eq_nat_mod_div (a m b : ℕ) :
    Int.fract (((a * m : ℕ) : ℝ) / (b : ℝ)) = ((a * m % b : ℕ) : ℝ) / (b : ℝ) :=
  Int.fract_div_natCast_eq_div_natCast_mod

/-- Version with product form. -/
lemma int_fract_eq_nat_mod_div' (a m b : ℕ) :
    Int.fract ((a : ℝ) * (m : ℝ) / (b : ℝ)) = ((a * m % b : ℕ) : ℝ) / (b : ℝ) := by
  rw [show (a : ℝ) * (m : ℝ) = ((a * m : ℕ) : ℝ) from by push_cast; ring]
  exact int_fract_eq_nat_mod_div a m b

-- ════════════════════════════════════════════════
-- §3. FLOOR STEP DECOMPOSITION
-- ════════════════════════════════════════════════

/-- **Floor step decomposition**: J(m) = a/b + {am/b} - {a(m+1)/b}.

    The ℕ step ⌊a(m+1)/b⌋ - ⌊am/b⌋ equals a/b + {am/b} - {a(m+1)/b} in ℝ.
    This is the key identity for the Staircase Telescope. -/
lemma floor_step_eq_frac_diff (a b m : ℕ) (hb : 0 < b)
    (h_mono : a * m / b ≤ a * (m + 1) / b) :
    ((a * (m + 1) / b - a * m / b : ℕ) : ℝ) =
    (a : ℝ) / (b : ℝ) +
    Int.fract (((a * m : ℕ) : ℝ) / (b : ℝ)) -
    Int.fract (((a * (m + 1) : ℕ) : ℝ) / (b : ℝ)) := by
  have h1 := nat_div_cast_eq a (m + 1) b
  have h2 := nat_div_cast_eq a m b
  have hb_ne : (b : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
  rw [Nat.cast_sub h_mono, h1, h2]
  -- a*(m+1)/b - a*m/b = a/b in ℝ
  have h_diff : ((a * (m + 1) : ℕ) : ℝ) / (b : ℝ) - ((a * m : ℕ) : ℝ) / (b : ℝ) =
      (a : ℝ) / (b : ℝ) := by
    rw [show ((a * (m + 1) : ℕ) : ℝ) = ((a * m : ℕ) : ℝ) + (a : ℝ) from by push_cast; ring]
    field_simp; ring
  linarith

-- ════════════════════════════════════════════════
-- §4. USEFUL COROLLARIES
-- ════════════════════════════════════════════════

/-- Fract is 0 iff b divides a*m. -/
lemma int_fract_eq_zero_iff (a m b : ℕ) (hb : 0 < b) :
    Int.fract (((a * m : ℕ) : ℝ) / (b : ℝ)) = 0 ↔ b ∣ a * m := by
  rw [int_fract_eq_nat_mod_div a m b]
  have hb_ne : (b : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
  constructor
  · intro h
    have h1 : ((a * m % b : ℕ) : ℝ) = 0 := by
      by_contra hne
      have hpos : (0 : ℝ) < ((a * m % b : ℕ) : ℝ) :=
        Nat.cast_pos.mpr (Nat.pos_of_ne_zero (by exact_mod_cast hne))
      exact (div_ne_zero (ne_of_gt hpos) hb_ne) h
    exact Nat.dvd_of_mod_eq_zero (by exact_mod_cast h1)
  · intro ⟨k, hk⟩
    rw [hk, Nat.mul_mod_right, Nat.cast_zero, zero_div]

-- ════════════════════════════════════════════════
-- AUDIT — ALL PROVED, 0 sorry ✅
-- ════════════════════════════════════════════════
-- ✅ int_floor_eq_nat_div — ⌊↑(am)/↑b⌋ = ↑(a*m/b : ℕ)
-- ✅ int_floor_eq_nat_div' — version with (a:ℝ)*(m:ℝ)
-- ✅ nat_div_cast_eq — ↑(a*m/b) = ↑(am)/↑b - {↑(am)/↑b}
-- ✅ int_fract_eq_nat_mod_div — {↑(am)/↑b} = ↑(am%b)/↑b
-- ✅ int_fract_eq_nat_mod_div' — version with (a:ℝ)*(m:ℝ)
-- ✅ floor_step_eq_frac_diff — J(m) = a/b + {am/b} - {a(m+1)/b}
-- ✅ int_fract_eq_zero_iff — {↑(am)/↑b} = 0 ↔ b ∣ am

end Cathedral.Analysis.FloorFract
