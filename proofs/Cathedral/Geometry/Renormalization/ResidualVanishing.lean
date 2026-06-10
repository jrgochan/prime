/-
  Cathedral/Geometry/Renormalization/ResidualVanishing.lean

  ## THE RESIDUAL VANISHING — Graduation of wedgeResidual → 0

  ════════════════════════════════════════════════════════════════

  Proves that the wedge residual for consecutive pairs vanishes:

    wedgeResidual(n, n+1) → 0  as  n → ∞

  This graduates the axiom `wedgeResidual_consecutive_vanish` from
  `WedgeResidual.lean`.

  ### Strategy

  Decompose: residual = ratioTerm + ecotTerm, show both → 0.

  **ratioTerm(n,n+1)** = -1/(2n(n+1)) · log(1+1/n)
    Squeeze: |ratioTerm| ≤ log/(2n(n+1)) ≤ log ≤ 1/n → 0.
    Uses: log(1+x) ≤ x (Mathlib: `log_le_sub_one_of_pos`).

  **ecotTerm(n,n+1)** = -π/(2n(n+1)) · (V(n,1) + V(n+1,n))
    Need: |V(a,b)| grows sub-quadratically in a.
    Axiom: |V(a,b)| ≤ a·(log a + 1) (from Jordan + harmonic bound).
    Then |ecot| ≤ 2π·(log(n+1)+1)/n → 0.
    Uses: log(x)/x → 0 (Mathlib: `isLittleO_log_id_atTop`).

  Created: June 9, 2026 (The Graduation — La Bizarre)
-/

import Cathedral.Vasyunin.Defs
import Cathedral.Vasyunin.Cotangent.VasyuninBound
import Cathedral.Vasyunin.Cotangent.VasyuninGrowth
import Cathedral.Geometry.Renormalization.WedgeResidual
import Mathlib.Analysis.SpecialFunctions.Trigonometric.Bounds
import Mathlib.Analysis.SpecialFunctions.Log.Basic
import Mathlib.Analysis.SpecialFunctions.Pow.Asymptotics
import Mathlib.Topology.Algebra.Order.LiminfLimsup

noncomputable section

open Real Finset Filter Asymptotics
open Cathedral.Vasyunin Cathedral.Vasyunin.Bound Cathedral.WedgeResidual

namespace Cathedral.ResidualVanishing

-- ════════════════════════════════════════════════════════════════
-- §1. JORDAN'S INEQUALITY FOR LATTICE POINTS
-- ════════════════════════════════════════════════════════════════

/-- **Jordan's inequality for lattice points**: sin(πm/n) ≥ 2m/n
    for 1 ≤ m ≤ n/2. Follows from the standard bound
    sin(x) ≥ (2/π)x for 0 ≤ x ≤ π/2. -/
lemma sin_lower_jordan (m n : ℕ) (_hm : 1 ≤ m) (hmn : 2 * m ≤ n) :
    (2 * (m : ℝ)) / n ≤ Real.sin (π * m / n) := by
  have hn_pos : (0 : ℝ) < n := by exact_mod_cast (Nat.pos_of_ne_zero (by omega))
  have hm_le : (↑m : ℝ) ≤ ↑n / 2 := by
    have : (2 * ↑m : ℝ) ≤ ↑n := by exact_mod_cast hmn
    linarith
  have hle : π * ↑m / ↑n ≤ π / 2 := by
    calc π * ↑m / ↑n ≤ π * (↑n / 2) / ↑n := by
          apply div_le_div_of_nonneg_right _ hn_pos.le
          exact mul_le_mul_of_nonneg_left hm_le (le_of_lt Real.pi_pos)
        _ = π / 2 := by field_simp
  have hge : 0 ≤ π * ↑m / ↑n := by positivity
  have jordan := Real.mul_le_sin hge hle
  suffices h : 2 * (↑m : ℝ) / ↑n = 2 / π * (π * ↑m / ↑n) by rw [h]; exact jordan
  field_simp

-- ════════════════════════════════════════════════════════════════
-- §2. VASYUNIN SUM GROWTH BOUND
-- ════════════════════════════════════════════════════════════════

/-- **Vasyunin sum growth**: |V(a,b)| ≤ a · (log a + 1).

    GRADUATED ✅ — Fully proved in `VasyuninGrowth.lean`.
    Chain: Jordan → |cot| ≤ a/(2m) → symmetry → involution reindex
         → a · H(a-1) ≤ a · (log a + 1). -/
nonrec def vasyuninSum_growth := Cathedral.VasyuninGrowth.vasyuninSum_growth

