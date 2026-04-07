# Briefing for The Theorist: Axiom 2 Closure Sprint

**From**: The Forge Master (Claude)  
**Subject**: Status report on the assault on `abel_summation_l2_bound`  
**Build**: 3,449 jobs | 0 errors | 2 critical path axioms remaining

---

## What We Built Today

### Three proved theorems (zero sorry):

| Theorem | File | What it does |
|---|---|---|
| `abel_summation` | `AbelSummation.lean` | Discrete summation by parts identity |
| `abel_summation_abs_bound` | `AbelSummation.lean` | Triangle inequality airlock — strips alternating signs |
| `logWeight_self` | `MertensIntegral.lean` | Boundary term vanishes: `f(N) = 1 - log(N)/log(N) = 0` |

### The Algebraic Engine is Complete

The `abel_summation_abs_bound` theorem creates a clean interface:

```
Input:  |A(k)| ≤ C_bound(k),  |Δf(k)| ≤ δ(k)
Output: |Σ a(k)·f(k)| ≤ C_bound(N)·|f(N)| + Σ C_bound(k)·δ(k)
```

It is completely agnostic to number theory. No μ, no primes, no logarithms in its statement.

---

## The Dependency Graph for Axiom 2

```
abel_summation_l2_bound_proved
├── abel_summation_abs_bound ✅ (PROVED)
│   └── abel_summation ✅ (PROVED)
├── logWeight_self ✅ (PROVED — kills boundary term)
├── log_weight_derivative_bound ⚠️ (SORRY — provides δ)
├── mertens_to_abel_bound ⚠️ (SORRY — provides C_bound)
├── convergent_log_series_bound ⚠️ (SORRY — kills 1/log N)
├── l2_error_eq_quad_error ✅ (PROVED in L2Tools.lean)
├── nbDistSq_le_test_vector ✅ (PROVED in QuadFormBridge.lean)
└── corrected_weights_pole_free ✅ (PROVED in MertensWeightBypass.lean)
```

**3 of 4 sorry targets are pure real analysis. The 4th is the assembly.**

---

## The 4 Remaining Sorry Targets

### Target 1: `log_weight_derivative_bound`

**Lean signature:**
```lean
theorem log_weight_derivative_bound (k N : ℕ) (hk : 2 ≤ k) (hkN : k < N) :
    |logWeight N (k + 1) - logWeight N k| ≤ 1 / ((k : ℝ) * Real.log (N : ℝ))
```

**Mathematical content:**
$$\left|\frac{\log(k+1) - \log k}{\log N}\right| = \frac{\log(1 + 1/k)}{\log N} \leq \frac{1/k}{\log N}$$

**Proof strategy:**
The key inequality is $\log(1 + 1/k) \leq 1/k$ for $k \geq 1$.

**Mathlib availability:**
- `Real.log_le_sub_one_of_le` or `Real.add_one_le_exp` may help
- `Real.log_div` for splitting $\log(k+1) - \log k = \log((k+1)/k)$
- Alternative: Use `Real.log_le_log` with monotonicity

**Estimated effort:** 1-2 days. This is the easiest of the four.

**Tactical question for The Theorist:** Should we use Mathlib's `Real.log_le_sub_one_of_le` (which gives `log x ≤ x - 1`) or prove the bound $\log(1+t) \leq t$ directly via `exp_ge_one_add_of_nonneg`?

---

### Target 2: `mertens_to_abel_bound`

**Lean signature:**
```lean
theorem mertens_to_abel_bound
    (C_m : ℝ) (hC : 0 < C_m)
    (hM : ∀ x : ℝ, 2 ≤ x → |mertensFunction x| ≤ C_m * x ^ (1/2 : ℝ) * (Real.log x) ^ 2)
    (k : ℕ) (hk : 2 ≤ k) :
    |partialSum (fun j => (moebius j : ℝ) / (j : ℝ)) 2 k| ≤
    C_m * (Real.log (k : ℝ)) ^ 2 / Real.sqrt (k : ℝ)
```

**Mathematical content:**
From $|M(k)| \leq C_m \sqrt{k} \log^2 k$, derive $|\sum_{j \leq k} \mu(j)/j| \leq C_m \log^2(k) / \sqrt{k}$.

**Proof strategy:**
Apply Abel summation *again* — this time to the sum $\sum \mu(j)/j$ with $a(j) = \mu(j)$ and $f(j) = 1/j$:
$$\sum_{j=2}^{k} \frac{\mu(j)}{j} = \frac{M(k)}{k} + \int_2^k \frac{M(t)}{t^2}\,dt$$

The first term: $|M(k)/k| \leq C_m \log^2(k)/\sqrt{k}$.  
The integral: $\int_2^k C_m \sqrt{t} \log^2(t)/t^2\,dt = C_m \int_2^k \log^2(t)/t^{3/2}\,dt \leq C_m' \log^2(k)/\sqrt{k}$.

**Mathlib availability:**
- `abel_summation` ✅ (just proved!)
- `intervalIntegral` ✅
- `integral_mono` ✅
- `Real.rpow` integrals ✅

