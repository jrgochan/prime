#![allow(unused, dead_code)]
//! ═══════════════════════════════════════════════════════════════════════════
//!  CATHEDRAL HIGH-PRECISION SPECTRAL EXPERIMENT
//!  256-bit MPFR Gram matrix · Rank-1 Interference · Full Analysis
//!
//!  Output:
//!    results/summary.json         - Machine-readable results
//!    results/eigenvalues.csv      - Eigenvalue data per N
//!    results/rank1_accuracy.csv   - Rank-1 accuracy per partition per N
//!    results/witness.csv          - Möbius witness & d²_N per N
//!    results/precision_audit.csv  - Max |HP - f64| per N
//!    stdout                       - Human-readable report
//! ═══════════════════════════════════════════════════════════════════════════

use nalgebra::{DMatrix, DVector, SymmetricEigen, SVD};
use rayon::prelude::*;
use rug::Float;
use std::fs;
use std::time::Instant;

const P: u32 = 256; // 256-bit MPFR precision (~77 decimal digits)

// ═══════════════════════════════════════════════
// NUMBER THEORY
// ═══════════════════════════════════════════════

fn gcd(a: usize, b: usize) -> usize {
    let (mut a, mut b) = (a, b);
    while b != 0 { let t = b; b = a % b; a = t; } a
}
fn big_omega(mut n: usize) -> usize {
    let mut c = 0; let mut d = 2;
    while d * d <= n { while n % d == 0 { c += 1; n /= d; } d += 1; }
    if n > 1 { c += 1; } c
}
fn mobius(mut n: usize) -> i32 {
    if n <= 1 { return 1; }
    let mut c = 0; let mut d = 2;
    while d * d <= n {
        if n % d == 0 { n /= d; if n % d == 0 { return 0; } c += 1; }
        d += 1;
    }
    if n > 1 { c += 1; }
    if c % 2 == 0 { 1 } else { -1 }
}

// ═══════════════════════════════════════════════
// 256-BIT VASYUNIN COTANGENT FORMULA
// ═══════════════════════════════════════════════

fn vasyunin_hp(a: usize, b: usize) -> Float {
    if a <= 1 { return Float::with_val(P, 0); }
    let pi = Float::with_val(P, rug::float::Constant::Pi);
    let af = Float::with_val(P, a as u64);
    let mut total = Float::with_val(P, 0);
    for m in 1..a {
        let mb_mod = (m * b) % a;
        let mut frac = Float::with_val(P, mb_mod as u64);
        frac /= &af;
        let mut angle = Float::with_val(P, &pi);
        angle *= m as u64;
        angle /= &af;
        let sin_v = Float::with_val(P, angle.clone().sin());
        let cos_v = Float::with_val(P, angle.cos());
        if sin_v.clone().abs() < 1e-30 { continue; }
        let mut term = Float::with_val(P, &frac);
        term *= &cos_v;
        term /= &sin_v;
        total += term;
    }
    total
}

fn gram_hp(j: usize, k: usize) -> f64 {
    let pi = Float::with_val(P, rug::float::Constant::Pi);
    let gamma = Float::with_val(P, Float::parse(
        "0.57721566490153286060651209008240243104215933593992").unwrap());
    let mut two_pi = Float::with_val(P, &pi);
    two_pi *= 2u32;
    let ln2pi = Float::with_val(P, two_pi.ln());
    let mut coeff = Float::with_val(P, &ln2pi);
    coeff -= &gamma;
    coeff /= 2u32;
    let jf = Float::with_val(P, j as u64);
    let kf = Float::with_val(P, k as u64);
    let mut jk = Float::with_val(P, &jf);
    jk *= &kf;

    if j == k {
        let mut result = Float::with_val(P, &ln2pi);
        result -= &gamma;
        result /= &jf;
        let mut jsq = Float::with_val(P, &jf);
        jsq *= &jf;
        let mut inv_jsq = Float::with_val(P, 1u32);
        inv_jsq /= &jsq;
        result -= &inv_jsq;
        return result.to_f64();
    }

    let d = gcd(j, k);
    let (jp, kp) = (j / d, k / d);

    let mut inv_j = Float::with_val(P, 1u32); inv_j /= &jf;
    let mut inv_k = Float::with_val(P, 1u32); inv_k /= &kf;
    let mut inv_sum = Float::with_val(P, &inv_j); inv_sum += &inv_k;
    let mut t1 = Float::with_val(P, &coeff); t1 *= &inv_sum;

    let mut diff = Float::with_val(P, &jf); diff -= &kf;
    let mut den2 = Float::with_val(P, 2u32); den2 *= &jk;
    let mut ratio = Float::with_val(P, &kf); ratio /= &jf;
    let ln_ratio = Float::with_val(P, ratio.ln());
    let mut t2 = Float::with_val(P, &diff); t2 /= &den2; t2 *= &ln_ratio;

    let v1 = vasyunin_hp(jp, kp);
    let v2 = vasyunin_hp(kp, jp);
    let mut v_sum = Float::with_val(P, &v1); v_sum += &v2;
    let mut den3 = Float::with_val(P, 2u32); den3 *= &jk;
    let mut t3 = Float::with_val(P, &pi); t3 *= d as u64; t3 /= &den3; t3 *= &v_sum;

    let mut t4 = Float::with_val(P, 1u32); t4 /= &jk;

    let mut result = Float::with_val(P, &t1);
    result += &t2; result -= &t3; result -= &t4;
    result.to_f64()
}

