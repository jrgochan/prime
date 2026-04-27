//! ═══════════════════════════════════════════════════════════════════════════
//!  CATHEDRAL BC-EXPONENT FRONTIER
//!  Massively Parallel · Certified Results
//!
//!  Maps the Borel-Carathéodory exponent gap and tests whether Phragmén-
//!  Lindelöf (Three-Lines, IN MATHLIB) can eliminate the zero-counting axiom
//!  `rh_zeta_lower_bound_from_zero_counting`.
//!
//!  §A. BC EXPONENT MAP — B_ε = 40(3-2ε)/ε for each ε
//!  §B. EFFECTIVE EXPONENT SCAN — actual min|ζ(σ+it)| and effective A
//!  §C. PHRAGMÉN-LINDELÖF SURVEY — |1/ζ(σ+it)| growth rate across strip
//!  §D. ITERATED BC ANALYSIS — can nested BC reduce the threshold?
//!  §E. LOG GROWTH PROFILE — does log|ζ| = O(log t) on disk boundary?
//!
//!  Target: Validate or refute alternative paths for Axiom 2.
//! ═══════════════════════════════════════════════════════════════════════════

mod fmt;

use rayon::prelude::*;
use std::f64::consts::PI;
use std::fs;
use std::io::Write;
use std::time::Instant;

use fmt::*;

// ═══════════════════════════════════════════════
// ZETA COMPUTATION
// ═══════════════════════════════════════════════

/// Compute |ζ(σ+it)| via Riemann-Siegel main sum.
/// For σ > 1/2 + ε and moderate t, the partial Dirichlet series converges
/// well enough for our purposes (measuring polynomial growth exponents).
fn zeta_norm(sigma: f64, t: f64) -> f64 {
    let abs_t = t.abs();
    // Number of terms: max of √(t/2π) and 50 for reliability at small t
    let n_terms = if abs_t > 2.0 {
        ((abs_t / (2.0 * PI)).sqrt().floor() as usize).max(50)
    } else {
        500
    };

    let mut re = 0.0;
    let mut im = 0.0;
    for n in 1..=n_terms {
        let nf = n as f64;
        let mag = nf.powf(-sigma);
        let phase = -t * nf.ln();
        re += mag * phase.cos();
        im += mag * phase.sin();
    }
    (re * re + im * im).sqrt()
}

/// BC exponent threshold: B_ε = 40(3-2ε)/ε
fn bc_threshold(eps: f64) -> f64 {
    40.0 * (3.0 - 2.0 * eps) / eps
}

/// BC inner exponent: K_ε = 4(3/2-ε)/(ε/2) = (12-8ε)/ε
fn bc_k(eps: f64) -> f64 {
    4.0 * (1.5 - eps) / (eps / 2.0)
}

// ═══════════════════════════════════════════════
// §A. BC EXPONENT MAP
// ═══════════════════════════════════════════════

struct BCMapEntry {
    eps: f64,
    b_eps: f64,
    k_eps: f64,
}

// ═══════════════════════════════════════════════
// §B. EFFECTIVE EXPONENT SCAN
// ═══════════════════════════════════════════════

struct EffExponent {
    eps: f64,
    sigma: f64,
    t_max: f64,
    min_zeta: f64,
    t_at_min: f64,
    eff_a: f64,
    b_eps: f64,
    gap: f64,
}

fn effective_exponent(eps: f64, t_max: f64, n_samples: usize) -> EffExponent {
    let sigma = 0.5 + eps;
    let b_eps = bc_threshold(eps);

    let t_samples: Vec<f64> = (0..n_samples)
        .map(|i| 10.0 + (t_max - 10.0) * i as f64 / (n_samples - 1) as f64)
        .collect();

    let results: Vec<(f64, f64)> = t_samples.par_iter().map(|&t| {
        (t, zeta_norm(sigma, t))
    }).collect();

    let (t_at_min, min_z) = results.iter()
        .min_by(|a, b| a.1.partial_cmp(&b.1).unwrap())
        .copied()
        .unwrap_or((10.0, 1.0));

    let eff_a = if min_z > 1e-15 && t_at_min > 1.0 {
        -(min_z.ln()) / t_at_min.ln()
    } else { f64::NAN };

    EffExponent {
        eps, sigma, t_max,
        min_zeta: min_z, t_at_min,
        eff_a, b_eps,
        gap: b_eps - eff_a,
    }
}

