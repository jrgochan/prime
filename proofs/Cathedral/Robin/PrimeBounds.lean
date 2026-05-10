/-
  Cathedral/Robin/PrimeBounds.lean

  ## Prime Power Bounds & Lagarias for All Primes — PROVED
-/

import Cathedral.Robin.Defs
import Cathedral.Robin.SigmaProps
import Cathedral.Robin.HarmonicBounds
import Mathlib.Analysis.SpecialFunctions.ExpDeriv
import Mathlib.Analysis.SpecialFunctions.Log.Basic
import Mathlib.Data.Nat.Prime.Basic

open Real ArithmeticFunction

-- ════════════════════════════════════════════════
-- PART I: GEOMETRIC SUM BOUND
-- ════════════════════════════════════════════════

lemma geom_sum_le_two_pow (P : ℝ) (hP : 2 ≤ P) (k : ℕ) :
    ∑ j ∈ Finset.range (k + 1), P ^ j ≤ 2 * P ^ k := by
  induction k with
  | zero => simp [pow_zero, mul_one]
  | succ k ih =>
    rw [Finset.sum_range_succ]
    calc ∑ j ∈ Finset.range (k + 1), P ^ j + P ^ (k + 1)
      _ ≤ 2 * P ^ k + P ^ (k + 1) := by linarith
      _ ≤ P * P ^ k + P ^ (k + 1) := by
          have : 2 * P ^ k ≤ P * P ^ k :=
            mul_le_mul_of_nonneg_right hP (by positivity)
          linarith
      _ = P ^ (k + 1) + P ^ (k + 1) := by ring_nf
      _ = 2 * P ^ (k + 1) := by ring

-- ════════════════════════════════════════════════
-- PART II: PRIME POWER SIGMA BOUND
-- ════════════════════════════════════════════════

theorem sigma_one_prime_pow_bound {p k : ℕ} (hp : p.Prime) (_hk : 1 ≤ k) :
    (sumOfDivisors (p ^ k) : ℝ) ≤ 2 * (p ^ k : ℝ) := by
  unfold sumOfDivisors
  have h_apply := sigma_one_apply_prime_pow (i := k) hp
  have h_cast : ((sigma 1) (p ^ k) : ℝ) = ∑ j ∈ Finset.range (k + 1), (p : ℝ) ^ j := by
    rw [h_apply]; push_cast; rfl
  rw [h_cast]
  exact geom_sum_le_two_pow (p : ℝ) (by exact_mod_cast hp.two_le) k

-- ════════════════════════════════════════════════
-- PART III: TAYLOR TRUNCATION BOUNDS
-- ════════════════════════════════════════════════

-- NOTE: We use the GramDiag.lean pattern for HasDerivAt proofs.
-- Key: `dsimp only [_root_.id]` (not `simp`) to resolve the
-- ArithmeticFunction.id vs _root_.id ambiguity.

lemma exp_lower_quadratic (x : ℝ) (hx : 0 ≤ x) : 1 + x + x^2/2 ≤ Real.exp x := by
  suffices h : 0 ≤ Real.exp x - (1 + x + x^2/2) by linarith
  set f : ℝ → ℝ := fun t => Real.exp t - (1 + t + t^2/2)
  have hf0 : f 0 = 0 := by
    show Real.exp 0 - (1 + 0 + 0 ^ 2 / 2) = 0; simp [Real.exp_zero]
  have hcont : ContinuousOn f (Set.Ici 0) := by
    show ContinuousOn (fun t => Real.exp t - (1 + t + t ^ 2 / 2)) (Set.Ici 0)
    exact ContinuousOn.sub continuous_exp.continuousOn
      (ContinuousOn.add (continuousOn_const.add continuousOn_id)
        ((continuous_pow 2).continuousOn.div_const 2))
  have hdiff : DifferentiableOn ℝ f (interior (Set.Ici (0:ℝ))) := by
    simp only [interior_Ici]
    show DifferentiableOn ℝ (fun t => Real.exp t - (1 + t + t ^ 2 / 2)) (Set.Ioi 0)
    intro t ht; simp only [Set.mem_Ioi] at ht
    apply DifferentiableAt.differentiableWithinAt
    exact differentiableAt_exp.sub
      ((differentiableAt_id.const_add 1).add ((differentiableAt_pow 2).div_const 2))
  have hderiv : ∀ t ∈ interior (Set.Ici (0:ℝ)), 0 ≤ deriv f t := by
    intro t ht; simp only [interior_Ici, Set.mem_Ioi] at ht
    have hdf : HasDerivAt f (Real.exp t - (1 + t)) t := by
      have hd1 := hasDerivAt_exp t
      have hd2 := (hasDerivAt_id t).const_add 1
      have hd3 := (hasDerivAt_pow 2 t).div_const 2
      refine (hd1.sub (hd2.add hd3)).congr_deriv ?_
      dsimp only [_root_.id]; ring
    rw [hdf.deriv]; linarith [Real.add_one_le_exp t]
  have hmono := monotoneOn_of_deriv_nonneg (convex_Ici 0) hcont hdiff hderiv
  have hfx : f 0 ≤ f x := hmono (Set.mem_Ici.mpr le_rfl) (Set.mem_Ici.mpr hx) hx
  rw [hf0] at hfx; exact hfx

