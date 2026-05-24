/-
  Cathedral/Physics/GramWiring/DiagonalShift.lean

  ## THE −1/3 DIAGONAL SHIFT: G_V(k,k) − G^(1)(k,k) → −1/3

  ════════════════════════════════════════════════════════════════

  The Bernoulli-1 Gram matrix G^(1) has constant diagonal:
    G^(1)(k,k) = R(k,k) + 1/4 = 1/12 + 1/4 = 1/3

  The Vasyunin Gram matrix G_V has decaying diagonal:
    G_V(k,k) = (ln(2π) − γ)/k − 1/k²  → 0

  The DIAGONAL SHIFT is their difference:
    Δ_diag(k) = G_V(k,k) − G^(1)(k,k) = (ln(2π) − γ)/k − 1/k² − 1/3

  This converges to −1/3 as k → ∞. The Vasyunin diagonal is
  asymptotically 1/3 SMALLER than the Bernoulli-1 diagonal.

  ### Impact on the Quadratic Form

  The diagonal correction to the quadratic form is:
    vᵀΔ_diag v = Σ_k Δ_diag(k) · v(k)²
               ≈ −(1/3) · ‖v‖² + (ln(2π)−γ) · Σ v(k)²/k
               ≈ [−1/3 + (ln(2π)−γ)] · (6/π²) · logN
               ≈ 0.93 · 0.61 · logN

  versus the Bernoulli-1 diagonal:
    D(N) ≈ (ln(2π)−γ) · (6/π²) · logN ≈ 1.26 · 0.61 · logN

  Ratio of correction to original: (c − 1/3)/c ≈ 0.74

  So the diagonal shift accounts for approximately 26% of the
  Bernoulli-1 diagonal — meaning the Vasyunin diagonal contributes
  only 74% of what the Bernoulli-1 diagonal would predict.

  Status: ALL 12 THEOREMS PROVED. Zero sorry. Zero axioms.
  Dependencies: RamanujanBridge, DiagonalBound, Vasyunin.Defs
  Created: May 20, 2026 — The Lutetium Session 🔬
-/

import Cathedral.Physics.Mertens.RamanujanBridge
import Cathedral.Physics.GramWiring.DiagonalBound

noncomputable section
open Real Finset

namespace Cathedral.Physics.DiagonalShift

-- ════════════════════════════════════════════════════════════════
-- §1. THE BERNOULLI-1 DIAGONAL IS CONSTANT 1/3
-- ════════════════════════════════════════════════════════════════

/-- **THEOREM**: The Bernoulli-1 Gram diagonal is constant 1/3.

    G^(1)(k,k) = R(k,k) + 1/4 = 1/12 + 1/4 = 1/3.

    This is remarkable: while the Vasyunin diagonal G_V(k,k) decays
    like 1/k, the Bernoulli-1 diagonal treats ALL modes equally.
    Every mode k has the same self-energy 1/3 in the Bernoulli-1 world. -/
theorem bernoulli1_diagonal (k : ℕ) (hk : 0 < k) :
    RamanujanBridge.ramanujanEntry k k + 1 / 4 = 1 / 3 := by
  rw [RamanujanBridge.ramanujan_diagonal k hk]
  norm_num

-- ════════════════════════════════════════════════════════════════
-- §2. THE DIAGONAL SHIFT FORMULA
-- ════════════════════════════════════════════════════════════════

/-- **DEFINITION**: The diagonal shift Δ_diag(k) = G_V(k,k) − G^(1)(k,k).

    Δ_diag(k) = (ln(2π) − γ)/k − 1/k² − 1/3 -/
noncomputable def diagShift (k : ℕ) : ℝ :=
  Cathedral.Vasyunin.vasyuninGramEntry k k -
    (RamanujanBridge.ramanujanEntry k k + 1 / 4)

/-- **THEOREM**: The exact diagonal shift formula.

    Δ_diag(k) = (ln(2π) − γ)/k − 1/k² − 1/3

    This is the difference between what the Vasyunin kernel sees
    and what the Bernoulli-1 kernel sees at each diagonal entry. -/
theorem diagShift_formula (k : ℕ) (hk : 0 < k) :
    diagShift k =
    (Real.log (2 * Real.pi) - eulerMascheroniConstant) / ↑k -
    1 / (↑k) ^ 2 - 1 / 3 := by
  unfold diagShift
  rw [Cathedral.Vasyunin.vasyuninGramEntry_diag,
      bernoulli1_diagonal k hk]

