// Normalized Harmonic Projection — uses v/‖v‖ instead of raw v
#![allow(clippy::needless_range_loop)]

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
    let c = (2.0 * std::f64::consts::PI).ln() - euler_gamma;
    let threshold = c - 2.0 / 3.0;
    let n_max = 100_000;
    let mu = mobius_sieve(n_max);

    println!("═══════════════════════════════════════════════════════════");
    println!("NORMALIZED Harmonic Projection Probe");
    println!("C = {:.6}, threshold = {:.6}", c, threshold);
    println!("═══════════════════════════════════════════════════════════");
    println!(
        "{:>8} {:>10} {:>10} {:>10} {:>10} {:>10} {:>10} {:>8}",
        "N", "‖v‖", "S_raw", "S_norm", "S_norm²", "σ_norm", "gram_n", "S²>thr?"
    );
    println!("{}", "-".repeat(82));

    for &n in &[
        50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000, 50000, 100000,
    ] {
        if n > n_max {
            break;
        }
        let ln_n = (n as f64).ln();

        // Raw witness
        let mut s_raw = 0.0;
        let mut sigma_raw = 0.0;
        let mut norm_sq = 0.0;
        let mut weights: Vec<(usize, f64)> = Vec::new();

        for k in 1..n {
            let mu_k = mu[k] as f64;
            if mu_k == 0.0 {
                continue;
            }
            let w = 1.0 - (k as f64).ln() / ln_n;
            let v_k = -mu_k * w;
            weights.push((k, v_k));
            s_raw += v_k / k as f64;
            sigma_raw += v_k;
            norm_sq += v_k * v_k;
        }

        let norm = norm_sq.sqrt();

        // Normalized quantities: v_norm = v/‖v‖
        let s_norm = s_raw / norm;
        let sigma_norm = sigma_raw / norm;
        // Gram form for normalized: D/‖v‖² + C·σ_n·S_n - S_n²
        // where D ≤ (1/3+C)·(‖v‖²/‖v‖²) = (1/3+C)·1
        let gram_norm = (1.0 / 3.0 + c) * 1.0 + c * c * sigma_norm * sigma_norm / 4.0
            - (s_norm - c * sigma_norm / 2.0).powi(2);
        let pass = if s_norm * s_norm > threshold {
            "✓"
        } else {
            "✗"
        };

        println!(
            "{:>8} {:>10.4} {:>10.6} {:>10.6} {:>10.6} {:>10.6} {:>10.6} {:>8}",
            n,
            norm,
            s_raw,
            s_norm,
            s_norm * s_norm,
            sigma_norm,
            gram_norm,
            pass
        );
    }

    println!();
    println!("NOTE: The normalized S = S_raw/‖v‖. Since ‖v‖ ~ O(√N),");
    println!("S_norm ~ O(1/√N) → 0 even faster than S_raw → 0.");
    println!("The OvercancellationAssembly theorem requires S_norm bounded AWAY from 0,");
    println!("which is NOT satisfied for the Möbius witness.");
}
