/-
  Cathedral/Perron/VerticalBounds.lean

  ## Reusable Lemmas for Vertical Contour Bounds

  Provides production-quality helpers for bounding integrals of the form
    ∫_{-T}^T x^(σ+ti) / ((σ+ti) · ζ(σ+ti)) dt
  under the Riemann Hypothesis.

  ### Helpers Provided:
  1. `perron_integrand_denom_pos` — denominator positivity
  2. `perron_vertical_continuousOn` — ContinuousOn of the integrand
  3. `norm_perron_integrand_eq` — norm factorization: x^σ / ‖denom‖
  4. `perron_integrand_pointwise_bound` — pointwise bound for |t| ≥ T₀
  5. `rpow_integral_bound` — ∫_{a}^{b} t^{α-1} dt ≤ b^α / α

  ### Dependencies:
  - ZetaConvexity.lean: rh_zeta_ne_zero, inv_zeta_bound_under_rh
  - Defs.lean: norm_one_div_two_pi_le
-/

import Cathedral.Perron.Defs
import Cathedral.White.Infrastructure.ZetaConvexity

noncomputable section
open Complex Real MeasureTheory Set Filter
open scoped Topology

namespace Cathedral.White.Infrastructure

-- ═══════════════════════════════════════════
-- §1. Denominator Positivity
-- ═══════════════════════════════════════════

/-- Under RH with σ > 1/2 and σ ≠ 1, the denominator (σ+ti)·ζ(σ+ti) is nonzero. -/
lemma perron_integrand_denom_ne_zero (hRH : RiemannHypothesis)
    (σ : ℝ) (hσ : 1/2 < σ) (hσ_ne : σ ≠ 1) (t : ℝ) :
    (↑σ + ↑t * I : ℂ) * riemannZeta (↑σ + ↑t * I) ≠ 0 := by
  apply mul_ne_zero
  · -- σ + ti ≠ 0 since Re(s) = σ > 1/2 > 0
    intro h0; have := congr_arg Complex.re h0; simp at this; linarith
  · -- ζ(σ+ti) ≠ 0 under RH (since Re > 1/2 and s ≠ 1)
    have hs_ne_one : (↑σ + ↑t * I : ℂ) ≠ 1 := by
      intro h; apply hσ_ne
      have := congr_arg Complex.re h
      simp [Complex.add_re, Complex.ofReal_re, Complex.mul_re,
        Complex.I_re, Complex.I_im] at this; exact this
    exact rh_zeta_ne_zero hRH (by simp; linarith) hs_ne_one

/-- The denominator norm is strictly positive. -/
lemma perron_integrand_denom_pos (hRH : RiemannHypothesis)
    (σ : ℝ) (hσ : 1/2 < σ) (hσ_ne : σ ≠ 1) (t : ℝ) :
    0 < ‖(↑σ + ↑t * I : ℂ) * riemannZeta (↑σ + ↑t * I)‖ :=
  norm_pos_iff.mpr (perron_integrand_denom_ne_zero hRH σ hσ hσ_ne t)

-- ═══════════════════════════════════════════
-- §2. ContinuousOn (the most-duplicated pattern!)
-- ═══════════════════════════════════════════

/-- **ContinuousOn** of x^(σ+ti)/((σ+ti)·ζ(σ+ti)) as a function of t,
    on any set S ⊆ ℝ, under RH with σ > 1/2 and σ ≠ 1.

    This pattern was previously duplicated 3+ times:
    - ContourShift.lean L216-244
    - ZetaConvexity.lean L270-326
    - AssemblyHelpers.lean (inline)

    Proof structure:
    - Numerator x^s: ContinuousOn.cpow + slitPlane (x > 0)
    - Denominator s·ζ(s): Continuous.mul + differentiable_riemannZeta (s ≠ 1)
    - Nonvanishing: perron_integrand_denom_ne_zero -/
lemma perron_vertical_continuousOn (hRH : RiemannHypothesis)
    (x σ : ℝ) (hx : 0 < x) (hσ : 1/2 < σ) (hσ_ne : σ ≠ 1) (S : Set ℝ) :
    ContinuousOn (fun t : ℝ => (x : ℂ) ^ (↑σ + ↑t * I) /
      ((↑σ + ↑t * I) * riemannZeta (↑σ + ↑t * I))) S := by
  have hs_ne_one : ∀ t : ℝ, (↑σ + ↑t * I : ℂ) ≠ 1 := by
    intro t h; apply hσ_ne
    have := congr_arg Complex.re h
    simp [Complex.add_re, Complex.ofReal_re, Complex.mul_re,
      Complex.I_re, Complex.I_im] at this; exact this
  apply ContinuousOn.div
  · -- Numerator: x^(σ+ti) is continuous (x > 0 gives slitPlane)
    exact ContinuousOn.cpow continuousOn_const (by fun_prop)
      (fun _ _ => Complex.ofReal_mem_slitPlane.mpr (by linarith))
  · -- Denominator: (σ+ti)·ζ(σ+ti) is continuous
    apply ContinuousOn.mul (by fun_prop)
    exact (fun t _ => ContinuousAt.continuousWithinAt <|
      ContinuousAt.comp (differentiableAt_riemannZeta (hs_ne_one t)).continuousAt
        (by fun_prop : ContinuousAt (fun t : ℝ => (↑σ + ↑t * I : ℂ)) t))
  · -- Denominator ≠ 0
    intro t _
    exact perron_integrand_denom_ne_zero hRH σ hσ hσ_ne t

