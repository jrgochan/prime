/-
  Cathedral/Vasyunin/Cotangent/VasyuninReflectionWiring.lean

  ## The Complete Reflection: V(a, a−b) = −V(a, b)

  This file WIRES the algebraic core (from VasyuninReflection.lean) to
  the actual vasyuninSum definition (from Defs.lean), producing:

    vasyuninSum a (a - b) = -vasyuninSum a b

  for coprime a ≥ 2 and 1 ≤ b < a.

  The proof uses:
  1. cot_sum_vanishes (from CotSymmetry): Σ cot(πm/a) = 0
  2. The fractional part identity: {m(a−b)/a} = 1 − {mb/a}
     (axiom: fract_reflection_coprime)
  3. Sum algebra: Σ(1−f)g = Σg − Σfg = 0 − Σfg = −Σfg

  Created: May 20, 2026 (The Thulium Session — Wiring Phase)
-/

import Cathedral.Vasyunin.Defs
import Cathedral.Vasyunin.Cotangent.CotSymmetry
import Cathedral.Vasyunin.Cotangent.FractReflection
import Mathlib.Algebra.Order.Floor.Ring
import Mathlib.Data.Nat.GCD.Basic

noncomputable section
open Finset

namespace Cathedral.Vasyunin.ReflectionWiring

-- ════════════════════════════════════════════════
-- PART I: THE FRACTIONAL PART IDENTITY (AXIOM)
-- ════════════════════════════════════════════════

/-- Fractional part reflection — GRADUATED from axiom to theorem.
    See FractReflection.lean for the full proof.
    {m(a−b)/a} = 1 − {mb/a} for coprime a,b. -/
def fract_reflection_coprime := Cathedral.Vasyunin.FractReflection.fract_reflection_coprime

-- ════════════════════════════════════════════════
-- PART II: THE COMPLETE REFLECTION THEOREM
-- ════════════════════════════════════════════════

/-- **THE REFLECTION THEOREM**: V(a, a−b) = −V(a, b).

    For a ≥ 2, 1 ≤ b < a, with gcd(a,b) = 1:

      vasyuninSum a (a - b) = -(vasyuninSum a b)

    Proof:
    1. Rewrite each fract: {m(a−b)/a} = 1 − {mb/a}   (by fract_reflection_coprime)
    2. Expand: Σ (1 − {mb/a})·cot(πm/a) = Σ cot(πm/a) − Σ {mb/a}·cot(πm/a)
    3. Kill: Σ cot(πm/a) = 0                          (by cot_sum_vanishes)
    4. Done: = 0 − V(a,b) = −V(a,b)                   ∎

    Axiom count: 1 (fract_reflection_coprime).
    This can be graduated via Int.fract_neg and coprimality arithmetic. -/
theorem vasyuninSum_reflection (a b : ℕ) (ha : 2 ≤ a) (hb : b < a)
    (hcop : Nat.Coprime a b) :
    vasyuninSum a (a - b) = -(vasyuninSum a b) := by
  -- Unfold vasyuninSum
  unfold vasyuninSum
  simp only [show ¬(a ≤ 1) from by omega, ↓reduceIte]
  -- Step 1: Apply the fractional part reflection to each summand
  have hfract : ∀ m ∈ Ico 1 a,
      Int.fract ((m * (a - b) : ℕ) / (a : ℝ)) =
      1 - Int.fract ((m * b : ℕ) / (a : ℝ)) :=
    fun m hm => fract_reflection_coprime a b m ha hm hcop hb
  -- Step 2: Rewrite the LHS sum using fract reflection
  have step2 : ∑ m ∈ Ico 1 a,
      Int.fract ((m * (a - b) : ℕ) / (a : ℝ)) * cot (Real.pi * m / a) =
    ∑ m ∈ Ico 1 a,
      (1 - Int.fract ((m * b : ℕ) / (a : ℝ))) * cot (Real.pi * m / a) :=
    Finset.sum_congr rfl (fun m hm => by rw [hfract m hm])
  rw [step2]
  -- Step 3: Expand (1 - f) * g = g - f * g
  simp_rw [sub_mul, one_mul, Finset.sum_sub_distrib]
  -- Goal: Σ cot(πm/a) - Σ {mb/a}·cot(πm/a) = -(Σ {mb/a}·cot(πm/a))
  -- Step 4: Kill the first sum using cot_sum_vanishes
  have hcot : ∑ m ∈ Ico 1 a, cot (Real.pi * ↑m / ↑a) = 0 :=
    Cathedral.Vasyunin.cot_sum_vanishes a ha
  rw [hcot, zero_sub]

end Cathedral.Vasyunin.ReflectionWiring
