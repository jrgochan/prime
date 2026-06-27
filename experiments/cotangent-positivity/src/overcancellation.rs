use rayon::prelude::*;
use std::collections::HashMap;
use std::f64::consts::PI;
use std::fs;
use std::io::Write;
use std::time::Instant;

const EULER_GAMMA: f64 = 0.5772156649015329;
const LN_2PI: f64 = 1.8378770664093453;

/// Sieve-based Möbius function
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

/// Vasyunin sum V(a,b) = Σ_{m=1}^{a-1} {m·b/a} · cot(π·m/a)
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

/// BD weights: v_j = -μ(j)·(1-lnj/lnN)
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

/// Mean vector: b_k = (ln(k) + 1 - γ) / k
fn mean_entry(k: usize) -> f64 {
    let kf = k as f64;
    (kf.ln() + 1.0 - EULER_GAMMA) / kf
}

/// Diagonal Gram entry: G(j,j) = (ln(2π) - γ)/j - 1/j²
fn gram_diagonal(j: usize) -> f64 {
    let jf = j as f64;
    (LN_2PI - EULER_GAMMA) / jf - 1.0 / (jf * jf)
}

/// Off-diagonal Gram entry (full, not split)
fn gram_offdiag(j: usize, k: usize, pair_sums: &HashMap<(usize, usize), f64>) -> f64 {
    let jf = j as f64;
    let kf = k as f64;
    let d = gcd(j, k);
    let jp = j / d;
    let kp = k / d;

    let term1 = (LN_2PI - EULER_GAMMA) / 2.0 * (1.0 / jf + 1.0 / kf);
    let term2 = (jf - kf) / (2.0 * jf * kf) * (kf / jf).ln();

    // Cotangent term
    let key = if jp <= kp { (jp, kp) } else { (kp, jp) };
    let ps = pair_sums.get(&key).copied().unwrap_or(0.0);
    let term3 = PI * (d as f64) / (2.0 * jf * kf) * ps;

    let term4 = 1.0 / (jf * kf);

    term1 + term2 - term3 - term4
}

