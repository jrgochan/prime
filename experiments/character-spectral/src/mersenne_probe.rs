//! ═══════════════════════════════════════════════════════════════════════════
//!  MERSENNE PROBE: Targeted Spectral Analysis of Structurally Interesting Integers
//!
//!  Instead of computing the full N×N Gram matrix (O(N²) memory, O(N³) solve),
//!  this probe selects a small set of ~500-2000 "candidate" integers based on
//!  known structural patterns from the particle zoo analysis:
//!
//!  1. Mersenne multiples: k = 2^a · (2^p - 1) for Mersenne primes 2^p - 1
//!  2. Highly composite numbers and their small multiples
//!  3. Semiprimes near N/30 (the resonance zone)
//!  4. Adjacent primes (potential Higgs bosons)
//!  5. Prime powers and other structurally rich integers
//!
//!  By computing only the submatrix G[candidates × candidates] and solving
//!  for its ground state, we can predict the top fermion at scales N = 10^5
//!  to N = 10^6 in under a minute.
//!
//!  Usage: mersenne-probe [max_N]
//! ═══════════════════════════════════════════════════════════════════════════

use cathedral_utils::fmt::*;
use rayon::prelude::*;
use std::time::Instant;

use cathedral_utils::gram::gram_entry_f64;

// ═══════════════════════════════════════════════════════════════════════
// PRIME / FACTORIZATION UTILITIES
// ═══════════════════════════════════════════════════════════════════════

fn is_prime(n: usize) -> bool {
    if n < 2 {
        return false;
    }
    if n < 4 {
        return true;
    }
    if n.is_multiple_of(2) || n.is_multiple_of(3) {
        return false;
    }
    let mut i = 5;
    while i * i <= n {
        if n.is_multiple_of(i) || n.is_multiple_of(i + 2) {
            return false;
        }
        i += 6;
    }
    true
}

fn factorize(mut n: usize) -> Vec<(usize, u32)> {
    let mut factors = Vec::new();
    let mut d = 2;
    while d * d <= n {
        if n.is_multiple_of(d) {
            let mut exp = 0;
            while n.is_multiple_of(d) {
                n /= d;
                exp += 1;
            }
            factors.push((d, exp));
        }
        d += if d == 2 { 1 } else { 2 };
    }
    if n > 1 {
        factors.push((n, 1));
    }
    factors
}

fn format_factors(n: usize) -> String {
    let factors = factorize(n);
    if factors.is_empty() {
        return "1".to_string();
    }
    factors
        .iter()
        .map(|(p, e)| {
            if *e == 1 {
                format!("{p}")
            } else {
                format!("{p}^{e}")
            }
        })
        .collect::<Vec<_>>()
        .join("·")
}

fn num_divisors(n: usize) -> usize {
    let factors = factorize(n);
    factors.iter().map(|(_, e)| (*e as usize) + 1).product()
}

fn omega(n: usize) -> usize {
    factorize(n).len()
}

// ═══════════════════════════════════════════════════════════════════════
// CANDIDATE SELECTION: The "Smart Sieve"
// ═══════════════════════════════════════════════════════════════════════

/// Known Mersenne primes (2^p - 1) for p up to 61
const MERSENNE_EXPONENTS: &[u32] = &[2, 3, 5, 7, 13, 17, 19, 31, 61];

