//! # Overcancellation Scan v3: GCD Fourier Decomposition
//!
//! Computes the GCD Fourier decomposition of vᵀRv for multiple weight types:
//!   1. Simple: v_k = μ(k)/logN
//!   2. Fejér:  v_k = -μ(k)(1 - logk/logN)
//!
//! Key identity (from Glass Bridge + SOS decomposition):
//!   vᵀGv = vᵀRv + (σ/2)²
//!   vᵀRv = (1/12) · Σ_d J₂(d) · f(d)²
//!
//! where f(d) = Σ_{d|k, k≤N} v_k/k are the "GCD Fourier coefficients"
//! and J₂(d) = d²·Π_{p|d}(1-1/p²) is Jordan's totient.
//!
//! Discovery: f(p) = μ(p)/(φ(p)·logN) for prime p.

use cathedral_utils::arith::{mobius_table, euler_totient};
use rayon::prelude::*;
use std::time::Instant;

const EULER_GAMMA: f64 = 0.5772156649015329;
const PI: f64 = std::f64::consts::PI;
const LN2PI: f64 = 1.8378770664093453;

/// Sieve J₂(d) = d² · Π_{p|d}(1-1/p²) for d=0..n
fn jordan2_sieve(n: usize) -> Vec<f64> {
    let mut j2: Vec<f64> = (0..=n).map(|d| (d as f64).powi(2)).collect();
    j2[0] = 0.0;
    let mut is_prime = vec![true; n + 1];
    is_prime[0] = false;
    if n >= 1 { is_prime[1] = false; }
    for p in 2..=n {
        if !is_prime[p] { continue; }
        for m in (2 * p..=n).step_by(p) {
            is_prime[m] = false;
        }
        let factor = 1.0 - 1.0 / (p as f64 * p as f64);
        for m in (p..=n).step_by(p) {
            j2[m] *= factor;
        }
    }
    j2
}

/// Vasyunin cotangent sum
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

/// Gram entry G(j,k) via Vasyunin cotangent formula
fn gram_entry(j: usize, k: usize) -> f64 {
    let (jf, kf) = (j as f64, k as f64);
    if j == k {
        return (LN2PI - EULER_GAMMA) / kf - 1.0 / (kf * kf);
    }
    let d = cathedral_utils::arith::gcd(j, k);
    let (jp, kp) = (j / d, k / d);
    let df = d as f64;
    let t1 = (LN2PI - EULER_GAMMA) / 2.0 * (1.0 / jf + 1.0 / kf);
    let t2 = (jf - kf) / (2.0 * jf * kf) * (kf / jf).ln();
    let t3 = PI * df / (2.0 * jf * kf) * (vasyunin_sum(jp, kp) + vasyunin_sum(kp, jp));
    let t4 = 1.0 / (jf * kf);
    t1 + t2 - t3 - t4
}

/// Ramanujan entry R(j,k) = gcd(j,k)²/(12·j·k)
#[inline]
fn ramanujan_entry(j: usize, k: usize) -> f64 {
    let d = cathedral_utils::arith::gcd(j, k) as f64;
    d * d / (12.0 * j as f64 * k as f64)
}

/// Weight types
enum WeightType { Simple, Fejer }

/// Build weights for a given type
fn build_weights(mu: &[i8], n: usize, wtype: &WeightType) -> Vec<f64> {
    let log_n = (n as f64).ln();
    let mut w = vec![0.0f64; n + 1];
    for k in 1..=n {
        if mu[k] == 0 { continue; }
        w[k] = match wtype {
            WeightType::Simple => mu[k] as f64 / log_n,
            WeightType::Fejer => -mu[k] as f64 * (1.0 - (k as f64).ln() / log_n),
        };
    }
    w
}

/// Compute GCD Fourier coefficients f(d) = Σ_{d|k, k≤N} v_k/k
fn gcd_fourier_coeffs(v: &[f64], n: usize) -> Vec<f64> {
    let mut f = vec![0.0f64; n + 1];
    for d in 1..=n {
        let mut s = 0.0;
        let mut m = 1;
        while d * m <= n {
            let k = d * m;
            s += v[k] / k as f64;
            m += 1;
        }
        f[d] = s;
    }
    f
}

struct ScanResult {
    vt_rv: f64,
    sigma: f64,
    rank1: f64,
    vt_gv: f64,
    bt_v: f64,
    d_sq: f64,
    fourier: Vec<f64>,
    j2_contribs: Vec<f64>,
}

