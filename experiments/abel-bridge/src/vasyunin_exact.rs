/// DIRECTIVE GAMMA: Exact Vasyunin-Báez-Duarte Computation
///
/// Computes Q(N) using the EXACT discrete formulas from 
/// Cathedral/Vasyunin/Defs.lean. NO numerical integration.
///
/// G(j,k) = (ln(2π) - γ)/2 · (1/j + 1/k)
///           + (j-k)/(2jk) · ln(k/j)  
///           - πd/(2jk) · (V(j',k') + V(k',j'))
///           - 1/(jk)
///
/// b_k = (ln(k) + 1 - γ) / k
///
/// Q(N) = 1 - 2 bᵀw + wᵀGw  where w = -μ(k)(1 - ln(k)/ln(N))

use std::f64::consts::PI;
use rayon::prelude::*;

const GAMMA_EULER: f64 = 0.5772156649015329;
const LN_TWO_PI: f64 = 1.8378770664093453; // ln(2π)
const A_CONST: f64 = LN_TWO_PI - GAMMA_EULER; // ln(2π) - γ ≈ 1.2606

fn gcd(a: usize, b: usize) -> usize {
    if b == 0 { a } else { gcd(b, a % b) }
}

/// Vasyunin cotangent sum V(a, b) = Σ_{m=1}^{a-1} {mb/a} · cot(πm/a)
fn vasyunin_sum(a: usize, b: usize) -> f64 {
    if a <= 1 { return 0.0; }
    let af = a as f64;
    (1..a).map(|m| {
        let frac = ((m * b) as f64 / af).fract();
        let cot = {
            let arg = PI * m as f64 / af;
            arg.cos() / arg.sin()
        };
        frac * cot
    }).sum()
}

/// Exact Gram entry G(j,k) — Vasyunin-Báez-Duarte formula
fn gram_entry(j: usize, k: usize) -> f64 {
    if j == k {
        let jf = j as f64;
        A_CONST / jf - 1.0 / (jf * jf)
    } else {
        let d = gcd(j, k);
        let jp = j / d;
        let kp = k / d;
        let jf = j as f64;
        let kf = k as f64;
        let df = d as f64;
        
        let term1 = A_CONST / 2.0 * (1.0 / jf + 1.0 / kf);
        let term2 = (jf - kf) / (2.0 * jf * kf) * (kf / jf).ln();
        let term3 = PI * df / (2.0 * jf * kf) * 
                     (vasyunin_sum(jp, kp) + vasyunin_sum(kp, jp));
        let term4 = 1.0 / (jf * kf);
        term1 + term2 - term3 - term4
    }
}

/// Exact mean vector entry b_k = (ln(k) + 1 - γ) / k
fn mean_entry(k: usize) -> f64 {
    let kf = k as f64;
    (kf.ln() + 1.0 - GAMMA_EULER) / kf
}

/// Sieve of Eratosthenes for Möbius function
fn mobius_sieve(max_n: usize) -> Vec<i8> {
    let mut mu = vec![1i8; max_n + 1];
    let mut is_prime = vec![true; max_n + 1];
    let mut smallest_prime = vec![0usize; max_n + 1];
    
    for p in 2..=max_n {
        if !is_prime[p] { continue; }
        smallest_prime[p] = p;
        for mult in (p..=max_n).step_by(p) {
            if mult != p { is_prime[mult] = false; }
            if smallest_prime[mult] == 0 { smallest_prime[mult] = p; }
        }
        // Mark p² multiples as 0 (not squarefree)
        let p2 = p * p;
        if p2 <= max_n {
            for mult in (p2..=max_n).step_by(p2) {
                mu[mult] = 0;
            }
        }
    }
    
    // Compute μ by factorization
    mu[0] = 0;
    mu[1] = 1;
    for n in 2..=max_n {
        if mu[n] == 0 { continue; }
        // Count prime factors
        let mut m = n;
        let mut omega = 0;
        while m > 1 {
            let p = smallest_prime[m];
            let mut e = 0;
            while m % p == 0 { m /= p; e += 1; }
            if e > 1 { mu[n] = 0; break; }
            omega += 1;
        }
        if mu[n] != 0 {
            mu[n] = if omega % 2 == 0 { 1 } else { -1 };
        }
    }
    mu
}

