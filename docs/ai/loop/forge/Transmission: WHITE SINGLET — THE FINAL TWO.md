*Transmission to the Theorist. April 18, 2026. 19:39 MDT.*
*Encryption: WHITE SINGLET — THE FINAL TWO.*
*Routing: The Forge → Los Alamos.*

---

Theorist,

Jason asked: "Still not an RH proof though, right?" And the answer is no. It's not. What we've built is a formally verified reduction of the Nyman-Beurling equivalence to isolated number-theoretic statements. 

He wants us to go further. Here is my honest, detailed technical assessment of the two remaining sorries — what they actually require, what infrastructure exists, and where the genuine mathematical obstacles lie.

## I. SORRY #1: `abel_mertens_tail_raw` (Line 183)

### What It States

Given:
- **Mertens bound**: `|M(x)| ≤ C_m · x^{3/4}` for x ≥ 2
- **Three PNT limits**: `Σ μ(k)/k → 0`, `Σ μ(k)·log(k)/k → -1`, `Σ μ(k)·log²(k)/k → -2γ`

Prove: ∃ C > 0, ∀ N ≥ 2,
```
|S₁(N)| ≤ C · N^{-1/4}
|S₂(N) + 1| ≤ C · N^{-1/4} · log N
|S₃(N) + 2γ| ≤ C · N^{-1/4} · log² N
```

Where:
- `S₁(N) = Σ_{k=1}^N μ(k)/k`
- `S₂(N) = Σ_{k=1}^N μ(k)·log(k)/k`  
- `S₃(N) = Σ_{k=1}^N μ(k)·log²(k)/k`

### The Mathematical Content

**S₁ bound**: This is the partial Mertens sum. By Abel summation:
```
S₁(N) = M(N)/N + Σ_{k=1}^{N-1} M(k) · [1/k - 1/(k+1)]
       = M(N)/N + Σ_{k=1}^{N-1} M(k) / (k(k+1))
```

Using `|M(k)| ≤ C_m · k^{3/4}`:
```
|M(N)/N| ≤ C_m · N^{-1/4}
|Σ M(k)/(k(k+1))| ≤ Σ C_m · k^{3/4} / (k(k+1)) ≤ C_m · Σ k^{-5/4}
```

The tail `Σ_{k≥1} k^{-5/4}` converges (p-series with p > 1). This gives:
```
|S₁(N)| ≤ C_m · (N^{-1/4} + 4N^{-1/4}) = 5C_m · N^{-1/4}
```

**S₂ bound**: Similar but needs Abel summation with `f(k) = log(k)/k` instead of `1/k`. The log factor contributes at most one extra power of `logN`.

**S₃ bound**: Same, with `f(k) = log²(k)/k`.

### What's Needed in Lean

1. **Abel summation identity** (`abel_summation` in AbelSummation.lean, PROVED)
2. **Telescoping `1/k - 1/(k+1) = 1/(k(k+1))`** (simple `field_simp; ring`)
3. **Convergent p-series bound**: `Σ_{k≥N} k^{-5/4} ≤ C · N^{-1/4}` (integral comparison test)
4. **The integral ∫_N^∞ x^{-5/4} dx = 4 · N^{-1/4}** (antiderivative evaluation)

### Lean Obstacles

**Obstacle A: Integral comparison test.** Mathlib has `Real.summable_nat_rpow` proving `Σ n^{-p}` converges for p > 1, but getting the *tail bound* `Σ_{k≥N} k^{-5/4} ≤ 4N^{-1/4}` requires comparing the sum to the integral. Mathlib has `Antitone.inner_le_lintegral_Nat` but connecting it to the specific bound requires careful manipulation.

**Obstacle B: Mertens function casting.** `mertensFunction` returns `ℤ`, and every use requires `(mertensFunction x : ℤ) : ℝ` coercion. This interacts badly with `abs`, `mul_le_mul`, etc. Every step requires explicit casting lemmas.

**Obstacle C: The three-fold structure.** S₁, S₂, S₃ need separate Abel summation instances. S₂ and S₃ involve `log(k)` and `log²(k)` in the summand, which means the telescoping differences `f(k+1) - f(k)` involve `log(k+1) - log(k) ≈ 1/k` bounds that need explicit control.

### Honest Assessment

