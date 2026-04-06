/-
  Cathedral/Scratch/OffDiagBound.lean

  Proof of gram_entry_offdiag_upper:
    gramEntry j k ≤ 1/4 + gcd(j,k)/(j*k)  for j ≠ k.

  Architecture:
    gramEntry_le_quarter_plus_cov  (from GramOffDiag.lean, PROVED)
      + cov_le_gcd_div             (covariance ≤ gcd/(jk))
      = gram_entry_offdiag_upper'  (main theorem)

  Proof decomposition for cov_le_gcd_div:
    Step 1: cov_eq_weighted_cross (substitution u=1/x, SORRY)
      Cov = Σ_n ∫₀¹ ({jt}-½)({kt}-½) · 1/(n+t)² dt
    Step 2: cross_product_general (BernoulliCross.lean, SORRY)
      ∫₀¹ ({jt}-½)({kt}-½) dt = gcd²/(12jk)
    Step 3: weight_correction_bound (weight analysis, SORRY)
      The weighted integral ≤ gcd/(jk)
-/

import Cathedral.GramOffDiag
import Cathedral.GramBounds
import Cathedral.Mertens.CovDecomp

set_option maxHeartbeats 800000
noncomputable section
open Real MeasureTheory Set Finset

-- ═══════════════════════════════════════════════
-- Step 1: Weighted cross-product decomposition
-- ═══════════════════════════════════════════════

/-- The covariance integral decomposes via u=1/x into a weighted sum
    of cross-products of fractional parts.

    ∫₀¹ ({j/x}-½)({k/x}-½) dx
      = Σ_{n≥1} ∫₀¹ ({j(n+t)}-½)({k(n+t)}-½) / (n+t)² dt
      = Σ_{n≥1} ∫₀¹ ({jt}-½)({kt}-½) / (n+t)² dt

    The last equality uses {j(n+t)} = {jt} for integer n. -/
private lemma cov_eq_weighted_cross' (j k : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k) :
    ∫ x in (0:ℝ)..1, (Int.fract ((j:ℝ)/x) - 1/2) * (Int.fract ((k:ℝ)/x) - 1/2) =
    ∑' (n : ℕ), ∫ t in (0:ℝ)..1,
      (Int.fract ((j:ℝ) * t) - 1/2) * (Int.fract ((k:ℝ) * t) - 1/2) /
      ((n : ℝ) + 1 + t)^2 :=
  cov_eq_weighted_cross j k hj hk

-- ═══════════════════════════════════════════════
-- Step 2: Weight total = 1 (telescoping)
-- ═══════════════════════════════════════════════

/-- Each weight piece: ∫₀¹ 1/(n+1+t)² dt = 1/(n+1) - 1/(n+2).
    Proof: FTC with antiderivative -1/(n+1+t). -/
private lemma weight_piece (n : ℕ) :
    ∫ t in (0:ℝ)..1, (1 : ℝ) / ((n : ℝ) + 1 + t)^2 =
    1 / ((n : ℝ) + 1) - 1 / ((n : ℝ) + 2) := by
  have hpos : ∀ t ∈ Set.uIcc (0:ℝ) 1, (0:ℝ) < (n : ℝ) + 1 + t := by
    intro t ht
    have h01 : Set.uIcc (0:ℝ) 1 = Set.Icc (0:ℝ) 1 := by
      simp [Set.uIcc]
    rw [h01, Set.mem_Icc] at ht
    have : (0:ℝ) ≤ (n : ℝ) := Nat.cast_nonneg' n
    linarith [ht.1]
  have hderiv : ∀ t ∈ Set.uIcc (0:ℝ) 1,
      HasDerivAt (fun s => -(1 : ℝ) / ((n : ℝ) + 1 + s))
        (1 / ((n : ℝ) + 1 + t)^2) t := by
    intro t ht
    have hne : (n : ℝ) + 1 + t ≠ 0 := ne_of_gt (hpos t ht)
    have hd : HasDerivAt (fun s => (n : ℝ) + 1 + s) 1 t := by
      convert (hasDerivAt_const t ((n : ℝ) + 1)).add (hasDerivAt_id t) using 1; ring
    -- d/dt[-(n+1+t)⁻¹] = (n+1+t)⁻²
    have h := hd.inv hne
    -- h : HasDerivAt (fun s => (n+1+s)⁻¹) (-(1)/(n+1+t)²) t
    -- We want: HasDerivAt (fun s => -1/(n+1+s)) (1/(n+1+t)²) t
    have key : HasDerivAt (fun s => -((n : ℝ) + 1 + s)⁻¹) (1 / ((n : ℝ) + 1 + t)^2) t := by
      convert h.neg using 1; simp [neg_div]
    convert key using 1
    ext s; simp [div_eq_mul_inv]
  have hint : IntervalIntegrable (fun t => (1:ℝ) / ((n:ℝ) + 1 + t)^2) MeasureTheory.volume 0 1 := by
    apply ContinuousOn.intervalIntegrable
    apply ContinuousOn.div continuousOn_const
    · exact (((continuous_const.add continuous_id).pow 2).continuousOn)
    · intro t ht; exact pow_ne_zero 2 (ne_of_gt (hpos t ht))
  rw [intervalIntegral.integral_eq_sub_of_hasDerivAt hderiv hint]
  simp [div_eq_mul_inv]; ring

/-- **Weight total**: Σ_{n≥0} ∫₀¹ 1/(n+1+t)² dt = 1.
    By telescoping: Σ (1/(n+1) - 1/(n+2)) = 1. -/
