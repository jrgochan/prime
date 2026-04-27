-- Scratch: Bridge matching proof
import Mathlib.Analysis.Fourier.FourierTransform
import Mathlib.Analysis.SpecialFunctions.Trigonometric.Basic
import Mathlib.MeasureTheory.Integral.Bochner.Basic
import Mathlib.MeasureTheory.Integral.Bochner.Set
import Mathlib.MeasureTheory.Integral.IntervalIntegral.Basic

open MeasureTheory Real Complex
open scoped FourierTransform

noncomputable section

def mysinc (x : ℝ) : ℝ :=
  if x = 0 then 1 else Real.sin (π * x) / (π * x)

def Λ_ℂ (ξ : ℝ) : ℂ := ((max (1 - |ξ|) 0 : ℝ) : ℂ)

def fejerKernel (x : ℝ) : ℝ := (mysinc x) ^ 2

-- Assume Bridge for testing
axiom bridge (x : ℝ) :
  ∫ ξ in Set.Icc (-1 : ℝ) 1,
    ((1 - |ξ|) * Real.cos (2 * π * x * ξ) : ℝ) = fejerKernel x

-- Step 1: 𝓕 Λ_ℂ (w) = ∫ v in [-1,1], 𝐞(-(v*w)) • Λ_ℂ(v)
-- This is the key step: restrict the integral to the support
-- Then split exp into cos + i sin
-- Then identify cos part with Bridge, sin part with 0

-- Let me check what 𝓕 Λ_ℂ looks like more concretely
-- What does fourier_eq give?
#check @Real.fourier_eq ℂ _ _ _ _

-- Wait, does this work by rfl? Let me check...
-- 𝓕 is defined for ℝ → ℂ as Real.fourierIntegral, which unfolds to
-- VectorFourier.fourierIntegral fourierChar volume (innerₗ ℝ) f w
-- = ∫ v, fourierChar (-(innerₗ ℝ v w)) • f v
-- On ℝ, innerₗ ℝ v w = v * w (the inner product)
-- So = ∫ v, 𝐞(-(v*w)) • f(v)
