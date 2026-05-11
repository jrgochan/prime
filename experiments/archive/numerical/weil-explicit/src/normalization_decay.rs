#![allow(unused, dead_code, non_snake_case)]
use rayon::prelude::*;

// ══════════════════════════════════════════════════════════
// NORMALIZATION DECAY ANALYSIS
//
// Key question: How do v_min entries at FIXED k change as N grows?
// Observed: v_min[2] ∝ N^{-0.31}. But WHY?
//
// We track:
// 1. v_min[k] vs N for fixed k = 2,3,5,6,10,12,20,30
// 2. Energy distribution: where does ||v||² concentrate?
// 3. How does the "support" of v_min expand with N?
// 4. The precise decay exponent at each fixed k
// ══════════════════════════════════════════════════════════

fn frac_part(x: f64) -> f64 {
    x - x.floor()
}

fn gram_entry(j: usize, k: usize, n_pts: usize) -> f64 {
    let jf = j as f64;
    let kf = k as f64;
    let dx = 1.0 / n_pts as f64;
    let mut sum = 0.0f64;
    for i in 0..n_pts {
        let x = (i as f64 + 0.5) * dx;
        sum += frac_part(jf / x) * frac_part(kf / x);
    }
    sum * dx
}

fn lu_decompose(a: &mut Vec<Vec<f64>>) -> Vec<usize> {
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

fn smallest_eigenvector(mat: &[Vec<f64>], n_iter: usize) -> (f64, Vec<f64>) {
    let n = mat.len();
    if n == 1 {
        return (mat[0][0], vec![1.0]);
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
    // Ensure consistent sign
    let sign = if v[0] >= 0.0 { 1.0 } else { -1.0 };
    let v_signed: Vec<f64> = v.iter().map(|x| x * sign).collect();
    let mut w = vec![0.0; n];
    for i in 0..n {
        for j in 0..n {
            w[i] += mat[i][j] * v_signed[j];
        }
    }
    let lam: f64 = v_signed.iter().zip(w.iter()).map(|(a, b)| a * b).sum();
    (lam, v_signed)
}

fn main() {
    println!("═══════════════════════════════════════════════════════════════");
    println!("  NORMALIZATION DECAY ANALYSIS");
    println!("  How does v_min redistribute energy as N grows?");
    println!("═══════════════════════════════════════════════════════════════");

    let n_pts = 200_000;
    let max_n: usize = 1000;
    let start = std::time::Instant::now();

    // Phase 1: Compute Gram matrix
    println!(
        "\n[1/4] Computing {}×{} Gram matrix...",
        max_n - 1,
        max_n - 1
    );
    let dim = max_n - 1;
    let gram_upper: Vec<Vec<f64>> = (0..dim)
        .into_par_iter()
        .map(|j| {
            let mut row = vec![0.0; dim];
            for k in j..dim {
                row[k] = gram_entry(j + 2, k + 2, n_pts);
            }
            row
        })
        .collect();
    let mut gram = vec![vec![0.0; dim]; dim];
    for j in 0..dim {
        for k in j..dim {
            gram[j][k] = gram_upper[j][k];
            gram[k][j] = gram_upper[j][k];
        }
    }
    println!("  Done in {:.1}s", start.elapsed().as_secs_f64());

    // Phase 2: Track v_min[k] at FIXED k as N varies
    println!("\n[2/4] Fixed-k tracking...\n");

    let fixed_ks: Vec<usize> = vec![2, 3, 5, 6, 10, 12, 20, 30, 60];
    let n_values: Vec<usize> = (0..20)
        .map(|i| 30 + i * 50)
        .filter(|&n| n <= max_n)
        .collect();

    // Print header
    print!("  {:>5}", "N");
    for &k in &fixed_ks {
        print!(" {:>10}", format!("v[{}]", k));
    }
    println!(" {:>10} {:>10}", "λ_min", "||v||_eff");
    println!();

    let mut fixed_k_data: Vec<(usize, Vec<f64>, f64)> = Vec::new();

    for &n in &n_values {
        let d = n - 1;
        if d < 2 {
            continue;
        }
        let sub: Vec<Vec<f64>> = gram[..d].iter().map(|r| r[..d].to_vec()).collect();
        let (lam, v) = smallest_eigenvector(&sub, 500);

        print!("  {:5}", n);
        let mut vals = Vec::new();
        for &k in &fixed_ks {
            if k - 2 < v.len() {
                let val = v[k - 2];
                print!(" {:10.6}", val);
                vals.push(val);
            } else {
                print!(" {:>10}", "—");
                vals.push(0.0);
            }
        }

        // Effective dimension: 1/Σv[k]^4  (participation ratio)
        let pr: f64 = 1.0 / v.iter().map(|x| x.powi(4)).sum::<f64>();
        println!(" {:10.6} {:10.2}", lam, pr);

        fixed_k_data.push((n, vals, lam));
    }

    // Phase 3: Decay exponents for each fixed k
    println!("\n[3/4] Decay exponents at each fixed k...\n");
    println!(
        "  {:>5} {:>10} {:>10} {:>10}",
        "k", "exponent", "prefactor", "R²"
    );

    for (ki, &k) in fixed_ks.iter().enumerate() {
        let data: Vec<(f64, f64)> = fixed_k_data
            .iter()
            .filter(|(n, vals, _)| *n >= 50 && ki < vals.len() && vals[ki].abs() > 1e-10)
            .map(|(n, vals, _)| (*n as f64, vals[ki].abs()))
            .collect();

        if data.len() >= 5 {
            let nf = data.len() as f64;
            let slnx: f64 = data.iter().map(|(n, _)| n.ln()).sum();
            let slny: f64 = data.iter().map(|(_, v)| v.ln()).sum();
            let slnx2: f64 = data.iter().map(|(n, _)| n.ln().powi(2)).sum();
            let slnxy: f64 = data.iter().map(|(n, v)| n.ln() * v.ln()).sum();
            let slope = (nf * slnxy - slnx * slny) / (nf * slnx2 - slnx * slnx);
            let intercept = (slny - slope * slnx) / nf;

            // R² computation
            let mean_y = slny / nf;
            let ss_tot: f64 = data.iter().map(|(_, v)| (v.ln() - mean_y).powi(2)).sum();
            let ss_res: f64 = data
                .iter()
                .map(|(n, v)| (v.ln() - intercept - slope * n.ln()).powi(2))
                .sum();
            let r2 = 1.0 - ss_res / ss_tot;

            println!(
                "  {:5} {:10.4} {:10.6} {:10.6}",
                k,
                slope,
                intercept.exp(),
                r2
            );
        }
    }

    // Phase 4: Energy distribution analysis
    println!("\n[4/4] Energy distribution...\n");
    println!("  How does ||v||² distribute across index ranges?\n");

    println!(
        "  {:>5} {:>10} {:>10} {:>10} {:>10} {:>10} {:>10} {:>10}",
        "N", "k≤10", "k≤30", "k≤100", "k≤N/4", "k≤N/2", "k≤3N/4", "center"
    );

    for &n in &n_values {
        let d = n - 1;
        if d < 2 {
            continue;
        }
        let sub: Vec<Vec<f64>> = gram[..d].iter().map(|r| r[..d].to_vec()).collect();
        let (_, v) = smallest_eigenvector(&sub, 500);

        // Energy in ranges
        let energy = |lo: usize, hi: usize| -> f64 {
            v.iter()
                .enumerate()
                .filter(|(i, _)| *i + 2 >= lo && *i + 2 <= hi)
                .map(|(_, x)| x * x)
                .sum::<f64>()
        };

        let e_10 = energy(2, 10);
        let e_30 = energy(2, 30);
        let e_100 = energy(2, 100);
        let e_q1 = energy(2, n / 4);
        let e_q2 = energy(2, n / 2);
        let e_q3 = energy(2, 3 * n / 4);

        // Center of mass (weighted by v²)
        let com: f64 = v
            .iter()
            .enumerate()
            .map(|(i, x)| (i + 2) as f64 * x * x)
            .sum::<f64>();

        println!(
            "  {:5} {:10.4} {:10.4} {:10.4} {:10.4} {:10.4} {:10.4} {:10.2}",
            n, e_10, e_30, e_100, e_q1, e_q2, e_q3, com
        );
    }

    // Phase 5: The g projection decomposition
    println!("\n  ═══ PROJECTION DECOMPOSITION ═══\n");
    println!("  gᵀv_min = Σ_{{k≤K}} g[k]v[k] + Σ_{{k>K}} g[k]v[k]\n");

    for &n in &[100, 200, 300, 500, 700, 999] {
        let d = n - 1;
        let sub: Vec<Vec<f64>> = gram[..d].iter().map(|r| r[..d].to_vec()).collect();
        let (_, v) = smallest_eigenvector(&sub, 500);
        // g for adding f_{n+1}
        let g: Vec<f64> = (0..d).map(|k| gram[n - 1][k]).collect();
        let g_norm: f64 = g.iter().map(|x| x * x).sum::<f64>().sqrt();
        let total: f64 = g.iter().zip(v.iter()).map(|(a, b)| a * b).sum();

        println!("  N = {}:", n);
        let cutoffs = [10, 30, 50, 100, n / 4, n / 2];
        for &c in &cutoffs {
            if c >= d {
                continue;
            }
            let partial: f64 = g[..c].iter().zip(v[..c].iter()).map(|(a, b)| a * b).sum();
            let tail: f64 = total - partial;
            println!(
                "    K={:5}: Σ_{{k≤K}} = {:10.6}, Σ_{{k>K}} = {:10.6}, total = {:10.6}",
                c + 2,
                partial,
                tail,
                total
            );
        }
        println!("    cos θ = {:10.8}", total.abs() / g_norm);
        println!();
    }

    // Phase 6: The KEY quantity — how fast does gᵀv shrink?
    println!("  ═══ gᵀv_min DECAY RATE ═══\n");

    let mut gv_data: Vec<(f64, f64)> = Vec::new();
    for &n in &n_values {
        if n < 20 {
            continue;
        }
        let d = n - 1;
        let sub: Vec<Vec<f64>> = gram[..d].iter().map(|r| r[..d].to_vec()).collect();
        let (_, v) = smallest_eigenvector(&sub, 500);
        let g: Vec<f64> = (0..d).map(|k| gram[n - 1][k]).collect();
        let g_norm: f64 = g.iter().map(|x| x * x).sum::<f64>().sqrt();
        let gv: f64 = g.iter().zip(v.iter()).map(|(a, b)| a * b).sum();
        let cos_theta = gv.abs() / g_norm;

        gv_data.push((n as f64, cos_theta));
    }

    println!("  {:>5} {:>12} {:>12}", "N", "cos θ", "cos θ · √N");
    for &(n, cos) in &gv_data {
        println!("  {:5} {:12.8} {:12.6}", n as usize, cos, cos * n.sqrt());
    }

    // Fit
    if gv_data.len() >= 5 {
        let nf = gv_data.len() as f64;
        let slnx: f64 = gv_data.iter().map(|(n, _)| n.ln()).sum();
        let slny: f64 = gv_data.iter().map(|(_, c)| c.ln()).sum();
        let slnx2: f64 = gv_data.iter().map(|(n, _)| n.ln().powi(2)).sum();
        let slnxy: f64 = gv_data.iter().map(|(n, c)| n.ln() * c.ln()).sum();
        let slope = (nf * slnxy - slnx * slny) / (nf * slnx2 - slnx * slnx);
        let intercept = (slny - slope * slnx) / nf;
        println!("\n  Fit: cos θ ∝ N^({:.4})", slope);
        println!("  Prefactor: {:.6}", intercept.exp());

        if slope < -0.5 {
            let drop_exp = 2.0 * slope + 1.0; // δ = ||g||² cos²θ / S ~ N · N^{2·slope} / S
            println!(
                "\n  Therefore: δ_N ∝ N · N^{{2×{:.4}}} = N^({:.4})",
                slope, drop_exp
            );
            if drop_exp < -1.0 {
                println!("  ✅ Σ δ_N CONVERGES! (exponent {:.4} < -1)", drop_exp);
            } else {
                println!(
                    "  ⚠️  Σ δ_N may not converge (exponent {:.4} ≥ -1)",
                    drop_exp
                );
            }
        }
    }

    println!("\n  Total time: {:.1}s", start.elapsed().as_secs_f64());
    println!("═══════════════════════════════════════════════════════════════");
}
