//! ═══════════════════════════════════════════════════════════════════════
//!  POINTWISE f_N(x) EVALUATOR — Möbius Cancellation Microscope v2
//!  Production-grade profiling of f_N(x) = Σ μ(k)w_k{1/(kx)}
//!
//!  Cathedral experiment: evaluates the Nyman-Beurling approximant
//!  f_N(x) at a fine grid of points x ∈ (0,1) and checks whether
//!  f_N(x) ≤ 1 + ε(N) pointwise — a key condition for the Gram bound.
//!
//!  The identity: vᵀGv = ∫₀¹ f_N(x)² dx = ‖f_N‖²
//!  If f_N(x) ≤ 1 + ε pointwise, then ‖f_N‖² ≤ (1 + ε)².
//!
//!  Usage:
//!    pointwise-eval <N> [--grid <M>] [--output <dir>]
//!
//!  Output:
//!    - pointwise_N<N>.tsv: full grid data (x, f_N(x), |f_N(x)-1|)
//!    - pointwise_cert_N<N>.json: certificate with extrema & L² check
//!    - pointwise_summary_N<N>.txt: human-readable report
//!
//! ═══════════════════════════════════════════════════════════════════════

use cathedral_utils::arith;
use cathedral_utils::arith::Kahan;
use cathedral_utils::mertens;
use rayon::prelude::*;
use std::io::Write;
use std::time::Instant;

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 2 || args[1] == "--help" || args[1] == "-h" {
        eprintln!("Usage: pointwise-eval <N> [--grid <M>] [--output <dir>]");
        eprintln!();
        eprintln!("Evaluate f_N(x) = Σ μ(k)w_k{{1/(kx)}} on a uniform grid of M points.");
        eprintln!("Tests whether f_N(x) ≤ 1 + ε(N) pointwise (Gram bound condition).");
        eprintln!();
        eprintln!("Arguments:");
        eprintln!("  N               Truncation parameter (2..100000)");
        eprintln!("  --grid <M>      Number of grid points (default: 10000)");
        eprintln!("  --output <dir>  Output directory (default: results_pointwise)");
        std::process::exit(1);
    }

    let n: usize = args[1].parse().expect("N must be a positive integer");
    let grid: usize = args.iter().position(|a| a == "--grid")
        .and_then(|i| args.get(i+1))
        .and_then(|s| s.parse().ok())
        .unwrap_or(10_000);
    let output_dir = args.iter().position(|a| a == "--output")
        .and_then(|i| args.get(i+1).map(|s| s.as_str()))
        .unwrap_or("results_pointwise");

    std::fs::create_dir_all(output_dir).ok();

    println!();
    println!("╔═══════════════════════════════════════════════════════════╗");
    println!("║  POINTWISE f_N(x) EVALUATOR — Möbius Microscope v2      ║");
    println!("║  Cathedral Gram Bound Analysis                           ║");
    println!("╚═══════════════════════════════════════════════════════════╝");
    println!();

    let t0 = Instant::now();

    // Compute weights
    let mu = arith::mobius_table(n);
    let weights = mertens::witness_vector(n, &mu);
    let dim = n - 1;
    let ln_n = (n as f64).ln();

    let n_active = weights.iter().filter(|&&w| w.abs() > 1e-30).count();
    eprintln!("═══ POINTWISE EVALUATOR N={n} ═══");
    eprintln!("  Grid: {grid} points on (0,1)");
    eprintln!("  Active weights: {n_active}/{dim} (squarefree k=2..{n})");
    eprintln!("  Parallelism: {} threads", rayon::current_num_threads());

    // Evaluate f_N(x) on grid in parallel
    let grid_data: Vec<(f64, f64)> = (1..=grid)
        .into_par_iter()
        .map(|i| {
            let x = (i as f64 - 0.5) / grid as f64; // midpoint rule
            let mut f_n = Kahan::new();

            for k_idx in 0..dim {
                let w = weights[k_idx];
                if w.abs() < 1e-30 { continue; }
                let k = (k_idx + 2) as f64;
                let inv_kx = 1.0 / (k * x);
                let frac = inv_kx - inv_kx.floor();
                f_n.add(w * frac);
            }
            (x, f_n.value())
        })
        .collect();

    let elapsed_eval = t0.elapsed().as_secs_f64();
    eprintln!("  ✓ Evaluated {grid} points in {elapsed_eval:.2}s");

    // Compute statistics
    let mut max_fn = f64::NEG_INFINITY;
    let mut min_fn = f64::INFINITY;
    let mut max_x = 0.0f64;
    let mut min_x = 0.0f64;
    let mut max_overshoot = 0.0f64; // max(f_N(x) - 1, 0)
    let mut max_overshoot_x = 0.0f64;
    let mut l2_sum = Kahan::new();
    let mut l2_err_sum = Kahan::new();
    let mut mean_sum = Kahan::new();
    let dx = 1.0 / grid as f64;

    for &(x, fx) in &grid_data {
        if fx > max_fn { max_fn = fx; max_x = x; }
        if fx < min_fn { min_fn = fx; min_x = x; }
        let overshoot = fx - 1.0;
        if overshoot > max_overshoot { max_overshoot = overshoot; max_overshoot_x = x; }
        l2_sum.add(fx * fx * dx);
        l2_err_sum.add((fx - 1.0).powi(2) * dx);
        mean_sum.add(fx * dx);
    }

    let l2_norm_sq = l2_sum.value();
    let l2_error_sq = l2_err_sum.value();
    let mean_fn = mean_sum.value();

    // bᵀv = ∫₀¹ f_N(x) dx (by definition)
    let btv = mean_fn;

    // d²_N = 1 - 2bᵀv + vᵀGv = 1 - 2·mean + ‖f_N‖²
    let d2n = 1.0 - 2.0 * btv + l2_norm_sq;

    // Count overshoot/undershoot points
    let n_over = grid_data.iter().filter(|(_, fx)| *fx > 1.0).count();
    let n_under = grid_data.iter().filter(|(_, fx)| *fx < 0.0).count();
    let overshoot_pct = 100.0 * n_over as f64 / grid as f64;
    let undershoot_pct = 100.0 * n_under as f64 / grid as f64;

    // Print summary
    println!("  ┌───────────────────────────────────────────────────────┐");
    println!("  │  POINTWISE PROFILE f_N(x), N={n:<6}                   │");
    println!("  ├───────────────────────────────────────────────────────┤");
    println!("  │  max f_N(x)   = {max_fn:>12.8}  at x = {max_x:.6}          │");
    println!("  │  min f_N(x)   = {min_fn:>12.8}  at x = {min_x:.6}          │");
    println!("  │  mean f_N     = {mean_fn:>12.8}  (= bᵀv)                │");
    println!("  │  ‖f_N‖²       = {l2_norm_sq:>12.8}  (= vᵀGv)               │");
    println!("  │  ‖f_N-1‖²     = {l2_error_sq:>12.8}  (= d²_N)                │");
    println!("  │  d²_N (check) = {d2n:>12.8}                             │");
    println!("  │  max(f_N-1)   = {:>12.8}  at x = {max_overshoot_x:.6}          │", max_overshoot);
    println!("  │  f_N > 1 at   = {n_over:>6} / {grid} pts ({overshoot_pct:.1}%)         │");
    println!("  │  f_N < 0 at   = {n_under:>6} / {grid} pts ({undershoot_pct:.1}%)         │");
    println!("  │  vtGv < 1?    = {}                                      │", if l2_norm_sq < 1.0 { "YES ✓" } else { "NO  ✗" });
    println!("  │  gap·ln(N)    = {:<12.8}                             │", (1.0 - l2_norm_sq) * ln_n);
    println!("  └───────────────────────────────────────────────────────┘");

    // Write TSV
    let tsv_path = format!("{output_dir}/pointwise_N{n}.tsv");
    {
        let mut f = std::fs::File::create(&tsv_path).expect("create TSV");
        writeln!(f, "x\tf_N\tf_N_minus_1\tabs_dev").unwrap();
        for &(x, fx) in &grid_data {
            writeln!(f, "{x:.8}\t{fx:.15e}\t{:.15e}\t{:.15e}", fx - 1.0, (fx - 1.0).abs()).unwrap();
        }
    }
    eprintln!("  ✓ TSV → {tsv_path}");

    // Write summary
    let sum_path = format!("{output_dir}/pointwise_summary_N{n}.txt");
    {
        let mut f = std::fs::File::create(&sum_path).expect("create summary");
        writeln!(f, "═══ POINTWISE PROFILE f_N(x) — N={n} ═══").unwrap();
        writeln!(f, "Grid: {grid} points on (0,1)").unwrap();
        writeln!(f, "Active weights: {n_active} (squarefree k=2..{n})").unwrap();
        writeln!(f).unwrap();
        writeln!(f, "EXTREMA:").unwrap();
        writeln!(f, "  max f_N(x) = {max_fn:.15e}  at x = {max_x:.10}").unwrap();
        writeln!(f, "  min f_N(x) = {min_fn:.15e}  at x = {min_x:.10}").unwrap();
        writeln!(f, "  max overshoot (f_N - 1) = {max_overshoot:.15e}  at x = {max_overshoot_x:.10}").unwrap();
        writeln!(f).unwrap();
        writeln!(f, "INTEGRALS (midpoint rule, {grid} pts):").unwrap();
        writeln!(f, "  ∫ f_N(x) dx      = {mean_fn:.15e}  (= bᵀv)").unwrap();
        writeln!(f, "  ∫ f_N(x)² dx     = {l2_norm_sq:.15e}  (= vᵀGv = ‖f_N‖²)").unwrap();
        writeln!(f, "  ∫ (f_N(x)-1)² dx = {l2_error_sq:.15e}  (= d²_N)").unwrap();
        writeln!(f, "  d²_N (1-2bv+vGv) = {d2n:.15e}").unwrap();
        writeln!(f).unwrap();
        writeln!(f, "GRAM BOUND:").unwrap();
        writeln!(f, "  vᵀGv         = {l2_norm_sq:.15e}").unwrap();
        writeln!(f, "  1 - vᵀGv     = {:.15e}", 1.0 - l2_norm_sq).unwrap();
        writeln!(f, "  gap·ln(N)    = {:.15e}", (1.0 - l2_norm_sq) * ln_n).unwrap();
        writeln!(f, "  Axiom sat?   = {}", if l2_norm_sq < 1.0 { "YES" } else { "CHECK" }).unwrap();
        writeln!(f).unwrap();
        writeln!(f, "POINTWISE BOUND:").unwrap();
        writeln!(f, "  Points with f_N > 1: {} / {} ({:.2}%)", n_over, grid, overshoot_pct).unwrap();
        writeln!(f, "  Points with f_N < 0: {} / {} ({:.2}%)", n_under, grid, undershoot_pct).unwrap();
        writeln!(f, "  If f_N ≤ 1+ε: ε = {max_overshoot:.15e}").unwrap();
        writeln!(f, "  Then ‖f_N‖² ≤ (1+ε)² = {:.15e}", (1.0 + max_overshoot).powi(2)).unwrap();
    }
    eprintln!("  ✓ Summary → {sum_path}");

    // Write certificate JSON
    let cert_path = format!("{output_dir}/pointwise_cert_N{n}.json");
    {
        // Find the 10 points with largest |f_N(x) - 1|
        let mut devs: Vec<(f64, f64, f64)> = grid_data.iter()
            .map(|&(x, fx)| (x, fx, (fx - 1.0).abs()))
            .collect();
        devs.sort_by(|a, b| b.2.partial_cmp(&a.2).unwrap());
        let top_devs: Vec<serde_json::Value> = devs.iter().take(20)
            .map(|&(x, fx, d)| serde_json::json!({"x": x, "f_N": fx, "dev": d}))
            .collect();

        // Histogram of f_N values
        let n_bins = 50;
        let mut hist = vec![0usize; n_bins];
        let hist_min = min_fn - 0.01;
        let hist_max = max_fn + 0.01;
        let hist_width = (hist_max - hist_min) / n_bins as f64;
        for &(_, fx) in &grid_data {
            let bin = ((fx - hist_min) / hist_width).floor() as usize;
            if bin < n_bins { hist[bin] += 1; }
        }
        let hist_json: Vec<serde_json::Value> = (0..n_bins)
            .map(|i| {
                let lo = hist_min + i as f64 * hist_width;
                serde_json::json!({"bin_lo": lo, "bin_hi": lo + hist_width, "count": hist[i]})
            })
            .collect();

        let cert = serde_json::json!({
            "experiment": "pointwise-eval",
            "version": "2.0",
            "N": n,
            "grid_points": grid,
            "active_weights": n_active,
            "extrema": {
                "max_fN": max_fn, "max_fN_x": max_x,
                "min_fN": min_fn, "min_fN_x": min_x,
                "max_overshoot": max_overshoot, "max_overshoot_x": max_overshoot_x,
            },
            "integrals": {
                "mean_fN": mean_fn,
                "l2_norm_sq": l2_norm_sq,
                "l2_error_sq": l2_error_sq,
                "d2N": d2n,
                "btv": btv,
            },
            "gram_bound": {
                "vtGv": l2_norm_sq,
                "gap": 1.0 - l2_norm_sq,
                "gap_times_lnN": (1.0 - l2_norm_sq) * ln_n,
                "axiom_satisfied": l2_norm_sq < 1.0,
            },
            "pointwise_bound": {
                "n_overshoot": n_over,
                "n_undershoot": n_under,
                "overshoot_pct": overshoot_pct,
                "epsilon": max_overshoot,
                "bound_1_plus_eps_sq": (1.0 + max_overshoot.max(0.0)).powi(2),
            },
            "top_deviations": top_devs,
            "histogram": hist_json,
            "timing_seconds": t0.elapsed().as_secs_f64(),
        });

        let mut f = std::fs::File::create(&cert_path).expect("create cert");
        writeln!(f, "{}", serde_json::to_string_pretty(&cert).unwrap()).unwrap();
    }
    eprintln!("  ✓ Cert → {cert_path}");
    eprintln!("  ✓ Total time: {:.2}s", t0.elapsed().as_secs_f64());
}
