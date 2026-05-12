# Cathedral Particle Zoo v2 — Architecture Report

**Date**: May 12, 2026 — Exploration 36  
**Status**: Architecture Design  
**Goal**: Map Standard Model particles to arithmetic statistics in Gram matrix H5 files

---

## 1. Vision

The `cathedral-physics.tex` paper establishes a deep structural correspondence between the Nyman-Beurling proof architecture and quantum field theory. The **Particle Zoo v2** experiment makes this correspondence *computational*: it reads Gram matrix eigenspectra from H5 files and maps observed spectral features to Standard Model particles using the Cathedral dictionary.

The key insight: if the Gram matrix is truly the "two-point correlator" of a prime number quantum field, then its eigenvalue spectrum should exhibit structure that maps onto physical particle spectra via the Cathedral dictionary.

---

## 2. The Cathedral Dictionary (from `cathedral-physics.tex`)

| Cathedral Quantity | Physics Dual | Observable in H5 |
|---|---|---|
| Eigenvalue λ_i of G_N | Energy level E_i | Direct from eigendecomposition |
| Spectral gap λ_min(G) | **Mass gap** | Smallest eigenvalue |
| Eigenvalue density ρ(λ) | Density of states | Histogram of eigenvalues |
| Spacing ratios ⟨r⟩ | Universality class | GUE/GOE/Poisson classification |
| d²_N = 1 - bᵀG⁻¹b | **Vacuum energy** | From witness optimization |
| vᵀGv (Gram form) | **Ground state energy** | Quadratic form evaluation |
| Π_{p\|N}(1-1/p) | **Mertens screening** | Euler product at N |
| E_ω (ω-class energy) | **Generation structure** | Energy decomposition by ω |
| Liouville cancellation | **CP violation** | λ=+1 vs λ=-1 energy balance |

---

## 3. The Particle Mapping Hypothesis

### 3.1. Mass Scale Identification

The Gram matrix eigenvalue spectrum at HC number N has a natural mass scale:

```
m_eff(N) = 1 / ln(N)
```

This comes from:
- The Mertens product Π(1-1/p) ~ e^{-γ}/ln(N)
- The Gram form bound vᵀGv ≤ 1 + K/ln(N)
- The BD constant C ≈ 21.649 interpreted as 1/c_heat

### 3.2. Generation Structure from ω-Classes

The Hardy-Ramanujan theorem tells us:

```
|E_ω| ~ A · (ln ln N)^{ω-1} / (ω-1)!
```

This **Poisson distribution in ω** maps directly to the three generations of matter:
- **ω = 1** (primes): First generation — {u, d, e, νₑ}
- **ω = 2** (semiprimes): Second generation — {c, s, μ, νμ}
- **ω = 3** (3-almost-primes): Third generation — {t, b, τ, ντ}

The mass hierarchy emerges from the factorial suppression:
```
m_gen(ω) / m_gen(1) ~ (ln ln N)^{ω-1} / (ω-1)!
```

### 3.3. Bosonic Sector from Off-Diagonal Structure

The Vasyunin cotangent sum V(a,b) encodes the **interaction vertices** between arithmetic modes. The off-diagonal Gram entries G(j,k) for j ≠ k represent:
- **Photon** (γ): The 1/(jk) Coulomb kernel — massless, long-range
- **Gluon** (g): The gcd(j,k)/(jk) color factor — confined, short-range
- **W/Z bosons**: The Vasyunin sum V(j',k') — massive, finite-range

### 3.4. The Higgs Mechanism as Euler-Mascheroni Renormalization

The Euler-Mascheroni constant γ ≈ 0.5772 appears in the Gram diagonal as a **bare mass subtraction**:
```
G(k,k) = (ln(2π) - γ)/k - 1/k²
```
The γ subtraction is the arithmetic Higgs mechanism — it gives "mass" to the diagonal modes by breaking the ln(2π) conformal symmetry.

