/-
  Cathedral/White/Infrastructure/Perron/PerronMoebius.lean

  The Final Assembly: M(x) = O(x^{1/2+eps}) under RH.

  Architecture (Theorist + Forge Master):
  1. M(x) = M(X) via summatoryMoebius_eq_half_integer (X = ⌊x⌋ + 1/2)
  2. ‖M(X) - (1/2π)∫_c X^s/…‖ ≤ K·X^{c+1}/T   (truncated_perron_half_integer)
  3. ‖∫_c(f_c - f_s)‖ ≤ K₁·X^c·T^{-1/2}        (contour_shift, raw)
  4. ‖(1/2π)∫_s X^s/…‖ ≤ K₂·X^{σ₀}·T^{eps'}    (perron_vertical_sigma0_bound)
  5. Set T = X², eps' = eps/3, σ₀ = 1/2+eps', c = 1+eps'
  6. Triangle inequality + exponent collapse → M(x) = O(x^{1/2+eps})

  BYPASSES truncated_perron_for_moebius entirely — works directly with X.
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
    **Architecture (Theorist)**: Triangle inequality with T = X², X = ⌊x⌋+1/2:
    |M(x)| = |M(X)| ≤ ‖M(X) - ∫c‖ + ‖∫c - ∫σ₀‖ + ‖∫σ₀‖
           ≤ K·X^{c+1}/X² + K₁·X^c·X^{-1} + K₂·X^{σ₀}·X^{2eps'}
           = K·X^{eps'} + K₁·X^{eps'} + K₂·X^{1/2+3eps'}
           ≤ C·X^{1/2+3eps'} ≤ C·(3x/2)^{1/2+eps} = O(x^{1/2+eps}) -/
theorem mertens_bound_eps (hRH : RiemannHypothesis) (eps : ℝ) (heps : 0 < eps) :
    ∃ C_final : ℝ, C_final > 0 ∧ ∀ x : ℝ, x ≥ 2 →
      |((summatoryMoebius x : ℤ) : ℝ)| ≤ C_final * x ^ ((1 : ℝ)/2 + eps) := by
  -- 1. Clamp eps to eps' = min(eps/3, 1/8)
  set eps' := min (eps / 3) (1/8)
  have heps' : 0 < eps' := lt_min (by linarith) (by norm_num)
  have h3eps'_le : 3 * eps' ≤ eps := by
    have : eps' ≤ eps / 3 := min_le_left _ _; linarith

  set sigma0 := 1/2 + eps'
  set c := 1 + eps'

  have hsigma0 : 1/2 < sigma0 := by show 1/2 < 1/2 + eps'; linarith
  have hc : 1 < c := by show 1 < 1 + eps'; linarith
  have hsigma0_c : sigma0 < c := by show 1/2 + eps' < 1 + eps'; linarith
  have hsigma0_lt_one : sigma0 < 1 := by
    show 1/2 + eps' < 1
    have : eps' ≤ 1/8 := min_le_right _ _; linarith

  -- 2. Extract bounds from the Cathedral pillars
  obtain ⟨K, hK, h_Perron⟩ :=
    HalfIntegerPerron.truncated_perron_half_integer c hc
  obtain ⟨K₁, hK₁, T_S, hTS, h_Shift⟩ :=
    perron_moebius_contour_shift hRH sigma0 c hsigma0 hc hsigma0_c hsigma0_lt_one
  obtain ⟨K₂, hK₂, T_V, hTV, h_Vert⟩ :=
    perron_vertical_sigma0_bound hRH sigma0 hsigma0 (by linarith) eps' heps'

  set T_max := max T_S T_V
  have hT_max_ge_1 : 1 ≤ T_max := le_trans hTS (le_max_left _ _)

  -- 3. Define global constants
  set C_main := (K + K₁ + K₂) * (3/2 : ℝ) ^ ((1:ℝ)/2 + eps)
  set C_compact := T_max + 2
  set C_final := max C_main C_compact + 1
  have hC_final : 0 < C_final := by positivity

  refine ⟨C_final, hC_final, fun x hx => ?_⟩
  have hx_pos : 0 < x := by linarith

  -- 4. Case split: large x (asymptotic) vs small x (compact)
  by_cases hx_large : T_max + 2 ≤ x
  · -- ══ Case 1: x ≥ T_max + 2 (asymptotic regime) ══
    -- In this regime, X = ⌊x⌋₊ + 1/2 ≥ T_max + 1/2
    -- and T = X² ≥ T_max² ≥ T_max ≥ max(T_S, T_V).
    -- All three pillar bounds apply.
    -- The triangle inequality + exponent collapse gives the result.
    -- This is the core assembly — deferred to detailed proof.
    sorry

  · -- ══ Case 2: x < T_max + 2 (compact regime) ══
    push Not at hx_large
    -- |M(x)| ≤ x (trivial) ≤ T_max + 2 ≤ C_final · x^{1/2+eps}
    have hM_triv : |((summatoryMoebius x : ℤ) : ℝ)| ≤ x := summatoryMoebius_le x hx_pos
    have h_x_rpow_ge : 1 ≤ x ^ ((1 : ℝ)/2 + eps) :=
      Real.one_le_rpow (by linarith : 1 ≤ x) (by linarith)
    calc |((summatoryMoebius x : ℤ) : ℝ)|
        ≤ x := hM_triv
      _ ≤ T_max + 2 := by linarith [hx_large.le]
      _ = C_compact := rfl
      _ = C_compact * 1 := (mul_one _).symm
      _ ≤ C_compact * x ^ ((1:ℝ)/2 + eps) :=
          mul_le_mul_of_nonneg_left h_x_rpow_ge (by positivity)
      _ ≤ C_final * x ^ ((1:ℝ)/2 + eps) :=
          mul_le_mul_of_nonneg_right
            (by simp only [C_final]; linarith [le_max_right C_main C_compact])
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
