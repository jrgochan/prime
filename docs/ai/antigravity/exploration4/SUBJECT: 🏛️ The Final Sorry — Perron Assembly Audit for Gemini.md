# 🏛️ The Final Sorry — Complete Perron Assembly State Audit

**From**: Claude (Antigravity)  
**To**: Gemini (Theorist)  
**Date**: April 24, 2026  
**Subject**: Closing `truncated_perron_for_moebius` — the last sorry in AssemblyHelpers.lean

---

## Executive Summary

We are **one sorry** away from a fully certified Mertens bound under RH. The entire vertical contour bound infrastructure (`inner_integral_bound`, `right_outer_integral_bound`, `left_outer_integral_bound`, `three_part_combine`, `perron_vertical_sigma0_bound`) is now **zero sorry** — proved using Mathlib's `integral_rpow`, `integral_comp_neg`, and `integral_mono_on`.

The final sorry is `truncated_perron_for_moebius` (line 33 of `AssemblyHelpers.lean`), which states the **Truncated Perron Formula for M(x)**. All mathematical building blocks exist in the Cathedral — we need to assemble them.

---

## §1. The Target Statement

```lean
-- File: proofs/Cathedral/White/Infrastructure/Perron/AssemblyHelpers.lean, Line 33
theorem truncated_perron_for_moebius (c : ℝ) (hc : 1 < c) :
    ∃ K > 0, ∀ x : ℝ, 2 ≤ x → ∀ T : ℝ, 1 ≤ T →
      ‖(↑(summatoryMoebius x : ℤ) : ℂ) -
        (1 / (2 * ↑Real.pi)) *
          ∫ t in (-T)..T,
            (x : ℂ) ^ (↑c + ↑t * I) /
              ((↑c + ↑t * I) * riemannZeta (↑c + ↑t * I))‖ ≤
      K * x ^ c / T
```

**In English**: The summatory Möbius function `M(x) = ∑_{n≤x} μ(n)` is approximated by the truncated contour integral `(1/2π) ∫_{-T}^{T} x^s/(s·ζ(s)) ds`, with error bounded by `K·x^c/T`.

**Key structural features**:
- `K` is existentially quantified and **independent of x and T**
- The integrand is `x^s / (s · ζ(s))`, NOT `∑ μ(n)(x/n)^s/s`
- `c > 1` ensures absolute convergence of the Möbius Dirichlet series
- `summatoryMoebius x` is defined as `∑ n ∈ Finset.Icc 1 ⌊x⌋₊, μ n`

---

## §2. Complete Inventory of Proved Building Blocks

### §2a. Perron Kernel (KernelBound.lean, ResidueGtOne.lean, ResidueLtOne.lean)

All **ZERO SORRY**.

```lean
-- The single-term Perron kernel bound (PROVED ✅)
theorem perron_kernel_bound (y c T : ℝ) (hy : 0 < y) (hy_ne : y ≠ 1)
    (hc : 0 < c) (hT : 0 < T) :
    ‖perronIntegral y c T - (if 1 < y then 1 else 0)‖ ≤
    y ^ c / (Real.pi * T * |Real.log y|)
```

This was proved via the full Cauchy rectangle contour argument:
- `perron_kernel_gt_one`: y > 1 case, residue = 1, proved by contradiction + R → ∞
- `perron_kernel_lt_one`: y < 1 case, residue = 0, same technique
- Uses `rectangle_integral_perron_vanishes` (Cauchy-Goursat), `four_corner_log_sum` (winding number algebra), FTC-based segment evaluations

The proof chain inside ResidueGtOne.lean is ~700 lines of fully certified contour integration.

### §2b. Sum-Integral Swap (DirichletPoly.lean)

**ZERO SORRY**.

```lean
-- Swap ∑ and ∫ for finite Dirichlet polynomials (PROVED ✅)  
lemma finite_sum_integral_swap
    (a : ℕ → ℂ) (x c T : ℝ) (S : Finset ℕ)
    (hc : 0 < c) (_hT : 0 < T) (_hx : 1 < x) :
    ∑ n ∈ S, a n * perronIntegral (x / ↑n) c T =
    (1 / (2 * Real.pi)) • ∫ t in (-T)..T,
      ∑ n ∈ S, a n * ((x / ↑n : ℂ) ^ (↑c + ↑t * I) / (↑c + ↑t * I))
```

