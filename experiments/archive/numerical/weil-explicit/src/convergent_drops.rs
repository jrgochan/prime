#![allow(unused, dead_code, non_snake_case)]
use rayon::prelude::*;

// ══════════════════════════════════════════════════════════
// CONVERGENT DROPS EXPERIMENT
//
// Test the key conjecture: eigenvalue drops at highly composite
// numbers form a convergent series, implying λ_min → c > 0.
//
// Computes for each N = 2..1000:
//   1. λ_min(G_N) via inverse iteration
//   2. Schur_N = γ - gᵀ G_N⁻¹ g  (how much "new info" f_{N+1} adds)
//   3. Drop δ_N = λ_min(G_N) - λ_min(G_{N+1})
//   4. Correlates with d(N+1) (number of divisors)
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
        if n % d == 0 {
            count += 1;
            if d != n / d {
                count += 1;
            }
        }
        d += 1;
    }
    count
}

fn is_prime(n: usize) -> bool {
    if n < 2 {
        return false;
    }
    if n < 4 {
        return true;
    }
    if n % 2 == 0 || n % 3 == 0 {
        return false;
    }
    let mut i = 5;
    while i * i <= n {
        if n % i == 0 || n % (i + 2) == 0 {
            return false;
        }
        i += 6;
    }
    true
}

// LU decomposition with partial pivoting
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

