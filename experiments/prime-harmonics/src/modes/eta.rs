//! # 🌊 Eta Mode — Complete Winding Cancellation Analysis
//!
//! Computes the Dirichlet eta partial sums for EVERY integer up to N:
//!
//!   η(s, N) = Σ_{n=1}^{N} (-1)^{n+1} · n^{-s}
//!
//! At a zeta zero s = 1/2 + iγ, η(s) = 0 (converges at rate ~1/√N under RH).
//!
//! For each integer n, we compute:
//! - Möbius value μ(n)
//! - Arithmetic type (prime, squarefree composite, squared)
//! - Phase angle γ·log(n) mod 2π
//! - Contribution to η partial sum
//! - Running |η| magnitude
//!
//! Also tracks inter-prime cancellation: how composites between
//! consecutive primes restore balance.

use std::f64::consts::PI;
use std::io::Write;
use std::time::Instant;

/// First 30 nontrivial zeta zeros (imaginary parts).
const ZEROS: [f64; 30] = [
    14.134725141734693, 21.022039638771555, 25.010857580145688,
    30.424876125859513, 32.935061587739189, 37.586178158825671,
    40.918719012147495, 43.327073280914999, 48.005150881167159,
    49.773832477672302, 52.970321477714460, 56.446247697063394,
    59.347044002602353, 60.831778524609809, 65.112544048081607,
    67.079810529494173, 69.546401711696542, 72.067157674481907,
    75.704690699083933, 77.144840068874805, 79.337375020249367,
    82.910380854086030, 84.735492980517050, 87.425274613125196,
    88.809111207634465, 92.491899270558484, 94.651344040519838,
    95.870634228245309, 98.831194218193692, 101.31785100573139,
];

/// Sieve Möbius function for all n ≤ limit.
/// Returns a Vec where moebius[n] = μ(n).
fn sieve_moebius(limit: usize) -> Vec<i8> {
    let mut mu = vec![0i8; limit + 1];
    let mut min_factor = vec![0u32; limit + 1];

    // Smallest prime factor sieve
    for i in 2..=limit {
        if min_factor[i] == 0 {
            // i is prime
            min_factor[i] = i as u32;
            if i * i <= limit {
                let mut j = i * i;
                while j <= limit {
                    if min_factor[j] == 0 {
                        min_factor[j] = i as u32;
                    }
                    j += i;
                }
            }
        }
    }

    mu[1] = 1;
    for n in 2..=limit {
        let p = min_factor[n] as usize;
        let m = n / p;
        if m % p == 0 {
            // p^2 | n, so μ(n) = 0
            mu[n] = 0;
        } else {
            // μ(n) = -μ(n/p)
            mu[n] = -mu[m];
        }
    }
    mu
}

/// Sieve primes up to limit.
fn sieve_primes(limit: usize) -> Vec<bool> {
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
    is_prime
}

/// Number of distinct prime factors.
fn omega(mut n: usize, is_prime: &[bool]) -> u32 {
    let mut count = 0;
    let mut d = 2;
    while d * d <= n {
        if n % d == 0 {
            count += 1;
            while n % d == 0 { n /= d; }
        }
        d += 1;
    }
    if n > 1 { count += 1; }
    count
}

/// Arithmetic type label.
fn arith_type(n: usize, mu: i8, is_prime: &[bool]) -> &'static str {
    if n == 1 { return "unit"; }
    if is_prime[n] { return "prime"; }
    if mu == 0 { return "sq"; }
    if mu == 1 { return "μ=+1"; }
    "μ=-1"
}

/// Statistics for the eta analysis.
struct EtaStats {
    /// Running sums for multiple zeros
    eta_re: Vec<f64>,
    eta_im: Vec<f64>,
}

