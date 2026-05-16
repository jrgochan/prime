import Mathlib.NumberTheory.ArithmeticFunction.Moebius
import Mathlib.Data.Real.Basic

open Finset ArithmeticFunction

lemma moebius_divisor_sum (n : ℕ) (hn : 0 < n) :
    ∑ d ∈ n.divisors, (moebius d : ℤ) =
    if n = 1 then 1 else 0 := by
  have h1 := moebius_mul_coe_zeta
  have h2 := congr_fun (congr_arg DFunLike.coe h1) n
  simp only [mul_apply, one_apply] at h2
  have h3 : ∀ x ∈ n.divisorsAntidiagonal,
      moebius x.1 * ((↑zeta : ArithmeticFunction ℤ) x.2) = moebius x.1 := by
    intro x hx
    have : x.2 ≠ 0 :=
      (Nat.pos_of_mem_divisors (Nat.snd_mem_divisors_of_mem_antidiagonal hx)).ne'
    simp [zeta_apply, this]
  rw [Finset.sum_congr rfl h3] at h2
  have antidiag_to_div : ∑ x ∈ n.divisorsAntidiagonal, moebius x.1 =
      ∑ d ∈ n.divisors, moebius d := by
    apply Finset.sum_nbij' (fun x => x.1) (fun d => (d, n / d))
    · intro x hx; exact Nat.fst_mem_divisors_of_mem_antidiagonal hx
    · intro d hd; exact Nat.mem_divisorsAntidiagonal.mpr
        ⟨Nat.mul_div_cancel' (Nat.dvd_of_mem_divisors hd), hn.ne'⟩
    · intro x hx
      have hmem := Nat.mem_divisorsAntidiagonal.mp hx
      have hab : x.1 * x.2 = n := hmem.1
      ext
      · rfl
      · simp; rw [show n / x.1 = x.2 from by
          rw [← hab]; exact Nat.mul_div_cancel_left x.2 (by
            rcases x with ⟨a, b⟩; simp at hab ⊢
            exact Nat.pos_of_ne_zero (by intro h; simp [h] at hab; omega))]
    · intro d _; rfl
    · intro x _; rfl
  rw [← antidiag_to_div]; exact h2

-- Weighted Möbius sum: only n=1 survives
lemma moebius_weighted_sum (h : ℕ → ℝ) (M : ℕ) (hM : 0 < M) :
    ∑ n ∈ Finset.range M,
      (if n + 1 = 1 then (1 : ℝ) else 0) * h (n + 1) = h 1 := by
  simp only [show ∀ (n : ℕ), (n + 1 = 1) ↔ (n = 0) from fun n => by omega]
  simp only [ite_mul, one_mul, zero_mul]
  rw [Finset.sum_ite_eq' (Finset.range M) 0 (fun n => h (n + 1))]
  simp [hM]