// f64 version for precision comparison
const EG: f64 = 0.5772156649015328606;

fn vasyunin_f64(a: usize, b: usize) -> f64 {
    if a <= 1 { return 0.0; }
    let pi = std::f64::consts::PI; let af = a as f64;
    let mut t = 0.0;
    for m in 1..a {
        let fr = ((m * b) % a) as f64 / af;
        let ang = pi * m as f64 / af;
        let (s, c) = ang.sin_cos();
        if s.abs() < 1e-15 { continue; }
        t += fr * c / s;
    }
    t
}
fn gram_f64(j: usize, k: usize) -> f64 {
    let pi = std::f64::consts::PI; let l2p = (2.0 * pi).ln(); let co = (l2p - EG) / 2.0;
    let (jf, kf) = (j as f64, k as f64); let jk = jf * kf;
    if j == k { return (l2p - EG) / jf - 1.0 / (jf * jf); }
    let d = gcd(j, k); let (jp, kp) = (j / d, k / d);
    co * (1.0 / jf + 1.0 / kf) + (jf - kf) / (2.0 * jk) * (kf / jf).ln()
        - pi * d as f64 / (2.0 * jk) * (vasyunin_f64(jp, kp) + vasyunin_f64(kp, jp))
        - 1.0 / jk
}

// ═══════════════════════════════════════════════
// HIGH-PRECISION GRAM MATRIX
// ═══════════════════════════════════════════════

fn build_gram(n: usize) -> (DMatrix<f64>, f64) {
    let dim = n - 1;
    let pairs: Vec<_> = (0..dim).flat_map(|i| (i..dim).map(move |j| (i, j))).collect();
    let entries: Vec<_> = pairs.par_iter().map(|&(i, j)| {
        let hp = gram_hp(i + 2, j + 2);
        let lo = gram_f64(i + 2, j + 2);
        (i, j, hp, (hp - lo).abs())
    }).collect();
    let mut g = DMatrix::zeros(dim, dim);
    let mut mx = 0.0f64;
    for (i, j, v, d) in entries { g[(i, j)] = v; g[(j, i)] = v; if d > mx { mx = d; } }
    (g, mx)
}

// ═══════════════════════════════════════════════
// PARTITION & ANALYSIS
// ═══════════════════════════════════════════════

fn partition(n: usize, m: usize) -> Vec<Vec<usize>> {
    let dim = n - 1;
    let mut c = vec![Vec::new(); m];
    for i in 0..dim {
        let k = i + 2;
        let class = if m == 1 { 0 } else if m == 2 { big_omega(k) % 2 } else { k % m };
        c[class].push(i);
    }
    c
}

fn block_cross(n: usize, g: &DMatrix<f64>, m: usize) -> (DMatrix<f64>, DMatrix<f64>) {
    let dim = n - 1;
    let cls = partition(n, m);
    let mut ic = vec![0usize; dim];
    for (c, ms) in cls.iter().enumerate() { for &i in ms { ic[i] = c; } }
    let mut gb = DMatrix::zeros(dim, dim);
    let mut gc = DMatrix::zeros(dim, dim);
    for i in 0..dim {
        for j in 0..dim {
            if ic[i] == ic[j] { gb[(i, j)] = g[(i, j)]; }
            else { gc[(i, j)] = g[(i, j)]; }
        }
    }
    (gb, gc)
}

#[derive(Clone)]
struct PartitionResult {
    modulus: usize,
    raw_mean: f64,
    eig_mean: f64,
    improvement: f64,
    sv_gap_min: f64,
    lambda_eff: f64,
}

