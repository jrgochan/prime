/// Convergence Test: Does Log/Flat → 0.25 as N → ∞?
///
/// Runs the spectral analyzer at multiple N values and measures
/// the average Log/Flat energy ratio at the first 10 Riemann zeros.
/// The Theorist predicts convergence to (1/2)² = 0.25.

use std::time::Instant;

const RIEMANN_ZEROS: &[f64] = &[
    14.134725, 21.022040, 25.010858, 30.424876, 32.935062,
    37.586178, 40.918719, 43.327073, 48.005151, 49.773832,
];

fn mobius_sieve(n: usize) -> Vec<i8> {
    let mut mu = vec![0i8; n + 1];
    mu[1] = 1;
    let mut is_prime = vec![true; n + 1];
    let mut primes = Vec::new();
    for i in 2..=n {
        if is_prime[i] {
            primes.push(i);
            mu[i] = -1;
        }
        for &p in &primes {
            if i * p > n { break; }
            is_prime[i * p] = false;
            if i % p == 0 {
                mu[i * p] = 0;
                break;
            } else {
                mu[i * p] = -mu[i];
            }
        }
    }
    mu
}

/// Compute |D_N(1/2 + it)|² for a single t value
fn energy_at(coeffs: &[f64], ln_k: &[f64], t: f64) -> f64 {
    let mut re = 0.0f64;
    let mut im = 0.0f64;
    for i in 0..coeffs.len() {
        let phase = -t * ln_k[i];
        let (s, c) = phase.sin_cos();
        re += coeffs[i] * c;
        im += coeffs[i] * s;
    }
    re * re + im * im
}

/// Find peak energy near a zero (search ±0.5 at resolution 0.001)
fn peak_near(coeffs: &[f64], ln_k: &[f64], zero: f64) -> f64 {
    let mut best = 0.0f64;
    let steps = 1000;
    for i in 0..=steps {
        let t = (zero - 0.5) + i as f64 / steps as f64;
        let e = energy_at(coeffs, ln_k, t);
        if e > best { best = e; }
    }
    best
}

fn main() {
    let n_values: Vec<usize> = vec![
        1_000, 2_000, 5_000, 10_000, 20_000,
        50_000, 100_000, 200_000, 500_000, 1_000_000,
    ];

    println!("{}", "=".repeat(85));
    println!("CONVERGENCE TEST: Does Log/Flat energy ratio → 0.25 as N → ∞?");
    println!("Theorist prediction: ratio = (L¹ norm of taper)² = (1/2)² = 0.25");
    println!("{}", "=".repeat(85));

    println!("\n{:>10} {:>8} {:>12} {:>12} {:>10} {:>10} {:>10}",
        "N", "ln(N)", "Log peak", "Flat peak", "Ratio", "|Δ| from", "1/ln(N)");
    println!("{:>10} {:>8} {:>12} {:>12} {:>10} {:>10} {:>10}",
        "", "", "(avg)", "(avg)", "(avg)", "0.25", "");
    println!("{}", "-".repeat(85));

    for &n in &n_values {
        let t0 = Instant::now();

        let mu = mobius_sieve(n);
        let ln_n = (n as f64).ln();

        let mut ln_k = vec![0.0f64; n];
        let mut k_half = vec![0.0f64; n];
        for i in 0..n {
            let k = (i + 1) as f64;
            ln_k[i] = k.ln();
            k_half[i] = k.powf(-0.5);
        }

        // Log cutoff coefficients
        let log_coeffs: Vec<f64> = (0..n).map(|i| {
            let m = mu[i + 1] as f64;
            -m * (1.0 - ln_k[i] / ln_n) * k_half[i]
        }).collect();

        // Flat Möbius coefficients
        let flat_coeffs: Vec<f64> = (0..n).map(|i| {
            let m = mu[i + 1] as f64;
            -m * k_half[i]
        }).collect();

        // Measure peak energy at each zero
        let mut ratios = Vec::new();
        let mut log_sum = 0.0;
        let mut flat_sum = 0.0;

        for &z in RIEMANN_ZEROS {
            let log_e = peak_near(&log_coeffs, &ln_k, z);
            let flat_e = peak_near(&flat_coeffs, &ln_k, z);
            log_sum += log_e;
            flat_sum += flat_e;
            if flat_e > 0.0 {
                ratios.push(log_e / flat_e);
            }
        }

        let avg_log = log_sum / RIEMANN_ZEROS.len() as f64;
        let avg_flat = flat_sum / RIEMANN_ZEROS.len() as f64;
        let avg_ratio = ratios.iter().sum::<f64>() / ratios.len() as f64;
        let delta = (avg_ratio - 0.25).abs();
        let inv_ln_n = 1.0 / ln_n;
        let elapsed = t0.elapsed();

        println!("{:>10} {:>8.3} {:>12.2} {:>12.2} {:>10.5} {:>10.5} {:>10.5}  ({:.1?})",
            n, ln_n, avg_log, avg_flat, avg_ratio, delta, inv_ln_n, elapsed);
    }

    println!("\n{}", "=".repeat(85));
    println!("If Δ decreases proportionally to 1/ln(N), the Theorist's prediction holds.");
    println!("Expected: ratio → 0.25000 as N → ∞");
    println!("{}", "=".repeat(85));
}
