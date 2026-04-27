-- Scratch: test the full FTC pipeline
import Mathlib.Analysis.SpecialFunctions.Trigonometric.Deriv
import Mathlib.MeasureTheory.Integral.IntervalIntegral.Basic
import Mathlib.Analysis.SpecialFunctions.Integrals.Basic
import Mathlib.MeasureTheory.Integral.IntervalIntegral.FundThmCalculus

open Real MeasureTheory

noncomputable section

example (c : ℝ) (hc : c ≠ 0) :
    ∫ ξ in (0 : ℝ)..1, (1 - ξ) * cos (c * ξ) = (1 - cos c) / c ^ 2 := by
  have hDeriv : ∀ ξ ∈ Set.uIcc (0 : ℝ) 1,
      HasDerivAt (fun t => (1 - t) * sin (c * t) / c - cos (c * t) / c ^ 2)
        ((1 - ξ) * cos (c * ξ)) ξ := by
    intro ξ _
    have h1 : HasDerivAt (fun t => (1 : ℝ) - t) (-1) ξ := by
      simpa using (hasDerivAt_id ξ).const_sub 1
    have h2 := (hasDerivAt_const_mul c (x := ξ)).sin
    have h3 := (hasDerivAt_const_mul c (x := ξ)).cos
    convert (h1.mul h2).div_const c |>.sub (h3.div_const (c ^ 2)) using 1
    field_simp; ring
  have key := intervalIntegral.integral_eq_sub_of_hasDerivAt hDeriv
    (((continuous_const.sub continuous_id).mul
      (continuous_cos.comp (continuous_const.mul continuous_id))).intervalIntegrable _ _)
  -- Try to see what key looks like:
  -- F(1) - F(0) = ((1-1)*sin(c*1)/c - cos(c*1)/c^2) - ((1-0)*sin(c*0)/c - cos(c*0)/c^2)
  -- After beta reduction: (0*sin(c)/c - cos(c)/c^2) - (1*sin(0)/c - cos(0)/c^2)
  -- = (- cos(c)/c^2) - (- 1/c^2) = (1 - cos c)/c^2
  convert key using 1
  simp [sin_zero, cos_zero]
  ring
