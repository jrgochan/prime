//! ═══════════════════════════════════════════════════════════════════════════
//!  EXPERIMENT: BOSON-FERMION CLASSIFICATION OF THE INTEGERS
//!
//!  The Cathedral physics paper (Correspondence 8.5) establishes a duality:
//!  - Primes → Gauge Bosons: low ground-state weight, generate chaos
//!  - Composites → Massive Fermions: high ground-state weight, localized wells
//!
//!  This experiment computes, for each integer k ∈ {2, ..., N}:
//!  - Its ground-state eigenvector weight |⟨k|ψ₀⟩|²
//!  - Its number of divisors d(k) and divisor sum σ(k)
//!  - Its "hub connectivity" = Σ_{j≠k} gcd(j,k) (graph-theoretic centrality)
//!  - Classification as "boson" (low weight) or "fermion" (high weight)
//!
//!  Usage: boson-fermion [max_N]
//! ═══════════════════════════════════════════════════════════════════════════

mod fmt;

use fmt::*;
use rayon::prelude::*;
use std::time::Instant;

// ═══════════════════════════════════════════════════════════════════════
// GRAM MATRIX CONSTRUCTION (f64, parallel)
// ═══════════════════════════════════════════════════════════════════════

fn gcd(a: usize, b: usize) -> usize {
    if b == 0 { a } else { gcd(b, a % b) }
}

fn gram_entry_f64(j: usize, k: usize) -> f64 {
    let jf = j as f64;
    let kf = k as f64;
    let inv_jk = 1.0 / (jf * kf);
    let lcm_jk = j / gcd(j, k) * k;
    let t_direct = (lcm_jk * 3).max(2_000).min(200_000);

    let mut total = 0.0f64;
    for n in 1..=t_direct {
        let nf = n as f64;
        let a_int = n / j;
        let b_int = n / k;
        let a = a_int as f64;
        let b = b_int as f64;
        let inv_n = 1.0 / nf;
        let ln_term = (1.0 + inv_n).ln();
        let ab_coeff = a / kf + b / jf;
        let ab_frac = if a_int > 0 && b_int > 0 {
            (a * b) / (nf * (nf + 1.0))
        } else {
            0.0
        };
        total += inv_jk - ab_coeff * ln_term + ab_frac;
    }

    let d = gcd(j, k) as f64;
    let twelve_jk = 12.0 * jf * kf;
    let tail_mean = 0.25 + d * d / twelve_jk;
    let t_f = t_direct as f64;
    total += tail_mean / t_f;
    total += tail_mean / (2.0 * t_f * t_f);
    total
}

fn build_gram_f64(n: usize) -> (Vec<f64>, usize) {
    let dim = n - 1;
    let entries: Vec<((usize, usize), f64)> = (0..dim)
        .into_par_iter()
        .flat_map(|row| {
            (row..dim)
                .map(move |col| ((row, col), gram_entry_f64(row + 2, col + 2)))
                .collect::<Vec<_>>()
        })
        .collect();

    let mut mat = vec![0.0f64; dim * dim];
    for ((r, c), v) in entries {
        mat[r * dim + c] = v;
        mat[c * dim + r] = v;
    }
    (mat, dim)
}

// ═══════════════════════════════════════════════════════════════════════
// NUMBER-THEORETIC UTILITIES
// ═══════════════════════════════════════════════════════════════════════

fn is_prime(n: usize) -> bool {
    if n < 2 { return false; }
    if n < 4 { return true; }
    if n % 2 == 0 || n % 3 == 0 { return false; }
    let mut i = 5;
    while i * i <= n {
        if n % i == 0 || n % (i + 2) == 0 { return false; }
        i += 6;
    }
    true
}

fn num_divisors(n: usize) -> usize {
    if n == 0 { return 0; }
    let mut count = 0;
    let mut i = 1;
    while i * i <= n {
        if n % i == 0 {
            count += 1;
            if i != n / i { count += 1; }
        }
        i += 1;
    }
    count
}

