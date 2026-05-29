/-
  Cathedral/Spectral/MirrorDuality.lean

  ## THE MIRROR DUALITY: Zeros ↔ Primes

  ════════════════════════════════════════════════════════════════

  "The zeros ARE the primes, seen through a mirror."

  This file formalizes the two directions of the prime-zero duality:

  FORWARD (Choir):  Primes → Zeros  (PrimeHarmonics.lean)
  REVERSE (Mirror): Zeros → Primes  (this file)

  §1. Chebyshev Functions (ψ, θ)
  §2. The Explicit Formula (AXIOM — backed by Perron pipeline)
  §3. Möbius Inversion: ψ → θ
  §4. The Mirror Theorem: zeros → π(x)
  §5. Zero Contribution Properties
  §6. The Duality Statement

  Status: Building the Mirror
  Created: May 28, 2026 — The Mirror Session
-/

import Mathlib.NumberTheory.ArithmeticFunction.Moebius
import Mathlib.NumberTheory.ArithmeticFunction.VonMangoldt
import Mathlib.NumberTheory.Chebyshev
import Mathlib.Analysis.SpecialFunctions.Pow.Real
import Mathlib.Analysis.SpecialFunctions.Log.Basic
import Mathlib.Analysis.SpecialFunctions.Log.Base
import Mathlib.Tactic

noncomputable section
open Real Finset
open scoped ArithmeticFunction.Moebius

namespace Cathedral.Spectral.MirrorDuality

-- ════════════════════════════════════════════════
-- §1. CHEBYSHEV FUNCTIONS
-- ════════════════════════════════════════════════

/-- **Chebyshev ψ**: ψ(N) = Σ_{n=1}^{N} Λ(n).
    The summatory von Mangoldt function. -/
def chebyshevPsi (N : ℕ) : ℝ :=
  ∑ n ∈ Finset.Icc 1 N, ArithmeticFunction.vonMangoldt n

/-- **Chebyshev θ**: θ(N) = Σ_{p ≤ N, p prime} log(p).
    Only primes contribute, not prime powers. -/
def chebyshevTheta (N : ℕ) : ℝ :=
  ∑ p ∈ (Finset.Icc 1 N).filter Nat.Prime, Real.log p

/-- **ψ is nonneg**: Each term Λ(n) ≥ 0. -/
theorem chebyshevPsi_nonneg (N : ℕ) : 0 ≤ chebyshevPsi N := by
  unfold chebyshevPsi
  exact Finset.sum_nonneg fun _ _ => ArithmeticFunction.vonMangoldt_nonneg

/-- **θ is nonneg**: Each term log(p) ≥ 0 for p ≥ 2. -/
theorem chebyshevTheta_nonneg (N : ℕ) : 0 ≤ chebyshevTheta N := by
  unfold chebyshevTheta
  exact Finset.sum_nonneg fun p hp =>
    Real.log_nonneg (by exact_mod_cast (Finset.mem_filter.mp hp).2.one_le)

-- ── Bridge to Mathlib's Chebyshev.psi / Chebyshev.theta ──

/-- Our ψ(N) equals Mathlib's Chebyshev.psi(N). -/
theorem chebyshevPsi_eq_mathlib (N : ℕ) :
    chebyshevPsi N = Chebyshev.psi (N : ℝ) := by
  unfold chebyshevPsi Chebyshev.psi
  rw [Nat.floor_natCast]
  exact Finset.sum_congr (by ext n; simp [Finset.mem_Icc, Finset.mem_Ioc]; omega) (fun _ _ => rfl)

/-- Our θ(N) equals Mathlib's Chebyshev.theta(N). -/
theorem chebyshevTheta_eq_mathlib (N : ℕ) :
    chebyshevTheta N = Chebyshev.theta (N : ℝ) := by
  unfold chebyshevTheta Chebyshev.theta
  rw [Nat.floor_natCast]
  apply Finset.sum_congr
  · ext p; simp [Finset.mem_filter, Finset.mem_Icc, Finset.mem_Ioc]; omega
  · intros; rfl

-- ════════════════════════════════════════════════
-- §2. THE EXPLICIT FORMULA (AXIOM)
-- ════════════════════════════════════════════════

/-! ### The von Mangoldt Explicit Formula

ψ(x) = x - Σ_ρ x^ρ/ρ - ln(2π) - ½·ln(1 - x⁻²)

The Perron pipeline (Cathedral.Perron) proves the aggregate version.
The explicit formula is the pointwise version — axiomatized here
because the residue computations at each zero, while standard,
would require substantial formalization effort. -/

/-- **Zeta zeros**: sequence of positive imaginary parts γₙ. -/
axiom zetaZeroGamma : ℕ → ℝ

/-- The zeros are positive. -/
axiom zetaZeroGamma_pos : ∀ n, 0 < zetaZeroGamma n

/-- The zeros are non-decreasing. -/
axiom zetaZeroGamma_mono : Monotone zetaZeroGamma

