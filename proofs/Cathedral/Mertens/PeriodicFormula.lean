/-
  Cathedral/Scratch/PeriodicFormula.lean

  Proof of ∫₀¹ t·{nt} dt = (3n+1)/(12n), following the telescope pattern
  established in FractIntegral.lean.
-/

import Cathedral.GramOffDiag
import Cathedral.GramBounds

set_option maxHeartbeats 800000

noncomputable section
open Real MeasureTheory Set Finset

-- ═══════════════════════════════════════════════
-- Step 0: Antiderivative
-- ═══════════════════════════════════════════════

/-- HasDerivAt for t·(nt-m) = nt²-mt. Antiderivative: nt³/3 - mt²/2. -/
private lemma antideriv_fract_linear (n m : ℕ) (x : ℝ) :
    HasDerivAt (fun t => (n : ℝ) * t^3 / 3 - (m : ℝ) * t^2 / 2)
      (x * ((n : ℝ) * x - (m : ℝ))) x := by
  have h1 := (hasDerivAt_pow 3 x).const_mul (n : ℝ)
  have h2 := (hasDerivAt_pow 2 x).const_mul (m : ℝ)
  convert (h1.div_const 3).sub (h2.div_const 2) using 1
  ring

-- ═══════════════════════════════════════════════
-- Step 1: Piece integral
-- ═══════════════════════════════════════════════

/-- ∫_{m/n}^{(m+1)/n} t·(nt-m) dt = (3m+2)/(6n²). -/
lemma fract_linear_piece (n m : ℕ) (hn : 1 ≤ n) :
    ∫ t in ((m : ℝ) / (n : ℝ))..((↑m + 1) / (n : ℝ)),
      t * ((n : ℝ) * t - (m : ℝ)) = (3 * (m : ℝ) + 2) / (6 * (n : ℝ)^2) := by
  have hn_pos : (0 : ℝ) < (n : ℝ) := Nat.cast_pos.mpr (by omega)
  have hcont : ContinuousOn (fun t => t * ((n : ℝ) * t - (m : ℝ)))
      (Set.uIcc ((m : ℝ)/(n : ℝ)) (((m : ℝ)+1)/(n : ℝ))) :=
    ContinuousOn.mul continuousOn_id
      ((continuousOn_const.mul continuousOn_id).sub continuousOn_const)
  rw [intervalIntegral.integral_eq_sub_of_hasDerivAt
    (fun x _ => antideriv_fract_linear n m x)
    hcont.intervalIntegrable]
  field_simp
  ring

-- ═══════════════════════════════════════════════
-- Step 2: Measurability and Integrability
-- ═══════════════════════════════════════════════

/-- t ↦ Int.fract(n*t) is measurable. -/
private lemma measurable_fract_mul (n : ℕ) :
    Measurable (fun t : ℝ => Int.fract ((n : ℝ) * t)) :=
  measurable_fract_real.comp (measurable_const.mul measurable_id)

/-- |t| ≤ max |a| |b| when t ∈ uIoc a b. -/
private lemma abs_le_max_abs_of_uIoc {a b t : ℝ}
    (ht : t ∈ Set.uIoc a b) : |t| ≤ max |a| |b| := by
  rw [Set.uIoc, Set.mem_Ioc] at ht
  rcases le_or_gt 0 t with h_nonneg | h_neg
  · rw [abs_of_nonneg h_nonneg]
    calc t ≤ max a b := ht.2
      _ ≤ max |a| |b| := max_le_max (le_abs_self a) (le_abs_self b)
  · rw [abs_of_neg h_neg]
    have hmin : min a b < 0 := lt_of_lt_of_le (by linarith : min a b < t) (le_of_lt h_neg)
    have : -t ≤ -(min a b) := by linarith [ht.1]
    rcases min_choice a b with ha | hb
    · rw [ha] at this
      calc -t ≤ -a := this
        _ = |a| := by rw [abs_of_neg (by linarith [ha, hmin] : a < 0)]
        _ ≤ max |a| |b| := le_max_left _ _
    · rw [hb] at this
      calc -t ≤ -b := this
        _ = |b| := by rw [abs_of_neg (by linarith [hb, hmin] : b < 0)]
        _ ≤ max |a| |b| := le_max_right _ _

/-- t * Int.fract(n*t) is integrable on any interval.
    Proof: measurable and bounded by max(|a|,|b|) on uIoc. -/
