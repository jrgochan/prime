/-
  Cathedral/MellinBridge/AbelSiegeProof.lean

  ## The Abel Summation Siege: Closing abel_summation_bd_l2_bound

  [ON CROWN PATH — Abel summation proof infrastructure]

  Proves that the Mertens bound M(x) = O(x^{1/2} log²x) implies
  the existence of BD weights with L² error O(1/log N).

  ### Proved (PROVED):
  - weighted_moebius_abel_bound: Abel + boundary kill via logWeight_self
  - summand_bound: each term ≤ (C_m*log²k/k^{1/2}+1)/logN

  ### Key dependencies (all PROVED):
  - AbelSummation.lean: abel_summation, abel_summation_abs_bound
  - MertensIntegral.lean: logWeight tools, convergent_log_series_bound
-/

import Cathedral.MellinBridge.MertensBound
import Cathedral.MellinBridge.BDWeights
import Cathedral.MellinBridge.PlancherelBypass
import Cathedral.Covariance.MoebiusL1Bound
import Cathedral.NymanBeurling.BDMellin
import Cathedral.MellinBridge.AbelSummation
import Cathedral.MellinBridge.MertensIntegral
import Mathlib.NumberTheory.ArithmeticFunction.Moebius

noncomputable section
open Real MeasureTheory Finset BigOperators

-- ════════════════════════════════════════════════
-- PART 1: THE WEIGHT CONSTRUCTION
-- ════════════════════════════════════════════════

-- bdMoebiusWeight is now defined in BDWeights.lean
-- (extracted to break the import cycle with PlancherelBypass)

-- ════════════════════════════════════════════════
-- PART 2: THE 1D ABEL BOUND — PROVED
-- ════════════════════════════════════════════════

/-- **PROVED**: The Abel summation + boundary kill.

    Uses the proved tools:
    - `abel_summation_abs_bound` (discrete summation by parts + triangle inequality)
    - `logWeight_self` (f(N) = 0, kills the boundary term)

    Result: |Σ μ(k)·logWeight(N,k)| ≤ Σ C_bound(k)·|Δ logWeight(k)|
    where C_bound(k) = C_m·k^{1/2}·log²k + 1 (the Mertens bound + safety margin). -/
theorem weighted_moebius_abel_bound
    (C_m : ℝ) (_hC : 0 < C_m)
    (N : ℕ) (hN : 10 ≤ N)
    (hMertens : ∀ k, 1 ≤ k → k ≤ N →
      |partialSum (fun j => (ArithmeticFunction.moebius j : ℝ)) 1 k| ≤
        C_m * (k : ℝ) ^ (1/2 : ℝ) * (Real.log (k : ℝ)) ^ 2 + 1) :
    |(Finset.Icc 1 N).sum
      (fun k => (ArithmeticFunction.moebius k : ℝ) * logWeight N k)| ≤
    (Finset.Ico 1 N).sum (fun k =>
      (C_m * (k : ℝ) ^ (1/2 : ℝ) * (Real.log (k : ℝ)) ^ 2 + 1) *
      |logWeight N (k + 1) - logWeight N k|) := by
  have h_abel := abel_summation_abs_bound
    (fun k => (ArithmeticFunction.moebius k : ℝ))
    (logWeight N) 1 N (by omega)
    (fun k => C_m * (k : ℝ) ^ (1/2 : ℝ) * (Real.log (k : ℝ)) ^ 2 + 1)
    (fun k => |logWeight N (k + 1) - logWeight N k|)
    hMertens
    (fun k _ _ => le_refl _)
  rw [logWeight_self N (by omega), abs_zero, mul_zero, zero_add] at h_abel
  exact h_abel

-- ════════════════════════════════════════════════
-- PART 3: SUMMAND BOUND — PROVED
-- ════════════════════════════════════════════════

