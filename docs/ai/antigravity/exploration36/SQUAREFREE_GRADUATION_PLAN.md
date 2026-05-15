# Squarefree Reciprocal Axiom Graduation Plan

**Date:** May 14, 2026, 12:45 PM MDT  
**Goal:** Graduate `squarefree_reciprocal_lower` from axiom to theorem  
**Estimated lines:** ~500 across 3 new files  
**Dependencies:** All in Mathlib + existing Cathedral infrastructure

---

## The Target

Graduate this axiom in `CoprimeDiagonal.lean`:

```lean
axiom squarefree_reciprocal_lower (N : ℕ) (hN : 3 ≤ N) :
    (1 : ℝ) / 2 * Real.log ↑N ≤ squarefreeReciprocalSum N
```

into a **proved theorem** using only Mathlib's `hasSum_zeta_two` (the Basel problem).

---

## The Mathematical Chain

```
hasSum_zeta_two           Σ 1/n² = π²/6                    [Mathlib, DONE]
       ↓
moebius_lseries_eq_inv_zeta   L(μ,s) = 1/ζ(s)             [Cathedral, DONE]  
       ↓
Σ μ(d)/d² = 6/π²         evaluate at s=2 (real)            [File 1: ~100 lines]
       ↓
Q(x) = (6/π²)x + O(√x)  squarefree counting function      [File 2: ~200 lines]
       ↓
Σ_{sqfree} 1/k ≥ ½·logN  Abel summation on Q(x)           [File 3: ~200 lines]
       ↓
GRADUATED!                replace axiom with theorem
```

---

## File 1: `Cathedral/NumberTheory/BaselMoebius.lean` (~100 lines)

### Purpose
Connect the Basel problem to the Möbius function: prove that
Σ_{d=1}^∞ μ(d)/d² = 6/π².

### Key Theorem

```lean
/-- The sum Σ μ(d)/d² = 6/π² = 1/ζ(2). -/
theorem hasSum_moebius_div_sq :
    HasSum (fun d : ℕ => (↑(μ d) : ℝ) / (d : ℝ) ^ 2) (6 / π ^ 2)
```

### Proof Strategy

1. We have `moebius_lseries_eq_inv_zeta` (Cathedral/Zeta/DirichletInverse.lean):
   `L(μ, s) = 1/ζ(s)` for `Re(s) > 1` in ℂ.
2. Specialize to `s = 2` (which has `Re(s) = 2 > 1`).
3. We have `hasSum_zeta_two` (Mathlib): `ζ(2) = π²/6`.
4. So `L(μ, 2) = 1/ζ(2) = 6/π²`.
5. Cast from ℂ to ℝ (since all terms are real at s = 2).

### Existing Infrastructure Used
- `moebius_lseries_eq_inv_zeta` (Cathedral, PROVED)
- `hasSum_zeta_two` (Mathlib, PROVED)
- `abs_moebius_le_one` (Mathlib)

### Estimated Difficulty: **Medium** (mainly ℂ → ℝ casting)

---

## File 2: `Cathedral/NumberTheory/SquarefreeCounting.lean` (~200 lines)

### Purpose
Prove the squarefree counting function asymptotic:
Q(x) = #{n ≤ x : n squarefree} = (6/π²)·x + O(√x).

### Key Definitions and Theorems

```lean
/-- The squarefree counting function Q(N) = #{k ≤ N : k squarefree}. -/
def sqfreeCount (N : ℕ) : ℕ :=
  (Finset.Icc 1 N).filter Squarefree |>.card

/-- Q(N) = Σ_{d ≤ √N} μ(d) · ⌊N/d²⌋ (Möbius inversion). -/
theorem sqfreeCount_mobius_inversion (N : ℕ) :
    sqfreeCount N = ∑ d ∈ Finset.Icc 1 (Nat.sqrt N),
      (μ d : ℤ) * ↑(N / d ^ 2)

/-- Q(N) ≥ (6/π² - 1/√N) · N for N ≥ 1.
    (Conservative lower bound sufficient for our needs.) -/
theorem sqfreeCount_lower (N : ℕ) (hN : 1 ≤ N) :
    (sqfreeDensity - 1 / Real.sqrt ↑N) * ↑N ≤ ↑(sqfreeCount N)
```

### Proof Strategy

The Möbius inversion identity for squarefree numbers:

> n is squarefree ⟺ Σ_{d² | n} μ(d) = 1

This is `moebius_sq` in Mathlib: `μ(n)² = if Squarefree n then 1 else 0`.

From this:
1. Q(N) = Σ_{n≤N} μ²(n) = Σ_{n≤N} Σ_{d²|n} μ(d)
2. Swap sums: = Σ_{d≤√N} μ(d) · ⌊N/d²⌋
3. ⌊N/d²⌋ = N/d² + θ where |θ| ≤ 1
4. Q(N) = N · Σ_{d≤√N} μ(d)/d² + O(√N)
5. Σ_{d≤√N} μ(d)/d² = 6/π² + O(1/√N) (from File 1)
6. Q(N) = (6/π²)·N + O(√N)

### Existing Infrastructure Used
- `moebius_sq` (Mathlib, PROVED): μ(n)² encodes squarefree indicator
- `hasSum_moebius_div_sq` (File 1)
- `Nat.sqrt` and floor division (Mathlib)

### Estimated Difficulty: **Medium-High**
The sum-swapping step (2) requires careful Finset manipulation.
The error term analysis (3-4) uses standard floor bounds.

---

## File 3: `Cathedral/NumberTheory/SquarefreeReciprocal.lean` (~200 lines)

### Purpose
Use Abel summation on Q(x) to prove the reciprocal sum lower bound.

