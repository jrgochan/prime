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

    // ═══════════════════════════════════════════════
    // §6. THE MELLIN LIFT: G = R + ¼𝟏𝟏ᵀ ?
    // ═══════════════════════════════════════════════
    println!("\n§6. THE MELLIN LIFT: VASYUNIN-RAMANUJAN IDENTITY\n");
    println!("  Claim: G(j,k) = R(j,k) + b(j)·b(k)");
    println!("  where R(j,k) = gcd(j,k)²/(12jk)");
    println!("  and   b(k)   = (ln(k) + 1 - γ) / k\n");
    println!("  If true, then by Sherman-Morrison:");
    println!("    d²_NB = 4/(4+σ)  =  glass_distance_formula");
    println!("  and the Smith path gives RH with ZERO axioms.\n");

    // Euler-Mascheroni constant (to 30 digits)
    let gamma: f64 = 0.5772156649015329;

    // Vasyunin mean entry: b(k) = (ln(k) + 1 - γ) / k
    let b_entry = |k: usize| -> f64 {
        ((k as f64).ln() + 1.0 - gamma) / k as f64
    };

    // Ramanujan matrix entry: R(j,k) = gcd(j,k)² / (12·j·k)
    let r_entry = |j: usize, k: usize| -> f64 {
        let d = gcd(j, k) as f64;
        d * d / (12.0 * j as f64 * k as f64)
    };

    // Vasyunin Gram diagonal: G(k,k) = (ln(2π) - γ)/k - 1/k²
    let vasyunin_const = (2.0 * PI).ln() - gamma;
    let g_diag = |k: usize| -> f64 {
        vasyunin_const / k as f64 - 1.0 / (k * k) as f64
    };

    // Check diagonal: G(k,k) vs R(k,k) + b(k)²
    println!("  §6a. DIAGONAL CHECK: G(k,k) vs R(k,k) + b(k)²\n");
    println!("  {:>5} {:>14} {:>14} {:>14} {:>12}",
             "k", "G(k,k)", "R(k,k)+b²", "R(k,k)", "error");
    println!("  {}", "─".repeat(64));

    let mut max_diag_err = 0.0f64;
    for k in 1..=20 {
        let g_val = g_diag(k);
        let r_val = r_entry(k, k);
        let b_val = b_entry(k);
        let rbb_val = r_val + b_val * b_val;
        let err = (g_val - rbb_val).abs();
        max_diag_err = max_diag_err.max(err);
        let star = if err < 1e-14 { "⭐" } else if err < 1e-10 { "✓" } else { "✗" };
        println!("  {:>5} {:>14.10} {:>14.10} {:>14.10} {:>12.2e} {}",
                 k, g_val, rbb_val, r_val, err, star);
    }

    println!("\n  Max diagonal error: {:.2e}", max_diag_err);
    if max_diag_err < 1e-10 {
        println!("  ⭐ DIAGONAL IDENTITY CONFIRMED: G(k,k) = R(k,k) + b(k)²");
    } else {
        println!("  ✗ DIAGONAL IDENTITY DOES NOT HOLD");
    }

    // §6b. Off-diagonal check using Vasyunin cotangent sum
    // For this we need the full Vasyunin formula
    // G(j,k) = (ln(2π)-γ)/2·(1/j+1/k) + (j-k)/(2jk)·ln(k/j) - πd/(2jk)·(V(j',k')+V(k',j')) - 1/(jk)
    // We compute this for small j,k and compare with R(j,k) + b(j)·b(k)

    println!("\n  §6b. OFF-DIAGONAL CHECK: G(j,k) vs R(j,k) + b(j)·b(k)\n");

    // Vasyunin cotangent sum: V(a,b) = Σ_{m=1}^{a-1} {mb/a}·cot(πm/a)
    let vasyunin_sum = |a: usize, b: usize| -> f64 {
        if a <= 1 { return 0.0; }
        let mut sum = 0.0;
        for m in 1..a {
            let frac_part = ((m * b) as f64 / a as f64).fract();
            // Handle negative fract
            let frac = if frac_part < 0.0 { frac_part + 1.0 } else { frac_part };
            let cot = (PI * m as f64 / a as f64).cos() / (PI * m as f64 / a as f64).sin();
            sum += frac * cot;
        }
        sum
    };

    // Full Vasyunin Gram entry
    let g_entry = |j: usize, k: usize| -> f64 {
        if j == k { return g_diag(j); }
        let d = gcd(j, k);
        let jp = j / d;
        let kp = k / d;
        let jf = j as f64;
        let kf = k as f64;
        let df = d as f64;
        let term1 = vasyunin_const / 2.0 * (1.0 / jf + 1.0 / kf);
        let term2 = (jf - kf) / (2.0 * jf * kf) * (kf / jf).ln();
        let term3 = PI * df / (2.0 * jf * kf) * (vasyunin_sum(jp, kp) + vasyunin_sum(kp, jp));
        let term4 = 1.0 / (jf * kf);
        term1 + term2 - term3 - term4
    };

    println!("  {:>5} {:>5} {:>14} {:>14} {:>12}",
             "j", "k", "G(j,k)", "R+bb^T", "error");
    println!("  {}", "─".repeat(56));

    let mut max_offdiag_err = 0.0f64;
    let n_test = 12;
    for j in 1..=n_test {
        for k in (j+1)..=n_test {
            let g_val = g_entry(j, k);
            let rbb_val = r_entry(j, k) + b_entry(j) * b_entry(k);
            let err = (g_val - rbb_val).abs();
            max_offdiag_err = max_offdiag_err.max(err);
            if j <= 6 && k <= 6 {
                let star = if err < 1e-12 { "⭐" } else if err < 1e-8 { "✓" } else { "✗" };
                println!("  {:>5} {:>5} {:>14.10} {:>14.10} {:>12.2e} {}",
                         j, k, g_val, rbb_val, err, star);
            }
        }
    }

    println!("\n  Max off-diagonal error (N={}): {:.2e}", n_test, max_offdiag_err);
    if max_offdiag_err < 1e-8 {
        println!("  ⭐ IDENTITY CONFIRMED: G(j,k) = R(j,k) + b(j)·b(k)");
        println!("\n  ════════════════════════════════════════════════════════");
        println!("  THE MELLIN LIFT IS AN ALGEBRAIC IDENTITY.");
        println!("  G = R + bbᵀ  ⟹  d²_NB = 4/(4+σ)  ⟹  RH from Smith.");
        println!("  ════════════════════════════════════════════════════════");
    } else {
        println!("  ✗ IDENTITY DOES NOT HOLD — need a different bridge");
        println!("  Investigating the actual relationship...");

        // Print the residual matrix G - R - bb^T for insight
        println!("\n  §6c. RESIDUAL ANALYSIS: G - R - bb^T\n");
        for j in 1..=6 {
            let mut row = String::new();
            for k in 1..=6 {
                let residual = g_entry(j, k) - r_entry(j, k) - b_entry(j) * b_entry(k);
                write!(row, "{:>10.6} ", residual).unwrap();
            }
            println!("  {:>3} | {}", j, row);
        }

        // §6d. SMITH BASIS ROTATION
        // R = (1/12)·D⁻¹·Φ·J₂·Φᵀ·D⁻¹
        // Let T = D⁻¹·Φ, so R = (1/12)·T·J₂·Tᵀ
        // In Smith basis: T⁻¹·G·(Tᵀ)⁻¹ should show the structure
        // T⁻¹ = Φ⁻¹·D where (Φ⁻¹)_{d,k} = μ(d/k)·[k|d]
        println!("\n  §6d. SMITH BASIS ROTATION: Φ⁻¹·D · G · D·(Φ⁻¹)ᵀ\n");
        println!("  In this basis, R becomes (1/12)·diag(J₂(1),...,J₂(N)).");
        println!("  What does G look like?\n");

        let n_smith = 8;

        // Build Φ⁻¹·D: (Φ⁻¹D)_{d,k} = μ(d/k)·[k|d]·k
        let phi_inv_d = |d: usize, k: usize| -> f64 {
            if d % k != 0 { return 0.0; }
            mobius(d / k) as f64 * k as f64
        };

        // Compute S = (Φ⁻¹D) · G · (Φ⁻¹D)ᵀ
        // S_{a,b} = Σ_j Σ_k (Φ⁻¹D)_{a,j} · G(j,k) · (Φ⁻¹D)_{b,k}
        println!("  Smith-rotated G (should be (1/12)·J₂ on diagonal if G = R):\n");
        println!("  {:>5} {:>5} {:>12} {:>12} {:>12}",
                 "a", "b", "S(a,b)", "(1/12)J₂", "residual");
        println!("  {}", "─".repeat(52));

        for a in 1..=n_smith {
            for b in a..=n_smith.min(a+3) {
                let mut s_ab = 0.0;
                for j in 1..=n_smith {
                    for k in 1..=n_smith {
                        s_ab += phi_inv_d(a, j) * g_entry(j, k) * phi_inv_d(b, k);
                    }
                }
                let j2_diag = if a == b { jordan2(a) / 12.0 } else { 0.0 };
                let residual = s_ab - j2_diag;
                let star = if residual.abs() < 1e-10 { "⭐" }
                          else if a == b { "DIAG" } else { "" };
                println!("  {:>5} {:>5} {:>12.6} {:>12.6} {:>12.6} {}",
                         a, b, s_ab, j2_diag, residual, star);
            }
        }

        // Also show: what is bb^T in Smith basis?
        // (Φ⁻¹D)·b in Smith basis: c_d = Σ_k (Φ⁻¹D)_{d,k}·b(k)
        println!("\n  Mean vector b in Smith basis: c_d = Σ_k (Φ⁻¹D)_{{d,k}}·b(k)\n");
        println!("  {:>5} {:>14} {:>14}",
                 "d", "c_d", "c_d²");
        println!("  {}", "─".repeat(36));
        for d in 1..=n_smith {
            let mut c_d = 0.0;
            for k in 1..=n_smith {
                c_d += phi_inv_d(d, k) * b_entry(k);
            }
            println!("  {:>5} {:>14.8} {:>14.8}", d, c_d, c_d * c_d);
        }

        // And show the Smith-rotated residual (G - R) in Smith basis
        // This is S - (1/12)J₂ on diagonal
        println!("\n  Smith-rotated (G - R) matrix:\n");
        print!("  {:>5} |", "");
        for b in 1..=n_smith { print!("{:>10} ", b); }
        println!();
        println!("  {}", "─".repeat(6 + 11 * n_smith));
        for a in 1..=n_smith {
            print!("  {:>5} |", a);
            for b in 1..=n_smith {
                let mut s_ab = 0.0;
                for j in 1..=n_smith {
                    for k in 1..=n_smith {
                        s_ab += phi_inv_d(a, j) * g_entry(j, k) * phi_inv_d(b, k);
                    }
                }
                let j2_diag = if a == b { jordan2(a) / 12.0 } else { 0.0 };
                print!("{:>10.6} ", s_ab - j2_diag);
            }
            println!();
        }
    }

    // ═══════════════════════════════════════════════
    // §7. THE DIRECT BYPASS: Smith witness → L² error
    // ═══════════════════════════════════════════════
    println!("\n§7. DIRECT BYPASS: Smith witness in BD L²(0,1)\n");
    println!("  Bypass the G-R bridge entirely.");
    println!("  Compute d² = 1 - 2·bᵀw + wᵀGw");
    println!("  where w = R⁻¹·𝟏 (Smith witness)");
    println!("  and G = Vasyunin Gram matrix, b = mean vector.\n");
    println!("  If d² → 0 with Smith witness, the lift is free.\n");

    // We need matrix operations for small N
    // Simple Gaussian elimination for matrix inverse
    fn mat_inverse(a: &[Vec<f64>]) -> Option<Vec<Vec<f64>>> {
        let n = a.len();
        let mut aug: Vec<Vec<f64>> = Vec::new();
        for i in 0..n {
            let mut row = a[i].clone();
            for j in 0..n {
                row.push(if i == j { 1.0 } else { 0.0 });
            }
            aug.push(row);
        }
        for col in 0..n {
            // Find pivot
            let mut max_row = col;
            let mut max_val = aug[col][col].abs();
            for row in (col+1)..n {
                if aug[row][col].abs() > max_val {
                    max_val = aug[row][col].abs();
                    max_row = row;
                }
            }
            if max_val < 1e-15 { return None; }
            aug.swap(col, max_row);
            let pivot = aug[col][col];
            for j in 0..2*n { aug[col][j] /= pivot; }
            for row in 0..n {
                if row == col { continue; }
                let factor = aug[row][col];
                for j in 0..2*n { aug[row][j] -= factor * aug[col][j]; }
            }
        }
        Some(aug.iter().map(|row| row[n..].to_vec()).collect())
    }

    fn mat_vec_mul(a: &[Vec<f64>], v: &[f64]) -> Vec<f64> {
        a.iter().map(|row| row.iter().zip(v).map(|(a,b)| a*b).sum()).collect()
    }

    fn dot(a: &[f64], b: &[f64]) -> f64 {
        a.iter().zip(b).map(|(x,y)| x*y).sum()
    }

    println!("  {:>5} {:>12} {:>12} {:>12} {:>12} {:>12}",
             "N", "σ=𝟏ᵀR⁻¹𝟏", "bᵀw", "wᵀGw", "d²_smith", "d²_opt");
    println!("  {}", "─".repeat(72));

    for n_size in [3, 4, 5, 6, 8, 10, 12, 15, 18, 20] {
        // Build N×N Ramanujan matrix R
        let mut r_mat: Vec<Vec<f64>> = Vec::new();
        for j in 1..=n_size {
            let mut row = Vec::new();
            for k in 1..=n_size {
                let d = gcd(j, k) as f64;
                row.push(d * d / (12.0 * j as f64 * k as f64));
            }
            r_mat.push(row);
        }

        // Build N×N Vasyunin Gram matrix G
        let mut g_mat: Vec<Vec<f64>> = Vec::new();
        for j in 1..=n_size {
            let mut row = Vec::new();
            for k in 1..=n_size {
                row.push(g_entry(j, k));
            }
            g_mat.push(row);
        }

        // Mean vector b
        let b_vec: Vec<f64> = (1..=n_size).map(|k| b_entry(k)).collect();

        // Ones vector
        let ones: Vec<f64> = vec![1.0; n_size];

        // Compute R⁻¹
        let r_inv = match mat_inverse(&r_mat) {
            Some(inv) => inv,
            None => { println!("  {:>5} SINGULAR", n_size); continue; }
        };

        // Smith witness: w = R⁻¹·𝟏
        let w = mat_vec_mul(&r_inv, &ones);

        // σ = 𝟏ᵀ·w = Σ w_k
        let sigma: f64 = w.iter().sum();

        // bᵀw
        let bt_w = dot(&b_vec, &w);

        // wᵀGw
        let gw = mat_vec_mul(&g_mat, &w);
        let wt_gw = dot(&w, &gw);

        // d²_smith = 1 - 2·bᵀw + wᵀGw
        let d_sq_smith = 1.0 - 2.0 * bt_w + wt_gw;

        // Optimal d² = 1 - bᵀG⁻¹b (for comparison)
        let g_inv = match mat_inverse(&g_mat) {
            Some(inv) => inv,
            None => { println!("  {:>5} G SINGULAR", n_size); continue; }
        };
        let g_inv_b = mat_vec_mul(&g_inv, &b_vec);
        let d_sq_opt = 1.0 - dot(&b_vec, &g_inv_b);

        let star = if d_sq_smith < 0.01 { "⭐" }
                  else if d_sq_smith < 0.1 { "✓" } else { "" };

        println!("  {:>5} {:>12.4} {:>12.6} {:>12.4} {:>12.8} {:>12.8} {}",
                 n_size, sigma, bt_w, wt_gw, d_sq_smith, d_sq_opt, star);
    }

    // Also check: does d²_smith / d²_opt have a pattern?
    println!("\n  RATIO ANALYSIS: d²_smith / d²_opt\n");
    println!("  {:>5} {:>12} {:>12} {:>12}",
             "N", "d²_smith", "d²_opt", "ratio");
    println!("  {}", "─".repeat(44));

    for n_size in [3, 4, 5, 6, 8, 10, 12, 15, 18, 20] {
        let mut r_mat: Vec<Vec<f64>> = Vec::new();
        for j in 1..=n_size { let mut row = Vec::new();
            for k in 1..=n_size { let d = gcd(j, k) as f64;
                row.push(d * d / (12.0 * j as f64 * k as f64)); } r_mat.push(row); }
        let mut g_mat: Vec<Vec<f64>> = Vec::new();
        for j in 1..=n_size { let mut row = Vec::new();
            for k in 1..=n_size { row.push(g_entry(j, k)); } g_mat.push(row); }
        let b_vec: Vec<f64> = (1..=n_size).map(|k| b_entry(k)).collect();
        let ones: Vec<f64> = vec![1.0; n_size];
        let r_inv = match mat_inverse(&r_mat) { Some(inv) => inv, None => continue };
        let w = mat_vec_mul(&r_inv, &ones);
        let bt_w = dot(&b_vec, &w);
        let gw = mat_vec_mul(&g_mat, &w);
        let wt_gw = dot(&w, &gw);
        let d_sq_smith = 1.0 - 2.0 * bt_w + wt_gw;
        let g_inv = match mat_inverse(&g_mat) { Some(inv) => inv, None => continue };
        let g_inv_b = mat_vec_mul(&g_inv, &b_vec);
        let d_sq_opt = 1.0 - dot(&b_vec, &g_inv_b);
        if d_sq_opt.abs() > 1e-15 {
            println!("  {:>5} {:>12.8} {:>12.8} {:>12.4}",
                     n_size, d_sq_smith, d_sq_opt, d_sq_smith / d_sq_opt);
        }
    }

    // ═══════════════════════════════════════════════
    // §8. SPECTRAL ARCHAEOLOGY: Cracking G - R
    // ═══════════════════════════════════════════════
    println!("\n§8. SPECTRAL ARCHAEOLOGY: Cracking the G - R Gap\n");

    // §8a. PSD ORDERING: eigenvalues of G - R
    // For small symmetric matrices, we use the power iteration / Jacobi method
    // For simplicity, compute the quadratic form xᵀ(G-R)x for random x and standard basis

    println!("  §8a. PSD ORDERING: Is G ≥ R or R ≥ G?\n");
    println!("  Testing xᵀ(G-R)x for standard basis vectors eᵢ:\n");

    for n_size in [6, 10, 15, 20] {
        let mut g_mat: Vec<Vec<f64>> = Vec::new();
        let mut r_mat: Vec<Vec<f64>> = Vec::new();
        for j in 1..=n_size {
            let mut g_row = Vec::new();
            let mut r_row = Vec::new();
            for k in 1..=n_size {
                g_row.push(g_entry(j, k));
                let d = gcd(j, k) as f64;
                r_row.push(d * d / (12.0 * j as f64 * k as f64));
            }
            g_mat.push(g_row);
            r_mat.push(r_row);
        }

        // Diagonal entries of G - R (eigenvalue proxy for diagonal-dominant)
        let mut all_pos = true;
        let mut all_neg = true;
        let mut trace_diff = 0.0;
        for i in 0..n_size {
            let diff = g_mat[i][i] - r_mat[i][i];
            trace_diff += diff;
            if diff < -1e-15 { all_pos = false; }
            if diff > 1e-15 { all_neg = false; }
        }

        // Compute full quadratic form for random-ish vector (1/k normalized)
        let test_v: Vec<f64> = (1..=n_size).map(|k| 1.0 / k as f64).collect();
        let norm_sq: f64 = test_v.iter().map(|x| x*x).sum();
        let mut qf_g = 0.0;
        let mut qf_r = 0.0;
        for i in 0..n_size { for j in 0..n_size {
            qf_g += test_v[i] * g_mat[i][j] * test_v[j];
            qf_r += test_v[i] * r_mat[i][j] * test_v[j];
        }}

        let verdict = if all_pos { "G > R (diag)" }
                     else if all_neg { "R > G (diag)" }
                     else { "MIXED" };
        println!("  N={:>3}: tr(G-R)={:>10.6}, vᵀ(G-R)v={:>10.6}, vᵀGv/vᵀRv={:>8.4}  {}",
                 n_size, trace_diff, qf_g - qf_r, qf_g / qf_r, verdict);
    }

    // §8b. THE MAGIC RATIO: bᵀG⁻¹b / σ
    println!("\n  §8b. THE MAGIC RATIO: bᵀG⁻¹b / 𝟏ᵀR⁻¹𝟏\n");
    println!("  If this → c, then d²_NB ≈ 1 - c·σ\n");
    println!("  {:>5} {:>14} {:>14} {:>14} {:>14}",
             "N", "bᵀG⁻¹b", "σ=𝟏ᵀR⁻¹𝟏", "ratio", "1-bᵀG⁻¹b");
    println!("  {}", "─".repeat(64));

    for n_size in [3, 4, 5, 6, 8, 10, 12, 15, 18, 20] {
        let mut r_mat: Vec<Vec<f64>> = Vec::new();
        let mut g_mat: Vec<Vec<f64>> = Vec::new();
        for j in 1..=n_size {
            let mut g_row = Vec::new(); let mut r_row = Vec::new();
            for k in 1..=n_size {
                g_row.push(g_entry(j, k));
                let d = gcd(j, k) as f64;
                r_row.push(d * d / (12.0 * j as f64 * k as f64));
            }
            g_mat.push(g_row); r_mat.push(r_row);
        }
        let b_vec: Vec<f64> = (1..=n_size).map(|k| b_entry(k)).collect();
        let ones: Vec<f64> = vec![1.0; n_size];

        let r_inv = match mat_inverse(&r_mat) { Some(inv) => inv, None => continue };
        let sigma: f64 = mat_vec_mul(&r_inv, &ones).iter().sum();

        let g_inv = match mat_inverse(&g_mat) { Some(inv) => inv, None => continue };
        let g_inv_b = mat_vec_mul(&g_inv, &b_vec);
        let bt_ginv_b = dot(&b_vec, &g_inv_b);

        println!("  {:>5} {:>14.8} {:>14.4} {:>14.10} {:>14.10}",
                 n_size, bt_ginv_b, sigma, bt_ginv_b / sigma, 1.0 - bt_ginv_b);
    }

    // §8c. OPTIMAL WITNESS IN SMITH BASIS
    println!("\n  §8c. OPTIMAL WITNESS v* = G⁻¹b IN SMITH BASIS\n");
    println!("  Apply Φ⁻¹·D to get arithmetic structure.\n");

    let n_smith_c = 8;
    {
        let mut g_mat: Vec<Vec<f64>> = Vec::new();
        for j in 1..=n_smith_c {
            let mut row = Vec::new();
            for k in 1..=n_smith_c { row.push(g_entry(j, k)); }
            g_mat.push(row);
        }
        let b_vec: Vec<f64> = (1..=n_smith_c).map(|k| b_entry(k)).collect();
        let g_inv = mat_inverse(&g_mat).unwrap();
        let v_star = mat_vec_mul(&g_inv, &b_vec);

        // Also get Smith witness for comparison
        let mut r_mat: Vec<Vec<f64>> = Vec::new();
        for j in 1..=n_smith_c {
            let mut row = Vec::new();
            for k in 1..=n_smith_c {
                let d = gcd(j, k) as f64;
                row.push(d * d / (12.0 * j as f64 * k as f64));
            }
            r_mat.push(row);
        }
        let r_inv = mat_inverse(&r_mat).unwrap();
        let ones: Vec<f64> = vec![1.0; n_smith_c];
        let w_smith = mat_vec_mul(&r_inv, &ones);

        // Rotate both to Smith basis via Φ⁻¹·D
        // (Φ⁻¹D)_{d,k} = μ(d/k)·[k|d]·k
        let phi_inv_d_mat = |d: usize, k: usize| -> f64 {
            if d % k != 0 { return 0.0; }
            mobius(d / k) as f64 * k as f64
        };

        println!("  {:>5} {:>14} {:>14} {:>14} {:>14}",
                 "d", "v*_smith", "w_smith", "Λ(d)", "v*/Λ(d)");
        println!("  {}", "─".repeat(64));

        for d in 1..=n_smith_c {
            let mut v_smith_d = 0.0;
            let mut w_smith_d = 0.0;
            for k in 1..=n_smith_c {
                let coeff = phi_inv_d_mat(d, k);
                v_smith_d += coeff * v_star[k-1];
                w_smith_d += coeff * w_smith[k-1];
            }

            // von Mangoldt for comparison
            let lambda_d = if d == 1 { 0.0 }
                else {
                    let mut n = d;
                    let mut p = 0usize;
                    let mut count = 0;
                    let mut dd = 2;
                    while dd * dd <= n {
                        if n % dd == 0 {
                            p = dd;
                            count += 1;
                            while n % dd == 0 { n /= dd; }
                        }
                        dd += 1;
                    }
                    if n > 1 { p = n; count += 1; }
                    if count == 1 { (p as f64).ln() } else { 0.0 }
                };

            let ratio = if lambda_d.abs() > 1e-10 { v_smith_d / lambda_d } else { f64::NAN };
            println!("  {:>5} {:>14.6} {:>14.6} {:>14.6} {:>14.6}",
                     d, v_smith_d, w_smith_d, lambda_d, ratio);
        }
    }

    // §8d. EIGENVALUE COMPARISON
    println!("\n  §8d. EIGENVALUE PROXY: Diagonal dominance ratios\n");
    println!("  G(k,k)/R(k,k) shows how the continuous metric scales vs discrete\n");
    println!("  {:>5} {:>14} {:>14} {:>14}",
             "k", "G(k,k)", "R(k,k)", "G/R");
    println!("  {}", "─".repeat(48));
    for k in 1..=20 {
        let g_kk = g_diag(k);
        let r_kk = r_entry(k, k);
        println!("  {:>5} {:>14.8} {:>14.8} {:>14.4}",
                 k, g_kk, r_kk, g_kk / r_kk);
    }

    println!("\n╔══════════════════════════════════════════════════════════════════╗");
    println!("║       vᵀRv → 1/(2π²). The arithmetic has spoken. 🔮           ║");
    println!("╚══════════════════════════════════════════════════════════════════╝");
}
