/-
  Cathedral/Perron/AssemblyHelpers.lean

  Assembly helpers for the Mertens bound: truncated Perron formula
  and vertical contour bound on the σ₀ line.

  Architecture:
    §1. (DELETED: truncated_perron_for_moebius — dead end, see exploration5)
    §2. inner_integral_bound           (compact bound, ✅ FULLY PROVED)
    §3a. right_outer_integral_bound    (rpow integration, ✅ FULLY PROVED)
    §3b. left_outer_integral_bound     (symmetric via integral_comp_neg, ✅ FULLY PROVED)
    §4. three_part_combine             (assembly, ✅ FULLY PROVED)
    §5. perron_vertical_sigma0_bound   (main lemma, ✅ no new sorry)

  Uses production helpers from VerticalBounds.lean.
-/

import Cathedral.Perron.DirichletPoly
import Cathedral.Perron.ContourShift
import Cathedral.Perron.VerticalBounds
import Cathedral.Perron.HalfIntegerPerron

noncomputable section
open Complex Real MeasureTheory Set Filter ArithmeticFunction
open scoped LSeries.notation ArithmeticFunction.Moebius ArithmeticFunction.zeta Topology

namespace Cathedral.Perron

-- ═══════════════════════════════════════════
-- §1. Truncated Perron Formula
-- ═══════════════════════════════════════════

-- DELETED: truncated_perron_for_moebius (April 24, 2026)
--
-- This theorem attempted to bound M(x) via the Perron formula with x^s
-- in the contour integral. This is a mathematical dead-end because the
-- integral transfer X^s → x^s via MVT gives O(x^{c+1+2ε}) error,
-- not the target O(x^{1/2+ε}). See docs/ai/antigravity/exploration5/
-- "SUBJECT: ABORT THE TRANSFER" for the full analysis.
--
-- The correct approach (implemented in PerronMoebius.lean) works directly
-- with X = ⌊x⌋ + 1/2, never putting x^s into a contour integral.
-- M(x) = M(X) by step function property, then X ≤ (3/2)·x for the pushback.

-- ═══════════════════════════════════════════
-- §1b. rpow Helpers for T = X² Assembly
-- All PROVED — FULLY PROVED.
-- ═══════════════════════════════════════════

/-- (X²)^{-1/2} = X^{-1} for X > 0. -/
lemma rpow_sq_neg_half {X : ℝ} (hX : 0 < X) :
    (X ^ (2 : ℝ)) ^ (-((1:ℝ)/2)) = X ^ (-(1 : ℝ)) := by
  rw [← rpow_mul hX.le]; norm_num

/-- (X²)^{e} = X^{2e} for X > 0. -/
lemma rpow_sq_mul_exp {X e : ℝ} (hX : 0 < X) :
    (X ^ (2 : ℝ)) ^ e = X ^ (2 * e) := by
  rw [← rpow_mul hX.le]

/-- Perron term collapse: K * X^{c+1} / X² = K * X^{c-1}. -/
lemma perron_exp_collapse {K X c : ℝ} (hX : 0 < X) :
    K * X ^ (c + 1) / X ^ (2 : ℝ) = K * X ^ (c - 1) := by
  rw [mul_div_assoc, ← rpow_sub hX]; congr 1; ring_nf

/-- Shift term collapse: K₁ * X^c * (X²)^{-1/2} = K₁ * X^{c-1}. -/
lemma shift_exp_collapse {K₁ X c : ℝ} (hX : 0 < X) :
    K₁ * X ^ c * (X ^ (2 : ℝ)) ^ (-((1:ℝ)/2)) = K₁ * X ^ (c - 1) := by
  rw [rpow_sq_neg_half hX, mul_assoc, ← rpow_add hX]; ring_nf

/-- Vertical term collapse: K₂ * X^σ₀ * (X²)^{eps'} = K₂ * X^{σ₀+2eps'}. -/
lemma vert_exp_collapse {K₂ X sigma0 eps' : ℝ} (hX : 0 < X) :
    K₂ * X ^ sigma0 * (X ^ (2 : ℝ)) ^ eps' = K₂ * X ^ (sigma0 + 2 * eps') := by
  rw [rpow_sq_mul_exp hX, mul_assoc, ← rpow_add hX]

