// overcancellation-scan/src/bin/d6_anomaly_probe.rs
//
// ╔═══════════════════════════════════════════════════════════════════╗
// ║  d(N)=6 ANOMALY PROBE — Deep Dive into the Alignment Peak       ║
// ║                                                                   ║
// ║  Why do numbers with exactly 6 divisors have 20× higher          ║
// ║  cos²θ alignment than primes?                                    ║
// ║                                                                   ║
// ║  Decomposes d(N)=6 into factorization types:                     ║
// ║    Type A: N = p²q  (e.g., 12=2²·3, 18=2·3², 50=2·5²)         ║
// ║    Type B: N = pqr  (e.g., 30=2·3·5, 42=2·3·7)                 ║
// ║                                                                   ║
// ║  Also tests: does the Entanglement Brake S(N) = Σ v_k/k         ║
// ║  correlate with cos²θ? If the brake controls alignment,          ║
// ║  there may be a provable connection.                              ║
// ╚═══════════════════════════════════════════════════════════════════╝

use cathedral_utils::gram;
use rayon::prelude::*;
use std::time::Instant;

fn is_prime(n: usize) -> bool {
    if n < 2 { return false; }
    if n < 4 { return true; }
    if n % 2 == 0 || n % 3 == 0 { return false; }
    let mut i = 5;
    while i * i <= n {
        if n % i == 0 || n % (i + 2) == 0 { return false; }
        i += 6;
    }
    true
}

fn num_divisors(n: usize) -> usize {
    let mut count = 0;
    let mut d = 1;
    while d * d <= n {
        if n % d == 0 {
            count += 1;
            if d != n / d { count += 1; }
        }
        d += 1;
    }
    count
}

/// Factorize n into prime factors with multiplicities
fn factorize(n: usize) -> Vec<(usize, usize)> {
    let mut factors = Vec::new();
    let mut m = n;
    let mut p = 2;
    while p * p <= m {
        let mut e = 0;
        while m % p == 0 {
            m /= p;
            e += 1;
        }
        if e > 0 { factors.push((p, e)); }
        p += 1;
    }
    if m > 1 { factors.push((m, 1)); }
    factors
}

/// Classify d(N)=6 numbers
fn classify_d6(n: usize) -> &'static str {
    let factors = factorize(n);
    match factors.len() {
        1 => "p^5",         // p⁵ (e.g., 32)
        2 => {
            let exps: Vec<usize> = factors.iter().map(|&(_, e)| e).collect();
            if exps.contains(&2) && exps.contains(&1) {
                "p²q"
            } else {
                "other"
            }
        }
        3 => "pqr",          // three distinct primes
        _ => "other",
    }
}

fn build_gram(n: usize) -> Vec<f64> {
    let dim = n - 1;
    let upper_indices: Vec<(usize, usize)> = (0..dim)
        .flat_map(|j| (j..dim).map(move |k| (j, k)))
        .collect();
    let entries: Vec<(usize, usize, f64)> = upper_indices
        .par_iter()
        .map(|&(j, k)| (j, k, gram::gram_entry_f64(j + 1, k + 1)))
        .collect();
    let mut g = vec![0.0f64; dim * dim];
    for (j, k, val) in entries {
        g[j * dim + k] = val;
        g[k * dim + j] = val;
    }
    g
}

fn lambda_min_with_vec(g_flat: &[f64], dim: usize) -> (f64, Vec<f64>) {
    let mat = nalgebra::DMatrix::from_row_slice(dim, dim, g_flat);
    let eig = mat.symmetric_eigen();
    let mut min_idx = 0;
    let mut min_val = eig.eigenvalues[0];
    for i in 1..dim {
        if eig.eigenvalues[i] < min_val {
            min_val = eig.eigenvalues[i];
            min_idx = i;
        }
    }
    let v: Vec<f64> = (0..dim).map(|r| eig.eigenvectors[(r, min_idx)]).collect();
    (min_val, v)
}

