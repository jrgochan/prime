//! ═══════════════════════════════════════════════════════════════════════════
//!  MIRROR MODE — Reconstruct primes from zeta zeros
//!
//!  "The zeros ARE the primes, seen through a mirror."
//!
//!  Uses the Riemann explicit formula:
//!    ψ(x) = x - Σ_ρ x^ρ/ρ - ln(2π) - ½ln(1 - x⁻²)
//!
//!  Each zero ρ = ½ + iγ contributes a correction wave. Adding more zeros
//!  makes the smooth approximation converge to the exact prime staircase.
//! ═══════════════════════════════════════════════════════════════════════════

use cathedral_utils::arith::primes_up_to;
use cathedral_utils::zeta_zeros;
use std::f64::consts::PI;

/// Chebyshev ψ(x) = Σ_{p^k ≤ x} ln(p) — the "prime step function" weighted by ln(p).
///
/// Exact computation by trial division (for ground truth).
fn chebyshev_psi_exact(x: f64) -> f64 {
    if x < 2.0 {
        return 0.0;
    }
    let limit = x as usize;
    let mut is_prime = vec![true; limit + 1];
    is_prime[0] = false;
    if limit >= 1 {
        is_prime[1] = false;
    }
    for i in 2..=(limit as f64).sqrt() as usize {
        if is_prime[i] {
            let mut j = i * i;
            while j <= limit {
                is_prime[j] = false;
                j += i;
            }
        }
    }

    let mut psi = 0.0;
    for p in 2..=limit {
        if is_prime[p] {
            let ln_p = (p as f64).ln();
            // Add ln(p) for each prime power p^k ≤ x
            let mut pk = p as f64;
            while pk <= x {
                psi += ln_p;
                pk *= p as f64;
            }
        }
    }
    psi
}

/// π(x) — exact prime counting function via sieve.
fn pi_exact(x: f64) -> usize {
    if x < 2.0 {
        return 0;
    }
    let limit = x as usize;
    let mut is_prime = vec![true; limit + 1];
    is_prime[0] = false;
    if limit >= 1 {
        is_prime[1] = false;
    }
    for i in 2..=(limit as f64).sqrt() as usize {
        if is_prime[i] {
            let mut j = i * i;
            while j <= limit {
                is_prime[j] = false;
                j += i;
            }
        }
    }
    is_prime.iter().filter(|&&b| b).count()
}

/// Chebyshev ψ(x) via the explicit formula with `num_zeros` zeros.
///
/// ψ(x) = x - Σ_{n=1}^{N} 2·Re(x^ρ_n / ρ_n) - ln(2π) - ½·ln(1 - x⁻²)
///
/// For each zero ρ = ½ + iγ, the pair (ρ, ρ̄) contributes:
///   2·Re(x^(½+iγ) / (½+iγ))
///   = 2·√x · (½·cos(γ·ln(x)) + γ·sin(γ·ln(x))) / (¼ + γ²)
fn chebyshev_psi_from_zeros(x: f64, num_zeros: usize) -> f64 {
    if x < 2.0 {
        return 0.0;
    }

    let zeros = zeta_zeros::known_zeros(num_zeros);
    let ln_x = x.ln();
    let sqrt_x = x.sqrt();

    // Main term
    let mut psi = x;

    // Zero contributions: -Σ 2·Re(x^ρ/ρ)
    for &gamma in zeros.iter() {
        let phase: f64 = gamma * ln_x;
        let cos_phase = phase.cos();
        let sin_phase = phase.sin();

        // x^(½+iγ) / (½+iγ) = √x · e^(iγ·ln(x)) / (½+iγ)
        // Re part: √x · (½·cos(γlnx) + γ·sin(γlnx)) / (¼+γ²)
        let denom = 0.25 + gamma * gamma;
        let contribution = sqrt_x * (0.5 * cos_phase + gamma * sin_phase) / denom;
        psi -= 2.0 * contribution;
    }

    // Constant: -ln(2π)
    psi -= (2.0 * PI).ln();

    // Trivial zeros: -½·ln(1 - x⁻²)
    if x > 1.0 {
        psi -= 0.5 * (1.0 - 1.0 / (x * x)).ln();
    }

    psi
}