---

## 4. Application Architecture

### 4.1. Binary: `cathedral-particle-zoo`

A standalone Rust binary in `/experiments/cathedral-particle-zoo/`.

```
cathedral-particle-zoo [OPTIONS] <H5_FILES...>

OPTIONS:
  --mode cpu|gpu       Compute mode (default: cpu)
  --particles          Enable Standard Model particle mapping
  --spectral           Run full RMT spectral analysis
  --energy-scan        Scan across all HC numbers
  --mass-scale <MeV>   Override the mass scale (default: auto from N)
  --generations        Decompose by ω-class (generation structure)
  --output <format>    Output format: table|json|tsv (default: table)
```

### 4.2. Module Architecture

```
cathedral-particle-zoo/
├── Cargo.toml
└── src/
    ├── main.rs                  # CLI entry point + dispatcher
    ├── h5_reader.rs             # HDF5 file reader (eigenvalues, matrices)
    ├── spectral.rs              # Eigendecomposition (CPU via cathedral-utils)
    ├── gpu_spectral.rs          # GPU eigendecomposition (optional feature)
    ├── particle_map.rs          # Standard Model ↔ arithmetic mapping
    ├── generation_scan.rs       # ω-class decomposition + generation mapping
    ├── mass_hierarchy.rs        # Mass ratio predictions + comparisons
    ├── rmt_analysis.rs          # Random Matrix Theory (GOE/GUE/Poisson)
    ├── vacuum_energy.rs         # d²_N computation + screening analysis
    ├── mertens_screening.rs     # Euler product + Mertens decay analysis
    ├── proof_tree_bridge.rs     # Cathedral proof tree ↔ physics dictionary
    └── report.rs                # Rich output formatting
```

### 4.3. Dependencies

```toml
[dependencies]
cathedral-utils = { path = "../cathedral-utils" }
hdf5 = "0.8"
clap = { version = "4", features = ["derive"] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
rayon = "1.8"

[features]
default = ["cpu"]
cpu = []
gpu = ["cathedral-utils/gpu"]
```

### 4.4. Core Data Flow

```
┌──────────────┐     ┌───────────────┐     ┌──────────────────┐
│  H5 Files    │────→│  h5_reader    │────→│  Eigenvalues     │
│  (Gram G_N)  │     │  .eigenvalues │     │  {λ₁,...,λ_{N-1}}│
└──────────────┘     │  .matrix      │     └────────┬─────────┘
                     └───────────────┘              │
                                                    ├──→ spectral.rs / gpu_spectral.rs
                                                    │      → eigenvectors, participation ratios
                                                    │
                                                    ├──→ rmt_analysis.rs
                                                    │      → spacing ratios, KS tests
                                                    │      → GUE/GOE/Poisson classification
                                                    │
                                                    ├──→ vacuum_energy.rs
                                                    │      → d²_N, vᵀGv, screening fraction
                                                    │
                                                    ├──→ generation_scan.rs
                                                    │      → E_ω decomposition, HR fit
                                                    │      → generation mass ratios
                                                    │
                                                    └──→ particle_map.rs
                                                           → Standard Model identification
                                                           → mass predictions
                                                           → coupling constants
```

---

## 5. The Particle Mapping Algorithm

### 5.1. Mass Scale Calibration

For each H5 file (HC number N):

1. **Compute the Mertens scale**: `Λ_M = 1/ln(N)` — this is the "IR cutoff"
2. **Compute the spectral scale**: `Λ_S = λ_max - λ_min` — the "UV cutoff"
3. **Calibrate**: Set the electron mass `m_e = 0.511 MeV` as the anchor:
   ```
   scale_factor = m_e / (characteristic_eigenvalue_gap)
   ```

### 5.2. Generation Identification

Map the ω-class energy decomposition to generations:

