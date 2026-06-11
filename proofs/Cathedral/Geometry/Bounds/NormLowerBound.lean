/-
  Cathedral/Geometry/Bounds/NormLowerBound.lean

  ## The Norm Lower Bound: ||v||² ≥ c₀ · N / ln²N

  ════════════════════════════════════════════════════════════════

  GRADUATED VERSION (June 11, 2026)

  All 4 sub-axioms have been promoted to theorems:
  - sqfreeCount_ge_third        ← SquarefreeCountBound.lean
  - sqfreeCount_ge_third_real   ← SquarefreeCountBound.lean
  - unfilteredTaperSum_lower    ← UnfilteredTaperSumBound.lean
  - witnessNormSq_ge_third_unfiltered ← AbelFilterBound.lean

  The definitions (sqfreeCount, taperSq, unfilteredTaperSum) live
  in NormLowerBoundDefs.lean to avoid circular imports.

  STATUS: 0 axioms. 0 sorry. Fully graduated. 🎓
  Original: June 5, 2026 — The Final Five: Axiom 1
  Graduated: June 11, 2026 — The Brave Berry Maneuver
-/

import Cathedral.Geometry.Bounds.NormLowerBoundDefs
import Cathedral.Geometry.Bounds.SquarefreeCountBound
import Cathedral.Geometry.Bounds.UnfilteredTaperSumBound
import Cathedral.Geometry.Abel.AbelFilterBound

set_option maxHeartbeats 800000

noncomputable section
open Real Finset

namespace Cathedral.Geometry.Bounds.NormLowerBound

open Cathedral.Vasyunin
open Cathedral.Geometry.Bernoulli.BernoulliDiagonal
open Cathedral.Geometry.Bounds.SquarefreeCountBound
open Cathedral.Geometry.Bounds.UnfilteredTaperSumBound
open Cathedral.Geometry.Abel.AbelFilterBound

-- ════════════════════════════════════════════════════════════════
-- §1. GRADUATED SUB-AXIOMS → THEOREMS
-- ════════════════════════════════════════════════════════════════

/-! ### Squarefree density bounds (graduated from axiom)

  These were axioms in the original file. The proofs are in
  SquarefreeCountBound.lean, proved via partition + sieve. -/

/-- **GRADUATED**: Q(N) ≥ N/3 for N ≥ 1.
    Was: axiom. Now: theorem delegating to SquarefreeCountBound. -/
theorem sqfreeCount_ge_third :
    ∀ N : ℕ, 1 ≤ N → N / 3 ≤ sqfreeCount N :=
  sqfreeCount_ge_third_proved

/-- **GRADUATED**: ↑N / 3 ≤ ↑(Q(N)) in ℝ.
    Was: axiom. Now: theorem delegating to SquarefreeCountBound. -/
theorem sqfreeCount_ge_third_real :
    ∀ N : ℕ, 1 ≤ N → (↑N : ℝ) / 3 ≤ ↑(sqfreeCount N) :=
  sqfreeCount_ge_third_real_proved

-- ════════════════════════════════════════════════════════════════
-- §2. WITNESS NORM AS SQUAREFREE SUM
-- ════════════════════════════════════════════════════════════════

/-- **NORM EXPANSION**: ||v||² = Σ_{i:Fin N} μ(i+1)² · taper²(i+1,N). -/
theorem witnessNormSq_eq_sqfree_sum (N : ℕ) (_hN : 3 ≤ N) :
    witnessNormSq N =
    ∑ i : Fin N, (↑(ArithmeticFunction.moebius (i.val + 1) : ℤ) : ℝ) ^ 2 *
      taperSq (i.val + 1) N := by
  unfold witnessNormSq taperSq logCutoffWitness moebiusFn
  congr 1; ext i
  ring

-- ════════════════════════════════════════════════════════════════
-- §3. GRADUATED INTEGRAL + ABEL BOUNDS
-- ════════════════════════════════════════════════════════════════

/-! ### Integral and Abel bounds (graduated from axiom)

  These were axioms in the original file. The proofs are in
  UnfilteredTaperSumBound.lean and AbelFilterBound.lean. -/

/-- **GRADUATED**: The unfiltered taper sum grows as N/ln²N.
    Was: axiom. Now: theorem delegating to UnfilteredTaperSumBound. -/
theorem unfilteredTaperSum_lower :
    ∃ N₀ : ℕ, ∀ N : ℕ, N ≥ N₀ → N ≥ 3 →
      ↑N / (Real.log ↑N) ^ 2 ≤ unfilteredTaperSum N :=
  unfilteredTaperSum_lower_proved

/-- **GRADUATED**: ||v||² ≥ (1/3) · unfilteredTaperSum.
    Was: axiom. Now: theorem delegating to AbelFilterBound. -/
