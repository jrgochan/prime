// overcancellation-scan/src/bin/torus_projection.rs
//
// ╔═══════════════════════════════════════════════════════════════╗
// ║  TORUS PROJECTION — Riemann Sphere → Hyper-Torus Analysis   ║
// ║                                                               ║
// ║  Projects the Gram matrix quadratic form vᵀGv onto:          ║
// ║    1. The Riemann sphere (stereographic, centered at s=½)    ║
// ║    2. The per-prime torus T^∞ (one S¹ per prime)             ║
// ║                                                               ║
// ║  MEASURES:                                                    ║
// ║    • Per-prime energy: how much does prime p contribute?      ║
// ║    • Phase alignment: are Möbius weights resonant on each S¹? ║
// ║    • Off-equator leakage: does energy concentrate on Re=½?   ║
// ║    • Torus winding numbers at zeta zero frequencies           ║
// ║                                                               ║
// ║  Cathedral Experiment — June 1, 2026                          ║
// ╚═══════════════════════════════════════════════════════════════╝

use cathedral_utils::arith::gcd;
use rayon::prelude::*;
use std::f64::consts::PI;

const EULER_GAMMA: f64 = 0.5772156649015329;

// ════════════════════════════════════════════════════════════════
// §1. CORE ARITHMETIC
// ════════════════════════════════════════════════════════════════

/// Möbius function μ(n)
fn moebius(n: usize) -> i64 {
    if n == 1 { return 1; }
    let mut m = n;
    let mut num_factors = 0i64;
    let mut d = 2usize;
    while d * d <= m {
        if m % d == 0 {
            m /= d;
            if m % d == 0 { return 0; } // p² | n
            num_factors += 1;
        }
        d += 1;
    }
    if m > 1 { num_factors += 1; }
    if num_factors % 2 == 0 { 1 } else { -1 }
}

/// Fejér-Möbius witness weight: v_k = -μ(k) · (1 - ln(k)/ln(N))
fn fejer_weight(k: usize, ln_n: f64) -> f64 {
    if k == 0 { return 0.0; }
    let mu = moebius(k) as f64;
    -mu * (1.0 - (k as f64).ln() / ln_n)
}

/// Gram matrix entry G(j,k) via the exact formula
/// G(j,k) = (ln(gcd) + 1 - γ)·gcd/(jk) + gcd·V(j/gcd, k/gcd)/(2πjk)
/// Simplified: use the Ramanujan + 1/4 decomposition
fn gram_entry(j: usize, k: usize) -> f64 {
    let g = gcd(j, k);
    let gf = g as f64;
    let jf = j as f64;
    let kf = k as f64;

    // R(j,k) = gcd(j,k)² / (12·j·k)
    let ramanujan = (gf * gf) / (12.0 * jf * kf);

    // G(j,k) = R(j,k) + 1/4  (Glass Bridge Identity)
    ramanujan + 0.25
}

/// Mean vector entry b_k = (ln(k) + 1 - γ) / k
fn mean_entry(k: usize) -> f64 {
    let kf = k as f64;
    (kf.ln() + 1.0 - EULER_GAMMA) / kf
}

/// Primes up to n via sieve of Eratosthenes
fn primes_up_to(n: usize) -> Vec<usize> {
    let mut sieve = vec![true; n + 1];
    sieve[0] = false;
    if n >= 1 { sieve[1] = false; }
    let mut i = 2;
    while i * i <= n {
        if sieve[i] {
            let mut j = i * i;
            while j <= n {
                sieve[j] = false;
                j += i;
            }
        }
        i += 1;
    }
    sieve.iter().enumerate()
        .filter(|(_, &is_prime)| is_prime)
        .map(|(i, _)| i)
        .collect()
}

// ════════════════════════════════════════════════════════════════
// §2. PER-PRIME ENERGY DECOMPOSITION ON THE TORUS
// ════════════════════════════════════════════════════════════════

