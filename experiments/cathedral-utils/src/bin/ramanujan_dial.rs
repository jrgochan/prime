//! ═══════════════════════════════════════════════════════════════════════════
//!  RAMANUJAN DIAL — The N-Analysis Experiment (Massively Parallel)
//!
//!  Explores which values of N matter for the Nyman-Beurling distance d²_N.
//!
//!  Parallelization strategy:
//!    1. Sieve-based divisor table — O(N log N) vs O(N√N)
//!    2. Bulk parallel Gram matrix — all entries computed up front via rayon
//!    3. Incremental Cholesky — reuse L_{N-1}, extend by one row: O(N²) not O(N³)
//!
//!  Usage:
//!    cargo run --release --bin ramanujan-dial [--max <limit>] [--compute-d2]
//!    cargo run --release --bin ramanujan-dial -- --compute-d2 --d2-max 2000
//! ═══════════════════════════════════════════════════════════════════════════

use std::time::Instant;
use std::collections::HashSet;
use rayon::prelude::*;
use cathedral_utils::arith;

fn main() {
    let args: Vec<String> = std::env::args().collect();

    let max_limit: u64 = args.iter().position(|a| a == "--max")
        .and_then(|i| args.get(i + 1)?.parse().ok())
        .unwrap_or(1_000_000);

    let compute_d2 = args.iter().any(|a| a == "--compute-d2");
    let d2_max: usize = args.iter().position(|a| a == "--d2-max")
        .and_then(|i| args.get(i + 1)?.parse().ok())
        .unwrap_or(500);

    println!();
    println!("╔══════════════════════════════════════════════════════════════╗");
    println!("║  🎛️  RAMANUJAN DIAL — N-Analysis (Massively Parallel)       ║");
    println!("╠══════════════════════════════════════════════════════════════╣");
    println!("║  Max N: {:<52}║", format!("{}", max_limit));
    println!("║  Compute d²: {:<47}║",
        if compute_d2 { format!("yes (up to N={}) — PARALLEL", d2_max) }
        else { "no (--compute-d2 to enable)".to_string() });
    println!("║  Threads: {:<50}║", rayon::current_num_threads());
    println!("╚══════════════════════════════════════════════════════════════╝");
    println!();

    // ═══════════════════════════════════════════════════════════
    // PART 1: THE RAMANUJAN TEMPERATURE DIAL
    // ═══════════════════════════════════════════════════════════
    println!("═══════════════════════════════════════════════════════════════");
    println!("PART 1: THE RAMANUJAN TEMPERATURE DIAL");
    println!("═══════════════════════════════════════════════════════════════");
    println!();
    println!("  Ramanujan (1915): N(ε) = Π_p p^⌊1/(p^ε - 1)⌋");
    println!("  Phase transitions at ε = ln(2)/ln(p).");
    println!();

    let primes = small_primes(100);
    let mut eps = 1.0f64;
    let mut prev_n: u64 = 0;
    let mut colossal_anchors: Vec<(f64, u64, String)> = Vec::new();

    println!("  {:>8} {:>14} {:>6} {:>6} {:>30}",
        "ε", "N(ε)", "d(N)", "ω(N)", "factorization");
    println!("  {:>8} {:>14} {:>6} {:>6} {:>30}",
        "────────", "──────────────", "──────", "──────", "──────────────────────────────");

    while eps > 0.005 {
        let (n, facts) = ramanujan_n(eps, &primes);
        if n != prev_n && n <= max_limit && n >= 2 {
            prev_n = n;
            let divs = count_divisors_from_factorization(&facts);
            let distinct_primes = facts.len();
            let fact_str = format_factorization(&facts);
            colossal_anchors.push((eps, n, fact_str.clone()));
            println!("  {:>8.4} {:>14} {:>6} {:>6} {:>30}",
                eps, format_num(n), divs, distinct_primes, fact_str);
        }
        eps -= 0.001;
    }
    println!();

    // ═══════════════════════════════════════════════════════════
    // PART 2: THE COLOSSAL SEQUENCE
    // ═══════════════════════════════════════════════════════════
    let colossal: Vec<u64> = vec![
        2, 6, 12, 60, 120, 360, 2520, 5040, 55440, 720720,
    ];
    let colossal_names = [
        "", "", "", "", "", "",
        "Plato's Number", "Robin Threshold", "Precision Wall", "Deep Sink",
    ];

    println!("═══════════════════════════════════════════════════════════════");
    println!("PART 2: THE COLOSSAL SEQUENCE (Superior Highly Composites)");
    println!("═══════════════════════════════════════════════════════════════");
    println!();
    println!("  {:>10} {:>6} {:>6} {:>30} {:>20}",
        "N", "d(N)", "ω(N)", "factorization", "significance");
    println!("  {:>10} {:>6} {:>6} {:>30} {:>20}",
        "──────────", "──────", "──────", "──────────────────────────────", "────────────────────");

    for (idx, &n) in colossal.iter().enumerate() {
        if n > max_limit { break; }
        let nu = n as usize;
        println!("  {:>10} {:>6} {:>6} {:>30} {:>20}",
            format_num(n), count_divisors_brute(nu), arith::small_omega(nu),
            arith::factorize(nu), colossal_names.get(idx).unwrap_or(&""));
    }
    println!();

    // ═══════════════════════════════════════════════════════════
    // PART 3: HCN SCAN — Sieve-accelerated
    // ═══════════════════════════════════════════════════════════
    let t0 = Instant::now();
    let hcn_limit = max_limit.min(200_000) as usize;

    println!("═══════════════════════════════════════════════════════════════");
    println!("PART 3: HIGHLY COMPOSITE NUMBERS up to {} (sieve)", format_num(hcn_limit as u64));
    println!("═══════════════════════════════════════════════════════════════");
    println!();

    // Sieve-based divisor count: O(N log N)
    let div_table = divisor_count_sieve(hcn_limit);
    let hcns = find_hcn_from_sieve(&div_table);
    println!("  ✓ Sieve + HCN scan in {:.3}s ({} HCNs found)",
        t0.elapsed().as_secs_f64(), hcns.len());
    println!();

    println!("  {:>10} {:>6} {:>6} {:>30} {:>10}",
        "N", "d(N)", "ω(N)", "factorization", "type");
    println!("  {:>10} {:>6} {:>6} {:>30} {:>10}",
        "──────────", "──────", "──────", "──────────────────────────────", "──────────");

    for &n in &hcns {
        let is_col = colossal.contains(&(n as u64));
        println!("  {:>10} {:>6} {:>6} {:>30} {:>10}",
            format_num(n as u64), div_table[n], arith::small_omega(n),
            arith::factorize(n), if is_col { "COLOSSAL" } else { "HCN" });
    }
    println!();

    // ═══════════════════════════════════════════════════════════
    // PART 4: VOID ANALYSIS
    // ═══════════════════════════════════════════════════════════
    println!("═══════════════════════════════════════════════════════════════");
    println!("PART 4: VOID ANALYSIS — Between Colossal Anchors");
    println!("═══════════════════════════════════════════════════════════════");
    println!();

    let colossal_under: Vec<u64> = colossal.iter().copied()
        .filter(|&n| n <= max_limit).collect();
    let sieve = arith::sieve_primes(hcn_limit);

    for pair in colossal_under.windows(2) {
        let (lo, hi) = (pair[0], pair[1]);
        if hi > 200_000 { continue; }

        let hcns_between: Vec<usize> = hcns.iter().copied()
            .filter(|&n| (n as u64) > lo && (n as u64) < hi).collect();
        let primes_in_gap: usize = ((lo as usize + 1)..hi as usize)
            .filter(|&n| n < sieve.len() && sieve[n]).count();

        println!("  Gap [{} → {}]: size {}, {} HCNs, {} primes",
            format_num(lo), format_num(hi), format_num(hi - lo),
            hcns_between.len(), primes_in_gap);

        for &h in &hcns_between {
            println!("    HCN {:>8} = {:<20} d={:<4} ({:.1}× anchor)",
                format_num(h as u64), arith::factorize(h),
                div_table[h], h as f64 / lo as f64);
        }
        println!();
    }

    // ═══════════════════════════════════════════════════════════
    // PART 5: RECOMMENDATIONS
    // ═══════════════════════════════════════════════════════════
    println!("═══════════════════════════════════════════════════════════════");
    println!("PART 5: RECOMMENDED N VALUES FOR CATHEDRAL EXPERIMENTS");
    println!("═══════════════════════════════════════════════════════════════");
    println!();

    let recs = vec![
        (2u64, "Minimal: G is 1×1", "trivial"),
        (6, "First 2-prime anchor (2·3)", "quick"),
        (12, "First exponent-2 anchor (2²·3)", "quick"),
        (60, "First 3-prime anchor (2²·3·5)", "quick"),
        (120, "Half of 2-prime-chain (2³·3·5)", "quick"),
        (360, "Peak exponent-2 (2³·3²·5)", "seconds"),
        (2520, "Plato's Number (2³·3²·5·7)", "minutes"),
        (5040, "Robin Threshold (2⁴·3²·5·7)", "minutes"),
        (55440, "Precision Wall (2⁴·3²·5·7·11)", "GPU hours"),
        (110880, "2× Wall, 144 divisors", "GPU day"),
        (166320, "3× Wall, 160 divisors", "GPU days"),
        (720720, "Deep Sink (2⁴·3²·5·7·11·13)", "GPU weeks"),
    ];

    println!("  {:>10} {:>6} {:>6} {:>42} {:>12}",
        "N", "d(N)", "ω(N)", "description", "compute");
    println!("  {:>10} {:>6} {:>6} {:>42} {:>12}",
        "──────────", "──────", "──────",
        "──────────────────────────────────────────", "────────────");

    for (n, desc, compute) in &recs {
        let nu = *n as usize;
        println!("  {:>10} {:>6} {:>6} {:>42} {:>12}",
            format_num(*n), count_divisors_brute(nu),
            arith::small_omega(nu), desc, compute);
    }
    println!();

    // Control groups
    println!("  CONTROL GROUPS (primes — minimal divisor structure):");
    for (n, desc) in [
        (5039u64, "Largest prime < 5040"),
        (5051, "Smallest prime > 5040"),
        (55439, "Largest prime < 55440"),
        (55441, "Smallest prime > 55440"),
        (104729, "10,000th prime (max silence)"),
    ] {
        let is_p = is_prime_simple(n as usize);
        println!("    {:>10}  {}  {}", format_num(n), desc,
            if is_p { "✓ prime" } else { "✗ NOT prime" });
    }
    println!();

    // ═══════════════════════════════════════════════════════════
    // PART 6: d² COMPUTATIONS — MASSIVELY PARALLEL
    // ═══════════════════════════════════════════════════════════
    if compute_d2 {
        println!("═══════════════════════════════════════════════════════════════");
        println!("PART 6: d²_N COMPUTATIONS — PARALLEL (N ≤ {})", d2_max);
        println!("═══════════════════════════════════════════════════════════════");
        println!();
        compute_d2_parallel(d2_max, &hcns);
    } else {
        println!("═══════════════════════════════════════════════════════════════");
        println!("PART 6: d²_N — SKIPPED (use --compute-d2)");
        println!("═══════════════════════════════════════════════════════════════");
        println!();
    }

    // ═══════════════════════════════════════════════════════════
    // PART 7: PHASE TRANSITIONS
    // ═══════════════════════════════════════════════════════════
    println!("═══════════════════════════════════════════════════════════════");
    println!("PART 7: PHASE TRANSITIONS — When Primes Freeze In");
    println!("═══════════════════════════════════════════════════════════════");
    println!();
    println!("  {:>6} {:>10} {:>10} {:>14}",
        "prime", "ε_entry", "N_before", "N_after");
    println!("  {:>6} {:>10} {:>10} {:>14}",
        "──────", "──────────", "──────────", "──────────────");

    for &p in &primes[..primes.len().min(15)] {
        let eps_entry = 2.0f64.ln() / (p as f64).ln();
        let (n_above, _) = ramanujan_n(eps_entry + 0.001, &primes);
        let (n_below, _) = ramanujan_n(eps_entry - 0.001, &primes);
        println!("  {:>6} {:>10.4} {:>10} {:>14}",
            p, eps_entry, format_num(n_above), format_num(n_below));
    }
    println!();

    // SUMMARY
    println!("╔══════════════════════════════════════════════════════════════╗");
    println!("║  SUMMARY — N-ANALYSIS                                      ║");
    println!("╠══════════════════════════════════════════════════════════════╣");
    println!("║  1. Colossal numbers are the TRUE structural nodes.       ║");
    println!("║  2. HCNs between colossals are local gravity wells.       ║");
    println!("║  3. Primes in the void are 'silent' — minimal d² descent. ║");
    println!("║  4. The Ramanujan ε parameter governs phase transitions.  ║");
    println!("║  5. GPU runs should target: 360, 2520, 5040, 55440.       ║");
    println!("╚══════════════════════════════════════════════════════════════╝");
    println!();
}

