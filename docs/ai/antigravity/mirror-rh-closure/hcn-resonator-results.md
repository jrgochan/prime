# HCN Resonator Results: Fejér-Möbius Weights at Highly Composite Numbers

**Date:** May 29, 2026
**Directive:** Gemini (Theorist) — "RE: THE UV CATASTROPHE & THE HCN RESONATOR"
**Experiment:** Dyson Protocol §4 — Fejér-Möbius weights v_k = -μ(k)(1 - ln k / ln N)
**N_max:** 2520 | **Total time:** 1820.66s

## §1. The Hypothesis (Gemini)

Gemini predicted that the Fejér-Möbius (Wilsonian UV cutoff) weights would produce
dramatically lower d²_BD at Highly Composite Numbers (HCNs) compared to non-HCN
neighbors, because the Wilsonian cutoff aligns with the harmonic lattice of the integers.

## §2. Results: HCN Values

| N (HCN) | d²_saw(FM) | vᵀΔ_true v | d²_BD(FM) | d²_opt | FM/opt ratio |
|---------|-----------|------------|-----------|--------|-------------|
| 120 | +0.236 | -0.233 | **0.0665** | 0.0429 | 1.55× |
| 180 | +0.286 | -0.245 | **0.0733** | 0.0426 | 1.72× |
| 240 | +0.334 | -0.289 | **0.0785** | 0.0422 | 1.86× |
| 360 | +0.422 | -0.396 | **0.0857** | 0.0420 | 2.04× |
| 720 | +0.643 | -0.654 | **0.0973** | 0.0415 | 2.34× |
| 840 | +0.702 | -0.698 | **0.0997** | 0.0415 | 2.40× |
| 1260 | +0.917 | -0.952 | **0.1059** | 0.0414 | 2.56× |
| 1680 | +1.084 | -1.049 | **0.1098** | 0.0413 | 2.66× |
| 2520 | +1.423 | -1.376 | **0.1154** | 0.0412 | 2.80× |

## §3. Results: Non-HCN Neighbors

| N | d²_saw(FM) | vᵀΔ_true v | d²_BD(FM) | d²_opt | FM/opt ratio |
|---|-----------|------------|-----------|--------|-------------|
| 100 | +0.210 | -0.164 | **0.0630** | 0.0431 | 1.46× |
| 150 | +0.263 | -0.243 | **0.0703** | 0.0427 | 1.65× |
| 200 | +0.312 | -0.321 | **0.0757** | 0.0425 | 1.78× |
| 300 | +0.387 | -0.396 | **0.0827** | 0.0421 | 1.96× |
| 500 | +0.521 | -0.542 | **0.0915** | 0.0418 | 2.19× |
| 700 | +0.630 | -0.633 | **0.0968** | 0.0415 | 2.33× |

## §4. Analysis

### Finding 1: Fejér-Möbius VASTLY outperforms Born
The FM/optimal ratio stays between **1.5×–2.8×**, compared to the Born Protocol's
**3615× at N=2520**. The Wilsonian UV cutoff is doing its job — it tames the UV
catastrophe by 1000×.

### Finding 2: HCN resonance NOT confirmed
Contrary to Gemini's prediction, non-HCN neighbors show **similar or slightly better**
performance than HCNs at comparable N:
- N=100 (non-HCN): 0.0630 vs N=120 (HCN): 0.0665
- N=300 (non-HCN): 0.0827 vs N=360 (HCN): 0.0857
- N=700 (non-HCN): 0.0968 vs N=720 (HCN): 0.0973

The HCN effect does NOT appear in d²_BD(FM). The anomaly cancellation is
equally effective at all N values, not preferentially at HCNs.

### Finding 3: d²_BD(FM) is INCREASING
d²_BD(FM) grows from 0.063 at N=100 to 0.115 at N=2520. The Fejér-Möbius weights
are NOT the optimal trial wavefunction — they provide a finite but non-closing upper bound.

### Finding 4: Beautiful anomaly cancellation
The anomaly scattering (vᵀΔ_true v) almost perfectly cancels d²_saw(FM):
- N=2520: +1.423 - 1.376 = 0.047 residual (97% cancellation!)
- But this residual GROWS with N, so it doesn't close.

## §5. Physics Interpretation

The Fejér-Möbius weights are the **Renormalized vacuum** — they tame the UV catastrophe
by a factor of 1000× compared to bare weights. But they're still not optimal because:

1. The Wilsonian cutoff is too blunt — it kills ALL high-frequency modes, not just
   the scattered ones.
2. The optimal weights v* = G⁻¹b require full knowledge of the Green's function G.
3. No trial wavefunction with a simple analytic form can replicate the precise
   mode-by-mode cancellation that v* achieves.

**The key insight stands:** (-∞) + (+∞) = 0.042 is the content of RH.
Trial wavefunctions can approximate this, but closing the gap requires
understanding WHY the optimal weights achieve exact cancellation.

## §6. Comparison Table

| Method | d²_BD at N=500 | Ratio to optimal | Status |
|--------|---------------|-----------------|--------|
| Optimal (v* = G⁻¹b) | 0.0418 | 1.00× | ✅ (by definition) |
| Fejér-Möbius | 0.0915 | 2.19× | ❌ (grows with N) |
| Born (bare weights) | 114.3 | 2733× | ❌❌❌ (explodes) |

## §7. Next Steps

1. **Spectral analysis of G:** Decompose the Green's function to understand
   what makes v* = G⁻¹b special.
2. **Neumann series:** Try G⁻¹ = R_true⁻¹ (I + ΔR_true⁻¹)⁻¹ to get a
   perturbative expansion of the optimal weights.
3. **GPU run at N=10,000:** See if d²_opt continues its monotone decline.
