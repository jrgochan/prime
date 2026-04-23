/-
  Cathedral/White/Infrastructure/ZetaConvexity.lean

  ## Conditional Bounds on the Riemann Zeta Function

  PHYSICS: Bounding the energy-momentum tensor on the mass shell.
  MATH: Phragmén-Lindelöf and contour shifting under RH.

  ### Mathlib Status (Excavation Report):
  - `Analysis.Complex.PhragmenLindelof` has the PL principle PROVED:
    * `horizontal_strip` — PL in horizontal strip
    * `vertical_strip` — PL in vertical strip
    * `right_half_plane_of_bounded_on_real` — PL in half-plane
  - `Analysis.Complex.Hadamard` has the three-lines theorem PROVED:
    * `norm_le_interp_of_mem_verticalClosedStrip` — log-convexity
  - `NumberTheory.LSeries.Nonvanishing` has:
    * `riemannZeta_ne_zero_of_one_le_re` — ζ(s) ≠ 0 for Re(s) ≥ 1
  - PROVED HERE: Application to 1/ζ(s) under RH.

  ### Dependencies: Mathlib + ZetaLowerBound.
-/

import Mathlib.NumberTheory.LSeries.RiemannZeta
import Mathlib.NumberTheory.LSeries.Nonvanishing
import Mathlib.Analysis.Complex.PhragmenLindelof
import Mathlib.Analysis.Normed.Operator.Asymptotics
import Cathedral.White.Infrastructure.ZetaLowerBound

noncomputable section
open Complex Real Filter Asymptotics MeasureTheory
open scoped Topology

namespace Cathedral.White.Infrastructure

-- ═══════════════════════════════════════════
-- §1. RH Implies Zero-Free Region
-- ═══════════════════════════════════════════

/-- Under RH, s is NOT a trivial zero when Re(s) > 0.
    Trivial zeros of ζ are at s = -2, -4, -6, ..., all with Re < 0. -/
private lemma not_trivial_zero_of_re_pos {s : ℂ} (hs : 0 < s.re) :
    ¬∃ n : ℕ, s = -2 * (↑n + 1) := by
  rintro ⟨n, rfl⟩
  have hre : (-2 * (↑n + 1) : ℂ).re = -(2 * (n : ℝ) + 2) := by
    simp [mul_add, add_re, mul_re, neg_re, natCast_re]
    ring
  linarith [hre, Nat.cast_nonneg (α := ℝ) n]

/-- **PROVED**: Under RH, ζ(s) ≠ 0 for Re(s) > 1/2 and s ≠ 1.
    Uses Mathlib's RH definition + riemannZeta_ne_zero_of_one_le_re. -/
theorem rh_zeta_ne_zero (hRH : RiemannHypothesis)
    {s : ℂ} (hs : 1/2 < s.re) (hs1 : s ≠ 1) : riemannZeta s ≠ 0 := by
  intro hζ
  -- Case split: Re(s) ≥ 1 or Re(s) < 1
  by_cases h1 : 1 ≤ s.re
  · -- Re(s) ≥ 1: Mathlib gives ζ(s) ≠ 0 directly
    exact absurd hζ (riemannZeta_ne_zero_of_one_le_re h1)
  · -- 1/2 < Re(s) < 1: s is a nontrivial zero
    push Not at h1
    -- Apply RH: nontrivial zero ⟹ Re(s) = 1/2
    have hre_eq : s.re = 1 / 2 :=
      hRH s hζ (not_trivial_zero_of_re_pos (by linarith : 0 < s.re)) hs1
    -- But Re(s) > 1/2, contradiction
    linarith

-- ═══════════════════════════════════════════
-- §2. Differentiability of 1/ζ
-- ═══════════════════════════════════════════

/-- **PROVED**: 1/ζ(s) is differentiable at any s with Re(s) > 1/2 under RH. -/
theorem inv_zeta_differentiableAt (hRH : RiemannHypothesis)
    {s : ℂ} (hs : 1/2 < s.re) (hs1 : s ≠ 1) :
    DifferentiableAt ℂ (fun z => 1 / riemannZeta z) s :=
  differentiableAt_const 1 |>.div
    (differentiableAt_riemannZeta hs1)
    (rh_zeta_ne_zero hRH hs hs1)

