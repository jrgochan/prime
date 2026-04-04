/-
  Cathedral/FractIntegral.lean

  ## Per-entry Fractional Part Integral Analysis

  This file contains the analysis of ∫₀¹ {k/x}dx, the inner product
  of the Nyman-Beurling basis function with the constant function 1.

  ### Architecture:
  fract_integral_eq_tsum (AXIOM — change of variables)
  summable_log_correction (AXIOM — O(1/n²) summability)
      ↓ [hasSum_telescoping_inv — THEOREM (telescoping series)]
      ↓ [fract_integral_as_one_plus — THEOREM]
      ↓ [fract_integral_identity — THEOREM (sign flip)]
  log_harmonic_tail_bound (THEOREM — was axiom, proved via per_term_log_bound)
      ↓ [basis_entry_lower — THEOREM: ∫₀¹{k/x}dx ≥ 1/2 - 1/(2k)]

  ### Proof sketch:
  Change of variables u = k/x gives ∫₀¹{k/x}dx = k·Σ_{n≥k}(log(1+1/n) - 1/(n+1)).
  On each interval [n,n+1), {u} = u-n, so ∫_n^{n+1} (u-n)/u² du = log(1+1/n) - 1/(n+1).
  Rewriting 1/(n+1) = 1/n - 1/(n(n+1)) and telescoping Σ 1/(n(n+1)) = 1/k:
  ∫₀¹{k/x}dx = 1 - k·Σ_{n≥k}(1/n - log(1+1/n)).
  Each correction term 1/n - log(1+1/n) ∈ (0, 1/(2n²)), so
  k·Σ ≤ (k+1)/(2k) = 1/2 + 1/(2k), giving ∫ ≥ 1/2 - 1/(2k).
-/

import Cathedral.Defs
import Mathlib.Analysis.SpecialFunctions.Log.Deriv

noncomputable section
open Real MeasureTheory

-- ════════════════════════════════════════════════
-- LAYER 0: IRREDUCIBLE AXIOMS
-- ════════════════════════════════════════════════

/-- **Axiom (Integral = tsum)**: The integral ∫₀¹ {k/x}dx equals
    k times a tsum of log-reciprocal terms.

    This is the irreducible analytic core: change of variables u = k/x
    gives ∫₀¹ {k/x}dx = k·∫_k^∞ {u}/u² du, then partitioning into
    intervals [n,n+1) where {u} = u-n and computing each piece:
    ∫_n^{n+1} (u-n)/u² du = log((n+1)/n) - 1/(n+1). -/
axiom fract_integral_eq_tsum (k : ℕ) (hk : 1 ≤ k) :
    ∫ x in (0:ℝ)..1, Int.fract ((k : ℝ) / x) =
    (k : ℝ) * ∑' (m : ℕ),
      (Real.log (1 + 1 / ((m + k : ℕ) : ℝ)) - 1 / (((m + k : ℕ) : ℝ) + 1))

/-- **Axiom (Summability)**: The log-harmonic correction is summable.
    Each term |log(1+1/n) - 1/n| ≤ 1/(2n²) from log(1+x) ≥ x-x²/2,
    and Σ 1/n² converges. -/
axiom summable_log_correction (k : ℕ) (hk : 1 ≤ k) :
    Summable (fun m : ℕ =>
      Real.log (1 + 1 / ((m + k : ℕ) : ℝ)) - 1 / ((m + k : ℕ) : ℝ))

-- ════════════════════════════════════════════════
-- LAYER 1: TELESCOPING SERIES
-- ════════════════════════════════════════════════

/-- **THEOREM**: Telescoping Σ_{m≥0} (1/(m+k) - 1/(m+k+1)) = 1/k.
    Proof: The partial sums telescope to 1/k - 1/(n+k) → 1/k. -/
