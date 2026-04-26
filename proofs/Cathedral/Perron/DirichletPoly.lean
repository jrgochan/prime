import Cathedral.Perron.Defs
import Cathedral.White.Infrastructure.DirichletZetaInverse
import Mathlib.Analysis.PSeries
import Mathlib.Analysis.SumIntegralComparisons
import Mathlib.Analysis.SpecialFunctions.ImproperIntegrals
import Mathlib.Topology.Algebra.InfiniteSum.Real

/-!
# Dirichlet Polynomial Infrastructure for the Perron Formula

This file provides the sum-integral swap for finite Dirichlet polynomials,
the Möbius Dirichlet polynomial approximation to `1/ζ(s)`, and supporting
tail bounds via the integral test.

## Main results

* `perron_integrand_intervalIntegrable` : integrability of `y^s/s` on `[-T, T]`
* `finite_sum_integral_swap` : `∑ a(n)·P(x/n) = (1/2π) ∫ ∑ a(n)(x/n)^s/s`
* `moebius_partial_sum_approx` : `‖∑_{n≤N} μ(n)/n^s - 1/ζ(s)‖ ≤ N^{1-σ}/(σ-1)`
* `rpow_tail_bound` : `∑' (N+(n+1))^{-σ} ≤ N^{1-σ}/(σ-1)`
-/

noncomputable section
open Complex Real MeasureTheory Set Filter ArithmeticFunction
open scoped LSeries.notation ArithmeticFunction.Moebius ArithmeticFunction.zeta Topology

namespace Cathedral.White.Infrastructure

-- ═══════════════════════════════════════════
-- Dirichlet Polynomial Infrastructure
-- ═══════════════════════════════════════════

/-- **PROVED**: Integrability of the Perron integrand on [-T, T] for y > 0.
    Uses: ContinuousOn.cpow (base in slitPlane since y > 0) + ContinuousOn.div. -/
lemma perron_integrand_intervalIntegrable (y c T : ℝ) (hc : 0 < c) (hy : 0 < y) :
    IntervalIntegrable (fun t : ℝ =>
      (y : ℂ) ^ (↑c + ↑t * I) / (↑c + ↑t * I))
      MeasureTheory.volume (-T) T := by
  apply ContinuousOn.intervalIntegrable
  apply ContinuousOn.div
  · exact ContinuousOn.cpow continuousOn_const (by fun_prop)
      (fun _ _ => Complex.ofReal_mem_slitPlane.mpr hy)
  · fun_prop
  · intro t _ h; have := congr_arg Complex.re h
    simp [Complex.add_re, Complex.ofReal_re, Complex.mul_re, Complex.I_re, Complex.I_im] at this
    linarith

/-- **PROVED**: Sum-integral swap for finite Dirichlet polynomials.
    Uses: Finset.mul_sum, intervalIntegral.integral_const_mul,
    intervalIntegral.integral_finset_sum,
    perron_integrand_intervalIntegrable (continuity of y^s/s). -/
