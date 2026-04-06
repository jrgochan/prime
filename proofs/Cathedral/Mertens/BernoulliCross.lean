import Cathedral.GramOffDiag
import Cathedral.GramBounds
import Cathedral.Mertens.CoprimeCross

set_option maxHeartbeats 800000
noncomputable section
open Real MeasureTheory Set Finset

-- ═══════════════════════════════════════════════
-- Helper: {nt} = nt - m on open piece
-- ═══════════════════════════════════════════════

private lemma fract_mul_piece (n m : ℕ) (hn : 1 ≤ n) (hm : m < n)
    (t : ℝ) (hl : (m : ℝ) / (n : ℝ) < t) (hr : t < ((m : ℝ) + 1) / (n : ℝ)) :
    Int.fract ((n : ℝ) * t) = (n : ℝ) * t - (m : ℝ) := by
  have hn_pos : (0 : ℝ) < (n : ℝ) := Nat.cast_pos.mpr (by omega)
  have hlo : (m : ℝ) < (n : ℝ) * t := by
    rw [div_lt_iff₀ hn_pos] at hl; linarith
  have hhi : (n : ℝ) * t < (m : ℝ) + 1 := by
    rw [lt_div_iff₀ hn_pos] at hr; linarith
  have h0 : (0 : ℝ) ≤ (n : ℝ) * t - (m : ℝ) := by linarith
  have h1 : (n : ℝ) * t - (m : ℝ) < 1 := by linarith
  rw [Int.fract_eq_iff]
  exact ⟨h0, h1, ⟨m, by push_cast; ring⟩⟩

-- ═══════════════════════════════════════════════
-- ae-congr
-- ═══════════════════════════════════════════════

private lemma fract_ae_piece (n m : ℕ) (hn : 1 ≤ n) (hm : m < n) :
    ∫ t in ((m : ℝ)/(n : ℝ))..((↑m+1)/(n : ℝ)),
      Int.fract ((n : ℝ) * t) =
    ∫ t in ((m : ℝ)/(n : ℝ))..((↑m+1)/(n : ℝ)),
      ((n : ℝ) * t - (m : ℝ)) := by
  have hn_pos : (0 : ℝ) < (n : ℝ) := Nat.cast_pos.mpr (by omega)
  have hle : (m : ℝ) / (n : ℝ) ≤ ((m : ℝ) + 1) / (n : ℝ) :=
    div_le_div_of_nonneg_right (by linarith) (le_of_lt hn_pos)
  rw [intervalIntegral.integral_of_le hle, intervalIntegral.integral_of_le hle]
  apply integral_congr_ae
  rw [Filter.eventuallyEq_iff_exists_mem]
  refine ⟨Set.Ioo ((m : ℝ)/(n : ℝ)) (((m : ℝ)+1)/(n : ℝ)), ?_, ?_⟩
  · rw [mem_ae_iff]; apply le_antisymm _ (zero_le _)
    rw [Measure.restrict_apply (measurableSet_Ioo.compl)]
    calc volume ((Set.Ioo ((m : ℝ)/(n : ℝ)) (((m : ℝ)+1)/(n : ℝ)))ᶜ ∩
            Set.Ioc ((m : ℝ)/(n : ℝ)) (((m : ℝ)+1)/(n : ℝ)))
        ≤ volume {((m : ℝ) + 1) / (n : ℝ)} := by
          apply measure_mono; intro t ⟨hc, hi⟩
          simp only [Set.mem_singleton_iff]
          by_contra h; exact hc (Set.mem_Ioo.mpr ⟨hi.1, lt_of_le_of_ne hi.2 h⟩)
      _ = 0 := Real.volume_singleton
  · intro t ht; exact fract_mul_piece n m hn hm t ht.1 ht.2

-- ═══════════════════════════════════════════════
-- FTC for piece integral
-- ═══════════════════════════════════════════════

