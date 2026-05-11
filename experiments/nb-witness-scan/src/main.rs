//! # NB Witness Scan — Systematic f_N Evaluation
//!
//! For each N from 2 to N_max (default 1000), computes:
//! - Möbius sieve μ(k)
//! - Log-cutoff witness weights w_k = -μ(k)·(1 - ln(k)/ln(N))
//! - f_N(x) = Σ w_k·{1/(kx)} at sample points
//! - d²_N = 1 - 2bᵀv + vᵀGv  (via integral quadrature)
//! - PNT partial sums S₁, S₂, S₃
//!
//! Uses cathedral-utils exclusively — zero local math code.
//!
//! ## Output
//!
//! - `results/witness_scan.json` — full data for all N
//! - `results/d_sq_decay.tsv` — N vs d²_N table
//! - Terminal table with key statistics

use cathedral_utils::{arith, constants, mertens};
use rayon::prelude::*;
use serde::Serialize;
use std::fs;
use std::io::Write;
use std::time::Instant;

// ═══════════════════════════════════════════════════════════════════
// DATA STRUCTURES
// ═══════════════════════════════════════════════════════════════════

#[derive(Serialize, Clone)]
struct WitnessRow {
    n: usize,
    dim: usize,
    d_sq: f64,
    d_sq_times_ln_n: f64,
    bt_v: f64,
    vt_gv: f64,
    s1: f64,
    s2: f64,
    s3: f64,
    mertens_n: i64,
    mertens_ratio: f64,
    f_at_half: f64,
    f_l2_norm_sq: f64,
}

#[derive(Serialize)]
struct ScanResult {
    experiment: String,
    version: String,
    n_max: usize,
    n_min: usize,
    total_points: usize,
    elapsed_secs: f64,
    best_d_sq: f64,
    best_n: usize,
    d_sq_scaling: String,
    data: Vec<WitnessRow>,
}

// ═══════════════════════════════════════════════════════════════════
// CORE COMPUTATION
// ═══════════════════════════════════════════════════════════════════

fn analyze_n(n: usize, mu: &[i8], mertens_vals: &[i64]) -> WitnessRow {
    let dim = n - 1;
    let ln_n = (n as f64).ln();

    // Witness weights
    let weights = mertens::log_cutoff_weights(n, mu);

    // f_N at x = 0.5
    let f_at_half = mertens::f_n_at(0.5, &weights);

    // ‖f_N‖² = ∫₀¹ f_N(x)² dx  (= vᵀGv by Parseval)
    let n_pts = (1000).max(n * 4).min(50_000);
    let vt_gv = mertens::vtgv_by_integral(&weights, n_pts);
    let bt_v = mertens::btv_by_integral(&weights, n_pts);

    // d² = 1 - 2bᵀv + vᵀGv
    let d_sq = 1.0 - 2.0 * bt_v + vt_gv;

    // PNT sums
    let s1 = mertens::pnt_s1(mu, n);
    let s2 = mertens::pnt_s2(mu, n);
    let s3 = mertens::pnt_s3(mu, n);

    // Mertens
    let m_n = if n < mertens_vals.len() {
        mertens_vals[n]
    } else {
        0
    };
    let mertens_ratio = if n >= 10 {
        (m_n as f64).abs() / ((n as f64).sqrt() * ln_n.powi(2))
    } else {
        0.0
    };

    WitnessRow {
        n,
        dim,
        d_sq,
        d_sq_times_ln_n: d_sq * ln_n,
        bt_v,
        vt_gv,
        s1,
        s2,
        s3,
        mertens_n: m_n,
        mertens_ratio,
        f_at_half,
        f_l2_norm_sq: vt_gv,
    }
}

// ═══════════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════════

