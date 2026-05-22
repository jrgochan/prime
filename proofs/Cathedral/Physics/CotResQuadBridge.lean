/-
  Cathedral/Physics/CotResQuadBridge.lean

  ## The CotRes ↔ vᵀGv Bridge

  Connects the structural theorems (CotRes dissolution, Glass fibers)
  to the BD criterion (d² = 1 - 2bᵀv + vᵀGv).

  Created: May 21, 2026 — The Bridge Session
-/

import Cathedral.Physics.GlassFiberCotRes

noncomputable section
open Finset

namespace Cathedral.CotResQuadBridge

-- ════════════════════════════════════════════════════════════════
-- §1. DIAGONAL / OFF-DIAGONAL SPLIT
-- ════════════════════════════════════════════════════════════════

/-- The diagonal contribution. -/
def diagTerm (N : ℕ) (v : Fin N → ℝ) (K : ℕ → ℕ → ℝ) : ℝ :=
  ∑ i : Fin N, v i ^ 2 * K (i.val + 1) (i.val + 1)

/-- The off-diagonal (CotRes) contribution. -/
def offDiagTerm (N : ℕ) (v : Fin N → ℝ) (K : ℕ → ℕ → ℝ) : ℝ :=
  ∑ i : Fin N, ∑ j : Fin N,
    if i = j then 0 else v i * v j * K (i.val + 1) (j.val + 1)

/-- **THEOREM**: B(v, K) = DiagTerm(v, K) + OffDiagTerm(v, K). -/
theorem bilinear_diag_offdiag_split (N : ℕ) (v : Fin N → ℝ) (K : ℕ → ℕ → ℝ) :
    GlassFiberCotRes.bilinearForm N v K = diagTerm N v K + offDiagTerm N v K := by
  unfold GlassFiberCotRes.bilinearForm diagTerm offDiagTerm
  trans ∑ i : Fin N,
    ((∑ j : Fin N, if i = j then v i * v j * K (↑i + 1) (↑j + 1) else 0) +
     (∑ j : Fin N, if i = j then 0 else v i * v j * K (↑i + 1) (↑j + 1)))
  · apply Finset.sum_congr rfl; intro i _
    rw [← Finset.sum_add_distrib]
    apply Finset.sum_congr rfl; intro j _
    split_ifs with h
    · subst h; simp
    · simp
  rw [Finset.sum_add_distrib]
  congr 1
  apply Finset.sum_congr rfl; intro i _
  rw [Finset.sum_ite_eq]
  simp [Finset.mem_univ, sq]

-- ════════════════════════════════════════════════════════════════
-- §2. COTRES RATIONALITY TRANSFER
-- ════════════════════════════════════════════════════════════════

/-- **THEOREM (CotRes Rationality)**: B(v, K) = B(v, K_sym). -/
theorem bilinear_eq_sym_kernel (N : ℕ) (v : Fin N → ℝ) (K : ℕ → ℕ → ℝ) :
    GlassFiberCotRes.bilinearForm N v K =
    GlassFiberCotRes.bilinearForm N v (GlassFiberCotRes.kernelSym K) := by
  have := GlassFiberCotRes.bilinear_eq_sym N v K
  unfold GlassFiberCotRes.bilinearSym at this
  exact this

/-- Diag(K_sym) = Diag(K). -/
theorem diagTerm_sym_eq (N : ℕ) (v : Fin N → ℝ) (K : ℕ → ℕ → ℝ) :
    diagTerm N v (GlassFiberCotRes.kernelSym K) = diagTerm N v K := by
  unfold diagTerm GlassFiberCotRes.kernelSym
  apply Finset.sum_congr rfl; intro i _; congr 1; ring

/-- OffDiag(K) = OffDiag(K_sym): CotRes is rational. -/
theorem offDiag_sym_transfer (N : ℕ) (v : Fin N → ℝ) (K : ℕ → ℕ → ℝ) :
    offDiagTerm N v K =
    offDiagTerm N v (GlassFiberCotRes.kernelSym K) := by
  have h1 := bilinear_diag_offdiag_split N v K
  have h2 := bilinear_diag_offdiag_split N v (GlassFiberCotRes.kernelSym K)
  have h3 := bilinear_eq_sym_kernel N v K
  have h4 := diagTerm_sym_eq N v K
  linarith

