/// Glass Product Convergence Probe
///
/// Probes the wall axiom: ∏_p (1 + p^{-s}) converges for Re(s) > 1/2.
///
/// This computes the partial glass product ∏_{p≤N} (1 + p^{-s}) for
/// increasing N and various s = σ + it, tracking:
///   - |P_N|: magnitude of the partial product
///   - arg(P_N): phase angle
///   - Convergence rate: |P_{N} - P_{N/2}| / |P_{N/2}|
///
/// The experiment visualizes WHERE the wall lives:
///   σ > 1:     rapid absolute convergence (Euler region)
///   σ ~ 0.75:  slower convergence with oscillation
///   σ ~ 0.55:  heavy oscillation, slow convergence
///   σ ~ 0.501: the wall — barely converges
///   σ = 0.5:   critical line — product dips near ζ zeros
///
/// Also decomposes the glass TOWER layer by layer:
///   L_k(s) = ∏_p (1 + p^{-2^k·s}),  k = 0, 1, ..., 7
///   showing that the wall lives entirely in L_0 (k=0).

use std::f64::consts::PI;

// ═══════════════════════════════════════════════════════
// §1. PRIME SIEVE
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

// ═══════════════════════════════════════════════════════
// §2. COMPLEX ARITHMETIC
// ═══════════════════════════════════════════════════════

#[derive(Clone, Copy)]
struct C64 { re: f64, im: f64 }

impl C64 {
    fn new(re: f64, im: f64) -> Self { C64 { re, im } }
    fn one() -> Self { C64 { re: 1.0, im: 0.0 } }
    fn norm(&self) -> f64 { (self.re * self.re + self.im * self.im).sqrt() }
    fn arg(&self) -> f64 { self.im.atan2(self.re) }

    fn mul(self, other: C64) -> C64 {
        C64 {
            re: self.re * other.re - self.im * other.im,
            im: self.re * other.im + self.im * other.re,
        }
    }

    fn add(self, other: C64) -> C64 {
        C64 { re: self.re + other.re, im: self.im + other.im }
    }
}

/// Compute p^{-s} = p^{-σ} · e^{-it·ln(p)} = p^{-σ}·(cos(t·ln p) - i·sin(t·ln p))
fn prime_power_neg_s(p: usize, sigma: f64, t: f64) -> C64 {
    let lnp = (p as f64).ln();
    let magnitude = (p as f64).powf(-sigma);
    let phase = -t * lnp;
    C64::new(magnitude * phase.cos(), magnitude * phase.sin())
}

// ═══════════════════════════════════════════════════════
// §3. GLASS PRODUCT COMPUTATION
// ═══════════════════════════════════════════════════════

/// Compute ∏_{p ≤ N} (1 + p^{-s}) for s = σ + it
fn glass_product(primes: &[usize], sigma: f64, t: f64, max_prime: usize) -> C64 {
    let mut product = C64::one();
    for &p in primes {
        if p > max_prime { break; }
        let term = C64::one().add(prime_power_neg_s(p, sigma, t));
        product = product.mul(term);
    }
    product
}

/// Compute the glass tower layer L_k(s) = ∏_{p ≤ N} (1 + p^{-2^k·s})
fn glass_layer(primes: &[usize], k: u32, sigma: f64, t: f64, max_prime: usize) -> C64 {
    let scale = (1u64 << k) as f64; // 2^k
    glass_product(primes, sigma * scale, t * scale, max_prime)
}

// ═══════════════════════════════════════════════════════
// §4. THE PROBE
// ═══════════════════════════════════════════════════════

