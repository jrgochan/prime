#![allow(dead_code, unused_variables, unused_imports, unused_assignments, clippy::needless_range_loop, clippy::doc_lazy_continuation, non_snake_case, clippy::empty_line_after_doc_comments)]
// overcancellation-scan/src/bin/bd_convergence_probe.rs
//
// ╔═══════════════════════════════════════════════════════════════════╗
// ║  BD CONVERGENCE PROBE — The Final Whisper                       ║
// ║                                                                   ║
// ║  Computes the FULL Baez-Duarte norm squared:                     ║
// ║    ||1 - Σ v_k f_k||² = 1 - 2·σ·c + vᵀGv                      ║
// ║                                                                   ║
// ║  With optimal Mertens weights v_k = -μ(k)/k · w(k,N)            ║
// ║                                                                   ║
// ║  Questions this probe answers:                                    ║
// ║  1. Does the BD norm squared → 0?                                ║
// ║  2. What is CotRes/vᵀGv and does it have a limit?               ║
// ║  3. What is the RATE of convergence?                             ║
// ║  4. How does CotRes decompose by GCD stratum?                   ║
// ║  5. What is the per-prime Euler factor?                          ║
// ╚═══════════════════════════════════════════════════════════════════╝

use cathedral_utils::arith::{gcd, mobius_table};
use std::f64::consts::PI;
use std::collections::BTreeMap;

const EULER_GAMMA: f64 = 0.5772156649015329;

fn vasyunin_const() -> f64 {
    (2.0 * PI).ln() - EULER_GAMMA
}

/// Vasyunin sum V(a, b) = Σ_{m=1}^{a-1} cot(πm/a) · {mb/a}
fn vasyunin_sum(a: usize, b: usize) -> f64 {
    if a <= 1 { return 0.0; }
    let mut s = 0.0;
    for m in 1..a {
        let cot_val = 1.0 / (PI * m as f64 / a as f64).tan();
        let frac = ((m * b) as f64 / a as f64).fract();
        s += cot_val * frac;
    }
    s
}

/// Dissolved Vasyunin: V(a,b) + V(b,a) = -(a²+b²+1)/(6ab) + 1/2
fn dissolved_vasyunin(a: usize, b: usize) -> f64 {
    let af = a as f64;
    let bf = b as f64;
    -(af * af + bf * bf + 1.0) / (6.0 * af * bf) + 0.5
}

/// Full Gram entry G(j,k) for j ≠ k, using DISSOLVED formula
fn gram_entry(j: usize, k: usize) -> f64 {
    let c = vasyunin_const();
    let jf = j as f64;
    let kf = k as f64;
    let d = gcd(j, k);
    let jp = j / d;
    let kp = k / d;
    let df = d as f64;

    let term1 = c / 2.0 * (1.0 / jf + 1.0 / kf);
    let term2 = (jf - kf) / (2.0 * jf * kf) * (kf / jf).ln();
    // Use DISSOLVED formula: V+V = -(j'²+k'²+1)/(6j'k') + 1/2
    let v_dissolved = dissolved_vasyunin(jp, kp);
    let term3 = PI * df / (2.0 * jf * kf) * v_dissolved;
    let term4 = 1.0 / (jf * kf);

    term1 + term2 - term3 - term4
}

/// Diagonal Gram entry G(k,k)
fn gram_diag(k: usize) -> f64 {
    let c = vasyunin_const();
    let kf = k as f64;
    c / kf - 1.0 / (kf * kf)
}

/// BD witness weight: v(k) = -μ(k)/k · w(k,N) where w = 1 - ln(k)/ln(N)
fn mertens_weight(k: usize, mu_k: i8, n: usize) -> f64 {
    if k >= n || mu_k == 0 { return 0.0; }
    let w = 1.0 - (k as f64).ln() / (n as f64).ln();
    -(mu_k as f64) / (k as f64) * w
}

/// Compute the cotangent part of G(j,k) — just the dissolved cotangent contribution
fn cotangent_contribution(j: usize, k: usize) -> f64 {
    let jf = j as f64;
    let kf = k as f64;
    let d = gcd(j, k);
    let jp = j / d;
    let kp = k / d;
    let df = d as f64;
    let v_dissolved = dissolved_vasyunin(jp, kp);
    -PI * df / (2.0 * jf * kf) * v_dissolved
}

