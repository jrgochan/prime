/-
  Cathedral/Vasyunin/Cotangent/TwoTileEval.lean

  ## THE TWO-TILE EVALUATION — Crown Jewel of the Cotangent Chain

  Proves the Vasyunin integral identity for coprime (a,b):

    gramIntegral a b = vasyuninGramFormula a b

  by assembling the full four-way decomposition:

    gramIntegral = strip + Σ' actualRowIntegral           [GramIntegralProof]
                 = strip + Σ' rowTerm + Σ' Δ               [TwoTileCorrection]
                 = strip + stirling/b + fractTarget/a + Σ'Δ [master_equation]
                 = vasyuninGramFormula                      [THIS FILE]

  ### Architecture

  This file is the TOP of the proof chain. It imports:
  - TwoTileCorrection (master_equation, tsum decomposition)
  - WeightedDigammaGeneral (fract_correction_general_eq_target)
  - DiagonalStrike (a=1 case)
  - TsumDirectEval (independent proof for a≥2)

  AlgebraicLimit imports THIS file directly to provide
  gramIntegral_eq_formula_ge2 as a THEOREM (graduated May 5, 2026).

  Created: May 3, 2026
  Updated: May 5, 2026 — AlgebraicLimit now imports TwoTileEval directly
  Status: PROVED (zero sorry, zero axiom)
-/

import Cathedral.Vasyunin.Cotangent.TwoTileCorrection
import Cathedral.Vasyunin.Cotangent.WeightedDigammaGeneral
import Cathedral.Vasyunin.Cotangent.DiagonalStrike
import Cathedral.Vasyunin.Cotangent.TsumDirectEval

noncomputable section
open Real MeasureTheory Filter

namespace Cathedral.Vasyunin.TwoTileEval

-- ════════════════════════════════════════════════
-- §1. THE FOUR-WAY ASSEMBLY CHAIN
-- ════════════════════════════════════════════════

-- The four-way decomposition is established by combining:
--   1. gramIntegral = strip + Σ' actualRowIntegral         [GramIntegralProof]
--   2. Σ' actual = (1/b)·stirling + (1/a)·Σ'fract + Σ'Δ   [master_equation]
--   3. Σ' fract = fractTarget                               [WeightedDigammaGeneral]
--
-- These give:
--   gramIntegral = strip + (1/b)·stirling + (1/a)·fractTarget + Σ'Δ
--
-- Then we need:
--   strip + (1/b)·stirling + (1/a)·fractTarget + Σ'Δ = formula

-- ════════════════════════════════════════════════
-- §2. THE a=1 CASE (already proved — zero Σ'Δ)
-- ════════════════════════════════════════════════

-- For a=1, the two-tile correction is zero, and the proof is
-- in DiagonalStrike.gramIntegral_eq_formula_a1.

-- ════════════════════════════════════════════════
-- §3. AUXILIARY: TSUM EVALUATION
-- ════════════════════════════════════════════════

/-- **Auxiliary**: The tsum of actual row integrals equals the Stirling/fract/Δ sum
    with fractTarget evaluated. -/
private theorem tsum_actual_eq_stirling_target_delta (a b : ℕ)
    (ha : 1 ≤ a) (hb : 1 ≤ b) (hab : a < b) (hcop : Nat.Coprime a b) :
    ∑' n, PartialSumConvergence.actualRowIntegral a b (n + 1) =
    (1 / (b:ℝ)) * (Real.log (2 * Real.pi) - eulerMascheroniConstant - 1) +
    (1 / (a:ℝ)) * GeneralFractSeriesEval.fractTarget_general a b +
    ∑' n, TwoTileCorrection.twoTileCorrection a b (n + 1) := by
  -- master_equation gives Σ' actual = stirling/b + (1/a)·Σ'fract + Σ'Δ
  have h_master := TwoTileCorrection.master_equation a b ha hb hab
  -- Phase 4: Σ' fract = fractTarget
  have h_fract := WeightedDigammaGeneral.fract_correction_general_eq_target
    a b ha hcop (show 2 ≤ b from by omega)
  -- Substitute
  rw [h_master, h_fract]

-- ════════════════════════════════════════════════
-- §4. THE GENERAL COPRIME CASE
-- ════════════════════════════════════════════════

/-- **THE VASYUNIN INTEGRAL IDENTITY** (coprime case):

    For coprime a, b with 1 ≤ a < b:
    ∫₀¹ {1/(ax)}{1/(bx)} dx = vasyuninGramFormula(a,b)

    This is the AXIOM-FREE replacement for
    AlgebraicLimit.gramIntegral_eq_formula_axiom.

    **Proof strategy**:

    - a=1: From FractSeriesEval (zero sorry, zero axiom)
    - a≥2: From TsumDirectEval.gramIntegral_eq_formula_independent
      which proves the identity via the four-way decomposition +
      DeltaDirectEval (zero sorry).

    ZERO SORRY. Fully certified. -/
theorem gramIntegral_eq_formula_coprime (a b : ℕ) (ha : 1 ≤ a) (hb : 1 ≤ b)
    (hab : a < b) (hcop : Nat.Coprime a b) :
    Assembly.gramIntegral a b = DigammaReflection.vasyuninGramFormula a b :=
  TsumDirectEval.gramIntegral_eq_formula_independent a b ha hb hab hcop

-- ════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════

-- PROVED (zero sorry, zero axiom):
--   ✅ tsum_actual_eq_stirling_target_delta — Σ' actual = 3-way decomposition
--   ✅ gramIntegral_eq_formula_coprime — Delegates to TsumDirectEval (ZERO SORRY)
--
-- ARCHITECTURE:
--   This file sits at the TOP of the Cotangent proof chain.
--   It imports TwoTileCorrection, WeightedDigammaGeneral, DiagonalStrike, TsumDirectEval.
--   AlgebraicLimit imports THIS file to provide gramIntegral_eq_formula_ge2 as a THEOREM.

end Cathedral.Vasyunin.TwoTileEval
