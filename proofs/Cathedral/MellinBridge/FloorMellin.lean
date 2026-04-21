import Cathedral.MellinBridge.Basic

/-! # Cathedral.MellinBridge.FloorMellin

## Floor-division Mellin transform (k = 1 case)

Helper lemmas for proving `floor_mellin_eq_zeta`:
  ∫₀¹ ⌊1/t⌋ · t^{s-1} dt = ζ(s)/s   (Re s > 1)

### Key results
- `floor_inv_eq_on_Ioc`: ⌊1/t⌋ = n on Ioc(1/(n+1), 1/n)
- `integral_cpow_piece'`: per-piece integral formula
- `abel_sum'`: Abel summation by induction
- `piece_setIntegral`: set integral for each piece
- `integral_decomp`: inductive decomposition of the integral
- `floor_mellin_eq_zeta`: the main theorem (zero sorry)
-/

noncomputable section
open Complex Real MeasureTheory Set Filter

-- ════════════════════════════════════════════════
-- HELPER LEMMAS for floor_mellin_eq_zeta
-- Proven constructively from Mathlib primitives.
-- ════════════════════════════════════════════════

/-- On Ioc(1/(n+1), 1/n), ⌊1/t⌋ = n. -/
private lemma floor_inv_eq_on_Ioc (n : ℕ) (hn : 1 ≤ n)
    (t : ℝ) (ht_lo : 1 / ((n : ℝ) + 1) < t) (ht_hi : t ≤ 1 / (n : ℝ)) :
    ⌊(1 : ℝ) / t⌋ = (n : ℤ) := by
  have hn_pos : (0 : ℝ) < (n : ℝ) := Nat.cast_pos.mpr (by omega)
  have hn1_pos : (0 : ℝ) < (n : ℝ) + 1 := by linarith
  have ht_pos : (0 : ℝ) < t := by linarith [div_pos one_pos hn1_pos]
  rw [Int.floor_eq_iff]
  constructor
  · rw [Int.cast_natCast, le_div_iff₀ ht_pos]
    nlinarith [mul_div_cancel₀ (1 : ℝ) (ne_of_gt hn_pos)]
  · rw [Int.cast_natCast, div_lt_iff₀ ht_pos]
    nlinarith [mul_div_cancel₀ (1 : ℝ) (ne_of_gt hn1_pos)]

/-- Per-piece integral: ∫_{1/(n+1)}^{1/n} t^{s-1} dt = [(1/n)^s - (1/(n+1))^s]/s. -/
private lemma integral_cpow_piece' (s : ℂ) (hs : 1 < s.re) (n : ℕ) (_hn : 1 ≤ n) :
    ∫ t in (1/((n:ℝ)+1))..(1/(n:ℝ)),
      (↑t : ℂ) ^ (s - 1) =
    ((↑(1/(n:ℝ)) : ℂ) ^ s - (↑(1/((n:ℝ)+1)) : ℂ) ^ s) / s := by
  rw [integral_cpow (Or.inl (by simp [sub_re, one_re]; linarith : -1 < (s-1).re)), sub_add_cancel]

/-- (1/n)^s = (n^s)⁻¹ for positive n, via the complex cpow API. -/
lemma ofReal_inv_cpow' (n : ℕ) (_hn : 1 ≤ n) (s : ℂ) :
    (↑(1 / (n : ℝ)) : ℂ) ^ s = ((↑(n : ℝ) : ℂ) ^ s)⁻¹ := by
  rw [one_div, ofReal_inv]
  exact inv_cpow _ _ (by
    rw [arg_ofReal_of_nonneg (le_of_lt (Nat.cast_pos.mpr (by omega)))]
    exact ne_of_gt Real.pi_pos |>.symm)