private lemma fract_linear_integrable (n : ℕ) (a b : ℝ) :
    IntervalIntegrable (fun t => t * Int.fract ((n : ℝ) * t)) volume a b := by
  apply IntervalIntegrable.mono_fun (intervalIntegrable_const (c := max (|a|) (|b|)))
  · exact (measurable_id.mul (measurable_fract_mul n)).aestronglyMeasurable.restrict
  · filter_upwards [ae_restrict_mem measurableSet_uIoc] with t ht
    rw [Real.norm_eq_abs, Real.norm_eq_abs, abs_mul,
        abs_of_nonneg (le_max_of_le_left (abs_nonneg a))]
    calc |t| * |Int.fract ((n : ℝ) * t)|
        ≤ |t| * 1 := mul_le_mul_of_nonneg_left
            (by rw [abs_of_nonneg (Int.fract_nonneg _)]; exact le_of_lt (Int.fract_lt_one _))
            (abs_nonneg _)
      _ = |t| := mul_one _
      _ ≤ max |a| |b| := abs_le_max_abs_of_uIoc ht

-- ═══════════════════════════════════════════════
-- Step 3: On each piece, t·{nt} = t·(nt-m) a.e.
-- ═══════════════════════════════════════════════

/-- On (m/n, (m+1)/n), {nt} = nt - m. -/
lemma fract_nat_mul_piece (n m : ℕ) (hn : 1 ≤ n) (hm : m < n)
    (t : ℝ) (ht_lo : (m : ℝ) / (n : ℝ) < t) (ht_hi : t < ((m : ℝ) + 1) / (n : ℝ)) :
    Int.fract ((n : ℝ) * t) = (n : ℝ) * t - (m : ℝ) := by
  have hn_pos : (0 : ℝ) < (n : ℝ) := Nat.cast_pos.mpr (by omega)
  unfold Int.fract
  have hfloor : ⌊(n : ℝ) * t⌋ = (m : ℤ) := by
    rw [Int.floor_eq_iff]
    constructor
    · rw [Int.cast_natCast]
      nlinarith [mul_div_cancel₀ (m : ℝ) (ne_of_gt hn_pos)]
    · rw [Int.cast_natCast]
      have := mul_div_cancel₀ ((m : ℝ) + 1) (ne_of_gt hn_pos)
      push_cast; nlinarith
  rw [hfloor, Int.cast_natCast]

/-- On each piece, the integrals agree (ae on the Ioc). -/
lemma fract_linear_piece_eq (n m : ℕ) (hn : 1 ≤ n) (hm : m < n) :
    ∫ t in ((m : ℝ) / (n : ℝ))..((↑m + 1) / (n : ℝ)),
      t * Int.fract ((n : ℝ) * t) =
    ∫ t in ((m : ℝ) / (n : ℝ))..((↑m + 1) / (n : ℝ)),
      t * ((n : ℝ) * t - (m : ℝ)) := by
  have hn_pos : (0 : ℝ) < (n : ℝ) := Nat.cast_pos.mpr (by omega)
  have hle : (m : ℝ) / (n : ℝ) ≤ ((m : ℝ) + 1) / (n : ℝ) :=
    div_le_div_of_nonneg_right (by linarith) (le_of_lt hn_pos)
  rw [intervalIntegral.integral_of_le hle, intervalIntegral.integral_of_le hle]
  apply integral_congr_ae
  rw [Filter.eventuallyEq_iff_exists_mem]
  refine ⟨Set.Ioo ((m : ℝ)/(n : ℝ)) (((m : ℝ)+1)/(n : ℝ)), ?_, ?_⟩
  · rw [mem_ae_iff]
    apply le_antisymm _ (zero_le _)
    rw [Measure.restrict_apply (measurableSet_Ioo.compl)]
    calc volume ((Set.Ioo ((m : ℝ)/(n : ℝ)) (((m : ℝ)+1)/(n : ℝ)))ᶜ ∩
            Set.Ioc ((m : ℝ)/(n : ℝ)) (((m : ℝ)+1)/(n : ℝ)))
        ≤ volume {((m : ℝ) + 1) / (n : ℝ)} := by
          apply measure_mono
          intro t ⟨ht_not_ioo, ht_ioc⟩
          simp only [Set.mem_compl_iff, Set.mem_Ioo, not_and, not_lt] at ht_not_ioo
          simp only [Set.mem_Ioc] at ht_ioc
          simp only [Set.mem_singleton_iff]
          linarith [ht_not_ioo ht_ioc.1, ht_ioc.2]
      _ = 0 := Real.volume_singleton
  · intro t ht
    show t * Int.fract (↑n * t) = t * (↑n * t - ↑m)
    congr 1
    exact fract_nat_mul_piece n m hn hm t ht.1 ht.2

-- ═══════════════════════════════════════════════
-- Step 4: Telescope
-- ═══════════════════════════════════════════════

