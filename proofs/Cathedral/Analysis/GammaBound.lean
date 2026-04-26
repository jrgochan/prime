/-
  Cathedral/Analysis/GammaBound.lean

  ## Gamma Function Norm Bounds via Reflection Formula

  Key results for bounding |Γ(s)| in the critical strip.

  ### Dependencies: Mathlib (Gamma, reflection formula, trig)
-/

import Mathlib.Analysis.SpecialFunctions.Gamma.Beta
import Mathlib.Analysis.SpecialFunctions.Gamma.Deligne
import Mathlib.Analysis.SpecialFunctions.Trigonometric.Complex
import Mathlib.Analysis.SpecialFunctions.Trigonometric.Basic
import Mathlib.Analysis.Complex.Norm

noncomputable section
open Complex Real MeasureTheory Set

-- ════════════════════════════════════════════════════
-- §1. |Γ(σ+it)| ≤ Γ(σ) for σ > 0
-- ════════════════════════════════════════════════════

/-- |Γ(s)| ≤ Γ(Re(s)) for Re(s) > 0, from the integral representation.
    From Γ(s) = ∫ t^{s-1} e^{-t} dt and |t^{s-1}| = t^{σ-1} for t > 0,
    we get |Γ(s)| ≤ ∫ t^{σ-1} e^{-t} dt = Γ(σ). -/
theorem norm_Gamma_le_Gamma_re {s : ℂ} (hs : 0 < s.re) :
    ‖Complex.Gamma s‖ ≤ Real.Gamma s.re := by
  -- Step 1: Γ(s) = GammaIntegral(s) = ∫ t ∈ Ioi 0, exp(-t) · t^(s-1)
  rw [Complex.Gamma_eq_integral hs]
  -- Step 2: Γ(σ) = ∫ t ∈ Ioi 0, exp(-t) · t^(σ-1)
  rw [Real.Gamma_eq_integral hs]
  -- GammaIntegral s = ∫ x in Ioi 0, ↑(exp(-x)) * ↑x ^ (s - 1)
  unfold Complex.GammaIntegral
  -- ‖∫ f‖ ≤ ∫ ‖f‖ ≤ ∫ g when ‖f‖ ≤ g a.e.
  refine le_trans (norm_integral_le_integral_norm _) ?_
  apply MeasureTheory.setIntegral_mono_on
  · -- integrability of ‖f‖
    exact (Complex.GammaIntegral_convergent hs).norm
  · -- integrability of g
    exact Real.GammaIntegral_convergent hs
  · exact measurableSet_Ioi
  · -- pointwise: ‖exp(-x) * x^(s-1)‖ = exp(-x) * x^(σ-1) for x > 0
    intro x hx
    rw [Set.mem_Ioi] at hx
    apply le_of_eq
    simp only [norm_mul, Complex.norm_of_nonneg (le_of_lt (Real.exp_pos (-x))),
        norm_cpow_eq_rpow_re_of_pos hx, sub_re, one_re]

-- ════════════════════════════════════════════════════
-- §2. |sin(z)| ≤ cosh(Im(z))
-- ════════════════════════════════════════════════════

/-- normSq(sin z) = sin²(Re z)·cosh²(Im z) + cos²(Re z)·sinh²(Im z). -/
private lemma normSq_sin (z : ℂ) :
    Complex.normSq (Complex.sin z) =
      Real.sin z.re ^ 2 * Real.cosh z.im ^ 2 +
      Real.cos z.re ^ 2 * Real.sinh z.im ^ 2 := by
  rw [Complex.sin_eq z]
  simp only [normSq_apply, sq]
  -- The _im lemmas below are flagged as "unused" by simp but are needed for ring to close.
  -- They reduce cosh(↑x).im and sinh(↑x).im to 0, enabling ring to see pure ℝ arithmetic.
  set_option linter.unusedSimpArgs false in
  simp only [add_re, add_im, mul_re, mul_im, ofReal_re, ofReal_im, I_re, I_im,
    cosh_ofReal_re, cosh_ofReal_im, sinh_ofReal_re, sinh_ofReal_im,
    sin_ofReal_re, sin_ofReal_im, cos_ofReal_re, cos_ofReal_im]
  ring

