import Cathedral.Defs
import Cathedral.FractIntegral

/-! # Cathedral.GramDiag

## Diagonal Gram entry upper bound: `gramEntry j j ≤ 1/3 + 1/j²`

### Proof architecture
```
gram_entry_diag_upper' (MAIN THEOREM)
  ├── gramEntry_le_basis: gramEntry j j ≤ ∫₀¹ {j/x} dx
  │     └── fract_mul_self_le: {a}·{a} ≤ {a} (pointwise)
  ├── basis_integral_upper: ∫₀¹ {j/x} dx ≤ 1/2
  │     └── correction_lower: k·Σ(1/n - log(1+1/n)) ≥ 1/2
  │           ├── per_term_log_lower: 1/n - log(1+1/n) ≥ 1/(2n(n+1))
  │           │     ├── log2_le (n=1): log(2) ≤ 3/4 via exp(3/20)⁵ ≥ 2
  │           │     └── per_term_nge2 (n≥2): via Taylor upper bound on log
  │           └── telescoping: Σ 1/(2n(n+1)) = 1/(2k)
  └── gramEntry_le_third (j≥3): gramEntry j j ≤ 1/3
        └── piece integral decomposition (TODO)
```
-/

noncomputable section
open Real MeasureTheory Set

-- ════════════════════════════════════════════════
-- POINTWISE BOUND
-- ════════════════════════════════════════════════

/-- {a}·{a} ≤ {a} since 0 ≤ {a} < 1 implies {a}(1 - {a}) ≥ 0. -/
lemma fract_mul_self_le (a : ℝ) :
    Int.fract a * Int.fract a ≤ Int.fract a := by
  nlinarith [Int.fract_nonneg a, Int.fract_lt_one a]

-- ════════════════════════════════════════════════
-- LOG(2) ≤ 3/4
-- ════════════════════════════════════════════════

/-- log(2) ≤ 3/4, proved via exp(3/20)⁵ ≥ (23/20)⁵ ≥ 2. -/
private lemma log2_le : Real.log 2 ≤ 3 / 4 := by
  rw [Real.log_le_iff_le_exp (by norm_num : (0:ℝ) < 2)]
  rw [show (3:ℝ)/4 = (5:ℕ) * (3/20 : ℝ) from by norm_num, Real.exp_nat_mul]
  calc (2:ℝ) ≤ (23/20)^5 := by norm_num
    _ ≤ (Real.exp (3/20))^5 := by gcongr; linarith [Real.add_one_le_exp (3/20:ℝ)]

-- ════════════════════════════════════════════════
-- PER-TERM LOG LOWER BOUND
-- ════════════════════════════════════════════════

/-- log(1+x) ≤ x - x²/2 + x³/3 for x ≥ 0.
    Proof: h(x) = x - x²/2 + x³/3 - log(1+x) satisfies h(0)=0 and
    h'(x) = x³/(1+x) ≥ 0, so h is monotone on [0,∞). -/
