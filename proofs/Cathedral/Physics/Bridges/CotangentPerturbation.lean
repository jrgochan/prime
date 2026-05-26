/-
  Cathedral/Physics/Bridges/CotangentPerturbation.lean

  ## OPTION B: Cotangent as Small Perturbation

  Strategy: Split the Gram quadratic form as
    vᵀGv = vᵀG_nocot·v + vᵀG_cot·v
  and bound the cotangent part using the PROVED Vasyunin bound.

  Created: May 25, 2026 — Option B
-/

import Cathedral.Defs
import Mathlib.Data.Real.Basic
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Tactic.Ring
import Mathlib.Tactic.Linarith
import Mathlib.Tactic.Positivity

noncomputable section
open Finset

namespace Cathedral.CotangentPerturbation

-- ════════════════════════════════════════════════════════════════
-- §1. ABSTRACT PERTURBATION FRAMEWORK
-- ════════════════════════════════════════════════════════════════

/-- A bilinear form Q(w) = Σᵢ Σⱼ K(i+1,j+1) · w(i) · w(j). -/
noncomputable def bilinearForm (N : ℕ) (K : ℕ → ℕ → ℝ) (w : Fin N → ℝ) : ℝ :=
  ∑ i : Fin N, ∑ j : Fin N,
    K (i.val + 1) (j.val + 1) * w i * w j

/-- **THEOREM**: Bilinear forms are additive in the kernel. -/
theorem bilinear_add (N : ℕ) (K₁ K₂ : ℕ → ℕ → ℝ) (w : Fin N → ℝ) :
    bilinearForm N (fun j k => K₁ j k + K₂ j k) w =
    bilinearForm N K₁ w + bilinearForm N K₂ w := by
  unfold bilinearForm
  simp only [add_mul, Finset.sum_add_distrib]

/-- **THEOREM**: Bilinear form triangle inequality. -/
theorem bilinear_abs_le (N : ℕ) (K : ℕ → ℕ → ℝ) (w : Fin N → ℝ) :
    |bilinearForm N K w| ≤
    ∑ i : Fin N, ∑ j : Fin N,
      |K (i.val + 1) (j.val + 1)| * |w i| * |w j| := by
  unfold bilinearForm
  calc |∑ i : Fin N, ∑ j : Fin N,
        K (↑i + 1) (↑j + 1) * w i * w j|
      ≤ ∑ i : Fin N, |∑ j : Fin N,
        K (↑i + 1) (↑j + 1) * w i * w j| :=
        Finset.abs_sum_le_sum_abs _ _
    _ ≤ ∑ i : Fin N, ∑ j : Fin N,
        |K (↑i + 1) (↑j + 1) * w i * w j| := by
        apply Finset.sum_le_sum; intro i _
        exact Finset.abs_sum_le_sum_abs _ _
    _ = ∑ i : Fin N, ∑ j : Fin N,
        |K (↑i + 1) (↑j + 1)| * |w i| * |w j| := by
        apply Finset.sum_congr rfl; intro i _
        apply Finset.sum_congr rfl; intro j _
        rw [abs_mul, abs_mul]

/-- Helper: double sum of products factors. -/
private lemma double_sum_factor {N : ℕ} (f g : Fin N → ℝ) :
    ∑ i : Fin N, ∑ j : Fin N, f i * g j =
    (∑ i : Fin N, f i) * (∑ j : Fin N, g j) := by
  rw [Finset.sum_mul]
  apply Finset.sum_congr rfl; intro i _
  rw [Finset.mul_sum]

/-- **THEOREM**: Kernel supremum bound.
    If |K(j,k)| ≤ M for all j,k, then |Q_K(w)| ≤ M · (Σ|wᵢ|)². -/
