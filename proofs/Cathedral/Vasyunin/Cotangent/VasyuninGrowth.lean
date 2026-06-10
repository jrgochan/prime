/-
  Cathedral/Vasyunin/Cotangent/VasyuninGrowth.lean

  ## THE VASYUNIN GROWTH BOUND — |V(a,b)| ≤ a·(log a + 1)

  ════════════════════════════════════════════════════════════════

  Proves that the Vasyunin cotangent sum grows sub-quadratically:

    |V(a,b)| ≤ a · (log a + 1)

  This graduates the axiom `vasyuninSum_growth` from
  `ResidualVanishing.lean`, completing the Residual Vanishing proof chain.

  ### Strategy

  Chain: VasyuninBound → Jordan → cotangent bound → symmetry
       → involution reindex → harmonic bound → growth

  1. `vasyuninSum_abs_le`: |V(a,b)| ≤ Σ |cot(πm/a)|  (from VasyuninBound)
  2. `cot_bound_jordan`: |cot(πm/a)| ≤ a/(2m) for m ≤ a/2 (Jordan)
  3. `cot_pi_sub`: cot(π-x) = -cot(x) (symmetry, pairs m with a-m)
  4. Pointwise: |cot(πm/a)| ≤ a/(2m) + a/(2(a-m)) for all m
  5. Sum → split → factor → reindex via m ↦ a-m involution
  6. `harmonic_le_log_add_one`: Σ 1/m ≤ log(n) + 1 (by induction)
  7. Assembly: Σ|cot| ≤ a·H(a-1) ≤ a·(log a + 1)

  ### Zero axioms. Zero sorries. 🎉

  Created: June 9, 2026 (The Mountain — Brahms Op. 18)
-/

import Cathedral.Vasyunin.Defs
import Cathedral.Vasyunin.Cotangent.VasyuninBound
import Mathlib.Analysis.SpecialFunctions.Trigonometric.Bounds
import Mathlib.Analysis.SpecialFunctions.Log.Basic
import Mathlib.Tactic

noncomputable section

open Real Finset Filter Cathedral.Vasyunin Cathedral.Vasyunin.Bound

namespace Cathedral.VasyuninGrowth

-- ════════════════════════════════════════════════════════════════
-- §1. COTANGENT BOUND FROM JORDAN'S INEQUALITY
-- ════════════════════════════════════════════════════════════════

/-- Jordan's inequality: sin(πm/n) ≥ 2m/n for 1 ≤ m ≤ n/2 -/
private lemma sin_lower (m n : ℕ) (_hm : 1 ≤ m) (hmn : 2 * m ≤ n) :
    (2 * (m : ℝ)) / n ≤ Real.sin (π * m / n) := by
  have hn_pos : (0 : ℝ) < n := by exact_mod_cast (Nat.pos_of_ne_zero (by omega))
  have hm_le : (↑m : ℝ) ≤ ↑n / 2 := by
    linarith [show (2 * ↑m : ℝ) ≤ ↑n from by exact_mod_cast hmn]
  suffices 2 * (↑m : ℝ) / ↑n = 2 / π * (π * ↑m / ↑n) by
    rw [this]; exact Real.mul_le_sin (by positivity) (by
      calc π * ↑m / ↑n ≤ π * (↑n / 2) / ↑n :=
            div_le_div_of_nonneg_right
              (mul_le_mul_of_nonneg_left hm_le Real.pi_pos.le) hn_pos.le
          _ = π / 2 := by field_simp)
  field_simp

/-- **Cotangent bound**: |cot(πm/a)| ≤ a/(2m) for 1 ≤ m, 2m ≤ a.

    Proof: Jordan gives sin(πm/a) ≥ 2m/a, and |cos| ≤ 1,
    so |cot| = |cos|/sin ≤ 1/sin ≤ 1/(2m/a) = a/(2m). -/
