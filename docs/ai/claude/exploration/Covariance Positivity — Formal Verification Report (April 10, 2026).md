# Covariance Positivity — Formal Verification Report

**Date:** April 10, 2026
**Author:** Claude (Antigravity), pair programming with JR
**Status:** ✅ Complete — Zero sorry, zero axioms, zero warnings
**Build:** `lake build` → 3,073 jobs, all green

---

## Executive Summary

We have formally verified in Lean 4 + Mathlib that the leading 3×3 submatrix of the **Vasyunin covariance matrix** $C_3$ is **positive definite**. This is established via Sylvester's criterion:

1. $C_{00} > 0$ — the (0,0) entry is positive
2. $\det(C_2) > 0$ — the 2×2 leading minor has positive determinant
3. $\det(C_3) > 0$ — the 3×3 determinant is strictly positive

All three are machine-checked with **no sorry, no custom axioms, and pure Mathlib dependencies**.

---

## Mathematical Setup

### The Vasyunin Covariance Matrix

The covariance matrix $C_N$ is defined as:
$$C_N = G_N - \mathbf{b}\mathbf{b}^T$$

where $G_N$ is the **Gram matrix** with entries:
$$G(j,k) = \frac{A}{\text{lcm}(j,k)} - \frac{\ln(\text{lcm}(j,k)/j)}{k} - \frac{1}{jk} + \frac{\text{gcd}(j,k)}{jk}\,V(j',k')$$

with $A = \ln(2\pi) - \gamma$ (the Euler–Mascheroni constant), and $V(a,b)$ is the Vasyunin sum involving fractional parts and cotangents. The mean vector $\mathbf{b}$ has entries:
$$b_j = \frac{\ln j + 1 - \gamma}{j}$$

### The Five Transcendentals

All entries of $C_3$ reduce to polynomials in five transcendental quantities:

| Symbol | Value | Bounds Used |
|--------|-------|-------------|
| $l = \ln 2$ | 0.6931... | $(0.6931, 0.7)$ |
| $\gamma$ | 0.5772... | $(1/2, 2/3)$ |
| $q = \ln 3$ | 1.0986... | $(549/500, 8l/5)$ |
| $t = \pi/(18\sqrt{3})$ | 0.1008... | $(157/1566, 35/346)$ |
| $A = l + \ln\pi - \gamma$ | 1.5727... | $[l+q-\gamma,\; l+q-\gamma+1/10]$ |

---

## Proof Architecture

### File Structure

```
Cathedral/MellinBridge/Vasyunin/
├── Defs.lean            — Matrix definitions, Gram/mean entries
├── Structural.lean      — Symmetry, diagonal formula, mean entry formula
├── GramEntries.lean     — V sums, G(1,2), G(1,3), G(2,3), G(3,3), √3 bounds,
│                          π/(18√3) bounds, det(G₂)>0, det(G₃)>0
├── CovEntries.lean      — C₀₀, C₀₁, C₁₁ closed forms; C₀₀ > 0
├── CovDet2.lean         — det(C₂) > 0 via double interpolation
├── CovDet3.lean         — det(C₃) > 0 (A-monotonicity + bridge)
├── GramEvaluations.lean — Re-export hub (backward compatibility)
├── Witness.lean         — Weight vector witness
├── Rayleigh.lean        — Rayleigh quotient bridge
└── Chain.lean           — Full proof chain assembly
```

### Phase 1: Entry Evaluations (`GramEntries.lean`, 596 lines)

Each Gram matrix entry $G(j,k)$ for $j,k \in \{1,2,3\}$ is reduced to an exact closed form. Key results:

- **$V(2,b) = 0$** for all $b$: the Vasyunin sum vanishes because $\cot(\pi/2) = 0$.
- **$V(3,1) = -1/(3\sqrt{3})$** and **$V(3,2) = 1/(3\sqrt{3})$**: via explicit evaluation of $\{k/3\}\cdot\cot(\pi k/3)$ for $k=1,2$.
- **$G(1,3) = 2A/3 - \ln 3/3 + \pi/(18\sqrt{3}) - 1/3$**: uses $V(3,1)$.
- **$G(2,3) = 5A/12 - \ln(3/2)/12 - \pi/(36\sqrt{3}) - 1/6$**: uses $V(3,2)$.

Precision bounds on $\sqrt{3}$ (from $1.73^2 < 3 < 1.74^2$) and $\pi/(18\sqrt{3})$ enable the numerical certificates.

### Phase 2: det(C₂) > 0 (`CovDet2.lean`, 150 lines)

