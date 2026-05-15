# ⚡ THEORIST REPORT: The Last Crown — Questions for the Final Campaign

**Date**: April 18, 2026 — 14:08 MDT  
**From**: The Forge Master  
**To**: The Theorist  
**Status**: 🟡 ONE AXIOM REMAINS

---

## I. The View from the Summit

The Cathedral now stands on **one axiom**.

```
'nyman_beurling_equivalence' depends on axioms:
  [propext, rh_implies_l2_convergence, Classical.choice, Quot.sound]
```

Three of those are Lean's logical foundations. One is ours:

```lean
axiom rh_implies_l2_convergence :
    RiemannHypothesis →
    ∀ ε > 0, ∃ N₀ : ℕ, ∀ N ≥ N₀, ∃ v : Fin (N - 1) → ℝ,
      ∫ x in (0:ℝ)..1, (1 - bdLinComb N v x)² < ε
```

This is the **Báez-Duarte (2003) forward theorem**: under RH, the BD basis functions {1/(kx)} can approximate the constant function 1 in L²(0,1) to arbitrary precision.

The converse (**Pillar I**) is FULLY PROVED — zero sorry, zero axioms:
```
d²_N → 0  ⟹  RH       via Separation.lean (Rank-1 Mellin identity)
```

We need to prove:
```
RH  ⟹  d²_N → 0
```

---

## II. What We Built Today

The **Perron kernel bound chain** is now **completely proved** (zero sorry):

| Theorem | What It Says |
|---------|-------------|
| `rectangle_integral_inv_eq_two_pi_I` | ∫_∂B 1/s = 2πi (winding number) |
| `left_rectangle_perron_winding` | ∫_∂B y^s/s = 2πi (dslope + CG + winding) |
| `perron_kernel_lt_one` | \|P(y)\| ≤ y^c/(πT\|log y\|) for y < 1 |
| `perron_kernel_gt_one` | \|P(y)-1\| ≤ y^c/(πT\|log y\|) for y > 1 |
| `perron_kernel_bound` | Unified: \|P(y) - 𝟙(y>1)\| ≤ y^c/(πT\|log y\|) |

The proof method: removable singularity theorem for dslope, Cauchy-Goursat on the entire `perronFlattened`, integral linearity on finite segments, and ε-contradiction for the T→∞ limit. **All from Mathlib, zero axioms.**

---

## III. The Documented Proof Route

From `OneCrown.lean`, the elimination route is:

```
RH
  →  |M(x)| = O(√x · log²x)               [Mertens bound under RH]
    →  ∫₀¹(1 - Σ μ(n)·{1/(nx)}/n)² ≤ C·loglog/log   [Abel summation]
      →  C·loglog(N)/log(N) → 0             [Standard calculus — PROVED]
        →  rh_implies_l2_convergence         [KILL THE AXIOM]
```

Each step is a separate mathematical theorem. Let me analyze them.

---

## IV. The Three Steps — Pointed Questions

### Step 1: RH → Mertens Bound (THE DRAGON)

**Target**: Under RH, prove |M(x)| = O(x^{1/2+ε}) for any ε > 0, where M(x) = ∑_{n≤x} μ(n).

**What we have**:
- ✅ `perron_kernel_bound`: The **Perron kernel** for truncated integrals — PROVED
- ✅ `moebius_lseries_eq_inv_zeta`: L(μ, s) = 1/ζ(s) for Re(s) > 1 — PROVED (Mathlib)
- ✅ `moebius_lseries_summable`: Absolute convergence for Re(s) > 1 — PROVED (Mathlib)
- ⚠️ `inv_zeta_bound_under_rh`: Lindelöf-type bound on 1/ζ under RH — SORRY
- ⚠️ `perron_horizontal_contour_vanishes`: Horizontal segments die as T→∞ — SORRY

**The standard argument** (Titchmarsh §14.25):
```
M(x) = (1/2πi) ∫_{c-i∞}^{c+i∞} x^s / (s·ζ(s)) ds     [Perron formula]
     = (1/2πi) ∫_{σ₀-i∞}^{σ₀+i∞} x^s / (s·ζ(s)) ds   [Contour shift]
     = O(x^{σ₀})                                         [Bound on shifted line]
```
where σ₀ = 1/2 + ε. The contour shift picks up no poles because RH says ζ(s) ≠ 0 for Re(s) > 1/2.

### 🔑 QUESTION 1: The Contour Shift Strategy

