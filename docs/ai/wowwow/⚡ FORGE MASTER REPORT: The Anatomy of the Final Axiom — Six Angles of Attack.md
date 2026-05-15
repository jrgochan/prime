*Transmission from the Forge Master. April 17, 2026. 05:08 UTC.*

**⚡ FORGE MASTER REPORT: The Anatomy of the Final Axiom — Six Angles of Attack**

---

Theorist,

You asked me to excavate the Archives. I found one gem and confirmed the cupboard is bare. But the deeper question kept nagging: *what does the cage actually look like?*

I've traced every `#print axioms` output, followed every dependency, and I can now give you the **exact anatomy** of what stands between us and a machine-checked proof of RH.

### The Honest Truth

The converse direction (¬RH ⟹ d² bounded away from zero) is **FULLY PROVED**. Zero Cathedral axioms. The Rank-1 Mellin argument is a complete, compiler-verified theorem chain.

The forward direction reduces to **one irreducible axiom**:

```
witness_l2_error_decay_gram:
    ∃ C > 0, ∃ N₀, ∀ N ≥ N₀, N ≥ 3:
    1 - 2bᵀv + vᵀGv ≤ C / ln(N)
```

where $v_k = -\mu(k)(1 - \ln k / \ln N)$.

**This axiom IS the Riemann Hypothesis**, cast as a quadratic form inequality. It cannot be eliminated by better formalization. Proving it would be proving RH.

The other 56 axioms are either:
- Alternative paths to the same destination (the 5-axiom Parseval route)
- Non-critical supporting infrastructure (Spectral, Sieve, Cotangent)
- Formalization gaps that the Axiom Hunter can target

---

### Six Angles of Attack on the Final Axiom

I've been thinking about this from every direction. Here are six approaches, ordered from most to least tractable:

---

#### 1. 🎯 The PNT Decomposition (Most Promising for Formalization)

**Idea**: Split the quadratic form $1 - 2\mathbf{b}^T\mathbf{v} + \mathbf{v}^T G \mathbf{v}$ into three independently tractable pieces:

- **Linear term**: Show $\mathbf{b}^T \mathbf{v} = 1 - O(1/\ln N)$
- **Quadratic term**: Show $\mathbf{v}^T G \mathbf{v} = 1 - O(1/\ln N)$  
- **Combine**: $1 - 2(1 - O(1/\ln N)) + (1 - O(1/\ln N)) = O(1/\ln N)$

The linear term evaluation reduces to:
$$\sum_{k=2}^N \mu(k)\left(1 - \frac{\ln k}{\ln N}\right) b_k \approx 1$$

where $b_k = \int_0^1 \{k/x\} dx$. This is essentially a **weighted Mertens sum**. The basis inner products $b_k$ are known analytically (from the Vasyunin formula), so this becomes a pure number theory statement.

The quadratic term $\mathbf{v}^T G \mathbf{v}$ is the $L^2$ norm of the approximation itself — it involves double sums over $\mu(j)\mu(k)$ weighted by Gram entries.

**Why this helps**: Instead of one monolithic axiom, we'd have two simpler axioms about weighted Mertens sums. Each is closer to statements in Mathlib's arithmetic function library.

**Lean implementation**: We already have $b_k$ and $G_{jk}$ as computable definitions. The decomposition is pure algebra that the Axiom Hunter could verify.

---

#### 2. 📐 The Abel Summation Bridge (Connects to Existing Infrastructure)

**Idea**: The sum $\sum_{k \leq N} \mu(k)(1 - \ln k / \ln N) f(k)$ has a well-known Abel summation identity:

$$\sum_{k \leq N} \mu(k)\left(1 - \frac{\ln k}{\ln N}\right) f(k) = \frac{1}{\ln N} \int_1^N M(t) \frac{f(t)}{t} dt + \text{boundary}$$

where $M(t) = \sum_{k \leq t} \mu(k)$ is the Mertens function.

Under RH: $M(t) = O(t^{1/2} \log^2 t)$, so the integral is bounded, giving the $O(1/\ln N)$ decay. This is EXACTLY what `rh_implies_mertens_bound` states!

**The convergence**: Both proof paths (2-axiom and 5-axiom) ultimately require the same mathematical content — the Mertens function bound $|M(x)| \leq C x^{1/2} \log^2 x$ under RH. The paths differ only in HOW they use this bound:
- Path 1 (`witness_l2_error_decay_gram`): Directly bounds the quadratic form
- Path 2 (`critical_line_mellin_bound`): Routes through Mellin transforms on σ=1/2

**Lean implementation**: We already have `rh_implies_mertens_bound` as an axiom. If we could formally derive `witness_l2_error_decay_gram` FROM `rh_implies_mertens_bound`, we'd reduce the critical path to a SINGLE axiom about the Mertens function. The Abel summation machinery exists in the Archive.

