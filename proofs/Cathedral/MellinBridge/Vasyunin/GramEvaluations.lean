/-
  Cathedral/MellinBridge/Vasyunin/GramEvaluations.lean

  Exact evaluations of small Gram matrix entries:
  V(2,1) = 0, G(1,2) exact form, G(1,2) > 0, trace formula.
-/

import Cathedral.MellinBridge.Vasyunin.Structural

noncomputable section
open Real Matrix Finset

namespace Cathedral.Vasyunin

/-- Euler-Mascheroni constant γ ≈ 0.5772 -/
local notation "γ" => Real.eulerMascheroniConstant

-- ════════════════════════════════════════════════
-- GRAM MATRIX TRACE AND SMALL CASES
-- ════════════════════════════════════════════════

/-- **V(2,1) = 0**: The only term has cot(π/2) = cos(π/2)/sin(π/2) = 0.
    Sum: {1·1/2}·cot(π·1/2) = (1/2)·0 = 0. -/
theorem vasyuninSum_two_one : vasyuninSum 2 1 = 0 := by
  unfold vasyuninSum
  simp only [show ¬(2 ≤ 1) from by omega, ↓reduceIte]
  have h_ico : Ico 1 2 = ({1} : Finset ℕ) := by
    ext x; simp
  rw [h_ico, Finset.sum_singleton]
  unfold cot
  have h_cos : Real.cos (Real.pi * (1 : ℕ) / (2 : ℕ)) = 0 := by
    rw [show (Real.pi * (1 : ℕ) / (2 : ℕ) : ℝ) = Real.pi / 2 by push_cast; ring]
    exact Real.cos_pi_div_two
  rw [h_cos]
  simp

/-- The trace of the N×N Gram matrix equals the sum of diagonal entries. -/
theorem vasyuninGramMatrix_trace (N : ℕ) :
    (vasyuninGramMatrix N).trace =
    ∑ i : Fin N, ((Real.log (2 * Real.pi) - γ) / (↑i.val + 1) -
                   1 / (↑i.val + 1) ^ 2) := by
  unfold Matrix.trace
  congr 1
  ext i
  exact vasyuninGramMatrix_diag N i

/-- **G(1,2) exact form**: Since gcd(1,2)=1, j'=1, k'=2, and
    V(1,2) = V(2,1) = 0 (both vanish), we get:
    G(1,2) = 3A/4 - ln(2)/4 - 1/2
    where A = ln(2π) - γ. -/
theorem vasyuninGramEntry_one_two :
    vasyuninGramEntry 1 2 =
    3 * (Real.log (2 * Real.pi) - γ) / 4 -
    Real.log 2 / 4 - 1 / 2 := by
  unfold vasyuninGramEntry
  simp only [show 1 ≠ 2 from by omega, ↓reduceIte]
  simp only [show Nat.gcd 1 2 = 1 from by norm_num,
             show 1 / 1 = 1 from by norm_num,
             show 2 / 1 = 2 from by norm_num]
  rw [vasyuninSum_one, vasyuninSum_two_one]
  push_cast
  rw [show (2 : ℝ) / (1 : ℝ) = 2 by norm_num]
  rw [show Real.log (2 : ℝ) = Real.log 2 from rfl]
  ring

/-- **G(1,2) > 0**: The off-diagonal Gram entry is strictly positive.
    From the exact form G(1,2) = 3A/4 - ln(2)/4 - 1/2, we need 3A > ln(2) + 2.
    Using ln(2) > 0.693, ln(π) > 1, γ < 2/3:
    LHS > 2·0.693 + 3 = 4.386 > 4 > 2 + 2 = RHS. -/
