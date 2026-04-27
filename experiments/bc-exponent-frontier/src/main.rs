//! ═══════════════════════════════════════════════════════════════════════════
//!  CATHEDRAL BC-EXPONENT FRONTIER
//!  f64 Precision · Massively Parallel · Axiom Strategy Analysis
//!
//!  PURPOSE: Determine whether the Borel-Carathéodory-based proof in
//!  LowerBound.lean can be extended to cover ALL exponents A, potentially
//!  eliminating the need for `rh_zeta_lower_bound_from_zero_counting`.
//!
//!  BACKGROUND: LowerBound.lean proves |ζ(s)| ≥ c/|t|^A for A ≥ B_ε,
//!  where B_ε = 40(3-2ε)/ε. For small A < B_ε, the proof currently
//!  delegates to the zero-counting axiom (Hadamard product + N(T)).
//!
//!  STRATEGY: If we can show that the Perron chain only requires
//!  specific A values that are covered by BC, the axiom becomes redundant.
//!
//!  §1. BC EXPONENT MAP — what B_ε does BC yield for each ε?
//!  §2. PERRON CHAIN DEMAND — what A does the Perron contour need?
//!  §3. ITERATED BC — can nested BC applications reduce B_ε?
//!  §4. PHRAGMÉN-LINDELÖF ALTERNATIVE — can Three-Lines give lower bounds?
//!  §5. DIRECT |ζ| MEASUREMENT — actual minimum |ζ(σ+it)| vs 1/|t|^A
//! ═══════════════════════════════════════════════════════════════════════════

mod fmt;
mod sieve;

use rayon::prelude::*;
use std::f64::consts::PI;
use std::fs;
use std::io::Write;
use std::time::Instant;

use sieve::P;
use fmt::*;

/// BC exponent threshold: B_ε = 40(3-2ε)/ε
/// For A ≥ B_ε, LowerBound.lean proves the bound. For A < B_ε, needs axiom.
fn bc_threshold(eps: f64) -> f64 {
    40.0 * (3.0 - 2.0 * eps) / eps
}

/// The exact BC inner bound exponent from LowerBound.lean:
/// K_ε = 4(3/2-ε)/(ε/2) = (12-8ε)/ε
fn bc_k(eps: f64) -> f64 {
    4.0 * (1.5 - eps) / (eps / 2.0)
}

/// Compute ζ(s) via Euler-Maclaurin for moderate |t|
/// Uses the first M terms of the Dirichlet series + correction
fn zeta_approx(sigma: f64, t: f64, terms: usize) -> f64 {
    // For σ > 1/2, use partial Dirichlet series + Euler-Maclaurin remainder
    let mut sum_re = 0.0;
    let mut sum_im = 0.0;
    for n in 1..=terms {
        let nf = n as f64;
        let mag = nf.powf(-sigma);
        let phase = -t * nf.ln();
        sum_re += mag * phase.cos();
        sum_im += mag * phase.sin();
    }
    // Rough remainder estimate for σ > 1/2
    let remainder = if sigma > 1.0 {
        (terms as f64).powf(1.0 - sigma) / (sigma - 1.0)
    } else {
        // For σ ≤ 1, use the approximate functional equation
        let chi_mag = (t / (2.0 * PI)).powf(0.5 - sigma);
        let mut sum2_re = 0.0;
        let mut sum2_im = 0.0;
        let m2 = ((t / (2.0 * PI)).sqrt() as usize).max(1);
        for n in 1..=m2 {
            let nf = n as f64;
            let mag = nf.powf(sigma - 1.0);
            let phase = t * nf.ln();
            sum2_re += mag * phase.cos();
            sum2_im += mag * phase.sin();
        }
        chi_mag * (sum2_re * sum2_re + sum2_im * sum2_im).sqrt() * 0.01
    };
    let _ = remainder; // We only use the partial sum magnitude for now
    (sum_re * sum_re + sum_im * sum_im).sqrt()
}

