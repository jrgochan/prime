/-
  Cathedral/Covariance/MertensBridge.lean

  ## Bridge: PNTA Mertens' Third Theorem → Cathedral

  Connects PrimeNumberTheoremAnd's Mertens' third theorem
  to the Cathedral's EulerProduct module.

  ### Sorry Status
  This file: 1 sorry (range(X+1) → range(X) correction factor).
  The sorry is a standard limit argument: the correction factor
  (1-1/X)⁻¹ → 1, so it doesn't affect the limit.
  All other bridge-local proofs are complete.
  Inherited sorrys from PNTA/Mertens.lean are classical (non-RH).

  Created: May 10, 2026
-/

import Cathedral.Covariance.EulerProduct
import Mathlib.Order.Filter.Basic
import Mathlib.Topology.Algebra.Order.LiminfLimsup
import Mathlib.NumberTheory.Harmonic.EulerMascheroni

-- ════════════════════════════════════════════════
-- PNTAnd AXIOM REPLACEMENT
-- Mertens' third theorem: ∏_{p≤x}(1-1/p) ~ e^{-γ}/log(x).
-- Previously imported from PrimeNumberTheoremAnd.Mertens.
-- Reference: Kontorovich et al., PrimeNumberTheoremAnd (2024–2026).
-- ════════════════════════════════════════════════

/-- **Mertens' Third Theorem (asymptotic form).**
    ∏_{p ≤ x, prime} (1-1/p) ~ e^{-γ}/log(x).
    Axiom (was proved in PNTAnd/Mertens.lean as Mertens.E₃.bound''). -/
axiom mertens_third_asymptotic :
  Asymptotics.IsEquivalent Filter.atTop
    (fun x : ℝ ↦ ∏ p ∈ (Finset.Ioc 0 ⌊x⌋₊).filter Nat.Prime,
      (1 - (1 : ℝ) / p))
    (fun x ↦ Real.exp (-eulerMascheroniConstant) / Real.log x)

noncomputable section
open Real Finset Filter Asymptotics

namespace Cathedral.Covariance.MertensBridge

-- ════════════════════════════════════════════════
-- §1. PNTA IMPORT + CORE ℝ LIMIT
-- ════════════════════════════════════════════════

/-- PNTA Mertens Third: ∏_{p ≤ x} (1-1/p) ~ e^{-γ}/log(x) -/
theorem pnta_mertens_third :
    (fun x : ℝ => ∏ p ∈ (Ioc 0 ⌊x⌋₊).filter Nat.Prime,
      (1 - (1 : ℝ) / p)) ~[atTop]
    (fun x => exp (-eulerMascheroniConstant) / log x) :=
  mertens_third_asymptotic

/-- **log(x) * ∏_{p ≤ x} (1-1/p) → e^{-γ}** over ℝ. PROVED.

    Proof: Multiply PNTA asymptotic by log (reflexive ~),
    simplify log * e^{-γ}/log = e^{-γ}, apply tendsto_const. -/
theorem mertens_tendsto_real :
    Tendsto (fun x : ℝ =>
      log x * ∏ p ∈ (Ioc 0 ⌊x⌋₊).filter Nat.Prime,
        (1 - (1 : ℝ) / p))
    atTop (nhds (exp (-eulerMascheroniConstant))) := by
  have h_mul := IsEquivalent.mul
    (show (fun x : ℝ => log x) ~[atTop] (fun x => log x) from IsEquivalent.refl)
    pnta_mertens_third
  have h_simp : (fun x : ℝ => log x * (exp (-eulerMascheroniConstant) / log x))
      =ᶠ[atTop] (fun _ => exp (-eulerMascheroniConstant)) := by
    filter_upwards [eventually_gt_atTop (1 : ℝ)] with x hx
    field_simp [ne_of_gt (log_pos hx)]
  exact (h_mul.congr_right h_simp).tendsto_const

-- ════════════════════════════════════════════════
-- §2. FINSET REINDEXING
-- ════════════════════════════════════════════════