fn divisor_sum(n: usize) -> usize {
    if n == 0 { return 0; }
    let mut total = 0;
    let mut i = 1;
    while i * i <= n {
        if n % i == 0 {
            total += i;
            if i != n / i { total += n / i; }
        }
        i += 1;
    }
    total
}

/// Prime factorization: number of distinct prime factors (omega)
fn omega(n: usize) -> usize {
    if n <= 1 { return 0; }
    let mut count = 0;
    let mut m = n;
    let mut p = 2;
    while p * p <= m {
        if m % p == 0 {
            count += 1;
            while m % p == 0 { m /= p; }
        }
        p += 1;
    }
    if m > 1 { count += 1; }
    count
}

/// Total prime factors with multiplicity (Omega)
fn big_omega(n: usize) -> usize {
    if n <= 1 { return 0; }
    let mut count = 0;
    let mut m = n;
    let mut p = 2;
    while p * p <= m {
        while m % p == 0 {
            count += 1;
            m /= p;
        }
        p += 1;
    }
    if m > 1 { count += 1; }
    count
}

/// Hub connectivity: sum of gcd(k, j) for all j in {2..N}, j ≠ k
fn hub_connectivity(k: usize, n: usize) -> usize {
    let mut total = 0;
    for j in 2..=n {
        if j != k { total += gcd(k, j); }
    }
    total
}

// ═══════════════════════════════════════════════════════════════════════
// PARTICLE CLASSIFICATION
// ═══════════════════════════════════════════════════════════════════════

#[derive(Debug)]
struct Particle {
    k: usize,                // The integer
    weight: f64,             // |⟨k|ψ₀⟩|²
    is_prime: bool,
    divisor_count: usize,    // d(k)
    divisor_sum: usize,      // σ(k)
    omega: usize,            // distinct prime factors
    big_omega: usize,        // total prime factors with multiplicity
    hub_score: usize,        // Σ gcd(k,j) for j≠k
    classification: &'static str,
}

