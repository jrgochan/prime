import Cathedral.Defs
import Cathedral.Archive.HighFrequencyTrap.FractIntegral

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
lemma gramEntry_le_basis (j : ℕ) :
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
-- PIECE INTEGRAL ANALYSIS FOR j ≥ 3
-- ════════════════════════════════════════════════

/-- log(1+x) ≥ x - x²/2 + x³/3 - x⁴/4 for x ≥ 0.
    Proof: h(x) = log(1+x) - (x - x²/2 + x³/3 - x⁴/4) has h(0) = 0 and
    h'(x) = x⁴/(1+x) ≥ 0, so h is monotone. -/
lemma log_lower_quartic (x : ℝ) (hx : 0 ≤ x) :
    x - x^2/2 + x^3/3 - x^4/4 ≤ Real.log (1 + x) := by
  suffices h : 0 ≤ Real.log (1 + x) - (x - x^2/2 + x^3/3 - x^4/4) by linarith
  set f : ℝ → ℝ := fun t => Real.log (1 + t) - (t - t^2/2 + t^3/3 - t^4/4) with hf_def
  have hf0 : f 0 = 0 := by simp [hf_def, Real.log_one]
  have hcont : ContinuousOn f (Ici 0) := by
    simp only [hf_def]
    apply ContinuousOn.sub
    · exact ContinuousOn.log (continuousOn_const.add continuousOn_id) (fun t ht => by
        simp only [mem_Ici] at ht; linarith)
    · fun_prop
  have hdiff : DifferentiableOn ℝ f (interior (Ici (0:ℝ))) := by
    simp only [interior_Ici, hf_def]
    intro t ht; simp only [mem_Ioi] at ht
    apply DifferentiableAt.differentiableWithinAt
    apply DifferentiableAt.sub
    · exact (differentiableAt_id.const_add 1).log (ne_of_gt (by linarith : (0:ℝ) < 1 + t))
    · fun_prop
  have hderiv : ∀ t ∈ interior (Ici (0:ℝ)), 0 ≤ deriv f t := by
    intro t ht; simp only [interior_Ici, mem_Ioi] at ht
    have h1t : (0:ℝ) < 1 + t := by linarith
    have hdf : HasDerivAt f (t^4 / (1+t)) t := by
      simp only [hf_def]
      have h1 := (hasDerivAt_id t).const_add 1 |>.log (ne_of_gt h1t)
      have h2 := hasDerivAt_id t
      have h3 := (hasDerivAt_pow 2 t).div_const 2
      have h4 := (hasDerivAt_pow 3 t).div_const 3
      have h5 := (hasDerivAt_pow 4 t).div_const 4
      refine (h1.sub (((h2.sub h3).add h4).sub h5)).congr_deriv ?_
      simp only [id]; field_simp; ring
    rw [hdf.deriv]
    exact div_nonneg (pow_nonneg (le_of_lt ht) 4) (le_of_lt h1t)
  have hmono : MonotoneOn f (Ici 0) :=
    monotoneOn_of_deriv_nonneg (convex_Ici 0) hcont hdiff hderiv
  have hfx : f 0 ≤ f x := hmono (mem_Ici.mpr (le_refl 0)) (mem_Ici.mpr hx) hx
  rw [hf0] at hfx; exact hfx

/-- FTC: ∫_{j/(n+1)}^{j/n} (j/x - n)² dx = j·[(2n+1)/(n+1) - 2n·log(1+1/n)].
    Antiderivative: F(x) = -j²·x⁻¹ - 2jn·log(x) + n²·x. -/
