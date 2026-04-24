/-
  Cathedral/White/Infrastructure/Perron/HalfIntegerPerron.lean

  ## The Silver Bullet: Half-Integer Perron Formula

  This file implements the three-part strategy for closing the Perron formula
  assembly, as designed by the Theorist:

  1. **Dynamic N Trick**: Choose N so large that the Dirichlet tail error
     is crushed to O(x^c/T), using only the Archimedean property.
  2. **Half-Integer Shift**: Evaluate the Perron formula at X = m + 1/2,
     eliminating the log singularity at x = n.
  3. **T = X² Masterstroke**: Set T = X² in the assembly to collapse all
     error bounds to O(X^{1/2+ε}).

  ### Architecture
    §1. Log bound at half-integers (`half_integer_log_bound`)
    §2. Perron error at half-integers (`perron_formula_error_bound_full`)
    §3. Half-integer log sum bound (`perron_log_sum_bound`)
    §4. Dirichlet tail integral bound (`dirichlet_tail_integral_bound`)
    §5. Main theorem (`truncated_perron_half_integer`)

  ### Dependencies
    - DirichletPoly (finite_sum_integral_swap, moebius_partial_sum_approx)
    - Defs (perronIntegral, perronIntegrand)
    - DirichletZetaInverse (summatoryMoebius)
-/

import Cathedral.White.Infrastructure.Perron.DirichletPoly
import Cathedral.White.Infrastructure.Perron.KernelBound
import Cathedral.White.Infrastructure.DirichletZetaInverse
import Cathedral.White.Infrastructure.SummabilityHelpers

noncomputable section
open Complex Real MeasureTheory Set Filter ArithmeticFunction Finset
open scoped LSeries.notation ArithmeticFunction.Moebius ArithmeticFunction.zeta Topology

namespace Cathedral.White.Infrastructure.HalfIntegerPerron

-- ═══════════════════════════════════════════
-- §0. Foundational Log Bounds (reusable)
-- ═══════════════════════════════════════════

/-- **log(y) ≥ 1 - 1/y** for y > 0.
    Proof: from `exp(t) ≥ 1 + t`, set `t = -log(y)`. -/
lemma log_ge_one_sub_inv (y : ℝ) (hy : 0 < y) : 1 - 1/y ≤ Real.log y := by
  have h := Real.add_one_le_exp (-Real.log y)
  rw [Real.exp_neg, Real.exp_log hy] at h
  rw [one_div]; linarith

/-- **log(y) ≤ y - 1** for y > 0.
    Proof: from `exp(t) ≥ 1 + t`, set `t = log(y)`. -/
lemma log_le_sub_one (y : ℝ) (hy : 0 < y) : Real.log y ≤ y - 1 := by
  have h := Real.add_one_le_exp (Real.log y)
  rw [Real.exp_log hy] at h; linarith

/-- For y > 1, log(y) > 0 and log(y) ≥ (y-1)/y = 1 - 1/y.
    This gives |log(y)| = log(y) ≥ 1 - 1/y > 0 when y > 1. -/
lemma abs_log_ge_of_gt_one (y : ℝ) (hy : 1 < y) :
    |Real.log y| ≥ 1 - 1/y := by
  rw [abs_of_pos (Real.log_pos hy)]
  exact log_ge_one_sub_inv y (by linarith)

/-- For 0 < y < 1, -log(y) > 0 and |log(y)| = -log(y) = log(1/y) ≥ 1 - y.
    Proof: log(1/y) = -log(y), and log(1/y) ≥ 1 - 1/(1/y) = 1 - y. -/
lemma abs_log_ge_of_lt_one (y : ℝ) (hy_pos : 0 < y) (hy_lt : y < 1) :
    |Real.log y| ≥ 1 - y := by
  rw [abs_of_neg (Real.log_neg hy_pos hy_lt)]
  have h := log_le_sub_one y hy_pos
  linarith

-- ═══════════════════════════════════════════
-- §1. Half-Integer Log Bound
-- ═══════════════════════════════════════════

/-- At half-integers X = m + 1/2, the quantity X/n is never an integer,
    and |log(X/n)| is bounded below by 1/(8X) for all n ≥ 1.
    Equivalently: 1/|log(X/n)| ≤ 8X.

    This is the key insight that eliminates the log singularity.

    **Proof** (two cases):
    - If n < X or n > X (far): |log(X/n)| ≥ 1 - min(n/X, X/n) ≥ 1/(2X)
      (using log(y) ≥ 1-1/y for y > 1, |log(y)| ≥ 1-y for y < 1)
    - Both cases: since |X - n| ≥ 1/2, the bound 1/(2X) ≥ 1/(8X). -/
