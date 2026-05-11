//! ═══════════════════════════════════════════════════════════════════
//!  COVARIANCE DECAY EXPERIMENT
//!  Interrogating witness_covariance_decay: vᵀCv ≤ C/ln(N)
//!  The last remaining axiom in the Cathedral proof chain.
//!  This IS the Riemann Hypothesis.
//! ═══════════════════════════════════════════════════════════════════

mod build;
mod panels;
mod report;

use std::time::Instant;

/// Test schedule: N values to interrogate.
/// Capped at 20K — our largest DD-lossless HPDF file.
const SCHEDULE: &[usize] = &[
    10, 20, 50, 100, 200, 500, 1000, 2000, 3000, 5000, 7500, 10000, 15000, 20000,
];

/// Configuration parsed from CLI flags.
struct Config {
    /// If Some(prec), use MPFR Jacobi eigendecomposition at `prec` bits
    /// instead of f64 nalgebra. Applies to N ≤ mpfr_eigen_limit.
    mpfr_eigen_prec: Option<u32>,
    /// Maximum N for full MPFR eigen (default: FULL_EIGEN_LIMIT from panels).
    mpfr_eigen_limit: Option<usize>,
}

fn parse_config() -> Config {
    let args: Vec<String> = std::env::args().collect();
    let mut cfg = Config {
        mpfr_eigen_prec: None,
        mpfr_eigen_limit: None,
    };

    // --mpfr-eigen <bits>  : enable MPFR Jacobi eigensolver
    if let Some(idx) = args.iter().position(|a| a == "--mpfr-eigen") {
        let prec: u32 = args
            .get(idx + 1)
            .and_then(|s| s.parse().ok())
            .unwrap_or(256);
        cfg.mpfr_eigen_prec = Some(prec);
        eprintln!("  ⚡ MPFR Jacobi eigendecomposition enabled at {prec}-bit precision");
    }

    // --mpfr-limit <N>  : max N for full MPFR eigen
    if let Some(idx) = args.iter().position(|a| a == "--mpfr-limit") {
        let limit: usize = args
            .get(idx + 1)
            .and_then(|s| s.parse().ok())
            .unwrap_or(3000);
        cfg.mpfr_eigen_limit = Some(limit);
    }

    if args.iter().any(|a| a == "--help" || a == "-h") {
        eprintln!("Usage: covariance-decay [OPTIONS]");
        eprintln!();
        eprintln!("Options:");
        eprintln!("  --mpfr-eigen <bits>  Enable MPFR Jacobi eigensolver at <bits> precision");
        eprintln!("                       (default: 256 if flag present)");
        eprintln!("  --mpfr-limit <N>     Max N for full MPFR eigendecomposition (default: 3000)");
        eprintln!("  --help               Show this help message");
        eprintln!();
        eprintln!("Examples:");
        eprintln!("  covariance-decay                       # f64 nalgebra (default)");
        eprintln!("  covariance-decay --mpfr-eigen 256      # 256-bit MPFR Jacobi");
        eprintln!("  covariance-decay --mpfr-eigen 1024     # 1024-bit MPFR Jacobi");
        eprintln!("  covariance-decay --mpfr-eigen 1024 --mpfr-limit 2000");
        std::process::exit(0);
    }

    cfg
}

fn main() {
    let cfg = parse_config();
    let t0 = Instant::now();
    report::header();

    // ── Phase 1: Precompute number-theory tables ──────────────────
    let max_n = *SCHEDULE.last().unwrap();
    eprintln!("\n  ▸ Sieving Möbius table up to N={max_n}...");
    let mu = cathedral_utils::arith::mobius_table(max_n + 1);
    eprintln!("  ✓ Möbius table ready ({} entries)", mu.len());

    // ── Phase 2: Build / load Gram matrix (build-once) ───────────
    // Cached matrices use indices 2..N. We augment with k=1 row/col.
    let gram_full = build::build_or_load_gram(max_n, &mu);
    let gram_dim = gram_full.dim;
    eprintln!("  ✓ Full Gram matrix ready: {gram_dim}×{gram_dim} (indices 1..{max_n})");

    // ── Phase 3: Run all panels for each N in the schedule ───────
    let mut results: Vec<panels::NResult> = Vec::new();

    for &n in SCHEDULE {
        if n > gram_dim {
            eprintln!("  ⚠ Skipping N={n} (exceeds built matrix dim {gram_dim})");
            continue;
        }
        let tn = Instant::now();
        let sep = "═".repeat(60);
        eprintln!("\n{sep}");
        eprintln!("  N = {n}");
        eprintln!("{sep}");

        let r = panels::analyze_n(
            n,
            &gram_full,
            &mu,
            cfg.mpfr_eigen_prec,
            cfg.mpfr_eigen_limit,
        );
        eprintln!("  ✓ N={n} complete ({:.2}s)", tn.elapsed().as_secs_f64());
        results.push(r);
    }

    // ── Phase 4: Decay fitting and final report ──────────────────
    report::panel1_table(&results);
    report::panel2_spectrum(&results);
    report::panel3_projection(&results);
    report::panel4_pnt(&results);
    report::panel6_route_c(&results);
    report::decay_fit(&results);
    report::certificate(&results, t0.elapsed());

    eprintln!("\n  Total elapsed: {:.1}s", t0.elapsed().as_secs_f64());
}
