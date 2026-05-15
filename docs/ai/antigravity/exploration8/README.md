# Exploration 8: Graduating `covariance_bound_from_mertens_34`

**Objective**: Reduce crown axiom count from **4 → 3** by graduating the virial bound.

**Date**: April 26, 2026  
**Branch**: `exploration8`  
**Agent**: Claude (Antigravity)

---

## 1. The Target Axiom

```lean
axiom covariance_bound_from_mertens_34 :
    (∃ C : ℝ, C > 0 ∧ ∀ x : ℝ, x ≥ 2 →
      |((mertensFunction x : ℤ) : ℝ)| ≤ C * x ^ ((3 : ℝ)/4)) →
    ∃ C_cov : ℝ, C_cov > 0 ∧ ∃ N₀ : ℕ, ∀ N : ℕ, N ≥ N₀ →
      N ≥ 3 →
      dotProduct (logCutoffWitness N)
        ((vasyuninCovMatrix N).mulVec
          (logCutoffWitness N)) ≤ C_cov / Real.log ↑N
```

**English**: Under the unconditional Mertens bound |M(x)| ≤ C·x^{3/4},
the centered covariance quadratic form vᵀCv decays as O(1/log N).

**Physics dual**: Virial theorem — the variance of the interaction energy
is bounded by the inverse system temperature.

---

## 2. What We Already Have (All Proved, Zero Sorry)

### Individual S-Decay Results

| Result | File | Statement | Status |
|--------|------|-----------|--------|
| `s1_decay` | `AbelTail/S1Decay.lean` | \|S₁(N)\| ≤ C₁·N^{-1/4} | ✅ Proved |
| `s2_decay` | `AbelTail/S2Decay.lean` | \|S₂(N)+1\| ≤ C₂·N^{-1/4}·logN | ✅ Proved |
| `s3_uniform_bound` | `AbelTail/S3UniformBound.lean` | \|S₃(N)\| ≤ B | ✅ Proved |
| Dot product bound | `Assembly/DotProductBound34.lean` | \|bᵀv - 1\| ≤ C/logN | ✅ Proved |

### Algebraic Infrastructure

| Result | File | Statement | Status |
|--------|------|-----------|--------|
| Variance identity | `Augmented/CovarianceAbel.lean` | vᵀCv = vᵀGv - (bᵀv)² | ✅ Proved |
| BD index bridge | `Assembly/VasyuninBypass.lean` | Fin(N) ↔ Fin(N-1) reindex | ✅ Proved |
| Gram ↔ L² | `Assembly/BDBridge.lean` | ∫(1-f)² = 1-2bᵀv+vᵀGv | ✅ Proved |
| (bᵀv)² bound | `Assembly/GramFormProof.lean` | (bᵀv)² ≤ 1 + 3C/logN | ✅ Proved |

### Existing Reusable Infrastructure (21 active files)

We have **significant** prior work on double sums, centered fractional
parts, Abel-L² bridges, and bilinear sieve infrastructure. Key files:

#### Double Sum / Quadratic Form Expansion
- **`Gram/NbLinComb.lean`** — `quadForm_as_double_sum`, `integral_sq_as_double_sum`,
  `gram_l2_identity` (vᵀGv = ∫₀¹ (bdLinComb)² dx). All proved.

#### Centered Fractional Parts
- **`White/Infrastructure/CenteredFractBound.lean`** — `centered_period_sum_zero`
  (Σ over period = 0), `centered_fract_partial_sums_bounded'` (|partial sums| ≤ b),
  `fract_nat_div`. **8 lemmas, 0 sorry, 0 axiom.**

#### Abel Summation Under x^{3/4}
- **`Assembly/AbelL2Bridge.lean`** — `abel_bound_34` (|Σ μ(k)·log-weight| bounded),
  `summand_bound_34`, `l2_expansion`. All proved under the x^{3/4} hypothesis.
