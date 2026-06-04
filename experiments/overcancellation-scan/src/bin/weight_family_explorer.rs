// overcancellation-scan/src/bin/weight_family_explorer.rs
//
// ╔═══════════════════════════════════════════════════════════════════════╗
// ║  WEIGHT FAMILY EXPLORER — Finding the Weight That Closes the Gap    ║
// ║                                                                       ║
// ║  Tests damped Möbius weight families v_k = -μ(k)·w^β(k)·k^{-α}     ║
// ║  against HPDF-certified Gram matrices.                               ║
// ║                                                                       ║
// ║  Key diagnostic: does max|inner_k| × Σ|v_k| ≤ 1?                    ║
// ║  If so, the bilinear_row_bound from InnerAbel CLOSES.                ║
// ║                                                                       ║
// ║  Also checks: vtGv ≤ 1 and d² = 1 - 2bᵀv + vtGv.                    ║
// ║  Cathedral — The Weight Sweep 🧪                                      ║
// ║  June 2, 2026                                                         ║
// ╚═══════════════════════════════════════════════════════════════════════╝

use cathedral_utils::hpdf::HpdfReader;
use rayon::prelude::*;
use std::f64::consts::PI;
use std::path::PathBuf;

const EULER_GAMMA: f64 = 0.5772156649015329;

/// Sieve μ(k) for k=0..n
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

/// V(a,b) = Σ_{m=1}^{a-1} cot(πm/a) · {mb/a}
fn vasyunin_sum(a: usize, b: usize) -> f64 {
    if a <= 1 { return 0.0; }
    let af = a as f64;
    let mut s = 0.0;
    for m in 1..a {
        let angle = PI * m as f64 / af;
        let sin_v = angle.sin();
        if sin_v.abs() < 1e-15 { continue; }
        let cot = angle.cos() / sin_v;
        let frac = ((m * b) as f64 / af).fract();
        s += cot * frac;
    }
    s
}

/// Compute G(1,k) analytically
fn gram_entry_k1(k: usize) -> f64 {
    let c = (2.0 * PI).ln() - EULER_GAMMA;
    if k == 1 { return c - 1.0; }
    let kf = k as f64;
    let t1 = c / 2.0 * (1.0 + 1.0 / kf);
    let t2 = (1.0 - kf) / (2.0 * kf) * kf.ln();
    let vk1 = vasyunin_sum(k, 1);
    let t3 = PI / (2.0 * kf) * vk1;
    let t4 = 1.0 / kf;
    t1 + t2 - t3 - t4
}

/// A weight family parameterized by (α, β):
///   v_k = -μ(k) · w(k)^β · k^{-α}
/// where w(k) = max(0, 1 - ln(k)/ln(N)) is the Fejér taper.
#[derive(Clone)]
struct WeightFamily {
    name: String,
    alpha: f64,  // power damping exponent
    beta: f64,   // taper exponent
}

impl WeightFamily {
    fn new(name: &str, alpha: f64, beta: f64) -> Self {
        Self { name: name.to_string(), alpha, beta }
    }
    
    /// Compute weight for index k given N and μ(k).
    fn weight(&self, k: usize, n: usize, mu_k: i8) -> f64 {
        if mu_k == 0 { return 0.0; }
        let kf = k as f64;
        let w = (1.0 - kf.ln() / (n as f64).ln()).max(0.0);
        -(mu_k as f64) * w.powf(self.beta) * kf.powf(-self.alpha)
    }
}

/// Results from testing a weight family against a Gram matrix.
struct WeightResult {
    name: String,
    n: usize,
    vtgv: f64,
    d_sq: f64,
    l1: f64,
    max_inner: f64,
    bilinear_bound: f64,
    sigma: f64,
    s_val: f64,
}

