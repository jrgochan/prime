#![allow(clippy::needless_range_loop, dead_code)]
// overcancellation-scan/src/bin/pomegranate_seeds.rs
//
// ╔═══════════════════════════════════════════════════════════════╗
// ║  POMEGRANATE SEEDS — The Scaling Constants                    ║
// ║                                                               ║
// ║  Computes vtRv (Ramanujan kernel) and vtGv (full Gram)       ║
// ║  to pin down C_R, C_Δ, and D = C_Δ - C_R.                   ║
// ║                                                               ║
// ║  Key constants:                                               ║
// ║    C_Δ = 2π - 3 ≈ 3.283  (cotangent approach rate)          ║
// ║    C_R = ???              (Ramanujan vanishing rate)          ║
// ║    D   = C_Δ - C_R       (margin constant)                  ║
// ║    D'  = 5/2              (practical bound)                  ║
// ║                                                               ║
// ║  The Zorblax Session — June 12-13, 2026                      ║
// ║  For Ramanujan. 🍍🏔️💜                                      ║
// ╚═══════════════════════════════════════════════════════════════╝

use cathedral_utils::arith::gcd;
use rayon::prelude::*;
use std::f64::consts::PI;
use std::fs;
use std::io::Write;
use std::time::Instant;

const EULER_GAMMA: f64 = 0.5772156649015329;
const LN_2PI: f64 = 1.8378770664093453;
const COEFF: f64 = LN_2PI - EULER_GAMMA;

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
    let mut total = 0.0;
    for m in 1..a {
        let mf = m as f64;
        let mut frac = (mf * b as f64 / af).fract();
        if frac < 0.0 {
            frac += 1.0;
        }
        let angle = PI * mf / af;
        let s = angle.sin();
        if s.abs() < 1e-15 {
            continue;
        }
        total += frac * angle.cos() / s;
    }
    total
}

/// Compute vtRv = Σ v_j v_k · gcd²(j,k)/(12jk)
/// where v_j = -μ(j)(1 - lnj/lnN) [dense_anatomy convention]
fn compute_vtrv(n: usize, mu: &[i8]) -> f64 {
    let ln_n = (n as f64).ln();

    // Collect squarefree j with their weights (NO 1/j factor!)
    let active: Vec<(usize, f64)> = (1..n)
        .filter(|&j| mu[j] != 0)
        .map(|j| {
            let w = -(mu[j] as f64) * (1.0 - (j as f64).ln() / ln_n);
            (j, w)
        })
        .collect();

    // Parallel: compute vtRv with R(j,k) = gcd²/(12jk)
    let _diagonal: f64 = active
        .iter()
        .map(|&(j, wj)| {
            let jf = j as f64;
            wj * wj * jf * jf / (12.0 * jf * jf) // gcd(j,j)=j, so gcd²/(12j²) = 1/12
        })
        .sum::<f64>();
    // Simplify: diagonal = Σ wj² / 12
    let diagonal: f64 = active.iter().map(|&(_, wj)| wj * wj / 12.0).sum();

    // Off-diagonal
    let offdiag: f64 = active
        .par_iter()
        .enumerate()
        .map(|(i, &(j, wj))| {
            let jf = j as f64;
            let mut local = 0.0;
            for ki in (i + 1)..active.len() {
                let (k, wk) = active[ki];
                let kf = k as f64;
                let g = gcd(j, k) as f64;
                let r_jk = g * g / (12.0 * jf * kf);
                local += 2.0 * wj * wk * r_jk;
            }
            local
        })
        .sum();

    diagonal + offdiag
}

/// Gram diagonal G(j,j) = (ln2π - γ)/j - 1/j²
fn gram_diagonal(j: usize) -> f64 {
    let jf = j as f64;
    COEFF / jf - 1.0 / (jf * jf)
}

/// Gram off-diagonal G(j,k) using the dense_anatomy formula
fn gram_offdiag(j: usize, k: usize) -> f64 {
    let jf = j as f64;
    let kf = k as f64;
    let d = gcd(j, k);
    let jp = j / d;
    let kp = k / d;
    let term1 = COEFF / 2.0 * (1.0 / jf + 1.0 / kf);
    let term2 = (jf - kf) / (2.0 * jf * kf) * (kf / jf).ln();
    let v1 = vasyunin_sum(jp, kp);
    let v2 = vasyunin_sum(kp, jp);
    let term3 = PI * (d as f64) / (2.0 * jf * kf) * (v1 + v2);
    let term4 = 1.0 / (jf * kf);
    term1 + term2 - term3 - term4
}

