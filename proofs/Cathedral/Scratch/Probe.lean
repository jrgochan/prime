import Cathedral.GramOffDiag
import Cathedral.GramBounds
import Cathedral.Scratch.CoprimeCross

set_option maxHeartbeats 4000000
noncomputable section
open Real MeasureTheory Set Finset

-- Test cross_product_general
example (j k : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k) :
    ∫ t in (0:ℝ)..1, (Int.fract ((j : ℝ) * t) - 1/2) *
                      (Int.fract ((k : ℝ) * t) - 1/2) =
    ((Nat.gcd j k : ℝ))^2 / (12 * ((j : ℝ) * (k : ℝ))) := by
  set g := Nat.gcd j k
  set a := j / g
  set b := k / g
  have hg_pos : 0 < g := Nat.pos_of_ne_zero (Nat.gcd_ne_zero_left (by omega))
  have hja : j = g * a := (Nat.mul_div_cancel' (Nat.gcd_dvd_left j k)).symm
  have hkb : k = g * b := (Nat.mul_div_cancel' (Nat.gcd_dvd_right j k)).symm
  have hcop : Nat.Coprime a b := Nat.coprime_div_gcd_div_gcd hg_pos
  have ha : 1 ≤ a := Nat.div_pos (Nat.le_of_dvd (by omega) (Nat.gcd_dvd_left j k)) hg_pos
  have hb : 1 ≤ b := Nat.div_pos (Nat.le_of_dvd (by omega) (Nat.gcd_dvd_right j k)) hg_pos
  -- Rewrite j·t = a·(g·t) and k·t = b·(g·t)
  have hj_eq : ∀ t : ℝ, (j : ℝ) * t = (a : ℝ) * ((g : ℝ) * t) := by
    intro t; push_cast [hja]; ring
  have hk_eq : ∀ t : ℝ, (k : ℝ) * t = (b : ℝ) * ((g : ℝ) * t) := by
    intro t; push_cast [hkb]; ring
  simp_rw [hj_eq, hk_eq]
  -- Substitution
  have hg_ne : (g : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
  set h := fun u => (Int.fract ((a : ℝ) * u) - 1/2) * (Int.fract ((b : ℝ) * u) - 1/2)
  have hgt_eq : ∀ t : ℝ,
      (Int.fract ((a : ℝ) * ((g : ℝ) * t)) - 1/2) * (Int.fract ((b : ℝ) * ((g : ℝ) * t)) - 1/2) =
      h (t * (g : ℝ)) := by
    intro t; simp only [h, mul_comm (g : ℝ) t, mul_assoc]
  simp_rw [hgt_eq]
  rw [intervalIntegral.integral_comp_mul_right h hg_ne]
  simp only [zero_mul, one_mul]
  -- After substitution: (g : ℝ)⁻¹ • ∫ u in 0..g, h u = g²/(12jk)
  -- Periodicity: ∫₀^g h = g • ∫₀¹ h
  have hperiodic : Function.Periodic h 1 := by
    intro u; show h (u + 1) = h u
    simp only [h, mul_add, mul_one]
    congr 1 <;> { congr 1; exact Int.fract_add_natCast _ _ }
  have hint : ∀ t₁ t₂, IntervalIntegrable h MeasureSpace.volume t₁ t₂ := by
    intro t₁ t₂
    have hmeas : AEStronglyMeasurable h volume :=
      ((measurable_fract.comp (measurable_const.mul measurable_id)).sub
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
  rw [show (g : ℝ) = 0 + (g : ℤ) • (1 : ℝ) from by simp,
      hperiodic.intervalIntegral_add_zsmul_eq (g : ℤ) 0 hint]
  simp only [zero_add]
  -- Need to handle a = b case separately, or use general coprime theorem
  by_cases hab : a = b
  · -- a = b, coprime(a,a) → a = 1
    have ha1 : a = 1 := by rwa [Nat.Coprime, Nat.gcd_self] at hcop
    rw [hab, ha1]; simp [h]
    -- g = j = k, so g²/12jk = 1/12
    sorry
  · rw [cross_product_coprime' a b ha hb hab hcop]
  rw [zsmul_eq_mul, Int.cast_natCast, smul_eq_mul]
  push_cast [hja, hkb]
  field_simp; ring

end
