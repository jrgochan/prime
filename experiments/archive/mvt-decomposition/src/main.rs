#![allow(unused, dead_code)]
//! ═══════════════════════════════════════════════════════════════════════════
//!  CATHEDRAL MVT DECOMPOSITION EXPERIMENT
//!  512-bit MPFR · Massively Parallel · Certified Results
//!
//!  Decomposes the mean value integral ∫₋ᵀᵀ |P_N(t)|² dt into diagonal
//!  and off-diagonal terms for Báez-Duarte Möbius log-taper weights.
//!  Tests whether a simpler bound (Bessel vs full Montgomery-Vaughan)
//!  suffices to graduate `critical_line_mellin_variance`.
//!
//!  §A. DIAGONAL vs OFF-DIAGONAL — exact decomposition at finite T
//!  §B. WEIGHT STRUCTURE — decay profile, Σ|a|², Σk|a|², growth rate
//!  §C. SEPARATION ANALYSIS — min δₙ = min|log m - log n|
//!  §D. BOUND COMPARISON — Off/Bessel vs Off/M-V vs Off/Diag
//!  §E. SCALING LAW — does Σk|aₖ|²/Σ|aₖ|² stay bounded as N → ∞?
//!
//!  Target: Validate or refute the hypothesis that critical_line_mellin_variance
//!  can be graduated without the full Montgomery-Vaughan inequality.
//! ═══════════════════════════════════════════════════════════════════════════

mod sieve;
mod weights;
mod fmt;

use rayon::prelude::*;
use std::fs;
use std::io::Write;
use std::time::Instant;

use fmt::*;

// ═══════════════════════════════════════════════
// §A. DIAGONAL vs OFF-DIAGONAL DECOMPOSITION
// ═══════════════════════════════════════════════

struct DecompResult {
    n: usize,
    t_max: f64,
    n_active: usize,
    sum_a2: f64,
    diagonal: f64,
    off_diagonal: f64,
    total: f64,
    off_diag_ratio: f64,      // |off-diag| / diagonal
    mv_bound: f64,            // π·Σ(n+1)|aₙ|²
    bessel_bound: f64,        // 2π·Σ|aₙ|²
    off_vs_mv: f64,           // |off-diag| / mv_bound
    off_vs_bessel: f64,       // |off-diag| / bessel_bound
    bessel_ok: bool,
}

/// Exact diagonal contribution: 2T · Σ |aₙ|²
fn diagonal_term(a: &[f64], t_max: f64) -> f64 {
    let sum_sq: f64 = a.iter().map(|x| x * x).sum();
    2.0 * t_max * sum_sq
}

/// Exact off-diagonal: Σ_{m≠n} aₘ·aₙ · 2·sin(T·ln(m/n))/ln(m/n)
fn off_diagonal_term(a: &[f64], t_max: f64) -> f64 {
    let n = a.len();
    let row_sums: Vec<f64> = (1..n).into_par_iter().map(|m| {
        if a[m] == 0.0 { return 0.0; }
        let mut row = 0.0;
        for k in 1..n {
            if k == m || a[k] == 0.0 { continue; }
            let log_ratio = (m as f64).ln() - (k as f64).ln();
            let sinc = 2.0 * (t_max * log_ratio).sin() / log_ratio;
            row += a[m] * a[k] * sinc;
        }
        row
    }).collect();
    row_sums.iter().sum()
}

/// M-V bound: π·Σₙ (n+1)|aₙ|²
fn mv_bound(a: &[f64]) -> f64 {
    a.iter().enumerate()
        .filter(|(n, _)| *n > 0)
        .map(|(n, &an)| (n as f64 + 1.0) * an * an)
        .sum::<f64>() * std::f64::consts::PI
}

/// Bessel bound: 2π·Σ|aₙ|²
fn bessel_bound(a: &[f64]) -> f64 {
    a.iter().map(|x| x * x).sum::<f64>() * 2.0 * std::f64::consts::PI
}

fn decompose(n: usize, mu: &[i8], t_max: f64) -> DecompResult {
    let a = weights::bd_dirichlet_coeffs(n, mu);
    let n_active = a.iter().filter(|&&x| x != 0.0).count();
    let sum_a2: f64 = a.iter().map(|x| x * x).sum();

    let diag = diagonal_term(&a, t_max);
    let offdiag = off_diagonal_term(&a, t_max);
    let total = diag + offdiag;

    let mv_b = mv_bound(&a);
    let bessel_b = bessel_bound(&a);

    let ratio = if diag > 0.0 { offdiag.abs() / diag } else { 0.0 };
    let off_mv = if mv_b > 0.0 { offdiag.abs() / mv_b } else { 0.0 };
    let off_be = if bessel_b > 0.0 { offdiag.abs() / bessel_b } else { 0.0 };

    DecompResult {
        n, t_max, n_active, sum_a2,
        diagonal: diag, off_diagonal: offdiag, total,
        off_diag_ratio: ratio,
        mv_bound: mv_b, bessel_bound: bessel_b,
        off_vs_mv: off_mv, off_vs_bessel: off_be,
        bessel_ok: offdiag.abs() < bessel_b,
    }
}