theorem cot_bound_jordan (m a : ℕ) (hm : 1 ≤ m) (hma : 2 * m ≤ a) :
    |Cathedral.Vasyunin.cot (π * m / a)| ≤ (a : ℝ) / (2 * m) := by
  have ha_pos : (0 : ℝ) < a := by exact_mod_cast (by omega : 0 < a)
  have h_sin := sin_lower m a hm hma
  have h_sin_pos : 0 < Real.sin (π * ↑m / ↑a) :=
    lt_of_lt_of_le (div_pos (by positivity) ha_pos) h_sin
  unfold Cathedral.Vasyunin.cot; rw [abs_div, abs_of_pos h_sin_pos]
  calc |Real.cos (π * ↑m / ↑a)| / Real.sin (π * ↑m / ↑a)
      ≤ 1 / Real.sin (π * ↑m / ↑a) :=
        div_le_div_of_nonneg_right (abs_cos_le_one _) h_sin_pos.le
    _ ≤ 1 / (2 * ↑m / ↑a) :=
        div_le_div_of_nonneg_left one_pos.le
          (div_pos (by positivity) ha_pos) h_sin
    _ = ↑a / (2 * ↑m) := by field_simp

-- ════════════════════════════════════════════════════════════════
-- §2. COTANGENT SYMMETRY
-- ════════════════════════════════════════════════════════════════

/-- **Cotangent π-symmetry**: cot(π - x) = -cot(x).
    This pairs term m with term a-m in the Vasyunin sum. -/
theorem cot_pi_sub (x : ℝ) :
    Cathedral.Vasyunin.cot (π - x) = -Cathedral.Vasyunin.cot x := by
  unfold Cathedral.Vasyunin.cot
  rw [Real.cos_pi_sub, Real.sin_pi_sub]
  ring

-- ════════════════════════════════════════════════════════════════
-- §3. HARMONIC SUM BOUND
-- ════════════════════════════════════════════════════════════════

/-- **Log lower bound**: 1/(n+1) ≤ log((n+1)/n) for n ≥ 1.
    From log(x) ≤ x-1 applied to 1/((n+1)/n) = n/(n+1). -/
private lemma inv_le_log_diff (n : ℕ) (hn : 1 ≤ n) :
    1 / ((n : ℝ) + 1) ≤ Real.log ((n : ℝ) + 1) - Real.log n := by
  have hn_pos : (0 : ℝ) < n := by exact_mod_cast (by omega : 0 < n)
  rw [← Real.log_div (by linarith) (ne_of_gt hn_pos)]
  have h := Real.log_le_sub_one_of_pos
    (div_pos one_pos (by positivity : 0 < ((n : ℝ) + 1) / (n : ℝ)))
  rw [Real.log_div one_ne_zero
    (ne_of_gt (by positivity : 0 < ((n : ℝ) + 1) / (n : ℝ))), Real.log_one] at h
  linarith [
    show 1 / (((n : ℝ) + 1) / (n : ℝ)) = (n : ℝ) / ((n : ℝ) + 1) from by
      rw [one_div, inv_div],
    show (n : ℝ) / ((n : ℝ) + 1) + 1 / ((n : ℝ) + 1) = 1 from by field_simp]

/-- **Harmonic sum bound**: Σ_{m=1}^{n} 1/m ≤ log(n) + 1 for n ≥ 1.

    Proof by induction using 1/(k+1) ≤ log(k+1) - log(k). -/
theorem harmonic_le_log_add_one : ∀ (n : ℕ), 1 ≤ n →
    ∑ m ∈ Ico 1 (n + 1), (1 : ℝ) / m ≤ Real.log n + 1 := by
  intro n hn
  induction n with
  | zero => omega
  | succ k ih =>
    by_cases hk : k = 0
    · subst hk
      rw [show Ico 1 (0 + 1 + 1) = ({1} : Finset ℕ) from by
        ext x; simp only [Finset.mem_Ico, Finset.mem_singleton]; omega]
      simp [Finset.sum_singleton]
    · have hk1 : 1 ≤ k := by omega
      have hsplit : Ico 1 (k + 2) = Ico 1 (k + 1) ∪ {k + 1} := by
        ext x
        simp only [Finset.mem_union, Finset.mem_Ico, Finset.mem_singleton]
        omega
      have hdisj : Disjoint (Ico 1 (k + 1)) ({k + 1} : Finset ℕ) := by
        simp only [Finset.disjoint_singleton_right, Finset.mem_Ico,
          not_and, not_lt]; omega
      rw [hsplit, Finset.sum_union hdisj, Finset.sum_singleton]
      push_cast; linarith [ih hk1, inv_le_log_diff k hk1]

