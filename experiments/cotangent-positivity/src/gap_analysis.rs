//! # Gap Analysis v2 — CORRECT Vasyunin Formula
//!
//! Uses the EXACT Vasyunin-Báez-Duarte Gram entry:
//!   G(j,k) = (ln(2π) - γ)/2 · (1/j + 1/k) + (j-k)/(2jk) · ln(k/j)
//!            - π·d/(2jk) · (V(j',k') + V(k',j')) - 1/(jk)
//!   G(j,j) = (ln(2π) - γ)/j - 1/j²
//!
//! Decomposes: vtGv = nonCot - S_cot
//! where nonCot = diag + offDiag_noncot (everything except -eCot)
//!
//! Cathedral — Climbing the Wall 🧗 — June 1, 2026

use cathedral_utils::arith::gcd;
use rayon::prelude::*;
use std::collections::HashMap;
use std::f64::consts::PI;
use std::time::Instant;

const EULER_GAMMA: f64 = 0.5772156649015329;
const LN_2PI: f64 = 1.8378770664093453; // ln(2π)

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

/// CORRECT diagonal Gram entry: G(j,j) = (ln(2π) - γ)/j - 1/j²
fn gram_diagonal(j: usize) -> f64 {
    let jf = j as f64;
    (LN_2PI - EULER_GAMMA) / jf - 1.0 / (jf * jf)
}

/// Non-cotangent part of the off-diagonal: term1 + term2 - term4
/// G(j,k) = term1 + term2 - term3 - term4
/// where term3 = π·d/(2jk)·(V+V) is the cotangent part
fn gram_offdiag_noncot(j: usize, k: usize) -> f64 {
    let jf = j as f64;
    let kf = k as f64;
    let term1 = (LN_2PI - EULER_GAMMA) / 2.0 * (1.0 / jf + 1.0 / kf);
    let term2 = (jf - kf) / (2.0 * jf * kf) * (kf / jf).ln();
    let term4 = 1.0 / (jf * kf);
    term1 + term2 - term4
}

/// Cotangent part of the off-diagonal: π·d/(2jk)·(V(j',k') + V(k',j'))
fn gram_offdiag_cot(j: usize, k: usize, pair_sums: &HashMap<(usize, usize), f64>) -> f64 {
    let d = gcd(j, k);
    let jp = j / d;
    let kp = k / d;
    let key = if jp <= kp { (jp, kp) } else { (kp, jp) };
    let ps = pair_sums.get(&key).copied().unwrap_or(0.0);
    PI * (d as f64) / (2.0 * j as f64 * k as f64) * ps
}

fn bd_weights(n: usize, mu: &[i8]) -> Vec<f64> {
    let log_n = (n as f64).ln();
    (0..n - 1)
        .map(|i| {
            let j = i + 1;
            if mu[j] == 0 {
                0.0
            } else {
                -(mu[j] as f64) * (1.0 - (j as f64).ln() / log_n)
            }
        })
        .collect()
}

fn precompute_pair_sums(n: usize, mu: &[i8]) -> HashMap<(usize, usize), f64> {
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
    needed
        .par_iter()
        .map(|&(a, b)| ((a, b), vasyunin_sum(a, b) + vasyunin_sum(b, a)))
        .collect()
}

struct GapResult {
    n: usize,
    diag: f64,
    off_noncot: f64,
    off_cot: f64,
    noncot: f64,
    vtgv: f64,
    d1: f64,
    d_ge2: f64,
    elapsed: f64,
}

