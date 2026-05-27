import Cathedral.NumberTheory.EulerProductLimit
import Cathedral.NumberTheory.SquarefreeJ2Sum
import Cathedral.NumberTheory.CoprimeRestricted
import Cathedral.Physics.Bridges.BernoulliSkeleton

/-!
# Euler Product Graduation — Option A

## Overview

This file graduates the `euler_product_b1_energy` axiom from
`EulerProductLimit.lean` via the direct multiplicative evaluation
(Option A).

## The Chain

The identity Σ_d J₂(d)·A(d)² = 6/π² factors as:

1. **Squarefree annihilation** (proved in EulerProductLimit):
   A(d) = 0 for non-squarefree d.

2. **Coprime splitting** (proved here, §1-§2):
   For squarefree d with gcd(m,d) > 1: μ(dm) = 0
   For squarefree d with gcd(m,d) = 1: μ(dm) = μ(d)·μ(m)
   Therefore: A(d) = μ(d)/d² · Σ_{gcd(m,d)=1} μ(m)/m²

3. **Coprime-restricted sum** (proved in CoprimeRestricted.lean, §3):
   Σ_{gcd(m,d)=1} μ(m)/m² = (6/π²) / Π_{p|d}(1-1/p²)

   This is the Euler product with d-prime factors removed.
   Graduation: remove the p-factors from Π_p(1-1/p²) = 6/π².

4. **J₂·A² computation** (proved here, §4):
   J₂(d)·A(d)² = (6/π²)² / [d² · Π_{p|d}(1-1/p²)]
                = (6/π²)² · Π_{p|d} 1/(p²-1)

5. **Summation** (proved here, §5):
   Σ J₂(d)·A(d)² = (6/π²)² · Σ_{sqfree d} Π 1/(p²-1)
                   = (6/π²)² · π²/6
                   = 6/π²

Status: All axioms graduated. 0 axioms, 0 sorry remaining.

Created: May 26, 2026 — The Euler Product Graduation Session
-/

noncomputable section
open Real Finset BigOperators
open ArithmeticFunction
open scoped ArithmeticFunction.Moebius

namespace Cathedral.NumberTheory.EulerProductGraduation

-- Convenient abbreviations
private abbrev J₂ := Cathedral.Physics.BernoulliSkeleton.jordanTotient2
private abbrev A := EulerProductLimit.divisorProjection

-- ════════════════════════════════════════════════════════════════
-- §1. COPRIME SPLITTING — μ(dm) for squarefree d
-- ════════════════════════════════════════════════════════════════

/-- When d is squarefree and m shares a prime factor with d,
    dm is not squarefree, so μ(dm) = 0.
    Uses `coprime_of_squarefree_mul` from Mathlib: Squarefree(d*m) → Coprime d m. -/
theorem moebius_mul_zero_of_not_coprime {d m : ℕ}
    (hcop : ¬Nat.Coprime d m) :
    (μ (d * m) : ℤ) = 0 := by
  apply moebius_eq_zero_of_not_squarefree
  intro hsf
  exact hcop (Nat.coprime_of_squarefree_mul hsf)

/-- When d is squarefree and gcd(d,m) = 1, μ(dm) = μ(d)·μ(m).
    This is just multiplicativity of the Möbius function. -/
theorem moebius_mul_of_coprime {d m : ℕ} (hcop : Nat.Coprime d m) :
    (μ (d * m) : ℤ) = μ d * μ m :=
  isMultiplicative_moebius.map_mul_of_coprime hcop

-- ════════════════════════════════════════════════════════════════
-- §2. COPRIME-RESTRICTED SUM (re-exported from CoprimeRestricted.lean)
-- ════════════════════════════════════════════════════════════════

/-- The coprime-restricted Möbius sum (re-exported from CoprimeRestricted). -/
noncomputable abbrev coprimeRestricted := CoprimeRestricted.coprimeRestricted

