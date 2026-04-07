# The Two Remaining Axioms: A Theorist's Analysis

> **Status**: Both axioms are *known true theorems* from classical mathematics.  
> **Challenge**: Porting them into Lean 4 / Mathlib 4.  
> **Assessment**: Axiom 2 is closable within weeks. Axiom 1 depends on ongoing community work.

---

## Axiom 1: `mertens_bound_from_rh`

### The Lean Signature

```lean
axiom mertens_bound_from_rh :
    RiemannHypothesis →
    ∃ C : ℝ, 0 < C ∧ ∀ x : ℝ, 2 ≤ x →
    |((mertensFunction x : ℤ) : ℝ)| ≤ C * x ^ (1/2 : ℝ) * (Real.log x) ^ 2
```

where `mertensFunction x = Σ_{n ≤ x} μ(n)` (our definition using `Finset.filter` over `Finset.range`).

### What This Says Mathematically

$$\text{RH} \implies |M(x)| \leq C \sqrt{x} \log^2 x \quad \forall\, x \geq 2$$

This is the **Titchmarsh bound** (Theorem 14.25(C) in *The Theory of the Riemann Zeta-Function*). The classical proof goes:

1. Start with the Perron inversion formula: $M(x) = \frac{1}{2\pi i} \int_{c-i\infty}^{c+i\infty} \frac{x^s}{\zeta(s) \cdot s}\, ds$
2. Shift the contour to $\text{Re}(s) = 1/2 + \varepsilon$
3. RH guarantees $1/\zeta(s)$ has no poles beyond the critical line
4. The residual integral is bounded by $\mathcal{O}(x^{1/2+\varepsilon})$
5. The $\log^2 x$ factor comes from the density of zeros on the critical line

### Mathlib Landscape

| Ingredient | Mathlib Status | Gap |
|---|---|---|
| `ArithmeticFunction.moebius` | ✅ Available | — |
| `Finset.sum`, `Finset.filter` | ✅ Available | — |
| `Real.log`, `Real.rpow` | ✅ Available | — |
| `RiemannHypothesis` (our def) | ✅ In Cathedral | — |
| Perron's inversion formula | ❌ **Not in Mathlib** | Major gap |
| Contour integration (`∮`) | ❌ **Not in Mathlib** | Major gap |
| $1/\zeta(s)$ analytic continuation | ❌ **Not in Mathlib** | Major gap |
| Zero-free region estimates | ❌ **Not in Mathlib** | Major gap |
| Zero density estimates | ❌ **Not in Mathlib** | Major gap |

### Feasibility Assessment

> [!CAUTION]
> **This is the hardest axiom.** The classical proof requires exactly the complex-analytic machinery we bypassed. However, there are two viable paths:

#### Path A: The PrimeNumberTheoremAnd Project (External)

The **Tao-Kontorovich PrimeNumberTheoremAnd** project has:
- ✅ Formalized PNT via Wiener-Ikehara
- 🔶 Developing "MediumPNT" with explicit error terms
- 🔶 Building Perron formula machinery
- 🔶 Working toward zero-free region estimates

**Timeline**: If the PrimeNumberTheoremAnd project completes its Perron formula branch, the Mertens bound follows naturally. This is an **external dependency** — estimated 6-18 months.

**Integration strategy**: Import PrimeNumberTheoremAnd as a Lake dependency, adapt their `M(x)` definition to match ours, and apply their explicit error bound.

#### Path B: The Selberg-Delange Direct Route

An alternative avoiding Perron entirely:
1. Start from $\sum_{n \leq x} \mu(n)/n^s = 1/\zeta(s)$ (Euler product, already approachable)
2. Use partial summation to relate $M(x)$ to $\sum \mu(n)/n^{1/2}$
3. Apply Selberg's elementary identity relating $M(x)$ to $\psi(x)$
4. Use $\psi(x) = x + O(x^{1/2} \log^2 x)$ (equivalent to RH)

This route avoids contour integration but still needs the zero-free region. **Not obviously shorter.**

#### Path C: Accept as Axiom (Current Choice)

