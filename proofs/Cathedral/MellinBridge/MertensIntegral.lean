/-
  Cathedral/MellinBridge/MertensIntegral.lean

  ## Structural Tools for the Mertens Bridge

  NOTE (The Triangle Inequality Trap):
  The L² error d²_N = 1 - 2bᵀv + vᵀGv is a 2D geometric quantity.
  Bounding 1D coefficients via the triangle inequality destroys the
  cross-term cancellation, yielding O(N) instead of O(1/log N).
  The condition number κ(G_N) = Θ(N log N) is the gatekeeper.
  abel_summation_l2_bound remains as a justified axiom isolating
  the Mellin-Plancherel L² convergence rate.
-/

import Cathedral.Defs
import Mathlib.Analysis.SpecificLimits.Normed
import Mathlib.Topology.Algebra.InfiniteSum.Real

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
theorem logWeight_one (N : ℕ) (_hN : 2 ≤ N) : logWeight N 1 = 1 := by
  unfold logWeight
  simp [Real.log_one]

/-- **PROVED**: The discrete derivative bound: |f(k+1) - f(k)| ≤ 1/(k · log N).
    Uses the exponential characterization: log(1 + 1/k) ≤ 1/k. -/
theorem log_weight_derivative_bound (k N : ℕ) (hk : 2 ≤ k) (hkN : k < N) :
    |logWeight N (k + 1) - logWeight N k| ≤ 1 / ((k : ℝ) * Real.log (N : ℝ)) := by
  unfold logWeight
  have hk_pos : (0 : ℝ) < (k : ℝ) := Nat.cast_pos.mpr (by omega)
  have hN_gt1 : (1 : ℝ) < (N : ℝ) := by exact_mod_cast show 1 < N by omega
  have hlog_N_pos : 0 < Real.log (N : ℝ) := Real.log_pos hN_gt1
  have hk1_pos : (0 : ℝ) < ((k + 1 : ℕ) : ℝ) := Nat.cast_pos.mpr (by omega)
  have h1 : (1 : ℝ) - Real.log ((k + 1 : ℕ) : ℝ) / Real.log (N : ℝ) -
      (1 - Real.log (k : ℝ) / Real.log (N : ℝ)) =
      (Real.log (k : ℝ) - Real.log ((k + 1 : ℕ) : ℝ)) / Real.log (N : ℝ) := by ring
  rw [h1, abs_div, abs_of_pos hlog_N_pos]
  have h_le : Real.log (k : ℝ) ≤ Real.log ((k + 1 : ℕ) : ℝ) :=
    Real.log_le_log hk_pos (by exact_mod_cast show k ≤ k + 1 by omega)
  rw [abs_of_nonpos (by linarith), neg_sub]
  have h_eq : Real.log ((k + 1 : ℕ) : ℝ) - Real.log (k : ℝ) =
      Real.log (1 + 1 / (k : ℝ)) := by
    rw [← Real.log_div (ne_of_gt hk1_pos) (ne_of_gt hk_pos)]
    congr 1
    rw [show ((k + 1 : ℕ) : ℝ) = (k : ℝ) + 1 from by push_cast; ring]
    field_simp
  rw [h_eq]
  have h_bound : Real.log (1 + 1 / (k : ℝ)) ≤ 1 / (k : ℝ) := by
    rw [Real.log_le_iff_le_exp (by positivity)]
    linarith [Real.add_one_le_exp (1 / (k : ℝ))]
  rw [show 1 / ((k : ℝ) * Real.log (N : ℝ)) =
      (1 / (k : ℝ)) / Real.log (N : ℝ) from by field_simp]
  exact div_le_div_of_nonneg_right h_bound hlog_N_pos.le

-- ════════════════════════════════════════════════
-- PART II: CONVERGENT SERIES
-- ════════════════════════════════════════════════

/-- **PROVED**: The Convergent Series.
    Σ_{k=2}^N log²(k) / k^{3/2} ≤ C for all N.

    Proof uses log(k) ≤ 8·k^{1/8} (from log(x) ≤ x - 1 < x applied to
    x = k^{1/8}) and bounds by the convergent p-series Σ 64·k^{-5/4}. -/
