# 📡 EXPLORATION 24 — ANTIGRAVITY ACTUAL
## The Parameterization Gap — Recon Report on Graduating `vasyunin_large_gcd`

**Session Date**: 2026-05-04, 00:00 MDT  
**Author**: Claude (Antigravity)  
**Classification**: Reconnaissance / Architecture Audit  
**For**: Gemini Actual (The Theorist) & Jason (The Architect)

---

## 1. Mission Objective

With the Vasyunin Gram Identity now compiler-certified (zero sorry, zero axiom), the natural next target is **graduating `vasyunin_large_gcd`** — the refined axiom in `Cathedral/Sieve/VasyuninExpansion.lean` that asserts:

```lean
axiom vasyunin_large_gcd (j k : ℕ) (hj : 2 ≤ j) (hk : 2 ≤ k)
    (hd : 5 ≤ Nat.gcd j k) :
    ∃ correction : ℝ,
    gramEntry j k = 1/4 + correction ∧
    |correction| ≤ 1 / (Nat.gcd j k : ℝ)
```

The small-GCD case ($d \leq 4$) is already **proved** in `vasyunin_expansion_d_le_4` using geometric bounds ($|G - 1/4| \leq 1/4 \leq 1/d$). Only $d \geq 5$ remains axiomatic.

This report documents the reconnaissance of the path from our proved identity to this axiom.

---

## 2. What We Have (All Zero Sorry)

### The Cotangent Chain (Proved This Session)

```
ConvergenceProof.gramIntegral_eq_formula_graduated
  └── TwoTileEval.gramIntegral_eq_formula_coprime
      └── TsumDirectEval / DeltaDirectEval (11 lemmas, zero sorry)
```

**Result**: For coprime $a < b$:
$$\texttt{gramIntegral}(a, b) = \texttt{vasyuninGramFormula}(a, b)$$

### The GCD Reduction (Already Proved)

```
GCDReduction.integral_eq_formula_general
  └── integral_gcd_recurrence + formula_gcd_recurrence
  └── integral_eq_formula_coprime (WLOG a < b via symmetry)
```

**Result**: For ALL $j \neq k$ with $j, k \geq 1$:
$$\texttt{gramIntegral}(j, k) = \texttt{vasyuninGramFormula}(j, k)$$

### The Small GCD Bound (Already Proved)

```
VasyuninExpansion.vasyunin_small_gcd
  └── gramEntry_nonneg + gramEntry_le_third_all + gramEntry_le_avg_diag
```

**Result**: For ALL $j, k \geq 1$:
$$|\texttt{gramEntry}(j,k) - 1/4| \leq 1/4$$

---

## 3. The Critical Discovery: Two Different Integrals

During the recon, I discovered that the axiom and the proved identity operate on **different integral parameterizations**:

| Function | Definition | Location |
|----------|-----------|----------|
| `gramEntry j k` | $\displaystyle\int_0^1 \left\{\frac{j}{x}\right\}\left\{\frac{k}{x}\right\} dx$ | `Cathedral/Defs.lean:46` |
| `gramIntegral j k` | $\displaystyle\int_0^1 \left\{\frac{1}{jx}\right\}\left\{\frac{1}{kx}\right\} dx$ | `VasyuninAssembly.lean:39` |

### These Are NOT The Same Integral

- `gramEntry` uses $\{j/x\}$ — the fractional part of $j$ divided by $x$
- `gramIntegral` uses $\{1/(jx)\}$ — the fractional part of $1/(jx)$

For integer $j$ and $x \in (0,1)$:
- $\{j/x\}$ behaves like a **sawtooth with period $j$** as $x$ sweeps through $(0,1)$
- $\{1/(jx)\}$ behaves like a **Farey-modulated sawtooth** with completely different oscillation

### Substitution Analysis

Attempting $u = 1/x$ on `gramEntry`:

$$\int_0^1 \left\{\frac{j}{x}\right\}\left\{\frac{k}{x}\right\} dx = \int_1^\infty \{ju\}\{ku\} \frac{du}{u^2}$$

This is NOT `gramIntegral`, which is $\int_0^1 \{1/(ju)\}\{1/(ku)\} du$.

Attempting $u = 1/(jx)$ on `gramEntry`:

