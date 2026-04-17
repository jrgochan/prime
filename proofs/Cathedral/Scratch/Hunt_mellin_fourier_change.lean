import Cathedral.MellinBridge.Basic
import Cathedral.MellinBridge.HilbertSetup
import Cathedral.MellinBridge.MellinSieve
import Cathedral.Defs

set_option maxHeartbeats 200000

theorem mellin_fourier_change (N : ℕ) (hN : 2 ≤ N)
    (v : Fin (N - 1) → ℝ) (t : ℝ) : := by
  rfl
