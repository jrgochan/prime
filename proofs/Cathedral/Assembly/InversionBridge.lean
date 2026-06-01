/-
  Cathedral/Assembly/InversionBridge.lean

  # THE INVERSION BRIDGE: Sawtooth → BD via x ↦ 1/x

  ════════════════════════════════════════════════════════════════

  ## The Two Shorelines

  The Cathedral has two halves that don't connect:

  **East Wing** (SmithWitness + SmithFranelBridge):
    d²_saw → 0 unconditionally via Euclid.
    Zero sorry, zero axioms.
    The sawtooth basis {kt} is complete in L²(0,1).

  **West Wing** (NymanBeurling/Separation):
    d²_BD → 0 → RH via rank-1 Mellin separation.
    Zero custom axioms.

  ## The Channel

  Under the change of variables x = 1/t:

    ∫₀¹ |1 - Σ cₖ{1/(kx)}|² dx = ∫₁^∞ |1 - Σ cₖ{t/k}|² dt/t²

  So BD approximation on (0,1) ≡ {t/k} approximation on (1,∞)
  with weight 1/t².

  The functions {kt} and {t/k} are fundamentally different:
  - {kt} has k teeth on (0,1) — high frequency
  - {t/k} has 1 tooth on (0,k) — low frequency, slow decay

  Their relationship passes through the Möbius function, and
  whether completeness of {kt} on (0,1) transfers to completeness
  of {t/k} on (1,∞) with weight 1/t² IS the Riemann Hypothesis.

  ## The Bridge

  This file defines a single clean axiom `inversion_completeness`
  that encodes the RH content as a statement about function
  approximation under coordinate inversion, and wires it into:

    inversion_completeness + Smith witness → d²_BD → 0 → RH

  ## Axiom Class: CROWN (1 axiom, ≡ RH)

  Status: PROVED modulo 1 axiom + 1 standard-calculus sorry.
  Created: May 31, 2026 — The Inversion Bridge
-/

import Cathedral.Defs
import Cathedral.NymanBeurling.BDMellin
import Cathedral.NymanBeurling.Separation
import Cathedral.NymanBeurling.BDBridgeProved
import Cathedral.Physics.GramWiring.SmithWitness
import Cathedral.Physics.GramWiring.SmithFranelBridge
import Mathlib.MeasureTheory.Integral.IntegralEqImproper

noncomputable section
open Real MeasureTheory Set Filter Finset Topology

-- ════════════════════════════════════════════════════════════════
-- §1. DEFINITIONS
-- ════════════════════════════════════════════════════════════════

/-- The BD fractional function on the half-line: {t/k} for t ∈ (0,∞).
    Under x = 1/t, the BD basis function {1/(kx)} becomes {t/k}. -/
def bdFractHalfLine (k : ℕ) (t : ℝ) : ℝ := Int.fract (t / (k : ℝ))

/-- The sawtooth basis function: {kt} for t ∈ (0,1).
    This is the function system used by the Smith witness.
    Unconditionally complete in L²(0,1). -/
def sawtoothBasis (k : ℕ) (t : ℝ) : ℝ := Int.fract ((k : ℝ) * t)

/-- BD linear combination on the half-line (1,∞):
    f(t) = Σᵢ cᵢ · {t/(i+1)}.
    This is what bdLinComb becomes after x = 1/t. -/
def bdHalfLineComb (N : ℕ) (c : Fin (N - 1) → ℝ) (t : ℝ) : ℝ :=
  ∑ i : Fin (N - 1), c i * bdFractHalfLine (i.val + 1) t

/-- Sawtooth linear combination on (0,1):
    f(t) = Σᵢ cᵢ · {(i+1)·t}.
    This is the function system proved complete by the Smith witness. -/
def sawLinComb (N : ℕ) (c : Fin (N - 1) → ℝ) (t : ℝ) : ℝ :=
  ∑ i : Fin (N - 1), c i * sawtoothBasis (i.val + 1) t

-- ════════════════════════════════════════════════════════════════
-- §2. CHANGE OF VARIABLES (standard calculus)
-- ════════════════════════════════════════════════════════════════

/-- **LEMMA**: bdLinComb at 1/t equals bdHalfLineComb at t.
    Under the substitution x = 1/t:
      Σ cₖ {1/((k+1)·x)} = Σ cₖ {t/(k+1)}
    since 1/((k+1)·(1/t)) = t/(k+1). -/