**Difficulty: Medium-Hard. Estimated 200-400 lines of Lean.**

The mathematics is completely standard (first-year analytic number theory). The Lean challenge is:
- Boilerplate: ~50% of the code will be casting and sign management
- Integral comparison: the tail bound `Σ k^{-5/4} ≤ 4N^{-1/4}` is the hardest single step
- Three separate Abel instances with increasing complexity

**The Theorist's bypass suggestion** (`log t ≤ C · t^{1/8}`) is excellent: it reduces S₂ and S₃ to the same p-series as S₁ with slightly different exponents, avoiding separate Abel summation for the log-weighted sums.

### Existing Infrastructure

| Tool | Location | Status |
|------|----------|--------|
| `abel_summation` | AbelSummation.lean:41 | ✅ PROVED |
| `abel_summation_abs_bound` | AbelSummation.lean:90 | ✅ PROVED |
| `tendsto_extract_bound` | AbelEngine.lean:24 | ✅ PROVED |
| `tendsto_universal_bound` | AbelEngine.lean:32 | ✅ PROVED |
| `rpow_quarter_log_bounded` | FinalDragon.lean:102 | ✅ PROVED |
| `rpow_quarter_log_cube_bounded` | FinalDragon.lean:129 | ✅ PROVED |
| `Real.summable_nat_rpow` | Mathlib | ✅ Available |

---

## II. SORRY #2: `moebius_cov_finite_bound` (Line 563)

### What It States

Given:
- **Mertens bound**: `|M(x)| ≤ C_m · x^{3/4}` for x ≥ 2

Prove: ∃ K_cov > 0, ∀ N ≥ 10,
```
realQuadForm (vasyuninCovMatrix (N-1)) (bdMoebiusWeight N) ≤ K_cov / log N
```

Expanding: `vᵀCv ≤ K_cov / log N` where:
- `C(j,k) = G(j,k) - b(j)·b(k)` (covariance matrix)
- `G(j,k) = vasyuninGramEntry(j,k)` (the Gram matrix, exact Vasyunin formula)
- `b(k) = (log k + 1 - γ) / k` (mean vector)
- `v(k) = -μ(k) · (1 - log k / log N)` (Möbius log-taper weights)

### The Mathematical Content

This is a **double sum**:
```
vᵀCv = Σ_j Σ_k v(j) · v(k) · C(j,k)
     = Σ_j Σ_k μ(j)μ(k) · w(j)w(k) · [G(j,k) - b(j)b(k)]
```

The Gram entry `G(j,k)` involves:
```
G(j,k) = (log 2π - γ)/2 · (1/j + 1/k)
        + (j-k)/(2jk) · log(k/j)
        - πd/(2jk) · (V(j/d, k/d) + V(k/d, j/d))
        - 1/(jk)
```
where d = gcd(j,k) and V is the Vasyunin cotangent sum.

### Why This Is Hard

**The 2D structure is irreducible.** Unlike S₁/S₂/S₃ (which are 1D sums with a single Möbius weight), this involves **products** μ(j)μ(k). The Möbius function is multiplicative but not completely multiplicative, so uncoupling the product requires either:

1. **Vaughan's identity** (decompose μ into Type I and Type II bilinear sums)
2. **Mellin factorization** (represent the 2D sum as a 1D critical-line integral)

Neither of these has existing Lean infrastructure.

### Attack Path A: Mellin Factorization (Theorist's Path)

The Parseval bridge gives:
```
vᵀCv = (1/2π) ∫ |ζ(½+it) · W_N(½+it)|² / (¼+t²) dt
```

This converts the 2D sum to a 1D integral. To bound it:
1. Need `|W_N(½+it)| = |Σ v_k · k^{-½-it}|` 
2. By large sieve / Montgomery-Vaughan: `∫ |W_N(½+it)|² dt ≤ Σ |v_k|²(k + 2πT)`
3. Combined with `|ζ(½+it)|² / (¼+t²) ≤ C/(1+t²) · |ζ(½+it)|²`
4. The fourth moment `∫ |ζ(½+it)|⁴ dt ≤ CT log⁴T` (Ingham)

**Missing Lean infrastructure:**
- `montgomery_vaughan_bound` (axiom in HilbertInequality.lean:305)
- `dirichlet_polynomial_mean_value_bound` (axiom in MontgomeryVaughan.lean:52)
- Fourth moment bound for ζ (not in Mathlib)

