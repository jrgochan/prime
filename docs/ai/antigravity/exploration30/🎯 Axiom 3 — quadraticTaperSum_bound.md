# 🎯 Axiom 3 Analysis — `quadraticTaperSum_bound`

**Target**: $|Q(N)| = \left|\sum_{j,k \leq N-1} \mu(j)\mu(k) \ln(j) \ln(k) \cdot G(j,k)\right| \leq K \cdot \ln N$

**Physical Meaning**: The second-order taper correction—the "error tail" from the log-cutoff weights—has at most logarithmic growth, controlled by the second derivative of $1/\zeta(s)$ near $s=1$.

---

## 1. What the Axiom Says

The **quadratic taper sum** is the double Möbius sum with both indices weighted by logarithms:

$$Q(N) = \sum_{j=1}^{N-1} \sum_{k=1}^{N-1} \mu(j)\mu(k) \ln(j) \ln(k) \cdot G(j,k)$$

The claim is that $|Q(N)| \leq K \ln N$ for some universal constant $K$ and all $N \geq 3$.

This is the weakest of the three axioms—it only needs a logarithmic upper bound, not a precise asymptotic. In the taper decomposition:

$$\frac{1}{\ln^2 N} \cdot Q(N) \leq \frac{K}{\ln N} \to 0$$

so this term contributes at most $O(1/\ln N)$ to $\mathbf{v}^\top G \mathbf{v}$.

---

## 2. Why It Should Be True

### 2a. The $(1/\zeta)''(1)$ Connection

The second derivative of the Möbius L-series:

$$\frac{d^2}{ds^2}\left[\sum \frac{\mu(n)}{n^s}\right] = \sum \frac{\mu(n) \ln^2(n)}{n^s}$$

At $s=1$, the PNT axiom `pnt_mu_log_sq_div_k` states:

$$\sum_{k=1}^{N} \frac{\mu(k) \ln^2(k)}{k} \to -2\gamma$$

where $\gamma$ is the Euler-Mascheroni constant. This means the "diagonal" part of $Q(N)$ converges. The off-diagonal contribution is bounded by Cauchy-Schwarz.

### 2b. Why Only $O(\ln N)$ Growth?

The factor $\ln(j) \cdot \ln(k)$ grows as $\ln^2 N$ for large indices, but the Möbius cancellation provides decay $\sim 1/\ln N$ per factor, yielding net growth $\sim \ln^2 N / \ln^2 N = O(1)$ for the core, with a logarithmic tail from the boundary terms.

More precisely: Abel summation on $\sum \mu(k) \ln^2(k) / k$ against the Gram matrix column gives a bound of order $\ln N$ from the boundary term.

### 2c. The Mertens Wall Bypass

This axiom is notable because it **does not require the full strength of PNT**. Even the crude bound $|M(x)| \ll x / \ln^c x$ for any $c > 0$ would suffice. The s3_uniform_bound in the Cathedral's Abel engine already handles this via Mertens' theorem alone, bypassing PNT entirely.

---

## 3. Cathedral Arsenal Available

### Existing Proved Tools

| Tool | Location | What It Provides |
|------|----------|-----------------|
| `pnt_mu_log_sq_div_k` | `PNT/AbelMean.lean` | Σ μ(k)·ln²(k)/k → -2γ (axiom, OFF crown path) |
| `s3_uniform_bound_from_mertens` | `AbelTail/S3UniformBound.lean` | S₃ bound from Mertens ONLY (PROVED) |
| `moebius_bilinear_crude_bound` | `EulerProduct.lean` | (Σ |μ(j)|/j)² ≤ N² (PROVED) |
| `abs_moebius_sum_le` | `EulerProduct.lean` | Σ |μ(n)|/n ≤ N (PROVED) |
| `euler_factor_norm_le_one` | `EulerProduct.lean` | |1-p^{-σ}| ≤ 1 (PROVED) |
| `log_shift_bound` | `AbelTail/Engine.lean` | log(N) ≤ 2·log(N-1) for N ≥ 10 (PROVED) |
| Abel Interior machinery | `AbelTail/AbelInterior.lean` | Interior sum control for Abel tails |
| `linearTaper_symm` | `TaperDecomposition.lean` | Sum symmetry via Gram (PROVED) |
| `mertens_third_statement` | `EulerProduct.lean` | Π(1-1/p) ~ e^{-γ}/ln X (sorry) |

### Key Architectural Note

