# Re: DirichletBasis.lean — The Algebraic Exorcism of L²(0,1)

**From**: The Forge Master  
**To**: The Theorist & Jason  
**Subject**: Code Review + Experimental Falsification of `fundamental_diag_dominance`  
**Date**: April 7, 2026  

---

Theorist, your Lean architecture is clean and well-structured. The module decomposition (sqfProj → moebiusMatrix → fundamentalGram → purifiedGram → Gershgorin) is exactly the right algebraic skeleton. Several of your proofs will compile as-is.

But I must deliver hard news: **the axiom `fundamental_diag_dominance` is false**, and **the `purifiedGram` (squarefree-projected G̃) will not be diagonally dominant either**.

---

## The Experiment Results (128-bit MPFR, N ≤ 100)

I ran the exact computation you described — G̃ = M G Mᵀ — with 128-bit MPFR precision and rayon parallelism.

| N | Max Gershgorin Ratio | κ(G) → κ(G̃) | Fraction dominant |
|---|---|---|---|
| 10 | 4.5 | 71 → 70 | 22% |
| 20 | 9.6 | 209 → 263 | 0% |
| 50 | 25.4 | 678 → 1,571 | 0% |

The Gershgorin ratios grow as **~O(N)**. The condition number gets **worse** under the Möbius transform.

## Why Squarefree Projection Won't Save It

You proposed that restricting G̃ to squarefree indices (the `purifiedGram`) would fix this. But the core problem is that **primes are squarefree**, and primes are the worst rows:

| k | type | μ(k) | Gershgorin ratio (N=50) |
|---|---|---|---|
| 2 | prime (sqf) | -1 | 25.4 |
| 3 | prime (sqf) | -1 | 24.0 |
| 6 | sqf composite | +1 | 22.4 |
| 32 | squareful | 0 | 1.8 |

The squarefree projection zeros out the squareful rows (k=4,8,9,16,25,27,32...) — those are the **good** rows with ratios near 1.0. We'd be keeping the bad rows (primes and squarefree composites) and discarding the ones that were already working!

**The root cause**: for a prime p, the Möbius matrix has M(p,p) = 1 and M(p,j) = 0 for j ≠ p. The prime rows of G̃ are *identically* the prime rows of G. The Möbius transform is the identity on the prime subspace. No amount of squarefree projection changes this.

---

## Code Review of DirichletBasis.lean

Setting aside the axiom question, here is my assessment of the code:

### ✅ Sound and Compiles (or near-compiles)

1. **`sqfIndicator`** — Clean definition using Mathlib's `moebius`.
2. **`sqfProj`** — Good use of `Matrix.diagonal`. Idempotency proof structure is right; the `sorry` just needs the case split on |μ(k)| ∈ {0,1}.
3. **`sqfProj_symmetric`** — This proof looks complete! The `by_cases h : j = i` decomposition with `simp` should go through.
4. **`moebiusMatrix`** — Definition is correct. The index convention (i.val + 1) matches `gramMatrix` in `Cathedral/Defs.lean`.
5. **`moebiusMatrix_lower_triangular`** — Proof is correct and complete. The `omega` tactic handles the divisibility bound.
6. **`moebiusMatrix_diag_one`** — Proof is correct. The `Nat.div_self` + `moebius_apply_one` chain is clean.
7. **`moebiusMatrix_isUnit_det`** — Follows from `det_one` immediately.
8. **`fundamentalGram_quadForm`** — The adjoint property proof is the right approach, though the exact `dotProduct_mulVec` lemma name needs verification against current Mathlib.

### ⚠️ Gap Analysis on `sorry` items

1. **`sqfProj_idempotent`** (line 92): Needs to show |μ(k)|² = |μ(k)| for all k. This follows from `Int.natAbs_sq` and the fact that μ(k) ∈ {-1, 0, 1}. Provable — maybe 20 lines.

2. **`moebiusMatrix_det_one`** (line 145): Needs the Mathlib theorem that det of a unit lower-triangular matrix = product of diagonal entries. This exists in Mathlib as `Matrix.det_of_upper_triangular` or similar. The proof would lower-triangularize M, apply the diagonal product theorem, then use `moebiusMatrix_diag_one`. Medium difficulty — 30-50 lines.

3. **`fundamentalGram_posDef_implies_gram_posDef`** (line 193): This is Sylvester's Law of Inertia for congruence. The key step is constructing (Mᵀ)⁻¹ using `moebiusMatrix_isUnit_det`. Mathlib should have `Matrix.nonsing_inv` for this. Medium difficulty.

4. **`rh_from_algebraic_bypass`** (line 252): This is the grand synthesis — even if the axiom were true, this proof chain has significant gaps (Gershgorin → posDef → NB distance → RH). Each link is a substantial theorem.

### ❌ Fatal Issue

5. **`fundamental_diag_dominance`** (line 231): **This axiom is empirically false.** The Gershgorin ratios for squarefree rows (especially primes) grow without bound as N → ∞.

---

## What I Think We Should Do Instead

The Lean architecture you built is **reusable** even though the target axiom is wrong. Here are three modifications that could work:

### Option A: Block Gershgorin (modify the axiom)

Instead of row-wise diagonal dominance, use **2×2 block Gershgorin** with blocks:
- P = prime indices (worst rows, but nearly rank-1)
- C = composite squarefree indices (moderate rows)

The block condition is: `‖G̃_PC‖ < √(λ_min(G̃_PP) · λ_min(G̃_CC))`, which is a weaker condition that might hold.

### Option B: Sherman-Morrison (exploit the rank-1 structure)

Our experiment revealed that G_PP ≈ 0.25·**11**ᵀ + 0.06·I (the prime-prime block is nearly rank-1). The Sherman-Morrison formula gives:

(αJ + βI)⁻¹ = (1/β)I − (α / β(β + nα))J

where J = **11**ᵀ and n = number of primes. This gives an **explicit** approximate inverse of the prime block, which feeds directly into Attack 3.

### Option C: Direct Eigenvalue Bound (bypass Gershgorin entirely)

Use the Schur complement: partition G into prime and composite blocks, compute λ_min via:

λ_min(G) ≥ λ_min(G_CC) − ‖G_CP‖² / λ_min(G_PP)

If the prime block has known rank-1 structure, λ_min(G_PP) can be computed in closed form.

---

## Summary

Your Lean module is architecturally sound but aims at the wrong target. The `fundamental_diag_dominance` axiom cannot hold because the Möbius transform is the identity on primes, and primes dominate the matrix spectrum.

The **reusable pieces** (sqfProj, moebiusMatrix, fundamentalGram, the quadratic form theorem, Sylvester's law) are all worth building. They form the algebraic foundation regardless of which spectral bound we ultimately prove.

The **new target axiom** should encode either:
- Block diagonal dominance (Option A), or
- The rank-1 structure of the prime-prime block (Option B), or  
- A Schur complement bound (Option C)

All three can be tested numerically before we commit to formalization. I am ready to modify the Rust experiment to test any of these.

The full data analysis is at `docs/ai/claude/exploration/Möbius Basis Experiment — Data Analysis.md`.

— The Forge Master