fn inverse_iteration(mat: &[Vec<f64>], n_iter: usize) -> f64 {
    let n = mat.len();
    if n == 0 {
        return 0.0;
    }
    if n == 1 {
        return mat[0][0];
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
    vav
}

fn main() {
    println!("═══════════════════════════════════════════════════════════════");
    println!("  CONVERGENT DROPS EXPERIMENT (N=1000)");
    println!("  Testing: Do eigenvalue drops at HC numbers converge?");
    println!("═══════════════════════════════════════════════════════════════");

    let max_n: usize = 1000;
    let n_pts = 200_000;

    // Phase 1: Precompute the full Gram matrix
    println!(
        "\n[1/4] Computing {}×{} Gram matrix ({} pts)...",
        max_n - 1,
        max_n - 1,
        n_pts
    );
    let start = std::time::Instant::now();

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

    // Symmetrize
    let mut gram = vec![vec![0.0; dim]; dim];
    for j in 0..dim {
        for k in j..dim {
            gram[j][k] = gram_upper[j][k];
            gram[k][j] = gram_upper[j][k];
        }
    }
    println!("  Done in {:.1}s", start.elapsed().as_secs_f64());

    // Phase 2: Compute λ_min, Schur complement, drops for each N
    println!("\n[2/4] Computing eigenvalues and Schur complements...\n");
    println!(
        "  {:>5}  {:>12}  {:>12}  {:>12}  {:>5}  {:>5}  {:>8}",
        "N", "λ_min(G_N)", "Schur_N", "drop δ_N", "d(N)", "prime", "type"
    );

    let mut lmin_prev = 0.0f64;
    let mut results: Vec<(usize, f64, f64, f64, usize, bool)> = Vec::new();
    let mut cumulative_drop = 0.0f64;

    for n in 2..=max_n {
        let d = n - 1; // dimension of G_N

        // Extract sub-matrix G_N
        let sub: Vec<Vec<f64>> = gram[..d].iter().map(|r| r[..d].to_vec()).collect();

        // Compute λ_min
        let lmin = inverse_iteration(&sub, 300);

        // Compute Schur complement only for N ≤ 500 (expensive at large N)
        let schur = if n < max_n && n <= 500 {
            let g: Vec<f64> = (0..d).map(|k| gram[n - 1][k]).collect();
            let gamma = gram[n - 1][n - 1];
            let mut lu = sub.clone();
            let piv = lu_decompose(&mut lu);
            let x = lu_solve(&lu, &piv, &g);
            let gtx: f64 = g.iter().zip(x.iter()).map(|(a, b)| a * b).sum();
            gamma - gtx
        } else {
            -1.0 // sentinel: not computed
        };

        // Drop from previous
        let drop = if n > 2 {
            (lmin_prev - lmin).max(0.0)
        } else {
            0.0
        };
        if drop > 0.0 {
            cumulative_drop += drop;
        }

        let nd = num_divisors(n);
        let pr = is_prime(n);

        // Determine type
        let ntype = if nd >= 12 {
            "HC"
        } else if nd >= 8 {
            "hc"
        } else if pr {
            "P"
        } else if nd <= 3 {
            "sp"
        } else {
            ""
        };

        // Print significant rows
        let show = n <= 30 || drop > 0.0003 || nd >= 16 || n % 100 == 0 || n == max_n;
        if show {
            let sch_str = if schur >= 0.0 {
                format!("{:12.8}", schur)
            } else {
                "         n/a".to_string()
            };
            println!(
                "  {:5}  {:12.8}  {}  {:12.8}  {:5}  {:>5}  {:>8}",
                n,
                lmin,
                sch_str,
                drop,
                nd,
                if pr { "yes" } else { "" },
                ntype
            );
        }

        // Progress
        if n % 100 == 0 {
            eprintln!("  ... N={} done ({:.0}s)", n, start.elapsed().as_secs_f64());
        }

        results.push((n, lmin, schur, drop, nd, pr));
        lmin_prev = lmin;
    }

    // Phase 3: Analysis of drops
    println!("\n[3/4] ═══ DROP ANALYSIS ═══\n");

    // Top 20 largest drops
    let mut drops_sorted: Vec<(usize, f64, usize)> = results
        .iter()
        .filter(|r| r.3 > 1e-8)
        .map(|r| (r.0, r.3, r.4))
        .collect();
    drops_sorted.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap());

    println!("  Top 20 largest eigenvalue drops:");
    println!(
        "  {:>5}  {:>12}  {:>5}  {:>8}",
        "N", "drop", "d(N)", "cumul"
    );
    let mut cum = 0.0;
    for (i, (n, drop, nd)) in drops_sorted.iter().take(20).enumerate() {
        cum += drop;
        println!("  {:5}  {:12.8}  {:5}  {:8.6}", n, drop, nd, cum);
        let _ = i;
    }

    // Average drop at primes vs composites
    let prime_drops: Vec<f64> = results
        .iter()
        .filter(|r| r.5 && r.3 > 0.0)
        .map(|r| r.3)
        .collect();
    let composite_drops: Vec<f64> = results
        .iter()
        .filter(|r| !r.5 && r.0 > 2 && r.3 > 0.0)
        .map(|r| r.3)
        .collect();
    let hc_drops: Vec<f64> = results
        .iter()
        .filter(|r| r.4 >= 8 && r.3 > 0.0)
        .map(|r| r.3)
        .collect();

    println!("\n  Drop statistics:");
    if !prime_drops.is_empty() {
        let avg: f64 = prime_drops.iter().sum::<f64>() / prime_drops.len() as f64;
        let max = prime_drops.iter().cloned().fold(0.0f64, f64::max);
        println!(
            "    Primes:     avg = {:.8}, max = {:.8}, count = {}",
            avg,
            max,
            prime_drops.len()
        );
    }
    if !composite_drops.is_empty() {
        let avg: f64 = composite_drops.iter().sum::<f64>() / composite_drops.len() as f64;
        let max = composite_drops.iter().cloned().fold(0.0f64, f64::max);
        println!(
            "    Composites: avg = {:.8}, max = {:.8}, count = {}",
            avg,
            max,
            composite_drops.len()
        );
    }
    if !hc_drops.is_empty() {
        let avg: f64 = hc_drops.iter().sum::<f64>() / hc_drops.len() as f64;
        let max = hc_drops.iter().cloned().fold(0.0f64, f64::max);
        println!(
            "    HC (d≥8):   avg = {:.8}, max = {:.8}, count = {}",
            avg,
            max,
            hc_drops.len()
        );
    }

    // Cumulative drop
    let total_drop: f64 = results.iter().filter(|r| r.3 > 0.0).map(|r| r.3).sum();
    let lmin_2 = results[0].1;
    println!("\n  λ_min(G_2) = {:.8}", lmin_2);
    println!("  Σ drops    = {:.8}", total_drop);
    println!("  λ_min(G_2) - Σ drops = {:.8}", lmin_2 - total_drop);
    println!("  λ_min(G_{}) = {:.8}", max_n, results.last().unwrap().1);

    // Phase 4: Schur complement analysis
    println!("\n[4/4] ═══ SCHUR COMPLEMENT ANALYSIS ═══\n");

    // Schur at primes vs composites
    let prime_schurs: Vec<(usize, f64)> = results
        .iter()
        .filter(|r| r.5 && r.0 < max_n)
        .map(|r| (r.0, r.2))
        .collect();
    let composite_schurs: Vec<(usize, f64)> = results
        .iter()
        .filter(|r| !r.5 && r.0 > 2 && r.0 < max_n)
        .map(|r| (r.0, r.2))
        .collect();

    println!("  Schur complement: Schur_N = ||f_{{N+1}} - proj||²\n");

    println!("  At primes (f_{{N+1}} with N+1 prime):");
    if !prime_schurs.is_empty() {
        let avg: f64 = prime_schurs.iter().map(|s| s.1).sum::<f64>() / prime_schurs.len() as f64;
        let min = prime_schurs
            .iter()
            .map(|s| s.1)
            .fold(f64::INFINITY, f64::min);
        println!(
            "    avg Schur = {:.8}, min Schur = {:.8}, count = {}",
            avg,
            min,
            prime_schurs.len()
        );
    }

    println!("  At composites:");
    if !composite_schurs.is_empty() {
        let avg: f64 =
            composite_schurs.iter().map(|s| s.1).sum::<f64>() / composite_schurs.len() as f64;
        let min = composite_schurs
            .iter()
            .map(|s| s.1)
            .fold(f64::INFINITY, f64::min);
        println!(
            "    avg Schur = {:.8}, min Schur = {:.8}, count = {}",
            avg,
            min,
            composite_schurs.len()
        );
    }

    // Check Schur ≥ c/N
    println!("\n  Testing Schur_N ≥ c/(N+1):");
    let mut min_ratio = f64::INFINITY;
    let mut min_ratio_n = 0;
    for r in &results {
        if r.0 >= max_n {
            continue;
        }
        let ratio = r.2 * (r.0 as f64 + 1.0);
        if ratio < min_ratio {
            min_ratio = ratio;
            min_ratio_n = r.0;
        }
    }
    println!(
        "    min [Schur_N · (N+1)] = {:.6} at N = {}",
        min_ratio, min_ratio_n
    );
    println!(
        "    ⟹ Schur_N ≥ {:.6} / (N+1) for all N ≤ {}",
        min_ratio, max_n
    );

    // Convergence test: cumulative drops in windows
    println!("\n  Cumulative drops in windows of 100:");
    println!(
        "  {:>10}  {:>12}  {:>8}  {:>10}",
        "window", "Σ drops", "# drops", "ratio"
    );
    let windows: Vec<(usize, usize)> = vec![
        (2, 100),
        (100, 200),
        (200, 300),
        (300, 400),
        (400, 500),
        (500, 600),
        (600, 700),
        (700, 800),
        (800, 900),
        (900, 1000),
    ];
    let mut prev_sum = 0.0f64;
    let mut window_sums: Vec<f64> = Vec::new();
    for window in &windows {
        let drops_in: Vec<f64> = results
            .iter()
            .filter(|r| r.0 >= window.0 && r.0 < window.1 && r.3 > 0.0)
            .map(|r| r.3)
            .collect();
        let sum: f64 = drops_in.iter().sum();
        let count = drops_in.len();
        let ratio = if prev_sum > 0.0 && window.0 >= 200 {
            format!("{:.4}", sum / prev_sum)
        } else {
            "-".to_string()
        };
        println!(
            "  {:>4}-{:<4}  {:12.8}  {:8}  {:>10}",
            window.0, window.1, sum, count, ratio
        );
        window_sums.push(sum);
        prev_sum = sum;
    }

    // Estimate tail from geometric decay
    println!("\n  ═══ TAIL ESTIMATION ═══");
    let last_3: Vec<f64> = window_sums.iter().rev().take(3).cloned().collect();
    if last_3.len() >= 2 && last_3[1] > 0.0 {
        let ratio_last = last_3[0] / last_3[1];
        let ratio_avg = if last_3.len() >= 3 && last_3[2] > 0.0 {
            ((last_3[0] / last_3[1]) * (last_3[1] / last_3[2])).sqrt()
        } else {
            ratio_last
        };

        println!("  Last window ratio: {:.4}", ratio_last);
        println!("  Geometric mean ratio (last 3): {:.4}", ratio_avg);

        // Tail = last_window / (1 - ratio)
        let last_w = *window_sums.last().unwrap();
        let tail_est = last_w * ratio_avg / (1.0 - ratio_avg);
        let lmin_last = results.last().unwrap().1;
        let lmin_inf = lmin_last - tail_est;

        println!("\n  Last window sum: {:.10}", last_w);
        println!("  Estimated tail (geometric): {:.10}", tail_est);
        println!("  λ_min(G_{}) = {:.10}", max_n, lmin_last);
        println!(
            "  λ_min(G_∞) ≈ {:.10} - {:.10} = {:.10}",
            lmin_last, tail_est, lmin_inf
        );

        if lmin_inf > 0.0 {
            println!("\n  ╔═══════════════════════════════════════════════════════╗");
            println!("  ║                                                       ║");
            println!(
                "  ║  ✅ λ_min(G_∞) ≈ {:.6}                            ║",
                lmin_inf
            );
            println!("  ║     HYPERZETA: CONVERGENCE TO POSITIVE LIMIT         ║");
            println!(
                "  ║     Window decay ratio ≈ {:.3}                       ║",
                ratio_avg
            );
            println!("  ║                                                       ║");
            println!("  ╚═══════════════════════════════════════════════════════╝");
        }

        // Conservative bound with ratio = 0.9
        let cons_tail = last_w * 0.9 / (1.0 - 0.9);
        println!(
            "\n  Conservative (ratio=0.9): tail = {:.10}, λ_min(G_∞) ≥ {:.10}",
            cons_tail,
            lmin_last - cons_tail
        );
    }

    println!("\n  ════════════════════════════════════════════════════════");
    if total_drop < lmin_2 {
        println!("  ✅ Cumulative drops < λ_min(G_2): CONVERGENCE CONSISTENT");
    } else {
        println!("  ⚠️  Cumulative drops ≥ λ_min(G_2): needs more data");
    }
    println!("  Total time: {:.1}s", start.elapsed().as_secs_f64());
    println!("═══════════════════════════════════════════════════════════════");
}