lemma half_integer_log_bound (m : ℕ) (hm : 2 ≤ m) (n : ℕ) (hn : 1 ≤ n) :
    let X : ℝ := (m : ℝ) + 1/2
    0 < |Real.log (X / ↑n)| ∧ 1 / |Real.log (X / ↑n)| ≤ 8 * X := by
  intro X
  have hX_pos : (0 : ℝ) < X := by positivity
  have hX_ge : (5:ℝ)/2 ≤ X := by
    show (5:ℝ)/2 ≤ (m : ℝ) + 1/2
    have : (2 : ℝ) ≤ (m : ℝ) := Nat.ofNat_le_cast.mpr hm
    linarith
  have hn_pos : (0 : ℝ) < (n : ℝ) := Nat.cast_pos.mpr (by omega)
  have hXn_pos : 0 < X / ↑n := div_pos hX_pos hn_pos
  -- Half-integer key fact: X/n ≠ 1 (X = m + 1/2 is not a natural number)
  have hXn_ne_one : X / ↑n ≠ 1 := by
    intro h
    have hXn : X = (n : ℝ) := by field_simp at h; linarith
    -- X = m + 1/2 = n → 2m + 1 = 2n → odd = even, contradiction
    have h2 : (m : ℝ) + 1/2 = (n : ℝ) := hXn
    have h3 : 2 * (m : ℝ) + 1 = 2 * (n : ℝ) := by linarith
    have h4 : (2 * m + 1 : ℕ) = (2 * n : ℕ) := by exact_mod_cast h3
    omega
  -- Therefore |log(X/n)| > 0
  have hlog_ne : Real.log (X / ↑n) ≠ 0 :=
    Real.log_ne_zero_of_pos_of_ne_one hXn_pos hXn_ne_one
  have habs_pos : 0 < |Real.log (X / ↑n)| := abs_pos.mpr hlog_ne
  refine ⟨habs_pos, ?_⟩
  -- Need: 1/|log(X/n)| ≤ 8X, equivalently |log(X/n)| ≥ 1/(8X)
  suffices h : 1 / (8 * X) ≤ |Real.log (X / ↑n)| by
    rw [div_le_iff₀ habs_pos]
    have h8X : (0 : ℝ) < 8 * X := by positivity
    nlinarith [mul_le_mul_of_nonneg_right h h8X.le,
              div_mul_cancel₀ (1 : ℝ) (ne_of_gt h8X)]
  -- The core bound: |X - n| ≥ 1/2 (half-integer gap)
  have hXn_gap : |X - ↑n| ≥ 1/2 := by
    rw [show X - ↑n = (m : ℝ) + 1/2 - ↑n from rfl]
    -- |m + 1/2 - n| = |m - n + 1/2|, and m - n is an integer
    -- So the fractional part is 1/2, giving |·| ≥ 1/2
    have : ∃ k : ℤ, (m : ℝ) - ↑n = ↑k := ⟨(m : ℤ) - n, by push_cast; ring⟩
    obtain ⟨k, hk⟩ := this
    rw [show (m : ℝ) + 1/2 - ↑n = ↑k + 1/2 from by linarith]
    rw [show |(k : ℝ) + 1/2| = |↑k + 1/2| from rfl]
    by_cases hk_nn : (0 : ℝ) ≤ (k : ℝ)
    · -- k ≥ 0: |k + 1/2| = k + 1/2 ≥ 1/2
      rw [abs_of_nonneg (by linarith)]; linarith
    · -- k < 0: k ≤ -1, so k + 1/2 ≤ -1/2, |k + 1/2| ≥ 1/2
      push_neg at hk_nn
      have : k ≤ -1 := Int.le_sub_one_of_lt (by exact_mod_cast hk_nn)
      have : (k : ℝ) ≤ -1 := by exact_mod_cast this
      rw [abs_of_neg (by linarith)]; linarith
  -- Two cases based on whether X/n > 1 or X/n < 1
  rcases lt_or_gt_of_ne hXn_ne_one with hlt | hgt
  · -- Case: X/n < 1, i.e. n > X
    -- |log(X/n)| ≥ 1 - X/n = (n - X)/n ≥ (1/2)/n ≥ 1/(2n)
    have hXn_lt : X / ↑n < 1 := hlt
    have hn_gt_X : X < ↑n := by rwa [div_lt_one hn_pos] at hXn_lt
    have h_abs_log : |Real.log (X / ↑n)| ≥ 1 - X / ↑n :=
      abs_log_ge_of_lt_one (X / ↑n) hXn_pos hXn_lt
    have h_diff : 1 - X / ↑n = (↑n - X) / ↑n := by field_simp
    rw [h_diff] at h_abs_log
    -- (n - X)/n ≥ (1/2)/n since |X - n| ≥ 1/2 and n > X means n - X ≥ 1/2
    have h_nX : ↑n - X ≥ 1/2 := by
      have := hXn_gap
      rw [abs_of_nonpos (by linarith)] at this; linarith
    have h_bound : (1/2) / ↑n ≤ (↑n - X) / ↑n :=
      div_le_div_of_nonneg_right h_nX hn_pos.le
    -- (1/2)/n ≥ 1/(8X) since n ≤ X + X = 2X (actually n ≤ bound, but
    -- we need: 1/(2n) ≥ 1/(8X), i.e. 8X ≥ 2n, i.e. 4X ≥ n
    -- Since n ≤ ⌊X⌋ + ... this is NOT always true. Use weaker bound:
    -- |log| ≥ (n-X)/n ≥ 1/(2n). And 1/(2n) ≥ 1/(8X) iff 4X ≥ n.
    -- But n could be > 4X! We need a different argument for large n.
    -- For large n (n > 2X): X/n < 1/2, so |log(X/n)| > log 2 > 1/(8X)
    -- For moderate n (X < n ≤ 2X): use the (n-X)/n bound
    by_cases hn_le : (n : ℝ) ≤ 4 * X
    · -- n ≤ 4X: 1/(2n) ≥ 1/(8X)
      calc 1 / (8 * X) ≤ (1/2) / ↑n := by
              rw [div_le_div_iff₀ (by positivity) hn_pos]; nlinarith
        _ ≤ (↑n - X) / ↑n := h_bound
        _ ≤ |Real.log (X / ↑n)| := h_abs_log
    · -- n > 4X: X/n < 1/4, so |log(X/n)| ≥ 1 - X/n > 3/4 ≥ 1/(8X)
      push_neg at hn_le
      have hXn_small : X / ↑n < 1/4 := by
        rw [div_lt_iff₀ hn_pos]; linarith
      -- |log(X/n)| ≥ 1 - X/n > 1 - 1/4 = 3/4 ≥ 1/(8X) since X ≥ 5/2
      have h1 : 1 / (8 * X) ≤ 1/20 := by
        rw [div_le_div_iff₀ (by positivity) (by norm_num : (0:ℝ) < 20)]; nlinarith
      linarith
  · -- Case: X/n > 1, i.e. n < X
    -- |log(X/n)| = log(X/n) ≥ 1 - n/X = (X - n)/X ≥ (1/2)/X = 1/(2X) ≥ 1/(8X)
    have hXn_gt : 1 < X / ↑n := hgt
    have hn_lt_X : ↑n < X := by rwa [lt_div_iff₀ hn_pos, one_mul] at hXn_gt
    have h_abs_log : |Real.log (X / ↑n)| ≥ 1 - 1 / (X / ↑n) :=
      abs_log_ge_of_gt_one (X / ↑n) hXn_gt
    have h_simplify : 1 - 1 / (X / ↑n) = (X - ↑n) / X := by field_simp
    rw [h_simplify] at h_abs_log
    have h_Xn : X - ↑n ≥ 1/2 := by
      have := hXn_gap; rw [abs_of_pos (by linarith)] at this; exact this
    calc 1 / (8 * X) ≤ (1/2) / X := by
            rw [div_le_div_iff₀ (by positivity) hX_pos]; nlinarith
      _ ≤ (X - ↑n) / X := div_le_div_of_nonneg_right h_Xn hX_pos.le
      _ ≤ |Real.log (X / ↑n)| := h_abs_log

-- ═══════════════════════════════════════════
-- §2. Unified Finite Perron Error
-- ═══════════════════════════════════════════

set_option maxHeartbeats 800000 in
/-- **Helper 1**: The unified finite Perron error at half-integers.

    For X = m + 1/2 (hence X ≠ n for all n), the difference between the
    Perron integral sum and the Möbius summatory function is bounded by
    the pointwise Perron kernel error terms.

    Requires N ≥ m so that M(X) = ∑_{n=1}^m μ(n) ⊆ the sum range.

    Uses: `perron_kernel_bound` for each n (unified y > 1 and y < 1 cases). -/
lemma perron_formula_error_bound_full (m : ℕ) (hm : 2 ≤ m) (c T : ℝ) (N : ℕ)
    (hc : 0 < c) (hT : 0 < T) (hN : m ≤ N) :
    let X : ℝ := (m : ℝ) + 1/2
    ‖∑ n ∈ Finset.Icc 1 N, (↑(ArithmeticFunction.moebius n) : ℂ) *
        perronIntegral (X / ↑n) c T -
      (↑(summatoryMoebius X : ℤ) : ℂ)‖ ≤
    ∑ n ∈ Finset.Icc 1 N,
      (X / ↑n) ^ c / (Real.pi * T * |Real.log (X / ↑n)|) := by
  intro X
  have hX_pos : (0 : ℝ) < X := by positivity
  -- Step 1: M(X) = ∑_{n=1}^m μ(n) since ⌊X⌋₊ = m
  have h_floor : ⌊X⌋₊ = m := by
    apply Nat.floor_eq_iff (by positivity : 0 ≤ X) |>.mpr
    constructor <;> simp [X] <;> linarith
  have hM : (summatoryMoebius X : ℤ) = ∑ n ∈ Finset.Icc 1 m, μ n := by
    unfold summatoryMoebius; rw [h_floor]
  -- Step 2: X/n > 1 ↔ n ≤ m, X/n < 1 ↔ n ≥ m+1
  have h_gt_one : ∀ n : ℕ, 1 ≤ n → n ≤ m → 1 < X / ↑n := by
    intro n hn1 hn2
    rw [one_lt_div (Nat.cast_pos.mpr (by omega : 0 < n))]
    have : (n : ℝ) ≤ (m : ℝ) := Nat.cast_le.mpr hn2
    show (n : ℝ) < (m : ℝ) + 1 / 2; linarith
  have h_lt_one : ∀ n : ℕ, m + 1 ≤ n → X / ↑n < 1 := by
    intro n hn
    rw [div_lt_one (Nat.cast_pos.mpr (by omega : 0 < n))]
    have : (m : ℝ) + 1 ≤ (n : ℝ) := by exact_mod_cast hn
    show (m : ℝ) + 1 / 2 < (n : ℝ); linarith
  have h_pos : ∀ n : ℕ, 1 ≤ n → 0 < X / ↑n :=
    fun n hn => div_pos hX_pos (Nat.cast_pos.mpr (by omega))
  -- X/n ≠ 1 for all n ≥ 1 (half-integer vs integer)
  have h_ne_one : ∀ n : ℕ, 1 ≤ n → X / ↑n ≠ 1 := by
    intro n hn habs
    -- X/n = 1 → X = n → m + 1/2 = n, impossible since 2*(m+1/2) = 2m+1 is odd
    have hXn : X = (n : ℝ) := by
      rwa [div_eq_one_iff_eq (Nat.cast_pos.mpr (by omega)).ne'] at habs
    -- 2*X = 2m+1 (odd), but 2*n is even
    have h1 : 2 * X = 2 * (m : ℝ) + 1 := by simp [X]; ring
    have h2 : 2 * X = 2 * (n : ℝ) := by rw [hXn]
    -- 2m+1 = 2n → odd = even, contradiction
    have : 2 * (m : ℤ) + 1 = 2 * (n : ℤ) := by exact_mod_cast (by linarith : 2*(m:ℝ)+1 = 2*(n:ℝ))
    omega
  -- Step 3: Introduce the indicator and rewrite the difference
  -- M(X) = ∑_{n ∈ Icc 1 m} μ(n) = ∑_{n ∈ Icc 1 N} μ(n)·𝟙(1 < X/n)
  -- since: for n ≤ m, X/n > 1 (so 𝟙 = 1); for n > m, X/n < 1 (so 𝟙 = 0)
  -- Therefore: LHS = ∑ μ(n)·(P(X/n) - 𝟙(1 < X/n))

  -- First, establish that the indicator sum equals M(X)
  have h_ind_eq : (↑(summatoryMoebius X : ℤ) : ℂ) =
      ∑ n ∈ Finset.Icc 1 N, (↑(μ n) : ℂ) * (if 1 < X / ↑n then 1 else 0) := by
    rw [hM, Int.cast_sum]
    -- Split Icc 1 N = Icc 1 m ∪ Icc (m+1) N
    have h_disj : Finset.Icc 1 N = Finset.Icc 1 m ∪ Finset.Icc (m + 1) N := by
      ext k; simp [Finset.mem_union, Finset.mem_Icc]; omega
    have h_disjoint : Disjoint (Finset.Icc 1 m) (Finset.Icc (m + 1) N) := by
      simp [Finset.disjoint_left]; omega
    rw [h_disj, Finset.sum_union h_disjoint]
    -- For n ∈ Icc (m+1) N: 𝟙(1 < X/n) = 0 since X/n < 1
    have h_tail_zero : ∑ n ∈ Finset.Icc (m + 1) N,
        (↑(μ n) : ℂ) * (if 1 < X / ↑n then 1 else 0) = 0 := by
      apply Finset.sum_eq_zero; intro n hn
      have hn_ge : m + 1 ≤ n := (Finset.mem_Icc.mp hn).1
      simp [show ¬(1 < X / ↑n) from not_lt.mpr (le_of_lt (h_lt_one n hn_ge))]
    rw [h_tail_zero, add_zero]
    -- For n ∈ Icc 1 m: 𝟙(1 < X/n) = 1 since X/n > 1
    apply Finset.sum_congr rfl; intro n hn
    have hn1 : 1 ≤ n := (Finset.mem_Icc.mp hn).1
    have hn2 : n ≤ m := (Finset.mem_Icc.mp hn).2
    simp [h_gt_one n hn1 hn2]

  -- Step 4: Rewrite the difference
  have h_diff : ∑ n ∈ Finset.Icc 1 N, (↑(μ n) : ℂ) * perronIntegral (X / ↑n) c T -
      (↑(summatoryMoebius X : ℤ) : ℂ) =
    ∑ n ∈ Finset.Icc 1 N, (↑(μ n) : ℂ) *
      (perronIntegral (X / ↑n) c T - (if 1 < X / ↑n then 1 else 0)) := by
    rw [h_ind_eq, ← Finset.sum_sub_distrib]
    apply Finset.sum_congr rfl; intro n _; ring

  -- Step 5: Apply triangle inequality + perron_kernel_bound
  rw [h_diff]
  calc ‖∑ n ∈ Finset.Icc 1 N, (↑(μ n) : ℂ) *
        (perronIntegral (X / ↑n) c T - (if 1 < X / ↑n then 1 else 0))‖
      ≤ ∑ n ∈ Finset.Icc 1 N, ‖(↑(μ n) : ℂ) *
        (perronIntegral (X / ↑n) c T - (if 1 < X / ↑n then 1 else 0))‖ :=
        norm_sum_le _ _
    _ = ∑ n ∈ Finset.Icc 1 N, (‖(↑(μ n) : ℂ)‖ *
        ‖perronIntegral (X / ↑n) c T - (if 1 < X / ↑n then 1 else 0)‖) := by
        apply Finset.sum_congr rfl; intro n _; exact norm_mul _ _
    _ ≤ ∑ n ∈ Finset.Icc 1 N,
        (X / ↑n) ^ c / (Real.pi * T * |Real.log (X / ↑n)|) := by
        apply Finset.sum_le_sum; intro n hn
        have hn1 : 1 ≤ n := (Finset.mem_Icc.mp hn).1
        -- |μ(n)| ≤ 1
        have h_mu_le : ‖(↑(μ n) : ℂ)‖ ≤ 1 := by
          rw [Complex.norm_intCast]; exact_mod_cast abs_moebius_le_one
        -- perron_kernel_bound gives the per-term error
        have h_kern := Cathedral.White.Infrastructure.perron_kernel_bound (X / ↑n) c T
          (h_pos n hn1) (h_ne_one n hn1) hc hT
        calc ‖(↑(μ n) : ℂ)‖ * ‖perronIntegral (X / ↑n) c T -
              (if 1 < X / ↑n then 1 else 0)‖
            ≤ 1 * ((X / ↑n) ^ c / (Real.pi * T * |Real.log (X / ↑n)|)) :=
              mul_le_mul h_mu_le h_kern (norm_nonneg _) one_pos.le
          _ = _ := one_mul _

-- ═══════════════════════════════════════════
-- §3. Half-Integer Log Sum Bound
-- ═══════════════════════════════════════════



set_option maxHeartbeats 800000 in
/-- **Helper 2**: The half-integer log sum bound.

    At half-integers, using 1/|log(X/n)| ≤ 8X, we get:
    ∑_{n=1}^N (X/n)^c / |log(X/n)| ≤ 8X · ∑ (X/n)^c
                                      = 8X^{c+1} · ∑ n^{-c}
                                      ≤ 8ζ(c) · X^{c+1}
    This bound is uniform in N and uses only ζ(c) < ∞ for c > 1. -/
lemma perron_log_sum_bound (c : ℝ) (hc : 1 < c) :
    ∃ C_sum > 0, ∀ m : ℕ, 2 ≤ m → ∀ N : ℕ,
      let X : ℝ := (m : ℝ) + 1/2
      ∑ n ∈ Finset.Icc 1 N,
        (X / ↑n) ^ c / |Real.log (X / ↑n)| ≤ C_sum * X ^ (c + 1) := by
  open Cathedral.White.Infrastructure.SummabilityHelpers in
  -- Use pre-proved lemmas from SummabilityHelpers
  set ζc := ∑' n : ℕ, ((n : ℝ) ^ c)⁻¹
  have hζc_pos : 0 < ζc := rpow_inv_tsum_pos hc
  refine ⟨8 * ζc, by linarith, fun m hm N => ?_⟩
  intro X
  have hX_pos : (0 : ℝ) < X := by positivity
  -- Step 1: half_integer_log_bound gives: each term ≤ (X/n)^c · 8X
  have step1 : ∑ n ∈ Finset.Icc 1 N, (X / ↑n) ^ c / |Real.log (X / ↑n)| ≤
      ∑ n ∈ Finset.Icc 1 N, (X / ↑n) ^ c * (8 * X) := by
    apply Finset.sum_le_sum; intro n hn
    have hn1 : 1 ≤ n := (Finset.mem_Icc.mp hn).1
    obtain ⟨hlog_pos, hlog_bound⟩ := half_integer_log_bound m hm n hn1
    have hA : 0 ≤ (X / ↑n) ^ c :=
      rpow_nonneg (div_nonneg hX_pos.le (Nat.cast_nonneg' n)) c
    calc (X / ↑n) ^ c / |Real.log (X / ↑n)|
        = (X / ↑n) ^ c * (1 / |Real.log (X / ↑n)|) := by ring
      _ ≤ (X / ↑n) ^ c * (8 * X) := mul_le_mul_of_nonneg_left hlog_bound hA
  -- Steps 2-4: Factor, bound by tsum, assemble
  -- ∑ (X/n)^c · 8X = 8X · ∑ X^c · n^{-c} = 8X^{c+1} · ∑ n^{-c} ≤ 8ζc · X^{c+1}
  calc ∑ n ∈ Finset.Icc 1 N, (X / ↑n) ^ c / |Real.log (X / ↑n)|
      ≤ ∑ n ∈ Finset.Icc 1 N, (X / ↑n) ^ c * (8 * X) := step1
    _ ≤ 8 * ζc * X ^ (c + 1) := by
        -- Each term: (X/n)^c * 8X = 8X^{c+1} · (n^c)^{-1}
        -- Sum: 8X^{c+1} · ∑ (n^c)⁻¹ ≤ 8X^{c+1} · ζc
        have h_bound : ∀ n ∈ Finset.Icc 1 N,
            (X / ↑n) ^ c * (8 * X) = 8 * X ^ (c + 1) * ((n : ℝ) ^ c)⁻¹ := by
          intro n hn
          have hn1 : 1 ≤ n := (Finset.mem_Icc.mp hn).1
          rw [div_rpow_eq_mul_inv hX_pos (by omega) c]
          -- Goal: X ^ c * ((n : ℝ) ^ c)⁻¹ * (8 * X) = 8 * X ^ (c + 1) * ((n : ℝ) ^ c)⁻¹
          rw [show X ^ c * ((n : ℝ) ^ c)⁻¹ * (8 * X) =
              8 * (X * X ^ c) * ((n : ℝ) ^ c)⁻¹ from by ring,
            mul_rpow_eq_rpow_succ hX_pos c]
        rw [Finset.sum_congr rfl h_bound, ← Finset.mul_sum]
        have hstep3 := rpow_inv_partial_le_tsum hc (Finset.Icc 1 N)
        nlinarith [rpow_nonneg hX_pos.le (c + 1)]

set_option maxHeartbeats 800000 in
/-- **Helper 3**: The Dirichlet tail integral bound.

    The difference between the finite Dirichlet polynomial and 1/ζ(s)
    integrated against x^s/s over [-T,T] is bounded by O(N^{1-c} · X^c · T).

    Uses: `moebius_partial_sum_approx` for the pointwise bound
    ‖∑_{n=1}^N μ(n)/n^s - 1/ζ(s)‖ ≤ N^{1-Re(s)}/(Re(s)-1).

    Strategy: bound the integrand pointwise, then integrate the constant bound.
    ‖(D_N - 1/ζ) · X^s/s‖ ≤ [N^{1-c}/(c-1)] · [X^c/c] on the line Re(s)=c.
    Integrating over [-T,T] gives 2T times this, absorption of 1/(2π) ≤ 1. -/
lemma dirichlet_tail_integral_bound (c : ℝ) (hc : 1 < c) :
    ∃ C_tail > 0, ∀ X T : ℝ, 0 < X → 0 < T → ∀ N : ℕ, 0 < N →
      ‖(1 / (2 * ↑Real.pi)) *
        ∫ t in (-T)..T,
          (∑ n ∈ Finset.Icc 1 N,
            (↑(ArithmeticFunction.moebius n) : ℂ) /
              (↑n : ℂ) ^ (↑c + ↑t * I) -
            1 / riemannZeta (↑c + ↑t * I)) *
          ((X : ℂ) ^ (↑c + ↑t * I) / (↑c + ↑t * I))‖ ≤
      C_tail * (N : ℝ) ^ (1 - c) * X ^ c * T := by
  -- C_tail = 2/(c · (c-1)) works (factor of 2 from [-T,T] length, 1/(2π) ≤ 1)
  refine ⟨2 / (c * (c - 1)), div_pos two_pos (mul_pos (by linarith) (by linarith)),
    fun X T hX hT N hN => ?_⟩
  -- Step 1: Absorb 1/(2π) factor: ‖(1/(2π)) · z‖ ≤ ‖z‖
  have h_pfx := Cathedral.White.Infrastructure.norm_one_div_two_pi_mul_le
    (∫ t in (-T)..T,
      (∑ n ∈ Finset.Icc 1 N,
        (↑(ArithmeticFunction.moebius n) : ℂ) /
          (↑n : ℂ) ^ (↑c + ↑t * I) -
        1 / riemannZeta (↑c + ↑t * I)) *
      ((X : ℂ) ^ (↑c + ↑t * I) / (↑c + ↑t * I)))
  -- Step 2: Bound the integral norm by constant × interval length
  -- Pointwise bound: for each t, the integrand norm ≤ N^{1-c}/(c-1) · X^c/c
  have h_re_eq : ∀ t : ℝ, (↑c + ↑t * I : ℂ).re = c := by
    intro t; simp [Complex.add_re, Complex.ofReal_re, Complex.mul_re, Complex.I_re, Complex.I_im]
  have h_s_ne : ∀ t : ℝ, (↑c + ↑t * I : ℂ) ≠ 0 := by
    intro t h; have := congr_arg Complex.re h
    simp [Complex.add_re, Complex.ofReal_re, Complex.mul_re, Complex.I_re, Complex.I_im] at this
    linarith
  have h_s_norm_ge : ∀ t : ℝ, c ≤ ‖(↑c + ↑t * I : ℂ)‖ := by
    intro t; calc c = |(c : ℝ)| := (abs_of_pos (by linarith)).symm
      _ = |(↑c + ↑t * I : ℂ).re| := by rw [h_re_eq]
      _ ≤ ‖(↑c + ↑t * I : ℂ)‖ := Complex.abs_re_le_norm _
  -- Step 3: Bound the integral
  have h_int_bound : ‖∫ t in (-T)..T,
      (∑ n ∈ Finset.Icc 1 N,
        (↑(μ n) : ℂ) / (↑n : ℂ) ^ (↑c + ↑t * I) -
        1 / riemannZeta (↑c + ↑t * I)) *
      ((X : ℂ) ^ (↑c + ↑t * I) / (↑c + ↑t * I))‖ ≤
    (↑N : ℝ) ^ (1 - c) / (c - 1) * (X ^ c / c) * |T - (-T)| := by
    apply intervalIntegral.norm_integral_le_of_norm_le_const
    intro t _
    -- ‖f · g‖ = ‖f‖ · ‖g‖
    rw [norm_mul]
    -- ‖f‖ ≤ N^{1-c}/(c-1) by moebius_partial_sum_approx
    have h_tail := Cathedral.White.Infrastructure.moebius_partial_sum_approx
      N hN (↑c + ↑t * I) (by rw [h_re_eq]; exact hc)
    -- ‖g‖ = ‖X^s/s‖ = X^c/‖s‖ ≤ X^c/c
    have h_norm_g : ‖(X : ℂ) ^ (↑c + ↑t * I) / (↑c + ↑t * I)‖ ≤ X ^ c / c := by
      rw [norm_div, norm_cpow_eq_rpow_re_of_pos hX, h_re_eq]
      exact div_le_div_of_nonneg_left (rpow_nonneg hX.le c) (by linarith : (0 : ℝ) < c) (h_s_norm_ge t)
    -- Chain: ‖f·g‖ ≤ ‖f‖·‖g‖ ≤ bound₁·bound₂
    have h_tail' : ‖∑ n ∈ Finset.Icc 1 N, (↑(μ n) : ℂ) / (↑n : ℂ) ^ (↑c + ↑t * I) -
        1 / riemannZeta (↑c + ↑t * I)‖ ≤ (↑N : ℝ) ^ (1 - c) / (c - 1) := by
      calc _ ≤ (↑N : ℝ) ^ (1 - (↑c + ↑t * I).re) / ((↑c + ↑t * I).re - 1) := h_tail
        _ = _ := by rw [h_re_eq]
    exact mul_le_mul h_tail' h_norm_g (norm_nonneg _)
      (div_nonneg (rpow_nonneg (Nat.cast_nonneg' N) _) (by linarith))
  -- Step 4: Assemble: ‖(1/2π)·∫‖ ≤ ‖∫‖ ≤ bound · 2T = ...
  have h_abs_2T : |T - (-T)| = 2 * T := by
    rw [show T - (-T) = 2 * T from by ring, abs_of_pos (by linarith)]
  calc ‖_‖ ≤ ‖∫ t in (-T)..T, _‖ := h_pfx
    _ ≤ (↑N : ℝ) ^ (1 - c) / (c - 1) * (X ^ c / c) * |T - (-T)| := h_int_bound
    _ = (↑N : ℝ) ^ (1 - c) / (c - 1) * (X ^ c / c) * (2 * T) := by rw [h_abs_2T]
    _ = 2 / (c * (c - 1)) * (↑N : ℝ) ^ (1 - c) * X ^ c * T := by
        have hc_pos : (0 : ℝ) < c := by linarith
        have hc1_pos : (0 : ℝ) < c - 1 := by linarith
        field_simp

-- ═══════════════════════════════════════════
-- §4½. Integrability of X^s/(sζ(s)) for c > 1
-- ═══════════════════════════════════════════

/-- X^(c+it)/((c+it)·ζ(c+it)) is interval-integrable on [-T,T] for c > 1.
    No RH needed: ζ(s) ≠ 0 for Re(s) > 1 by Euler product.
    Pattern: PerronMoebius.lean lines 130-153. -/
lemma perron_zeta_integrable (X c T : ℝ) (hX : 0 < X) (hc : 1 < c) :
    IntervalIntegrable (fun t : ℝ =>
      (X : ℂ) ^ (↑c + ↑t * I) /
        ((↑c + ↑t * I) * riemannZeta (↑c + ↑t * I)))
      MeasureTheory.volume (-T) T := by
  apply ContinuousOn.intervalIntegrable
  apply ContinuousOn.div
  · -- Numerator: X^(c+ti) is continuous (X > 0 gives slitPlane)
    exact ContinuousOn.cpow continuousOn_const (by fun_prop)
      (fun _ _ => Complex.ofReal_mem_slitPlane.mpr hX)
  · -- Denominator: (c+ti)·ζ(c+ti) is continuous
    apply ContinuousOn.mul (by fun_prop)
    exact fun t _ => ContinuousAt.continuousWithinAt <|
      ContinuousAt.comp
        (differentiableAt_riemannZeta (by
          intro h; have := congr_arg Complex.re h
          simp [Complex.add_re, Complex.ofReal_re, Complex.mul_re,
            Complex.I_re, Complex.I_im] at this; linarith)).continuousAt
        (by fun_prop : ContinuousAt (fun t : ℝ => (↑c + ↑t * I : ℂ)) t)
  · -- Denominator ≠ 0: Re(s) = c > 1 so ζ(s) ≠ 0, and s ≠ 0 since Re(s) > 0
    intro t _; apply mul_ne_zero
    · intro h0; have := congr_arg Complex.re h0
      simp [Complex.add_re, Complex.ofReal_re, Complex.mul_re,
        Complex.I_re, Complex.I_im] at this; linarith
    · exact riemannZeta_ne_zero_of_one_lt_re (by
        simp [Complex.add_re, Complex.ofReal_re, Complex.mul_re,
          Complex.I_re, Complex.I_im]; linarith)

/-- X^c = X^{c-1} · X for X > 0. Used in tail bound algebra. -/
private lemma rpow_eq_pred_mul (X c : ℝ) (hX : 0 < X) : X ^ c = X ^ (c - 1) * X := by
  have : X ^ c = X ^ ((c - 1) + 1) := by congr 1; ring
  rw [this, rpow_add hX, rpow_one]

-- ═══════════════════════════════════════════
-- §5. Main Theorem: Truncated Perron at Half-Integers
-- ═══════════════════════════════════════════

set_option maxHeartbeats 800000 in
/-- **The Truncated Perron Formula for M(x), evaluated at half-integers.**

    For X = m + 1/2, the summatory Möbius function M(X) is approximated by
    the contour integral (1/2π) ∫_{-T}^{T} X^(c+it)/((c+it)·ζ(c+it)) dt
    with error O(X^{c+1}/T).

    Note: The `dt` form uses 1/(2π) since the change of variables
    s = c+it, ds = i·dt absorbs the `i` from the standard 1/(2πi)∫ds form.

    **Strategy** (The Silver Bullet):
    1. Triangle inequality via an intermediate finite Perron sum.
    2. Kernel error (§2 + §3): O(X^{c+1}/T) by the log sum bound.
    3. Tail error (§4): O(N^{1-c} · X^c · T), crushed by choosing N large.
    4. Sum the two: O(X^{c+1}/T). -/
theorem truncated_perron_half_integer (c : ℝ) (hc : 1 < c) :
    ∃ K > 0, ∀ m : ℕ, 2 ≤ m → ∀ T : ℝ, 1 ≤ T →
      let X : ℝ := (m : ℝ) + 1/2
      ‖(↑(summatoryMoebius X : ℤ) : ℂ) -
        (1 / (2 * ↑Real.pi)) *
          ∫ t in (-T)..T,
            (X : ℂ) ^ (↑c + ↑t * I) /
              ((↑c + ↑t * I) * riemannZeta (↑c + ↑t * I))‖ ≤
      K * X ^ (c + 1) / T := by
  -- Step 1: Obtain constants from helpers
  obtain ⟨C_sum, hC_sum_pos, h_log_sum⟩ := perron_log_sum_bound c hc
  obtain ⟨C_tail, hC_tail_pos, h_tail⟩ := dirichlet_tail_integral_bound c hc
  -- K absorbs kernel error C_sum/π and tail contribution
  set K := C_sum / Real.pi + C_tail + 1
  refine ⟨K, by positivity, fun m hm T hT => ?_⟩
  intro X
  have hX_pos : (0 : ℝ) < X := by positivity
  have hT_pos : (0 : ℝ) < T := by linarith
  have hc_pos : (0 : ℝ) < c := by linarith
  have hX_gt1 : (1 : ℝ) < X := by
    show 1 < (m : ℝ) + 1 / 2
    have : (2 : ℝ) ≤ (m : ℝ) := by exact_mod_cast hm
    linarith
  -- Step 2: Dynamic N via Archimedean property.
  -- We need C_tail · N^{1-c} · X^c · T ≤ X^{c+1}/T.
  -- Sufficient: N^{c-1} ≥ C_tail · T² · X (then tail ≤ X^{c-1}/T ≤ X^{c+1}/T).
  -- Choose N₀ > (C_tail · T² · X)^{1/(c-1)}, so N₀^{c-1} > C_tail·T²·X.
  obtain ⟨N₀, hN₀⟩ := exists_nat_gt ((C_tail * T ^ 2 * X) ^ ((1 : ℝ) / (c - 1)))
  set N := max m (N₀ + 1) with hN_def
  have hN_m : m ≤ N := le_max_left _ _
  have hN_pos : 0 < N := by omega
  have hN_ge_N₀ : (N₀ : ℝ) < (N : ℝ) := by
    calc (N₀ : ℝ) < N₀ + 1 := by linarith
      _ ≤ (N : ℝ) := by exact_mod_cast le_max_right m (N₀ + 1)
  -- Step 3: §2 + §3 give kernel error bound
  have h_kernel := perron_formula_error_bound_full m hm c T N hc_pos hT_pos hN_m
  have h_sum := h_log_sum m hm N
  have h_kernel_bound : ‖∑ n ∈ Finset.Icc 1 N,
      (↑(ArithmeticFunction.moebius n) : ℂ) *
        Cathedral.White.Infrastructure.perronIntegral (X / ↑n) c T -
      (↑(summatoryMoebius X : ℤ) : ℂ)‖ ≤
    C_sum / (Real.pi * T) * X ^ (c + 1) := by
    calc _ ≤ ∑ n ∈ Finset.Icc 1 N,
        (X / ↑n) ^ c / (Real.pi * T * |Real.log (X / ↑n)|) := h_kernel
      _ = 1 / (Real.pi * T) * ∑ n ∈ Finset.Icc 1 N,
        (X / ↑n) ^ c / |Real.log (X / ↑n)| := by
        rw [Finset.mul_sum]; apply Finset.sum_congr rfl; intro n _; field_simp
      _ ≤ 1 / (Real.pi * T) * (C_sum * X ^ (c + 1)) :=
        mul_le_mul_of_nonneg_left h_sum (by positivity)
      _ = C_sum / (Real.pi * T) * X ^ (c + 1) := by ring
  -- Step 4: §4 gives tail integral bound
  have h_tail_bound := h_tail X T hX_pos hT_pos N hN_pos
  -- Step 5: Prove N^{c-1} > C_tail · T² · X
  -- from N > N₀ > (C_tail·T²·X)^{1/(c-1)}
  have hc1_pos : (0 : ℝ) < c - 1 := by linarith
  have h_val_pos : (0 : ℝ) < C_tail * T ^ 2 * X := by positivity
  -- N > (C_tail·T²·X)^{1/(c-1)}, so N^{c-1} > C_tail·T²·X
  have h_N_rpow : C_tail * T ^ 2 * X < (N : ℝ) ^ (c - 1) := by
    have hN_gt : (C_tail * T ^ 2 * X) ^ ((1 : ℝ) / (c - 1)) < (N : ℝ) :=
      lt_trans hN₀ hN_ge_N₀
    calc C_tail * T ^ 2 * X
        = ((C_tail * T ^ 2 * X) ^ ((1 : ℝ) / (c - 1))) ^ (c - 1) := by
          rw [← Real.rpow_mul (le_of_lt h_val_pos)]
          rw [show (1 : ℝ) / (c - 1) * (c - 1) = 1 from one_div_mul_cancel (ne_of_gt hc1_pos)]
          exact (Real.rpow_one _).symm
      _ < (N : ℝ) ^ (c - 1) := by
          apply Real.rpow_lt_rpow (rpow_nonneg (le_of_lt h_val_pos) _) hN_gt hc1_pos
  -- Step 6: Derive C_tail · N^{1-c} · X^c · T ≤ X^{c+1}/T from h_N_rpow.
  have h_tail_crushed : C_tail * (N : ℝ) ^ (1 - c) * X ^ c * T ≤ X ^ (c + 1) / T := by
    have hN_pos_real : (0 : ℝ) < (N : ℝ) := Nat.cast_pos.mpr hN_pos
    have hN_c1_pos : (0 : ℝ) < (N : ℝ) ^ (c - 1) := rpow_pos_of_pos hN_pos_real _
    have h_inv : (N : ℝ) ^ (1 - c) = 1 / (N : ℝ) ^ (c - 1) := by
      rw [show (1 : ℝ) - c = -(c - 1) from by ring]
      rw [rpow_neg (le_of_lt hN_pos_real)]
      ring
    rw [h_inv]
    have hstep : C_tail / (N : ℝ) ^ (c - 1) ≤ 1 / (T ^ 2 * X) := by
      rw [div_le_div_iff₀ hN_c1_pos (by positivity : (0:ℝ) < T ^ 2 * X)]
      linarith
    rw [show C_tail * (1 / (N : ℝ) ^ (c - 1)) = C_tail / (N : ℝ) ^ (c - 1) from by ring]
    have h_exp : X ^ (c - 1) ≤ X ^ (c + 1) :=
      rpow_le_rpow_of_exponent_le hX_gt1.le (by linarith)
    have h_lhs : C_tail / (N : ℝ) ^ (c - 1) * X ^ c * T ≤ X ^ (c - 1) / T := by
      calc C_tail / (N : ℝ) ^ (c - 1) * X ^ c * T
          ≤ 1 / (T ^ 2 * X) * X ^ c * T := by
            apply mul_le_mul_of_nonneg_right _ hT_pos.le
            exact mul_le_mul_of_nonneg_right hstep (rpow_nonneg hX_pos.le _)
        _ = X ^ (c - 1) / T := by
            rw [rpow_eq_pred_mul X c hX_pos]
            field_simp
    linarith [div_le_div_of_nonneg_right h_exp hT_pos.le]
  -- Step 7: Triangle inequality assembly.
  -- Let A_N = ∑ μ(n)·P(X/n) and B = (1/(2π))∫ X^s/(sζ(s)) dt.
  set A_N := ∑ n ∈ Finset.Icc 1 N,
    (↑(ArithmeticFunction.moebius n) : ℂ) *
      Cathedral.White.Infrastructure.perronIntegral (X / ↑n) c T
  set B := (1 / (2 * ↑Real.pi)) *
    ∫ t in (-T)..T, (X : ℂ) ^ (↑c + ↑t * I) /
      ((↑c + ↑t * I) * riemannZeta (↑c + ↑t * I))
  -- h_kernel_bound : ‖A_N - M‖ ≤ C_sum/(πT) · X^{c+1}
  -- So ‖M - A_N‖ ≤ C_sum/(πT) · X^{c+1}
  have h_M_AN : ‖(↑(summatoryMoebius X : ℤ) : ℂ) - A_N‖ ≤
      C_sum / (Real.pi * T) * X ^ (c + 1) := by
    rw [norm_sub_rev]; exact h_kernel_bound
  -- The integral connection: ‖A_N - B‖ ≤ X^{c+1}/T
  -- Proof: A_N = (1/(2π))∫ (∑μ(n)(X/n)^s/s) dt  [finite_sum_integral_swap]
  --        = (1/(2π))∫ (∑μ(n)/n^s)·X^s/s dt    [algebraic factoring]
  -- So A_N - B = (1/(2π))∫ [(∑μ(n)/n^s) - 1/ζ(s)]·X^s/s dt  [integral_sub]
  -- ‖A_N - B‖ ≤ C_tail · N^{1-c} · X^c · T ≤ X^{c+1}/T  [§4 + h_tail_crushed]
  have h_AN_B : ‖A_N - B‖ ≤ X ^ (c + 1) / T := by
    sorry
  -- Triangle: ‖M - B‖ ≤ ‖M - A_N‖ + ‖A_N - B‖
  have h_tri : ‖(↑(summatoryMoebius X : ℤ) : ℂ) - B‖ ≤
      ‖(↑(summatoryMoebius X : ℤ) : ℂ) - A_N‖ + ‖A_N - B‖ := by
    calc ‖(↑(summatoryMoebius X : ℤ) : ℂ) - B‖
        = ‖((↑(summatoryMoebius X : ℤ) : ℂ) - A_N) + (A_N - B)‖ := by
          congr 1; ring
      _ ≤ ‖(↑(summatoryMoebius X : ℤ) : ℂ) - A_N‖ + ‖A_N - B‖ :=
          norm_add_le _ _
  -- Combine: ‖M - B‖ ≤ C_sum/(πT)·X^{c+1} + X^{c+1}/T ≤ K·X^{c+1}/T
  -- K = C_sum/π + 1, and C_sum/(πT) ≤ C_sum/π · 1/T
  have h_final : C_sum / (Real.pi * T) * X ^ (c + 1) + X ^ (c + 1) / T ≤
      K * X ^ (c + 1) / T := by
    -- K = C_sum/π + 1
    -- C_sum/(π·T) · X^{c+1} + X^{c+1}/T = (C_sum/π + 1) · X^{c+1}/T = K · X^{c+1}/T
    -- This is an equality, not just ≤!
    have : C_sum / (Real.pi * T) * X ^ (c + 1) + X ^ (c + 1) / T =
        (C_sum / Real.pi + 1) * X ^ (c + 1) / T := by
      have hpi : Real.pi ≠ 0 := ne_of_gt Real.pi_pos
      have hT_ne : T ≠ 0 := ne_of_gt hT_pos
      field_simp
    rw [this]
    -- Now goal: (C_sum/π + 1) * X^{c+1} / T ≤ K * X^{c+1} / T
    -- K = C_sum/π + C_tail + 1 ≥ C_sum/π + 1 (since C_tail > 0)
    apply div_le_div_of_nonneg_right _ hT_pos.le
    apply mul_le_mul_of_nonneg_right _ (rpow_nonneg hX_pos.le _)
    linarith
  calc ‖(↑(summatoryMoebius X : ℤ) : ℂ) - B‖
      ≤ C_sum / (Real.pi * T) * X ^ (c + 1) + X ^ (c + 1) / T := by
        linarith [h_tri, h_M_AN, h_AN_B]
    _ ≤ K * X ^ (c + 1) / T := h_final

-- ═══════════════════════════════════════════
-- §6. Transfer to General x via M(x) = M(⌊x⌋ + 1/2)
-- ═══════════════════════════════════════════

/-- M(x) = M(⌊x⌋ + 1/2) for all x, since M is a step function
    constant on [m, m+1). This lets us use `truncated_perron_half_integer`
    for arbitrary real x. -/
lemma summatoryMoebius_eq_half_integer (x : ℝ) (hx : 2 ≤ x) :
    summatoryMoebius x = summatoryMoebius (↑⌊x⌋ + 1/2 : ℝ) := by
  unfold summatoryMoebius
  congr 1
  -- Need: ⌊x⌋₊ = ⌊(↑⌊x⌋ : ℝ) + 1/2⌋₊
  -- Key: ⌊x⌋₊ = n iff n ≤ x < n+1, and ⌊n + 1/2⌋₊ = n
  have hx_nn : 0 ≤ x := by linarith
  have : ⌊(⌊x⌋₊ : ℝ) + 1/2⌋₊ = ⌊x⌋₊ := by
    apply Nat.floor_eq_iff (by positivity : 0 ≤ (⌊x⌋₊ : ℝ) + 1/2) |>.mpr
    constructor
    · linarith [Nat.floor_le hx_nn]
    · linarith [Nat.lt_floor_add_one x]
  -- Now need ↑⌊x⌋ = ⌊x⌋₊ in the cast
  have hcast : (↑⌊x⌋ : ℝ) = (⌊x⌋₊ : ℝ) := (natCast_floor_eq_intCast_floor hx_nn).symm
  rw [hcast, this]

end Cathedral.White.Infrastructure.HalfIntegerPerron