/-- ∫_{m/n}^{(m+1)/n} {nt} dt = 1/(2n). -/
lemma fract_piece_mean (n m : ℕ) (hn : 1 ≤ n) (hm : m < n) :
    ∫ t in ((m : ℝ)/(n : ℝ))..((↑m+1)/(n : ℝ)),
      Int.fract ((n : ℝ) * t) = 1 / (2 * (n : ℝ)) := by
  rw [fract_ae_piece n m hn hm]
  -- Antideriv: F(t) = nt²/2 - mt, F'(t) = nt - m
  have hderiv : ∀ x ∈ Set.uIcc ((m : ℝ)/(n : ℝ)) (((m : ℝ)+1)/(n : ℝ)),
      HasDerivAt (fun t => (n : ℝ) * t^2 / 2 - (m : ℝ) * t) ((n : ℝ) * x - (m : ℝ)) x := by
    intro x _
    have := (((hasDerivAt_id x).pow 2).const_mul (n : ℝ)).div_const 2
    have := this.sub ((hasDerivAt_id x).const_mul (m : ℝ))
    convert this using 1
    simp [mul_comm]; ring
  rw [intervalIntegral.integral_eq_sub_of_hasDerivAt hderiv
      ((continuous_const.mul continuous_id).sub continuous_const).continuousOn.intervalIntegrable]
  field_simp; ring

-- ═══════════════════════════════════════════════
-- Integrability + telescope
-- ═══════════════════════════════════════════════

private lemma fract_integrable (n : ℕ) (a b : ℝ) :
    IntervalIntegrable (fun t => Int.fract ((n : ℝ) * t)) volume a b := by
  apply (intervalIntegrable_const (c := (1 : ℝ))).mono_fun
  · exact (measurable_fract.comp (measurable_const.mul measurable_id)).aestronglyMeasurable
  · filter_upwards with t
    simp only [Real.norm_eq_abs, abs_one]
    exact le_of_lt (abs_lt.mpr ⟨by linarith [Int.fract_nonneg ((n : ℝ) * t)],
                                  by linarith [Int.fract_lt_one ((n : ℝ) * t)]⟩)

private lemma fract_telescope (n : ℕ) (hn : 1 ≤ n) (M : ℕ) (hM : M < n) :
    ∑ m ∈ Finset.range (M + 1),
      ∫ t in ((m : ℝ) / (n : ℝ))..((↑m + 1) / (n : ℝ)),
        Int.fract ((n : ℝ) * t) =
    ∫ t in (0 : ℝ)..((↑M + 1) / (n : ℝ)),
      Int.fract ((n : ℝ) * t) := by
  induction M with
  | zero => rw [Finset.sum_range_one]; simp
  | succ M ih =>
    rw [Finset.sum_range_succ, ih (by omega)]
    have hcast : (↑(M + 1) : ℝ) = (M : ℝ) + 1 := by push_cast; ring
    simp only [hcast]
    exact intervalIntegral.integral_add_adjacent_intervals
      (fract_integrable n 0 _) (fract_integrable n _ _)

-- ═══════════════════════════════════════════════
-- MAIN: ∫₀¹ {nt} dt = 1/2
-- ═══════════════════════════════════════════════

theorem fract_mean (n : ℕ) (hn : 1 ≤ n) :
    ∫ t in (0:ℝ)..1, Int.fract ((n : ℝ) * t) = 1 / 2 := by
  have hn_pos : (0 : ℝ) < (n : ℝ) := Nat.cast_pos.mpr (by omega)
  -- Rewrite 1 = (n-1+1)/n, use telescope
  have h1 : (1 : ℝ) = ((↑(n - 1) : ℝ) + 1) / (n : ℝ) := by
    have : (↑(n - 1) : ℝ) + 1 = (n : ℝ) := by
      rw [Nat.cast_sub (by omega)]; push_cast; linarith
    rw [this]; field_simp
  rw [h1, ← fract_telescope n hn (n - 1) (by omega)]
  rw [show n - 1 + 1 = n from by omega]
  -- Each piece = 1/(2n), sum = 1/2
  rw [Finset.sum_congr rfl (fun m hm => fract_piece_mean n m hn (Finset.mem_range.mp hm))]
  rw [Finset.sum_const, Finset.card_range]
  simp only [nsmul_eq_mul]
  have hne : (n : ℝ) ≠ 0 := ne_of_gt hn_pos
  field_simp
  rw [Nat.cast_sub (by omega : 1 ≤ n)]; simp

-- ═══════════════════════════════════════════════
-- ∫₀¹ {nt}² dt = 1/3
-- ═══════════════════════════════════════════════