-- norm_one_div_two_pi_le already in Defs.lean (imported via VerticalBounds)

/-- Push X → x: X^α ≤ a^α * x^α when X ≤ a*x with a,x > 0, α > 0. -/
lemma rpow_le_mul_rpow {X x a α : ℝ} (hX : 0 < X) (hx : 0 < x) (ha : 0 < a)
    (hα : 0 < α) (h : X ≤ a * x) :
    X ^ α ≤ a ^ α * x ^ α := by
  calc X ^ α ≤ (a * x) ^ α := rpow_le_rpow hX.le h hα.le
    _ = a ^ α * x ^ α := mul_rpow ha.le hx.le

-- ═══════════════════════════════════════════
-- §2. Inner Integral Bound (compact [-T₀,T₀])
-- ═══════════════════════════════════════════

/-- On [-T₀, T₀], bound by the compact minimum of the denominator.
    ‖∫_{-T₀}^{T₀} f‖ ≤ x^σ · (1/g_min) · 2T₀.
    FULLY PROVED — uses norm_perron_integrand_eq + compact min. -/
private lemma inner_integral_bound
    {x sigma0 T₀ g_min : ℝ} (hx_pos : 0 < x) (hT₀_pos : 0 < T₀)
    (hg_min_pos : 0 < g_min)
    (hg_ge_min : ∀ t ∈ Set.Icc (-T₀) T₀,
      g_min ≤ ‖(↑sigma0 + ↑t * I : ℂ) * riemannZeta (↑sigma0 + ↑t * I)‖) :
    let f := fun t : ℝ => (x : ℂ) ^ (↑sigma0 + ↑t * I) /
        ((↑sigma0 + ↑t * I) * riemannZeta (↑sigma0 + ↑t * I))
    ‖∫ t in (-T₀)..T₀, f t‖ ≤ x ^ sigma0 * (1 / g_min) * (2 * T₀) := by
  intro f
  calc ‖∫ t in (-T₀)..T₀, f t‖
      ≤ (x ^ sigma0 * (1 / g_min)) * |T₀ - (-T₀)| := by
        apply intervalIntegral.norm_integral_le_of_norm_le_const
        intro t ht
        show ‖(x : ℂ) ^ (↑sigma0 + ↑t * I) /
          ((↑sigma0 + ↑t * I) * riemannZeta (↑sigma0 + ↑t * I))‖ ≤ _
        rw [norm_perron_integrand_eq x sigma0 t hx_pos]
        rw [Set.uIoc_of_le (by linarith : -T₀ ≤ T₀)] at ht
        have h_mem : t ∈ Set.Icc (-T₀) T₀ := ⟨le_of_lt ht.1, ht.2⟩
        show x ^ sigma0 / ‖(↑sigma0 + ↑t * I : ℂ) * riemannZeta (↑sigma0 + ↑t * I)‖ ≤
          x ^ sigma0 * (1 / g_min)
        rw [mul_one_div]
        exact div_le_div_of_nonneg_left (rpow_nonneg hx_pos.le _) hg_min_pos
          (hg_ge_min t h_mem)
    _ = x ^ sigma0 * (1 / g_min) * (2 * T₀) := by
        rw [abs_of_pos (by linarith)]; ring

-- ═══════════════════════════════════════════
-- §3. Outer Integral Bound (Lindelöf region)
-- ═══════════════════════════════════════════

/-- Right outer integral bound: ‖∫_{T₀}^T f‖ ≤ x^σ · C/ε₀ · T^{ε₀}.
    Uses pointwise bound + integral_mono + rpow_integral_bound. FULLY PROVED. -/
