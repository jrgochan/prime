/-
  Cathedral/White/Infrastructure/PerronKernel.lean

  ## The Quantitative Perron Kernel

  PHYSICS: The propagator in momentum space — single particle contribution.
  MATH: The contour integral of y^s/s over a vertical line, bounded by rectangle.

  ### Strategy (The Theorist's Blueprint):
  For a single y > 0, y ≠ 1:
    (1/2πi) ∫_{c-iT}^{c+iT} y^s/s ds ≈ { 1  if y > 1
                                           { 0  if y < 1
  with error O(y^c / (πT|log y|)).

  Proof: Complete the contour to a rectangle using Mathlib's
  `integral_boundary_rect_eq_zero_of_differentiable_on_off_countable`.
  - y > 1: close left, pick up residue at s = 0 (= 1)
  - y < 1: close right, no poles (= 0)
  Horizontal segments give the error bound.

  ### Mathlib Dependencies:
  - `Analysis.Complex.CauchyIntegral` (rectangle integral vanishing)
  - `Analysis.Complex.CauchyIntegral` (Cauchy integral formula for residue)

  ### Cathedral Dependencies: None (pure complex analysis).
-/

import Mathlib.Analysis.Complex.CauchyIntegral
import Mathlib.Analysis.Complex.RemovableSingularity
import Mathlib.Analysis.SpecialFunctions.Complex.LogDeriv
import Mathlib.Analysis.SpecialFunctions.Pow.Deriv
import Mathlib.MeasureTheory.Integral.IntervalIntegral.Basic

noncomputable section
open Complex Real MeasureTheory Set BigOperators

namespace Cathedral.White.Infrastructure

-- ═══════════════════════════════════════════
-- §1. The Perron Kernel Integrand
-- ═══════════════════════════════════════════

/-- The Perron kernel integrand: y^s / s. -/
def perronIntegrand (y : ℝ) (s : ℂ) : ℂ :=
  (y : ℂ) ^ s / s

/-- The vertical line integral over [c-iT, c+iT] of y^s/s.
    With s = c + it, ds = i·dt, so (1/2πi)·∫f·ds = (1/2π)·∫f·dt. -/
def perronIntegral (y c T : ℝ) : ℂ :=
  (1 / (2 * ↑Real.pi)) *
    ∫ t in (-T)..T, perronIntegrand y (c + t * I)

-- ═══════════════════════════════════════════
-- §2. Differentiability of y^s/s away from s=0
-- ═══════════════════════════════════════════

/-- y^s is differentiable for y > 0. -/
private lemma differentiableAt_cpow_const {y : ℝ} (hy : 0 < y) (s : ℂ) :
    DifferentiableAt ℂ (fun z => (y : ℂ) ^ z) s := by
  have hy_ne : (y : ℂ) ≠ 0 := Complex.ofReal_ne_zero.mpr (ne_of_gt hy)
  exact DifferentiableAt.const_cpow differentiableAt_id (Or.inl hy_ne)

/-- y^s/s is differentiable away from s = 0, for y > 0. -/
lemma perronIntegrand_differentiableAt {y : ℝ} (hy : 0 < y) {s : ℂ} (hs : s ≠ 0) :
    DifferentiableAt ℂ (perronIntegrand y) s := by
  exact (differentiableAt_cpow_const hy s).div differentiableAt_id hs

-- ═══════════════════════════════════════════
-- §3. Horizontal Segment Bounds
-- ═══════════════════════════════════════════

/-- The norm of the Perron integrand: ‖y^s/s‖ = y^(Re s) / ‖s‖ for y > 0, s ≠ 0. -/
lemma perronIntegrand_norm {y : ℝ} (hy : 0 < y) {s : ℂ} (hs : s ≠ 0) :
    ‖perronIntegrand y s‖ = y ^ s.re / ‖s‖ := by
  unfold perronIntegrand
  rw [norm_div, norm_cpow_eq_rpow_re_of_pos hy]

/-- On a horizontal line at height ±T with Re(s) = σ, ‖y^s/s‖ ≤ y^σ/T. -/
lemma perronIntegrand_bound_on_horizontal {y σ : ℝ} (hy : 0 < y) {T : ℝ} (hT : 0 < T)
    {s : ℂ} (hs_re : s.re = σ) (hs_im : |s.im| = T) (hs_ne : s ≠ 0) :
    ‖perronIntegrand y s‖ ≤ y ^ σ / T := by
  rw [perronIntegrand_norm hy hs_ne, hs_re]
  gcongr
  -- Need: T ≤ ‖s‖
  rw [← hs_im]
  exact abs_im_le_norm s

-- ═══════════════════════════════════════════
-- §4. Exponential Decay Integral
-- ═══════════════════════════════════════════

/-- For 0 < y < 1, the integral of y^σ over [c,R] is at most y^c/|log y|.
    Uses FTC: ∫_c^R y^σ dσ = (y^R - y^c)/log(y) ≤ y^c/|log y|. -/
lemma integral_rpow_le_of_lt_one {y c R : ℝ} (hy_pos : 0 < y) (hy_lt : y < 1)
    (hc : 0 ≤ c) (hR : c ≤ R) :
    ∫ σ in c..R, y ^ σ ≤ y ^ c / |Real.log y| := by
  -- Key fact: log y < 0 for 0 < y < 1
  have hlog_neg : Real.log y < 0 := Real.log_neg hy_pos hy_lt
  have hlog_ne : Real.log y ≠ 0 := ne_of_lt hlog_neg
  -- The antiderivative of y^σ is y^σ / log(y)
  -- By FTC: ∫_c^R (log y · y^σ) dσ = y^R - y^c
  have ftc : ∫ σ in c..R, Real.log y * y ^ σ = y ^ R - y ^ c := by
    apply intervalIntegral.integral_eq_sub_of_hasDerivAt
    · intro x _
      have h := (Real.hasStrictDerivAt_const_rpow hy_pos x).hasDerivAt
      rwa [mul_comm] at h
    · exact (continuous_const.mul (Continuous.rpow continuous_const continuous_id
        (fun _ => Or.inl (ne_of_gt hy_pos)))).intervalIntegrable c R
  -- Therefore: log y · ∫_c^R y^σ dσ = y^R - y^c
  have key : Real.log y * ∫ σ in c..R, y ^ σ = y ^ R - y ^ c := by
    rw [← intervalIntegral.integral_const_mul]
    exact ftc
  -- So: ∫_c^R y^σ dσ = (y^R - y^c) / log y
  have integral_eq : ∫ σ in c..R, y ^ σ = (y ^ R - y ^ c) / Real.log y := by
    field_simp at key ⊢
    linarith
  -- Now bound: (y^R - y^c) / log y ≤ y^c / |log y|
  -- Since log y < 0: |log y| = -log y
  -- And: (y^R - y^c) / log y = -(y^R - y^c) / (-log y) = (y^c - y^R) / |log y|
  -- Since y^R ≥ 0: y^c - y^R ≤ y^c
  rw [integral_eq, abs_of_neg hlog_neg]
  have hyR_nonneg : 0 ≤ y ^ R := rpow_nonneg hy_pos.le R
  have hyc_nonneg : 0 ≤ y ^ c := rpow_nonneg hy_pos.le c
  -- Goal: (y^R - y^c) / log y ≤ y^c / (-log y)
  -- Note: y^c / (-log y) = -(y^c / log y) = (-y^c) / log y
  -- So goal is: (y^R - y^c) / log y ≤ (-y^c) / log y
  -- Since log y < 0, dividing preserves order when numerator is larger
  -- (y^R - y^c) / log y ≤ (-y^c) / log y ← div_le_div_of_nonpos_right
  -- ↔ -y^c ≤ y^R - y^c (since log y < 0, division reverses)
  -- Wait, log y < 0 means we need le_div_iff etc with reversal
  -- Let's just compute directly
  have h1 : y ^ c / (-Real.log y) = -(y ^ c) / Real.log y := by ring
  rw [h1, div_le_div_right_of_neg hlog_neg]
  linarith

/-- For y > 1, the integral of y^σ over [-R,c] is at most y^c/log y.
    Uses FTC: ∫_{-R}^c y^σ dσ = (y^c - y^{-R})/log(y) ≤ y^c/log y. -/
lemma integral_rpow_le_of_gt_one {y c R : ℝ} (hy : 1 < y) (hR : 0 ≤ R) :
    ∫ σ in (-R)..c, y ^ σ ≤ y ^ c / Real.log y := by
  have hy_pos : 0 < y := lt_trans one_pos hy
  have hlog_pos : 0 < Real.log y := Real.log_pos hy
  have hlog_ne : Real.log y ≠ 0 := ne_of_gt hlog_pos
  -- FTC: ∫_{-R}^c (log y · y^σ) dσ = y^c - y^{-R}
  have ftc : ∫ σ in (-R)..c, Real.log y * y ^ σ = y ^ c - y ^ (-R) := by
    apply intervalIntegral.integral_eq_sub_of_hasDerivAt
    · intro x _
      have h := (Real.hasStrictDerivAt_const_rpow hy_pos x).hasDerivAt
      rwa [mul_comm] at h
    · exact (continuous_const.mul (Continuous.rpow continuous_const continuous_id
        (fun _ => Or.inl (ne_of_gt hy_pos)))).intervalIntegrable (-R) c
  have key : Real.log y * ∫ σ in (-R)..c, y ^ σ = y ^ c - y ^ (-R) := by
    rw [← intervalIntegral.integral_const_mul]; exact ftc
  have integral_eq : ∫ σ in (-R)..c, y ^ σ = (y ^ c - y ^ (-R)) / Real.log y := by
    field_simp at key ⊢; linarith
  rw [integral_eq]
  have : 0 ≤ y ^ (-R) := rpow_nonneg hy_pos.le (-R)
  exact div_le_div_of_nonneg_right (by linarith) hlog_pos.le

-- ═══════════════════════════════════════════
-- §5. Rectangle Sub-lemmas
-- ═══════════════════════════════════════════

/-- The rectangle integral of y^s/s vanishes when s=0 is outside.
    For the rectangle [c, R] × [-T, T] with c > 0, y^s/s is holomorphic inside.
    Uses Mathlib's `integral_boundary_rect_eq_zero_of_differentiableOn` (Cauchy-Goursat). -/
lemma rectangle_integral_perron_vanishes {y c R T : ℝ} (hy : 0 < y)
    (hc : 0 < c) (hR : c < R) (hT : 0 < T) :
    (∫ x in c..R, perronIntegrand y (x + (-T) * I)) -
    (∫ x in c..R, perronIntegrand y (x + T * I)) +
    I * (∫ t in (-T)..T, perronIntegrand y (R + t * I)) -
    I * (∫ t in (-T)..T, perronIntegrand y (c + t * I)) = 0 := by
  -- Key fact: 0 is not in the rectangle [c,R]×[-T,T] since c > 0
  have rect_ne_zero : ∀ s ∈ Set.uIcc c R ×ℂ Set.uIcc (-T) T, s ≠ (0 : ℂ) := by
    intro s hs h0
    have hre : s.re ∈ Set.uIcc c R := (Complex.mem_reProdIm.mp hs).1
    rw [h0] at hre
    simp [Set.mem_uIcc, Complex.zero_re] at hre
    -- hre : c ≤ 0 ∧ 0 ≤ R ∨ R ≤ 0 ∧ 0 ≤ c
    rcases hre with ⟨h1, _⟩ | ⟨_, h2⟩ <;> linarith
  -- f is differentiable on the closed rectangle
  have hDiff : DifferentiableOn ℂ (perronIntegrand y) (Set.uIcc c R ×ℂ Set.uIcc (-T) T) :=
    fun s hs => (perronIntegrand_differentiableAt hy (rect_ne_zero s hs)).differentiableWithinAt
  -- Apply Cauchy-Goursat (z = ⟨c,-T⟩, w = ⟨R,T⟩)
  have key := Complex.integral_boundary_rect_eq_zero_of_differentiableOn
    (perronIntegrand y) ⟨c, -T⟩ ⟨R, T⟩ hDiff
  simp only [smul_eq_mul] at key
  -- ↑(-T) = -(↑T) in ℂ
  rwa [Complex.ofReal_neg] at key

/-- The right vertical segment is bounded by 2T·y^R/R for y < 1.
    For each t, ‖y^{R+tI}/(R+tI)‖ = y^R/‖R+tI‖ ≤ y^R/R since ‖R+tI‖ ≥ R. -/
lemma right_vertical_bound {y R T : ℝ} (hy_pos : 0 < y) (hy_lt : y < 1)
    (hR : 0 < R) (hT : 0 < T) :
    ‖∫ t in (-T)..T, perronIntegrand y (R + t * I)‖ ≤ 2 * T * y ^ R / R := by
  -- Each integrand has norm ≤ y^R/R
  have pointwise_bound : ∀ t ∈ Set.uIoc (-T) T, ‖perronIntegrand y (↑R + ↑t * I)‖ ≤ y ^ R / R := by
    intro t _
    have hR_ne : (↑R : ℂ) + ↑t * I ≠ 0 := by
      intro h
      have : (↑R : ℂ).re + (↑t * I).re = 0 := by rw [← Complex.add_re]; simp [h]
      simp [Complex.ofReal_re, Complex.mul_re, Complex.I_re, Complex.I_im] at this
      linarith
    rw [perronIntegrand_norm hy_pos hR_ne]
    have hre : (↑R + ↑t * I).re = R := by
      simp [Complex.add_re, Complex.ofReal_re, Complex.mul_re, Complex.I_re, Complex.I_im]
    rw [hre]
    gcongr
    -- Need: R ≤ ‖R + tI‖
    calc (R : ℝ) = |(↑R + ↑t * I).re| := by simp [hre, abs_of_pos hR]
      _ ≤ ‖(↑R : ℂ) + ↑t * I‖ := Complex.abs_re_le_norm _
  -- Apply constant bound: ‖∫‖ ≤ C * |T - (-T)| = C * 2T
  calc ‖∫ t in (-T)..T, perronIntegrand y (↑R + ↑t * I)‖
      ≤ (y ^ R / R) * |T - (-T)| :=
        intervalIntegral.norm_integral_le_of_norm_le_const_ae
          (Filter.Eventually.of_forall pointwise_bound)
    _ = 2 * T * y ^ R / R := by
        rw [sub_neg_eq_add, ← two_mul, abs_of_pos (by linarith : 0 < 2 * T)]
        ring

-- ═══════════════════════════════════════════
-- §6. The Perron Kernel for y > 1 (Residue = 1)
-- ═══════════════════════════════════════════

/-- The "flattened" Perron integrand with the pole removed:
    g(s) = (y^s - 1)/s for s ≠ 0, and g(0) = log(y).
    This is entire by the removable singularity theorem. -/
noncomputable def perronFlattened (y : ℝ) : ℂ → ℂ :=
  dslope (fun z => (y : ℂ) ^ z) 0

/-- The key decomposition: y^s/s = g(s) + 1/s for s ≠ 0.
    This follows from dslope definition: g(s) = (y^s - f(0))/(s - 0) = (y^s - 1)/s. -/
lemma perronIntegrand_eq_flattened_add_inv (y : ℝ) (hy : 0 < y) (s : ℂ) (hs : s ≠ 0) :
    perronIntegrand y s = perronFlattened y s + 1 / s := by
  simp only [perronIntegrand, perronFlattened, dslope_of_ne _ hs, slope, vsub_eq_sub, sub_zero,
             smul_eq_mul]
  have : (y : ℂ) ^ (0 : ℂ) = 1 := by simp [cpow_zero]
  rw [this]
  field_simp
  ring

/-- The rectangle integral of 1/s around [-R, c] × [-T, T] equals 2πi.
    This is the winding number computation.
    Proof: By explicit FTC evaluation of Complex.log on each segment. -/
lemma rectangle_integral_inv_eq_two_pi_I {c R T : ℝ} (hc : 0 < c) (hR : 0 < R) (hT : 0 < T) :
    (∫ x in (-R)..c, ((↑x + -↑T * I)⁻¹ : ℂ)) -
    (∫ x in (-R)..c, ((↑x + ↑T * I)⁻¹ : ℂ)) +
    I * (∫ t in (-T)..T, ((↑c + ↑t * I)⁻¹ : ℂ)) -
    I * (∫ t in (-T)..T, ((-↑R + ↑t * I)⁻¹ : ℂ)) = 2 * Real.pi * I := by
  -- This requires explicit evaluation of ∫ 1/s on each segment using Complex.log FTC.
  -- The log values at the 4 corners cancel except for the imaginary part
  -- which sums to 2π (from the winding number argument).
  sorry

/-- Left vertical segment bound for y > 1: ‖∫ f(−R + t·I) dt‖ ≤ 2T·y^(−R)/R.
    The exponential decay y^(-R) → 0 as R → ∞ when y > 1. -/
lemma left_vertical_bound {y R T : ℝ} (hy : 1 < y) (hR : 0 < R) (hT : 0 < T) :
    ‖∫ t in (-T)..T, perronIntegrand y (-↑R + ↑t * I)‖ ≤ 2 * T * y ^ (-R) / R := by
  have hy_pos : 0 < y := lt_trans zero_lt_one hy
  -- Each integrand has norm ≤ y^(-R)/R
  have pointwise_bound : ∀ t ∈ Set.uIoc (-T) T,
      ‖perronIntegrand y (-↑R + ↑t * I)‖ ≤ y ^ (-R) / R := by
    intro t _
    have hR_ne : (-↑R : ℂ) + ↑t * I ≠ 0 := by
      intro h
      have : (-↑R : ℂ).re + (↑t * I).re = 0 := by rw [← Complex.add_re]; simp [h]
      simp [Complex.ofReal_re, Complex.neg_re, Complex.mul_re, Complex.I_re, Complex.I_im] at this
      linarith
    rw [perronIntegrand_norm hy_pos hR_ne]
    have hre : (-↑R + ↑t * I).re = -R := by
      simp [Complex.add_re, Complex.neg_re, Complex.ofReal_re,
            Complex.mul_re, Complex.I_re, Complex.I_im]
    rw [hre]
    gcongr
    -- Need: R ≤ ‖-R + tI‖
    calc (R : ℝ) = |(-↑R + ↑t * I).re| := by
          simp [hre, abs_of_pos hR]  -- |-R| = R since R > 0
      _ ≤ ‖(-↑R : ℂ) + ↑t * I‖ := Complex.abs_re_le_norm _
  -- Apply constant bound: ‖∫‖ ≤ C * |T - (-T)| = C * 2T
  calc ‖∫ t in (-T)..T, perronIntegrand y (-↑R + ↑t * I)‖
      ≤ (y ^ (-R) / R) * |T - (-T)| :=
        intervalIntegral.norm_integral_le_of_norm_le_const_ae
          (Filter.Eventually.of_forall pointwise_bound)
    _ = 2 * T * y ^ (-R) / R := by
        rw [sub_neg_eq_add, ← two_mul, abs_of_pos (by linarith : 0 < 2 * T)]
        ring

/-- **KEY LEMMA**: For y > 1, Perron integral = 1 + O(y^c/(T·log y)).

    Strategy (The Phantom Pole Bypass via dslope):
    1. Split: y^s/s = g(s) + 1/s where g(s) = dslope(y^s, 0)(s) = (y^s - 1)/s
    2. g is entire (Mathlib: differentiableOn_dslope)
    3. On the LEFT rectangle [-R, c] × [-T, T] enclosing s=0:
       ∫_∂B g = 0 (Cauchy-Goursat), so ∫_∂B y^s/s = ∫_∂B 1/s = 2πi
    4. Same composition as lt_one but contour shifted LEFT
    5. Residue = 1 extracted from the 2πi winding number -/
theorem perron_kernel_gt_one (y c T : ℝ) (hy : 1 < y) (hc : 0 < c) (hT : 0 < T) :
    ‖perronIntegral y c T - 1‖ ≤ y ^ c / (Real.pi * T * |Real.log y|) := by
  -- Proof outline:
  -- 1. For any R > 0, on rectangle [-R, c] × [-T, T]:
  --    ∫_∂B y^s/s = ∫_∂B 1/s = 2πi (by dslope + Cauchy-Goursat + winding)
  -- 2. perronIntegral = (right edge)/(2π)
  --    = [2πi + (top - bot) + I·left] / (2πi)  ... wait, divided by 2π not 2πi
  -- 3. perronIntegral - 1 = [(top - bot) + I·left]/(2π) ... with 2πi from residue
  -- Actually, we need to be more careful with the sign conventions.
  --
  -- The full assembly requires rectangle_integral_inv_eq_two_pi_I.
  -- We sorry this pending completion of the winding number calculation.
  sorry

-- ═══════════════════════════════════════════
-- §7. The Perron Kernel for y < 1 (Residue = 0)
-- ═══════════════════════════════════════════

/-- Horizontal segment bound: ‖∫_c^R f(σ ± TI) dσ‖ ≤ y^c / (T · |log y|) for 0 < y < 1.
    Composes perronIntegrand_bound_on_horizontal with integral_rpow_le_of_lt_one. -/
lemma horizontal_segment_bound {y c R T : ℝ} (hy_pos : 0 < y) (hy_lt : y < 1)
    (hc : 0 < c) (hR : c ≤ R) (hT : 0 < T) (sign : ℝ) (hsign : |sign| = 1) :
    ‖∫ σ in c..R, perronIntegrand y (↑σ + ↑(sign * T) * I)‖ ≤
      y ^ c / (T * |Real.log y|) := by
  -- Pointwise bound: ‖f(σ + sign·T·I)‖ ≤ y^σ/T
  have hle : ∀ σ, σ ∈ Set.Ioc c R → ‖perronIntegrand y (↑σ + ↑(sign * T) * I)‖ ≤ y ^ σ / T := by
    intro σ hσ_mem
    have hσ_pos : 0 < σ := lt_trans hc hσ_mem.1
    have hre : (↑σ + ↑(sign * T) * I : ℂ).re = σ := by
      simp [Complex.add_re, Complex.ofReal_re, Complex.mul_re, Complex.I_re, Complex.I_im]
    have hs_ne : (↑σ : ℂ) + ↑(sign * T) * I ≠ 0 := by
      intro h
      have : (↑σ + ↑(sign * T) * I : ℂ).re = (0 : ℂ).re := congr_arg Complex.re h
      simp [Complex.add_re, Complex.ofReal_re, Complex.mul_re, Complex.I_re, Complex.I_im] at this
      linarith
    have him : |(↑σ + ↑(sign * T) * I : ℂ).im| = T := by
      simp only [Complex.add_im, Complex.ofReal_im, Complex.mul_im, Complex.ofReal_re,
                  Complex.ofReal_im, Complex.I_re, Complex.I_im]
      ring_nf
      rw [abs_mul, hsign, one_mul, abs_of_pos hT]
    exact perronIntegrand_bound_on_horizontal hy_pos hT hre him hs_ne
  have hint : IntervalIntegrable (fun σ => y ^ σ / T) MeasureTheory.volume c R :=
    ((Continuous.rpow continuous_const continuous_id
      (fun _ => Or.inl (ne_of_gt hy_pos))).div_const T).intervalIntegrable c R
  calc ‖∫ σ in c..R, perronIntegrand y (↑σ + ↑(sign * T) * I)‖
      ≤ ∫ σ in c..R, y ^ σ / T :=
        intervalIntegral.norm_integral_le_of_norm_le hR
          (Filter.Eventually.of_forall fun σ hσ => hle σ hσ)
          hint
    _ = (∫ σ in c..R, y ^ σ) / T := by
        rw [intervalIntegral.integral_div]
    _ ≤ (y ^ c / |Real.log y|) / T :=
        div_le_div_of_nonneg_right (integral_rpow_le_of_lt_one hy_pos hy_lt hc.le hR) hT.le
    _ = y ^ c / (T * |Real.log y|) := by ring

/-- **Finite-R Perron bound**: For any R > c, composing the rectangle identity with
    the horizontal and vertical bounds gives a two-term bound on the Perron integral.
    This is the core composition of ALL our building-block lemmas. -/
lemma perron_integral_bound_with_R {y c R T : ℝ} (hy_pos : 0 < y) (hy_lt : y < 1)
    (hc : 0 < c) (hR : c < R) (hT : 0 < T) :
    ‖perronIntegral y c T‖ ≤
      y ^ c / (Real.pi * T * |Real.log y|) + T * y ^ R / (Real.pi * R) := by
  -- Abbreviate the four integrals
  set bot := ∫ x in c..R, perronIntegrand y (↑x + -↑T * I) with hbot_def
  set top := ∫ x in c..R, perronIntegrand y (↑x + ↑T * I) with htop_def
  set rv := ∫ t in (-T)..T, perronIntegrand y (↑R + ↑t * I) with hrv_def
  set lv := ∫ t in (-T)..T, perronIntegrand y (↑c + ↑t * I) with hlv_def
  -- Step 1: From rect, extract lv
  have rect := rectangle_integral_perron_vanishes hy_pos hc hR hT
  have hlv_eq : I * lv = bot - top + I * rv := by linear_combination -rect
  -- lv = -I * (bot - top) + rv
  have hlv_eq2 : lv = -I * (bot - top) + rv := by
    have hI_ne : (I : ℂ) ≠ 0 := Complex.I_ne_zero
    have : lv = I⁻¹ * (I * lv) := by rw [inv_mul_cancel_left₀ hI_ne]
    rw [this, hlv_eq, Complex.inv_I, mul_add, ← mul_assoc (-I) I rv]
    simp [Complex.I_mul_I]
  -- Step 2: Bound each segment
  have hbot_bound := horizontal_segment_bound hy_pos hy_lt hc hR.le hT (-1) (by norm_num)
  have htop_bound := horizontal_segment_bound hy_pos hy_lt hc hR.le hT 1 (by norm_num)
  have hrv_bound := right_vertical_bound hy_pos hy_lt (lt_trans hc hR) hT
  -- Match sign: (-1)*T = -T and 1*T = T, and ↑(-T) = -↑T
  simp only [neg_one_mul, one_mul, Complex.ofReal_neg] at hbot_bound htop_bound
  -- ‖lv‖ ≤ ‖bot‖ + ‖top‖ + ‖rv‖
  have hlv_bound : ‖lv‖ ≤ ‖bot‖ + ‖top‖ + ‖rv‖ := by
    rw [hlv_eq2]
    calc ‖-I * (bot - top) + rv‖
        ≤ ‖-I * (bot - top)‖ + ‖rv‖ := norm_add_le _ _
      _ = ‖bot - top‖ + ‖rv‖ := by
          rw [norm_mul, norm_neg, Complex.norm_I, one_mul]
      _ ≤ (‖bot‖ + ‖top‖) + ‖rv‖ := by
          gcongr; exact norm_sub_le _ _
  -- Step 3: Unfold perronIntegral and compute norm
  unfold perronIntegral
  have hpi_pos : (0 : ℝ) < Real.pi := Real.pi_pos
  have h2pi_norm : ‖(1 : ℂ) / (2 * ↑Real.pi)‖ = 1 / (2 * Real.pi) := by
    rw [norm_div, norm_one, norm_mul, Complex.norm_ofNat, Complex.norm_real]
    simp [abs_of_pos hpi_pos]
  rw [norm_mul, h2pi_norm]
  -- Final bound
  have h2pi_pos : 0 < 2 * Real.pi := by positivity
  calc 1 / (2 * Real.pi) * ‖lv‖
      ≤ 1 / (2 * Real.pi) * (‖bot‖ + ‖top‖ + ‖rv‖) := by
        gcongr
    _ ≤ 1 / (2 * Real.pi) *
        (y ^ c / (T * |Real.log y|) + y ^ c / (T * |Real.log y|) + 2 * T * y ^ R / R) := by
        gcongr
    _ = y ^ c / (Real.pi * T * |Real.log y|) + T * y ^ R / (Real.pi * R) := by
        field_simp
        ring

/-- **KEY LEMMA**: For 0 < y < 1, Perron integral = 0 + O(y^c/(T|log y|)).

    Proof: For any R > c, apply Cauchy-Goursat to the rectangle [c,R]×[-T,T].
    The left side is our Perron integral × 2πi. The other three sides are bounded:
    • horizontal: ≤ y^c/(T|log y|) each (by horizontal_segment_bound)
    • right vertical: ≤ 2T·y^R/R (by right_vertical_bound, → 0 as R → ∞)
    Since the bound holds for all R and the y^R/R term → 0, we get the result. -/
theorem perron_kernel_lt_one (y c T : ℝ) (hy_pos : 0 < y) (hy_lt : y < 1)
    (hc : 0 < c) (hT : 0 < T) :
    ‖perronIntegral y c T‖ ≤ y ^ c / (Real.pi * T * |Real.log y|) := by
  -- It suffices to show: for any ε > 0, ‖·‖ ≤ target + ε
  -- This implies ‖·‖ ≤ target by contradiction.
  by_contra hlt
  push_neg at hlt
  set δ := ‖perronIntegral y c T‖ - y ^ c / (Real.pi * T * |Real.log y|) with hδ_def
  have hδ : 0 < δ := by linarith
  -- Choose R large enough that T/(πR) < δ
  set R := max (c + 1) (T / (Real.pi * δ) + 1) with hR_def
  have hR_gt_c : c < R := by
    calc c < c + 1 := by linarith
      _ ≤ R := le_max_left _ _
  have hR_pos : 0 < R := lt_trans hc hR_gt_c
  -- Apply our proved composition bound
  have hbound := perron_integral_bound_with_R hy_pos hy_lt hc hR_gt_c hT
  -- Bound y^R ≤ 1 since 0 < y < 1
  have hyR_le : y ^ R ≤ 1 := rpow_le_one hy_pos.le hy_lt.le hR_pos.le
  -- So: T * y^R / (πR) ≤ T * 1 / (πR) = T/(πR)
  have herr_le : T * y ^ R / (Real.pi * R) ≤ T / (Real.pi * R) := by
    apply div_le_div_of_nonneg_right _ (mul_pos Real.pi_pos hR_pos).le
    calc T * y ^ R ≤ T * 1 := by gcongr
      _ = T := mul_one T
  -- And R > T/(πδ), so T/(πR) < δ
  have hR_big : T / (Real.pi * δ) < R := by
    calc T / (Real.pi * δ) < T / (Real.pi * δ) + 1 := by linarith
      _ ≤ R := le_max_right _ _
  have herr_lt : T / (Real.pi * R) < δ := by
    rw [div_lt_iff₀ (mul_pos Real.pi_pos hR_pos)]
    -- Need: T < δ * (π * R) = π * δ * R
    -- From hR_big: T / (π * δ) < R, so T < (π * δ) * R
    have hπδ_pos := mul_pos Real.pi_pos hδ
    have := (div_lt_iff₀ hπδ_pos).mp hR_big
    -- this : T < R * (π * δ)
    linarith
  -- Combine: ‖perronIntegral‖ ≤ target + Ty^R/(πR) ≤ target + T/(πR) < target + δ
  -- But δ = ‖perronIntegral‖ - target
  -- So target + δ = ‖perronIntegral‖, giving ‖perronIntegral‖ < ‖perronIntegral‖. Contradiction!
  linarith

-- ═══════════════════════════════════════════
-- §8. The Unified Perron Kernel Bound
-- ═══════════════════════════════════════════

/-- **UNIFIED PERRON KERNEL**: The Perron integral approximates the step function.

    For any y > 0, y ≠ 1:
    |(1/2πi) ∫_{c-iT}^{c+iT} y^s/s ds - 𝟙(y > 1)| ≤ y^c / (π·T·|log y|) -/
theorem perron_kernel_bound (y c T : ℝ) (hy : 0 < y) (hy_ne : y ≠ 1)
    (hc : 0 < c) (hT : 0 < T) :
    ‖perronIntegral y c T - (if 1 < y then 1 else 0)‖ ≤
    y ^ c / (Real.pi * T * |Real.log y|) := by
  by_cases h : 1 < y
  · simp only [h, ↑ite_true]
    exact perron_kernel_gt_one y c T h hc hT
  · push_neg at h
    have hlt : y < 1 := lt_of_le_of_ne h hy_ne
    simp only [show ¬(1 < y) from not_lt.mpr (le_of_lt hlt), ↑ite_false]
    simp only [sub_zero]
    exact perron_kernel_lt_one y c T hy hlt hc hT

-- ═══════════════════════════════════════════
-- §9. From Kernel to Summatory Function (The Assembly)
-- ═══════════════════════════════════════════

/-- **PERRON'S FORMULA**: The truncated Perron formula for summatory functions.

    For a : ℕ → ℂ with absolute convergence on Re(s) > 1:
    ∑_{n ≤ x} a(n) = (1/2πi) ∫_{c-iT}^{c+iT} (∑ a(n)/n^s) · x^s/s ds + O(x^c/T)

    This follows by summing `perron_kernel_bound` over n ≤ x,
    applied to y = x/n. The finite sum allows swapping ∑ and ∫. -/
theorem perron_formula_from_kernel
    (a : ℕ → ℂ) (x c T : ℝ) (hx : 0 < x) (hc : 1 < c) (hT : 0 < T)
    (hx_frac : Int.fract x ≠ 0) :
    ‖(∑ n ∈ Finset.Icc 1 ⌊x⌋₊, a n) -
      (1 / (2 * ↑Real.pi)) *
      ∫ t in (-T)..T, (∑ n ∈ Finset.Icc 1 ⌊x⌋₊, a n * (n : ℂ) ^ (-(↑c + ↑t * I))) *
        (x : ℂ) ^ (↑c + ↑t * I) / (↑c + ↑t * I)‖ ≤
    x ^ c / T := by
  sorry -- Sum over n of perron_kernel_bound(x/n) + swap ∑ and ∫

end Cathedral.White.Infrastructure
