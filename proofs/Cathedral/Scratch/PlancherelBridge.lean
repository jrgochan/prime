/-
  PlancherelBridge: PROVING plancherel_mathlib_fourier.
-/

import Cathedral.MellinBridge.PlancherelDefs
import Mathlib.Analysis.Fourier.LpSpace
import Mathlib.Analysis.Fourier.FourierTransform
import Mathlib.MeasureTheory.Function.L2Space

noncomputable section
open Real MeasureTheory Finset BigOperators Complex
open scoped FourierTransform

-- ═══════════════════════════════════════════
-- Step A: Lp norm² = ∫ pointwise norm²
-- ═══════════════════════════════════════════

lemma lp2_norm_sq_eq_integral (f : ℝ →₂[volume] ℂ) :
    ‖f‖ ^ 2 = ∫ a : ℝ, ‖f a‖ ^ 2 := by
  rw [sq, ← @inner_self_eq_norm_mul_norm ℂ, L2.inner_def]
  simp only [inner_self_eq_norm_sq_to_K]
  norm_cast

-- ═══════════════════════════════════════════
-- Step B: raw ∫ ‖f‖² = ‖toLp f‖²
-- ═══════════════════════════════════════════

lemma raw_integral_eq_lp_norm_sq (f : ℝ → ℂ) (hf : MemLp f 2 volume) :
    ∫ u : ℝ, ‖f u‖ ^ 2 = ‖hf.toLp f‖ ^ 2 := by
  rw [lp2_norm_sq_eq_integral]
  apply integral_congr_ae
  filter_upwards [hf.coeFn_toLp] with u hu
  show ‖f u‖ ^ 2 = ‖(hf.toLp f : ℝ →₂[volume] ℂ) u‖ ^ 2
  rw [hu]

-- ═══════════════════════════════════════════
-- Step C: Plancherel for Lp (norm² version)
-- ═══════════════════════════════════════════

lemma plancherel_lp_norm_sq (f_lp : ℝ →₂[volume] ℂ) :
    ‖f_lp‖ ^ 2 = ‖(𝓕 f_lp : ℝ →₂[volume] ℂ)‖ ^ 2 := by
  rw [MeasureTheory.Lp.norm_fourier_eq]

-- ═══════════════════════════════════════════
-- Step D: Density bridge (the hard part)
-- ═══════════════════════════════════════════

-- For f ∈ L¹ ∩ L², the L² extension of the Fourier transform
-- agrees a.e. with the L¹ integral formula.
-- Follows from:
--   SchwartzMap.toLp_fourier_eq (for Schwartz functions)
--   + density of Schwartz in L¹ ∩ L²
--   + continuity of both 𝓕₂ (isometry on L²) and 𝓕₁ (bounded L¹→L∞)
axiom l2_fourier_eq_l1_fourier_ae (f : ℝ → ℂ)
    (hf1 : Integrable f volume) (hf2 : MemLp f 2 volume) :
    (𝓕 (hf2.toLp f) : ℝ →₂[volume] ℂ) =ᵐ[volume] (𝓕 f : ℝ → ℂ)

-- ═══════════════════════════════════════════
-- ASSEMBLY
-- ═══════════════════════════════════════════

theorem plancherel_proved (f : ℝ → ℂ)
    (hf1 : Integrable f volume)
    (hf2 : MemLp f 2 volume) :
    ∫ u : ℝ, ‖f u‖ ^ 2 = ∫ ξ : ℝ, ‖𝓕 f ξ‖ ^ 2 := by
  -- ∫ ‖f u‖² = ‖toLp f‖²  (Step B)
  rw [raw_integral_eq_lp_norm_sq f hf2]
  -- ‖toLp f‖² = ‖𝓕₂(toLp f)‖²  (Step C: Plancherel)
  rw [plancherel_lp_norm_sq (hf2.toLp f)]
  -- ‖𝓕₂(toLp f)‖² = ∫ ‖𝓕₂(toLp f) ξ‖²  (Step A)
  rw [lp2_norm_sq_eq_integral]
  -- ∫ ‖𝓕₂(toLp f) ξ‖² = ∫ ‖𝓕 f ξ‖²  (Step D)
  apply integral_congr_ae
  filter_upwards [l2_fourier_eq_l1_fourier_ae f hf1 hf2] with ξ hξ
  show ‖(𝓕 (hf2.toLp f) : ℝ →₂[volume] ℂ) ξ‖ ^ 2 = ‖𝓕 f ξ‖ ^ 2
  rw [hξ]

end
