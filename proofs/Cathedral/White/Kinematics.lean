/-
  Cathedral/White/Kinematics.lean

  ## Phase I, Strike 1: Reflection Positivity — Kill Axiom 2

  TARGET: Eliminate `autocorr_eval_zero` from PlancherelBypass.lean.

  ### Physics
  The energy of the vacuum is positive-definite.
  The autocorrelation at zero lag equals the L² norm in position space.

  ### Math
  Change of variables x = e^{-u} maps (0,1] → [0,∞).
  The Jacobian |dx/du| = e^{-u} is absorbed by the flattening factor:
    g_N(u)² = r_N(e^{-u})² · e^{-u}
  (already proved as `flattenedResidualV_sq_eq`).

  ### Strategy
  Use Mathlib's `integral_comp_mul_deriv_Ioi` or
  `MeasureTheory.integral_image_eq_integral_abs_deriv_smul`
  to formally execute the substitution.

  ### Dependencies
  - flattenedResidualV_sq_eq (PlancherelBypass.lean, PROVED)
  - autocorrelation_zero_eq_l2 (PlancherelBypass.lean, PROVED)
  - Mathlib.MeasureTheory.Integral.IntegralEqImproper
-/

import Cathedral.MellinBridge.PlancherelBypass
import Mathlib.MeasureTheory.Integral.IntegralEqImproper
import Mathlib.MeasureTheory.Function.JacobianOneDim

noncomputable section
open Real MeasureTheory Set Filter

namespace Cathedral.White

-- ════════════════════════════════════════════════
-- §1. THE DIFFEOMORPHISM: x = exp(-u)
-- ════════════════════════════════════════════════

/-- The map u ↦ exp(-u) is strictly decreasing on [0,∞) with range (0,1]. -/
lemma exp_neg_strictAntiOn : StrictAntiOn (fun u => Real.exp (-u)) (Set.Ici 0) := by
  intro a _ b _ hab
  exact Real.exp_lt_exp_of_lt (neg_lt_neg hab)

/-- The derivative of u ↦ exp(-u) is -exp(-u). -/
lemma hasDerivAt_exp_neg (u : ℝ) :
    HasDerivAt (fun u => Real.exp (-u)) (-Real.exp (-u)) u := by
  have := Real.hasDerivAt_exp (-u)
  simpa using this.comp u (hasDerivAt_neg u)

/-- exp(-u) maps [0,∞) into (0,1]. -/
lemma exp_neg_mem_Ioc (u : ℝ) (hu : 0 ≤ u) :
    Real.exp (-u) ∈ Set.Ioc 0 1 := by
  constructor
  · exact Real.exp_pos _
  · rwa [Real.exp_le_one_iff, neg_le, neg_zero]

-- ════════════════════════════════════════════════
-- §2. THE JACOBIAN ABSORPTION (CORE IDENTITY)
-- ════════════════════════════════════════════════

/-- exp(-u) is antitone on Ioi(0). -/
lemma exp_neg_antitoneOn : AntitoneOn (fun u : ℝ => Real.exp (-u)) (Set.Ioi 0) :=
  fun _ _ _ _ hab => Real.exp_le_exp.mpr (neg_le_neg hab)

/-- The derivative of exp(-u) within Ioi is -exp(-u). -/
lemma hasDerivWithinAt_exp_neg (u : ℝ) (_ : u ∈ Set.Ioi (0 : ℝ)) :
    HasDerivWithinAt (fun u => Real.exp (-u)) (-Real.exp (-u)) (Set.Ioi 0) u := by
  have : HasDerivAt (fun u => Real.exp (-u)) (Real.exp (-u) * (-1)) u := by
    exact (Real.hasDerivAt_exp (-u)).comp u (hasDerivAt_id u).neg
  simp only [mul_neg, mul_one] at this
  exact this.hasDerivWithinAt

/-- exp(-·) maps Ioi(0) onto Ioo(0,1). -/
lemma exp_neg_image_Ioi : (fun u : ℝ => Real.exp (-u)) '' Set.Ioi 0 = Set.Ioo 0 1 := by
  ext x
  simp only [Set.mem_image, Set.mem_Ioi, Set.mem_Ioo]
  constructor
  · rintro ⟨u, hu, rfl⟩
    exact ⟨Real.exp_pos _, by rwa [Real.exp_lt_one_iff, neg_neg_iff_pos]⟩
  · intro ⟨hx_pos, hx_lt⟩
    refine ⟨-Real.log x, ?_, ?_⟩
    · rw [neg_pos]; exact Real.log_neg hx_pos hx_lt
    · simp [Real.exp_log hx_pos]