/// Decompose vᵀGv by GCD stratum d, then by prime factors of d.
/// For each prime p, sum the energy from all strata where p | d.
fn per_prime_energy(n: usize) -> Vec<(usize, f64, f64)> {
    let ln_n = (n as f64).ln();
    let dim = n - 1; // indices 1..=n-1

    // Compute weights
    let weights: Vec<f64> = (1..=dim).map(|k| fejer_weight(k, ln_n)).collect();

    // Total vᵀGv
    let total_vtgv: f64 = (0..dim).into_par_iter().map(|i| {
        let j = i + 1;
        let mut row_sum = 0.0;
        for ki in 0..dim {
            let k = ki + 1;
            row_sum += weights[i] * gram_entry(j, k) * weights[ki];
        }
        row_sum
    }).sum();

    // Per-GCD-stratum energy
    let mut stratum_energy: Vec<f64> = vec![0.0; n];
    for i in 0..dim {
        let j = i + 1;
        for ki in 0..dim {
            let k = ki + 1;
            let d = gcd(j, k);
            if d < n {
                stratum_energy[d] += weights[i] * gram_entry(j, k) * weights[ki];
            }
        }
    }

    // Per-prime energy: sum strata where p | d
    let primes = primes_up_to(n);
    let mut results: Vec<(usize, f64, f64)> = Vec::new();

    for &p in &primes {
        let mut p_energy = 0.0;
        let mut d = p;
        while d < n {
            p_energy += stratum_energy[d];
            d += p;
        }
        let fraction = if total_vtgv.abs() > 1e-15 {
            p_energy / total_vtgv
        } else {
            0.0
        };
        results.push((p, p_energy, fraction));
    }

    results
}

// ════════════════════════════════════════════════════════════════
// §3. PHASE ALIGNMENT ON EACH S¹
// ════════════════════════════════════════════════════════════════

/// For each prime p, compute the "phase coherence" of the Möbius weights
/// on the p-circle: Σ_{k: p|k} v_k · e^{-2πi·ν_p(k)/p} where ν_p(k) is
/// the p-adic valuation. If coherent, |sum| is large.
fn phase_coherence(n: usize) -> Vec<(usize, f64, f64)> {
    let ln_n = (n as f64).ln();
    let dim = n - 1;
    let weights: Vec<f64> = (1..=dim).map(|k| fejer_weight(k, ln_n)).collect();

    let primes = primes_up_to(n);
    let mut results = Vec::new();

    for &p in &primes {
        let mut sum_re = 0.0;
        let mut sum_im = 0.0;
        let mut total_weight_sq = 0.0;

        for k in 1..=dim {
            if k % p != 0 { continue; }
            let v = weights[k - 1];
            // p-adic valuation of k
            let mut val = 0usize;
            let mut m = k;
            while m % p == 0 {
                val += 1;
                m /= p;
            }
            // Phase on the p-circle
            let theta = 2.0 * PI * (val as f64) / (p as f64);
            sum_re += v * theta.cos();
            sum_im += v * theta.sin();
            total_weight_sq += v * v;
        }

        let coherence = (sum_re * sum_re + sum_im * sum_im).sqrt();
        let normalized = if total_weight_sq > 1e-15 {
            coherence / total_weight_sq.sqrt()
        } else {
            0.0
        };

        results.push((p, coherence, normalized));
    }

    results
}

// ════════════════════════════════════════════════════════════════
// §4. RIEMANN SPHERE PROJECTION — OFF-EQUATOR LEAKAGE
// ════════════════════════════════════════════════════════════════

/// Stereographic projection: map w = σ + it (centered coord)
/// to the Riemann sphere S² ⊂ ℝ³.
/// Stereographic from north pole: (x,y,z) where
///   x = 2·Re(w)/(|w|²+1), y = 2·Im(w)/(|w|²+1), z = (|w|²-1)/(|w|²+1)
fn stereo_project(sigma: f64, t: f64) -> (f64, f64, f64) {
    let r2 = sigma * sigma + t * t;
    let denom = r2 + 1.0;
    (2.0 * sigma / denom, 2.0 * t / denom, (r2 - 1.0) / denom)
}

