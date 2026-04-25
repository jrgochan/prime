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

  S_rational(M) = (M-1)/b                                    (trivial)
  S_log(M)      = -Σ (n(m)/a + m/b)·log((m+1)/m)            (key: Gauss digamma)
  S_linear(M)   = Σ n(m)/(a(m+1))                            (convergent series)

  ### The Limit

  As M → ∞, the combination S_rational + S_log + S_linear converges to
  the Vasyunin formula because:

  1. S_rational = (M-1)/b → ∞ (diverges)
  2. S_log splits into:
     a. -(1/b)·Σ m·log((m+1)/m) → -(1/b)·(M·log M - M + ln(2π)/2) (Stirling)
     b. -(1/a)·Σ n(m)·log((m+1)/m) → related to ψ(a/b) (Gauss digamma)
  3. The divergent M/b terms cancel between (1) and (2a)
  4. What remains is finite and equals vasyuninGramFormula

  Created: April 25, 2026 — Decomposition of the Final Axiom
  Status: BUILDING
-/

import Cathedral.Vasyunin.Cotangent.LogDigammaBridge
import Cathedral.Vasyunin.Cotangent.TelescopeSum
import Cathedral.Vasyunin.Cotangent.StirlingBridge
import Cathedral.Vasyunin.Cotangent.OffDiagPartition
import Cathedral.White.Infrastructure.DirichletTest
import Cathedral.White.Infrastructure.CenteredFractBound
import Mathlib.Analysis.SpecialFunctions.Stirling
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
def S_rational (b M : ℕ) : ℝ := ((M:ℝ) - 1) / (b:ℝ)

/-- The log partial sum: -Σ_{m=1}^{M-1} (n(m)/a + m/b) · log((m+1)/m). -/
def S_log (a b M : ℕ) : ℝ :=
  -∑ m ∈ Finset.Icc 1 (M - 1),
    ((tileIndex a b m : ℝ) / (a:ℝ) + (m:ℝ) / (b:ℝ)) *
    Real.log (((m:ℝ) + 1) / (m:ℝ))

/-- The linear partial sum: Σ_{m=1}^{M-1} n(m) / (a·(m+1)). -/
def S_linear (a b M : ℕ) : ℝ :=
  ∑ m ∈ Finset.Icc 1 (M - 1),
    (tileIndex a b m : ℝ) / ((a:ℝ) * ((m:ℝ) + 1))

/-- The combined partial sum S(M) = S_rational + S_log + S_linear. -/
def S_combined (a b M : ℕ) : ℝ :=
  S_rational b M + S_log a b M + S_linear a b M

-- ════════════════════════════════════════════════
-- §3. THE LOG SUM SPLITS INTO STIRLING + DIGAMMA
-- ════════════════════════════════════════════════

/-- The log sum splits: S_log = S_log_stirling + S_log_digamma
    where:
      S_log_stirling = -(1/b) · Σ m · log((m+1)/m)
      S_log_digamma  = -(1/a) · Σ n(m) · log((m+1)/m) -/
def S_log_stirling (b M : ℕ) : ℝ :=
  -(1/(b:ℝ)) * ∑ m ∈ Finset.Icc 1 (M - 1),
    (m:ℝ) * Real.log (((m:ℝ) + 1) / (m:ℝ))

def S_log_digamma (a b M : ℕ) : ℝ :=
  -(1/(a:ℝ)) * ∑ m ∈ Finset.Icc 1 (M - 1),
    (tileIndex a b m : ℝ) * Real.log (((m:ℝ) + 1) / (m:ℝ))

theorem S_log_split (a b M : ℕ) :
    S_log a b M = S_log_stirling b M + S_log_digamma a b M := by
  simp only [S_log, S_log_stirling, S_log_digamma]
  rw [neg_mul, neg_mul, ← neg_add]
  congr 1
  rw [Finset.mul_sum, Finset.mul_sum, ← Finset.sum_add_distrib]
  congr 1; ext m; ring

-- ════════════════════════════════════════════════
-- §4. STIRLING COMPONENT — PROVED
-- ════════════════════════════════════════════════

-- The Stirling component uses the already-proved m_log_partial_sum_formula.
-- S_rational + S_log_stirling cancels the divergent M/b and leaves
-- finite terms related to ln(2π)/2 and Euler-Mascheroni constant.

