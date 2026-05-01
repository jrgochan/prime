//! Particle Zoo Analyzer — Arithmetic Renormalization of d²_N
//!
//! Decomposes the Nyman-Beurling energy E = b^T a* into contributions
//! by ω-class (number of distinct prime factors), measures the Liouville
//! cancellation, and tests the Hardy-Ramanujan envelope fit.

use cathedral_utils::arith::{
    self, b_vector, big_omega, liouville_table, small_omega_table, von_mangoldt, EULER_GAMMA,
};
use std::fs;

/// Load a coefficient TSV file.
/// Format: <index>\t<coefficient>
fn load_coefficients(path: &str) -> Vec<(usize, f64)> {
    let contents = fs::read_to_string(path).expect("Failed to read coefficient file");
    let mut coeffs = Vec::new();
    for line in contents.lines() {
        let line = line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        let parts: Vec<&str> = line.split('\t').collect();
        if parts.len() >= 2 {
            if let (Ok(idx), Ok(val)) = (parts[0].parse::<usize>(), parts[1].parse::<f64>()) {
                coeffs.push((idx, val));
            }
        }
    }
    coeffs
}

/// Run particle zoo analysis on a single dataset
fn analyze(label: &str, coeffs: &[(usize, f64)]) {
    let n_max = coeffs.last().map(|(i, _)| *i).unwrap_or(0);
    let dim = coeffs.len();

    println!("\n{}", "═".repeat(70));
    println!("  PARTICLE ZOO: {} (N={}, dim={})", label, n_max, dim);
    println!("{}", "═".repeat(70));

    // Build lookup arrays indexed by n (2..=n_max)
    let b = b_vector(dim);
    let omega = small_omega_table(n_max);
    let liouville = liouville_table(n_max);
    let lambda_ln_ln = (n_max as f64).ln().ln();

    // Energy decomposition by ω-class
    let max_omega = coeffs.iter().map(|(n, _)| omega[*n] as usize).max().unwrap_or(0);

    let mut e_omega = vec![0.0f64; max_omega + 1];
    let mut count_omega = vec![0usize; max_omega + 1];
    let mut sum_abs_a = vec![0.0f64; max_omega + 1];

    let mut total_energy = 0.0f64;
    let mut e_lio_pos = 0.0f64; // Ω even (λ=+1)
    let mut e_lio_neg = 0.0f64; // Ω odd (λ=-1)

    for (i, &(n, a_n)) in coeffs.iter().enumerate() {
        let b_n = b[i];
        let contrib = a_n * b_n;
        total_energy += contrib;

        let w = omega[n] as usize;
        e_omega[w] += contrib;
        count_omega[w] += 1;
        sum_abs_a[w] += a_n.abs();

        let lio = liouville[n];
        if lio > 0 {
            e_lio_pos += contrib;
        } else {
            e_lio_neg += contrib;
        }
    }

    let d2 = 1.0 - total_energy;
    println!("\n  Total energy E = b^T a* = {:.10}", total_energy);
    println!("  d² = 1 - E = {:.10}", d2);
    println!("  λ = ln ln N = {:.4}", lambda_ln_ln);

    // ── Alternating Series Table ──
    println!("\n  ┌───┬──────────────┬────────────┬────────┬──────────────┬──────────────┐");
    println!("  │ ω │     E_ω      │    |E_ω|   │  count │  partial sum │   gap to 1   │");
    println!("  ├───┼──────────────┼────────────┼────────┼──────────────┼──────────────┤");

    let mut partial = 0.0f64;
    let mut magnitudes: Vec<f64> = Vec::new();
    for w in 1..=max_omega {
        if count_omega[w] == 0 {
            continue;
        }
        partial += e_omega[w];
        let gap = 1.0 - partial;
        let mag = e_omega[w].abs();
        magnitudes.push(mag);

        let sign = if e_omega[w] > 0.0 { "+" } else { "-" };
        let above_below = if partial > 1.0 { "ABOVE" } else { "below" };
        println!(
            "  │ {} │ {}{:11.6} │ {:10.6} │ {:6} │ {:+12.6} │ {:+12.6} ({}) │",
            w, sign, e_omega[w].abs(), mag, count_omega[w], partial, gap, above_below
        );
    }
    println!("  └───┴──────────────┴────────────┴────────┴──────────────┴──────────────┘");

    // ── Leibniz Convergence ──
    println!("\n  Leibniz Test:");
    let decreasing_after_1 = magnitudes
        .windows(2)
        .skip(1)
        .all(|w| w[0] >= w[1]);
    println!("    Magnitudes: {:?}", magnitudes.iter().map(|m| format!("{:.4}", m)).collect::<Vec<_>>());
    if magnitudes.len() > 2 {
        let ratios: Vec<String> = magnitudes
            .windows(2)
            .map(|w| format!("{:.4}", w[1] / w[0]))
            .collect();
        println!("    Ratios |E_(w+1)/E_w|: {:?}", ratios);
    }
    println!("    Decreasing after ω=2? {}", decreasing_after_1);

    // ── Hardy-Ramanujan Fit ──
    println!("\n  Hardy-Ramanujan Envelope Fit:");
    println!("    Testing |E_ω| = A · λ^(ω-1) / (ω-1)!");

    let mut hr_num = 0.0f64;
    let mut hr_den = 0.0f64;
    let mut fit_ws: Vec<usize> = Vec::new();

    for (i, w) in (1..=max_omega).filter(|w| count_omega[*w] > 0).enumerate() {
        let hr_val = lambda_ln_ln.powi((w - 1) as i32) / factorial(w - 1) as f64;
        let m = magnitudes[i];
        hr_num += m * hr_val;
        hr_den += hr_val * hr_val;
        fit_ws.push(w);
    }

    let a_fit = hr_num / hr_den;

    // R²
    let mean_mag = magnitudes.iter().sum::<f64>() / magnitudes.len() as f64;
    let ss_tot: f64 = magnitudes.iter().map(|m| (m - mean_mag).powi(2)).sum();
    let ss_res: f64 = fit_ws
        .iter()
        .enumerate()
        .map(|(i, &w)| {
            let hr = lambda_ln_ln.powi((w - 1) as i32) / factorial(w - 1) as f64;
            (magnitudes[i] - a_fit * hr).powi(2)
        })
        .sum();
    let r2 = if ss_tot > 0.0 { 1.0 - ss_res / ss_tot } else { 0.0 };

    let predicted_net = a_fit * (-lambda_ln_ln).exp();
    println!("    A = {:.4}, R² = {:.6}", a_fit, r2);
    println!("    Predicted E_net = A·e^(-λ) = {:.4} · {:.6} = {:.6}", a_fit, (-lambda_ln_ln).exp(), predicted_net);
    println!("    Actual E_net = {:.6}", total_energy);

    // Per-ω comparison
    println!("\n    ω │   |E_ω|   │  HR = Aλ^(w-1)/(w-1)! │   ratio   ");
    println!("    ──┼───────────┼───────────────────────┼───────────");
    for (i, &w) in fit_ws.iter().enumerate() {
        let hr = a_fit * lambda_ln_ln.powi((w - 1) as i32) / factorial(w - 1) as f64;
        let ratio = magnitudes[i] / hr;
        println!("    {} │ {:9.4} │ {:21.4} │ {:9.4}", w, magnitudes[i], hr, ratio);
    }

    // ── Liouville Cancellation ──
    println!("\n  Liouville Cancellation:");
    let cancel = (e_lio_pos + e_lio_neg).abs() / (e_lio_pos.abs() + e_lio_neg.abs());
    let renorm = (e_lio_pos.abs() + e_lio_neg.abs()) / (e_lio_pos + e_lio_neg).abs();
    println!("    E(Ω even, λ=+1) = {:+.6}", e_lio_pos);
    println!("    E(Ω odd,  λ=-1) = {:+.6}", e_lio_neg);
    println!("    Net              = {:+.6}", e_lio_pos + e_lio_neg);
    println!("    Cancellation     = {:.2}%", cancel * 100.0);
    println!("    Renorm factor    = {:.1}×", renorm);

    // ── Anti-multiplicative ratios ──
    println!("\n  Anti-Multiplicative Structure:");
    let coprime_pairs: &[(usize, usize)] = &[
        (2, 3), (2, 5), (2, 7), (2, 11), (2, 13),
        (3, 5), (3, 7), (3, 11), (3, 13),
        (5, 7), (5, 11), (5, 13),
        (7, 11), (7, 13), (11, 13),
    ];

    let mut ratios_vec = Vec::new();
    for &(p, q) in coprime_pairs {
        let pq = p * q;
        if pq <= n_max {
            let a_p = coeffs.iter().find(|(n, _)| *n == p).map(|(_, a)| *a).unwrap_or(0.0);
            let a_q = coeffs.iter().find(|(n, _)| *n == q).map(|(_, a)| *a).unwrap_or(0.0);
            let a_pq = coeffs.iter().find(|(n, _)| *n == pq).map(|(_, a)| *a).unwrap_or(0.0);
            if a_p.abs() > 1e-15 && a_q.abs() > 1e-15 {
                let ratio = a_pq / (a_p * a_q);
                ratios_vec.push(ratio);
            }
        }
    }
    let mean_ratio: f64 = ratios_vec.iter().sum::<f64>() / ratios_vec.len() as f64;
    println!("    Mean a*(pq)/(a*(p)·a*(q)) = {:.6}", mean_ratio);
    println!("    |1 + ratio| = {:.6}", (1.0 + mean_ratio).abs());

    // ── Von Mangoldt correlation ──
    let mut a_vals = Vec::new();
    let mut lam_vals = Vec::new();
    for &(n, a_n) in coeffs {
        let l = von_mangoldt(n) / (n as f64);
        a_vals.push(a_n);
        lam_vals.push(l);
    }
    let corr = pearson_r(&a_vals, &lam_vals);
    println!("    Corr(a*, Λ(n)/n) = {:.6}", corr);

    // ── Prime energy decay ──
    println!("\n  Prime Coefficient Decay:");
    let is_prime = arith::sieve_primes(n_max);
    let primes_to_show = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 97, 101, 997, 1009];
    for &p in &primes_to_show {
        if p <= n_max {
            if let Some(&(_, a_p)) = coeffs.iter().find(|(n, _)| *n == p) {
                let lnp = (p as f64).ln();
                println!("    a*({:5}) = {:+.6}   ln(p)/p = {:.6}   a*·p/ln(p) = {:.4}", p, a_p, lnp / p as f64, a_p * p as f64 / lnp);
            }
        }
    }

    // ── Dirichlet series ──
    println!("\n  Dirichlet Series Σ a*(n)/n^s:");
    for &s in &[1.0, 1.5, 2.0] {
        let ds: f64 = coeffs.iter().map(|&(n, a)| a / (n as f64).powf(s)).sum();
        println!("    s = {:.1}: {:.8}", s, ds);
    }

    // ── Weighted omega distribution vs Erdős-Kac ──
    println!("\n  ω-Distribution (counts vs Erdős-Kac):");
    for w in 1..=max_omega.min(7) {
        let count = count_omega[w];
        let frac = count as f64 / dim as f64;
        // Hardy-Ramanujan/Erdős-Kac: π_ω(N) ~ N/ln(N) · (ln ln N)^(ω-1) / (ω-1)!
        let n_f = n_max as f64;
        let hr_pred = (n_f / n_f.ln()) * lambda_ln_ln.powi((w - 1) as i32) / factorial(w - 1) as f64;
        let hr_frac = hr_pred / n_f;
        println!("    ω={}: observed {:.4} ({:6})  HR predict {:.4} ({:.0})", w, frac, count, hr_frac, hr_pred);
    }
}

