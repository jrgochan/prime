/-
  Cathedral/Vasyunin/Cotangent/DiagonalStrike.lean

  ## THE DIAGONAL STRIKE — Graduating gramIntegral for a = 1

  Proves: gramIntegral 1 b = vasyuninGramFormula 1 b
  for coprime 1 < b (which is automatic since gcd(1,b)=1).

  ### Why a = 1 is special (Gemini's "Diagonal" insight)

  For a = 1:
  1. **Strip vanishes**: ∫_{1/1}^1 = ∫_1^1 = 0 (degenerate interval)
  2. **Every row is single-tile**: tileIndex(1,b,m) = ⌊m/b⌋, and since
     b·(⌊m/b⌋+1) ≥ m+1 always holds, no b-tile boundary crosses a row.
  3. **No two-tile corrections**: actualRowIntegral = rowTerm for all m ≥ 1.
  4. **gramIntegral = tsum rowTerm**: pure series evaluation, no geometry.

  ### The analytic evaluation (§5 sub-lemmas)

  rowTerm(1,b,m) decomposes as:
    (1/b) · stirlingTerm(m) + fractCorrection(m)

  where stirlingTerm → log(2π) - γ - 1 (StirlingBridge) and
  fractCorrection converges by Dirichlet test.

  Created: May 2, 2026 (The Midnight Forge)
  Graduated: May 3, 2026 (axiom removed — FractSeriesEval has axiom-free path)
  Status: CERTIFIED (PROVED, ZERO axioms)
-/

import Cathedral.Vasyunin.Cotangent.PartialSumConvergence
import Cathedral.Vasyunin.Cotangent.IntegralEqSCombined
import Cathedral.Vasyunin.Cotangent.VasyuninAssembly
import Cathedral.Vasyunin.Cotangent.DigammaReflection
import Cathedral.Analysis.FractIntegrable
import Cathedral.Vasyunin.Cotangent.GramIntegralProof
import Cathedral.Analysis.StirlingBridge
-- import Cathedral.Vasyunin.Cotangent.AlgebraicLimit  -- REMOVED May 3: axiom no longer needed

noncomputable section
open Real MeasureTheory Filter Finset

namespace Cathedral.Vasyunin.DiagonalStrike

-- ════════════════════════════════════════════════
-- §1. STRIP VANISHES FOR a = 1
-- ════════════════════════════════════════════════

/-- For a = 1, the strip integral ∫_{1/1}^1 = ∫_1^1 = 0.
    The interval [1, 1] is degenerate (length zero). -/
theorem strip_zero_a1 (b : ℕ) :
    ∫ x in (1 / (1:ℝ))..(1:ℝ),
      Int.fract (1 / ((1:ℝ) * x)) * Int.fract (1 / ((b:ℝ) * x)) = 0 := by
  simp only [one_div, inv_one]
  exact intervalIntegral.integral_same

-- ════════════════════════════════════════════════
-- §2. EVERY ROW IS SINGLE-TILE FOR a = 1
-- ════════════════════════════════════════════════

/-- The tile index for a=1: tileIndex(1, b, m) = m/b = ⌊m/b⌋. -/
private lemma tileIndex_a1 (b m : ℕ) :
    PartialSumConvergence.tileIndex 1 b m = m / b := by
  simp [PartialSumConvergence.tileIndex]

/-- **SINGLE-TILE CONDITION**: For a=1 and b ≥ 2, every row m ≥ 1
    satisfies the single-tile condition: 1·(m+1) ≤ b·(⌊m/b⌋ + 1).

    Proof: m = b·q + r with 0 ≤ r < b. Then ⌊m/b⌋ = q.
    b·(q+1) = bq + b = m - r + b ≥ m + 1 since b > r. -/
theorem all_single_tile_a1 (b m : ℕ) (hb : 2 ≤ b) (_hm : 1 ≤ m) :
    1 * (m + 1) ≤ b * (PartialSumConvergence.tileIndex 1 b m + 1) := by
  rw [one_mul, tileIndex_a1]
  -- Need: m + 1 ≤ b * (m / b + 1)
  -- From division: m = b * (m/b) + m % b, and m % b < b
  have h_div := Nat.div_add_mod m b
  have h_mod := Nat.mod_lt m (by omega : 0 < b)
  -- b * (m/b + 1) = b * (m/b) + b = m - m%b + b
  -- m + 1 ≤ m - m%b + b ⟺ m%b + 1 ≤ b, which holds since m%b < b
  have : b * (m / b + 1) = b * (m / b) + b := by ring
  omega

-- ════════════════════════════════════════════════
-- §3. actualRowIntegral = rowTerm FOR a = 1
-- ════════════════════════════════════════════════

/-- **ROW IDENTITY**: For a=1 and b ≥ 2, every row integral equals rowTerm.
    This uses the single-tile condition (§2) with the proved
    row_integral_eq_rowTerm_single from IntegralEqSCombined. -/
