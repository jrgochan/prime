//! ═══════════════════════════════════════════════════════════════════════════
//!  CATHEDRAL RL — Reinforcement Learning for the Gram Form Inequality
//!
//!  The Riemann Hypothesis, reduced to matrix optimization:
//!    Show that vᵀG_N v ≤ 1 + K/ln(N) for the Möbius witness vector v.
//!
//!  Three agent strategies:
//!    1. CG:     Conjugate Gradient  — find the quadratic optimum G⁻¹b
//!    2. ES:     Evolution Strategy  — gradient-free structural exploration
//!    3. HYBRID: CG warmup → ES     — best of both worlds
//!
//!  Architecture:
//!    src/
//!      main.rs       ← this file (CLI + orchestration)
//!      env.rs        ← RL environment (Gram matrix, matvec, GPU dispatch)
//!      runner.rs     ← agent runner functions (CG, GD, ES, hybrid loops)
//!      output.rs     ← result types, display, JSON serialization
//!      agent/        ← agent implementations
//!        mod.rs           ← barrel exports
//!        numerics.rs      ← Kahan compensated arithmetic
//!        gradient.rs      ← §1 gradient descent
//!        conjugate_gradient.rs ← §2 Jacobi-preconditioned CG
//!        evolution.rs     ← §3 (μ+λ) evolution strategy
//!        hybrid.rs        ← §4 CG → ES hybrid
//!
//!  Usage:
//!    cathedral-rl --n 500 --agent hybrid --episodes 100
//!    cathedral-rl --n 1000 --agent cg
//!    cathedral-rl --n 2520 --agent es --generations 500 --pop 64
//!    cathedral-rl --sweep                 # sweep over HC numbers
//! ═══════════════════════════════════════════════════════════════════════════

mod agent;
mod certificate;
mod env;
mod output;
mod precision;
mod runner;

use clap::Parser;
use env::CathedralEnv;
use output::*;
use std::time::Instant;

/// Highly composite numbers — the Cathedral's preferred subsequence
const HC_NUMBERS: &[usize] = &[
    120, 180, 240, 360, 720, 840, 1260, 1680, 2520, 5040, 7560, 10080, 15120, 20160, 25200, 27720,
    45360, 50400, 55440, 83160,
];

#[derive(Parser, Debug)]
#[command(name = "cathedral-rl")]
#[command(about = "RL-based optimization of the Cathedral Gram form inequality")]
struct Args {
    /// Matrix dimension N (Gram matrix is (N-1)×(N-1))
    #[arg(short, long, default_value_t = 500)]
    n: usize,

    /// Agent type: cg, es, gd, hybrid
    #[arg(short, long, default_value = "hybrid")]
    agent: String,

    /// Number of CG iterations (for cg/hybrid agents)
    #[arg(long, default_value_t = 5000)]
    cg_steps: usize,

    /// CG convergence tolerance (relative residual ||r||/||r₀|| threshold)
    #[arg(long, default_value_t = 1e-12)]
    cg_tol: f64,

    /// Number of ES generations (for es/hybrid agents)
    #[arg(long, default_value_t = 500)]
    generations: usize,

    /// ES population size
    #[arg(long, default_value_t = 32)]
    pop: usize,

    /// ES mutation sigma
    #[arg(long, default_value_t = 0.01)]
    sigma: f64,

    /// GD learning rate
    #[arg(long, default_value_t = 0.001)]
    lr: f64,

    /// GD momentum
    #[arg(long, default_value_t = 0.9)]
    momentum: f64,

    /// Run HC number sweep instead of single N
    #[arg(long)]
    sweep: bool,

    /// Maximum N for sweep
    #[arg(long, default_value_t = 5040)]
    sweep_max: usize,

    /// Load Gram matrix from HPDF (.h5) file
    #[arg(long)]
    hpdf: Option<String>,

    /// Load Gram matrix from binary cache (.bin) file
    #[arg(long)]
    cache: Option<String>,

    /// Enable GPU acceleration (requires --features gpu)
    #[arg(long)]
    gpu: bool,

    /// Output results to JSON file
    #[arg(short, long)]
    output: Option<String>,

    /// Precision tier for CG: f64, dd, mixed, mpfr
    #[arg(long, default_value = "f64")]
    precision: String,

    /// MPFR precision in bits (only used with --precision mpfr)
    #[arg(long, default_value_t = 256)]
    mpfr_bits: u32,
}