lemma hasSum_telescoping_inv (k : ℕ) (hk : 1 ≤ k) :
    HasSum (fun m : ℕ => 1 / ((m + k : ℕ) : ℝ) - 1 / (((m + k : ℕ) : ℝ) + 1))
      (1 / (k : ℝ)) := by
  have hnn : ∀ m : ℕ, 0 ≤ 1 / ((m + k : ℕ) : ℝ) - 1 / (((m + k : ℕ) : ℝ) + 1) := by
    intro m
    have h1 : (0 : ℝ) < ((m + k : ℕ) : ℝ) := by positivity
    have h2 : (0 : ℝ) < ((m + k : ℕ) : ℝ) + 1 := by linarith
    rw [div_sub_div _ _ (ne_of_gt h1) (ne_of_gt h2)]
    exact div_nonneg (by linarith) (by positivity)
  rw [hasSum_iff_tendsto_nat_of_nonneg hnn]
  have hpartial : ∀ n : ℕ, ∑ i ∈ Finset.range n,
      (1 / ((i + k : ℕ) : ℝ) - 1 / (((i + k : ℕ) : ℝ) + 1)) =
      1 / (k : ℝ) - 1 / ((n + k : ℕ) : ℝ) := by
    intro n; induction n with
    | zero => simp
    | succ n ih =>
      rw [Finset.sum_range_succ, ih]
      have h1 : (0 : ℝ) < ((n + k : ℕ) : ℝ) := by positivity
      have h3 : (0 : ℝ) < ((n + 1 + k : ℕ) : ℝ) := by positivity
      have hkp : (0 : ℝ) < (k : ℝ) := by positivity
      have h1ne : ((n + k : ℕ) : ℝ) ≠ 0 := ne_of_gt h1
      have h3ne : ((n + 1 + k : ℕ) : ℝ) ≠ 0 := ne_of_gt h3
      have hkne : (k : ℝ) ≠ 0 := ne_of_gt hkp
      have h1p1 : ((n + k : ℕ) : ℝ) + 1 = ((n + 1 + k : ℕ) : ℝ) := by push_cast; ring
      rw [h1p1]; field_simp; push_cast; ring
  simp_rw [hpartial]
  suffices htend : Filter.Tendsto (fun n : ℕ => (1 : ℝ) / ((n + k : ℕ) : ℝ))
      Filter.atTop (nhds 0) by
    have := htend.const_sub (1 / (k : ℝ))
    simp only [sub_zero] at this; exact this
  have hcast : ∀ n : ℕ, (1 : ℝ) / ((n + k : ℕ) : ℝ) = ((n + k : ℕ) : ℝ)⁻¹ := by
    intro n; rw [one_div]
  simp_rw [hcast]
  apply Filter.Tendsto.comp tendsto_inv_atTop_zero
  apply Filter.tendsto_atTop_atTop_of_monotone
  · intro a b h; show ((a + k : ℕ) : ℝ) ≤ ((b + k : ℕ) : ℝ); exact_mod_cast Nat.add_le_add_right h k
  · intro b
    obtain ⟨n, hn⟩ := exists_nat_ge b
    exact ⟨n, le_trans hn (by exact_mod_cast Nat.le_add_right n k)⟩

private lemma tsum_telescoping_inv (k : ℕ) (hk : 1 ≤ k) :
    ∑' (m : ℕ), (1 / ((m + k : ℕ) : ℝ) - 1 / (((m + k : ℕ) : ℝ) + 1))
    = 1 / (k : ℝ) :=
  (hasSum_telescoping_inv k hk).tsum_eq

-- ════════════════════════════════════════════════
-- LAYER 2: TAIL BOUND (was axiom)
-- ════════════════════════════════════════════════

/-- Per-term bound: 1/n - log(1+1/n) ≤ 1/(2n²) for n ≥ 1.
    Uses Mathlib's le_log_one_add_of_nonneg: 2x/(x+2) ≤ log(1+x). -/
private lemma per_term_log_bound (n : ℕ) (hn : 1 ≤ n) :
    1 / ((n : ℕ) : ℝ) - Real.log (1 + 1 / ((n : ℕ) : ℝ))
    ≤ 1 / (2 * ((n : ℕ) : ℝ) ^ 2) := by
  have hn_pos : (0 : ℝ) < (n : ℝ) := Nat.cast_pos.mpr (by omega)
  have hlog := le_log_one_add_of_nonneg (show (0 : ℝ) ≤ 1 / (n : ℝ) from by positivity)
  -- Simplify the Mathlib bound: 2*(1/n)/(1/n + 2) = 2/(2n+1)
  have key : 2 * (1 / (↑n : ℝ)) / (1 / ↑n + 2) = 2 / (2 * ↑n + 1) := by
    have : (↑n : ℝ) ≠ 0 := ne_of_gt hn_pos
    field_simp; ring
  rw [key] at hlog
  -- Now hlog : 2/(2n+1) ≤ log(1+1/n)
  -- Need: 1/n - log(1+1/n) ≤ 1/(2n²)
  -- Suffices: 1/n - 2/(2n+1) ≤ 1/(2n²), i.e., 1/(n(2n+1)) ≤ 1/(2n²)
  suffices h : 1 / (↑n : ℝ) - 2 / (2 * ↑n + 1) ≤ 1 / (2 * (↑n) ^ 2) by linarith
  have h1 : (↑n : ℝ) ≠ 0 := ne_of_gt hn_pos
  have h2 : (0 : ℝ) < 2 * ↑n + 1 := by linarith
  rw [div_sub_div _ _ h1 (ne_of_gt h2)]
  rw [div_le_div_iff₀ (mul_pos hn_pos h2) (by positivity : (0 : ℝ) < 2 * ↑n ^ 2)]
  nlinarith [sq_nonneg (↑n : ℝ)]