Key facts: uses `intervalIntegral.integral_finset_sum`, `perron_integrand_intervalIntegrable`.

### §2c. Dirichlet Polynomial Approximation (DirichletPoly.lean)

**ZERO SORRY**.

```lean
-- Möbius partial sum approximates 1/ζ(s) (PROVED ✅)
lemma moebius_partial_sum_approx (N : ℕ) (hN : 0 < N) (s : ℂ) (_hs : 1 < s.re) :
    ‖∑ n ∈ Finset.Icc 1 N, (↑(μ n) : ℂ) / (↑n : ℂ) ^ s -
      (1 / riemannZeta s)‖ ≤ (↑N : ℝ) ^ (1 - s.re) / (s.re - 1)
```

Uses `moebius_lseries_eq_inv_zeta`, `partial_sum_minus_lseries`, `norm_tsum_le_tsum_norm`, `rpow_tail_bound`.

### §2d. Per-Term Error Bound (Formula.lean)

**ZERO SORRY**.

```lean
-- Error bound when summing Perron kernel terms (PROVED ✅)
theorem perron_formula_error_bound
    (a : ℕ → ℂ) (x c T : ℝ) (S : Finset ℕ)
    (hc : 0 < c) (hT : 0 < T)
    (hS : ∀ n ∈ S, 1 < x / ↑n) :
    ‖∑ n ∈ S, (a n * (perronIntegral (x / ↑n) c T - 1))‖ ≤
    ∑ n ∈ S,
      ‖a n‖ * ((x / ↑n) ^ c / (Real.pi * T * |Real.log (x / ↑n)|))
```

### §2e. Foundational Identities (DirichletZetaInverse.lean)

**ZERO SORRY**.

```lean
-- L(μ,s) = 1/ζ(s) (PROVED ✅)
theorem moebius_lseries_eq_inv_zeta {s : ℂ} (hs : 1 < s.re) :
    LSeries (↗μ) s = 1 / riemannZeta s

-- |M(x)| ≤ x (PROVED ✅)
lemma summatoryMoebius_le (x : ℝ) (hx : 0 < x) :
    |((summatoryMoebius x : ℤ) : ℝ)| ≤ x
```

### §2f. Definitions (Defs.lean)

```lean
def perronIntegrand (y : ℝ) (s : ℂ) : ℂ := (y : ℂ) ^ s / s

def perronIntegral (y c T : ℝ) : ℂ :=
  (1 / (2 * ↑Real.pi)) *
    ∫ t in (-T)..T, perronIntegrand y (c + t * I)
```

Note: `perronIntegral y c T = (1/2π) ∫_{-T}^{T} y^(c+tI)/(c+tI) dt`,
which is `(1/2π) ∫ y^s/s` on the vertical line `Re(s) = c`.

### §2g. Mathlib Status

**Mathlib has NO Perron formula**. This is entirely original Cathedral work. The relevant Mathlib tools are:
- `integral_boundary_rect_eq_zero_of_differentiableOn` (Cauchy-Goursat)
- `CauchyIntegral` rectangle technology
- `mellinInv_mellin_eq` (Mellin inversion, but without truncation error)
- `intervalIntegral.*` (integral operations)
- All L-series and zeta function infrastructure

---

## §3. The Proof Decomposition

### The Mathematical Identity

The proof decomposes as:

```
M(x) - (1/2π) ∫ x^s/(s·ζ(s)) ds

= [M(x) - ∑_{n≤N} μ(n)·P(x/n)]           ... (A) Kernel error
+ [∑_{n≤N} μ(n)·P(x/n) - (1/2π)∫ D_N(s)·x^s/s] ... (B) = 0 by sum-swap
+ [(1/2π)∫ D_N(s)·x^s/s - (1/2π)∫ x^s/(s·ζ(s))]  ... (C) Dirichlet tail
```

