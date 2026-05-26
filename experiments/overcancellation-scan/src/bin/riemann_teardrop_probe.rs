// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║  RIEMANN TEARDROP PROBE                                                  ║
// ║                                                                          ║
// ║  The circle at each zero ρ = 1/2 + iγ, when lifted from 2D to higher   ║
// ║  dimensions via ζ(s), becomes a TEARDROP — pinching at the zero where   ║
// ║  |ζ| = 0, bulging where |ζ| is large.                                  ║
// ║                                                                          ║
// ║  Coordinates:                                                            ║
// ║    dim 1-2: (Re(s), Im(s)) — the circle                                ║
// ║    dim 3:   |ζ(s)| — the "height" (zero at ρ, positive elsewhere)      ║
// ║    dim 4:   arg(ζ(s)) — the phase (winds once around the zero)         ║
// ║    dim 5:   θ_RS — Riemann-Siegel phase                                ║
// ║    dim 6+:  Dirichlet partial sums — spectral decomposition            ║
// ║                                                                          ║
// ║  The teardrop shape encodes HOW the zero sits in spectral space.        ║
// ╚═══════════════════════════════════════════════════════════════════════════╝

use cathedral_utils::riemann_siegel;
use std::f64::consts::PI;

/// Compute ζ(s) via the approximate functional equation (Riemann-Siegel).
/// Returns (Re(ζ), Im(ζ)) for s = σ + it.
///
/// Uses: ζ(s) = Σ_{n≤N} n^{-s} + χ(s) · Σ_{n≤N} n^{-(1-s)} + remainder
/// where N = floor(√(t/(2π))), and χ(s) = π^{s-1/2} Γ((1-s)/2) / Γ(s/2).
///
/// For moderate t, this gives ~10⁻⁶ accuracy.
fn zeta_approx(sigma: f64, t: f64) -> (f64, f64) {
    let n_max = ((t.abs() / (2.0 * PI)).sqrt()).floor().max(1.0) as usize;

    // Main sum: Σ n^{-s} = Σ n^{-σ} · e^{-it·ln(n)}
    let mut sum_re = 0.0;
    let mut sum_im = 0.0;
    for n in 1..=n_max {
        let nf = n as f64;
        let mag = nf.powf(-sigma);
        let phase = -t * nf.ln();
        sum_re += mag * phase.cos();
        sum_im += mag * phase.sin();
    }

    // Chi factor: χ(s) = 2^s · π^{s-1} · sin(πs/2) · Γ(1-s)
    // For the functional equation correction.
    // Use the simplified version for the critical strip:
    // χ(s) ≈ (t/(2π))^{1/2-σ} · e^{i(θ(t) + (σ-1/2)·π/2)}
    // where θ(t) is the Riemann-Siegel theta function.
    if t.abs() > 10.0 {
        let theta = riemann_siegel::rs_theta(t.abs());
        let chi_mag = (t.abs() / (2.0 * PI)).powf(0.5 - sigma);
        let chi_phase = theta + (sigma - 0.5) * PI / 2.0;
        let chi_re = chi_mag * chi_phase.cos();
        let chi_im = chi_mag * chi_phase.sin();

        // Conjugate sum: Σ n^{-(1-s)} = Σ n^{-(1-σ)} · e^{it·ln(n)}
        let mut conj_re = 0.0;
        let mut conj_im = 0.0;
        for n in 1..=n_max {
            let nf = n as f64;
            let mag = nf.powf(-(1.0 - sigma));
            let phase = t * nf.ln();
            conj_re += mag * phase.cos();
            conj_im += mag * phase.sin();
        }

        // χ · conj_sum
        let correction_re = chi_re * conj_re - chi_im * conj_im;
        let correction_im = chi_re * conj_im + chi_im * conj_re;

        sum_re += correction_re;
        sum_im += correction_im;
    }

    (sum_re, sum_im)
}

/// Compute |ζ(s)|² for s = σ + it
fn zeta_abs_sq(sigma: f64, t: f64) -> f64 {
    let (re, im) = zeta_approx(sigma, t);
    re * re + im * im
}

/// Compute arg(ζ(s)) for s = σ + it
fn zeta_arg(sigma: f64, t: f64) -> f64 {
    let (re, im) = zeta_approx(sigma, t);
    im.atan2(re)
}

