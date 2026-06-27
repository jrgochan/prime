//! # Path 1e Analytics — Large-N Component Asymptotics
//!
//! Measures the full 5-term + 2-layer decomposition at Rust speed:
//!   vtGv = [diag + eLog + eRatio − eConst] − [L0 + L1]
//!        = nonCot − S_eCot
//!
//! Runs up to N = 10,000+ with parallel Vasyunin sum computation.
//!
//! Cathedral — Path 1e Analytic Graduation — June 4, 2026

use rayon::prelude::*;
use std::collections::HashMap;
use std::f64::consts::PI;
use std::time::Instant;

const EULER_GAMMA: f64 = 0.5772156649015329;
const LN_2PI: f64 = 1.8378770664093453;

fn sieve_mobius(n: usize) -> Vec<i8> {
    let mut mu = vec![0i8; n + 1];
    mu[1] = 1;
    let mut is_prime = vec![true; n + 1];
    let mut primes = Vec::new();
    for i in 2..=n {
        if is_prime[i] { primes.push(i); mu[i] = -1; }
        for &p in &primes {
            if i * p > n { break; }
            is_prime[i * p] = false;
            if i % p == 0 { mu[i * p] = 0; break; }
            else { mu[i * p] = -mu[i]; }
        }
    }
    mu
}

fn gcd(mut a: usize, mut b: usize) -> usize {
    while b != 0 { let t = b; b = a % b; a = t; }
    a
}

fn vasyunin_sum(a: usize, b: usize) -> f64 {
    if a <= 1 { return 0.0; }
    let af = a as f64;
    let bf = b as f64;
    let mut total = 0.0;
    for m in 1..a {
        let mf = m as f64;
        let mut frac_part = (mf * bf / af).fract();
        if frac_part < 0.0 { frac_part += 1.0; }
        let angle = PI * mf / af;
        let sin_val = angle.sin();
        if sin_val.abs() < 1e-15 { continue; }
        total += frac_part * angle.cos() / sin_val;
    }
    total
}

fn gram_diagonal(j: usize) -> f64 {
    let jf = j as f64;
    (LN_2PI - EULER_GAMMA) / jf - 1.0 / (jf * jf)
}

fn bd_weights(n: usize, mu: &[i8]) -> Vec<f64> {
    let log_n = (n as f64).ln();
    (0..n - 1)
        .map(|i| {
            let j = i + 1;
            if mu[j] == 0 { 0.0 }
            else { -(mu[j] as f64) * (1.0 - (j as f64).ln() / log_n) }
        })
        .collect()
}

fn precompute_pair_sums(n: usize, mu: &[i8]) -> HashMap<(usize, usize), f64> {
    let mut needed: Vec<(usize, usize)> = Vec::new();
    let mut seen = std::collections::HashSet::new();
    for j in 1..n {
        if mu[j] == 0 { continue; }
        for k in 1..n {
            if j == k || mu[k] == 0 { continue; }
            let d = gcd(j, k);
            let a = j / d; let b = k / d;
            let key = if a <= b { (a, b) } else { (b, a) };
            if seen.insert(key) { needed.push(key); }
        }
    }
    needed.par_iter()
        .map(|&(a, b)| ((a, b), vasyunin_sum(a, b) + vasyunin_sum(b, a)))
        .collect()
}

/// Abel partial sum A(x) = Σ_{k≤x} μ(k)/k
fn abel_partial_sums(n: usize, mu: &[i8]) -> (f64, f64) {
    let mut a_x = 0.0f64;
    let mut max_a = 0.0f64;
    let mut max_a_skip1 = 0.0f64; // max|A(x)| for x ≥ 2
    for k in 1..=n {
        a_x += mu[k] as f64 / k as f64;
        max_a = max_a.max(a_x.abs());
        if k >= 2 {
            max_a_skip1 = max_a_skip1.max(a_x.abs());
        }
    }
    (max_a, max_a_skip1)
}

#[derive(Clone)]
struct FullResult {
    n: usize,
    diag: f64,
    off_elog: f64,
    off_eratio: f64,
    off_econst: f64,
    off_noncot: f64,
    noncot: f64,
    l0: f64,        // odd-gcd cotangent layer
    l1: f64,        // 2||gcd cotangent layer
    s_ecot: f64,    // L0 + L1
    vtgv: f64,
    c_prime: f64,   // nonCot - L1
    margin: f64,    // 1 - vtGv
    max_abel: f64,
    max_abel_skip1: f64,
    elapsed: f64,
}

