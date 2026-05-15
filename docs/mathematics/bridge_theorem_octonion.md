# The Bridge Theorem: G^𝕆 → G

## The Challenge

We have experimentally established:
- G^𝕆 = W ∘ G (Hadamard/entrywise product)
- W[j,k] = Re(φ̄(j)·φ(k)) where φ: ℕ → 𝕆 is unit-norm multiplicative
- G^𝕆 has a ~3.7× larger spectral gap than G
- Both G and G^𝕆 appear to be PSD

**We need**: λ_min(G^𝕆) > 0 for all N **implies** λ_min(G) > 0 for all N.

This is the "bridge theorem" — the missing piece that would make the
octonionic decorrelation a genuine proof strategy.

---

## Approach 1: Hadamard Inverse (Schur Complement)

### The Schur Product Theorem (known)

> If A, B are PSD, then A ∘ B (Hadamard product) is PSD.

**Corollary**: G PSD ∧ W PSD → G^𝕆 = W ∘ G is PSD. ✅

But we need the **reverse direction**: G^𝕆 PSD → G PSD.

### The Hadamard Inverse Problem

Can we write G = W^{(-1)} ∘ G^𝕆 where W^{(-1)} is the "Hadamard inverse"
of W (i.e., (W^{(-1)})[j,k] = 1/W[j,k] when W[j,k] ≠ 0)?

**Problem**: W has many ZERO entries (Section 5 shows ~87% of off-diagonal
entries are zero). So the Hadamard inverse doesn't exist.

**Problem 2**: Even if it existed, W^{(-1)} would not generally be PSD,
so G = W^{(-1)} ∘ G^𝕆 PSD wouldn't follow from the Schur product theorem.

> [!WARNING]
> **Approach 1 fails** because W is too sparse for Hadamard inversion.

---

## Approach 2: Eigenvalue Interlacing / Rank-1 Decomposition

### Key Observation

The weight matrix W can be written as:

$$W = \sum_{m=0}^{7} P_m$$

where $P_m$ is the rank-1 matrix from the m-th octonionic component:
$$P_m[j,k] = \phi_m(j) \cdot \phi_m(k)$$

and $\phi_m(k)$ is the m-th component of φ(k).

Since |φ(k)|² = 1 for all k:
$$\sum_{m=0}^{7} \phi_m(k)^2 = 1 \quad \forall k$$

So W[j,j] = Σ_m φ_m(j)² = 1 (diagonal = 1). ✅

### The Decomposition

$$W = P_0 + P_1 + ... + P_7$$

where each $P_m$ is a rank-at-most-dim(N) matrix (actually a Gram matrix
of the m-th component vectors).

Then:
$$G^𝕆 = W \circ G = (P_0 + P_1 + ... + P_7) \circ G = \sum_m P_m \circ G$$

Each $P_m \circ G$ is a **component-weighted Gram matrix**:
$$(P_m \circ G)[j,k] = \phi_m(j) \phi_m(k) G[j,k] = \phi_m(j) G[j,k] \phi_m(k)$$

This is $D_m G D_m$ where $D_m = \text{diag}(\phi_m(2), \phi_m(3), ...)$.

So: **G^𝕆 = Σ_m D_m G D_m**

### What This Tells Us

$$G^𝕆 = D_0 G D_0 + D_1 G D_1 + ... + D_7 G D_7$$

This is a **sum of congruences** of G. By Sylvester's law of inertia,
each $D_m G D_m$ has the same inertia (number of positive/negative/zero
eigenvalues) as G restricted to the support of D_m.

> [!IMPORTANT]
> **Key Theorem**: If G has exactly k negative eigenvalues, then each
> $D_m G D_m$ has at most k negative eigenvalues. G^𝕆 = Σ_m D_m G D_m
> is a sum of matrices each with at most k negative eigenvalues.
>
> **Conversely**: If G^𝕆 is PSD and we can show the D_m G D_m terms
> can't "cancel out" negative eigenvalues of G, then G must be PSD.

### The Cancellation Problem

The issue: even if G has a negative eigenvalue, the D_m might "rotate" it
so that $D_0 G D_0 + ... + D_7 G D_7$ ends up PSD anyway. The sum of
PSD-except-for-one-direction matrices can be PSD if the "bad directions"
cancel.