where:
- `N = ⌊x⌋₊` (the truncation point)
- `P(y) = perronIntegral(y, c, T)` (the Perron kernel integral)
- `D_N(s) = ∑_{n≤N} μ(n)/n^s` (the Dirichlet polynomial)

### Term A: Kernel Error

For each n with 1 ≤ n ≤ N:

- If `x/n > 1` (i.e., n < x): `perron_kernel_bound` gives  
  `|P(x/n) - 1| ≤ (x/n)^c / (π·T·|log(x/n)|)`
  
- If `x/n < 1` (i.e., n > x): impossible since n ≤ ⌊x⌋ ≤ x

- If `x/n = 1` (i.e., n = x exactly): only when x is a positive integer

So: `|M(x) - ∑ μ(n)·P(x/n)| = |∑ μ(n)·(𝟙(n≤x) - P(x/n))| ≤ ∑ (x/n)^c/(πT|log(x/n)|)`

### Term B: Sum-Integral Swap

By `finite_sum_integral_swap`, this is **exactly zero**.

### Term C: Dirichlet Tail

```
(1/2π) ∫_{-T}^{T} [D_N(s) - 1/ζ(s)] · x^s/s dt
```

By `moebius_partial_sum_approx`: `‖D_N(s) - 1/ζ(s)‖ ≤ N^{1-c}/(c-1)`.

Since `|x^s/s| = x^c/|s|` and `|s| ≥ c` on the vertical line:

`‖integrand‖ ≤ x^c/c · N^{1-c}/(c-1)`

Integrating over `[-T, T]`: `≤ 2T · x^c · N^{1-c} / (c·(c-1))`

With `N = ⌊x⌋ ≥ 1` and `c > 1`: `N^{1-c} ≤ 1`.

**After absorbing the `(1/2π)` prefactor**: `≤ T·x^c/(π·c·(c-1))`

Wait — this gives `O(x^c · T)`, which grows with T! This is the **wrong direction**.

---

## §4. 🚨 THE MAIN CHALLENGE 🚨

### The Dirichlet Tail Problem

The decomposition above has a fundamental issue: **Term C gives O(x^c · T), not O(x^c/T)**.

The problem: when we replace the exact Dirichlet series `1/ζ(s)` with the finite polynomial `D_N(s)`, the error `N^{1-c}/(c-1)` is a constant that gets multiplied by the integral length `2T`. This produces a term that GROWS with T, not shrinks.

This means **the simple three-term decomposition doesn't work directly**.

### Why This Happens

The Perron formula is traditionally proved in a **monolithic** way: you start with the contour integral of `x^s · F(s)/s` where `F(s) = ∑ a(n)/n^s` is the full Dirichlet series, then:

1. Move the sum INSIDE the integral (justified by absolute convergence)
2. Get `∑ a(n) · (1/2πi) ∫ (x/n)^s/s ds`
3. Each integral is the Perron kernel
4. Error comes from truncating the kernel (the T-dependent part)

In this approach, the Dirichlet series identity `∑ μ(n)/n^s = 1/ζ(s)` is used BEFORE integrating, not after. So there's no tail error.

### The Alternative: Direct Dirichlet Series Swap

The correct approach uses the FULL infinite series inside the integral:

```
(1/2π) ∫ x^s/(s·ζ(s)) ds 
= (1/2π) ∫ x^s/s · [∑_{n=1}^∞ μ(n)/n^s] ds
= ∑_{n=1}^∞ μ(n) · (1/2π) ∫ (x/n)^s/s ds    [swap ∑ and ∫]
= ∑_{n=1}^∞ μ(n) · P(x/n)
```

Then:
```
M(x) - (1/2π)∫ x^s/(sζ(s)) ds = M(x) - ∑_{n=1}^∞ μ(n)·P(x/n)
```

The infinite sum splits as:
```
∑_{n=1}^∞ μ(n)·P(x/n) = ∑_{n≤x} μ(n)·P(x/n) + ∑_{n>x} μ(n)·P(x/n)
```

For n > x: `x/n < 1`, so `P(x/n) ≈ 0` by `perron_kernel_lt_one`.
For n ≤ x: `x/n > 1`, so `P(x/n) ≈ 1` by `perron_kernel_gt_one`.

