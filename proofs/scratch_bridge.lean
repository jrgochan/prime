-- Scratch: Full bridge matching — step by step
import Mathlib.Analysis.Fourier.FourierTransform
import Mathlib.Analysis.SpecialFunctions.Trigonometric.Basic
import Mathlib.MeasureTheory.Integral.Bochner.Basic
import Mathlib.MeasureTheory.Integral.Bochner.Set
import Mathlib.MeasureTheory.Integral.IntervalIntegral.Basic

open MeasureTheory Real Complex
open scoped FourierTransform

noncomputable section

def Λ_ℂ (ξ : ℝ) : ℂ := ((max (1 - |ξ|) 0 : ℝ) : ℂ)

-- Building block: inner = mul on ℝ
lemma real_inner_eq_mul (v w : ℝ) : @inner ℝ ℝ _ v w = v * w := by
  simp; ring

-- Step 1: Unfold FT to explicit exp integral
lemma ft_Λ_unfold (w : ℝ) :
    𝓕 Λ_ℂ w = ∫ v : ℝ,
      Complex.exp (↑(-2 * π * (v * w)) * Complex.I) * Λ_ℂ v := by
  rw [fourier_eq']
  congr 1; ext v; congr 1; congr 1; simp; ring

-- Step 2: Use Euler's formula: exp(iθ) = cos θ + i sin θ
-- exp(↑(-2πvw) * I) = cos(-2πvw) + i sin(-2πvw)
-- = cos(2πvw) - i sin(2πvw)

-- Step 3: exp * Λ_ℂ(v) = cos(2πvw) * Λ_ℂ(v) - i sin(2πvw) * Λ_ℂ(v)
-- For Λ_ℂ(v) = (max(1-|v|,0) : ℂ) which is real:
-- = (cos(2πvw) * max(1-|v|,0) : ℂ) - i (sin(2πvw) * max(1-|v|,0) : ℂ)

-- Step 4: Take the integral
-- ∫ [...] = ∫ cos(2πvw) * Λ(v) dv - i ∫ sin(2πvw) * Λ(v) dv  (in ℂ)
-- = Bridge(w) - i * 0 = sinc²(w)

-- This is still quite complex to formalize. Let me try a different approach:
-- Instead of decomposing the exp, I'll directly show that
-- 𝓕 Λ_ℂ(w) is real-valued and equals the real-valued Bridge result.

-- Actually, let me try the simplest possible approach:
-- Just show the integral equals sinc²(w) by converting everything to
-- real-valued computations.

-- Key idea: For a REAL-VALUED function f : ℝ → ℝ cast to ℂ,
-- 𝓕 (↑f)(w) = ∫ exp(-2πivw) * (f v : ℂ) dv

-- The cosine FT is: Re(𝓕 f(w)) = ∫ cos(2πvw) f(v) dv
-- The sine FT is: -Im(𝓕 f(w)) = ∫ sin(2πvw) f(v) dv

-- But I don't need to decompose! I can work entirely in ℂ.
-- I need: 𝓕 Λ_ℂ(w) = (sinc²(w) : ℂ)
-- This is a ℂ equation. Both sides are real-valued.

-- Hmm, let me try yet another approach. Since the Bridge matching is
-- "just" plumbing, let me try to directly connect:
-- ∫ v, exp(-2πivw) * Λ_ℂ(v) = (∫₋₁¹ (1-|v|) cos(2πvw) dv : ℂ)

-- The cos integral is our Bridge = sinc²(w).
-- And the sin integral vanishes.

-- To show this, I need:
-- 1. ∫ₓ exp(-2πivw) * Λ_ℂ(v) = ∫ₓ∈[-1,1] exp(-2πivw) * (1-|v| : ℂ)  [support]
-- 2. ∫ₓ∈[-1,1] exp(-2πivw) * (1-|v| : ℂ) = ∫₋₁¹ exp(-2πivw)(1-|v| : ℂ)  [Icc→interval]
-- 3. ∫₋₁¹ exp(-2πivw)(1-|v| : ℂ) = ∫₋₁¹ (cos(2πvw) - i sin(2πvw))(1-|v| : ℂ)
-- 4. = (∫₋₁¹ cos(2πvw)(1-|v|) : ℂ) - i(∫₋₁¹ sin(2πvw)(1-|v|) : ℂ)
-- 5. = (Bridge(w) : ℂ) - i·0 = (sinc²(w) : ℂ)

-- Each step is about 10-20 lines of Lean. Total: ~80 lines.
-- Doable but tedious. Let me start with step 1 (support restriction).

-- SUPPORT RESTRICTION: For |v| > 1, Λ_ℂ(v) = 0
lemma Λ_ℂ_outside (v : ℝ) (hv : 1 < |v|) : Λ_ℂ v = 0 := by
  simp [Λ_ℂ, max_eq_right (show 1 - |v| ≤ 0 by linarith)]

-- SUPPORT RESTRICTION: the integrand vanishes outside [-1,1]
lemma ft_integrand_outside (w v : ℝ) (hv : v ∉ Set.Icc (-1 : ℝ) 1) :
    Complex.exp (↑(-2 * π * (v * w)) * Complex.I) * Λ_ℂ v = 0 := by
  have habs : 1 < |v| := by
    rw [Set.mem_Icc, ← abs_le] at hv
    exact not_le.mp hv
  simp [Λ_ℂ_outside v habs]
