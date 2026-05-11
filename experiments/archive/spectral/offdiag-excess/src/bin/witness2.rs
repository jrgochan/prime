#![allow(unused, dead_code)]
//! Corrected Báez-Duarte Witness Experiment
//!
//! Uses the CORRECT NB basis indexing: {2/x}, {3/x}, ..., {(n+1)/x}
//! Witness vectors tested:
//! 1. Constant: v_i = c
//! 2. Möbius:   v_i = μ(i+2) / (i+2)  (for basis {(i+2)/x})
//! 3. 1/k:      v_i = 1/(i+2)          (harmonic weights)
//! 4. Optimal:  v = G⁻¹b

use offdiag_excess::{fract_integral, gram_entry};
use rayon::prelude::*;

fn moebius(n: usize) -> i32 {
    if n == 0 {
        return 0;
    }
    if n == 1 {
        return 1;
    }
    let mut m = n;
    let mut num_factors = 0;
    let mut p = 2;
    while p * p <= m {
        if m % p == 0 {
            num_factors += 1;
            m /= p;
            if m % p == 0 {
                return 0;
            }
        }
        p += 1;
    }
    if m > 1 {
        num_factors += 1;
    }
    if num_factors % 2 == 0 {
        1
    } else {
        -1
    }
}

fn solve_spd(a: &[Vec<f64>], b: &[f64]) -> Vec<f64> {
    let n = b.len();
    let mut aug: Vec<Vec<f64>> = a
        .iter()
        .enumerate()
        .map(|(i, row)| {
            let mut r = row.clone();
            r.push(b[i]);
            r
        })
        .collect();
    for col in 0..n {
        let mut max_row = col;
        for row in (col + 1)..n {
            if aug[row][col].abs() > aug[max_row][col].abs() {
                max_row = row;
            }
        }
        aug.swap(col, max_row);
        let pivot = aug[col][col];
        if pivot.abs() < 1e-15 {
            continue;
        }
        for row in (col + 1)..n {
            let factor = aug[row][col] / pivot;
            for j in col..=n {
                let val = aug[col][j];
                aug[row][j] -= factor * val;
            }
        }
    }
    let mut x = vec![0.0; n];
    for i in (0..n).rev() {
        let mut sum = aug[i][n];
        for j in (i + 1)..n {
            sum -= aug[i][j] * x[j];
        }
        if aug[i][i].abs() > 1e-15 {
            x[i] = sum / aug[i][i];
        }
    }
    x
}

struct WitnessResult {
    name: &'static str,
    d2_raw: f64,
    d2_scaled: f64,
    alpha: f64,
    btv: f64,
    vtgv: f64,
}

fn evaluate_witness(name: &'static str, v: &[f64], b: &[f64], g: &[Vec<f64>]) -> WitnessResult {
    let dim = v.len();
    let btv: f64 = b.iter().zip(v.iter()).map(|(bi, vi)| bi * vi).sum();
    let vtgv: f64 = (0..dim)
        .map(|i| {
            let gv_i: f64 = (0..dim).map(|j| g[i][j] * v[j]).sum();
            v[i] * gv_i
        })
        .sum();
    let d2_raw = 1.0 - 2.0 * btv + vtgv;
    let (d2_scaled, alpha) = if vtgv.abs() > 1e-15 {
        (1.0 - btv * btv / vtgv, btv / vtgv)
    } else {
        (d2_raw, 1.0)
    };
    WitnessResult {
        name,
        d2_raw,
        d2_scaled,
        alpha,
        btv,
        vtgv,
    }
}

fn main() {
    let sizes: Vec<usize> = std::env::args()
        .skip(1)
        .filter_map(|s| s.parse().ok())
        .collect();
    let sizes = if sizes.is_empty() {
        vec![10, 20, 30, 50, 75, 100, 150, 200, 300]
    } else {
        sizes
    };

    eprintln!("═══════════════════════════════════════════════════════");
    eprintln!("  Corrected Witness Experiment (indices 2..n+1)");
    eprintln!("═══════════════════════════════════════════════════════\n");

    eprintln!(
        "{:>5} {:>10} {:>10} {:>10} {:>10} {:>10}",
        "n", "Constant", "Möbius", "1/k", "Optimal", "time"
    );
    eprintln!("{}", "-".repeat(60));

    for &n in &sizes {
        let start = std::time::Instant::now();
        let dim = n;

        // Build Gram matrix with CORRECT indexing: gramEntry(i+2, j+2)
        // This matches the actual NB basis {2/x}, ..., {(n+1)/x}
        let b: Vec<f64> = (0..dim).map(|i| fract_integral(i + 2)).collect();
        let g: Vec<Vec<f64>> = (0..dim)
            .into_par_iter()
            .map(|i| (0..dim).map(|j| gram_entry(i + 2, j + 2)).collect())
            .collect();

        // Witness 1: Constant
        let v_const: Vec<f64> = vec![1.0; dim];
        let w_const = evaluate_witness("const", &v_const, &b, &g);

        // Witness 2: Möbius μ(k)/k for k = 2..n+1
        let v_mob: Vec<f64> = (0..dim)
            .map(|i| {
                let k = i + 2;
                moebius(k) as f64 / k as f64
            })
            .collect();
        let w_mob = evaluate_witness("möbius", &v_mob, &b, &g);

        // Witness 3: 1/k for k = 2..n+1
        let v_harm: Vec<f64> = (0..dim).map(|i| 1.0 / (i + 2) as f64).collect();
        let w_harm = evaluate_witness("1/k", &v_harm, &b, &g);

        // Witness 4: Optimal G⁻¹b
        let v_opt = solve_spd(&g, &b);
        let btginvb: f64 = b.iter().zip(v_opt.iter()).map(|(bi, vi)| bi * vi).sum();
        let d2_opt = 1.0 - btginvb;

        let elapsed = start.elapsed();

        eprintln!(
            "{:5} {:10.6} {:10.6} {:10.6} {:10.6} {:>10.1}s",
            n,
            w_const.d2_scaled,
            w_mob.d2_scaled,
            w_harm.d2_scaled,
            d2_opt,
            elapsed.as_secs_f64()
        );
    }

    eprintln!("\n(All d² values use optimal scaling α* = bᵀv / vᵀGv)");
    eprintln!("Lower is better. d²→0 proves RH via Nyman-Beurling.");
}
