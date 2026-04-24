/-
  Cathedral/White/Infrastructure/Perron/PerronMoebius.lean

  The Final Assembly: M(x) = O(x^{1/2+eps}) under RH.

  This file contains only the final theorems:
  - mertens_bound_eps: RH implies M(x) = O(x^{1/2+eps})
  - mertens_bound_eps_implies_original: O(x^{1/2+eps}) implies O(x^{3/4}) (PROVED)

  All infrastructure is in:
  - ContourShift.lean: Cauchy-Goursat + contour shift theorem
  - DirichletPoly.lean: sum-swap, tail bounds (zero sorry)
  - AssemblyHelpers.lean: truncated Perron formula + vertical bound
-/

import Cathedral.White.Infrastructure.Perron.AssemblyHelpers
import Cathedral.White.Infrastructure.Perron.ContourShift

noncomputable section
open Complex Real MeasureTheory Set Filter ArithmeticFunction
open scoped LSeries.notation ArithmeticFunction.Moebius ArithmeticFunction.zeta Topology

namespace Cathedral.White.Infrastructure

-- ═══════════════════════════════════════════
-- The Final Assembly: M(x) = O(x^{1/2+eps})
-- ═══════════════════════════════════════════

/-- Under RH, M(x) = O(x^{1/2+eps}) for any eps > 0.
    **Architecture (Theorist)**: Triangle inequality with T = x:
    |M(x)| ≤ ‖M(x) - ∫c‖ + ‖∫c - ∫σ₀‖ + ‖∫σ₀‖
           ≤ K·x^c/x + K₁·x^c·x^{-1/2} + K₂·x^{σ₀}·x^{eps'/2}
           = K·x^{eps'} + K₁·x^{1/2+eps'} + K₂·x^{1/2+eps'}
           = O(x^{1/2+eps'})  ≤  O(x^{1/2+eps}) -/
theorem mertens_bound_eps (hRH : RiemannHypothesis) (eps : ℝ) (heps : 0 < eps) :
    ∃ C_final : ℝ, C_final > 0 ∧ ∀ x : ℝ, x ≥ 2 →
      |((summatoryMoebius x : ℤ) : ℝ)| ≤ C_final * x ^ ((1 : ℝ)/2 + eps) := by
  -- 1. Choose eps' = min(2eps/3, 1/3) so that with T = x²:
  --    sigma0 + eps' = 1/2 + 3eps'/2 ≤ 1/2 + eps
  set eps' := min (2 * eps / 3) (1/3)
  have heps' : 0 < eps' := lt_min (by linarith) (by norm_num)
  have heps'_le_eps : 3 * eps' / 2 ≤ eps := by
    have h1 : eps' ≤ 2 * eps / 3 := min_le_left _ _
    linarith

  set sigma0 := 1/2 + eps'/2
  set c := 1 + eps'

  have hsigma0 : 1/2 < sigma0 := by show 1/2 < 1/2 + eps'/2; linarith
  have hc : 1 < c := by show 1 < 1 + eps'; linarith
  have hsigma0_c : sigma0 < c := by show 1/2 + eps'/2 < 1 + eps'; linarith
  have hsigma0_lt_one : sigma0 < 1 := by
    show 1/2 + eps'/2 < 1
    have : eps' ≤ 1/3 := min_le_right _ _; linarith

  -- 2. Extract the three fundamental bounds (quantified completely independent of x!)
  obtain ⟨K, hK, h_Perron⟩ := truncated_perron_for_moebius c hc
  obtain ⟨K₁, hK₁, T_S, hTS, h_Shift⟩ :=
    perron_moebius_contour_shift hRH sigma0 c hsigma0 hc hsigma0_c hsigma0_lt_one
  obtain ⟨K₂, hK₂, T_V, hTV, h_Vert⟩ :=
    perron_vertical_sigma0_bound hRH sigma0 hsigma0 (by linarith) (eps'/2) (by positivity)

  set T_max := max T_S T_V
  have hT_max_ge_1 : 1 ≤ T_max := le_trans hTS (le_max_left _ _)

  -- 3. Define the global constant C_final
  set C_main := K + K₁ + K₂
  set C_compact := T_max / (2 ^ ((1 : ℝ)/2 + eps))
  set C_final := max C_main C_compact + 1
  have hC_final : 0 < C_final := by positivity

  refine ⟨C_final, hC_final, fun x hx => ?_⟩
  have hx_pos : 0 < x := by linarith
  have hx_gt_1 : 1 < x := by linarith

  have h_eps_ineq : x ^ ((1 : ℝ)/2 + 3 * eps' / 2) ≤ x ^ ((1 : ℝ)/2 + eps) :=
    rpow_le_rpow_of_exponent_le hx_gt_1.le (by linarith [heps'_le_eps])

  -- 4. Split behavior based on whether x is large enough for the asymptotic bounds
  by_cases hx_large : T_max ≤ x
  · -- Case 1: x ≥ T_max. We set T = x².
    set T := x ^ (2 : ℝ)
    have hT_ge_1 : 1 ≤ T := Real.one_le_rpow (by linarith : 1 ≤ x) (by norm_num : (0:ℝ) ≤ 2)
    have hT_max_le : T_max ≤ T := by
      calc T_max ≤ x := hx_large
        _ = x ^ (1 : ℝ) := (Real.rpow_one x).symm
        _ ≤ x ^ (2 : ℝ) := rpow_le_rpow_of_exponent_le (by linarith : 1 ≤ x) (by norm_num)
    set I_c := (1 / (2 * ↑Real.pi)) *
      ∫ t in (-T)..T, (x : ℂ) ^ (↑c + ↑t * I) /
        ((↑c + ↑t * I) * riemannZeta (↑c + ↑t * I))
    set I_s := (1 / (2 * ↑Real.pi)) *
      ∫ t in (-T)..T, (x : ℂ) ^ (↑sigma0 + ↑t * I) /
        ((↑sigma0 + ↑t * I) * riemannZeta (↑sigma0 + ↑t * I))

    have h1 := h_Perron x hx T hT_ge_1
    have h2 := h_Shift x hx_gt_1 T (le_trans (le_max_left _ _) hT_max_le)
    have h3 := h_Vert x hx T (le_trans (le_max_right _ _) hT_max_le)

    have h_tri1 : ‖(↑(summatoryMoebius x : ℤ) : ℂ)‖ ≤
        ‖(↑(summatoryMoebius x : ℤ) : ℂ) - I_c‖ + ‖I_c - I_s‖ + ‖I_s‖ := by
      calc ‖(↑(summatoryMoebius x : ℤ) : ℂ)‖
        = ‖((↑(summatoryMoebius x : ℤ) : ℂ) - I_c) + (I_c - I_s) + I_s‖ := by congr 1; ring
        _ ≤ ‖((↑(summatoryMoebius x : ℤ) : ℂ) - I_c) + (I_c - I_s)‖ + ‖I_s‖ := norm_add_le _ _
        _ ≤ ‖(↑(summatoryMoebius x) : ℂ) - I_c‖ + ‖I_c - I_s‖ + ‖I_s‖ := by
          gcongr; exact norm_add_le _ _

    have h_real_norm : |((summatoryMoebius x : ℤ) : ℝ)| =
        ‖((↑(summatoryMoebius x : ℤ) : ℝ) : ℂ)‖ := by
      rw [Complex.norm_real, Real.norm_eq_abs]

    -- Algebraic exponent simplifications (with T = x²)
    -- h1: K * x^{c+1} / x² = K * x^{c-1} = K * x^{eps'}
    have h1_eval : K * x ^ (c + 1) / T = K * x ^ eps' := by
      simp only [T]
      rw [mul_div_assoc, ← Real.rpow_sub hx_pos]
      congr 1; simp only [c]; ring

    -- h2: K₁ * x^c * T^{-1/2} = K₁ * x^c * x^{-1} = K₁ * x^{eps'}
    have h2_eval : K₁ * x ^ c * T ^ (-((1 : ℝ)/2)) = K₁ * x ^ eps' := by
      simp only [T]
      rw [show (x ^ (2:ℝ)) ^ (-((1:ℝ)/2)) = x ^ (-(1 : ℝ)) from by
        rw [← Real.rpow_mul hx_pos.le]; norm_num]
      rw [mul_assoc, ← rpow_add hx_pos]
      congr 1; simp only [c]; ring

    -- h3: K₂ * x^{σ₀} * T^{eps'/2} = K₂ * x^{σ₀+eps'} = K₂ * x^{1/2+3eps'/2}
    have h3_eval : K₂ * x ^ sigma0 * T ^ (eps' / 2) = K₂ * x ^ ((1 : ℝ)/2 + 3 * eps' / 2) := by
      simp only [T]
      rw [show (x ^ (2:ℝ)) ^ (eps' / 2) = x ^ eps' from by
        rw [← Real.rpow_mul hx_pos.le]; ring_nf]
      rw [mul_assoc, ← rpow_add hx_pos]
      congr 1; simp only [sigma0]; ring

    set_option maxHeartbeats 800000 in
    have h_bound_eps' : |((summatoryMoebius x : ℤ) : ℝ)| ≤
        C_main * x ^ ((1 : ℝ)/2 + 3 * eps' / 2) := by
      -- Shift bound: ‖I_c - I_s‖ ≤ K₁ * x^c * T^{-1/2}
      have h_shift_bound : ‖I_c - I_s‖ ≤ K₁ * x ^ c * T ^ (-((1 : ℝ)/2)) := by
        -- I_c - I_s = (1/(2π)) * (∫f_c - ∫f_s)
        -- Since ‖1/(2π)‖ ≤ 1, ‖I_c - I_s‖ ≤ ‖∫(f_c - f_s)‖ ≤ K₁ bound
        -- Proof structure identical to previous; integral limits are (-T)..T
        have h_eq : I_c - I_s = (1 / (2 * ↑Real.pi)) *
            ((∫ t in (-T)..T, (x : ℂ) ^ (↑c + ↑t * I) /
                ((↑c + ↑t * I) * riemannZeta (↑c + ↑t * I))) -
             (∫ t in (-T)..T, (x : ℂ) ^ (↑sigma0 + ↑t * I) /
                ((↑sigma0 + ↑t * I) * riemannZeta (↑sigma0 + ↑t * I)))) := by
          simp only [I_c, I_s]; ring
        -- Integrability on [-T, T]
        have h_vert_cont : ∀ (σ : ℝ), σ ≠ 1 → (1/2 < σ) →
            ContinuousOn (fun t : ℝ => (x : ℂ) ^ (↑σ + ↑t * I) /
              ((↑σ + ↑t * I) * riemannZeta (↑σ + ↑t * I)))
              (Set.uIcc (-T) T) := by
          intro σ hσ hσ_half
          have hs_ne_one : ∀ t : ℝ, (↑σ + ↑t * I : ℂ) ≠ 1 := by
            intro t h; apply hσ
            have := congr_arg Complex.re h
            simp [Complex.add_re, Complex.ofReal_re, Complex.mul_re,
              Complex.I_re, Complex.I_im] at this; exact this
          apply ContinuousOn.div
          · exact ContinuousOn.cpow continuousOn_const (by fun_prop)
              (fun _ _ => Complex.ofReal_mem_slitPlane.mpr (by linarith))
          · apply ContinuousOn.mul (by fun_prop)
            exact (fun t _ => ContinuousAt.continuousWithinAt <|
              ContinuousAt.comp (differentiableAt_riemannZeta (hs_ne_one t)).continuousAt
                (by fun_prop : ContinuousAt (fun t : ℝ => (↑σ + ↑t * I : ℂ)) t))
          · intro t _ h; apply absurd h; apply mul_ne_zero
            · intro h0; have := congr_arg Complex.re h0; simp at this; linarith
            · exact rh_zeta_ne_zero hRH (by simp; linarith) (hs_ne_one t)
        have h_int_fc : IntervalIntegrable
            (fun t => (x : ℂ) ^ (↑c + ↑t * I) / ((↑c + ↑t * I) * riemannZeta (↑c + ↑t * I)))
            volume (-T) T :=
          (h_vert_cont c (by linarith) (by linarith)).intervalIntegrable
        have h_int_fs : IntervalIntegrable
            (fun t => (x : ℂ) ^ (↑sigma0 + ↑t * I) / ((↑sigma0 + ↑t * I) * riemannZeta (↑sigma0 + ↑t * I)))
            volume (-T) T :=
          (h_vert_cont sigma0 (by linarith) hsigma0).intervalIntegrable
        show ‖I_c - I_s‖ ≤ K₁ * x ^ c * T ^ (-((1 : ℝ)/2))
        have h_ic_is : I_c - I_s = (1 / (2 * ↑Real.pi) : ℂ) *
            ∫ t in (-T)..T,
              ((x : ℂ) ^ (↑c + ↑t * I) / ((↑c + ↑t * I) * riemannZeta (↑c + ↑t * I)) -
               (x : ℂ) ^ (↑sigma0 + ↑t * I) / ((↑sigma0 + ↑t * I) *
                riemannZeta (↑sigma0 + ↑t * I))) := by
          simp only [I_c, I_s]
          rw [← mul_sub, intervalIntegral.integral_sub h_int_fc h_int_fs]
        rw [h_ic_is, norm_mul]
        have h_norm_pfx : ‖(1 / (2 * ↑Real.pi) : ℂ)‖ ≤ 1 := by
          rw [norm_div, norm_one, norm_mul, Complex.norm_ofNat]
          rw [show ‖(↑Real.pi : ℂ)‖ = Real.pi from by
            rw [Complex.norm_real]; exact abs_of_pos Real.pi_pos]
          rw [div_le_one (by positivity : (0:ℝ) < 2 * Real.pi)]
          linarith [Real.pi_gt_three]
        exact le_trans (mul_le_of_le_one_left (norm_nonneg _) h_norm_pfx) h2

      -- Cast path: |((M : ℤ) : ℝ)| = ‖((M : ℤ) : ℂ)‖
      rw [h_real_norm]
      have hcast : ‖((↑(summatoryMoebius x : ℤ) : ℝ) : ℂ)‖ =
          ‖(↑(summatoryMoebius x : ℤ) : ℂ)‖ := by
        congr 1
      rw [hcast]

      -- Triangle inequality → raw bounds → exponent simplification
      have h_raw : ‖(↑(summatoryMoebius x : ℤ) : ℂ)‖ ≤
          K * x ^ (c + 1) / T + K₁ * x ^ c * T ^ (-((1 : ℝ)/2)) +
          K₂ * x ^ sigma0 * T ^ (eps' / 2) :=
        le_trans h_tri1 (by gcongr)
      rw [h1_eval, h2_eval, h3_eval] at h_raw
      -- All three terms now: K·x^{eps'} + K₁·x^{eps'} + K₂·x^{1/2+3eps'/2}
      -- Upgrade eps' to 1/2+3eps'/2 via monotonicity
      have hx_eps_le : x ^ eps' ≤ x ^ ((1 : ℝ)/2 + 3 * eps' / 2) :=
        rpow_le_rpow_of_exponent_le hx_gt_1.le (by linarith)
      linarith [mul_le_mul_of_nonneg_left hx_eps_le hK.le,
               mul_le_mul_of_nonneg_left hx_eps_le hK₁.le]

    -- Upgrade to target eps and C_final
    calc |((summatoryMoebius x : ℤ) : ℝ)|
        ≤ C_main * x ^ ((1 : ℝ)/2 + 3 * eps' / 2) := h_bound_eps'
      _ ≤ C_final * x ^ ((1 : ℝ)/2 + 3 * eps' / 2) :=
        mul_le_mul_of_nonneg_right (by simp only [C_final]; linarith [le_max_left C_main C_compact])
          (rpow_nonneg hx_pos.le _)
      _ ≤ C_final * x ^ ((1 : ℝ)/2 + eps) :=
        mul_le_mul_of_nonneg_left h_eps_ineq hC_final.le

  · -- Case 2: x < T_max. M(x) is bounded trivially by x.
    have hM_triv : |((summatoryMoebius x : ℤ) : ℝ)| ≤ x := summatoryMoebius_le x hx_pos
    have h_x_bound : x ≤ T_max := (not_le.mp hx_large).le
    have h_x_rpow_ge_2 : 2 ^ ((1 : ℝ)/2 + eps) ≤ x ^ ((1 : ℝ)/2 + eps) :=
      rpow_le_rpow (by linarith) hx (by linarith)

    have h_compact_bound : x ≤ C_compact * x ^ ((1 : ℝ)/2 + eps) := by
      calc x ≤ T_max := h_x_bound
        _ = (T_max / 2 ^ ((1 : ℝ)/2 + eps)) * 2 ^ ((1 : ℝ)/2 + eps) := by
            have : (0 : ℝ) < 2 ^ ((1 : ℝ)/2 + eps) := rpow_pos_of_pos (by linarith) _
            exact (div_mul_cancel₀ T_max (ne_of_gt this)).symm
        _ ≤ C_compact * x ^ ((1 : ℝ)/2 + eps) :=
          mul_le_mul_of_nonneg_left h_x_rpow_ge_2 (by positivity)

    calc |((summatoryMoebius x : ℤ) : ℝ)|
        ≤ x := hM_triv
      _ ≤ C_compact * x ^ ((1 : ℝ)/2 + eps) := h_compact_bound
      _ ≤ C_final * x ^ ((1 : ℝ)/2 + eps) :=
        mul_le_mul_of_nonneg_right (by simp only [C_final]; linarith [le_max_right C_main C_compact])
          (rpow_nonneg hx_pos.le _)

-- ═══════════════════════════════════════════
-- From eps to the original form (PROVED)
-- ═══════════════════════════════════════════

/-- **PROVED**: The eps-version implies the 3/4-power version.
    Specializes eps = 1/4: |M(x)| <= C x^{3/4}. -/
theorem mertens_bound_eps_implies_original
    (hmert : ∀ eps : ℝ, eps > 0 → ∃ C : ℝ, C > 0 ∧ ∀ x : ℝ, x ≥ 2 →
      |((summatoryMoebius x : ℤ) : ℝ)| ≤ C * x ^ ((1 : ℝ)/2 + eps)) :
    ∃ C : ℝ, C > 0 ∧ ∀ x : ℝ, x ≥ 2 →
      |((summatoryMoebius x : ℤ) : ℝ)| ≤ C * x ^ ((3 : ℝ)/4) := by
  obtain ⟨C, hC_pos, hM⟩ := hmert (1/4 : ℝ) (by norm_num)
  exact ⟨C, hC_pos, fun x hx => by convert hM x hx using 2; norm_num⟩

-- NOTE: The bridge between summatoryMoebius (DirichletZetaInverse.lean)
-- and mertensFunction (MertensBound.lean) is handled in the
-- assembly file MertensFromPerron.lean.

end Cathedral.White.Infrastructure
