#![allow(unused, dead_code)]
//! High-Precision Octonionic Witness Experiment
//!
//! Uses MPFR (256-bit) for the 8×8 class-level Gram matrix aggregation
//! and solve. Individual Gram entries are computed in f64 (sufficient
//! for ~15 digits), then accumulated with full precision.
//!
//! The KEY QUESTION: is d²(8cls) truly positive for all N, or does it
//! genuinely cross zero at n≈500?
//!
//! Usage: cargo run --release --bin oct_precision [sizes...]

use rayon::prelude::*;
use offdiag_excess::{gram_entry, fract_integral};
use rug::{Float, float::Round};

const PREC: u32 = 256; // 256-bit precision (~77 decimal digits)

fn min_prime_factor(n: usize) -> usize {
    if n <= 1 { return 1; }
    if n % 2 == 0 { return 2; }
    let mut p = 3;
    while p * p <= n {
        if n % p == 0 { return p; }
        p += 2;
    }
    n
}

fn octonion_class(k: usize) -> usize {
    match min_prime_factor(k) {
        2 => 0, 3 => 1, 5 => 2, 7 => 3,
        11 => 4, 13 => 5, 17 => 6, _ => 7,
    }
}

fn class_label(cls: usize) -> &'static str {
    match cls {
        0 => "even", 1 => "3|k", 2 => "5|k", 3 => "7|k",
        4 => "11|k", 5 => "13|k", 6 => "17|k", 7 => "≥19",
        _ => "?",
    }
}

/// Solve 8×8 system in MPFR precision via Gaussian elimination
fn solve_mpfr(a: &[Vec<Float>], b: &[Float]) -> Vec<Float> {
    let n = b.len();
    // Build augmented matrix
    let mut aug: Vec<Vec<Float>> = (0..n).map(|i| {
        let mut row: Vec<Float> = a[i].iter().map(|x| x.clone()).collect();
        row.push(b[i].clone());
        row
    }).collect();

    let mut perm: Vec<usize> = (0..n).collect();

    for col in 0..n {
        // Partial pivoting
        let mut max_row = col;
        for row in (col + 1)..n {
            if aug[row][col].clone().abs() > aug[max_row][col].clone().abs() {
                max_row = row;
            }
        }
        aug.swap(col, max_row);
        perm.swap(col, max_row);

        let pivot = aug[col][col].clone();
        if pivot.clone().abs() < Float::with_val(PREC, 1e-100) {
            continue;
        }
        for row in (col + 1)..n {
            let factor = Float::with_val(PREC, &aug[row][col] / &pivot);
            for j in col..=n {
                let val = aug[col][j].clone();
                aug[row][j] -= &factor * &val;
            }
        }
    }

    // Back-substitution
    let mut x: Vec<Float> = (0..n).map(|_| Float::with_val(PREC, 0)).collect();
    for i in (0..n).rev() {
        let mut sum = aug[i][n].clone();
        for j in (i + 1)..n {
            sum -= &aug[i][j] * &x[j];
        }
        x[i] = Float::with_val(PREC, &sum / &aug[i][i]);
    }
    x
}

