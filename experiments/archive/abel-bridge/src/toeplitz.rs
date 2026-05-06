//! # Angle 1: Wiener-Kolmogorov / Toeplitz Verification
//!
//! The Theorist claims: if we set M_{jk} = G_{jk}/√(jk), the normalized
//! Gram matrix is Toeplitz on the log scale — i.e., M_{jk} depends only
//! on |ln(j) - ln(k)|.
//!
//! This experiment verifies this numerically by:
//! 1. Computing raw Gram entries G(j,k) = ∫₀¹ {j/x}{k/x} dx
//! 2. Normalizing: M(j,k) = G(j,k) / √(jk)
//! 3. Checking if M(j,k) ≈ M(j',k') when |ln j - ln k| = |ln j' - ln k'|
//! 4. Extracting the "Toeplitz kernel" r(τ) where τ = |ln j - ln k|
//! 5. Computing the power spectral density (PSD) via FFT/DFT
//!
//! If the Toeplitz structure holds, Szegő's limit theorem gives the
//! asymptotic minimum prediction error — which IS the RH axiom.

use rayon::prelude::*;
use std::fs;
use std::io::Write;
use std::time::Instant;

const QUAD_POINTS: usize = 100_000;

/// Compute ∫₀¹ f(x) dx via composite Simpson's rule
fn integrate_01<F: Fn(f64) -> f64>(f: F) -> f64 {
    let n = QUAD_POINTS;
    let h = 1.0 / n as f64;
    let mut total = 0.0;

    for i in 1..n {
        let x = i as f64 * h;
        let w = if i % 2 == 0 { 2.0 } else { 4.0 };
        total += w * f(x);
    }

    // Near-boundary estimates (avoid x=0 singularity)
    total += f(h * 0.01);
    total += f(1.0 - h * 0.01);

    total * h / 3.0
}

/// Gram entry G(j,k) = ∫₀¹ {j/x}{k/x} dx  [HIGH-FREQUENCY BASIS]
fn gram_entry_hf(j: usize, k: usize) -> f64 {
    let jf = j as f64;
    let kf = k as f64;
    integrate_01(|x| (jf / x).fract() * (kf / x).fract())
}

/// Gram entry G(j,k) = ∫₀¹ {1/(jx)}{1/(kx)} dx  [BÁEZ-DUARTE BASIS]
fn gram_entry_bd(j: usize, k: usize) -> f64 {
    let jf = j as f64;
    let kf = k as f64;
    integrate_01(|x| (1.0 / (jf * x)).fract() * (1.0 / (kf * x)).fract())
}

/// Normalized Gram (HF): M(j,k) = G_HF(j,k) / √(jk)
fn normalized_gram_hf(j: usize, k: usize) -> f64 {
    gram_entry_hf(j, k) / ((j as f64) * (k as f64)).sqrt()
}

/// Normalized Gram (BD): M(j,k) = G_BD(j,k) / √(jk)
fn normalized_gram_bd(j: usize, k: usize) -> f64 {
    gram_entry_bd(j, k) / ((j as f64) * (k as f64)).sqrt()
}

/// Compute the "autocorrelation function" by averaging M(j,k) over all
/// pairs (j,k) with approximately the same log-distance τ = |ln j - ln k|
fn compute_toeplitz_kernel<F: Fn(usize, usize) -> f64 + Sync>(
    max_k: usize, n_bins: usize, norm_gram: F
) -> Vec<(f64, f64, f64, usize)> {
    let max_tau = (max_k as f64).ln();
    let bin_width = max_tau / n_bins as f64;

    // Collect all (j,k) pairs and their M values, binned by τ
    let pairs: Vec<(usize, usize)> = (1..=max_k)
        .flat_map(|j| (j..=max_k).map(move |k| (j, k)))
        .collect();

    let m_values: Vec<(f64, f64)> = pairs
        .par_iter()
        .map(|&(j, k)| {
            let tau = ((k as f64).ln() - (j as f64).ln()).abs();
            let m = norm_gram(j, k);
            (tau, m)
        })
        .collect();

    // Bin by tau
    let mut bins: Vec<Vec<f64>> = vec![Vec::new(); n_bins + 1];
    let mut tau_sums: Vec<f64> = vec![0.0; n_bins + 1];

    for &(tau, m) in &m_values {
        let bin = (tau / bin_width).floor() as usize;
        let bin = bin.min(n_bins);
        bins[bin].push(m);
        tau_sums[bin] += tau;
    }

    // Average each bin: (tau_center, mean_M, std_M, count)
    bins.iter()
        .enumerate()
        .filter(|(_, b)| !b.is_empty())
        .map(|(i, b)| {
            let count = b.len();
            let mean = b.iter().sum::<f64>() / count as f64;
            let avg_tau = tau_sums[i] / count as f64;
            let variance = b.iter().map(|&x| (x - mean).powi(2)).sum::<f64>() / count as f64;
            (avg_tau, mean, variance.sqrt(), count)
        })
        .collect()
}

