/-
Copyright (c) 2026 Cathedral Project. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
import Mathlib.NumberTheory.LSeries.RiemannZeta
import Mathlib.NumberTheory.LSeries.Dirichlet
import Mathlib.Topology.Algebra.InfiniteSum.Basic
import Mathlib.Analysis.SpecialFunctions.Pow.Real
import Mathlib.Analysis.PSeries
import Mathlib.Analysis.Normed.Group.InfiniteSum

/-!
# ζ(2ⁿs) → 1 as n → ∞

For Re(s) > 0, the sequence ζ(2ⁿ·s) tends to 1 as n → ∞.

This graduates the `zeta_tower_limit` axiom from GlassCriticalLine.lean,
reducing the Cathedral's axiom count from 3 to 2.
-/

noncomputable section
set_option linter.unusedSimpArgs false

open Complex Real Filter Topology Finset

namespace Cathedral.Zeta.ZetaTowerLimit

-- ════════════════════════════════════════════════════════════════
-- §1. REAL PART COMPUTATION
-- ════════════════════════════════════════════════════════════════

/-- Re(2ⁿ · s) = 2ⁿ · Re(s). -/
lemma re_two_pow_mul (s : ℂ) (n : ℕ) :
    ((2 : ℂ) ^ n * s).re = 2 ^ n * s.re := by
  have h : (2 : ℂ) ^ n = ((2 ^ n : ℝ) : ℂ) := by
    induction n with
    | zero => simp
    | succ k ih => push_cast [pow_succ]; rw [ih]
  simp only [h, re_ofReal_mul]

/-- Re(2ⁿ · s) → ∞ when Re(s) > 0. -/
lemma re_two_pow_mul_tendsto (s : ℂ) (hs : 0 < s.re) :
    Tendsto (fun n => ((2 : ℂ) ^ n * s).re) atTop atTop := by
  simp only [re_two_pow_mul]
  exact (tendsto_pow_atTop_atTop_of_one_lt (by norm_num : (1 : ℝ) < 2)).atTop_mul_const hs

-- ════════════════════════════════════════════════════════════════
-- §2. THE DIRICHLET TAIL BOUND
-- ════════════════════════════════════════════════════════════════

/-- For Re(s) ≥ 3, |ζ(s) - 1| ≤ (1/2)^(Re(s)-2).

    Uses ζ(s) = Σ 1/n^s, the factoring n⁻σ ≤ n⁻² · 2⁻⁽σ⁻²⁾,
    and the comparison Σ_{n≥2} n⁻² ≤ Σ 1/(n(n-1)) = 1. -/
