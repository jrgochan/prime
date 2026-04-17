import Cathedral.Defs
import Cathedral.Axioms
import Cathedral.Gram.L2Bridge
import Cathedral.Gram.FractIntegral
import Cathedral.Structural.Independence
import Mathlib.Analysis.InnerProductSpace.Basic
import Mathlib.Analysis.SpecialFunctions.Integrals.Basic

set_option maxHeartbeats 200000

theorem fract_orthogonal_at_zero (k : ℕ) (hk : 1 ≤ k) (ρ : ℂ)
    (hρ_pos : 0 < ρ.re) (hρ_lt : ρ.re < 1) := by
  nlinarith