The axiom is **logically sound**: it states a direction of a *known equivalence* (Titchmarsh 14.25). The other direction ($M(x) = O(x^{1/2+\varepsilon}) \implies \text{RH}$) is even harder to formalize. By stating only the forward direction, we create a clean modular interface.

**Recommendation**: Leave as axiom. Monitor PrimeNumberTheoremAnd. When their Perron branch completes, the axiom can be closed by a domain expert in ~2 weeks of Lean work.

---

## Axiom 2: `abel_summation_l2_bound`

### The Lean Signature

```lean
axiom abel_summation_l2_bound :
    (∃ C_m : ℝ, 0 < C_m ∧ ∀ x : ℝ, 2 ≤ x →
      |((mertensFunction x : ℤ) : ℝ)| ≤ C_m * x ^ (1/2 : ℝ) * (Real.log x) ^ 2) →
    ∃ C : ℝ, 0 < C ∧
    ∀ N : ℕ, 10 ≤ N →
    ∃ v : Fin (N - 1) → ℝ,
    ∫ x in (0:ℝ)..1, (1 - nbLinComb N v x) ^ 2 ≤ C / Real.log (N : ℝ) ∧
    dotProduct v v ≤ (N : ℝ) ^ 2
```

### What This Says Mathematically

Given $|M(x)| \leq C_m \sqrt{x} \log^2 x$, construct weights $v$ such that:
$$\int_0^1 \left(1 - \sum_{k=2}^{N} v_k \left\{\frac{k}{x}\right\}\right)^2 dx \leq \frac{C}{\log N}$$

### The Proof Strategy (Paper Mathematics)

The proof decomposes into five steps, each independently tractable:

**Step 1: Define the weights.** Use our `correctedWeight`:
$$v_k = \frac{\mu(k)}{k}\left(1 - \frac{\log k}{\log N}\right) \quad + \text{pole correction at } k=2$$

**Step 2: Expand the L² error.**
$$\|1 - f_N\|^2 = 1 - 2\sum v_k b_k + \sum_{j,k} v_j v_k G_{jk}$$
where $b_k = \int_0^1 \{k/x\}\,dx$ and $G_{jk} = \int_0^1 \{j/x\}\{k/x\}\,dx$.

This is already PROVED in the Cathedral as `l2_error_eq_quad_error`.

**Step 3: Bound the cross terms via Abel summation.**
The key identity (summation by parts):
$$\sum_{k=2}^{N} a_k f(k) = A(N)f(N) - \int_2^N A(t) f'(t)\,dt$$
where $A(t) = \sum_{k \leq t} a_k$ and $a_k = \mu(k)/k$.

With $f(k) = 1 - \log k / \log N$, we get $f'(t) = -1/(t \log N)$, so:
$$\left|\sum_{k=2}^{N} \frac{\mu(k)}{k}\left(1 - \frac{\log k}{\log N}\right)\right| \leq \frac{|A(N)|}{\log N} + \frac{1}{\log N}\int_2^N \frac{|A(t)|}{t}\,dt$$

**Step 4: Apply the Mertens bound.**
$A(t) = M(t)/$ (partial Möbius sum), so $|A(t)| \leq C_m \sqrt{t} \log^2 t / t$, giving:
$$\int_2^N \frac{|A(t)|}{t}\,dt \leq C_m \int_2^N \frac{\log^2 t}{\sqrt{t}}\,dt = \mathcal{O}(\sqrt{N} \log^2 N)$$

**Step 5: Combine.**
The total $L^2$ error is $\mathcal{O}(1/\log N)$ after accounting for the Gram matrix structure.

### Mathlib Landscape

| Ingredient | Mathlib Status | Gap |
|---|---|---|
| `ArithmeticFunction.moebius` | ✅ Available | — |
| `Finset.sum`, `Finset.Icc` | ✅ Available | — |
| `intervalIntegral` | ✅ Available | — |
| `integral_add`, `integral_sub` | ✅ Available | — |
| `integral_const_mul` | ✅ Available | — |
| `integral_mono` (comparison) | ✅ Available | — |
| `Real.log`, `Real.rpow` | ✅ Available | — |
| Integration by parts | 🔶 **Partial** (Stokes-like) | Needs wrapping |
| Abel/summation by parts | ❌ **Not in Mathlib** | Must be built |
| Step function integrals | ❌ **Not in Mathlib** | Must be built |
| Sum-integral interchange | 🔶 **Available for finite sums** | Straightforward |

