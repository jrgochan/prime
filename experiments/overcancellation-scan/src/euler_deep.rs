//! # Euler Convergence Deep Probe
//!
//! Focused computation of (1 - vᵀGv)·lnN at high N
//! to test: does it converge to 1 + ln(2π) ≈ 2.8379?
//!
//! Stripped-down version — only computes vᵀGv, no decomposition.
//! Uses Rayon for parallelization.

use cathedral_utils::arith::{gcd, mobius_table};
use rayon::prelude::*;
use std::time::Instant;

const EULER_GAMMA: f64 = 0.5772156649015329;
const PI: f64 = std::f64::consts::PI;
const LN2PI: f64 = 1.8378770664093453;

/// Vasyunin cotangent sum V(a,b)
fn vasyunin_sum(a: usize, b: usize) -> f64 {
    if a <= 1 { return 0.0; }
    let af = a as f64;
    let mut total = 0.0;
    for m in 1..a {
        let frac = ((m * b) % a) as f64 / af;
        let angle = PI * m as f64 / af;
        let (sin_v, cos_v) = angle.sin_cos();
        if sin_v.abs() < 1e-15 { continue; }
        total += frac * cos_v / sin_v;
    }
    total
}

/// Vasyunin Gram entry G_V(j,k)
fn gram_entry(j: usize, k: usize) -> f64 {
    let (jf, kf) = (j as f64, k as f64);
    if j == k {
        return (LN2PI - EULER_GAMMA) / kf - 1.0 / (kf * kf);
    }
    let d = gcd(j, k);
    let (jp, kp) = (j / d, k / d);
    let df = d as f64;
    let t1 = (LN2PI - EULER_GAMMA) / 2.0 * (1.0 / jf + 1.0 / kf);
    let t2 = (jf - kf) / (2.0 * jf * kf) * (kf / jf).ln();
    let t3 = PI * df / (2.0 * jf * kf) * (vasyunin_sum(jp, kp) + vasyunin_sum(kp, jp));
    let t4 = 1.0 / (jf * kf);
    t1 + t2 - t3 - t4
}

/// Compute vᵀGv with Möbius-Fejér weights
fn compute_vtgv(mu: &[i8], n: usize) -> (f64, f64) {
    let t0 = Instant::now();
    let log_n = (n as f64).ln();

    let v: Vec<f64> = (0..=n).map(|k| {
        if k == 0 || mu[k] == 0 { 0.0 }
        else { -(mu[k] as f64) * (1.0 - (k as f64).ln() / log_n) }
    }).collect();

    let active: Vec<usize> = (1..=n).filter(|&k| v[k] != 0.0).collect();

    let row_sums: f64 = active.par_iter().map(|&j| {
        let mut gv = 0.0f64;
        for &k in &active {
            gv += v[j] * v[k] * gram_entry(j, k);
        }
        gv
    }).sum();

    let elapsed = t0.elapsed().as_secs_f64();
    (row_sums, elapsed)
}

fn main() {
    let target = 1.0 + LN2PI;  // 2.8379
    let euler_e = std::f64::consts::E;

    println!("╔══════════════════════════════════════════════════════════════╗");
    println!("║   EULER CONVERGENCE DEEP PROBE                             ║");
    println!("║   Testing: (1 - vᵀGv)·lnN → 1 + ln(2π) ≈ {:.6}?     ║", target);
    println!("╚══════════════════════════════════════════════════════════════╝\n");

    let test_points: Vec<usize> = vec![
        500, 1000, 2000, 3000, 5000, 8000, 10000, 12000, 15000,
    ];

    let max_n = *test_points.iter().max().unwrap();
    println!("Sieving μ(k) for k ≤ {}...", max_n);
    let mu = mobius_table(max_n);
    println!("  Done.\n");

    println!("{:>6} {:>12} {:>12} {:>12} {:>12} {:>12} {:>8}",
             "N", "vᵀGv", "(1-Gv)·lnN", "gap(e)", "gap(1+ln2π)", "% to 1+ln2π", "secs");
    println!("{}", "─".repeat(86));

    for &n in &test_points {
        let (vtgv, elapsed) = compute_vtgv(&mu, n);
        let log_n = (n as f64).ln();
        let product = (1.0 - vtgv) * log_n;
        let gap_e = product - euler_e;
        let gap_target = product - target;
        let pct = gap_target / target * 100.0;

        println!("{:>6} {:>12.8} {:>12.6} {:>+12.6} {:>+12.6} {:>11.3}% {:>7.1}",
                 n, vtgv, product, gap_e, gap_target, pct, elapsed);
    }

    println!("\n{}", "═".repeat(86));
    println!("  EXTRAPOLATION");
    println!("{}\n", "═".repeat(86));

    // Simple extrapolation: if f(N) = L + A/lnN, use last 2 points
    let n1 = test_points[test_points.len() - 2];
    let n2 = test_points[test_points.len() - 1];
    // We'd need the values... let me just recompute
    let (g1, _) = compute_vtgv(&mu, n1);
    let (g2, _) = compute_vtgv(&mu, n2);
    let f1 = (1.0 - g1) * (n1 as f64).ln();
    let f2 = (1.0 - g2) * (n2 as f64).ln();
    let x1 = 1.0 / (n1 as f64).ln();
    let x2 = 1.0 / (n2 as f64).ln();

    // f = L + A·x → L = (f2·x1 - f1·x2) / (x1 - x2)
    let l_extrap = (f2 * x1 - f1 * x2) / (x1 - x2);
    println!("  Linear extrapolation (last 2 pts): L = {:.6}", l_extrap);
    println!("  1 + ln(2π)                       = {:.6}", target);
    println!("  e                                 = {:.6}", euler_e);
    println!("  Gap from 1+ln(2π): {:.6} ({:.3}%)", (l_extrap - target).abs(),
             (l_extrap - target).abs() / target * 100.0);
    println!("  Gap from e:        {:.6} ({:.3}%)", (l_extrap - euler_e).abs(),
             (l_extrap - euler_e).abs() / euler_e * 100.0);
}
