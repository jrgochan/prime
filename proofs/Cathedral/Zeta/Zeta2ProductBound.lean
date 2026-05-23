/-
  Cathedral/Zeta/Zeta2ProductBound.lean

  ## Graduation of zeta2Product_lower_bound

  Proves: ∃ c > 0, ∀ N, c ≤ ∏_{p ≤ N, prime} (1 - 1/p²)

  Strategy:
  1. Each factor (1 - 1/p²) ∈ (0, 1) for prime p ≥ 2
  2. ln(1-x) ≥ -2x for 0 ≤ x ≤ 1/2  (elementary calculus)
  3. Σ ln(1-1/p²) ≥ -2·Σ 1/p² ≥ -2·Σ 1/n²  (comparison)
  4. Σ 1/n² < ∞  (Mathlib: summable_one_div_nat_pow, since 1 < 2)
  5. Z₂(N) = exp(Σ ln(1-1/p²)) ≥ exp(-2·Σ 1/n²) > 0

  This graduates the axiom `zeta2Product_lower_bound` from
  GlassEulerConvergence.lean.
-/

import Mathlib.Analysis.PSeries
import Mathlib.Analysis.SpecialFunctions.Log.Basic
import Mathlib.Analysis.SpecialFunctions.ExpDeriv
import Mathlib.Topology.Algebra.InfiniteSum.Basic
import Cathedral.Physics.Glass.GlassEulerConvergence

set_option autoImplicit false

noncomputable section
open Real Finset Filter Topology

namespace Cathedral.Zeta.Zeta2ProductBound
open Cathedral.GlassEulerConvergence

-- ════════════════════════════════════════════════════════════════
-- §1. LOGARITHMIC BOUND: ln(1-x) ≥ -2x for 0 ≤ x ≤ 1/2
-- ════════════════════════════════════════════════════════════════

/-- For 0 ≤ x ≤ 1/2, we have ln(1-x) ≥ -2x.
    This follows from the concavity of ln: ln(1-x) ≥ ln(1) + ln'(1)·(-x) = -x ≥ -2x,
    but we use a direct bound: 1-x ≥ exp(-2x) for x ∈ [0, 1/2].

    For the Cathedral, this is axiomatized as an elementary calculus fact.
    It can be graduated via monotonicity of f(x) = ln(1-x) + 2x on [0, 1/2]. -/
axiom log_one_sub_ge_neg_two_mul :
    ∀ x : ℝ, 0 ≤ x → x ≤ 1/2 → Real.log (1 - x) ≥ -2 * x

-- ════════════════════════════════════════════════════════════════
-- §2. PRODUCT-LOG CONNECTION
-- ════════════════════════════════════════════════════════════════

/-- The ζ(2) product factors are nonzero (needed for log_prod). -/
theorem zeta2_factor_ne_zero (p : ℕ) (hp : Nat.Prime p) :
    1 - 1 / (p : ℝ) ^ 2 ≠ 0 := by
  have : (1 : ℝ) < (p : ℝ) := by exact_mod_cast hp.one_lt
  have : (1 : ℝ) < (p : ℝ) ^ 2 := by nlinarith
  have : 1 / (p : ℝ) ^ 2 < 1 := by
    rw [div_lt_one (by positivity)]; linarith
  linarith

/-- The log of the ζ(2) product equals the sum of logs. -/
theorem log_zeta2Product (N : ℕ) :
    Real.log (zeta2Product N) =
    ∑ p ∈ (range (N+1)).filter Nat.Prime,
      Real.log (1 - 1 / (p : ℝ) ^ 2) := by
  unfold zeta2Product
  rw [Real.log_prod]
  intro p hp
  simp only [mem_filter] at hp
  exact zeta2_factor_ne_zero p hp.2