/// Test a weight family against the HPDF Gram matrix.
/// The HPDF matrix covers k=2..N (dim = N-1). We augment with k=1 analytically.
fn test_weight_family(
    family: &WeightFamily,
    n: usize,
    gram: &[f64],
    dim: usize,
    mu: &[i8],
) -> WeightResult {
    let log_n = (n as f64).ln();
    
    // Build weight vector for k=2..N (HPDF sector)
    let mut v2 = vec![0.0f64; dim];
    for i in 0..dim {
        let k = i + 2;
        if k >= n { break; }
        v2[i] = family.weight(k, n, mu[k]);
    }
    
    // k=1 weight
    let v1 = family.weight(1, n, mu[1]);
    
    // Compute Gv for k≥2 sector (parallel)
    let gv2: Vec<f64> = (0..dim).into_par_iter().map(|i| {
        let mut s = 0.0;
        for j in 0..dim {
            s += gram[i * dim + j] * v2[j];
        }
        s
    }).collect();
    
    // vtGv for k≥2 sector
    let vtgv_k2: f64 = (0..dim).map(|i| v2[i] * gv2[i]).sum();
    
    // k=1 contributions
    let g11 = gram_entry_k1(1);
    let diag_k1 = v1 * v1 * g11;
    
    // Cross terms and k=1 inner product
    let mut cross_vtgv = 0.0f64;
    let mut inner_k1 = v1 * g11; // G(1,1)*v1
    
    for i in 0..dim {
        let k = i + 2;
        if k >= n { break; }
        let g1k = gram_entry_k1(k);
        cross_vtgv += 2.0 * v1 * v2[i] * g1k;
        inner_k1 += v2[i] * g1k; // sum of v_j * G(j,1) for j>=2
    }
    
    // Full vtGv
    let vtgv = vtgv_k2 + diag_k1 + cross_vtgv;
    
    // Full inner products (Gv)_k for all k
    // For k>=2: (Gv)_k = gv2[k-2] + v1 * G(1,k)
    let mut max_inner = inner_k1.abs(); // k=1 row
    for i in 0..dim {
        let k = i + 2;
        if k >= n { break; }
        let g1k = gram_entry_k1(k);
        let full_inner_k = gv2[i] + v1 * g1k;
        if full_inner_k.abs() > max_inner {
            max_inner = full_inner_k.abs();
        }
    }
    
    // L1 norm, sigma, S
    let mut l1 = v1.abs();
    let mut sigma = v1;
    let mut s_val = v1; // v1/1
    
    for i in 0..dim {
        let k = i + 2;
        if k >= n { break; }
        l1 += v2[i].abs();
        sigma += v2[i];
        s_val += v2[i] / (k as f64);
    }
    
    // d² = 1 - 2bᵀv + vtGv, where b_k ≈ 1/(2k)
    let mut btv = v1 * 0.5; // b_1 = 1/2
    for i in 0..dim {
        let k = i + 2;
        if k >= n { break; }
        btv += v2[i] * 0.5 / (k as f64);
    }
    let d_sq = 1.0 - 2.0 * btv + vtgv;
    
    WeightResult {
        name: family.name.clone(),
        n,
        vtgv,
        d_sq,
        l1,
        max_inner,
        bilinear_bound: max_inner * l1,
        sigma,
        s_val,
    }
}

