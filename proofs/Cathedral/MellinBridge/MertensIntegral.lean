/-
  Cathedral/MellinBridge/MertensIntegral.lean

  ## The Final Sprint: Continuous Bounding Lemmas for Axiom 2

  This file contains the continuous analysis lemmas needed to close
  `abel_summation_l2_bound` in MertensWeightBypass.lean.

  Once these are proved, Axiom 2 falls and the Cathedral drops to ONE axiom.

  The chain:
    1. log_weight_derivative_bound: |f(k+1) - f(k)| ≤ 1/(k·log N)
       This gives us `δ(k)` for abel_summation_abs_bound.

    2. mertens_partial_sum_bound: |Σ_{j=2}^k μ(j)/j| ≤ C_m · log²k / √k
       This gives us `C_bound(k)` for abel_summation_abs_bound.

    3. convergent_series_bound: Σ_{k=2}^N log²k / k^{3/2} ≤ C
       The summability that kills the 1/log(N) factor.

    4. axiom2_closure: The full assembly closing abel_summation_l2_bound.
-/

import Cathedral.Defs
import Cathedral.MellinBridge.AbelSummation
import Cathedral.MellinBridge.MertensWeightBypass

open Finset BigOperators Real

noncomputable section

-- ════════════════════════════════════════════════
-- PART I: THE DISCRETE DERIVATIVE BOUND
-- ════════════════════════════════════════════════

/-- The logarithmic weight function: f(k) = 1 - log(k)/log(N). -/
def logWeight (N : ℕ) (k : ℕ) : ℝ :=
  1 - Real.log (k : ℝ) / Real.log (N : ℝ)

/-- Key property: f(N) = 0 (the vanishing boundary term). -/
theorem logWeight_self (N : ℕ) (hN : 2 ≤ N) : logWeight N N = 0 := by
  unfold logWeight
  have hN_pos : (0 : ℝ) < (N : ℝ) := by positivity
  have hlogN : Real.log (N : ℝ) ≠ 0 := by
    apply ne_of_gt
    apply Real.log_pos
    exact_mod_cast show 1 < N by omega
  field_simp
  ring

/-- **The Discrete Derivative Bound.**

    |f(k+1) - f(k)| = |log(k+1) - log(k)| / log(N)
                     = log(1 + 1/k) / log(N)
                     ≤ (1/k) / log(N)
                     = 1 / (k · log N)

    This provides the `δ(k)` input for `abel_summation_abs_bound`. -/
theorem log_weight_derivative_bound (k N : ℕ) (hk : 2 ≤ k) (hkN : k < N) :
    |logWeight N (k + 1) - logWeight N k| ≤ 1 / ((k : ℝ) * Real.log (N : ℝ)) := by
  unfold logWeight
  -- Simplify: |(1 - log(k+1)/logN) - (1 - log(k)/logN)|
  --         = |log(k)/logN - log(k+1)/logN|
  --         = |log(k) - log(k+1)| / log(N)
  --         = (log(k+1) - log(k)) / log(N)    [since log is increasing]
  --         = log(1 + 1/k) / log(N)
  --         ≤ (1/k) / log(N)
  sorry

-- ════════════════════════════════════════════════
-- PART II: MERTENS PARTIAL SUM → ABEL BOUND
-- ════════════════════════════════════════════════

/-- The partial Möbius sum: A(k) = Σ_{j=2}^k μ(j)/j.

    When the Mertens bound |M(x)| ≤ C√x·log²x holds, partial summation gives:
    |A(k)| = |Σ_{j≤k} μ(j)/j| ≤ C · log²(k) / √k

    This provides the `C_bound(k)` input for `abel_summation_abs_bound`. -/
theorem mertens_to_abel_bound
    (C_m : ℝ) (hC : 0 < C_m)
    (hM : ∀ x : ℝ, 2 ≤ x → |mertensFunction x| ≤ C_m * x ^ (1/2 : ℝ) * (Real.log x) ^ 2)
    (k : ℕ) (hk : 2 ≤ k) :
    |partialSum (fun j => (ArithmeticFunction.moebius j : ℝ) / (j : ℝ)) 2 k| ≤
    C_m * (Real.log (k : ℝ)) ^ 2 / Real.sqrt (k : ℝ) := by
  -- This follows from the Mertens bound via partial summation.
  -- |Σ_{j=2}^k μ(j)/j| = |M(k)/k + ∫_2^k M(t)/t² dt|   [Abel summation]
  --                      ≤ C_m·√k·log²k/k + C_m·∫_2^k √t·log²t/t² dt
  --                      = C_m·log²k/√k + O(log²k/√k)
  --                      ≤ C'·log²k/√k
  sorry

