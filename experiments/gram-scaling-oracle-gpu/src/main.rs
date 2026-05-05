//! ═══════════════════════════════════════════════════════════════════════════
//!  CATHEDRAL GRAM SCALING ORACLE — GPU ACCELERATED
//!
//!  Target: RTX 4090 (24 GB) + Ryzen 9 7950X3D (16 cores, 64 GB RAM)
//!
//!  Tiered execution:
//!    GPU cuSOLVER dsyevd (NoVec) — matrices that fit in VRAM
//!    CPU OpenBLAS dsyevr          — λ_min-only fallback for larger N
//!
//!  Cross-N sweep: compute λ_min(G_N) at multiple N, fit α scaling
//! ═══════════════════════════════════════════════════════════════════════════

mod cpu;
mod gcd_decomp;
mod gpu;

use cathedral_utils::cache;
use cathedral_utils::gram::GramMatrix;
use std::io::Write;
use std::time::Instant;

const BOLD: &str = "\x1b[1m";
const DIM: &str = "\x1b[2m";
const CYAN: &str = "\x1b[36m";
const GREEN: &str = "\x1b[32m";
const YELLOW: &str = "\x1b[33m";
const MAGENTA: &str = "\x1b[35m";
const WHITE: &str = "\x1b[97m";
const RESET: &str = "\x1b[0m";

/// Cross-N sweep schedule (ascending).
const CROSS_N_SCHEDULE: &[usize] = &[
    100, 200, 500, 1000, 2000, 5000, 10000, 20000, 40000,
    60000, 80000, 100000, 120000,
];

/// Try to load a cached Gram matrix. Returns (data, dim).
fn load_cached_gram(max_n: usize) -> Option<(Vec<f64>, usize)> {
    let dd_path = cache::dd_gram_cache_path(max_n, 256);
    if dd_path.exists() {
        if let Some((hi, _lo, dim)) = cache::load_dd_gram(&dd_path) {
            return Some((hi, dim));
        }
    }
    for prec in [256u32, 512, 128, 106, 0] {
        let path = cache::gram_cache_path(max_n, prec);
        if path.exists() {
            if let Some(gm) = cache::load_gram(&path) {
                return Some((gm.data, gm.max_dim));
            }
        }
    }
    None
}

/// Build a Gram matrix from scratch.
fn build_gram(max_n: usize) -> (Vec<f64>, usize) {
    let gm = GramMatrix::build(max_n, None);
    (gm.data, gm.max_dim)
}

/// Load or build a Gram matrix.
fn get_gram(max_n: usize) -> (Vec<f64>, usize) {
    if let Some(cached) = load_cached_gram(max_n) {
        cached
    } else {
        build_gram(max_n)
    }
}