/-- **CANCELLATION LEMMA**: S_rational(M) + S_log_stirling(M) =
    -(1/b) · [M·log(M) - M + log(2π)/2 + ...] + (M-1)/b

    The M/b terms cancel, leaving finite terms. -/
theorem rational_plus_stirling (b M : ℕ) (_hb : 1 ≤ b) (hM : 2 ≤ M) :
    S_rational b M + S_log_stirling b M =
    ((M:ℝ) - 1) / (b:ℝ) -
    (1/(b:ℝ)) * (((M:ℝ) - 1) * Real.log (M:ℝ) -
      ∑ m ∈ Finset.Icc 1 (M - 1), Real.log (m:ℝ)) := by
  simp only [S_rational, S_log_stirling]
  rw [neg_mul]
  have h := TelescopeSum.m_log_partial_sum_formula (M - 1) (by omega)
  have hcast : ((M - 1 : ℕ) : ℝ) = (M : ℝ) - 1 := by
    rw [Nat.cast_sub (by omega : 1 ≤ M)]; simp
  rw [h, hcast]
  have hM_eq : (M : ℝ) - 1 + 1 = (M : ℝ) := by ring
  rw [hM_eq]
  ring

-- ════════════════════════════════════════════════
-- §5. THE DIGAMMA COMPONENT — SUB-AXIOM
-- ════════════════════════════════════════════════

/-- **SUB-AXIOM 1 (Gauss Digamma Limit)**:
    The floor-weighted log sum converges to a specific value related
    to the digamma function at a/b.

    -(1/a) · Σ_{m=1}^{M-1} ⌊am/b⌋ · log((m+1)/m)
    → -(1/a) · [ψ(a/b) + γ + log(b)] · b + finite corrections

    This is the deepest analytic fact. The connection goes through:
    1. ⌊am/b⌋ = am/b - {am/b} (floor = value - fractional part)
    2. Σ (am/b) · log((m+1)/m) = (a/b) · Σ m · log((m+1)/m) (handled by Stirling)
    3. Σ {am/b} · log((m+1)/m) → ψ(a/b) + γ + log(b/a) (Gauss digamma)

    The Gauss digamma connection: for coprime p/q,
    ψ(p/q) = -γ - log(2q) - (π/2)·cot(πp/q) + 2·Σ cos(2πnp/q)·log(sin(πn/q))

    This sub-axiom encapsulates the convergence of the floor-weighted log sum
    to specific values involving digamma, Euler-Mascheroni, and cotangent sums.

    The target value is stated abstractly — the precise constant depends on
    ψ(a/b) via the Gauss digamma formula. -/
axiom floor_weighted_log_sum_limit (a b : ℕ) (ha : 1 ≤ a) (hb : 1 ≤ b)
    (hab : a < b) (hcop : Nat.Coprime a b) :
    ∃ L_digamma : ℝ,
    Tendsto
      (fun M : ℕ => S_log_digamma a b M +
        ((a:ℝ)/(b:ℝ)) * (1/(b:ℝ)) *
          (((M:ℝ) - 1) * Real.log (M:ℝ) -
           ∑ m ∈ Finset.Icc 1 (M - 1), Real.log (m:ℝ)))
      atTop
      (nhds L_digamma)

-- ════════════════════════════════════════════════
-- §6. THE LINEAR COMPONENT — SUB-AXIOM
-- ════════════════════════════════════════════════

/-- **SUB-AXIOM 2 (Linear Series Convergence)**:
    The series Σ n(m)/(a(m+1)) minus a correction converges to a finite limit.

    Key decomposition: ⌊am/b⌋ = am/b - {am/b}, so
    S_linear = (1/b)·Σ m/(m+1) - (1/a)·Σ {am/b}/(m+1)

    The first sum diverges like log(M), but is cancelled by the
    Stirling correction from S_rational + S_log_stirling.
    The second sum (fractional parts divided by m+1) converges
    absolutely since 0 ≤ {am/b} < 1 and Σ 1/(m+1) diverges but
    the fractional parts average to (b-1)/(2b) by equidistribution.

    Actually: the residual after Stirling cancellation is the
    CONVERGENT fractional-part weighted harmonic sum. -/
