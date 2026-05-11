#![allow(unused, dead_code, non_snake_case)]
use nalgebra::{DMatrix, SymmetricEigen};
use rayon::prelude::*;

// ══════════════════════════════════════════════════════════════════════
// GUE STATISTICS TEST FOR THE GRAM MATRIX SPECTRUM
//
// The Montgomery-Dyson discovery (1972): zeta zeros exhibit GUE statistics.
// Question: Do the eigenvalues of our Gram matrix G_N also follow GUE?
//
// If YES → G_N is in the same universality class as the zeta zeros,
//          confirming it as a spectral realization of ζ(s).
// If GOE → unexpected time-reversal symmetry (interesting!)
// If Poisson → no correlation (unlikely for a structured matrix)
//
// Tests:
// 1. Nearest-neighbor spacing distribution p(s)
// 2. Comparison to Wigner surmises (GUE, GOE, Poisson)
// 3. Spacing ratio statistics (r = min(s_i, s_{i+1}) / max(s_i, s_{i+1}))
// 4. Number variance Σ²(L)
// ══════════════════════════════════════════════════════════════════════

use std::f64::consts::PI;

fn frac_part(x: f64) -> f64 {
    x - x.floor()
}

/// Gram entry G[j,k] = ∫₀¹ {j/x}{k/x} dx
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

/// Build Gram matrix G_N (parallel)
fn build_gram(n: usize, n_pts: usize) -> DMatrix<f64> {
    let dim = n - 1;
    let entries: Vec<((usize, usize), f64)> = (0..dim)
        .into_par_iter()
        .flat_map(|i| {
            (i..dim)
                .into_par_iter()
                .map(move |j| ((i, j), gram_entry(i + 2, j + 2, n_pts)))
        })
        .collect();
    let mut mat = DMatrix::<f64>::zeros(dim, dim);
    for ((i, j), v) in entries {
        mat[(i, j)] = v;
        mat[(j, i)] = v;
    }
    mat
}

/// GUE Wigner surmise: p(s) = (32/π²) s² exp(-4s²/π)
fn gue_wigner(s: f64) -> f64 {
    (32.0 / (PI * PI)) * s * s * (-4.0 * s * s / PI).exp()
}

/// GOE Wigner surmise: p(s) = (π/2) s exp(-πs²/4)
fn goe_wigner(s: f64) -> f64 {
    (PI / 2.0) * s * (-PI * s * s / 4.0).exp()
}

/// Poisson: p(s) = exp(-s)
fn poisson(s: f64) -> f64 {
    (-s).exp()
}

/// GSE Wigner surmise: p(s) = (2^18 / (3^6 π³)) s⁴ exp(-64s²/(9π))
fn gse_wigner(s: f64) -> f64 {
    let coeff = (2.0_f64.powi(18)) / (3.0_f64.powi(6) * PI.powi(3));
    coeff * s.powi(4) * (-64.0 * s * s / (9.0 * PI)).exp()
}

/// Unfold eigenvalues: normalize so average spacing ≈ 1
/// Uses simple linear unfolding (sort + rescale by local density)
fn unfold_eigenvalues(evals: &[f64]) -> Vec<f64> {
    let n = evals.len();
    // Simple unfolding: map eigenvalue index to uniform spacing
    // ξ_i = i / (N-1) * N = i * N / (N-1), so spacings ≈ 1
    // More sophisticated: use cumulative spectral density

    // Staircase function approach: ξ_i = N(λ_i) where N is the
    // integrated density of states. For empirical unfolding,
    // use the rank: ξ_i = i (already sorted by rank).
    // Then spacings s_i = ξ_{i+1} - ξ_i are normalized.

    // Better: polynomial fit to the cumulative distribution
    // For now, simple rank-based unfolding
    let mut sorted = evals.to_vec();
    sorted.sort_by(|a, b| a.partial_cmp(b).unwrap());

    // Compute spacings in terms of eigenvalue differences,
    // then normalize by local mean spacing
    let mut spacings = Vec::with_capacity(n - 1);
    for i in 0..n - 1 {
        spacings.push(sorted[i + 1] - sorted[i]);
    }

    // Normalize: divide by mean spacing
    let mean_spacing: f64 = spacings.iter().sum::<f64>() / spacings.len() as f64;
    if mean_spacing > 0.0 {
        for s in spacings.iter_mut() {
            *s /= mean_spacing;
        }
    }

    spacings
}

/// Better unfolding using local mean (window-based)
fn unfold_local(evals: &[f64], window: usize) -> Vec<f64> {
    let n = evals.len();
    let mut sorted = evals.to_vec();
    sorted.sort_by(|a, b| a.partial_cmp(b).unwrap());

    let mut spacings = Vec::with_capacity(n - 1);
    for i in 0..n - 1 {
        let raw = sorted[i + 1] - sorted[i];

        // Local mean spacing from neighbors
        let lo = if i >= window { i - window } else { 0 };
        let hi = (i + window + 1).min(n - 1);
        let local_mean = (sorted[hi] - sorted[lo]) / (hi - lo) as f64;

        if local_mean > 1e-15 {
            spacings.push(raw / local_mean);
        }
    }
    spacings
}

