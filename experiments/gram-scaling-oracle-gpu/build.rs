fn main() {
    // ═══════════════════════════════════════════════════════════════
    // Link against CUDA libraries for GPU eigendecomposition
    // ═══════════════════════════════════════════════════════════════
    #[cfg(target_os = "linux")]
    {
        // cuSOLVER for GPU eigendecomposition (dsyevd)
        println!("cargo:rustc-link-lib=cusolver");
        // cuBLAS for GPU matrix-vector operations
        println!("cargo:rustc-link-lib=cublas");
        // CUDA runtime
        println!("cargo:rustc-link-lib=cudart");
        // OpenBLAS for CPU LAPACK fallback (dsyevr, dsyevd)
        println!("cargo:rustc-link-lib=openblas");

        // CUDA library paths
        println!("cargo:rustc-link-search=native=/usr/local/cuda/lib64");
        println!("cargo:rustc-link-search=native=/usr/lib/wsl/lib");
    }

    #[cfg(target_os = "macos")]
    {
        println!("cargo:rustc-link-lib=framework=Accelerate");
    }
}