pub fn run(n_max: usize, num_zeros: usize, verbose: bool) {
    let gamma_count = num_zeros.min(ZEROS.len());
    let gammas = &ZEROS[..gamma_count];

    eprintln!("🌊 Eta Mode — Complete Winding Cancellation");
    eprintln!("  N_max: {}", n_max);
    eprintln!("  Zeros: {} (γ₁ = {:.6})", gamma_count, gammas[0]);
    eprintln!();

    let start = Instant::now();

    // Sieve
    let mu = sieve_moebius(n_max);
    let is_prime = sieve_primes(n_max);
    let sieve_time = start.elapsed();
    eprintln!("  Sieved μ(n) and primes in {:.2?}", sieve_time);

    let calc_start = Instant::now();

    // ═══════════════════════════════════════════
    // §1. ETA PARTIAL SUMS (the convergent series)
    // ═══════════════════════════════════════════
    println!("═══════════════════════════════════════════════════════════════");
    println!("§1. DIRICHLET ETA PARTIAL SUMS: η(1/2+iγ, N)");
    println!("    η(s) = Σ (-1)^{{n+1}} n^{{-s}} = (1-2^{{1-s}})·ζ(s)");
    println!("    At a zero: η → 0 at rate ~ 1/√N (if RH is true)");
    println!("═══════════════════════════════════════════════════════════════");
    println!();

    // Track eta for each zero
    let mut eta_re = vec![0.0f64; gamma_count];
    let mut eta_im = vec![0.0f64; gamma_count];

    // Milestone tracking
    let milestones: Vec<usize> = {
        let mut m = vec![10, 50, 100, 500];
        let mut power = 1000;
        while power <= n_max {
            m.push(power);
            power *= 10;
        }
        if *m.last().unwrap_or(&0) != n_max {
            m.push(n_max);
        }
        m.retain(|&x| x <= n_max);
        m
    };

    // Header
    print!("{:>12}", "N");
    for i in 0..gamma_count.min(5) {
        print!("{:>14}", format!("|η| at γ_{}", i + 1));
    }
    println!("{:>14}", "|η|·√N at γ₁");
    println!("{}", "-".repeat(12 + 14 * (gamma_count.min(5) + 1)));

    for n in 1..=n_max {
        let sign: f64 = if n % 2 == 1 { 1.0 } else { -1.0 };
        let amp = sign / (n as f64).sqrt();
        let ln_n = (n as f64).ln();

        for (zi, &gamma) in gammas.iter().enumerate() {
            let phase = gamma * ln_n;
            eta_re[zi] += amp * phase.cos();
            eta_im[zi] += amp * (-phase.sin());
        }

        if milestones.contains(&n) {
            print!("{:>12}", n);
            for zi in 0..gamma_count.min(5) {
                let mag = (eta_re[zi] * eta_re[zi] + eta_im[zi] * eta_im[zi]).sqrt();
                print!("{:>14.8}", mag);
            }
            let mag1 = (eta_re[0] * eta_re[0] + eta_im[0] * eta_im[0]).sqrt();
            let scaled = mag1 * (n as f64).sqrt();
            println!("{:>14.6}", scaled);
        }
    }

    println!();

    // ═══════════════════════════════════════════
    // §2. MÖBIUS-WEIGHTED SUM (the 1/ζ series)
    // ═══════════════════════════════════════════
    println!("═══════════════════════════════════════════════════════════════");
    println!("§2. MÖBIUS SUM: S(N,γ) = Σ_{{n≤N}} μ(n)·n^{{-1/2-iγ}}");
    println!("    This → 1/ζ(1/2+iγ) which DIVERGES at zeros");
    println!("    Rate of divergence indicates the zero's \"strength\"");
    println!("═══════════════════════════════════════════════════════════════");
    println!();

    let mut mob_re = vec![0.0f64; gamma_count];
    let mut mob_im = vec![0.0f64; gamma_count];

    print!("{:>12}", "N");
    for i in 0..gamma_count.min(5) {
        print!("{:>14}", format!("|S| at γ_{}", i + 1));
    }
    println!("{:>14}", "|S|/√(logN)");
    println!("{}", "-".repeat(12 + 14 * (gamma_count.min(5) + 1)));

    for n in 1..=n_max {
        if mu[n] == 0 { continue; }
        let amp = (mu[n] as f64) / (n as f64).sqrt();
        let ln_n = (n as f64).ln();

        for (zi, &gamma) in gammas.iter().enumerate() {
            let phase = gamma * ln_n;
            mob_re[zi] += amp * phase.cos();
            mob_im[zi] += amp * (-phase.sin());
        }

        if milestones.contains(&n) {
            print!("{:>12}", n);
            for zi in 0..gamma_count.min(5) {
                let mag = (mob_re[zi] * mob_re[zi] + mob_im[zi] * mob_im[zi]).sqrt();
                print!("{:>14.8}", mag);
            }
            let mag1 = (mob_re[0] * mob_re[0] + mob_im[0] * mob_im[0]).sqrt();
            let scaled = mag1 / (n as f64).ln().sqrt();
            println!("{:>14.6}", scaled);
        }
    }

    println!();

    // ═══════════════════════════════════════════
    // §3. INTER-PRIME CANCELLATION (at γ₁)
    // ═══════════════════════════════════════════
    println!("═══════════════════════════════════════════════════════════════");
    println!("§3. INTER-PRIME CANCELLATION AT γ₁ = {:.6}", gammas[0]);
    println!("    Between each prime pair, how do composites cancel?");
    println!("═══════════════════════════════════════════════════════════════");
    println!();

    let gamma1 = gammas[0];
    let primes: Vec<usize> = (2..=n_max).filter(|&n| is_prime[n]).collect();

    // η-weighted inter-prime analysis
    let mut eta1_re = 0.0f64;
    let mut eta1_im = 0.0f64;

    print!("{:>18} {:>10} {:>12} {:>12} {:>12} {:>12}", 
           "Interval", "#comp", "|η| before", "|η| after", "Δ|η|", "Δ|η|/Δ|η|_p");
    println!();
    println!("{}", "-".repeat(80));

    let max_intervals = 50;
    let mut interval_count = 0;
    let mut last_prime_idx = 0;

    // Add n=1 contribution
    eta1_re += 1.0; // (-1)^2 · 1^{-1/2} · cos(0) = 1

    for pi in 0..primes.len().min(n_max) {
        let p = primes[pi];
        let p_next = if pi + 1 < primes.len() { primes[pi + 1] } else { break };

        if p_next > n_max { break; }

        // Add all numbers from last position to p-1 (composites before prime)
        // ... actually, let's just track as we go

        let mag_before = (eta1_re * eta1_re + eta1_im * eta1_im).sqrt();

        // Add numbers from prev_end..=p_next-1
        let start_n = if pi == 0 { 2 } else { primes[pi - 1] + 1 };

        // Process current prime p and composites up to p_next - 1
        for n in start_n..p_next {
            let sign: f64 = if n % 2 == 1 { 1.0 } else { -1.0 };
            let amp = sign / (n as f64).sqrt();
            let ln_n = (n as f64).ln();
            let phase = gamma1 * ln_n;
            eta1_re += amp * phase.cos();
            eta1_im += amp * (-phase.sin());
        }

        let mag_after = (eta1_re * eta1_re + eta1_im * eta1_im).sqrt();
        let delta = mag_after - mag_before;

        let n_composites = if pi == 0 { p_next - 2 } else { p_next - primes[pi - 1] - 1 };

        // Only print first max_intervals and then milestones
        if interval_count < max_intervals || p > n_max / 2 {
            if interval_count < max_intervals {
                println!("  [{:>6}, {:>6}) {:>10} {:>12.6} {:>12.6} {:>+12.6} {:>12.4}",
                         if pi == 0 { 2 } else { primes[pi-1] + 1 }, p_next,
                         n_composites, mag_before, mag_after, delta,
                         if mag_before > 0.001 { delta / mag_before } else { 0.0 });
            }
        }
        interval_count += 1;
    }

    println!();

    // ═══════════════════════════════════════════
    // §4. RATE ANALYSIS: |η| · √N
    // ═══════════════════════════════════════════
    println!("═══════════════════════════════════════════════════════════════");
    println!("§4. CONVERGENCE RATE: |η(1/2+iγ₁, N)| · √N");
    println!("    Under RH: should be O(1) (bounded)");
    println!("    Without RH: could grow as N^{{σ-1/2}} for some σ > 1/2");
    println!("═══════════════════════════════════════════════════════════════");
    println!();

    // Recompute for fine-grained tracking
    let mut eta_re_fine = 0.0f64;
    let mut eta_im_fine = 0.0f64;
    let mut max_scaled = 0.0f64;
    let mut max_scaled_at = 0usize;

    let log_milestones: Vec<usize> = (1..=((n_max as f64).log10() as usize + 1))
        .map(|k| 10usize.pow(k as u32))
        .filter(|&x| x <= n_max)
        .collect();

    println!("{:>12} {:>14} {:>14} {:>14} {:>14}",
             "N", "|η|", "|η|·√N", "max|η|·√N", "max at N");
    println!("{}", "-".repeat(70));

    for n in 1..=n_max {
        let sign: f64 = if n % 2 == 1 { 1.0 } else { -1.0 };
        let amp = sign / (n as f64).sqrt();
        let ln_n = (n as f64).ln();
        let phase = gamma1 * ln_n;
        eta_re_fine += amp * phase.cos();
        eta_im_fine += amp * (-phase.sin());

        let mag = (eta_re_fine * eta_re_fine + eta_im_fine * eta_im_fine).sqrt();
        let scaled = mag * (n as f64).sqrt();
        if scaled > max_scaled {
            max_scaled = scaled;
            max_scaled_at = n;
        }

        if log_milestones.contains(&n) || n == n_max {
            println!("{:>12} {:>14.10} {:>14.6} {:>14.6} {:>14}",
                     n, mag, scaled, max_scaled, max_scaled_at);
        }
    }

    let calc_time = calc_start.elapsed();
    let total_time = start.elapsed();

    println!();
    println!("═══════════════════════════════════════════════════════════════");
    println!("§5. SUMMARY");
    println!("═══════════════════════════════════════════════════════════════");
    println!();
    println!("  N_max:        {:>12}", n_max);
    println!("  Sieve time:   {:>12.2?}", sieve_time);
    println!("  Compute time: {:>12.2?}", calc_time);
    println!("  Total time:   {:>12.2?}", total_time);
    println!();

    let final_mag = (eta_re[0] * eta_re[0] + eta_im[0] * eta_im[0]).sqrt();
    let final_scaled = final_mag * (n_max as f64).sqrt();
    println!("  |η(1/2+iγ₁, {})| = {:.10}", n_max, final_mag);
    println!("  |η| · √N          = {:.6}", final_scaled);
    println!("  max |η| · √N      = {:.6}  (at N = {})", max_scaled, max_scaled_at);
    println!();

    if final_scaled < 10.0 {
        println!("  ✅ |η|·√N is bounded — CONSISTENT WITH RH");
    } else {
        println!("  ⚠️  |η|·√N = {:.2} — check if this stabilizes at larger N", final_scaled);
    }
    println!();
}
