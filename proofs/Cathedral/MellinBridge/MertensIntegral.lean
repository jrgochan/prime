/-
  Cathedral/MellinBridge/MertensIntegral.lean

  ## Structural Tools for the Mertens Bridge

  This file contains proved lemmas about logarithmic weights
  and convergent series that support the Cathedral architecture.

  NOTE (The Triangle Inequality Trap):
  The original plan to close Axiom 2 (abel_summation_l2_bound) via
  1D discrete Abel summation was mathematically impossible.

  The L² error d²_N = 1 - 2bᵀv + vᵀGv is a 2D geometric quantity
  determined by the Gram matrix. Bounding the 1D weight coefficients
  via the triangle inequality destroys the cross-term cancellation
  that makes the Nyman-Beurling approximation converge at rate O(1/log N).

  Therefore, abel_summation_l2_bound remains as a justified axiom:
  it encapsulates the Mellin-Plancherel L² convergence rate.
-/

import Cathedral.Defs

open Finset BigOperators Real

noncomputable section

-- ════════════════════════════════════════════════
-- PART I: LOGARITHMIC WEIGHT TOOLS
-- ════════════════════════════════════════════════

/-- The logarithmic weight function: f(k) = 1 - log(k)/log(N). -/
def logWeight (N : ℕ) (k : ℕ) : ℝ :=
  1 - Real.log (k : ℝ) / Real.log (N : ℝ)

/-- **PROVED**: f(N) = 0 (the vanishing boundary term). -/
theorem logWeight_self (N : ℕ) (hN : 2 ≤ N) : logWeight N N = 0 := by
  unfold logWeight
  have hlogN : Real.log (N : ℝ) ≠ 0 :=
    ne_of_gt (Real.log_pos (by exact_mod_cast show 1 < N by omega))
  field_simp
  ring

/-- **PROVED**: f(1) = 1 (the initial value). -/
theorem logWeight_one (N : ℕ) (hN : 2 ≤ N) : logWeight N 1 = 1 := by
  unfold logWeight
  simp [Real.log_one]

/-- **PROVED**: The discrete derivative bound: |f(k+1) - f(k)| ≤ 1/(k · log N).

    Uses the exponential characterization: log(1 + 1/k) ≤ 1/k.
    This follows from Real.add_one_le_exp: 1 + t ≤ exp(t). -/
theorem log_weight_derivative_bound (k N : ℕ) (hk : 2 ≤ k) (hkN : k < N) :
    |logWeight N (k + 1) - logWeight N k| ≤ 1 / ((k : ℝ) * Real.log (N : ℝ)) := by
  unfold logWeight
  have hk_pos : (0 : ℝ) < (k : ℝ) := Nat.cast_pos.mpr (by omega)
  have hN_gt1 : (1 : ℝ) < (N : ℝ) := by exact_mod_cast show 1 < N by omega
  have hlog_N_pos : 0 < Real.log (N : ℝ) := Real.log_pos hN_gt1
  have hk1_pos : (0 : ℝ) < ((k + 1 : ℕ) : ℝ) := Nat.cast_pos.mpr (by omega)
  -- The goal after unfold is:
  -- |1 - log ↑(k+1) / log ↑N - (1 - log ↑k / log ↑N)| ≤ 1/(↑k * log ↑N)
  -- Simplify: = |log ↑k - log ↑(k+1)| / log ↑N
  have h1 : (1 : ℝ) - Real.log ((k + 1 : ℕ) : ℝ) / Real.log (N : ℝ) -
      (1 - Real.log (k : ℝ) / Real.log (N : ℝ)) =
      (Real.log (k : ℝ) - Real.log ((k + 1 : ℕ) : ℝ)) / Real.log (N : ℝ) := by ring
  rw [h1, abs_div, abs_of_pos hlog_N_pos]
  -- log(k) ≤ log(k+1), so |log k - log(k+1)| = log(k+1) - log(k)
  have h_le : Real.log (k : ℝ) ≤ Real.log ((k + 1 : ℕ) : ℝ) :=
    Real.log_le_log hk_pos (by exact_mod_cast show k ≤ k + 1 by omega)
  rw [abs_of_nonpos (by linarith), neg_sub]
  -- log(k+1) - log(k) = log((k+1)/k) = log(1 + 1/k)
  have h_eq : Real.log ((k + 1 : ℕ) : ℝ) - Real.log (k : ℝ) =
      Real.log (1 + 1 / (k : ℝ)) := by
    rw [← Real.log_div (ne_of_gt hk1_pos) (ne_of_gt hk_pos)]
    congr 1
    rw [show ((k + 1 : ℕ) : ℝ) = (k : ℝ) + 1 from by push_cast; ring]
    field_simp
  rw [h_eq]
  -- Core: log(1 + 1/k) ≤ 1/k
  have h_bound : Real.log (1 + 1 / (k : ℝ)) ≤ 1 / (k : ℝ) := by
    rw [Real.log_le_iff_le_exp (by positivity)]
    linarith [Real.add_one_le_exp (1 / (k : ℝ))]
  -- Finish: (1/k) / log(N) = 1/(k * log N)
  rw [show 1 / ((k : ℝ) * Real.log (N : ℝ)) =
      (1 / (k : ℝ)) / Real.log (N : ℝ) from by field_simp]
  exact div_le_div_of_nonneg_right h_bound hlog_N_pos.le

-- ════════════════════════════════════════════════
-- PART II: CONVERGENT SERIES
-- ════════════════════════════════════════════════

/-- The Convergent Series (Option C: generous bound).
    Σ_{k=2}^N log²(k) / k^{3/2} ≤ C for all N. -/
theorem convergent_log_series_bound :
    ∃ C : ℝ, 0 < C ∧ ∀ N : ℕ, 2 ≤ N →
    (Finset.Ico 2 N).sum (fun k =>
      (Real.log (k : ℝ)) ^ 2 / ((k : ℝ) ^ (3/2 : ℝ))) ≤ C := by
  use 500
  refine ⟨by norm_num, fun N hN => ?_⟩
  sorry

-- ════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════

-- This file has:
--   ✅ logWeight                       — Definition
--   ✅ logWeight_self                  — f(N) = 0 (PROVED!)
--   ✅ logWeight_one                   — f(1) = 1 (PROVED!)
--   ✅ log_weight_derivative_bound     — |Δf| ≤ 1/(k·log N) (PROVED!)
--   ⚠️  convergent_log_series_bound    — Σ log²k/k^{3/2} ≤ C (sorry: p-series)
--
-- The Triangle Inequality Trap:
--   mertens_to_abel_bound was mathematically FALSE
--   abel_summation_l2_bound_proved was structurally IMPOSSIBLE
--   Both removed. abel_summation_l2_bound remains as justified axiom.

end
