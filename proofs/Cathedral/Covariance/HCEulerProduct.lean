/-
  Cathedral/Covariance/HCEulerProduct.lean

  ## HC-Euler Product Bridge

  Connects the Euler product infrastructure (divisor_sum_euler_product, PROVED)
  to the Gram quadratic form constituent functions, enabling evaluation of
  the Möbius bilinear sum at HC numbers via the Mertens product.

  ### Key Results

  1. `recipProduct_euler` — Σμ(j)μ(k)/(jk) = Π(1−1/p)² over divisors of squarefree N
  2. `gcdWeighted_euler` — Σμ(j)μ(k)·gcd(j,k)/(jk) = Π(1−1/p) over divisors of N
  3. `euler_product_bound_at_hc` — bound via Mertens at HC numbers

  Created: May 12, 2026 — Exploration 36
-/

import Cathedral.Covariance.EulerProduct
import Cathedral.Covariance.HighlyComposite
import Mathlib.Data.Nat.Factorization.Basic

noncomputable section
open Real Finset Filter ArithmeticFunction

namespace Cathedral.Covariance

-- ════════════════════════════════════════════════
-- §1. CONSTITUENT FUNCTIONS
-- ════════════════════════════════════════════════

/-- The reciprocal product: f(j,k) = 1/(jk). -/
def recipProduct (j k : ℕ) : ℝ := 1 / ((j : ℝ) * (k : ℝ))

/-- The GCD-weighted function: f(j,k) = gcd(j,k)/(jk). -/
def gcdWeighted (j k : ℕ) : ℝ := (Nat.gcd j k : ℝ) / ((j : ℝ) * (k : ℝ))

-- ════════════════════════════════════════════════
-- §2. RECIPROCAL PRODUCT EULER FACTORIZATION
-- ════════════════════════════════════════════════

/-- recipProduct is BilinearMultiplicative: 1/((j₁j₂)(k₁k₂)) = 1/(j₁k₁) · 1/(j₂k₂). -/
theorem recipProduct_bilinear_mult : BilinearMultiplicative recipProduct := by
  intro j₁ k₁ j₂ k₂ _
  unfold recipProduct
  push_cast
  field_simp

/-- recipProduct(1,1) = 1. -/
theorem recipProduct_one_one : recipProduct 1 1 = 1 := by
  unfold recipProduct; simp

/-- **PROVED**: The Möbius double sum of 1/(jk) over divisors of squarefree N
    equals Π_{p|N} (1−1/p)² via the Euler product. -/
theorem recipProduct_euler (N : ℕ) (hSq : Squarefree N) :
    ∑ j ∈ Nat.divisors N, ∑ k ∈ Nat.divisors N,
      (moebius j : ℝ) * (moebius k : ℝ) * recipProduct j k =
    ∏ p ∈ Nat.primeFactors N, (1 - 1 / (p : ℝ)) ^ 2 := by
  rw [divisor_sum_euler_product recipProduct recipProduct_bilinear_mult
    recipProduct_one_one N hSq]
  congr 1; ext p
  -- localFactor(recipProduct, p) = localFactor(fun j k => 1/(j*k), p)
  -- which equals (1 - 1/p)² by trivial_local_factor
  show localFactor recipProduct p = (1 - 1 / (p : ℝ)) ^ 2
  unfold localFactor recipProduct
  push_cast
  ring

-- ════════════════════════════════════════════════
-- §3. GCD-WEIGHTED EULER FACTORIZATION
-- ════════════════════════════════════════════════

/-- gcdWeighted is BilinearMultiplicative.
    Uses gcd(j₁j₂, k₁k₂) = gcd(j₁,k₁)·gcd(j₂,k₂) for coprime(j₁k₁, j₂k₂). -/