theorem vasyuninGramEntry_one_two_pos : vasyuninGramEntry 1 2 > 0 := by
  rw [vasyuninGramEntry_one_two]
  have h_log2 : (0.6931471803 : ℝ) < Real.log 2 := Real.log_two_gt_d9
  have h_e_lt_3 : Real.exp 1 < 3 := Real.exp_one_lt_three
  have h_pi_gt : (3 : ℝ) < Real.pi := pi_gt_three
  have h_gamma : Real.eulerMascheroniConstant < 2 / 3 :=
    Real.eulerMascheroniConstant_lt_two_thirds
  have h_log3 : 1 < Real.log 3 := by
    rw [show (1 : ℝ) = Real.log (Real.exp 1) from (Real.log_exp 1).symm]
    exact Real.log_lt_log (Real.exp_pos 1) h_e_lt_3
  have h_logpi : 1 < Real.log Real.pi :=
    lt_trans h_log3 (Real.log_lt_log (by norm_num : (0:ℝ) < 3) h_pi_gt)
  have h_log2pi : Real.log (2 * Real.pi) = Real.log 2 + Real.log Real.pi :=
    Real.log_mul (by norm_num : (2:ℝ) ≠ 0) (ne_of_gt Real.pi_pos)
  rw [h_log2pi]
  linarith

/-- **3⁷ ≥ 2¹¹** (2187 ≥ 2048), hence ln(3) ≥ 11·ln(2)/7 ≈ 1.089.
    This is the crucial number-theoretic bound that unlocks det(G₂) > 0. -/
theorem log_three_ge_11_log_two_div_7 :
    Real.log 3 ≥ 11 * Real.log 2 / 7 := by
  rw [ge_iff_le, div_le_iff₀ (by norm_num : (0:ℝ) < 7)]
  rw [show 11 * Real.log 2 = Real.log (2 ^ 11) by rw [Real.log_pow]; ring]
  rw [show Real.log 3 * 7 = Real.log (3 ^ 7) by rw [Real.log_pow]; ring]
  exact Real.log_le_log (by norm_num : (0:ℝ) < 2 ^ 11) (by norm_num)

