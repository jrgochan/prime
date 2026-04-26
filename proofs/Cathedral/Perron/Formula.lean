import Cathedral.Perron.KernelBound

/-!
# Perron's Formula: From Kernel to Summatory Function

This file assembles the unified Perron kernel bound into per-term error bounds
suitable for finite Dirichlet polynomial sums.

## Main results

* `perron_per_term_gt_one` : specialization of the kernel bound for `y > 1`
* `perron_formula_error_bound` : triangle inequality bound for `∑ a(n)·(P(x/n) - 1)`
-/

noncomputable section
open Complex Real MeasureTheory Set BigOperators ComplexConjugate

namespace Cathedral.Perron

-- ═══════════════════════════════════════════
-- §9. From Kernel to Summatory Function (The Assembly)
-- ═══════════════════════════════════════════

/-- **PROVED**: For y > 1, the Perron integral approximates 1.
    Direct specialization of perron_kernel_gt_one. -/
theorem perron_per_term_gt_one
    (y c T : ℝ) (hy : 1 < y) (hc : 0 < c) (hT : 0 < T) :
    ‖perronIntegral y c T - 1‖ ≤
    y ^ c / (Real.pi * T * |Real.log y|) :=
  perron_kernel_gt_one y c T hy hc hT

set_option maxHeartbeats 800000 in
/-- **PROVED**: Error bound for a finite Dirichlet polynomial via Perron's formula.

    For a finite sum Σ_{n ∈ S} a(n) with x/n > 1 for each n ∈ S:
    ‖Σ a(n)·(P(x/n) - 1)‖ ≤ Σ ‖a(n)‖ · (x/n)^c / (π·T·|log(x/n)|)
    where P(y) = perronIntegral(y, c, T).

    Proof: triangle inequality + perron_kernel_gt_one per term. -/
theorem perron_formula_error_bound
    (a : ℕ → ℂ) (x c T : ℝ) (S : Finset ℕ)
    (hc : 0 < c) (hT : 0 < T)
    (hS : ∀ n ∈ S, 1 < x / ↑n) :
    ‖∑ n ∈ S, (a n * (perronIntegral (x / ↑n) c T - 1))‖ ≤
    ∑ n ∈ S,
      ‖a n‖ * ((x / ↑n) ^ c / (Real.pi * T * |Real.log (x / ↑n)|)) := by
  -- Pre-extract per-term bounds to avoid expensive in-context elaboration
  have per_term : ∀ n ∈ S,
      ‖a n‖ * ‖perronIntegral (x / ↑n) c T - 1‖ ≤
      ‖a n‖ * ((x / ↑n) ^ c / (Real.pi * T * |Real.log (x / ↑n)|)) := by
    intro n hn
    exact mul_le_mul_of_nonneg_left (perron_per_term_gt_one _ c T (hS n hn) hc hT) (norm_nonneg _)
  calc ‖∑ n ∈ S, (a n * (perronIntegral (x / ↑n) c T - 1))‖
      ≤ ∑ n ∈ S, ‖a n * (perronIntegral (x / ↑n) c T - 1)‖ :=
        norm_sum_le _ _
    _ = ∑ n ∈ S, (‖a n‖ * ‖perronIntegral (x / ↑n) c T - 1‖) := by
        apply Finset.sum_congr rfl; intro n _; exact norm_mul _ _
    _ ≤ ∑ n ∈ S,
        (‖a n‖ * ((x / ↑n) ^ c / (Real.pi * T * |Real.log (x / ↑n)|))) :=
        Finset.sum_le_sum per_term

end Cathedral.Perron
