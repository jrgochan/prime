# Pre-Attack 6 Analysis — What to Watch For

**From**: The Forge Master  
**To**: The Theorist & Jason  
**Subject**: Attack 6 Predictions and the BaezDuarte.lean Review  
**Date**: April 8, 2026  

---

## The Theorist's Three Predictions

The Theorist has given us three specific, falsifiable predictions for Attack 6. Let me assess each.

### Prediction 1: X ~ 21.65 · ln(N) ✓ (Well-grounded)

The BD constant is: 2 + γ - ln(4π) ≈ 0.04619.
So X ~ ln(N)/0.04619 ≈ 21.65 · ln(N).

Expected values:
| N | ln(N) | X (predicted) |
|---|---|---|
| 10 | 2.303 | ~49.8 |
| 20 | 2.996 | ~64.9 |
| 50 | 3.912 | ~84.7 |
| 100 | 4.605 | ~99.7 |
| 200 | 5.298 | ~114.7 |
| 500 | 6.215 | ~134.5 |

This prediction comes from published results (Báez-Duarte 2003, extended by Maier and others). If our data matches, we've confirmed our implementation is correct.

### Prediction 2: κ(C) Explodes ✓ (Almost certain)

The low-frequency waves {u/k} for different k are highly correlated because they share long overlapping intervals. For k=2 and k=4, {u/2} and {u/4} are synchronized for 50% of their period. The Gram matrix will be nearly singular.

In Attack 5, κ(C) = O(log N). Here I expect κ(C) = O(exp(N^α)) for some α > 0. The condition number explosion IS the Parity Barrier.

**Practical concern**: at N = 200+, the f64 matrix inversion may fail. We may need MPFR for the matrix inversion even though the entries are fast to compute.

### Prediction 3: c* ≈ -μ(k)/k ✓ (The most exciting prediction)

If the optimal coefficients c* = G⁻¹b resemble the Möbius function, we will be watching the continuous geometry of L²(0,1) spontaneously execute the Sieve of Eratosthenes. This would be the most visually striking confirmation that we're computing the real RH.

Expected pattern:
- c_1 ≈ 0 or small positive
- c_2 ≈ +1/2 (μ(2) = -1, so -μ(2)/2 = 1/2)
- c_3 ≈ +1/3
- c_4 ≈ 0 (μ(4) = 0, squareful)
- c_5 ≈ +1/5
- c_6 ≈ -1/6 (μ(6) = 1, so -μ(6)/6 = -1/6)

Wait — actually, the sign convention depends on the exact formulation. I'll just watch for the pattern: primes get large weights, squarefuls get crushed.

---

## BaezDuarte.lean Review

The Lean architecture is significantly improved over DirichletBasis.lean:

### ✅ What's Good

1. **Clean separation**: Parts I-IV follow a logical dependency chain
2. **`baezDuarte_prod_le_one`**: Nearly complete proof! The nlinarith should close it with the two hypotheses.
3. **`bdMeanVector`**: Uses the closed-form (log + 1 - γ)/k instead of an integral — much easier to formalize
4. **`bdCovMatrix`**: Clean definition via `vecMulVec`
5. **The WARNING comment**: Documents the θ > 1 trap explicitly — this is crucial for future readers

### ⚠️ Dependencies to Verify

| Symbol | Source | Status |
|---|---|---|
| `eulerMascheroniConstant` | Mathlib | ⚠️ Check exact name |
| `Int.fract` | Mathlib | ✅ Available |
| `Matrix.ShermanMorrison` | Mathlib | ⚠️ May not exist yet |
| `RiemannHypothesis` | Cathedral/Defs | ✅ Exists |
| `dotProduct_smul` | Mathlib | ✅ Available |
| `vecMulVec` | Mathlib | ✅ Available |

The biggest risk: **Mathlib may not have Sherman-Morrison formalized**. If not, we'll need to prove it ourselves — roughly 100-150 lines of matrix algebra.

### Sorry Count: 3

1. `h_sm` (Sherman-Morrison application) — hardest, ~100 lines
2. `1 + X ≠ 0` — easy if X > 0, which follows from C being positive definite
3. `rh_iff_bd_cov_divergence` — the deep NB theorem, probably stays as an axiom

### Compared to Previous Attempts

| Module | Axiom Count | Target | Status |
|---|---|---|---|
| DirichletBasis.lean | 5 sorry | G̃ diag dominance | ❌ False |
| CovarianceBridge.lean | 4 sorry | C̃ diag dominance | ❌ False |
| DualVariational.lean | 3 sorry | v=1 trial vector | ❌ Wrong basis |
| **BaezDuarte.lean** | **3 sorry** | **X ~ ln(N) growth** | **🔬 Testing** |

Each iteration has been cleaner and more honest. BaezDuarte.lean asks the right question with the right basis.

---

## The Experimental Reality Check

Attack 6 is built and ready at `experiments/baez-duarte/`. When Attack 5 finishes:

```bash
cd /Users/jrgochan/code/github.com/jrgochan/prime/experiments/baez-duarte && cargo run --release 2>&1 | tee output_attack6.log
```

The three columns that matter:
1. **X/ln(N)** — does it converge to ~21.65?
2. **κ(C)** — how fast does it explode?
3. **c* signs** — does the Möbius function emerge?

If all three land, we have the true Riemann Hypothesis trapped in the machine. Not proved — trapped. The proof still requires showing X ~ c·ln(N), which is the content of the Parity Barrier. But at least we'll be fighting the right war.

---

## One Thought on the Road Ahead

Even if Attack 6 confirms the BD predictions perfectly, the remaining proof obligation — showing X_N → ∞ — is EXACTLY the Riemann Hypothesis reformulated. We haven't simplified it; we've rewritten it in a form where the numerical evidence is maximally transparent.

The Cathedral's role is to formalize the FRAMEWORK (Sherman-Morrison, covariance deflation, NB equivalence) and reduce RH to the single statement: `∃ C₀ > 0, ∀ N, X_N ≥ C₀ · ln(N)`. That's the final axiom. Everything else becomes machine-verified.

— The Forge Master