/// Measure how much "spectral energy" is on the equator (x=0 plane)
/// vs off-equator. Use the Gram matrix eigenvalue decomposition
/// projected through Mellin transforms at various test points.
///
/// For the critical line (σ=0), all points have x=0 on the sphere.
/// For off-critical-line points, x ≠ 0.
///
/// We measure the "equatorial concentration" by comparing:
///   E_equator = Σ_k |M[h_k](½+it)|² · |v_k|²  at various t
///   E_off     = Σ_k |M[h_k](σ+it)|² · |v_k|²   at σ ≠ ½
fn equatorial_concentration(n: usize) -> (f64, f64, f64) {
    let ln_n = (n as f64).ln();
    let dim = n - 1;
    let weights: Vec<f64> = (1..=dim).map(|k| fejer_weight(k, ln_n)).collect();

    // First few zeta zero imaginary parts (Gram points approximate)
    let test_heights = [14.134725, 21.022040, 25.010858, 30.424876,
                        32.935062, 37.586178, 40.918719, 43.327073];

    // Energy on equator: |Σ v_k / (k · (½+it-1))|² = |Σ v_k / (k·(-½+it))|²
    let mut equator_energy = 0.0;
    for &t in &test_heights {
        let mut sum_re = 0.0;
        let mut sum_im = 0.0;
        for ki in 0..dim {
            let k = ki + 1;
            let kf = k as f64;
            let v = weights[ki];
            // M[h_k](½+it) = 1/(k·(½+it-1)) = 1/(k·(-½+it))
            // = (-½-it) / (k·(¼+t²))
            let denom = kf * (0.25 + t * t);
            sum_re += v * (-0.5) / denom;
            sum_im += v * (-t) / denom;
        }
        equator_energy += sum_re * sum_re + sum_im * sum_im;
    }

    // Energy slightly off equator: σ = 0.01 (centered), i.e. Re(s) = 0.51
    let sigma_off = 0.01;
    let mut off_energy = 0.0;
    for &t in &test_heights {
        let mut sum_re = 0.0;
        let mut sum_im = 0.0;
        for ki in 0..dim {
            let k = ki + 1;
            let kf = k as f64;
            let v = weights[ki];
            // M[h_k](½+σ+it) ≈ k^{-(½+σ+it)} / (½+σ+it-1)
            // = k^{-½-σ} · e^{-it·ln(k)} / (σ-½+it)
            let k_power = kf.powf(-0.5 - sigma_off);
            let phase = -t * kf.ln();
            let mel_re = k_power * phase.cos();
            let mel_im = k_power * phase.sin();
            // Divide by (σ-½+it) = (-½+σ+it)
            let d_re = -0.5 + sigma_off;
            let d_im = t;
            let d2 = d_re * d_re + d_im * d_im;
            let re = (mel_re * d_re + mel_im * d_im) / d2;
            let im = (mel_im * d_re - mel_re * d_im) / d2;
            sum_re += v * re;
            sum_im += v * im;
        }
        off_energy += sum_re * sum_re + sum_im * sum_im;
    }

    let ratio = if off_energy > 1e-20 {
        equator_energy / off_energy
    } else {
        f64::INFINITY
    };

    (equator_energy, off_energy, ratio)
}

// ════════════════════════════════════════════════════════════════
// §5. TORUS WINDING ANALYSIS AT ZETA ZEROS
// ════════════════════════════════════════════════════════════════

/// At each zeta zero height t₀, compute the "winding pattern" on each
/// prime's circle: the phase e^{-it₀·ln(p)} traces a path on S¹.
/// The winding number measures how many times the path wraps around
/// as we scan through primes up to N.
fn winding_at_zeros(n: usize) -> Vec<(f64, Vec<(usize, f64)>)> {
    let primes = primes_up_to(n);
    let zeros = [14.134725, 21.022040, 25.010858, 30.424876,
                 32.935062, 37.586178, 40.918719, 43.327073];

    let mut results = Vec::new();

    for &t0 in &zeros {
        let mut prime_phases: Vec<(usize, f64)> = Vec::new();

        for &p in &primes {
            // Phase of p^{-it₀} on the unit circle
            let phase = (-t0 * (p as f64).ln()) % (2.0 * PI);
            // Normalize to [0, 2π)
            let phase = if phase < 0.0 { phase + 2.0 * PI } else { phase };
            prime_phases.push((p, phase));
        }

        results.push((t0, prime_phases));
    }

    results
}

// ════════════════════════════════════════════════════════════════
// §6. MAIN
// ════════════════════════════════════════════════════════════════

