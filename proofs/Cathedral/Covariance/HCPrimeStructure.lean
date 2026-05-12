/-
  Cathedral/Covariance/HCPrimeStructure.lean

  ## HC Prime Structure → Mertens Product Decay

  Proves that the Mertens product over primeFactors of HC numbers
  tends to 0, by combining:
  1. Mertens' third theorem: Π_{p<X}(1-1/p) → 0
  2. HC numbers eventually contain all primes up to any bound
  3. Superset product inequality for [0,1]-valued functions

  ### Axioms in this file: 1
  - `hc_primeFactors_eventually_contain`: HC numbers eventually contain
    all primes up to any bound. This follows from the prime swap theorem
    (if p | N_hc and q < p with q ∤ N_hc, then N/p·q has more divisors).

  ### Proved in this file:
  - `mertens_product_tendsto_zero`: Π_{p<X}(1-1/p) → 0 (from Mertens 3rd)
  - `mertens_hc_product_tendsto_zero_proved`: Π_{p|N_hc}(1-1/p) → 0

  Created: May 12, 2026 — Exploration 36
  Status: 0 sorry, 1 axiom.
-/

import Cathedral.Covariance.HighlyComposite
import Cathedral.Covariance.MertensBridge
import Mathlib.Data.Nat.Factorization.Basic

noncomputable section
open Real Finset Filter Cathedral.Covariance Cathedral.Covariance.MertensBridge

namespace Cathedral.Covariance.HCPrimeStructure

-- ════════════════════════════════════════════════
-- §1. HC PRIME STRUCTURE AXIOM
-- ════════════════════════════════════════════════

/-- **AXIOM**: HC numbers eventually contain all primes up to any bound.

    For any B, there exists N₀ such that for all HC numbers N ≥ N₀,
    every prime p ≤ B divides N.

    This is a consequence of the **prime swap theorem**: if N is HC,
    p | N, and q < p is a prime with q ∤ N, then M = N/p · q satisfies
    M < N and d(M) ≥ d(N), contradicting HC.

    In particular, HC numbers have "consecutive" prime factors
    {2, 3, 5, ..., p_k}, with no gaps. -/
axiom hc_primeFactors_eventually_contain :
    ∀ B : ℕ, ∃ N₀ : ℕ, ∀ N : ℕ, IsHighlyComposite N → N ≥ N₀ →
      ∀ p : ℕ, p.Prime → p ≤ B → p ∈ N.primeFactors

-- ════════════════════════════════════════════════
-- §2. SUPERSET PRODUCT INEQUALITY
-- ════════════════════════════════════════════════

/-- Product over a superset of [0,1] factors is ≤ product over subset.
    (More factors in [0,1] makes the product smaller.) -/
private lemma prod_le_prod_of_superset (S T : Finset ℕ) (hST : T ⊆ S) (f : ℕ → ℝ)
    (hf0 : ∀ x ∈ S, 0 ≤ f x) (hf1 : ∀ x ∈ S, f x ≤ 1) :
    ∏ x ∈ S, f x ≤ ∏ x ∈ T, f x := by
  rw [← Finset.prod_sdiff hST]
  calc (∏ x ∈ S \ T, f x) * (∏ x ∈ T, f x)
      ≤ 1 * (∏ x ∈ T, f x) :=
        mul_le_mul_of_nonneg_right
          (Finset.prod_le_one (fun x hx => hf0 x (sdiff_subset hx))
            (fun x hx => hf1 x (sdiff_subset hx)))
          (Finset.prod_nonneg (fun x hx => hf0 x (hST hx)))
    _ = ∏ x ∈ T, f x := one_mul _

-- ════════════════════════════════════════════════
-- §3. MERTENS PRODUCT → 0
-- ════════════════════════════════════════════════

/-- **PROVED**: The Mertens product Π_{p<X, prime}(1-1/p) → 0 as X → ∞.

    From cathedral_mertens_third: ln(X) · Π → e^{-γ} > 0.
    Since ln(X) → ∞, we get Π → 0.

    Proof: for any ε > 0, eventually ln(X) · Π < e^{-γ} + 1 = C,
    so Π < C/ln(X). Since ln(X) → ∞, eventually C/ln(X) < ε. -/