fn scan(mu: &[i8], j2: &[f64], phi: &[usize], n: usize, wtype: &WeightType) -> ScanResult {
    let v = build_weights(mu, n, wtype);
    let f = gcd_fourier_coeffs(&v, n);

    // vᵀRv = (1/12) Σ J₂(d)·f(d)²
    let mut j2_contribs = vec![0.0f64; n + 1];
    let mut vt_rv = 0.0;
    for d in 1..=n {
        let c = j2[d] * f[d] * f[d] / 12.0;
        j2_contribs[d] = c;
        vt_rv += c;
    }

    let sigma: f64 = v[1..=n].iter().sum();
    let rank1 = (sigma / 2.0).powi(2);
    let vt_gv = vt_rv + rank1;

    // bᵀv
    let bt_v: f64 = (1..=n)
        .filter(|&k| mu[k] != 0)
        .map(|k| (0.5 - 0.5 / k as f64) * v[k])
        .sum();
    let d_sq = 1.0 - 2.0 * bt_v + vt_gv;

    ScanResult {
        vt_rv, sigma, rank1, vt_gv, bt_v, d_sq,
        fourier: f, j2_contribs,
    }
}

fn main() {
    println!("╔══════════════════════════════════════════════════════════════════╗");
    println!("║   OVERCANCELLATION SCAN v3: GCD Fourier Decomposition          ║");
    println!("║                                                                ║");
    println!("║   vᵀRv = (1/12)·Σ J₂(d)·f(d)²  via Glass Bridge              ║");
    println!("║   f(d) = Σ_{{d|k}} v_k/k  — the GCD Fourier coefficients       ║");
    println!("╚══════════════════════════════════════════════════════════════════╝\n");

    let test_points: Vec<usize> = vec![
        100, 500, 1000, 5000, 10000, 20000, 50000, 100000,
    ];

    let max_n = *test_points.iter().max().unwrap();
    println!("Sieving up to {}...", max_n);
    let t0 = Instant::now();
    let mu = mobius_table(max_n);
    let j2 = jordan2_sieve(max_n);
    let phi = euler_totient(max_n);
    println!("  Sieve done in {:.3}s\n", t0.elapsed().as_secs_f64());

    for wtype in &[WeightType::Fejer, WeightType::Simple] {
        let label = match wtype {
            WeightType::Fejer => "FEJÉR: v_k = -μ(k)(1 - logk/logN)",
            WeightType::Simple => "SIMPLE: v_k = μ(k)/logN",
        };
        println!("\n{}", "═".repeat(35));
        println!("  {}", label);
        println!("{}", "═".repeat(35));

        println!("\n{:>8} {:>10} {:>10} {:>10} {:>10} {:>12} {:>8}",
                 "N", "vᵀRv", "(σ/2)²", "vᵀGv", "d²", "vᵀRv/logN", "time");
        println!("{}", "─".repeat(78));

        for &n in &test_points {
            let t = Instant::now();
            let r = scan(&mu, &j2, &phi, n, wtype);
            let log_n = (n as f64).ln();
            let elapsed = t.elapsed().as_secs_f64();

            println!("{:>8} {:>10.4} {:>10.4} {:>10.4} {:>10.6} {:>12.6} {:>7.2}s",
                     n, r.vt_rv, r.rank1, r.vt_gv, r.d_sq, r.vt_rv / log_n, elapsed);
        }

        // GCD Fourier pattern for the last (largest) N
        let n = *test_points.last().unwrap();
        let r = scan(&mu, &j2, &phi, n, wtype);
        let log_n = (n as f64).ln();

        println!("\n  GCD Fourier coefficients at N={}:", n);
        println!("  {:>5} {:>12} {:>12} {:>12}", "d", "f(d)·logN", "1/φ(d)", "ratio");
        println!("  {}", "─".repeat(50));
        for &d in &[1, 2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 30, 210] {
            if d <= n && phi[d] > 0 {
                let f_scaled = r.fourier[d] * log_n;
                let inv_phi = 1.0 / phi[d] as f64;
                let ratio = if inv_phi.abs() > 1e-15 { f_scaled / inv_phi } else { 0.0 };
                println!("  {:>5} {:>12.6} {:>12.6} {:>12.6}", d, f_scaled, inv_phi, ratio);
            }
        }

        // Contribution by d-range
        println!("\n  Contribution by d-range:");
        let ranges = [(1,10), (10,100), (100,1000), (1000,10000), (10000, n+1)];
        for (lo, hi) in ranges {
            if lo <= n {
                let s: f64 = (lo..hi.min(n+1)).map(|d| r.j2_contribs[d]).sum();
                println!("    d∈[{:>5},{:>6}): {:>10.4} ({:>5.1}%)",
                         lo, hi.min(n+1), s, 100.0 * s / r.vt_rv);
            }
        }
    }

    println!("\n{}", "═".repeat(35));
    println!("  The GCD Fourier coefficient f(p) ≈ μ(p)/(φ(p)·logN)");
    println!("  is the Ramanujan projection of Möbius onto divisor classes.");
    println!("  The Crown axiom: can RH tame Σ J₂(d)·f(d)²? 🏛️");
    println!("{}\n", "═".repeat(35));
}