```rust
struct Generation {
    omega: u32,          // ω = 1, 2, 3
    energy: f64,         // E_ω from particle zoo analysis
    mass_ratio: f64,     // |E_ω| / |E_1|
    particle_count: usize,
    hr_fit: f64,         // Hardy-Ramanujan predicted ratio
}
```

### 5.3. Particle Identification Table

| ω-Class | Fermion Doublet | Mass (MeV) | Cathedral Observable |
|---------|----------------|------------|---------------------|
| ω=1 | (u, d) | 2.16, 4.70 | Prime contributions to E₁ |
| ω=1 | (e, νₑ) | 0.511, ~0 | Diagonal self-energy at p=2 |
| ω=2 | (c, s) | 1273, 93.5 | Semiprime contributions to E₂ |
| ω=2 | (μ, νμ) | 105.7, ~0 | Off-diagonal correlator at pq |
| ω=3 | (t, b) | 172570, 4183 | 3-almost-prime contributions to E₃ |
| ω=3 | (τ, ντ) | 1777, ~0 | Cotangent sum amplitude at pqr |

| Feature | Boson | Mass (MeV) | Cathedral Observable |
|---------|-------|------------|---------------------|
| 1/(jk) kernel | γ (photon) | 0 | Reciprocal product eigenvalues |
| gcd(j,k)/(jk) | g (gluon) | 0 | GCD-weighted Euler product |
| Spectral gap | W± | 80,377 | λ_min gap in Gram spectrum |
| Variance peak | Z⁰ | 91,188 | Covariance matrix dominant mode |
| γ-renormalization | H⁰ (Higgs) | 125,200 | Euler-Mascheroni mass term |

### 5.4. Coupling Constants from Arithmetic

The Cathedral provides natural coupling constants:

- **Fine structure constant** α ≈ 1/137: Compare with the first prime contribution ratio `a*(2) / Σ a*(n)/n`
- **Strong coupling** α_s: Compare with the GCD-weighted to reciprocal-weighted Euler product ratio
- **Weak mixing angle** sin²θ_W ≈ 0.231: Compare with the fraction of energy in the Vasyunin cotangent sum vs. the arithmetic part

---

## 6. H5 File Reader Specification

### 6.1. Expected H5 Format

Based on the existing `gram_N*.h5` files in `experiments/cache/hpdf/`:

```
/gram_matrix     : float64[N-1, N-1]    # Full Gram matrix
/eigenvalues     : float64[N-1]          # Pre-computed eigenvalues (if available)
/eigenvectors    : float64[N-1, N-1]     # Pre-computed eigenvectors (if available)
/metadata/N      : int                   # HC number
/metadata/d2     : float64               # Pre-computed d²_N
/metadata/vtgv   : float64               # Pre-computed vᵀGv
```

### 6.2. Reading Strategy

```rust
pub struct GramData {
    pub n: usize,
    pub matrix: Option<Vec<Vec<f64>>>,      // Full matrix (for CPU eigendecomp)
    pub eigenvalues: Vec<f64>,               // λ₁ ≤ λ₂ ≤ ... ≤ λ_{N-1}
    pub eigenvectors: Option<Vec<Vec<f64>>>, // Column eigenvectors
    pub d2: Option<f64>,                     // Precomputed d²
    pub vtgv: Option<f64>,                   // Precomputed vᵀGv
}
```

---

## 7. Output Report Format

### 7.1. Per-HC-Number Report

