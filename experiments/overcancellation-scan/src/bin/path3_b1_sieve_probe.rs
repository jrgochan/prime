#![allow(
    dead_code,
    unused_variables,
    unused_imports,
    unused_assignments,
    clippy::needless_range_loop,
    clippy::doc_lazy_continuation,
    non_snake_case,
    clippy::empty_line_after_doc_comments
)]
/// Path 3 Probe: B₁ Bilinear Decomposition + Large Sieve
///
/// From BilinearSieve.lean's PROVED theorem `bilinear_b1_decomposition`:
///   ∫₀¹ (Σ v_k {1/(kx)})² = ∫₀¹ (Σ v_k B₁(1/(kx)))²
///                           + σ · ∫₀¹ (Σ v_k B₁(1/(kx)))
///                           + (1/4) · σ²
///
/// where B₁(x) = {x} - 1/2 (sawtooth), σ = Σ v_k.
///
/// Since vᵀGv = ∫₀¹ f_N² dx, this decomposes the Gram form into:
///   - B₁ covariance integral (the skeleton's domain!)
///   - Cross term (linear in σ → 0 by Mertens)
///   - σ² term (→ 0 by Mertens²)
///
/// The B₁ covariance integral is where the Large Sieve applies:
///   ∫₀¹ (Σ v_k B₁(1/(kx)))² ≤ C · Σ v_k² · (k+1)
///
/// For Möbius weights: Σ μ(k)²·(1-lnk/lnN)²·(k+1) is a weighted Mertens sum.

