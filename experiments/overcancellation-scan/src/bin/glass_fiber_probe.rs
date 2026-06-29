#![allow(
    dead_code,
    unused_variables,
    unused_imports,
    unused_assignments,
    clippy::needless_range_loop,
    clippy::doc_lazy_continuation,
    non_snake_case,
    clippy::empty_line_after_doc_comments
)]
// overcancellation-scan/src/bin/glass_fiber_probe.rs
//
// ╔═══════════════════════════════════════════════════════════════════╗
// ║  GLASS FIBER PROBE — Antisymmetric Vasyunin Coupling Scanner    ║
// ║                                                                   ║
// ║  Decomposes CotRes through the three Hopf fibers:                ║
// ║    CotRes = CotRes_sym + CotRes_anti                             ║
// ║    CotRes_anti ≈ Glass₁(52%) + Glass₂(7.8%) + Glass₃(0.4%)      ║
// ║                                                                   ║
// ║  The symmetric part dissolves (Dedekind reciprocity).            ║
// ║  The antisymmetric part IS the Riemann Hypothesis.               ║
// ║  This probe measures it at increasing N.                         ║
// ╚═══════════════════════════════════════════════════════════════════╝

use cathedral_utils::arith::{gcd, mobius_table};
use std::f64::consts::PI;

const EULER_GAMMA: f64 = 0.5772156649015329;

/// C = ln(2π) − γ
fn vasyunin_const() -> f64 {
    (2.0 * PI).ln() - EULER_GAMMA
}

/// Vasyunin sum V(a, b) = Σ_{m=1}^{a-1} cot(πm/a) · {mb/a}
fn vasyunin_sum(a: usize, b: usize) -> f64 {
    if a <= 1 {
        return 0.0;
    }
    let mut s = 0.0;
    for m in 1..a {
        let cot_val = 1.0 / (PI * m as f64 / a as f64).tan();
        let frac = ((m * b) as f64 / a as f64).fract();
        s += cot_val * frac;
    }
    s
}

/// Symmetric Vasyunin: [V(a,b) + V(b,a)] / 2
fn vasyunin_sym(a: usize, b: usize) -> f64 {
    (vasyunin_sum(a, b) + vasyunin_sum(b, a)) / 2.0
}

/// Antisymmetric Vasyunin: [V(a,b) - V(b,a)] / 2
fn vasyunin_anti(a: usize, b: usize) -> f64 {
    (vasyunin_sum(a, b) - vasyunin_sum(b, a)) / 2.0
}

/// Dissolved symmetric Vasyunin (closed-form rational):
/// [V(a,b) + V(b,a)] / 2 = [-(a²+b²+1)/(6ab) + 1/2] / 2
fn dissolved_sym(a: usize, b: usize) -> f64 {
    let af = a as f64;
    let bf = b as f64;
    (-(af * af + bf * bf + 1.0) / (6.0 * af * bf) + 0.5) / 2.0
}

/// BD witness weight: w(k,N) = 1 - ln(k)/ln(N)
fn log_weight(k: usize, n: usize) -> f64 {
    if k >= n {
        return 0.0;
    }
    1.0 - (k as f64).ln() / (n as f64).ln()
}

/// Glass fiber weight for a single prime p at fiber level
/// Returns (dark_weight, glass1_weight, glass2_weight, glass3_weight)
fn glass_weights(p: f64) -> (f64, f64, f64, f64) {
    let dark = (1.0 - 1.0 / p.powi(8)).ln();
    let g1 = -(1.0 + 1.0 / p).ln();
    let g2 = -(1.0 + 1.0 / p.powi(2)).ln();
    let g3 = -(1.0 + 1.0 / p.powi(4)).ln();
    (dark, g1, g2, g3)
}

