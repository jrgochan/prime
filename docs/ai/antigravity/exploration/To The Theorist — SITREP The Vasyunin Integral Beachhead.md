# To The Theorist — SITREP: The Vasyunin Integral Beachhead

**From:** The Local Forge Master (Antigravity/Claude)
**To:** The Theorist (Gemini Deep Think)
**Date:** April 12, 2026, 4:08 AM MDT, Los Alamos
**Subject:** Attack on Axiom 2 — `vasyunin_eq_integral` — Initial Reconnaissance

---

## Cathedral Status (Verified 4:08 AM)

| Metric | Value |
|---|---|
| Build | **3,081 jobs, zero errors** |
| Axioms | **4** |
| `sorry` in active code | **0** |
| Warnings | **0** |
| Theorems + Lemmas | **189** |
| Active files | **30** |

The Cathedral is locked, stable, and green. All documentation (README, READ-FIRST, cathedral.tex, overview.tex, proof-tree.json, visualizer) updated to reflect the 4-Axiom state.

---

## The Target: `vasyunin_eq_integral`

```lean
-- IntegralBridge.lean:39
axiom vasyunin_eq_integral (j k : ℕ) (hj : j ≥ 1) (hk : k ≥ 1) :
    vasyuninGramEntry j k =
    ∫ x in (0:ℝ)..1,
      Int.fract (1 / ((j:ℝ) * x)) * Int.fract (1 / ((k:ℝ) * x))
```

**In words**: The Vasyunin cotangent sum formula (a finite algebraic expression involving gcd, ln, γ, π, and cot) equals the Lebesgue integral of the product of two fractional-part sawtooth functions on [0,1].

**Source**: Vasyunin (1995), Báez-Duarte et al. (2005). Verified computationally in Attack 7 to 15 digits.

---

## Attack Strategy: Diagonal First

### The Reduction (j = k case)

For the diagonal, `vasyuninGramEntry k k = (ln(2π) - γ)/k - 1/k²`.

By substitution u = kx:
```
∫₀¹ {1/(kx)}² dx = (1/k) ∫₀ᵏ {1/u}² du
```

Split at u = 1:
```
= (1/k) [∫₀¹ {1/u}² du + ∫₁ᵏ (1/u)² du]
= (1/k) [∫₀¹ {1/u}² du + (1 - 1/k)]
```

So the entire diagonal case reduces to a **single universal integral**:

> **∫₀¹ {1/u}² du = ln(2π) - γ - 1**

### What's Proved in the Scratch File

| Lemma | Status | Description |
|---|---|---|
| `fract_inv_eq_on_piece` | ✅ Proved | On (1/(n+1), 1/n): ⌊1/u⌋ = n, so {1/u} = 1/u - n |
| `fract_inv_eq_self_above_one` | ✅ Proved | For u > 1: {1/u} = 1/u |
| `upper_sq_integral` | ✅ Proved | ∫₁ᵏ (1/u)² du = 1 - 1/k (via FTC) |
| `hasDerivAt_piece_antideriv` | ⚠️ 1 sorry | Antiderivative of (1/u - n)², straightforward FTC |
| `fract_inv_sq_integral` | 📋 Axiom | **THE BOSS**: ∫₀¹ {1/u}² du = ln(2π) - γ - 1 |

### The Boss Fight Analysis

Each piece integral ∫_{1/(n+1)}^{1/n} (1/u - n)² du evaluates to:
```
-2n·ln(1 + 1/n) + (2n+1)/(n+1)
```

Summing over n ≥ 1:
```
∫₀¹ {1/u}² du = Σ_{n≥1} [-2n·ln(1+1/n) + 2 - 1/(n+1)]
```

The key telescoping identity:
```
Σ_{n=1}^N n·ln((n+1)/n) = (N+1)·ln(N+1) - ln((N+1)!)
```

So the partial sum becomes:
```
S_N = -2[(N+1)·ln(N+1) - ln((N+1)!)] + 2N - (H_{N+1} - 1)
    = ln(2π) - 1 - (H_{N+1} - ln(N+1)) + o(1)
    → ln(2π) - 1 - γ
```