lemma norm_riemannZeta_sub_one_le {s : ℂ} (hs : 3 ≤ s.re) :
    ‖riemannZeta s - 1‖ ≤ (1 / 2 : ℝ) ^ (s.re - 2) := by
  have hs1 : 1 < s.re := by linarith
  have hne : s ≠ 0 := by intro h; rw [h] at hs1; simp at hs1; linarith
  rw [zeta_eq_tsum_one_div_nat_cpow hs1]
  -- The summand f(n) = 1/(n:ℂ)^s
  -- f(0) = 1/0^s = 0, f(1) = 1/1^s = 1
  -- So Σ f - 1 = Σ_{n≥2} f(n)
  -- Summability of f
  have hsumm : Summable (fun n : ℕ => 1 / (↑n : ℂ) ^ s) :=
    Complex.summable_one_div_nat_cpow.mpr hs1
  -- Split: Σ f = f(0) + Σ_{n≥1} f(n+1)
  rw [hsumm.tsum_eq_zero_add]
  -- f(0) = 0
  simp only [Nat.cast_zero, zero_cpow hne, div_zero, zero_add]
  -- Now: ‖Σ_{n:ℕ} 1/(n+1)^s - 1‖ ≤ bound
  -- Split again: Σ_{n:ℕ} 1/(n+1)^s = f(1) + Σ_{n:ℕ} 1/(n+2)^s = 1 + tail
  have hsumm1 : Summable (fun n : ℕ => 1 / (↑(n + 1) : ℂ) ^ s) :=
    hsumm.comp_injective (fun a b hab => by omega)
  rw [hsumm1.tsum_eq_zero_add]
  -- The n=0 term of the shifted series: 1/(0+1)^s = 1
  simp only [Nat.cast_zero, zero_add, Nat.cast_one, one_cpow, div_one]
  -- Goal: ‖1 + tail - 1‖ = ‖tail‖ ≤ bound
  rw [add_sub_cancel_left]
  -- Goal: ‖∑' n, 1/(n+2)^s‖ ≤ (1/2)^(σ-2)
  -- Use tsum_of_norm_bounded with dominator g(n) = (n+2)^{-2} · (1/2)^(σ-2)
  -- HasSum g ((1/2)^(σ-2)) by telescoping × constant
  -- Each ‖1/(n+2)^s‖ = (n+2)^{-σ} ≤ g(n)
  -- Use norm bound + tsum_of_norm_bounded
  have hsumm2 : Summable (fun n : ℕ => 1 / (↑(n + 1 + 1) : ℂ) ^ s) :=
    hsumm1.comp_injective (fun a b hab => by omega)
  -- ‖tail‖ ≤ Σ norms ≤ bound
  -- Use tsum_of_norm_bounded: if HasSum g a and ‖f i‖ ≤ g i, then ‖Σ f‖ ≤ a
  -- Set g(n) = (1/2)^(σ-2) * 1/((n+1)*(n+2))
  -- Then HasSum g ((1/2)^(σ-2)) since Σ 1/((n+1)(n+2)) = 1
  -- And ‖1/(n+2)^s‖ ≤ g(n) since (n+2)^{-σ} ≤ (1/2)^(σ-2) · 1/((n+1)(n+2))
  apply tsum_of_norm_bounded
  · -- HasSum dominator: HasSum (fun n => (1/2)^(σ-2) * 1/((n+1)*(n+2))) ((1/2)^(σ-2))
    -- First prove HasSum (fun n => 1/((n+1)*(n+2))) 1, then scale
    have h_tele : HasSum (fun n : ℕ => (1 : ℝ) / ((↑n + 1) * (↑n + 2))) 1 := by
      rw [hasSum_iff_tendsto_nat_of_nonneg (fun i => by positivity)]
      -- Partial sums telescope: Σ_{k<N} 1/((k+1)(k+2)) = 1 - 1/(N+1)
      have hpartial : ∀ N : ℕ, ∑ k ∈ Finset.range N, (1 : ℝ) / ((↑k + 1) * (↑k + 2)) =
          1 - 1 / (↑N + 1) := by
        intro N
        induction N with
        | zero => simp
        | succ n ih =>
          rw [Finset.sum_range_succ, ih]
          have h1 : (↑n + 1 : ℝ) ≠ 0 := by positivity
          have h2 : (↑n + 2 : ℝ) ≠ 0 := by positivity
          field_simp
          push_cast
          ring
      simp_rw [hpartial]
      -- 1 - 1/(N+1) → 1 - 0 = 1
      have : Tendsto (fun N : ℕ => 1 - 1 / ((↑N : ℝ) + 1)) atTop (nhds (1 - 0)) := by
        apply Filter.Tendsto.const_sub
        rw [show (fun N : ℕ => (1 : ℝ) / (↑N + 1)) = (fun N : ℕ => (↑N + 1)⁻¹) from by
          ext; simp [one_div]]
        have : Tendsto (fun N : ℕ => ((↑N : ℝ) + 1)⁻¹) atTop (nhds 0) := by
          apply Filter.Tendsto.inv_tendsto_atTop
          exact tendsto_atTop_add_const_right _ 1 (tendsto_natCast_atTop_atTop (R := ℝ))
        exact this
      simpa using this
    -- Scale by (1/2)^(σ-2)
    rw [show (1 / 2 : ℝ) ^ (s.re - 2) = (1 / 2 : ℝ) ^ (s.re - 2) * 1 from (mul_one _).symm]
    exact h_tele.mul_left _
  · -- Pointwise bound: ‖1/(n+2)^s‖ ≤ (1/2)^(σ-2) * 1/((n+1)(n+2))
    intro n
    -- Compute the norm
    rw [norm_div, norm_one, one_div]
    rw [show (↑(n + 1 + 1) : ℂ) = (((↑n : ℝ) + 2 : ℝ) : ℂ) from by push_cast; ring]
    rw [norm_cpow_eq_rpow_re_of_pos (by positivity : (0 : ℝ) < (↑n : ℝ) + 2)]
    -- Goal: ((↑n+2)^σ)⁻¹ ≤ (1/2)^(σ-2) * 1/((↑n+1)(↑n+2))
    have hn2 : (0 : ℝ) < (↑n : ℝ) + 2 := by positivity
    have hn1 : (0 : ℝ) < (↑n : ℝ) + 1 := by positivity
    have h2n : (2 : ℝ) ≤ (↑n : ℝ) + 2 := by linarith [show (0:ℝ) ≤ (↑n : ℝ) from Nat.cast_nonneg n]
    have hσ2 : 0 ≤ s.re - 2 := by linarith
    -- Factor: (n+2)^σ = (n+2)^2 · (n+2)^{σ-2}
    have hfactor : ((↑n : ℝ) + 2) ^ s.re = ((↑n : ℝ) + 2) ^ (2 : ℝ) * ((↑n : ℝ) + 2) ^ (s.re - 2) := by
      rw [← rpow_add hn2]; congr 1; ring
    rw [hfactor, mul_comm, mul_inv, mul_one_div]
    -- Goal: (((↑n+2)^{σ-2})⁻¹ * ((↑n+2)^2)⁻¹) ≤ (1/2)^{σ-2} / ((↑n+1)(↑n+2))
    rw [div_eq_mul_inv]
    apply mul_le_mul
    · -- ((n+2)^{σ-2})⁻¹ ≤ (1/2)^{σ-2} = 2⁻¹^{σ-2} = (2^{σ-2})⁻¹
      have h12eq : (1 / 2 : ℝ) ^ (s.re - 2) = ((2:ℝ) ^ (s.re - 2))⁻¹ := by
        rw [one_div, inv_rpow (by norm_num : (0:ℝ) ≤ 2)]
      rw [h12eq]
      exact inv_anti₀ (rpow_pos_of_pos (by norm_num : (0:ℝ) < 2) _)
        (rpow_le_rpow (by norm_num : (0:ℝ) ≤ 2) h2n hσ2)
    · -- ((n+2)^2)⁻¹ ≤ ((n+1)(n+2))⁻¹
      rw [rpow_two]
      exact inv_anti₀ (by positivity) (by nlinarith)
    · exact inv_nonneg.mpr (by positivity)
    · exact rpow_nonneg (by norm_num : (0:ℝ) ≤ 1/2) _