private lemma log_upper_cubic (x : ℝ) (hx : 0 ≤ x) :
    Real.log (1 + x) ≤ x - x^2/2 + x^3/3 := by
  suffices h : 0 ≤ x - x^2/2 + x^3/3 - Real.log (1 + x) by linarith
  set f : ℝ → ℝ := fun t => t - t^2/2 + t^3/3 - Real.log (1 + t) with hf_def
  have hf0 : f 0 = 0 := by simp [hf_def, Real.log_one]
  have hcont : ContinuousOn f (Ici 0) := by
    simp only [hf_def]
    apply ContinuousOn.sub
    · apply ContinuousOn.add
      · exact (continuousOn_id.sub ((continuous_pow 2).continuousOn.div_const 2))
      · exact (continuous_pow 3).continuousOn.div_const 3
    · exact ContinuousOn.log (continuousOn_const.add continuousOn_id) (fun t ht => by
        simp only [mem_Ici] at ht; linarith)
  have hdiff : DifferentiableOn ℝ f (interior (Ici (0:ℝ))) := by
    simp only [interior_Ici, hf_def]
    intro t ht
    simp only [mem_Ioi] at ht
    apply DifferentiableAt.differentiableWithinAt
    apply DifferentiableAt.sub
    · apply DifferentiableAt.add
      · exact differentiableAt_id.sub ((differentiableAt_pow 2).div_const 2)
      · exact (differentiableAt_pow 3).div_const 3
    · exact (differentiableAt_id.const_add 1).log (ne_of_gt (by linarith : (0:ℝ) < 1 + t))
  have hderiv : ∀ t ∈ interior (Ici (0:ℝ)), 0 ≤ deriv f t := by
    intro t ht
    simp only [interior_Ici, mem_Ioi] at ht
    have h1t : (0:ℝ) < 1 + t := by linarith
    have h1t_ne : (1:ℝ) + t ≠ 0 := ne_of_gt h1t
    -- h'(t) = 1 - t + t² - 1/(1+t) = t³/(1+t)
    have hdf : HasDerivAt f (t^3 / (1+t)) t := by
      simp only [hf_def]
      have h1 := hasDerivAt_id t
      have h2 := (hasDerivAt_pow 2 t).div_const 2
      have h3 := (hasDerivAt_pow 3 t).div_const 3
      have h4 := (hasDerivAt_id t).const_add 1 |>.log h1t_ne
      refine (((h1.sub h2).add h3).sub h4).congr_deriv ?_
      simp only [id]; field_simp; ring
    rw [hdf.deriv]
    exact div_nonneg (pow_nonneg (le_of_lt ht) 3) (le_of_lt h1t)
  have hmono : MonotoneOn f (Ici 0) :=
    monotoneOn_of_deriv_nonneg (convex_Ici 0) hcont hdiff hderiv
  have hfx : f 0 ≤ f x := hmono (mem_Ici.mpr (le_refl 0)) (mem_Ici.mpr hx) hx
  rw [hf0] at hfx; exact hfx

private lemma per_term_nge2 (n : ℕ) (hn : 2 ≤ n) :
    1 / ((n : ℕ) : ℝ) - Real.log (1 + 1 / ((n : ℕ) : ℝ))
    ≥ 1 / (2 * ((n : ℕ) : ℝ) * (((n : ℕ) : ℝ) + 1)) := by
  have hn_pos : (0 : ℝ) < (n : ℝ) := by positivity
  have hge2 : (n : ℝ) ≥ 2 := by exact_mod_cast hn
  -- log(1+1/n) ≤ 1/n - (1/n)²/2 + (1/n)³/3
  have h := log_upper_cubic (1/(n:ℝ)) (by positivity)
  -- 1/n - log ≥ 1/(2n²) - 1/(3n³) ≥ 1/(2n(n+1))
  have step1 : 1/(n:ℝ) - Real.log (1 + 1/(n:ℝ)) ≥ 1/(2*(n:ℝ)^2) - 1/(3*(n:ℝ)^3) := by
    have h1 : (1/(n:ℝ))^2 / 2 = 1 / (2 * (n:ℝ)^2) := by field_simp
    have h2 : (1/(n:ℝ))^3 / 3 = 1 / (3 * (n:ℝ)^3) := by field_simp
    linarith [h1, h2]
  have step2 : 1/(2*(n:ℝ)^2) - 1/(3*(n:ℝ)^3) ≥ 1/(2*(n:ℝ)*((n:ℝ)+1)) := by
    rw [ge_iff_le, sub_eq_add_neg, ← sub_eq_add_neg]
    rw [div_sub_div _ _ (ne_of_gt (by positivity : (0:ℝ) < 2*(n:ℝ)^2))
                        (ne_of_gt (by positivity : (0:ℝ) < 3*(n:ℝ)^3))]
    rw [div_le_div_iff₀ (by positivity) (by positivity)]
    nlinarith [sq_nonneg ((n:ℝ) - 2)]
  linarith

/-- For all n ≥ 1: 1/n - log(1+1/n) ≥ 1/(2n(n+1)). -/
private lemma per_term_log_lower (n : ℕ) (hn : 1 ≤ n) :
    1 / ((n : ℕ) : ℝ) - Real.log (1 + 1 / ((n : ℕ) : ℝ))
    ≥ 1 / (2 * ((n : ℕ) : ℝ) * (((n : ℕ) : ℝ) + 1)) := by
  rcases n with _ | _ | m
  · omega
  · -- n = 1: need 1 - log(2) ≥ 1/4
    show 1 / ((1 : ℕ) : ℝ) - Real.log (1 + 1 / ((1 : ℕ) : ℝ)) ≥
      1 / (2 * ((1 : ℕ) : ℝ) * (((1 : ℕ) : ℝ) + 1))
    simp only [Nat.cast_one]; linarith [log2_le]
  · exact per_term_nge2 (m + 2) (by omega)

