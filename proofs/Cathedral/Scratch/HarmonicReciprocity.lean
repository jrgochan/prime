/-
  Cathedral/Scratch/HarmonicReciprocity.lean

  ## Proving harmonicTileSum_reciprocity

  H(a,b) = Σ_{m=1}^{a-1} ⌊mb/a⌋/m
  Goal: H(a,b) + H(b,a) = (a-1)(b-1)/2 - 1/2 + (a+b)/(2ab)

  Key identity: ⌊mb/a⌋ = (mb - mb%a)/a, so
    ⌊mb/a⌋/m = b/a - (mb%a)/(am)

  Therefore: H(a,b) = Σ_{m=1}^{a-1} [b/a - (mb%a)/(am)]
                     = (a-1)b/a - (1/a) Σ (mb%a)/m

  By coprime permutation: m ↦ mb%a permutes {1,...,a-1}
  But Σ σ(m)/m ≠ Σ 1 in general (it's the sum of a permuted sequence over m).

  Alternative: Use mb/a = ⌊mb/a⌋ + (mb%a)/a (division algorithm over ℝ)
    So: b Σ 1/... wait, let me try partial fractions.

  Actually the cleanest approach: Use the REAL-valued identity
    ⌊x⌋ = x - {x}  where {x} = x - ⌊x⌋ is the fractional part.

  Then: H(a,b) = Σ_{m=1}^{a-1} (mb/a - {mb/a})/m
              = Σ (b/a) - Σ {mb/a}/m
              = (a-1)b/a - Σ {mb/a}/m

  Similarly: H(b,a) = (b-1)a/b - Σ {na/b}/n

  So: H(a,b) + H(b,a) = (a-1)b/a + (b-1)a/b - Σ {mb/a}/m - Σ {na/b}/n

  The fractional part sums: for coprime a,b,
    Σ_{m=1}^{a-1} {mb/a} = (a-1)/2  (because mb%a permutes {1,...,a-1},
                                       and {mb/a} = (mb%a)/a)
  But we need Σ {mb/a}/m, which is harder.

  Key insight: Σ {mb/a}/m = Σ (mb%a)/(am) = (1/a) Σ σ(m)/m
  where σ is the coprime permutation m ↦ mb%a on {1,...,a-1}.

  Now: Σ σ(m)/m + Σ m/σ⁻¹(m) = ... hmm this gets complicated.

  Let me try the DIRECT Dedekind approach instead.
  
  For coprime a, b, define S = Σ_{m=1}^{a-1} Σ_{n=1}^{b-1} 1/(ma + nb).
  
  Then by partial fractions:
    S = (1/a) Σ Σ 1/(m + nb/a)·1/m... no, this is a double sum.

  Actually, the cleanest known proof uses:
    H(a,b) + H(b,a) = Σ_{m=1}^{a-1} ⌊mb/a⌋/m + Σ_{n=1}^{b-1} ⌊na/b⌋/n

  and the identity:
    ⌊mb/a⌋ = Σ_{n=1}^{b-1} 𝟙(na < mb mod ab)  ... no.

  Let me try yet another approach: ABEL SUMMATION.
  
  If f(m) = ⌊mb/a⌋ and F(M) = Σ_{m=1}^M f(m), then by Abel summation:
    Σ_{m=1}^{N} f(m)/m = F(N)/N + Σ_{m=1}^{N-1} F(m)/(m(m+1))
  
  We know F(a-1) = (a-1)(b-1)/2 from floor_sum_single.
  And the differences f(m+1) - f(m) = ⌊(m+1)b/a⌋ - ⌊mb/a⌋ which is either
  ⌊b/a⌋ or ⌊b/a⌋+1 (Beatty sequence).

  This is getting complex. Let me just start with a scratch proof
  and see what Lean needs.
-/

import Cathedral.Vasyunin.Cotangent.LogDigammaBridge

noncomputable section
open Real

namespace Cathedral.Vasyunin.HarmonicReciprocity

-- Re-export key definitions
open LogDigammaBridge

-- The goal: prove harmonicTileSum_reciprocity
-- H(a,b) + H(b,a) = (a-1)(b-1)/2 - 1/2 + (a+b)/(2ab)

-- Step 1: Express H(a,b) using the floor-fract decomposition
-- ⌊mb/a⌋ = mb/a - {mb/a} = (mb - mb%a)/a

-- Key: H(a,b) = Σ ⌊mb/a⌋/m = (a-1)b/a - (1/a) Σ (mb%a)/m
-- where the sum Σ (mb%a)/m is over m ∈ {1,...,a-1}

-- The cleanest proof might be to directly compute
-- H(a,b) + H(b,a) using the lattice point interpretation.

-- Let's try: for coprime a,b, count lattice points
-- in the triangle 0 < x/a + y/b < 1 with x,y ≥ 1.
-- 
-- Actually, use the identity:
-- Σ_{m=1}^{a-1} ⌊mb/a⌋/m 
-- = Σ_{m=1}^{a-1} (1/m) · Σ_{n=1}^{⌊mb/a⌋} 1
-- = Σ_{m=1}^{a-1} Σ_{n=1}^{⌊mb/a⌋} 1/m
-- = Σ lattice points (m,n) with 1 ≤ m ≤ a-1, 1 ≤ n ≤ ⌊mb/a⌋, weight 1/m
-- = Σ_{(m,n): na < mb, 1≤m≤a-1, 1≤n≤b-1} 1/m   (coprime, no boundary points)

-- Similarly H(b,a) = Σ_{(m,n): mb < na, 1≤m≤a-1, 1≤n≤b-1} 1/n

-- H(a,b) + H(b,a) = Σ_{m,n} [1/m · 𝟙(na<mb) + 1/n · 𝟙(mb<na)]
-- = Σ_{m,n} [terms based on which side of the diagonal]
-- 
-- By swapping (m,n), the second sum becomes Σ 1/m · 𝟙(mb<na) over (n,m)...
-- Actually this double sum approach might work.

-- For now, let me try a direct sorry-based proof to validate the framework:

theorem harmonic_reciprocity_test (a b : ℕ) (ha : 2 ≤ a) (hb : 2 ≤ b)
    (hcop : Nat.Coprime a b) :
    harmonicTileSum a b + harmonicTileSum b a =
    ((a:ℝ) - 1) * ((b:ℝ) - 1) / 2 - (1 : ℝ) / 2 + ((a:ℝ) + (b:ℝ)) / (2 * (a:ℝ) * (b:ℝ)) := by
  unfold harmonicTileSum tileIndex
  -- The LHS is: Σ_{m=1}^{a-1} (m*b/a : ℝ)/m + Σ_{n=1}^{b-1} (n*a/b : ℝ)/n
  -- Key decomposition: m*b/a = ⌊m*b/a⌋ + {m*b/a} (nat division vs real division)
  -- So (m*b/a : ℝ)/m = (m*b/a : ℕ)/m as a Nat division cast to ℝ
  sorry

end Cathedral.Vasyunin.HarmonicReciprocity