/// Get the results directory anchored to the cathedral-rl crate root.
/// This ensures output files always go to experiments/cathedral-rl/results/
/// regardless of the working directory.
fn results_dir() -> std::path::PathBuf {
    std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("results")
}

fn main() {
    let args = Args::parse();
    let t_global = Instant::now();

    print_banner();

    if args.sweep {
        run_sweep(&args, t_global);
    } else {
        let result = run_single(&args, args.n);
        print_single_result(&result);

        if let Some(ref path) = args.output {
            write_json(path, &result);
        }

        // Emit certificate
        let cert_dir = results_dir().join("certificates");
        std::fs::create_dir_all(&cert_dir).ok();
        let cert_path = cert_dir.join(format!("cathedral_rl_N{}.json", args.n));
        certificate::write_certificate(
            &cert_path,
            std::slice::from_ref(&result),
            t_global.elapsed(),
        )
        .ok();

        // Emit timestamped log file with full results
        write_run_log(&args, &result, t_global.elapsed());
    }
}

fn run_single(args: &Args, n: usize) -> RunResult {
    let t0 = Instant::now();

    println!("  {BOLD}{MAGENTA}§1{RESET}  {BOLD}Building Environment (N={n})...{RESET}");
    let max_steps = args.cg_steps + args.generations;

    // Load from explicit path if provided, otherwise auto-detect
    #[cfg(feature = "hpdf")]
    let mut env = if let Some(ref path) = args.hpdf {
        CathedralEnv::from_hpdf(std::path::Path::new(path), max_steps).unwrap_or_else(|e| {
            eprintln!("  {RED}✗{RESET} HPDF load failed: {e}");
            std::process::exit(1);
        })
    } else if let Some(ref path) = args.cache {
        CathedralEnv::from_cache(std::path::Path::new(path), max_steps).unwrap_or_else(|e| {
            eprintln!("  {RED}✗{RESET} Cache load failed: {e}");
            std::process::exit(1);
        })
    } else {
        CathedralEnv::new(n, max_steps)
    };

    #[cfg(not(feature = "hpdf"))]
    let mut env = if let Some(ref path) = args.cache {
        CathedralEnv::from_cache(std::path::Path::new(path), max_steps).unwrap_or_else(|e| {
            eprintln!("  {RED}✗{RESET} Cache load failed: {e}");
            std::process::exit(1);
        })
    } else {
        CathedralEnv::new(n, max_steps)
    };

    // Initialize GPU if requested
    #[cfg(feature = "gpu")]
    if args.gpu {
        match env.init_gpu() {
            Ok(()) => println!("    {GREEN}✓{RESET} GPU acceleration enabled"),
            Err(e) => {
                eprintln!("    {YELLOW}⚠{RESET} GPU init failed: {e} — using CPU");
            }
        }
    }

    let baseline_d2 = env.baseline_d2;
    let baseline_vtgv = env.compute_vtgv();
    let baseline_btv = env.compute_btv();

    println!("    Baseline (log-cutoff witness):");
    println!("      d²    = {baseline_d2:.10}");
    println!("      vᵀGv  = {baseline_vtgv:.10}");
    println!("      bᵀv   = {baseline_btv:.10}");
    println!();

    println!(
        "  {BOLD}{MAGENTA}§2{RESET}  {BOLD}Running Agent: {}...{RESET}",
        args.agent.to_uppercase()
    );

    let mut total_steps;

    match args.agent.as_str() {
        "cg" => {
            total_steps = runner::run_cg_with_tol(&mut env, args.cg_steps, args.cg_tol);
        }
        "gd" => {
            total_steps = runner::run_gd(&mut env, args.cg_steps, args.lr, args.momentum);
        }
        "es" => {
            total_steps = runner::run_es(&mut env, args.generations, args.pop, args.sigma);
        }
        "hybrid" => {
            total_steps = runner::run_hybrid(
                &mut env,
                args.cg_steps,
                args.cg_tol,
                args.generations,
                args.pop,
                args.sigma,
            );
        }
        _ => {
            eprintln!("  {RED}\u{2717}{RESET} Unknown agent: {}", args.agent);
            std::process::exit(1);
        }
    }

    // §3. Precision refinement (if requested)
    if args.precision != "f64" {
        println!();
        println!(
            "  {BOLD}{MAGENTA}§3{RESET}  {BOLD}Precision Refinement: {}...{RESET}",
            args.precision.to_uppercase()
        );

        match args.precision.as_str() {
            "dd" => {
                let result = precision::dd_cg::run_dd_cg(&mut env, args.cg_steps, args.cg_tol);
                total_steps += result.steps;
            }
            "mixed" => {
                let result =
                    precision::mixed_cg::run_mixed_cg(&mut env, args.cg_steps, args.cg_tol);
                total_steps += result.steps;
            }
            "mpfr" => {
                let result = precision::mpfr_cg::run_mpfr_cg(
                    &mut env,
                    args.cg_steps,
                    args.cg_tol,
                    args.mpfr_bits,
                );
                total_steps += result.steps;
            }
            _ => {
                eprintln!(
                    "  {YELLOW}\u{26A0}{RESET} Unknown precision tier: {} (using f64)",
                    args.precision
                );
            }
        }
    }

    let optimal_d2 = env.compute_d2();
    let optimal_vtgv = env.compute_vtgv();
    let optimal_btv = env.compute_btv();
    let improvement = baseline_d2 - optimal_d2;
    let improvement_pct = if baseline_d2 > 0.0 {
        improvement / baseline_d2 * 100.0
    } else {
        0.0
    };
    let ln_n = (n as f64).ln();
    // K=1 bound: vᵀGv ≤ 1 + 1/ln(N)
    let gram_bound_satisfied = optimal_vtgv <= 1.0 + 1.0 / ln_n;

    let wall_time_s = t0.elapsed().as_secs_f64();
    let k_eff = (optimal_vtgv - 1.0) * ln_n;
    let matvec_rate = if wall_time_s > 0.0 {
        total_steps as f64 / wall_time_s
    } else {
        0.0
    };

    RunResult {
        n,
        dim: env.dim,
        agent: args.agent.clone(),
        baseline_d2,
        baseline_vtgv,
        baseline_btv,
        optimal_d2,
        optimal_vtgv,
        optimal_btv,
        improvement,
        improvement_pct,
        gram_bound_satisfied,
        total_steps,
        wall_time_s,
        k_eff,
        ln_n,
        matvec_rate,
    }
}