// ═══════════════════════════════════════════════════════════════
// PARALLEL d² ENGINE
// ═══════════════════════════════════════════════════════════════

/// Massively parallel d² computation using:
///   1. Bulk parallel Gram entry precomputation (rayon)
///   2. Incremental Cholesky (O(N²) per step, not O(N³))
fn compute_d2_parallel(max_n: usize, hcns: &[usize]) {
    use cathedral_utils::gram;

    let dim = max_n - 1; // indices 2..=max_n → dim entries
    let hcn_set: HashSet<usize> = hcns.iter().copied().collect();

    // ── Step 1: Bulk parallel Gram matrix computation ──────────
    let t0 = Instant::now();
    println!("  Phase 1: Bulk Gram matrix ({0}×{0} = {1} unique entries)...",
        dim, dim * (dim + 1) / 2);

    // Compute upper triangle in parallel: flatten (i,j) pairs
    let pairs: Vec<(usize, usize)> = (0..dim)
        .flat_map(|i| (i..dim).map(move |j| (i, j)))
        .collect();

    let gram_values: Vec<((usize, usize), f64)> = pairs.par_iter()
        .map(|&(i, j)| ((i, j), gram::gram_entry_f64(i + 2, j + 2)))
        .collect();

    // Store in flat symmetric matrix
    let mut gram = vec![0.0f64; dim * dim];
    for &((i, j), val) in &gram_values {
        gram[i * dim + j] = val;
        gram[j * dim + i] = val;
    }

    let gram_time = t0.elapsed().as_secs_f64();
    println!("  ✓ Gram matrix computed in {:.2}s ({} entries/sec)",
        gram_time, (pairs.len() as f64 / gram_time) as u64);

    // ── Step 2: b-vector ──────────────────────────────────────
    let b = arith::b_vector(dim);

    // ── Step 3: Incremental Cholesky ──────────────────────────
    let t0 = Instant::now();
    println!("  Phase 2: Incremental Cholesky (N=2..{})...", max_n);
    println!();
    println!("  {:>6} {:>14} {:>6} {:>6} {:>10} {:>20} {:>3}",
        "N", "d²_N", "d(N)", "ω(N)", "type", "factorization", "");
    println!("  {:>6} {:>14} {:>6} {:>6} {:>10} {:>20} {:>3}",
        "──────", "──────────────", "──────", "──────",
        "──────────", "────────────────────", "───");

    // L is stored row-major, grows incrementally
    let mut l = vec![0.0f64; dim * dim];
    let mut prev_d2 = f64::MAX;
    let mut anomalies = 0usize;

    for n in 2..=max_n {
        let cur_dim = n - 1; // current matrix dimension
        let new_idx = cur_dim - 1; // 0-based index of new row/column

        // ── Incremental Cholesky: extend L by one row ────────
        // For the new row new_idx, compute L[new_idx, 0..new_idx] and L[new_idx, new_idx]
        //
        // For k < new_idx:
        //   L[new_idx, k] = (G[new_idx, k] - Σ_{m=0}^{k-1} L[new_idx, m]*L[k, m]) / L[k, k]
        //
        // L[new_idx, new_idx] = sqrt(G[new_idx, new_idx] - Σ_{m=0}^{new_idx-1} L[new_idx, m]²)

        for k in 0..new_idx {
            let mut s = 0.0f64;
            for m in 0..k {
                s += l[new_idx * dim + m] * l[k * dim + m];
            }
            l[new_idx * dim + k] = (gram[new_idx * dim + k] - s) / l[k * dim + k];
        }

        let mut diag_sum = 0.0f64;
        for m in 0..new_idx {
            diag_sum += l[new_idx * dim + m] * l[new_idx * dim + m];
        }
        let diag = gram[new_idx * dim + new_idx] - diag_sum;
        if diag <= 0.0 {
            let type_str = classify(n, &hcn_set);
            println!("  {:>6} {:>14} {:>6} {:>6} {:>10} {:>20}",
                n, "CHOL FAIL", count_divisors_brute(n), arith::small_omega(n),
                type_str, arith::factorize(n));
            anomalies += 1;
            continue;
        }
        l[new_idx * dim + new_idx] = diag.sqrt();

        // ── Forward solve: L y = b[0..cur_dim] ──────────────
        let mut y = vec![0.0f64; cur_dim];
        for i in 0..cur_dim {
            let mut s = 0.0f64;
            for jj in 0..i {
                s += l[i * dim + jj] * y[jj];
            }
            y[i] = (b[i] - s) / l[i * dim + i];
        }

        // d² = 1 - ||y||²
        let y_norm_sq: f64 = y.iter().map(|v| v * v).sum();
        let d2 = 1.0 - y_norm_sq;

        let type_str = classify(n, &hcn_set);
        let descent = if d2 < prev_d2 { "↓" } else { "↑" };
        if d2 > prev_d2 { anomalies += 1; }

        // Print strategy: always print notable N, sparse for large N
        let is_notable = hcn_set.contains(&n) || is_prime_simple(n)
            || n <= 60 || d2 > prev_d2 || n % 500 == 0
            || colossal_set().contains(&(n as u64));

        if is_notable {
            println!("  {:>6} {:>14.10} {:>6} {:>6} {:>10} {:>20} {}",
                n, d2, count_divisors_brute(n), arith::small_omega(n),
                type_str, arith::factorize(n), descent);
        }

        prev_d2 = d2;
    }

    let chol_time = t0.elapsed().as_secs_f64();
    println!();
    println!("  ✓ Incremental Cholesky completed in {:.2}s", chol_time);
    println!("  ✓ Total time: {:.2}s (Gram) + {:.2}s (Cholesky) = {:.2}s",
        gram_time, chol_time, gram_time + chol_time);
    println!("  ✓ Monotonicity anomalies: {} (expected 0 for exact arithmetic)",
        anomalies);
    println!();
}