-- ════════════════════════════════════════════════════════════════
-- §3. ANALYTIC BUILDING BLOCKS
-- ════════════════════════════════════════════════════════════════

/-- log(1 + 1/n) ≤ 1/n, from the standard inequality log(x) ≤ x - 1. -/
lemma log_inv_le (n : ℕ) (hn : 1 ≤ n) :
    Real.log (1 + 1 / (n : ℝ)) ≤ 1 / n := by
  have h_pos : (0 : ℝ) < 1 + 1 / n := by
    have : (0 : ℝ) < n := by exact_mod_cast (by omega : 0 < n)
    linarith [show (0 : ℝ) ≤ 1/n from by positivity]
  linarith [log_le_sub_one_of_pos h_pos]

/-- gcd(n, n+1) = 1 for all natural n. -/
lemma gcd_consecutive (n : ℕ) : Nat.gcd n (n + 1) = 1 := by
  rw [Nat.gcd_comm]; conv_lhs => rw [Nat.gcd_rec]; simp

/-- **log(x+1)/x → 0** as x → ∞ (ℝ version).
    Squeeze: log(x+1) ≤ log(x²) = 2·log(x) for x ≥ 2,
    so log(x+1)/x ≤ 2·log(x)/x → 0. -/
lemma tendsto_log_succ_div :
    Tendsto (fun x : ℝ => Real.log (x + 1) / x) atTop (nhds 0) := by
  apply squeeze_zero_norm' (a := fun x => 2 * (Real.log x / x))
  · filter_upwards [Filter.Ici_mem_atTop 2] with x (hx : (2 : ℝ) ≤ x)
    rw [Real.norm_eq_abs]
    have hx_pos : (0 : ℝ) < x := by linarith
    rw [abs_of_nonneg (div_nonneg (Real.log_nonneg (by linarith)) hx_pos.le)]
    calc Real.log (x + 1) / x
        ≤ Real.log (x ^ 2) / x := by
          exact div_le_div_of_nonneg_right
            (Real.log_le_log (by linarith) (by nlinarith)) hx_pos.le
      _ = 2 * (Real.log x / x) := by rw [Real.log_pow]; ring
  · rw [show (0 : ℝ) = 2 * 0 from by ring]
    exact isLittleO_log_id_atTop.tendsto_div_nhds_zero.const_mul 2

-- ════════════════════════════════════════════════════════════════
-- §4. COMPONENT LIMITS ✅
-- ════════════════════════════════════════════════════════════════

/-- **ratioTerm(n, n+1) → 0**. ✅
    Squeeze: |ratioTerm| ≤ log((n+1)/n)/(2n(n+1)) ≤ log ≤ 1/n → 0. -/
lemma ratioTerm_tendsto :
    Tendsto (fun n : ℕ => ratioTerm n (n + 1)) atTop (nhds 0) := by
  unfold ratioTerm
  apply squeeze_zero_norm' (a := fun n : ℕ => 1 / (n : ℝ))
  · filter_upwards [Filter.Ici_mem_atTop 1] with n (hn : 1 ≤ n)
    rw [Real.norm_eq_abs]; push_cast
    have hn_pos : (0 : ℝ) < (n : ℝ) := by exact_mod_cast (by omega : 0 < n)
    have hn_r : (1 : ℝ) ≤ (n : ℝ) := by exact_mod_cast hn
    have hn_ne : (n : ℝ) ≠ 0 := ne_of_gt hn_pos
    have hdiv_ge : (1 : ℝ) ≤ ((n : ℝ) + 1) / (n : ℝ) := by rw [le_div_iff₀ hn_pos]; linarith
    have hlog_nn : 0 ≤ Real.log (((n : ℝ) + 1) / (n : ℝ)) := Real.log_nonneg hdiv_ge
    have hlog_le : Real.log (((n : ℝ) + 1) / (n : ℝ)) ≤ 1 / (n : ℝ) := by
      have h1 := log_le_sub_one_of_pos (div_pos (by linarith : (0:ℝ) < (n:ℝ) + 1) hn_pos)
      linarith [show ((n:ℝ) + 1) / (n:ℝ) - 1 = 1 / (n:ℝ) from by rw [add_div, div_self hn_ne, add_sub_cancel_left]]
    rw [show (n : ℝ) - ((n : ℝ) + 1) = -1 from by ring,
        show (-1 : ℝ) / (2 * (n : ℝ) * ((n : ℝ) + 1)) * Real.log (((n : ℝ) + 1) / (n : ℝ)) =
            -(Real.log (((n : ℝ) + 1) / (n : ℝ)) / (2 * (n : ℝ) * ((n : ℝ) + 1))) from by ring,
        abs_neg, abs_of_nonneg (div_nonneg hlog_nn (by positivity))]
    exact le_trans (div_le_self hlog_nn (by nlinarith)) hlog_le
  · simp only [one_div]
    exact tendsto_inv_atTop_zero.comp tendsto_natCast_atTop_atTop

