# Character-Projected Spectral Probe — Results Report

**Experiment:** `experiments/character-spectral`  
**Date:** April 28, 2026  
**Precision:** 128-bit MPFR Jacobi eigensolve  
**Range:** N = 30, 50, 75, 100, 150, 200  
**Runtime:** 511.7s (12 threads, Apple Silicon)

---

## Executive Summary

The Nyman–Beurling Gram matrix G_N undergoes a **Poisson → GOE phase transition** at N ≈ 75. By decomposing G_N into residue class sub-matrices mod 8, we discover that this quantum chaos is an **emergent inter-class phenomenon**: each individual residue class remains Poisson through N = 200, but the coupled system develops GOE spectral rigidity.

Three key corrections to prior understanding:
1. The universality class is **GOE (β=1)**, not GUE (β=2) — the Gram matrix is real symmetric
2. Character weighting G_χ(j,k) = χ(j)·G(j,k)·χ(k) is **spectrally trivial** (similarity transform)
3. The dark sector (even indices) **develops correlations** at N ≥ 150, contrary to initial predictions

---

## 1. Character Decomposition Is Spectrally Trivial

### The Trap
All four Dirichlet characters mod 8 have the same support: the odd integers. The character-weighted Gram matrix G_χ(j,k) = χ(j)·G(j,k)·χ(k) is related to G by a diagonal similarity transform D·G·D where D = diag(χ(k)) and D² = I. Similarity transforms preserve eigenvalues exactly.

### Consequence
**All four character channels produce identical eigenvalue spectra** (ρ = 1.0000 between all pairs). The character decomposition from `GallagherPartition.lean` is an energy (L²) partition, not a spectral (eigenvalue) partition. This is a theorem, not a numerical artifact.

### Resolution
Residue class decomposition (k ≡ 1, 3, 5, 7 mod 8) selects genuinely different sub-matrices of G_N, producing distinct eigenvalue spectra.

---

## 2. Residue Classes Have Distinct Spectra

Eigenvalue extrema at N = 200:

| Channel | dim | λ_min | λ_max | κ(G) |
|---------|-----|-------|-------|------|
| Full G_N | 199 | 3.17e-5 | 3.839 | 1.21e5 |
| k≡1(8) | 24 | 2.51e-4 | 0.414 | 1.65e3 |
| k≡3(8) | 25 | 2.48e-4 | 0.569 | 2.29e3 |
| k≡5(8) | 25 | 2.38e-4 | 0.495 | 2.08e3 |
| k≡7(8) | 25 | 2.19e-4 | 0.450 | 2.06e3 |
| Odd | 99 | 6.65e-5 | 1.875 | 2.82e4 |
| Dark (even) | 100 | 5.98e-5 | 1.982 | 3.31e4 |

**k≡3(8) carries 37% more spectral weight** (λ_max) than k≡1(8). The residue classes are not equivalent — they encode different arithmetic structure.

---

## 3. Quantum Chaos Is Emergent

### The Phase Transition Cascade

| N | Full G_N | k≡1(8) | k≡3(8) | k≡5(8) | k≡7(8) | Odd | Dark |
|---|---------|--------|--------|--------|--------|-----|------|
| 30 | Poisson | N/A | Poisson | Poisson | N/A | Poisson | Poisson |
| 50 | Poisson | Poisson | Poisson | Poisson | Poisson | Poisson | Poisson |
| 75 | **GOE** | Poisson | Poisson | Poisson | Poisson | Poisson | Poisson |
| 100 | **GOE** | Poisson | Poisson | Poisson | Poisson | **GOE** | Poisson |
| 150 | **GOE** | Poisson | Poisson | Poisson | Poisson | Poisson | **GOE** |
| 200 | **GOE** | Poisson | Poisson | Poisson | Poisson | **GOE** | **GOE** |

### Interpretation
The GOE transition occurs **only when multiple residue classes interact**. Each isolated sub-lattice is an integrable system (Poisson). The coupling between arithmetic progressions creates geometric frustration → spectral rigidity → quantum chaos.

This is precisely the "cross-talk between syndrome channels" predicted by the Cathedral architecture.

