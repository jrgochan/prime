/-
  Cathedral/Vasyunin/Cotangent/StirlingBridge.lean

  **THE STIRLING BRIDGE** (The Dawn Strike, April 12, 2026)

  Proves the analytic identity underlying the diagonal Gram entry:

    lim_{K→∞} Σ_{n=0}^{K-2} [-2(n+1)·log(1+1/(n+1)) + 2 - 1/(n+2)]
    = ln(2π) - γ - 1

  These are the partial sums of ∫₀¹ {1/u}² du decomposed via the
  piecewise identity on each interval [1/(n+1), 1/n].

  The proof uses:
  - Stirling's formula: stirlingSeq K → √π (from Mathlib)
  - Euler-Mascheroni: H_K - ln K → γ  (from Mathlib)
  - Algebraic telescoping of Σ n·log((n+1)/n)
  - Harmonic series shifting

  Created: April 12, 2026, 4:30 AM MDT (The Dawn Strike)
  Integrated into Cathedral: April 12, 2026, 4:49 AM MDT
-/

import Mathlib.Analysis.SpecialFunctions.Stirling
import Mathlib.NumberTheory.Harmonic.EulerMascheroni

noncomputable section
open Real Filter

namespace Cathedral.Vasyunin.StirlingBridge

-- ════════════════════════════════════════════════
-- §1. THE STIRLING-EULER LIMIT
-- ════════════════════════════════════════════════

/-- The partial sum P(K) = 2·log(stirlingSeq K) + log(2) - 1 - (harmonic K - log K). -/
def partialSum (K : ℕ) : ℝ :=
  2 * Real.log (Stirling.stirlingSeq K) + Real.log 2 - 1 -
  ((harmonic K : ℝ) - Real.log (K : ℝ))

/-- P(K) → log(2π) - γ - 1 as K → ∞. -/
theorem tendsto_partialSum :
    Tendsto partialSum atTop (nhds (Real.log (2 * Real.pi) - eulerMascheroniConstant - 1)) := by
  unfold partialSum
  have htarget : Real.log (2 * Real.pi) - eulerMascheroniConstant - 1 =
      (2 * Real.log (Real.sqrt Real.pi) + Real.log 2 - 1) - eulerMascheroniConstant := by
    rw [show 2 * Real.log (Real.sqrt Real.pi) = Real.log Real.pi from by
      rw [Real.log_sqrt (le_of_lt Real.pi_pos)]; ring]
    rw [show Real.log Real.pi + Real.log 2 = Real.log (2 * Real.pi) from by
      rw [← Real.log_mul (by positivity : (Real.pi : ℝ) ≠ 0) (by norm_num : (2:ℝ) ≠ 0)]
      ring_nf]
    ring
  rw [htarget]
  have h_stirling : Tendsto (fun K => 2 * Real.log (Stirling.stirlingSeq K))
      atTop (nhds (2 * Real.log (Real.sqrt Real.pi))) := by
    have hstir := Stirling.tendsto_stirlingSeq_sqrt_pi
    exact (hstir.log (ne_of_gt (Real.sqrt_pos.mpr Real.pi_pos))).const_mul 2
  have h_euler := Real.tendsto_harmonic_sub_log
  have h_const : Tendsto (fun _ : ℕ => Real.log 2 - 1)
      atTop (nhds (Real.log 2 - 1)) := tendsto_const_nhds
  have h_combined := (h_stirling.add h_const).sub h_euler
  convert h_combined using 1
  · ext K; ring
  · congr 1; ring

-- ════════════════════════════════════════════════
-- §2. ALGEBRAIC SUB-LEMMAS
-- ════════════════════════════════════════════════