private lemma right_outer_integral_bound (hRH : RiemannHypothesis)
    {x sigma0 C T₀ ε₀ T : ℝ}
    (hx_pos : 0 < x) (hsigma0 : 1/2 < sigma0) (hsigma0_ne : sigma0 ≠ 1)
    (hC_pos : 0 < C) (hε₀_pos : 0 < ε₀) (_hε₀_le_one : ε₀ ≤ 1)
    (h_half_ε₀ : 1/2 + ε₀ ≤ sigma0) (hT₀_pos : 0 < T₀) (hT_ge_T₀ : T₀ ≤ T)
    (hzeta_bound : ∀ s : ℂ, (1/2 + ε₀ ≤ s.re) → (T₀ ≤ |s.im|) →
      ‖(1 : ℂ) / riemannZeta s‖ ≤ C * |s.im| ^ ε₀) :
    let f := fun t : ℝ => (x : ℂ) ^ (↑sigma0 + ↑t * I) /
        ((↑sigma0 + ↑t * I) * riemannZeta (↑sigma0 + ↑t * I))
    ‖∫ t in T₀..T, f t‖ ≤ x ^ sigma0 * C / ε₀ * T ^ ε₀ := by
  intro f
  -- Integrability of f and the bound function
  have hf_int : IntervalIntegrable f volume T₀ T :=
    perron_vertical_integrable hRH x sigma0 hx_pos hsigma0 hsigma0_ne T₀ T
  have hφ_int : IntervalIntegrable (fun t => x ^ sigma0 * C * t ^ (ε₀ - 1)) volume T₀ T :=
    (rpow_sub_one_integrable hε₀_pos).const_mul (x ^ sigma0 * C)
  -- Pointwise bound: ‖f(t)‖ ≤ x^σ · C · t^{ε₀-1} for t ∈ (T₀, T]
  have h_pw : ∀ t ∈ Set.Icc T₀ T, ‖f t‖ ≤ x ^ sigma0 * C * t ^ (ε₀ - 1) := by
    intro t ht
    have ht_pos : 0 < t := lt_of_lt_of_le hT₀_pos (le_of_eq rfl |>.trans ht.1)
    have ht_abs : |t| = t := abs_of_pos ht_pos
    have h_T₀_le : T₀ ≤ |t| := by rw [ht_abs]; exact ht.1
    have h := perron_integrand_pointwise_bound hx_pos hC_pos hε₀_pos h_half_ε₀
      hzeta_bound h_T₀_le hT₀_pos
    rwa [ht_abs] at h
  -- Chain: ‖∫f‖ ≤ ∫‖f‖ ≤ ∫ x^σ·C·t^{ε₀-1} = x^σ·C·∫t^{ε₀-1} ≤ x^σ·C·T^{ε₀}/ε₀
  calc ‖∫ t in T₀..T, f t‖
      ≤ ∫ t in T₀..T, ‖f t‖ :=
        intervalIntegral.norm_integral_le_integral_norm hT_ge_T₀
    _ ≤ ∫ t in T₀..T, x ^ sigma0 * C * t ^ (ε₀ - 1) := by
        apply intervalIntegral.integral_mono_on hT_ge_T₀ hf_int.norm hφ_int
        intro t ht; exact h_pw t ht
    _ = x ^ sigma0 * C * ∫ t in T₀..T, t ^ (ε₀ - 1) := by
        rw [intervalIntegral.integral_const_mul]
    _ ≤ x ^ sigma0 * C * (T ^ ε₀ / ε₀) :=
        mul_le_mul_of_nonneg_left (rpow_integral_bound hT₀_pos hT_ge_T₀ hε₀_pos)
          (by positivity)
    _ = x ^ sigma0 * C / ε₀ * T ^ ε₀ := by ring

/-- Left outer integral bound: ‖∫_{-T}^{-T₀} f‖ ≤ x^σ · C/ε₀ · T^{ε₀}.
    Same as right, using |t| = -t on [-T, -T₀]. -/
