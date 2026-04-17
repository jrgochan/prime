import Cathedral.MellinBridge.MertensBound
import Cathedral.MellinBridge.BDWeights
import Cathedral.NymanBeurling.BDMellin
import Mathlib.Analysis.Fourier.Inversion

set_option maxHeartbeats 200000

theorem mellin_fourier_scale (N : ℕ) (v : Fin (N - 1) → ℝ) :
    ∫ ξ : ℝ, ‖∫ u : ℝ, flattenedResidualC N v u * := by
  exact?
