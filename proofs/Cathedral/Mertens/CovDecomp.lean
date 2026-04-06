/-
  CovDecomp.lean — Building blocks for cov_eq_weighted_cross via finite sums.

  Strategy: Use finite sum decomposition + piece_cov_subst + limit argument.
-/

import Cathedral.GramOffDiag
import Cathedral.GramBounds
import Cathedral.Mertens.SubstProbe

set_option maxHeartbeats 3200000
noncomputable section
open Real MeasureTheory Set Finset intervalIntegral

-- ═══════════════════════════════════════════════
-- Part 1: Definitions and integrability
-- ═══════════════════════════════════════════════

/-- The covariance integrand. -/
private def covFun (j k : ℕ) : ℝ → ℝ :=
  fun x => (Int.fract ((j:ℝ)/x) - 1/2) * (Int.fract ((k:ℝ)/x) - 1/2)

/-- Covariance integrand is bounded by 1/4. -/
private lemma covFun_bound (j k : ℕ) (x : ℝ) : |covFun j k x| ≤ 1/4 := by
  simp only [covFun, abs_mul]
  have h1 : |Int.fract ((j:ℝ)/x) - 1/2| ≤ 1/2 := by
    have := Int.fract_nonneg ((j:ℝ)/x)
    have := Int.fract_lt_one ((j:ℝ)/x)
    rw [abs_le]; constructor <;> linarith
  have h2 : |Int.fract ((k:ℝ)/x) - 1/2| ≤ 1/2 := by
    have := Int.fract_nonneg ((k:ℝ)/x)
    have := Int.fract_lt_one ((k:ℝ)/x)
    rw [abs_le]; constructor <;> linarith
  calc |_| * |_| ≤ 1/2 * (1/2) := mul_le_mul h1 h2 (abs_nonneg _) (by linarith)
    _ = 1/4 := by ring

/-- Covariance integrand is interval integrable.
    Uses the same measurability pattern as centered_prod_integrable in GramOffDiag.lean. -/
private lemma covFun_integrable (j k : ℕ) (a b : ℝ) :
    IntervalIntegrable (covFun j k) volume a b := by
  apply IntervalIntegrable.mono_fun
    (intervalIntegral.intervalIntegrable_const (c := (1:ℝ)))
  · -- AEStronglyMeasurable via Measurable
    have h1 : Measurable (fun x : ℝ => Int.fract ((j:ℝ)/x) - 1/2) :=
      (measurable_fract_real.comp (measurable_const.div measurable_id)).sub measurable_const
    have h2 : Measurable (fun x : ℝ => Int.fract ((k:ℝ)/x) - 1/2) :=
      (measurable_fract_real.comp (measurable_const.div measurable_id)).sub measurable_const
    exact (h1.mul h2).aestronglyMeasurable.restrict
  · -- ‖covFun‖ ≤ 1 a.e.
    filter_upwards with x
    simp only [covFun, Real.norm_eq_abs, abs_one]
    have hfj := Int.fract_nonneg ((j:ℝ)/x)
    have hfj' := Int.fract_lt_one ((j:ℝ)/x)
    have hfk := Int.fract_nonneg ((k:ℝ)/x)
    have hfk' := Int.fract_lt_one ((k:ℝ)/x)
    rw [abs_le]; constructor <;> nlinarith

-- ═══════════════════════════════════════════════
-- Part 2: Finite sum decomposition
-- ═══════════════════════════════════════════════

