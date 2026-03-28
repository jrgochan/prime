import Mathlib.Data.Real.Basic
import Mathlib.Algebra.Order.Field.Basic

def isContraction (α : ℝ) : Prop := |α| ≤ 1
axiom HeckeEigenvalue : ℝ
axiom liCoefficient : ℕ → ℝ
axiom li_trace_formula (n : ℕ) : liCoefficient n = 1 - HeckeEigenvalue ^ n

theorem li_positive_from_contraction (n : ℕ) (h_contract : isContraction HeckeEigenvalue) :
    0 ≤ liCoefficient n := by
  rw [li_trace_formula]
  have h1 : |HeckeEigenvalue| ≤ 1 := h_contract
  have h2 : |HeckeEigenvalue ^ n| ≤ 1 := by
    rw [abs_pow]
    exact pow_le_one n (abs_nonneg _) h1
  have h3 : HeckeEigenvalue ^ n ≤ 1 := by
    exact (abs_le.mp h2).2
  linarith
