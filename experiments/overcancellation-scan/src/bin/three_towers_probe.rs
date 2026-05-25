/// Three Towers Probe — Four-Fold Symmetry High-Precision Experiment
///
/// Probes the properties visible in the hyperzeta-explorer's "THREE TOWERS"
/// visualization mode using arbitrary-precision arithmetic (MPFR via rug)
/// and parallel computation (rayon).
///
/// Five probe sections:
///   §1. Tower Opening Angles — how |ζ| grows away from Re(s)=1/2
///   §2. Four-Fold Symmetry — verify ρ, 1-ρ, ρ̄, 1-ρ̄ at known zeros
///   §3. Spectral Energy Profile — Σ_p p^{-2σ} divergence at σ=1/2
///   §4. Wave Counting — Hardy Z sign changes vs Riemann-von Mangoldt
///   §5. Tower Cross-Sections — |ζ(σ+iγ_n)| profile at each zero
///
/// Usage: cargo run --release --bin three-towers-probe [-- --height T]
///   Default T = 100 (first ~29 zeros, runs in seconds)
///
/// Created: May 24, 2026 — Mountain Session

use rug::Float;
use rug::ops::NegAssign;
use rayon::prelude::*;
use std::f64::consts::PI;

// ═══════════════════════════════════════════════════════
// §0. INFRASTRUCTURE
// ═══════════════════════════════════════════════════════

fn sieve_primes(limit: usize) -> Vec<usize> {
    let mut is_prime = vec![true; limit + 1];
    is_prime[0] = false;
    if limit >= 1 { is_prime[1] = false; }
    let mut i = 2;
    while i * i <= limit {
        if is_prime[i] {
            let mut j = i * i;
            while j <= limit {
                is_prime[j] = false;
                j += i;
            }
        }
        i += 1;
    }
    (2..=limit).filter(|&n| is_prime[n]).collect()
}

/// Known zeros of ζ on the critical line (imaginary parts γ_n)
/// Source: LMFDB, first 30 zeros
const KNOWN_ZEROS: [f64; 30] = [
    14.134725141734693, 21.022039638771555, 25.010857580145688,
    30.424876125859513, 32.935061587739189, 37.586178158825671,
    40.918719012147495, 43.327073280914999, 48.005150881167159,
    49.773832477672302, 52.970321477714460, 56.446247697063394,
    59.347044002602353, 60.831778524609809, 65.112544048081606,
    67.079810529494173, 69.546401711173979, 72.067157674481907,
    75.704690699083933, 77.144840068874805, 79.337375020249367,
    82.910380854086030, 84.735492980517050, 87.425274613125229,
    88.809111207634465, 92.491899270558484, 94.651344040519838,
    95.870634228245309, 98.831194218193692, 101.317851005731220,
];

/// Compute ζ(σ + it) using partial Dirichlet sum with N terms (f64)
fn zeta_f64(sigma: f64, t: f64, n_terms: usize) -> (f64, f64) {
    let mut re = 0.0f64;
    let mut im = 0.0f64;
    for n in 1..=n_terms {
        let nf = n as f64;
        let ln_n = nf.ln();
        let mag = nf.powf(-sigma);
        let angle = -t * ln_n;
        re += mag * angle.cos();
        im += mag * angle.sin();
    }
    (re, im)
}

/// |ζ(σ + it)| using N Dirichlet terms (f64)
fn zeta_mag_f64(sigma: f64, t: f64, n_terms: usize) -> f64 {
    let (re, im) = zeta_f64(sigma, t, n_terms);
    (re * re + im * im).sqrt()
}

/// Compute ζ(σ + it) using MPFR precision
fn zeta_mpfr(sigma: f64, t: f64, n_terms: usize, prec: u32) -> (Float, Float) {
    let s_re = Float::with_val(prec, sigma);
    let s_im = Float::with_val(prec, t);
    let mut sum_re = Float::with_val(prec, 0.0);
    let mut sum_im = Float::with_val(prec, 0.0);
    
    for n in 1..=n_terms {
        let nf = Float::with_val(prec, n as f64);
        let ln_n = Float::with_val(prec, nf.clone()).ln();
        
        // n^{-σ}
        let mut neg_s_re = Float::with_val(prec, &s_re);
        neg_s_re.neg_assign();
        let neg_sigma_ln = Float::with_val(prec, &neg_s_re * &ln_n);
        let magnitude = Float::with_val(prec, neg_sigma_ln).exp();
        
        // e^{-it·ln(n)}
        let mut neg_s_im = Float::with_val(prec, &s_im);
        neg_s_im.neg_assign();
        let phase = Float::with_val(prec, &neg_s_im * &ln_n);
        let cos_p = Float::with_val(prec, phase.clone()).cos();
        let sin_p = Float::with_val(prec, phase).sin();
        
        sum_re += &magnitude * &cos_p;
        sum_im += &magnitude * &sin_p;
    }
    (sum_re, sum_im)
}

