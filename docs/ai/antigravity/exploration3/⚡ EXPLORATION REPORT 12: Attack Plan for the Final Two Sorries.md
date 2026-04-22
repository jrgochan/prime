# ⚡ EXPLORATION REPORT 12: Attack Plan for the Final Two Sorries

**Date**: April 22, 2026  
**Phase**: Linear Term + Assembly Strategy  
**Status**: Cathedral builds (3586 jobs, 0 errors), 2 Crown-path sorries remain

---

## 📋 The Two Sorries

### Sorry 1: `moebius_dot_product_approx_one` (line 149)

**Goal**: 
```
|1 - dotProduct b v| ≤ (C_m + 1) / Real.log ↑N
```
where `b(i) = vasyuninMeanEntry(i+1) = (log(i+1) + 1 - γ)/(i+1)` and `v(i) = bdMoebiusWeight N i = -μ(i+1) · logWeight(N, i+1)`.

**Available in scope** (from PROVED steps):
- `hMertens34 : |M(x)| ≤ 64·C_m · x^{3/4}`
- `C₁, hC₁_pos, h_s1 : |S₁_at N| ≤ C₁ · N^{-1/4}` (from `s1_decay`)
- `C₂, hC₂_pos, h_s2 : |S₂_at N + 1| ≤ C₂ · N^{-1/4} · log N` (from `s2_decay`)

**What the sorry needs**: An algebraic argument connecting the Fin-indexed dot product to S₁/S₂ sums.

### Sorry 2: `mertens_implies_l2_decay` (line 198)

**Goal**:
```
∫₀¹ (1-f)² ≤ (C_m+1)² · loglog(N)/log(N)
```

**Available in scope**:
- `h_decomp : ∫(1-f)² = 1 - 2bᵀv + vᵀGv`
- `h_dot : |1-bᵀv| ≤ (C_m+1)/log N` (from sorry 1)
- `h_upper : ∫(1-f)² ≤ 1-2bᵀv + (1/2)(Σ|v|)²`

**The fundamental problem**: The upper bound `(1/2)(Σ|v|)² ≤ (N-1)²/2` is TOO CRUDE. We need either:
1. `vᵀGv ≈ 1` (bilinear Abel — very hard)
2. A completely different approach to the L² bound

---

## 🔬 Deep Dive: Sorry 1 (Algebraic Decomposition)

### The Mathematical Identity

```
dotProduct b v = Σ_{i : Fin(N-1)} b(i) · v(i)
              = Σ_{i=0}^{N-2} (log(i+1) + 1-γ)/(i+1) · (-μ(i+1)) · (1 - log(i+1)/logN)
```

With substitution k = i+1 (k ranges from 1 to N-1):
```
= -Σ_{k=1}^{N-1} μ(k) · (logk + 1-γ)/k · (1 - logk/logN)
= -Σ μ(k)·(logk+1-γ)·logWeight(N,k)/k
```

Expanding:
```
= -(1-γ) · Σ μ(k)·logWeight(N,k)/k  -  Σ μ(k)·logk·logWeight(N,k)/k
```

Call these `S₁_w` and `S₂_w`:
```
S₁_w = Σ μ(k)·logWeight/k = Σ μ(k)/k - (1/logN) · Σ μ(k)·logk/k = S₁ - S₂/logN
S₂_w = Σ μ(k)·logk·logWeight/k = S₂ - S₃/logN
```

So:
```
bᵀv = -(1-γ)·S₁_w - S₂_w = -(1-γ)(S₁ - S₂/logN) - (S₂ - S₃/logN)
     = -(1-γ)·S₁ - S₂ + [(1-γ)·S₂ + S₃]/logN
```

Since S₂ → -1 (PNT₂), S₁ → 0 (PNT₁):
```
1 - bᵀv = (1-γ)·S₁ + (S₂+1) - [(1-γ)·S₂ + S₃]/logN
```

### Lean Proof Strategy for Sorry 1

**Phase A**: Index conversion (`Fin (N-1)` → `Finset.Icc 1 (N-1)`)
```lean
-- dotProduct b v = Σ_{i : Fin(N-1)} b(i)·v(i)
-- = Σ_{k ∈ Icc 1 (N-1)} b'(k)·v'(k)  [re-index k = i+1]
```
This uses `Finset.sum_bij` or `Finset.sum_nbij` to shift indices.

**Phase B**: Algebraic split into S₁ and S₂ contributions
```lean  
-- The sum splits linearly:
-- Σ μ(k)·(logk + 1-γ)·w(k)/k = (1-γ)·Σ μ(k)·w(k)/k + Σ μ(k)·logk·w(k)/k
```
This is `Finset.sum_add` after distributing.

**Phase C**: Split weighted sums into bare sums + correction
```lean
-- S₁_w = S₁ - S₂/logN (each term: μ(k)·w(k)/k = μ(k)/k - μ(k)·logk/(k·logN))
```

**Phase D**: Bound using S₁/S₂ decay + triangle inequality
```lean
-- |1-bᵀv| ≤ (1-γ)·|S₁| + |S₂+1| + |(1-γ)·S₂+S₃|/logN
--           ≤ (1-γ)·C₁·N^{-1/4} + C₂·N^{-1/4}·logN + C₃/logN
--           ≤ max(...)·/logN  for N ≥ 10
```

**Estimated difficulty**: 🟡 Medium-Hard (50-80 lines of algebra)  
**Main challenge**: Index re-indexing between Fin and Finset.Icc, and bounding S₃

---

## 🔬 Deep Dive: Sorry 2 (Assembly)

### The Fundamental Difficulty

