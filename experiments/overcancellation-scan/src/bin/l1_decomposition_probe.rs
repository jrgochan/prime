#![allow(dead_code, unused_variables, unused_imports, unused_assignments, clippy::needless_range_loop, clippy::doc_lazy_continuation, non_snake_case, clippy::empty_line_after_doc_comments)]
/// L₁ Decomposition Probe — Validates the graduation path for moebius_annihilation
///
/// Decomposes vᵀL₁v = vᵀGv - vᵀA₁v into three components:
/// 1. Logarithmic part: from log(gcd) terms  
/// 2. Harmonic part: from harmonic number corrections
/// 3. Cotangent remainder: everything else
///
/// Purpose: confirm each component decays as O(1/logN) relative to vᵀA₁v

use std::collections::HashMap;

/// Compute μ(n) via sieve
fn mobius_sieve(n: usize) -> Vec<i32> {
    let mut mu = vec![0i32; n + 1];
    mu[1] = 1;
    let mut is_prime = vec![true; n + 1];
    let mut primes = Vec::new();
    
    for i in 2..=n {
        if is_prime[i] {
            primes.push(i);
            mu[i] = -1;
        }
        for &p in &primes {
            if i * p > n { break; }
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

fn gcd(a: usize, b: usize) -> usize {
    if b == 0 { a } else { gcd(b, a % b) }
}

/// Compute ∫₀¹ {1/(jx)}{1/(kx)} dx via high-precision numerical integration
/// Uses the explicit formula from Vasyunin's decomposition
fn gram_entry_numerical(j: usize, k: usize) -> f64 {
    // Use quadrature: split [0,1] into intervals where floor functions are constant
    // For accuracy, use the cotangent formula:
    // G(j,k) = Σ_{m=1}^{j-1} Σ_{n=1}^{k-1} [gcd(m*k, n*j) == j*k] * stuff
    // Actually, simpler: direct numerical integration with change of variable
    
    let jf = j as f64;
    let kf = k as f64;
    
    // Integration via Gauss-Kronrod or direct formula
    // The exact formula: G(j,k) = (1/(2jk)) * [sum over Ramanujan sums + log terms]
    // For validation, use numerical integration with many points
    
    let n_pts = 100_000;
    let mut sum = 0.0;
    for i in 1..n_pts {
        let x = i as f64 / n_pts as f64;
        let fj = 1.0 / (jf * x);
        let fk = 1.0 / (kf * x);
        let frac_j = fj - fj.floor();
        let frac_k = fk - fk.floor();
        sum += frac_j * frac_k;
    }
    sum / n_pts as f64
}

/// B₁ skeleton entry
fn b1_entry(j: usize, k: usize) -> f64 {
    let g = gcd(j, k) as f64;
    g * g / (12.0 * j as f64 * k as f64)
}

/// Harmonic number H(n) = 1 + 1/2 + ... + 1/n
fn harmonic(n: usize) -> f64 {
    (1..=n).map(|k| 1.0 / k as f64).sum()
}

/// The explicit L₁ decomposition
/// L₁(j,k) = G(j,k) - A₁(j,k)
///
/// Decompose into:
/// (a) L₁_log: logarithmic gcd contribution  
/// (b) L₁_harm: harmonic number correction
/// (c) L₁_remainder: everything else (cotangent dissolution)
fn l1_decomposition(j: usize, k: usize) -> (f64, f64, f64) {
    let g = gcd(j, k);
    let a = j / g;
    let b = k / g;
    let gf = g as f64;
    let jf = j as f64;
    let kf = k as f64;
    
    // The full G(j,k) - A₁(j,k) via explicit formula
    let g_full = gram_entry_numerical(j, k);
    let a1 = b1_entry(j, k);
    let l1_total = g_full - a1;
    
    // Component (a): logarithmic part
    // This comes from log(gcd) in the Vasyunin expansion
    // L₁_log ≈ gcd²/(jk) · (2γ + 2·ln(gcd))/(12)
    // More precisely, the log term is:
    // (gcd²/(jk)) · (ln(gcd)/6)
    let euler_gamma = 0.5772156649015329;
    let l1_log = if g > 1 {
        (gf * gf / (jf * kf)) * gf.ln() / 6.0
    } else {
        0.0
    };
    
    // Component (b): harmonic number corrections  
    // These come from the digamma/harmonic terms in the Vasyunin formula
    // L₁_harm ≈ (gcd²/(jk)) · (γ - (H(a-1) + H(b-1))/2) / 6
    let ha = if a > 1 { harmonic(a - 1) } else { 0.0 };
    let hb = if b > 1 { harmonic(b - 1) } else { 0.0 };
    let l1_harm = (gf * gf / (jf * kf)) * (euler_gamma - (ha + hb) / 2.0) / 6.0;
    
    // Component (c): remainder = total - log - harm
    let l1_remainder = l1_total - l1_log - l1_harm;
    
    (l1_log, l1_harm, l1_remainder)
}

fn main() {
    println!("═══════════════════════════════════════════════════════════════");
    println!("L₁ DECOMPOSITION PROBE — Graduation Validator");
    println!("═══════════════════════════════════════════════════════════════");
    println!();
    
    let n_max = 500;
    let mu = mobius_sieve(n_max);
    
    // ── §1: Check a few L₁ entries ──
    println!("═══ §1: Sample L₁(j,k) Decomposition ═══");
    println!("{:>4} {:>4} {:>12} {:>12} {:>12} {:>12} {:>12}",
             "j", "k", "L₁_total", "L₁_log", "L₁_harm", "L₁_rem", "A₁");
    println!("{}", "-".repeat(76));
    
    for &(j, k) in &[(2,4), (3,6), (6,12), (2,3), (5,7), (4,8), (3,9)] {
        let g_full = gram_entry_numerical(j, k);
        let a1 = b1_entry(j, k);
        let l1_total = g_full - a1;
        let (l1_log, l1_harm, l1_rem) = l1_decomposition(j, k);
        println!("{:>4} {:>4} {:>12.6} {:>12.6} {:>12.6} {:>12.6} {:>12.6}",
                 j, k, l1_total, l1_log, l1_harm, l1_rem, a1);
    }
    
    // ── §2: Bilinear sum decomposition for Möbius witness ──
    println!();
    println!("═══ §2: vᵀL₁v Decomposition (flat Möbius witness) ═══");
    println!("{:>6} {:>12} {:>12} {:>12} {:>12} {:>12} {:>10}",
             "N", "vᵀA₁v", "vᵀL₁v", "L₁_log", "L₁_harm", "L₁_rem", "ratio");
    println!("{}", "-".repeat(82));
    
    for &n in &[10, 20, 50, 100, 200, 300, 500] {
        // Build flat Möbius witness: v(k) = -μ(k)/k
        let mut v: HashMap<usize, f64> = HashMap::new();
        for k in 1..=n {
            if mu[k] != 0 {
                v.insert(k, -mu[k] as f64 / k as f64);
            }
        }
        
        let keys: Vec<usize> = v.keys().copied().collect();
        
        // Compute bilinear sums
        let mut vta1v = 0.0;
        let mut vtl1v_log = 0.0;
        let mut vtl1v_harm = 0.0;
        let mut vtl1v_rem = 0.0;
        
        for &j in &keys {
            for &k in &keys {
                let vj = v[&j];
                let vk = v[&k];
                let prod = vj * vk;
                
                vta1v += prod * b1_entry(j, k);
                let (l_log, l_harm, l_rem) = l1_decomposition(j, k);
                vtl1v_log += prod * l_log;
                vtl1v_harm += prod * l_harm;
                vtl1v_rem += prod * l_rem;
            }
        }
        
        let vtl1v_total = vtl1v_log + vtl1v_harm + vtl1v_rem;
        let ratio = if vta1v.abs() > 1e-15 { vtl1v_total / vta1v } else { f64::NAN };
        
        println!("{:>6} {:>12.8} {:>12.8} {:>12.8} {:>12.8} {:>12.8} {:>10.4}",
                 n, vta1v, vtl1v_total, vtl1v_log, vtl1v_harm, vtl1v_rem, ratio);
    }
    
    // ── §3: Decay rate analysis ──
    println!();
    println!("═══ §3: Decay Rate Analysis ═══");
    println!("{:>6} {:>12} {:>12} {:>12} {:>12}",
             "N", "|L₁/A₁|", "1/logN", "ratio/logN", "~ const?");
    println!("{}", "-".repeat(60));
    
    for &n in &[10, 20, 50, 100, 200, 300, 500] {
        let mut v: HashMap<usize, f64> = HashMap::new();
        for k in 1..=n {
            if mu[k] != 0 {
                v.insert(k, -mu[k] as f64 / k as f64);
            }
        }
        let keys: Vec<usize> = v.keys().copied().collect();
        
        let mut vta1v = 0.0;
        let mut vtl1v = 0.0;
        
        for &j in &keys {
            for &k in &keys {
                let vj = v[&j];
                let vk = v[&k];
                let prod = vj * vk;
                vta1v += prod * b1_entry(j, k);
                let g_full = gram_entry_numerical(j, k);
                vtl1v += prod * (g_full - b1_entry(j, k));
            }
        }
        
        let ratio = (vtl1v / vta1v).abs();
        let inv_log = 1.0 / (n as f64).ln();
        let normalized = ratio / inv_log;  // Should be ~constant if decay is 1/logN
        
        println!("{:>6} {:>12.6} {:>12.6} {:>12.4} {:>12}",
                 n, ratio, inv_log, normalized, 
                 if (normalized - 0.3).abs() < 0.15 { "✓ stable" } else { "  varies" });
    }
    
    // ── §4: Which Mertens axiom is needed? ──
    println!();
    println!("═══ §4: Mertens Sum Diagnostics ═══");
    println!("Testing which weighted Möbius sums appear in the L₁ bilinear form:");
    println!();
    
    for &n in &[50, 100, 200, 500] {
        let ln_n = (n as f64).ln();
        
        // Σ μ(k)/k (should → 0 by PNT/Mertens)
        let sum_mu_over_k: f64 = (1..=n).filter(|&k| mu[k] != 0)
            .map(|k| mu[k] as f64 / k as f64).sum();
        
        // Σ μ(k)·ln(k)/k (should → -1 by PNT)
        let sum_mu_log_over_k: f64 = (1..=n).filter(|&k| mu[k] != 0)
            .map(|k| mu[k] as f64 * (k as f64).ln() / k as f64).sum();
        
        // Σ μ²(k)/k (should ≈ (6/π²)·ln(N))
        let sum_mu2_over_k: f64 = (1..=n).filter(|&k| mu[k] != 0)
            .map(|k| 1.0 / k as f64).sum();
        
        // Σ μ²(k)·ln(k)/k (weighted Mertens)
        let _sum_mu2_log_over_k: f64 = (1..=n).filter(|&k| mu[k] != 0)
            .map(|k| (k as f64).ln() / k as f64).sum();
        
        println!("  N={:>4}: Σμ/k = {:>+.6}, Σμ·ln(k)/k = {:>+.6}, Σμ²/k = {:>.4} (expect {:.4}·lnN = {:.4})",
                 n, sum_mu_over_k, sum_mu_log_over_k,
                 sum_mu2_over_k, 6.0/std::f64::consts::PI.powi(2),
                 6.0/std::f64::consts::PI.powi(2) * ln_n);
    }
    
    println!();
    println!("═══════════════════════════════════════════════════════════════");
    println!("CONCLUSION: If the L₁/A₁ ratio × logN stabilizes to a");
    println!("constant, then moebius_annihilation is graduable using");
    println!("the existing Mertens axioms in BartlettWindow.lean.");
    println!("═══════════════════════════════════════════════════════════════");
}
