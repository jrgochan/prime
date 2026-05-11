fn main() {
    // ═══════════════════════════════════════════════════════════════
    // CUDA kernel compilation for GPU-accelerated skeleton key verification
    // ═══════════════════════════════════════════════════════════════
    #[cfg(target_os = "linux")]
    {
        // Compile CUDA kernel
        let cuda_src = "cuda/skeleton_keys.cu";
        let cuda_out = format!("{}/skeleton_keys.o", std::env::var("OUT_DIR").unwrap());

        let nvcc_status = std::process::Command::new("nvcc")
            .args(&[
                "-c",
                cuda_src,
                "-o",
                &cuda_out,
                "--gpu-architecture=sm_89", // Ada Lovelace (RTX 4090)
                "-O3",
                "--use_fast_math",
                "-Xcompiler",
                "-fPIC",
            ])
            .status();

        match nvcc_status {
            Ok(s) if s.success() => {
                println!(
                    "cargo:rustc-link-search=native={}",
                    std::env::var("OUT_DIR").unwrap()
                );
                // Link the compiled object
                let lib_dir = std::env::var("OUT_DIR").unwrap();
                let lib_path = format!("{}/libskeleton_keys.a", lib_dir);
                std::process::Command::new("ar")
                    .args(&["rcs", &lib_path, &cuda_out])
                    .status()
                    .expect("ar failed");
                println!("cargo:rustc-link-lib=static=skeleton_keys");
                println!("cargo:rustc-link-lib=cudart");
                println!("cargo:rustc-link-search=native=/usr/local/cuda/lib64");
                println!("cargo:rustc-link-search=native=/usr/lib/wsl/lib");
            }
            _ => {
                eprintln!("WARNING: nvcc not found or failed. GPU kernels disabled.");
                eprintln!("         CPU-only mode will be used.");
            }
        }

        println!("cargo:rerun-if-changed={}", cuda_src);
    }

    #[cfg(target_os = "macos")]
    {
        // No CUDA on macOS — CPU-only mode
        println!("cargo:warning=No CUDA on macOS — CPU-only mode");
    }
}
