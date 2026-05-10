import Mathlib.NumberTheory.LSeries.SumCoeff
import Mathlib.Analysis.SpecialFunctions.Pow.Deriv

/-!
  # Abel Summation for Dirichlet Series

  Convenience wrappers around Mathlib's `LSeries_eq_mul_integral`
  for the integral representation of L-series via Abel summation.
-/


noncomputable section
open Complex Real MeasureTheory Filter Finset Asymptotics
open scoped Topology

namespace Cathedral.Zeta

-- ═══════════════════════════════════════════
-- §1. Convenience lemmas
-- ═══════════════════════════════════════════

/-- For positive real t, (t : ℂ) lies in the slit plane.
    Convenience wrapper around `Complex.ofReal_mem_slitPlane`. -/
lemma ofReal_mem_slitPlane_of_pos {t : ℝ} (ht : 0 < t) :
    (t : ℂ) ∈ Complex.slitPlane :=
  Complex.ofReal_mem_slitPlane.mpr ht

/-- Differentiability of t ↦ (t : ℂ)^r for t ≠ 0 and r ≠ 0.
    Wrapper around `hasDerivAt_ofReal_cpow_const`. -/
lemma differentiableAt_ofReal_cpow {r : ℂ} (hr : r ≠ 0) {t : ℝ} (ht : t ≠ 0) :
    DifferentiableAt ℝ (fun (x : ℝ) => (x : ℂ) ^ r) t :=
  (hasDerivAt_ofReal_cpow_const ht hr).differentiableAt

/-- The derivative of t ↦ (t : ℂ)^r equals r·t^{r-1}.
    Wrapper around `Complex.deriv_ofReal_cpow_const`. -/
lemma deriv_ofReal_cpow_eq {r : ℂ} (hr : r ≠ 0) {t : ℝ} (ht : t ≠ 0) :
    deriv (fun (x : ℝ) => (x : ℂ) ^ r) t = r * (t : ℂ) ^ (r - 1) :=
  Complex.deriv_ofReal_cpow_const ht hr

-- ═══════════════════════════════════════════
-- §2. The Dirichlet Series integral representation
-- ═══════════════════════════════════════════

/-- **PROVED (Mathlib)**: Abel summation for Dirichlet series.

    If the partial sums `∑_{k ∈ Icc 1 n} f(k)` are O(n^r) for some 0 ≤ r,
    and the L-series converges at s with r < Re(s), then:

      L(f, s) = s · ∫₁^∞ (∑_{k ≤ t} f(k)) · t^{-(s+1)} dt

    This is `LSeries_eq_mul_integral` from Mathlib, re-exported here.
    FULLY PROVED. Zero axioms.

    Note: The original Cathedral version used a different signature with
    `A : ℝ → ℂ` and `∑' n, a(n)·n^{-s}`. Mathlib's version is more
    general (works with the `LSeries` API directly). -/
theorem dirichlet_series_integral_representation
    (f : ℕ → ℂ) {r : ℝ} (hr : 0 ≤ r) {s : ℂ} (hs : r < s.re)
    (hS : LSeriesSummable f s)
    (hO : (fun n => ∑ k ∈ Icc 1 n, f k) =O[atTop] fun n => (n : ℝ) ^ r) :
    LSeries f s =
    s * ∫ t in Set.Ioi (1:ℝ), (∑ k ∈ Icc 1 ⌊t⌋₊, f k) * (t : ℂ) ^ (-(s + 1)) :=
  LSeries_eq_mul_integral f hr hs hS hO

-- ═══════════════════════════════════════════
-- §3. Summability from coefficient growth
-- ═══════════════════════════════════════════

/-- **PROVED (Mathlib)**: If partial sums of ‖f(k)‖ are O(n^r),
    then the L-series converges for Re(s) > r.
    Re-exported from `LSeriesSummable_of_sum_norm_bigO`. -/
theorem dirichlet_series_summable_of_growth
    (f : ℕ → ℂ) {r : ℝ} (hr : 0 ≤ r) {s : ℂ} (hs : r < s.re)
    (hO : (fun n => ∑ k ∈ Icc 1 n, ‖f k‖) =O[atTop] fun n => (n : ℝ) ^ r) :
    LSeriesSummable f s :=
  LSeriesSummable_of_sum_norm_bigO hO hr hs

end Cathedral.Zeta
