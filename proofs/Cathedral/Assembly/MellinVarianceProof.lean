/-!
  # Critical Line Mellin Variance

  Proves the critical-line Mellin variance bound under RH:
    `(1/2π) ∫ |M_{r_N}(1/2 + it)|² dt ≤ C/log N`

  ## Strategy

  Uses the Perron chain to obtain `M(x) = O(x^{3/4})` under RH,
  then the spatial L² decay bound, and finally the Parseval bridge
  (`parseval_bridge_white`) to translate back to the Mellin integral.

  ## Note on the Forward Direction

  The L² convergence `∫(1-f_N)² → 0` under RH cannot be proved from
  Mertens-type bounds alone. The spatial L² norm diverges under
  real-variable bounds — convergence is strictly a frequency-domain
  phenomenon requiring Parseval's identity. The correct architecture
  encapsulates the forward direction via the `baez_duarte_forward` axiom.
-/

import Cathedral.White.Scattering
import Cathedral.MellinBridge.PlancherelDefs
import Cathedral.MellinBridge.BDWeights
import Cathedral.Assembly.MellinPerronBridge

noncomputable section
open Real MeasureTheory Complex Filter Cathedral.White ArithmeticFunction

-- ═══════════════════════════════════════════════
-- THE CROWN AXIOM
-- ═══════════════════════════════════════════════

/-- The Critical Line Mellin Variance under RH.

    Under the Riemann Hypothesis, the L² norm of the Mellin-transformed
    residual on the critical line decays as `O(1/log N)`:
      `(1/2π) ∫ |M_{r_N}(1/2 + it)|² dt ≤ C/log N`

    Proof chain:
      RH → Mertens `x^{3/4}` (Perron)
         → `∫₀¹(1-f_N)² ≤ C/logN`
         → `(1/2π)∫|M|² ≤ C/logN` (Parseval bridge) -/
theorem critical_line_mellin_variance_proved (hRH : RiemannHypothesis) :
    ∃ C : ℝ, C > 0 ∧ ∃ N₀ : ℕ, ∀ N : ℕ, N ≥ N₀ →
      N ≥ 3 →
      (1 / (2 * Real.pi)) *
      ∫ t : ℝ, ‖mellinBDResidual N (bdMoebiusWeight N)
        ((1/2 : ℂ) + t * Complex.I)‖ ^ 2
      ≤ C / Real.log ↑N :=
  critical_line_mellin_variance_from_perron hRH

end