lemma finite_sum_integral_swap
    (a : ℕ → ℂ) (x c T : ℝ) (S : Finset ℕ)
    (hc : 0 < c) (_hT : 0 < T) (_hx : 1 < x) :
    ∑ n ∈ S, a n * perronIntegral (x / ↑n) c T =
    (1 / (2 * Real.pi)) • ∫ t in (-T)..T,
      ∑ n ∈ S, a n * ((x / ↑n : ℂ) ^ (↑c + ↑t * I) / (↑c + ↑t * I)) := by
  -- Step 1: Unfold perronIntegral and fix casts
  simp only [perronIntegral, perronIntegrand]
  have h_cast : ∀ n : ℕ, (↑(x / ↑n) : ℂ) = (↑x : ℂ) / (↑n : ℂ) := by
    intro n; push_cast; ring
  simp_rw [h_cast]
  -- Step 2: Convert RHS ℝ-smul to ℂ-mul
  rw [show (1 / (2 * π) : ℝ) • (∫ t in (-T)..T,
      ∑ n ∈ S, a n * ((↑x / ↑n : ℂ) ^ (↑c + ↑t * I) / (↑c + ↑t * I))) =
    1 / (2 * (↑π : ℂ)) * ∫ t in (-T)..T,
      ∑ n ∈ S, a n * ((↑x / ↑n : ℂ) ^ (↑c + ↑t * I) / (↑c + ↑t * I)) from by
    simp [Complex.ofReal_mul, Complex.ofReal_ofNat]]
  -- Step 3: Factor 1/(2π) out of the sum
  trans 1 / (2 * (↑π : ℂ)) * ∑ n ∈ S, a n * ∫ t in (-T)..T,
      (↑x / ↑n : ℂ) ^ (↑c + ↑t * I) / (↑c + ↑t * I)
  · rw [Finset.mul_sum]; congr 1; ext n; ring
  congr 1
  -- Step 4: Pull a(n) into integral
  trans ∑ n ∈ S, ∫ t in (-T)..T,
      a n * ((↑x / ↑n : ℂ) ^ (↑c + ↑t * I) / (↑c + ↑t * I))
  · congr 1; ext n; exact (intervalIntegral.integral_const_mul _ _).symm
  -- Step 5: Swap sum and integral (by integral_finset_sum)
  symm
  apply intervalIntegral.integral_finset_sum
  -- Each summand a(n) * ((↑x/↑n)^(c+tI)/(c+tI)) is integrable on [-T,T]
  -- Uses perron_integrand_intervalIntegrable with y = x/n > 0
  intro n _
  apply IntervalIntegrable.const_mul
  -- Need: IntervalIntegrable (fun t => (↑x / ↑n : ℂ)^(c+tI)/(c+tI))
  -- This is the same as perron_integrand_intervalIntegrable (x/n) c T hc
  -- once we identify ↑(x/↑n : ℝ) with (↑x/↑n : ℂ)
  have : (fun t : ℝ => (↑x / ↑n : ℂ) ^ (↑c + ↑t * I) / (↑c + ↑t * I)) =
    (fun t : ℝ => (↑(x / ↑n) : ℂ) ^ (↑c + ↑t * I) / (↑c + ↑t * I)) := by
    ext t; congr 1; push_cast; ring
  rw [this]
  by_cases hn : n = 0
  · -- n = 0 case: x/0 = 0, and 0^(c+tI)/(c+tI) = 0 since c+tI ≠ 0
    subst hn; simp only [Nat.cast_zero, div_zero, Complex.ofReal_zero]
    have h_zero : (fun t : ℝ => (0 : ℂ) ^ (↑c + ↑t * I) / (↑c + ↑t * I)) =
        (fun _ => (0 : ℂ)) := by
      ext t; have : ↑c + ↑t * I ≠ (0 : ℂ) := by
        intro h; have := congr_arg Complex.re h
        simp [Complex.add_re, Complex.ofReal_re, Complex.mul_re,
              Complex.I_re, Complex.I_im] at this; linarith
      simp [Complex.zero_cpow this]
    rw [h_zero]; exact intervalIntegrable_const
  · exact perron_integrand_intervalIntegrable _ c T hc
      (div_pos (by linarith) (Nat.cast_pos.mpr (Nat.pos_of_ne_zero hn)))

/-- **PROVED**: Reindexing from Finset.range to Finset.Icc 1 N. -/
lemma sum_range_eq_sum_Icc (f : ℕ → ℂ) (N : ℕ) :
    ∑ i ∈ Finset.range N, f (i + 1) = ∑ i ∈ Finset.Icc 1 N, f i := by
  conv_rhs => rw [show Finset.Icc 1 N = (Finset.range N).map
      ⟨(· + 1), Nat.succ_injective⟩ from by
    ext x; simp [Finset.mem_Icc, Finset.mem_range, Finset.mem_map]; constructor
    · intro ⟨h1, h2⟩; exact ⟨x - 1, by omega, by omega⟩
    · rintro ⟨a, ha, rfl⟩; omega]
  rw [Finset.sum_map]; simp