/-- Harmonic sum on Ico 1 a: Σ_{m=1}^{a-1} 1/m ≤ log(a) + 1.
    Uses harmonic_le_log_add_one + log monotonicity. -/
private lemma harmonic_ico (a : ℕ) (ha : 2 ≤ a) :
    ∑ m ∈ Ico 1 a, (1 : ℝ) / ↑m ≤ Real.log ↑a + 1 := by
  have h1 : ∑ m ∈ Ico 1 a, (1 : ℝ) / ↑m ≤ Real.log ((a - 1 : ℕ) : ℝ) + 1 := by
    rw [show a = (a - 1) + 1 from by omega]
    exact harmonic_le_log_add_one (a - 1) (by omega)
  linarith [Real.log_le_log
    (by exact_mod_cast (show 0 < a - 1 by omega) : (0 : ℝ) < ((a - 1 : ℕ) : ℝ))
    (by exact_mod_cast (show a - 1 ≤ a by omega) : ((a - 1 : ℕ) : ℝ) ≤ ((a : ℕ) : ℝ))]

-- ════════════════════════════════════════════════════════════════
-- §4. INVOLUTION REINDEX
-- ════════════════════════════════════════════════════════════════

/-- **Involution reindex**: Σ 1/(a-m) = Σ 1/m over Ico 1 a.

    The map m ↦ a-m is an involution on Ico 1 a.
    This is the key Finset manipulation that pairs each m with a-m. -/
private lemma sum_inv_sub (a : ℕ) :
    ∑ m ∈ Ico 1 a, (1 : ℝ) / (↑a - ↑m) =
    ∑ m ∈ Ico 1 a, (1 : ℝ) / ↑m := by
  apply Finset.sum_nbij' (fun m => a - m) (fun m => a - m)
  · intro m hm; obtain ⟨_, h⟩ := Finset.mem_Ico.mp hm
    exact Finset.mem_Ico.mpr ⟨by omega, by omega⟩
  · intro m hm; obtain ⟨_, h⟩ := Finset.mem_Ico.mp hm
    exact Finset.mem_Ico.mpr ⟨by omega, by omega⟩
  · intro m hm; obtain ⟨_, h⟩ := Finset.mem_Ico.mp hm; omega
  · intro m hm; obtain ⟨_, h⟩ := Finset.mem_Ico.mp hm; omega
  · intro m hm; obtain ⟨_, h⟩ := Finset.mem_Ico.mp hm
    simp only [Nat.cast_sub (le_of_lt h)]

-- ════════════════════════════════════════════════════════════════
-- §5. COTANGENT SUM BOUND — THE ASSEMBLY ✅
-- ════════════════════════════════════════════════════════════════

/-- **Cotangent sum bound**: Σ_{m=1}^{a-1} |cot(πm/a)| ≤ a·(log a + 1).

    Proof strategy:
    1. For each m: |cot(πm/a)| ≤ a/(2m) + a/(2(a-m))
       (Jordan on whichever half m falls in, other term is non-negative)
    2. Split the sum: Σ = Σ a/(2m) + Σ a/(2(a-m))
    3. Factor: = a/2 · Σ 1/m + a/2 · Σ 1/(a-m)
    4. Reindex via involution m ↦ a-m: Σ 1/(a-m) = Σ 1/m
    5. Combine: = a · Σ 1/m = a · H(a-1) ≤ a · (log a + 1) -/