theorem witnessNormSq_ge_third_unfiltered :
    ∀ N : ℕ, 3 ≤ N →
      unfilteredTaperSum N / 3 ≤ witnessNormSq N :=
  witnessNormSq_ge_third_unfiltered_proved

-- ════════════════════════════════════════════════════════════════
-- §4. THE GRADUATION: norm_lower_bound
-- ════════════════════════════════════════════════════════════════

/-- **GRADUATED THEOREM**: The norm lower bound.

    ||v||² ≥ c₀ · N/ln²N with c₀ = 1/3.

    Chain: unfilteredTaperSum ≥ N/ln²N  →  ||v||² ≥ unfiltered/3  →  ||v||² ≥ N/(3ln²N)

    ALL LINKS NOW PROVED. Zero axioms in the chain. -/
theorem norm_lower_bound_graduated :
    ∃ c₀ : ℝ, c₀ > 0 ∧ ∃ N₀ : ℕ, ∀ N : ℕ, N ≥ N₀ →
      c₀ * ↑N / (Real.log ↑N) ^ 2 ≤ witnessNormSq N := by
  -- Use c₀ = 1/3
  use 1/3
  constructor
  · norm_num
  -- Get N₀ from the unfiltered lower bound
  obtain ⟨N₀, hUF⟩ := unfilteredTaperSum_lower
  use max N₀ 3
  intro N hN
  have hN3 : N ≥ 3 := by omega
  have hN0 : N ≥ N₀ := by omega
  -- Step 1: unfilteredTaperSum N ≥ N/ln²N
  have h1 := hUF N hN0 hN3
  -- Step 2: ||v||² ≥ unfilteredTaperSum/3
  have h2 := witnessNormSq_ge_third_unfiltered N hN3
  -- Step 3: Chain
  have hlog_pos : 0 < Real.log ↑N :=
    Real.log_pos (by exact_mod_cast show 1 < N by omega)
  have hlog2_pos : 0 < (Real.log ↑N) ^ 2 := sq_pos_of_pos hlog_pos
  have hN_pos : (0 : ℝ) < ↑N := Nat.cast_pos.mpr (by omega)
  -- (1/3) · N/ln²N ≤ unfiltered/3 ≤ ||v||²
  calc (1 : ℝ) / 3 * ↑N / (Real.log ↑N) ^ 2
      = (↑N / (Real.log ↑N) ^ 2) / 3 := by ring
    _ ≤ unfilteredTaperSum N / 3 := by
        exact div_le_div_of_nonneg_right h1 (by norm_num : (0:ℝ) < 3).le
    _ ≤ witnessNormSq N := h2

-- ════════════════════════════════════════════════════════════════
-- §5. AUDIT
-- ════════════════════════════════════════════════════════════════

/-!
## Audit (June 11, 2026 — Sub-Axiom Graduation: COMPLETE 🎓)

### Sorry: 0 ✅
### Custom Axioms: 0 ✅ (was 4 — all graduated!)

### Graduated Axioms:
| # | Former Axiom | Now Proved In | Method |
|---|-------------|---------------|--------|
| 1 | `sqfreeCount_ge_third` | SquarefreeCountBound.lean | Partition + sieve |
| 2 | `sqfreeCount_ge_third_real` | SquarefreeCountBound.lean | Cast from ℕ proof |
| 3 | `unfilteredTaperSum_lower` | UnfilteredTaperSumBound.lean | Integral comparison |
| 4 | `witnessNormSq_ge_third_unfiltered` | AbelFilterBound.lean | Abel summation |

### Theorems PROVED (zero sorry):
| # | Result | Status | Content |
|---|--------|--------|---------|
| 1 | `sqfreeCount_ge_third` | ✅ 🎓 | Q(N) ≥ N/3 |
| 2 | `sqfreeCount_ge_third_real` | ✅ 🎓 | ↑Q(N) ≥ ↑N/3 in ℝ |
| 3 | `unfilteredTaperSum_lower` | ✅ 🎓 | Σf ≥ N/ln²N |
| 4 | `witnessNormSq_ge_third_unfiltered` | ✅ 🎓 | ||v||² ≥ Σf/3 |
| 5 | `witnessNormSq_eq_sqfree_sum` | ✅ | ||v||² = Σ μ²·taper² |
| 6 | `norm_lower_bound_graduated` | ✅ | ||v||² ≥ N/(3ln²N) |

### Architecture: The Brave Berry Maneuver
  NormLowerBoundDefs.lean (definitions: sqfreeCount, taperSq, unfilteredTaperSum)
      ↓                    ↓                    ↓
  SquarefreeCountBound  UnfilteredTaperSum   AbelFilterBound
  (proves Q≥N/3)        (proves Σf≥N/ln²N)  (proves ||v||²≥Σf/3)
      ↓                    ↓                    ↓
  NormLowerBound.lean ← imports all three, re-exports as theorems
-/

end Cathedral.Geometry.Bounds.NormLowerBound

end