/-- **det(G₂) > 0**: The 2×2 leading minor of the Gram matrix has positive
    determinant. Combined with G(1,1) > 0, this proves the 2×2 Gram matrix
    is positive definite (Sylvester's criterion).

    det(G₂) = G(1,1)·G(2,2) - G(1,2)²
    where G(1,1) = A - 1, G(2,2) = A/2 - 1/4, G(1,2) = 3A/4 - L/4 - 1/2
    and A = ln(2π) - γ, L = ln(2).

    Numerically: det ≈ 0.025 > 0.

    The proof uses the key bound 3⁷ ≥ 2¹¹ to establish
    ln(π) > 11·ln(2)/7 ≈ 1.089, which provides enough arithmetic
    precision for nlinarith to close the polynomial inequality. -/
theorem vasyuninGram2x2_det_pos :
    vasyuninGramEntry 1 1 * vasyuninGramEntry 2 2 -
    vasyuninGramEntry 1 2 * vasyuninGramEntry 1 2 > 0 := by
  rw [vasyuninGramEntry_diag 1, vasyuninGramEntry_diag 2, vasyuninGramEntry_one_two]
  have h_log2pi : Real.log (2 * Real.pi) = Real.log 2 + Real.log Real.pi :=
    Real.log_mul (by norm_num : (2:ℝ) ≠ 0) (ne_of_gt Real.pi_pos)
  rw [h_log2pi]
  set l := Real.log 2
  set p := Real.log Real.pi
  set g := Real.eulerMascheroniConstant
  -- Bounds
  have hl : (0.6931471803 : ℝ) < l := Real.log_two_gt_d9
  have hg_lo : (1:ℝ)/2 < g := Real.one_half_lt_eulerMascheroniConstant
  have hg_hi : g < 2/3 := Real.eulerMascheroniConstant_lt_two_thirds
  -- The crucial bound: ln(π) > 11·ln(2)/7 (from 3^7 > 2^11 and π > 3)
  have h_logpi : p > 11 * l / 7 := by
    calc p > Real.log 3 :=
              Real.log_lt_log (by norm_num : (0:ℝ) < 3) pi_gt_three
         _ ≥ 11 * l / 7 := log_three_ge_11_log_two_div_7
  -- Upper bound: ln(π) ≤ 2·ln(2) (from π ≤ 4)
  have h_p_le : p ≤ 2 * l := by
    rw [show 2 * l = Real.log (2 ^ 2) from by rw [Real.log_pow]; ring]
    exact Real.log_le_log Real.pi_pos (by norm_num; exact pi_le_four)
  -- Normalize Nat casts
  push_cast
  -- nlinarith closes with the tight bound on p
  nlinarith [sq_nonneg (p - 11*l/7), sq_nonneg (g - 1/2), sq_nonneg (l - 0.7),
             mul_pos (show (0:ℝ) < l by linarith) (show (0:ℝ) < p by linarith),
             mul_pos (show (0:ℝ) < l by linarith) (show (0:ℝ) < l - g by linarith)]

/-- **G(2,1) = G(1,2)**: Symmetry of the off-diagonal entry. -/
theorem vasyuninGramEntry_two_one :
    vasyuninGramEntry 2 1 = vasyuninGramEntry 1 2 :=
  vasyuninGramEntry_comm 2 1

/-- **V(3,1)**: For a = 3, b = 1, the sum has two terms:
    {1/3}·cot(π/3) + {2/3}·cot(2π/3). -/
theorem vasyuninSum_three_one :
    vasyuninSum 3 1 =
    Int.fract (1 / (3 : ℝ)) * cot (Real.pi * 1 / 3) +
    Int.fract (2 / (3 : ℝ)) * cot (Real.pi * 2 / 3) := by
  unfold vasyuninSum
  simp only [show ¬(3 ≤ 1) from by omega, ↓reduceIte]
  have h_ico : Ico 1 3 = ({1, 2} : Finset ℕ) := by
    ext x; simp; omega
  rw [h_ico]
  simp only [Finset.sum_pair (by norm_num : (1:ℕ) ≠ 2)]
  push_cast
  norm_num

/-- **V(3,2)**: For a = 3, b = 2, the sum has two terms:
    {2/3}·cot(π/3) + {4/3}·cot(2π/3). -/
theorem vasyuninSum_three_two :
    vasyuninSum 3 2 =
    Int.fract (2 / (3 : ℝ)) * cot (Real.pi * 1 / 3) +
    Int.fract (4 / (3 : ℝ)) * cot (Real.pi * 2 / 3) := by
  unfold vasyuninSum
  simp only [show ¬(3 ≤ 1) from by omega, ↓reduceIte]
  have h_ico : Ico 1 3 = ({1, 2} : Finset ℕ) := by
    ext x; simp; omega
  rw [h_ico]
  simp only [Finset.sum_pair (by norm_num : (1:ℕ) ≠ 2)]
  push_cast
  norm_num

-- ════════════════════════════════════════════════
-- FRACTIONAL PARTS
-- ════════════════════════════════════════════════

/-- {1/3} = 1/3: the fractional part of 1/3 is 1/3. -/
theorem fract_one_third : Int.fract (1 / (3 : ℝ)) = 1 / 3 := by
  rw [Int.fract_eq_self.mpr ⟨by norm_num, by norm_num⟩]

/-- {2/3} = 2/3: the fractional part of 2/3 is 2/3. -/
theorem fract_two_thirds : Int.fract (2 / (3 : ℝ)) = 2 / 3 := by
  rw [Int.fract_eq_self.mpr ⟨by norm_num, by norm_num⟩]

/-- {4/3} = 1/3: since 4/3 = 1 + 1/3, the fractional part is 1/3. -/
theorem fract_four_thirds : Int.fract (4 / (3 : ℝ)) = 1 / 3 := by
  rw [show (4 : ℝ) / 3 = 1 / 3 + 1 from by ring]
  rw [Int.fract_add_one]
  exact fract_one_third

-- ════════════════════════════════════════════════
-- COTANGENT EVALUATIONS
-- ════════════════════════════════════════════════

/-- cot(π/3) = cos(π/3) / sin(π/3) = (1/2) / (√3/2) = 1/√3. -/
theorem cot_pi_div_three :
    cot (Real.pi / 3) = 1 / Real.sqrt 3 := by
  unfold cot
  rw [cos_pi_div_three, sin_pi_div_three]
  have h2 : (2:ℝ) ≠ 0 := by norm_num
  field_simp

/-- cot(2π/3) = -1/√3.
    Proof: 2π/3 = π - π/3, so cos(2π/3) = -cos(π/3) = -1/2
    and sin(2π/3) = sin(π/3) = √3/2. -/
theorem cot_two_pi_div_three :
    cot (2 * Real.pi / 3) = -(1 / Real.sqrt 3) := by
  unfold cot
  rw [show 2 * Real.pi / 3 = Real.pi - Real.pi / 3 by ring]
  rw [Real.cos_pi_sub, Real.sin_pi_sub, cos_pi_div_three, sin_pi_div_three]
  have h2 : (2:ℝ) ≠ 0 := by norm_num
  field_simp

-- ════════════════════════════════════════════════
-- CLOSED FORM V(3,k)
-- ════════════════════════════════════════════════

/-- **V(3,1) = -1/(3√3)**: The Vasyunin sum evaluates to an exact irrational.
    = (1/3)·(1/√3) + (2/3)·(-1/√3) = (1-2)/(3√3) = -1/(3√3). -/
theorem vasyuninSum_three_one_val :
    vasyuninSum 3 1 = -(1 / (3 * Real.sqrt 3)) := by
  rw [vasyuninSum_three_one]
  rw [show Real.pi * 1 / 3 = Real.pi / 3 by ring]
  rw [show Real.pi * 2 / 3 = 2 * Real.pi / 3 by ring]
  rw [fract_one_third, fract_two_thirds, cot_pi_div_three, cot_two_pi_div_three]
  ring

/-- **V(3,2) = 1/(3√3)**: By similar calculation.
    = (2/3)·(1/√3) + (1/3)·(-1/√3) = (2-1)/(3√3) = 1/(3√3). -/
theorem vasyuninSum_three_two_val :
    vasyuninSum 3 2 = 1 / (3 * Real.sqrt 3) := by
  rw [vasyuninSum_three_two]
  rw [show Real.pi * 1 / 3 = Real.pi / 3 by ring]
  rw [show Real.pi * 2 / 3 = 2 * Real.pi / 3 by ring]
  rw [fract_two_thirds, fract_four_thirds, cot_pi_div_three, cot_two_pi_div_three]
  ring

-- ════════════════════════════════════════════════
-- G(1,3) EXACT FORM
-- ════════════════════════════════════════════════

/-- **G(1,3) exact form**: Since gcd(1,3)=1, j'=1, k'=3, and
    V(1,3) = 0, V(3,1) = -1/(3√3), we get:
    G(1,3) = 2A/3 - ln(3)/3 + π/(18√3) - 1/3
    where A = ln(2π) - γ. -/
theorem vasyuninGramEntry_one_three :
    vasyuninGramEntry 1 3 =
    2 * (Real.log (2 * Real.pi) - γ) / 3 -
    Real.log 3 / 3 +
    Real.pi / (18 * Real.sqrt 3) - 1 / 3 := by
  unfold vasyuninGramEntry
  simp only [show 1 ≠ 3 from by omega, ↓reduceIte]
  simp only [show Nat.gcd 1 3 = 1 from by norm_num,
             show 1 / 1 = 1 from by norm_num,
             show 3 / 1 = 3 from by norm_num]
  rw [vasyuninSum_one, vasyuninSum_three_one_val]
  push_cast
  rw [show (3 : ℝ) / (1 : ℝ) = 3 by norm_num]
  rw [show Real.log (3 : ℝ) = Real.log 3 from rfl]
  ring

/-- **G(3,3) exact form**: The third diagonal entry.
    G(3,3) = (ln(2π) - γ)/3 - 1/9. -/
theorem vasyuninGramEntry_three_three :
    vasyuninGramEntry 3 3 =
    (Real.log (2 * Real.pi) - γ) / 3 - 1 / 9 := by
  rw [vasyuninGramEntry_diag]; push_cast; ring

/-- **Third mean entry**: b₃ = (ln(3) + 1 - γ)/3. -/
theorem vasyuninMeanEntry_three :
    vasyuninMeanEntry 3 = (Real.log 3 + 1 - γ) / 3 := by
  unfold vasyuninMeanEntry; norm_num

/-- **V(2,b) = 0 for all b**: The sum has one term {b/2}·cot(π/2).
    Since cot(π/2) = cos(π/2)/sin(π/2) = 0/1 = 0, the term vanishes.
    This generalizes V(2,1) = 0. -/
theorem vasyuninSum_two (b : ℕ) : vasyuninSum 2 b = 0 := by
  unfold vasyuninSum
  simp only [show ¬(2 ≤ 1) from by omega, ↓reduceIte]
  have h_ico : Ico 1 2 = ({1} : Finset ℕ) := by ext x; simp
  rw [h_ico, Finset.sum_singleton]
  unfold cot
  have h_cos : Real.cos (Real.pi * (1 : ℕ) / (2 : ℕ)) = 0 := by
    rw [show (Real.pi * (1 : ℕ) / (2 : ℕ) : ℝ) = Real.pi / 2 by push_cast; ring]
    exact Real.cos_pi_div_two
  rw [h_cos]; simp

/-- **G(2,3) exact form**: Since gcd(2,3)=1, j'=2, k'=3,
    V(2,3) = 0, V(3,2) = 1/(3√3), we get:
    G(2,3) = 5A/12 - ln(3/2)/12 - π/(36√3) - 1/6
    where A = ln(2π) - γ. -/
theorem vasyuninGramEntry_two_three :
    vasyuninGramEntry 2 3 =
    5 * (Real.log (2 * Real.pi) - γ) / 12 -
    Real.log (3 / 2) / 12 -
    Real.pi / (36 * Real.sqrt 3) -
    1 / 6 := by
  unfold vasyuninGramEntry
  simp only [show 2 ≠ 3 from by omega, ↓reduceIte]
  simp only [show Nat.gcd 2 3 = 1 from by norm_num,
             show 2 / 1 = 2 from by norm_num,
             show 3 / 1 = 3 from by norm_num]
  rw [vasyuninSum_two 3, vasyuninSum_three_two_val]
  push_cast
  rw [show (3 : ℝ) / (2 : ℝ) = 3 / 2 by norm_num]
  ring

-- ════════════════════════════════════════════════
-- OFF-DIAGONAL POSITIVITY
-- ════════════════════════════════════════════════

/-- √3 < 2: since 3 < 4 = 2². -/
theorem sqrt_three_lt_two : Real.sqrt 3 < 2 := by
  have : Real.sqrt 3 < Real.sqrt 4 := Real.sqrt_lt_sqrt (by norm_num) (by norm_num)
  rwa [show Real.sqrt 4 = 2 from by
    rw [show (4:ℝ) = 2^2 by norm_num, Real.sqrt_sq (by norm_num : (0:ℝ) ≤ 2)]] at this

/-- **G(1,3) > 0**: The off-diagonal entry is strictly positive.
    Uses π > 3, √3 < 2 to bound π/(18√3) > 1/12, then
    combines with ln(π) > 11·ln(2)/7 from our 3⁷ ≥ 2¹¹ bound. -/
theorem vasyuninGramEntry_one_three_pos : vasyuninGramEntry 1 3 > 0 := by
  rw [vasyuninGramEntry_one_three]
  have h_log2pi : Real.log (2 * Real.pi) = Real.log 2 + Real.log Real.pi :=
    Real.log_mul (by norm_num : (2:ℝ) ≠ 0) (ne_of_gt Real.pi_pos)
  rw [h_log2pi]
  set l := Real.log 2
  set p := Real.log Real.pi
  set g := Real.eulerMascheroniConstant
  set s := Real.sqrt 3
  -- Bounds
  have hl : (0.6931471803 : ℝ) < l := Real.log_two_gt_d9
  have hg_hi : g < 2/3 := Real.eulerMascheroniConstant_lt_two_thirds
  have h_logpi : p > 11 * l / 7 := by
    calc p > Real.log 3 :=
              Real.log_lt_log (by norm_num : (0:ℝ) < 3) pi_gt_three
         _ ≥ 11 * l / 7 := log_three_ge_11_log_two_div_7
  -- ln(3) < 2·ln(2) (since 3 < 4 = 2²)
  have h_log3 : Real.log 3 < 2 * l := by
    rw [show 2 * l = Real.log (2 ^ 2) from by rw [Real.log_pow]; ring]
    exact Real.log_lt_log (by norm_num : (0:ℝ) < 3) (by norm_num)
  -- π/(18√3) > 1/12 (since π > 3, √3 < 2)
  have hs_pos : (0 : ℝ) < s := Real.sqrt_pos.mpr (by norm_num : (0:ℝ) < 3)
  have hs_lt : s < 2 := sqrt_three_lt_two
  have h_pi_term : Real.pi / (18 * s) > 1 / 12 := by
    have h18s_pos : (0:ℝ) < 18 * s := by positivity
    rw [gt_iff_lt, div_lt_div_iff₀ (by norm_num : (0:ℝ) < 12) h18s_pos]
    nlinarith [pi_gt_three]
  -- Now close: the positive terms overcome the negative ones
  nlinarith [h_log3, h_logpi, h_pi_term]

/-- √3 > 1: since 3 > 1. -/
theorem one_lt_sqrt_three : (1 : ℝ) < Real.sqrt 3 := by
  rw [show (1 : ℝ) = Real.sqrt 1 from by simp]
  exact Real.sqrt_lt_sqrt (by norm_num) (by norm_num)

/-- **G(2,3) > 0**: The off-diagonal entry is strictly positive.
    Uses ln(3/2) < ln(2), π/(36√3) < 1/9, and ln(π) > 11·ln(2)/7. -/
theorem vasyuninGramEntry_two_three_pos : vasyuninGramEntry 2 3 > 0 := by
  rw [vasyuninGramEntry_two_three]
  have h_log2pi : Real.log (2 * Real.pi) = Real.log 2 + Real.log Real.pi :=
    Real.log_mul (by norm_num : (2:ℝ) ≠ 0) (ne_of_gt Real.pi_pos)
  rw [h_log2pi]
  set l := Real.log 2
  set p := Real.log Real.pi
  set g := Real.eulerMascheroniConstant
  set s := Real.sqrt 3
  -- Bounds
  have hl : (0.6931471803 : ℝ) < l := Real.log_two_gt_d9
  have hg_hi : g < 2/3 := Real.eulerMascheroniConstant_lt_two_thirds
  have h_logpi : p > 11 * l / 7 := by
    calc p > Real.log 3 :=
              Real.log_lt_log (by norm_num : (0:ℝ) < 3) pi_gt_three
         _ ≥ 11 * l / 7 := log_three_ge_11_log_two_div_7
  -- ln(3/2) < ln(2) (since 3/2 < 2)
  have h_log32 : Real.log (3 / 2) < l := by
    exact Real.log_lt_log (by norm_num : (0:ℝ) < 3/2) (by norm_num)
  -- ln(3/2) > 0
  have h_log32_pos : Real.log (3 / 2) > 0 :=
    Real.log_pos (by norm_num : (1:ℝ) < 3/2)
  -- π/(36√3) < 1/9 (since π < 4, √3 > 1)
  have hs_pos : (0 : ℝ) < s := Real.sqrt_pos.mpr (by norm_num : (0:ℝ) < 3)
  have hs_gt : (1 : ℝ) < s := one_lt_sqrt_three
  have h_pi_upper : Real.pi / (36 * s) < 1 / 9 := by
    have h36s_pos : (0:ℝ) < 36 * s := by positivity
    rw [div_lt_div_iff₀ h36s_pos (by norm_num : (0:ℝ) < 9)]
    -- Need: 9 * π < 36 * s, i.e. π < 4s
    -- π ≤ 4 and s > 1, so π < 4 ≤ 4s
    nlinarith [pi_le_four]
  have h_pi_pos : Real.pi / (36 * s) > 0 := by positivity
  -- nlinarith closes
  nlinarith [h_log32, h_logpi, h_pi_upper, h_pi_pos]

end Cathedral.Vasyunin