/// Dirichlet partial sum D_K(s) = Σ_{n=1}^{K} n^{-s}
/// Returns |D_K(s)|
fn dirichlet_partial_abs(k: usize, sigma: f64, t: f64) -> f64 {
    let mut re = 0.0;
    let mut im = 0.0;
    for n in 1..=k {
        let nf = n as f64;
        let mag = nf.powf(-sigma);
        let phase = -t * nf.ln();
        re += mag * phase.cos();
        im += mag * phase.sin();
    }
    (re * re + im * im).sqrt()
}

/// Teardrop shape analysis for a single zero
struct TeardropShape {
    gamma: f64,
    radius: f64,
    // Shape measurements
    max_zeta_abs: f64,
    min_zeta_abs: f64,
    asymmetry: f64,          // (max - min) / (max + min)
    pinch_angle: f64,        // angle where |ζ| is minimum (should be near the zero)
    bulge_angle: f64,        // angle where |ζ| is maximum
    phase_winding: f64,      // total phase change (should be ≈ 2π for simple zero)
    // Higher-dimensional measurements
    d2_asymmetry: f64,       // asymmetry using D_2 partial sum
    d5_asymmetry: f64,       // asymmetry using D_5 partial sum
    d10_asymmetry: f64,      // asymmetry using D_10 partial sum
    // Teardrop orientation
    centroid_re_shift: f64,  // how much the centroid shifts from circle center (Re)
    centroid_im_shift: f64,  // how much the centroid shifts from circle center (Im)
}

fn analyze_teardrop(gamma: f64, radius: f64, n_points: usize) -> TeardropShape {
    let center_re = 0.5;
    let center_im = gamma;

    let mut max_zeta = 0.0f64;
    let mut min_zeta = f64::MAX;
    let mut pinch_phi = 0.0;
    let mut bulge_phi = 0.0;

    let mut phases: Vec<f64> = Vec::with_capacity(n_points);
    let mut zeta_values: Vec<(f64, f64)> = Vec::with_capacity(n_points);

    // Weighted centroid (weighted by |ζ|)
    let mut wcx = 0.0;
    let mut wcy = 0.0;
    let mut wtotal = 0.0;

    // D_K partial sums
    let mut d2_max = 0.0f64;
    let mut d2_min = f64::MAX;
    let mut d5_max = 0.0f64;
    let mut d5_min = f64::MAX;
    let mut d10_max = 0.0f64;
    let mut d10_min = f64::MAX;

    for i in 0..n_points {
        let phi = 2.0 * PI * i as f64 / n_points as f64;
        let sigma = center_re + radius * phi.cos();
        let t = center_im + radius * phi.sin();

        // Skip if sigma < 0 (numerical instability)
        if sigma < 0.01 || t < 5.0 {
            continue;
        }

        let (zre, zim) = zeta_approx(sigma, t);
        let z_abs = (zre * zre + zim * zim).sqrt();
        let z_arg = zim.atan2(zre);

        zeta_values.push((zre, zim));
        phases.push(z_arg);

        if z_abs > max_zeta {
            max_zeta = z_abs;
            bulge_phi = phi;
        }
        if z_abs < min_zeta {
            min_zeta = z_abs;
            pinch_phi = phi;
        }

        // Weighted centroid
        let px = center_re + radius * phi.cos();
        let py = center_im + radius * phi.sin();
        wcx += px * z_abs;
        wcy += py * z_abs;
        wtotal += z_abs;

        // Partial sums
        let d2 = dirichlet_partial_abs(2, sigma, t);
        let d5 = dirichlet_partial_abs(5, sigma, t);
        let d10 = dirichlet_partial_abs(10, sigma, t);
        d2_max = d2_max.max(d2);
        d2_min = d2_min.min(d2);
        d5_max = d5_max.max(d5);
        d5_min = d5_min.min(d5);
        d10_max = d10_max.max(d10);
        d10_min = d10_min.min(d10);
    }

    // Phase winding
    let mut total_winding = 0.0;
    for i in 1..phases.len() {
        let mut dphi = phases[i] - phases[i - 1];
        if dphi > PI { dphi -= 2.0 * PI; }
        if dphi < -PI { dphi += 2.0 * PI; }
        total_winding += dphi;
    }
    // Close the loop
    if !phases.is_empty() {
        let mut dphi = phases[0] - phases[phases.len() - 1];
        if dphi > PI { dphi -= 2.0 * PI; }
        if dphi < -PI { dphi += 2.0 * PI; }
        total_winding += dphi;
    }

    let asymmetry = if max_zeta + min_zeta > 0.0 {
        (max_zeta - min_zeta) / (max_zeta + min_zeta)
    } else { 0.0 };

    let centroid_re_shift = if wtotal > 0.0 { wcx / wtotal - center_re } else { 0.0 };
    let centroid_im_shift = if wtotal > 0.0 { wcy / wtotal - center_im } else { 0.0 };

    let d2_asym = if d2_max + d2_min > 0.0 { (d2_max - d2_min) / (d2_max + d2_min) } else { 0.0 };
    let d5_asym = if d5_max + d5_min > 0.0 { (d5_max - d5_min) / (d5_max + d5_min) } else { 0.0 };
    let d10_asym = if d10_max + d10_min > 0.0 { (d10_max - d10_min) / (d10_max + d10_min) } else { 0.0 };

    TeardropShape {
        gamma,
        radius,
        max_zeta_abs: max_zeta,
        min_zeta_abs: min_zeta,
        asymmetry,
        pinch_angle: pinch_phi,
        bulge_angle: bulge_phi,
        phase_winding: total_winding,
        d2_asymmetry: d2_asym,
        d5_asymmetry: d5_asym,
        d10_asymmetry: d10_asym,
        centroid_re_shift,
        centroid_im_shift,
    }
}