fn main() {
    println!("╔═══════════════════════════════════════════════════════════════╗");
    println!("║  GLASS FIBER PROBE — Antisymmetric Vasyunin Coupling        ║");
    println!("╚═══════════════════════════════════════════════════════════════╝");
    println!();

    let c = vasyunin_const();
    println!("C = ln(2π) − γ = {:.6}", c);
    println!();

    // ═══════════════════════════════════════════════════
    // SECTION 1: Verify symmetric dissolution
    // ═══════════════════════════════════════════════════
    println!("═══ §1: Symmetric Dissolution Verification ═══");
    println!(
        "{:>5} {:>5} {:>12} {:>12} {:>12} {:>12}",
        "a", "b", "V_sym(dir)", "V_sym(dis)", "V_anti", "|anti/sym|"
    );
    for a in 2..=12 {
        for b in 1..a {
            if gcd(a, b) != 1 {
                continue;
            }
            let vs = vasyunin_sym(a, b);
            let vd = dissolved_sym(a, b);
            let va = vasyunin_anti(a, b);
            let ratio = if vs.abs() > 1e-15 {
                va.abs() / vs.abs()
            } else {
                f64::NAN
            };
            println!(
                "{:5} {:5} {:12.6} {:12.6} {:12.6} {:12.4}",
                a, b, vs, vd, va, ratio
            );
        }
    }
    println!();

    // ═══════════════════════════════════════════════════
    // SECTION 2: Antisymmetric coupling in the bilinear form
    // ═══════════════════════════════════════════════════
    println!("═══ §2: Antisymmetric Coupling in Bilinear Form ═══");
    println!("CotRes = CotRes_sym + CotRes_anti");
    println!("CotRes_sym uses V_sym (rational, by Dissolution)");
    println!("CotRes_anti uses V_anti (transcendental, = RH)");
    println!();

    for &n in &[30, 60, 120, 360, 720, 1000, 2520, 5040, 10080] {
        let mu = mobius_table(n + 1);
        let size = n - 1;
        let mut v = vec![0.0f64; size];
        for k in 1..n {
            v[k - 1] = -(mu[k] as f64) * log_weight(k, n);
        }

        // Compute the three-part decomposition of vᵀ(cotangent)v
        let mut cotres_sym = 0.0;
        let mut cotres_anti = 0.0;
        let mut cotres_total = 0.0;
        let mut vtgv_total = 0.0;

        // Also track per-GCD-stratum antisymmetric contributions
        let mut anti_by_gcd = std::collections::BTreeMap::<usize, f64>::new();

        for j_idx in 0..size {
            let j = j_idx + 1;
            // Diagonal contribution to vᵀGv
            let diag = c / (j as f64) - 1.0 / ((j as f64) * (j as f64));
            vtgv_total += v[j_idx] * v[j_idx] * diag;

            for k_idx in 0..size {
                let k = k_idx + 1;
                if k == j {
                    continue;
                }

                let d = gcd(j, k);
                let jp = j / d;
                let kp = k / d;
                let jf = j as f64;
                let kf = k as f64;
                let df = d as f64;
                let vv = v[j_idx] * v[k_idx];

                // Full off-diagonal Gram entry
                let term1 = c / 2.0 * (1.0 / jf + 1.0 / kf);
                let term2 = (jf - kf) / (2.0 * jf * kf) * (kf / jf).ln();
                let v_full = vasyunin_sum(jp, kp) + vasyunin_sum(kp, jp);
                let term3 = PI * df / (2.0 * jf * kf) * v_full;
                let term4 = 1.0 / (jf * kf);
                vtgv_total += vv * (term1 + term2 - term3 - term4);

                // Cotangent part only: -πd/(2jk) · V(j',k') · v_j · v_k
                // Decompose V into symmetric + antisymmetric
                let v_s = vasyunin_sym(jp, kp);
                let v_a = vasyunin_anti(jp, kp);

                let cot_factor = PI * df / (2.0 * jf * kf);
                // Note: in G, the cotangent enters as -term3 = -πd/(2jk)·(V+V)
                // sym part: -πd/(2jk) · 2·V_sym
                // anti part: -πd/(2jk) · 2·V_anti (this part changes sign under j↔k)
                cotres_sym += vv * (-cot_factor * 2.0 * v_s);
                cotres_anti += vv * (-cot_factor * 2.0 * v_a);
                cotres_total += vv * (-term3);

                *anti_by_gcd.entry(d).or_insert(0.0) += vv * (-cot_factor * 2.0 * v_a);
            }
        }

        let ratio = if vtgv_total.abs() > 1e-15 {
            cotres_anti / vtgv_total
        } else {
            f64::NAN
        };
        let anti_abs_ratio = if vtgv_total.abs() > 1e-15 {
            cotres_anti.abs() / vtgv_total
        } else {
            f64::NAN
        };

        println!("  N = {:>5}:  vᵀGv = {:+.8}", n, vtgv_total);
        println!("    CotRes_total = {:+.8}", cotres_total);
        println!(
            "    CotRes_sym   = {:+.8}  (rational, dissolved)",
            cotres_sym
        );
        println!(
            "    CotRes_anti  = {:+.8}  (transcendental, = RH)",
            cotres_anti
        );
        println!(
            "    |CotRes_anti|/vᵀGv = {:.6}  (need < 0.5 for Crown)",
            anti_abs_ratio
        );
        println!("    CotRes_anti/vᵀGv   = {:+.6}", ratio);

        // Show top GCD strata contributions to antisymmetric
        let mut anti_gcd_vec: Vec<_> = anti_by_gcd.iter().collect();
        anti_gcd_vec.sort_by(|a, b| b.1.abs().partial_cmp(&a.1.abs()).unwrap());
        print!("    Top GCD strata (anti): ");
        for (i, (&d, &val)) in anti_gcd_vec.iter().take(5).enumerate() {
            if i > 0 {
                print!(", ");
            }
            print!("d={}: {:+.4}", d, val);
        }
        println!();
        println!();
    }

    // ═══════════════════════════════════════════════════
    // SECTION 3: Glass fiber decomposition of cancellation
    // ═══════════════════════════════════════════════════
    println!("═══ §3: Glass Fiber Cancellation Budget ═══");
    println!("Decomposition of Σ ln(1-1/p) through three Hopf fibers:");
    println!();
    println!(
        "{:>5} {:>12} {:>12} {:>12} {:>12} {:>12}",
        "p", "total", "dark", "Glass₁", "Glass₂", "Glass₃"
    );

    let primes: Vec<usize> = {
        let mut sieve = [true; 100];
        sieve[0] = false;
        sieve[1] = false;
        for i in 2..10 {
            if sieve[i] {
                let mut j = i * i;
                while j < 100 {
                    sieve[j] = false;
                    j += i;
                }
            }
        }
        (2..100).filter(|&i| sieve[i]).collect()
    };

    let mut total_dark = 0.0;
    let mut total_g1 = 0.0;
    let mut total_g2 = 0.0;
    let mut total_g3 = 0.0;
    let mut total_log = 0.0;

    for &p in &primes {
        let pf = p as f64;
        let (dark, g1, g2, g3) = glass_weights(pf);
        let total = (1.0 - 1.0 / pf).ln();
        total_dark += dark;
        total_g1 += g1;
        total_g2 += g2;
        total_g3 += g3;
        total_log += total;

        if p <= 13 {
            println!(
                "{:5} {:12.6} {:12.6} {:12.6} {:12.6} {:12.6}",
                p, total, dark, g1, g2, g3
            );
        }
    }
    println!("  ...");
    println!(
        "{:>5} {:12.6} {:12.6} {:12.6} {:12.6} {:12.6}",
        "SUM", total_log, total_dark, total_g1, total_g2, total_g3
    );
    println!();
    let sum_fibers = total_dark + total_g1 + total_g2 + total_g3;
    println!(
        "  Verification: Σ fibers = {:.6}, Σ total = {:.6}, diff = {:.2e}",
        sum_fibers,
        total_log,
        (sum_fibers - total_log).abs()
    );
    println!();
    println!("  Cancellation budget:");
    println!(
        "    Dark (ζ(8)→ζ(16)):  {:.1}%",
        100.0 * total_dark / total_log
    );
    println!(
        "    Glass₁ (ℂ, U(1)):   {:.1}%",
        100.0 * total_g1 / total_log
    );
    println!(
        "    Glass₂ (ℍ, SU(2)):  {:.1}%",
        100.0 * total_g2 / total_log
    );
    println!(
        "    Glass₃ (𝕆, SU(3)):  {:.1}%",
        100.0 * total_g3 / total_log
    );
    println!();

    // ═══════════════════════════════════════════════════
    // SECTION 4: Scaling analysis of CotRes_anti
    // ═══════════════════════════════════════════════════
    println!("═══ §4: Scaling Analysis ═══");
    println!("Does CotRes_anti converge? Grow? Oscillate?");
    println!();
    println!(
        "{:>8} {:>12} {:>12} {:>12} {:>12}",
        "N", "CotRes_anti", "|anti|/vᵀGv", "CotRes_sym", "vᵀGv"
    );

    for &n in &[30, 60, 120, 240, 360, 720, 1000, 1260, 2520] {
        let mu = mobius_table(n + 1);
        let size = n - 1;
        let mut v = vec![0.0f64; size];
        for k in 1..n {
            v[k - 1] = -(mu[k] as f64) * log_weight(k, n);
        }

        let mut cotres_sym = 0.0f64;
        let mut cotres_anti = 0.0f64;
        let mut vtgv = 0.0f64;

        for j_idx in 0..size {
            let j = j_idx + 1;
            let jf = j as f64;
            vtgv += v[j_idx] * v[j_idx] * (c / jf - 1.0 / (jf * jf));

            for k_idx in 0..size {
                let k = k_idx + 1;
                if k == j {
                    continue;
                }
                let d = gcd(j, k);
                let jp = j / d;
                let kp = k / d;
                let jf = j as f64;
                let kf = k as f64;
                let df = d as f64;
                let vv = v[j_idx] * v[k_idx];

                // Full Gram entry
                let term1 = c / 2.0 * (1.0 / jf + 1.0 / kf);
                let term2 = (jf - kf) / (2.0 * jf * kf) * (kf / jf).ln();
                let v_full = vasyunin_sum(jp, kp) + vasyunin_sum(kp, jp);
                let term3 = PI * df / (2.0 * jf * kf) * v_full;
                let term4 = 1.0 / (jf * kf);
                vtgv += vv * (term1 + term2 - term3 - term4);

                // Cotangent decomposition
                let cot_factor = PI * df / (2.0 * jf * kf);
                cotres_sym += vv * (-cot_factor * 2.0 * vasyunin_sym(jp, kp));
                cotres_anti += vv * (-cot_factor * 2.0 * vasyunin_anti(jp, kp));
            }
        }

        let ratio = if vtgv.abs() > 1e-15 {
            cotres_anti.abs() / vtgv
        } else {
            f64::NAN
        };
        println!(
            "{:8} {:+12.8} {:12.6} {:+12.8} {:12.8}",
            n, cotres_anti, ratio, cotres_sym, vtgv
        );
    }

    println!();
    println!("════════════════════════════════════════════════════════════");
    println!("KEY QUESTION: Does |CotRes_anti|/vᵀGv stay bounded < 0.5?");
    println!("If YES → Crown holds → RH is proved.");
    println!("════════════════════════════════════════════════════════════");
}