-- ════════════════════════════════════════════════════════════════
-- §3. THE VASYUNIN CONSTANT BOUND AND DIAGONAL NEGATIVITY
-- ════════════════════════════════════════════════════════════════

/-- The Vasyunin constant c = ln(2π) − γ satisfies c < 4/3.

    Proof outline:
    1. log(2) < 347/500 (from Mathlib log_two_lt_d9 : log 2 < 0.6931471808)
    2. γ > 447/875 via eulerMascheroniSeq(7) = 363/140 - log(8)
       and log(8) = 3·log(2) < 3·347/500 = 1041/500
       so γ > 363/140 - 1041/500 = 447/875 ≈ 0.5109
    3. log(π) < 23/20 since π < 3.15 < exp(23/20)
       (exp(23/20) > 3.15 by Taylor with 7 terms)
    4. c = log(2) + log(π) - γ < 347/500 + 23/20 - 447/875
         = 2333/1750 < 4/3  (since 2333·3 = 6999 < 7000 = 1750·4)

    Margin: 1/5250 ≈ 0.00019. Razor-thin but rigorous. -/
theorem vasyunin_const_lt_four_thirds :
    Real.log (2 * Real.pi) - eulerMascheroniConstant < 4 / 3 := by
  -- Step 1: Split log(2π) = log(2) + log(π)
  have h2_ne : (2 : ℝ) ≠ 0 := by norm_num
  have hpi_ne : Real.pi ≠ 0 := ne_of_gt Real.pi_pos
  rw [Real.log_mul h2_ne hpi_ne]
  -- Step 2: Upper bound log(2) < 347/500
  have hlog2 : Real.log 2 < 347 / 500 := by
    linarith [Real.log_two_lt_d9]
  have hlogpi : Real.log Real.pi < 23 / 20 := by
    rw [Real.log_lt_iff_lt_exp (by linarith [Real.pi_pos])]
    calc Real.pi < 3.15 := by linarith [Real.pi_lt_d2]
      _ ≤ Real.exp (23 / 20) := by
        refine le_trans ?_ (Real.sum_le_exp_of_nonneg (by norm_num : (0 : ℝ) ≤ 23/20) 7)
        simp_rw [Finset.sum_range_succ, Nat.factorial_succ]
        norm_num
  have hgamma : 447 / 875 < eulerMascheroniConstant := by
    have hseq : eulerMascheroniSeq 7 = 363 / 140 - Real.log 8 := by
      rw [eulerMascheroniSeq]; norm_num
    have hlog8 : Real.log 8 < 1041 / 500 := by
      have : Real.log 8 = 3 * Real.log 2 := by
        rw [show (8 : ℝ) = 2 ^ 3 from by norm_num]
        rw [Real.log_pow]; push_cast; ring
      linarith [Real.log_two_lt_d9]
    calc (447 : ℝ) / 875 = 363 / 140 - 1041 / 500 := by norm_num
      _ < 363 / 140 - Real.log 8 := by linarith
      _ = eulerMascheroniSeq 7 := hseq.symm
      _ < eulerMascheroniConstant :=
          Real.eulerMascheroniSeq_lt_eulerMascheroniConstant 7
  linarith

/-- **THEOREM**: Δ_diag(k) < 0 for all k ≥ 3. -/
theorem diagShift_neg_for_k_ge_3 (k : ℕ) (hk : 3 ≤ k) :
    diagShift k < 0 := by
  rw [diagShift_formula k (by omega)]
  have hc := vasyunin_const_lt_four_thirds
  have hk_pos : (0 : ℝ) < ↑k := Nat.cast_pos.mpr (by omega)
  have hk_real : (3 : ℝ) ≤ ↑k := by exact_mod_cast hk
  -- Rewrite as a single fraction: (3c·k - 3 - k²) / (3k²)
  have heq : (Real.log (2 * Real.pi) - eulerMascheroniConstant) / ↑k -
      1 / (↑k) ^ 2 - 1 / 3 =
      (3 * (Real.log (2 * Real.pi) - eulerMascheroniConstant) * ↑k - 3 -
      (↑k : ℝ) ^ 2) / (3 * (↑k) ^ 2) := by field_simp
  rw [heq]
  apply div_neg_of_neg_of_pos
  · -- Numerator: 3ck - 3 - k² < 0
    -- Since c < 4/3: 3c < 4, so 3ck < 4k
    -- k² - 4k + 3 = (k-1)(k-3) ≥ 0 for k ≥ 3
    nlinarith
  · positivity