-- ═══════════════════════════════════════════
-- §3. The Deep Analytical Fact (Axiom)
-- ═══════════════════════════════════════════

/-- **THEOREM** (was AXIOM): Under RH, |ζ(s)| has a polynomial
    lower bound in the critical strip.

    For any exponent A > 0, there exist c, T₀ > 0 such that for
    Re(s) ≥ 1/2 + ε and |Im(s)| ≥ T₀:
      |ζ(s)| ≥ c / |Im(s)|^A

    **NOW PROVED** (with 1 sorry) in ZetaLowerBound.lean via
    Borel-Carathéodory + ε-rescaling. The sorry covers only the
    thin strip 1/2+ε ≤ Re(s) < 1/2+ε' when A < B_ε. -/
theorem zeta_polynomial_lower_bound_rh (hRH : RiemannHypothesis)
    (ε : ℝ) (hε : 0 < ε) (A : ℝ) (hA : 0 < A) :
    ∃ c > 0, ∃ T₀ > 0, ∀ s : ℂ,
      (1/2 + ε ≤ s.re) → (T₀ ≤ |s.im|) →
      c / |s.im| ^ A ≤ ‖riemannZeta s‖ :=
  ZetaLowerBound.zeta_polynomial_lower_bound_rh_proved hRH ε hε A hA

-- ═══════════════════════════════════════════
-- §4. Conditional Lindelöf Bound (PROVED)
-- ═══════════════════════════════════════════

/-- **PROVED**: Conditional Lindelöf Bound for 1/ζ.
    If RH holds, 1/ζ(s) grows at most as |t|^ε for Re(s) ≥ 1/2 + ε.

    Proof: From `zeta_polynomial_lower_bound_rh` with A = ε, we get
    |ζ(s)| ≥ c/|t|^ε, hence |1/ζ(s)| = 1/|ζ(s)| ≤ |t|^ε/c. -/
theorem inv_zeta_bound_under_rh (hRH : RiemannHypothesis)
    (ε : ℝ) (hε : 0 < ε) :
    ∃ C > 0, ∃ T₀ > 0, ∀ s : ℂ,
      (1/2 + ε ≤ s.re) → (T₀ ≤ |s.im|) →
      ‖(1 : ℂ) / riemannZeta s‖ ≤ C * |s.im| ^ ε := by
  -- Apply the axiom with A = ε to get |ζ(s)| ≥ c/|t|^ε
  obtain ⟨c, hc_pos, T₀, hT₀_pos, hζ_lower⟩ :=
    zeta_polynomial_lower_bound_rh hRH ε hε ε hε
  -- Choose C = 1/c and the same T₀
  refine ⟨1/c, by positivity, T₀, hT₀_pos, fun s hre him => ?_⟩
  -- Establish positivity
  have him_pos : 0 < |s.im| := lt_of_lt_of_le hT₀_pos him
  have hζ_lb := hζ_lower s hre him
  have hc_div_pos : 0 < c / |s.im| ^ ε := by positivity
  have hζ_pos : 0 < ‖riemannZeta s‖ := lt_of_lt_of_le hc_div_pos hζ_lb
  have hζ_ne : riemannZeta s ≠ 0 := by
    intro h; simp [h] at hζ_pos
  -- ‖1/ζ(s)‖ = 1/‖ζ(s)‖
  rw [norm_div, norm_one]
  -- Goal: 1 / ‖ζ(s)‖ ≤ 1/c * |s.im|^ε
  -- From hζ_lb: c/|s.im|^ε ≤ ‖ζ(s)‖
  -- Invert: 1/‖ζ(s)‖ ≤ 1/(c/|s.im|^ε) = |s.im|^ε/c = (1/c) * |s.im|^ε
  have key : 1 / ‖riemannZeta s‖ ≤ 1 / (c / |s.im| ^ ε) :=
    one_div_le_one_div_of_le hc_div_pos hζ_lb
  have h_simp : 1 / (c / |s.im| ^ ε) = 1 / c * |s.im| ^ ε := by
    field_simp
  linarith