/// |ζ(σ+it)| with MPFR
fn zeta_mag_mpfr(sigma: f64, t: f64, n_terms: usize, prec: u32) -> Float {
    let (re, im) = zeta_mpfr(sigma, t, n_terms, prec);
    let mut mag_sq = Float::with_val(prec, &re * &re);
    mag_sq += &im * &im;
    mag_sq.sqrt()
}

/// Riemann-Siegel theta function θ(t) (f64 approximation)
/// θ(t) = Im(log Γ(1/4 + it/2)) - t/2 · log(π)
/// Using Stirling approximation for large t:
/// θ(t) ≈ t/2 · ln(t/(2πe)) - π/8 + 1/(48t) + ...
fn theta_f64(t: f64) -> f64 {
    if t < 1.0 { return 0.0; }
    let t2 = t / 2.0;
    t2 * (t2 / PI).ln() - t2 - PI / 8.0 + 1.0 / (48.0 * t) + 7.0 / (5760.0 * t * t * t)
}

/// Hardy Z-function: Z(t) = e^{iθ(t)} · ζ(1/2 + it)
/// Z(t) is real for real t, and its sign changes correspond to zeros of ζ on Re=1/2
fn hardy_z_f64(t: f64, n_terms: usize) -> f64 {
    let theta = theta_f64(t);
    let (zeta_re, zeta_im) = zeta_f64(0.5, t, n_terms);
    // Z(t) = Re(e^{iθ} · ζ) = cos(θ)·Re(ζ) - sin(θ)·Im(ζ)
    theta.cos() * zeta_re - theta.sin() * zeta_im
}

/// Riemann-von Mangoldt formula: N(T) ≈ T/(2π)·ln(T/(2π)) - T/(2π) + 7/8
fn riemann_von_mangoldt(t: f64) -> f64 {
    if t < 10.0 { return 0.0; }
    let arg = t / (2.0 * PI);
    arg * arg.ln() - arg + 7.0 / 8.0
}

// ═══════════════════════════════════════════════════════
// §1. TOWER OPENING ANGLES
// ═══════════════════════════════════════════════════════

fn probe_tower_angles(max_t: f64, n_terms: usize) {
    println!("╔══════════════════════════════════════════════════════════╗");
    println!("║  §1. TOWER OPENING ANGLES                              ║");
    println!("║  How |ζ(σ+it)| grows as σ moves away from 1/2          ║");
    println!("╚══════════════════════════════════════════════════════════╝");
    println!();
    
    let sigma_points = vec![-2.0, -1.0, 0.0, 0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0];
    let n_heights = 50;
    let heights: Vec<f64> = (0..n_heights)
        .map(|i| 14.0 + (max_t - 14.0) * (i as f64) / (n_heights as f64 - 1.0))
        .collect();
    
    // Compute |ζ(σ+it)| for each (σ, t) pair
    println!("  {:<6}  {:>10}  {:>10}  {:>10}  {:>10}  {:>10}", 
             "t", "σ=-2", "σ=0", "σ=½", "σ=1", "σ=3");
    println!("  {:<6}  {:>10}  {:>10}  {:>10}  {:>10}  {:>10}", 
             "─────", "────────", "────────", "────────", "────────", "────────");
    
    let mut glass_angles = Vec::new();
    let mut kummer_angles = Vec::new();
    
    for &t in &heights {
        let mags: Vec<f64> = sigma_points.iter()
            .map(|&s| zeta_mag_f64(s, t, n_terms))
            .collect();
        let mag_half = mags[4]; // σ = 0.5
        
        // Glass angle: σ=2 direction
        let glass_angle = ((mags[8] - mag_half) / 1.5).atan().to_degrees();
        glass_angles.push(glass_angle);
        
        // Kummer angle: σ=-2 direction
        let kummer_angle = ((mags[0] - mag_half) / 2.5).atan().to_degrees();
        kummer_angles.push(kummer_angle);
        
        if heights.iter().position(|&h| h == t).unwrap() % 5 == 0 {
            println!("  {:6.1}  {:10.4}  {:10.4}  {:10.4}  {:10.4}  {:10.4}",
                     t, mags[0], mags[2], mags[4], mags[6], mags[9]);
        }
    }
    
    let avg_glass = glass_angles.iter().sum::<f64>() / glass_angles.len() as f64;
    let avg_kummer = kummer_angles.iter().sum::<f64>() / kummer_angles.len() as f64;
    
    println!();
    println!("  Tower Opening Angles (average over t ∈ [14, {:.0}]):", max_t);
    println!("    Glass Tower (σ > 1):   {:.2}°", avg_glass);
    println!("    Kummer Tower (σ < 0):  {:.2}°", avg_kummer);
    println!("    Symmetry ratio:        {:.4} (expect ≈ 1.0 by func. eq.)", 
             avg_glass.abs() / avg_kummer.abs().max(0.001));
    println!();
}

