#![allow(unused, dead_code, non_snake_case)]
use rayon::prelude::*;

// ══════════════════════════════════════════════════════════
// APPROACH 1: Oscillation Orthogonality Verification
//
// Test the key claim: on (0, 1/N), fractional parts {k/x}
// are approximately orthogonal, giving λ_min ≥ c/N.
// ══════════════════════════════════════════════════════════

fn frac_part(x: f64) -> f64 {
    x - x.floor()
}

/// Compute ∫₀^{a} {j/x}·{k/x} dx  (localized inner product)
fn inner_product_localized(j: usize, k: usize, upper: f64, n_pts: usize) -> f64 {
    let jf = j as f64;
    let kf = k as f64;
    let dx = upper / n_pts as f64;
    let mut sum = 0.0;
    for i in 1..n_pts {
        let x = i as f64 * dx;
        sum += frac_part(jf / x) * frac_part(kf / x);
    }
    sum * dx
}

/// Compute ∫₀^{a} ({j/x} - 1/2)·({k/x} - 1/2) dx  (centered)
fn centered_inner_product(j: usize, k: usize, upper: f64, n_pts: usize) -> f64 {
    let jf = j as f64;
    let kf = k as f64;
    let dx = upper / n_pts as f64;
    let mut sum = 0.0;
    for i in 1..n_pts {
        let x = i as f64 * dx;
        let fj = frac_part(jf / x) - 0.5;
        let fk = frac_part(kf / x) - 0.5;
        sum += fj * fk;
    }
    sum * dx
}

fn main() {
    println!("═══════════════════════════════════════════════════════════════");
    println!("  APPROACH 1: Oscillation Orthogonality");
    println!("  Testing: Are {{k/x}} approximately orthogonal on (0, 1/N)?");
    println!("═══════════════════════════════════════════════════════════════");

    let n_pts = 2_000_000;

    // ═══ Test 1: Self-energy on (0, 1/N) ═══
    println!("\n[1/4] Self-energy: ∫₀^{{1/N}} {{k/x}}² dx vs 1/(12N)\n");
    println!(
        "  {:>4}  {:>4}  {:>14}  {:>14}  {:>10}",
        "N", "k", "∫{k/x}² dx", "1/(12N)", "ratio"
    );

    for n in [10, 20, 50, 100, 200, 500] {
        let upper = 1.0 / n as f64;
        let expected = 1.0 / (12.0 * n as f64);
        for k in [2, 3, 5, 10, n / 2, n] {
            if k < 2 || k > n {
                continue;
            }
            let energy = inner_product_localized(k, k, upper, n_pts);
            println!(
                "  {:4}  {:4}  {:14.10}  {:14.10}  {:10.4}",
                n,
                k,
                energy,
                expected,
                energy / expected
            );
        }
        println!();
    }

    // ═══ Test 2: Cross-correlations on (0, 1/N) ═══
    println!("[2/4] Cross-correlations: ∫₀^{{1/N}} ({{j/x}}-½)({{k/x}}-½) dx\n");
    println!(
        "  {:>4}  {:>4}  {:>4}  {:>14}  {:>14}  {:>10}",
        "N", "j", "k", "cross-corr", "bound C/(N·|j-k|)", "ratio"
    );

    for n in [20, 50, 100, 200] {
        let upper = 1.0 / n as f64;
        let mut max_ratio = 0.0f64;

        for j in 2..=n.min(20) {
            for k in (j + 1)..=n.min(20) {
                let cc = centered_inner_product(j, k, upper, n_pts);
                let bound = 1.0 / (n as f64 * (k - j) as f64);
                let ratio = cc.abs() / bound;
                max_ratio = max_ratio.max(ratio);
                if (k - j) <= 3 || (j <= 5 && k <= 10) {
                    println!(
                        "  {:4}  {:4}  {:4}  {:14.10}  {:14.10}  {:10.4}",
                        n, j, k, cc, bound, ratio
                    );
                }
            }
        }
        println!("  N={}: max |CC|/bound = {:.4}", n, max_ratio);
        println!();
    }

    // ═══ Test 3: Gram matrix eigenvalues on (0, 1/N) vs (0, 1) ═══
    println!("[3/4] Comparing Gram matrices: localized vs full\n");

    for n in [10, 20, 40, 80] {
        let upper = 1.0 / n as f64;
        let dim = n - 1;

        // Localized Gram matrix on (0, 1/N)
        let gram_loc: Vec<Vec<f64>> = (0..dim)
            .into_par_iter()
            .map(|j| {
                let mut row = vec![0.0; dim];
                for k in j..dim {
                    row[k] = inner_product_localized(j + 2, k + 2, upper, n_pts / 10);
                }
                row
            })
            .collect();

        // Full Gram matrix on (0, 1)
        let gram_full: Vec<Vec<f64>> = (0..dim)
            .into_par_iter()
            .map(|j| {
                let mut row = vec![0.0; dim];
                for k in j..dim {
                    row[k] = inner_product_localized(j + 2, k + 2, 1.0, n_pts / 10);
                }
                row
            })
            .collect();

        // Symmetrize
        let mut g_loc = vec![vec![0.0; dim]; dim];
        let mut g_full = vec![vec![0.0; dim]; dim];
        for j in 0..dim {
            for k in j..dim {
                g_loc[j][k] = gram_loc[j][k];
                g_loc[k][j] = gram_loc[j][k];
                g_full[j][k] = gram_full[j][k];
                g_full[k][j] = gram_full[j][k];
            }
        }

        let lmin_loc = inverse_iteration(&g_loc, 200);
        let lmin_full = inverse_iteration(&g_full, 200);
        let expected = 1.0 / (12.0 * n as f64);

        println!("  N={:3}: λ_min(loc) = {:.8}, λ_min(full) = {:.8}, 1/(12N) = {:.8}, loc/expected = {:.4}",
            n, lmin_loc, lmin_full, expected, lmin_loc / expected);
    }

    // ═══ Test 4: The key theorem — does (0,1/N) energy + (1/N,1) energy work? ═══
    println!("\n[4/4] Energy decomposition: (0,1/N) + (1/N,1)\n");
    println!(
        "  {:>4}  {:>14}  {:>14}  {:>14}  {:>10}",
        "N", "λ_min(0,1/N)", "λ_min(full)", "ratio", "1/(12N)"
    );

    for n in [10, 20, 30, 50, 80, 100, 150, 200] {
        let dim = (n - 1).min(80); // cap for performance
        let upper = 1.0 / n as f64;
        let pts = n_pts / 20;

        let gram_loc: Vec<Vec<f64>> = (0..dim)
            .into_par_iter()
            .map(|j| {
                let mut row = vec![0.0; dim];
                for k in j..dim {
                    row[k] = inner_product_localized(j + 2, k + 2, upper, pts);
                }
                row
            })
            .collect();

        let gram_full: Vec<Vec<f64>> = (0..dim)
            .into_par_iter()
            .map(|j| {
                let mut row = vec![0.0; dim];
                for k in j..dim {
                    row[k] = inner_product_localized(j + 2, k + 2, 1.0, pts);
                }
                row
            })
            .collect();

        let mut g_l = vec![vec![0.0; dim]; dim];
        let mut g_f = vec![vec![0.0; dim]; dim];
        for j in 0..dim {
            for k in j..dim {
                g_l[j][k] = gram_loc[j][k];
                g_l[k][j] = gram_loc[j][k];
                g_f[j][k] = gram_full[j][k];
                g_f[k][j] = gram_full[j][k];
            }
        }

        let lmin_l = inverse_iteration(&g_l, 200);
        let lmin_f = inverse_iteration(&g_f, 200);
        let expected = 1.0 / (12.0 * n as f64);
        println!(
            "  {:4}  {:14.10}  {:14.10}  {:10.4}  {:10.8}",
            n,
            lmin_l,
            lmin_f,
            lmin_f / lmin_l,
            expected
        );
    }

    println!("\n═══════════════════════════════════════════════════════════════");
    println!("  Oscillation analysis complete.");
    println!("═══════════════════════════════════════════════════════════════");
}