-- ════════════════════════════════════════════════════════════════
-- §3. THE TOWER LIMIT
-- ════════════════════════════════════════════════════════════════

/-- (1/2)^x → 0 as x → +∞ along the reals. -/
private lemma rpow_half_tendsto_zero :
    Tendsto (fun x : ℝ => (1 / 2 : ℝ) ^ x) atTop (nhds 0) := by
  have h_pos : (0 : ℝ) < 1 / 2 := by norm_num
  have h_log_neg : Real.log (1/2) < 0 := Real.log_neg h_pos (by norm_num)
  rw [show (fun x : ℝ => (1/2 : ℝ) ^ x) =
      (fun x => Real.exp (Real.log (1/2) * x)) from by
    ext x; rw [Real.rpow_def_of_pos h_pos]]
  apply Real.tendsto_exp_atBot.comp
  exact Filter.tendsto_id.const_mul_atTop_of_neg h_log_neg

/-- **The Tower Limit Theorem**: ζ(2ⁿs) → 1 as n → ∞ for Re(s) > 0.

    Graduates the `zeta_tower_limit` axiom from GlassCriticalLine.lean. -/
theorem zeta_tower_limit (s : ℂ) (hs : 0 < s.re) :
    Tendsto (fun n => riemannZeta ((2 : ℂ) ^ n * s)) atTop (nhds 1) := by
  rw [Metric.tendsto_atTop]
  intro ε hε
  -- Step 1: Eventually Re(2^n · s) ≥ 3
  obtain ⟨N₁, hN₁⟩ : ∃ N₁, ∀ n, N₁ ≤ n → 3 ≤ ((2:ℂ)^n * s).re := by
    have : ∀ᶠ n in atTop, ((2:ℂ)^n * s).re ∈ Set.Ici 3 :=
      (re_two_pow_mul_tendsto s hs) (mem_atTop 3)
    exact this.exists_forall_of_atTop
  -- Step 2: Eventually (1/2)^(Re(2^n·s)-2) < ε
  have h_sub : Tendsto (fun n => ((2:ℂ)^n * s).re - 2) atTop atTop :=
    (re_two_pow_mul_tendsto s hs).atTop_add tendsto_const_nhds
  have h_rpow : Tendsto (fun n => ((1:ℝ)/2)^(((2:ℂ)^n * s).re - 2)) atTop (nhds 0) :=
    rpow_half_tendsto_zero.comp h_sub
  obtain ⟨N₂, hN₂⟩ : ∃ N₂, ∀ n, N₂ ≤ n → ((1:ℝ)/2)^(((2:ℂ)^n * s).re - 2) < ε := by
    obtain ⟨N, hN⟩ := Metric.tendsto_atTop.mp h_rpow ε hε
    exact ⟨N, fun n hn => by
      have := hN n hn
      rwa [Real.dist_eq, sub_zero, abs_of_nonneg (rpow_nonneg (by norm_num : (0:ℝ) ≤ 1/2) _)] at this⟩
  -- Step 3: Combine
  use max N₁ N₂
  intro n hn
  rw [dist_comm, Complex.dist_eq, norm_sub_rev]
  exact lt_of_le_of_lt (norm_riemannZeta_sub_one_le (hN₁ n (le_of_max_le_left hn)))
    (hN₂ n (le_of_max_le_right hn))

end Cathedral.Zeta.ZetaTowerLimit

end