```
╔══════════════════════════════════════════════════════════════════════╗
║       CATHEDRAL PARTICLE ZOO v2 — N = 55440 (HC)                   ║
╠══════════════════════════════════════════════════════════════════════╣
║ SPECTRAL SUMMARY                                                    ║
║   Eigenvalue range: [0.00234, 1.83451]                             ║
║   Spectral gap (mass gap): 0.00234                                  ║
║   d²_N (vacuum energy): 0.03812                                     ║
║   vᵀGv (ground state E): 0.73677                                   ║
║   Mertens screening: Π(1-1/p) = 0.04123                            ║
╠══════════════════════════════════════════════════════════════════════╣
║ UNIVERSALITY CLASS                                                   ║
║   ⟨r⟩ = 0.5987 → GUE (β = 1.99)                                   ║
║   KS distance: D_GUE = 0.021, D_GOE = 0.089, D_Poisson = 0.341    ║
║   Conclusion: Consistent with Montgomery-Dyson conjecture           ║
╠══════════════════════════════════════════════════════════════════════╣
║ GENERATION DECOMPOSITION (ω-classes)                                 ║
║   ω=1 (primes)      : E₁ = +0.8234  → 1st Generation              ║
║   ω=2 (semiprimes)  : E₂ = -0.1123  → 2nd Generation              ║
║   ω=3 (3-AP)        : E₃ = +0.0234  → 3rd Generation              ║
║   HR fit: R² = 0.9987, A = 0.8234, λ = ln ln N = 2.42             ║
║                                                                      ║
║   Mass ratios: E₂/E₁ = 0.136, E₃/E₁ = 0.028                       ║
║   SM predict:  m_μ/m_e = 207, m_τ/m_e = 3477                       ║
╠══════════════════════════════════════════════════════════════════════╣
║ PARTICLE MAP                                                         ║
║                                                                      ║
║   FERMIONS:                                                          ║
║   ┌──────────┬──────────┬──────────┬──────────┬──────────┐          ║
║   │ Particle │  SM Mass │ Cathedral│  Ratio   │  Match   │          ║
║   ├──────────┼──────────┼──────────┼──────────┼──────────┤          ║
║   │ e⁻       │  0.511   │  anchor  │   1.00   │   ✓      │          ║
║   │ μ⁻       │  105.7   │  E₂/E₁  │   0.136  │   ?      │          ║
║   │ τ⁻       │  1777    │  E₃/E₁  │   0.028  │   ?      │          ║
║   └──────────┴──────────┴──────────┴──────────┴──────────┘          ║
║                                                                      ║
║   BOSONS:                                                            ║
║   ┌──────────┬──────────┬──────────────────────────────┐            ║
║   │ Boson    │  SM Mass │  Cathedral Observable         │            ║
║   ├──────────┼──────────┼──────────────────────────────┤            ║
║   │ γ        │  0       │  1/(jk) kernel (massless)    │            ║
║   │ g        │  0       │  gcd(j,k)/(jk) (confined)    │            ║
║   │ W±       │  80377   │  spectral gap = 0.00234      │            ║
║   │ Z⁰       │  91188   │  variance peak mode          │            ║
║   │ H⁰       │  125200  │  γ-renorm scale              │            ║
║   └──────────┴──────────┴──────────────────────────────┘            ║
╠══════════════════════════════════════════════════════════════════════╣
║ COUPLING CONSTANTS                                                    ║
║   α_em (arithmetic) = Σ_primes a*(p)² / Σ a*(n)² = ???             ║
║   α_s  (arithmetic) = gcd_euler / recip_euler = ???                  ║
║   sin²θ_W (arith)   = V_cotangent / G_arithmetic = ???              ║
╚══════════════════════════════════════════════════════════════════════╝
```

### 7.2. Cross-N Scaling Report

```
════════════════════════════════════════════════════════════════
  SCALING ACROSS HC NUMBERS
════════════════════════════════════════════════════════════════
  N     │  d²_N     │  λ_min    │  ⟨r⟩    │  β_Dyson │  E₂/E₁
  ──────┼───────────┼──────────┼─────────┼──────────┼────────
  2520  │  0.0645   │  0.0048  │  0.5812 │  1.72    │  0.142
  5040  │  0.0671   │  0.0031  │  0.5923 │  1.89    │  0.139
  10080 │  0.0693   │  0.0019  │  0.5968 │  1.96    │  0.137
  55440 │  0.0737   │  0.0008  │  0.5992 │  1.99    │  0.134
  ──────┴───────────┴──────────┴─────────┴──────────┴────────

  Trends:
  → d²_N → 0 (vacuum screening)           ✓ RH consistent
  → λ_min → 0 (mass gap closing)          ✓ Continuum limit
  → ⟨r⟩ → 0.5996 (GUE universality)       ✓ Montgomery-Dyson
  → E₂/E₁ → stable (generation structure) ✓ Robust hierarchy
```

