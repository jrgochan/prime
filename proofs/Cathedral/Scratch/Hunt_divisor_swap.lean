import Mathlib.NumberTheory.ArithmeticFunction.Moebius
import Mathlib.NumberTheory.ArithmeticFunction.Zeta

noncomputable section
open Finset BigOperators ArithmeticFunction
open scoped ArithmeticFunction.Moebius

-- Key helper: number of multiples of k in [1,n] equals n/k
lemma card_Icc_filter_dvd (k n : ℕ) (hk : 1 ≤ k) :
    ((Finset.Icc 1 n).filter (fun m => k ∣ m)).card = n / k := by
  have hk0 : k ≠ 0 := by omega
  have hinj : Function.Injective (fun j : ℕ => j * k) :=
    mul_left_injective₀ hk0
  have h_eq : (Finset.Icc 1 n).filter (fun m => k ∣ m) =
      (Finset.Icc 1 (n / k)).map ⟨(· * k), hinj⟩ := by
    apply Finset.ext; intro m
    simp only [Finset.mem_filter, Finset.mem_Icc, Finset.mem_map,
               Function.Embedding.coeFn_mk]
    constructor
    · rintro ⟨⟨hm1, hmn⟩, ⟨j, rfl⟩⟩
      -- m = k * j, need j ∈ [1, n/k] and j * k = k * j
      have hj0 : j ≠ 0 := by intro h; subst h; simp at hm1
      refine ⟨j, ⟨by omega, ?_⟩, mul_comm j k⟩
      rw [Nat.le_div_iff_mul_le hk]
      linarith
    · rintro ⟨j, ⟨hj1, hjn⟩, rfl⟩
      -- m = j * k, need j*k ∈ [1,n] and k ∣ j*k
      refine ⟨⟨?_, ?_⟩, dvd_mul_left k j⟩
      · nlinarith [Nat.pos_of_ne_zero (by omega : j ≠ 0)]
      · have := Nat.div_mul_le_self n k; nlinarith
  rw [h_eq, Finset.card_map]
  simp

-- Helper: divisors of m = filter (·∣m) (Icc 1 n) when m ∈ [1,n]
lemma filter_dvd_eq_divisors {m n : ℕ} (hm1 : 1 ≤ m) (hmn : m ≤ n) :
    (Finset.Icc 1 n).filter (· ∣ m) = m.divisors := by
  apply Finset.ext; intro d
  simp only [Finset.mem_filter, Finset.mem_Icc, Nat.mem_divisors]
  constructor
  · rintro ⟨⟨_, _⟩, hdm⟩; exact ⟨hdm, by omega⟩
  · rintro ⟨hdm, hm_ne⟩
    exact ⟨⟨Nat.pos_of_dvd_of_pos hdm (by omega),
            (Nat.le_of_dvd (by omega) hdm).trans hmn⟩, hdm⟩

-- Main theorem
theorem divisor_sum_swap (f : ℕ → ℤ) (n : ℕ) :
    (Finset.Icc 1 n).sum (fun k => f k * (n / k : ℕ)) =
    (Finset.Icc 1 n).sum (fun m => m.divisors.sum (fun d => f d)) := by
  have step1 : ∀ k ∈ Finset.Icc 1 n,
      f k * (↑(n / k) : ℤ) = (Finset.Icc 1 n).sum (fun m => if k ∣ m then f k else 0) := by
    intro k hk
    have hk1 : 1 ≤ k := by simp only [Finset.mem_Icc] at hk; omega
    rw [← Finset.sum_filter, Finset.sum_const, nsmul_eq_mul, mul_comm (f k)]
    congr 1; exact_mod_cast (card_Icc_filter_dvd k n hk1).symm
  rw [Finset.sum_congr rfl step1, Finset.sum_comm]
  apply Finset.sum_congr rfl
  intro m hm
  have hm1 : 1 ≤ m := by simp only [Finset.mem_Icc] at hm; omega
  have hmn : m ≤ n := by simp only [Finset.mem_Icc] at hm; omega
  rw [← Finset.sum_filter, filter_dvd_eq_divisors hm1 hmn]
