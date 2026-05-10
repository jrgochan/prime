/-
  Cathedral/Vasyunin/Cotangent/TwoTileCorrection.lean

  ## THE TWO-TILE CORRECTION — Phase 2 of Axiom Graduation

  For coprime (a,b) with a < b, some rows have TWO tiles where
  ⌊1/(bx)⌋ takes two distinct values. The "single-tile approximation"
  rowTerm(a,b,m) is wrong for these rows — the actual integral differs
  by a correction Δ(m).

  ### Key Results

  §1. twoTileCorrection definition:
      Δ(m) := actualRowIntegral(a,b,m) - rowTerm(a,b,m)

  §2. Single-tile rows: Δ(m) = 0
      Proved by applying IntegralEqSCombined.row_integral_eq_rowTerm_single.

  §3. Two-tile correction bound: |Δ(m)| ≤ C/m²
      Both actualRowIntegral and rowTerm are individually O(1/m²).

  §4. Summability: Σ |Δ(n+1)| converges (comparison with 1/m²).

  §5. Tsum decomposition:
      Σ' actualRowIntegral(n+1) = Σ' rowTerm(n+1) + Σ' Δ(n+1)

  Created: May 3, 2026 (Phase 2 — The Two-Tile Correction)
  Status: BUILDING
-/

import Cathedral.Vasyunin.Cotangent.PartialSumConvergence
import Cathedral.Vasyunin.Cotangent.IntegralEqSCombined
import Cathedral.Vasyunin.Cotangent.GramIntegralProof
import Cathedral.Vasyunin.Cotangent.GeneralFractSeriesEval

noncomputable section
open Real MeasureTheory Filter

namespace Cathedral.Vasyunin.TwoTileCorrection

-- ════════════════════════════════════════════════
-- §1. THE TWO-TILE CORRECTION FUNCTION
-- ════════════════════════════════════════════════

/-- The two-tile correction: the difference between the actual row integral
    and the single-tile approximation (rowTerm).

    Δ(a,b,m) := actualRowIntegral(a,b,m) - rowTerm(a,b,m)

    For single-tile rows: Δ = 0 (proved below).
    For two-tile rows: Δ ≠ 0 in general, but |Δ| = O(1/m²).

    There are exactly (a-1) two-tile rows per period of b rows
    (for coprime (a,b)), since the two-tile condition is:
      am mod b > b - a
    and exactly (a-1) residues in {0,...,b-1} satisfy this. -/
def twoTileCorrection (a b m : ℕ) : ℝ :=
  PartialSumConvergence.actualRowIntegral a b m -
  PartialSumConvergence.rowTerm a b m

-- ════════════════════════════════════════════════
-- §2. SINGLE-TILE ROWS: CORRECTION IS ZERO
-- ════════════════════════════════════════════════

/-- For a single-tile row, the correction is exactly zero.

    The single-tile condition is: a*(m+1) ≤ b*(tileIndex(a,b,m) + 1),
    meaning the entire row is covered by a single b-floor value.

    Proof: By IntegralEqSCombined.row_integral_eq_rowTerm_single,
    the actual row integral equals rowTerm for single-tile rows. -/
theorem twoTileCorrection_zero_of_single_tile (a b m : ℕ)
    (ha : 1 ≤ a) (hb : 1 ≤ b) (hm : 1 ≤ m) (hab : a < b)
    (h_single : a * (m + 1) ≤ b * (PartialSumConvergence.tileIndex a b m + 1)) :
    twoTileCorrection a b m = 0 := by
  unfold twoTileCorrection
  have h := IntegralEqSCombined.row_integral_eq_rowTerm_single a b m ha hb hm hab h_single
  -- h : ∫ ... = rowTerm, and actualRowIntegral = ∫ ...
  unfold PartialSumConvergence.actualRowIntegral at *
  linarith

-- ════════════════════════════════════════════════
-- §3. CORRECTION BOUND: |Δ(m)| ≤ C/m²
-- ════════════════════════════════════════════════

