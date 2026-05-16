import Mathlib.NumberTheory.ArithmeticFunction.Moebius
import Mathlib.Data.Real.Basic

open Finset ArithmeticFunction

lemma mul_succ_le_of_lt_div (d a M : ℕ) (ha : a < M / (d + 1)) :
    (d + 1) * (a + 1) ≤ M := by
  have : a + 1 ≤ M / (d + 1) := ha
  calc (d + 1) * (a + 1) ≤ (d + 1) * (M / (d + 1)) :=
        Nat.mul_le_mul_left (d + 1) this
    _ ≤ M := Nat.mul_div_le M (d + 1)

lemma mul_succ_pos (d a : ℕ) : 0 < (d + 1) * (a + 1) := by positivity

theorem double_sum_reindex (f : ℕ → ℕ → ℝ) (M : ℕ) :
    ∑ d ∈ range M, ∑ a ∈ range (M / (d + 1)), f d a =
    ∑ n ∈ range M, ∑ r ∈ (n + 1).divisors, f (r - 1) ((n + 1) / r - 1) := by
  rw [sum_sigma', sum_sigma']
  apply sum_nbij' (fun ⟨d, a⟩ => ⟨(d + 1) * (a + 1) - 1, (d + 1)⟩)
                   (fun ⟨n, r⟩ => ⟨r - 1, (n + 1) / r - 1⟩)
  -- 1. Forward membership
  · intro ⟨d, a⟩ hmem
    simp only [mem_sigma, mem_range] at hmem ⊢
    have hle : (d + 1) * (a + 1) ≤ M := mul_succ_le_of_lt_div d a M hmem.2
    have hpos : 0 < (d + 1) * (a + 1) := mul_succ_pos d a
    exact ⟨by omega,
      by rw [show (d + 1) * (a + 1) - 1 + 1 = (d + 1) * (a + 1) from by omega]
         exact Nat.mem_divisors.mpr ⟨⟨a + 1, by ring⟩, by omega⟩⟩
  -- 2. Backward membership
  · intro ⟨n, r⟩ hmem
    simp only [mem_sigma, mem_range] at hmem ⊢
    have hr_dvd : r ∣ n + 1 := Nat.dvd_of_mem_divisors hmem.2
    have hr_pos : 0 < r := Nat.pos_of_mem_divisors hmem.2
    have hq_pos : 0 < (n + 1) / r := Nat.div_pos (Nat.le_of_dvd (by omega) hr_dvd) hr_pos
    exact ⟨by have : r ≤ n + 1 := Nat.le_of_dvd (by omega) hr_dvd; omega,
      by rw [show r - 1 + 1 = r from by omega]
         exact Nat.lt_of_lt_of_le (by omega) (Nat.div_le_div_right (by omega : n + 1 ≤ M))⟩
  -- 3. Left inverse: backward(forward(⟨d,a⟩)) = ⟨d,a⟩
  · intro ⟨d, a⟩ hmem
    simp only [mem_sigma, mem_range] at hmem
    have hpos : 0 < (d + 1) * (a + 1) := mul_succ_pos d a
    ext
    · simp
    · simp
      rw [show (d + 1) * (a + 1) - 1 + 1 = (d + 1) * (a + 1) from by omega]
      rw [Nat.mul_div_cancel_left _ (by omega : 0 < d + 1)]
      omega
  -- 4. Right inverse: forward(backward(⟨n,r⟩)) = ⟨n,r⟩
  · intro ⟨n, r⟩ hmem
    simp only [mem_sigma, mem_range] at hmem
    have hr_dvd : r ∣ n + 1 := Nat.dvd_of_mem_divisors hmem.2
    have hr_pos : 0 < r := Nat.pos_of_mem_divisors hmem.2
    have hq_pos : 0 < (n + 1) / r := Nat.div_pos (Nat.le_of_dvd (by omega) hr_dvd) hr_pos
    ext
    · simp
      rw [show r - 1 + 1 = r from by omega,
          show (n + 1) / r - 1 + 1 = (n + 1) / r from by omega]
      rw [Nat.mul_div_cancel' hr_dvd]; omega
    · simp; omega
  -- 5. Function value match
  · intro ⟨d, a⟩ hmem
    simp only
    have hpos : 0 < (d + 1) * (a + 1) := mul_succ_pos d a
    show f d a = f ((d + 1) - 1) (((d + 1) * (a + 1) - 1 + 1) / (d + 1) - 1)
    rw [show (d + 1) * (a + 1) - 1 + 1 = (d + 1) * (a + 1) from by omega]
    rw [Nat.mul_div_cancel_left _ (by omega : 0 < d + 1)]
    simp
