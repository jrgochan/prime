/-
  Cathedral/Vasyunin/Cotangent/SqueezeElimination.lean

  ## THE SQUEEZE THEOREM ELIMINATION OF AXIOM 4

  Proves: ∫₀¹ {1/u}² du = ln(2π) − γ − 1

  By the Squeeze Theorem (Theorist's directive, April 12, 2026):
    Let I = ∫₀¹ {1/u}² du (a constant).
    Let P(K) = ∫_{1/K}^{1} {1/u}² du.

    By interval additivity: I = ∫₀^{1/K} + P(K)
    By tail bound: 0 ≤ ∫₀^{1/K} ≤ 1/K
    So: P(K) ≤ I ≤ P(K) + 1/K

    StirlingBridge: P(K) → ln(2π) − γ − 1
    Squeeze: I = ln(2π) − γ − 1  ∎

  Created: April 12, 2026, 7:20 PM MDT (The Squeeze)
-/

import Cathedral.Analysis.StirlingBridge
import Cathedral.Analysis.PiecewiseFTC
import Mathlib.MeasureTheory.Integral.IntervalIntegral.Basic
import Mathlib.MeasureTheory.Function.Floor
import Mathlib.Topology.Order.Basic
import Mathlib.Topology.Separation.Hausdorff

noncomputable section
open Real MeasureTheory Filter

namespace Cathedral.Vasyunin.SqueezeElimination

-- ════════════════════════════════════════════════
-- §1. THE TAIL BOUND: ‖∫₀^ε {1/u}²‖ ≤ ε
-- ════════════════════════════════════════════════

/-- The tail integral ∫₀^ε {1/u}² du is bounded by ε.
    Proof: the integrand is bounded by 1 (since 0 ≤ fract < 1),
    so the integral is bounded by the interval length. -/
lemma fract_sq_tail_bound (ε : ℝ) (hε : 0 ≤ ε) :
    ‖∫ x in (0:ℝ)..ε, Int.fract (1 / x) * Int.fract (1 / x)‖ ≤ ε := by
  have h : ∀ x ∈ Set.uIoc (0:ℝ) ε,
      ‖Int.fract (1 / x) * Int.fract (1 / x)‖ ≤ 1 := by
    intro x _
    rw [Real.norm_eq_abs, abs_of_nonneg (mul_nonneg (Int.fract_nonneg _) (Int.fract_nonneg _))]
    nlinarith [Int.fract_nonneg (1/x), Int.fract_lt_one (1/x)]
  calc ‖∫ x in (0:ℝ)..ε, Int.fract (1/x) * Int.fract (1/x)‖
      ≤ 1 * |ε - 0| := intervalIntegral.norm_integral_le_of_norm_le_const h
    _ = ε := by rw [sub_zero, abs_of_nonneg hε, one_mul]

/-- The tail integral is nonneg. -/
lemma fract_sq_tail_nonneg (ε : ℝ) (hε : 0 ≤ ε) :
    0 ≤ ∫ x in (0:ℝ)..ε, Int.fract (1 / x) * Int.fract (1 / x) := by
  apply intervalIntegral.integral_nonneg hε
  intros x _
  exact mul_nonneg (Int.fract_nonneg _) (Int.fract_nonneg _)

-- ════════════════════════════════════════════════
-- §2. INTERVAL SPLITTING: I = tail + P(K)
-- ════════════════════════════════════════════════

/-- {1/u}² is interval integrable on any bounded interval. -/
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

/-- Splitting: ∫₀¹ = ∫₀^{1/K} + ∫_{1/K}^{1}. -/
lemma integral_split (K : ℕ) (_hK : 1 ≤ K) :
    ∫ x in (0:ℝ)..(1:ℝ), Int.fract (1 / x) * Int.fract (1 / x) =
    (∫ x in (0:ℝ)..(1 / (K:ℝ)),
      Int.fract (1 / x) * Int.fract (1 / x)) +
    (∫ x in (1 / (K:ℝ))..(1:ℝ),
      Int.fract (1 / x) * Int.fract (1 / x)) := by
  rw [← intervalIntegral.integral_add_adjacent_intervals
    (fract_sq_intervalIntegrable 0 (1 / (K:ℝ)))
    (fract_sq_intervalIntegrable (1 / (K:ℝ)) 1)]

-- ════════════════════════════════════════════════
-- §3. THE SQUEEZE THEOREM
-- ════════════════════════════════════════════════

-- For the squeeze, we need to connect ∫_{1/K}^{1} {1/u}² to
-- StirlingBridge.partialSum K. This is the piecewise linkage.
-- The StirlingBridge proves:
--   partialSum K = Σ_{n=0}^{K-2} [-2(n+1)·log(1+1/(n+1)) + 2 - 1/(n+2)]
-- The GramDiag Archive proves:
--   ∫_{1/(K)}^{1} {1/u}² = same piecewise sum
-- NOTE: The piecewise linkage is proved in PiecewiseFTC.lean (imported above).

-- AXIOM ELIMINATED: integral_eq_partialSum is now a THEOREM
-- proved in PiecewiseFTC.lean via piecewise FTC + StirlingBridge matching.
-- Import: Cathedral.Vasyunin.Cotangent.PiecewiseFTC provides
--   PiecewiseFTC.integral_eq_partialSum (K : ℕ) (hK : K ≥ 2)
-- We re-export under our local namespace:
private theorem integral_eq_partialSum (K : ℕ) (hK : K ≥ 2) :
    ∫ x in (1 / (K:ℝ))..(1:ℝ),
      Int.fract (1 / x) * Int.fract (1 / x) =
    StirlingBridge.partialSum K :=
  Cathedral.Vasyunin.PiecewiseFTC.integral_eq_partialSum K hK

/-- **THE SQUEEZE THEOREM ELIMINATION**:
    ∫₀¹ {1/u}² du = ln(2π) − γ − 1.

    Proof: Let I = ∫₀¹. By splitting at 1/K:
      I = ∫₀^{1/K} + P(K)
    The tail satisfies 0 ≤ ∫₀^{1/K} ≤ 1/K. Therefore:
      P(K) ≤ I ≤ P(K) + 1/K
    Since P(K) → ln(2π) − γ − 1 and 1/K → 0, by squeeze, I = ln(2π) − γ − 1.

    This replaces DiagonalBridge.fract_sq_integral_value. -/
theorem fract_sq_integral_value :
    ∫ u in (0:ℝ)..(1:ℝ),
      (Int.fract (1 / u) * Int.fract (1 / u) : ℝ) =
    Real.log (2 * Real.pi) - eulerMascheroniConstant - 1 := by
  set g : ℝ → ℝ := fun x => Int.fract (1 / x) * Int.fract (1 / x) with hg_def
  set I := ∫ u in (0:ℝ)..(1:ℝ), g u
  set L := Real.log (2 * Real.pi) - eulerMascheroniConstant - 1

  -- Step 1: For K ≥ 2, splitting at 1/K gives I = tail + P(K)
  have hsplit : ∀ K : ℕ, 2 ≤ K →
      I = (∫ x in (0:ℝ)..(1 / (K:ℝ)), g x) +
          StirlingBridge.partialSum K := by
    intro K hK
    rw [show I = (∫ x in (0:ℝ)..(1 / (K:ℝ)), g x) +
        (∫ x in (1 / (K:ℝ))..(1:ℝ), g x) from by
      exact integral_split K (by omega)]
    congr 1
    exact integral_eq_partialSum K hK

  -- Step 2: The tail is bounded: 0 ≤ tail ≤ 1/K
  have htail_bound : ∀ K : ℕ, 1 ≤ K →
      0 ≤ (∫ x in (0:ℝ)..(1 / (K:ℝ)), g x) ∧
      (∫ x in (0:ℝ)..(1 / (K:ℝ)), g x) ≤ 1 / (K:ℝ) := by
    intro K hK
    constructor
    · exact fract_sq_tail_nonneg (1 / (K:ℝ)) (by positivity)
    · have hbound := fract_sq_tail_bound (1 / (K:ℝ)) (by positivity)
      rwa [Real.norm_eq_abs,
        abs_of_nonneg (fract_sq_tail_nonneg (1 / (K:ℝ)) (by positivity))] at hbound

  -- Step 3: Therefore P(K) ≤ I ≤ P(K) + 1/K
  have hle_lower : ∀ K : ℕ, 2 ≤ K →
      StirlingBridge.partialSum K ≤ I := by
    intro K hK
    rw [hsplit K hK]
    linarith [(htail_bound K (by omega)).1]

  have hle_upper : ∀ K : ℕ, 2 ≤ K →
      I ≤ StirlingBridge.partialSum K + 1 / (K:ℝ) := by
    intro K hK
    rw [hsplit K hK]
    linarith [(htail_bound K (by omega)).2]

  -- Step 4: Squeeze theorem
  -- Both StirlingBridge.partialSum K and partialSum K + 1/K → L
  have h_lower_tends : Tendsto StirlingBridge.partialSum atTop (nhds L) :=
    StirlingBridge.tendsto_partialSum

  have h_upper_tends : Tendsto (fun K => StirlingBridge.partialSum K + 1 / (K:ℝ))
      atTop (nhds L) := by
    have : Tendsto (fun K : ℕ => (1:ℝ) / (K:ℝ)) atTop (nhds 0) := by
      simp only [one_div]
      exact tendsto_inv_atTop_zero.comp (tendsto_natCast_atTop_atTop)
    convert h_lower_tends.add this using 1
    simp [L]

  -- The constant sequence (fun _ => I) is squeezed between these
  have h_squeeze : Tendsto (fun _ : ℕ => I) atTop (nhds L) := by
    apply tendsto_of_tendsto_of_tendsto_of_le_of_le' h_lower_tends h_upper_tends
    · filter_upwards [Ioi_mem_atTop 1] with K (hK : 1 < K)
      exact hle_lower K hK
    · filter_upwards [Ioi_mem_atTop 1] with K (hK : 1 < K)
      exact hle_upper K hK

  -- Extract equality from unique limits
  exact tendsto_nhds_unique tendsto_const_nhds h_squeeze

end Cathedral.Vasyunin.SqueezeElimination