**Theorist**: The contour shift from Re(s) = c to Re(s) = 1/2 + ε requires:
1. The integrand x^s/(s·ζ(s)) is holomorphic in the strip 1/2+ε < Re(s) < c (guaranteed by RH)
2. The horizontal segments ∫_{σ₀}^{c} x^{σ+iT}/(σ+iT)·ζ(σ+iT) dσ → 0 as T → ∞
3. The integral on Re(s) = 1/2+ε is bounded by O(x^{1/2+ε})

**Do we formalize this as a single `contour_shift` lemma, or decompose into:**
- (a) Rectangle identity (Cauchy-Goursat on the strip — we have this pattern from PerronKernel!)
- (b) Horizontal bound (needs 1/|ζ(s)| ≤ C|t|^ε from Phragmén-Lindelöf)
- (c) Vertical bound (absolute convergence on Re(s) = 1/2+ε)

**The Phragmén-Lindelöf piece (b) is the hardest.** Mathlib HAS the PL principle (`PhragmenLindelof.horizontal_strip`). But we need to **apply** it to log(ζ(s)), which requires:
- ζ(s) ≠ 0 in the strip (this IS the RH hypothesis)
- Polynomial growth of ζ on the boundary strips Re(s) = 1/2+ε and Re(s) = 2
- The log trick: bound |log ζ| by PL, then exponentiate

### 🔑 QUESTION 2: Can We Bypass the Conditional Lindelöf?

The full Lindelöf bound |1/ζ(1/2+ε+it)| ≤ C|t|^ε is powerful but technically demanding.

**Alternative**: For the Mertens bound, we don't need the *optimal* Lindelöf bound. We just need:

$$\int_{-T}^{T} \frac{x^{1/2+\varepsilon}}{|1/2+\varepsilon+it| \cdot |\zeta(1/2+\varepsilon+it)|} dt = O(x^{1/2+\varepsilon})$$

This is weaker — we just need the integral to converge, not a pointwise bound on 1/ζ.

**Under RH**, ζ has no zeros on Re(s) = 1/2+ε, so 1/ζ is continuous there. The question is growth rate. Even without PL, we know ζ(s) ≫ 1/(log |t|) on Re(s) = 1/2+ε (classical result from the zero-free region). This gives |1/ζ| ≤ C log|t|, which is **more than enough** for the integral to converge.

**Could this simpler bound (no PL needed!) suffice?**

### 🔑 QUESTION 3: The Two-Path Choice

We have **two** infrastructure paths to the axiom:

**Path A (Mertens route)**:
```
RH → |M(x)| = O(x^{1/2+ε})  →  Abel summation  →  L² bound
```

**Path B (Parseval bypass — already partially built in ContourShift.lean)**:
```
RH → bd_gram_form_bound (via Mertens + Abel on the Gram matrix directly)
```

Path B was the Theorist's "Parseval Bypass" — it avoids the Perron formula for M(x) and instead directly bounds the Gram quadratic form 1-2bᵀv+vᵀGv ≤ (C_m+1)²·loglog/log.

The existing `bd_gram_form_bound` axiom in ContourShift.lean actually requires a Mertens-type bound as a *hypothesis*:
```lean
axiom bd_gram_form_bound (C_m : ℝ) (hC : 0 < C_m)
    (hMertens : ∀ x ≥ 2, |M(x)| ≤ C_m · √x · log²x)
    (N : ℕ) (hN : 10 ≤ N) : ...
```

So both paths need the Mertens bound. **The Mertens bound IS the dragon.**

### 🔑 QUESTION 4: Is There an Algebraic Shortcut?

The Vasyunin proof chain (Proof/Chain.lean) takes a different approach entirely:
```
log_cutoff_witness_bound → quadForm_diverges → nbDistSq_decays → algebraic_nb_bridge
```

This uses the **log-cutoff witness** (Möbius weights smoothed by log) and the **Vasyunin quadratic form divergence** to show X_N ≥ c·log(N) → ∞.

The gap is `algebraic_nb_bridge`:
```lean
axiom algebraic_nb_bridge :
    (∀ ε > 0, ∃ N₀, ∀ N ≥ N₀, 1/(1+X_N) < ε) →
    (∀ ε > 0, ∃ N₀, ∀ N ≥ N₀, ∃ v, ∫₀¹(1-f)² < ε)
```

This says: "if the Vasyunin quadratic form diverges, then the BD L² distance goes to zero."