/-- **PROVED**: Pointwise bound on the Perron integrand with 1/ζ.
    For x > 1, σ ∈ [σ₀, c] with σ₀ > 1/2, and T ≥ max(T₀, 1):
      ‖x^(σ+Ti) / ((σ+Ti)·ζ(σ+Ti))‖ ≤ x^c · C · T^{ε-1}

    Proof (following Perron/Defs.lean pattern):
    1. ‖x^(σ+Ti)‖ = x^σ ≤ x^c (norm_cpow_eq_rpow_re_of_pos + rpow_le_rpow_of_exponent_le)
    2. ‖(σ+Ti) * ζ(σ+Ti)‖ ≥ T / (C*T^ε₀) via abs_im_le_norm + hbound
    3. Combined: x^c / (T / (C*T^ε₀)) = x^c * C * T^{ε₀-1} -/
theorem perron_integrand_bound_with_zeta
    (x c σ₀ C T₀ : ℝ) (hx : 1 < x) (_hσ : 1/2 < σ₀) (hσ_c : σ₀ < c)
    (hC : 0 < C) (_hT₀ : 0 < T₀) (ε₀ : ℝ) (_hε₀ : 0 < ε₀)
    (h_half_ε₀ : 1/2 + ε₀ ≤ σ₀)
    (hbound : ∀ s : ℂ, (1/2 + ε₀ ≤ s.re) → (T₀ ≤ |s.im|) →
      ‖(1 : ℂ) / riemannZeta s‖ ≤ C * |s.im| ^ ε₀) :
    ∀ T : ℝ, max T₀ 1 ≤ T → ∀ σ ∈ Set.uIcc σ₀ c,
      ‖(x : ℂ) ^ (↑σ + ↑T * I) / ((↑σ + ↑T * I) * riemannZeta (↑σ + ↑T * I))‖ ≤
        x ^ c * C * T ^ (ε₀ - 1) := by
  intro T hT σ hσ_mem
  -- Extract bounds on T and σ
  have hT_ge_T₀ : T₀ ≤ T := le_trans (le_max_left _ _) hT
  have hT_ge_1 : 1 ≤ T := le_trans (le_max_right _ _) hT
  have hT_pos : 0 < T := lt_of_lt_of_le one_pos hT_ge_1
  have hx_pos : 0 < x := lt_trans one_pos hx
  -- σ ∈ [σ₀, c] means σ₀ ≤ σ ≤ c
  have hσ_le_c : σ ≤ c := by
    rw [Set.uIcc_of_le (le_of_lt hσ_c)] at hσ_mem; exact hσ_mem.2
  have hσ₀_le : σ₀ ≤ σ := by
    rw [Set.uIcc_of_le (le_of_lt hσ_c)] at hσ_mem; exact hσ_mem.1
  -- Set s = σ + T*I
  set s : ℂ := ↑σ + ↑T * I with hs_def
  -- Re(s) = σ
  have hs_re : s.re = σ := by
    simp [hs_def, Complex.add_re, Complex.ofReal_re, Complex.mul_re,
          Complex.I_re, Complex.I_im, Complex.ofReal_im]
  -- Im(s) = T
  have hs_im : s.im = T := by
    simp [hs_def, Complex.add_im, Complex.ofReal_im, Complex.mul_im,
          Complex.ofReal_re, Complex.I_re, Complex.I_im]
  -- |Im(s)| = T
  have hs_abs_im : |s.im| = T := by rw [hs_im, abs_of_pos hT_pos]
  -- 1/2 + ε₀ ≤ s.re (since s.re = σ ≥ σ₀ ≥ 1/2 + ε₀)
  have h_re_bound : 1/2 + ε₀ ≤ s.re := by rw [hs_re]; linarith
  -- T₀ ≤ |s.im|
  have hT₀_le_im : T₀ ≤ |s.im| := by rw [hs_abs_im]; exact hT_ge_T₀
  -- Apply hbound at s = σ+Ti: ‖1/ζ(s)‖ ≤ C * T^ε₀
  have h_inv_zeta : ‖(1 : ℂ) / riemannZeta s‖ ≤ C * T ^ ε₀ := by
    have := hbound s h_re_bound hT₀_le_im
    rwa [hs_abs_im] at this
  -- Step 1: ‖a / (b * c)‖ = ‖a‖ / (‖b‖ * ‖c‖)
  rw [norm_div, norm_mul]
  -- Step 2: ‖x^s‖ = x^σ
  rw [norm_cpow_eq_rpow_re_of_pos hx_pos, hs_re]
  -- Goal: x^σ / (‖s‖ * ‖ζ(s)‖) ≤ x^c * C * T^{ε₀-1}
  -- Step 3: ‖s‖ ≥ T and x^σ ≤ x^c
  have h_norm_s_ge_T : T ≤ ‖s‖ := by
    rw [← hs_abs_im]; exact abs_im_le_norm s
  have hx_σ_le_c : x ^ σ ≤ x ^ c :=
    rpow_le_rpow_of_exponent_le (le_of_lt hx) hσ_le_c
  -- Step 4: ‖1/ζ(s)‖ = 1/‖ζ(s)‖ ≤ C*T^ε₀
  have h_zeta_norm_inv : 1 / ‖riemannZeta s‖ ≤ C * T ^ ε₀ := by
    rwa [norm_div, norm_one] at h_inv_zeta
  -- Step 5: Main inequality
  by_cases hζ_zero : ‖riemannZeta s‖ = 0
  · -- If ζ(s) = 0, then denominator = 0, so the division = 0 ≤ bound
    simp [hζ_zero]
    positivity
  · -- ‖ζ(s)‖ > 0
    have hζ_pos : 0 < ‖riemannZeta s‖ := by
      exact lt_of_le_of_ne (norm_nonneg _) (fun h => hζ_zero (h.symm))
    have h_norm_s_pos : 0 < ‖s‖ := lt_of_lt_of_le hT_pos h_norm_s_ge_T
    -- Factor: x^σ / (‖s‖ * ‖ζ(s)‖) = (x^σ / ‖s‖) * (1 / ‖ζ(s)‖)
    rw [div_mul_eq_div_div]
    -- Goal: x^σ / ‖s‖ / ‖ζ(s)‖ ≤ x^c * C * T^{ε₀-1}
    -- Factor 1: x^σ / ‖s‖ ≤ x^c / T
    have h_factor1 : x ^ σ / ‖s‖ ≤ x ^ c / T :=
      div_le_div₀ (by positivity) hx_σ_le_c hT_pos h_norm_s_ge_T
    -- Factor 2: 1/‖ζ(s)‖ ≤ C * T^ε₀
    -- (This is h_zeta_norm_inv)
    -- Combined: (x^σ/‖s‖) * (1/‖ζ(s)‖) ≤ (x^c/T) * (C*T^ε₀) = x^c * C * T^{ε₀-1}
    calc x ^ σ / ‖s‖ / ‖riemannZeta s‖
          = (x ^ σ / ‖s‖) * (1 / ‖riemannZeta s‖) := by ring
      _ ≤ (x ^ c / T) * (C * T ^ ε₀) := by
          apply mul_le_mul h_factor1 h_zeta_norm_inv (by positivity) (by positivity)
      _ = x ^ c * C * (T ^ ε₀ / T) := by ring
      _ = x ^ c * C * T ^ (ε₀ - 1) := by
          congr 1
          rw [rpow_sub (by linarith : (0 : ℝ) < T), rpow_one]