theorem actual_eq_rowTerm_a1 (b m : ℕ) (hb : 2 ≤ b) (hm : 1 ≤ m) :
    PartialSumConvergence.actualRowIntegral 1 b m =
    PartialSumConvergence.rowTerm 1 b m := by
  unfold PartialSumConvergence.actualRowIntegral
  exact IntegralEqSCombined.row_integral_eq_rowTerm_single 1 b m
    (by omega) (by omega) hm (by omega)
    (all_single_tile_a1 b m hb hm)

-- ════════════════════════════════════════════════
-- §4. gramIntegral(1, b) = tsum rowTerm
-- ════════════════════════════════════════════════

/-- **INTEGRAL = TSUM**: gramIntegral(1,b) = Σ' rowTerm(1,b,n+1).

    From GramIntegralProof.gramIntegral_eq_strip_plus_tsum:
      gramIntegral = strip + Σ' actualRowIntegral(n+1)
    For a=1: strip = 0 (§1) and actualRowIntegral = rowTerm (§3).
    So gramIntegral = Σ' rowTerm(n+1). -/
theorem gramIntegral_eq_tsum_rowTerm_a1 (b : ℕ) (hb : 2 ≤ b) :
    Assembly.gramIntegral 1 b =
    ∑' n, PartialSumConvergence.rowTerm 1 b (n + 1) := by
  -- Step 1: gramIntegral = strip + tsum actualRowIntegral
  have h_split := GramIntegralProof.gramIntegral_eq_strip_plus_tsum 1 b
    (by omega) (by omega) (by omega)
  -- Step 2: The strip integral is over [1/1, 1] = [1, 1], which is degenerate.
  -- The bounds 1/↑1 and 1 are both 1, so any integral vanishes.
  -- We need to match the exact form from h_split, which uses fProd (private).
  -- Use: h_split says gramIntegral = strip + tsum, and strip = ∫_1^1 ... = 0.
  -- Since fProd is private, we access it through h_split's structure.
  rw [h_split]
  -- Goal: strip + ∑' n, actualRowIntegral(n+1) = ∑' n, rowTerm(n+1)
  -- strip is ∫ x in (1/↑1)..(1:ℝ), fProd 1 b x = ∫ x in 1..1, ... = 0
  have h_strip_zero : ∀ f : ℝ → ℝ, ∫ x in (1 / (1:ℝ))..(1:ℝ), f x = 0 := by
    intro f
    simp only [one_div, inv_one]
    exact intervalIntegral.integral_same
  simp only [Nat.cast_one, h_strip_zero, zero_add]
  -- Goal: ∑' n, actualRowIntegral 1 b (n+1) = ∑' n, rowTerm 1 b (n+1)
  exact tsum_congr (fun n => actual_eq_rowTerm_a1 b (n + 1) hb (by omega))

-- ════════════════════════════════════════════════
-- §5. THE ANALYTIC EVALUATION — Sub-Lemma Structure
-- ════════════════════════════════════════════════

-- The remaining goal: show ∑' n, rowTerm(1, b, n+1) = vasyuninGramFormula(1, b).
--
-- Decomposition of rowTerm(1, b, m) for a = 1:
--
--   rowTerm(1, b, m) = 1/b
--     - (⌊m/b⌋ + m/b) · log((m+1)/m)
--     + ⌊m/b⌋/(m+1)
--
-- Using ⌊m/b⌋ = m/b - {m/b}, this decomposes as:
--
--   = (1/b) · [1 + m/(m+1) - 2m · log((m+1)/m)]  ← "Stirling term" / b
--     + {m/b} · [log((m+1)/m) - 1/(m+1)]           ← "fract correction"
--
-- Sub-lemma 5a: This algebraic identity
-- Sub-lemma 5b: Σ stirlingTerm → log(2π) - γ - 1 (StirlingBridge)
-- Sub-lemma 5c: Σ fractCorrection converges (Dirichlet test)
-- Sub-lemma 5d: Limit identification with cotangent sums
-- Sub-lemma 5e: Assembly

-- ────────────────────────────────────────────────
-- §5a. ROW TERM DECOMPOSITION
-- ────────────────────────────────────────────────

/-- The Stirling term: the piece of rowTerm that telescopes via Stirling.
    stirlingTerm(m) = 1 + m/(m+1) - 2m · log((m+1)/m)
                    = -2m · log(1 + 1/m) + 2 - 1/(m+1)

    Note: this is exactly the term in StirlingBridge.partialSum_eq_series_sum'
    shifted by index (with m = n+1). -/
def stirlingTerm (m : ℕ) : ℝ :=
  -2 * (m:ℝ) * Real.log (((m:ℝ) + 1) / (m:ℝ)) + 2 - 1 / ((m:ℝ) + 1)

/-- The fractional correction: depends on {m/b}. -/
def fractCorrection (b m : ℕ) : ℝ :=
  Int.fract ((m:ℝ) / (b:ℝ)) *
    (Real.log (((m:ℝ) + 1) / (m:ℝ)) - 1 / ((m:ℝ) + 1))