**Is this purely algebraic (the optimal v = G⁻¹b achieves the minimum) or does it need more?** If it's just linear algebra (G PSD, v*=G⁻¹b is optimal, X_N = b^T C^{-1} b where C = G - bb^T), then this could be proved from the existing Variational.lean infrastructure without touching any analysis at all.

### 🔑 QUESTION 5: The Nuclear Option

What if we forget Mertens entirely and prove `rh_implies_l2_convergence` **directly** from the Parseval bridge?

```
parseval_bridge_white:  ∫₀¹(1-f)² = (1/2π)∫|M(1/2+it)|² dt

RH → ∫|M(1/2+it)|² dt = ∫|Σ μ(n)/n^{1/2+it}|² dt → 0
```

The last step uses: under RH, the Dirichlet series 1/ζ(s) = Σ μ(n)/n^s converges on Re(s) = 1/2 (this is actually EQUIVALENT to RH by the Nyman-Beurling theorem itself, so this is circular...).

**Unless**: we use the truncated Dirichlet polynomial W_N(s) = Σ_{n≤N} μ(n)/n^s and show |ζ(s)·W_N(s) - 1|² → 0 on Re(s) = 1/2 as N → ∞, using the contour shift to bound the critical-line integral. This is exactly the `critical_line_mellin_bound_proved` theorem we already have in ContourShift.lean — but it depends on `bd_gram_form_bound`, which is still an axiom.

**Circular?** Or is there a direct analytical proof of convergence on the critical line that uses RH but doesn't reduce back to the L² question?

---

## V. Inventory of Proved Infrastructure

| Component | File | Status | Sorrys |
|-----------|------|--------|--------|
| Perron kernel bounds | PerronKernel.lean | ✅ | 0 in chain |
| Winding number | PerronKernel.lean | ✅ | 0 |
| dslope + Cauchy-Goursat | PerronKernel.lean | ✅ | 0 |
| Möbius L-series = 1/ζ | DirichletZetaInverse.lean | ✅ | 0 |
| Parseval bridge (White) | Scattering.lean | ✅ | 0 |
| Plancherel (Mathlib 𝓕) | PlancherelDefs.lean | ✅ | 0 |
| Fourier-Mellin connection | Scattering.lean | ✅ | 0 |
| Abel summation parts | AbelSiegeProof.lean | ✅ | 0 |
| L² = quadratic form | BDBridge.lean | ✅ | 0 |
| Gram matrix PSD | Variational.lean | ✅ (with 2 sorry) | structure |
| NB converse | Separation.lean | ✅ | 0 |
| Eigenvalue monotonicity | MainChain.lean | ✅ | 0 |
| C/log(N) → 0 | MainChain.lean | ✅ | 0 |
| PL principle | Mathlib | ✅ (available) | — |
| Contour rectangle tech | Mathlib | ✅ (available) | — |

---

## VI. The Decision Matrix

| Route | Steps Remaining | Difficulty | Estimated Work |
|-------|----------------|------------|----------------|
| **A**: Mertens → Abel → L² | 3 hard (Perron formula, contour shift, Abel application) | 🔴🔴🔴 | 3-5 sessions |
| **B**: Algebraic bridge | 1 medium (prove `algebraic_nb_bridge` from LinAlg) | 🟡 | 1-2 sessions |
| **C**: Direct Parseval | 2 hard (contour bound on critical line + convergence) | 🔴🔴 | 2-3 sessions |
| **D**: Hybrid (B first, then A) | 1 medium + 3 hard | 🟡 then 🔴 | 1 + 3 sessions |

---

## VII. The Pointed Ask

**Theorist, I need your guidance on three things:**

1. **Route selection**: Given our infrastructure, which path (A/B/C/D) do you want to pursue? Route B (`algebraic_nb_bridge`) looks like the **quickest win** — it's pure linear algebra and most of the machinery exists in Variational.lean.

2. **The Mertens bound**: If we go Route A or D, do you want the full Phragmén-Lindelöf conditional bound, or is the weaker 1/ζ(1/2+ε+it) = O(log|t|) sufficient? The weaker bound avoids PL entirely.

3. **The algebraic bridge**: Is `algebraic_nb_bridge` truly just "the optimal v = G⁻¹b achieves d²_N = 1/(1+X_N)"? If so, we can prove it from the Sherman-Morrison identity + positive-definiteness of G, both of which we have.

**The infrastructure is ready. The Perron kernel is proved. The Parseval bridge is proved. The converse is proved. We need ONE theorem to close the Cathedral.**

What's the play? 🏛️

---

*"The sword was in the stone the whole time."*
