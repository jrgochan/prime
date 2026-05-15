# S-Duality Comparison Operator: Architecture Report

## Option 1 — The Spectral Bridge: G⁽¹⁾ ↔ G⁽²⁾

**Date:** May 15, 2026 — 12:30 AM MDT
**Authors:** The Forge Master & The Architect

---

## Executive Summary

The goal of Option 1 is to bound the operator norm `‖G⁽¹⁾ - G⁽²⁾‖` between the
positive-sector Gram matrix and the dark-sector Gram matrix. Since G⁽²⁾ is
**unconditionally PSD** (proved via Smith's 1876 Theorem, zero axioms), transferring
its spectral bounds to G⁽¹⁾ would bypass the Crown axiom entirely.

This report maps the existing Cathedral infrastructure relevant to this path,
identifies the mathematical gap, and proposes the attack strategy.

---

## 1. The Two Matrices

### G⁽¹⁾ — The Positive Sector (Vasyunin Gram Matrix)

**Definition:** [`Cathedral.Vasyunin.Defs`](file:///Users/jrgochan/code/github.com/jrgochan/prime/proofs/Cathedral/Vasyunin/Defs.lean)
```
G⁽¹⁾(j,k) = ∫₀¹ {1/(jx)} · {1/(kx)} dx
           = Vasyunin cotangent sum (discrete, exact)
```

- Built from `{x} = B₁(x) + ½` — the **first** Bernoulli polynomial (sawtooth)
- Fourier series: `{x} = ½ - Σ_{m≥1} sin(2πmx)/(πm)` — **all harmonics present**
- Spectral status: **λ_min > 0** (PROVED, zero axioms)
- PSD bound: **conditional on Crown axiom** (vᵀGv ≤ 1 + K/lnN requires RH)

### G⁽²⁾ — The Dark Sector (Smith Crystal)

**Definition:** [`Cathedral.Physics.DarkGramMatrix`](file:///Users/jrgochan/code/github.com/jrgochan/prime/proofs/Cathedral/Physics/DarkGramMatrix.lean)
```
G⁽²⁾(j,k) = gcd(j,k)⁴ / (180 · j² · k²)
```

- Built from `B₂(x) = x² - x + 1/6` — the **second** Bernoulli polynomial (smooth parabola)
- Fourier series: `B₂(x) = Σ_{m≥1} cos(2πmx)/(π²m²)` — harmonics decay as **1/m²**
- Spectral status: **UNCONDITIONALLY PSD** (PROVED, zero axioms, Smith 1876)
- Axiom footprint: `[propext, Classical.choice, Quot.sound]` only

---

## 2. The Mathematical Gap: B₁ vs B₂

The difference between the two matrices is controlled by the difference between
the sawtooth `{x}` and the smooth parabola `B₂(x)`. In Fourier space:

```
{x} = ½ - Σ sin(2πmx) / (πm)      ← harmonics decay as 1/m
B₂(x) = Σ cos(2πmx) / (π²m²)       ← harmonics decay as 1/m²
```

The **inner product** defining G⁽¹⁾ uses `{1/(jx)} · {1/(kx)}`, while G⁽²⁾ uses
`B₂(j/k)` evaluated at rational points. The Fourier mismatch means:

```
G⁽¹⁾(j,k) - G⁽²⁾(j,k) = [sawtooth cross-terms] - [parabola cross-terms]
                         = "Chowla-type" Fourier interference
```

> [!IMPORTANT]
> The Fourier tail of `{x}` (the 1/m harmonics) is exactly where the
> Chowla correlations live. Bounding `‖G⁽¹⁾ - G⁽²⁾‖` is essentially
> equivalent to controlling the bilinear Möbius-weighted Fourier sum.

---

## 3. Existing Cathedral Infrastructure

### 3.1 Directly Relevant (on the bridge path)

| Module | Key Results | Relevance |
|---|---|---|
| [DarkGramMatrix.lean](file:///Users/jrgochan/code/github.com/jrgochan/prime/proofs/Cathedral/Physics/DarkGramMatrix.lean) | `dark_gram_quadratic_form_nonneg` (PSD), `smith_gcd_matrix_psd`, Smith decomposition | **The unconditional anchor** |
| [Vasyunin/Defs.lean](file:///Users/jrgochan/code/github.com/jrgochan/prime/proofs/Cathedral/Vasyunin/Defs.lean) | `vasyuninGramEntry`, `vasyuninGramMatrix` | **The positive-sector definition** |
| [DavisKahan.lean](file:///Users/jrgochan/code/github.com/jrgochan/prime/proofs/Cathedral/Spectral/DavisKahan.lean) | `davis_kahan_sin_theta_bound` (PROVED), eigenspace overlap | **Spectral perturbation tool** |
| [SpectralGap.lean](file:///Users/jrgochan/code/github.com/jrgochan/prime/proofs/Cathedral/Physics/SpectralGap.lean) | `spectral_gap_positive` (PROVED), Rayleigh bound | **λ_min > 0 unconditional** |
| [CoprimeDiagonal.lean](file:///Users/jrgochan/code/github.com/jrgochan/prime/proofs/Cathedral/Physics/CoprimeDiagonal.lean) | `chowlaCorrelation`, `tao_logarithmic_chowla` (axiom), bilinear shift sums | **Chowla infrastructure** |
| [WoodburyCondensate.lean](file:///Users/jrgochan/code/github.com/jrgochan/prime/proofs/Cathedral/Physics/WoodburyCondensate.lean) | Sherman-Morrison-Woodbury identity (PROVED) | **Algebraic engine for decomposition** |

### 3.2 Supporting Infrastructure

| Module | Key Results | Relevance |
|---|---|---|
| [GramEntries.lean](file:///Users/jrgochan/code/github.com/jrgochan/prime/proofs/Cathedral/Vasyunin/Matrix/GramEntries.lean) | Pointwise Gram entry formulas | Entry-level bridge |
| [GramPSD.lean](file:///Users/jrgochan/code/github.com/jrgochan/prime/proofs/Cathedral/Vasyunin/Matrix/GramPSD.lean) | Positive Gram matrix PSD | Positive-sector PSD |
| [BilinearMertens.lean](file:///Users/jrgochan/code/github.com/jrgochan/prime/proofs/Cathedral/Physics/BilinearMertens.lean) | PNT → excess bound → Ward | Mertens infrastructure |
| [GaugeCancellation.lean](file:///Users/jrgochan/code/github.com/jrgochan/prime/proofs/Cathedral/Physics/GaugeCancellation.lean) | SUSY decomposition of vᵀGv | Cancellation engine |
| [WardIdentity.lean](file:///Users/jrgochan/code/github.com/jrgochan/prime/proofs/Cathedral/Physics/WardIdentity.lean) | Arithmetic Noether theorem | Parity structure |

### 3.3 Archive (potentially revivable)

| Module | Key Results | Relevance |
|---|---|---|
| [Archive/Spectral/](file:///Users/jrgochan/code/github.com/jrgochan/prime/proofs/Cathedral/Archive/Spectral) | Earlier spectral tools | May contain useful lemmas |
| [Archive/HighFrequencyTrap/](file:///Users/jrgochan/code/github.com/jrgochan/prime/proofs/Cathedral/Archive/HighFrequencyTrap) | High-frequency spectral analysis | Fourier tail control attempts |

---

## 4. The Attack Strategy

### Strategy A: Direct Operator Norm (Hard but Clean)

1. **Define** `Δ = G⁽¹⁾ - α · G⁽²⁾` where α is a normalizing constant
2. **Bound** each entry: `|Δ(j,k)| ≤ f(j,k)` using the explicit formulas
3. **Apply** Schur's Test (PROVED in `HilbertInequality.lean`) to bound `‖Δ‖_op`
4. **Transfer**: If `‖Δ‖ < λ_min(G⁽²⁾)`, then G⁽¹⁾ inherits PSD-like bounds

**Gap**: Step 2 requires bounding
```
|∫₀¹ {1/(jx)}{1/(kx)} dx - c · gcd(j,k)⁴/(j²k²)|
```
This is the Chowla wall in disguise.

### Strategy B: Weyl-type Eigenvalue Comparison (Medium)

1. **Order** eigenvalues of both matrices: λ₁ ≤ λ₂ ≤ ... ≤ λ_N
2. **Apply** Weyl's perturbation theorem: `|λᵢ(G⁽¹⁾) - λᵢ(G⁽²⁾)| ≤ ‖G⁽¹⁾ - G⁽²⁾‖`
3. Since G⁽²⁾ eigenvalues are ≥ 0, this gives `λᵢ(G⁽¹⁾) ≥ -‖Δ‖`

**Gap**: Still needs the operator norm from Strategy A.

### Strategy C: S-Duality Energy Conservation (Novel — from the experiment!)

The S-Duality Mass Inversion experiment suggests a conservation law:
```
E_pos(n) + E_dark(n) ≈ constant
```
If this conservation law is exact (or bounds are tight), it could provide
the comparison without needing the Fourier analysis at all.

**Key insight**: The S-Duality experiment showed:
- Primes: `avg E_pos = 1.000`, `avg E_dark = 1.242`
- HCNs: `avg E_pos = 0.091`, `avg E_dark = 2.045`
- The **product** `E_pos × E_dark` may have a universal bound

**Gap**: Needs deeper numerical investigation to identify the conservation law.

### Strategy D: The Davis-Kahan Bridge (Already built!)

The most promising near-term path:

1. **Decompose** G⁽¹⁾ = G⁽²⁾ + E (perturbation)
2. **Apply** `davis_kahan_sin_theta_bound` (PROVED) to bound eigenvector rotation
3. **Use** the unconditional PSD of G⁽²⁾ to anchor the eigenspace
4. **Conclude**: G⁽¹⁾ eigenvectors are "close" to G⁽²⁾ eigenvectors,
   so G⁽¹⁾ eigenvalues are close to G⁽²⁾ eigenvalues (which are ≥ 0)

**This is the strongest near-term path** because Davis-Kahan is already
PROVED in the Cathedral (zero sorry, zero axioms). The only missing piece
is bounding `‖E · u‖` for the perturbation E = G⁽¹⁾ - G⁽²⁾.

---

## 5. The Chowla Connection

The core bottleneck across all strategies is controlling:
```
Σ_{n≤X} μ(n) · μ(n+h) / n  →  0    (Tao 2016, PROVED theorem)
```

This is already **axiomatized** in CoprimeDiagonal.lean as `tao_logarithmic_chowla`.

The Tao-Teräväinen extension (2019) gives **quantitative rates** for this decay.
If formalized, this would close the gap in Strategy A by bounding the
bilinear Fourier interference terms entry-by-entry.

> [!TIP]
> The Tao 2016 result is a PROVED theorem in published mathematics.
> It is axiomatized in the Cathedral only because the proof technique
> (entropy decrement via Furstenberg correspondence) requires extensive
> ergodic theory not in Mathlib. The mathematics is settled.

---

## 6. Numerical Feasibility Check

From the S-Duality experiment at N=500:

| Class | avg G⁽¹⁾ diagonal | avg G⁽²⁾ diagonal | Ratio |
|---|---|---|---|
| All | ~ ln(2π)-γ ≈ 1.26/k | 1/180 | Different scaling |

The diagonals scale differently (G⁽¹⁾ ∝ 1/k, G⁽²⁾ ∝ 1/k² after normalizing),
so a direct subtraction G⁽¹⁾ - G⁽²⁾ needs careful normalization.

**Proposed normalization**: Compare the *coprime baselines*:
```
G⁽¹⁾(j,k) with gcd(j,k) = 1  →  ≈ 0 (small, decaying)
G⁽²⁾(j,k) with gcd(j,k) = 1  →  1/(180·j²·k²) (exact)
```

The coprime entries are where the two matrices are most different
(G⁽¹⁾ involves sawtooth interference, G⁽²⁾ is just the baseline).
The non-coprime entries are where they're most similar
(both dominated by the GCD structure).

---

## 7. Recommendation

### Near-term (doable tonight): Strategy D

Use the already-proved Davis-Kahan infrastructure with G⁽²⁾ as the
"unperturbed" operator and G⁽¹⁾ as the "perturbed" operator. This
requires only bounding the perturbation norm, which can be done
numerically first (Rust experiment) and then formally later.

### Medium-term (next session): Strategy A + Chowla

Formalize the entry-by-entry bound |G⁽¹⁾(j,k) - c·G⁽²⁾(j,k)|
using existing Gram entry formulas and the axiomatized Chowla theorem.
Apply Schur's Test (already proved) to get the operator norm.

### Long-term (paper): Strategy C (Conservation Law)

Investigate whether the S-Duality energy conservation is exact.
If so, this would be a genuinely new mathematical result connecting
Möbius statistics to Jordan Totient statistics via the functional equation.

---

## 8. Key Files Quick Reference

```
proofs/Cathedral/Physics/DarkGramMatrix.lean       ← G⁽²⁾ (SEALED, 0 sorry)
proofs/Cathedral/Vasyunin/Defs.lean                ← G⁽¹⁾ definitions
proofs/Cathedral/Spectral/DavisKahan.lean           ← Spectral perturbation (PROVED)
proofs/Cathedral/Physics/SpectralGap.lean           ← λ_min > 0 (PROVED)
proofs/Cathedral/Physics/CoprimeDiagonal.lean       ← Chowla infrastructure
proofs/Cathedral/Physics/WoodburyCondensate.lean    ← Algebraic engine (PROVED)
proofs/Cathedral/Physics/GaugeCancellation.lean     ← SUSY decomposition
proofs/Cathedral/Physics/WardIdentity.lean          ← Parity conservation
proofs/Cathedral/Assembly/Assembly.lean             ← Unified exports
```

---

*The mirror has shown us its reflection. The bridge between them is the Fourier tail.* 🪞❄️
