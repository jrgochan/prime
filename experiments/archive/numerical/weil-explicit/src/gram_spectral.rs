#![allow(unused, dead_code, non_snake_case)]
use std::f64::consts::PI;

// ══════════════════════════════════════════════════════════
// PROJECT HYPERZETA: Gram Matrix Spectral Analysis
//
// Study the eigenvalue structure of the Nyman-Beurling
// Gram matrix G[j][k] = ⟨{j/·}, {k/·}⟩ in L²(0,1)
//
// Key question: How does λ_min(G_N) scale with N?
// If λ_min ~ N^{-1+ε} → RH follows!
// ══════════════════════════════════════════════════════════

fn frac_part(x: f64) -> f64 { x - x.floor() }

/// High-precision inner product ⟨{j/x}, {k/x}⟩ in L²(0,1)
/// Uses adaptive integration with more points near x = 0
fn inner_product_hp(j: usize, k: usize, n_points: usize) -> f64 {
    // Split [0,1] into [0, 1/max(j,k)] and [1/max(j,k), 1]
    // The first interval has the most oscillations
    let m = j.max(k);
    let split = 1.0 / m as f64;

    let n1 = (n_points as f64 * 0.7) as usize; // 70% of points in oscillatory region
    let n2 = n_points - n1;

    let mut sum = 0.0;

    // Region 1: (0, split] — fine mesh
    if n1 > 0 {
        let dx1 = split / n1 as f64;
        for i in 1..=n1 {
            let x = i as f64 * dx1;
            sum += frac_part(j as f64 / x) * frac_part(k as f64 / x) * dx1;
        }
    }

    // Region 2: (split, 1] — coarser mesh
    if n2 > 0 {
        let dx2 = (1.0 - split) / n2 as f64;
        for i in 1..=n2 {
            let x = split + i as f64 * dx2;
            sum += frac_part(j as f64 / x) * frac_part(k as f64 / x) * dx2;
        }
    }

    sum
}

/// Inner product ⟨1, {k/x}⟩ in L²(0,1)
fn inner_with_one(k: usize, n_points: usize) -> f64 {
    let dx = 1.0 / n_points as f64;
    let mut sum = 0.0;
    for i in 1..n_points {
        let x = i as f64 * dx;
        sum += frac_part(k as f64 / x);
    }
    sum * dx
}

/// Jacobi eigenvalue algorithm for symmetric matrices
fn eigenvalues(mat: &[Vec<f64>]) -> Vec<f64> {
    let n = mat.len();
    let mut a = mat.to_vec();
    for _ in 0..5000 {
        let mut max_val = 0.0f64;
        let mut p = 0;
        let mut q = 1;
        for i in 0..n {
            for j in (i+1)..n {
                if a[i][j].abs() > max_val {
                    max_val = a[i][j].abs();
                    p = i; q = j;
                }
            }
        }
        if max_val < 1e-14 { break; }
        let theta = if (a[q][q] - a[p][p]).abs() < 1e-15 {
            PI / 4.0
        } else {
            0.5 * (2.0 * a[p][q] / (a[p][p] - a[q][q])).atan()
        };
        let c = theta.cos();
        let s = theta.sin();
        let mut new_a = a.clone();
        for i in 0..n {
            if i != p && i != q {
                new_a[i][p] = c * a[i][p] + s * a[i][q];
                new_a[p][i] = new_a[i][p];
                new_a[i][q] = -s * a[i][p] + c * a[i][q];
                new_a[q][i] = new_a[i][q];
            }
        }
        new_a[p][p] = c*c*a[p][p] + 2.0*s*c*a[p][q] + s*s*a[q][q];
        new_a[q][q] = s*s*a[p][p] - 2.0*s*c*a[p][q] + c*c*a[q][q];
        new_a[p][q] = 0.0; new_a[q][p] = 0.0;
        a = new_a;
    }
    let mut eigs: Vec<f64> = (0..n).map(|i| a[i][i]).collect();
    eigs.sort_by(|a, b| a.partial_cmp(b).unwrap());
    eigs
}

fn gcd(a: usize, b: usize) -> usize {
    if b == 0 { a } else { gcd(b, a % b) }
}

