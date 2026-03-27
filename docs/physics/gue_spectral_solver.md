# Gaussian Unitary Ensemble (GUE) & Spectral Physics

A central pillar of the Hilbert-Pólya conjecture involves identifying an infinite-dimensional Hermitian matrix (a Hamiltonian operator) whose spectral eigenvalues correspond precisely to the distribution of prime zeros. 

## The Accelerated Physics Engine (Rust)

The Rust hyper-engine generates colossal state matrices via the **Gaussian Unitary Ensemble (GUE)**. Generating millions of these massive grids relies on specific cryptographic boundaries.

### Core Matrix Generation (The AMX Binding)
1.  **Libraries:** The engine must bind heavily to Apple's **Accelerate Framework**. Through crates linking `vecLib` and `BLAS`, the Rust ecosystem explicitly targets the M2 Max chip's undocumented **Apple Matrix Coprocessors (AMX)**.
2.  **The True Randomness Requirement:** 
    > [!CAUTION]
    > Using standard PRNGs (like Mersenne Twister or standard `rand`) across 16-Dimensional fields creates periodic algorithmic clustering. The Agent will hallucinate shapes that are artifacts of the computer, not mathematics.
    
    *   The backend **must** populate GUE elements and Monte Carlo probes utilizing **Low-Discrepancy Quasi-Random sequences (e.g., Sobol Sequences)**. This ensures perfectly unified continuous dimensional loading without mathematical clustering.

### The Eigenvalue Filter
The system actively solves down the GUE matrix looking for specific eigenvalue gaps:
1.  Extracts the energy levels (eigenvalues) utilizing the accelerated AMX linear algebra routines.
2.  Measures the continuous spacing between sequential levels.
3.  Writes the variance arrays instantly into the SharedArrayBuffer for WebGPU visual extraction, mirroring the Montgomery-Odlyzko prime gaps.
