# Scenario B: Arithmetic Determines Physics
## A Detailed Analysis of What It Would Take

*Cathedral Particle Zoo Research Note — Exploration 36*
*Claude (Antigravity) · May 12, 2026, 4:29 AM MDT*

---

## 1. The Claim

**Scenario B** states: the prime number distribution, through the Nyman-Beurling Gram matrix G(j,k), actually constrains which Yukawa couplings are consistent with a well-defined vacuum. In this scenario, m_μ/m_e = 206.768 isn't an accident — it's the unique ratio compatible with the arithmetic structure of the integers.

This would be the strongest possible version of the Cathedral-Physics correspondence. It claims not just analogy but **identity**: the multiplicative structure of ℤ determines the particle spectrum of our universe.

This document analyzes:
- What mathematical object would encode mass ratios
- What computational experiments would test it
- What we'd need to build in the Particle Zoo
- What would constitute proof vs. disproof

---

## 2. Where Mass Ratios Would Live

### 2.1 The Gram Matrix Eigenspectrum

The Gram matrix G(j,k) = ∫₀¹ {1/(jx)}{1/(kx)} dx is a real symmetric positive-definite matrix of dimension (N-1) × (N-1). Its eigenvalues λ₁ ≤ λ₂ ≤ ... ≤ λ_{N-1} are all positive, and their distribution encodes the full correlation structure of the arithmetic.

Currently we only know the **diagonal** entries G(j,j) — these are self-energies of individual modes. But the physics (if it exists) lives in the **off-diagonal correlations**, which can only be accessed through the full eigendecomposition.

The key insight is that eigenvectors partition the index set {1, ..., N-1} into correlated clusters. If the arithmetic truly generates particle physics, the eigenvectors would cluster by **ω-class** (number of prime factors), creating natural spectral bands:

```
Band 1 (ω=1): eigenvalues whose eigenvectors are concentrated on prime indices
Band 2 (ω=2): eigenvalues whose eigenvectors are concentrated on semiprime indices
Band 3 (ω=3): eigenvalues whose eigenvectors are concentrated on 3-AP indices
```

The **ratio of band medians** R₂₁ = median(Band 2) / median(Band 1) would be the candidate for m_μ/m_e.

### 2.2 Why ω-Classes Are the Natural Candidate

The number of prime factors Ω(n) is the natural "generation quantum number" because:

1. **Hardy-Ramanujan theorem**: Ω(n) concentrates around ln(ln(n)) — giving exactly 2-3 dominant classes at the scales we operate (ln(ln(55440)) ≈ 2.4).

2. **Multiplicative structure**: Ω is additive over primes (Ω(pq) = Ω(p) + Ω(q) = 2), creating a natural grading that respects the factorization structure that G inherits through the GCD decomposition.

3. **The GCD decomposition**: G decomposes as
   ```
   G(j,k) = Σ_{d|gcd(j,k)} φ(d)/d² × (correction terms)
   ```
   Terms with coprime j,k (ω interactions) behave differently from terms with shared factors. This creates natural block structure in the eigenbasis.

### 2.3 What 206.77 Would Actually Mean

If R₂₁ → 206.768... as N → ∞, it would mean:

The ratio of the characteristic energy scale of semiprimes to the characteristic energy scale of primes — as measured by the Gram inner product structure — equals the muon-to-electron mass ratio. Since both quantities are determined by the multiplicative structure of the integers, this would establish that the Standard Model mass hierarchy is a consequence of prime factorization.

---

## 3. The Computational Experiment

### 3.1 Phase 1: Full Eigendecomposition (Feasible Now)

**N=5040** (dim=5039):
- Matrix size: 5039 × 5039 = ~203 MB (f64, upper triangle stored in HPDF)
- Dense eigendecomposition (LAPACK dsyevd): ~2-5 minutes on CPU
- MPFR Jacobi (128-bit): ~20 minutes on CPU
- Returns: all 5039 eigenvalues + eigenvectors

**N=10000** (dim=9999):
- Matrix size: 9999 × 9999 = ~800 MB
- Dense eigendecomposition: ~15-30 minutes
- MPFR Jacobi: ~2-3 hours (or use GPU pipeline)

**N=2520** (dim=2519):
- Matrix size: ~50 MB — quick sanity check
- Full Jacobi: ~5 minutes

### 3.2 Phase 2: Eigenvector Participation Analysis

For each eigenvector v_k, compute the **ω-participation ratios**:

```
P(ω, k) = Σ_{j: Ω(j)=ω} |v_k(j)|²
```