/-- Each log factor is bounded: ln(1-1/p²) ≥ -2/p² for prime p. -/
theorem log_factor_lower_bound (p : ℕ) (hp : Nat.Prime p) :
    Real.log (1 - 1 / (p : ℝ) ^ 2) ≥ -2 * (1 / (p : ℝ) ^ 2) := by
  have hp_gt1 : (1 : ℝ) < (p : ℝ) := by exact_mod_cast hp.one_lt
  have hp2_pos : (0 : ℝ) < (p : ℝ) ^ 2 := by positivity
  have h_le_half : 1 / (p : ℝ) ^ 2 ≤ 1 / 2 := by
    have hp_ge2 : (2 : ℝ) ≤ (p : ℝ) := by exact_mod_cast hp.two_le
    have hp2_ge4 : (4 : ℝ) ≤ (p : ℝ) ^ 2 := by nlinarith
    -- 1/p² ≤ 1/4 ≤ 1/2
    have : 1 / (p : ℝ) ^ 2 ≤ 1 / 4 := by
      apply div_le_div_of_nonneg_left one_pos.le (by positivity) hp2_ge4
    linarith
  have h_nonneg : 0 ≤ 1 / (p : ℝ) ^ 2 := by positivity
  exact log_one_sub_ge_neg_two_mul _ h_nonneg h_le_half

-- ════════════════════════════════════════════════════════════════
-- §3. THE MAIN BOUND (graduation)
-- ════════════════════════════════════════════════════════════════

/-- **THEOREM (graduation)**: The ζ(2) product is bounded below.

    Z₂(N) ≥ exp(-2 · Σ_{n≥1} 1/n²) > 0 for all N.

    This graduates the axiom `zeta2Product_lower_bound`.
    The only remaining axiom is `log_one_sub_ge_neg_two_mul`
    (elementary calculus: ln(1-x) ≥ -2x for x ∈ [0,1/2]). -/
theorem zeta2Product_lower_bound_proved :
    ∃ c : ℝ, 0 < c ∧ ∀ N : ℕ, c ≤ zeta2Product N := by
  -- Step 1: Σ 1/n² converges (Mathlib p-series test, since 1 < 2)
  have h_summable : Summable (fun n : ℕ => 1 / (n : ℝ) ^ 2) :=
    Real.summable_one_div_nat_pow.mpr (by norm_num : 1 < 2)
  -- Step 2: Get the sum S = tsum (1/n²)
  set S := ∑' n : ℕ, 1 / (n : ℝ) ^ 2
  -- Step 3: Our lower bound constant c = exp(-2S) > 0
  refine ⟨Real.exp (-2 * S), Real.exp_pos _, ?_⟩
  -- Step 4: For each N, Z₂(N) ≥ exp(-2S)
  intro N
  -- Equivalently: log(exp(-2S)) ≤ log(Z₂(N))
  rw [← Real.log_le_log_iff (Real.exp_pos _) (zeta2Product_pos N)]
  rw [Real.log_exp, log_zeta2Product]
  -- Need: -2S ≤ Σ_{p prime, p≤N} ln(1-1/p²)
  -- Strategy: -2S ≤ -2·Σ_p 1/p² = Σ_p (-2/p²) ≤ Σ_p ln(1-1/p²)
  calc -2 * S
      ≤ -(2 * ∑ p ∈ (range (N+1)).filter Nat.Prime, 1 / (p : ℝ) ^ 2) := by
        have h_fin_le : ∑ p ∈ (range (N+1)).filter Nat.Prime, 1 / (p : ℝ) ^ 2 ≤ S := by
          calc ∑ p ∈ (range (N+1)).filter Nat.Prime, 1 / (p : ℝ) ^ 2
              ≤ ∑ n ∈ range (N+1), 1 / (n : ℝ) ^ 2 := by
                apply sum_le_sum_of_subset_of_nonneg (filter_subset _ _)
                intros; positivity
            _ ≤ S := h_summable.sum_le_tsum _ (fun n _ => by positivity)
        linarith
    _ = ∑ p ∈ (range (N+1)).filter Nat.Prime, (-2 * (1 / (p : ℝ) ^ 2)) := by
        simp only [neg_mul, mul_sum, Finset.sum_neg_distrib]
    _ ≤ ∑ p ∈ (range (N+1)).filter Nat.Prime,
            Real.log (1 - 1 / (p : ℝ) ^ 2) := by
        apply sum_le_sum
        intro p hp
        simp only [mem_filter] at hp
        exact (log_factor_lower_bound p hp.2).le
end Cathedral.Zeta.Zeta2ProductBound