theorem cotSum_le_a_log_a (a : ℕ) (ha : 2 ≤ a) :
    ∑ m ∈ Ico 1 a, |Cathedral.Vasyunin.cot (π * m / a)| ≤
    (a : ℝ) * (Real.log a + 1) := by
  have ha_pos : (0 : ℝ) < a := by exact_mod_cast (by omega : 0 < a)
  -- Main calc chain
  calc ∑ m ∈ Ico 1 a, |Cathedral.Vasyunin.cot (π * ↑m / ↑a)|
      -- Step 1: pointwise bound
      ≤ ∑ m ∈ Ico 1 a, (↑a / (2 * ↑m) + ↑a / (2 * (↑a - ↑m))) := by
        apply Finset.sum_le_sum
        intro m hm; obtain ⟨h1, h2⟩ := Finset.mem_Ico.mp hm
        have : (0 : ℝ) < ↑a - ↑m := by
          linarith [show (m : ℝ) < a from by exact_mod_cast h2]
        by_cases h : 2 * m ≤ a
        · -- First half: |cot| ≤ a/(2m)
          exact le_trans (cot_bound_jordan m a h1 h) (le_add_of_nonneg_right (by positivity))
        · -- Second half: |cot(πm/a)| = |cot(π(a-m)/a)| ≤ a/(2(a-m))
          rw [show π * (↑m : ℝ) / ↑a = π - π * ↑(a - m) / ↑a from by
            rw [Nat.cast_sub (le_of_lt h2)]; field_simp; ring]
          rw [cot_pi_sub, abs_neg,
              show (↑a : ℝ) / (2 * (↑a - ↑m)) = ↑a / (2 * ↑(a - m)) from by
                rw [Nat.cast_sub (le_of_lt h2)]]
          exact le_trans (cot_bound_jordan (a - m) a (by omega) (by omega))
            (le_add_of_nonneg_left (by positivity))
    -- Step 2: split into two sums
    _ = ∑ m ∈ Ico 1 a, ↑a / (2 * ↑m) + ∑ m ∈ Ico 1 a, ↑a / (2 * (↑a - ↑m)) :=
        Finset.sum_add_distrib
    -- Step 3: factor out a/2
    _ = ↑a / 2 * ∑ m ∈ Ico 1 a, (1 / ↑m) +
        ↑a / 2 * ∑ m ∈ Ico 1 a, (1 / (↑a - ↑m)) := by
        congr 1 <;> (rw [Finset.mul_sum]; congr 1; ext m; field_simp)
    -- Step 4: reindex via involution m ↦ a-m
    _ = ↑a / 2 * ∑ m ∈ Ico 1 a, (1 / ↑m) +
        ↑a / 2 * ∑ m ∈ Ico 1 a, (1 / ↑m) := by
        rw [sum_inv_sub a]
    -- Step 5: combine
    _ = ↑a * ∑ m ∈ Ico 1 a, (1 / ↑m) := by ring
    -- Step 6: harmonic bound
    _ ≤ ↑a * (Real.log ↑a + 1) :=
        mul_le_mul_of_nonneg_left (harmonic_ico a ha) ha_pos.le

-- ════════════════════════════════════════════════════════════════
-- §6. THE GRADUATION ✅
-- ════════════════════════════════════════════════════════════════

/-- **THE VASYUNIN GROWTH BOUND**: |V(a,b)| ≤ a · (log a + 1).

    This graduates `vasyuninSum_growth` from `ResidualVanishing.lean`.
    Chain: |V| ≤ Σ|cot| (VasyuninBound) ≤ a·(log a + 1) (cotSum). -/
theorem vasyuninSum_growth (a b : ℕ) (ha : 2 ≤ a) :
    |vasyuninSum a b| ≤ a * (Real.log a + 1) :=
  le_trans (vasyuninSum_abs_le a b ha) (cotSum_le_a_log_a a ha)

-- ════════════════════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════════════════════

/-!
## Audit — VasyuninGrowth.lean (June 9, 2026)

### Theorems Proved: 7
  - `cot_bound_jordan` — |cot(πm/a)| ≤ a/(2m) for m ≤ a/2 ✅
  - `cot_pi_sub` — cot(π-x) = -cot(x) ✅
  - `harmonic_le_log_add_one` — Σ 1/m ≤ log(n) + 1 ✅
  - `cotSum_le_a_log_a` — Σ|cot(πm/a)| ≤ a·(log a + 1) ✅
  - `vasyuninSum_growth` — |V(a,b)| ≤ a·(log a + 1) ✅
  - (plus private: sin_lower, inv_le_log_diff, harmonic_ico, sum_inv_sub)

### Axioms: 0 🎉
### Sorry: 0 🎉

### Graduation Chain
  Jordan → |cot| ≤ a/(2m) → cot(π-x) = -cot(x)
  → pointwise: |cot(πm/a)| ≤ a/(2m) + a/(2(a-m))
  → Σ|cot| ≤ Σ a/(2m) + Σ a/(2(a-m))
  → factor out a/2, reindex via m ↦ a-m involution
  → a · H(a-1) ≤ a · (log a + 1)
  → |V| ≤ Σ|cot| ≤ a · (log a + 1) ∎
-/

end Cathedral.VasyuninGrowth

end