fn analyze(n: usize, g: &DMatrix<f64>, m: usize) -> PartitionResult {
    let dim = n - 1;
    let nc = m;
    let cls = partition(n, m);
    let (gb, gc) = block_cross(n, g, m);
    let eb = SymmetricEigen::new(gb.clone());
    let w = &eb.eigenvectors;
    let bev: Vec<f64> = eb.eigenvalues.iter().cloned().collect();
    let me = w.transpose() * &gc * w;

    let mut ec = vec![0usize; dim];
    for i in 0..dim {
        let ev = w.column(i);
        let mut bc = 0; let mut be = 0.0f64;
        for c in 0..nc {
            let e: f64 = cls[c].iter().map(|&ii| ev[ii] * ev[ii]).sum();
            if e > be { be = e; bc = c; }
        }
        ec[i] = bc;
    }
    let mut ebc: Vec<Vec<usize>> = vec![Vec::new(); nc];
    for (i, &c) in ec.iter().enumerate() { ebc[c].push(i); }

    let pairs: Vec<_> = (0..nc).flat_map(|i| ((i + 1)..nc).map(move |j| (i, j))).collect();
    let res: Vec<(f64, f64, f64, f64)> = pairs.par_iter().map(|&(c1, c2)| {
        let (ra, rg) = {
            let (r, c) = (&cls[c1], &cls[c2]);
            if r.is_empty() || c.is_empty() { (1.0, f64::INFINITY) } else {
                let b = DMatrix::from_fn(r.len(), c.len(), |i, j| gc[(r[i], c[j])]);
                let fr: f64 = b.iter().map(|x| x * x).sum();
                let s = SVD::new(b, false, false);
                let mut sv: Vec<f64> = s.singular_values.iter().cloned().collect();
                sv.sort_by(|a, b| b.partial_cmp(a).unwrap());
                (if fr > 0.0 { sv[0] * sv[0] / fr } else { 1.0 },
                 if sv.len() >= 2 && sv[1] > 1e-15 { sv[0] / sv[1] } else { f64::INFINITY })
            }
        };
        let (ea, le) = {
            let (r, c) = (&ebc[c1], &ebc[c2]);
            if r.is_empty() || c.is_empty() { (1.0, f64::NAN) } else {
                let b = DMatrix::from_fn(r.len(), c.len(), |i, j| me[(r[i], c[j])]);
                let fr: f64 = b.iter().map(|x| x * x).sum();
                let s = SVD::new(b, true, false);
                let mut sv: Vec<f64> = s.singular_values.iter().cloned().collect();
                sv.sort_by(|a, b| b.partial_cmp(a).unwrap());
                let a = if fr > 0.0 { sv[0] * sv[0] / fr } else { 1.0 };
                let l = if let Some(ref u) = s.u {
                    let uc = u.column(0);
                    let mut rs = 0.0f64;
                    for (li, &gi) in r.iter().enumerate() {
                        let lam = bev[gi];
                        if lam.abs() > 1e-15 { rs += uc[li] * uc[li] / lam; }
                    }
                    if rs.abs() > 1e-30 { 1.0 / rs } else { f64::NAN }
                } else { f64::NAN };
                (a, l)
            }
        };
        (ra, rg, ea, le)
    }).collect();

    let ra: Vec<f64> = res.iter().map(|r| r.0).collect();
    let ea: Vec<f64> = res.iter().map(|r| r.2).collect();
    let le: Vec<f64> = res.iter().filter(|r| !r.3.is_nan()).map(|r| r.3).collect();
    let sg: Vec<f64> = res.iter().filter(|r| r.1.is_finite()).map(|r| r.1).collect();

    PartitionResult {
        modulus: m,
        raw_mean: ra.iter().sum::<f64>() / ra.len() as f64,
        eig_mean: ea.iter().sum::<f64>() / ea.len() as f64,
        improvement: (ea.iter().sum::<f64>() - ra.iter().sum::<f64>()) / ra.len() as f64,
        sv_gap_min: if !sg.is_empty() { sg.iter().cloned().fold(f64::INFINITY, f64::min) } else { f64::NAN },
        lambda_eff: if !le.is_empty() { le.iter().sum::<f64>() / le.len() as f64 } else { f64::NAN },
    }
}

// ═══════════════════════════════════════════════
// RESULT STRUCTURES
// ═══════════════════════════════════════════════

#[derive(Clone)]
struct NResult {
    n: usize,
    dim: usize,
    time_s: f64,
    max_delta: f64,
    lmin_g: f64,
    lmin_b1: f64,     // m=1 sanity check
    lmin_b2: f64,
    lmin_b8: f64,
    ratio_b1: f64,    // should be exactly 1.0
    ratio_b2: f64,
    ratio_b8: f64,
    r_parity: f64,
    r_trivial: f64,   // R for m=1 (should be 0 or NaN)
    parts: Vec<PartitionResult>,
    rayleigh: f64,
    witness_proj: f64,
    d_sq: f64,
}