---

## 4. Van Hove Singularity Improved Within Residue Classes

The logarithmic singularity fit ρ(E) = A·ln|E - E₀| + B is significantly better within homogeneous residue classes:

| N=50 | Full | k≡1(8) | k≡3(8) | k≡5(8) | k≡7(8) |
|------|------|--------|--------|--------|--------|
| R² | 0.708 | **0.867** | **0.905** | **0.890** | **0.883** |

The Van Hove singularity characteristic of 2D spatial geometry is **cleaner within each arithmetic sub-sector**. Mixing the sectors introduces the fractal arithmetic topology that corrupts the flat-lattice fit.

---

## 5. Dark Sector Awakens

Initial prediction: the dark sector (even indices) should remain Poisson because characters don't see it.

**Reality:** Dark sector transitions to GOE at N ≈ 150.

This means the Gram matrix coupling between even and odd indices is strong enough to transmit spectral correlations into the even sector at large N. The dark sector is "heated" by the arithmetic activity in the odd sector through the off-diagonal G(j,k) entries where j is odd and k is even.

---

## 6. Cross-Channel Entanglement Grows

Pearson ρ between residue class eigenvalue staircases:

| N | k≡1 vs k≡3 | k≡1 vs k≡5 | k≡1 vs k≡7 | k≡3 vs k≡5 | k≡3 vs k≡7 | k≡5 vs k≡7 |
|---|-----------|-----------|-----------|-----------|-----------|-----------|
| 30 | 0.54 | 0.48 | 0.44 | 0.63 | 0.51 | 0.54 |
| 50 | 0.70 | 0.70 | 0.78 | 0.76 | 0.70 | 0.76 |
| 75 | 0.81 | 0.82 | 0.88 | 0.84 | 0.81 | 0.87 |
| 100 | 0.84 | 0.86 | 0.93 | 0.88 | 0.85 | 0.91 |
| 150 | 0.87 | 0.90 | 0.94 | 0.92 | 0.89 | 0.93 |
| 200 | 0.89 | 0.92 | **0.96** | 0.92 | 0.91 | 0.95 |

The k≡1 and k≡7 classes are the most correlated (ρ → 0.96), consistent with them being "conjugate" under multiplication by 7 ≡ -1 (mod 8).

---

## 7. Connection to Cathedral Formal Proofs

| Lean Theorem | Experimental Validation |
|---|---|
| `FrequencySeparation.lean`: δ-separated frequencies | Each residue class has distinct λ_min, confirming frequency isolation |
| `GallagherPartition.lean`: orthogonal energy partition | Confirmed — but partition is in L² norm, not eigenvalue spectrum |
| `χ₈_orthogonality`: character orthogonality | Verified numerically (16/16 pairs match) |
| `discrete_energy_partition`: 4-channel partition | Energy partitions correctly, but eigenvalues are identical across channels |

### What Cannot Be Formalized
- Phase transition thresholds (N_c ≈ 75) — these are finite-size effects, not asymptotic theorems
- Level spacing universality class (GOE) — statistical, not algebraic
- Cross-channel correlation growth — empirical observation

---

## 8. Open Questions for Future Work

1. **Does the GOE transition in residue classes occur at higher N?** (N ≈ 500 might reveal per-class chaos)
2. **Why k≡3(8) has the most spectral weight** — is this related to 3 being the first odd prime?
3. **Can we detect the transition to GUE at even higher N?** (GUE would require complex entries, so probably not for this real matrix)
4. **Character-weighted analysis on the FULL matrix** (not sub-matrices) — project onto Fourier components without restricting to support

---

## Appendix: File Inventory

All data in `experiments/character-spectral/results/`:
- `eigenvalues_{full,res1,res3,res5,res7,odd,even}_N{n}.tsv`
- `spacing_N{n}.tsv` — per-channel universality class fits
- `van_hove_N{n}.tsv` — Van Hove singularity parameters per channel
- `cross_corr_N{n}.tsv` — Pearson ρ between channel staircases
- `certificate.json` — machine-readable summary
- `run_residue_N200.log` — full terminal output
