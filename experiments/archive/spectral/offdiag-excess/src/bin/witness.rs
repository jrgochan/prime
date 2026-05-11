#![allow(unused, dead_code)]
//! Báez-Duarte Witness Experiment
//!
//! Compares three witnesses for the Nyman-Beurling distance:
//! 1. Constant: v_i = c (the failed approach)
//! 2. Möbius:   v_i = μ(i+1) / (i+1) (Báez-Duarte golden path)
//! 3. Optimal:  v = G⁻¹b (the true infimum)
//!
//! For each witness, computes d² = 1 - 2·bᵀv + vᵀGv

use rayon::prelude::*;
use offdiag_excess::{gram_entry, fract_integral};

/// Compute the Möbius function μ(n) via trial division.
fn moebius(n: usize) -> i32 {
    if n == 0 { return 0; }
    if n == 1 { return 1; }

    let mut m = n;
    let mut num_factors = 0;

    // Trial division
    let mut p = 2;
    while p * p <= m {
        if m % p == 0 {
            num_factors += 1;
            m /= p;
            if m % p == 0 {
                // p² divides n → μ(n) = 0
                return 0;
            }
        }
        p += 1;
    }
    if m > 1 {
        num_factors += 1;
    }

    if num_factors % 2 == 0 { 1 } else { -1 }
}

/// Solve Ax = b using Cholesky-like approach (simple Gaussian elimination for SPD)
fn solve_spd(a: &[Vec<f64>], b: &[f64]) -> Vec<f64> {
    let n = b.len();
    // Augmented matrix
    let mut aug: Vec<Vec<f64>> = a.iter().enumerate().map(|(i, row)| {
        let mut r = row.clone();
        r.push(b[i]);
        r
    }).collect();

    // Forward elimination with partial pivoting
    for col in 0..n {
        // Find pivot
        let mut max_val = aug[col][col].abs();
        let mut max_row = col;
        for row in (col + 1)..n {
            if aug[row][col].abs() > max_val {
                max_val = aug[row][col].abs();
                max_row = row;
            }
        }
        if max_val < 1e-15 {
            eprintln!("WARNING: Near-singular matrix at col {}", col);
        }
        aug.swap(col, max_row);

        let pivot = aug[col][col];
        for row in (col + 1)..n {
            let factor = aug[row][col] / pivot;
            for j in col..=n {
                let val = aug[col][j];
                aug[row][j] -= factor * val;
            }
        }
    }

    // Back substitution
    let mut x = vec![0.0; n];
    for i in (0..n).rev() {
        let mut sum = aug[i][n];
        for j in (i + 1)..n {
            sum -= aug[i][j] * x[j];
        }
        x[i] = sum / aug[i][i];
    }
    x
}

