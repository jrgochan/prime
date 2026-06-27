//! # S-Duality Mass Inversion Experiment
//!
//! Numerically explores the S-Duality between the positive (Möbius) sector
//! and the dark (Jordan/GCD) sector of the Cathedral.
//!
//! **Core hypothesis**: Primes and Highly Composite Numbers swap their physical
//! roles across the S-Duality mirror:
//!
//! - **Positive sector (Möbius)**: Primes are LOUD (|μ(p)| = 1), HCNs are SILENT (μ = 0)
//! - **Dark sector (Jordan)**: Primes are QUIET (weak gcd coupling), HCNs are MASSIVE (huge gcd⁴)
//!
//! We compute "energy profiles" for each number in both sectors and verify
//! this inversion numerically.

use std::collections::HashMap;

/// Compute the Möbius function μ(n) via trial division.
fn moebius(n: u64) -> i64 {
    if n == 1 {
        return 1;
    }
    let mut m = n;
    let mut num_factors = 0;

    // Trial division
    let mut p = 2u64;
    while p * p <= m {
        if m.is_multiple_of(p) {
            m /= p;
            num_factors += 1;
            if m.is_multiple_of(p) {
                // p² divides n → μ(n) = 0
                return 0;
            }
        }
        p += 1;
    }
    if m > 1 {
        num_factors += 1;
    }

    if num_factors % 2 == 0 { 1 } else { -1 }
}

/// Check if n is prime.
fn is_prime(n: u64) -> bool {
    if n < 2 { return false; }
    if n < 4 { return true; }
    if n.is_multiple_of(2) || n.is_multiple_of(3) { return false; }
    let mut i = 5;
    while i * i <= n {
        if n.is_multiple_of(i) || n.is_multiple_of(i + 2) { return false; }
        i += 6;
    }
    true
}

/// Count the number of divisors of n.
fn num_divisors(n: u64) -> u64 {
    let mut count = 0;
    let mut i = 1;
    while i * i <= n {
        if n.is_multiple_of(i) {
            count += 1;
            if i != n / i {
                count += 1;
            }
        }
        i += 1;
    }
    count
}

/// Find highly composite numbers up to limit.
/// A number n is highly composite if d(n) > d(m) for all m < n.
fn find_hcn(limit: u64) -> Vec<u64> {
    let mut hcns = vec![];
    let mut max_divisors = 0;
    for n in 1..=limit {
        let d = num_divisors(n);
        if d > max_divisors {
            max_divisors = d;
            hcns.push(n);
        }
    }
    hcns
}

/// Compute the "dark sector row energy" for number j:
///   E_dark(j) = Σ_{k=2..N} gcd(j,k)⁴ / (j² · k²)
///
/// This measures how strongly j couples to all other modes in the dark Gram matrix.
fn dark_energy(j: u64, n_max: u64) -> f64 {
    let j_sq = (j as f64) * (j as f64);
    let mut energy = 0.0;
    for k in 2..=n_max {
        let g = gcd(j, k) as f64;
        let k_sq = (k as f64) * (k as f64);
        energy += g.powi(4) / (j_sq * k_sq);
    }
    energy
}

/// Compute the "positive sector Möbius energy" for number j:
///   E_pos(j) = |μ(j)|²
///
/// This is 1 if j is squarefree, 0 if j has a squared prime factor.
fn positive_energy(j: u64) -> f64 {
    let mu = moebius(j);
    (mu * mu) as f64
}

/// Compute the "Möbius row coupling" — how much j couples to others via Möbius:
///   C_pos(j) = Σ_{k=2..N} |μ(gcd(j,k))| / N
///
/// Primes have gcd(p,k)=1 for most k → high Möbius coupling.
/// HCNs have gcd(hcn,k)>1 for many k → μ often 0 → low coupling.
fn positive_coupling(j: u64, n_max: u64) -> f64 {
    let mut coupling = 0.0;
    for k in 2..=n_max {
        let g = gcd(j, k);
        coupling += (moebius(g).abs()) as f64;
    }
    coupling / (n_max as f64)
}

/// Jordan's totient J₄(n) = n⁴ · ∏_{p|n} (1 - 1/p⁴)
fn jordan_totient4(n: u64) -> f64 {
    if n == 0 { return 0.0; }
    let n4 = (n as f64).powi(4);
    let mut product = 1.0;
    let mut m = n;
    let mut p = 2u64;
    while p * p <= m {
        if m.is_multiple_of(p) {
            product *= 1.0 - 1.0 / (p as f64).powi(4);
            while m.is_multiple_of(p) {
                m /= p;
            }
        }
        p += 1;
    }
    if m > 1 {
        product *= 1.0 - 1.0 / (m as f64).powi(4);
    }
    n4 * product
}

fn gcd(a: u64, b: u64) -> u64 {
    if b == 0 { a } else { gcd(b, a % b) }
}

/// Classify a number for reporting.
fn classify(n: u64, hcn_set: &HashMap<u64, bool>) -> &'static str {
    if is_prime(n) {
        "PRIME"
    } else if hcn_set.contains_key(&n) {
        "HCN"
    } else {
        "composite"
    }
}