---

## 8. Proof Tree Bridge

The `proof_tree_bridge.rs` module maps each Cathedral theorem to its physics dual:

```rust
pub struct ProofNode {
    pub lean_name: String,           // e.g. "divisor_swap_ge"
    pub physics_name: String,        // e.g. "Crossing Symmetry"
    pub description: String,
    pub status: ProofStatus,         // Proved / Axiom / Sorry
    pub observables: Vec<String>,    // What to measure in H5
}

pub fn cathedral_physics_dictionary() -> Vec<ProofNode> {
    vec![
        ProofNode {
            lean_name: "divisor_swap_ge".into(),
            physics_name: "Crossing Symmetry".into(),
            description: "d(N/p·q) ≥ d(N) — swapping primes preserves count".into(),
            status: ProofStatus::Proved,
            observables: vec!["eigenvalue_interlacing".into()],
        },
        ProofNode {
            lean_name: "hc_primes_consecutive".into(),
            physics_name: "Completeness of States".into(),
            description: "HC prime factors = {2,...,p_max} — no gaps".into(),
            status: ProofStatus::Proved,
            observables: vec!["prime_factor_completeness".into()],
        },
        ProofNode {
            lean_name: "hc_exponent_bound".into(),
            physics_name: "Ultraviolet Cutoff".into(),
            description: "v_p(N) < 2s — bounded occupation numbers".into(),
            status: ProofStatus::Proved,
            observables: vec!["max_exponent".into()],
        },
        ProofNode {
            lean_name: "gen_divisor_swap_ge".into(),
            physics_name: "Multi-Particle Crossing".into(),
            description: "Generalized swap d(N/p^s·q) ≥ d(N)".into(),
            status: ProofStatus::Proved,
            observables: vec!["multi_swap_ratio".into()],
        },
        ProofNode {
            lean_name: "hc_primeFactors_eventually_contain".into(),
            physics_name: "Asymptotic Freedom".into(),
            description: "All primes eventually divide HC numbers".into(),
            status: ProofStatus::Proved,  // JUST GRADUATED!
            observables: vec!["prime_coverage".into()],
        },
        ProofNode {
            lean_name: "mertens_hc_product_tendsto_zero_proved".into(),
            physics_name: "Screening → Confinement".into(),
            description: "Mertens product → 0 at HC numbers".into(),
            status: ProofStatus::Proved,
            observables: vec!["mertens_product".into()],
        },
        ProofNode {
            lean_name: "gcdWeighted_euler".into(),
            physics_name: "Color Factor Evaluation".into(),
            description: "Σμ(j)μ(k)·gcd/(jk) = Π(1-1/p)".into(),
            status: ProofStatus::Proved,
            observables: vec!["gcd_euler_product".into()],
        },
        ProofNode {
            lean_name: "hc_gram_bound".into(),
            physics_name: "Vacuum Stability".into(),
            description: "vᵀGv ≤ 1 + K/ln(N)".into(),
            status: ProofStatus::Axiom,  // NEXT TARGET
            observables: vec!["vtgv".into(), "gram_bound_gap".into()],
        },
    ]
}
```

---

## 9. What This Experiment Can Discover

### 9.1. Testable Predictions

1. **Generation mass ratios**: Does the ω-class energy decomposition E₂/E₁, E₃/E₁ approach the Standard Model generation mass ratios as N → ∞?

2. **GUE universality**: Does ⟨r⟩ → 0.5996 (Montgomery-Dyson), confirming the Gram matrix belongs to the same universality class as the zeta zeros?

