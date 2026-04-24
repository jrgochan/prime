/-
  Cathedral/White/Infrastructure/Perron/AssemblyHelpers.lean

  Assembly helpers for the Mertens bound: truncated Perron formula
  and vertical contour bound on the σ₀ line.

  Both lemmas currently have sorry — they're the assembly interface
  between DirichletPoly and ContourShift.
-/

import Cathedral.White.Infrastructure.Perron.DirichletPoly
import Cathedral.White.Infrastructure.Perron.ContourShift
import Cathedral.White.Infrastructure.ZetaConvexity

noncomputable section
open Complex Real MeasureTheory Set Filter ArithmeticFunction
open scoped LSeries.notation ArithmeticFunction.Moebius ArithmeticFunction.zeta Topology

namespace Cathedral.White.Infrastructure

-- ═══════════════════════════════════════════
-- Assembly Helpers
-- ═══════════════════════════════════════════

/-- The Truncated Perron Formula for M(x): connects M(x) to the contour integral.
    Uses the classical Perron formula for individual terms + finite sum swap. -/
theorem truncated_perron_for_moebius (c : ℝ) (hc : 1 < c) :
    ∃ K > 0, ∀ x : ℝ, 2 ≤ x → ∀ T : ℝ, 1 ≤ T →
      ‖(↑(summatoryMoebius x : ℤ) : ℂ) -
        (1 / (2 * ↑Real.pi * I)) *
          ∫ t in (-T)..T,
            (x : ℂ) ^ (↑c + ↑t * I) /
              ((↑c + ↑t * I) * riemannZeta (↑c + ↑t * I))‖ ≤
      K * x ^ c / T := by
  -- Strategy (Theorist): finite sum bypass + moebius_partial_sum_approx
  -- + perron kernel bounds. Requires classical Perron formula for each term.
  sorry

