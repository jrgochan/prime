/-
  Scratch: rpow algebra for the Three-Circles → sub-logarithmic conversion.
  Key: 6^(1-α) · (C · log(2+|t|))^α = (6^(1-α) · C^α) · (log(2+|t|))^α
-/

import Mathlib.Analysis.SpecialFunctions.Pow.Real
import Mathlib.Analysis.SpecialFunctions.Log.Basic

noncomputable section
open Real

-- ═══════════════════════════════════════════
-- rpow algebra: a^(1-θ) · (C·x)^θ = (a^(1-θ) · C^θ) · x^θ
-- ═══════════════════════════════════════════

/-- a^(1-θ) · (C·x)^θ = (a^(1-θ)·C^θ) · x^θ when a, C, x > 0. -/
lemma rpow_factor_out {a C x θ : ℝ} (ha : 0 < a) (hC : 0 < C) (hx : 0 < x) :
    a ^ (1-θ) * (C * x) ^ θ = (a ^ (1-θ) * C ^ θ) * x ^ θ := by
  rw [mul_rpow (le_of_lt hC) (le_of_lt hx)]
  ring

/-- If M ≤ C · x and M > 0 and x > 0, then a^(1-θ)·M^θ ≤ a^(1-θ)·(C·x)^θ
    when 0 ≤ θ ≤ 1 and a > 0. -/
lemma rpow_bound_from_linear {a M C x θ : ℝ}
    (ha : 0 < a) (hM : 0 ≤ M) (hCx : M ≤ C * x)
    (hθ : 0 ≤ θ) (_hθ1 : θ ≤ 1)
    (_hC : 0 < C) (hx : 0 < x) :
    a ^ (1-θ) * M ^ θ ≤ a ^ (1-θ) * (C * x) ^ θ := by
  apply mul_le_mul_of_nonneg_left
  · exact rpow_le_rpow hM hCx hθ
  · exact le_of_lt (rpow_pos_of_pos ha _)

/-- M = 10·log(2+|t|) + log 4 ≤ 11·log(2+|t|) when |t| ≥ 2.
    Because log 4 ≤ log(2+|t|) when |t| ≥ 2. -/
lemma M_le_11_log {t : ℝ} (ht : 2 ≤ |t|) :
    10 * Real.log (2 + |t|) + Real.log 4 ≤ 11 * Real.log (2 + |t|) := by
  have h2t : (4 : ℝ) ≤ 2 + |t| := by linarith
  have h4_pos : (0 : ℝ) < 4 := by norm_num
  have h2t_pos : (0 : ℝ) < 2 + |t| := by linarith [abs_nonneg t]
  have hlog_le : Real.log 4 ≤ Real.log (2 + |t|) :=
    Real.log_le_log h4_pos h2t
  linarith

/-- The full Three-Circles bound is controlled by K · (log(2+|t|))^α.

    Given: ‖G(z*)‖ ≤ 6^(1-α) · b^α where b = 2·M·R₃/(R₄-R₃) and M = 10·log(2+|t|) + log 4.
    Since M ≤ 11·log(2+|t|) for |t| ≥ 2:
      b ≤ 2·11·log(2+|t|)·R₃/(R₄-R₃) = C_ε · log(2+|t|)
    So: 6^(1-α)·b^α ≤ 6^(1-α)·(C_ε·log(2+|t|))^α = K · (log(2+|t|))^α
    where K = 6^(1-α) · C_ε^α > 0. -/
lemma three_circles_to_sub_log
    {R₃ R₄ α : ℝ} (hα : 0 ≤ α) (hα1 : α ≤ 1)
    (hR₃_pos : 0 < R₃) (hR₃_lt_R₄ : R₃ < R₄)
    {t : ℝ} (ht : 2 ≤ |t|)
    (bound : ℝ) (hbound : bound = 6 ^ (1 - α) *
      (2 * (10 * Real.log (2 + |t|) + Real.log 4) * R₃ / (R₄ - R₃)) ^ α) :
    bound ≤ (6 ^ (1 - α) * (22 * R₃ / (R₄ - R₃)) ^ α) *
            (Real.log (2 + |t|)) ^ α := by
  rw [hbound]
  have h2t_pos : (0 : ℝ) < 2 + |t| := by linarith [abs_nonneg t]
  have hlog_pos : 0 < Real.log (2 + |t|) := Real.log_pos (by linarith)
  have hgap_pos : 0 < R₄ - R₃ := by linarith
  have hM_le := M_le_11_log ht
  -- 2·M·R₃/(R₄-R₃) ≤ 2·11·log(2+|t|)·R₃/(R₄-R₃) = 22·R₃/(R₄-R₃)·log(2+|t|)
  have hb_le : 2 * (10 * Real.log (2 + |t|) + Real.log 4) * R₃ / (R₄ - R₃) ≤
               22 * R₃ / (R₄ - R₃) * Real.log (2 + |t|) := by
    rw [div_mul_eq_mul_div]
    apply div_le_div_of_nonneg_right _ (le_of_lt hgap_pos)
    nlinarith
  -- Now factor: 6^(1-α) · b^α ≤ 6^(1-α) · (C·log(2+|t|))^α
  have hb_nonneg : 0 ≤ 2 * (10 * Real.log (2 + |t|) + Real.log 4) * R₃ / (R₄ - R₃) := by
    apply div_nonneg
    · apply mul_nonneg
      · apply mul_nonneg (by norm_num)
        linarith [Real.log_nonneg (show (1:ℝ) ≤ 4 by norm_num)]
      · exact le_of_lt hR₃_pos
    · exact le_of_lt hgap_pos
  calc 6 ^ (1 - α) * (2 * (10 * Real.log (2 + |t|) + Real.log 4) * R₃ / (R₄ - R₃)) ^ α
      ≤ 6 ^ (1 - α) * (22 * R₃ / (R₄ - R₃) * Real.log (2 + |t|)) ^ α := by
        apply mul_le_mul_of_nonneg_left
        · exact rpow_le_rpow hb_nonneg hb_le hα
        · exact le_of_lt (rpow_pos_of_pos (by norm_num : (0:ℝ) < 6) _)
    _ = (6 ^ (1 - α) * (22 * R₃ / (R₄ - R₃)) ^ α) * (Real.log (2 + |t|)) ^ α := by
        rw [mul_rpow (le_of_lt (by positivity : (0:ℝ) < 22 * R₃ / (R₄ - R₃)))
                      (le_of_lt hlog_pos)]
        ring

#check @rpow_factor_out
#check @M_le_11_log
#check @three_circles_to_sub_log
