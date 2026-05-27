import Cathedral.NumberTheory.BaselMoebius

/-!
# Graduation of coprime_restricted_moebius_sum

## Overview

This file proves the identity:
  CR(d) = (6/π²) / Π_{p|d}(1-1/p²)

where CR(d) = Σ_{n≥1, gcd(n,d)=1} μ(n)/n² is the coprime-restricted Möbius sum.

## Strategy

Induction on the number of prime factors of d.

### Base case
CR(1) = 6/π² (proved here as `coprimeRestricted_one`).

### Inductive step
For prime q with q∤d:
  CR(q·d) = CR(d) / (1 - 1/q²)

Derived from: CR(d) = CR(qd) + T, where T = -1/q² · CR(qd).

Created: May 27, 2026
-/

noncomputable section
open Real Finset BigOperators
open ArithmeticFunction
open scoped ArithmeticFunction.Moebius

namespace Cathedral.NumberTheory.CoprimeRestricted

-- ════════════════════════════════════════════════════════════════
-- §0. DEFINITION AND BASE CASE
-- ════════════════════════════════════════════════════════════════

/-- The coprime-restricted Möbius sum:
    CR(d) = Σ_{m≥1, gcd(m,d)=1} μ(m)/m²

    For d = 1 this is just the full sum = 6/π².
    For general squarefree d, the primes dividing d are removed
    from the Euler product. -/
noncomputable def coprimeRestricted (d : ℕ) : ℝ :=
  ∑' n : ℕ, if Nat.Coprime d (n + 1) then
    (↑(μ (n + 1)) : ℝ) / ((n + 1 : ℕ) : ℝ) ^ 2 else 0

/-- CR(1) = 6/π² (the full Möbius sum, since gcd(1,m) = 1 always). -/
theorem coprimeRestricted_one : coprimeRestricted 1 = 6 / π ^ 2 := by
  unfold coprimeRestricted
  simp only [Nat.Coprime, Nat.gcd_one_left, if_true]
  -- Goal: ∑' n, μ(n+1)/(n+1)² = 6/π²
  -- From BaselMoebius: ∑' n, μ(n)/n² = 6/π²
  -- Split off n=0 term (μ(0)/0² = 0) and shift
  have hf_sum := BaselMoebius.summable_moebius_div_sq
  have hf_val := BaselMoebius.tsum_moebius_div_sq
  have hshift := hf_sum.sum_add_tsum_nat_add 1
  rw [hf_val] at hshift
  simp only [Finset.sum_range_one] at hshift
  simp only [ArithmeticFunction.map_zero, Int.cast_zero, zero_div, zero_add] at hshift
  exact hshift

-- ════════════════════════════════════════════════════════════════
-- §1. SUMMABILITY
-- ════════════════════════════════════════════════════════════════

/-- Auxiliary: |μ(n)/n²| ≤ 1/n² since |μ| ≤ 1. -/
private theorem moebius_div_sq_norm_le (n : ℕ) :
    ‖(↑(μ (n + 1)) : ℝ) / ((n + 1 : ℕ) : ℝ) ^ 2‖ ≤
    1 / ((n + 1 : ℕ) : ℝ) ^ 2 := by
  have h_pos : (0 : ℝ) < ((n + 1 : ℕ) : ℝ) ^ 2 := by positivity
  rw [norm_div]
  have h_norm_denom : ‖((n + 1 : ℕ) : ℝ) ^ 2‖ = ((n + 1 : ℕ) : ℝ) ^ 2 := by
    rw [Real.norm_eq_abs, abs_of_nonneg h_pos.le]
  rw [h_norm_denom, div_le_div_iff_of_pos_right h_pos]
  simp only [Real.norm_eq_abs, ← Int.cast_abs]
  exact_mod_cast ArithmeticFunction.abs_moebius_le_one

/-- 1/(n+1)² is summable (shifted Basel series). -/
private theorem summable_shifted_inv_sq :
    Summable (fun n : ℕ => 1 / ((n + 1 : ℕ) : ℝ) ^ 2) := by
  have h := summable_one_div_nat_pow.mpr (by norm_num : 1 < 2)
  refine h.comp_injective (fun a b hab => ?_)
  omega

