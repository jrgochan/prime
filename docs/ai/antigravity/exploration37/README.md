# Exploration 37: The GCD Strata and the Trinity of 1/12

## Session Summary — May 31, 2026

> "We just need to account for 12% and we have a 1/12 and there's a famous -1/12"

### What We Built

Four new Lean files, 30+ theorems, **zero sorry, zero axioms**:

| File | Theorems | Key Result |
|------|----------|------------|
| `RamanujanGCDStrata.lean` | 7 | R(da,db) = 1/(12ab) universal coprime kernel |
| `CoprimeInnerSum.lean` | 6 | 12Φ = S² - NCP; taper is the ENGINE of convergence |
| `TwelveBridge.lean` | 12 | Trinity of 1/12; Higgs anomaly localized to Δ = G - R |
| `AnomalyStrata.lean` | 5 | **Master theorem**: v^T G v = Σ R_d + Σ Δ_d |

### The Discovery: The Trinity of 1/12

Three appearances of the constant 1/12, now formally connected:

1. **ζ(-1) = -1/12** — Ramanujan's regularized sum (SilenceAndEcho.lean)
2. **R(k,k) = +1/12** — Constant diagonal of Ramanujan matrix (BernoulliSkeleton.lean)
3. **R(da,db) = 1/(12ab)** — Universal coprime kernel, d-independent (RamanujanGCDStrata.lean)

All three are B₂/2 = (1/6)/2 = 1/12, where B₂ is the second Bernoulli number.

### The Higgs Anomaly at d=2

The d=2 GCD stratum (the "Higgs sector" from ArithmeticSU2.lean) shows 12% sign disagreement with μ(d) at N=55,440. Tonight we proved:

- **Kernel**: R at d=1 ≡ R at d=2 (d-independent) → can't explain the 12%
- **Weights**: μ(2a)μ(2b) = μ(a)μ(b) (double flip cancels) → can't explain the 12%
- **∴ The 12% lives entirely in Δ = G - R** (the Archimedean anomaly)

### The Final Reduction

The Crown Axiom (`discrete_riemann_hypothesis`) now decomposes as:

```
v^T C v ≤ C/ln N
    ↕
[Σ R_d] + [Σ Δ_d] - (b^T v)² ≤ C/ln N
```

Three legs remain:

| Leg | Status | Infrastructure |
|-----|--------|---------------|
| **(b^T v)² = 1 + O(1/ln N)** | ✅ PROVED (moebius_mean_finite_bound) | AbelMean.lean |
| **Σ R_d = 1 + O(1/ln N)** | 🔧 Closeable (Smith PSD + Mertens) | BernoulliSkeleton.lean |
| **Σ Δ_d = O(1/ln N)** | 🎯 IS RH (Archimedean anomaly decay) | AnomalyStrata.lean |

### Connection to the Five Forward Paths

See detailed analyses in this folder:

- [Path A: Mellin Crown](path-a-mellin-crown.md) — The classical Mellin approach
- [Path B: GCD Strata](path-b-gcd-strata.md) — **WHERE WE DOVE TONIGHT** ⭐
- [Path C: Renormalization](path-c-renormalization.md) — Selberg-Delange α-decay
- [Path D: Smith Basis Change](path-d-smith-basis-change.md) — Sawtooth → BD bridge
- [Path E: Spectral/Overcancellation](path-e-spectral.md) — Wave converse + eta

### Files Modified

- `proofs/Cathedral/Covariance/RamanujanGCDStrata.lean` — NEW
- `proofs/Cathedral/Covariance/CoprimeInnerSum.lean` — NEW
- `proofs/Cathedral/Covariance/TwelveBridge.lean` — NEW
- `proofs/Cathedral/Covariance/AnomalyStrata.lean` — NEW
- `proofs/lakefile.lean` — Registered 4 new modules
- `papers/core/cathedral.tex` — Updated §6.2 (3→5 results, Covariance 24→28 files)