private lemma weight_total_one :
    ∑' (n : ℕ), ∫ t in (0:ℝ)..1, (1 : ℝ) / ((n : ℝ) + 1 + t)^2 = 1 := by
  -- Partial sums telescope: Σ_{n<N} = 1 - 1/(N+1) → 1
  -- Each term is 1/(n+1) - 1/(n+2) by weight_piece
  have hpartial : ∀ N : ℕ,
    (Finset.range N).sum (fun n =>
      ∫ t in (0:ℝ)..1, (1:ℝ) / ((n:ℝ) + 1 + t)^2) =
    1 - 1 / ((N : ℝ) + 1) := by
    intro N; induction N with
    | zero => simp
    | succ k ih =>
      rw [Finset.sum_range_succ, ih, weight_piece]
      push_cast; ring
  -- HasSum from partial sums via limit 1 - 1/(N+1) → 1
  suffices htend : Filter.Tendsto (fun N => (Finset.range N).sum (fun n =>
      ∫ t in (0:ℝ)..1, (1:ℝ) / ((n:ℝ) + 1 + t)^2)) Filter.atTop (nhds 1) by
    exact ((hasSum_iff_tendsto_nat_of_nonneg (fun n => by
      apply intervalIntegral.integral_nonneg (by norm_num : (0:ℝ) ≤ 1)
      intro t _; positivity) 1).mpr htend).tsum_eq
  simp_rw [hpartial, one_div]
  have h0 : Filter.Tendsto (fun N : ℕ => ((N : ℝ) + 1)⁻¹) Filter.atTop (nhds 0) := by
    have h1 : Filter.Tendsto (fun N : ℕ => ((N : ℝ) + 1)) Filter.atTop Filter.atTop :=
      Filter.Tendsto.atTop_add tendsto_natCast_atTop_atTop tendsto_const_nhds
    exact Filter.Tendsto.inv_tendsto_atTop h1
  have key : Filter.Tendsto (fun N : ℕ => (1 : ℝ) - ((N : ℝ) + 1)⁻¹)
      Filter.atTop (nhds ((1:ℝ) - 0)) :=
    Filter.Tendsto.sub (tendsto_const_nhds (x := (1:ℝ))) h0
  simp at key; exact key



-- ═══════════════════════════════════════════════
-- Step 3: The covariance bound (IBP approach)
-- ═══════════════════════════════════════════════

/-- **Running average bound** for coprime Bernoulli cross products.

    For coprime a,b ≥ 1 with a ≠ b, the "centered running integral"
    Ψ(c) = ∫₀ᶜ ({au}-½)({bu}-½) du - c/(12ab)
    satisfies |Ψ(c)| ≤ 1/(4·max(a,b)) for all c ∈ [0,1].

    Since Ψ(0) = Ψ(1) = 0 (exact integral matches the mean),
    the max deviation within a period is controlled by the piece
    structure from CoprimeCross.lean.

    **Status**: Elementary number theory + piecewise integration.
    The bound follows from analyzing the quadratic running integral
    on each sub-interval [k/max(a,b), (k+1)/max(a,b)]. -/
private lemma running_avg_bound (a b : ℕ) (ha : 1 ≤ a) (hb : 1 ≤ b)
    (_hne : a ≠ b) (_hcop : Nat.Coprime a b) (c : ℝ) (hc : c ∈ Icc (0:ℝ) 1) :
    |∫ u in (0:ℝ)..c,
      (Int.fract ((a:ℝ) * u) - 1/2) * (Int.fract ((b:ℝ) * u) - 1/2) -
      c / (12 * (a:ℝ) * (b:ℝ))| ≤
    1 / (4 * max (a:ℝ) (b:ℝ)) := by
  sorry

/-- **KEY LEMMA**: Cov ≤ gcd/(jk) for j,k ≥ 1.

    **Proof strategy** (IBP + telescoping):
    1. Decompose F = F₀ + F̃ where F₀ = g²/(12jk) and F̃ is mean-zero periodic
    2. Mean term: F₀ · Σ weights = g²/(12jk) · 1 = g²/(12jk)
    3. Error term: By IBP, ∫ F̃·wₙ = -∫ Ψ·wₙ' where Ψ is the running integral
       Since Ψ(0) = Ψ(1) = 0 (complete periods) and |wₙ'| integrates to
       1/(n+1)² - 1/(n+2)², the error telescopes to ≤ max|Ψ|
    4. Running average bound: max|Ψ| ≤ 1/(4g·max(a,b)) from periodicity
    5. Total: Cov ≤ g²/(12jk) + 1/(4g·max(a,b)) ≤ g/(jk) ✓ -/
private lemma cov_le_gcd_div (j k : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k) :
    ∫ x in (0:ℝ)..1, (Int.fract ((j:ℝ)/x) - 1/2) * (Int.fract ((k:ℝ)/x) - 1/2) ≤
    (Nat.gcd j k : ℝ) / ((j : ℝ) * (k : ℝ)) := by
  rw [cov_eq_weighted_cross' j k hj hk]
  -- The full proof uses IBP + running average bound.
  -- For now, the structure is verified and the sorry isolates
  -- the analytical core (running_avg_bound + IBP machinery).
  sorry

-- ═══════════════════════════════════════════════
-- Main theorem (fully proved modulo cov_le_gcd_div)
-- ═══════════════════════════════════════════════

/-- **MAIN THEOREM**: gramEntry j k ≤ 1/4 + gcd(j,k)/(j*k) for j ≠ k.
    Replaces the axiom in GramEntry.lean. -/
theorem gram_entry_offdiag_upper' (j k : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k) (_hjk : j ≠ k) :
    gramEntry j k ≤ 1 / 4 + (Nat.gcd j k : ℝ) / ((j : ℝ) * (k : ℝ)) := by
  linarith [gramEntry_le_quarter_plus_cov j k hj hk, cov_le_gcd_div j k hj hk]

end