/// Find all prime factors of n
fn prime_factors(n: usize) -> Vec<usize> {
    let mut factors = Vec::new();
    let mut m = n;
    let mut p = 2;
    while p * p <= m {
        if m.is_multiple_of(p) {
            factors.push(p);
            while m.is_multiple_of(p) { m /= p; }
        }
        p += 1;
    }
    if m > 1 { factors.push(m); }
    factors
}

fn main() {
    println!("╔═══════════════════════════════════════════════════════════════╗");
    println!("║  BD CONVERGENCE PROBE — The Final Whisper                   ║");
    println!("╚═══════════════════════════════════════════════════════════════╝");
    println!();

    let max_n = 5000;
    let mu = mobius_table(max_n + 1);
    let c = vasyunin_const();

    println!("C = ln(2π) − γ = {:.10}", c);
    println!();

    // ═══════════════════════════════════════════════════
    // SECTION 1: Full BD Norm Squared for increasing N
    // ═══════════════════════════════════════════════════
    println!("═══════════════════════════════════════════════════════════════");
    println!("§1. BD NORM SQUARED: ||1 - Σ v_k f_k||²");
    println!("    Does it → 0? (This IS the RH criterion)");
    println!("═══════════════════════════════════════════════════════════════");
    println!();
    println!("{:>6}  {:>12}  {:>12}  {:>12}  {:>12}  {:>12}",
             "N", "vᵀGv", "2·σ·c_term", "BD_norm²", "CotRes/vᵀGv", "BD·ln(N)");

    let test_ns: Vec<usize> = vec![
        30, 60, 100, 200, 360, 500, 720, 1000, 1500, 2000, 2520, 3000, 4000, 5000
    ];

    let mut bd_data: Vec<(usize, f64, f64)> = Vec::new();

    for &n in &test_ns {
        // Compute weights
        let v: Vec<f64> = (1..=n).map(|k| mertens_weight(k, mu[k], n)).collect();

        // Compute vᵀGv
        let mut vtgv = 0.0;
        let mut cot_res = 0.0;
        for j in 1..=n {
            if v[j-1].abs() < 1e-30 { continue; }
            for k in 1..=n {
                if v[k-1].abs() < 1e-30 { continue; }
                let g = if j == k { gram_diag(j) } else { gram_entry(j, k) };
                vtgv += v[j-1] * v[k-1] * g;
                if j != k {
                    cot_res += v[j-1] * v[k-1] * cotangent_contribution(j, k);
                }
            }
        }

        // Compute the linear term: σ = Σ v_k · ⟨1, f_k⟩
        // EXACT: ⟨1, f_k⟩ = ∫₀¹ {1/(kt)} dt = (ln(k) + 1 - γ) / k
        //
        // Proof: substitute u = 1/(kt), split ∫ into [1/k, 1], [1, 2], [2, 3], ...
        //   = (1/k)[ln(k) + Σ_{m=1}^∞ (ln((m+1)/m) - 1/(m+1))]
        //   = (1/k)[ln(k) + 1 - γ]
        let linear_term: f64 = (1..=n).map(|k| {
            let kf = k as f64;
            let inner = (kf.ln() + 1.0 - EULER_GAMMA) / kf;
            v[k-1] * inner
        }).sum();
        
        // BD norm squared: ||1 - Σ v_k f_k||² = 1 - 2·σ + vᵀGv
        let bd_norm_sq = 1.0 - 2.0 * linear_term + vtgv;

        let ratio = if vtgv.abs() > 1e-20 { cot_res / vtgv } else { 0.0 };
        let bd_ln = bd_norm_sq * (n as f64).ln();

        println!("{:>6}  {:>12.8}  {:>12.8}  {:>12.8}  {:>12.6}  {:>12.6}",
                 n, vtgv, 2.0 * linear_term, bd_norm_sq, ratio, bd_ln);
        
        bd_data.push((n, bd_norm_sq, vtgv));
    }

    // ═══════════════════════════════════════════════════
    // SECTION 2: GCD Stratum Decomposition of CotRes
    // ═══════════════════════════════════════════════════
    println!();
    println!("═══════════════════════════════════════════════════════════════");
    println!("§2. GCD STRATUM DECOMPOSITION (N = 2520)");
    println!("    CotRes = Σ_d CotRes(d) — which GCD values dominate?");
    println!("═══════════════════════════════════════════════════════════════");
    println!();

    let n_strata = 2520;
    let v: Vec<f64> = (1..=n_strata).map(|k| mertens_weight(k, mu[k], n_strata)).collect();
    
    let mut strata: BTreeMap<usize, f64> = BTreeMap::new();
    for j in 1..=n_strata {
        if v[j-1].abs() < 1e-30 { continue; }
        for k in 1..=n_strata {
            if j == k || v[k-1].abs() < 1e-30 { continue; }
            let d = gcd(j, k);
            let contrib = v[j-1] * v[k-1] * cotangent_contribution(j, k);
            *strata.entry(d).or_insert(0.0) += contrib;
        }
    }

    let total_cot: f64 = strata.values().sum();
    println!("{:>6}  {:>14}  {:>10}", "d", "CotRes(d)", "% of total");
    let mut sorted_strata: Vec<_> = strata.iter().collect();
    sorted_strata.sort_by(|a, b| b.1.abs().partial_cmp(&a.1.abs()).unwrap());
    for (d, val) in sorted_strata.iter().take(20) {
        let pct = if total_cot.abs() > 1e-20 { *val / total_cot * 100.0 } else { 0.0 };
        println!("{:>6}  {:>14.8}  {:>9.2}%", d, val, pct);
    }
    println!("  ...   {:>14.8}  {:>9.2}%", total_cot, 100.0);

    // ═══════════════════════════════════════════════════
    // SECTION 3: Per-Prime Euler Factor
    // ═══════════════════════════════════════════════════
    println!();
    println!("═══════════════════════════════════════════════════════════════");
    println!("§3. PER-PRIME EULER FACTOR (N = 2520)");
    println!("    For each prime p, sum CotRes over all d divisible by p");
    println!("═══════════════════════════════════════════════════════════════");
    println!();

    let primes: Vec<usize> = (2..=n_strata).filter(|&p| {
        if p < 2 { return false; }
        for d in 2..=(p as f64).sqrt() as usize {
            if p % d == 0 { return false; }
        }
        true
    }).collect();

    println!("{:>6}  {:>14}  {:>14}  {:>14}", "p", "CotRes(p|d)", "Glass₁(p)", "Ratio");
    for &p in primes.iter().take(20) {
        let prime_contrib: f64 = strata.iter()
            .filter(|(d, _)| *d % p == 0)
            .map(|(_, v)| v)
            .sum();
        let glass1 = 1.0 / (1.0 + 1.0 / p as f64);
        let ratio = if glass1.abs() > 1e-20 { prime_contrib / total_cot } else { 0.0 };
        println!("{:>6}  {:>14.8}  {:>14.8}  {:>14.6}", p, prime_contrib, glass1, ratio);
    }

    // ═══════════════════════════════════════════════════
    // SECTION 4: Rate of Convergence Analysis
    // ═══════════════════════════════════════════════════
    println!();
    println!("═══════════════════════════════════════════════════════════════");
    println!("§4. RATE OF CONVERGENCE");
    println!("    How fast does BD norm² → 0?");
    println!("═══════════════════════════════════════════════════════════════");
    println!();

    println!("{:>6}  {:>12}  {:>12}  {:>12}  {:>12}", 
             "N", "BD·ln(N)", "BD·ln²(N)", "BD·N^0.5", "BD·N");
    for &(n, bd, _vtgv) in &bd_data {
        let ln_n = (n as f64).ln();
        println!("{:>6}  {:>12.6}  {:>12.6}  {:>12.6}  {:>12.6}",
                 n, bd * ln_n, bd * ln_n * ln_n, 
                 bd * (n as f64).sqrt(), bd * n as f64);
    }

    println!();
    println!("If BD·ln(N) → C:    rate is O(1/ln N)  [Mertens rate]");
    println!("If BD·ln²(N) → C:   rate is O(1/ln²N)  [faster than Mertens]");
    println!("If BD·√N → C:       rate is O(1/√N)    [spectral rate]");
    println!("If BD·N → C:        rate is O(1/N)      [optimal rate]");

    // ═══════════════════════════════════════════════════
    // SECTION 5: vᵀGv Decomposition
    // ═══════════════════════════════════════════════════
    println!();
    println!("═══════════════════════════════════════════════════════════════");
    println!("§5. vᵀGv DECOMPOSITION (N = 2520)");
    println!("    Diagonal vs Off-diagonal, and term-by-term");
    println!("═══════════════════════════════════════════════════════════════");
    println!();

    let n_decomp = 2520;
    let v_d: Vec<f64> = (1..=n_decomp).map(|k| mertens_weight(k, mu[k], n_decomp)).collect();

    let mut diag_sum = 0.0;
    let mut offdiag_term1 = 0.0;
    let mut offdiag_term2 = 0.0;
    let mut offdiag_term3 = 0.0;  // dissolved cotangent
    let mut offdiag_term4 = 0.0;

    for j in 1..=n_decomp {
        if v_d[j-1].abs() < 1e-30 { continue; }
        diag_sum += v_d[j-1] * v_d[j-1] * gram_diag(j);
        for k in 1..=n_decomp {
            if j == k || v_d[k-1].abs() < 1e-30 { continue; }
            let jf = j as f64;
            let kf = k as f64;
            let d = gcd(j, k);
            let jp = j / d;
            let kp = k / d;
            let df = d as f64;

            let w = v_d[j-1] * v_d[k-1];
            offdiag_term1 += w * c / 2.0 * (1.0 / jf + 1.0 / kf);
            offdiag_term2 += w * (jf - kf) / (2.0 * jf * kf) * (kf / jf).ln();
            let v_dissolved = dissolved_vasyunin(jp, kp);
            offdiag_term3 += w * (-PI * df / (2.0 * jf * kf) * v_dissolved);
            offdiag_term4 += w * (-1.0 / (jf * kf));
        }
    }

    let vtgv_total = diag_sum + offdiag_term1 + offdiag_term2 + offdiag_term3 + offdiag_term4;

    println!("  Diagonal (CG):        {:>14.8}  ({:.1}%)", diag_sum, diag_sum / vtgv_total * 100.0);
    println!("  Off-diag term1 (CσS): {:>14.8}  ({:.1}%)", offdiag_term1, offdiag_term1 / vtgv_total * 100.0);
    println!("  Off-diag term2 (log):  {:>14.8}  ({:.1}%)", offdiag_term2, offdiag_term2 / vtgv_total * 100.0);
    println!("  Off-diag term3 (cot):  {:>14.8}  ({:.1}%)", offdiag_term3, offdiag_term3 / vtgv_total * 100.0);
    println!("  Off-diag term4 (-S²):  {:>14.8}  ({:.1}%)", offdiag_term4, offdiag_term4 / vtgv_total * 100.0);
    println!("  ──────────────────────────────────────────");
    println!("  Total vᵀGv:           {:>14.8}", vtgv_total);
    println!();
    println!("  CotRes (term3):       {:>14.8}", offdiag_term3);
    println!("  CotRes/vᵀGv:          {:>14.8}", offdiag_term3 / vtgv_total);

    println!();
    println!("═══════════════════════════════════════════════════════════════");
    println!("§6. VERDICT");
    println!("═══════════════════════════════════════════════════════════════");
    println!();
    
    if bd_data.len() >= 2 {
        let (n1, bd1, _) = bd_data[bd_data.len() - 2];
        let (n2, bd2, _) = bd_data[bd_data.len() - 1];
        let ln1 = (n1 as f64).ln();
        let ln2 = (n2 as f64).ln();
        
        if bd1 > 0.0 && bd2 > 0.0 {
            let rate = (bd1.ln() - bd2.ln()) / (ln2 - ln1);
            println!("  Estimated power decay: BD ~ N^({:.3})", -rate);
            println!("  (If ≈ 0: logarithmic decay; if ≈ 0.5: square root; if ≈ 1: linear)");
        }
        
        println!();
        println!("  BD(last)/BD(first) = {:.6}", bd2 / bd_data[0].1);
        println!("  ln(last)/ln(first) = {:.6}", ln2 / (bd_data[0].0 as f64).ln());
    }

    println!();
    println!("The primes have spoken. 💎");
}