fn analyze_gaps(n: usize) -> GapResult {
    let t0 = Instant::now();
    let mu = sieve_mobius(n);
    let v = bd_weights(n, &mu);
    let dim = v.len();

    // Diagonal: Σ v_j² · G(j,j)
    let diag: f64 = (0..dim).map(|i| v[i] * v[i] * gram_diagonal(i + 1)).sum();

    // Pre-compute pair sums
    let pair_sums = precompute_pair_sums(n, &mu);

    // Off-diagonal: parallel by row
    let row_results: Vec<(f64, f64, HashMap<usize, f64>)> = (0..dim)
        .into_par_iter()
        .filter(|&i| v[i] != 0.0)
        .map(|i| {
            let j = i + 1;
            let mut row_noncot = 0.0;
            let mut row_cot = 0.0;
            let mut row_strata: HashMap<usize, f64> = HashMap::new();

            for k_idx in 0..dim {
                if k_idx == i || v[k_idx] == 0.0 {
                    continue;
                }
                let k = k_idx + 1;

                // Non-cot part
                row_noncot += v[i] * v[k_idx] * gram_offdiag_noncot(j, k);

                // Cot part
                let cot_val = gram_offdiag_cot(j, k, &pair_sums);
                let cot_contrib = v[i] * v[k_idx] * cot_val;
                row_cot += cot_contrib;

                // GCD stratum tracking
                let d = gcd(j, k);
                *row_strata.entry(d).or_insert(0.0) += cot_contrib;
            }

            (row_noncot, row_cot, row_strata)
        })
        .collect();

    // Merge
    let mut off_noncot = 0.0;
    let mut off_cot = 0.0;
    let mut gcd_strata: HashMap<usize, f64> = HashMap::new();
    for (nc, ct, strata) in &row_results {
        off_noncot += nc;
        off_cot += ct;
        for (&d, &val) in strata {
            *gcd_strata.entry(d).or_insert(0.0) += val;
        }
    }

    // vtGv = diag + off_noncot - off_cot
    // nonCot = diag + off_noncot  (everything except the -eCot)
    let noncot = diag + off_noncot;
    let vtgv = noncot - off_cot;

    let d1 = gcd_strata.get(&1).copied().unwrap_or(0.0);
    let d_ge2: f64 = gcd_strata
        .iter()
        .filter(|(&d, _)| d >= 2)
        .map(|(_, &v)| v)
        .sum();

    GapResult {
        n,
        diag,
        off_noncot,
        off_cot,
        noncot,
        vtgv,
        d1,
        d_ge2,
        elapsed: t0.elapsed().as_secs_f64(),
    }
}