/-- ae-congr for squared: {nt}² = (nt-m)² on piece. -/
private lemma fract_sq_ae_piece (n m : ℕ) (hn : 1 ≤ n) (hm : m < n) :
    ∫ t in ((m : ℝ)/(n : ℝ))..((↑m+1)/(n : ℝ)),
      (Int.fract ((n : ℝ) * t))^2 =
    ∫ t in ((m : ℝ)/(n : ℝ))..((↑m+1)/(n : ℝ)),
      ((n : ℝ) * t - (m : ℝ))^2 := by
  have hn_pos : (0 : ℝ) < (n : ℝ) := Nat.cast_pos.mpr (by omega)
  have hle : (m : ℝ) / (n : ℝ) ≤ ((m : ℝ) + 1) / (n : ℝ) :=
    div_le_div_of_nonneg_right (by linarith) (le_of_lt hn_pos)
  rw [intervalIntegral.integral_of_le hle, intervalIntegral.integral_of_le hle]
  apply integral_congr_ae
  rw [Filter.eventuallyEq_iff_exists_mem]
  refine ⟨Set.Ioo ((m : ℝ)/(n : ℝ)) (((m : ℝ)+1)/(n : ℝ)), ?_, ?_⟩
  · rw [mem_ae_iff]; apply le_antisymm _ (zero_le _)
    rw [Measure.restrict_apply (measurableSet_Ioo.compl)]
    calc volume ((Set.Ioo ((m : ℝ)/(n : ℝ)) (((m : ℝ)+1)/(n : ℝ)))ᶜ ∩
            Set.Ioc ((m : ℝ)/(n : ℝ)) (((m : ℝ)+1)/(n : ℝ)))
        ≤ volume {((m : ℝ) + 1) / (n : ℝ)} := by
          apply measure_mono; intro t ⟨hc, hi⟩
          simp only [Set.mem_singleton_iff]
          by_contra h; exact hc (Set.mem_Ioo.mpr ⟨hi.1, lt_of_le_of_ne hi.2 h⟩)
      _ = 0 := Real.volume_singleton
  · intro t ht
    show (Int.fract ((n : ℝ) * t))^2 = ((n : ℝ) * t - (m : ℝ))^2
    rw [fract_mul_piece n m hn hm t ht.1 ht.2]

/-- ∫_{m/n}^{(m+1)/n} {nt}² dt = 1/(3n). -/
lemma fract_sq_piece (n m : ℕ) (hn : 1 ≤ n) (hm : m < n) :
    ∫ t in ((m : ℝ)/(n : ℝ))..((↑m+1)/(n : ℝ)),
      (Int.fract ((n : ℝ) * t))^2 = 1 / (3 * (n : ℝ)) := by
  rw [fract_sq_ae_piece n m hn hm]
  -- antideriv of (nt-m)² = n²t² - 2nmt + m² is n²t³/3 - nmt² + m²t
  have hderiv : ∀ x ∈ Set.uIcc ((m : ℝ)/(n : ℝ)) (((m : ℝ)+1)/(n : ℝ)),
      HasDerivAt (fun t => (n : ℝ)^2 * t^3 / 3 - (n : ℝ) * (m : ℝ) * t^2 + (m : ℝ)^2 * t)
        (((n : ℝ) * x - (m : ℝ))^2) x := by
    intro x _
    have h1 := (((hasDerivAt_id x).pow 3).const_mul ((n : ℝ)^2)).div_const 3
    have h2 := ((hasDerivAt_id x).pow 2).const_mul ((n : ℝ) * (m : ℝ))
    have h3 := (hasDerivAt_id x).const_mul ((m : ℝ)^2)
    convert (h1.sub h2).add h3 using 1
    simp [id]; ring
  rw [intervalIntegral.integral_eq_sub_of_hasDerivAt hderiv
      (by apply ContinuousOn.intervalIntegrable; fun_prop)]
  field_simp; ring

/-- {nt}² is interval-integrable. -/
private lemma fract_sq_integrable (n : ℕ) (a b : ℝ) :
    IntervalIntegrable (fun t => (Int.fract ((n : ℝ) * t))^2) volume a b := by
  apply (intervalIntegrable_const (c := (1 : ℝ))).mono_fun
  · exact (Measurable.pow_const (measurable_fract.comp (measurable_const.mul measurable_id)) 2).aestronglyMeasurable
  · filter_upwards with t
    simp only [Real.norm_eq_abs, abs_one]
    rw [abs_le]; constructor
    · nlinarith [sq_nonneg (Int.fract ((n : ℝ) * t))]
    · have h1 := Int.fract_lt_one ((n : ℝ) * t)
      have h0 := Int.fract_nonneg ((n : ℝ) * t)
      nlinarith

