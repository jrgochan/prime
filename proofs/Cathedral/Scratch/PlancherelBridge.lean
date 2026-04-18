/-
  Scratch: Full proof of l2_fourier_test_schwartz
-/

import Cathedral.MellinBridge.PlancherelDefs
import Mathlib.Analysis.Fourier.LpSpace
import Mathlib.Analysis.Distribution.TemperedDistribution

noncomputable section
open MeasureTheory FourierTransform Real Complex
open scoped BigOperators SchwartzMap

-- The key distributional identity:
-- For f ∈ L² and g Schwartz,
-- ∫ g(ξ) • (𝓕₂ f)(ξ) dξ = ∫ (𝓕 g)(x) • f(x) dx

-- Note: For Schwartz g, 𝓕 g is also Schwartz (𝓢 → 𝓢).
-- The coercion 𝓢(ℝ, ℂ) → (ℝ → ℂ) is via SchwartzMap.FunLike.

lemma l2_fourier_test_schwartz (f_lp : ℝ →₂[volume] ℂ) (g : 𝓢(ℝ, ℂ)) :
    Lp.toTemperedDistribution (𝓕 f_lp) g =
    Lp.toTemperedDistribution f_lp (𝓕 g) := by
  -- fourier_toTemperedDistribution_eq says:
  -- 𝓕 (Lp.toTemperedDistribution f_lp) = Lp.toTemperedDistribution (𝓕 f_lp)
  have h := Lp.fourier_toTemperedDistribution_eq f_lp
  -- So: Lp.toTemperedDistribution (𝓕 f_lp) g
  --   = (𝓕 (Lp.toTemperedDistribution f_lp)) g    [by h]
  --   = Lp.toTemperedDistribution f_lp (𝓕 g)       [by defn of distributional 𝓕]
  rw [← h]
  -- Goal: (𝓕 (Lp.toTemperedDistribution f_lp)) g = Lp.toTemperedDistribution f_lp (𝓕 g)
  rfl

-- This tells us:
-- ∫ g(ξ) • (𝓕₂ f_lp)(ξ) dξ = ∫ (𝓕 g)(x) • f_lp(x) dx
-- by Lp.toTemperedDistribution_apply on both sides.

-- Now expanding via toTemperedDistribution_apply:
-- LHS = ∫ g(ξ) • (𝓕₂ f_lp : ℝ →₂[volume] ℂ)(ξ) dξ
-- RHS = ∫ (𝓕 g : 𝓢(ℝ, ℂ))(x) • (f_lp : ℝ →₂[volume] ℂ)(x) dx

-- For the Fubini side: we need
-- ∫ g(ξ) • (𝓕₁ f)(ξ) dξ = ∫ (𝓕 g)(x) • f(x) dx
-- which is fourier_l1_self_adjoint f g (with smul = * for ℂ).

-- The conclusion: ∫ g • 𝓕₂(f.toLp) = ∫ g • 𝓕₁(f) for all Schwartz g.

-- Let me check what toTemperedDistribution_apply produces
#check @Lp.toTemperedDistribution_apply ℝ ℂ
-- toTemperedDistribution_apply f g = ∫ x, g x • ↑↑f x

end
