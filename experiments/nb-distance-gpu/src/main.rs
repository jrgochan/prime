//! GPU-accelerated Nyman-Beurling distance probe.
//!
//! Uses cuSOLVER for eigendecomposition (100-300x faster than CPU).
//! Loads Gram matrices built by cathedral-utils (any precision).

mod gpu;

use cathedral_utils::{arith, cache, fitting, gram::GramMatrix};
use nalgebra::{DMatrix, DVector};

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let max_n: usize = args.get(1).and_then(|s| s.parse().ok()).unwrap_or(1000);

    println!();
    println!("  ╔═══════════════════════════════════════════════════════════════╗");
    println!("  ║  NYMAN-BEURLING DISTANCE PROBE (GPU-ACCELERATED)");
    println!("  ║  d²_N = 1 - b^T G_N^{{-1}} b  ·  RH ⟺ d²_N → 0");
    println!("  ║  Max N = {}  ·  cuSOLVER eigendecomposition", max_n);
    println!("  ╚═══════════════════════════════════════════════════════════════╝");
    println!();

    // Detect GPU
    match gpu::detect_gpu() {
        Some(info) => {
            println!(
                "  \x1b[32m✓ GPU detected: {} ({} MB VRAM)\x1b[0m",
                info.name, info.vram_mb
            );
        }
        None => {
            eprintln!("  ✗ No CUDA GPU detected.");
            std::process::exit(1);
        }
    }

    // Find and load best cached Gram matrix
    let gram = find_cached_gram(max_n);

    // Build test schedule
    let test_ns = build_schedule(max_n);

    println!();
    println!("  \x1b[1m\x1b[97m═══ DISTANCE + SPECTRAL ANALYSIS (GPU) ═══\x1b[0m");
    println!("  \x1b[2m     N  │ d²_N            │ λ_min          │ GPU(s)   │ D(N)         │ |⟨b,v_min⟩|\x1b[0m");
    println!("  \x1b[2m  ──────┼─────────────────┼────────────────┼──────────┼──────────────┼─────────────\x1b[0m");

    let mut results: Vec<NResult> = Vec::new();

    for &n in &test_ns {
        if n < 3 || n > gram.max_n {
            continue;
        }
        let dim = n - 1;
        let (sub, _) = gram.extract_submatrix(n);
        let b = arith::b_vector(dim);

        // Cholesky solve for d² (CPU — numerically stable)
        let g_mat = DMatrix::from_fn(dim, dim, |i, j| sub[i * dim + j]);
        let bv = DVector::from_column_slice(&b[..dim]);
        let d2 = if let Some(chol) = g_mat.clone().cholesky() {
            let c = chol.solve(&bv);
            1.0 - bv.dot(&c)
        } else {
            f64::NAN
        };

        // GPU eigendecomposition
        match gpu::gpu_syevd(&sub, dim) {
            Ok(result) => {
                let lambda_min = result.eigenvalues[0];

                // v_min is column 0 (column-major storage)
                let mut vmin_linf = 0.0f64;
                let mut b_vmin_proj = 0.0f64;
                for i in 0..dim {
                    let v = result.eigenvectors[i]; // col 0, row i
                    vmin_linf = vmin_linf.max(v.abs());
                    b_vmin_proj += b[i] * v;
                }
                b_vmin_proj = b_vmin_proj.abs();
                let deloc_ratio = vmin_linf * (dim as f64).sqrt();

                let status = if d2 > 0.0 && d2 < 1.0 { "✓" } else { "⚠" };

                println!(
                    "  {:<6} │ {:+.10e} │ {:.10e} │ {:.4}s   │ {:.6e}  │ {:.6e} {}",
                    n, d2, lambda_min, result.gpu_time_secs, deloc_ratio, b_vmin_proj, status
                );

                results.push(NResult {
                    n,
                    d2,
                    lambda_min,
                    gpu_time: result.gpu_time_secs,
                    deloc_ratio,
                    b_vmin_proj,
                });
            }
            Err(e) => {
                eprintln!("  {:<6} │ {:+.10e} │ GPU ERROR: {}", n, d2, e);
            }
        }
    }

    println!();

    // Scaling fits
    if results.len() >= 5 {
        let d2_data: Vec<(f64, f64)> = results
            .iter()
            .filter(|r| r.n >= 10 && r.d2 > 0.0)
            .map(|r| ((r.n as f64).ln(), r.d2.ln()))
            .collect();
        if d2_data.len() >= 3 {
            let (alpha, c_ln, r2) = fitting::linreg(&d2_data);
            println!(
                "  d² decay:  d² ~ {:.4} · N^({:.4})   R² = {:.4}",
                c_ln.exp(),
                alpha,
                r2
            );
        }

        let deloc_data: Vec<(f64, f64)> = results
            .iter()
            .filter(|r| r.n >= 10 && r.deloc_ratio > 0.0)
            .map(|r| ((r.n as f64).ln(), r.deloc_ratio.ln()))
            .collect();
        if deloc_data.len() >= 3 {
            let (slope, intercept, r2) = fitting::linreg(&deloc_data);
            println!(
                "  D(N) scaling:  D(N) ~ {:.4} · N^({:.4})   R² = {:.4}",
                intercept.exp(),
                slope,
                r2
            );
        }

        let bproj_data: Vec<(f64, f64)> = results
            .iter()
            .filter(|r| r.n >= 10 && r.b_vmin_proj > 0.0)
            .map(|r| ((r.n as f64).ln(), r.b_vmin_proj.ln()))
            .collect();
        if bproj_data.len() >= 3 {
            let (slope, intercept, r2) = fitting::linreg(&bproj_data);
            println!(
                "  |⟨b,v_min⟩| scaling:  ~ {:.4} · N^({:.4})   R² = {:.4}",
                intercept.exp(),
                slope,
                r2
            );
        }
    }

    // Summary
    let total_gpu: f64 = results.iter().map(|r| r.gpu_time).sum();
    println!();
    println!(
        "  Total GPU time: {:.2}s for {} eigendecompositions",
        total_gpu,
        results.len()
    );
    println!();
}