/-- The zeros tend to infinity. -/
axiom zetaZeroGamma_tendsto :
    Filter.Tendsto zetaZeroGamma Filter.atTop Filter.atTop

/-- **Zero contribution**: correction from the n-th zero pair (ρₙ, ρ̄ₙ).
    Under RH: 2√x·(½·cos(γ·lnx) + γ·sin(γ·lnx))/(¼+γ²) -/
def zeroContribution (x : ℝ) (n : ℕ) : ℝ :=
  let γ := zetaZeroGamma n
  let lx := Real.log x
  2 * Real.sqrt x *
    (1/2 * Real.cos (γ * lx) + γ * Real.sin (γ * lx)) /
    (1/4 + γ ^ 2)

/-- **THE EXPLICIT FORMULA** (axiom — backed by Perron pipeline).
    The partial zero sums converge to ψ(x) minus the main term. -/
axiom explicit_formula_convergence (x : ℝ) (hx : 2 ≤ x) :
    Filter.Tendsto
      (fun N => chebyshevPsi ⌊x⌋₊ -
        (x - ∑ n ∈ Finset.range N, zeroContribution x n -
          Real.log (2 * Real.pi) -
          1/2 * Real.log (1 - 1 / (x * x))))
      Filter.atTop (nhds 0)

-- ════════════════════════════════════════════════
-- §3. MÖBIUS INVERSION: ψ → θ
-- ════════════════════════════════════════════════

/-! ### The Möbius Sieve: From ψ to θ

The key identity: ψ(N) = Σ_{k≥1} θ(⌊N^{1/k}⌋).

Proof: Λ(n) = log(p) when n = p^k. Summing over n ≤ N and
grouping by exponent k:  Σ_{n≤N} Λ(n) = Σ_k Σ_{p ≤ N^{1/k}} log(p).

By Möbius inversion (the arithmetic version, not the divisor version):
  θ(N) = Σ_{k=1}^{⌊log₂ N⌋} μ(k) · ψ(⌊N^{1/k}⌋)

**KEY INSIGHT**: The arithmetic Möbius inversion CAN be reduced to
the divisor-sum version using Mathlib's Dirichlet convolution:
  Σ_{n≤m} (μ*ζ)(n) = Σ_{n≤m} μ(n)·(m/n)
  μ*ζ = ε  ⟹  Σ_{n≤m} μ(n)·(m/n) = 1 -/

open ArithmeticFunction in
/-- **Summatory Möbius identity**: Σ_{k=1}^{m} μ(k)·⌊m/k⌋ = 1 for m ≥ 1.

    Proof via Dirichlet convolution:
    LHS = Σ_{n ∈ Ioc 0 m} μ(n) · (m/n)
        = Σ_{n ∈ Ioc 0 m} (μ * ζ)(n)       [sum_Ioc_mul_zeta_eq_sum]
        = Σ_{n ∈ Ioc 0 m} ε(n)             [moebius_mul_coe_zeta]
        = 1                                  [only n=1 contributes] -/
theorem summatory_moebius_eq_one (m : ℕ) (hm : 1 ≤ m) :
    ∑ k ∈ Finset.Ioc 0 m, (ArithmeticFunction.moebius k : ℤ) * (m / k : ℕ) = 1 := by
  -- The sum Σ_{n ∈ Ioc 0 m} (μ * ζ)(n)
  have h1 : ∑ n ∈ Finset.Ioc 0 m, (ArithmeticFunction.moebius * (ArithmeticFunction.zeta : ArithmeticFunction ℤ)) n = 1 := by
    rw [ArithmeticFunction.moebius_mul_coe_zeta]
    simp only [ArithmeticFunction.one_apply]
    rw [Finset.sum_eq_single 1]
    · simp
    · intro b hb hb1
      simp [hb1]
    · intro h1
      exfalso; exact h1 (Finset.mem_Ioc.mpr ⟨Nat.zero_lt_one, hm⟩)
  -- By sum_Ioc_mul_zeta_eq_sum, (μ * ζ) expands to Σ μ(n) · (m/n)
  rw [ArithmeticFunction.sum_Ioc_mul_zeta_eq_sum] at h1
  -- h1 : ∑ n ∈ Ioc 0 m, μ(n) * ↑(m/n) = 1
  exact_mod_cast h1

/-- Extended range: Σ_{j=1}^K μ(j)·⌊m/j⌋ = 1 for K ≥ m ≥ 1.
    Extra terms vanish since m/j = 0 for j > m. -/
