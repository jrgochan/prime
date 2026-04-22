/-
  Cathedral/AbelTail/Antiderivative.lean

  ## Antiderivative Engine for Abel Tail Bounds

  Provides the HasDerivAt machinery for the antiderivatives used
  in the integral comparison bounds:
    F₁(t) = -4·t^{-1/4}   →  F₁'(t) = t^{-5/4}
  and the integral evaluation via FTC:
    ∫_a^b t^{-5/4} dt = -4·b^{-1/4} + 4·a^{-1/4}

  These are the "Bypass C" (Theorist directive): computing explicit
  antiderivatives for the power-law tails.
-/

import Cathedral.Defs

noncomputable section
open Real Finset BigOperators MeasureTheory

-- ════════════════════════════════════════════════
-- §1. ANTIDERIVATIVE: F(t) = -4·t^{-1/4}
-- ════════════════════════════════════════════════

/-- **PROVED**: d/dt(-4·t^{-1/4}) = t^{-5/4}.
    From rpow derivative: d/dt(t^p) = p·t^{p-1}.
    With p = -1/4: d/dt(-4·t^{-1/4}) = -4·(-1/4)·t^{-5/4} = t^{-5/4}. -/
theorem hasDerivAt_neg4_rpow (x : ℝ) (hx : 0 < x) :
    HasDerivAt (fun t => -4 * t ^ (-(1:ℝ)/4)) (x ^ (-(5:ℝ)/4)) x := by
  have h1 := Real.hasDerivAt_rpow_const (Or.inl (ne_of_gt hx)) (p := -(1:ℝ)/4)
  convert h1.const_mul (-4) using 1
  have : -(1:ℝ)/4 - 1 = -(5:ℝ)/4 := by ring
  rw [this]; ring

-- ════════════════════════════════════════════════
-- §2. INTEGRAL EVALUATION VIA FTC
-- ════════════════════════════════════════════════

/-- **PROVED**: ∫_a^b t^{-5/4} dt = -4·b^{-1/4} + 4·a^{-1/4}.
    Direct from hasDerivAt_neg4_rpow + FTC. -/
theorem integral_rpow_54 (a b : ℝ) (ha : 0 < a) (hab : a ≤ b) :
    ∫ t in a..b, t ^ (-(5:ℝ)/4) =
    -4 * b ^ (-(1:ℝ)/4) + 4 * a ^ (-(1:ℝ)/4) := by
  have hb : 0 < b := lt_of_lt_of_le ha hab
  have hF : ∀ t ∈ Set.uIcc a b, HasDerivAt (fun t => -4 * t ^ (-(1:ℝ)/4))
      (t ^ (-(5:ℝ)/4)) t := by
    intro t ht
    rw [Set.uIcc_of_le hab] at ht
    exact hasDerivAt_neg4_rpow t (lt_of_lt_of_le ha ht.1)
  have hint : IntervalIntegrable (fun t => t ^ (-(5:ℝ)/4)) MeasureTheory.volume a b := by
    apply ContinuousOn.intervalIntegrable
    apply ContinuousOn.rpow continuousOn_id continuousOn_const
    intro t ht; left; rw [Set.uIcc_of_le hab] at ht; exact ne_of_gt (lt_of_lt_of_le ha ht.1)
  rw [intervalIntegral.integral_eq_sub_of_hasDerivAt hF hint]
  ring

end