fn dot(a: &[f64], b: &[f64]) -> f64 {
    a.iter().zip(b.iter()).map(|(x, y)| x * y).sum()
}

fn norm_sq(v: &[f64]) -> f64 {
    v.iter().map(|x| x * x).sum()
}

fn extract_submatrix(full: &[f64], full_dim: usize, dim: usize) -> Vec<f64> {
    let mut sub = vec![0.0f64; dim * dim];
    for j in 0..dim {
        for k in 0..dim {
            sub[j * dim + k] = full[j * full_dim + k];
        }
    }
    sub
}

fn main() {
    let t_start = Instant::now();

    println!("╔═══════════════════════════════════════════════════════════════════╗");
    println!("║  d(N)=6 ANOMALY PROBE — Why Is Alignment 20× Higher?            ║");
    println!("║  + Entanglement Brake Correlation                                ║");
    println!("╚═══════════════════════════════════════════════════════════════════╝");
    println!();

    let max_n: usize = 800;
    let start_n: usize = 3;

    let t0 = Instant::now();
    let full_gram = build_gram(max_n);
    let full_dim = max_n - 1;
    println!("  [Built {}×{} Gram matrix in {:.1}s]", full_dim, full_dim, t0.elapsed().as_secs_f64());

    // ══════════════════════════════════════════════════
    // Compute cos²θ, S(N) for all N
    // ══════════════════════════════════════════════════

    struct Record {
        n: usize,
        cos2: f64,
        d_n: usize,
        class: String,
        s_aggregate: f64,  // Σ v_min[k] / (k+1)
        largest_prime_factor: usize,
        smallest_prime_factor: usize,
        gcd_with_prev_prime: usize,
    }

    let mut records: Vec<Record> = Vec::new();
    let mut prev_prime = 2usize;

    println!();
    println!("  {:>5} {:>12} {:>5} {:>6} {:>12} {:>6} {:>6} {:>6}",
        "N", "cos²θ", "d(N)", "class", "S_aggregate", "lpf", "spf", "gcd_p");
    println!("  {}", "─".repeat(75));

    for n in start_n..=max_n {
        let dim = n - 1;
        let prev_dim = dim - 1;

        if prev_dim < 2 { continue; }

        let sub = extract_submatrix(&full_gram, full_dim, dim);
        let prev_sub = extract_submatrix(&full_gram, full_dim, prev_dim);

        // Cross-correlation g
        let g_vec: Vec<f64> = (0..prev_dim).map(|i| sub[i * dim + prev_dim]).collect();
        let g_nsq = norm_sq(&g_vec);

        // v_min of G_{N-1}
        let (_lmin_prev, v_min_prev) = lambda_min_with_vec(&prev_sub, prev_dim);

        // cos²θ
        let cos2 = if g_nsq > 1e-30 {
            let proj = dot(&g_vec, &v_min_prev);
            proj * proj / g_nsq
        } else { 0.0 };

        // Entanglement brake aggregate: S = Σ v_min[k] / (k+1)
        let s_agg: f64 = (0..prev_dim)
            .map(|k| v_min_prev[k] / (k + 1) as f64)
            .sum();

        let dn = num_divisors(n);
        let factors = factorize(n);
        let class = if dn == 6 {
            classify_d6(n).to_string()
        } else if is_prime(n) {
            "prime".to_string()
        } else {
            format!("d={}", dn)
        };

        let lpf = factors.last().map(|&(p, _)| p).unwrap_or(1);
        let spf = factors.first().map(|&(p, _)| p).unwrap_or(1);

        fn gcd(mut a: usize, mut b: usize) -> usize {
            while b != 0 { let t = b; b = a % b; a = t; } a
        }
        let gcd_p = gcd(n, prev_prime);
        if is_prime(n) { prev_prime = n; }

        let show = dn == 6 || is_prime(n) && n <= 200
            || n <= 15 || n % 200 == 0 || n == max_n;

        if show {
            println!("  {:5} {:12.4e} {:5} {:>6} {:12.4e} {:6} {:6} {:6}",
                n, cos2, dn, class, s_agg, lpf, spf, gcd_p);
        }

        records.push(Record { n, cos2, d_n: dn, class, s_aggregate: s_agg,
            largest_prime_factor: lpf, smallest_prime_factor: spf,
            gcd_with_prev_prime: gcd_p });

        if n % 200 == 0 {
            eprintln!("  ... N={} done ({:.0}s total)", n, t_start.elapsed().as_secs_f64());
        }
    }

    // ══════════════════════════════════════════════════
    // ANALYSIS 1: d(N)=6 decomposition
    // ══════════════════════════════════════════════════

    println!();
    println!("══════════════════════════════════════════════════════════════");
    println!("  ANALYSIS 1: d(N)=6 Factorization Decomposition");
    println!("══════════════════════════════════════════════════════════════");

    let d6_records: Vec<&Record> = records.iter()
        .filter(|r| r.d_n == 6 && r.cos2 > 1e-30)
        .collect();

    let p2q: Vec<f64> = d6_records.iter()
        .filter(|r| r.class == "p²q")
        .map(|r| r.cos2)
        .collect();
    let pqr: Vec<f64> = d6_records.iter()
        .filter(|r| r.class == "pqr")
        .map(|r| r.cos2)
        .collect();

    println!();
    println!("  {:>8} {:>8} {:>14} {:>14} {:>10}",
        "Type", "Count", "Mean cos²θ", "Max cos²θ", "Std");

    for (name, data) in &[("p²q", &p2q), ("pqr", &pqr)] {
        if data.is_empty() { continue; }
        let mean: f64 = data.iter().sum::<f64>() / data.len() as f64;
        let max: f64 = data.iter().cloned().fold(0.0f64, f64::max);
        let std: f64 = (data.iter().map(|x| (x - mean).powi(2)).sum::<f64>()
            / data.len() as f64).sqrt();
        println!("  {:>8} {:>8} {:14.4e} {:14.4e} {:10.4e}",
            name, data.len(), mean, max, std);
    }

    // Show the actual d=6 numbers with their cos²θ
    println!();
    println!("  Top 20 d(N)=6 numbers by cos²θ:");
    println!("  {:>5} {:>12} {:>6} {:>30}",
        "N", "cos²θ", "type", "factorization");
    let mut d6_sorted: Vec<&Record> = d6_records.clone();
    d6_sorted.sort_by(|a, b| b.cos2.partial_cmp(&a.cos2).unwrap());
    for r in d6_sorted.iter().take(20) {
        let f: Vec<String> = factorize(r.n).iter()
            .map(|&(p, e)| if e == 1 { format!("{}", p) } else { format!("{}^{}", p, e) })
            .collect();
        println!("  {:5} {:12.4e} {:>6} {:>30}",
            r.n, r.cos2, r.class, f.join(" · "));
    }

    // ══════════════════════════════════════════════════
    // ANALYSIS 2: Entanglement Brake Correlation
    // ══════════════════════════════════════════════════

    println!();
    println!("══════════════════════════════════════════════════════════════");
    println!("  ANALYSIS 2: Entanglement Brake S vs cos²θ");
    println!("══════════════════════════════════════════════════════════════");

    // Compute correlation between |S_aggregate| and cos²θ
    let brake_data: Vec<(f64, f64)> = records.iter()
        .filter(|r| r.n >= 20 && r.cos2 > 1e-30)
        .map(|r| (r.s_aggregate.abs(), r.cos2))
        .collect();

    if brake_data.len() >= 10 {
        let n = brake_data.len() as f64;
        let mx: f64 = brake_data.iter().map(|(x, _)| x).sum::<f64>() / n;
        let my: f64 = brake_data.iter().map(|(_, y)| y).sum::<f64>() / n;
        let cov: f64 = brake_data.iter().map(|(x, y)| (x - mx) * (y - my)).sum::<f64>() / n;
        let sx: f64 = (brake_data.iter().map(|(x, _)| (x - mx).powi(2)).sum::<f64>() / n).sqrt();
        let sy: f64 = (brake_data.iter().map(|(_, y)| (y - my).powi(2)).sum::<f64>() / n).sqrt();
        let corr = if sx > 0.0 && sy > 0.0 { cov / (sx * sy) } else { 0.0 };

        println!();
        println!("  Pearson correlation(|S|, cos²θ) = {:.6}", corr);
        println!("  ({} data points)", brake_data.len());
    }

    // Log-log correlation
    let log_brake: Vec<(f64, f64)> = brake_data.iter()
        .filter(|&&(x, y)| x > 1e-30 && y > 1e-30)
        .map(|&(x, y)| (x.ln(), y.ln()))
        .collect();

    if log_brake.len() >= 10 {
        let n = log_brake.len() as f64;
        let mx: f64 = log_brake.iter().map(|(x, _)| x).sum::<f64>() / n;
        let my: f64 = log_brake.iter().map(|(_, y)| y).sum::<f64>() / n;
        let cov: f64 = log_brake.iter().map(|(x, y)| (x - mx) * (y - my)).sum::<f64>() / n;
        let sx: f64 = (log_brake.iter().map(|(x, _)| (x - mx).powi(2)).sum::<f64>() / n).sqrt();
        let sy: f64 = (log_brake.iter().map(|(_, y)| (y - my).powi(2)).sum::<f64>() / n).sqrt();
        let log_corr = if sx > 0.0 && sy > 0.0 { cov / (sx * sy) } else { 0.0 };

        println!("  Log-log correlation(ln|S|, ln cos²θ) = {:.6}", log_corr);
    }

    // By d(N) group: what is |S| like?
    println!();
    println!("  {:>6} {:>8} {:>14} {:>14}",
        "d(N)", "count", "mean |S|", "mean cos²θ");
    let mut by_dn: std::collections::HashMap<usize, Vec<(f64, f64)>> = std::collections::HashMap::new();
    for r in records.iter().filter(|r| r.n >= 20 && r.cos2 > 1e-30) {
        by_dn.entry(r.d_n).or_default().push((r.s_aggregate.abs(), r.cos2));
    }
    let mut keys: Vec<usize> = by_dn.keys().cloned().collect();
    keys.sort();
    for d in keys {
        let vals = &by_dn[&d];
        if vals.len() >= 3 {
            let ms: f64 = vals.iter().map(|(s, _)| s).sum::<f64>() / vals.len() as f64;
            let mc: f64 = vals.iter().map(|(_, c)| c).sum::<f64>() / vals.len() as f64;
            println!("  {:6} {:8} {:14.4e} {:14.4e}", d, vals.len(), ms, mc);
        }
    }

    // ══════════════════════════════════════════════════
    // ANALYSIS 3: Smallest prime factor effect
    // ══════════════════════════════════════════════════

    println!();
    println!("══════════════════════════════════════════════════════════════");
    println!("  ANALYSIS 3: Smallest Prime Factor vs cos²θ");
    println!("══════════════════════════════════════════════════════════════");

    let mut by_spf: std::collections::HashMap<usize, Vec<f64>> = std::collections::HashMap::new();
    for r in records.iter().filter(|r| r.n >= 20 && !r.class.contains("prime") && r.cos2 > 1e-30) {
        by_spf.entry(r.smallest_prime_factor).or_default().push(r.cos2);
    }
    let mut spf_keys: Vec<usize> = by_spf.keys().cloned().collect();
    spf_keys.sort();

    println!();
    println!("  {:>6} {:>8} {:>14}",
        "spf", "count", "mean cos²θ");
    for spf in spf_keys {
        let vals = &by_spf[&spf];
        if vals.len() >= 3 {
            let mean: f64 = vals.iter().sum::<f64>() / vals.len() as f64;
            println!("  {:6} {:8} {:14.4e}", spf, vals.len(), mean);
        }
    }

    println!();
    println!("  Total runtime: {:.1}s", t_start.elapsed().as_secs_f64());
    println!();
}