/-- **Ecot term absolute value bound** for consecutive pairs.
    |ecotTerm(n,n+1)| ≤ 2π·(log(n+1)+1)/n for n ≥ 2.

    Uses: gcd(n,n+1) = 1, vasyuninSum_growth, triangle inequality,
    log monotonicity, and the fraction bound (2n+1)/(2(n+1)) ≤ 2. -/
lemma ecotTerm_abs_bound (n : ℕ) (hn : 2 ≤ n) :
    |ecotTerm n (n + 1)| ≤ 2 * π * (Real.log ((n : ℝ) + 1) + 1) / n := by
  unfold ecotTerm; push_cast
  rw [gcd_consecutive, Nat.div_one, Nat.div_one, Nat.cast_one, mul_one]
  have hn_pos : (0 : ℝ) < n := by exact_mod_cast (by omega : 0 < n)
  rw [show -(π : ℝ) / (2 * ↑n * (↑n + 1)) * (vasyuninSum n (n + 1) + vasyuninSum (n + 1) n) =
      -(π / (2 * ↑n * (↑n + 1)) * (vasyuninSum n (n + 1) + vasyuninSum (n + 1) n)) from by ring,
    abs_neg, abs_mul, abs_of_pos (div_pos Real.pi_pos (by positivity))]
  -- Growth bounds from vasyuninSum_growth
  have h_v1 := vasyuninSum_growth n (n+1) hn
  have h_v2 : |vasyuninSum (n+1) n| ≤ ((n : ℝ) + 1) * (Real.log ((n : ℝ) + 1) + 1) := by
    have := vasyuninSum_growth (n+1) n (by omega); push_cast at this; exact this
  -- log monotonicity: log n ≤ log(n+1)
  have hlog_mono := Real.log_le_log hn_pos (show (n : ℝ) ≤ (n : ℝ) + 1 by linarith)
  -- Upgrade v1 bound to use log(n+1)
  have h_v1' : |vasyuninSum n (n+1)| ≤ (n : ℝ) * (Real.log ((n : ℝ) + 1) + 1) :=
    le_trans h_v1 (mul_le_mul_of_nonneg_left (by linarith) hn_pos.le)
  -- Triangle inequality + sum bound
  have h_sum : |vasyuninSum n (n+1) + vasyuninSum (n+1) n| ≤
      (2 * (n : ℝ) + 1) * (Real.log ((n : ℝ) + 1) + 1) := by
    calc |vasyuninSum n (n+1) + vasyuninSum (n+1) n|
        ≤ |vasyuninSum n (n+1)| + |vasyuninSum (n+1) n| := abs_add_le _ _
      _ ≤ (n : ℝ) * (Real.log ((n : ℝ) + 1) + 1) + ((n : ℝ) + 1) * (Real.log ((n : ℝ) + 1) + 1) :=
          add_le_add h_v1' h_v2
      _ = (2 * (n : ℝ) + 1) * (Real.log ((n : ℝ) + 1) + 1) := by ring
  -- Fraction bound: π(2n+1)/(2n(n+1)) ≤ 2π/n
  -- Factor out π·n, reduce to (2n+1) ≤ 4(n+1)
  have h_frac : π * (2 * (↑n : ℝ) + 1) / (2 * ↑n * (↑n + 1)) ≤ 2 * π / ↑n := by
    rw [div_le_div_iff₀ (by positivity : (0 : ℝ) < 2 * ↑n * (↑n + 1)) hn_pos]
    have hpn : 0 < π * (↑n : ℝ) := mul_pos Real.pi_pos hn_pos
    rw [show π * (2 * ↑n + 1) * ↑n = π * ↑n * (2 * ↑n + 1) from by ring,
        show 2 * π * (2 * ↑n * (↑n + 1)) = π * ↑n * (4 * (↑n + 1)) from by ring]
    exact mul_le_mul_of_nonneg_left (by nlinarith) hpn.le
  -- Assemble: π/(2n(n+1)) · |V+V| ≤ 2π(log(n+1)+1)/n
  calc π / (2 * ↑n * (↑n + 1)) * |vasyuninSum n (n + 1) + vasyuninSum (n + 1) n|
      ≤ π / (2 * ↑n * (↑n + 1)) * ((2 * ↑n + 1) * (Real.log (↑n + 1) + 1)) :=
        mul_le_mul_of_nonneg_left h_sum (div_nonneg Real.pi_pos.le (by positivity))
    _ = π * (2 * ↑n + 1) / (2 * ↑n * (↑n + 1)) * (Real.log (↑n + 1) + 1) := by ring
    _ ≤ 2 * π / ↑n * (Real.log (↑n + 1) + 1) :=
        mul_le_mul_of_nonneg_right h_frac (add_nonneg (Real.log_nonneg (by linarith)) zero_le_one)
    _ = 2 * π * (Real.log (↑n + 1) + 1) / ↑n := by ring

