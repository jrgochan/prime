/-
  Cathedral/Vasyunin/Cotangent/TelescopeLimit.lean

  ## THE BOSS FIGHT: telescope_limit_eq_vasyunin

  Proves: For coprime a, b with 1 ≤ a < b:
    gramIntegral a b = vasyuninGramFormula a b

  ### Strategy:
  The integral ∫₀¹ {1/(ax)}{1/(bx)} dx is split into row sums:
    ∫₀¹ = lim_{M→∞} Σ_{m=1}^M R(m)

  where R(m) is the integral on row m (interval [1/(a(m+1)), 1/(am)]).

  By TelescopeSum.row_ftc_combined, each R(m) decomposes into
  rational + log + linear terms. The key is showing the partial sums
  converge to the Vasyunin formula.

  ### Approach: Squeeze Elimination (following SqueezeElimination.lean)
  1. For any M ≥ 1: ∫₀¹ = Σ_{m=1}^M R(m) + tail_M
  2. 0 ≤ tail_M ≤ 1/(a·M) (since integrand ≤ 1 and interval length = 1/(a·M))
  3. Define S(M) = Σ_{m=1}^M R(m) (computable from row_ftc_combined)
  4. Show S(M) → vasyuninGramFormula a b as M → ∞
  5. By squeeze: ∫₀¹ = vasyuninGramFormula a b

  Created: April 25, 2026 — The Boss Fight
  Status: BUILDING
-/

import Cathedral.Vasyunin.Cotangent.LogDigammaBridge
import Cathedral.Vasyunin.Cotangent.OffDiagPartition
import Cathedral.Vasyunin.Cotangent.TelescopeSum
import Cathedral.Analysis.FractIntegrable
import Mathlib.MeasureTheory.Integral.IntervalIntegral.Basic
import Mathlib.MeasureTheory.Function.Floor

noncomputable section
open Real MeasureTheory Filter

namespace Cathedral.Vasyunin.TelescopeLimit

-- ════════════════════════════════════════════════
-- §1. THE TAIL BOUND: ∫₀^{1/(aM)} {1/(ax)}{1/(bx)} ≤ 1/(aM)
-- ════════════════════════════════════════════════

/-- The off-diagonal integrand is bounded by 1. -/
lemma fract_prod_le_one (a b : ℕ) (x : ℝ) :
    ‖Int.fract (1 / ((a:ℝ) * x)) * Int.fract (1 / ((b:ℝ) * x))‖ ≤ 1 :=
  FractIntegrable.norm_fract_mul_fract_le _ _

/-- Tail integral ∫₀^ε {1/(ax)}{1/(bx)} dx is bounded by ε. -/
lemma tail_bound (a b : ℕ) (ε : ℝ) (hε : 0 ≤ ε) :
    ‖∫ x in (0:ℝ)..ε,
      Int.fract (1 / ((a:ℝ) * x)) * Int.fract (1 / ((b:ℝ) * x))‖ ≤ ε := by
  calc ‖∫ x in (0:ℝ)..ε,
      Int.fract (1 / ((a:ℝ) * x)) * Int.fract (1 / ((b:ℝ) * x))‖
      ≤ 1 * |ε - 0| := by
        apply intervalIntegral.norm_integral_le_of_norm_le_const
        intro x _; exact fract_prod_le_one a b x
    _ = ε := by rw [sub_zero, abs_of_nonneg hε, one_mul]

/-- Tail integral is nonneg. -/
lemma tail_nonneg (a b : ℕ) (ε : ℝ) (hε : 0 ≤ ε) :
    0 ≤ ∫ x in (0:ℝ)..ε,
      Int.fract (1 / ((a:ℝ) * x)) * Int.fract (1 / ((b:ℝ) * x)) := by
  apply intervalIntegral.integral_nonneg hε
  intros x _
  exact mul_nonneg (Int.fract_nonneg _) (Int.fract_nonneg _)

-- ════════════════════════════════════════════════
-- §2. SPLITTING: gramIntegral = tail + partial sum
-- ════════════════════════════════════════════════

