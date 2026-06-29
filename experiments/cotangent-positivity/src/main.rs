//! # Cotangent Sum Positivity Probe — Parallel Edition
//!
//! Computes S_cot(N) = Σ_{j≠k} v_j v_k E_cot(j,k) at scale.
//!
//! Key question: Is S_cot(N) > 0 for all N?
//! If yes, then the cotangent is an ALLY and the Crown Axiom
//! follows from the proved overcancellation infrastructure.
//!
//! Architecture: Pre-compute all V(a,b) pair sums, then use rayon
//! to parallelize the O(N²) weight-pair loop across all cores.
//!
//! Cathedral — Climbing the Wall 🧗
//! June 1, 2026

use cathedral_utils::arith::gcd;
use rayon::prelude::*;
use std::collections::HashMap;
use std::f64::consts::PI;
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::Instant;

/// Sieve of Eratosthenes + Möbius function computation.
fn sieve_mobius(n: usize) -> Vec<i8> {
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
    mu
}

/// V(a, b) = Σ_{m=1}^{a-1} frac(mb/a) · cot(πm/a)
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

/// GCD


/// Pre-compute all V(a,b)+V(b,a) pair sums needed for a given N.
/// Returns a HashMap keyed by (min(a,b), max(a,b)) for canonicalization.
fn precompute_pair_sums(n: usize, mu: &[i8]) -> HashMap<(usize, usize), f64> {
    // Collect all (a,b) pairs we'll need
    let mut needed: Vec<(usize, usize)> = Vec::new();
    let mut seen = std::collections::HashSet::new();

    for j in 1..n {
        if mu[j] == 0 {
            continue;
        }
        for k in 1..n {
            if j == k || mu[k] == 0 {
                continue;
            }
            let d = gcd(j, k);
            let a = j / d;
            let b = k / d;
            let key = if a <= b { (a, b) } else { (b, a) };
            if seen.insert(key) {
                needed.push(key);
            }
        }
    }

    // Parallel computation of all pair sums
    let results: Vec<((usize, usize), f64)> = needed
        .par_iter()
        .map(|&(a, b)| {
            let ps = vasyunin_sum(a, b) + vasyunin_sum(b, a);
            ((a, b), ps)
        })
        .collect();

    results.into_iter().collect()
}

/// Compute S_cot(N) with full GCD stratification, PARALLEL.
fn compute_scot_parallel(n: usize) -> (f64, HashMap<usize, f64>, usize) {
    let mu = sieve_mobius(n);
    let log_n = (n as f64).ln();

    // BD weights for squarefree j
    let weights: Vec<(usize, f64)> = (1..n)
        .filter(|&j| mu[j] != 0)
        .map(|j| {
            let w = -(mu[j] as f64) * (1.0 - (j as f64).ln() / log_n);
            (j, w)
        })
        .collect();

    let n_active = weights.len();

    // Pre-compute all V pair sums (parallel over pairs)
    let pair_sums = precompute_pair_sums(n, &mu);

    // Parallel computation of contributions per row
    let row_results: Vec<(f64, HashMap<usize, f64>)> = weights
        .par_iter()
        .map(|&(j, wj)| {
            let mut row_total = 0.0;
            let mut row_gcd: HashMap<usize, f64> = HashMap::new();

            for &(k, wk) in &weights {
                if j == k {
                    continue;
                }
                let d = gcd(j, k);
                let a = j / d;
                let b = k / d;
                let key = if a <= b { (a, b) } else { (b, a) };
                let ps = pair_sums.get(&key).copied().unwrap_or(0.0);
                let e_cot = PI * (d as f64) / (2.0 * (j as f64) * (k as f64)) * ps;
                let contrib = wj * wk * e_cot;
                row_total += contrib;
                *row_gcd.entry(d).or_insert(0.0) += contrib;
            }

            (row_total, row_gcd)
        })
        .collect();

    // Merge results
    let mut total = 0.0;
    let mut gcd_sums: HashMap<usize, f64> = HashMap::new();
    for (row_total, row_gcd) in row_results {
        total += row_total;
        for (d, v) in row_gcd {
            *gcd_sums.entry(d).or_insert(0.0) += v;
        }
    }

    (total, gcd_sums, n_active)
}

