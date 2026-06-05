/-
  Cathedral/Geometry/SquarefreeCountBound.lean

  ## GRADUATING sqfreeCount_ge_third: Q(N) ≥ N/3

  ════════════════════════════════════════════════════════════════

  THE PROOF STRATEGY (Prime Square Sieve):

  Every non-squarefree k has a prime p with p²|k.
  By union bound: #{non-sqfree ≤ N} ≤ Σ_p #{p²|k, k ≤ N} = Σ_p ⌊N/p²⌋.
  Each ⌊N/p²⌋ ≤ N/p² (Nat.cast_div_le).
  Using Σ 1/p² ≤ 1/2 (proved in SquarefreeReciprocal.lean):
    #{non-sqfree ≤ N} ≤ N/2.
  Therefore: Q(N) = N − #{non-sqfree} ≥ N − N/2 ≥ N/3.

  STATUS: Graduates sqfreeCount_ge_third axiom.
  Created: June 5, 2026 — Sub-Axiom Graduation Campaign 🛡️
-/

import Cathedral.NumberTheory.SquarefreeReciprocal
import Cathedral.NumberTheory.DirichletConvolution
import Cathedral.Geometry.NormLowerBound

set_option maxHeartbeats 800000

noncomputable section
open Real Finset

namespace Cathedral.Geometry.SquarefreeCountBound

-- Use the NormLowerBound version of sqfreeCount
open Cathedral.Geometry.NormLowerBound in
-- Re-export for clarity
abbrev sqfreeCount' := @NormLowerBound.sqfreeCount

-- ════════════════════════════════════════════════════════════════
-- §1. PARTITION IDENTITY
-- ════════════════════════════════════════════════════════════════

/-- The non-squarefree counting function. -/
def nonsqfreeCount (N : ℕ) : ℕ :=
  ((Icc 1 N).filter (fun k => ¬Squarefree k)).card

/-- **PARTITION**: sqfreeCount + nonsqfreeCount = N for N ≥ 1. -/
theorem sqfree_partition (N : ℕ) (hN : 1 ≤ N) :
    NormLowerBound.sqfreeCount N + nonsqfreeCount N = N := by
  unfold NormLowerBound.sqfreeCount nonsqfreeCount
  have h := (Icc 1 N).card_filter_add_card_filter_not (fun k => Squarefree k)
  simp only [Nat.card_Icc] at h
  omega

-- ════════════════════════════════════════════════════════════════
-- §2. THE PRIME SIEVE
-- ════════════════════════════════════════════════════════════════

/-- Every non-squarefree k in [1,N] belongs to the biUnion of
    {multiples of p² in [1,N]} over primes p. -/
theorem nonsqfree_subset_biUnion (N : ℕ) :
    (Icc 1 N).filter (fun k => ¬Squarefree k) ⊆
    ((Icc 2 N).filter Nat.Prime).biUnion
      (fun p => (Icc 1 N).filter (fun k => p ^ 2 ∣ k)) := by
  intro k hk
  rw [Finset.mem_filter] at hk
  rw [Finset.mem_biUnion]
  obtain ⟨hk_range, hk_nsf⟩ := hk
  rw [Nat.squarefree_iff_prime_squarefree] at hk_nsf
  push Not at hk_nsf
  obtain ⟨p, hp, hpk⟩ := hk_nsf
  have hk_pos : 0 < k := by
    rw [Finset.mem_Icc] at hk_range; omega
  have hk_le : k ≤ N := (Finset.mem_Icc.mp hk_range).2
  have hp_pos : 0 < p := hp.pos
  have hp_le : p ≤ N := by
    have : p * p ≤ k := Nat.le_of_dvd hk_pos hpk
    have : p ≤ p * p := Nat.le_mul_of_pos_right p hp_pos
    omega
  refine ⟨p, Finset.mem_filter.mpr ⟨Finset.mem_Icc.mpr ⟨hp.two_le, hp_le⟩, hp⟩, ?_⟩
  rw [Finset.mem_filter]
  exact ⟨hk_range, by rwa [sq]⟩

