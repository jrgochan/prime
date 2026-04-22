/-
  Cathedral/White/Infrastructure/Perron/Rectangle.lean

  ## Rectangle Sub-lemmas

  Cauchy-Goursat for y^s/s on the rectangle [c,R]×[-T,T]
  and the right vertical segment bound.
-/

import Cathedral.White.Infrastructure.Perron.Defs

noncomputable section
open Complex Real MeasureTheory Set BigOperators ComplexConjugate

namespace Cathedral.White.Infrastructure

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
  have rect_ne_zero : ∀ s ∈ Set.uIcc c R ×ℂ Set.uIcc (-T) T, s ≠ (0 : ℂ) := by
    intro s hs h0
    have hre : s.re ∈ Set.uIcc c R := (Complex.mem_reProdIm.mp hs).1
    rw [h0] at hre
    simp [Set.mem_uIcc, Complex.zero_re] at hre
    rcases hre with ⟨h1, _⟩ | ⟨_, h2⟩ <;> linarith
  have hDiff : DifferentiableOn ℂ (perronIntegrand y) (Set.uIcc c R ×ℂ Set.uIcc (-T) T) :=
    fun s hs => (perronIntegrand_differentiableAt hy (rect_ne_zero s hs)).differentiableWithinAt
  have key := Complex.integral_boundary_rect_eq_zero_of_differentiableOn
    (perronIntegrand y) ⟨c, -T⟩ ⟨R, T⟩ hDiff
  simp only [smul_eq_mul] at key
  rwa [Complex.ofReal_neg] at key

/-- The right vertical segment is bounded by 2T·y^R/R for y < 1.
    For each t, ‖y^{R+tI}/(R+tI)‖ = y^R/‖R+tI‖ ≤ y^R/R since ‖R+tI‖ ≥ R. -/
lemma right_vertical_bound {y R T : ℝ} (hy_pos : 0 < y) (hy_lt : y < 1)
    (hR : 0 < R) (hT : 0 < T) :
    ‖∫ t in (-T)..T, perronIntegrand y (R + t * I)‖ ≤ 2 * T * y ^ R / R := by
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
    calc (R : ℝ) = |(↑R + ↑t * I).re| := by simp [hre, abs_of_pos hR]
      _ ≤ ‖(↑R : ℂ) + ↑t * I‖ := Complex.abs_re_le_norm _
  calc ‖∫ t in (-T)..T, perronIntegrand y (↑R + ↑t * I)‖
      ≤ (y ^ R / R) * |T - (-T)| :=
        intervalIntegral.norm_integral_le_of_norm_le_const_ae
          (Filter.Eventually.of_forall pointwise_bound)
    _ = 2 * T * y ^ R / R := by
        rw [sub_neg_eq_add, ← two_mul, abs_of_pos (by linarith : 0 < 2 * T)]
        ring

end Cathedral.White.Infrastructure
