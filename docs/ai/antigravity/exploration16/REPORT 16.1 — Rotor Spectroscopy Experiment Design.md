# 🔬 REPORT 16.1 — Rotor Spectroscopy: The 8-Dimensional Character Space

**From**: Antigravity (Claude)  
**Date**: April 27, 2026, 20:49 MDT  
**Phase**: Curator — Numerical Exploration  
**Branch**: `exploration16`

---

## 1. OBJECTIVE

Build a comprehensive, production-grade Rust experiment that performs
**spectroscopy** of the mod-8 character partition — the "Stained Glass
Rotors" of the Cathedral.

The Lean proofs in `GallagherPartition.lean` and `GallagherMVT.lean`
establish that the Dirichlet polynomial energy decomposes exactly into
4 orthogonal character channels. This experiment will:

1. **Measure** the energy distribution across all 4 channels for varying N
2. **Test** whether geometric frustration (equal 25% per channel) holds
3. **Validate** the Gallagher MVT spectral isolation at finite N
4. **Explore** the 8-dimensional residue class structure of the BD weights
5. **Certify** the dispersion relation (log-frequency separation)

---

## 2. THE PHYSICS

### 2.1 The Character Partition (Proved in Lean)

The Lean theorem `discrete_energy_partition` states:

$$\sum_{k=1}^{N-1} |v_k|^2 = \frac{1}{4} \sum_{i=1}^{4} \sum_{k} |\chi_i(k)|^2 \cdot |v_k|^2$$

where $\chi_1, \chi_2, \chi_3, \chi_4$ are the Dirichlet characters mod 8.
For the BD log-taper weights $v_k = -\mu(k)(1 - \ln k / \ln N)$, we can
measure how the energy distributes across channels.

### 2.2 The 8 Residue Classes

The integers mod 8 fall into residue classes with distinct character:

| k mod 8 | χ₁(k) | χ₂(k) | χ₃(k) | χ₄(k) | Physics |
|---------|-------|-------|-------|-------|---------|
| 1       | 1     | 1     | 1     | 1     | All channels active |
| 3       | 1     | 1     | -1    | -1    | Channels 1,2 only |
| 5       | 1     | -1    | 1     | -1    | Channels 1,3 only |
| 7       | 1     | -1    | -1    | 1     | Channels 1,4 only |
| 2,4,6,0 | 0     | 0     | 0     | 0     | Dark (even k → μ(k)=0 for k≥4) |

The "dark" classes (even residues) contribute zero to squarefree sums.
The experiment measures the energy split across the 4 active channels
for the odd residue classes.

### 2.3 The Gallagher MVT

The Gallagher Mean Value Theorem gives:
$$\int_{-\infty}^{\infty} \left|\sum_k v_k \cdot k^{-it}\right|^2 K_\delta(t)\,dt = \sum_k |v_k|^2$$

where $K_\delta$ is the Fejér kernel with $\delta = 1/(N+1)$. This is the
**completeness relation**: the total spectral energy equals the sum of
squared amplitudes.

### 2.4 The Dispersion Relation

The log-frequencies $\lambda_k = \log(k)$ are separated by:
$$|\lambda_j - \lambda_k| = |\log(j/k)| \geq \log(1 + 1/N) \geq 1/(N+1)$$

for $j \neq k$ with $1 \leq j, k \leq N$. This is the **spectral gap**
that enables mode resolution.

---

## 3. EXPERIMENT DESIGN

### 3.1 Sections (matching crown-cancellation quality)

```
§A. SIEVE VALIDATION — μ(k) correctness + squarefree statistics
§B. CHARACTER TABLE — explicit χ₁..χ₄ mod 8, orthogonality check
§C. ENERGY PARTITION — per-channel energy fractions vs N
§D. RESIDUE CLASS DECOMPOSITION — v_k² by k mod 8
§E. SPECTRAL PROFILE — |D_N(1/2+it)|² on critical line, per-channel
§F. GALLAGHER MVT VALIDATION — ∫|D_N|²·K_δ vs Σ|v_k|²
§G. DISPERSION RELATION — min |λ_j - λ_k| vs 1/(N+1)
§H. SCALING LAW — channel energy fractions vs N (asymptotic equipartition?)
```

### 3.2 Output

- **TSV files** per section for plotting
- **JSON certificate** with all measured quantities
- **Terminal output** with formatted tables, check marks, and color

### 3.3 Parameters

| Parameter | Default | High-N mode |
|-----------|---------|-------------|
| max_N | 10,000 | 100,000+ |
| t_max (spectral profile) | 200.0 | 500.0 |
| GL quadrature order | GL8 | GL8 |
| Parallelism | rayon (all cores) | rayon |

### 3.4 Key Predictions

1. **Equipartition**: As N → ∞, each channel should carry ≈25% of the
   total energy (geometric frustration).
2. **Orthogonality**: Cross-channel correlations should be numerically zero.
3. **Gallagher**: The MVT integral should equal Σ|v_k|² to machine precision.
4. **Dispersion**: The minimum gap should track 1/(N+1) closely.
5. **Residue asymmetry**: At finite N, the k≡1 (mod 8) class may dominate
   since it's the only class contributing to all 4 channels.

---

## 4. WHAT THIS VALIDATES

### In the Cathedral

- `discrete_energy_partition` (GallagherPartition.lean) — numerically
- `gallagher_mvt` (GallagherMVT.lean) — numerically
- `log_frequencies_separated` (FrequencySeparation.lean) — numerically
- `χ₈_orthogonality` (GallagherPartition.lean, by native_decide) — independently

### In the Physics Paper

- **§5 NEW**: Quantum error-correcting code (stabilizer syndrome channels)
- **§5 NEW**: Completeness relation (Gallagher MVT)
- **§5 NEW**: Dispersion relation (log-frequency separation)
- **Appendix A**: Stained Glass Rotors phenomenon table

### For the Bounty Board

If equipartition **fails** at large N, it would suggest the mod-8 channels
are not uniformly loaded — which could provide a handle for closing
Axiom 1 (covariance bound) via a channel-specific argument.

---

## 5. IMPLEMENTATION NOTES

### Matching crown-cancellation quality

1. **Sieve**: Reuse the proven `mobius_sieve` implementation
2. **Parallelism**: `rayon` for GL8 panel integration
3. **Formatting**: Same `fmt.rs` module with ANSI colors, check marks
4. **Certificate**: JSON output with timestamp, precision, all results
5. **TSV output**: Machine-readable for plotting
6. **CLI argument**: `cargo run --release -- [max_N]`

### No MPFR needed

Unlike crown-cancellation (which needs 512-bit zeta evaluation), this
experiment works with f64 throughout — the character values are exact
integers {-1, 0, 1}, the sieve is exact, and the energy computation
is O(N) per point with no catastrophic cancellation.

This means it can run to **much larger N** (100K+) in reasonable time.

---

*Antigravity, awaiting green light to build. 🏛️🤍*