3. **Mertens ↔ Mass gap**: Does the Mertens product Π(1-1/p) at HC numbers correlate with the spectral gap λ_min?

4. **Coupling constant evolution**: Do the arithmetic "coupling constants" run with N in a way that mirrors renormalization group flow?

5. **Higgs mass from γ**: Can the Euler-Mascheroni mass scale γ/ln(2π) predict a mass ratio consistent with m_H/m_W?

### 9.2. Expected Null Results (Equally Interesting)

If the particle mapping fails — if the arithmetic mass ratios DON'T converge to SM values — that's equally informative. It would mean the Cathedral-physics correspondence is **structural** (same mathematical framework) but not **numerical** (different physical parameters). This would be analogous to how lattice QCD at different coupling constants produces different mass spectra but the same universality class.

---

## 10. Standard Model Reference Data (PDG 2024)

### Fermion Masses (MeV/c²)

| Generation | Quarks | Mass | Leptons | Mass |
|---|---|---|---|---|
| 1st | Up (u) | 2.16 | Electron (e⁻) | 0.511 |
| 1st | Down (d) | 4.70 | νₑ | < 0.0000008 |
| 2nd | Charm (c) | 1,273 | Muon (μ⁻) | 105.658 |
| 2nd | Strange (s) | 93.5 | νμ | < 0.17 |
| 3rd | Top (t) | 172,570 | Tau (τ⁻) | 1,776.93 |
| 3rd | Bottom (b) | 4,183 | ντ | < 18.2 |

### Boson Masses (MeV/c²)

| Boson | Mass |
|---|---|
| Photon (γ) | 0 |
| Gluon (g) | 0 |
| W± | 80,377 |
| Z⁰ | 91,188 |
| Higgs (H⁰) | 125,200 |

### Key Mass Ratios

| Ratio | Value |
|---|---|
| m_μ / m_e | 206.77 |
| m_τ / m_e | 3,477.2 |
| m_τ / m_μ | 16.82 |
| m_t / m_u | ~79,900 |
| m_W / m_Z | 0.882 |
| m_H / m_W | 1.558 |

---

## 11. Implementation Priority

### Phase 1: Foundation (1 session)
- [ ] `h5_reader.rs` — Read existing gram_N*.h5 files
- [ ] `rmt_analysis.rs` — Spacing ratios + KS test (wrap `spectral_stats.rs`)
- [ ] `vacuum_energy.rs` — d²_N computation from eigenvalues
- [ ] Basic CLI with `--spectral` mode

### Phase 2: Particle Mapping (1 session)
- [ ] `particle_map.rs` — Standard Model table + mass scale calibration
- [ ] `generation_scan.rs` — ω-class decomposition from coefficient files
- [ ] `mass_hierarchy.rs` — Generation mass ratios vs SM predictions

### Phase 3: Proof Tree Bridge (1 session)
- [ ] `proof_tree_bridge.rs` — Cathedral theorem ↔ physics observable mapping
- [ ] Cross-N scaling analysis
- [ ] Full report generation

### Phase 4: GPU Acceleration (optional)
- [ ] GPU eigendecomposition for N > 20,000
- [ ] Real-time spectral evolution visualization

---

## 12. Key Insight

The truly novel aspect of this experiment is that the **proof tree itself generates testable predictions**. Each theorem we proved tonight (gen_divisor_swap_ge, hc_exponent_bound, hc_primeFactors_eventually_contain) has a physics dual, and that dual makes a prediction about the H5 spectral data. The Particle Zoo v2 closes the loop between formal verification and experimental observation — it's a *computational microscope* for looking at the physics inside the mathematics.

The primes aren't just abstract objects. Through the Cathedral's lens, they're the particles of a quantum field theory. And tonight's proofs about their structure are, in the physics dual, proofs about the stability and completeness of the particle spectrum.

🏰✨