fn select_candidates(n: usize) -> Vec<usize> {
    let mut cands = std::collections::BTreeSet::new();

    // 1. MERSENNE MULTIPLES: k = 2^a · M_p for small multipliers
    for &p in MERSENNE_EXPONENTS {
        let mp = (1u64 << p) - 1;
        if mp as usize > n {
            break;
        }

        // Base Mersenne prime multiples: 2^a * M_p
        for a in 0..=20 {
            let k = (1u64 << a) * mp;
            if k as usize > n {
                break;
            }
            cands.insert(k as usize);

            // Small prime multipliers: 3, 5, 7, 11
            for &q in &[3u64, 5, 7, 11, 13] {
                let kq = k * q;
                if kq as usize <= n {
                    cands.insert(kq as usize);
                }
            }
        }
    }

    // 2. RESONANCE ZONE: semiprimes and composites near N/20 to N/40
    let zone_lo = n / 50;
    let zone_hi = n / 15;
    // Sample semiprimes and interesting composites in the zone
    for k in zone_lo..=zone_hi {
        let w = omega(k);
        let d = num_divisors(k);
        // Keep semiprimes (ω=2), or any with many divisors, or special structure
        if w == 2 || d >= 8 || k % 127 == 0 || k % 31 == 0 {
            cands.insert(k);
        }
        // But limit total candidates from this zone
        if cands.len() > 3000 {
            break;
        }
    }

    // 3. HIGHLY COMPOSITE NUMBERS (known up to 10^9)
    let hc = [
        2, 4, 6, 12, 24, 36, 48, 60, 120, 180, 240, 360, 720, 840, 1260, 1680, 2520, 5040, 7560,
        10080, 15120, 20160, 25200, 27720, 45360, 50400, 55440, 83160, 110880, 166320, 221760,
        277200, 332640, 498960, 554400, 665280, 720720, 1081080, 1441440, 2162160, 2882880,
        3603600, 4324320, 6486480, 7207200, 8648640, 10810800, 14414400, 17297280, 21621600,
        36756720, 43243200, 61261200, 73513440, 110270160, 122522400, 147026880, 183783600,
        245044800, 294053760, 367567200, 551350800, 698377680, 735134400,
    ];
    for &h in &hc {
        if h <= n {
            cands.insert(h);
            // Small multiples of HC numbers
            for m in 2..=5 {
                if h * m <= n {
                    cands.insert(h * m);
                }
            }
        }
    }

    // 4. ADJACENT PRIMES: for every candidate c, add nearest primes
    let cands_snapshot: Vec<usize> = cands.iter().copied().collect();
    for c in &cands_snapshot {
        // Search for primes within gap 50
        for offset in 1..=50 {
            if *c > offset && is_prime(*c - offset) {
                cands.insert(*c - offset);
                break;
            }
        }
        for offset in 1..=50 {
            if *c + offset <= n && is_prime(*c + offset) {
                cands.insert(*c + offset);
                break;
            }
        }
    }

    // 5. SMALL PRIMES (always important as gauge bosons)
    for p in 2..=100 {
        if is_prime(p) {
            cands.insert(p);
        }
    }

    // 6. PRIME POWERS up to N
    for p in [2, 3, 5, 7, 11, 13] {
        let mut pk: usize = p;
        while pk <= n {
            cands.insert(pk);
            if pk > n / p {
                break;
            }
            pk *= p;
        }
    }

    // Filter: must be in [2, N]
    let mut result: Vec<usize> = cands.into_iter().filter(|&k| k >= 2 && k <= n).collect();
    result.sort_unstable();
    result
}

// ═══════════════════════════════════════════════════════════════════════
// SUBMATRIX CONSTRUCTION + EIGENVECTOR
// ═══════════════════════════════════════════════════════════════════════

fn build_submatrix(candidates: &[usize]) -> Vec<f64> {
    let dim = candidates.len();
    let t_start = Instant::now();

    let entries: Vec<((usize, usize), f64)> = (0..dim)
        .into_par_iter()
        .flat_map(|row| {
            let result: Vec<_> = (row..dim)
                .map(move |col| ((row, col), gram_entry_f64(candidates[row], candidates[col])))
                .collect();
            if row % 200 == 0 && row > 0 {
                let elapsed = t_start.elapsed().as_secs_f64();
                let frac = row as f64 / dim as f64;
                let eta = elapsed / frac * (1.0 - frac);
                eprint!(
                    "\r  {DIM}  submatrix row {row}/{dim} ({:.0}%) ETA {eta:.0}s{RESET}    ",
                    frac * 100.0
                );
            }
            result
        })
        .collect();

    if dim > 200 {
        eprintln!();
    }
    eprintln!(
        "  Submatrix: {}×{} ({:.1}s)",
        dim,
        dim,
        t_start.elapsed().as_secs_f64()
    );

    let mut mat = vec![0.0f64; dim * dim];
    for ((r, c), v) in entries {
        mat[r * dim + c] = v;
        mat[c * dim + r] = v;
    }
    mat
}

fn ground_state_inverse_iter(mat: &[f64], dim: usize) -> (f64, Vec<f64>) {
    use nalgebra::DMatrix;

    eprintln!("  LU decomposition ({dim}×{dim})...");
    let t0 = Instant::now();
    let m = DMatrix::from_row_slice(dim, dim, mat);
    let lu = m.clone().lu();
    eprintln!("  LU done ({:.1}s)", t0.elapsed().as_secs_f64());

    let max_iter = 300;
    let mut v = nalgebra::DVector::from_element(dim, 1.0 / (dim as f64).sqrt());

    for _iter in 0..max_iter {
        let w = lu.solve(&v).expect("LU solve failed");
        let norm = w.norm();
        if norm < 1e-30 {
            break;
        }
        v = w / norm;
    }

    // Rayleigh quotient for eigenvalue
    let gv = &m * &v;
    let lambda = v.dot(&gv) / v.dot(&v);

    let weights: Vec<f64> = v.iter().map(|x| x * x).collect();
    (lambda, weights)
}

