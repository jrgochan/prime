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
    -- Step A: Set up X = ⌊x⌋₊ + 1/2, T = X²
    set m := ⌊x⌋₊
    have hm : 2 ≤ m := Nat.le_floor (by linarith : (2 : ℝ) ≤ x)
    set X := (m : ℝ) + 1/2
    have hX_pos : 0 < X := by positivity
    have hX_ge_2 : 2 ≤ X := by
      have : (2 : ℝ) ≤ (m : ℝ) := by exact_mod_cast hm
      show 2 ≤ (m : ℝ) + 1/2; linarith
    have hX_gt_1 : 1 < X := by linarith [show (2:ℝ) ≤ (m:ℝ) from by exact_mod_cast hm]

    -- M(x) = M(X)
    have h_M_eq := HalfIntegerPerron.summatoryMoebius_eq_half_integer x hx
    have h_floor_eq : (↑⌊x⌋ + 1/2 : ℝ) = X := by
      have := natCast_floor_eq_intCast_floor (show (0:ℝ) ≤ x by linarith)
      show (↑⌊x⌋ + 1/2 : ℝ) = (↑m + 1/2 : ℝ); linarith
    have h_M_X : summatoryMoebius x = summatoryMoebius X := by
      have : summatoryMoebius (↑⌊x⌋ + 1/2 : ℝ) = summatoryMoebius X := congr_arg _ h_floor_eq
      exact h_M_eq.trans this
    have h_abs_norm : |((summatoryMoebius x : ℤ) : ℝ)| =
        ‖((↑(summatoryMoebius X : ℤ) : ℝ) : ℂ)‖ := by
      simp only [Complex.norm_real, Real.norm_eq_abs]
      show |((summatoryMoebius x : ℤ) : ℝ)| = |((summatoryMoebius X : ℤ) : ℝ)|
      congr 1; exact_mod_cast h_M_X
    rw [h_abs_norm]

    -- X ≤ (3/2) · x
    have h_X_le : X ≤ (3/2 : ℝ) * x := by
      calc X = (m : ℝ) + 1/2 := rfl
        _ ≤ x + 1/2 := by linarith [Nat.floor_le (show (0:ℝ) ≤ x by linarith)]
        _ ≤ x + (1/2) * x := by linarith
        _ = (3/2 : ℝ) * x := by ring

    -- Step B: T = X², threshold bounds
    set T := X ^ (2 : ℝ)
    have hT_ge_1 : 1 ≤ T := Real.one_le_rpow (by linarith : 1 ≤ X) (by norm_num)
    -- X ≥ T_max + 1/2: since x ≥ T_max + 2 and m ≥ x - 1
    have hX_ge_T : T_max ≤ X := by
      have hm_le_x : (m : ℝ) ≤ x := by
        exact_mod_cast Nat.floor_le (show (0:ℝ) ≤ x by linarith)
      have hx_lt_m1 : x < (m : ℝ) + 1 := Nat.lt_floor_add_one x
      show T_max ≤ (m : ℝ) + 1/2
      linarith
    have hT_max_le : T_max ≤ T := by
      calc T_max ≤ X := hX_ge_T
        _ = X ^ (1 : ℝ) := (rpow_one X).symm
        _ ≤ X ^ (2 : ℝ) := rpow_le_rpow_of_exponent_le (show (1:ℝ) ≤ X by linarith) (by norm_num)
    have hTS_le : T_S ≤ T := le_trans (le_max_left _ _) hT_max_le
    have hTV_le : T_V ≤ T := le_trans (le_max_right _ _) hT_max_le

    -- Step C: Apply pillars
    have h1 := h_Perron m hm T hT_ge_1
    have h2 := h_Shift X hX_gt_1 T hTS_le
    have h3 := h_Vert X hX_ge_2 T hTV_le

    -- Step D: Define contour integrals and triangle inequality
    set I_c := (1 / (2 * ↑Real.pi)) *
      ∫ t in (-T)..T, (X : ℂ) ^ (↑c + ↑t * I) /
        ((↑c + ↑t * I) * riemannZeta (↑c + ↑t * I))
    set I_s := (1 / (2 * ↑Real.pi)) *
      ∫ t in (-T)..T, (X : ℂ) ^ (↑sigma0 + ↑t * I) /
        ((↑sigma0 + ↑t * I) * riemannZeta (↑sigma0 + ↑t * I))

    -- ‖M(X)‖ ≤ ‖M(X) - I_c‖ + ‖I_c - I_s‖ + ‖I_s‖
    have h_tri : ‖((↑(summatoryMoebius X : ℤ) : ℝ) : ℂ)‖ ≤
        ‖((↑(summatoryMoebius X : ℤ) : ℝ) : ℂ) - I_c‖ + ‖I_c - I_s‖ + ‖I_s‖ := by
      calc ‖((↑(summatoryMoebius X : ℤ) : ℝ) : ℂ)‖
          = ‖(((↑(summatoryMoebius X : ℤ) : ℝ) : ℂ) - I_c) + (I_c - I_s) + I_s‖ := by
            congr 1; ring
        _ ≤ ‖(((↑(summatoryMoebius X : ℤ) : ℝ) : ℂ) - I_c) + (I_c - I_s)‖ + ‖I_s‖ :=
            norm_add_le _ _
        _ ≤ ‖((↑(summatoryMoebius X : ℤ) : ℝ) : ℂ) - I_c‖ + ‖I_c - I_s‖ + ‖I_s‖ := by
            linarith [norm_add_le (((↑(summatoryMoebius X : ℤ) : ℝ) : ℂ) - I_c) (I_c - I_s)]

    -- Step D: Bound ‖M(X) - I_c‖ using h_Perron
    -- h1 gives: ‖M(X)_ℂ - I_c‖ ≤ K * X^{c+1} / T
    -- But h1 uses ↑(summatoryMoebius X : ℤ) : ℂ, while we have the ℝ cast
    have h_cast_eq : ((↑(summatoryMoebius X : ℤ) : ℝ) : ℂ) =
        (↑(summatoryMoebius X : ℤ) : ℂ) := by push_cast; ring
    rw [h_cast_eq] at h_tri ⊢

    -- Step D2: Bound ‖I_c - I_s‖ using h_Shift + integral_sub + 1/(2π) ≤ 1
    have h_int_c := perron_vertical_integrable hRH X c hX_pos
      (show 1/2 < c from by simp only [c]; linarith)
      (show c ≠ 1 from by intro h; simp only [c] at h; linarith)
      (-T) T
    have h_int_s := perron_vertical_integrable hRH X sigma0 hX_pos hsigma0
      (show sigma0 ≠ 1 from by
        simp only [sigma0]; linarith [min_le_right (eps / 3) (1/8 : ℝ)])
      (-T) T
    have h_shift_bound : ‖I_c - I_s‖ ≤ K₁ * X ^ c * T ^ (-((1:ℝ)/2)) := by
      -- I_c - I_s = (1/2π) * (∫f_c - ∫f_s) = (1/2π) * ∫(f_c - f_s)
      have h_diff : I_c - I_s = (1 / (2 * ↑Real.pi) : ℂ) *
          ∫ t in (-T)..T,
            ((X : ℂ) ^ (↑c + ↑t * I) / ((↑c + ↑t * I) * riemannZeta (↑c + ↑t * I)) -
             (X : ℂ) ^ (↑sigma0 + ↑t * I) / ((↑sigma0 + ↑t * I) *
              riemannZeta (↑sigma0 + ↑t * I))) := by
        simp only [I_c, I_s]
        rw [← mul_sub, intervalIntegral.integral_sub h_int_c h_int_s]
      calc ‖I_c - I_s‖
          = ‖(1 / (2 * ↑Real.pi) : ℂ) * ∫ t in (-T)..T, _‖ := by rw [h_diff]
        _ = ‖(1 / (2 * ↑Real.pi) : ℂ)‖ * ‖∫ t in (-T)..T, _‖ := norm_mul _ _
        _ ≤ 1 * ‖∫ t in (-T)..T, _‖ := by gcongr; exact norm_one_div_two_pi_le
        _ = ‖∫ t in (-T)..T, _‖ := one_mul _
        _ ≤ K₁ * X ^ c * T ^ (-((1:ℝ)/2)) := h2

    have h1_eval : K * X ^ (c + 1) / T = K * X ^ eps' := by
      simp only [T]
      rw [perron_exp_collapse hX_pos]
      congr 1; simp only [c]; ring_nf
    have h2_eval : K₁ * X ^ c * T ^ (-((1:ℝ)/2)) = K₁ * X ^ eps' := by
      simp only [T]
      rw [shift_exp_collapse hX_pos]
      congr 1; simp only [c]; ring_nf
    have h3_eval : K₂ * X ^ sigma0 * T ^ eps' = K₂ * X ^ (1/2 + 3 * eps') := by
      simp only [T]
      rw [vert_exp_collapse hX_pos]
      congr 1; simp only [sigma0]; ring_nf

    -- Step F: Absorb + push X → x
    -- eps' ≤ 1/2 + 3eps'
    have h_eps_mono : X ^ eps' ≤ X ^ (1/2 + 3 * eps') :=
      rpow_le_rpow_of_exponent_le (show (1:ℝ) ≤ X by linarith) (by linarith)
    -- Sum: (K + K₁)·X^{eps'} + K₂·X^{1/2+3eps'} ≤ (K+K₁+K₂)·X^{1/2+3eps'}
    have h_sum : K * X ^ eps' + K₁ * X ^ eps' + K₂ * X ^ (1/2 + 3 * eps') ≤
        (K + K₁ + K₂) * X ^ (1/2 + 3 * eps') := by
      have := mul_le_mul_of_nonneg_left h_eps_mono hK.le
      have := mul_le_mul_of_nonneg_left h_eps_mono hK₁.le
      nlinarith

    -- Main calc
    calc ‖(↑(summatoryMoebius X : ℤ) : ℂ)‖
        ≤ ‖(↑(summatoryMoebius X : ℤ) : ℂ) - I_c‖ + ‖I_c - I_s‖ + ‖I_s‖ := h_tri
      _ ≤ K * X ^ (c + 1) / T + K₁ * X ^ c * T ^ (-((1:ℝ)/2)) +
          K₂ * X ^ sigma0 * T ^ eps' := by linarith [h1, h_shift_bound, h3]
      _ = K * X ^ eps' + K₁ * X ^ eps' + K₂ * X ^ (1/2 + 3 * eps') := by
          rw [h1_eval, h2_eval, h3_eval]
      _ ≤ (K + K₁ + K₂) * X ^ (1/2 + 3 * eps') := h_sum
      _ ≤ (K + K₁ + K₂) * ((3/2 : ℝ) * x) ^ (1/2 + 3 * eps') := by
          apply mul_le_mul_of_nonneg_left _ (by positivity)
          exact rpow_le_rpow hX_pos.le h_X_le (by linarith)
      _ = (K + K₁ + K₂) * ((3/2 : ℝ) ^ (1/2 + 3 * eps') * x ^ (1/2 + 3 * eps')) := by
          rw [mul_rpow (by norm_num : (0:ℝ) ≤ 3/2) hx_pos.le]
      _ ≤ (K + K₁ + K₂) * ((3/2 : ℝ) ^ ((1:ℝ)/2 + eps) * x ^ (1/2 + 3 * eps')) := by
          apply mul_le_mul_of_nonneg_left _ (by positivity)
          apply mul_le_mul_of_nonneg_right _ (rpow_nonneg hx_pos.le _)
          exact rpow_le_rpow_of_exponent_le (by norm_num : (1:ℝ) ≤ 3/2) (by linarith)
      _ ≤ (K + K₁ + K₂) * ((3/2 : ℝ) ^ ((1:ℝ)/2 + eps) * x ^ ((1:ℝ)/2 + eps)) := by
          apply mul_le_mul_of_nonneg_left _ (by positivity)
          apply mul_le_mul_of_nonneg_left _ (rpow_nonneg (by norm_num : (0:ℝ) ≤ 3/2) _)
          exact rpow_le_rpow_of_exponent_le (show (1:ℝ) ≤ x by linarith) (by linarith)
      _ = C_main * x ^ ((1:ℝ)/2 + eps) := by ring
      _ ≤ C_final * x ^ ((1:ℝ)/2 + eps) := by
          apply mul_le_mul_of_nonneg_right _ (rpow_nonneg hx_pos.le _)
          simp only [C_final]; linarith [le_max_left C_main C_compact]

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