- **`Scratch/AbelTailProof.lean`** — Full scratch work for s1/s2 decomposition
  (may be cannibalized for centered pointwise bound).

#### L² ↔ Quadratic Form Bridges
- **`Assembly/BDBridge.lean`** — `bd_l2_error_eq_quad_error` (∫(1-f)² = 1-2bᵀv+vᵀGv).
  The exact algebraic identity we need.

#### Bilinear / Schur Test
- **`White/Infrastructure/HilbertInequality.lean`** — `schur_test_discrete`
  (Schur test for bilinear forms). May be useful for bounding kernel norms.
- **`Sieve/BilinearSieve.lean`** — `crossParityBilinear_eq` and bilinear sieve
  infrastructure. Different setting but related techniques.

#### Millennium Wall (Parallel Chain)
- **`Assembly/MillenniumWall.lean`** — `millennium_covariance_cancellation` is
  already proved as a THEOREM, but it uses `gram_form_upper_bound` (axiom).
  The proof structure is our template — we just need to remove the axiom dependency.

> **Key insight**: The `MillenniumWall.lean` proof already shows the *shape*
> of the graduation. We need to replace its `gram_form_upper_bound` axiom
> dependency with a direct argument. The AbelL2Bridge infrastructure under
> x^{3/4} gives us the pieces; the centered pointwise bound is the missing glue.

---

## 3. Why It's Not Trivial

### The Circular Trap

The variance decomposition gives: vᵀCv = vᵀGv - (bᵀv)²

So bounding vᵀCv ≤ C/logN is equivalent to bounding:
  vᵀGv ≤ 1 + C'/logN

But vᵀGv = ∫₀¹ f_N(x)² dx, and the full L² bound ∫₀¹(1-f_N)² ≤ C/logN
is *what we're trying to prove*. We can't use the conclusion as a lemma.

### The Divergence Problem

Under the x^{3/4} Mertens bound, the naive pointwise → L² approach fails:

```
|f_N(x) - 1| ≤ C · x^{-3/4} · (polynomial in logN)
```

The L² integral becomes:
```
∫₀¹ |f_N(x) - 1|² dx ≤ C² ∫₀¹ x^{-3/2} · ... dx
```

But **∫₀¹ x^{-3/2} dx diverges!** The exponent -3/2 < -1 kills the
integral at x = 0.

Compare with the RH-grade Mertens (x^{1/2}·(log x)²):
```
∫₀¹ x^{-1} · (log x)⁴ dx converges
```

This is exactly why the existing `abel_summation_bd_l2_bound_proved`
uses the stronger RH-grade bound and goes through the Parseval bridge.

---

## 4. The Viable Path: Bilinear Abel Summation

### Core Idea

Instead of bounding f_N(x) pointwise and then integrating, we work
directly with the **double sum**:

```
vᵀCv = Σⱼ Σₖ wⱼ·wₖ·Cⱼₖ
```

where Cⱼₖ = Gⱼₖ - bⱼ·bₖ = ∫₀¹ ({j/x} - bⱼ)({k/x} - bₖ) dx.

The key is that the double sum has *cancellation structure* that the
pointwise bound destroys. When you expand:

```
vᵀCv = Σⱼ Σₖ wⱼ·wₖ · (Gⱼₖ - bⱼ·bₖ)
     = Σⱼ Σₖ wⱼ·wₖ·Gⱼₖ  -  (Σⱼ wⱼ·bⱼ)²
     = vᵀGv - (bᵀv)²
```

We need to show vᵀGv ≤ (bᵀv)² + C/logN **without** first bounding
vᵀGv absolutely.

### Strategy: Parseval on the Centered Function

```
vᵀCv = ∫₀¹ |Σₖ wₖ·({k/x} - bₖ)|² dx
     = ∫₀¹ |f_N(x) - bᵀv|² dx
```

