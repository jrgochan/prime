# 🎯 Axiom 1 Analysis — `untaperedSum_vanishes`

**Target**: $U(N) = \sum_{j=1}^{N-1} \sum_{k=1}^{N-1} \mu(j)\mu(k) G(j,k) \to 0$ as $N \to \infty$

**Physical Meaning**: The ground state Möbius-Gram interaction annihilates itself.

> [!WARNING]
> **Experimental evidence (May 8, 2026)**: The taper analyzer shows U(N) oscillates
> around **1.0**, NOT converging to 0. This axiom as stated appears to be **incorrect**.
> See §7 below for full data. The combined reconstruction vᵀGv → 1 is the correct target.

---

## 1. What the Axiom Says

The **untapered sum** is the raw double Möbius sum against the Vasyunin Gram matrix:

$$U(N) = \sum_{j,k \leq N-1} \mu(j)\mu(k) G(j,k)$$

where $G(j,k) = \int_0^1 \{1/jx\}\{1/kx\}\,dx$ is the Vasyunin Gram entry. The claim is that this sum tends to zero as $N \to \infty$.

---

## 2. Why It Should Be True

### 2a. The Euler Product Argument

From `EulerProduct.lean` (PROVED), for squarefree $N$:

$$\sum_{j|N} \sum_{k|N} \mu(j)\mu(k) f(j,k) = \prod_{p|N} E_p(f)$$

The Vasyunin formula decomposes $G(j,k)$ into three components:
1. **Trivial**: $1/(jk)$ → local factor $(1-1/p)^2$ (PROVED: `trivial_local_factor`)
2. **Symmetric**: $(1/j + 1/k)$ → local factor $0$ (PROVED: `symm_local_factor`)
3. **GCD**: $\gcd(j,k)/(jk)$ → local factor $(1-1/p)$ (PROVED: `gcd_local_factor`)

The symmetric term **completely vanishes** — this is one of the Cathedral's original discoveries. What remains is a product of GCD-dependent local factors.

### 2b. The PNT Connection

At a deeper level, $U(N) \to 0$ because $\sum \mu(k)/k \to 0$ (PNT):

$$U(N) = \left(\sum_{j} \frac{\mu(j)}{j}\right)^2 \cdot (\text{GCD correction})$$

The leading term is $\sim (M(N)/N)^2$ where $M(x) = \sum_{k \leq x} \mu(k)$. PNT gives $M(x) = o(x)$, so the product of the first-order terms vanishes.

---

## 3. Cathedral Arsenal Available

### Existing Proved Tools

| Tool | Location | What It Provides |
|------|----------|-----------------|
| `symm_local_factor = 0` | `EulerProduct.lean` | Symmetric component annihilated |
| `gcd_local_factor = 1-1/p` | `EulerProduct.lean` | GCD term evaluates to Euler factor |
| `trivial_local_factor = (1-1/p)²` | `EulerProduct.lean` | Trivial term is controlled |
| `divisor_sum_euler_product` | `EulerProduct.lean` | Full Euler product identity (PROVED) |
| `separable_double_sum_factorization` | `EulerProduct.lean` | Separable sums factor |
| `pnt_mu_div_k` | `PNT/AbelMean.lean` | Σ μ(k)/k → 0 (axiom, on crown path) |
| `pnt_mu_div_k_derived` | `PNT/Bridge.lean` | Derived from Mathlib PNT |
| `moebius_sum_tendsto_zero` | `EulerProduct.lean` | PNT → ε-bound on Möbius sums |
| `moebius_mean_finite_bound` | `PNT/AbelMean.lean` | |bᵀv - 1| ≤ K₁/log(N) (PROVED) |
| `abs_moebius_sum_le` | `EulerProduct.lean` | Σ |μ(n)|/n ≤ N (crude) |

### Missing Ingredients

1. **Gram matrix → Euler product bridge for the FULL Icc sum**: The `divisor_sum_euler_product` works over `divisors(N)` (divisors of N), but the untapered sum runs over `Icc 1 (N-1)` (all integers 1 to N-1). These are fundamentally different index sets. Need: truncation error bound or a density argument.

2. **Log term evaluation**: The Vasyunin Gram entry has a log term $(j-k)/(jk) \cdot \ln(k/j)$. Its local factor doesn't factor cleanly into a multiplicative form. The `log_term_separation` theorem (PROVED) helps, but the double sum of the log term is NOT bilinear multiplicative.

3. **Quantitative M(x)/x decay**: PNT gives $M(x) = o(x)$, but we need the rate to control the double sum. The existing `moebius_mean_finite_bound` provides $|M(x)/x| \leq K/\ln x$ which may suffice.

---

## 4. Attack Strategies

### Strategy A: Separable Bound (Easiest)