/-- **PROVED**: Tail extraction for Möbius L-series.
    The difference between partial sum and full L-series equals the negative tail. -/
lemma partial_sum_minus_lseries (N : ℕ) (s : ℂ) (hs : 1 < s.re) :
    ∑ n ∈ Finset.Icc 1 N, LSeries.term (↗μ) s n - LSeries (↗μ) s =
    -(∑' (n : ℕ), LSeries.term (↗μ) s (n + (N + 1))) := by
  have h_sum := moebius_lseries_summable hs
  have h_split := h_sum.sum_add_tsum_nat_add (N + 1)
  have h0 : LSeries.term (↗μ) s 0 = 0 := by simp [LSeries.term]
  have h_range_eq : ∑ i ∈ Finset.range (N + 1), LSeries.term (↗μ) s i =
      ∑ i ∈ Finset.Icc 1 N, LSeries.term (↗μ) s i := by
    rw [Finset.sum_range_succ', h0, add_zero]
    exact sum_range_eq_sum_Icc _ _
  simp only [LSeries]
  rw [← h_range_eq, eq_sub_of_add_eq h_split]; ring

/-- **PROVED**: Finite partial sum of x^{-σ} is bounded by N^{1-σ}/(σ-1).
    Uses AntitoneOn.sum_le_integral + integral_rpow + algebraic sign manipulation.
    Architecture due to Gemini Theorist: zero measure theory limits! -/
private lemma rpow_tail_finite (N : ℕ) (hN : 0 < N) (σ : ℝ) (hσ : 1 < σ) (K : ℕ) :
    ∑ i ∈ Finset.range K, ((↑N : ℝ) + ↑(i + 1)) ^ (-σ) ≤ (↑N : ℝ) ^ (1 - σ) / (σ - 1) := by
  have hN_pos : (0 : ℝ) < (↑N : ℝ) := Nat.cast_pos.mpr hN
  have hNK_le : (↑N : ℝ) ≤ (↑N : ℝ) + (↑K : ℝ) := le_add_of_nonneg_right (Nat.cast_nonneg K)
  -- Step 1: Antitone of x^{-σ} on [N, N+K]
  have h_anti : AntitoneOn (fun x : ℝ => x ^ (-σ)) (Set.Icc (↑N : ℝ) ((↑N : ℝ) + ↑K)) := by
    intro a ha b hb hab; simp only
    rw [rpow_neg (lt_of_lt_of_le hN_pos ha.1).le,
        rpow_neg (lt_of_lt_of_le hN_pos hb.1).le, inv_eq_one_div, inv_eq_one_div]
    exact one_div_le_one_div_of_le
      (rpow_pos_of_pos (lt_of_lt_of_le hN_pos ha.1) σ)
      (rpow_le_rpow (lt_of_lt_of_le hN_pos ha.1).le hab (by linarith : 0 ≤ σ))
  -- Step 2: ∑ ≤ ∫ via AntitoneOn.sum_le_integral
  have h_sum_le := h_anti.sum_le_integral
  -- Step 3: Evaluate ∫_N^{N+K} x^{-σ} via integral_rpow
  have h_not_in : (0 : ℝ) ∉ Set.uIcc (↑N : ℝ) ((↑N : ℝ) + (↑K : ℝ)) := by
    rw [Set.uIcc_of_le hNK_le]
    intro h; simp [Set.mem_Icc] at h; linarith [h.1]
  have h_int := integral_rpow (a := (↑N : ℝ)) (b := (↑N : ℝ) + (↑K : ℝ)) (r := -σ)
    (Or.inr ⟨by linarith, h_not_in⟩)
  -- Step 4: Bound by dropping the nonpositive (N+K)^{-σ+1}/(-σ+1) term
  have h_neg_term : ((↑N : ℝ) + ↑K) ^ (-σ + 1) / (-σ + 1) ≤ 0 :=
    div_nonpos_iff.mpr (Or.inl ⟨rpow_nonneg (by linarith : (0:ℝ) ≤ ↑N + ↑K) _, by linarith⟩)
  -- Chain: ∑ ≤ ∫ = formula ≤ bound
  have step1 := le_trans h_sum_le (le_of_eq h_int)
  have step2 : (((↑N : ℝ) + ↑K) ^ (-σ + 1) - (↑N : ℝ) ^ (-σ + 1)) / (-σ + 1) ≤
      (↑N : ℝ) ^ (1 - σ) / (σ - 1) := by
    rw [sub_div]
    have h_main : -(↑N : ℝ) ^ (-σ + 1) / (-σ + 1) = (↑N : ℝ) ^ (1 - σ) / (σ - 1) := by
      rw [show (-σ + 1 : ℝ) = 1 - σ from by ring,
          show (1 - σ : ℝ) = -(σ - 1) from by ring]
      exact neg_div_neg_eq _ _
    calc _ ≤ 0 - (↑N : ℝ) ^ (-σ + 1) / (-σ + 1) := by linarith [h_neg_term]
      _ = -(↑N : ℝ) ^ (-σ + 1) / (-σ + 1) := by ring
      _ = _ := h_main
  exact le_trans step1 step2

/-- **PROVED** (zero sorry): The integral test for the Dirichlet series tail.
    ∑' n, (N + (n+1))^{-σ} ≤ N^{1-σ}/(σ-1) for σ > 1 and N ≥ 1.

    Uses: AntitoneOn.sum_le_integral + integral_rpow + Real.tsum_le_of_sum_range_le.
    Architecture due to Gemini Theorist: algebraic bound on finite sums,
    then lift to tsum. Zero measure theory limits needed! -/
lemma rpow_tail_bound (N : ℕ) (hN : 0 < N) (σ : ℝ) (hσ : 1 < σ) :
    ∑' (n : ℕ), ((↑N : ℝ) + ↑(n + 1)) ^ (-σ) ≤ (↑N : ℝ) ^ (1 - σ) / (σ - 1) :=
  Real.tsum_le_of_sum_range_le
    (fun n => rpow_nonneg (by linarith [Nat.cast_nonneg (α := ℝ) N, Nat.cast_nonneg (α := ℝ) (n + 1)]) _)
    (fun K => rpow_tail_finite N hN σ hσ K)

set_option maxHeartbeats 400000 in
/-- **PROVED**: Summability of the shifted rpow sequence (N+(n+1))^{-σ}
    for σ > 1, by comparison with the convergent p-series (n+1)^{-σ}.
    Uses rpow_le_rpow_of_nonpos for the monotonicity comparison. -/
lemma rpow_shifted_summable (N : ℕ) (σ : ℝ) (hσ : 1 < σ) :
    Summable (fun n : ℕ => ((↑N : ℝ) + ↑(n + 1)) ^ (-σ)) := by
  apply (((summable_nat_add_iff 1).mpr
    (Real.summable_nat_rpow.mpr (by linarith))).of_nonneg_of_le
    (fun n => rpow_nonneg (by positivity) _)
    (fun n => rpow_le_rpow_of_nonpos
      (by positivity)
      (by push_cast; linarith [Nat.cast_nonneg (α := ℝ) N])
      (by linarith)))

set_option maxHeartbeats 800000 in
/-- **PROVED (zero sorry!)**: Dirichlet polynomial identification.
    For Re(s) > 1 and N ≥ 1,
    Σ_{n≤N} μ(n)/n^s approximates 1/ζ(s) with tail O(N^{1-Re(s)}).

    Proof chain:
    1. moebius_lseries_eq_inv_zeta: LSeries(μ,s) = 1/ζ(s) (PROVED)
    2. partial_sum_minus_lseries: tail extraction (PROVED)
    3. abs_moebius_le_one: |μ(n)| ≤ 1 (Mathlib)
    4. norm_tsum_le_tsum_norm: ‖∑'f‖ ≤ ∑'‖f‖ (Mathlib)
    5. rpow_tail_bound: integral test (PROVED — zero sorry!) -/
lemma moebius_partial_sum_approx (N : ℕ) (hN : 0 < N) (s : ℂ) (_hs : 1 < s.re) :
    ‖∑ n ∈ Finset.Icc 1 N, (↑(ArithmeticFunction.moebius n) : ℂ) / (↑n : ℂ) ^ s -
      (1 / riemannZeta s)‖ ≤ (↑N : ℝ) ^ (1 - s.re) / (s.re - 1) := by
  -- Step 1: Rewrite 1/ζ(s) as LSeries(μ,s)
  rw [← moebius_lseries_eq_inv_zeta _hs]
  -- Step 2: Convert our sum to use LSeries.term
  have h_term_eq : ∑ n ∈ Finset.Icc 1 N, (↑(μ n) : ℂ) / (↑n : ℂ) ^ s =
      ∑ n ∈ Finset.Icc 1 N, LSeries.term (↗μ) s n := by
    apply Finset.sum_congr rfl
    intro n hn; simp [Finset.mem_Icc] at hn
    simp [LSeries.term, show n ≠ 0 from by omega]
  rw [h_term_eq]
  -- Step 3: Apply tail extraction
  rw [partial_sum_minus_lseries N s _hs, norm_neg]
  -- Goal: ‖∑' n, LSeries.term (↗μ) s (n + (N+1))‖ ≤ N^{1-σ}/(σ-1)
  -- Step 4: Chain ‖∑'f‖ ≤ ∑'‖f‖ ≤ ∑'g ≤ bound
  have h_summ : Summable (fun n => LSeries.term (↗μ) s (n + (N + 1))) :=
    (summable_nat_add_iff (N + 1)).mpr (LSeriesSummable_moebius_iff.mpr _hs)
  have h_norm_summ := h_summ.norm
  have h_rpow_summ := rpow_shifted_summable N s.re _hs
  -- Pointwise bound: ‖term (↗μ) s (n+N+1)‖ ≤ (N+(n+1))^{-σ}
  have h_pw : ∀ n, ‖LSeries.term (↗μ) s (n + (N + 1))‖ ≤
      ((↑N : ℝ) + ↑(n + 1)) ^ (-s.re) := by
    intro n
    have hm : n + (N + 1) ≠ 0 := by omega
    rw [LSeries.norm_term_eq, if_neg hm]
    calc ‖(↑(μ (n + (N + 1))) : ℂ)‖ / (↑(n + (N + 1)) : ℝ) ^ s.re
        ≤ 1 / (↑(n + (N + 1)) : ℝ) ^ s.re := by
          gcongr; rw [Complex.norm_intCast]
          exact_mod_cast abs_moebius_le_one (n := n + (N + 1))
      _ = ((↑N : ℝ) + ↑(n + 1)) ^ (-s.re) := by
          rw [rpow_neg (by positivity : (0:ℝ) ≤ ↑N + ↑(n + 1)), one_div]
          congr 1; push_cast; ring_nf
  -- Chain: ‖∑' f‖ ≤ ∑' ‖f‖ ≤ ∑' g ≤ bound
  exact (norm_tsum_le_tsum_norm h_norm_summ).trans
    ((h_norm_summ.tsum_le_tsum h_pw h_rpow_summ).trans
      (rpow_tail_bound N hN s.re _hs))

end Cathedral.White.Infrastructure