/-- Immediate corollary: IntervalIntegrable on any [a,b]. -/
lemma perron_vertical_integrable (hRH : RiemannHypothesis)
    (x σ : ℝ) (hx : 0 < x) (hσ : 1/2 < σ) (hσ_ne : σ ≠ 1) (a b : ℝ) :
    IntervalIntegrable (fun t : ℝ => (x : ℂ) ^ (↑σ + ↑t * I) /
      ((↑σ + ↑t * I) * riemannZeta (↑σ + ↑t * I))) volume a b :=
  (perron_vertical_continuousOn hRH x σ hx hσ hσ_ne _).intervalIntegrable

-- ═══════════════════════════════════════════
-- §3. Norm Factorization
-- ═══════════════════════════════════════════

/-- ‖x^(σ+ti)/((σ+ti)·ζ(σ+ti))‖ = x^σ / ‖(σ+ti)·ζ(σ+ti)‖ for x > 0.
    Factors the numerator norm using ‖x^s‖ = x^{Re(s)} = x^σ. -/
lemma norm_perron_integrand_eq (x σ t : ℝ) (hx : 0 < x) :
    ‖(x : ℂ) ^ (↑σ + ↑t * I) / ((↑σ + ↑t * I) * riemannZeta (↑σ + ↑t * I))‖ =
    x ^ σ / ‖(↑σ + ↑t * I : ℂ) * riemannZeta (↑σ + ↑t * I)‖ := by
  rw [norm_div, norm_cpow_eq_rpow_re_of_pos hx]
  congr 1
  simp [Complex.add_re, Complex.ofReal_re, Complex.mul_re,
    Complex.I_re, Complex.I_im, Complex.ofReal_im]

-- ═══════════════════════════════════════════
-- §4. Pointwise Lindelöf Bound for |t| ≥ T₀
-- ═══════════════════════════════════════════

/-- Pointwise bound: ‖x^(σ+ti)/((σ+ti)·ζ(σ+ti))‖ ≤ x^σ · C · |t|^{ε₀-1}
    for |t| ≥ T₀, using the Lindelöf bound on 1/ζ.

    Decomposition: ‖f‖ = x^σ / (‖s‖ · ‖ζ(s)‖)
                       ≤ x^σ · (1/|t|) · (C·|t|^ε₀)
                       = x^σ · C · |t|^{ε₀-1}. -/
lemma perron_integrand_pointwise_bound
    {x σ C T₀ ε₀ : ℝ} (hx : 0 < x) (hC : 0 < C) (_hε₀ : 0 < ε₀)
    (h_half_ε₀ : 1/2 + ε₀ ≤ σ)
    (hzeta_bound : ∀ s : ℂ, (1/2 + ε₀ ≤ s.re) → (T₀ ≤ |s.im|) →
      ‖(1 : ℂ) / riemannZeta s‖ ≤ C * |s.im| ^ ε₀)
    {t : ℝ} (ht : T₀ ≤ |t|) (hT₀ : 0 < T₀) :
    ‖(x : ℂ) ^ (↑σ + ↑t * I) / ((↑σ + ↑t * I) * riemannZeta (↑σ + ↑t * I))‖ ≤
    x ^ σ * C * |t| ^ (ε₀ - 1) := by
  set s : ℂ := ↑σ + ↑t * I
  have hs_re : s.re = σ := by
    simp [s, Complex.add_re, Complex.ofReal_re, Complex.mul_re,
          Complex.I_re, Complex.I_im, Complex.ofReal_im]
  have hs_im : s.im = t := by
    simp [s, Complex.add_im, Complex.ofReal_im, Complex.mul_im,
          Complex.ofReal_re, Complex.I_re, Complex.I_im]
  have ht_pos : 0 < |t| := lt_of_lt_of_le hT₀ ht
  -- Bounds from hypotheses
  have h_inv_zeta : ‖(1 : ℂ) / riemannZeta s‖ ≤ C * |t| ^ ε₀ := by
    have := hzeta_bound s (by rw [hs_re]; linarith) (by rw [hs_im]; exact ht)
    rwa [hs_im] at this
  have h_norm_s_ge : |t| ≤ ‖s‖ := by rw [← hs_im]; exact abs_im_le_norm s
  -- Decompose ‖a/(b·c)‖ = ‖a‖/(‖b‖·‖c‖)
  rw [norm_div, norm_mul, norm_cpow_eq_rpow_re_of_pos hx, hs_re]
  by_cases hζ : ‖riemannZeta s‖ = 0
  · simp [hζ]; positivity
  · have hζ_pos : 0 < ‖riemannZeta s‖ :=
      lt_of_le_of_ne (norm_nonneg _) (Ne.symm hζ)
    rw [div_mul_eq_div_div]
    calc x ^ σ / ‖s‖ / ‖riemannZeta s‖
        = (x ^ σ / ‖s‖) * (1 / ‖riemannZeta s‖) := by ring
      _ ≤ (x ^ σ / |t|) * (C * |t| ^ ε₀) := by
          apply mul_le_mul
          · exact div_le_div₀ (by positivity) le_rfl ht_pos h_norm_s_ge
          · rwa [norm_div, norm_one] at h_inv_zeta
          · positivity
          · positivity
      _ = x ^ σ * C * (|t| ^ ε₀ / |t|) := by ring
      _ = x ^ σ * C * |t| ^ (ε₀ - 1) := by
          congr 1; rw [rpow_sub ht_pos, rpow_one]

