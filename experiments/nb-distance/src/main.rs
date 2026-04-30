//! # Nyman-Beurling Distance Probe
//!
//! The most direct computational test of the Riemann Hypothesis.
//!
//! ## Mathematical Foundation
//!
//! Let ρ_k(x) = {1/(kx)} be the dilated fractional part functions on (0,1).
//! The Nyman-Beurling theorem states:
//!
//!   **RH ⟺ d²_N → 0 as N → ∞**
//!
//! where d²_N = inf ||1 - f||²_{L²(0,1)} over f ∈ span{ρ_2, ..., ρ_N}.
//!
//! ## Computation
//!
//! The infimum is achieved by solving G_N c = b, giving:
//!   d²_N = 1 - b^T G_N^{-1} b
//!
//! where G(j,k) = ∫₀¹ {1/jx}{1/kx} dx (Gram matrix)
//!   and b_k = ∫₀¹ {1/kx} dx = (ln k + 1 - γ)/k (target vector).
//!
//! No envelope restriction, no sieve weights — pure L² projection.

mod solver;
mod certificate;

use cathedral_utils::{arith, cache, gram, fitting, fmt};
use fmt::{BOLD, WHITE, CYAN, GREEN, YELLOW, DIM, RESET};

fn main() {
    let t0 = std::time::Instant::now();
    let threads = rayon::current_num_threads();

    let max_n: usize = std::env::args()
        .nth(1)
        .and_then(|s| s.parse().ok())
        .unwrap_or(1000);

    // ═══ HEADER ═══
    println!();
    println!("  {BOLD}{CYAN}╔═══════════════════════════════════════════════════════════════╗{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}{WHITE}NYMAN-BEURLING DISTANCE PROBE{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {DIM}d²_N = 1 - b^T G_N^{{-1}} b  ·  RH ⟺ d²_N → 0{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {DIM}Max N = {max_n}  ·  {threads} threads{RESET}");
    println!("  {BOLD}{CYAN}╚═══════════════════════════════════════════════════════════════╝{RESET}");
    println!();

    // ═══ LOAD GRAM MATRIX ═══
    println!("  {BOLD}{WHITE}═══ §A. GRAM MATRIX ═══{RESET}");

    // Try caches: MPFR-512 > DD (106) > MPFR-256 > MPFR-128 > f64
    let (gram_matrix, precision) = {
        let precisions = [512, 106, 256, 128, 0];
        let mut found = None;
        for &p in &precisions {
            let path = cache::gram_cache_path(max_n, p);
            if let Some(g) = cache::load_gram(&path) {
                found = Some((g, p));
                break;
            }
        }
        match found {
            Some(x) => x,
            None => {
                eprintln!("  No cached Gram matrix for N={max_n}.");
                eprintln!("  Run: gram-builder {max_n}");
                std::process::exit(1);
            }
        }
    };

    let prec_str = match precision {
        0 => "f64".to_string(),
        106 => "double-double".to_string(),
        p => format!("{p}-bit MPFR"),
    };
    println!("  {GREEN}✓{RESET} Loaded {prec_str} Gram matrix (N={}, {} MB)", gram_matrix.max_n, gram_matrix.mem_mb());
    println!();

    // ═══ BUILD TEST SCHEDULE ═══
    let test_ns = build_schedule(max_n);
    println!("  {BOLD}{WHITE}═══ §B. DISTANCE COMPUTATION ═══{RESET}");
    println!("  {DIM}Computing d²_N = 1 - b^T G_N^{{-1}} b for {} values of N{RESET}", test_ns.len());
    println!();

    println!("  {DIM}     N  │ d²_N            │ λ_min          │ κ(G_N)     │ ||c*||₁      │ status{RESET}");
    println!("  {DIM}  ──────┼─────────────────┼────────────────┼────────────┼──────────────┼────────{RESET}");

    let mut results: Vec<solver::DistanceResult> = Vec::new();

    for &n in &test_ns {
        if n < 3 || n > gram_matrix.max_n { continue; }
        let dim = n - 1;
        let (sub, _trace) = gram_matrix.extract_submatrix(n);
        let b = arith::b_vector(dim);

        let r = solver::compute_distance(&sub, dim, &b, n);

        let status = if r.d2 > 0.0 && r.d2 < 1.0 {
            format!("{GREEN}✓ valid{RESET}")
        } else if r.d2 <= 0.0 {
            format!("\x1b[31m✗ d²≤0\x1b[0m")
        } else {
            format!("{YELLOW}⚠ d²≥1{RESET}")
        };

        println!(
            "  {:<6} │ {:+.10e} │ {:.10e} │ {:.4e} │ {:.6e} │ {}",
            n, r.d2, r.lambda_min, r.condition, r.coeff_mass, status
        );

        results.push(r);
    }
    println!();

    // ═══ DECAY ANALYSIS ═══
    println!("  {BOLD}{WHITE}═══ §C. DECAY ANALYSIS ═══{RESET}");

    // Power-law fit: d² ~ C · N^(-α)
    let fit_data: Vec<(f64, f64)> = results.iter()
        .filter(|r| r.n >= 10 && r.d2 > 0.0)
        .map(|r| (r.n as f64, r.d2))
        .collect();

    let (fit_alpha, fit_c, fit_r2) = if fit_data.len() >= 3 {
        let log_data: Vec<(f64, f64)> = fit_data.iter().map(|(n, d)| (n.ln(), d.ln())).collect();
        let (slope, intercept, r2) = fitting::linreg(&log_data);
        (-slope, intercept.exp(), r2)
    } else {
        (0.0, 0.0, 0.0)
    };

    println!("  {DIM}Power-law fit (N ≥ 10):{RESET}");
    println!("    d²_N ~ {:.6} · N^(-{:.4})   R² = {:.6}", fit_c, fit_alpha, fit_r2);
    println!();

    // Log fit: d² ~ C / ln(N)
    let log_fit = if fit_data.len() >= 3 {
        let inv_log_data: Vec<(f64, f64)> = fit_data.iter().map(|(n, d)| (1.0 / n.ln(), *d)).collect();
        let (slope, intercept, r2) = fitting::linreg(&inv_log_data);
        (slope, intercept, r2)
    } else {
        (0.0, 0.0, 0.0)
    };

    println!("  {DIM}Logarithmic fit (d² ~ a/ln(N) + b):{RESET}");
    println!("    d²_N ~ {:.6}/ln(N) + {:.6}   R² = {:.6}", log_fit.0, log_fit.1, log_fit.2);
    println!();

    // Check: is d² monotonically decreasing after initial transient?
    let monotone = results.windows(2)
        .filter(|w| w[0].n >= 10)
        .all(|w| w[1].d2 <= w[0].d2 + 1e-10);
    let all_positive = results.iter().all(|r| r.d2 > 0.0);

    let check = |b: bool| if b { format!("{GREEN}✓{RESET}") } else { format!("\x1b[31m✗\x1b[0m") };
    println!("  {} All d²_N > 0 (required by L² theory)", check(all_positive));
    println!("  {} Monotonically decreasing for N ≥ 10", check(monotone));

    if fit_alpha > 0.0 {
        let extrapolated_1e6 = fit_c * (1e6_f64).powf(-fit_alpha);
        let extrapolated_1e9 = fit_c * (1e9_f64).powf(-fit_alpha);
        println!();
        println!("  {DIM}Extrapolation (power-law):{RESET}");
        println!("    d²(10⁶)  ≈ {:.6e}", extrapolated_1e6);
        println!("    d²(10⁹)  ≈ {:.6e}", extrapolated_1e9);
        println!("    d²(10¹²) ≈ {:.6e}", fit_c * (1e12_f64).powf(-fit_alpha));
    }
    println!();

    // ═══ DELOCALIZATION ANALYSIS ═══
    println!("  {BOLD}{WHITE}═══ §D. EIGENVECTOR DELOCALIZATION ═══{RESET}");
    println!("  {DIM}Path B probe: if D(N) = ||v_min||_∞ · √N is bounded, then RH follows{RESET}");
    println!();
    println!("  {DIM}     N  │ ||v_min||_∞  │ D(N)         │ IPR(v_min)   │ |⟨b,v_min⟩|{RESET}");
    println!("  {DIM}  ──────┼──────────────┼──────────────┼──────────────┼─────────────{RESET}");

    let deloc_data: Vec<(f64, f64)> = results.iter()
        .filter(|r| r.n >= 10)
        .map(|r| {
            println!("  {:<6} │ {:.6e}  │ {:.6e}  │ {:.6e}  │ {:.6e}",
                r.n, r.vmin_linf, r.delocalization_ratio, r.ipr, r.b_vmin_proj);
            (r.n as f64, r.delocalization_ratio)
        })
        .collect();

    println!();

    // Fit D(N) ~ A · N^β to see if it's bounded (β ≈ 0) or growing
    if deloc_data.len() >= 3 {
        let log_deloc: Vec<(f64, f64)> = deloc_data.iter()
            .filter(|(_, d)| *d > 0.0)
            .map(|(n, d)| (n.ln(), d.ln()))
            .collect();
        if log_deloc.len() >= 3 {
            let (slope, intercept, r2) = fitting::linreg(&log_deloc);
            let a = intercept.exp();
            println!("  {DIM}D(N) scaling fit:{RESET}");
            println!("    D(N) ~ {:.4} · N^({:.4})   R² = {:.4}", a, slope, r2);
            if slope.abs() < 0.1 {
                println!("    {GREEN}✓ D(N) approximately BOUNDED → delocalization holds{RESET}");
            } else if slope > 0.0 {
                println!("    {YELLOW}⚠ D(N) growing as N^{:.3} — needs more data{RESET}", slope);
            }
            println!();
        }

        // IPR scaling: IPR ~ A · N^β  (should be β ≈ -1 for uniform delocalization)
        let ipr_data: Vec<(f64, f64)> = results.iter()
            .filter(|r| r.n >= 10 && r.ipr > 0.0)
            .map(|r| (r.n as f64, r.ipr))
            .collect();
        if ipr_data.len() >= 3 {
            let log_ipr: Vec<(f64, f64)> = ipr_data.iter()
                .map(|(n, ipr)| (n.ln(), ipr.ln()))
                .collect();
            let (slope, intercept, r2) = fitting::linreg(&log_ipr);
            println!("  {DIM}IPR scaling fit:{RESET}");
            println!("    IPR ~ {:.4} · N^({:.4})   R² = {:.4}", intercept.exp(), slope, r2);
            if slope < -0.5 {
                println!("    {GREEN}✓ IPR decaying → eigenvector delocalized{RESET}");
            }
        }
    }
    println!();

    // ═══ CERTIFICATE ═══
    let max_tested = results.last().map_or(0, |r| r.n);
    let min_d2 = results.iter().map(|r| r.d2).fold(f64::INFINITY, f64::min);

    println!("  {BOLD}{CYAN}╔═══════════════════════════════════════════════════════════════════════╗{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}{WHITE}NYMAN-BEURLING DISTANCE CERTIFICATE{RESET}");
    println!("  {BOLD}{CYAN}╠═══════════════════════════════════════════════════════════════════════╣{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  Gram: {prec_str} ({} MB)  Threads: {threads}  Max N: {max_tested}", gram_matrix.mem_mb());
    println!("  {BOLD}{CYAN}║{RESET}  b_k = (ln k + 1 - γ) / k");
    println!("  {BOLD}{CYAN}║{RESET}  {} All d²_N > 0 for N ≤ {max_tested}", check(all_positive));
    println!("  {BOLD}{CYAN}║{RESET}  {} Monotonically decreasing", check(monotone));
    println!("  {BOLD}{CYAN}║{RESET}  Min d²_N = {:.10e} at N = {}", min_d2,
        results.iter().min_by(|a, b| a.d2.partial_cmp(&b.d2).unwrap()).unwrap().n);
    println!("  {BOLD}{CYAN}║{RESET}  Decay: d² ~ {:.4} · N^(-{:.4})  R²={:.4}", fit_c, fit_alpha, fit_r2);
    if all_positive && fit_alpha > 0.0 {
        println!("  {BOLD}{CYAN}║{RESET}  {GREEN}{BOLD}CONSISTENT WITH RH{RESET}");
    }
    println!("  {BOLD}{CYAN}╚═══════════════════════════════════════════════════════════════════════╝{RESET}");
    println!();

    // ═══ WRITE OUTPUT ═══
    std::fs::create_dir_all("results").ok();
    certificate::write_tsv(
        std::path::Path::new("results/nb_distance.tsv"), &results
    ).expect("Failed to write TSV");

    certificate::write_certificate(
        std::path::Path::new("results/nb_certificate.json"),
        &results, precision, fit_alpha, fit_c, fit_r2,
    ).expect("Failed to write certificate");

    println!("  Total: {:.1}s ({threads} threads)", t0.elapsed().as_secs_f64());
    println!("  Output: results/nb_distance.tsv");
    println!("           results/nb_certificate.json");
    println!();
}

/// Build a dense test schedule for N values.
fn build_schedule(max_n: usize) -> Vec<usize> {
    let mut ns: Vec<usize> = Vec::new();
    // Dense: every integer from 3..30
    for n in 3..=30.min(max_n) { ns.push(n); }
    // Medium: every 5 from 35..100
    for n in (35..=100.min(max_n)).step_by(5) { ns.push(n); }
    // Coarse: every 25 from 125..500
    for n in (125..=500.min(max_n)).step_by(25) { ns.push(n); }
    // Sparse: every 50 from 550..1000
    for n in (550..=1000.min(max_n)).step_by(50) { ns.push(n); }
    // Wide: every 100 from 1100..2000
    for n in (1100..=max_n).step_by(100) { ns.push(n); }
    // Always include max_n
    if !ns.contains(&max_n) && max_n >= 3 { ns.push(max_n); }
    ns.sort();
    ns.dedup();
    ns
}