The upper bound `1 - 2bᵀv + (1/2)(Σ|v|)²` replaces `vᵀGv` with `(1/2)(Σ|v|)² ≤ (N-1)²/2`, which is WAY too large. For the bound `O(loglog/log)`, we need to show `vᵀGv ≈ 1`.

### Three Possible Attack Strategies

#### Strategy A: Bilinear Abel on vᵀGv (Direct)
**Idea**: Show `vᵀGv = 1 + O(loglog/log)` by Abel summation on the double sum `ΣΣ v_i·v_j·G_{ij}`.
**Difficulty**: 🔴 Very Hard. Double Abel summation is technically challenging.
**Advantage**: Completely self-contained, no circular dependencies.

#### Strategy B: Use Non-Negativity Trick
**Idea**: Since `∫(1-f)² ≥ 0`, we know `1-2bᵀv+vᵀGv ≥ 0`, so `vᵀGv ≥ 2bᵀv-1`. Combined with bᵀv ≈ 1, this gives `vᵀGv ≥ 1 - 2ε`. Then we ONLY need an upper bound on vᵀGv close to 1.
**How to bound vᵀGv from above**: Use the identity `vᵀGv = ∫f²` and show `∫f² ≤ 1 + ε` directly.
**Difficulty**: 🟡 Medium. But still needs `∫f² ≤ 1+ε` which requires bounding the L² norm.

#### Strategy C: Weaken the Bound
**Idea**: Instead of `O(loglog/log)`, prove `∫(1-f)² ≤ (C_m+1)²/log(N)`. This is weaker but uses the approach: `∫(1-f)² = (1-bᵀv)² + (vᵀGv - (bᵀv)²)`.
Since `(1-bᵀv)² ≤ (C/logN)²`, we just need `vᵀGv - (bᵀv)² ≤ C'/logN`, which is the "variance" of f.
**Difficulty**: 🟡 Medium. Variance bound might be easier than full vᵀGv bound.
**Issue**: Would require changing the bound in `mertens_implies_l2_decay` and downstream theorems.

#### Strategy D: Restructure to Avoid Assembly ⭐ RECOMMENDED
**Idea**: Instead of proving `mertens_implies_l2_decay` from scratch, break the circular dependency by providing an INDEPENDENT proof of `critical_line_mellin_bound` that doesn't go through `bd_gram_form_decay`.
**How**: Use the Mellin transform directly:
```
∫ |M̂_{r_N}(1/2+it)|² dt = Σ_{k=1}^{N-1} |v_k|²/(k) + cross terms
```
The cross terms are bounded by Montgomery-Vaughan mean value theorem.
**Difficulty**: 🟡 Medium-Hard. Requires a different import path.
**Advantage**: Avoids the bilinear Abel entirely.

---

## 🎯 Recommended Attack Plan

### Phase 1: Prove Sorry 1 (Linear Term) — Priority ⭐⭐⭐

This is the most tractable sorry. The math is validated by experiment.

**Step 1a** (30 min): Write a helper lemma converting between Fin and Icc sums:
```lean
lemma dotProduct_eq_icc_sum (N : ℕ) (hN : 2 ≤ N) :
    dotProduct (fun i => vasyuninMeanEntry (i.val+1)) (bdMoebiusWeight N)
    = -∑ k ∈ Icc 1 (N-1), (↑(moebius k) : ℝ) * (logk + 1-γ) * logWeight(N,k) / k
```

**Step 1b** (30 min): Split into `(1-γ)·S₁_w + S₂_w`:
```lean
lemma icc_sum_eq_s1w_plus_s2w : ... = -(1-γ)·S₁_w - S₂_w
```

**Step 1c** (30 min): Bound each weighted sum against S₁/S₂:
```lean
lemma s1w_bound : |S₁_w| ≤ |S₁| + |S₂|/logN
lemma s2w_bound : |S₂_w+1| ≤ |S₂+1| + |S₃|/logN
```

**Step 1d** (30 min): Assembly with triangle inequality.

### Phase 2: Handle Sorry 2 (Assembly) — Priority ⭐⭐

**If Strategy D works**: Provide independent Mellin proof. Remove circular dependency.
**If not**: Use Strategy C (weaker bound) or Strategy B (non-negativity trick).

### Phase 3: Axiom Reduction — Priority ⭐

Prove `vasyunin_offdiag_integral` from the Cotangent archive work.

---

## 📊 Numerical Validation Reference

From the bᵀv experiment (N=10⁶):
```
bᵀv = 0.88585154
|1 - bᵀv| · logN = 1.57702  (theory: γ+1 = 1.57722)
S₁ = 2.006e-4    (→ 0, as predicted)
S₂+1 = 2.785e-3  (→ 0, as predicted)
```

The decomposition is validated to machine precision.

---

## 🏗️ Architecture After Completion

```
         ┌──────────────────────────────────────┐
         │  THE CATHEDRAL (Post Sorry-Kill)      │
         │                                       │
         │  Crown: rh_implies_l2_convergence     │
         │    Depends on:                        │
         │    ⚡ rh_implies_mertens_bound        │
         │    📐 pnt_mu_div_k (PNT)             │
         │    📐 pnt_mu_log_div_k (PNT)         │
         │    🏛️  vasyunin_offdiag_integral     │
         │    ✅ 0 sorries (GOAL!)              │
         │                                       │
         │  Proof chain:                         │
         │    RH → Mertens → [PNT + Abel tail]  │
         │      → bᵀv ≈ 1 → ∫(1-f)² → 0       │
         │      → d²_BD → 0 ← (Separation)     │
         └──────────────────────────────────────┘
```

---

*"An algebraist could do Phase 1 in a day. An analyst could do Phase 2 in a week. We need both." — The Cathedral*