theorem bilinear_sup_bound (N : ℕ) (K : ℕ → ℕ → ℝ) (w : Fin N → ℝ)
    (M : ℝ) (_hM : 0 ≤ M)
    (hbound : ∀ i j : Fin N,
      |K (i.val + 1) (j.val + 1)| ≤ M) :
    |bilinearForm N K w| ≤
    M * (∑ i : Fin N, |w i|) ^ 2 := by
  have h1 := bilinear_abs_le N K w
  have h2 : ∑ i : Fin N, ∑ j : Fin N,
      |K (↑i + 1) (↑j + 1)| * |w i| * |w j| ≤
      ∑ i : Fin N, ∑ j : Fin N, M * |w i| * |w j| := by
    apply Finset.sum_le_sum; intro i _
    apply Finset.sum_le_sum; intro j _
    apply mul_le_mul_of_nonneg_right
    · exact mul_le_mul_of_nonneg_right (hbound i j) (abs_nonneg _)
    · exact abs_nonneg _
  have h3 : ∑ i : Fin N, ∑ j : Fin N, M * |w i| * |w j| =
      M * (∑ i : Fin N, |w i|) ^ 2 := by
    conv_lhs =>
      arg 2; ext i; arg 2; ext j
      rw [show M * |w i| * |w j| = (M * |w i|) * |w j| from by ring]
    have factored := double_sum_factor (fun i => M * |w i|) (fun j => |w j|)
    rw [factored]
    have : ∑ i : Fin N, M * |w i| = M * ∑ i : Fin N, |w i| := by
      rw [Finset.mul_sum]
    rw [this, sq]; ring
  linarith

-- ════════════════════════════════════════════════════════════════
-- §2. THE PERTURBATION THEOREM
-- ════════════════════════════════════════════════════════════════

/-- **MASTER PERTURBATION THEOREM**:
    If K = K₁ + K₂ and |K₂(j,k)| ≤ ε, then
    Q_K(w) ≤ Q_{K₁}(w) + ε · (Σ|wᵢ|)². -/
theorem perturbation_bound (N : ℕ) (K₁ K₂ : ℕ → ℕ → ℝ)
    (w : Fin N → ℝ) (ε : ℝ) (hε : 0 ≤ ε)
    (hbound : ∀ i j : Fin N,
      |K₂ (i.val + 1) (j.val + 1)| ≤ ε) :
    bilinearForm N (fun j k => K₁ j k + K₂ j k) w ≤
    bilinearForm N K₁ w + ε * (∑ i : Fin N, |w i|) ^ 2 := by
  rw [bilinear_add]
  have hK2 := bilinear_sup_bound N K₂ w ε hε hbound
  -- |Q_{K₂}| ≤ ε·(Σ|w|)² implies Q_{K₂} ≤ ε·(Σ|w|)²
  linarith [le_abs_self (bilinearForm N K₂ w)]

/-- **LOWER PERTURBATION BOUND**:
    Q_K(w) ≥ Q_{K₁}(w) - ε · (Σ|wᵢ|)². -/
theorem perturbation_lower_bound (N : ℕ) (K₁ K₂ : ℕ → ℕ → ℝ)
    (w : Fin N → ℝ) (ε : ℝ) (hε : 0 ≤ ε)
    (hbound : ∀ i j : Fin N,
      |K₂ (i.val + 1) (j.val + 1)| ≤ ε) :
    bilinearForm N K₁ w - ε * (∑ i : Fin N, |w i|) ^ 2 ≤
    bilinearForm N (fun j k => K₁ j k + K₂ j k) w := by
  rw [bilinear_add]
  have hK2 := bilinear_sup_bound N K₂ w ε hε hbound
  linarith [neg_abs_le (bilinearForm N K₂ w)]

-- ════════════════════════════════════════════════════════════════
-- §3. APPLICATION: GRAM = ELEMENTARY + COTANGENT PERTURBATION
-- ════════════════════════════════════════════════════════════════

/-- The cotangent perturbation kernel. For any splitting
    G = K_elem + K_cot, the perturbation framework applies.

    We define K_cot abstractly via K_cot = G - K_elem,
    parameterized by K_elem. -/
noncomputable def cotKernelOf (K_elem : ℕ → ℕ → ℝ) (j k : ℕ) : ℝ :=
  gramEntry j k - K_elem j k

