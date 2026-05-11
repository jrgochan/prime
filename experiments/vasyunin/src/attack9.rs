/// Attack 9: The Dimensional Autopsy
///
/// Decomposes v^T C_N v into its 5 component dimensions:
///   1. Rational:  G1(j,k) = A/2 * (1/j + 1/k)
///   2. Logarithmic: G2(j,k) = (j-k)/(2jk) * ln(k/j)
///   3. Cotangent: G3(j,k) = -π·d/(2jk) * (V(j',k') + V(k',j'))
///   4. Base:      G4(j,k) = -1/(jk)
///   5. Mean:      -(b^T v)^2
///
/// Hypothesis: Rational and Base flatline (PNT); RH lives in Log × Cot × Mean.
use std::f64::consts::PI;
use rayon::prelude::*;

use cathedral_utils::arith::{gcd, EULER_GAMMA, mobius_table};

fn main() {
    let a = std::f64::consts::TAU.ln() - EULER_GAMMA; // A = ln(2π) - γ
    println!("═══ Attack 9: The Dimensional Autopsy (Rust) ═══");
    println!("  A = ln(2π) - γ = {:.10}", a);
    println!();

    // Sieve μ
    let max_n = 50_000usize;
    let mu = mobius_table(max_n);

    // PNT diagnostic
    println!("═══ PNT Diagnostic: Σμ(k)/k ═══");
    for &n in &[100, 500, 1000, 5000, 10000, 20000, 50000] {
        let sum: f64 = (1..=n).map(|k| mu[k] as f64 / k as f64).sum();
        println!("  N={:>6}: Σμ(k)/k = {:>14.10}", n, sum);
    }
    println!();

    let ns = vec![50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000, 50000];

    println!("═══ Computing decompositions... ═══");
    let mut results = Vec::new();

    for &n in &ns {
        let t0 = std::time::Instant::now();
        let r = dimensional_autopsy(n, &mu, a);
        let dt = t0.elapsed().as_secs_f64();
        println!("  N={:>6}  {:.1}s  Q/ln={:.4}", n, dt, r.q_over_ln);
        results.push(r);
    }

    // ─── Tables ───
    println!();
    println!("═══ Dimensional Decomposition: v^T [component] v ═══");
    println!("{:>6} {:>13} {:>13} {:>13} {:>13} {:>13} {:>13}",
             "N", "Rational", "Log", "Cotangent", "Base", "Mean", "TOTAL");
    println!("{}", "-".repeat(90));
    for r in &results {
        println!("{:>6} {:>13.4e} {:>13.4e} {:>13.4e} {:>13.4e} {:>13.4e} {:>13.4e}",
                 r.n, r.vt_g1, r.vt_g2, r.vt_g3, r.vt_g4, r.mean_defl, r.vt_cv);
    }

    println!();
    println!("═══ Percentage Contribution (|component| / Σ|all|) ═══");
    println!("{:>6} {:>10} {:>10} {:>10} {:>10} {:>10}", "N", "%Rational", "%Log", "%Cot", "%Base", "%Mean");
    println!("{}", "-".repeat(60));
    for r in &results {
        let total = r.vt_g1.abs() + r.vt_g2.abs() + r.vt_g3.abs() + r.vt_g4.abs() + r.mean_defl.abs();
        println!("{:>6} {:>9.2}% {:>9.2}% {:>9.2}% {:>9.2}% {:>9.2}%",
                 r.n,
                 r.vt_g1.abs()/total*100.0,
                 r.vt_g2.abs()/total*100.0,
                 r.vt_g3.abs()/total*100.0,
                 r.vt_g4.abs()/total*100.0,
                 r.mean_defl.abs()/total*100.0);
    }

    println!();
    println!("═══ Rank-1 Kill Diagnostic ═══");
    println!("{:>6} {:>14} {:>14} {:>14}", "N", "Σv_k", "Σv_k/k", "|G1|/|G3|");
    println!("{}", "-".repeat(52));
    for r in &results {
        let ratio = if r.vt_g3.abs() > 1e-30 { r.vt_g1.abs() / r.vt_g3.abs() } else { f64::INFINITY };
        println!("{:>6} {:>14.6} {:>14.10} {:>14.6}", r.n, r.sum_v, r.sum_v_over_k, ratio);
    }

    println!();
    println!("═══ Rayleigh Quotient ═══");
    println!("{:>6} {:>10} {:>14} {:>14}", "N", "Q/ln(N)", "(b^Tv)²", "v^TCv");
    println!("{}", "-".repeat(46));
    for r in &results {
        println!("{:>6} {:>10.4} {:>14.4e} {:>14.4e}", r.n, r.q_over_ln, r.btv_sq, r.vt_cv);
    }

    // Save JSON
    let json_results: Vec<serde_json::Value> = results.iter().map(|r| {
        serde_json::json!({
            "N": r.n,
            "ln_N": r.ln_n,
            "Q_over_ln": r.q_over_ln,
            "vt_G1_rational": r.vt_g1,
            "vt_G2_log": r.vt_g2,
            "vt_G3_cot": r.vt_g3,
            "vt_G4_base": r.vt_g4,
            "mean_deflation": r.mean_defl,
            "vt_C_v": r.vt_cv,
            "bTv_sq": r.btv_sq,
            "sum_v": r.sum_v,
            "sum_v_over_k": r.sum_v_over_k,
        })
    }).collect();

    let output = serde_json::json!({
        "experiment": "attack9_dimensional_autopsy",
        "hypothesis": "Rational and Base dimensions flatline; RH lives in Log x Cot x Mean",
        "results": json_results
    });

    std::fs::write(
        "results_attack9.json",
        serde_json::to_string_pretty(&output).unwrap()
    ).expect("Failed to write results");

    println!();
    println!("  📄 Saved to results_attack9.json");
    println!("  ✅ Attack 9 complete.");
}