/// B₁ entry: gcd(j,k)² / (12·j·k)
fn b1_entry(j: usize, k: usize) -> f64 {
    let d = gcd(j, k) as f64;
    d * d / (12.0 * j as f64 * k as f64)
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

struct OvercancellationResult {
    n: usize,
    dim: usize,
    vtgv: f64,
    vt_b1_v: f64,
    vt_l1_v: f64,
    bt_v: f64,       // bᵀv — the dot product convergence
    d2: f64,          // d²_N = 1 - 2bᵀv + vtGv
    margin_bt: f64,   // 2(1-bᵀv) — the PNT margin
    ratio: f64,       // d²_N / (2(1-bᵀv)) — MUST BE ≤ 1 for vtGv ≤ 1
    elapsed: f64,
}

fn analyze(n: usize) -> OvercancellationResult {
    let start = Instant::now();
    let dim = n - 1;
    let mu = sieve_mobius(n);
    let v = bd_weights(n, &mu);

    let pair_sums = precompute_pair_sums(n, &mu);

    // Diagonal contributions
    let diag_g: f64 = (0..dim).map(|i| v[i] * v[i] * gram_diagonal(i + 1)).sum();
    let diag_b1: f64 = (0..dim).map(|i| v[i] * v[i] * b1_entry(i + 1, i + 1)).sum();

    // bᵀv = Σ b_j · v_j
    let bt_v: f64 = (0..dim).map(|i| mean_entry(i + 1) * v[i]).sum();

    // Off-diagonal: parallel by row
    let row_results: Vec<(f64, f64)> = (0..dim)
        .into_par_iter()
        .filter(|&i| v[i] != 0.0)
        .map(|i| {
            let j = i + 1;
            let mut row_g = 0.0;
            let mut row_b1 = 0.0;

            for k_idx in 0..dim {
                if k_idx == i || v[k_idx] == 0.0 { continue; }
                let k = k_idx + 1;

                row_g += v[i] * v[k_idx] * gram_offdiag(j, k, &pair_sums);
                row_b1 += v[i] * v[k_idx] * b1_entry(j, k);
            }
            (row_g, row_b1)
        })
        .collect();

    let mut off_g = 0.0;
    let mut off_b1 = 0.0;
    for &(g, b1) in &row_results {
        off_g += g;
        off_b1 += b1;
    }

    let vtgv = diag_g + off_g;
    let vt_b1_v = diag_b1 + off_b1;
    let vt_l1_v = vtgv - vt_b1_v;

    let d2 = 1.0 - 2.0 * bt_v + vtgv;
    let margin_bt = 2.0 * (1.0 - bt_v);
    let ratio = if margin_bt.abs() > 1e-15 { d2 / margin_bt } else { f64::NAN };

    let elapsed = start.elapsed().as_secs_f64();
    OvercancellationResult {
        n, dim, vtgv, vt_b1_v, vt_l1_v, bt_v, d2, margin_bt, ratio, elapsed,
    }
}

fn main() {
    println!();
    println!("  OVERCANCELLATION PROBE: vtGv = 2·bᵀv - 1 + d²  🏰");
    println!("  vtGv ≤ 1  ⟺  d² ≤ 2·(1-bᵀv)  ⟺  ratio ≤ 1");
    println!("  Cores: {}", rayon::current_num_threads());
    println!("═══════════════════════════════════════════════════════════════════════════════════════════════════");
    println!();
    println!("{:>6} │ {:>10} │ {:>10} │ {:>10} │ {:>10} │ {:>10} │ {:>10} │ {:>8} │ {:>6}",
        "N", "vtGv", "vt_B1_v", "vt_L1_v", "bᵀv", "d²_N", "2(1-bᵀv)", "ratio", "time");
    println!("────────────────────────────────────────────────────────────────────────────────────────────────────");

    let ns: Vec<usize> = vec![
        60, 120, 180, 240, 360, 480, 720, 840, 1000, 1260,
        1680, 2520, 5040, 7560, 10080, 15120, 20160, 25200,
        30240, 40320, 50400,
    ];

    let mut results: Vec<OvercancellationResult> = Vec::new();

    for &n in &ns {
        let r = analyze(n);

        let _vtgv_ok = if r.vtgv <= 1.0 { "✓" } else { "✗" };
        let ratio_ok = if r.ratio <= 1.0 { "✓" } else { "✗" };

        println!(
            "{:6} │ {:+10.6} │ {:+10.6} │ {:+10.6} │ {:+10.6} │ {:+10.6} │ {:+10.6} │ {:7.4}{} │ {:5.1}s",
            r.n, r.vtgv, r.vt_b1_v, r.vt_l1_v, r.bt_v, r.d2, r.margin_bt,
            r.ratio, ratio_ok, r.elapsed
        );
        results.push(r);
    }

    // Write TSV output
    let results_dir = "experiments/cotangent-positivity/results";
    fs::create_dir_all(results_dir).unwrap();

    let tsv_path = format!("{}/overcancellation.tsv", results_dir);
    let mut f = fs::File::create(&tsv_path).unwrap();
    writeln!(f, "N\tdim\tvtGv\tvt_B1_v\tvt_L1_v\tbt_v\td2_N\tmargin_bt\tratio\tmargin_vtGv").unwrap();
    for r in &results {
        writeln!(f, "{}\t{}\t{:.10}\t{:.10}\t{:.10}\t{:.10}\t{:.10}\t{:.10}\t{:.10}\t{:.10}",
            r.n, r.dim, r.vtgv, r.vt_b1_v, r.vt_l1_v, r.bt_v, r.d2, r.margin_bt,
            r.ratio, 1.0 - r.vtgv
        ).unwrap();
    }

    println!();
    println!("═══════════════════════════════════════════════════════════════════════════════════════════════════");
    println!();
    println!("  KEY: ratio = d²_N / 2(1-bᵀv)");
    println!("       vtGv ≤ 1  ⟺  ratio ≤ 1");
    println!("       If ratio is DECREASING, overcancellation axiom likely holds for all N.");
    println!();
    println!("TSV written to: {}", tsv_path);
}