-- ════════════════════════════════════════════════
-- PART III: THE CONVERGENT SERIES
-- ════════════════════════════════════════════════

/-- **The Convergent Series.**

    Σ_{k=2}^∞ log²(k) / k^{3/2} converges to a finite constant.

    This is the key fact that makes the Abel bound collapse to O(1/log N).
    For our purposes, we just need a uniform upper bound for any finite N. -/
theorem convergent_log_series_bound :
    ∃ C : ℝ, 0 < C ∧ ∀ N : ℕ, 2 ≤ N →
    (Finset.Ico 2 N).sum (fun k =>
      (Real.log (k : ℝ)) ^ 2 / ((k : ℝ) ^ (3/2 : ℝ))) ≤ C := by
  -- The series Σ log²k / k^{3/2} converges by comparison with
  -- the integral ∫₂^∞ log²t / t^{3/2} dt < ∞.
  -- We can take C = 20 (very generous upper bound).
  sorry

-- ════════════════════════════════════════════════
-- PART IV: THE ASSEMBLY — CLOSING AXIOM 2
-- ════════════════════════════════════════════════

/-- **THE CLOSURE OF AXIOM 2.**

    Given the Mertens bound (Axiom 1), construct weights v such that:
    ∫₀¹ (1 - Σ vₖ{k/x})² dx ≤ C/log(N)

    This theorem, once proved, REPLACES `axiom abel_summation_l2_bound`
    in MertensWeightBypass.lean.

    Proof sketch:
    1. Define v(k) = correctedWeight(k, N) (from MertensWeightBypass)
    2. Apply abel_summation_abs_bound with:
       - a(k) = μ(k)/k
       - f(k) = logWeight N k = 1 - log(k)/log(N)
       - C_bound(k) = C_m · log²(k) / √k
       - δ(k) = 1 / (k · log N)
    3. The boundary term vanishes: C_bound(N) · |f(N)| = C_bound(N) · 0 = 0
    4. The remaining sum is (1/log N) · Σ log²k / k^{3/2} ≤ C/log N
    5. Wire through l2_error_eq_quad_error and nbDistSq_le_test_vector -/
theorem abel_summation_l2_bound_proved :
    (∃ C_m : ℝ, 0 < C_m ∧ ∀ x : ℝ, 2 ≤ x →
      |mertensFunction x| ≤ C_m * x ^ (1/2 : ℝ) * (Real.log x) ^ 2) →
    ∃ C : ℝ, 0 < C ∧
    ∀ N : ℕ, 10 ≤ N →
    ∃ v : Fin (N - 1) → ℝ,
    ∫ x in (0:ℝ)..1, (1 - nbLinComb N v x) ^ 2 ≤ C / Real.log (N : ℝ) ∧
    dotProduct v v ≤ (N : ℝ) ^ 2 := by
  intro ⟨C_m, hC_m, hMertens⟩
  -- Step 1: Get the convergent series bound
  obtain ⟨C_series, hC_series_pos, hC_series⟩ := convergent_log_series_bound
  -- Step 2: Use corrected weights from MertensWeightBypass
  -- Step 3: Apply abel_summation_abs_bound
  -- Step 4: Use logWeight_self to kill the boundary term
  -- Step 5: Use convergent_log_series_bound for the sum
  -- Step 6: Wire through L² bridge
  sorry

-- ════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════

-- This file targets closing Axiom 2 (abel_summation_l2_bound).
--
-- Status:
--   ✅ logWeight                       — Definition
--   ✅ logWeight_self                  — Boundary vanishes (PROVING)
--   ⚠️  log_weight_derivative_bound    — |Δf| ≤ 1/(k·log N) (NEXT)
--   ⚠️  mertens_to_abel_bound          — |A(k)| ≤ C·log²k/√k
--   ⚠️  convergent_log_series_bound    — Σ log²k/k^{3/2} ≤ C
--   ⚠️  abel_summation_l2_bound_proved — THE GOAL
--
-- Dependencies proved elsewhere:
--   ✅ abel_summation              (AbelSummation.lean)
--   ✅ abel_summation_abs_bound    (AbelSummation.lean)
--   ✅ corrected_weights_pole_free (MertensWeightBypass.lean)
--   ✅ l2_error_eq_quad_error      (L2Tools.lean)
--   ✅ nbDistSq_le_test_vector     (QuadFormBridge.lean)

end