fn run_sweep(args: &Args, t_global: Instant) {
    println!(
        "  {BOLD}{MAGENTA}SWEEP{RESET}  {BOLD}HC Number Sweep (max N={})...{RESET}",
        args.sweep_max
    );
    println!();

    let schedule: Vec<usize> = HC_NUMBERS
        .iter()
        .filter(|&&n| n <= args.sweep_max)
        .cloned()
        .collect();

    println!("  {DIM}  Schedule: {:?}{RESET}", schedule);
    println!();

    let mut results: Vec<RunResult> = Vec::new();

    print_sweep_header();

    for &n in &schedule {
        let result = run_single(args, n);
        print_sweep_row(&result);
        results.push(result);
    }

    print_sweep_summary(&results);

    // Write JSON
    if let Some(ref path) = args.output {
        write_json(path, &results);
    } else {
        // Default output
        let out_dir = results_dir();
        std::fs::create_dir_all(&out_dir).ok();
        let sweep_path = out_dir.join("cathedral_rl_sweep.json");
        write_json(&sweep_path.to_string_lossy(), &results);
    }

    // Emit certificate
    let cert_dir = results_dir().join("certificates");
    std::fs::create_dir_all(&cert_dir).ok();
    let cert_path = cert_dir.join(format!("cathedral_rl_sweep_N{}.json", args.sweep_max));
    certificate::write_certificate(&cert_path, &results, t_global.elapsed()).ok();

    // Emit timestamped log
    write_sweep_log(args, &results, t_global.elapsed());
}

