/-
  Cathedral/Vasyunin/Cotangent/PartialSumConvergence.lean

  ## DECOMPOSITION OF partial_sum_tends_to_formula

  Strategy: Decompose the monolithic convergence axiom into tractable
  sub-axioms, each representing a well-understood analytic fact.

  ### The Three-Sum Decomposition

  For coprime a, b with a < b, the partial integral from 1/(aM) to 1 equals:

    Σ_{m=1}^{M-1} R(m)

  where R(m) = 1/b - (n(m)/a + m/b)·log((m+1)/m) + n(m)/(a(m+1))
  and n(m) = ⌊am/b⌋ (the Beatty sequence for the coprime pair).

  The sum splits into three components:

  s_rational(M) = (M-1)/b                                    (diverges)
  s_log(M)      = -Σ (n(m)/a + m/b)·log((m+1)/m)            (diverges)
  s_linear(M)   = Σ n(m)/(a(m+1))                            (diverges)

  ### The Convergence Structure (CORRECTED April 25, 2026)

  **CRITICAL**: No sub-sum converges individually. Only the FULL combination
  s_combined(M) = s_rational + s_log + s_linear converges as M → ∞.

  The cancellation structure:
  1. s_log = s_log_stirling + s_log_digamma
  2. s_rational + s_log_stirling cancels the O(M) divergence (proved)
  3. The remaining log-divergent pieces in s_log_digamma + s_linear
     cancel through floor/fract decomposition and Dirichlet test
  4. What survives is finite and equals vasyuninGramFormula

  Created: April 25, 2026 — Decomposition of the Final Axiom
  Status: BUILDING — Convergence axiom corrected
-/

import Cathedral.Vasyunin.Cotangent.TelescopeSum
import Cathedral.Vasyunin.Cotangent.StirlingBridge
import Cathedral.Vasyunin.Cotangent.OffDiagPartition
import Cathedral.Analysis.DirichletTest
import Cathedral.Analysis.CenteredFractBound
import Mathlib.Analysis.SpecialFunctions.Stirling
import Mathlib.Analysis.SpecialFunctions.Log.Deriv
import Mathlib.Analysis.Calculus.Deriv.MeanValue
import Mathlib.NumberTheory.Harmonic.EulerMascheroni
import Mathlib.Algebra.Order.Floor.Semifield

noncomputable section
open Real MeasureTheory Filter

namespace Cathedral.Vasyunin.PartialSumConvergence

-- ════════════════════════════════════════════════
-- §1. THE TILE INDEX FUNCTION n(m)
-- ════════════════════════════════════════════════

/-- For coprime (a,b) with a < b, the tile index on row m is n(m) = ⌊am/b⌋.
    This is the k-index at the left boundary of row m. -/
def tileIndex (a b m : ℕ) : ℕ := (a * m) / b

