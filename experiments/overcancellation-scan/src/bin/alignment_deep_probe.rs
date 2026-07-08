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
// overcancellation-scan/src/bin/alignment_deep_probe.rs
//
// ╔═══════════════════════════════════════════════════════════════════╗
// ║  ALIGNMENT DEEP PROBE — cos²θ vs |S| Power Law + Spectral Gaps  ║
// ║                                                                   ║
// ║  Three concurrent analyses:                                       ║
// ║                                                                   ║
// ║  A) FIT the power law cos²θ ~ C·|S|^γ exactly                   ║
// ║     → What is γ? Is it universal or N-dependent?                 ║
// ║                                                                   ║
// ║  B) SPECTRAL GAP RATIOS λ₁/λ₃, λ₁/λ_min                       ║
// ║     → How does the condition number grow?                        ║
// ║     → Does λ₁/λ₃ predict cos²θ?                                ║
// ║                                                                   ║
// ║  C) TIME-BRIDGE DECOMPOSITION                                    ║
// ║     → How much of G comes from Ramanujan mean M vs error E?     ║
// ║     → Does the E/M ratio predict alignment?                      ║
// ╚═══════════════════════════════════════════════════════════════════╝

use cathedral_utils::arith::gcd;
use cathedral_utils::gram;
use rayon::prelude::*;
use std::time::Instant;