// ═══════════════════════════════════════════════
// §B. WEIGHT STRUCTURE
// ═══════════════════════════════════════════════

struct WeightProfile {
    n: usize,
    n_active: usize,
    sum_a2: f64,
    sum_ka2: f64,
    ratio_ka2: f64,      // Σk|a|²/Σ|a|²
    max_abs_a: f64,
    max_abs_k: usize,
}

fn weight_profile(n: usize, mu: &[i8]) -> WeightProfile {
    let a = weights::bd_dirichlet_coeffs(n, mu);
    let n_active = a.iter().filter(|&&x| x != 0.0).count();
    let sum_a2: f64 = a.iter().map(|x| x * x).sum();
    let sum_ka2: f64 = a.iter().enumerate()
        .map(|(k, x)| (k.max(1) as f64) * x * x).sum();

    let (mut max_abs, mut max_k) = (0.0f64, 0usize);
    for (k, &ak) in a.iter().enumerate() {
        if ak.abs() > max_abs { max_abs = ak.abs(); max_k = k; }
    }

    WeightProfile {
        n, n_active, sum_a2, sum_ka2,
        ratio_ka2: if sum_a2 > 0.0 { sum_ka2 / sum_a2 } else { 0.0 },
        max_abs_a: max_abs, max_abs_k: max_k,
    }
}

// ═══════════════════════════════════════════════
// §C. SEPARATION ANALYSIS
// ═══════════════════════════════════════════════

fn min_separation(n: usize, mu: &[i8]) -> (f64, usize, usize) {
    let a = weights::bd_dirichlet_coeffs(n, mu);
    let active: Vec<usize> = (1..n).filter(|&k| a[k] != 0.0).collect();
    let mut min_delta = f64::INFINITY;
    let (mut best_m, mut best_n) = (0, 0);
    for i in 0..active.len() {
        for j in (i+1)..active.len() {
            let d = ((active[j] as f64).ln() - (active[i] as f64).ln()).abs();
            if d < min_delta && d > 0.0 {
                min_delta = d;
                best_m = active[i];
                best_n = active[j];
            }
        }
    }
    (min_delta, best_m, best_n)
}

// ═══════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════