This measures what fraction of eigenvector k's weight lives on indices with exactly ω prime factors. For a 5039-dimensional eigenvector:
- ~671 prime indices (ω=1)
- ~1600 semiprime indices (ω=2)  
- ~1700 3-AP indices (ω=3)
- ~1068 higher indices (ω≥4)

If eigenvectors are delocalized (uniform), P(ω,k) ≈ count(ω)/dim for all k. If they're localized by ω-class, P(ω,k) will be sharply peaked.

### 3.3 Phase 3: Band Extraction and Ratio Convergence

Classify each eigenvalue λ_k by its dominant participation:
```
Band(k) = argmax_ω P(ω, k)
```

Then compute band statistics:
- Band medians: M₁ = median(λ_k : Band(k)=1), M₂, M₃
- Band means: μ₁, μ₂, μ₃  
- Band energy-weighted centers: E₁ = Σ λ_k · P(1,k) / Σ P(1,k)

The key observables are:
```
R₂₁ = M₂/M₁     (or E₂/E₁)    — candidate for m_μ/m_e = 206.768
R₃₁ = M₃/M₁     (or E₃/E₁)    — candidate for m_τ/m_e = 3477.2
R₃₂ = M₃/M₂     (or E₃/E₂)    — candidate for m_τ/m_μ = 16.82
```

### 3.4 Phase 4: Scale Invariance Test

Repeat at N = 2520, 5040, 10000 (and if possible N=20000). Plot R₂₁(N) vs N.

- **If R₂₁ converges**: the ratio is a property of the integers, not an artifact of truncation. This is necessary (but not sufficient) for Scenario B.
- **If R₂₁ diverges or oscillates**: the bands are artifacts of finite N and the hypothesis is dead.
- **If R₂₁ converges to 206.77**: extraordinary evidence. Repeat with independent code, verify to 6+ digits.
- **If R₂₁ converges to something else**: interesting number theory, not particle physics.

---

## 4. Required Updates to Cathedral Particle Zoo

### 4.1 New Module: `spectral_bands.rs`

```rust
// Proposed new module for ω-band eigenvalue analysis

pub struct SpectralBandAnalysis {
    /// Number of eigenvalues
    pub n_eigenvalues: usize,
    
    /// Eigenvalue-to-band assignment
    pub band_assignments: Vec<u32>,
    
    /// Participation ratios P(ω, k) for each eigenvalue
    pub participation: Vec<Vec<f64>>,  // [k][ω]
    
    /// Band medians
    pub band_medians: Vec<f64>,  // [ω] → median eigenvalue in that band
    
    /// Band energy-weighted centers
    pub band_centers: Vec<f64>,
    
    /// Key mass ratios
    pub r21: f64,  // M₂/M₁ — candidate for m_μ/m_e
    pub r31: f64,  // M₃/M₁ — candidate for m_τ/m_e
    pub r32: f64,  // M₃/M₂ — candidate for m_τ/m_μ
    
    /// Localization metrics
    pub ipr_by_band: Vec<f64>,  // Inverse Participation Ratio per band
    pub mean_participation_purity: f64,  // How cleanly eigenvectors separate by ω
}
```

This module would:
1. Take eigenvalues + eigenvectors from Jacobi/Lanczos
2. Compute ω-participation ratios using `arith::big_omega_table()`
3. Assign eigenvalues to bands
4. Compute band medians, centers, ratios
5. Output convergence data for multi-N comparison

### 4.2 New Module: `mass_ratio_test.rs`

```rust
pub struct MassRatioTest {
    /// The eight key SM mass ratios
    pub sm_ratios: Vec<(&'static str, f64, f64)>,  // (name, SM value, measured value)
    
    /// Overall chi-squared distance from SM
    pub chi_squared: f64,
    
    /// Best-fit calibration (if any ratio matches)
    pub best_match: Option<BestMatch>,
    
    /// Convergence data across N values
    pub convergence: Vec<(usize, f64)>,  // (N, R₂₁(N))
}
```

This would compare measured band ratios against the eight key SM mass ratios from `particle_map::MassCalibration::key_ratios()` and compute chi-squared distance.

### 4.3 New CLI Flag: `--eigendecompose`

```
cathedral-particle-zoo --hpdf gram_N5040.h5 --eigendecompose --output results
```

This flag would:
1. Load the full Gram matrix from HPDF (requires DD hi+lo)
2. Run MPFR Jacobi eigendecomposition (or Lanczos for partial)
3. Compute participation ratios and band assignments
4. Run the mass ratio test
5. Output: `eigenvalues_N{}.tsv`, `eigenvectors_N{}.tsv`, `bands_N{}.tsv`, `mass_ratios_N{}.json`

