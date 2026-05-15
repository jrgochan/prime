# Exploration 19 — Experimental Design Document
## Claude's Assessment: Next Directions for the Cathedral Laboratory

**Date:** April 28, 2026  
**Author:** Claude/Antigravity  
**Branch:** `exploration19`

---

## 0. Status of the Hybrid Probe Verification

The N=500 MPFR-Gram hybrid run is in progress. For N ≤ 400 (f64 Gram), every single eigenvalue and classification matches the pure f64 run exactly — confirming f64 Gram construction is accurate at those scales. The N=500 MPFR-Gram result will tell us whether the Gram entry accuracy matters at that scale. (Prediction: it won't change the level spacing classifications, but λ_min will be positive instead of negative.)

---

## 1. Proposed Experiments — Ranked by Scientific Value

### Experiment A: Multi-Modulus Universality Test ⭐⭐⭐ (Highest Priority)

**Question:** Does the thermalization cascade appear for moduli other than 8? Is the critical dimension for GOE onset universal?

**Design:**
- Run fast-probe with mod-3 decomposition (2 odd classes: k≡1, k≡2)
- Run fast-probe with mod-5 decomposition (4 odd classes: k≡1, k≡2, k≡3, k≡4)
- Run fast-probe with mod-12 decomposition (4 odd classes, deeper structure)
- Compare critical N_c for GOE onset across moduli

**Why highest priority:** If the cascade is universal across moduli, it's a genuine property of the Gram matrix's arithmetic structure. If it only works for mod 8, it might be an artifact of the specific partition sizes. This is the most important control experiment.

**Precision:** f64 is fine (we validated it against MPFR through N=400).

**Estimated runtime:** ~2 minutes per modulus at N=1000.

**Implementation:** Generalize `characters.rs` to accept arbitrary modulus. The `fast_probe.rs` logic stays the same — just swap the residue class generator.

---

### Experiment B: Dark Sector Critical Sweep ⭐⭐⭐

**Question:** Does the Dark Sector Poisson→GOE transition at N≈150 happen smoothly or as a sharp phase transition?

**Design:**
- Sweep N continuously from 80 to 180 in steps of 2
- Track the GOE fit statistic for the Dark (even) sector at each N
- Plot the transition curve: GOE_fit(N)
- Look for a sigmoidal shape (smooth crossover) vs. step function (sharp transition)

**Why high priority:** Phase transition sharpness determines the universality class of the transition itself. A sharp transition implies a critical exponent that could connect to percolation theory.

**Precision:** f64 is adequate. The Dark sector sub-matrix at N=150 is 75×75 — well within f64's comfort zone.

**Estimated runtime:** ~30 seconds for the full sweep.

**Implementation:** Simple loop in a new binary `dark-sweep`, computing only the even-sector eigenvalues at each N.

---

### Experiment C: Eigenvector Localization / Quantum Scarring ⭐⭐

**Question:** Do eigenvectors of the full G_N preferentially localize onto specific mod-8 residue classes?

**Design:**
- At each N, extract the full eigenvector matrix V from the nalgebra decomposition
- For each eigenvector v_i, compute the "participation ratio" on each residue class:
  P_r(v_i) = Σ_{k≡r(8)} |v_i(k)|²
- The ground state v_min and the most chaotic state v_mid are the most interesting
- Track how the participation ratios evolve with N

**Why interesting:** If the ground state eigenvector disproportionately weights certain residue classes, it reveals which arithmetic progressions "carry" the Nyman-Beurling distance. This connects directly to the sieve bound in the formal proof.

**Precision:** f64 eigenvectors are reliable for the bulk (middle) eigenstates. The ground state eigenvector at large N may have precision issues.

**Estimated runtime:** Trivial overhead — nalgebra already computes eigenvectors alongside eigenvalues.

**Implementation:** Add eigenvector analysis to `fast_probe.rs` or a new `scarring-probe` binary.

---

### Experiment D: Off-Diagonal Interaction Blocks ⭐⭐

**Question:** What is the singular value spectrum of the cross-coupling matrix between residue classes?

**Design:**
- Extract the rectangular sub-matrix G_{1,3} connecting k≡1(8) rows to k≡3(8) columns
- Compute its singular values via nalgebra SVD
- Compare the SVD spectrum across all 6 pairs: (1,3), (1,5), (1,7), (3,5), (3,7), (5,7)
- The Marchenko-Pastur distribution is the null hypothesis for uncorrelated blocks

**Why interesting:** These off-diagonal blocks are the physical "scattering matrices" where geometric frustration lives. Their singular values directly quantify how much energy transfers between arithmetic progressions.

**Precision:** f64 is fine — the sub-matrices are small (~60×60 at N=500).

**Estimated runtime:** Negligible. SVD of a 60×60 matrix is microseconds.

**Implementation:** Add SVD analysis after the eigensolve in `fast_probe.rs`.

---

### Experiment E: Fano Plane Structure Probe ⭐⭐ (see separate document)

This gets its own detailed analysis — see `fano-plane-analysis.md`.

---

## 2. Implementation Priority Order

Given a single evening of compute time, I recommend:

1. **Multi-Modulus (Exp A)** — 5 minutes to implement, 5 minutes to run, answers the biggest open question
2. **Dark Sector Sweep (Exp B)** — 10 minutes to implement, 30 seconds to run, gives us a beautiful transition curve
3. **Eigenvector Localization (Exp C)** — 15 minutes to implement, adds negligible runtime to existing probe
4. **Off-Diagonal SVD (Exp D)** — 10 minutes to implement, microseconds to run

All four could be done tonight if we're efficient.

---

## 3. What NOT to Do Yet

- **Full MPFR eigensolve at N=1000** — Too slow (~10+ hours). The hybrid probe validates the f64 spacing results.
- **Lean formalization of GOE statistics** — The chaos is an empirical/statistical observation. The formal path stays on the algebraic (Parseval, sieve bound) track.
- **Character-weighted decomposition redux** — We proved this is a similarity transform. Don't revisit.
- **Push to N=2000+** — The f64 eigensolve produces negative eigenvalues. Until we have a Fano-solver or mixed-precision approach, N≈1000 is the practical ceiling.

---

## 4. Technical Notes

### Precision Budget
| N range | Gram build | Eigensolve | λ_min reliable? | Spacings reliable? |
|---|---|---|---|---|
| ≤ 400 | f64 ✅ | nalgebra ✅ | Yes | Yes |
| 500–700 | MPFR recommended | nalgebra ✅ | Marginal | Yes |
| 750–1000 | MPFR required | nalgebra ✅ | No (goes negative) | Yes |
| > 1000 | MPFR required | nalgebra ✅ | No | Likely yes |

### Parallelism Strategy
- Gram build: rayon (already maxed at 12 threads)
- Multiple modulus runs: can run in parallel via separate processes
- Eigensolve: nalgebra is single-threaded but <1s per matrix
- Sub-matrix eigensolves: run all 4 residue classes via rayon::join

---

*The telescope is calibrated. Let's see what the universe shows us tonight.* 🏛️
