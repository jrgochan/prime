import Cathedral.White.Infrastructure.Perron.Defs

/-!
# FTC-Based Integral Bounds for `y^σ`

This file establishes bounds for the integral `∫ y^σ dσ` using the Fundamental
Theorem of Calculus. These are the key exponential decay/growth estimates
used by both the `y < 1` and `y > 1` cases of the Perron kernel.

## Main results

* `integral_rpow_le_of_lt_one` : for `0 < y < 1`, `∫_c^R y^σ ≤ y^c/|log y|`
* `integral_rpow_le_of_gt_one` : for `y > 1`, `∫_{-R}^c y^σ ≤ y^c/log y`
-/

noncomputable section
open Complex Real MeasureTheory Set BigOperators ComplexConjugate

namespace Cathedral.White.Infrastructure

-- ═══════════════════════════════════════════
-- §4. Exponential Decay Integral
-- ═══════════════════════════════════════════

/-- For 0 < y < 1, the integral of y^σ over [c,R] is at most y^c/|log y|.
    Uses FTC: ∫_c^R y^σ dσ = (y^R - y^c)/log(y) ≤ y^c/|log y|. -/
lemma integral_rpow_le_of_lt_one {y c R : ℝ} (hy_pos : 0 < y) (hy_lt : y < 1)
    (_hc : 0 ≤ c) (_hR : c ≤ R) :
    ∫ σ in c..R, y ^ σ ≤ y ^ c / |Real.log y| := by
  have hlog_neg : Real.log y < 0 := Real.log_neg hy_pos hy_lt
  have hlog_ne : Real.log y ≠ 0 := ne_of_lt hlog_neg
  have ftc : ∫ σ in c..R, Real.log y * y ^ σ = y ^ R - y ^ c := by
    apply intervalIntegral.integral_eq_sub_of_hasDerivAt
    · intro x _
      have h := (Real.hasStrictDerivAt_const_rpow hy_pos x).hasDerivAt
      rwa [mul_comm] at h
    · exact (continuous_const.mul (Continuous.rpow continuous_const continuous_id
        (fun _ => Or.inl (ne_of_gt hy_pos)))).intervalIntegrable c R
  have key : Real.log y * ∫ σ in c..R, y ^ σ = y ^ R - y ^ c := by
    rw [← intervalIntegral.integral_const_mul]; exact ftc
  have integral_eq : ∫ σ in c..R, y ^ σ = (y ^ R - y ^ c) / Real.log y := by
    field_simp at key ⊢; linarith
  rw [integral_eq, abs_of_neg hlog_neg]
  have hyR_nonneg : 0 ≤ y ^ R := rpow_nonneg hy_pos.le R
  have hyc_nonneg : 0 ≤ y ^ c := rpow_nonneg hy_pos.le c
  have h1 : y ^ c / (-Real.log y) = -(y ^ c) / Real.log y := by ring
  rw [h1, div_le_div_right_of_neg hlog_neg]
  linarith

/-- For y > 1, the integral of y^σ over [-R,c] is at most y^c/log y.
    Uses FTC: ∫_{-R}^c y^σ dσ = (y^c - y^{-R})/log(y) ≤ y^c/log y. -/
lemma integral_rpow_le_of_gt_one {y c R : ℝ} (hy : 1 < y) (_hR : 0 ≤ R) :
    ∫ σ in (-R)..c, y ^ σ ≤ y ^ c / Real.log y := by
  have hy_pos : 0 < y := lt_trans one_pos hy
  have hlog_pos : 0 < Real.log y := Real.log_pos hy
  have hlog_ne : Real.log y ≠ 0 := ne_of_gt hlog_pos
  have ftc : ∫ σ in (-R)..c, Real.log y * y ^ σ = y ^ c - y ^ (-R) := by
    apply intervalIntegral.integral_eq_sub_of_hasDerivAt
    · intro x _
      have h := (Real.hasStrictDerivAt_const_rpow hy_pos x).hasDerivAt
      rwa [mul_comm] at h
    · exact (continuous_const.mul (Continuous.rpow continuous_const continuous_id
        (fun _ => Or.inl (ne_of_gt hy_pos)))).intervalIntegrable (-R) c
  have key : Real.log y * ∫ σ in (-R)..c, y ^ σ = y ^ c - y ^ (-R) := by
    rw [← intervalIntegral.integral_const_mul]; exact ftc
  have integral_eq : ∫ σ in (-R)..c, y ^ σ = (y ^ c - y ^ (-R)) / Real.log y := by
    field_simp at key ⊢; linarith
  rw [integral_eq]
  have : 0 ≤ y ^ (-R) := rpow_nonneg hy_pos.le (-R)
  exact div_le_div_of_nonneg_right (by linarith) hlog_pos.le

end Cathedral.White.Infrastructure