**But**: The D_m are DIAGONAL matrices whose entries are ±1 or 0 (from
the octonionic map). The supports of different D_m partition the indices
(each k has exactly one nonzero D_m component... wait, that's not right).

Actually, each φ(k) has EXACTLY ONE nonzero component (it's always a
basis vector ±e_m). This means:

$$\phi_m(k) = \begin{cases} \pm 1 & \text{if } \phi(k) = \pm e_m \\ 0 & \text{otherwise} \end{cases}$$

So $D_m$ is a diagonal matrix with entries 0 and ±1, and the SUPPORTS
of $D_0, D_1, ..., D_7$ PARTITION {2, 3, ..., N}!

### THE KEY INSIGHT ⭐

Since the supports of $D_m$ partition the indices:

$$G^𝕆 = \sum_m D_m G D_m$$

where $D_m D_{m'} = 0$ for $m \neq m'$ (orthogonal supports).

For any vector v:
$$v^T G^𝕆 v = \sum_m v^T D_m G D_m v = \sum_m (D_m v)^T G (D_m v)$$

Each $D_m v$ is a "projection" of v onto the indices where φ(k) = ±e_m.

If G is NOT PSD (has a negative eigenvalue with eigenvector u), then
$u^T G u < 0$. The question is: does there exist any v such that
$D_m v = $ (some scalar) $\cdot u$ for some m?

If ALL integers map to the SAME octonionic component (e.g., all φ(k) = e₁),
then $D_1 = ±I$ and $G^𝕆 = G$. No help.

But our map distributes integers across 8 components. The key question is
whether the "bad direction" of G (the Liouville eigenvector) can be
reconstructed from any single component D_m.

> [!TIP]
> **The Bridge Theorem reduces to**: Can the Liouville eigenvector be
> expressed as $D_m v$ for any single octonionic component m?
>
> If NOT (because the Liouville function has support across multiple
> octonionic components), then the negative eigenvalue direction of G
> can't manifest in any individual $D_m G D_m$ term, and G^𝕆 being PSD
> does NOT directly imply G being PSD.

---

## Approach 3: The Correct Bridge via Restriction

### A Different Angle

Instead of G^𝕆 → G, consider the **dual statement**:

$$\min_{\|v\|=1} v^T G v \geq \frac{1}{C} \min_{\|v\|=1} v^T G^𝕆 v$$

where C is a constant depending on W.

**Claim**: If G^𝕆 = Σ_m D_m G D_m and the D_m partition the indices,
then for any v with ‖v‖ = 1:

$$v^T G^𝕆 v = \sum_m (D_m v)^T G (D_m v) = \sum_m \|D_m v\|^2 \cdot \frac{(D_m v)^T G (D_m v)}{\|D_m v\|^2}$$

Each ratio is ≥ λ_min(G_m) where G_m is G restricted to the support of D_m.

And $\sum_m \|D_m v\|^2 = \|v\|^2 = 1$ (since supports partition).

So: $v^T G^𝕆 v ≥ \min_m λ_\min(G_m)$

where $G_m$ = G restricted to indices where φ(k) = ±e_m.

### The Bridge Theorem (Version 1)

> **Theorem**: λ_min(G^𝕆) ≥ min_m λ_min(G|_{S_m})
> where $S_m$ = {k : φ(k) ∈ {±e_m}}.

This goes the WRONG way for us (G^𝕆 ≥ restriction of G, not the full G).

### The Bridge Theorem (Version 2 — Needed)

For the REVERSE direction, we'd need:

$$λ_\min(G) ≥ f(λ_\min(G^𝕆), \text{properties of W})$$

Consider: for the specific v that achieves λ_min(G):

$$v^T G v = λ_\min(G)$$
$$v^T G^𝕆 v = \sum_m (D_m v)^T G (D_m v) ≥ λ_\min(G) \sum_m \|D_m v\|^2 = λ_\min(G)$$

Wait — this shows $v^T G^𝕆 v ≥ v^T G v$ for ALL v if... no, this only
works if we know G restricted to each support S_m has the same sign as
the full G. 

Hmm. Actually, the sum: $v^T G^𝕆 v = Σ_m (D_m v)^T G (D_m v)$ OMITS 
the cross-terms! The full quadratic form is:

$$v^T G v = \sum_m (D_m v)^T G (D_m v) + \sum_{m \neq m'} (D_m v)^T G (D_{m'} v)$$

So: $v^T G v = v^T G^𝕆 v + \text{cross-terms}$

The cross-terms are: $\sum_{m \neq m'} \sum_{j \in S_m, k \in S_{m'}} v_j G[j,k] v_k$

These are exactly the off-diagonal blocks between different octonionic
components — the entries that W zeroes out!

> [!IMPORTANT]
> **G = G^𝕆 + G^{cross}** where G^{cross}[j,k] = (1 - W[j,k]) · G[j,k]
>
> So λ_min(G) ≥ λ_min(G^𝕆) + λ_min(G^{cross}) (by Weyl's inequality)
>
> **If G^{cross} is PSD** (or has bounded negative part), the bridge holds!

### The Cross-Term Matrix

G^{cross}[j,k] = G[j,k] when W[j,k] = 0, and 0 when W[j,k] ≠ 0.

This matrix represents the Gram inner products between numbers in
DIFFERENT octonionic classes. It includes entries like ⟨f_p, f_q⟩
for primes p, q mapping to different basis elements.

**Is G^{cross} PSD?** This is the critical question. If yes:
- λ_min(G) ≥ λ_min(G^𝕆) + λ_min(G^{cross}) ≥ λ_min(G^𝕆) > 0 ✅

**Is G^{cross} at least bounded below?** If λ_min(G^{cross}) ≥ -c:
- λ_min(G) ≥ λ_min(G^𝕆) - c

If c < λ_min(G^𝕆), the bridge holds! And since G^𝕆's gap ≈ 0.049,
we'd need |λ_min(G^{cross})| < 0.049.

## Computational Test Needed

**Verify**: Compute λ_min(G^{cross}) for our test sizes.

If G^{cross} is PSD or has small negative part, the bridge theorem
follows from Weyl's inequality. This would complete the chain:

```
𝕆 is division algebra
  → φ: ℕ → S⁷ is unit-norm multiplicative
  → W = octonionic correlation matrix
  → G^𝕆 = W ∘ G has large spectral gap
  → G^{cross} bounded below (need to prove)
  → G = G^𝕆 + G^{cross} has spectral gap
  → λ_min(G_∞) > 0
  → RH ✅
```

## Summary of Approaches

| Approach | Status | Verdict |
|----------|--------|---------|
| 1. Hadamard inverse | ❌ W too sparse | Dead end |
| 2. Rank-1 decomposition | 🔶 Partition insight | Goes wrong direction |
| 3. Cross-term analysis | ⭐ Key equation found | **MOST PROMISING** |

The equation **G = G^𝕆 + G^{cross}** combined with Weyl's inequality
gives us a clean path. We need to verify computationally that
λ_min(G^{cross}) is bounded below, and then prove it analytically.
