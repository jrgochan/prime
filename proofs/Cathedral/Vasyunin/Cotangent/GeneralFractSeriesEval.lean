/-
  Cathedral/Vasyunin/Cotangent/GeneralFractSeriesEval.lean

  ## THE GENERAL FRACT SERIES EVALUATION

  Generalizes the a=1 proof chain (FractSeriesEval.lean + DiagonalStrike.lean)
  to coprime (a,b) with a ≥ 1, b ≥ 2.

  ### Key Insight

  For general coprime (a,b), the rowTerm decomposition is:

    rowTerm(a,b,m) = (1/b) · stirlingTerm(m) + (1/a) · fractCorrection_general(a,b,m)

  where:
    stirlingTerm(m) = -2m · log((m+1)/m) + 2 - 1/(m+1)  — IDENTICAL to a=1
    fractCorrection_general(a,b,m) = {am/b} · (log((m+1)/m) - 1/(m+1))

  The ONLY difference from a=1 is replacing {m/b} with {am/b}.
  Since gcd(a,b) = 1, the map m ↦ am mod b is a PERMUTATION of {0,...,b-1},
  so the residue-class structure is identical — just with permuted labels.

  ### Phase 1 Contents

  §1. fractCorrection_general definition
  §2. rowTerm_decompose_general: the algebraic identity
  §3. Summability: fractCorrection_general is summable (comparison with 1/m²)
  §4. Tsum decomposition: tsum rowTerm = (1/b)·stirling_limit + tsum fract_general

  Created: May 2, 2026 (Phase 1 — The General Decomposition)
  Status: BUILDING
-/

import Cathedral.Vasyunin.Cotangent.DiagonalStrike
import Cathedral.Vasyunin.Cotangent.PartialSumConvergence

noncomputable section
open Real MeasureTheory Filter Finset

namespace Cathedral.Vasyunin.GeneralFractSeriesEval

-- ════════════════════════════════════════════════
-- §1. THE GENERAL FRACTIONAL CORRECTION
-- ════════════════════════════════════════════════

/-- The generalized fractional correction for coprime (a,b).

    fractCorrection_general(a,b,m) = {am/b} · (log((m+1)/m) - 1/(m+1))

    For a=1: {1·m/b} = {m/b}, recovering DiagonalStrike.fractCorrection.
    The factor {am/b} is periodic with period b (since gcd(a,b)=1,
    the map m ↦ am mod b permutes {0,...,b-1}). -/
def fractCorrection_general (a b m : ℕ) : ℝ :=
  Int.fract ((a:ℝ) * (m:ℝ) / (b:ℝ)) *
    (Real.log (((m:ℝ) + 1) / (m:ℝ)) - 1 / ((m:ℝ) + 1))

/-- For a=1, fractCorrection_general recovers DiagonalStrike.fractCorrection. -/
theorem fractCorrection_general_a1 (b m : ℕ) :
    fractCorrection_general 1 b m = DiagonalStrike.fractCorrection b m := by
  simp [fractCorrection_general, DiagonalStrike.fractCorrection, Nat.cast_one, one_mul]

-- ════════════════════════════════════════════════
-- §2. THE GENERAL ROW TERM DECOMPOSITION
-- ════════════════════════════════════════════════

/-- **PHASE 1 CORE**: rowTerm(a,b,m) = (1/b)·stirlingTerm(m) + (1/a)·fractCorrection_general(a,b,m)

    Proof: The tile index n = ⌊am/b⌋ = am/b - {am/b}.
    So n/a = m/b - {am/b}/a.

    rowTerm = 1/b - (n/a + m/b)·L + n/(a(m+1))
            = 1/b - (2m/b - {am/b}/a)·L + (m/b - {am/b}/a)/(m+1)
            = [1/b - (2m/b)·L + m/(b(m+1))]
              + ({am/b}/a)·[L - 1/(m+1)]
            = (1/b)·stirlingTerm(m) + (1/a)·fractCorrection_general(a,b,m)

    This is the fundamental algebraic identity that enables the entire
    generalization campaign. -/
