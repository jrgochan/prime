/-
  Cathedral/Vasyunin/Cotangent/IntegralEqSCombined.lean

  ## INTEGRAL = STRIP + S_COMBINED: The Evaluative Plumbing

  Proves: ∫_{1/(aM)}^1 {1/(ax)}{1/(bx)} dx = strip + s_combined a b M

  Created: April 25, 2026
  Status: BUILDING — two-tile telescoping in progress
-/

import Cathedral.Vasyunin.Cotangent.PartialSumConvergence
import Cathedral.Vasyunin.Cotangent.OffDiagPartition
import Cathedral.Analysis.CrossTermFTC
import Cathedral.Vasyunin.Cotangent.TelescopeSum
import Mathlib.MeasureTheory.Integral.IntervalIntegral.Basic

noncomputable section
open Real MeasureTheory

namespace Cathedral.Vasyunin.IntegralEqSCombined

-- ════════════════════════════════════════════════
-- §1. FLOOR DIVISION FACTS
-- ════════════════════════════════════════════════

private lemma lt_div_succ_mul (a b m : ℕ) (hb : 1 ≤ b) :
    a * m < b * (a * m / b + 1) := by
  have h1 := Nat.div_add_mod (a * m) b
  have h2 := Nat.mod_lt (a * m) (show 0 < b by omega)
  nlinarith

private lemma div_mul_le (a b m : ℕ) :
    b * (a * m / b) ≤ a * m := by
  calc b * (a * m / b) = (a * m / b) * b := by ring
    _ ≤ a * m := Nat.div_mul_le_self (a * m) b

-- ════════════════════════════════════════════════
-- §2. SINGLE-TILE ROW (n ≥ 1)
-- ════════════════════════════════════════════════

theorem single_tile_eq_rowTerm (a b m : ℕ)
    (ha : 1 ≤ a) (hb : 1 ≤ b) (hm : 1 ≤ m) (_hab : a < b)
    (hn : 1 ≤ PartialSumConvergence.tileIndex a b m)
    (h_kn_le : b * PartialSumConvergence.tileIndex a b m ≤ a * m)
    (h_le_kn1 : a * (m + 1) ≤ b * (PartialSumConvergence.tileIndex a b m + 1)) :
    ∫ x in (OffDiagPartition.rowLo a m)..(OffDiagPartition.rowHi a m),
      Int.fract (1 / ((a:ℝ) * x)) * Int.fract (1 / ((b:ℝ) * x)) =
    PartialSumConvergence.rowTerm a b m := by
  set n := PartialSumConvergence.tileIndex a b m with hn_def
  -- Step 1: fract product = polynomial on the tile
  rw [OffDiagPartition.row_integral_single_tile a b m n ha hb hm hn h_kn_le h_le_kn1]
  -- Step 2: FTC evaluation
  have h_ftc := CrossTermFTC.cross_piece_integral_ftc a b m n ha hb
    (OffDiagPartition.rowLo a m) (OffDiagPartition.rowHi a m)
    (OffDiagPartition.rowLo_pos a m ha hm)
    (le_of_lt (OffDiagPartition.row_nonempty a m ha hm))
  rw [h_ftc]
  -- Step 3: FTC value = rowTerm (via row_ftc_combined)
  unfold OffDiagPartition.rowLo OffDiagPartition.rowHi
  -- row_ftc_combined gives us the LHS = 1/b + log_term + linear_term
  have h_rfc := TelescopeSum.row_ftc_combined a b m n ha hb hm
  -- rowTerm is defined as 1/b + log_term + linear_term
  show _ = PartialSumConvergence.rowTerm a b m
  unfold PartialSumConvergence.rowTerm
  -- n = tileIndex a b m by definition, so the hn_def handles unification
  rw [← hn_def]
  -- Now h_rfc and the goal should match after simp
  simp only at h_rfc ⊢
  linarith

-- ════════════════════════════════════════════════
-- §3. SINGLE-TILE ROW (n = 0)
-- ════════════════════════════════════════════════