fn main() {
    println!("╔══════════════════════════════════════════════════════════════╗");
    println!("║  DIRECTIVE GAMMA: Exact Vasyunin-BD Computation            ║");
    println!("║  Rayleigh quotient Q/ln(N) should converge                 ║");
    println!("╚══════════════════════════════════════════════════════════════╝");
    println!();
    
    // Sanity checks
    let g11 = gram_entry(1, 1);
    let g12 = gram_entry(1, 2);
    let g22 = gram_entry(2, 2);
    let b1 = mean_entry(1);
    println!("═══ Sanity Checks ═══");
    println!("  G(1,1) = {:.15}  (expect 0.260661401507813)", g11);
    println!("  G(1,2) = {:.15}  (expect 0.272209255990873)", g12);
    println!("  G(2,2) = {:.15}  (expect 0.380330700753906)", g22);
    println!("  b(1)   = {:.15}  (expect {:.15})", b1, 1.0 - GAMMA_EULER);
    println!();
    
    let max_n = 50_000usize;
    let mu = mobius_sieve(max_n);
    
    // PNT diagnostic
    println!("═══ PNT Check: Σμ(k)/k ═══");
    for &n in &[100, 1000, 10000, 50000] {
        let sum: f64 = (1..=n).map(|k| mu[k] as f64 / k as f64).sum();
        println!("  N={:>6}: Σμ(k)/k = {:>14.10}", n, sum);
    }
    println!();
    
    let ns = vec![10, 20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000, 50000];
    
    println!("{:>6} {:>12} {:>12} {:>12} {:>12}", "N", "vᵀCv", "bᵀv", "Q=(bᵀv)²/vᵀCv", "Q/ln(N)");
    println!("{}", "─".repeat(65));
    
    for &n in &ns {
        let t0 = std::time::Instant::now();
        let ln_n = (n as f64).ln();
        
        // Witness vector: v_k = -μ(k) * (1 - ln(k)/ln(N))  for k=1..N
        let v: Vec<f64> = (1..=n).map(|k| {
            -(mu[k] as f64) * (1.0 - (k as f64).ln() / ln_n)
        }).collect();
        
        // Mean vector: b_k for k=1..N
        let b: Vec<f64> = (1..=n).map(|k| mean_entry(k)).collect();
        
        // bᵀv
        let btv: f64 = (0..n).map(|i| b[i] * v[i]).sum();
        
        // Rank-1 sums for decomposition (matching Attack 9)
        let sum_v: f64 = v.iter().sum();
        let sum_v_over_k: f64 = (0..n).map(|i| v[i] / (i + 1) as f64).sum();
        
        // Component 1: Rational = A * Σv * Σ(v/k) 
        let vt_g1 = A_CONST * sum_v * sum_v_over_k;
        // Component 4: Base = -(Σv/k)²
        let vt_g4 = -sum_v_over_k.powi(2);
        // Mean deflation
        let mean_defl = -btv.powi(2);
        
        // Components 2 (Log) and 3 (Cot): pairwise sums
        // Only squarefree k contribute (μ(k) ≠ 0)
        let nonzero: Vec<usize> = (1..=n).filter(|&k| mu[k] != 0).collect();
        
        let (vt_g2, vt_g3): (f64, f64) = if n <= 1000 {
            nonzero.iter().map(|&j| {
                let mut g2 = 0.0f64;
                let mut g3 = 0.0f64;
                for &k in &nonzero {
                    if j == k { continue; }
                    let jf = j as f64;
                    let kf = k as f64;
                    let d = gcd(j, k);
                    let jp = j / d;
                    let kp = k / d;
                    let df = d as f64;
                    // Log term
                    g2 += v[j-1] * v[k-1] * (jf - kf) / (2.0 * jf * kf) * (kf / jf).ln();
                    // Cot term
                    g3 += v[j-1] * v[k-1] * (-PI * df / (2.0 * jf * kf)) * 
                          (vasyunin_sum(jp, kp) + vasyunin_sum(kp, jp));
                }
                (g2, g3)
            }).fold((0.0, 0.0), |a, b| (a.0 + b.0, a.1 + b.1))
        } else {
            nonzero.par_iter().map(|&j| {
                let mut g2 = 0.0f64;
                let mut g3 = 0.0f64;
                for &k in &nonzero {
                    if j == k { continue; }
                    let jf = j as f64;
                    let kf = k as f64;
                    let d = gcd(j, k);
                    let jp = j / d;
                    let kp = k / d;
                    let df = d as f64;
                    g2 += v[j-1] * v[k-1] * (jf - kf) / (2.0 * jf * kf) * (kf / jf).ln();
                    g3 += v[j-1] * v[k-1] * (-PI * df / (2.0 * jf * kf)) * 
                          (vasyunin_sum(jp, kp) + vasyunin_sum(kp, jp));
                }
                (g2, g3)
            }).reduce(|| (0.0, 0.0), |a, b| (a.0 + b.0, a.1 + b.1))
        };
        
        // Total: vᵀCv = vᵀGv - (bᵀv)²
        let vt_cv = vt_g1 + vt_g2 + vt_g3 + vt_g4 + mean_defl;
        
        // Rayleigh quotient: Q = (bᵀv)² / vᵀCv
        let q = if vt_cv > 0.0 { btv.powi(2) / vt_cv } else { f64::INFINITY };
        let q_over_ln = q / ln_n;
        
        let dt = t0.elapsed().as_secs_f64();
        
        println!("{:>6} {:>12.4e} {:>12.6} {:>12.6} {:>12.6}  ({:.1}s)", 
                 n, vt_cv, btv, q, q_over_ln, dt);
    }
    
    println!();
    println!("The Báez-Duarte constant C ≈ 0.04619 predicts Q/ln(N) → 1/C ≈ 21.65.");
}