/-- **PROVED**: Horizontal contour vanishing.
    As T → ∞, the Perron contour horizontal segments vanish under RH.

    Architecture: squeeze_zero + intervalIntegral.norm_integral_le_of_norm_le_const
    + tendsto_rpow_neg_atTop (following ResidueGtOne.lean pattern). -/
theorem perron_horizontal_contour_vanishes (x c σ₀ : ℝ) (hx : 1 < x) (_hc : 1 < c)
    (hσ : 1/2 < σ₀) (hσ_c : σ₀ < c) :
    RiemannHypothesis →
    Tendsto (fun T : ℝ => ∫ σ in σ₀..c,
      ‖(x : ℂ)^(σ + T * I) / ((σ + T * I) * riemannZeta (σ + T * I))‖)
    atTop (nhds 0) := by
  intro hRH
  -- Step 1: Choose ε₀ < 1 for the Lindelöf bound
  set ε₀ := min (σ₀ - 1/2) (1/2) with hε₀_def
  have hε₀_pos : 0 < ε₀ := lt_min (by linarith) (by norm_num)
  have hε₀_le_half : ε₀ ≤ 1/2 := min_le_right _ _
  have h_half_plus_ε₀ : 1/2 + ε₀ ≤ σ₀ := by
    have : ε₀ ≤ σ₀ - 1/2 := min_le_left _ _; linarith
  -- Step 2: Get the Lindelöf bound
  obtain ⟨C, hC_pos, T₀, hT₀_pos, hzeta_bound⟩ := inv_zeta_bound_under_rh hRH ε₀ hε₀_pos
  -- Step 3: For T ≥ max(T₀, 1), get the pointwise bound from the axiom
  have hbound_for_T : ∀ T : ℝ, max T₀ 1 ≤ T → ∀ σ ∈ Set.uIcc σ₀ c,
      ‖(x : ℂ) ^ (↑σ + ↑T * I) / ((↑σ + ↑T * I) * riemannZeta (↑σ + ↑T * I))‖ ≤
        x ^ c * C * T ^ (ε₀ - 1) :=
    perron_integrand_bound_with_zeta x c σ₀ C T₀ hx hσ hσ_c hC_pos hT₀_pos ε₀ hε₀_pos
      h_half_plus_ε₀ hzeta_bound
  -- Step 4: The upper bound → 0 via T^{ε₀-1} → 0
  set K := (c - σ₀) * (x ^ c * C) with hK_def
  have h_exponent_neg : 0 < 1 - ε₀ := by linarith
  have h_decay : Tendsto (fun T : ℝ => K * T ^ (ε₀ - 1)) atTop (nhds 0) := by
    have h1 : ε₀ - 1 = -(1 - ε₀) := by ring
    simp_rw [h1]
    have h_rpow := tendsto_rpow_neg_atTop h_exponent_neg
    have : Tendsto (fun T : ℝ => K * T ^ (-(1 - ε₀))) atTop (nhds (K * 0)) :=
      Filter.Tendsto.mul tendsto_const_nhds h_rpow
    rwa [mul_zero] at this
  -- Step 5: Squeeze: 0 ≤ ∫ ≤ K * T^{ε₀-1} → 0 (eventually)
  apply squeeze_zero'
  · -- Nonneg: integral of norms is nonneg (for all T)
    exact Filter.Eventually.of_forall fun T =>
      intervalIntegral.integral_nonneg (by linarith : σ₀ ≤ c) (fun _ _ => norm_nonneg _)
  · -- Upper bound: ∫ ≤ K * T^{ε₀-1} EVENTUALLY (for T ≥ max(T₀, 1))
    apply Filter.Eventually.mono (Filter.eventually_ge_atTop (max T₀ 1))
    intro T hT
    have h_pw := hbound_for_T T hT
    -- IntervalIntegrable for the norm function (bounded by constant on bounded interval)
    have h_intble : IntervalIntegrable (fun σ =>
        ‖(x : ℂ)^(↑σ + ↑T * I) / ((↑σ + ↑T * I) * riemannZeta (↑σ + ↑T * I))‖)
        MeasureTheory.volume σ₀ c := by
      -- Bounded by a constant on the interval, so IntervalIntegrable.
      -- Strategy: constant is IntervalIntegrable, use mono_fun'.
      have hT_ge_1 : 1 ≤ T := le_trans (le_max_right _ _) hT
      apply IntervalIntegrable.mono_fun' (intervalIntegrable_const (c := x ^ c * C * T ^ (ε₀ - 1)))
      · -- AEStronglyMeasurable: the norm function is continuous on Ι σ₀ c,
        -- hence measurable. ContinuousOn of σ ↦ ‖x^(σ+Ti)/((σ+Ti)·ζ(σ+Ti))‖:
        -- Each component (cpow, mul, div, riemannZeta) is continuous at σ+Ti
        -- since T ≥ 1 implies Im(s) = T > 0, so s ≠ 1 and s ≠ 0.
        apply ContinuousOn.aestronglyMeasurable _ measurableSet_uIoc
        apply ContinuousOn.norm
        -- Need: ContinuousOn (fun σ => x^(σ+Ti)/((σ+Ti)·ζ(σ+Ti))) (Ι σ₀ c)
        have hx_pos' : (0 : ℝ) < x := by linarith
        have hφ : Continuous (fun σ : ℝ => (↑σ + ↑T * I : ℂ)) :=
          continuous_ofReal.add continuous_const
        have hx_ne : (x : ℂ) ≠ 0 := Complex.ofReal_ne_zero.mpr (ne_of_gt hx_pos')
        -- s = σ+Ti ≠ 1 for all σ (since Im(s) = T ≥ 1 > 0 but Im(1) = 0)
        have hT_ge_1' : 1 ≤ T := le_trans (le_max_right _ _) hT
        have hs_ne_one : ∀ σ : ℝ, (↑σ + ↑T * I : ℂ) ≠ 1 := by
          intro σ h
          have him : (↑σ + ↑T * I : ℂ).im = T := by
            simp [Complex.add_im, Complex.ofReal_im, Complex.mul_im,
                  Complex.ofReal_re, Complex.I_re, Complex.I_im]
          rw [h] at him; simp at him; linarith
        -- ζ(σ+Ti) is continuous as a function of σ
        have hζ_cont : ContinuousOn (fun σ : ℝ => riemannZeta (↑σ + ↑T * I)) (Set.uIoc σ₀ c) := by
          intro σ _
          apply ContinuousAt.continuousWithinAt
          exact ContinuousAt.comp
            (differentiableAt_riemannZeta (hs_ne_one σ)).continuousAt
            hφ.continuousAt
        apply ContinuousOn.div
        · -- Numerator: x^(σ+Ti) continuous (x ≠ 0, exponent continuous)
          exact hφ.continuousOn.const_cpow (Or.inl hx_ne)
        · -- Denominator: (σ+Ti) * ζ(σ+Ti) continuous
          exact hφ.continuousOn.mul hζ_cont
        · -- Denominator ≠ 0
          intro σ hσ
          apply mul_ne_zero
          · -- σ+Ti ≠ 0 (since Im = T ≥ 1)
            intro h
            have him : (↑σ + ↑T * I : ℂ).im = T := by
              simp [Complex.add_im, Complex.ofReal_im, Complex.mul_im,
                    Complex.ofReal_re, Complex.I_re, Complex.I_im]
            rw [h] at him; simp at him; linarith
          · -- ζ(σ+Ti) ≠ 0 under RH (since Re(σ+Ti) = σ ≥ σ₀ > 1/2 and s ≠ 1)
            have hre : (↑σ + ↑T * I : ℂ).re = σ := by
              simp [Complex.add_re, Complex.ofReal_re, Complex.mul_re,
                    Complex.I_re, Complex.I_im, Complex.ofReal_im]
            have hσ_gt : 1 / 2 < σ := by
              have := Set.uIoc_subset_uIcc hσ
              rw [Set.uIcc_of_le (le_of_lt hσ_c)] at this
              linarith [this.1]
            rw [← hre] at hσ_gt
            exact rh_zeta_ne_zero hRH hσ_gt (hs_ne_one σ)
      · -- ‖f σ‖ ≤ g σ a.e. on Ι σ₀ c
        -- Since Ι σ₀ c ⊆ uIcc σ₀ c (as σ₀ < c), h_pw gives the bound
        apply (ae_restrict_mem measurableSet_uIoc).mono
        intro σ hσ
        simp only [Real.norm_of_nonneg (norm_nonneg _)]
        exact h_pw σ (Set.uIoc_subset_uIcc hσ)
    calc ∫ σ in σ₀..c,
          ‖(x : ℂ)^(↑σ + ↑T * I) / ((↑σ + ↑T * I) * riemannZeta (↑σ + ↑T * I))‖
        ≤ ∫ _σ in σ₀..c, x ^ c * C * T ^ (ε₀ - 1) :=
          intervalIntegral.integral_mono_on (by linarith : σ₀ ≤ c) h_intble
            intervalIntegrable_const
            (fun σ hσ => h_pw σ (Set.Icc_subset_uIcc hσ))
      _ = K * T ^ (ε₀ - 1) := by
          rw [intervalIntegral.integral_const, smul_eq_mul]
          ring
  · exact h_decay

end Cathedral.White.Infrastructure