/-- The CR(d) terms are absolutely summable. -/
theorem summable_coprimeRestricted_terms (d : ℕ) :
    Summable (fun n : ℕ => if Nat.Coprime d (n + 1) then
      (↑(μ (n + 1)) : ℝ) / ((n + 1 : ℕ) : ℝ) ^ 2 else 0) :=
  Summable.of_norm_bounded summable_shifted_inv_sq fun n => by
    split_ifs with h
    · exact moebius_div_sq_norm_le n
    · simp only [norm_zero, one_div]; positivity

/-- The q-divisible terms are summable. -/
theorem summable_q_divisible (q d : ℕ) :
    Summable (fun n : ℕ => if Nat.Coprime d (n + 1) ∧ (q ∣ (n + 1)) then
      (↑(μ (n + 1)) : ℝ) / ((n + 1 : ℕ) : ℝ) ^ 2 else 0) :=
  Summable.of_norm_bounded summable_shifted_inv_sq fun n => by
    split_ifs with h
    · exact moebius_div_sq_norm_le n
    · simp only [norm_zero, one_div]; positivity

-- ════════════════════════════════════════════════════════════════
-- §2. POINTWISE SPLITTING
-- ════════════════════════════════════════════════════════════════

/-- Pointwise: f_d(n) = f_{qd}(n) + g_{q,d}(n) -/
theorem term_split (q d n : ℕ) (hq_prime : Nat.Prime q) :
    (if Nat.Coprime d (n + 1) then (↑(μ (n + 1)) : ℝ) / ((n + 1 : ℕ) : ℝ) ^ 2 else 0) =
    (if Nat.Coprime (q * d) (n + 1) then (↑(μ (n + 1)) : ℝ) / ((n + 1 : ℕ) : ℝ) ^ 2 else 0) +
    (if Nat.Coprime d (n + 1) ∧ (q ∣ (n + 1)) then
      (↑(μ (n + 1)) : ℝ) / ((n + 1 : ℕ) : ℝ) ^ 2 else 0) := by
  by_cases hd : Nat.Coprime d (n + 1)
  · by_cases hqn : Nat.Coprime q (n + 1)
    · have hqd : Nat.Coprime (q * d) (n + 1) :=
        Nat.coprime_mul_iff_left.mpr ⟨hqn, hd⟩
      have hq_not_dvd : ¬(q ∣ (n + 1)) :=
        (Nat.Prime.coprime_iff_not_dvd hq_prime).mp hqn
      rw [if_pos hd, if_pos hqd, if_neg (not_and_of_not_right _ hq_not_dvd)]
      ring
    · have hqd : ¬Nat.Coprime (q * d) (n + 1) := by
        intro h; exact hqn (Nat.coprime_mul_iff_left.mp h).1
      have hq_dvd : q ∣ (n + 1) := by
        rwa [Nat.Prime.coprime_iff_not_dvd hq_prime, not_not] at hqn
      rw [if_pos hd, if_neg hqd, if_pos ⟨hd, hq_dvd⟩]
      ring
  · have hqd : ¬Nat.Coprime (q * d) (n + 1) := by
      intro h; exact hd (Nat.coprime_mul_iff_left.mp h).2
    rw [if_neg hd, if_neg hqd, if_neg (not_and_of_not_left _ hd)]
    ring

-- ════════════════════════════════════════════════════════════════
-- §3. TSUM SPLITTING: CR(d) = CR(qd) + T
-- ════════════════════════════════════════════════════════════════

/-- CR(d) = CR(qd) + Σ_{gcd(n,d)=1, q|n} μ(n)/n². -/
theorem coprimeRestricted_split (q d : ℕ) (hq_prime : Nat.Prime q) :
    coprimeRestricted d = coprimeRestricted (q * d) +
      ∑' n : ℕ, if Nat.Coprime d (n + 1) ∧ (q ∣ (n + 1)) then
        (↑(μ (n + 1)) : ℝ) / ((n + 1 : ℕ) : ℝ) ^ 2 else 0 := by
  unfold coprimeRestricted
  rw [← (summable_coprimeRestricted_terms (q * d)).tsum_add
    (summable_q_divisible q d)]
  congr 1
  funext n
  exact term_split q d n hq_prime

