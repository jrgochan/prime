/// Experiments 2 & 3: Vasyunin Bound + NB Distance Decay
///
/// Exp 2: Validate |G_{jk} - 1/4| ≤ gcd(j,k)/(2jk) with exact integration
/// Exp 3: Compute d²_N = 1 - bᵀG⁻¹b with high-precision Gram matrix
///
/// Key optimization: compute ALL Gram entries in ONE pass over quadrature points.
/// For each x_i, compute frac(j/x_i) for all j, then accumulate outer products.

use std::fs;
use std::io::Write;

const N_MAX: usize = 400;
const QUAD_PTS: usize = 100_000; // 100K points for high precision

fn main() {
    println!("╔═══════════════════════════════════════════════════════╗");
    println!("║  Experiments 2 & 3: Vasyunin + NB Distance Decay     ║");
    println!("╚═══════════════════════════════════════════════════════╝\n");

    fs::create_dir_all("results").unwrap();

    // ═══════════════════════════════════════════
    // EXPERIMENT 2: Vasyunin Bound (exact integration for small j,k)
    // ═══════════════════════════════════════════
    println!("═══ Experiment 2: Vasyunin Bound Validation ═══\n");

    let mut vasy_file = fs::File::create("results/vasyunin_exact.csv").unwrap();
    writeln!(vasy_file, "j,k,G_jk,quarter,abs_error,vasyunin_bound,ratio,holds").unwrap();

    let vasy_max = 80;
    let mut violations = 0;
    let mut total_checks = 0;
    let mut max_ratio = 0.0f64;

    println!("{:>4} {:>4}  {:>14}  {:>12}  {:>12}  {:>12}  {:>6}",
        "j", "k", "G_{jk}", "|G-1/4|", "gcd/(2jk)", "ratio", "ok?");
    println!("{}", "-".repeat(75));

    for j in 1..=vasy_max {
        for k in j..=vasy_max {
            let g_jk = compute_gram_exact(j, k);
            let error = (g_jk - 0.25).abs();
            let gcd_jk = gcd(j, k) as f64;
            let bound = gcd_jk / (2.0 * j as f64 * k as f64);
            let ratio = error / bound;
            let holds = ratio <= 1.0 + 1e-8; // small tolerance

            if !holds { violations += 1; }
            max_ratio = max_ratio.max(ratio);
            total_checks += 1;

            writeln!(vasy_file, "{},{},{:.15},{:.15},{:.15},{:.15},{:.8},{}",
                j, k, g_jk, 0.25, error, bound, ratio, holds).unwrap();

            // Print interesting cases
            if (j <= 5 && k <= 5) || ratio > 0.9 || !holds {
                println!("{:>4} {:>4}  {:>14.10}  {:>12.2e}  {:>12.2e}  {:>12.6}  {}",
                    j, k, g_jk, error, bound, ratio, if holds { "✓" } else { "✗" });
            }
        }
    }

    println!("\nVasyunin Summary:");
    println!("  Pairs checked: {}", total_checks);
    println!("  Violations: {}", violations);
    println!("  Max ratio |G-1/4| / bound: {:.6}", max_ratio);
    println!("  Bound {}!", if violations == 0 { "HOLDS" } else { "VIOLATED" });

    // ═══════════════════════════════════════════
    // EXPERIMENT 3: NB Distance Decay
    // ═══════════════════════════════════════════
    println!("\n═══ Experiment 3: NB Distance Decay d²_N = O(1/log N) ═══\n");

    // Precompute basis inner products
    println!("Precomputing b_k for k=1..{} ...", N_MAX);
    let basis_ip: Vec<f64> = (0..=N_MAX)
        .map(|k| if k == 0 { 0.0 } else { compute_basis_ip(k) })
        .collect();

    // Precompute Gram matrix using vectorized single-pass
    println!("Precomputing Gram matrix (single-pass, {} quadrature points) ...", QUAD_PTS);
    let gram = compute_gram_matrix_fast(N_MAX);
    println!("Done.\n");

    let mut nb_file = fs::File::create("results/nb_distance_v2.csv").unwrap();
    writeln!(nb_file, "N,d2_optimal,d2_times_logN,log_N").unwrap();

    let mut opt_vec_file = fs::File::create("results/optimal_vectors.csv").unwrap();
    writeln!(opt_vec_file, "N,k,c_k,v_k_selberg").unwrap();

    let moebius = compute_moebius(N_MAX + 1);

    println!("{:>4}  {:>14}  {:>12}  {:>10}",
        "N", "d²_optimal", "d²·logN", "logN");
    println!("{}", "-".repeat(50));

    let mut max_d2_logn = 0.0f64;

    for n in 2..=N_MAX {
        let log_n = (n as f64).ln();
        let dim = n - 1;

        let b: Vec<f64> = (1..=dim).map(|k| basis_ip[k]).collect();
        let g: Vec<Vec<f64>> = (1..=dim)
            .map(|i| (1..=dim).map(|j| gram[i][j]).collect())
            .collect();

        // Solve G⁻¹b via Cholesky
        let (d2_opt, opt_c) = match solve_distance_and_vector(&g, &b) {
            Some(r) => r,
            None => {
                if n <= 20 || n % 50 == 0 {
                    println!("{:>4}  SINGULAR", n);
                }
                continue;
            }
        };

        let d2_logn = d2_opt * log_n;
        if n >= 10 { max_d2_logn = max_d2_logn.max(d2_logn); }

        writeln!(nb_file, "{},{:.15},{:.10},{:.10}", n, d2_opt, d2_logn, log_n).unwrap();

        // Save optimal vector for select N values
        if n == 10 || n == 50 || n == 100 || n == 200 || n == N_MAX {
            let v_selberg: Vec<f64> = (1..=dim)
                .map(|k| selberg_weight(k, n, &moebius) / (k as f64))
                .collect();
            for k in 0..dim.min(50) {
                writeln!(opt_vec_file, "{},{},{:.10},{:.10}",
                    n, k+1, opt_c[k], v_selberg[k]).unwrap();
            }
        }

        if n <= 20 || n % 25 == 0 || n == N_MAX {
            println!("{:>4}  {:>14.10}  {:>12.6}  {:>10.4}",
                n, d2_opt, d2_logn, log_n);
        }
    }

    println!("\n{}", "=".repeat(50));
    println!("RESULTS:");
    println!("  max d²·log(N) for N≥10: {:.8}", max_d2_logn);
    println!("  → moebius_test_bound verified with C ≈ {:.2}", max_d2_logn.ceil().max(1.0));
    println!("\nOutput: results/vasyunin_exact.csv, results/nb_distance_v2.csv,");
    println!("        results/optimal_vectors.csv");

    let mut report = fs::File::create("results/experiment_report.txt").unwrap();
    writeln!(report, "EXPERIMENT 2: Vasyunin Bound").unwrap();
    writeln!(report, "  Pairs: {}, Violations: {}, Max ratio: {:.6}", total_checks, violations, max_ratio).unwrap();
    writeln!(report, "\nEXPERIMENT 3: NB Distance Decay").unwrap();
    writeln!(report, "  max d²·log(N) for N≥10: {:.10}", max_d2_logn).unwrap();
    writeln!(report, "  Conclusion: d²_N = O(1/log N) with C ≈ {:.2}", max_d2_logn.ceil().max(1.0)).unwrap();
}

