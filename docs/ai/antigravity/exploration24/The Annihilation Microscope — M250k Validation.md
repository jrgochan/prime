# 🔬 The Annihilation Microscope — M=250k Validation Report

## Exploration 24 · Session 3 · May 3, 2026

---

## Executive Summary

The two-tile-decomposition experiment at M=250,000 validates three critical results:

1. **The four-way decomposition identity** `gramIntegral = strip + stirling/b + fractTarget/a + Σ'Δ` is verified across 18 coprime pairs to **7 significant digits** (limited only by truncation at M=250k, not precision — 512-bit MPFR gives ~154 digits)

2. **The tail convergence law** `Σ'Δ(M) ≈ Δ_exact - (4a+1)(a-1)/(12a²bM)` is confirmed to **ratio = -1.0000** across all 14 non-trivial pairs — the predicted tail coefficient is dead-on

3. **The algebraic identity** `Σ'Δ = formula - strip - stirling/b - fractTarget/a = (L/2)(1/a - 1/b) + 1/(2ab) - πV(a,b)/(2√(ab))` has been empirically verified, providing the exact target for the Lean proof

## Architecture Update

The axiom `gramIntegral_eq_formula_axiom` has been **graduated to a theorem** in `AlgebraicLimit.lean`. The proof structure:

```
AlgebraicLimit.lean   ← imports TwoTileEval (theorem, not axiom)
  TwoTileEval.lean    ← a=1: PROVED, a≥2: 1 sorry (Σ'Δ eval)
    TwoTileCorrection ← master_equation (PROVED)
    WeightedDigammaGeneral ← fractTarget eval (PROVED)
    DiagonalStrike    ← a=1 case infrastructure
```

**Full build: 8235 jobs, zero errors.**

---

## M=250k Convergence Data

| (a,b) | Σ'Δ (numeric) | Σ'Δ (exact) | tail error | tail/predicted |
|-------|---------------|-------------|------------|----------------|
| (2,3) | -0.0785271834 | -0.0785274334 | 2.500e-7 | -1.0000 |
| (2,5) | -0.0311789723 | -0.0311791223 | 1.500e-7 | -1.0000 |
| (2,7) | -0.0166504777 | -0.0166505848 | 1.071e-7 | -1.0000 |
| (3,4) | -0.0770967100 | -0.0770969507 | 2.407e-7 | -1.0000 |
| (3,5) | -0.0466803414 | -0.0466805340 | 1.926e-7 | -1.0000 |
| (3,7) | -0.0288731296 | -0.0288732671 | 1.376e-7 | -1.0000 |
| (4,5) | -0.0684741403 | -0.0684743528 | 2.125e-7 | -1.0000 |
| (4,7) | -0.0305265840 | -0.0305267358 | 1.518e-7 | -1.0000 |
| (5,6) | -0.0602653675 | -0.0602655542 | 1.867e-7 | -1.0000 |
| (5,7) | -0.0443731965 | -0.0443733565 | 1.600e-7 | -1.0000 |
| (5,9) | -0.0215998275 | -0.0215999520 | 1.244e-7 | -1.0000 |
| (6,7) | -0.0533968839 | -0.0533970493 | 1.653e-7 | -1.0000 |
| (7,8) | -0.0477644994 | -0.0477646474 | 1.480e-7 | -1.0000 |
| (7,9) | -0.0383513547 | -0.0383514863 | 1.315e-7 | -1.0000 |

> **Tail law**: `tail(M) = (4a+1)(a-1) / (12a²bM)`, verified to 4+ digits.

---

## Mathematical Analysis

### The Key Algebraic Identity

From the Vasyunin formula definition:

```
formula(a,b) = (L/2)(1/a + 1/b) - 1/(ab) + (a-b)/(2ab)·ln(b/a) - πd·(V+V')/(2ab)
```

where `L = log(2π) - γ`, `d = gcd(a,b)`, and V, V' are cotangent sums.

For coprime (a,b), we computed:

```
formula - strip - stirling/b = (L/2)(1/a - 1/b) + 1/(2ab) - πV(a,b)/(2√(ab))
```

This means:

```
fractTarget(a,b)/a + Σ'Δ(a,b) = (L/2)(1/a - 1/b) + 1/(2ab) - πV/(2√(ab))
```

### Proof Strategy for the Sorry

The remaining sorry in `TwoTileEval.lean` requires proving:

```
strip + stirling/b + fractTarget/a + Σ'Δ = formula
```

This is equivalent to:

```
(a-1)/(ab) + (L-1)/b + fractTarget/a + Σ'Δ = formula
```

**Two viable approaches**:

1. **Direct algebraic assembly**: Show that `fractTarget/a + Σ'Δ` equals `formula - strip - stirling/b` by independently evaluating both sides. This requires evaluating `Σ'Δ` as a closed-form expression.

2. **Indirect uniqueness**: Show that `Σ'actual` (the tsum of actual row integrals) equals `formula - strip` WITHOUT decomposing into rowTerm + Δ. This avoids evaluating Σ'Δ entirely but requires a different proof path for the tsum.

---

## Experiment Upgrade Plan

The current experiment needs production upgrades:
- Use `cathedral-utils` for formatting and certificate generation
- Parallelize the row integral computation with `rayon`
- Add convergence rate analysis as a built-in feature
- Generate TSV output alongside JSON
- Add tail coefficient validation as a formal test