/-- **THEOREM**: The diagonal shift is negative for k = 1.
    Δ_diag(1) = c − 4/3 < 0 since c < 4/3.
    Depends on vasyunin_const_lt_four_thirds. -/
theorem diagShift_neg_at_1 :
    diagShift 1 < 0 := by
  rw [diagShift_formula 1 one_pos]
  simp only [Nat.cast_one, div_one, one_pow]
  linarith [vasyunin_const_lt_four_thirds]


/-- **THEOREM**: The Bernoulli-1 diagonal is constant.
    For all k ≥ 1: G^(1)(k,k) = 1/3. -/
theorem bernoulli1_diag_eq_third (k : ℕ) (hk : 0 < k) :
    RamanujanBridge.ramanujanEntry k k + 1 / 4 = 1 / 3 :=
  bernoulli1_diagonal k hk

/-- **THEOREM**: The exact diagonal shift.
    diagShift(k) = (c/k − 1/k²) − 1/3 = G_V(k,k) − 1/3. -/
theorem diagShift_eq (k : ℕ) (hk : 0 < k) :
    diagShift k =
    Cathedral.Vasyunin.vasyuninGramEntry k k - 1 / 3 := by
  unfold diagShift
  rw [bernoulli1_diagonal k hk]

/-- **THEOREM**: The diagonal shift satisfies the upper bound
    Δ_diag(k) ≤ −1/3 + c/k.

    Proof: drop the negative −1/k² term.
    Since −1/k² < 0, we have c/k − 1/k² − 1/3 < c/k − 1/3 = −1/3 + c/k. -/
theorem diagShift_le (k : ℕ) (hk : 0 < k) :
    diagShift k ≤ -1 / 3 + (Real.log (2 * Real.pi) - eulerMascheroniConstant) / ↑k := by
  rw [diagShift_formula k hk]
  have hk_sq_pos : (0 : ℝ) < (↑k) ^ 2 := sq_pos_of_pos (Nat.cast_pos.mpr (by omega))
  linarith [div_pos one_pos hk_sq_pos]

/-- **THEOREM**: The diagonal shift satisfies the lower bound
    Δ_diag(k) ≥ −1/3.

    This is because G_V(k,k) > 0 (proved in DiagonalBound). -/
theorem diagShift_gt_neg_third (k : ℕ) (hk : 1 ≤ k) :
    -1 / 3 < diagShift k := by
  rw [diagShift_formula k (by omega)]
  have := DiagonalBound.gram_diagonal_positive k hk
  linarith

-- ════════════════════════════════════════════════════════════════
-- §4. THE DIAGONAL CORRECTION TO THE QUADRATIC FORM
-- ════════════════════════════════════════════════════════════════

/-- **THEOREM**: The Vasyunin diagonal sum decomposes as
    the Bernoulli-1 diagonal sum minus the shift correction.

    Σ G_V(k,k)·v² = Σ (1/3)·v² + Σ Δ_diag(k)·v²
                   = (1/3)·‖v‖² + Σ Δ_diag(k)·v²

    Since Δ_diag(k) → −1/3, the correction eventually consumes
    the entire Bernoulli-1 diagonal contribution. -/
theorem diagonal_decomposition (N : ℕ) (v : Fin N → ℝ) :
    ∑ i : Fin N, Cathedral.Vasyunin.vasyuninGramEntry (i.val + 1) (i.val + 1) * v i ^ 2 =
    1 / 3 * ∑ i : Fin N, v i ^ 2 +
    ∑ i : Fin N, diagShift (i.val + 1) * v i ^ 2 := by
  rw [Finset.mul_sum]
  rw [← Finset.sum_add_distrib]
  congr 1; ext i
  have hi : 0 < i.val + 1 := by omega
  rw [diagShift_eq (i.val + 1) hi]
  ring

/-- **THEOREM**: The diagonal shift correction is bounded by c · ‖v/k‖².

    Σ Δ_diag(k) · v(k)² ≤ −(1/3)·‖v‖² + c · Σ v(k)²/k

    where c = ln(2π) − γ. This uses the upper bound
    Δ_diag(k) ≤ −1/3 + c/k. -/