/-- CR(1) = 6/π² (re-exported from CoprimeRestricted). -/
theorem coprimeRestricted_one : coprimeRestricted 1 = 6 / π ^ 2 :=
  CoprimeRestricted.coprimeRestricted_one

-- ════════════════════════════════════════════════════════════════
-- §3. THE COPRIME-RESTRICTED SUM IDENTITY (🎓 GRADUATED)
-- ════════════════════════════════════════════════════════════════

/-- **GRADUATED** (Coprime-restricted Euler product removal):

    For squarefree d ≥ 1:
    Σ_{gcd(m,d)=1} μ(m)/m² = (6/π²) / Π_{p|d}(1-1/p²)

    Proved in `CoprimeRestricted.lean` via induction on prime factors
    of d, using the Möbius function's multiplicativity and a tsum
    reindexing argument. -/
theorem coprime_restricted_moebius_sum (d : ℕ) (hd : 0 < d) (hd_sf : Squarefree d) :
    coprimeRestricted d =
      (6 / π ^ 2) / ∏ p ∈ d.primeFactors, (1 - 1 / (p : ℝ) ^ 2) :=
  CoprimeRestricted.coprime_restricted_moebius_sum d hd hd_sf

-- ════════════════════════════════════════════════════════════════
-- §4. J₂(d)·A(d)² COMPUTATION
-- ════════════════════════════════════════════════════════════════

/-- Key algebraic identity:
    J₂(d)/d² = Π_{p|d}(1-1/p²)

    Immediate from the definition J₂(d) = d²·Π(1-1/p²). -/
