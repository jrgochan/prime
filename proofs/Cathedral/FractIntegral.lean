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
  log_harmonic_tail_bound (AXIOM — tail bound)
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

/-- **Axiom (Tail Bound)**: k·Σ_{n≥k}(1/n - log(1+1/n)) ≤ 1/2 + 1/(2k).
    Each term ≤ 1/(2n²) and Σ_{n≥k} 1/(2n²) ≤ (k+1)/(2k²),
    so k·Σ ≤ (k+1)/(2k) = 1/2 + 1/(2k). -/
axiom log_harmonic_tail_bound (k : ℕ) (hk : 1 ≤ k) :
    (k : ℝ) * ∑' (m : ℕ),
      (1 / ((m + k : ℕ) : ℝ) - Real.log (1 + 1 / ((m + k : ℕ) : ℝ)))
    ≤ 1 / 2 + 1 / (2 * (k : ℝ))

-- ════════════════════════════════════════════════
-- LAYER 1: TELESCOPING SERIES
-- ════════════════════════════════════════════════

/-- **THEOREM**: Telescoping Σ_{m≥0} (1/(m+k) - 1/(m+k+1)) = 1/k.
    Proof: The partial sums telescope to 1/k - 1/(n+k) → 1/k. -/
private lemma hasSum_telescoping_inv (k : ℕ) (hk : 1 ≤ k) :
    HasSum (fun m : ℕ => 1 / ((m + k : ℕ) : ℝ) - 1 / (((m + k : ℕ) : ℝ) + 1))
      (1 / (k : ℝ)) := by
  have hnn : ∀ m : ℕ, 0 ≤ 1 / ((m + k : ℕ) : ℝ) - 1 / (((m + k : ℕ) : ℝ) + 1) := by
    intro m
    have h1 : (0 : ℝ) < ((m + k : ℕ) : ℝ) := by positivity
    have h2 : (0 : ℝ) < ((m + k : ℕ) : ℝ) + 1 := by linarith
    rw [div_sub_div _ _ (ne_of_gt h1) (ne_of_gt h2)]
    exact div_nonneg (by linarith) (by positivity)
  rw [hasSum_iff_tendsto_nat_of_nonneg hnn]
  -- Partial sums telescope
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
  -- 1/k - 1/(n+k) → 1/k since 1/(n+k) → 0
  suffices htend : Filter.Tendsto (fun n : ℕ => (1 : ℝ) / ((n + k : ℕ) : ℝ))
      Filter.atTop (nhds 0) by
    have := htend.const_sub (1 / (k : ℝ))
    simp only [sub_zero] at this; exact this
  -- Show (n+k : ℕ) : ℝ → +∞, compose with 1/x → 0
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
-- LAYER 2: INTEGRAL IDENTITIES
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
  -- Split: log - 1/(n+1) = (log - 1/n) + (1/n - 1/(n+1))
  have hsumm_log := summable_log_correction k hk
  have hsumm_tel := (hasSum_telescoping_inv k hk).summable
  -- Rewrite: Σ(log - 1/(n+1)) = Σ((log - 1/n) + (1/n - 1/(n+1)))
  --        = Σ(log - 1/n) + Σ(1/n - 1/(n+1))  [tsum_add]
  --        = Σ(log - 1/n) + 1/k              [telescoping]
  -- k * Σ(log - 1/(n+1)) = k * (Σ(log - 1/n) + 1/k) = 1 + k * Σ(log - 1/n)
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
-- LAYER 3: THE PER-ENTRY BOUND
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
