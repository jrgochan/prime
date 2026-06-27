#![allow(unused, dead_code)]
//! Octonionic Witness Experiment (v2 - fixed)
//!
//! Tests whether the optimal witness v = G⁻¹b clusters by octonionic class.
//! If yes, this reduces RH to a small finite-dimensional problem.
//!
//! Usage: cargo run --release --bin oct_witness [sizes...]
//! Default sizes: 50 100 150 200 250

use offdiag_excess::{fract_integral, gram_entry};
use rayon::prelude::*;

/// Smallest prime factor of n
fn min_prime_factor(n: usize) -> usize {
    if n <= 1 {
        return 1;
    }
    if n.is_multiple_of(2) {
        return 2;
    }
    let mut p = 3;
    while p * p <= n {
        if n.is_multiple_of(p) {
            return p;
        }
        p += 2;
    }
    n
}

/// Octonionic class: maps integer k ≥ 2 to class 0..7
fn octonion_class(k: usize) -> usize {
    match min_prime_factor(k) {
        2 => 0, // even numbers
        3 => 1, // multiples of 3
        5 => 2, // multiples of 5
        7 => 3, // multiples of 7
        11 => 4,
        13 => 5,
        17 => 6,
        _ => 7, // primes ≥ 19 and their exclusive multiples
    }
}

fn class_label(cls: usize) -> &'static str {
    match cls {
        0 => "even",
        1 => "3|k",
        2 => "5|k",
        3 => "7|k",
        4 => "11|k",
        5 => "13|k",
        6 => "17|k",
        7 => "≥19",
        _ => "?",
    }
}

/// Solve Ax = b with LU + iterative refinement
fn solve_refined(a: &[Vec<f64>], b: &[f64], refinements: usize) -> (Vec<f64>, f64) {
    let n = b.len();
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
                let f = lu[row][col];
                let v = lu[col][j];
                lu[row][j] -= f * v;
            }
        }
    }

    let solve_lu = |rhs: &[f64]| -> Vec<f64> {
        let mut y = vec![0.0; n];
        for i in 0..n {
            y[i] = rhs[perm[i]];
        }
        for i in 0..n {
            for j in 0..i {
                y[i] -= lu[i][j] * y[j];
            }
        }
        for i in (0..n).rev() {
            for j in (i + 1)..n {
                y[i] -= lu[i][j] * y[j];
            }
            if lu[i][i].abs() > 1e-20 {
                y[i] /= lu[i][i];
            } else {
                y[i] = 0.0;
            }
        }
        y
    };

    let mut x = solve_lu(b);
    for _ in 0..refinements {
        let mut res = vec![0.0; n];
        for i in 0..n {
            res[i] = b[i] - (0..n).map(|j| a[i][j] * x[j]).sum::<f64>();
        }
        let dx = solve_lu(&res);
        for i in 0..n {
            x[i] += dx[i];
        }
    }

    let diag_max = (0..n).map(|i| lu[i][i].abs()).fold(0.0_f64, f64::max);
    let diag_min = (0..n).map(|i| lu[i][i].abs()).fold(f64::INFINITY, f64::min);
    let cond = if diag_min > 0.0 {
        diag_max / diag_min
    } else {
        f64::INFINITY
    };
    (x, cond)
}

