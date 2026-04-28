/-
  Cathedral/Analysis/FrequencySeparation.lean

  ## Frequency Separation for Logarithmic Frequencies

  ### Mathematical Content

  For the Gallagher MVT application to Dirichlet polynomials,
  we need that the frequencies λₙ = log(n) are δ-separated
  with δ = 1/(N+1).

  Key inequality: log(n+1) - log(n) = log(1 + 1/n) ≥ 1/(n+1)
  (from log(1+x) ≥ x/(1+x) for x > 0)

  ### Dependencies
  - HilbertInequality.lean (IsDeltaSeparated definition)
  - Mathlib (Real.log monotonicity, etc.)

  ### Sorry Status
  Assembly file — proving frequency separation.
-/

import Cathedral.Analysis.HilbertInequality
import Mathlib.Analysis.SpecialFunctions.Log.Basic
import Mathlib.Analysis.SpecialFunctions.Log.Deriv

noncomputable section
open Real Finset BigOperators

namespace Cathedral.Analysis

-- ═══════════════════════════════════════════════
-- §1. LOG SEPARATION LEMMA
-- ═══════════════════════════════════════════════

/-- **Key inequality**: log(1 + 1/n) ≥ 1/(n+1) for n ≥ 1.

    Proof: log(1+x) ≥ x/(1+x) for x > 0.
    Set x = 1/n: log(1+1/n) ≥ (1/n)/(1+1/n) = 1/(n+1). -/
lemma log_one_add_inv_ge (n : ℕ) (hn : 1 ≤ n) :
    (1 : ℝ) / (n + 1) ≤ Real.log (1 + 1 / n) := by
  have hn_pos : (0 : ℝ) < n := Nat.cast_pos.mpr (by omega)
  -- Use: 1 - x⁻¹ ≤ log x for x > 0 (Real.one_sub_inv_le_log_of_pos)
  -- with x = 1 + 1/n > 0
  have h_pos : (0 : ℝ) < 1 + 1 / n := by linarith [div_pos one_pos hn_pos]
  have h := Real.one_sub_inv_le_log_of_pos h_pos
  -- Simplify: 1 - (1+1/n)⁻¹ = 1 - n/(n+1) = 1/(n+1)
  have h_simpl : 1 - (1 + 1 / (n : ℝ))⁻¹ = 1 / (n + 1) := by
    field_simp; ring
  linarith

/-- For distinct natural numbers m ≠ n with 1 ≤ m, n ≤ N,
    |log(m) - log(n)| ≥ 1/(N+1). -/
lemma log_nat_separation (m n N : ℕ) (hm : 1 ≤ m) (hn : 1 ≤ n)
    (hmN : m ≤ N) (hnN : n ≤ N) (hmn : m ≠ n) :
    (1 : ℝ) / (N + 1) ≤ |Real.log m - Real.log n| := by
  -- WLOG m > n (swap if needed)
  wlog h : n < m with H
  · push_neg at h
    have : m < n := lt_of_le_of_ne h hmn
    rw [abs_sub_comm]
    exact H n m N hn hm hnN hmN (Ne.symm hmn) this
  -- Now m > n, so m ≥ n + 1
  have hmn_le : n + 1 ≤ m := h
  -- log m ≥ log(n+1) > log(n)
  have hm_pos : (0 : ℝ) < m := Nat.cast_pos.mpr (by omega)
  have hn_pos : (0 : ℝ) < n := Nat.cast_pos.mpr (by omega)
  have h_mono : Real.log n < Real.log m := by
    exact Real.log_lt_log hn_pos (by exact_mod_cast h)
  rw [abs_of_pos (sub_pos.mpr h_mono)]
  -- log(m) - log(n) ≥ log(n+1) - log(n) (log is monotone)
  have h_step : Real.log (n + 1) ≤ Real.log m := by
    exact Real.log_le_log (by positivity) (by exact_mod_cast hmn_le)
  have h_diff : Real.log (n + 1) - Real.log n ≤ Real.log m - Real.log n :=
    sub_le_sub_right h_step _
  -- log(n+1) - log(n) = log((n+1)/n) = log(1 + 1/n)
  have h_ratio : Real.log (n + 1) - Real.log n = Real.log (1 + 1 / n) := by
    rw [← Real.log_div (by positivity) (by positivity)]
    congr 1
    field_simp
  -- Apply the key inequality
  have h_key : (1 : ℝ) / (n + 1) ≤ Real.log (1 + 1 / n) :=
    log_one_add_inv_ge n hn
  -- 1/(n+1) ≥ 1/(N+1) since n ≤ N
  have h_denom : (1 : ℝ) / (↑N + 1) ≤ 1 / (↑n + 1) := by
    rw [div_le_div_iff₀ (by positivity : (0 : ℝ) < ↑N + 1) (by positivity : (0 : ℝ) < ↑n + 1)]
    linarith [show (n : ℝ) ≤ N from by exact_mod_cast hnN]
  linarith [h_ratio ▸ h_key]

-- ═══════════════════════════════════════════════
-- §2. DIRICHLET FREQUENCY SEPARATION
-- ═══════════════════════════════════════════════

/-- **SUB-GOAL A**: Logarithmic frequencies are δ-separated.

    For the Gallagher MVT application to Dirichlet polynomials
    Σ aₙ n^{-it} = Σ aₙ e^{-it·log(n)}, the frequencies
    λₙ = log(n+1) (shifted by 1 for Fin N indexing) satisfy
    |λᵢ - λⱼ| ≥ 1/(N+1) for i ≠ j.

    This is the frequency separation condition required by
    `fejer_orthogonality` and `gallagher_mvt`. -/
theorem log_frequencies_separated (N : ℕ) (_ : 2 ≤ N) :
    IsDeltaSeparated (fun n : Fin N => Real.log (↑n.val + 1)) (1 / (↑N + 1)) := by
  intro i j hij
  -- Cast to ℝ: need |log(i+1) - log(j+1)| ≥ 1/(N+1)
  -- Use log_nat_separation with m=i+1, n=j+1, bound=N
  have h := log_nat_separation (i.val + 1) (j.val + 1) N
    (by omega) (by omega) (by omega) (by have := i.isLt; omega)
    (by intro h; apply hij; exact Fin.ext (by omega))
  -- Adjust: 1/(N+1) ≤ 1/(N+1) follows from N ≤ N
  -- log_nat_separation gives 1/(N+1) ≤ |log(i+1) - log(j+1)|
  -- but its bound is N, so we get 1/(↑N+1) which matches
  exact_mod_cast h

end Cathedral.Analysis