/-- **∫₀¹ {nt}² dt = 1/3** for n ≥ 1. -/
theorem fract_sq_integral (n : ℕ) (hn : 1 ≤ n) :
    ∫ t in (0:ℝ)..1, (Int.fract ((n : ℝ) * t))^2 = 1 / 3 := by
  have hn_pos : (0 : ℝ) < (n : ℝ) := Nat.cast_pos.mpr (by omega)
  have h1 : (1 : ℝ) = ((↑(n - 1) : ℝ) + 1) / (n : ℝ) := by
    have : (↑(n - 1) : ℝ) + 1 = (n : ℝ) := by
      rw [Nat.cast_sub (by omega)]; push_cast; linarith
    rw [this]; field_simp
  -- Telescope for {nt}²
  have htelescope : ∀ M : ℕ, M < n →
      ∑ m ∈ Finset.range (M + 1),
        ∫ t in ((m : ℝ) / (n : ℝ))..((↑m + 1) / (n : ℝ)),
          (Int.fract ((n : ℝ) * t))^2 =
      ∫ t in (0 : ℝ)..((↑M + 1) / (n : ℝ)),
        (Int.fract ((n : ℝ) * t))^2 := by
    intro M; induction M with
    | zero => intro _; rw [Finset.sum_range_one]; simp
    | succ M ih =>
      intro hM; rw [Finset.sum_range_succ, ih (by omega)]
      have hcast : (↑(M + 1) : ℝ) = (M : ℝ) + 1 := by push_cast; ring
      simp only [hcast]
      exact intervalIntegral.integral_add_adjacent_intervals
        (fract_sq_integrable n 0 _) (fract_sq_integrable n _ _)
  rw [h1, ← htelescope (n - 1) (by omega), show n - 1 + 1 = n from by omega]
  rw [Finset.sum_congr rfl (fun m hm => fract_sq_piece n m hn (Finset.mem_range.mp hm))]
  rw [Finset.sum_const, Finset.card_range]
  simp only [nsmul_eq_mul]
  have : (n : ℝ) ≠ 0 := ne_of_gt hn_pos
  field_simp
  rw [Nat.cast_sub (by omega : 1 ≤ n)]; simp

-- ═══════════════════════════════════════════════
-- Centered variance: ∫₀¹ ({nt}-½)² dt = 1/12
-- ═══════════════════════════════════════════════

/-- **∫₀¹ ({nt}-½)² dt = 1/12** for n ≥ 1.
    Follows from: ({nt}-½)² = {nt}² - {nt} + 1/4.
    ∫ = 1/3 - 1/2 + 1/4 = 1/12. -/
theorem centered_fract_variance (n : ℕ) (hn : 1 ≤ n) :
    ∫ t in (0:ℝ)..1, (Int.fract ((n : ℝ) * t) - 1/2)^2 = 1 / 12 := by
  -- Expand (x-1/2)² = x² - x + 1/4
  have hexp : ∀ t : ℝ,
      (Int.fract ((n : ℝ) * t) - 1/2)^2 =
      (Int.fract ((n : ℝ) * t))^2 - Int.fract ((n : ℝ) * t) + 1/4 := by
    intro t; ring
  simp_rw [hexp]
  rw [intervalIntegral.integral_add
      ((fract_sq_integrable n 0 1).sub (fract_integrable n 0 1))
      (intervalIntegrable_const),
    intervalIntegral.integral_sub (fract_sq_integrable n 0 1) (fract_integrable n 0 1)]
  rw [fract_sq_integral n hn, fract_mean n hn]
  simp [intervalIntegral.integral_const]; ring

-- ═══════════════════════════════════════════════
-- Cross-product: α=1 case
-- ∫₀¹ (t-½)({nt}-½) dt = 1/(12n)
-- ═══════════════════════════════════════════════

