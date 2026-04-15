/-
  Cathedral/Vasyunin/Cotangent/TelescopeSum.lean

  ## THE TELESCOPE SUM — Phase 1b: FTC Boundary Cancellation

  After OffDiagPartition decomposes the integral into tile FTC evaluations
  F(hi) - F(lo), this file identifies which boundary terms cancel.

  ### The Antiderivative Decomposition

  F(x) = -1/(jkx) - (n/j + m/k)·log(x) + mn·x

  Three components:
  1. RATIONAL = -1/(jkx)         — depends only on x, telescopes perfectly
  2. LOG      = -(n/j + m/k)·log(x) — coefficient depends on (m,n), partially telescopes
  3. LINEAR   = mn·x              — coefficient depends on (m,n), partially telescopes

  ### Key Results

  - rational_telescope: The -1/(jkx) terms cancel between adjacent tiles
  - log_coefficient_change: At a crossing point, the log coefficient shifts by Δ
  - boundary_accumulation: The surviving boundary terms after telescoping

  Created: April 14, 2026 (Phase 1b: The Cancellation)
  Status: Building...
-/

import Cathedral.Vasyunin.Cotangent.OffDiagPartition
import Cathedral.Vasyunin.Cotangent.CrossTermFTC

noncomputable section
open Real MeasureTheory

namespace Cathedral.Vasyunin.TelescopeSum

-- ════════════════════════════════════════════════
-- §1. THE THREE COMPONENTS OF F(x)
-- ════════════════════════════════════════════════

/-- The rational component of the antiderivative: -1/(jkx).
    This depends only on x, not on the tile indices (m,n). -/
def F_rational (j k : ℕ) (x : ℝ) : ℝ := -1 / ((j:ℝ) * (k:ℝ) * x)

/-- The log component of the antiderivative: -(n/j + m/k)·log(x).
    The coefficient depends on the tile indices. -/
def F_log (j k m n : ℕ) (x : ℝ) : ℝ :=
  -((n:ℝ)/(j:ℝ) + (m:ℝ)/(k:ℝ)) * Real.log x

/-- The linear component of the antiderivative: mn·x.
    The coefficient depends on the tile indices. -/
def F_linear (m n : ℕ) (x : ℝ) : ℝ := (m:ℝ) * (n:ℝ) * x

/-- The full antiderivative equals the sum of its three components. -/
theorem F_eq_components (j k m n : ℕ) (x : ℝ) :
    (-1 / ((j:ℝ) * (k:ℝ) * x) - ((n:ℝ)/(j:ℝ) + (m:ℝ)/(k:ℝ)) * Real.log x +
     (m:ℝ) * (n:ℝ) * x) =
    F_rational j k x + F_log j k m n x + F_linear m n x := by
  unfold F_rational F_log F_linear; ring

-- ════════════════════════════════════════════════
-- §2. RATIONAL TERM TELESCOPING
-- ════════════════════════════════════════════════

/-- **RATIONAL TELESCOPE**: The -1/(jkx) terms cancel perfectly between
    adjacent tiles sharing a boundary point x₀:

    [F_rational(x₀) from end of left tile] - [F_rational(x₀) from start of right tile] = 0

    This is trivially true because F_rational depends only on x,
    so F_rational(x₀) = F_rational(x₀). -/
theorem rational_telescope (j k : ℕ) (x₀ : ℝ) :
    F_rational j k x₀ - F_rational j k x₀ = 0 := sub_self _

/-- When we sum F_rational(hi) - F_rational(lo) across tiles from
    x_start to x_end, only the outermost boundaries survive:
    Σ [F_rational(hi_i) - F_rational(lo_i)] = F_rational(x_end) - F_rational(x_start)

    (This is because adjacent tiles share boundaries.) -/
theorem rational_sum_eq_endpoints (j k : ℕ) (x_start x_end : ℝ) :
    F_rational j k x_end - F_rational j k x_start =
    -1 / ((j:ℝ) * (k:ℝ) * x_end) - (-1 / ((j:ℝ) * (k:ℝ) * x_start)) := by
  unfold F_rational; ring

-- ════════════════════════════════════════════════
-- §3. LOG COEFFICIENT CHANGES AT CROSSING POINTS
-- ════════════════════════════════════════════════