lemma integral_sq_div_sub_const (j n : ℕ) (hj : 1 ≤ j) (hn : 1 ≤ n) :
    ∫ x in ((j:ℝ)/((n:ℝ)+1))..((j:ℝ)/(n:ℝ)),
      ((j:ℝ)/x - (n:ℝ))^2 =
    (j:ℝ) * ((2*(n:ℝ)+1)/((n:ℝ)+1) - 2*(n:ℝ)* Real.log (1 + 1/(n:ℝ))) := by
  have hj_pos : (0:ℝ) < (j:ℝ) := Nat.cast_pos.mpr (by omega)
  have hn_pos : (0:ℝ) < (n:ℝ) := Nat.cast_pos.mpr (by omega)
  have hn1_pos : (0:ℝ) < (n:ℝ) + 1 := by linarith
  have hlo_pos : (0:ℝ) < (j:ℝ)/((n:ℝ)+1) := div_pos hj_pos hn1_pos
  have hhi_pos : (0:ℝ) < (j:ℝ)/(n:ℝ) := div_pos hj_pos hn_pos
  have hle : (j:ℝ)/((n:ℝ)+1) ≤ (j:ℝ)/(n:ℝ) :=
    div_le_div_of_nonneg_left (le_of_lt hj_pos) hn_pos (by linarith)
  set g₁ : ℝ → ℝ := fun x => -(j:ℝ)^2 * x⁻¹
  set g₂ : ℝ → ℝ := fun x => -2*(j:ℝ)*(n:ℝ) * Real.log x
  set g₃ : ℝ → ℝ := fun x => (n:ℝ)^2 * x
  have hF : ∀ x ∈ Set.uIcc ((j:ℝ)/((n:ℝ)+1)) ((j:ℝ)/(n:ℝ)),
      HasDerivAt (fun x => g₁ x + g₂ x + g₃ x) (((j:ℝ)/x - (n:ℝ))^2) x := by
    intro x hx
    rw [Set.uIcc_of_le hle] at hx
    have hx_pos : (0:ℝ) < x := lt_of_lt_of_le hlo_pos hx.1
    have hx_ne : x ≠ 0 := ne_of_gt hx_pos
    have h1 : HasDerivAt g₁ ((j:ℝ)^2 * x⁻¹^2) x := by
      simp only [g₁]; convert (hasDerivAt_inv hx_ne).const_mul (-(j:ℝ)^2) using 1; ring
    have h2 : HasDerivAt g₂ (-2*(j:ℝ)*(n:ℝ) * x⁻¹) x := by
      simp only [g₂]; exact (Real.hasDerivAt_log hx_ne).const_mul _
    have h3 : HasDerivAt g₃ ((n:ℝ)^2) x := by
      simp only [g₃]; convert (hasDerivAt_id x).const_mul ((n:ℝ)^2) using 1; ring
    refine ((h1.add h2).add h3).congr_deriv ?_
    field_simp; ring
  have hint : IntervalIntegrable (fun x => ((j:ℝ)/x - (n:ℝ))^2) volume
      ((j:ℝ)/((n:ℝ)+1)) ((j:ℝ)/(n:ℝ)) := by
    apply ContinuousOn.intervalIntegrable
    apply ContinuousOn.pow
    exact (continuousOn_const.div continuousOn_id (fun x hx => by
      rw [Set.uIcc_of_le hle] at hx; exact ne_of_gt (lt_of_lt_of_le hlo_pos hx.1))).sub
      continuousOn_const
  rw [intervalIntegral.integral_eq_sub_of_hasDerivAt hF hint]
  simp only [g₁, g₂, g₃]
  have hlog : Real.log ((j:ℝ)/(n:ℝ)) - Real.log ((j:ℝ)/((n:ℝ)+1)) =
      Real.log (1 + 1/(n:ℝ)) := by
    rw [← Real.log_div (ne_of_gt hhi_pos) (ne_of_gt hlo_pos)]
    congr 1; field_simp
  have inv1 : ((j:ℝ)/(n:ℝ))⁻¹ = (n:ℝ)/(j:ℝ) := by field_simp
  have inv2 : ((j:ℝ)/((n:ℝ)+1))⁻¹ = ((n:ℝ)+1)/(j:ℝ) := by field_simp
  rw [inv1, inv2]
  set L := Real.log (1 + 1/(n:ℝ))
  have hlog2 : Real.log ((j:ℝ)/(n:ℝ)) = Real.log ((j:ℝ)/((n:ℝ)+1)) + L := by
    linarith [hlog]
  rw [hlog2]
  have hn_ne : (n:ℝ) ≠ 0 := ne_of_gt hn_pos
  have hn1_ne : (n:ℝ) + 1 ≠ 0 := ne_of_gt hn1_pos
  have hj_ne : (j:ℝ) ≠ 0 := ne_of_gt hj_pos
  field_simp; ring

/-- Per-piece bound: the squared piece integral ≤ j/(3n(n+1)) for n ≥ 3.
    Uses log_lower_quartic: log(1+1/n) ≥ 1/n - 1/(2n²) + 1/(3n³) - 1/(4n⁴). -/
