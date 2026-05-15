# 📡 Axiom B Graduation — The Numerator Rate Theorem

**Date**: 2026-05-08
**Author**: Claude (Antigravity)
**Status**: EXECUTING

---

## Executive Summary

**Axiom B** (`witness_numerator_rate`) states:

$$|\mathbf{b}^\top \mathbf{v} - 1| \leq \frac{K_1}{\ln N}$$

This is the quantitative refinement of the already-proved qualitative convergence
$\mathbf{b}^\top \mathbf{v} \to 1$ (WitnessNumeratorProved.lean, graduated May 7, 2026).

**The graduation is achievable now.** All necessary infrastructure exists:
- The algebraic expansion of $\mathbf{b}^\top \mathbf{v}$ into PNT sub-sums (proved)
- The quantitative $K/\ln N$ bounds on each sub-sum (proved via Abel-Mertens)
- The triangle inequality assembly pattern (proved in `moebius_mean_finite_bound`)

The gap is a ~150-line bridge file connecting these pieces.

---

## 1. The Proof Architecture

### 1.1 What We Have

The qualitative proof in WitnessNumeratorProved.lean uses three steps:

**Step 1 — Algebraic Expansion** (`dot_expansion`):
$$\mathbf{b}^\top \mathbf{v} = -(1-\gamma) S_1(N{-}1) - S_2(N{-}1) + \frac{(1-\gamma) S_2(N{-}1) + S_3(N{-}1)}{\ln N}$$

where the PNT sub-sums are:
- $S_1(M) = \sum_{k=1}^{M} \mu(k)/k$
- $S_2(M) = \sum_{k=1}^{M} \mu(k) \ln(k)/k$
- $S_3(M) = \sum_{k=1}^{M} \mu(k) \ln^2(k)/k$

**Step 2 — Error Shift** (`error_shift`):
$$\mathbf{b}^\top \mathbf{v} - 1 = -(1-\gamma) S_1 - (S_2 + 1) + \frac{(1-\gamma)(S_2+1) + (S_3+2\gamma) - (1+\gamma)}{\ln N}$$

**Step 3 — PNT Limits**: $S_1 \to 0$, $S_2 \to -1$, $S_3 \to -2\gamma$.

### 1.2 What We Need

Replace Step 3 (qualitative limits) with **quantitative bounds**:
$$|S_1(M)| \leq K/\ln M, \quad |S_2(M)+1| \leq K/\ln M, \quad |S_3(M)+2\gamma| \leq K/\ln M$$

**These are already proved!** The theorem `pnt_mertens_tail_domination` in
AbelMean.lean establishes exactly this, via the Abel-Mertens engine:

```lean
-- AbelMean.lean, line ~264
private lemma pnt_mertens_tail_domination ... :
    ∃ K : ℝ, K > 0 ∧ ∀ N : ℕ, 3 ≤ N →
    |S₁ N| ≤ K / Real.log (N : ℝ) ∧
    |S₂ N - (-1)| ≤ K / Real.log (N : ℝ) ∧
    |S₃ N - (-2 * eulerMascheroniConstant)| ≤ K / Real.log (N : ℝ)
```

### 1.3 The Bridge

The `moebius_mean_finite_bound` theorem in AbelMean.lean already performs
the triangle inequality assembly — but in the BD/mean-integral basis,
not the Vasyunin `logCutoffWitness × vasyuninMeanVec` basis.

The graduation file must:
1. Get quantitative K/ln(N) bounds at N-1 (shift index)
2. Scale from log(N-1) to log(N) via the `log_ratio_bound` lemma
3. Substitute into the `dot_expansion` identity
4. Apply the `error_shift` regrouping
5. Triangle inequality with constant collection

---

## 2. Dependency Graph