-- ════════════════════════════════════════════════════════════════
-- §3. BD DISTANCE DECOMPOSITION
-- ════════════════════════════════════════════════════════════════

/-- **THEOREM**: BD bound decomposes through CotRes. -/
theorem bd_bound_decomp (N : ℕ) (v : Fin N → ℝ) (b : Fin N → ℝ)
    (K : ℕ → ℕ → ℝ) :
    1 - 2 * ∑ i : Fin N, b i * v i +
      GlassFiberCotRes.bilinearForm N v K =
    1 - 2 * ∑ i : Fin N, b i * v i +
      diagTerm N v K + offDiagTerm N v K := by
  rw [bilinear_diag_offdiag_split]; ring

-- ════════════════════════════════════════════════════════════════
-- §4. OFF-DIAGONAL BOUNDS
-- ════════════════════════════════════════════════════════════════

/-- Helper: Σᵢ Σⱼ f(i)·g(j) = (Σᵢ f(i))·(Σⱼ g(j)). -/
private lemma double_sum_product {N : ℕ} (f g : Fin N → ℝ) :
    ∑ i : Fin N, ∑ j : Fin N, f i * g j =
    (∑ i : Fin N, f i) * (∑ j : Fin N, g j) := by
  rw [Finset.sum_mul]
  apply Finset.sum_congr rfl; intro i _
  rw [Finset.mul_sum]

/-- |OffDiag(v, K)| ≤ (Σ|vᵢ|)² · M. -/
theorem offDiag_bound_by_kernel_sup (N : ℕ) (v : Fin N → ℝ)
    (K : ℕ → ℕ → ℝ) (M : ℝ) (hM_nn : 0 ≤ M)
    (hM : ∀ i j : Fin N, i ≠ j →
      |K (i.val + 1) (j.val + 1)| ≤ M) :
    |offDiagTerm N v K| ≤
    (∑ i : Fin N, |v i|) ^ 2 * M := by
  unfold offDiagTerm
  have step1 : |∑ i : Fin N, ∑ j : Fin N, if i = j then (0 : ℝ)
      else v i * v j * K (i.val + 1) (j.val + 1)| ≤
      ∑ i : Fin N, ∑ j : Fin N, |v i| * |v j| * M := by
    apply le_trans (Finset.abs_sum_le_sum_abs _ _)
    apply Finset.sum_le_sum; intro i _
    apply le_trans (Finset.abs_sum_le_sum_abs _ _)
    apply Finset.sum_le_sum; intro j _
    split_ifs with h
    · rw [abs_zero]
      exact mul_nonneg (mul_nonneg (abs_nonneg _) (abs_nonneg _)) hM_nn
    · rw [abs_mul, abs_mul]
      exact mul_le_mul_of_nonneg_left (hM i j h)
        (mul_nonneg (abs_nonneg _) (abs_nonneg _))
  have step2 : ∑ i : Fin N, ∑ j : Fin N, |v i| * |v j| * M =
      (∑ i : Fin N, |v i|) ^ 2 * M := by
    have key : ∑ i : Fin N, ∑ j : Fin N, |v i| * |v j| =
        (∑ i : Fin N, |v i|) * (∑ j : Fin N, |v j|) := double_sum_product _ _
    rw [sq]
    calc ∑ i : Fin N, ∑ j : Fin N, |v i| * |v j| * M
        = (∑ i : Fin N, ∑ j : Fin N, |v i| * |v j|) * M := by
          rw [Finset.sum_mul]
          apply Finset.sum_congr rfl; intro i _
          rw [Finset.sum_mul]
      _ = (∑ i : Fin N, |v i|) * (∑ j : Fin N, |v j|) * M := by
          rw [key]
  linarith