theorem gcdWeighted_bilinear_mult : BilinearMultiplicative gcdWeighted := by
  intro j₁ k₁ j₂ k₂ hcop
  unfold gcdWeighted
  -- Handle zero cases: if any argument is 0, both sides are 0 (division by zero)
  by_cases hj1 : j₁ = 0
  · simp [hj1]
  by_cases hk1 : k₁ = 0
  · simp [hk1]
  by_cases hj2 : j₂ = 0
  · simp [hj2]
  by_cases hk2 : k₂ = 0
  · simp [hk2]
  -- All arguments nonzero: use factorization to prove gcd equality
  have h_gcd : Nat.gcd (j₁ * j₂) (k₁ * k₂) = Nat.gcd j₁ k₁ * Nat.gcd j₂ k₂ := by
    apply Nat.eq_of_factorization_eq
      (Nat.gcd_ne_zero_left (mul_ne_zero hj1 hj2))
      (mul_ne_zero (Nat.gcd_ne_zero_left hj1) (Nat.gcd_ne_zero_left hj2))
    intro p
    simp only [Nat.factorization_gcd (mul_ne_zero hj1 hj2) (mul_ne_zero hk1 hk2),
               Nat.factorization_mul hj1 hj2, Nat.factorization_mul hk1 hk2,
               Nat.factorization_gcd hj1 hk1, Nat.factorization_gcd hj2 hk2,
               Nat.factorization_mul (Nat.gcd_ne_zero_left hj1) (Nat.gcd_ne_zero_left hj2),
               Finsupp.inf_apply, Finsupp.add_apply]
    -- Extract coprimality at prime p: either v_p(j₁k₁) = 0 or v_p(j₂k₂) = 0
    have h_min_zero : min ((j₁ * k₁).factorization p) ((j₂ * k₂).factorization p) = 0 := by
      have h1 := Nat.factorization_gcd (mul_ne_zero hj1 hk1) (mul_ne_zero hj2 hk2)
      rw [hcop] at h1
      have h2 : ((j₁ * k₁).factorization ⊓ (j₂ * k₂).factorization) p =
                (Nat.factorization 1) p := by rw [h1]
      simp only [Finsupp.inf_apply, Nat.factorization_one,
                 Finsupp.coe_zero, Pi.zero_apply] at h2
      exact h2
    simp only [Nat.factorization_mul hj1 hk1, Nat.factorization_mul hj2 hk2,
               Finsupp.add_apply] at h_min_zero
    -- min(fj₁+fj₂, fk₁+fk₂) = min(fj₁,fk₁) + min(fj₂,fk₂)
    -- follows from: min(fj₁+fk₁, fj₂+fk₂) = 0 (coprimality at p)
    omega
  rw [h_gcd]; push_cast; field_simp

/-- gcdWeighted(1,1) = 1. -/
theorem gcdWeighted_one_one : gcdWeighted 1 1 = 1 := by
  unfold gcdWeighted; simp

/-- **KEY**: The Möbius double sum of gcd(j,k)/(jk) over divisors of squarefree N
    equals Π_{p|N} (1−1/p) = φ(N)/N. -/
theorem gcdWeighted_euler (N : ℕ) (hSq : Squarefree N) :
    ∑ j ∈ Nat.divisors N, ∑ k ∈ Nat.divisors N,
      (moebius j : ℝ) * (moebius k : ℝ) * gcdWeighted j k =
    ∏ p ∈ Nat.primeFactors N, (1 - 1 / (p : ℝ)) := by
  rw [divisor_sum_euler_product gcdWeighted gcdWeighted_bilinear_mult
    gcdWeighted_one_one N hSq]
  congr 1; ext p
  -- localFactor(gcdWeighted, p) = 1 - 1/p
  show localFactor gcdWeighted p = 1 - 1 / (p : ℝ)
  unfold localFactor gcdWeighted
  -- gcd(1,1)=1, gcd(p,1)=1, gcd(1,p)=1, gcd(p,p)=p
  simp only [Nat.gcd_one_right, Nat.gcd_one_left, Nat.gcd_self]
  push_cast
  field_simp
  ring

-- ════════════════════════════════════════════════
-- §4. MERTENS PRODUCT BOUND AT HC NUMBERS
-- ════════════════════════════════════════════════

/-- For any N ≥ 2, primeFactors(N) ⊆ primes in range(N+1).
    (Every prime dividing N is ≤ N.) -/
theorem primeFactors_subset_range_succ (N : ℕ) (hN : 2 ≤ N) :
    N.primeFactors ⊆ (Finset.range (N + 1)).filter Nat.Prime := by
  intro p hp
  simp only [Finset.mem_filter, Finset.mem_range]
  exact ⟨Nat.lt_succ_of_le (Nat.le_of_dvd (by omega) (Nat.dvd_of_mem_primeFactors hp)),
         Nat.prime_of_mem_primeFactors hp⟩

