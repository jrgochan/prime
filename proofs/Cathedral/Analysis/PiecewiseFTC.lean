/-
  Cathedral/Analysis/PiecewiseFTC.lean

  ## PIECEWISE FTC FOR THE BODY INTEGRAL

  Proves integral_eq_partialSum:
    ∫_{1/K}^{1} {1/u}² du = StirlingBridge.partialSum K

  This bridges the gap between:
  - StirlingBridge (which proves P(K) → ln(2π) − γ − 1)
  - SqueezeElimination (which uses this to prove ∫₀¹ = ln(2π) − γ − 1)

  The proof decomposes ∫_{1/K}^{1} into K-1 piece integrals,
  evaluates each via FTC, and matches with partialSum_eq_series_sum.

  Created: April 12, 2026, 7:29 PM MDT (The Piecewise Campaign)
-/

import Cathedral.Analysis.StirlingBridge
import Mathlib.MeasureTheory.Integral.IntervalIntegral.Basic
import Mathlib.MeasureTheory.Integral.IntervalIntegral.FundThmCalculus
import Mathlib.MeasureTheory.Function.Floor
import Mathlib.Analysis.SpecialFunctions.Integrals.Basic

noncomputable section
open Real MeasureTheory

namespace Cathedral.Vasyunin.PiecewiseFTC

-- ════════════════════════════════════════════════
-- §1. FRACT IDENTITY ON EACH PIECE
-- ════════════════════════════════════════════════

/-- On the interval (1/(n+1), 1/n], we have ⌊1/x⌋ = n,
    so {1/x} = 1/x - n and {1/x}² = (1/x - n)².
    Here n ≥ 1. -/
lemma fract_eq_on_piece (n : ℕ) (hn : 1 ≤ n) (x : ℝ)
    (hlo : 1 / ((n:ℝ) + 1) < x) (hhi : x ≤ 1 / (n:ℝ)) :
    Int.fract (1 / x) = 1 / x - (n:ℝ) := by
  have hn_pos : (0:ℝ) < (n:ℝ) := Nat.cast_pos.mpr (by omega)
  have hn1_pos : (0:ℝ) < (n:ℝ) + 1 := by linarith
  have hx_pos : (0:ℝ) < x := lt_of_lt_of_le (by positivity) (le_of_lt hlo)
  -- 1/x ∈ [n, n+1)
  have h_ge : (n:ℝ) ≤ 1 / x := by
    rw [le_div_iff₀ hx_pos]
    calc (n:ℝ) * x ≤ (n:ℝ) * (1 / (n:ℝ)) := by nlinarith
      _ = 1 := by field_simp
  have h_lt : 1 / x < (n:ℝ) + 1 := by
    rw [div_lt_iff₀ hx_pos]
    calc 1 = ((n:ℝ) + 1) * (1 / ((n:ℝ) + 1)) := by field_simp
      _ < ((n:ℝ) + 1) * x := by nlinarith
  -- So ⌊1/x⌋ = n
  have hfloor : ⌊1 / x⌋ = (n:ℤ) := by
    apply Int.floor_eq_iff.mpr
    exact ⟨by exact_mod_cast h_ge, by push_cast; exact h_lt⟩
  rw [Int.fract, hfloor]; push_cast; ring

-- ════════════════════════════════════════════════
-- §2. FTC ON EACH PIECE
-- ════════════════════════════════════════════════

/-- FTC: ∫_{1/(n+1)}^{1/n} (1/x - n)² dx = (2n+1)/(n+1) - 2n·log(1+1/n).

    Antiderivative: F(x) = -x⁻¹ - 2n·log(x) + n²·x.
    F'(x) = x⁻² + 2n·x⁻¹ + n² ... wait, that's not right.
    Actually for (1/x - n)² = 1/x² - 2n/x + n²,
    the antiderivative is -1/x - 2n·log(x) + n²·x. -/
