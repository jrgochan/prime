import Cathedral.MellinBridge.MertensBound
import Cathedral.MellinBridge.BDWeights
import Cathedral.NymanBeurling.BDMellin
import Mathlib.Analysis.Fourier.Inversion

set_option maxHeartbeats 200000

theorem fourier_inv_autocorr (N : ℕ) (v : Fin (N - 1) → ℝ) :
    residualAutocorrelation N v 0 = := by
  push_cast; ring