fn main() {
    let sizes: Vec<usize> = std::env::args()
        .skip(1)
        .filter_map(|s| s.parse().ok())
        .collect();
    let sizes = if sizes.is_empty() {
        vec![50, 100, 150, 200, 250]
    } else {
        sizes
    };

    eprintln!("══════════════════════════════════════════════════════════════════");
    eprintln!("  Octonionic Witness Experiment v2");
    eprintln!("  Does G⁻¹b cluster by class? Does 8-param witness beat const?");
    eprintln!("══════════════════════════════════════════════════════════════════\n");

    // Summary table
    eprintln!(
        "{:>5} {:>10} {:>10} {:>10} {:>8} {:>10} {:>8}",
        "n", "d2(const)", "d2(8cls)", "d2(opt)", "R²", "8/const", "time"
    );
    eprintln!("{}", "-".repeat(68));

    for &n in &sizes {
        let start = std::time::Instant::now();
        let dim = n;

        // Build Gram matrix with index-2 start: {2/x}, ..., {(n+1)/x}
        let b: Vec<f64> = (0..dim).map(|i| fract_integral(i + 2)).collect();
        let g: Vec<Vec<f64>> = (0..dim)
            .into_par_iter()
            .map(|i| (0..dim).map(|j| gram_entry(i + 2, j + 2)).collect())
            .collect();

        // Classify each index
        let classes: Vec<usize> = (0..dim).map(|i| octonion_class(i + 2)).collect();

        // Find which classes are actually populated
        let mut active_classes: Vec<usize> = Vec::new();
        let mut class_count = [0usize; 8];
        for &c in &classes {
            class_count[c] += 1;
        }
        for c in 0..8 {
            if class_count[c] > 0 {
                active_classes.push(c);
            }
        }
        let nc = active_classes.len();

        // ═══ OPTIMAL WITNESS (N-dimensional) ═══
        let (v_opt, cond) = solve_refined(&g, &b, 10);
        let btginvb: f64 = b.iter().zip(v_opt.iter()).map(|(a, b)| a * b).sum();
        let d2_opt = 1.0 - btginvb;

        // ═══ CONSTANT WITNESS (1-dimensional) ═══
        let b_sum: f64 = b.iter().sum();
        let g_sum: f64 = g.iter().map(|row| row.iter().sum::<f64>()).sum();
        let c_const = b_sum / g_sum;
        let d2_const = 1.0 - 2.0 * c_const * b_sum + c_const * c_const * g_sum;

        // ═══ CLASS-AVERAGED WITNESS (nc-dimensional) ═══
        // Build nc×nc class-level Gram matrix
        let mut g_cls = vec![vec![0.0; nc]; nc];
        let mut b_cls = vec![0.0; nc];

        // Map active_classes[ci_idx] -> ci_idx
        let mut class_to_idx = [0usize; 8];
        for (idx, &c) in active_classes.iter().enumerate() {
            class_to_idx[c] = idx;
        }

        for i in 0..dim {
            let ci = class_to_idx[classes[i]];
            b_cls[ci] += b[i];
            for j in 0..dim {
                let cj = class_to_idx[classes[j]];
                g_cls[ci][cj] += g[i][j];
            }
        }

        // Solve nc×nc system
        let (c_cls, _) = solve_refined(&g_cls, &b_cls, 5);

        // Build class witness and compute d²
        let v_cls: Vec<f64> = (0..dim).map(|i| c_cls[class_to_idx[classes[i]]]).collect();
        let btv: f64 = b.iter().zip(v_cls.iter()).map(|(a, b)| a * b).sum();
        let vtgv: f64 = (0..dim)
            .map(|i| v_cls[i] * (0..dim).map(|j| g[i][j] * v_cls[j]).sum::<f64>())
            .sum();
        // Direct d² (not optimally scaled — the class solve already gives the right scale)
        let d2_cls_direct = 1.0 - 2.0 * btv + vtgv;
        // Optimally scaled for safety
        let d2_cls = if vtgv > 1e-15 {
            (1.0 - btv * btv / vtgv).min(d2_cls_direct)
        } else {
            d2_cls_direct
        };

        // ═══ R² ANALYSIS ═══
        let global_mean: f64 = v_opt.iter().sum::<f64>() / dim as f64;
        let total_var: f64 = v_opt.iter().map(|v| (v - global_mean).powi(2)).sum::<f64>();

        let mut between_var = 0.0;
        for &cls in &active_classes {
            let indices: Vec<usize> = (0..dim).filter(|&i| classes[i] == cls).collect();
            let mean: f64 = indices.iter().map(|&i| v_opt[i]).sum::<f64>() / indices.len() as f64;
            between_var += (mean - global_mean).powi(2) * indices.len() as f64;
        }
        let r_squared = if total_var > 1e-20 {
            between_var / total_var
        } else {
            0.0
        };

        let ratio = if d2_cls.abs() > 1e-15 {
            d2_const / d2_cls
        } else {
            0.0
        };
        let elapsed = start.elapsed();

        eprintln!(
            "{:5} {:10.6} {:10.6} {:10.6} {:8.4} {:10.2} {:8.1}s",
            n,
            d2_const,
            d2_cls,
            d2_opt,
            r_squared,
            ratio,
            elapsed.as_secs_f64()
        );

        // Detailed output for this N
        if n >= 100 || sizes.len() == 1 {
            eprintln!(
                "        cond={:.1e}, nc={}, classes=[{}]",
                cond,
                nc,
                active_classes
                    .iter()
                    .map(|c| format!("{}:{}", class_label(*c), class_count[*c]))
                    .collect::<Vec<_>>()
                    .join(", ")
            );

            // Class analysis of optimal witness
            eprintln!("        ── v_opt by class ──");
            for &cls in &active_classes {
                let indices: Vec<usize> = (0..dim).filter(|&i| classes[i] == cls).collect();
                let vals: Vec<f64> = indices.iter().map(|&i| v_opt[i]).collect();
                let mean: f64 = vals.iter().sum::<f64>() / vals.len() as f64;
                let std: f64 = (vals.iter().map(|v| (v - mean).powi(2)).sum::<f64>()
                    / vals.len() as f64)
                    .sqrt();
                let cv = if mean.abs() > 1e-10 {
                    std / mean.abs() * 100.0
                } else {
                    f64::INFINITY
                };
                eprintln!(
                    "        {:>5} (n={:3}): mean={:+.6}, std={:.6}, CV={:.0}%",
                    class_label(cls),
                    indices.len(),
                    mean,
                    std,
                    cv
                );
            }

            // Class witness coefficients
            eprintln!("        ── 8-class coefficients ──");
            for (idx, &cls) in active_classes.iter().enumerate() {
                eprintln!(
                    "        c[{}] = {:+.8} ({}, n={})",
                    cls,
                    c_cls[idx],
                    class_label(cls),
                    class_count[cls]
                );
            }
            eprintln!();
        }
    }

    eprintln!("══════════════════════════════════════════════════════════════════");
    eprintln!("  INTERPRETATION:");
    eprintln!("  - R² > 0.5: v_opt has significant class structure");
    eprintln!("  - d2(8cls) << d2(const): class decomposition captures real info");
    eprintln!("  - d2(8cls) → 0: RH reduces to 8-parameter problem!");
    eprintln!("══════════════════════════════════════════════════════════════════");
}