lemma exp_lower_cubic (x : ℝ) (hx : 0 ≤ x) : 1 + x + x^2/2 + x^3/6 ≤ Real.exp x := by
  suffices h : 0 ≤ Real.exp x - (1 + x + x^2/2 + x^3/6) by linarith
  set f : ℝ → ℝ := fun t => Real.exp t - (1 + t + t^2/2 + t^3/6)
  have hf0 : f 0 = 0 := by
    show Real.exp 0 - (1 + 0 + 0 ^ 2 / 2 + 0 ^ 3 / 6) = 0; simp [Real.exp_zero]
  have hcont : ContinuousOn f (Set.Ici 0) := by
    show ContinuousOn (fun t => Real.exp t - (1 + t + t ^ 2 / 2 + t ^ 3 / 6)) (Set.Ici 0)
    exact ContinuousOn.sub continuous_exp.continuousOn
      (ContinuousOn.add (ContinuousOn.add (continuousOn_const.add continuousOn_id)
        ((continuous_pow 2).continuousOn.div_const 2))
        ((continuous_pow 3).continuousOn.div_const 6))
  have hdiff : DifferentiableOn ℝ f (interior (Set.Ici (0:ℝ))) := by
    simp only [interior_Ici]
    show DifferentiableOn ℝ (fun t => Real.exp t - (1 + t + t ^ 2 / 2 + t ^ 3 / 6)) (Set.Ioi 0)
    intro t ht; simp only [Set.mem_Ioi] at ht
    apply DifferentiableAt.differentiableWithinAt
    exact differentiableAt_exp.sub
      (((differentiableAt_id.const_add 1).add ((differentiableAt_pow 2).div_const 2)).add
        ((differentiableAt_pow 3).div_const 6))
  have hderiv : ∀ t ∈ interior (Set.Ici (0:ℝ)), 0 ≤ deriv f t := by
    intro t ht; simp only [interior_Ici, Set.mem_Ioi] at ht
    have hdf : HasDerivAt f (Real.exp t - (1 + t + t^2/2)) t := by
      have hd1 := hasDerivAt_exp t
      have hd2 := (hasDerivAt_id t).const_add 1
      have hd3 := (hasDerivAt_pow 2 t).div_const 2
      have hd4 := (hasDerivAt_pow 3 t).div_const 6
      refine (hd1.sub ((hd2.add hd3).add hd4)).congr_deriv ?_
      dsimp only [_root_.id]; ring
    rw [hdf.deriv]; linarith [exp_lower_quadratic t (le_of_lt ht)]
  have hmono := monotoneOn_of_deriv_nonneg (convex_Ici 0) hcont hdiff hderiv
  have hfx : f 0 ≤ f x := hmono (Set.mem_Ici.mpr le_rfl) (Set.mem_Ici.mpr hx) hx
  rw [hf0] at hfx; exact hfx

