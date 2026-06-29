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
/// Harmonic Projection Probe — Path 4 Closure Validator
///
/// Computes the quantities from OvercancellationAssembly.lean:
///   S(N) = Σ v(k)/(k+1)     (harmonic Möbius aggregate)
///   σ(N) = Σ v(k)            (total weight)
///   ‖v‖² = Σ v(k)²           (norm squared)
///   D(N) = diagonal bound    
///
/// where v(k) = -μ(k+1)·(1 - ln(k+1)/ln(N)) is the log-cutoff witness.
///
/// TARGET: Verify S(N)² > C - 2/3 ≈ 0.594 where C = ln(2π) - γ ≈ 1.261
///
/// If confirmed, Path 4 (gram_eventually_lt_one) closes unconditionally!

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

fn main() {
    let euler_gamma = 0.5772156649015329;
    let c_vasyunin = (2.0 * std::f64::consts::PI).ln() - euler_gamma;
    let threshold = c_vasyunin - 2.0 / 3.0;

    println!("═══════════════════════════════════════════════════════════════");
    println!("HARMONIC PROJECTION PROBE — Path 4 Closure Validator");
    println!("═══════════════════════════════════════════════════════════════");
    println!();
    println!("Constants:");
    println!("  C = ln(2π) - γ = {:.6}", c_vasyunin);
    println!("  Threshold = C - 2/3 = {:.6}", threshold);
    println!(
        "  Need: S² > {:.6} (i.e., |S| > {:.6})",
        threshold,
        threshold.sqrt()
    );
    println!();

    let n_max = 100_000;
    let mu = mobius_sieve(n_max);

    // ═══ §1: Core quantities for increasing N ═══
    println!("═══ §1: Log-Cutoff Witness Quantities ═══");
    println!(
        "{:>8} {:>12} {:>12} {:>12} {:>12} {:>12} {:>8}",
        "N", "S(N)", "S²", "σ(N)", "‖v‖²", "Gram≤", "S²>thr?"
    );
    println!("{}", "-".repeat(88));

    for &n in &[
        10, 20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000, 50000, 100000,
    ] {
        if n > n_max {
            break;
        }
        let ln_n = (n as f64).ln();

        // Log-cutoff witness: v(k) = -μ(k)·(1 - ln(k)/ln(N)) for k=1..N-1
        let mut s = 0.0_f64; // Σ v(k)/k
        let mut sigma = 0.0_f64; // Σ v(k)
        let mut norm_sq = 0.0_f64; // Σ v(k)²

        for k in 1..n {
            let mu_k = mu[k] as f64;
            if mu_k == 0.0 {
                continue;
            }
            let ln_k = (k as f64).ln();
            let weight = 1.0 - ln_k / ln_n;
            let v_k = -mu_k * weight;

            s += v_k / k as f64;
            sigma += v_k;
            norm_sq += v_k * v_k;
        }

        let s_sq = s * s;
        // Upper bound: (1/3 + C)·‖v‖² + C²σ²/4 - (S - Cσ/2)²
        let gram_upper = (1.0 / 3.0 + c_vasyunin) * norm_sq
            + c_vasyunin * c_vasyunin * sigma * sigma / 4.0
            - (s - c_vasyunin * sigma / 2.0).powi(2);
        let passes = if s_sq > threshold {
            "✓ PASS"
        } else {
            "✗ FAIL"
        };

        println!(
            "{:>8} {:>12.6} {:>12.6} {:>12.6} {:>12.6} {:>12.6} {:>8}",
            n, s, s_sq, sigma, norm_sq, gram_upper, passes
        );
    }

    // ═══ §2: The overcancellation mechanism ═══
    println!();
    println!("═══ §2: Overcancellation Mechanism (σ → 0 from Mertens) ═══");
    println!(
        "{:>8} {:>12} {:>12} {:>12} {:>12} {:>12}",
        "N", "|σ|", "C²σ²/4", "-(S-Cσ/2)²", "offdiag", "diag_bound"
    );
    println!("{}", "-".repeat(72));

    for &n in &[100, 500, 1000, 5000, 10000, 50000, 100000] {
        if n > n_max {
            break;
        }
        let ln_n = (n as f64).ln();
        let mut s = 0.0;
        let mut sigma = 0.0;
        let mut norm_sq = 0.0;

        for k in 1..n {
            let mu_k = mu[k] as f64;
            if mu_k == 0.0 {
                continue;
            }
            let weight = 1.0 - (k as f64).ln() / ln_n;
            let v_k = -mu_k * weight;
            s += v_k / k as f64;
            sigma += v_k;
            norm_sq += v_k * v_k;
        }

        let c2s2_4 = c_vasyunin.powi(2) * sigma.powi(2) / 4.0;
        let brake = -(s - c_vasyunin * sigma / 2.0).powi(2);
        let offdiag = c2s2_4 + brake;
        let diag = (1.0 / 3.0 + c_vasyunin) * norm_sq;

        println!(
            "{:>8} {:>12.6} {:>12.6} {:>12.6} {:>12.6} {:>12.6}",
            n,
            sigma.abs(),
            c2s2_4,
            brake,
            offdiag,
            diag
        );
    }

    // ═══ §3: Is gram_eventually_lt_one satisfied? ═══
    println!();
    println!("═══ §3: gram_eventually_lt_one Check ═══");
    println!(
        "{:>8} {:>14} {:>14} {:>14} {:>8}",
        "N", "gram_upper", "gram_upper/1", "1+K/logN", "< 1 ?"
    );
    println!("{}", "-".repeat(66));

    for &n in &[100, 500, 1000, 5000, 10000, 50000, 100000] {
        if n > n_max {
            break;
        }
        let ln_n = (n as f64).ln();
        let mut s = 0.0;
        let mut sigma = 0.0;
        let mut norm_sq = 0.0;

        for k in 1..n {
            let mu_k = mu[k] as f64;
            if mu_k == 0.0 {
                continue;
            }
            let weight = 1.0 - (k as f64).ln() / ln_n;
            let v_k = -mu_k * weight;
            s += v_k / k as f64;
            sigma += v_k;
            norm_sq += v_k * v_k;
        }

        let gram_upper = (1.0 / 3.0 + c_vasyunin) * norm_sq
            + c_vasyunin.powi(2) * sigma.powi(2) / 4.0
            - (s - c_vasyunin * sigma / 2.0).powi(2);

        let lt_one = if gram_upper < 1.0 {
            "✓ YES"
        } else {
            "✗ NO"
        };
        let k_equiv = (gram_upper - 1.0) * ln_n; // Effective K in "1 + K/logN"

        println!(
            "{:>8} {:>14.6} {:>14.6} {:>14.6} {:>8}",
            n, gram_upper, gram_upper, k_equiv, lt_one
        );
    }

    // ═══ §4: S(N) convergence analysis ═══
    println!();
    println!("═══ §4: Harmonic Projection S(N) Convergence ═══");
    println!(
        "Tracking S(N) to see if it stabilizes above {:.4}",
        threshold.sqrt()
    );
    println!();

    let mut prev_s = 0.0;
    for &n in &[
        10, 20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000, 30000, 50000, 70000, 100000,
    ] {
        if n > n_max {
            break;
        }
        let ln_n = (n as f64).ln();
        let mut s = 0.0;
        for k in 1..n {
            let mu_k = mu[k] as f64;
            if mu_k == 0.0 {
                continue;
            }
            let weight = 1.0 - (k as f64).ln() / ln_n;
            let v_k = -mu_k * weight;
            s += v_k / k as f64;
        }
        let delta = s - prev_s;
        println!(
            "  N={:>6}: S = {:>+.8}, S² = {:.6}, Δ = {:>+.6}, {} threshold",
            n,
            s,
            s * s,
            delta,
            if s * s > threshold { "ABOVE" } else { "below" }
        );
        prev_s = s;
    }

    // ═══ §5: Verdict ═══
    println!();
    println!("═══════════════════════════════════════════════════════════════");
    println!("VERDICT:");
    println!();

    // Final check at largest N
    let n = n_max;
    let ln_n = (n as f64).ln();
    let mut s = 0.0;
    let mut sigma = 0.0;
    let mut norm_sq = 0.0;
    for k in 1..n {
        let mu_k = mu[k] as f64;
        if mu_k == 0.0 {
            continue;
        }
        let weight = 1.0 - (k as f64).ln() / ln_n;
        let v_k = -mu_k * weight;
        s += v_k / k as f64;
        sigma += v_k;
        norm_sq += v_k * v_k;
    }

    let gram_upper = (1.0 / 3.0 + c_vasyunin) * norm_sq + c_vasyunin.powi(2) * sigma.powi(2) / 4.0
        - (s - c_vasyunin * sigma / 2.0).powi(2);

    println!("  At N = {}:", n);
    println!("    S(N) = {:.8}", s);
    println!("    S²   = {:.6} (threshold: {:.6})", s * s, threshold);
    println!("    σ(N) = {:.8} (→ 0 by Mertens)", sigma);
    println!("    ‖v‖² = {:.6}", norm_sq);
    println!("    gram_upper = {:.6} (need < 1)", gram_upper);
    println!();

    if s * s > threshold && gram_upper < 1.0 {
        println!("  ✅ PATH 4 NUMERICALLY CONFIRMED!");
        println!("     S² > C-2/3 AND gram_upper < 1.");
        println!("     The overcancellation mechanism works.");
    } else if s * s > threshold {
        println!("  ⚠️  S² > threshold but gram_upper ≥ 1.");
        println!("     Need larger N or σ closer to 0.");
    } else {
        println!("  ❌ S² ≤ threshold. Harmonic projection is too weak.");
    }
    println!("═══════════════════════════════════════════════════════════════");
}