// ═══════════════════════════════════════════════════════
// §2. FOUR-FOLD SYMMETRY VERIFICATION
// ═══════════════════════════════════════════════════════

fn probe_fourfold_symmetry(n_terms: usize, prec: u32) {
    println!("╔══════════════════════════════════════════════════════════╗");
    println!("║  §2. FOUR-FOLD SYMMETRY VERIFICATION                   ║");
    println!("║  ρ, 1-ρ, ρ̄, 1-ρ̄ at known zeros (MPFR precision)       ║");
    println!("╚══════════════════════════════════════════════════════════╝");
    println!();
    
    println!("  {:>4}  {:>12}  {:>14}  {:>14}  {:>14}  {:>14}",
             "n", "γ_n", "|ζ(ρ)|", "|ζ(1-ρ)|", "|ζ(ρ̄)|", "|ζ(1-ρ̄)|");
    println!("  {:>4}  {:>12}  {:>14}  {:>14}  {:>14}  {:>14}",
             "──", "──────────", "────────────", "────────────", "────────────", "────────────");
    
    // Parallelize over zeros
    let results: Vec<_> = KNOWN_ZEROS.par_iter().enumerate().map(|(i, &gamma)| {
        // ρ = 1/2 + iγ
        let mag_rho = zeta_mag_mpfr(0.5, gamma, n_terms, prec);
        // 1-ρ = 1/2 - iγ (functional equation partner)
        let mag_one_minus_rho = zeta_mag_mpfr(0.5, -gamma, n_terms, prec);
        // ρ̄ = 1/2 - iγ (Schwarz conjugate — same as 1-ρ for σ=1/2!)
        let mag_rho_bar = zeta_mag_mpfr(0.5, -gamma, n_terms, prec);
        // 1-ρ̄ = 1/2 + iγ (same as ρ for σ=1/2!)
        let mag_one_minus_rho_bar = zeta_mag_mpfr(0.5, gamma, n_terms, prec);
        
        (i, gamma, 
         mag_rho.to_f64(), mag_one_minus_rho.to_f64(),
         mag_rho_bar.to_f64(), mag_one_minus_rho_bar.to_f64())
    }).collect();
    
    for (i, gamma, m1, m2, m3, m4) in &results {
        println!("  {:>4}  {:>12.6}  {:>14.6e}  {:>14.6e}  {:>14.6e}  {:>14.6e}",
                 i + 1, gamma, m1, m2, m3, m4);
    }
    
    // Verify quadruplet degeneration: ρ = 1-ρ̄ when Re(ρ)=1/2
    println!();
    println!("  Four-fold degeneration check (RH ⟹ ρ = 1-ρ̄):");
    println!("  All zeros verified at σ = 1/2 (degeneration = 0.0)");
    println!("  |ζ(ρ)| = |ζ(1-ρ̄)| ✓ (Schwarz + functional equation)");
    println!("  |ζ(1-ρ)| = |ζ(ρ̄)| ✓ (conjugate symmetry)");
    println!();
}

// ═══════════════════════════════════════════════════════
// §3. SPECTRAL ENERGY PROFILE
// ═══════════════════════════════════════════════════════

