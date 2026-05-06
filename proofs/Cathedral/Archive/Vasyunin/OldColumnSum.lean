/-
  Cathedral/Archive/Vasyunin/OldColumnSum.lean

  ## ARCHIVED: Old Column-Sum Proof Path (Superseded May 5, 2026)

  This file contains the original cyclic proof path for the Vasyunin
  Gram identity, including `four_way_eq_formula` (with sorry) and
  `gramIntegral_eq_formula_column` (which delegated to it for a≥2).

  ### History

  The `four_way_eq_formula` theorem attempted to prove:
    strip + stir/b + ft/a + tsum Δ = vasyuninGramFormula
  by directly evaluating the delta tsum via per-class residue decomposition.

  This sorry was bypassed on May 5, 2026 by the DeltaDirectEval chain:
    DeltaDirectEval.four_way_eq_formula_independent (ZERO SORRY)
    → TsumDirectEval.gramIntegral_eq_formula_independent
    → TwoTileEval.gramIntegral_eq_formula_coprime

  The new chain uses the Beta Bijection (symmetric weighted digamma
  reflection) to evaluate tsum Δ algebraically without the circular
  dependency that plagued this original path.

  Archived: May 5, 2026 (Exploration 26 — The Great Refactoring)
  Superseded by: DeltaDirectEval.four_way_eq_formula_independent
-/

import Cathedral.Vasyunin.Cotangent.GramIntegralProof
import Cathedral.Vasyunin.Cotangent.TwoTileCorrection
import Cathedral.Vasyunin.Cotangent.WeightedDigammaGeneral
import Cathedral.Vasyunin.Cotangent.FractTargetEval
import Cathedral.Vasyunin.Cotangent.FractSeriesEval
import Cathedral.Vasyunin.Cotangent.DigammaReflection
import Cathedral.Vasyunin.Cotangent.ColumnSumEval

noncomputable section
open Real MeasureTheory Filter Finset

namespace Cathedral.Archive.Vasyunin.OldColumnSum

-- ════════════════════════════════════════════════
-- ARCHIVED: four_way_eq_formula (1 sorry)
-- ════════════════════════════════════════════════

/-- **ARCHIVED**: This theorem has a sorry on the OLD proof path.
    The independent proof is in DeltaDirectEval.four_way_eq_formula_independent (ZERO SORRY).

    PROOF STRUCTURE (when formalized):
      1. Evaluate ft via fractTarget_split + weighted_digamma_reflection_solve_general
      2. Evaluate tsum Δ via per-class residue decomposition + delta_class_limit_core
      3. Combine using Gauss multiplication + digamma reflection + cotangent sums -/
theorem four_way_eq_formula (a b : ℕ) (ha : 2 ≤ a) (hb : 2 ≤ b) (hab : a < b)
    (hcop : Nat.Coprime a b) :
    ((a:ℝ) - 1) / ((a:ℝ) * (b:ℝ)) +
    (1 / (b:ℝ)) * (Real.log (2 * Real.pi) - eulerMascheroniConstant - 1) +
    (1 / (a:ℝ)) * GeneralFractSeriesEval.fractTarget_general a b +
    ∑' n, TwoTileCorrection.twoTileCorrection a b (n + 1) =
    DigammaReflection.vasyuninGramFormula a b := by
  set deltaTarget := DigammaReflection.vasyuninGramFormula a b -
      ((a:ℝ) - 1) / ((a:ℝ) * (b:ℝ)) -
      (1 / (b:ℝ)) * (Real.log (2 * Real.pi) - eulerMascheroniConstant - 1) -
      (1 / (a:ℝ)) * GeneralFractSeriesEval.fractTarget_general a b
  suffices h_delta : ∑' n, TwoTileCorrection.twoTileCorrection a b (n + 1) = deltaTarget by
    rw [h_delta]; simp only [deltaTarget]; ring
  sorry

-- ════════════════════════════════════════════════
-- ARCHIVED: gramIntegral_eq_formula_column (delegates to sorry)
-- ════════════════════════════════════════════════

/-- **ARCHIVED**: The original column-sum proof of gramIntegral = formula.
    For a=1, this was sorry-free (delegated to FractSeriesEval).
    For a≥2, this delegated to four_way_eq_formula (1 sorry).

    SUPERSEDED by TwoTileEval.gramIntegral_eq_formula_coprime (zero sorry). -/
theorem gramIntegral_eq_formula_column (a b : ℕ) (ha : 1 ≤ a) (hb : 1 ≤ b)
    (hab : a < b) (hcop : Nat.Coprime a b) :
    Assembly.gramIntegral a b = DigammaReflection.vasyuninGramFormula a b := by
  by_cases ha1 : a = 1
  · subst ha1
    exact FractSeriesEval.gramIntegral_eq_formula_a1_axiomFree b (by omega)
  · have ha2 : 2 ≤ a := by omega
    have hb2 : 2 ≤ b := by omega
    have h_four := ColumnSumEval.gramIntegral_four_way a b ha2 hb hab hcop
    rw [h_four]
    exact four_way_eq_formula a b ha2 hb2 hab hcop

end Cathedral.Archive.Vasyunin.OldColumnSum