// ═══════════════════════════════════════════════════════════════════════
// ANALYSIS
// ═══════════════════════════════════════════════════════════════════════

struct CandidateInfo {
    k: usize,
    weight: f64,
    d_k: usize,
    omega: usize,
    is_prime: bool,
    factors: String,
}

fn analyze(candidates: &[usize], weights: &[f64], lambda_min: f64, n: usize) {
    let total_time = Instant::now();

    // Build info
    let mut infos: Vec<CandidateInfo> = candidates
        .iter()
        .zip(weights.iter())
        .map(|(&k, &w)| CandidateInfo {
            k,
            weight: w,
            d_k: num_divisors(k),
            omega: omega(k),
            is_prime: is_prime(k),
            factors: if is_prime(k) {
                format!("{k} (prime)")
            } else {
                format_factors(k)
            },
        })
        .collect();

    // Sort by weight descending
    infos.sort_by(|a, b| b.weight.partial_cmp(&a.weight).unwrap());

    // Summary stats
    let prime_weight: f64 = infos.iter().filter(|i| i.is_prime).map(|i| i.weight).sum();
    let composite_weight: f64 = infos.iter().filter(|i| !i.is_prime).map(|i| i.weight).sum();
    let prime_count = infos.iter().filter(|i| i.is_prime).count();
    let composite_count = infos.iter().filter(|i| !i.is_prime).count();

    eprintln!("\n  ═══ MERSENNE PROBE RESULTS · N = {n} ═══\n");
    eprintln!(
        "  Candidates analyzed: {} ({} primes, {} composites)",
        infos.len(),
        prime_count,
        composite_count
    );
    eprintln!("  λ_min (submatrix): {:.6e}", lambda_min);
    eprintln!();
    eprintln!("  Ground-state weight allocation:");
    eprintln!(
        "    Bosons (primes):     {:.4}% ({} primes)",
        prime_weight * 100.0,
        prime_count
    );
    eprintln!(
        "    Fermions (composites): {:.4}% ({} composites)",
        composite_weight * 100.0,
        composite_count
    );
    if prime_weight > 0.0 {
        eprintln!(
            "    Ratio:               {:.1}×",
            composite_weight / prime_weight
        );
    }

    // Top 30 by weight
    eprintln!("\n  ═══ TOP 30 PARTICLES (by ground-state weight) ═══\n");
    eprintln!("  rank │ k          │ weight       │ d(k) │ ω │ type    │ factors");
    eprintln!("  ─────┼────────────┼──────────────┼──────┼───┼─────────┼────────");
    for (i, info) in infos.iter().take(30).enumerate() {
        let kind = if info.is_prime { "BOSON" } else { "fermion" };
        eprintln!(
            "  {:<4} │ {:<10} │ {:.8e} │ {:<4} │ {} │ {:<7} │ {}",
            i + 1,
            info.k,
            info.weight,
            info.d_k,
            info.omega,
            kind,
            info.factors
        );
    }

    // Mersenne family analysis
    eprintln!("\n  ═══ MERSENNE PRIME FAMILIES ═══\n");
    for &p in MERSENNE_EXPONENTS {
        let mp = (1u64 << p) - 1;
        if mp as usize > n {
            break;
        }

        let family_weight: f64 = infos
            .iter()
            .filter(|i| !i.is_prime && (i.k as u64).is_multiple_of(mp))
            .map(|i| i.weight)
            .sum();

        let family_count = infos
            .iter()
            .filter(|i| !i.is_prime && (i.k as u64).is_multiple_of(mp))
            .count();

        // Find the heaviest member
        let best = infos
            .iter()
            .filter(|i| !i.is_prime && (i.k as u64).is_multiple_of(mp))
            .max_by(|a, b| a.weight.partial_cmp(&b.weight).unwrap());

        if let Some(b) = best {
            eprintln!(
                "  M_{p} = {mp} (2^{p}-1): {family_count} members, total weight = {:.4}%",
                family_weight * 100.0
            );
            eprintln!(
                "    Champion: k = {} (weight {:.6e}, d={}, ω={}) = {}",
                b.k, b.weight, b.d_k, b.omega, b.factors
            );
        }
    }

    // Higgs adjacency check
    eprintln!("\n  ═══ HIGGS ADJACENCY (boson-fermion pairs at gap ≤ 2) ═══\n");
    let top_fermions: Vec<&CandidateInfo> = infos.iter().filter(|i| !i.is_prime).take(10).collect();

    for f in &top_fermions {
        // Check if adjacent integers are primes in our candidate set
        for gap in 1..=2 {
            if f.k > gap {
                let neighbor = f.k - gap;
                if let Some(boson) = infos.iter().find(|i| i.k == neighbor && i.is_prime) {
                    eprintln!(
                        "  {} (fermion, wt={:.4e}) ← gap={} → {} (boson, wt={:.4e})",
                        f.k, f.weight, gap, boson.k, boson.weight
                    );
                }
            }
            let neighbor = f.k + gap;
            if neighbor <= n
                && let Some(boson) = infos.iter().find(|i| i.k == neighbor && i.is_prime)
            {
                eprintln!(
                    "  {} (fermion, wt={:.4e}) ← gap={} → {} (boson, wt={:.4e})",
                    f.k, f.weight, gap, boson.k, boson.weight
                );
            }
        }
    }

    // Write results
    let out_path = format!("results/mersenne_probe_N{n}.tsv");
    let mut out = String::from("rank\tk\tweight\td_k\tomega\tis_prime\tfactors\n");
    for (i, info) in infos.iter().enumerate() {
        out.push_str(&format!(
            "{}\t{}\t{:.12e}\t{}\t{}\t{}\t{}\n",
            i + 1,
            info.k,
            info.weight,
            info.d_k,
            info.omega,
            if info.is_prime { "prime" } else { "composite" },
            info.factors
        ));
    }
    std::fs::write(&out_path, out).unwrap();
    eprintln!("\n  ✓ Wrote \"{out_path}\"");

    // JSON summary
    let json_path = format!("results/mersenne_probe_N{n}.json");
    let top = &infos[0];
    let top_boson = infos.iter().find(|i| i.is_prime).unwrap();
    let json = format!(
        r#"{{
  "experiment": "mersenne-probe",
  "N": {n},
  "candidates": {},
  "lambda_min_submatrix": {:.12e},
  "prime_weight": {:.10},
  "composite_weight": {:.10},
  "top_fermion": {{
    "k": {},
    "weight": {:.12e},
    "d_k": {},
    "omega": {},
    "factors": "{}"
  }},
  "top_boson": {{
    "k": {},
    "weight": {:.12e}
  }}
}}
"#,
        infos.len(),
        lambda_min,
        prime_weight,
        composite_weight,
        top.k,
        top.weight,
        top.d_k,
        top.omega,
        top.factors,
        top_boson.k,
        top_boson.weight
    );
    std::fs::write(&json_path, json).unwrap();
    eprintln!("  ✓ Wrote \"{json_path}\"");

    eprintln!(
        "\n  Total analysis: {:.1}s\n",
        total_time.elapsed().as_secs_f64()
    );
}