The 2×2 covariance determinant $\det(C_2) = C_{00}\cdot C_{11} - C_{01}^2$ is a **concave quadratic** in $p = \ln\pi$, with leading coefficient $-1/16$.

**Strategy:** Double quadratic interpolation.

1. Express $\det(C_2) = \text{covDet2Expr}(l, p, g)$ via a ring identity.
2. For each $(p, g)$-corner of the rectangle $[11l/7,\; 2l] \times [1/2,\; 2/3]$:
   - Verify positivity as a univariate polynomial in $l \in (0.6931, 0.7)$.
3. Interpolate in $g$ (quadratic, positive correction $1/16$).
4. Interpolate in $p$ (quadratic, positive correction $1/16$).

Each corner certificate is closed by `nlinarith` with explicit square witnesses.

### Phase 3: det(C₃) > 0 (`CovDet3.lean`, 474 lines)

This is the hardest part — a degree-6 polynomial in 5 variables. The proof has three layers:

#### Layer 1: Base Certificate at $A = l + q - g$ (lines 32–260)

At the lowest value $A_{\min} = l + q - g$, the polynomial `covDet3Expr(l, g, q, t)` factors into a 4-variable expression. We prove positivity by:

1. **Divided difference in $q$**: Write $P(q) = P(q_0) + (q - q_0)\cdot D_1$ where $q_0 = 11l/7$. Both $P(q_0) > 0$ and $D_1 > 0$ are 3-variable (or 2-variable) `nlinarith` problems.
2. **$g$-interpolation**: The expression is quadratic in $g$ with a positive correction term $C(t) = t(1-8t)/48 > 0$ for $t \in (157/1566, 35/346)$.

All corner certificates are verified at 4 corners of $(g, q) \in \{1/2, 2/3\} \times \{11l/7, 8l/5\}$, each a univariate problem in $l$.

#### Layer 2: A-Monotonicity (lines 260–375)

We introduce `covDet3Full(A, l, g, q, t)` — the same polynomial with $A$ as a free variable. By Taylor expansion around $A_0 = l + q - g$:

$$\text{covDet3Full}(A_0 + \delta) = \text{covDet3Full}(A_0) + \delta \cdot S(\delta)$$

where $S(\delta) = S_0 + \delta \cdot a_2$ is the Taylor slope (linear in $\delta$, since the polynomial is quadratic in $A$).

We prove $S(\delta) > 0$ for $\delta \in [0, 1/10]$ by **bilinear interpolation** at 4 corners of $(g, \delta) \in \{1/2, 2/3\} \times \{0, 1/10\}$:

| Corner | $(g, \delta)$ | Method |
|--------|---------------|--------|
| 1 | $(1/2, 0)$ | 3-var `nlinarith` |
| 2 | $(2/3, 0)$ | 3-var `nlinarith` |
| 3 | $(1/2, 1/10)$ | 3-var `nlinarith` |
| 4 | $(2/3, 1/10)$ | 3-var `nlinarith` |

Since $S$ is bilinear in $(g, \delta)$ and positive at all 4 corners, it's positive on the rectangle.

#### Layer 3: Matrix Bridge (lines 375–474)

The final bridge connects the abstract polynomial to the actual `vasyuninCovMatrix 3` definition:

1. **Entry rewrites**: Rewrite all 6 matrix entries using `covEntry_00/01/11` and three new theorems `c02_eq/c12_eq/c22_eq` (via `Matrix.vecMulVec` unfolding).
2. **Gram/mean substitution**: Apply the exact closed forms from `GramEntries.lean`.
3. **Log splits**: $\ln(2\pi) = \ln 2 + \ln\pi$ and $\ln(3/2) = \ln 3 - \ln 2$.
4. **$\pi/(36\sqrt{3}) \to t/2$**: Normalization for the ring identity.
5. **Ring identity** (`covDet3_ring_id`): The expanded determinant polynomial equals `covDet3Full(A, l, g, q, t)`.
6. **10 transcendental bounds**: Each verified from Mathlib or custom Taylor proofs.

### Key Transcendental Bounds