fn mobius_sieve(n: usize) -> Vec<i32> {
    let mut mu = vec![0i32; n + 1];
    mu[1] = 1;
    let mut is_prime = vec![true; n + 1];
    let mut primes = Vec::new();
    for i in 2..=n {
        if is_prime[i] {
            primes.push(i);
            mu[i] = -1;
        }
        for &p in &primes {
            if i * p > n {
                break;
            }
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

/// Compute B₁(x) = {x} - 1/2
fn sawtooth(x: f64) -> f64 {
    x - x.floor() - 0.5
}

fn main() {
    let n_max = 5000; // Keep small for O(N²) numerical integration
    let mu = mobius_sieve(n_max);

    println!("═══════════════════════════════════════════════════════════════");
    println!("PATH 3 PROBE: B₁ Bilinear Decomposition + Large Sieve");
    println!("═══════════════════════════════════════════════════════════════");
    println!();

    // ═══ §1: Compute the decomposition for each N ═══
    println!("═══ §1: B₁ Decomposition of vᵀGv ═══");
    println!(
        "{:>6} {:>12} {:>12} {:>12} {:>12} {:>12}",
        "N", "vᵀGv", "∫(ΣvB₁)²", "σ·∫ΣvB₁", "σ²/4", "check"
    );
    println!("{}", "-".repeat(72));

    for &n in &[10, 20, 50, 100, 200, 500, 1000, 2000, 5000] {
        if n > n_max {
            break;
        }
        let ln_n = (n as f64).ln();

        // Build weights
        let mut weights = vec![0.0_f64; n]; // v[k] for k=1..n-1 (0-indexed: v[0]=v(1))
        let mut sigma = 0.0_f64;
        for k in 1..n {
            let mu_k = mu[k] as f64;
            if mu_k == 0.0 {
                continue;
            }
            let w = 1.0 - (k as f64).ln() / ln_n;
            weights[k] = -mu_k * w;
            sigma += weights[k];
        }

        // Numerical integration with N_pts quadrature points
        let n_pts = 50_000;
        let mut int_fract_sq = 0.0; // ∫₀¹ (Σ v_k {1/(kx)})² dx
        let mut int_saw_sq = 0.0; // ∫₀¹ (Σ v_k B₁(1/(kx)))² dx
        let mut int_saw = 0.0; // ∫₀¹ (Σ v_k B₁(1/(kx))) dx

        for i in 1..n_pts {
            let x = i as f64 / n_pts as f64;
            let mut sum_fract = 0.0;
            let mut sum_saw = 0.0;

            for k in 1..n {
                if weights[k] == 0.0 {
                    continue;
                }
                let u = 1.0 / (k as f64 * x);
                sum_fract += weights[k] * (u - u.floor());
                sum_saw += weights[k] * sawtooth(u);
            }

            int_fract_sq += sum_fract * sum_fract;
            int_saw_sq += sum_saw * sum_saw;
            int_saw += sum_saw;
        }
        int_fract_sq /= n_pts as f64;
        int_saw_sq /= n_pts as f64;
        int_saw /= n_pts as f64;

        // The decomposition: ∫f² = ∫(ΣvB₁)² + σ·∫(ΣvB₁) + σ²/4
        let rhs = int_saw_sq + sigma * int_saw + 0.25 * sigma * sigma;
        let check = (int_fract_sq - rhs).abs();

        println!(
            "{:>6} {:>12.6} {:>12.6} {:>12.6} {:>12.6} {:>12.2e}",
            n,
            int_fract_sq,
            int_saw_sq,
            sigma * int_saw,
            0.25 * sigma * sigma,
            check
        );
    }

    // ═══ §2: Large Sieve target — weighted ℓ² norm ═══
    println!();
    println!("═══ §2: Large Sieve RHS — Σ v_k² · (k+1) ═══");
    println!(
        "{:>6} {:>12} {:>12} {:>12} {:>12} {:>12}",
        "N", "∫(ΣvB₁)²", "Σv²(k+1)", "ratio C", "σ²", "d²_N≈"
    );
    println!("{}", "-".repeat(72));

    for &n in &[10, 20, 50, 100, 200, 500, 1000, 2000, 5000] {
        if n > n_max {
            break;
        }
        let ln_n = (n as f64).ln();

        let mut weights = vec![0.0_f64; n];
        let mut sigma = 0.0_f64;
        let mut weighted_l2 = 0.0_f64; // Σ v_k² · (k+1)
        let mut bv = 0.0_f64; // bᵀv

        for k in 1..n {
            let mu_k = mu[k] as f64;
            if mu_k == 0.0 {
                continue;
            }
            let w = 1.0 - (k as f64).ln() / ln_n;
            weights[k] = -mu_k * w;
            sigma += weights[k];
            weighted_l2 += weights[k] * weights[k] * (k as f64 + 1.0);
            // b_k = (ln(k) + 1 - γ) / k
            let euler_gamma = 0.5772156649015329;
            let b_k = ((k as f64).ln() + 1.0 - euler_gamma) / k as f64;
            bv += b_k * weights[k];
        }

        // Numerical integration for B₁ covariance
        let n_pts = 50_000;
        let mut int_saw_sq = 0.0;
        for i in 1..n_pts {
            let x = i as f64 / n_pts as f64;
            let mut sum_saw = 0.0;
            for k in 1..n {
                if weights[k] == 0.0 {
                    continue;
                }
                sum_saw += weights[k] * sawtooth(1.0 / (k as f64 * x));
            }
            int_saw_sq += sum_saw * sum_saw;
        }
        int_saw_sq /= n_pts as f64;

        let ratio = if weighted_l2 > 0.0 {
            int_saw_sq / weighted_l2
        } else {
            f64::NAN
        };

        // Approximate d²_N
        let vtgv_approx = int_saw_sq + sigma * 0.0 + 0.25 * sigma * sigma; // rough
        let d2_approx = 1.0 - 2.0 * bv + vtgv_approx;

        println!(
            "{:>6} {:>12.6} {:>12.4} {:>12.6} {:>12.4} {:>12.6}",
            n,
            int_saw_sq,
            weighted_l2,
            ratio,
            sigma * sigma,
            d2_approx
        );
    }

    // ═══ §3: Path 3 feasibility ═══
    println!();
    println!("═══ §3: Path 3 Feasibility ═══");
    println!();
    println!("For the Large Sieve path to work, we need:");
    println!("  1. ∫(ΣvB₁)² ≤ C · Σv²(k+1)  [Large Sieve, ratio C above]");
    println!("  2. Σv²(k+1) = O(1/logN)       [PNT weight decay]");
    println!();

    println!(
        "{:>6} {:>12} {:>12} {:>12}",
        "N", "Σv²(k+1)", "1/logN", "Σv²(k+1)·logN"
    );
    println!("{}", "-".repeat(48));

    for &n in &[50, 100, 200, 500, 1000, 2000, 5000] {
        if n > n_max {
            break;
        }
        let ln_n = (n as f64).ln();
        let mut weighted_l2 = 0.0_f64;
        for k in 1..n {
            let mu_k = mu[k] as f64;
            if mu_k == 0.0 {
                continue;
            }
            let w = 1.0 - (k as f64).ln() / ln_n;
            let v_k = -mu_k * w;
            weighted_l2 += v_k * v_k * (k as f64 + 1.0);
        }
        let normalized = weighted_l2 * ln_n;
        println!(
            "{:>6} {:>12.4} {:>12.6} {:>12.4}",
            n,
            weighted_l2,
            1.0 / ln_n,
            normalized
        );
    }

    println!();
    println!("If Σv²(k+1)·logN stabilizes → const, then Σv²(k+1) = O(1/logN) ✓");
    println!("═══════════════════════════════════════════════════════════════");
}
