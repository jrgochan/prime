/-
  Cathedral/Zeta/ZetaTailBound.lean

  ## Zeta Tail Bound via Dirichlet Series

  An independent, elementary proof that `‖ζ(s) - 1‖ < 1` for `Re(s) ≥ 2`,
  using the Dirichlet series representation and comparison with
  `ζ(2) - 1 = π²/6 - 1 ≈ 0.645 < 1`.

  ### Strategy
  1. Write ζ(s) = 1 + ∑_{n≥0} 1/(n+2)^s  (split off n=0 term)
  2. Triangle inequality: ‖∑ 1/(n+2)^s‖ ≤ ∑ 1/(n+2)^{Re s}
  3. Monotonicity: ≤ ∑ 1/(n+2)^2 for Re(s) ≥ 2
  4. Evaluation: ∑ 1/(n+2)^2 = ζ(2) - 1 = π²/6 - 1
  5. Numerical: π² < 12 (from Mathlib's `pi_lt_d4`), so π²/6 - 1 < 1

  ### Relation to ZetaDiskBounds
  `ZetaDiskBounds.lean` proves the stronger `‖ζ(s) - 1‖ ≤ 3/4` via the
  `riemannZetaSummandHom` API. This file provides an independent proof path
  using only `zeta_eq_tsum_one_div_nat_add_one_cpow` and `hasSum_zeta_two`,
  which may be useful when the summand API is unavailable.

  ### Dependencies: Mathlib (ζ, ζ(2), π bounds, infinite sums).
-/

import Mathlib.NumberTheory.LSeries.RiemannZeta
import Mathlib.NumberTheory.ZetaValues
import Mathlib.Analysis.Normed.Group.InfiniteSum
import Mathlib.Analysis.Real.Pi.Bounds

set_option maxHeartbeats 800000

noncomputable section
open Complex Real Nat

namespace Cathedral.Zeta.TailBound

/-!
# Zeta Tail Bound: `‖ζ(s) - 1‖ < 1` for `Re(s) ≥ 2`

This file proves that `‖ζ(s) - 1‖ < 1` when `Re(s) ≥ 2`, using the Dirichlet
series representation and comparison with `ζ(2) - 1 = π²/6 - 1 ≈ 0.645 < 1`.

## Main results

* `zeta_sub_one_norm_lt_one` : `‖ζ(s) - 1‖ < 1` for `Re(s) ≥ 2`
-/

/-- `π² < 12`; from `π < 3.1416` (Mathlib: `pi_lt_d4`). -/
private lemma pi_sq_lt_twelve : π ^ 2 < 12 := by
  nlinarith [pi_lt_d4, pi_pos, sq_nonneg (3.1416 - π)]

/-- The tail sum `∑_{n≥0} 1/(n+2)^2 < 1`.
    Proof: equals `ζ(2) - 1 = π²/6 - 1 ≈ 0.645 < 1`. -/
private lemma tsum_tail_inv_sq_lt_one :
    ∑' (n : ℕ), (1 : ℝ) / ((n : ℝ) + 2) ^ 2 < 1 := by
  have hsumm := hasSum_zeta_two.summable
  have h_val := hasSum_zeta_two.tsum_eq
  have h1 := hsumm.tsum_eq_zero_add
  have h0 : (1 : ℝ) / (0 : ℕ) ^ 2 = 0 := by norm_num
  have hsumm1 := (summable_nat_add_iff 1).mpr hsumm
  -- Bridge between ↑(n+2) and (n : ℝ) + 2 cast forms
  have hconv : ∀ k : ℕ, (1 : ℝ) / (↑(k + 2)) ^ 2 = 1 / ((k : ℝ) + 2) ^ 2 := by
    intro k; simp only [Nat.cast_add, Nat.cast_ofNat]
  have h_val1 : ∑' (n : ℕ), (1 : ℝ) / (↑(n + 1)) ^ 2 = π ^ 2 / 6 := by
    linarith [h1, h_val, h0]
  have h2 := hsumm1.tsum_eq_zero_add
  have h1v : (1 : ℝ) / (↑((0 : ℕ) + 1)) ^ 2 = 1 := by norm_num
  -- ∑ 1/(↑(n+2))^2 = π²/6 - 1
  have h_tail : ∑' (n : ℕ), (1 : ℝ) / (↑(n + 2)) ^ 2 = π ^ 2 / 6 - 1 := by
    linarith [h2, h_val1, h1v]
  -- Convert to our form and conclude
  rw [show (fun n : ℕ => (1 : ℝ) / ((n : ℝ) + 2) ^ 2) =
    (fun n : ℕ => (1 : ℝ) / (↑(n + 2)) ^ 2) from by ext n; exact (hconv n).symm]
  linarith [h_tail, pi_sq_lt_twelve]

/-- Summability of `n ↦ 1/(n+1)^s` when `1 < Re(s)`. -/
private lemma summable_one_div_add_one_cpow {s : ℂ} (hs : 1 < s.re) :
    Summable (fun n : ℕ => 1 / (↑n + 1 : ℂ) ^ s) := by
  exact ((summable_nat_add_iff 1).mpr
    (Complex.summable_one_div_nat_cpow.mpr hs)).congr (fun n => by
      simp only [Nat.cast_add, Nat.cast_one])

/-- Pointwise norm bound: `‖1/(n+2)^s‖ ≤ 1/(n+2)^2` when `Re(s) ≥ 2`. -/
private lemma norm_one_div_cpow_le {s : ℂ} (hs : 2 ≤ s.re) (n : ℕ) :
    ‖1 / ((n : ℂ) + 2) ^ s‖ ≤ 1 / ((n : ℝ) + 2) ^ 2 := by
  have hpos : (0 : ℝ) < (n : ℝ) + 2 := by positivity
  rw [norm_div, norm_one,
      show ((n : ℂ) + 2 : ℂ) = (↑((n : ℝ) + 2) : ℂ) from by push_cast; ring,
      Complex.norm_cpow_eq_rpow_re_of_pos hpos,
      one_div, one_div,
      show ((n : ℝ) + 2) ^ (2 : ℕ) = ((n : ℝ) + 2) ^ ((2 : ℕ) : ℝ) from by rw [rpow_natCast]]
  exact inv_anti₀ (rpow_pos_of_pos hpos _)
    (rpow_le_rpow_of_exponent_le (by linarith : 1 ≤ (n : ℝ) + 2) (by exact_mod_cast hs))

/-- **Zeta tail bound**: `‖ζ(s) - 1‖ < 1` for `Re(s) ≥ 2`.

    This gives `1/ζ(s) = 1/(1 + (ζ(s) - 1))` is well-defined via Neumann series,
    and `ζ(s) ≠ 0` in the region `Re(s) ≥ 2`. -/
theorem zeta_sub_one_norm_lt_one {s : ℂ} (hs : 2 ≤ s.re) :
    ‖riemannZeta s - 1‖ < 1 := by
  have hs1 : 1 < s.re := by linarith
  have hsumm := summable_one_div_add_one_cpow hs1
  -- ζ(s) - 1 = ∑' n, 1/(n+2)^s
  have h_sub : riemannZeta s - 1 = ∑' n : ℕ, 1 / ((n : ℂ) + 2) ^ s := by
    rw [zeta_eq_tsum_one_div_nat_add_one_cpow hs1, hsumm.tsum_eq_zero_add]
    simp only [Nat.cast_zero, zero_add, one_cpow, div_one, add_sub_cancel_left]
    congr 1; ext n; push_cast; ring_nf
  rw [h_sub]
  -- Summability of n ↦ 1/(n+2)^s
  have hsumm2 : Summable (fun n : ℕ => 1 / ((n : ℂ) + 2) ^ s) := by
    have := (summable_nat_add_iff 1).mpr hsumm
    exact this.congr (fun n => by push_cast; ring_nf)
  -- Summability of real comparison series
  have hsumm_real : Summable (fun n : ℕ => (1 : ℝ) / ((n : ℝ) + 2) ^ 2) := by
    exact ((summable_nat_add_iff 2).mpr hasSum_zeta_two.summable).congr (fun n => by
      push_cast; ring_nf)
  -- Chain: ‖∑'‖ ≤ ∑' ‖·‖ ≤ ∑' 1/(n+2)^2 < 1
  apply lt_of_le_of_lt (norm_tsum_le_tsum_norm hsumm2.norm)
  apply lt_of_le_of_lt (hsumm2.norm.tsum_le_tsum (fun n => norm_one_div_cpow_le hs n) hsumm_real)
  exact tsum_tail_inv_sq_lt_one

end Cathedral.Zeta.TailBound