theorem mertens_product_tendsto_zero :
    Tendsto (fun X : ℕ => ∏ p ∈ (range X).filter Nat.Prime, (1 - 1 / (p : ℝ)))
    atTop (nhds 0) := by
  rw [Metric.tendsto_atTop]
  intro ε hε
  have h_mertens := cathedral_mertens_third
  rw [Metric.tendsto_atTop] at h_mertens
  obtain ⟨N₁, hN₁⟩ := h_mertens 1 one_pos
  set C := exp (-eulerMascheroniConstant) + 1
  have h_log_unbdd : Tendsto (fun n : ℕ => log (n : ℝ)) atTop atTop :=
    tendsto_log_atTop.comp tendsto_natCast_atTop_atTop
  rw [Filter.tendsto_atTop_atTop] at h_log_unbdd
  obtain ⟨N₂, hN₂⟩ := h_log_unbdd (C / ε + 1)
  refine ⟨max N₁ (max N₂ 2), fun X hX => ?_⟩
  have hlog_pos : 0 < log (X : ℝ) := by
    apply Real.log_pos; exact_mod_cast show 1 < X from by omega
  rw [Real.dist_eq, sub_zero, abs_of_nonneg (Finset.prod_nonneg fun p hp => by
    have := (mem_filter.mp hp).2
    linarith [show (0:ℝ) ≤ 1/(p:ℝ) from div_nonneg one_pos.le (Nat.cast_nonneg' p),
              show 1/(p:ℝ) ≤ 1 from by
                rw [div_le_one (show (0:ℝ) < p from by exact_mod_cast this.pos)]
                exact_mod_cast this.one_le])]
  have h_dist := hN₁ X (by omega)
  rw [Real.dist_eq] at h_dist
  have h_bound : log X * ∏ p ∈ (range X).filter Nat.Prime, (1 - 1/(p:ℝ)) < C := by
    have := (abs_lt.mp h_dist).2; linarith
  have : ∏ p ∈ (range X).filter Nat.Prime, (1 - 1/(p:ℝ)) < C / log X := by
    rwa [lt_div_iff₀ hlog_pos, mul_comm]
  have : C / log (X : ℝ) < ε := by
    rw [div_lt_iff₀ hlog_pos]
    have : C / ε + 1 ≤ log (X : ℝ) := hN₂ X (by omega)
    calc C = ε * (C / ε) := by rw [mul_div_cancel₀ C (ne_of_gt hε)]
      _ < ε * (C / ε + 1) := by linarith
      _ ≤ ε * log (X : ℝ) := by linarith [mul_le_mul_of_nonneg_left ‹_› (le_of_lt hε)]
  linarith

-- ════════════════════════════════════════════════
-- §4. THE GRADUATION
-- ════════════════════════════════════════════════

/-- **PROVED (from axiom)**: The Mertens product over primeFactors of HC
    numbers tends to 0.

    This GRADUATES the axiom `mertens_hc_product_tendsto_zero` from
    HCEulerProduct.lean, replacing it with the simpler axiom
    `hc_primeFactors_eventually_contain`.

    Proof chain:
    1. mertens_product_tendsto_zero: Π_{p<X}(1-1/p) → 0  (from Mertens 3rd)
    2. For large HC N, primeFactors(N) ⊇ {primes ≤ B}     (axiom)
    3. Superset product: Π_{pf(N)} ≤ Π_{primes ≤ B}       (proved)
    4. Combine: Π_{pf(N)} ≤ Π_{primes ≤ B} < ε            (for large B) -/
theorem mertens_hc_product_tendsto_zero_proved :
    ∀ ε : ℝ, ε > 0 → ∃ N₀ : ℕ, ∀ N : ℕ, IsHighlyComposite N → N ≥ N₀ →
      ∏ p ∈ Nat.primeFactors N, (1 - 1 / (p : ℝ)) < ε := by
  intro ε hε
  -- Step 1: Find B such that Π_{range(B+1) filter prime}(1-1/p) < ε
  have h_mz := mertens_product_tendsto_zero
  rw [Metric.tendsto_atTop] at h_mz
  obtain ⟨B, hB⟩ := h_mz ε hε
  -- Step 2: Find N₁ such that HC N ≥ N₁ → primeFactors(N) ⊇ {primes ≤ B}
  obtain ⟨N₁, hN₁⟩ := hc_primeFactors_eventually_contain B
  refine ⟨max N₁ 6, fun N hHC hN => ?_⟩
  -- Step 3: {primes ≤ B} = range(B+1) filter prime ⊆ primeFactors(N)
  have h_sub : (range (B + 1)).filter Nat.Prime ⊆ N.primeFactors := by
    intro p hp
    simp only [mem_filter, mem_range] at hp
    exact hN₁ N hHC (by omega) p hp.2 (by omega)
  -- All Euler factors in [0,1]
  have hf0 : ∀ x ∈ N.primeFactors, 0 ≤ 1 - 1/(x:ℝ) := fun x hx => by
    have := (Nat.prime_of_mem_primeFactors hx).one_le
    linarith [show (0:ℝ) ≤ 1/(x:ℝ) from div_nonneg one_pos.le (Nat.cast_nonneg' x),
              show 1/(x:ℝ) ≤ 1 from by
                rw [div_le_one (show (0:ℝ) < x from by
                  exact_mod_cast (Nat.prime_of_mem_primeFactors hx).pos)]
                exact_mod_cast (Nat.prime_of_mem_primeFactors hx).one_le]
  have hf1 : ∀ x ∈ N.primeFactors, 1 - 1/(x:ℝ) ≤ 1 := fun x _ => by
    linarith [show (0:ℝ) ≤ 1/(x:ℝ) from div_nonneg one_pos.le (Nat.cast_nonneg' x)]
  -- Step 4: Π_{pf(N)} ≤ Π_{range(B+1) filter prime} < ε
  have h_le := prod_le_prod_of_superset N.primeFactors
    ((range (B + 1)).filter Nat.Prime) h_sub (fun p => 1 - 1/(p:ℝ)) hf0 hf1
  have h_target := hB (B + 1) (by omega)
  rw [Real.dist_eq, sub_zero, abs_of_nonneg (Finset.prod_nonneg fun p hp => by
    have := (mem_filter.mp hp).2
    linarith [show (0:ℝ) ≤ 1/(p:ℝ) from div_nonneg one_pos.le (Nat.cast_nonneg' p),
              show 1/(p:ℝ) ≤ 1 from by
                rw [div_le_one (show (0:ℝ) < p from by exact_mod_cast this.pos)]
                exact_mod_cast this.one_le])] at h_target
  linarith

-- ════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════

/-!
## Audit (May 12, 2026)

### Sorry: 0 ✅
### Axioms: 1
- `hc_primeFactors_eventually_contain`: HC numbers eventually contain
  all primes up to any bound. Follows from the prime swap theorem.

### Proved:
- `mertens_product_tendsto_zero` — Π_{p<X}(1-1/p) → 0 ✅
- `mertens_hc_product_tendsto_zero_proved` — Π_{p|N_hc}(1-1/p) → 0 ✅

### Architecture:
```
  cathedral_mertens_third (MertensBridge, PROVED)
       ↓
  mertens_product_tendsto_zero (PROVED: Π → 0 from ln·Π → e^{-γ})
       ↓
  hc_primeFactors_eventually_contain (AXIOM — prime swap)
       ↓
  mertens_hc_product_tendsto_zero_proved (PROVED: Π_{pf(N_hc)} → 0)
       ↓
  [replaces mertens_hc_product_tendsto_zero in HCEulerProduct.lean]
```

### Axiom graduation path:
`hc_primeFactors_eventually_contain` can be graduated by proving the
prime swap theorem: if p | N_hc and q < p prime with q ∤ N_hc, then
M = N/p · q has d(M) ≥ d(N) and M < N. This requires:
- Divisor count multiplicativity: d(a·b) = d(a)·d(b) for coprime a,b
- Factorization arithmetic: v_p(N/p) = v_p(N) - 1
- The key inequality: 2·v_p(N) ≥ v_p(N) + 1 for v_p(N) ≥ 1
-/

end Cathedral.Covariance.HCPrimeStructure