fn analyze_full(n: usize) -> FullResult {
    let t0 = Instant::now();
    let mu = sieve_mobius(n);
    let v = bd_weights(n, &mu);
    let dim = v.len();

    // Diagonal
    let diag: f64 = (0..dim)
        .map(|i| v[i] * v[i] * gram_diagonal(i + 1))
        .sum();

    // Precompute Vasyunin pair sums
    let pair_sums = precompute_pair_sums(n, &mu);

    // Off-diagonal: parallel by row
    // Returns (eLog, eRatio, eConst, L0, L1) per row
    let row_results: Vec<(f64, f64, f64, f64, f64)> = (0..dim)
        .into_par_iter()
        .filter(|&i| v[i] != 0.0)
        .map(|i| {
            let j = i + 1;
            let jf = j as f64;
            let mut row_elog = 0.0;
            let mut row_eratio = 0.0;
            let mut row_econst = 0.0;
            let mut row_l0 = 0.0;
            let mut row_l1 = 0.0;

            for k_idx in 0..dim {
                if k_idx == i || v[k_idx] == 0.0 { continue; }
                let k = k_idx + 1;
                let kf = k as f64;
                let w = v[i] * v[k_idx];

                // eLog: (ln2π−γ)/2 · (1/j + 1/k)
                row_elog += w * (LN_2PI - EULER_GAMMA) / 2.0 * (1.0 / jf + 1.0 / kf);
                // eRatio: (j-k)/(2jk) · ln(k/j)
                row_eratio += w * (jf - kf) / (2.0 * jf * kf) * (kf / jf).ln();
                // eConst: 1/(jk)
                row_econst += w / (jf * kf);

                // Cotangent part
                let d = gcd(j, k);
                let jp = j / d;
                let kp = k / d;
                let key = if jp <= kp { (jp, kp) } else { (kp, jp) };
                let ps = pair_sums.get(&key).copied().unwrap_or(0.0);
                let cot_contrib = w * PI * (d as f64) / (2.0 * jf * kf) * ps;

                // Layer classification
                if d % 2 == 1 {
                    row_l0 += cot_contrib;  // odd gcd → layer 0
                } else if !d.is_multiple_of(4) {
                    row_l1 += cot_contrib;  // 2||d → layer 1
                }
                // d % 4 == 0 → layer ≥ 2, should be ≈0 for BD weights
            }

            (row_elog, row_eratio, row_econst, row_l0, row_l1)
        })
        .collect();

    // Merge
    let mut off_elog = 0.0;
    let mut off_eratio = 0.0;
    let mut off_econst = 0.0;
    let mut l0 = 0.0;
    let mut l1 = 0.0;
    for &(el, er, ec, r0, r1) in &row_results {
        off_elog += el;
        off_eratio += er;
        off_econst += ec;
        l0 += r0;
        l1 += r1;
    }

    let off_noncot = off_elog + off_eratio - off_econst;
    let noncot = diag + off_noncot;
    let s_ecot = l0 + l1;
    let vtgv = noncot - s_ecot;

    // Abel errors
    let (max_abel, max_abel_skip1) = abel_partial_sums(n, &mu);

    FullResult {
        n, diag, off_elog, off_eratio, off_econst, off_noncot,
        noncot, l0, l1, s_ecot, vtgv,
        c_prime: noncot - l1,
        margin: 1.0 - vtgv,
        max_abel, max_abel_skip1,
        elapsed: t0.elapsed().as_secs_f64(),
    }
}

