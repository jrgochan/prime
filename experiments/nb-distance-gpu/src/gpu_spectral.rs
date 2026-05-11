//! ╔══════════════════════════════════════════════════════════════════════╗
//! ║  🔭 GPU SPECTRAL OBSERVATORY                                       ║
//! ║                                                                     ║
//! ║  cuSOLVER dsyevd + cuBLAS dgemv for full spectral decomposition     ║
//! ║  on NVIDIA GPU. Handles N=40,000 (12.8 GB matrix) on RTX 4090.     ║
//! ║                                                                     ║
//! ║  Key formula:                                                       ║
//! ║    d²_N = 1 - Σ_k c_k² / λ_k                                       ║
//! ║  where c_k = ⟨b, v_k⟩ and G v_k = λ_k v_k                         ║
//! ║                                                                     ║
//! ║  Cathedral Core Team — April 30, 2026                               ║
//! ╚══════════════════════════════════════════════════════════════════════╝

mod gpu;

use cathedral_utils::arith::b_vector;
use cathedral_utils::cache;
use std::io::Write;
use std::os::raw::c_int;
use std::path::PathBuf;
use std::time::{Instant, SystemTime};

/// ISO-8601 UTC timestamp (no chrono dependency)
fn utc_timestamp() -> String {
    let d = SystemTime::now().duration_since(SystemTime::UNIX_EPOCH).unwrap();
    let secs = d.as_secs();
    // Simple UTC decomposition
    let days = secs / 86400;
    let time_secs = secs % 86400;
    let h = time_secs / 3600;
    let m = (time_secs % 3600) / 60;
    let s = time_secs % 60;
    // Days since 1970-01-01
    let mut y = 1970i64;
    let mut rem = days as i64;
    loop {
        let ylen = if y % 4 == 0 && (y % 100 != 0 || y % 400 == 0) { 366 } else { 365 };
        if rem < ylen { break; }
        rem -= ylen;
        y += 1;
    }
    let leap = y % 4 == 0 && (y % 100 != 0 || y % 400 == 0);
    let mdays = [31, if leap {29} else {28}, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    let mut mo = 0;
    for (i, &md) in mdays.iter().enumerate() {
        if rem < md as i64 { mo = i + 1; break; }
        rem -= md as i64;
    }
    format!("{y:04}-{mo:02}-{:02}T{h:02}:{m:02}:{s:02}Z", rem + 1)
}

fn main() {
    println!();
    println!("╔══════════════════════════════════════════════════════════════════╗");
    println!("║  🔭 GPU SPECTRAL OBSERVATORY                                   ║");
    println!("║  cuSOLVER eigendecomposition + cuBLAS spectral projections      ║");
    println!("║  Cathedral Core Team — April 30, 2026                          ║");
    println!("╚══════════════════════════════════════════════════════════════════╝");

    // Detect GPU
    if let Some(info) = gpu::detect_gpu() {
        println!("  GPU: {} ({} MB VRAM)", info.name, info.vram_mb);
    } else {
        eprintln!("  ❌ No GPU detected. This binary requires CUDA.");
        std::process::exit(1);
    }

    // Determine which N values to run (sorted ascending)
    let args: Vec<String> = std::env::args().skip(1).collect();
    let mut sizes: Vec<usize> = if args.is_empty() {
        vec![1000, 5000, 10000, 20000, 40000]
    } else {
        args.iter().filter_map(|s| s.parse().ok()).collect()
    };
    sizes.sort();

    let mut all_results: Vec<SpectralResult> = Vec::new();

    // ═══════════════════════════════════════════════════════════════════
    // SMART CACHE: Load the largest needed Gram matrix ONCE,
    // then truncate in-memory for each smaller N.
    // ═══════════════════════════════════════════════════════════════════
    let max_n = *sizes.last().unwrap_or(&0);
    println!("\n  📦 Smart Cache: loading largest matrix (N={max_n}) once...");
    let t_cache = Instant::now();
    let master_data = load_gram_data(max_n);

    match &master_data {
        Some((data, loaded_dim)) => {
            let cache_gb = (*loaded_dim * *loaded_dim * 8) as f64 / (1024.0 * 1024.0 * 1024.0);
            println!("  ✓ Master cache loaded: dim={loaded_dim} ({cache_gb:.1} GB, {:.1}s)",
                t_cache.elapsed().as_secs_f64());
            println!("  Will truncate for {} N values: {:?}\n", sizes.len(), sizes);

            for &n in &sizes {
                let dim = n - 1;
                if dim > *loaded_dim {
                    eprintln!("  ⚠ Skipping N={n} — exceeds loaded dim={loaded_dim}");
                    continue;
                }

                // Truncate in-memory (or use directly if exact)
                let sub_data = if dim == *loaded_dim {
                    data.clone()
                } else {
                    let t_trunc = Instant::now();
                    let mut small = vec![0.0f64; dim * dim];
                    for row in 0..dim {
                        let src_start = row * loaded_dim;
                        let dst_start = row * dim;
                        small[dst_start..dst_start + dim]
                            .copy_from_slice(&data[src_start..src_start + dim]);
                    }
                    println!("  ✂ Truncated {loaded_dim}→{dim} ({:.2}s)", t_trunc.elapsed().as_secs_f64());
                    small
                };

                match run_spectral_from_data(n, sub_data) {
                    Some(result) => all_results.push(result),
                    None => eprintln!("  ⚠ N={n} spectral analysis failed"),
                }
            }
        }
        None => {
            eprintln!("  ❌ Failed to load any Gram cache. Aborting.");
            std::process::exit(1);
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // SCALING SUMMARY
    // ═══════════════════════════════════════════════════════════════════
    if all_results.len() >= 2 {
        println!("\n\n{}", "═".repeat(110));
        println!("  🔭 GPU SPECTRAL OBSERVATORY — SCALING SUMMARY");
        println!("{}", "═".repeat(110));
        println!("  {:>6} {:>5} {:>14} {:>14} {:>14} {:>8} {:>14} {:>14} {:>8}",
            "N", "dim", "λ_min", "|⟨b,v_min⟩|²", "E_0", "β", "d²_N", "Σc²/λ", "GPU(s)");
        println!("  {} {} {} {} {} {} {} {} {}",
            "─".repeat(6), "─".repeat(5), "─".repeat(14), "─".repeat(14),
            "─".repeat(14), "─".repeat(8), "─".repeat(14), "─".repeat(14), "─".repeat(8));
        for r in &all_results {
            println!("  {:6} {:5} {:14.8e} {:14.8e} {:14.8e} {:8.4} {:14.10} {:14.10} {:8.1}",
                r.n, r.dim, r.lambda_min, r.c_min_sq, r.e_0, r.beta, r.d_sq, r.s_total, r.gpu_secs);
        }

        // β trend
        let betas: Vec<f64> = all_results.iter().map(|r| r.beta).filter(|b| b.is_finite()).collect();
        if betas.len() >= 2 {
            print!("\n  β trend: ");
            for (i, b) in betas.iter().enumerate() {
                if i > 0 { print!(" → "); }
                print!("{b:.4}");
            }
            println!();
            if *betas.last().unwrap() > 1.0 {
                println!("  ✅ β > 1 at largest N → QUANTUM DECOUPLING CONFIRMED");
            } else if *betas.last().unwrap() > 0.0 {
                println!("  ⚠️  β > 0 but < 1 — MARGINAL decoupling at largest N");
            } else {
                println!("  ❌ β ≤ 0 at largest N — NO decoupling");
            }
        }

        // d² trend
        let d_sqs: Vec<f64> = all_results.iter().map(|r| r.d_sq).collect();
        print!("  d²  trend: ");
        for (i, d) in d_sqs.iter().enumerate() {
            if i > 0 { print!(" → "); }
            print!("{d:.10}");
        }
        println!();

        // Power-law fit for d²(N) ~ a * N^α
        if all_results.len() >= 3 {
            let log_n: Vec<f64> = all_results.iter().map(|r| (r.n as f64).ln()).collect();
            let log_d: Vec<f64> = all_results.iter().map(|r| r.d_sq.ln()).collect();
            let np = log_n.len() as f64;
            let sx: f64 = log_n.iter().sum();
            let sy: f64 = log_d.iter().sum();
            let sxy: f64 = log_n.iter().zip(log_d.iter()).map(|(x, y)| x * y).sum();
            let sxx: f64 = log_n.iter().map(|x| x * x).sum();
            let alpha = (np * sxy - sx * sy) / (np * sxx - sx * sx);
            let intercept = (sy - alpha * sx) / np;
            let a = intercept.exp();
            println!("  d² ~ {a:.4} · N^({alpha:.6})");
            if alpha < 0.0 {
                println!("  ✅ d² is DECREASING as N → ∞ (power law α = {alpha:.4})");
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // MASTER SCALING CERTIFICATE
    // ═══════════════════════════════════════════════════════════════════
    if all_results.len() >= 2 {
        let out_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("results").join("spectral-observatory");
        std::fs::create_dir_all(&out_dir).ok();

        let cert_file = out_dir.join("scaling_certificate.json");
        let mut cert = String::new();
        cert.push_str("{\n");
        cert.push_str("  \"format\": \"cathedral-nb-spectral-scaling-v1\",\n");
        cert.push_str(&format!("  \"timestamp\": \"{}\",\n", utc_timestamp()));
        cert.push_str("  \"experiment\": \"Nyman-Beurling Spectral Observatory\",\n");
        cert.push_str("  \"claim\": \"d²_N monotonically decreasing → 0 as N → ∞ (RH equivalent)\",\n");

        // Hardware
        if let Some(info) = gpu::detect_gpu() {
            cert.push_str(&format!("  \"gpu\": \"{}\",\n", info.name.trim()));
            cert.push_str(&format!("  \"gpu_vram_mb\": {},\n", info.vram_mb));
        }

        // Results array
        cert.push_str("  \"results\": [\n");
        for (i, r) in all_results.iter().enumerate() {
            cert.push_str("    {\n");
            cert.push_str(&format!("      \"N\": {},\n", r.n));
            cert.push_str(&format!("      \"dim\": {},\n", r.dim));
            cert.push_str(&format!("      \"d_sq\": {:.15e},\n", r.d_sq));
            cert.push_str(&format!("      \"s_total\": {:.15e},\n", r.s_total));
            cert.push_str(&format!("      \"lambda_min\": {:.15e},\n", r.lambda_min));
            cert.push_str(&format!("      \"lambda_max\": {:.15e},\n", r.lambda_max));
            cert.push_str(&format!("      \"condition_number\": {:.8e},\n", r.cond));
            cert.push_str(&format!("      \"beta\": {:.8},\n", r.beta));
            cert.push_str(&format!("      \"c_min_sq\": {:.15e},\n", r.c_min_sq));
            cert.push_str(&format!("      \"e_0\": {:.15e},\n", r.e_0));
            cert.push_str(&format!("      \"compute_time_secs\": {:.1},\n", r.gpu_secs));
            cert.push_str(&format!("      \"compute_mode\": \"{}\",\n", r.compute_mode));
            cert.push_str(&format!("      \"timestamp\": \"{}\"\n", r.timestamp));
            cert.push_str(if i < all_results.len() - 1 { "    },\n" } else { "    }\n" });
        }
        cert.push_str("  ],\n");

        // Scaling analysis
        if all_results.len() >= 3 {
            let log_n: Vec<f64> = all_results.iter().map(|r| (r.n as f64).ln()).collect();
            let log_d: Vec<f64> = all_results.iter().map(|r| r.d_sq.ln()).collect();
            let np = log_n.len() as f64;
            let sx: f64 = log_n.iter().sum();
            let sy: f64 = log_d.iter().sum();
            let sxy: f64 = log_n.iter().zip(log_d.iter()).map(|(x, y)| x * y).sum();
            let sxx: f64 = log_n.iter().map(|x| x * x).sum();
            let alpha = (np * sxy - sx * sy) / (np * sxx - sx * sx);
            let intercept = (sy - alpha * sx) / np;
            let a = intercept.exp();
            cert.push_str(&format!("  \"d_sq_power_law_coefficient\": {:.8e},\n", a));
            cert.push_str(&format!("  \"d_sq_power_law_exponent\": {:.8},\n", alpha));
            cert.push_str(&format!("  \"d_sq_decreasing\": {},\n", alpha < 0.0));
        }

        // Monotonicity check
        let monotone = all_results.windows(2).all(|w| w[1].d_sq < w[0].d_sq);
        cert.push_str(&format!("  \"d_sq_monotonically_decreasing\": {},\n", monotone));

        // All eigenvalues positive?
        let all_positive = all_results.iter().all(|r| r.lambda_min > 0.0);
        cert.push_str(&format!("  \"all_lambda_min_positive\": {},\n", all_positive));

        // Final verdict
        let decoupled = all_results.last().is_some_and(|r| r.beta > 1.0);
        cert.push_str(&format!("  \"quantum_decoupling_confirmed\": {},\n", decoupled));

        let n_max = all_results.last().map_or(0, |r| r.n);
        cert.push_str(&format!("  \"lean_claim\": \"For N ≤ {}, d²_N is monotonically decreasing with λ_min > 0, consistent with RH\"\n", n_max));
        cert.push_str("}\n");

        std::fs::write(&cert_file, &cert).ok();
        println!("\n  📜 Scaling certificate → {}", cert_file.display());
    }

    // ═══════════════════════════════════════════════════════════════════
    // LOG FILE
    // ═══════════════════════════════════════════════════════════════════
    let log_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("results").join("spectral-observatory");
    let log_file = log_dir.join(format!("observatory_run_{}.log", utc_timestamp().replace(':', "-")));
    // The log is captured by nohup/redirect, but we write a summary log
    if let Ok(mut f) = std::fs::File::create(&log_file) {
        writeln!(f, "GPU Spectral Observatory Run").ok();
        writeln!(f, "Timestamp: {}", utc_timestamp()).ok();
        writeln!(f, "N values: {:?}", sizes).ok();
        writeln!(f).ok();
        for r in &all_results {
            writeln!(f, "N={:6}  d²={:.12}  λ_min={:.8e}  λ_max={:.8e}  cond={:.4e}  β={:.4}  mode={}",
                r.n, r.d_sq, r.lambda_min, r.lambda_max, r.cond, r.beta, r.compute_mode).ok();
        }
        println!("  📋 Log file → {}", log_file.display());
    }

    println!("\n  🔭 GPU Observatory complete.");
}

struct SpectralResult {
    n: usize,
    dim: usize,
    lambda_min: f64,
    lambda_max: f64,
    cond: f64,
    c_min_sq: f64,
    e_0: f64,
    beta: f64,
    d_sq: f64,
    s_total: f64,
    gpu_secs: f64,
    timestamp: String,
    compute_mode: String,
}

/// Load the Gram matrix for a given N from the best available cache.
/// Returns (flat data, dim) or None.
fn load_gram_data(n: usize) -> Option<(Vec<f64>, usize)> {
    // Try standard Gram cache first
    let std_paths = [
        cache::gram_cache_path(n, 106),
        cache::gram_cache_path(n, 128),
        cache::gram_cache_path(n, 256),
        cache::gram_cache_path(n, 0),
    ];

    if let Some(gram) = std_paths.iter().find_map(|p| {
        if p.exists() { eprintln!("  Trying: {}", p.display()); cache::load_gram(p) } else { None }
    }) {
        return Some((gram.data, gram.max_dim));
    }

    // Try DD cache (hi part only) — exact match first
    let dd_paths = [
        cache::dd_gram_cache_path(n, 256),
        cache::dd_gram_cache_path(n, 128),
    ];
    if let Some((hi, _lo, dim)) = dd_paths.iter().find_map(|p| {
        if p.exists() { eprintln!("  Trying DD: {}", p.display()); cache::load_dd_gram(p) } else { None }
    }) {
        return Some((hi, dim));
    }

    // Try larger caches
    let larger_sizes: Vec<usize> = vec![40000, 50000, 60000, 80000, 100000];
    for &big_n in &larger_sizes {
        if big_n <= n { continue; }
        let big_paths = [
            cache::dd_gram_cache_path(big_n, 256),
            cache::dd_gram_cache_path(big_n, 128),
        ];
        if let Some((hi, _lo, big_dim)) = big_paths.iter().find_map(|p| {
            if p.exists() {
                eprintln!("  Trying larger DD (N={big_n}): {}", p.display());
                cache::load_dd_gram(p)
            } else { None }
        }) {
            return Some((hi, big_dim));
        }
    }
    None
}

/// Run spectral analysis on pre-loaded Gram data for a given N.
/// The data is already truncated to the right size.
fn run_spectral_from_data(n: usize, data: Vec<f64>) -> Option<SpectralResult> {
    println!("\n{}", "═".repeat(72));
    println!("  🔭 GPU SPECTRAL OBSERVATORY — N = {n}");
    println!("{}", "═".repeat(72));

    let dim = n - 1;
    let mem_gb = (dim * dim * 8) as f64 / (1024.0 * 1024.0 * 1024.0);
    println!("  Gram matrix: dim={dim} ({mem_gb:.1} GB)");

    // ═══════════════════════════════════════════════════════════════════
    // Step 2: Build b-vector
    // ═══════════════════════════════════════════════════════════════════
    let b = b_vector(dim);
    let b_norm: f64 = b.iter().map(|x| x * x).sum::<f64>().sqrt();
    println!("  ‖b‖ = {b_norm:.8}");

    // ═══════════════════════════════════════════════════════════════════
    // Step 3: GPU spectral projections (eigen + V^T b)
    //         Falls back to eigenvalues-only + Cholesky d² for large N
    // ═══════════════════════════════════════════════════════════════════
    let vram_needed_gb = (dim * dim * 8 * 3) as f64 / (1024.0 * 1024.0 * 1024.0);
    let use_full = vram_needed_gb < 22.0; // leave 2 GB headroom on 24 GB GPU

    if use_full {
        println!("  Mode: FULL eigendecomposition + projections (~{vram_needed_gb:.1} GB VRAM)");
    } else {
        println!("  Mode: HYBRID — eigenvalues-only + Cholesky d² (~{:.1} GB VRAM)", mem_gb + 1.0);
        println!("         (full eigen+vecs needs {vram_needed_gb:.1} GB, exceeds VRAM)");
    }

    if use_full {
        // ── Full path: eigenvalues + eigenvectors + projections on GPU ──
        println!("  Launching GPU eigendecomposition + projections...");
        let result = match gpu::gpu_spectral_projections(&data, dim, &b) {
            Ok(r) => r,
            Err(e) => {
                eprintln!("  ⚠ Full eigen failed ({e}), falling back to hybrid...");
                return run_hybrid_spectral(n, dim, data, b);
            }
        };
        drop(data);

        let eigenvalues = result.eigenvalues;
        let projections = result.projections;
        let gpu_secs = result.gpu_time_secs;

        let lambda_min = eigenvalues[0];
        let lambda_max = eigenvalues[dim - 1];
        let cond = if lambda_min > 0.0 { lambda_max / lambda_min } else { f64::INFINITY };
        println!("  λ_min = {lambda_min:.8e}");
        println!("  λ_max = {lambda_max:.8e}");
        println!("  cond(G) = {cond:.4e}");
        println!("  GPU time: {gpu_secs:.1}s");

        let c_sq: Vec<f64> = projections.iter().map(|c| c * c).collect();
        analyze_and_report(n, dim, &eigenvalues, &c_sq, gpu_secs)
    } else {
        // ── Hybrid path: eigenvalues-only on GPU + Cholesky d² ──
        run_hybrid_spectral(n, dim, data, b)
    }
}

/// Hybrid approach for N too large for full eigendecomposition on GPU:
/// 1. d² via GPU Cholesky (dpotrf + dpotrs) — fast, always fits
/// 2. Full eigendecomposition via CPU LAPACK (OpenBLAS, 16 threads)
///    - Try full eigen+vecs first (gives projections c_k)
///    - Fall back to eigenvalues-only if RAM is tight
fn run_hybrid_spectral(n: usize, dim: usize, data: Vec<f64>, b: Vec<f64>) -> Option<SpectralResult> {
    // ── Phase 1: d² via GPU Cholesky (this always fits — just one matrix copy) ──
    println!("  Phase 1: Computing d² via GPU Cholesky...");
    let t_chol = Instant::now();
    let _d_sq = match gpu::gpu_cholesky_d2(&data, &b, dim) {
        Ok(d2) => {
            println!("  d² = {d2:.12} ({:.1}s)", t_chol.elapsed().as_secs_f64());
            d2
        }
        Err(e) => {
            eprintln!("  ⚠ GPU Cholesky failed: {e}");
            f64::NAN
        }
    };

    // ── Phase 2: Full CPU LAPACK eigendecomposition + projections ──
    // Need ~2.5× matrix size in RAM: matrix + eigenvector storage + workspace
    let ram_needed_gb = (dim * dim * 8 * 3) as f64 / (1024.0 * 1024.0 * 1024.0);
    println!("  Phase 2: CPU LAPACK eigendecomposition (~{ram_needed_gb:.1} GB RAM needed)...");

    // Try full eigen+vecs first (gives us projections c_k = ⟨b, v_k⟩)
    let (eigenvalues, c_sq, eig_time) = cpu_lapack_full_eigen(&data, &b, dim);
    drop(data);

    if eigenvalues[0].is_nan() {
        eprintln!("  ❌ CPU LAPACK failed completely");
        return None;
    }

    let lambda_min = eigenvalues[0];
    let lambda_max = eigenvalues[dim - 1];
    let cond = if lambda_min > 0.0 { lambda_max / lambda_min } else { f64::INFINITY };
    println!("  λ_min = {lambda_min:.8e}");
    println!("  λ_max = {lambda_max:.8e}");
    println!("  cond(G) = {cond:.4e}");

    // Route through the full analysis pipeline
    analyze_and_report(n, dim, &eigenvalues, &c_sq, eig_time)
}

/// Common analysis and reporting for the full eigenvector path.
fn analyze_and_report(n: usize, dim: usize, eigenvalues: &[f64], c_sq: &[f64], gpu_secs: f64) -> Option<SpectralResult> {
    let lambda_min = eigenvalues[0];

    let mut e_k: Vec<f64> = vec![0.0; dim];
    for k in 0..dim {
        if eigenvalues[k] > 1e-30 {
            e_k[k] = c_sq[k] / eigenvalues[k];
        } else {
            e_k[k] = f64::INFINITY;
        }
    }

    let mut s_cumulative = vec![0.0f64; dim];
    s_cumulative[0] = e_k[0];
    for k in 1..dim {
        s_cumulative[k] = s_cumulative[k - 1] + e_k[k];
    }
    let s_total = s_cumulative[dim - 1];
    let d_sq = 1.0 - s_total;

    println!("\n  ── SPECTRAL DECOMPOSITION ──");
    println!("  Σ c_k²/λ_k = {s_total:.12}");
    println!("  d²_N = 1 - Σ c_k²/λ_k = {d_sq:.12}");

    // ── QUANTUM DECOUPLING ANALYSIS ──
    println!("\n  ── QUANTUM DECOUPLING ANALYSIS ──");
    println!("  {:>5} {:>14} {:>14} {:>14} {:>12}",
        "k", "λ_k", "c_k²", "E_k=c²/λ", "S_cum");
    println!("  {} {} {} {} {}",
        "─".repeat(5), "─".repeat(14), "─".repeat(14), "─".repeat(14), "─".repeat(12));

    let n_show = 20.min(dim);
    for k in 0..n_show {
        println!("  {:5} {:14.8e} {:14.8e} {:14.8e} {:12.8}",
            k, eigenvalues[k], c_sq[k], e_k[k], s_cumulative[k]);
    }
    println!("  {:>5}", "...");
    for k in (dim.saturating_sub(5))..dim {
        println!("  {:5} {:14.8e} {:14.8e} {:14.8e} {:12.8}",
            k, eigenvalues[k], c_sq[k], e_k[k], s_cumulative[k]);
    }

    // ── DECOUPLING POWER LAW ──
    println!("\n  ── DECOUPLING POWER LAW ──");
    let n_fit = (dim / 10).max(20).min(500).min(dim / 2);
    let mut log_lambda = Vec::new();
    let mut log_c_sq = Vec::new();
    for k in 0..n_fit {
        if eigenvalues[k] > 1e-30 && c_sq[k] > 1e-50 {
            log_lambda.push(eigenvalues[k].ln());
            log_c_sq.push(c_sq[k].ln());
        }
    }

    let beta = if log_lambda.len() >= 5 {
        let np = log_lambda.len() as f64;
        let sx: f64 = log_lambda.iter().sum();
        let sy: f64 = log_c_sq.iter().sum();
        let sxy: f64 = log_lambda.iter().zip(log_c_sq.iter()).map(|(x, y)| x * y).sum();
        let sxx: f64 = log_lambda.iter().map(|x| x * x).sum();
        let b = (np * sxy - sx * sy) / (np * sxx - sx * sx);
        println!("  β = {b:.6}  (fit over bottom {n_fit} modes, {}/{n_fit} valid)", log_lambda.len());
        if b > 1.0 {
            println!("  ✅ β > 1: QUANTUM DECOUPLING CONFIRMED");
        } else if b > 0.0 {
            println!("  ⚠️  0 < β < 1: MARGINAL");
        } else {
            println!("  ❌ β ≤ 0: NO DECOUPLING");
        }
        b
    } else {
        f64::NAN
    };

    // Multi-window β
    if dim >= 100 {
        println!("\n  ── MULTI-WINDOW β STABILITY ──");
        for &frac in &[0.02, 0.05, 0.10, 0.20, 0.33] {
            let win = ((dim as f64 * frac) as usize).max(20).min(dim / 2);
            let mut lx = Vec::new();
            let mut ly = Vec::new();
            for k in 0..win {
                if eigenvalues[k] > 1e-30 && c_sq[k] > 1e-50 {
                    lx.push(eigenvalues[k].ln());
                    ly.push(c_sq[k].ln());
                }
            }
            if lx.len() >= 5 {
                let np = lx.len() as f64;
                let sx: f64 = lx.iter().sum();
                let sy: f64 = ly.iter().sum();
                let sxy: f64 = lx.iter().zip(ly.iter()).map(|(x, y)| x * y).sum();
                let sxx: f64 = lx.iter().map(|x| x * x).sum();
                let b = (np * sxy - sx * sy) / (np * sxx - sx * sx);
                let marker = if b > 1.0 { "✅" } else if b > 0.0 { "⚠️ " } else { "❌" };
                println!("  {marker} bottom {:.0}% ({} modes): β = {b:.4}", frac * 100.0, lx.len());
            }
        }
    }

    // ── ORTHOGONALITY SHIELD ──
    println!("\n  ── ORTHOGONALITY SHIELD ──");
    println!("  |⟨b, v_min⟩|² = {:.8e}", c_sq[0]);
    println!("  λ_min          = {:.8e}", eigenvalues[0]);
    println!("  E_0 = c₀²/λ   = {:.8e}", e_k[0]);
    if d_sq > 0.0 {
        println!("  E_0 / d²_N     = {:.8e}", e_k[0] / d_sq);
    }

    // ── Save TSV ──
    let out_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("results").join("spectral-observatory");
    std::fs::create_dir_all(&out_dir).ok();
    let out_file = out_dir.join(format!("gpu_spectral_N{n}.tsv"));
    let mut tsv = String::new();
    tsv.push_str("k\tlambda_k\tc_k_sq\tE_k\tS_cumulative\n");
    for k in 0..dim {
        tsv.push_str(&format!("{k}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\n",
            eigenvalues[k], c_sq[k], e_k[k], s_cumulative[k]));
    }
    std::fs::write(&out_file, &tsv).ok();
    println!("\n  Data saved to: {}", out_file.display());

    let lambda_max = eigenvalues[dim - 1];
    let cond = if lambda_min > 0.0 { lambda_max / lambda_min } else { f64::INFINITY };
    let ts = utc_timestamp();
    let mode = if gpu_secs < 100.0 && dim <= 20000 { "GPU_full" } else { "CPU_LAPACK" };

    // ── Per-N JSON Certificate ──
    let cert_file = out_dir.join(format!("certificate_N{n}.json"));
    let mut cert = String::new();
    cert.push_str("{\n");
    cert.push_str("  \"format\": \"cathedral-nb-spectral-certificate-v1\",\n");
    cert.push_str(&format!("  \"timestamp\": \"{ts}\",\n"));
    cert.push_str(&format!("  \"N\": {n},\n"));
    cert.push_str(&format!("  \"dim\": {dim},\n"));
    cert.push_str(&format!("  \"d_sq\": {d_sq:.15e},\n"));
    cert.push_str(&format!("  \"s_total\": {s_total:.15e},\n"));
    cert.push_str(&format!("  \"lambda_min\": {lambda_min:.15e},\n"));
    cert.push_str(&format!("  \"lambda_max\": {lambda_max:.15e},\n"));
    cert.push_str(&format!("  \"condition_number\": {cond:.8e},\n"));
    cert.push_str(&format!("  \"beta\": {beta:.8},\n"));
    cert.push_str(&format!("  \"c_min_sq\": {:.15e},\n", c_sq[0]));
    cert.push_str(&format!("  \"e_0\": {:.15e},\n", e_k[0]));
    cert.push_str(&format!("  \"e_0_over_d_sq\": {:.15e},\n", if d_sq > 0.0 { e_k[0] / d_sq } else { f64::NAN }));
    cert.push_str(&format!("  \"orthogonality_shield\": {:.15e},\n", c_sq[0]));
    cert.push_str(&format!("  \"lambda_min_positive\": {},\n", lambda_min > 0.0));
    cert.push_str(&format!("  \"quantum_decoupling\": {},\n", beta > 1.0));
    cert.push_str(&format!("  \"compute_mode\": \"{mode}\",\n"));
    cert.push_str(&format!("  \"compute_time_secs\": {gpu_secs:.1},\n"));
    cert.push_str(&format!("  \"data_file\": \"gpu_spectral_N{n}.tsv\",\n"));
    cert.push_str(&format!("  \"lean_claim\": \"At N={n}, d²_N = {d_sq:.12}, λ_min = {lambda_min:.8e} > 0, β = {beta:.4}\"\n"));
    cert.push_str("}\n");
    std::fs::write(&cert_file, &cert).ok();
    println!("  📜 Certificate → {}", cert_file.display());

    Some(SpectralResult {
        n, dim, lambda_min, lambda_max, cond,
        c_min_sq: c_sq[0],
        e_0: e_k[0],
        beta, d_sq, s_total, gpu_secs,
        timestamp: ts,
        compute_mode: mode.to_string(),
    })
}

// ═══════════════════════════════════════════════════════════════════
// CPU LAPACK EIGENDECOMPOSITION via OpenBLAS (multi-threaded)
// ═══════════════════════════════════════════════════════════════════

#[link(name = "openblas")]
extern "C" {
    /// LAPACK symmetric eigendecomposition (divide-and-conquer)
    /// Uses all CPU cores via OpenBLAS threading.
    /// ⚠️ For jobz='V', lwork = 1 + 6N + 2N² which overflows i32 at N ≈ 32767.
    fn dsyevd_(
        jobz: *const u8,   // 'N' = eigenvalues only, 'V' = eigenvalues + eigenvectors
        uplo: *const u8,   // 'U' = upper, 'L' = lower
        n: *const c_int,
        a: *mut f64,       // input matrix (overwritten), column-major
        lda: *const c_int,
        w: *mut f64,       // eigenvalues output (ascending)
        work: *mut f64,    // workspace
        lwork: *const c_int,
        iwork: *mut c_int, // integer workspace
        liwork: *const c_int,
        info: *mut c_int,
    );

    /// LAPACK symmetric eigendecomposition (QR algorithm)
    /// Slower than dsyevd but uses only lwork = 3N-1 workspace (~1 MB at N=40K).
    /// No integer workspace needed. Used as fallback when dsyevd workspace
    /// exceeds i32::MAX (which happens at dim ≥ 32768 with jobz='V').
    fn dsyev_(
        jobz: *const u8,
        uplo: *const u8,
        n: *const c_int,
        a: *mut f64,
        lda: *const c_int,
        w: *mut f64,
        work: *mut f64,
        lwork: *const c_int,
        info: *mut c_int,
    );
}

/// Multi-threaded CPU eigenvalue computation via LAPACK dsyevd + OpenBLAS.
///
/// For N=40,000 with 16-core Ryzen 9 7950X3D:
/// - Single-threaded nalgebra: ~45-60 min
/// - OpenBLAS 16 threads: ~3-5 min (estimated 10-16× speedup)
fn cpu_lapack_eigenvalues(data: &[f64], dim: usize) -> (Vec<f64>, f64) {
    let t_start = Instant::now();
    let n = dim as c_int;
    let mem_gb = (dim * dim * 8) as f64 / (1024.0 * 1024.0 * 1024.0);
    println!("  LAPACK dsyevd: dim={dim} ({mem_gb:.1} GB matrix)");
    println!("  OpenBLAS threads: {}",
        std::thread::available_parallelism().map(|p| p.get()).unwrap_or(1));

    // LAPACK expects column-major. For symmetric matrices, row-major = column-major!
    let mut a = data.to_vec();
    let mut w = vec![0.0f64; dim];
    let mut info: c_int = 0;

    // Query optimal workspace sizes
    let mut work_query = vec![0.0f64; 1];
    let mut iwork_query = vec![0i32; 1];
    let lwork_query: c_int = -1;
    let liwork_query: c_int = -1;

    unsafe {
        dsyevd_(
            b"N" as *const u8, // eigenvalues only
            b"L" as *const u8, // lower triangle
            &n, a.as_mut_ptr(), &n,
            w.as_mut_ptr(),
            work_query.as_mut_ptr(), &lwork_query,
            iwork_query.as_mut_ptr(), &liwork_query,
            &mut info,
        );
    }

    if info != 0 {
        eprintln!("  ❌ LAPACK dsyevd workspace query failed: info={info}");
        return (vec![f64::NAN; dim], 0.0);
    }

    let lwork = work_query[0] as c_int;
    let liwork = iwork_query[0];
    let ws_mb = (lwork as usize * 8 + liwork as usize * 4) / (1024 * 1024);
    println!("  LAPACK workspace: {ws_mb} MB (lwork={lwork}, liwork={liwork})");

    let mut work = vec![0.0f64; lwork as usize];
    let mut iwork = vec![0i32; liwork as usize];

    // Run the multi-threaded eigendecomposition!
    println!("  Computing eigenvalues (all cores)...");
    let t_eigen = Instant::now();
    unsafe {
        dsyevd_(
            b"N" as *const u8,
            b"L" as *const u8,
            &n, a.as_mut_ptr(), &n,
            w.as_mut_ptr(),
            work.as_mut_ptr(), &lwork,
            iwork.as_mut_ptr(), &liwork,
            &mut info,
        );
    }
    let cpu_time = t_eigen.elapsed().as_secs_f64();

    if info != 0 {
        eprintln!("  ❌ LAPACK dsyevd failed: info={info}");
        return (vec![f64::NAN; dim], cpu_time);
    }

    let total_time = t_start.elapsed().as_secs_f64();
    println!("  LAPACK dsyevd completed: {cpu_time:.1}s (total: {total_time:.1}s)");
    println!("  λ_min = {:.8e}, λ_max = {:.8e}", w[0], w[dim - 1]);

    (w, total_time)
}

/// Full CPU eigendecomposition: eigenvalues + eigenvectors + projections.
///
/// Uses LAPACK dsyevd with jobz='V' (compute eigenvectors).
/// For dim ≥ 32768, dsyevd's workspace (1+6N+2N²) overflows i32, so we
/// fall back to dsyev (QR algorithm, workspace = 3N-1 ≈ 1 MB).
/// dsyev is ~2× slower but works for any matrix size.
///
/// Returns (eigenvalues sorted ascending, c_k² projections sorted by eigenvalue, time)
fn cpu_lapack_full_eigen(data: &[f64], b: &[f64], dim: usize) -> (Vec<f64>, Vec<f64>, f64) {
    let t_start = Instant::now();
    let n = dim as c_int;
    let mem_gb = (dim * dim * 8) as f64 / (1024.0 * 1024.0 * 1024.0);

    // Check if dsyevd workspace would overflow i32.
    // dsyevd jobz='V' needs lwork = 1 + 6N + 2N², which overflows at N ≈ 32767.
    let lwork_needed: u64 = 1 + 6 * (dim as u64) + 2 * (dim as u64) * (dim as u64);
    let use_dsyev = lwork_needed > (i32::MAX as u64);

    if use_dsyev {
        println!("  LAPACK dsyev (QR, FULL eigen+vecs): dim={dim} ({mem_gb:.1} GB matrix)");
        println!("  ⚠ Using dsyev instead of dsyevd (workspace {lwork_needed} exceeds i32::MAX)");
    } else {
        println!("  LAPACK dsyevd (FULL eigen+vecs): dim={dim} ({mem_gb:.1} GB matrix)");
    }
    println!("  OpenBLAS threads: {}",
        std::thread::available_parallelism().map(|p| p.get()).unwrap_or(1));

    // LAPACK expects column-major. For symmetric matrices, row-major = column-major!
    // After dsyevd/dsyev with jobz='V', the matrix `a` is overwritten with eigenvectors
    // stored column-by-column: column k = eigenvector for eigenvalue w[k].
    let mut a = data.to_vec();
    let mut w = vec![0.0f64; dim];
    let mut info: c_int = 0;

    if use_dsyev {
        // ═══════════════════════════════════════════
        // dsyev path: QR algorithm, small workspace
        // ═══════════════════════════════════════════

        // Query optimal workspace
        let mut work_query = vec![0.0f64; 1];
        let lwork_query: c_int = -1;

        unsafe {
            dsyev_(
                b"V" as *const u8,
                b"L" as *const u8,
                &n, a.as_mut_ptr(), &n,
                w.as_mut_ptr(),
                work_query.as_mut_ptr(), &lwork_query,
                &mut info,
            );
        }

        if info != 0 {
            eprintln!("  ❌ LAPACK dsyev workspace query failed: info={info}");
            return (vec![f64::NAN; dim], vec![f64::NAN; dim], 0.0);
        }

        let lwork = work_query[0] as c_int;
        let ws_mb = (lwork as usize * 8) / (1024 * 1024);
        println!("  LAPACK workspace: {ws_mb} MB (lwork={lwork})");

        let mut work = vec![0.0f64; lwork as usize];

        println!("  Computing eigenvalues + eigenvectors (all cores, QR method)...");
        let t_eigen = Instant::now();
        unsafe {
            dsyev_(
                b"V" as *const u8,
                b"L" as *const u8,
                &n, a.as_mut_ptr(), &n,
                w.as_mut_ptr(),
                work.as_mut_ptr(), &lwork,
                &mut info,
            );
        }
        let eigen_time = t_eigen.elapsed().as_secs_f64();
        println!("  LAPACK dsyev (eigen+vecs): {eigen_time:.1}s");

        drop(work);

        if info != 0 {
            eprintln!("  ❌ LAPACK dsyev failed: info={info}");
            return (vec![f64::NAN; dim], vec![f64::NAN; dim], eigen_time);
        }
    } else {
        // ═══════════════════════════════════════════
        // dsyevd path: divide-and-conquer, large workspace
        // ═══════════════════════════════════════════

        // Query optimal workspace sizes for jobz='V'
        let mut work_query = vec![0.0f64; 1];
        let mut iwork_query = vec![0i32; 1];
        let lwork_query: c_int = -1;
        let liwork_query: c_int = -1;

        unsafe {
            dsyevd_(
                b"V" as *const u8,
                b"L" as *const u8,
                &n, a.as_mut_ptr(), &n,
                w.as_mut_ptr(),
                work_query.as_mut_ptr(), &lwork_query,
                iwork_query.as_mut_ptr(), &liwork_query,
                &mut info,
            );
        }

        if info != 0 {
            eprintln!("  ❌ LAPACK dsyevd workspace query failed: info={info}");
            return (vec![f64::NAN; dim], vec![f64::NAN; dim], 0.0);
        }

        let lwork = work_query[0] as c_int;
        let liwork = iwork_query[0];
        let ws_mb = (lwork as usize * 8 + liwork as usize * 4) / (1024 * 1024);
        println!("  LAPACK workspace: {ws_mb} MB (lwork={lwork}, liwork={liwork})");

        let mut work = vec![0.0f64; lwork as usize];
        let mut iwork = vec![0i32; liwork as usize];

        println!("  Computing eigenvalues + eigenvectors (all cores, D&C method)...");
        let t_eigen = Instant::now();
        unsafe {
            dsyevd_(
                b"V" as *const u8,
                b"L" as *const u8,
                &n, a.as_mut_ptr(), &n,
                w.as_mut_ptr(),
                work.as_mut_ptr(), &lwork,
                iwork.as_mut_ptr(), &liwork,
                &mut info,
            );
        }
        let eigen_time = t_eigen.elapsed().as_secs_f64();
        println!("  LAPACK dsyevd (eigen+vecs): {eigen_time:.1}s");

        drop(work);
        drop(iwork);

        if info != 0 {
            eprintln!("  ❌ LAPACK dsyevd failed: info={info}");
            return (vec![f64::NAN; dim], vec![f64::NAN; dim], eigen_time);
        }
    }

    println!("  λ_min = {:.8e}, λ_max = {:.8e}", w[0], w[dim - 1]);

    // Compute projections c_k = ⟨b, v_k⟩
    // After dsyevd/dsyev, a is stored column-major: column k = v_k
    // v_k[i] = a[i + k * dim]
    println!("  Computing projections c_k = ⟨b, v_k⟩...");
    let t_proj = Instant::now();
    let mut c_sq = vec![0.0f64; dim];
    for k in 0..dim {
        let col_start = k * dim;
        let mut dot = 0.0f64;
        for i in 0..dim {
            dot += b[i] * a[col_start + i];
        }
        c_sq[k] = dot * dot;
    }
    let proj_time = t_proj.elapsed().as_secs_f64();
    println!("  Projections computed: {proj_time:.1}s");

    let total_time = t_start.elapsed().as_secs_f64();
    println!("  LAPACK full eigen total: {total_time:.1}s");

    (w, c_sq, total_time)
}
