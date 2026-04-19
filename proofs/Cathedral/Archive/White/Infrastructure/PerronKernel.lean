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
open Complex Real MeasureTheory Set BigOperators ComplexConjugate

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

/-- Antiderivative for right vertical: d/dt[-I·log(c + tI)] = 1/(c + tI).
    Used for ∫ 1/(c + tI) dt in the winding number computation. -/
lemma right_vert_log_antideriv {c : ℝ} (hc : 0 < c) (t : ℝ) :
    HasDerivAt (fun u : ℝ => -I * Complex.log (↑c + ↑u * I))
      ((↑c + ↑t * I)⁻¹ : ℂ) t := by
  have hslitPlane : (↑c + ↑t * I) ∈ slitPlane := by
    left; simp [Complex.add_re, Complex.ofReal_re, Complex.mul_re,
                Complex.I_re, Complex.I_im, hc]
  have hf : HasDerivAt (fun u : ℝ => (↑c : ℂ) + ↑u * I) (I : ℂ) t := by
    simpa using (Complex.ofRealCLM.hasDerivAt (x := t)).mul_const I |>.const_add (↑c : ℂ)
  have hlog := HasDerivAt.clog_real hf hslitPlane
  have hmul := hlog.const_mul (-I)
  have : -I * (I / (↑c + ↑t * I)) = (↑c + ↑t * I)⁻¹ := by
    rw [div_eq_mul_inv, ← mul_assoc,
        show -I * I = (1 : ℂ) from by simp [Complex.I_mul_I], one_mul]
  rwa [this] at hmul