-- ════════════════════════════════════════════════════════════════
-- §4. REINDEXING: the q-divisible sum = -1/q² · CR(qd)
-- ════════════════════════════════════════════════════════════════

/-- μ(q·(m+1)) = -μ(m+1) when q is prime and gcd(q, m+1) = 1. -/
theorem moebius_prime_mul {q m : ℕ} (hq : Nat.Prime q)
    (hcop : Nat.Coprime q (m + 1)) :
    (μ (q * (m + 1)) : ℤ) = -(μ (m + 1) : ℤ) := by
  rw [isMultiplicative_moebius.map_mul_of_coprime hcop]
  simp [ArithmeticFunction.moebius_apply_prime hq]

/-- μ(q·(m+1)) = 0 when q | (m+1) (since q² | q·(m+1)). -/
theorem moebius_prime_mul_of_dvd {q m : ℕ} (hq : Nat.Prime q)
    (hdvd : q ∣ (m + 1)) :
    (μ (q * (m + 1)) : ℤ) = 0 := by
  apply moebius_eq_zero_of_not_squarefree
  intro hsf
  have hcop := Nat.coprime_of_squarefree_mul hsf
  exact absurd hdvd ((Nat.Prime.coprime_iff_not_dvd hq).mp hcop)

/-- The q-divisible part of CR(d) equals -1/q² · CR(qd).

This is the key reindexing argument: terms with q | (n+1) are exactly
those of the form n+1 = q·k, and μ(q·k) = -μ(k) when gcd(q,k) = 1.

Mathematical proof:
  Σ_{gcd(d,n)=1, q|n} μ(n)/n²
  = Σ_{k≥1} μ(q·k)/(q·k)²  · 𝟙[gcd(d,qk)=1]
  = Σ_{k≥1, gcd(q,k)=1} (-μ(k))/(q²·k²) · 𝟙[gcd(d,qk)=1]
    (since μ(qk) = 0 when q|k, and = -μ(k) when gcd(q,k)=1)
  = -1/q² · Σ_{k≥1, gcd(qd,k)=1} μ(k)/k²
  = -1/q² · CR(qd)  -/