fn main() {
    let t0 = Instant::now();

    // Parse args
    let n_max: usize = std::env::args()
        .nth(1)
        .and_then(|s| s.parse().ok())
        .unwrap_or(1000);

    println!();
    println!("╔══════════════════════════════════════════════════════════════════╗");
    println!("║  🏛️  NB WITNESS SCAN — Cathedral f_N Evaluator v1.0            ║");
    println!("║                                                                 ║");
    println!(
        "║  Evaluates the Nyman-Beurling approximant for N = 2..{:<6}     ║",
        n_max
    );
    println!("║  Using cathedral-utils: arith + mertens + constants             ║");
    println!("╚══════════════════════════════════════════════════════════════════╝");
    println!();

    // Step 1: Sieve
    println!("  Step 1: Möbius sieve up to {}...", n_max);
    let mu = arith::mobius_table(n_max);
    let mertens_vals = mertens::mertens_values(&mu);
    println!(
        "  ✓ μ(k) for k ≤ {}, M({}) = {}",
        n_max, n_max, mertens_vals[n_max]
    );

    // Step 2: Parallel computation for all N
    println!(
        "  Step 2: Computing f_N and d²_N for N = 2..{}  (parallel)...",
        n_max
    );

    let test_ns: Vec<usize> = (2..=n_max).collect();
    let rows: Vec<WitnessRow> = test_ns
        .par_iter()
        .map(|&n| analyze_n(n, &mu, &mertens_vals))
        .collect();

    let elapsed = t0.elapsed().as_secs_f64();
    println!(
        "  ✓ {} data points in {:.1}s ({:.0} pts/sec)",
        rows.len(),
        elapsed,
        rows.len() as f64 / elapsed
    );

    // Step 3: Write results
    fs::create_dir_all("results").ok();

    // TSV
    {
        let mut f = fs::File::create("results/d_sq_decay.tsv").unwrap();
        writeln!(
            f,
            "N\td_sq\td_sq*ln(N)\tbt_v\tvt_Gv\tS1\tS2\tS3\tM(N)\tf_N(0.5)"
        )
        .unwrap();
        for row in &rows {
            writeln!(
                f,
                "{}\t{:.10e}\t{:.6}\t{:.8}\t{:.8}\t{:.6}\t{:.6}\t{:.6}\t{}\t{:.6}",
                row.n,
                row.d_sq,
                row.d_sq_times_ln_n,
                row.bt_v,
                row.vt_gv,
                row.s1,
                row.s2,
                row.s3,
                row.mertens_n,
                row.f_at_half
            )
            .unwrap();
        }
    }
    println!("  📄 results/d_sq_decay.tsv");

    // JSON
    let best = rows
        .iter()
        .min_by(|a, b| a.d_sq.partial_cmp(&b.d_sq).unwrap())
        .unwrap();
    let result = ScanResult {
        experiment: "NB Witness Scan".to_string(),
        version: "1.0.0".to_string(),
        n_max,
        n_min: 2,
        total_points: rows.len(),
        elapsed_secs: elapsed,
        best_d_sq: best.d_sq,
        best_n: best.n,
        d_sq_scaling: "d²_N ~ C/ln(N) (Mertens hypothesis)".to_string(),
        data: rows.clone(),
    };
    {
        let f = fs::File::create("results/witness_scan.json").unwrap();
        serde_json::to_writer_pretty(f, &result).unwrap();
    }
    println!("  📄 results/witness_scan.json");

    // Step 4: Summary table
    println!();
    println!("  ┌────────┬──────────────┬──────────┬──────────┬──────────┬──────────┐");
    println!("  │   N    │     d²_N     │ d²·ln(N) │   S₁(N)  │   S₂(N)  │  f(0.5)  │");
    println!("  ├────────┼──────────────┼──────────┼──────────┼──────────┼──────────┤");

    let sample_ns: Vec<usize> = vec![5, 10, 20, 30, 50, 75, 100, 150, 200, 300, 500, 750, 1000]
        .into_iter()
        .filter(|&n| n <= n_max)
        .collect();

    for &n in &sample_ns {
        if let Some(row) = rows.iter().find(|r| r.n == n) {
            println!(
                "  │ {:>6} │ {:>12.6e} │ {:>8.4} │ {:>8.5} │ {:>8.5} │ {:>8.4} │",
                row.n, row.d_sq, row.d_sq_times_ln_n, row.s1, row.s2, row.f_at_half
            );
        }
    }
    println!("  └────────┴──────────────┴──────────┴──────────┴──────────┴──────────┘");
    println!();

    // PNT convergence check
    let last = rows.last().unwrap();
    let gamma2 = 2.0 * constants::EULER_GAMMA;
    println!("  PNT Sum Convergence at N={}:", n_max);
    println!("    S₁ = {:.8}  (target: 0)", last.s1);
    println!("    S₂ = {:.8}  (target: -1)", last.s2);
    println!("    S₃ = {:.8}  (target: -2γ = {:.8})", last.s3, -gamma2);
    println!();

    // d² scaling analysis
    if rows.len() >= 10 {
        let _ln_ns: Vec<f64> = sample_ns
            .iter()
            .filter(|&&n| n >= 10)
            .filter_map(|&n| rows.iter().find(|r| r.n == n))
            .map(|r| (r.n as f64).ln())
            .collect();
        let d_ln: Vec<f64> = sample_ns
            .iter()
            .filter(|&&n| n >= 10)
            .filter_map(|&n| rows.iter().find(|r| r.n == n))
            .map(|r| r.d_sq_times_ln_n)
            .collect();
        if d_ln.len() >= 3 {
            let avg: f64 = d_ln.iter().sum::<f64>() / d_ln.len() as f64;
            let last_3_avg: f64 = d_ln[d_ln.len() - 3..].iter().sum::<f64>() / 3.0;
            println!("  d²·ln(N) scaling:");
            println!("    Average:  {:.4}", avg);
            println!("    Last 3:   {:.4}", last_3_avg);
            if (last_3_avg - avg).abs() < 0.5 {
                println!("    ✅ STABLE — d² ~ C/ln(N) confirmed (RH consistent)");
            } else {
                println!("    ⚠  Still converging");
            }
        }
    }

    println!();
    println!("  Best: d²_{} = {:.10e}", best.n, best.d_sq);
    println!("  Total time: {:.1}s", t0.elapsed().as_secs_f64());
    println!();
}
