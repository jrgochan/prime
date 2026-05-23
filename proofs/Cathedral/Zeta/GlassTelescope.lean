/-
Copyright (c) 2026 Cathedral Project. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
import Mathlib.NumberTheory.LSeries.RiemannZeta
import Mathlib.NumberTheory.LSeries.Dirichlet
import Mathlib.NumberTheory.LSeries.Nonvanishing
import Mathlib.Analysis.SpecialFunctions.Pow.Complex

/-!
# Glass Telescope Identity

The telescoping product identity:
  ζ(s) = ζ(2ⁿs) · ∏_{k<n} ζ(2^k·s)/ζ(2^{k+1}·s)

This is algebraically trivial (the product telescopes to ζ(s)/ζ(2ⁿs)),
but requires establishing that all denominators ζ(2^{k+1}·s) ≠ 0.

Using Mathlib's `riemannZeta_ne_zero_of_one_le_re` (the classical
de la Vallée-Poussin zero-free region), we prove this for Re(s) > 1/2,
since Re(2^{k+1}·s) ≥ 2^k ≥ 1 for all k ≥ 0.

Graduates the `glass_telescope_analytic` axiom from GlassCriticalLine.lean.
-/

noncomputable section
set_option linter.unusedSimpArgs false

open Complex Real Filter Topology Finset

namespace Cathedral.Zeta.GlassTelescope

-- ════════════════════════════════════════════════════════════════
-- §1. REAL PART COMPUTATION
-- ════════════════════════════════════════════════════════════════

/-- Re(2^k · s) = 2^k · Re(s). -/
lemma re_two_pow_mul (s : ℂ) (k : ℕ) :
    ((2 : ℂ) ^ k * s).re = 2 ^ k * s.re := by
  have h : (2 : ℂ) ^ k = ((2 ^ k : ℝ) : ℂ) := by
    induction k with
    | zero => simp
    | succ n ih => push_cast [pow_succ]; rw [ih]
  simp only [h, re_ofReal_mul]

-- ════════════════════════════════════════════════════════════════
-- §2. NON-VANISHING IN THE TELESCOPE
-- ════════════════════════════════════════════════════════════════

/-- For Re(s) > 1/2, ζ(2^{k+1}·s) ≠ 0.

    Since Re(2^{k+1}·s) = 2^{k+1}·Re(s) > 2^{k+1}·(1/2) = 2^k ≥ 1,
    the result follows from `riemannZeta_ne_zero_of_one_le_re`. -/
lemma zeta_two_pow_ne_zero {s : ℂ} (hs : (1 : ℝ) / 2 < s.re) (k : ℕ) :
    riemannZeta ((2 : ℂ) ^ (k + 1) * s) ≠ 0 := by
  apply riemannZeta_ne_zero_of_one_le_re
  rw [re_two_pow_mul]
  have h2k : (1 : ℝ) ≤ 2 ^ k := by exact_mod_cast Nat.one_le_two_pow
  have : 2 ^ (k + 1) * s.re > 2 ^ (k + 1) * (1 / 2) := by
    apply mul_lt_mul_of_pos_left hs
    exact_mod_cast Nat.pos_of_ne_zero (by positivity)
  linarith [show (2 : ℝ) ^ (k + 1) * (1 / 2) = 2 ^ k from by rw [pow_succ]; ring]

-- ════════════════════════════════════════════════════════════════
-- §3. THE TELESCOPE IDENTITY
-- ════════════════════════════════════════════════════════════════

/-- Algebraic helper: a * (P * (b / a)) = b * P when a ≠ 0.
    This is the key cancellation step in the telescoping induction. -/
private lemma mul_prod_div_cancel {a b P : ℂ} (ha : a ≠ 0) :
    a * (P * (b / a)) = b * P := by
  have : a * (P * (b / a)) = P * (a * (b / a)) := by ring
  rw [this, mul_comm a (b / a), div_mul_cancel₀ b ha, mul_comm]

/-- The telescope collapses: ζ(2ⁿs) · ∏_{k<n} ζ(2^k·s)/ζ(2^{k+1}·s) = ζ(s).

    By induction on n:
    - Base: ζ(s) · (empty product) = ζ(s)
    - Step: ζ(2^{n+1}s) · (∏_{k<n} · ζ(2^n·s)/ζ(2^{n+1}·s))
            = ζ(2^n·s) · ∏_{k<n}  [cancel ζ(2^{n+1}·s)]
            = ζ(s)                 [by IH] -/
theorem glass_telescope_identity (s : ℂ) (n : ℕ) (hs : (1 : ℝ) / 2 < s.re) :
    riemannZeta ((2 : ℂ) ^ n * s) *
      ∏ k ∈ Finset.range n,
        (riemannZeta ((2 : ℂ) ^ k * s) / riemannZeta ((2 : ℂ) ^ (k + 1) * s))
    = riemannZeta s := by
  induction n with
  | zero => simp
  | succ n ih =>
    rw [Finset.prod_range_succ]
    -- Goal: ζ(2^(n+1)·s) * (P * (ζ(2^n·s) / ζ(2^(n+1)·s))) = ζ(s)
    rw [mul_prod_div_cancel (zeta_two_pow_ne_zero hs n)]
    exact ih

/-- **The Glass Telescope** (GRADUATED):
    ζ(s) = ζ(2ⁿ·s) · ∏_{k=0}^{n-1} ζ(2^k·s)/ζ(2^{k+1}·s)

    🎓 GRADUATED — the axiom `glass_telescope_analytic` is now a theorem.
    The telescope is algebraically trivial; the real content is the
    non-vanishing ζ(2^{k+1}·s) ≠ 0, which follows from the classical
    zero-free region Re(s) ≥ 1 (de la Vallée-Poussin). -/
theorem glass_telescope (s : ℂ) (n : ℕ) (_hn : 0 < n)
    (hs : (1 : ℝ) / 2 < s.re) :
    riemannZeta s = riemannZeta ((2 : ℂ) ^ n * s) *
      ∏ k ∈ Finset.range n,
        (riemannZeta ((2 : ℂ) ^ k * s) / riemannZeta ((2 : ℂ) ^ (k + 1) * s)) :=
  (glass_telescope_identity s n hs).symm

end Cathedral.Zeta.GlassTelescope

end