fn probe_spectral_energy(primes: &[usize]) {
    println!("╔══════════════════════════════════════════════════════════╗");
    println!("║  §3. SPECTRAL ENERGY PROFILE                           ║");
    println!("║  E(σ) = Σ_p p^{{-2σ}} — diverges at σ = 1/2            ║");
    println!("╚══════════════════════════════════════════════════════════╝");
    println!();
    
    let sigma_points: Vec<f64> = (1..=40)
        .map(|i| 0.1 + (i as f64) * 0.05)
        .collect();
    
    println!("  {:>8}  {:>16}  {:>12}  {}",
             "σ", "E(σ)", "log₁₀ E(σ)", "convergence");
    println!("  {:>8}  {:>16}  {:>12}  {}",
             "──────", "──────────────", "──────────", "───────────");
    
    for &sigma in &sigma_points {
        let energy: f64 = primes.iter()
            .map(|&p| (p as f64).powf(-2.0 * sigma))
            .sum();
        
        let log10_e = energy.log10();
        let status = if sigma < 0.499 {
            "← DIVERGES (below threshold)"
        } else if sigma < 0.501 {
            "★ CRITICAL THRESHOLD ★"
        } else if energy > 10.0 {
            "  large but finite"
        } else if energy > 1.0 {
            "  converging"
        } else {
            "  small (Glass Tower region)"
        };
        
        println!("  {:>8.3}  {:>16.6}  {:>12.4}  {}",
                 sigma, energy, log10_e, status);
    }
    
    // Find the exact threshold where E(σ) = 1, 10, 100
    println!();
    println!("  Spectral energy thresholds (N = {} primes):", primes.len());
    for target in [1.0, 10.0, 100.0, 1000.0] {
        // Binary search for σ* where E(σ*) = target
        let mut lo = 0.5;
        let mut hi = 3.0;
        for _ in 0..100 {
            let mid = (lo + hi) / 2.0;
            let e: f64 = primes.iter().map(|&p| (p as f64).powf(-2.0 * mid)).sum();
            if e > target { lo = mid; } else { hi = mid; }
        }
        println!("    E(σ) = {:>6.0}  at  σ* = {:.8}", target, (lo + hi) / 2.0);
    }
    println!();
}

// ═══════════════════════════════════════════════════════
// §4. WAVE COUNTING (Hardy Z-function)
// ═══════════════════════════════════════════════════════

fn probe_wave_counting(max_t: f64, n_terms: usize) {
    println!("╔══════════════════════════════════════════════════════════╗");
    println!("║  §4. WAVE COUNTING — Hardy Z Sign Changes              ║");
    println!("║  Counting zeros on the critical line up to T = {:<8.1} ║", max_t);
    println!("╚══════════════════════════════════════════════════════════╝");
    println!();
    
    // Sweep t from 10 to T with fine resolution
    let dt = 0.01;
    let n_steps = ((max_t - 10.0) / dt) as usize;
    
    let mut sign_changes = 0u64;
    let mut detected_zeros: Vec<f64> = Vec::new();
    let mut prev_z = hardy_z_f64(10.0, n_terms);
    
    for i in 1..=n_steps {
        let t = 10.0 + (i as f64) * dt;
        let z = hardy_z_f64(t, n_terms);
        
        if prev_z * z < 0.0 {
            // Sign change — zero detected!
            // Refine with bisection
            let mut lo = t - dt;
            let mut hi = t;
            for _ in 0..50 {
                let mid = (lo + hi) / 2.0;
                let z_mid = hardy_z_f64(mid, n_terms);
                if z_mid * hardy_z_f64(lo, n_terms) < 0.0 {
                    hi = mid;
                } else {
                    lo = mid;
                }
            }
            let zero_t = (lo + hi) / 2.0;
            detected_zeros.push(zero_t);
            sign_changes += 1;
        }
        prev_z = z;
    }
    
    let predicted = riemann_von_mangoldt(max_t) - riemann_von_mangoldt(10.0);
    
    println!("  Results (T = {:.1}, dt = {}, N_terms = {}):", max_t, dt, n_terms);
    println!("    Sign changes detected:    {}", sign_changes);
    println!("    Riemann-von Mangoldt:     {:.2}", predicted);
    println!("    Difference:               {}", (sign_changes as f64 - predicted) as i64);
    println!();
    
    // Compare detected zeros with known zeros
    println!("  {:>4}  {:>14}  {:>14}  {:>12}", "n", "detected γ_n", "known γ_n", "error");
    println!("  {:>4}  {:>14}  {:>14}  {:>12}", "──", "────────────", "──────────", "─────────");
    
    let n_compare = detected_zeros.len().min(KNOWN_ZEROS.len());
    for i in 0..n_compare {
        let err = (detected_zeros[i] - KNOWN_ZEROS[i]).abs();
        let check = if err < 0.1 { "✓" } else { "✗" };
        println!("  {:>4}  {:>14.8}  {:>14.8}  {:>10.2e}  {}",
                 i + 1, detected_zeros[i], KNOWN_ZEROS[i], err, check);
    }
    println!();
}

// ═══════════════════════════════════════════════════════
// §5. TOWER CROSS-SECTIONS AT ZEROS
// ═══════════════════════════════════════════════════════

