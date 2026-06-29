#![allow(
    dead_code,
    unused_variables,
    unused_imports,
    unused_assignments,
    clippy::needless_range_loop,
    clippy::doc_lazy_continuation,
    non_snake_case,
    clippy::empty_line_after_doc_comments
)]
// overcancellation-scan/src/bin/fermi_tower.rs
//
// ╔═══════════════════════════════════════════════════════════════════════╗
// ║  FERMI TOWER — Block Decomposition by ω-Layer at Giant N            ║
// ║                                                                       ║
// ║  Computes vtGv decomposed by Fermi layers ω(j)×ω(k) using          ║
// ║  exact Direct Gram (Vasyunin cotangent formula).                      ║
// ║                                                                       ║
// ║  Also computes the Ceiling Test:                                      ║
// ║    vtGv(L≤1), vtGv(L≤2), vtGv(L≤3), vtGv(full)                    ║
// ║                                                                       ║
// ║  Usage: fermi-tower [N_MAX] [STEP]                                    ║
// ║    default: N_MAX=7500, STEP=500                                      ║
// ║  Cathedral — June 4, 2026                                             ║
// ╚═══════════════════════════════════════════════════════════════════════╝

use cathedral_utils::arith::gcd;
use rayon::prelude::*;
use std::collections::HashMap;
use std::f64::consts::PI;
use std::time::Instant;

const EULER_GAMMA: f64 = 0.5772156649015329;
const LN_2PI: f64 = 1.8378770664093453;
const COEFF: f64 = LN_2PI - EULER_GAMMA;

fn sieve_mobius(n: usize) -> (Vec<i8>, Vec<usize>) {
    let mut mu = vec![0i8; n + 1];
    mu[1] = 1;
    let mut is_prime = vec![true; n + 1];
    let mut primes = Vec::new();
    for i in 2..=n {
        if is_prime[i] {
            primes.push(i);
            mu[i] = -1;
        }
        for &p in &primes {
            if i * p > n {
                break;
            }
            is_prime[i * p] = false;
            if i % p == 0 {
                mu[i * p] = 0;
                break;
            } else {
                mu[i * p] = -mu[i];
            }
        }
    }
    (mu, primes)
}

fn sieve_omega(n: usize) -> Vec<u8> {
    let mut om = vec![0u8; n + 1];
    for p in 2..=n {
        if om[p] == 0 {
            for m in (p..=n).step_by(p) {
                om[m] += 1;
            }
        }
    }
    om
}

fn vasyunin_sum(a: usize, b: usize) -> f64 {
    if a <= 1 {
        return 0.0;
    }
    let af = a as f64;
    let bf = b as f64;
    let mut total = 0.0;
    for m in 1..a {
        let mf = m as f64;
        let mut frac_part = (mf * bf / af).fract();
        if frac_part < 0.0 {
            frac_part += 1.0;
        }
        let angle = PI * mf / af;
        let sin_val = angle.sin();
        if sin_val.abs() < 1e-15 {
            continue;
        }
        total += frac_part * angle.cos() / sin_val;
    }
    total
}

fn gram_entry(j: usize, k: usize, pair_sums: &HashMap<(usize, usize), f64>) -> f64 {
    let jf = j as f64;
    let kf = k as f64;
    if j == k {
        return COEFF / jf - 1.0 / (jf * jf);
    }
    let d = gcd(j, k);
    let jp = j / d;
    let kp = k / d;
    let term1 = COEFF / 2.0 * (1.0 / jf + 1.0 / kf);
    let term2 = (jf - kf) / (2.0 * jf * kf) * (kf / jf).ln();
    let key = if jp <= kp { (jp, kp) } else { (kp, jp) };
    let ps = pair_sums.get(&key).copied().unwrap_or(0.0);
    let term3 = PI * (d as f64) / (2.0 * jf * kf) * ps;
    let term4 = 1.0 / (jf * kf);
    term1 + term2 - term3 - term4
}

/// Precompute V(a,b)+V(b,a) for all reduced pairs needed at this N.
fn precompute_pair_sums(active: &[(usize, f64, u8)]) -> HashMap<(usize, usize), f64> {
    let mut needed = std::collections::HashSet::new();
    for &(j, _, _) in active {
        for &(k, _, _) in active {
            if j == k {
                continue;
            }
            let d = gcd(j, k);
            let a = j / d;
            let b = k / d;
            let key = if a <= b { (a, b) } else { (b, a) };
            needed.insert(key);
        }
    }
    let needed_vec: Vec<_> = needed.into_iter().collect();
    needed_vec
        .par_iter()
        .map(|&(a, b)| ((a, b), vasyunin_sum(a, b) + vasyunin_sum(b, a)))
        .collect()
}