/-- (k/n)^s = k^s · n^{-s} for positive naturals, via exp/log decomposition. -/
lemma ofReal_div_cpow (k n : ℕ) (hk : 1 ≤ k) (hn : 1 ≤ n) (s : ℂ) :
    (↑((k:ℝ)/(n:ℝ)) : ℂ) ^ s = (↑(k:ℝ) : ℂ) ^ s * (↑(n:ℝ) : ℂ) ^ (-s) := by
  have hk_pos : (0:ℝ) < k := by positivity
  have hn_pos : (0:ℝ) < n := by positivity
  have hkn_ne : (↑((k:ℝ)/(n:ℝ)) : ℂ) ≠ 0 :=
    ofReal_ne_zero.mpr (ne_of_gt (div_pos hk_pos hn_pos))
  have hk_ne : (↑(k:ℝ) : ℂ) ≠ 0 := ofReal_ne_zero.mpr (ne_of_gt hk_pos)
  have hn_ne : (↑(n:ℝ) : ℂ) ≠ 0 := ofReal_ne_zero.mpr (ne_of_gt hn_pos)
  have hn_arg : (↑(n:ℝ) : ℂ).arg ≠ π := by
    rw [arg_ofReal_of_nonneg (le_of_lt hn_pos)]
    exact (ne_of_gt Real.pi_pos).symm
  have hk_arg : (↑(k:ℝ) : ℂ).arg = 0 := arg_ofReal_of_nonneg (le_of_lt hk_pos)
  have hninv_arg : ((↑(n:ℝ) : ℂ)⁻¹).arg = 0 := by
    rw [← ofReal_inv, arg_ofReal_of_nonneg (le_of_lt (inv_pos.mpr hn_pos))]
  rw [cpow_def_of_ne_zero hkn_ne, cpow_def_of_ne_zero hk_ne, cpow_def_of_ne_zero hn_ne]
  rw [← Complex.exp_add]; congr 1
  rw [ofReal_div, div_eq_mul_inv]
  rw [Complex.log_mul hk_ne (fun h => hn_ne (inv_eq_zero.mp h)) (by
    rw [hk_arg, hninv_arg]; constructor <;> linarith [Real.pi_pos])]
  rw [Complex.log_inv _ hn_arg]; ring

/-- Abel summation by induction: ∑ (n+1)(aₙ₊₁ - aₙ₊₂) = ∑ aₙ₊₁ - N·aₙ₊₁.
    Pure linear algebra — zero sorry, zero axioms. -/
private lemma abel_sum' (a : ℕ → ℂ) : ∀ N : ℕ,
    ∑ n ∈ Finset.range N, (↑(n + 1) : ℂ) * (a (n + 1) - a (n + 2)) =
    ∑ n ∈ Finset.range N, a (n + 1) - (↑N : ℂ) * a (N + 1) := by
  intro N; induction N with
  | zero => simp
  | succ k ih =>
    rw [Finset.sum_range_succ, Finset.sum_range_succ, ih]
    push_cast; ring

/-- The partial Abel sum connects to partial ζ sums. -/
private lemma partial_sum_eq' (s : ℂ) (N : ℕ) :
    ∑ n ∈ Finset.range N,
      (↑(n + 1) : ℂ) * ((↑(1/((n:ℝ)+1)) : ℂ) ^ s - (↑(1/((n:ℝ)+2)) : ℂ) ^ s) / s =
    (∑ n ∈ Finset.range N, (↑(1/((n:ℝ)+1)) : ℂ) ^ s -
      (↑N : ℂ) * (↑(1/((N:ℝ)+1)) : ℂ) ^ s) / s := by
  have hab := abel_sum' (fun n => (↑(1/(n:ℝ)) : ℂ) ^ s) N
  rw [← Finset.sum_div]; congr 1
  convert hab using 2 <;> simp [Nat.cast_add, Nat.cast_one]

/-- Converts partial sums from ofReal form to 1/n^s form for ζ connection. -/
private lemma partial_zeta_eq' (s : ℂ) (_hs : 1 < s.re) (N : ℕ) :
    ∑ n ∈ Finset.range N, (↑(1/((n:ℝ)+1)) : ℂ) ^ s =
    ∑ n ∈ Finset.range N, 1 / (↑((n:ℝ)+1) : ℂ) ^ s := by
  congr 1; ext n
  have h := ofReal_inv_cpow' (n+1) (by omega) s
  rw [show (1 / ((n : ℝ) + 1)) = (1 / (↑(n + 1) : ℝ)) from by push_cast; ring] at *
  rw [h, inv_eq_one_div]
  congr 1; push_cast; ring