struct NResult {
    n: usize,
    d2: f64,
    lambda_min: f64,
    gpu_time: f64,
    deloc_ratio: f64,
    b_vmin_proj: f64,
}

fn find_cached_gram(max_n: usize) -> GramMatrix {
    // Try various precision levels, largest matrix first
    let cache_dir = cache::cache_dir();
    eprintln!(
        "  \x1b[2mSearching for cached Gram matrices in {}\x1b[0m",
        cache_dir.display()
    );

    // Look for files matching gram_N*_*.bin
    let mut best: Option<GramMatrix> = None;
    if let Ok(entries) = std::fs::read_dir(&cache_dir) {
        for entry in entries.flatten() {
            let name = entry.file_name().to_string_lossy().to_string();
            if name.starts_with("gram_N") && name.ends_with(".bin") {
                if let Some(g) = cache::load_gram(&entry.path()) {
                    if g.max_n >= max_n && best.as_ref().is_none_or(|b| g.precision > b.precision) {
                        best = Some(g);
                    }
                }
            }
        }
    }

    match best {
        Some(g) => {
            eprintln!(
                "  \x1b[32m✓ Using cached Gram matrix (N={}, {}-bit, {} MB)\x1b[0m",
                g.max_n,
                g.precision,
                g.data.len() * 8 / (1024 * 1024)
            );
            g
        }
        None => {
            eprintln!("  ✗ No cached Gram matrix found for N={}.", max_n);
            eprintln!("    Run: gram-builder {} --precision dd", max_n);
            std::process::exit(1);
        }
    }
}

fn build_schedule(max_n: usize) -> Vec<usize> {
    let mut ns = Vec::new();
    for n in 3..=30.min(max_n) {
        ns.push(n);
    }
    for n in (35..=100.min(max_n)).step_by(5) {
        ns.push(n);
    }
    for n in (125..=500.min(max_n)).step_by(25) {
        ns.push(n);
    }
    for n in (550..=1000.min(max_n)).step_by(50) {
        ns.push(n);
    }
    for n in (1100..=2000.min(max_n)).step_by(100) {
        ns.push(n);
    }
    for n in (2200..=5000.min(max_n)).step_by(200) {
        ns.push(n);
    }
    for n in (5500..=max_n).step_by(500) {
        ns.push(n);
    }
    if !ns.contains(&max_n) && max_n >= 3 {
        ns.push(max_n);
    }
    ns.sort();
    ns.dedup();
    ns
}