theorem q_divisible_sum_eq (q d : ℕ) (hq : Nat.Prime q) (hq_ndvd : ¬(q ∣ d)) :
    (∑' n : ℕ, if Nat.Coprime d (n + 1) ∧ (q ∣ (n + 1)) then
      (↑(μ (n + 1)) : ℝ) / ((n + 1 : ℕ) : ℝ) ^ 2 else 0) =
    -(1 / (q : ℝ) ^ 2) * coprimeRestricted (q * d) := by
  -- Define the LHS summand f and the injection ι(m) = q*(m+1) - 1
  set f : ℕ → ℝ := fun n => if Nat.Coprime d (n + 1) ∧ (q ∣ (n + 1)) then
      (↑(μ (n + 1)) : ℝ) / ((n + 1 : ℕ) : ℝ) ^ 2 else 0
  set ι : ℕ → ℕ := fun m => q * (m + 1) - 1
  -- Step 1: ι is injective (q*(a+1)-1 = q*(b+1)-1 → a = b)
  have hι_inj : Function.Injective ι := by
    intro a b (hab : q * (a + 1) - 1 = q * (b + 1) - 1)
    have hqa : 1 ≤ q * (a + 1) := by nlinarith [hq.one_le]
    have hqb : 1 ≤ q * (b + 1) := by nlinarith [hq.one_le]
    have h : q * (a + 1) = q * (b + 1) := by omega
    have := mul_left_cancel₀ hq.ne_zero h; omega
  -- Step 2: f vanishes outside range of ι (if ¬(q ∣ n+1) then f(n) = 0)
  have hf_zero : ∀ x, x ∉ Set.range ι → f x = 0 := by
    intro n hn; simp only [f]
    rw [if_neg]; intro ⟨_, hdvd⟩
    apply hn; obtain ⟨k, hk⟩ := hdvd
    cases k with
    | zero => omega
    | succ k => exact ⟨k, show q * (k + 1) - 1 = n by omega⟩
  -- Step 3: Reindex ∑ f(ι(m)) = ∑ f(n) via support ⊆ range ι
  have hsupp : Function.support f ⊆ Set.range ι := by
    intro n hn; by_contra h_nr; exact hn (hf_zero n h_nr)
  rw [← hι_inj.tsum_eq hsupp]
  -- Step 4: Pointwise: f(ι(m)) = -(1/q²) · CR_term(qd, m)
  -- Three cases: (a) coprime(q,m+1) ∧ coprime(d,m+1), (b) q|(m+1), (c) ¬coprime(d,m+1)
  have hqd_cop : Nat.Coprime d q :=
    Nat.Coprime.symm ((Nat.Prime.coprime_iff_not_dvd hq).mpr hq_ndvd)
  have h_term : ∀ m, f (ι m) = -(1 / (q : ℝ) ^ 2) *
      (if Nat.Coprime (q * d) (m + 1) then
        (↑(μ (m + 1)) : ℝ) / ((m + 1 : ℕ) : ℝ) ^ 2 else 0) := by
    intro m; simp only [f, ι]
    have hge : q * (m + 1) ≥ 1 := by nlinarith [hq.one_le]
    have hn1 : q * (m + 1) - 1 + 1 = q * (m + 1) := by omega
    simp only [hn1, dvd_mul_right, and_true]
    have h_iff : Nat.Coprime d (q * (m + 1)) ↔ Nat.Coprime d (m + 1) := by
      rw [Nat.coprime_mul_iff_right]
      exact ⟨fun ⟨_, h2⟩ => h2, fun h2 => ⟨hqd_cop, h2⟩⟩
    by_cases hd : Nat.Coprime d (m + 1)
    · rw [if_pos (h_iff.mpr hd)]
      by_cases hqm : Nat.Coprime q (m + 1)
      · -- Case (a): coprime(q,m+1) → μ(q*(m+1)) = -μ(m+1)
        rw [if_pos (Nat.Coprime.mul_left hqm hd)]
        have hmu : (↑(μ (q * (m + 1))) : ℝ) = -(↑(μ (m + 1)) : ℝ) := by
          exact_mod_cast show (μ (q * (m + 1)) : ℤ) = -(μ (m + 1) : ℤ) from by
            rw [isMultiplicative_moebius.map_mul_of_coprime hqm]
            simp [ArithmeticFunction.moebius_apply_prime hq]
        rw [hmu, show ((q * (m + 1) : ℕ) : ℝ) ^ 2 = (q : ℝ) ^ 2 * ((m + 1 : ℕ) : ℝ) ^ 2
          from by push_cast; ring]
        ring
      · -- Case (b): q|(m+1) → μ(q*(m+1)) = 0 (q² divides q*(m+1))
        rw [if_neg (by rw [Nat.coprime_mul_iff_left]; exact fun ⟨h, _⟩ => hqm h)]
        have : (μ (q * (m + 1)) : ℤ) = 0 := by
          apply ArithmeticFunction.moebius_eq_zero_of_not_squarefree
          intro hsf; exact hqm (Nat.coprime_of_squarefree_mul hsf)
        simp [this]
    · -- Case (c): ¬coprime(d, m+1) → both sides zero
      rw [if_neg (mt h_iff.mp hd),
          if_neg (by intro h; exact hd (Nat.coprime_mul_iff_left.mp h).2)]
      simp
  -- Step 5: Factor out the constant -(1/q²) via tsum_mul_left
  simp_rw [h_term]; unfold coprimeRestricted; rw [← tsum_mul_left]

-- ════════════════════════════════════════════════════════════════
-- §5. KEY INDUCTIVE STEP
-- ════════════════════════════════════════════════════════════════