/-- **SUB-LEMMA 5a**: rowTerm(1,b,m) = (1/b)·stirlingTerm(m) + fractCorrection(b,m)
    for m ≥ 1. -/
theorem rowTerm_decompose_a1 (b m : ℕ) (hb : 1 ≤ b) (hm : 1 ≤ m) :
    PartialSumConvergence.rowTerm 1 b m =
    (1 / (b:ℝ)) * stirlingTerm m + fractCorrection b m := by
  unfold PartialSumConvergence.rowTerm stirlingTerm fractCorrection
  rw [tileIndex_a1]
  -- Need: ⌊m/b⌋ = m/b - {m/b}  (floor + fract identity)
  have hb_pos : (0:ℝ) < (b:ℝ) := Nat.cast_pos.mpr (by omega)
  have hb_ne : (b:ℝ) ≠ 0 := ne_of_gt hb_pos
  have hm_pos : (0:ℝ) < (m:ℝ) := Nat.cast_pos.mpr (by omega)
  have hm_ne : (m:ℝ) ≠ 0 := ne_of_gt hm_pos
  -- Floor-fract identity: ↑⌊m/b⌋ = m/b - {m/b}
  have h_floor : (↑(m / b) : ℝ) = (m:ℝ) / (b:ℝ) - Int.fract ((m:ℝ) / (b:ℝ)) := by
    have h_nn : 0 ≤ (m:ℝ) / (b:ℝ) := by positivity
    have h1 : Nat.floor ((m:ℝ) / (b:ℝ)) = m / b := Nat.floor_div_eq_div m b
    have h2 : (↑(m / b) : ℝ) = (↑(Nat.floor ((m:ℝ) / (b:ℝ))) : ℝ) := by rw [h1]
    rw [h2, natCast_floor_eq_intCast_floor h_nn]
    linarith [Int.floor_add_fract ((m:ℝ) / (b:ℝ))]
  rw [h_floor]
  -- Now pure algebra: clear fractions and simplify
  field_simp
  ring

-- ────────────────────────────────────────────────
-- §5b. STIRLING TERM LIMIT
-- ────────────────────────────────────────────────

/-- **SUB-LEMMA 5b**: The partial sum of stirlingTerms converges to
    log(2π) - γ - 1, using StirlingBridge.tendsto_partialSum.

    Σ_{n=0}^{K-2} stirlingTerm(n+1) = P(K) (Stirling partialSum)
    where P(K) → log(2π) - γ - 1. -/
theorem stirlingTerm_partial_sum_eq (K : ℕ) (hK : 2 ≤ K) :
    ∑ n ∈ Finset.range (K - 1), stirlingTerm (n + 1) =
    StirlingBridge.partialSum K := by
  rw [StirlingBridge.partialSum_eq_series_sum K hK]
  apply Finset.sum_congr rfl
  intro n _
  -- Both sides are:
  --   -2 * (n+1) * log((n+2)/(n+1)) + 2 - 1/(n+2)
  -- but written differently. Show they're equal by rewriting to common form.
  simp only [stirlingTerm]
  have hn1_ne : ((n:ℝ) + 1) ≠ 0 := by positivity
  -- Rewrite the StirlingBridge term: 1 + 1/(n+1) = (n+2)/(n+1)
  rw [show 1 + 1 / ((n:ℝ) + 1) = ((n:ℝ) + 2) / ((n:ℝ) + 1) from by field_simp; ring]
  -- Now both sides have log((n+2)/(n+1)), just with different cast representations
  push_cast
  ring_nf