/// Compute λ_min using the best available method (GPU → CPU fallback).
fn compute_lambda_min(data: &[f64], dim: usize, vram_mb: usize) -> (f64, f64, &'static str) {
    // Try GPU first if matrix fits
    if gpu::can_fit_novec(dim, vram_mb) {
        match gpu::gpu_lambda_min(data, dim) {
            Ok((lmin, time)) => return (lmin, time, "GPU_cuSOLVER"),
            Err(e) => eprintln!("    ⚠ GPU failed ({e}), falling back to CPU"),
        }
    }

    // CPU fallback: dsyevr for λ_min only (fast, 16 cores)
    let (lmin, time) = cpu::full_matrix_lambda_min(data, dim);
    (lmin, time, "CPU_OpenBLAS")
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let max_n: usize = args.get(1).and_then(|s| s.parse().ok()).unwrap_or(5000);

    println!();
    println!("  {BOLD}{CYAN}╔═══════════════════════════════════════════════════════════════════════╗{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}{WHITE}CATHEDRAL GRAM SCALING ORACLE — GPU ACCELERATED{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  cuSOLVER dsyevd + OpenBLAS dsyevr · Cross-N Scaling");
    println!("  {BOLD}{CYAN}║{RESET}  N = {max_n}");
    println!("  {BOLD}{CYAN}╚═══════════════════════════════════════════════════════════════════════╝{RESET}");
    println!();

    // Detect GPU
    let gpu_info = gpu::detect_gpu();
    let vram_mb = match &gpu_info {
        Some(info) => {
            println!("  {GREEN}✓{RESET} GPU: {} ({} MB VRAM)", info.name.trim(), info.vram_mb);
            info.vram_mb
        }
        None => {
            println!("  {YELLOW}⚠{RESET} No GPU detected — CPU-only mode");
            0
        }
    };
    println!();

    let t_total = Instant::now();

    // ═══════════════════════════════════════════════════════════════
    // §1. CROSS-N SWEEP — TRUE GLOBAL α
    // ═══════════════════════════════════════════════════════════════
    println!("  {BOLD}{MAGENTA}§1{RESET}  {BOLD}Cross-N Sweep — True Global λ_min(G_N) ...{RESET}");

    let sweep_ns: Vec<usize> = CROSS_N_SCHEDULE.iter()
        .filter(|&&n| n <= max_n)
        .cloned()
        .collect();

    let mut cross_n_data: Vec<(usize, f64, f64, &str)> = Vec::new();
    println!("  {DIM}     Schedule: {:?}{RESET}", sweep_ns);
    println!();

    for &n in &sweep_ns {
        let t0 = Instant::now();
        eprint!("  {DIM}     N={n:<6} → loading...{RESET}");

        let (data, dim) = get_gram(n);
        let load_time = t0.elapsed().as_secs_f64();
        let mem_gb = (data.len() * 8) as f64 / (1024.0 * 1024.0 * 1024.0);

        eprint!("\r  {DIM}     N={n:<6} ({dim}×{dim}, {mem_gb:.2} GB, {load_time:.1}s load) → computing λ_min...{RESET}          ");

        let (lmin, eigen_time, mode) = compute_lambda_min(&data, dim, vram_mb);

        eprintln!("\r  {GREEN}✓{RESET} N={n:<6} dim={dim:<6} λ_min = {lmin:<20.12e}  ({load_time:.1}s load + {eigen_time:.1}s {mode})          ");

        cross_n_data.push((n, lmin, eigen_time, mode));
        drop(data);
    }
    println!();

    // Fit the cross-N scaling
    println!("  {BOLD}  Cross-N Scaling Fit:{RESET}");
    let cross_ns: Vec<f64> = cross_n_data.iter().map(|&(n, _, _, _)| n as f64).collect();
    let cross_lmins: Vec<f64> = cross_n_data.iter().map(|&(_, lm, _, _)| lm).collect();

    let (_, alpha_power, r2_power) = if cross_ns.len() >= 3 {
        cathedral_utils::fitting::power_law_fit(&cross_ns, &cross_lmins)
    } else { (0.0, 0.0, 0.0) };

    let (_, alpha_log, r2_log) = if cross_ns.len() >= 3 {
        cathedral_utils::fitting::log_decay_fit(&cross_ns, &cross_lmins)
    } else { (0.0, 0.0, 0.0) };

    println!("    Power law:  λ_min(G_N) ~ c · N^(-{alpha_power:.4})   R² = {r2_power:.6}");
    println!("    Log decay:  λ_min(G_N) ~ c / (ln N)^{alpha_log:.4}    R² = {r2_log:.6}");
    println!("    Target α:   0.855 (Three-Circles prediction)");
    if r2_log > r2_power {
        println!("    {GREEN}→ Log-decay model fits better{RESET}");
    } else {
        println!("    {GREEN}→ Power-law model fits better{RESET}");
    }
    println!();

    // ═══════════════════════════════════════════════════════════════
    // §2. MASTER RESULTS
    // ═══════════════════════════════════════════════════════════════
    println!("  {BOLD}{CYAN}  ┌───────────────────────────────────────────────────────────────┐{RESET}");
    println!("  {BOLD}{CYAN}  │{RESET}  {BOLD}{WHITE}SCALING ORACLE GPU — MASTER RESULTS{RESET}                        {BOLD}{CYAN}│{RESET}");
    println!("  {BOLD}{CYAN}  ├───────────────────────────────────────────────────────────────┤{RESET}");
    println!("  {BOLD}{CYAN}  │{RESET}  N range:         {:<20}{:<20}{BOLD}{CYAN}│{RESET}",
             format!("{}..{}", sweep_ns.first().unwrap_or(&0), sweep_ns.last().unwrap_or(&0)), "");
    println!("  {BOLD}{CYAN}  │{RESET}  {BOLD}{YELLOW}α (power law):   {alpha_power:<12.6}{RESET}  R² = {r2_power:.6}          {BOLD}{CYAN}│{RESET}");
    println!("  {BOLD}{CYAN}  │{RESET}  {BOLD}{YELLOW}α (log decay):   {alpha_log:<12.6}{RESET}  R² = {r2_log:.6}          {BOLD}{CYAN}│{RESET}");
    println!("  {BOLD}{CYAN}  │{RESET}  TARGET:  α ≈ 0.855 (Three-Circles / Parseval Mirror)        {BOLD}{CYAN}│{RESET}");
    println!("  {BOLD}{CYAN}  └───────────────────────────────────────────────────────────────┘{RESET}");
    println!();

    // Cross-N data table
    println!("  {BOLD}  Cross-N λ_min data:{RESET}");
    println!("  {DIM}  ┌──────────┬──────────────────────┬────────────┬────────┬──────────────┐{RESET}");
    println!("  {DIM}  │    N     │      λ_min(G_N)      │   ln(N)    │  mode  │   time (s)   │{RESET}");
    println!("  {DIM}  ├──────────┼──────────────────────┼────────────┼────────┼──────────────┤{RESET}");
    for &(n, lm, time, mode) in &cross_n_data {
        let mode_short = if mode.contains("GPU") { "GPU" } else { "CPU" };
        println!("  {DIM}  │{RESET} {n:>8} {DIM}│{RESET} {lm:>20.12e} {DIM}│{RESET} {:<10.4} {DIM}│{RESET} {mode_short:<6} {DIM}│{RESET} {time:>12.1} {DIM}│{RESET}",
                 (n as f64).ln());
    }
    println!("  {DIM}  └──────────┴──────────────────────┴────────────┴────────┴──────────────┘{RESET}");
    println!();

    // ═══════════════════════════════════════════════════════════════
    // §3. CERTIFIED OUTPUT
    // ═══════════════════════════════════════════════════════════════
    println!("  {BOLD}{MAGENTA}§3{RESET}  {BOLD}Writing Certified Results ...{RESET}");
    write_certificate(max_n, &cross_n_data, alpha_power, r2_power, alpha_log, r2_log, &gpu_info);

    let elapsed = t_total.elapsed().as_secs_f64();
    println!();
    println!("  {BOLD}{GREEN}  ══════════════════════════════════════════════════════════════{RESET}");
    println!("  {BOLD}{GREEN}  ORACLE COMPLETE{RESET}  ·  N = {max_n}  ·  {elapsed:.1}s total");
    println!("  {BOLD}{GREEN}  ══════════════════════════════════════════════════════════════{RESET}");
    println!();
}

