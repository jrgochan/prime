/-
  Cathedral/Vasyunin/Cotangent/FormulaBridge.lean

  ## Bridge: vasyuninGramEntry = vasyuninGramFormula

  The Cathedral has two definitions of the same cotangent sum:
  - `vasyuninSum` (Defs.lean): uses `cot x = cos x / sin x`, range `Ico 1 a`
  - `vasyuninCotSum` (DigammaReflection.lean): uses `1 / tan x`, range `Icc 1 (a-1)`

  And two definitions of the Gram formula:
  - `vasyuninGramEntry` (Defs.lean): the source-of-truth definition
  - `vasyuninGramFormula` (DigammaReflection.lean): the proof target

  This file bridges them, proving they are equal for j ≠ k, j,k ≥ 1.

  Created: April 25, 2026 — The Weekend Assault, Phase 3
  Status: IN PROGRESS
-/

import Cathedral.Vasyunin.Defs
import Cathedral.Vasyunin.Cotangent.DigammaReflection

noncomputable section
open Real Finset

namespace Cathedral.Vasyunin.FormulaBridge

-- ════════════════════════════════════════════════
-- §1. COT = 1/TAN BRIDGE
-- ════════════════════════════════════════════════

/-- `cot x = 1 / tan x` when sin x ≠ 0.
    Both are cos(x)/sin(x). -/
theorem cot_eq_inv_tan (x : ℝ) (_hsin : Real.sin x ≠ 0) :
    Cathedral.Vasyunin.cot x = 1 / Real.tan x := by
  unfold Cathedral.Vasyunin.cot
  -- 1 / tan x = 1 / (sin x / cos x) = cos x / sin x
  rw [Real.tan_eq_sin_div_cos, one_div, inv_div]

-- ════════════════════════════════════════════════
-- §2. SUMMATION RANGE BRIDGE: Ico 1 a = Icc 1 (a-1)
-- ════════════════════════════════════════════════

/-- `Ico 1 a = Icc 1 (a-1)` for natural numbers with a ≥ 2. -/
theorem ico_eq_icc_pred (a : ℕ) (ha : 2 ≤ a) :
    Ico 1 a = Icc 1 (a - 1) := by
  ext m; simp [Finset.mem_Ico, Finset.mem_Icc]; omega

-- ════════════════════════════════════════════════
-- §3. CAST BRIDGE: (m * b : ℕ) / (a : ℝ) = (m:ℝ) * (b:ℝ) / (a:ℝ)
-- ════════════════════════════════════════════════

/-- Natural number multiplication cast to reals. -/
theorem nat_mul_cast_div (m b a : ℕ) :
    ((m * b : ℕ) : ℝ) / (a : ℝ) = (m : ℝ) * (b : ℝ) / (a : ℝ) := by
  rw [Nat.cast_mul]

-- ════════════════════════════════════════════════
-- §4. THE MAIN BRIDGE: vasyuninSum = vasyuninCotSum
-- ════════════════════════════════════════════════

/-- **THE SUM BRIDGE**: The two cotangent sum definitions are equal.

    `vasyuninSum a b` (from Defs.lean, uses cot = cos/sin, range Ico 1 a)
    = `vasyuninCotSum a b` (from DigammaReflection.lean, uses 1/tan, range Icc 1 (a-1))

    For a ≤ 1: both are 0.
    For a ≥ 2: proved by showing each summand is equal. -/
theorem vasyuninSum_eq_vasyuninCotSum (a b : ℕ) :
    Cathedral.Vasyunin.vasyuninSum a b =
    DigammaReflection.vasyuninCotSum a b := by
  by_cases ha : a ≤ 1
  · -- Both are 0 when a ≤ 1
    rw [Cathedral.Vasyunin.vasyuninSum]
    simp [ha]
    exact (DigammaReflection.vasyuninCotSum_of_le_one b ha).symm
  · -- a ≥ 2 case
    push Not at ha
    have ha2 : 2 ≤ a := by omega
    unfold Cathedral.Vasyunin.vasyuninSum DigammaReflection.vasyuninCotSum
    simp only [show ¬(a ≤ 1) from by omega, ↓reduceIte]
    rw [ico_eq_icc_pred a ha2]
    apply Finset.sum_congr rfl
    intro m hm
    -- Each summand: fract and trig parts
    congr 1
    · -- Fractional part: (m * b : ℕ) / a = (m : ℝ) * (b : ℝ) / a
      rw [nat_mul_cast_div]
    · -- Trig: cot(πm/a) = 1/tan(πm/a)
      rw [cot_eq_inv_tan]
      -- sin(πm/a) ≠ 0 because m ∈ {1,...,a-1}, so πm/a ∈ (0,π)
      simp [Finset.mem_Icc] at hm
      have ha_pos : (0:ℝ) < (a:ℝ) := Nat.cast_pos.mpr (by omega)
      have hm_pos : (0:ℝ) < (m:ℝ) := Nat.cast_pos.mpr (by omega)
      have hma_lt : (m:ℝ) < (a:ℝ) := by exact_mod_cast (by omega : m < a)
      -- πm/a ∈ (0, π)
      have harg_pos : 0 < Real.pi * (m:ℝ) / (a:ℝ) := by positivity
      have harg_lt_pi : Real.pi * (m:ℝ) / (a:ℝ) < Real.pi := by
        rw [div_lt_iff₀ ha_pos, mul_comm]
        calc (m:ℝ) * Real.pi < (a:ℝ) * Real.pi :=
              mul_lt_mul_of_pos_right hma_lt Real.pi_pos
          _ = Real.pi * (a:ℝ) := mul_comm _ _
      exact ne_of_gt (Real.sin_pos_of_pos_of_lt_pi harg_pos harg_lt_pi)

-- ════════════════════════════════════════════════
-- §5. THE GRAM FORMULA BRIDGE
-- ════════════════════════════════════════════════

/-- **THE FORMULA BRIDGE**: `vasyuninGramEntry j k = vasyuninGramFormula j k`
    for j ≠ k with j, k ≥ 1.

    Both formulas compute the same expression with d = gcd(j,k),
    but use different definitions of the cotangent sum. -/
theorem vasyuninGramEntry_eq_vasyuninGramFormula (j k : ℕ)
    (_hj : 1 ≤ j) (_hk : 1 ≤ k) (hjk : j ≠ k) :
    Cathedral.Vasyunin.vasyuninGramEntry j k =
    DigammaReflection.vasyuninGramFormula j k := by
  unfold Cathedral.Vasyunin.vasyuninGramEntry DigammaReflection.vasyuninGramFormula
  simp only [hjk, ↓reduceIte]
  -- Both use the same terms with the same GCD structure.
  -- The only difference is the cotangent sum.
  rw [vasyuninSum_eq_vasyuninCotSum, vasyuninSum_eq_vasyuninCotSum]

end Cathedral.Vasyunin.FormulaBridge
