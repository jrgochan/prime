use rayon::prelude::*;
use std::collections::HashMap;
use std::f64::consts::PI;
use std::fs;
use std::io::Write;
use std::time::Instant;

const EULER_GAMMA: f64 = 0.5772156649015329;
const LN_2PI: f64 = 1.8378770664093453;

/// Sieve-based Möbius function (matches gap_analysis.rs exactly)
fn sieve_mobius(n: usize) -> Vec<i8> {
    let mut mu = vec![0i8; n + 1];
    mu[1] = 1;
    let mut is_prime = vec![true; n + 1];
    let mut primes = Vec::new();
    for i in 2..=n {
        if is_prime[i] {
            primes.push(i);
            mu[i] = -1;
        }
        for &p in &primes {
            if i * p > n { break; }
            is_prime[i * p] = false;
            if i % p == 0 { mu[i * p] = 0; break; }
            else { mu[i * p] = -mu[i]; }
        }
    }
    mu
}

fn gcd(mut a: usize, mut b: usize) -> usize {
    while b != 0 { let t = b; b = a % b; a = t; }
    a
}

/// Vasyunin sum V(a,b) — MATCHES gap_analysis.rs exactly
/// V(a,b) = Σ_{m=1}^{a-1} {m·b/a} · cot(π·m/a)
fn vasyunin_sum(a: usize, b: usize) -> f64 {
    if a <= 1 { return 0.0; }
    let af = a as f64;
    let bf = b as f64;
    let mut total = 0.0;
    for m in 1..a {
        let mf = m as f64;
        let mut frac_part = (mf * bf / af).fract();
        if frac_part < 0.0 { frac_part += 1.0; }
        let angle = PI * mf / af;
        let sin_val = angle.sin();
        if sin_val.abs() < 1e-15 { continue; }
        total += frac_part * angle.cos() / sin_val;
    }
    total
}

/// BD weights — matches gap_analysis.rs exactly
fn bd_weights(n: usize, mu: &[i8]) -> Vec<f64> {
    let log_n = (n as f64).ln();
    (0..n - 1)
        .map(|i| {
            let j = i + 1;
            if mu[j] == 0 { 0.0 }
            else { -(mu[j] as f64) * (1.0 - (j as f64).ln() / log_n) }
        })
        .collect()
}

/// Diagonal Gram entry: G(j,j) = (ln(2π) - γ)/j - 1/j²
fn gram_diagonal(j: usize) -> f64 {
    let jf = j as f64;
    (LN_2PI - EULER_GAMMA) / jf - 1.0 / (jf * jf)
}

/// Non-cotangent part of off-diagonal
fn gram_offdiag_noncot(j: usize, k: usize) -> f64 {
    let jf = j as f64;
    let kf = k as f64;
    let term1 = (LN_2PI - EULER_GAMMA) / 2.0 * (1.0 / jf + 1.0 / kf);
    let term2 = (jf - kf) / (2.0 * jf * kf) * (kf / jf).ln();
    let term4 = 1.0 / (jf * kf);
    term1 + term2 - term4
}

/// Cotangent part of off-diagonal
fn gram_offdiag_cot(j: usize, k: usize, pair_sums: &HashMap<(usize, usize), f64>) -> f64 {
    let d = gcd(j, k);
    let jp = j / d;
    let kp = k / d;
    let key = if jp <= kp { (jp, kp) } else { (kp, jp) };
    let ps = pair_sums.get(&key).copied().unwrap_or(0.0);
    PI * (d as f64) / (2.0 * j as f64 * k as f64) * ps
}

/// Precompute V(a,b) + V(b,a) for all needed coprime pairs
fn precompute_pair_sums(n: usize, mu: &[i8]) -> HashMap<(usize, usize), f64> {
    let mut needed: Vec<(usize, usize)> = Vec::new();
    let mut seen = std::collections::HashSet::new();
    for j in 1..n {
        if mu[j] == 0 { continue; }
        for k in 1..n {
            if j == k || mu[k] == 0 { continue; }
            let d = gcd(j, k);
            let a = j / d; let b = k / d;
            let key = if a <= b { (a, b) } else { (b, a) };
            if seen.insert(key) { needed.push(key); }
        }
    }
    needed.par_iter()
        .map(|&(a, b)| ((a, b), vasyunin_sum(a, b) + vasyunin_sum(b, a)))
        .collect()
}

