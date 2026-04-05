/-
  Cathedral/GramOffDiag.lean

  ## Off-diagonal Gram entry upper bound

  ### Proven theorems (zero sorry):
  - gramEntry_le_avg_diag: G_{j,k} ≤ (G_{j,j}+G_{k,k})/2
  - gramEntry_le_third_offdiag: G_{j,k} ≤ 1/3 for j,k ≥ 3
  - gram_entry_offdiag_upper_amgm: G_{j,k} ≤ 1/4+1/(jk) for j,k ≥ 3, jk ≤ 12
  - log_two_lower: ln2 ≥ 2/3
  - piece_sq_upper_bound_n1/n2: piece bounds for n=1,2
-/

import Cathedral.Defs
import Cathedral.Structural
import Cathedral.FractIntegral
import Cathedral.GramDiag

noncomputable section
open Real MeasureTheory Set

-- ════════════════════════════════════════════════
-- POINTWISE BOUND
-- ════════════════════════════════════════════════

/-- Pointwise AM-GM: {a}·{b} ≤ ({a}² + {b}²)/2. -/
lemma fract_prod_le_avg_sq (a b : ℝ) :
    Int.fract a * Int.fract b ≤ (Int.fract a * Int.fract a + Int.fract b * Int.fract b) / 2 := by
  nlinarith [sq_nonneg (Int.fract a - Int.fract b)]

-- ════════════════════════════════════════════════
-- AM-GM INTEGRAL BOUND
-- ════════════════════════════════════════════════

/-- G_{j,k} ≤ (G_{j,j}+G_{k,k})/2 by pointwise AM-GM. -/
theorem gramEntry_le_avg_diag (j k : ℕ) :
    gramEntry j k ≤ (gramEntry j j + gramEntry k k) / 2 := by
  have hjj := fract_prod_intervalIntegrable j j
  have hkk := fract_prod_intervalIntegrable k k
  have hjk := fract_prod_intervalIntegrable j k
  have hint := intervalIntegral.integral_mono_on zero_le_one hjk
    ((hjj.add hkk).div_const 2)
    (fun x _ => fract_prod_le_avg_sq ((j:ℝ)/x) ((k:ℝ)/x))
  have hlin : ∫ x in (0:ℝ)..1,
      (Int.fract ((j:ℝ)/x) * Int.fract ((j:ℝ)/x) +
       Int.fract ((k:ℝ)/x) * Int.fract ((k:ℝ)/x)) / 2 =
      (gramEntry j j + gramEntry k k) / 2 := by
    unfold gramEntry
    rw [show ∀ f : ℝ → ℝ, (fun x => f x / 2) = fun x => (1/2 : ℝ) * f x from
          fun f => funext (fun x => by ring)]
    rw [intervalIntegral.integral_const_mul, show (1:ℝ)/2 = 2⁻¹ from by norm_num,
        inv_mul_eq_div]
    congr 1
    exact intervalIntegral.integral_add hjj hkk
  rw [show gramEntry j k = ∫ x in (0:ℝ)..1, Int.fract ((j:ℝ)/x) * Int.fract ((k:ℝ)/x) from rfl]
  linarith

-- ════════════════════════════════════════════════
-- TIER 1: j,k ≥ 3 VIA gramEntry_le_third
-- ════════════════════════════════════════════════

/-- For j,k ≥ 3: G_{j,k} ≤ 1/3. -/
theorem gramEntry_le_third_offdiag (j k : ℕ) (hj : 3 ≤ j) (hk : 3 ≤ k) :
    gramEntry j k ≤ 1 / 3 := by
  have h3 := gramEntry_le_avg_diag j k
  have h1 := gramEntry_le_third j hj
  have h2 := gramEntry_le_third k hk
  linarith

/-- Arithmetic: 1/3 ≤ 1/4 + 1/(jk) when jk ≤ 12. -/
private lemma third_le_quarter_plus_inv (j k : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k)
    (hjk_le : j * k ≤ 12) :
    (1 : ℝ) / 3 ≤ 1 / 4 + 1 / ((j : ℝ) * (k : ℝ)) := by
  have hj_pos : (0 : ℝ) < (j : ℝ) := Nat.cast_pos.mpr (by omega)
  have hk_pos : (0 : ℝ) < (k : ℝ) := Nat.cast_pos.mpr (by omega)
  have hjk_pos : (0 : ℝ) < (j : ℝ) * (k : ℝ) := mul_pos hj_pos hk_pos
  have hjk_cast : (j : ℝ) * (k : ℝ) ≤ 12 := by exact_mod_cast hjk_le
  rw [div_add_div _ _ (by norm_num : (4:ℝ) ≠ 0) (ne_of_gt hjk_pos),
      div_le_div_iff₀ (by norm_num : (0:ℝ) < 3) (mul_pos (by norm_num : (0:ℝ) < 4) hjk_pos)]
  nlinarith

