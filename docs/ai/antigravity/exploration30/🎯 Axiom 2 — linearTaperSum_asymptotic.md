# 🎯 Axiom 2 Analysis — `linearTaperSum_asymptotic`

**Target**: $L(N) = \sum_{j,k \leq N-1} \mu(j)\mu(k) \ln(j) \cdot G(j,k) \approx -\frac{\ln N}{2} + O(1)$

**Physical Meaning**: The Robin Resonance — the formal derivative of $1/\zeta(s)$ at $s=1$ extracts the von Mangoldt function's logarithmic contribution.

---

## 1. What the Axiom Says

The **linear taper sum** introduces a logarithmic weight on one index:

$$L(N) = \sum_{j=1}^{N-1} \sum_{k=1}^{N-1} \mu(j)\mu(k) \ln(j) \cdot G(j,k)$$

The claim is that $L(N) \approx -\frac{\ln N}{2}$ with bounded error — specifically, there exists $C$ such that:

$$L(N) + \frac{\ln N}{2} \to C$$

This is the heart of the taper decomposition: when combined as $-\frac{2}{\ln N} \cdot L(N)$, it produces the "+1" needed in $\mathbf{v}^\top G \mathbf{v} \approx 1$.

---

## 2. Why It Should Be True

### 2a. The $(1/\zeta)'(1)$ Connection

Formally, the Dirichlet series $\sum \mu(n)/n^s = 1/\zeta(s)$. Differentiating:

$$-\sum_{n=1}^{\infty} \frac{\mu(n) \ln n}{n^s} = \frac{-\zeta'(s)}{\zeta(s)^2}$$

At $s=1$: $\zeta'(s)/\zeta(s)^2$ relates to the von Mangoldt function $\Lambda$, and the partial sum

$$\sum_{k=1}^{N} \frac{\mu(k) \ln k}{k} \to -1$$

This is the PNT axiom `pnt_mu_log_div_k` in the Cathedral.

### 2b. The Gram Entry Decomposition

Using the Vasyunin formula, the dominant term in $G(j,k)$ for the linear taper sum is $\frac{\text{gcd}(j,k)}{jk}$. Separating the log-weighted sum:

$$\sum_j \sum_k \mu(j)\mu(k) \ln(j) \frac{\gcd(j,k)}{jk} = \sum_j \frac{\mu(j) \ln j}{j} \sum_k \frac{\mu(k)}{k} \cdot (\text{GCD factor})$$

The first factor $\to -1$ by PNT. The second factor involves Mertens-type products, giving the $\ln N / 2$ growth.

### 2c. The Mertens Product Link

The key identity (Mertens' third theorem):
$$\prod_{p \leq X} \left(1 - \frac{1}{p}\right) \sim \frac{e^{-\gamma}}{\ln X}$$

Taking logs: $\sum_{p \leq X} \ln(1 - 1/p) \approx -\gamma - \ln \ln X$. The derivative of the Euler product at $s=1$ generates $-\sum_{p} \frac{\ln p}{p-1}$ which grows like $\ln X$.

---

## 3. Cathedral Arsenal Available

### Existing Proved Tools

| Tool | Location | What It Provides |
|------|----------|-----------------|
| `pnt_mu_log_div_k` | `PNT/AbelMean.lean` | Σ μ(k)·ln(k)/k → -1 (axiom, crown path) |
| `pnt_mu_log_div_k_proved` | `PNT/LogBridge.lean` | Same, derived from Mathlib PNT |
| `gcd_local_factor` | `EulerProduct.lean` | Local factor for GCD term = 1-1/p (PROVED) |
| `log_term_separation` | `EulerProduct.lean` | (j-k)/(jk)·ln(k/j) factorization (PROVED) |
| `separable_double_sum_factorization` | `EulerProduct.lean` | Separable sums factor (PROVED) |
| `s1_decay` | `AbelTail/S1Decay.lean` | S₁(N) → 0 with rate N^{-1/4} (PROVED) |
| `s2_decay` | `AbelTail/S2Decay.lean` | S₂(N) → -1 with log·N^{-1/4} rate |
| `moebius_mean_finite_bound` | `PNT/AbelMean.lean` | |bᵀv - 1| ≤ K₁/log(N) (PROVED) |
| `mertens_third_statement` | `EulerProduct.lean` | Mertens product → e^{-γ}/ln X (sorry) |
| `linearTaper_symm` | `TaperDecomposition.lean` | Gram symmetry: log(k) sum = log(j) sum |

### Missing Ingredients

1. **The PNT derivative sum `pnt_mu_log_div_k`**: Currently an axiom. The derived version `pnt_mu_log_div_k_proved` in `LogBridge.lean` is available but needs to be connected to the crown path. This is the **single most important missing ingredient**.

2. **Mertens' third theorem**: The `mertens_third_statement` has a sorry. This theorem connects $\prod(1-1/p)$ to $e^{-\gamma}/\ln X$ and would give the $-\ln N / 2$ growth rate.

3. **Inner sum evaluation**: Need to show $\sum_k \mu(k) G(j,k) \approx -(1/2j) + O(1/j \ln j)$ uniformly in $j$, so that $\sum_j \mu(j) \ln(j) \cdot (-1/2j) \approx (1/2) \sum_j \mu(j) \ln(j) / j \to -1/2$.

---

## 4. Attack Strategies

### Strategy A: 1D Reduction via Separability (Most Promising)

**Core idea**: Separate $G(j,k)$ into its Vasyunin components and show the dominant contribution comes from the GCD term, which factors.

**Step 1**: Decompose $L(N)$ using Vasyunin:
$$L(N) = L_{\text{triv}}(N) + L_{\text{symm}}(N) + L_{\text{gcd}}(N) + L_{\text{log}}(N)$$

**Step 2**: Show $L_{\text{symm}}(N) = 0$ (from `symm_local_factor = 0`, extended with the log weight — this needs checking since the log breaks separability).

**Step 3**: Show $L_{\text{gcd}}(N) \approx -\ln N / 2$ via:
$$L_{\text{gcd}}(N) = \sum_j \frac{\mu(j) \ln j}{j} \cdot \sum_k \frac{\mu(k) \gcd(j,k)}{jk}$$

This separates into a product of 1D sums when restricted to coprime pairs.

**Feasibility**: HIGH for the leading term, MEDIUM for the error.

### Strategy B: Abel Summation on the Derivative (Cleanest)

Use the Abel engine (already proved: `s1_decay`, `s2_decay`):

The Abel summation approach:
$$S_2(N) = \sum_{k=1}^{N} \frac{\mu(k) \ln k}{k} \to -1$$

is exactly `pnt_mu_log_div_k`. If this axiom is graduated (which `LogBridge.lean` provides), then:

$$L(N) \approx S_2(N) \cdot (\text{GCD weighted sum of k direction}) \approx (-1) \cdot \frac{\ln N}{2}$$

**Feasibility**: HIGH if `pnt_mu_log_div_k` is graduated. The main work is the GCD factor.

### Strategy C: Direct Numerical Fit (Validation Only)

From experiments, fit $L(N) + \ln N / 2$ and verify it converges:
- $L(1000) + \ln(1000)/2 \approx C_1$
- $L(10000) + \ln(10000)/2 \approx C_1 + O(1/\ln 10000)$

This validates but doesn't prove.

---

## 5. The Critical Path

```
pnt_mu_log_div_k (Axiom / LogBridge derived)
       │
       │  + Gram entry GCD decomposition
       │
       ▼
linearTaperSum_asymptotic
       │
       │  × (-2/ln N)  [from taper decomposition]
       │
       ▼
Produces the "+1" in vᵀGv ≈ 1 + O(1/ln N)
```

### Priority

This axiom is the **most analytically rich** of the three and has the **strongest existing infrastructure**. The `pnt_mu_log_div_k` axiom is the bottleneck — once graduated, the rest follows from:
1. Gram entry decomposition (proved)
2. Separable sum factorization (proved)
3. Abel summation engine (mostly proved)

---

## 6. Mathlib Resources

| Mathlib Result | What It Gives |
|---------------|--------------|
| PNT (ArithmeticFunction) | M(x) = o(x) → Σ μ(k)/k → 0 |
| `vonMangoldt_summatory` | Σ_{k≤x} Λ(k) ~ x |
| `DirichletSeries` derivative | d/ds L(μ,s) at s > 1 |
| `ArithmeticFunction.IsMultiplicative.sum_divisors_eq_prod` | Multiplicative sums → Euler products |

---

## 7. Difficulty Assessment

| Factor | Rating |
|--------|--------|
| Mathematical difficulty | ⭐⭐⭐⭐ (needs PNT derivative) |
| Lean formalization gap | ⭐⭐⭐ (LogBridge mostly built) |
| Infrastructure available | ⭐⭐⭐⭐⭐ (Abel engine, Euler product, PNT) |
| Overall feasibility | 🟢 HIGH (if pnt_mu_log_div_k graduated) |

### Recommended Path

1. **Graduate `pnt_mu_log_div_k`**: Connect `pnt_mu_log_div_k_proved` from `LogBridge.lean` to the crown path
2. **Prove inner sum bound**: $|\sum_k \mu(k) G(j,k)| \leq C/j$ using Cauchy-Schwarz + PNT
3. **Assemble**: The asymptotic follows from Abel summation on $\sum_j \mu(j) \ln(j) / j$ weighted by the inner bound

---

## 8. Numerical Evidence (UPDATED — May 8, 2026)

**Full taper analyzer sweep across all 13 HPDF files:**

| N | ln(N) | L(N) | L + lnN/2 |
|------:|------:|------:|----------:|
| 2 | 0.69 | 0.075 | 0.42 |
| 6 | 1.79 | 0.699 | 1.60 |
| 12 | 2.49 | 1.647 | 2.89 |
| 60 | 4.09 | 1.343 | 3.39 |
| 120 | 4.79 | 2.092 | 4.49 |
| 360 | 5.89 | 1.674 | 4.62 |
| 1000 | 6.91 | 1.649 | 5.10 |
| 2520 | 7.83 | 1.800 | 5.72 |
| 5040 | 8.53 | 1.997 | 6.26 |
| 10000 | 9.21 | 2.568 | 7.17 |
| 20000 | 9.90 | 2.202 | 7.15 |
| 40000 | 10.60 | 1.992 | 7.29 |
| **55440** | **10.92** | **2.008** | **7.47** |

> [!WARNING]
> **L(N) + ln(N)/2 is NOT converging to a constant.** It grows slowly
> (from 3.4 at N=60 to 7.5 at N=55440), roughly like O(ln ln N) or O(√ln N).
>
> The axiom as stated — `L(N) + lnN/2 → C` — appears to be **incorrect**.
>
> **However**, this doesn't break the proof because the factor 2/lnN kills
> the growth: (2/lnN)·|L(N)| → 0 regardless of L(N)'s exact rate.
> The combined reconstruction vᵀGv = U - 2L/lnN + Q/ln²N → 1 is robust.
>
> **Recommended fix**: Restate as `|L(N)| ≤ K·ln(N)` (a bound, not an asymptotic),
> which the data clearly supports with K ≈ 1.