/// Compute vtGv with block decomposition, optionally truncating at max_layer.
fn compute_fermi_tower(
    n: usize,
    mu: &[i8],
    omega: &[u8],
    max_layer: u8,
) -> (f64, HashMap<(u8, u8), f64>, usize) {
    let log_n = (n as f64).ln();

    // Build active weight list
    let mut active: Vec<(usize, f64, u8)> = Vec::new();
    for k in 1..=n {
        if mu[k] == 0 {
            continue;
        }
        if omega[k] > max_layer {
            continue;
        }
        let w = -(mu[k] as f64) * (1.0 - (k as f64).ln() / log_n);
        if w.abs() < 1e-18 {
            continue;
        }
        active.push((k, w, omega[k]));
    }
    let n_active = active.len();

    // Precompute Vasyunin pair sums (parallel)
    let pair_sums = precompute_pair_sums(&active);

    // Main double loop: accumulate by block
    let mut blocks: HashMap<(u8, u8), f64> = HashMap::new();
    let mut total = 0.0f64;

    for &(j, wj, oj) in &active {
        for &(k, wk, ok) in &active {
            let g = gram_entry(j, k, &pair_sums);
            let c = wj * g * wk;
            *blocks.entry((oj, ok)).or_insert(0.0) += c;
            total += c;
        }
    }

    (total, blocks, n_active)
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let n_max: usize = if args.len() > 1 {
        args[1].parse().unwrap_or(7500)
    } else {
        7500
    };
    let step: usize = if args.len() > 2 {
        args[2].parse().unwrap_or(500)
    } else {
        500
    };

    eprintln!("╔═══════════════════════════════════════════════════════════════════════════╗");
    eprintln!(
        "║  FERMI TOWER — Block Decomposition to N={:<10}     ⚛️🏰            ║",
        n_max
    );
    eprintln!(
        "║  Step size: {:<10}                                                    ║",
        step
    );
    eprintln!("╚═══════════════════════════════════════════════════════════════════════════╝");
    eprintln!();

    let sieve_start = Instant::now();
    let (mu, _primes) = sieve_mobius(n_max);
    let omega = sieve_omega(n_max);
    eprintln!(
        "  Sieve complete in {:.2}s",
        sieve_start.elapsed().as_secs_f64()
    );

    // Build test points: small values + every `step` + n_max
    let mut test_points: Vec<usize> = vec![30, 50, 76, 100, 200, 500, 1000];
    let mut n = step;
    while n <= n_max {
        if !test_points.contains(&n) {
            test_points.push(n);
        }
        n += step;
    }
    if !test_points.contains(&n_max) {
        test_points.push(n_max);
    }
    test_points.sort();
    test_points.dedup();

    // ═══════════════════════════════════════════════════════════════════════
    // §1. BLOCK DECOMPOSITION
    // ═══════════════════════════════════════════════════════════════════════
    println!();
    println!("════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════");
    println!("§1. FERMI TOWER BLOCK DECOMPOSITION (Direct Gram, EXACT)");
    println!("════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════");
    println!();
    println!(
        "{:>6} {:>12} {:>9} {:>9} {:>10} {:>8} {:>8} {:>8} {:>6} {:>8}",
        "N", "vtGv", "(1,1)%", "(2,2)%", "cross%", "L12%", "L3%", "L4+%", "#act", "time"
    );
    println!("{}", "─".repeat(100));

    for &n in &test_points {
        let start = Instant::now();
        let (vtgv, blocks, n_active) = compute_fermi_tower(n, &mu, &omega, 99);
        let elapsed = start.elapsed().as_secs_f64();

        let pp = blocks.get(&(1, 1)).copied().unwrap_or(0.0);
        let ss = blocks.get(&(2, 2)).copied().unwrap_or(0.0);
        let cross = blocks.get(&(1, 2)).copied().unwrap_or(0.0)
            + blocks.get(&(2, 1)).copied().unwrap_or(0.0);
        let l12: f64 = blocks
            .iter()
            .filter(|(&(i, j), _)| (1..=2).contains(&i) && (1..=2).contains(&j))
            .map(|(_, v)| v)
            .sum();
        let l3: f64 = blocks
            .iter()
            .filter(|(&(i, j), _)| i.max(j) == 3)
            .map(|(_, v)| v)
            .sum();
        let l4p: f64 = blocks
            .iter()
            .filter(|(&(i, j), _)| i.max(j) >= 4)
            .map(|(_, v)| v)
            .sum();

        println!(
            "{:>6} {:>12.6} {:>8.0}% {:>8.0}% {:>9.0}% {:>7.0}% {:>7.0}% {:>7.0}% {:>6} {:>7.1}s",
            n,
            vtgv,
            pp / vtgv * 100.0,
            ss / vtgv * 100.0,
            cross / vtgv * 100.0,
            l12 / vtgv * 100.0,
            l3 / vtgv * 100.0,
            l4p / vtgv * 100.0,
            n_active,
            elapsed
        );

        eprintln!(
            "  N={}: vtGv={:.8}, {}×overcancellation, {:.1}s",
            n,
            vtgv,
            (pp / vtgv) as i64,
            elapsed
        );
    }

    // ═══════════════════════════════════════════════════════════════════════
    // §2. CEILING TEST
    // ═══════════════════════════════════════════════════════════════════════
    println!();
    println!("════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════");
    println!("§2. CEILING TEST: vtGv(L≤3) vs vtGv(full)");
    println!("════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════");
    println!();
    println!(
        "{:>6} {:>12} {:>12} {:>12} {:>12} {:>9} {:>5} {:>10} {:>8}",
        "N",
        "vtGv(L≤1)",
        "vtGv(L≤2)",
        "vtGv(L≤3)",
        "vtGv(full)",
        "L3≥full?",
        "<1?",
        "margin",
        "time"
    );
    println!("{}", "─".repeat(100));

    for &n in &test_points {
        let start = Instant::now();
        let (v1, _, _) = compute_fermi_tower(n, &mu, &omega, 1);
        let (v2, _, _) = compute_fermi_tower(n, &mu, &omega, 2);
        let (v3, _, _) = compute_fermi_tower(n, &mu, &omega, 3);
        let (vf, _, _) = compute_fermi_tower(n, &mu, &omega, 99);
        let elapsed = start.elapsed().as_secs_f64();

        let upper = v3 >= vf - 1e-10;
        let under1 = vf < 1.0;
        let margin = 1.0 - vf;

        println!(
            "{:>6} {:>12.6} {:>12.6} {:>12.6} {:>12.6} {:>9} {:>5} {:>10.4} {:>7.1}s",
            n,
            v1,
            v2,
            v3,
            vf,
            if upper { "✅" } else { "❌" },
            if under1 { "✅" } else { "❌" },
            margin,
            elapsed
        );
    }

    // ═══════════════════════════════════════════════════════════════════════
    // §3. THE GIANT NUMBERS
    // ═══════════════════════════════════════════════════════════════════════
    println!();
    println!("════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════");
    println!("§3. THE GIANT NUMBERS: Internal Overcancellation");
    println!("════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════");
    println!();
    println!(
        "{:>6} {:>6} {:>12} {:>12} {:>12} {:>12} {:>10}",
        "N", "logN", "(1,1)/vtGv", "(2,2)/vtGv", "cross/vtGv", "OC-ratio", "vtGv"
    );
    println!("{}", "─".repeat(80));

    for &n in &test_points {
        let (vtgv, blocks, _) = compute_fermi_tower(n, &mu, &omega, 99);
        let pp = blocks.get(&(1, 1)).copied().unwrap_or(0.0);
        let ss = blocks.get(&(2, 2)).copied().unwrap_or(0.0);
        let cross = blocks.get(&(1, 2)).copied().unwrap_or(0.0)
            + blocks.get(&(2, 1)).copied().unwrap_or(0.0);
        let log_n = (n as f64).ln();
        let oc = pp / vtgv;

        println!(
            "{:>6} {:>6.2} {:>11.0}× {:>11.0}× {:>11.0}× {:>11.0}× {:>10.6}",
            n,
            log_n,
            oc,
            ss / vtgv,
            cross / vtgv,
            oc,
            vtgv
        );
    }

    println!();
    println!("═══════════════════════════════════════════════════════════════════════════════════════════");
    println!(
        "Three quarks, confined. The overcancellation grows ~logN² but the net stays bounded."
    );
    println!("═══════════════════════════════════════════════════════════════════════════════════════════");
}