theorem j2_div_sq_eq_prod (d : ℕ) (hd : 0 < d) :
    J₂ d / (d : ℝ) ^ 2 = ∏ p ∈ d.primeFactors, (1 - 1 / (p : ℝ) ^ 2) := by
  unfold J₂ Cathedral.Physics.BernoulliSkeleton.jordanTotient2
  have hd_ne : (d : ℝ) ^ 2 ≠ 0 := pow_ne_zero _ (Nat.cast_ne_zero.mpr hd.ne')
  rw [mul_div_cancel_left₀ _ hd_ne]

/-- The product Π_{p|d}(1-1/p²) > 0 for all d ≥ 1. -/
theorem prod_one_sub_inv_sq_pos (d : ℕ) (_hd : 0 < d) :
    0 < ∏ p ∈ d.primeFactors, (1 - 1 / (p : ℝ) ^ 2) := by
  apply Finset.prod_pos
  intro p hp
  have hp_prime := (Nat.mem_primeFactors.mp hp).1
  have hp2 : 2 ≤ p := hp_prime.two_le
  have hp2_pos : (0 : ℝ) < (p : ℝ) ^ 2 := by positivity
  rw [sub_pos, div_lt_one hp2_pos]
  calc (1 : ℝ) < 2 ^ 2 := by norm_num
    _ ≤ (p : ℝ) ^ 2 := by
      apply pow_le_pow_left₀ (by positivity : (0 : ℝ) ≤ 2)
      exact Nat.cast_le.mpr hp2

/-- For squarefree d, the reciprocal product equals d²/J₂(d). -/
theorem prod_inv_eq_sq_div_j2 (d : ℕ) (hd : 0 < d) :
    1 / ∏ p ∈ d.primeFactors, (1 - 1 / (p : ℝ) ^ 2) = (d : ℝ) ^ 2 / J₂ d := by
  rw [one_div, ← j2_div_sq_eq_prod d hd, inv_div]

/-- For squarefree d = p₁···pₖ, we have
    J₂(d) = Π_{p|d} (p²-1).

    Proof: J₂(d) = d²·Π(1-1/p²). For squarefree d, d = Πp so d² = Πp².
    Distributing: J₂(d) = Π[p²·(1-1/p²)] = Π(p²-1). -/
theorem j2_eq_prod_sq_minus_one (d : ℕ) (_hd : 0 < d) (hd_sf : Squarefree d) :
    J₂ d = ∏ p ∈ d.primeFactors, ((p : ℝ) ^ 2 - 1) := by
  unfold J₂ Cathedral.Physics.BernoulliSkeleton.jordanTotient2
  -- d = ∏ p for squarefree d
  have hd_eq : (d : ℝ) = ∏ p ∈ d.primeFactors, (p : ℝ) := by
    rw [← Nat.cast_prod]
    exact congrArg Nat.cast (Nat.prod_primeFactors_of_squarefree hd_sf).symm
  -- d² = (∏ p)², and we distribute into the product
  rw [hd_eq, ← Finset.prod_pow, ← Finset.prod_mul_distrib]
  apply Finset.prod_congr rfl
  intro p hp
  have hp_prime := (Nat.mem_primeFactors.mp hp).1
  have hp_pos : (0 : ℝ) < (p : ℝ) := Nat.cast_pos.mpr hp_prime.pos
  have hp_ne : (p : ℝ) ≠ 0 := ne_of_gt hp_pos
  have hp2_ne : (p : ℝ) ^ 2 ≠ 0 := pow_ne_zero _ hp_ne
  -- p² · (1 - 1/p²) = p² - 1
  field_simp

/-- For squarefree d = p₁···pₖ, we have
    Π_{p|d} 1/(p²-1) = 1/J₂(d). -/
theorem prod_inv_sq_minus_one (d : ℕ) (hd : 0 < d) (hd_sf : Squarefree d) :
    ∏ p ∈ d.primeFactors, (1 / ((p : ℝ) ^ 2 - 1)) =
      1 / J₂ d := by
  rw [j2_eq_prod_sq_minus_one d hd hd_sf, Finset.prod_div_distrib, Finset.prod_const_one]

-- ════════════════════════════════════════════════════════════════
-- §5. THE SQUAREFREE SUM EVALUATION
-- ════════════════════════════════════════════════════════════════

/-- **GRADUATED** (Squarefree reciprocal J₂ sum):

    Σ_{d sqfree, d≥1} 1/J₂(d) = π²/6

    Formerly an axiom — now proved in SquarefreeJ2Sum.lean via:
    - Multiplicative Euler product (Mathlib `riemannZeta_eulerProduct_hasProd`)
    - ℂ→ℝ projection through `IsInducing ofReal`
    - ζ(2) = π²/6 (`riemannZeta_two`)

    HasSum form includes absolute convergence. -/
theorem squarefree_reciprocal_j2_sum :
    HasSum (fun d : ℕ => if d = 0 then 0
      else if Squarefree d then 1 / J₂ d else 0)
    (π ^ 2 / 6) :=
  Cathedral.NumberTheory.SquarefreeJ2Sum.squarefree_reciprocal_j2_sum

-- ════════════════════════════════════════════════════════════════
-- §6. THE ASSEMBLY — graduating euler_product_b1_energy
-- ════════════════════════════════════════════════════════════════

/-- (6/π²)² · (π²/6) = 6/π². -/
theorem six_over_pi_sq_squared_times_zeta2 :
    (6 / π ^ 2) ^ 2 * (π ^ 2 / 6) = 6 / π ^ 2 := by
  have hpi : (π : ℝ) ≠ 0 := pi_ne_zero
  have hpi2 : π ^ 2 ≠ 0 := pow_ne_zero _ hpi
  field_simp

-- ════════════════════════════════════════════════════════════════
-- §6a. DIVISOR PROJECTION SPLITTING: A(d) = μ(d)/d² · CR(d)
-- ════════════════════════════════════════════════════════════════

/-- Each term of A(d) splits by coprimality. -/
private theorem div_proj_term_split (d n : ℕ) :
    (↑(μ (d * (n + 1))) : ℝ) / ((d * (n + 1) : ℕ) : ℝ) ^ 2 =
    (↑(μ d) : ℝ) / (d : ℝ) ^ 2 *
      (if Nat.Coprime d (n + 1) then (↑(μ (n + 1)) : ℝ) / ((n + 1 : ℕ) : ℝ) ^ 2 else 0) := by
  by_cases hcop : Nat.Coprime d (n + 1)
  · rw [if_pos hcop]
    have hmu : (↑(μ (d * (n + 1))) : ℝ) = (↑(μ d) : ℝ) * (↑(μ (n + 1)) : ℝ) :=
      by exact_mod_cast moebius_mul_of_coprime hcop
    rw [hmu, show ((d * (n + 1) : ℕ) : ℝ) ^ 2 = (d : ℝ) ^ 2 * ((n + 1 : ℕ) : ℝ) ^ 2
      from by push_cast; ring]
    ring
  · rw [if_neg hcop, mul_zero]
    have : (↑(μ (d * (n + 1))) : ℝ) = 0 :=
      by exact_mod_cast moebius_mul_zero_of_not_coprime hcop
    simp [this]

/-- **Key factorization**: A(d) = μ(d)/d² · CR(d) for d ≥ 1. -/
theorem div_proj_eq_moebius_cr (d : ℕ) (hd : 0 < d) :
    A d = (↑(μ d) : ℝ) / (d : ℝ) ^ 2 * coprimeRestricted d := by
  unfold A EulerProductLimit.divisorProjection
  rw [if_neg hd.ne']
  show ∑' n, _ = (↑(μ d) : ℝ) / (d : ℝ) ^ 2 * ∑' n, _
  rw [← tsum_mul_left]
  congr 1; funext n
  exact div_proj_term_split d n

-- ════════════════════════════════════════════════════════════════
-- §6b. MÖBIUS SQUARE IDENTITY: μ(d)² = 1 for squarefree d
-- ════════════════════════════════════════════════════════════════

/-- For squarefree d ≥ 1, μ(d) ≠ 0 (by strong induction on d). -/
private theorem moebius_ne_zero_of_squarefree :
    ∀ d : ℕ, 0 < d → Squarefree d → (μ d : ℤ) ≠ 0 := by
  intro d
  induction d using Nat.strongRecOn with
  | _ d ih =>
    intro hd hd_sf
    by_cases h1 : d = 1
    · subst h1; simp [isMultiplicative_moebius.map_one]
    · obtain ⟨p, hp, hpdvd⟩ := Nat.exists_prime_and_dvd h1
      have hq_lt : d / p < d := Nat.div_lt_self hd hp.one_lt
      have hcop : Nat.Coprime p (d / p) :=
        Nat.coprime_of_squarefree_mul (show Squarefree (p * (d / p)) by
          rwa [Nat.mul_div_cancel' hpdvd])
      have hq_sf : Squarefree (d / p) :=
        fun c hc => hd_sf c (hc.trans (Nat.div_dvd_of_dvd hpdvd))
      rw [show d = p * (d / p) from (Nat.mul_div_cancel' hpdvd).symm,
          isMultiplicative_moebius.map_mul_of_coprime hcop]
      exact mul_ne_zero (by simp [moebius_apply_prime hp])
        (ih _ hq_lt (Nat.div_pos (Nat.le_of_dvd hd hpdvd) hp.pos) hq_sf)

/-- **μ(d)² = 1** for squarefree d ≥ 1 (in ℝ). -/
theorem moebius_sq_eq_one (d : ℕ) (hd : 0 < d) (hd_sf : Squarefree d) :
    (↑(μ d) : ℝ) ^ 2 = 1 := by
  have hne := moebius_ne_zero_of_squarefree d hd hd_sf
  have hab := abs_moebius_le_one (n := d)
  have hmem : μ d = 1 ∨ μ d = -1 := by
    have habs := abs_le.mp hab; omega
  rcases hmem with h | h <;> simp [h]

-- ════════════════════════════════════════════════════════════════
-- §6c. J₂·A² COMPUTATION
-- ════════════════════════════════════════════════════════════════

/-- **J₂(d)·A(d)² = (6/π²)²/J₂(d)** for squarefree d ≥ 1. -/
theorem j2_A_sq_eq_of_squarefree (d : ℕ) (hd : 0 < d) (hd_sf : Squarefree d) :
    J₂ d * (A d) ^ 2 = (6 / π ^ 2) ^ 2 / J₂ d := by
  have hprod_pos := prod_one_sub_inv_sq_pos d hd
  rw [div_proj_eq_moebius_cr d hd, coprime_restricted_moebius_sum d hd hd_sf]
  unfold J₂ Cathedral.Physics.BernoulliSkeleton.jordanTotient2
  have hmu_sq := moebius_sq_eq_one d hd hd_sf
  field_simp
  nlinarith [hmu_sq, sq_nonneg ((6 : ℝ) / π ^ 2)]

/-- Pointwise identity for ALL d. -/
theorem j2_A_sq_pointwise (d : ℕ) :
    J₂ d * (A d) ^ 2 =
    (6 / π ^ 2) ^ 2 * (if d = 0 then 0 else if Squarefree d then 1 / J₂ d else 0) := by
  by_cases hd0 : d = 0
  · subst hd0; simp [EulerProductLimit.divisorProjection_zero]
  · rw [if_neg hd0]
    have hd : 0 < d := Nat.pos_of_ne_zero hd0
    by_cases hd_sf : Squarefree d
    · rw [if_pos hd_sf, j2_A_sq_eq_of_squarefree d hd hd_sf]; ring
    · rw [if_neg hd_sf, mul_zero]
      have : A d = 0 := EulerProductLimit.divisorProjection_nonsquarefree d hd hd_sf
      rw [this]; ring

-- ════════════════════════════════════════════════════════════════
-- §6d. THE FINAL ASSEMBLY — euler_product_b1_energy GRADUATED
-- ════════════════════════════════════════════════════════════════

/-- **🎓 GRADUATED**: Σ_d J₂(d)·A(d)² = 6/π² (HasSum form).

    This proves the `euler_product_b1_energy` axiom from EulerProductLimit. -/
theorem euler_product_assembly :
    HasSum (fun d : ℕ => J₂ d * (A d) ^ 2) (6 / π ^ 2) := by
  rw [show (6 : ℝ) / π ^ 2 = (6 / π ^ 2) ^ 2 * (π ^ 2 / 6) from
    six_over_pi_sq_squared_times_zeta2.symm]
  have hfun : (fun d : ℕ => J₂ d * (A d) ^ 2) =
      (fun d : ℕ => (6 / π ^ 2) ^ 2 *
        (if d = 0 then 0 else if Squarefree d then 1 / J₂ d else 0)) :=
    funext j2_A_sq_pointwise
  rw [hfun]
  exact squarefree_reciprocal_j2_sum.mul_left _

-- ════════════════════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════════════════════

/-!
## Audit

### Status: 0 axioms, 0 sorry — FULLY GRADUATED ✅

The `euler_product_b1_energy` axiom has been completely graduated via
the Option A multiplicative evaluation chain.

### Axiom Reduction:
- **Before**: 1 axiom (`euler_product_b1_energy`)
- **After**: **0 axioms** — all graduated ✅

### Dependencies:
- `Cathedral.NumberTheory.EulerProductLimit` (divisorProjection, jordanTotient2)
- `Cathedral.NumberTheory.CoprimeRestricted` (coprime-restricted Möbius sum)
- `Cathedral.NumberTheory.SquarefreeJ2Sum` (squarefree reciprocal J₂ sum)
- Mathlib: `isMultiplicative_moebius`, `Squarefree`, `Nat.primeFactors`, `HasSum`
-/

end Cathedral.NumberTheory.EulerProductGraduation

end

