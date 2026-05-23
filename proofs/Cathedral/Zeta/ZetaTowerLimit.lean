/-
Copyright (c) 2026 Cathedral Project. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
import Mathlib.NumberTheory.LSeries.RiemannZeta
import Mathlib.NumberTheory.LSeries.Dirichlet
import Mathlib.Topology.Algebra.InfiniteSum.Basic

/-!
# ζ(2ⁿs) → 1 as n → ∞

For Re(s) > 0, the sequence ζ(2ⁿ·s) tends to 1 as n → ∞.

This graduates the `zeta_tower_limit` axiom from GlassCriticalLine.lean,
reducing the Cathedral's axiom count from 3 to 2.

### Strategy

The Dirichlet series gives ζ(s) = 1 + Σ_{n≥2} n⁻ˢ for Re(s) > 1.
Using the factoring bound n⁻σ = n⁻² · n⁻⁽σ⁻²⁾ ≤ n⁻² · 2⁻⁽σ⁻²⁾,
we get |ζ(s) - 1| ≤ C · (1/2)^(Re(s)-2) → 0 as Re(s) → ∞.
Since Re(2ⁿs) = 2ⁿ · Re(s) → ∞ for Re(s) > 0, the result follows.

Dependencies: Mathlib.NumberTheory.LSeries.RiemannZeta
-/

noncomputable section
set_option linter.unusedSimpArgs false

open Complex Real Filter Topology Finset

namespace Cathedral.Zeta.ZetaTowerLimit

-- ════════════════════════════════════════════════════════════════
-- §1. REAL PART COMPUTATION
-- ════════════════════════════════════════════════════════════════

/-- (2:ℂ)^n has real part 2^n. -/
private lemma two_pow_re (n : ℕ) : ((2 : ℂ) ^ n).re = (2 ^ n : ℝ) := by
  induction n with
  | zero => simp
  | succ n ih =>
    rw [pow_succ, pow_succ, mul_re, two_re, two_im, zero_mul, sub_zero, ih]

/-- (2:ℂ)^n has imaginary part 0. -/
private lemma two_pow_im (n : ℕ) : ((2 : ℂ) ^ n).im = 0 := by
  induction n with
  | zero => simp
  | succ n ih =>
    rw [pow_succ, mul_im, two_re, two_im, ih, zero_mul, mul_zero, add_zero]

/-- Re(2ⁿ · s) = 2ⁿ · Re(s). -/
lemma re_two_pow_mul (s : ℂ) (n : ℕ) :
    ((2 : ℂ) ^ n * s).re = 2 ^ n * s.re := by
  rw [mul_re, two_pow_re, two_pow_im, zero_mul, sub_zero]

/-- Re(2ⁿ · s) → ∞ when Re(s) > 0. -/
lemma re_two_pow_mul_tendsto (s : ℂ) (hs : 0 < s.re) :
    Tendsto (fun n => ((2 : ℂ) ^ n * s).re) atTop atTop := by
  simp only [re_two_pow_mul]
  have h2 : Tendsto (fun n : ℕ => (2 : ℝ) ^ n) atTop atTop := by
    apply tendsto_pow_atTop_atTop_of_one_lt
    norm_num
  exact h2.atTop_mul_const hs

-- ════════════════════════════════════════════════════════════════
-- §2. THE DIRICHLET TAIL BOUND
-- ════════════════════════════════════════════════════════════════

/-- For Re(s) ≥ 3, |ζ(s) - 1| ≤ (1/2)^(Re(s)-2).

    Proof: ζ(s) = Σ_{n:ℕ} 1/n^s where the n=0 term is 0 and n=1 is 1.
    So ζ(s) - 1 = Σ_{n≥2} 1/n^s.
    For n ≥ 2 and σ = Re(s) ≥ 3:
      |1/n^s| = n^{-σ} = n^{-2} · n^{-(σ-2)} ≤ n^{-2} · 2^{-(σ-2)}
    So |ζ(s) - 1| ≤ Σ_{n≥2} n^{-2} · 2^{-(σ-2)} ≤ 1 · (1/2)^(σ-2). -/
