/-
  Cathedral/Vasyunin/Cotangent/AlgebraicLimit.lean

  ## ALGEBRAIC LIMIT IDENTIFICATION — GRADUATED

  Provides: For coprime (a,b) with 1 ≤ a < b:

    gramIntegral a b = vasyuninGramFormula a b

  ### Architecture (UPDATED May 5, 2026 — AXIOM GRADUATED)

  The a≥2 case was previously an axiom (cycle-breaking stub).
  As of May 5, 2026, the import cycle has been confirmed to NOT EXIST:

    DeltaDirectEval does NOT import AlgebraicLimit or ConvergenceAxioms.
    TwoTileEval → TsumDirectEval → DeltaDirectEval — all axiom-free.
    Therefore AlgebraicLimit CAN import TwoTileEval without creating a cycle.

  Both cases are now PROVED:
    - a=1: From FractSeriesEval.gramIntegral_eq_formula_a1_axiomFree
    - a≥2: From TwoTileEval.gramIntegral_eq_formula_coprime (zero sorry)

  Created: May 2, 2026
  Updated: May 5, 2026 — AXIOM GRADUATED → THEOREM (zero sorry, zero axiom)
  Status: ZERO SORRY, ZERO AXIOM 🎓
-/

import Cathedral.Vasyunin.Cotangent.FractSeriesEval
import Cathedral.Vasyunin.Cotangent.TwoTileEval

noncomputable section
open Real MeasureTheory Filter

namespace Cathedral.Vasyunin.AlgebraicLimit

-- ════════════════════════════════════════════════
-- THE GRADUATED THEOREM (was axiom until May 5, 2026)
-- ════════════════════════════════════════════════

/-- **THEOREM** (GRADUATED May 5, 2026): The Vasyunin-Gram integral identity for a ≥ 2.

    For coprime a, b with 2 ≤ a < b:

    ∫₀¹ {1/(ax)}{1/(bx)} dx = vasyuninGramFormula(a,b)

    Previously an axiom (cycle-breaking stub). Now proved via:
      TwoTileEval.gramIntegral_eq_formula_coprime
    which uses DeltaDirectEval (zero-sorry) → TsumDirectEval → TwoTileEval.

    The import cycle was discovered to not exist: DeltaDirectEval does NOT
    import AlgebraicLimit or any file that depends on it. -/
theorem gramIntegral_eq_formula_ge2 (a b : ℕ) (ha : 2 ≤ a) (hb : 1 ≤ b)
    (hab : a < b) (hcop : Nat.Coprime a b) :
    Assembly.gramIntegral a b = DigammaReflection.vasyuninGramFormula a b :=
  TwoTileEval.gramIntegral_eq_formula_coprime a b (by omega) hb hab hcop

/-- **THEOREM**: The Vasyunin-Gram integral identity for all coprime (a,b).

    - a=1: PROVED from FractSeriesEval.gramIntegral_eq_formula_a1_axiomFree (zero sorry)
    - a≥2: PROVED from TwoTileEval.gramIntegral_eq_formula_coprime (zero sorry) -/
theorem gramIntegral_eq_formula_axiom (a b : ℕ) (ha : 1 ≤ a) (hb : 1 ≤ b)
    (hab : a < b) (hcop : Nat.Coprime a b) :
    Assembly.gramIntegral a b = DigammaReflection.vasyuninGramFormula a b := by
  rcases (show a = 1 ∨ 2 ≤ a from by omega) with rfl | ha2
  · exact FractSeriesEval.gramIntegral_eq_formula_a1_axiomFree b (show 2 ≤ b from by omega)
  · exact gramIntegral_eq_formula_ge2 a b ha2 hb hab hcop

-- ════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════
-- STATUS (May 5, 2026):
--   a=1 case: FULLY PROVED (zero sorry, zero axiom)
--   a≥2 case: FULLY PROVED (zero sorry, zero axiom) 🎓
--
-- GRADUATION HISTORY:
--   May 2, 2026: Created as sorry stub
--   May 3, 2026: Converted sorry → explicit axiom (cycle-breaking)
--   May 5, 2026: AXIOM → THEOREM 🎓
--     Import cycle confirmed nonexistent:
--     DeltaDirectEval does NOT import AlgebraicLimit.
--     TwoTileEval can be safely imported here.
--
-- IMPORT STRUCTURE (v2 — no cycle):
--   AlgebraicLimit imports {FractSeriesEval, TwoTileEval}
--   TwoTileEval → TsumDirectEval → DeltaDirectEval → {ColumnSumEval, ...}
--   None of these import AlgebraicLimit or ConvergenceAxioms.

end Cathedral.Vasyunin.AlgebraicLimit