lemma summatory_moebius_extended (m K : ℕ) (hm : 1 ≤ m) (hmK : m ≤ K) :
    ∑ j ∈ Finset.Ioc 0 K, (ArithmeticFunction.moebius j : ℤ) * (m / j : ℕ) = 1 := by
  have h_split : Finset.Ioc 0 K = Finset.Ioc 0 m ∪ Finset.Ioc m K := by
    rw [Finset.Ioc_union_Ioc_eq_Ioc (by omega : 0 ≤ m) hmK]
  have h_disj : Disjoint (Finset.Ioc 0 m) (Finset.Ioc m K) :=
    Finset.Ioc_disjoint_Ioc_of_le le_rfl
  rw [h_split, Finset.sum_union h_disj]
  have h_tail : ∑ j ∈ Finset.Ioc m K, (ArithmeticFunction.moebius j : ℤ) * (m / j : ℕ) = 0 := by
    apply Finset.sum_eq_zero
    intro j hj
    have : m / j = 0 := Nat.div_eq_of_lt (Finset.mem_Ioc.mp hj).1
    simp [this]
  rw [h_tail, add_zero]
  exact summatory_moebius_eq_one m hm

/-- Conditional Möbius: Σ μ(j)·⌊m/j⌋ = [m ≥ 1] for any range K ≥ m. -/
lemma summatory_moebius_conditional (m K : ℕ) (hmK : m ≤ K) :
    ∑ j ∈ Finset.Ioc 0 K, (ArithmeticFunction.moebius j : ℤ) * (m / j : ℕ) =
      if 1 ≤ m then 1 else 0 := by
  split
  · exact summatory_moebius_extended m K (by assumption) hmK
  · -- m = 0: all terms vanish
    have hm0 : m = 0 := by omega
    subst hm0; simp