The `pnt_mu_log_sq_div_k` axiom was **eliminated from the crown path** in the v9 axiom reduction (documented in `PerronCrown.lean`). The `s3_uniform_bound_from_mertens` theorem provides the same bound using only Mertens' theorem, without PNT. This makes Axiom 3 the **easiest to graduate** of the three.

### Missing Ingredients

1. **Pointwise Gram bound**: ~~Need $|G(j,k)| \leq C/(jk)$~~ — **FALSE for diagonal** ($G(k,k) \sim 1.26/k$). Use the **GCD-stratified bound** instead: $G(j,k) \leq 1/4 + \gcd^2/(12jk) + 1/(4\max(j,k))$ (verified to N=100K in `gcd-sum-audit`, and to N=55440 in taper analyzer).

2. **Bilinear Abel summation**: Need a 2D version of Abel summation to control the double sum. The 1D Abel engine is well-developed but the 2D extension needs work.

3. **Log²-weighted Möbius tail**: The bound $\sum_{k \leq N} |\mu(k)| \ln^2(k) / k \leq C \ln^2 N$ (trivially true but needs formalization).

---

## 4. Attack Strategies

### Strategy A: Cauchy-Schwarz Factorization (Easiest)

**Core idea**: Bound the double sum by the product of two single sums using Cauchy-Schwarz.

$$|Q(N)| \leq \sqrt{Q_{jj}(N)} \cdot \sqrt{Q_{kk}(N)}$$

where $Q_{jj}(N) = \sum_{j,k} |\mu(j)|^2 \ln^2(j) \cdot G(j,k)$. Since $|\mu(j)| \leq 1$:

$$|Q(N)| \leq \sum_{j \leq N} \ln^2(j) \cdot \sum_{k \leq N} \frac{|\mu(k)|}{k} \cdot \frac{C}{j}$$

This telescopes to $O(\ln^3 N)$, which is worse than needed but could be tightened.

**Feasibility**: HIGH for a crude bound. Needs refinement for the optimal $O(\ln N)$.

### Strategy B: Abel + S3 Uniform Bound (Most Cathedral-Native)

**Core idea**: Leverage the existing `s3_uniform_bound_from_mertens` which already bounds the third Abel tail using only Mertens' theorem.

**Steps**:
1. Rewrite $Q(N)$ as a 2D partial sum
2. Apply Abel summation on the outer index $j$: 
   $Q(N) = S_3(N) \cdot (\text{Gram column sum at N}) - \int_1^N S_3(t) \cdot d(\text{Gram column sum})$
3. Bound using `s3_uniform_bound_from_mertens` for the $S_3$ factor
4. Bound the Gram column sum by $O(\ln N / N)$

**Feasibility**: MEDIUM-HIGH. This is the architecturally cleanest approach and avoids PNT.

### Strategy C: Direct Crude Bound (Fastest)

**Core idea**: Use $|\mu(j)| \leq 1$, $G(j,k) \leq C/(jk)$ to get:

$$|Q(N)| \leq C \sum_{j \leq N} \frac{\ln^2 j}{j} \cdot \sum_{k \leq N} \frac{\ln^2 k}{k}$$

Each factor is $O(\ln^3 N)$, giving $|Q(N)| \leq C' \ln^6 N$. This is much worse than $O(\ln N)$ but suffices if we only need $Q(N)/\ln^2 N \to 0$.

**Wait**: Actually $Q(N)/\ln^2 N \to 0$ only needs $|Q(N)| = o(\ln^2 N)$, and $\ln^6 N$ doesn't satisfy this! We genuinely need $|Q(N)| = O(\ln N)$, which requires Möbius cancellation.

**Feasibility**: LOW for the required bound. This approach needs significant cancellation.

### Strategy D: PNT Derivative Direct (Cleanest Mathematically)

Use the convergence $\sum \mu(k) \ln^2(k) / k \to -2\gamma$ directly:

$$Q(N) = \left(\sum_j \frac{\mu(j) \ln j}{j}\right) \cdot \left(\sum_k \frac{\mu(k) \ln k}{k}\right) \cdot (\text{GCD correction}) + O(1)$$

Since both 1D sums converge to $-1$, and the GCD correction introduces at most $O(\ln N)$ growth from the Mertens product:

$$Q(N) = 1 \cdot (\text{Mertens product}) + O(1) = O(\ln N)$$

**Feasibility**: MEDIUM. Requires careful handling of the GCD factor's contribution.