// ═══════════════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════════════

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let n: usize = args.get(1).and_then(|s| s.parse().ok()).unwrap_or(100_000);
    let threads = rayon::current_num_threads();
    let total = Instant::now();

    eprintln!();
    eprintln!("  ╔═══════════════════════════════════════════════════════════════════════╗");
    eprintln!("  ║  CATHEDRAL MERSENNE PROBE");
    eprintln!("  ║  Targeted spectral analysis · N = {n}");
    eprintln!("  ║  {threads} threads");
    eprintln!("  ╚═══════════════════════════════════════════════════════════════════════╝");
    eprintln!();

    // Step 1: Select candidates
    let t0 = Instant::now();
    let candidates = select_candidates(n);
    eprintln!(
        "  Selected {} candidate integers ({:.2}s)",
        candidates.len(),
        t0.elapsed().as_secs_f64()
    );
    eprintln!("    Mersenne multiples, HC numbers, resonance zone semiprimes,");
    eprintln!("    adjacent primes, prime powers");
    eprintln!();

    // Step 2: Build submatrix
    let mat = build_submatrix(&candidates);

    // Step 3: Ground state
    let dim = candidates.len();
    let (lambda_min, weights) = ground_state_inverse_iter(&mat, dim);

    // Step 4: Analysis
    analyze(&candidates, &weights, lambda_min, n);

    eprintln!(
        "  Total: {:.1}s ({threads} threads)\n",
        total.elapsed().as_secs_f64()
    );
}