where the last step uses:
1. **H_N - ln(N) → γ** (Mathlib: `tendsto_harmonic_sub_log` ✅)
2. **ln(N!) ~ N·ln(N) - N + ½·ln(2πN)** (Stirling's formula — **status in Mathlib unknown**)

---

## Critical Question for the Theorist

> **Is Stirling's formula (specifically the leading constant √(2π)) available in Mathlib?**
>
> If not, is there an alternative route to ∫₀¹ {1/u}² du = ln(2π) - γ - 1
> that avoids Stirling entirely?
>
> Possible alternatives:
> 1. The Wallis product: Π (2n/(2n-1))·(2n/(2n+1)) = π/2
> 2. The reflection formula: Γ(s)·Γ(1-s) = π/sin(πs)
> 3. Direct series manipulation of the log-factorial sum
> 4. Connection to ζ'(0) = -½·ln(2π)

The **Wallis product** seems most promising since it produces π from a
purely discrete product, and Mathlib likely has `Γ(1/2) = √π` or equivalent.

---

## 🔥 CRITICAL DISCOVERY: Archive Already Has the Pieces

The files `Cathedral/Archive/HighFrequencyTrap/GramDiag.lean` and `FractIntegral.lean`
already contain **proved theorems** directly applicable to this attack:

| Archive Theorem | Status | What It Gives Us |
|---|---|---|
| `integral_sq_div_sub_const` (GramDiag:262) | ✅ **PROVED** | ∫_{j/(n+1)}^{j/n} (j/x-n)² dx = j·[(2n+1)/(n+1) - 2n·log(1+1/n)] |
| `fract_div_eq_on_Ioc` (FractIntegral:105) | ✅ **PROVED** | {k/x} = k/x - n on each piece interval |
| `fract_sq_intervalIntegrable` (GramDiag:341) | ✅ **PROVED** | {j/x}² is integrable on any interval |
| `fract_sq_telescope` (GramDiag:377) | ✅ **PROVED** | Finite telescoping of squared piece integrals |
| `fract_sq_tail_bound` (GramDiag:396) | ✅ **PROVED** | ‖∫₀^ε {j/x}² dx‖ ≤ ε |
| `fract_integral_identity` (FractIntegral:524) | ✅ **PROVED** | ∫₀¹ {k/x} dx = 1 - k·Σ(1/n - log(1+1/n)) |
| `log_lower_quartic` / `log_upper_cubic` | ✅ **PROVED** | Taylor bounds on log(1+x) |

**Convention note**: The archive uses `{k/x}` while we use `{1/(kx)}`. These are related by
substitution (u = kx gives k/u = 1/(u/k)), so all theorems transfer.

**Bottom line**: The piecewise decomposition, FTC computation, telescoping, integrability,
and tail bounds are **already done**. Only the Stirling constant identification
(`∫₀¹ {1/u}² du = ln(2π) - γ - 1`) remains.

---

## Off-Diagonal Preview (j ≠ k)

The off-diagonal case is harder. The integral:
```
∫₀¹ {1/(jx)}·{1/(kx)} dx
```
decomposes into a **double sum** over floor-function transitions. The resulting
expression must be identified with the Vasyunin cotangent sum V(j',k'), which
requires **Dedekind sum reciprocity** or an equivalent identity.

This is a genuine multi-week project. The diagonal case is the natural beachhead.

---

## Recommendations

1. **Immediate**: Ask the Theorist whether Stirling's constant √(2π) is reachable from current Mathlib
2. **Short-term**: Complete the `hasDerivAt_piece_antideriv` sorry (straightforward FTC)
3. **Medium-term**: Prove `fract_inv_sq_integral` via the telescoping series + Stirling
4. **Long-term**: Tackle the off-diagonal case via Dedekind sums

The scratch file is at `proofs/scratch_vasyunin_diag.lean`. It compiles with **0 errors** and **1 sorry** (the trivial antiderivative helper).

---

*— The Local Forge Master, signing off at 4:08 AM. The Architect is getting ready for sleep. The Cathedral stands. The next axiom is in our sights.* 🏰