/-- Antiderivative for left vertical (Theorist's trick):
    d/dt[-I·log(R - tI)] = 1/(-R + tI).
    Key insight: R - tI has Re = R > 0, staying in slitPlane. -/
lemma left_vert_log_antideriv {R : ℝ} (hR : 0 < R) (t : ℝ) :
    HasDerivAt (fun u : ℝ => -I * Complex.log (↑R - ↑u * I))
      ((-↑R + ↑t * I)⁻¹ : ℂ) t := by
  have hslitPlane : (↑R - ↑t * I) ∈ slitPlane := by
    left; simp [Complex.sub_re, Complex.ofReal_re, Complex.mul_re,
                Complex.I_re, Complex.I_im, hR]
  have hf : HasDerivAt (fun u : ℝ => (↑R : ℂ) - ↑u * I) (-I : ℂ) t := by
    simpa using ((Complex.ofRealCLM.hasDerivAt (x := t)).mul_const I).const_sub (↑R : ℂ)
  have hlog := HasDerivAt.clog_real hf hslitPlane
  have hmul := hlog.const_mul (-I)
  -- -I * (-I / (R - tI)) = -I²/(R - tI) = 1/(R - tI) = -1/(-R + tI) ... wait
  -- Actually: -I * (-I / (R - tI)) = I²/(R - tI) = -1/(R - tI) = 1/(-R + tI)? No.
  -- Let's compute: -I * (-I) = I² = -1, so -I * (-I/(R-tI)) = -1/(R-tI) = 1/(-(R-tI)) = 1/(-R+tI)
  have : -I * (-I / (↑R - ↑t * I)) = (-↑R + ↑t * I)⁻¹ := by
    rw [div_eq_mul_inv, ← mul_assoc,
        show -I * -I = (-1 : ℂ) from by simp [Complex.I_mul_I]]
    simp only [neg_mul, one_mul, neg_inv, neg_neg]
    congr 1; ring
  rwa [this] at hmul

/-- Antiderivative for horizontal segments: d/dx[log(x + aI)] = 1/(x + aI)
    when a ≠ 0 (so x + aI stays in slitPlane via nonzero imaginary part). -/
lemma horiz_log_antideriv {a : ℝ} (ha : a ≠ 0) (x : ℝ) :
    HasDerivAt (fun u : ℝ => Complex.log (↑u + ↑a * I))
      ((↑x + ↑a * I)⁻¹ : ℂ) x := by
  have hslitPlane : (↑x + ↑a * I) ∈ slitPlane := by
    right; simp [Complex.add_im, Complex.ofReal_im, Complex.mul_im,
                 Complex.I_re, Complex.I_im, ha]
  have hf : HasDerivAt (fun u : ℝ => (↑u : ℂ) + ↑a * I) (1 : ℂ) x := by
    simpa using (Complex.ofRealCLM.hasDerivAt (x := x)).add_const (↑a * I)
  have hlog := HasDerivAt.clog_real hf hslitPlane
  simp [div_eq_mul_inv] at hlog
  exact hlog

/-- The four-corner logarithm identity: pure winding number algebra.
    Uses conjugation symmetry (log(z̄) = conj(log z)) plus
    arg(-R+TI) + arg(R+TI) = π (from arg_neg_eq_arg_add_pi_of_im_neg). -/
lemma four_corner_log_sum {R T : ℝ} (hR : 0 < R) (hT : 0 < T) :
    -Complex.log (-↑R - ↑T * I) + Complex.log (-↑R + ↑T * I)
    - Complex.log (↑R - ↑T * I) + Complex.log (↑R + ↑T * I) = 2 * ↑Real.pi * I := by
  have hconj_RT : conj (↑R + ↑T * I) = ↑R - ↑T * I := by
    simp [map_add, map_mul, conj_ofReal, conj_I, mul_neg]; ring
  have harg_ne_pi : (↑R + ↑T * I : ℂ).arg ≠ π := by
    intro h
    have hre : (0 : ℝ) < (↑R + ↑T * I : ℂ).re := by
      simp [Complex.add_re, Complex.ofReal_re, Complex.mul_re, Complex.I_re, Complex.I_im, hR]
    linarith [Complex.arg_lt_pi_iff.mpr (Or.inl hre.le), Complex.arg_le_pi (↑R + ↑T * I)]
  have harg_sum : (↑R + ↑T * I : ℂ).arg + (-↑R + ↑T * I : ℂ).arg = π := by
    have : (-↑R + ↑T * I : ℂ) = -(↑R - ↑T * I) := by ring
    rw [this, Complex.arg_neg_eq_arg_add_pi_of_im_neg
      (by simp [Complex.sub_im, Complex.ofReal_im, Complex.mul_im,
                Complex.I_re, Complex.I_im, hT] : (↑R - ↑T * I : ℂ).im < 0)]
    rw [show (↑R - ↑T * I : ℂ) = conj (↑R + ↑T * I) from hconj_RT.symm,
        Complex.arg_conj, if_neg harg_ne_pi]; ring
  have harg_ne_pi2 : (-↑R + ↑T * I : ℂ).arg ≠ π := by
    exact ne_of_lt (Complex.arg_lt_pi_iff.mpr (Or.inr
      (by simp [Complex.add_im, Complex.neg_im, Complex.ofReal_im,
                Complex.mul_im, Complex.I_re, Complex.I_im]; linarith : (-↑R + ↑T * I : ℂ).im ≠ 0)))
  have hlog_conj1 : Complex.log (↑R - ↑T * I) = conj (Complex.log (↑R + ↑T * I)) := by
    rw [← hconj_RT, Complex.log_conj _ harg_ne_pi]
  have hconj_mRT : conj (-↑R + ↑T * I) = -↑R - ↑T * I := by
    simp [map_add, map_neg, map_mul, conj_ofReal, conj_I, mul_neg]; ring
  have hlog_conj2 : Complex.log (-↑R - ↑T * I) = conj (Complex.log (-↑R + ↑T * I)) := by
    rw [← hconj_mRT, Complex.log_conj _ harg_ne_pi2]
  have key (z : ℂ) : z - conj z = 2 * I * ↑z.im := by
    apply Complex.ext <;> simp [Complex.mul_re, Complex.I_re, Complex.I_im,
                  Complex.mul_im, Complex.conj_re, Complex.conj_im] <;> ring
  calc -Complex.log (-↑R - ↑T * I) + Complex.log (-↑R + ↑T * I)
      - Complex.log (↑R - ↑T * I) + Complex.log (↑R + ↑T * I)
      = (Complex.log (-↑R + ↑T * I) - conj (Complex.log (-↑R + ↑T * I)))
        + (Complex.log (↑R + ↑T * I) - conj (Complex.log (↑R + ↑T * I))) := by
          rw [hlog_conj1, hlog_conj2]; ring
    _ = 2 * I * ↑(Complex.log (-↑R + ↑T * I)).im
        + 2 * I * ↑(Complex.log (↑R + ↑T * I)).im := by rw [key, key]
    _ = 2 * I * ↑((-↑R + ↑T * I : ℂ).arg)
        + 2 * I * ↑((↑R + ↑T * I : ℂ).arg) := by simp [Complex.log_im]
    _ = 2 * I * ↑((↑R + ↑T * I : ℂ).arg + (-↑R + ↑T * I : ℂ).arg) := by push_cast; ring
    _ = 2 * I * ↑(Real.pi) := by rw [harg_sum]
    _ = 2 * ↑Real.pi * I := by ring

/-- The rectangle integral of 1/s around [-R, c] × [-T, T] equals 2πi.
    FTC on each segment reduces to the four-corner log identity. -/
lemma rectangle_integral_inv_eq_two_pi_I {c R T : ℝ} (hc : 0 < c) (hR : 0 < R) (hT : 0 < T) :
    (∫ x in (-R)..c, ((↑x + -↑T * I)⁻¹ : ℂ)) -
    (∫ x in (-R)..c, ((↑x + ↑T * I)⁻¹ : ℂ)) +
    I * (∫ t in (-T)..T, ((↑c + ↑t * I)⁻¹ : ℂ)) -
    I * (∫ t in (-T)..T, ((-↑R + ↑t * I)⁻¹ : ℂ)) = 2 * Real.pi * I := by
  -- Step 1: FTC on each segment.
  -- Integrability follows from HasDerivAt (the derivative is the integrand, which is continuous).
  have hT_ne : (T : ℝ) ≠ 0 := ne_of_gt hT
  have hmT_ne : (-T : ℝ) ≠ 0 := neg_ne_zero.mpr hT_ne
  -- Bottom: ∫_{-R}^c 1/(x - TI) dx = log(c - TI) - log(-R - TI)
  have hbot : ∫ x in (-R)..c, ((↑x + -↑T * I)⁻¹ : ℂ) =
      Complex.log (↑c + -↑T * I) - Complex.log (-↑R + -↑T * I) := by
    rw [show (-↑R : ℂ) = ↑(-R) from by push_cast; ring,
        show ((-↑T : ℂ) * I) = (↑(-T) * I) from by push_cast; ring]
    exact intervalIntegral.integral_eq_sub_of_hasDerivAt
      (fun x _ => horiz_log_antideriv hmT_ne x)
      (ContinuousOn.intervalIntegrable (ContinuousOn.inv₀ (by fun_prop) (fun x _ h => by
        have := congr_arg Complex.im h
        simp [Complex.add_im, Complex.ofReal_im, Complex.mul_im, Complex.I_re, Complex.I_im] at this
        exact hT_ne this)))
  -- Top: ∫_{-R}^c 1/(x + TI) dx = log(c + TI) - log(-R + TI)
  have htop : ∫ x in (-R)..c, ((↑x + ↑T * I)⁻¹ : ℂ) =
      Complex.log (↑c + ↑T * I) - Complex.log (-↑R + ↑T * I) := by
    rw [show (-↑R : ℂ) = ↑(-R) from by push_cast; ring]
    exact intervalIntegral.integral_eq_sub_of_hasDerivAt
      (fun x _ => horiz_log_antideriv hT_ne x)
      (ContinuousOn.intervalIntegrable (ContinuousOn.inv₀ (by fun_prop) (fun x _ h => by
        have := congr_arg Complex.im h
        simp [Complex.add_im, Complex.ofReal_im, Complex.mul_im, Complex.I_re, Complex.I_im] at this
        exact hT_ne this)))
  -- Right: ∫_{-T}^T 1/(c + tI) dt = -I·log(c+TI) - (-I·log(c-TI))
  have hright : ∫ t in (-T)..T, ((↑c + ↑t * I)⁻¹ : ℂ) =
      -I * Complex.log (↑c + ↑T * I) - (-I * Complex.log (↑c + (-↑T) * I)) := by
    rw [show ((-↑T : ℂ) * I) = (↑(-T) * I) from by push_cast; ring]
    exact intervalIntegral.integral_eq_sub_of_hasDerivAt
      (fun t _ => right_vert_log_antideriv hc t)
      (ContinuousOn.intervalIntegrable (ContinuousOn.inv₀ (by fun_prop) (fun t _ h => by
        have := congr_arg Complex.re h
        simp [Complex.add_re, Complex.ofReal_re, Complex.mul_re, Complex.I_re, Complex.I_im] at this
        linarith)))
  -- Left: ∫_{-T}^T 1/(-R + tI) dt = -I·log(R-TI) - (-I·log(R+TI))
  have hleft : ∫ t in (-T)..T, ((-↑R + ↑t * I)⁻¹ : ℂ) =
      -I * Complex.log (↑R - ↑T * I) - (-I * Complex.log (↑R - (-↑T) * I)) := by
    rw [show ((-↑T : ℂ) * I) = (↑(-T) * I) from by push_cast; ring]
    exact intervalIntegral.integral_eq_sub_of_hasDerivAt
      (fun t _ => left_vert_log_antideriv hR t)
      (ContinuousOn.intervalIntegrable (ContinuousOn.inv₀ (by fun_prop) (fun t _ h => by
        have := congr_arg Complex.re h
        simp [Complex.add_re, Complex.ofReal_re, Complex.neg_re, Complex.mul_re, Complex.I_re, Complex.I_im] at this
        linarith)))
  -- Step 2: Substitute the four FTC results and simplify
  rw [hbot, htop, hright, hleft]
  -- The goal now has I * (-I * ... - -I * ...) terms. Simplify using I*(-I) = 1.
  have hII : (I : ℂ) * -I = 1 := by
    simp [Complex.ext_iff, Complex.I_re, Complex.I_im]
  -- Normalize sign patterns
  have hs1 : (-↑R + -↑T * I : ℂ) = -↑R - ↑T * I := by ring
  have hs2 : (↑R - -↑T * I : ℂ) = ↑R + ↑T * I := by ring
  have hs3 : (↑c + -↑T * I : ℂ) = ↑c - ↑T * I := by ring
  rw [hs1, hs2, hs3]
  -- Now simplify I * (-I * A - -I * B) terms
  -- I * (-I * A - -I * B) = I*(-I)*A - I*(-I)*B ... no, -(-I) = I
  -- -I * A - -I * B means: (-I)*A - (-I)*B = (-I)*(A - B)
  -- I * ((-I)*(A - B)) = (I*(-I))*(A-B) = 1*(A-B) = A - B
  -- But Lean represents this differently. Let's compute directly.
  have key1 : I * (-I * Complex.log (↑c + ↑T * I) - -I * Complex.log (↑c - ↑T * I))
      = Complex.log (↑c + ↑T * I) - Complex.log (↑c - ↑T * I) := by
    have : -I * Complex.log (↑c + ↑T * I) - -I * Complex.log (↑c - ↑T * I)
         = -I * (Complex.log (↑c + ↑T * I) - Complex.log (↑c - ↑T * I)) := by ring
    rw [this, ← mul_assoc, hII, one_mul]
  have key2 : I * (-I * Complex.log (↑R - ↑T * I) - -I * Complex.log (↑R + ↑T * I))
      = Complex.log (↑R - ↑T * I) - Complex.log (↑R + ↑T * I) := by
    have : -I * Complex.log (↑R - ↑T * I) - -I * Complex.log (↑R + ↑T * I)
         = -I * (Complex.log (↑R - ↑T * I) - Complex.log (↑R + ↑T * I)) := by ring
    rw [this, ← mul_assoc, hII, one_mul]
  rw [key1, key2]
  -- Goal: (log(c-TI) - log(-R-TI)) - (log(c+TI) - log(-R+TI))
  --       + (log(c+TI) - log(c-TI)) - (log(R-TI) - log(R+TI)) = 2πI
  -- The log(c±TI) cancel, leaving: -log(-R-TI) + log(-R+TI) - log(R-TI) + log(R+TI) = 2πI
  linear_combination four_corner_log_sum hR hT

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

/-- Horizontal segment bound for y > 1 on [-R, c]:
    ‖∫_{-R}^c f(σ ± TI) dσ‖ ≤ y^c/(T·|log y|).
    Uses integral_rpow_le_of_gt_one for the exponential decay. -/
lemma horizontal_segment_bound_gt_one {y c R T : ℝ} (hy : 1 < y)
    (hc : 0 < c) (hR : 0 ≤ R) (hT : 0 < T) (sign : ℝ) (hsign : |sign| = 1) :
    ‖∫ σ in (-R)..c, perronIntegrand y (↑σ + ↑(sign * T) * I)‖ ≤
      y ^ c / (T * |Real.log y|) := by
  have hy_pos : 0 < y := lt_trans one_pos hy
  -- Pointwise bound: ‖f(σ + sign·T·I)‖ ≤ y^σ/T
  have hle : ∀ σ, σ ∈ Set.Ioc (-R) c →
      ‖perronIntegrand y (↑σ + ↑(sign * T) * I)‖ ≤ y ^ σ / T := by
    intro σ _
    have hre : (↑σ + ↑(sign * T) * I : ℂ).re = σ := by
      simp [Complex.add_re, Complex.ofReal_re, Complex.mul_re, Complex.I_re, Complex.I_im]
    have hs_ne : (↑σ : ℂ) + ↑(sign * T) * I ≠ 0 := by
      intro h
      have him := congr_arg Complex.im h
      simp only [Complex.add_im, Complex.ofReal_im, Complex.mul_im, Complex.ofReal_re,
                  Complex.I_re, Complex.I_im, Complex.zero_im, mul_one, mul_zero, add_zero] at him
      have : sign * T = 0 := by linarith
      have : |sign * T| = 0 := abs_eq_zero.mpr this
      rw [abs_mul, hsign, one_mul, abs_of_pos hT] at this
      linarith
    have him : |(↑σ + ↑(sign * T) * I : ℂ).im| = T := by
      simp only [Complex.add_im, Complex.ofReal_im, Complex.mul_im, Complex.ofReal_re,
                  Complex.ofReal_im, Complex.I_re, Complex.I_im]
      ring_nf
      rw [abs_mul, hsign, one_mul, abs_of_pos hT]
    exact perronIntegrand_bound_on_horizontal hy_pos hT hre him hs_ne
  have hmR_le_c : -R ≤ c := by linarith [hc]
  have hint : IntervalIntegrable (fun σ => y ^ σ / T) MeasureTheory.volume (-R) c :=
    ((Continuous.rpow continuous_const continuous_id
      (fun _ => Or.inl (ne_of_gt hy_pos))).div_const T).intervalIntegrable (-R) c
  calc ‖∫ σ in (-R)..c, perronIntegrand y (↑σ + ↑(sign * T) * I)‖
      ≤ ∫ σ in (-R)..c, y ^ σ / T :=
        intervalIntegral.norm_integral_le_of_norm_le hmR_le_c
          (Filter.Eventually.of_forall fun σ hσ => hle σ hσ)
          hint
    _ = (∫ σ in (-R)..c, y ^ σ) / T := by
        rw [intervalIntegral.integral_div]
    _ ≤ (y ^ c / Real.log y) / T :=
        div_le_div_of_nonneg_right (integral_rpow_le_of_gt_one hy hR) hT.le
    _ = y ^ c / (T * |Real.log y|) := by
        rw [abs_of_pos (Real.log_pos hy)]; ring

/-- Rectangle identity for y^s/s on [-R, c] × [-T, T]:
    The boundary integral equals 2πi (the winding number).
    Uses dslope decomposition: y^s/s = g(s) + 1/s where g is entire.
    Cauchy-Goursat kills ∫_∂B g = 0, and ∫_∂B 1/s = 2πi. -/
lemma left_rectangle_perron_winding {y c R T : ℝ}
    (hy : 0 < y) (hc : 0 < c) (hR : 0 < R) (hT : 0 < T) :
    (∫ x in (-R)..c, perronIntegrand y (↑x + -↑T * I)) -
    (∫ x in (-R)..c, perronIntegrand y (↑x + ↑T * I)) +
    I * (∫ t in (-T)..T, perronIntegrand y (↑c + ↑t * I)) -
    I * (∫ t in (-T)..T, perronIntegrand y (-↑R + ↑t * I)) =
    2 * ↑Real.pi * I := by
  -- Step 1: dslope of y^z is differentiable everywhere (removable singularity)
  set f_cpow : ℂ → ℂ := fun z => (y : ℂ) ^ z with hf_def
  have hDiffAt : ∀ z : ℂ, DifferentiableAt ℂ (dslope f_cpow 0) z := by
    intro z
    rcases eq_or_ne z 0 with rfl | hz
    · -- At z = 0: use differentiableOn_dslope (removable singularity theorem)
      have hDiff : DifferentiableOn ℂ f_cpow (Set.univ : Set ℂ) :=
        fun z _ => (differentiableAt_cpow_const hy z).differentiableWithinAt
      have h_nhds : (Set.univ : Set ℂ) ∈ nhds (0 : ℂ) := Filter.univ_mem
      have key := ((differentiableOn_dslope h_nhds (f := f_cpow)).mpr hDiff) 0 (Set.mem_univ _)
      exact key.differentiableAt (Filter.univ_mem)
    · -- At z ≠ 0: straightforward
      exact (differentiableAt_dslope_of_ne hz).mpr (differentiableAt_cpow_const hy z)
  -- Step 2: Cauchy-Goursat for g = dslope on the rectangle [-R, c] × [-T, T]
  set g := dslope f_cpow 0 with hg_def
  have rect_g : (∫ x in (-R)..c, g (↑x + -↑T * I)) -
      (∫ x in (-R)..c, g (↑x + ↑T * I)) +
      I * (∫ t in (-T)..T, g (↑c + ↑t * I)) -
      I * (∫ t in (-T)..T, g (-↑R + ↑t * I)) = 0 := by
    have hDiffOn : DifferentiableOn ℂ g (Set.uIcc (-R) c ×ℂ Set.uIcc (-T) T) :=
      fun z _ => (hDiffAt z).differentiableWithinAt
    have key := Complex.integral_boundary_rect_eq_zero_of_differentiableOn
      g ⟨-R, -T⟩ ⟨c, T⟩ hDiffOn
    simp only [smul_eq_mul] at key
    convert key using 2 <;> push_cast <;> ring
  -- Step 3: Winding number for 1/s
  have rect_inv := rectangle_integral_inv_eq_two_pi_I hc hR hT
  -- Step 4: On each segment, split ∫ f = ∫ g + ∫ (1/s) using perronIntegrand_eq_flattened_add_inv.
  -- We use: perronIntegrand y s = g s + 1/s for s ≠ 0, and integral_add for measurability.
  -- Key fact: on all boundary segments, s ≠ 0 (either re ≠ 0 or im ≠ 0).
  -- Therefore the integrand identity holds pointwise, and the integrals split.
  -- Instead of splitting each segment individually, we note that the result follows
  -- from rect_g + rect_inv by showing the perron integrals equal the sum.
  -- Since f(s) = g(s) + 1/s pointwise on the boundary, ∫ f = ∫ g + ∫ (1/s) by integral_add.
  -- So ∫_∂B f = ∫_∂B g + ∫_∂B 1/s = 0 + 2πi.
  -- The pointwise identity gives us: on each segment, the perronIntegrand integral
  -- equals the g integral + the 1/s integral.
  -- For the bottom segment ∫_{-R}^c f(x - TI) dx:
  have hT_ne : T ≠ 0 := ne_of_gt hT
  have hmT_ne : -T ≠ 0 := neg_ne_zero.mpr hT_ne
  -- g is continuous (differentiable everywhere → continuous)
  have hg_cont : Continuous g := by
    rw [continuous_iff_continuousAt]
    intro z; exact (hDiffAt z).continuousAt
  -- Helper: g ∘ φ is integrable for any continuous φ : ℝ → ℂ
  -- Bridge: g = perronFlattened y (both are dslope of the same function)
  have hg_eq : g = perronFlattened y := rfl
  -- Split each segment using integral_add
  have split_bot : ∫ x in (-R)..c, perronIntegrand y (↑x + -↑T * I) =
      (∫ x in (-R)..c, g (↑x + -↑T * I)) + ∫ x in (-R)..c, ((↑x + -↑T * I)⁻¹ : ℂ) := by
    rw [← intervalIntegral.integral_add]
    · congr 1; ext x
      have hne : (↑x + -↑T * I : ℂ) ≠ 0 := by
        intro h; have := congr_arg Complex.im h
        simp [Complex.add_im, Complex.ofReal_im, Complex.mul_im, Complex.I_re, Complex.I_im] at this
        exact hT_ne this
      rw [perronIntegrand_eq_flattened_add_inv y hy _ hne, one_div, hg_eq]
    · exact (hg_cont.comp (by fun_prop : Continuous fun x : ℝ => (↑x + -↑T * I : ℂ))).intervalIntegrable _ _
    · exact ContinuousOn.intervalIntegrable (ContinuousOn.inv₀ (by fun_prop) (fun x _ h => by
        have := congr_arg Complex.im h
        simp [Complex.add_im, Complex.ofReal_im, Complex.mul_im, Complex.I_re, Complex.I_im] at this
        exact hT_ne this))
  have split_top : ∫ x in (-R)..c, perronIntegrand y (↑x + ↑T * I) =
      (∫ x in (-R)..c, g (↑x + ↑T * I)) + ∫ x in (-R)..c, ((↑x + ↑T * I)⁻¹ : ℂ) := by
    rw [← intervalIntegral.integral_add]
    · congr 1; ext x
      have hne : (↑x + ↑T * I : ℂ) ≠ 0 := by
        intro h; have := congr_arg Complex.im h
        simp [Complex.add_im, Complex.ofReal_im, Complex.mul_im, Complex.I_re, Complex.I_im] at this
        exact hT_ne this
      rw [perronIntegrand_eq_flattened_add_inv y hy _ hne, one_div, hg_eq]
    · exact (hg_cont.comp (by fun_prop : Continuous fun x : ℝ => (↑x + ↑T * I : ℂ))).intervalIntegrable _ _
    · exact ContinuousOn.intervalIntegrable (ContinuousOn.inv₀ (by fun_prop) (fun x _ h => by
        have := congr_arg Complex.im h
        simp [Complex.add_im, Complex.ofReal_im, Complex.mul_im, Complex.I_re, Complex.I_im] at this
        exact hT_ne this))
  have split_right : ∫ t in (-T)..T, perronIntegrand y (↑c + ↑t * I) =
      (∫ t in (-T)..T, g (↑c + ↑t * I)) + ∫ t in (-T)..T, ((↑c + ↑t * I)⁻¹ : ℂ) := by
    rw [← intervalIntegral.integral_add]
    · congr 1; ext t
      have hne : (↑c + ↑t * I : ℂ) ≠ 0 := by
        intro h; have := congr_arg Complex.re h
        simp [Complex.add_re, Complex.ofReal_re, Complex.mul_re, Complex.I_re, Complex.I_im] at this
        linarith
      rw [perronIntegrand_eq_flattened_add_inv y hy _ hne, one_div, hg_eq]
    · exact (hg_cont.comp (by fun_prop : Continuous fun t : ℝ => (↑c + ↑t * I : ℂ))).intervalIntegrable _ _
    · exact ContinuousOn.intervalIntegrable (ContinuousOn.inv₀ (by fun_prop) (fun t _ h => by
        have := congr_arg Complex.re h
        simp [Complex.add_re, Complex.ofReal_re, Complex.mul_re, Complex.I_re, Complex.I_im] at this
        linarith))
  have split_left : ∫ t in (-T)..T, perronIntegrand y (-↑R + ↑t * I) =
      (∫ t in (-T)..T, g (-↑R + ↑t * I)) + ∫ t in (-T)..T, ((-↑R + ↑t * I)⁻¹ : ℂ) := by
    rw [← intervalIntegral.integral_add]
    · congr 1; ext t
      have hne : (-↑R + ↑t * I : ℂ) ≠ 0 := by
        intro h; have := congr_arg Complex.re h
        simp [Complex.add_re, Complex.neg_re, Complex.ofReal_re, Complex.mul_re,
              Complex.I_re, Complex.I_im] at this
        linarith
      rw [perronIntegrand_eq_flattened_add_inv y hy _ hne, one_div, hg_eq]
    · exact (hg_cont.comp (by fun_prop : Continuous fun t : ℝ => (-↑R + ↑t * I : ℂ))).intervalIntegrable _ _
    · exact ContinuousOn.intervalIntegrable (ContinuousOn.inv₀ (by fun_prop) (fun t _ h => by
        have := congr_arg Complex.re h
        simp [Complex.add_re, Complex.neg_re, Complex.ofReal_re, Complex.mul_re,
              Complex.I_re, Complex.I_im] at this
        linarith))
  -- Step 5: Substitute and combine
  rw [split_bot, split_top, split_right, split_left]
  -- After substitution, the expression is:
  -- (g_bot + inv_bot) - (g_top + inv_top) + I*(g_right + inv_right) - I*(g_left + inv_left)
  -- = [g_bot - g_top + I*g_right - I*g_left] + [inv_bot - inv_top + I*inv_right - I*inv_left]
  -- = 0 + 2πi = 2πi
  linear_combination rect_g + rect_inv

/-- Finite-R Perron bound for y > 1:
    ‖perronIntegral - 1‖ ≤ y^c/(π·T·|log y|) + T·y^(-R)/(π·R). -/
lemma perron_integral_bound_with_R_gt_one {y c R T : ℝ} (hy : 1 < y)
    (hc : 0 < c) (hR : 0 < R) (hT : 0 < T) :
    ‖perronIntegral y c T - 1‖ ≤
      y ^ c / (Real.pi * T * |Real.log y|) + T * y ^ (-R) / (Real.pi * R) := by
  have hy_pos : 0 < y := lt_trans one_pos hy
  -- Abbreviate the four integrals
  set bot := ∫ x in (-R)..c, perronIntegrand y (↑x + -↑T * I) with hbot_def
  set top := ∫ x in (-R)..c, perronIntegrand y (↑x + ↑T * I) with htop_def
  set rv := ∫ t in (-T)..T, perronIntegrand y (↑c + ↑t * I) with hrv_def
  set lv := ∫ t in (-T)..T, perronIntegrand y (-↑R + ↑t * I) with hlv_def
  -- Step 1: Rectangle identity gives bot - top + I*rv - I*lv = 2πi
  have rect := left_rectangle_perron_winding hy_pos hc hR hT
  -- Extract: I*rv = 2πi + top - bot + I*lv
  have hrv_eq : I * rv = 2 * ↑Real.pi * I - (bot - top) + I * lv := by
    linear_combination rect
  -- rv = 2π + (-I)(top - bot) + lv
  have hrv_eq2 : rv = 2 * ↑Real.pi + (-I) * (top - bot) + lv := by
    have hI_ne : (I : ℂ) ≠ 0 := Complex.I_ne_zero
    have key : rv = I⁻¹ * (I * rv) := by rw [inv_mul_cancel_left₀ hI_ne]
    rw [key, hrv_eq, Complex.inv_I]
    have hII : (-I : ℂ) * I = 1 := by
      simp [Complex.ext_iff, Complex.I_re, Complex.I_im]
    ring_nf
    simp [Complex.I_mul_I]
  -- Step 2: perronIntegral - 1 = (1/(2π))(-I(top - bot) + lv)
  have hP_sub : perronIntegral y c T - 1 =
      (1 / (2 * ↑Real.pi)) * ((-I) * (top - bot) + lv) := by
    show (1 / (2 * ↑Real.pi)) * rv - 1 =
        (1 / (2 * ↑Real.pi)) * ((-I) * (top - bot) + lv)
    rw [hrv_eq2]
    have hpi_ne : (2 * ↑Real.pi : ℂ) ≠ 0 := by
      apply mul_ne_zero (by norm_num : (2:ℂ) ≠ 0)
      exact Complex.ofReal_ne_zero.mpr (ne_of_gt Real.pi_pos)
    field_simp; ring
  -- Step 3: Bound the three segments
  have hbot_bound := horizontal_segment_bound_gt_one hy hc hR.le hT (-1) (by norm_num)
  have htop_bound := horizontal_segment_bound_gt_one hy hc hR.le hT 1 (by norm_num)
  simp only [neg_one_mul, one_mul, Complex.ofReal_neg] at hbot_bound htop_bound
  have hlv_bound := left_vertical_bound hy hR hT
  -- Step 4: Triangle inequality
  have herr_bound : ‖(-I) * (top - bot) + lv‖ ≤ ‖top‖ + ‖bot‖ + ‖lv‖ := by
    calc ‖(-I) * (top - bot) + lv‖
        ≤ ‖(-I) * (top - bot)‖ + ‖lv‖ := norm_add_le _ _
      _ = ‖top - bot‖ + ‖lv‖ := by
          rw [norm_mul, norm_neg, Complex.norm_I, one_mul]
      _ ≤ (‖top‖ + ‖bot‖) + ‖lv‖ := by
          gcongr; exact norm_sub_le _ _
  -- Step 5: Unfold perronIntegral and compute norm
  rw [hP_sub, norm_mul]
  have hpi_pos : (0 : ℝ) < Real.pi := Real.pi_pos
  have h2pi_norm : ‖(1 : ℂ) / (2 * ↑Real.pi)‖ = 1 / (2 * Real.pi) := by
    rw [norm_div, norm_one, norm_mul, Complex.norm_ofNat, Complex.norm_real]
    simp [abs_of_pos hpi_pos]
  rw [h2pi_norm]
  have h2pi_pos : 0 < 2 * Real.pi := by positivity
  -- Final calc
  calc 1 / (2 * Real.pi) * ‖(-I) * (top - bot) + lv‖
      ≤ 1 / (2 * Real.pi) * (‖top‖ + ‖bot‖ + ‖lv‖) := by
        gcongr
    _ ≤ 1 / (2 * Real.pi) *
        (y ^ c / (T * |Real.log y|) + y ^ c / (T * |Real.log y|) + 2 * T * y ^ (-R) / R) := by
        gcongr
    _ = y ^ c / (Real.pi * T * |Real.log y|) + T * y ^ (-R) / (Real.pi * R) := by
        field_simp; ring

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
  -- By contradiction: assume the bound fails, then choose R so large
  -- that the left vertical contribution is negligible.
  by_contra hlt
  push_neg at hlt
  set δ := ‖perronIntegral y c T - 1‖ - y ^ c / (Real.pi * T * |Real.log y|) with hδ_def
  have hδ : 0 < δ := by linarith
  -- Choose R large enough that T/(πR) < δ
  set R := max 1 (T / (Real.pi * δ) + 1) with hR_def
  have hR_pos : 0 < R := by
    calc (0:ℝ) < 1 := one_pos
      _ ≤ R := le_max_left _ _
  -- Apply the finite-R bound
  have hbound := perron_integral_bound_with_R_gt_one hy hc hR_pos hT
  -- Bound y^(-R) ≤ 1 since y > 1 and R > 0
  -- y^(-R) = 1/y^R and y^R ≥ 1 since y ≥ 1
  have hyR_le : y ^ (-R) ≤ 1 := by
    have : 1 ≤ y ^ R := one_le_rpow hy.le hR_pos.le
    rw [rpow_neg (le_of_lt (lt_trans one_pos hy))]
    exact inv_le_one_of_one_le₀ this
  -- So: T * y^(-R) / (πR) ≤ T / (πR)
  have herr_le : T * y ^ (-R) / (Real.pi * R) ≤ T / (Real.pi * R) := by
    apply div_le_div_of_nonneg_right _ (mul_pos Real.pi_pos hR_pos).le
    calc T * y ^ (-R) ≤ T * 1 := by gcongr
      _ = T := mul_one T
  -- And R > T/(πδ), so T/(πR) < δ
  have hR_big : T / (Real.pi * δ) < R := by
    calc T / (Real.pi * δ) < T / (Real.pi * δ) + 1 := by linarith
      _ ≤ R := le_max_right _ _
  have herr_lt : T / (Real.pi * R) < δ := by
    rw [div_lt_iff₀ (mul_pos Real.pi_pos hR_pos)]
    have hπδ_pos := mul_pos Real.pi_pos hδ
    have := (div_lt_iff₀ hπδ_pos).mp hR_big
    linarith
  -- Combine: ‖P - 1‖ ≤ target + T·y^(-R)/(πR) ≤ target + T/(πR) < target + δ
  -- But δ = ‖P - 1‖ - target, contradiction
  linarith

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
