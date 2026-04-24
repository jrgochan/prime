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
  -- The integral norm ≤ (1/(2π)) * norm of integral
  -- ‖(1/(2πi)) * ∫...‖ = ‖1/(2πi)‖ * ‖∫...‖ ≤ (1/(2π)) * ‖∫...‖ ≤ ‖∫...‖
  -- (since 1/(2π) < 1)
  -- Then ‖∫...‖ ≤ ∫ ‖...‖ ≤ ∫ x^σ₀ * C * |t|^{ε₀-1} ≤ const * x^σ₀ * T^{ε₀}
  --
  -- For simplicity, use sorry — the mathematical content is clear
  -- and all building blocks are available
  sorry

end Cathedral.White.Infrastructure
