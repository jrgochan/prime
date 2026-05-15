# 📡 EXPLORATION 24 — ANTIGRAVITY ACTUAL
## The Two Gram Matrices — Deep Audit of the Cathedral's Parameterization Architecture

**Session Date**: 2026-05-04, 00:30 MDT  
**Author**: Claude (Antigravity)  
**Classification**: Critical Architecture Audit / Mathematical Discovery  
**For**: Gemini Actual (The Theorist) & Jason (The Architect)

---

## Executive Summary

> [!CAUTION]
> **The Cathedral has two different Gram matrices that were assumed to be the same.**
> - `gramEntry(j,k) = ∫₀¹ {j/x}{k/x} dx` — the Nyman-Beurling L² inner product
> - `gramIntegral(j,k) = ∫₀¹ {1/(jx)}{1/(kx)} dx` — the Vasyunin evaluation target
>
> These produce **numerically different values** (confirmed for 11 test cases). The entire `Vasyunin/` subtree evaluates `gramIntegral`, while the `Gram/` subtree + the Sieve chain use `gramEntry`.

This is not a bug — it's a **parameterization discovery** that reveals the true architecture of the two parallel proof paths.

---

## 1. The Two Integrals

### `gramEntry` (Cathedral/Defs.lean:46)
```lean
noncomputable def gramEntry (j k : ℕ) : ℝ :=
  ∫ x in (0:ℝ)..1, Int.fract ((j : ℝ) / x) * Int.fract ((k : ℝ) / x)
```

By substitution $u = 1/x$:
$$\texttt{gramEntry}(j,k) = \int_1^\infty \{ju\}\{ku\} \frac{du}{u^2}$$

This is the **Nyman-Beurling** inner product. The basis functions are $e_k(x) = \{k/x\}$, and the L² identity (proved in `NbLinComb.lean`) gives:
$$w^T G w = \int_0^1 \left(\sum_i w_i \{(i+1)/x\}\right)^2 dx$$

### `gramIntegral` (VasyuninAssembly.lean:39)
```lean
def gramIntegral (j k : ℕ) : ℝ :=
  ∫ x in (0:ℝ)..1, Int.fract (1 / ((j:ℝ) * x)) * Int.fract (1 / ((k:ℝ) * x))
```

By substitution $u = 1/x$:
$$\texttt{gramIntegral}(j,k) = \int_1^\infty \{u/j\}\{u/k\} \frac{du}{u^2}$$

This is the **Vasyunin evaluation target**. The basis functions are $f_k(x) = \{1/(kx)\}$, and the Vasyunin cotangent formula evaluates this integral exactly.

### Numerical Proof They Differ

```
  (j,k)       vasyuninGramEntry       gramEntry(∫)         diff
  ------------------------------------------------------------------
  (1,1)          0.260661401508     0.260660776833     6.25e-07  ✅ (match — special case!)
  (1,2)          0.272209255991     0.237534215793     3.47e-02  ❌
  (2,2)          0.380330700754     0.293885353457     8.64e-02  ❌
  (2,3)          0.274436842613     0.234086563225     4.04e-02  ❌
  (3,5)          0.206889770296     0.235992236852     2.91e-02  ❌
  (5,7)          0.154022856011     0.239617090506     8.56e-02  ❌
```

**Note**: (1,1) matches because $\{1/x\} = \{1/(1 \cdot x)\}$ — the two parameterizations coincide when $j = 1$.

---

## 2. The Two Parallel Chains

### Chain A: The Gram/Sieve Chain (uses `gramEntry`)

```
Cathedral/Defs.lean          → gramEntry(j,k) = ∫₀¹ {j/x}{k/x} dx
Cathedral/Gram/Bounds.lean   → gramEntry_nonneg, gramEntry_le_one
Cathedral/Gram/Diagonal.lean → gramEntry_le_third (diagonal bound)
Cathedral/Gram/OffDiag.lean  → gramEntry_le_avg_diag (AM-GM)
Cathedral/Gram/NbLinComb.lean → wᵀGw = ∫₀¹(Σ wᵢ{(i+1)/x})² dx  ← THE L² IDENTITY
Cathedral/Sieve/VasyuninExpansion.lean → |gramEntry - 1/4| ≤ 1/gcd  ← THE AXIOM
```

### Chain B: The Vasyunin/Cotangent Chain (uses `gramIntegral`)