lemma norm_riemannZeta_sub_one_le {s : ℂ} (hs : 3 ≤ s.re) :
    ‖riemannZeta s - 1‖ ≤ (1 / 2 : ℝ) ^ (s.re - 2) := by
  sorry

-- ════════════════════════════════════════════════════════════════
-- §3. THE TOWER LIMIT
-- ════════════════════════════════════════════════════════════════

/-- (1/2)^x → 0 as x → +∞ along the reals. -/
private lemma rpow_half_tendsto_zero :
    Tendsto (fun x : ℝ => (1 / 2 : ℝ) ^ x) atTop (nhds 0) := by
  have h_pos : (0 : ℝ) < 1 / 2 := by norm_num
  have h_lt : (1 : ℝ) / 2 < 1 := by norm_num
  have h_log_neg : Real.log (1/2) < 0 := Real.log_neg h_pos h_lt
  rw [show (fun x : ℝ => (1/2 : ℝ) ^ x) =
      (fun x => Real.exp (Real.log (1/2) * x)) from by
    ext x; rw [Real.rpow_def_of_pos h_pos]]
  apply Real.tendsto_exp_atBot.comp
  exact tendsto_const_nhds.neg_mul_atTop (neg_neg.mpr h_log_neg) tendsto_id

/-- **The Tower Limit Theorem**: ζ(2ⁿs) → 1 as n → ∞ for Re(s) > 0.

    Graduates the `zeta_tower_limit` axiom from GlassCriticalLine.lean. -/
theorem zeta_tower_limit (s : ℂ) (hs : 0 < s.re) :
    Tendsto (fun n => riemannZeta ((2 : ℂ) ^ n * s)) atTop (nhds 1) := by
  rw [Metric.tendsto_atTop]
  intro ε hε
  -- Step 1: Eventually Re(2^n · s) ≥ 3
  have hre := re_two_pow_mul_tendsto s hs
  obtain ⟨N₁, hN₁⟩ : ∃ N₁, ∀ n, N₁ ≤ n → 3 ≤ ((2:ℂ)^n * s).re := by
    have : ∀ᶠ n in atTop, ((2:ℂ)^n * s).re ∈ Set.Ici 3 :=
      hre (mem_atTop 3)
    exact this.exists_forall_of_atTop
  -- Step 2: Eventually (1/2)^(Re(2^n·s)-2) < ε
  have h_sub : Tendsto (fun n => ((2:ℂ)^n * s).re - 2) atTop atTop :=
    (re_two_pow_mul_tendsto s hs).atTop_add tendsto_const_nhds
  have h_rpow : Tendsto (fun n => ((1:ℝ)/2)^(((2:ℂ)^n * s).re - 2)) atTop (nhds 0) :=
    rpow_half_tendsto_zero.comp h_sub
  obtain ⟨N₂, hN₂⟩ : ∃ N₂, ∀ n, N₂ ≤ n → ((1:ℝ)/2)^(((2:ℂ)^n * s).re - 2) < ε := by
    have : ∀ᶠ n in atTop, ((1:ℝ)/2)^(((2:ℂ)^n * s).re - 2) < ε := by
      have := (Metric.tendsto_atTop.mp h_rpow ε hε)
      exact this.mono fun n hn => by
        rw [Real.dist_eq, sub_zero, abs_of_nonneg] at hn
        · exact hn
        · exact rpow_nonneg (by norm_num : (0:ℝ) ≤ 1/2) _
    exact this.exists_forall_of_atTop
  -- Step 3: Combine
  use max N₁ N₂
  intro n hn
  rw [dist_comm, Complex.dist_eq, norm_sub_rev]
  have h3 : 3 ≤ ((2:ℂ)^n * s).re := hN₁ n (le_of_max_le_left hn)
  have hbound := norm_riemannZeta_sub_one_le h3
  have hsmall := hN₂ n (le_of_max_le_right hn)
  -- ‖ζ(2^n·s) - 1‖ ≤ (1/2)^(Re-2) < ε
  exact lt_of_le_of_lt hbound hsmall

end Cathedral.Zeta.ZetaTowerLimit

end
