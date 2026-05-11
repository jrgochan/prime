//! # NB Witness Scan — GPU-Accelerated Edition
//!
//! For large N (1000+), the CPU quadrature approach in nb-witness-scan becomes
//! the bottleneck: evaluating f_N(x) at O(N) points with O(N) weights is O(N²).
//!
//! This GPU version takes a different approach:
//!
//! ## Strategy: Gram Matrix → Cholesky → d² (direct)
//!
//! Instead of computing d² via integral quadrature:
//!   d² ≈ 1 - 2·bᵀv + vᵀGv  (O(N²) quadrature)
//!
//! We compute the EXACT d² via:
//!   d² = 1 - bᵀ G⁻¹ b       (optimal over ALL weight vectors)
//!
//! This requires:
//! 1. Building the Gram matrix G_N (uses cathedral-utils/gram)
//! 2. Solving G x = b via Cholesky/CG
//! 3. d² = 1 - bᵀx
//!
//! For N ≤ 25k: GPU Cholesky via cuSOLVER (seconds)
//! For N > 25k: Mixed-precision CG with DD accumulation
//!
//! ## Modes
//!
//! - `scan <N_max>`: sweep N = 100, 200, ..., N_max
//! - `single <N>`: certify a single N
//! - `ooc <N>`: out-of-core mode for N > 50k (streams matrix from disk)
//!
//! ## Output
//!
//! - `results/gpu_sweep.json` — full sweep data
//! - `results/gpu_sweep.tsv` — N vs d² table
//! - Per-N certificates in `certificates/`

use cathedral_utils::{arith, gram, cache, dd::DD};
#[cfg(feature = "gpu")]
use cathedral_utils::gpu;
use cathedral_utils::linalg;
use rayon::prelude::*;
use serde::Serialize;
use std::fs;
use std::io::Write;
use std::time::Instant;

// ═══════════════════════════════════════════════════════════════════
// DATA STRUCTURES
// ═══════════════════════════════════════════════════════════════════

#[derive(Serialize, Clone)]
struct ScanRow {
    n: usize,
    dim: usize,
    d_sq: f64,
    d_sq_times_ln_n: f64,
    method: String,
    time_secs: f64,
    lambda_min: Option<f64>,
}

#[derive(Serialize)]
struct ScanResult {
    experiment: String,
    version: String,
    n_values: usize,
    elapsed_secs: f64,
    best_d_sq: f64,
    best_n: usize,
    data: Vec<ScanRow>,
}

// ═══════════════════════════════════════════════════════════════════
// B-VECTOR — uses canonical arith::b_vector from cathedral-utils
// b_k = (ln(k) + 1 - γ) / k for k = 2..=N
// ═══════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════
// SOLVERS
// ═══════════════════════════════════════════════════════════════════

/// GPU Cholesky solve: G x = b → d² = 1 - bᵀx
#[cfg(feature = "gpu")]
fn gpu_solve(gram_data: &[f64], b: &[f64], dim: usize) -> Option<(f64, String, f64)> {
    let t = Instant::now();
    match gpu::cholesky::d_sq_f64(gram_data, b, dim) {
        Ok(result) => Some((result.d_sq, result.method, t.elapsed().as_secs_f64())),
        Err(_) => None,
    }
}

/// DD-precision CG solve for large N
fn cg_solve(gram_data: &[f64], b: &[f64], dim: usize) -> (f64, String, f64) {
    let t = Instant::now();

    // Jacobi preconditioner
    let m_inv: Vec<f64> = (0..dim).into_par_iter()
        .map(|i| {
            let diag = gram_data[i * dim + i];
            if diag > 0.0 { 1.0 / diag } else { 1.0 }
        }).collect();

    let mut x = vec![0.0f64; dim];
    let mut r = b.to_vec();
    let mut z: Vec<f64> = r.iter().zip(m_inv.iter())
        .map(|(ri, mi)| ri * mi).collect();
    let mut p = z.clone();
    let mut ap = vec![0.0f64; dim];

    let mut rz = dd_dot(&r, &z);
    let b_norm = dd_dot(b, b).to_f64().sqrt();
    let tol = 1e-13 * b_norm;
    let max_iter = dim.max(5000).min(50_000);

    for iter in 0..max_iter {
        // f64 matvec (fast, parallel)
        linalg::dense_matvec(gram_data, dim, &p, &mut ap);

        let pap = dd_dot(&p, &ap);
        if pap.hi <= 0.0 && pap.lo <= 0.0 { break; }

        let alpha = rz / pap;
        let af = alpha.to_f64();

        x.par_iter_mut().zip(p.par_iter()).for_each(|(xi, pi)| *xi += af * pi);
        r.par_iter_mut().zip(ap.par_iter()).for_each(|(ri, ai)| *ri -= af * ai);

        let r_norm = dd_dot(&r, &r).to_f64().sqrt();
        if iter % 500 == 0 {
            let d_sq = 1.0 - dd_dot(b, &x).to_f64();
            eprint!("\r    CG-DD iter {:>5}: ‖r‖={:.3e}, d²≈{:.10}", iter, r_norm, d_sq);
        }
        if r_norm < tol {
            eprintln!();
            let d_sq = 1.0 - dd_dot(b, &x).to_f64();
            return (d_sq, format!("CG_DD_{}_iters", iter + 1), t.elapsed().as_secs_f64());
        }

        z.par_iter_mut().enumerate().for_each(|(i, zi)| *zi = m_inv[i] * r[i]);
        let rz_new = dd_dot(&r, &z);
        let beta = (rz_new / rz).to_f64();
        rz = rz_new;
        p.par_iter_mut().zip(z.par_iter()).for_each(|(pi, zi)| *pi = zi + beta * *pi);
    }

    eprintln!();
    let d_sq = 1.0 - dd_dot(b, &x).to_f64();
    (d_sq, "CG_DD_max_iter".to_string(), t.elapsed().as_secs_f64())
}