/-- **CORRECTION BOUND**: |Δ(a,b,m)| ≤ 1/(a·m²) + (a+b)/(ab·m²).

    Both actualRowIntegral(m) and rowTerm(m) are nonneg and O(1/m²):
    - actualRowIntegral ≤ 1/(a·m²)           [actualRowIntegral_le]
    - rowTerm ≤ (a+b)/(ab·m²)                [rowTerm_le_upper]
    - 0 ≤ actualRowIntegral                   [actualRowIntegral_nonneg]
    - 0 ≤ rowTerm                             [rowTerm_nonneg]

    Therefore |Δ| = |I - R| ≤ I + R (triangle inequality). -/
theorem twoTileCorrection_abs_le (a b m : ℕ)
    (ha : 1 ≤ a) (hb : 1 ≤ b) (hab : a < b) (hm : 1 ≤ m) :
    |twoTileCorrection a b m| ≤
    (1 / ((a:ℝ) * (m:ℝ) ^ 2)) + ((a:ℝ) + (b:ℝ)) / ((a:ℝ) * (b:ℝ)) / (m:ℝ) ^ 2 := by
  unfold twoTileCorrection
  -- Triangle inequality: |I - R| ≤ |I| + |R| = I + R (both nonneg)
  have hI_nn := PartialSumConvergence.actualRowIntegral_nonneg a b m ha hm
  have hR_nn := PartialSumConvergence.rowTerm_nonneg a b m ha hb hab hm
  have hI_le := PartialSumConvergence.actualRowIntegral_le a b m ha hm
  have hR_le := PartialSumConvergence.rowTerm_le_upper a b m ha hb hab hm
  calc |PartialSumConvergence.actualRowIntegral a b m -
         PartialSumConvergence.rowTerm a b m|
      ≤ |PartialSumConvergence.actualRowIntegral a b m| +
        |PartialSumConvergence.rowTerm a b m| := abs_sub _ _
    _ = PartialSumConvergence.actualRowIntegral a b m +
        PartialSumConvergence.rowTerm a b m := by
        rw [abs_of_nonneg hI_nn, abs_of_nonneg hR_nn]
    _ ≤ 1 / ((a:ℝ) * (m:ℝ) ^ 2) +
        ((a:ℝ) + (b:ℝ)) / ((a:ℝ) * (b:ℝ)) / (m:ℝ) ^ 2 := by linarith

-- ════════════════════════════════════════════════
-- §4. SUMMABILITY OF THE TWO-TILE CORRECTION
-- ════════════════════════════════════════════════

/-- Summability of rowTerm shifted by 1. -/
private theorem rowTerm_shifted_summable (a b : ℕ) (ha : 1 ≤ a) (hb : 1 ≤ b) (hab : a < b) :
    Summable (fun n : ℕ => PartialSumConvergence.rowTerm a b (n + 1)) := by
  set C := ((a:ℝ) + (b:ℝ)) / ((a:ℝ) * (b:ℝ)) with hC_def
  apply Summable.of_nonneg_of_le
  · intro n; exact PartialSumConvergence.rowTerm_nonneg a b (n+1) ha hb hab (by omega)
  · intro n
    calc PartialSumConvergence.rowTerm a b (n + 1)
        ≤ C / (↑(n + 1)) ^ 2 :=
          PartialSumConvergence.rowTerm_le_upper a b (n+1) ha hb hab (by omega)
      _ = C / ((n:ℝ) + 1) ^ 2 := by push_cast; ring_nf
  · have : Summable (fun n : ℕ => (1:ℝ) / ((n:ℝ) + 1) ^ 2) := by
      rw [show (fun n : ℕ => (1:ℝ) / ((n:ℝ) + 1) ^ 2) =
          (fun n : ℕ => (fun m : ℕ => (1:ℝ) / (m:ℝ) ^ 2) (n + 1)) from by
        ext n; push_cast; ring_nf]
      exact (summable_nat_add_iff 1).mpr
        (summable_one_div_nat_pow.mpr (show 1 < 2 by norm_num))
    convert this.mul_left C using 1
    ext n; ring

/-- **SUMMABILITY**: The two-tile correction series converges absolutely.

    Since actualRowIntegral(n+1) and rowTerm(n+1) are both summable,
    their difference twoTileCorrection(n+1) is summable. -/