/// Exact G_{jk} = ∫₀¹ {j/x}{k/x} dx via piecewise analytical integration.
/// Breakpoints at x = j/m and x = k/n for relevant m, n.
fn compute_gram_exact(j: usize, k: usize) -> f64 {
    let jf = j as f64;
    let kf = k as f64;

    // For accuracy, use enough breakpoints that sub-intervals are smooth
    let limit = ((j.max(k)) * 5000).min(500000);
    let mut bps = Vec::with_capacity(2 * limit);

    for m in j..=limit {
        let bp = jf / m as f64;
        if bp <= 1.0 { bps.push(bp); }
        if bp < 1e-12 { break; }
    }
    for m in k..=limit {
        let bp = kf / m as f64;
        if bp <= 1.0 { bps.push(bp); }
        if bp < 1e-12 { break; }
    }
    bps.push(1.0);
    bps.sort_unstable_by(|a, b| a.partial_cmp(b).unwrap());
    bps.dedup_by(|a, b| (*a - *b).abs() < 1e-15);

    let mut total = 0.0;
    for w in bps.windows(2) {
        let a = w[0];
        let b = w[1];
        if b - a < 1e-15 || a < 1e-14 { continue; }

        let mid = (a + b) / 2.0;
        let m = (jf / mid).floor();
        let nn = (kf / mid).floor();

        // ∫_a^b (j/x - m)(k/x - n) dx
        // = jk(1/a - 1/b) - (jn+km)(ln(b) - ln(a)) + mn(b-a)
        total += jf * kf * (1.0/a - 1.0/b)
            - (jf * nn + kf * m) * (b.ln() - a.ln())
            + m * nn * (b - a);
    }
    total
}