/-- normSq(sin z) ≤ cosh²(Im z). -/
private lemma normSq_sin_le_cosh_sq (z : ℂ) :
    Complex.normSq (Complex.sin z) ≤ Real.cosh z.im ^ 2 := by
  rw [normSq_sin]
  -- sin²·cosh² + cos²·sinh² = sin²·cosh² + cos²·(cosh²-1) = cosh² - cos² ≤ cosh²
  have hsc := Real.sin_sq_add_cos_sq z.re
  have hsinh_le : Real.sinh z.im ^ 2 ≤ Real.cosh z.im ^ 2 := by
    nlinarith [Real.cosh_sq_sub_sinh_sq z.im]
  nlinarith [sq_nonneg (Real.sin z.re), sq_nonneg (Real.cos z.re),
             sq_nonneg (Real.cosh z.im), sq_nonneg (Real.sinh z.im)]

/-- |sin(z)| ≤ cosh(Im(z)) for all z ∈ ℂ. -/
theorem norm_sin_le_cosh_im (z : ℂ) :
    ‖Complex.sin z‖ ≤ Real.cosh z.im := by
  have h1 := normSq_sin_le_cosh_sq z
  have h2 : 0 ≤ Real.cosh z.im := le_of_lt (Real.cosh_pos z.im)
  -- ‖sin z‖ = √(normSq(sin z)) by Complex.norm_def
  rw [Complex.norm_def, ← Real.sqrt_sq h2]
  exact Real.sqrt_le_sqrt (by exact_mod_cast h1)

-- ════════════════════════════════════════════════════
-- §3. sin(πs) ≠ 0 in the open strip (0,1)
-- ════════════════════════════════════════════════════

/-- sin(πs) ≠ 0 when Re(s) ∈ (0, 1). -/
theorem sin_pi_mul_ne_zero {s : ℂ} (hs_pos : 0 < s.re) (hs_lt : s.re < 1) :
    Complex.sin (↑π * s) ≠ 0 := by
  rw [Complex.sin_ne_zero_iff]
  intro k hk
  have hpi : (π : ℂ) ≠ 0 := ofReal_ne_zero.mpr Real.pi_ne_zero
  have hs_eq_k : s = (k : ℂ) := by
    have h2 : s * (π : ℂ) = (k : ℂ) * (π : ℂ) := by rw [mul_comm]; exact hk
    exact mul_right_cancel₀ hpi h2
  have hk_eq : s.re = (k : ℝ) := by
    rw [hs_eq_k]; simp only [intCast_re]
  have hk0 : (0 : ℤ) < k := by exact_mod_cast hk_eq ▸ hs_pos
  have hk1 : k < (1 : ℤ) := by exact_mod_cast hk_eq ▸ hs_lt
  omega

-- ════════════════════════════════════════════════════
-- §4. Lower bound on |Γ(s)| via reflection formula
-- ════════════════════════════════════════════════════

/-- |Γ(s)| ≥ π / (cosh(π·Im(s)) · Γ(1 - Re(s))) for Re(s) ∈ (0,1).

    From the reflection formula Γ(s)·Γ(1-s) = π/sin(πs):
    |Γ(s)| = π / (|sin(πs)|·|Γ(1-s)|)
            ≥ π / (cosh(πt)·Γ(1-σ))
    using |sin(πs)| ≤ cosh(πt) and |Γ(1-s)| ≤ Γ(1-σ). -/