/-- Σ_{m=0}^{N-1} log(m+1) = log(N!). -/
private lemma sum_log_eq_log_factorial (N : ℕ) :
    ∑ m ∈ Finset.range N, Real.log ((m : ℝ) + 1) = Real.log (Nat.factorial N : ℝ) := by
  induction N with
  | zero => simp
  | succ n ih =>
    rw [Finset.sum_range_succ, ih]
    have hn1 : ((n : ℝ) + 1) ≠ 0 := by positivity
    have hfact : (Nat.factorial n : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (Nat.factorial_ne_zero n)
    rw [show Nat.factorial (n + 1) = (n + 1) * Nat.factorial n from Nat.factorial_succ n]
    push_cast
    rw [Real.log_mul hn1 hfact]; ring

/-- Key telescoping: Σ_{m=0}^{N-1} (m+1)·log((m+2)/(m+1)) = (N+1)·log(N+1) - log((N+1)!). -/
private lemma sum_weighted_log_telescope (N : ℕ) :
    ∑ m ∈ Finset.range N,
      ((m : ℝ) + 1) * Real.log (((m : ℝ) + 2) / ((m : ℝ) + 1)) =
    ((N : ℝ) + 1) * Real.log ((N : ℝ) + 1) - Real.log (Nat.factorial (N + 1) : ℝ) := by
  induction N with
  | zero =>
    simp [Nat.factorial]
  | succ n ih =>
    rw [Finset.sum_range_succ, ih]
    push_cast
    have hn1 : (0 : ℝ) < (n : ℝ) + 1 := by positivity
    have hn2 : (0 : ℝ) < (n : ℝ) + 2 := by positivity
    rw [Real.log_div (ne_of_gt hn2) (ne_of_gt hn1)]
    rw [show Nat.factorial (n + 2) = (n + 2) * Nat.factorial (n + 1) from
      Nat.factorial_succ (n + 1)]
    push_cast
    rw [Real.log_mul (ne_of_gt hn2)
      (Nat.cast_ne_zero.mpr (Nat.factorial_ne_zero (n + 1)))]
    ring

/-- P(K) = 2·log(K!) - 2K·log(K) + 2K - 1 - H_K via Stirling expansion. -/
private lemma partialSum_expand (K : ℕ) (hK : 1 ≤ K) :
    partialSum K =
    2 * Real.log (Nat.factorial K : ℝ) - 2 * (K : ℝ) * Real.log (K : ℝ) +
    2 * (K : ℝ) - 1 - (harmonic K : ℝ) := by
  unfold partialSum
  rw [Stirling.log_stirlingSeq_formula]
  have hK_pos : (0 : ℝ) < (K : ℝ) := Nat.cast_pos.mpr (by omega)
  have hK_ne : (K : ℝ) ≠ 0 := ne_of_gt hK_pos
  rw [Real.log_div (ne_of_gt hK_pos) (ne_of_gt (Real.exp_pos 1))]
  rw [show Real.log (2 * (K : ℝ)) = Real.log 2 + Real.log (K : ℝ) from
    Real.log_mul (by norm_num) hK_ne]
  rw [Real.log_exp]
  ring

-- ════════════════════════════════════════════════
-- §3. HARMONIC SHIFT IDENTITY
-- ════════════════════════════════════════════════

/-- Σ_{n=0}^{M-1} 1/(n+2) = H_{M+1} - 1. -/
private lemma harmonic_shift (M : ℕ) :
    (∑ n ∈ Finset.range M, (1 / ((n : ℚ) + 2) : ℚ)) = harmonic (M + 1) - 1 := by
  induction M with
  | zero => simp [harmonic_succ, harmonic_zero]
  | succ m ih =>
    rw [Finset.sum_range_succ, ih]
    rw [show m + 1 + 1 = m + 2 from by omega]
    rw [harmonic_succ (m + 1), harmonic_succ m]
    push_cast; ring

/-- Real-valued harmonic shift. -/
private lemma harmonic_shift_real (M : ℕ) :
    ∑ n ∈ Finset.range M, (1 / ((n : ℝ) + 2)) = ((harmonic (M + 1) : ℚ) : ℝ) - 1 := by
  have hq := harmonic_shift M
  have := congr_arg (fun (q : ℚ) => (q : ℝ)) hq
  simp only [Rat.cast_sum, Rat.cast_div, Rat.cast_one, Rat.cast_add,
             Rat.cast_natCast, Rat.cast_sub] at this
  linarith

-- ════════════════════════════════════════════════
-- §4. THE SERIES BRIDGE (FINAL ASSEMBLY)
-- ════════════════════════════════════════════════

/-- P(M+2) = Σ_{n=0}^{M} [-2(n+1)·log(1+1/(n+1)) + 2 - 1/(n+2)]. -/
theorem partialSum_eq_series_sum' (M : ℕ) :
    partialSum (M + 2) =
    ∑ n ∈ Finset.range (M + 1),
      (-2 * ((n : ℝ) + 1) * Real.log (1 + 1 / ((n : ℝ) + 1)) + 2 - 1 / ((n : ℝ) + 2)) := by
  rw [partialSum_expand (M + 2) (by omega)]
  have hlog_rw : ∀ n : ℕ,
      -2 * ((n : ℝ) + 1) * Real.log (1 + 1 / ((n : ℝ) + 1)) + 2 - 1 / ((n : ℝ) + 2) =
      -2 * (((n : ℝ) + 1) * Real.log (((n : ℝ) + 2) / ((n : ℝ) + 1))) +
      (2 - 1 / ((n : ℝ) + 2)) := by
    intro n
    have : ((n : ℝ) + 1) ≠ 0 := by positivity
    rw [show 1 + 1 / ((n : ℝ) + 1) = ((n : ℝ) + 2) / ((n : ℝ) + 1) from by field_simp; ring]
    ring
  simp_rw [hlog_rw, Finset.sum_add_distrib]

  have hlogsum : ∑ n ∈ Finset.range (M + 1),
      (-2 * (((n : ℝ) + 1) * Real.log (((n : ℝ) + 2) / ((n : ℝ) + 1)))) =
      -2 * (((M : ℝ) + 2) * Real.log ((M : ℝ) + 2) -
            Real.log (Nat.factorial (M + 2) : ℝ)) := by
    have : ∀ n ∈ Finset.range (M + 1),
        (-2 * (((n : ℝ) + 1) * Real.log (((n : ℝ) + 2) / ((n : ℝ) + 1)))) =
        -2 * (((n : ℝ) + 1) * Real.log (((n : ℝ) + 2) / ((n : ℝ) + 1))) := by
      intros; ring
    rw [Finset.sum_congr rfl this, ← Finset.mul_sum, sum_weighted_log_telescope (M + 1)]
    rw [show M + 1 + 1 = M + 2 from by omega]
    push_cast; ring
  rw [hlogsum]
  have hconst : ∑ n ∈ Finset.range (M + 1), ((2 : ℝ) - 1 / ((n : ℝ) + 2)) =
      2 * ((M : ℝ) + 1) - ∑ n ∈ Finset.range (M + 1), (1 / ((n : ℝ) + 2)) := by
    rw [Finset.sum_sub_distrib, Finset.sum_const, Finset.card_range, nsmul_eq_mul]
    push_cast; ring
  rw [hconst, harmonic_shift_real (M + 1)]
  rw [show M + 1 + 1 = M + 2 from by omega]
  push_cast; ring

/-- P(K) = Σ piecewise terms for K ≥ 2. -/
theorem partialSum_eq_series_sum (K : ℕ) (hK : K ≥ 2) :
    partialSum K =
    ∑ n ∈ Finset.range (K - 1),
      (-2 * ((n : ℝ) + 1) * Real.log (1 + 1 / ((n : ℝ) + 1)) + 2 - 1 / ((n : ℝ) + 2)) := by
  have hM : K = (K - 2) + 2 := by omega
  rw [hM, show (K - 2) + 2 - 1 = (K - 2) + 1 from by omega]
  exact partialSum_eq_series_sum' (K - 2)

-- ════════════════════════════════════════════════
-- SUMMARY: THE INTEGRAL VALUE
-- ════════════════════════════════════════════════
--
-- With both theorems proved:
-- 1. partialSum_eq_series_sum: P(K) = Σ piecewise terms
-- 2. tendsto_partialSum: P(K) → log(2π) - γ - 1
-- We conclude: ∫₀¹ {1/u}² du = log(2π) - γ - 1
--
-- This is the analytic substance of vasyunin_eq_integral
-- for the diagonal case j = k.

end Cathedral.Vasyunin.StirlingBridge
