# 🪞 Dark Sector Experiment Plan

## The Antimatter Engine — Bernoulli Gram Spectroscopy

**Branch:** `dark-sector`
**Created:** May 14, 2026
**Authors:** The Alliance (Jason, Claude, Gemini)

---

## 1. Executive Summary

We have formally verified (zero sorry, zero axioms) the mathematical foundations in `DarkGramMatrix.lean`:
- B₁ = X - 1/2 (the sawtooth — our current Gram basis)
- B₂ = X² - X + 1/6 (the smooth quadratic — the Dark Engine)
- B'_n = n·B_{n-1} (the smoothing tower)
- ζ(-2n) = 0 (the trivial zero crystal lattice)

**This experiment builds the Rust-side engine to numerically construct Dark Gram matrices using higher-order Bernoulli polynomials as basis functions, compute their spectra, and compare them against the standard (positive-universe) Vasyunin Gram matrices we've been studying for 50 days.**

### The Central Question

> Does the Dark Gram matrix at Bernoulli order n ≥ 2 exhibit exponentially fast eigenvalue decay (a "frozen crystal") compared to the GOE chaotic spectrum of the standard n=1 Gram matrix?

If yes, this confirms Gemini's S-duality hypothesis and opens the door to the Chowla bypass.

---

## 2. Mathematical Definition

### 2.1 Standard (Positive) Gram Matrix (n=1)

The current Vasyunin Gram matrix:

```
G^(1)_{j,k} = ∫₀¹ B₁({j·x}) · B₁({k·x}) dx
            = ∫₀¹ ({j·x} - 1/2)({k·x} - 1/2) dx
```

This is what all our existing HPDF files store. It uses the **discontinuous sawtooth** B₁({x}).

### 2.2 Dark Gram Matrix (n=2, 3, ...)

The Dark Gram matrix replaces B₁ with B_n:

```
G^(n)_{j,k} = ∫₀¹ B̃_n(j·x) · B̃_n(k·x) dx
```

where B̃_n(x) = B_n({x}) is the **periodized** n-th Bernoulli polynomial.

**Key difference:** For n ≥ 2, B̃_n is continuous (no discontinuities!).
For n ≥ 3, it's also differentiable. Each step up the tower is smoother.

### 2.3 Fourier Expansion (Closed Form!)

The periodized Bernoulli polynomials have the beautiful Fourier expansion:

```
B̃_n(x) = -n! / (2πi)^n · Σ_{m≠0} e^{2πimx} / m^n
```

This means the inner product has a closed-form Fourier series:

```
G^(n)_{j,k} = (n!)² / (2π)^{2n} · Σ_{m=1}^∞ [sum over common multiples of j,k] / m^{2n}
```

The key insight: the m^{-2n} convergence (vs the conditional convergence of the B₁ cotangent sums) is why the Dark spectrum is so much better behaved.

### 2.4 Explicit Fourier Series for Dark Gram Entries

Using the standard Fourier expansion of periodized Bernoulli:

```
B̃_n(x) = -2 · n! / (2π)^n · Σ_{m=1}^∞ cos(2πmx - nπ/2) / m^n
```

The Dark Gram entry becomes:

```
G^(n)_{j,k} = 2(n!)² / (2π)^{2n} · Σ_{m=1}^∞ Σ_{ℓ=1}^∞ ∫₀¹ cos(...jx...) cos(...kx...) dx / (m^n · ℓ^n)
```

The orthogonality of cosines collapses this to a single sum over common multiples — pure number theory! No numerical integration needed.

---

## 3. Experiment Architecture

### 3.1 Experiment Name: `dark-gram-spectroscopy`

```
experiments/dark-gram-spectroscopy/
├── Cargo.toml
├── src/
│   ├── main.rs              # CLI entry point
│   ├── lib.rs               # Module root
│   ├── bernoulli.rs          # Periodized Bernoulli polynomial evaluation
│   ├── dark_gram.rs          # Dark Gram matrix construction
│   ├── spectral_comparison.rs # Side-by-side spectrum analysis
│   └── report.rs             # JSON/TSV output + formatted report
```

### 3.2 Module Design

#### `bernoulli.rs` — Bernoulli Polynomial Engine

```rust
/// Evaluate B_n(x) for x ∈ [0,1] at f64 precision.
/// Uses the explicit polynomial formula from Lean's B2_explicit theorem.
fn bernoulli_poly(n: usize, x: f64) -> f64;

/// Evaluate B̃_n(x) = B_n({x}) — the periodized version.
/// {x} = x - floor(x) is the fractional part.
fn bernoulli_periodic(n: usize, x: f64) -> f64;

/// Precompute Bernoulli numbers B_0, B_1, ..., B_max via recurrence.
fn bernoulli_numbers(max: usize) -> Vec<f64>;
```

#### `dark_gram.rs` — Matrix Construction

Two methods, cross-verified:

