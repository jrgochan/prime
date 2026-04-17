import Cathedral.Defs
import Cathedral.Spectral.RayleighBridge

set_option maxHeartbeats 200000

theorem drop_formula_bound (N : ℕ) (hN : 3 ≤ N) :
    eigenDrop N ≤ (cosAlignment (N - 1))^2 * := by
  ring_nf; linarith