/-- Finite sum of adjacent pieces: ∫_{1/(N+1)}^1 covFun = Σ_{n<N} ∫_{piece_n}. -/
private lemma finite_sum_pieces (j k : ℕ) (N : ℕ) :
    ∫ x in (1/((N:ℝ)+1))..1, covFun j k x =
    (Finset.range N).sum (fun n =>
      ∫ x in (1/((n:ℝ)+2))..(1/((n:ℝ)+1)), covFun j k x) := by
  induction N with
  | zero => simp
  | succ m ih =>
    rw [Finset.sum_range_succ, ← ih]
    -- After sum_range_succ + ih, goal is:
    -- ∫_{1/((m+1)+1)}^1 = (∫_{1/(m+1)}^1) + ∫_{piece_m}
    -- Use add_comm and integral_add_adjacent_intervals
    have hcast : ((m + 1 : ℕ) : ℝ) + 1 = (m:ℝ) + 2 := by push_cast; ring
    have hsplit := integral_add_adjacent_intervals
      (a := 1/((m:ℝ)+2)) (b := 1/((m:ℝ)+1)) (c := (1:ℝ))
      (covFun_integrable j k _ _) (covFun_integrable j k _ _)
    -- hsplit : ∫_{1/(m+2)}^{1/(m+1)} + ∫_{1/(m+1)}^1 = ∫_{1/(m+2)}^1
    show ∫ x in 1 / ((↑(m + 1) : ℝ) + 1)..1, covFun j k x =
      (∫ x in (1/((m:ℝ)+1))..1, covFun j k x) +
      ∫ x in (1/((m:ℝ)+2))..(1/((m:ℝ)+1)), covFun j k x
    rw [hcast, ← hsplit, add_comm]

-- ═══════════════════════════════════════════════
-- Part 3: Piece substitution
-- ═══════════════════════════════════════════════

/-- The weighted cross-product integrand for the n-th piece. -/
private def weightedCross (j k : ℕ) (n : ℕ) : ℝ → ℝ :=
  fun t => (Int.fract ((j:ℝ) * t) - 1/2) * (Int.fract ((k:ℝ) * t) - 1/2) /
           ((n:ℝ) + 1 + t)^2

/-- Each piece integral equals the weighted cross-product. -/
private lemma piece_eq_weighted (j k n : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k) :
    ∫ x in (1/((n:ℝ)+2))..(1/((n:ℝ)+1)), covFun j k x =
    ∫ t in (0:ℝ)..1, weightedCross j k n t := by
  show ∫ x in (1/((n:ℝ)+2))..(1/((n:ℝ)+1)),
    (Int.fract ((j:ℝ)/x) - 1/2) * (Int.fract ((k:ℝ)/x) - 1/2) =
    ∫ t in (0:ℝ)..1,
      (Int.fract ((j:ℝ) * t) - 1/2) * (Int.fract ((k:ℝ) * t) - 1/2) /
      ((n:ℝ) + 1 + t)^2
  exact piece_cov_subst j k n hj hk

/-- Finite sum: ∫_{1/(N+1)}^1 covFun = Σ_{n<N} ∫₀¹ weightedCross n  -/
private lemma finite_sum_eq_weighted (j k : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k) (N : ℕ) :
    ∫ x in (1/((N:ℝ)+1))..1, covFun j k x =
    (Finset.range N).sum (fun n =>
      ∫ t in (0:ℝ)..1, weightedCross j k n t) := by
  rw [finite_sum_pieces j k N]
  congr 1; ext n
  exact piece_eq_weighted j k n hj hk

-- ═══════════════════════════════════════════════
-- Part 4: Limit argument
-- ═══════════════════════════════════════════════

/-- ∫₀¹ = ∫₀^{1/(N+1)} + ∫_{1/(N+1)}^1 -/
private lemma cov_split (j k : ℕ) (N : ℕ) :
    ∫ x in (0:ℝ)..1, covFun j k x =
    (∫ x in (0:ℝ)..(1/((N:ℝ)+1)), covFun j k x) +
    ∫ x in (1/((N:ℝ)+1))..1, covFun j k x :=
  (integral_add_adjacent_intervals
    (covFun_integrable j k 0 (1/((N:ℝ)+1)))
    (covFun_integrable j k (1/((N:ℝ)+1)) 1)).symm

