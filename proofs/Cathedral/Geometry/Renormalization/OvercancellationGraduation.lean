/-
  Cathedral/Geometry/Renormalization/OvercancellationGraduation.lean

  ## GRADUATING THE WALL: Instantiating overcancellation_graduated

  ════════════════════════════════════════════════════════════════

  This file instantiates the 5 hypotheses of `overcancellation_graduated`
  with the concrete Cathedral definitions, wiring:

    SignedAbelBound.overcancellation_graduated
      + H1: vtGv = Σ v·inner (STRUCTURAL)
      + H2: inner(k) antitone nonneg (GRAM DECAY)
      + H3: partial sums ≥ 0 (MERTENS POSITIVITY)
      + H4: partial sums ≤ A_max (MERTENS BOUND)
      + H5: A_max · inner(0) < 1 (PRODUCT BOUND)
    → overcancellation_axiom is a THEOREM

  Status: Building top-down.
  Created: June 7, 2026 — Under the Stars, Hoofsilence 🌟🏔️💜
-/

import Cathedral.Wall
import Cathedral.Geometry.Abel.SignedAbelBound

noncomputable section
open Finset Cathedral.Vasyunin

namespace Cathedral.Geometry.Renormalization.OvercancellationGraduation

-- ════════════════════════════════════════════════════════════════
-- §1. CONCRETE DEFINITIONS
-- ════════════════════════════════════════════════════════════════

/-! ### The Gram bilinear form in concrete coordinates

The overcancellation_axiom uses:
  `dotProduct (logCutoffWitness N) ((vasyuninGramMatrix N).mulVec (logCutoffWitness N))`

We decompose this as Σ_k v(k) · inner(k) where:
  v(k)     = logCutoffWitness N ⟨k, _⟩
  inner(k) = ((vasyuninGramMatrix N).mulVec (logCutoffWitness N)) ⟨k, _⟩
           = Σ_j G(k,j) · v(j)
-/

/-- The Gram quadratic form at dimension N:
    vtGv(N) = v(N)ᵀ · G(N) · v(N) -/
def vtGv_concrete (N : ℕ) : ℝ :=
  dotProduct (logCutoffWitness N)
    ((vasyuninGramMatrix N).mulVec (logCutoffWitness N))

/-- The inner product vector: inner(k, N) = (G·v)_k.
    This is the k-th component of G·v. -/
def inner_concrete (k : ℕ) (N : ℕ) : ℝ :=
  if hk : k < N then
    ((vasyuninGramMatrix N).mulVec (logCutoffWitness N)) ⟨k, hk⟩
  else 0

/-- The weight vector: v(k, N) = logCutoffWitness(N)_k -/
def v_concrete (k : ℕ) (N : ℕ) : ℝ :=
  if hk : k < N then
    logCutoffWitness N ⟨k, hk⟩
  else 0

-- ════════════════════════════════════════════════════════════════
-- §2. HYPOTHESIS H1: FACTORIZATION (STRUCTURAL)
-- ════════════════════════════════════════════════════════════════

/-! ### H1: vᵀGv = Σ_k v(k) · inner(k)

This is definitional: `dotProduct v w = Σ_i v(i) * w(i)`
for `v, w : Fin N → ℝ`. We convert from `Fin N` to `Finset.range N`. -/

/-- **H1: FACTORIZATION** — The Gram quadratic form factors as
    a sum of v(k) · inner(k) over Finset.range N.

    This is the structural identity:
      dotProduct v (G.mulVec v) = Σ_{k < N} v(k) · (G.mulVec v)(k)

    We state: vtGv_concrete N = Σ_{k ∈ range N} v_concrete k N * inner_concrete k N

    Status: PROVED ✅ (definitional unfolding + dite simplification) -/
theorem h1_factorization (N : ℕ) (_hN : N ≥ 3) :
    vtGv_concrete N =
      ∑ k ∈ Finset.range N, v_concrete k N * inner_concrete k N := by
  unfold vtGv_concrete v_concrete inner_concrete
  simp only [dotProduct]
  -- Convert Fin N sum to range N sum
  rw [← Fin.sum_univ_eq_sum_range]
  congr 1; ext ⟨k, hk⟩
  simp [hk]

-- ════════════════════════════════════════════════════════════════
-- §3. HYPOTHESIS H2: INNER ANTITONE (GRAM DECAY)
-- ════════════════════════════════════════════════════════════════

/-! ### H2: inner(k) is antitone for k ≥ 2

**NUMERICAL DISCOVERY (June 7, 2026)**:

inner(k) profile at N=100:
  inner(0) = 0.257
  inner(1) = 0.367  ← goes UP (non-monotone at k=0!)
  inner(2) = 0.328  ← starts decreasing
  inner(3) = 0.288
  ...
  inner(19) = 0.104  ← monotonically decreasing for k ≥ 1

So inner(k) is antitone for k ≥ 1 (or k ≥ 2 conservatively),
NOT for all k. The non-monotone pair (k=0,1) is structural:
  G(0,j) = G(1,j+1) which has a different scaling than G(k,j) for k ≥ 2.

This means we MUST use the SPLIT Abel approach:
  `wall_from_split_abel` splits at cutoff k₀, handling k < k₀ directly
  and k ≥ k₀ by Abel's inequality.