/-- **THEOREM**: G = K_elem + cotKernelOf K_elem, by construction. -/
theorem gram_eq_elem_plus_cot (K_elem : ℕ → ℕ → ℝ) (j k : ℕ) :
    gramEntry j k = K_elem j k + cotKernelOf K_elem j k := by
  unfold cotKernelOf; ring

/-- **THEOREM**: The Gram quadratic form splits for any K_elem. -/
theorem gram_form_split (N : ℕ) (K_elem : ℕ → ℕ → ℝ) (w : Fin N → ℝ) :
    bilinearForm N gramEntry w =
    bilinearForm N K_elem w +
    bilinearForm N (cotKernelOf K_elem) w := by
  -- gramEntry = K_elem + cotKernelOf K_elem pointwise
  show bilinearForm N (fun j k => gramEntry j k) w =
    bilinearForm N K_elem w + bilinearForm N (cotKernelOf K_elem) w
  have key : (fun j k => gramEntry j k) =
      (fun j k => K_elem j k + cotKernelOf K_elem j k) := by
    ext j k; exact gram_eq_elem_plus_cot K_elem j k
  rw [key]
  exact bilinear_add N K_elem (cotKernelOf K_elem) w

/-- **COROLLARY**: Gram perturbation bound.
    If the "cotangent kernel" |G(j,k) - K_elem(j,k)| ≤ ε, then
    vᵀGv ≤ vᵀK_elem·v + ε · (Σ|wᵢ|)². -/
theorem gram_perturbation_bound (N : ℕ) (K_elem : ℕ → ℕ → ℝ)
    (w : Fin N → ℝ) (ε : ℝ) (hε : 0 ≤ ε)
    (hcot : ∀ i j : Fin N,
      |cotKernelOf K_elem (i.val + 1) (j.val + 1)| ≤ ε) :
    bilinearForm N gramEntry w ≤
    bilinearForm N K_elem w +
    ε * (∑ i : Fin N, |w i|) ^ 2 := by
  rw [gram_form_split N K_elem w]
  have hK2 := bilinear_sup_bound N (cotKernelOf K_elem) w ε hε hcot
  linarith [le_abs_self (bilinearForm N (cotKernelOf K_elem) w)]

/-- **COROLLARY**: Gram perturbation lower bound.
    vᵀGv ≥ vᵀK_elem·v - ε · (Σ|wᵢ|)². -/
theorem gram_perturbation_lower_bound (N : ℕ) (K_elem : ℕ → ℕ → ℝ)
    (w : Fin N → ℝ) (ε : ℝ) (hε : 0 ≤ ε)
    (hcot : ∀ i j : Fin N,
      |cotKernelOf K_elem (i.val + 1) (j.val + 1)| ≤ ε) :
    bilinearForm N K_elem w -
    ε * (∑ i : Fin N, |w i|) ^ 2 ≤
    bilinearForm N gramEntry w := by
  rw [gram_form_split N K_elem w]
  have hK2 := bilinear_sup_bound N (cotKernelOf K_elem) w ε hε hcot
  linarith [neg_abs_le (bilinearForm N (cotKernelOf K_elem) w)]

-- ════════════════════════════════════════════════════════════════
-- §4. TWO-TIER HEAD/TAIL SPLITTING
-- ════════════════════════════════════════════════════════════════

/-- The "tail" bilinear form: sum only over pairs with both i,j ≥ J. -/
noncomputable def tailForm (N J : ℕ) (K : ℕ → ℕ → ℝ) (w : Fin N → ℝ) : ℝ :=
  ∑ i : Fin N, ∑ j : Fin N,
    if J ≤ i.val ∧ J ≤ j.val then
      K (i.val + 1) (j.val + 1) * w i * w j
    else 0

/-- The "head" bilinear form: Q - Tail. -/
noncomputable def headForm (N J : ℕ) (K : ℕ → ℕ → ℝ) (w : Fin N → ℝ) : ℝ :=
  bilinearForm N K w - tailForm N J K w