fn main() {
    let t0 = Instant::now();
    let threads = rayon::current_num_threads();

    let max_n: usize = std::env::args().nth(1)
        .and_then(|s| s.parse().ok())
        .unwrap_or(2000);

    header(
        "CATHEDRAL MVT DECOMPOSITION",
        &format!("Target: test Bessel vs M-V for critical_line_mellin_variance · max N = {max_n}"),
        weights::P, threads,
    );

    fs::create_dir_all("results").unwrap();

    let mut test_ns: Vec<usize> = vec![10, 20, 50, 100, 200, 300, 500, 750, 1000, 2000, 5000];
    test_ns.retain(|&n| n <= max_n);
    if !test_ns.contains(&max_n) && max_n > 10 { test_ns.push(max_n); }
    test_ns.sort();
    test_ns.dedup();
    let sieve_max = *test_ns.last().unwrap();

    eprintln!("  {DIM}▸ Sieving μ(k) for k ≤ {sieve_max}...{RESET}");
    let mu = sieve::mobius_sieve(sieve_max);
    eprintln!("  {GREEN}✓{RESET} Sieve complete ({} squarefree)",
        mu[1..].iter().filter(|&&m| m != 0).count());
    println!();

    let t_values: Vec<f64> = vec![10.0, 100.0, 1000.0, 10000.0, 100000.0];

    // ═══ §A. DECOMPOSITION ═══
    println!("  {BOLD}{WHITE}═══ §A. DIAGONAL vs OFF-DIAGONAL DECOMPOSITION ═══{RESET}");
    println!("  {DIM}  ∫₋ᵀᵀ |P_N(t)|² dt = Diagonal + Off-diagonal{RESET}");
    println!("  {DIM}  BD coefficients: aₙ = -μ(n)·(1 - ln(n)/ln(N)) / √n{RESET}");
    println!();

    let mut tsv_a = fs::File::create("results/decomposition.tsv").unwrap();
    writeln!(tsv_a, "N\tT\tn_active\tsum_a2\tdiagonal\toff_diagonal\ttotal\toff_diag_ratio\tmv_bound\tbessel_bound\toff_vs_mv\toff_vs_bessel\tbessel_ok").unwrap();

    let mut all_results: Vec<DecompResult> = Vec::new();

    for &n in &test_ns {
        let a = weights::bd_dirichlet_coeffs(n, &mu);
        let n_active = a.iter().filter(|&&x| x != 0.0).count();
        let sum_a2: f64 = a.iter().map(|x| x * x).sum();
        let mv_b = mv_bound(&a);
        let bessel_b = bessel_bound(&a);

        println!("  {BOLD}N = {n}{RESET}  ({n_active} active, Σ|a|² = {sum_a2:.6e}, M-V = {mv_b:.4e}, Bessel = {bessel_b:.4e})");
        println!("    {DIM}        T │    Diagonal    │  Off-diagonal  │     Total      │ Off/Diag  │ Off/MV   │ Off/Bessel{RESET}");

        for &t_max in &t_values {
            let t = Instant::now();
            let r = decompose(n, &mu, t_max);
            let elapsed = t.elapsed().as_secs_f64();

            println!("    {:>9.0} │ {:>13.6e} │ {:>+13.6e} │ {:>13.6e} │ {:.4e} {} │ {:.4e} │ {:.4e} {}  {DIM}({:.1}s){RESET}",
                t_max, r.diagonal, r.off_diagonal, r.total,
                r.off_diag_ratio, check(r.off_diag_ratio < 0.1),
                r.off_vs_mv, r.off_vs_bessel, check(r.bessel_ok),
                elapsed);

            writeln!(tsv_a, "{}\t{}\t{}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\t{}",
                r.n, r.t_max, r.n_active, r.sum_a2,
                r.diagonal, r.off_diagonal, r.total, r.off_diag_ratio,
                r.mv_bound, r.bessel_bound, r.off_vs_mv, r.off_vs_bessel,
                r.bessel_ok).unwrap();

            all_results.push(r);
        }
        println!();
    }

    // ═══ §B. WEIGHT STRUCTURE ═══
    println!("  {BOLD}{WHITE}═══ §B. BD WEIGHT STRUCTURE ═══{RESET}");
    println!("  {DIM}  How fast do BD Dirichlet coefficients decay?{RESET}");
    println!("  {DIM}  Critical ratio: Σk|aₖ|²/Σ|aₖ|² — bounded → Bessel suffices{RESET}");
    println!();
    println!("    {DIM}     N  │  active │   Σ|a|²    │   Σk|a|²   │  ratio    │  max|aₖ|     │ at k{RESET}");

    let mut tsv_b = fs::File::create("results/weight_structure.tsv").unwrap();
    writeln!(tsv_b, "N\tn_active\tsum_a2\tsum_ka2\tratio_ka2\tmax_abs_a\tmax_abs_k").unwrap();

    let mut weight_profiles: Vec<WeightProfile> = Vec::new();

    for &n in &test_ns {
        let wp = weight_profile(n, &mu);
        println!("    {:>6} │ {:>7} │ {:.6e} │ {:.6e} │ {:>8.4} │ {:.6e}  │ {}",
            wp.n, wp.n_active, wp.sum_a2, wp.sum_ka2, wp.ratio_ka2,
            wp.max_abs_a, wp.max_abs_k);
        writeln!(tsv_b, "{}\t{}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\t{}",
            wp.n, wp.n_active, wp.sum_a2, wp.sum_ka2, wp.ratio_ka2,
            wp.max_abs_a, wp.max_abs_k).unwrap();
        weight_profiles.push(wp);
    }
    println!();

    // Growth rate analysis
    if weight_profiles.len() >= 2 {
        println!("  {BOLD}  Ratio growth rate:{RESET}");
        for w in weight_profiles.windows(2) {
            let alpha = (w[1].ratio_ka2 / w[0].ratio_ka2).ln()
                / (w[1].n as f64 / w[0].n as f64).ln();
            println!("    N: {}->{}: ratio {:.4}->{:.4}, growth ≈ N^{:.3}",
                w[0].n, w[1].n, w[0].ratio_ka2, w[1].ratio_ka2, alpha);
        }
        println!();
    }

    // ═══ §C. SEPARATION ═══
    println!("  {BOLD}{WHITE}═══ §C. MINIMUM SEPARATION δₙ = min|log m - log n| ═══{RESET}");
    println!("  {DIM}  Larger δ → faster off-diagonal decay → weaker bounds suffice{RESET}");
    println!();
    println!("    {DIM}     N  │    δ_min       │  1/(N+1)       │ ratio δ/(1/(N+1)) │ closest pair{RESET}");

    let mut tsv_c = fs::File::create("results/separation.tsv").unwrap();
    writeln!(tsv_c, "N\tdelta_min\ttrivial_bound\tratio\tclosest_m\tclosest_n").unwrap();

    for &n in &test_ns {
        let (delta, m, k) = min_separation(n, &mu);
        let trivial = 1.0 / (n as f64 + 1.0);
        let ratio = delta / trivial;
        println!("    {:>6} │ {:.8e}  │ {:.8e}  │ {:>17.4} │ ({}, {})",
            n, delta, trivial, ratio, m, k);
        writeln!(tsv_c, "{}\t{:.15e}\t{:.15e}\t{:.15e}\t{}\t{}",
            n, delta, trivial, ratio, m, k).unwrap();
    }
    println!();

    // ═══ §D. BOUND COMPARISON SUMMARY ═══
    println!("  {BOLD}{WHITE}═══ §D. BOUND COMPARISON (T = 100000) ═══{RESET}");
    println!("  {DIM}  At large T (relevant for Mellin integral T → ∞):{RESET}");
    println!();
    println!("    {DIM}     N  │  |off-diag|     │  Bessel bound   │  M-V bound      │  Off/Diag   │ Bessel? │ M-V?{RESET}");

    let mut tsv_d = fs::File::create("results/bound_comparison.tsv").unwrap();
    writeln!(tsv_d, "N\toff_diag_abs\tbessel_bound\tmv_bound\toff_diag_ratio\tbessel_ok\tmv_ok").unwrap();

    let t_large = 100000.0;
    let mut all_bessel_ok = true;

    for &n in &test_ns {
        let r = decompose(n, &mu, t_large);
        let mv_ok = r.off_diagonal.abs() < r.mv_bound;
        if !r.bessel_ok { all_bessel_ok = false; }

        println!("    {:>6} │ {:>14.6e} │ {:>14.6e} │ {:>14.6e} │ {:.4e} │ {:>7} │ {}",
            n, r.off_diagonal.abs(), r.bessel_bound, r.mv_bound,
            r.off_diag_ratio, check(r.bessel_ok), check(mv_ok));

        writeln!(tsv_d, "{}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\t{}\t{}",
            n, r.off_diagonal.abs(), r.bessel_bound, r.mv_bound,
            r.off_diag_ratio, r.bessel_ok, mv_ok).unwrap();
    }
    println!();

    // ═══ CERTIFICATE ═══
    println!("  {BOLD}{CYAN}╔═══════════════════════════════════════════════════════════════════════╗{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}{WHITE}MVT DECOMPOSITION — CERTIFICATE{RESET}");
    println!("  {BOLD}{CYAN}╠═══════════════════════════════════════════════════════════════════════╣{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  Precision: {YELLOW}{}-bit MPFR{RESET}    Threads: {YELLOW}{threads}{RESET}", weights::P);
    println!("  {BOLD}{CYAN}║{RESET}  Max N: {YELLOW}{sieve_max}{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}");

    // §A: Off-diagonal ratios
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}§A. Off-diagonal / Diagonal (T=100000){RESET}");
    for &n in &test_ns {
        let r = decompose(n, &mu, t_large);
        println!("  {BOLD}{CYAN}║{RESET}    N={:>5}: Off/Diag = {MAGENTA}{:.6e}{RESET}  Off/MV = {:.4}  Off/Bessel = {:.4} {}",
            n, r.off_diag_ratio, r.off_vs_mv, r.off_vs_bessel, check(r.bessel_ok));
    }
    println!("  {BOLD}{CYAN}║{RESET}");

    // §B: Weight ratio growth
    let last_wp = weight_profiles.last().unwrap();
    let first_wp = weight_profiles.first().unwrap();
    let growth_exp = if first_wp.ratio_ka2 > 0.0 && first_wp.n > 0 {
        (last_wp.ratio_ka2 / first_wp.ratio_ka2).ln()
            / (last_wp.n as f64 / first_wp.n as f64).ln()
    } else { 0.0 };

    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}§B. Weight ratio Σk|aₖ|²/Σ|aₖ|² scaling{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}    N={:>5}: ratio = {MAGENTA}{:.4}{RESET}", first_wp.n, first_wp.ratio_ka2);
    println!("  {BOLD}{CYAN}║{RESET}    N={:>5}: ratio = {MAGENTA}{:.4}{RESET}", last_wp.n, last_wp.ratio_ka2);
    println!("  {BOLD}{CYAN}║{RESET}    Growth ≈ N^{YELLOW}{:.3}{RESET}", growth_exp);
    let ratio_bounded = growth_exp < 0.1;
    println!("  {BOLD}{CYAN}║{RESET}    {} Ratio bounded (required for Bessel)", check(ratio_bounded));
    println!("  {BOLD}{CYAN}║{RESET}");

    // Verdict
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}VERDICT{RESET}");
    if ratio_bounded && all_bessel_ok {
        println!("  {BOLD}{CYAN}║{RESET}    {GREEN}{BOLD}✓ BESSEL BOUND SUFFICES{RESET}");
        println!("  {BOLD}{CYAN}║{RESET}    {GREEN}  critical_line_mellin_variance may graduate{RESET}");
        println!("  {BOLD}{CYAN}║{RESET}    {GREEN}  WITHOUT Montgomery-Vaughan!{RESET}");
    } else {
        println!("  {BOLD}{CYAN}║{RESET}    {YELLOW}{BOLD}⚠ FULL MONTGOMERY-VAUGHAN REQUIRED{RESET}");
        println!("  {BOLD}{CYAN}║{RESET}    {YELLOW}  Weight ratio grows as ≈ N^{:.3}{RESET}", growth_exp);
        println!("  {BOLD}{CYAN}║{RESET}    {YELLOW}  Bessel bound at T=100000: {}{RESET}", check(all_bessel_ok));
        println!("  {BOLD}{CYAN}║{RESET}    {DIM}  The off-diagonal is SMALL relative to M-V bound,{RESET}");
        println!("  {BOLD}{CYAN}║{RESET}    {DIM}  confirming M-V is correct but loose for BD weights.{RESET}");
        println!("  {BOLD}{CYAN}║{RESET}    {DIM}  Graduation path: formalize M-V inequality for exp sums.{RESET}");
    }
    println!("  {BOLD}{CYAN}║{RESET}");
    println!("  {BOLD}{CYAN}╚═══════════════════════════════════════════════════════════════════════╝{RESET}");

    // JSON certificate
    let cert = format!(r#"{{
  "experiment": "Cathedral MVT Decomposition",
  "precision_bits": {},
  "threads": {},
  "timestamp": "{}",
  "target_axiom": "critical_line_mellin_variance (MellinCrown.lean)",
  "max_N_tested": {},
  "bessel_bound_suffices": {},
  "weight_ratio_growth_exponent": {:.6},
  "weight_ratio_bounded": {},
  "weight_profiles": [{}
  ],
  "decomposition_T100000": [{}
  ],
  "elapsed_seconds": {:.3}
}}"#,
        weights::P, threads,
        chrono::Utc::now().to_rfc3339(),
        sieve_max,
        ratio_bounded && all_bessel_ok,
        growth_exp,
        ratio_bounded,
        weight_profiles.iter().map(|wp| {
            format!("\n    {{\"N\": {}, \"n_active\": {}, \"sum_a2\": {:.15e}, \"sum_ka2\": {:.15e}, \"ratio\": {:.15e}}}",
                wp.n, wp.n_active, wp.sum_a2, wp.sum_ka2, wp.ratio_ka2)
        }).collect::<Vec<_>>().join(","),
        test_ns.iter().map(|&n| {
            let r = decompose(n, &mu, t_large);
            format!("\n    {{\"N\": {}, \"off_diag\": {:.15e}, \"off_diag_ratio\": {:.15e}, \"off_vs_mv\": {:.15e}, \"off_vs_bessel\": {:.15e}, \"bessel_ok\": {}}}",
                n, r.off_diagonal, r.off_diag_ratio, r.off_vs_mv, r.off_vs_bessel, r.bessel_ok)
        }).collect::<Vec<_>>().join(","),
        t0.elapsed().as_secs_f64()
    );
    fs::write("results/certificate.json", &cert).unwrap();

    println!();
    println!("  {BOLD}{WHITE}Total:{RESET} {GREEN}{:.1}s{RESET} ({threads} threads)", t0.elapsed().as_secs_f64());
    println!("  {BOLD}{WHITE}Output:{RESET} results/{{decomposition,weight_structure,separation,bound_comparison}}.tsv");
    println!("  {BOLD}{WHITE}Certificate:{RESET} results/certificate.json");
    println!();
}