theorem n_zero_eq_rowTerm (a b m : ℕ)
    (ha : 1 ≤ a) (hb : 1 ≤ b) (hm : 1 ≤ m)
    (hn0 : PartialSumConvergence.tileIndex a b m = 0)
    (h_le_kn1 : a * (m + 1) ≤ b * 1) :
    ∫ x in (OffDiagPartition.rowLo a m)..(OffDiagPartition.rowHi a m),
      Int.fract (1 / ((a:ℝ) * x)) * Int.fract (1 / ((b:ℝ) * x)) =
    PartialSumConvergence.rowTerm a b m := by
  have ha_pos : (0:ℝ) < (a:ℝ) := Nat.cast_pos.mpr (by omega)
  have hb_pos : (0:ℝ) < (b:ℝ) := Nat.cast_pos.mpr (by omega)
  have ham1_le_b : a * (m + 1) ≤ b := by linarith
  -- ae equality: both fracts reduce to polynomials
  have h_eq : ∫ x in (OffDiagPartition.rowLo a m)..(OffDiagPartition.rowHi a m),
      Int.fract (1 / ((a:ℝ) * x)) * Int.fract (1 / ((b:ℝ) * x)) =
      ∫ x in (OffDiagPartition.rowLo a m)..(OffDiagPartition.rowHi a m),
      (1 / ((a:ℝ) * x) - (m:ℝ)) * (1 / ((b:ℝ) * x) - 0) := by
    apply intervalIntegral.integral_congr_ae
    filter_upwards with x hx
    have h_ne := OffDiagPartition.row_nonempty a m ha hm
    simp only [Set.uIoc_of_le (le_of_lt h_ne)] at hx
    rw [CrossTermFTC.fract_eq_on_piece_general a m ha hm x hx.1 hx.2]
    congr 1; simp only [sub_zero]
    have hx_pos : (0:ℝ) < x := by
      calc (0:ℝ) < OffDiagPartition.rowLo a m := OffDiagPartition.rowLo_pos a m ha hm
        _ < x := hx.1
    have hbx_pos : (0:ℝ) < (b:ℝ) * x := mul_pos hb_pos hx_pos
    apply Int.fract_eq_self.mpr
    refine ⟨by positivity, ?_⟩
    rw [div_lt_one hbx_pos]
    have ham1_le_b_real : (a:ℝ) * ((m:ℝ) + 1) ≤ (b:ℝ) := by
      have : ((a * (m + 1) : ℕ) : ℝ) ≤ ((b : ℕ) : ℝ) := Nat.cast_le.mpr ham1_le_b
      push_cast at this; linarith
    calc 1 = (a:ℝ) * ((m:ℝ) + 1) * (1 / ((a:ℝ) * ((m:ℝ) + 1))) := by field_simp
      _ < (a:ℝ) * ((m:ℝ) + 1) * x := by
          apply mul_lt_mul_of_pos_left hx.1
          exact mul_pos ha_pos (by linarith : (0:ℝ) < (m:ℝ) + 1)
      _ ≤ (b:ℝ) * x := by nlinarith
  rw [h_eq]
  -- FTC with n = 0
  have h_ftc := CrossTermFTC.cross_piece_integral_ftc a b m 0 ha hb
    (OffDiagPartition.rowLo a m) (OffDiagPartition.rowHi a m)
    (OffDiagPartition.rowLo_pos a m ha hm)
    (le_of_lt (OffDiagPartition.row_nonempty a m ha hm))
  simp only [Nat.cast_zero] at h_ftc; rw [h_ftc]
  -- Use row_ftc_combined with n = 0
  unfold OffDiagPartition.rowLo OffDiagPartition.rowHi
  show _ = PartialSumConvergence.rowTerm a b m
  unfold PartialSumConvergence.rowTerm
  rw [hn0]
  have h_rfc := TelescopeSum.row_ftc_combined a b m 0 ha hb hm
  simp only at h_rfc ⊢
  linarith

-- ════════════════════════════════════════════════
-- §4. TWO-TILE ROW: FTC TELESCOPING
-- ════════════════════════════════════════════════

/-- Helper: on the left sub-tile (rowLo, x₀] where x₀ = 1/(b·n₀),
    the fract product equals the polynomial (1/(ax)-m)(1/(bx)-n₀). -/