/-- G_{j,k} ≤ 1/4+1/(jk) for j,k ≥ 3 with jk ≤ 12. -/
theorem gram_entry_offdiag_upper_amgm (j k : ℕ) (hj : 3 ≤ j) (hk : 3 ≤ k)
    (hjk_le : j * k ≤ 12) :
    gramEntry j k ≤ 1 / 4 + 1 / ((j : ℝ) * (k : ℝ)) :=
  le_trans (gramEntry_le_third_offdiag j k hj hk)
    (third_le_quarter_plus_inv j k (by omega) (by omega) hjk_le)

-- ════════════════════════════════════════════════
-- LOG BOUNDS FOR PIECE ESTIMATES
-- ════════════════════════════════════════════════

/-- log(2) ≥ 2/3 via decomposition ln2 = ln(4/3) + ln(3/2) + quartic Taylor. -/
private lemma log_two_lower : Real.log 2 ≥ 2 / 3 := by
  have h1 : Real.log 2 = Real.log (4/3) + Real.log (3/2) := by
    rw [← Real.log_mul (by norm_num : (4:ℝ)/3 ≠ 0) (by norm_num : (3:ℝ)/2 ≠ 0)]
    norm_num
  rw [h1]
  have hlog43 := log_lower_quartic (1/(3:ℝ)) (by norm_num)
  have hlog32 := log_lower_quartic (1/(2:ℝ)) (by norm_num)
  rw [show (1:ℝ) + 1/3 = 4/3 from by ring] at hlog43
  rw [show (1:ℝ) + 1/2 = 3/2 from by ring] at hlog32
  have h43 : (1:ℝ)/3 - (1/3)^2/2 + (1/3)^3/3 - (1/3)^4/4 = 31/108 := by norm_num
  have h32 : (1:ℝ)/2 - (1/2)^2/2 + (1/2)^3/3 - (1/2)^4/4 = 77/192 := by norm_num
  rw [h43] at hlog43; rw [h32] at hlog32
  linarith

/-- Piece bound at n=1: 3/2 - 2·ln2 ≤ 1/6. -/
private lemma piece_sq_upper_bound_n1 :
    (2*(1:ℝ)+1)/((1:ℝ)+1) - 2*(1:ℝ) * Real.log (1 + 1/(1:ℝ))
    ≤ 1 / (3 * (1:ℝ) * ((1:ℝ)+1)) := by
  have h := log_two_lower
  rw [show (1:ℝ) + 1/1 = 2 from by ring]
  norm_num
  linarith

/-- Piece bound at n=2: 5/3 - 4·ln(3/2) ≤ 1/18. -/
private lemma piece_sq_upper_bound_n2 :
    (2*(2:ℝ)+1)/((2:ℝ)+1) - 2*(2:ℝ) * Real.log (1 + 1/(2:ℝ))
    ≤ 1 / (3 * (2:ℝ) * ((2:ℝ)+1)) := by
  have hsplit : Real.log ((3:ℝ)/2) = Real.log ((5:ℝ)/4) + Real.log ((6:ℝ)/5) := by
    rw [← Real.log_mul (by norm_num : (5:ℝ)/4 ≠ 0) (by norm_num : (6:ℝ)/5 ≠ 0)]
    norm_num
  have h54 := log_lower_quartic (1/(4:ℝ)) (by norm_num)
  have h65 := log_lower_quartic (1/(5:ℝ)) (by norm_num)
  norm_num at h54 h65 hsplit ⊢
  linarith

-- ════════════════════════════════════════════════
-- INFRASTRUCTURE: SUBSTITUTION IDENTITY
-- ════════════════════════════════════════════════

/-- Key periodicity lemma: {j(n+t)} = {jt} for j,n : ℕ, t : ℝ. -/
lemma fract_mul_add_nat (j n : ℕ) (t : ℝ) :
    Int.fract ((j : ℝ) * (↑n + t)) = Int.fract ((j : ℝ) * t) := by
  have : (j : ℝ) * (↑n + t) = (j : ℝ) * t + ↑(j * n) := by push_cast; ring
  rw [this, Int.fract_add_natCast]

/-- Telescoping weight sum. -/
lemma weight_telescope (M : ℕ) :
    (Finset.range M).sum (fun n => 1 / ((n : ℝ) + 1) - 1 / ((n : ℝ) + 2)) =
    1 - 1 / ((M : ℝ) + 1) := by
  induction M with
  | zero => simp
  | succ k ih => rw [Finset.sum_range_succ, ih]; push_cast; field_simp; ring

end