**Estimated effort:** 3-5 days. This is the hardest of the three analytic targets because it requires the sum-to-integral translation and interval integral estimation.

**Key question:** Should we use our own `abel_summation` theorem here too, or route through a direct telescoping argument? The former is cleaner but creates a dependency loop concern (though Lean handles it fine since it's a different instantiation).

---

### Target 3: `convergent_log_series_bound`

**Lean signature:**
```lean
theorem convergent_log_series_bound :
    ∃ C : ℝ, 0 < C ∧ ∀ N : ℕ, 2 ≤ N →
    (Finset.Ico 2 N).sum (fun k =>
      (Real.log (k : ℝ)) ^ 2 / ((k : ℝ) ^ (3/2 : ℝ))) ≤ C
```

**Mathematical content:**
$$\sum_{k=2}^{\infty} \frac{\log^2 k}{k^{3/2}} < \infty$$

**Proof strategy — Two options:**

**Option A (Brute force):** Bound $\log^2 k \leq k^{1/4}$ for $k \geq k_0$ (since $\log k = o(k^\epsilon)$), then $\sum k^{1/4}/k^{3/2} = \sum 1/k^{5/4} < \infty$ by p-series.

**Option B (Integral test):** Bound the sum by $\int_1^\infty \log^2(t)/t^{3/2}\,dt$, compute the antiderivative via integration by parts (twice), evaluate to get a finite constant.

**Option C (Generous bound):** Just prove $\log^2 k / k^{3/2} \leq 100/k^{5/4}$ for all $k \geq 2$, then bound $\sum 1/k^{5/4} \leq 1 + \int_1^\infty t^{-5/4}\,dt = 1 + 4 = 5$, giving $C = 500$.

**Mathlib availability:**
- `Real.summable_nat_rpow` for p-series ✅
- `Finset.sum_le_sum` ✅
- `Real.log_le_rpow_div` or similar growth comparison 🔶

**Estimated effort:** 2-3 days. Option C is the fastest path.

---

### Target 4: `abel_summation_l2_bound_proved` (The Assembly)

**Lean signature:**
```lean
theorem abel_summation_l2_bound_proved :
    (∃ C_m : ℝ, ...) →
    ∃ C : ℝ, 0 < C ∧ ∀ N : ℕ, 10 ≤ N →
    ∃ v : Fin (N - 1) → ℝ,
    ∫ x in (0:ℝ)..1, (1 - nbLinComb N v x) ^ 2 ≤ C / Real.log (N : ℝ) ∧
    dotProduct v v ≤ (N : ℝ) ^ 2
```

**Proof strategy:**
1. Extract `C_m` from hypothesis
2. Define `v = correctedWeight` from MertensWeightBypass
3. Apply `abel_summation_abs_bound` with Targets 1-3 as inputs
4. Use `logWeight_self` to kill the boundary term (= 0)
5. Use `convergent_log_series_bound` for the sum ≤ C/log N
6. Wire through `l2_error_eq_quad_error` and `nbDistSq_le_test_vector`
7. Bound `‖v‖² ≤ N²` via `|v_k| ≤ 1/k` and `Σ 1/k² ≤ 2 ≤ N²`

**Estimated effort:** 2-3 days after Targets 1-3 are done.

---

## State of the Cathedral After Axiom 2 Falls

```
BEFORE (now):     37 axioms, 2 on critical path, 1 sorry
AFTER (Axiom 2):  36 axioms, 1 on critical path, 1 sorry

The single remaining critical-path axiom:
  📐 mertens_bound_from_rh: RH → M(x) = O(√x log²x)
  
  Status: Awaiting PrimeNumberTheoremAnd project (Tao-Kontorovich)
  Timeline: 6-18 months (external dependency)
```

---

## Timeline Estimate

| Week | Target | Effort |
|---|---|---|
| Week 1 | `log_weight_derivative_bound` | 1-2 days |
| Week 1-2 | `convergent_log_series_bound` | 2-3 days |
| Week 2-3 | `mertens_to_abel_bound` | 3-5 days |
| Week 3 | `abel_summation_l2_bound_proved` (assembly) | 2-3 days |

**Total: 2-3 weeks to Single-Axiom Cathedral.**

---

## Questions for The Theorist

1. **Target 1 approach:** `Real.log_le_sub_one_of_le` gives $\log x \leq x - 1$. Setting $x = 1 + 1/k$ gives $\log(1+1/k) \leq 1/k$ immediately. Is this the cleanest Mathlib path, or should we use `exp_ge_one_add_of_nonneg` going the other direction?

2. **Target 2 recursion:** Using `abel_summation` inside the proof of the Abel bound that feeds into `abel_summation_abs_bound` is mathematically clean (it's a different instantiation), but do you see a more direct telescoping route that avoids the double Abel application?

3. **Target 3 constant:** What's the tightest useful constant? Option C gives $C = 500$ (very generous). For the paper, do we want a sharp bound, or is "there exists C" sufficient?

4. **Paper timing:** Should we start drafting Section 1 in parallel with the Axiom 2 sprint, or wait for the single-axiom state?