lemma exp_lower_quartic (x : ℝ) (hx : 0 ≤ x) :
    1 + x + x^2/2 + x^3/6 + x^4/24 ≤ Real.exp x := by
  suffices h : 0 ≤ Real.exp x - (1 + x + x^2/2 + x^3/6 + x^4/24) by linarith
  set f : ℝ → ℝ := fun t => Real.exp t - (1 + t + t^2/2 + t^3/6 + t^4/24)
  have hf0 : f 0 = 0 := by
    show Real.exp 0 - (1 + 0 + 0 ^ 2 / 2 + 0 ^ 3 / 6 + 0 ^ 4 / 24) = 0; simp [Real.exp_zero]
  have hcont : ContinuousOn f (Set.Ici 0) := by
    show ContinuousOn (fun t => Real.exp t - (1 + t + t ^ 2 / 2 + t ^ 3 / 6 + t ^ 4 / 24)) (Set.Ici 0)
    exact ContinuousOn.sub continuous_exp.continuousOn
      (ContinuousOn.add (ContinuousOn.add (ContinuousOn.add (continuousOn_const.add continuousOn_id)
        ((continuous_pow 2).continuousOn.div_const 2))
        ((continuous_pow 3).continuousOn.div_const 6))
        ((continuous_pow 4).continuousOn.div_const 24))
  have hdiff : DifferentiableOn ℝ f (interior (Set.Ici (0:ℝ))) := by
    simp only [interior_Ici]
    show DifferentiableOn ℝ (fun t => Real.exp t - (1 + t + t ^ 2 / 2 + t ^ 3 / 6 + t ^ 4 / 24)) (Set.Ioi 0)
    intro t ht; simp only [Set.mem_Ioi] at ht
    apply DifferentiableAt.differentiableWithinAt
    exact differentiableAt_exp.sub
      ((((differentiableAt_id.const_add 1).add ((differentiableAt_pow 2).div_const 2)).add
        ((differentiableAt_pow 3).div_const 6)).add
        ((differentiableAt_pow 4).div_const 24))
  have hderiv : ∀ t ∈ interior (Set.Ici (0:ℝ)), 0 ≤ deriv f t := by
    intro t ht; simp only [interior_Ici, Set.mem_Ioi] at ht
    have hdf : HasDerivAt f (Real.exp t - (1 + t + t^2/2 + t^3/6)) t := by
      have hd1 := hasDerivAt_exp t
      have hd2 := (hasDerivAt_id t).const_add 1
      have hd3 := (hasDerivAt_pow 2 t).div_const 2
      have hd4 := (hasDerivAt_pow 3 t).div_const 6
      have hd5 := (hasDerivAt_pow 4 t).div_const 24
      refine (hd1.sub (((hd2.add hd3).add hd4).add hd5)).congr_deriv ?_
      dsimp only [_root_.id]; ring
    rw [hdf.deriv]; linarith [exp_lower_cubic t (le_of_lt ht)]
  have hmono := monotoneOn_of_deriv_nonneg (convex_Ici 0) hcont hdiff hderiv
  have hfx : f 0 ≤ f x := hmono (Set.mem_Ici.mpr le_rfl) (Set.mem_Ici.mpr hx) hx
  rw [hf0] at hfx; exact hfx

lemma log_inv_le (x : ℝ) (hx : 0 < x) : 1 - x⁻¹ ≤ Real.log x := by
  have h1 : Real.log x⁻¹ ≤ x⁻¹ - 1 := Real.log_le_sub_one_of_pos (inv_pos.mpr hx)
  rw [Real.log_inv] at h1; linarith

-- ════════════════════════════════════════════════
-- PART IV: SMALL PRIME VERIFICATION
-- The lemmas are stated in terms of (↑p + 1) to match the master theorem
-- ════════════════════════════════════════════════

private lemma lagarias_p2 :
    (2 : ℝ) + 1 ≤ harmonicR 2 + Real.exp (harmonicR 2) * Real.log (harmonicR 2) := by
  unfold harmonicR
  have h_h : (harmonic 2 : ℝ) = 3/2 := by norm_num
  rw [h_h]
  have he : 67/16 ≤ Real.exp (3/2 : ℝ) := by
    have h1 := exp_lower_cubic (3/2 : ℝ) (by norm_num)
    linarith
  have hl : 77/192 ≤ Real.log (3/2 : ℝ) := by
    have h1 := log_lower_quartic (1/2 : ℝ) (by norm_num)
    have h3 : (1:ℝ) + 1/2 = 3/2 := by norm_num
    rw [h3] at h1; linarith
  nlinarith

