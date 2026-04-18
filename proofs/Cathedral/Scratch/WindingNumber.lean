import Mathlib.Analysis.Complex.CauchyIntegral
import Mathlib.Analysis.SpecialFunctions.Complex.LogDeriv
import Mathlib.Analysis.SpecialFunctions.Pow.Deriv
import Mathlib.MeasureTheory.Integral.IntervalIntegral.Basic

noncomputable section
open Complex Real MeasureTheory Set

-- Test: integrability of (x + aI)⁻¹
example (a : ℝ) (ha : a ≠ 0) :
    IntervalIntegrable (fun x : ℝ => ((↑x + ↑a * I)⁻¹ : ℂ)) volume 0 1 := by
  apply ContinuousOn.intervalIntegrable
  apply ContinuousOn.inv₀
  · fun_prop
  · intro x _
    intro h
    have := congr_arg Complex.im h
    simp [Complex.add_im, Complex.ofReal_im, Complex.mul_im, Complex.I_re, Complex.I_im] at this
    exact ha this

end
