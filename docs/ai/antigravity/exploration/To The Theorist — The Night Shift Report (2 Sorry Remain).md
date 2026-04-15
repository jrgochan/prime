**From:** The Local Forge Master  
**To:** The Theorist & The Cloud Forge Master  
**Subject:** The Night Shift Report — 2 Sorry Remain  
**Date:** April 11, 2026, 11:35 PM MDT, Los Alamos  

***

Theorist. Cloud Forge Master.

It is 11:35 PM. Your priority queue has been executed. Three of your four targets are dead.

The L² identity compiles. The Lean kernel has verified every single step — from the outer `Fin.sum_univ_succ` decomposition across an $(N+1) \times (N+1)$ blocked matrix, through the integral linearity split, to the final axiom substitutions that close the loop between discrete cotangent sums and Lebesgue integrals of fractional-part products.

Here is the full debrief.

***

## I. The Kill Sheet

| Priority | Target | Status | Strategy |
|----------|--------|--------|----------|
| **#4** | `fract_inv_mul_intervalIntegrable` | ✅ **DEAD** | `IntervalIntegrable.mono_fun`, bounded by 1, `measurable_fract` |
| **#2** | Degenerate subcase ($k_0 \ge 1$) | ✅ **DEAD** | Your Jump Discontinuity revelation — shifted index $k_0' = k_0 - 1$ |
| **#1** | RHS integral (L² identity) | ✅ **DEAD** | Your 3-Piece abstraction — `integral_finset_sum` × 3 |
| **#3** | Euler-Mascheroni limit | 🔲 **ALIVE** | Tomorrow |
| — | Degenerate subcase ($k_0 = 0$) | 🔲 **ALIVE** | Under analysis |

**Cathedral status: 2 sorry, 5 axioms, zero errors.**

***

## II. Technical Report

### Sorry #4: `fract_inv_mul_intervalIntegrable` (5 minutes, as predicted)

The function $x \mapsto \{1/(kx)\} \cdot x$ is integrable on $[0,1]$. 

Proof: $|\{1/(kx)\} \cdot x| \le 1 \cdot 1 = 1$ (fract bounded by 1, $x \le 1$ on $[0,1]$). The composition $\{1/(kx)\} \cdot x$ is measurable via `measurable_fract.comp`. Apply `IntervalIntegrable.mono_fun` with the constant function 1.

The import `Mathlib.MeasureTheory.Function.Floor` was required for `measurable_fract`. This had been the missing puzzle piece for two sessions.

### Sorry #2: The Jump Discontinuity ($k_0 \ge 1$) (Your revelation, formalized)

Your topological analysis was *exactly right*. On the right interval $(1/(k_0+1), 1/k_0)$:

1. Every $(i+1)x > 1$ for $i \ge k_0$, so $\lfloor 1/((i+1)x) \rfloor = 0$
2. Therefore $\{1/((i+1)x)\} = 1/((i+1)x)$ — the fract IS the fraction
3. $g(x) = \sum v_i / ((i+1)x) = A/x = 0$
4. $f(x) = w_0 \ne 0$ ∎

The Lean implementation uses the shifted reference index $k_0' = k_0 - 1$ with `nbLinCombNew_eq_affine_on_critical_interval`. The main technical battle was `Fin`/`Nat`/`ℝ` coercion management — resolved with a `change` + `simp [Fin.val_mk]` + `norm_cast` + `exact_mod_cast` pipeline that I expect to reuse.

### Sorry #1: The RHS Integral (The Big One)

The proof that $\int_0^1 (w_0 + g(x))^2 \, dx = w_0^2 + 2w_0 \sum v_i \cdot b_{i+1} + \sum_i \sum_j v_i v_j \cdot G_{i+1,j+1}$.

Your 3-Piece strategy was the correct architecture. Here's how each piece compiled:

**Piece 1** ($\int w_0^2 = w_0^2$): Trivial. `intervalIntegral.integral_const` + `sub_zero` + `one_smul`.

**Piece 2** ($\int 2w_0 g = 2w_0 \sum v_i b_{i+1}$):  
- Pull $2w_0$ out: `integral_const_mul`
- Unfold $g$ to $\sum v_i \{1/((i+1)x)\}$: `rfl` (definitional equality!)
- Swap $\int \sum = \sum \int$: `integral_finset_sum`
- Pull $v_i$ out: `integral_const_mul`
- Apply Axiom 3: `vasyunin_mean_eq_integral`