/// DD-accumulated dot product
fn dd_dot(a: &[f64], b: &[f64]) -> DD {
    const CHUNK: usize = 1024;
    let n = a.len();
    let n_chunks = n.div_ceil(CHUNK);
    let partials: Vec<DD> = (0..n_chunks).into_par_iter()
        .map(|c| {
            let start = c * CHUNK;
            let end = (start + CHUNK).min(n);
            let mut acc = DD::from_f64(0.0);
            for i in start..end {
                let p = a[i] * b[i];
                let e = a[i].mul_add(b[i], -p);
                acc += DD::new(p, e);
            }
            acc
        }).collect();
    let mut total = DD::from_f64(0.0);
    for p in &partials { total += *p; }
    total
}

/// Parallel matvec with DD accumulation per row

// ═══════════════════════════════════════════════════════════════════
// GRAM MATRIX BUILDING (with cache)
// ═══════════════════════════════════════════════════════════════════

fn build_or_load_gram(n: usize) -> (Vec<f64>, usize) {
    let dim = n - 1;

    // Try cache first
    let cache_path = cache::gram_cache_path(n, 64);
    if let Some(g) = cache::load_gram(&cache_path) {
        eprintln!("    ✓ Loaded G_{} from cache", n);
        return (g.data, dim);
    }

    // Build fresh
    eprintln!("    Building G_{} ({} × {})...", n, dim, dim);
    let t = Instant::now();

    let g = if n <= 500 {
        // f64 for small N
        let g = gram::GramMatrix::build(n, None);
        eprintln!("    ✓ Built in {:.1}s (f64)", t.elapsed().as_secs_f64());
        g
    } else if n <= 5000 {
        // DD for medium N
        let dd_table = gram::DDLnTable::new(n);
        let g = gram::GramMatrix::build_dd(n, &dd_table);
        eprintln!("    ✓ Built in {:.1}s (DD)", t.elapsed().as_secs_f64());
        g
    } else {
        // MPFR for large N
        let ln_table = gram::LnNTable::new(n, 256);
        let g = gram::GramMatrix::build_fast(n, &ln_table);
        eprintln!("    ✓ Built in {:.1}s (MPFR-256)", t.elapsed().as_secs_f64());
        g
    };

    // Cache for reuse
    cache::save_gram(&cache_path, &g).ok();
    let data = g.data;
    (data, dim)
}

// ═══════════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════════

fn main() {
    let t0 = Instant::now();
    let args: Vec<String> = std::env::args().collect();

    let mode = args.get(1).map(|s| s.as_str()).unwrap_or("scan");
    let n_max: usize = args.get(2).and_then(|s| s.parse().ok()).unwrap_or(5000);

    println!();
    println!("╔══════════════════════════════════════════════════════════════════╗");
    println!("║  🏛️  NB WITNESS SCAN GPU — Cathedral d²_N Pipeline v1.0        ║");
    println!("║                                                                 ║");
    println!("║  Mode: {:<10}  N_max: {:<8}                               ║", mode, n_max);
    println!("║  Uses: Gram matrix + Cholesky/CG (exact d²_N)                  ║");
    println!("╚══════════════════════════════════════════════════════════════════╝");
    println!();

    #[cfg(feature = "gpu")]
    {
        if let Some(info) = gpu::detect() {
            println!("  GPU: {} ({} MB VRAM)", info.name, info.vram_bytes / (1024 * 1024));
        } else {
            println!("  GPU: not detected, will use CPU CG");
        }
    }
    #[cfg(not(feature = "gpu"))]
    println!("  GPU: disabled (compile with --features gpu)");

    match mode {
        "scan" => run_scan(n_max),
        "single" => run_single(n_max),
        _ => {
            eprintln!("Usage: nb-witness-scan-gpu [scan|single] <N>");
            std::process::exit(1);
        }
    }

    println!("  Total time: {:.1}s", t0.elapsed().as_secs_f64());
    println!();
}