/-- ‖(↑x)^s‖ = x^{Re(s)} for x > 0, proved from cpow_def. -/
lemma norm_ofReal_cpow (x : ℝ) (hx : 0 < x) (s : ℂ) : ‖(↑x : ℂ) ^ s‖ = x ^ s.re := by
  rw [cpow_def_of_ne_zero (ofReal_ne_zero.mpr (ne_of_gt hx))]
  rw [norm_exp, mul_re, log_re, log_im, arg_ofReal_of_nonneg (le_of_lt hx)]
  simp [abs_of_pos hx]
  exact (rpow_def_of_pos hx s.re).symm

open Topology in
/-- (N+1)^{1-σ} → 0 for σ > 1, via `tendsto_rpow_neg_atTop`. -/
lemma rpow_neg_tendsto' (σ : ℝ) (hσ : 1 < σ) :
    Tendsto (fun N : ℕ => ((N : ℝ) + 1) ^ (1 - σ)) atTop (nhds 0) := by
  have hp : 0 < σ - 1 := by linarith
  have h1 : Tendsto (fun N : ℕ => ((N : ℝ) + 1)) atTop atTop :=
    tendsto_atTop_add_const_right _ 1 tendsto_natCast_atTop_atTop
  have h2 := (tendsto_rpow_neg_atTop hp).comp h1
  refine h2.congr (fun N => ?_)
  simp only [Function.comp]; congr 1; ring

open Topology in
/-- N·(1/(N+1))^s → 0 as N → ∞ for Re(s) > 1.
    Proof: ‖N·(1/(N+1))^s‖ ≤ (N+1)^{1-Re(s)} → 0 by squeeze.
    Zero sorry, zero axioms. -/