/-- CR(d) = CR(q*d) · (1 - 1/q²) -/
theorem coprimeRestricted_factor (q d : ℕ) (hq : Nat.Prime q)
    (hq_ndvd : ¬(q ∣ d)) :
    coprimeRestricted d = coprimeRestricted (q * d) * (1 - 1 / (q : ℝ) ^ 2) := by
  rw [coprimeRestricted_split q d hq,
      q_divisible_sum_eq q d hq hq_ndvd]
  ring

/-- CR(q*d) = CR(d) / (1 - 1/q²) -/
theorem coprimeRestricted_remove_prime (q d : ℕ) (hq : Nat.Prime q)
    (hq_ndvd : ¬(q ∣ d)) :
    coprimeRestricted (q * d) = coprimeRestricted d / (1 - 1 / (q : ℝ) ^ 2) := by
  have h1 : (1 : ℝ) - 1 / (q : ℝ) ^ 2 ≠ 0 := by
    have hq2 : (q : ℝ) ^ 2 ≥ 4 := by
      have : (2 : ℝ) ≤ (q : ℝ) := by exact_mod_cast hq.two_le
      nlinarith
    intro heq
    have : 1 / (q : ℝ) ^ 2 = 1 := by linarith
    have : (q : ℝ) ^ 2 ≤ 1 := by
      rw [div_eq_iff (by positivity : (q : ℝ) ^ 2 ≠ 0)] at this
      linarith
    linarith
  rw [eq_div_iff h1, coprimeRestricted_factor q d hq hq_ndvd]

-- ════════════════════════════════════════════════════════════════
-- §6. MAIN THEOREM BY FINSET INDUCTION
-- ════════════════════════════════════════════════════════════════

/-- CR(∏ S) = (6/π²) / ∏_{p∈S} (1 - 1/p²) for S a set of primes. -/
theorem coprimeRestricted_prod_primes (S : Finset ℕ) (hS : ∀ p ∈ S, Nat.Prime p) :
    coprimeRestricted (∏ p ∈ S, p) =
      (6 / π ^ 2) / ∏ p ∈ S, (1 - 1 / (p : ℝ) ^ 2) := by
  induction S using Finset.induction_on with
  | empty =>
    simp [coprimeRestricted_one]
  | @insert q S hq_notin ih =>
    have hq_prime : Nat.Prime q := hS q (Finset.mem_insert_self q S)
    have hS_primes : ∀ p ∈ S, Nat.Prime p :=
      fun p hp => hS p (Finset.mem_insert_of_mem hp)
    rw [Finset.prod_insert hq_notin]
    have hq_ndvd : ¬(q ∣ ∏ p ∈ S, p) := by
      intro hdvd
      obtain ⟨p, hp, hqp⟩ := (hq_prime.prime.dvd_finset_prod_iff _root_.id).mp hdvd
      -- hqp : q ∣ id p = q ∣ p, with p prime from S
      rcases (hS_primes p hp).eq_one_or_self_of_dvd q hqp with h1 | h1
      · exact hq_prime.one_lt.ne' h1
      · rw [← h1] at hp; exact hq_notin hp
    rw [coprimeRestricted_remove_prime q (∏ p ∈ S, p) hq_prime hq_ndvd,
        ih hS_primes, Finset.prod_insert hq_notin, div_div, mul_comm]

/-- **MAIN THEOREM**: CR(d) = (6/π²) / Π_{p|d}(1-1/p²) for squarefree d ≥ 1. -/
theorem coprime_restricted_moebius_sum (d : ℕ) (_hd : 0 < d) (hd_sf : Squarefree d) :
    coprimeRestricted d =
      (6 / π ^ 2) / ∏ p ∈ d.primeFactors, (1 - 1 / (p : ℝ) ^ 2) := by
  conv_lhs => rw [← Nat.prod_primeFactors_of_squarefree hd_sf]
  exact coprimeRestricted_prod_primes d.primeFactors
    (fun p hp => (Nat.mem_primeFactors.mp hp).1)

end Cathedral.NumberTheory.CoprimeRestricted

end