fn main() {
    println!("╔═══════════════════════════════════════════════════════════════════════════╗");
    println!("║  WEIGHT FAMILY EXPLORER — HPDF-Backed                          🧪⚡     ║");
    println!("║  v_k = -μ(k) · w(k)^β · k^{{-α}}                                        ║");
    println!("║  Cathedral — Finding the Weight That Closes the Gap                      ║");
    println!("╚═══════════════════════════════════════════════════════════════════════════╝");
    println!();
    
    let cache_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent().unwrap()
        .join("cache/hpdf");
    
    // Define weight families
    let families = vec![
        WeightFamily::new("Fejér(α=0,β=1)", 0.0, 1.0),
        WeightFamily::new("Power(α=0.5)",   0.5, 1.0),
        WeightFamily::new("Mertens(α=1)",   1.0, 1.0),
        WeightFamily::new("α=1.25",         1.25, 1.0),
        WeightFamily::new("α=1.5",          1.5, 1.0),
        WeightFamily::new("α=1.75",         1.75, 1.0),
        WeightFamily::new("Heavy(α=2)",     2.0, 1.0),
        WeightFamily::new("Ultra(α=3)",     3.0, 1.0),
        // Beta variations (taper exponent)
        WeightFamily::new("Selberg(β=2)",   0.0, 2.0),
        WeightFamily::new("α=1,β=2",        1.0, 2.0),
        WeightFamily::new("α=1.5,β=2",      1.5, 2.0),
        WeightFamily::new("α=2,β=2",        2.0, 2.0),
        // Mixed
        WeightFamily::new("α=0.5,β=2",      0.5, 2.0),
        WeightFamily::new("α=1,β=0.5",      1.0, 0.5),
        WeightFamily::new("α=0.75,β=1.5",   0.75, 1.5),
    ];
    
    // HC numbers with HPDF files
    let hc_ns: Vec<usize> = vec![
        60, 120, 240, 360, 840, 1260, 2520, 5040, 7560, 10080,
        20160, 27720, 45360, 55440,
    ];
    
    // ═══ SECTION 1: Full family comparison ═══
    println!("═══ SECTION 1: All Weight Families ═══");
    println!();
    
    for &n in &hc_ns {
        let path = cache_dir.join(format!("gram_N{}.h5", n));
        if !path.exists() { continue; }
        
        let reader = match HpdfReader::open(&path) {
            Ok(r) => r,
            Err(e) => { eprintln!("  [skip] N={}: {}", n, e); continue; }
        };
        
        let dim = reader.dim();
        let mu_raw = reader.read_mobius().unwrap_or_else(|_| sieve_mobius(n));
        let gram = match reader.read_gram_full() {
            Ok(g) => g,
            Err(e) => { eprintln!("  [skip] N={}: read_gram_full failed: {}", n, e); continue; }
        };
        
        println!("  N = {} (dim={})", n, dim);
        println!("  {:<17} {:>10} {:>10} {:>8} {:>10} {:>10} {:>8} {:>8} {:>5}",
            "Family", "vtGv", "d²", "Σ|v|", "max|in|", "bound", "σ", "S", "≤1?");
        println!("  {} {} {} {} {} {} {} {} {}",
            "-".repeat(17), "-".repeat(10), "-".repeat(10), "-".repeat(8),
            "-".repeat(10), "-".repeat(10), "-".repeat(8), "-".repeat(8), "-".repeat(5));
        
        for family in &families {
            let r = test_weight_family(family, n, &gram, dim, &mu_raw);
            let check = if r.bilinear_bound <= 1.0 { " ✅" } else { " ❌" };
            println!("  {:<17} {:>10.4} {:>10.4} {:>8.2} {:>10.6} {:>10.4} {:>8.4} {:>8.4} {}",
                r.name, r.vtgv, r.d_sq, r.l1, r.max_inner, r.bilinear_bound,
                r.sigma, r.s_val, check);
        }
        println!();
    }
    
    // ═══ SECTION 2: α sweep for β=1 ═══
    println!("═══ SECTION 2: α Sweep (β=1, varying damping power) ═══");
    println!();
    
    let alphas: Vec<f64> = (0..=30).map(|i| i as f64 * 0.1).collect();
    
    println!("  {:<8}", "α \\ N");
    print!("  {:>8}", "");
    for &n in &hc_ns {
        if n > 10080 { continue; }
        print!("  {:>12}", format!("N={}", n));
    }
    println!("  (bound=max|in|×Σ|v|)");
    println!("  {}", "-".repeat(8 + hc_ns.iter().filter(|&&n| n <= 10080).count() * 14));
    
    for &alpha in &alphas {
        let family = WeightFamily::new(&format!("α={:.1}", alpha), alpha, 1.0);
        print!("  α={:<5.1}", alpha);
        
        for &n in &hc_ns {
            if n > 10080 { continue; }
            let path = cache_dir.join(format!("gram_N{}.h5", n));
            if !path.exists() { print!("  {:>12}", "---"); continue; }
            
            let reader = match HpdfReader::open(&path) {
                Ok(r) => r,
                Err(_) => { print!("  {:>12}", "err"); continue; }
            };
            
            let dim = reader.dim();
            let mu_raw = reader.read_mobius().unwrap_or_else(|_| sieve_mobius(n));
            let gram = match reader.read_gram_full() {
                Ok(g) => g,
                Err(_) => { print!("  {:>12}", "err"); continue; }
            };
            
            let r = test_weight_family(&family, n, &gram, dim, &mu_raw);
            let marker = if r.bilinear_bound <= 1.0 { "✅" } else { "❌" };
            print!("  {:>10.4}{}", r.bilinear_bound, marker);
        }
        println!();
    }
    
    // ═══ SECTION 3: The sweet spot — 2D sweep (α,β) ═══
    println!();
    println!("═══ SECTION 3: 2D (α,β) Sweet Spot Search at N=2520 ═══");
    println!();
    
    let path = cache_dir.join("gram_N2520.h5");
    if path.exists() {
        let reader = HpdfReader::open(&path).unwrap();
        let dim = reader.dim();
        let mu_raw = reader.read_mobius().unwrap_or_else(|_| sieve_mobius(2520));
        let gram = reader.read_gram_full().unwrap();
        
        println!("  {:<12} {:>8} {:>10} {:>10} {:>10} {:>8}", 
            "(α, β)", "vtGv", "d²", "bound", "Σ|v|", "≤1?");
        println!("  {} {} {} {} {} {}",
            "-".repeat(12), "-".repeat(8), "-".repeat(10), "-".repeat(10),
            "-".repeat(10), "-".repeat(8));
        
        let alphas_2d: Vec<f64> = (0..=25).map(|i| i as f64 * 0.1).collect();
        let betas_2d: Vec<f64> = vec![0.5, 1.0, 1.5, 2.0, 3.0];
        
        for &beta in &betas_2d {
            for &alpha in &alphas_2d {
                let name = format!("({:.1},{:.1})", alpha, beta);
                let family = WeightFamily::new(&name, alpha, beta);
                let r = test_weight_family(&family, 2520, &gram, dim, &mu_raw);
                let check = if r.bilinear_bound <= 1.0 && r.d_sq < 1.5 {
                    " 🎯"
                } else if r.bilinear_bound <= 1.0 {
                    " ✅"
                } else {
                    " ❌"
                };
                // Only print interesting ones (bound ≤ 2.0)
                if r.bilinear_bound <= 2.0 {
                    println!("  {:<12} {:>8.4} {:>10.4} {:>10.4} {:>10.2} {}",
                        r.name, r.vtgv, r.d_sq, r.bilinear_bound, r.l1, check);
                }
            }
        }
    }
    
    // ═══ SECTION 4: Best candidates scaling ═══
    println!();
    println!("═══ SECTION 4: Best Candidate Scaling ═══");
    println!();
    
    let best_candidates = vec![
        WeightFamily::new("Mertens(1,1)", 1.0, 1.0),
        WeightFamily::new("(1.5,1)",      1.5, 1.0),
        WeightFamily::new("Heavy(2,1)",   2.0, 1.0),
        WeightFamily::new("(1,2)",        1.0, 2.0),
        WeightFamily::new("(1.5,2)",      1.5, 2.0),
    ];
    
    println!("  {:>6} │", "N");
    for fam in &best_candidates {
        print!(" {:>20} │", fam.name);
    }
    println!();
    println!("  {:>6} │", "");
    for _ in &best_candidates {
        print!(" {:>8} {:>8} {:>2} │", "bound", "vtGv", "");
    }
    println!();
    println!("  {}", "-".repeat(6 + best_candidates.len() * 23));
    
    for &n in &hc_ns {
        let path = cache_dir.join(format!("gram_N{}.h5", n));
        if !path.exists() { continue; }
        
        let reader = match HpdfReader::open(&path) {
            Ok(r) => r,
            Err(_) => continue,
        };
        let dim = reader.dim();
        let mu_raw = reader.read_mobius().unwrap_or_else(|_| sieve_mobius(n));
        let gram = match reader.read_gram_full() {
            Ok(g) => g,
            Err(_) => continue,
        };
        
        print!("  {:>6} │", n);
        for fam in &best_candidates {
            let r = test_weight_family(fam, n, &gram, dim, &mu_raw);
            let check = if r.bilinear_bound <= 1.0 { "✅" } else { "❌" };
            print!(" {:>8.4} {:>8.4} {} │", r.bilinear_bound, r.vtgv, check);
        }
        println!();
    }
    
    println!();
    println!("═══════════════════════════════════════════════════════════════════════════");
    println!("  KEY: bound = max|inner_k| × Σ|v_k|");
    println!("  ✅ = bound ≤ 1 (bilinear_row_bound closes)");
    println!("  🎯 = bound ≤ 1 AND d² < 1.5 (both bound AND approximation quality)");
    println!("═══════════════════════════════════════════════════════════════════════════");
}
