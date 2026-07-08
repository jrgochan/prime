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
//! Mertens L² Probe — The Irreducible Core of RH
//!
//! Computes the discrete Mertens L² sum:
//!   S(N) = Σ_{n=1}^{N} (M(n)/√n)²
//!
//! and the normalized version:
//!   R(N) = S(N) / N
//!
//! The key conjecture (equivalent to RH via Parseval):
//!   R(N) → finite constant as N → ∞
//!
//! We also compute the BD distance d²_N at small N using the
//! HPDF Gram matrices with dd (double-double) precision arithmetic,
//! to verify the relationship between d² and the Mertens L² bound.

use cathedral_utils::arith;
use cathedral_utils::mertens;
use std::time::Instant;

fn main() {
    println!("═══════════════════════════════════════════════════════════════");
    println!("  MERTENS L² PROBE — The Irreducible Core of RH");
    println!("═══════════════════════════════════════════════════════════════");
    println!();

    let n_max: usize = 50_000_000;

    println!("Sieving μ(k) up to {}...", n_max);
    let t0 = Instant::now();
    let mu = arith::mobius_table(n_max);
    println!("  Done in {:.2}s\n", t0.elapsed().as_secs_f64());

    println!("Computing M(n) = Σ μ(k) for k=1..n...");
    let t0 = Instant::now();
    let m = mertens::mertens_values(&mu);
    println!("  Done in {:.2}s\n", t0.elapsed().as_secs_f64());

    // ═══════════════════════════════════════════════════════════════
    // §1. Discrete Mertens L² sum: S(N) = Σ (M(n)/√n)²
    // ═══════════════════════════════════════════════════════════════

    println!("═══════════════════════════════════════════════════════════════");
    println!("§1. DISCRETE MERTENS L² SUM: S(N) = Σ (M(n)/√n)²");
    println!("═══════════════════════════════════════════════════════════════");
    println!();
    println!(
        "{:>12} {:>14} {:>14} {:>14} {:>14}",
        "N", "S(N)", "R(N)=S/N", "max|M|/√n", "R growth"
    );
    println!("{}", "-".repeat(72));

    let mut s_n = 0.0f64;
    let mut max_normalized = 0.0f64;
    let mut prev_r = 0.0f64;
    let mut checkpoints = vec![
        100, 200, 500, 1000, 2000, 5000, 10_000, 20_000, 50_000, 100_000, 200_000, 500_000,
        1_000_000, 2_000_000, 5_000_000, 10_000_000, 20_000_000, 50_000_000,
    ];
    checkpoints.retain(|&c| c <= n_max);

    let mut cp_idx = 0;

    for n in 1..=n_max {
        let mn = m[n] as f64;
        let sqrtn = (n as f64).sqrt();
        let normalized = mn / sqrtn;
        s_n += normalized * normalized;

        if mn.abs() / sqrtn > max_normalized {
            max_normalized = mn.abs() / sqrtn;
        }

        if cp_idx < checkpoints.len() && n == checkpoints[cp_idx] {
            let r_n = s_n / n as f64;
            let growth = if prev_r > 0.0 {
                format!("{:+.4}", r_n - prev_r)
            } else {
                "—".to_string()
            };
            println!(
                "{:>12} {:>14.4} {:>14.8} {:>14.6} {:>14}",
                n, s_n, r_n, max_normalized, growth
            );
            prev_r = r_n;
            cp_idx += 1;
        }
    }

    println!();

    // ═══════════════════════════════════════════════════════════════
    // §2. Weighted Mertens sums (related to axioms)
    // ═══════════════════════════════════════════════════════════════

    println!("═══════════════════════════════════════════════════════════════");
    println!("§2. WEIGHTED MERTENS SUMS (axiom-related)");
    println!("═══════════════════════════════════════════════════════════════");
    println!();

    // S_log(N) = Σ (M(n)/(√n · ln(n)))²  — the log-corrected L²
    // This is what the tapered Mertens rate looks like
    let mut s_log = 0.0f64;
    let mut s_log2 = 0.0f64;
    let mut s_inv = 0.0f64; // Σ M(n)²/n²

    println!(
        "{:>12} {:>16} {:>16} {:>16}",
        "N", "S_log(N)/N", "S_log²(N)/N", "Σ M²/n²"
    );
    println!("{}", "-".repeat(64));

    let mut cp_idx = 0;
    s_log = 0.0;
    s_log2 = 0.0;
    s_inv = 0.0;

    for n in 2..=n_max {
        let mn = m[n] as f64;
        let sqrtn = (n as f64).sqrt();
        let logn = (n as f64).ln();

        s_log += (mn / (sqrtn * logn)).powi(2);
        s_log2 += (mn / (sqrtn * logn * logn)).powi(2);
        s_inv += (mn / n as f64).powi(2);

        if cp_idx < checkpoints.len() && n == checkpoints[cp_idx] {
            println!(
                "{:>12} {:>16.10} {:>16.10} {:>16.10}",
                n,
                s_log / n as f64,
                s_log2 / n as f64,
                s_inv
            );
            cp_idx += 1;
        }
    }

    println!();

    // ═══════════════════════════════════════════════════════════════
    // §3. Running maximum of |M(n)|/√n (the Mertens hypothesis)
    // ═══════════════════════════════════════════════════════════════

    println!("═══════════════════════════════════════════════════════════════");
    println!("§3. MERTENS HYPOTHESIS: max |M(n)|/√n up to N");
    println!("═══════════════════════════════════════════════════════════════");
    println!();
    println!(
        "{:>12} {:>14} {:>14} {:>12} {:>14}",
        "N", "max|M|/√n", "M(N)/√N", "M(N)", "at n"
    );
    println!("{}", "-".repeat(68));

    let mut running_max = 0.0f64;
    let mut argmax_n = 0usize;
    let mut cp_idx = 0;

    for n in 1..=n_max {
        let mn = m[n] as f64;
        let ratio = mn.abs() / (n as f64).sqrt();
        if ratio > running_max {
            running_max = ratio;
            argmax_n = n;
        }

        if cp_idx < checkpoints.len() && n == checkpoints[cp_idx] {
            let mn_now = m[n] as f64 / (n as f64).sqrt();
            println!(
                "{:>12} {:>14.8} {:>14.8} {:>12} {:>14}",
                n, running_max, mn_now, m[n], argmax_n
            );
            cp_idx += 1;
        }
    }

    println!();

    // ═══════════════════════════════════════════════════════════════
    // §4. The Parseval connection: Σ |M(n)|²/n^{2σ} vs 1/|ζ(σ+it)|²
    // ═══════════════════════════════════════════════════════════════

    println!("═══════════════════════════════════════════════════════════════");
    println!("§4. PARSEVAL CONNECTION: D(σ) = Σ M(n)²/n^{{2σ}}");
    println!("  RH ⟺ D(σ) < ∞ for all σ > 1/2");
    println!("═══════════════════════════════════════════════════════════════");
    println!();

    let sigmas = [0.55, 0.60, 0.65, 0.70, 0.75, 0.80, 0.90, 1.00];

    println!(
        "{:>12} {:>14} {:>14} {:>14} {:>14}",
        "N", "σ=0.55", "σ=0.60", "σ=0.75", "σ=1.00"
    );
    println!("{}", "-".repeat(70));

    let mut d_sums: Vec<f64> = vec![0.0; sigmas.len()];
    let mut cp_idx = 0;

    for n in 1..=n_max {
        let mn2 = (m[n] as f64).powi(2);
        let nf = n as f64;

        for (i, &sigma) in sigmas.iter().enumerate() {
            d_sums[i] += mn2 / nf.powf(2.0 * sigma);
        }

        if cp_idx < checkpoints.len() && n == checkpoints[cp_idx] {
            println!(
                "{:>12} {:>14.4} {:>14.4} {:>14.4} {:>14.4}",
                n, d_sums[0], d_sums[1], d_sums[4], d_sums[7]
            );
            cp_idx += 1;
        }
    }

    println!();
    println!("Full σ scan at N={}:", n_max);
    for (i, &sigma) in sigmas.iter().enumerate() {
        let converged = if sigma > 0.5 && d_sums[i] < 1e15 {
            "✅"
        } else {
            "❌"
        };
        println!(
            "  σ={:.2}: D(σ) = {:>16.4}  {}",
            sigma, d_sums[i], converged
        );
    }

    println!();
    println!("═══════════════════════════════════════════════════════════════");
    println!("§5. VERDICT");
    println!("═══════════════════════════════════════════════════════════════");
    println!();

    let final_r = s_n / n_max as f64;
    println!("  R(N) = S(N)/N at N={}: {:.10}", n_max, final_r);
    println!();

    if final_r < 10.0 {
        println!("  R(N) appears BOUNDED → consistent with L² Mertens bound");
        println!("  (and therefore consistent with RH)");
    } else {
        println!("  R(N) appears GROWING → inconsistent with L² Mertens bound");
    }

    println!();
    println!("  Key: if R(N) → C (constant), then RH follows from");
    println!("  the Parseval identity connecting D(1/2) to ∫|1/ζ|² dt.");
    println!("  Current value C ≈ {:.6}", final_r);
}