-- Helper: ae-congruence for t·{nt} → t·(nt-m) on piece
private lemma t_fract_ae_piece (n m : ℕ) (hn : 1 ≤ n) (hm : m < n) :
    ∫ t in ((m : ℝ)/(n : ℝ))..((↑m+1)/(n : ℝ)),
      t * Int.fract ((n : ℝ) * t) =
    ∫ t in ((m : ℝ)/(n : ℝ))..((↑m+1)/(n : ℝ)),
      t * ((n : ℝ) * t - (m : ℝ)) := by
  have hn_pos : (0 : ℝ) < (n : ℝ) := Nat.cast_pos.mpr (by omega)
  have hle : (m : ℝ) / (n : ℝ) ≤ ((m : ℝ) + 1) / (n : ℝ) :=
    div_le_div_of_nonneg_right (by linarith) (le_of_lt hn_pos)
  rw [intervalIntegral.integral_of_le hle, intervalIntegral.integral_of_le hle]
  apply integral_congr_ae
  rw [Filter.eventuallyEq_iff_exists_mem]
  refine ⟨Set.Ioo ((m : ℝ)/(n : ℝ)) (((m : ℝ)+1)/(n : ℝ)), ?_, ?_⟩
  · rw [mem_ae_iff]; apply le_antisymm _ (zero_le _)
    rw [Measure.restrict_apply (measurableSet_Ioo.compl)]
    calc volume ((Set.Ioo ((m : ℝ)/(n : ℝ)) (((m : ℝ)+1)/(n : ℝ)))ᶜ ∩
            Set.Ioc ((m : ℝ)/(n : ℝ)) (((m : ℝ)+1)/(n : ℝ)))
        ≤ volume {((m : ℝ) + 1) / (n : ℝ)} := by
          apply measure_mono; intro t ⟨hc, hi⟩
          simp only [Set.mem_singleton_iff]
          by_contra h; exact hc (Set.mem_Ioo.mpr ⟨hi.1, lt_of_le_of_ne hi.2 h⟩)
      _ = 0 := Real.volume_singleton
  · intro t ht
    show t * Int.fract ((n : ℝ) * t) = t * ((n : ℝ) * t - (m : ℝ))
    congr 1; exact fract_mul_piece n m hn hm t ht.1 ht.2

-- Helper: FTC for ∫ t·(nt-m) on piece
private lemma t_fract_piece_mean (n m : ℕ) (hn : 1 ≤ n) (hm : m < n) :
    ∫ t in ((m : ℝ)/(n : ℝ))..((↑m + 1)/(n : ℝ)),
      t * Int.fract ((n : ℝ) * t) =
    (3 * (m : ℝ) + 2) / (6 * (n : ℝ)^2) := by
  rw [t_fract_ae_piece n m hn hm]
  have hn_pos : (0 : ℝ) < (n : ℝ) := Nat.cast_pos.mpr (by omega)
  have hn_ne : (n : ℝ) ≠ 0 := ne_of_gt hn_pos
  have hderiv : ∀ t ∈ Set.uIcc ((m : ℝ)/(n : ℝ)) ((↑m+1)/(n : ℝ)),
      HasDerivAt (fun s => (n : ℝ) * s^3 / 3 - (m : ℝ) * s^2 / 2)
        (t * ((n : ℝ) * t - (m : ℝ))) t := by
    intro t _
    have h1 := ((hasDerivAt_pow 3 t).const_mul (n : ℝ)).div_const (3 : ℝ)
    have h2 := ((hasDerivAt_pow 2 t).const_mul (m : ℝ)).div_const (2 : ℝ)
    exact (h1.sub h2).congr_deriv (by ring)
  rw [intervalIntegral.integral_eq_sub_of_hasDerivAt hderiv
    (continuous_id.mul (continuous_const.mul continuous_id |>.sub continuous_const)).continuousOn.intervalIntegrable]
  field_simp; ring

-- Helper: integrability of t·{nt}
private lemma t_fract_integrable (n : ℕ) (a b : ℝ) :
    IntervalIntegrable (fun t => t * Int.fract ((n : ℝ) * t)) volume a b := by
  apply ((continuous_abs.add continuous_const).intervalIntegrable (a := a) (b := b)
    (μ := volume) : IntervalIntegrable (fun t : ℝ => |t| + (1:ℝ)) volume a b).mono_fun
  · exact (measurable_id.mul (measurable_fract.comp (measurable_const.mul measurable_id))).aestronglyMeasurable
  · filter_upwards with t
    show ‖t * Int.fract (↑n * t)‖ ≤ ‖(fun t : ℝ => |t| + (1:ℝ)) t‖
    simp only [Real.norm_eq_abs]
    rw [abs_mul]
    have h1 : |Int.fract (↑n * t)| ≤ 1 :=
      le_of_lt (abs_lt.mpr ⟨by linarith [Int.fract_nonneg (↑n * t)], Int.fract_lt_one _⟩)
    have h2 : |t| * |Int.fract (↑n * t)| ≤ |t| :=
      calc |t| * |Int.fract (↑n * t)| ≤ |t| * 1 := mul_le_mul_of_nonneg_left h1 (abs_nonneg _)
        _ = |t| := mul_one _
    have h4 : 0 ≤ |t| + 1 := by linarith [abs_nonneg t]
    rw [abs_of_nonneg h4]
    linarith