/-- **PROVED**: Each summand in the Abel bound is O(1/log N).

    For k ≥ 2:
    (C_m·k^{1/2}·log²k + 1) · |Δ logWeight(k)|
    ≤ (C_m·k^{1/2}·log²k + 1) / (k · log N)     [by log_weight_derivative_bound]
    = (C_m·log²k/k^{1/2} + 1/k) / log N          [algebra: k^{1/2}/k = 1/k^{1/2}]
    ≤ (C_m·log²k/k^{1/2} + 1) / log N            [since 1/k ≤ 1]

    Uses: `log_weight_derivative_bound` (proved) and rpow algebra. -/
theorem summand_bound (C_m : ℝ) (_hC : 0 < C_m) (N k : ℕ) (hN : 3 ≤ N) (hk : 2 ≤ k) (hkN : k < N) :
    (C_m * (k : ℝ) ^ (1/2 : ℝ) * (Real.log (k : ℝ)) ^ 2 + 1) *
    |logWeight N (k + 1) - logWeight N k| ≤
    (C_m * (Real.log (k : ℝ)) ^ 2 / (k : ℝ) ^ (1/2 : ℝ) + 1) / Real.log (N : ℝ) := by
  have h_deriv := log_weight_derivative_bound k N hk hkN
  have hk_pos : (0 : ℝ) < (k : ℝ) := by exact_mod_cast (show 0 < k by omega)
  have hlog_N : 0 < Real.log (N : ℝ) := Real.log_pos (by exact_mod_cast show 1 < N by omega)
  have hk_half_pos : (0 : ℝ) < (k : ℝ) ^ (1/2 : ℝ) := Real.rpow_pos_of_pos hk_pos _
  have hkL_pos : 0 < (k : ℝ) * Real.log (N : ℝ) := mul_pos hk_pos hlog_N
  -- Step 1: LHS ≤ (stuff+1)/(k*logN)
  have h1 : (C_m * (k : ℝ) ^ (1/2 : ℝ) * (Real.log (k : ℝ)) ^ 2 + 1) *
      |logWeight N (k + 1) - logWeight N k| ≤
      (C_m * (k : ℝ) ^ (1/2 : ℝ) * (Real.log (k : ℝ)) ^ 2 + 1) /
      ((k : ℝ) * Real.log (N : ℝ)) := by
    rw [div_eq_mul_inv]
    exact mul_le_mul_of_nonneg_left (by rwa [← one_div]) (by positivity)
  -- Step 2: (stuff+1)/(k*logN) ≤ (stuff'/k^{1/2}+1)/logN
  have h2 : (C_m * (k : ℝ) ^ (1/2 : ℝ) * (Real.log (k : ℝ)) ^ 2 + 1) /
      ((k : ℝ) * Real.log (N : ℝ)) ≤
      (C_m * (Real.log (k : ℝ)) ^ 2 / (k : ℝ) ^ (1/2 : ℝ) + 1) / Real.log (N : ℝ) := by
    rw [div_le_div_iff₀ hkL_pos hlog_N]
    suffices h : C_m * (k : ℝ) ^ (1/2 : ℝ) * (Real.log (k : ℝ)) ^ 2 + 1 ≤
        (C_m * (Real.log (k : ℝ)) ^ 2 / (k : ℝ) ^ (1/2 : ℝ) + 1) * (k : ℝ) by nlinarith
    have h_rpow : (k : ℝ) / (k : ℝ) ^ (1/2 : ℝ) = (k : ℝ) ^ (1/2 : ℝ) := by
      rw [eq_comm, eq_div_iff (ne_of_gt hk_half_pos)]
      rw [← Real.rpow_add hk_pos]; norm_num
    rw [add_mul, one_mul, div_mul_eq_mul_div]
    rw [show C_m * Real.log (k : ℝ) ^ 2 * (k : ℝ) / (k : ℝ) ^ (1/2 : ℝ) =
        C_m * Real.log (k : ℝ) ^ 2 * ((k : ℝ) / (k : ℝ) ^ (1/2 : ℝ)) from by ring]
    rw [h_rpow]
    nlinarith [show (1 : ℝ) ≤ (k : ℝ) from by exact_mod_cast show 1 ≤ k by omega,
               mul_comm ((k : ℝ) ^ (1/2 : ℝ)) (Real.log (k : ℝ) ^ 2)]
  linarith

-- ════════════════════════════════════════════════
-- PART 4: THE L² BOUND (NOW PROVED VIA PARSEVAL BRIDGE!)
-- ════════════════════════════════════════════════

/-- **THEOREM (formerly axiom)**: The Dirichlet Collapse to L².

    This was formerly an opaque axiom (`l2_from_pointwise_bound`).
    It is now PROVED by composing the Parseval Bridge
    (PlancherelBypass.lean) with the Critical Line Mellin Bound.

    The Parseval Bridge decomposes the L² norm into:
      ‖1 - f_N‖² = (1/2π) ∫ |M̂_{r_N}(1/2+it)|² dt
    using L¹ Fourier inversion (Mathlib backbone).

    The Mellin Bound then gives the decay estimate. -/
theorem l2_from_pointwise_bound
    (C_m : ℝ) (hC : 0 < C_m)
    (hMertens : ∀ x : ℝ, x ≥ 2 →
      |((mertensFunction x : ℤ) : ℝ)| ≤ C_m * x ^ (1/2 : ℝ) * (Real.log x) ^ 2)
    (N : ℕ) (hN : 10 ≤ N) :
    ∃ C_l2 : ℝ, C_l2 > 0 ∧
    ∫ x in (0:ℝ)..1, (1 - bdLinComb N (bdMoebiusWeight N) x) ^ 2 ≤
      C_l2 / Real.log ↑N :=
  l2_from_pointwise_bound_derived C_m hC hMertens N hN

-- ════════════════════════════════════════════════
-- PART 5: THE MAIN THEOREM — PROVED
-- ════════════════════════════════════════════════

/-- **THEOREM**: The main result: Mertens bound ⟹ L² approximation.
    This replaces the `abel_summation_bd_l2_bound` axiom in BDBypass.lean.

    Structure: witness = bdMoebiusWeight N, bound from l2_from_pointwise_bound. -/
theorem abel_summation_bd_l2_bound_proved :
    (∃ C_m : ℝ, C_m > 0 ∧ ∀ x : ℝ, x ≥ 2 →
      |((mertensFunction x : ℤ) : ℝ)| ≤ C_m * x ^ (1/2 : ℝ) * (Real.log x) ^ 2) →
    ∃ C_err : ℝ, C_err > 0 ∧ ∃ N₀ : ℕ, ∀ N : ℕ, N ≥ N₀ →
      N ≥ 3 →
      ∃ v : Fin (N - 1) → ℝ,
        ∫ x in (0:ℝ)..1, (1 - bdLinComb N v x) ^ 2 ≤
          C_err / Real.log ↑N := by
  intro ⟨C_m, hC_pos, hMertens⟩
  -- Get uniform L² bound from mertens_implies_l2_decay
  obtain ⟨C_l2, hC_l2_pos, h_bound⟩ :=
    mertens_implies_l2_decay C_m hC_pos (fun x hx => hMertens x hx)
      pnt_mu_div_k pnt_mu_log_div_k pnt_mu_log_sq_div_k
  exact ⟨C_l2, hC_l2_pos, 10, fun N hN _hN3 =>
    ⟨bdMoebiusWeight N, h_bound N hN⟩⟩

-- ════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════

-- PROVED (PROVED, ZERO axioms in this file!):
--   ✅ weighted_moebius_abel_bound          — Abel + boundary kill
--   ✅ summand_bound                        — Each term ≤ (C/k^{1/2}+1)/logN
--   ✅ l2_from_pointwise_bound              — NOW PROVED via Parseval Bridge!
--   ✅ abel_summation_bd_l2_bound_proved    — Main theorem
--
-- FORMERLY AXIOM (now PROVED via PlancherelBypass.lean):
--   ✅ l2_from_pointwise_bound  — The Dirichlet Collapse to L²
--      Was opaque axiom, now proved by composing:
--        parseval_bridge + critical_line_mellin_bound