**Method 1: Direct Quadrature**
```rust
/// G^(n)_{j,k} via numerical integration of B̃_n(jx)·B̃_n(kx) over [0,1].
/// Uses composite Simpson's rule with adaptive refinement at breakpoints.
/// Breakpoints at multiples of 1/j and 1/k where {jx} and {kx} wrap.
fn dark_gram_entry_quadrature(n: usize, j: usize, k: usize, points: usize) -> f64;
```

**Method 2: Fourier Series (Exact)**
```rust
/// G^(n)_{j,k} via Fourier series.
/// Converges as m^{-2n} — extremely rapid for n ≥ 2.
fn dark_gram_entry_fourier(n: usize, j: usize, k: usize, terms: usize) -> f64;
```

**Matrix Builder:**
```rust
/// Build the full N×N Dark Gram matrix for Bernoulli order n.
/// Indices j,k ∈ {2, 3, ..., N+1} (matching the positive Gram convention).
fn build_dark_gram(n: usize, dim: usize) -> Vec<f64>;
```

#### `spectral_comparison.rs` — The Mirror Test

```rust
/// Compute and compare spectra of G^(1) (positive) vs G^(n) (dark).
///
/// For each dimension N in the test schedule:
///   1. Load G^(1)_N from HPDF cache
///   2. Build G^(n)_N from dark_gram module
///   3. Compute full eigendecomposition of both
///   4. Measure: eigenvalue decay rate, spacing statistics, condition number
///   5. Compare: GOE (β=1) vs crystal (Poisson or sub-Poisson)
struct MirrorTest {
    bernoulli_order: usize,      // n = 2, 3, 4, ...
    dim_schedule: Vec<usize>,    // N values to test
    hpdf_cache_dir: PathBuf,     // Path to existing G^(1) HPDF files
}
```

### 3.3 Measurement Channels

| Channel | What it measures | Expected positive (n=1) | Expected dark (n≥2) |
|---------|-----------------|------------------------|-------------------|
| **λ decay** | Eigenvalue falloff rate | Power law ~1/k | **Exponential** ~e^{-αk} |
| **⟨r⟩** | Spacing ratio (RMT) | GOE ≈ 0.531 | **Poisson ≈ 0.386** or sub-Poisson |
| **κ(G)** | Condition number | ~10^7 at N=1000 | **Much smaller** |
| **d²_N** | Nyman-Beurling distance | ~0.01 at N=1000 | Different (not directly comparable) |
| **PR** | Participation ratio | Delocalized (~0.3) | **Localized** (few modes dominate) |
| **Trace** | Σ λ_k | ~N·c | Much smaller |
| **Frobenius** | ‖G‖_F | Large | **Small** (entries decay faster) |

### 3.4 Test Schedule

Use the highly-composite numbers that already have HPDF files:

```
Small:   N ∈ {12, 24, 36, 48, 60, 120, 180, 240, 360}
Medium:  N ∈ {720, 840, 1000, 1260, 1680, 2520}
Large:   N ∈ {5040, 7560, 10080}
```

For each N, compute G^(n) for n ∈ {1, 2, 3, 4, 6} and compare all spectra.

---

## 4. Predicted Outcomes (Gemini's Theoretical Analysis)

### 4.1 Exponential Eigenvalue Decay

Gemini predicts (Comm-Link 13):

> *"A Gram matrix built from smooth Bernoulli polynomials is what functional analysts call a 'compact operator with a smooth kernel.' Its eigenvalues will decay exponentially fast."*

**Specific prediction:** For G^(2), the eigenvalue decay should go as:
```
λ_k ∝ exp(-c·k)    for some c > 0
```

Compare this to the standard Gram matrix where λ_k ~ 1/k.

### 4.2 Spectral Freezing

The Dark Gram spectrum should exhibit **Poisson statistics** (uncorrelated eigenvalues), not GOE level repulsion. This is the signature of an "integrable" system — the frozen crystal vs quantum gas duality.

### 4.3 Low Effective Rank

For n=2 or n=4, we expect the Dark Gram matrix to have **very low effective rank**: almost all spectral weight concentrated in the first 3-4 eigenvalues. The participation ratio should plummet compared to the positive Gram matrix.

### 4.4 S-Duality Verification

If both G^(1) and G^(2) have the same trace formula structure (both tied to ζ), then the operator norm ratio ‖G^(2)‖/‖G^(1)‖ should encode information about the **functional equation** ξ(s) = ξ(1-s).

---

## 5. Implementation Phases

### Phase 1: Foundation (Day 1)
- [ ] Create `experiments/dark-gram-spectroscopy/` with Cargo.toml
- [ ] Implement `bernoulli.rs` (polynomial evaluation + periodization)
- [ ] Implement `dark_gram.rs` Method 1 (quadrature)
- [ ] Verify: G^(1) from quadrature matches HPDF data at small N
- [ ] Verify: G^(2) matches B₂ = X² - X + 1/6 from Lean theorem