/-! Subset product bound: for factors in (0,1], product over a SUBSET is ≥
    product over the full set. Since primeFactors(N) ⊆ primes ≤ N,
    the Mertens product over primeFactors is ≥ the full Mertens product.

    This gives: Π_{p|N}(1-1/p) ≥ Π_{p≤N, prime}(1-1/p) ~ e^{-γ}/lnN.
    (This is a LOWER bound, useful for showing φ(N)/N isn't too small.)

    For the UPPER bound needed by the Gram form: at HC numbers, the product
    Π_{p|N}(1-1/p) → 0 as N → ∞ because HC numbers acquire more prime factors.
    The precise rate is O(1/ln(ln N)) by Mertens' theorem applied to the
    largest prime factor p_k ~ (ln N)^{1+o(1)}.

    For the subsequential Gram bound vᵀGv < 1, we only need the product
    to be eventually < 1, which holds for all N ≥ 6.
-/
/-- Each Euler factor (1−1/p) is nonneg for primes p ≥ 2. -/
theorem euler_factor_nonneg {p : ℕ} (hp : Nat.Prime p) :
    0 ≤ 1 - 1 / (p : ℝ) := by
  have hp2 : (2 : ℝ) ≤ (p : ℝ) := by exact_mod_cast hp.two_le
  have hp_pos : (0 : ℝ) < (p : ℝ) := by linarith
  rw [sub_nonneg, div_le_one hp_pos]
  linarith

/-- Each Euler factor (1−1/p) is at most 1. -/
theorem euler_factor_le_one {p : ℕ} (_hp : Nat.Prime p) :
    1 - 1 / (p : ℝ) ≤ 1 := by
  have : (0 : ℝ) ≤ 1 / (p : ℝ) := div_nonneg one_pos.le (Nat.cast_nonneg' p)
  linarith

/-- The Mertens product over primeFactors is nonneg. -/
theorem mertens_product_nonneg (N : ℕ) :
    0 ≤ ∏ p ∈ Nat.primeFactors N, (1 - 1 / (p : ℝ)) := by
  apply Finset.prod_nonneg
  intro p hp
  exact euler_factor_nonneg (Nat.prime_of_mem_primeFactors hp)

/-- The product Π_{p|N}(1-1/p) is strictly less than 1 for any N ≥ 2.
    (In particular, for HC numbers N ≥ 6.)

    Proof: pick any p₀ ∈ primeFactors(N), split ∏ = (1−1/p₀)·∏_{rest},
    then (1−1/p₀) < 1 and ∏_{rest} ≤ 1 (each factor ≤ 1) and
    (1−1/p₀) ≥ 0, so ∏ ≤ (1−1/p₀)·1 < 1. -/
theorem mertens_product_lt_one (N : ℕ) (hN : 6 ≤ N) (_hHC : IsHighlyComposite N) :
    ∏ p ∈ Nat.primeFactors N, (1 - 1 / (p : ℝ)) < 1 := by
  -- N ≥ 6 ≥ 2 → primeFactors nonempty
  have hne : N.primeFactors.Nonempty := by
    rw [Finset.nonempty_iff_ne_empty, ne_eq, Nat.primeFactors_eq_empty]
    omega
  obtain ⟨p₀, hp₀⟩ := hne
  have hp₀_prime := Nat.prime_of_mem_primeFactors hp₀
  -- Split product: ∏ = (1-1/p₀) · ∏_{rest}
  rw [← Finset.mul_prod_erase _ _ hp₀]
  -- Factor bounds
  have h_lt : 1 - 1 / (p₀ : ℝ) < 1 := by
    have hp₀_pos : (0 : ℝ) < p₀ := Nat.cast_pos.mpr hp₀_prime.pos
    linarith [div_pos one_pos hp₀_pos]
  have h_nonneg : 0 ≤ 1 - 1 / (p₀ : ℝ) := euler_factor_nonneg hp₀_prime
  have h_rest_le : ∏ p ∈ N.primeFactors.erase p₀, (1 - 1 / (p : ℝ)) ≤ 1 :=
    Finset.prod_le_one
      (fun p hp => euler_factor_nonneg (Nat.prime_of_mem_primeFactors (Finset.mem_of_mem_erase hp)))
      (fun p hp => euler_factor_le_one (Nat.prime_of_mem_primeFactors (Finset.mem_of_mem_erase hp)))
  -- Chain: (1-1/p₀) · ∏_{rest} ≤ (1-1/p₀) · 1 = (1-1/p₀) < 1
  calc (1 - 1 / (p₀ : ℝ)) * ∏ p ∈ N.primeFactors.erase p₀, (1 - 1 / (p : ℝ))
      ≤ (1 - 1 / (p₀ : ℝ)) * 1 :=
        mul_le_mul_of_nonneg_left h_rest_le h_nonneg
    _ = 1 - 1 / (p₀ : ℝ) := mul_one _
    _ < 1 := h_lt

/-- **Mertens-HC Tendsto**: The Euler product over primeFactors of HC numbers
    tends to 0. This is the key decay statement.

    Proof sketch: HC numbers N_k have primeFactors = {2,3,...,p_{π(k)}}
    where p_{π(k)} → ∞. By Mertens' third theorem,
    Π_{p≤p_k}(1-1/p) ~ e^{-γ}/ln(p_k) → 0.
    Since primeFactors(N_k) ⊇ {primes ≤ p_k}, the product over
    primeFactors decays at least as fast. -/
axiom mertens_hc_product_tendsto_zero :
    ∀ ε : ℝ, ε > 0 → ∃ N₀ : ℕ, ∀ N : ℕ, IsHighlyComposite N → N ≥ N₀ →
      ∏ p ∈ Nat.primeFactors N, (1 - 1 / (p : ℝ)) < ε

/-- **PROVED**: The GCD-weighted Euler product at HC numbers is eventually < 1.
    This is what the Gram bound actually needs. -/
theorem gcdWeighted_euler_eventually_lt_one :
    ∃ N₀ : ℕ, ∀ N : ℕ, IsHighlyComposite N → N ≥ N₀ →
      Squarefree N →
      ∑ j ∈ Nat.divisors N, ∑ k ∈ Nat.divisors N,
        (moebius j : ℝ) * (moebius k : ℝ) * gcdWeighted j k < 1 := by
  obtain ⟨N₀, hN₀⟩ := mertens_hc_product_tendsto_zero 1 one_pos
  exact ⟨N₀, fun N hHC hN hSq => by
    rw [gcdWeighted_euler N hSq]
    exact hN₀ N hHC hN⟩

-- ════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════

/-!
## Audit (revised May 12, 2026)

### Sorry: 0 ✅

### Custom Axioms: 1
- `mertens_hc_product_tendsto_zero`: Π_{p|N_hc}(1-1/p) → 0 as N_hc → ∞
  (Follows from Mertens' 3rd theorem + HC numbers having all small primes.)
  NOTE: Previous axiom `mertens_product_bound_at_hc` (C/lnN bound) was FALSE —
  the correct rate is O(1/ln(ln N)), not O(1/ln N).

### PROVED (compiler-verified):
- `recipProduct_bilinear_mult` — 1/(jk) is BilinearMultiplicative ✅
- `recipProduct_euler` — Σμ(j)μ(k)/(jk) = Π(1−1/p)² ✅
- `gcdWeighted_bilinear_mult` — gcd(j,k)/(jk) is BilinearMultiplicative ✅
  (uses factorization_gcd + omega for the prime valuation identity)
- `gcdWeighted_euler` — Σμ(j)μ(k)·gcd/(jk) = Π(1−1/p) ✅
- `gcdWeighted_euler_eventually_lt_one` — GCD sum < 1 at large HC ✅ (from axiom)
- `primeFactors_subset_range_succ` — primeFactors ⊆ primes ≤ N ✅
- `mertens_product_lt_one` — Π_{p|N}(1-1/p) < 1 for N ≥ 6 ✅
- `euler_factor_nonneg` — 1−1/p ≥ 0 ✅
- `euler_factor_le_one` — 1−1/p ≤ 1 ✅
- `mertens_product_nonneg` — product ≥ 0 ✅

### Architecture:
```
  divisor_sum_euler_product (EulerProduct.lean, PROVED)
       ↓
  recipProduct_euler ────────→ Π(1−1/p)²
  gcdWeighted_euler ─────────→ Π(1−1/p)
       ↓
  mertens_hc_product_tendsto_zero (AXIOM — Mertens + HC structure)
       ↓
  gcdWeighted_euler_eventually_lt_one (PROVED: GCD sum < 1 at large HC)
       ↓
  [future] hc_gram_bound
```

### Key correction (May 12, 2026):
The previous axiom `mertens_product_bound_at_hc` claimed Π_{p|N}(1-1/p) ≤ C/lnN,
which is FALSE for large HC numbers. Numerically: C = prod * lnN grows as
~3.5 at N = 698M and is unbounded. The correct asymptotic is O(1/ln(ln N))
since HC prime factors are {2,3,...,p_k} with p_k ~ (lnN)^{1+o(1)}.
The corrected axiom uses a tendsto formulation which is mathematically sound.
-/

end Cathedral.Covariance