theorem twoTileCorrection_summable (a b : ℕ) (ha : 1 ≤ a) (hb : 1 ≤ b) (hab : a < b) :
    Summable (fun n : ℕ => twoTileCorrection a b (n + 1)) := by
  -- Both components are summable, so their difference is summable
  have hI := GramIntegralProof.actualRowIntegral_summable a b ha hb
  have hR := rowTerm_shifted_summable a b ha hb hab
  show Summable (fun n => PartialSumConvergence.actualRowIntegral a b (n+1) -
    PartialSumConvergence.rowTerm a b (n+1))
  exact hI.sub hR

-- ════════════════════════════════════════════════
-- §5. TSUM DECOMPOSITION: ACTUAL = ROWTERM + CORRECTION
-- ════════════════════════════════════════════════

/-- **TSUM DECOMPOSITION**: The actual row integral series decomposes into
    the rowTerm series plus the two-tile correction series.

    Σ' actualRowIntegral(n+1) = Σ' rowTerm(n+1) + Σ' Δ(n+1)

    This is the key bridge: the left side appears in
    gramIntegral_eq_strip_plus_tsum (proved in GramIntegralProof),
    and the right side connects to the Stirling + fract decomposition
    (proved in GeneralFractSeriesEval). -/
theorem tsum_actualRowIntegral_eq_rowTerm_plus_correction
    (a b : ℕ) (ha : 1 ≤ a) (hb : 1 ≤ b) (hab : a < b) :
    ∑' n, PartialSumConvergence.actualRowIntegral a b (n + 1) =
    ∑' n, PartialSumConvergence.rowTerm a b (n + 1) +
    ∑' n, twoTileCorrection a b (n + 1) := by
  -- twoTileCorrection = actual - rowTerm, so actual = rowTerm + correction
  have h_eq : ∀ n, PartialSumConvergence.actualRowIntegral a b (n + 1) =
      PartialSumConvergence.rowTerm a b (n + 1) +
      twoTileCorrection a b (n + 1) := by
    intro n; unfold twoTileCorrection; ring
  conv_lhs => rw [show (fun n => PartialSumConvergence.actualRowIntegral a b (n + 1)) =
    (fun n => PartialSumConvergence.rowTerm a b (n + 1) +
              twoTileCorrection a b (n + 1)) from funext h_eq]
  -- Summability of both components
  have hR := rowTerm_shifted_summable a b ha hb hab
  have hΔ := twoTileCorrection_summable a b ha hb hab
  exact Summable.tsum_add hR hΔ

-- ════════════════════════════════════════════════
-- §6. THE MASTER EQUATION
-- ════════════════════════════════════════════════

/-- **THE MASTER EQUATION**: The tsum of actualRowIntegral decomposes into
    Stirling/b + fract/a + correction.

    Σ' actualRowIntegral(a,b,n+1) =
      (1/b) · (log(2π) - γ - 1) +
      (1/a) · Σ' fractCorrection_general(a,b,n+1) +
      Σ' twoTileCorrection(a,b,n+1)

    This combines:
    1. tsum_actualRowIntegral_eq_rowTerm_plus_correction (this file)
    2. tsum_rowTerm_eq_stirling_plus_fract_general (GeneralFractSeriesEval)

    Together with gramIntegral_eq_strip_plus_tsum (GramIntegralProof),
    which gives gramIntegral = strip + Σ' actualRowIntegral,
    this yields the full 4-way decomposition.

    **This reduces the axiom graduation to evaluating TWO convergent series:**
    - Σ' fractCorrection_general(a,b,n+1)  → via residue-class + digamma (Phase 3-4)
    - Σ' twoTileCorrection(a,b,n+1)        → via periodic structure (Phase 5) -/
theorem master_equation (a b : ℕ) (ha : 1 ≤ a) (hb : 1 ≤ b) (hab : a < b) :
    ∑' n, PartialSumConvergence.actualRowIntegral a b (n + 1) =
    (1 / (b:ℝ)) * (Real.log (2 * Real.pi) - eulerMascheroniConstant - 1) +
    (1 / (a:ℝ)) * ∑' n, GeneralFractSeriesEval.fractCorrection_general a b (n + 1) +
    ∑' n, twoTileCorrection a b (n + 1) := by
  -- Step 1: Σ' actual = Σ' rowTerm + Σ' Δ
  have h1 := tsum_actualRowIntegral_eq_rowTerm_plus_correction a b ha hb hab
  -- Step 2: Σ' rowTerm = (1/b)·stirling + (1/a)·Σ' fract
  have h2 := GeneralFractSeriesEval.tsum_rowTerm_eq_stirling_plus_fract_general
    a b ha (show 2 ≤ b from by omega)
  linarith