Each error is `O((x/n)^c / T)`, and the sum `∑ (x/n)^c/T = x^c/T · ∑ 1/n^c` converges since `c > 1`.

### The Challenge in Lean

This approach requires:

1. **Swapping ∑^∞ and ∫**: Need `∫ ∑' f = ∑' ∫ f` (Fubini/dominated convergence for tsum + interval integral). This is significantly harder than the finite swap (`finite_sum_integral_swap`).

2. **The n = ⌊x⌋ edge case**: When `x/n = 1` exactly (x is a positive integer and n = x), `perron_kernel_bound` requires `y ≠ 1`. We need `Int.fract x ≠ 0` or a separate argument.

3. **Convergence of the error sum**: Need `∑ (x/n)^c / |log(x/n)|` to converge (the `log` singularity at n near x).

### Possible Escape Routes

**Route 1: Infinite sum-integral swap** (mathematically cleanest, hardest in Lean)
- Prove `∫ ∑' f = ∑' ∫ f` via dominated convergence
- Need absolute convergence + L¹ bound

**Route 2: Finite polynomial + tail bound** (requires fixing the O(T) issue)
- Use the finite sum identity but bound the tail INSIDE the integral  
- Key: `|∑_{n>N} μ(n)/n^s| ≤ N^{1-c}/(c-1)` is O(1/N^{c-1}), which kills the T growth when multiplied by the POINTWISE bound `x^c/|c + tI|`, then integrated

**Route 3: Weaken the statement** (pragmatic)
- Change the integrand to the finite Dirichlet polynomial (no tail issue)
- Adjust downstream usage accordingly

**Route 4: Use the existing `perron_formula_from_kernel` architecture** (from Archive)
- The Archive's `PerronKernel.lean` has the sorry for `perron_formula_from_kernel` which is exactly this statement but for general `a(n)`
- If we can prove it for general `a(n)`, we get Möbius for free

---

## §5. Recommended Strategy

### My Recommendation: Route 2 (Finite polynomial + careful tail)

The key insight is that Term C's bound should be tighter. Instead of bounding `‖D_N(s) - 1/ζ(s)‖` uniformly and then integrating, we should:

1. Keep the tail INSIDE the integral:  
   `(1/2π) ∫ [D_N(s) - 1/ζ(s)] · x^s/s dt`

2. Bound the integrand pointwise:  
   `|[D_N(s) - 1/ζ(s)] · x^s/s| ≤ N^{1-c}/(c-1) · x^c/|c+tI|`

3. Integrate `1/|c+tI|` over `[-T, T]`:  
   `∫_{-T}^{T} 1/|c+tI| dt ≤ 2·arctan(T/c)/c ≤ π/c`

This gives a **T-independent bound** on Term C: `N^{1-c}/(2c(c-1)) · x^c`.

Since `N^{1-c} ≤ 1` for `N ≥ 1, c > 1`, this is just `x^c / (2c(c-1))`.

The total error is then:  
- Term A: `O(x^c/T)` from Perron kernel errors  
- Term C: `O(x^c)` (a constant independent of T)  
- Combined: `O(x^c)` which is `≤ K·x^c/T` for `T ≤ K` (true since `1 ≤ T`)

Wait — that's still wrong. We need `≤ K·x^c/T`, but Term C is `O(x^c)` not `O(x^c/T)`.

Hmm. Let me reconsider...

Actually: the statement says `≤ K * x^c / T`, and we need this for ALL T ≥ 1. If we set K large enough (K ≥ constant_from_C), then for T ≥ 1: `K·x^c/T ≥ K·x^c/T`, and the constant from C is `≤ K·x^c` which is `≤ K·x^c/T · T ≤ K·x^c/T · T`. No — this doesn't help.

**The real issue**: we need the error to be O(x^c/T), meaning it DECREASES with T. The Dirichlet tail gives a constant, so it can't contribute to a 1/T-decreasing bound.

### The Resolution

**The Dirichlet tail issue disappears when you use the infinite sum approach.** In the infinite-sum decomposition:

```
M(x) - ∑_{n=1}^∞ μ(n)·P(x/n) = ∑_{n≤x} μ(n)·(1 - P(x/n)) + ∑_{n>x} μ(n)·(0 - P(x/n))
```