lemma piece_sq_upper_bound (n : ℕ) (hn : 3 ≤ n) :
    (2*(n:ℝ)+1)/((n:ℝ)+1) - 2*(n:ℝ)* Real.log (1 + 1/(n:ℝ))
    ≤ 1 / (3 * (n:ℝ) * ((n:ℝ)+1)) := by
  have hn_pos : (0:ℝ) < (n:ℝ) := Nat.cast_pos.mpr (by omega)
  have hge3 : (n:ℝ) ≥ 3 := by exact_mod_cast hn
  have hlog := log_lower_quartic (1/(n:ℝ)) (by positivity)
  have hstep1 : (2*(n:ℝ)+1)/((n:ℝ)+1) - 2*(n:ℝ) * Real.log (1 + 1/(n:ℝ)) ≤
      (2*(n:ℝ)+1)/((n:ℝ)+1) - 2*(n:ℝ) * (1/(n:ℝ) - (1/(n:ℝ))^2/2 + (1/(n:ℝ))^3/3 - (1/(n:ℝ))^4/4) := by
    linarith [mul_le_mul_of_nonneg_left hlog (by positivity : (0:ℝ) ≤ 2*(n:ℝ))]
  have hstep2 :
      (2*(n:ℝ)+1)/((n:ℝ)+1) - 2*(n:ℝ) * (1/(n:ℝ) - (1/(n:ℝ))^2/2 + (1/(n:ℝ))^3/3 - (1/(n:ℝ))^4/4) =
      1/((n:ℝ)*((n:ℝ)+1)) - 2/(3*(n:ℝ)^2) + 1/(2*(n:ℝ)^3) := by
    field_simp; ring
  have hstep3 : 1/((n:ℝ)*((n:ℝ)+1)) - 2/(3*(n:ℝ)^2) + 1/(2*(n:ℝ)^3) ≤
      1/(3*(n:ℝ)*((n:ℝ)+1)) := by
    suffices h : 1/((n:ℝ)*((n:ℝ)+1)) - 2/(3*(n:ℝ)^2) + 1/(2*(n:ℝ)^3) -
        1/(3*(n:ℝ)*((n:ℝ)+1)) ≤ 0 by linarith
    have heq : 1/((n:ℝ)*((n:ℝ)+1)) - 2/(3*(n:ℝ)^2) + 1/(2*(n:ℝ)^3) -
        1/(3*(n:ℝ)*((n:ℝ)+1)) = -(((n:ℝ)-3)/(6*(n:ℝ)^3*((n:ℝ)+1))) := by
      field_simp; ring
    rw [heq]; exact neg_nonpos_of_nonneg (div_nonneg (by linarith) (by positivity))
  linarith [hstep1, hstep2]

-- Integrability of {j/x}²
lemma fract_sq_intervalIntegrable (j : ℕ) (a b : ℝ) :
    IntervalIntegrable (fun x => Int.fract ((j:ℝ)/x) * Int.fract ((j:ℝ)/x)) volume a b := by
  apply IntervalIntegrable.mono_fun
    (intervalIntegral.intervalIntegrable_const (c := (1:ℝ)))
  · have hmeas : Measurable (fun x : ℝ => Int.fract ((j:ℝ) / x)) :=
      measurable_fract_real.comp (measurable_const.div measurable_id)
    exact (hmeas.mul hmeas).aestronglyMeasurable.restrict
  · filter_upwards with x
    rw [Real.norm_eq_abs, abs_of_nonneg (mul_nonneg (Int.fract_nonneg _) (Int.fract_nonneg _)),
        Real.norm_eq_abs, abs_of_nonneg (by norm_num : (0:ℝ) ≤ 1)]
    nlinarith [Int.fract_nonneg ((j:ℝ)/x), Int.fract_lt_one ((j:ℝ)/x)]

