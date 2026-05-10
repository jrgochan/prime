/-
  Cathedral/Vasyunin/Cotangent/GCDReduction.lean

  ## Sub-Axiom 4: General → Coprime Reduction

  Proves `vasyunin_integral_eq_formula` from `telescope_limit_eq_vasyunin`
  by reducing general (j,k) to the coprime case (j/d, k/d).

  ### The Integral Recurrence
  For d = gcd(j,k), j' = j/d, k' = k/d:
    gramIntegral(j,k) = (1/d)·gramIntegral(j',k') + (1/(dj'k'))·(1-1/d)

  ### The Formula Recurrence
    vasyuninGramFormula(j,k) = (1/d)·vasyuninGramFormula(j',k') + (1/(dj'k'))·(1-1/d)

  Both satisfy the same recurrence, so equality in the coprime case
  lifts to equality in the general case.

  Created: April 25, 2026 — The Weekend Assault
  Status: PROVED. 0 sorry, 0 axiom.
-/

import Cathedral.Vasyunin.Cotangent.LogDigammaBridge
import Cathedral.Vasyunin.Cotangent.DigammaReflection
import Cathedral.Vasyunin.Cotangent.IntegralSubstitution
import Mathlib.MeasureTheory.Integral.IntervalIntegral.Basic

noncomputable section
open Real MeasureTheory Finset

namespace Cathedral.Vasyunin.GCDReduction

-- ════════════════════════════════════════════════
-- §1. FORMULA RECURRENCE
-- ════════════════════════════════════════════════

/-- **FORMULA RECURRENCE**: For d = gcd(j,k), j' = j/d, k' = k/d:

    vasyuninGramFormula(j,k)
      = (1/d) · vasyuninGramFormula(j',k') + (1/(d·j'·k')) · (1 - 1/d)

    This is a pure algebraic identity. The formula already
    uses a = j/d and b = k/d internally for the cotangent sums,
    and the remaining terms scale as 1/d with a correction. -/