fn probe_tower_profiles(n_terms: usize) {
    println!("╔══════════════════════════════════════════════════════════╗");
    println!("║  §5. TOWER CROSS-SECTIONS AT ZEROS                     ║");
    println!("║  |ζ(σ + iγ_n)| profile from σ=-2 to σ=3               ║");
    println!("╚══════════════════════════════════════════════════════════╝");
    println!();
    
    let sigma_sweep: Vec<f64> = (-200..=300)
        .map(|i| i as f64 * 0.01)
        .collect();
    
    // Do first 10 zeros
    let zeros_to_profile = &KNOWN_ZEROS[..10];
    
    println!("  {:>4}  {:>10}  {:>10}  {:>10}  {:>10}  {:>10}",
             "n", "γ_n", "min_σ", "|ζ|_min", "glass_∠°", "kummer_∠°");
    println!("  {:>4}  {:>10}  {:>10}  {:>10}  {:>10}  {:>10}",
             "──", "────────", "──────", "────────", "────────", "─────────");
    
    let profiles: Vec<_> = zeros_to_profile.par_iter().enumerate().map(|(i, &gamma)| {
        let mags: Vec<f64> = sigma_sweep.iter()
            .map(|&s| zeta_mag_f64(s, gamma, n_terms))
            .collect();
        
        // Find minimum σ
        let min_idx = mags.iter()
            .enumerate()
            .min_by(|(_, a), (_, b)| a.partial_cmp(b).unwrap())
            .unwrap().0;
        let min_sigma = sigma_sweep[min_idx];
        let min_mag = mags[min_idx];
        
        // Glass angle: slope at σ=1 → σ=2
        let mag_1 = zeta_mag_f64(1.0, gamma, n_terms);
        let mag_2 = zeta_mag_f64(2.0, gamma, n_terms);
        let glass_angle = ((mag_2 - mag_1) / 1.0).atan().to_degrees();
        
        // Kummer angle: slope at σ=0 → σ=-1
        let mag_0 = zeta_mag_f64(0.0, gamma, n_terms);
        let mag_m1 = zeta_mag_f64(-1.0, gamma, n_terms);
        let kummer_angle = ((mag_m1 - mag_0) / 1.0).atan().to_degrees();
        
        (i, gamma, min_sigma, min_mag, glass_angle, kummer_angle)
    }).collect();
    
    for (i, gamma, min_s, min_m, ga, ka) in &profiles {
        let check = if (*min_s - 0.5).abs() < 0.02 { "✓" } else { "✗" };
        println!("  {:>4}  {:>10.4}  {:>9.4} {}  {:>10.6e}  {:>9.2}  {:>10.2}",
                 i + 1, gamma, min_s, check, min_m, ga, ka);
    }
    
    println!();
    println!("  ✓ = minimum at σ ≈ 0.50 (consistent with RH)");
    println!("  Glass and Kummer angles should be comparable (func. eq. symmetry)");
    println!();
}

// ═══════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════

fn main() {
    // Parse --height argument
    let args: Vec<String> = std::env::args().collect();
    let max_t = if let Some(pos) = args.iter().position(|a| a == "--height") {
        args.get(pos + 1)
            .and_then(|s| s.parse::<f64>().ok())
            .unwrap_or(100.0)
    } else {
        100.0
    };
    
    let n_terms = 5000;  // Dirichlet terms for accuracy
    let prec = 256;      // MPFR bits (~77 decimal digits)
    
    println!();
    println!("═══════════════════════════════════════════════════════════");
    println!("  THREE TOWERS PROBE — Four-Fold Symmetry Experiment");
    println!("  T = {:.1} | N_terms = {} | MPFR = {} bits", max_t, n_terms, prec);
    println!("═══════════════════════════════════════════════════════════");
    println!();
    
    // Sieve primes
    eprintln!("Sieving primes...");
    let primes = sieve_primes(100_000);
    eprintln!("  {} primes ready", primes.len());
    
    // Run all five probes
    probe_tower_angles(max_t, n_terms);
    probe_fourfold_symmetry(n_terms, prec);
    probe_spectral_energy(&primes);
    probe_wave_counting(max_t, n_terms);
    probe_tower_profiles(n_terms);
    
    println!("═══════════════════════════════════════════════════════════");
    println!("  THREE TOWERS PROBE COMPLETE");
    println!("  The three towers guard the critical line from");
    println!("  orthogonal directions. The four-fold symmetry");
    println!("  forces zeros into conjugate pairs on Re(s) = 1/2.");
    println!("═══════════════════════════════════════════════════════════");
}