struct AutopsyResult {
    n: usize,
    ln_n: f64,
    vt_g1: f64,  // Rational
    vt_g2: f64,  // Log
    vt_g3: f64,  // Cotangent
    vt_g4: f64,  // Base
    mean_defl: f64,
    vt_cv: f64,  // Total
    btv_sq: f64,
    q_over_ln: f64,
    sum_v: f64,
    sum_v_over_k: f64,
}

fn dimensional_autopsy(n: usize, mu: &[i8], a: f64) -> AutopsyResult {
    let ln_n = (n as f64).ln();

    // Witness vector and mean vector
    let mut v = vec![0.0f64; n + 1];
    let mut b = vec![0.0f64; n + 1];
    for k in 1..=n {
        v[k] = -(mu[k] as f64) * (1.0 - (k as f64).ln() / ln_n);
        b[k] = ((k as f64).ln() + 1.0 - EULER_GAMMA) / k as f64;
    }

    // Rank-1 sums (instant)
    let sum_v: f64 = (1..=n).map(|k| v[k]).sum();
    let sum_v_over_k: f64 = (1..=n).map(|k| v[k] / k as f64).sum();
    let btv: f64 = (1..=n).map(|k| b[k] * v[k]).sum();

    // Term 1 (Rational): A * Σv * Σ(v/k)
    let vt_g1 = a * sum_v * sum_v_over_k;

    // Term 4 (Base): -(Σv/k)²
    let vt_g4 = -sum_v_over_k.powi(2);

    // Mean deflation
    let mean_defl = -btv.powi(2);

    // Terms 2 (Log) and 3 (Cot): need pairwise sums
    // Only squarefree indices matter (μ≠0)
    let nonzero: Vec<usize> = (1..=n).filter(|&k| mu[k] != 0).collect();

    // Parallel computation of Term 2 and Term 3
    let (vt_g2, vt_g3) = nonzero.par_iter().enumerate().map(|(i_idx, &j)| {
        let mut g2_sum = 0.0f64;
        let mut g3_sum = 0.0f64;

        for &k in &nonzero[i_idx + 1..] {
            let vj_vk = v[j] * v[k];
            if vj_vk.abs() < 1e-30 {
                continue;
            }

            // Term 2: Log
            let g2 = (j as f64 - k as f64) / (2.0 * j as f64 * k as f64)
                * (k as f64 / j as f64).ln();
            g2_sum += 2.0 * vj_vk * g2;

            // Term 3: Cotangent
            let d = gcd(j, k);
            let jp = j / d;
            let kp = k / d;
            let v1 = vasyunin_sum(jp, kp);
            let v2 = vasyunin_sum(kp, jp);
            let g3 = -PI * d as f64 / (2.0 * j as f64 * k as f64) * (v1 + v2);
            g3_sum += 2.0 * vj_vk * g3;
        }

        (g2_sum, g3_sum)
    }).reduce(|| (0.0, 0.0), |(a1, b1), (a2, b2)| (a1 + a2, b1 + b2));

    let vt_cv = vt_g1 + vt_g2 + vt_g3 + vt_g4 + mean_defl;
    let q = if vt_cv > 0.0 { btv.powi(2) / vt_cv } else { f64::INFINITY };

    AutopsyResult {
        n, ln_n, vt_g1, vt_g2, vt_g3, vt_g4, mean_defl, vt_cv,
        btv_sq: btv.powi(2),
        q_over_ln: q / ln_n,
        sum_v, sum_v_over_k,
    }
}

fn vasyunin_sum(a: usize, b: usize) -> f64 {
    if a <= 1 { return 0.0; }
    let mut total = 0.0f64;
    for m in 1..a {
        let frac = (m * b % a) as f64 / a as f64;
        let cot = 1.0 / (PI * m as f64 / a as f64).tan();
        total += frac * cot;
    }
    total
}