/// The Möbius function μ(n).
///
/// μ(1) = 1
/// μ(n) = (-1)^k if n = p₁·p₂·...·pₖ (product of k distinct primes)
/// μ(n) = 0 if n has a squared prime factor
fn moebius(n: usize) -> i32 {
    if n == 1 {
        return 1;
    }
    let mut m = n;
    let mut k = 0; // number of distinct prime factors
    let mut p = 2;
    while p * p <= m {
        if m.is_multiple_of(p) {
            m /= p;
            if m.is_multiple_of(p) {
                return 0; // squared prime factor
            }
            k += 1;
        }
        p += 1;
    }
    if m > 1 {
        k += 1;
    }
    if k % 2 == 0 {
        1
    } else {
        -1
    }
}

/// Chebyshev θ(x) from zeros via full Möbius inversion:
///   θ(x) = Σ_{k=1}^{⌊log₂ x⌋} μ(k) · ψ(x^{1/k})
///
/// This removes prime power contributions from ψ, giving
/// θ(x) = Σ_{p ≤ x} ln(p) — pure prime counting weight.
fn chebyshev_theta_from_zeros(x: f64, num_zeros: usize) -> f64 {
    if x < 2.0 {
        return 0.0;
    }

    let k_max = (x.ln() / 2.0_f64.ln()) as usize; // ⌊log₂ x⌋
    let mut theta = 0.0;

    for k in 1..=k_max {
        let mu = moebius(k);
        if mu == 0 {
            continue;
        }

        let x_k = x.powf(1.0 / k as f64);
        if x_k < 2.0 {
            break;
        }

        let psi_k = chebyshev_psi_from_zeros(x_k, num_zeros);
        theta += mu as f64 * psi_k;
    }

    theta
}

/// Approximate π(x) from the explicit formula using full Möbius inversion.
///
/// 1. Compute θ(x) = Σ_k μ(k) · ψ(x^{1/k})  (full Möbius inversion)
/// 2. Compute π(x) = θ(x)/ln(x) + ∫₂ˣ θ(t)/(t·ln²(t)) dt
///
/// The integral correction accounts for the fact that θ(x)/ln(x)
/// underestimates π(x) because ln(p) varies across primes.
fn pi_from_zeros(x: f64, num_zeros: usize) -> f64 {
    if x < 2.0 {
        return 0.0;
    }

    let theta_x = chebyshev_theta_from_zeros(x, num_zeros);
    let ln_x = x.ln();

    // Leading term
    let mut pi = theta_x / ln_x;

    // Integration-by-parts correction: ∫₂ˣ θ(t)/(t·ln²(t)) dt
    // Use trapezoidal rule with adaptive spacing
    let n_steps = 200;
    let ln2 = 2.0_f64.ln();
    let dx = (ln_x - ln2) / n_steps as f64;

    for i in 0..n_steps {
        let ln_t0 = ln2 + i as f64 * dx;
        let ln_t1 = ln_t0 + dx;
        let t0 = ln_t0.exp();
        let t1 = ln_t1.exp();

        let theta_t0 = chebyshev_theta_from_zeros(t0, num_zeros);
        let theta_t1 = chebyshev_theta_from_zeros(t1, num_zeros);

        // ∫ θ(t)/(t·ln²(t)) dt ≈ trapezoidal in ln-space
        let f0 = theta_t0 / (ln_t0 * ln_t0);
        let f1 = theta_t1 / (ln_t1 * ln_t1);
        pi += 0.5 * (f1 + f0) * dx;
    }

    pi
}

/// Logarithmic integral li(x) = ∫₂ˣ dt/ln(t)
fn li(x: f64) -> f64 {
    if x <= 2.0 {
        return 0.0;
    }
    // Numerical integration via trapezoidal rule
    let n = 10000;
    let dx = (x - 2.0) / n as f64;
    let mut sum = 0.0;
    for i in 0..n {
        let t0 = 2.0 + i as f64 * dx;
        let t1 = t0 + dx;
        sum += dx * 0.5 * (1.0 / t0.ln() + 1.0 / t1.ln());
    }
    sum
}