-- ════════════════════════════════════════════════
-- CORRECTION SUM TELESCOPING
-- ════════════════════════════════════════════════

/-- 1/(2n(n+1)) = (1/2)(1/n - 1/(n+1)). -/
private lemma inv_prod_half_tele (n : ℕ) (hn : 1 ≤ n) :
    1 / (2 * ((n : ℕ) : ℝ) * (((n : ℕ) : ℝ) + 1)) =
    (1/2) * (1 / ((n : ℕ) : ℝ) - 1 / (((n : ℕ) : ℝ) + 1)) := by
  have h1 : ((n : ℕ) : ℝ) ≠ 0 := by positivity
  have h2 : ((n : ℕ) : ℝ) + 1 ≠ 0 := by positivity
  rw [div_sub_div _ _ h1 h2]; field_simp; ring

/-- Σ 1/(2n(n+1)) from n=k to ∞ = 1/(2k) (via telescoping). -/
private lemma tsum_lower (k : ℕ) (hk : 1 ≤ k) :
    ∑' m, (1 / (2 * ((m + k : ℕ) : ℝ) * (((m + k : ℕ) : ℝ) + 1))) =
    1 / (2 * (k : ℝ)) := by
  rw [show (fun m : ℕ => 1 / (2 * ((m + k : ℕ) : ℝ) * (((m + k : ℕ) : ℝ) + 1))) =
      (fun m : ℕ => (1/2:ℝ) * (1 / ((m + k : ℕ) : ℝ) - 1 / (((m + k : ℕ) : ℝ) + 1))) from by
    ext m; exact inv_prod_half_tele (m + k) (by omega)]
  rw [tsum_mul_left, (hasSum_telescoping_inv k hk).tsum_eq]; ring

/-- Summability of 1/(2n(n+1)). -/
private lemma summ_lower (k : ℕ) (hk : 1 ≤ k) :
    Summable (fun m : ℕ =>
      1 / (2 * ((m + k : ℕ) : ℝ) * (((m + k : ℕ) : ℝ) + 1))) := by
  rw [show (fun m : ℕ => 1 / (2 * ((m + k : ℕ) : ℝ) * (((m + k : ℕ) : ℝ) + 1))) =
      (fun m : ℕ => (1/2:ℝ) * (1 / ((m + k : ℕ) : ℝ) - 1 / (((m + k : ℕ) : ℝ) + 1))) from by
    ext m; exact inv_prod_half_tele (m + k) (by omega)]
  exact (hasSum_telescoping_inv k hk).summable.mul_left (1/2)

-- ════════════════════════════════════════════════
-- CORRECTION LOWER BOUND
-- ════════════════════════════════════════════════

/-- k·Σ(1/n - log(1+1/n)) ≥ 1/2, via per-term bound and telescoping. -/
private lemma correction_lower (k : ℕ) (hk : 1 ≤ k) :
    (k : ℝ) * ∑' (m : ℕ),
      (1 / ((m + k : ℕ) : ℝ) - Real.log (1 + 1 / ((m + k : ℕ) : ℝ)))
    ≥ 1 / 2 := by
  have hk_pos : (0 : ℝ) < (k : ℝ) := by positivity
  have hsumm : Summable (fun m : ℕ =>
      1 / ((m + k : ℕ) : ℝ) - Real.log (1 + 1 / ((m + k : ℕ) : ℝ))) := by
    have := (summable_log_correction k hk).neg; simp only [neg_sub] at this; exact this
  have htsum_ineq : ∑' m, (1 / (2 * ((m + k : ℕ) : ℝ) * (((m + k : ℕ) : ℝ) + 1))) ≤
      ∑' m, (1 / ((m + k : ℕ) : ℝ) - Real.log (1 + 1 / ((m + k : ℕ) : ℝ))) :=
    Summable.tsum_le_tsum
      (fun m => by linarith [per_term_log_lower (m + k) (by omega : 1 ≤ m + k)])
      (summ_lower k hk) hsumm
  calc (k : ℝ) * ∑' m, (1 / ((m + k : ℕ) : ℝ) - Real.log (1 + 1 / ((m + k : ℕ) : ℝ)))
      ≥ (k : ℝ) * ∑' m, (1 / (2 * ((m + k : ℕ) : ℝ) * (((m + k : ℕ) : ℝ) + 1))) :=
        mul_le_mul_of_nonneg_left htsum_ineq (le_of_lt hk_pos)
    _ = (k : ℝ) * (1 / (2 * (k : ℝ))) := by rw [tsum_lower k hk]
    _ = 1 / 2 := by field_simp