/-- Telescoping: Σ ∫_{m/n}^{(m+1)/n} = ∫₀^{(M+1)/n}. -/
lemma fract_linear_telescope (n : ℕ) (hn : 1 ≤ n) (M : ℕ) (hM : M < n) :
    ∑ m ∈ Finset.range (M + 1),
      ∫ t in ((m : ℝ) / (n : ℝ))..((↑m + 1) / (n : ℝ)),
        t * Int.fract ((n : ℝ) * t) =
    ∫ t in (0 : ℝ)..((↑M + 1) / (n : ℝ)),
      t * Int.fract ((n : ℝ) * t) := by
  induction M with
  | zero =>
    rw [Finset.sum_range_one]; simp only [Nat.cast_zero, zero_div]
  | succ M ih =>
    rw [Finset.sum_range_succ, ih (by omega)]
    rw [← intervalIntegral.integral_add_adjacent_intervals
      (fract_linear_integrable n 0 (((M : ℝ) + 1) / (n : ℝ)))
      (fract_linear_integrable n (((M : ℝ) + 1) / (n : ℝ)) ((↑(M + 1) + 1) / ↑n))]
    congr 1 <;> push_cast <;> ring_nf

-- ═══════════════════════════════════════════════
-- Step 5: Arithmetic sum
-- ═══════════════════════════════════════════════

/-- Σ_{m=0}^{n-1} (3m+2) = n(3n+1)/2. -/
private lemma sum_3m_plus_2 (n : ℕ) (hn : 1 ≤ n) :
    ∑ m ∈ Finset.range n, (3 * (m : ℝ) + 2) = (n : ℝ) * (3 * (n : ℝ) + 1) / 2 := by
  induction n with
  | zero => omega
  | succ k ih =>
    rw [Finset.sum_range_succ]
    by_cases hk : 1 ≤ k
    · rw [ih hk]; push_cast; ring
    · have : k = 0 := by omega
      subst this; simp; ring

-- ═══════════════════════════════════════════════
-- Step 6: Main theorem
-- ═══════════════════════════════════════════════

/-- **THEOREM**: ∫₀¹ t·{nt} dt = (3n+1)/(12n) for n ≥ 1. -/
theorem fract_linear_integral (n : ℕ) (hn : 1 ≤ n) :
    ∫ t in (0:ℝ)..1, t * Int.fract ((n : ℝ) * t) = (3 * (n : ℝ) + 1) / (12 * (n : ℝ)) := by
  have hn_pos : (0 : ℝ) < (n : ℝ) := Nat.cast_pos.mpr (by omega)
  -- Use n - 1 carefully: Nat.pred_eq_sub_one
  set M := n - 1 with hM_def
  have hM_lt : M < n := Nat.sub_one_lt_of_le hn le_rfl
  have hM_succ : M + 1 = n := by omega
  -- 1 = (M + 1) / n = n / n
  have h_one : (1 : ℝ) = ((M : ℝ) + 1) / (n : ℝ) := by
    have hcast : (M : ℝ) + 1 = (n : ℝ) := by
      rw [← Nat.cast_one, ← Nat.cast_add, hM_succ]
    rw [hcast]
    exact (div_self (ne_of_gt hn_pos)).symm
  rw [h_one, ← fract_linear_telescope n hn M hM_lt]
  -- Apply piece_eq and piece_value to each summand
  have hrange : ∀ m ∈ Finset.range n,
      ∫ t in ((m : ℝ)/(n : ℝ))..((↑m + 1)/(n : ℝ)),
        t * Int.fract ((n : ℝ) * t) = (3 * (m : ℝ) + 2) / (6 * (n : ℝ)^2) := by
    intro m hm
    rw [Finset.mem_range] at hm
    rw [fract_linear_piece_eq n m hn hm, fract_linear_piece n m hn]
  rw [hM_succ, Finset.sum_congr rfl hrange]
  -- Σ_{m=0}^{n-1} (3m+2)/(6n²) = (3n+1)/(12n)
  simp_rw [div_eq_mul_inv]
  rw [← Finset.sum_mul]
  rw [show (6 * (n : ℝ) ^ 2)⁻¹ = 1 / (6 * (n : ℝ) ^ 2) from by ring]
  rw [sum_3m_plus_2 n hn]
  -- Need to unfold M = n - 1 for ring to close
  have hM_cast : (M : ℝ) = (n : ℝ) - 1 := by
    have := hM_succ  -- M + 1 = n
    have : (M : ℝ) + 1 = (n : ℝ) := by exact_mod_cast this
    linarith
  rw [hM_cast]
  field_simp; ring

end