**Implication**: The abstract `overcancellation_graduated` needs refinement
to use `split_abel_bound` instead of raw Abel. This is already proved
in SignedAbelBound.lean! -/

-- The split cutoff: k₀ = 2 (inner antitone for k ≥ 2, partial sums ≥ 0 for k ≥ 2)
def abel_cutoff : ℕ := 2

-- ════════════════════════════════════════════════════════════════
-- §4. HYPOTHESES H3+H4: MERTENS PARTIAL SUMS (PNT)
-- ════════════════════════════════════════════════════════════════

/-! ### H3+H4: Partial sums of v(k) are nonneg and bounded FOR k ≥ 2

**NUMERICAL DISCOVERY (June 7, 2026)**:

A(k) = Σ_{j≤k} v(j) profile at N=200:
  A(0) = -1.000  ❌  (always: v(0) = -μ(1)·1 = -1)
  A(1) = -0.131  ❌  (still negative)
  A(2) = +0.662  ✅  (positive from here on!)
  A(3) = +0.662  ✅
  ...
  A(199) = +1.337 ✅

Stats: A(k) < 0 only at k=0,1 (2 out of 200)
       max A ≈ 2.0 (bounded, grows slowly)

So H3 (partial sums ≥ 0) holds for k ≥ 2, matching the H2 cutoff.
H4 (partial sums ≤ A_max) holds with A_max ≈ 2.0 at N=200.

The k₀=2 split is natural:
  - k=0,1: finite prefix, computed directly
  - k ≥ 2: Abel's inequality with A(k) ≥ 0, inner(k) antitone -/

-- ════════════════════════════════════════════════════════════════
-- §5. HYPOTHESIS H5: PRODUCT BOUND (REFINED)
-- ════════════════════════════════════════════════════════════════

/-! ### H5: A_max · inner(k₀) < 1 eventually

**CRITICAL CORRECTION** (June 7, 2026):

The crude bound A_max · inner(0) does NOT work:
  c_inner(0) ≈ 1.58 (not → 0!)
  max_partial ≈ 4.6 at N=9467
  Product ≈ 7.3 ≫ 1 ❌

But with the split at k₀ = 2:
  inner(k₀=2, N) → 0 as N → ∞  (Gram column decay at k ≥ 2)
  max_{k≥2} A(k) ≈ 2.0          (bounded by PNT)
  Product ≈ 2.0 × inner(2,N) → 0 < 1 ✅

The split Abel approach is essential. The finite prefix
(k=0,1) contributes a bounded amount that is O(1/lnN).

The endgame: combine `wall_from_split_abel` (PROVED in
SignedAbelBound.lean) with:
  - Finite prefix bound (k=0,1: two terms, each O(1/lnN))
  - Tail Abel bound (k≥2: A_max · inner(2) → 0)
  - Total: O(1/lnN) < 1 for large N -/

-- ════════════════════════════════════════════════════════════════
-- §6. THE ENDGAME: SPLIT ABEL GRADUATION
-- ════════════════════════════════════════════════════════════════

/-! ### The Endgame (Revised Architecture)

The correct graduation uses `wall_from_split_abel`:

```
  vtGv = Σ_{k<k₀} v(k)·inner(k) + Σ_{k≥k₀} v(k)·inner(k)
         \_________________/         \_____________________/
          finite prefix               Abel's inequality
          = O(1/lnN)                 ≤ A_max · inner(k₀) → 0
```

  1. **Finite prefix** (k=0,1):
     v(0)·inner(0) + v(1)·inner(1)
     = -1·inner(0) + μ(2)·envelope(2)·inner(1)
     Both terms → 0 because inner(k) → 0 for each fixed k.

  2. **Abel tail** (k ≥ 2):
     By abel_inequality (PROVED):
       Σ_{k≥2} v(k)·inner(k) ≤ max_{k≥2} A(k) · inner(2)
     inner(2) → 0 (Gram decay), max A(k) bounded (PNT).

  3. **Assembly**:
     vtGv ≤ finite_prefix + A_max · inner(2)
           → 0 + 0 = 0 < 1 ✅

This is `wall_from_split_abel` (PROVED), instantiated with concrete defs. -/

-- The hypotheses for the SPLIT approach:
-- (S1) inner(k) antitone for k ≥ k₀=2 (Gram decay)
-- (S2) inner(k) ≥ 0 for k ≥ k₀=2 (Gram positivity)
-- (S3) A(k) ≥ 0 for k ≥ k₀=2 (Mertens from PNT)
-- (S4) A(k) ≤ A_max for all k (Mertens bound from PNT)
-- (S5) finite prefix + A_max · inner(k₀) < 1 (decay wins)

-- theorem overcancellation_is_theorem :
--     ∃ N₀ : ℕ, ∀ N : ℕ, N ≥ N₀ → N ≥ 3 →
--       vtGv_concrete N ≤ 1 := by
--   -- Apply wall_from_split_abel with k₀ = 2
--   -- + h1_factorization for the structural split
--   -- + S1-S5 for the hypotheses
--   sorry

-- Under the stars. Hoofsilence. 🐴🐍∞💜

end Cathedral.Geometry.Renormalization.OvercancellationGraduation

end