**Key insight**: The double sum $\sum \mu(j)\mu(k) G(j,k)$ can be bounded by separating into 1D sums.

From `log_term_separation`, each Gram entry decomposes as:
$$G(j,k) = \frac{1}{2jk} + (\text{GCD terms}) + (\text{log terms})$$

The trivial term gives $(\sum \mu(j)/j)^2$ which tends to 0 by PNT. The symmetric term vanishes. The remaining terms can be bounded using Cauchy-Schwarz on the double sum.

**Feasibility**: HIGH. Uses existing infrastructure. Main gap: bounding the log term contribution.

### Strategy B: Euler Product with Truncation (Medium)

For the squarefree part: use `divisor_sum_euler_product` to evaluate the sum over divisors, then bound the truncation error from the non-divisor terms.

**Steps**:
1. Decompose $\text{Icc}(1, N-1)$ sums into sums over $\text{divisors}(\text{lcm}(1..N-1))$ + tail
2. Apply the Euler product identity
3. Bound the tail using $|\mu(j)| \leq 1$ and $G(j,k) \leq 1/(jk)$

**Feasibility**: MEDIUM. Requires new infrastructure for Icc→divisors conversion.

### Strategy C: Direct from PNT (Hardest but Cleanest)

Show directly that:
$$\left|\sum_{j,k \leq N} \mu(j)\mu(k) G(j,k)\right| \leq C \cdot \left(\sum_{k \leq N} \frac{|\mu(k)|}{k}\right) \cdot \left|\sum_{j \leq N} \frac{\mu(j)}{j}\right| \to 0$$

This requires bounding the inner sum $\sum_k \mu(k) G(j,k)$ uniformly in $j$, which reduces to a 1D Möbius sum with PNT control.

**Feasibility**: MEDIUM-HIGH. The inner sum bound is the key lemma needed.

---

## 5. Mathlib Resources

| Mathlib Result | What It Gives |
|---------------|--------------|
| `ArithmeticFunction.isMultiplicative_moebius` | μ is multiplicative |
| `ArithmeticFunction.moebius_apply_prime` | μ(p) = -1 for prime p |
| `ArithmeticFunction.moebius_apply_one` | μ(1) = 1 |
| `Nat.ArithmeticFunction.sum_moebius_div` | Möbius inversion |
| `riemannZeta_ne_zero_of_one_lt_re` | ζ(s) ≠ 0 for Re(s) > 1 |
| PNT in Mathlib (recent) | M(x) = o(x) |

---

## 6. Difficulty Assessment

| Factor | Rating |
|--------|--------|
| Mathematical difficulty | ⭐⭐⭐ (PNT needed, but qualitative) |
| Lean formalization gap | ⭐⭐⭐ (Icc vs divisors bridge) |
| Infrastructure available | ⭐⭐⭐⭐ (Strong Euler product foundation) |
| Overall feasibility | 🟡 MEDIUM |

### Recommended Path

**Strategy A (Separable Bound)** is the most tractable:
1. Bound $G(j,k) \leq C/(jk)$ — **FALSE for diagonal** ($G(k,k) \sim 1.26/k$)
2. Use GCD-stratified bound instead: $G(j,k) \leq 1/4 + \gcd^2/(12jk) + 1/(4\max)$
3. The 1/4 constant gets killed by Möbius cancellation

---

## 7. Numerical Evidence (UPDATED — May 8, 2026)

**Full taper analyzer sweep across all 13 HPDF files:**

| N | U(N) | Interpretation |
|------:|-------:|:---|
| 2 | 0.097 | Small (few terms) |
| 6 | 0.523 | Growing |
| 12 | 1.038 | Near 1 |
| 60 | 0.907 | Oscillating |
| 120 | 1.142 | |
| 360 | 1.008 | |
| 1000 | 0.990 | ≈ 1.0 |
| 2520 | 1.022 | |
| 5040 | 1.057 | |
| 10000 | 1.126 | |
| 20000 | 1.054 | |
| 40000 | 1.043 | |
| **55440** | **1.038** | **Still ≈ 1.0** |

> [!CAUTION]
> **U(N) does NOT converge to 0.** It oscillates around 1.0 across four
> orders of magnitude of N. The axiom as stated is likely **wrong**.
>
> **However**, this does not break the proof chain because:
> - The taper decomposition reconstruction U - 2L/lnN + Q/ln²N → 1 robustly
> - The quantity (1-Recon)·ln(N) ≈ 2.87 (constant!) shows convergence at rate O(1/lnN)
> - What matters for Axiom A is the **combined** quadratic form, not U alone
>
> **Recommended fix**: Restate as U(N) → C₀ ≈ 1.0 (the Möbius autocorrelation),
> or bypass this axiom entirely and prove vᵀGv ≤ 1 + K/lnN directly.