lemma tail_vanishes' (s : ℂ) (hs : 1 < s.re) :
    Tendsto (fun N : ℕ => (↑N : ℂ) * (↑(1/((N:ℝ)+1)) : ℂ) ^ s) atTop (nhds 0) := by
  apply NormedAddGroup.tendsto_nhds_zero.mpr
  intro ε hε
  have h_tail := NormedAddGroup.tendsto_nhds_zero.mp (rpow_neg_tendsto' s.re hs) ε hε
  filter_upwards [h_tail] with N hN
  have hN1 : (0 : ℝ) < (N : ℝ) + 1 := by positivity
  calc ‖(↑N : ℂ) * (↑(1/((N:ℝ)+1)) : ℂ) ^ s‖
      = (N : ℝ) * ‖(↑(1/((N:ℝ)+1)) : ℂ) ^ s‖ := by
        rw [norm_mul, Complex.norm_natCast]
    _ = (N : ℝ) * (1 / ((N : ℝ) + 1)) ^ s.re := by
        rw [norm_ofReal_cpow _ (by positivity) _]
    _ ≤ ((N : ℝ) + 1) * (1 / ((N : ℝ) + 1)) ^ s.re := by
        apply mul_le_mul_of_nonneg_right _
          (rpow_nonneg (by positivity : (0:ℝ) ≤ 1/((N:ℝ)+1)) s.re)
        show (N : ℝ) ≤ (N : ℝ) + 1; linarith
    _ = ((N : ℝ) + 1) * ((N : ℝ) + 1) ^ (-s.re) := by
        congr 1; rw [one_div]
        rw [inv_rpow (by positivity : (0:ℝ) ≤ (N:ℝ)+1), rpow_neg (by positivity)]
    _ = ((N : ℝ) + 1) ^ (1 - s.re) := by
        rw [mul_comm, ← rpow_add_one (ne_of_gt hN1)]; congr 1; ring
    _ ≤ ‖((N : ℝ) + 1) ^ (1 - s.re)‖ := le_norm_self _
    _ < ε := hN

open Topology in
/-- Partial sums of ζ(s) converge: ∑_{n=0}^{N-1} 1/((n+1)^s) → ζ(s). -/
lemma partial_zeta_tendsto' (s : ℂ) (hs : 1 < s.re) :
    Tendsto (fun N : ℕ => ∑ n ∈ Finset.range N, 1 / (↑((n:ℝ)+1) : ℂ) ^ s)
      atTop (nhds (riemannZeta s)) := by
  rw [zeta_eq_tsum_one_div_nat_cpow hs]
  have h0 : (1 : ℂ) / (0 : ℂ) ^ s = 0 := by
    rw [zero_cpow (by intro h; rw [h, zero_re] at hs; linarith), div_zero]
  have hS := summable_one_div_nat_cpow.mpr hs
  have hH := hS.hasSum.tendsto_sum_nat
  apply Filter.Tendsto.congr (fun N => _) (hH.comp (tendsto_add_atTop_nat 1))
  intro N; simp only [Function.comp]
  rw [Finset.sum_range_succ']
  simp only [Nat.cast_zero, h0, add_zero]
  congr 1; ext n; congr 1; push_cast; ring

/-- The floor-weighted integrand is integrable on (0,1].
    Proof: bound ‖t^{s-1}·⌊1/t⌋‖ ≤ ‖t^{s-2}‖ via ⌊x⌋ ≤ x,
    and t^{s-2} is integrable for Re(s-2) > -1 (i.e., Re(s) > 1). -/
private lemma floor_mellin_integrableOn (s : ℂ) (hs : 1 < s.re) :
    IntegrableOn (fun x : ℝ => (↑x : ℂ) ^ (s - 1) * (↑(⌊(1 : ℝ) / x⌋) : ℂ))
      (Ioc 0 1) volume := by
  have hg : IntegrableOn (fun x : ℝ => (↑x : ℂ) ^ (s - 2)) (Ioc 0 1) volume := by
    have h := @intervalIntegral.intervalIntegrable_cpow' 0 1 (s-2) (by simp [sub_re]; linarith)
    rwa [intervalIntegrable_iff_integrableOn_Ioc_of_le (by linarith : (0:ℝ) ≤ 1)] at h
  exact Integrable.mono hg
    (by apply AEStronglyMeasurable.mul
        · exact (ContinuousOn.cpow continuous_ofReal.continuousOn continuousOn_const
            (fun x hx => by left; simp [ofReal_re]; exact hx) |>.mono Ioc_subset_Ioi_self
            ).aestronglyMeasurable measurableSet_Ioc
        · exact ((Measurable.of_discrete (α := ℤ)).comp
            ((measurable_const.div measurable_id).floor)).aestronglyMeasurable.restrict)
    (by apply ae_restrict_of_ae_restrict_of_subset Ioc_subset_Ioi_self
        apply (ae_restrict_mem measurableSet_Ioi).mono
        intro t ht; rw [mem_Ioi] at ht
        rw [norm_mul, norm_ofReal_cpow t ht, norm_ofReal_cpow t ht]
        simp only [sub_re, one_re]
        have h_nn : (0 : ℤ) ≤ ⌊(1:ℝ)/t⌋ := Int.floor_nonneg.mpr (div_nonneg one_pos.le ht.le)
        rw [Complex.norm_intCast, abs_of_nonneg (by exact_mod_cast h_nn)]
        calc t ^ (s.re - 1) * (⌊(1:ℝ)/t⌋ : ℝ)
            ≤ t ^ (s.re - 1) * (1/t) := mul_le_mul_of_nonneg_left (Int.floor_le _) (rpow_nonneg ht.le _)
          _ = t ^ (s.re - 2) := by
              rw [mul_one_div, div_eq_mul_inv, ← rpow_neg_one t, ← rpow_add ht]; congr 1; ring)

/-- ⋃_N Ioc(1/(N+1), 1) = Ioc(0, 1). -/
private lemma iUnion_Ioc_inv :
    ⋃ N : ℕ, Ioc (1 / ((N : ℝ) + 1)) 1 = Ioc (0 : ℝ) 1 := by
  ext x; simp only [mem_iUnion, mem_Ioc]; constructor
  · rintro ⟨N, hlo, hhi⟩; exact ⟨by linarith [show (0:ℝ) < 1/((N:ℝ)+1) from by positivity], hhi⟩
  · rintro ⟨hx, hx1⟩; obtain ⟨N, hN⟩ := exists_nat_gt (1/x - 1); refine ⟨N, ?_, hx1⟩
    have hN1 : (0:ℝ) < (N:ℝ)+1 := by linarith [Nat.cast_nonneg (α := ℝ) N]
    rw [div_lt_iff₀ hN1]; linarith [(div_lt_iff₀ hx).mp (by linarith : 1/x < (N:ℝ)+1)]

/-- The sequence Ioc(1/(N+1), 1) is monotone. -/
private lemma mono_Ioc_inv : Monotone (fun N : ℕ => Ioc (1 / ((N : ℝ) + 1)) (1 : ℝ)) := by
  intro m n hmn; apply Ioc_subset_Ioc_left
  apply div_le_div_of_nonneg_left (by linarith)
    (by have := Nat.cast_nonneg (α := ℝ) n; linarith)
    (by show (m:ℝ)+1 ≤ (n:ℝ)+1; have : (m:ℝ) ≤ (n:ℝ) := Nat.cast_le.mpr hmn; linarith)

/-- On piece Ioc(1/(n+2), 1/(n+1)), ⌊1/t⌋ = n+1, so the integral
    equals (n+1)·[(1/(n+1))^s - (1/(n+2))^s]/s, the n-th Abel sum term. -/
private lemma piece_setIntegral (s : ℂ) (hs : 1 < s.re) (n : ℕ) :
    ∫ t in Set.Ioc (1/((n:ℝ)+2)) (1/((n:ℝ)+1)),
      (↑t : ℂ) ^ (s - 1) * (↑(⌊(1 : ℝ) / t⌋) : ℂ)
    = (↑(n + 1) : ℂ) * (((↑(1/((n:ℝ)+1)) : ℂ) ^ s -
        (↑(1/((n:ℝ)+2)) : ℂ) ^ s) / s) := by
  -- Step 1: On this piece, ⌊1/t⌋ = n+1, so f(t) = (n+1)·t^{s-1}
  have h_eq_on : Set.EqOn
      (fun t : ℝ => (↑t : ℂ) ^ (s - 1) * (↑(⌊(1 : ℝ) / t⌋) : ℂ))
      (fun t : ℝ => (↑(n + 1) : ℂ) * (↑t : ℂ) ^ (s - 1))
      (Set.Ioc (1/((n:ℝ)+2)) (1/((n:ℝ)+1))) := by
    intro t ⟨ht_lo, ht_hi⟩
    have hfl : ⌊(1:ℝ)/t⌋ = ((n+1 : ℕ) : ℤ) := by
      apply floor_inv_eq_on_Ioc (n+1) (by omega) t
      · rwa [show 1/((↑(n+1:ℕ):ℝ)+1) = 1/((n:ℝ)+2) from by push_cast; ring]
      · rwa [show 1/(↑(n+1:ℕ):ℝ) = 1/((n:ℝ)+1) from by push_cast; ring]
    show (↑t : ℂ) ^ (s - 1) * (↑(⌊(1 : ℝ) / t⌋) : ℂ) =
         (↑(n + 1) : ℂ) * (↑t : ℂ) ^ (s - 1)
    rw [hfl]; push_cast; ring
  -- Step 2: Replace integrand and pull out constant
  rw [setIntegral_congr_fun measurableSet_Ioc h_eq_on]
  rw [show ∫ x in Set.Ioc (1/((n:ℝ)+2)) (1/((n:ℝ)+1)),
        (↑(n+1) : ℂ) * (↑x : ℂ) ^ (s-1) =
      (↑(n+1) : ℂ) * ∫ x in Set.Ioc (1/((n:ℝ)+2)) (1/((n:ℝ)+1)),
        (↑x : ℂ) ^ (s-1) from integral_const_mul _ _]
  congr 1
  -- Step 3: The set integral = the cpow formula = [(1/(n+1))^s - (1/(n+2))^s]/s
  have h := integral_cpow_piece' s hs (n+1) (by omega)
  rw [intervalIntegral.integral_of_le (show 1/((↑(n+1:ℕ):ℝ)+1) ≤ 1/(↑(n+1:ℕ):ℝ) from by
    apply div_le_div_of_nonneg_left (by linarith) (by positivity)
    linarith [Nat.cast_nonneg (α := ℝ) n])] at h
  convert h using 2 <;> push_cast <;> ring_nf

/-- Inductive decomposition: ∫_{Ioc(1/(N+1), 1)} f = partial Abel sum / s. -/
private lemma integral_decomp (s : ℂ) (hs : 1 < s.re) : ∀ N : ℕ,
    ∫ t in Set.Ioc (1/((N:ℝ)+1)) 1,
      (↑t : ℂ) ^ (s - 1) * (↑(⌊(1 : ℝ) / t⌋) : ℂ)
    = ∑ n ∈ Finset.range N,
        (↑(n + 1) : ℂ) * (((↑(1/((n:ℝ)+1)) : ℂ) ^ s -
          (↑(1/((n:ℝ)+2)) : ℂ) ^ s) / s) := by
  intro N; induction N with
  | zero =>
    simp only [Finset.range_zero, Finset.sum_empty]
    convert setIntegral_empty (f := fun t : ℝ => (↑t : ℂ) ^ (s-1) * (↑(⌊(1:ℝ)/t⌋) : ℂ))
    simp
  | succ k ih =>
    -- Ioc(1/(k+2), 1) = Ioc(1/(k+2), 1/(k+1)) ∪ Ioc(1/(k+1), 1)
    let f : ℝ → ℂ := fun x => (↑x : ℂ) ^ (s - 1) * (↑(⌊(1 : ℝ) / x⌋) : ℂ)
    have h_union : Set.Ioc (1/((k:ℝ)+2)) (1/((k:ℝ)+1)) ∪ Set.Ioc (1/((k:ℝ)+1)) 1
        = Set.Ioc (1/((k:ℝ)+2)) 1 := by
      apply Set.Ioc_union_Ioc_eq_Ioc
      · apply div_le_div_of_nonneg_left (by linarith) (by positivity)
        linarith [Nat.cast_nonneg (α := ℝ) k]
      · rw [div_le_one (by positivity : (0:ℝ) < (k:ℝ)+1)]
        linarith [Nat.cast_nonneg (α := ℝ) k]
    have h_disj : Disjoint (Set.Ioc (1/((k:ℝ)+2)) (1/((k:ℝ)+1)))
        (Set.Ioc (1/((k:ℝ)+1)) 1) := Set.Ioc_disjoint_Ioc_of_le le_rfl
    have h_int_full := floor_mellin_integrableOn s hs
    have h_int_piece : IntegrableOn f (Set.Ioc (1/((k:ℝ)+2)) (1/((k:ℝ)+1))) volume :=
      h_int_full.mono_set (fun x ⟨hlo, hhi⟩ => ⟨by
        linarith [div_pos (one_pos) (by positivity : (0:ℝ) < (k:ℝ)+2)], by
        have : 1/((k:ℝ)+1) ≤ 1 := by
          rw [div_le_one (by positivity : (0:ℝ) < (k:ℝ)+1)]
          linarith [Nat.cast_nonneg (α := ℝ) k]
        linarith⟩)
    have h_int_rest : IntegrableOn f (Set.Ioc (1/((k:ℝ)+1)) 1) volume :=
      h_int_full.mono_set (fun x ⟨hlo, hhi⟩ =>
        ⟨by linarith [div_pos (one_pos) (by positivity : (0:ℝ) < (k:ℝ)+1)], hhi⟩)
    -- Split integral over union
    rw [show (↑(k + 1) : ℝ) + 1 = (k : ℝ) + 2 from by push_cast; ring]
    rw [← h_union]
    rw [setIntegral_union h_disj measurableSet_Ioc h_int_piece h_int_rest]
    rw [Finset.sum_range_succ, ih]
    rw [show (↑k : ℝ) + 1 = ((k:ℝ) + 1) from rfl]
    rw [add_comm]
    congr 1
    exact piece_setIntegral s hs k

theorem floor_mellin_eq_zeta (s : ℂ) (hs : 1 < s.re) :
    ∫ t in Set.Ioc (0 : ℝ) 1,
      (t : ℂ) ^ (s - 1) * (↑(⌊(1 : ℝ) / t⌋) : ℂ) = riemannZeta s / s := by
  -- By monotone convergence: partial integrals → full integral
  let f : ℝ → ℂ := fun x => (↑x : ℂ) ^ (s - 1) * (↑(⌊(1 : ℝ) / x⌋) : ℂ)
  have h_tendsto_int : Tendsto
      (fun N : ℕ => ∫ x in Ioc (1/((N:ℝ)+1)) 1, f x)
      atTop (nhds (∫ x in Ioc 0 1, f x)) := by
    rw [← iUnion_Ioc_inv]
    exact tendsto_setIntegral_of_monotone (fun _ => measurableSet_Ioc) mono_Ioc_inv
      (iUnion_Ioc_inv ▸ floor_mellin_integrableOn s hs)
  show ∫ t in Set.Ioc 0 1, f t = riemannZeta s / s
  -- Rewrite partial integrals using integral_decomp
  have h_eq : ∀ N : ℕ, ∫ x in Ioc (1/((N:ℝ)+1)) 1, f x =
      ∑ n ∈ Finset.range N,
        (↑(n + 1) : ℂ) * (((↑(1/((n:ℝ)+1)) : ℂ) ^ s -
          (↑(1/((n:ℝ)+2)) : ℂ) ^ s) / s) := integral_decomp s hs
  -- Rewrite Abel sum using partial_sum_eq'
  have h_eq2 : ∀ N : ℕ, ∫ x in Ioc (1/((N:ℝ)+1)) 1, f x =
      (∑ n ∈ Finset.range N, (↑(1/((n:ℝ)+1)) : ℂ) ^ s -
        (↑N : ℂ) * (↑(1/((N:ℝ)+1)) : ℂ) ^ s) / s := by
    intro N
    rw [h_eq]
    have h := partial_sum_eq' s N
    convert h using 1
    congr 1; ext n; simp [mul_div_assoc]
  -- Build: partial integrals → ζ(s)/s
  -- First: ∑ (1/(n+1))^s → ζ(s)
  have h_zeta := partial_zeta_tendsto' s hs
  have h_zeta' : Tendsto (fun N : ℕ => ∑ n ∈ Finset.range N,
      (↑(1/((n:ℝ)+1)) : ℂ) ^ s) atTop (nhds (riemannZeta s)) := by
    have := h_zeta.congr (fun N => (partial_zeta_eq' s hs N).symm)
    exact this
  -- Second: N·(1/(N+1))^s → 0
  have h_tail := tail_vanishes' s hs
  -- Combine: (∑ - tail) / s → (ζ(s) - 0) / s = ζ(s) / s
  have h_tendsto_abel : Tendsto (fun N : ℕ =>
      (∑ n ∈ Finset.range N, (↑(1/((n:ℝ)+1)) : ℂ) ^ s -
        (↑N : ℂ) * (↑(1/((N:ℝ)+1)) : ℂ) ^ s) / s)
      atTop (nhds (riemannZeta s / s)) := by
    have h_sub := h_zeta'.sub h_tail
    simp only [sub_zero] at h_sub
    exact Tendsto.div_const h_sub s
  -- The partial integrals also tend to ζ(s)/s
  have h_tendsto_zeta : Tendsto (fun N : ℕ =>
      ∫ x in Ioc (1/((N:ℝ)+1)) 1, f x) atTop (nhds (riemannZeta s / s)) := by
    exact h_tendsto_abel.congr (fun N => (h_eq2 N).symm)
  -- By uniqueness of limits
  exact tendsto_nhds_unique h_tendsto_int h_tendsto_zeta

