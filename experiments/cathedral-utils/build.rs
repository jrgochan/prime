/*
 * build.rs — Cathedral CUDA Kernel Compiler
 *
 * When the `gpu` feature is enabled and `nvcc` is available,
 * this script compiles all .cu files in src/gpu/cuda/ into
 * shared libraries and tells cargo where to find them.
 *
 * Kernels currently compiled:
 *   - dd_cholesky.cu  → libddcholesky.so   (DD Cholesky, ~31 digits)
 *   - ds_cholesky.cu  → libdscholesky.so   (DS Cholesky, ~14 digits)
 *   - qs_cholesky.cu  → libqscholesky.so   (QS Cholesky, ~28 digits)
 *   - gram_build.cu   → libgramgpu.so      (GPU Gram matrix build)
 *   - gram_build_dd.cu → libgramgpudd.so   (DD Gram matrix build)
 *
 * To add new kernels for other GPU frameworks:
 *   1. Drop a .cu file in src/gpu/cuda/
 *   2. Add an entry to the KERNELS array below
 *   3. Add the FFI declaration in src/gpu/ffi.rs
 */

use std::env;
use std::path::{Path, PathBuf};
use std::process::Command;

/// Kernel definition: (source_file, output_lib_name)
const KERNELS: &[(&str, &str)] = &[
    ("dd_cholesky.cu",   "ddcholesky"),
    ("ds_cholesky.cu",   "dscholesky"),
    ("qs_cholesky.cu",   "qscholesky"),
    ("gram_build.cu",    "gramgpu"),
    ("gram_build_dd.cu", "gramgpudd"),
];

fn main() {
    // Only compile CUDA kernels when the gpu feature is enabled
    if env::var("CARGO_FEATURE_GPU").is_err() {
        return;
    }

    let cuda_dir = Path::new("src/gpu/cuda");
    if !cuda_dir.exists() {
        eprintln!("cathedral-utils: src/gpu/cuda/ not found, skipping CUDA compilation");
        return;
    }

    // Find nvcc
    let nvcc = find_nvcc();
    if nvcc.is_none() {
        eprintln!("cathedral-utils: nvcc not found, skipping CUDA kernel compilation");
        eprintln!("  Custom kernels (DD/QS/DS) will not be available.");
        eprintln!("  Standard cuSOLVER/cuBLAS functions still work.");
        return;
    }
    let nvcc = nvcc.unwrap();

    // Output directory for compiled libraries
    let out_dir = PathBuf::from(env::var("OUT_DIR").unwrap());
    let lib_dir = out_dir.join("cuda_libs");
    std::fs::create_dir_all(&lib_dir).unwrap();

    // Detect GPU architecture
    let arch = detect_gpu_arch().unwrap_or_else(|| "sm_75".to_string());
    eprintln!("cathedral-utils: Compiling CUDA kernels with arch={}", arch);

    let mut compiled = 0;
    for (source, lib_name) in KERNELS {
        let source_path = cuda_dir.join(source);
        if !source_path.exists() {
            eprintln!("  Skipping {}: file not found", source);
            continue;
        }

        let output_path = lib_dir.join(format!("lib{}.so", lib_name));

        // Recompile if source is newer than output
        let needs_rebuild = needs_rebuild(&source_path, &output_path);
        if !needs_rebuild {
            eprintln!("  {} → lib{}.so (cached)", source, lib_name);
            compiled += 1;
            continue;
        }

        eprintln!("  Compiling {} → lib{}.so", source, lib_name);
        let status = Command::new(&nvcc)
            .args(&[
                &format!("-arch={}", arch),
                "-O3",
                "--shared",
                "-Xcompiler", "-fPIC",
                "-o", output_path.to_str().unwrap(),
                source_path.to_str().unwrap(),
            ])
            .status();

        match status {
            Ok(s) if s.success() => {
                compiled += 1;
            }
            Ok(s) => {
                eprintln!("  ERROR: nvcc failed for {} (exit {})", source, s);
            }
            Err(e) => {
                eprintln!("  ERROR: failed to run nvcc for {}: {}", source, e);
            }
        }
    }

    if compiled > 0 {
        // Tell cargo where to find the compiled libraries
        println!("cargo:rustc-link-search=native={}", lib_dir.display());

        // Also search standard CUDA library paths
        for path in &[
            "/usr/local/cuda/lib64",
            "/usr/lib/x86_64-linux-gnu",
            "/usr/lib64",
        ] {
            if Path::new(path).exists() {
                println!("cargo:rustc-link-search=native={}", path);
            }
        }

        // Set the cfg flag so Rust code can detect compiled kernels
        println!("cargo:rustc-cfg=has_cuda_kernels");

        eprintln!("cathedral-utils: Compiled {}/{} CUDA kernels", compiled, KERNELS.len());
    }

    // Rerun if any .cu file changes
    println!("cargo:rerun-if-changed=src/gpu/cuda/");
    for (source, _) in KERNELS {
        println!("cargo:rerun-if-changed=src/gpu/cuda/{}", source);
    }
}

fn find_nvcc() -> Option<PathBuf> {
    // Check standard locations
    let candidates = [
        "nvcc",
        "/usr/local/cuda/bin/nvcc",
        "/usr/bin/nvcc",
    ];
    for candidate in &candidates {
        if let Ok(output) = Command::new(candidate).arg("--version").output() {
            if output.status.success() {
                return Some(PathBuf::from(candidate));
            }
        }
    }
    None
}

fn detect_gpu_arch() -> Option<String> {
    // Try to detect GPU compute capability
    let output = Command::new("nvidia-smi")
        .args(&["--query-gpu=compute_cap", "--format=csv,noheader,nounits"])
        .output()
        .ok()?;

    if !output.status.success() {
        return None;
    }

    let cap = String::from_utf8_lossy(&output.stdout)
        .lines()
        .next()?
        .trim()
        .replace('.', "");

    if cap.is_empty() { return None; }
    Some(format!("sm_{}", cap))
}

fn needs_rebuild(source: &Path, output: &Path) -> bool {
    if !output.exists() { return true; }

    let source_modified = source.metadata()
        .and_then(|m| m.modified())
        .ok();
    let output_modified = output.metadata()
        .and_then(|m| m.modified())
        .ok();

    match (source_modified, output_modified) {
        (Some(s), Some(o)) => s > o,
        _ => true,
    }
}