/-- **ecotTerm(n, n+1) → 0**. ✅
    Squeeze: |ecotTerm| ≤ 2π·(log(n+1)+1)/n → 0. -/
lemma ecotTerm_tendsto :
    Tendsto (fun n : ℕ => ecotTerm n (n + 1)) atTop (nhds 0) := by
  apply squeeze_zero_norm' (a := fun n : ℕ => 2 * π * (Real.log ((n : ℝ) + 1) + 1) / n)
  · filter_upwards [Filter.Ici_mem_atTop 2] with n hn
    rw [Real.norm_eq_abs]; exact ecotTerm_abs_bound n hn
  · -- 2π·(log(n+1)+1)/n → 0
    have h_log : Tendsto (fun n : ℕ => (Real.log ((n : ℝ) + 1) + 1) / n) atTop (nhds 0) := by
      have h1 : Tendsto (fun n : ℕ => Real.log ((n : ℝ) + 1) / n) atTop (nhds 0) :=
        tendsto_log_succ_div.comp tendsto_natCast_atTop_atTop
      have h2 : Tendsto (fun n : ℕ => 1 / (n : ℝ)) atTop (nhds 0) := by
        simp only [one_div]; exact tendsto_inv_atTop_zero.comp tendsto_natCast_atTop_atTop
      have h3 := h1.add h2; simp only [add_zero] at h3
      exact h3.congr (fun n => by ring)
    have h4 : Tendsto (fun n : ℕ => 2 * π * ((Real.log ((n : ℝ) + 1) + 1) / n)) atTop (nhds 0) := by
      rw [show (0 : ℝ) = 2 * π * 0 from by ring]
      exact h_log.const_mul (2 * π)
    exact h4.congr (fun n => by ring)

-- ════════════════════════════════════════════════════════════════
-- §5. THE GRADUATION ✅
-- ════════════════════════════════════════════════════════════════

/-- **THE RESIDUAL VANISHES**: wedgeResidual(n, n+1) → 0 as n → ∞.

    This is the main result. It decomposes the residual into
    ratioTerm + ecotTerm, each of which tends to 0.

    This graduates `wedgeResidual_consecutive_vanish` from
    `WedgeResidual.lean`. -/
theorem wedgeResidual_consecutive_vanish' :
    Tendsto (fun n => wedgeResidual n (n + 1)) atTop (nhds 0) := by
  show Tendsto (fun n => ratioTerm n (n + 1) + ecotTerm n (n + 1)) atTop (nhds 0)
  rw [show (0 : ℝ) = 0 + 0 from by ring]
  exact ratioTerm_tendsto.add ecotTerm_tendsto

-- ════════════════════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════════════════════

/-!
## Audit — ResidualVanishing.lean (June 9, 2026)

### Theorems Proved: 8
  - `sin_lower_jordan` — sin(πm/n) ≥ 2m/n for m ≤ n/2 ✅
  - `log_inv_le` — log(1+1/n) ≤ 1/n ✅
  - `gcd_consecutive` — gcd(n, n+1) = 1 ✅
  - `tendsto_log_succ_div` — log(x+1)/x → 0 ✅
  - `ratioTerm_tendsto` — ratio piece → 0 ✅
  - `ecotTerm_abs_bound` — |ecot| ≤ 2π(log(n+1)+1)/n ✅
  - `ecotTerm_tendsto` — ecot piece → 0 ✅
  - `wedgeResidual_consecutive_vanish'` — residual → 0 ✅

### Axioms: 0 🎉 (vasyuninSum_growth graduated to VasyuninGrowth.lean)

### Sorry: 0 🎉

### Graduation Chain
  Jordan → cot bound → symmetry → involution reindex
  → Σ|cot| ≤ a·H(a-1) ≤ a·(log a + 1) → |V| sub-quadratic
  → triangle ineq → |ecot| ≤ 2π·(log(n+1)+1)/n → ecot → 0
  → residual = ratio + ecot → 0 + 0 = 0. ∎
-/

end Cathedral.ResidualVanishing

end
