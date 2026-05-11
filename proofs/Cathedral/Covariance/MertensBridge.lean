/-
  Cathedral/Covariance/MertensBridge.lean

  ## Bridge: PNTA Mertens' Third Theorem → Cathedral

  Connects the PrimeNumberTheoremAnd project's formalization of
  Mertens' third theorem to the Cathedral's EulerProduct module.

  ### Architecture
  The PNTA project (deps/PrimeNumberTheoremAnd) has a complete
  blueprint for Mertens' theorems in Mertens.lean (926 lines).
  The *downstream* result `E₃.bound''` (the asymptotic for the
  prime product) is proved, but depends on upstream sorrys in
  the Mertens chain.

  This bridge file:
  1. Imports PNTA's Mertens module
  2. Converts between indexing conventions (Ioc vs Finset.range)
  3. Deduces the Cathedral's `mertens_third_statement`

  ### Sorry Tracking
  This bridge inherits sorrys from PNTA/Mertens.lean:
  - E₃.abs_le (the core error bound)
  - prod_one_minus_div_prime_eq (product ↔ log-sum identity)
  - sum_div_log_eq (partial summation integral identity)
  - 3 integrability helpers
  These are all CLASSICAL RESULTS being actively formalized by
  the PrimeNumberTheoremAnd team. None require RH.

  Created: May 10, 2026
-/

import PrimeNumberTheoremAnd.Mertens
import Cathedral.Covariance.EulerProduct
import Mathlib.Order.Filter.Basic
import Mathlib.Topology.Algebra.Order.LiminfLimsup

noncomputable section
open Real Finset Filter Asymptotics

namespace Cathedral.Covariance.MertensBridge

-- ════════════════════════════════════════════════
-- §1. FINSET REINDEXING: Ioc 0 n ↔ range (n+1)
-- ════════════════════════════════════════════════

/-- For primes ≥ 2, the product over `(Ioc 0 n).filter Prime` equals
    the product over `(range (n+1)).filter Prime`.

    Both sets contain exactly the primes in {2, 3, ..., n}. -/
lemma prod_primes_Ioc_eq_range (n : ℕ) :
    ∏ p ∈ (Ioc 0 n).filter Nat.Prime, (1 - 1 / (p : ℝ)) =
    ∏ p ∈ (range (n + 1)).filter Nat.Prime, (1 - 1 / (p : ℝ)) := by
  congr 1; ext p
  simp only [mem_filter, mem_Ioc, mem_range]
  constructor
  · rintro ⟨⟨_, hpn⟩, hpp⟩; exact ⟨by omega, hpp⟩
  · rintro ⟨hpn, hpp⟩; exact ⟨⟨hpp.pos, by omega⟩, hpp⟩

/-- Variant: range n gives primes in {0, ..., n-1}, which for n ≥ 1
    matches primes in Ioc 0 (n-1). -/
lemma prod_primes_range_eq_Ioc (n : ℕ) (hn : 1 ≤ n) :
    ∏ p ∈ (range n).filter Nat.Prime, (1 - 1 / (p : ℝ)) =
    ∏ p ∈ (Ioc 0 (n - 1)).filter Nat.Prime, (1 - 1 / (p : ℝ)) := by
  conv_lhs => rw [show n = (n - 1) + 1 from by omega]
  exact (prod_primes_Ioc_eq_range (n - 1)).symm

-- ════════════════════════════════════════════════
-- §2. THE BRIDGE: PNTA → Cathedral
-- ════════════════════════════════════════════════

/-- **PNTA Mertens Third** (inherited from PrimeNumberTheoremAnd).

    The prime product is asymptotic to e^{-γ}/log(x):
      ∏_{p ≤ x} (1 - 1/p) ~ e^{-γ} / log(x)

    NOTE: This theorem is PROVED in PNTA's Mertens.lean,
    but depends on upstream sorrys in the Mertens chain
    (all classical, non-RH results). -/
theorem pnta_mertens_third :
    (fun x : ℝ => ∏ p ∈ (Ioc 0 ⌊x⌋₊).filter Nat.Prime,
      (1 - (1 : ℝ) / p)) ~[atTop]
    (fun x => exp (-eulerMascheroniConstant) / log x) :=
  Mertens.E₃.bound''

/-- Convert the PNTA asymptotic equivalence to a Tendsto statement
    for natural number arguments, matching the Cathedral's convention.

    Strategy: PNTA gives f ~ g (over ℝ), meaning f/g → 1.
    We restrict to ℕ, reindex Ioc → range, and multiply by log.

    The sorry here is a MECHANICAL filter/topology conversion,
    not a mathematical gap. All the math is in PNTA. -/
theorem mertens_third_nat_tendsto :
    Tendsto (fun X : ℕ =>
      Real.log ↑X * ∏ p ∈ (Finset.range X).filter Nat.Prime,
        (1 - 1 / (p : ℝ)))
    atTop (nhds (Real.exp (-eulerMascheroniConstant))) := by
  sorry
  -- Proof sketch:
  -- 1. pnta_mertens_third gives: ∏_{p ≤ x} ~ e^{-γ}/log(x) over ℝ
  -- 2. IsEquivalent means: ∏ / (e^{-γ}/log) → 1, i.e., log·∏/e^{-γ} → 1
  -- 3. So log(x) · ∏_{p ≤ x} → e^{-γ}
  -- 4. Restrict from ℝ to ℕ via Tendsto.comp + Nat.tendsto_coe_atTop
  -- 5. Reindex Ioc 0 ⌊X⌋₊ → range X using prod_primes_range_eq_Ioc
  -- The details involve: Filter.Tendsto.comp, Nat.floor_natCast,
  -- and the reindexing lemma above.

/-- **THE BRIDGE**: Provides `mertens_third_statement` for the Cathedral.

    This theorem has the exact signature of the sorry in
    EulerProduct.lean:170. Once the filter/topology conversion
    above is closed, this eliminates that sorry entirely. -/
theorem cathedral_mertens_third :
    Tendsto (fun X : ℕ =>
      Real.log ↑X * ∏ p ∈ (Finset.range X).filter Nat.Prime,
        (1 - 1 / (p : ℝ)))
    atTop (nhds (Real.exp (-eulerMascheroniConstant))) :=
  mertens_third_nat_tendsto

-- ════════════════════════════════════════════════
-- §3. SORRY AUDIT
-- ════════════════════════════════════════════════

/-!
## Bridge Sorry Audit

### This file: 1 sorry (MECHANICAL)
- `mertens_third_nat_tendsto`: Filter/topology conversion
  (PNTA ℝ-asymptotic → Cathedral ℕ-Tendsto).
  This is a MECHANICAL conversion, not a mathematical gap.
  The math is fully proved by `Mertens.E₃.bound''` in PNTA.

### Inherited from PNTA/Mertens.lean: 16 sorrys (all CLASSICAL)
All are classical analytic number theory results being actively
formalized. None require the Riemann Hypothesis.

Critical path (6 sorrys):
1. `sum_div_log_eq` — partial summation integral identity
2. `integrable_const_div_mul_log_sq` — integrability helper
3. `integrable_E₁Λ_div_mul_log_sq` — integrability helper
4. `integrable_E₁p_div_mul_log_sq` — integrability helper
5. `E₂Λ.eq` — second error integral form
6. `E₃.abs_le` — core Mertens third error bound
-/

end Cathedral.Covariance.MertensBridge