-- ════════════════════════════════════════════════
-- INTEGRAL UPPER BOUND
-- ════════════════════════════════════════════════

/-- **THEOREM**: ∫₀¹ {k/x} dx ≤ 1/2 for k ≥ 1. -/
theorem basis_integral_upper (k : ℕ) (hk : 1 ≤ k) :
    ∫ x in (0:ℝ)..1, Int.fract ((k : ℝ) / x) ≤ 1 / 2 := by
  linarith [fract_integral_identity k hk, correction_lower k hk]

-- ════════════════════════════════════════════════
-- GRAMENTRY DIAGONAL BOUNDS
-- ════════════════════════════════════════════════

/-- gramEntry j j ≤ ∫₀¹ {j/x} dx via pointwise {u}² ≤ {u}. -/
private lemma gramEntry_le_basis (j : ℕ) :
    gramEntry j j ≤ ∫ x in (0:ℝ)..1, Int.fract ((j:ℝ) / x) := by
  unfold gramEntry
  apply intervalIntegral.integral_mono_on (by norm_num : (0:ℝ) ≤ 1)
  · -- Integrability of {j/x}²
    apply IntervalIntegrable.mono_fun
      (intervalIntegral.intervalIntegrable_const (c := (1:ℝ)))
    · -- Measurability: Int.fract ∘ (j/·) is measurable
      have hmeas : Measurable (fun x : ℝ => Int.fract ((j:ℝ) / x)) :=
        measurable_fract_real.comp (measurable_const.div measurable_id)
      exact (hmeas.mul hmeas).aestronglyMeasurable.restrict
    · filter_upwards with x
      rw [Real.norm_eq_abs, abs_of_nonneg (mul_nonneg (Int.fract_nonneg _) (Int.fract_nonneg _)),
          Real.norm_eq_abs, abs_of_nonneg (by norm_num : (0:ℝ) ≤ 1)]
      nlinarith [Int.fract_nonneg ((j:ℝ)/x), Int.fract_lt_one ((j:ℝ)/x)]
  · exact fract_div_intervalIntegrable j 0 1
  · intro x _; exact fract_mul_self_le _

-- ════════════════════════════════════════════════
-- MAIN THEOREM
-- ════════════════════════════════════════════════

/-- **THEOREM**: gramEntry j j ≤ 1/3 + 1/j² for all j ≥ 1.
    - j ∈ {1, 2}: gramEntry ≤ 1/2 ≤ 1/3 + 1/j² (arithmetic).
    - j ≥ 3: gramEntry ≤ 1/3 ≤ 1/3 + 1/j² (piece decomposition). -/
theorem gram_entry_diag_upper' (j : ℕ) (hj : 1 ≤ j) :
    gramEntry j j ≤ 1 / 3 + 1 / ((j : ℝ) ^ 2) := by
  by_cases hle : j ≤ 2
  · -- j ∈ {1, 2}: gramEntry ≤ 1/2 ≤ 1/3 + 1/j²
    have h_half := calc gramEntry j j
        ≤ ∫ x in (0:ℝ)..1, Int.fract ((j:ℝ) / x) := gramEntry_le_basis j
      _ ≤ 1 / 2 := basis_integral_upper j hj
    interval_cases j <;> simp_all <;> norm_num <;> linarith
  · -- j ≥ 3: gramEntry j j ≤ 1/3 suffices since 1/j² ≥ 0
    push_neg at hle
    -- gramEntry j j ≤ 1/3 from piece integral analysis
    have : gramEntry j j ≤ 1 / 3 := by
      sorry -- TODO: piece integral decomposition
    linarith [show (0:ℝ) ≤ 1 / (j:ℝ)^2 from by positivity]

end