/// Write a comprehensive timestamped log for a single run.
fn write_run_log(args: &Args, result: &RunResult, elapsed: std::time::Duration) {
    use std::io::Write;
    use std::time::SystemTime;

    let log_dir = results_dir().join("logs");
    std::fs::create_dir_all(&log_dir).ok();
    let secs = SystemTime::now()
        .duration_since(SystemTime::UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs();
    let log_path = log_dir.join(format!("cathedral_rl_N{}_{}.log", result.n, secs));

    let pyth_sum = result.optimal_d2 + result.optimal_vtgv;
    let pyth_res = (pyth_sum - 1.0).abs();

    let log = format!(
        r#"═══════════════════════════════════════════════════════════════
CATHEDRAL RL — RUN LOG
═══════════════════════════════════════════════════════════════
Timestamp:   {}
N:           {}
Dimension:   {} × {}
Agent:       {}
Precision:   {}
CG Steps:    {}
CG Tol:      {:.2e}
Wall Time:   {:.2}s
═══════════════════════════════════════════════════════════════
BASELINE (log-cutoff witness)
  d²    = {:.15e}
  vᵀGv  = {:.15}
  bᵀv   = {:.15}

OPTIMIZED (CG-converged witness)
  d²    = {:.15e}
  vᵀGv  = {:.15}
  bᵀv   = {:.15}

DERIVED
  Pythagorean: d²+vᵀGv = {:.15}
  |residual|:  {:.2e}
  K_eff:       {:.6}
  ln(N):       {:.6}
  vᵀGv < 1:   {}
  Improvement: {:.6e} ({:.2}%)
  Matvec rate: {:.0} mv/s
═══════════════════════════════════════════════════════════════
"#,
        secs,
        result.n,
        result.dim,
        result.dim,
        result.agent,
        args.precision,
        args.cg_steps,
        args.cg_tol,
        elapsed.as_secs_f64(),
        result.baseline_d2,
        result.baseline_vtgv,
        result.baseline_btv,
        result.optimal_d2,
        result.optimal_vtgv,
        result.optimal_btv,
        pyth_sum,
        pyth_res,
        result.k_eff,
        result.ln_n,
        if result.optimal_vtgv < 1.0 {
            "YES ✓ (subcritical)"
        } else {
            "NO"
        },
        result.improvement,
        result.improvement_pct,
        result.matvec_rate,
    );

    if let Ok(mut f) = std::fs::File::create(&log_path) {
        f.write_all(log.as_bytes()).ok();
        eprintln!("  {GREEN}✓{RESET} Log written to {}", log_path.display());
    }

    // Also write the JSON result alongside
    let json_path = log_dir.join(format!("cathedral_rl_N{}_{}.json", result.n, secs));
    write_json(&json_path.to_string_lossy(), result);
}

/// Write a comprehensive timestamped log for a sweep.
fn write_sweep_log(args: &Args, results: &[RunResult], elapsed: std::time::Duration) {
    use std::io::Write;
    use std::time::SystemTime;

    let log_dir = results_dir().join("logs");
    std::fs::create_dir_all(&log_dir).ok();
    let secs = SystemTime::now()
        .duration_since(SystemTime::UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs();
    let max_n = results.last().map(|r| r.n).unwrap_or(0);
    let log_path = log_dir.join(format!("cathedral_rl_sweep_N{}_{}.log", max_n, secs));

    let mut log = format!(
        r#"═══════════════════════════════════════════════════════════════
CATHEDRAL RL — SWEEP LOG
═══════════════════════════════════════════════════════════════
Timestamp:   {}
Precision:   {}
CG Steps:    {}
CG Tol:      {:.2e}
Wall Time:   {:.2}s
HC Numbers:  {}
═══════════════════════════════════════════════════════════════

{:>8} | {:>16} | {:>16} | {:>16} | {:>8} | {:>12}
{:-<8}-+-{:-<16}-+-{:-<16}-+-{:-<16}-+-{:-<8}-+-{:-<12}
"#,
        secs,
        args.precision,
        args.cg_steps,
        args.cg_tol,
        elapsed.as_secs_f64(),
        results.len(),
        "N",
        "baseline_d2",
        "optimal_d2",
        "vtgv",
        "K_eff",
        "pyth_res",
        "",
        "",
        "",
        "",
        "",
        "",
    );

    for r in results {
        let pyth_sum = r.optimal_d2 + r.optimal_vtgv;
        let pyth_res = (pyth_sum - 1.0).abs();
        log += &format!(
            "{:>8} | {:>16.10e} | {:>16.10e} | {:>16.10} | {:>8.4} | {:>12.2e}\n",
            r.n, r.baseline_d2, r.optimal_d2, r.optimal_vtgv, r.k_eff, pyth_res,
        );
    }

    let all_sub = results.iter().all(|r| r.optimal_vtgv < 1.0);
    log += &format!(
        "\nAll vᵀGv < 1: {}\n",
        if all_sub {
            "YES ✓ (subcritical)"
        } else {
            "NO"
        },
    );

    if let Ok(mut f) = std::fs::File::create(&log_path) {
        f.write_all(log.as_bytes()).ok();
        eprintln!(
            "  {GREEN}✓{RESET} Sweep log written to {}",
            log_path.display()
        );
    }

    // Also write the JSON result alongside
    let json_path = log_dir.join(format!("cathedral_rl_sweep_N{}_{}.json", max_n, secs));
    write_json(&json_path.to_string_lossy(), &results.to_vec());
}