-- Helper: telescope for t·{nt}
private lemma t_fract_telescope (n : ℕ) (hn : 1 ≤ n) (M : ℕ) (_hM : M < n) :
    ∑ m ∈ Finset.range (M + 1),
      ∫ t in ((m : ℝ) / (n : ℝ))..((↑m + 1) / (n : ℝ)),
        t * Int.fract ((n : ℝ) * t) =
    ∫ t in (0 : ℝ)..((↑M + 1) / (n : ℝ)),
      t * Int.fract ((n : ℝ) * t) := by
  induction M with
  | zero => rw [Finset.sum_range_one]; simp
  | succ M ih =>
    rw [Finset.sum_range_succ, ih (by omega)]
    have hcast : (↑(M + 1) : ℝ) = (M : ℝ) + 1 := by push_cast; ring
    simp only [hcast]
    exact intervalIntegral.integral_add_adjacent_intervals
      (t_fract_integrable n 0 _) (t_fract_integrable n _ _)

-- Helper: Σ_{m=0}^{n-1} (3m+2) = n(3n+1)/2
private lemma sum_3m_plus_2_raw (n : ℕ) :
    (range n).sum (fun m => 3 * (m : ℝ) + 2) =
    (n : ℝ) * (3 * (n : ℝ) + 1) / 2 := by
  induction n with
  | zero => simp
  | succ k ih => rw [sum_range_succ, ih]; push_cast; ring

-- Corollary with denominator
private lemma sum_3m_plus_2 (n : ℕ) (hn : 1 ≤ n) :
    (range n).sum (fun m => (3 * (m : ℝ) + 2) / (6 * (n : ℝ)^2)) =
    (3 * (n : ℝ) + 1) / (12 * (n : ℝ)) := by
  have hn_pos : (0 : ℝ) < (n : ℝ) := Nat.cast_pos.mpr (by omega)
  rw [← Finset.sum_div]
  rw [sum_3m_plus_2_raw]
  field_simp; ring

-- Main: ∫₀¹ t·{nt} = (3n+1)/(12n)
private lemma t_fract_linear_integral (n : ℕ) (hn : 1 ≤ n) :
    ∫ t in (0:ℝ)..1, t * Int.fract ((n : ℝ) * t) =
    (3 * (n : ℝ) + 1) / (12 * (n : ℝ)) := by
  have hn_pos : (0 : ℝ) < (n : ℝ) := Nat.cast_pos.mpr (by omega)
  have hend : (1 : ℝ) = ((↑(n - 1) : ℝ) + 1) / (n : ℝ) := by
    have : (↑(n - 1) : ℝ) + 1 = (n : ℝ) := by
      rw [Nat.cast_sub (by omega)]; push_cast; linarith
    rw [this]; field_simp
  -- Only rewrite the endpoint in the integral, not the RHS
  conv_lhs => rw [hend]
  rw [← t_fract_telescope n hn (n - 1) (by omega)]
  rw [show n - 1 + 1 = n from by omega]
  rw [Finset.sum_congr rfl (fun m hm => t_fract_piece_mean n m hn (Finset.mem_range.mp hm))]
  exact sum_3m_plus_2 n hn

/-- Cross-product for α=1: ∫₀¹ (t-½)({nt}-½) dt = 1/(12n). -/
theorem cross_product_one (n : ℕ) (hn : 1 ≤ n) :
    ∫ t in (0:ℝ)..1, (t - 1/2) * (Int.fract ((n : ℝ) * t) - 1/2) =
    1 / (12 * (n : ℝ)) := by
  -- Expand: (t-1/2)({nt}-1/2) = t·{nt} - (1/2)·{nt} + (-(1/2)·t + 1/4)
  have hexp : ∀ t : ℝ, (t - 1/2) * (Int.fract ((n : ℝ) * t) - 1/2) =
      t * Int.fract ((n : ℝ) * t) - (1/2) * Int.fract ((n : ℝ) * t)
      + (-(1/2) * t + 1/4) := by intro t; ring
  simp_rw [hexp]
  have hid : IntervalIntegrable (fun t : ℝ => t) volume (0:ℝ) 1 :=
    continuous_id.intervalIntegrable 0 1
  rw [intervalIntegral.integral_add
      ((t_fract_integrable n 0 1).sub ((fract_integrable n 0 1).const_mul _))
      ((hid.const_mul _).add intervalIntegrable_const)]
  rw [intervalIntegral.integral_sub (t_fract_integrable n 0 1)
      ((fract_integrable n 0 1).const_mul _)]
  rw [intervalIntegral.integral_add (hid.const_mul _) intervalIntegrable_const]
  rw [t_fract_linear_integral n hn]
  rw [intervalIntegral.integral_const_mul, fract_mean n hn]
  rw [intervalIntegral.integral_const_mul]
  simp [intervalIntegral.integral_const]
  have hn_pos : (0 : ℝ) < (n : ℝ) := Nat.cast_pos.mpr (by omega)
  field_simp; ring