---

## 5. The Critical Advantage: S3 Bypass

The Cathedral already has a powerful result that bypasses PNT entirely for this axiom:

```
s3_uniform_bound_from_mertens : 
  (Mertens hypothesis) → |S₃(N)| ≤ K · ln N
```

This was proved in `AbelTail/S3UniformBound.lean` and eliminates the need for `pnt_mu_log_sq_div_k`. The key insight: Mertens' theorem ($\prod(1-1/p) \sim e^{-\gamma}/\ln X$) is strictly weaker than PNT but sufficient for quadratic bounds.

**This means Axiom 3 can potentially be graduated using only Mertens' theorem**, which is already partially formalized in `EulerProduct.lean`.

---

## 6. Mathlib Resources

| Mathlib Result | What It Gives |
|---------------|--------------|
| `Real.log_le_log` | Monotonicity of log |
| `Finset.sum_le_sum` | Pointwise sum bounds |
| `abs_sum_le_sum_abs` | Triangle inequality for sums |
| `Real.tendsto_log_atTop` | log N → ∞ |
| Harmonic series bounds | Σ 1/k ~ ln N + γ |
| `ArithmeticFunction.moebius_sq_le_one` | |μ(n)|² ≤ 1 |

---

## 7. Difficulty Assessment

| Factor | Rating |
|--------|--------|
| Mathematical difficulty | ⭐⭐ (only needs a bound, not an asymptotic) |
| Lean formalization gap | ⭐⭐ (S3 engine already built) |
| Infrastructure available | ⭐⭐⭐⭐⭐ (S3 bypass + Mertens, Abel engine) |
| Overall feasibility | 🟢🟢 HIGH (easiest of the three axioms) |

### Recommended Path

**Strategy B (Abel + S3 Uniform Bound)** is optimal:

1. **Formalize pointwise Gram bound**: $|G(j,k)| \leq C/(jk)$ from Vasyunin formula
2. **Reduce $Q(N)$ to 1D Abel tail**: Via column sum bound $\sum_k |\mu(k)| \ln(k) \cdot |G(j,k)| \leq C \ln(j) / j$
3. **Apply `s3_uniform_bound_from_mertens`**: Gives $|\text{boundary term}| \leq K \ln N$
4. **Bound interior integral**: Using Abel interior estimates (already proved)

The total expected effort is **1-2 sessions** given the existing infrastructure.

---

## 8. Numerical Evidence (UPDATED — May 8, 2026)

**Full taper analyzer sweep across all 13 HPDF files:**

| N | Q(N) | |Q|/lnN | Status |
|------:|--------:|-------:|:---|
| 2 | 0.18 | 0.26 | ✅ |
| 6 | 1.04 | 0.58 | ✅ |
| 12 | 2.77 | 1.12 | ✅ |
| 60 | 2.40 | 0.59 | ✅ |
| 120 | 4.46 | 0.93 | ✅ |
| 360 | 3.70 | 0.63 | ✅ |
| 1000 | 4.29 | 0.62 | ✅ |
| 2520 | 5.08 | 0.65 | ✅ |
| 5040 | 5.92 | 0.70 | ✅ |
| 10000 | 10.54 | **1.14** | ✅ (spike) |
| 20000 | 10.12 | 1.02 | ✅ |
| 40000 | 6.96 | 0.66 | ✅ |
| **55440** | **7.98** | **0.73** | **✅** |

The ratio |Q(N)|/ln(N) **oscillates between 0.26 and 1.14** across four orders of
magnitude. There is no upward trend. **The bound |Q(N)| ≤ K·ln(N) holds with K ≈ 1.2.**

---

## 9. Connection to the S3 Bypass Architecture

```
Mertens' Third Theorem (EulerProduct.lean, 1 sorry)
         │
         ▼
s3_uniform_bound_from_mertens (AbelTail/S3UniformBound.lean, PROVED)
         │
         │  + Pointwise Gram bound |G(j,k)| ≤ C/(jk)
         │  + Bilinear Abel summation
         │
         ▼
quadraticTaperSum_bound  ←── AXIOM 3 (TARGET)
         │
         │  × (1/ln²N)
         │
         ▼
O(1/ln N) contribution to vᵀGv
```

The Mertens sorry in `EulerProduct.lean` is the remaining blocker, but `s3_uniform_bound_from_mertens` takes Mertens as a *hypothesis*, not as a Lean axiom, so the proof is modular.