theorem convergent_log_series_bound :
    ∃ C : ℝ, 0 < C ∧ ∀ N : ℕ, 2 ≤ N →
    (Finset.Ico 2 N).sum (fun k =>
      (Real.log (k : ℝ)) ^ 2 / ((k : ℝ) ^ (3/2 : ℝ))) ≤ C := by
  -- 1. The dominating p-series converges (p = -5/4 < -1)
  have h_summable : Summable (fun k : ℕ => 64 * (k : ℝ) ^ (-(5/4) : ℝ)) := by
    apply Summable.mul_left
    exact Real.summable_nat_rpow.mpr (by norm_num)
  -- 2. Set C to the infinite sum + 1
  set C_inf := ∑' (k : ℕ), 64 * (k : ℝ) ^ (-(5/4) : ℝ)
  use C_inf + 1
  refine ⟨?_, fun N _ => ?_⟩
  · -- Prove C > 0
    have h_nonneg : 0 ≤ C_inf := by
      apply tsum_nonneg
      intro n
      positivity
    linarith
  · -- Prove the partial sum is bounded by C
    have h_summand : ∀ k : ℕ, 2 ≤ k →
        (Real.log (k : ℝ)) ^ 2 / ((k : ℝ) ^ (3/2 : ℝ)) ≤ 64 * (k : ℝ) ^ (-(5/4) : ℝ) := by
      intro k hk
      have hk_pos : (0 : ℝ) < (k : ℝ) := by exact_mod_cast (show 0 < k by omega)
      -- log(k^{1/8}) ≤ k^{1/8}
      have hrpow_pos : (0 : ℝ) < (k : ℝ) ^ (1/8 : ℝ) := Real.rpow_pos_of_pos hk_pos _
      have h_log_bound : Real.log ((k : ℝ) ^ (1/8 : ℝ)) ≤ (k : ℝ) ^ (1/8 : ℝ) := by
        have := Real.log_le_sub_one_of_pos hrpow_pos
        linarith
      -- (1/8) log k ≤ k^{1/8}
      have h_log_rpow : Real.log ((k : ℝ) ^ (1/8 : ℝ)) = (1/8 : ℝ) * Real.log (k : ℝ) :=
        Real.log_rpow hk_pos (1/8 : ℝ)
      rw [h_log_rpow] at h_log_bound
      -- log k ≤ 8 * k^{1/8}
      have h_log_le : Real.log (k : ℝ) ≤ 8 * (k : ℝ) ^ (1/8 : ℝ) := by linarith
      -- square both sides
      have h_sq : (Real.log (k : ℝ)) ^ 2 ≤ 64 * (k : ℝ) ^ (1/4 : ℝ) := by
        have h_log_nn : 0 ≤ Real.log (k : ℝ) := Real.log_nonneg (by
          exact_mod_cast show 1 ≤ k by omega)
        have h_pow := pow_le_pow_left₀ h_log_nn h_log_le 2
        calc (Real.log (k : ℝ)) ^ 2
          _ ≤ (8 * (k : ℝ) ^ (1/8 : ℝ)) ^ 2 := h_pow
          _ = 64 * (((k : ℝ) ^ (1/8 : ℝ)) ^ 2) := by ring
          _ = 64 * (k : ℝ) ^ (1/4 : ℝ) := by
            congr 1
            rw [← Real.rpow_natCast ((k : ℝ) ^ (1/8 : ℝ)) 2,
                ← Real.rpow_mul hk_pos.le]
            norm_num
      -- divide by k^{3/2}
      have hk32_pos : (0 : ℝ) < (k : ℝ) ^ (3/2 : ℝ) := Real.rpow_pos_of_pos hk_pos _
      rw [div_le_iff₀ hk32_pos]
      calc (Real.log (k : ℝ)) ^ 2
        _ ≤ 64 * (k : ℝ) ^ (1/4 : ℝ) := h_sq
        _ = 64 * ((k : ℝ) ^ (-(5/4) : ℝ) * (k : ℝ) ^ (3/2 : ℝ)) := by
            congr 2
            rw [← Real.rpow_add hk_pos]
            congr 1
            norm_num
        _ = 64 * (k : ℝ) ^ (-(5/4) : ℝ) * (k : ℝ) ^ (3/2 : ℝ) := by ring
    -- Telescope the summation bound
    calc (Finset.Ico 2 N).sum (fun k => (Real.log (k : ℝ)) ^ 2 / ((k : ℝ) ^ (3/2 : ℝ)))
      _ ≤ (Finset.Ico 2 N).sum (fun k => 64 * (k : ℝ) ^ (-(5/4) : ℝ)) := by
          apply Finset.sum_le_sum
          intro k hk
          rw [Finset.mem_Ico] at hk
          exact h_summand k hk.1
      _ ≤ C_inf := by
          exact h_summable.sum_le_tsum _ (fun n _ => by positivity)
      _ ≤ C_inf + 1 := by linarith

-- ════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════

-- ZERO SORRY in this file!
--
--   ✅ logWeight                       — Definition
--   ✅ logWeight_self                  — f(N) = 0
--   ✅ logWeight_one                   — f(1) = 1
--   ✅ log_weight_derivative_bound     — |Δf| ≤ 1/(k·log N)
--   ✅ convergent_log_series_bound     — Σ log²k/k^{3/2} ≤ C

end