-- ═══════════════════════════════════════════════
-- General coprime cross-product (verified)
-- ═══════════════════════════════════════════════

/-- Cross-product for coprime pairs.
    ∫₀¹ ({αt}-½)({βt}-½) dt = 1/(12αβ) for gcd(α,β)=1.
    TODO: Prove via piecewise computation on α+β-1 subintervals,
    or via equidistribution / CRT argument. -/
theorem cross_product_coprime (α β : ℕ) (hα : 1 ≤ α) (hβ : 1 ≤ β)
    (hcop : Nat.Coprime α β) :
    ∫ t in (0:ℝ)..1, (Int.fract ((α : ℝ) * t) - 1/2) *
                      (Int.fract ((β : ℝ) * t) - 1/2) =
    1 / (12 * ((α : ℝ) * (β : ℝ))) := by
  -- Case split: α = β or α ≠ β
  by_cases hne : α = β
  · -- α = β: coprime(α,α) ⟹ α = 1
    subst hne
    have hα1 : α = 1 := by rwa [Nat.Coprime, Nat.gcd_self] at hcop
    subst hα1
    -- ∫₀¹ ({1·t}-½)·({1·t}-½) = 1/(12·1·1) = 1/12
    have hmul : ∀ t : ℝ, (Int.fract ((1 : ℕ) * t) - 1/2) * (Int.fract ((1 : ℕ) * t) - 1/2) =
        (Int.fract ((1 : ℕ) * t) - 1/2)^2 := fun t => by ring
    simp_rw [hmul]
    convert centered_fract_variance 1 le_rfl using 1; push_cast; norm_num
  · -- α ≠ β: use cross_product_coprime' from CoprimeCross
    exact cross_product_coprime' α β hα hβ hne hcop

-- ═══════════════════════════════════════════════
-- General cross-product via gcd reduction
-- ═══════════════════════════════════════════════

/-- General cross-product: ∫₀¹ ({jt}-½)({kt}-½) dt = gcd²/(12jk).
    Proof: Factor j = g·a, k = g·b with gcd(a,b) = 1.
    Substitute u = g·t, use periodicity {g·a·t} = {a·(gt)} = {a·u},
    then apply cross_product_coprime. -/