/// Compute full vtGv using correct Vasyunin cotangent kernel
fn compute_vtgv(n: usize, mu: &[i8]) -> f64 {
    let ln_n = (n as f64).ln();

    let active: Vec<(usize, f64)> = (1..n)
        .filter(|&j| mu[j] != 0)
        .map(|j| {
            let w = -(mu[j] as f64) * (1.0 - (j as f64).ln() / ln_n);
            (j, w)
        })
        .collect();

    // Diagonal
    let diag: f64 = active
        .iter()
        .map(|&(j, wj)| wj * wj * gram_diagonal(j))
        .sum();

    // Off-diagonal (parallel over first index)
    // Use reduced coprime parts for Vasyunin sums (much faster!)
    let offdiag: f64 = active
        .par_iter()
        .enumerate()
        .map(|(i, &(j, wj))| {
            let mut local = 0.0;
            for ki in (i + 1)..active.len() {
                let (k, wk) = active[ki];
                let g_jk = gram_offdiag(j, k);
                local += 2.0 * wj * wk * g_jk;
            }
            local
        })
        .sum();

    diag + offdiag
}

fn main() {
    let n_max: usize = std::env::args()
        .nth(1)
        .and_then(|s| s.parse().ok())
        .unwrap_or(100_000);

    eprintln!("╔══════════════════════════════════════════════╗");
    eprintln!("║  POMEGRANATE SEEDS — Scaling Constants       ║");
    eprintln!("║  N_max = {:>8}                            ║", n_max);
    eprintln!("╚══════════════════════════════════════════════╝");

    let t0 = Instant::now();
    let mu = sieve_mobius(n_max);
    eprintln!("  Sieved μ(n) in {:.2}s", t0.elapsed().as_secs_f64());

    // Sample points
    let mut samples: Vec<usize> = Vec::new();
    // Dense for small N
    for n in (100..=1000).step_by(100) {
        samples.push(n);
    }
    for n in (1000..=10000).step_by(1000) {
        samples.push(n);
    }
    for n in (10000..=50000).step_by(5000) {
        samples.push(n);
    }
    for n in (50000..=n_max).step_by(10000) {
        samples.push(n);
    }
    samples.sort();
    samples.dedup();
    samples.retain(|&n| n <= n_max);

    // Output
    let outpath = "experiments/overcancellation-scan/results/pomegranate_seeds.tsv";
    let mut out = fs::File::create(outpath).expect("create output");
    writeln!(out, "N\tvtRv\tC_R\tvtGv\tvtDelta\tC_Delta\tD\tD_prime_ok").unwrap();

    // Constants
    let c_delta_theory = 2.0 * PI - 3.0;
    let d_prime = 2.5;

    println!("  C_Δ(theory) = 2π-3 = {:.6}", c_delta_theory);
    println!("  D'          = 5/2  = {:.6}", d_prime);
    println!();
    println!(
        "{:>8} {:>10} {:>10} {:>10} {:>10} {:>10} {:>10} {:>6} {:>8}",
        "N", "vtRv", "C_R", "vtGv", "vtΔv", "C_Δ", "D", "D'ok", "time"
    );
    println!("{}", "-".repeat(90));

    for &n in &samples {
        let t1 = Instant::now();

        let vtrv = compute_vtrv(n, &mu);
        let vtgv = compute_vtgv(n, &mu);

        let ln_n = (n as f64).ln();
        let c_r = vtrv * ln_n;
        let vt_delta = vtgv - vtrv;
        let c_delta = (1.0 - vt_delta) * ln_n;
        let d = (1.0 - vtgv) * ln_n;
        let bound = 1.0 - d_prime / ln_n;
        let ok = if vtgv < bound { "✅" } else { "❌" };

        let elapsed = t1.elapsed().as_secs_f64();

        println!(
            "{:>8} {:>10.7} {:>10.6} {:>10.7} {:>10.7} {:>10.6} {:>10.6} {:>6} {:>7.1}s",
            n, vtrv, c_r, vtgv, vt_delta, c_delta, d, ok, elapsed
        );

        writeln!(
            out,
            "{}\t{}\t{}\t{}\t{}\t{}\t{}\t{}",
            n, vtrv, c_r, vtgv, vt_delta, c_delta, d, ok
        )
        .unwrap();
        out.flush().unwrap();
    }

    println!();
    println!("🍎🍍🏔️💜");
}