theorem rowTerm_decompose_general (a b m : ℕ) (ha : 1 ≤ a) (hb : 1 ≤ b) (hm : 1 ≤ m) :
    PartialSumConvergence.rowTerm a b m =
    (1 / (b:ℝ)) * DiagonalStrike.stirlingTerm m +
    (1 / (a:ℝ)) * fractCorrection_general a b m := by
  unfold PartialSumConvergence.rowTerm DiagonalStrike.stirlingTerm fractCorrection_general
  -- Key setup
  have ha_pos : (0:ℝ) < (a:ℝ) := Nat.cast_pos.mpr (by omega)
  have ha_ne : (a:ℝ) ≠ 0 := ne_of_gt ha_pos
  have hb_pos : (0:ℝ) < (b:ℝ) := Nat.cast_pos.mpr (by omega)
  have hb_ne : (b:ℝ) ≠ 0 := ne_of_gt hb_pos
  have hm_pos : (0:ℝ) < (m:ℝ) := Nat.cast_pos.mpr (by omega)
  have hm_ne : (m:ℝ) ≠ 0 := ne_of_gt hm_pos
  -- Floor-fract identity: ↑⌊am/b⌋ = am/b - {am/b}
  -- (tileIndex a b m = (a*m)/b by definition)
  have h_floor : (↑(PartialSumConvergence.tileIndex a b m) : ℝ) =
      (a:ℝ) * (m:ℝ) / (b:ℝ) - Int.fract ((a:ℝ) * (m:ℝ) / (b:ℝ)) := by
    simp only [PartialSumConvergence.tileIndex]
    have h_nn : 0 ≤ (a:ℝ) * (m:ℝ) / (b:ℝ) := by positivity
    have h1 : Nat.floor ((a:ℝ) * (m:ℝ) / (b:ℝ)) = a * m / b := by
      rw [show (a:ℝ) * (m:ℝ) / (b:ℝ) = ((a * m : ℕ):ℝ) / ((b : ℕ):ℝ) from by push_cast; ring]
      exact Nat.floor_div_eq_div (a * m) b
    have h2 : (↑(a * m / b) : ℝ) = (↑(Nat.floor ((a:ℝ) * (m:ℝ) / (b:ℝ))) : ℝ) := by rw [h1]
    rw [h2, natCast_floor_eq_intCast_floor h_nn]
    linarith [Int.floor_add_fract ((a:ℝ) * (m:ℝ) / (b:ℝ))]
  -- Substitute the floor identity and simplify with field_simp + ring
  rw [h_floor]
  field_simp
  ring

-- ════════════════════════════════════════════════
-- §3. SUMMABILITY OF fractCorrection_general
-- ════════════════════════════════════════════════

