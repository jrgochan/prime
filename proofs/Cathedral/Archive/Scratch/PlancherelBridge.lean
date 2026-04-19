/-
  Scratch: Full proof of l2_fourier_eq_l1_fourier_ae
-/

import Cathedral.MellinBridge.PlancherelDefs
import Mathlib.Analysis.Fourier.LpSpace
import Mathlib.Analysis.Distribution.TemperedDistribution

set_option maxHeartbeats 400000

noncomputable section
open MeasureTheory FourierTransform Real Complex ENNReal
open scoped BigOperators SchwartzMap

-- Distributional identity
lemma l2_fourier_test (f_lp : ℝ →₂[volume] ℂ) (g : 𝓢(ℝ, ℂ)) :
    Lp.toTemperedDistribution (𝓕 f_lp) g =
    Lp.toTemperedDistribution f_lp (𝓕 g) := by
  have h := Lp.fourier_toTemperedDistribution_eq f_lp; rw [← h]; rfl

-- L² → LocallyIntegrable
private lemma lp2_locallyIntegrable (g : ℝ →₂[volume] ℂ) :
    LocallyIntegrable (g : ℝ → ℂ) volume :=
  (Lp.memLp g).locallyIntegrable one_le_two

-- MAIN THEOREM
theorem l2_fourier_eq_l1_fourier_ae_proved (f : ℝ → ℂ)
    (hf1 : Integrable f volume) (hf2 : MemLp f 2 volume) :
    (𝓕 (hf2.toLp f) : ℝ →₂[volume] ℂ) =ᵐ[volume] (𝓕 f : ℝ → ℂ) := by
  have hFf_cont : Continuous (𝓕 f : ℝ → ℂ) :=
    VectorFourier.fourierIntegral_continuous continuous_fourierChar
      (innerSL ℝ).continuous₂ hf1

  -- Step 1: Schwartz test — both transforms give same distribution
  have h_schwartz_test : ∀ φ : 𝓢(ℝ, ℂ),
      ∫ ξ : ℝ, (φ : ℝ → ℂ) ξ • (𝓕 (hf2.toLp f) : ℝ →₂[volume] ℂ) ξ =
      ∫ ξ : ℝ, (φ : ℝ → ℂ) ξ • (𝓕 f : ℝ → ℂ) ξ := by
    intro φ
    have h_l2 := l2_fourier_test (hf2.toLp f) φ
    rw [Lp.toTemperedDistribution_apply, Lp.toTemperedDistribution_apply] at h_l2
    have h_l2_f : ∫ ξ, (φ : ℝ → ℂ) ξ • (𝓕 (hf2.toLp f) : ℝ →₂[volume] ℂ) ξ =
        ∫ x, (𝓕 φ : 𝓢(ℝ, ℂ)) x • f x := by
      rw [h_l2]; apply integral_congr_ae
      filter_upwards [hf2.coeFn_toLp] with x hx; rw [hx]
    have h_l1 := fourier_l1_self_adjoint f (φ : ℝ → ℂ) hf1 φ.integrable
    rw [h_l2_f]; simp only [smul_eq_mul]
    have : ∫ ξ, (φ : ℝ → ℂ) ξ * 𝓕 f ξ = ∫ ξ, 𝓕 f ξ * (φ : ℝ → ℂ) ξ := by
      congr 1; ext ξ; exact mul_comm _ _
    rw [this, h_l1]; congr 1; ext x; exact mul_comm _ _

  -- Step 2: Use ae_eq_of_integral_contDiff_smul_eq
  exact ae_eq_of_integral_contDiff_smul_eq
    (lp2_locallyIntegrable (𝓕 (hf2.toLp f)))
    hFf_cont.locallyIntegrable
    (fun g hg_smooth hg_compact => by
      -- Promote (g : ℝ → ℝ) to Schwartz (ℝ, ℂ)
      set g_c : ℝ → ℂ := (↑) ∘ g
      -- hg_smooth : ContDiff ℝ ∞ g (where ∞ might be ↑⊤ in WithTop ℕ∞)
      -- ofRealCLM.contDiff gives ContDiff for any n, so .comp matches
      have hg_c_smooth := ofRealCLM.contDiff.comp hg_smooth
      have hg_c_compact : HasCompactSupport g_c := hg_compact.comp_left ofReal_zero
      set φ := hg_c_compact.toSchwartzMap hg_c_smooth
      -- g(x) • z = φ(x) • z since g(x) • z = (g(x) : ℂ) * z = φ(x) * z
      show ∫ x, (φ : ℝ → ℂ) x • (𝓕 (hf2.toLp f) : ℝ →₂[volume] ℂ) x =
           ∫ x, (φ : ℝ → ℂ) x • 𝓕 f x
      exact h_schwartz_test φ)

end