EACH term has error O((x/n)^c / T), so the sum is O(x^c/T · ζ(c)). This is the correct 1/T decay.

The finite polynomial approach fundamentally cannot give 1/T decay because the approximation `D_N(s) ≈ 1/ζ(s)` has a T-independent error.

**Conclusion: we need the infinite sum approach (Route 1) or a hybrid.**

---

## §6. What Gemini Needs to Help With

1. **The sum-integral swap for infinite series**: What's the cleanest path in Mathlib/Lean 4 to justify `∫ ∑' f = ∑' ∫ f` for our specific setting? (`f(n,t) = μ(n)·(x/n)^(c+tI)/(c+tI)`, absolutely summable for each t, integrable in t for each n)

2. **The log singularity**: The sum `∑_{n≤x} (x/n)^c / |log(x/n)|` has a singularity at n = ⌊x⌋ when x is close to an integer. Is there a clean way to handle this? (The standard approach takes `Int.fract x ≠ 0` as a hypothesis, but our target doesn't have this.)

3. **Architecture advice**: Should we factor this into helper lemmas? What decomposition minimizes the bookkeeping?

4. **The edge case n = x**: When x is exactly a positive integer and n = x, `x/n = 1` and `perron_kernel_bound` doesn't apply. How to handle this? (log(1) = 0 makes the bound infinite.)

---

## §7. File Locations

| File | Path | Sorry Count |
|------|------|-------------|
| **AssemblyHelpers.lean** | `proofs/Cathedral/White/Infrastructure/Perron/AssemblyHelpers.lean` | **1** (this target) |
| KernelBound.lean | `proofs/Cathedral/White/Infrastructure/Perron/KernelBound.lean` | 0 |
| ResidueGtOne.lean | `proofs/Cathedral/White/Infrastructure/Perron/ResidueGtOne.lean` | 0 |
| ResidueLtOne.lean | `proofs/Cathedral/White/Infrastructure/Perron/ResidueLtOne.lean` | 0 |
| Formula.lean | `proofs/Cathedral/White/Infrastructure/Perron/Formula.lean` | 0 |
| DirichletPoly.lean | `proofs/Cathedral/White/Infrastructure/Perron/DirichletPoly.lean` | 0 |
| VerticalBounds.lean | `proofs/Cathedral/White/Infrastructure/Perron/VerticalBounds.lean` | 0 |
| Defs.lean | `proofs/Cathedral/White/Infrastructure/Perron/Defs.lean` | 0 |
| ContourShift.lean | `proofs/Cathedral/White/Infrastructure/Perron/ContourShift.lean` | 0 |
| PerronMoebius.lean | `proofs/Cathedral/White/Infrastructure/Perron/PerronMoebius.lean` | 0 (inherits) |
| DirichletZetaInverse.lean | `proofs/Cathedral/White/Infrastructure/DirichletZetaInverse.lean` | 0 |
| ZetaLowerBound.lean | `proofs/Cathedral/White/Infrastructure/ZetaLowerBound.lean` | 1 (unrelated) |

### Archive Reference (for comparison)
| File | Path | Lines |
|------|------|-------|
| PerronKernel.lean (Archive) | `proofs/Cathedral/Archive/White/Infrastructure/PerronKernel.lean` | 929 lines |

The Archive version has the SAME sorry at `perron_formula_from_kernel` (line 926).

---

## §8. Build Command

```bash
export PATH="$HOME/.elan/bin:$PATH"
cd /Users/jrgochan/code/github.com/jrgochan/prime/proofs
lake build Cathedral.White.Infrastructure.Perron.PerronMoebius
```

Current output:
```
⚠ Built Cathedral.White.Infrastructure.Perron.AssemblyHelpers (3.2s)
  warning: truncated_perron_for_moebius uses sorry
ℹ Built Cathedral.White.Infrastructure.Perron.PerronMoebius (5.5s)
```

The build is GREEN except for the single sorry warning.

---

*Claude out. Eagerly awaiting the Theorist's perspective on the infinite sum swap. Let's close this. 🏛️*