/// Compute spacing ratios r_i = min(s_i, s_{i+1}) / max(s_i, s_{i+1})
/// Mean ratio: Poisson → 2ln2 - 1 ≈ 0.386
///             GOE → 0.5307
///             GUE → 0.6027
///             GSE → 0.6762
fn spacing_ratios(spacings: &[f64]) -> Vec<f64> {
    let mut ratios = Vec::with_capacity(spacings.len() - 1);
    for i in 0..spacings.len() - 1 {
        let (a, b) = (spacings[i], spacings[i + 1]);
        if a > 1e-15 && b > 1e-15 {
            ratios.push(a.min(b) / a.max(b));
        }
    }
    ratios
}

/// Histogram of values into bins
fn histogram(values: &[f64], n_bins: usize, max_val: f64) -> Vec<(f64, f64)> {
    let bin_width = max_val / n_bins as f64;
    let mut counts = vec![0usize; n_bins];
    let total = values.len() as f64;

    for &v in values {
        let bin = (v / bin_width) as usize;
        if bin < n_bins {
            counts[bin] += 1;
        }
    }

    (0..n_bins)
        .map(|i| {
            let center = (i as f64 + 0.5) * bin_width;
            let density = counts[i] as f64 / (total * bin_width);
            (center, density)
        })
        .collect()
}

/// Kolmogorov-Smirnov test statistic against a theoretical CDF
fn ks_statistic(spacings: &[f64], cdf: &dyn Fn(f64) -> f64) -> f64 {
    let n = spacings.len();
    let mut sorted = spacings.to_vec();
    sorted.sort_by(|a, b| a.partial_cmp(b).unwrap());

    let mut max_diff = 0.0f64;
    for (i, &s) in sorted.iter().enumerate() {
        let empirical = (i + 1) as f64 / n as f64;
        let theoretical = cdf(s);
        max_diff = max_diff.max((empirical - theoretical).abs());
    }
    max_diff
}

/// CDF of GUE Wigner surmise (numerical integration)
fn gue_cdf(s: f64) -> f64 {
    let n = 1000;
    let dx = s / n as f64;
    let mut sum = 0.0;
    for i in 0..n {
        let x = (i as f64 + 0.5) * dx;
        sum += gue_wigner(x) * dx;
    }
    sum.min(1.0)
}

fn goe_cdf(s: f64) -> f64 {
    let n = 1000;
    let dx = s / n as f64;
    let mut sum = 0.0;
    for i in 0..n {
        let x = (i as f64 + 0.5) * dx;
        sum += goe_wigner(x) * dx;
    }
    sum.min(1.0)
}

fn poisson_cdf(s: f64) -> f64 {
    1.0 - (-s).exp()
}