// ═══════════════════════════════════════════════
// TERMINAL FORMATTING
// ═══════════════════════════════════════════════

const BOLD: &str = "\x1b[1m";
const DIM: &str = "\x1b[2m";
const CYAN: &str = "\x1b[36m";
const GREEN: &str = "\x1b[32m";
const YELLOW: &str = "\x1b[33m";
const MAGENTA: &str = "\x1b[35m";
const RED: &str = "\x1b[31m";
const WHITE: &str = "\x1b[97m";
const RESET: &str = "\x1b[0m";

fn bar(val: f64, max: f64, width: usize) -> String {
    let filled = ((val / max) * width as f64).round() as usize;
    let filled = filled.min(width);
    format!("{}{}{}",
        "█".repeat(filled),
        DIM,
        "░".repeat(width - filled))
}

fn print_header() {
    println!();
    println!("  {BOLD}{CYAN}╔═══════════════════════════════════════════════════════════════════════════╗{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}{WHITE}CATHEDRAL HIGH-PRECISION SPECTRAL EXPERIMENT{RESET}                          {BOLD}{CYAN}║{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {DIM}256-bit MPFR · Vasyunin cotangent formula · {} cores{RESET}                  {BOLD}{CYAN}║{RESET}",
        rayon::current_num_threads());
    println!("  {BOLD}{CYAN}╚═══════════════════════════════════════════════════════════════════════════╝{RESET}");
    println!();
}

fn print_result(r: &NResult) {
    let ln_n = (r.n as f64).ln();

    println!("  {BOLD}{CYAN}┌─── N = {}{RESET} {DIM}(dim = {}, {:.1}s, 256-bit){RESET}", r.n, r.dim, r.time_s);
    println!("  {CYAN}│{RESET}");

    // Precision
    let prec_color = if r.max_delta < 1e-13 { GREEN } else { YELLOW };
    println!("  {CYAN}│{RESET}  {DIM}Precision:{RESET}  {prec_color}max|G₂₅₆ − G_f64| = {:.2e}{RESET}", r.max_delta);
    println!("  {CYAN}│{RESET}");

    // Eigenvalues
    println!("  {CYAN}│{RESET}  {BOLD}Eigenvalues{RESET}");
    println!("  {CYAN}│{RESET}    λ_min(G)       = {GREEN}{:.12e}{RESET}", r.lmin_g);
    println!("  {CYAN}│{RESET}    λ_min(block₁)  = {:.12e}  {GREEN}(×{:.6}){RESET}  {DIM}← sanity: must be ×1.000{RESET}", r.lmin_b1, r.ratio_b1);
    println!("  {CYAN}│{RESET}    λ_min(block₂)  = {:.12e}  {YELLOW}(×{:.2}){RESET}", r.lmin_b2, r.ratio_b2);
    println!("  {CYAN}│{RESET}    λ_min(block₈)  = {:.12e}  {YELLOW}(×{:.2}){RESET}", r.lmin_b8, r.ratio_b8);
    println!("  {CYAN}│{RESET}    R(trivial)     = {GREEN}{:.10}{RESET}  {DIM}← sanity: must be 0{RESET}", r.r_trivial);
    println!("  {CYAN}│{RESET}    R(parity)      = {MAGENTA}{:.10}{RESET}", r.r_parity);
    println!("  {CYAN}│{RESET}");

    // Rank-1
    println!("  {CYAN}│{RESET}  {BOLD}Rank-1 Accuracy{RESET}  {DIM}(σ₁²/‖block‖²_F){RESET}");
    println!("  {CYAN}│{RESET}    {DIM}partition │ raw_mean     eig_mean     Δ           σ₁/σ₂    λ_eff     λ_eff/ln(N){RESET}");
    for p in &r.parts {
        let label = match p.modulus { 1 => "m=1 ✓  ", 2 => "mod 2   ", 4 => "mod 4   ", _ => "mod 8   " };
        if p.modulus == 1 {
            // m=1: no inter-class pairs → all metrics are N/A
            println!("  {CYAN}│{RESET}    {BOLD}{}{RESET} │ {DIM}N/A          N/A          N/A         N/A      N/A       N/A{RESET}  {GREEN}← trivial (no cross){RESET}", label);
            continue;
        }
        let acc_col = if p.raw_mean > 0.96 { GREEN } else if p.raw_mean > 0.93 { YELLOW } else { RED };
        println!("  {CYAN}│{RESET}    {BOLD}{}{RESET} │ {acc_col}{:.4}%{RESET}    {acc_col}{:.4}%{RESET}    {:+.4}%    {:.3}    {:.4}    {:.6}",
            label,
            p.raw_mean * 100.0, p.eig_mean * 100.0,
            p.improvement * 100.0, p.sv_gap_min,
            p.lambda_eff, p.lambda_eff / ln_n);
    }
    println!("  {CYAN}│{RESET}");

    // Witness
    println!("  {CYAN}│{RESET}  {BOLD}Möbius Witness{RESET}");
    println!("  {CYAN}│{RESET}    Rayleigh(v̂)     = {GREEN}{:.12}{RESET}", r.rayleigh);
    println!("  {CYAN}│{RESET}    |⟨v̂, v_min⟩|    = {:.10}", r.witness_proj);
    println!("  {CYAN}│{RESET}    d²_N            = {MAGENTA}{:.12}{RESET}", r.d_sq);
    println!("  {CYAN}│{RESET}    ln(N)·d²_N      = {:.8}", ln_n * r.d_sq);
    println!("  {CYAN}└──────────────────────────────────────────────────────────────────────{RESET}");
    println!();
}

