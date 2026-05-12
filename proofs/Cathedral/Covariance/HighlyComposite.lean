/-
  Cathedral/Covariance/HighlyComposite.lean

  ## Highly Composite Numbers: Formalization and Subsequence Existence

  A highly composite number (HC number) is a positive integer N such that
  every positive integer M < N has strictly fewer divisors than N:

    IsHighlyComposite N ↔ ∀ M, 0 < M → M < N → (Nat.divisors M).card < (Nat.divisors N).card

  ### Key Results

  1. `IsHighlyComposite` — the predicate
  2. `isHighlyComposite_one` — 1 is HC
  3. `isHighlyComposite_two` — 2 is HC
  4. `hc_pos` — HC numbers are positive
  5. `exists_hc_ge` — for every N, there exists an HC number ≥ N
  6. `hcSubseq` — an unbounded HC subsequence
  7. `hcSubseq_tendsto` — the subsequence tends to infinity

  Created: May 12, 2026 — Exploration 36
  Status: PROVED. 0 sorry, 0 axioms.
-/

import Mathlib.NumberTheory.Divisors
import Mathlib.Data.Finset.Max
import Mathlib.Order.Filter.AtTopBot.Archimedean

noncomputable section
open Finset Filter

namespace Cathedral.Covariance

-- ════════════════════════════════════════════════
-- §1. THE DEFINITION
-- ════════════════════════════════════════════════

/-- A positive integer N is **highly composite** if every smaller positive
    integer has strictly fewer divisors.

    This is the standard definition from Ramanujan (1915).
    Equivalently: N achieves a new record for the divisor count function d(n). -/
def IsHighlyComposite (N : ℕ) : Prop :=
  0 < N ∧ ∀ M : ℕ, 0 < M → M < N → #(Nat.divisors M) < #(Nat.divisors N)

-- ════════════════════════════════════════════════
-- §2. BASE CASES
-- ════════════════════════════════════════════════

/-- 1 is highly composite (vacuously — no positive integer < 1). -/
theorem isHighlyComposite_one : IsHighlyComposite 1 :=
  ⟨Nat.one_pos, fun _ _ hM => absurd hM (by omega)⟩

/-- 2 is highly composite. d(2) = 2 > d(1) = 1. -/
theorem isHighlyComposite_two : IsHighlyComposite 2 := by
  constructor
  · omega
  · intro M hM_pos hM_lt
    -- M = 1 is the only possibility
    have hM1 : M = 1 := by omega
    subst hM1
    decide

-- ════════════════════════════════════════════════
-- §3. BASIC PROPERTIES
-- ════════════════════════════════════════════════

/-- HC numbers are positive. -/
theorem hc_pos {N : ℕ} (h : IsHighlyComposite N) : 0 < N := h.1

/-- If N is HC, then N ≥ 1. -/
theorem hc_ge_one {N : ℕ} (h : IsHighlyComposite N) : 1 ≤ N :=
  h.1

-- ════════════════════════════════════════════════
-- §4. EXISTENCE OF HC NUMBERS BEYOND ANY BOUND
-- ════════════════════════════════════════════════

/-- Among {1,...,N}, the smallest number achieving the maximum divisor count
    is highly composite, and its divisor count is at least d(k) for all k ≤ N. -/