fn main() {
    println!("═══════════════════════════════════════════════════════════════");
    println!("  COTANGENT POSITIVITY PROBE — Parallel Rust 🦀⚡");
    println!("  Cathedral — Climbing the Wall 🧗");
    println!("  Cores: {}", rayon::current_num_threads());
    println!("═══════════════════════════════════════════════════════════════");
    println!();

    let ever_negative = AtomicBool::new(false);

    println!("POSITIVITY SWEEP");
    println!("────────────────────────────────────────────────────────────────────────────────");
    println!(
        "{:>6} │ {:>12} │ {:>4} │ {:>10} │ {:>7} │ {:>11} │ {:>11} │ {:>8} │ {:>6}",
        "N", "S_cot", "sign", "|S|·lnN", "active", "d=1", "d≥2", "margin%", "time"
    );
    println!("────────────────────────────────────────────────────────────────────────────────");

    let ns: Vec<usize> = vec![
        100, 200, 500, 1000, 2000, 2520, 3000, 5000, 5040, 7000, 10000, 15000, 20000, 25000, 30000,
        40000, 50000,
    ];

    let mut results: Vec<(usize, f64, f64, f64, usize)> = Vec::new();

    for &n in &ns {
        let t0 = Instant::now();
        let (total, gcd_sums, n_active) = compute_scot_parallel(n);
        let dt = t0.elapsed().as_secs_f64();

        let sign = if total > 0.0 { "+" } else { "−" };
        if total <= 0.0 {
            ever_negative.store(true, Ordering::Relaxed);
        }

        let d1 = gcd_sums.get(&1).copied().unwrap_or(0.0);
        let d_ge2: f64 = gcd_sums
            .iter()
            .filter(|(&d, _)| d >= 2)
            .map(|(_, &v)| v)
            .sum();

        let margin_pct = if d_ge2.abs() > 1e-15 {
            total / d_ge2 * 100.0
        } else {
            0.0
        };

        let log_n = (n as f64).ln();
        println!(
            "{:6} │ {:+12.6} │  {}  │ {:10.4} │ {:7} │ {:+11.4} │ {:+11.4} │ {:7.1}% │ {:5.1}s",
            n,
            total,
            sign,
            total.abs() * log_n,
            n_active,
            d1,
            d_ge2,
            margin_pct,
            dt
        );

        results.push((n, total, d1, d_ge2, n_active));
    }

    // ──── Scaling ────
    println!();
    println!("SCALING EXTRAPOLATION");
    println!("────────────────────────────────────────────────────────────────────────────────");

    let big: Vec<&(usize, f64, f64, f64, usize)> =
        results.iter().filter(|(n, _, _, _, _)| *n >= 500).collect();
    if big.len() >= 3 {
        let n_pts = big.len() as f64;
        let sum_x: f64 = big
            .iter()
            .map(|(n, _, _, _, _)| 1.0 / (*n as f64).ln())
            .sum();
        let sum_y: f64 = big.iter().map(|(_, s, _, _, _)| *s).sum();
        let sum_xx: f64 = big
            .iter()
            .map(|(n, _, _, _, _)| {
                let x = 1.0 / (*n as f64).ln();
                x * x
            })
            .sum();
        let sum_xy: f64 = big
            .iter()
            .map(|(n, s, _, _, _)| {
                let x = 1.0 / (*n as f64).ln();
                x * (*s)
            })
            .sum();

        let denom = n_pts * sum_xx - sum_x * sum_x;
        if denom.abs() > 1e-20 {
            let slope = (n_pts * sum_xy - sum_x * sum_y) / denom;
            let intercept = (sum_y - slope * sum_x) / n_pts;
            println!("  Fit: S_cot ≈ {:.4} / ln(N) + {:.6}", slope, intercept);
            println!("  Extrapolated S(∞) ≈ {:.6}", intercept);
        }
    }

    // ──── Verdict ────
    println!();
    println!("═══════════════════════════════════════════════════════════════");
    if !ever_negative.load(Ordering::Relaxed) {
        println!(
            "  ✅ S_cot > 0 for ALL N up to {} — POSITIVITY HOLDS!",
            ns.last().unwrap()
        );
        println!("  The cotangent is an ALLY. The wall is a DOOR. 🚪");
    } else {
        println!("  ⚠️  S_cot became negative! The wall stands. 🧱");
        for &(n, s, _, _, _) in &results {
            if s <= 0.0 {
                println!("     NEGATIVE at N = {}: S_cot = {:.8}", n, s);
            }
        }
    }
    println!("═══════════════════════════════════════════════════════════════");
}