/-- The tail ∫₀^{1/(N+1)} covFun → 0 as N → ∞. -/
private lemma cov_tail_tendsto (j k : ℕ) :
    Filter.Tendsto (fun N : ℕ =>
      ∫ x in (0:ℝ)..(1/((N:ℝ)+1)), covFun j k x)
      Filter.atTop (nhds 0) := by
  -- |∫₀^{1/(N+1)} covFun| ≤ (1/4) · 1/(N+1) → 0
  apply squeeze_zero_norm
  · -- ‖∫₀^{1/(N+1)} covFun‖ ≤ 1/4 * 1/(N+1)
    intro N
    calc ‖∫ x in (0:ℝ)..(1/((N:ℝ)+1)), covFun j k x‖
        ≤ (1/4) * |1/((N:ℝ)+1) - 0| := by
          apply intervalIntegral.norm_integral_le_of_norm_le_const_ae
          apply Filter.Eventually.of_forall
          intro x _
          rw [Real.norm_eq_abs]
          exact covFun_bound j k x
      _ = 1/4 * (1/((N:ℝ)+1)) := by
          rw [sub_zero, abs_of_pos (by positivity)]
  · -- (1/4) · 1/(N+1) → 0
    have : Filter.Tendsto (fun N : ℕ => (1:ℝ)/4 * (1/((N:ℝ)+1)))
        Filter.atTop (nhds (1/4 * 0)) := by
      apply Filter.Tendsto.const_mul
      have h1 : Filter.Tendsto (fun N : ℕ => ((↑N:ℝ)+1)) Filter.atTop Filter.atTop :=
        Filter.Tendsto.atTop_add tendsto_natCast_atTop_atTop tendsto_const_nhds
      have h2 : Filter.Tendsto (fun N : ℕ => ((↑N:ℝ)+1)⁻¹) Filter.atTop (nhds 0) :=
        Filter.Tendsto.inv_tendsto_atTop h1
      convert h2 using 1
      simp [one_div]
    simp only [mul_zero] at this
    convert this using 1

-- ═══════════════════════════════════════════════
-- Part 5: The main theorem
-- ═══════════════════════════════════════════════

/-- Partial sums equal the full integral minus the tail. -/
private lemma partial_sum_eq (j k : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k) (N : ℕ) :
    (Finset.range N).sum (fun n =>
      ∫ t in (0:ℝ)..1, weightedCross j k n t) =
    (∫ x in (0:ℝ)..1, covFun j k x) -
    ∫ x in (0:ℝ)..(1/((N:ℝ)+1)), covFun j k x := by
  have h1 := cov_split j k N
  -- h1 : ∫₀¹ f = (∫₀^ε f) + ∫_ε^1 f
  have h2 := finite_sum_eq_weighted j k hj hk N
  -- h2 : ∫_ε^1 f = Σ_{n<N} ∫₀¹ wn
  linarith

/-- Partial sums tend to ∫₀¹ covFun. -/
private lemma partial_sum_tendsto (j k : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k) :
    Filter.Tendsto (fun N => (Finset.range N).sum (fun n =>
      ∫ t in (0:ℝ)..1, weightedCross j k n t))
    Filter.atTop (nhds (∫ x in (0:ℝ)..1, covFun j k x)) := by
  simp_rw [partial_sum_eq j k hj hk]
  have htail := cov_tail_tendsto j k
  have key : Filter.Tendsto (fun N : ℕ =>
      (∫ x in (0:ℝ)..1, covFun j k x) -
      ∫ x in (0:ℝ)..(1/((N:ℝ)+1)), covFun j k x)
      Filter.atTop (nhds ((∫ x in (0:ℝ)..1, covFun j k x) - 0)) :=
    Filter.Tendsto.sub tendsto_const_nhds htail
  simp only [sub_zero] at key
  convert key using 1

/-- The series of weighted cross-products is summable.
    Partial sums of ‖term_n‖ are bounded by 1/4 (telescoping weight). -/
