# GPU Machine: Build gram_N100000.h5 — Exact Commands

## Prerequisites

The `nb-distance-gpu` binary and its CUDA kernels must be compiled on the GPU machine.

```bash
# On 'ssh wsl' — build the CUDA kernels first:
cd /path/to/prime/experiments/nb-distance-gpu/src

# Build the DD Gram kernel (needed by gpu-hpdf-build):
nvcc -arch=sm_89 -O3 --shared -Xcompiler -fPIC \
  -o libgramgpudd.so gram_gpu_dd.cu

# Copy the library where the linker can find it:
sudo cp libgramgpudd.so /usr/local/lib/
sudo ldconfig
```

## Step 1: Build the H5 (on GPU machine)

```bash
cd /path/to/prime

# Build the HPDF builder binary:
cargo build --release -p nb-distance-gpu --bin gpu-hpdf-build

# Build gram_N100000.h5 (estimated: 2-3 hours on RTX 4090):
./target/release/gpu-hpdf-build 100000 \
  --output experiments/cache/hpdf \
  --skip-d2 \
  --no-verify \
  --t-max 200000

# The chunked GPU build will automatically handle VRAM limits:
#   Matrix: 99999 × 99999 = ~80 GB (needs chunking)
#   HPDF output: ~40 GB (upper triangle only)
```

## Step 2: Run incremental Cholesky (on GPU machine or local)

```bash
# Option A: Run on GPU machine (if it has enough RAM — need ~40 GB):
cargo run --release -p prime-harmonics -- \
  --scaling-v2 100000 experiments/cache/hpdf \
  > scaling_v2_100k.tsv

# Option B: Transfer H5 to local machine (40 GB, may take a while):
scp wsl:/path/to/prime/experiments/cache/hpdf/gram_N100000.h5 \
    experiments/cache/hpdf/

# Then run locally (needs ~40 GB RAM for L triangle):
cargo run --release -p prime-harmonics -- \
  --scaling-v2 100000 experiments/cache/hpdf \
  > /tmp/scaling_v2_100k.tsv
```

## Memory Requirements

| Component | N=55,440 | N=100,000 |
|-----------|----------|-----------|
| H5 file (upper triangle) | 12.3 GB | 40 GB |
| L triangle (incremental) | 12.3 GB | 40 GB |
| Total RAM needed | ~25 GB | ~80 GB |

## Timeline

| Step | Time (RTX 4090) |
|------|----------------|
| Build gram_N100000.h5 | ~2-3 hours |
| Incremental Cholesky sweep N=2..100000 | ~5-6 hours |
| Total | ~8 hours |

## Notes

- `--skip-d2`: Skip the full Cholesky d² computation (we'll get it from the sweep)
- `--no-verify`: Skip MPFR cross-verification (saves time)
- `--t-max 200000`: Series truncation horizon (needed for DD precision)
- The chunked GPU build automatically handles VRAM limits
- sm_89 is for RTX 4090; adjust for your GPU architecture