/-- |OffDiag(v, K)| ≤ B · (Σ |vᵢ|/(i+1))². -/
theorem offDiag_harmonic_bound (N : ℕ) (v : Fin N → ℝ)
    (K : ℕ → ℕ → ℝ) (B : ℝ) (hB : 0 ≤ B)
    (hK : ∀ i j : Fin N, i ≠ j →
      |K (i.val + 1) (j.val + 1)| ≤
      B / ((i.val + 1 : ℝ) * (j.val + 1 : ℝ))) :
    |offDiagTerm N v K| ≤
    B * (∑ i : Fin N, |v i| / (i.val + 1 : ℝ)) ^ 2 := by
  unfold offDiagTerm
  have step1 : |∑ i : Fin N, ∑ j : Fin N, if i = j then (0 : ℝ)
      else v i * v j * K (i.val + 1) (j.val + 1)| ≤
      ∑ i : Fin N, ∑ j : Fin N,
        |v i| / (i.val + 1 : ℝ) * (|v j| / (j.val + 1 : ℝ)) * B := by
    apply le_trans (Finset.abs_sum_le_sum_abs _ _)
    apply Finset.sum_le_sum; intro i _
    apply le_trans (Finset.abs_sum_le_sum_abs _ _)
    apply Finset.sum_le_sum; intro j _
    split_ifs with h
    · rw [abs_zero]
      apply mul_nonneg
      · apply mul_nonneg
        · exact div_nonneg (abs_nonneg _) (by positivity)
        · exact div_nonneg (abs_nonneg _) (by positivity)
      · exact hB
    · rw [abs_mul, abs_mul]
      calc |v i| * |v j| * |K (i.val + 1) (j.val + 1)|
          ≤ |v i| * |v j| * (B / ((i.val + 1 : ℝ) * (j.val + 1 : ℝ))) :=
            mul_le_mul_of_nonneg_left (hK i j h)
              (mul_nonneg (abs_nonneg _) (abs_nonneg _))
        _ = |v i| / (i.val + 1 : ℝ) * (|v j| / (j.val + 1 : ℝ)) * B := by
            field_simp
  have step2 : ∑ i : Fin N, ∑ j : Fin N,
      |v i| / (↑↑i + 1) * (|v j| / (↑↑j + 1)) * B =
      B * (∑ i : Fin N, |v i| / (↑↑i + 1)) ^ 2 := by
    have key : ∑ i : Fin N, ∑ j : Fin N,
        |v i| / (↑↑i + 1) * (|v j| / (↑↑j + 1)) =
        (∑ i : Fin N, |v i| / (↑↑i + 1)) * (∑ j : Fin N, |v j| / (↑↑j + 1)) :=
      double_sum_product _ _
    rw [sq]
    calc ∑ i : Fin N, ∑ j : Fin N,
        |v i| / (↑↑i + 1) * (|v j| / (↑↑j + 1)) * B
        = (∑ i : Fin N, ∑ j : Fin N,
          |v i| / (↑↑i + 1) * (|v j| / (↑↑j + 1))) * B := by
          rw [Finset.sum_mul]
          apply Finset.sum_congr rfl; intro i _
          rw [Finset.sum_mul]
      _ = B * ((∑ i : Fin N, |v i| / (↑↑i + 1)) * (∑ j : Fin N, |v j| / (↑↑j + 1))) := by
          rw [key]; ring
  linarith

-- ════════════════════════════════════════════════════════════════
-- §5. AUDIT
-- ════════════════════════════════════════════════════════════════

/-!
## Audit — CotResQuadBridge (May 21, 2026)

### PROVED: 7 🎓 / 0 axioms
| # | Result | Status |
|---|--------|--------|
| 1 | `bilinear_diag_offdiag_split` | 🎓 B = Diag + OffDiag |
| 2 | `bilinear_eq_sym_kernel` | 🎓 B(v,K) = B(v,K_sym) |
| 3 | `diagTerm_sym_eq` | 🎓 Diag(K_sym) = Diag(K) |
| 4 | `offDiag_sym_transfer` | 🎓 OffDiag(K) = OffDiag(K_sym) |
| 5 | `bd_bound_decomp` | 🎓 BD = 1-2bv + Diag + OffDiag |
| 6 | `offDiag_bound_by_kernel_sup` | 🎓 |OffDiag| ≤ (Σ|v|)² · M |
| 7 | `offDiag_harmonic_bound` | 🎓 |OffDiag| ≤ B·(Σ|v|/k)² |

### Architecture
```
  GlassFiberCotRes.lean              DiagonalDecomposition.lean
  (bilinearAnti_zero)                (diagonal_gram_decomposition)
         ↓                                    ↓
  bilinear_eq_sym_kernel ─────→ bilinear_diag_offdiag_split
         ↓                                    ↓
  offDiag_sym_transfer           bd_bound_decomp
         ↓                                    ↓
  CotRes is rational!            d² = 1-2bv + Diag + CotRes
         ↓
  offDiag_harmonic_bound: |CotRes| ≤ B·(Σ|v|/k)²
```
-/

end Cathedral.CotResQuadBridge