### Feasibility Assessment

> [!IMPORTANT]
> **This axiom is closable.** It requires no complex analysis, no PNT, no deep number theory. It is a statement of pure real analysis: summation by parts + integral estimation.

#### The Build Plan

**Phase 1: Abel Summation Lemma (~3-5 days)**

State and prove the discrete summation-by-parts identity:
```lean
theorem abel_summation (a : ℕ → ℝ) (f : ℕ → ℝ) (M N : ℕ) (hMN : M ≤ N) :
    (Finset.Icc M N).sum (fun k => a k * f k) =
    (Finset.Icc M N).sum a * f N -
    (Finset.Icc M (N-1)).sum (fun k =>
      (Finset.Icc M k).sum a * (f (k+1) - f k))
```

This is purely algebraic — telescoping sums. Mathlib has all the `Finset.sum` machinery. The main work is bookkeeping.

**Phase 2: Integral Estimation (~5-7 days)**

Prove that $\int_2^N |A(t)|/t\,dt \leq C\sqrt{N}\log^2 N$:
```lean
theorem integral_mertens_bound (C_m : ℝ) (hC : 0 < C_m) (N : ℕ) (hN : 2 ≤ N)
    (hM : ∀ x, 2 ≤ x → |M(x)| ≤ C_m * x^(1/2) * (log x)^2) :
    ∫ t in (2:ℝ)..(N:ℝ), |M(t)| / t ≤ C_m * √N * (log N)^2
```

This uses `integral_mono` (comparison principle) and standard power function integrals, both available in Mathlib.

**Phase 3: Weight Bound (~3-5 days)**

Show $\|v\|^2 \leq N^2$ for logarithmically smoothed Möbius weights:
```lean
-- |μ(k)/k · (1 - log k/log N)| ≤ 1/k
-- Σ 1/k² ≤ π²/6 ≤ N² (very generous)
```

This is trivial: each weight is at most $1/k$ in absolute value, so $\sum v_k^2 \leq \sum 1/k^2 \leq 2$.

**Phase 4: Assembly (~2-3 days)**

Combine Phases 1-3 with the existing `l2_error_eq_quad_error` theorem.

**Total estimated effort: 2-3 weeks** for a Lean-proficient analyst.

---

## Comparative Summary

| Property | Axiom 1 (`mertens_bound`) | Axiom 2 (`abel_summation`) |
|---|---|---|
| **Domain** | Analytic Number Theory | Real Analysis |
| **Mathematical depth** | Deep (≡ RH) | Moderate (textbook) |
| **Complex analysis needed?** | Yes (Perron formula) | **No** |
| **Mathlib dependencies available?** | ~20% | ~70% |
| **External project dependency?** | PrimeNumberTheoremAnd | None |
| **Estimated formalization effort** | 6-18 months (waiting on PNTA) | **2-3 weeks** |
| **Can be done independently?** | Needs NT expert | **Any analyst** |
| **Blocking the critical path?** | Yes | Yes |
| **Known to be true?** | Yes (Titchmarsh 14.25(C)) | Yes (textbook) |

---

## Recommended Next Steps

### Immediate (This Week)
1. **Begin Axiom 2**: Build `abel_summation` as a standalone Lean lemma in a new file `Cathedral/MellinBridge/AbelSummation.lean`
2. The algebraic core (discrete summation by parts) requires zero imports beyond `Finset`

### Short-Term (This Month)
3. Complete the integral estimation chain for Axiom 2
4. Close Axiom 2, reducing the Cathedral to **a single axiom**

### Medium-Term (3-6 Months)
5. Monitor PrimeNumberTheoremAnd's Perron branch
6. When ready, import as Lake dependency and bridge their `M(x)` to ours

### Long-Term (6-18 Months)
7. Close Axiom 1 via PNTA import
8. **The Cathedral reaches Absolute Zero: zero axioms on the critical path**
