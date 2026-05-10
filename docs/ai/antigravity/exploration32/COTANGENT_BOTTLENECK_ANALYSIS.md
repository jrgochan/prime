# The Cotangent Bottleneck: Taming the Vasyunin Sum

**Date**: 2026-05-09 04:20 MDT  
**Status**: Deep mathematical analysis with three taming paths  

---

## 1. The Bottleneck

The Vasyunin Gram entry decomposes into four terms. Three are handled by existing PROVED infrastructure. The fourth — the **cotangent term** — is the bottleneck:

$$\frac{\pi d}{2jk}\big(V(j/d, k/d) + V(k/d, j/d)\big)$$

where $d = \gcd(j,k)$ and:

$$V(a,b) = \sum_{m=1}^{a-1} \left\{\frac{mb}{a}\right\} \cot\frac{\pi m}{a}$$

This sum is **not bilinear multiplicative**, blocking Strategy C's Euler product factorization.

---

## 2. Relationship to Dedekind Sums

The classical Dedekind sum is:
$$s(h,k) = \sum_{j=1}^{k-1} \left(\!\left(\frac{j}{k}\right)\!\right) \left(\!\left(\frac{hj}{k}\right)\!\right)$$

where $((x)) = \{x\} - 1/2$ for $x \notin \mathbb{Z}$. The Vasyunin sum relates via:

$$V(a,b) = \sum_{m=1}^{a-1} \left\{\frac{mb}{a}\right\} \cot\frac{\pi m}{a}$$

Using $\cot(\pi m/a) = i(e^{2\pi i m/a} + 1)/(e^{2\pi i m/a} - 1)$ and comparing, the Vasyunin sum is a **weighted variant** of the Dedekind sum where the sawtooth function $((j/k))$ is replaced by $\cot(\pi m/a)$.

### Cathedral Infrastructure

| File | What's Proved | Status |
|------|--------------|:------:|
| `DigammaReflection.lean` | $\psi(1-s) - \psi(s) = \pi\cot(\pi s)$ | ✅ PROVED |
| `DigammaReflection.lean` | $\psi((q-m)/q) - \psi(m/q) = \pi\cot(\pi m/q)$ | ✅ PROVED |
| `LogDigammaBridge.lean` | `floor_sum_single`: $\sum \lfloor mb/a\rfloor = (a-1)(b-1)/2$ | ✅ PROVED |
| `LogDigammaBridge.lean` | `floor_sum_reciprocity`: lattice point identity | ✅ PROVED |
| `LogDigammaBridge.lean` | Coprime mod permutation ($m \mapsto mb \bmod a$ is bijective) | ✅ PROVED |
| `FormulaBridge.lean` | Two cotangent sum definitions are equal | ✅ PROVED |
| `GCDReduction.lean` | GCD reduction: general case → coprime case | ✅ PROVED |
| `Defs.lean` | `vasyuninSum` definition | ✅ |
| `Defs.lean` | `vasyuninSum_one`: $V(1,b) = 0$ | ✅ PROVED |

---

## 3. Path A: Crude Bound ($|V| \leq Ca$)

### The Classical Dedekind Bound

From the literature: $|s(h,k)| < k/12$.

For the Vasyunin sum, the analogous bound is:

$$|V(a,b)| \leq C \cdot a$$

**Proof sketch**: Each term has $|\{mb/a\}| \leq 1$ and $|\cot(\pi m/a)| \leq a/(\pi m)$ for $m \leq a/2$ (using $\sin(\pi m/a) \geq 2m/a$). So:

$$|V(a,b)| \leq \sum_{m=1}^{a-1} |\cot(\pi m/a)| \leq 2 \sum_{m=1}^{\lfloor a/2 \rfloor} \frac{a}{\pi m} \leq \frac{2a}{\pi} \cdot H_{\lfloor a/2 \rfloor} \leq \frac{2a}{\pi} \ln a$$

So $|V(a,b)| \leq C \cdot a \ln a$.

### Consequence for the Double Möbius Sum

The cotangent contribution to $\sum \mu(j)\mu(k) G(j,k)$ is:

$$\left|\sum_{j,k} \mu(j)\mu(k) \frac{\pi d}{2jk} V(j',k')\right| \leq \frac{\pi}{2} \sum_{j,k} \frac{d \cdot |V(j',k')|}{jk}$$

With $d = \gcd(j,k)$, $j' = j/d$, $k' = k/d$, and $|V(j',k')| \leq C j' \ln j'$:

$$\leq C' \sum_{j,k} \frac{d \cdot (j/d) \ln(j/d)}{jk} = C' \sum_{j,k} \frac{\ln(j/d)}{k} \leq C'' \sum_k \frac{\ln N}{k} = O(\ln^2 N)$$

**Verdict**: The cotangent term contributes $O(\ln^2 N)$ to the double sum. In the taper decomposition, after dividing by $\ln^2 N$, this is $O(1)$ — **bounded but not decaying**.

