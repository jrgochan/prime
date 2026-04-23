/-
  Cathedral/Assembly/CalcBounds.lean

  ## Calculus Bounds for the Dot Product Assembly

  Contains the key calculus inequalities needed to convert
  N^{-1/4} decay rates to 1/logN rates.

  STATUS: 2 sorry (pure calculus — no number theory)
-/

import Mathlib.Analysis.SpecialFunctions.Log.Basic
import Mathlib.Analysis.SpecialFunctions.Pow.Real

noncomputable section
open Real

-- ════════════════════════════════════════════════
-- §1. KEY CALCULUS BOUNDS
-- ════════════════════════════════════════════════

/-- **Calculus Bound 1**: For N ≥ 10, ↑(N-1)^{-1/4} · log↑N ≤ 2.

    Proof sketch: logN / (N-1)^{1/4} ≤ logN / N^{1/4} · (N/(N-1))^{1/4}
    ≤ (4/e) · (10/9)^{1/4} ≤ 1.47 · 1.03 ≤ 2.

    The function t·e^{-t/4} achieves max 4/e at t=4 and decreases.
    For all N ≥ 1: logN / N^{1/4} ≤ 4/e < 1.48.
    So logN / (N-1)^{1/4} ≤ (N/(N-1))^{1/4} · 4/e ≤ (10/9)^{1/4} · 4/e < 2. -/
theorem rpow_quarter_logN_le_two (N : ℕ) (hN : 10 ≤ N) :
    (↑(N - 1) : ℝ) ^ (-(1:ℝ)/4) * Real.log ↑N ≤ 2 := by
  sorry

/-- **Calculus Bound 2**: For N ≥ 10, ↑(N-1)^{-1/4} · log↑(N-1) · log↑N ≤ 9.

    Proof sketch: log²N / (N-1)^{1/4} ≤ log²N / N^{1/4} · (N/(N-1))^{1/4}
    ≤ (4/e)² · (10/9)^{1/4} ≈ 8.66 · 1.03 ≈ 8.92 ≤ 9.

    Uses: t²·e^{-t/4} maximized at t=8, value 64/e² ≈ 8.66.
    And log(N-1) ≤ logN for N ≥ 2. -/
theorem rpow_quarter_logsq_le_nine (N : ℕ) (hN : 10 ≤ N) :
    (↑(N - 1) : ℝ) ^ (-(1:ℝ)/4) * Real.log (↑(N - 1) : ℝ) *
    Real.log ↑N ≤ 9 := by
  sorry

end
