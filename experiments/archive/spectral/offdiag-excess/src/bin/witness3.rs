#![allow(unused, dead_code)]
//! Witness v3: More robust optimal witness with condition number tracking
//!
//! Uses iterative refinement for better numerical stability.

use offdiag_excess::{fract_integral, gram_entry};
use rayon::prelude::*;

fn moebius(n: usize) -> i32 {
    if n <= 1 {
        return n as i32;
    }
    let mut m = n;
    let mut nf = 0;
    let mut p = 2;
    while p * p <= m {
        if m % p == 0 {
            nf += 1;
            m /= p;
            if m % p == 0 {
                return 0;
            }
        }
        p += 1;
    }
    if m > 1 {
        nf += 1;
    }
    if nf % 2 == 0 {
        1
    } else {
        -1
    }
}

/// Solve via LU with iterative refinement
fn solve_refined(a: &[Vec<f64>], b: &[f64], iters: usize) -> (Vec<f64>, f64) {
    let n = b.len();

    // LU decomposition with partial pivoting
    let mut lu: Vec<Vec<f64>> = a.to_vec();
    let mut perm: Vec<usize> = (0..n).collect();

    for col in 0..n {
        let mut max_row = col;
        for row in (col + 1)..n {
            if lu[row][col].abs() > lu[max_row][col].abs() {
                max_row = row;
            }
        }
        lu.swap(col, max_row);
        perm.swap(col, max_row);

        let pivot = lu[col][col];
        if pivot.abs() < 1e-20 {
            continue;
        }
        for row in (col + 1)..n {
            lu[row][col] /= pivot;
            for j in (col + 1)..n {
                let factor = lu[row][col];
                let val = lu[col][j];
                lu[row][j] -= factor * val;
            }
        }
    }

    // Forward-back solve
    let solve_lu = |rhs: &[f64]| -> Vec<f64> {
        let mut y = vec![0.0; n];
        for i in 0..n {
            y[i] = rhs[perm[i]];
        }
        // Forward (L)
        for i in 0..n {
            for j in 0..i {
                y[i] -= lu[i][j] * y[j];
            }
        }
        // Backward (U)
        for i in (0..n).rev() {
            for j in (i + 1)..n {
                y[i] -= lu[i][j] * y[j];
            }
            y[i] /= lu[i][i];
        }
        y
    };

    let mut x = solve_lu(b);

    // Iterative refinement
    for _ in 0..iters {
        let mut residual = vec![0.0; n];
        for i in 0..n {
            let ax_i: f64 = (0..n).map(|j| a[i][j] * x[j]).sum();
            residual[i] = b[i] - ax_i;
        }
        let correction = solve_lu(&residual);
        for i in 0..n {
            x[i] += correction[i];
        }
    }

    // Estimate condition: ratio of max/min diagonal of U
    let diag_max = (0..n).map(|i| lu[i][i].abs()).fold(0.0_f64, f64::max);
    let diag_min = (0..n).map(|i| lu[i][i].abs()).fold(f64::INFINITY, f64::min);
    let cond_est = if diag_min > 0.0 {
        diag_max / diag_min
    } else {
        f64::INFINITY
    };

    (x, cond_est)
}

fn main() {
    let sizes: Vec<usize> = std::env::args()
        .skip(1)
        .filter_map(|s| s.parse().ok())
        .collect();
    let sizes = if sizes.is_empty() {
        vec![10, 20, 30, 50, 75, 100, 125, 150, 175, 200, 250, 300]
    } else {
        sizes
    };

    eprintln!("═══════════════════════════════════════════════════════════════════");
    eprintln!("  Witness Experiment v3 (indices 2..n+1, iterative refinement)");
    eprintln!("═══════════════════════════════════════════════════════════════════\n");

    eprintln!(
        "{:>5} {:>10} {:>10} {:>10} {:>12} {:>8}",
        "n", "Constant", "Möbius", "Optimal", "CondEst", "time"
    );
    eprintln!("{}", "-".repeat(60));

    for &n in &sizes {
        let start = std::time::Instant::now();
        let dim = n;

        // Build Gram matrix with index-2 start
        let b: Vec<f64> = (0..dim).map(|i| fract_integral(i + 2)).collect();
        let g: Vec<Vec<f64>> = (0..dim)
            .into_par_iter()
            .map(|i| (0..dim).map(|j| gram_entry(i + 2, j + 2)).collect())
            .collect();

        // Constant witness (optimally scaled)
        let b_sum: f64 = b.iter().sum();
        let g_sum: f64 = g.iter().map(|row| row.iter().sum::<f64>()).sum();
        let c_opt = b_sum / g_sum;
        let d2_const = 1.0 - 2.0 * c_opt * b_sum + c_opt * c_opt * g_sum;

        // Möbius witness (optimally scaled)
        let v_mob: Vec<f64> = (0..dim)
            .map(|i| moebius(i + 2) as f64 / (i + 2) as f64)
            .collect();
        let btv: f64 = b.iter().zip(v_mob.iter()).map(|(a, b)| a * b).sum();
        let vtgv: f64 = (0..dim)
            .map(|i| v_mob[i] * (0..dim).map(|j| g[i][j] * v_mob[j]).sum::<f64>())
            .sum();
        let d2_mob = if vtgv.abs() > 1e-15 {
            1.0 - btv * btv / vtgv
        } else {
            1.0
        };

        // Optimal witness with refinement
        let (v_opt, cond) = solve_refined(&g, &b, 5);
        let btginvb: f64 = b.iter().zip(v_opt.iter()).map(|(a, b)| a * b).sum();
        let d2_opt = 1.0 - btginvb;

        let elapsed = start.elapsed();

        eprintln!(
            "{:5} {:10.6} {:10.6} {:10.6} {:12.1e} {:8.1}s",
            n,
            d2_const,
            d2_mob,
            d2_opt,
            cond,
            elapsed.as_secs_f64()
        );
    }
}
