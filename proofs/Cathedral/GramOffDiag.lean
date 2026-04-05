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
-- GENERALIZED DIAGONAL BOUND: G_{j,j} ≤ 1/3 FOR ALL j ≥ 1
-- ════════════════════════════════════════════════

/-- Piece bound for ALL n ≥ 1: dispatches to n=1, n=2, or n≥3 cases. -/
private lemma piece_sq_upper_bound_all (n : ℕ) (hn : 1 ≤ n) :
    (2*(n:ℝ)+1)/((n:ℝ)+1) - 2*(n:ℝ)* Real.log (1 + 1/(n:ℝ))
    ≤ 1 / (3 * (n:ℝ) * ((n:ℝ)+1)) := by
  by_cases h3 : 3 ≤ n
  · exact piece_sq_upper_bound n h3
  · interval_cases n
    · push_cast; exact piece_sq_upper_bound_n1
    · push_cast; exact piece_sq_upper_bound_n2

/-- Piece integral bound for j ≥ 1, n ≥ 1 (extends fract_sq_piece_bound). -/
private lemma fract_sq_piece_bound_all (j n : ℕ) (hj : 1 ≤ j) (hn : 1 ≤ n) :
    ∫ x in ((j:ℝ)/((n:ℝ)+1))..((j:ℝ)/(n:ℝ)),
      Int.fract ((j:ℝ)/x) * Int.fract ((j:ℝ)/x) ≤
    (j:ℝ) / (3 * (n:ℝ) * ((n:ℝ)+1)) := by
  have hj_pos : (0:ℝ) < (j:ℝ) := Nat.cast_pos.mpr (by omega)
  have hn_pos : (0:ℝ) < (n:ℝ) := Nat.cast_pos.mpr (by omega)
  have hle : (j:ℝ)/((n:ℝ)+1) ≤ (j:ℝ)/(n:ℝ) :=
    div_le_div_of_nonneg_left (le_of_lt hj_pos) hn_pos (by linarith)
  have hae : ∫ x in ((j:ℝ)/((n:ℝ)+1))..((j:ℝ)/(n:ℝ)),
      Int.fract ((j:ℝ)/x) * Int.fract ((j:ℝ)/x) =
      ∫ x in ((j:ℝ)/((n:ℝ)+1))..((j:ℝ)/(n:ℝ)), ((j:ℝ)/x - (n:ℝ))^2 := by
    rw [intervalIntegral.integral_of_le hle, intervalIntegral.integral_of_le hle]
    exact integral_congr_ae ((ae_restrict_mem measurableSet_Ioc).mono (fun x hx => by
      show Int.fract ((j:ℝ)/x) * Int.fract ((j:ℝ)/x) = ((j:ℝ)/x - (n:ℝ))^2
      rw [fract_div_eq_on_Ioc j n hj hn x hx.1 hx.2]; ring))
  rw [hae, integral_sq_div_sub_const j n hj hn]
  calc (j:ℝ) * ((2*(n:ℝ)+1)/((n:ℝ)+1) - 2*(n:ℝ)* Real.log (1 + 1/(n:ℝ)))
      ≤ (j:ℝ) * (1 / (3 * (n:ℝ) * ((n:ℝ)+1))) :=
        mul_le_mul_of_nonneg_left (piece_sq_upper_bound_all n hn) (by positivity)
    _ = (j:ℝ) / (3 * (n:ℝ) * ((n:ℝ)+1)) := by ring