theorem formula_gcd_recurrence (j k : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k) (_hjk : j ≠ k) :
    let d := Nat.gcd j k
    let j' := j / d
    let k' := k / d
    DigammaReflection.vasyuninGramFormula j k =
    (1 / (d : ℝ)) * DigammaReflection.vasyuninGramFormula j' k' +
    (1 / ((d : ℝ) * (j' : ℝ) * (k' : ℝ))) * (1 - 1 / (d : ℝ)) := by
  -- Both sides expand to the same expression with j = dj', k = dk'
  unfold DigammaReflection.vasyuninGramFormula
  simp only
  -- The GCD of j/d and k/d is 1 (by coprime_after_gcd)
  have hd_pos : 0 < Nat.gcd j k := Nat.gcd_pos_of_pos_left k (by omega)
  have hj' : j / Nat.gcd j k ≥ 1 := by
    exact Nat.div_pos (Nat.le_of_dvd (by omega) (Nat.gcd_dvd_left j k)) hd_pos
  have hk' : k / Nat.gcd j k ≥ 1 := by
    exact Nat.div_pos (Nat.le_of_dvd (by omega) (Nat.gcd_dvd_right j k)) hd_pos
  rw [LogDigammaBridge.gcd_div_eq_one j k hj hk]
  -- Now it's pure algebra: j = d·j', k = d·k'
  have hj_eq : j = Nat.gcd j k * (j / Nat.gcd j k) := by
    rw [Nat.mul_div_cancel' (Nat.gcd_dvd_left j k)]
  have hk_eq : k = Nat.gcd j k * (k / Nat.gcd j k) := by
    rw [Nat.mul_div_cancel' (Nat.gcd_dvd_right j k)]
  set d := Nat.gcd j k
  set jp := j / d
  set kp := k / d
  -- Cast to reals
  have hd_ne : (d : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
  have hjp_ne : (jp : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
  have hkp_ne : (kp : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
  have hj_cast : (j : ℝ) = (d : ℝ) * (jp : ℝ) := by
    push_cast [hj_eq]; ring
  have hk_cast : (k : ℝ) = (d : ℝ) * (kp : ℝ) := by
    push_cast [hk_eq]; ring
  rw [hj_cast, hk_cast]
  -- j'/1 = j' and k'/1 = k' (simplify trivial div by 1)
  simp only [Nat.div_one, Nat.cast_one]
  -- Need to cancel d·d⁻¹ and d*kp/(d*jp) → kp/jp in log args
  -- Use field_simp to clear all fractions, then ring
  -- First handle the log rewriting explicitly
  have key1 : (d:ℝ) * (kp:ℝ) / ((d:ℝ) * (jp:ℝ)) = (kp:ℝ) / (jp:ℝ) := by
    field_simp
  conv_lhs => rw [key1]
  -- Now all log terms match; handle the algebra
  field_simp
  ring

-- ════════════════════════════════════════════════
-- §2. THE COPRIME BRIDGE (WLOG j < k)
-- ════════════════════════════════════════════════

/-- For coprime j, k with j ≠ k:
    gramIntegral j k = vasyuninGramFormula j k.

    Proved by WLOG j < k (using symmetry), then applying
    telescope_limit_eq_vasyunin. -/
theorem integral_eq_formula_coprime (j k : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k)
    (hjk : j ≠ k) (hcop : Nat.Coprime j k) :
    Assembly.gramIntegral j k =
    DigammaReflection.vasyuninGramFormula j k := by
  rcases Nat.lt_or_gt_of_ne hjk with hjk_lt | hjk_gt
  · -- j < k: direct application
    exact LogDigammaBridge.telescope_limit_eq_vasyunin j k hj hk hjk_lt hcop
  · -- j > k: use integral+formula symmetry, then telescope
    have h1 : Assembly.gramIntegral j k = Assembly.gramIntegral k j :=
      Assembly.gramIntegral_comm j k
    rw [h1]
    have h2 : DigammaReflection.vasyuninGramFormula j k =
        DigammaReflection.vasyuninGramFormula k j :=
      Assembly.vasyuninGramFormula_comm j k hj hk
    rw [h2]
    exact LogDigammaBridge.telescope_limit_eq_vasyunin k j hk hj hjk_gt hcop.symm

-- ════════════════════════════════════════════════
-- §3. INTEGRAL GCD RECURRENCE
-- ════════════════════════════════════════════════

/-- **INTEGRAL GCD RECURRENCE** — PROVED from IntegralSubstitution:

    For d = gcd(j,k), j' = j/d, k' = k/d:
    gramIntegral(j,k) = (1/d) · gramIntegral(j',k') + (1/(d·j'·k')) · (1 - 1/d)

    Proof:
    1. Substitute u = dx → gramIntegral(j,k) = (1/d)∫₀ᵈ {1/(j'u)}{1/(k'u)} du
    2. Split at 1:        = (1/d)(∫₀¹ + ∫₁ᵈ)
    3. ∫₀¹ = gramIntegral(j',k') by definition
    4. ∫₁ᵈ = (1/(j'k'))(1-1/d) by tail_integral_value
    5. Distribute: (1/d)·gramIntegral(j',k') + (1/(d·j'·k'))·(1-1/d) -/
theorem integral_gcd_recurrence (j k : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k) (hjk : j ≠ k) :
    let d := Nat.gcd j k
    let j' := j / d
    let k' := k / d
    Assembly.gramIntegral j k =
    (1 / (d : ℝ)) * Assembly.gramIntegral j' k' +
    (1 / ((d : ℝ) * (j' : ℝ) * (k' : ℝ))) * (1 - 1 / (d : ℝ)) := by
  simp only
  set d := Nat.gcd j k with hd_def
  set jp := j / d with hjp_def
  set kp := k / d with hkp_def
  have hd_pos : 0 < d := Nat.gcd_pos_of_pos_left k (by omega)
  have hd_ge2 : 2 ≤ d ∨ d = 1 := by omega
  have hjp_pos : 1 ≤ jp :=
    Nat.div_pos (Nat.le_of_dvd (by omega) (Nat.gcd_dvd_left j k)) hd_pos
  have hkp_pos : 1 ≤ kp :=
    Nat.div_pos (Nat.le_of_dvd (by omega) (Nat.gcd_dvd_right j k)) hd_pos
  have hd_ne : (d:ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
  have hjp_ne : (jp:ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
  have hkp_ne : (kp:ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
  -- Step 1: Apply the substitution u = dx
  rw [IntegralSubstitution.integral_substitution j k hj hk hjk]
  -- Now goal: (1/d) * ∫₀ᵈ f du = (1/d) * gramIntegral jp kp + (1/(d·jp·kp))·(1-1/d)
  -- Step 2 & 3 & 4: Split the integral and evaluate the tail
  rcases hd_ge2 with hd2 | hd1
  · -- Case d ≥ 2: split at 1 and use tail_integral_value
    rw [IntegralSubstitution.split_at_one jp kp d hjp_pos hkp_pos hd2]
    -- Now: (1/d) * (∫₀¹ + ∫₁ᵈ) = (1/d) * gramIntegral jp kp + ...
    -- ∫₀¹ is gramIntegral jp kp by definition
    have h_01 : ∫ u in (0:ℝ)..(1:ℝ),
        Int.fract (1 / ((jp:ℝ) * u)) * Int.fract (1 / ((kp:ℝ) * u)) =
        Assembly.gramIntegral jp kp := by
      rfl
    rw [h_01]
    -- ∫₁ᵈ = (1/(jp·kp))·(1-1/d) by tail_integral_value
    rw [IntegralSubstitution.tail_integral_value jp kp d hjp_pos hkp_pos hd2]
    -- Now: (1/d) * (gramIntegral jp kp + (1/(jp·kp))·(1-1/d))  =  RHS
    ring
  · -- Case d = 1: j and k are coprime, so gcd = 1
    -- After substitution, the integral is over [0,1], which is gramIntegral jp kp
    -- and the RHS correction term vanishes since 1 - 1/1 = 0
    have hd_cast : (d:ℝ) = 1 := by exact_mod_cast hd1
    -- jp = j, kp = k (dividing by 1)
    have h_01 : ∫ u in (0:ℝ)..(1:ℝ),
        Int.fract (1 / ((jp:ℝ) * u)) * Int.fract (1 / ((kp:ℝ) * u)) =
        Assembly.gramIntegral jp kp := by rfl
    -- The integral ∫₀ᵈ with d=1 is ∫₀¹
    have hd1_cast : (d:ℝ) = (1:ℝ) := hd_cast
    rw [hd1_cast, h_01]
    -- 1⁻¹ * gramIntegral jp kp = 1⁻¹ * gramIntegral jp kp + (...)·0
    ring

-- ════════════════════════════════════════════════
-- §4. THE MAIN THEOREM: GENERAL = FORMULA
-- ════════════════════════════════════════════════

/-- **THEOREM**: `gramIntegral j k = vasyuninGramFormula j k` for all j, k ≥ 1 with j ≠ k.

    This REPLACES the axiom `vasyunin_integral_eq_formula` in LogDigammaBridge.

    Proof:
    1. gramIntegral(j,k) = (1/d)·gramIntegral(j',k') + correction  [integral_gcd_recurrence]
    2. gramIntegral(j',k') = vasyuninGramFormula(j',k')             [integral_eq_formula_coprime]
    3. (1/d)·vasyuninGramFormula(j',k') + correction
         = vasyuninGramFormula(j,k)                                 [formula_gcd_recurrence]
-/
theorem integral_eq_formula_general (j k : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k) (hjk : j ≠ k) :
    Assembly.gramIntegral j k = DigammaReflection.vasyuninGramFormula j k := by
  -- Set up GCD decomposition
  set d := Nat.gcd j k with hd_def
  set jp := j / d with hjp_def
  set kp := k / d with hkp_def
  have hd_pos : 0 < d := Nat.gcd_pos_of_pos_left k (by omega)
  have hjp_pos : jp ≥ 1 :=
    Nat.div_pos (Nat.le_of_dvd (by omega) (Nat.gcd_dvd_left j k)) hd_pos
  have hkp_pos : kp ≥ 1 :=
    Nat.div_pos (Nat.le_of_dvd (by omega) (Nat.gcd_dvd_right j k)) hd_pos
  -- j' and k' are coprime
  have hcop : Nat.Coprime jp kp :=
    LogDigammaBridge.coprime_after_gcd j k hj hk
  -- j' ≠ k' (otherwise j = d·j' = d·k' = k, contradicting hjk)
  have hjkp : jp ≠ kp := by
    intro h
    have hj_eq : j = d * jp := by rw [Nat.mul_div_cancel' (Nat.gcd_dvd_left j k)]
    have hk_eq : k = d * kp := by rw [Nat.mul_div_cancel' (Nat.gcd_dvd_right j k)]
    rw [h] at hj_eq
    exact hjk (by omega)
  -- Step 1: Apply the integral recurrence
  rw [integral_gcd_recurrence j k hj hk hjk]
  -- Step 2: Replace gramIntegral(j',k') with vasyuninGramFormula(j',k')
  rw [integral_eq_formula_coprime jp kp hjp_pos hkp_pos hjkp hcop]
  -- Step 3: The formula recurrence (reversed) gives us the result
  exact (formula_gcd_recurrence j k hj hk hjk).symm

end Cathedral.Vasyunin.GCDReduction
