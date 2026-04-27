-- Scratch: FK3/FK4 implementation
import Mathlib.Analysis.Fourier.FourierTransform
import Mathlib.Analysis.Fourier.Inversion
import Mathlib.Analysis.SpecialFunctions.Trigonometric.Basic
import Mathlib.Analysis.SpecialFunctions.Trigonometric.Sinc
import Mathlib.Analysis.SpecialFunctions.ImproperIntegrals
import Mathlib.MeasureTheory.Integral.Bochner.Basic

open MeasureTheory Real Complex
open scoped FourierTransform

noncomputable section

-- The triangle function, ℂ-valued
def Λ_ℂ (ξ : ℝ) : ℂ := ((max (1 - |ξ|) 0 : ℝ) : ℂ)

-- 𝓕(f)(0) = ∫ f(x) dx
lemma fourier_at_zero (f : ℝ → ℂ) : 𝓕 f 0 = ∫ v : ℝ, f v := by
  simp [Real.fourier_eq]

-- Now the FK3 plan:
-- 1. Apply fourier_fourierInv_eq to Λ_ℂ at ξ=0:
--    𝓕(𝓕⁻ Λ_ℂ)(0) = Λ_ℂ(0) = 1
-- 2. By fourier_at_zero: 𝓕(𝓕⁻ Λ_ℂ)(0) = ∫ (𝓕⁻ Λ_ℂ)(x) dx
-- 3. Need: ∫ (𝓕⁻ Λ_ℂ)(x) dx = ∫ fejerKernel(x) dx  (matching)

-- Step 1: Test that Λ_ℂ(0) = 1
example : Λ_ℂ 0 = 1 := by
  simp [Λ_ℂ]

-- Step 2: Integrable Λ_ℂ 
-- Λ_ℂ is bounded (≤ 1) and has support [-1,1], so it's integrable.
-- This needs some work...

-- Step 3: Integrable (𝓕 Λ_ℂ)
-- This is equivalent to FK2 (modulo matching 𝓕 Λ_ℂ with fejerKernel)
-- For now, let me see what 𝓕 Λ_ℂ unfolds to:

-- 𝓕 Λ_ℂ (w) = ∫ 𝐞(-(v * w)) • Λ_ℂ(v) dv
-- where 𝐞(x) = exp(2πix) (the Fourier character on ℝ)
-- = ∫ exp(-2πi v w) * max(1-|v|, 0) dv

-- This is a Lebesgue integral. For w=0:
-- 𝓕 Λ_ℂ (0) = ∫ 1 * max(1-|v|, 0) dv = ∫₋₁¹ (1-|v|) dv = 1

-- For general w, this equals sinc²(w) = sin²(πw)/(πw)²
-- (our Bridge theorem, extended to complex notation)

-- The matching requires showing that the Lebesgue integral
-- of exp(-2πivw) * Λ(v) equals sinc²(w).

-- Let me try a direct proof that 𝓕 Λ_ℂ = 𝓕⁻ Λ_ℂ (evenness)
lemma Λ_ℂ_even (ξ : ℝ) : Λ_ℂ (-ξ) = Λ_ℂ ξ := by
  simp [Λ_ℂ, abs_neg]

-- And check if fourierInv is defined as 𝓕 applied with negation
-- 𝓕⁻ f(w) = 𝓕 f(-w) in the standard definition
-- So for even f: 𝓕 f(w) = ∫ 𝐞(-vw) f(v) dv = ∫ 𝐞((-v)w) f(-v) dv (v → -v)
-- = ∫ 𝐞(vw) f(v) dv (since f(-v) = f(v)) = 𝓕⁻ f(w)