/-- **KEY STEP**: The integral of g_N² over (0,∞) equals the integral
    of r_N² over (0,1) via x = exp(-u).

    Uses Mathlib's antitone change of variables:
      ∫ x in f '' s, g x = ∫ u in s, (-f'(u)) • g(f(u))

    With f(u) = exp(-u), -f'(u) = exp(-u), and
    g_N(u)² = r_N(exp(-u))² · exp(-u)  [from flattenedResidualV_sq_eq]. -/
theorem flattened_l2_eq_residual_l2 (N : ℕ) (v : Fin (N - 1) → ℝ) :
    ∫ u in Set.Ioi (0 : ℝ), (flattenedResidualV N v u) ^ 2 =
    ∫ x in (0:ℝ)..1, (bdResidualV N v x) ^ 2 := by
  -- Step 1: Rewrite g_N(u)² = r_N(exp(-u))² · exp(-u) using flattenedResidualV_sq_eq
  have h_sq : ∀ u ∈ Set.Ioi (0 : ℝ),
      (flattenedResidualV N v u) ^ 2 =
      (bdResidualV N v (Real.exp (-u))) ^ 2 * Real.exp (-u) := by
    intro u hu
    exact flattenedResidualV_sq_eq N v u (le_of_lt (Set.mem_Ioi.mp hu))
  -- Step 2: Rewrite the Ioi integral pointwise
  rw [setIntegral_congr_fun measurableSet_Ioi h_sq]
  -- Step 3: Apply antitone change of variables (JacobianOneDim)
  -- For antitone f, ∫ x in f '' s, g x = ∫ u in s, (-f'(u)) • g(f(u))
  -- We reverse: ∫ u in s, (-f'(u)) • g(f(u)) = ∫ x in f '' s, g x
  -- With f(u) = exp(-u), -f'(u) = exp(-u), f '' Ioi(0) = Ioo(0,1)
  have h_antitone := MeasureTheory.integral_image_eq_integral_deriv_smul_of_antitoneOn
    measurableSet_Ioi
    (fun u hu => hasDerivWithinAt_exp_neg u hu)
    exp_neg_antitoneOn
    (fun x : ℝ => (bdResidualV N v x : ℝ) ^ 2)
  rw [exp_neg_image_Ioi] at h_antitone
  -- h_antitone: ∫ x ∈ Ioo(0,1), g(x) = ∫ u ∈ Ioi(0), (-(-exp(-u))) • g(exp(-u))
  simp only [neg_neg, smul_eq_mul] at h_antitone
  -- h_antitone: ∫ x ∈ Ioo 0 1, .. = ∫ u ∈ Ioi 0, exp(-u) * (bdResidualV ..)²
  -- Goal: ∫ u ∈ Ioi 0, (bdResidualV ..)² * exp(-u) = ∫ x in 0..1, (bdResidualV ..)²
  -- First commute the multiplication in the goal to match h_antitone
  rw [show (fun u => bdResidualV N v (Real.exp (-u)) ^ 2 * Real.exp (-u)) =
      (fun u => Real.exp (-u) * bdResidualV N v (Real.exp (-u)) ^ 2) from by ext u; ring]
  rw [← h_antitone, ← integral_Ioc_eq_integral_Ioo,
      intervalIntegral.integral_of_le (by norm_num : (0:ℝ) ≤ 1)]

-- ════════════════════════════════════════════════
-- §3. FULL INTEGRAL SPLITTING
-- ════════════════════════════════════════════════

/-- g_N(u) = 0 for u < 0 by definition. -/
lemma flattenedResidualV_zero_of_neg (N : ℕ) (v : Fin (N - 1) → ℝ) (u : ℝ) (hu : u < 0) :
    flattenedResidualV N v u = 0 := by
  unfold flattenedResidualV
  simp [show ¬(0 ≤ u) from not_le.mpr hu]

/-- g_N(u)² = 0 for u < 0, since g_N(u) = 0. -/
lemma flattenedResidualV_sq_zero_of_neg (N : ℕ) (v : Fin (N - 1) → ℝ) (u : ℝ) (hu : u < 0) :
    (flattenedResidualV N v u) ^ 2 = 0 := by
  rw [flattenedResidualV_zero_of_neg N v u hu]; ring

/-- The full-line integral of g_N² equals the [0,∞) integral.
    On (-∞, 0), g_N = 0 pointwise, so the function is supported on [0,∞). -/
lemma full_integral_eq_Ici (N : ℕ) (v : Fin (N - 1) → ℝ) :
    ∫ u : ℝ, (flattenedResidualV N v u) ^ 2 =
    ∫ u in Set.Ici (0 : ℝ), (flattenedResidualV N v u) ^ 2 := by
  symm
  apply setIntegral_eq_integral_of_forall_compl_eq_zero
  intro u hu
  simp only [Set.mem_Ici, not_le] at hu
  exact flattenedResidualV_sq_zero_of_neg N v u hu

/-- The [0,∞) integral equals the (0,∞) integral, since {0} has measure zero. -/
lemma Ici_eq_Ioi_integral (N : ℕ) (v : Fin (N - 1) → ℝ) :
    ∫ u in Set.Ici (0 : ℝ), (flattenedResidualV N v u) ^ 2 =
    ∫ u in Set.Ioi (0 : ℝ), (flattenedResidualV N v u) ^ 2 := by
  apply setIntegral_congr_set
  exact Ioi_ae_eq_Ici.symm

/-- **PROVED**: The full-line integral of g_N² equals the half-line integral. -/
lemma full_integral_eq_halfline (N : ℕ) (v : Fin (N - 1) → ℝ) :
    ∫ u : ℝ, (flattenedResidualV N v u) ^ 2 =
    ∫ u in Set.Ioi (0 : ℝ), (flattenedResidualV N v u) ^ 2 := by
  rw [full_integral_eq_Ici N v, Ici_eq_Ioi_integral N v]

-- ════════════════════════════════════════════════
-- §4. THE THEOREM (AXIOM 2 ELIMINATION)
-- ════════════════════════════════════════════════

/-- **THEOREM**: Axiom 2 (`autocorr_eval_zero`) proved.

    The autocorrelation at zero lag equals the L²(0,1) norm of the residual.

    Proof chain:
    1. h(0) = ∫ g_N² du                  [autocorrelation_zero_eq_l2, PROVED]
    2. ∫ g_N² du = ∫₀^∞ g_N² du          [full_integral_eq_halfline, this file]
    3. ∫₀^∞ g_N² du = ∫₀¹ r_N² dx        [flattened_l2_eq_residual_l2, this file]
    4. Chain: h(0) = ∫₀¹ r_N² dx          [QED]

    Physics: Reflection Positivity. The vacuum energy is the L² norm. -/
theorem autocorr_eval_zero_proved (N : ℕ) (v : Fin (N - 1) → ℝ) :
    residualAutocorrelation N v 0 = ∫ x in (0:ℝ)..1, (bdResidualV N v x) ^ 2 := by
  -- Step 1: h(0) = ∫ g_N(u)² du {autocorrelation_zero_eq_l2, PROVED}
  rw [autocorrelation_zero_eq_l2 N v]
  -- Step 2: ∫ g_N² du = ∫₀^∞ g_N² du {full_integral_eq_halfline}
  rw [full_integral_eq_halfline N v]
  -- Step 3: ∫₀^∞ g_N² du = ∫₀¹ r_N² dx {flattened_l2_eq_residual_l2}
  exact flattened_l2_eq_residual_l2 N v

-- ════════════════════════════════════════════════
-- AUDIT: AXIOM 2 STATUS — **COMPLETE**
-- ════════════════════════════════════════════════
-- autocorr_eval_zero_proved depends on:
--   ✅ autocorrelation_zero_eq_l2 (PROVED in PlancherelBypass.lean)
--   ✅ flattenedResidualV_sq_eq (PROVED in PlancherelBypass.lean)
--   ✅ full_integral_eq_halfline (PROVED — integral splitting via Ici/Ioi)
--   ✅ flattened_l2_eq_residual_l2 (PROVED — antitone CoV via JacobianOneDim)
--
-- Total sorry count: 0 🤍
-- AXIOM 2 (Reflection Positivity) is ELIMINATED.
-- Pure measure-theoretic proof. No number theory axioms.

end Cathedral.White
