import Cathedral.Perron.Defs
import Cathedral.Perron.IntegralBounds
import Cathedral.Perron.Rectangle

/-!
  Cathedral/Perron/ResidueLtOne.lean

  Residue analysis for σ < 1 in the Perron contour.
  Handles the contribution from ζ-zeros inside the contour.

  PROVED. Zero axioms.
-/

/-!
# Perron Kernel for `y < 1` (No Residue)

This file proves that the Perron integral `(1/2π) ∫ y^s/s ds` is
`O(y^c/(T·|log y|))` for `0 < y < 1`.

The proof uses the **right-rectangle contour shift**: apply Cauchy-Goursat to `[c,R]×[-T,T]`
(which encloses no poles since `c > 0`), bound the horizontal and right-vertical segments,
then send `R → ∞`. The exponential decay `y^R → 0` for `0 < y < 1` kills the right vertical.

## Main results

* `perron_kernel_lt_one` : for `0 < y < 1`, `‖P(y,c,T)‖ ≤ y^c/(π·T·|log y|)`
-/

noncomputable section
open Complex Real MeasureTheory Set BigOperators ComplexConjugate

namespace Cathedral.Perron

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
  push Not at hlt
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

end Cathedral.Perron

