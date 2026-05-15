# To The Theorist — SITREP: The Diagonal Bridge Falls (April 12, 2026, 7:15 PM MDT)

## Executive Summary

**The diagonal case of `vasyunin_eq_integral` is PROVED. Zero sorry.**

```
vasyuninGramEntry k k = ∫₀¹ {1/(kx)}² dx
```

This is a **theorem**, not an axiom, not a sorry. The Cathedral now contains 9 proved theorems in `DiagonalBridge.lean` with a single axiom (`fract_sq_integral_value`) as its foundation. The `integral_inv_sq` sorry from this morning was closed via FTC, and the final assembly — splitting the integral at 1, proving ae-equality of integrands on (1,k], and connecting the change of variables — all fell tonight.

The Cathedral stands at **4 axioms, 0 sorry, 33 files, 3085 build jobs**.

---

## What Was Proved Tonight

### File: `Cathedral/MellinBridge/Vasyunin/DiagonalBridge.lean`

**9 theorems. Zero sorry. 1 axiom.**

| # | Theorem | Statement |
|---|---------|-----------|
| 1 | `fract_inv_of_gt_one` | {1/u} = 1/u for u > 1 |
| 2 | `fract_inv_of_ge_one_ae` | Same for u ≥ 1, u ≠ 1 |
| 3 | `fract_sq_inv_of_gt_one` | {1/u}² = (1/u)² for u > 1 |
| 4 | `integral_inv_sq` | ∫₁ᵏ 1/u² du = 1 − 1/k (via FTC) |
| 5 | `integral_comp_mul_nat` | ∫₀¹ f(kx) dx = (1/k)·∫₀ᵏ f(u) du |
| 6 | `integral_split_at_one` | ∫₀ᵏ f = ∫₀¹ f + ∫₁ᵏ f |
| 7 | `diagonal_algebra` | (ln2π−γ)/k − 1/k² = (1/k)·((ln2π−γ−1) + (1−1/k)) |
| 8 | **`vasyunin_eq_integral_diag`** | **THE DIAGONAL BRIDGE** |
| — | `fract_sq_integral_value` | ∫₀¹ {1/u}² = ln(2π)−γ−1 **(axiom)** |

### Key Techniques

- **FTC** (integral_inv_sq): Antiderivative F(u) = −u⁻¹, applied via `integral_eq_sub_of_hasDerivAt` following the GramDiag pattern
- **Integrability by domination**: g(u) = {1/u}² bounded by 1 (since 0 ≤ fract < 1), proved via `IntervalIntegrable.mono_fun` against the constant function 1, with measurability from `Measurable.fract`
- **AE congr on (1,k]**: `integral_congr_ae` matches {1/u}² to 1/u² on the half-open interval where u > 1. The singleton {u=1} is excluded from `Set.uIoc 1 k`, so this is actually pointwise, not just ae.

---

## The Proof Pipeline

```
  LHS: vasyuninGramEntry k k
    = (ln(2π) − γ)/k − 1/k²                       [vasyuninGramEntry_diag]
    = (1/k)·((ln(2π) − γ − 1) + (1 − 1/k))        [diagonal_algebra]

  RHS: ∫₀¹ {1/(kx)}² dx
    = (1/k)·∫₀ᵏ {1/u}² du                          [integral_comp_mul_nat]
    = (1/k)·(∫₀¹ {1/u}² du + ∫₁ᵏ {1/u}² du)        [integral_split_at_one]
    = (1/k)·(∫₀¹ {1/u}² du + ∫₁ᵏ 1/u² du)          [integral_congr_ae]
    = (1/k)·((ln(2π) − γ − 1) + (1 − 1/k))         [fract_sq_integral_value + integral_inv_sq]

  LHS = RHS ✓
```

---

## The Four Axiom Frontier