lemma bdLinComb_inv_eq_halfLine (N : ℕ) (c : Fin (N - 1) → ℝ) (t : ℝ)
    (ht : t ≠ 0) :
    bdLinComb N c (1 / t) = bdHalfLineComb N c t := by
  unfold bdLinComb bdHalfLineComb bdFractHalfLine
  congr 1; ext i
  congr 1
  rw [show 1 / ((↑(i.val + 1) : ℝ) * (1 / t)) = t / ↑(i.val + 1) from by
    have hi : (↑(i.val + 1) : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
    field_simp]

-- ════════════════════════════════════════════════════════════════
-- §2. CHANGE OF VARIABLES (standard calculus)
-- ════════════════════════════════════════════════════════════════

/-!
### Change of Variables: BD L² on (0,1) = half-line L² with weight 1/t²

Under x = 1/t (with dx = -dt/t²):
  ∫₀¹ |1 - Σ cₖ{1/(kx)}|² dx = ∫₁^∞ |1 - Σ cₖ{t/k}|² dt/t²

**PROOF ARCHITECTURE**:
1. **Pointwise identity** (`integrand_transform`): PROVED via `bdLinComb_inv_eq_halfLine`
2. **Finite substitution** (`finite_cov_inv`): for R > 1,
   ∫ x in (1/R)..1, g(x) = ∫ t in 1..R, g(1/t)/t²
   via `integral_comp_mul_deriv_of_deriv_nonpos` with φ(t)=1/t
3. **Limit**: As R→∞, both sides converge to the desired improper integrals
-/

/-- Pointwise identity: for t ≠ 0, the BD integrand under 1/t substitution
    gives the half-line integrand. -/
private lemma integrand_transform (N : ℕ) (c : Fin (N - 1) → ℝ) (t : ℝ)
    (ht : t ≠ 0) :
    (1 - bdLinComb N c (1 / t)) ^ 2 = (1 - bdHalfLineComb N c t) ^ 2 := by
  rw [bdLinComb_inv_eq_halfLine N c t ht]

/-- **Finite substitution**: for R > 1,
    ∫ x in (1/R)..1, g(x) = ∫ t in 1..R, g(1/t)/t².

    Uses `integral_comp_mul_deriv_of_deriv_nonpos` with φ(t) = 1/t, φ'(t) = -1/t² ≤ 0.
    Since φ(1) = 1, φ(R) = 1/R:
      ∫ t in 1..R, g(φ(t)) · φ'(t) = ∫ u in φ(1)..φ(R), g(u) = ∫ u in 1..(1/R), g(u)
    Negating both sides gives the result. -/
private lemma finite_cov_inv (g : ℝ → ℝ) (R : ℝ) (hR : 1 < R) :
    ∫ x in (1/R)..1, g x =
    ∫ t in (1:ℝ)..R, g (1 / t) / t ^ 2 := by
  -- Apply integral_comp_mul_deriv_of_deriv_nonpos with φ(t)=1/t
  have h_cov := intervalIntegral.integral_comp_mul_deriv_of_deriv_nonpos
    (f := fun t => t⁻¹) (f' := fun t => -(t ^ 2)⁻¹) (g := g)
    -- Hypothesis 1: ContinuousOn (·⁻¹) on [[1, R]]
    (by apply ContinuousOn.inv₀ continuousOn_id
        intro x hx
        rw [Set.uIcc_of_le hR.le] at hx
        exact ne_of_gt (lt_of_lt_of_le one_pos hx.1))
    -- Hypothesis 2: HasDerivAt (·⁻¹) (-(·^2)⁻¹) on Ioo 1 R
    (by intro x hx
        simp only [min_eq_left hR.le, max_eq_right hR.le] at hx
        exact hasDerivAt_inv (ne_of_gt (lt_trans one_pos hx.1)))
    -- Hypothesis 3: -(·^2)⁻¹ ≤ 0 on Ioo 1 R
    (by intro x hx
        simp only [min_eq_left hR.le, max_eq_right hR.le] at hx
        apply neg_nonpos_of_nonneg
        exact inv_nonneg.mpr (sq_nonneg x))
  -- h_cov : ∫ t in 1..R, (g ∘ (·⁻¹)) t * (-(t^2)⁻¹) = ∫ u in 1⁻¹..R⁻¹, g u
  simp only [inv_one] at h_cov
  -- h_cov : ∫ t in 1..R, (g ∘ (·⁻¹)) t * (-(t^2)⁻¹) = ∫ u in 1..R⁻¹, g u
  -- RHS: ∫ u in 1..R⁻¹ = -(∫ u in R⁻¹..1)
  rw [show (1 : ℝ) / R = R⁻¹ from one_div R]
  -- Goal: ∫ x in R⁻¹..1, g x = ∫ t in 1..R, g(1/t)/t²
  -- From h_cov, using integral_symm on the RHS of h_cov:
  -- ∫ u in 1..R⁻¹ = -(∫ u in R⁻¹..1)
  -- So h_cov says: LHS_neg = -(∫ u in R⁻¹..1, g u)
  -- where LHS_neg = ∫ t in 1..R, g(t⁻¹) * (-(t^2)⁻¹)
  --              = -(∫ t in 1..R, g(t⁻¹) * (t^2)⁻¹)
  -- So: -(∫ t in 1..R, g(t⁻¹) * (t^2)⁻¹) = -(∫ u in R⁻¹..1, g u)
  -- => ∫ u in R⁻¹..1, g u = ∫ t in 1..R, g(t⁻¹) * (t^2)⁻¹
  -- We just need: g(t⁻¹) * (t^2)⁻¹ = g(1/t) / t^2 (trivially true)
  --
  -- Manipulate h_cov algebraically:
  have h1 : ∫ u in (1 : ℝ)..R⁻¹, g u = -(∫ u in R⁻¹..1, g u) :=
    intervalIntegral.integral_symm R⁻¹ 1
  rw [h1] at h_cov
  -- h_cov : ∫ t in 1..R, (g ∘ (·⁻¹)) t * (-(t^2)⁻¹) = -(∫ u in R⁻¹..1, g u)
  -- LHS of h_cov: factor out negative
  have h2 : ∀ t : ℝ, (g ∘ fun t => t⁻¹) t * (-(t ^ 2)⁻¹) =
      -(g (t⁻¹) * (t ^ 2)⁻¹) := by
    intro t; simp [Function.comp, mul_neg]
  simp_rw [h2] at h_cov
  rw [intervalIntegral.integral_neg] at h_cov
  -- h_cov : -(∫ t in 1..R, g(t⁻¹) * (t^2)⁻¹) = -(∫ u in R⁻¹..1, g u)
  -- Cancel negation
  have h3 : ∫ u in R⁻¹..1, g u = ∫ t in (1:ℝ)..R, g (t⁻¹) * (t ^ 2)⁻¹ := by
    linarith
  rw [h3]
  -- Goal: ∫ t in 1..R, g(t⁻¹) * (t^2)⁻¹ = ∫ t in 1..R, g(1/t) / t^2
  congr 1; ext t
  -- g(t⁻¹) * (t^2)⁻¹ = g(1/t) / t^2
  rw [one_div, div_eq_mul_inv]

/-- The full change of variables: ∫₀¹ f(x)dx = ∫₁^∞ f(1/t)/t² dt -/
theorem change_of_variables_bd (N : ℕ) (c : Fin (N - 1) → ℝ) :
    ∫ x in (0:ℝ)..1, (1 - bdLinComb N c x) ^ 2 =
    ∫ t in Set.Ioi (1 : ℝ),
      (1 - bdHalfLineComb N c t) ^ 2 / t ^ 2 := by
  -- Step 1: Rewrite RHS using the pointwise identity
  suffices h : ∫ x in (0:ℝ)..1, (1 - bdLinComb N c x) ^ 2 =
      ∫ t in Set.Ioi (1 : ℝ), (1 - bdLinComb N c (1 / t)) ^ 2 / t ^ 2 by
    rw [h]; congr 1; ext t
    by_cases ht : t = 0
    · simp [ht]
    · rw [integrand_transform N c t ht]
  -- Step 2: Use finite_cov_inv + limits
  -- Strategy: both sides are limits of the same sequence via finite_cov_inv
  set g : ℝ → ℝ := fun x => (1 - bdLinComb N c x) ^ 2
  set h : ℝ → ℝ := fun t => g (1 / t) / t ^ 2
  -- The finite identity: for n ≥ 2, ∫ x in (1/n)..1, g x = ∫ t in 1..n, h t
  have h_fin : ∀ n : ℕ, 1 < (n : ℝ) →
      ∫ x in (1/(n:ℝ))..1, g x = ∫ t in (1:ℝ)..(n:ℝ), h t := by
    intro n hn; exact finite_cov_inv g n hn
  -- LHS convergence: ∫ x in (1/n)..1, g x → ∫ x in 0..1, g x
  -- Because x ↦ ∫ t in x..1, g(t) is continuous (primitive of interval-integrable function)
  have h_lhs : Tendsto (fun n : ℕ => ∫ x in (1/(n:ℝ))..1, g x) atTop
      (𝓝 (∫ x in (0:ℝ)..1, g x)) := by
    -- F(a) = ∫ x in a..1, g(x) is continuous by continuous_primitive + integral_symm
    -- and 1/n → 0, so F(1/n) → F(0)
    have h_int : ∀ a b : ℝ, IntervalIntegrable g volume a b := by
      intro a b
      -- g = (1 - bdLinComb)² is bounded and measurable, hence interval-integrable
      -- Follow the pattern from bdLinComb_sq_integrable in BDMellin.lean
      have h_meas : Measurable g := by
        change Measurable (fun x => (1 - bdLinComb N c x) ^ 2)
        apply Measurable.pow_const
        exact measurable_const.sub (Finset.measurable_sum _ (fun i _ =>
          (measurable_fract_real.comp (measurable_const.div
            (measurable_const.mul measurable_id))).const_mul (c i)))
      -- Bound: |g(x)| ≤ (1 + Σ|cᵢ|)²
      set C := 1 + ∑ i : Fin (N - 1), |c i|
      have h_bound : ∀ x, ‖g x‖ ≤ C ^ 2 := by
        intro x
        show ‖(1 - bdLinComb N c x) ^ 2‖ ≤ C ^ 2
        rw [Real.norm_eq_abs, abs_of_nonneg (sq_nonneg _)]
        have h_bd_bound : |bdLinComb N c x| ≤ ∑ i : Fin (N-1), |c i| := by
          unfold bdLinComb
          calc |(∑ i, c i * Int.fract (1 / (↑(i.val + 1) * x)))|
              ≤ ∑ i, |c i * Int.fract (1 / (↑(i.val + 1) * x))| :=
                Finset.abs_sum_le_sum_abs _ _
            _ = ∑ i, |c i| * |Int.fract (1 / (↑(i.val + 1) * x))| := by
                congr 1; ext i; exact abs_mul _ _
            _ ≤ ∑ i, |c i| * 1 := by
                apply Finset.sum_le_sum; intro i _
                exact mul_le_mul_of_nonneg_left ((abs_of_nonneg (Int.fract_nonneg _)).le.trans
                  (Int.fract_lt_one _).le) (abs_nonneg _)
            _ = _ := by simp
        have hC_pos : 0 ≤ C - 1 := by
          simp only [C, add_sub_cancel_left]
          exact Finset.sum_nonneg (fun i _ => abs_nonneg _)
        have h_abs : |1 - bdLinComb N c x| ≤ C := by
          have h1 : -(bdLinComb N c x) ≤ |bdLinComb N c x| := neg_le_abs (bdLinComb N c x)
          have h2 : bdLinComb N c x ≤ |bdLinComb N c x| := le_abs_self _
          rw [abs_le]
          constructor
          -- -C ≤ 1 - bdLinComb: need bdLinComb ≤ 1 + C, which is clear
          · linarith [h1, h_bd_bound]
          -- 1 - bdLinComb ≤ C: need -bdLinComb ≤ C - 1 = Σ|cᵢ|, i.e., bdLinComb ≥ -Σ|cᵢ|
          · linarith [h1, h_bd_bound]
        calc (1 - bdLinComb N c x) ^ 2 = |1 - bdLinComb N c x| ^ 2 := by
              rw [sq_abs]
           _ ≤ C ^ 2 := pow_le_pow_left₀ (abs_nonneg _) h_abs 2
      -- Bounded measurable functions are interval-integrable
      -- Use wlog: swap bounds if needed since IntervalIntegrable is symmetric
      rcases le_or_gt a b with hab | hab
      · rw [intervalIntegrable_iff_integrableOn_Ioc_of_le hab]
        exact ⟨h_meas.aestronglyMeasurable, .of_bounded
          (Filter.Eventually.of_forall (fun x => h_bound x))⟩
      · exact (IntervalIntegrable.symm
          (by rw [intervalIntegrable_iff_integrableOn_Ioc_of_le (by linarith)]
              exact ⟨h_meas.aestronglyMeasurable, .of_bounded
                (Filter.Eventually.of_forall (fun x => h_bound x))⟩))
    -- Primitive is continuous: b ↦ ∫ x in 1..b, g(x) is continuous
    have h_cont := intervalIntegral.continuous_primitive h_int 1
    -- So a ↦ ∫ x in a..1, g(x) = -(∫ x in 1..a, g(x)) is continuous
    have h_F_cont : Continuous (fun a => ∫ x in a..(1:ℝ), g x) := by
      have : (fun a => ∫ x in a..(1:ℝ), g x) = (fun a => -(∫ x in (1:ℝ)..a, g x)) := by
        ext a; exact intervalIntegral.integral_symm 1 a
      rw [this]
      exact h_cont.neg
    -- 1/n → 0
    have h_inv_tendsto : Tendsto (fun n : ℕ => (1 : ℝ) / (n : ℝ)) atTop (𝓝 0) := by
      simp only [one_div]
      exact tendsto_inv_atTop_zero.comp tendsto_natCast_atTop_atTop
    -- Compose: F(1/n) → F(0)
    exact (h_F_cont.tendsto 0).comp h_inv_tendsto
  -- RHS convergence: ∫ t in 1..n, h t → ∫ t in Ioi 1, h t
  -- By intervalIntegral_tendsto_integral_Ioi
  have h_rhs : Tendsto (fun n : ℕ => ∫ t in (1:ℝ)..(n:ℝ), h t) atTop
      (𝓝 (∫ t in Set.Ioi (1:ℝ), h t)) := by
    apply intervalIntegral_tendsto_integral_Ioi
    · -- IntegrableOn h (Ioi 1)
      -- h(t) = g(1/t)/t². Since |g| ≤ C² (proved above), |h(t)| ≤ C²/t²
      -- and 1/t² is integrable on Ioi 1 by integrableOn_Ioi_rpow_of_lt
      set C := 1 + ∑ i : Fin (N - 1), |c i|
      have h_g_bound : ∀ x, |g x| ≤ C ^ 2 := by
        intro x
        show |(1 - bdLinComb N c x) ^ 2| ≤ C ^ 2
        rw [abs_of_nonneg (sq_nonneg _)]
        have h_bd_bound : |bdLinComb N c x| ≤ ∑ i : Fin (N-1), |c i| := by
          unfold bdLinComb
          calc |(∑ i, c i * Int.fract (1 / (↑(i.val + 1) * x)))|
              ≤ ∑ i, |c i * Int.fract (1 / (↑(i.val + 1) * x))| :=
                Finset.abs_sum_le_sum_abs _ _
            _ = ∑ i, |c i| * |Int.fract (1 / (↑(i.val + 1) * x))| := by
                congr 1; ext i; exact abs_mul _ _
            _ ≤ ∑ i, |c i| * 1 := by
                apply Finset.sum_le_sum; intro i _
                exact mul_le_mul_of_nonneg_left ((abs_of_nonneg (Int.fract_nonneg _)).le.trans
                  (Int.fract_lt_one _).le) (abs_nonneg _)
            _ = _ := by simp
        have hC_pos : 0 ≤ C - 1 := by
          simp only [C, add_sub_cancel_left]
          exact Finset.sum_nonneg (fun i _ => abs_nonneg _)
        have h_abs : |1 - bdLinComb N c x| ≤ C := by
          have hle : bdLinComb N c x ≤ ∑ i : Fin (N-1), |c i| :=
            (le_abs_self _).trans h_bd_bound
          have hge : -(∑ i : Fin (N-1), |c i|) ≤ bdLinComb N c x := by
            have := neg_abs_le (bdLinComb N c x)
            linarith [h_bd_bound]
          rw [abs_le]; constructor <;> linarith
        calc (1 - bdLinComb N c x) ^ 2 = |1 - bdLinComb N c x| ^ 2 := by
              rw [sq_abs]
           _ ≤ C ^ 2 := pow_le_pow_left₀ (abs_nonneg _) h_abs 2
      -- h is measurable
      have h_meas_h : Measurable h := by
        change Measurable (fun t => (1 - bdLinComb N c (1 / t)) ^ 2 / t ^ 2)
        apply Measurable.div
        · apply Measurable.pow_const
          exact measurable_const.sub (Finset.measurable_sum _ (fun i _ =>
            (measurable_fract_real.comp (measurable_const.div
              (measurable_const.mul (measurable_const.div measurable_id)))).const_mul (c i)))
        · exact measurable_id.pow_const 2
      -- Bound: |h(t)| ≤ C² / t² for t > 0
      have h_norm_bound : ∀ t ∈ Set.Ioi (1:ℝ), ‖h t‖ ≤ C ^ 2 / t ^ 2 := by
        intro t ht
        simp only [Set.mem_Ioi] at ht
        show ‖g (1 / t) / t ^ 2‖ ≤ C ^ 2 / t ^ 2
        rw [Real.norm_eq_abs, abs_div, abs_of_nonneg (sq_nonneg _),
            abs_of_nonneg (sq_nonneg _)]
        apply div_le_div_of_nonneg_right _ (sq_nonneg _)
        -- g(1/t) = |g(1/t)| since g ≥ 0 (it's a square)
        exact le_of_eq_of_le (abs_of_nonneg (sq_nonneg _)).symm (h_g_bound (1 / t))
      -- IntegrableOn h (Ioi 1) by comparison with C²/t² via Integrable.mono'
      -- C²/t² = C² * t^(-2), and t^(-2) is integrable on Ioi 1
      have h_bound_int : IntegrableOn (fun t : ℝ => C ^ 2 / t ^ 2) (Set.Ioi 1) := by
        have h1 : IntegrableOn (fun t : ℝ => C ^ 2 * t ^ ((-2:ℝ))) (Set.Ioi 1) :=
          (integrableOn_Ioi_rpow_of_lt (show (-2:ℝ) < -1 by norm_num) one_pos).const_mul (C^2)
        apply h1.congr_fun _ measurableSet_Ioi
        intro t ht
        simp only [Set.mem_Ioi] at ht
        show C ^ 2 * t ^ ((-2 : ℝ)) = C ^ 2 / t ^ 2
        rw [Real.rpow_neg (le_of_lt (by linarith : (0:ℝ) < t)),
            show (2:ℝ) = ((2:ℕ) : ℝ) from by norm_num,
            Real.rpow_natCast, div_eq_mul_inv]
      exact h_bound_int.mono' h_meas_h.aestronglyMeasurable
        (by filter_upwards [ae_restrict_mem measurableSet_Ioi] with t ht
            exact h_norm_bound t ht)
    · -- Tendsto (fun n : ℕ => (n : ℝ)) atTop atTop
      exact tendsto_natCast_atTop_atTop
  -- Transfer h_rhs to an equivalent statement about the LHS sequence
  have h_transfer : Tendsto (fun n : ℕ => ∫ x in (1/(n:ℝ))..1, g x) atTop
      (𝓝 (∫ t in Set.Ioi (1:ℝ), h t)) := by
    apply Filter.Tendsto.congr' _ h_rhs
    filter_upwards [Filter.Ici_mem_atTop 2] with n (hn : 2 ≤ n)
    exact (h_fin n (by exact_mod_cast hn)).symm
  exact tendsto_nhds_unique h_lhs h_transfer

-- ════════════════════════════════════════════════════════════════
-- §3. SAWTOOTH COMPLETENESS (bridge from Smith to L² form)
-- ════════════════════════════════════════════════════════════════

-- §3a. SAWTOOTH COMPLETENESS (unconditional L² approximation)
/-- The optimal sawtooth coefficients derived from the Smith witness.
    c_opt(i) = 2·w_{i+1} / (4+σ) where w = smithWitness, σ = sigmaWitness.
    These are the Gram matrix (G = R + (1/4)𝟏𝟏ᵀ) optimal coefficients
    minimizing ∫₀¹ |1 - Σ cₖ{kt}|² via Woodbury inversion. -/
noncomputable def sawOptCoeffs (N : ℕ) : Fin (N - 1) → ℝ :=
  let M := N - 1
  let σ := Cathedral.Physics.SmithWitness.sigmaWitness M
  fun i => 2 * Cathedral.Physics.SmithWitness.smithWitness M (i.val + 1) / (4 + σ)

/- **BRIDGE LEMMA** (axiomatized): The L² residual with optimal Smith
    coefficients equals the Glass Distance.

    With c_opt(i) = 2·w_{i+1}/(4+σ):
      ∫₀¹ (1 - sawLinComb N c_opt t)² = 4 / (4 + σ(N-1))

    Proof sketch (to be filled):
    1. Expand (1 - Σ cₖ{kt})² = 1 - 2 b^T c + c^T G c
       where bₖ = ∫₀¹ {kt} = 1/2, G_{ij} = ∫₀¹ {it}{jt} = R_{ij} + 1/4
    2. Apply fract_inner_product for G entries
    3. From Woodbury: c_opt = G⁻¹ b gives minimum = 1 - b^T G⁻¹ b
    4. Using R w = 𝟏 (smith_solve): G⁻¹ 𝟏 = 4w/(4+σ)
    5. d² = 1 - (1/2)·𝟏^T·(4w/(4+σ)) = 1 - σ/(4+σ) = 4/(4+σ) ✓

    All ingredients (fract_inner_product, smith_solve, mean value) are
    proved sorry-free in the Cathedral. The proof is purely algebraic.

    Key identity chain:
      ∫(1-f)² = 1 - Σcₖ + Σᵢⱼ cᵢcⱼ Rᵢⱼ + (Σcₖ)²/4
    With cₖ = 2wₖ/(4+σ), smith_solve gives Σᵢⱼ wᵢwⱼ Rᵢⱼ = σ:
      = 1 - 2σ/(4+σ) + 4σ/(4+σ)² + σ²/(4+σ)²
      = 1 - σ/(4+σ) = 4/(4+σ)  ✓ -/

/-- Mean of fractional part: ∫₀¹ {kt} dt = 1/2 for k ≥ 1.
    From {x} = B₁(x) + 1/2 and sawtooth_mean_zero: ∫B₁(kt) = 0. -/
private lemma fract_mean (k : ℕ) (hk : 0 < k) :
    ∫ t in (0:ℝ)..1, Int.fract ((k : ℝ) * t) = 1 / 2 := by
  -- {kt} = B₁(kt) + 1/2 pointwise
  simp_rw [Cathedral.FourierGram.fract_eq_sawtooth_add_half]
  -- Integrability of B₁(kt) on [0,1]
  have hint_saw : IntervalIntegrable
      (fun t => Cathedral.FourierGram.sawtoothReal ((k:ℝ) * t)) volume (0:ℝ) 1 :=
    (IntegrableOn.of_bound (by simp)
      (Cathedral.FourierGram.sawtoothReal_measurable.comp
        (measurable_const.mul measurable_id)).aestronglyMeasurable.restrict
      (1/2) (ae_of_all _ (fun t => Cathedral.FourierGram.sawtoothReal_bound _))).intervalIntegrable
  rw [intervalIntegral.integral_add hint_saw intervalIntegrable_const]
  rw [Cathedral.RamanujanInnerProduct.sawtooth_mean_zero k hk, zero_add]
  simp [intervalIntegral.integral_const]

/-- The quadratic form identity: for any coefficients c,
    ∫₀¹ (1 - sawLinComb N c t)² = 1 - Σcₖ + Σᵢⱼ cᵢcⱼ Gᵢⱼ
    where Gᵢⱼ = ∫₀¹ {(i+1)t}{(j+1)t} = gcd²/(12(i+1)(j+1)) + 1/4.

    This is the quadratic form expansion + integral linearity. -/
private lemma sawtooth_l2_quadratic (N : ℕ) (c : Fin (N-1) → ℝ) (_hN : 2 ≤ N) :
    ∫ t in (0:ℝ)..1, (1 - sawLinComb N c t) ^ 2 =
    1 - ∑ i : Fin (N-1), c i +
    ∑ i : Fin (N-1), ∑ j : Fin (N-1), c i * c j *
      (↑(Nat.gcd (i.val+1) (j.val+1))^2 / (12 * ↑(i.val+1) * ↑(j.val+1)) + 1/4) := by
  -- The proof expands (1-f)² = 1 - 2f + f², integrates by linearity,
  -- applies fract_mean for the linear terms and fract_inner_product for the quadratic.
  -- All integrability follows from boundedness of {kt} on [0,1].
  --
  -- We organize as: ∫(1-f)² = ∫1 - 2∫f + ∫f²
  --   = 1 - 2·Σcₖ·(1/2) + Σᵢⱼ cᵢcⱼ·G(i,j)
  --   = 1 - Σcₖ + Σᵢⱼ cᵢcⱼ·G(i,j)
  --
  -- Step 1: Key mean/inner-product facts
  have h_mean : ∀ k : Fin (N-1),
      ∫ t in (0:ℝ)..1, sawtoothBasis (k.val+1) t = 1/2 :=
    fun k => fract_mean (k.val+1) (by omega)
  have h_gram : ∀ (i j : Fin (N-1)),
      ∫ t in (0:ℝ)..1, sawtoothBasis (i.val+1) t * sawtoothBasis (j.val+1) t =
      ↑(Nat.gcd (i.val+1) (j.val+1))^2 / (12 * ↑(i.val+1) * ↑(j.val+1)) + 1/4 := by
    intro i j; exact Cathedral.RamanujanInnerProduct.fract_inner_product
      (i.val+1) (j.val+1) (by omega) (by omega)
  -- Integrability of sawtoothBasis (bounded measurable on [0,1])
  have hbasis : ∀ (k : ℕ), 0 < k →
      IntervalIntegrable (fun t => Int.fract ((k:ℝ) * t)) volume (0:ℝ) 1 := by
    intro k _
    simp_rw [Cathedral.FourierGram.fract_eq_sawtooth_add_half]
    exact IntervalIntegrable.add
      ((IntegrableOn.of_bound (by simp)
        (Cathedral.FourierGram.sawtoothReal_measurable.comp
          (measurable_const.mul measurable_id)).aestronglyMeasurable.restrict
        (1/2) (ae_of_all _ (fun t =>
          Cathedral.FourierGram.sawtoothReal_bound _))).intervalIntegrable)
      intervalIntegrable_const
  -- Integrability of c_k * basis_k
  have hcb : ∀ k : Fin (N-1),
      IntervalIntegrable (fun t => c k * sawtoothBasis (k.val+1) t) volume (0:ℝ) 1 :=
    fun k => (hbasis (k.val+1) (by omega)).const_mul (c k)
  -- Integrability of sawLinComb
  have hf : IntervalIntegrable (sawLinComb N c) volume (0:ℝ) 1 := by
    show IntervalIntegrable (fun t => ∑ i : Fin (N-1), c i * sawtoothBasis (i.val+1) t) _ _ _
    have : (fun t => ∑ i : Fin (N-1), c i * sawtoothBasis (i.val+1) t) =
        ∑ i ∈ Finset.univ, fun t => c i * sawtoothBasis (i.val+1) t := by
      ext t; simp [Finset.sum_apply]
    rw [this]
    exact IntervalIntegrable.sum Finset.univ (fun k _ => hcb k)
  -- Integrability of c_i * c_j * basis_i * basis_j
  have hcb2 : ∀ i j : Fin (N-1),
      IntervalIntegrable (fun t => c i * c j * (sawtoothBasis (i.val+1) t *
        sawtoothBasis (j.val+1) t)) volume (0:ℝ) 1 := by
    intro i j
    have hmeas : Measurable (fun t : ℝ =>
        Int.fract ((↑(i.val+1) : ℝ) * t) * Int.fract ((↑(j.val+1) : ℝ) * t)) :=
      (measurable_fract_real.comp (measurable_const.mul measurable_id)).mul
        (measurable_fract_real.comp (measurable_const.mul measurable_id))
    have hbound : ∀ t : ℝ, ‖Int.fract ((↑(i.val+1):ℝ) * t) *
        Int.fract ((↑(j.val+1):ℝ) * t)‖ ≤ 1 := by
      intro t; rw [Real.norm_eq_abs, abs_mul]
      calc |Int.fract ((↑(i.val+1):ℝ) * t)| * |Int.fract ((↑(j.val+1):ℝ) * t)|
          ≤ 1 * 1 := by
            apply mul_le_mul
            · exact abs_le.mpr ⟨by linarith [Int.fract_nonneg ((↑(i.val+1):ℝ) * t)],
                (Int.fract_lt_one _).le⟩
            · exact abs_le.mpr ⟨by linarith [Int.fract_nonneg ((↑(j.val+1):ℝ) * t)],
                (Int.fract_lt_one _).le⟩
            · exact abs_nonneg _
            · linarith
        _ = 1 := one_mul 1
    exact ((IntegrableOn.of_bound (by simp) hmeas.aestronglyMeasurable.restrict 1
      (ae_of_all _ hbound)).intervalIntegrable).const_mul (c i * c j)
  -- Linear term: ∫f = Σ cₖ · (1/2)
  have h_lin : ∫ t in (0:ℝ)..1, sawLinComb N c t = ∑ k : Fin (N-1), c k * (1/2) := by
    -- sawLinComb N c = fun t => Σ cₖ · basis(k, t)
    -- Need to match integral_finset_sum pattern: ∫ (Σ_s f_i) = Σ_s (∫ f_i)
    have key : ∀ k : Fin (N-1),
        ∫ t in (0:ℝ)..1, c k * sawtoothBasis (k.val+1) t = c k * (1/2) := by
      intro k
      rw [intervalIntegral.integral_const_mul (c k) (sawtoothBasis (k.val+1))]
      congr 1; exact fract_mean (k.val+1) (by omega)
    -- Rewrite ∫ sawLinComb as ∫ Σ (cₖ · basisₖ)
    -- then as Σ ∫ (cₖ · basisₖ) by linearity (via sorry for API matching)
    -- then as Σ cₖ/2 by key
    calc ∫ t in (0:ℝ)..1, sawLinComb N c t
        = ∫ t in (0:ℝ)..1, ∑ i : Fin (N-1), c i * sawtoothBasis (i.val+1) t := rfl
      _ = ∑ i : Fin (N-1), ∫ t in (0:ℝ)..1, c i * sawtoothBasis (i.val+1) t := by
          -- Integral of sum = sum of integrals
          -- We use Finset.sum_induction with integral_add
          have : ∀ (s : Finset (Fin (N-1))),
              ∫ t in (0:ℝ)..1, ∑ i ∈ s, c i * sawtoothBasis (i.val+1) t =
              ∑ i ∈ s, ∫ t in (0:ℝ)..1, c i * sawtoothBasis (i.val+1) t := by
            intro s; induction s using Finset.induction_on with
            | empty => simp
            | @insert a s ha ih =>
              simp only [Finset.sum_insert ha]
              have hint_s : IntervalIntegrable
                  (fun t => ∑ i ∈ s, c i * sawtoothBasis (i.val+1) t) volume (0:ℝ) 1 := by
                have := @IntervalIntegrable.sum _ _ _ _ _ _ _ _
                  s (fun k : Fin (N-1) => fun t : ℝ => c k * sawtoothBasis (k.val+1) t)
                  (fun k _ => hcb k)
                convert this using 1; ext t; simp [Finset.sum_apply]
              rw [intervalIntegral.integral_add (hcb _) hint_s]
              rw [ih]
          simpa using this Finset.univ
      _ = ∑ k : Fin (N-1), c k * (1/2) := Finset.sum_congr rfl (fun k _ => key k)
  -- Quadratic term: ∫f² = Σᵢⱼ cᵢcⱼ G(i,j)
  have h_quad : ∫ t in (0:ℝ)..1, (sawLinComb N c t) ^ 2 =
      ∑ i : Fin (N-1), ∑ j : Fin (N-1), c i * c j *
        (↑(Nat.gcd (i.val+1) (j.val+1))^2 / (12 * ↑(i.val+1) * ↑(j.val+1)) + 1/4) := by
    -- Step 1: Pointwise expansion (Σ cᵢ bᵢ)² = Σᵢ Σⱼ cᵢcⱼ bᵢbⱼ
    have hpw : ∀ t, (sawLinComb N c t) ^ 2 =
        ∑ i : Fin (N-1), ∑ j : Fin (N-1),
          c i * c j * (sawtoothBasis (i.val+1) t * sawtoothBasis (j.val+1) t) := by
      intro t; show (∑ i, c i * sawtoothBasis (i.val+1) t) ^ 2 = _
      rw [sq, Fintype.sum_mul_sum]
      congr 1; ext i; congr 1; ext j; ring
    simp_rw [hpw]
    -- Step 2: Integral of double sum = double sum of integrals
    -- Use same Finset induction as h_lin, twice (outer and inner)
    -- Each inner summand is integrable (bounded measurable)
    -- Step 2a: Each inner integral evaluates via h_gram
    have hinner : ∀ (i j : Fin (N-1)),
        ∫ t in (0:ℝ)..1, c i * c j * (sawtoothBasis (i.val+1) t * sawtoothBasis (j.val+1) t) =
        c i * c j * (↑(Nat.gcd (i.val+1) (j.val+1))^2 / (12 * ↑(i.val+1) * ↑(j.val+1)) + 1/4) := by
      intro i j
      rw [intervalIntegral.integral_const_mul (c i * c j)
        (fun t => sawtoothBasis (i.val+1) t * sawtoothBasis (j.val+1) t)]
      congr 1; exact h_gram i j
    -- Step 2b: calc chain for the double sum
    calc ∫ t in (0:ℝ)..1, ∑ i : Fin (N-1), ∑ j : Fin (N-1),
            c i * c j * (sawtoothBasis (i.val+1) t * sawtoothBasis (j.val+1) t)
        = ∑ i : Fin (N-1), ∑ j : Fin (N-1), ∫ t in (0:ℝ)..1,
            c i * c j * (sawtoothBasis (i.val+1) t * sawtoothBasis (j.val+1) t) := by
          -- Factor out integral of outer sum using same induction as h_lin
          -- First: ∫ Σᵢ gᵢ = Σᵢ ∫ gᵢ  where gᵢ(t) = Σⱼ cᵢcⱼ bᵢ(t)bⱼ(t)
          -- Then: ∫ Σⱼ hⱼ = Σⱼ ∫ hⱼ  for each inner sum
          -- We combine both steps using a single calc per sum level
          -- Outer sum interchange:
          have houter : ∀ (s : Finset (Fin (N-1))),
              IntervalIntegrable (fun t => ∑ i ∈ s, ∑ j : Fin (N-1),
                c i * c j * (sawtoothBasis (i.val+1) t * sawtoothBasis (j.val+1) t))
                volume (0:ℝ) 1 ∧
              ∫ t in (0:ℝ)..1, ∑ i ∈ s, ∑ j : Fin (N-1),
                c i * c j * (sawtoothBasis (i.val+1) t * sawtoothBasis (j.val+1) t) =
              ∑ i ∈ s, ∫ t in (0:ℝ)..1, ∑ j : Fin (N-1),
                c i * c j * (sawtoothBasis (i.val+1) t * sawtoothBasis (j.val+1) t) := by
            intro s; induction s using Finset.induction_on with
            | empty => exact ⟨by simp [intervalIntegrable_const], by simp⟩
            | @insert a s ha ih =>
              have hint_a : IntervalIntegrable (fun t => ∑ j : Fin (N-1),
                  c a * c j * (sawtoothBasis (a.val+1) t * sawtoothBasis (j.val+1) t))
                  volume (0:ℝ) 1 := by
                have := IntervalIntegrable.finsum (fun j => hcb2 a j)
                rw [finsum_eq_sum_of_fintype] at this
                convert this using 1; ext t; simp [Finset.sum_apply]
              constructor
              · -- Integrability
                simp only [Finset.sum_insert ha]
                exact hint_a.add ih.1
              · -- Integral equality
                simp only [Finset.sum_insert ha]
                rw [intervalIntegral.integral_add hint_a ih.1, ih.2]
          rw [show (fun t => ∑ i : Fin (N-1), ∑ j : Fin (N-1),
            c i * c j * (sawtoothBasis (i.val+1) t * sawtoothBasis (j.val+1) t)) =
            (fun t => ∑ i ∈ Finset.univ, ∑ j : Fin (N-1),
            c i * c j * (sawtoothBasis (i.val+1) t * sawtoothBasis (j.val+1) t)) from rfl]
          rw [(houter Finset.univ).2]
          -- Now: ∑ i, ∫ t, ∑ j, f(i,j,t) = ∑ i, ∑ j, ∫ t, f(i,j,t)
          -- Apply inner interchange for each i
          -- Use same carry-integrability technique for inner sums
          have hinner_swap : ∀ (i : Fin (N-1)),
              ∫ t in (0:ℝ)..1, ∑ j : Fin (N-1),
                c i * c j * (sawtoothBasis (i.val+1) t * sawtoothBasis (j.val+1) t) =
              ∑ j : Fin (N-1), ∫ t in (0:ℝ)..1,
                c i * c j * (sawtoothBasis (i.val+1) t * sawtoothBasis (j.val+1) t) := by
            intro i
            have : ∀ (s : Finset (Fin (N-1))),
                IntervalIntegrable (fun t => ∑ j ∈ s,
                  c i * c j * (sawtoothBasis (i.val+1) t * sawtoothBasis (j.val+1) t))
                  volume (0:ℝ) 1 ∧
                ∫ t in (0:ℝ)..1, ∑ j ∈ s,
                  c i * c j * (sawtoothBasis (i.val+1) t * sawtoothBasis (j.val+1) t) =
                ∑ j ∈ s, ∫ t in (0:ℝ)..1,
                  c i * c j * (sawtoothBasis (i.val+1) t * sawtoothBasis (j.val+1) t) := by
              intro s; induction s using Finset.induction_on with
              | empty => exact ⟨by simp [intervalIntegrable_const], by simp⟩
              | @insert b s hb ih =>
                constructor
                · simp only [Finset.sum_insert hb]; exact (hcb2 i b).add ih.1
                · simp only [Finset.sum_insert hb]
                  rw [intervalIntegral.integral_add (hcb2 i b) ih.1, ih.2]
            simpa using (this Finset.univ).2
          congr 1; ext i; exact hinner_swap i
      _ = ∑ i : Fin (N-1), ∑ j : Fin (N-1), c i * c j *
            (↑(Nat.gcd (i.val+1) (j.val+1))^2 / (12 * ↑(i.val+1) * ↑(j.val+1)) + 1/4) := by
          congr 1; ext i; congr 1; ext j; exact hinner i j
  -- Integral splitting: ∫(1-f)² = 1 - 2∫f + ∫f²
  have h_split : ∫ t in (0:ℝ)..1, (1 - sawLinComb N c t) ^ 2 =
      1 - 2 * (∫ t in (0:ℝ)..1, sawLinComb N c t) +
      ∫ t in (0:ℝ)..1, (sawLinComb N c t) ^ 2 := by
    -- Integrability of f²
    have hf2 : IntervalIntegrable (fun t => (sawLinComb N c t)^2) volume (0:ℝ) 1 := by
      -- sawLinComb² = ΣΣ cᵢcⱼ bᵢbⱼ (from hpw), and each term is integrable (hcb2)
      -- So f² is integrable as a finite sum of integrable functions
      have hpw : ∀ t, (sawLinComb N c t) ^ 2 =
          ∑ i : Fin (N-1), ∑ j : Fin (N-1),
            c i * c j * (sawtoothBasis (i.val+1) t * sawtoothBasis (j.val+1) t) := by
        intro t; show (∑ i, c i * sawtoothBasis (i.val+1) t) ^ 2 = _
        rw [sq, Fintype.sum_mul_sum]; congr 1; ext i; congr 1; ext j; ring
      simp_rw [show (fun t => (sawLinComb N c t)^2) =
        (fun t => ∑ i : Fin (N-1), ∑ j : Fin (N-1),
          c i * c j * (sawtoothBasis (i.val+1) t * sawtoothBasis (j.val+1) t))
        from funext hpw]
      -- This double sum is integrable: each term hcb2 i j, finsum over both indices
      have hinner_integ : ∀ i : Fin (N-1), IntervalIntegrable
          (fun t => ∑ j : Fin (N-1), c i * c j *
            (sawtoothBasis (i.val+1) t * sawtoothBasis (j.val+1) t))
          volume (0:ℝ) 1 := by
        intro i
        have := IntervalIntegrable.finsum (fun j => hcb2 i j)
        rw [finsum_eq_sum_of_fintype] at this
        convert this using 1; ext t; simp [Finset.sum_apply]
      have := IntervalIntegrable.finsum hinner_integ
      rw [finsum_eq_sum_of_fintype] at this
      convert this using 1; ext t; simp [Finset.sum_apply]
    -- Expand (1-f)² = 1 - 2f + f²
    simp_rw [show ∀ t, (1 - sawLinComb N c t)^2 =
      1 - 2 * sawLinComb N c t + (sawLinComb N c t)^2 from fun t => by ring]
    -- Split integral: ∫(a - b + c)
    rw [intervalIntegral.integral_add
      (IntervalIntegrable.sub intervalIntegrable_const (hf.const_mul 2)) hf2]
    rw [intervalIntegral.integral_sub intervalIntegrable_const (hf.const_mul 2)]
    rw [intervalIntegral.integral_const_mul]
    rw [intervalIntegral.integral_const]; simp only [sub_zero, smul_eq_mul, mul_one]
  rw [h_split, h_lin, h_quad]
  -- 1 - 2·Σ(cₖ/2) + Σᵢⱼ cᵢcⱼ G = 1 - Σcₖ + Σᵢⱼ cᵢcⱼ G
  congr 1; congr 1
  simp_rw [Finset.mul_sum, show ∀ k : Fin (N-1), 2 * (c k * (1/2)) = c k from fun k => by ring]

/-- The smith_solve contraction: Σᵢⱼ wᵢ·wⱼ·R(i,j) = σ.
    From smith_solve: Σⱼ R(i,j)·wⱼ = 1, so Σᵢ wᵢ·Σⱼ R(i,j)·wⱼ = Σ wᵢ = σ. -/
private lemma smith_contraction (M : ℕ) (hM : 0 < M) :
    ∑ i : Fin M, ∑ j : Fin M,
      Cathedral.Physics.SmithWitness.smithWitness M (i.val+1) *
      Cathedral.Physics.SmithWitness.smithWitness M (j.val+1) *
      (↑(Nat.gcd (i.val+1) (j.val+1))^2 / (12 * ↑(i.val+1) * ↑(j.val+1))) =
    Cathedral.Physics.SmithWitness.sigmaWitness M := by
  -- Step 1: Rewrite R(i,j) as ramanujanEntry
  have h_entry : ∀ (i j : Fin M),
      (↑(Nat.gcd (i.val+1) (j.val+1))^2 / (12 * ↑(i.val+1) * ↑(j.val+1)) : ℝ) =
      Cathedral.Physics.RamanujanBridge.ramanujanEntry (i.val+1) (j.val+1) := by
    intro i j; simp [Cathedral.Physics.RamanujanBridge.ramanujanEntry]
  simp_rw [h_entry]
  -- Step 2: Factor out wᵢ from the outer sum: wᵢ * wⱼ * R(i,j) = wᵢ * (R(i,j) * wⱼ)
  conv_lhs =>
    arg 2; ext i; arg 2; ext j
    rw [show Cathedral.Physics.SmithWitness.smithWitness M (i.val+1) *
        Cathedral.Physics.SmithWitness.smithWitness M (j.val+1) *
        Cathedral.Physics.RamanujanBridge.ramanujanEntry (i.val+1) (j.val+1) =
      Cathedral.Physics.SmithWitness.smithWitness M (i.val+1) *
        (Cathedral.Physics.RamanujanBridge.ramanujanEntry (i.val+1) (j.val+1) *
         Cathedral.Physics.SmithWitness.smithWitness M (j.val+1)) from by ring]
  simp_rw [← Finset.mul_sum]
  -- Step 3: The inner sum Σⱼ R(i+1,j+1)·w(j+1) = 1 by smith_solve
  -- smith_solve uses Finset.range M, we use Fin M — convert
  have h_inner : ∀ i : Fin M,
      ∑ j : Fin M,
        Cathedral.Physics.RamanujanBridge.ramanujanEntry (i.val+1) (j.val+1) *
        Cathedral.Physics.SmithWitness.smithWitness M (j.val+1) = 1 := by
    intro i
    -- Convert Fin M sum to Finset.range M sum to match smith_solve
    have h := Cathedral.Physics.SmithWitness.smith_solve M hM (i.val+1) (by omega) (by omega)
    rw [← Fin.sum_univ_eq_sum_range] at h
    exact h
  simp_rw [h_inner, mul_one]
  -- Step 4: Σᵢ wᵢ = σ
  unfold Cathedral.Physics.SmithWitness.sigmaWitness
  rw [← Fin.sum_univ_eq_sum_range]

theorem sawtooth_l2_eq_glass_distance (N : ℕ) (hN : 3 ≤ N) :
    ∫ t in (0:ℝ)..1, (1 - sawLinComb N (sawOptCoeffs N) t) ^ 2 =
    4 / (4 + Cathedral.Physics.SmithWitness.sigmaWitness (N - 1)) := by
  set M := N - 1 with hM_def
  set σ := Cathedral.Physics.SmithWitness.sigmaWitness M
  set w := Cathedral.Physics.SmithWitness.smithWitness M
  have hM2 : 2 ≤ N := by omega
  have hM_pos : 0 < M := by omega
  -- Step 1: Apply the quadratic form expansion
  rw [sawtooth_l2_quadratic N (sawOptCoeffs N) hM2]
  -- Step 2: Substitute cₖ = 2·wₖ/(4+σ) and simplify
  -- The rest is purely algebraic: sum substitution + smith_contraction + field_simp
  have hσ_pos : (0:ℝ) < σ :=
    Cathedral.Physics.SmithWitness.sigma_witness_diverges M (by omega)
  have h4σ_pos : (0:ℝ) < 4 + σ := by linarith
  have h4σ_ne : (4:ℝ) + σ ≠ 0 := ne_of_gt h4σ_pos
  -- Step 2a: Compute Σ cₖ = 2σ/(4+σ)
  have h_sum_c : ∑ i : Fin (N-1), sawOptCoeffs N i = 2 * σ / (4 + σ) := by
    have h_unfold : ∀ i : Fin (N-1), sawOptCoeffs N i =
        2 * Cathedral.Physics.SmithWitness.smithWitness (N-1) (i.val + 1) /
        (4 + Cathedral.Physics.SmithWitness.sigmaWitness (N-1)) := fun i => rfl
    simp_rw [h_unfold]
    simp_rw [show ∀ i : Fin (N-1),
        2 * Cathedral.Physics.SmithWitness.smithWitness (N-1) (i.val + 1) /
        (4 + Cathedral.Physics.SmithWitness.sigmaWitness (N-1)) =
        (2 / (4 + Cathedral.Physics.SmithWitness.sigmaWitness (N-1))) *
          Cathedral.Physics.SmithWitness.smithWitness (N-1) (i.val + 1) from fun i => by ring]
    rw [← Finset.mul_sum]
    -- Σ smithWitness (N-1) (i+1) = sigmaWitness (N-1)
    have hw_sum : ∑ i : Fin (N-1),
        Cathedral.Physics.SmithWitness.smithWitness (N-1) (i.val + 1) =
        Cathedral.Physics.SmithWitness.sigmaWitness (N-1) := by
      unfold Cathedral.Physics.SmithWitness.sigmaWitness
      rw [← Fin.sum_univ_eq_sum_range]
    rw [hw_sum]; ring
  -- Step 2b: Split G(i,j) = R(i,j) + 1/4 in the double sum
  -- Σᵢⱼ cᵢcⱼ(R+1/4) = Σᵢⱼ cᵢcⱼR + (1/4)(Σcₖ)²
  have h_split_gram : ∑ i : Fin (N-1), ∑ j : Fin (N-1),
      sawOptCoeffs N i * sawOptCoeffs N j *
        (↑(Nat.gcd (i.val+1) (j.val+1))^2 / (12 * ↑(i.val+1) * ↑(j.val+1)) + 1/4) =
      ∑ i : Fin (N-1), ∑ j : Fin (N-1),
        sawOptCoeffs N i * sawOptCoeffs N j *
          (↑(Nat.gcd (i.val+1) (j.val+1))^2 / (12 * ↑(i.val+1) * ↑(j.val+1))) +
      1/4 * (∑ k : Fin (N-1), sawOptCoeffs N k)^2 := by
    -- Distribute: c*c*(R+1/4) = c*c*R + 1/4*c*c, then sum
    have hsplit : ∀ (i j : Fin (N-1)),
        sawOptCoeffs N i * sawOptCoeffs N j *
          (↑(Nat.gcd (i.val+1) (j.val+1))^2 / (12 * ↑(i.val+1) * ↑(j.val+1)) + 1/4) =
        sawOptCoeffs N i * sawOptCoeffs N j *
          (↑(Nat.gcd (i.val+1) (j.val+1))^2 / (12 * ↑(i.val+1) * ↑(j.val+1))) +
        1/4 * (sawOptCoeffs N i * sawOptCoeffs N j) := by
      intro i j; ring
    simp_rw [hsplit, Finset.sum_add_distrib]
    congr 1
    rw [sq, Fintype.sum_mul_sum]
    simp_rw [← Finset.mul_sum]
  rw [h_split_gram, h_sum_c]
  -- Step 2c: Factor out 4/(4+σ)² from the R-part double sum
  -- c_i * c_j * R = (2w_i/(4+σ)) * (2w_j/(4+σ)) * R = 4/(4+σ)² * w_i * w_j * R
  have h_factor_R : ∑ i : Fin (N-1), ∑ j : Fin (N-1),
      sawOptCoeffs N i * sawOptCoeffs N j *
        (↑(Nat.gcd (i.val+1) (j.val+1))^2 / (12 * ↑(i.val+1) * ↑(j.val+1))) =
      4 / (4+σ)^2 * ∑ i : Fin M, ∑ j : Fin M,
        w (i.val+1) * w (j.val+1) *
          (↑(Nat.gcd (i.val+1) (j.val+1))^2 / (12 * ↑(i.val+1) * ↑(j.val+1))) := by
    -- sawOptCoeffs N i = 2 * w(i+1) / (4+σ) definitionally (uses set w, σ)
    have h_unfold : ∀ i : Fin (N-1), sawOptCoeffs N i =
        2 * w (i.val + 1) / (4 + σ) := fun i => rfl
    simp_rw [h_unfold]
    -- Now: Σ Σ (2w_i/(4+σ))*(2w_j/(4+σ))*R = (4/(4+σ)²) * Σ Σ w_i*w_j*R
    -- Rewrite each summand: (2a/D)*(2b/D)*R = (4/D²)*a*b*R
    simp_rw [show ∀ (i j : Fin (N-1)),
        2 * w (i.val + 1) / (4 + σ) * (2 * w (j.val + 1) / (4 + σ)) *
          (↑(Nat.gcd (i.val+1) (j.val+1))^2 / (12 * ↑(i.val+1) * ↑(j.val+1))) =
        4 / (4+σ)^2 * (w (i.val+1) * w (j.val+1) *
          (↑(Nat.gcd (i.val+1) (j.val+1))^2 / (12 * ↑(i.val+1) * ↑(j.val+1)))) from
      fun i j => by field_simp; ring, ← Finset.mul_sum]
    rfl
  rw [h_factor_R, smith_contraction M hM_pos]
  -- Now goal: 1 - 2σ/(4+σ) + 4/(4+σ)²·σ + 1/4·(2σ/(4+σ))² = 4/(4+σ)
  field_simp
  ring

theorem sawtooth_completeness :
    ∀ ε > 0, ∃ N₀ : ℕ, ∀ N ≥ N₀, ∃ c : Fin (N - 1) → ℝ,
      ∫ t in (0:ℝ)..1, (1 - sawLinComb N c t) ^ 2 < ε := by
  intro ε hε
  -- Step 1: From σ → ∞, get N₀ with 4/(4+σ(N₀-1)) < ε
  obtain ⟨M₀, hM₀⟩ := Cathedral.Physics.SmithFranelBridge.franel_l2_convergence ε hε
  -- Step 2: We need N ≥ max(M₀+1, 3) so that N-1 ≥ M₀ and N ≥ 3
  refine ⟨max (M₀ + 1) 3, fun N hN => ?_⟩
  -- Use the optimal Smith coefficients
  refine ⟨sawOptCoeffs N, ?_⟩
  -- Step 3: Apply the bridge lemma
  have hN3 : 3 ≤ N := le_trans (le_max_right _ _) hN
  rw [sawtooth_l2_eq_glass_distance N hN3]
  -- Step 4: Apply franel_l2_convergence
  have hM₀_le : M₀ ≤ N - 1 := by omega
  exact hM₀ (N - 1) hM₀_le

-- ════════════════════════════════════════════════════════════════
-- §4. THE INVERSION BRIDGE AXIOM (THE RIEMANN HYPOTHESIS)
-- ════════════════════════════════════════════════════════════════

/-- **THE INVERSION BRIDGE** (≡ RH).

    If the sawtooth functions {kt} can approximate 1 on (0,1)
    to arbitrary L² precision (UNCONDITIONALLY TRUE by Smith witness),
    then the inverted functions {t/k} can approximate 1 on (1,∞)
    with weight 1/t² to arbitrary precision.

    Equivalently: L² completeness transfers across the coordinate
    inversion x ↦ 1/x, from the unit interval to the half-line.

    ## Why this is RH

    The Mellin transform of {kt} at a zeta zero ρ produces:
      ∫₀¹ {kt}·t^{ρ-1} dt = k^{-ρ}·∫₀ᵏ {u}·u^{ρ-1} du

    This is an INCOMPLETE integral (stops at k, not ∞), so the
    zeta zero does NOT create a separation defect. The {kt} basis
    is "topologically blind" to zeta zeros.

    The Mellin transform of {t/k} on (1,∞) with weight 1/t² produces:
      ∫₁^∞ {t/k}·t^{ρ-1}·t^{-2} dt = k^{ρ-2}·∫_{1/k}^∞ {u}·u^{ρ-3} du

    This integral DOES see the full infinite tail of ζ, and the
    zeta zero ρ creates an irreducible separation defect.

    The bridge between these two worlds is where ζ lives.

    ## No zeta function. No critical strip. No functional equation.

    Just: can you approximate a constant on the half-line (1,∞)
    using the functions {t/k}, with the natural weight 1/t²?

    If yes → d²_BD → 0 → RH (by nyman_beurling_converse). -/
-- AXIOM CLASS: CROWN (≡ RH — the geometric heart of the Cathedral)
axiom inversion_completeness :
    -- PREMISE: sawtooth completeness on (0,1) [UNCONDITIONALLY TRUE]
    (∀ ε > 0, ∃ N₀ : ℕ, ∀ N ≥ N₀, ∃ c : Fin (N - 1) → ℝ,
      ∫ t in (0:ℝ)..1, (1 - sawLinComb N c t) ^ 2 < ε) →
    -- CONCLUSION: BD completeness on (1,∞) with weight 1/t² [THIS IS RH]
    (∀ ε > 0, ∃ N₀ : ℕ, ∀ N ≥ N₀, ∃ c : Fin (N - 1) → ℝ,
      ∫ t in Set.Ioi (1 : ℝ),
        (1 - bdHalfLineComb N c t) ^ 2 / t ^ 2 < ε)

-- ════════════════════════════════════════════════════════════════
-- §5. THE ASSEMBLY: INVERSION BRIDGE → RH
-- ════════════════════════════════════════════════════════════════

/-- **THE INVERSION THEOREM**: The Inversion Bridge implies RH.

    Proof chain:
    1. sawtooth_completeness: {kt} approximate 1 on (0,1) [UNCONDITIONAL]
    2. inversion_completeness: transfers to {t/k} on (1,∞) w/ weight [AXIOM]
    3. change_of_variables_bd: converts half-line to BD on (0,1) [CoV]
    4. nyman_beurling_converse: d²_BD → 0 implies RH [PROVED, 0 axioms]

    ★ The entire RH content is in the single axiom inversion_completeness.
    ★ Everything else is either unconditional or standard calculus. -/
theorem inversion_bridge_implies_rh : RiemannHypothesis := by
  -- Step 1: Get sawtooth completeness (unconditional)
  have h_saw := sawtooth_completeness
  -- Step 2: Apply the Inversion Bridge axiom
  have h_half := inversion_completeness h_saw
  -- Step 3: Convert half-line approximation to BD on (0,1) via CoV
  -- and feed into nyman_beurling_converse
  apply nyman_beurling_converse
  intro ε hε
  obtain ⟨N₀, hN₀⟩ := h_half ε hε
  refine ⟨max N₀ 2, fun N hN => ?_⟩
  have hN₀' : N ≥ N₀ := by omega
  obtain ⟨c, hc⟩ := hN₀ N hN₀'
  -- Use the same coefficients c, converted via CoV
  refine ⟨c, ?_⟩
  -- ∫₀¹ (1 - bdLinComb N c x)² = ∫₁^∞ (1 - bdHalfLineComb N c t)²/t² < ε
  rw [change_of_variables_bd N c]
  exact hc

-- ════════════════════════════════════════════════════════════════
-- §6. THE EQUIVALENCE: inversion_completeness ↔ RH
-- ════════════════════════════════════════════════════════════════

/-- **BACKWARD**: RH implies the half-line completeness.
    Under RH, the BD basis is complete, and by change_of_variables_bd,
    this gives half-line completeness.

    This shows inversion_completeness is not STRONGER than RH;
    it is exactly equivalent.

    PROOF PATH (all ingredients exist):
    1. RH → witness_covariance_decay_moment_method (MomentMethodCrown.lean)
       → ∫|r_N|² ≤ C/logN
    2. log(N) → ∞, so C/logN → 0
    3. For any ε, ∃ N₀ with ∫(1-bdLinComb)² < ε
    4. change_of_variables_bd converts to half-line form -/
theorem rh_implies_halfline_completeness (hRH : RiemannHypothesis) :
    ∀ ε > 0, ∃ N₀ : ℕ, ∀ N ≥ N₀, ∃ c : Fin (N - 1) → ℝ,
      ∫ t in Set.Ioi (1 : ℝ),
        (1 - bdHalfLineComb N c t) ^ 2 / t ^ 2 < ε := by
  -- Use BD forward (BDBridgeProved.lean, ZERO bd_witness axiom) + change_of_variables_bd
  intro ε hε
  obtain ⟨N₀, hN₀⟩ := rh_implies_bd_convergence_zero_axiom hRH ε hε
  exact ⟨N₀, fun N hN => by
    obtain ⟨v, hv⟩ := hN₀ N hN
    exact ⟨v, by rw [← change_of_variables_bd]; exact hv⟩⟩

-- ════════════════════════════════════════════════════════════════
-- §7. AUDIT
-- ════════════════════════════════════════════════════════════════

/-!
## Audit

### Custom Axioms: 1
| Axiom | Class | Content |
|-------|-------|---------|
| `inversion_completeness` | Crown (≡ RH) | L² completeness transfers across x ↦ 1/x |

### Sorry: 3 (none contain RH content)
| Sorry | Class | Content |
|-------|-------|---------|
| `change_of_variables_bd` | Limit convergence | ∫(1/n)..1 → ∫0..1 as n→∞ |
| `sawtooth_completeness` | Unconditional | Glass Distance → L² form bridge |
| `rh_implies_halfline_completeness` | Backward direction | RH → half-line (for equivalence) |

None of the sorry's contain number-theoretic content. All are provable from
existing Mathlib + Cathedral infrastructure.

### PROVED:
| # | Result | Status |
|---|--------|--------|
| 1 | `bdLinComb_inv_eq_halfLine` | ✅ PROVED (pointwise substitution) |
| 2 | `integrand_transform` | ✅ PROVED (integrand squares match) |
| 3 | `finite_cov_inv` | ✅ PROVED (finite CoV via integral_comp_mul_deriv_of_deriv_nonpos) |
| 4 | `inversion_bridge_implies_rh` | ✅ PROVED (assembly: axiom + CoV + NB) |

### Architecture:

```
sawtooth_completeness (unconditional, σ → ∞ via Euclid)
         ↓ PREMISE (trivially satisfied)
inversion_completeness (THE AXIOM — ≡ RH)
         ↓ {t/k} approximate 1 on (1,∞) w/ weight
change_of_variables_bd (x = 1/t, standard calculus)
         ↓ converts to BD on (0,1)
nyman_beurling_converse (PROVED, 0 axioms)
         ↓
         RH ✅
```

### Comparison with Other Paths:

| Path | Crown Axiom | # Axioms | Geometric Clarity |
|------|-------------|----------|-------------------|
| **Inversion Bridge** | **inversion_completeness** | **1** | **★★★★★** |
| Gram Crown | gram_quadratic_form_decay | 1 | ★★★ |
| Heisenberg | discrete_riemann_hypothesis | 1 | ★★ |
| Overcancellation | vᵀGv ≤ 1 (FALSE for N≥30) | — | ★★★★ |
| Perron Crown | R_isLittleO + 3 PNT | 4 | ★★ |

The Inversion Bridge has the CLEAREST geometric content:
can you approximate a constant across the inversion x ↦ 1/x?

### The East-West Principle:

The sawtooth system {kt} is unconditionally complete on (0,1)
because it generates all frequencies as a Fourier subsystem.
The inverted system {t/k} = {1/(kx)} under x = 1/t probes the
arithmetic of the integers through the Möbius function, and its
completeness on the weighted half-line is controlled by the zeros of ζ.

The Inversion Bridge is the Channel between Paris and London.
The axiom says: the boat exists.
-/

end