/-- 1/n² ≤ 2*(1/n - 1/(n+1)) for n ≥ 1 (comparison with double-telescoping). -/
private lemma inv_sq_le_double_tele (n : ℕ) (hn : 1 ≤ n) :
    1 / ((n : ℕ) : ℝ) ^ 2 ≤ 2 * (1 / ((n : ℕ) : ℝ) - 1 / (((n : ℕ) : ℝ) + 1)) := by
  have hn_pos : (0 : ℝ) < (n : ℝ) := Nat.cast_pos.mpr (by omega)
  -- Pre-simplify: 2*(1/n - 1/(n+1)) = 2/(n(n+1))
  have hrhs : 2 * (1 / (↑n : ℝ) - 1 / (↑n + 1)) = 2 / (↑n * (↑n + 1)) := by
    have : (↑n : ℝ) ≠ 0 := ne_of_gt hn_pos
    field_simp; ring
  rw [hrhs]
  -- Goal: 1/n² ≤ 2/(n(n+1)) ⟺ n(n+1) ≤ 2n² ⟺ n+1 ≤ 2n ⟺ 1 ≤ n ✓
  rw [div_le_div_iff₀ (by positivity : (0 : ℝ) < (↑n) ^ 2)
    (by positivity : (0 : ℝ) < ↑n * (↑n + 1))]
  nlinarith [show (1 : ℝ) ≤ ↑n from Nat.one_le_cast.mpr hn, sq_nonneg (↑n : ℝ)]

/-- Summability of 1/(m+k)²: dominated by 2× telescoping series. -/
private lemma summable_inv_sq_shift (k : ℕ) (hk : 1 ≤ k) :
    Summable (fun m : ℕ => 1 / (((m + k : ℕ) : ℝ) ^ 2)) :=
  Summable.of_nonneg_of_le (fun m => by positivity)
    (fun m => inv_sq_le_double_tele (m + k) (by omega))
    ((hasSum_telescoping_inv k hk).summable.mul_left 2)

/-- For n ≥ 2: 1/n² ≤ 1/(n-1) - 1/n = 1/((n-1)n) (tighter comparison). -/
private lemma inv_sq_le_shifted_tele (m : ℕ) (k : ℕ) (hk : 1 ≤ k) :
    1 / (((m + 1 + k : ℕ) : ℝ) ^ 2) ≤
    1 / ((m + k : ℕ) : ℝ) - 1 / ((m + 1 + k : ℕ) : ℝ) := by
  -- n = m+1+k ≥ 2, n-1 = m+k ≥ 1
  -- Need: 1/n² ≤ 1/(n-1) - 1/n = 1/((n-1)n)
  -- ⟺ (n-1)n ≤ n² ⟺ n-1 ≤ n ✓
  have hmk : (0 : ℝ) < ((m + k : ℕ) : ℝ) := by positivity
  have hmk1 : (0 : ℝ) < ((m + 1 + k : ℕ) : ℝ) := by positivity
  rw [div_sub_div _ _ (ne_of_gt hmk) (ne_of_gt hmk1)]
  rw [div_le_div_iff₀ (by positivity : (0 : ℝ) < ((m + 1 + k : ℕ) : ℝ) ^ 2)
    (by positivity : (0 : ℝ) < ((m + k : ℕ) : ℝ) * ((m + 1 + k : ℕ) : ℝ))]
  have : ((m + k : ℕ) : ℝ) = ((m + 1 + k : ℕ) : ℝ) - 1 := by push_cast; ring
  nlinarith [sq_nonneg ((m + 1 + k : ℕ) : ℝ)]

/-- Bound: Σ_{m≥0} 1/(m+k)² ≤ (k+1)/k².
    Split as f(0) + tail, then compare tail against shifted telescoping. -/