lemma piece_integral_ftc (n : ℕ) (hn : 1 ≤ n) :
    ∫ x in (1 / ((n:ℝ) + 1))..(1 / (n:ℝ)),
      (1 / x - (n:ℝ)) ^ 2 =
    (2 * (n:ℝ) + 1) / ((n:ℝ) + 1) - 2 * (n:ℝ) * Real.log (1 + 1 / (n:ℝ)) := by
  have hn_pos : (0:ℝ) < (n:ℝ) := Nat.cast_pos.mpr (by omega)
  have hn1_pos : (0:ℝ) < (n:ℝ) + 1 := by linarith
  have hlo : (0:ℝ) < 1 / ((n:ℝ) + 1) := by positivity
  have hhi : (0:ℝ) < 1 / (n:ℝ) := by positivity
  have hle : 1 / ((n:ℝ) + 1) ≤ 1 / (n:ℝ) :=
    div_le_div_of_nonneg_left (by linarith) hn_pos (by linarith)
  -- Use antiderivative F(x) = -x⁻¹ + (-2n·log(x)) + n²·x
  -- Note: we avoid Lean sub/neg issues by writing + (-2n·log x)
  have hF_deriv : ∀ x ∈ Set.uIcc (1 / ((n:ℝ) + 1)) (1 / (n:ℝ)),
      HasDerivAt (fun x => -x⁻¹ + (-2 * (n:ℝ) * Real.log x) + (n:ℝ) ^ 2 * x)
        ((1 / x - (n:ℝ)) ^ 2) x := by
    intro x hx
    rw [Set.uIcc_of_le hle] at hx
    have hx_pos : (0:ℝ) < x := lt_of_lt_of_le hlo hx.1
    have hx_ne : x ≠ 0 := ne_of_gt hx_pos
    have h1 : HasDerivAt (fun x => -x⁻¹) (x⁻¹ ^ 2) x := by
      convert (hasDerivAt_inv hx_ne).neg using 1; ring
    have h2 : HasDerivAt (fun x => -2 * (n:ℝ) * Real.log x) (-2 * (n:ℝ) * x⁻¹) x :=
      (Real.hasDerivAt_log hx_ne).const_mul (-2 * (n:ℝ))
    have h3 : HasDerivAt (fun x => (n:ℝ) ^ 2 * x) ((n:ℝ) ^ 2) x := by
      convert (hasDerivAt_id x).const_mul ((n:ℝ) ^ 2) using 1; ring
    exact ((h1.add h2).add h3).congr_deriv (by field_simp; ring)
  have hint : IntervalIntegrable (fun x => (1 / x - (n:ℝ)) ^ 2)
      volume (1 / ((n:ℝ) + 1)) (1 / (n:ℝ)) := by
    apply ContinuousOn.intervalIntegrable
    apply ContinuousOn.pow
    exact (continuousOn_const.div continuousOn_id (fun x hx => by
      rw [Set.uIcc_of_le hle] at hx
      exact ne_of_gt (lt_of_lt_of_le hlo hx.1))).sub continuousOn_const
  rw [intervalIntegral.integral_eq_sub_of_hasDerivAt hF_deriv hint]
  -- Evaluate at endpoints
  have hinv_hi : (1 / (n:ℝ))⁻¹ = (n:ℝ) := by field_simp
  have hinv_lo : (1 / ((n:ℝ) + 1))⁻¹ = (n:ℝ) + 1 := by field_simp
  rw [hinv_hi, hinv_lo]
  have hlog : Real.log (1 / (n:ℝ)) - Real.log (1 / ((n:ℝ) + 1)) =
      Real.log (1 + 1 / (n:ℝ)) := by
    rw [← Real.log_div (ne_of_gt hhi) (ne_of_gt hlo)]
    congr 1; field_simp
  set L := Real.log (1 + 1 / (n:ℝ))
  have hlog2 : Real.log (1 / (n:ℝ)) = Real.log (1 / ((n:ℝ) + 1)) + L := by
    linarith [hlog]
  rw [hlog2]
  have hn_ne : (n:ℝ) ≠ 0 := ne_of_gt hn_pos
  have hn1_ne : (n:ℝ) + 1 ≠ 0 := ne_of_gt hn1_pos
  field_simp; ring

-- ════════════════════════════════════════════════
-- §3. PIECE INTEGRAL = STIRLING TERM (ALGEBRAIC)
-- ════════════════════════════════════════════════

/-- The FTC value (2n+1)/(n+1) - 2n·log(1+1/n) equals the
    StirlingBridge summand -2n·log(1+1/n) + 2 - 1/(n+1).
    This is pure algebra: (2n+1)/(n+1) = 2 - 1/(n+1). -/
lemma ftc_eq_stirling_term (n : ℕ) (hn : 1 ≤ n) :
    (2 * (n:ℝ) + 1) / ((n:ℝ) + 1) - 2 * (n:ℝ) * Real.log (1 + 1 / (n:ℝ)) =
    -2 * (n:ℝ) * Real.log (1 + 1 / (n:ℝ)) + 2 - 1 / ((n:ℝ) + 1) := by
  have hn1_ne : (n:ℝ) + 1 ≠ 0 := ne_of_gt (by positivity : (0:ℝ) < (n:ℝ) + 1)
  field_simp; ring

-- ════════════════════════════════════════════════
-- §4. INTEGRABILITY AND TELESCOPING
-- ════════════════════════════════════════════════

/-- {1/x}² is interval integrable on any bounded interval. -/
lemma fract_sq_intervalIntegrable (a b : ℝ) :
    IntervalIntegrable (fun x => Int.fract (1 / x) * Int.fract (1 / x))
      volume a b := by
  apply IntervalIntegrable.mono_fun (intervalIntegrable_const (c := (1:ℝ)))
  · have hm : Measurable (fun x : ℝ => Int.fract (1 / x) * Int.fract (1 / x)) :=
      (measurable_const.div measurable_id).fract.mul
        (measurable_const.div measurable_id).fract
    exact hm.aestronglyMeasurable.restrict
  · apply ae_of_all
    intro x
    simp only [Real.norm_eq_abs, abs_one]
    rw [abs_of_nonneg (mul_nonneg (Int.fract_nonneg _) (Int.fract_nonneg _))]
    nlinarith [Int.fract_nonneg (1/x), Int.fract_lt_one (1/x)]