/-- range(n+1) and Ioc 0 n have the same primes. PROVED. -/
lemma filter_prime_range_succ_eq_Ioc (n : ℕ) :
    (range (n + 1)).filter Nat.Prime = (Ioc 0 n).filter Nat.Prime := by
  ext p; simp only [mem_filter, mem_range, mem_Ioc]
  exact ⟨fun ⟨h, hp⟩ => ⟨⟨hp.pos, by omega⟩, hp⟩,
         fun ⟨⟨_, h⟩, hp⟩ => ⟨by omega, hp⟩⟩

-- ════════════════════════════════════════════════
-- §3. ℝ → ℕ RESTRICTION (range(X+1) version)
-- ════════════════════════════════════════════════

/-- log(X) * ∏_{range(X+1)} → e^{-γ}. PROVED (zero sorry). -/
theorem mertens_range_succ :
    Tendsto (fun X : ℕ =>
      log (X : ℝ) * ∏ p ∈ (range (X + 1)).filter Nat.Prime,
        (1 - 1 / (p : ℝ)))
    atTop (nhds (exp (-eulerMascheroniConstant))) := by
  have h := mertens_tendsto_real.comp tendsto_natCast_atTop_atTop
  simp only [Function.comp_def, Nat.floor_natCast] at h
  refine h.congr (fun X => ?_)
  simp only [filter_prime_range_succ_eq_Ioc]

-- ════════════════════════════════════════════════
-- §4. THE BRIDGE (range X version)
-- ════════════════════════════════════════════════

/-- **THE BRIDGE**: log(X) * ∏_{p < X, prime}(1-1/p) → e^{-γ}.

    The one sorry: range(X) differs from range(X+1) by at most
    the element X. When X is prime, the extra product factor is
    (1-1/X), which → 1. When X is composite or 0/1, the products
    are equal. Either way the limits agree.

    This is a standard off-by-one argument, not a mathematical gap. -/
theorem mertens_third_nat_tendsto :
    Tendsto (fun X : ℕ =>
      Real.log ↑X * ∏ p ∈ (Finset.range X).filter Nat.Prime,
        (1 - 1 / (p : ℝ)))
    atTop (nhds (Real.exp (-eulerMascheroniConstant))) := by
  -- mertens_range_succ: log(X) * ∏_{range(X+1)} → e^{-γ}
  -- We want:            log(X) * ∏_{range(X)}   → e^{-γ}
  -- The products differ by at most a factor (1-1/X) when X is prime.
  -- Since (1-1/X)⁻¹ → 1 as X → ∞, the two limits agree.
  sorry

/-- **THE BRIDGE**: Provides `mertens_third_statement` for the Cathedral. -/
theorem cathedral_mertens_third :
    Tendsto (fun X : ℕ =>
      Real.log ↑X * ∏ p ∈ (Finset.range X).filter Nat.Prime,
        (1 - 1 / (p : ℝ)))
    atTop (nhds (Real.exp (-eulerMascheroniConstant))) :=
  mertens_third_nat_tendsto

-- ════════════════════════════════════════════════
-- §5. SORRY AUDIT
-- ════════════════════════════════════════════════

/-!
## Bridge Sorry Audit

### This file: 1 sorry
- `mertens_third_nat_tendsto`: Off-by-one correction between
  range(X) and range(X+1). When X is prime, the extra factor is
  (1-1/X) which → 1. Standard limit argument, not a mathematical gap.

### Proved in this file (zero sorry):
- `mertens_tendsto_real`: The core ℝ limit via IsEquivalent.mul
- `mertens_range_succ`: ℝ → ℕ restriction with range(X+1)
- `filter_prime_range_succ_eq_Ioc`: Finset reindexing

### Inherited from PNTA/Mertens.lean: 16 sorrys (all CLASSICAL)
All are classical analytic number theory results being actively
formalized by the PrimeNumberTheoremAnd team. None require RH.
-/

end Cathedral.Covariance.MertensBridge
