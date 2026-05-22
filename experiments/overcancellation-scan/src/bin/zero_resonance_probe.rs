// overcancellation-scan/src/bin/zero_resonance_probe.rs
//
// ╔═══════════════════════════════════════════════════════════════════╗
// ║  ZERO RESONANCE PROBE — Do Zeta Zeros Modulate cos²θ?          ║
// ║                                                                   ║
// ║  Three analyses:                                                  ║
// ║                                                                   ║
// ║  A) FOURIER SPECTRUM of cos²θ(N) — peaks at zero frequencies?   ║
// ║     If cos²θ has spectral content at f = γₖ/(2π), the zeros     ║
// ║     are modulating the alignment.                                 ║
// ║                                                                   ║
// ║  B) ZERO PROXIMITY — does cos²θ spike/dip near N ≈ γₖ?         ║
// ║     Look at cos²θ conditioned on |N - round(γₖ)| < δ           ║
// ║                                                                   ║
// ║  C) PHASE ANALYSIS — does N^{iγₖ} phase predict cos²θ?         ║
// ║     The Mellin overlap involves k^{-1/2-iγ}, so                 ║
// ║     cos(γₖ · ln N) might modulate the alignment.                ║
// ║                                                                   ║
// ║  D) EIGENVALUE DROP SPECTRUM — does δ_N have zero-frequency     ║
// ║     content? The drop should "feel" the zeros through the       ║
// ║     Mellin structure of the new basis vector.                    ║
// ╚═══════════════════════════════════════════════════════════════════╝