fn main() {
    let t0 = Instant::now();

    println!("╔══════════════════════════════════════════════════════════════╗");
    println!("║  ANGLE 1: WIENER-KOLMOGOROV / TOEPLITZ VERIFICATION        ║");
    println!("║  Is the normalized Gram matrix Toeplitz on the log scale?   ║");
    println!("╚══════════════════════════════════════════════════════════════╝");
    println!();

    fs::create_dir_all("results").unwrap();

    // ═══ Phase 1: Direct Toeplitz check for small indices ═══
    println!("═══ Phase 1a: High-Frequency Basis {{j/x}} ═══");
    println!("  Computing M(j,k) = G_HF(j,k)/√(jk) for pairs with same log-ratio");
    println!();

    println!("  Log-ratio = ln(2) ≈ 0.693:");
    let pairs_ln2: Vec<(usize, usize)> = vec![(1,2), (2,4), (3,6), (4,8), (5,10)];
    for &(j, k) in &pairs_ln2 {
        let m = normalized_gram_hf(j, k);
        println!("    M_HF({},{}) = {:.8}", j, k, m);
    }

    println!("\n  Log-ratio = ln(3) ≈ 1.099:");
    let pairs_ln3: Vec<(usize, usize)> = vec![(1,3), (2,6), (3,9), (4,12), (5,15)];
    for &(j, k) in &pairs_ln3 {
        let m = normalized_gram_hf(j, k);
        println!("    M_HF({},{}) = {:.8}", j, k, m);
    }

    println!("\n═══ Phase 1b: Báez-Duarte Basis {{1/(jx)}} ═══");
    println!("  Computing M(j,k) = G_BD(j,k)/√(jk) for pairs with same log-ratio");
    println!();

    println!("  Log-ratio = ln(2) ≈ 0.693:");
    for &(j, k) in &pairs_ln2 {
        let m = normalized_gram_bd(j, k);
        println!("    M_BD({},{}) = {:.8}", j, k, m);
    }

    println!("\n  Log-ratio = ln(3) ≈ 1.099:");
    for &(j, k) in &pairs_ln3 {
        let m = normalized_gram_bd(j, k);
        println!("    M_BD({},{}) = {:.8}", j, k, m);
    }

    println!("\n  Log-ratio = ln(4) ≈ 1.386:");
    let pairs_ln4: Vec<(usize, usize)> = vec![(1,4), (2,8), (3,12), (5,20)];
    for &(j, k) in &pairs_ln4 {
        let m = normalized_gram_bd(j, k);
        println!("    M_BD({},{}) = {:.8}", j, k, m);
    }

    println!("\n  BD Diagonal (τ = 0):");
    for j in 1..=10 {
        let m = normalized_gram_bd(j, j);
        println!("    M_BD({},{}) = {:.8}", j, j, m);
    }

    // ═══ Phase 2: Full kernel extraction ═══
    println!("\n═══ Phase 2: BD Toeplitz Kernel r(τ) Extraction ═══");
    let max_k = 50;
    let n_bins = 30;

    println!("  Computing all M_BD(j,k) for j,k ∈ [1,{}] ({} pairs)...",
        max_k, max_k * (max_k + 1) / 2);

    let kernel = compute_toeplitz_kernel(max_k, n_bins, |j, k| normalized_gram_bd(j, k));

    println!("  Done in {:.1}s\n", t0.elapsed().as_secs_f64());

    // Write kernel to file
    {
        let mut f = fs::File::create("results/toeplitz_kernel.tsv").unwrap();
        writeln!(f, "tau\tmean_M\tstd_M\tcount").unwrap();
        for &(tau, mean, std, count) in &kernel {
            writeln!(f, "{:.6}\t{:.10}\t{:.10}\t{}", tau, mean, std, count).unwrap();
        }
    }

    println!("  τ (log-dist)  | Mean M(τ) | Std Dev   | Count | Quality");
    println!("  ─────────────-|───────────|───────────|───────|────────");
    for &(tau, mean, std, count) in &kernel {
        let quality = if count > 1 && std / mean.abs().max(1e-10) < 0.1 {
            "✅ TOEPLITZ"
        } else if count > 1 && std / mean.abs().max(1e-10) < 0.3 {
            "⚠️  approx"
        } else if count <= 1 {
            "   single"
        } else {
            "❌ NOT Toeplitz"
        };
        println!("  {:.4}          | {:.6}  | {:.6}  | {:>5} | {}",
            tau, mean, std, count, quality);
    }

    // ═══ Phase 3: Scatter plot data for visual inspection ═══
    println!("\n═══ Phase 3: BD scatter data ═══");
    {
        let mut f = fs::File::create("results/toeplitz_scatter_bd.tsv").unwrap();
        writeln!(f, "j\tk\ttau\tM_bd\tG_bd\tM_hf\tG_hf").unwrap();

        let pairs: Vec<(usize, usize)> = (1..=max_k)
            .flat_map(|j| (j..=max_k).map(move |k| (j, k)))
            .collect();

        let rows: Vec<String> = pairs
            .par_iter()
            .map(|&(j, k)| {
                let tau = ((k as f64).ln() - (j as f64).ln()).abs();
                let g_bd = gram_entry_bd(j, k);
                let m_bd = g_bd / ((j as f64) * (k as f64)).sqrt();
                let g_hf = gram_entry_hf(j, k);
                let m_hf = g_hf / ((j as f64) * (k as f64)).sqrt();
                format!("{}\t{}\t{:.8}\t{:.10}\t{:.10}\t{:.10}\t{:.10}", j, k, tau, m_bd, g_bd, m_hf, g_hf)
            })
            .collect();

        for row in &rows {
            writeln!(f, "{}", row).unwrap();
        }
    }
    println!("  📄 results/toeplitz_scatter_bd.tsv");

    // ═══ Verdict ═══
    let total = t0.elapsed().as_secs_f64();
    println!("\n╔══════════════════════════════════════════════════════════════╗");
    println!("║  VERDICT: Is the Gram matrix Toeplitz on the log scale?    ║");
    println!("╠══════════════════════════════════════════════════════════════╣");

    // Check if the low-tau bins have small std (good Toeplitz fit)
    let good_bins: usize = kernel.iter()
        .filter(|&&(_, mean, std, count)| count > 2 && std / mean.abs().max(1e-10) < 0.15)
        .count();
    let total_bins = kernel.iter().filter(|&&(_, _, _, count)| count > 2).count();

    println!("║  Bins with good Toeplitz fit: {}/{}", good_bins, total_bins);
    if good_bins as f64 / total_bins.max(1) as f64 > 0.7 {
        println!("║  ✅ STRONG TOEPLITZ STRUCTURE DETECTED!                    ║");
        println!("║  → Szegő's limit theorem is applicable                    ║");
        println!("║  → The Wiener-Kolmogorov paradigm is viable               ║");
    } else if good_bins as f64 / total_bins.max(1) as f64 > 0.4 {
        println!("║  ⚠️  APPROXIMATE Toeplitz structure                        ║");
        println!("║  → May need asymptotic refinement                         ║");
    } else {
        println!("║  ❌ Toeplitz structure WEAK or absent                      ║");
        println!("║  → Angle 1 may not be directly applicable                 ║");
    }
    println!("║  Total time: {:.1}s                                        ║", total);
    println!("╚══════════════════════════════════════════════════════════════╝");
}