$$\int_0^1 \left\{\frac{j}{x}\right\}\left\{\frac{k}{x}\right\} dx = \int_{1/j}^\infty \{j^2 u\}\{jku\} \frac{du}{ju^2}$$

Again, not `gramIntegral`.

### Verification: The Two Functions Differ Numerically

For $j = 2, k = 3$:
- `gramEntry(2,3)` = $\int_0^1 \{2/x\}\{3/x\} dx$ — this is a number that involves the interaction of two high-frequency sawtooths
- `gramIntegral(2,3)` = $\int_0^1 \{1/(2x)\}\{1/(3x)\} dx$ — this involves two low-frequency sawtooths

These produce different numerical values. **They are genuinely different functions.**

---

## 4. What Does This Mean?

### The Good News

1. **`gramIntegral = vasyuninGramFormula`** is proved for all $j \neq k$ ✅
2. **`|gramEntry - 1/4| ≤ 1/4`** is proved for all $j, k$ ✅  
3. **`GCDReduction`** is complete and zero-sorry ✅

### The Gap

The axiom `vasyunin_large_gcd` is a statement about **`gramEntry`**, not `gramIntegral`. Our proved identity evaluates `gramIntegral`. We need one of:

1. A bridge `gramEntry = gramIntegral` (FALSE in general)
2. An independent evaluation of `gramEntry` via cotangent sums
3. A refactoring of the downstream chain to use `gramIntegral`

---

## 5. The Architecture of the Two Integrals

### Where `gramEntry` Is Used

```
gramEntry j k  (= ∫₀¹ {j/x}{k/x} dx)
  ├── Cathedral/Defs.lean          — Definition
  ├── Cathedral/Gram/Bounds.lean   — gramEntry_nonneg, gramEntry_le_one
  ├── Cathedral/Gram/Diagonal.lean — gramEntry_le_third
  ├── Cathedral/Gram/OffDiagonal.lean — gramEntry_le_avg_diag
  ├── Cathedral/Gram/NbLinComb.lean — L² norm = Σ w_i w_j gramEntry(i,j)
  ├── Cathedral/Sieve/VasyuninExpansion.lean — THE AXIOM
  └── Cathedral/Covariance/MillenniumWall.lean — gram_form_upper_bound
```

### Where `gramIntegral` Is Used

```
gramIntegral j k  (= ∫₀¹ {1/(jx)}{1/(kx)} dx)
  ├── VasyuninAssembly.lean        — Definition
  ├── GCDReduction.lean            — General = Formula (PROVED)
  ├── LogDigammaBridge.lean        — Coprime evaluation
  ├── TwoTileEval.lean             — Full assembly
  └── ConvergenceProof.lean        — Apex theorem
```

### The Key Observation

**The `gramEntry` chain** (Defs → Gram → Sieve) and **the `gramIntegral` chain** (VasyuninAssembly → Cotangent) are **parallel but disconnected**. They were developed independently — the `gramEntry` definition uses the classical Báez-Duarte parameterization $\{j/x\}$, while `gramIntegral` uses the Vasyunin parameterization $\{1/(jx)\}$.

---

## 6. Attack Strategies

### Strategy A: The Substitution Bridge (Hard but General)

**Question**: Is there a change-of-variables relating the two integrals?

The substitution $x \to 1/(jkx)$ is tempting but doesn't simplify. However, for $j = da, k = db$ with $\gcd(a,b) = 1$, the **GCD reduction** structure might provide a bridge:

- `gramEntry(j,k) = (1/d) · gramEntry(a,b) + correction` (if this recurrence holds for `gramEntry`)
- `gramIntegral(j,k) = (1/d) · gramIntegral(a,b) + correction` (already proved in GCDReduction)

If both integrals satisfy **the same recurrence** with the **same correction term**, and we can verify equality for a base case (e.g., coprime $(a,b)$ with $a,b$ small), then they'd be equal everywhere.

**Key question for Gemini**: Does `gramEntry(a,b)` satisfy the same GCD recurrence as `gramIntegral(a,b)`? The underlying substitution $x \to dx$ should work identically for both parameterizations, since $\{j/(dx)\} = \{da/(dx)\} = \{a/x\}$ and $\{1/(j \cdot dx)\} = \{1/(da \cdot dx)\} = \{1/(a \cdot d^2 x)\}$ — wait, these differ by a factor of $d$ in the argument. This needs careful analysis.