fn main() {
    let sizes: Vec<usize> = std::env::args()
        .skip(1)
        .filter_map(|s| s.parse().ok())
        .collect();
    let sizes = if sizes.is_empty() {
        vec![10, 20, 30, 50, 75, 100, 150, 200]
    } else {
        sizes
    };

    eprintln!("═══════════════════════════════════════════════════════");
    eprintln!("  Báez-Duarte Witness Experiment");
    eprintln!("  Comparing: Constant | Möbius (μ/k) | Optimal (G⁻¹b)");
    eprintln!("═══════════════════════════════════════════════════════\n");

    eprintln!("{:>5} {:>12} {:>12} {:>12} {:>10} {:>10}",
        "n", "d²(const)", "d²(möbius)", "d²(optimal)", "möb/const", "möb→0?");
    eprintln!("{}", "-".repeat(68));

    let mut results: Vec<serde_json::Value> = Vec::new();

    for &n in &sizes {
        let start = std::time::Instant::now();

        // Build the n×n Gram matrix G and basis vector b
        // Using indices 1..=n (matching Lean's gramMatrix (n+1))
        let dim = n;

        // Basis vector: b_i = ∫₀¹ {(i+1)/x} dx
        let b: Vec<f64> = (0..dim).map(|i| fract_integral(i + 1)).collect();

        // Build Gram matrix (parallelized by row)
        let g: Vec<Vec<f64>> = (0..dim).into_par_iter().map(|i| {
            (0..dim).map(|j| gram_entry(i + 1, j + 1)).collect()
        }).collect();

        // ── Witness 1: Constant ──
        // Optimal constant: c = (Σ b_i) / (Σᵢⱼ G(i,j))
        let b_sum: f64 = b.iter().sum();
        let g_sum: f64 = g.iter().map(|row| row.iter().sum::<f64>()).sum();
        let c_opt = b_sum / g_sum;

        // d²(const) = 1 - 2c·Σb_i + c²·Σᵢⱼ G(i,j)
        let d2_const = 1.0 - 2.0 * c_opt * b_sum + c_opt * c_opt * g_sum;

        // ── Witness 2: Möbius μ(k)/k ──
        // v_i = μ(i+1) / (i+1)
        let v_mob: Vec<f64> = (0..dim).map(|i| {
            let k = i + 1;
            moebius(k) as f64 / k as f64
        }).collect();

        // d²(möb) = 1 - 2·bᵀv + vᵀGv
        let btv_mob: f64 = b.iter().zip(v_mob.iter()).map(|(bi, vi)| bi * vi).sum();
        let vtgv_mob: f64 = (0..dim).map(|i| {
            let gv_i: f64 = (0..dim).map(|j| g[i][j] * v_mob[j]).sum();
            v_mob[i] * gv_i
        }).sum();
        let d2_mob = 1.0 - 2.0 * btv_mob + vtgv_mob;

        // ── Witness 3: Optimal v = G⁻¹b ──
        // d²(opt) = 1 - bᵀG⁻¹b
        let v_opt = solve_spd(&g, &b);
        let btginvb: f64 = b.iter().zip(v_opt.iter()).map(|(bi, vi)| bi * vi).sum();
        let d2_opt = 1.0 - btginvb;

        // Also try scaled Möbius: find optimal α such that d²(α·v_mob) is minimized
        // d²(α·v) = 1 - 2α·bᵀv + α²·vᵀGv
        // Minimize: α* = bᵀv / vᵀGv
        let alpha_opt = btv_mob / vtgv_mob;
        let d2_mob_scaled = 1.0 - btv_mob * btv_mob / vtgv_mob;

        let elapsed = start.elapsed();

        eprintln!("{:5} {:12.6} {:12.6} {:12.6} {:10.4} {:>10}  ({:.1}s)",
            n, d2_const, d2_mob_scaled, d2_opt,
            d2_mob_scaled / d2_const,
            if d2_mob_scaled < d2_const { "better" } else { "worse" },
            elapsed.as_secs_f64());

        results.push(serde_json::json!({
            "n": n,
            "d2_constant": d2_const,
            "d2_mobius_raw": d2_mob,
            "d2_mobius_scaled": d2_mob_scaled,
            "d2_optimal": d2_opt,
            "alpha_optimal": alpha_opt,
            "ratio_mob_const": d2_mob_scaled / d2_const,
            "btv_mob": btv_mob,
            "vtgv_mob": vtgv_mob,
            "b_sum": b_sum,
            "g_sum": g_sum,
            "time_s": elapsed.as_secs_f64(),
        }));
    }

    // Summary
    eprintln!("\n═══ Summary ═══");
    eprintln!("If d²(möbius) → 0 faster than d²(constant), the Möbius witness works!");
    eprintln!("If d²(optimal) → 0, that confirms Nyman-Beurling convergence.\n");

    // Check trends
    if results.len() >= 2 {
        let last = &results[results.len() - 1];
        let prev = &results[results.len() - 2];
        let d2_opt_last = last["d2_optimal"].as_f64().unwrap();
        let d2_opt_prev = prev["d2_optimal"].as_f64().unwrap();
        let d2_mob_last = last["d2_mobius_scaled"].as_f64().unwrap();
        let d2_const_last = last["d2_constant"].as_f64().unwrap();

        eprintln!("  d²(optimal) trend: {:.6} → {:.6} ({})",
            d2_opt_prev, d2_opt_last,
            if d2_opt_last < d2_opt_prev { "DECREASING ✓" } else { "INCREASING ✗" });
        eprintln!("  d²(möbius)/d²(const) = {:.4} (< 1 means Möbius is better)",
            d2_mob_last / d2_const_last);
    }

    // Write JSON
    let json = serde_json::to_string_pretty(&results).unwrap();
    std::fs::write("results/witness_comparison.json", &json).unwrap();
    eprintln!("\n✅ Results written to results/witness_comparison.json");
}