fn write_certificate(
    max_n: usize,
    cross_n_data: &[(usize, f64, f64, &str)],
    alpha_power: f64, r2_power: f64,
    alpha_log: f64, r2_log: f64,
    gpu_info: &Option<gpu::GpuInfo>,
) {
    std::fs::create_dir_all("results").ok();

    // TSV
    let tsv_path = format!("results/cross_n_scaling_N{max_n}.tsv");
    if let Ok(mut f) = std::fs::File::create(&tsv_path) {
        writeln!(f, "N\tdim\tlambda_min\tln_N\tln_lambda_min\tmode\ttime_s").ok();
        for &(n, lm, time, mode) in cross_n_data {
            writeln!(f, "{}\t{}\t{:.15e}\t{:.10}\t{:.10}\t{}\t{:.1}",
                     n, n - 1, lm, (n as f64).ln(), lm.ln(), mode, time).ok();
        }
    }

    // JSON certificate
    let json_path = format!("results/cross_n_certificate_N{max_n}.json");
    if let Ok(mut f) = std::fs::File::create(&json_path) {
        let gpu_name = gpu_info.as_ref().map(|i| i.name.trim().to_string()).unwrap_or("none".into());
        let vram = gpu_info.as_ref().map(|i| i.vram_mb).unwrap_or(0);

        writeln!(f, "{{").ok();
        writeln!(f, "  \"format\": \"cathedral-gram-scaling-oracle-gpu-v1\",").ok();
        writeln!(f, "  \"max_N\": {max_n},").ok();
        writeln!(f, "  \"gpu\": \"{gpu_name}\",").ok();
        writeln!(f, "  \"gpu_vram_mb\": {vram},").ok();
        writeln!(f, "  \"scaling\": {{").ok();
        writeln!(f, "    \"alpha_power_law\": {alpha_power:.10},").ok();
        writeln!(f, "    \"r2_power_law\": {r2_power:.10},").ok();
        writeln!(f, "    \"alpha_log_decay\": {alpha_log:.10},").ok();
        writeln!(f, "    \"r2_log_decay\": {r2_log:.10}").ok();
        writeln!(f, "  }},").ok();
        writeln!(f, "  \"three_circles_target\": 0.855,").ok();
        writeln!(f, "  \"data_points\": [").ok();
        for (i, &(n, lm, time, mode)) in cross_n_data.iter().enumerate() {
            let comma = if i + 1 < cross_n_data.len() { "," } else { "" };
            writeln!(f, "    {{ \"N\": {n}, \"lambda_min\": {lm:.15e}, \"mode\": \"{mode}\", \"time_s\": {time:.1} }}{comma}").ok();
        }
        writeln!(f, "  ]").ok();
        writeln!(f, "}}").ok();
    }

    println!("  {GREEN}✓{RESET} Results written to results/");
    println!("    ├── {tsv_path}");
    println!("    └── {json_path}");
}