// ─── Eigenvalue utilities ───

fn lu_decompose(a: &mut [Vec<f64>]) -> Vec<usize> {
    let n = a.len();
    let mut piv: Vec<usize> = (0..n).collect();
    for col in 0..n {
        let mut max_row = col;
        for row in (col + 1)..n {
            if a[row][col].abs() > a[max_row][col].abs() {
                max_row = row;
            }
        }
        if max_row != col {
            a.swap(col, max_row);
            piv.swap(col, max_row);
        }
        if a[col][col].abs() < 1e-15 {
            continue;
        }
        for row in (col + 1)..n {
            a[row][col] /= a[col][col];
            let f = a[row][col];
            for j in (col + 1)..n {
                a[row][j] -= f * a[col][j];
            }
        }
    }
    piv
}

fn lu_solve(lu: &[Vec<f64>], piv: &[usize], b: &[f64]) -> Vec<f64> {
    let n = b.len();
    let mut x: Vec<f64> = piv.iter().map(|&i| b[i]).collect();
    for i in 1..n {
        for j in 0..i {
            let f = lu[i][j];
            x[i] -= f * x[j];
        }
    }
    for i in (0..n).rev() {
        for j in (i + 1)..n {
            x[i] -= lu[i][j] * x[j];
        }
        x[i] /= lu[i][i];
    }
    x
}

fn inverse_iteration(mat: &[Vec<f64>], n_iter: usize) -> f64 {
    let n = mat.len();
    if n == 0 {
        return 0.0;
    }
    let mut lu = mat.to_vec();
    let piv = lu_decompose(&mut lu);
    let mut v = vec![1.0 / (n as f64).sqrt(); n];
    for _ in 0..n_iter {
        let w = lu_solve(&lu, &piv, &v);
        let norm: f64 = w.iter().map(|x| x * x).sum::<f64>().sqrt();
        if norm < 1e-15 {
            break;
        }
        v = w.iter().map(|x| x / norm).collect();
    }
    let mut w = vec![0.0; n];
    for i in 0..n {
        for j in 0..n {
            w[i] += mat[i][j] * v[j];
        }
    }
    let vav: f64 = v.iter().zip(w.iter()).map(|(a, b)| a * b).sum();
    let vv: f64 = v.iter().map(|x| x * x).sum::<f64>();
    vav / vv
}
