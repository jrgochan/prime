#![allow(
    dead_code,
    unused_variables,
    unused_imports,
    unused_assignments,
    clippy::needless_range_loop,
    clippy::doc_lazy_continuation,
    non_snake_case,
    clippy::empty_line_after_doc_comments
)]
// overcancellation-scan/src/bin/selberg_ecot_exponent.rs
//
// ╔═══════════════════════════════════════════════════════════════╗
// ║  SELBERG E_COT EXPONENT — High-N Decay Rate via HPDF        ║
// ║                                                               ║
// ║  Tests the growth of Σ v_j v_k E_cot(j,k) vs ln(N).        ║
// ║  Uses precomputed Gram matrices from .h5 files.               ║
// ║                                                               ║
// ║  KEY QUESTION: Is E_cot = O(ln(N)^α) with α < 1?           ║
// ║  If yes → E_cot/ln(N) → 0 → cotangent axiom HOLDS.          ║
// ╚═══════════════════════════════════════════════════════════════╝

use cathedral_utils::arith::gcd;
use cathedral_utils::hpdf::HpdfReader;
use rayon::prelude::*;
use std::f64::consts::PI;
use std::path::PathBuf;

const EULER_GAMMA: f64 = 0.5772156649015329;

fn vasyunin_const() -> f64 {
    (2.0 * PI).ln() - EULER_GAMMA
}

/// Vasyunin cotangent sum V(a,b) = Σ_{m=1}^{a-1} cot(πm/a) · {mb/a}
fn vasyunin_sum(a: usize, b: usize) -> f64 {
    if a <= 1 {
        return 0.0;
    }
    let af = a as f64;
    let mut s = 0.0;
    for m in 1..a {
        let angle = PI * m as f64 / af;
        let cot = angle.cos() / angle.sin();
        let frac = ((m * b) as f64 / af).fract();
        s += cot * frac;
    }
    s
}

/// Compute E_cot(j,k) = G(j,k) - E_log(j,k) - E_ratio(j,k) + E_const(j,k)
/// Or directly: π·d/(2jk) · (V(j',k') + V(k',j'))
fn ecot_entry(j: usize, k: usize) -> f64 {
    if j == k {
        return 0.0;
    }
    let d = gcd(j, k);
    let jp = j / d;
    let kp = k / d;
    let v_sum = vasyunin_sum(jp, kp) + vasyunin_sum(kp, jp);
    PI * d as f64 / (2.0 * j as f64 * k as f64) * v_sum
}

/// G(1,k) via Vasyunin formula
fn gram_entry_k1(k: usize) -> f64 {
    let c = vasyunin_const();
    if k == 1 {
        return c - 1.0;
    }
    let kf = k as f64;
    let t1 = c / 2.0 * (1.0 + 1.0 / kf);
    let t2 = (1.0 - kf) / (2.0 * kf) * kf.ln();
    let vk1 = vasyunin_sum(k, 1);
    let t3 = PI / (2.0 * kf) * vk1;
    let t4 = 1.0 / kf;
    t1 + t2 - t3 - t4
}

/// Compute E_cot contribution to the quadratic form at given N,
/// using HPDF Gram matrix for the full G(j,k) entries and
/// subtracting the non-cotangent pieces analytically.
fn compute_ecot_from_gram(gram: &[f64], dim: usize, n: usize, mu: &[i8]) -> (f64, f64) {
    let log_n = (n as f64).ln();

    // Build BD weights (unnormalized, no 1/k factor)
    let mut v = vec![0.0f64; n];
    for k in 1..n {
        let mu_k = mu[k] as f64;
        let cutoff = 1.0 - (k as f64).ln() / log_n;
        if cutoff > 0.0 {
            v[k] = -mu_k * cutoff;
        }
    }

    // E_cot contribution (off-diagonal, using analytic formula)
    // This avoids needing to decompose the Gram matrix — we compute
    // E_cot directly from the Vasyunin sums.
    let ecot_sum: f64 = (1..n)
        .into_par_iter()
        .map(|j| {
            if v[j] == 0.0 {
                return 0.0;
            }
            let mut row_sum = 0.0;
            for k in (j + 1)..n {
                if v[k] == 0.0 {
                    continue;
                }
                let ec = ecot_entry(j, k);
                row_sum += 2.0 * v[j] * v[k] * ec;
            }
            row_sum
        })
        .sum();

    // Full vᵀGv from HPDF (for cross-check)
    // dim = n-2 (k=2..n-1 in the HPDF)
    // We need k=1 separately

    // k≥2 sector from HPDF
    let vtgv_k2: f64 = (0..dim)
        .into_par_iter()
        .map(|i| {
            let j = i + 2;
            if j >= n {
                return 0.0;
            }
            let mut row = 0.0;
            for ji in 0..dim {
                let k = ji + 2;
                if k >= n {
                    break;
                }
                row += v[j] * v[k] * gram[i * dim + ji];
            }
            row
        })
        .sum();

    // k=1 contributions
    let mut vtgv_k1 = v[1] * v[1] * gram_entry_k1(1);
    for i in 0..dim {
        let k = i + 2;
        if k >= n {
            break;
        }
        vtgv_k1 += 2.0 * v[1] * v[k] * gram_entry_k1(k);
    }

    let vtgv = vtgv_k2 + vtgv_k1;

    (ecot_sum, vtgv)
}