-- ════════════════════════════════════════════════
-- §7. THE a=1 CASE: CORRECTION VANISHES
-- ════════════════════════════════════════════════

/-- For a=1, ALL rows are single-tile (proved in DiagonalStrike.all_single_tile_a1),
    so the correction series is identically zero.

    This is consistent with the already-proved gramIntegral_eq_formula_a1_axiomFree
    in FractSeriesEval.lean, which needs no two-tile correction. -/
theorem twoTileCorrection_eq_zero_a1 (b m : ℕ) (hb : 2 ≤ b) (hm : 1 ≤ m) :
    twoTileCorrection 1 b m = 0 := by
  apply twoTileCorrection_zero_of_single_tile 1 b m (by omega) (by omega) hm (by omega)
  -- Need: 1 * (m + 1) ≤ b * (tileIndex 1 b m + 1)
  -- tileIndex 1 b m = (1*m)/b = m/b
  -- b * (m/b + 1) ≥ m + 1 for b ≥ 1
  simp only [PartialSumConvergence.tileIndex, one_mul]
  -- b * (m/b + 1) = b * (m/b) + b ≥ m + 1
  -- since b * (m / b) + m % b = m (Nat.div_add_mod)
  -- and m % b < b, so b * (m/b) ≥ m - (b-1) ≥ m - b + 1
  -- therefore b * (m/b + 1) = b * (m/b) + b ≥ m + 1
  have hdivmod := Nat.div_add_mod m b
  have hmod_lt := Nat.mod_lt m (show 0 < b by omega)
  -- b * (m/b) = m - m%b, so b * (m/b + 1) = m - m%b + b ≥ m + 1 since m%b < b
  nlinarith [Nat.mul_div_le m b]

/-- For a=1, the correction tsum is zero. -/
theorem tsum_twoTileCorrection_eq_zero_a1 (b : ℕ) (hb : 2 ≤ b) :
    ∑' n, twoTileCorrection 1 b (n + 1) = 0 := by
  have h_eq : ∀ n, twoTileCorrection 1 b (n + 1) = 0 :=
    fun n => twoTileCorrection_eq_zero_a1 b (n + 1) hb (by omega)
  simp [h_eq, tsum_zero]

-- ════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════

-- PROVED (FULLY PROVED):
--   ✅ twoTileCorrection                               — Definition
--   ✅ twoTileCorrection_zero_of_single_tile            — Δ = 0 for single-tile rows
--   ✅ twoTileCorrection_abs_le                         — |Δ| ≤ C/m² triangle bound
--   ✅ twoTileCorrection_summable                       — Σ |Δ(n+1)| converges
--   ✅ tsum_actualRowIntegral_eq_rowTerm_plus_correction — Σ' actual = Σ' rowTerm + Σ' Δ
--   ✅ master_equation                                  — gramIntegral = 4-way decomposition
--   ✅ twoTileCorrection_eq_zero_a1                     — Δ = 0 for a=1 (all single-tile)
--   ✅ tsum_twoTileCorrection_eq_zero_a1                — Σ' Δ = 0 for a=1
--
-- ARCHITECTURE:
--   This file provides the bridge between:
--     GramIntegralProof (gramIntegral = strip + Σ' actualRowIntegral)
--   and:
--     GeneralFractSeriesEval (Σ' rowTerm = Stirling/b + fract/a)
--
--   The remaining axiom graduation requires evaluating:
--     1. Σ' fractCorrection_general (Phases 3-4: residue + digamma)
--     2. Σ' twoTileCorrection (Phase 5: periodic evaluation)
--
--   Combined target:
--     strip + Stirling/b + fractEval/a + ΔEval = vasyuninGramFormula

end Cathedral.Vasyunin.TwoTileCorrection