private lemma tele_sum (j : ℕ) (hj : 1 ≤ j) (M : ℕ) :
    (Finset.range (M+1)).sum (fun m =>
      (j:ℝ) / (3 * ((j:ℝ)+(m:ℝ)) * ((j:ℝ)+(m:ℝ)+1))) =
    (j:ℝ)/3 * (1/(j:ℝ) - 1/((j:ℝ)+(M:ℝ)+1)) := by
  have hj_pos : (0:ℝ) < (j:ℝ) := Nat.cast_pos.mpr (by omega)
  -- Step 1: factor out j/3
  have hrw : ∀ m : ℕ, (j:ℝ) / (3 * ((j:ℝ)+(m:ℝ)) * ((j:ℝ)+(m:ℝ)+1)) =
      (j:ℝ)/3 * (1/((j:ℝ)+(m:ℝ)) - 1/((j:ℝ)+(m:ℝ)+1)) := by
    intro m; field_simp; ring
  -- Step 2: telescope the inner sum
  have htele : ∀ M' : ℕ, ∑ m ∈ Finset.range (M'+1),
      (1/((j:ℝ)+(m:ℝ)) - 1/((j:ℝ)+(m:ℝ)+1)) =
      1/(j:ℝ) - 1/((j:ℝ)+(M':ℝ)+1) := by
    intro M'; induction M' with
    | zero => simp
    | succ k ih => rw [Finset.sum_range_succ, ih]; push_cast; field_simp; ring
  -- Combine
  calc (Finset.range (M+1)).sum (fun m =>
        (j:ℝ) / (3 * ((j:ℝ)+(m:ℝ)) * ((j:ℝ)+(m:ℝ)+1)))
      = (Finset.range (M+1)).sum (fun m =>
        (j:ℝ)/3 * (1/((j:ℝ)+(m:ℝ)) - 1/((j:ℝ)+(m:ℝ)+1))) := by
          congr 1; ext m; exact hrw m
    _ = (j:ℝ)/3 * (Finset.range (M+1)).sum (fun m =>
        1/((j:ℝ)+(m:ℝ)) - 1/((j:ℝ)+(m:ℝ)+1)) := by rw [Finset.mul_sum]
    _ = (j:ℝ)/3 * (1/(j:ℝ) - 1/((j:ℝ)+(M:ℝ)+1)) := by rw [htele]

/-- **THEOREM**: G_{j,j} ≤ 1/3 for ALL j ≥ 1. -/
theorem gramEntry_le_third_all (j : ℕ) (hj : 1 ≤ j) :
    gramEntry j j ≤ 1 / 3 := by
  by_cases hj3 : 3 ≤ j
  · exact gramEntry_le_third j hj3
  have hj_pos : (0:ℝ) < (j:ℝ) := Nat.cast_pos.mpr (by omega)
  suffices hbound : ∀ M : ℕ, gramEntry j j ≤ 1/3 + 2*(j:ℝ)/(3*((j:ℝ)+(M:ℝ)+1)) by
    by_contra h_neg; push_neg at h_neg
    obtain ⟨N₀, hN₀⟩ := exists_nat_gt (2*(j:ℝ)/(3*(gramEntry j j - 1/3)))
    have hM := hbound N₀
    have hδ_pos : 0 < gramEntry j j - 1/3 := by linarith
    have key : 2*(j:ℝ)/(3*((j:ℝ)+(N₀:ℝ)+1)) < gramEntry j j - 1/3 := by
      rw [div_lt_iff₀ (by positivity : (0:ℝ) < 3*((j:ℝ)+(N₀:ℝ)+1))]
      have h1 : 2*(j:ℝ) < 3*(gramEntry j j - 1/3)*N₀ := by
        rw [div_lt_iff₀ (by positivity : (0:ℝ) < 3*(gramEntry j j - 1/3))] at hN₀; linarith
      nlinarith [show (0:ℝ) ≤ (j:ℝ) from by positivity]
    linarith
  intro M
  set ε := (j:ℝ) / ((j:ℝ) + (M:ℝ) + 1)
  have hε_pos : 0 < ε := by positivity
  unfold gramEntry
  rw [(intervalIntegral.integral_add_adjacent_intervals
    (fract_sq_intervalIntegrable j 0 ε) (fract_sq_intervalIntegrable j ε 1)).symm]
  have htail : ∫ x in (0:ℝ)..ε, Int.fract ((j:ℝ)/x) * Int.fract ((j:ℝ)/x) ≤ ε := by
    linarith [le_abs_self (∫ x in (0:ℝ)..ε, Int.fract ((j:ℝ)/x) * Int.fract ((j:ℝ)/x)),
              (Real.norm_eq_abs _).symm ▸ fract_sq_tail_bound j ε (le_of_lt hε_pos)]
  have hmain : ∫ x in ε..1, Int.fract ((j:ℝ)/x) * Int.fract ((j:ℝ)/x) ≤
      1/3 - (j:ℝ)/(3*((j:ℝ)+(M:ℝ)+1)) := by
    rw [← fract_sq_telescope j hj M]
    have hpieces : ∀ m ∈ Finset.range (M + 1),
        ∫ x in ((j:ℝ)/((j:ℝ)+(m:ℝ)+1))..((j:ℝ)/((j:ℝ)+(m:ℝ))),
          Int.fract ((j:ℝ)/x) * Int.fract ((j:ℝ)/x) ≤
        (j:ℝ) / (3 * ((j:ℝ)+(m:ℝ)) * ((j:ℝ)+(m:ℝ)+1)) := by
      intro m _
      rw [show (j:ℝ) + (m:ℝ) = ((j+m:ℕ):ℝ) from by push_cast; ring]
      exact fract_sq_piece_bound_all j (j+m) hj (by omega)
    have htele := tele_sum j hj M
    have hsimp : (j:ℝ)/3 * (1/(j:ℝ) - 1/((j:ℝ)+(M:ℝ)+1)) =
        1/3 - (j:ℝ)/(3*((j:ℝ)+(M:ℝ)+1)) := by field_simp
    linarith [Finset.sum_le_sum hpieces]
  linarith [show (j:ℝ)/((j:ℝ)+(M:ℝ)+1) + (1/3 - (j:ℝ)/(3*((j:ℝ)+(M:ℝ)+1))) =
    1/3 + 2*(j:ℝ)/(3*((j:ℝ)+(M:ℝ)+1)) from by field_simp; ring]

-- ════════════════════════════════════════════════
-- MAIN THEOREM: ALL j,k ≥ 1 WITH jk ≤ 12
-- ════════════════════════════════════════════════

/-- **MAIN THEOREM**: G_{j,k} ≤ 1/4+1/(jk) for ALL j,k ≥ 1 with jk ≤ 12. -/
theorem gram_entry_offdiag_upper_all (j k : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k)
    (hjk_le : j * k ≤ 12) :
    gramEntry j k ≤ 1 / 4 + 1 / ((j : ℝ) * (k : ℝ)) := by
  have h1 := gramEntry_le_third_all j hj
  have h2 := gramEntry_le_third_all k hk
  have h3 := gramEntry_le_avg_diag j k
  exact le_trans (by linarith) (third_le_quarter_plus_inv j k hj hk hjk_le)


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