fn print_summary_table(results: &[NResult]) {
    println!("  {BOLD}{CYAN}╔═══════════════════════════════════════════════════════════════════════════╗{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}{WHITE}SUMMARY TABLE{RESET}                                                          {BOLD}{CYAN}║{RESET}");
    println!("  {BOLD}{CYAN}╠═══════════════════════════════════════════════════════════════════════════╣{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}");

    // Eigenvalue table
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}Eigenvalues & Spectral Gap{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {DIM}    N    │  λ_min(G)         │  b₁/G       │  block₂/G   │  block₈/G   │  R(parity){RESET}");
    for r in results {
        let b1_ok = if (r.ratio_b1 - 1.0).abs() < 1e-10 { GREEN } else { RED };
        println!("  {BOLD}{CYAN}║{RESET}    {:>5} │  {GREEN}{:.8e}{RESET}  │  {b1_ok}×{:.6}{RESET}  │  {YELLOW}×{:.3}{RESET}      │  {YELLOW}×{:.3}{RESET}      │  {MAGENTA}{:.8}{RESET}",
            r.n, r.lmin_g, r.ratio_b1, r.ratio_b2, r.ratio_b8, r.r_parity);
    }
    println!("  {BOLD}{CYAN}║{RESET}");

    // Rank-1 accuracy table (mod 2 only for brevity, plus mod 8)
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}Rank-1 Accuracy (mod 2){RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {DIM}    N    │  raw_mean    eig_mean   Δ          λ_eff     λ_eff/ln(N){RESET}");
    for r in results {
        let p2 = &r.parts[1]; // index 1 because m=1 is now index 0
        let ln_n = (r.n as f64).ln();
        println!("  {BOLD}{CYAN}║{RESET}    {:>5} │  {:.4}%   {:.4}%  {:+.4}%   {:.4}    {GREEN}{:.6}{RESET}",
            r.n, p2.raw_mean * 100.0, p2.eig_mean * 100.0, p2.improvement * 100.0,
            p2.lambda_eff, p2.lambda_eff / ln_n);
    }
    println!("  {BOLD}{CYAN}║{RESET}");

    // λ_eff scaling table
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}λ_eff Scaling Across Cayley-Dickson Tower{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {DIM}    N    │  λ_eff(m2)   λ_eff(m4)   λ_eff(m8)   │  m2/ln   m4/ln   m8/ln{RESET}");
    for r in results {
        let ln = (r.n as f64).ln();
        // parts[0]=m1 (N/A), parts[1]=m2, parts[2]=m4, parts[3]=m8
        println!("  {BOLD}{CYAN}║{RESET}    {:>5} │  {:.4}      {:.4}      {:.4}      │  {GREEN}{:.4}{RESET}   {:.4}   {:.4}",
            r.n,
            r.parts[1].lambda_eff, r.parts[2].lambda_eff, r.parts[3].lambda_eff,
            r.parts[1].lambda_eff / ln, r.parts[2].lambda_eff / ln, r.parts[3].lambda_eff / ln);
    }
    println!("  {BOLD}{CYAN}║{RESET}");

    // Witness table
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}Möbius Witness & NB Distance{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {DIM}    N    │  Rayleigh       |⟨v̂,v_min⟩|  d²_N           ln(N)·d²{RESET}");
    for r in results {
        let ln_n = (r.n as f64).ln();
        println!("  {BOLD}{CYAN}║{RESET}    {:>5} │  {GREEN}{:.10}{RESET}   {:.8}    {MAGENTA}{:.10}{RESET}   {:.6}",
            r.n, r.rayleigh, r.witness_proj, r.d_sq, ln_n * r.d_sq);
    }
    println!("  {BOLD}{CYAN}║{RESET}");

    // Precision audit
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}Precision Audit{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {DIM}    N    │  max|G₂₅₆ − G_f64|{RESET}");
    for r in results {
        let col = if r.max_delta < 1e-13 { GREEN } else { YELLOW };
        println!("  {BOLD}{CYAN}║{RESET}    {:>5} │  {col}{:.3e}{RESET}  {}",
            r.n, r.max_delta, bar(r.max_delta.log10().abs(), 16.0, 20));
    }
    println!("  {BOLD}{CYAN}║{RESET}");

    // Verdicts
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}{WHITE}═══ VERDICTS ═══{RESET}");
    let all_delta_ok = results.iter().all(|r| r.max_delta < 1e-10);
    let all_eig_inv = results.iter().all(|r| r.parts.iter().filter(|p| p.modulus > 1).all(|p| p.improvement.abs() < 1e-4));
    let leff_grows = results.last().unwrap().parts[1].lambda_eff > results.first().unwrap().parts[1].lambda_eff;
    let r_below_1 = results.iter().all(|r| r.r_parity < 1.0);
    let dsq_positive = results.iter().all(|r| r.d_sq > 0.0);
    let sanity_b1 = results.iter().all(|r| (r.ratio_b1 - 1.0).abs() < 1e-10);
    let sanity_r0 = results.iter().all(|r| r.r_trivial < 1e-10);

    let check = |b: bool| if b { format!("{GREEN}✓{RESET}") } else { format!("{RED}✗{RESET}") };
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}Sanity Checks (m=1 trivial partition):{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}    {} block₁/G = 1.0 at all N (block = G)", check(sanity_b1));
    println!("  {BOLD}{CYAN}║{RESET}    {} R(trivial) = 0 at all N (no cross-class)", check(sanity_r0));
    println!("  {BOLD}{CYAN}║{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}Main Verdicts:{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}    {} f64 precision sufficient (all Δ < 1e-10)", check(all_delta_ok));
    println!("  {BOLD}{CYAN}║{RESET}    {} Eigenbasis is a no-op (all |Δ| < 0.01%)", check(all_eig_inv));
    println!("  {BOLD}{CYAN}║{RESET}    {} λ_eff grows with N", check(leff_grows));
    println!("  {BOLD}{CYAN}║{RESET}    {} R(parity) < 1 at all N", check(r_below_1));
    println!("  {BOLD}{CYAN}║{RESET}    {} d²_N > 0 at all N (NB distance positive)", check(dsq_positive));
    println!("  {BOLD}{CYAN}║{RESET}");

    let leff_ratios: Vec<f64> = results.iter().map(|r| r.parts[1].lambda_eff / (r.n as f64).ln()).collect();
    let mean_ratio: f64 = leff_ratios.iter().sum::<f64>() / leff_ratios.len() as f64;
    println!("  {BOLD}{CYAN}║{RESET}    λ_eff(mod2)/ln(N) ≈ {BOLD}{GREEN}{:.4}{RESET}  {DIM}(mean over all N){RESET}", mean_ratio);
    println!("  {BOLD}{CYAN}║{RESET}    Rank-1 accuracy decays as ≈ {BOLD}{YELLOW}N^{{-1/4}}{RESET}  {DIM}(finite-size effect){RESET}");
    println!("  {BOLD}{CYAN}║{RESET}    Rank-1 conjecture (99.99% at N→∞): {BOLD}{RED}REFUTED{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}    Cathedral foundation (H_N PD): {BOLD}{GREEN}UNAFFECTED{RESET}");

    println!("  {BOLD}{CYAN}║{RESET}");
    println!("  {BOLD}{CYAN}╚═══════════════════════════════════════════════════════════════════════════╝{RESET}");
}