private lemma left_outer_integral_bound (hRH : RiemannHypothesis)
    {x sigma0 C T₀ ε₀ T : ℝ}
    (hx_pos : 0 < x) (hsigma0 : 1/2 < sigma0) (hsigma0_ne : sigma0 ≠ 1)
    (hC_pos : 0 < C) (hε₀_pos : 0 < ε₀) (_hε₀_le_one : ε₀ ≤ 1)
    (h_half_ε₀ : 1/2 + ε₀ ≤ sigma0) (hT₀_pos : 0 < T₀) (hT_ge_T₀ : T₀ ≤ T)
    (hzeta_bound : ∀ s : ℂ, (1/2 + ε₀ ≤ s.re) → (T₀ ≤ |s.im|) →
      ‖(1 : ℂ) / riemannZeta s‖ ≤ C * |s.im| ^ ε₀) :
    let f := fun t : ℝ => (x : ℂ) ^ (↑sigma0 + ↑t * I) /
        ((↑sigma0 + ↑t * I) * riemannZeta (↑sigma0 + ↑t * I))
    ‖∫ t in (-T)..(-T₀), f t‖ ≤ x ^ sigma0 * C / ε₀ * T ^ ε₀ := by
  intro f
  -- Reduce ∫_{-T}^{-T₀} f(t) dt = ∫_{T₀}^{T} f(-u) du via integral_comp_neg
  have h_sub : ∫ t in (-T)..(-T₀), f t = ∫ u in T₀..T, f (-u) := by
    have := (intervalIntegral.integral_comp_neg (f := f) (a := T₀) (b := T)).symm
    simpa only [neg_neg] using this
  rw [h_sub]
  -- Integrability of f(-u) on [T₀, T]
  have hf_neg_int : IntervalIntegrable (fun u => f (-u)) volume T₀ T := by
    have h := perron_vertical_integrable hRH x sigma0 hx_pos hsigma0 hsigma0_ne (-T) (-T₀)
    rw [IntervalIntegrable.iff_comp_neg] at h
    simp only [neg_neg] at h; exact h.symm
  -- Integrability of the bound function
  have hφ_int : IntervalIntegrable (fun t => x ^ sigma0 * C * t ^ (ε₀ - 1)) volume T₀ T :=
    (rpow_sub_one_integrable hε₀_pos).const_mul (x ^ sigma0 * C)
  -- Pointwise bound: ‖f(-u)‖ ≤ x^σ · C · u^{ε₀-1} for u ∈ [T₀, T]
  -- Since |-u| = u for u > 0, the Lindelöf bound at s = σ₀ - u·i gives the same estimate
  have h_pw : ∀ u ∈ Set.Icc T₀ T, ‖f (-u)‖ ≤ x ^ sigma0 * C * u ^ (ε₀ - 1) := by
    intro u hu
    have hu_pos : 0 < u := lt_of_lt_of_le hT₀_pos hu.1
    -- |-u| = u
    have h_abs : |(-u : ℝ)| = u := by rw [abs_neg, abs_of_pos hu_pos]
    have h_T₀_le : T₀ ≤ |(-u : ℝ)| := by rw [h_abs]; exact hu.1
    have h := perron_integrand_pointwise_bound hx_pos hC_pos hε₀_pos h_half_ε₀
      hzeta_bound h_T₀_le hT₀_pos
    rwa [h_abs] at h
  -- Chain: ‖∫f(-u)‖ ≤ ∫‖f(-u)‖ ≤ ∫ x^σ·C·u^{ε₀-1} ≤ x^σ·C·T^{ε₀}/ε₀
  calc ‖∫ u in T₀..T, f (-u)‖
      ≤ ∫ u in T₀..T, ‖f (-u)‖ :=
        intervalIntegral.norm_integral_le_integral_norm hT_ge_T₀
    _ ≤ ∫ u in T₀..T, x ^ sigma0 * C * u ^ (ε₀ - 1) := by
        apply intervalIntegral.integral_mono_on hT_ge_T₀ hf_neg_int.norm hφ_int
        intro u hu; exact h_pw u hu
    _ = x ^ sigma0 * C * ∫ u in T₀..T, u ^ (ε₀ - 1) := by
        rw [intervalIntegral.integral_const_mul]
    _ ≤ x ^ sigma0 * C * (T ^ ε₀ / ε₀) :=
        mul_le_mul_of_nonneg_left (rpow_integral_bound hT₀_pos hT_ge_T₀ hε₀_pos)
          (by positivity)
    _ = x ^ sigma0 * C / ε₀ * T ^ ε₀ := by ring