fn main() {
    println!("═══════════════════════════════════════════════════════════════════════════════════════════════════════");
    println!("  PATH 1e ANALYTIC GRADUATION — Large-N Component Asymptotics 🏛️");
    println!("  vtGv = [diag + eLog + eRatio − eConst] − [L0 + L1]");
    println!("  Cores: {}", rayon::current_num_threads());
    println!("═══════════════════════════════════════════════════════════════════════════════════════════════════════");

    // Highly composite numbers + round numbers for smooth curves
    let ns: Vec<usize> = vec![
        60, 120, 180, 240, 360, 480, 720, 840, 1000, 1260,
        1500, 1680, 2000, 2520, 3000, 3600, 4200, 5040, 6000, 7560,
    ];

    println!("\n§1. FULL 5+2 DECOMPOSITION");
    println!("──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────");
    println!(
        "{:>6} │ {:>9} │ {:>9} │ {:>9} │ {:>9} │ {:>9} │ {:>9} │ {:>9} │ {:>9} │ {:>8} │ {:>5}",
        "N", "diag", "eLog", "eRatio", "eConst", "nonCot", "L0", "L1", "vtGv", "1-vtGv", "time"
    );
    println!("──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────");

    let mut results: Vec<FullResult> = Vec::new();

    for &n in &ns {
        let r = analyze_full(n);
        println!(
            "{:6} │ {:+9.5} │ {:+9.5} │ {:+9.5} │ {:+9.5} │ {:+9.5} │ {:+9.5} │ {:+9.5} │ {:+9.5} │ {:8.5} │ {:5.1}s",
            r.n, r.diag, r.off_elog, r.off_eratio, r.off_econst,
            r.noncot, r.l0, r.l1, r.vtgv, r.margin, r.elapsed
        );
        results.push(r);
    }

    // §2: Growth rates
    println!("\n§2. GROWTH RATES (× lnN)");
    println!("──────────────────────────────────────────────────────────────────────────────────────────────");
    println!(
        "{:>6} │ {:>10} │ {:>12} │ {:>10} │ {:>10} │ {:>12} │ {:>10}",
        "N", "diag·lnN", "nonCot·lnN", "L0·lnN", "L1·lnN", "S_eCot·lnN", "vtGv·lnN"
    );
    println!("──────────────────────────────────────────────────────────────────────────────────────────────");
    for r in &results {
        let ln_n = (r.n as f64).ln();
        println!(
            "{:6} │ {:10.5} │ {:12.5} │ {:10.5} │ {:10.5} │ {:12.5} │ {:10.5}",
            r.n, r.diag * ln_n, r.noncot * ln_n, r.l0 * ln_n, r.l1 * ln_n,
            r.s_ecot * ln_n, r.vtgv * ln_n
        );
    }

    // §3: Path 1e certificates
    println!("\n§3. PATH 1e CERTIFICATES");
    println!("──────────────────────────────────────────────────────────────────────────────────────────────");
    println!(
        "{:>6} │ {:>9} │ {:>9} │ {:>12} │ {:>9} │ {:>5} │ {:>9} │ {:>8}",
        "N", "nonCot", "L1", "C'=nC-L1", "L0", "L0≥0", "vtGv", "margin"
    );
    println!("──────────────────────────────────────────────────────────────────────────────────────────────");
    for r in &results {
        let l0_ok = if r.l0 >= 0.0 { "✅" } else { "❌" };
        println!(
            "{:6} │ {:+9.5} │ {:+9.5} │ {:12.6} │ {:+9.5} │ {:>5} │ {:+9.5} │ {:8.5}",
            r.n, r.noncot, r.l1, r.c_prime, r.l0, l0_ok, r.vtgv, r.margin
        );
    }

    // §4: Shadow absorption ratio
    println!("\n§4. RATIO ANALYSIS");
    println!("──────────────────────────────────────────────────────────────────────────────────────────────");
    println!(
        "{:>6} │ {:>12} │ {:>12} │ {:>12} │ {:>12}",
        "N", "S_eCot/nonCot", "L0/S_eCot", "L1/S_eCot", "vtGv/nonCot"
    );
    println!("──────────────────────────────────────────────────────────────────────────────────────────────");
    for r in &results {
        let ecot_ratio = if r.noncot.abs() > 1e-15 { r.s_ecot / r.noncot } else { 0.0 };
        let l0_frac = if r.s_ecot.abs() > 1e-15 { r.l0 / r.s_ecot } else { 0.0 };
        let l1_frac = if r.s_ecot.abs() > 1e-15 { r.l1 / r.s_ecot } else { 0.0 };
        let vtgv_ratio = if r.noncot.abs() > 1e-15 { r.vtgv / r.noncot } else { 0.0 };
        println!(
            "{:6} │ {:12.6} │ {:12.6} │ {:12.6} │ {:12.6}",
            r.n, ecot_ratio, l0_frac, l1_frac, vtgv_ratio
        );
    }

    // §5: Abel errors
    println!("\n§5. ABEL PARTIAL SUM ERRORS");
    println!("──────────────────────────────────────────────────────────────────────────────────────────────");
    println!(
        "{:>6} │ {:>12} │ {:>14} │ {:>12}",
        "N", "max|A(x)|", "max|A(x)|,x≥2", "decay rate"
    );
    println!("──────────────────────────────────────────────────────────────────────────────────────────────");
    for r in &results {
        let decay = if r.max_abel_skip1 > 0.0 {
            format!("{:.4}", r.max_abel_skip1 * (r.n as f64).ln())
        } else {
            "—".to_string()
        };
        println!(
            "{:6} │ {:12.6} │ {:14.6} │ {:>12}",
            r.n, r.max_abel, r.max_abel_skip1, decay
        );
    }

    // §6: vtGv·lnN and vtGv·ln²N to detect true growth rate
    println!("\n§6. TRUE GROWTH RATE OF vtGv");
    println!("──────────────────────────────────────────────────────────────────────────────────────────────");
    println!(
        "{:>6} │ {:>8} │ {:>10} │ {:>10} │ {:>10} │ {:>12}",
        "N", "vtGv", "vtGv·lnN", "vtGv·ln²N", "1-vtGv", "(1-vtGv)·lnN"
    );
    println!("──────────────────────────────────────────────────────────────────────────────────────────────");
    for r in &results {
        let ln_n = (r.n as f64).ln();
        println!(
            "{:6} │ {:8.5} │ {:10.5} │ {:10.4} │ {:10.5} │ {:12.5}",
            r.n, r.vtgv, r.vtgv * ln_n, r.vtgv * ln_n * ln_n,
            r.margin, r.margin * ln_n
        );
    }

    // §7: Verdict
    println!("\n═══════════════════════════════════════════════════════════════════════════════════════════════════════");
    println!("  VERDICT");
    println!("═══════════════════════════════════════════════════════════════════════════════════════════════════════");

    let last = results.last().unwrap();
    let first = results.first().unwrap();

    // vtGv growth rate
    let vtgv_growth = last.vtgv / first.vtgv;
    let logn_growth = (last.n as f64).ln() / (first.n as f64).ln();

    println!("\n  vtGv growth: {:.5} → {:.5} (×{:.3}, logN ×{:.3})",
        first.vtgv, last.vtgv, vtgv_growth, logn_growth);

    if vtgv_growth < logn_growth * 0.8 {
        println!("  → vtGv grows SUBLOGARITHMICALLY ✅ (likely O(1))");
    } else if vtgv_growth < logn_growth * 1.2 {
        println!("  → vtGv grows ≈ O(logN) ⚠️  (borderline)");
    } else {
        println!("  → vtGv grows SUPERLOGARITHMICALLY ❌");
    }

    // Margin analysis
    let max_vtgv = results.iter().map(|r| r.vtgv).fold(f64::NEG_INFINITY, f64::max);
    let min_margin = results.iter().map(|r| r.margin).fold(f64::INFINITY, f64::min);

    println!("\n  Max vtGv across all N: {:.6}", max_vtgv);
    println!("  Min margin (1-vtGv):   {:.6} ({:.1}%)", min_margin, min_margin * 100.0);
    println!("  vtGv < 1 for all N?    {}", if max_vtgv < 1.0 { "✅ YES" } else { "❌ NO" });

    // S_eCot positivity
    let all_ecot_pos = results.iter().all(|r| r.s_ecot > 0.0);
    let min_ecot = results.iter().map(|r| r.s_ecot).fold(f64::INFINITY, f64::min);
    println!("\n  S_eCot > 0 for all N?  {} (min: {:.6})", 
        if all_ecot_pos { "✅ YES" } else { "❌ NO" }, min_ecot);

    // Ratio stability
    let ratios: Vec<f64> = results.iter()
        .filter(|r| r.noncot.abs() > 1e-10)
        .map(|r| r.s_ecot / r.noncot)
        .collect();
    if !ratios.is_empty() {
        let mean_ratio: f64 = ratios.iter().sum::<f64>() / ratios.len() as f64;
        let var_ratio: f64 = ratios.iter().map(|r| (r - mean_ratio).powi(2)).sum::<f64>() / ratios.len() as f64;
        println!("\n  S_eCot/nonCot ratio: mean={:.4}, std={:.4}", mean_ratio, var_ratio.sqrt());
        println!("  vtGv/nonCot ratio:   mean={:.4}", 
            results.iter().filter(|r| r.noncot.abs() > 1e-10)
                .map(|r| r.vtgv / r.noncot).sum::<f64>() / ratios.len() as f64);
    }

    // Abel feasibility
    println!("\n  BILINEAR ABEL (refined, skipping k=1):");
    println!("    max|A(x)| for x≥2: {:.6}", last.max_abel_skip1);
    println!("    This is the effective Abel error for the k≥2 bilinear sum.");

    println!("\n═══════════════════════════════════════════════════════════════════════════════════════════════════════");
}