-- ═══════════════════════════════════════════
-- §5. rpow Integral Bound
-- ═══════════════════════════════════════════

/-- ∫_{a}^{b} t^{α-1} dt ≤ b^α / α, for 0 < α, 0 < a ≤ b.
    Proof: evaluate via integral_rpow, drop the negative -a^α/α term. -/
lemma rpow_integral_bound {a b α : ℝ} (ha : 0 < a) (_hab : a ≤ b) (hα : 0 < α) :
    ∫ t in a..b, t ^ (α - 1) ≤ b ^ α / α := by
  rw [integral_rpow (Or.inl (show -1 < α - 1 from by linarith))]
  simp only [show α - 1 + 1 = α from by ring]
  rw [sub_div]
  linarith [div_nonneg (rpow_nonneg ha.le α) hα.le]

/-- Integrability of t^{α-1} on [a, b] for α > 0. -/
lemma rpow_sub_one_integrable {a b α : ℝ} (hα : 0 < α) :
    IntervalIntegrable (fun t => t ^ (α - 1)) volume a b :=
  intervalIntegral.intervalIntegrable_rpow' (show -1 < α - 1 from by linarith)

-- ═══════════════════════════════════════════
-- §6. Compact Bound for Inner Integral
-- ═══════════════════════════════════════════

/-- On compact [-T₀, T₀], the denominator has a positive minimum.
    Returns the minimum value, which is independent of x and T. -/
lemma perron_denom_compact_min (hRH : RiemannHypothesis)
    (σ : ℝ) (hσ : 1/2 < σ) (hσ_ne : σ ≠ 1) (T₀ : ℝ) (hT₀ : 0 < T₀) :
    ∃ g_min > 0, ∀ t ∈ Set.Icc (-T₀) T₀,
      g_min ≤ ‖(↑σ + ↑t * I : ℂ) * riemannZeta (↑σ + ↑t * I)‖ := by
  set g : ℝ → ℝ := fun t => ‖(↑σ + ↑t * I : ℂ) * riemannZeta (↑σ + ↑t * I)‖
  -- g is continuous (composition of continuous functions)
  have hg_cont : Continuous g := by
    apply Continuous.norm
    apply Continuous.mul (by fun_prop)
    rw [continuous_iff_continuousAt]; intro t
    have hs_ne : (↑σ + ↑t * I : ℂ) ≠ 1 := by
      intro h; apply hσ_ne
      have := congr_arg Complex.re h
      simp [Complex.add_re, Complex.ofReal_re, Complex.mul_re,
        Complex.I_re, Complex.I_im] at this; exact this
    exact ContinuousAt.comp (differentiableAt_riemannZeta hs_ne).continuousAt
      (by fun_prop : ContinuousAt (fun t : ℝ => (↑σ + ↑t * I : ℂ)) t)
  -- On compact Icc, g achieves a minimum
  obtain ⟨t_min, ht_min_mem, ht_min_val⟩ :=
    IsCompact.exists_isMinOn isCompact_Icc
      (⟨0, by constructor <;> linarith⟩ : (Set.Icc (-T₀) T₀).Nonempty)
      hg_cont.continuousOn
  exact ⟨g t_min, perron_integrand_denom_pos hRH σ hσ hσ_ne t_min,
         fun t ht => ht_min_val ht⟩

end Cathedral.White.Infrastructure