/-- Bound each squared piece integral by j/(3n(n+1)). -/
lemma fract_sq_piece_bound (j n : ℕ) (hj : 3 ≤ j) (hn : j ≤ n) :
    ∫ x in ((j:ℝ)/((n:ℝ)+1))..((j:ℝ)/(n:ℝ)),
      Int.fract ((j:ℝ)/x) * Int.fract ((j:ℝ)/x) ≤
    (j:ℝ) / (3 * (n:ℝ) * ((n:ℝ)+1)) := by
  have hj_pos : (0:ℝ) < (j:ℝ) := Nat.cast_pos.mpr (by omega)
  have hn_pos : (0:ℝ) < (n:ℝ) := Nat.cast_pos.mpr (by omega)
  have hle : (j:ℝ)/((n:ℝ)+1) ≤ (j:ℝ)/(n:ℝ) :=
    div_le_div_of_nonneg_left (le_of_lt hj_pos) hn_pos (by linarith)
  -- Replace fract with (j/x - n)² via a.e. congr
  have hae : ∫ x in ((j:ℝ)/((n:ℝ)+1))..((j:ℝ)/(n:ℝ)),
      Int.fract ((j:ℝ)/x) * Int.fract ((j:ℝ)/x) =
      ∫ x in ((j:ℝ)/((n:ℝ)+1))..((j:ℝ)/(n:ℝ)), ((j:ℝ)/x - (n:ℝ))^2 := by
    rw [intervalIntegral.integral_of_le hle, intervalIntegral.integral_of_le hle]
    exact integral_congr_ae ((ae_restrict_mem measurableSet_Ioc).mono (fun x hx => by
      show Int.fract ((j:ℝ)/x) * Int.fract ((j:ℝ)/x) = ((j:ℝ)/x - (n:ℝ))^2
      rw [fract_div_eq_on_Ioc j n (by omega) (by omega) x hx.1 hx.2]; ring))
  rw [hae, integral_sq_div_sub_const j n (by omega) (by omega)]
  calc (j:ℝ) * ((2*(n:ℝ)+1)/((n:ℝ)+1) - 2*(n:ℝ)* Real.log (1 + 1/(n:ℝ)))
      ≤ (j:ℝ) * (1 / (3 * (n:ℝ) * ((n:ℝ)+1))) :=
        mul_le_mul_of_nonneg_left (piece_sq_upper_bound n (by omega)) (by positivity)
    _ = (j:ℝ) / (3 * (n:ℝ) * ((n:ℝ)+1)) := by ring

/-- Finite telescoping of squared piece integrals. -/
lemma fract_sq_telescope (j : ℕ) (hj : 1 ≤ j) (N : ℕ) :
    ∑ m ∈ Finset.range (N + 1),
      ∫ x in ((j:ℝ)/((j:ℝ)+(m:ℝ)+1))..((j:ℝ)/((j:ℝ)+(m:ℝ))),
        Int.fract ((j:ℝ)/x) * Int.fract ((j:ℝ)/x) =
    ∫ x in ((j:ℝ)/((j:ℝ)+(N:ℝ)+1))..(1:ℝ),
      Int.fract ((j:ℝ)/x) * Int.fract ((j:ℝ)/x) := by
  induction N with
  | zero =>
    rw [Finset.sum_range_one]; simp only [Nat.cast_zero, add_zero]
    congr 1; exact div_self (ne_of_gt (show (0:ℝ) < (j:ℝ) by positivity))
  | succ N ih =>
    rw [Finset.sum_range_succ, ih]
    set a := (j:ℝ) / ((j:ℝ) + (N:ℝ) + 2)
    set b := (j:ℝ) / ((j:ℝ) + (N:ℝ) + 1)
    have key := intervalIntegral.integral_add_adjacent_intervals
      (fract_sq_intervalIntegrable j a b) (fract_sq_intervalIntegrable j b 1)
    rw [add_comm]; convert key using 2 <;> simp [a, b] <;> ring_nf

/-- Tail bound: ‖∫₀^ε {j/x}² dx‖ ≤ ε. -/
lemma fract_sq_tail_bound (j : ℕ) (ε : ℝ) (hε : 0 ≤ ε) :
    ‖∫ x in (0:ℝ)..ε, Int.fract ((j:ℝ)/x) * Int.fract ((j:ℝ)/x)‖ ≤ ε := by
  have h : ∀ x ∈ Set.uIoc (0:ℝ) ε,
      ‖Int.fract ((j:ℝ)/x) * Int.fract ((j:ℝ)/x)‖ ≤ 1 := by
    intro x _
    rw [Real.norm_eq_abs, abs_of_nonneg (mul_nonneg (Int.fract_nonneg _) (Int.fract_nonneg _))]
    nlinarith [Int.fract_nonneg ((j:ℝ)/x), Int.fract_lt_one ((j:ℝ)/x)]
  calc ‖∫ x in (0:ℝ)..ε, Int.fract ((j:ℝ)/x) * Int.fract ((j:ℝ)/x)‖
      ≤ 1 * |ε - 0| := intervalIntegral.norm_integral_le_of_norm_le_const h
    _ = ε := by rw [sub_zero, abs_of_nonneg hε, one_mul]