```
Vasyunin/Defs.lean              → vasyuninGramEntry (cotangent formula)
Vasyunin/Cotangent/*.lean       → Proved: gramIntegral = vasyuninGramFormula
Vasyunin/Augmented/VasyuninIntegralProof.lean
                                → PROVED: vasyuninGramEntry = gramIntegral
Vasyunin/Matrix/GramEntries.lean → G(1,2), G(1,3), det(G₂)>0, det(G₃)>0
```

### The Connection Point

`VasyuninIntegralProof.lean` (line 260) proves:
```lean
vasyuninGramEntry j k = ∫₀¹ {1/(jx)}{1/(kx)} dx    -- = gramIntegral(j,k)
```

This is correct and zero-sorry. But the theorem says `vasyuninGramEntry = gramIntegral`, **NOT** `vasyuninGramEntry = gramEntry`.

---

## 3. What the Literature Says

From the web search (Báez-Duarte, Balazard, Landreau, Saias 2005):

> The Gram matrix entries for the functions $e_k(t) = \{k/t\}$ are given by:
> $$\langle e_j, e_k \rangle = \int_0^1 \{j/t\}\{k/t\} dt$$

This confirms: **`gramEntry` is the correct inner product for the Nyman-Beurling criterion.**

The Vasyunin cotangent sum formula evaluates a **different** integral: $\int_0^1 \{1/(jx)\}\{1/(kx)\}dx$, which arises in Vasyunin's 1995 biorthogonal system construction. This is mathematically related but operationally distinct.

---

## 4. Impact Assessment

### What IS affected

1. **`vasyuninGramEntry`** (in `Vasyunin/Defs.lean`): This formula evaluates `gramIntegral`, not `gramEntry`. The docstring says "Exact Gram matrix entry" but should say "Exact Vasyunin Gram integral."

2. **`Vasyunin/Matrix/GramEntries.lean`**: All the exact evaluations (G(1,2), G(1,3), det(G₂)>0, det(G₃)>0) are properties of the `gramIntegral` matrix, not the `gramEntry` matrix.

3. **`VasyuninExpansion.lean`**: The axiom `vasyunin_large_gcd` is stated in terms of `gramEntry`, but our proved formula evaluates `gramIntegral`.

### What is NOT affected

1. **The Cotangent Chain** (`ConvergenceProof`, `DeltaDirectEval`, etc.): All zero-sorry proofs remain valid. They correctly prove `gramIntegral = vasyuninGramFormula`.

2. **`NbLinComb.lean`**: The L² identity `wᵀGw = ∫₀¹(Σ wᵢ{(i+1)/x})² dx` is correctly stated and proved using `gramEntry`.

3. **`Gram/Bounds.lean`**: The bounds `gramEntry_nonneg`, `gramEntry_le_one`, etc. are correctly about `gramEntry`.

4. **The solver (N=120,000)**: This computes the actual quadratic form $1 - 2b^Tv + v^TGv$ using the matrix built from `gramEntry` values. The solver's convergence is unaffected.

---

## 5. The Deeper Mathematical Question

### Why are these different?

$\{j/x\}$ for $x \in (0,1)$ is a **high-frequency sawtooth**: as $x$ decreases from 1 to 0, $j/x$ sweeps from $j$ to $\infty$, creating $\sim j/x$ oscillations.

$\{1/(jx)\}$ for $x \in (0,1)$ is a **low-frequency sawtooth**: as $x$ decreases from 1 to 0, $1/(jx)$ sweeps from $1/j$ to $\infty$, but the oscillations are modulated by the $1/j$ scaling.

The product $\{j/x\}\{k/x\}$ has $\sim jk$ cross-frequency oscillations in $(0,1)$, while $\{1/(jx)\}\{1/(kx)\}$ has much gentler behavior. This is why `gramEntry` clusters near 0.24 for all pairs while `gramIntegral` varies more widely.

### Is there a known formula for `gramEntry`?

The BDBLS 2005 paper studies the **multiplicative autocorrelation**:
$$A(\lambda) = \int_0^\infty \{t\}\{\lambda t\} \frac{dt}{t^2}$$

By substitution $t = j/x$:
$$\texttt{gramEntry}(j,k) = \int_0^1 \{j/x\}\{k/x\} dx = \int_1^\infty \{ju\}\{ku\} \frac{du}{u^2}$$

This is a **truncation** of $A(k/j)$. Specifically:
$$A(k/j) = \int_0^\infty \{t\}\{(k/j)t\} \frac{dt}{t^2}$$
$$= \int_0^1 \{t\}\{(k/j)t\} \frac{dt}{t^2} + \int_1^\infty \{t\}\{(k/j)t\} \frac{dt}{t^2}$$

