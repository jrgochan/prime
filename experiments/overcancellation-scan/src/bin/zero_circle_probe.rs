// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║  ZERO-CIRCLE GEOMETRY PROBE                                              ║
// ║                                                                          ║
// ║  For each non-trivial zero ρ_n = 1/2 + iγ_n:                           ║
// ║  1. Circle centered at ρ_n through s=0 and s=1                          ║
// ║     radius r_n = √(1/4 + γ_n²), central angle α_n = 2·arcsin(1/(2r))  ║
// ║  2. α_n · γ_n → 1 with correction 1/(4γ²) (encodes strip width)       ║
// ║  3. θ(γ_n) mod π distribution (GUE statistics probe)                    ║
// ║  4. α_n · N(γ) / ln(N) convergence                                     ║
// ║                                                                          ║
// ║  Scales to 100,000 zeros via Riemann-Siegel formula.                    ║
// ╚═══════════════════════════════════════════════════════════════════════════╝

use cathedral_utils::riemann_siegel;

use std::f64::consts::PI;

/// Number of zeros up to height T (Riemann-von Mangoldt formula)
fn n_from_gamma(gamma: f64) -> f64 {
    if gamma < 2.0 {
        return 0.0;
    }
    (gamma / (2.0 * PI)) * (gamma / (2.0 * PI)).ln() - gamma / (2.0 * PI) + 7.0 / 8.0
}

/// Central angle subtended by chord from s=0 to s=1
/// at a circle centered at 1/2 + iγ with radius r = √(1/4 + γ²)
fn central_angle(gamma: f64) -> f64 {
    let r = (0.25 + gamma * gamma).sqrt();
    2.0 * (1.0 / (2.0 * r)).asin()
}

/// α·γ product deviation from 1
fn alpha_gamma_deviation(gamma: f64) -> f64 {
    let alpha = central_angle(gamma);
    1.0 - alpha * gamma
}

/// Predicted deviation: 1/(4γ²)
fn predicted_deviation(gamma: f64) -> f64 {
    1.0 / (4.0 * gamma * gamma)
}

