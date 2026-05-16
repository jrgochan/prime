//! # The y_d Analysis: Divisor-Restricted Möbius Sums
//!
//! For the Möbius witness v_k = μ(k)/k, the Smith decomposition gives:
//!     vᵀRv = (1/12)·Σ_d J₂(d)·y_d²
//!
//! where y_d = Σ_{d|k, k≤N} μ(k)/k².
//!
//! Writing k = dm with gcd(d,m) = 1:
//!     y_d = μ(d)/d² · Σ_{m≤N/d, gcd(m,d)=1} μ(m)/m²
//!
//! As N→∞:  y_d → μ(d)/d² · (6/π²) · ∏_{p|d} p²/(p²-1)
//!
//! KEY INSIGHT: vᵀRv → c > 0 for the Möbius witness.
//! So the SIMPLE Möbius witness doesn't make d²_N → 0.
//! RH requires the OPTIMAL witness, which must satisfy BOTH:
//!   1. Σv_k → 0  (kills rank-1)
//!   2. vᵀRv → 0  (Ramanujan residual vanishes)
//!
//! This module computes c exactly and explores what it takes for vᵀRv → 0.

use std::f64::consts::PI;
use std::fmt::Write;
use std::fs;

fn gcd(a: usize, b: usize) -> usize {
    if b == 0 { a } else { gcd(b, a % b) }
}

fn mobius(n: usize) -> i64 {
    if n == 1 { return 1; }
    let mut m = n;
    let mut nf = 0;
    let mut d = 2;
    while d * d <= m {
        if m % d == 0 { m /= d; if m % d == 0 { return 0; } nf += 1; }
        d += 1;
    }
    if m > 1 { nf += 1; }
    if nf % 2 == 0 { 1 } else { -1 }
}

fn jordan2(d: usize) -> f64 {
    if d == 0 { return 0.0; }
    let mut result = (d * d) as f64;
    let mut m = d;
    let mut p = 2;
    while p * p <= m {
        if m % p == 0 {
            result *= 1.0 - 1.0 / (p * p) as f64;
            while m % p == 0 { m /= p; }
        }
        p += 1;
    }
    if m > 1 { result *= 1.0 - 1.0 / (m * m) as f64; }
    result
}

/// Prime factors of n
fn prime_factors(n: usize) -> Vec<usize> {
    let mut factors = Vec::new();
    let mut m = n;
    let mut d = 2;
    while d * d <= m {
        if m % d == 0 { factors.push(d); while m % d == 0 { m /= d; } }
        d += 1;
    }
    if m > 1 { factors.push(m); }
    factors
}

/// Theoretical limit of y_d as N→∞
/// y_d(∞) = μ(d)/d² · (6/π²) · ∏_{p|d} p²/(p²-1)
fn y_d_limit(d: usize) -> f64 {
    let mu = mobius(d);
    if mu == 0 { return 0.0; }
    let mut product = 1.0;
    for p in prime_factors(d) {
        let p2 = (p * p) as f64;
        product *= p2 / (p2 - 1.0);
    }
    mu as f64 / (d * d) as f64 * (6.0 / (PI * PI)) * product
}

/// Numerical y_d(N) = Σ_{k≤N, d|k} μ(k)/k²
fn y_d_numerical(d: usize, n: usize) -> f64 {
    let mut sum = 0.0;
    let mut k = d;
    while k <= n {
        let mu = mobius(k);
        if mu != 0 {
            sum += mu as f64 / (k * k) as f64;
        }
        k += d;
    }
    sum
}