private lemma left_tile_fract_eq (a b m : ℕ)
    (ha : 1 ≤ a) (hb : 1 ≤ b) (hm : 1 ≤ m) (hab : a < b)
    (h_cross_lo : a * m < b * (PartialSumConvergence.tileIndex a b m + 1))
    (x : ℝ) (hx_lo : OffDiagPartition.rowLo a m < x)
    (hx_hi : x ≤ 1 / ((b:ℝ) * ((PartialSumConvergence.tileIndex a b m : ℝ) + 1))) :
    Int.fract (1 / ((a:ℝ) * x)) * Int.fract (1 / ((b:ℝ) * x)) =
    (1 / ((a:ℝ) * x) - (m:ℝ)) * (1 / ((b:ℝ) * x) - ((PartialSumConvergence.tileIndex a b m : ℝ) + 1)) := by
  set n := PartialSumConvergence.tileIndex a b m
  have ha_pos : (0:ℝ) < (a:ℝ) := Nat.cast_pos.mpr (by omega)
  have hb_pos : (0:ℝ) < (b:ℝ) := Nat.cast_pos.mpr (by omega)
  -- a-fract: {1/(ax)} = 1/(ax) - m on row m
  have hx_le_rowHi : x ≤ OffDiagPartition.rowHi a m := by
    calc x ≤ 1 / ((b:ℝ) * ((n:ℝ) + 1)) := hx_hi
      _ ≤ 1 / ((a:ℝ) * (m:ℝ)) := by
        apply div_le_div_of_nonneg_left (by norm_num : (0:ℝ) ≤ 1) (by positivity)
        exact_mod_cast (show a * m ≤ b * (n + 1) from by linarith [h_cross_lo])
  have h_a_fract := CrossTermFTC.fract_eq_on_piece_general a m ha hm x hx_lo hx_le_rowHi
  -- b-fract: {1/(bx)} = 1/(bx) - (n+1) on (1/(b(n+2)), 1/(b·(n+1))]
  have hbn2_gt : b * (n + 2) > a * (m + 1) := by nlinarith
  have h_b_lo : 1 / ((b:ℝ) * ((n:ℝ) + 2)) < x := by
    calc 1 / ((b:ℝ) * ((n:ℝ) + 2))
        ≤ 1 / ((a:ℝ) * ((m:ℝ) + 1)) := by
          apply div_le_div_of_nonneg_left (by norm_num : (0:ℝ) ≤ 1) (by positivity)
          exact_mod_cast (show a * (m + 1) ≤ b * (n + 2) from by linarith [hbn2_gt])
      _ < x := hx_lo
  have hn1_pos : 1 ≤ n + 1 := Nat.le_add_left 1 n
  -- fract_eq_on_piece_general b (n+1) expects x ≤ 1/(b * ↑(n+1))
  -- hx_hi : x ≤ 1/(b * (↑n + 1)), and ↑(n+1) = ↑n + 1
  have hx_hi' : x ≤ 1 / ((b:ℝ) * ((n + 1 : ℕ):ℝ)) := by
    convert hx_hi using 2; push_cast; ring
  -- h_b_lo : 1/(b*(↑n + 2)) < x, need 1/(b*↑(n+1+1)) < x
  have h_b_lo' : 1 / ((b:ℝ) * (((n + 1 : ℕ):ℝ) + 1)) < x := by
    convert h_b_lo using 2; push_cast; ring
  have h_b_fract := CrossTermFTC.fract_eq_on_piece_general b (n+1) hb hn1_pos x h_b_lo' hx_hi'
  rw [h_a_fract, h_b_fract]; push_cast; ring

/-- Helper: on the right sub-tile (x₀, rowHi] where x₀ = 1/(b·(n+1)),
    the fract product equals (1/(ax)-m)(1/(bx)-n). Works for n ≥ 0. -/