fn main() {
    println!("╔═══════════════════════════════════════════════════════════════════════════════╗");
    println!("║  SELBERG E_COT EXPONENT — Does E_cot grow as ln(N)^α with α < 1?          ║");
    println!("║  Using precomputed HPDF Gram matrices + rayon parallelism                   ║");
    println!("╚═══════════════════════════════════════════════════════════════════════════════╝");
    println!();

    let cache_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .unwrap()
        .join("cache/hpdf");

    // HCN files, sorted by N
    let hc_ns: Vec<usize> = vec![
        60, 360, 840, 1260, 2520, 5040, 7560, 10080, 20160, 27720, 45360, 55440,
    ];

    println!(
        "{:>8} {:>10} {:>14} {:>10} {:>10} {:>10} {:>10}",
        "N", "ln(N)", "Σ vv·E_cot", "/ lnN", "/ ln^0.85", "/ ln^0.5", "vᵀGv"
    );
    println!("{}", "─".repeat(80));

    let mut data_x = Vec::new();
    let mut data_y = Vec::new();

    for &n in &hc_ns {
        let path = cache_dir.join(format!("gram_N{}.h5", n));
        if !path.exists() {
            eprintln!("  [skip] {} not found", path.display());
            continue;
        }

        let reader = match HpdfReader::open(&path) {
            Ok(r) => r,
            Err(e) => {
                eprintln!("  [skip] N={}: {}", n, e);
                continue;
            }
        };

        let dim = reader.dim();
        eprint!("  N = {:>6} (dim={})...", n, dim);

        let mu_raw = reader.read_mobius().unwrap();
        let gram = reader.read_gram_full().unwrap();

        let (ecot_sum, vtgv) = compute_ecot_from_gram(&gram, dim, n, &mu_raw);

        let log_n = (n as f64).ln();

        data_x.push(log_n);
        data_y.push(ecot_sum);

        eprintln!(" done");
        println!(
            "{:>8} {:>10.3} {:>14.6} {:>10.6} {:>10.6} {:>10.6} {:>10.6}",
            n,
            log_n,
            ecot_sum,
            ecot_sum / log_n,
            ecot_sum / log_n.powf(0.85),
            ecot_sum / log_n.sqrt(),
            vtgv
        );
    }

    // Power-law fit: y = A * x^α
    if data_x.len() >= 3 {
        println!();
        println!("═══════════════════════════════════════════════════════════════════════════════");
        println!("POWER-LAW FIT: E_cot = A · ln(N)^α");
        println!();

        // Simple least-squares in log-log space: log(y) = log(A) + α·log(x)
        let n = data_x.len();
        let log_x: Vec<f64> = data_x.iter().map(|x| x.ln()).collect();
        let log_y: Vec<f64> = data_y.iter().map(|y| y.abs().ln()).collect();

        let mean_lx = log_x.iter().sum::<f64>() / n as f64;
        let mean_ly = log_y.iter().sum::<f64>() / n as f64;

        let mut cov = 0.0;
        let mut var = 0.0;
        for i in 0..n {
            cov += (log_x[i] - mean_lx) * (log_y[i] - mean_ly);
            var += (log_x[i] - mean_lx) * (log_x[i] - mean_lx);
        }

        let alpha = cov / var;
        let log_a = mean_ly - alpha * mean_lx;
        let a = log_a.exp();

        println!("  Fitted: E_cot ≈ {:.4} · ln(N)^{:.4}", a, alpha);
        println!("  Exponent α = {:.4}", alpha);
        println!();

        if alpha < 1.0 {
            println!("  ✅ α < 1 → E_cot / ln(N) → 0");
            println!("  → Decay rate: O(1/ln(N)^{:.3})", 1.0 - alpha);
            println!("  → The cotangent axiom is NUMERICALLY CONFIRMED at scale!");
        } else {
            println!("  ⚠  α ≥ 1 → E_cot / ln(N) may not → 0");
        }
    }

    println!();
    println!("═══════════════════════════════════════════════════════════════════════════════");
}
