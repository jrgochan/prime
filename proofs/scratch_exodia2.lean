/-
  Scratch file: Exodia Assembly — Stage 2
  Testing the full assembly chain from holomorphic log through to lower bound.
-/

import Cathedral.Zeta.DiskBounds
import Cathedral.Zeta.Hadamard
import Mathlib.Analysis.SpecialFunctions.Pow.Asymptotics
import Mathlib.Analysis.Calculus.MeanValue
import Mathlib.NumberTheory.LSeries.Dirichlet
import Mathlib.Analysis.PSeries
import Mathlib.Topology.Algebra.InfiniteSum.Real

noncomputable section
open Complex Real Filter Asymptotics MeasureTheory Metric Set
open scoped Topology ArithmeticFunction LSeries.notation

namespace ScratchExodia2
open Cathedral.Zeta.DiskBounds
open Cathedral.Zeta.Hadamard

-- Inline from LittlewoodManeuver to avoid import dependency
private lemma sub_logarithmic_bound
    {α A : ℝ} (_hα : 0 < α) (hα1 : α < 1) (hA : 0 < A) :
    ∃ T₀ > 0, ∀ t : ℝ, T₀ ≤ t →
      (Real.log t) ^ α < A * Real.log t := by
  have h1mα : 0 < 1 - α := sub_pos.mpr hα1
  have h_tend_x : Tendsto (fun x : ℝ => x ^ (-(1-α))) atTop (𝓝 0) :=
    tendsto_rpow_neg_atTop h1mα
  have h_tend : Tendsto (fun t : ℝ => (Real.log t) ^ (α - 1)) atTop (𝓝 0) := by
    have : (fun t => (Real.log t) ^ (-(1-α))) = (fun t => (Real.log t) ^ (α - 1)) := by
      ext; ring_nf
    rw [← this]
    exact h_tend_x.comp tendsto_log_atTop
  rw [Metric.tendsto_atTop] at h_tend
  obtain ⟨N, hN⟩ := h_tend A hA
  refine ⟨max N (Real.exp 2), lt_of_lt_of_le (Real.exp_pos 2) (le_max_right _ _), fun t ht => ?_⟩
  have hN_le : N ≤ t := le_trans (le_max_left _ _) ht
  have hexp_le : Real.exp 2 ≤ t := le_trans (le_max_right _ _) ht
  have hlog_ge2 : (2 : ℝ) ≤ Real.log t := by
    rwa [← Real.log_exp 2, Real.log_le_log_iff (Real.exp_pos 2)
      (lt_of_lt_of_le (Real.exp_pos 2) hexp_le)]
  have hlog_pos : 0 < Real.log t := by linarith
  have h_dist := hN t hN_le
  rw [Real.dist_eq, sub_zero] at h_dist
  have h_rpow_pos : 0 < Real.log t ^ (α - 1) := rpow_pos_of_pos hlog_pos _
  rw [abs_of_pos h_rpow_pos] at h_dist
  have h_mul : Real.log t ^ (α - 1) * Real.log t < A * Real.log t := by nlinarith
  have h_rpow_eq : Real.log t ^ (α - 1) * Real.log t = Real.log t ^ α := by
    have := rpow_add hlog_pos (α - 1) 1
    rw [rpow_one, sub_add_cancel] at this; linarith
  linarith

-- ═══════════════════════════════════════════
-- THE EXODIA CORE: Sub-logarithmic ‖G‖ bound → ζ polynomial lower bound
-- ═══════════════════════════════════════════

/-- If exp(-K·(log(2+|t|))^α) bounds ‖ζ(s)‖ from below (up to constants),
    and α < 1, then ‖ζ(s)‖ ≥ c/|t|^A for any A > 0 and large enough |t|.

    Key arithmetic: exp(-K·(log x)^α) ≥ exp(-A·log x) = x^{-A}
    when (log x)^α < (A/K)·log x, which holds for x ≥ T₀ by sub_logarithmic_bound. -/
private lemma sub_log_to_polynomial
    {K : ℝ} (hK : 0 < K) {α : ℝ} (hα : 0 < α) (hα1 : α < 1)
    {A : ℝ} (hA : 0 < A) :
    ∃ T₀ > 0, ∀ t : ℝ, T₀ ≤ |t| →
      (1/4 : ℝ) * Real.exp (-(K * (Real.log (2 + |t|)) ^ α)) ≥
      (1/4 : ℝ) * (2 + |t|) ^ (-A) := by
  -- Get T₁ from sub_logarithmic_bound: (log x)^α < (A/K)·log x for x ≥ T₁
  have hAK : 0 < A / K := div_pos hA hK
  obtain ⟨T₁, hT₁_pos, hT₁⟩ := sub_logarithmic_bound hα hα1 hAK
  -- We need 2 + |t| ≥ T₁, so |t| ≥ T₁ - 2 suffices (and |t| ≥ 2 for the base)
  refine ⟨max T₁ 2, lt_of_lt_of_le (by norm_num : (0:ℝ) < 2) (le_max_right _ _), ?_⟩
  intro t ht
  have hT₁_le : T₁ ≤ |t| := le_trans (le_max_left _ _) ht
  have ht_ge_2 : 2 ≤ |t| := le_trans (le_max_right _ _) ht
  have h2t_pos : 0 < 2 + |t| := by linarith [abs_nonneg t]
  have h2t_ge_T : T₁ ≤ 2 + |t| := by linarith
  -- Apply sub_logarithmic_bound at x = 2 + |t|
  have hlog_sub := hT₁ (2 + |t|) h2t_ge_T
  -- hlog_sub : (log(2+|t|))^α < (A/K) · log(2+|t|)
  -- → K · (log(2+|t|))^α < A · log(2+|t|)
  have hK_bound : K * (Real.log (2 + |t|)) ^ α < A * Real.log (2 + |t|) := by
    have h1 := mul_lt_mul_of_pos_left hlog_sub hK
    -- h1 : K * (log(2+|t|))^α < K * (A/K * log(2+|t|))
    -- K * (A/K * log(2+|t|)) = A * log(2+|t|) since K ≠ 0
    have h2 : K * (A / K * Real.log (2 + |t|)) = A * Real.log (2 + |t|) := by
      field_simp
    linarith
  -- exp(-K·(log x)^α) ≥ exp(-A·log x) = x^{-A}
  have hexp_ge : Real.exp (-(A * Real.log (2 + |t|))) ≤
      Real.exp (-(K * (Real.log (2 + |t|)) ^ α)) :=
    Real.exp_le_exp.mpr (neg_le_neg (le_of_lt hK_bound))
  -- exp(-A·log x) = x^{-A}
  have hexp_eq : Real.exp (-(A * Real.log (2 + |t|))) = (2 + |t|) ^ (-A) := by
    rw [Real.rpow_def_of_pos h2t_pos]; ring_nf
  rw [ge_iff_le, ← hexp_eq]
  exact mul_le_mul_of_nonneg_left hexp_ge (by norm_num)

#check @sub_log_to_polynomial

end ScratchExodia2