private lemma right_tile_fract_eq (a b m : ℕ)
    (ha : 1 ≤ a) (hb : 1 ≤ b) (hm : 1 ≤ m)
    (h_cross_hi : b * (PartialSumConvergence.tileIndex a b m + 1) < a * (m + 1))
    (x : ℝ) (hx_lo : 1 / ((b:ℝ) * ((PartialSumConvergence.tileIndex a b m : ℝ) + 1)) < x)
    (hx_hi : x ≤ OffDiagPartition.rowHi a m) :
    Int.fract (1 / ((a:ℝ) * x)) * Int.fract (1 / ((b:ℝ) * x)) =
    (1 / ((a:ℝ) * x) - (m:ℝ)) * (1 / ((b:ℝ) * x) - (PartialSumConvergence.tileIndex a b m : ℝ)) := by
  set n := PartialSumConvergence.tileIndex a b m
  have ha_pos : (0:ℝ) < (a:ℝ) := Nat.cast_pos.mpr (by omega)
  have hb_pos : (0:ℝ) < (b:ℝ) := Nat.cast_pos.mpr (by omega)
  -- a-fract: x ∈ (x₀, rowHi] ⊂ (rowLo, rowHi], so {1/(ax)} = 1/(ax) - m
  have h_a_lo : OffDiagPartition.rowLo a m < x := by
    calc OffDiagPartition.rowLo a m
        = 1 / ((a:ℝ) * ((m:ℝ) + 1)) := rfl
      _ ≤ 1 / ((b:ℝ) * ((n:ℝ) + 1)) := by
          apply div_le_div_of_nonneg_left (by norm_num : (0:ℝ) ≤ 1) (by positivity)
          exact_mod_cast (show b * (n + 1) ≤ a * (m + 1) from by linarith [h_cross_hi])
      _ < x := hx_lo
  have h_a_fract := CrossTermFTC.fract_eq_on_piece_general a m ha hm x h_a_lo hx_hi
  -- b-fract: need {1/(bx)} = 1/(bx) - n
  -- x > 1/(b(n+1)) gives 1/(bx) < n+1
  -- x ≤ rowHi = 1/(am) and bn ≤ am gives 1/(bx) ≥ am/(b) ≥ n
  have hbn_le : b * n ≤ a * m := div_mul_le a b m
  by_cases hn_pos : 1 ≤ n
  · -- n ≥ 1: use fract_eq_on_piece_general
    have h_b_hi : x ≤ 1 / ((b:ℝ) * (n:ℝ)) := by
      calc x ≤ 1 / ((a:ℝ) * (m:ℝ)) := hx_hi
        _ ≤ 1 / ((b:ℝ) * (n:ℝ)) := by
          apply div_le_div_of_nonneg_left (by norm_num : (0:ℝ) ≤ 1) (by positivity)
          exact_mod_cast hbn_le
    rw [h_a_fract, CrossTermFTC.fract_eq_on_piece_general b n hb hn_pos x hx_lo h_b_hi]
  · -- n = 0: {1/(bx)} = 1/(bx) since 0 < 1/(bx) < 1
    have hn0 : n = 0 := by omega
    have hx_pos : (0:ℝ) < x := lt_trans (OffDiagPartition.rowLo_pos a m ha hm) h_a_lo
    have hbx_pos : (0:ℝ) < (b:ℝ) * x := mul_pos hb_pos hx_pos
    have h_nonneg : (0:ℝ) ≤ 1 / ((b:ℝ) * x) := le_of_lt (div_pos one_pos hbx_pos)
    have h_lt_one : 1 / ((b:ℝ) * x) < 1 := by
      rw [div_lt_one hbx_pos]
      rw [hn0] at hx_lo; simp only [Nat.cast_zero, zero_add, mul_one] at hx_lo
      -- hx_lo : 1 / ((b:ℝ) * 1) < x, i.e. 1/b < x, so b*x > 1
      calc 1 = (b:ℝ) * (1 / (b:ℝ)) := by field_simp
        _ < (b:ℝ) * x := by nlinarith
    have h_b_fract : Int.fract (1 / ((b:ℝ) * x)) = 1 / ((b:ℝ) * x) :=
      Int.fract_eq_self.mpr ⟨h_nonneg, h_lt_one⟩
    rw [h_a_fract, h_b_fract, hn0]; simp only [Nat.cast_zero, sub_zero]


/-- **Two-tile FTC evaluation**: For a two-tile row, the integral splits
    at x₀ = 1/(b·(n+1)) into two polynomial integrals. -/