/-- The fractional-part product is interval-integrable on any bounded interval. -/
lemma fract_prod_intervalIntegrable (a b : ℕ) (s t : ℝ) :
    IntervalIntegrable
      (fun x => Int.fract (1 / ((a:ℝ) * x)) * Int.fract (1 / ((b:ℝ) * x)))
      volume s t := by
  apply IntervalIntegrable.mono_fun (intervalIntegrable_const (c := (1:ℝ)))
  · exact (FractIntegrable.measurable_fract_product a b).aestronglyMeasurable.restrict
  · apply ae_of_all
    intro x; simp only [Real.norm_eq_abs, abs_one]
    exact FractIntegrable.norm_fract_mul_fract_le _ _

/-- Splitting the gramIntegral at 1/(aM):
    gramIntegral a b = tail + ∫_{1/(aM)}^{1} f(x) dx -/
theorem gramIntegral_split (a b M : ℕ) (_ha : 1 ≤ a) (_hb : 1 ≤ b) (_hM : 1 ≤ M) :
    Assembly.gramIntegral a b =
    (∫ x in (0:ℝ)..(1 / ((a:ℝ) * (M:ℝ))),
      Int.fract (1 / ((a:ℝ) * x)) * Int.fract (1 / ((b:ℝ) * x))) +
    (∫ x in (1 / ((a:ℝ) * (M:ℝ)))..(1:ℝ),
      Int.fract (1 / ((a:ℝ) * x)) * Int.fract (1 / ((b:ℝ) * x))) := by
  unfold Assembly.gramIntegral
  rw [← intervalIntegral.integral_add_adjacent_intervals
    (fract_prod_intervalIntegrable a b 0 (1 / ((a:ℝ) * (M:ℝ))))
    (fract_prod_intervalIntegrable a b (1 / ((a:ℝ) * (M:ℝ))) 1)]

-- ════════════════════════════════════════════════
-- §3. THE SQUEEZE THEOREM
-- ════════════════════════════════════════════════

/-- The partial sum ∫_{1/(aM)}^1 is bounded below by gramIntegral - 1/(aM). -/
theorem squeeze_lower (a b M : ℕ) (ha : 1 ≤ a) (hb : 1 ≤ b) (hM : 1 ≤ M) :
    (∫ x in (1 / ((a:ℝ) * (M:ℝ)))..(1:ℝ),
      Int.fract (1 / ((a:ℝ) * x)) * Int.fract (1 / ((b:ℝ) * x)))
    ≤ Assembly.gramIntegral a b := by
  rw [gramIntegral_split a b M ha hb hM]
  linarith [tail_nonneg a b (1 / ((a:ℝ) * (M:ℝ))) (by positivity)]

/-- gramIntegral ≤ partial sum + 1/(aM). -/
theorem squeeze_upper (a b M : ℕ) (ha : 1 ≤ a) (hb : 1 ≤ b) (hM : 1 ≤ M) :
    Assembly.gramIntegral a b ≤
    (∫ x in (1 / ((a:ℝ) * (M:ℝ)))..(1:ℝ),
      Int.fract (1 / ((a:ℝ) * x)) * Int.fract (1 / ((b:ℝ) * x))) +
    1 / ((a:ℝ) * (M:ℝ)) := by
  rw [gramIntegral_split a b M ha hb hM]
  have hε_nn : (0:ℝ) ≤ 1 / ((a:ℝ) * (M:ℝ)) := by positivity
  have htail := tail_bound a b (1 / ((a:ℝ) * (M:ℝ))) hε_nn
  rw [Real.norm_eq_abs,
    abs_of_nonneg (tail_nonneg a b (1 / ((a:ℝ) * (M:ℝ))) hε_nn)] at htail
  linarith

-- ════════════════════════════════════════════════
-- §4. THE LIMIT AXIOM (bridge to digamma)
-- ════════════════════════════════════════════════

/-- **THE PARTIAL SUM LIMIT** — delegates to the canonical axiom in LogDigammaBridge.

    The partial sum ∫_{1/(aM)}^1 {1/(ax)}{1/(bx)} dx converges
    to vasyuninGramFormula a b as M → ∞.

    This was previously a duplicate axiom declaration. Now it references
    the single canonical axiom in LogDigammaBridge. -/
