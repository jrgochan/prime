# Attacking `vasyunin_eq_integral` — Research Notes

*April 11, 2026, 6:28 AM MDT*

## The Axiom

```lean
axiom vasyunin_eq_integral (j k : ℕ) (hj : j ≥ 1) (hk : k ≥ 1) :
    vasyuninGramEntry j k =
    ∫ x in (0:ℝ)..1, Int.fract ((j:ℝ) / x) * Int.fract ((k:ℝ) / x)
```

## What This Says

The closed-form cotangent-sum formula for the Gram matrix entries equals the L²(0,1) inner product of fractional-part sawtooth functions.

## The Proof Strategy

### Step 1: Piecewise Decomposition

On the interval `(j/(n+1), j/n]`, we have `⌊j/x⌋ = n`, so `{j/x} = j/x - n`.

Therefore:
```
∫₀¹ {j/x}{k/x} dx = Σₘ Σₙ ∫_{max(j/(m+1), k/(n+1))}^{min(j/m, k/n)} (j/x - m)(k/x - n) dx
```

### Step 2: Polynomial Integration

Each piece is a rational function of x:
```
(j/x - m)(k/x - n) = jk/x² - (jn + km)/x + mn
```

Integral of each term is standard:
- `∫ jk/x² dx = -jk/x`
- `∫ (jn+km)/x dx = (jn+km) · ln(x)`
- `∫ mn dx = mn · x`

### Step 3: Cotangent Sum Emergence

The sum over intervals produces:
- Log terms → `log(2π) - γ` part (via Stirling/digamma)
- Rational terms → `1/(jk)` part  
- Cross terms → cotangent sums (via Ramanujan/Dedekind)

### Step 4: Matching to Closed Form

Show the resulting expression equals `vasyuninGramEntry j k`.

## Mathlib Infrastructure Assessment

### Available
- `Int.fract` — basic fractional part function ✅
- `MeasureTheory.Function.Floor` — measurability of floor/fract ✅
- `IntervalIntegral` — Lebesgue integration on intervals ✅
- `integral_comp_mul_right`, etc. — substitution rules ✅

### Needed but Challenging
- Splitting ∫₀¹ into infinitely many subintervals (convergence)
- Interchange of sum and integral (dominated convergence)
- Digamma/Stirling approximations for the log(2π) term
- Cotangent sum identities (Ramanujan sums)

### Key Mathlib Lemmas to Find
- `intervalIntegral.integral_union_of_disjoint` or similar for splitting
- `MeasureTheory.integral_sum` for sum-integral interchange
- `Int.fract_div_intCast_eq` or related for {j/x} decomposition

## Difficulty Assessment

**Estimated effort: 3-5 focused sessions (20-40 hours)**

The integral decomposition is straightforward mathematics but painful Lean plumbing. Each step is individually provable but the sum involves:
1. Infinite series convergence arguments  
2. Careful handling of the singularity at x=0
3. Matching nested sum structures to the cotangent formula

## Alternative: Diagonal-Only Attack

The **diagonal case** j = k is dramatically simpler:
```
∫₀¹ {j/x}² dx = (log(2π) - γ)/j - 1/j²
```

This avoids the cross-term cotangent sums entirely.  
Could prove the diagonal case first, which would partially verify the axiom.

## Recommendation

Start with the **diagonal case** (j = k) as a proof of concept. If that succeeds, the off-diagonal case follows by the same decomposition but with more bookkeeping.