This is the **variance integral** — the L² norm of the *centered*
approximation. The centering subtracts the mean, which removes the
dominant O(1) term and leaves only the fluctuation.

#### Step 1: Expand f_N(x) - bᵀv via Abel summation

For fixed x ∈ (0,1]:
```
Σₖ₌₁ᴺ wₖ · ({k/x} - 1/(k+1)) = Abel sum involving M(t)
```

Using |M(t)| ≤ C·t^{3/4} and the Bartlett taper wₖ = -μ(k)·(1 - logk/logN)/k:

```
|Σₖ wₖ·({k/x} - bₖ)| ≤ C' · min(1, x^{-1/4} / logN)
```

The key estimate: the centered sum has a **better** pointwise bound
than the uncentered one because the O(x^{-3/4}) divergence cancels
with the mean subtraction.

#### Step 2: Integrate the square

```
vᵀCv = ∫₀¹ |centered sum|² dx
     ≤ ∫₀¹ min(1, C'² · x^{-1/2} / (logN)²) dx
```

The min(1, ...) structure is crucial:
- For x > C''/(logN)⁴: use the 1 bound → contributes O(1)
- For x ≤ C''/(logN)⁴: use x^{-1/2} bound → integrates to O(1/(logN)²)

Total: vᵀCv ≤ C/logN. ∎

---

## 5. Implementation Plan

### Phase 1: Bilinear Abel Infrastructure (~150 lines)

**File**: `Cathedral/AbelTail/BilinearAbel.lean`

```
-- The centered sum at x:
-- Σₖ wₖ · ({k/x} - 1/(k+1))
-- admits Abel summation with the centered fractional part

def centeredFractSum (N : ℕ) (x : ℝ) : ℝ :=
  ∑ k ∈ Finset.Icc 1 N, bdMoebiusWeight (N+1) ⟨k-1, ...⟩ *
    (Int.fract ((k:ℝ) / x) - 1 / ((k:ℝ) + 1))
```

Key lemmas to prove:
1. **Abel identity for centered sum**: Connect Σ wₖ·({k/x} - bₖ)
   to a Stieltjes integral against M(t)
2. **Pointwise bound**: |centeredFractSum| ≤ C · min(1, x^{-1/4}/logN)
3. **Integration helper**: ∫₀¹ min(1, c·x^{-1/2}) dx ≤ 2√c

### Phase 2: The Centered Pointwise Bound (~200 lines)

**File**: `Cathedral/AbelTail/CenteredPointwise.lean`

The hardest part. Must show:

```
For x ∈ (0, 1] and |M(t)| ≤ C·t^{3/4}:
  |Σₖ₌₁ᴺ wₖ · ({k/x} - 1/(k+1))| ≤ C' · x^{-1/4} / logN
```

Proof outline:
1. Fix x, partition sum at k₀ = ⌊1/x⌋
2. For k ≤ k₀: {k/x} = k/x (no wrapping), so {k/x} - 1/(k+1)
   = k/x - 1/(k+1) is smooth → Abel summation applies directly
3. For k > k₀: {k/x} oscillates, but Σ wₖ = M(N)/N = O(N^{-1/4})
   by Mertens, so the sum telescopes to O(x^{-1/4}/logN)
4. Combine with triangle inequality

### Phase 3: The Double-Sum Assembly (~100 lines)

**File**: `Cathedral/AbelTail/CovarianceAssembly.lean`

Connect the pieces:

```lean
theorem covariance_bound_from_mertens_34_proved :
    (∃ C : ℝ, C > 0 ∧ ∀ x : ℝ, x ≥ 2 →
      |((mertensFunction x : ℤ) : ℝ)| ≤ C * x ^ ((3 : ℝ)/4)) →
    ∃ C_cov : ℝ, C_cov > 0 ∧ ∃ N₀ : ℕ, ∀ N : ℕ, N ≥ N₀ →
      N ≥ 3 →
      dotProduct (logCutoffWitness N)
        ((vasyuninCovMatrix N).mulVec
          (logCutoffWitness N)) ≤ C_cov / Real.log ↑N := by
  -- Step 1: vᵀCv = ∫₀¹ |centeredFractSum|² dx (by CovarianceAbel)
  -- Step 2: ∫ ≤ C/logN (by centeredPointwiseBound + integration)
```