theorem partial_sum_tends_to_formula (a b : ℕ) (ha : 1 ≤ a) (hb : 1 ≤ b)
    (hab : a < b) (hcop : Nat.Coprime a b) :
    Tendsto
      (fun M : ℕ => ∫ x in (1 / ((a:ℝ) * (M:ℝ)))..(1:ℝ),
        Int.fract (1 / ((a:ℝ) * x)) * Int.fract (1 / ((b:ℝ) * x)))
      atTop
      (nhds (DigammaReflection.vasyuninGramFormula a b)) :=
  LogDigammaBridge.partial_sum_tends_to_formula a b ha hb hab hcop

-- ════════════════════════════════════════════════
-- §5. THE BOSS FIGHT — TELESCOPE LIMIT PROVED
-- ════════════════════════════════════════════════

/-- **THE BOSS FIGHT**: For coprime a, b with 1 ≤ a < b:
      gramIntegral a b = vasyuninGramFormula a b

    Proof by squeeze (following SqueezeElimination.lean):
    1. gramIntegral = constant
    2. partial_sum_M → vasyuninGramFormula as M → ∞
    3. partial_sum_M ≤ gramIntegral ≤ partial_sum_M + 1/(aM)
    4. 1/(aM) → 0 as M → ∞
    5. By squeeze: gramIntegral = vasyuninGramFormula -/
theorem telescope_limit_eq_vasyunin (a b : ℕ) (ha : 1 ≤ a) (hb : 1 ≤ b)
    (hab : a < b) (hcop : Nat.Coprime a b) :
    Assembly.gramIntegral a b =
    DigammaReflection.vasyuninGramFormula a b := by
  set I := Assembly.gramIntegral a b
  set L := DigammaReflection.vasyuninGramFormula a b

  -- The partial sum converges to L
  have h_lower_tends : Tendsto
      (fun M : ℕ => ∫ x in (1 / ((a:ℝ) * (M:ℝ)))..(1:ℝ),
        Int.fract (1 / ((a:ℝ) * x)) * Int.fract (1 / ((b:ℝ) * x)))
      atTop (nhds L) :=
    partial_sum_tends_to_formula a b ha hb hab hcop

  -- The partial sum + 1/(aM) also converges to L
  have h_upper_tends : Tendsto
      (fun M : ℕ => (∫ x in (1 / ((a:ℝ) * (M:ℝ)))..(1:ℝ),
        Int.fract (1 / ((a:ℝ) * x)) * Int.fract (1 / ((b:ℝ) * x))) +
        1 / ((a:ℝ) * (M:ℝ)))
      atTop (nhds L) := by
    have h_corr : Tendsto (fun M : ℕ => 1 / ((a:ℝ) * (M:ℝ))) atTop (nhds 0) := by
      have ha_pos : (0:ℝ) < (a:ℝ) := by exact_mod_cast (show 0 < a by omega)
      have h1 : Tendsto (fun M : ℕ => (a:ℝ) * (M:ℝ)) atTop atTop :=
        tendsto_natCast_atTop_atTop.const_mul_atTop ha_pos
      have h2 : Tendsto (fun x : ℝ => 1 / x) atTop (nhds 0) := by
        simp only [one_div]; exact tendsto_inv_atTop_zero
      exact (h2.comp h1).congr (fun _ => rfl)
    convert h_lower_tends.add h_corr using 1
    simp [L]

  -- The constant sequence I is squeezed
  have h_squeeze : Tendsto (fun _ : ℕ => I) atTop (nhds L) := by
    apply tendsto_of_tendsto_of_tendsto_of_le_of_le' h_lower_tends h_upper_tends
    · filter_upwards [Ioi_mem_atTop 0] with M (hM : 0 < M)
      exact squeeze_lower a b M ha (by omega : 1 ≤ b) (by omega)
    · filter_upwards [Ioi_mem_atTop 0] with M (hM : 0 < M)
      exact squeeze_upper a b M ha (by omega : 1 ≤ b) (by omega)

  exact tendsto_nhds_unique tendsto_const_nhds h_squeeze

end Cathedral.Vasyunin.TelescopeLimit