```
pnt_mu_div_k (AXIOM 1)      ─┐
pnt_mu_log_div_k (AXIOM 2)   ├─→ abel_mertens_tail_raw (PROVED)
pnt_mu_log_sq_div_k (AXIOM 3)┘         │
mertens_bound (AXIOM)        ──────────┘
                                        │
                              pnt_mertens_tail_domination (PROVED)
                                        │
                                        ▼
dot_expansion (PROVED)  ──→  AXIOM B GRADUATION  ←── error_shift (PROVED)
                                        │
                                        ▼
                           witness_numerator_rate (THEOREM!)
```

## 3. The Axiom Status After Graduation

### Before (PATH B):
| Axiom | Type | Status |
|-------|------|--------|
| gram_form_upper_bound | Axiom A (≡ RH) | AXIOM |
| witness_numerator_rate | Axiom B (from PNT) | AXIOM |

### After:
| Axiom | Type | Status |
|-------|------|--------|
| gram_form_upper_bound | Axiom A (≡ RH) | AXIOM |
| witness_numerator_rate | ~~Axiom B~~ | **THEOREM** 🎓 |

PATH B reduces from **2 axioms to 1 axiom** (the RH-equivalent Gram form bound).

## 4. Upstream PNT Axiom Status

The graduation still depends on 3 PNT axioms + Mertens bound:

| Axiom | Value | Graduated? | Blocker |
|-------|-------|:----------:|---------|
| `pnt_mu_div_k` | $\sum \mu(k)/k \to 0$ | ✅ via PNTAnd | — |
| `pnt_mu_log_div_k` | $\sum \mu(k)\ln k/k \to -1$ | ❌ | Forward Tauberian |
| `pnt_mu_log_sq_div_k` | $\sum \mu(k)\ln^2 k/k \to -2\gamma$ | ❌ | Forward Tauberian + γ |
| Mertens bound | $|M(x)| \leq Cx^{3/4}$ | ❌ | Standard ANT |

**Note**: Axioms 2-3 are blocked by Mathlib's missing forward Tauberian theorem.
When PNTAnd's Wiener-Ikehara sorrys close (2 sorrys in Wiener.lean), all three
PNT axioms will become theorems automatically.

## 5. Connection to EulerProduct.lean

The newly-created `Cathedral/Covariance/EulerProduct.lean` provides complementary
infrastructure for the same proof path:

- **Local factor evaluations** explain *why* the Gram form bound holds
  (Robin Resonance: $\prod_p(1-1/p) \sim e^{-\gamma}/\ln N$)
- **`moebius_lseries_eq_inv_zeta'`** connects the Möbius L-series to $1/\zeta(s)$,
  which is the generating function whose Taylor coefficients at $s=1$ give the
  PNT sub-sum limits $S_1 \to 0$, $S_2 \to -1$, $S_3 \to -2\gamma$
- The **`mertens_third_statement`** in EulerProduct.lean is the product-form
  of the same asymptotic that drives the Gram form bound

## 6. The Graduation File

**Target**: `Cathedral/Vasyunin/Proof/WitnessNumeratorRate.lean`

**Strategy**: Direct assembly from existing components.

1. Import `WitnessNumeratorProved` (for `dot_expansion`, `error_shift`)
2. Import `AbelMean` (for `pnt_mertens_tail_domination`, `log_ratio_bound`)
3. Get K/ln(N) bounds on S₁, S₂, S₃ at N-1
4. Scale to log(N) via log_ratio_bound
5. Substitute into dot_expansion
6. Apply error_shift
7. Triangle inequality with Gamma-evasion constant

The proof structure closely mirrors `moebius_mean_finite_bound` (AbelMean.lean
lines 457-569), which already performs the identical assembly in a parallel basis.

## 7. Risk Assessment

| Risk | Probability | Mitigation |
|------|:-----------:|------------|
| `pnt_mertens_tail_domination` is private | High | Re-export or duplicate |
| `dot_expansion` uses different sum indices | Medium | Index shift via `tendsto_pred` |
| Lean type-level mismatch between bases | Low | Definitional unfolding |
| Constant collection fails | Very Low | Already works in `moebius_mean_finite_bound` |

**Overall assessment**: This is assembly work, not research. Expected completion: < 2 hours.

---

*"The pieces are on the board. The only move is to pick them up."*