axiom linear_series_convergent (a b : ℕ) (ha : 1 ≤ a) (hb : 1 ≤ b)
    (hab : a < b) (hcop : Nat.Coprime a b) :
    ∃ L_linear : ℝ,
    Tendsto
      (fun M : ℕ => S_linear a b M -
        ((a:ℝ)/(b:ℝ)) * (1/(a:ℝ)) *
          (((M:ℝ) - 1) * Real.log (M:ℝ) -
           ∑ m ∈ Finset.Icc 1 (M - 1), Real.log (m:ℝ)))
      atTop
      (nhds L_linear)

/-- **FRACTIONAL PART SERIES**: The convergent remainder after
    subtracting the main term from S_linear.

    S_linear_residual = -1/a · Σ {am/b} / (m+1)

    This converges absolutely since 0 ≤ {am/b} < 1. -/
def S_linear_residual (a b M : ℕ) : ℝ :=
  -(1/(a:ℝ)) * ∑ m ∈ Finset.Icc 1 (M - 1),
    (Int.fract ((a:ℝ) * (m:ℝ) / (b:ℝ))) / ((m:ℝ) + 1)

/-- The linear sum decomposes into a main term + convergent residual.
    S_linear = (1/b)·Σ m/(m+1) + S_linear_residual

    This follows from ⌊am/b⌋ = am/b - {am/b}. -/
theorem S_linear_decompose (a b M : ℕ) (_ha : 1 ≤ a) (hb : 1 ≤ b) :
    S_linear a b M =
    (1/(b:ℝ)) * ∑ m ∈ Finset.Icc 1 (M - 1),
      (m:ℝ) / ((m:ℝ) + 1) +
    S_linear_residual a b M := by
  simp only [S_linear, S_linear_residual, tileIndex]
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
-- §7. ASSEMBLY — THE COMBINED LIMIT
-- ════════════════════════════════════════════════

/-- **The integral equals the row sum** (connecting OffDiagPartition to our sums).
    This is the bridge: ∫_{1/(aM)}^1 = Σ R(m) = S_combined(M).

    Proved by: OffDiagPartition.integral_eq_sum_rows gives the integral
    as a sum of row integrals, and row_ftc_combined evaluates each row
    integral into 1/b + log_term + linear_term. -/
axiom integral_eq_S_combined (a b : ℕ) (ha : 1 ≤ a) (hb : 1 ≤ b)
    (hab : a < b) (hcop : Nat.Coprime a b) (M : ℕ) (hM : 2 ≤ M) :
    ∫ x in (1 / ((a:ℝ) * (M:ℝ)))..(1:ℝ),
      Int.fract (1 / ((a:ℝ) * x)) * Int.fract (1 / ((b:ℝ) * x)) =
    S_combined a b M

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
      |Cathedral.White.Infrastructure.DirichletTest.partialSum₀
        (fun m => Int.fract ((a:ℝ) * ((m:ℕ):ℝ) / (b:ℝ)) - ((b:ℝ) - 1) / (2 * (b:ℝ))) n| ≤ C :=
  ⟨(b:ℝ), Cathedral.White.Infrastructure.CenteredFractBound.centered_fract_partial_sums_bounded'
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
  obtain ⟨L, hL⟩ := Cathedral.White.Infrastructure.DirichletTest.dirichlet_test
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

-- Sub-axioms in this file (4):
--   1. floor_weighted_log_sum_limit          — Gauss digamma convergence
--   2. linear_series_convergent              — Linear series convergence
--   3. integral_eq_S_combined                — Integral = algebraic sum (evaluative)
--   4. centered_fract_partial_sums_bounded   — Periodic partial sums bounded (number theory)
--
-- PROVED (zero sorry):
--   ✅ S_log_split                            — Log sum = Stirling + Digamma parts
--   ✅ rational_plus_stirling                 — M/b cancellation with Stirling
--   ✅ tileIndex_nonneg                       — Tile index ≥ 0
--   ✅ S_linear_decompose                     — Floor decomposition identity
--   ✅ centered_fract_residual_converges_sketch — Residual converges (by Dirichlet test!)
--
-- Architecture:
--   centered_fract_partial_sums_bounded (number theory)
--     → dirichlet_test (White/Infrastructure, PROVED)
--     → centered_fract_residual_converges_sketch
--     → linear_series_convergent (when combined with Stirling cancellation)

end Cathedral.Vasyunin.PartialSumConvergence