-- ═══════════════════════════════════════════
-- §4. Three-Part Assembly (pure algebra)
-- ═══════════════════════════════════════════

/-- Given bounds on the three parts, assemble the final bound.
    Triangle inequality + exponent monotonicity. FULLY PROVED. -/
private lemma three_part_combine
    {x sigma0 T ε₀ eps' M C_bound T₀ : ℝ}
    (_hT_pos : 0 < T) (hT_ge_1 : 1 ≤ T) (hε₀_le : ε₀ ≤ eps') (heps' : 0 < eps')
    (hT₀_pos : 0 < T₀) (hM_pos : 0 < M) (hC_bound_pos : 0 < C_bound) (hx_nonneg : 0 ≤ x)
    (I_left I_inner I_right : ℂ)
    (h_left : ‖I_left‖ ≤ x ^ sigma0 * C_bound * T ^ ε₀)
    (h_inner : ‖I_inner‖ ≤ x ^ sigma0 * M * (2 * T₀))
    (h_right : ‖I_right‖ ≤ x ^ sigma0 * C_bound * T ^ ε₀) :
    ‖I_left + I_inner + I_right‖ ≤
    (2 * T₀ * M + 2 * C_bound + 1) * x ^ sigma0 * T ^ eps' := by
  -- Exponent monotonicity and T^{eps'} ≥ 1
  have h_eps_mono : T ^ ε₀ ≤ T ^ eps' := rpow_le_rpow_of_exponent_le hT_ge_1 hε₀_le
  have hTe1 : (1 : ℝ) ≤ T ^ eps' := one_le_rpow hT_ge_1 heps'.le
  have hT_eps_pos : 0 < T ^ eps' := lt_of_lt_of_le one_pos hTe1
  -- Step 1: triangle inequality
  have h_tri : ‖I_left + I_inner + I_right‖ ≤
      ‖I_left‖ + ‖I_inner‖ + ‖I_right‖ := by
    have h1 := norm_add_le (I_left + I_inner) I_right
    have h2 := norm_add_le I_left I_inner
    linarith
  -- Step 2: substitute bounds
  set A := x ^ sigma0 * C_bound * T ^ ε₀
  set B := x ^ sigma0 * M * (2 * T₀)
  have h_sum : ‖I_left‖ + ‖I_inner‖ + ‖I_right‖ ≤ A + B + A := by linarith
  -- Step 3: A ≤ x^σ · C_bound · T^{eps'}
  have hA : A ≤ x ^ sigma0 * C_bound * T ^ eps' :=
    mul_le_mul_of_nonneg_left h_eps_mono (by positivity)
  -- Step 4: B ≤ B · T^{eps'}
  have hB : B ≤ B * T ^ eps' := le_mul_of_one_le_right (by positivity) hTe1
  -- Step 5: combine
  have hxs_nn : 0 ≤ x ^ sigma0 := rpow_nonneg (by positivity) _
  calc ‖I_left + I_inner + I_right‖
      ≤ A + B + A := le_trans h_tri h_sum
    _ ≤ (x ^ sigma0 * C_bound * T ^ eps') + (B * T ^ eps') +
        (x ^ sigma0 * C_bound * T ^ eps') := by linarith [hA, hB]
    _ = (2 * x ^ sigma0 * C_bound + B) * T ^ eps' := by ring
    _ ≤ (2 * x ^ sigma0 * C_bound + B + x ^ sigma0) * T ^ eps' := by
        linarith [mul_nonneg hxs_nn hT_eps_pos.le]
    _ = ((2 * C_bound + M * (2 * T₀) + 1) * x ^ sigma0) * T ^ eps' := by
        simp only [B]; ring
    _ = (2 * T₀ * M + 2 * C_bound + 1) * x ^ sigma0 * T ^ eps' := by ring

-- ═══════════════════════════════════════════
-- §5. Main Vertical Bound (assembly only)
-- ═══════════════════════════════════════════

set_option maxHeartbeats 800000 in
/-- Bounding the vertical contour on the σ₀ line using the Lindelöf bound.
    Assembles: inner_integral_bound + outer_integral_bound + three_part_combine. -/
lemma perron_vertical_sigma0_bound (hRH : RiemannHypothesis)
    (sigma0 : ℝ) (hsigma0 : 1/2 < sigma0) (hsigma0_ne : sigma0 ≠ 1)
    (eps' : ℝ) (heps' : 0 < eps') :
    ∃ C_vert > 0, ∃ T_min ≥ (1 : ℝ), ∀ x : ℝ, x ≥ 2 → ∀ T : ℝ, T_min ≤ T →
      ‖(1 / (2 * ↑Real.pi)) * ∫ t in (-T)..T,
        (x : ℂ) ^ (↑sigma0 + ↑t * I) /
        ((↑sigma0 + ↑t * I) * riemannZeta (↑sigma0 + ↑t * I))‖ ≤
      C_vert * x ^ sigma0 * T ^ eps' := by
  -- ε₀ choice + Lindelöf + compact min
  set ε₀ := min (min eps' (sigma0 - 1/2)) 1 / 2
  have hε₀_pos : 0 < ε₀ := div_pos (lt_min (lt_min heps' (by linarith)) one_pos) (by norm_num)
  have hε₀_le : ε₀ ≤ eps' :=
    le_trans (div_le_div_of_nonneg_right (le_trans (min_le_left _ _) (min_le_left _ _))
      (by norm_num)) (by linarith)
  have hε₀_le_one : ε₀ ≤ 1 := by
    calc ε₀ ≤ 1 / 2 := div_le_div_of_nonneg_right (min_le_right _ _) (by norm_num)
      _ ≤ 1 := by norm_num
  have h_half_ε₀ : 1/2 + ε₀ ≤ sigma0 := by
    have : ε₀ ≤ (sigma0 - 1/2) / 2 :=
      div_le_div_of_nonneg_right (le_trans (min_le_left _ _) (min_le_right _ _)) (by norm_num)
    linarith
  obtain ⟨C, hC_pos, T₀, hT₀_pos, hzeta_bound⟩ := Cathedral.Zeta.inv_zeta_bound_under_rh hRH ε₀ hε₀_pos
  obtain ⟨g_min, hg_min_pos, hg_ge_min⟩ :=
    perron_denom_compact_min hRH sigma0 hsigma0 hsigma0_ne T₀ hT₀_pos
  -- Constants
  set M := 1 / g_min
  set C_b := C / ε₀
  set T_min := max (2 * T₀) 1
  set C_vert := 2 * T₀ * M + 2 * C_b + 1

  refine ⟨C_vert, by positivity, T_min, le_max_right _ _, fun x hx T hT_min => ?_⟩
  have hT_pos : 0 < T := by linarith [le_max_right (2 * T₀) 1, hT_min]
  have hT_ge_T₀ : T₀ ≤ T := by linarith [le_max_left (2 * T₀) 1, hT_min]
  have hT_ge_1 : 1 ≤ T := le_trans (le_max_right _ _) hT_min
  have hx_pos : 0 < x := by linarith

  -- Define the integrand
  set f := fun t : ℝ => (x : ℂ) ^ (↑sigma0 + ↑t * I) /
      ((↑sigma0 + ↑t * I) * riemannZeta (↑sigma0 + ↑t * I))

  -- Integrability
  have hf_l := perron_vertical_integrable hRH x sigma0 hx_pos hsigma0 hsigma0_ne (-T) (-T₀)
  have hf_m := perron_vertical_integrable hRH x sigma0 hx_pos hsigma0 hsigma0_ne (-T₀) T₀
  have hf_r := perron_vertical_integrable hRH x sigma0 hx_pos hsigma0 hsigma0_ne T₀ T

  -- The three bounds
  have h1 : ‖∫ t in (-T₀)..T₀, f t‖ ≤ x ^ sigma0 * M * (2 * T₀) :=
    inner_integral_bound hx_pos hT₀_pos hg_min_pos hg_ge_min

  have h2 : ‖∫ t in T₀..T, f t‖ ≤ x ^ sigma0 * C / ε₀ * T ^ ε₀ :=
    right_outer_integral_bound hRH hx_pos hsigma0 hsigma0_ne
      hC_pos hε₀_pos hε₀_le_one h_half_ε₀ hT₀_pos hT_ge_T₀ hzeta_bound

  have h3 : ‖∫ t in (-T)..(-T₀), f t‖ ≤ x ^ sigma0 * C / ε₀ * T ^ ε₀ :=
    left_outer_integral_bound hRH hx_pos hsigma0 hsigma0_ne
      hC_pos hε₀_pos hε₀_le_one h_half_ε₀ hT₀_pos hT_ge_T₀ hzeta_bound

  -- Absorb 1/(2π), split, and combine
  have h_pfx : ‖(1 / (2 * ↑Real.pi)) * ∫ t in (-T)..T, f t‖ ≤ ‖∫ t in (-T)..T, f t‖ :=
    norm_one_div_two_pi_mul_le _
  have h_split : ∫ t in (-T)..T, f t =
      (∫ t in (-T)..(-T₀), f t) + (∫ t in (-T₀)..T₀, f t) + (∫ t in T₀..T, f t) := by
    have hf_lm : IntervalIntegrable f volume (-T) T₀ := hf_l.trans hf_m
    have s1 := (intervalIntegral.integral_add_adjacent_intervals hf_l hf_m).symm
    -- s1 : ∫ (-T)..T₀ = (∫ (-T)..(-T₀)) + ∫ (-T₀)..T₀
    have s2 := (intervalIntegral.integral_add_adjacent_intervals hf_lm hf_r).symm
    -- s2 : ∫ (-T)..T = (∫ (-T)..T₀) + ∫ T₀..T
    rw [s2, s1]
  -- Convert h2, h3 to C_b form
  have h2' : ‖∫ t in T₀..T, f t‖ ≤ x ^ sigma0 * C_b * T ^ ε₀ := by
    calc ‖∫ t in T₀..T, f t‖ ≤ x ^ sigma0 * C / ε₀ * T ^ ε₀ := h2
      _ = x ^ sigma0 * C_b * T ^ ε₀ := by ring
  have h3' : ‖∫ t in (-T)..(-T₀), f t‖ ≤ x ^ sigma0 * C_b * T ^ ε₀ := by
    calc ‖∫ t in (-T)..(-T₀), f t‖ ≤ x ^ sigma0 * C / ε₀ * T ^ ε₀ := h3
      _ = x ^ sigma0 * C_b * T ^ ε₀ := by ring
  -- Final: chain h_pfx → split → combined
  have h_final : ‖∫ t in (-T)..T, f t‖ ≤ C_vert * x ^ sigma0 * T ^ eps' := by
    have := three_part_combine hT_pos hT_ge_1 hε₀_le heps' hT₀_pos
      (by positivity : 0 < 1 / g_min) (by positivity : 0 < C / ε₀) hx_pos.le
      (∫ t in (-T)..(-T₀), f t) (∫ t in (-T₀)..T₀, f t) (∫ t in T₀..T, f t)
      h3' h1 h2'
    have h_eq : ‖∫ t in (-T)..T, f t‖ =
        ‖(∫ t in (-T)..(-T₀), f t) + (∫ t in (-T₀)..T₀, f t) + (∫ t in T₀..T, f t)‖ :=
      congr_arg _ h_split
    linarith
  exact le_trans h_pfx h_final

end Cathedral.Perron
