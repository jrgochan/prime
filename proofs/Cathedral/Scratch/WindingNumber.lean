/-
  Scratch: Right vertical antiderivative
-/
import Mathlib.Analysis.Complex.CauchyIntegral
import Mathlib.Analysis.Complex.RemovableSingularity
import Mathlib.Analysis.SpecialFunctions.Complex.LogDeriv
import Mathlib.Analysis.SpecialFunctions.Pow.Deriv
import Mathlib.MeasureTheory.Integral.IntervalIntegral.Basic

noncomputable section
open Complex Real MeasureTheory Set

-- This lemma is the core chain rule: d/dt[-I * log(c + tI)] = 1/(c + tI)
lemma right_vert_antideriv (c : ℝ) (hc : 0 < c) (t : ℝ) :
    HasDerivAt (fun u : ℝ => -I * Complex.log (↑c + ↑u * I))
      ((↑c + ↑t * I)⁻¹ : ℂ) t := by
  have hslitPlane : (↑c + ↑t * I) ∈ slitPlane := by
    left; simp [Complex.add_re, Complex.ofReal_re, Complex.mul_re, Complex.I_re, Complex.I_im, hc]
  have hf : HasDerivAt (fun u : ℝ => (↑c : ℂ) + ↑u * I) (I : ℂ) t := by
    have h1 := Complex.ofRealCLM.hasDerivAt (x := t)
    simpa using (h1.mul_const I).const_add (↑c : ℂ)
  have hlog := HasDerivAt.clog_real hf hslitPlane
  have hmul := hlog.const_mul (-I)
  -- hmul : HasDerivAt (fun u => -I * log(c + uI)) (-I * (I / (c + tI))) t
  -- Need: -I * (I / (c + tI)) = (c + tI)⁻¹
  have hsimpl : -I * (I / (↑c + ↑t * I)) = (↑c + ↑t * I)⁻¹ := by
    rw [div_eq_mul_inv, ← mul_assoc, show -I * I = (1 : ℂ) from by simp [Complex.I_mul_I],
        one_mul]
  rwa [hsimpl] at hmul