private lemma weighted_cross_summable (j k : ℕ) :
    Summable (fun n => ∫ t in (0:ℝ)..1, weightedCross j k n t) := by
  -- Each ‖term_n‖ ≤ 1/4 · (1/(n+1) - 1/(n+2)) which telescopes to ≤ 1/4
  apply summable_of_sum_range_norm_le (c := 1/4)
  intro N
  -- Goal: Σ_{n<N} ‖∫₀¹ wCross_n‖ ≤ 1/4
  calc ∑ n ∈ Finset.range N, ‖∫ t in (0:ℝ)..1, weightedCross j k n t‖
      ≤ ∑ n ∈ Finset.range N, (1/4 * (1/((n:ℝ)+1) - 1/((n:ℝ)+2))) := by
        apply Finset.sum_le_sum; intro n _
        rw [Real.norm_eq_abs]
        -- |∫₀¹ F/(n+1+t)²| ≤ (1/4)·(1/(n+1) - 1/(n+2))
        -- Use: ‖∫ f‖ ≤ ∫ g when ‖f(t)‖ ≤ g(t) a.e.
        -- with g(t) = (1/4)/(n+1+t)², using covFun_bound
        have hbound : ∀ t ∈ Set.Ioc (0:ℝ) 1,
            ‖weightedCross j k n t‖ ≤ 1/4 * (1 / ((n:ℝ) + 1 + t)^2) := by
          intro t ht
          rw [Real.norm_eq_abs]; simp only [weightedCross]
          have hpos : (0:ℝ) < (n:ℝ) + 1 + t := by
            have : (0:ℝ) ≤ (n:ℝ) := Nat.cast_nonneg _; linarith [ht.1]
          rw [abs_div, abs_of_pos (pow_pos hpos 2)]
          rw [mul_div_assoc']
          apply div_le_div_of_nonneg_right _ (pow_pos hpos 2).le
          -- |({jt}-½)({kt}-½)| ≤ 1/4: each factor ∈ [-1/2, 1/2]
          have hfj := Int.fract_nonneg ((j:ℝ)*t)
          have hfj' := Int.fract_lt_one ((j:ℝ)*t)
          have hfk := Int.fract_nonneg ((k:ℝ)*t)
          have hfk' := Int.fract_lt_one ((k:ℝ)*t)
          rw [abs_le]; constructor <;> nlinarith
        have hg_int : IntervalIntegrable
            (fun t => 1/4 * (1 / ((n:ℝ) + 1 + t)^2)) volume 0 1 := by
          apply ContinuousOn.intervalIntegrable
          apply ContinuousOn.const_mul
          apply ContinuousOn.div continuousOn_const
          · exact ((continuous_const.add continuous_id).pow 2).continuousOn
          · intro t ht
            have hpos : (0:ℝ) < (n:ℝ) + 1 + t := by
              simp [Set.uIcc, Set.mem_Icc] at ht
              have : (0:ℝ) ≤ (n:ℝ) := Nat.cast_nonneg _; linarith [ht.1]
            exact pow_ne_zero 2 (ne_of_gt hpos)
        have h_le := intervalIntegral.norm_integral_le_of_norm_le
          (by norm_num : (0:ℝ) ≤ 1)
          (Filter.Eventually.of_forall hbound) hg_int
        rw [Real.norm_eq_abs] at h_le
        calc |∫ t in (0:ℝ)..1, weightedCross j k n t|
            ≤ ∫ t in (0:ℝ)..1, 1/4 * (1 / ((n:ℝ) + 1 + t)^2) := h_le
          _ = 1/4 * ∫ t in (0:ℝ)..1, 1 / ((n:ℝ) + 1 + t)^2 := by
              rw [intervalIntegral.integral_const_mul]
          _ = 1/4 * (1/((n:ℝ)+1) - 1/((n:ℝ)+2)) := by
              congr 1
              -- FTC: antiderivative of 1/(n+1+t)² is -1/(n+1+t)
              have hpos : ∀ t ∈ Set.uIcc (0:ℝ) 1, (0:ℝ) < (n:ℝ) + 1 + t := by
                intro t ht
                simp [Set.uIcc, Set.mem_Icc] at ht
                have : (0:ℝ) ≤ (n:ℝ) := Nat.cast_nonneg _; linarith [ht.1]
              have hderiv : ∀ t ∈ Set.uIcc (0:ℝ) 1,
                  HasDerivAt (fun s => -(1:ℝ) / ((n:ℝ) + 1 + s)) (1 / ((n:ℝ) + 1 + t)^2) t := by
                intro t ht
                have hne : (n:ℝ) + 1 + t ≠ 0 := ne_of_gt (hpos t ht)
                have hd : HasDerivAt (fun s => (n:ℝ) + 1 + s) 1 t := by
                  convert (hasDerivAt_const t ((n:ℝ) + 1)).add (hasDerivAt_id t) using 1; ring
                have key : HasDerivAt (fun s => -((n:ℝ) + 1 + s)⁻¹) (1/((n:ℝ) + 1 + t)^2) t := by
                  convert (hd.inv hne).neg using 1; simp [neg_div]
                convert key using 1; ext s; simp [div_eq_mul_inv]
              have hint : IntervalIntegrable (fun t => (1:ℝ) / ((n:ℝ)+1+t)^2) volume 0 1 := by
                apply ContinuousOn.intervalIntegrable
                apply ContinuousOn.div continuousOn_const
                · exact ((continuous_const.add continuous_id).pow 2).continuousOn
                · intro t ht; exact pow_ne_zero 2 (ne_of_gt (hpos t ht))
              rw [intervalIntegral.integral_eq_sub_of_hasDerivAt hderiv hint]
              simp [div_eq_mul_inv]; ring
    _ = 1/4 * ∑ n ∈ Finset.range N, (1/((n:ℝ)+1) - 1/((n:ℝ)+2)) := by
        rw [Finset.mul_sum]
    _ ≤ 1/4 := by
        rw [weight_telescope]
        have hN : (0:ℝ) < (N:ℝ) + 1 := by positivity
        have : 0 < 1 / ((N:ℝ) + 1) := div_pos one_pos hN
        nlinarith

/-- **MAIN THEOREM (exported)**:
    The covariance integral equals a tsum of weighted cross-products.

    ∫₀¹ ({j/x}-½)({k/x}-½) dx = Σₙ ∫₀¹ ({jt}-½)({kt}-½) / (n+1+t)² dt -/
theorem cov_eq_weighted_cross (j k : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k) :
    ∫ x in (0:ℝ)..1, (Int.fract ((j:ℝ)/x) - 1/2) * (Int.fract ((k:ℝ)/x) - 1/2) =
    ∑' (n : ℕ), ∫ t in (0:ℝ)..1,
      (Int.fract ((j:ℝ) * t) - 1/2) * (Int.fract ((k:ℝ) * t) - 1/2) /
      ((n : ℝ) + 1 + t)^2 := by
  -- Show HasSum from summable + partial sum convergence
  have hsumm := weighted_cross_summable j k
  have htend := partial_sum_tendsto j k hj hk
  -- Since the series is summable and partial sums → C, we have tsum = C
  have hhas : HasSum (fun n => ∫ t in (0:ℝ)..1, weightedCross j k n t)
      (∫ x in (0:ℝ)..1, covFun j k x) := by
    -- summable → hasSum (tsum f), and partial sums → tsum f
    have hs := hsumm.hasSum
    -- but partial sums also → ∫ covFun (from partial_sum_tendsto)
    -- by uniqueness of limits in Hausdorff space, tsum = ∫ covFun
    have h1 := hs.tendsto_sum_nat
    have h2 := htend
    have : ∑' n, (∫ t in (0:ℝ)..1, weightedCross j k n t) =
        ∫ x in (0:ℝ)..1, covFun j k x :=
      tendsto_nhds_unique h1 h2
    rw [this] at hs; exact hs
  -- tsum_eq from HasSum
  have key := hhas.tsum_eq.symm
  -- Bridge to raw expressions via convert
  convert key using 1

end