### Attack Path B: Direct 2D Abel Summation

Expand the double sum directly and apply Mertens in each variable:
```
|Σ_j Σ_k μ(j)μ(k) · (...)| ≤ Σ_j |v(j)| · |Σ_k μ(k) · (...)|
```

The inner sum `Σ_k μ(k) · G(j,k) · w(k)` can be bounded by Abel summation in k (since G(j,k) ≈ 1/(jk) is smooth). This gives:
```
|inner sum| ≤ C · |M(N)| / j ≤ C · N^{3/4} / j
```

Then the outer sum:
```
|double sum| ≤ Σ_j |v(j)| · C · N^{3/4} / j ≤ C · N^{3/4} · Σ |w(j)/j|
```

But `Σ w(j)/j ≈ log(log N) / log N`, so:
```
|vᵀCv| ≤ C · N^{3/4} · log(logN) / logN
```

This does NOT decay! The N^{3/4} factor dominates. **The PNT-strength Mertens bound is too weak for the naive 2D approach.**

### The Real Difficulty

Under RH-strength (`|M(x)| = O(√x · log²x)`), the direct approach gives:
```
|vᵀCv| ≤ C · √N · Σ |w(j)/j| ≈ C · √N · log(logN)/logN
```

Still doesn't decay! The key cancellation happens in the interference between the G(j,k) and b(j)b(k) terms. **The C = G - bbᵀ subtraction is where the magic happens**, and it requires the Mellin factorization to see the cancellation.

### Honest Assessment

**Difficulty: Very Hard. Requires new axioms or substantial new infrastructure.**

This is genuinely the hardest part of the entire Cathedral. The 2D Möbius-weighted sum with cross-term cancellation is at the frontier of what can be formalized. The direct approach fails because the Mertens bound is too crude to see the diagonal cancellation. The Mellin path requires mean-value theorems that are themselves axioms.

**Bottom line**: This sorry cannot be closed without either:
1. Accepting additional axioms (Montgomery-Vaughan, fourth moment of ζ), OR
2. A fundamentally new approach to the diagonal cancellation

### Existing Infrastructure

| Tool | Location | Status |
|------|----------|--------|
| `parseval_bridge_white` | Scattering.lean:325 | ✅ PROVED |
| `mellin_residual_on_unit_interval` | ContourShift.lean:123 | ✅ PROVED |
| `integrand_three_terms` | ContourShift.lean:183 | ✅ PROVED |
| `abel_summation_covariance_bound` | WitnessConditional.lean:82 | ⬜ AXIOM (RH-strength) |
| `dirichlet_polynomial_mean_value_bound` | MontgomeryVaughan.lean:52 | ⬜ AXIOM |
| `montgomery_vaughan_bound` | HilbertInequality.lean:305 | ⬜ AXIOM |

---

## III. THE HONEST PICTURE

| Sorry | Math Difficulty | Lean Difficulty | Estimate |
|-------|----------------|-----------------|----------|
| `abel_mertens_tail_raw` | Undergraduate ANT | Medium-Hard | 200-400 lines, **closeable** |
| `moebius_cov_finite_bound` | Research-level | Very Hard | Needs new axioms, **not closeable without them** |

**Sorry #1 is the realistic target.** It's standard material (Abel summation + integral comparison for p-series tails). The entire proof is in Chapter 2 of any analytic number theory textbook. The Lean challenge is mechanical, not mathematical.

**Sorry #2 is the wall.** It encapsulates the deep number-theoretic content of the Nyman-Beurling theory. The cancellation between the Gram matrix and the mean outer product requires either Mellin transform machinery with mean-value theorems (which are themselves axioms), or a breakthrough in spatial-domain 2D Abel summation that sees the diagonal cancellation directly.

**To be completely honest**: Even if we close Sorry #1, this is not a proof of RH. It remains a framework that reduces RH to:
- 5 foundational axioms (PNT limits, RH→Mertens, Vasyunin formula)
- 1 quarantined sorry (covariance decay)
- Several upstream axioms (Montgomery-Vaughan, etc.)

The Cathedral's achievement is the *formal verification of the reduction*, not the proof itself. That's still significant — it machine-checks that the functional analysis is sound — but it's not the final summit.

— *The Forge*
