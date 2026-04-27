-- Scratch: FULL bridge matching assembly
import Mathlib.Analysis.Fourier.FourierTransform
import Mathlib.Analysis.SpecialFunctions.Trigonometric.Basic
import Mathlib.Analysis.Complex.Trigonometric
import Mathlib.MeasureTheory.Integral.Bochner.Basic
import Mathlib.MeasureTheory.Integral.Bochner.Set
import Mathlib.MeasureTheory.Integral.IntervalIntegral.Basic

open MeasureTheory Real Complex
open scoped FourierTransform

noncomputable section

def Λ_ℂ (ξ : ℝ) : ℂ := ((max (1 - |ξ|) 0 : ℝ) : ℂ)

axiom fejerKernel : ℝ → ℝ
axiom fejerKernel_integrable : Integrable fejerKernel (volume : Measure ℝ)
axiom bridge_theorem (x : ℝ) :
  ∫ ξ in Set.Icc (-1 : ℝ) 1,
    ((1 - |ξ|) * Real.cos (2 * π * x * ξ)) = fejerKernel x

-- Proven building blocks
lemma ft_Λ_ℂ_unfold (w : ℝ) :
    𝓕 Λ_ℂ w = ∫ v : ℝ,
      Complex.exp (↑(-2 * π * (v * w)) * Complex.I) * Λ_ℂ v := by
  rw [fourier_eq']; congr 1; ext v; congr 1; congr 1; simp; ring

lemma Λ_ℂ_outside (v : ℝ) (hv : 1 < |v|) : Λ_ℂ v = 0 := by
  simp [Λ_ℂ, max_eq_right (show 1 - |v| ≤ 0 by linarith)]

lemma ft_Λ_ℂ_restrict (w : ℝ) :
    𝓕 Λ_ℂ w = ∫ v in Set.Icc (-1 : ℝ) 1,
      Complex.exp (↑(-2 * π * (v * w)) * Complex.I) * Λ_ℂ v := by
  rw [ft_Λ_ℂ_unfold, ← setIntegral_eq_integral_of_forall_compl_eq_zero]
  intro v hv
  have : 1 < |v| := by rw [Set.mem_Icc, ← abs_le] at hv; exact not_le.mp hv
  simp [Λ_ℂ_outside v this]

lemma Λ_ℂ_on_Icc (v : ℝ) (hv : v ∈ Set.Icc (-1 : ℝ) 1) :
    Λ_ℂ v = ((1 - |v|) : ℂ) := by
  rw [Set.mem_Icc] at hv
  have hab : |v| ≤ 1 := abs_le.mpr ⟨by linarith [hv.1], hv.2⟩
  show ((max (1 - |v|) 0 : ℝ) : ℂ) = ((1 - |v|) : ℂ)
  simp [max_def, sub_nonneg.mpr hab]

-- Euler decomposition key identity
lemma euler_mul_real (θ r : ℝ) :
    Complex.exp (↑θ * Complex.I) * (↑r : ℂ) =
    ↑(Real.cos θ * r) + ↑(Real.sin θ * r) * Complex.I := by
  rw [Complex.exp_mul_I]
  simp [Complex.ofReal_cos, Complex.ofReal_sin]
  ring

-- NOW: Full proof.
-- The key insight: use the building blocks to reduce to a sorry
-- that is just "the integral of cos equals Bridge"

lemma ft_Λ_ℂ_eq_fejerKernel (w : ℝ) :
    𝓕 Λ_ℂ w = ((fejerKernel w : ℝ) : ℂ) := by
  -- Step 1: Restrict to [-1,1]
  rw [ft_Λ_ℂ_restrict]
  -- Step 2: Replace Λ_ℂ with (1-|v|) on [-1,1]
  -- Step 3: Apply Euler's formula
  -- Step 4: Split integral, identify cos = Bridge, sin = 0
  -- The integral equals:
  -- ∫ v ∈ [-1,1], ↑(cos(-2πvw)(1-|v|)) + ↑(sin(-2πvw)(1-|v|)) * I
  -- = ↑(∫ cos(-2πvw)(1-|v|)) + ↑(∫ sin(-2πvw)(1-|v|)) * I
  -- = ↑(∫ cos(2πwv)(1-|v|)) + ↑(0) * I     [cos even, sin→0]
  -- = ↑(Bridge(w)) = ↑(fejerKernel w)

  -- For now, let me try a calc chain:
  calc ∫ v in Set.Icc (-1 : ℝ) 1,
      Complex.exp (↑(-2 * π * (v * w)) * Complex.I) * Λ_ℂ v
    = ∫ v in Set.Icc (-1 : ℝ) 1,
      Complex.exp (↑(-2 * π * (v * w)) * Complex.I) * ((1 - |v|) : ℂ) := by
        refine setIntegral_congr_fun measurableSet_Icc (fun v hv => ?_)
        rw [Λ_ℂ_on_Icc v hv]
    _ = ∫ v in Set.Icc (-1 : ℝ) 1,
      (↑(Real.cos (-2 * π * (v * w)) * (1 - |v|)) +
       ↑(Real.sin (-2 * π * (v * w)) * (1 - |v|)) * Complex.I) := by
        refine setIntegral_congr_fun measurableSet_Icc (fun v _ => ?_)
        convert euler_mul_real (-2 * π * (v * w)) (1 - |v|) using 1
        simp
    _ = ((fejerKernel w : ℝ) : ℂ) := by
        -- Split the integral of (a + b*I) into ∫a + (∫b)*I
        -- ∫a = ↑(∫ cos * Λ) = ↑(Bridge(w)) = ↑(fejerKernel w)
        -- ∫b = ↑(∫ sin * Λ) = ↑(0) = 0 (odd function on symmetric interval)
        -- So total = ↑(fejerKernel w) + 0 * I = ↑(fejerKernel w)

        -- The integral of (↑f + ↑g * I) over a set equals
        -- ↑(∫ f) + ↑(∫ g) * I (by integral linearity)

        -- Let me use Bridge directly:
        -- cos(-θ) = cos(θ), so cos(-2πvw) = cos(2πvw)
        -- Also cos(2πvw)(1-|v|) = (1-|v|) cos(2πxv) with x = w  (multiply order)
        -- Bridge: ∫ (1-|v|) cos(2πwv) dv = fejerKernel(w)

        -- For the sin part: sin(-θ) = -sin(θ)
        -- sin(-2πvw)(1-|v|) is an odd function of v on [-1,1]
        -- So its integral = 0

        sorry