private lemma hc_from_max_divisors_strong (N : ℕ) (hN : 1 ≤ N) :
    ∃ M, M ≤ N ∧ IsHighlyComposite M ∧
      ∀ k, 1 ≤ k → k ≤ N → #(Nat.divisors k) ≤ #(Nat.divisors M) := by
  -- Find the element in {1,...,N} with maximum divisor count
  have hne : (Icc 1 N).Nonempty := ⟨1, mem_Icc.mpr ⟨le_refl 1, hN⟩⟩
  obtain ⟨M₀, hM₀_mem, hM₀_max⟩ := Finset.exists_max_image (Icc 1 N)
    (fun n => #(Nat.divisors n)) hne
  have hM₀_pos : 0 < M₀ := by have := (mem_Icc.mp hM₀_mem).1; omega
  have hM₀_le : M₀ ≤ N := (mem_Icc.mp hM₀_mem).2
  -- Among all n with d(n) = d(M₀), take the smallest. That one is HC.
  -- Use Nat.find to get the smallest
  have hex : ∃ m, m ∈ Icc 1 N ∧ #(Nat.divisors m) = #(Nat.divisors M₀) :=
    ⟨M₀, hM₀_mem, rfl⟩
  -- Get the minimum of the set S = {n ∈ Icc 1 N | d(n) = d(M₀)}
  let S := (Icc 1 N).filter (fun n => #(Nat.divisors n) = #(Nat.divisors M₀))
  have hS_ne : S.Nonempty := ⟨M₀, Finset.mem_filter.mpr ⟨hM₀_mem, rfl⟩⟩
  -- S is a Finset ℕ, so we can take its min
  set M := S.min' hS_ne
  have hM_mem : M ∈ S := Finset.min'_mem S hS_ne
  have hM_icc : M ∈ Icc 1 N := (Finset.mem_filter.mp hM_mem).1
  have hM_eq : #(Nat.divisors M) = #(Nat.divisors M₀) :=
    (Finset.mem_filter.mp hM_mem).2
  have hM_min : ∀ n ∈ S, M ≤ n := fun n hn => Finset.min'_le S n hn
  have hM_pos : 0 < M := by have := (mem_Icc.mp hM_icc).1; omega
  have hM_le : M ≤ N := (mem_Icc.mp hM_icc).2
  -- d(M) = d(M₀) ≥ d(k) for all k ∈ {1,...,N}
  have hM_global_max : ∀ k, 1 ≤ k → k ≤ N → #(Nat.divisors k) ≤ #(Nat.divisors M) := by
    intro k hk1 hkN
    rw [hM_eq]
    exact hM₀_max k (mem_Icc.mpr ⟨hk1, hkN⟩)
  -- M is HC: for any 0 < k < M, d(k) < d(M)
  refine ⟨M, hM_le, ⟨hM_pos, fun k hk_pos hk_lt => ?_⟩, hM_global_max⟩
  have hk_le_N : k ≤ N := le_trans (le_of_lt hk_lt) hM_le
  have hk_le := hM₀_max k (mem_Icc.mpr ⟨hk_pos, hk_le_N⟩)
  -- If d(k) ≥ d(M), then d(k) = d(M₀), so k ∈ S, so M ≤ k, contradicting k < M
  by_contra h_not_lt
  push Not at h_not_lt
  have hk_eq : #(Nat.divisors k) = #(Nat.divisors M₀) := by omega
  have hk_in_S : k ∈ S := Finset.mem_filter.mpr ⟨mem_Icc.mpr ⟨hk_pos, hk_le_N⟩, hk_eq⟩
  have := hM_min k hk_in_S
  omega

/-- **THEOREM**: For every N, there exists a highly composite number ≥ N.

    Proof: d(2^(D+1)) = D+2 > D = max d(k) for k ≤ N, so d is unbounded.
    The smallest achiever of the new max is HC and must exceed N. -/
theorem exists_hc_ge (N : ℕ) :
    ∃ M, N ≤ M ∧ IsHighlyComposite M := by
  -- For N = 0, use M = 1
  match N with
  | 0 => exact ⟨1, Nat.zero_le 1, isHighlyComposite_one⟩
  | Nat.succ n =>
  -- For n+1 ≥ 1:
  set N' := n + 1 with hN'_def
  have hN'_pos : 1 ≤ N' := by omega
  -- Step 1: Let D = max d(k) for k ∈ {1,...,N'}
  obtain ⟨M_pre, _, _, hM_pre_max⟩ := hc_from_max_divisors_strong N' hN'_pos
  -- D is the maximum divisor count on {1,...,N'}
  -- We bound it by the value at M_pre
  let D := #(Nat.divisors M_pre)
  -- Step 2: d(2^(D+1)) = D + 2 > D
  set K := 2 ^ (D + 1) with hK_def
  have hK_pos : 1 ≤ K := Nat.one_le_two_pow
  have hd_K : #(Nat.divisors K) = D + 2 := by
    rw [hK_def, Nat.divisors_prime_pow Nat.prime_two]
    simp [Finset.card_map, Finset.card_range]
  -- Step 3: K₃ = max(N', K), find HC in {1,...,K₃}
  set K₃ := max N' K with hK₃_def
  have hK₃_pos : 1 ≤ K₃ := le_trans hK_pos (le_max_right N' K)
  obtain ⟨M₂, hM₂_le, hM₂_hc, hM₂_max⟩ := hc_from_max_divisors_strong K₃ hK₃_pos
  by_cases hM₂_ge : N' ≤ M₂
  · exact ⟨M₂, hM₂_ge, hM₂_hc⟩
  · -- M₂ < N'. Contradiction: d(M₂) ≥ d(K) > D ≥ d(M₂)
    push Not at hM₂_ge
    exfalso
    -- d(M₂) ≤ D since M₂ < N', hence M₂ ≤ N', so d(M₂) ≤ d(M_pre) = D
    have hM₂_le_D : #(Nat.divisors M₂) ≤ D :=
      hM_pre_max M₂ (hc_ge_one hM₂_hc) (le_of_lt hM₂_ge)
    -- d(M₂) ≥ d(K) since K ∈ {1,...,K₃} and M₂ has max d on {1,...,K₃}
    have hM₂_ge_K : #(Nat.divisors K) ≤ #(Nat.divisors M₂) :=
      hM₂_max K hK_pos (le_max_right N' K)
    -- d(K) = D + 2 > D ≥ d(M₂), contradiction
    omega

-- ════════════════════════════════════════════════
-- §5. THE HC SUBSEQUENCE
-- ════════════════════════════════════════════════

/-- Build an unbounded HC subsequence. -/
noncomputable def hcSubseq : ℕ → ℕ :=
  fun n => (exists_hc_ge (n + 1)).choose

/-- Each element of the HC subsequence is highly composite. -/
theorem hcSubseq_isHC (n : ℕ) : IsHighlyComposite (hcSubseq n) :=
  (exists_hc_ge (n + 1)).choose_spec.2

/-- The HC subsequence is eventually at least n+1, hence unbounded. -/
theorem hcSubseq_ge (n : ℕ) : n + 1 ≤ hcSubseq n :=
  (exists_hc_ge (n + 1)).choose_spec.1

/-- The HC subsequence tends to infinity. -/
theorem hcSubseq_tendsto : Tendsto hcSubseq atTop atTop := by
  rw [Filter.tendsto_atTop_atTop]
  intro b
  exact ⟨b, fun n hn => le_trans (by omega) (hcSubseq_ge n)⟩

/-- Each element of the HC subsequence is ≥ 3 for n ≥ 2. -/
theorem hcSubseq_ge_three (n : ℕ) (hn : 2 ≤ n) : 3 ≤ hcSubseq n :=
  le_trans (by omega) (hcSubseq_ge n)

-- ════════════════════════════════════════════════
-- AUDIT — 0 sorry ✓
-- ════════════════════════════════════════════════

/-!
## Audit — 0 sorry ✓

### Sorry: 0
### Axioms: 0

### Architecture:
```
  IsHighlyComposite (predicate) ─────┐
  isHighlyComposite_one (PROVED) ────┤
  isHighlyComposite_two (PROVED) ────┤
  hc_pos (PROVED) ──────────────────┤
  hc_from_max_divisors_strong (PROVED) ──┤
                                     ↓
  exists_hc_ge (PROVED) ───────────→ hcSubseq (DEF)
                                     │
                                     ↓
                            hcSubseq_tendsto (PROVED)
                                     │
                                     ↓
                        gram_form_upper_bound_subseq (TARGET)
```

### Key lemmas:
- `hc_from_max_divisors_strong`: Among {1,...,N}, the smallest number
  achieving max d(n) is HC, and d(M) ≥ d(k) for all k ≤ N.
- `exists_hc_ge`: Uses d(2^(D+1)) = D+2 > D to prove d(n) unbounded,
  then the strong helper to extract an HC number exceeding any bound.
-/

end Cathedral.Covariance
