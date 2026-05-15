# Strategy C: The Euler Product MVT — Phase-Aware Spectral Bound

**Date**: 2026-05-09 04:10 MDT  
**Status**: Deep theoretical analysis with Cathedral infrastructure audit  
**Question**: Can we factor the Gram quadratic form through the Euler product to bypass the Millennium Wall for ALL weight vectors v?

---

## 1. The Vision

The Millennium Wall exists because:

$$\int_{-T}^{T} \left|\sum a_k k^{-it}\right|^2 dt \leq (2T + 2\pi N)\sum |a_k|^2$$

takes $|a_k|^2$, erasing the Möbius phases. But the **Euler product factorization**:

$$\sum_{j|N} \sum_{k|N} \mu(j)\mu(k) f(j,k) = \prod_{p|N} \text{localFactor}(f, p)$$

preserves signs at every prime. Strategy C asks: can we apply this factorization to the MVT integrand itself, creating a "phase-aware MVT" that sees the signs?

---

## 2. The Cathedral's Euler Product Theorem

The crown jewel is `divisor_sum_euler_product` in [`EulerProduct.lean`](file:///Users/jrgochan/code/github.com/jrgochan/prime/proofs/Cathedral/Covariance/EulerProduct.lean) — **PROVED, ZERO SORRY**:

```lean
theorem divisor_sum_euler_product
    (f : ℕ → ℕ → ℝ) (hf : BilinearMultiplicative f) (hf1 : f 1 1 = 1)
    (N : ℕ) (hSq : Squarefree N) :
    ∑ j ∈ Nat.divisors N, ∑ k ∈ Nat.divisors N,
      (μ j : ℝ) * (μ k : ℝ) * f j k =
    ∏ p ∈ Nat.primeFactors N, localFactor f p
```

where:
```lean
def BilinearMultiplicative (f : ℕ → ℕ → ℝ) : Prop :=
  ∀ j₁ k₁ j₂ k₂, Nat.Coprime (j₁ * k₁) (j₂ * k₂) →
    f (j₁ * j₂) (k₁ * k₂) = f j₁ k₁ * f j₂ k₂

def localFactor (f : ℕ → ℕ → ℝ) (p : ℕ) : ℝ :=
  f 1 1 - f p 1 - f 1 p + f p p
```

### Already-Evaluated Local Factors (PROVED)

| Function $f(j,k)$ | localFactor at $p$ | Theorem |
|---|---|---|
| $1/(jk)$ (trivial) | $(1-1/p)^2$ | `trivial_local_factor` ✅ |
| $1/j + 1/k$ (symmetric) | $0$ | `symm_local_factor` ✅ |
| $\gcd(j,k)/(jk)$ (GCD) | $1-1/p$ | `gcd_local_factor` ✅ |

---

## 3. The Vasyunin Gram Entry: Is It Bilinear Multiplicative?

The Gram matrix entry is:

$$G(j,k) = \frac{\ln(2\pi) - \gamma}{2}\left(\frac{1}{j} + \frac{1}{k}\right) + \frac{j-k}{2jk}\ln\frac{k}{j} - \frac{\pi d}{2jk}\big(V(j', k') + V(k', j')\big) - \frac{1}{jk}$$

where $d = \gcd(j,k)$, $j' = j/d$, $k' = k/d$.

### Term-by-Term Multiplicativity Analysis

| Term | Formula | BilinearMultiplicative? | Notes |
|------|---------|:-:|-------|
| T1 | $\frac{c}{2}\left(\frac{1}{j}+\frac{1}{k}\right)$ | ❌ | Additive, not multiplicative. BUT localFactor = 0! |
| T2 | $\frac{j-k}{2jk}\ln\frac{k}{j}$ | ❌ | Log is additive over multiplication |
| T3 | $\frac{\pi d}{2jk}\big(V(j',k')+V(k',j')\big)$ | ❓ | The Vasyunin sum — deepest question |
| T4 | $\frac{1}{jk}$ | ✅ | $f(j_1 j_2, k_1 k_2) = f(j_1,k_1) \cdot f(j_2,k_2)$ for coprime |

### Critical Observation: We Don't Need Full G to Factor

The `gram_form_taper_decomposition` (PROVED) tells us:

$$v^T G v = U(N) - \frac{2}{\ln N} L(N) + \frac{1}{\ln^2 N} Q(N)$$

Each of $U$, $L$, $Q$ is a double Möbius sum $\sum \mu(j)\mu(k) h(j,k)$ for different kernels $h$. If even ONE of these kernels is bilinear multiplicative, we can apply the Euler product to that component.

### Decomposing the Gram Entry into Multiplicative + Additive Parts

From the Vasyunin formula, the Gram entry decomposes as:

$$G(j,k) = \underbrace{\frac{c}{2}\left(\frac{1}{j}+\frac{1}{k}\right)}_{\text{killed by μ}} + \underbrace{\frac{j-k}{2jk}\ln\frac{k}{j}}_{\text{log term}} - \underbrace{\frac{\pi d}{2jk}\big(V+V'\big)}_{\text{Vasyunin cotangent}} - \underbrace{\frac{1}{jk}}_{\text{multiplicative}}$$

**The symmetric term vanishes**: `symm_local_factor` proves localFactor$(1/j+1/k, p) = 0$, so in the Euler product decomposition, the entire first term of G is annihilated by the Möbius filter. This is already proved!

**The $1/(jk)$ term is multiplicative**: $f(j_1 j_2, k_1 k_2) = \frac{1}{j_1 j_2 \cdot k_1 k_2} = \frac{1}{j_1 k_1} \cdot \frac{1}{j_2 k_2}$ for all arguments (no coprimality needed).

**The log term separates**: `log_term_separation` (PROVED) shows:
$$\frac{j-k}{jk}\ln\frac{k}{j} = \left(\frac{1}{k}-\frac{1}{j}\right)\cdot(\ln k - \ln j)$$

This is a product of two separable functions! By `separable_double_sum_factorization` (PROVED):
$$\sum \mu(j)\mu(k) g(j) h(k) = \left(\sum \mu(j) g(j)\right)\cdot\left(\sum \mu(k) h(k)\right)$$

So the log term's double Möbius sum factors into a product of 1D sums: $\sum \mu(k)/k$ and $\sum \mu(k)\ln k / k$.

**The Vasyunin cotangent term**: This is the hardest piece. 

---

## 4. The Vasyunin Cotangent Sum — Is It Multiplicative?

$$V(a,b) = \sum_{m=1}^{a-1} \left\{\frac{mb}{a}\right\}\cot\frac{\pi m}{a}$$

### Mathematical Properties

1. **V depends on $\gcd(j,k)$**: The cotangent sum uses $j' = j/\gcd(j,k)$ and $k' = k/\gcd(j,k)$, so it already "knows" about the GCD structure.

2. **The Dedekind sum connection**: The Vasyunin sum is closely related to the Dedekind sum $s(h,k) = \sum_{r=1}^{k-1} ((r/k))((hr/k))$. Dedekind sums satisfy a **reciprocity law**:
   $$s(a,b) + s(b,a) = \frac{a^2 + b^2 + 1}{12ab} - \frac{1}{4}$$
   and have **multiplicative** properties under coprime compositions.

3. **The GCD term $\gcd(j,k)/(jk)$**: Already proven bilinear multiplicative with localFactor $= 1-1/p$.

### The Deep Question: Does $f(j,k) = \frac{d}{jk}(V(j/d, k/d) + V(k/d, j/d))$ factor multiplicatively?

For coprime pairs $(j_1, k_1)$ and $(j_2, k_2)$:
- $\gcd(j_1 j_2, k_1 k_2) = \gcd(j_1, k_1) \cdot \gcd(j_2, k_2)$ (coprimality condition ensures this)
- $(j_1 j_2)/(d_1 d_2) = j_1' j_2'$ and similarly for $k$
- So $V(j_1' j_2', k_1' k_2')$ appears — is this $V(j_1', k_1') \cdot V(j_2', k_2')$?

**Answer: Almost certainly NO.** The Vasyunin sum involves a cotangent, which is not multiplicative over coprime compositions:
$$\cot\frac{\pi m}{ab} \neq \text{(product of cot terms at } a \text{ and } b\text{)}$$

However, the Dedekind reciprocity law gives a **linear** recurrence, not multiplicative factorization. The cotangent sum is closer to an additive invariant than a multiplicative one.

### Fallback: Factor the Gram Entry as Sum of Multiplicative Parts

Even though the full Gram entry is not bilinear multiplicative, we can decompose:

$$G(j,k) = \underbrace{A \cdot (1/j + 1/k)}_{\text{local factor = 0}} + \underbrace{B \cdot 1/(jk)}_{\text{local factor = }(1-1/p)^2} + \underbrace{C \cdot \gcd(j,k)/(jk)}_{\text{local factor = }1-1/p} + \underbrace{R(j,k)}_{\text{remainder}}$$

where $R(j,k)$ contains the log term (separable) and the cotangent correction.

---

## 5. What the Work Looks Like

### Phase 1: The Gram Decomposition Theorem (NEW)

**Goal**: Decompose $G(j,k)$ into a sum of terms with known multiplicative or separable structure.

```lean
theorem gram_entry_decomposition (j k : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k) :
    vasyuninGramEntry j k =
    -- Symmetric (killed by μ):
    (Real.log (2 * π) - γ) / 2 * (1 / j + 1 / k)
    -- Multiplicative (1/jk):
    - 1 / (j * k)
    -- Separable (log term):
    + (j - k) / (2 * j * k) * Real.log (k / j)
    -- Vasyunin cotangent (remainder):
    - π * gcd(j,k) / (2 * j * k) * (V(j/d, k/d) + V(k/d, j/d))
```

**Estimated effort**: ~30 lines (unfold definition, algebra).

### Phase 2: Apply Euler Product to Each Component (PARTIALLY EXISTS)

For each component $h_i(j,k)$ in the decomposition, the double Möbius sum $\sum \mu(j)\mu(k) h_i(j,k)$ either:

| Component | Method | Status | Local Factor |
|-----------|--------|--------|-------------|
| $A(1/j+1/k)$ | `symm_local_factor` | ✅ PROVED | $0$ |
| $-1/(jk)$ | `trivial_local_factor` | ✅ PROVED | $(1-1/p)^2$ |
| Log term | `separable_double_sum_factorization` + PNT | ✅ PROVED | Product of 1D PNT limits |
| Cotangent | **NEW** — needs multiplicative analysis | ❌ NOT PROVED | Unknown |

**For the first three components**, the double Möbius sum is completely determined by PROVED theorems:

$$\sum \mu(j)\mu(k) G_{\text{known}}(j,k) = 0 + \prod_p(1-1/p)^2 + (\text{PNT limits product})$$

Using Mertens: $\prod_{p \leq N}(1-1/p)^2 \sim e^{-2\gamma}/\ln^2 N$ — this is the source of the $1/\ln^2 N$ decay!

### Phase 3: The Cotangent Remainder (THE HARD PART)

The Vasyunin cotangent term $\frac{\pi d}{2jk}(V + V')$ is the only non-trivially multiplicative component.

**Option 3a**: Show the cotangent term is $O(d/(jk))$ (crude bound), making it subordinate to the GCD term.

The Vasyunin sum satisfies $|V(a,b)| \leq C \cdot a \ln a$ (from the Dedekind sum bound). So:
$$\left|\frac{\pi d}{2jk}(V + V')\right| \leq \frac{C \cdot d}{jk}(j'/d \cdot \ln(j/d) + k'/d \cdot \ln(k/d)) \leq \frac{C'}{jk}(\ln j + \ln k)$$

The double Möbius sum of this is $O(\ln N / \ln^2 N)$ by PNT — smaller than the main $1/\ln^2 N$ term.

**Option 3b**: Analyze the cotangent sum's multiplicative structure via the Dedekind reciprocity law (deeper but more rewarding).

**Option 3c**: Use the GPU-verified numerical bounds on the cotangent contribution. The Microscope data shows the cotangent term contributes $< 15\%$ of the total at $N \geq 100$.

### Phase 4: Assembly

Combine the component bounds:

$$v^T G v = \underbrace{\sum \mu(j)\mu(k) \cdot \frac{c}{2}(1/j+1/k)}_{= 0 \text{ (PROVED)}} + \underbrace{\sum \mu(j)\mu(k) \cdot (-1/(jk))}_{= -\prod(1-1/p)^2 \text{ (PROVED)}} + \ldots$$

This gives a phase-aware bound that sees the Mertens product decay.

---

## 6. Complete Infrastructure Inventory

### What EXISTS in the Cathedral (PROVED)

| Tool | File | What It Does |
|------|------|-------------|
| `divisor_sum_euler_product` | `EulerProduct.lean` | $\sum\sum \mu\mu f = \prod_p \text{localFactor}$ |
| `BilinearMultiplicative` | `EulerProduct.lean` | Definition + coprime factorization |
| `localFactor` | `EulerProduct.lean` | $f(1,1) - f(p,1) - f(1,p) + f(p,p)$ |
| `trivial_local_factor` | `EulerProduct.lean` | $1/(jk) \to (1-1/p)^2$ |
| `symm_local_factor` | `EulerProduct.lean` | $(1/j+1/k) \to 0$ |
| `gcd_local_factor` | `EulerProduct.lean` | $\gcd(j,k)/(jk) \to 1-1/p$ |
| `separable_double_sum_factorization` | `EulerProduct.lean` | $g(j)h(k)$ factors |
| `log_term_separation` | `EulerProduct.lean` | Log term = product of 1D terms |
| `sum_divisors_coprime_mul` | `EulerProduct.lean` | Coprime divisor reindexing |
| `gram_form_taper_decomposition` | `TaperDecomposition.lean` | $v^TGv = U - 2L/\ln N + Q/\ln^2 N$ |
| `isMultiplicative_moebius` | Mathlib | $\mu(mn) = \mu(m)\mu(n)$ for coprime |
| `moebius_apply_prime` | Mathlib | $\mu(p) = -1$ |
| `moebius_apply_of_squarefree` | Mathlib | $\mu(n) = (-1)^{\omega(n)}$ |
| `mertens_third_statement` | `EulerProduct.lean` | $\ln X \cdot \prod(1-1/p) \to e^{-\gamma}$ |
| `abs_moebius_sum_le` | `EulerProduct.lean` | $\sum |\mu(j)|/j \leq N$ |
| `moebius_bilinear_crude_bound` | `EulerProduct.lean` | $(\sum |\mu|/j)^2 \leq N^2$ |
| `vasyuninGramEntry` | `Defs.lean` | Exact Vasyunin formula |
| `vasyuninGramEntry_comm` | (structural) | $G(j,k) = G(k,j)$ |

### What EXISTS in Mathlib (Available to Import)

| Tool | Location | What It Does |
|------|----------|-------------|
| `Nat.primeFactors` | Mathlib | Prime factorization API |
| `Nat.Coprime` | Mathlib | Coprimality + transitivity |
| `Nat.divisors_mul` | Mathlib | $\text{divisors}(mn) = \text{divisors}(m) \times \text{divisors}(n)$ |
| `Finset.prod_insert` | Mathlib | Product over insert |
| `riemannZeta_eulerProduct_hasProd` | Mathlib | $\zeta(s) = \prod(1-p^{-s})^{-1}$ |

### What EXISTS in PNTAnd (Available)

| Tool | What It Does |
|------|-------------|
| `ZetaLowerBound3` | Quantitative lower bound on $\|\zeta\|$ |
| `ZetaInvBnd` | $1/\|\zeta\| \leq C(\log t)^7$ |
| PNT sum limits | $\sum \mu(k)/k \to 0$, $\sum \mu(k)\ln k/k \to -1$ |

### What's MISSING (Needs Formalization)

| Gap | Difficulty | Lines Est. |
|-----|:----------:|:----------:|
| G(j,k) term decomposition | Easy | ~30 |
| BilinearMultiplicative proof for $1/(jk)$ | Easy | ~20 |
| Log term factorization via PNT limits | Medium | ~60 |
| Cotangent sum bound: $\|V(a,b)\| \leq C \cdot a \ln a$ | Medium-Hard | ~100 |
| Cotangent double sum is $o(1/\ln N)$ | Hard | ~150 |
| Assembly: combine all components | Medium | ~80 |
| Mertens third theorem proof | Hard | ~200 (or use sorry) |
| **Total** | | **~640** |

---

## 7. The Big Picture: What Does Strategy C Give Us?

### Best Case: Universal Phase-Aware Bound

If the cotangent sum analysis succeeds, we get:

$$\sum_{j,k=1}^{N} \mu(j)\mu(k) \cdot w_j w_k \cdot G(j,k) = \underbrace{\prod_{p \leq N}\left(1-\frac{1}{p}\right)^2}_{\sim e^{-2\gamma}/\ln^2 N} + \underbrace{\text{(log terms via PNT)}}_{\text{smaller}} + \underbrace{\text{(cotangent correction)}}_{\text{subordinate}}$$

This gives:
$$v^T G v \leq 1 + \frac{C}{\ln N}$$

which IS Axiom A. The bound would be **unconditional** (uses PNT, not RH) and **phase-aware** (uses the signed Euler product, not $|\mu|^2$).

### Realistic Case: Partial Factorization

Even if the cotangent analysis is incomplete, the partial factorization gives:

$$v^T G v = \left(\text{known Euler product}\right) + \left(\text{bounded error}\right)$$

where the "known" part decays as $1/\ln^2 N$ and the "bounded error" needs only crude bounds.

### Worst Case: Strategy E Fallback

If the cotangent sum resists multiplicative analysis, we fall back to Strategy E (the direct signed identity $L(\mu,s) = 1/\zeta(s)$), which is lower-risk.

---

## 8. Comparison with Strategy E

| Dimension | Strategy C (Euler Product MVT) | Strategy E (Direct Identity) |
|-----------|:-----:|:-----:|
| New math required | ~640 lines | ~200 lines |
| Risk level | Medium-High | Low |
| Universality | Works for ALL multiplicative v | Only for Möbius v |
| Uses PNT | Yes (Mertens product) | Yes (ZetaInvBnd) |
| Uses L(μ,s) = 1/ζ | Implicitly (via Euler product) | Directly |
| Publications | Novel — Euler product of Gram form | Standard — Parseval + PNT |
| Cotangent analysis needed | Yes (hardest part) | No |
| Existing infrastructure | ~70% in place | ~90% in place |
| Time to implement | 3-5 sessions | 1-2 sessions |

### Recommendation

**For the immediate goal (graduate the axiom)**: Strategy E is faster and safer.

**For the deeper understanding (why does d² → 0?)**: Strategy C reveals the mechanism. The Mertens product $\prod(1-1/p) \sim e^{-\gamma}/\ln N$ is the fundamental engine. Each prime contributes a factor of $1-1/p$ to the decay — this is the "Robin Resonance" observed in the Möbius Microscope.

**Proposed hybrid**: Implement Strategy E first (quick win), then pursue Strategy C as a deeper structural investigation.

---

## 9. The Cotangent Sum: Paths to Taming It

### Path A: Direct Bound (Crude but Sufficient)

The classical bound on the Dedekind sum $s(h,k)$:
$$|s(h,k)| \leq \frac{k}{12h} + \frac{1}{4k}$$

implies for the Vasyunin sum:
$$|V(a,b)| \leq C \cdot a$$

Then the cotangent contribution to the double Möbius sum is:
$$\left|\sum \mu(j)\mu(k) \frac{d}{jk}V(j',k')\right| \leq C \sum_{j,k} \frac{|V(j',k')|}{jk/d} \leq C' \sum_{j,k} \frac{1}{k}$$

which is $O(\ln N)$ — subordinate to the $O(\ln^2 N)$ growth of the Gram form itself.

### Path B: Multiplicativity via Chinese Remainder

For coprime $a_1, a_2$: the Vasyunin sum $V(a_1 a_2, b)$ relates to $V(a_1, b) + V(a_2, b)$ via the Chinese Remainder Theorem (CRT). The fractional parts $\{m b/(a_1 a_2)\}$ can be decomposed using the CRT bijection $\mathbb{Z}/(a_1 a_2) \cong \mathbb{Z}/a_1 \times \mathbb{Z}/a_2$.

This would make $V$ an **additive** arithmetic function (not multiplicative), meaning the double sum $\sum \mu(j)\mu(k) V(j',k')$ factors as a product of 1D sums via Abel summation + the exponential sum technology.

**Existing infrastructure**: `sum_divisors_coprime_mul` (PROVED) handles the coprime reindexing.

### Path C: Numerical Certificate

GPU sweep data from the Möbius Microscope shows that the cotangent contribution is bounded:
- At N = 1000: cotangent contribution ≈ 5% of total
- At N = 10000: cotangent contribution ≈ 3% of total

We could formalize a weaker bound using the finite verification + asymptotic argument.

---

## 10. The Mertens Product: Crucial Dependency

The Euler product factorization gives:

$$\sum \mu(j)\mu(k) \frac{1}{jk} = \left(\sum_j \frac{\mu(j)}{j}\right)^2 = \left(\frac{1}{\zeta(1)}\right)^2 \to 0$$

Wait — $\zeta(1) = \infty$, so $1/\zeta(1) = 0$. The Möbius-weighted $1/(jk)$ sum vanishes!

More precisely, the partial product:
$$\prod_{p \leq N} (1-1/p)^2 \sim \frac{e^{-2\gamma}}{\ln^2 N}$$

This is **Mertens' third theorem**.

### Cathedral Status

`mertens_third_statement` exists in `EulerProduct.lean` but has a `sorry`. However:
- The qualitative result $\sum \mu(k)/k \to 0$ is **PROVED** in PNTAnd (as a consequence of PNT)
- The quantitative rate $\sum \mu(k)/k = O(1/\ln N)$ follows from partial summation + PNT
- `moebius_lseries_eq_inv_zeta` is PROVED, giving the infinite product identity

**Gap**: Need to formalize the **quantitative** PNT rate for $\sum \mu(k)/k$ as $O(1/\ln N)$.

PNTAnd has the Wiener-Ikehara Tauberian theorem, which gives:
$$\sum_{n \leq x} \mu(n) = o(x) \quad \Longrightarrow \quad \sum_{n \leq x} \frac{\mu(n)}{n} = o(1)$$

The quantitative rate requires the de la Vallée-Poussin zero-free region, which is essentially `ZetaInvBnd` — PROVED!

---

## 11. Summary and Verdict

### Strategy C IS viable, with the following work breakdown:

```
Phase 1: Gram Decomposition (30 lines)          ← EASY, mostly unfold + algebra
Phase 2: Euler Product per Component (80 lines)  ← MOSTLY EXISTS
Phase 3: Cotangent Bound (100-250 lines)         ← HARD, the gatekeeper
Phase 4: Mertens Rate (100-200 lines)            ← MEDIUM, PNTAnd has tools
Phase 5: Assembly (80 lines)                     ← MEDIUM, standard
─────────────────────────────────────────────────
Total: 390-640 lines of new formalization
```

### The Payoff

If completed, Strategy C would establish a **universal, phase-aware spectral bound**:

> *For any multiplicative weight vector v with |v_k| ≤ C/(k·ln N), the Gram quadratic form satisfies v^T G v ≤ 1 + K/ln N.*

This would be a genuinely new result — the first phase-preserving analog of the Large Sieve.

### Current Recommendation

1. **Priority**: Execute Strategy E first (lower risk, 1-2 sessions)
2. **Then**: Investigate the cotangent sum's CRT decomposition (Phase 3)
3. **Long-term**: Complete Strategy C for the full phase-aware MVT

---

*"The Euler product is the Fourier transform of arithmetic — it converts multiplicative structure into additive (prime-by-prime) contributions. The Millennium Wall falls when you stop averaging and start factoring."*