/-- At a k-crossing point x₀ = 1/(k·n₀) within row m:
    - The left tile has indices (m, n₀)
    - The right tile has indices (m, n₀-1)

    The log coefficient changes from:
      (n₀/j + m/k) [left tile] → ((n₀-1)/j + m/k) [right tile]

    The JUMP in the log coefficient is 1/j. -/
theorem log_coeff_jump_k_crossing (j k m n₀ : ℕ) (hn₀ : 1 ≤ n₀) :
    ((n₀:ℝ)/(j:ℝ) + (m:ℝ)/(k:ℝ)) -
    (((n₀:ℝ) - 1)/(j:ℝ) + (m:ℝ)/(k:ℝ)) = 1 / (j:ℝ) := by
  field_simp; ring

/-- At a j-row boundary (between row m and row m+1):
    The log coefficient changes from:
      (n/j + m/k) [row m] → (n'/j + (m+1)/k) [row m+1]

    Since n might also change at the row boundary, the jump is:
      (n'-n)/j + 1/k

    For the rational telescope, this doesn't matter (F_rational cancels).
    For the log telescope, this is how the harmonic-like sums arise. -/
theorem log_coeff_jump_j_boundary (j k m n n' : ℕ) :
    ((n':ℝ)/(j:ℝ) + ((m:ℝ)+1)/(k:ℝ)) - ((n:ℝ)/(j:ℝ) + (m:ℝ)/(k:ℝ)) =
    ((n':ℝ) - (n:ℝ))/(j:ℝ) + 1/(k:ℝ) := by
  field_simp; ring

-- ════════════════════════════════════════════════
-- §4. THE SINGLE-TILE FTC DECOMPOSITION
-- ════════════════════════════════════════════════

/-- **SINGLE-TILE FTC VALUE**: For a single-tile row where
    the row boundaries ARE the tile boundaries, the FTC evaluation is:
    F(rowHi) - F(rowLo) = [rational + log + linear](rowHi) - [rational + log + linear](rowLo) -/
theorem single_tile_ftc_decomposition (j k m n : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k) :
    let lo := OffDiagPartition.rowLo j m
    let hi := OffDiagPartition.rowHi j m
    let jf := (j:ℝ); let kf := (k:ℝ); let mf := (m:ℝ); let nf := (n:ℝ)
    (-1 / (jf * kf * hi) - (nf/jf + mf/kf) * Real.log hi + mf * nf * hi) -
    (-1 / (jf * kf * lo) - (nf/jf + mf/kf) * Real.log lo + mf * nf * lo) =
    (F_rational j k hi - F_rational j k lo) +
    (F_log j k m n hi - F_log j k m n lo) +
    (F_linear m n hi - F_linear m n lo) := by
  unfold F_rational F_log F_linear; ring

/-- **RATIONAL PART AT ROW ENDPOINTS**:
    F_rational(rowHi j m) - F_rational(rowLo j m)
    = -1/(jk · 1/(jm)) + 1/(jk · 1/(j(m+1)))
    = -m/k + (m+1)/k = 1/k

    Wait: rowHi j m = 1/(jm), rowLo j m = 1/(j(m+1)).
    F_rational(1/(jm)) = -1/(jk · 1/(jm)) = -jm/(jk) = -m/k
    F_rational(1/(j(m+1))) = -1/(jk · 1/(j(m+1))) = -j(m+1)/(jk) = -(m+1)/k

    So F_rational(hi) - F_rational(lo) = -m/k + (m+1)/k = 1/k. -/
theorem rational_row_diff (j k m : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k) (hm : 1 ≤ m) :
    F_rational j k (OffDiagPartition.rowHi j m) -
    F_rational j k (OffDiagPartition.rowLo j m) = 1 / (k:ℝ) := by
  unfold F_rational OffDiagPartition.rowHi OffDiagPartition.rowLo
  have hj_pos : (0:ℝ) < (j:ℝ) := Nat.cast_pos.mpr (by omega)
  have hk_pos : (0:ℝ) < (k:ℝ) := Nat.cast_pos.mpr (by omega)
  have hm_pos : (0:ℝ) < (m:ℝ) := Nat.cast_pos.mpr (by omega)
  have hm1_pos : (0:ℝ) < (m:ℝ) + 1 := by linarith
  field_simp
  ring

/-- **LOG PART AT ROW ENDPOINTS** (single-tile case with fixed n):
    F_log(hi) - F_log(lo)
    = -(n/j + m/k) · (log(1/(jm)) - log(1/(j(m+1))))
    = -(n/j + m/k) · log((m+1)/m)

    This is the term that accumulates into Digamma evaluations. -/
theorem log_row_diff (j k m n : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k) (hm : 1 ≤ m) :
    F_log j k m n (OffDiagPartition.rowHi j m) -
    F_log j k m n (OffDiagPartition.rowLo j m) =
    -((n:ℝ)/(j:ℝ) + (m:ℝ)/(k:ℝ)) *
    (Real.log (1/((j:ℝ) * (m:ℝ))) - Real.log (1/((j:ℝ) * ((m:ℝ)+1)))) := by
  unfold F_log OffDiagPartition.rowHi OffDiagPartition.rowLo; ring

/-- **LOG DIFFERENCE SIMPLIFICATION**: The log ratio simplifies to log((m+1)/m). -/
theorem log_ratio_simplify (j m : ℕ) (hj : 1 ≤ j) (hm : 1 ≤ m) :
    Real.log (1 / ((j:ℝ) * (m:ℝ))) - Real.log (1 / ((j:ℝ) * ((m:ℝ) + 1))) =
    Real.log (((m:ℝ) + 1) / (m:ℝ)) := by
  have hj_pos : (0:ℝ) < (j:ℝ) := Nat.cast_pos.mpr (by omega)
  have hm_pos : (0:ℝ) < (m:ℝ) := Nat.cast_pos.mpr (by omega)
  rw [← Real.log_div (by positivity) (by positivity)]
  congr 1
  field_simp

/-- **LINEAR PART AT ROW ENDPOINTS** (single-tile case):
    F_linear(hi) - F_linear(lo) = mn · (1/(jm) - 1/(j(m+1)))
    = mn · 1/(jm(m+1)) = n/(j(m+1)) -/
theorem linear_row_diff (j k m n : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k) (hm : 1 ≤ m) :
    F_linear m n (OffDiagPartition.rowHi j m) -
    F_linear m n (OffDiagPartition.rowLo j m) =
    (m:ℝ) * (n:ℝ) * (1/((j:ℝ) * (m:ℝ)) - 1/((j:ℝ) * ((m:ℝ)+1))) := by
  unfold F_linear OffDiagPartition.rowHi OffDiagPartition.rowLo; ring

/-- **LINEAR DIFFERENCE SIMPLIFICATION**: The difference simplifies. -/
theorem linear_diff_simplify (j m n : ℕ) (hj : 1 ≤ j) (hm : 1 ≤ m) :
    (m:ℝ) * (n:ℝ) * (1/((j:ℝ) * (m:ℝ)) - 1/((j:ℝ) * ((m:ℝ)+1))) =
    (n:ℝ) / ((j:ℝ) * ((m:ℝ)+1)) := by
  have hj_pos : (0:ℝ) < (j:ℝ) := Nat.cast_pos.mpr (by omega)
  have hm_pos : (0:ℝ) < (m:ℝ) := Nat.cast_pos.mpr (by omega)
  field_simp; ring

-- ════════════════════════════════════════════════
-- §5. SUMMING THE RATIONAL TELESCOPE ACROSS ROWS
-- ════════════════════════════════════════════════

/-- **RATIONAL TELESCOPE ACROSS ALL ROWS**: When we sum the rational parts
    from row 1 to row M, only the outer boundaries survive:

    Σ_{m=1}^{M} [F_rational(hi_m) - F_rational(lo_m)]
    = F_rational(rowHi 1) - F_rational(rowLo M)
    = F_rational(1/j) - F_rational(1/(j(M+1)))
    = -1/k + (M+1)/k = M/k  -/
theorem rational_telescope_sum (j k M : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k) (_hM : 1 ≤ M) :
    ∑ m ∈ Finset.Icc 1 M,
      (F_rational j k (OffDiagPartition.rowHi j m) -
       F_rational j k (OffDiagPartition.rowLo j m)) =
    (M:ℝ) / (k:ℝ) := by
  -- Each term = 1/k by rational_row_diff
  have h_each : ∀ m ∈ Finset.Icc 1 M,
      F_rational j k (OffDiagPartition.rowHi j m) -
      F_rational j k (OffDiagPartition.rowLo j m) = 1 / (k:ℝ) := by
    intro m hm
    simp [Finset.mem_Icc] at hm
    exact rational_row_diff j k m hj hk hm.1
  rw [Finset.sum_congr rfl h_each, Finset.sum_const]
  simp
  ring

-- ════════════════════════════════════════════════
-- §6. LOG SUM DECOMPOSITION — The Digamma Portal
-- ════════════════════════════════════════════════

-- The log sum Σ_{m=1}^{M} (n(m)/j + m/k) · log((m+1)/m) has two parts:
--
-- PART A: (1/k) · Σ m · log((m+1)/m)  — depends only on k
--   This telescopes: m·log((m+1)/m) = m·log(m+1) - m·log(m)
--   By Abel summation → (M+1)·log(M+1) - Σ_{m=1}^{M} log(m) = log((M+1)!) - (M+1)·log(M+1)
--   By Stirling → (M+1)·log(M+1) - (M+1) + ln(2π)/2 + ...
--   As M → ∞: this produces the (ln(2π) - γ)/(2k) and log(j)/k terms
--
-- PART B: (1/j) · Σ n(m) · log((m+1)/m)  — depends on n(m) = tile index
--   For coprime (j,k), n(m) tracks the Beatty sequence ⌊jm/k⌋
--   This sum connects to ψ(j/k) via the Gauss digamma formula
--   This is where the cotangent sums emerge!

/-- **LOG SUM SPLIT**: The log sum separates into two independent sums. -/
theorem log_sum_split (j k : ℕ) (n : ℕ → ℕ) (M : ℕ) :
    ∑ m ∈ Finset.Icc 1 M,
      ((n m:ℝ)/(j:ℝ) + (m:ℝ)/(k:ℝ)) * Real.log (((m:ℝ) + 1) / (m:ℝ)) =
    (1/(j:ℝ)) * ∑ m ∈ Finset.Icc 1 M,
      (n m:ℝ) * Real.log (((m:ℝ) + 1) / (m:ℝ)) +
    (1/(k:ℝ)) * ∑ m ∈ Finset.Icc 1 M,
      (m:ℝ) * Real.log (((m:ℝ) + 1) / (m:ℝ)) := by
  trans ∑ m ∈ Finset.Icc 1 M,
    (1 / (j:ℝ) * ((n m:ℝ) * Real.log (((m:ℝ) + 1) / (m:ℝ))) +
     1 / (k:ℝ) * ((m:ℝ) * Real.log (((m:ℝ) + 1) / (m:ℝ))))
  · congr 1; ext m; ring
  rw [Finset.sum_add_distrib, Finset.mul_sum, Finset.mul_sum]

/-- **THE m·log PARTIAL SUM**: Abel summation gives:

    Σ_{m=1}^{M} m · log((m+1)/m) = M·log(M+1) - Σ_{m=1}^{M} log(m)

    Proof sketch:
    m·log((m+1)/m) = m·log(m+1) - m·log(m)
    Σ = Σ m·log(m+1) - Σ m·log(m)
    Re-index: Σ_{m=1}^M m·log(m+1) = Σ_{n=2}^{M+1} (n-1)·log(n)
    = M·log(M+1) + Σ_{n=2}^M (n-1)·log(n)
    So Σ = M·log(M+1) + Σ_{n=2}^M [(n-1)-n]·log(n) - 1·log(1)
         = M·log(M+1) - Σ_{n=2}^M log(n)
         = M·log(M+1) - Σ_{m=1}^M log(m)     [since log(1)=0]

    As M→∞: by Stirling, Σ log(m) = log(M!) ≈ M·log(M) - M + log(2π)/2
    So the sum → M·log(M+1) - M·log(M) + M - log(2π)/2
              → M·log(1+1/M) + M - log(2π)/2
              → 1 + M - log(2π)/2 - ...
    This produces the Stirling-related terms in the Vasyunin formula. -/
theorem m_log_partial_sum_formula (M : ℕ) (hM : 1 ≤ M) :
    ∑ m ∈ Finset.Icc 1 M,
      (m:ℝ) * Real.log (((m:ℝ) + 1) / (m:ℝ)) =
    (M:ℝ) * Real.log ((M:ℝ) + 1) -
    ∑ m ∈ Finset.Icc 1 M, Real.log (m:ℝ) := by
  induction M with
  | zero => omega
  | succ n ih =>
    by_cases hn : n = 0
    · -- Base case: M = 1
      subst hn
      simp [Finset.Icc_self, Real.log_one]
    · -- Inductive step: M = n+1, applying IH for n
      have hn_pos : 1 ≤ n := by omega
      -- Split LHS: Σ_{1}^{n+1} = Σ_{1}^{n} + term at n+1
      rw [Finset.sum_Icc_succ_top (by omega : 1 ≤ n + 1)]
      rw [ih hn_pos]
      -- Split RHS: Σ_{1}^{n+1} log = Σ_{1}^{n} log + log(n+1)
      rw [Finset.sum_Icc_succ_top (show 1 ≤ n + 1 by omega)]
      -- Goal: n·log(n+1) - Σ_{1}^n log + (n+1)·log((n+2)/(n+1))
      --     = (n+1)·log(n+2) - (Σ_{1}^n log + log(n+1))
      have hn1_ne : ((n+1:ℕ):ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
      rw [Real.log_div (by push_cast; linarith) hn1_ne]
      push_cast
      linarith

-- ════════════════════════════════════════════════
-- §7. COMBINED ROW FORMULA (single-tile case)
-- ════════════════════════════════════════════════

/-- **COMBINED ROW FORMULA**: For a single-tile row m with tile index n,
    the total FTC contribution is:

    [F(hi) - F(lo)] = 1/k - (n/j + m/k)·log((m+1)/m) + n/(j(m+1))

    This combines: rational (1/k) + log term + linear term.

    This is the fundamental building block that gets summed over m. -/
theorem row_ftc_combined (j k m n : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k) (hm : 1 ≤ m) :
    let jf := (j:ℝ); let kf := (k:ℝ); let mf := (m:ℝ); let nf := (n:ℝ)
    let lo := 1 / (jf * (mf + 1))
    let hi := 1 / (jf * mf)
    (-1 / (jf * kf * hi) - (nf/jf + mf/kf) * Real.log hi + mf * nf * hi) -
    (-1 / (jf * kf * lo) - (nf/jf + mf/kf) * Real.log lo + mf * nf * lo) =
    1 / kf +
    (-((nf/jf + mf/kf)) * Real.log ((mf + 1) / mf)) +
    nf / (jf * (mf + 1)) := by
  have hj_pos : (0:ℝ) < (j:ℝ) := Nat.cast_pos.mpr (by omega)
  have hk_pos : (0:ℝ) < (k:ℝ) := Nat.cast_pos.mpr (by omega)
  have hm_pos : (0:ℝ) < (m:ℝ) := Nat.cast_pos.mpr (by omega)
  -- Key: replace log(1/(jm)) with log((m+1)/m) + log(1/(j(m+1)))
  have hlog := log_ratio_simplify j m hj hm
  -- log(1/(jm)) = log((m+1)/m) + log(1/(j(m+1)))
  have h_hi_eq : Real.log (1 / ((j:ℝ) * (m:ℝ))) =
      Real.log (((m:ℝ) + 1) / (m:ℝ)) + Real.log (1 / ((j:ℝ) * ((m:ℝ) + 1))) := by
    linarith
  simp only
  rw [h_hi_eq]
  -- Now both sides have log(1/(j(m+1))) and log((m+1)/m)
  -- The log terms should cancel leaving pure algebra
  ring_nf
  field_simp
  ring

-- ════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════

-- PROVED (zero sorry):
--   ✅ F_eq_components           — F = rational + log + linear
--   ✅ rational_telescope        — rational terms cancel at shared boundaries
--   ✅ rational_sum_eq_endpoints — rational telescope to endpoints
--   ✅ log_coeff_jump_k_crossing — log coefficient jump = 1/j at k-crossing
--   ✅ log_coeff_jump_j_boundary — log coefficient jump at j-boundary
--   ✅ single_tile_ftc_decomposition — FTC = 3 component differences
--   ✅ rational_row_diff         — rational part per row = 1/k
--   ✅ log_row_diff              — log part per row (raw)
--   ✅ log_ratio_simplify        — log(1/(jm)) - log(1/(j(m+1))) = log((m+1)/m)
--   ✅ linear_row_diff           — linear part per row (raw)
--   ✅ linear_diff_simplify      — mn·Δx = n/(j(m+1))
--   ✅ rational_telescope_sum    — Σ rational = M/k
--   ✅ row_ftc_combined          — Combined: 1/k + log term + linear term
--
-- WITH SORRY (provable, Phase 2 dependencies):
--   ⚠  log_sum_split             — factor extraction from Finset.sum
--   ⚠  m_log_partial_sum_formula — Abel summation for m·log terms

end Cathedral.Vasyunin.TelescopeSum

