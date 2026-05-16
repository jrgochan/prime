import Mathlib.NumberTheory.ArithmeticFunction.Moebius
import Mathlib.Data.Real.Basic

open Finset

-- Proven: symmetric sum swap for dependent ranges
theorem sum_swap_div_range (f : ℕ → ℕ → ℝ) (M : ℕ) :
    ∑ r ∈ range M, ∑ m ∈ range (M / (r + 1)), f r m =
    ∑ m ∈ range M, ∑ r ∈ range (M / (m + 1)), f r m := by
  rw [sum_sigma', sum_sigma']
  apply sum_nbij' (fun ⟨r, m⟩ => ⟨m, r⟩) (fun ⟨m, r⟩ => ⟨r, m⟩)
  · intro ⟨r, m⟩ hmem
    simp only [mem_sigma, mem_range] at hmem ⊢
    have hle : (m + 1) * (r + 1) ≤ M := by
      calc (m + 1) * (r + 1) ≤ M / (r + 1) * (r + 1) := Nat.mul_le_mul_right _ hmem.2
        _ ≤ M := Nat.div_mul_le_self M (r + 1)
    constructor
    · have : m + 1 ≤ M := le_trans (Nat.le_mul_of_pos_right _ (by omega)) hle; omega
    · have : (r + 1) * (m + 1) ≤ M := by rw [Nat.mul_comm]; exact hle
      have : r + 1 ≤ M / (m + 1) := (Nat.le_div_iff_mul_le (by omega)).mpr this; omega
  · intro ⟨m, r⟩ hmem
    simp only [mem_sigma, mem_range] at hmem ⊢
    have hle : (r + 1) * (m + 1) ≤ M := by
      calc (r + 1) * (m + 1) ≤ M / (m + 1) * (m + 1) := Nat.mul_le_mul_right _ hmem.2
        _ ≤ M := Nat.div_mul_le_self M (m + 1)
    constructor
    · have : r + 1 ≤ M := le_trans (Nat.le_mul_of_pos_right _ (by omega)) hle; omega
    · have : (m + 1) * (r + 1) ≤ M := by rw [Nat.mul_comm]; exact hle
      have : m + 1 ≤ M / (r + 1) := (Nat.le_div_iff_mul_le (by omega)).mpr this; omega
  · intro ⟨r, m⟩ _; rfl
  · intro ⟨m, r⟩ _; rfl
  · intro ⟨r, m⟩ _; rfl

-- Test: the moebius_cancellation proof pattern
-- After swap: Σ_m μ(m+1) * Σ_r f((r+1)(m+1)) = f(1) by dirichlet_moebius_sum
noncomputable def mu (n : ℕ) : ℤ := ArithmeticFunction.moebius n

axiom dirichlet_moebius_sum (h : ℕ → ℝ) (M : ℕ) (hM : 0 < M) :
    ∑ d ∈ range M, (mu (d + 1) : ℝ) * ∑ a ∈ range (M / (d + 1)),
      h ((d + 1) * (a + 1)) = h 1

theorem moebius_cancel (f : ℕ → ℝ) (M : ℕ) (hM : 0 < M) :
    ∑ r ∈ range M, ∑ m ∈ range (M / (r + 1)),
      (mu (m + 1) : ℝ) * f ((r + 1) * (m + 1)) = f 1 := by
  -- Step 1: Swap r and m
  rw [sum_swap_div_range (fun r m => (mu (m + 1) : ℝ) * f ((r + 1) * (m + 1))) M]
  -- Now: Σ_m Σ_{r < M/(m+1)} μ(m+1) * f((r+1)(m+1))
  -- Step 2: Factor μ(m+1) out of the inner sum
  simp_rw [← mul_sum]
  -- Now: Σ_m μ(m+1) * Σ_r f((r+1)(m+1))
  -- Step 3: Commute multiplication: (r+1)*(m+1) = (m+1)*(r+1)
  simp_rw [Nat.mul_comm]
  -- Now matches dirichlet_moebius_sum: Σ_m μ(m+1) * Σ_r f((m+1)*(r+1)) = f(1)
  exact dirichlet_moebius_sum f M hM