/-- ae congr: on (1/(n+1), 1/n], {1/x}² = (1/x - n)². -/
lemma fract_sq_ae_eq_piece (n : ℕ) (hn : 1 ≤ n) :
    ∫ x in (1 / ((n:ℝ) + 1))..(1 / (n:ℝ)),
      Int.fract (1 / x) * Int.fract (1 / x) =
    ∫ x in (1 / ((n:ℝ) + 1))..(1 / (n:ℝ)),
      (1 / x - (n:ℝ)) ^ 2 := by
  have hn_pos : (0:ℝ) < (n:ℝ) := Nat.cast_pos.mpr (by omega)
  have hle : 1 / ((n:ℝ) + 1) ≤ 1 / (n:ℝ) :=
    div_le_div_of_nonneg_left (by linarith) hn_pos (by linarith)
  rw [intervalIntegral.integral_of_le hle, intervalIntegral.integral_of_le hle]
  exact MeasureTheory.integral_congr_ae ((ae_restrict_mem measurableSet_Ioc).mono
    (fun x hx => by
      simp only
      have hfr := fract_eq_on_piece n hn x hx.1 hx.2
      nlinarith [Int.fract_nonneg (1/x), Int.fract_lt_one (1/x)]))

/-- Each piece integral of {1/x}² equals the StirlingBridge summand. -/
theorem piece_eq_stirling_summand (n : ℕ) (hn : 1 ≤ n) :
    ∫ x in (1 / ((n:ℝ) + 1))..(1 / (n:ℝ)),
      Int.fract (1 / x) * Int.fract (1 / x) =
    -2 * (n:ℝ) * Real.log (1 + 1 / (n:ℝ)) + 2 - 1 / ((n:ℝ) + 1) := by
  rw [fract_sq_ae_eq_piece n hn, piece_integral_ftc n hn, ftc_eq_stirling_term n hn]

/-- Telescoping: the sum of piece integrals equals ∫_{1/K}^{1}. -/
theorem telescope (K : ℕ) (hK : 2 ≤ K) :
    ∑ m ∈ Finset.range (K - 1),
      ∫ x in (1 / ((m:ℝ) + 2))..(1 / ((m:ℝ) + 1)),
        Int.fract (1 / x) * Int.fract (1 / x) =
    ∫ x in (1 / (K:ℝ))..(1:ℝ),
      Int.fract (1 / x) * Int.fract (1 / x) := by
  induction K with
  | zero => omega
  | succ K ih =>
    by_cases hK1 : K = 1
    · -- Base case: K+1 = 2
      subst hK1
      simp
    · -- K+1 ≥ 3, so K ≥ 2
      have hK_ge2 : 2 ≤ K := by omega
      rw [show K + 1 - 1 = (K - 1) + 1 from by omega]
      rw [Finset.sum_range_succ, ih hK_ge2]
      -- Use adjacent intervals
      have hadj := intervalIntegral.integral_add_adjacent_intervals
        (fract_sq_intervalIntegrable (1 / ((↑(K - 1) : ℝ) + 2)) (1 / ((↑(K - 1) : ℝ) + 1)))
        (fract_sq_intervalIntegrable (1 / ((↑(K - 1) : ℝ) + 1)) 1)
      rw [add_comm]
      convert hadj using 2 <;>
        (congr 1; rw [Nat.cast_sub (by omega : 1 ≤ K)]; push_cast; ring)

-- ════════════════════════════════════════════════
-- §5. MAIN THEOREM: INTEGRAL = PARTIAL SUM
-- ════════════════════════════════════════════════

/-- **THE PIECEWISE LINKAGE**:
    ∫_{1/K}^{1} {1/u}² du = StirlingBridge.partialSum K.

    Each piece integral ∫_{1/(n+1)}^{1/n} {1/x}² equals the
    StirlingBridge summand, by FTC + algebraic matching. -/
theorem integral_eq_partialSum (K : ℕ) (hK : K ≥ 2) :
    ∫ x in (1 / (K:ℝ))..(1:ℝ),
      Int.fract (1 / x) * Int.fract (1 / x) =
    StirlingBridge.partialSum K := by
  rw [← telescope K hK]
  rw [StirlingBridge.partialSum_eq_series_sum K hK]
  apply Finset.sum_congr rfl
  intro m hm
  rw [Finset.mem_range] at hm
  -- The m-th summand: piece integral on [1/(m+2), 1/(m+1)]
  -- = -2(m+1)·log(1+1/(m+1)) + 2 - 1/(m+2)
  -- piece_eq_stirling_summand uses n=m+1:
  --   ∫ in 1/((m+1)+1)..1/(m+1), ... = -2*(m+1)*log(1+1/(m+1)) + 2 - 1/((m+1)+1)
  -- Goal has ∫ in 1/(↑m+2)..1/(↑m+1), ... = -2*(↑m+1)*log(1+1/(↑m+1)) + 2 - 1/(↑m+2)
  -- These match since ↑(m+1)+1 = ↑m+2
  have key := piece_eq_stirling_summand (m + 1) (by omega)
  convert key using 2 <;> (push_cast; ring)

end Cathedral.Vasyunin.PiecewiseFTC