-- ════════════════════════════════════════════════════════════════
-- §3. THE COUNT BOUNDS
-- ════════════════════════════════════════════════════════════════

/-- **UNION BOUND ON COUNTS**: nonsqfreeCount N ≤ Σ_p N/p². -/
theorem nonsqfreeCount_le_sum (N : ℕ) :
    nonsqfreeCount N ≤
    ∑ p ∈ (Icc 2 N).filter Nat.Prime, N / p ^ 2 := by
  unfold nonsqfreeCount
  calc ((Icc 1 N).filter (fun k => ¬Squarefree k)).card
      ≤ (((Icc 2 N).filter Nat.Prime).biUnion
           (fun p => (Icc 1 N).filter (fun k => p ^ 2 ∣ k))).card :=
        Finset.card_le_card (nonsqfree_subset_biUnion N)
    _ ≤ ∑ p ∈ (Icc 2 N).filter Nat.Prime,
          ((Icc 1 N).filter (fun k => p ^ 2 ∣ k)).card :=
        Finset.card_biUnion_le
    _ = ∑ p ∈ (Icc 2 N).filter Nat.Prime, N / p ^ 2 := by
        apply Finset.sum_congr rfl
        intro p hp
        rw [Finset.mem_filter] at hp
        have hp_pos : 0 < p := by
          have := hp.1
          rw [Finset.mem_Icc] at this; omega
        have hp2 : 1 ≤ p ^ 2 := Nat.one_le_pow 2 p hp_pos
        exact card_Icc_filter_dvd (p ^ 2) N hp2

-- ════════════════════════════════════════════════════════════════
-- §4. THE REAL-VALUED BOUND
-- ════════════════════════════════════════════════════════════════

/-- **SUM BOUND**: Σ_p (N/p² : ℕ) ≤ N/2 (via casting to ℝ). -/
theorem sum_div_sq_le_half (N : ℕ) :
    ∑ p ∈ (Icc 2 N).filter Nat.Prime, N / p ^ 2 ≤ N / 2 := by
  -- Strategy: show 2 * sum ≤ N using ℝ, then conclude sum ≤ N/2 in ℕ
  set s := ∑ p ∈ (Icc 2 N).filter Nat.Prime, N / p ^ 2
  -- Step 1: (s : ℝ) ≤ (N : ℝ) / 2
  have hs_real : (↑s : ℝ) ≤ (↑N : ℝ) / 2 := by
    calc (↑s : ℝ)
        = ∑ p ∈ (Icc 2 N).filter Nat.Prime, (↑(N / p ^ 2) : ℝ) := by
          simp only [s, Nat.cast_sum]
      _ ≤ ∑ p ∈ (Icc 2 N).filter Nat.Prime, (↑N : ℝ) / (↑p : ℝ) ^ 2 := by
          apply Finset.sum_le_sum
          intro p _hp
          -- Need: ↑(N / p²) ≤ ↑N / (↑p)²
          -- Nat.cast_div_le gives ↑(N / p²) ≤ ↑N / ↑(p²)
          -- And ↑(p²) = (↑p)² by push_cast
          have : (↑(N / p ^ 2) : ℝ) ≤ ↑N / ↑(p ^ 2) := Nat.cast_div_le
          simp only [Nat.cast_pow] at this
          exact this
      _ = (↑N : ℝ) * ∑ p ∈ (Icc 2 N).filter Nat.Prime, (1 : ℝ) / (↑p : ℝ) ^ 2 := by
          rw [Finset.mul_sum]; congr 1; ext p; ring
      _ ≤ (↑N : ℝ) * (1 / 2) := by
          apply mul_le_mul_of_nonneg_left
          · exact Cathedral.NumberTheory.SquarefreeReciprocal.prime_sq_reciprocal_le_half N
          · exact Nat.cast_nonneg _
      _ = (↑N : ℝ) / 2 := by ring
  -- Step 2: Cast back to ℕ
  -- From (s : ℝ) ≤ N/2, get 2*s ≤ N in ℝ, then in ℕ
  rw [Nat.le_div_iff_mul_le (by norm_num : 0 < 2)]
  -- Goal: s * 2 ≤ N
  have h2s : (↑(s * 2) : ℝ) ≤ ↑N := by
    push_cast; linarith
  exact_mod_cast h2s