theorem norm_Gamma_lower_reflection {s : ℂ}
    (hs_pos : 0 < s.re) (hs_lt : s.re < 1) :
    π / (Real.cosh (π * s.im) * Real.Gamma (1 - s.re)) ≤ ‖Complex.Gamma s‖ := by
  -- Setup
  have h_sin_ne := sin_pi_mul_ne_zero hs_pos hs_lt
  have h_re_1_s : (1 - s).re = 1 - s.re := by simp only [sub_re, one_re]
  have h_re_pos : 0 < (1 - s).re := by rw [h_re_1_s]; linarith
  have h_Gamma1_ne := Complex.Gamma_ne_zero_of_re_pos h_re_pos
  have h_Gamma_ne := Complex.Gamma_ne_zero_of_re_pos hs_pos
  -- Positivity
  have h_sin_pos : 0 < ‖Complex.sin (↑π * s)‖ := norm_pos_iff.mpr h_sin_ne
  have h_cosh_pos : 0 < Real.cosh (π * s.im) := Real.cosh_pos _
  have h_G1_pos : 0 < Real.Gamma (1 - s.re) := Real.Gamma_pos_of_pos (by linarith)
  have h_G1_norm_pos : 0 < ‖Complex.Gamma (1 - s)‖ := norm_pos_iff.mpr h_Gamma1_ne
  -- Reflection: Γ(s)·Γ(1-s) = π/sin(πs)
  have hrefl := Complex.Gamma_mul_Gamma_one_sub s
  -- |sin(πs)| ≤ cosh(π·Im(s))
  have h_sin_bound : ‖Complex.sin (↑π * s)‖ ≤ Real.cosh (π * s.im) := by
    have h1 := norm_sin_le_cosh_im (↑π * s)
    have h2 : (↑π * s).im = π * s.im := by
      simp only [mul_im, ofReal_re, ofReal_im, zero_mul, add_zero]
    rwa [h2] at h1
  -- |Γ(1-s)| ≤ Γ(1-σ)
  have h_G1_bound : ‖Complex.Gamma (1 - s)‖ ≤ Real.Gamma (1 - s.re) := by
    have h := norm_Gamma_le_Gamma_re h_re_pos
    rwa [h_re_1_s] at h
  -- |sin|·|Γ(1-s)| ≤ cosh·Γ(1-σ)
  have h_denom : ‖Complex.sin (↑π * s)‖ * ‖Complex.Gamma (1 - s)‖ ≤
      Real.cosh (π * s.im) * Real.Gamma (1 - s.re) :=
    mul_le_mul h_sin_bound h_G1_bound (norm_nonneg _) (le_of_lt h_cosh_pos)
  -- Norm version of reflection: |Γ(s)|·|Γ(1-s)| = π/|sin(πs)|
  have h_prod : ‖Complex.Gamma s‖ * ‖Complex.Gamma (1 - s)‖ =
      π / ‖Complex.sin (↑π * s)‖ := by
    rw [← norm_mul, hrefl]
    simp only [norm_div, Complex.norm_real, Real.norm_eq_abs, abs_of_pos Real.pi_pos]
  -- |Γ(s)| = π / (|sin(πs)| · |Γ(1-s)|)
  have h_gamma_eq : ‖Complex.Gamma s‖ =
      π / (‖Complex.sin (↑π * s)‖ * ‖Complex.Gamma (1 - s)‖) := by
    have h_sinG := h_prod
    field_simp at h_sinG ⊢
    linarith
  -- π/(cosh·Γ) ≤ π/(|sin|·|Γ(1-s)|) since |sin|·|Γ| ≤ cosh·Γ
  rw [h_gamma_eq]
  exact div_le_div_of_nonneg_left (le_of_lt Real.pi_pos)
    (mul_pos h_sin_pos h_G1_norm_pos) h_denom

-- ════════════════════════════════════════════════════
-- §5. Strategic notes
-- ════════════════════════════════════════════════════

-- Remaining sorry: norm_Gamma_le_Gamma_re (integral bound).
-- All other lemmas are fully proved or depend only on that.
-- The reflection formula lower bound shows |Γ(s)| ≥ π/(cosh(πt)·Γ(1-σ)).