fn is_prime(n: usize) -> bool {
    if n < 2 {
        return false;
    }
    if n < 4 {
        return true;
    }
    if n.is_multiple_of(2) || n.is_multiple_of(3) {
        return false;
    }
    let mut i = 5;
    while i * i <= n {
        if n.is_multiple_of(i) || n.is_multiple_of(i + 2) {
            return false;
        }
        i += 6;
    }
    true
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

fn full_eigen_sorted(g_flat: &[f64], dim: usize) -> (Vec<f64>, nalgebra::DMatrix<f64>) {
    let mat = nalgebra::DMatrix::from_row_slice(dim, dim, g_flat);
    let eig = mat.symmetric_eigen();
    let mut indexed: Vec<(usize, f64)> = eig.eigenvalues.iter().cloned().enumerate().collect();
    indexed.sort_by(|a, b| a.1.partial_cmp(&b.1).unwrap());
    let sorted_vals: Vec<f64> = indexed.iter().map(|(_, v)| *v).collect();
    (sorted_vals, eig.eigenvectors)
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

/// Ramanujan entry R(j,k) = Σ_{d|gcd(j,k)} μ(j/d)μ(k/d)φ(d)/d²
/// Simplified: for the mean M(j,k) = R(j,k) + 1/4
/// Using the exact formula: mean of {t/j}{t/k} over [0, lcm(j,k)]
fn ramanujan_mean(j: usize, k: usize) -> f64 {
    let l = j * k / gcd(j, k); // lcm
    let lf = l as f64;
    let jf = j as f64;
    let kf = k as f64;

    // Compute mean of {t/j}{t/k} over one period [0, lcm(j,k)]
    // by numerical quadrature (exact for piecewise-polynomial)
    let steps = l * 4; // 4 substeps per unit
    let dt = lf / steps as f64;
    let mut sum = 0.0;
    for s in 0..steps {
        let t = (s as f64 + 0.5) * dt;
        let fj = (t / jf).fract();
        let fk = (t / kf).fract();
        sum += fj * fk * dt;
    }
    sum / lf
}

fn main() {
    let t_start = Instant::now();

    println!("╔═══════════════════════════════════════════════════════════════════╗");
    println!("║  ALIGNMENT DEEP PROBE — Power Law γ + Spectral Gap Ratios       ║");
    println!("╚═══════════════════════════════════════════════════════════════════╝");
    println!();

    let max_n: usize = 600;
    let start_n: usize = 4;

    let t0 = Instant::now();
    let full_gram = build_gram(max_n);
    let full_dim = max_n - 1;
    println!(
        "  [Built {}×{} Gram matrix in {:.1}s]",
        full_dim,
        full_dim,
        t0.elapsed().as_secs_f64()
    );

    // ══════════════════════════════════════════════════
    // Collect data for all N
    // ══════════════════════════════════════════════════

    struct Record {
        n: usize,
        cos2: f64,
        s_brake: f64, // Entanglement brake aggregate |S|
        lambda_min: f64,
        lambda_1: f64,  // largest eigenvalue
        lambda_3: f64,  // 3rd largest eigenvalue
        condition: f64, // λ_max / λ_min
        ratio_1_3: f64, // λ₁ / λ₃
        gap_2_1: f64,   // λ₂ - λ₁ (nearest spacing at bottom)
        eigen_drop: f64,
    }

    let mut records: Vec<Record> = Vec::new();
    let mut prev_lmin = 0.0f64;

    println!();
    println!(
        "  {:>5} {:>10} {:>10} {:>10} {:>10} {:>10} {:>10} {:>10} {:>10}",
        "N", "cos²θ", "|S|", "λ_min", "λ₁", "λ₃", "λ₁/λ₃", "κ", "δ_N"
    );
    println!("  {}", "─".repeat(95));

    for n in start_n..=max_n {
        let dim = n - 1;
        let prev_dim = dim - 1;
        if prev_dim < 2 {
            continue;
        }

        let sub = extract_submatrix(&full_gram, full_dim, dim);

        // Full eigendecomposition (sorted ascending)
        let (eigenvals, _eigvecs) = full_eigen_sorted(&sub, dim);
        let lmin = eigenvals[0];
        let lmin2 = if dim >= 2 { eigenvals[1] } else { lmin };
        let lmax = eigenvals[dim - 1];
        let l3 = if dim >= 3 { eigenvals[dim - 3] } else { lmax }; // 3rd from top

        // cos²θ: projection of g onto v_min of G_{N-1}
        let g_vec: Vec<f64> = (0..prev_dim).map(|i| sub[i * dim + prev_dim]).collect();
        let g_nsq = norm_sq(&g_vec);

        let prev_sub = extract_submatrix(&full_gram, full_dim, prev_dim);
        let (_lmin_prev, v_min_prev) = lambda_min_with_vec(&prev_sub, prev_dim);

        let cos2 = if g_nsq > 1e-30 {
            let proj = dot(&g_vec, &v_min_prev);
            proj * proj / g_nsq
        } else {
            0.0
        };

        // Brake aggregate
        let s_brake: f64 = (0..prev_dim)
            .map(|k| v_min_prev[k] / (k + 1) as f64)
            .sum::<f64>()
            .abs();

        let drop = if n > start_n {
            (prev_lmin - lmin).max(0.0)
        } else {
            0.0
        };

        let condition = if lmin > 0.0 {
            lmax / lmin
        } else {
            f64::INFINITY
        };
        let ratio_1_3 = if l3 > 0.0 { lmax / l3 } else { 0.0 };
        let gap_2_1 = lmin2 - lmin;

        let show = n <= 15 || n % 50 == 0 || n == max_n || is_prime(n) && n <= 100;
        if show {
            println!(
                "  {:5} {:10.2e} {:10.2e} {:10.2e} {:10.4} {:10.4} {:10.4} {:10.1} {:10.2e}",
                n, cos2, s_brake, lmin, lmax, l3, ratio_1_3, condition, drop
            );
        }

        records.push(Record {
            n,
            cos2,
            s_brake,
            lambda_min: lmin,
            lambda_1: lmax,
            lambda_3: l3,
            condition,
            ratio_1_3,
            gap_2_1,
            eigen_drop: drop,
        });

        prev_lmin = lmin;
        if n % 100 == 0 {
            eprintln!("  ... N={} ({:.0}s)", n, t_start.elapsed().as_secs_f64());
        }
    }

    // ══════════════════════════════════════════════════
    // ANALYSIS A: cos²θ ~ C·|S|^γ power law fit
    // ══════════════════════════════════════════════════

    println!();
    println!("══════════════════════════════════════════════════════════════");
    println!("  ANALYSIS A: cos²θ vs |S| — Fitting cos²θ ≈ C·|S|^γ");
    println!("══════════════════════════════════════════════════════════════");

    let brake_pairs: Vec<(f64, f64)> = records
        .iter()
        .filter(|r| r.n >= 20 && r.cos2 > 1e-30 && r.s_brake > 1e-30)
        .map(|r| (r.s_brake, r.cos2))
        .collect();

    if brake_pairs.len() >= 10 {
        // Log-log linear regression: ln(cos²θ) = γ·ln|S| + ln C
        let n = brake_pairs.len() as f64;
        let lx: Vec<f64> = brake_pairs.iter().map(|(s, _)| s.ln()).collect();
        let ly: Vec<f64> = brake_pairs.iter().map(|(_, c)| c.ln()).collect();
        let sx: f64 = lx.iter().sum();
        let sy: f64 = ly.iter().sum();
        let sxy: f64 = lx.iter().zip(ly.iter()).map(|(x, y)| x * y).sum();
        let sx2: f64 = lx.iter().map(|x| x * x).sum();
        let gamma = (n * sxy - sx * sy) / (n * sx2 - sx * sx);
        let ln_c = (sy - gamma * sx) / n;
        let c_coeff = ln_c.exp();
        let mean_y = sy / n;
        let ss_tot: f64 = ly.iter().map(|y| (y - mean_y).powi(2)).sum();
        let ss_res: f64 = lx
            .iter()
            .zip(ly.iter())
            .map(|(x, y)| (y - (gamma * x + ln_c)).powi(2))
            .sum();
        let r2 = 1.0 - ss_res / ss_tot;

        println!();
        println!(
            "  FULL FIT (N≥20): cos²θ ≈ {:.4e} · |S|^{:.4}    R² = {:.6}",
            c_coeff, gamma, r2
        );

        // Window fits to check stability
        for &(lo, hi) in &[(20, 100), (100, 200), (200, 400), (400, 600)] {
            let window: Vec<(f64, f64)> = records
                .iter()
                .filter(|r| r.n >= lo && r.n < hi && r.cos2 > 1e-30 && r.s_brake > 1e-30)
                .map(|r| (r.s_brake, r.cos2))
                .collect();
            if window.len() >= 10 {
                let n = window.len() as f64;
                let lx: Vec<f64> = window.iter().map(|(s, _)| s.ln()).collect();
                let ly: Vec<f64> = window.iter().map(|(_, c)| c.ln()).collect();
                let sx: f64 = lx.iter().sum();
                let sy: f64 = ly.iter().sum();
                let sxy: f64 = lx.iter().zip(ly.iter()).map(|(x, y)| x * y).sum();
                let sx2: f64 = lx.iter().map(|x| x * x).sum();
                let g = (n * sxy - sx * sy) / (n * sx2 - sx * sx);
                let lc = (sy - g * sx) / n;
                let my = sy / n;
                let st: f64 = ly.iter().map(|y| (y - my).powi(2)).sum();
                let sr: f64 = lx
                    .iter()
                    .zip(ly.iter())
                    .map(|(x, y)| (y - (g * x + lc)).powi(2))
                    .sum();
                let r2w = 1.0 - sr / st;
                println!(
                    "  [{:>3},{:>3}): γ = {:.4},  C = {:.4e},  R² = {:.4}  ({} pts)",
                    lo,
                    hi,
                    g,
                    lc.exp(),
                    r2w,
                    window.len()
                );
            }
        }

        // Prime vs composite γ
        for (label, filter_fn) in &[("PRIMES", true), ("COMPS", false)] {
            let subset: Vec<(f64, f64)> = records
                .iter()
                .filter(|r| {
                    r.n >= 20 && r.cos2 > 1e-30 && r.s_brake > 1e-30 && is_prime(r.n) == *filter_fn
                })
                .map(|r| (r.s_brake, r.cos2))
                .collect();
            if subset.len() >= 10 {
                let n = subset.len() as f64;
                let lx: Vec<f64> = subset.iter().map(|(s, _)| s.ln()).collect();
                let ly: Vec<f64> = subset.iter().map(|(_, c)| c.ln()).collect();
                let sx: f64 = lx.iter().sum();
                let sy: f64 = ly.iter().sum();
                let sxy: f64 = lx.iter().zip(ly.iter()).map(|(x, y)| x * y).sum();
                let sx2: f64 = lx.iter().map(|x| x * x).sum();
                let g = (n * sxy - sx * sy) / (n * sx2 - sx * sx);
                let lc = (sy - g * sx) / n;
                let my = sy / n;
                let st: f64 = ly.iter().map(|y| (y - my).powi(2)).sum();
                let sr: f64 = lx
                    .iter()
                    .zip(ly.iter())
                    .map(|(x, y)| (y - (g * x + lc)).powi(2))
                    .sum();
                let r2w = 1.0 - sr / st;
                println!(
                    "  {:>6}: γ = {:.4},  C = {:.4e},  R² = {:.4}  ({} pts)",
                    label,
                    g,
                    lc.exp(),
                    r2w,
                    subset.len()
                );
            }
        }
    }

    // ══════════════════════════════════════════════════
    // ANALYSIS B: Spectral Gap Ratios
    // ══════════════════════════════════════════════════

    println!();
    println!("══════════════════════════════════════════════════════════════");
    println!("  ANALYSIS B: Spectral Gap Ratios λ₁/λ₃ and Condition Number");
    println!("══════════════════════════════════════════════════════════════");

    // λ₁/λ₃ scaling
    let ratio_data: Vec<(f64, f64)> = records
        .iter()
        .filter(|r| r.n >= 10 && r.ratio_1_3 > 0.0)
        .map(|r| (r.n as f64, r.ratio_1_3))
        .collect();

    if ratio_data.len() >= 10 {
        // Does λ₁/λ₃ converge?
        let last_10: Vec<f64> = ratio_data.iter().rev().take(10).map(|(_, r)| *r).collect();
        let mean_last: f64 = last_10.iter().sum::<f64>() / 10.0;
        let std_last: f64 =
            (last_10.iter().map(|x| (x - mean_last).powi(2)).sum::<f64>() / 10.0).sqrt();

        println!();
        println!(
            "  λ₁/λ₃ (last 10 values): mean = {:.6}, std = {:.6}, CV = {:.4}",
            mean_last,
            std_last,
            std_last / mean_last
        );
    }

    // Print λ₁/λ₃ trend
    println!();
    println!(
        "  {:>5} {:>10} {:>12} {:>10}",
        "N", "λ₁/λ₃", "κ (cond#)", "gap₂-₁"
    );
    println!("  {}", "─".repeat(45));
    for r in records
        .iter()
        .filter(|r| r.n % 50 == 0 || r.n <= 10 || r.n == max_n)
    {
        println!(
            "  {:5} {:10.6} {:12.1} {:10.2e}",
            r.n, r.ratio_1_3, r.condition, r.gap_2_1
        );
    }

    // Correlation: λ₁/λ₃ vs cos²θ
    let gap_cos2_data: Vec<(f64, f64)> = records
        .iter()
        .filter(|r| r.n >= 20 && r.cos2 > 1e-30 && r.ratio_1_3 > 0.0)
        .map(|r| (r.ratio_1_3, r.cos2))
        .collect();

    if gap_cos2_data.len() >= 10 {
        let n = gap_cos2_data.len() as f64;
        let lx: Vec<f64> = gap_cos2_data.iter().map(|(r, _)| r.ln()).collect();
        let ly: Vec<f64> = gap_cos2_data.iter().map(|(_, c)| c.ln()).collect();
        let mx = lx.iter().sum::<f64>() / n;
        let my = ly.iter().sum::<f64>() / n;
        let cov: f64 = lx
            .iter()
            .zip(ly.iter())
            .map(|(x, y)| (x - mx) * (y - my))
            .sum::<f64>()
            / n;
        let sx = (lx.iter().map(|x| (x - mx).powi(2)).sum::<f64>() / n).sqrt();
        let sy = (ly.iter().map(|y| (y - my).powi(2)).sum::<f64>() / n).sqrt();
        let corr = if sx > 0.0 && sy > 0.0 {
            cov / (sx * sy)
        } else {
            0.0
        };

        println!();
        println!("  Log-log corr(ln(λ₁/λ₃), ln cos²θ) = {:.6}", corr);
    }

    // ══════════════════════════════════════════════════
    // ANALYSIS C: Gap₂₁ spacing statistics
    // ══════════════════════════════════════════════════

    println!();
    println!("══════════════════════════════════════════════════════════════");
    println!("  ANALYSIS C: Bottom Eigenvalue Spacing λ₂-λ₁ vs cos²θ");
    println!("══════════════════════════════════════════════════════════════");

    // Does the gap between λ_min and λ_{min+1} predict alignment?
    let gap_data: Vec<(f64, f64)> = records
        .iter()
        .filter(|r| r.n >= 20 && r.cos2 > 1e-30 && r.gap_2_1 > 1e-30)
        .map(|r| (r.gap_2_1, r.cos2))
        .collect();

    if gap_data.len() >= 10 {
        let n = gap_data.len() as f64;
        let lx: Vec<f64> = gap_data.iter().map(|(g, _)| g.ln()).collect();
        let ly: Vec<f64> = gap_data.iter().map(|(_, c)| c.ln()).collect();
        let mx = lx.iter().sum::<f64>() / n;
        let my = ly.iter().sum::<f64>() / n;
        let cov: f64 = lx
            .iter()
            .zip(ly.iter())
            .map(|(x, y)| (x - mx) * (y - my))
            .sum::<f64>()
            / n;
        let sx = (lx.iter().map(|x| (x - mx).powi(2)).sum::<f64>() / n).sqrt();
        let sy = (ly.iter().map(|y| (y - my).powi(2)).sum::<f64>() / n).sqrt();
        let corr = if sx > 0.0 && sy > 0.0 {
            cov / (sx * sy)
        } else {
            0.0
        };

        println!();
        println!("  Log-log corr(ln(λ₂-λ₁), ln cos²θ) = {:.6}", corr);
    }

    // ══════════════════════════════════════════════════
    // ANALYSIS D: Multi-predictor summary
    // ══════════════════════════════════════════════════

    println!();
    println!("══════════════════════════════════════════════════════════════");
    println!("  ANALYSIS D: All Correlations with cos²θ");
    println!("══════════════════════════════════════════════════════════════");
    println!();

    // Compute correlations of cos²θ with everything
    let filtered: Vec<&Record> = records
        .iter()
        .filter(|r| r.n >= 30 && r.cos2 > 1e-30)
        .collect();

    if filtered.len() >= 20 {
        let ln_cos2: Vec<f64> = filtered.iter().map(|r| r.cos2.ln()).collect();
        let predictors: Vec<(&str, Vec<f64>)> = vec![
            (
                "ln|S| (brake)",
                filtered
                    .iter()
                    .map(|r| {
                        if r.s_brake > 1e-30 {
                            r.s_brake.ln()
                        } else {
                            -70.0
                        }
                    })
                    .collect(),
            ),
            (
                "ln(λ₁/λ₃)",
                filtered
                    .iter()
                    .map(|r| {
                        if r.ratio_1_3 > 0.0 {
                            r.ratio_1_3.ln()
                        } else {
                            0.0
                        }
                    })
                    .collect(),
            ),
            (
                "ln(λ₂-λ₁)",
                filtered
                    .iter()
                    .map(|r| {
                        if r.gap_2_1 > 1e-30 {
                            r.gap_2_1.ln()
                        } else {
                            -70.0
                        }
                    })
                    .collect(),
            ),
            (
                "ln(κ)",
                filtered
                    .iter()
                    .map(|r| {
                        if r.condition > 0.0 {
                            r.condition.ln()
                        } else {
                            0.0
                        }
                    })
                    .collect(),
            ),
            (
                "ln(λ_min)",
                filtered
                    .iter()
                    .map(|r| {
                        if r.lambda_min > 0.0 {
                            r.lambda_min.ln()
                        } else {
                            -30.0
                        }
                    })
                    .collect(),
            ),
            (
                "ln(N)",
                filtered.iter().map(|r| (r.n as f64).ln()).collect(),
            ),
            (
                "ln(d(N))",
                filtered
                    .iter()
                    .map(|r| (num_divisors(r.n) as f64).ln())
                    .collect(),
            ),
            (
                "ln(δ_N)",
                filtered
                    .iter()
                    .map(|r| {
                        if r.eigen_drop > 1e-30 {
                            r.eigen_drop.ln()
                        } else {
                            -70.0
                        }
                    })
                    .collect(),
            ),
        ];

        println!(
            "  {:>20} {:>12} {:>12}",
            "Predictor", "Correlation", "Interpretation"
        );
        println!("  {}", "─".repeat(50));

        let n = ln_cos2.len() as f64;
        let my = ln_cos2.iter().sum::<f64>() / n;
        let sy = (ln_cos2.iter().map(|y| (y - my).powi(2)).sum::<f64>() / n).sqrt();

        for (name, vals) in &predictors {
            let mx = vals.iter().sum::<f64>() / n;
            let sx = (vals.iter().map(|x| (x - mx).powi(2)).sum::<f64>() / n).sqrt();
            let cov: f64 = vals
                .iter()
                .zip(ln_cos2.iter())
                .map(|(x, y)| (x - mx) * (y - my))
                .sum::<f64>()
                / n;
            let corr = if sx > 0.0 && sy > 0.0 {
                cov / (sx * sy)
            } else {
                0.0
            };

            let interp = if corr.abs() > 0.8 {
                "★ STRONG"
            } else if corr.abs() > 0.6 {
                "● MODERATE"
            } else if corr.abs() > 0.4 {
                "○ WEAK"
            } else {
                "· NONE"
            };

            println!("  {:>20} {:>+12.4} {:>12}", name, corr, interp);
        }
    }

    println!();
    println!("  Total runtime: {:.1}s", t_start.elapsed().as_secs_f64());
    println!();
}
