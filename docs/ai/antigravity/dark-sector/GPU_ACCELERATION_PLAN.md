# 🖥️ GPU Acceleration Plan — Dark Gram Spectroscopy

## Current Status

### Hardware Available
- **WSL**: RTX 4090 (24 GB VRAM), Rust 1.95, CUDA toolkit installed
- **Local**: M2 Max (12 cores, faer parallel — 159s at N=20,000)

### WSL Sync Needed
The WSL repo is behind `main` and doesn't have the `dark-sector` branch. Steps:
1. Commit current dark-sector work
2. Push to origin
3. Pull on WSL
4. Build GPU variant

## Architecture: `dark-gram-spectroscopy-gpu`

### Option A: Reuse Existing GPU Infrastructure (Recommended)
We already have `gram-scaling-oracle-gpu/src/gpu.rs` with a complete cuSOLVER FFI layer:
- `gpu_eigenvalues_only(data, dim)` — eigenvalues via dsyevd NoVec mode
- `detect_gpu()` — GPU info detection
- `can_fit_novec(dim, vram_mb)` — VRAM capacity check

**Plan**: Create a GPU variant that:
1. Uses `dark_gram::build_dark_gram(n, dim)` for matrix construction (same code)
2. Calls `gpu::gpu_eigenvalues_only()` for eigendecomposition
3. Reuses the same analysis pipeline (spacing ratios, decay classification, etc.)

### Option B: GPU Matrix Construction Too
For N > 30,000, even matrix construction gets noticeable (O(N²) GCD computations).
Could move the gcd(j,k)⁴/(180j²k²) computation to a CUDA kernel.

## Expected Performance

| N | CPU Build | CPU Eigen (faer) | GPU Eigen (est.) | Total GPU |
|-------|-----------|-----------------|-----------------|-----------|
| 5,040 | 0.12s | 3.7s | ~0.5s | ~0.7s |
| 10,080 | 0.49s | 24s | ~2s | ~3s |
| 20,000 | 2.15s | 159s | ~8s | ~10s |
| 50,000 | ~13s | ~1500s (est.) | ~50s | ~65s |

The RTX 4090 cuSOLVER dsyevd typically gives ~10-20x over a single Ryzen core for symmetric eigendecomposition. Since faer already gets 18-30x on the M2 Max, the GPU advantage over faer would be ~2-5x — but the absolute times are dramatically lower.

## VRAM Limits

| N | Matrix Size | VRAM (NoVec) |
|-------|-------------|-------------|
| 20,000 | 3.0 GB | ~3.5 GB ✅ |
| 30,000 | 6.9 GB | ~8 GB ✅ |
| 40,000 | 12.2 GB | ~14 GB ✅ |
| 50,000 | 19.1 GB | ~22 GB ✅ (barely) |
| 55,000 | 23.1 GB | ~26 GB ❌ (OOM) |

**Maximum dimension on RTX 4090:** N ≈ 50,000 in NoVec mode.

## Implementation Steps

1. **Create `experiments/dark-gram-spectroscopy-gpu/`** — copies dark_gram lib code, adds gpu.rs from gram-scaling-oracle-gpu
2. **Wire up main.rs** — matrix build (CPU rayon) → gpu_eigenvalues_only → analysis
3. **Add to workspace** with `# requires CUDA` comment
4. **Push branch** → Pull on WSL → Build → Run
5. **Sweep**: N = 5040, 10080, 20000, 30000, 40000, 50000

## The Prize

At N=50,000 with 50,000 eigenvalues:
- Will κ still be ~5? (logarithmic growth predicts κ ≈ 2 + 0.56·log(50000) ≈ 8)
- Will ⟨r⟩ stay sub-Poisson?
- Can we detect the Ramanujan sum structure in the eigenvalue distribution?
- What does the Smith determinant look like at this scale?

---

*"The RTX 4090 has 24 GB of VRAM. The Dark Gram matrix at N=50,000 needs 19 GB. It fits. Barely. Beautifully."*