/-- Bounding the vertical contour on the σ₀ line using the Lindelöf bound. -/
lemma perron_vertical_sigma0_bound (hRH : RiemannHypothesis)
    (sigma0 : ℝ) (hsigma0 : 1/2 < sigma0) (eps' : ℝ) (heps' : 0 < eps') :
    ∃ C_vert > 0, ∃ T_min ≥ (1 : ℝ), ∀ x : ℝ, x ≥ 2 → ∀ T : ℝ, T_min ≤ T →
      ‖(1 / (2 * ↑Real.pi * I)) * ∫ t in (-T)..T,
        (x : ℂ) ^ (↑sigma0 + ↑t * I) /
        ((↑sigma0 + ↑t * I) * riemannZeta (↑sigma0 + ↑t * I))‖ ≤
      C_vert * x ^ sigma0 * T ^ eps' := by
  -- Strategy: pointwise bound from inv_zeta_bound_under_rh, integrate, absorb 1/(2πi)
  -- Choose ε₀ = min(eps', sigma0 - 1/2) so that 1/2 + ε₀ ≤ sigma0
  set ε₀ := min eps' (sigma0 - 1/2) / 2 with hε₀_def
  have hε₀_pos : 0 < ε₀ := by
    simp only [ε₀]; exact div_pos (lt_min heps' (by linarith)) (by norm_num)
  have hε₀_le_eps' : ε₀ ≤ eps' := by
    calc ε₀ = min eps' (sigma0 - 1/2) / 2 := rfl
      _ ≤ eps' / 2 := by gcongr; exact min_le_left _ _
      _ ≤ eps' := by linarith
  have h_half_ε₀ : 1/2 + ε₀ ≤ sigma0 := by
    have : ε₀ ≤ (sigma0 - 1/2) / 2 := by
      calc ε₀ = min eps' (sigma0 - 1/2) / 2 := rfl
        _ ≤ (sigma0 - 1/2) / 2 := by gcongr; exact min_le_right _ _
    linarith
  -- Get the Lindelöf bound
  obtain ⟨C, hC_pos, T₀, hT₀_pos, hzeta_bound⟩ := inv_zeta_bound_under_rh hRH ε₀ hε₀_pos
  -- Set constants
  set T_min := max T₀ 1
  set C_vert := C / ε₀ + 1
  have hC_vert_pos : 0 < C_vert := by positivity
  refine ⟨C_vert, hC_vert_pos, T_min, le_max_right _ _, fun x hx T hT_min => ?_⟩
  have hT_pos : 0 < T := by linarith [le_max_right T₀ 1, hT_min]
  have hT_ge_T₀ : T₀ ≤ T := le_trans (le_max_left _ _) hT_min
  have hT_ge_1 : 1 ≤ T := le_trans (le_max_right _ _) hT_min
  have hx_pos : 0 < x := by linarith
  -- Factor out the 1/(2πi) prefactor: ‖a*∫...‖ ≤ ‖∫...‖
  calc ‖(1 / (2 * ↑Real.pi * I)) * ∫ t in (-T)..T,
        (x : ℂ) ^ (↑sigma0 + ↑t * I) /
        ((↑sigma0 + ↑t * I) * riemannZeta (↑sigma0 + ↑t * I))‖
      ≤ ‖∫ t in (-T)..T,
          (x : ℂ) ^ (↑sigma0 + ↑t * I) /
          ((↑sigma0 + ↑t * I) * riemannZeta (↑sigma0 + ↑t * I))‖ := by
        rw [norm_mul]
        calc ‖(1 : ℂ) / (2 * ↑Real.pi * I)‖ * _ ≤ 1 * _ := by
              gcongr
              rw [norm_div, norm_one, norm_mul, norm_mul, Complex.norm_two,
                Complex.norm_I, mul_one]
              rw [show ‖(↑Real.pi : ℂ)‖ = Real.pi from by
                rw [Complex.norm_real]; exact abs_of_pos Real.pi_pos]
              rw [div_le_one (by positivity : (0:ℝ) < 2 * Real.pi)]
              linarith [Real.pi_gt_three]
          _ = _ := one_mul _
    _ ≤ C_vert * x ^ sigma0 * T ^ eps' := by
        -- Use the crude uniform bound: ‖integrand‖ ≤ x^σ₀ · M for some M.
        -- Specifically, ‖x^s‖ = x^σ₀, ‖1/s‖ ≤ 1/σ₀, and ‖1/ζ(s)‖ is bounded on the
        -- compact set {σ₀+tI : |t| ≤ T} (since ζ has no zeros with Re > 1/2 under RH).
        --
        -- Bound: ‖integrand‖ ≤ x^σ₀/(σ₀ · min_{|t|≤T} ‖ζ(σ₀+tI)‖)
        -- The minimum exists by compactness and is > 0 under RH.
        -- Then ‖∫‖ ≤ 2T · x^σ₀/(σ₀ · min|ζ|).
        --
        -- For the exponent: 2T = 2·T^1 vs C_vert·T^{eps'}.
        -- We need T^1 ≤ const·T^{eps'}, i.e., T^{1-eps'} ≤ const.
        -- This DOESN'T hold for growing T.
        --
        -- The correct proof requires splitting around t=0 and using the
        -- Lindelöf bound for |t| ≥ T₀. The integral of |t|^{ε₀-1} on [1,T]
        -- equals T^{ε₀}/ε₀, giving the O(T^{ε₀}) ≤ O(T^{eps'}) bound.
        -- This requires:
        -- 1. ContinuousOn of the integrand on [-T,T] (for integrability)
        -- 2. Splitting ∫_{-T}^T = ∫_{-T}^{-T₀} + ∫_{-T₀}^{T₀} + ∫_{T₀}^T
        -- 3. Compact bound on [-T₀,T₀], Lindelöf bound on the outer parts
        -- 4. integral_rpow for ∫₁^T t^{ε₀-1} dt = T^{ε₀}/ε₀
        -- All building blocks are available in Mathlib.
        sorry

end Cathedral.White.Infrastructure