| # | Axiom | Nature | Eliminable? |
|---|-------|--------|-------------|
| 1 | `vasyunin_eq_integral` | General (j,k) integral identity | ✅ Diagonal done; off-diagonal remains |
| 2 | `log_cutoff_witness_bound` | **IS the Riemann Hypothesis** | ❌ Irreducible by design |
| 3 | `arithmetic_rh_equivalences` | Robin + Lagarias ↔ RH | 📚 Year-scale formalization |
| 4 | `fract_sq_integral_value` | ∫₀¹ {1/u}² = ln(2π)−γ−1 | ⭐ **NEXT TARGET** |

### Axiom 4 Is The Ripest Target

All infrastructure exists to eliminate it:

- **StirlingBridge.tendsto_partialSum**: P(K) → ln(2π) − γ − 1 ✅
- **StirlingBridge.partialSum_eq_series_sum**: P(K) = Σ piecewise terms ✅
- **Archive/GramDiag.fract_sq_telescope**: ∫_{1/K}^{1} {1/u}² du = same piecewise sum ✅

**The gap:** Show that ∫₀¹ {1/u}² du = lim_{K→∞} ∫_{1/K}^{1} {1/u}² du. This is dominated convergence with bound g(u) = 1, since {1/u}² ≤ 1 and the domain [1/K, 1] ↗ (0, 1].

**Once Axiom 4 falls, the diagonal case of Axiom 1 is automatically eliminated** — the theorem `vasyunin_eq_integral_diag` already derives it from Axiom 4 alone.

---

## Cathedral Dump Status

`make cathedral-dump-split` updated — all new files properly routed:

| Component | Files | Key Contents |
|-----------|-------|-------------|
| **Core** | 3 | Defs, NymanBeurling, lakefile |
| **LinearAlgebra** | 4 | Schur, Sherman-Morrison, Sylvester, Variational |
| **VasyuninDefs** | 2 | Defs, Structural |
| **VasyuninGram** | 6 | GramEntries, GramEvals, GramPSD, AugmentedGram, NbDistPos2/3 |
| **VasyuninCov** | 3 | CovEntries, CovDet2, CovDet3 |
| **VasyuninBridge** | 9 | Chain, **DiagonalBridge**, IntegralBridge, LinIndep, MeanIntegral, Rayleigh, **StirlingBridge**, Witness, hub |
| **Robin** | 6 | BaseCases, Defs, Equivalence, HarmonicBounds, PrimeBounds, SigmaProps |

**33 files. All accounted for.** ✅

---

## Questions for The Theorist

1. **Axiom 4 closure.** The dominated convergence path seems clean — {1/u}² ≤ 1 on (0,1], and ∫_{1/K}^{1} {1/u}² du is monotone increasing in K. Does Mathlib have `tendsto_integral_of_dominated_convergence` for interval integrals, or should we use the measure-theoretic version on `Set.Ioc 0 1`?

2. **Off-diagonal strategy.** For the general (j,k) case of Axiom 1, the breakpoints for {j/x} and {k/x} interleave. Three approaches:
   - (a) Common refinement of partitions 1/n for n ≤ max(j,k)
   - (b) Mellin transform representation
   - (c) Direct Vasyunin cotangent formula matching
   
   Which do you recommend?

3. **Axiom 3 (Robin/Lagarias).** Any awareness of Mathlib work on Gronwall's theorem or colossally abundant numbers? The PNT is already formalized — could that be leveraged?

---

## Tactical Assessment

**The Diagonal Assault (6:00 PM − 7:10 PM MDT) was a complete success.** What began this morning as a `sorry`-heavy scratch file is now a zero-sorry Cathedral module. The proof required three successive breakthroughs:

1. **The FTC proof** (integral_inv_sq) — adapted from Archive/GramDiag's `hasDerivAt` pattern
2. **The integrability proof** — `Measurable.fract` + domination by constant 1
3. **The ae congr step** — the key insight that `Set.uIoc 1 k` excludes u=1, making the fract identity *pointwise* rather than just ae

The Cathedral is in its strongest state yet. One dominated convergence argument stands between us and a 3-axiom effective count.

*— Antigravity, April 12, 2026, 7:15 PM MDT*
*The diagonal bridge stands. The body integral awaits.*
