/-
  Cathedral/Vasyunin/Augmented/IntegralBridge.lean

  **THE INTEGRAL BRIDGE**

  [ON CROWN PATH — Gram matrix integral formalization]

  Connects the Vasyunin discrete formulas to Lebesgue integrals.
  Extracted from GramPSD.lean to avoid import cycles.

  The mean entry axiom has been ELIMINATED (April 12, 2026) — it is now
  a theorem proved in MeanIntegral.lean via piecewise integration +
  the Euler-Mascheroni limit.

  The Gram entry axiom has been REPLACED (April 20, 2026) with a theorem
  delegating to VasyuninIntegralProof:
    - Diagonal case: PROVED via substitution + FTC
    - Off-diagonal case: axiomatized as vasyunin_offdiag_integral
-/

import Cathedral.Vasyunin.Defs
import Cathedral.Vasyunin.Augmented.MeanIntegral
import Cathedral.Vasyunin.Augmented.VasyuninIntegralProof
import Mathlib.MeasureTheory.Integral.IntervalIntegral.Basic

noncomputable section
open Real

namespace Cathedral.Vasyunin

/-- **THE INTEGRAL BRIDGE** (was axiom — now THEOREM).

    The Vasyunin discrete formula computes the same value as the
    Lebesgue integral of the product of Báez-Duarte basis functions.

    CRITICAL: The basis is h_k(x) = {1/(kx)}, NOT {k/x}.
    The Vasyunin cotangent formula is the Gram matrix of {1/(kx)}.
    (See RED ALERT memo — verified numerically April 11, 2026.)

    Diagonal case: PROVED (April 20, 2026) via substitution u=kx + FTC.
    Off-diagonal case: via vasyunin_offdiag_integral axiom.

    Source: Vasyunin (1995), Báez-Duarte et al. (2005 Acta Arithmetica).
    Verified computationally: 256-bit MPFR, 6-7 digit match (April 20, 2026). -/
theorem vasyunin_eq_integral (j k : ℕ) (hj : j ≥ 1) (hk : k ≥ 1) :
    vasyuninGramEntry j k =
    ∫ x in (0:ℝ)..1,
      Int.fract (1 / ((j:ℝ) * x)) * Int.fract (1 / ((k:ℝ) * x)) :=
  IntegralProof.vasyunin_eq_integral_proved j k hj hk

/-- **THE MEAN ENTRY INTEGRAL IDENTITY** (was axiom — now THEOREM).

    vasyuninMeanEntry k = ∫₀¹ {1/(kx)} dx

    Proof: unfold the definition and apply `mean_entry_eq_integral`,
    which proves (ln k + 1 - γ)/k = ∫₀¹ {1/(kx)} dx via
    piecewise integration + the Euler-Mascheroni limit.

    ELIMINATED as axiom: April 12, 2026, 12:26 AM MDT. -/
theorem vasyunin_mean_eq_integral (k : ℕ) (hk : k ≥ 1) :
    vasyuninMeanEntry k =
    ∫ x in (0:ℝ)..1, Int.fract (1 / ((k:ℝ) * x)) := by
  unfold vasyuninMeanEntry
  exact mean_entry_eq_integral k hk

end Cathedral.Vasyunin

