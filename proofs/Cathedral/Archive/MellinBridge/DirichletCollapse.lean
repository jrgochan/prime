/-
  Cathedral/MellinBridge/DirichletCollapse.lean

  ## The Dirichlet Collapse: Möbius Inversion Identities

  Proves the fundamental Möbius inversion identity used throughout
  the Cathedral's number-theoretic foundations.

  ### Key results (PROVED):
  - sum_moebius_eq_indicator: Σ_{d|n} μ(d) = [n=1]
  - divisor_sum_swap: Σ_k f(k)·(n/k) = Σ_m Σ_{d|m} f(d) (finite Fubini)
  - dirichlet_moebius_sum: Σ_{k=1}^n μ(k)⌊n/k⌋ = 1

  ### Note on L² bounds:
  The Theorist's Transmission (April 16, 2026) established that L²
  convergence of the Nyman-Beurling approximant arises entirely from
  oscillatory cancellation in the Möbius sum. This cancellation cannot
  be captured by real-variable pointwise bounds and fundamentally
  requires the Mellin-Plancherel isometry (axiomatized in AbelSiegeProof.lean).
-/

import Mathlib.NumberTheory.ArithmeticFunction.Moebius
import Mathlib.NumberTheory.ArithmeticFunction.Zeta

noncomputable section
open Finset BigOperators ArithmeticFunction
open scoped ArithmeticFunction.Moebius

-- ════════════════════════════════════════════════
-- PART 1: POINT-WISE MÖBIUS INVERSION (PROVED!)
-- ════════════════════════════════════════════════

/-- **PROVED**: Σ_{d | n} μ(d) = [n = 1].
    Direct from Mathlib's `moebius_mul_coe_zeta`. -/
theorem sum_moebius_eq_indicator (n : ℕ) :
    (n.divisors.sum fun d => (μ d : ℤ)) = if n = 1 then 1 else 0 := by
  -- Σ_{d|n} μ(d) = (μ * ζ)(n) = 1(n) = [n=1]
  rw [← coe_mul_zeta_apply (f := μ)]
  rw [moebius_mul_coe_zeta]
  rfl

-- ════════════════════════════════════════════════
-- PART 2: THE FINITE FUBINI SWAP
-- ════════════════════════════════════════════════

/-- Helper: #{m ∈ [1,n] : k∣m} = ⌊n/k⌋. The multiples of k in [1,n]
    biject with [1,⌊n/k⌋] via j ↦ j·k. -/
private lemma card_Icc_filter_dvd (k n : ℕ) (hk : 1 ≤ k) :
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
      have hj0 : j ≠ 0 := by intro h; subst h; simp at hm1
      refine ⟨j, ⟨by omega, ?_⟩, mul_comm j k⟩
      rw [Nat.le_div_iff_mul_le hk]; linarith
    · rintro ⟨j, ⟨hj1, hjn⟩, rfl⟩
      refine ⟨⟨?_, ?_⟩, dvd_mul_left k j⟩
      · nlinarith [Nat.pos_of_ne_zero (by omega : j ≠ 0)]
      · have := Nat.div_mul_le_self n k; nlinarith
  rw [h_eq, Finset.card_map]; simp

/-- Helper: {d ∈ [1,n] : d∣m} = m.divisors when m ∈ [1,n]. -/
private lemma filter_dvd_eq_divisors {m n : ℕ} (hm1 : 1 ≤ m) (hmn : m ≤ n) :
    (Finset.Icc 1 n).filter (· ∣ m) = m.divisors := by
  apply Finset.ext; intro d
  simp only [Finset.mem_filter, Finset.mem_Icc, Nat.mem_divisors]
  constructor
  · rintro ⟨⟨_, _⟩, hdm⟩; exact ⟨hdm, by omega⟩
  · rintro ⟨hdm, hm_ne⟩
    exact ⟨⟨Nat.pos_of_dvd_of_pos hdm (by omega),
            (Nat.le_of_dvd (by omega) hdm).trans hmn⟩, hdm⟩

/-- **PROVED**: The finite Fubini swap:
    Σ_{k=1}^n f(k)·⌊n/k⌋ = Σ_{m=1}^n (Σ_{d|m} f(d))

    Both sides count the same pairs: (k,j) with 1≤k≤n, 1≤j≤n/k
    bijects with (d,m) with 1≤m≤n, d|m, via (k,j) ↦ (k, j·k). -/
theorem divisor_sum_swap (f : ℕ → ℤ) (n : ℕ) :
    (Finset.Icc 1 n).sum (fun k => f k * (n / k : ℕ)) =
    (Finset.Icc 1 n).sum (fun m => m.divisors.sum (fun d => f d)) := by
  -- Step 1: Rewrite f(k)*(n/k) as conditional sum Σ_{m∈[1,n]} [k∣m]·f(k)
  have step1 : ∀ k ∈ Finset.Icc 1 n,
      f k * (↑(n / k) : ℤ) = (Finset.Icc 1 n).sum (fun m => if k ∣ m then f k else 0) := by
    intro k hk
    have hk1 : 1 ≤ k := by simp only [Finset.mem_Icc] at hk; omega
    rw [← Finset.sum_filter, Finset.sum_const, nsmul_eq_mul, mul_comm (f k)]
    congr 1; exact_mod_cast (card_Icc_filter_dvd k n hk1).symm
  -- Step 2: Swap sums: Σ_k Σ_m [k∣m]·f(k) = Σ_m Σ_k [k∣m]·f(k)
  rw [Finset.sum_congr rfl step1, Finset.sum_comm]
  -- Step 3: Inner sum Σ_{k∈[1,n]} [k∣m]·f(k) = Σ_{d|m} f(d)
  apply Finset.sum_congr rfl
  intro m hm
  have hm1 : 1 ≤ m := by simp only [Finset.mem_Icc] at hm; omega
  have hmn : m ≤ n := by simp only [Finset.mem_Icc] at hm; omega
  rw [← Finset.sum_filter, filter_dvd_eq_divisors hm1 hmn]

-- ════════════════════════════════════════════════
-- PART 3: THE DIRICHLET HYPERBOLA IDENTITY
-- ════════════════════════════════════════════════

/-- **PROVED** (modulo `divisor_sum_swap`):
    The Dirichlet hyperbola identity: Σ_{k=1}^n μ(k)·⌊n/k⌋ = 1.

    Composes `divisor_sum_swap` with `sum_moebius_eq_indicator` to
    collapse the double sum to a single indicator evaluation. -/
theorem dirichlet_moebius_sum (n : ℕ) (hn : 1 ≤ n) :
    (Finset.Icc 1 n).sum (fun k => (μ k : ℤ) * (n / k : ℕ)) = 1 := by
  rw [divisor_sum_swap]
  conv_lhs => arg 2; ext m; rw [sum_moebius_eq_indicator]
  simp only [Finset.sum_ite_eq', show 1 ∈ Finset.Icc 1 n from Finset.mem_Icc.mpr ⟨le_refl 1, hn⟩,
    if_true]

end
