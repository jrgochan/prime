//! ═══════════════════════════════════════════════════════════════════════════
//!  EXPLORATION 21 · ROAD 2: THE SPECTRAL ROAD
//!  Build-once Gram Matrix · Vacuum Geometry · Sieve Witnesses
//!
//!  Does λ_min(G_N) → 0?  Equivalent to RH by Nyman-Beurling.
//!
//!  Architecture:
//!    gram.rs       — Gram matrix engine (f64/MPFR, build-once)
//!    arith.rs      — Number theory (sieve, Möbius, b-vector)
//!    analysis.rs   — Eigenvalue analysis, PR, dipole detection
//!    witness.rs    — Selberg/GPY/Maynard sieve witnesses
//!    certificate.rs — JSON + TSV output
//!    fmt.rs        — Terminal formatting
//!
//!  Hardware: Apple M2 Max, 96 GB RAM, 12 cores
//! ═══════════════════════════════════════════════════════════════════════════

mod analysis;
mod arith;
mod certificate;
mod fmt;
mod gram;
mod optimizer;
mod witness;

use fmt::*;
use std::fs;
use std::time::Instant;

fn main() {
    let t0 = Instant::now();
    let threads = rayon::current_num_threads();

    let max_n: usize = std::env::args()
        .nth(1)
        .and_then(|s| s.parse().ok())
        .unwrap_or(1000);

    header(
        "ROAD 2: EIGENVALUE DECAY PROBE",
        &format!("Does λ_min(G_N) → 0?  (≡ RH)  ·  max N = {max_n}"),
        gram::P,
        threads,
    );
    println!("  {DIM}Hardware: M2 Max · 96 GB RAM · {threads} cores{RESET}");
    println!();
    fs::create_dir_all("results").unwrap();

    // ─── Test schedule ───────────────────────────────────────────
    let test_ns = build_test_schedule(max_n);

    // ═══ §0. SETUP ═══════════════════════════════════════════════
    println!("  {BOLD}{WHITE}═══ §0. SETUP ═══{RESET}");
    println!();

    // Try loading from cache: prefer MPFR, fall back to f64
    let mpfr_cache = cathedral_utils::cache::gram_cache_path(max_n, gram::P);
    let f64_cache = cathedral_utils::cache::gram_cache_path(max_n, 0);

    let (gram_matrix, ln_table) = if let Some(cached) = cathedral_utils::cache::load_gram(&mpfr_cache) {
        // MPFR cache hit — no ln_table needed for analysis
        (cached, None)
    } else if let Some(cached) = cathedral_utils::cache::load_gram(&f64_cache) {
        // f64 cache hit
        (cached, None)
    } else {
        // Build from scratch — use MPFR if requested or max_n > 500
        let needs_mpfr = max_n > 500;
        let lt = if needs_mpfr {
            let max_t = (max_n * 5).max(5_000).min(gram::MAX_LN_TABLE);
            Some(gram::LnTable::new(max_t))
        } else {
            None
        };
        let matrix = gram::GramMatrix::build(max_n, lt.as_ref());

        // Cache to disk for next time
        let save_path = if matrix.mpfr_built { &mpfr_cache } else { &f64_cache };
        if let Err(e) = cathedral_utils::cache::save_gram(save_path, &matrix) {
            eprintln!("  \x1b[33m⚠\x1b[0m Failed to cache: {e}");
        }

        (matrix, lt)
    };
    println!("  {DIM}Matrix memory: {} MB{RESET}", gram_matrix.mem_mb());
    println!();

    // ═══ §A. PRECISION VALIDATION ════════════════════════════════
    if let Some(ref lt) = ln_table {
        println!("  {BOLD}{WHITE}═══ §A. PRECISION VALIDATION ═══{RESET}");
        println!();
        for &n in &[50, 100, 200] {
            let t = Instant::now();
            let (max_rel, mean_rel) = gram::validate_f64_vs_mpfr(n, lt);
            println!(
                "    N={:<4}: max_rel_err = {:.2e}, mean = {:.2e}  ({:.1}s)",
                n,
                max_rel,
                mean_rel,
                t.elapsed().as_secs_f64()
            );
        }
        println!();
    }

    // ═══ §B. EIGENVALUE DECAY ════════════════════════════════════
    println!("  {BOLD}{WHITE}═══ §B. EIGENVALUE DECAY: λ_min(G_N) ═══{RESET}");
    println!(
        "  {DIM}  Extracting from prebuilt {0}×{0} Gram matrix{RESET}",
        gram_matrix.max_dim
    );
    println!();
    println!("  {DIM}     N  │ dim  │ λ_min           │ λ₂             │ gap λ₂/λ₁   │ time{RESET}");
    println!("  {DIM}  ──────┼──────┼─────────────────┼────────────────┼─────────────┼──────{RESET}");

    let eigen_results = analysis::eigenvalue_sweep(&gram_matrix, &test_ns);

    for r in &eigen_results {
        let gap_str = if r.gap.is_nan() {
            "—".to_string()
        } else {
            format!("{:.4}×", r.gap)
        };
        println!(
            "  {:<6} │ {:<4} │ {:.9e} │ {:.9e} │ {:<11} │ {:.1}s  {}",
            r.n,
            r.dim,
            r.lambda_min,
            r.lambda_2,
            gap_str,
            r.elapsed,
            check(r.lambda_min > 0.0)
        );
    }
    println!();

    // ═══ §C. DECAY RATE ANALYSIS ═════════════════════════════════
    println!("  {BOLD}{WHITE}═══ §C. DECAY RATE ANALYSIS ═══{RESET}");
    println!();

    let fit = analysis::fit_decay(&eigen_results);
    if fit.power_r2 > 0.0 {
        println!(
            "  {BOLD}Power law:{RESET}  λ_min ≈ {:.6} · N^({:.4})  R² = {MAGENTA}{:.6}{RESET}",
            fit.power_c, -fit.power_alpha, fit.power_r2
        );
    }
    if fit.log_r2 > 0.0 {
        println!(
            "  {BOLD}Log-decay:{RESET}  R² = {MAGENTA}{:.6}{RESET}",
            fit.log_r2
        );
    }
    if fit.power_r2 > 0.0 && fit.log_r2 > 0.0 {
        let winner = if fit.power_r2 > fit.log_r2 {
            "Power law"
        } else {
            "Log-decay"
        };
        println!("  {YELLOW}★ Best fit: {winner}{RESET}");
    }
    println!();

    // ═══ §D. EIGENVECTOR ANATOMY + DIPOLE ════════════════════════
    let study_n = test_ns
        .iter()
        .rev()
        .find(|&&n| n <= 500)
        .copied()
        .unwrap_or(200);
    println!("  {BOLD}{WHITE}═══ §D. EIGENVECTOR ANATOMY (N = {study_n}) ═══{RESET}");
    println!();

    // Find the eigenvector for study_n from our results
    if let Some(r) = eigen_results.iter().find(|r| r.n == study_n) {
        // Top components
        let mut components: Vec<(usize, f64)> = r
            .eigvec_min
            .iter()
            .enumerate()
            .map(|(i, &v)| (i + 2, v))
            .collect();
        components.sort_by(|a, b| b.1.abs().partial_cmp(&a.1.abs()).unwrap());

        println!("  {DIM}rank │ k     │ weight       │ factorization{RESET}");
        println!("  {DIM}─────┼───────┼──────────────┼──────────────{RESET}");
        for (rank, (k, w)) in components.iter().take(15).enumerate() {
            println!(
                "  {:<4} │ {:<5} │ {:+.8e} │ {}",
                rank + 1,
                k,
                w,
                arith::factorize(*k)
            );
        }

        // Prime vs composite weight
        let sieve = arith::sieve_primes(study_n);
        let (mut pw, mut cw) = (0.0f64, 0.0f64);
        for (i, v) in r.eigvec_min.iter().enumerate() {
            let w2 = v * v;
            if sieve[i + 2] {
                pw += w2;
            } else {
                cw += w2;
            }
        }
        println!();
        println!("  Weight² on primes:     {CYAN}{:.2}%{RESET}", pw * 100.0);
        println!(
            "  Weight² on composites: {YELLOW}{:.2}%{RESET}",
            cw * 100.0
        );

        // Dipole analysis
        println!();
        println!("  {BOLD}{WHITE}Arithmetic Dipole Analysis:{RESET}");
        let dipole = analysis::dipole_analysis(&r.eigvec_min, 15);
        println!(
            "    Positive contributions: {:+.8e}",
            dipole.pos_sum
        );
        println!(
            "    Negative contributions: {:+.8e}",
            dipole.neg_sum
        );
        println!("    Net (15 terms):        {:+.8e}", dipole.net);
        println!(
            "    Cancellation ratio:    {:.4}%",
            dipole.cancellation_ratio * 100.0
        );
    }
    println!();

    // ═══ §E. VACUUM GEOMETRY ═════════════════════════════════════
    println!("  {BOLD}{WHITE}═══ §E. VACUUM GEOMETRY ═══{RESET}");
    println!("  {DIM}Anderson localization + b-vector orthogonality{RESET}");
    println!();

    println!("  {DIM}     N  │ ⟨b,v_min⟩      │ PR         │ ||v||_∞     │ peak k/N{RESET}");
    println!("  {DIM}  ──────┼────────────────┼────────────┼─────────────┼─────────{RESET}");

    let mut vacuum_results: Vec<analysis::VacuumGeometry> = Vec::new();
    for &n in &test_ns {
        if n < 10 {
            continue;
        }
        if let Some(vg) = analysis::vacuum_geometry(&gram_matrix, n) {
            println!(
                "  {:<6} │ {:+.6e}  │ {:.2e}  │ {:.6e}  │ {:.3}",
                vg.n, vg.b_dot_v, vg.pr, vg.v_inf, vg.peak_ratio
            );
            vacuum_results.push(vg);
        }
    }
    println!();

    // ═══ §F. SIEVE WITNESS COMPARISON ════════════════════════════
    println!("  {BOLD}{WHITE}═══ §F. SIEVE WITNESSES: Selberg vs GPY vs Maynard ═══{RESET}");
    println!("  {DIM}d²_N = ||1 - f_N||² using full Gram matrix{RESET}");
    println!();
    println!("  {DIM}     N  │ Selberg       │ GPY           │ Maynard       │ Liouville{RESET}");
    println!("  {DIM}  ──────┼───────────────┼───────────────┼───────────────┼──────────────{RESET}");

    let mut all_witness_results: Vec<witness::WitnessResult> = Vec::new();
    for &n in &test_ns {
        if n < 10 || n > 500 {
            continue;
        }
        let results = witness::compare_witnesses(&gram_matrix, n);
        print!("  {:<6}", n);
        for r in &results {
            let marker = if r.d2_n < 0.0 {
                GREEN
            } else if r.d2_n < 1.0 {
                YELLOW
            } else {
                RED
            };
            print!(" │ {marker}{:+.6e}{RESET}", r.d2_n);
        }
        println!();
        all_witness_results.extend(results);
    }
    println!();

    // ═══ §G. ENVELOPE OPTIMIZATION ════════════════════════════════
    println!("  {BOLD}{WHITE}═══ §G. SIEVE ENVELOPE OPTIMIZER ═══{RESET}");
    println!("  {DIM}F(x) = c₁(1-x) + c₂(1-x)² + c₃(1-x)³ + c₄(1-x)⁴{RESET}");
    println!("  {DIM}Minimizing d²_N = 1 - 2c^T b + c^T G c via exact linear solve{RESET}");
    println!();

    let opt_theta = 0.9;
    println!("  {DIM}     N  │ Core       │ d²_opt        │ d²_sel        │ improve │ c₁       c₂       c₃       c₄{RESET}");
    println!("  {DIM}  ──────┼────────────┼───────────────┼───────────────┼─────────┼───────────────────────────────{RESET}");

    let opt_ns: Vec<usize> = test_ns.iter().copied().filter(|&n| n >= 10 && n <= 1000).collect();
    let opt_results = optimizer::sweep(&gram_matrix, &opt_ns, opt_theta);

    for r in &opt_results {
        let core_color = if r.core == "Liouville" { GREEN } else { YELLOW };
        println!(
            "  {:<6} │ {core_color}{:<10}{RESET} │ {:+.6e} │ {:+.6e} │ {GREEN}{:5.1}%{RESET}  │ {:+.3} {:+.3} {:+.3} {:+.3}",
            r.n, r.core, r.d2_min, r.d2_selberg, r.improvement * 100.0,
            r.params[0], r.params[1], r.params[2], r.params[3]
        );
    }
    println!();

    // Write optimizer results
    {
        let mut f = std::fs::File::create("results/optimizer.tsv").unwrap();
        use std::io::Write;
        writeln!(f, "N\tcore\ttheta\tD\td2_min\td2_selberg\timprovement\tc1\tc2\tc3\tc4").unwrap();
        for r in &opt_results {
            writeln!(f, "{}\t{}\t{:.2}\t{}\t{:.15e}\t{:.15e}\t{:.10}\t{:.10}\t{:.10}\t{:.10}\t{:.10}",
                r.n, r.core, r.theta, r.d_level, r.d2_min, r.d2_selberg, r.improvement,
                r.params[0], r.params[1], r.params[2], r.params[3]).unwrap();
        }
    }

    // ═══ §H. CERTIFICATE ═════════════════════════════════════════
    let all_positive = eigen_results.iter().all(|r| r.lambda_min > 0.0);
    let monotone = eigen_results
        .windows(2)
        .all(|w| w[1].lambda_min <= w[0].lambda_min + 1e-15);
    let max_n_tested = eigen_results.last().map_or(0, |r| r.n);

    println!("  {BOLD}{CYAN}╔═══════════════════════════════════════════════════════════════════════╗{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}{WHITE}ROAD 2 CERTIFICATE — EIGENVALUE DECAY PROBE{RESET}");
    println!("  {BOLD}{CYAN}╠═══════════════════════════════════════════════════════════════════════╣{RESET}");
    println!(
        "  {BOLD}{CYAN}║{RESET}  Gram: {} ({} MB)  Threads: {threads}  Max N: {max_n_tested}",
        if gram_matrix.mpfr_built {
            format!("{}-bit MPFR", gram::P)
        } else {
            "f64".to_string()
        },
        gram_matrix.mem_mb()
    );
    println!(
        "  {BOLD}{CYAN}║{RESET}  {} λ_min > 0 for all N ≤ {max_n_tested}",
        check(all_positive)
    );
    println!(
        "  {BOLD}{CYAN}║{RESET}  {} Monotonically decreasing",
        check(monotone)
    );
    if fit.power_r2 > 0.5 {
        println!(
            "  {BOLD}{CYAN}║{RESET}  Decay: λ ~ {:.4} · N^({:.3})  R²={:.4}",
            fit.power_c, -fit.power_alpha, fit.power_r2
        );
    }
    if all_positive {
        println!("  {BOLD}{CYAN}║{RESET}  {GREEN}{BOLD}CONSISTENT WITH RH{RESET}");
    }
    println!("  {BOLD}{CYAN}╚═══════════════════════════════════════════════════════════════════════╝{RESET}");
    println!();

    // ─── Write output files ──────────────────────────────────────
    certificate::write_eigenvalue_tsv(&eigen_results, "results/eigenvalue_decay.tsv");
    certificate::write_vacuum_tsv(&vacuum_results, "results/vacuum_geometry.tsv");
    certificate::write_witness_tsv(&all_witness_results, "results/witness_comparison.tsv");
    certificate::write_certificate_json(
        &eigen_results,
        &fit,
        gram_matrix.mpfr_built,
        gram_matrix.mem_mb(),
        threads,
        gram::P,
        t0.elapsed().as_secs_f64(),
        "results/certificate.json",
    );

    println!(
        "  {BOLD}{WHITE}Total:{RESET} {GREEN}{:.1}s{RESET} ({threads} threads)",
        t0.elapsed().as_secs_f64()
    );
    println!("  {BOLD}{WHITE}Output:{RESET} results/eigenvalue_decay.tsv");
    println!("  {BOLD}{WHITE}        {RESET} results/vacuum_geometry.tsv");
    println!("  {BOLD}{WHITE}        {RESET} results/witness_comparison.tsv");
    println!("  {BOLD}{WHITE}        {RESET} results/certificate.json");
    println!();
}

/// Build the test schedule: fixed points + dense sampling above 500.
fn build_test_schedule(max_n: usize) -> Vec<usize> {
    let mut ns: Vec<usize> = Vec::new();
    for &step in &[
        10, 20, 30, 50, 75, 100, 150, 200, 250, 300, 400, 500, 600, 700, 800, 900, 1000, 1200,
        1500, 2000, 3000, 5000, 7000, 10000,
    ] {
        if step <= max_n {
            ns.push(step);
        }
    }
    for n in (500..=max_n).step_by(100) {
        if !ns.contains(&n) {
            ns.push(n);
        }
    }
    if !ns.contains(&max_n) {
        ns.push(max_n);
    }
    ns.sort();
    ns.dedup();
    ns
}
