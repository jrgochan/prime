/-
  Cathedral/GramOffDiag.lean

  ## Off-diagonal Gram entry upper bound: `gramEntry j k ≤ 1/4 + 1/(jk)` for j ≠ k

  ### Proof architecture
  ```
  gram_entry_offdiag_upper' (MAIN THEOREM)
    ├── Case j,k ≥ 3, jk ≤ 12: AM-GM + gramEntry_le_third
    │     ├── fract_prod_le_avg_sq: {a}·{b} ≤ ({a}²+{b}²)/2
    │     └── gramEntry_le_avg_diag: G_{j,k} ≤ (G_{j,j}+G_{k,k})/2
    ├── Case min(j,k) ≤ 2: substitution + IBP (TODO)
    └── Case j,k ≥ 3, jk ≥ 13: refined diagonal + AM-GM (TODO)
  ```
-/

import Cathedral.Defs
import Cathedral.Structural
import Cathedral.FractIntegral
import Cathedral.GramDiag

noncomputable section
open Real MeasureTheory Set

-- ════════════════════════════════════════════════
-- POINTWISE BOUND: AM-GM FOR PRODUCTS OF FRACTIONAL PARTS
-- ════════════════════════════════════════════════

/-- Pointwise AM-GM: {a}·{b} ≤ ({a}² + {b}²)/2 for any a,b : ℝ.
    Proof: (x-y)² ≥ 0 ⟹ x² + y² ≥ 2xy ⟹ xy ≤ (x²+y²)/2. -/
lemma fract_prod_le_avg_sq (a b : ℝ) :
    Int.fract a * Int.fract b ≤ (Int.fract a * Int.fract a + Int.fract b * Int.fract b) / 2 := by
  nlinarith [sq_nonneg (Int.fract a - Int.fract b)]

/-- G_{j,k} ≤ G_{j,j}: since {k/x} ∈ [0,1), {j/x}{k/x} ≤ {j/x}·1 = {j/x} ≤ {j/x}².
    Wait: {a} ∈ [0,1) means {a}² ≤ {a}, so {j/x}² ≤ {j/x}, NOT the other way.
    So {j/x}{k/x} ≤ {j/x} and {j/x}² ≤ {j/x}. Both ≤ {j/x}.
    This means G_{j,k} ≤ b_j and G_{j,j} ≤ b_j. Can't conclude G_{j,k} ≤ G_{j,j}.

    Correct approach: {a}{b} ≤ ({a}²+{b}²)/2 by AM-GM.
    Integrate and split: ∫{j/x}{k/x} ≤ (∫{j/x}² + ∫{k/x}²)/2 = (G_{j,j}+G_{k,k})/2. -/
theorem gramEntry_le_avg_diag (j k : ℕ) :
    gramEntry j k ≤ (gramEntry j j + gramEntry k k) / 2 := by
  have hjj := fract_prod_intervalIntegrable j j
  have hkk := fract_prod_intervalIntegrable k k
  have hjk := fract_prod_intervalIntegrable j k
  -- First show ∫ fj·fk ≤ ∫ (fj²+fk²)/2
  have hint := intervalIntegral.integral_mono_on zero_le_one hjk
    ((hjj.add hkk).div_const 2)
    (fun x _ => fract_prod_le_avg_sq ((j:ℝ)/x) ((k:ℝ)/x))
  -- The RHS integral = (∫fj² + ∫fk²)/2 by linearity
  -- ∫ (f(x) + g(x))/2 dx = (1/2) ∫ (f+g) = (1/2)(∫f + ∫g)
  -- Use mul_comm to rewrite /2 as *2⁻¹
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
  -- Now: hint : ∫fj*fk ≤ ∫(fj²+fk²)/2, hlin : ∫(fj²+fk²)/2 = (G_jj+G_kk)/2
  -- Goal: G_jk ≤ (G_jj + G_kk)/2
  rw [show gramEntry j k = ∫ x in (0:ℝ)..1, Int.fract ((j:ℝ)/x) * Int.fract ((k:ℝ)/x) from rfl]
  linarith

-- ════════════════════════════════════════════════
-- TIER 1: AM-GM FOR j,k ≥ 3 WITH jk ≤ 12
-- ════════════════════════════════════════════════

/-- For j,k ≥ 3: G_{j,k} ≤ 1/3.
    Via gramEntry_le_avg_diag + gramEntry_le_third. -/
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
  -- 1/3 ≤ 1/4 + 1/(jk) ⟺ jk ≤ 12
  have h3 : (3:ℝ) ≠ 0 := by norm_num
  have h4 : (4:ℝ) ≠ 0 := by norm_num
  rw [div_add_div _ _ h4 (ne_of_gt hjk_pos), div_le_div_iff₀ (by norm_num : (0:ℝ) < 3)
    (mul_pos (by norm_num : (0:ℝ) < 4) hjk_pos)]
  nlinarith

/-- **THEOREM**: Off-diagonal bound for j,k ≥ 3 with jk ≤ 12.
    The only off-diagonal pairs are (3,4) and (4,3). -/
theorem gram_entry_offdiag_upper_amgm (j k : ℕ) (hj : 3 ≤ j) (hk : 3 ≤ k)
    (hjk_le : j * k ≤ 12) :
    gramEntry j k ≤ 1 / 4 + 1 / ((j : ℝ) * (k : ℝ)) :=
  le_trans (gramEntry_le_third_offdiag j k hj hk)
    (third_le_quarter_plus_inv j k (by omega) (by omega) hjk_le)

-- ════════════════════════════════════════════════
-- INFRASTRUCTURE: SUBSTITUTION IDENTITY
-- ════════════════════════════════════════════════

/-- Key periodicity lemma: {j(n+t)} = {jt} for j,n : ℕ, t : ℝ.
    Since jn is an integer, the fractional part is unaffected. -/
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