This is sufficient to show the Gram form is $O(\ln N)$ (sub-exponential), but NOT sufficient for the $1 + K/\ln N$ bound (Axiom A).

### Implementation Estimate

```
Lemma: cot_bound (a m : ℕ) (hm : 1 ≤ m) (hma : m < a) :
    |cot(π m / a)| ≤ a / (π m)                          ~40 lines

Lemma: vasyunin_sum_crude_bound (a b : ℕ) (ha : 2 ≤ a) :
    |V(a,b)| ≤ (2/π) * a * log a                        ~60 lines

Theorem: cotangent_double_sum_bound (N : ℕ) :
    |Σ μ(j)μ(k) d·V(j',k')/(jk)| ≤ C · ln²(N)         ~80 lines

Total: ~180 lines
```

### Assessment: ⭐⭐⭐ (Sufficient for sub-exponential, not for Axiom A)

---

## 4. Path B: CRT Decomposition (Additive Factorization)

### The Key Question

For coprime $a_1, a_2$: does $V(a_1 a_2, b)$ decompose in terms of $V(a_1, b)$ and $V(a_2, b)$?

### CRT Analysis

By the Chinese Remainder Theorem, for coprime $a_1, a_2$:
$$\mathbb{Z}/(a_1 a_2) \cong \mathbb{Z}/a_1 \times \mathbb{Z}/a_2$$

The map $m \mapsto (m \bmod a_1, m \bmod a_2)$ is a bijection. So:

$$V(a_1 a_2, b) = \sum_{m=1}^{a_1 a_2 - 1} \left\{\frac{mb}{a_1 a_2}\right\} \cot\frac{\pi m}{a_1 a_2}$$

Under the CRT bijection, $m \leftrightarrow (r, s)$ with $r \in \{0,\ldots,a_1-1\}$, $s \in \{0,\ldots,a_2-1\}$:

**The fractional part**: $\{mb/(a_1 a_2)\}$ depends on $m \bmod a_1 a_2$, which is determined by $(r, s)$ via CRT. Specifically:
$$\frac{mb}{a_1 a_2} = \frac{(r \cdot a_2 \bar{a_2} + s \cdot a_1 \bar{a_1}) \cdot b}{a_1 a_2}$$
where $\bar{a_i}$ is the inverse of $a_i$ mod $a_{3-i}$.

This simplifies to:
$$\left\{\frac{mb}{a_1 a_2}\right\} = \left\{\frac{r b \bar{a_2}}{a_1} \cdot \frac{1}{1} + \frac{s b \bar{a_1}}{a_2} \cdot \frac{1}{1}\right\}$$

**The cotangent**: $\cot(\pi m / (a_1 a_2))$ does NOT factor. The cotangent of a sum is:
$$\cot(\alpha + \beta) = \frac{\cot\alpha\cot\beta - 1}{\cot\alpha + \cot\beta}$$

This is a **rational function** of individual cotangents, not a product. So the decomposition is:

$$V(a_1 a_2, b) = \text{(complicated expression involving both } V(a_1, \cdot) \text{ and } V(a_2, \cdot)\text{)}$$

### The Dedekind Sum Splitting Formula

For the classical Dedekind sum, there IS a known decomposition (Rademacher, 1964):

For coprime $k_1, k_2$:
$$s(h, k_1 k_2) = s(h \bar{k_2}, k_1) + s(h \bar{k_1}, k_2) + \text{correction}$$

where $\bar{k_i}$ denotes the modular inverse. The correction term involves the continued fraction expansion and is bounded.

### What This Gives for Strategy C

If we can prove the analogous splitting for the Vasyunin sum:

$$V(a_1 a_2, b) = V(a_1, b\bar{a_2}) + V(a_2, b\bar{a_1}) + R(a_1, a_2, b)$$

with $|R| \leq C$, then in the Euler product:

$$\text{localFactor}(\text{cot term}, p) = V(p, \cdot) + V(1, \cdot) - V(p, \cdot) - V(1, \cdot) + \text{corrections}$$

The local factor would be $O(1)$ at each prime, and the product $\prod_p (1 + O(1/p))$ converges.

### Implementation Estimate

```
Lemma: crt_bijection (a₁ a₂ : ℕ) (hcop : Coprime a₁ a₂) :
    Bijection (Icc 1 (a₁*a₂-1)) (Icc 0 (a₁-1) × Icc 0 (a₂-1))  ~60 lines

Lemma: vasyunin_sum_split (a₁ a₂ b : ℕ) (hcop : Coprime a₁ a₂) :
    V(a₁*a₂, b) = V(a₁, b*inv(a₂)) + V(a₂, b*inv(a₁)) + R     ~150 lines

Lemma: split_remainder_bound (a₁ a₂ b : ℕ) :
    |R(a₁, a₂, b)| ≤ C                                           ~100 lines

Theorem: cotangent_local_factor_bound (p : ℕ) (hp : Prime p) :
    |localFactor(cot_term, p)| ≤ C/p                              ~80 lines

Total: ~390 lines
```