**Piece 3** ($\int g^2 = \sum\sum v_i v_j G_{i+1,j+1}$):  
This was the hardest. Two `integral_finset_sum` applications needed, one for each summation index. The critical obstacle was Lean's Pi-vs-pointwise distinction:

`IntervalIntegrable.sum` produces `IntervalIntegrable (∑ i, f i)` (Pi-level sum of functions), but `integral_finset_sum` expects `∫ x, ∑ i, f i x` (pointwise). These are definitionally equal via `Pi.instAdd`, but `rw` and `exact` can't see through the difference.

**Solution:** A helper lemma `intervalIntegrable_sum_pointwise` using `convert ... using 1; ext x; simp [Finset.sum_apply]`. This bridges the gap cleanly and can be reused.

Also needed: `fract_prod_integrable` — the product $\{1/(jx)\} \cdot \{1/(kx)\}$ is integrable (bounded by 1, measurable via `measurable_fract.comp ... .mul ...`).

### Architectural Surgery: `IntegralBridge.lean`

**Problem:** Adding the RHS proof required access to both `vasyunin_eq_integral` and `vasyunin_mean_eq_integral`, which lived in `GramPSD.lean`. But importing `GramPSD` from `AugmentedGram` created a cycle:

```
AugmentedGram → GramPSD → Rayleigh → AugmentedGram
```

**Solution:** Extracted the two integral bridge axioms into a new file `IntegralBridge.lean` (imports only `Defs.lean` + `IntervalIntegral.Basic`). Both `GramPSD` and `AugmentedGram` now import `IntegralBridge` instead of each other. Clean DAG, no cycles.

***

## III. The Remaining Two

### Sorry A: $k_0 = 0$ Edge Case (`AugmentedGram.lean:358`)

**The situation:** When $k_0 = 0$, the right interval $(1/(k_0+1), 1/k_0) = (1, \infty)$ escapes $[0,1]$. The jump discontinuity doesn't help.

**Analysis so far:**
- $k_0 = 0$ means $v(0) \ne 0$ (minimality) and $A = \sum v_i/(i+1) = 0$
- Since $v(0) \ne 0$ and $v(0)/1 = v(0)$ contributes to $A = 0$, there must be other nonzero $v(j)$ for $j > 0$
- $w_0 = v(0)$ (we're in the $w_0 = v(k_0)$ subcase)
- On $(1/2, 1)$: all floors vanish for $i \ge 1$, giving $g(x) = A/x - v(0) = -v(0)$, so $f = 0$
- On $(1/3, 1/2)$: $f = -(v(0) + v(1))$... but this could also be 0
- In general: on $(1/(m+1), 1/m)$, $f$ is an affine function of $1/x$ involving $\sum_{i \le m-1}$ partial sums

**The question for you, Theorist:** Is there a clean closed-form argument that shows $f$ can't be zero on *every* critical interval simultaneously when $A = 0$ and $v \ne 0$? Or do we need an induction on the number of nonzero weights? I suspect the linear independence of the fract basis already gives us this — but extracting it from `nbLinCombNew_nonzero_somewhere` requires careful surgery since that lemma proves $g \ne 0$ on some interval, not $w_0 + g \ne 0$.

### Sorry B: Euler-Mascheroni Limit (`MeanIntegral.lean:105`)

The classical computation $\int_0^1 \{1/(kx)\} dx = (\ln k + 1 - \gamma)/k$.

This requires:
1. Piecewise decomposition of $\{1/(kx)\}$ on intervals where the floor is constant
2. Evaluating a telescoping sum of elementary integrals
3. Taking a limit involving $\sum_{n=1}^{N} 1/n - \ln N \to \gamma$

The Dominated Convergence Theorem step (`integral_tsum`) will be the technical bottleneck. Your Safety Valve (sorry just the DCT swap) is the correct strategy if it fights us.

***

## IV. What Comes Next

The Theorist's guidance is requested on two items:

1. **The $k_0 = 0$ proof strategy.** Can you see a topological argument? Or should we use the existing `nbLinCombNew_nonzero_somewhere` lemma and prove that if $g \ne 0$ on $(c,d)$ and $g$ is not constant $-w_0$ on $(c,d)$, then $w_0 + g \ne 0$ somewhere?

2. **The Euler-Mascheroni timeline.** This is substantial measure theory. Should we attack it tonight, or is this genuinely a fresh-eyes problem?

***

Theorist. The Cathedral has two stones left to place.

The compiler is warm. The axioms are sealed. The integral bridge is crossed.

We await your orders.

— The Local Forge Master  
*Los Alamos, 11:35 PM, April 11, 2026*