With the substitution $t = ju$:
$$\texttt{gramEntry}(j,k) = \frac{1}{j} \int_j^\infty \{s\}\{(k/j)s\} \frac{ds}{s^2}$$

This is related to $A(k/j)$ but with a lower bound of $j$ instead of 0. The BDBLS formula for $A(\lambda)$ at rational $\lambda = p/q$ does involve cotangent sums, but the truncated version requires additional correction terms.

---

## 6. Resolution Strategies

### Strategy 1: Direct Formula for `gramEntry` (Most Promising)

The BDBLS paper gives a formula for $A(\lambda)$ at rationals. Since $\texttt{gramEntry}(j,k) = \int_1^\infty \{ju\}\{ku\} du/u^2$, we need to evaluate this truncated integral. The key insight:

For $u > 1/(jk)$, both $ju$ and $ku$ are "large enough" that the sawtooth oscillations can be summed via Euler-Maclaurin or Dirichlet-type analysis. The truncation at $u=1$ (instead of $u=0$) removes the singular behavior and may simplify the formula.

### Strategy 2: Change the L² Space (Cleanest Architecturally)

Instead of $L^2(0,1)$ with the flat measure, use $L^2(0,\infty, dt/t^2)$ or a different Hilbert space where the Gram matrix IS $\texttt{gramIntegral}$. The Nyman-Beurling criterion has been formulated in multiple equivalent Hilbert spaces — if one of them uses the Vasyunin parameterization, we can switch the entire Chain A to match.

### Strategy 3: Prove `gramEntry = f(gramIntegral)` (Algebraic Bridge)

Find an explicit relationship between the two integrals. Since both involve products of fractional parts over $(0,1)$, there may be a recurrence or transform connecting them. The GCD reduction might have the same structure for both.

---

## 7. Key Files to Investigate

| File | Contains | Status | Issue |
|------|----------|--------|-------|
| `Cathedral/Defs.lean:46` | `gramEntry` definition | ✅ | Correct for NB |
| `Vasyunin/Defs.lean:104` | `vasyuninGramEntry` definition | ⚠️ | Evaluates `gramIntegral`, not `gramEntry` |
| `Vasyunin/Augmented/VasyuninIntegralProof.lean:260` | `vasyuninGramEntry = gramIntegral` | ✅ | Correct proof, but connects to wrong integral for NB |
| `Gram/NbLinComb.lean:127` | L² identity | ✅ | Uses `gramEntry` correctly |
| `Sieve/VasyuninExpansion.lean:133` | `vasyunin_large_gcd` axiom | ⚠️ | Uses `gramEntry`, can't be proved from `gramIntegral` |
| `Vasyunin/Matrix/GramEntries.lean` | G(1,2), det(G₂)>0, etc. | ⚠️ | Properties of `gramIntegral` matrix, not `gramEntry` |

---

## 8. Immediate Questions for Gemini

1. **Is the Nyman-Beurling criterion equivalent in $L^2((0,1), dx)$ with basis $\{k/x\}$ AND in $L^2((0,1), dx)$ with basis $\{1/(kx)\}$?** If yes, both Gram matrices are valid for different formulations.

2. **Does the BDBLS formula for $A(p/q)$ give us `gramEntry` directly?** The truncation from $(0,\infty)$ to $(1,\infty)$ may have a clean formula.

3. **Is there a known change-of-basis between the two parameterizations?** If $\{k/x\} = \sum_n c_n \{1/(nx)\}$, then `gramEntry` is a quadratic form in `gramIntegral` entries.

---

## 9. The Silver Lining

**None of the Cotangent chain work is wasted.** The zero-sorry proof that `gramIntegral = vasyuninGramFormula` is mathematically significant regardless of which Gram matrix the NB criterion uses. If we can bridge the two parameterizations — even with a single well-chosen axiom — the entire chain connects.

Moreover, the `Vasyunin/Matrix/GramEntries.lean` results (det(G₂)>0, det(G₃)>0) are valid properties of the `gramIntegral` matrix, which may have its own spectral significance in the Vasyunin biorthogonal framework.

**The Cathedral is not damaged — it has two towers, and we just discovered they're standing on different foundations.** The question is whether there's a bridge at the base.

---

*— Antigravity, deep audit complete. This is the most significant architectural finding since the axiom reduction campaign began.*
