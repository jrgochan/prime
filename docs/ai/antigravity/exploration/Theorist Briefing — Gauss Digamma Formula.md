# Theorist Briefing: Proving the Gauss Digamma Formula

**Date**: April 14, 2026  
**From**: Antigravity (AI pair programmer)  
**Re**: Converting `gauss_digamma_formula` from axiom → theorem  
**Build Status**: 3087 jobs, zero errors ✅

---

## Recent Achievement

The **digamma reflection formula** has been **promoted from axiom to theorem** with zero sorry:

```
ψ(1-s) - ψ(s) = π · cot(πs)    for s ∉ ℤ
```

**Proof method**: Take `logDeriv` of Mathlib's `Gamma_mul_Gamma_one_sub`:
- LHS: `logDeriv_mul` + `logDeriv_comp` (chain rule for `z ↦ 1-z`) → `ψ(s) - ψ(1-s)`  
- RHS: `logDeriv_div` + `HasDerivAt` for `sin(πz)` → `-π·cos(πs)/sin(πs)`  
- Assembly: `linear_combination`

This reduced the Vasyunin chain from 7 → 6 axioms.

---

## Current Axiom Inventory (Vasyunin Chain)

| # | Axiom | File | Nature |
|---|---|---|---|
| 1 | `log_cutoff_witness_bound` | Chain.lean | Numerical bound |
| 2 | **`gauss_digamma_formula`** | DigammaReflection.lean | **← TARGET** |
| 3 | `vasyunin_eq_integral` | IntegralBridge.lean | Original bridge axiom |
| 4 | `harmonicTileSum_reciprocity` | LogDigammaBridge.lean | Dedekind (1892) |
| 5 | `telescope_limit_eq_vasyunin` | LogDigammaBridge.lean | Analytic limit |
| 6 | `vasyunin_integral_eq_formula` | LogDigammaBridge.lean | General integral |

**Sorry count**: 1 (`floor_sum_reciprocity` in LogDigammaBridge.lean)

---

## The Statement Under Analysis

For coprime `p < q` with `p ≥ 1`:

$$\psi\!\left(\frac{p}{q}\right) = -\gamma - \log(2q) - \frac{\pi}{2}\cot\!\left(\frac{\pi p}{q}\right) + 2 \sum_{n=1}^{\lfloor(q-1)/2\rfloor} \cos\!\left(\frac{2\pi n p}{q}\right) \log\!\sin\!\left(\frac{\pi n}{q}\right)$$

This is **Gauss's digamma formula** (1813), the key identity that converts digamma values at rational arguments into finite sums involving cotangent and log-sin values.

---

## Mathlib Infrastructure Audit

### What exists ✅
- **Gamma reflection**: `Gamma_mul_Gamma_one_sub` — Γ(s)·Γ(1-s) = π/sin(πs)
- **Legendre duplication**: `Gamma_mul_Gamma_add_half` — Γ(s)·Γ(s+½) = Γ(2s)·2^{1-2s}·√π
- **Euler limit**: `GammaSeq_tendsto_Gamma` — n^s · n! / ∏(s+k) → Γ(s)
- **Digamma = logDeriv(Γ)**: `digamma_def`
- **Gamma nonvanishing**: `Gamma_ne_zero`
- **logDeriv algebra**: `logDeriv_mul`, `logDeriv_div`, `logDeriv_comp`, `logDeriv_prod`
- **Fourier theory**: `Mathlib.Analysis.Fourier.AddCircle` (basic framework)
- **Hurwitz zeta**: `Mathlib.NumberTheory.LSeries.HurwitzZeta` (analytic continuation exists)

### What's missing ❌

> **The general Gauss multiplication formula for Γ is NOT in Mathlib.**  
> Only the q=2 case (Legendre duplication) has been proved.

The multiplication formula states:
$$\prod_{k=0}^{q-1} \Gamma\!\left(s + \frac{k}{q}\right) = (2\pi)^{(q-1)/2} \cdot q^{1/2-qs} \cdot \Gamma(qs)$$

This is the natural "parent" identity from which the Gauss digamma formula follows by differentiation.

---

## Proof Strategies

### Strategy A: Prove the Multiplication Formula, Then Differentiate

**Idea**: Generalize Mathlib's existing Legendre duplication proof pattern.

The Legendre proof works by:
1. Show both sides are equal for real s > 0 using the Bohr–Mollerup theorem
2. Extend to all complex s via `AnalyticOnNhd.eq_of_frequently_eq`

For general q, step 1 requires proving:
$$\prod_{k=0}^{q-1} \Gamma\!\left(s + \frac{k}{q}\right) = (2\pi)^{(q-1)/2} \cdot q^{1/2 - qs} \cdot \Gamma(qs) \quad \text{for } s > 0$$

This can be done via the Beta function and induction on q, or via the Bohr–Mollerup characterization.

Then take `logDeriv` of both sides:
$$\sum_{k=0}^{q-1} \psi\!\left(s + \frac{k}{q}\right) = q \cdot \psi(qs) - q \log q$$

Evaluate at s = p/q with our already-proved `digamma_add_nat` and `digamma_reflection_complex` to extract ψ(p/q).

**Effort**: 🔴 500–1000 lines across multiple sessions

### Strategy B: Euler Limit + Roots of Unity

**Idea**: Compute `logDeriv(GammaSeq)` at s = p/q directly using partial fractions over roots of unity.

**Effort**: 🔴 300–600 lines

### Strategy C: Digamma Series + DFT

**Idea**: Prove the Weierstrass partial-fraction series for ψ, then apply DFT at ℤ/qℤ.

**Effort**: 🔴 400–700 lines

### Strategy D: Keep as Axiom

**Rationale**: The Gauss digamma formula is a well-established result from 1813. Keeping it as a clearly-stated axiom is mathematically honest and practically sound.

**Effort**: 🟢 0 lines

---

## Questions for The Theorist

1. **Is Strategy A (multiplication formula) the right mathematical path?**  
   If you were to prove this on paper for a referee, which approach would you take? The multiplication formula → logDeriv → extraction chain seems cleanest, but is there a shortcut I'm missing?

2. **Does our proof chain actually need the FULL Gauss digamma formula?**  
   If we only use ψ(p/q) for specific small q values, perhaps we can prove just those cases from the Legendre duplication (q=2) plus the reflection formula.

3. **Is the Bohr–Mollerup route or the Beta-function route better for the multiplication formula?**  
   Mathlib already has `Gamma_mul_Gamma_add_half_of_pos` proved via Bohr–Mollerup for the q=2 case. Generalizing should be possible but may require subtle convexity arguments.

4. **Could the Hurwitz zeta approach work?**  
   Mathlib has `HurwitzZeta` with analytic continuation. The Gauss digamma formula can be derived from `ψ(s) = -ζ'(0, s)` where ζ is the Hurwitz zeta. Is this route cleaner?

5. **Priority call**: Given that all 6 remaining axioms are classical results, is it more valuable to:  
   (a) Push for zero axioms in the Vasyunin chain  
   (b) Focus effort on the broader Cathedral architecture (e.g., other attack fronts)  
   (c) Write up the current state for publication

---

## Current Build Integrity

```
lake build Cathedral          → 3087 jobs, zero errors
Axioms (Vasyunin chain)       → 6 (all classical results)
Sorry (Vasyunin chain)        → 1 (elementary lattice point counting)
digamma_reflection_complex    → PROVED (was axiom, now theorem)
```

The Cathedral stands. The question is: how far do we climb? 🏛️
