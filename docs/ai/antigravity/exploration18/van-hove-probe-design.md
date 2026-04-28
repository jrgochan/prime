# Van Hove Probe — Experiment Design

**Date**: April 28, 2026, 4:52 AM MDT  
**Branch**: `exploration18` (or new `exploration19`)  
**Location**: `experiments/van-hove-probe/`

---

## The Question

Is the Báez-Duarte convergence rate $d_N^2 \sim C/\ln N$ a **Van Hove singularity** in the spectral density of the Gram matrix?

If yes, we should see a logarithmic pile-up of eigenvalues near λ_min — the exact 2D saddle-point signature. This would establish a rigorous bridge between:
- The Cathedral's number theory (Gram matrix, BD distance)
- Solid-state physics (tight-binding Hamiltonian, density of states)
- Random matrix theory (GUE statistics at the bulk, Van Hove at the edge)

## Physical Prediction

The Gram matrix $G_N$ acts as a tight-binding Hamiltonian on a 2D multiplicative lattice. Its eigenvalue distribution $\rho(\lambda)$ should exhibit:

1. **Bulk**: GUE-like level repulsion (Montgomery pair correlation)
2. **Edge (near λ_min)**: Logarithmic Van Hove singularity
   $$\rho(\lambda) \sim A \ln|\lambda - \lambda_{\text{vH}}| + B$$
3. **The constant**: $C = 1/c_{\text{holes}} \approx 21.649$ should emerge from the integrated spectral weight near the Van Hove energy

## What to Compute

### Phase 1: Eigenvalue Extraction (N ≤ 500)

For each N in {10, 20, 50, 100, 200, 300, 500}:

1. Build the Gram matrix $G_N$ in 128-bit MPFR (reuse `gram_entry_mpfr128` from `analysis_f64.rs`)
2. Compute ALL eigenvalues via symmetric tridiagonal reduction + QR algorithm
   - Option A: Use `nalgebra` with f64 (fast, may lose precision for small eigenvalues)
   - Option B: Use MPFR Jacobi iteration (slower, precise for the critical small eigenvalues)
   - Recommendation: **Option A for the bulk, Option B for the 10 smallest eigenvalues**
3. Output: sorted eigenvalue list, spectral staircase, level spacings

### Phase 2: Density of States Analysis

1. **Histogram**: Bin eigenvalues into ~50 bins, compute $\rho(\lambda)$
2. **Kernel density estimate**: Gaussian KDE for smooth $\rho(\lambda)$
3. **Van Hove fit**: Near $\lambda_{\min}$, fit $\rho(\lambda) = A \ln|\lambda - E_0| + B$
   - Extract $A$, $E_0$, $B$
   - Check if $A$ is related to $c_{\text{holes}} \approx 0.04619$

### Phase 3: Thermodynamics

1. **Partition function**: $Z(\beta) = \sum_k e^{-\beta \lambda_k}$
2. **Free energy**: $F(\beta) = -\ln Z(\beta) / \beta$
3. **Specific heat**: $C_V(\beta) = \beta^2 \partial^2 (\beta F) / \partial \beta^2$
4. **Van Hove prediction**: $C_V$ should show a $\ln \beta$ divergence at the critical temperature $\beta_c \sim 1/\lambda_{\min}$

### Phase 4: Level Spacing Statistics

1. **Unfolded spacings**: Normalize eigenvalue gaps by local mean spacing
2. **Nearest-neighbor distribution**: $P(s)$ — compare with:
   - Poisson: $P(s) = e^{-s}$ (integrable, no repulsion)
   - GUE: $P(s) \sim s^2 e^{-4s^2/\pi}$ (chaotic, quadratic repulsion)
   - Van Hove: Intermediate — clustering near the singularity
3. **Number variance**: $\Sigma^2(L) = \text{Var}(\#\{\lambda_k \in [E, E+L]\})$

## Implementation Plan

### Rust Crate Structure

```
experiments/van-hove-probe/
├── Cargo.toml
├── src/
│   ├── main.rs          # CLI: --N 500 --precision 128
│   ├── gram.rs          # Reuse from baez-duarte (or symlink)
│   ├── eigensolve.rs    # Symmetric eigenvalue decomposition
│   ├── dos.rs           # Density of states, KDE, Van Hove fit
│   ├── thermo.rs        # Partition function, specific heat
│   └── spacing.rs       # Level spacing statistics
└── results/
    ├── eigenvalues_N100.json
    ├── dos_N100.json
    └── certificate.json
```

### Dependencies

```toml
[dependencies]
rug = { version = "1.24", features = ["float"] }
rayon = "1.10"
nalgebra = "0.33"        # For f64 eigensolve
serde = { version = "1", features = ["derive"] }
serde_json = "1"
```

### Key Design Decisions

1. **Eigensolve strategy**: For N ≤ 500, f64 eigensolve via `nalgebra` is fine for the bulk spectrum. For the smallest 10 eigenvalues (which determine the Van Hove structure), use inverse iteration in 128-bit MPFR after getting approximate eigenvalues from f64.

2. **Gram matrix reuse**: The `gram_entry_mpfr128` function from `analysis_f64.rs` computes individual entries. For eigenvalue extraction, we need the full matrix in f64 for nalgebra. Build in MPFR, convert to f64 for the eigensolve.

3. **Output format**: JSON certificates with all eigenvalues, DOS histogram, fitted Van Hove parameters, and thermodynamic quantities. These feed directly into HyperZeta for visualization.

## Expected Results

### If the Van Hove picture is correct:

- $\rho(\lambda)$ near $\lambda_{\min}$ fits $A \ln|\lambda - E_0| + B$ with $R^2 > 0.95$
- The fitted $A$ relates to $c_{\text{holes}}$ by a geometric factor (lattice coordination number)
- Level spacings near $\lambda_{\min}$ show clustering (not GUE repulsion)
- Specific heat diverges logarithmically at $\beta_c$

### If the Van Hove picture is wrong:

- $\rho(\lambda)$ near $\lambda_{\min}$ fits a power law $(\lambda - E_0)^\alpha$ better than a log
- This would suggest the $1/\ln N$ decay comes from a different mechanism (e.g., Tracy-Widom edge statistics)
- Still valuable — we'd learn what the spectral edge structure actually is

## Connection to the Cathedral

This experiment tests the deepest structural claim in the physics paper: that the Gram matrix is a tight-binding Hamiltonian on a multiplicative quasicrystal, and that the BD constant $C \approx 21.649$ is the coefficient of a 2D Van Hove logarithm.

If confirmed, it would:
1. Provide a physical mechanism for the $1/\ln N$ convergence rate
2. Connect the Cathedral to the solid-state physics literature on quasicrystals
3. Suggest new spectral analysis tools (Van Hove fitting, thermal probes) for future axiom graduation
4. Strengthen the physics paper's "prime number gas" thermodynamic dictionary

## Timeline

- **Phase 1** (eigenvalue extraction): ~2 hours of coding, runs in minutes for N ≤ 500
- **Phase 2** (DOS analysis): ~1 hour, mostly analysis code
- **Phase 3** (thermodynamics): ~1 hour, straightforward from eigenvalues
- **Phase 4** (level spacings): ~2 hours, requires careful unfolding

Total: One focused afternoon session.

---

*Sweet dreams, Jason. The primes will still be quasi-crystalline in the morning.* 🏛️🌙✨