fn main() {
    let n_max: u64 = 500;

    println!("╔══════════════════════════════════════════════════════════════════╗");
    println!("║         S-DUALITY MASS INVERSION EXPERIMENT                    ║");
    println!("║         The Mirror Universe Energy Census                       ║");
    println!("║         N = {}                                                ║", n_max);
    println!("╚══════════════════════════════════════════════════════════════════╝");
    println!();

    // Find HCNs
    let hcns = find_hcn(n_max);
    let hcn_set: HashMap<u64, bool> = hcns.iter().map(|&h| (h, true)).collect();

    println!("═══ Highly Composite Numbers up to {} ═══", n_max);
    print!("  ");
    for &h in &hcns {
        print!("{} ", h);
    }
    println!("\n");

    // ═══════════════════════════════════════════════════
    // SECTION 1: Individual energy profiles
    // ═══════════════════════════════════════════════════
    println!("═══ SECTION 1: Individual Energy Profiles ═══");
    println!("{:>6} {:>10} {:>8} {:>12} {:>12} {:>12}",
        "n", "class", "|μ(n)|²", "E_dark(n)", "J₄(n)", "μ-coupling");
    println!("{}", "─".repeat(68));

    // Track aggregates
    let mut prime_dark_total = 0.0;
    let mut prime_pos_total = 0.0;
    let mut prime_coupling_total = 0.0;
    let mut prime_j4_total = 0.0;
    let mut prime_count = 0u64;

    let mut hcn_dark_total = 0.0;
    let mut hcn_pos_total = 0.0;
    let mut hcn_coupling_total = 0.0;
    let mut hcn_j4_total = 0.0;
    let mut hcn_count = 0u64;

    let mut comp_dark_total = 0.0;
    let mut comp_pos_total = 0.0;
    let mut comp_coupling_total = 0.0;
    let mut comp_j4_total = 0.0;
    let mut comp_count = 0u64;

    // Show detailed profiles for select numbers
    let mut show_numbers: Vec<u64> = vec![];
    // First 10 primes in range
    let primes: Vec<u64> = (2..=n_max).filter(|&n| is_prime(n)).collect();
    show_numbers.extend(&primes[..primes.len().min(8)]);
    // All HCNs
    show_numbers.extend(&hcns);
    // Some composites
    for &c in &[4, 6, 12, 30, 100, 210, 360] {
        if c <= n_max && !is_prime(c) && !hcn_set.contains_key(&c) {
            show_numbers.push(c);
        }
    }
    show_numbers.sort();
    show_numbers.dedup();

    for &n in &show_numbers {
        let class = classify(n, &hcn_set);
        let pos_e = positive_energy(n);
        let dark_e = dark_energy(n, n_max);
        let j4 = jordan_totient4(n);
        let pos_c = positive_coupling(n, n_max);

        let class_marker = match class {
            "PRIME" => "⚡",
            "HCN" => "🌀",
            _ => "  ",
        };

        println!("{:>6} {:>10} {:>8.0} {:>12.4} {:>12.1} {:>10.4}  {}",
            n, class, pos_e, dark_e, j4, pos_c, class_marker);
    }

    // Compute aggregates for ALL numbers
    for n in 2..=n_max {
        let pos_e = positive_energy(n);
        let dark_e = dark_energy(n, n_max);
        let j4 = jordan_totient4(n);
        let pos_c = positive_coupling(n, n_max);

        if is_prime(n) {
            prime_pos_total += pos_e;
            prime_dark_total += dark_e;
            prime_j4_total += j4;
            prime_coupling_total += pos_c;
            prime_count += 1;
        } else if hcn_set.contains_key(&n) {
            hcn_pos_total += pos_e;
            hcn_dark_total += dark_e;
            hcn_j4_total += j4;
            hcn_coupling_total += pos_c;
            hcn_count += 1;
        } else {
            comp_pos_total += pos_e;
            comp_dark_total += dark_e;
            comp_j4_total += j4;
            comp_coupling_total += pos_c;
            comp_count += 1;
        }
    }

    // ═══════════════════════════════════════════════════
    // SECTION 2: Aggregate comparison
    // ═══════════════════════════════════════════════════
    println!();
    println!("═══ SECTION 2: Aggregate Energy by Class ═══");
    println!("{:>12} {:>6} {:>12} {:>12} {:>14} {:>12}",
        "Class", "Count", "Σ|μ|²", "Σ E_dark", "Σ J₄", "Σ μ-couple");
    println!("{}", "─".repeat(74));
    println!("{:>12} {:>6} {:>12.1} {:>12.4} {:>14.1} {:>12.4}",
        "PRIMES ⚡", prime_count, prime_pos_total, prime_dark_total,
        prime_j4_total, prime_coupling_total);
    println!("{:>12} {:>6} {:>12.1} {:>12.4} {:>14.1} {:>12.4}",
        "HCNs 🌀", hcn_count, hcn_pos_total, hcn_dark_total,
        hcn_j4_total, hcn_coupling_total);
    println!("{:>12} {:>6} {:>12.1} {:>12.4} {:>14.1} {:>12.4}",
        "Other", comp_count, comp_pos_total, comp_dark_total,
        comp_j4_total, comp_coupling_total);

    // ═══════════════════════════════════════════════════
    // SECTION 3: Per-element averages (the key comparison)
    // ═══════════════════════════════════════════════════
    println!();
    println!("═══ SECTION 3: Per-Element Averages (The S-Duality Mirror) ═══");
    println!("{:>12} {:>12} {:>12} {:>14} {:>12}",
        "Class", "avg|μ|²", "avg E_dark", "avg J₄", "avg μ-cpl");
    println!("{}", "─".repeat(66));
    if prime_count > 0 {
        println!("{:>12} {:>12.4} {:>12.6} {:>14.2} {:>12.6}",
            "PRIMES ⚡",
            prime_pos_total / prime_count as f64,
            prime_dark_total / prime_count as f64,
            prime_j4_total / prime_count as f64,
            prime_coupling_total / prime_count as f64);
    }
    if hcn_count > 0 {
        println!("{:>12} {:>12.4} {:>12.6} {:>14.2} {:>12.6}",
            "HCNs 🌀",
            hcn_pos_total / hcn_count as f64,
            hcn_dark_total / hcn_count as f64,
            hcn_j4_total / hcn_count as f64,
            hcn_coupling_total / hcn_count as f64);
    }
    if comp_count > 0 {
        println!("{:>12} {:>12.4} {:>12.6} {:>14.2} {:>12.6}",
            "Other",
            comp_pos_total / comp_count as f64,
            comp_dark_total / comp_count as f64,
            comp_j4_total / comp_count as f64,
            comp_coupling_total / comp_count as f64);
    }

    // ═══════════════════════════════════════════════════
    // SECTION 4: The Inversion Ratio
    // ═══════════════════════════════════════════════════
    println!();
    println!("═══ SECTION 4: S-Duality Inversion Ratios ═══");

    let prime_avg_dark = prime_dark_total / prime_count as f64;
    let hcn_avg_dark = hcn_dark_total / hcn_count as f64;
    let prime_avg_pos = prime_pos_total / prime_count as f64;
    let hcn_avg_pos = hcn_pos_total / hcn_count as f64;
    let prime_avg_coupling = prime_coupling_total / prime_count as f64;
    let hcn_avg_coupling = hcn_coupling_total / hcn_count as f64;

    println!();
    println!("  Dark sector:  HCN/Prime energy ratio = {:.4}",
        hcn_avg_dark / prime_avg_dark);
    println!("  Pos  sector:  Prime/HCN Möbius ratio = {:.4}",
        prime_avg_pos / hcn_avg_pos);
    println!("  Pos coupling: Prime/HCN coupling ratio = {:.4}",
        prime_avg_coupling / hcn_avg_coupling);
    println!();

    if hcn_avg_dark > prime_avg_dark && prime_avg_pos >= hcn_avg_pos {
        println!("  ✅ S-DUALITY MASS INVERSION CONFIRMED!");
        println!("     Primes: LOUD in positive sector, QUIET in dark sector");
        println!("     HCNs:   SILENT in positive sector, MASSIVE in dark sector");
    } else {
        println!("  ⚠️  Unexpected pattern — investigate further");
    }

    // ═══════════════════════════════════════════════════
    // SECTION 5: Top-10 in each sector
    // ═══════════════════════════════════════════════════
    println!();
    println!("═══ SECTION 5: Top-10 Dark Sector Gravity Wells ═══");
    let mut dark_energies: Vec<(u64, f64)> = (2..=n_max)
        .map(|n| (n, dark_energy(n, n_max)))
        .collect();
    dark_energies.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap());
    println!("{:>6} {:>12} {:>10} {:>8}", "n", "E_dark(n)", "class", "|μ(n)|");
    println!("{}", "─".repeat(40));
    for &(n, e) in dark_energies.iter().take(15) {
        let class = classify(n, &hcn_set);
        let mu = moebius(n);
        println!("{:>6} {:>12.6} {:>10} {:>8}", n, e, class, mu);
    }

    println!();
    println!("═══ SECTION 6: Top-10 Positive Sector Möbius Couplers ═══");
    let mut pos_couplings: Vec<(u64, f64)> = (2..=n_max)
        .map(|n| (n, positive_coupling(n, n_max)))
        .collect();
    pos_couplings.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap());
    println!("{:>6} {:>12} {:>10} {:>8}", "n", "μ-coupling", "class", "μ(n)");
    println!("{}", "─".repeat(40));
    for &(n, c) in pos_couplings.iter().take(15) {
        let class = classify(n, &hcn_set);
        let mu = moebius(n);
        println!("{:>6} {:>12.6} {:>10} {:>8}", n, c, class, mu);
    }

    println!();
    println!("═══ EXPERIMENT COMPLETE ═══");
    println!("🪞 The mirror has been examined. 🌯❄️");
}