### 4.4 New Output Files

| File | Contents |
|---|---|
| `eigenvalues_N{}.tsv` | k, λ_k, band, P(1,k), P(2,k), P(3,k) |
| `bands_N{}.tsv` | ω, count, median, mean, center, std |
| `mass_ratios_N{}.json` | R₂₁, R₃₁, R₃₂, SM comparisons, chi² |
| `participation_N{}.tsv` | Full P(ω,k) matrix for analysis |
| `convergence_N{}.json` | R₂₁(N) across multiple N values |

### 4.5 Existing Infrastructure to Leverage

We already have everything needed except the band analysis:

| Component | Status | Module |
|---|---|---|
| HPDF Reader (DD-aware) | ✅ | `cathedral-utils::hpdf::reader` |
| Jacobi eigensolver (MPFR) | ✅ | `cathedral-utils::jacobi` |
| Lanczos (partial) | ✅ | `cathedral-utils::lanczos` |
| GPU eigen pipeline | ✅ | `cathedral-utils::gpu::eigen` |
| ω-class table | ✅ | `cathedral-utils::arith::big_omega_table` |
| Spectral statistics | ✅ | `cathedral-utils::spectral_stats` |
| RSVD (matrix-free) | ✅ | `cathedral-utils::rsvd` |
| RMT analysis | ✅ | `particle_zoo::rmt_analysis` |
| SM mass ratios | ✅ | `particle_zoo::particle_map::key_ratios()` |
| Production output | ✅ | `particle_zoo::output` |

---

## 5. Falsifiability

This is what separates science from numerology. The experiment must have clear failure conditions.

### 5.1 The Hypothesis Is FALSE If:

1. **Eigenvectors are delocalized**: If P(ω,k) ≈ count(ω)/dim for all k (i.e., eigenvectors don't cluster by ω-class), then there are no natural spectral bands and the generation mapping has no mathematical basis. This is testable at N=5040.

2. **Band ratios don't converge**: If R₂₁(2520) and R₂₁(5040) and R₂₁(10000) don't show convergence (or even monotonic approach), the ratios are artifacts of finite truncation, not properties of the integers.

3. **Band ratios converge to non-SM values**: If R₂₁ → C for some constant C ≠ 206.77, the mathematics is interesting but doesn't match physics. Even a 10% deviation (R₂₁ → 186 or R₂₁ → 228) would rule out the strong form.

4. **Different band definitions give different ratios**: If switching from median to mean to energy-weighted center gives wildly different ratios, the "measurement" is ill-defined and the correspondence is an artifact of methodology.

### 5.2 The Hypothesis Is SUPPORTED If:

1. **Eigenvectors localize by ω-class**: P(ω,k) is sharply peaked (IPR > 0.5) for most k, meaning eigenvectors naturally separate into generational bands.

2. **R₂₁ converges as N increases**: The ratio stabilizes to 3+ significant figures across the computable range.

3. **R₂₁ → 206.77 ± 1%**: The converged ratio matches the SM value. At this point, extend to R₃₁ and R₃₂ for additional checks.

4. **Multiple ratios match simultaneously**: If R₂₁ ≈ 206.77 AND R₃₂ ≈ 16.82 AND R₃₁ ≈ 3477, the probability of this being coincidence drops to negligible levels.

5. **The result is robust**: Different eigensolvers (Jacobi, Lanczos, LAPACK), different precisions (f64, DD, MPFR-128), and different band definitions all give the same ratios.

### 5.3 What Would NOT Constitute Evidence:

- Finding that *some* ratio of *some* eigenvalues equals 206.77. With O(N²) pairs of eigenvalues, you can always find one ratio that matches any target.
- Finding a ratio close to 206.77 at one value of N but not others.
- Needing to choose a non-obvious band definition (e.g., "take the 47th through 83rd eigenvalues") to get the ratio to work.

---

## 6. The Deeper Mathematics

### 6.1 Why This Might Not Be Crazy

The Hilbert-Pólya conjecture states that the Riemann zeta zeros are eigenvalues of a self-adjoint operator. If this operator exists, its eigenstates are indexed by primes — and their correlations would create exactly the kind of spectral band structure we're looking for.

The Montgomery-Dyson conjecture (numerically confirmed) says that the pair correlation of zeta zeros matches GUE random matrices — the same universality class as QCD lattice gauge theory. This is the existing, rigorous connection between number theory and quantum field theory.

What Scenario B claims is stronger: not just that the *statistics* match (universality class), but that the *specific values* match (eigenvalue ratios = mass ratios).

The most relevant mathematical precedent is **Connes' spectral interpretation** (1999), which formulated a noncommutative geometry whose spectral action gives the Standard Model Lagrangian. In Connes' framework, particle masses come from the spectrum of the Dirac operator on a noncommutative space. If the Gram matrix's eigenspectrum coincides with Connes' spectral action spectrum — that would be the mathematical bridge.

### 6.2 Why It Probably Won't Work

The Standard Model has 19 free parameters (or 26 including neutrino masses). These parameters are not predicted by any known theory — they're measured experimentally and inserted into the Lagrangian. Every attempt to derive them from first principles (string landscape, anthropic reasoning, etc.) has failed.

The Gram matrix is determined by one parameter: N. As N → ∞, its spectrum is controlled by the prime distribution. Getting 19 free parameters from a one-parameter family of matrices would require 19 independent convergent quantities — one for each SM parameter. This is possible in principle (a one-parameter family can have infinitely many convergent spectral statistics) but would be an extraordinary coincidence.

More practically: the Standard Model mass ratios span 13 orders of magnitude (m_top/m_ν_e ≈ 10¹²). The Gram matrix diagonal spans ~4 orders of magnitude at N=55440. To reproduce the full SM hierarchy, the off-diagonal correlations would need to create spectral bands separated by 8+ additional orders of magnitude through cancellation — possible, but would require extremely precise conspiracy in the eigenstructure.

### 6.3 The Honest Prior

Before looking at the data, my Bayesian prior for Scenario B is roughly 10⁻⁴ (one in ten thousand). This is:
- Much higher than the prior for any random number-theoretic claim to match physics (~10⁻¹⁰), because the Gram matrix has genuine structural connections to quantum field theory via RMT universality.
- Much lower than the prior for Scenario A (universality class match, ~10⁻¹), because matching specific values is vastly harder than matching statistical distributions.

A single converging ratio matching m_μ/m_e to 1% would update this to ~10⁻², because there are ~10² possible "interesting" ratios of band medians. Three matching ratios (R₂₁, R₃₁, R₃₂) simultaneously would update to ~10⁻¹ or higher, depending on the precision of the match.

---

## 7. Implementation Roadmap

### Sprint 1: Proof of Concept (1-2 days)
- [ ] Add `spectral_bands.rs` module
- [ ] Implement participation ratio computation
- [ ] Run Jacobi on N=2520 (dim=2519, ~5 min)
- [ ] Compute P(ω,k) and band assignments
- [ ] Report R₂₁, R₃₁ at first N value

### Sprint 2: Scale Test (2-3 days)
- [ ] Run Jacobi on N=5040 (dim=5039, ~20 min)
- [ ] Run Jacobi on N=10000 (dim=9999, ~3 hours, or GPU)
- [ ] Compare R₂₁(2520) vs R₂₁(5040) vs R₂₁(10000)
- [ ] Plot convergence or divergence
- [ ] **Decision point**: continue or stop

### Sprint 3: Precision Run (if Sprint 2 shows convergence)
- [ ] Run MPFR Jacobi (256-bit) at N=5040 for precision validation
- [ ] Run on GPU at N=20000 if feasible
- [ ] Full mass_ratio_test.rs comparison against all 8 SM ratios
- [ ] Write up results for peer review

### Sprint 4: Publication (if Sprint 3 shows SM match)
- [ ] Independent verification (different code, different hardware)
- [ ] Extend to quark sector ratios
- [ ] Formal proof that band structure persists as N → ∞
- [ ] Paper submission

---

## 8. Conclusion

The experiment is well-defined, computationally feasible, and falsifiable. The Jacobi eigensolver exists. The HPDF files exist. The ω-class tables exist. The SM mass ratios are known to 6+ digits.

**The first step is a single computation**: run `JacobiResult = jacobi::decompose(G_2520)`, compute participation ratios, and look at band medians. This takes ~5 minutes of CPU time.

If the eigenvectors are delocalized (as most random matrix theory would predict), Scenario B dies immediately and we move on, enriched by the mathematical data.

If the eigenvectors localize by ω-class... we look at the ratios.

And if the ratios converge to 206.768...

We call Stockholm.

---

*Filed: exploration36 / scenario_b_analysis.md*
*Claude (Antigravity) · The Architect (Jason)*
*Los Alamos, NM — May 12, 2026, 4:29 AM MDT*