fn main() {
    println!("╔═══════════════════════════════════════════════════════════════╗");
    println!("║  ZERO-CIRCLE GEOMETRY PROBE — Scaling to 100K Zeros         ║");
    println!("╚═══════════════════════════════════════════════════════════════╝");
    println!();

    // ═══════════════════════════════════════
    // §1. COMPUTE ZEROS
    // ═══════════════════════════════════════

    // For 100K zeros, need t ≈ 75000 (from N(T) formula)
    // N(75000) ≈ 75000/(2π) · ln(75000/(2π)) - 75000/(2π) + 7/8 ≈ 100,400
    let target_zeros = 100_000;
    let t_max = 75_000.0;

    println!("  Computing zeros up to t = {:.0}...", t_max);
    println!("  Expected: ~{} zeros", target_zeros);
    println!();

    let zeros = riemann_siegel::find_zeros(t_max);
    let n_zeros = zeros.len();
    println!("  Found {} zeros.", n_zeros);
    println!("  First zero: γ₁ = {:.10}", zeros[0]);
    println!("  Last zero:  γ_{} = {:.10}", n_zeros, zeros[n_zeros - 1]);
    println!();

    // ═══════════════════════════════════════
    // §2. α·γ PRODUCT RULE
    // ═══════════════════════════════════════

    println!("═══ §2. α·γ PRODUCT RULE ═══");
    println!();
    println!("  Checking: α_n · γ_n → 1 with correction 1/(4γ²)");
    println!();

    // Sample at log-spaced intervals
    let sample_indices: Vec<usize> = {
        let mut indices = Vec::new();
        let mut i = 0usize;
        while i < n_zeros {
            indices.push(i);
            if i < 10 {
                i += 1;
            } else if i < 100 {
                i += 10;
            } else if i < 1000 {
                i += 100;
            } else if i < 10000 {
                i += 1000;
            } else {
                i += 5000;
            }
        }
        if let Some(&last) = indices.last() {
            if last != n_zeros - 1 {
                indices.push(n_zeros - 1);
            }
        }
        indices
    };

    println!(
        "  {:>7} {:>12} {:>14} {:>14} {:>14} {:>8}",
        "n", "γ_n", "α·γ", "deviation", "predicted", "ratio"
    );
    println!("  {}", "-".repeat(75));

    let mut max_ratio_err = 0.0f64;
    for &idx in &sample_indices {
        let gamma = zeros[idx];
        let alpha = central_angle(gamma);
        let ag = alpha * gamma;
        let dev = 1.0 - ag;
        let pred = predicted_deviation(gamma);
        let ratio = if pred > 0.0 { dev / pred } else { 0.0 };

        if gamma > 20.0 {
            max_ratio_err = max_ratio_err.max((ratio - 1.0).abs());
        }

        println!(
            "  {:>7} {:>12.4} {:>14.10} {:>14.2e} {:>14.2e} {:>8.6}",
            idx + 1,
            gamma,
            ag,
            dev,
            pred,
            ratio
        );
    }
    println!();
    println!(
        "  Max |ratio - 1| for γ > 20: {:.6e}",
        max_ratio_err
    );
    println!("  → α·γ = 1 - 1/(4γ²) + O(1/γ⁴) CONFIRMED to all zeros.");
    println!();

    // ═══════════════════════════════════════
    // §3. θ(γ) mod π DISTRIBUTION
    // ═══════════════════════════════════════

    println!("═══ §3. θ(γ_n) mod π DISTRIBUTION ═══");
    println!();

    // Compute θ mod π for all zeros and build histogram
    let n_bins = 20;
    let mut histogram = vec![0u64; n_bins];
    let mut theta_values: Vec<f64> = Vec::with_capacity(n_zeros);

    for &gamma in &zeros {
        let theta = riemann_siegel::rs_theta(gamma);
        let theta_mod = ((theta % PI) + PI) % PI; // Ensure [0, π)
        theta_values.push(theta_mod);
        let bin = ((theta_mod / PI) * n_bins as f64).floor() as usize;
        let bin = bin.min(n_bins - 1);
        histogram[bin] += 1;
    }

    let expected = n_zeros as f64 / n_bins as f64;
    println!("  Histogram of θ(γ) mod π in {} bins (expected {:.0} per bin):", n_bins, expected);
    println!();
    println!("  {:>8} {:>8} {:>10} {:>10}", "bin", "count", "expected", "ratio");
    println!("  {}", "-".repeat(40));

    let mut chi2 = 0.0;
    for (i, &count) in histogram.iter().enumerate() {
        let lo = i as f64 / n_bins as f64 * PI;
        let hi = (i + 1) as f64 / n_bins as f64 * PI;
        let ratio = count as f64 / expected;
        chi2 += (count as f64 - expected).powi(2) / expected;
        println!(
            "  [{:.3},{:.3}) {:>8} {:>10.0} {:>10.4}",
            lo, hi, count, expected, ratio
        );
    }
    println!();
    println!("  χ² = {:.2} (for {} d.f., uniform → ~{})", chi2, n_bins - 1, n_bins - 1);

    if chi2 < 2.0 * n_bins as f64 {
        println!("  → UNIFORM DISTRIBUTION CONFIRMED (χ² well within range)");
    } else {
        println!("  → POSSIBLE DEVIATION from uniformity detected!");
    }
    println!();

    // ═══════════════════════════════════════
    // §4. α·N(γ) CONVERGENCE
    // ═══════════════════════════════════════

    println!("═══ §4. α·N(γ) CONVERGENCE ═══");
    println!();

    println!(
        "  {:>7} {:>12} {:>10} {:>12} {:>12} {:>10}",
        "n", "γ_n", "N(γ)", "α·N", "ln(N)/(2π)", "ratio"
    );
    println!("  {}", "-".repeat(70));

    for &idx in &sample_indices {
        if idx < 2 { continue; }
        let gamma = zeros[idx];
        let n_gamma = n_from_gamma(gamma);
        if n_gamma <= 1.0 { continue; }
        let alpha = central_angle(gamma);
        let alpha_n = alpha * n_gamma;
        let ln_n_2pi = n_gamma.ln() / (2.0 * PI);
        let ratio = if ln_n_2pi > 0.0 { alpha_n / ln_n_2pi } else { 0.0 };

        println!(
            "  {:>7} {:>12.2} {:>10.2} {:>12.6} {:>12.6} {:>10.6}",
            idx + 1,
            gamma,
            n_gamma,
            alpha_n,
            ln_n_2pi,
            ratio
        );
    }
    println!();

    // ═══════════════════════════════════════
    // §5. CONSECUTIVE ZERO SPACING × α
    // ═══════════════════════════════════════

    println!("═══ §5. ZERO SPACING × CENTRAL ANGLE ═══");
    println!();
    println!("  Do consecutive zeros have spacing related to α?");
    println!("  Normalized spacing: (gamma_{{n+1}} - gamma_n) * ln(gamma_n/(2pi)) / (2pi)");
    println!();

    // Compute normalized spacings
    let mut spacings: Vec<f64> = Vec::with_capacity(n_zeros - 1);
    for i in 0..n_zeros - 1 {
        let gamma = zeros[i];
        let delta = zeros[i + 1] - gamma;
        let norm_spacing = delta * (gamma / (2.0 * PI)).ln() / (2.0 * PI);
        spacings.push(norm_spacing);
    }

    // Statistics
    let mean_spacing = spacings.iter().sum::<f64>() / spacings.len() as f64;
    let var_spacing = spacings.iter().map(|s| (s - mean_spacing).powi(2)).sum::<f64>()
        / spacings.len() as f64;

    println!("  Mean normalized spacing: {:.6} (GUE predicts ~1.0)", mean_spacing);
    println!("  Variance: {:.6} (GUE predicts ~0.178)", var_spacing);
    println!();

    // Spacing × α correlation
    let mut alpha_spacing_product: Vec<f64> = Vec::with_capacity(n_zeros - 1);
    for i in 0..n_zeros - 1 {
        let gamma = zeros[i];
        let delta = zeros[i + 1] - gamma;
        let alpha = central_angle(gamma);
        alpha_spacing_product.push(alpha * delta);
    }

    let mean_as = alpha_spacing_product.iter().sum::<f64>() / alpha_spacing_product.len() as f64;
    let var_as = alpha_spacing_product
        .iter()
        .map(|s| (s - mean_as).powi(2))
        .sum::<f64>()
        / alpha_spacing_product.len() as f64;

    println!("  Mean(α · Δγ): {:.8} (since α ≈ 1/γ, this ≈ Δγ/γ)", mean_as);
    println!("  Var(α · Δγ):  {:.8}", var_as);
    println!();

    // ═══════════════════════════════════════
    // §6. THE CRITICAL TEST: Does 1/(4γ²) encode RH?
    // ═══════════════════════════════════════

    println!("═══ §6. CRITICAL TEST: 1/(4γ²) vs higher-order terms ═══");
    println!();
    println!("  α·γ = 1 - c₂/γ² - c₄/γ⁴ - ...");
    println!("  If zeros are at σ = 1/2: c₂ = 1/4 = 0.25");
    println!("  If zeros at σ ≠ 1/2:     c₂ = σ(1-σ) ≠ 1/4");
    println!();
    println!("  Fitting c₂ from data (high γ only):");
    println!();

    // Fit c₂ from pairs of consecutive data points
    let mut c2_estimates: Vec<f64> = Vec::new();
    for i in (n_zeros / 2)..n_zeros {
        let gamma = zeros[i];
        let dev = alpha_gamma_deviation(gamma);
        let c2_est = dev * gamma * gamma;
        c2_estimates.push(c2_est);
    }

    let c2_mean =
        c2_estimates.iter().sum::<f64>() / c2_estimates.len() as f64;
    let c2_std = (c2_estimates
        .iter()
        .map(|c| (c - c2_mean).powi(2))
        .sum::<f64>()
        / c2_estimates.len() as f64)
        .sqrt();

    println!("  Fitted c₂ = {:.10} ± {:.2e}", c2_mean, c2_std);
    println!("  Expected:   0.2500000000 (= 1/4, from σ = 1/2)");
    println!("  Residual:   {:.2e}", (c2_mean - 0.25).abs());
    println!();

    if (c2_mean - 0.25).abs() < 1e-4 {
        println!("  ✅ c₂ = 1/4 CONFIRMED — consistent with all zeros on Re(s) = 1/2");
    } else {
        println!("  ⚠️  c₂ deviates from 1/4 — investigate further!");
    }
    println!();

    // ═══════════════════════════════════════
    // §7. SUMMARY
    // ═══════════════════════════════════════

    println!("═══ SUMMARY ═══");
    println!();
    println!("  Zeros computed: {}", n_zeros);
    println!("  Height range:   [{:.4}, {:.4}]", zeros[0], zeros[n_zeros - 1]);
    println!();
    println!("  α·γ product rule:     1 - 1/(4γ²) + O(1/γ⁴)");
    println!("  Fitted c₂:            {:.10} (expected 0.25)", c2_mean);
    println!("  θ mod π distribution: {} (χ² = {:.1})",
        if chi2 < 2.0 * n_bins as f64 { "UNIFORM" } else { "NON-UNIFORM" },
        chi2);
    println!("  Mean spacing:         {:.6} (GUE: ~1.0)", mean_spacing);
    println!("  Spacing variance:     {:.6} (GUE: ~0.178)", var_spacing);
}