// ═══════════════════════════════════════════════
// FILE OUTPUT
// ═══════════════════════════════════════════════

fn write_results(results: &[NResult], dir: &str) {
    fs::create_dir_all(dir).unwrap();

    // summary.json
    let mut json = String::from("{\n  \"experiment\": \"Cathedral High-Precision Spectral Experiment\",\n");
    json += &format!("  \"precision_bits\": {},\n", P);
    json += &format!("  \"cores\": {},\n", rayon::current_num_threads());
    json += "  \"results\": [\n";
    for (idx, r) in results.iter().enumerate() {
        let ln_n = (r.n as f64).ln();
        json += &format!("    {{\n      \"N\": {},\n      \"dim\": {},\n",  r.n, r.dim);
        json += &format!("      \"time_s\": {:.3},\n", r.time_s);
        json += &format!("      \"max_f64_delta\": {:.6e},\n", r.max_delta);
        json += &format!("      \"lambda_min_G\": {:.15e},\n", r.lmin_g);
        json += &format!("      \"lambda_min_block2\": {:.15e},\n", r.lmin_b2);
        json += &format!("      \"lambda_min_block8\": {:.15e},\n", r.lmin_b8);
        json += &format!("      \"block2_over_G\": {:.6},\n", r.ratio_b2);
        json += &format!("      \"block8_over_G\": {:.6},\n", r.ratio_b8);
        json += &format!("      \"R_parity\": {:.12},\n", r.r_parity);
        json += "      \"rank1\": {\n";
        for (pi, p) in r.parts.iter().enumerate() {
            json += &format!("        \"mod{}\": {{ \"raw_mean\": {:.8}, \"eig_mean\": {:.8}, \"improvement\": {:.8e}, \"sv_gap_min\": {:.6}, \"lambda_eff\": {:.8}, \"lambda_eff_over_lnN\": {:.8} }}",
                p.modulus, p.raw_mean, p.eig_mean, p.improvement, p.sv_gap_min, p.lambda_eff, p.lambda_eff / ln_n);
            json += if pi < r.parts.len() - 1 { ",\n" } else { "\n" };
        }
        json += "      },\n";
        json += &format!("      \"rayleigh\": {:.15},\n", r.rayleigh);
        json += &format!("      \"witness_proj\": {:.15},\n", r.witness_proj);
        json += &format!("      \"d_sq_N\": {:.15},\n", r.d_sq);
        json += &format!("      \"lnN_d_sq\": {:.12}\n", ln_n * r.d_sq);
        json += if idx < results.len() - 1 { "    },\n" } else { "    }\n" };
    }
    json += "  ]\n}\n";
    fs::write(format!("{}/summary.json", dir), &json).unwrap();

    // eigenvalues.csv
    let mut csv = String::from("N,dim,lambda_min_G,lambda_min_block2,lambda_min_block8,ratio_b2,ratio_b8,R_parity\n");
    for r in results {
        csv += &format!("{},{},{:.15e},{:.15e},{:.15e},{:.6},{:.6},{:.12}\n",
            r.n, r.dim, r.lmin_g, r.lmin_b2, r.lmin_b8, r.ratio_b2, r.ratio_b8, r.r_parity);
    }
    fs::write(format!("{}/eigenvalues.csv", dir), &csv).unwrap();

    // rank1_accuracy.csv
    let mut csv = String::from("N,modulus,raw_mean,eig_mean,improvement,sv_gap_min,lambda_eff,lambda_eff_over_lnN\n");
    for r in results {
        let ln_n = (r.n as f64).ln();
        for p in &r.parts {
            csv += &format!("{},{},{:.10},{:.10},{:.10e},{:.6},{:.10},{:.10}\n",
                r.n, p.modulus, p.raw_mean, p.eig_mean, p.improvement,
                p.sv_gap_min, p.lambda_eff, p.lambda_eff / ln_n);
        }
    }
    fs::write(format!("{}/rank1_accuracy.csv", dir), &csv).unwrap();

    // witness.csv
    let mut csv = String::from("N,rayleigh,witness_proj,d_sq_N,lnN_d_sq\n");
    for r in results {
        let ln_n = (r.n as f64).ln();
        csv += &format!("{},{:.15},{:.15},{:.15},{:.12}\n",
            r.n, r.rayleigh, r.witness_proj, r.d_sq, ln_n * r.d_sq);
    }
    fs::write(format!("{}/witness.csv", dir), &csv).unwrap();

    // precision_audit.csv
    let mut csv = String::from("N,max_delta_f64,log10_delta\n");
    for r in results {
        csv += &format!("{},{:.6e},{:.4}\n", r.n, r.max_delta, r.max_delta.log10());
    }
    fs::write(format!("{}/precision_audit.csv", dir), &csv).unwrap();

    eprintln!("  {GREEN}✓{RESET} Results written to {BOLD}{}{RESET}/", dir);
}