private lemma lagarias_p3 :
    (3 : ℝ) + 1 ≤ harmonicR 3 + Real.exp (harmonicR 3) * Real.log (harmonicR 3) := by
  unfold harmonicR
  have h_h : (harmonic 3 : ℝ) = 11/6 := by norm_num
  rw [h_h]
  have he : 7181/1296 ≤ Real.exp (11/6 : ℝ) := by
    have h1 := exp_lower_cubic (11/6 : ℝ) (by norm_num)
    linarith
  have hl : 2895/5184 ≤ Real.log (11/6 : ℝ) := by
    have h1 := log_lower_quartic (5/6 : ℝ) (by norm_num)
    have h3 : (1:ℝ) + 5/6 = 11/6 := by norm_num
    rw [h3] at h1; linarith
  nlinarith

private lemma lagarias_p5 :
    (5 : ℝ) + 1 ≤ harmonicR 5 + Real.exp (harmonicR 5) * Real.log (harmonicR 5) := by
  unfold harmonicR
  have h_h : (harmonic 5 : ℝ) = 137/60 := by norm_num
  rw [h_h]
  have he : 9 ≤ Real.exp (137/60 : ℝ) := by
    have h1 := exp_lower_quartic (137/60 : ℝ) (by norm_num)
    linarith
  have hl : 77/137 ≤ Real.log (137/60 : ℝ) := by
    have h1 := log_inv_le (137/60 : ℝ) (by norm_num)
    have h2 : (1 : ℝ) - (137/60 : ℝ)⁻¹ = 77/137 := by norm_num
    linarith
  nlinarith

private lemma lagarias_p7 :
    (7 : ℝ) + 1 ≤ harmonicR 7 + Real.exp (harmonicR 7) * Real.log (harmonicR 7) := by
  unfold harmonicR
  have h_h : (harmonic 7 : ℝ) = 363/140 := by norm_num
  rw [h_h]
  have he : 117/10 ≤ Real.exp (363/140 : ℝ) := by
    have h1 := exp_lower_quartic (363/140 : ℝ) (by norm_num)
    linarith
  have hl : 223/363 ≤ Real.log (363/140 : ℝ) := by
    have h1 := log_inv_le (363/140 : ℝ) (by norm_num)
    have h2 : (1 : ℝ) - (363/140 : ℝ)⁻¹ = 223/363 := by norm_num
    linarith
  nlinarith

-- ════════════════════════════════════════════════
-- PART V: STRATEGIC BYPASS FOR p ≥ 11
-- ════════════════════════════════════════════════

private lemma log_two_ge : (2:ℝ) / 3 ≤ Real.log 2 := by
  have h43 := log_lower_quartic (1/3 : ℝ) (by norm_num)
  have h32 := log_lower_quartic (1/2 : ℝ) (by norm_num)
  have : (1:ℝ) + 1/3 = 4/3 := by norm_num
  rw [this] at h43
  have : (1:ℝ) + 1/2 = 3/2 := by norm_num
  rw [this] at h32
  have h1 : Real.log 2 = Real.log (4/3) + Real.log (3/2) := by
    rw [← Real.log_mul (by norm_num : (4:ℝ)/3 ≠ 0) (by norm_num : (3:ℝ)/2 ≠ 0)]
    norm_num
  linarith

private lemma log_three_ge_one : 1 ≤ Real.log 3 := by
  have h32 := log_lower_quartic (1/2 : ℝ) (by norm_num)
  have : (1:ℝ) + 1/2 = 3/2 := by norm_num
  rw [this] at h32
  have h1 : Real.log 3 = Real.log (3/2) + Real.log 2 := by
    rw [← Real.log_mul (by norm_num : (3:ℝ)/2 ≠ 0) (by norm_num : (2:ℝ) ≠ 0)]
    norm_num
  linarith [log_two_ge]

private lemma harmonicR_mono {m n : ℕ} (h : m ≤ n) : harmonicR m ≤ harmonicR n := by
  obtain ⟨k, rfl⟩ := Nat.exists_eq_add_of_le h
  induction k with
  | zero => simp
  | succ k ih =>
    have ihm : harmonicR m ≤ harmonicR (m + k) := ih (by omega)
    calc harmonicR m ≤ harmonicR (m + k) := ihm
      _ ≤ harmonicR (m + k + 1) := by
        unfold harmonicR
        simp only [Rat.cast_le]
        rw [harmonic_succ]
        exact le_add_of_nonneg_right (by positivity)