fn main() {
    println!("╔══════════════════════════════════════════════════════════════════╗");
    println!("║  GUE STATISTICS TEST — GRAM MATRIX EIGENVALUES                 ║");
    println!("║  Does G_N live in the Montgomery-Dyson universality class?     ║");
    println!("╚══════════════════════════════════════════════════════════════════╝\n");

    let n_pts = 500_000;
    let total_start = std::time::Instant::now();

    // Test sizes
    let test_sizes = vec![50, 100, 200, 300, 500];

    for &n in &test_sizes {
        let start = std::time::Instant::now();
        println!("═══════════════════════════════════════════════════════════════");
        println!("  N = {} (dim = {})", n, n - 1);
        println!("═══════════════════════════════════════════════════════════════\n");

        // Build and diagonalize G_N
        let gram = build_gram(n, n_pts);
        let eig = SymmetricEigen::new(gram);
        let evals: Vec<f64> = eig.eigenvalues.iter().cloned().collect();

        let mut sorted = evals.clone();
        sorted.sort_by(|a, b| a.partial_cmp(b).unwrap());

        println!(
            "  Eigenvalue range: [{:.8}, {:.8}]",
            sorted[0],
            sorted[sorted.len() - 1]
        );
        println!(
            "  Mean eigenvalue: {:.8}",
            sorted.iter().sum::<f64>() / sorted.len() as f64
        );

        // ─── Unfolding ───
        let spacings_global = unfold_eigenvalues(&evals);
        let spacings_local = unfold_local(&evals, 10.min(evals.len() / 10));

        // Use local unfolding for analysis
        let spacings = &spacings_local;

        println!("  Number of spacings: {}", spacings.len());
        println!(
            "  Mean spacing (normalized): {:.6}",
            spacings.iter().sum::<f64>() / spacings.len() as f64
        );

        // ─── Spacing Distribution Histogram ───
        println!("\n  Spacing distribution p(s):\n");
        println!(
            "  {:>6} {:>10} {:>10} {:>10} {:>10} {:>10}",
            "s", "observed", "GUE", "GOE", "Poisson", "GSE"
        );
        println!("  {}", "─".repeat(62));

        let hist = histogram(spacings, 20, 4.0);
        for (center, density) in &hist {
            let s = *center;
            if s < 3.5 {
                println!(
                    "  {:6.2} {:10.4} {:10.4} {:10.4} {:10.4} {:10.4}",
                    s,
                    density,
                    gue_wigner(s),
                    goe_wigner(s),
                    poisson(s),
                    gse_wigner(s)
                );
            }
        }

        // ─── Kolmogorov-Smirnov Tests ───
        let ks_gue = ks_statistic(spacings, &gue_cdf);
        let ks_goe = ks_statistic(spacings, &goe_cdf);
        let ks_poi = ks_statistic(spacings, &poisson_cdf);

        println!("\n  Kolmogorov-Smirnov statistics (lower = better fit):");
        println!("    KS(GUE)     = {:.6}", ks_gue);
        println!("    KS(GOE)     = {:.6}", ks_goe);
        println!("    KS(Poisson) = {:.6}", ks_poi);

        let best = if ks_gue <= ks_goe && ks_gue <= ks_poi {
            "GUE"
        } else if ks_goe <= ks_poi {
            "GOE"
        } else {
            "Poisson"
        };
        println!("    Best fit: {} ✨", best);

        // ─── Spacing Ratio Test ───
        let ratios = spacing_ratios(spacings);
        let mean_ratio = ratios.iter().sum::<f64>() / ratios.len() as f64;

        println!("\n  Spacing ratio test ⟨r⟩ = min(sᵢ,sᵢ₊₁)/max(sᵢ,sᵢ₊₁):");
        println!("    Observed ⟨r⟩ = {:.6}", mean_ratio);
        println!("    Poisson:      0.38629  (2ln2 - 1)");
        println!("    GOE:          0.53590");
        println!("    GUE:          0.60270");
        println!("    GSE:          0.67620");

        let ratio_diffs = [
            ("Poisson", (mean_ratio - 0.38629).abs()),
            ("GOE", (mean_ratio - 0.53590).abs()),
            ("GUE", (mean_ratio - 0.60270).abs()),
            ("GSE", (mean_ratio - 0.67620).abs()),
        ];
        let best_ratio = ratio_diffs
            .iter()
            .min_by(|a, b| a.1.partial_cmp(&b.1).unwrap())
            .unwrap();
        println!("    Closest: {} (Δ = {:.6}) ✨", best_ratio.0, best_ratio.1);

        // ─── Level Repulsion ───
        // s → 0 behavior: p(s) ~ s^β where β = 1 (GOE), 2 (GUE), 4 (GSE)
        let small_spacings: Vec<f64> = spacings
            .iter()
            .filter(|&&s| s > 0.01 && s < 0.5)
            .cloned()
            .collect();

        if small_spacings.len() >= 10 {
            // Fit log(p(s)) = β·log(s) + const for small s
            let n_small = small_spacings.len() as f64;
            let sum_log_s: f64 = small_spacings.iter().map(|s| s.ln()).sum();
            let mean_log_s = sum_log_s / n_small;

            // Estimate β from the density at small s
            let hist_small = histogram(&small_spacings, 5, 0.5);
            if hist_small.len() >= 2 {
                let (s1, p1) = hist_small[0];
                let (s2, p2) = hist_small[1];
                if p1 > 0.01 && p2 > 0.01 && s1 > 0.01 && s2 > 0.01 {
                    let beta_est = (p2.ln() - p1.ln()) / (s2.ln() - s1.ln());
                    println!("\n  Level repulsion exponent β (from small-s behavior):");
                    println!("    Estimated β ≈ {:.2}", beta_est);
                    println!("    GOE: β = 1, GUE: β = 2, GSE: β = 4");
                }
            }
        }

        let t = start.elapsed().as_secs_f64();
        println!("\n  (computed in {:.1}s)\n", t);
    }

    // ─── Summary ───
    println!("\n╔══════════════════════════════════════════════════════════════════╗");
    println!("║  SUMMARY                                                       ║");
    println!("╚══════════════════════════════════════════════════════════════════╝\n");
    println!("  The Gram matrix eigenvalue statistics reveal which universality");
    println!("  class the operator belongs to. If GUE, this confirms the");
    println!("  Montgomery-Dyson connection and supports the Hilbert-Pólya");
    println!("  interpretation of the Nyman-Beurling Gram matrix.\n");
    println!("  Total time: {:.1}s", total_start.elapsed().as_secs_f64());
}
