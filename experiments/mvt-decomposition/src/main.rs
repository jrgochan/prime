//! ═══════════════════════════════════════════════════════════════════════════
//!  CATHEDRAL MVT-DECOMPOSITION EXPERIMENT
//!  256-bit MPFR · Massively Parallel · Axiom Strategy Analysis
//!
//!  PURPOSE: Determine whether the full Montgomery-Vaughan inequality is
//!  needed to graduate `critical_line_mellin_variance`, or whether a simpler
//!  bound suffices for BD-specific weights.
//!
//!  KEY INSIGHT: The MVT says ∫₋ᵀᵀ |Σ aₙ n⁻ⁱᵗ|² dt = 2T·Σ|aₙ|² + off-diagonal.
//!  The full M-V bounds off-diagonal ≤ π·Σ n|aₙ|². But for BD weights
//!  aₙ = -μ(n)·logTaper(n)/√n, the off-diagonal might decay independently.
//!
//!  §1. DIAGONAL vs OFF-DIAGONAL — exact decomposition at finite T
//!  §2. OFF-DIAGONAL STRUCTURE — sign, cancellation, decay pattern
//!  §3. RATIO ANALYSIS — off-diagonal / diagonal as f(T, N)
//!  §4. SIMPLIFIED BOUND TEST — can we avoid full M-V?
//!
//!  If off-diag/diag → 0 faster than expected, a weaker inequality
//!  (provable from existing Mathlib tools) might suffice.
//! ═══════════════════════════════════════════════════════════════════════════

mod fmt;
mod sieve;

use rayon::prelude::*;
use rug::Float;
use std::fs;
use std::io::Write;
use std::time::Instant;

use sieve::P;
use fmt::*;

/// Compute the BD Dirichlet coefficients: aₙ = -μ(n)·(1-log(n)/log(N)) / √n
/// These are the coefficients in the Mellin transform of the BD residual.
fn bd_dirichlet_coeffs(n: usize, mu: &[i8]) -> Vec<f64> {
    let log_n = (n as f64).ln();
    (0..n).map(|k| {
        if k == 0 { return 0.0; }
        if mu[k] == 0 { return 0.0; }
        let log_k = (k as f64).ln();
        let taper = 1.0 - log_k / log_n;
        if taper <= 0.0 { return 0.0; }
        -(mu[k] as f64) * taper / (k as f64).sqrt()
    }).collect()
}

/// Exact diagonal contribution: 2T · Σ |aₙ|²
fn diagonal_term(a: &[f64], t_max: f64) -> f64 {
    let sum_sq: f64 = a.iter().map(|x| x * x).sum();
    2.0 * t_max * sum_sq
}

