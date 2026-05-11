#![allow(unused, dead_code, non_snake_case)]
use rayon::prelude::*;

// ══════════════════════════════════════════════════════════
// APPROACH 2: Ramanujan Sum Diagonalization
//
// Decompose Gram matrix using multiplicative structure,
// test eigenvalue predictions from Ramanujan-Fourier expansion.
// ══════════════════════════════════════════════════════════

fn frac_part(x: f64) -> f64 {
    x - x.floor()
}

fn gcd(a: usize, b: usize) -> usize {
    if b == 0 {
        a
    } else {
        gcd(b, a % b)
    }
}

fn euler_phi(n: usize) -> usize {
    let mut result = n;
    let mut m = n;
    let mut p = 2;
    while p * p <= m {
        if m % p == 0 {
            while m % p == 0 {
                m /= p;
            }
            result -= result / p;
        }
        p += 1;
    }
    if m > 1 {
        result -= result / m;
    }
    result
}

fn mobius(n: usize) -> i64 {
    if n == 1 {
        return 1;
    }
    let mut m = n;
    let mut num_factors = 0;
    let mut p = 2;
    while p * p <= m {
        if m % p == 0 {
            m /= p;
            num_factors += 1;
            if m % p == 0 {
                return 0;
            } // p² | n
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

fn von_mangoldt(n: usize) -> f64 {
    if n < 2 {
        return 0.0;
    }
    let mut m = n;
    let mut p = 2;
    while p * p <= m {
        if m % p == 0 {
            while m % p == 0 {
                m /= p;
            }
            return if m == 1 { (p as f64).ln() } else { 0.0 };
        }
        p += 1;
    }
    // n is prime
    (n as f64).ln()
}

/// Ramanujan sum c_q(n) = Σ_{d | gcd(q,n)} μ(q/d) · d
fn ramanujan_sum(q: usize, n: usize) -> i64 {
    let g = gcd(q, n);
    let mut sum: i64 = 0;
    let mut d = 1;
    while d * d <= g {
        if g % d == 0 {
            sum += mobius(q / d) * d as i64;
            if d != g / d {
                let d2 = g / d;
                if q % d2 == 0 {
                    sum += mobius(q / d2) * d2 as i64;
                }
            }
        }
        d += 1;
    }
    // Recompute properly
    sum = 0;
    for d in 1..=g {
        if g % d == 0 && q % d == 0 {
            sum += mobius(q / d) * d as i64;
        }
    }
    sum
}

fn inner_product(j: usize, k: usize, n_pts: usize) -> f64 {
    let jf = j as f64;
    let kf = k as f64;
    let dx = 1.0 / n_pts as f64;
    let mut sum = 0.0;
    for i in 1..n_pts {
        let x = i as f64 * dx;
        sum += frac_part(jf / x) * frac_part(kf / x);
    }
    sum * dx
}

fn main() {
    println!("═══════════════════════════════════════════════════════════════");
    println!("  APPROACH 2: Ramanujan Sum Diagonalization");
    println!("  Testing the multiplicative structure of G_N");
    println!("═══════════════════════════════════════════════════════════════");

    let max_n = 100;
    let n_int = 200_000;

    // ═══ Test 1: GCD decomposition ═══
    println!("\n[1/5] Verifying G[j,k] depends primarily on gcd(j,k)\n");
    println!(
        "  {:>4} {:>4} {:>4} {:>12} {:>12} {:>12}",
        "j", "k", "gcd", "G[j,k]", "G_coprime", "G[j,k]-G_cp"
    );

    // Compute a few entries and the "coprime baseline"
    let mut coprime_sum = 0.0;
    let mut coprime_count = 0;
    for j in 2..=20 {
        for k in (j + 1)..=20 {
            if gcd(j, k) == 1 {
                coprime_sum += inner_product(j, k, n_int);
                coprime_count += 1;
            }
        }
    }
    let c0 = coprime_sum / coprime_count as f64;
    println!("  Coprime baseline C₀ = {:.10}\n", c0);

    for j in 2..=12 {
        for k in j..=12 {
            let g = gcd(j, k);
            let val = inner_product(j, k, n_int);
            println!(
                "  {:4} {:4} {:4} {:12.8} {:12.8} {:12.8}",
                j,
                k,
                g,
                val,
                c0,
                val - c0
            );
        }
    }

    // ═══ Test 2: Ramanujan sums ═══
    println!("\n[2/5] Ramanujan sums c_q(n) for small q\n");
    println!(
        "  {:>3} {:>4} {:>4} {:>4} {:>4} {:>4} {:>4} {:>4} {:>4} {:>4} {:>4}",
        "q", "n=1", "2", "3", "4", "5", "6", "7", "8", "9", "10"
    );

    for q in 1..=12 {
        print!("  {:3}", q);
        for n in 1..=10 {
            print!(" {:4}", ramanujan_sum(q, n));
        }
        println!("  φ(q)={}", euler_phi(q));
    }

    // ═══ Test 3: Smith determinant test ═══
    println!("\n[3/5] Smith determinant: det(B) vs Π (B*μ)(k)\n");

    // B[j,k] = G[j,k] - C₀ (the GCD-dependent part)
    // For a pure GCD matrix M[j,k] = f(gcd(j,k)):
    //   det(M) = Π_{k=1}^N (f*μ)(k)

    for test_n in [5, 10, 15, 20] {
        let dim = test_n - 1;
        let mut mat = vec![vec![0.0; dim]; dim];
        for j in 0..dim {
            for k in j..dim {
                let val = inner_product(j + 2, k + 2, n_int);
                mat[j][k] = val;
                mat[k][j] = val;
            }
        }

        // Compute det via LU
        let mut lu = mat.clone();
        let _piv = lu_decompose(&mut lu);
        let det_val: f64 = (0..dim).map(|i| lu[i][i]).product();

        // Smith product for the pure GCD part
        // First extract f(g) = average G[j,k] over pairs with gcd = g
        let mut gcd_vals: std::collections::HashMap<usize, (f64, usize)> =
            std::collections::HashMap::new();
        for j in 0..dim {
            for k in 0..dim {
                let g = gcd(j + 2, k + 2);
                let e = gcd_vals.entry(g).or_insert((0.0, 0));
                e.0 += mat[j][k];
                e.1 += 1;
            }
        }

        println!("  N={:2}: det(G) = {:.6e}", test_n, det_val);
        println!("         GCD averages:");
        let mut gcd_keys: Vec<usize> = gcd_vals.keys().cloned().collect();
        gcd_keys.sort();
        for g in &gcd_keys[..gcd_keys.len().min(8)] {
            let (sum, count) = gcd_vals[g];
            println!(
                "           gcd={}: avg = {:.8} (count={})",
                g,
                sum / count as f64,
                count
            );
        }
        println!();
    }

    // ═══ Test 4: Ramanujan-Fourier coefficients of the Gram correction ═══
    println!("[4/5] Ramanujan-Fourier coefficients of G - C₀\n");

    let dim = max_n - 1;
    // Compute correction matrix B[j,k] = G[j,k] - C₀
    let gram: Vec<Vec<f64>> = (0..dim.min(60))
        .into_par_iter()
        .map(|j| {
            let mut row = vec![0.0; dim.min(60)];
            for k in 0..dim.min(60) {
                row[k] = inner_product(j + 2, k + 2, n_int) - c0;
            }
            row
        })
        .collect();

    // Compute α̂_q = (1/N²) Σ_{j,k} B[j,k] · c_q(j) · c_q(k) / φ(q)²
    println!(
        "  {:>4}  {:>14}  {:>14}  {:>14}  {:>8}",
        "q", "α̂_q", "Λ(q)/q", "α̂_q·q", "φ(q)"
    );

    let dim_s = dim.min(60);
    for q in 1..=30 {
        let phi_q = euler_phi(q);
        let mut sum = 0.0;
        for j in 0..dim_s {
            let cqj = ramanujan_sum(q, j + 2) as f64;
            for k in 0..dim_s {
                let cqk = ramanujan_sum(q, k + 2) as f64;
                sum += gram[j][k] * cqj * cqk;
            }
        }
        let alpha_q = sum / ((dim_s * dim_s) as f64 * (phi_q as f64).powi(2));
        let lambda_q = von_mangoldt(q) / q as f64;
        println!(
            "  {:4}  {:14.8}  {:14.8}  {:14.8}  {:8}",
            q,
            alpha_q,
            lambda_q,
            alpha_q * q as f64,
            phi_q
        );
    }

    // ═══ Test 5: Eigenvalue prediction ═══
    println!("\n[5/5] Eigenvalue prediction from Ramanujan expansion\n");

    // Compute actual eigenvalues for N = 30
    let test_dim = 28;
    let mut g30 = vec![vec![0.0; test_dim]; test_dim];
    for j in 0..test_dim {
        for k in j..test_dim {
            let val = inner_product(j + 2, k + 2, n_int);
            g30[j][k] = val;
            g30[k][j] = val;
        }
    }

    let actual_eigs = eigenvalues_sorted(&g30);
    println!("  Actual eigenvalues of G_30 (first 10 and last 3):");
    for i in 0..10.min(actual_eigs.len()) {
        println!("    λ_{} = {:.10}", i + 1, actual_eigs[i]);
    }
    println!("    ...");
    for i in (actual_eigs.len() - 3)..actual_eigs.len() {
        println!("    λ_{} = {:.10}", i + 1, actual_eigs[i]);
    }

    println!("\n═══════════════════════════════════════════════════════════════");
    println!("  Ramanujan analysis complete.");
    println!("═══════════════════════════════════════════════════════════════");
}

// ─── Linear algebra utilities ───

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

fn eigenvalues_sorted(mat: &[Vec<f64>]) -> Vec<f64> {
    let n = mat.len();
    let mut a = mat.to_vec();
    for _ in 0..n * n * 10 {
        let mut max_val = 0.0f64;
        let mut p = 0;
        let mut q = 1;
        for i in 0..n {
            for j in (i + 1)..n {
                if a[i][j].abs() > max_val {
                    max_val = a[i][j].abs();
                    p = i;
                    q = j;
                }
            }
        }
        if max_val < 1e-13 {
            break;
        }
        let theta = if (a[q][q] - a[p][p]).abs() < 1e-15 {
            std::f64::consts::PI / 4.0
        } else {
            0.5 * (2.0 * a[p][q] / (a[p][p] - a[q][q])).atan()
        };
        let (c, s) = (theta.cos(), theta.sin());
        let mut b = a.clone();
        for i in 0..n {
            if i != p && i != q {
                b[i][p] = c * a[i][p] + s * a[i][q];
                b[p][i] = b[i][p];
                b[i][q] = -s * a[i][p] + c * a[i][q];
                b[q][i] = b[i][q];
            }
        }
        b[p][p] = c * c * a[p][p] + 2.0 * s * c * a[p][q] + s * s * a[q][q];
        b[q][q] = s * s * a[p][p] - 2.0 * s * c * a[p][q] + c * c * a[q][q];
        b[p][q] = 0.0;
        b[q][p] = 0.0;
        a = b;
    }
    let mut eigs: Vec<f64> = (0..n).map(|i| a[i][i]).collect();
    eigs.sort_by(|a, b| a.partial_cmp(b).unwrap());
    eigs
}
