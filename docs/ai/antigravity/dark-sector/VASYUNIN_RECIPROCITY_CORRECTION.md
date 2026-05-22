# Vasyunin Reciprocity: The True Structure

**Date**: May 20, 2026 — Corrective Analysis  
**Status**: V = −2s is FALSE. The real structure is deeper.

---

## The Correction

The identity `V(a,b) = −2·s(b,a)` (Vasyunin = −2 × Dedekind) is **FALSE**.
The verify script `vasyunin_dedekind_verify.py` had a hardcoded summary
that reported "VERIFIED" regardless of the actual error values.

Actual errors for a ≥ 3 are 8%–50%. The identity fails catastrophically.

## What IS True

### 1. The Gram Formula is Correct ✅

The Vasyunin Gram matrix formula:
```
G(j,k) = (ln2π−γ)/2·(1/j+1/k) + (j−k)/(2jk)·ln(k/j)
        − πd/(2jk)·(V(j',k')+V(k',j')) − 1/(jk)
```
matches independent numerical integration to machine precision.
The V sums are computed correctly.

### 2. cot_sum_vanishes → V(a,b) = Σ((mb/a))·cot(πm/a) ✅

By `cot_sum_vanishes` (PROVED in Lean):
```
V(a,b) = Σ {mb/a}·cot(πm/a)
       = Σ (((mb/a)) + 1/2)·cot(πm/a)
       = Σ ((mb/a))·cot(πm/a) + 0
```

This is a **hybrid sum**: cotangent weight × sawtooth argument.
The standard Dedekind sum uses sawtooth × sawtooth.

### 3. Reflection Symmetry ✅

```
V(a, a−b) = −V(a, b)    for coprime a,b
```

Proof: The involution m → a−m gives cot(π(a−m)/a) = −cot(πm/a)
and {(a−m)b/a} = 1 − {mb/a}, so the sum negates plus
an extra Σ cot term which vanishes by `cot_sum_vanishes`.

This is **provable in Lean** using existing infrastructure.

### 4. Dedekind Reciprocity ✅

```
s(a,b) + s(b,a) = (a² + b² + 1)/(12ab) − 1/4
```
PROVED in DedekindBridge.lean. Still valid, but does NOT
apply to V because V ≠ −2s.

### 5. All EntanglementBrake Theorems ✅

- `const_error_eq_neg_S_sq` — vᵀE_const = −S²
- `elog_dominant_factorization` — vᵀE_log = C·σ·S
- `reciprocal_sum_factorization` — Σ v·v·(1/j+1/k) = 2σS

These are pure algebra, unconditionally true.

## What V+V Actually Looks Like

The ratio V(a,b)+V(b,a) / (−2·(s(a,b)+s(b,a))) is NOT constant:

| (a,b) | V+V | −2(s+s) | Ratio |
|-------|-----|---------|-------|
| (3,2) | 0.192 | 0.111 | **√3** |
| (4,3) | 0.308 | 0.139 | 2.214 |
| (5,3) | 0.273 | 0.111 | 2.455 |
| (7,2) | −0.613 | −0.143 | 4.291 |
| (8,3) | −0.222 | −0.014 | **15.97** |
| (11,4) | −0.381 | −0.023 | **16.74** |

The ratio varies wildly. V+V is NOT a rational function of (a,b).

## Why V ≠ −2s

Per-term analysis for (a,b) = (5,3):

| m | V weight: cot(πm/5) | s weight: m/5 − 1/2 |
|---|---------------------|---------------------|
| 1 | **3.078** | −0.300 |
| 2 | **0.325** | −0.100 |
| 3 | −0.325 | 0.100 |
| 4 | −3.078 | 0.300 |

The cotangent weight cot(πm/a) is NOT proportional to the linear weight
m/a − 1/2 for any constant of proportionality. The Vasyunin sum is
genuinely transcendental — it involves irrational cotangent values
that do not reduce to rational arithmetic.

## Implications

1. **The "dissolution" was premature** — The cotangent quadratic form
   does NOT reduce to Dedekind reciprocity.

2. **The entanglement IS real** — Gemini was right: the cotangent
   coupling between V(j',k') and V(k',j') is genuinely
   transcendental and does not simplify.

3. **All other Thulium Session results stand** — The S² brake,
   σ·S factorization, and Dedekind reciprocity are all valid.

4. **The CotDedekindDissolution.lean theorems are valid algebra** —
   They just prove IF V+V = closed form THEN E_cot = rational.
   The hypothesis is false, so the conclusion is vacuously correct.

## What We Gained

Despite the false bridge, the Thulium Session produced:
- **cot_sum_vanishes**: A genuinely useful identity (Lean, 0 sorry)
- **Reflection symmetry**: V(a,a−b) = −V(a,b) (provable)
- **S² brake**: Unconditional downward force (Lean, 0 sorry)
- **σ·S factorization**: E_log structure (Lean, 0 sorry)
- **Numerical anatomy**: Crossover at N≈857, pair structure
- **Euler convergence**: (1−Gv)·lnN → e (needs confirmation)

The cotangent remains the hard piece. The entanglement is real.
