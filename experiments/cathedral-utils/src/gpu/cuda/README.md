# Cathedral CUDA Kernels

This directory contains the CUDA kernel source files for the Cathedral GPU acceleration pipeline.

## Auto-Compilation

When building with the `gpu` feature enabled and `nvcc` is available, the `build.rs` script automatically compiles these kernels into shared libraries. No manual compilation needed.

```bash
# Build with GPU + auto-compiled kernels
cargo build --features gpu
```

## Current Kernels

| File | Library | Description | Precision |
|------|---------|-------------|-----------|
| `dd_cholesky.cu` | `libddcholesky.so` | Double-double Cholesky d² | ~31 digits |
| `ds_cholesky.cu` | `libdscholesky.so` | Double-single Cholesky d² | ~14 digits |
| `qs_cholesky.cu` | `libqscholesky.so` | Quad-single Cholesky d² | ~28 digits |
| `gram_build.cu` | `libgramgpu.so` | GPU Gram matrix construction | QS |
| `gram_build_dd.cu` | `libgramgpudd.so` | GPU DD Gram matrix construction | DD |

## Adding New Kernels

To add a new CUDA kernel:

1. **Create the `.cu` file** in this directory
2. **Export a C API** using `extern "C" { ... }`
3. **Register in `build.rs`**: Add an entry to the `KERNELS` array:
   ```rust
   ("my_kernel.cu", "mykernel"),  // → libmykernel.so
   ```
4. **Add FFI declaration** in `src/gpu/ffi.rs`:
   ```rust
   #[cfg(has_cuda_kernels)]
   #[link(name = "mykernel")]
   extern "C" {
       pub fn my_kernel_function(...) -> ...;
   }
   ```
5. **Add safe wrapper** in the appropriate module (e.g., `src/gpu/cholesky.rs`)

## Other GPU Frameworks

The architecture supports non-CUDA backends. To add support for:

- **ROCm/HIP**: Add `.hip` files and extend `build.rs` with `hipcc` compilation
- **Metal**: Add `.metal` files and compile with `xcrun -sdk macosx metal`
- **Vulkan Compute**: Add SPIR-V shaders and link via `vulkan`
- **WebGPU**: Add WGSL shaders for browser-based computation

Each new backend should:
1. Create a new directory (e.g., `src/gpu/hip/`, `src/gpu/metal/`)
2. Add compile logic to `build.rs`
3. Use cfg flags for conditional compilation (e.g., `has_hip_kernels`)

## Build Requirements

- NVIDIA CUDA Toolkit (nvcc)
- GPU compute capability ≥ 7.5 (auto-detected via `nvidia-smi`)
- Linux (WSL supported)