theorem exp_harmonicR_ge (n : ℕ) : (n : ℝ) + 1 ≤ Real.exp (harmonicR n) := by
  have h_lower := harmonicR_lower n
  have h_pos : (0 : ℝ) < (n : ℝ) + 1 := by positivity
  calc (n : ℝ) + 1
      = Real.exp (Real.log ((n : ℝ) + 1)) := by rw [Real.exp_log h_pos]
    _ ≤ Real.exp (harmonicR n) := by
        apply Real.exp_le_exp.mpr
        exact_mod_cast h_lower

private lemma harmonicR_11_ge_3 : 3 ≤ harmonicR 11 := by
  unfold harmonicR
  have h : (harmonic 11 : ℝ) = 83711 / 27720 := by norm_num
  rw [h]; norm_num

private lemma lagarias_ge_11 {p : ℕ} (hp : 11 ≤ p) :
    (p : ℝ) + 1 ≤ harmonicR p + Real.exp (harmonicR p) * Real.log (harmonicR p) := by
  have h_Hp_ge_3 : 3 ≤ harmonicR p := le_trans harmonicR_11_ge_3 (harmonicR_mono hp)
  have h_log_ge_1 : 1 ≤ Real.log (harmonicR p) :=
    le_trans log_three_ge_one (Real.log_le_log (by norm_num : (0:ℝ) < 3) h_Hp_ge_3)
  have h_exp_ge := exp_harmonicR_ge p
  calc (p : ℝ) + 1
      ≤ Real.exp (harmonicR p) := h_exp_ge
    _ = Real.exp (harmonicR p) * 1 := (mul_one _).symm
    _ ≤ Real.exp (harmonicR p) * Real.log (harmonicR p) :=
        mul_le_mul_of_nonneg_left h_log_ge_1 (le_of_lt (Real.exp_pos _))
    _ ≤ harmonicR p + Real.exp (harmonicR p) * Real.log (harmonicR p) := by
        linarith [show 0 ≤ harmonicR p from by linarith]

-- ════════════════════════════════════════════════
-- PART VI: THE MASTER THEOREM
-- ════════════════════════════════════════════════

/-- **THEOREM — PROVED**: Lagarias holds for ALL primes. -/
theorem lagarias_for_primes {p : ℕ} (hp : p.Prime) :
    (sumOfDivisors p : ℝ) ≤
      harmonicR p + Real.exp (harmonicR p) * Real.log (harmonicR p) := by
  -- σ(p) = p + 1
  rw [sigma_one_prime hp]; push_cast
  -- Now goal: (↑p + 1 : ℝ) ≤ ...
  by_cases h11 : 11 ≤ p
  · exact lagarias_ge_11 h11
  · have h11' : p < 11 := not_le.mp h11
    have hp2 := hp.two_le
    interval_cases p
    -- p = 2
    · exact lagarias_p2
    -- p = 3
    · exact lagarias_p3
    -- p = 4 (not prime)
    · revert hp; decide
    -- p = 5
    · exact lagarias_p5
    -- p = 6 (not prime)
    · revert hp; decide
    -- p = 7
    · exact lagarias_p7
    -- p = 8, 9, 10 (not prime)
    · revert hp; decide
    · revert hp; decide
    · revert hp; decide

-- ════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════

-- This file has:
--   PROVED
--   ZERO axioms
--   ALL PROVED:
--     ✅ geom_sum_le_two_pow           — Σ P^j ≤ 2·P^k
--     ✅ sigma_one_prime_pow_bound     — σ(p^k) ≤ 2p^k
--     ✅ exp_lower_{quadratic,cubic,quartic} — Taylor bounds
--     ✅ log_inv_le                    — log(x) ≥ 1 - 1/x
--     ✅ lagarias_p2, p3, p5, p7       — Small prime verification
--     ✅ log_two_ge, log_three_ge_one  — Logarithmic constants
--     ✅ harmonicR_mono                — H_m ≤ H_n for m ≤ n
--     ✅ exp_harmonicR_ge              — exp(H_n) ≥ n+1
--     ✅ harmonicR_11_ge_3             — H_11 ≥ 3
--     ✅ lagarias_ge_11                — Lagarias for p ≥ 11
--     ✅ lagarias_for_primes           — Lagarias for ALL primes!