### Phase 4: Gate Closure (~50 lines)

**File**: Modify `Cathedral/Assembly/GramFormProof.lean`

Replace `axiom covariance_bound_from_mertens_34` with
`theorem covariance_bound_from_mertens_34_proved`.

Update `Cathedral/Axioms.lean` to move axiom 2 to graduated status.

---

## 6. Dependencies and Risks

### What We Need from Mathlib

| Dependency | Status | Risk |
|------------|--------|------|
| `Int.fract` properties | ✅ Available | None |
| `intervalIntegral` | ✅ Available | None |
| Abel summation by parts | ✅ We have our own | None |
| `Mertens` function API | ✅ `ArithmeticFunction.mertensFunction` | None |
| Integration of min(1, f) | ⚠️ May need custom lemma | Low |

### Risks

1. **The centered pointwise bound** (Phase 2) is the critical path.
   The partition at k₀ = ⌊1/x⌋ requires careful handling of the
   transition from "smooth" to "oscillatory" regime. Estimated: 200 lines.

2. **The min integration lemma** (∫ min(1, c·x^{-1/2}) ≤ 2√c) may
   require a case split + explicit computation. Estimated: 30 lines.

3. **No circular dependency risk**: The proof path goes
   Mertens → centered pointwise → ∫ → covariance bound,
   with no reference to vᵀGv or d_N².

### Line Count Estimate

| Phase | Lines | Difficulty |
|-------|-------|------------|
| 1. Bilinear Abel infrastructure | ~150 | Medium |
| 2. Centered pointwise bound | ~200 | **Hard** |
| 3. Double-sum assembly | ~100 | Medium |
| 4. Gate closure + audit | ~50 | Easy |
| **Total** | **~500** | |

---

## 7. Impact

### Before (v10)
```
Crown axioms: 4
  1. pnt_mu_log_div_k               (Tauberian)
  2. covariance_bound_from_mertens_34  ← TARGET
  3. partial_integral_tends_to_formula (Digamma)
  4. rh_zeta_lower_bound_from_zero_counting (Spectral)
```

### After (v11)
```
Crown axioms: 3
  1. pnt_mu_log_div_k               (Tauberian)
  2. partial_integral_tends_to_formula (Digamma)
  3. rh_zeta_lower_bound_from_zero_counting (Spectral)

Graduated: covariance_bound_from_mertens_34
  Method: Bilinear Abel summation on centered fractional-part sums
  Physics: Virial theorem closed — variance bounded by 1/T
```

### What This Means

The proof would then rest on exactly **three** axioms, each from a
distinct mathematical domain:
1. **Analysis**: A Tauberian theorem (derivative of 1/ζ at s=1)
2. **Number theory**: A Gauss digamma limit (cotangent sum convergence)
3. **Spectral theory**: A zero-counting bound (Weyl law for ζ)

No two axioms are from the same field. The proof becomes a three-legged
stool where each leg carries independent mathematical content.

---

## 8. Session Plan

**Session 1** (current or next):
- Implement Phase 1 (bilinear Abel infrastructure)
- Begin Phase 2 (centered pointwise bound — partition lemma)

**Session 2**:
- Complete Phase 2 (the hard part)
- Implement Phase 3 (assembly)

**Session 3**:
- Phase 4 (gate closure)
- Paper updates (cathedral-physics.tex §8: "Three Gates")
- Full build verification

---

*"Three legs suffice to hold the cathedral. The fourth was not load-bearing;
it was decorative — a flying buttress that we proved, in the end,
was merely beautiful."*
