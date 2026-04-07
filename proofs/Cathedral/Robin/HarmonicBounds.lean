/-
  Cathedral/Robin/HarmonicBounds.lean

  ## Harmonic Number Infrastructure

  The logarithmic sandwich that drives the Lagarias inequality:
    log(n+1) ≤ H_n ≤ 1 + log(n)

  All theorems use Mathlib's Harmonic.Bounds API.
  The Bounds theorems are natively real-valued (using implicit ℚ → ℝ cast).
-/

import Cathedral.Robin.Defs
import Mathlib.NumberTheory.Harmonic.Bounds
import Mathlib.NumberTheory.Harmonic.Int

open Real

-- ════════════════════════════════════════════════
-- PART I: POSITIVITY
-- ════════════════════════════════════════════════

/-- **THEOREM (PROVED)**: H_n > 0 for n ≥ 1. -/
theorem harmonicR_pos {n : ℕ} (hn : 1 ≤ n) : 0 < harmonicR n := by
  unfold harmonicR
  exact_mod_cast harmonic_pos (by omega : n ≠ 0)

-- ════════════════════════════════════════════════
-- PART II: THE LOGARITHMIC SANDWICH
-- ════════════════════════════════════════════════

/-- **THEOREM (PROVED)**: log(n+1) ≤ H_n.
    Lower bound from integral comparison (Mathlib).

    Mathlib's `log_add_one_le_harmonic` has type:
    `Real.log ↑(n + 1) ≤ (harmonic n : ℝ)` -/
theorem harmonicR_lower (n : ℕ) : log ↑(n + 1) ≤ harmonicR n := by
  unfold harmonicR
  exact log_add_one_le_harmonic n

/-- **THEOREM (PROVED)**: H_n ≤ 1 + log(n).
    Upper bound from integral comparison (Mathlib).

    Mathlib's `harmonic_le_one_add_log` has type:
    `(harmonic n : ℝ) ≤ 1 + Real.log ↑n` -/
theorem harmonicR_upper (n : ℕ) : harmonicR n ≤ 1 + log ↑n := by
  unfold harmonicR
  exact harmonic_le_one_add_log n

-- ════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════

-- This file has:
--   ZERO sorry
--   ZERO axioms
--   3 PROVED theorems:
--     ✅ harmonicR_pos     — H_n > 0
--     ✅ harmonicR_lower   — log(n+1) ≤ H_n
--     ✅ harmonicR_upper   — H_n ≤ 1 + log(n)