fn run_single(n: usize) {
    println!("  Certifying N = {}...", n);
    let (gram_data, dim) = build_or_load_gram(n);
    let b = arith::b_vector(n - 1);

    // Try GPU first, fall back to CG
    let (d_sq, method, time) = {
        #[cfg(feature = "gpu")]
        {
            if dim <= 25000 {
                if let Some(result) = gpu_solve(&gram_data, &b, dim) {
                    result
                } else {
                    cg_solve(&gram_data, &b, dim)
                }
            } else {
                cg_solve(&gram_data, &b, dim)
            }
        }
        #[cfg(not(feature = "gpu"))]
        { cg_solve(&gram_data, &b, dim) }
    };

    let ln_n = (n as f64).ln();
    println!();
    println!("  ┌──────────────────────────────────────────────────┐");
    println!("  │  N = {:>8}  (dim = {:>8})                    │", n, dim);
    println!("  │  d²_N     = {:.12e}                   │", d_sq);
    println!("  │  d²·ln(N) = {:.6}                             │", d_sq * ln_n);
    println!("  │  Method   = {:40} │", method);
    println!("  │  Time     = {:.1}s                                │", time);
    println!("  └──────────────────────────────────────────────────┘");
}

fn run_scan(n_max: usize) {
    // Generate test schedule: dense at small N, sparser at large N
    let mut test_ns: Vec<usize> = Vec::new();

    // Every 10 up to 100
    for n in (10..=100.min(n_max)).step_by(10) { test_ns.push(n); }
    // Every 50 up to 500
    for n in (150..=500.min(n_max)).step_by(50) { test_ns.push(n); }
    // Every 100 up to 2000
    for n in (600..=2000.min(n_max)).step_by(100) { test_ns.push(n); }
    // Every 500 up to 10000
    for n in (2500..=10000.min(n_max)).step_by(500) { test_ns.push(n); }
    // Every 2000 up to 50000
    for n in (12000..=50000.min(n_max)).step_by(2000) { test_ns.push(n); }
    // Every 10000 beyond
    for n in (60000..=n_max).step_by(10000) { test_ns.push(n); }

    // Always include n_max
    if !test_ns.contains(&n_max) && n_max > 10 { test_ns.push(n_max); }
    test_ns.sort();
    test_ns.dedup();

    println!("  Schedule: {} test points from N={} to N={}", test_ns.len(), test_ns[0], test_ns.last().unwrap());
    println!();

    let mut rows: Vec<ScanRow> = Vec::new();

    for &n in &test_ns {
        eprint!("  N={:>6}: ", n);
        let (gram_data, dim) = build_or_load_gram(n);
        let b = arith::b_vector(n - 1);

        let (d_sq, method, time) = {
            #[cfg(feature = "gpu")]
            {
                if dim <= 25000 {
                    if let Some(result) = gpu_solve(&gram_data, &b, dim) {
                        result
                    } else {
                        cg_solve(&gram_data, &b, dim)
                    }
                } else {
                    cg_solve(&gram_data, &b, dim)
                }
            }
            #[cfg(not(feature = "gpu"))]
            { cg_solve(&gram_data, &b, dim) }
        };

        let ln_n = (n as f64).ln();
        eprintln!("d²={:.8e}, d²·ln(N)={:.4}, method={}, {:.1}s",
            d_sq, d_sq * ln_n, method, time);

        rows.push(ScanRow {
            n, dim,
            d_sq,
            d_sq_times_ln_n: d_sq * ln_n,
            method,
            time_secs: time,
            lambda_min: None,
        });
    }

    // Write results
    fs::create_dir_all("results").ok();

    // TSV
    {
        let mut f = fs::File::create("results/gpu_sweep.tsv").unwrap();
        writeln!(f, "N\td_sq\td_sq*ln(N)\tmethod\ttime_secs").unwrap();
        for row in &rows {
            writeln!(f, "{}\t{:.12e}\t{:.6}\t{}\t{:.1}",
                row.n, row.d_sq, row.d_sq_times_ln_n, row.method, row.time_secs).unwrap();
        }
    }
    println!("  📄 results/gpu_sweep.tsv");

    // JSON
    let best = rows.iter().min_by(|a, b| a.d_sq.partial_cmp(&b.d_sq).unwrap()).unwrap();
    let result = ScanResult {
        experiment: "NB Witness Scan GPU".to_string(),
        version: "1.0.0".to_string(),
        n_values: rows.len(),
        elapsed_secs: 0.0,
        best_d_sq: best.d_sq,
        best_n: best.n,
        data: rows.clone(),
    };
    {
        let f = fs::File::create("results/gpu_sweep.json").unwrap();
        serde_json::to_writer_pretty(f, &result).unwrap();
    }
    println!("  📄 results/gpu_sweep.json");

    // Summary table
    println!();
    println!("  ┌────────┬──────────────────┬──────────┬────────────────────────┐");
    println!("  │   N    │      d²_N        │ d²·ln(N) │ Method                 │");
    println!("  ├────────┼──────────────────┼──────────┼────────────────────────┤");
    for row in &rows {
        println!("  │ {:>6} │ {:>16.10e} │ {:>8.4} │ {:22} │",
            row.n, row.d_sq, row.d_sq_times_ln_n, row.method);
    }
    println!("  └────────┴──────────────────┴──────────┴────────────────────────┘");
    println!();
    println!("  Best: d²_{} = {:.10e}", best.n, best.d_sq);
}