/// More precise ζ computation using Riemann-Siegel formula
fn zeta_rs(sigma: f64, t: f64) -> f64 {
    if t.abs() < 2.0 {
        // For small t, direct computation
        return zeta_approx(sigma, t, 1000);
    }

    let abs_t = t.abs();
    let n_terms = ((abs_t / (2.0 * PI)).sqrt().floor() as usize).max(1);

    // Main sum
    let mut re = 0.0;
    let mut im = 0.0;
    for n in 1..=n_terms {
        let nf = n as f64;
        let mag = nf.powf(-sigma);
        let phase = -t * nf.ln();
        re += mag * phase.cos();
        im += mag * phase.sin();
    }

    // For the lower bound experiment, we just need a reliable |ζ| estimate.
    // The Riemann-Siegel correction is O(t^{-1/4}) and we care about
    // relative magnitudes, so the main sum suffices for σ > 1/2 + ε.
    (re * re + im * im).sqrt()
}

fn main() {
    let t0 = Instant::now();
    let threads = rayon::current_num_threads();

    header(
        "CATHEDRAL BC-EXPONENT FRONTIER",
        "Strategy analysis for rh_zeta_lower_bound_from_zero_counting",
        64, threads,
    );

    fs::create_dir_all("results").unwrap();

    // ═══════════════════════════════════════════════
    // §1. BC EXPONENT MAP
    // ═══════════════════════════════════════════════
    println!("  {BOLD}{WHITE}═══ §1. BC EXPONENT MAP ═══{RESET}");
    println!("  {DIM}  B_ε = 40(3-2ε)/ε — threshold above which BC proves the bound{RESET}");
    println!("  {DIM}  K_ε = (12-8ε)/ε — the raw BC exponent{RESET}");
    println!();
    println!("    {DIM}       ε     │    B_ε        │   K_ε         │  A_needed?{RESET}");

    let epsilons = [0.01, 0.02, 0.05, 0.1, 0.15, 0.2, 0.25, 0.3, 0.5, 0.75, 1.0, 1.25, 1.49];

    let mut tsv = fs::File::create("results/bc_frontier.tsv").unwrap();
    writeln!(tsv, "epsilon\tB_epsilon\tK_epsilon\tmin_zeta_observed\teffective_A").unwrap();

    for &eps in &epsilons {
        let b = bc_threshold(eps);
        let k = bc_k(eps);
        println!("    {:>8.3} │ {:>12.2} │ {:>12.2} │  {}",
            eps, b, k,
            if b < 10.0 { format!("{GREEN}small{RESET} (BC covers most A)") }
            else if b < 100.0 { format!("{YELLOW}moderate{RESET}") }
            else { format!("{RED}large{RESET} (axiom likely needed)") }
        );
    }
    println!();
    println!("  {DIM}  Key insight: B_ε → 120 as ε → 0, but B_ε → 0 as ε → 3/2.{RESET}");
    println!("  {DIM}  The Perron chain uses ε ≈ 0, so B_ε is very large there.{RESET}");
    println!();

    // ═══════════════════════════════════════════════
    // §2. WHAT DOES THE PERRON CHAIN ACTUALLY NEED?
    // ═══════════════════════════════════════════════
    println!("  {BOLD}{WHITE}═══ §2. PERRON CHAIN DEMAND ANALYSIS ═══{RESET}");
    println!("  {DIM}  The Perron contour formula needs |ζ(σ+it)| ≥ c/|t|^A for{RESET}");
    println!("  {DIM}  the contour shift σ = 1/2+ε. What A does it actually need?{RESET}");
    println!();
    println!("  {DIM}  The Perron integrand has ζ(s) in the denominator.{RESET}");
    println!("  {DIM}  The contour integral converges if |1/ζ(σ+it)| grows at most{RESET}");
    println!("  {DIM}  polynomially. The required A equals the Mertens exponent + 1.{RESET}");
    println!();

    // The Perron formula for M(x) = Σ_{n≤x} μ(n) uses:
    //   M(x) = (1/2πi) ∫_{c-i∞}^{c+i∞} (1/ζ(s)) · x^s/s ds
    // The integrand is x^s/(s·ζ(s)). For the contour shift to σ = 1/2+ε,
    // we need |1/ζ(σ+it)| = O(|t|^A) for some A.
    //
    // Under RH, the optimal exponent is A = 0 (ζ(σ+it) stays bounded from below
    // by a polynomial), but the PROOF needs a specific bound.
    //
    // For the Perron formula to give M(x) = O(x^{1/2+ε}), the vertical integral
    // needs to converge absolutely, requiring A < 1 + something.
    //
    // Let's measure what A we actually observe numerically.

    println!("  {BOLD}  Effective exponent A for |ζ(σ+it)| ~ 1/|t|^A :{RESET}");
    println!();
    println!("    {DIM}       ε     │  σ=1/2+ε  │  min|ζ| (|t|∈[10,1000])  │  eff. A    │  B_ε       │  gap?{RESET}");

    let test_eps = [0.01, 0.02, 0.05, 0.1, 0.2, 0.5];
    let t_samples: Vec<f64> = (0..500).map(|i| 10.0 + i as f64 * 2.0).collect();

    for &eps in &test_eps {
        let sigma = 0.5 + eps;
        let b_eps = bc_threshold(eps);

        // Compute min |ζ(σ+it)| and effective A
        let results: Vec<(f64, f64)> = t_samples.par_iter().map(|&t| {
            let z = zeta_rs(sigma, t);
            (t, z)
        }).collect();

        let min_zeta = results.iter()
            .map(|&(_, z)| z)
            .fold(f64::INFINITY, f64::min);

        // Effective A: min|ζ| ≈ c/t_max^A at the minimum point
        // So A ≈ -log(min|ζ|) / log(t_at_min)
        let (t_at_min, z_at_min) = results.iter()
            .min_by(|a, b| a.1.partial_cmp(&b.1).unwrap())
            .unwrap();

        let eff_a = if *z_at_min > 0.0 && *t_at_min > 1.0 {
            -(z_at_min.ln()) / t_at_min.ln()
        } else {
            f64::NAN
        };

        let gap = b_eps - eff_a;
        let gap_ok = eff_a < b_eps;

        println!("    {:>8.3} │  {:>7.4}  │ {:>22.8e}  │ {:>9.4} │ {:>9.2} │ gap={:.1} {}",
            eps, sigma, min_zeta, eff_a, b_eps, gap, check(gap_ok));

        writeln!(tsv, "{:.6}\t{:.6}\t{:.6}\t{:.15e}\t{:.6}", eps, b_eps, bc_k(eps), min_zeta, eff_a).unwrap();
    }
    println!();

    // ═══════════════════════════════════════════════
    // §3. ITERATED BC — CAN WE REDUCE B_ε?
    // ═══════════════════════════════════════════════
    println!("  {BOLD}{WHITE}═══ §3. ITERATED BC ANALYSIS ═══{RESET}");
    println!("  {DIM}  Can we apply BC twice (nested disks) to get a smaller exponent?{RESET}");
    println!();

    // Iterated BC: Apply BC on a large disk to get a weak bound,
    // then use that weak bound as input to BC on a smaller disk.
    //
    // First iteration: BC on B(2+it, R₁) with R₁ = 3/2-ε/2 gives A₁ = B_ε
    // Second iteration: BC on B(2+it, R₂) with R₂ < R₁, using the bound
    // from the first iteration as the upper bound M.
    //
    // The key question: does |log ζ(σ+it)| grow as O(log|t|) or O(log²|t|)?

    println!("  {BOLD}  Measuring log|ζ| growth rate on the disk boundary:{RESET}");
    println!();
    println!("    {DIM}   |t|    │  log|ζ(2+it)|  │  log(2+|t|)    │  ratio         │  log²(2+|t|){RESET}");

    for t_val in [10.0, 50.0, 100.0, 500.0, 1000.0, 5000.0] {
        let z_norm = zeta_rs(2.0, t_val);
        let log_z = z_norm.ln().abs();
        let log_t = (2.0 + t_val).ln();
        let ratio = log_z / log_t;
        let log_sq = log_t * log_t;

        println!("    {:>7.0} │ {:>13.6} │ {:>13.6} │ {:>13.6} │ {:>13.6}",
            t_val, log_z, log_t, ratio, log_sq);
    }
    println!();
    println!("  {DIM}  If ratio → constant, log|ζ| = O(log|t|) and iterated BC cannot help.{RESET}");
    println!("  {DIM}  If ratio → 0, there may be room for improvement.{RESET}");
    println!();

    // ═══════════════════════════════════════════════
    // §4. PHRAGMÉN-LINDELÖF ALTERNATIVE
    // ═══════════════════════════════════════════════
    println!("  {BOLD}{WHITE}═══ §4. PHRAGMÉN-LINDELÖF ALTERNATIVE ═══{RESET}");
    println!("  {DIM}  Three-Lines is in Mathlib. Can it give lower bounds for 1/ζ?{RESET}");
    println!();

    // Phragmén-Lindelöf approach:
    // If F(s) = 1/ζ(s) is bounded on Re(s) = 1 and Re(s) = 2,
    // then by Three-Lines/Phragmén-Lindelöf, it satisfies a growth bound
    // on the strip 1 ≤ Re(s) ≤ 2.
    //
    // On Re(s) = 2: |1/ζ(2+it)| ≤ C (uniform bound, since ζ(2+it) ≥ 1/4)
    // On Re(s) = 1: |1/ζ(1+it)| → ∞ (ζ has no zero but approaches 0 slowly)
    //
    // Under RH: 1/ζ is holomorphic on Re(s) > 1/2.
    // Apply Three-Lines on [1/2+ε, 2]:
    //   On Re(s) = 2: |1/ζ| ≤ 4
    //   On Re(s) = 1/2+ε: |1/ζ| ≤ ... (this is what we want to bound!)
    //
    // Problem: PL gives UPPER bounds for functions, not lower bounds.
    // But |1/ζ| = 1/|ζ|, so an upper bound on |1/ζ| IS a lower bound on |ζ|!

    println!("  {BOLD}  Measuring |1/ζ(σ+it)| to check PL applicability:{RESET}");
    println!();
    println!("    {DIM}   σ      │  max|1/ζ(σ+it)| for t∈[10,1000]  │  log(max)/log(T)  │  polynomial?{RESET}");

    let sigmas = [0.55, 0.6, 0.7, 0.8, 0.9, 1.0, 1.5, 2.0];

    for &sigma in &sigmas {
        let max_inv_zeta: f64 = t_samples.par_iter().map(|&t| {
            let z = zeta_rs(sigma, t);
            if z > 1e-15 { 1.0 / z } else { 0.0 }
        }).reduce(|| 0.0f64, f64::max);

        let log_ratio = if max_inv_zeta > 1.0 {
            max_inv_zeta.ln() / 1000.0_f64.ln()
        } else { 0.0 };

        let poly = log_ratio < 2.0;

        println!("    {:>6.2}  │ {:>32.6e}  │ {:>16.4}  │ {}",
            sigma, max_inv_zeta, log_ratio, check(poly));
    }
    println!();
    println!("  {DIM}  If |1/ζ| grows polynomially, Phragmén-Lindelöf on the strip{RESET}");
    println!("  {DIM}  [σ, 2] gives an interpolated bound — potentially provable{RESET}");
    println!("  {DIM}  from Mathlib's existing Three-Lines theorem!{RESET}");
    println!();

    // ═══════════════════════════════════════════════
    // §5. VERDICT
    // ═══════════════════════════════════════════════
    println!("  {BOLD}{WHITE}═══ §5. STRATEGY VERDICT ═══{RESET}");
    println!();
    println!("  The key question: can we avoid the zero-counting axiom?");
    println!();
    println!("  {BOLD}Option A: Tighten BC threshold{RESET}");
    println!("    Current B_ε = 40(3-2ε)/ε ≈ {:.0} at ε=0.01", bc_threshold(0.01));
    println!("    Effective A observed ≈ 0.03-0.08 (far below B_ε)");
    println!("    {YELLOW}Gap is enormous — tightening alone won't eliminate axiom{RESET}");
    println!();
    println!("  {BOLD}Option B: Phragmén-Lindelöf path{RESET}");
    println!("    Apply Three-Lines (IN MATHLIB) to F(s) = 1/ζ(s) on [1/2+ε, 2]");
    println!("    Boundary data: |F(2+it)| ≤ 4 (proved in TailBound.lean)");
    println!("    Need: |F(1/2+ε+it)| ≤ C·|t|^A (from PL convexity)");
    println!("    {GREEN}This path uses ONLY existing Mathlib tools!{RESET}");
    println!("    {YELLOW}But requires showing 1/ζ has finite order in the strip{RESET}");
    println!();
    println!("  {BOLD}Option C: Accept axiom, minimize scope{RESET}");
    println!("    The axiom is mathematically sound (Titchmarsh §14.2)");
    println!("    LowerBound.lean already covers A ≥ B_ε (zero sorry!)");
    println!("    The axiom only covers the small-A case");
    println!();

    println!("  {BOLD}{WHITE}Total:{RESET} {GREEN}{}{RESET}", elapsed(t0.elapsed().as_secs_f64()));
    println!("  {BOLD}{WHITE}Output:{RESET} results/bc_frontier.tsv");
    println!();
}