pub fn run(x_max: f64) {
    println!("🪞 MIRROR MODE — Reconstructing Primes from Zeta Zeros");
    println!("   \"The zeros ARE the primes, seen through a mirror.\"");
    println!();

    let actual_primes = primes_up_to(x_max as usize);
    let pi_true = actual_primes.len();

    println!("   Range: [2, {}]", x_max as usize);
    println!("   Actual primes: {}", pi_true);
    println!();

    // ═══ §1: Convergence of π(x) as we add zeros ═══
    println!("═══ §1. THE STAIRCASE EMERGES ══════════════════════════════════");
    println!(
        "    π({}) from the explicit formula with increasing zeros:",
        x_max as usize
    );
    println!();
    println!(
        "    {:>10}  {:>12}  {:>12}  {:>10}  {:>10}",
        "# Zeros", "π(x) approx", "π(x) exact", "Error", "Error %"
    );
    println!(
        "    {:>10}  {:>12}  {:>12}  {:>10}  {:>10}",
        "──────────", "────────────", "────────────", "──────────", "──────────"
    );

    let zero_counts = [1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000, 10000];

    for &nz in &zero_counts {
        let available = zeta_zeros::known_zeros(nz).len();
        if available == 0 {
            continue;
        }

        let pi_approx = pi_from_zeros(x_max, nz);
        let error = pi_approx - pi_true as f64;
        let error_pct = error / pi_true as f64 * 100.0;
        let bar = if error_pct.abs() < 1.0 {
            "⭐⭐⭐"
        } else if error_pct.abs() < 5.0 {
            "⭐⭐"
        } else if error_pct.abs() < 20.0 {
            "⭐"
        } else {
            ""
        };
        println!(
            "    {:>10}  {:>12.2}  {:>12}  {:>+10.2}  {:>+8.2}%  {}",
            nz, pi_approx, pi_true, error, error_pct, bar
        );
    }

    println!();
    println!(
        "    li({}) = {:.2} (classical estimate)",
        x_max as usize,
        li(x_max)
    );
    println!();

    // ═══ §2: The mirror at specific x values ═══
    let test_values: Vec<f64> = vec![10.0, 25.0, 50.0, 100.0, 200.0, 500.0, 1000.0];
    let test_values: Vec<f64> = test_values.into_iter().filter(|&v| v <= x_max).collect();

    if !test_values.is_empty() {
        println!("═══ §2. THE MIRROR AT EACH x ═══════════════════════════════════");
        println!("    π(x) from 10,000 zeros vs reality:");
        println!();
        println!(
            "    {:>8}  {:>10}  {:>10}  {:>10}  {:>10}  {:>10}",
            "x", "π exact", "π (zeros)", "li(x)", "Δ zeros", "Δ li(x)"
        );
        println!(
            "    {:>8}  {:>10}  {:>10}  {:>10}  {:>10}  {:>10}",
            "────────", "──────────", "──────────", "──────────", "──────────", "──────────"
        );

        for &x in &test_values {
            let exact = pi_exact(x);
            let from_z = pi_from_zeros(x, 10_000);
            let li_x = li(x);
            println!(
                "    {:>8}  {:>10}  {:>10.1}  {:>10.1}  {:>+10.1}  {:>+10.1}",
                x as usize,
                exact,
                from_z,
                li_x,
                from_z - exact as f64,
                li_x - exact as f64
            );
        }
        println!();
    }

    // ═══ §3: Prime detection — peaks of ψ'(x) ═══
    println!("═══ §3. DETECTING INDIVIDUAL PRIMES FROM ZEROS ════════════════");
    println!("    Scanning ψ(x) from 10,000 zeros for sharp jumps (= primes):");
    println!();

    let scan_limit = x_max.min(200.0);
    let dx = 0.1;
    let nz = 10_000;

    let mut detected_primes: Vec<(f64, f64)> = Vec::new();
    let mut x = 2.0;
    let mut psi_prev = chebyshev_psi_from_zeros(x - dx, nz);

    while x <= scan_limit {
        let psi_curr = chebyshev_psi_from_zeros(x, nz);
        let dpsi = psi_curr - psi_prev;

        // A prime p causes a jump of ≈ ln(p) in ψ(x)
        // Look for jumps > 0.3 (smallest prime ln(2) ≈ 0.693)
        if dpsi > 0.3 {
            // Check if this is near a local maximum of the derivative
            let psi_next = chebyshev_psi_from_zeros(x + dx, nz);
            let dpsi_next = psi_next - psi_curr;
            if dpsi > dpsi_next {
                detected_primes.push((x, dpsi));
            }
        }

        psi_prev = psi_curr;
        x += dx;
    }

    // Match detected peaks against actual primes
    let actual_small = primes_up_to(scan_limit as usize);
    let mut hits = 0;
    let mut false_pos = 0;

    println!(
        "    {:>6}  {:>10}  {:>10}  {:>10}  {:>8}",
        "#", "Detected", "Nearest p", "Jump Δψ", "Match?"
    );
    println!(
        "    {:>6}  {:>10}  {:>10}  {:>10}  {:>8}",
        "──────", "──────────", "──────────", "──────────", "────────"
    );

    let display_limit = 30.min(detected_primes.len());
    for (i, &(x_det, jump)) in detected_primes.iter().take(display_limit).enumerate() {
        let nearest = actual_small
            .iter()
            .min_by_key(|&&p| ((p as f64 - x_det) * 10.0).abs() as usize)
            .copied()
            .unwrap_or(0);

        let dist = (x_det - nearest as f64).abs();
        let matched = dist < 1.0;
        if matched {
            hits += 1;
        } else {
            false_pos += 1;
        }

        let marker = if matched { "✅" } else { "❌" };
        println!(
            "    {:>6}  {:>10.1}  {:>10}  {:>10.3}  {:>8}",
            i + 1,
            x_det,
            nearest,
            jump,
            marker
        );
    }

    if detected_primes.len() > display_limit {
        // Count remaining matches
        for &(x_det, _) in detected_primes.iter().skip(display_limit) {
            let nearest = actual_small
                .iter()
                .min_by_key(|&&p| ((p as f64 - x_det) * 10.0).abs() as usize)
                .copied()
                .unwrap_or(0);
            let dist = (x_det - nearest as f64).abs();
            if dist < 1.0 {
                hits += 1;
            } else {
                false_pos += 1;
            }
        }
        println!(
            "    ... ({} more peaks detected)",
            detected_primes.len() - display_limit
        );
    }

    println!();
    println!(
        "    Detected: {} peaks | Matched to primes: {} | False positives: {}",
        detected_primes.len(),
        hits,
        false_pos
    );
    println!(
        "    Actual primes ≤ {}: {}",
        scan_limit as usize,
        actual_small.len()
    );
    println!(
        "    Detection rate: {:.1}%",
        hits as f64 / actual_small.len() as f64 * 100.0
    );
    println!();

    // ═══ §4: The choir / mirror duality ═══
    println!("═══ §4. THE DUALITY ═══════════════════════════════════════════");
    println!();
    println!("    PRIMES → ZEROS (the choir):");
    println!("      Each prime p oscillates at frequency log(p).");
    println!("      Where ALL primes cancel → a zeta zero.");
    println!("      10B primes in 3.19s → zeros at t = 10¹².");
    println!();
    println!("    ZEROS → PRIMES (the mirror):");
    println!("      Each zero γ contributes a correction wave cos(γ·ln(x))/√x.");
    println!("      The superposition of all waves → the prime staircase.");
    println!(
        "      10,000 zeros → π({}) ≈ {:.1} (true: {}).",
        x_max as usize,
        pi_from_zeros(x_max, 10_000),
        pi_true
    );
    println!();
    println!("    🌀 The Riemann Hypothesis says: both mirrors are perfect.");
    println!("       All zeros have Re(ρ) = ½ ⟺ the primes are as regular as possible.");
    println!("═══════════════════════════════════════════════════════════════════");
}