/-- **THEOREM**: Q(w) = Head_J(w) + Tail_J(w). -/
theorem bilinear_head_tail_split (N J : ℕ) (K : ℕ → ℕ → ℝ)
    (w : Fin N → ℝ) :
    bilinearForm N K w = headForm N J K w + tailForm N J K w := by
  unfold headForm; ring

/-- **THEOREM**: Tail triangle inequality. -/
theorem tail_abs_le (N J : ℕ) (K : ℕ → ℕ → ℝ) (w : Fin N → ℝ) :
    |tailForm N J K w| ≤
    ∑ i : Fin N, ∑ j : Fin N,
      if J ≤ i.val ∧ J ≤ j.val then
        |K (i.val + 1) (j.val + 1)| * |w i| * |w j|
      else 0 := by
  unfold tailForm
  apply le_trans (Finset.abs_sum_le_sum_abs _ _)
  apply Finset.sum_le_sum; intro i _
  apply le_trans (Finset.abs_sum_le_sum_abs _ _)
  apply Finset.sum_le_sum; intro j _
  split_ifs with h
  · rw [abs_mul, abs_mul]
  · simp

/-- **THEOREM**: Tail bound via kernel supremum on the tail region.
    If |K(j,k)| ≤ M for all j,k with 0-indexed i,j ≥ J, then
    |Tail_J(w)| ≤ M · (Σ_{i≥J} |w_i|)². -/
theorem tail_sup_bound (N J : ℕ) (K : ℕ → ℕ → ℝ) (w : Fin N → ℝ)
    (M : ℝ) (_hM : 0 ≤ M)
    (hbound : ∀ i j : Fin N, J ≤ i.val → J ≤ j.val →
      |K (i.val + 1) (j.val + 1)| ≤ M) :
    |tailForm N J K w| ≤
    M * (∑ i : Fin N, if J ≤ i.val then |w i| else 0) ^ 2 := by
  have h1 := tail_abs_le N J K w
  have h2 : ∑ i : Fin N, ∑ j : Fin N,
      (if J ≤ ↑i ∧ J ≤ ↑j then |K (↑i + 1) (↑j + 1)| * |w i| * |w j| else 0) ≤
      ∑ i : Fin N, ∑ j : Fin N,
      (if J ≤ ↑i ∧ J ≤ ↑j then M * |w i| * |w j| else 0) := by
    apply Finset.sum_le_sum; intro i _
    apply Finset.sum_le_sum; intro j _
    split_ifs with h
    · apply mul_le_mul_of_nonneg_right
      · exact mul_le_mul_of_nonneg_right (hbound i j h.1 h.2) (abs_nonneg _)
      · exact abs_nonneg _
    · exact le_refl _
  have h3 : ∑ i : Fin N, ∑ j : Fin N,
      (if J ≤ ↑i ∧ J ≤ ↑j then M * |w i| * |w j| else 0) =
      M * (∑ i : Fin N, if J ≤ ↑i then |w i| else 0) ^ 2 := by
    have key : ∀ i j : Fin N,
        (if J ≤ ↑i ∧ J ≤ ↑j then M * |w i| * |w j| else 0) =
        (if J ≤ ↑i then M * |w i| else 0) *
        (if J ≤ ↑j then |w j| else 0) := by
      intro i j
      by_cases hi : J ≤ ↑i <;> by_cases hj : J ≤ ↑j <;> simp [hi, hj]
    conv_lhs => arg 2; ext i; arg 2; ext j; rw [key i j]
    rw [double_sum_factor]
    -- LHS is now: (Σ_i (if J≤i then M*|w_i| else 0)) * (Σ_j (if J≤j then |w_j| else 0))
    -- Factor out M from first sum
    have factorM : ∑ i : Fin N, (if J ≤ ↑i then M * |w i| else 0) =
        M * ∑ i : Fin N, (if J ≤ ↑i then |w i| else 0) := by
      simp only [Finset.mul_sum]
      apply Finset.sum_congr rfl; intro i _
      by_cases hi : J ≤ ↑i <;> simp [hi]
    rw [factorM, sq]; ring
  linarith