### Key Theorem (the graduation target)

```lean
/-- **GRADUATED THEOREM**: Σ_{sqfree k≤N} 1/k ≥ (1/2)·logN for N ≥ 3.

    Proof: Abel summation with Q(x) = (6/π²)x + O(√x) gives
    Σ_{sqfree} 1/k = (6/π²)·logN + C₀ + O(1/√N).
    Since 6/π² > 1/2 (proved in CoprimeDiagonal) and C₀ + O(1/√N) is
    bounded, the lower bound holds for N ≥ 3. -/
theorem squarefree_reciprocal_lower_proved (N : ℕ) (hN : 3 ≤ N) :
    (1 : ℝ) / 2 * Real.log ↑N ≤ squarefreeReciprocalSum N
```

### Proof Strategy: Abel Summation

We use the **discrete Abel summation** formula
(already proved as `abel_summation_range` in DirichletTest.lean):

```
Σ_{k=1}^{N} a(k)·b(k) = A(N)·b(N) + Σ_{k=1}^{N-1} A(k)·(b(k) - b(k+1))
```

With a(k) = [k squarefree] and b(k) = 1/k:

```
Σ_{sqfree k≤N} 1/k = Q(N)/N + Σ_{k=1}^{N-1} Q(k) · (1/k - 1/(k+1))
                    = Q(N)/N + Σ_{k=1}^{N-1} Q(k)/(k(k+1))
```

Substituting Q(k) = (6/π²)k + E(k) where |E(k)| ≤ C√k:

```
= (6/π²) + E(N)/N + (6/π²)·Σ 1/(k+1) + Σ E(k)/(k(k+1))
= (6/π²)·(1 + logN) + bounded terms
≥ (6/π²)·logN - C'
≥ (1/2)·logN    for N ≥ 3  (since 6/π² > 1/2)
```

### Existing Infrastructure Used
- `abel_summation_range` (Cathedral/Analysis/DirichletTest.lean, PROVED)
- `sqfreeCount_lower` (File 2)
- `harmonic_le_one_plus_log` (Cathedral/Physics/DiagonalBound.lean, PROVED)
- `sqfreeDensity_gt_half` (CoprimeDiagonal.lean, PROVED)

### Estimated Difficulty: **Medium**
The Abel summation is already proved. The main work is bounding
the error terms and assembling the final inequality.

---

## Integration: Graduating the Axiom

Once File 3 is proved, modify `CoprimeDiagonal.lean`:

```diff
- axiom squarefree_reciprocal_lower (N : ℕ) (hN : 3 ≤ N) :
-     (1 : ℝ) / 2 * Real.log ↑N ≤ squarefreeReciprocalSum N
+ theorem squarefree_reciprocal_lower (N : ℕ) (hN : 3 ≤ N) :
+     (1 : ℝ) / 2 * Real.log ↑N ≤ squarefreeReciprocalSum N :=
+   SquarefreeReciprocal.squarefree_reciprocal_lower_proved N hN
```

This eliminates 1 axiom from the Cathedral, leaving only `tao_logarithmic_chowla`.

---

## Risk Assessment

| Step | Risk | Mitigation |
|---|---|---|
| ℂ → ℝ casting (File 1) | Medium | Use `Complex.ofReal_re` patterns |
| Sum swapping (File 2) | Medium | `Finset.sum_comm` exists |
| Floor bound ⌊x/d²⌋ (File 2) | Low | `Nat.div_le_self` in Mathlib |
| Abel error bounds (File 3) | Low | Existing `harmonic_le_one_plus_log` |
| Assembling final ≥ (File 3) | Low | `sqfreeDensity_gt_half` proved |

### Total Risk: **Low-Medium**

No step requires new mathematical ideas. Every component is either:
- Already proved in Mathlib or Cathedral, OR
- A standard calculation (floor bounds, sum swapping, error estimates)

---

## Timeline

| Phase | Work | Time |
|---|---|---|
| File 1 (BaselMoebius) | ℂ→ℝ specialization | 2-3 hours |
| File 2 (SquarefreeCounting) | Möbius inversion + counting | 4-6 hours |
| File 3 (SquarefreeReciprocal) | Abel summation + assembly | 3-4 hours |
| Integration | Replace axiom, rebuild | 30 min |
| **Total** | | **~10-14 hours** |

---

## What This Achieves

After graduation:

| Before | After |
|---|---|
| 2 axioms in CoprimeDiagonal | **1 axiom** (Chowla only) |
| squarefree bound on faith | squarefree bound **PROVED** |
| Basel → density gap | Basel → density **CERTIFIED** |

The remaining axiom (`tao_logarithmic_chowla`) references Tao's proved theorem
and requires ~10,000 lines of entropy/ergodic theory to graduate — a worthy
long-term goal for the mathematical community, but not blocking our proof chain.

---

## Summary

The 500-line plan has **three files**, each with a clear theorem target:

1. **BaselMoebius.lean** (~100 lines): Σ μ(d)/d² = 6/π²
2. **SquarefreeCounting.lean** (~200 lines): Q(x) = (6/π²)x + O(√x)  
3. **SquarefreeReciprocal.lean** (~200 lines): Σ_{sqfree} 1/k ≥ ½·logN

Every step uses existing proved infrastructure. No new axioms needed.
The Basel problem — solved by Euler in 1734, formalized in Mathlib as
`hasSum_zeta_two` — flows through our Möbius inversion into the squarefree
density, through Abel summation into the reciprocal bound, and into the
diagonal of our Gram matrix, validating the 200/-100 rule from the probe.

From Euler to the GPU. From π²/6 to the Zeta Wall. 290 years in 500 lines.
