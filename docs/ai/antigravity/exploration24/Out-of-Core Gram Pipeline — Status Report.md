# 📡 Out-of-Core Gram Matrix Pipeline — Status & Next Steps

**Filed:** May 2, 2026, 4:20 AM MDT  
**Context:** Gemini Report 35 (Leviathan Roadmap) + existing `nb-distance-gpu` infrastructure

---

## 1. Current State — What You Already Have

### 1.1 Build Pipeline (cathedral-utils)
- `gram-builder`: Builds Gram matrices at arbitrary precision (f64 / DD / MPFR)
- Three algorithms: standard O(T), block-based O(T/j+T/k), double-double
- **12-core rayon parallelism**, Kahan summation, adaptive early-exit
- Binary cache format: `CATHEDRA` magic, checksum, row-major f64

### 1.2 Cached Matrices (Already on Disk!)

| File | N | Size | Format |
|------|---|------|--------|
| `dd_gram_N5000_mpfr256.bin` | 5,000 | 400 MB | DD (hi+lo) |
| `dd_gram_N10000_mpfr256.bin` | 10,000 | 1.6 GB | DD (hi+lo) |
| `dd_gram_N20000_mpfr256.bin` | 20,000 | 6.4 GB | DD (hi+lo) |
| `dd_gram_N40000_mpfr256.bin` | 40,000 | 25.6 GB | DD (hi+lo) |
| + various `gram_N100_*` | 100 | 78 KB | Multiple precisions |
| + `gram_N1000_*` | 1,000 | 8 MB | MPFR-106/128 |

**You already have a 40,000×40,000 DD Gram matrix cached at 256-bit MPFR precision!** This is the largest matrix you've built.

### 1.3 GPU Pipeline (nb-distance-gpu)

| Component | Status | Notes |
|-----------|--------|-------|
| `gpu_syevd` — Full eigendecomposition | ✅ Working | cuSOLVER, row→col conversion |
| `gpu_spectral_projections` — V^T b on GPU | ✅ Working | Avoids 12.8 GB eigenvector download |
| `gpu_eigenvalues_only` — NoVec mode | ✅ Working | ~14 GB for N=40K (fits in 24 GB VRAM) |
| `gpu_cholesky_d2` — f64 Cholesky | ✅ Working | d² = 1 - b^T G^{-1} b |
| `gpu_dd_cholesky` — DD Cholesky | ✅ Working | ~31 digit precision, custom CUDA kernel |
| `gpu_ds_cholesky` — DS-f32 Cholesky | ✅ Working | ~14 digits at f32 speed |
| `gpu_qs_cholesky` — QS-f32 Cholesky | ✅ Working | ~28 digits at f32 speed |
| **cargo check** | ✅ **COMPILES** | 15 warnings (unused fields) |

### 1.4 The Gap

**What's NOT implemented:**
1. **Out-of-Core (OOC) Matrix-Vector Multiply** — Gemini's proposal for N > 50,000
2. **Iterative Solver** — Conjugate Gradient / Lanczos for d² from disk
3. **Chunked Eigenvalue Computation** — streaming matrix blocks through GPU

---

## 2. Gemini's Out-of-Core Proposal (Report 35)

### The Architecture

```
┌─────────────────────────────────────────────────┐
│                 NVMe SSD Array                  │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐          │
│  │ Block 0 │ │ Block 1 │ │ Block 2 │ ...       │
│  │ (12 GB) │ │ (12 GB) │ │ (12 GB) │          │
│  └────┬────┘ └────┬────┘ └────┬────┘          │
└───────┼──────────┼──────────┼──────────────────┘
        │          │          │
        ▼          ▼          ▼
   ┌────────────────────────────────┐
   │     PCIe Gen4 x16 Bus         │
   │     (~28 GB/s peak)           │
   └──────────┬─────────────────────┘
              │
   ┌──────────▼─────────────────────┐
   │       RTX 4090 (24 GB VRAM)    │
   │  ┌──────────────────────────┐  │
   │  │   cuBLAS dgemv kernel    │  │
   │  │   v_new = G_block · v    │  │
   │  │   accumulate result      │  │
   │  └──────────────────────────┘  │
   └────────────────────────────────┘
```

**Key insight:** For d² = 1 - b^T G^{-1} b via Conjugate Gradient:
- Only need **one operation**: matrix-vector multiply v → Gv
- Stream G in chunks from disk, multiply each chunk, accumulate
- Vector v fits in ~8 MB (even at N=1,000,000)
- CG converges in ~100-200 iterations for well-conditioned systems

### Target Schedule (from Report 35)

| N | Matrix Size | Storage | CG Time (est.) |
|---|------------|---------|----------------|
| 55,440 | 24.6 GB | 2 chunks | ~10 min |
| 110,880 | 98.3 GB | 8 chunks | ~40 min |
| 332,640 | 885 GB | 74 chunks | ~6 hr |
| 720,720 | 4.15 TB | 346 chunks | ~36 hr |
| 1,081,080 | 9.35 TB | 780 chunks | ~4 days |

---

## 3. What We Can Do RIGHT NOW (Without OOC)

### 3.1 Direct Approach: Use Existing N=40,000 Cache