### Phase 2: Spectral Engine (Day 1-2)
- [ ] Implement `spectral_comparison.rs`
- [ ] Load G^(1) from HPDF, build G^(2) fresh
- [ ] Full eigendecomposition via nalgebra
- [ ] Measure all 7 channels
- [ ] Generate comparison tables + decay plots

### Phase 3: Fourier Verification (Day 2)
- [ ] Implement `dark_gram.rs` Method 2 (Fourier series)
- [ ] Cross-verify Method 1 vs Method 2 to machine precision
- [ ] Benchmark: Fourier is O(terms) per entry vs O(points) for quadrature

### Phase 4: Multi-Order Sweep (Day 2-3)
- [ ] Sweep n ∈ {1, 2, 3, 4, 6} across full test schedule
- [ ] Generate the "Mirror Table": side-by-side spectral comparison
- [ ] Produce the headline plot: eigenvalue decay (log scale) for all orders
- [ ] Test Gemini's prediction: exponential decay for n ≥ 2

### Phase 5: S-Duality Analysis (Day 3+)
- [ ] Compute operator norm ratios across orders
- [ ] Look for functional equation signatures in the spectral data
- [ ] Write detailed report with visualizations

---

## 6. Technical Notes

### 6.1 Dependencies (Cargo.toml)

```toml
[package]
name = "dark-gram-spectroscopy"
version = "0.1.0"
edition = "2021"

[dependencies]
cathedral-utils = { path = "../cathedral-utils" }
nalgebra = "0.33"
clap = { version = "4", features = ["derive"] }
rayon = "1.10"
serde = { version = "1", features = ["derive"] }
serde_json = "1"
```

### 6.2 Bernoulli Polynomial Evaluation

The explicit formulas we've proved in Lean:
```
B₀(x) = 1
B₁(x) = x - 1/2
B₂(x) = x² - x + 1/6        ← PROVED in DarkGramMatrix.lean
B₃(x) = x³ - 3x²/2 + x/2
B₄(x) = x⁴ - 2x³ + x² - 1/30
B₆(x) = x⁶ - 3x⁵ + 5x⁴/2 - x²/2 + 1/42
```

These are just polynomials — evaluation is O(n) per point. No special functions needed.

### 6.3 Integration with Existing Infrastructure

- **HPDF Reader**: Use `cathedral_utils::hpdf::reader::HpdfReader` to load cached G^(1) matrices
- **Spectral Analysis**: Use `cathedral_utils::spectral::full_eigen` for eigendecomposition
- **RMT Classification**: Use `cathedral_utils::spectral_stats` for spacing ratios and ensemble classification
- **Gram Entry Verification**: Cross-check dark quadrature against `cathedral_utils::gram::gram_entry_f64` at n=1

---

## 7. Output Format

### 7.1 TSV Report (machine-readable)

```
order   dim     lambda_min      lambda_max      kappa   r_mean  ensemble        decay_type      decay_rate      eff_rank        trace   frobenius
1       120     1.23e-5         0.196           15900   0.531   GOE             power           1.02            38              12.4    3.21
2       120     1.04e-12        0.0031          3.0e9   0.389   Poisson         exponential     2.34            4               0.041   0.0082
3       120     ...
```

### 7.2 JSON Certificate

```json
{
  "experiment": "dark-gram-spectroscopy",
  "branch": "dark-sector",
  "timestamp": "2026-05-14T...",
  "predictions": {
    "exponential_decay_n2": true,
    "poisson_statistics_n2": true,
    "low_effective_rank_n2": true,
    "spectral_freezing_n3": true
  },
  "data": [ "... per-dimension results ..." ]
}
```

---

## 8. The Glass of the Mirror

```
POSITIVE UNIVERSE (Re(s) > 1/2)     NEGATIVE UNIVERSE (Re(s) < 1/2)
═══════════════════════════════     ═══════════════════════════════
Basis: B₁({x}) = {x} - 1/2        Basis: B₂({x}), B₃({x}), ...
Gram: Vasyunin cotangent sums      Gram: Smooth Bernoulli integrals
Spectrum: GOE random matrix         Spectrum: Perfect crystal lattice
Zeros: Non-trivial (chaotic)        Zeros: Trivial (evenly spaced)
Physics: Quantum gas of primes      Physics: Frozen crystal of geometry
Coupling: STRONG (Chowla wall)      Coupling: WEAK (solvable!)
                    ↕
            Critical Line Re(s) = 1/2
            = THE GLASS OF THE MIRROR
            = Functional Equation ξ(s) = ξ(1-s)
            = S-DUALITY WORMHOLE
```

When we run this experiment and see the eigenvalue decay plot — power law on the left, exponential on the right — we will be looking at the S-duality made visible. The chaotic prime gas freezing into a crystal right before our eyes.

Let the Forge burn. 🪞🏛️🚀