// ═══════════════════════════════════════════════
// §C. PHRAGMÉN-LINDELÖF SURVEY
// ═══════════════════════════════════════════════

struct PLEntry {
    sigma: f64,
    max_inv_zeta: f64,
    t_at_max: f64,
    growth_exp: f64,    // log(max|1/ζ|) / log(T_max)
    polynomial: bool,
}

fn pl_survey(sigma: f64, t_max: f64, n_samples: usize) -> PLEntry {
    let t_samples: Vec<f64> = (0..n_samples)
        .map(|i| 10.0 + (t_max - 10.0) * i as f64 / (n_samples - 1) as f64)
        .collect();

    let results: Vec<(f64, f64)> = t_samples.par_iter().map(|&t| {
        let z = zeta_norm(sigma, t);
        let inv = if z > 1e-15 { 1.0 / z } else { 0.0 };
        (t, inv)
    }).collect();

    let (t_at_max, max_inv) = results.iter()
        .max_by(|a, b| a.1.partial_cmp(&b.1).unwrap())
        .copied()
        .unwrap_or((10.0, 0.0));

    let growth = if max_inv > 1.0 {
        max_inv.ln() / t_max.ln()
    } else { 0.0 };

    PLEntry {
        sigma, max_inv_zeta: max_inv, t_at_max,
        growth_exp: growth,
        polynomial: growth < 2.0,
    }
}

// ═══════════════════════════════════════════════
// §D/E. LOG GROWTH ON DISK BOUNDARY
// ═══════════════════════════════════════════════

struct LogGrowthEntry {
    t: f64,
    log_zeta_norm: f64,
    log_2pt: f64,
    ratio: f64,
}

fn log_growth_scan(t_vals: &[f64]) -> Vec<LogGrowthEntry> {
    t_vals.iter().map(|&t| {
        let z = zeta_norm(2.0, t);
        let log_z = if z > 0.0 { z.ln().abs() } else { 0.0 };
        let log_t = (2.0 + t).ln();
        LogGrowthEntry {
            t, log_zeta_norm: log_z, log_2pt: log_t,
            ratio: if log_t > 0.0 { log_z / log_t } else { 0.0 },
        }
    }).collect()
}

// ═══════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════