The DD Gram matrix for N=40,000 is already cached (25.6 GB). Since it's stored as (hi+lo) pairs, the actual f64 matrix is 12.8 GB — **which fits in 24 GB VRAM!**

```
Steps:
1. Load dd_gram_N40000_mpfr256.bin (just the hi part, 12.8 GB)
2. Upload to GPU (takes ~2s on PCIe Gen4)
3. Run gpu_eigenvalues_only (NoVec mode, ~14 GB total)
4. Run gpu_cholesky_d2 for d²
```

**This should work TODAY** with your existing code. The `gpu_spectral` binary already does exactly this — it loads the DD cache and runs eigenvalue analysis.

### 3.2 Quick Win: Write-to-Disk for N=50,000

The current Gram builder can generate N=50,000 in a few hours on your M2 Max. The matrix would be:
- Size: 49,999² × 8 = 20 GB (f64) or 40 GB (DD)
- Build time: ~4-8 hours with the block-based fast algorithm

But this exceeds 24 GB VRAM for eigendecomposition. This is where the OOC approach kicks in.

---

## 4. Implementation Plan: Out-of-Core CG Solver

### Phase 1: Chunked Matrix-Vector Multiply (~200 lines)

```rust
/// Compute y = G · x where G is too large for RAM.
/// Reads G from disk in row-block chunks, streams each through GPU.
fn ooc_matvec(
    gram_path: &Path,
    x: &[f64],       // input vector (fits in RAM)
    y: &mut [f64],    // output vector (fits in RAM)
    dim: usize,
    chunk_rows: usize, // e.g., 4096 rows per chunk
) -> Result<(), String> {
    let mut file = File::open(gram_path)?;
    file.seek(SeekFrom::Start(HEADER_SIZE))?; // skip cache header
    
    let chunk_bytes = chunk_rows * dim * 8;
    let mut buffer = vec![0.0f64; chunk_rows * dim];
    
    for start_row in (0..dim).step_by(chunk_rows) {
        let rows = chunk_rows.min(dim - start_row);
        let bytes = rows * dim * 8;
        
        // Read chunk from disk
        file.read_exact(&mut buffer[..rows * dim])?;
        
        // GPU: y[start..start+rows] += chunk * x
        gpu_matvec_chunk(&buffer[..rows*dim], x, &mut y[start_row..], rows, dim)?;
    }
    Ok(())
}
```

### Phase 2: Conjugate Gradient Solver (~100 lines)

```rust
/// Solve G · c = b via Conjugate Gradient, using OOC matvec.
/// Returns c such that d² = 1 - b^T c.
fn ooc_conjugate_gradient(
    gram_path: &Path,
    b: &[f64],
    dim: usize,
    max_iter: usize,
    tol: f64,
) -> Vec<f64> {
    let mut x = vec![0.0; dim];   // solution
    let mut r = b.to_vec();        // residual = b - G·x = b (since x=0)
    let mut p = r.clone();         // search direction
    let mut r_dot_r = dot(&r, &r);
    
    for k in 0..max_iter {
        let mut ap = vec![0.0; dim];
        ooc_matvec(gram_path, &p, &mut ap, dim, 4096)?;
        
        let alpha = r_dot_r / dot(&p, &ap);
        axpy(alpha, &p, &mut x);       // x += α·p
        axpy(-alpha, &ap, &mut r);      // r -= α·A·p
        
        let r_dot_r_new = dot(&r, &r);
        if r_dot_r_new.sqrt() < tol { break; }
        
        let beta = r_dot_r_new / r_dot_r;
        for i in 0..dim { p[i] = r[i] + beta * p[i]; }
        r_dot_r = r_dot_r_new;
    }
    x
}
```

### Phase 3: Integration (~50 lines)

New binary `ooc-probe` that:
1. Reads a cached Gram matrix from disk
2. Runs CG to get d² = 1 - b^T G^{-1} b
3. Optionally does eigenvalue analysis via Lanczos (also OOC-friendly)

---

## 5. Immediate Next Step (No New Code Needed!)

**Before building OOC, let's verify your existing pipeline works at N=40,000:**

```bash
# From experiments/nb-distance-gpu:
cargo run --bin gpu-spectral -- 40000
```

If this loads the cached DD Gram and runs eigendecomposition + d² on GPU, you already have the largest NB distance computation ever done on consumer hardware. The OOC engine is only needed for N > ~50,000.

---

## 6. Build Estimate for OOC Engine

| Component | Lines | Time |
|-----------|-------|------|
| `ooc_matvec` — chunked disk→GPU multiply | ~200 | 2 hr |
| `ooc_cg_solver` — conjugate gradient | ~100 | 1 hr |
| `ooc_lanczos` — eigenvalue estimates | ~200 | 3 hr |
| `ooc-probe` binary — integration | ~100 | 1 hr |
| Testing at N=55,440 | — | 1 hr |
| **Total** | **~600** | **~8 hr** |

This is a Saturday project. One session to build the pipeline, one session to test at N=55,440 (the first Leviathan).

---

**Bottom line:** Your existing infrastructure is 90% of the way there. The N=40,000 run should work NOW with what you have. The OOC engine is a ~600-line addition for N > 50,000. Gemini's Leviathan roadmap is architecturally sound.

**🏛️ 🔧 ⚡ 🌊**