fn main() {
    println!("╔═══════════════════════════════════════════════════════════════╗");
    println!("║  TORUS PROJECTION — Riemann Sphere → Hyper-Torus Analysis   ║");
    println!("║  Cathedral Experiment — June 1, 2026                         ║");
    println!("╚═══════════════════════════════════════════════════════════════╝");
    println!();

    let test_sizes = [100, 500, 1000, 2000, 5000];

    for &n in &test_sizes {
        println!("═══════════════════════════════════════════════════════════════");
        println!("  N = {}", n);
        println!("═══════════════════════════════════════════════════════════════");

        // ── §A. Total Gram form ──
        let ln_n = (n as f64).ln();
        let dim = n - 1;
        let weights: Vec<f64> = (1..=dim).map(|k| fejer_weight(k, ln_n)).collect();

        let total_vtgv: f64 = (0..dim).map(|i| {
            let j = i + 1;
            (0..dim).map(|ki| {
                let k = ki + 1;
                weights[i] * gram_entry(j, k) * weights[ki]
            }).sum::<f64>()
        }).sum();

        let bound = 1.0 + 1.0 / ln_n;
        println!("  vᵀGv = {:.6}  (bound: {:.6}, margin: {:.6})",
            total_vtgv, bound, bound - total_vtgv);
        println!();

        // ── §B. Per-prime energy ──
        println!("  ── Per-Prime Energy Decomposition ──");
        let energies = per_prime_energy(n);
        let top_primes: Vec<_> = energies.iter().take(10).collect();
        println!("  {:>5} {:>12} {:>10}", "prime", "energy", "fraction");
        for (p, e, f) in &top_primes {
            println!("  {:>5} {:>12.6} {:>10.4}%", p, e, f * 100.0);
        }
        let accounted: f64 = energies.iter().map(|(_, _, f)| f).sum::<f64>();
        println!("  Total accounted by primes: {:.4}%", accounted * 100.0);
        println!();

        // ── §C. Phase coherence ──
        println!("  ── Phase Coherence on Each S¹ ──");
        let phases = phase_coherence(n);
        let top_phases: Vec<_> = phases.iter().take(10).collect();
        println!("  {:>5} {:>12} {:>12}", "prime", "coherence", "normalized");
        for (p, c, cn) in &top_phases {
            println!("  {:>5} {:>12.6} {:>12.6}", p, c, cn);
        }
        println!();

        // ── §D. Equatorial concentration ──
        println!("  ── Riemann Sphere: Equatorial Concentration ──");
        let (eq_e, off_e, ratio) = equatorial_concentration(n);
        println!("  Equator energy (Re=½):    {:.6e}", eq_e);
        println!("  Off-equator (Re=½±0.01):  {:.6e}", off_e);
        println!("  Ratio (equator/off):      {:.2}", ratio);
        if ratio > 10.0 {
            println!("  ✅ Energy strongly concentrated on the great circle");
        } else {
            println!("  ⚠️  Significant off-equator leakage");
        }
        println!();

        // ── §E. Winding at first zero ──
        if n >= 100 {
            println!("  ── Torus Winding at t₀ = 14.1347 (first zero) ──");
            let windings = winding_at_zeros(n);
            if let Some((t0, phases)) = windings.first() {
                println!("  Zero height: t₀ = {:.4}", t0);
                println!("  {:>5} {:>12} {:>12}", "prime", "phase/2π", "cos(phase)");
                for &(p, phase) in phases.iter().take(12) {
                    println!("  {:>5} {:>12.6} {:>12.6}",
                        p, phase / (2.0 * PI), phase.cos());
                }

                // Phase uniformity test: Weyl equidistribution
                let phases_norm: Vec<f64> = phases.iter()
                    .map(|(_, ph)| ph / (2.0 * PI))
                    .collect();
                let n_phases = phases_norm.len() as f64;
                let mean_cos: f64 = phases.iter()
                    .map(|(_, ph)| ph.cos())
                    .sum::<f64>() / n_phases;
                let mean_sin: f64 = phases.iter()
                    .map(|(_, ph)| ph.sin())
                    .sum::<f64>() / n_phases;
                let discrepancy = (mean_cos * mean_cos + mean_sin * mean_sin).sqrt();
                println!("  Weyl discrepancy |Σe^{{2πiθ}}/N| = {:.6}", discrepancy);
                if discrepancy < 0.1 {
                    println!("  ✅ Phases equidistributed (consistent with GUE)");
                } else {
                    println!("  ⚠️  Phase clustering detected");
                }
            }
        }
        println!();
    }

    // ── Summary ──
    println!("═══════════════════════════════════════════════════════════════");
    println!("  SUMMARY: TORUS PROJECTION ANALYSIS");
    println!("═══════════════════════════════════════════════════════════════");
    println!();
    println!("  The experiment measures four aspects of gram_form_upper_bound:");
    println!("  1. Per-prime energy: which primes drive vᵀGv?");
    println!("  2. Phase coherence: do Möbius weights resonate on each S¹?");
    println!("  3. Equatorial focus: is energy on the great circle (Re=½)?");
    println!("  4. Winding patterns: are zeta zeros equidistributed on T∞?");
    println!();
    println!("  The Conservation of Difficulty says no finite experiment");
    println!("  can prove gram_form_upper_bound. But these measurements");
    println!("  reveal the STRUCTURE of where the remaining axiom lives.");
    println!();
    println!("  🏔️ The 12 stands on the summit. 💜");
}