theorem cross_product_general (j k : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k) :
    ∫ t in (0:ℝ)..1, (Int.fract ((j : ℝ) * t) - 1/2) *
                      (Int.fract ((k : ℝ) * t) - 1/2) =
    ((Nat.gcd j k : ℝ))^2 / (12 * ((j : ℝ) * (k : ℝ))) := by
  set g := Nat.gcd j k with hg_def
  set a := j / g with ha_def
  set b := k / g with hb_def
  have hg_pos : 0 < g := Nat.pos_of_ne_zero (Nat.gcd_ne_zero_left (by omega))
  have hja : j = g * a := by
    show j = Nat.gcd j k * (j / Nat.gcd j k)
    exact (Nat.mul_div_cancel' (Nat.gcd_dvd_left j k)).symm
  have hkb : k = g * b := by
    show k = Nat.gcd j k * (k / Nat.gcd j k)
    exact (Nat.mul_div_cancel' (Nat.gcd_dvd_right j k)).symm
  have hcop : Nat.Coprime a b := by
    show Nat.Coprime (j / Nat.gcd j k) (k / Nat.gcd j k)
    exact Nat.coprime_div_gcd_div_gcd hg_pos
  have ha : 1 ≤ a := Nat.div_pos (Nat.le_of_dvd (by omega) (Nat.gcd_dvd_left j k)) hg_pos
  have hb : 1 ≤ b := Nat.div_pos (Nat.le_of_dvd (by omega) (Nat.gcd_dvd_right j k)) hg_pos
  -- Rewrite j·t = a·(g·t) and k·t = b·(g·t)
  have hj_eq : ∀ t : ℝ, (j : ℝ) * t = (a : ℝ) * ((g : ℝ) * t) := by
    intro t; push_cast [hja]; ring
  have hk_eq : ∀ t : ℝ, (k : ℝ) * t = (b : ℝ) * ((g : ℝ) * t) := by
    intro t; push_cast [hkb]; ring
  simp_rw [hj_eq, hk_eq]
  -- Step 1: Substitution u = g·t
  -- ∫₀¹ f(g·t) dt = g⁻¹ · ∫₀^g f(u) du
  have hg_ne : (g : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
  -- Define h and show integrand is h(t * g)  
  set h := fun u => (Int.fract ((a : ℝ) * u) - 1/2) * (Int.fract ((b : ℝ) * u) - 1/2)
    with hh_def
  -- The integrand after simp_rw is already fun t => h(g*t).
  -- Rewrite as fun t => h(t * g) so integral_comp_mul_right applies
  have hgt_eq : ∀ t : ℝ,
      (Int.fract ((a : ℝ) * ((g : ℝ) * t)) - 1/2) * (Int.fract ((b : ℝ) * ((g : ℝ) * t)) - 1/2) =
      h (t * (g : ℝ)) := by
    intro t; simp only [h, mul_comm (g : ℝ) t, mul_assoc]
  simp_rw [hgt_eq]
  rw [intervalIntegral.integral_comp_mul_right h hg_ne]
  simp only [zero_mul, one_mul]
  -- Step 2: Periodicity: ∫₀^g f = g · ∫₀¹ f (since f has period 1)
  -- h has period 1 since fract(n·(u+1)) = fract(n·u + n) = fract(n·u) for n ∈ ℕ
  have hperiodic : Function.Periodic h 1 := by
    intro u; show h (u + 1) = h u
    simp only [h, mul_add, mul_one]
    congr 1 <;> { congr 1; exact Int.fract_add_natCast _ _ }
  have hint : ∀ t₁ t₂, IntervalIntegrable h MeasureSpace.volume t₁ t₂ := by
    intro t₁ t₂
    -- Bounded measurable on finite-measure set
    have hmeas : AEStronglyMeasurable h volume := by
      exact ((measurable_fract.comp (measurable_const.mul measurable_id)).sub
          measurable_const |>.mul
          ((measurable_fract.comp (measurable_const.mul measurable_id)).sub
          measurable_const)).aestronglyMeasurable
    have hbound : ∀ u : ℝ, ‖h u‖ ≤ 1 := by
      intro u; simp only [h, norm_mul, Real.norm_eq_abs]
      have h1 : |Int.fract ((a : ℝ) * u) - 1/2| ≤ 1/2 := by
        rw [abs_le]; constructor
        · linarith [Int.fract_nonneg ((a : ℝ) * u)]
        · linarith [Int.fract_lt_one ((a : ℝ) * u)]
      have h2 : |Int.fract ((b : ℝ) * u) - 1/2| ≤ 1/2 := by
        rw [abs_le]; constructor
        · linarith [Int.fract_nonneg ((b : ℝ) * u)]
        · linarith [Int.fract_lt_one ((b : ℝ) * u)]
      calc |Int.fract _ - 1/2| * |Int.fract _ - 1/2| ≤ (1/2) * (1/2) :=
            mul_le_mul h1 h2 (abs_nonneg _) (by linarith)
        _ ≤ 1 := by norm_num
    constructor <;> exact Measure.integrableOn_of_bounded measure_Ioc_lt_top.ne hmeas
      (by filter_upwards with u; exact hbound u)
  -- Apply periodicity: ∫₀^g h = g • ∫₀¹ h
  have hperiod_int : ∫ u in (0:ℝ)..(g : ℝ), h u = (g : ℤ) • ∫ u in (0:ℝ)..1, h u := by
    have : (g : ℝ) = 0 + (g : ℤ) • (1 : ℝ) := by simp
    conv_lhs => rw [this]
    rw [hperiodic.intervalIntegral_add_zsmul_eq (g : ℤ) 0 hint]
    simp only [zero_add]
  rw [hperiod_int, cross_product_coprime a b ha hb hcop]
  -- Goal: (g:ℝ)⁻¹ * ((g:ℤ) * (1/(12*(a:ℝ)*(b:ℝ)))) = (g:ℝ)^2/(12*(j:ℝ)*(k:ℝ))
  have hg_r : (g : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
  have ha_r : (a : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
  have hb_r : (b : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
  simp only [zsmul_eq_mul, Int.cast_natCast, smul_eq_mul]
  push_cast [hja, hkb]
  field_simp

end
