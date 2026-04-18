/-
  Scratch: Phase 2 — Weak Hilbert Inequality via Schur's Test.
-/

import Mathlib.Analysis.InnerProductSpace.Basic
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Algebra.BigOperators.Group.Finset.Sigma
import Mathlib.Algebra.Order.BigOperators.Ring.Finset

noncomputable section
open Complex Real Finset BigOperators

def IsDeltaSeparated {N : ℕ} (lam : Fin N → ℝ) (δ : ℝ) : Prop :=
  ∀ i j : Fin N, i ≠ j → δ ≤ |lam i - lam j|

-- Key lemma: δ-separation implies distinct values
lemma delta_sep_ne_of_ne {N : ℕ} {lam : Fin N → ℝ} {δ : ℝ} (hδ : 0 < δ)
    (h_sep : IsDeltaSeparated lam δ) {i j : Fin N} (hij : i ≠ j) :
    lam i ≠ lam j := by
  intro h
  have := h_sep i j hij
  rw [h, sub_self, abs_zero] at this
  linarith

-- The norm of 1/(λ_i - λ_j) is bounded by 1/δ
lemma norm_inv_sub_le {N : ℕ} {lam : Fin N → ℝ} {δ : ℝ} (hδ : 0 < δ)
    (h_sep : IsDeltaSeparated lam δ) {i j : Fin N} (hij : i ≠ j) :
    1 / |lam i - lam j| ≤ 1 / δ := by
  have hab := h_sep i j hij
  have hpos : 0 < |lam i - lam j| := lt_of_lt_of_le hδ hab
  exact div_le_div_of_nonneg_left (by positivity) hδ hab

-- The kernel norm is bounded
lemma kernel_norm_le {N : ℕ} {lam : Fin N → ℝ} {δ : ℝ} (hδ : 0 < δ)
    (h_sep : IsDeltaSeparated lam δ) {i j : Fin N} (hij : i ≠ j) :
    ‖(1 : ℂ) / ((lam i - lam j : ℝ) : ℂ)‖ ≤ 1 / δ := by
  rw [norm_div, norm_one, Complex.norm_real]
  exact norm_inv_sub_le hδ h_sep hij

-- Row sum bound: at most (N-1)/δ
-- Each of the N-1 off-diagonal terms is ≤ 1/δ, and the diagonal is 0.
-- This is WEAKER than the sharp π/δ from Montgomery-Vaughan,
-- but it follows immediately from Schur's test.
lemma row_sum_le_card_div_delta {N : ℕ} (lam : Fin N → ℝ) (δ : ℝ)
    (hδ : 0 < δ) (h_sep : IsDeltaSeparated lam δ) (i : Fin N) :
    ∑ j : Fin N, ‖(if i = j then (0 : ℂ) else
      (1 : ℂ) / ((lam i - lam j : ℝ) : ℂ))‖ ≤ ↑(Fintype.card (Fin N)) / δ := by
  calc ∑ j : Fin N, ‖(if i = j then (0 : ℂ) else
        (1 : ℂ) / ((lam i - lam j : ℝ) : ℂ))‖
      ≤ ∑ j : Fin N, (1 / δ) := by
        apply Finset.sum_le_sum; intro j _
        split_ifs with h
        · simp; positivity
        · exact kernel_norm_le hδ h_sep h
    _ = ↑(Fintype.card (Fin N)) / δ := by
        simp [Finset.sum_const, Finset.card_univ, nsmul_eq_mul]; ring

end