fn main() {
    let sizes: Vec<usize> = std::env::args()
        .skip(1)
        .filter_map(|s| s.parse().ok())
        .collect();
    let sizes = if sizes.is_empty() {
        vec![100, 200, 300, 400, 500, 600, 700, 800, 1000]
    } else {
        sizes
    };

    eprintln!("══════════════════════════════════════════════════════════════════");
    eprintln!("  High-Precision Octonionic Witness (MPFR {}-bit)", PREC);
    eprintln!("  Gram entries: f64 | 8×8 aggregation+solve: MPFR");
    eprintln!("══════════════════════════════════════════════════════════════════\n");

    eprintln!("{:>5} {:>12} {:>12} {:>14} {:>12} {:>8}",
        "n", "d2(const)", "d2(8cls)", "btv_mpfr", "1-btv", "time");
    eprintln!("{}", "-".repeat(70));

    for &n in &sizes {
        let start = std::time::Instant::now();
        let dim = n;

        // Build Gram matrix in f64 (sufficient precision per entry)
        let b_f64: Vec<f64> = (0..dim).map(|i| fract_integral(i + 2)).collect();
        let g_f64: Vec<Vec<f64>> = (0..dim).into_par_iter().map(|i| {
            (0..dim).map(|j| gram_entry(i + 2, j + 2)).collect()
        }).collect();

        let classes: Vec<usize> = (0..dim).map(|i| octonion_class(i + 2)).collect();

        // Find active classes
        let mut active_classes: Vec<usize> = Vec::new();
        let mut class_count = vec![0usize; 8];
        for &c in &classes { class_count[c] += 1; }
        for c in 0..8 { if class_count[c] > 0 { active_classes.push(c); } }
        let nc = active_classes.len();

        let mut class_to_idx = vec![0usize; 8];
        for (idx, &c) in active_classes.iter().enumerate() {
            class_to_idx[c] = idx;
        }

        // ═══ Aggregate into 8×8 using MPFR precision ═══
        let mut g_cls: Vec<Vec<Float>> = (0..nc).map(|_| {
            (0..nc).map(|_| Float::with_val(PREC, 0)).collect()
        }).collect();
        let mut b_cls: Vec<Float> = (0..nc).map(|_| Float::with_val(PREC, 0)).collect();

        for i in 0..dim {
            let ci = class_to_idx[classes[i]];
            b_cls[ci] += b_f64[i];
            for j in 0..dim {
                let cj = class_to_idx[classes[j]];
                g_cls[ci][cj] += g_f64[i][j];
            }
        }

        // ═══ Solve in MPFR ═══
        let c_cls = solve_mpfr(&g_cls, &b_cls);

        // Compute btv = c^T · b_cls in MPFR
        let mut btv = Float::with_val(PREC, 0);
        for i in 0..nc {
            btv += Float::with_val(PREC, &c_cls[i] * &b_cls[i]);
        }
        let d2_cls = Float::with_val(PREC, 1) - &btv;

        // Also compute vtGv directly for cross-check
        let mut vtgv = Float::with_val(PREC, 0);
        for i in 0..nc {
            for j in 0..nc {
                vtgv += Float::with_val(PREC, &c_cls[i] * &Float::with_val(PREC, &c_cls[j] * &g_cls[i][j]));
            }
        }
        // d²_direct = 1 - 2*btv + vtgv
        let d2_direct = Float::with_val(PREC, 1) - Float::with_val(PREC, 2) * &btv + &vtgv;

        // Constant witness in f64
        let b_sum: f64 = b_f64.iter().sum();
        let g_sum: f64 = g_f64.iter().map(|row| row.iter().sum::<f64>()).sum();
        let c_const = b_sum / g_sum;
        let d2_const = 1.0 - 2.0 * c_const * b_sum + c_const * c_const * g_sum;

        let elapsed = start.elapsed();

        // Format the key value with many digits
        let btv_str = btv.to_string_radix(10, Some(20));
        let d2_str = d2_cls.to_string_radix(10, Some(15));

        eprintln!("{:5} {:12.6} {:>12} {:>14} {:>12} {:8.1}s",
            n, d2_const, d2_str, btv_str, 
            format!("{:.10}", d2_cls.to_f64_round(Round::Nearest)),
            elapsed.as_secs_f64());

        // Cross-check: d2_direct should equal d2_cls if c = G⁻¹b
        let crosscheck = Float::with_val(PREC, &d2_cls - &d2_direct);
        let crosscheck_str = crosscheck.to_string_radix(10, Some(10));

        // Print coefficients
        if n >= 200 {
            eprintln!("        d2_direct = {}", d2_direct.to_string_radix(10, Some(15)));
            eprintln!("        crosscheck (d2_cls - d2_direct) = {}", crosscheck_str);
            for (idx, &cls) in active_classes.iter().enumerate() {
                let c_str = c_cls[idx].to_string_radix(10, Some(15));
                eprintln!("        c[{}] ({:>4}, n={:3}) = {}",
                    cls, class_label(cls), class_count[cls], c_str);
            }
            eprintln!();
        }
    }

    eprintln!("══════════════════════════════════════════════════════════════════");
    eprintln!("  If d²(8cls) is ALWAYS > 0 with high precision:");
    eprintln!("    → The sign change at n≈500 was numerical noise");
    eprintln!("    → The 8-class witness IS converging to d²=0!");
    eprintln!("  If d²(8cls) genuinely goes negative:");
    eprintln!("    → The 8-class subspace overshoots → approach fails");
    eprintln!("══════════════════════════════════════════════════════════════════");
}