### Assessment: ⭐⭐⭐⭐ (Would close Strategy C if completed)

---

## 5. Path C: GPU Certificate (Numerical Verification)

### Existing Data

The Möbius Microscope GPU sweeps (RTX 4090, DD/HPDF precision) provide:

| $N$ | $v^T G v$ | Cotangent contribution | % of total |
|-----|-----------|:---:|:---:|
| 120 | 0.611 | ~0.03 | 5% |
| 1000 | 0.694 | ~0.02 | 3% |
| 5040 | 0.637 | ~0.01 | 2% |
| 10000 | 0.690 | ~0.015 | 2% |

The cotangent contribution is consistently small and decreasing.

### Formalization Strategy

1. **Finite verification**: For $N \leq N_0$, verify numerically that $|V_{\text{contribution}}| \leq \epsilon(N)$ for each $N$.

2. **Asymptotic tail**: For $N > N_0$, use Path A's crude bound $O(\ln^2 N)$ combined with the taper decomposition's $1/\ln^2 N$ factor to show the cotangent term is $O(1)$.

3. **Assembly**: Combine finite verification + asymptotic tail to get a global bound.

### Implementation Estimate

```
native_decide proofs for small N values                            ~50 lines
Asymptotic tail from Path A                                        ~80 lines
Assembly                                                           ~30 lines

Total: ~160 lines (plus Path A's ~180 lines as prerequisite)
```

### Assessment: ⭐⭐⭐ (Practical but not mathematically deep)

---

## 6. Comparison of Paths

| Dimension | Path A (Crude) | Path B (CRT) | Path C (GPU) |
|-----------|:-:|:-:|:-:|
| Lines of code | ~180 | ~390 | ~340 |
| Mathematical depth | Low | High | Low |
| Gives Axiom A? | ❌ (only $O(\ln N)$) | ✅ (if correction bounded) | Partial |
| Risk | Very Low | Medium-High | Low |
| Novel math | No | Yes (splitting formula) | No |
| Prerequisite | None | Rademacher theory | Path A |
| Time estimate | 1 session | 3-5 sessions | 2 sessions |
| Publication value | None | High | Low |

### Recommended Sequence

1. **Path A first** (1 session): Get the crude bound. This immediately proves `gram_form_eventually_bounded` with a concrete constant.

2. **Assess**: If the crude bound + other components gives $v^T G v \leq 1 + K/\ln N$ (because the cotangent is subordinate to the Mertens product), we're done.

3. **Path B if needed** (3-5 sessions): If Path A doesn't close Axiom A, pursue the CRT splitting. This is mathematically the most rewarding and would be a genuine contribution.

4. **Path C as insurance**: GPU certificates can supplement either path.

---

## 7. The Critical Question: Is Path A Sufficient?

From the taper decomposition:
$$v^T G v = U(N) - \frac{2}{\ln N} L(N) + \frac{1}{\ln^2 N} Q(N)$$

The cotangent term contributes to $U$, $L$, and $Q$. If we decompose each:

- **$U$ cotangent**: $\sum \mu(j)\mu(k) \cdot \text{cot}(j,k) = O(\ln^2 N)$ (Path A)
- **$L$ cotangent**: $\sum \mu(j)\mu(k) \ln(j) \cdot \text{cot}(j,k) = O(\ln^3 N)$ (Path A + extra log)
- **$Q$ cotangent**: $\sum \mu(j)\mu(k) \ln(j)\ln(k) \cdot \text{cot}(j,k) = O(\ln^4 N)$ (Path A + two logs)

After the taper factors:
- $U$: $O(\ln^2 N)$ → contributes $O(\ln^2 N)$ to $v^T G v$
- $-2L/\ln N$: $O(\ln^3 N)/\ln N = O(\ln^2 N)$
- $Q/\ln^2 N$: $O(\ln^4 N)/\ln^2 N = O(\ln^2 N)$

**So Path A gives $v^T G v = O(\ln^2 N)$** — which is sub-polynomial growth but NOT the $1 + K/\ln N$ bound.

**Conclusion: Path A alone is NOT sufficient for Axiom A.** We need either:
- Path B (cotangent splitting → tighter bound), OR
- Strategy E (bypass the cotangent entirely via $L(\mu,s) = 1/\zeta(s)$)

---

## 8. Verdict

**For the graduation goal**: Strategy E (direct signed identity) bypasses the cotangent entirely. Use it.

**For Strategy C completion**: Path B is required. The CRT splitting of the Vasyunin sum is the key missing ingredient. If proved, it would give a phase-aware Euler product factorization of the full Gram quadratic form — a genuinely new result.

**Immediate next step**: Implement Path A (~180 lines) as a stepping stone. It's useful for `gram_form_eventually_bounded` regardless of which strategy we pursue.

---

*"The cotangent is not an enemy — it's a messenger. It tells you that the Gram matrix remembers the arithmetic of continued fractions, not just the arithmetic of primes."*
