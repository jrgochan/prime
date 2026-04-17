import Cathedral.Vasyunin.Cotangent.TelescopeSum
import Mathlib.Analysis.SpecialFunctions.Gamma.Beta
import Mathlib.Analysis.SpecialFunctions.Gamma.Digamma

set_option maxHeartbeats 200000

theorem gauss_digamma_formula (p q : ℕ) (hp : 1 ≤ p) (hpq : p < q)
    (hcop : Nat.Coprime p q) : := by
  intro h; exact h.2