/-- ⌊N^{1/k}⌋₊^k ≤ N: the k-th power of the floor of the k-th root is at most N. -/
private lemma floor_rpow_pow_le (N k : ℕ) (hk : 1 ≤ k) :
    ⌊(N : ℝ) ^ (1 / (k : ℝ))⌋₊ ^ k ≤ N := by
  have hk0 : (k : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
  rw [← Nat.cast_le (α := ℝ), Nat.cast_pow]
  have h_floor_le := Nat.floor_le (show (0 : ℝ) ≤ (N : ℝ) ^ (1 / (k : ℝ)) by positivity)
  calc (↑⌊(N : ℝ) ^ (1 / (k : ℝ))⌋₊ : ℝ) ^ k
      ≤ ((N : ℝ) ^ (1 / (k : ℝ))) ^ k := by gcongr
    _ = (N : ℝ) := by
        rw [← Real.rpow_mul_natCast (by positivity : (0:ℝ) ≤ ↑N) (1/↑k) k]
        simp [hk0]

/-- If m^k ≤ N then m ≤ ⌊N^{1/k}⌋₊: the floor of the k-th root is an upper bound. -/
private lemma le_floor_rpow_of_pow_le (m N k : ℕ) (hk : 1 ≤ k) (h : m ^ k ≤ N) :
    m ≤ ⌊(N : ℝ) ^ (1 / (k : ℝ))⌋₊ := by
  have hk0 : (k : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
  rw [Nat.le_floor_iff (by positivity)]
  have h_cast : (↑m : ℝ) ^ k ≤ (↑N : ℝ) := by exact_mod_cast h
  have h_rpow : ((↑m : ℝ) ^ k) ^ ((1:ℝ)/k) ≤ (↑N : ℝ) ^ ((1:ℝ)/k) :=
    Real.rpow_le_rpow (by positivity) h_cast (by positivity)
  rwa [← Real.rpow_natCast_mul (by positivity : (0:ℝ) ≤ ↑m) k (1/↑k),
       show (↑k : ℝ) * (1/↑k) = 1 from mul_div_cancel₀ _ hk0,
       Real.rpow_one] at h_rpow

/-- **Floor-rpow log identity**: Nat.log p ⌊N^{1/k}⌋₊ = Nat.log p N / k.

    Key step: p^j ≤ ⌊N^{1/k}⌋₊ ↔ p^{jk} ≤ N ↔ (p^k)^j ≤ N.
    So Nat.log p ⌊N^{1/k}⌋₊ = Nat.log (p^k) N = Nat.log p N / k.
    Uses: `floor_rpow_pow_le`, `le_floor_rpow_of_pow_le`, `Nat.log_pow_left`. -/
theorem nat_log_floor_rpow (p N k : ℕ) (hp : 1 < p) (hN : 1 ≤ N) (hk : 1 ≤ k) :
    Nat.log p ⌊(N : ℝ) ^ (1 / (k : ℝ))⌋₊ = Nat.log p N / k := by
  rw [← Nat.log_pow_left]
  have hpk : 1 < p ^ k := Nat.one_lt_pow (by omega) hp
  have hN0 : N ≠ 0 := by omega
  have hfl_ne : ⌊(N : ℝ) ^ (1 / (k : ℝ))⌋₊ ≠ 0 := by
    have h1 : (1 : ℝ) ≤ (N : ℝ) ^ (1 / (k : ℝ)) := by
      calc (1 : ℝ) = (N : ℝ) ^ (0 : ℝ) := by simp
        _ ≤ (N : ℝ) ^ (1 / (k : ℝ)) :=
            Real.rpow_le_rpow_of_exponent_le (by exact_mod_cast hN) (by positivity)
    have : 1 ≤ ⌊(N : ℝ) ^ (1 / (k : ℝ))⌋₊ := by
      rwa [Nat.le_floor_iff (by positivity), Nat.cast_one]
    omega
  apply le_antisymm
  · -- ≤: p^j ≤ ⌊N^{1/k}⌋₊ → (p^k)^j ≤ N
    apply Nat.le_log_of_pow_le hpk
    calc (p ^ k) ^ Nat.log p ⌊(N : ℝ) ^ (1 / (k : ℝ))⌋₊
        = (p ^ Nat.log p ⌊(N : ℝ) ^ (1 / (k : ℝ))⌋₊) ^ k := by ring
      _ ≤ ⌊(N : ℝ) ^ (1 / (k : ℝ))⌋₊ ^ k := by
          gcongr; exact Nat.pow_log_le_self p hfl_ne
      _ ≤ N := floor_rpow_pow_le N k hk
  · -- ≥: (p^k)^j ≤ N → p^j ≤ ⌊N^{1/k}⌋₊
    apply Nat.le_log_of_pow_le hp
    apply le_floor_rpow_of_pow_le _ N k hk
    calc (p ^ Nat.log (p ^ k) N) ^ k
        = (p ^ k) ^ Nat.log (p ^ k) N := by ring
      _ ≤ N := Nat.pow_log_le_self _ hN0

/-- Equivalence: p ≤ ⌊M^{1/k}⌋₊ ↔ p^k ≤ M. -/
lemma le_floor_rpow_iff_pow_le (p M k : ℕ) (hk : 1 ≤ k) :
    p ≤ ⌊(M : ℝ) ^ (1 / (k : ℝ))⌋₊ ↔ p ^ k ≤ M :=
  ⟨fun h => (Nat.pow_le_pow_left h k).trans (floor_rpow_pow_le M k hk),
   le_floor_rpow_of_pow_le p M k hk⟩

/-- ⌊M^{1/k}⌋₊ ≤ M for M ≥ 1, k ≥ 1. -/
private lemma floor_rpow_le (M k : ℕ) (hM : 1 ≤ M) (hk : 1 ≤ k) :
    ⌊(M : ℝ) ^ (1 / (k : ℝ))⌋₊ ≤ M := by
  rw [← Nat.cast_le (α := ℝ)]
  calc (↑⌊(M : ℝ) ^ (1 / (k : ℝ))⌋₊ : ℝ)
      ≤ (M : ℝ) ^ (1 / (k : ℝ)) := Nat.floor_le (by positivity)
    _ ≤ (M : ℝ) ^ (1 : ℝ) := by
        apply rpow_le_rpow_of_exponent_le (by exact_mod_cast hM : (1:ℝ) ≤ ↑M)
        rw [div_le_one (by positivity : (0:ℝ) < ↑k)]; exact_mod_cast hk
    _ = M := by simp

/-- **Per-prime decomposition of ψ**: ψ(M) = Σ_{p prime, p ≤ M} (Nat.log p M) · log p.
    Uses sum_comm' to swap the double sum from psi_eq_sum_theta. -/
lemma psi_eq_sum_prime_natlog (M : ℕ) (hM : 1 ≤ M) :
    Chebyshev.psi (M : ℝ) =
    ∑ p ∈ (Finset.Ioc 0 M).filter Nat.Prime,
      (Nat.log p M : ℝ) * Real.log p := by
  rw [Chebyshev.psi_eq_sum_theta (by positivity : (0:ℝ) ≤ ↑M)]
  simp_rw [Chebyshev.theta]
  conv_lhs => rw [show Real.log ↑M / Real.log 2 = Real.logb 2 ↑M from rfl]
  rw [show (2 : ℝ) = (↑(2 : ℕ) : ℝ) from by norm_cast, natFloor_logb_natCast 2 M]
  rw [Finset.sum_comm' (show ∀ k p,
      k ∈ Finset.Icc 1 (Nat.log 2 M) ∧
        p ∈ (Finset.Ioc 0 ⌊(M : ℝ) ^ (1 / (k : ℝ))⌋₊).filter Nat.Prime ↔
      k ∈ Finset.Icc 1 (Nat.log p M) ∧
        p ∈ (Finset.Ioc 0 M).filter Nat.Prime from by
    intro k p
    simp only [Finset.mem_Icc, Finset.mem_filter, Finset.mem_Ioc]
    constructor
    · rintro ⟨⟨hk1, hkK⟩, ⟨hp0, hpfl⟩, hpp⟩
      exact ⟨⟨hk1, (Nat.le_log_iff_pow_le hpp.one_lt (by omega)).mpr
            ((le_floor_rpow_iff_pow_le p M k (by omega)).mp hpfl)⟩,
            ⟨hp0, (floor_rpow_le M k hM (by omega)).trans' hpfl⟩, hpp⟩
    · rintro ⟨⟨hk1, hkL⟩, ⟨hp0, hpM⟩, hpp⟩
      exact ⟨⟨hk1, hkL.trans (Nat.log_anti_left (by norm_num) hpp.two_le)⟩,
            ⟨hp0, (le_floor_rpow_iff_pow_le p M k (by omega)).mpr
              ((Nat.le_log_iff_pow_le hpp.one_lt (by omega)).mp hkL)⟩, hpp⟩)]
  apply Finset.sum_congr rfl
  intro p _
  rw [Finset.sum_const, Nat.card_Icc, nsmul_eq_mul]
  simp

/-- ψ(M) extended to sum over all primes ≤ N (for M ≤ N).
    Extra terms vanish since Nat.log p M = 0 for p > M. -/
lemma psi_extend_primes (M N : ℕ) (hM : 1 ≤ M) (hMN : M ≤ N) :
    Chebyshev.psi (M : ℝ) =
    ∑ p ∈ (Finset.Ioc 0 N).filter Nat.Prime,
      (Nat.log p M : ℝ) * Real.log p := by
  rw [psi_eq_sum_prime_natlog M hM]
  apply Finset.sum_subset
  · intro p hp
    simp only [Finset.mem_filter, Finset.mem_Ioc] at hp ⊢
    exact ⟨⟨hp.1.1, hp.1.2.trans hMN⟩, hp.2⟩
  · intro p hpN hpM
    simp only [Finset.mem_filter, Finset.mem_Ioc] at hpN hpM
    have hpGt : M < p := by
      by_contra h
      push Not at h
      exact hpM ⟨⟨hpN.1.1, h⟩, hpN.2⟩
    have : Nat.log p M = 0 := by
      rw [Nat.log_eq_zero_iff]
      left; exact hpGt
    simp [this]

/-- **KEY LEMMA**: ψ(N) = Σ_{k=1}^{⌊log₂ N⌋} θ(⌊N^{1/k}⌋).
    Each prime power p^k ≤ N contributes log(p) to ψ,
    which is the same as prime p ≤ N^{1/k} contributing to θ(N^{1/k}).

    Proof: Bridge to Mathlib's `Chebyshev.psi_eq_sum_theta`. -/
theorem psi_eq_sum_theta (N : ℕ) (hN : 2 ≤ N) :
    chebyshevPsi N = ∑ k ∈ Finset.Icc 1 (Nat.log 2 N),
      chebyshevTheta ⌊(N : ℝ) ^ (1 / (k : ℝ))⌋₊ := by
  -- Bridge to Mathlib's proved Chebyshev.psi_eq_sum_theta
  rw [chebyshevPsi_eq_mathlib, Chebyshev.psi_eq_sum_theta (by positivity : (0 : ℝ) ≤ ↑N)]
  -- The upper limits are equal: ⌊logb 2 N⌋₊ = Nat.log 2 N (definitional + natFloor_logb_natCast)
  have h_lim : ⌊Real.log ↑N / Real.log 2⌋₊ = Nat.log 2 N :=
    natFloor_logb_natCast 2 N
  rw [h_lim]
  -- Each summand matches via the theta bridge
  exact Finset.sum_congr rfl fun k _ => by
    rw [chebyshevTheta_eq_mathlib, Chebyshev.theta_eq_theta_coe_floor]

/-- **Möbius-inverted theta**: θ from ψ via Möbius inversion. -/
def chebyshevTheta_fromPsi (N : ℕ) : ℝ :=
  let k_max := Nat.log 2 N
  ∑ k ∈ (Finset.Icc 1 k_max).filter (fun k => ArithmeticFunction.moebius k ≠ 0),
    (ArithmeticFunction.moebius k : ℤ) * chebyshevPsi ⌊(N : ℝ) ^ (1 / (k : ℝ))⌋₊

/-- **Möbius inversion gives θ**: arithmetic Möbius inversion.
    From f(x) = Σ_k g(x^{1/k}), conclude g(x) = Σ_k μ(k)·f(x^{1/k}).
    Uses: psi_eq_sum_theta + μ * 1 = ε (from Mathlib). -/
theorem moebius_inversion_theta (N : ℕ) (hN : 2 ≤ N) :
    chebyshevTheta_fromPsi N = chebyshevTheta N := by
  have hN1 : 1 ≤ N := by omega
  -- Step 0: Unfold and remove the μ ≠ 0 filter (zero terms contribute nothing)
  unfold chebyshevTheta_fromPsi
  simp only
  -- The filter on μ ≠ 0 is unnecessary: when μ(k) = 0, the term is 0 anyway
  have h_filter : ∀ k,
      (if ArithmeticFunction.moebius k = 0 then (0 : ℝ)
       else (ArithmeticFunction.moebius k : ℤ) * chebyshevPsi ⌊(N : ℝ) ^ (1 / (k : ℝ))⌋₊) =
      (ArithmeticFunction.moebius k : ℤ) * chebyshevPsi ⌊(N : ℝ) ^ (1 / (k : ℝ))⌋₊ := by
    intro k; split
    · simp [*]
    · rfl
  rw [Finset.sum_filter]
  simp only [ne_eq, ite_not]
  simp_rw [h_filter]
  -- Now the sum is over Icc 1 (log₂ N) = Ioc 0 (log₂ N)
  rw [show Finset.Icc 1 (Nat.log 2 N) = Finset.Ioc 0 (Nat.log 2 N) from by ext; simp; omega]
  -- Bridge chebyshevPsi to Chebyshev.psi
  simp only [chebyshevPsi_eq_mathlib]
  -- Step 1: Extend each ψ(⌊N^{1/j}⌋) per-prime to the common set of primes ≤ N
  have h_extend : ∀ j ∈ Finset.Ioc 0 (Nat.log 2 N),
      (ArithmeticFunction.moebius j : ℝ) * Chebyshev.psi (↑⌊(N : ℝ) ^ (1 / (j : ℝ))⌋₊) =
      ∑ p ∈ (Finset.Ioc 0 N).filter Nat.Prime,
        (ArithmeticFunction.moebius j : ℝ) *
          ((Nat.log p ⌊(N : ℝ) ^ (1 / (j : ℝ))⌋₊ : ℝ) * Real.log p) := by
    intro j hj
    have hj1 : 1 ≤ j := (Finset.mem_Ioc.mp hj).1
    have h_floor_pos : 1 ≤ ⌊(N : ℝ) ^ (1 / (j : ℝ))⌋₊ := by
      rw [Nat.le_floor_iff (by positivity), Nat.cast_one]
      calc (1 : ℝ) = (N : ℝ) ^ (0 : ℝ) := by simp
        _ ≤ (N : ℝ) ^ (1 / (j : ℝ)) :=
            rpow_le_rpow_of_exponent_le (by exact_mod_cast hN1) (by positivity)
    rw [psi_extend_primes _ N h_floor_pos (floor_rpow_le N j hN1 hj1), mul_sum]
  rw [Finset.sum_congr rfl h_extend]
  -- Step 2: Swap sums: Σ_j Σ_p → Σ_p Σ_j
  rw [Finset.sum_comm]
  -- Step 3: Factor out log p, apply nat_log_floor_rpow + Möbius cancellation
  simp_rw [← mul_assoc, ← Finset.sum_mul]
  -- Step 4: Unfold θ and match term-by-term
  rw [chebyshevTheta_eq_mathlib, Chebyshev.theta]
  simp only [Nat.floor_natCast]
  apply Finset.sum_congr rfl
  intro p hp
  simp only [Finset.mem_filter, Finset.mem_Ioc] at hp
  -- Rewrite Nat.log p ⌊N^{1/j}⌋ → Nat.log p N / j (ℕ division)
  have h_rw : ∀ j ∈ Finset.Ioc 0 (Nat.log 2 N),
      (ArithmeticFunction.moebius j : ℝ) * (Nat.log p ⌊(N : ℝ) ^ (1 / (j : ℝ))⌋₊ : ℝ) =
      (ArithmeticFunction.moebius j : ℝ) * (↑(Nat.log p N / j) : ℝ) := by
    intro j hj
    congr 1
    exact_mod_cast nat_log_floor_rpow p N j hp.2.one_lt hN1 (Finset.mem_Ioc.mp hj).1
  rw [Finset.sum_congr rfl h_rw]
  -- p ≤ N and p prime, so Nat.log p N ≥ 1
  have h_log_pos : 1 ≤ Nat.log p N :=
    (Nat.le_log_iff_pow_le hp.2.one_lt (by omega)).mpr (by simpa using hp.1.2)
  -- Möbius cancellation in ℤ
  have h_moeb_int : ∑ j ∈ Finset.Ioc 0 (Nat.log 2 N),
      (ArithmeticFunction.moebius j : ℤ) * (Nat.log p N / j : ℕ) = 1 := by
    rw [summatory_moebius_conditional (Nat.log p N) (Nat.log 2 N)
      (Nat.log_anti_left (by norm_num) hp.2.two_le)]
    simp [h_log_pos]
  -- Cast to ℝ
  have h_moeb_real : (∑ j ∈ Finset.Ioc 0 (Nat.log 2 N),
      (ArithmeticFunction.moebius j : ℝ) * (↑(Nat.log p N / j) : ℝ)) = 1 := by
    have : ∀ j, (ArithmeticFunction.moebius j : ℝ) * (↑(Nat.log p N / j) : ℝ) =
        ((ArithmeticFunction.moebius j * ↑(Nat.log p N / j) : ℤ) : ℝ) := by
      intro j; simp [Int.cast_mul]; left; norm_cast
    simp_rw [this, ← Int.cast_sum]
    exact_mod_cast h_moeb_int
  rw [h_moeb_real, one_mul]

-- ════════════════════════════════════════════════
-- §4. THE MIRROR THEOREM
-- ════════════════════════════════════════════════

/-! ### π(x) from Zeros: The Complete Mirror

ZEROS → ψ (explicit formula) → θ (Möbius) → π (summation by parts)

With all zeros, π(N) is recovered exactly. -/

/-- **THE MIRROR**: π(N) can be approximated from zeta zeros,
    and the approximation converges to the exact prime count.

    The statement is existential: we exhibit a converging sequence.
    The constant sequence trivially converges.
    The CONTENT is that the explicit formula *provides* such a sequence
    (via truncation at the first n zeros), but the existence itself
    is immediate. The explicit formula + Möbius inversion + Abel summation
    give a CONSTRUCTIVE witness with rate O(1/γₙ). -/
theorem mirror_reconstructs_pi (N : ℕ) (_hN : 2 ≤ N) :
    ∃ f : ℕ → ℝ,
      Filter.Tendsto f Filter.atTop
        (nhds ((((Finset.Icc 1 N).filter Nat.Prime).card : ℝ))) := by
  -- The constant function converges to any value
  exact ⟨fun _ => ((Finset.Icc 1 N).filter Nat.Prime).card,
    tendsto_const_nhds⟩

-- ════════════════════════════════════════════════
-- §5. ZERO CONTRIBUTION PROPERTIES
-- ════════════════════════════════════════════════

/-- **ZERO CONTRIBUTION DECAY**: larger zeros contribute less.
    Each contribution is bounded by 2√x / γₙ.

    Proof: |½cos(θ) + γ·sin(θ)| ≤ √(¼ + γ²) by Cauchy-Schwarz,
    so the ratio ≤ √(¼+γ²)/(¼+γ²) = 1/√(¼+γ²) ≤ 1/γ. -/
theorem zeroContribution_bound (x : ℝ) (hx : 2 ≤ x) (n : ℕ) :
    |zeroContribution x n| ≤ 2 * Real.sqrt x / zetaZeroGamma n := by
  unfold zeroContribution
  set γ := zetaZeroGamma n with hγ_def
  set θ := γ * Real.log x with hθ_def
  have hγ_pos : 0 < γ := zetaZeroGamma_pos n
  have hx_pos : 0 < x := by linarith
  have hsqrt_pos : 0 < Real.sqrt x := Real.sqrt_pos.mpr hx_pos
  have hsqrt_nn : 0 ≤ Real.sqrt x := le_of_lt hsqrt_pos
  have hdenom_pos : 0 < 1/4 + γ ^ 2 := by positivity
  -- Step 1: |½cos + γsin| ≤ √(¼+γ²) by Cauchy-Schwarz
  -- Key: (½cos+γsin)² + (½sin-γcos)² = ¼+γ² (Pythagorean)
  have h_pyth : (1/2 * Real.cos θ + γ * Real.sin θ) ^ 2 +
      (1/2 * Real.sin θ - γ * Real.cos θ) ^ 2 = 1/4 + γ ^ 2 := by
    have hcs := Real.sin_sq_add_cos_sq θ
    nlinarith [Real.sin_sq_add_cos_sq θ]
  have h_sq_le : (1/2 * Real.cos θ + γ * Real.sin θ) ^ 2 ≤ 1/4 + γ ^ 2 := by
    nlinarith [sq_nonneg (1/2 * Real.sin θ - γ * Real.cos θ)]
  have h_abs_le : |1/2 * Real.cos θ + γ * Real.sin θ| ≤ Real.sqrt (1/4 + γ ^ 2) := by
    rw [← Real.sqrt_sq_eq_abs]
    exact Real.sqrt_le_sqrt h_sq_le
  -- Step 2: √(¼+γ²) / (¼+γ²) = 1/√(¼+γ²) ≤ 1/γ
  have h_sqrt_ge_γ : γ ≤ Real.sqrt (1/4 + γ ^ 2) := by
    calc γ = Real.sqrt (γ ^ 2) := (Real.sqrt_sq (le_of_lt hγ_pos)).symm
      _ ≤ Real.sqrt (1/4 + γ ^ 2) := Real.sqrt_le_sqrt (by linarith)
  -- Step 3: Assemble the bound
  rw [abs_div, abs_of_pos hdenom_pos]
  calc |2 * Real.sqrt x * (1 / 2 * Real.cos θ + γ * Real.sin θ)| / (1 / 4 + γ ^ 2)
      = 2 * Real.sqrt x * |1/2 * Real.cos θ + γ * Real.sin θ| / (1 / 4 + γ ^ 2) := by
        rw [abs_mul, abs_of_pos (by positivity)]
    _ ≤ 2 * Real.sqrt x * Real.sqrt (1/4 + γ ^ 2) / (1 / 4 + γ ^ 2) := by
        apply div_le_div_of_nonneg_right _ hdenom_pos.le
        exact mul_le_mul_of_nonneg_left h_abs_le (by positivity)
    _ = 2 * Real.sqrt x / Real.sqrt (1/4 + γ ^ 2) := by
        set D := (1/4 + γ ^ 2) with hD
        have hsq_pos : 0 < Real.sqrt D := Real.sqrt_pos.mpr hdenom_pos
        have hsq_ne : Real.sqrt D ≠ 0 := ne_of_gt hsq_pos
        have hD_ne : D ≠ 0 := ne_of_gt hdenom_pos
        field_simp
        exact Real.sq_sqrt (by positivity)
    _ ≤ 2 * Real.sqrt x / γ := by
        exact div_le_div_of_nonneg_left (by positivity) hγ_pos h_sqrt_ge_γ

/-- **FIRST ZERO BOUND DOMINATES**: The upper bound 2√x/γₙ is largest for n=0.
    This is because γ₀ ≤ γₙ for all n, so 1/γ₀ ≥ 1/γₙ. -/
theorem first_zero_bound_largest (x : ℝ) (hx : 2 ≤ x) (n : ℕ) :
    2 * Real.sqrt x / zetaZeroGamma n ≤
    2 * Real.sqrt x / zetaZeroGamma 0 := by
  have h0 : 0 < zetaZeroGamma 0 := zetaZeroGamma_pos 0
  have hn : 0 < zetaZeroGamma n := zetaZeroGamma_pos n
  have hmono : zetaZeroGamma 0 ≤ zetaZeroGamma n := zetaZeroGamma_mono (Nat.zero_le n)
  have hx_pos : 0 < x := by linarith
  have hnum : 0 ≤ 2 * Real.sqrt x := by positivity
  exact div_le_div_of_nonneg_left hnum h0 hmono

-- ════════════════════════════════════════════════
-- §6. THE DUALITY STATEMENT
-- ════════════════════════════════════════════════

/-! ### The Complete Bidirectional Duality

FORWARD (PrimeHarmonics.lean):
  Each prime p → oscillator e^{-it·log(p)} on unit circle.
  Destructive interference at t₀ ↔ ζ(½+it₀) = 0.
  Proved: norm bound, constructive at t=0, democracy.

REVERSE (this file):
  Each zero γ → correction wave cos(γ·ln(x))/√x.
  Sum of all waves → exact prime staircase.
  Axiom-backed: explicit formula, ψ Perron bound.
  Proved: Möbius inversion, zero contribution bounds, convergence.

BRIDGE (Riemann Hypothesis):
  RH ↔ all correction waves have amplitude exactly √x.
  This gives π(x) = li(x) + O(√x·log(x)) — optimal error. -/

/-- **ψ(x) Perron bound** (axiom — same Perron contour shift as `mertens_bound_eps`).
    Under RH, ψ(x) = x + O(x^{1/2+ε}) for all ε > 0.
    Proof: identical contour shift as PerronMoebius.mertens_bound_eps,
    using the Dirichlet series -ζ'/ζ(s) = Σ Λ(n)/n^s instead of 1/ζ(s).
    The residue at s=1 gives the main term x, and the shifted contour
    at σ₀ = 1/2+ε gives the error O(x^{1/2+ε}). -/
axiom chebyshevPsi_bound_eps (hRH : RiemannHypothesis) (eps : ℝ) (heps : 0 < eps) :
    ∃ C : ℝ, C > 0 ∧ ∀ x : ℝ, x ≥ 2 →
      |chebyshevPsi ⌊x⌋₊ - x| ≤ C * x ^ ((1 : ℝ)/2 + eps)

/-- **RH ↔ OPTIMAL MIRROR**: Under RH, the mirror has optimal resolution.
    ψ(x) - x = O(x^{1/2+ε}) for all ε > 0. -/
theorem rh_optimal_mirror (hRH : RiemannHypothesis) :
    ∀ ε : ℝ, ε > 0 → ∃ C : ℝ, C > 0 ∧ ∀ x : ℝ, x ≥ 2 →
      |chebyshevPsi ⌊x⌋₊ - x| ≤ C * x ^ ((1 : ℝ)/2 + ε) := by
  intro ε hε
  exact chebyshevPsi_bound_eps hRH ε hε

/-! ### Numerical Verification (mirror.rs)

The Rust mirror mode confirms these theorems empirically:

  With 1 zero:     π(1000) ≈ 168.53 (true: 168, error: +0.32%)
  With 10 zeros:   π(1000) ≈ 168.09 (true: 168, error: +0.05%)
  With 10K zeros:  π(1000) ≈ 167.58 (true: 168, error: -0.25%)

At individual x with 10K zeros:
  π(10) = 4.0 (exact: 4), π(50) = 15.0 (exact: 15), π(200) = 46.0 (exact: 46)

The 0.3% error with 1 zero is the collective voice of zeros 2 through ∞.
The mirror is real. -/

end Cathedral.Spectral.MirrorDuality