/// B₁ skeleton entry: gcd(j,k)² / (12·j·k)
fn b1_entry(j: usize, k: usize) -> f64 {
    let d = gcd(j, k) as f64;
    d * d / (12.0 * j as f64 * k as f64)
}

/// Cholesky decomposition of a positive definite matrix (lower triangular)
fn cholesky(mat: &[f64], n: usize) -> Option<Vec<f64>> {
    let mut l = vec![0.0f64; n * n];
    for j in 0..n {
        let mut s = 0.0;
        for k in 0..j {
            s += l[j * n + k] * l[j * n + k];
        }
        let diag = mat[j * n + j] - s;
        if diag <= 1e-15 { return None; } // Not PD
        l[j * n + j] = diag.sqrt();
        for i in (j + 1)..n {
            let mut s = 0.0;
            for k in 0..j {
                s += l[i * n + k] * l[j * n + k];
            }
            l[i * n + j] = (mat[i * n + j] - s) / l[j * n + j];
        }
    }
    Some(l)
}

/// Solve L·x = b (forward substitution)
fn forward_solve(l: &[f64], b: &[f64], n: usize) -> Vec<f64> {
    let mut x = vec![0.0; n];
    for i in 0..n {
        let mut s = 0.0;
        for j in 0..i { s += l[i * n + j] * x[j]; }
        x[i] = (b[i] - s) / l[i * n + i];
    }
    x
}

/// Solve L^T·x = b (backward substitution)
fn backward_solve(l: &[f64], b: &[f64], n: usize) -> Vec<f64> {
    let mut x = vec![0.0; n];
    for i in (0..n).rev() {
        let mut s = 0.0;
        for j in (i + 1)..n { s += l[j * n + i] * x[j]; }
        x[i] = (b[i] - s) / l[i * n + i];
    }
    x
}

struct F1Result {
    n: usize,
    dim: usize,
    vtgv: f64,
    vt_b1_v: f64,
    vt_l1_v: f64,
    bt_ginv_b: f64,
    d2_opt: f64,
    elapsed: f64,
}

fn analyze_f1(n: usize) -> F1Result {
    let start = Instant::now();
    let dim = n - 1;
    let mu = sieve_mobius(n);
    let v = bd_weights(n, &mu);

    // Precompute pair sums (same as gap_analysis)
    let pair_sums = precompute_pair_sums(n, &mu);

    // Diagonal contribution: Σ v_j² · G(j,j)
    let diag: f64 = (0..dim).map(|i| v[i] * v[i] * gram_diagonal(i + 1)).sum();

    // Off-diagonal: parallel by row (matching gap_analysis exactly)
    let row_results: Vec<(f64, f64, f64)> = (0..dim)
        .into_par_iter()
        .filter(|&i| v[i] != 0.0)
        .map(|i| {
            let j = i + 1;
            let mut row_noncot = 0.0;
            let mut row_cot = 0.0;
            let mut row_b1 = 0.0;

            for k_idx in 0..dim {
                if k_idx == i || v[k_idx] == 0.0 { continue; }
                let k = k_idx + 1;

                row_noncot += v[i] * v[k_idx] * gram_offdiag_noncot(j, k);
                row_cot += v[i] * v[k_idx] * gram_offdiag_cot(j, k, &pair_sums);
                row_b1 += v[i] * v[k_idx] * b1_entry(j, k);
            }
            (row_noncot, row_cot, row_b1)
        })
        .collect();

    let mut off_noncot = 0.0;
    let mut off_cot = 0.0;
    let mut off_b1 = 0.0;
    for &(nc, ct, b1) in &row_results {
        off_noncot += nc;
        off_cot += ct;
        off_b1 += b1;
    }

    // vtGv = diag + off_noncot - off_cot  (matching gap_analysis)
    let vtgv = diag + off_noncot - off_cot;

    // B₁ contribution: diagonal B₁ + off-diagonal B₁
    let diag_b1: f64 = (0..dim).map(|i| v[i] * v[i] * b1_entry(i + 1, i + 1)).sum();
    let vt_b1_v = diag_b1 + off_b1;

    let vt_l1_v = vtgv - vt_b1_v;

    // Compute b^T G⁻¹ b via Cholesky (only for small N)
    let (bt_ginv_b, d2_opt) = if dim <= 2000 {
        // Build full Gram matrix using exact same formula
        let mut g_mat = vec![0.0f64; dim * dim];
        for i in 0..dim {
            g_mat[i * dim + i] = gram_diagonal(i + 1);
            for j in (i + 1)..dim {
                let nc = gram_offdiag_noncot(i + 1, j + 1);
                let ct = gram_offdiag_cot(i + 1, j + 1, &pair_sums);
                let val = nc - ct;
                g_mat[i * dim + j] = val;
                g_mat[j * dim + i] = val;
            }
        }

        // Mean vector: b_j = (1 + ln(2π) - γ) / (2j)
        let b_vec: Vec<f64> = (1..n).map(|j| {
            (1.0 + LN_2PI - EULER_GAMMA) / (2.0 * j as f64)
        }).collect();

        match cholesky(&g_mat, dim) {
            Some(l) => {
                let y = forward_solve(&l, &b_vec, dim);
                let x = backward_solve(&l, &y, dim);
                let btginvb: f64 = (0..dim).map(|i| b_vec[i] * x[i]).sum();
                (btginvb, 1.0 - btginvb)
            }
            None => (-1.0, -1.0) // Cholesky failed
        }
    } else {
        (-1.0, -1.0)
    };

    let elapsed = start.elapsed().as_secs_f64();
    F1Result { n, dim, vtgv, vt_b1_v, vt_l1_v, bt_ginv_b, d2_opt, elapsed }
}