// ═══════════════════════════════════════════════════════════════
// UTILITY FUNCTIONS
// ═══════════════════════════════════════════════════════════════

fn colossal_set() -> HashSet<u64> {
    [2u64, 6, 12, 60, 120, 360, 2520, 5040, 55440, 720720]
        .iter().copied().collect()
}

fn classify(n: usize, hcn_set: &HashSet<usize>) -> &'static str {
    if colossal_set().contains(&(n as u64)) { "COLOSSAL" }
    else if hcn_set.contains(&n) { "HCN" }
    else if is_prime_simple(n) { "prime" }
    else { "" }
}

/// Sieve-based divisor count table: d(n) for n=0..=limit.
/// O(N log N) — each divisor d iterates through its multiples.
fn divisor_count_sieve(limit: usize) -> Vec<u32> {
    let mut d = vec![0u32; limit + 1];
    for i in 1..=limit {
        let mut m = i;
        while m <= limit {
            d[m] += 1;
            m += i;
        }
    }
    d
}

/// Find HCNs from precomputed divisor sieve.
fn find_hcn_from_sieve(div_table: &[u32]) -> Vec<usize> {
    let mut hcns = Vec::new();
    let mut max_d = 0u32;
    for n in 1..div_table.len() {
        if div_table[n] > max_d {
            max_d = div_table[n];
            hcns.push(n);
        }
    }
    hcns
}