-- ════════════════════════════════════════════════════════════════
-- §5. THE TWO-TIER THEOREM
-- ════════════════════════════════════════════════════════════════

/-- **TWO-TIER SPLIT BOUND**:
    Q(w) ≤ Head_J(w) + M_tail · (Σ_{i≥J} |w_i|)².

    The head is computed EXACTLY (finite sum, no approximation).
    Only the tail gets the sup-norm bound.
    This is the key tool for Option B. -/
theorem two_tier_split_bound (N J : ℕ) (K : ℕ → ℕ → ℝ) (w : Fin N → ℝ)
    (M_tail : ℝ) (hMt : 0 ≤ M_tail)
    (htail : ∀ i j : Fin N, J ≤ i.val → J ≤ j.val →
      |K (i.val + 1) (j.val + 1)| ≤ M_tail) :
    bilinearForm N K w ≤
    headForm N J K w +
    M_tail * (∑ i : Fin N, if J ≤ i.val then |w i| else 0) ^ 2 := by
  have h_split := bilinear_head_tail_split N J K w
  have h_tail := tail_sup_bound N J K w M_tail hMt htail
  rw [h_split]
  linarith [le_abs_self (tailForm N J K w)]

-- ════════════════════════════════════════════════════════════════
-- §6. AUDIT
-- ════════════════════════════════════════════════════════════════

/-!
## Audit — CotangentPerturbation.lean (May 25, 2026)

### PROVED: 13 🎓 / 0 axioms / 0 sorry
| # | Result | Status |
|---|--------|--------|
| 1 | `bilinear_add` | 🎓 Q_{K₁+K₂} = Q_{K₁} + Q_{K₂} |
| 2 | `bilinear_abs_le` | 🎓 \|Q_K\| ≤ Σ\|K\|·\|w\|·\|w\| |
| 3 | `bilinear_sup_bound` | 🎓 \|Q_K\| ≤ M·(Σ\|w\|)² |
| 4 | `perturbation_bound` | 🎓 Q_{K₁+K₂} ≤ Q_{K₁} + ε·(Σ\|w\|)² |
| 5 | `perturbation_lower_bound` | 🎓 Q_{K₁+K₂} ≥ Q_{K₁} - ε·(Σ\|w\|)² |
| 6 | `gram_eq_elem_plus_cot` | 🎓 G = K_elem + K_cot |
| 7 | `gram_form_split` | 🎓 vᵀGv = vᵀK_elem·v + vᵀK_cot·v |
| 8 | `gram_perturbation_bound` | 🎓 vᵀGv ≤ vᵀK_elem·v + ε·(Σ\|w\|)² |
| 9 | `gram_perturbation_lower_bound` | 🎓 vᵀGv ≥ vᵀK_elem·v - ε·(Σ\|w\|)² |
| 10 | `bilinear_head_tail_split` | 🎓 Q = Head_J + Tail_J |
| 11 | `tail_abs_le` | 🎓 triangle inequality for tail |
| 12 | `tail_sup_bound` | 🎓 \|Tail\| ≤ M·(Σ_{≥J}\|w\|)² |
| 13 | `two_tier_split_bound` | 🎓 Q ≤ Head + M_tail·(Σ_{≥J}\|w\|)² |

### The Two-Tier Strategy
```
          bilinearForm N K w
          ┌─────────┴─────────┐
     headForm (exact)    tailForm (bounded)
     [indices < J]       [indices ≥ J]
          │                    │
     computed by          |Tail| ≤ M·(Σ_{≥J}|w|)²
     finite sum           (tail_sup_bound)
          │                    │
          └─────────┬──────────┘
      Q ≤ Head + M·(Σ_{≥J}|w|)²
      (two_tier_split_bound)
```
-/

end Cathedral.CotangentPerturbation

