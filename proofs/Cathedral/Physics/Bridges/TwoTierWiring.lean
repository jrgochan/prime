/-
  Cathedral/Physics/Bridges/TwoTierWiring.lean

  ## Wiring: Two-Tier Framework → Master Gram Bound

  Connects the two-tier splitting from CotangentPerturbation.lean
  with the Gram form split to produce the MASTER BOUND:

    vᵀGv ≤ vᵀK_elem·v + Head_J(v, K_cot) + M_tail · (Σ_{≥J} |v|)²

  The head is an exact finite computation (no approximation needed).
  Only the tail requires a uniform bound M_tail on |K_cot|.

  This M_tail can be supplied by:
  - vasyuninSum_abs_le (from VasyuninBound.lean) for analytic bounds
  - native_decide for finite verification at specific N,J

  Created: May 25, 2026 — Two-Tier Wiring
-/

import Cathedral.Physics.Bridges.CotangentPerturbation
import Cathedral.Vasyunin.Cotangent.VasyuninBound

noncomputable section
open Finset

namespace Cathedral.TwoTierWiring

open Cathedral.CotangentPerturbation
open Cathedral.Vasyunin.Bound

-- ════════════════════════════════════════════════════════════════
-- §1. GRAM SPLIT + TWO-TIER = THE FULL BOUND
-- ════════════════════════════════════════════════════════════════

/-- **THE MASTER BOUND**: Combining Gram split and two-tier:

    vᵀGv = vᵀK_elem·v + vᵀK_cot·v
         ≤ vᵀK_elem·v + Head_J(v, K_cot) + M_tail · (Σ_{≥J} |v|)²

    The first two terms are EXACT finite computations.
    Only M_tail uses the Vasyunin bound.

    This is the key tool for Option B: the cotangent perturbation path. -/
theorem gram_two_tier_master (N J : ℕ) (K_elem : ℕ → ℕ → ℝ)
    (w : Fin N → ℝ) (M_tail : ℝ) (hMt : 0 ≤ M_tail)
    (htail : ∀ i j : Fin N, J ≤ i.val → J ≤ j.val →
      |cotKernelOf K_elem (i.val + 1) (j.val + 1)| ≤ M_tail) :
    bilinearForm N gramEntry w ≤
    bilinearForm N K_elem w +
    headForm N J (cotKernelOf K_elem) w +
    M_tail * (∑ i : Fin N, if J ≤ i.val then |w i| else 0) ^ 2 := by
  rw [gram_form_split N K_elem w]
  have h := two_tier_split_bound N J (cotKernelOf K_elem) w M_tail hMt htail
  linarith

-- ════════════════════════════════════════════════════════════════
-- §2. VASYUNIN BOUND → TAIL ENTRY BOUND
-- ════════════════════════════════════════════════════════════════

/-- **Vasyunin sum V+V bound**: For a,b ≥ 2,
    |V(a,b) + V(b,a)| ≤ Σ_{m∈Ico 1 a} |cot(πm/a)| + Σ_{m∈Ico 1 b} |cot(πm/b)|

    This is vasyuninSum_sum_abs_le from VasyuninBound.lean. -/
theorem vasyunin_vpv_bound (a b : ℕ) (ha : 2 ≤ a) (hb : 2 ≤ b) :
    |Cathedral.Vasyunin.vasyuninSum a b + Cathedral.Vasyunin.vasyuninSum b a| ≤
    ∑ m ∈ Ico 1 a, |Cathedral.Vasyunin.cot (Real.pi * m / a)| +
    ∑ m ∈ Ico 1 b, |Cathedral.Vasyunin.cot (Real.pi * m / b)| :=
  vasyuninSum_sum_abs_le a b ha hb

/-- **Vasyunin entry-level bound**: For a ≥ 2,
    |V(a,b)| ≤ (a-1) · C  for any C bounding |cot(πm/a)|. -/
theorem vasyunin_entry_bound (a b : ℕ) (ha : 2 ≤ a) (C : ℝ) (hC : 0 ≤ C)
    (hbound : ∀ m ∈ Ico 1 a, |Cathedral.Vasyunin.cot (Real.pi * m / a)| ≤ C) :
    |Cathedral.Vasyunin.vasyuninSum a b| ≤ (a - 1 : ℕ) * C :=
  vasyuninSum_abs_le_card_mul_sup a b ha C hC hbound

-- ════════════════════════════════════════════════════════════════
-- §3. HEAD EXACTNESS
-- ════════════════════════════════════════════════════════════════

/-- **THEOREM**: The head computation is exact.

    headForm N J K_cot w = bilinearForm N K_cot w - tailForm N J K_cot w

    This means: we don't need to BOUND the head — we compute it exactly
    as a finite sum. For a specific witness w and specific K_cot,
    the head is a definite real number (not an upper bound). -/
theorem head_is_exact (N J : ℕ) (K : ℕ → ℕ → ℝ) (w : Fin N → ℝ) :
    headForm N J K w = bilinearForm N K w - tailForm N J K w := by
  unfold headForm; rfl

/-- **THEOREM**: If the full form is non-negative and the tail is small,
    the head controls the form.

    bilinearForm = Head + Tail
    If Tail ≤ ε, then bilinearForm ≤ Head + ε. -/
theorem form_le_head_plus_tail_bound (N J : ℕ) (K : ℕ → ℕ → ℝ)
    (w : Fin N → ℝ) (ε : ℝ) (_hε : 0 ≤ ε)
    (htail : |tailForm N J K w| ≤ ε) :
    bilinearForm N K w ≤ headForm N J K w + ε := by
  have h := bilinear_head_tail_split N J K w
  rw [h]
  linarith [le_abs_self (tailForm N J K w)]

-- ════════════════════════════════════════════════════════════════
-- §4. AUDIT
-- ════════════════════════════════════════════════════════════════

/-!
## Audit — TwoTierWiring.lean (May 25, 2026)

### PROVED: 5 🎓 / 0 axioms / 0 sorry
| # | Result | Status |
|---|--------|--------|
| 1 | `gram_two_tier_master` | 🎓 vᵀGv ≤ Elem + Head + M·tail² |
| 2 | `vasyunin_vpv_bound` | 🎓 \|V+V\| ≤ Σ\|cot\| + Σ\|cot\| |
| 3 | `vasyunin_entry_bound` | 🎓 \|V(a,b)\| ≤ (a-1)·C |
| 4 | `head_is_exact` | 🎓 Head = Full - Tail (exact) |
| 5 | `form_le_head_plus_tail_bound` | 🎓 Full ≤ Head + ε |

### The Master Bound Architecture
```
  gramEntry ──── gram_form_split ────→ K_elem + K_cot
                                           │
  K_cot ──── bilinear_head_tail_split ─→ Head + Tail
                                           │         │
                           head_is_exact   │   tail_sup_bound
                           (EXACT)         │   (via vasyuninSum_abs_le)
                                           │         │
                              gram_two_tier_master ──┘
                                           │
                     vᵀGv ≤ Elem + Head + M_tail·(Σ|v|)²
                                           │
                     Head: exact finite computation
                     M_tail: from Vasyunin cotangent bound
```
-/

end Cathedral.TwoTierWiring
