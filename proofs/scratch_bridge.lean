-- Scratch: Close ALL sub-lemmas
import Mathlib.Analysis.Fourier.FourierTransform
import Mathlib.Analysis.Fourier.Inversion
import Mathlib.Analysis.SpecialFunctions.Trigonometric.Basic
import Mathlib.Analysis.SpecialFunctions.Trigonometric.Sinc
import Mathlib.Analysis.SpecialFunctions.ImproperIntegrals
import Mathlib.MeasureTheory.Integral.Bochner.Basic
import Mathlib.MeasureTheory.Function.LocallyIntegrable

open MeasureTheory Real Complex
open scoped FourierTransform

noncomputable section

def Λ_ℂ (ξ : ℝ) : ℂ := ((max (1 - |ξ|) 0 : ℝ) : ℂ)

-- Continuous
lemma Λ_ℂ_continuous : Continuous Λ_ℂ := by
  unfold Λ_ℂ
  exact continuous_ofReal.comp ((continuous_const.sub continuous_abs).max continuous_const)

-- Has compact support: Λ_ℂ(ξ) = 0 for |ξ| > 1 ⇒ tsupport ⊂ [-1,1]
lemma Λ_ℂ_hasCompactSupport : HasCompactSupport Λ_ℂ := by
  rw [hasCompactSupport_def]
  -- tsupport ⊂ [-1,1] which is compact
  apply IsCompact.of_isClosed_subset isCompact_Icc isClosed_closure
  exact closure_minimal (show Function.support Λ_ℂ ⊆ Set.Icc (-1) 1 from by
    intro ξ hξ
    simp only [Function.mem_support, ne_eq] at hξ
    rw [Set.mem_Icc]
    -- If ξ ∉ [-1,1], then |ξ| > 1, so Λ_ℂ ξ = 0.
    -- Equivalently: Λ_ℂ ξ ≠ 0 → ξ ∈ [-1,1]
    -- max(1-|ξ|, 0) ≠ 0 → 1-|ξ| > 0 → |ξ| < 1 → -1 < ξ < 1 → -1 ≤ ξ ∧ ξ ≤ 1
    have h : (0 : ℝ) < max (1 - |ξ|) 0 := by
      have : (max (1 - |ξ|) 0 : ℝ) ≠ 0 := by
        intro heq
        apply hξ
        show Λ_ℂ ξ = 0
        simp [Λ_ℂ, heq]
      exact lt_of_le_of_ne (le_max_right _ _) (Ne.symm this)
    have h2 : 0 < 1 - |ξ| := by
      by_contra h3
      push_neg at h3
      linarith [le_max_right (1 - |ξ|) (0 : ℝ), max_eq_right h3]
    exact ⟨by linarith [neg_abs_le ξ], by linarith [le_abs_self ξ]⟩) isClosed_Icc

-- Integrable
lemma Λ_ℂ_integrable : Integrable Λ_ℂ (volume : Measure ℝ) :=
  Λ_ℂ_continuous.integrable_of_hasCompactSupport Λ_ℂ_hasCompactSupport

-- FK3 chain
lemma Λ_ℂ_zero : Λ_ℂ 0 = 1 := by simp [Λ_ℂ]

lemma fourier_at_zero (f : ℝ → ℂ) : 𝓕 f 0 = ∫ v : ℝ, f v := by
  simp [Real.fourier_eq]

-- FK3: ∫ (𝓕⁻ Λ_ℂ)(x) dx = 1
-- Using fourier_fourierInv_eq at v=0
-- Still needs: Integrable (𝓕 Λ_ℂ) — the Bridge matching
lemma integral_fourierInv_Λ (h_ft_int : Integrable (𝓕 Λ_ℂ) (volume : Measure ℝ)) :
    ∫ x : ℝ, 𝓕⁻ Λ_ℂ x = 1 := by
  have h1 := Λ_ℂ_integrable.fourier_fourierInv_eq h_ft_int
    Λ_ℂ_continuous.continuousAt (v := (0 : ℝ))
  rw [Λ_ℂ_zero] at h1
  rw [fourier_at_zero] at h1
  exact h1