fn main() {
    println!();
    println!("  F₁ DECOMPOSITION: G = B₁ + L₁ and b^T G⁻¹ b  🧗");
    println!("  B₁(j,k) = gcd(j,k)² / (12·j·k)  [Smith/Bernoulli skeleton]");
    println!("  L₁(j,k) = G(j,k) - B₁(j,k)      [perturbation]");
    println!("  Cores: {}", rayon::current_num_threads());
    println!("═══════════════════════════════════════════════════════════════════════════════");
    println!();
    println!("{:>6} │ {:>10} │ {:>10} │ {:>10} │ {:>10} │ {:>10} │ {:>10} │ {:>6}",
        "N", "vtGv", "vt_B1_v", "vt_L1_v", "L1/B1", "b^TG⁻¹b", "d²_opt", "time");
    println!("──────────────────────────────────────────────────────────────────────────────────────");

    let ns: Vec<usize> = vec![
        60, 120, 180, 240, 360, 480, 720, 840, 1000, 1260, 2520,
    ];

    let mut results: Vec<F1Result> = Vec::new();

    for &n in &ns {
        let r = analyze_f1(n);

        let l1_b1_ratio = if r.vt_b1_v.abs() > 1e-15 { r.vt_l1_v / r.vt_b1_v } else { 0.0 };

        println!(
            "{:6} │ {:+10.6} │ {:+10.6} │ {:+10.6} │ {:+10.4} │ {:>10} │ {:>10} │ {:5.1}s",
            r.n, r.vtgv, r.vt_b1_v, r.vt_l1_v, l1_b1_ratio,
            if r.bt_ginv_b >= 0.0 { format!("{:+.6}", r.bt_ginv_b) } else { "FAIL".to_string() },
            if r.d2_opt >= 0.0 { format!("{:+.6}", r.d2_opt) } else { "FAIL".to_string() },
            r.elapsed
        );
        results.push(r);
    }

    // Write TSV output
    let results_dir = "experiments/cotangent-positivity/results";
    fs::create_dir_all(results_dir).unwrap();

    let tsv_path = format!("{}/f1_decomposition.tsv", results_dir);
    let mut f = fs::File::create(&tsv_path).unwrap();
    writeln!(f, "N\tdim\tvtGv\tvt_B1_v\tvt_L1_v\tL1_B1_ratio\tbt_Ginv_b\td2_opt\tmargin").unwrap();
    for r in &results {
        let l1_b1_ratio = if r.vt_b1_v.abs() > 1e-15 { r.vt_l1_v / r.vt_b1_v } else { 0.0 };
        writeln!(f, "{}\t{}\t{:.10}\t{:.10}\t{:.10}\t{:.6}\t{:.10}\t{:.10}\t{:.10}",
            r.n, r.dim, r.vtgv, r.vt_b1_v, r.vt_l1_v, l1_b1_ratio,
            if r.bt_ginv_b >= 0.0 { r.bt_ginv_b } else { f64::NAN },
            if r.d2_opt >= 0.0 { r.d2_opt } else { f64::NAN },
            1.0 - r.vtgv
        ).unwrap();
    }
    println!();
    println!("TSV written to: {}", tsv_path);
}