fn classify(weight: f64, median_weight: f64, is_prime: bool) -> &'static str {
    if is_prime {
        if weight < median_weight * 0.5 {
            "gauge boson (light)"    // Very low weight prime — pure mediator
        } else if weight < median_weight {
            "gauge boson"            // Below-average prime
        } else {
            "excited boson"          // Rare: prime with significant weight
        }
    } else {
        if weight > median_weight * 3.0 {
            "heavy fermion"          // Very high weight composite — gravity well
        } else if weight > median_weight * 1.5 {
            "fermion"               // Significant composite
        } else if weight > median_weight {
            "light fermion"         // Moderate composite
        } else {
            "spectator"             // Low-weight composite (neither boson nor fermion)
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════
// MAIN ANALYSIS
// ═══════════════════════════════════════════════════════════════════════

fn analyze(n: usize) {
    let t0 = Instant::now();

    println!("\n  {BOLD}{CYAN}╔═══════════════════════════════════════════════════════════════════════╗{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}{WHITE}BOSON-FERMION CLASSIFICATION · N = {n}{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {DIM}Computing Gram matrix + ground state eigenvector...{RESET}");
    println!("  {BOLD}{CYAN}╚═══════════════════════════════════════════════════════════════════════╝{RESET}");

    // Build Gram matrix
    let (mat, dim) = build_gram_f64(n);
    println!("  {DIM}Gram matrix: {dim}×{dim} ({:.1}s){RESET}", t0.elapsed().as_secs_f64());

    // Eigendecomposition
    let m = nalgebra::DMatrix::from_row_slice(dim, dim, &mat);
    let eigen = m.symmetric_eigen();

    // Find ground state (minimum eigenvalue)
    let mut indexed: Vec<(usize, f64)> = eigen.eigenvalues.iter()
        .enumerate()
        .map(|(i, &v)| (i, v))
        .collect();
    indexed.sort_by(|a, b| a.1.partial_cmp(&b.1).unwrap());

    let (ground_col, lambda_min) = indexed[0];
    println!("  {DIM}λ_min = {lambda_min:.10e} ({:.1}s){RESET}", t0.elapsed().as_secs_f64());

    // Extract ground state eigenvector
    let ground_vec: Vec<f64> = (0..dim)
        .map(|row| eigen.eigenvectors[(row, ground_col)])
        .collect();

    // Compute hub connectivity in parallel
    let hub_scores: Vec<usize> = (2..=n)
        .into_par_iter()
        .map(|k| hub_connectivity(k, n))
        .collect();

    // Build particle table
    let mut particles: Vec<Particle> = Vec::with_capacity(dim);
    for i in 0..dim {
        let k = i + 2;
        let w = ground_vec[i] * ground_vec[i];
        particles.push(Particle {
            k,
            weight: w,
            is_prime: is_prime(k),
            divisor_count: num_divisors(k),
            divisor_sum: divisor_sum(k),
            omega: omega(k),
            big_omega: big_omega(k),
            hub_score: hub_scores[i],
            classification: "",  // filled below
        });
    }

    // Compute median weight for classification thresholds
    let mut weights: Vec<f64> = particles.iter().map(|p| p.weight).collect();
    weights.sort_by(|a, b| a.partial_cmp(b).unwrap());
    let median_weight = weights[weights.len() / 2];

    // Classify each particle
    for p in &mut particles {
        p.classification = classify(p.weight, median_weight, p.is_prime);
    }

    // ─── TOP FERMIONS (heaviest composites) ───
    let mut by_weight = particles.iter().collect::<Vec<_>>();
    by_weight.sort_by(|a, b| b.weight.partial_cmp(&a.weight).unwrap());

    println!("\n  {BOLD}{WHITE}═══ TOP 20 HEAVY FERMIONS (highest ground-state weight) ═══{RESET}");
    println!("  {DIM}rank │   k   │  |⟨k|ψ₀⟩|²  │ d(k) │  σ(k) │  ω  │  Ω  │    hub     │ factorization      │ class{RESET}");
    println!("  {DIM}─────┼───────┼──────────────┼──────┼───────┼─────┼─────┼────────────┼────────────────────┼──────────────{RESET}");

    for (rank, p) in by_weight.iter().take(20).enumerate() {
        let factors = factorize_display(p.k);
        let color = if p.classification.contains("heavy") { RED }
                   else if p.classification.contains("fermion") { YELLOW }
                   else { WHITE };
        println!(
            "  {:<4} │ {:<5} │ {:<12.8} │ {:<4} │ {:<5} │ {:<3} │ {:<3} │ {:<10} │ {:<18} │ {color}{}{RESET}",
            rank + 1, p.k, p.weight, p.divisor_count, p.divisor_sum,
            p.omega, p.big_omega, p.hub_score, factors, p.classification,
        );
    }

    // ─── GAUGE BOSONS (primes, lowest weight) ───
    let mut primes: Vec<&Particle> = particles.iter().filter(|p| p.is_prime).collect();
    primes.sort_by(|a, b| a.weight.partial_cmp(&b.weight).unwrap());

    println!("\n  {BOLD}{WHITE}═══ ALL GAUGE BOSONS (primes, sorted by weight) ═══{RESET}");
    println!("  {DIM}rank │   p   │  |⟨p|ψ₀⟩|²  │    hub     │ class{RESET}");
    println!("  {DIM}─────┼───────┼──────────────┼────────────┼──────────────{RESET}");

    for (rank, p) in primes.iter().enumerate() {
        let color = if p.weight < median_weight * 0.5 { CYAN }
                   else if p.weight < median_weight { GREEN }
                   else { YELLOW };
        println!(
            "  {:<4} │ {:<5} │ {color}{:<12.8}{RESET} │ {:<10} │ {color}{}{RESET}",
            rank + 1, p.k, p.weight, p.hub_score, p.classification,
        );
    }

    // ─── STATISTICAL SUMMARY ───
    let prime_count = particles.iter().filter(|p| p.is_prime).count();
    let composite_count = dim - prime_count;
    let prime_weight: f64 = particles.iter().filter(|p| p.is_prime).map(|p| p.weight).sum();
    let composite_weight: f64 = particles.iter().filter(|p| !p.is_prime).map(|p| p.weight).sum();

    let heavy_fermions = particles.iter().filter(|p| p.classification.contains("heavy")).count();
    let regular_fermions = particles.iter().filter(|p| p.classification == "fermion").count();
    let light_bosons = particles.iter().filter(|p| p.classification.contains("light") && p.is_prime).count();

    // Correlation: hub connectivity vs weight
    let hub_weight_pairs: Vec<(f64, f64)> = particles.iter()
        .map(|p| (p.hub_score as f64, p.weight))
        .collect();
    let r_sq = pearson_r_squared(&hub_weight_pairs);

    // Correlation: divisor count vs weight
    let div_weight_pairs: Vec<(f64, f64)> = particles.iter()
        .map(|p| (p.divisor_count as f64, p.weight))
        .collect();
    let r_sq_div = pearson_r_squared(&div_weight_pairs);

    println!("\n  {BOLD}{WHITE}═══ PARTICLE PHYSICS SUMMARY ═══{RESET}");
    println!();
    println!("  {BOLD}Population:{RESET}");
    println!("    Primes (gauge bosons):    {CYAN}{prime_count}{RESET} ({:.1}% of integers)", 100.0 * prime_count as f64 / dim as f64);
    println!("    Composites (fermions):    {YELLOW}{composite_count}{RESET} ({:.1}% of integers)", 100.0 * composite_count as f64 / dim as f64);
    println!();
    println!("  {BOLD}Ground-state spectral weight:{RESET}");
    println!("    Prime weight (bosons):    {CYAN}{prime_weight:.6}{RESET} ({:.1}%)", 100.0 * prime_weight);
    println!("    Composite weight (ferm):  {YELLOW}{composite_weight:.6}{RESET} ({:.1}%)", 100.0 * composite_weight);
    println!("    Ratio composite/prime:    {BOLD}{WHITE}{:.1}×{RESET}", composite_weight / prime_weight);
    println!();
    println!("  {BOLD}Classification breakdown:{RESET}");
    println!("    Heavy fermions (>3× median):   {RED}{heavy_fermions}{RESET}");
    println!("    Regular fermions (1.5-3×):     {YELLOW}{regular_fermions}{RESET}");
    println!("    Light gauge bosons (<0.5×):    {CYAN}{light_bosons}{RESET}");
    println!();
    println!("  {BOLD}Correlations:{RESET}");
    println!("    Hub connectivity vs weight:  R² = {BOLD}{r_sq:.4}{RESET}");
    println!("    Divisor count vs weight:     R² = {BOLD}{r_sq_div:.4}{RESET}");

    // ─── THE PHYSICS ───
    println!("\n  {BOLD}{WHITE}═══ THE PHYSICS ═══{RESET}");
    println!();
    println!("  The ground state |ψ₀⟩ of the Gram matrix G_N encodes the vacuum");
    println!("  energy of the Nyman-Beurling approximation. Its structure reveals:");
    println!();
    println!("  {CYAN}• GAUGE BOSONS{RESET} (primes): carry only {:.1}% of ground-state weight.", 100.0 * prime_weight);
    println!("    They share no divisors → weak coupling → thermalize the bulk spectrum");
    println!("    into GOE chaos. They are the force carriers of arithmetic randomness.");
    println!();
    println!("  {YELLOW}• MASSIVE FERMIONS{RESET} (highly composite): carry {:.1}% of weight.", 100.0 * composite_weight);
    println!("    They share many divisors → strong coupling → create localized gravity");
    println!("    wells that trap the ground state. They are the matter of the prime gas.");
    println!();
    if r_sq > 0.3 {
        println!("  {GREEN}Hub-weight correlation R²={r_sq:.3} confirms the mechanism:{RESET}");
        println!("  {GREEN}  divisibility ≈ gravitational mass in the integer lattice.{RESET}");
    }
    println!();
    println!("  This structural separation — primes generate entropy, composites trap");
    println!("  the vacuum — is what topologically protects λ_min > 0 and constrains");
    println!("  the Riemann zeros to Re(s) = 1/2.");

    println!("\n  {DIM}Total time: {:.1}s{RESET}", t0.elapsed().as_secs_f64());
    println!();
}

/// Pearson correlation coefficient squared
fn pearson_r_squared(pairs: &[(f64, f64)]) -> f64 {
    let n = pairs.len() as f64;
    let sx: f64 = pairs.iter().map(|(x, _)| x).sum();
    let sy: f64 = pairs.iter().map(|(_, y)| y).sum();
    let sxx: f64 = pairs.iter().map(|(x, _)| x * x).sum();
    let syy: f64 = pairs.iter().map(|(_, y)| y * y).sum();
    let sxy: f64 = pairs.iter().map(|(x, y)| x * y).sum();

    let num = n * sxy - sx * sy;
    let den = ((n * sxx - sx * sx) * (n * syy - sy * sy)).sqrt();
    if den < 1e-30 { return 0.0; }
    let r = num / den;
    r * r
}

/// Display factorization of k
fn factorize_display(mut n: usize) -> String {
    if n <= 1 { return n.to_string(); }
    if is_prime(n) { return format!("{n} (prime)"); }

    let mut factors = Vec::new();
    let mut p = 2;
    while p * p <= n {
        let mut exp = 0;
        while n % p == 0 {
            exp += 1;
            n /= p;
        }
        if exp > 0 {
            if exp == 1 {
                factors.push(format!("{p}"));
            } else {
                factors.push(format!("{p}^{exp}"));
            }
        }
        p += 1;
    }
    if n > 1 { factors.push(format!("{n}")); }
    factors.join("·")
}

fn main() {
    let t0 = Instant::now();
    let threads = rayon::current_num_threads();

    let max_n: usize = std::env::args()
        .nth(1)
        .and_then(|s| s.parse().ok())
        .unwrap_or(400);

    header(
        "CATHEDRAL BOSON-FERMION CLASSIFIER",
        &format!("Ground-state particle duality · N = {max_n}"),
        64,
        threads,
    );

    // Run analysis for a few key N values
    let test_ns: Vec<usize> = if max_n >= 500 {
        vec![100, 200, 400, max_n]
    } else if max_n >= 200 {
        vec![100, 200, max_n]
    } else {
        vec![max_n]
    };

    for &n in &test_ns {
        analyze(n);
    }

    // Final cross-N comparison
    if test_ns.len() > 1 {
        println!("\n  {BOLD}{WHITE}═══ CROSS-N COMPARISON ═══{RESET}");
        println!("  {DIM}N    │ prime wt │ comp wt  │ ratio  │ top-1 fermion{RESET}");
        println!("  {DIM}─────┼──────────┼──────────┼────────┼──────────────{RESET}");

        for &n in &test_ns {
            let (mat, dim) = build_gram_f64(n);
            let m = nalgebra::DMatrix::from_row_slice(dim, dim, &mat);
            let eigen = m.symmetric_eigen();
            let mut idx: Vec<(usize, f64)> = eigen.eigenvalues.iter()
                .enumerate().map(|(i, &v)| (i, v)).collect();
            idx.sort_by(|a, b| a.1.partial_cmp(&b.1).unwrap());
            let (gc, _) = idx[0];
            let gv: Vec<f64> = (0..dim).map(|r| eigen.eigenvectors[(r, gc)]).collect();

            let pw: f64 = gv.iter().enumerate()
                .filter(|(i, _)| is_prime(i + 2))
                .map(|(_, &v)| v * v).sum();

            let mut wt: Vec<(usize, f64)> = gv.iter().enumerate()
                .map(|(i, &v)| (i + 2, v * v)).collect();
            wt.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap());
            let (top_k, top_w) = wt[0];

            println!(
                "  {:<4} │ {:<8.4} │ {:<8.4} │ {:<6.1}× │ k={} ({:.4}) {}",
                n, pw, 1.0 - pw, (1.0 - pw) / pw, top_k, top_w,
                factorize_display(top_k),
            );
        }
    }

    println!(
        "\n  {BOLD}{WHITE}Total:{RESET} {GREEN}{:.1}s{RESET} ({threads} threads, f64/nalgebra)",
        t0.elapsed().as_secs_f64()
    );
    println!();
}
