import Mathlib.NumberTheory.LSeries.Dirichlet

/-!
  # The Dirichlet Series for 1/ζ(s)

  Establishes `L(μ, s) = 1/ζ(s)` for `Re(s) > 1` from Mathlib's
  Dirichlet convolution identity `ζ · μ = 1`.

  ## Main Results

  * `moebius_lseries_eq_inv_zeta` : `L(μ, s) = 1/ζ(s)` for `Re(s) > 1`
  * `moebius_lseries_summable` : absolute convergence for `Re(s) > 1`
  * `summatoryMoebius_le` : `|M(x)| ≤ x` (trivial bound)
-/

noncomputable section
open Complex Real ArithmeticFunction BigOperators

-- access notation
open scoped LSeries.notation ArithmeticFunction.Moebius ArithmeticFunction.zeta

namespace Cathedral.Zeta

-- ═══════════════════════════════════════════
-- §1. L(μ, s) = 1/ζ(s)
-- ═══════════════════════════════════════════

/-- The L-series of the Möbius function is the reciprocal of ζ(s).

    `∑ μ(n)/n^s = 1/ζ(s)` for `Re(s) > 1`.
    From Mathlib's `LSeries_zeta_mul_Lseries_moebius`. -/
theorem moebius_lseries_eq_inv_zeta {s : ℂ} (hs : 1 < s.re) :
    LSeries (↗μ) s = 1 / riemannZeta s := by
  have hζ_ne : riemannZeta s ≠ 0 := riemannZeta_ne_zero_of_one_lt_re hs
  have h_prod := LSeries_zeta_mul_Lseries_moebius hs
  rw [LSeries_zeta_eq_riemannZeta hs] at h_prod
  -- h_prod : ζ(s) * L(μ,s) = 1
  -- Therefore L(μ,s) = 1/ζ(s)
  rw [one_div]
  exact mul_left_cancel₀ hζ_ne (by rw [mul_inv_cancel₀ hζ_ne]; exact h_prod)

/-- The Möbius L-series converges absolutely for `Re(s) > 1`. -/
theorem moebius_lseries_summable {s : ℂ} (hs : 1 < s.re) :
    LSeriesSummable (↗μ) s :=
  LSeriesSummable_moebius_iff.mpr hs

/-- `ζ(s) ≠ 0` for `Re(s) > 1`. -/
theorem zeta_ne_zero_of_re_gt_one {s : ℂ} (hs : 1 < s.re) :
    riemannZeta s ≠ 0 :=
  riemannZeta_ne_zero_of_one_lt_re hs

-- ═══════════════════════════════════════════
-- §2. The Summatory Möbius Function
-- ═══════════════════════════════════════════

/-- The summatory Möbius function M(x) = ∑_{n ≤ x} μ(n). -/
def summatoryMoebius (x : ℝ) : ℤ :=
  ∑ n ∈ Finset.Icc 1 ⌊x⌋₊, μ n

/-- M(x) is bounded by x (trivially). -/
lemma summatoryMoebius_le (x : ℝ) (hx : 0 < x) :
    |((summatoryMoebius x : ℤ) : ℝ)| ≤ x := by
  unfold summatoryMoebius
  -- |Σ μ(n)| ≤ Σ |μ(n)| ≤ card(Icc) ≤ ⌊x⌋₊ ≤ x
  -- Key fact: |μ(n)| ≤ 1 for all n
  have h_abs_moeb : ∀ n : ℕ, |((μ n : ℤ) : ℝ)| ≤ 1 := by
    intro n
    -- μ(n) ∈ {-1, 0, 1}, so |μ(n)| ∈ {0, 1}
    by_cases hn : Squarefree n
    · -- μ(n) = (-1)^(cardFactors n), so |μ(n)| = 1
      have := ArithmeticFunction.moebius_apply_of_squarefree hn
      rw [this]; push_cast
      simp [abs_pow, abs_neg, abs_one]
    · -- μ(n) = 0
      simp only [ArithmeticFunction.moebius_eq_zero_of_not_squarefree hn, Int.cast_zero, abs_zero]
      exact zero_le_one
  -- Now chain the bounds
  rw [show ((∑ n ∈ Finset.Icc 1 ⌊x⌋₊, μ n : ℤ) : ℝ) =
      ∑ n ∈ Finset.Icc 1 ⌊x⌋₊, ((μ n : ℤ) : ℝ) from by push_cast; rfl]
  calc |∑ n ∈ Finset.Icc 1 ⌊x⌋₊, ((μ n : ℤ) : ℝ)|
      ≤ ∑ n ∈ Finset.Icc 1 ⌊x⌋₊, |((μ n : ℤ) : ℝ)| := Finset.abs_sum_le_sum_abs _ _
    _ ≤ ∑ _n ∈ Finset.Icc 1 ⌊x⌋₊, (1 : ℝ) :=
        Finset.sum_le_sum (fun n _ => h_abs_moeb n)
    _ = (Finset.Icc 1 ⌊x⌋₊).card := by simp
    _ ≤ ⌊x⌋₊ := by simp [Nat.card_Icc]
    _ ≤ x := Nat.floor_le (le_of_lt hx)

/-  **COROLLARY**: By Perron's formula (once proved),
    M(x) = (1/2πi) ∫_{c-iT}^{c+iT} x^s / (s·ζ(s)) ds + O(x^c/T)

    This follows from:
    1. perron_formula_from_kernel with a(n) = μ(n)
    2. ∑ μ(n)/n^s = 1/ζ(s) (moebius_lseries_eq_inv_zeta above)
    3. Absolute convergence for c > 1 (moebius_lseries_summable above)

    The contour shift from Re(s) = c to Re(s) = 1/2 + ε then gives
    M(x) = O(x^{1/2+ε}) under RH. -/

end Cathedral.Zeta