use cathedral_utils::gram;
use cathedral_utils::riemann_siegel;
use rayon::prelude::*;
use std::f64::consts::PI;
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
    println!("║  ZERO RESONANCE PROBE — Do Riemann Zeros Modulate cos²θ?        ║");
    println!("╚═══════════════════════════════════════════════════════════════════╝");
    println!();

    // ══════════════════════════════════════════════════
    // Step 0: Compute Riemann zeta zeros
    // ══════════════════════════════════════════════════

    println!("  Computing Riemann zeta zeros up to t=200...");
    let zeros = riemann_siegel::find_zeros(200.0);
    println!("  Found {} zeros", zeros.len());
    println!();
    println!("  First 20 zeros:");
    for (i, &gamma) in zeros.iter().take(20).enumerate() {
        println!("    γ_{:>2} = {:.6}   (2π/γ = {:.4})", i + 1, gamma, 2.0 * PI / gamma);
    }

    // ══════════════════════════════════════════════════
    // Step 1: Compute cos²θ and δ_N for N=4..600
    // ══════════════════════════════════════════════════

    let max_n: usize = 600;
    let start_n: usize = 4;

    let t0 = Instant::now();
    let full_gram = build_gram(max_n);
    let full_dim = max_n - 1;
    println!();
    println!("  [Built {}×{} Gram matrix in {:.1}s]", full_dim, full_dim, t0.elapsed().as_secs_f64());

    let mut cos2_seq: Vec<(usize, f64)> = Vec::new(); // (N, cos²θ)
    let mut drop_seq: Vec<(usize, f64)> = Vec::new(); // (N, δ_N)
    let mut lmin_seq: Vec<(usize, f64)> = Vec::new(); // (N, λ_min)
    let mut prev_lmin = 0.0f64;

    for n in start_n..=max_n {
        let dim = n - 1;
        let prev_dim = dim - 1;
        if prev_dim < 2 { continue; }

        let sub = extract_submatrix(&full_gram, full_dim, dim);
        let (lmin, _) = lambda_min_with_vec(&sub, dim);

        let g_vec: Vec<f64> = (0..prev_dim).map(|i| sub[i * dim + prev_dim]).collect();
        let g_nsq = norm_sq(&g_vec);

        let prev_sub = extract_submatrix(&full_gram, full_dim, prev_dim);
        let (_, v_min_prev) = lambda_min_with_vec(&prev_sub, prev_dim);

        let cos2 = if g_nsq > 1e-30 {
            let proj = dot(&g_vec, &v_min_prev);
            proj * proj / g_nsq
        } else { 0.0 };

        let drop = if n > start_n { (prev_lmin - lmin).max(0.0) } else { 0.0 };

        cos2_seq.push((n, cos2));
        drop_seq.push((n, drop));
        lmin_seq.push((n, lmin));
        prev_lmin = lmin;

        if n % 100 == 0 {
            eprintln!("  ... N={} ({:.0}s)", n, t_start.elapsed().as_secs_f64());
        }
    }

    // Detrend: remove the 1/N³ trend from cos²θ to see the residual
    // Fit log(cos²θ) = α·log(N) + β, then residual = log(cos²θ) - fit
    let fit_data: Vec<(f64, f64)> = cos2_seq.iter()
        .filter(|&&(n, c)| n >= 30 && c > 1e-30)
        .map(|&(n, c)| ((n as f64).ln(), c.ln()))
        .collect();

    let (alpha, beta) = if fit_data.len() >= 10 {
        let nf = fit_data.len() as f64;
        let sx: f64 = fit_data.iter().map(|(x, _)| x).sum();
        let sy: f64 = fit_data.iter().map(|(_, y)| y).sum();
        let sxy: f64 = fit_data.iter().map(|(x, y)| x * y).sum();
        let sx2: f64 = fit_data.iter().map(|(x, _)| x * x).sum();
        let a = (nf * sxy - sx * sy) / (nf * sx2 - sx * sx);
        let b = (sy - a * sx) / nf;
        (a, b)
    } else { (-3.0, 0.0) };

    println!();
    println!("  Detrend: log(cos²θ) ≈ {:.4}·log(N) + {:.4}", alpha, beta);

    // Detrended residuals
    let residuals: Vec<(usize, f64)> = cos2_seq.iter()
        .filter(|&&(n, c)| n >= 30 && c > 1e-30)
        .map(|&(n, c)| {
            let predicted = alpha * (n as f64).ln() + beta;
            (n, c.ln() - predicted)
        })
        .collect();

    // ══════════════════════════════════════════════════
    // ANALYSIS A: Fourier Spectrum of Detrended cos²θ
    // ══════════════════════════════════════════════════

    println!();
    println!("══════════════════════════════════════════════════════════════");
    println!("  ANALYSIS A: Fourier Spectrum of Detrended cos²θ Residuals");
    println!("══════════════════════════════════════════════════════════════");

    // DFT of the detrended residuals
    let n_pts = residuals.len();
    let mean_r: f64 = residuals.iter().map(|(_, r)| r).sum::<f64>() / n_pts as f64;

    // Compute power spectrum
    let mut spectrum: Vec<(f64, f64)> = Vec::new(); // (frequency, power)
    let n_freq = n_pts / 2;

    for k in 1..n_freq {
        let freq = k as f64 / n_pts as f64; // cycles per unit N
        let mut re = 0.0f64;
        let mut im = 0.0f64;
        for (j, (_, r)) in residuals.iter().enumerate() {
            let phase = 2.0 * PI * k as f64 * j as f64 / n_pts as f64;
            re += (r - mean_r) * phase.cos();
            im += (r - mean_r) * phase.sin();
        }
        let power = (re * re + im * im) / n_pts as f64;
        spectrum.push((freq, power));
    }

    // Find top 15 peaks
    let mut sorted_spec: Vec<(f64, f64)> = spectrum.clone();
    sorted_spec.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap());

    println!();
    println!("  Top 15 spectral peaks of detrended cos²θ:");
    println!("  {:>6} {:>10} {:>14} {:>20}",
        "rank", "freq (1/N)", "power", "nearest γₖ/(2π)");
    println!("  {}", "─".repeat(55));

    for (i, &(freq, power)) in sorted_spec.iter().take(15).enumerate() {
        // Convert frequency to "angular frequency" and compare to γₖ
        let omega = freq * 2.0 * PI; // doesn't directly correspond...
        // Actually the N-index Fourier frequency corresponds to
        // oscillation per unit N. The zeta zeros create oscillations
        // in the Mellin integral at "log-frequency" γₖ.
        // So we should look at frequency in LOG(N) space.
        // But let's also just check: does freq * N_range ≈ γₖ?
        let period = if freq > 1e-10 { 1.0 / freq } else { f64::INFINITY };

        // Find nearest zero
        let nearest = zeros.iter()
            .map(|&g| (g, (period - g).abs()))
            .min_by(|a, b| a.1.partial_cmp(&b.1).unwrap())
            .map(|(g, _)| g)
            .unwrap_or(0.0);

        println!("  {:6} {:10.6} {:14.6e} {:>10.4} (γ={:.3})",
            i + 1, freq, power, period, nearest);
    }

    // ══════════════════════════════════════════════════
    // ANALYSIS B: Fourier in LOG(N) space
    // ══════════════════════════════════════════════════

    println!();
    println!("══════════════════════════════════════════════════════════════");
    println!("  ANALYSIS B: Fourier in log(N) Space — Zero Frequencies");
    println!("══════════════════════════════════════════════════════════════");

    // Resample residuals onto uniform log(N) grid
    let ln_min = (30.0f64).ln();
    let ln_max = (max_n as f64).ln();
    let n_log_pts = 512;
    let d_ln = (ln_max - ln_min) / n_log_pts as f64;

    let mut log_residuals = vec![0.0f64; n_log_pts];
    for i in 0..n_log_pts {
        let ln_n = ln_min + (i as f64 + 0.5) * d_ln;
        let n_target = ln_n.exp();
        // Find nearest residual
        if let Some(&(_, r)) = residuals.iter()
            .min_by_key(|&&(n, _)| ((n as f64 - n_target).abs() * 1e6) as i64)
        {
            log_residuals[i] = r;
        }
    }

    let mean_lr: f64 = log_residuals.iter().sum::<f64>() / n_log_pts as f64;

    // DFT in log space — frequencies here correspond directly to γₖ!
    let mut log_spectrum: Vec<(f64, f64)> = Vec::new();
    for k in 1..n_log_pts / 2 {
        let freq = k as f64 / (n_log_pts as f64 * d_ln); // cycles per unit ln(N)
        let angular_freq = 2.0 * PI * freq; // THIS should match γₖ!
        let mut re = 0.0f64;
        let mut im = 0.0f64;
        for (j, &r) in log_residuals.iter().enumerate() {
            let phase = 2.0 * PI * k as f64 * j as f64 / n_log_pts as f64;
            re += (r - mean_lr) * phase.cos();
            im += (r - mean_lr) * phase.sin();
        }
        let power = (re * re + im * im) / n_log_pts as f64;
        log_spectrum.push((angular_freq, power));
    }

    // Sort by power
    let mut sorted_log: Vec<(f64, f64)> = log_spectrum.clone();
    sorted_log.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap());

    println!();
    println!("  Top 15 peaks in log(N) Fourier space:");
    println!("  {:>6} {:>12} {:>14} {:>20}",
        "rank", "ω (log-freq)", "power", "nearest γₖ (match?)");
    println!("  {}", "─".repeat(55));

    for (i, &(omega, power)) in sorted_log.iter().take(15).enumerate() {
        let nearest = zeros.iter()
            .map(|&g| (g, (omega - g).abs()))
            .min_by(|a, b| a.1.partial_cmp(&b.1).unwrap());
        let (near_g, near_dist) = nearest.unwrap_or((0.0, f64::INFINITY));
        let match_pct = if near_g > 0.0 { 100.0 * (1.0 - near_dist / near_g) } else { 0.0 };
        let flag = if near_dist < 0.5 { " ★" } else if near_dist < 1.5 { " ●" } else { "" };

        println!("  {:6} {:12.4} {:14.6e}    γ={:.3} (Δ={:.2}){}", 
            i + 1, omega, power, near_g, near_dist, flag);
    }

    // ══════════════════════════════════════════════════
    // ANALYSIS C: Phase Correlation with Each Zero
    // ══════════════════════════════════════════════════

    println!();
    println!("══════════════════════════════════════════════════════════════");
    println!("  ANALYSIS C: Phase Correlation — cos(γₖ·ln N) vs cos²θ");
    println!("══════════════════════════════════════════════════════════════");
    println!();
    println!("  {:>4} {:>10} {:>12} {:>12}",
        "k", "γₖ", "corr(cos)", "corr(sin)");
    println!("  {}", "─".repeat(45));

    for (k, &gamma) in zeros.iter().take(30).enumerate() {
        // Correlation of cos(γ·ln(N)) with detrended log(cos²θ)
        let pairs: Vec<(f64, f64, f64)> = residuals.iter()
            .map(|&(n, r)| {
                let phase = gamma * (n as f64).ln();
                (phase.cos(), phase.sin(), r)
            })
            .collect();

        let n = pairs.len() as f64;
        let mr: f64 = pairs.iter().map(|(_, _, r)| r).sum::<f64>() / n;

        // Correlation with cos
        let mc: f64 = pairs.iter().map(|(c, _, _)| c).sum::<f64>() / n;
        let cov_c: f64 = pairs.iter().map(|(c, _, r)| (c - mc) * (r - mr)).sum::<f64>() / n;
        let sc: f64 = (pairs.iter().map(|(c, _, _)| (c - mc).powi(2)).sum::<f64>() / n).sqrt();
        let sr: f64 = (pairs.iter().map(|(_, _, r)| (r - mr).powi(2)).sum::<f64>() / n).sqrt();
        let corr_cos = if sc > 0.0 && sr > 0.0 { cov_c / (sc * sr) } else { 0.0 };

        // Correlation with sin
        let ms: f64 = pairs.iter().map(|(_, s, _)| s).sum::<f64>() / n;
        let cov_s: f64 = pairs.iter().map(|(_, s, r)| (s - ms) * (r - mr)).sum::<f64>() / n;
        let ss: f64 = (pairs.iter().map(|(_, s, _)| (s - ms).powi(2)).sum::<f64>() / n).sqrt();
        let corr_sin = if ss > 0.0 && sr > 0.0 { cov_s / (ss * sr) } else { 0.0 };

        let flag = if corr_cos.abs() > 0.15 || corr_sin.abs() > 0.15 { " ★" } else { "" };
        println!("  {:4} {:10.4} {:>+12.4} {:>+12.4}{}",
            k + 1, gamma, corr_cos, corr_sin, flag);
    }

    // ══════════════════════════════════════════════════
    // ANALYSIS D: Combined Phase Signal
    // ══════════════════════════════════════════════════

    println!();
    println!("══════════════════════════════════════════════════════════════");
    println!("  ANALYSIS D: Combined Zero Signal");
    println!("══════════════════════════════════════════════════════════════");

    // For each N, compute a "zero proximity score":
    // Z(N) = Σₖ cos(γₖ · ln N) / k²  (damped sum over first K zeros)
    let k_max = zeros.len().min(50);
    let zero_scores: Vec<(usize, f64)> = residuals.iter()
        .map(|&(n, _)| {
            let ln_n = (n as f64).ln();
            let score: f64 = (0..k_max)
                .map(|k| (zeros[k] * ln_n).cos() / ((k + 1) as f64).powi(2))
                .sum();
            (n, score)
        })
        .collect();

    // Correlate Z(N) with detrended cos²θ
    let zpairs: Vec<(f64, f64)> = zero_scores.iter()
        .zip(residuals.iter())
        .map(|(&(_, z), &(_, r))| (z, r))
        .collect();

    let n = zpairs.len() as f64;
    let mz: f64 = zpairs.iter().map(|(z, _)| z).sum::<f64>() / n;
    let mr: f64 = zpairs.iter().map(|(_, r)| r).sum::<f64>() / n;
    let cov: f64 = zpairs.iter().map(|(z, r)| (z - mz) * (r - mr)).sum::<f64>() / n;
    let sz: f64 = (zpairs.iter().map(|(z, _)| (z - mz).powi(2)).sum::<f64>() / n).sqrt();
    let sr: f64 = (zpairs.iter().map(|(_, r)| (r - mr).powi(2)).sum::<f64>() / n).sqrt();
    let corr_z = if sz > 0.0 && sr > 0.0 { cov / (sz * sr) } else { 0.0 };

    println!();
    println!("  Z(N) = Σ_{{k=1}}^{{{}}} cos(γₖ·ln N) / k²", k_max);
    println!("  Correlation(Z(N), detrended cos²θ) = {:.6}", corr_z);

    // Also try: |Z(N)| vs |cos²θ residual|
    let abs_pairs: Vec<(f64, f64)> = zpairs.iter()
        .map(|&(z, r)| (z.abs(), r.abs()))
        .collect();
    let mz: f64 = abs_pairs.iter().map(|(z, _)| z).sum::<f64>() / n;
    let mr: f64 = abs_pairs.iter().map(|(_, r)| r).sum::<f64>() / n;
    let cov: f64 = abs_pairs.iter().map(|(z, r)| (z - mz) * (r - mr)).sum::<f64>() / n;
    let sz: f64 = (abs_pairs.iter().map(|(z, _)| (z - mz).powi(2)).sum::<f64>() / n).sqrt();
    let sr: f64 = (abs_pairs.iter().map(|(_, r)| (r - mr).powi(2)).sum::<f64>() / n).sqrt();
    let corr_abs = if sz > 0.0 && sr > 0.0 { cov / (sz * sr) } else { 0.0 };
    println!("  Correlation(|Z(N)|, |residual|) = {:.6}", corr_abs);

    // ══════════════════════════════════════════════════
    // ANALYSIS E: Per-Zero Eigenvalue Drop Modulation
    // ══════════════════════════════════════════════════

    println!();
    println!("══════════════════════════════════════════════════════════════");
    println!("  ANALYSIS E: Do Drops δ_N Resonate with Zeta Zeros?");
    println!("══════════════════════════════════════════════════════════════");

    // Same as Analysis C but for eigenvalue drops
    let drop_residuals: Vec<(usize, f64)> = drop_seq.iter()
        .filter(|&&(n, d)| n >= 30 && d > 1e-30)
        .map(|&(n, d)| {
            let predicted = alpha * (n as f64).ln() + beta; // rough detrend
            (n, d.ln() - predicted)
        })
        .collect();

    println!();
    println!("  {:>4} {:>10} {:>12} {:>12}",
        "k", "γₖ", "corr_drop(cos)", "corr_drop(sin)");
    println!("  {}", "─".repeat(45));

    for (k, &gamma) in zeros.iter().take(20).enumerate() {
        let pairs: Vec<(f64, f64, f64)> = drop_residuals.iter()
            .map(|&(n, r)| {
                let phase = gamma * (n as f64).ln();
                (phase.cos(), phase.sin(), r)
            })
            .collect();

        let n = pairs.len() as f64;
        let mr: f64 = pairs.iter().map(|(_, _, r)| r).sum::<f64>() / n;
        let mc: f64 = pairs.iter().map(|(c, _, _)| c).sum::<f64>() / n;
        let cov_c: f64 = pairs.iter().map(|(c, _, r)| (c - mc) * (r - mr)).sum::<f64>() / n;
        let sc: f64 = (pairs.iter().map(|(c, _, _)| (c - mc).powi(2)).sum::<f64>() / n).sqrt();
        let sr: f64 = (pairs.iter().map(|(_, _, r)| (r - mr).powi(2)).sum::<f64>() / n).sqrt();
        let corr_cos = if sc > 0.0 && sr > 0.0 { cov_c / (sc * sr) } else { 0.0 };

        let ms: f64 = pairs.iter().map(|(_, s, _)| s).sum::<f64>() / n;
        let cov_s: f64 = pairs.iter().map(|(_, s, r)| (s - ms) * (r - mr)).sum::<f64>() / n;
        let ss: f64 = (pairs.iter().map(|(_, s, _)| (s - ms).powi(2)).sum::<f64>() / n).sqrt();
        let corr_sin = if ss > 0.0 && sr > 0.0 { cov_s / (ss * sr) } else { 0.0 };

        let amp = (corr_cos * corr_cos + corr_sin * corr_sin).sqrt();
        let flag = if amp > 0.15 { " ★" } else if amp > 0.10 { " ●" } else { "" };
        println!("  {:4} {:10.4} {:>+12.4} {:>+12.4}  amp={:.4}{}",
            k + 1, gamma, corr_cos, corr_sin, amp, flag);
    }

    println!();
    println!("  Total runtime: {:.1}s", t_start.elapsed().as_secs_f64());
    println!();
}