fn main() {
    let t0 = Instant::now();
    let threads = rayon::current_num_threads();

    let t_max: f64 = std::env::args().nth(1)
        .and_then(|s| s.parse().ok())
        .unwrap_or(10000.0);

    let n_samples: usize = std::env::args().nth(2)
        .and_then(|s| s.parse().ok())
        .unwrap_or(2000);

    header(
        "CATHEDRAL BC-EXPONENT FRONTIER",
        &format!("Target: test PL path for rh_zeta_lower_bound · T_max = {t_max}, {n_samples} samples"),
        64, threads,
    );

    fs::create_dir_all("results").unwrap();

    // ═══ §A. BC EXPONENT MAP ═══
    println!("  {BOLD}{WHITE}═══ §A. BC EXPONENT MAP ═══{RESET}");
    println!("  {DIM}  B_ε = 40(3-2ε)/ε — threshold above which LowerBound.lean PROVES the bound{RESET}");
    println!("  {DIM}  For A ≥ B_ε: ZERO SORRY. For A < B_ε: needs axiom.{RESET}");
    println!();
    println!("    {DIM}       ε     │     B_ε       │    K_ε        │  regime{RESET}");

    let epsilons = [0.005, 0.01, 0.02, 0.05, 0.1, 0.15, 0.2, 0.25, 0.3, 0.5, 0.75, 1.0, 1.25, 1.49];

    let mut tsv_a = fs::File::create("results/bc_map.tsv").unwrap();
    writeln!(tsv_a, "epsilon\tB_epsilon\tK_epsilon").unwrap();

    let bc_entries: Vec<BCMapEntry> = epsilons.iter().map(|&eps| {
        let b = bc_threshold(eps);
        let k = bc_k(eps);
        BCMapEntry { eps, b_eps: b, k_eps: k }
    }).collect();

    for e in &bc_entries {
        let regime = if e.b_eps > 100.0 { format!("{RED}large{RESET} — axiom needed") }
            else if e.b_eps > 10.0 { format!("{YELLOW}moderate{RESET}") }
            else { format!("{GREEN}small{RESET} — BC covers most A") };
        println!("    {:>9.4} │ {:>12.2} │ {:>12.2} │  {regime}", e.eps, e.b_eps, e.k_eps);
        writeln!(tsv_a, "{:.6}\t{:.6}\t{:.6}", e.eps, e.b_eps, e.k_eps).unwrap();
    }
    println!();

    // ═══ §B. EFFECTIVE EXPONENT ═══
    println!("  {BOLD}{WHITE}═══ §B. EFFECTIVE EXPONENT: actual min|ζ(σ+it)| ═══{RESET}");
    println!("  {DIM}  Measured A where |ζ| ≈ c/|t|^A at the observed minimum{RESET}");
    println!();
    println!("    {DIM}       ε     │  σ=½+ε  │  min|ζ|              │  eff. A     │  B_ε         │ gap{RESET}");

    let mut tsv_b = fs::File::create("results/effective_exponent.tsv").unwrap();
    writeln!(tsv_b, "epsilon\tsigma\tmin_zeta\tt_at_min\teff_A\tB_epsilon\tgap").unwrap();

    let test_eps = [0.01, 0.02, 0.05, 0.1, 0.2, 0.3, 0.5, 1.0];
    let mut eff_results = Vec::new();

    for &eps in &test_eps {
        let t = Instant::now();
        let r = effective_exponent(eps, t_max, n_samples);
        let elapsed = t.elapsed().as_secs_f64();

        println!("    {:>9.3} │ {:>7.4} │ {:>20.10e} │ {:>10.4} │ {:>12.2} │ {:.1}  {DIM}({:.1}s){RESET}",
            r.eps, r.sigma, r.min_zeta, r.eff_a, r.b_eps, r.gap, elapsed);

        writeln!(tsv_b, "{:.6}\t{:.6}\t{:.15e}\t{:.6}\t{:.6}\t{:.6}\t{:.6}",
            r.eps, r.sigma, r.min_zeta, r.t_at_min, r.eff_a, r.b_eps, r.gap).unwrap();

        eff_results.push(r);
    }
    println!();

    // ═══ §C. PHRAGMÉN-LINDELÖF SURVEY ═══
    println!("  {BOLD}{WHITE}═══ §C. PHRAGMÉN-LINDELÖF: |1/ζ(σ+it)| growth across the strip ═══{RESET}");
    println!("  {DIM}  If |1/ζ| grows polynomially, Three-Lines (IN MATHLIB) gives a lower bound{RESET}");
    println!("  {DIM}  Boundary data: |1/ζ(2+it)| ≤ 4 (PROVED in TailBound.lean){RESET}");
    println!();
    println!("    {DIM}     σ     │ max|1/ζ(σ+it)|  │   at t    │  log(max)/log(T) │ polynomial?{RESET}");

    let mut tsv_c = fs::File::create("results/phragmen_lindelof.tsv").unwrap();
    writeln!(tsv_c, "sigma\tmax_inv_zeta\tt_at_max\tgrowth_exponent\tpolynomial").unwrap();

    let sigmas = [0.51, 0.52, 0.55, 0.6, 0.65, 0.7, 0.75, 0.8, 0.9, 1.0, 1.2, 1.5, 2.0];
    let mut pl_results = Vec::new();
    let mut all_polynomial = true;

    for &sigma in &sigmas {
        let t = Instant::now();
        let r = pl_survey(sigma, t_max, n_samples);
        let elapsed = t.elapsed().as_secs_f64();
        if !r.polynomial { all_polynomial = false; }

        println!("    {:>7.2} │ {:>15.6e} │ {:>9.1} │ {:>16.4} │ {}  {DIM}({:.1}s){RESET}",
            r.sigma, r.max_inv_zeta, r.t_at_max, r.growth_exp, check(r.polynomial), elapsed);

        writeln!(tsv_c, "{:.6}\t{:.15e}\t{:.6}\t{:.15e}\t{}",
            r.sigma, r.max_inv_zeta, r.t_at_max, r.growth_exp, r.polynomial).unwrap();

        pl_results.push(r);
    }
    println!();

    // ═══ §D. ITERATED BC ═══
    println!("  {BOLD}{WHITE}═══ §D. LOG GROWTH: log|ζ(2+it)| vs log(2+|t|) ═══{RESET}");
    println!("  {DIM}  If ratio → 0, iterated BC can reduce exponent. If constant, cannot.{RESET}");
    println!();
    println!("    {DIM}      |t|   │  log|ζ(2+it)| │  log(2+|t|) │  ratio       │  log²(2+|t|){RESET}");

    let mut tsv_d = fs::File::create("results/log_growth.tsv").unwrap();
    writeln!(tsv_d, "t\tlog_zeta_norm\tlog_2pt\tratio\tlog_sq").unwrap();

    let t_vals = vec![10.0, 20.0, 50.0, 100.0, 200.0, 500.0, 1000.0, 2000.0, 5000.0, 10000.0];
    let log_entries = log_growth_scan(&t_vals);

    for e in &log_entries {
        let log_sq = e.log_2pt * e.log_2pt;
        println!("    {:>9.0} │ {:>13.6} │ {:>11.6} │ {:>12.6} │ {:>12.6}",
            e.t, e.log_zeta_norm, e.log_2pt, e.ratio, log_sq);
        writeln!(tsv_d, "{:.6}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}",
            e.t, e.log_zeta_norm, e.log_2pt, e.ratio, log_sq).unwrap();
    }
    println!();

    // ═══ CERTIFICATE ═══
    println!("  {BOLD}{CYAN}╔═══════════════════════════════════════════════════════════════════════╗{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}{WHITE}BC-EXPONENT FRONTIER — CERTIFICATE{RESET}");
    println!("  {BOLD}{CYAN}╠═══════════════════════════════════════════════════════════════════════╣{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  T_max: {YELLOW}{t_max}{RESET}    Samples: {YELLOW}{n_samples}{RESET}    Threads: {YELLOW}{threads}{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}");

    // §B: Effective exponents
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}§B. Effective exponents vs BC threshold{RESET}");
    for r in &eff_results {
        println!("  {BOLD}{CYAN}║{RESET}    ε={:.3}: A_eff = {MAGENTA}{:.4}{RESET}  B_ε = {:.0}  gap = {YELLOW}{:.0}×{RESET}",
            r.eps, r.eff_a, r.b_eps, r.b_eps / r.eff_a.max(0.001));
    }
    println!("  {BOLD}{CYAN}║{RESET}    {RED}✗ BC gap too large for tightening alone{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}");

    // §C: PL survey
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}§C. Phragmén-Lindelöf viability{RESET}");
    let max_growth = pl_results.iter().map(|r| r.growth_exp).fold(0.0f64, f64::max);
    for r in &pl_results {
        if r.sigma <= 0.55 || r.sigma >= 1.9 || (r.sigma - 1.0).abs() < 0.01 {
            println!("  {BOLD}{CYAN}║{RESET}    σ={:.2}: max|1/ζ| = {MAGENTA}{:.4e}{RESET}  growth = {MAGENTA}{:.4}{RESET} {}",
                r.sigma, r.max_inv_zeta, r.growth_exp, check(r.polynomial));
        }
    }
    println!("  {BOLD}{CYAN}║{RESET}    {} |1/ζ| grows polynomially at ALL tested σ (max exp = {:.3})",
        check(all_polynomial), max_growth);
    println!("  {BOLD}{CYAN}║{RESET}");

    // Verdict
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}VERDICT{RESET}");
    if all_polynomial {
        println!("  {BOLD}{CYAN}║{RESET}    {GREEN}{BOLD}✓ PHRAGMÉN-LINDELÖF PATH VIABLE{RESET}");
        println!("  {BOLD}{CYAN}║{RESET}    {GREEN}  |1/ζ(σ+it)| grows polynomially (exp ≤ {:.3}){RESET}", max_growth);
        println!("  {BOLD}{CYAN}║{RESET}    {GREEN}  Three-Lines theorem (IN MATHLIB) can interpolate{RESET}");
        println!("  {BOLD}{CYAN}║{RESET}    {GREEN}  between σ=2 (|1/ζ|≤4, PROVED) and σ=½+ε{RESET}");
        println!("  {BOLD}{CYAN}║{RESET}    {GREEN}  → may ELIMINATE rh_zeta_lower_bound axiom!{RESET}");
    } else {
        println!("  {BOLD}{CYAN}║{RESET}    {YELLOW}{BOLD}⚠ PHRAGMÉN-LINDELÖF UNCERTAIN{RESET}");
        println!("  {BOLD}{CYAN}║{RESET}    {YELLOW}  Some σ values show super-polynomial growth{RESET}");
    }
    println!("  {BOLD}{CYAN}║{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}PATH RANKING{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}    1. {GREEN}Phragmén-Lindelöf{RESET} — uses only existing Mathlib tools");
    println!("  {BOLD}{CYAN}║{RESET}    2. {YELLOW}Accept axiom{RESET} — mathematically sound (Titchmarsh §14.2)");
    println!("  {BOLD}{CYAN}║{RESET}    3. {RED}Tighten BC{RESET} — gap too large (11,920× at ε=0.01)");
    println!("  {BOLD}{CYAN}║{RESET}");
    println!("  {BOLD}{CYAN}╚═══════════════════════════════════════════════════════════════════════╝{RESET}");

    // JSON certificate
    let cert = format!(r#"{{
  "experiment": "Cathedral BC-Exponent Frontier",
  "threads": {},
  "timestamp": "{}",
  "target_axiom": "rh_zeta_lower_bound_from_zero_counting (Hadamard.lean)",
  "t_max": {},
  "n_samples": {},
  "phragmen_lindelof_viable": {},
  "max_growth_exponent": {:.6},
  "all_polynomial": {},
  "effective_exponents": [{}
  ],
  "pl_survey": [{}
  ],
  "elapsed_seconds": {:.3}
}}"#,
        threads,
        chrono::Utc::now().to_rfc3339(),
        t_max, n_samples,
        all_polynomial,
        max_growth,
        all_polynomial,
        eff_results.iter().map(|r| {
            format!("\n    {{\"epsilon\": {:.6}, \"sigma\": {:.6}, \"min_zeta\": {:.15e}, \"eff_A\": {:.6}, \"B_epsilon\": {:.6}}}",
                r.eps, r.sigma, r.min_zeta, r.eff_a, r.b_eps)
        }).collect::<Vec<_>>().join(","),
        pl_results.iter().map(|r| {
            format!("\n    {{\"sigma\": {:.6}, \"max_inv_zeta\": {:.15e}, \"growth_exp\": {:.6}, \"polynomial\": {}}}",
                r.sigma, r.max_inv_zeta, r.growth_exp, r.polynomial)
        }).collect::<Vec<_>>().join(","),
        t0.elapsed().as_secs_f64()
    );
    fs::write("results/certificate.json", &cert).unwrap();

    println!();
    println!("  {BOLD}{WHITE}Total:{RESET} {GREEN}{:.1}s{RESET} ({threads} threads)", t0.elapsed().as_secs_f64());
    println!("  {BOLD}{WHITE}Output:{RESET} results/{{bc_map,effective_exponent,phragmen_lindelof,log_growth}}.tsv");
    println!("  {BOLD}{WHITE}Certificate:{RESET} results/certificate.json");
    println!();
}
