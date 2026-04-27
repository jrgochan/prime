-- Scratch: Graduate all 4 routine sorry
import Mathlib.Analysis.Fourier.FourierTransform
import Mathlib.Analysis.SpecialFunctions.Trigonometric.Basic
import Mathlib.Analysis.Complex.Trigonometric
import Mathlib.Analysis.Complex.Basic
import Mathlib.MeasureTheory.Integral.Bochner.Basic
import Mathlib.MeasureTheory.Integral.Bochner.Set
import Mathlib.MeasureTheory.Integral.IntervalIntegral.Basic
import Mathlib.Topology.ContinuousMap.Compact

open MeasureTheory Real Complex Set
open scoped FourierTransform

noncomputable section

-- Helper: the real-valued cos integrand is continuous
private lemma continuous_cos_integrand (w : ℝ) :
    Continuous (fun v => Real.cos (-2 * π * (v * w)) * (1 - |v|)) :=
  (Real.continuous_cos.comp (continuous_const.mul
    (continuous_id.mul continuous_const))).mul
    (continuous_const.sub continuous_abs)

-- Helper: the real-valued sin integrand is continuous
private lemma continuous_sin_integrand (w : ℝ) :
    Continuous (fun v => Real.sin (-2 * π * (v * w)) * (1 - |v|)) :=
  (Real.continuous_sin.comp (continuous_const.mul
    (continuous_id.mul continuous_const))).mul
    (continuous_const.sub continuous_abs)

-- 1. cos_ofReal_integrableOn
lemma cos_ofReal_integrableOn (w : ℝ) :
    IntegrableOn
      (fun v => (↑(Real.cos (-2 * π * (v * w)) * (1 - |v|)) : ℂ))
      (Icc (-1 : ℝ) 1) :=
  (Complex.continuous_ofReal.comp (continuous_cos_integrand w)).continuousOn.integrableOn_compact
    isCompact_Icc

-- 2. sin_ofReal_integrableOn
lemma sin_ofReal_integrableOn (w : ℝ) :
    IntegrableOn
      (fun v => (↑(Real.sin (-2 * π * (v * w)) * (1 - |v|)) : ℂ))
      (Icc (-1 : ℝ) 1) :=
  (Complex.continuous_ofReal.comp (continuous_sin_integrand w)).continuousOn.integrableOn_compact
    isCompact_Icc

-- 3. sinI_ofReal_integrableOn
lemma sinI_ofReal_integrableOn (w : ℝ) :
    IntegrableOn
      (fun v => ↑(Real.sin (-2 * π * (v * w)) * (1 - |v|)) * Complex.I)
      (Icc (-1 : ℝ) 1) :=
  (sin_ofReal_integrableOn w).mul_const _

-- 4. sin_integral_vanishes
lemma sin_integral_vanishes (w : ℝ) :
    ∫ v in Icc (-1 : ℝ) 1,
      (Real.sin (-2 * π * (v * w)) * (1 - |v|)) = 0 := by
  -- f(-v) = -f(v)
  set f := fun v => Real.sin (-2 * π * (v * w)) * (1 - |v|) with hf_def
  have h_odd : ∀ v : ℝ, f (-v) = -f v := by
    intro v; simp only [hf_def]
    rw [show -2 * π * ((-v) * w) = -(-2 * π * (v * w)) from by ring,
        Real.sin_neg, abs_neg, neg_mul]
  -- Convert Icc → Ioc → interval integral
  rw [integral_Icc_eq_integral_Ioc,
      ← intervalIntegral.integral_of_le (by norm_num : (-1 : ℝ) ≤ 1)]
  -- ∫_{-1}^{1} f(v) dv = ∫_{-1}^{1} f(-v) dv  by integral_comp_neg
  have h_eq : (∫ v in (-1 : ℝ)..1, f v) =
      ∫ v in (-1 : ℝ)..1, f (-v) := by
    have h1 : (∫ v in (-1 : ℝ)..1, f (-v)) = ∫ v in -1..-(-1 : ℝ), f v :=
      intervalIntegral.integral_comp_neg f
    rw [h1, neg_neg]
  -- ∫ f = ∫ f(-·) = ∫ (-f) = -∫ f,  so 2∫ f = 0
  have h_neg : (∫ v in (-1 : ℝ)..1, f (-v)) = -(∫ v in (-1 : ℝ)..1, f v) := by
    have : (fun v => f (-v)) = (fun v => -f v) := funext h_odd
    rw [show (∫ v in (-1 : ℝ)..1, f (-v)) = (∫ v in (-1 : ℝ)..1, (fun v => f (-v)) v) from rfl,
        this]
    exact intervalIntegral.integral_neg
  linarith [h_eq, h_neg]
