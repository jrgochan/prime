/-
  Cathedral/PNT/PNTAndBridge.lean

  ## Bridge to PrimeNumberTheoremAnd

  Re-exports PNTAnd's key PNT results under Cathedral-compatible names.
  This file serves as the central import point for PNTAnd theorems used
  across the Cathedral, providing graduated replacements for former axioms.

  ### Graduated Axioms
  - `mu_pnt_alt` — Σ μ(n)/n = o(1) [PNT in Möbius form] → in LogBridge, Bridge
  - `R_isLittleO` — ψ(x) - x = o(x) [PNT in Chebyshev form] → in LogBridge
  - `M_isLittleO` — M(x) = o(x) [Mertens sublinearity] → in LogBridge
  - `mertens_first_mangoldt` — Σ Λ(n)/n ~ log(x) [Mertens 1st, Mangoldt]
  - `mertens_first_prime` — Σ log(p)/p ~ log(x) [Mertens 1st, prime]
  - `mertens_second_ioc` — Σ 1/p - loglog(x) → M [Mertens 2nd]

  ### Status: PROVED (0 sorry, 0 custom axioms)
  Created: May 31, 2026
-/

import PrimeNumberTheoremAnd.Consequences
import PrimeNumberTheoremAnd.Mertens
import PrimeNumberTheoremAnd.RosserSchoenfeldPrime

noncomputable section
open Real Finset Filter ArithmeticFunction Asymptotics

-- ════════════════════════════════════════════════════════════════
-- §1. HELPER LEMMAS
-- ════════════════════════════════════════════════════════════════

/-- For ℕ, `Iic n` and `Ioc 0 n` agree when filtered by `Nat.Prime`,
    since 0 is not prime. -/
lemma iic_eq_ioc_filter_prime (n : ℕ) :
    (Finset.Iic n).filter Nat.Prime = (Finset.Ioc 0 n).filter Nat.Prime := by
  ext p; simp only [mem_filter, mem_Iic, mem_Ioc]
  exact ⟨fun ⟨h1, h2⟩ => ⟨⟨h2.pos, h1⟩, h2⟩, fun ⟨⟨_, h2⟩, h3⟩ => ⟨h2, h3⟩⟩

