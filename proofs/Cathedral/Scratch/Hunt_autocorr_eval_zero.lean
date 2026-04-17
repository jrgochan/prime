import Cathedral.MellinBridge.MertensBound
import Cathedral.MellinBridge.BDWeights
import Cathedral.NymanBeurling.BDMellin
import Mathlib.Analysis.Fourier.Inversion

set_option maxHeartbeats 200000

theorem autocorr_eval_zero (N : ℕ) (v : Fin (N - 1) → ℝ) :
    residualAutocorrelation N v 0 = ∫ x in (0:ℝ)..1, (bdResidualV N v x) ^ 2 := by
  bound