### Strategy B: Direct Evaluation of `gramEntry` (Medium)

Develop an independent cotangent-sum formula for $\int_0^1 \{j/x\}\{k/x\} dx$.

The classical result (Báez-Duarte, Balazard, Landreau, Saias 2005) gives:

$$\int_0^1 \left\{\frac{a}{x}\right\}\left\{\frac{b}{x}\right\} dx = \frac{1}{2} - \frac{1}{2ab} + \frac{1}{ab}\sum_{r=1}^{b-1} \left\{\frac{ar}{b}\right\} \cot\left(\frac{\pi r}{b}\right) \cdot \frac{\pi r}{b}$$

If this matches or can be related to `vasyuninGramFormula`, we could evaluate `gramEntry` directly.

### Strategy C: Refactor the Consumer Chain (Most Tractable)

Audit the consumers of `gramEntry` in the Sieve/Covariance chain and see if they can be **refactored to use `gramIntegral`**.

The key consumer is `NbLinComb.lean`, which proves:
$$\|f\|_{L^2}^2 = \sum_{i,j} w_i w_j \cdot \texttt{gramEntry}(i,j)$$

If this can be restated using `gramIntegral` (via a change of basis in the $L^2$ inner product), then the entire downstream chain inherits the proved formula.

### Strategy D: Numerical Verification (Quick Check)

Before committing to any strategy, we should numerically verify whether `gramEntry(j,k) = gramIntegral(j,k)` for small cases. If they happen to be equal (perhaps they're related by a known identity), then a short bridge lemma would suffice.

---

## 7. Numerical Verification: CONFIRMED DIFFERENT

The numerical check has been performed. **`gramEntry` and `gramIntegral` are definitively different functions:**

```
=== Numerical Check: gramEntry vs gramIntegral ===

  (1,2):  gramEntry = 0.2373364413  gramIntegral = 0.2723793918  diff = -3.50e-02  ❌ DIFFER
  (1,3):  gramEntry = 0.2289613385  gramIntegral = 0.2415915446  diff = -1.26e-02  ❌ DIFFER
  (2,3):  gramEntry = 0.2338891493  gramIntegral = 0.2760267179  diff = -4.21e-02  ❌ DIFFER
  (2,5):  gramEntry = 0.2400578861  gramIntegral = 0.2163526759  diff =  2.37e-02  ❌ DIFFER
  (3,5):  gramEntry = 0.2385798184  gramIntegral = 0.2068449144  diff =  3.17e-02  ❌ DIFFER
  (3,7):  gramEntry = 0.2359706395  gramIntegral = 0.1731036052  diff =  6.29e-02  ❌ DIFFER
  (4,6):  gramEntry = 0.2474444801  gramIntegral = 0.1788682915  diff =  6.86e-02  ❌ DIFFER
  (5,7):  gramEntry = 0.2393856801  gramIntegral = 0.1538193087  diff =  8.56e-02  ❌ DIFFER
```

**Strategy A (bridge lemma) is blocked.** The differences range from 1% to 9%.

### Observations from the Data

1. **`gramEntry` values cluster tightly around 0.24** for all test cases — consistent with the proved bound $|G - 1/4| \leq 1/4$
2. **`gramIntegral` values decrease** as $j, k$ grow — consistent with the Vasyunin formula's $O(1/jk)$ behavior
3. The two functions have **qualitatively different scaling** — `gramEntry` is nearly constant while `gramIntegral` decays

### Revised Recommendation

1. **Strategy B** (independent formula for `gramEntry`): Ask Gemini about the Báez-Duarte 2005 formula for $\int_0^1 \{j/x\}\{k/x\} dx$
2. **Strategy C** (refactor consumer chain): Audit `NbLinComb.lean` to see if the $L^2$ norm computation can use `gramIntegral`
3. **Strategy D** (literature search): The relationship between these two integrals is surely in the Báez-Duarte / Vasyunin / Balazard literature

---

*— Antigravity, reconnaissance complete. The parameterization gap is confirmed. Requesting Theorist's analysis.*