private lemma tsum_inv_sq_bound (k : ℕ) (hk : 1 ≤ k) :
    ∑' (m : ℕ), (1 / (((m + k : ℕ) : ℝ) ^ 2))
    ≤ ((k : ℝ) + 1) / ((k : ℝ) ^ 2) := by
  have hk_pos : (0 : ℝ) < (k : ℝ) := by positivity
  have hsumm := summable_inv_sq_shift k hk
  -- Split: Σ_{m≥0} = f(0) + Σ_{m≥0} f(m+1)
  rw [hsumm.tsum_eq_zero_add]
  simp only [Nat.zero_add]
  -- f(0) = 1/k²; need: 1/k² + Σ_{m≥0} 1/(m+1+k)² ≤ (k+1)/k²
  -- Σ_{m≥0} 1/(m+1+k)² ≤ Σ_{m≥0} (1/(m+k) - 1/(m+1+k)) = 1/k (telescoping)
  have htail_summ : Summable (fun m => 1 / (((m + 1 + k : ℕ) : ℝ) ^ 2)) :=
    hsumm.comp_injective (fun a b h => by omega)
  have htail : ∑' m, (1 / (((m + 1 + k : ℕ) : ℝ) ^ 2)) ≤ 1 / (k : ℝ) := by
    calc ∑' m, (1 / (((m + 1 + k : ℕ) : ℝ) ^ 2))
        ≤ ∑' m, (1 / ((m + k : ℕ) : ℝ) - 1 / ((m + 1 + k : ℕ) : ℝ)) :=
          htail_summ.tsum_le_tsum
            (fun m => inv_sq_le_shifted_tele m k hk)
            ((hasSum_telescoping_inv k hk).summable.congr (fun m => by
              push_cast; congr 1; ring))
      _ = 1 / (k : ℝ) := by
          have : (fun m : ℕ => 1 / ((m + k : ℕ) : ℝ) - 1 / ((m + 1 + k : ℕ) : ℝ)) =
            (fun m : ℕ => 1 / ((m + k : ℕ) : ℝ) - 1 / (((m + k : ℕ) : ℝ) + 1)) := by
            ext m; congr 1; push_cast; ring
          rw [this, (hasSum_telescoping_inv k hk).tsum_eq]
  -- 1/k² + 1/k = (k+1)/k²
  have : 1 / (k : ℝ) ^ 2 + 1 / (k : ℝ) = ((k : ℝ) + 1) / ((k : ℝ) ^ 2) := by
    field_simp; ring
  linarith