/-- The log-reciprocal gap is nonneg: log((m+1)/m) - 1/(m+1) ≥ 0 for m ≥ 1.
    (Reuse from DiagonalStrike's log_gap_bound.) -/
private lemma log_gap_nonneg (m : ℕ) (hm : 1 ≤ m) :
    0 ≤ Real.log (((m:ℝ) + 1) / (m:ℝ)) - 1 / ((m:ℝ) + 1) := by
  have hm_pos : (0:ℝ) < (m:ℝ) := Nat.cast_pos.mpr (by omega)
  have h := one_sub_inv_le_log_of_pos (show (0:ℝ) < ((m:ℝ) + 1) / (m:ℝ) by positivity)
  rw [inv_div] at h
  linarith [show 1 - (m:ℝ) / ((m:ℝ) + 1) = 1 / ((m:ℝ) + 1) from by field_simp; ring]

/-- The log-reciprocal gap is bounded: log((m+1)/m) - 1/(m+1) ≤ 1/(m(m+1)). -/
private lemma log_gap_upper (m : ℕ) (hm : 1 ≤ m) :
    Real.log (((m:ℝ) + 1) / (m:ℝ)) - 1 / ((m:ℝ) + 1) ≤
    1 / ((m:ℝ) * ((m:ℝ) + 1)) := by
  have hm_pos : (0:ℝ) < (m:ℝ) := Nat.cast_pos.mpr (by omega)
  -- log((m+1)/m) ≤ 1/m (standard bound)
  have hL := log_le_sub_one_of_pos (show (0:ℝ) < ((m:ℝ) + 1) / (m:ℝ) by positivity)
  have h_simp : ((m:ℝ) + 1) / (m:ℝ) - 1 = 1 / (m:ℝ) := by field_simp; ring
  have hL_upper : Real.log (((m:ℝ) + 1) / (m:ℝ)) ≤ 1 / (m:ℝ) := by linarith
  linarith [show 1 / (m:ℝ) - 1 / ((m:ℝ) + 1) = 1 / ((m:ℝ) * ((m:ℝ) + 1)) from
    by field_simp; ring]

/-- **SUMMABILITY**: fractCorrection_general(a,b,n+1) is summable.

    Bound: |fractCorrection_general| ≤ 1/(m(m+1)) ≤ 1/m²
    since 0 ≤ {am/b} < 1 and 0 ≤ gap ≤ 1/(m(m+1)). -/
theorem fractCorrection_general_summable (a b : ℕ) (_ha : 1 ≤ a) (_hb : 2 ≤ b) :
    Summable (fun n : ℕ => fractCorrection_general a b (n + 1)) := by
  -- Dominator: 1/(n+1)²
  have h_dom : Summable (fun n : ℕ => (1:ℝ) / (↑(n + 1)) ^ 2) := by
    rw [show (fun n : ℕ => (1:ℝ) / (↑(n + 1)) ^ 2) =
        (fun n : ℕ => (fun m : ℕ => (1:ℝ) / (m:ℝ) ^ 2) (n + 1)) from by
      ext n; push_cast; ring_nf]
    exact (summable_nat_add_iff 1).mpr
      (summable_one_div_nat_pow.mpr (show 1 < 2 by norm_num))
  apply Summable.of_nonneg_of_le
  · -- fractCorrection_general ≥ 0: {am/b} ≥ 0 and gap ≥ 0
    intro n
    exact mul_nonneg (Int.fract_nonneg _) (log_gap_nonneg (n + 1) (by omega))
  · -- fractCorrection_general(n+1) ≤ 1/(n+1)²
    intro n
    simp only [fractCorrection_general]
    have h_fract_lt : Int.fract ((a:ℝ) * (↑(n+1)) / (b:ℝ)) < 1 := Int.fract_lt_one _
    have h_gap_upper := log_gap_upper (n + 1) (by omega)
    have h_gap_nonneg := log_gap_nonneg (n + 1) (by omega)
    calc Int.fract ((a:ℝ) * (↑(n+1)) / (b:ℝ)) *
          (Real.log ((↑(n+1) + 1) / ↑(n+1)) - 1 / (↑(n+1) + 1))
        ≤ 1 * (1 / (↑(n+1) * (↑(n+1) + 1))) :=
          mul_le_mul (le_of_lt h_fract_lt) h_gap_upper h_gap_nonneg (by norm_num)
      _ ≤ 1 / (↑(n + 1)) ^ 2 := by
          rw [one_mul]
          apply div_le_div_of_nonneg_left (by norm_num : (0:ℝ) ≤ 1) (by positivity)
          have : (0:ℝ) ≤ (n:ℝ) := Nat.cast_nonneg n
          push_cast; nlinarith
  · exact h_dom

-- ════════════════════════════════════════════════
-- §4. TSUM DECOMPOSITION
-- ════════════════════════════════════════════════

/-- **TSUM DECOMPOSITION**: The tsum of rowTerms splits into Stirling + fract pieces.

    Σ' rowTerm(a,b,n+1) = (1/b)·Σ' stirlingTerm(n+1) + (1/a)·Σ' fractCorrection_general(a,b,n+1)

    Uses rowTerm_decompose_general pointwise, plus summability of both pieces. -/
theorem tsum_rowTerm_decompose_general (a b : ℕ) (ha : 1 ≤ a) (hb : 2 ≤ b) :
    ∑' n, PartialSumConvergence.rowTerm a b (n + 1) =
    (1 / (b:ℝ)) * ∑' n, DiagonalStrike.stirlingTerm (n + 1) +
    (1 / (a:ℝ)) * ∑' n, fractCorrection_general a b (n + 1) := by
  have hS := DiagonalStrike.stirlingTerm_summable
  have hF := fractCorrection_general_summable a b ha hb
  have h_eq : ∀ n, PartialSumConvergence.rowTerm a b (n + 1) =
      (1 / (b:ℝ)) * DiagonalStrike.stirlingTerm (n + 1) +
               (1 / (a:ℝ)) * fractCorrection_general a b (n + 1) :=
    fun n => rowTerm_decompose_general a b (n + 1) ha (by omega) (by omega)
  calc ∑' n, PartialSumConvergence.rowTerm a b (n + 1)
      = ∑' n, ((1 / (b:ℝ)) * DiagonalStrike.stirlingTerm (n + 1) +
               (1 / (a:ℝ)) * fractCorrection_general a b (n + 1)) := tsum_congr h_eq
    _ = ∑' n, ((1 / (b:ℝ)) * DiagonalStrike.stirlingTerm (n + 1)) +
        ∑' n, ((1 / (a:ℝ)) * fractCorrection_general a b (n + 1)) :=
        Summable.tsum_add (hS.mul_left _) (hF.mul_left _)
    _ = _ := by rw [tsum_mul_left, tsum_mul_left]