/-- A constant function is o(log) since log → ∞. -/
private lemma one_isLittleO_log : IsLittleO atTop (fun (_ : ℝ) => (1 : ℝ)) (fun x => Real.log x) := by
  rw [isLittleO_iff]
  intro c hc
  filter_upwards [eventually_ge_atTop (Real.exp c⁻¹)] with x hx
  simp only [norm_one, norm_eq_abs]
  have hx_ge_1 : 1 ≤ x := le_trans (one_le_exp (inv_nonneg.mpr hc.le)) hx
  rw [abs_of_nonneg (Real.log_nonneg hx_ge_1)]
  rw [show (1 : ℝ) = c * c⁻¹ from (mul_inv_cancel₀ hc.ne').symm]
  exact mul_le_mul_of_nonneg_left
    (Real.log_exp c⁻¹ ▸ Real.log_le_log (exp_pos _) hx) hc.le

-- ════════════════════════════════════════════════════════════════
-- §2. MERTENS' FIRST THEOREM (von Mangoldt form) — GRADUATED 🎓
-- ════════════════════════════════════════════════════════════════

/-- **GRADUATED 🎓 (was axiom `mertens_first_mangoldt`):**
    Mertens' first theorem (von Mangoldt form).

    `Σ_{n ≤ x} Λ(n)/n ~ log(x)`

    **Proof**: From PNTAnd's `Mertens.E₁Λ.le/ge` which give
    `-2 ≤ E₁Λ(x) ≤ log(4) + 4` for `x ≥ 1`, and
    `Mertens.sum_mangoldt_div_eq` which gives `Σ Λ(d)/d = logx + E₁Λ(x)`.
    Since E₁Λ is bounded, it's O(1) = o(logx), giving IsEquivalent.

    References: `Mertens.E₁Λ.le`, `Mertens.E₁Λ.ge`, `Mertens.sum_mangoldt_div_eq`
    All three are sorry-free in PNTAnd v4.29.
    GRADUATED: May 31, 2026. -/
theorem mertens_first_mangoldt_proved :
    Asymptotics.IsEquivalent Filter.atTop
      (fun x : ℝ => ∑ d ∈ (Finset.Ioc 0 ⌊x⌋₊),
        ArithmeticFunction.vonMangoldt d / d)
      (fun x => Real.log x) := by
  rw [Asymptotics.IsEquivalent]
  -- E₁Λ is bounded: -2 ≤ E₁Λ ≤ log4+4
  have h_bdd : IsBigO atTop (fun x : ℝ =>
    (∑ d ∈ Ioc 0 ⌊x⌋₊, vonMangoldt d / ↑d) - Real.log x) (fun _ => (1 : ℝ)) := by
    rw [isBigO_iff]
    refine ⟨max 2 (Real.log 4 + 4), ?_⟩
    filter_upwards [eventually_ge_atTop (1 : ℝ)] with x hx
    simp only [norm_one, mul_one, norm_eq_abs]
    have h_eq : (∑ d ∈ Ioc 0 ⌊x⌋₊, vonMangoldt d / ↑d) - Real.log x = Mertens.E₁Λ x := by
      linarith [Mertens.sum_mangoldt_div_eq x]
    rw [h_eq, abs_le]
    exact ⟨by linarith [Mertens.E₁Λ.ge hx, le_max_left 2 (Real.log 4 + 4)],
           by linarith [Mertens.E₁Λ.le hx, le_max_right 2 (Real.log 4 + 4)]⟩
  exact h_bdd.trans_isLittleO one_isLittleO_log

-- ════════════════════════════════════════════════════════════════
-- §3. MERTENS' FIRST THEOREM (prime form) — GRADUATED 🎓
-- ════════════════════════════════════════════════════════════════

/-- **GRADUATED 🎓 (was axiom `mertens_first_prime`):**
    Mertens' first theorem (prime form).

    `Σ_{p ≤ x, prime} log(p)/p ~ log(x)`

    **Proof**: From PNTAnd's `RS_prime.mertens_first_theorem` which gives
    `Tendsto (Σ logp/p - logx) → mertensConstant`. Since the difference
    converges to a constant, it is O(1) = o(logx), giving IsEquivalent.

    References: `RS_prime.mertens_first_theorem` (sorry-free in PNTAnd v4.29)
    GRADUATED: May 31, 2026. -/
theorem mertens_first_prime_proved :
    Asymptotics.IsEquivalent Filter.atTop
      (fun x : ℝ => ∑ p ∈ (Finset.Ioc 0 ⌊x⌋₊).filter Nat.Prime,
        Real.log p / p)
      (fun x => Real.log x) := by
  rw [Asymptotics.IsEquivalent]
  have h_tends' : Tendsto (fun x : ℝ =>
      ∑ p ∈ (Finset.Ioc 0 ⌊x⌋₊).filter Nat.Prime, Real.log ↑p / ↑p - Real.log x)
      atTop (nhds mertensConstant) :=
    RS_prime.mertens_first_theorem.congr (fun x => by rw [iic_eq_ioc_filter_prime])
  exact (h_tends'.isBigO_one ℝ).trans_isLittleO one_isLittleO_log

-- ════════════════════════════════════════════════════════════════
-- §4. MERTENS' SECOND THEOREM — GRADUATED 🎓
-- ════════════════════════════════════════════════════════════════

/-- **GRADUATED 🎓 (was axiom `mertens_second_ioc`):**
    Mertens' second theorem (prime form, convergence).

    `∃ M, Tendsto (Σ_{p ≤ x} 1/p - log(log(x))) → M`

    The limit M = meisselMertensConstant ≈ 0.2615.

    **Proof**: Direct from PNTAnd's `RS_prime.mertens_second_theorem`,
    converting `Iic` to `Ioc 0` using `iic_eq_ioc_filter_prime`.

    References: `RS_prime.mertens_second_theorem` (sorry-free in PNTAnd v4.29)
    GRADUATED: May 31, 2026. -/
theorem mertens_second_ioc_proved :
    ∃ M : ℝ,
    Tendsto (fun x : ℝ =>
      (∑ p ∈ (Finset.Ioc 0 ⌊x⌋₊).filter Nat.Prime, 1 / (p : ℝ)) -
      Real.log (Real.log x))
      atTop (nhds M) :=
  ⟨meisselMertensConstant,
    RS_prime.mertens_second_theorem.congr (fun x => by rw [iic_eq_ioc_filter_prime])⟩

-- ════════════════════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════════════════════

/-!
## Audit — PNTAndBridge.lean (May 31, 2026)

### 🏆 ZERO SORRY — ALL THEOREMS PROVED

### Graduated from PNTAnd v4.29:
| # | Result | PNTAnd Source | Status |
|---|--------|---------------|--------|
| 1 | `mertens_first_mangoldt_proved` | `Mertens.E₁Λ.le/ge` | 🎓 sorry-free |
| 2 | `mertens_first_prime_proved` | `RS_prime.mertens_first_theorem` | 🎓 sorry-free |
| 3 | `mertens_second_ioc_proved` | `RS_prime.mertens_second_theorem` | 🎓 sorry-free |
| 4 | `iic_eq_ioc_filter_prime` | helper | 🎓 proved |
| 5 | `one_isLittleO_log` | helper | 🎓 proved |
-/

end