/-- **gramEntry j j ≤ 1/3 for j ≥ 3**.
    Proof by piece integral decomposition + Taylor bound.
    For each M: gramEntry ≤ 1/3 + 2j/(3(j+M+1)), and taking M → ∞ gives ≤ 1/3. -/
lemma gramEntry_le_third (j : ℕ) (hj : 3 ≤ j) :
    gramEntry j j ≤ 1 / 3 := by
  have hj_pos : (0:ℝ) < (j:ℝ) := Nat.cast_pos.mpr (by omega)
  -- For each M, bound gramEntry by partial sum + tail
  have hbound : ∀ M : ℕ, gramEntry j j ≤ 1/3 + 2*(j:ℝ)/(3*((j:ℝ)+(M:ℝ)+1)) := by
    intro M
    set ε := (j:ℝ) / ((j:ℝ) + (M:ℝ) + 1)
    have hε_pos : 0 < ε := by positivity
    -- gramEntry = ∫₀^ε + ∫_ε^1
    have hsplit : gramEntry j j =
      (∫ x in (0:ℝ)..ε, Int.fract ((j:ℝ)/x) * Int.fract ((j:ℝ)/x)) +
      (∫ x in ε..1, Int.fract ((j:ℝ)/x) * Int.fract ((j:ℝ)/x)) :=
      (intervalIntegral.integral_add_adjacent_intervals
        (fract_sq_intervalIntegrable j 0 ε) (fract_sq_intervalIntegrable j ε 1)).symm
    rw [hsplit]
    -- Tail bound
    have htail : ∫ x in (0:ℝ)..ε, Int.fract ((j:ℝ)/x) * Int.fract ((j:ℝ)/x) ≤ ε := by
      have hb := fract_sq_tail_bound j ε (le_of_lt hε_pos)
      -- hb : ‖∫...‖ ≤ ε. Since ∫... ≤ |∫...| = ‖∫...‖ ≤ ε.
      calc ∫ x in (0:ℝ)..ε, Int.fract ((j:ℝ)/x) * Int.fract ((j:ℝ)/x)
          ≤ |∫ x in (0:ℝ)..ε, Int.fract ((j:ℝ)/x) * Int.fract ((j:ℝ)/x)| := le_abs_self _
        _ = ‖∫ x in (0:ℝ)..ε, Int.fract ((j:ℝ)/x) * Int.fract ((j:ℝ)/x)‖ := (Real.norm_eq_abs _).symm
        _ ≤ ε := hb
    -- Main part: telescope = Σ pieces, bounded by partial telescoping sum
    have hmain : ∫ x in ε..1, Int.fract ((j:ℝ)/x) * Int.fract ((j:ℝ)/x) ≤
        (j:ℝ)/3 * (1/(j:ℝ) - 1/((j:ℝ)+(M:ℝ)+1)) := by
      -- Rewrite as sum of pieces via telescope
      have htel := (fract_sq_telescope j (by omega) M).symm
      rw [htel]
      -- Need to match the endpoints: the piece bounds use ↑(j+m) while
      -- the telescope uses ↑j + ↑m. Bridge with convert.
      -- First, bound each piece
      have hpieces : ∀ m ∈ Finset.range (M + 1),
          ∫ x in ((j:ℝ)/((j:ℝ)+(m:ℝ)+1))..((j:ℝ)/((j:ℝ)+(m:ℝ))),
            Int.fract ((j:ℝ)/x) * Int.fract ((j:ℝ)/x) ≤
          (j:ℝ) / (3 * ((j:ℝ)+(m:ℝ)) * ((j:ℝ)+(m:ℝ)+1)) := by
        intro m _
        -- The piece bound uses n = j+m (as ℕ)
        have : (j:ℝ) + (m:ℝ) = ((j+m:ℕ):ℝ) := by push_cast; ring
        rw [this]
        exact fract_sq_piece_bound j (j+m) hj (by omega)
      calc ∑ m ∈ Finset.range (M + 1),
              ∫ x in ((j:ℝ)/((j:ℝ)+(m:ℝ)+1))..((j:ℝ)/((j:ℝ)+(m:ℝ))),
                Int.fract ((j:ℝ)/x) * Int.fract ((j:ℝ)/x)
          ≤ ∑ m ∈ Finset.range (M + 1),
              (j:ℝ) / (3 * ((j:ℝ)+(m:ℝ)) * ((j:ℝ)+(m:ℝ)+1)) :=
            Finset.sum_le_sum hpieces
        _ = (j:ℝ)/3 * (1/(j:ℝ) - 1/((j:ℝ)+(M:ℝ)+1)) := by
            -- Summand equality: j/(3·(j+m)·(j+m+1)) = j/3·(1/(j+m) - 1/(j+m+1))
            have hrw : ∑ m ∈ Finset.range (M + 1),
                (j:ℝ) / (3 * ((j:ℝ)+(m:ℝ)) * ((j:ℝ)+(m:ℝ)+1)) =
                (j:ℝ)/3 * ∑ m ∈ Finset.range (M + 1),
                (1/((j:ℝ)+(m:ℝ)) - 1/((j:ℝ)+(m:ℝ)+1)) := by
              rw [Finset.mul_sum]
              congr 1; ext m
              have : (0:ℝ) < (j:ℝ) + (m:ℝ) := by positivity
              have : (0:ℝ) < (j:ℝ) + (m:ℝ) + 1 := by linarith
              field_simp; ring
            rw [hrw]
            -- Telescoping: Σ (1/(j+m) - 1/(j+m+1)) = 1/j - 1/(j+M+1)
            congr 1
            have htele : ∀ M' : ℕ, ∑ m ∈ Finset.range (M' + 1),
                (1/((j:ℝ)+(m:ℝ)) - 1/((j:ℝ)+(m:ℝ)+1)) =
                1/(j:ℝ) - 1/((j:ℝ)+(M':ℝ)+1) := by
              intro M'; induction M' with
              | zero => simp
              | succ M' ih =>
                rw [Finset.sum_range_succ, ih]
                have h1 : (j:ℝ) + (M':ℝ) + 1 ≠ 0 := by positivity
                have h2 : (j:ℝ) + (M':ℝ) + 1 + 1 ≠ 0 := by positivity
                have h3 : (j:ℝ) ≠ 0 := ne_of_gt hj_pos
                push_cast; field_simp; ring
            exact htele M
    -- Combine: tail + main ≤ ε + j/3·(1/j - 1/(j+M+1)) = 1/3 + 2j/(3(j+M+1))
    have hcomb : ε + (j:ℝ)/3 * (1/(j:ℝ) - 1/((j:ℝ)+(M:ℝ)+1)) =
        1/3 + 2*(j:ℝ)/(3*((j:ℝ)+(M:ℝ)+1)) := by
      simp only [ε]; field_simp; ring
    linarith
  -- Now take the limit: for any ε > 0, choose M large enough.
  by_contra h_neg; push Not at h_neg
  obtain ⟨N₀, hN₀⟩ := exists_nat_gt (2*(j:ℝ)/(3*(gramEntry j j - 1/3)))
  have hM := hbound N₀
  have hδ_pos : 0 < gramEntry j j - 1/3 := by linarith
  have key : 2*(j:ℝ)/(3*((j:ℝ)+(N₀:ℝ)+1)) < gramEntry j j - 1/3 := by
    rw [div_lt_iff₀ (by positivity : (0:ℝ) < 3*((j:ℝ)+(N₀:ℝ)+1))]
    have h1 : 2*(j:ℝ) < 3*(gramEntry j j - 1/3)*N₀ := by
      rw [div_lt_iff₀ (by positivity : (0:ℝ) < 3*(gramEntry j j - 1/3))] at hN₀; linarith
    nlinarith [show (0:ℝ) ≤ (j:ℝ) from by positivity]
  linarith

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
    push Not at hle
    have : gramEntry j j ≤ 1 / 3 := gramEntry_le_third j (by omega)
    linarith [show (0:ℝ) ≤ 1 / (j:ℝ)^2 from by positivity]

end