/-- The tsum of rowTerms equals (1/b)·(log(2π)-γ-1) + (1/a)·Σ' fractCorrection_general.
    Uses stirlingTerm_hasSum from DiagonalStrike. -/
theorem tsum_rowTerm_eq_stirling_plus_fract_general (a b : ℕ) (ha : 1 ≤ a) (hb : 2 ≤ b) :
    ∑' n, PartialSumConvergence.rowTerm a b (n + 1) =
    (1 / (b:ℝ)) * (Real.log (2 * Real.pi) - eulerMascheroniConstant - 1) +
    (1 / (a:ℝ)) * ∑' n, fractCorrection_general a b (n + 1) := by
  rw [tsum_rowTerm_decompose_general a b ha hb]
  congr 1
  congr 1
  exact DiagonalStrike.stirlingTerm_hasSum.tsum_eq

-- ════════════════════════════════════════════════
-- §5. THE FRACT CORRECTION TARGET (for general a)
-- ════════════════════════════════════════════════

/-- The target value for the general fract correction series.
    If we can prove Σ' fractCorrection_general = fractTarget_general,
    then Σ' rowTerm = formula (modulo the two-tile correction). -/
def fractTarget_general (a b : ℕ) : ℝ :=
  (a:ℝ) * (DigammaReflection.vasyuninGramFormula a b -
    ((a:ℝ) - 1) / ((a:ℝ) * (b:ℝ)) -
    (1 / (b:ℝ)) * (Real.log (2 * Real.pi) - eulerMascheroniConstant - 1))

/-- If tsum fractCorrection_general = fractTarget_general, then
    strip + tsum rowTerm = formula.

    This assumes that actualRowIntegral = rowTerm for ALL rows
    (i.e., the two-tile correction is zero or handled separately). -/
theorem tsum_rowTerm_of_fract_target_general (a b : ℕ) (ha : 1 ≤ a) (hb : 2 ≤ b)
    (h : ∑' n, fractCorrection_general a b (n + 1) = fractTarget_general a b) :
    ((a:ℝ) - 1) / ((a:ℝ) * (b:ℝ)) +
    ∑' n, PartialSumConvergence.rowTerm a b (n + 1) =
    DigammaReflection.vasyuninGramFormula a b := by
  rw [tsum_rowTerm_eq_stirling_plus_fract_general a b ha hb, h]
  unfold fractTarget_general
  have ha_pos : (0:ℝ) < (a:ℝ) := Nat.cast_pos.mpr (by omega)
  have ha_ne : (a:ℝ) ≠ 0 := ne_of_gt ha_pos
  field_simp
  ring

-- ════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════

-- PROVED (zero sorry):
--   ✅ fractCorrection_general          — Definition
--   ✅ fractCorrection_general_a1       — Recovers a=1 case
--   ✅ rowTerm_decompose_general        — THE CORE IDENTITY (Phase 1)
--   ✅ fractCorrection_general_summable — Summability by comparison with 1/m²
--   ✅ tsum_rowTerm_decompose_general   — Tsum splits into Stirling + fract
--   ✅ tsum_rowTerm_eq_stirling_plus_fract_general — Stirling evaluated
--   ✅ tsum_rowTerm_of_fract_target_general — Reduction to fract target
--
-- ARCHITECTURE:
--   rowTerm(a,b,m) = (1/b)·stirlingTerm(m) + (1/a)·{am/b}·gap(m)
--   The Stirling piece is universal (a-independent) and already evaluated.
--   The fract piece requires Phases 3-4 for evaluation.
--   The two-tile correction (Phases 2+5) bridges actualRowIntegral ↔ rowTerm.

end Cathedral.Vasyunin.GeneralFractSeriesEval
