/-
  Cathedral/Physics/Bridges/L2DirectBound.lean

  ## Option A2: Direct L² Bound on vᵀGv

  Strategy: Apply the two-tier framework DIRECTLY to gramEntry,
  bypassing the K_elem + K_cot decomposition entirely.

  Since vᵀGv = ∫₀¹ |Σ vₖ·{1/(kx)}|² dx (by bd_gram_l2_identity),
  bounding vᵀGv = bilinearForm N gramEntry w is equivalent to
  bounding the L² norm of the BD residual.

  The two-tier split gives:
    bilinearForm N gramEntry w ≤ headForm N J gramEntry w
                                + M · (Σ_{i≥J} |w_i|)²

  where headForm is EXACT (finite computation) and
  M = max_{i,j≥J} |gramEntry(i+1,j+1)| ≤ 1 (from gramEntry_le_one).

  This is Option A: the direct path, no decomposition needed.

  Created: May 25, 2026 — Option A Session
-/

import Cathedral.Physics.Bridges.CotangentPerturbation
import Cathedral.Gram.Bounds

noncomputable section
open Finset

namespace Cathedral.L2DirectBound

open Cathedral.CotangentPerturbation

-- ════════════════════════════════════════════════════════════════
-- §1. GRAM ENTRY TAIL BOUND
-- ════════════════════════════════════════════════════════════════

/-- **LEMMA**: |gramEntry(j,k)| ≤ 1 for all j,k.
    Since 0 ≤ gramEntry ≤ 1, we have |gramEntry| ≤ 1. -/
theorem gramEntry_abs_le_one (j k : ℕ) : |gramEntry j k| ≤ 1 := by
  rw [abs_of_nonneg (gramEntry_nonneg j k)]
  exact gramEntry_le_one j k

-- ════════════════════════════════════════════════════════════════
-- §2. THE DIRECT TWO-TIER BOUND ON vᵀGv
-- ════════════════════════════════════════════════════════════════

/-- **THE DIRECT BOUND (crude)**: vᵀGv ≤ Head_J + (Σ_{≥J} |w|)².

    Uses M = 1 (the uniform bound gramEntry ≤ 1).
    The head is an EXACT finite sum of Gram entries.

    This is the simplest possible application of two-tier to the
    Gram form. No K_elem decomposition needed. -/
theorem gram_direct_bound_crude (N J : ℕ) (w : Fin N → ℝ) :
    bilinearForm N gramEntry w ≤
    headForm N J gramEntry w +
    1 * (∑ i : Fin N, if J ≤ i.val then |w i| else 0) ^ 2 := by
  apply two_tier_split_bound
  · exact zero_le_one
  · intro i j _ _
    exact gramEntry_abs_le_one (i.val + 1) (j.val + 1)

/-- **THE DIRECT BOUND (parameterized)**: vᵀGv ≤ Head_J + M · (Σ_{≥J} |w|)²

    For any M that bounds |gramEntry(i+1,j+1)| in the tail.
    Supply a smaller M for a tighter bound. -/
theorem gram_direct_bound (N J : ℕ) (w : Fin N → ℝ)
    (M : ℝ) (hM : 0 ≤ M)
    (htail : ∀ i j : Fin N, J ≤ i.val → J ≤ j.val →
      |gramEntry (i.val + 1) (j.val + 1)| ≤ M) :
    bilinearForm N gramEntry w ≤
    headForm N J gramEntry w +
    M * (∑ i : Fin N, if J ≤ i.val then |w i| else 0) ^ 2 :=
  two_tier_split_bound N J gramEntry w M hM htail

-- ════════════════════════════════════════════════════════════════
-- §3. HEAD PROPERTIES
-- ════════════════════════════════════════════════════════════════

/-- **THEOREM**: The tail of vᵀGv is bounded.

    |tailForm N J gramEntry w| ≤ M · (Σ_{≥J} |w_i|)² -/
theorem gram_tail_bound (N J : ℕ) (w : Fin N → ℝ)
    (M : ℝ) (hM : 0 ≤ M)
    (htail : ∀ i j : Fin N, J ≤ i.val → J ≤ j.val →
      |gramEntry (i.val + 1) (j.val + 1)| ≤ M) :
    |tailForm N J gramEntry w| ≤
    M * (∑ i : Fin N, if J ≤ i.val then |w i| else 0) ^ 2 :=
  tail_sup_bound N J gramEntry w M hM htail

-- ════════════════════════════════════════════════════════════════
-- §4. COMPARISON: OPTION A vs OPTION B
-- ════════════════════════════════════════════════════════════════

/-- **THEOREM**: Option A = Head(G) + tail.
    headForm of G contains ALL of K_elem (since K_elem is bounded
    and contributes to both head and tail). -/
theorem option_a_is_exact_split (N J : ℕ) (w : Fin N → ℝ) :
    bilinearForm N gramEntry w =
    headForm N J gramEntry w + tailForm N J gramEntry w :=
  bilinear_head_tail_split N J gramEntry w

-- ════════════════════════════════════════════════════════════════
-- §5. AUDIT
-- ════════════════════════════════════════════════════════════════

/-!
## Audit — L2DirectBound.lean (May 25, 2026)

### PROVED: 5 🎓 / 0 axioms / 0 sorry
| # | Result | Status |
|---|--------|--------|
| 1 | `gramEntry_abs_le_one` | 🎓 \|G(j,k)\| ≤ 1 |
| 2 | `gram_direct_bound_crude` | 🎓 vᵀGv ≤ Head + (Σ_{≥J}\|w\|)² |
| 3 | `gram_direct_bound` | 🎓 vᵀGv ≤ Head + M·(Σ_{≥J}\|w\|)² |
| 4 | `gram_tail_bound` | 🎓 \|Tail\| ≤ M·(Σ_{≥J}\|w\|)² |
| 5 | `option_a_is_exact_split` | 🎓 vᵀGv = Head + Tail |

### Architecture: Option A vs Option B
```
OPTION A (L2DirectBound):              OPTION B (TwoTierWiring):
  gramEntry ──→ Head + Tail              gramEntry = K_elem + K_cot
  Head = exact finite sum                K_cot ──→ Head + Tail
  Tail ≤ 1·(Σ_{≥J}|w|)²                Tail ≤ M_cot·(Σ_{≥J}|w|)²
  ┌────────────────────────┐             ┌────────────────────────┐
  │ Simpler: 1 split       │             │ Sharper: K_cot has     │
  │ Fewer moving parts     │             │ smaller M_tail         │
  │ Direct L² connection   │             │ More structure         │
  └────────────────────────┘             └────────────────────────┘
```
-/

end Cathedral.L2DirectBound