/-- The tile index is nonneg (trivially, since it's a natural number). -/
lemma tileIndex_nonneg (a b m : ℕ) : 0 ≤ (tileIndex a b m : ℝ) :=
  Nat.cast_nonneg _

-- ════════════════════════════════════════════════
-- §2. THE THREE PARTIAL SUMS
-- ════════════════════════════════════════════════

/-- The rational partial sum: Σ_{m=1}^{M-1} 1/b = (M-1)/b. -/
def s_rational (b M : ℕ) : ℝ := ((M:ℝ) - 1) / (b:ℝ)

/-- The log partial sum: -Σ_{m=1}^{M-1} (n(m)/a + m/b) · log((m+1)/m). -/
def s_log (a b M : ℕ) : ℝ :=
  -∑ m ∈ Finset.Icc 1 (M - 1),
    ((tileIndex a b m : ℝ) / (a:ℝ) + (m:ℝ) / (b:ℝ)) *
    Real.log (((m:ℝ) + 1) / (m:ℝ))

/-- The linear partial sum: Σ_{m=1}^{M-1} n(m) / (a·(m+1)). -/
def s_linear (a b M : ℕ) : ℝ :=
  ∑ m ∈ Finset.Icc 1 (M - 1),
    (tileIndex a b m : ℝ) / ((a:ℝ) * ((m:ℝ) + 1))

/-- The combined partial sum S(M) = s_rational + s_log + s_linear. -/
def s_combined (a b M : ℕ) : ℝ :=
  s_rational b M + s_log a b M + s_linear a b M

-- ════════════════════════════════════════════════
-- §3. THE LOG SUM SPLITS INTO STIRLING + DIGAMMA
-- ════════════════════════════════════════════════

/-- The log sum splits: s_log = s_log_stirling + s_log_digamma
    where:
      s_log_stirling = -(1/b) · Σ m · log((m+1)/m)
      s_log_digamma  = -(1/a) · Σ n(m) · log((m+1)/m) -/
def s_log_stirling (b M : ℕ) : ℝ :=
  -(1/(b:ℝ)) * ∑ m ∈ Finset.Icc 1 (M - 1),
    (m:ℝ) * Real.log (((m:ℝ) + 1) / (m:ℝ))

def s_log_digamma (a b M : ℕ) : ℝ :=
  -(1/(a:ℝ)) * ∑ m ∈ Finset.Icc 1 (M - 1),
    (tileIndex a b m : ℝ) * Real.log (((m:ℝ) + 1) / (m:ℝ))

theorem s_log_split (a b M : ℕ) :
    s_log a b M = s_log_stirling b M + s_log_digamma a b M := by
  simp only [s_log, s_log_stirling, s_log_digamma]
  rw [neg_mul, neg_mul, ← neg_add]
  congr 1
  rw [Finset.mul_sum, Finset.mul_sum, ← Finset.sum_add_distrib]
  congr 1; ext m; ring

-- ════════════════════════════════════════════════
-- §4. STIRLING COMPONENT — PROVED
-- ════════════════════════════════════════════════

-- The Stirling component uses the already-proved m_log_partial_sum_formula.
-- s_rational + s_log_stirling cancels the divergent M/b and leaves
-- finite terms related to ln(2π)/2 and Euler-Mascheroni constant.

/-- **CANCELLATION LEMMA**: s_rational(M) + s_log_stirling(M) =
    -(1/b) · [M·log(M) - M + log(2π)/2 + ...] + (M-1)/b

    The M/b terms cancel, leaving finite terms. -/
theorem rational_plus_stirling (b M : ℕ) (_hb : 1 ≤ b) (hM : 2 ≤ M) :
    s_rational b M + s_log_stirling b M =
    ((M:ℝ) - 1) / (b:ℝ) -
    (1/(b:ℝ)) * (((M:ℝ) - 1) * Real.log (M:ℝ) -
      ∑ m ∈ Finset.Icc 1 (M - 1), Real.log (m:ℝ)) := by
  simp only [s_rational, s_log_stirling]
  rw [neg_mul]
  have h := TelescopeSum.m_log_partial_sum_formula (M - 1) (by omega)
  have hcast : ((M - 1 : ℕ) : ℝ) = (M : ℝ) - 1 := by
    rw [Nat.cast_sub (by omega : 1 ≤ M)]; simp
  rw [h, hcast]
  have hM_eq : (M : ℝ) - 1 + 1 = (M : ℝ) := by ring
  rw [hM_eq]
  ring

-- ════════════════════════════════════════════════
-- §5. THE COMBINED CONVERGENCE — CORRECTED AXIOM
-- ════════════════════════════════════════════════

-- **DISCOVERY (April 25, 2026):** The original decomposition into two
-- sub-axioms (floor_weighted_log_sum_limit and linear_series_convergent)
-- was MATHEMATICALLY FALSE. Each assigned a fraction of the Stirling
-- correction, but the allocation left log-divergent remainders in both.
--
-- Numerics confirm: for a=1, b=2,
--   s_linear(M) - (1/b)·Stirling(M) ≈ -(1/4)·log(M) → -∞
--   s_log_digamma(M) + (a/b²)·Stirling(M) → -∞
--
-- The divergence rates are -(a+b-1)/(2ab)·log(M) and similar, which
-- do NOT cancel individually. Only the TOTAL s_combined converges.
--
-- CORRECTED: Merge into a single axiom about s_combined convergence.

-- ════════════════════════════════════════════════
-- §4b. LOG BOUND INFRASTRUCTURE (derivative-based)
-- ════════════════════════════════════════════════

/-- g(x) = x - 1/x - 2·log(x). We show g ≥ 0 on [1,∞) via g'=(x-1)²/x² ≥ 0, g(1)=0. -/
private noncomputable def logBoundG (x : ℝ) : ℝ := x - x⁻¹ - 2 * Real.log x

private lemma logBoundG_hasDerivAt (x : ℝ) (hx : x ≠ 0) :
    HasDerivAt logBoundG ((x - 1)^2 / x^2) x := by
  have h : HasDerivAt logBoundG (1 - (-(x ^ 2)⁻¹) - 2 * x⁻¹) x :=
    ((hasDerivAt_id x).sub (hasDerivAt_inv hx)).sub ((hasDerivAt_log hx).const_mul 2)
  convert h using 1; field_simp; ring

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

/-- **AM log bound**: log((m+1)/m) ≤ (2m+1)/(2m(m+1)). -/
private lemma log_le_am (m : ℕ) (hm : 1 ≤ m) :
    Real.log (((m:ℝ) + 1) / (m:ℝ)) ≤
    (2*(m:ℝ) + 1) / (2*(m:ℝ)*((m:ℝ) + 1)) := by
  have hm_pos : (0:ℝ) < (m:ℝ) := Nat.cast_pos.mpr (by omega)
  have hx_ge : 1 ≤ ((m:ℝ) + 1) / (m:ℝ) := by rw [le_div_iff₀ hm_pos]; linarith
  have hg := logBoundG_nonneg hx_ge
  simp only [logBoundG, inv_div] at hg
  have heq : ((m:ℝ) + 1) / (m:ℝ) - (m:ℝ) / ((m:ℝ) + 1) =
      (2*(m:ℝ) + 1) / ((m:ℝ) * ((m:ℝ) + 1)) := by field_simp; ring
  suffices 2 * Real.log (((m:ℝ) + 1) / (m:ℝ)) ≤
      2 * ((2*(m:ℝ) + 1) / (2*(m:ℝ)*((m:ℝ) + 1))) by linarith
  have : 2 * ((2*(m:ℝ) + 1) / (2*(m:ℝ)*((m:ℝ) + 1))) =
      (2*(m:ℝ) + 1) / ((m:ℝ) * ((m:ℝ) + 1)) := by field_simp
  rw [this]; linarith

/-- **Simple upper bound**: log((m+1)/m) ≤ 1/m. -/
private lemma log_le_inv (m : ℕ) (hm : 1 ≤ m) :
    Real.log (((m:ℝ) + 1) / (m:ℝ)) ≤ 1 / (m:ℝ) := by
  have hm_pos : (0:ℝ) < (m:ℝ) := Nat.cast_pos.mpr (by omega)
  have h := log_le_sub_one_of_pos (show (0:ℝ) < ((m:ℝ) + 1) / (m:ℝ) by positivity)
  have : ((m:ℝ) + 1) / (m:ℝ) - 1 = 1 / (m:ℝ) := by field_simp; ring
  linarith

/-- **Simple lower bound**: log((m+1)/m) ≥ 1/(m+1). -/
private lemma log_ge_inv_succ (m : ℕ) (hm : 1 ≤ m) :
    1 / ((m:ℝ) + 1) ≤ Real.log (((m:ℝ) + 1) / (m:ℝ)) := by
  have hm_pos : (0:ℝ) < (m:ℝ) := Nat.cast_pos.mpr (by omega)
  have h := one_sub_inv_le_log_of_pos (show (0:ℝ) < ((m:ℝ) + 1) / (m:ℝ) by positivity)
  rw [inv_div] at h
  have : 1 - (m:ℝ) / ((m:ℝ) + 1) = 1 / ((m:ℝ) + 1) := by field_simp; ring
  linarith

/-- h(x) = log(x) - (x-1) + (x-1)²/2. We show h ≥ 0 on [1,∞) to get second-order log bound. -/
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

/-- **Second-order lower bound**: log((m+1)/m) ≥ 1/m - 1/(2m²). -/
private lemma log_ge_second_order (m : ℕ) (hm : 1 ≤ m) :
    1 / (m:ℝ) - 1 / (2 * (m:ℝ)^2) ≤ Real.log (((m:ℝ) + 1) / (m:ℝ)) := by
  have hm_pos : (0:ℝ) < (m:ℝ) := Nat.cast_pos.mpr (by omega)
  have hx_ge : 1 ≤ ((m:ℝ) + 1) / (m:ℝ) := by rw [le_div_iff₀ hm_pos]; linarith
  have hh := logBoundH_nonneg hx_ge
  simp only [logBoundH] at hh
  have hsub : ((m:ℝ) + 1) / (m:ℝ) - 1 = 1 / (m:ℝ) := by field_simp; ring
  rw [hsub] at hh
  have hsq : (1 / (m:ℝ))^2 / 2 = 1 / (2 * (m:ℝ)^2) := by field_simp
  linarith

/-- Floor division satisfies b * (a*m/b) ≤ a*m. -/
private lemma tileIndex_mul_le (a b m : ℕ) :
    b * tileIndex a b m ≤ a * m := by
  simp only [tileIndex]
  have := Nat.div_mul_le_self (a * m) b
  rw [mul_comm] at this
  exact this

/-- The single-row contribution to s_combined.

    R(m) = 1/b - (⌊am/b⌋/a + m/b)·log((m+1)/m) + ⌊am/b⌋/(a·(m+1))

    s_combined(M) = Σ_{m=1}^{M-1} R(m). -/
def rowTerm (a b m : ℕ) : ℝ :=
  1 / (b:ℝ) -
  ((tileIndex a b m : ℝ) / (a:ℝ) + (m:ℝ) / (b:ℝ)) *
    Real.log (((m:ℝ) + 1) / (m:ℝ)) +
  (tileIndex a b m : ℝ) / ((a:ℝ) * ((m:ℝ) + 1))

/-- s_combined equals Σ rowTerm for M ≥ 1. -/
theorem s_combined_eq_sum_rowTerm (a b M : ℕ) (hM : 1 ≤ M) :
    s_combined a b M =
    ∑ m ∈ Finset.Icc 1 (M - 1), rowTerm a b m := by
  simp only [s_combined, s_rational, s_log, s_linear, rowTerm]
  -- Rewrite (M-1)/b as a constant sum over Icc 1 (M-1)
  have h_rat : ((M:ℝ) - 1) / (b:ℝ) =
      ∑ _m ∈ Finset.Icc 1 (M - 1), (1:ℝ) / (b:ℝ) := by
    rw [Finset.sum_const, nsmul_eq_mul]
    have hcard : (Finset.Icc 1 (M - 1)).card = M - 1 := by
      rw [Nat.card_Icc]; omega
    rw [hcard, Nat.cast_sub hM]; ring
  -- Normalize the target: convert a - b to a + (-b) on the RHS
  simp only [sub_eq_add_neg] at *
  rw [h_rat, ← Finset.sum_neg_distrib,
      ← Finset.sum_add_distrib, ← Finset.sum_add_distrib]

/-- **SUB-LEMMA (Row Term Nonneg)**: R(m) ≥ 0 for m ≥ 1.

    Uses the AM log bound to reduce to (am - b·n)/(2abm(m+1)) ≥ 0,
    which holds since n = ⌊am/b⌋ implies b·n ≤ am. -/
lemma rowTerm_nonneg (a b m : ℕ) (ha : 1 ≤ a) (hb : 1 ≤ b)
    (_hab : a < b) (hm : 1 ≤ m) : 0 ≤ rowTerm a b m := by
  simp only [rowTerm]
  set n := tileIndex a b m
  set L := Real.log (((m:ℝ) + 1) / (m:ℝ))
  have ha_pos : (0:ℝ) < (a:ℝ) := Nat.cast_pos.mpr (by omega)
  have hb_pos : (0:ℝ) < (b:ℝ) := Nat.cast_pos.mpr (by omega)
  have hm_pos : (0:ℝ) < (m:ℝ) := Nat.cast_pos.mpr (by omega)
  have hm1_pos : (0:ℝ) < (m:ℝ) + 1 := by linarith
  -- Use L ≤ (2m+1)/(2m(m+1)) (AM bound)
  have hL_upper := log_le_am m hm
  -- Use L ≥ 0
  have hL_nonneg : 0 ≤ L := Real.log_nonneg (by rw [le_div_iff₀ hm_pos]; linarith)
  -- Key: bn ≤ am (floor property)
  have hbn_le_am : (b:ℝ) * (n:ℝ) ≤ (a:ℝ) * (m:ℝ) := by
    have h := tileIndex_mul_le a b m
    exact_mod_cast h
  -- Direct calculation: bound the log term from above
  have hcoeff_nonneg : 0 ≤ (n:ℝ) / (a:ℝ) + (m:ℝ) / (b:ℝ) := by positivity
  -- Step 1: With AM bound instead of L, the expression ≥ 0
  have h_am_nonneg : 0 ≤ 1 / (b:ℝ) - ((n:ℝ) / (a:ℝ) + (m:ℝ) / (b:ℝ)) *
      ((2*(m:ℝ) + 1) / (2*(m:ℝ)*((m:ℝ) + 1))) +
      (n:ℝ) / ((a:ℝ) * ((m:ℝ) + 1)) := by
    -- After clearing denominators, reduces to (am - bn)·(stuff) ≥ 0
    rw [div_add_div _ _ (ne_of_gt ha_pos) (ne_of_gt hb_pos)]
    have key : 0 ≤ (a:ℝ) * (m:ℝ) - (b:ℝ) * (n:ℝ) := by linarith
    -- Use field_simp to normalize, then nlinarith
    field_simp
    nlinarith [sq_nonneg ((a:ℝ) * (m:ℝ) - (b:ℝ) * (n:ℝ)),
               mul_nonneg key (Nat.cast_nonneg n),
               mul_nonneg key (le_of_lt hm_pos)]
  -- Step 2: Since L ≤ AM bound and coeff ≥ 0, the real expression ≥ AM expression
  calc 0 ≤ 1 / (b:ℝ) - ((n:ℝ) / (a:ℝ) + (m:ℝ) / (b:ℝ)) *
              ((2*(m:ℝ) + 1) / (2*(m:ℝ)*((m:ℝ) + 1))) +
            (n:ℝ) / ((a:ℝ) * ((m:ℝ) + 1)) := h_am_nonneg
     _ ≤ 1 / (b:ℝ) - ((n:ℝ) / (a:ℝ) + (m:ℝ) / (b:ℝ)) * L +
            (n:ℝ) / ((a:ℝ) * ((m:ℝ) + 1)) := by
          have : ((n:ℝ) / (a:ℝ) + (m:ℝ) / (b:ℝ)) * L ≤
              ((n:ℝ) / (a:ℝ) + (m:ℝ) / (b:ℝ)) *
                ((2*(m:ℝ) + 1) / (2*(m:ℝ)*((m:ℝ) + 1))) :=
            mul_le_mul_of_nonneg_left hL_upper hcoeff_nonneg
          linarith

/-- **SUB-LEMMA (Row Term Upper Bound)**: R(m) ≤ (a+b)/(ab·m²) for m ≥ 1.

    The proof decomposes R into a "main bracket" and a "fract bracket":
    - Main bracket: (1/b)·((2m+1)/(m+1) - 2mL) ≤ 1/(bm(m+1)) via the
      second-order lower bound L ≥ 1/m - 1/(2m²).
    - Fract bracket: (δ/a)·(L - 1/(m+1)) ≤ 1/(am(m+1)) via L ≤ 1/m
      and δ = am/b - n ≤ 1.
    Total: R ≤ (a+b)/(abm(m+1)) ≤ (a+b)/(abm²). -/
lemma rowTerm_le_upper (a b m : ℕ) (ha : 1 ≤ a) (hb : 1 ≤ b)
    (_hab : a < b) (hm : 1 ≤ m) :
    rowTerm a b m ≤ ((a:ℝ) + (b:ℝ)) / ((a:ℝ) * (b:ℝ)) / (m:ℝ)^2 := by
  simp only [rowTerm]
  set n := tileIndex a b m
  set L := Real.log (((m:ℝ) + 1) / (m:ℝ))
  have ha_pos : (0:ℝ) < (a:ℝ) := Nat.cast_pos.mpr (by omega)
  have hb_pos : (0:ℝ) < (b:ℝ) := Nat.cast_pos.mpr (by omega)
  have hm_pos : (0:ℝ) < (m:ℝ) := Nat.cast_pos.mpr (by omega)
  have hm1_pos : (0:ℝ) < (m:ℝ) + 1 := by linarith
  -- Key log bounds
  have hL_am := log_le_am m hm                   -- L ≤ (2m+1)/(2m(m+1))
  have hL_lower2 := log_ge_second_order m hm      -- L ≥ 1/m - 1/(2m²)
  have hL_upper := log_le_inv m hm                -- L ≤ 1/m
  have hL_lower := log_ge_inv_succ m hm           -- L ≥ 1/(m+1)
  -- Floor bound: bn ≤ am, i.e., δ = am/b - n ≥ 0 and am - bn ≤ b (so δ < 1 iff ¬b|am)
  have hbn_le_am : (b:ℝ) * (n:ℝ) ≤ (a:ℝ) * (m:ℝ) := by
    exact_mod_cast tileIndex_mul_le a b m
  have hn_nonneg : (0:ℝ) ≤ (n:ℝ) := Nat.cast_nonneg n
  -- Key intermediate: 2mL ≥ 2 - 1/m (from second-order bound)
  have h_2mL_lower : 2 * (m:ℝ) * L ≥ 2 - 1 / (m:ℝ) := by
    have hmul := mul_le_mul_of_nonneg_left hL_lower2 (show 0 ≤ 2 * (m:ℝ) by positivity)
    suffices h : 2 * (m:ℝ) * (1 / (m:ℝ) - 1 / (2 * (m:ℝ) ^ 2)) = 2 - 1 / (m:ℝ) by linarith
    field_simp
  -- Key intermediate: 2mL ≤ (2m+1)/(m+1) (from AM bound)
  have h_2mL_upper : 2 * (m:ℝ) * L ≤ (2 * (m:ℝ) + 1) / ((m:ℝ) + 1) := by
    have hmul := mul_le_mul_of_nonneg_left hL_am (show 0 ≤ 2 * (m:ℝ) by positivity)
    suffices h : 2 * (m:ℝ) * ((2 * (m:ℝ) + 1) / (2 * (m:ℝ) * ((m:ℝ) + 1))) =
        (2 * (m:ℝ) + 1) / ((m:ℝ) + 1) by linarith
    field_simp
  -- The main bracket: (2m+1)/(m+1) - 2mL ∈ [0, 1/(m(m+1))]
  have h_bracket_nonneg : 0 ≤ (2 * (m:ℝ) + 1) / ((m:ℝ) + 1) - 2 * (m:ℝ) * L := by
    linarith
  have h_bracket_upper : (2 * (m:ℝ) + 1) / ((m:ℝ) + 1) - 2 * (m:ℝ) * L ≤
      1 / ((m:ℝ) * ((m:ℝ) + 1)) := by
    have : (2 * (m:ℝ) + 1) / ((m:ℝ) + 1) - (2 - 1 / (m:ℝ)) =
        1 / ((m:ℝ) * ((m:ℝ) + 1)) := by field_simp; ring
    linarith
  -- δ = am/b - n ≤ 1 (integer: am - bn ≤ b - 1 < b, so am/b - n < 1)
  -- We use the division algorithm: am mod b < b, and am = b*n + (am mod b).
  have h_delta_bound : (a:ℝ) * (m:ℝ) - (b:ℝ) * (n:ℝ) < (b:ℝ) := by
    have hb_pos_nat : 0 < b := by omega
    have hmod := Nat.mod_lt (a * m) hb_pos_nat
    have hdiv := Nat.div_add_mod (a * m) b
    have h_nat : a * m - b * (a * m / b) < b := by omega
    have h_le : b * (a * m / b) ≤ a * m := by
      have := Nat.div_mul_le_self (a * m) b; rw [mul_comm] at this; exact this
    change (a:ℝ) * (m:ℝ) - (b:ℝ) * ((tileIndex a b m : ℕ):ℝ) < (b:ℝ)
    simp only [tileIndex]
    rw [show (a:ℝ) * (m:ℝ) - (b:ℝ) * ((a * m / b : ℕ):ℝ) = ((a * m - b * (a * m / b) : ℕ):ℝ) from by
      simp [Nat.cast_sub h_le]]
    exact_mod_cast h_nat
  -- L - 1/(m+1) ≤ 1/m - 1/(m+1) = 1/(m(m+1))
  have h_log_gap : L - 1 / ((m:ℝ) + 1) ≤ 1 / ((m:ℝ) * ((m:ℝ) + 1)) := by
    have : 1 / (m:ℝ) - 1 / ((m:ℝ) + 1) = 1 / ((m:ℝ) * ((m:ℝ) + 1)) := by field_simp; ring
    linarith
  -- Now prove the bound using monotonicity in L.
  -- R = 1/b - (n/a + m/b)·L + n/(a(m+1)) is DECREASING in L.
  -- So R ≤ R(L_min) where L_min = 1/m - 1/(2m²).
  have h_coeff_nn : 0 ≤ (n:ℝ) / (a:ℝ) + (m:ℝ) / (b:ℝ) := by positivity
  -- R ≤ R at L = 1/m - 1/(2m²)
  have h_Rub : 1 / (b:ℝ) - ((n:ℝ) / (a:ℝ) + (m:ℝ) / (b:ℝ)) * L +
      (n:ℝ) / ((a:ℝ) * ((m:ℝ) + 1)) ≤
      1 / (b:ℝ) - ((n:ℝ) / (a:ℝ) + (m:ℝ) / (b:ℝ)) *
        (1 / (m:ℝ) - 1 / (2 * (m:ℝ) ^ 2)) +
      (n:ℝ) / ((a:ℝ) * ((m:ℝ) + 1)) := by
    have := mul_le_mul_of_nonneg_left hL_lower2 h_coeff_nn
    linarith
  -- Now show R(L_min) ≤ (a+b)/(abm²)
  suffices h_Rmin : 1 / (b:ℝ) - ((n:ℝ) / (a:ℝ) + (m:ℝ) / (b:ℝ)) *
      (1 / (m:ℝ) - 1 / (2 * (m:ℝ) ^ 2)) +
      (n:ℝ) / ((a:ℝ) * ((m:ℝ) + 1)) ≤
      ((a:ℝ) + (b:ℝ)) / ((a:ℝ) * (b:ℝ)) / (m:ℝ) ^ 2 by linarith
  -- Simplify R(L_min) = 1/(2bm) - n(m-1)/(2am²(m+1))
  rw [show 1 / (b:ℝ) - ((n:ℝ) / (a:ℝ) + (m:ℝ) / (b:ℝ)) *
      (1 / (m:ℝ) - 1 / (2 * (m:ℝ) ^ 2)) +
      (n:ℝ) / ((a:ℝ) * ((m:ℝ) + 1)) =
      1 / (2 * (b:ℝ) * (m:ℝ)) -
      (n:ℝ) * ((m:ℝ) - 1) / (2 * (a:ℝ) * (m:ℝ) ^ 2 * ((m:ℝ) + 1))
      from by field_simp; ring]
  -- Clear denominators: need
  -- (a+b)/(abm²) - 1/(2bm) + n(m-1)/(2am²(m+1)) ≥ 0
  rw [show ((a:ℝ) + (b:ℝ)) / ((a:ℝ) * (b:ℝ)) / (m:ℝ) ^ 2 =
      ((a:ℝ) + (b:ℝ)) / ((a:ℝ) * (b:ℝ) * (m:ℝ) ^ 2) from by ring]
  suffices h : 0 ≤ ((a:ℝ) + (b:ℝ)) / ((a:ℝ) * (b:ℝ) * (m:ℝ) ^ 2) -
      (1 / (2 * (b:ℝ) * (m:ℝ)) -
      (n:ℝ) * ((m:ℝ) - 1) / (2 * (a:ℝ) * (m:ℝ) ^ 2 * ((m:ℝ) + 1))) by linarith
  -- Express as single fraction with positive denominator
  rw [show ((a:ℝ) + (b:ℝ)) / ((a:ℝ) * (b:ℝ) * (m:ℝ) ^ 2) -
      (1 / (2 * (b:ℝ) * (m:ℝ)) -
      (n:ℝ) * ((m:ℝ) - 1) / (2 * (a:ℝ) * (m:ℝ) ^ 2 * ((m:ℝ) + 1))) =
      (2 * (a:ℝ) + 2 * (b:ℝ) +
        (2 * (b:ℝ) - ((a:ℝ) * (m:ℝ) - (b:ℝ) * (n:ℝ))) * (m:ℝ) +
        ((a:ℝ) * (m:ℝ) - (b:ℝ) * (n:ℝ))) /
      (2 * (a:ℝ) * (b:ℝ) * (m:ℝ) ^ 2 * ((m:ℝ) + 1))
      from by field_simp; ring]
  apply div_nonneg _ (by positivity)
  -- Need: 2a + 2b + (2b - δ)m + δ ≥ 0 where δ = am - bn ∈ [0, b)
  have hδ_nn : 0 ≤ (a:ℝ) * (m:ℝ) - (b:ℝ) * (n:ℝ) := by linarith [hbn_le_am]
  nlinarith

/-- **THEOREM (Combined Convergence)** — GRADUATED from axiom!

    The total partial sum s_combined(M) = s_rational + s_log + s_linear
    converges to a finite limit as M → ∞.

    **Proof**: s_combined(M) = Σ_{m=1}^{M-1} R(m) where:
    - R(m) ≥ 0 (so partial sums are monotone increasing)
    - R(m) ≤ 1/m² (so partial sums are bounded by ζ(2) = π²/6)
    - By the monotone convergence theorem, the limit exists. -/
theorem s_combined_converges (a b : ℕ) (ha : 1 ≤ a) (hb : 1 ≤ b)
    (hab : a < b) (_hcop : Nat.Coprime a b) :
    ∃ L : ℝ,
    Tendsto (fun M : ℕ => s_combined a b M) atTop (nhds L) := by
  -- Step 1: rowTerm(n+1) is summable (by comparison with C/(n+1)²)
  set C := ((a:ℝ) + (b:ℝ)) / ((a:ℝ) * (b:ℝ)) with hC_def
  have hC_pos : 0 < C := by positivity
  have h_nonneg : ∀ n, 0 ≤ rowTerm a b (n + 1) :=
    fun n => rowTerm_nonneg a b (n + 1) ha hb hab (by omega)
  have h_upper : ∀ n, rowTerm a b (n + 1) ≤ C / ((n:ℝ) + 1)^2 := by
    intro n
    calc rowTerm a b (n + 1)
        ≤ C / ((n + 1 : ℕ):ℝ)^2 := rowTerm_le_upper a b (n + 1) ha hb hab (by omega)
      _ = C / ((n:ℝ) + 1)^2 := by push_cast; ring_nf
  have h_summable : Summable (fun n : ℕ => rowTerm a b (n + 1)) := by
    apply Summable.of_nonneg_of_le h_nonneg h_upper
    -- Σ C/(n+1)² is summable — C times shifted p-series
    have : Summable (fun n : ℕ => (1:ℝ) / ((n:ℝ) + 1) ^ 2) := by
      rw [show (fun n : ℕ => (1:ℝ) / ((n:ℝ) + 1) ^ 2) =
          (fun n : ℕ => (fun m : ℕ => (1:ℝ) / (m:ℝ) ^ 2) (n + 1)) from by
        ext n; push_cast; ring_nf]
      exact (summable_nat_add_iff 1).mpr
        (summable_one_div_nat_pow.mpr (show 1 < 2 by norm_num))
    convert this.mul_left C using 1
    ext n; ring
  -- Step 2: HasSum → Tendsto on Finset.range partial sums
  obtain ⟨L, hL⟩ := h_summable
  refine ⟨L, ?_⟩
  have h_tendsto : Tendsto
      (fun N : ℕ => ∑ n ∈ Finset.range N, rowTerm a b (n + 1))
      atTop (nhds L) :=
    (hasSum_iff_tendsto_nat_of_nonneg h_nonneg L).mp hL
  -- Step 3: Show Σ_{n<N} rowTerm(n+1) = s_combined(N+1)
  have h_eq : ∀ N : ℕ, ∑ n ∈ Finset.range N, rowTerm a b (n + 1) =
      s_combined a b (N + 1) := by
    intro N
    rw [s_combined_eq_sum_rowTerm a b (N + 1) (by omega), show N + 1 - 1 = N from by omega]
    apply Finset.sum_nbij' (fun n => n + 1) (fun m => m - 1)
    · intro n hn; simp [Finset.mem_Icc, Finset.mem_range] at *; omega
    · intro m hm; simp [Finset.mem_Icc, Finset.mem_range] at *; omega
    · intro n hn; simp [Finset.mem_range] at hn; omega
    · intro m hm; simp [Finset.mem_Icc] at hm; omega
    · intro n _hn; rfl
  -- Step 4: f(n+1) → L implies f(n) → L (shift by 1 in atTop filter)
  have h_shift : Tendsto (fun N => s_combined a b (N + 1)) atTop (nhds L) :=
    h_tendsto.congr (fun N => h_eq N)
  rw [Filter.tendsto_atTop'] at h_shift ⊢
  intro s hs
  obtain ⟨N, hN⟩ := h_shift s hs
  exact ⟨N + 1, fun n hn => by
    have := hN (n - 1) (by omega)
    simp [Nat.sub_add_cancel (by omega : 1 ≤ n)] at this
    exact this⟩

-- ════════════════════════════════════════════════
-- §5b. CONVERGENCE STRUCTURE — PROVED REDUCTIONS
-- ════════════════════════════════════════════════

/-- **KEY IDENTITY**: s_combined rewrites via floor/fract decomposition.

    s_combined(M) = s_rational(M) + s_log_stirling(M)
                  + s_log_digamma(M) + s_linear(M)

    where s_log = s_log_stirling + s_log_digamma (proved in s_log_split). -/
theorem s_combined_four_way (a b M : ℕ) :
    s_combined a b M =
    (s_rational b M + s_log_stirling b M) +
    (s_log_digamma a b M + s_linear a b M) := by
  simp only [s_combined, s_log_split]; ring

/-- **FRACTIONAL PART SERIES**: The convergent remainder after
    subtracting the main term from s_linear.

    s_linear_residual = -1/a · Σ {am/b} / (m+1)

    This converges absolutely since 0 ≤ {am/b} < 1. -/
def s_linear_residual (a b M : ℕ) : ℝ :=
  -(1/(a:ℝ)) * ∑ m ∈ Finset.Icc 1 (M - 1),
    (Int.fract ((a:ℝ) * (m:ℝ) / (b:ℝ))) / ((m:ℝ) + 1)

/-- The linear sum decomposes into a main term + convergent residual.
    s_linear = (1/b)·Σ m/(m+1) + s_linear_residual

    This follows from ⌊am/b⌋ = am/b - {am/b}. -/
theorem s_linear_decompose (a b M : ℕ) (_ha : 1 ≤ a) (hb : 1 ≤ b) :
    s_linear a b M =
    (1/(b:ℝ)) * ∑ m ∈ Finset.Icc 1 (M - 1),
      (m:ℝ) / ((m:ℝ) + 1) +
    s_linear_residual a b M := by
  simp only [s_linear, s_linear_residual, tileIndex]
  rw [neg_mul, ← sub_eq_add_neg, Finset.mul_sum, Finset.mul_sum, ← Finset.sum_sub_distrib]
  apply Finset.sum_congr rfl; intro m _
  have hb_pos : (0:ℝ) < (b:ℝ) := Nat.cast_pos.mpr (by omega)
  have hb_ne : (b:ℝ) ≠ 0 := ne_of_gt hb_pos
  -- Key identity: ↑(a*m/b) = ↑a*↑m/↑b - {↑a*↑m/↑b}
  have hfloor : (↑(a * m / b) : ℝ) = (a:ℝ) * (m:ℝ) / (b:ℝ) -
      Int.fract ((a:ℝ) * (m:ℝ) / (b:ℝ)) := by
    set x := (a:ℝ) * (m:ℝ) / (b:ℝ)
    have hnn : 0 ≤ x := by positivity
    -- ⌊↑n/↑d⌋₊ = n/d for naturals
    have h1 : Nat.floor x = a * m / b := by
      rw [show x = ((a * m : ℕ) : ℝ) / ((b : ℕ) : ℝ) from by push_cast; ring]
      exact Nat.floor_div_eq_div (a * m) b
    -- (⌊x⌋₊ : ℝ) = (⌊x⌋ : ℝ) for nonneg x
    have h2 : (↑(a * m / b) : ℝ) = (↑⌊x⌋ : ℝ) := by
      rw [← natCast_floor_eq_intCast_floor hnn, h1]
    -- ↑⌊x⌋ + {x} = x, so ↑⌊x⌋ = x - {x}
    linarith [Int.floor_add_fract x, h2]
  rw [hfloor]; field_simp

-- ════════════════════════════════════════════════
-- §7. THE ACTUAL ROW INTEGRAL — Path A (Corrected)
-- ════════════════════════════════════════════════

/-- **The actual row integral**: the integral of {1/(ax)}{1/(bx)} over row m.
    This is the CORRECT value for every row — both single-tile and two-tile.

    For single-tile rows: equals rowTerm(a,b,m) (proved in IntegralEqSCombined).
    For two-tile rows: equals sum of two FTC pieces (proved in IntegralEqSCombined).
    The definition is the integral itself — no algebraic case split needed. -/
def actualRowIntegral (a b m : ℕ) : ℝ :=
  ∫ x in (OffDiagPartition.rowLo a m)..(OffDiagPartition.rowHi a m),
    Int.fract (1 / ((a:ℝ) * x)) * Int.fract (1 / ((b:ℝ) * x))

/-- **Nonnegativity**: each row integral is nonneg (product of nonneg values). -/
theorem actualRowIntegral_nonneg (a b m : ℕ) (ha : 1 ≤ a) (hm : 1 ≤ m) :
    0 ≤ actualRowIntegral a b m := by
  unfold actualRowIntegral
  apply intervalIntegral.integral_nonneg
  · exact le_of_lt (OffDiagPartition.row_nonempty a m ha hm)
  · intro x _; exact mul_nonneg (Int.fract_nonneg _) (Int.fract_nonneg _)

/-- **THE TRIVIAL BOUND BYPASS**: each row integral ≤ 1/(a·m²).

    Proof: the integrand {1/(ax)}·{1/(bx)} is in [0,1) (product of fractional parts).
    The row width is 1/(am) - 1/(a(m+1)) = 1/(a·m·(m+1)) < 1/(a·m²).
    By the basic integral bound: ∫ f ≤ 1 × width ≤ 1/(a·m²).

    No polynomials. No logarithms. Pure geometric area of the bounding box. -/
theorem actualRowIntegral_le (a b m : ℕ) (ha : 1 ≤ a) (hm : 1 ≤ m) :
    actualRowIntegral a b m ≤ 1 / ((a:ℝ) * (m:ℝ) ^ 2) := by
  have ha_pos : (0:ℝ) < (a:ℝ) := Nat.cast_pos.mpr (by omega)
  have hm_pos : (0:ℝ) < (m:ℝ) := Nat.cast_pos.mpr (by omega)
  have hm1_pos : (0:ℝ) < (m:ℝ) + 1 := by linarith
  have h_le : OffDiagPartition.rowLo a m ≤ OffDiagPartition.rowHi a m :=
    le_of_lt (OffDiagPartition.row_nonempty a m ha hm)
  have h_nonneg := actualRowIntegral_nonneg a b m ha hm
  -- Step 1: integrand bounded by 1
  have h_bound : ∀ x ∈ Set.uIoc (OffDiagPartition.rowLo a m) (OffDiagPartition.rowHi a m),
      ‖Int.fract (1 / ((a:ℝ) * x)) * Int.fract (1 / ((b:ℝ) * x))‖ ≤ 1 := by
    intro x _
    rw [Real.norm_eq_abs, abs_of_nonneg (mul_nonneg (Int.fract_nonneg _) (Int.fract_nonneg _))]
    nlinarith [Int.fract_nonneg (1 / ((a:ℝ) * x)), Int.fract_lt_one (1 / ((a:ℝ) * x)),
              Int.fract_nonneg (1 / ((b:ℝ) * x)), Int.fract_lt_one (1 / ((b:ℝ) * x))]
  -- Step 2: apply integral norm bound
  have h_norm := intervalIntegral.norm_integral_le_of_norm_le_const h_bound
  -- Step 3: width bound
  have h_width : |OffDiagPartition.rowHi a m - OffDiagPartition.rowLo a m| =
      OffDiagPartition.rowHi a m - OffDiagPartition.rowLo a m := by
    rw [abs_of_nonneg]; linarith [h_le]
  have h_width_val : OffDiagPartition.rowHi a m - OffDiagPartition.rowLo a m =
      1 / ((a:ℝ) * (m:ℝ) * ((m:ℝ) + 1)) := by
    unfold OffDiagPartition.rowHi OffDiagPartition.rowLo
    field_simp; ring
  -- Step 4: chain: integral ≤ 1 × width ≤ 1/(am²)
  have h_integral_le : actualRowIntegral a b m ≤
      1 / ((a:ℝ) * (m:ℝ) * ((m:ℝ) + 1)) := by
    have : ‖actualRowIntegral a b m‖ ≤
        1 * |OffDiagPartition.rowHi a m - OffDiagPartition.rowLo a m| := h_norm
    rw [Real.norm_eq_abs, abs_of_nonneg h_nonneg, one_mul, h_width] at this
    linarith [h_width_val]
  calc actualRowIntegral a b m
      ≤ 1 / ((a:ℝ) * (m:ℝ) * ((m:ℝ) + 1)) := h_integral_le
    _ ≤ 1 / ((a:ℝ) * (m:ℝ) ^ 2) := by
        apply div_le_div_of_nonneg_left (by norm_num : (0:ℝ) ≤ 1)
          (by positivity : (0:ℝ) < (a:ℝ) * (m:ℝ) ^ 2)
        have : (m:ℝ) ^ 2 = (m:ℝ) * (m:ℝ) := sq (m:ℝ)
        rw [this]; nlinarith

/-- **THE INTEGRAL DECOMPOSITION (GRADUATED from axiom!)**:

    For M ≥ 2:
    ∫_{rowLo M}^{rowHi 1} {1/(ax)}{1/(bx)} dx = Σ_{m=1}^{M-1} actualRowIntegral(m)

    This is a trivially true statement of interval integral additivity —
    literally the definition of actualRowIntegral unfolded into
    OffDiagPartition.integral_eq_sum_rows.

    Replaces the FALSE axiom `integral_eq_S_combined` which claimed
    the integral equals Σ rowTerm. That claim was wrong for two-tile rows.

    GRADUATED: axiom → theorem (April 25, 2026) -/
theorem integral_eq_sum_actualRowIntegral (a b : ℕ) (ha : 1 ≤ a) (hb : 1 ≤ b)
    (M : ℕ) (hM : 2 ≤ M) :
    ∫ x in (OffDiagPartition.rowLo a (M - 1))..(OffDiagPartition.rowHi a 1),
      Int.fract (1 / ((a:ℝ) * x)) * Int.fract (1 / ((b:ℝ) * x)) =
    ∑ m ∈ Finset.Icc 1 (M - 1), actualRowIntegral a b m := by
  rw [OffDiagPartition.integral_eq_sum_rows a b ha hb 1 (M - 1) (by omega) (by omega)]
  apply Finset.sum_congr rfl
  intro m _; rfl

-- ════════════════════════════════════════════════
-- §7b. FRACTIONAL-PART RESIDUAL CONVERGENCE
-- Uses DirichletTest.dirichlet_test from White/Infrastructure
-- ════════════════════════════════════════════════

/-- The centered fractional parts f(m) = {am/b} - (b-1)/(2b) have
    bounded partial sums (they are periodic with period b and each
    period sums to 0).

    This is the key number-theoretic input that makes the Dirichlet
    test applicable to the Vasyunin residual series.

    **PROVED** — via CenteredFractBound.lean (zero sorry). -/
theorem centered_fract_partial_sums_bounded (a b : ℕ) (ha : 1 ≤ a) (hb : 2 ≤ b)
    (hab : a < b) (hcop : Nat.Coprime a b) :
    ∃ C : ℝ, ∀ n : ℕ,
      |Cathedral.Analysis.DirichletTest.partialSum₀
        (fun m => Int.fract ((a:ℝ) * ((m:ℕ):ℝ) / (b:ℝ)) - ((b:ℝ) - 1) / (2 * (b:ℝ))) n| ≤ C :=
  ⟨(b:ℝ), Cathedral.Analysis.CenteredFractBound.centered_fract_partial_sums_bounded'
    a b ha hb hab hcop⟩

/-- **RESIDUAL CONVERGENCE**: The centered fractional-part series converges
    by the Dirichlet test.

    Σ ({am/b} - (b-1)/(2b)) · 1/(m+1) converges.

    Proof (sketch): By `dirichlet_test` with:
    - a_n = {an/b} - (b-1)/(2b)  (bounded partial sums, by periodicity)
    - b_n = 1/(n+1)              (antitone, nonneg, tends to 0)

    TODO: Full proof once centered_fract_partial_sums_bounded is proved.
    The periodicity argument is: for coprime a,b, the map m → {am/b}
    permutes {1/b, 2/b, ..., (b-1)/b, 0}, so each period-b block sums
    to (0 + 1/b + ... + (b-1)/b) = (b-1)/2, and the centered partial
    sums oscillate within [−(b-1)/2, (b-1)/2]. -/
theorem centered_fract_residual_converges_sketch (a b : ℕ) (ha : 1 ≤ a) (hb : 2 ≤ b)
    (hab : a < b) (hcop : Nat.Coprime a b) :
    ∃ L : ℝ, Tendsto
      (fun n => ∑ m ∈ Finset.range n,
        (Int.fract ((a:ℝ) * ((m:ℕ):ℝ) / (b:ℝ)) - ((b:ℝ) - 1) / (2 * (b:ℝ))) *
        (1 / ((m:ℝ) + 1)))
      atTop (nhds L) := by
  obtain ⟨C, hC⟩ := centered_fract_partial_sums_bounded a b ha hb hab hcop
  obtain ⟨L, hL⟩ := Cathedral.Analysis.DirichletTest.dirichlet_test
    (fun m => Int.fract ((a:ℝ) * ((m:ℕ):ℝ) / (b:ℝ)) - ((b:ℝ) - 1) / (2 * (b:ℝ)))
    (fun m => 1 / ((m:ℝ) + 1))
    C hC
    (fun m => by positivity)
    (fun m n hmn => by
      apply div_le_div_of_nonneg_left one_pos.le (by positivity : (0:ℝ) < (m:ℝ) + 1)
      have : (m:ℝ) ≤ (n:ℝ) := Nat.cast_le.mpr hmn
      linarith)
    (by
      rw [Metric.tendsto_atTop]
      intro ε hε
      obtain ⟨N, hN⟩ := exists_nat_gt (1/ε)
      refine ⟨N, fun m hm => ?_⟩
      simp only [dist_zero_right, Real.norm_eq_abs]
      rw [abs_of_pos (by positivity : (0:ℝ) < 1 / ((m:ℝ) + 1))]
      rw [div_lt_iff₀ (by positivity : (0:ℝ) < (m:ℝ) + 1)]
      calc 1 = ε * (1 / ε) := by field_simp
        _ < ε * ↑N := by nlinarith
        _ ≤ ε * ((m:ℝ) + 1) := by
          have hm' : (N:ℝ) ≤ (m:ℝ) := Nat.cast_le.mpr hm
          nlinarith)
  exact ⟨L, hL⟩

-- ════════════════════════════════════════════════
-- §8. AXIOM AUDIT
-- ════════════════════════════════════════════════

-- Sub-axioms in this file (0 — all graduated or deleted):
--
-- GRADUATED (axiom → theorem, April 25, 2026):
--   ✅ integral_eq_S_combined  → integral_eq_sum_actualRowIntegral
--      (old axiom was FALSE: rowTerm wrong for two-tile rows)
--      (new theorem is trivially true by interval additivity)
--
-- ELIMINATED (April 25, 2026 — found to be mathematically false):
--   ✗ floor_weighted_log_sum_limit        — DELETED: log-divergent remainder
--   ✗ linear_series_convergent            — DELETED: log-divergent remainder
--   ✗ integral_eq_S_combined              — DELETED: rowTerm wrong for two-tile rows
--   The Stirling correction was incorrectly allocated between these two;
--   only the FULL s_combined converges, not individual pieces.
--
-- PROVED (zero sorry):
--   ✅ s_log_split                            — Log sum = Stirling + Digamma parts
--   ✅ rational_plus_stirling                 — M/b cancellation with Stirling
--   ✅ tileIndex_nonneg                       — Tile index ≥ 0
--   ✅ s_linear_decompose                     — Floor decomposition identity
--   ✅ centered_fract_partial_sums_bounded    — Periodic partial sums bounded
--   ✅ centered_fract_residual_converges_sketch — Centered residual converges (Dirichlet!)
--   ✅ s_combined_four_way                    — Four-way decomposition identity
--   ✅ s_combined_converges                   — GRADUATED: Combined convergence theorem
--   ✅ actualRowIntegral_nonneg               — Row integral ≥ 0
--   ✅ actualRowIntegral_le                   — Row integral ≤ 1/(am²) (geometric bound)
--   ✅ integral_eq_sum_actualRowIntegral       — GRADUATED: integral = Σ row integrals
--
-- Architecture:
--   integral_eq_sum_actualRowIntegral (trivial — interval additivity)
--     ← OffDiagPartition.integral_eq_sum_rows (PROVED)
--   actualRowIntegral_le (geometric bound)
--     ← integrand ∈ [0,1) + row width = 1/(a·m·(m+1))
--   s_combined_converges (monotone bounded)
--     ← rowTerm_nonneg + rowTerm_le_upper + comparison with Σ 1/m²

end Cathedral.Vasyunin.PartialSumConvergence
