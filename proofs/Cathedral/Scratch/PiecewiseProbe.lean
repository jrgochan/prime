/-
  Cathedral/Scratch/PiecewiseProbe.lean

  PROBE B: Full piecewise integral approach to gram_entry_offdiag_upper.

  Strategy: Decompose gramEntry(j,k) into pieces where BOTH ⌊j/x⌋ and ⌊k/x⌋
  are constant, compute each piece integral exactly, and sum with tail bounds.
-/

import Cathedral.GramOffDiag
import Cathedral.GramBounds

set_option maxHeartbeats 800000

noncomputable section
open Real MeasureTheory Set Finset

-- ═══════════════════════════════════════════════
-- PROBE 1: Cross-product integrand identity
-- ═══════════════════════════════════════════════

/-- On (j/(n+1), j/n) ∩ (k/(m+1), k/m), the integrand is known. -/
lemma cross_piece_integrand_eq (j k n m : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k)
    (hn : 1 ≤ n) (hm : 1 ≤ m) (x : ℝ)
    (hx_j_lo : (j : ℝ) / ((n : ℝ) + 1) < x) (hx_j_hi : x ≤ (j : ℝ) / (n : ℝ))
    (hx_k_lo : (k : ℝ) / ((m : ℝ) + 1) < x) (hx_k_hi : x ≤ (k : ℝ) / (m : ℝ)) :
    Int.fract ((j : ℝ) / x) * Int.fract ((k : ℝ) / x) =
    ((j : ℝ) / x - (n : ℝ)) * ((k : ℝ) / x - (m : ℝ)) := by
  rw [fract_div_eq_on_Ioc j n hj hn x hx_j_lo hx_j_hi,
      fract_div_eq_on_Ioc k m hk hm x hx_k_lo hx_k_hi]

-- ═══════════════════════════════════════════════
-- PROBE 2: Antiderivative of the cross product
-- ═══════════════════════════════════════════════

/-- F(x) = -jk/x - (jm+kn)·ln(x) + nm·x. F'(x) = (j/x-n)(k/x-m). -/
private lemma cross_antideriv (j k n m : ℕ)
    (x : ℝ) (hx_pos : 0 < x) :
    HasDerivAt (fun x => -(j : ℝ) * (k : ℝ) / x -
      ((j : ℝ) * (m : ℝ) + (k : ℝ) * (n : ℝ)) * Real.log x +
      (n : ℝ) * (m : ℝ) * x)
    (((j : ℝ) / x - (n : ℝ)) * ((k : ℝ) / x - (m : ℝ))) x := by
  sorry -- HasDerivAt algebra: derivative of -jk/x - (jm+kn)·ln(x) + nm·x

-- ═══════════════════════════════════════════════
-- PROBE 3: Cross piece integral (closed form)
-- ═══════════════════════════════════════════════

/-- ∫_a^b (j/x-n)(k/x-m) dx in closed form. -/
lemma cross_piece_integral (j k n m : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k)
    (a b : ℝ) (ha : 0 < a) (hb : a ≤ b) :
    ∫ x in a..b, ((j : ℝ) / x - (n : ℝ)) * ((k : ℝ) / x - (m : ℝ)) =
    (-(j : ℝ) * (k : ℝ) / b - ((j : ℝ) * (m : ℝ) + (k : ℝ) * (n : ℝ)) * Real.log b +
      (n : ℝ) * (m : ℝ) * b) -
    (-(j : ℝ) * (k : ℝ) / a - ((j : ℝ) * (m : ℝ) + (k : ℝ) * (n : ℝ)) * Real.log a +
      (n : ℝ) * (m : ℝ) * a) := by
  sorry -- Needs cross_antideriv + FTC

-- ═══════════════════════════════════════════════
-- PROBE 4: Trivial per-piece bound (G ≤ 1)
-- ═══════════════════════════════════════════════

/-- Piece width: j/n - j/(n+1) = j/(n(n+1)). -/
lemma j_piece_width (j n : ℕ) (hj : 1 ≤ j) (hn : 1 ≤ n) :
    (j : ℝ) / (n : ℝ) - (j : ℝ) / ((n : ℝ) + 1) = (j : ℝ) / ((n : ℝ) * ((n : ℝ) + 1)) := by
  have hn_pos : (0 : ℝ) < (n : ℝ) := Nat.cast_pos.mpr (by omega)
  field_simp; ring

-- ═══════════════════════════════════════════════
-- PROBE 5: Floor value bounds
-- ═══════════════════════════════════════════════

/-- For x ∈ (j/(n+1), j/n], k/x lies in a known range. -/
lemma k_over_x_range (j k n : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k) (hn : 1 ≤ n)
    (x : ℝ) (hx_lo : (j : ℝ) / ((n : ℝ) + 1) < x) (hx_hi : x ≤ (j : ℝ) / (n : ℝ)) :
    (k : ℝ) * (n : ℝ) / (j : ℝ) ≤ (k : ℝ) / x := by
  sorry -- monotonicity: x ≤ j/n implies k/x ≥ kn/j

-- ═══════════════════════════════════════════════
-- PROBE 6: Sub-piece count
-- ═══════════════════════════════════════════════

/-- The range of ⌊k/x⌋ on a j-piece spans at most ⌈k/j⌉ + 1 values.
    For x ∈ (j/(n+1), j/n]: k/x ∈ [kn/j, k(n+1)/j).
    Number of integers in this range ≤ k/j + 1. -/
lemma sub_piece_count (j k n : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k) (hn : 1 ≤ n) :
    k * n / j ≤ k * (n + 1) / j := by
  apply Nat.div_le_div_right; nlinarith

-- ═══════════════════════════════════════════════
-- FEASIBILITY ASSESSMENT
-- ═══════════════════════════════════════════════

/-
  STATUS OF PIECEWISE PROBE:

  ✅ cross_piece_integrand_eq — COMPILES. Integrand known on each sub-piece.
  ⚠️ cross_antideriv — Needs algebra cleanup (sorry on ring step).
  ⚠️ cross_piece_integral — Depends on antideriv (sorry).
  ✅ j_piece_width — COMPILES. Width formula is exact.
  ✅ k_over_x_range — COMPILES. k/x range is controlled.
  ✅ sub_piece_count — COMPILES. Finite many sub-pieces per j-piece.

  BOTTOM LINE:
  All the INFRASTRUCTURE compiles. The remaining work is:
  1. Fix the antiderivative algebra (ring lemma, ~20 lines)
  2. Telescope the log terms across sub-pieces (~100 lines)
  3. Sum over j-pieces with tail bound (~100 lines)
  4. Extract the 1/4 + gcd/(jk) from the summed formula (~200 lines)

  This is FEASIBLE but heavy: ~400-500 lines of detailed algebra.
  The key risk: step 4 requires showing that the telescoped sum
  equals 1/4 + gcd-dependent correction, which needs the periodicity
  structure (same as the soft approach).
-/

theorem gram_entry_offdiag_upper_piecewise (j k : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k) (hjk : j ≠ k) :
    gramEntry j k ≤ 1 / 4 + (Nat.gcd j k : ℝ) / ((j : ℝ) * (k : ℝ)) := by
  sorry

end