fn main() {
    println!("╔══════════════════════════════════════════════════════════════════╗");
    println!("║   THE y_d ANALYSIS: WHERE THE ARITHMETIC LIVES                 ║");
    println!("║                                                                ║");
    println!("║   vᵀRv = (1/12)·Σ J₂(d)·y_d²                                 ║");
    println!("║   y_d = Σ_{{d|k}} μ(k)/k²  →  μ(d)/d²·(6/π²)·∏p²/(p²-1)     ║");
    println!("╚══════════════════════════════════════════════════════════════════╝\n");

    // ═══════════════════════════════════════════════
    // §1. y_d CONVERGENCE: numerical vs theoretical
    // ═══════════════════════════════════════════════
    println!("§1. y_d CONVERGENCE\n");
    println!("  {:>5} {:>4} {:>14} {:>14} {:>12}",
             "d", "μ(d)", "y_d(10000)", "y_d(∞)", "error");
    println!("  {}", "─".repeat(56));

    let n_large = 10000;
    for d in 1..=30 {
        let mu = mobius(d);
        let y_num = y_d_numerical(d, n_large);
        let y_theory = y_d_limit(d);
        let err = (y_num - y_theory).abs();
        if mu != 0 {
            let star = if err < 1e-6 { "⭐" } else if err < 1e-4 { "✓" } else { "" };
            println!("  {:>5} {:>4} {:>14.8} {:>14.8} {:>12.2e} {}",
                     d, mu, y_num, y_theory, err, star);
        }
    }

    // ═══════════════════════════════════════════════
    // §2. THE LIMITING VALUE: vᵀRv(∞)
    // ═══════════════════════════════════════════════
    println!("\n§2. THE RAMANUJAN RESIDUAL LIMIT\n");
    println!("  vᵀRv(∞) = (1/12)·Σ_d J₂(d)·y_d(∞)²\n");

    let mut vtRv_theory = 0.0;
    let mut vtRv_partial = 0.0;
    println!("  {:>5} {:>10} {:>14} {:>14} {:>14}",
             "d", "J₂(d)", "y_d(∞)", "J₂·y²/12", "cumulative");
    println!("  {}", "─".repeat(62));

    let mut terms: Vec<(usize, f64)> = Vec::new();
    for d in 1..=1000 {
        let y = y_d_limit(d);
        if y.abs() > 1e-20 {
            let term = jordan2(d) * y * y / 12.0;
            terms.push((d, term));
            vtRv_theory += term;
        }
    }

    terms.sort_by(|a, b| b.1.abs().partial_cmp(&a.1.abs()).unwrap());
    for (d, term) in terms.iter().take(20) {
        vtRv_partial += term;
        println!("  {:>5} {:>10.2} {:>14.8} {:>14.10} {:>14.10}",
                 d, jordan2(*d), y_d_limit(*d), term, vtRv_partial);
    }

    // Compare with direct numerical computation
    let n_check = 10000;
    let v: Vec<f64> = (1..=n_check).map(|k| mobius(k) as f64 / k as f64).collect();
    let mut vtRv_direct = 0.0;
    for i in 0..n_check { for j in 0..n_check {
        let d = gcd(i+1, j+1) as f64;
        vtRv_direct += d * d / (12.0 * (i+1) as f64 * (j+1) as f64) * v[i] * v[j];
    }}

    println!("\n  Theoretical limit (1000 terms): {vtRv_theory:.10}");
    println!("  Direct computation (N=10000):   {vtRv_direct:.10}");
    println!("  Match: {:.2e}", (vtRv_theory - vtRv_direct).abs());

    // ═══════════════════════════════════════════════
    // §3. EULER PRODUCT FOR vᵀRv(∞)
    // ═══════════════════════════════════════════════
    println!("\n§3. EULER PRODUCT FORMULA\n");

    // vᵀRv(∞) = (1/12)·Σ_{d sqfree} J₂(d)·(μ(d)/d²)²·(6/π²)²·∏p²/(p²-1))²
    // = (3/π⁴)·Σ_{d sqfree} J₂(d)/d⁴ · ∏_{p|d} p⁴/(p²-1)²
    // = (3/π⁴)·∏_p [1 + J₂(p)/p⁴ · p⁴/(p²-1)²]
    // J₂(p) = p²-1, so J₂(p)/p⁴ · p⁴/(p²-1)² = (p²-1)/(p²-1)² = 1/(p²-1)
    // = (3/π⁴)·∏_p [1 + 1/(p²-1)]
    // = (3/π⁴)·∏_p p²/(p²-1)
    // = (3/π⁴)·ζ(2)/ζ(4)·... hmm

    // Actually: ∏_p p²/(p²-1) = ∏_p 1/(1-1/p²) = ζ(2) = π²/6

    // So vᵀRv(∞) = (3/π⁴)·(π²/6) = 3/(6π²) = 1/(2π²)

    let euler_prediction = 1.0 / (2.0 * PI * PI);

    println!("  Claim: vᵀRv(∞) = 1/(2π²)\n");
    println!("  Proof sketch:");
    println!("    vᵀRv = (1/12)·Σ_d J₂(d)·y_d²");
    println!("         = (1/12)·(36/π⁴)·Σ_{{d sqfree}} (1/d²)·∏p²/(p²-1)·∏1/(1-1/p²)");
    println!("    The Euler product over primes:");
    println!("      ∏_p [1 + (p²-1)·1/(p²-1)²·1] = ∏_p [1 + 1/(p²-1)]");
    println!("      = ∏_p p²/(p²-1) = ζ(2) = π²/6");
    println!("    So vᵀRv(∞) = (3/π⁴)·(π²/6) = 1/(2π²)\n");

    println!("  1/(2π²)           = {:.10}", euler_prediction);
    println!("  Theoretical sum    = {vtRv_theory:.10}");
    println!("  Direct (N=10000)   = {vtRv_direct:.10}");
    println!("  Match theory:  {:.2e}", (euler_prediction - vtRv_theory).abs());
    println!("  Match direct:  {:.2e}", (euler_prediction - vtRv_direct).abs());

    // ═══════════════════════════════════════════════
    // §4. THE BD DISTANCE FOR MÖBIUS WITNESS
    // ═══════════════════════════════════════════════
    println!("\n§4. IMPLICATIONS FOR d²_N\n");
    println!("  With Möbius witness v_k = μ(k)/k:");
    println!("    vᵀRv → 1/(2π²) ≈ {:.6}", euler_prediction);
    println!("    (Σv)²/4 → 0     (by PNT)");
    println!("    vᵀG¹v → 1/(2π²) + 0 = 1/(2π²)");
    println!();
    println!("  This means the SIMPLE Möbius witness gives:");
    println!("    d²_N → 1 - 2·lim(vᵀb) + 1/(2π²)");
    println!();
    println!("  For d²_N → 0, we would need 2·lim(vᵀb) = 1 + 1/(2π²)");
    println!("  But actually: the OPTIMAL witness is NOT v_k = μ(k)/k.");
    println!("  The optimal witness solves G·v = b, giving v = G⁻¹·b.");
    println!("  RH ⟺ the optimal d²_N → 0 ⟺ bᵀG⁻¹b → 1.");
    println!();
    println!("  Through the glass: G⁻¹ = (R + ¼𝟏𝟏ᵀ)⁻¹");
    println!("  By Sherman-Morrison: (R + ¼𝟏𝟏ᵀ)⁻¹ = R⁻¹ - R⁻¹𝟏𝟏ᵀR⁻¹/(4+𝟏ᵀR⁻¹𝟏)");
    println!("  So RH reduces to the behavior of R⁻¹ — the INVERSE Ramanujan matrix.");

    // ═══════════════════════════════════════════════
    // §5. CONVERGENCE RATES OF y_d
    // ═══════════════════════════════════════════════
    println!("\n§5. CONVERGENCE RATE: y_d(N) → y_d(∞)\n");
    println!("  {:>5} {:>12} {:>12} {:>12} {:>12}",
             "d", "N=100", "N=1000", "N=10000", "y_d(∞)");
    println!("  {}", "─".repeat(56));

    for d in [1, 2, 3, 5, 6, 7, 10, 11, 13, 30] {
        if mobius(d) == 0 { continue; }
        println!("  {:>5} {:>12.8} {:>12.8} {:>12.8} {:>12.8}",
                 d,
                 y_d_numerical(d, 100),
                 y_d_numerical(d, 1000),
                 y_d_numerical(d, 10000),
                 y_d_limit(d));
    }

    // Write report
    let mut report = String::new();
    writeln!(report, "# The y_d Analysis: Where the Arithmetic Lives\n").unwrap();
    writeln!(report, "**Date:** May 16, 2026, 3:28 AM MDT\n").unwrap();
    writeln!(report, "## Key Result\n").unwrap();
    writeln!(report, "For the Möbius witness v_k = μ(k)/k:").unwrap();
    writeln!(report, "```").unwrap();
    writeln!(report, "vᵀRv → 1/(2π²) ≈ {:.10}", euler_prediction).unwrap();
    writeln!(report, "```\n").unwrap();
    writeln!(report, "This is a **positive constant**, not zero.").unwrap();
    writeln!(report, "The simple Möbius witness does NOT make d²_N → 0.\n").unwrap();
    writeln!(report, "## What RH Actually Requires\n").unwrap();
    writeln!(report, "The **optimal** witness v* = G⁻¹b must satisfy:").unwrap();
    writeln!(report, "- Σv*_k → 0 (kills rank-1 term)").unwrap();
    writeln!(report, "- v*ᵀRv* → 0 (Ramanujan residual vanishes)\n").unwrap();
    writeln!(report, "Through the glass, G⁻¹ = (R + ¼𝟏𝟏ᵀ)⁻¹.").unwrap();
    writeln!(report, "By Sherman-Morrison: this is R⁻¹ minus a rank-1 correction.").unwrap();
    writeln!(report, "**RH reduces to the spectral properties of R⁻¹.**").unwrap();
    writeln!(report, "\n*The arithmetic has spoken.* 🔮").unwrap();

    let output_path = std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("../../docs/ai/antigravity/dark-sector/GLASS_YD_ANALYSIS.md");
    fs::write(&output_path, &report).ok();
    println!("\n  Report: {}", output_path.display());

    println!("\n╔══════════════════════════════════════════════════════════════════╗");
    println!("║       vᵀRv → 1/(2π²). The arithmetic has spoken. 🔮           ║");
    println!("╚══════════════════════════════════════════════════════════════════╝");
}