fn main() {
    println!("═══════════════════════════════════════════════════════════════");
    println!("  PROJECT HYPERZETA: Gram Matrix Spectral Analysis");
    println!("  Goal: Understand eigenvalue scaling of G_N");
    println!("═══════════════════════════════════════════════════════════════");

    let n_int = 200_000; // integration points for accuracy
    let max_n = 80; // max matrix size

    // Phase 1: Build and analyze Gram matrices of increasing size
    println!("\n[1/3] Computing Gram matrices up to N = {}...", max_n);
    println!("  Integration: {} points (adaptive)\n", n_int);

    let dim = max_n - 1; // indices 2..max_n
    let mut gram = vec![vec![0.0; dim]; dim];
    let mut rhs = vec![0.0; dim];

    // Precompute the full Gram matrix
    let start = std::time::Instant::now();
    for j in 0..dim {
        rhs[j] = inner_with_one(j + 2, n_int);
        for k in j..dim {
            let val = inner_product_hp(j + 2, k + 2, n_int);
            gram[j][k] = val;
            gram[k][j] = val;
        }
        if (j + 1) % 20 == 0 {
            println!("  Row {}/{} done ({:.1}s)", j + 1, dim, start.elapsed().as_secs_f64());
        }
    }
    println!("  Full Gram matrix computed in {:.1}s", start.elapsed().as_secs_f64());

    // Phase 2: Eigenvalue analysis at each size
    println!("\n[2/3] ═══ Eigenvalue Scaling Analysis ═══\n");
    println!("  {:>4}  {:>14}  {:>14}  {:>14}  {:>14}  {:>8}",
        "N", "λ_min", "λ₂", "λ_max", "κ (cond#)", "d_N²");

    let mut min_eigs = Vec::new();
    let mut sizes = Vec::new();

    for n in (2..=max_n).step_by(1) {
        let dim_n = n - 1;
        if dim_n > dim { break; }

        let sub: Vec<Vec<f64>> = gram[..dim_n].iter()
            .map(|row| row[..dim_n].to_vec()).collect();

        let eigs = eigenvalues(&sub);
        let lambda_min = eigs[0];
        let lambda_2 = if eigs.len() > 1 { eigs[1] } else { eigs[0] };
        let lambda_max = eigs[eigs.len() - 1];
        let cond = if lambda_min.abs() > 1e-15 { lambda_max / lambda_min } else { f64::INFINITY };

        // Compute d_N²
        let sub_rhs: Vec<f64> = rhs[..dim_n].to_vec();
        let d_sq = if lambda_min > 1e-15 {
            // d_N² = 1 - b^T G^{-1} b via solving Gx = b
            let mut aug: Vec<Vec<f64>> = sub.iter().enumerate().map(|(i, row)| {
                let mut r = row.clone();
                r.push(sub_rhs[i]);
                r
            }).collect();
            // Gaussian elimination
            for col in 0..dim_n {
                let mut max_row = col;
                for row in (col+1)..dim_n {
                    if aug[row][col].abs() > aug[max_row][col].abs() { max_row = row; }
                }
                aug.swap(col, max_row);
                if aug[col][col].abs() < 1e-15 { break; }
                for row in (col+1)..dim_n {
                    let f = aug[row][col] / aug[col][col];
                    for j in col..=dim_n { aug[row][j] -= f * aug[col][j]; }
                }
            }
            let mut x = vec![0.0; dim_n];
            for i in (0..dim_n).rev() {
                x[i] = aug[i][dim_n];
                for j in (i+1)..dim_n { x[i] -= aug[i][j] * x[j]; }
                x[i] /= aug[i][i];
            }
            let btginvb: f64 = x.iter().zip(sub_rhs.iter()).map(|(c,r)| c*r).sum();
            (1.0 - btginvb).max(0.0)
        } else { f64::NAN };

        if n <= 30 || n % 5 == 0 {
            println!("  {:4}  {:14.10}  {:14.10}  {:14.6}  {:14.2}  {:8.6}",
                n, lambda_min, lambda_2, lambda_max, cond, d_sq);
        }

        if lambda_min > 0.0 {
            min_eigs.push(lambda_min);
            sizes.push(n as f64);
        }
    }

    // Phase 3: Fit the scaling law
    println!("\n[3/3] ═══ Scaling Law Fit: λ_min ~ C · N^{{-α}} ═══\n");

    if min_eigs.len() >= 10 {
        // Use log-log linear regression on the last half of data
        let start_idx = min_eigs.len() / 2;
        let n_fit = min_eigs.len() - start_idx;

        let mut sum_x = 0.0;
        let mut sum_y = 0.0;
        let mut sum_xx = 0.0;
        let mut sum_xy = 0.0;

        for i in start_idx..min_eigs.len() {
            let x = sizes[i].ln();
            let y = min_eigs[i].ln();
            sum_x += x;
            sum_y += y;
            sum_xx += x * x;
            sum_xy += x * y;
        }

        let nf = n_fit as f64;
        let alpha = -(nf * sum_xy - sum_x * sum_y) / (nf * sum_xx - sum_x * sum_x);
        let log_c = (sum_y + alpha * sum_x) / nf;
        let c = log_c.exp();

        println!("  Best fit: λ_min(N) ≈ {:.6} · N^{{-{:.4}}}", c, alpha);
        println!();

        // Check predictions
        println!("  {:>6}  {:>14}  {:>14}  {:>10}", "N", "actual λ_min", "predicted", "ratio");
        for i in (min_eigs.len().saturating_sub(10))..min_eigs.len() {
            let predicted = c * sizes[i].powf(-alpha);
            println!("  {:6.0}  {:14.10}  {:14.10}  {:10.4}",
                sizes[i], min_eigs[i], predicted, min_eigs[i] / predicted);
        }

        println!("\n  ═══ INTERPRETATION ═══");
        if alpha < 1.0 {
            println!("  α = {:.4} < 1.0", alpha);
            println!("  ⟹ λ_min decays SLOWER than 1/N");
            println!("  ⟹ d_N² could still → 0 (consistent with RH)");
        } else if alpha < 2.0 {
            println!("  α = {:.4}, between 1.0 and 2.0", alpha);
            println!("  ⟹ λ_min decays like N^{{-{:.2}}}", alpha);
            println!("  ⟹ Gram matrix conditioning grows, but d_N might still → 0");
        } else {
            println!("  α = {:.4} ≥ 2.0", alpha);
            println!("  ⟹ λ_min decays very fast — potential issue for convergence");
        }
    }

    // Phase 4: GCD structure analysis
    println!("\n  ═══ GCD Structure ═══");
    println!("  The Gram matrix has a multiplicative structure from gcd(j,k):");
    println!("  For small N, showing G[j][k] vs gcd(j,k):\n");
    println!("  {:>4} {:>4} {:>8} {:>12}", "j", "k", "gcd", "G[j][k]");
    for j in 2..=8 {
        for k in j..=8 {
            let g = gcd(j, k);
            println!("  {:4} {:4} {:8} {:12.8}", j, k, g, gram[j-2][k-2]);
        }
    }

    println!("\n═══════════════════════════════════════════════════════════════");
    println!("  Spectral analysis complete.");
    println!("═══════════════════════════════════════════════════════════════");
}
