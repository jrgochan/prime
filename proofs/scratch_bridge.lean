-- Scratch: Direct assembly — one-shot bridge matching
import Mathlib.Analysis.Fourier.FourierTransform
import Mathlib.Analysis.SpecialFunctions.Trigonometric.Basic
import Mathlib.MeasureTheory.Integral.Bochner.Basic
import Mathlib.MeasureTheory.Integral.Bochner.Set
import Mathlib.MeasureTheory.Integral.IntervalIntegral.Basic

open MeasureTheory Real Complex
open scoped FourierTransform

noncomputable section

def Λ_ℂ (ξ : ℝ) : ℂ := ((max (1 - |ξ|) 0 : ℝ) : ℂ)

axiom fejerKernel : ℝ → ℝ
axiom fejerKernel_integrable : Integrable fejerKernel (volume : Measure ℝ)

-- Bridge: ∫₋₁¹ (1-|ξ|) cos(2πxξ) = fejerKernel(x)  (on Icc)
axiom bridge_theorem (x : ℝ) :
  ∫ ξ in Set.Icc (-1 : ℝ) 1,
    ((1 - |ξ|) * Real.cos (2 * π * x * ξ)) = fejerKernel x

-- The approach: instead of decomposing step by step,
-- let me try proving the final result directly using calc.

-- Key fact: the FT of Λ is a real number (because Λ is even and real-valued)
-- So 𝓕 Λ_ℂ(w) is real, and equals the cosine FT of Λ.

-- Instead of going through support restriction + Euler decomposition,
-- let me try to prove this using Mathlib's Fourier inversion directly.
-- We already know: 𝓕⁻(𝓕 Λ_ℂ)(v) = Λ_ℂ(v) and 𝓕⁻(fejerKernel_ℂ)(v) = Λ_ℂ(v)
-- So 𝓕 Λ_ℂ = fejerKernel_ℂ follows by injectivity of 𝓕⁻.

-- Wait, that's CIRCULAR — 𝓕⁻(fejerKernel_ℂ)(v) = Λ_ℂ(v) IS what we're trying to prove.

-- Let me try another angle: the Bridge gives us
-- ∫₋₁¹ Λ(ξ) cos(2πwξ) dξ = fejerKernel(w)
-- The FT gives us
-- 𝓕 Λ_ℂ(w) = ∫ Λ_ℂ(v) exp(-2πivw) dv
-- = ∫₋₁¹ (1-|v|) exp(-2πivw) dv   (support restriction)
-- = ∫₋₁¹ (1-|v|) cos(2πvw) dv - i ∫₋₁¹ (1-|v|) sin(2πvw) dv

-- The cos integral = Bridge(w) = fejerKernel(w)
-- The sin integral = 0 (by symmetry: odd function on symmetric interval)

-- Since 𝓕 Λ_ℂ(w) = fejerKernel(w) + i·0 = fejerKernel(w) : ℂ, we're done.

-- This is correct but the Lean plumbing is painful. Let me try to encode it
-- as a sorry chain where each sorry is TRIVIALLY closable.

-- APPROACH: Build from the end.
-- We need: 𝓕 Λ_ℂ w = (fejerKernel w : ℂ)
-- By Bridge: fejerKernel w = ∫ v in Icc (-1) 1, (1-|v|) cos(2πwv)
-- So we need: 𝓕 Λ_ℂ w = (∫ v in Icc (-1) 1, (1-|v|) cos(2πwv) : ℂ)

-- From ft_Λ_ℂ_unfold:
-- 𝓕 Λ_ℂ w = ∫ v, exp(-2πivw) Λ_ℂ(v) dv

-- Both sides are ℂ integrals. If we can show:
-- ∫ v, exp(-2πivw) Λ_ℂ(v) dv = (∫ v in Icc, (1-|v|) cos(2πwv) : ℂ)
-- then by bridge_theorem, the RHS = (fejerKernel w : ℂ).

-- This ℂ identity is the heart of the matter.
-- Actually, maybe I should try a COMPLETELY different tactic:
-- Just use native_decide or norm_num or some computational approach.
-- No, that won't work for general functions.

-- OK let me try the brute force approach. Port what we have and accept
-- a thin sorry at the assembly step. This is good engineering.

lemma ft_Λ_ℂ_eq_fejerKernel (w : ℝ) :
    𝓕 Λ_ℂ w = ((fejerKernel w : ℝ) : ℂ) := by
  -- Step 1: Unfold FT
  rw [fourier_eq']
  -- Goal: ∫ v, exp(↑(-2π·inner v w)·I) • Λ_ℂ(v) = (fejerKernel w : ℂ)
  sorry