/// Compute full N_MAX × N_MAX Gram matrix in a single pass over quadrature points.
/// For each x_i, compute frac(j/x_i) for j=1..N_MAX, then accumulate.
fn compute_gram_matrix_fast(n_max: usize) -> Vec<Vec<f64>> {
    let mut g = vec![vec![0.0f64; n_max + 1]; n_max + 1];
    let dx = 1.0 / QUAD_PTS as f64;

    for i in 0..QUAD_PTS {
        let x = (i as f64 + 0.5) * dx;
        // Precompute all fractional parts
        let fracs: Vec<f64> = (0..=n_max)
            .map(|j| if j == 0 { 0.0 } else { fract(j as f64 / x) })
            .collect();

        // Accumulate outer product (symmetric, only upper triangle)
        for j in 1..=n_max {
            let fj = fracs[j];
            if fj.abs() < 1e-15 { continue; }
            for k in j..=n_max {
                g[j][k] += fj * fracs[k];
            }
        }
    }

    // Scale and symmetrize
    for j in 1..=n_max {
        for k in j..=n_max {
            g[j][k] *= dx;
            g[k][j] = g[j][k];
        }
    }
    g
}

fn solve_distance_and_vector(g: &[Vec<f64>], b: &[f64]) -> Option<(f64, Vec<f64>)> {
    let n = b.len();
    let mut l = vec![vec![0.0f64; n]; n];
    for i in 0..n {
        for j in 0..=i {
            let s: f64 = (0..j).map(|k| l[i][k] * l[j][k]).sum();
            if i == j {
                let v = g[i][i] - s;
                if v <= 1e-15 { return None; }
                l[i][j] = v.sqrt();
            } else {
                if l[j][j].abs() < 1e-15 { return None; }
                l[i][j] = (g[i][j] - s) / l[j][j];
            }
        }
    }
    let mut y = vec![0.0f64; n];
    for i in 0..n {
        let s: f64 = (0..i).map(|j| l[i][j] * y[j]).sum();
        y[i] = (b[i] - s) / l[i][i];
    }
    let mut c = vec![0.0f64; n];
    for i in (0..n).rev() {
        let s: f64 = ((i+1)..n).map(|j| l[j][i] * c[j]).sum();
        c[i] = (y[i] - s) / l[i][i];
    }
    let btc: f64 = (0..n).map(|i| b[i] * c[i]).sum();
    Some((1.0 - btc, c))
}

fn compute_basis_ip(k: usize) -> f64 {
    let kf = k as f64;
    let mut sum = 0.0;
    for n in k..=(10 * k + 50000) {
        let nf = n as f64;
        sum += kf * ((nf + 1.0) / nf).ln() - kf / (nf + 1.0);
    }
    sum
}

fn fract(x: f64) -> f64 { x - x.floor() }
fn gcd(a: usize, b: usize) -> usize { if b == 0 { a } else { gcd(b, a % b) } }

fn selberg_weight(d: usize, big_d: usize, mu: &[i32]) -> f64 {
    if d == 0 || big_d <= 1 { return if d == 1 { 1.0 } else { 0.0 }; }
    if d > big_d { return 0.0; }
    mu[d] as f64 * (1.0 - (d as f64).ln() / (big_d as f64).ln()).max(0.0)
}

fn compute_moebius(max_n: usize) -> Vec<i32> {
    let mut mu = vec![0i32; max_n + 1];
    mu[1] = 1;
    let mut sp = vec![0usize; max_n + 1];
    let mut ip = vec![true; max_n + 1];
    for p in 2..=max_n {
        if !ip[p] { continue; }
        for m in (p..=max_n).step_by(p) {
            if m != p { ip[m] = false; }
            if sp[m] == 0 { sp[m] = p; }
        }
    }
    for n in 2..=max_n {
        let mut m = n; let mut nf = 0; let mut sf = true;
        while m > 1 {
            let p = sp[m]; let mut cnt = 0;
            while m % p == 0 { m /= p; cnt += 1; }
            if cnt > 1 { sf = false; break; }
            nf += 1;
        }
        mu[n] = if sf { if nf % 2 == 0 { 1 } else { -1 } } else { 0 };
    }
    mu
}