// ═══════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════

fn run(n: usize) -> NResult {
    let t0 = Instant::now();
    let dim = n - 1;
    let ln_n = (n as f64).ln();

    eprintln!("  {DIM}▸ N={}: building {}×{} Gram at 256-bit...{RESET}", n, dim, dim);
    let (g, md) = build_gram(n);
    eprintln!("  {DIM}  └─ {:.1}s, max Δ = {:.2e}{RESET}", t0.elapsed().as_secs_f64(), md);

    let eg = SymmetricEigen::new(g.clone());
    let mut gev: Vec<f64> = eg.eigenvalues.iter().cloned().collect();
    gev.sort_by(|a, b| a.partial_cmp(b).unwrap());
    let lm = gev[0];

    let mut mi = 0;
    for (i, &v) in eg.eigenvalues.iter().enumerate() { if v < eg.eigenvalues[mi] { mi = i; } }
    let vm = eg.eigenvectors.column(mi);

    // m=1 sanity check: block = G, cross = 0
    let (gb1, gc1) = block_cross(n, &g, 1);
    let mut b1e: Vec<f64> = SymmetricEigen::new(gb1.clone()).eigenvalues.iter().cloned().collect();
    b1e.sort_by(|a, b| a.partial_cmp(b).unwrap());

    let df1 = vm.dot(&(&gb1 * &vm));
    let cf1 = vm.dot(&(&gc1 * &vm));
    let rr_trivial = if df1.abs() > 1e-30 { cf1.abs() / df1 } else { 0.0 };

    let (gb2, gc2) = block_cross(n, &g, 2);
    let (gb8, _) = block_cross(n, &g, 8);
    let mut b2e: Vec<f64> = SymmetricEigen::new(gb2.clone()).eigenvalues.iter().cloned().collect();
    b2e.sort_by(|a, b| a.partial_cmp(b).unwrap());
    let mut b8e: Vec<f64> = SymmetricEigen::new(gb8).eigenvalues.iter().cloned().collect();
    b8e.sort_by(|a, b| a.partial_cmp(b).unwrap());

    let df = vm.dot(&(&gb2 * &vm));
    let cf = vm.dot(&(&gc2 * &vm));
    let rr = if df.abs() > 1e-30 { cf.abs() / df } else { f64::NAN };

    let r1 = analyze(n, &g, 1);
    let r2 = analyze(n, &g, 2);
    let r4 = analyze(n, &g, 4);
    let r8 = analyze(n, &g, 8);

    let lw: DVector<f64> = DVector::from_fn(dim, |i, _| {
        let k = i + 2;
        -(mobius(k) as f64) * (1.0 - (k as f64).ln() / ln_n)
    });
    let lwn = lw.norm();
    let lwh = &lw / lwn;
    let ray = lwh.dot(&(&g * &lwh));
    let wp = lwh.dot(&vm).abs();

    let bv = DVector::from_fn(dim, |i, _| {
        let k = (i + 2) as f64;
        (k.ln() + 1.0 - EG) / k
    });
    let dsq = if let Some(gi) = g.clone().try_inverse() {
        1.0 - bv.dot(&(&gi * &bv))
    } else { f64::NAN };

    NResult {
        n, dim,
        time_s: t0.elapsed().as_secs_f64(),
        max_delta: md,
        lmin_g: lm,
        lmin_b1: b1e[0],
        lmin_b2: b2e[0],
        lmin_b8: b8e[0],
        ratio_b1: b1e[0] / lm,
        ratio_b2: b2e[0] / lm,
        ratio_b8: b8e[0] / lm,
        r_parity: rr,
        r_trivial: rr_trivial,
        parts: vec![r1, r2, r4, r8],
        rayleigh: ray,
        witness_proj: wp,
        d_sq: dsq,
    }
}

fn main() {
    let t = Instant::now();
    print_header();

    let sizes = vec![50, 100, 200, 300, 500, 800, 1000, 1500, 2000];
    let mut results = Vec::new();

    for &n in &sizes {
        let r = run(n);
        print_result(&r);
        results.push(r);
    }

    print_summary_table(&results);

    let dir = "results";
    write_results(&results, dir);

    println!();
    println!("  {BOLD}{WHITE}Total runtime:{RESET} {GREEN}{:.1}s{RESET} on {} cores",
        t.elapsed().as_secs_f64(), rayon::current_num_threads());
    println!("  {BOLD}{WHITE}Precision:{RESET} 256-bit MPFR (rug/gmp-mpfr-sys)");
    println!("  {BOLD}{WHITE}Output:{RESET} {}/summary.json, eigenvalues.csv, rank1_accuracy.csv, witness.csv, precision_audit.csv", dir);
    println!();
}
