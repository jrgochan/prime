-- Scratch: FULL PROOF — integral_ofReal + integral_smul_const
import Mathlib.Analysis.Fourier.FourierTransform
import Mathlib.Analysis.SpecialFunctions.Trigonometric.Basic
import Mathlib.Analysis.Complex.Trigonometric
import Mathlib.Analysis.Complex.Basic
import Mathlib.MeasureTheory.Integral.Bochner.Basic
import Mathlib.MeasureTheory.Integral.Bochner.Set
import Mathlib.MeasureTheory.Integral.Bochner.ContinuousLinearMap
import Mathlib.MeasureTheory.Integral.IntervalIntegral.Basic

open MeasureTheory Real Complex
open scoped FourierTransform

noncomputable section

axiom fejerKernel : ℝ → ℝ
axiom bridge_cos (w : ℝ) :
  ∫ v in Set.Icc (-1 : ℝ) 1,
    (Real.cos (-2 * π * (v * w)) * (1 - |v|)) = fejerKernel w
axiom sin_vanish (w : ℝ) :
  ∫ v in Set.Icc (-1 : ℝ) 1,
    (Real.sin (-2 * π * (v * w)) * (1 - |v|)) = 0

axiom cos_integrable_on (w : ℝ) :
  IntegrableOn (fun v => (↑(Real.cos (-2 * π * (v * w)) * (1 - |v|)) : ℂ))
    (Set.Icc (-1 : ℝ) 1)
axiom sinI_integrable_on (w : ℝ) :
  IntegrableOn (fun v => ↑(Real.sin (-2 * π * (v * w)) * (1 - |v|)) * Complex.I)
    (Set.Icc (-1 : ℝ) 1)
axiom sin_ofReal_integrableOn (w : ℝ) :
  IntegrableOn (fun v => (↑(Real.sin (-2 * π * (v * w)) * (1 - |v|)) : ℂ))
    (Set.Icc (-1 : ℝ) 1)

lemma the_last_sorry (w : ℝ) :
    ∫ v in Set.Icc (-1 : ℝ) 1,
        (↑(Real.cos (-2 * π * (v * w)) * (1 - |v|)) +
         ↑(Real.sin (-2 * π * (v * w)) * (1 - |v|)) * Complex.I) =
    ((fejerKernel w : ℝ) : ℂ) := by
  -- Step 1: Split and convert everything
  rw [integral_add (cos_integrable_on w) (sinI_integrable_on w)]
  -- Handle cos part: ∫ ↑f = ↑(∫ f)
  have h_cos : ∫ v in Set.Icc (-1 : ℝ) 1,
      (↑(Real.cos (-2 * π * (v * w)) * (1 - |v|)) : ℂ) =
    ↑(fejerKernel w) := by
    rw [← bridge_cos w]
    exact integral_ofReal
  rw [h_cos]
  have h_sin : ∫ v in Set.Icc (-1 : ℝ) 1,
      (↑(Real.sin (-2 * π * (v * w)) * (1 - |v|)) : ℂ) * Complex.I = 0 := by
    rw [integral_mul_const_of_integrable (sin_ofReal_integrableOn w)]
    -- Goal: (∫ ↑g) * I = 0
    -- ∫ ↑g = ↑(∫ g) = ↑(0) = 0, so 0 * I = 0
    have : ∫ v in Set.Icc (-1 : ℝ) 1,
        (↑(Real.sin (-2 * π * (v * w)) * (1 - |v|)) : ℂ) =
      ↑(0 : ℝ) := by
      rw [← sin_vanish w]; exact integral_ofReal
    rw [this]; simp
  rw [h_sin, add_zero]
