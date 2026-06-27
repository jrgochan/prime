#![allow(unused, dead_code, non_snake_case)]
use rayon::prelude::*;

// ══════════════════════════════════════════════════════════
// DROP MECHANISM ANALYSIS
//
// Goal: Understand WHY δ_N ≈ C·d(N)²/N^{2.5}
//
// The drop formula: δ_N ≈ (gᵀ v_min)² / Schur_N
// where:
//   g     = cross-correlation vector ⟨f_k, f_{N+1}⟩
//   v_min = smallest eigenvector of G_N
//   Schur = γ - gᵀ G_N⁻¹ g ≈ 0.06 (constant)
//
// We decompose gᵀ v_min by divisor structure to find
// the exact decay rate and prove it bounded.
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

fn num_divisors(n: usize) -> usize {
    let mut count = 0;
    let mut d = 1;
    while d * d <= n {
        if n.is_multiple_of(d) {
            count += 1;
            if d != n / d {
                count += 1;
            }
        }
        d += 1;
    }
    count
}

fn gcd(a: usize, b: usize) -> usize {
    let (mut a, mut b) = (a, b);
    while b != 0 {
        let t = b;
        b = a % b;
        a = t;
    }
    a
}

fn distinct_prime_factors(n: usize) -> usize {
    let mut count = 0;
    let mut m = n;
    let mut d = 2;
    while d * d <= m {
        if m.is_multiple_of(d) {
            count += 1;
            while m.is_multiple_of(d) {
                m /= d;
            }
        }
        d += 1;
    }
    if m > 1 {
        count += 1;
    }
    count
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

// Returns (eigenvalue, eigenvector)
fn smallest_eigenpair(mat: &[Vec<f64>], n_iter: usize) -> (f64, Vec<f64>) {
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
    let mut w = vec![0.0; n];
    for i in 0..n {
        for j in 0..n {
            w[i] += mat[i][j] * v[j];
        }
    }
    let lam: f64 = v.iter().zip(w.iter()).map(|(a, b)| a * b).sum();
    (lam, v)
}

fn main() {
    println!("═══════════════════════════════════════════════════════════════");
    println!("  DROP MECHANISM ANALYSIS");
    println!("  Decomposing δ_N = (gᵀ v_min)² / Schur by divisor structure");
    println!("═══════════════════════════════════════════════════════════════");

    let max_n: usize = 500;
    let n_pts = 200_000;
    let start = std::time::Instant::now();

    // Phase 1: Compute Gram matrix
    println!(
        "\n[1/3] Computing {}×{} Gram matrix...",
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

    // Phase 2: Analyze drop mechanism at key N values
    println!("\n[2/3] Analyzing drop mechanism...\n");

    // M = the HC function being ADDED to G_{M-1}
    // Drop = λ_min(G_{M-1}) - λ_min(G_M)
    // Cross-correlation g[k] = ⟨f_k, f_M⟩ = gram[M-2][k-2]
    let hc_targets: Vec<usize> = vec![
        12, 24, 30, 36, 48, 60, 72, 84, 90, 120, 168, 180, 210, 240, 252, 270, 300, 336, 360, 420,
        480,
    ];

    println!(
        "  {:>5} {:>5} {:>5} {:>10} {:>10} {:>10} {:>10} {:>10} {:>10}",
        "M", "d(M)", "ω(M)", "δ_M", "|gᵀvmin|", "Schur", "δ_predict", "|g̃ᵀvmin|", "Σvmin"
    );

    let mut analysis_data: Vec<(usize, f64, f64, f64, f64, f64)> = Vec::new();

    for &m in &hc_targets {
        if m >= max_n {
            continue;
        }
        // G_{M-1} has dimension M-2 (functions 2..M-1)
        let dim_prev = m - 2;
        if dim_prev < 2 {
            continue;
        }

        // Eigenpair of G_{M-1}
        let sub: Vec<Vec<f64>> = gram[..dim_prev]
            .iter()
            .map(|r| r[..dim_prev].to_vec())
            .collect();
        let (lam_prev, v_min) = smallest_eigenpair(&sub, 500);

        // Eigenpair of G_M (dimension M-1)
        let dim_cur = m - 1;
        let sub1: Vec<Vec<f64>> = gram[..dim_cur]
            .iter()
            .map(|r| r[..dim_cur].to_vec())
            .collect();
        let (lam_cur, _) = smallest_eigenpair(&sub1, 500);
        let drop = (lam_prev - lam_cur).max(0.0);

        // Cross-correlation: g[k] = ⟨f_{k+2}, f_M⟩ = gram[m-2][k]
        // for k = 0..dim_prev-1 (functions 2..M-1)
        let g: Vec<f64> = (0..dim_prev).map(|k| gram[m - 2][k]).collect();
        let gamma = gram[m - 2][m - 2]; // self-energy of f_M

        // Projection gᵀ v_min
        let g_dot_v: f64 = g.iter().zip(v_min.iter()).map(|(a, b)| a * b).sum();

        // Schur complement
        let mut lu = sub.clone();
        let piv = lu_decompose(&mut lu);
        let x = lu_solve(&lu, &piv, &g);
        let gtx: f64 = g.iter().zip(x.iter()).map(|(a, b)| a * b).sum();
        let schur = gamma - gtx;

        // Predicted drop
        let drop_predict = g_dot_v * g_dot_v / schur;

        // Centered analysis: subtract coprime baseline
        let c0: f64 = {
            let coprime_entries: Vec<f64> = (0..dim_prev)
                .filter(|&k| gcd(k + 2, m) == 1)
                .map(|k| g[k])
                .collect();
            if coprime_entries.is_empty() {
                0.242
            } else {
                coprime_entries.iter().sum::<f64>() / coprime_entries.len() as f64
            }
        };

        let g_centered: Vec<f64> = g.iter().map(|&x| x - c0).collect();
        let gc_dot_v: f64 = g_centered
            .iter()
            .zip(v_min.iter())
            .map(|(a, b)| a * b)
            .sum();
        let v_sum: f64 = v_min.iter().sum::<f64>();

        let dn = num_divisors(m);
        let omega = distinct_prime_factors(m);

        println!(
            "  {:5} {:5} {:5} {:10.2e} {:10.6} {:10.6} {:10.2e} {:10.6} {:10.6}",
            m,
            dn,
            omega,
            drop,
            g_dot_v.abs(),
            schur,
            drop_predict,
            gc_dot_v.abs(),
            v_sum.abs()
        );

        analysis_data.push((m, drop, g_dot_v.abs(), schur, gc_dot_v.abs(), v_sum.abs()));
    }

    // Phase 3: The critical question: how does |gᵀ v_min| scale with N?
    println!("\n[3/3] ═══ SCALING ANALYSIS ═══\n");

    println!("  Testing: |gᵀ v_min| ∝ N^(-β)  for HC numbers\n");

    // Fit β from the HC data (excluding very small N)
    let hc_data: Vec<(f64, f64)> = analysis_data
        .iter()
        .filter(|d| d.0 >= 60)
        .map(|d| (d.0 as f64, d.2))
        .collect();

    if hc_data.len() >= 2 {
        // Log-log fit: ln|gᵀv| = -β ln(N) + ln(A)
        let n_fit = hc_data.len() as f64;
        let sum_lnx: f64 = hc_data.iter().map(|(n, _)| n.ln()).sum();
        let sum_lny: f64 = hc_data.iter().map(|(_, g)| g.ln()).sum();
        let sum_lnx2: f64 = hc_data.iter().map(|(n, _)| n.ln().powi(2)).sum();
        let sum_lnxy: f64 = hc_data.iter().map(|(n, g)| n.ln() * g.ln()).sum();

        let beta = -(n_fit * sum_lnxy - sum_lnx * sum_lny) / (n_fit * sum_lnx2 - sum_lnx * sum_lnx);
        let ln_a = (sum_lny + beta * sum_lnx) / n_fit;
        let a = ln_a.exp();

        println!("  Fit: |gᵀ v_min| ≈ {:.4} · N^(-{:.4})", a, beta);
        println!(
            "  Therefore: δ_N ≈ {:.4}² · N^(-{:.4}) / 0.06 = {:.4} · N^(-{:.4})",
            a,
            2.0 * beta,
            a * a / 0.06,
            2.0 * beta
        );

        if 2.0 * beta > 1.0 {
            println!(
                "\n  ✅ Exponent 2β = {:.4} > 1 ⟹ Σ δ_N CONVERGES!",
                2.0 * beta
            );
            println!("     (even without d(N)² factor, the sum converges)");
        }

        // Verify fit
        println!("\n  Fit verification:");
        println!(
            "  {:>5} {:>12} {:>12} {:>8}",
            "N", "|gᵀv| data", "|gᵀv| fit", "ratio"
        );
        for &(n, gv) in &hc_data {
            let fit = a * n.powf(-beta);
            println!(
                "  {:5} {:12.6} {:12.6} {:8.4}",
                n as usize,
                gv,
                fit,
                gv / fit
            );
        }
    }

    // Decomposition by divisor contribution
    println!("\n  ═══ DIVISOR DECOMPOSITION ═══\n");
    println!("  For each HC number N+1, decompose gᵀ v_min by gcd(k, N+1):\n");

    for &m in &[60, 120, 180, 240, 360, 420] {
        if m >= max_n {
            continue;
        }
        let dim_prev = m - 2;
        if dim_prev < 2 {
            continue;
        }
        let sub: Vec<Vec<f64>> = gram[..dim_prev]
            .iter()
            .map(|r| r[..dim_prev].to_vec())
            .collect();
        let (_, v_min) = smallest_eigenpair(&sub, 500);
        let g: Vec<f64> = (0..dim_prev).map(|k| gram[m - 2][k]).collect();
        let c0: f64 = {
            let co: Vec<f64> = (0..dim_prev)
                .filter(|&k| gcd(k + 2, m) == 1)
                .map(|k| g[k])
                .collect();
            if co.is_empty() {
                0.242
            } else {
                co.iter().sum::<f64>() / co.len() as f64
            }
        };

        // Group by gcd(k+2, M)
        let mut gcd_groups: std::collections::BTreeMap<usize, (f64, usize)> =
            std::collections::BTreeMap::new();
        for k in 0..dim_prev {
            let gk = gcd(k + 2, m);
            let contribution = (g[k] - c0) * v_min[k];
            let entry = gcd_groups.entry(gk).or_insert((0.0, 0));
            entry.0 += contribution;
            entry.1 += 1;
        }

        let total: f64 = gcd_groups.values().map(|v| v.0).sum();
        println!(
            "  M = {} (d(M) = {}, ω(M) = {}):",
            m,
            num_divisors(m),
            distinct_prime_factors(m)
        );
        println!(
            "    {:>6} {:>12} {:>6} {:>10}",
            "gcd", "Σ(g̃·v)", "count", "avg|v|"
        );
        for (gk, (contrib, count)) in &gcd_groups {
            if *count > 0 && *gk > 1 {
                let avg_v: f64 = (0..dim_prev)
                    .filter(|&k| gcd(k + 2, m) == *gk)
                    .map(|k| v_min[k].abs())
                    .sum::<f64>()
                    / *count as f64;
                println!("    {:6} {:12.8} {:6} {:10.6}", gk, contrib, count, avg_v);
            }
        }
        println!(
            "    Total divisor projection: {:.8} (gᵀv = g̃ᵀv + c₀·1ᵀv)",
            total
        );
        println!();
    }

    // Final: eigenvector structure
    println!("  ═══ EIGENVECTOR STRUCTURE ═══\n");
    println!("  v_min at N=500:");
    let d = max_n - 2;
    let sub: Vec<Vec<f64>> = gram[..d].iter().map(|r| r[..d].to_vec()).collect();
    let (lam, v_min) = smallest_eigenpair(&sub, 500);
    println!("  λ_min = {:.8}", lam);
    println!(
        "  ||v_min||² = {:.8}",
        v_min.iter().map(|x| x * x).sum::<f64>()
    );
    println!(
        "  Σ v_min = {:.8} (should be ≈ 0 if ⊥ to 1)",
        v_min.iter().sum::<f64>()
    );

    // Show decay of v_min entries
    println!("\n  |v_min[k]| at selected k:");
    println!("  {:>5}  {:>12}", "k", "|v_min[k]|");
    for k in [2, 3, 5, 10, 20, 50, 100, 200, 300, 400, 498] {
        if k - 2 < v_min.len() {
            println!("  {:5}  {:12.8}", k, v_min[k - 2].abs());
        }
    }

    // Fit v_min decay
    let vdata: Vec<(f64, f64)> = (0..d)
        .filter(|&i| v_min[i].abs() > 1e-10)
        .map(|i| ((i + 2) as f64, v_min[i].abs()))
        .collect();
    if vdata.len() > 10 {
        let n_v = 100.min(vdata.len());
        let sum_lnx: f64 = vdata[..n_v].iter().map(|(k, _)| k.ln()).sum::<f64>();
        let sum_lny: f64 = vdata[..n_v].iter().map(|(_, v)| v.ln()).sum::<f64>();
        let sum_lnx2: f64 = vdata[..n_v]
            .iter()
            .map(|(k, _)| k.ln().powi(2))
            .sum::<f64>();
        let sum_lnxy: f64 = vdata[..n_v]
            .iter()
            .map(|(k, v)| k.ln() * v.ln())
            .sum::<f64>();
        let nf = n_v as f64;
        let slope = (nf * sum_lnxy - sum_lnx * sum_lny) / (nf * sum_lnx2 - sum_lnx * sum_lnx);
        println!("\n  v_min[k] scaling: |v_min| ∝ k^({:.4})", slope);
        println!("  (negative slope means entries decay with k)");
    }

    println!("\n  Total time: {:.1}s", start.elapsed().as_secs_f64());
    println!("═══════════════════════════════════════════════════════════════");
}
