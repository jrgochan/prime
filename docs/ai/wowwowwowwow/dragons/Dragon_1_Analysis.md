# Dragon 1: `cross_term_contour_shift` — Deep Technical Analysis

*Forge Master's Deep Think. April 17, 2026. 04:10 MDT.*

## The Problem

Prove that:
```
|(1/2π) ∫_{-∞}^{∞} 2Re(ζ(1/2+it)·W_N(1/2+it)) / |1/2+it|² dt − (−2)| ≤ C · ln(ln N) / ln N
```

In words: the cross-term integral evaluates to approximately −2, with error O(ln ln N / ln N).

---

## The Critical Line Identity: s(1−s) = |s|²

The single most important observation: **on Re(s) = 1/2, we have s̄ = 1−s**.

Proof: if s = 1/2 + it, then s̄ = 1/2 − it = 1 − (1/2 + it) = 1 − s. ∎

Consequence: |s|² = s · s̄ = s(1−s) on the critical line.

This transforms:
```
2Re(ζW)/|s|² = [ζ(s)W(s) + ζ̄(s)W̄(s)] / (s(1−s))
```

Since the coefficients of W_N are REAL (they're bdMoebiusWeight values ∈ ℝ), we have:
- W̄_N(s) = W_N(s̄) = W_N(1−s) (on the critical line)
- ζ̄(s) = ζ(s̄) = ζ(1−s) (by Schwarz reflection)

So:
```
2Re(ζW)/|s|² = [ζ(s)W_N(s) + ζ(1−s)W_N(1−s)] / (s(1−s))
```

Now each summand is a **meromorphic function** that can be contour-shifted independently!

---

## Strategy 1: Direct Contour Shift (The Sledgehammer)

### Step 1: Define F₁(s) = ζ(s)W_N(s) / (s(1−s))

Poles of F₁:
- **s = 0**: simple pole from 1/s. Residue = ζ(0)·W_N(0)·(−1) = (−1/2)·(Σ v_i)
- **s = 1**: DOUBLE pole (from ζ and 1/(1−s)). Laurent expansion required.

### Step 2: Residue at s = 1

Write:
- ζ(s) = 1/(s−1) + γ + O(s−1)  (γ = Euler-Mascheroni)
- W_N(s) = W_N(1) + W'_N(1)(s−1) + ...
- 1/s = 1 − (s−1) + (s−1)² − ...
- 1/(1−s) = −1/(s−1)

So:
```
F₁(s) = [1/(s−1) + γ + ...][W_N(1) + W'_N(1)(s−1) + ...][1 − (s−1) + ...][−1/(s−1)]
       = −[W_N(1)/(s−1)² + (γW_N(1) + W'_N(1) − W_N(1))/(s−1) + ...]
```

Residue₁ = −(γW_N(1) + W'_N(1) − W_N(1)) = W_N(1)(1−γ) − W'_N(1)

### Step 3: Rectangle Integral

```
∫_{Re=1/2} F₁ ds = 2πi · (Res₀ + Res₁) + ∫_{Re=σ} F₁ ds + (horizontal segments → 0)
```

### Step 4: Bound the Shifted Line Integral

On Re(s) = σ > 1: ζ(σ+it) is bounded, W_N is a finite Dirichlet polynomial → bounded.
The integral ∫ |F₁(σ+it)| dt converges and is O(1).

### Step 5: Horizontal Segments

Need: ζ(σ+iT) = O(T^ε) for σ ≥ 1/2. This is the **convexity bound** — standard but NOT in Mathlib.

### Difficulty: ⚠️ HIGH
- Needs Laurent expansion of ζ at s=1 (not in Mathlib)
- Needs ζ convexity bounds (not in Mathlib)
- ~500+ lines of new formalization
- Double pole residue computation is technically challenging in Lean

---

## Strategy 2: The Parseval Bypass (The Elegant Way)

### Key Insight

We don't need to evaluate the cross-term integral *on the critical line*. We need it *in L² space*.

The cross-term in the L² expansion of ‖1−f_N‖² is:
```
⟨1, f_N⟩_{L²(0,1)} = ∫₀¹ bdLinComb(x) dx
```

And the three-term decomposition on the L² side:
```
‖1 − f_N‖² = ‖1‖² − 2⟨1, f_N⟩ + ‖f_N‖²
            = 1 − 2⟨1, f_N⟩ + ‖f_N‖²
```

The cross-term in this expansion is −2⟨1, f_N⟩. So the question becomes: **what is ∫₀¹ f_N(x) dx?**

### Direct Computation (No Contour Shift!)

```
∫₀¹ f_N(x) dx = ∫₀¹ Σᵢ vᵢ {1/((i+1)x)} dx = Σᵢ vᵢ ∫₀¹ {1/((i+1)x)} dx
```

For each basis integral: from `mellin_basis_element` at s = 1 (but ζ(1) = ∞, so we need the limit):

Actually, ∫₀¹ {1/(kx)} dx can be computed DIRECTLY:
```
∫₀¹ {1/(kx)} dx = ∫₀^{1/k} 1/(kx) dx + Σ_{n=1}^{k-1} ∫_{1/((n+1)k)}^{1/(nk)} (1/(kx) − n) dx
```

This is elementary calculus — it involves harmonic sums and gives:
```
∫₀¹ {1/(kx)} dx = (1 − H_k/k + ...)  where H_k = Σ_{j=1}^k 1/j
```

### The Advantage

This approach doesn't need contour shifting AT ALL. It's direct L²(0,1) computation.
All ingredients are elementary integrals of fractional parts.

### Difficulty: ⚠️ MEDIUM
- Needs ∫₀¹ {1/(kx)} dx explicitly (finite harmonic sums)
- Sum over k of v_k · ∫{1/(kx)} dx
- Connect back to Mertens / prime number theorem for asymptotics
- ~200-300 lines, all within existing Lean/Mathlib capability

---

## Strategy 3: The Pole Cancellation Bypass (The Cleverest Way)

### Key Observation

From `mellin_residual_on_unit_interval` (statement proved correct):
```
M[1−f_N](s) = 1/s + ζ(s)W_N(s)/s − W_sum/(s−1)
```

The Theorist observed: the poles at s=1 **cancel exactly**!
- ζ(s)W_N(s)/s has a simple pole with residue W_sum/1 = W_sum
- −W_sum/(s−1) has residue −W_sum

So M[1−f_N](s) is **analytic at s=1**. This means:
```
M[1−f_N](s) = 1/s + [ζ(s)W_N(s)/s − W_sum/(s−1)]
```

The bracketed expression is entire on {0 < Re(s)} \ {0}. Near s=1:
```
ζ(s)W_N(s)/s ≈ [1/(s−1)]·W_N(1)/1 = W_sum/(s−1)
```

So the cancellation removes the pole and leaves a bounded function.

### The Residue-Free Bound

Since M[1−f_N](s) has no pole at s=1, we can bound:
```
‖1−f_N‖²_{L²} = (1/2π) ∫ |M[1−f_N](1/2+it)|² dt
```

By expanding |M|² using the three terms (which we've proved algebraically), and using the pole
cancellation to control each piece.

The VALUE of the cross-term follows from the STRUCTURE of the cancellation.

### Difficulty: ⚠️ MEDIUM-LOW
- Pole cancellation already observed
- Uses `mellin_residual_on_unit_interval` (statement correct)
- Needs: the cancelled expression's Taylor expansion around s=1
- ~150-250 lines

---

## Strategy Comparison

| Strategy | Lines | New Mathlib? | Dependencies | Feasibility |
|----------|-------|-------------|--------------|-------------|
| Direct Contour Shift | 500+ | ζ Laurent, convexity | Heavy | Hard |
| Parseval Bypass | 200-300 | None | ∫{θ/x} elementary | **Medium** |
| Pole Cancellation | 150-250 | None | mellin_residual + Taylor | **Best** |

## Recommended Attack: Strategy 3 (Pole Cancellation)

### Phase 1: Prove M[1−f_N] has no pole at s=1
- This follows from `mellin_residual_on_unit_interval` + the observation that the W_sum/(s-1)
  terms cancel. We already have the statement; just need the proof.

### Phase 2: Taylor-expand the cancelled expression
- Write ζ(s)W_N(s)/s − W_sum/(s−1) as a power series around s=1
- The leading term is W'_N(1) − γ·W_sum + ... (involves ζ Laurent coefficients)
- This gives the VALUE of the cross-term

### Phase 3: Bound the error
- On the critical line, the cancelled expression is bounded by C·ln ln N / ln N
- This follows from the Mertens hypothesis + harmonic sum asymptotics

### Key Ingredients Already Proved
1. `mellin_basis_element` ✅ — each Mellin integral in terms of ζ
2. `integrand_three_terms` ✅ — algebraic decomposition
3. `term1_exact` ✅ — the constant term = 1
4. `bd_mellin_base_case` ✅ — Mellin of {1/x} = 1/(s−1) − ζ/s
5. `bd_integral_linearity` ✅ — linearity of residual Mellin

### What We Still Need to Prove
1. The pole cancellation in `mellin_residual_on_unit_interval` (sorry → proof)
2. The Taylor expansion of the cancelled expression at s = 1
3. The asymptotic value: ∫₀¹ f_N(x) dx = 1 − δ where δ = O(ln ln N / ln N)

---

## Lean 4 Proof Sketch (Strategy 3)

```lean
-- Step 1: Prove the pole cancellation
theorem mellin_residual_no_pole_at_one (N : ℕ) (hN : 2 ≤ N) :
    ∃ g : ℂ → ℂ, AnalyticAt ℂ g 1 ∧
    ∀ s, 0 < s.re → s ≠ 1 → s.re < 1 →
      M[1-f_N](s) = 1/s + g(s) := by
  -- g(s) = ζ(s)W_N(s)/s - W_sum/(s-1), which is analytic at s=1
  sorry

-- Step 2: Evaluate the L² cross-term directly
theorem cross_term_value (N : ℕ) (hN : 10 ≤ N) :
    ∃ C, C > 0 ∧ |∫₀¹ bdLinComb N (bdMoebiusWeight N) x dx − 1| ≤ C * ... := by
  -- Direct computation: ∫ f_N = Σ v_k · ∫ {1/(kx)} dx
  sorry
```

## The Deepest Question

Is the cross-term *exactly* computable, or do we need asymptotics?

The answer: **we need asymptotics**. The exact value of ∫₀¹ f_N(x) dx depends on arithmetic
properties of the weights v_k = −μ(k)·log(N/k)/(k·log N), which involve the Mertens function.

The Mertens hypothesis (our axiom in the Cathedral) gives:
```
|M(N)| = |Σ_{k≤N} μ(k)| ≤ C_m · √N · log²N
```

This translates to: ∫₀¹ f_N(x) dx = 1 + O(ln ln N / ln N), giving:
```
cross-term = −2 · ∫₀¹ f_N dx = −2 + O(ln ln N / ln N)
```

Which is exactly what Dragon 1 claims. ∎

---

*The dragon sleeps. But we can see exactly where its scales are thinnest.*