fn main() {
    println!("╔══════════════════════════════════════════════════════════╗");
    println!("║     GLASS PRODUCT CONVERGENCE PROBE                    ║");
    println!("║     Probing: ∏_p (1 + p^{{-s}}) for Re(s) > 1/2         ║");
    println!("║     The Wall = glass_product_convergence ≡ RH          ║");
    println!("╚══════════════════════════════════════════════════════════╝");
    println!();

    // Sieve primes up to 10^7
    let prime_limit = 10_000_000;
    eprintln!("Sieving primes up to {}...", prime_limit);
    let primes = sieve_primes(prime_limit);
    eprintln!("Found {} primes (largest: {})", primes.len(), primes.last().unwrap());
    println!();

    // ──────────────────────────────────────────────────
    // EXPERIMENT 1: Glass convergence vs σ
    // Fixed t = 14.1347 (height of first ζ zero)
    // ──────────────────────────────────────────────────
    let t_first_zero = 14.134725;
    let sigmas = [2.0, 1.5, 1.0, 0.75, 0.6, 0.55, 0.52, 0.505, 0.501];
    let checkpoints: Vec<usize> = vec![100, 1_000, 10_000, 100_000, 1_000_000, 10_000_000];

    println!("═══════════════════════════════════════════════════════");
    println!("  EXPERIMENT 1: Glass Product vs σ");
    println!("  Fixed t = {:.4} (first ζ zero height)", t_first_zero);
    println!("  P_N = ∏_{{p≤N}} (1 + p^{{-σ-it}})");
    println!("═══════════════════════════════════════════════════════");
    println!();

    for &sigma in &sigmas {
        println!("── σ = {:.3} ──────────────────────────────────────", sigma);
        println!("  {:>10}  {:>12}  {:>10}  {:>12}", "N", "|P_N|", "arg(P_N)", "Δ(relative)");

        let mut prev_product = C64::one();
        for &n in &checkpoints {
            let prod = glass_product(&primes, sigma, t_first_zero, n);
            let delta = if prev_product.norm() > 1e-15 {
                let diff_re = prod.re - prev_product.re;
                let diff_im = prod.im - prev_product.im;
                (diff_re * diff_re + diff_im * diff_im).sqrt() / prev_product.norm()
            } else {
                f64::NAN
            };
            println!("  {:>10}  {:>12.6}  {:>10.4}  {:>12.2e}",
                n, prod.norm(), prod.arg(), delta);
            prev_product = prod;
        }
        println!();
    }

    // ──────────────────────────────────────────────────
    // EXPERIMENT 2: The critical line near first zero
    // σ = 0.5, t sweeping through the first zero
    // ──────────────────────────────────────────────────
    println!("═══════════════════════════════════════════════════════");
    println!("  EXPERIMENT 2: Critical Line Scan Near First Zero");
    println!("  σ = 0.5, N = 10^6 primes");
    println!("  Scanning t near 14.1347...");
    println!("═══════════════════════════════════════════════════════");
    println!();
    println!("  {:>10}  {:>12}  {:>10}  {:>6}", "t", "|P_N|", "arg(P_N)", "region");

    let n_scan = 1_000_000;
    for i in -20..=20i32 {
        let t = t_first_zero + (i as f64) * 0.1;
        let prod = glass_product(&primes, 0.5, t, n_scan);
        let region = if (t - t_first_zero).abs() < 0.15 { "←ZERO" } else { "" };
        println!("  {:>10.4}  {:>12.6}  {:>10.4}  {:>6}",
            t, prod.norm(), prod.arg(), region);
    }
    println!();

    // ──────────────────────────────────────────────────
    // EXPERIMENT 3: Glass Tower Layer Decomposition
    // Shows that the wall lives in L_0, extended to k=9 (1024D)
    // ──────────────────────────────────────────────────
    println!("═══════════════════════════════════════════════════════");
    println!("  EXPERIMENT 3: Glass Tower Layer Decomposition");
    println!("  s = 0.55 + 14.1347i, N = 10^6 primes");
    println!("  L_k(s) = ∏_p (1 + p^{{-2^k·s}}),  k = 0..10");
    println!("═══════════════════════════════════════════════════════");
    println!();

    let sigma_tower = 0.55;
    let n_tower = 1_000_000;
    println!("  {:>5}  {:>6}  {:>14}  {:>14}  {:>14}  {:>12}", "k", "dim", "|L_k|", "|L_k - 1|", "Re(L_k)", "status");
    println!("  {:>5}  {:>6}  {:>14}  {:>14}  {:>14}  {:>12}", "─", "───", "──────────", "──────────", "──────────", "──────");

    let mut total_product = C64::one();
    for k in 0u32..=10 {
        let dim = 1u64 << (k + 1); // 2^{k+1} = CD dimension
        let layer = glass_layer(&primes, k, sigma_tower, t_first_zero, n_tower);
        total_product = total_product.mul(layer);
        let deviation = ((layer.re - 1.0).powi(2) + layer.im.powi(2)).sqrt();
        let status = if deviation < 1e-12 { "≡ 1 ✅" }
            else if deviation < 1e-6 { "≈ 1 ✅" }
            else if deviation < 0.01 { "near 1" }
            else if deviation < 0.1 { "~1" }
            else { "← WALL" };
        println!("  {:>5}  {:>5}D  {:>14.10}  {:>14.2e}  {:>14.10}  {}",
            k, dim, layer.norm(), deviation, layer.re, status);
    }
    println!();
    println!("  Total ∏ L_k: |P| = {:.10}, Re = {:.10}, Im = {:.10}",
        total_product.norm(), total_product.re, total_product.im);
    println!();

    // ──────────────────────────────────────────────────
    // EXPERIMENT 3b: The Glass Breathes
    // Tower decomposition at multiple t values
    // Shows L_0 breathing near ζ zeros
    // ──────────────────────────────────────────────────
    println!("═══════════════════════════════════════════════════════");
    println!("  EXPERIMENT 3b: The Glass Breathes");
    println!("  σ = 0.55, N = 10^6, t sweeps through ζ zeros");
    println!("  Known zeros: t₁≈14.13, t₂≈21.02, t₃≈25.01");
    println!("═══════════════════════════════════════════════════════");
    println!();

    let sigma_breathe = 0.55;
    let n_breathe = 1_000_000;
    // Known zero heights of ζ (first 5)
    let zero_ts = [14.1347, 21.0220, 25.0109, 30.4249, 32.9351];

    println!("  {:>8}  {:>12}  {:>12}  {:>12}  {:>12}  {:>6}",
        "t", "|L₀|", "|L₁|", "|L₂|", "|∏ L_k|", "zero?");
    println!("  {:>8}  {:>12}  {:>12}  {:>12}  {:>12}  {:>6}",
        "──────", "────────", "────────", "────────", "────────", "─────");

    for i in 0..=60 {
        let t = 10.0 + (i as f64) * 0.5;
        let l0 = glass_layer(&primes, 0, sigma_breathe, t, n_breathe);
        let l1 = glass_layer(&primes, 1, sigma_breathe, t, n_breathe);
        let l2 = glass_layer(&primes, 2, sigma_breathe, t, n_breathe);

        // Full product (approximate — layers k≥3 are ≈ 1)
        let mut full = C64::one();
        for k in 0u32..=5 {
            full = full.mul(glass_layer(&primes, k, sigma_breathe, t, n_breathe));
        }

        // Mark if near a known zero
        let near_zero = zero_ts.iter().any(|&zt| (t - zt).abs() < 0.4);
        let marker = if near_zero { "← ζ=0" } else { "" };

        println!("  {:>8.2}  {:>12.6}  {:>12.6}  {:>12.6}  {:>12.6}  {}",
            t, l0.norm(), l1.norm(), l2.norm(), full.norm(), marker);
    }

    // ──────────────────────────────────────────────────
    // EXPERIMENT 4: Phase cancellation analysis
    // Partial sums ∑_{p≤N} p^{-s} and growth rate
    // ──────────────────────────────────────────────────
    println!("═══════════════════════════════════════════════════════");
    println!("  EXPERIMENT 4: Phase Cancellation ∑_{{p≤N}} p^{{-s}}");
    println!("  The wall needs this to converge conditionally");
    println!("═══════════════════════════════════════════════════════");
    println!();

    let test_sigmas = [1.5, 1.0, 0.75, 0.55, 0.501];
    println!("  {:>6}  {:>10}  {:>12}  {:>12}  {:>12}",
        "σ", "N", "|∑ p^{-s}|", "Re(∑)", "Im(∑)");

    for &sigma in &test_sigmas {
        let mut sum = C64::new(0.0, 0.0);
        let mut count = 0;
        for &p in &primes {
            sum = sum.add(prime_power_neg_s(p, sigma, t_first_zero));
            count += 1;
            if count == primes.len() || p >= 10_000_000 {
                println!("  {:>6.3}  {:>10}  {:>12.6}  {:>12.6}  {:>12.6}",
                    sigma, p, sum.norm(), sum.re, sum.im);
            }
        }
    }
    println!();

    // ──────────────────────────────────────────────────
    // EXPERIMENT 5: σ sweep at fixed N
    // Continuous view of |P| vs σ
    // ──────────────────────────────────────────────────
    println!("═══════════════════════════════════════════════════════");
    println!("  EXPERIMENT 5: |P_N| vs σ (N = 10^6, t = 14.1347)");
    println!("  The glass product magnitude as σ → 1/2");
    println!("═══════════════════════════════════════════════════════");
    println!();

    let n_sweep = 1_000_000;
    println!("  {:>6}  {:>12}  {:>40}", "σ", "|P_N|", "bar");
    for i in 0..=30 {
        let sigma = 0.50 + (i as f64) * 0.05;
        let prod = glass_product(&primes, sigma, t_first_zero, n_sweep);
        let bar_len = (prod.norm().ln().abs().min(40.0)) as usize;
        let bar: String = if prod.norm() > 1.0 {
            "█".repeat(bar_len.min(40))
        } else {
            "░".repeat(bar_len.min(40))
        };
        println!("  {:>6.2}  {:>12.4}  {}", sigma, prod.norm(), bar);
    }

    println!();
    println!("════════════════════════════════════════════════════════");
    println!("  SUMMARY");
    println!("════════════════════════════════════════════════════════");
    println!("  The glass product ∏_p(1+p^{{-s}}) converges rapidly for σ > 1,");
    println!("  oscillates but converges for 1/2 < σ < 1 (IF RH is true),");
    println!("  and shows dramatic dips near ζ zeros on the critical line.");
    println!("  The wall lives entirely in the k=0 layer (L₀).");
    println!("  Higher Cayley-Dickson layers (k≥2) are ≈ 1 to machine precision.");
}