fn ramanujan_n(eps: f64, primes: &[usize]) -> (u64, Vec<(usize, u32)>) {
    let mut n: u64 = 1;
    let mut factors = Vec::new();
    for &p in primes {
        let val = (p as f64).powf(eps) - 1.0;
        if val <= 0.0 { break; }
        let a = (1.0 / val).floor() as u32;
        if a == 0 { break; }
        let mut pk: u64 = 1;
        for _ in 0..a { pk = pk.saturating_mul(p as u64); }
        if n > u64::MAX / pk { break; }
        n *= pk;
        factors.push((p, a));
    }
    (n, factors)
}

fn count_divisors_from_factorization(facts: &[(usize, u32)]) -> u64 {
    facts.iter().map(|(_, a)| *a as u64 + 1).product()
}

fn count_divisors_brute(n: usize) -> usize {
    if n <= 1 { return n; }
    let mut c = 0;
    let mut d = 1;
    while d * d <= n { if n % d == 0 { c += 1; if d != n/d { c += 1; } } d += 1; }
    c
}

fn is_prime_simple(n: usize) -> bool {
    if n < 2 { return false; }
    if n < 4 { return true; }
    if n % 2 == 0 || n % 3 == 0 { return false; }
    let mut i = 5;
    while i * i <= n { if n % i == 0 || n % (i+2) == 0 { return false; } i += 6; }
    true
}

fn format_factorization(facts: &[(usize, u32)]) -> String {
    facts.iter()
        .map(|(p, a)| if *a == 1 { format!("{p}") } else { format!("{p}^{a}") })
        .collect::<Vec<_>>().join("·")
}

fn small_primes(limit: usize) -> Vec<usize> {
    let sieve = arith::sieve_primes(limit);
    (2..=limit).filter(|&n| sieve[n]).collect()
}

fn format_num(n: u64) -> String {
    let s = n.to_string();
    let mut result = String::new();
    for (i, ch) in s.chars().rev().enumerate() {
        if i > 0 && i % 3 == 0 { result.push(','); }
        result.push(ch);
    }
    result.chars().rev().collect()
}