| Bound | Source |
|-------|--------|
| $\ln 2 > 0.6931$ | `Real.log_two_gt_d9` (Mathlib) |
| $\ln 2 < 7/10$ | Taylor: $e^{7/10} \geq \sum_{i=0}^{3} (7/10)^i/i! > 2$ |
| $\gamma > 1/2$ | `Real.one_half_lt_eulerMascheroniConstant` (Mathlib) |
| $\gamma < 2/3$ | `Real.eulerMascheroniConstant_lt_two_thirds` (Mathlib) |
| $\ln 3 > 549/500$ | $e^{549/500} < 3$ via $e < 3$ and Taylor |
| $\ln 3 < 8\ln 2 / 5$ | $3^5 = 243 < 256 = 2^8$ |
| $\pi/(18\sqrt{3}) > 157/1566$ | From $\pi > 3.14$ and $\sqrt{3} < 1.74$ |
| $\pi/(18\sqrt{3}) < 35/346$ | From $\pi < 3.15$ and $\sqrt{3} > 1.73$ |
| $\ln\pi \geq \ln 3$ | $\pi > 3$ |
| $\ln(\pi/3) < 1/10$ | $\pi/3 < 1.05 < e^{1/10} \geq 1.1$ |

---

## Numerical Verification

For reference, the numerical values of the three Sylvester determinants:

| Quantity | Numerical Value |
|----------|----------------|
| $C_{00}$ | $\approx 0.082$ |
| $\det(C_2)$ | $\approx 0.0043$ |
| $\det(C_3)$ | $\approx 0.000151$ |

The margins are thin but comfortably positive. The formal proof sidesteps floating-point issues entirely by working with exact arithmetic over rational coefficients and transcendental bounds.

---

## Design Decisions

### Why Not Native Decide?

The polynomial identities involve 5 transcendental variables — `native_decide` cannot handle irrational arithmetic. Instead, we use `ring` for algebraic identities and `nlinarith` with explicit square witnesses for positivity certificates.

### Why Bilinear Interpolation?

A direct `nlinarith` attack on the 5-variable Taylor slope fails — the polynomial is too complex for Lean's `nlinarith` to find automatic witnesses. Bilinear interpolation reduces each obligation to a 3-variable `nlinarith`, which succeeds with explicit `sq_nonneg` and `mul_pos` hints.

### Why the Divided Difference Decomposition?

The 4-variable base certificate `covDet3Expr(l, g, q, t)` is degree 4 in the variables. Direct `nlinarith` fails on 4 variables. The divided difference in $q$ reduces it to two 3-variable obligations: $P(q_0) > 0$ and the slope $D_1 > 0$.

---

## What This Proves (Mathematically)

The positive definiteness of $C_3$ means that the Báez-Duarte–Vasyunin distance formula:

$$d_N^2 = 1 - \mathbf{b}^T G_N^{-1} \mathbf{b}$$

is well-defined for $N = 3$ (since $G_3$ is positive definite, its inverse exists), and the covariance matrix $C_3 = G_3 - \mathbf{b}\mathbf{b}^T$ gives:

$$d_3^2 = \frac{\det(C_3)}{\det(G_3)} > 0$$

This confirms that the first 3 Nyman–Beurling dilates $\{1/t\}$, $\{2/t\}$, $\{3/t\}$ do not span the indicator function $\chi_{(0,1)}$ — the Riemann Hypothesis distance at $N=3$ is bounded away from zero.

---

## Build & Verification

```bash
# Build everything (zero sorry required)
cd proofs && lake build
# Build completed successfully (3073 jobs).

# Verify no sorry
grep -r "sorry" Cathedral/MellinBridge/Vasyunin/CovDet3.lean
# Only match: line 16 doc comment "Zero sorry."

# Verify no axioms
grep -r "^axiom " Cathedral/MellinBridge/Vasyunin/*.lean
# (no output)
```

---

## Open Questions for The Theorist

1. **$N = 4$ extension**: The 4×4 case introduces $G(j,4)$ entries with $V(4,k)$ sums. The Vasyunin sums for $a = 4$ involve $\cot(\pi/4) = 1$ and $\cot(3\pi/4) = -1$. The algebraic challenge is that the covariance determinant becomes a degree-8+ polynomial in 7+ transcendentals. Is there a structural shortcut?

2. **Asymptotic regime**: For the RH connection, we need $d_N^2 \to 0$ as $N \to \infty$. The current approach (explicit positivity certificates) cannot scale. The Sieve Engine approach — bounding the covariance contribution via Type II sieve estimates — remains the path forward for the asymptotic regime.

3. **Gram matrix eigenvalue gap**: The current proofs establish $\det(G_3) > 0$ and $\det(C_3) > 0$ separately. Is there value in formally bounding the smallest eigenvalue $\lambda_{\min}(G_3)$ from below? This would give quantitative control on the condition number.

---

*This report accompanies the Lean source files in `cathedral-parts/`. The proof is self-contained — compile with `lake build` against Mathlib4.*