-- ════════════════════════════════════════════════════════════════
-- §5. THE MAIN THEOREM
-- ════════════════════════════════════════════════════════════════

/-- **NONSQUAREFREE COUNT BOUND**: #{non-sqfree ≤ N} ≤ N/2. -/
theorem nonsqfreeCount_le_half (N : ℕ) :
    nonsqfreeCount N ≤ N / 2 := by
  calc nonsqfreeCount N
      ≤ ∑ p ∈ (Icc 2 N).filter Nat.Prime, N / p ^ 2 := nonsqfreeCount_le_sum N
    _ ≤ N / 2 := sum_div_sq_le_half N

/-- **THE GRADUATION TARGET**: Q(N) ≥ N/3 for all N ≥ 1.

    Proof: Q(N) = N − #{non-sqfree} ≥ N − N/2 ≥ N/3.

    This graduates the axiom `sqfreeCount_ge_third` from
    NormLowerBound.lean. -/
theorem sqfreeCount_ge_third_proved :
    ∀ N : ℕ, 1 ≤ N → N / 3 ≤ NormLowerBound.sqfreeCount N := by
  intro N hN
  have hpart := sqfree_partition N hN
  have hnsf := nonsqfreeCount_le_half N
  omega

-- ════════════════════════════════════════════════════════════════
-- §6. AUDIT
-- ════════════════════════════════════════════════════════════════

/-!
## Audit (June 5, 2026 — Sub-Axiom Graduation: sqfreeCount)

### Sorry: 0 ✅

### Custom Axioms: 0

### Key Imports Used:
  - `prime_sq_reciprocal_le_half` from SquarefreeReciprocal.lean
  - `card_Icc_filter_dvd` from DirichletConvolution.lean
  - `Finset.card_biUnion_le` from Mathlib
  - `Nat.cast_div_le` from Mathlib

### Theorems PROVED:
| # | Result | Status | Content |
|---|--------|--------|---------|
| 1 | `sqfree_partition` | ✅ | Q + Q̄ = N |
| 2 | `nonsqfree_subset_biUnion` | ✅ | non-sqfree ⊆ ⋃ p²-multiples |
| 3 | `nonsqfreeCount_le_sum` | ✅ | union bound on counts |
| 4 | `sum_div_sq_le_half` | ✅ | Σ N/p² ≤ N/2 |
| 5 | `nonsqfreeCount_le_half` | ✅ | #{non-sqfree} ≤ N/2 |
| 6 | `sqfreeCount_ge_third_proved` | ✅ | N/3 ≤ Q(N) |

### The Chain:
```
card_Icc_filter_dvd: #{d|k, k≤N} = N/d       [PROVED in DirichletConvolution]
    ↓
prime_sq_reciprocal_le_half: Σ 1/p² ≤ 1/2     [PROVED in SquarefreeReciprocal]
    ↓ + Nat.cast_div_le (Mathlib)
sum_div_sq_le_half: Σ N/p² ≤ N/2              [PROVED]
    ↓ + card_biUnion_le (Mathlib)
nonsqfreeCount_le_half: #{non-sqfree} ≤ N/2    [PROVED]
    ↓ + sqfree_partition [PROVED]
sqfreeCount_ge_third_proved: Q(N) ≥ N/3        [PROVED ✅]
```
-/

end Cathedral.Geometry.SquarefreeCountBound

end