fn factorial(n: usize) -> u64 {
    (1..=n as u64).product::<u64>().max(1)
}

fn pearson_r(x: &[f64], y: &[f64]) -> f64 {
    let n = x.len() as f64;
    let mx = x.iter().sum::<f64>() / n;
    let my = y.iter().sum::<f64>() / n;
    let cov: f64 = x.iter().zip(y).map(|(a, b)| (a - mx) * (b - my)).sum();
    let sx: f64 = x.iter().map(|a| (a - mx).powi(2)).sum::<f64>().sqrt();
    let sy: f64 = y.iter().map(|b| (b - my).powi(2)).sum::<f64>().sqrt();
    if sx * sy < 1e-30 { 0.0 } else { cov / (sx * sy) }
}

fn main() {
    println!("╔══════════════════════════════════════════════════════════════════════╗");
    println!("║     CATHEDRAL PARTICLE ZOO — Arithmetic Renormalization Analyzer    ║");
    println!("╚══════════════════════════════════════════════════════════════════════╝");

    let datasets = [
        ("N=20,000", "experiments/cache/unconstrained_coeffs_N20000.tsv"),
        ("N=40,000", "experiments/cache/unconstrained_coeffs_N40000.tsv"),
    ];

    for (label, path) in &datasets {
        if std::path::Path::new(path).exists() {
            let coeffs = load_coefficients(path);
            if !coeffs.is_empty() {
                analyze(label, &coeffs);
            } else {
                eprintln!("  Warning: {} is empty", path);
            }
        } else {
            eprintln!("  Skipping {} (file not found)", path);
        }
    }

    // ── Cross-N Scaling Summary ──
    println!("\n{}", "═".repeat(70));
    println!("  SCALING SUMMARY");
    println!("{}", "═".repeat(70));

    // Known GPU results
    let gpu_data = [
        (2000usize, 0.04250f64),
        (5000, 0.04087),
        (10000, 0.04064),
        (20000, 0.04036),
        (40000, 0.03999),
    ];

    println!("\n  From GPU Pipeline (DD precision):");
    println!("    {:>7} │ {:>10} │ {:>10} │ {:>10} │ {:>10}", "N", "d²_N", "d²·ln(N)", "1/ln(N)", "C_fit");
    println!("    {}┼{}┼{}┼{}┼{}", "─".repeat(7), "─".repeat(10), "─".repeat(10), "─".repeat(10), "─".repeat(10));
    for &(n, d2) in &gpu_data {
        let ln_n = (n as f64).ln();
        println!("    {:>7} │ {:10.6} │ {:10.4} │ {:10.6} │ {:10.4}",
            n, d2, d2 * ln_n, 1.0 / ln_n, d2 * ln_n);
    }

    // Fit d² = C / ln(N)^alpha
    let ln_d2: Vec<f64> = gpu_data.iter().map(|&(_, d)| d.ln()).collect();
    let ln_ln: Vec<f64> = gpu_data.iter().map(|&(n, _)| (n as f64).ln().ln()).collect();

    // Linear fit: ln(d²) = -α·ln(ln(N)) + ln(C)
    let n_pts = ln_d2.len() as f64;
    let mx = ln_ln.iter().sum::<f64>() / n_pts;
    let my = ln_d2.iter().sum::<f64>() / n_pts;
    let cov: f64 = ln_ln.iter().zip(&ln_d2).map(|(x, y)| (x - mx) * (y - my)).sum();
    let vx: f64 = ln_ln.iter().map(|x| (x - mx).powi(2)).sum();
    let alpha = -cov / vx;
    let ln_c = my + alpha * mx;
    let c = ln_c.exp();

    println!("\n    Fit: d² = {:.4} / ln(N)^{:.4}", c, alpha);
    println!("    If α > 0, then d² → 0 as N → ∞ (consistent with RH)");
    println!("    Current α = {:.4}", alpha);

    // Extrapolations
    println!("\n    Extrapolated d² values:");
    for &n in &[100_000usize, 1_000_000, 10_000_000, 1_000_000_000] {
        let pred = c / (n as f64).ln().powf(alpha);
        println!("      N = {:>12}: d² = {:.6}", n, pred);
    }
}