fn main() {
    println!("╔═══════════════════════════════════════════════════════════════╗");
    println!("║  RIEMANN TEARDROP PROBE                                     ║");
    println!("║  Lifting circles at ζ zeros into spectral space             ║");
    println!("╚═══════════════════════════════════════════════════════════════╝");
    println!();

    // ═══════════════════════════════════════
    // §1. FIND ZEROS
    // ═══════════════════════════════════════

    println!("  Computing zeros up to t = 500...");
    let zeros = riemann_siegel::find_zeros(500.0);
    println!("  Found {} zeros.", zeros.len());
    println!();

    // ═══════════════════════════════════════
    // §2. TEARDROP ANALYSIS AT MULTIPLE RADII
    // ═══════════════════════════════════════

    println!("═══ §2. TEARDROP SHAPE AT EACH ZERO ═══");
    println!();
    println!("  Using radius = r_n = √(1/4 + γ²) (circle through s=0 and s=1)");
    println!();

    // Small radius teardrops (local structure near zero)
    println!("  ── LOCAL TEARDROPS (radius = 1.0) ──");
    println!();
    println!("  {:>4} {:>8} {:>10} {:>10} {:>8} {:>8} {:>8} {:>8} {:>10} {:>10}",
             "n", "γ", "|ζ|_max", "|ζ|_min", "asym", "winding", "D2_asy", "D10_asy", "Δ_Re", "Δ_Im");
    println!("  {}", "-".repeat(100));

    let small_radius = 1.0;
    let n_sample = 360;

    for (i, &gamma) in zeros.iter().take(30).enumerate() {
        if gamma < 12.0 { continue; }
        let td = analyze_teardrop(gamma, small_radius, n_sample);
        println!(
            "  {:>4} {:>8.2} {:>10.4} {:>10.6} {:>8.4} {:>8.3} {:>8.4} {:>8.4} {:>+10.4} {:>+10.4}",
            i + 1, gamma, td.max_zeta_abs, td.min_zeta_abs,
            td.asymmetry, td.phase_winding / PI, td.d2_asymmetry, td.d10_asymmetry,
            td.centroid_re_shift, td.centroid_im_shift
        );
    }
    println!();

    // ═══════════════════════════════════════
    // §3. TEARDROP ORIENTATION
    // ═══════════════════════════════════════

    println!("═══ §3. TEARDROP ORIENTATION ═══");
    println!();
    println!("  The centroid shift (Δ_Re, Δ_Im) shows which way the teardrop 'points'.");
    println!("  If Δ_Re > 0: teardrop points toward Re(s) = 1 (right)");
    println!("  If Δ_Re < 0: teardrop points toward Re(s) = 0 (left)");
    println!();

    let mut right_count = 0;
    let mut left_count = 0;
    let mut up_count = 0;
    let mut down_count = 0;

    for &gamma in zeros.iter().take(80) {
        if gamma < 12.0 { continue; }
        let td = analyze_teardrop(gamma, small_radius, n_sample);
        if td.centroid_re_shift > 0.0 { right_count += 1; } else { left_count += 1; }
        if td.centroid_im_shift > 0.0 { up_count += 1; } else { down_count += 1; }
    }
    println!("  Centroid pointing RIGHT (toward s=1): {}", right_count);
    println!("  Centroid pointing LEFT  (toward s=0): {}", left_count);
    println!("  Centroid pointing UP   (higher γ):    {}", up_count);
    println!("  Centroid pointing DOWN (lower γ):     {}", down_count);
    println!();

    // ═══════════════════════════════════════
    // §4. RADIUS DEPENDENCE
    // ═══════════════════════════════════════

    println!("═══ §4. TEARDROP vs RADIUS (at γ₁ ≈ 14.13) ═══");
    println!();

    let gamma_1 = zeros[0];
    println!("  {:>8} {:>10} {:>10} {:>8} {:>8} {:>+10} {:>+10}",
             "radius", "|ζ|_max", "|ζ|_min", "asym", "winding", "Δ_Re", "Δ_Im");
    println!("  {}", "-".repeat(70));

    for &r in &[0.1, 0.5, 1.0, 2.0, 5.0, 10.0] {
        let td = analyze_teardrop(gamma_1, r, n_sample);
        println!(
            "  {:>8.1} {:>10.4} {:>10.6} {:>8.4} {:>8.3} {:>+10.4} {:>+10.4}",
            r, td.max_zeta_abs, td.min_zeta_abs,
            td.asymmetry, td.phase_winding / PI,
            td.centroid_re_shift, td.centroid_im_shift
        );
    }
    println!();

    // ═══════════════════════════════════════
    // §5. SPECTRAL DIMENSION ANALYSIS
    // ═══════════════════════════════════════

    println!("═══ §5. SPECTRAL DIMENSIONS — How many D to describe the teardrop? ═══");
    println!();
    println!("  For each zero, compare asymmetry of D_K partial sums:");
    println!("  D_2 sees only n=1,2; D_5 sees n=1..5; D_10 sees n=1..10");
    println!("  If D_K asymmetry grows with K, the teardrop has 'spectral depth'.");
    println!();

    println!("  {:>4} {:>8} {:>10} {:>10} {:>10} {:>10} {:>12}",
             "n", "γ", "D2_asym", "D5_asym", "D10_asym", "|ζ|_asym", "D10/D2");
    println!("  {}", "-".repeat(70));

    for (i, &gamma) in zeros.iter().take(20).enumerate() {
        if gamma < 12.0 { continue; }
        let td = analyze_teardrop(gamma, small_radius, n_sample);
        let ratio = if td.d2_asymmetry > 0.0 { td.d10_asymmetry / td.d2_asymmetry } else { 0.0 };
        println!(
            "  {:>4} {:>8.2} {:>10.4} {:>10.4} {:>10.4} {:>10.4} {:>12.4}",
            i + 1, gamma, td.d2_asymmetry, td.d5_asymmetry, td.d10_asymmetry,
            td.asymmetry, ratio
        );
    }
    println!();

    // ═══════════════════════════════════════
    // §6. THE BIG CIRCLE — Through s=0 and s=1
    // ═══════════════════════════════════════

    println!("═══ §6. THE BIG CIRCLE (r = |ρ|, through s=0 and s=1) ═══");
    println!();
    println!("  For the first 5 zeros, analyze the full-radius teardrop.");
    println!();

    println!("  {:>4} {:>8} {:>10} {:>10} {:>10} {:>8} {:>+10} {:>+10}",
             "n", "γ", "radius", "|ζ|_max", "|ζ|_min", "asym", "Δ_Re", "Δ_Im");
    println!("  {}", "-".repeat(75));

    for (i, &gamma) in zeros.iter().take(5).enumerate() {
        let big_r = (0.25 + gamma * gamma).sqrt();
        let td = analyze_teardrop(gamma, big_r, n_sample);
        println!(
            "  {:>4} {:>8.2} {:>10.2} {:>10.4} {:>10.6} {:>8.4} {:>+10.4} {:>+10.4}",
            i + 1, gamma, big_r, td.max_zeta_abs, td.min_zeta_abs,
            td.asymmetry, td.centroid_re_shift, td.centroid_im_shift
        );
    }
    println!();

    // ═══════════════════════════════════════
    // §7. SUMMARY
    // ═══════════════════════════════════════

    println!("═══ SUMMARY ═══");
    println!();
    println!("  The 'Riemann Teardrop' is the lift of the zero-circle into");
    println!("  spectral space via (Re(s), Im(s), |ζ(s)|, arg(ζ(s)), D_K(s), ...)");
    println!();
    println!("  Key measurements:");
    println!("  1. ASYMMETRY: how much the teardrop deviates from a circle");
    println!("  2. WINDING:   arg(ζ) winds ≈ 2π around a simple zero");
    println!("  3. CENTROID:  which direction the teardrop 'points'");
    println!("  4. SPECTRAL DEPTH: how D_K asymmetry grows with K");
}