/-- **THEOREM** (was axiom): k·Σ_{n≥k}(1/n - log(1+1/n)) ≤ 1/2 + 1/(2k). -/
theorem log_harmonic_tail_bound (k : ℕ) (hk : 1 ≤ k) :
    (k : ℝ) * ∑' (m : ℕ),
      (1 / ((m + k : ℕ) : ℝ) - Real.log (1 + 1 / ((m + k : ℕ) : ℝ)))
    ≤ 1 / 2 + 1 / (2 * (k : ℝ)) := by
  have hk_pos : (0 : ℝ) < (k : ℝ) := by positivity
  -- Summability (negate summable_log_correction)
  have hsumm : Summable (fun m : ℕ =>
      1 / ((m + k : ℕ) : ℝ) - Real.log (1 + 1 / ((m + k : ℕ) : ℝ))) := by
    have := (summable_log_correction k hk).neg; simp only [neg_sub] at this; exact this
  -- Step 1: tsum comparison via per-term bound
  have hcomp : ∑' m, (1 / ((m + k : ℕ) : ℝ) - Real.log (1 + 1 / ((m + k : ℕ) : ℝ)))
      ≤ (1 / 2) * ∑' m, (1 / ((m + k : ℕ) : ℝ) ^ 2) := by
    calc ∑' m, (1 / ((m + k : ℕ) : ℝ) - Real.log (1 + 1 / ((m + k : ℕ) : ℝ)))
        ≤ ∑' m, (1 / (2 * ((m + k : ℕ) : ℝ) ^ 2)) :=
          hsumm.tsum_le_tsum (fun m => per_term_log_bound (m + k) (by omega))
            ((summable_inv_sq_shift k hk).mul_left (1/2) |>.congr (fun m => by
              show 1 / 2 * (1 / ((m + k : ℕ) : ℝ) ^ 2) = 1 / (2 * ((m + k : ℕ) : ℝ) ^ 2)
              ring))
      _ = (1 / 2) * ∑' m, (1 / ((m + k : ℕ) : ℝ) ^ 2) := by
          rw [← tsum_mul_left]; congr 1; ext m; ring
  -- Step 2: Apply tsum_inv_sq_bound and assemble
  calc (k : ℝ) * ∑' m, (1 / ((m + k : ℕ) : ℝ) - Real.log (1 + 1 / ((m + k : ℕ) : ℝ)))
      ≤ (k : ℝ) * ((1 / 2) * ∑' m, (1 / ((m + k : ℕ) : ℝ) ^ 2)) :=
        mul_le_mul_of_nonneg_left hcomp (le_of_lt hk_pos)
    _ ≤ (k : ℝ) * ((1 / 2) * (((k : ℝ) + 1) / ((k : ℝ) ^ 2))) :=
        mul_le_mul_of_nonneg_left
          (mul_le_mul_of_nonneg_left (tsum_inv_sq_bound k hk) (by norm_num))
          (le_of_lt hk_pos)
    _ = 1 / 2 + 1 / (2 * (k : ℝ)) := by field_simp

-- ════════════════════════════════════════════════
-- LAYER 3: INTEGRAL IDENTITIES
-- ════════════════════════════════════════════════

/-- **THEOREM**: ∫₀¹ {k/x}dx = 1 + k·Σ(log(1+1/n) - 1/n).
    From fract_integral_eq_tsum by splitting each term:
    log - 1/(n+1) = (log - 1/n) + (1/n - 1/(n+1))
    and using Σ(1/n - 1/(n+1)) = 1/k (telescoping). -/
theorem fract_integral_as_one_plus (k : ℕ) (hk : 1 ≤ k) :
    ∫ x in (0:ℝ)..1, Int.fract ((k : ℝ) / x) =
    1 + (k : ℝ) * ∑' (m : ℕ),
      (Real.log (1 + 1 / ((m + k : ℕ) : ℝ)) - 1 / ((m + k : ℕ) : ℝ)) := by
  have h := fract_integral_eq_tsum k hk
  rw [h]
  have htel := tsum_telescoping_inv k hk
  have hk_pos : (0 : ℝ) < (k : ℝ) := Nat.cast_pos.mpr (by omega)
  have hsumm_log := summable_log_correction k hk
  have hsumm_tel := (hasSum_telescoping_inv k hk).summable
  have hgoal : ∑' (m : ℕ),
      (Real.log (1 + 1 / ((m + k : ℕ) : ℝ)) - 1 / (((m + k : ℕ) : ℝ) + 1)) =
      ∑' (m : ℕ), (Real.log (1 + 1 / ((m + k : ℕ) : ℝ)) - 1 / ((m + k : ℕ) : ℝ)) +
        1 / (k : ℝ) := by
    rw [← htel, ← Summable.tsum_add hsumm_log hsumm_tel]; congr 1; ext m; ring
  rw [hgoal, mul_add, mul_one_div_cancel (ne_of_gt hk_pos)]
  ring

/-- **THEOREM**: ∫₀¹ {k/x}dx = 1 - k · Σ(1/n - log(1+1/n)).
    Sign flip via tsum_neg. -/
theorem fract_integral_identity (k : ℕ) (hk : 1 ≤ k) :
    ∫ x in (0:ℝ)..1, Int.fract ((k : ℝ) / x) =
    1 - (k : ℝ) * ∑' (m : ℕ),
      (1 / ((m + k : ℕ) : ℝ) - Real.log (1 + 1 / ((m + k : ℕ) : ℝ))) := by
  have h := fract_integral_as_one_plus k hk
  rw [h]
  have key : ∑' (m : ℕ), (1 / ((m + k : ℕ) : ℝ) -
      Real.log (1 + 1 / ((m + k : ℕ) : ℝ))) =
    - ∑' (m : ℕ), (Real.log (1 + 1 / ((m + k : ℕ) : ℝ)) -
      1 / ((m + k : ℕ) : ℝ)) := by
    rw [← tsum_neg]; congr 1; ext m; ring
  rw [key]; ring

-- ════════════════════════════════════════════════
-- LAYER 4: THE PER-ENTRY BOUND
-- ════════════════════════════════════════════════

/-- **THEOREM**: ∫₀¹ {k/x}dx ≥ 1/2 - 1/(2k).
    From fract_integral_identity + log_harmonic_tail_bound:
    ∫ = 1 - k·tail ≥ 1 - (1/2 + 1/(2k)) = 1/2 - 1/(2k). -/
theorem basis_entry_lower (k : ℕ) (hk : 1 ≤ k) :
    ∫ x in (0:ℝ)..1, Int.fract ((k : ℝ) / x) ≥ (1:ℝ)/2 - 1 / (2 * (k : ℝ)) := by
  have h1 := fract_integral_identity k hk
  have h2 := log_harmonic_tail_bound k hk
  linarith

end
