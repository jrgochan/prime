import Cathedral.MellinBridge.Separation
import Cathedral.MellinBridge.MellinSieve

/-! # Cathedral.MellinBridge.NymanBeurling

## The Nyman-Beurling criterion

Combines the forward and converse directions into the full
Nyman-Beurling criterion, plus immediate provable consequences.

### Key results
- `nyman_beurling_forward`: RH ⟹ d²→0 (axiom)
- `nyman_beurling_from_mellin`: full Nyman-Beurling criterion
- `mellin_cpow_restricted`: Mellin of x^a on (0,1)
- `zeta_ne_zero_of_re_gt_one`: ζ(s) ≠ 0 for Re(s) > 1
-/

noncomputable section
open Complex Real MeasureTheory Set Filter

-- ════════════════════════════════════════════════
-- SECTION 4: THE FORWARD DIRECTION (Phase 3)
-- ════════════════════════════════════════════════

-- **FORMERLY axiom nyman_beurling_forward**:
-- Excised 2026-04-07. Now proved as `nyman_beurling_forward_from_sieve`
-- in Cathedral.MellinBridge.MellinSieve via the weight construction chain.

-- ════════════════════════════════════════════════
-- SECTION 5: COMBINING INTO NYMAN-BEURLING
-- ════════════════════════════════════════════════

/-- **THEOREM**: The Nyman-Beurling criterion (from forward + converse).
    d²_N → 0 ↔ RH.

    This is the decomposition of the `nyman_beurling` axiom from Assembly.lean
    into its two halves. Once both `nyman_beurling_forward` and
    `nyman_beurling_converse` are proved, this replaces the axiom. -/
theorem nyman_beurling_from_mellin :
    (∀ ε > 0, ∃ N₀ : ℕ, ∀ N ≥ N₀, ∃ v : Fin (N - 1) → ℝ,
      ∫ x in (0:ℝ)..1, (1 - nbLinComb N v x) ^ 2 < ε) ↔
    RiemannHypothesis :=
  ⟨nyman_beurling_converse, nyman_beurling_forward_from_sieve⟩

-- ════════════════════════════════════════════════
-- SECTION 6: IMMEDIATE PROVABLE RESULTS
-- ════════════════════════════════════════════════

/-- The Mellin transform of x^a on (0,1) is 1/(s+a) for Re(s+a) > 0.
    This is a direct consequence of Mathlib's hasMellin_cpow_Ioc. -/
theorem mellin_cpow_restricted (a : ℂ) (s : ℂ) (hs : 0 < (s + a).re) :
    mellinRestricted (fun x => (x : ℂ) ^ a) s = 1 / (s + a) := by
  unfold mellinRestricted
  -- t^{s-1} * t^a = t^{s+a-1} on Ioc 0 1
  have h_simp : Set.EqOn
      (fun t : ℝ => (↑t : ℂ) ^ (s - 1) * (↑t : ℂ) ^ a)
      (fun t : ℝ => (↑t : ℂ) ^ (s + a - 1))
      (Set.Ioc (0:ℝ) 1) := by
    intro t ⟨h0, _⟩
    simp only
    rw [← cpow_add _ _ (ofReal_ne_zero.mpr (ne_of_gt h0))]
    congr 1; ring
  rw [setIntegral_congr_fun measurableSet_Ioc h_simp]
  rw [← intervalIntegral.integral_of_le (by norm_num : (0:ℝ) ≤ 1)]
  have hre : -1 < (s + a - 1).re := by
    have := hs; rw [add_re] at this; simp [sub_re, one_re]; linarith
  have hsa : s + a ≠ 0 := by
    intro h; rw [h, zero_re] at hs; exact lt_irrefl _ hs
  rw [integral_cpow (Or.inl hre)]
  simp only [sub_add_cancel, ofReal_one, one_cpow, ofReal_zero, zero_cpow hsa, sub_zero]

/-- The zeta function has no zeros at s=1 (pole) or at trivial zeros.
    This is already in Mathlib. -/
theorem zeta_ne_zero_of_re_gt_one (s : ℂ) (hs : 1 < s.re) :
    riemannZeta s ≠ 0 :=
  riemannZeta_ne_zero_of_one_lt_re hs
end