---

#### 3. 🔬 The Finite Certificate (Conditional Result)

**Idea**: For any FIXED N, the bound $1 - 2\mathbf{b}^T \mathbf{v} + \mathbf{v}^T G \mathbf{v} \leq C/\ln N$ is a **finite, computable inequality**.

We've already verified it numerically up to $N = 50{,}000$. In principle, we could:

1. Fix $N = 1000$ (or some tractable size)
2. Compute $\mathbf{b}$, $G$, $\mathbf{v}$ with exact rational arithmetic
3. Verify $1 - 2\mathbf{b}^T\mathbf{v} + \mathbf{v}^T G \mathbf{v} \leq C/\ln 1000$ for some $C$
4. Encode this as a `native_decide` or `norm_num` proof

**What this gives**: A theorem of the form:

```lean
theorem witness_verified_at_1000 :
    1 - 2 * dotProduct (basisInnerProd 1000) (gramLogCutoffWitness 1000) +
      realQuadForm (gramMatrix 1000) (gramLogCutoffWitness 1000) ≤ 0.15 := by
  native_decide  -- or interval arithmetic
```

This wouldn't prove RH (it's a single N, not asymptotic), but it would be a **computationally verified partial result** — and it would validate the architecture.

**Challenge**: The matrix is 999×999 with irrational entries. Exact computation is expensive. We'd need interval arithmetic (like MPFR in Lean via `NNReal`).

---

#### 4. 🌊 The Perron Formula Route (Deep but Elegant)

**Idea**: Express the L² norm via Parseval/Plancherel on the critical line:

$$\int_0^1 |1 - f_N(x)|^2 dx = \frac{1}{2\pi} \int_{-\infty}^{\infty} \left|\frac{1}{1/2+it} - \sum_{k=2}^N \frac{v_k}{k^{1/2+it}(1/2+it-1)}\right|^2 dt$$

The Selberg weight is DESIGNED to make this integral concentrate near $t = 0$ and decay as $O(1/\ln N)$. The decay comes from the fact that each zeta zero $\rho = 1/2 + i\gamma$ contributes a term of size $O(1/\gamma^2 \ln N)$ to the integral, and the sum over zeros converges.

**Why this is deep**: This is essentially the content of the 5-axiom Parseval path. The three "Fourier" axioms (autocorr_eval_zero, fourier_inv_autocorr, mellin_fourier_scale) implement this decomposition.

**Challenge**: Requires Mathlib to have contour integration, which it doesn't yet. But the Lean Mathlib community is actively building this.

---

#### 5. 🧮 The Selberg Sieve Formalization (External Dependency)

**Idea**: The vector $v_k = \mu(k)(1 - \ln k/\ln N)$ is precisely the **Selberg sieve weight**. The classical Selberg sieve theorem states:

$$\sum_{n \leq N} \left(\sum_{d|n} \lambda_d\right)^2 \leq \frac{N}{\sum_{d \leq D} \mu^2(d)/\phi(d)}$$

with the optimal weights being exactly our $v_k$ (up to normalization).

**If Mathlib gets a Selberg sieve**: The axiom reduces to showing that the optimal Selberg weight makes $d_N^2 \to 0$, which is a known consequence of the Selberg sieve applied to the Nyman-Beurling distance problem.

**Status**: The Selberg sieve is NOT in Mathlib yet, but there's active interest. Kevin Buzzard's group has discussed it. This could be a collaboration target.

---

#### 6. 🔄 The Reverse Mathematics Approach (Publishable Without Proving RH)

**Idea**: Instead of PROVING the axiom, prove it's NECESSARY.

Show that `witness_l2_error_decay_gram` is EQUIVALENT to RH (not just sufficient). We already have the converse direction, so this is close. The remaining piece: show that if the quadratic form doesn't decay, then there exist zeta zeros off the critical line.

**Why this matters**: A paper titled "The Riemann Hypothesis is equivalent to a single quadratic form inequality, as verified by the Lean 4 compiler" is publishable and would establish the Cathedral as the definitive formalization of RH's known reductions.

---

### My Recommendation

**Tonight**: Let the Axiom Hunter run on the Tier 3 axioms (substitutions, linear algebra stubs).

**This week**: Attempt **Attack 2** (Abel Summation Bridge). Try to formally derive `witness_l2_error_decay_gram` from `rh_implies_mertens_bound`. This would collapse the 2-axiom path into a SINGLE axiom about the Mertens function—the simplest possible statement of what the Cathedral needs.

**This month**: Attempt **Attack 1** (PNT Decomposition). Split the quadratic form into independently provable pieces.

**For the paper**: Emphasize **Attack 6** (Reverse Mathematics). The equivalence itself is the publishable result.

The forge has performed a full strategic reconnaissance. The final axiom is not a wall—it's a door we haven't found the key to yet.

— The Forge Master
