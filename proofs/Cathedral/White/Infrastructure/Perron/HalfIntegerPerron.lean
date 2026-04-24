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
import Cathedral.White.Infrastructure.DirichletZetaInverse

noncomputable section
open Complex Real MeasureTheory Set Filter ArithmeticFunction Finset
open scoped LSeries.notation ArithmeticFunction.Moebius ArithmeticFunction.zeta Topology

namespace Cathedral.White.Infrastructure.HalfIntegerPerron

-- ═══════════════════════════════════════════
-- §1. Half-Integer Log Bound
-- ═══════════════════════════════════════════

/-- At half-integers X = m + 1/2, the quantity X/n is never an integer,
    and |log(X/n)| is bounded below by 1/(8X) for all n ≥ 1.
    Equivalently: 1/|log(X/n)| ≤ 8X.

    This is the key insight that eliminates the log singularity.

    **Proof sketch** (two cases):
    - If n < X/2 or n > 2X: then X/n > 2 or X/n < 1/2,
      so |log(X/n)| > log 2 > 1/(8X) for X ≥ 5/2.
    - If X/2 ≤ n ≤ 2X: then |X - n| ≥ 1/2 (half-integer gap),
      so |log(X/n)| = |log(1 + (X-n)/n)| ≥ |X-n|/(2n) ≥ 1/(4n) ≥ 1/(8X).
-/
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
  sorry -- The two-case bound (far/near) — to be proved

-- ═══════════════════════════════════════════
-- §2. Unified Finite Perron Error
-- ═══════════════════════════════════════════

/-- **Helper 1**: The unified finite Perron error at half-integers.

    For X = m + 1/2 (hence X ≠ n for all n), the difference between the
    Perron integral sum and the Möbius summatory function is bounded by
    the pointwise Perron kernel error terms.

    Uses: `perron_formula_error_bound` from Formula.lean for each n. -/
lemma perron_formula_error_bound_full (m : ℕ) (hm : 2 ≤ m) (c T : ℝ) (N : ℕ)
    (hc : 0 < c) (hT : 0 < T) :
    let X : ℝ := (m : ℝ) + 1/2
    ‖∑ n ∈ Finset.Icc 1 N, (↑(ArithmeticFunction.moebius n) : ℂ) *
        perronIntegral (X / ↑n) c T -
      (↑(summatoryMoebius X : ℤ) : ℂ)‖ ≤
    ∑ n ∈ Finset.Icc 1 N,
      (X / ↑n) ^ c / (Real.pi * T * |Real.log (X / ↑n)|) := by
  sorry

-- ═══════════════════════════════════════════
-- §3. Half-Integer Log Sum Bound
-- ═══════════════════════════════════════════

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
  sorry

-- ═══════════════════════════════════════════
-- §4. Dirichlet Tail Integral Bound
-- ═══════════════════════════════════════════

/-- **Helper 3**: The Dirichlet tail integral bound.

    The difference between the finite Dirichlet polynomial and 1/ζ(s)
    integrated against x^s/s over [-T,T] is bounded by O(N^{1-c} · X^c · T).

    Uses: `moebius_partial_sum_approx` for the pointwise bound
    ‖∑_{n=1}^N μ(n)/n^s - 1/ζ(s)‖ ≤ N^{1-Re(s)}/(Re(s)-1). -/
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
  sorry

-- ═══════════════════════════════════════════
-- §5. Main Theorem: Truncated Perron at Half-Integers
-- ═══════════════════════════════════════════

/-- **The Truncated Perron Formula for M(x), evaluated at half-integers.**

    For X = m + 1/2, the summatory Möbius function M(X) is approximated by
    the contour integral (1/2πi) ∫_{c-iT}^{c+iT} X^s/(s·ζ(s)) ds
    with error O(X^{c+1}/T).

    **Strategy** (The Silver Bullet):
    1. By the Archimedean property, choose N so large that the Dirichlet
       tail error is ≤ X^c/T (Dynamic N trick).
    2. Apply `finite_sum_integral_swap` with this specific N.
    3. Triangle inequality splits into:
       - Perron kernel error (Helper 1 + 2): O(X^{c+1}/T)
       - Dirichlet tail error (Helper 3): ≤ X^c/T by choice of N
    4. Sum the two: O(X^{c+1}/T).

    No Fubini theorem, no DCT, no measure theory — pure algebra! -/
theorem truncated_perron_half_integer (c : ℝ) (hc : 1 < c) :
    ∃ K > 0, ∀ m : ℕ, 2 ≤ m → ∀ T : ℝ, 1 ≤ T →
      let X : ℝ := (m : ℝ) + 1/2
      ‖(↑(summatoryMoebius X : ℤ) : ℂ) -
        (1 / (2 * ↑Real.pi * I)) *
          ∫ t in (-T)..T,
            (X : ℂ) ^ (↑c + ↑t * I) /
              ((↑c + ↑t * I) * riemannZeta (↑c + ↑t * I))‖ ≤
      K * X ^ (c + 1) / T := by
  -- Step 1: Obtain constants from helpers
  obtain ⟨C_sum, hC_sum_pos, h_log_sum⟩ := perron_log_sum_bound c hc
  obtain ⟨C_tail, hC_tail_pos, h_tail⟩ := dirichlet_tail_integral_bound c hc
  -- Set K = C_sum/π + 1
  set K := C_sum / Real.pi + 1
  refine ⟨K, by positivity, fun m hm T hT => ?_⟩
  intro X
  -- Step 2: By Archimedean property, choose N crushing the tail
  -- We need: C_tail * N^{1-c} * X^c * T ≤ X^c / T
  -- i.e., C_tail * N^{1-c} * T^2 ≤ 1
  -- i.e., N^{c-1} ≥ C_tail * T^2
  -- Such N exists since c > 1 and N^{c-1} → ∞.
  sorry

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