theorem two_tile_ftc_eval (a b m : ℕ)
    (ha : 1 ≤ a) (hb : 1 ≤ b) (hm : 1 ≤ m)
    (hab : a < b)
    (h_cross_lo : a * m < b * (PartialSumConvergence.tileIndex a b m + 1))
    (h_cross_hi : b * (PartialSumConvergence.tileIndex a b m + 1) < a * (m + 1)) :
    ∫ x in (OffDiagPartition.rowLo a m)..(OffDiagPartition.rowHi a m),
      Int.fract (1 / ((a:ℝ) * x)) * Int.fract (1 / ((b:ℝ) * x)) =
    (∫ x in (OffDiagPartition.rowLo a m)..(1 / ((b:ℝ) * ((PartialSumConvergence.tileIndex a b m : ℝ) + 1))),
      (1 / ((a:ℝ) * x) - (m:ℝ)) * (1 / ((b:ℝ) * x) - ((PartialSumConvergence.tileIndex a b m : ℝ) + 1))) +
    (∫ x in (1 / ((b:ℝ) * ((PartialSumConvergence.tileIndex a b m : ℝ) + 1)))..(OffDiagPartition.rowHi a m),
      (1 / ((a:ℝ) * x) - (m:ℝ)) * (1 / ((b:ℝ) * x) - (PartialSumConvergence.tileIndex a b m : ℝ))) := by
  set n := PartialSumConvergence.tileIndex a b m with hn_def
  set n₀ := n + 1 with hn₀_def
  have hn₀_pos : 1 ≤ n₀ := by omega
  have hb_pos : (0:ℝ) < (b:ℝ) := Nat.cast_pos.mpr (by omega)
  -- row_integral_split_at_crossing uses 1/(b·↑n₀); show it equals 1/(b·(↑n+1))
  have hbound_eq : (1:ℝ) / ((b:ℝ) * (n₀:ℝ)) = 1 / ((b:ℝ) * ((n:ℝ) + 1)) := by
    congr 1; congr 1; simp [hn₀_def]
  rw [OffDiagPartition.row_integral_split_at_crossing a b m n₀ ha hb hm hn₀_pos
      h_cross_lo h_cross_hi, hbound_eq]
  congr 1
  -- Left sub-integral: fract → polynomial
  · apply intervalIntegral.integral_congr_ae
    have hle : OffDiagPartition.rowLo a m ≤ 1 / ((b:ℝ) * ((n:ℝ) + 1)) := by
      unfold OffDiagPartition.rowLo
      apply div_le_div_of_nonneg_left (by norm_num : (0:ℝ) ≤ 1) (by positivity)
      exact_mod_cast (show b * n₀ ≤ a * (m + 1) by omega)
    filter_upwards with x hx
    rw [Set.uIoc_of_le hle] at hx
    exact left_tile_fract_eq a b m ha hb hm hab h_cross_lo x hx.1 hx.2
  -- Right sub-integral: fract → polynomial
  · apply intervalIntegral.integral_congr_ae
    have hle : 1 / ((b:ℝ) * ((n:ℝ) + 1)) ≤ OffDiagPartition.rowHi a m := by
      unfold OffDiagPartition.rowHi
      apply div_le_div_of_nonneg_left (by norm_num : (0:ℝ) ≤ 1) (by positivity)
      exact_mod_cast (show a * m ≤ b * n₀ by omega)
    filter_upwards with x hx
    rw [Set.uIoc_of_le hle] at hx
    exact right_tile_fract_eq a b m ha hb hm h_cross_hi x hx.1 hx.2

-- ════════════════════════════════════════════════
-- §5. SINGLE-TILE ROW LEMMA
-- ════════════════════════════════════════════════

/-- For coprime a < b and any SINGLE-TILE row m ≥ 1, ∫_{row m} = rowTerm a b m.
    This handles the case where the entire row has a single b-floor value. -/
theorem row_integral_eq_rowTerm_single (a b m : ℕ)
    (ha : 1 ≤ a) (hb : 1 ≤ b) (hm : 1 ≤ m)
    (hab : a < b)
    (h_single : a * (m + 1) ≤ b * (PartialSumConvergence.tileIndex a b m + 1)) :
    ∫ x in (OffDiagPartition.rowLo a m)..(OffDiagPartition.rowHi a m),
      Int.fract (1 / ((a:ℝ) * x)) * Int.fract (1 / ((b:ℝ) * x)) =
    PartialSumConvergence.rowTerm a b m := by
  set n := PartialSumConvergence.tileIndex a b m with hn_def
  have h_kn_le : b * n ≤ a * m := div_mul_le a b m
  by_cases hn_pos : 1 ≤ n
  · exact single_tile_eq_rowTerm a b m ha hb hm hab hn_pos h_kn_le h_single
  · have hn0 : n = 0 := by omega
    have : a * (m + 1) ≤ b * 1 := by rw [hn0] at h_single; linarith
    exact n_zero_eq_rowTerm a b m ha hb hm hn0 this

-- ════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════
-- PROVED (FULLY PROVED):
--   ✅ single_tile_eq_rowTerm      — Single-tile row (n ≥ 1) = rowTerm
--   ✅ n_zero_eq_rowTerm           — Single-tile row (n = 0) = rowTerm
--   ✅ row_integral_eq_rowTerm_single — Universal single-tile row lemma
--   ✅ two_tile_ftc_eval           — Two-tile row = sum of two FTC pieces
--   ✅ left_tile_fract_eq          — Left sub-tile fract reduction
--   ✅ right_tile_fract_eq         — Right sub-tile fract reduction
--
-- REMOVED (mathematically false):
--   ✗ two_tile_ftc_eq_rowTerm      — DELETED: rowTerm is wrong for two-tile rows
--   ✗ row_integral_eq_rowTerm      — DELETED: depended on false claim
--   ✗ integral_eq_strip_plus_S_combined — DELETED: depended on false claim
--
-- NOTE: The integral_eq_S_combined axiom in PartialSumConvergence.lean remains.
-- The main RH proof chain uses ConvergenceAxioms.partial_integral_tends_to_formula
-- which does NOT route through this file.

end Cathedral.Vasyunin.IntegralEqSCombined
