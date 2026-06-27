#![allow(dead_code, unused_variables, unused_imports, unused_assignments, clippy::needless_range_loop, clippy::doc_lazy_continuation, non_snake_case, clippy::empty_line_after_doc_comments)]
// overcancellation-scan/src/bin/overcancellation_anatomy.rs
//
// ╔═══════════════════════════════════════════════════════════════════╗
// ║  OVERCANCELLATION ANATOMY — Correct Vasyunin Decomposition      ║
// ║                                                                   ║
// ║  Uses the CORRECT Vasyunin Gram formula (with cotangent sums)    ║
// ║  and decomposes vᵀGv into four components:                       ║
// ║    diag, term1(CσS), term2(log), -term3(cot), -term4(-S²)       ║
// ║                                                                   ║
// ║  Parallelized with rayon for higher-N runs.                       ║
// ╚═══════════════════════════════════════════════════════════════════╝

use cathedral_utils::arith::{gcd, mobius_table};
use rayon::prelude::*;
use std::f64::consts::PI;

const EULER_GAMMA: f64 = 0.5772156649015329;

fn vasyunin_const() -> f64 {
    (2.0 * PI).ln() - EULER_GAMMA
}

/// Vasyunin sum V(a,b) = Σ_{m=1}^{a-1} cot(πm/a) · {mb/a}
fn vasyunin_sum(a: usize, b: usize) -> f64 {
    if a <= 1 { return 0.0; }
    let af = a as f64;
    let mut s = 0.0;
    for m in 1..a {
        let angle = PI * m as f64 / af;
        let cot = angle.cos() / angle.sin();
        let frac = ((m * b) as f64 / af).fract();
        s += cot * frac;
    }
    s
}

/// BD witness weight: v(k) = -μ(k) · (1 - ln(k)/ln(N))
fn log_weight(k: usize, n: usize) -> f64 {
    1.0 - (k as f64).ln() / (n as f64).ln()
}

/// Diagonal Gram entry G(k,k) = C/k - 1/k²
fn gram_diag(k: usize) -> f64 {
    let c = vasyunin_const();
    let kf = k as f64;
    c / kf - 1.0 / (kf * kf)
}

/// Compute a row's contribution to each term of vᵀGv
/// Returns (row_vtgv, row_term1, row_term2, row_term3, row_term4)
fn compute_row(j: usize, v: &[f64], n: usize) -> (f64, f64, f64, f64, f64) {
    let c = vasyunin_const();
    let jf = j as f64;
    let vj = v[j - 1];

    let mut row_diag = 0.0;
    let mut row_t1 = 0.0;
    let mut row_t2 = 0.0;
    let mut row_t3 = 0.0;
    let mut row_t4 = 0.0;

    for k in 1..n {
        let vk = v[k - 1];
        let w = vj * vk;

        if j == k {
            row_diag += w * gram_diag(j);
        } else {
            let kf = k as f64;
            let d = gcd(j, k);
            let jp = j / d;
            let kp = k / d;
            let df = d as f64;

            let t1 = c / 2.0 * (1.0 / jf + 1.0 / kf);
            let t2 = (jf - kf) / (2.0 * jf * kf) * (kf / jf).ln();
            let t3 = PI * df / (2.0 * jf * kf) * (vasyunin_sum(jp, kp) + vasyunin_sum(kp, jp));
            let t4 = 1.0 / (jf * kf);

            row_t1 += w * t1;
            row_t2 += w * t2;
            row_t3 += w * t3;  // note: subtracted in G, so -term3 contribution
            row_t4 += w * t4;  // note: subtracted in G, so -term4 contribution
        }
    }

    // G(j,k) = term1 + term2 - term3 - term4
    // vᵀGv = diag + Σ (t1 + t2 - t3 - t4)·v_j·v_k
    let row_total = row_diag + row_t1 + row_t2 - row_t3 - row_t4;
    (row_total, row_t1, row_t2, row_t3, row_t4)
}

fn main() {
    println!("╔═══════════════════════════════════════════════════════════════╗");
    println!("║  OVERCANCELLATION ANATOMY — Vasyunin Decomposition          ║");
    println!("╚═══════════════════════════════════════════════════════════════╝");
    println!();

    let c = vasyunin_const();
    println!("C = ln(2π) − γ = {:.6}", c);
    println!();

    // Start with smaller N values, go up to 2520
    let ns: Vec<usize> = vec![30, 60, 100, 300, 600, 1000, 2520];

    println!("{:>6} {:>10} {:>10} {:>10} {:>10} {:>10} {:>10} {:>10} {:>10} {:>10}",
        "N", "vᵀGv", "1-vᵀGv", "‖v‖²", "diag", "term1", "term2", "-term3", "-term4", "vᵀGv/‖v‖²");
    println!("{}", "─".repeat(106));

    for &n in &ns {
        let mu = mobius_table(n + 1);
        let size = n - 1;

        // Build witness vector
        let mut v = vec![0.0f64; size];
        for k in 1..n {
            v[k-1] = -(mu[k] as f64) * log_weight(k, n);
        }

        let norm_sq: f64 = v.iter().map(|x| x * x).sum();
        let _sigma: f64 = v.iter().sum();
        let _s: f64 = v.iter().enumerate().map(|(i, vi)| vi / (i as f64 + 1.0)).sum();

        eprint!("  N = {:5} ({} rows)...", n, size);

        // Parallel row computation
        let results: Vec<(f64, f64, f64, f64, f64)> = (1..n).into_par_iter()
            .map(|j| compute_row(j, &v, n))
            .collect();

        let mut vtgv = 0.0f64;
        let mut diag_total = 0.0f64;
        let mut t1_total = 0.0f64;
        let mut t2_total = 0.0f64;
        let mut t3_total = 0.0f64;
        let mut t4_total = 0.0f64;

        // Sum diagonal separately
        for j in 1..n {
            diag_total += v[j-1] * v[j-1] * gram_diag(j);
        }

        for (row_vtgv, rt1, rt2, rt3, rt4) in &results {
            vtgv += row_vtgv;
            t1_total += rt1;
            t2_total += rt2;
            t3_total += rt3;
            t4_total += rt4;
        }

        eprintln!(" done (vᵀGv = {:.4})", vtgv);

        println!("{:>6} {:>+10.4} {:>+10.4} {:>10.2} {:>+10.4} {:>+10.4} {:>+10.4} {:>+10.4} {:>+10.4} {:>10.6}",
            n, vtgv, 1.0 - vtgv, norm_sq,
            diag_total, t1_total, t2_total, -t3_total, -t4_total,
            vtgv / norm_sq);
    }

    println!();
    println!("NOTE: G(j,k) = term1 + term2 - term3 - term4");
    println!("  → vᵀGv = diag + term1 + term2 - term3 - term4");
    println!("  → So '-term3' and '-term4' show the NEGATIVE contributions");
}