fn main() {
    println!("═══════════════════════════════════════════════════════════════════════════════");
    println!("  GAP ANALYSIS v2 — Correct Vasyunin Formula 🧗");
    println!("  G(j,j) = (ln(2π)-γ)/j - 1/j²");
    println!("  G(j,k) = (ln(2π)-γ)/2·(1/j+1/k) + (j-k)/(2jk)·ln(k/j) - π·d·(V+V)/(2jk) - 1/(jk)");
    println!("  Cores: {}", rayon::current_num_threads());
    println!("═══════════════════════════════════════════════════════════════════════════════");
    println!();

    println!("FULL DECOMPOSITION: vtGv = nonCot - S_cot");
    println!("──────────────────────────────────────────────────────────────────────────────────────────");
    println!(
        "{:>6} │ {:>10} │ {:>10} │ {:>10} │ {:>10} │ {:>10} │ {:>10} │ {:>6}",
        "N", "diag", "off_noncot", "S_cot", "nonCot", "vtGv", "1-nonCot", "time"
    );
    println!("──────────────────────────────────────────────────────────────────────────────────────────");

    let ns: Vec<usize> = vec![
        60, 120, 180, 240, 360, 480, 720, 840, 1000, 1260,
        // Extended sweep: HC numbers up to 55440 (where we have .h5 Gram data)
        25200, 27720, 30240, 40320, 55440,
    ];

    let mut results: Vec<GapResult> = Vec::new();
    let mut all_noncot_lt1 = true;
    let mut all_scot_pos = true;

    for &n in &ns {
        let r = analyze_gaps(n);
        let gap = 1.0 - r.noncot;
        if r.noncot >= 1.0 {
            all_noncot_lt1 = false;
        }
        if r.off_cot <= 0.0 {
            all_scot_pos = false;
        }

        println!(
            "{:6} │ {:+10.6} │ {:+10.6} │ {:+10.6} │ {:+10.6} │ {:+10.6} │ {:+10.6} │ {:5.1}s",
            r.n, r.diag, r.off_noncot, r.off_cot, r.noncot, r.vtgv, gap, r.elapsed
        );
        results.push(r);
    }

    // S_cot GCD strata
    println!();
    println!("S_cot GCD STRATA");
    println!("──────────────────────────────────────────────────────────────────────────────────────────");
    for r in &results {
        if r.n <= 5040 {
            let margin = if r.d_ge2.abs() > 1e-15 {
                r.off_cot / r.d_ge2 * 100.0
            } else {
                0.0
            };
            println!(
                "N={:>5}: S_cot={:+.6}  d=1={:+.6}  d≥2={:+.6}  margin={:.1}%",
                r.n, r.off_cot, r.d1, r.d_ge2, margin
            );
        }
    }

    // Scaling
    println!();
    println!("SCALING: nonCot·lnN and S_cot·lnN");
    println!("──────────────────────────────────────────────────────────────────────────────────────────");
    for r in &results {
        let log_n = (r.n as f64).ln();
        println!(
            "N={:>5}: nonCot·lnN={:+8.4}  S_cot·lnN={:+8.4}  vtGv·lnN={:+8.4}  diag·lnN={:+8.4}",
            r.n,
            r.noncot * log_n,
            r.off_cot * log_n,
            r.vtgv * log_n,
            r.diag * log_n
        );
    }

    // Cross-check: vtGv should match known values
    println!();
    println!("CROSS-CHECK: vtGv ≈ d²·||v||² (should match .h5 data)");
    println!("──────────────────────────────────────────────────────────────────────────────────────────");
    for r in &results {
        let mu = sieve_mobius(r.n);
        let v = bd_weights(r.n, &mu);
        let vnorm2: f64 = v.iter().map(|x| x * x).sum();
        let d2 = r.vtgv / vnorm2;
        println!(
            "N={:>5}: vtGv={:+10.6}  ||v||²={:.4}  d²=vtGv/||v||²={:.8}",
            r.n, r.vtgv, vnorm2, d2
        );
    }

    // Verdict
    println!();
    println!("═══════════════════════════════════════════════════════════════════════════════");
    let max_noncot = results
        .iter()
        .map(|r| r.noncot)
        .fold(f64::NEG_INFINITY, f64::max);
    let min_scot = results
        .iter()
        .map(|r| r.off_cot)
        .fold(f64::INFINITY, f64::min);

    println!(
        "  Gap 1: max nonCot = {:.6}  → {}",
        max_noncot,
        if all_noncot_lt1 {
            "✅ nonCot < 1 for ALL N!"
        } else {
            "⚠️  nonCot ≥ 1 at some N"
        }
    );
    println!(
        "  Gap 2: min S_cot  = {:.6}  → {}",
        min_scot,
        if all_scot_pos {
            "✅ S_cot > 0 for ALL N!"
        } else {
            "⚠️  S_cot ≤ 0 at some N"
        }
    );

    if all_noncot_lt1 && all_scot_pos {
        println!();
        println!(
            "  🏆 BOTH GAPS HOLD for all tested N ≤ {}!",
            results.last().unwrap().n
        );
        println!("  The wall has handholds. The top is in sight! 🧗");
    } else if all_scot_pos {
        println!();
        println!("  S_cot > 0 ✅ — the cotangent is an ally!");
        if !all_noncot_lt1 {
            println!("  nonCot ≥ 1 ⚠️  — need to check the decomposition sign convention.");
            println!("  Note: if nonCot > 1 but vtGv < 1, it means S_cot > nonCot - 1,");
            println!("  i.e. the cotangent cancels enough to push vtGv below 1.");
        }
    }
    println!("═══════════════════════════════════════════════════════════════════════════════");
}
