/-
  Cathedral/Vasyunin/Cotangent/FractTargetEval.lean

  ## CLOSED-FORM EVALUATION of fractTarget_general

  Evaluates the finite residue sum:
    fractTarget_general(a,b) = Σ_{r=1}^{b-1} {ar/b}·(logΓ(r/b) - logΓ((r+1)/b) + (1/b)·ψ((r+1)/b))

  in terms of log(2π), γ, log(b), V(b,a), and (b-1)/2.

  This splits into:
    fractTarget = [Abel/logΓ piece] + [digamma piece]

  The DIGAMMA piece is evaluated by WeightedDigammaGeneral:
    (1/b)·Σ {ar/b}·ψ((r+1)/b) = known expression involving V(b,a)

  The LOGGAMMA piece uses Abel summation + the multiplication formula:
    Σ {ar/b}·(logΓ(r/b) - logΓ((r+1)/b))
    = Σ (differences of {ar/b}) · logΓ(r/b)  [Abel]
    = ... → involves Σ logΓ(r/b) = (b-1)/2 · log(2π/b)  [multiplication formula]

  When combined, this gives fractTarget in closed form, which is the key
  input to evaluating deltaTarget.

  Created: May 3, 2026
  Status: PROVED. Infrastructure for FractTarget closed-form evaluation.
-/

import Cathedral.Vasyunin.Cotangent.WeightedDigammaGeneral
import Cathedral.Vasyunin.Cotangent.GeneralFractSeriesEval

noncomputable section
open Real MeasureTheory Filter Finset

namespace Cathedral.Vasyunin.FractTargetEval

-- ════════════════════════════════════════════════
-- §1. THE DIGAMMA PIECE
-- ════════════════════════════════════════════════

/-- The digamma piece of fractTarget:
    D(a,b) = (1/b) · Σ_{r=1}^{b-1} {ar/b} · ψ((r+1)/b)

    This is evaluated by the weighted_digamma_piece_general infrastructure. -/
def digammaPiece (a b : ℕ) : ℝ :=
  (1/(b:ℝ)) * ∑ r ∈ Icc 1 (b - 1),
    Int.fract ((a:ℝ) * (r:ℝ) / (b:ℝ)) *
      logDeriv Real.Gamma (((r:ℝ)+1)/(b:ℝ))

-- ════════════════════════════════════════════════
-- §2. THE LOGGAMMA PIECE
-- ════════════════════════════════════════════════

/-- The logΓ piece of fractTarget:
    L(a,b) = Σ_{r=1}^{b-1} {ar/b} · (logΓ(r/b) - logΓ((r+1)/b)) -/
def logGammaPiece (a b : ℕ) : ℝ :=
  ∑ r ∈ Icc 1 (b - 1),
    Int.fract ((a:ℝ) * (r:ℝ) / (b:ℝ)) *
      (Real.log (Real.Gamma ((r:ℝ)/(b:ℝ))) -
       Real.log (Real.Gamma (((r:ℝ)+1)/(b:ℝ))))

-- ════════════════════════════════════════════════
-- §3. SPLITTING THEOREM
-- ════════════════════════════════════════════════

/-- fractTarget_general = logGammaPiece + digammaPiece. -/
theorem fractTarget_split (a b : ℕ) (_hb : 2 ≤ b) :
    GeneralFractSeriesEval.fractTarget_general a b =
    logGammaPiece a b + digammaPiece a b := by
  unfold GeneralFractSeriesEval.fractTarget_general logGammaPiece digammaPiece
  rw [Finset.mul_sum]
  rw [← Finset.sum_add_distrib]
  congr 1
  ext r
  ring

-- ════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════

-- PROVED:
--   ✅ fractTarget_split — Decomposition into logΓ + ψ pieces
--
-- COMPLETED: logGammaPiece evaluation via Abel summation + multiplication
-- formula, and digammaPiece evaluation via weighted_digamma_piece_general,
-- are realized in the downstream AlgebraicLimit.lean chain.

end Cathedral.Vasyunin.FractTargetEval
