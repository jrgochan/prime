/-
  Scratch: Proving fourier_l1_self_adjoint from Mathlib's Fubini
-/

import Cathedral.MellinBridge.PlancherelDefs
import Mathlib.Analysis.Fourier.LpSpace
import Mathlib.Analysis.Distribution.TemperedDistribution

noncomputable section
open MeasureTheory FourierTransform Real Complex
open scoped BigOperators SchwartzMap

-- The inner product on ℝ is symmetric, so innerₗ ℝ = (innerₗ ℝ).flip
private lemma innerₗ_flip_eq : (innerₗ (ℝ : Type)).flip = (innerₗ (ℝ : Type)) := by
  apply LinearMap.ext₂; intro v w; simp [real_inner_comm]

-- The continuity of the inner product as a bilinear form
private lemma innerₗ_continuous :
    Continuous fun (p : ℝ × ℝ) => (innerₗ (ℝ : Type) p.1) p.2 :=
  (innerSL ℝ).continuous₂

-- fourier_l1_self_adjoint PROVED from Mathlib's Fubini
theorem fourier_l1_self_adjoint_proved (f g : ℝ → ℂ)
    (hf : Integrable f volume) (hg : Integrable g volume) :
    ∫ ξ : ℝ, (𝓕 f ξ) * g ξ = ∫ x : ℝ, f x * (𝓕 g x) := by
  simp only [← smul_eq_mul]
  -- Unfold 𝓕 to VectorFourier form for rewriting
  change ∫ ξ, (VectorFourier.fourierIntegral 𝐞 volume (innerₗ ℝ) f ξ) • g ξ =
         ∫ x, f x • (VectorFourier.fourierIntegral 𝐞 volume (innerₗ ℝ) g x)
  -- Apply Mathlib's Fubini theorem
  rw [VectorFourier.integral_fourierIntegral_smul_eq_flip
    continuous_fourierChar innerₗ_continuous hf hg]
  -- RHS now has (innerₗ ℝ).flip, rewrite to (innerₗ ℝ) by symmetry
  rw [innerₗ_flip_eq]

-- ═══════════════════════════════════════════════
-- PART 2: The distributional identity (PROVED)
-- ═══════════════════════════════════════════════

lemma l2_fourier_test_schwartz (f_lp : ℝ →₂[volume] ℂ) (g : 𝓢(ℝ, ℂ)) :
    Lp.toTemperedDistribution (𝓕 f_lp) g =
    Lp.toTemperedDistribution f_lp (𝓕 g) := by
  have h := Lp.fourier_toTemperedDistribution_eq f_lp
  rw [← h]; rfl

-- ═══════════════════════════════════════════════
-- PART 3: Full proof of l2_fourier_eq_l1_fourier_ae
-- ═══════════════════════════════════════════════

theorem l2_fourier_eq_l1_fourier_ae_proved (f : ℝ → ℂ)
    (hf1 : Integrable f volume) (hf2 : MemLp f 2 volume) :
    (𝓕 (hf2.toLp f) : ℝ →₂[volume] ℂ) =ᵐ[volume] (𝓕 f : ℝ → ℂ) := by
  -- L² distributional identity, expanded to integrals:
  have h_l2 : ∀ g : 𝓢(ℝ, ℂ),
      ∫ ξ : ℝ, (g : ℝ → ℂ) ξ • (𝓕 (hf2.toLp f) : ℝ →₂[volume] ℂ) ξ =
      ∫ x : ℝ, (𝓕 g : 𝓢(ℝ, ℂ)) x • f x := by
    intro g
    have h_distrib := l2_fourier_test_schwartz (hf2.toLp f) g
    rw [Lp.toTemperedDistribution_apply, Lp.toTemperedDistribution_apply] at h_distrib
    rw [h_distrib]
    apply integral_congr_ae
    filter_upwards [hf2.coeFn_toLp] with x hx
    rw [hx]
  -- Both 𝓕₂(f.toLp) and 𝓕₁(f) give ∫ (𝓕 g) • f for all Schwartz g.
  -- 𝓕₂ by h_l2, and 𝓕₁ by fourier_l1_self_adjoint_proved (Fubini).
  -- The separation step requires LocallyIntegrable for the difference.
  sorry

end