theorem shift_correction_bound (N : ℕ) (v : Fin N → ℝ) :
    ∑ i : Fin N, diagShift (i.val + 1) * v i ^ 2 ≤
    -1 / 3 * ∑ i : Fin N, v i ^ 2 +
    (Real.log (2 * Real.pi) - eulerMascheroniConstant) *
      ∑ i : Fin N, v i ^ 2 / ↑(i.val + 1) := by
  rw [Finset.mul_sum, Finset.mul_sum]
  rw [← Finset.sum_add_distrib]
  apply Finset.sum_le_sum
  intro i _
  have hi : 0 < i.val + 1 := by omega
  have hi_pos : (0 : ℝ) < ↑(i.val + 1) := Nat.cast_pos.mpr hi
  have hshift := diagShift_le (i.val + 1) hi
  -- diagShift ≤ −1/3 + c/(i+1), so diagShift · v² ≤ (−1/3 + c/(i+1)) · v²
  have hv2 : 0 ≤ v i ^ 2 := sq_nonneg _
  calc diagShift (↑i + 1) * v i ^ 2
      ≤ (-1 / 3 + (Real.log (2 * Real.pi) - eulerMascheroniConstant) / ↑(i.val + 1)) *
        v i ^ 2 := by
        apply mul_le_mul_of_nonneg_right hshift hv2
    _ = -1 / 3 * v i ^ 2 +
        (Real.log (2 * Real.pi) - eulerMascheroniConstant) * (v i ^ 2 / ↑(i.val + 1)) := by
        rw [add_mul]; congr 1
        rw [div_mul_eq_mul_div]; ring

-- ════════════════════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════════════════════

/-!
## Audit — DiagonalShift

### Sorry: 0 ✅ (formerly 2, now graduated)

### Custom Axioms: 0 ✅

### PROVED (Zero Sorry):
| # | Result | Status |
|---|--------|--------|
| 1 | `bernoulli1_diagonal` | 🎓 **THEOREM** (G^(1)(k,k) = 1/3) |
| 2 | `diagShift` | 📐 **DEFINITION** |
| 3 | `diagShift_formula` | 🎓 **THEOREM** (exact formula) |
| 4 | `bernoulli1_diag_eq_third` | 🎓 **THEOREM** (= 1/3) |
| 5 | `diagShift_eq` | 🎓 **THEOREM** (= G_V(k,k) − 1/3) |
| 6 | `diagShift_le` | 🎓 **THEOREM** (≤ −1/3 + c/k) |
| 7 | `diagShift_gt_neg_third` | 🎓 **THEOREM** (> −1/3) |
| 8 | `diagonal_decomposition` | 🎓 **THEOREM** (form = (1/3)‖v‖² + Σ Δ·v²) |
| 9 | `shift_correction_bound` | 🎓 **THEOREM** (correction ≤ −(1/3)‖v‖² + c·Σv²/k) |
| 10 | `diagShift_neg_at_1` | 🎓 **THEOREM** (uses vasyunin_const_lt_four_thirds) |

### FORMERLY DEFERRED (Now graduated):
| # | Result | Status |
|---|--------|--------|
| 11 | `vasyunin_const_lt_four_thirds` | 🎓 **PROVED** (c < 4/3, margin 1/5250) |
| 12 | `diagShift_neg_for_k_ge_3` | 🎓 **PROVED** (uses c < 4/3 + factoring) |

### Mathematical Summary

The diagonal shift theorem establishes:
- The Bernoulli-1 diagonal is constant 1/3 (PROVED)
- The Vasyunin constant c = ln(2π)−γ < 4/3 (PROVED, margin 1/5250)
- The Vasyunin diagonal decays as c/k − 1/k² (known from Defs.lean)
- The shift satisfies −1/3 < Δ(k) ≤ −1/3 + c/k (PROVED)
- The sign Δ(k) < 0 for all k ≠ 2 (PROVED for k=1 and k≥3)
- The quadratic form decomposes: G_V diagonal = (1/3)‖v‖² + correction (PROVED)
- The correction is bounded: correction ≤ −(1/3)‖v‖² + c·Σ v²/k (PROVED)

Key numerical bounds used:
- γ > 447/875 (from eulerMascheroniSeq(7) and Mathlib log_two_lt_d9)
- log(π) < 23/20 (from π < 3.15 < exp(23/20), Taylor 7 terms)
- log(2) < 347/500 (from Mathlib log_two_lt_d9)
-/

end Cathedral.Physics.DiagonalShift

end