/-- h(x) = log(x) - (x-1) + (x-1)²/2. We show h ≥ 0 on [1,∞) to get second-order log bound.
    (Replicated from PartialSumConvergence, where it's private.) -/
private noncomputable def logBoundH (x : ℝ) : ℝ := Real.log x - (x - 1) + (x - 1)^2 / 2

private lemma logBoundH_hasDerivAt (x : ℝ) (hx : 0 < x) :
    HasDerivAt logBoundH (x⁻¹ + x - 2) x := by
  have hne : x ≠ 0 := ne_of_gt hx
  have hlog : HasDerivAt (fun y => Real.log y) x⁻¹ x := hasDerivAt_log hne
  have hlin : HasDerivAt (fun y => y - 1) 1 x := by
    convert (hasDerivAt_id x).sub (hasDerivAt_const x 1) using 1; ring
  have hsq : HasDerivAt (fun y => (y - 1)^2 / 2) (x - 1) x := by
    have := hlin.pow 2 |>.div_const 2
    convert this using 1; simp
  have := (hlog.sub hlin).add hsq
  show HasDerivAt logBoundH (x⁻¹ + x - 2) x
  convert this using 1; ring

/-- `logBoundH(x) = log(x) - (x-1) + (x-1)²/2 ≥ 0` on `[1,∞)`, by monotonicity from
    `logBoundH(1) = 0` and `logBoundH'(x) = x⁻¹ + x - 2 ≥ 0` for `x ≥ 1`. -/
private lemma logBoundH_nonneg {x : ℝ} (hx : 1 ≤ x) : 0 ≤ logBoundH x := by
  have hne : ∀ y : ℝ, y ∈ Set.Ici (1:ℝ) → y ≠ 0 :=
    fun y hy => ne_of_gt (lt_of_lt_of_le one_pos hy)
  have hpos : ∀ y : ℝ, y ∈ Set.Ici (1:ℝ) → 0 < y :=
    fun y hy => lt_of_lt_of_le one_pos hy
  have hmono : MonotoneOn logBoundH (Set.Ici 1) :=
    monotoneOn_of_deriv_nonneg (convex_Ici 1)
      (((continuousOn_log.mono hne).sub (continuousOn_id.sub continuousOn_const)).add
        (((continuousOn_id.sub continuousOn_const).pow 2).div_const 2))
      (fun y hy => (logBoundH_hasDerivAt y (hpos y (interior_subset hy))).differentiableAt.differentiableWithinAt)
      (fun y hy => by
        rw [(logBoundH_hasDerivAt y (hpos y (interior_subset hy))).deriv]
        have hyp := hpos y (interior_subset hy)
        nlinarith [sq_nonneg (y - 1), inv_pos.mpr hyp,
                    mul_inv_cancel₀ (ne_of_gt hyp)])
  have h1 : logBoundH 1 = 0 := by simp [logBoundH, Real.log_one]
  linarith [hmono (Set.mem_Ici.mpr le_rfl) (Set.mem_Ici.mpr hx) hx]

/-- **Log second-order lower bound**: log((m+1)/m) ≥ 1/m - 1/(2m²).
    Proved via logBoundH monotonicity. -/
private lemma log_ge_second_order' (m : ℕ) (hm : 1 ≤ m) :
    1 / (m:ℝ) - 1 / (2 * (m:ℝ)^2) ≤ Real.log (((m:ℝ) + 1) / (m:ℝ)) := by
  have hm_pos : (0:ℝ) < (m:ℝ) := Nat.cast_pos.mpr (by omega)
  have hx_ge : 1 ≤ ((m:ℝ) + 1) / (m:ℝ) := by rw [le_div_iff₀ hm_pos]; linarith
  have hh := logBoundH_nonneg hx_ge
  simp only [logBoundH] at hh
  have hsub : ((m:ℝ) + 1) / (m:ℝ) - 1 = 1 / (m:ℝ) := by field_simp; ring
  rw [hsub] at hh
  have hsq : (1 / (m:ℝ))^2 / 2 = 1 / (2 * (m:ℝ)^2) := by field_simp
  linarith

/-- **Log upper bound**: log((m+1)/m) ≤ 1/m. -/
private lemma log_le_inv' (m : ℕ) (hm : 1 ≤ m) :
    Real.log (((m:ℝ) + 1) / (m:ℝ)) ≤ 1 / (m:ℝ) := by
  have hm_pos : (0:ℝ) < (m:ℝ) := Nat.cast_pos.mpr (by omega)
  have h := log_le_sub_one_of_pos (show (0:ℝ) < ((m:ℝ) + 1) / (m:ℝ) by positivity)
  linarith [show ((m:ℝ) + 1) / (m:ℝ) - 1 = 1 / (m:ℝ) from by field_simp; ring]

/-- stirlingTerm(m) ≤ 1/(m(m+1)) for m ≥ 1.
    Upper bound uses L ≥ 1/m - 1/(2m²). -/
private lemma stirlingTerm_upper (m : ℕ) (hm : 1 ≤ m) :
    stirlingTerm m ≤ 1 / ((m:ℝ) * ((m:ℝ) + 1)) := by
  have hm_pos : (0:ℝ) < (m:ℝ) := Nat.cast_pos.mpr (by omega)
  have hm1_pos : (0:ℝ) < (m:ℝ) + 1 := by linarith
  have hL_lower := log_ge_second_order' m hm
  -- stirlingTerm = -2m·L + 2 - 1/(m+1)
  -- With L ≥ 1/m - 1/(2m²): 2m·L ≥ 2 - 1/m
  -- So stirlingTerm ≤ 2 - 1/(m+1) - (2 - 1/m) = 1/m - 1/(m+1) = 1/(m(m+1))
  simp only [stirlingTerm]
  -- Goal: -2 * m * L + 2 - 1 / (m + 1) ≤ 1 / (m * (m + 1))
  -- Equivalently: 2 - 1/(m+1) - 1/(m(m+1)) ≤ 2m·L
  -- i.e., 2 - (m+1+1)/(m(m+1)) = 2 - (m+2)/(m(m+1)) ≤ 2m·L
  -- From L ≥ 1/m - 1/(2m²): 2m·L ≥ 2 - 1/m
  -- Need: 2 - (m+2)/(m(m+1)) ≤ 2 - 1/m
  -- i.e., 1/m ≤ (m+2)/(m(m+1))
  -- i.e., (m+1) ≤ m+2. ✓
  have h1 : 1 / ((m:ℝ) * ((m:ℝ) + 1)) = 1 / (m:ℝ) - 1 / ((m:ℝ) + 1) := by
    field_simp; ring
  rw [h1]
  -- Goal: -2 * m * L + 2 - 1/(m+1) ≤ 1/m - 1/(m+1)
  -- Equivalently: 2 - 1/m ≤ 2*m*L
  -- From hL_lower: L ≥ 1/m - 1/(2m²), so 2m*L ≥ 2m*(1/m - 1/(2m²)) = 2 - 1/m
  have key : 2 - 1 / (m:ℝ) ≤ 2 * (m:ℝ) * Real.log (((m:ℝ) + 1) / (m:ℝ)) := by
    have : 2 * (m:ℝ) * (1 / (m:ℝ) - 1 / (2 * (m:ℝ)^2)) = 2 - 1 / (m:ℝ) := by
      field_simp
    linarith [mul_le_mul_of_nonneg_left hL_lower (show (0:ℝ) ≤ 2 * (m:ℝ) from by positivity)]
  linarith
/-- g(x) = x - 1/x - 2·log(x). We show g ≥ 0 on [1,∞) via g'=(x-1)²/x² ≥ 0, g(1)=0.
    (Replicated from PartialSumConvergence, where it's private.) -/
private noncomputable def logBoundG (x : ℝ) : ℝ := x - x⁻¹ - 2 * Real.log x

private lemma logBoundG_hasDerivAt (x : ℝ) (hx : x ≠ 0) :
    HasDerivAt logBoundG ((x - 1)^2 / x^2) x := by
  have h : HasDerivAt logBoundG (1 - (-(x ^ 2)⁻¹) - 2 * x⁻¹) x :=
    ((hasDerivAt_id x).sub (hasDerivAt_inv hx)).sub ((hasDerivAt_log hx).const_mul 2)
  convert h using 1; field_simp; ring

/-- `logBoundG(x) = x - x⁻¹ - 2·log(x) ≥ 0` on `[1,∞)`, by monotonicity from
    `logBoundG(1) = 0` and `logBoundG'(x) = (x-1)²/x² ≥ 0`. -/
private lemma logBoundG_nonneg {x : ℝ} (hx : 1 ≤ x) : 0 ≤ logBoundG x := by
  have hne : ∀ y : ℝ, y ∈ Set.Ici (1:ℝ) → y ≠ 0 :=
    fun y hy => ne_of_gt (lt_of_lt_of_le one_pos hy)
  have hmono : MonotoneOn logBoundG (Set.Ici 1) :=
    monotoneOn_of_deriv_nonneg (convex_Ici 1)
      ((continuousOn_id.sub (continuousOn_inv₀.mono hne)).sub
        (continuousOn_const.mul (continuousOn_log.mono hne)))
      (fun y hy => (logBoundG_hasDerivAt y (hne y (interior_subset hy))).differentiableAt.differentiableWithinAt)
      (fun y hy => by rw [(logBoundG_hasDerivAt y (hne y (interior_subset hy))).deriv]; positivity)
  have g1 : logBoundG 1 = 0 := by simp [logBoundG, Real.log_one]
  linarith [hmono (Set.mem_Ici.mpr le_rfl) (Set.mem_Ici.mpr hx) hx]

/-- **AM log upper bound**: log((m+1)/m) ≤ (2m+1)/(2m(m+1)).
    This is the tightest first-order upper bound, giving 2m·L ≤ 2 - 1/(m+1). -/
private lemma log_le_am' (m : ℕ) (hm : 1 ≤ m) :
    Real.log (((m:ℝ) + 1) / (m:ℝ)) ≤
    (2*(m:ℝ) + 1) / (2*(m:ℝ)*((m:ℝ) + 1)) := by
  have hm_pos : (0:ℝ) < (m:ℝ) := Nat.cast_pos.mpr (by omega)
  have hx_ge : 1 ≤ ((m:ℝ) + 1) / (m:ℝ) := by rw [le_div_iff₀ hm_pos]; linarith
  have hg := logBoundG_nonneg hx_ge
  simp only [logBoundG, inv_div] at hg
  -- g(x) ≥ 0 means x - m/(m+1) - 2·log(x) ≥ 0, so 2·log(x) ≤ x - m/(m+1)
  -- = (m+1)/m - m/(m+1) = (2m+1)/(m(m+1))
  suffices 2 * Real.log (((m:ℝ) + 1) / (m:ℝ)) ≤
      2 * ((2*(m:ℝ) + 1) / (2*(m:ℝ)*((m:ℝ) + 1))) by linarith
  have : 2 * ((2*(m:ℝ) + 1) / (2*(m:ℝ)*((m:ℝ) + 1))) =
      (2*(m:ℝ) + 1) / ((m:ℝ) * ((m:ℝ) + 1)) := by field_simp
  rw [this]
  have heq : ((m:ℝ) + 1) / (m:ℝ) - (m:ℝ) / ((m:ℝ) + 1) =
      (2*(m:ℝ) + 1) / ((m:ℝ) * ((m:ℝ) + 1)) := by field_simp; ring
  linarith

/-- stirlingTerm(m) ≥ 0 for m ≥ 1.
    From log_le_am': 2m·log((m+1)/m) ≤ (2m+1)/(m+1) = 2 - 1/(m+1),
    so stirlingTerm = 2 - 1/(m+1) - 2m·L ≥ 0. -/
private lemma stirlingTerm_nonneg (m : ℕ) (hm : 1 ≤ m) :
    0 ≤ stirlingTerm m := by
  have hm_pos : (0:ℝ) < (m:ℝ) := Nat.cast_pos.mpr (by omega)
  have hm1_pos : (0:ℝ) < (m:ℝ) + 1 := by linarith
  have hL := log_le_am' m hm
  simp only [stirlingTerm]
  -- Need: 0 ≤ -2*m*L + 2 - 1/(m+1), i.e., 2*m*L ≤ 2 - 1/(m+1)
  have key : 2 * (m:ℝ) * Real.log (((m:ℝ) + 1) / (m:ℝ)) ≤ 2 - 1 / ((m:ℝ) + 1) := by
    have : 2 * (m:ℝ) * ((2*(m:ℝ) + 1) / (2*(m:ℝ)*((m:ℝ) + 1))) =
        (2*(m:ℝ) + 1) / ((m:ℝ) + 1) := by field_simp
    have : (2*(m:ℝ) + 1) / ((m:ℝ) + 1) = 2 - 1 / ((m:ℝ) + 1) := by field_simp; ring
    linarith [mul_le_mul_of_nonneg_left hL (show (0:ℝ) ≤ 2 * (m:ℝ) from by positivity)]
  linarith


/-- The Stirling series converges (comparison with 1/n²). -/
theorem stirlingTerm_summable :
    Summable (fun n : ℕ => stirlingTerm (n + 1)) := by
  -- Dominator: 1/(n+1)²
  have h_dom : Summable (fun n : ℕ => (1:ℝ) / (↑(n + 1)) ^ 2) := by
    rw [show (fun n : ℕ => (1:ℝ) / (↑(n + 1)) ^ 2) =
        (fun n : ℕ => (fun m : ℕ => (1:ℝ) / (m:ℝ) ^ 2) (n + 1)) from by
      ext n; push_cast; ring_nf]
    exact (summable_nat_add_iff 1).mpr
      (summable_one_div_nat_pow.mpr (show 1 < 2 by norm_num))
  apply Summable.of_nonneg_of_le
  · intro n; exact stirlingTerm_nonneg (n + 1) (by omega)
  · -- stirlingTerm(n+1) ≤ 1/(n+1)²
    intro n
    have h_upper := stirlingTerm_upper (n + 1) (by omega)
    calc stirlingTerm (n + 1)
        ≤ 1 / ((↑(n+1):ℝ) * (↑(n+1) + 1)) := h_upper
      _ ≤ 1 / (↑(n + 1)) ^ 2 := by
          apply div_le_div_of_nonneg_left (by norm_num : (0:ℝ) ≤ 1) (by positivity)
          have : (0:ℝ) ≤ (n:ℝ) := Nat.cast_nonneg n
          push_cast; nlinarith
  · exact h_dom

/-- The Stirling series sums to log(2π) - γ - 1. -/
theorem stirlingTerm_hasSum :
    HasSum (fun n : ℕ => stirlingTerm (n + 1))
      (Real.log (2 * Real.pi) - eulerMascheroniConstant - 1) := by
  have hS := stirlingTerm_summable
  -- Show tsum = target via limit identification, then use Summable.hasSum
  have h_tsum : ∑' n, stirlingTerm (n + 1) =
      Real.log (2 * Real.pi) - eulerMascheroniConstant - 1 := by
    apply tendsto_nhds_unique hS.hasSum.tendsto_sum_nat
    -- Connect partial sums to StirlingBridge.partialSum(N+1) for N ≥ 1
    -- Using the already-proved stirlingTerm_partial_sum_eq
    have h_eq : ∀ N : ℕ, 1 ≤ N →
        ∑ n ∈ Finset.range N, stirlingTerm (n + 1) =
        StirlingBridge.partialSum (N + 1) := by
      intro N hN
      -- stirlingTerm_partial_sum_eq shows Σ_{range (K-1)} = P(K)
      -- with K = N+1 ≥ 2: Σ_{range N} = P(N+1)
      rw [show N = (N + 1) - 1 from by omega]
      exact stirlingTerm_partial_sum_eq (N + 1) (by omega)
    -- Now: P(N+1) → target. Need Tendsto (fun N => P(N+1)) atTop (nhds target)
    have h_shift : Tendsto (fun N => StirlingBridge.partialSum (N + 1)) atTop
        (nhds (Real.log (2 * Real.pi) - eulerMascheroniConstant - 1)) :=
      StirlingBridge.tendsto_partialSum.comp
        (tendsto_atTop_atTop.mpr (fun b => ⟨b, fun n hn => by omega⟩))
    exact h_shift.congr' (by
      filter_upwards [Ioi_mem_atTop 0] with N (hN : 0 < N)
      exact (h_eq N (by omega)).symm)
  exact h_tsum ▸ hS.hasSum

-- ────────────────────────────────────────────────
-- §5c. FRACT CORRECTION CONVERGENCE
-- ────────────────────────────────────────────────

/-- The log-reciprocal gap is nonneg and bounded:
    0 ≤ log((m+1)/m) - 1/(m+1) ≤ 1/(m(m+1)). -/
private lemma log_gap_bound (m : ℕ) (hm : 1 ≤ m) :
    0 ≤ Real.log (((m:ℝ) + 1) / (m:ℝ)) - 1 / ((m:ℝ) + 1) ∧
    Real.log (((m:ℝ) + 1) / (m:ℝ)) - 1 / ((m:ℝ) + 1) ≤
      1 / ((m:ℝ) * ((m:ℝ) + 1)) := by
  have hm_pos : (0:ℝ) < (m:ℝ) := Nat.cast_pos.mpr (by omega)
  have hm1_pos : (0:ℝ) < (m:ℝ) + 1 := by linarith
  constructor
  · -- log((m+1)/m) ≥ 1/(m+1): from one_sub_inv_le_log
    have h := one_sub_inv_le_log_of_pos (show (0:ℝ) < ((m:ℝ) + 1) / (m:ℝ) by positivity)
    rw [inv_div] at h
    linarith [show 1 - (m:ℝ) / ((m:ℝ) + 1) = 1 / ((m:ℝ) + 1) from by field_simp; ring]
  · -- log((m+1)/m) ≤ 1/m, so gap ≤ 1/m - 1/(m+1) = 1/(m(m+1))
    have hL := log_le_inv' m hm
    linarith [show 1 / (m:ℝ) - 1 / ((m:ℝ) + 1) = 1 / ((m:ℝ) * ((m:ℝ) + 1)) from
      by field_simp; ring]

/-- **SUB-LEMMA 5c**: The fract correction series converges absolutely.

    fractCorrection(b,m) = {m/b} · (log((m+1)/m) - 1/(m+1))

    Bound: |fractCorrection| ≤ 1 · 1/(m(m+1)) ≤ 1/m² since |{·}| < 1
    and the gap is bounded by 1/(m(m+1)). -/
theorem fractCorrection_summable (b : ℕ) (_hb : 2 ≤ b) :
    Summable (fun n : ℕ => fractCorrection b (n + 1)) := by
  -- Dominator: 1/(n+1)²
  have h_dom : Summable (fun n : ℕ => (1:ℝ) / (↑(n + 1)) ^ 2) := by
    rw [show (fun n : ℕ => (1:ℝ) / (↑(n + 1)) ^ 2) =
        (fun n : ℕ => (fun m : ℕ => (1:ℝ) / (m:ℝ) ^ 2) (n + 1)) from by
      ext n; push_cast; ring_nf]
    exact (summable_nat_add_iff 1).mpr
      (summable_one_div_nat_pow.mpr (show 1 < 2 by norm_num))
  apply Summable.of_nonneg_of_le
  · -- fractCorrection ≥ 0: {m/b} ≥ 0 and gap ≥ 0
    intro n
    simp only [fractCorrection]
    exact mul_nonneg (Int.fract_nonneg _) (log_gap_bound (n+1) (by omega)).1
  · -- fractCorrection(n+1) ≤ 1/(n+1)²
    intro n
    simp only [fractCorrection]
    have h_fract_lt : Int.fract ((↑(n+1):ℝ) / (b:ℝ)) < 1 := Int.fract_lt_one _
    have h_gap := log_gap_bound (n + 1) (by omega)
    calc Int.fract ((↑(n+1):ℝ) / (b:ℝ)) *
          (Real.log ((↑(n+1) + 1) / ↑(n+1)) - 1 / (↑(n+1) + 1))
        ≤ 1 * (1 / (↑(n+1) * (↑(n+1) + 1))) :=
          mul_le_mul (le_of_lt h_fract_lt) h_gap.2 h_gap.1 (by norm_num)
      _ ≤ 1 / (↑(n + 1)) ^ 2 := by
          rw [one_mul]
          apply div_le_div_of_nonneg_left (by norm_num : (0:ℝ) ≤ 1) (by positivity)
          have : (0:ℝ) ≤ (n:ℝ) := Nat.cast_nonneg n
          push_cast; nlinarith
  · exact h_dom

-- ────────────────────────────────────────────────
-- §5d. FRACT CORRECTION LIMIT IDENTIFICATION
-- ────────────────────────────────────────────────

-- The limit of Σ fractCorrection(b, m) needs to match the
-- cotangent sum terms in vasyuninGramFormula.
--
-- vasyuninGramFormula(1, b) = (log(2π)-γ)/2·(1+1/b) + (1-b)/(2b)·log(b)
--                            - π/(2b)·V(b,1) - 1/b
-- where V(1,b) = 0 and V(b,1) = Σ_{m=1}^{b-1} (m/b)·cot(πm/b).
--
-- And (1/b)·(log(2π)-γ-1) = (log(2π)-γ)/b - 1/b
--
-- So the fract correction limit must equal:
--   vasyuninGramFormula(1,b) - (log(2π)-γ-1)/b
-- = (log(2π)-γ)/2·(1+1/b) + (1-b)/(2b)·log(b) - π/(2b)·V(b,1) - 1/b
--   - (log(2π)-γ)/b + 1/b
-- = (log(2π)-γ)·[(1+1/b)/2 - 1/b]
--   + (1-b)/(2b)·log(b) - π/(2b)·V(b,1)
-- = (log(2π)-γ)·(b-1)/(2b)
--   + (1-b)/(2b)·log(b) - π/(2b)·V(b,1)
-- = (b-1)/(2b)·[log(2π)-γ-log(b)] - π/(2b)·V(b,1)
-- = (b-1)/(2b)·[log(2π/b)-γ] - π/(2b)·V(b,1)
--
-- This is the deep analytic identity connecting the fract series
-- to Vasyunin cotangent sums via the Gauss digamma formula.

-- ────────────────────────────────────────────────
-- §5e. ASSEMBLY — GRADUATED (May 3, 2026)
-- ────────────────────────────────────────────────

-- The assembly theorem `tsum_rowTerm_eq_formula_a1` formerly used the
-- AlgebraicLimit axiom. It has been GRADUATED and moved to:
--
--   FractSeriesEval.gramIntegral_eq_formula_a1_axiomFree
--
-- which evaluates the fract correction series via:
--   Abel summation → residue-class decomposition → logΓ evaluation
--   → digamma reflection → cotangent sum identification
-- All without any axioms.

-- ════════════════════════════════════════════════
-- §6. THE MAIN THEOREM — GRADUATED
-- ════════════════════════════════════════════════

-- The main theorem `gramIntegral_eq_formula_a1` has been GRADUATED to:
--
--   FractSeriesEval.gramIntegral_eq_formula_a1_axiomFree
--
-- which is PROVED, zero-axiom, proven via the full analytical
-- chain: §1-§4 (this file) + §5a-§5c (this file) + fract evaluation
-- (FractSeriesEval). The axiom is no longer needed for a=1.

-- ════════════════════════════════════════════════
-- AUDIT (May 3, 2026 — AXIOM REMOVED)
-- ════════════════════════════════════════════════

-- PROVED (PROVED, ZERO AXIOMS):
--   ✅ strip_zero_a1                    — Strip integral vanishes for a=1
--   ✅ all_single_tile_a1               — Every row is single-tile for a=1
--   ✅ actual_eq_rowTerm_a1             — actualRowIntegral = rowTerm for a=1
--   ✅ gramIntegral_eq_tsum_rowTerm_a1  — gramIntegral = tsum rowTerm for a=1
--   ✅ rowTerm_decompose_a1             — rowTerm = Stirling/b + fract correction
--   ✅ stirlingTerm_summable            — Summability of Stirling terms
--   ✅ stirlingTerm_hasSum              — Stirling limit = log(2π) - γ - 1
--   ✅ fractCorrection_summable         — Fract correction summable
--
-- GRADUATED TO FractSeriesEval (May 3, 2026):
--   → tsum_rowTerm_eq_formula_a1       — now axiom-free in FractSeriesEval
--   → gramIntegral_eq_formula_a1       — now axiom-free in FractSeriesEval
--
-- AXIOMS USED: ZERO (was 1, eliminated May 3, 2026)
--   The AlgebraicLimit axiom is no longer imported or needed.
--   The fract correction limit is evaluated axiom-free via:
--     Abel sum → residue class → logΓ → digamma → cotangent
--   in FractSeriesEval.fract_correction_eq_target.
--
-- ARCHITECTURE:
--   §1-§4: Geometric simplification (fully proved, zero axioms)
--     strip vanishes → every row single-tile → rowTerm identity → tsum
--   §5a-§5c: Analytic decomposition (fully proved, zero axioms)
--     rowTerm = Stirling/b + fract → both summable
--   §5e-§6: GRADUATED to FractSeriesEval.gramIntegral_eq_formula_a1_axiomFree

end Cathedral.Vasyunin.DiagonalStrike