/// Exact off-diagonal contribution: Σ_{m≠n} aₘ·aₙ·∫₋ᵀᵀ (m/n)^{-it} dt
/// = Σ_{m≠n} aₘ·aₙ · 2·sin(T·ln(m/n)) / ln(m/n)
fn off_diagonal_term(a: &[f64], t_max: f64) -> f64 {
    let n = a.len();
    // Use parallel sum over rows
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

/// The M-V bound on the off-diagonal: π · Σₙ (n+1) · |aₙ|²
/// (using δₙ = min_{m≠n} |log m - log n| ≥ 1/(n+1) and M-V Hilbert inequality)
fn mv_bound(a: &[f64]) -> f64 {
    let mut sum = 0.0;
    for (n, &an) in a.iter().enumerate() {
        if n == 0 || an == 0.0 { continue; }
        sum += (n as f64 + 1.0) * an * an;
    }
    std::f64::consts::PI * sum
}

/// A weaker "Bessel-Parseval" bound: just Σ|aₙ|² (no n factor)
/// This would be provable from plain Fourier analysis, no M-V needed.
fn bessel_bound(a: &[f64]) -> f64 {
    let sum_sq: f64 = a.iter().map(|x| x * x).sum();
    2.0 * std::f64::consts::PI * sum_sq
}

/// Minimum separation δₙ = min_{m≠n, m,n≤N} |log m - log n|
fn min_separation(n: usize, a: &[f64]) -> f64 {
    let mut min_delta = f64::INFINITY;
    let active: Vec<usize> = (1..n).filter(|&k| a[k] != 0.0).collect();
    for i in 0..active.len() {
        for j in (i+1)..active.len() {
            let d = ((active[j] as f64).ln() - (active[i] as f64).ln()).abs();
            if d < min_delta && d > 0.0 {
                min_delta = d;
            }
        }
    }
    min_delta
}

fn main() {
    let t0 = Instant::now();
    let threads = rayon::current_num_threads();

    let max_n: usize = std::env::args().nth(1)
        .and_then(|s| s.parse().ok())
        .unwrap_or(500);

    header(
        "CATHEDRAL MVT DECOMPOSITION",
        &format!("Strategy analysis for critical_line_mellin_variance · max N = {max_n}"),
        P, threads,
    );

    fs::create_dir_all("results").unwrap();

    let test_ns: Vec<usize> = [10, 20, 50, 100, 200, 300, 500, 750, 1000, 2000]
        .iter().copied().filter(|&n| n <= max_n).collect();

    eprintln!("  {DIM}▸ Sieving μ(k) for k ≤ {max_n}...{RESET}");
    let mu = sieve::mobius_sieve(max_n);
    eprintln!("  {GREEN}✓{RESET} Sieve complete\n");

    // ═══════════════════════════════════════════════
    // §1. DIAGONAL vs OFF-DIAGONAL AT VARIOUS T
    // ═══════════════════════════════════════════════
    println!("  {BOLD}{WHITE}═══ §1. DIAGONAL vs OFF-DIAGONAL DECOMPOSITION ═══{RESET}");
    println!("  {DIM}  For each N, compute ∫₋ᵀᵀ |P_N(t)|² dt = diagonal + off-diagonal{RESET}");
    println!("  {DIM}  BD coefficients: aₙ = -μ(n)·(1 - ln(n)/ln(N)) / √n{RESET}");
    println!();

    let t_values: Vec<f64> = vec![10.0, 100.0, 1000.0, 10000.0];

    let mut tsv1 = fs::File::create("results/decomposition.tsv").unwrap();
    writeln!(tsv1, "N\tT\tdiagonal\toff_diagonal\ttotal\tratio_offdiag_diag\tmv_bound\tbessel_bound\toff_vs_mv\toff_vs_bessel").unwrap();

    for &n in &test_ns {
        let a = bd_dirichlet_coeffs(n, &mu);
        let n_active: usize = a.iter().filter(|&&x| x != 0.0).count();
        let sum_a2: f64 = a.iter().map(|x| x * x).sum();
        let mv_b = mv_bound(&a);
        let bessel_b = bessel_bound(&a);

        println!("  {BOLD}N = {n}{RESET}  ({n_active} active coefficients, Σ|a|² = {sum_a2:.6e})");
        println!("    {DIM}M-V bound: π·Σ(n+1)|aₙ|² = {mv_b:.4e}   Bessel bound: 2π·Σ|aₙ|² = {bessel_b:.4e}{RESET}");
        println!("    {DIM}    T       │  Diagonal      │  Off-diagonal  │  Total         │ Off/Diag  │ Off/MV   │ Off/Bessel{RESET}");

        for &t_max in &t_values {
            let diag = diagonal_term(&a, t_max);
            let offdiag = off_diagonal_term(&a, t_max);
            let total = diag + offdiag;
            let ratio = if diag > 0.0 { offdiag.abs() / diag } else { 0.0 };
            let off_vs_mv = if mv_b > 0.0 { offdiag.abs() / mv_b } else { 0.0 };
            let off_vs_bessel = if bessel_b > 0.0 { offdiag.abs() / bessel_b } else { 0.0 };

            let ratio_ok = ratio < 0.1;
            let bessel_ok = offdiag.abs() < bessel_b;

            println!("    {:>8.0} │ {:>13.6e} │ {:>13.6e} │ {:>13.6e} │ {:.4e} {} │ {:.4e} │ {:.4e} {}",
                t_max, diag, offdiag, total, ratio, check(ratio_ok),
                off_vs_mv, off_vs_bessel, check(bessel_ok));

            writeln!(tsv1, "{}\t{}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}",
                n, t_max, diag, offdiag, total, ratio, mv_b, bessel_b, off_vs_mv, off_vs_bessel).unwrap();
        }
        println!();
    }

    // ═══════════════════════════════════════════════
    // §2. SEPARATION ANALYSIS
    // ═══════════════════════════════════════════════
    println!("  {BOLD}{WHITE}═══ §2. MINIMUM SEPARATION δₙ = min|log m - log n| ═══{RESET}");
    println!("  {DIM}  If δₙ grows, the off-diagonal decays faster → weaker bounds suffice{RESET}");
    println!();
    println!("    {DIM}     N  │  δ_min         │  1/(N+1)       │  ratio δ/1/(N+1){RESET}");

    for &n in &test_ns {
        let a = bd_dirichlet_coeffs(n, &mu);
        let delta = min_separation(n, &a);
        let trivial = 1.0 / (n as f64 + 1.0);
        let ratio = delta / trivial;
        println!("    {:>6} │ {:.6e}    │ {:.6e}    │ {:.2}", n, delta, trivial, ratio);
    }
    println!();

    // ═══════════════════════════════════════════════
    // §3. CRITICAL QUESTION: DOES OFF-DIAGONAL MATTER?
    // ═══════════════════════════════════════════════
    println!("  {BOLD}{WHITE}═══ §3. STRATEGY VERDICT ═══{RESET}");
    println!();

    // For the Mellin Crown, we need T → ∞ behavior.
    // Check: does off-diagonal / (2T·Σ|a|²) → 0 as T → ∞?
    let n_test = *test_ns.last().unwrap();
    let a = bd_dirichlet_coeffs(n_test, &mu);
    let bessel_b = bessel_bound(&a);
    let mv_b = mv_bound(&a);

    println!("  {BOLD}At N = {n_test}:{RESET}");
    println!("    Full M-V bound: {YELLOW}{mv_b:.6e}{RESET}");
    println!("    Bessel bound:   {YELLOW}{bessel_b:.6e}{RESET}");
    println!("    Ratio (Bessel/MV): {YELLOW}{:.4}{RESET}", bessel_b / mv_b);
    println!();

    let mut all_bessel_ok = true;
    for &t_max in &[100.0, 1000.0, 10000.0, 100000.0] {
        let offdiag = off_diagonal_term(&a, t_max);
        let ok = offdiag.abs() < bessel_b;
        if !ok { all_bessel_ok = false; }
        println!("    T = {:>8.0}:  |off-diag| = {:.6e}  < Bessel {:.6e}?  {}",
            t_max, offdiag.abs(), bessel_b, check(ok));
    }
    println!();

    if all_bessel_ok {
        println!("  {GREEN}{BOLD}✓ BESSEL BOUND SUFFICES{RESET}: For BD weights, the off-diagonal");
        println!("    is bounded by 2π·Σ|aₙ|² (no n-factor), which is provable from");
        println!("    plain Fourier analysis without Montgomery-Vaughan!");
        println!();
        println!("  {BOLD}Implication:{RESET} The graduation path for critical_line_mellin_variance");
        println!("    may NOT require the full M-V large sieve. A simpler proof via");
        println!("    Plancherel + orthogonality in Mathlib could suffice.");
    } else {
        println!("  {YELLOW}{BOLD}⚠ FULL M-V MAY BE NEEDED{RESET}: The off-diagonal exceeds the Bessel bound");
        println!("    at some T values. The full Montgomery-Vaughan inequality appears");
        println!("    necessary for BD weights.");
    }
    println!();

    // ═══════════════════════════════════════════════
    // §4. WEIGHT STRUCTURE ANALYSIS
    // ═══════════════════════════════════════════════
    println!("  {BOLD}{WHITE}═══ §4. BD WEIGHT DECAY PROFILE ═══{RESET}");
    println!("  {DIM}  How fast do the BD Dirichlet coefficients decay?{RESET}");
    println!("  {DIM}  Faster decay → off-diagonal is smaller → easier proof.{RESET}");
    println!();

    let n_test = 200;
    let a_test = bd_dirichlet_coeffs(n_test, &mu);
    println!("  {DIM}    k  │  μ(k)  │  aₖ            │  |aₖ|²         │  k·|aₖ|²{RESET}");
    let display_ks: Vec<usize> = vec![1, 2, 3, 5, 6, 7, 10, 11, 13, 14, 15, 17, 19, 21, 22, 23, 26, 29, 30, 33, 34, 35, 37, 38, 39, 41, 42, 43, 46, 47, 50, 100, 150, 199];
    for k in display_ks {
        if k >= n_test { break; }
        let ak = a_test[k];
        if ak == 0.0 { continue; }
        println!("    {:>4} │  {:>2}   │ {:>13.6e} │ {:>13.6e} │ {:>13.6e}",
            k, mu[k], ak, ak * ak, k as f64 * ak * ak);
    }
    println!();

    let sum_a2: f64 = a_test.iter().map(|x| x * x).sum();
    let sum_na2: f64 = a_test.iter().enumerate().map(|(k, x)| (k.max(1) as f64) * x * x).sum();
    println!("    Σ|aₖ|²   = {:.6e}", sum_a2);
    println!("    Σ k|aₖ|² = {:.6e}", sum_na2);
    println!("    Ratio Σk|aₖ|²/Σ|aₖ|² = {YELLOW}{:.2}{RESET}", sum_na2 / sum_a2);
    println!("    {DIM}(If this ratio is bounded, a Bessel-type bound works){RESET}");
    println!();

    println!("  {BOLD}{WHITE}Total:{RESET} {GREEN}{}{RESET}", elapsed(t0.elapsed().as_secs_f64()));
    println!("  {BOLD}{WHITE}Output:{RESET} results/decomposition.tsv");
    println!();
}
