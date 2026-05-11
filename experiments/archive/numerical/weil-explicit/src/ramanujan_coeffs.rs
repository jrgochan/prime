#![allow(unused, dead_code, non_snake_case)]
use rayon::prelude::*;

// ══════════════════════════════════════════════════════════
// RAMANUJAN COEFFICIENT ANALYSIS
//
// Goal: Expand g[k] = ⟨f_k, f_M⟩ in Ramanujan sums:
//   g[k] = c₀ + Σ_{q|M} α̂_q · c_q(k)
//
// Test: Does |α̂_q| ∝ 1/q?
// If YES → proof of drop bound follows from
//   |g⊺v_min| = |Σ α̂_q · S_q| where S_q = Σ_k c_q(k)v_min[k]
// ══════════════════════════════════════════════════════════

fn frac_part(x: f64) -> f64 { x - x.floor() }

fn gram_entry(j: usize, k: usize, n_pts: usize) -> f64 {
    let jf = j as f64;
    let kf = k as f64;
    let dx = 1.0 / n_pts as f64;
    let mut sum = 0.0f64;
    for i in 0..n_pts {
        let x = (i as f64 + 0.5) * dx;
        sum += frac_part(jf / x) * frac_part(kf / x);
    }
    sum * dx
}

fn gcd(a: usize, b: usize) -> usize {
    let (mut a, mut b) = (a, b);
    while b != 0 { let t = b; b = a % b; a = t; }
    a
}

fn mobius(n: usize) -> i32 {
    if n == 1 { return 1; }
    let mut m = n;
    let mut num_factors = 0;
    let mut d = 2;
    while d * d <= m {
        if m % d == 0 {
            num_factors += 1;
            m /= d;
            if m % d == 0 { return 0; } // squared factor
        }
        d += 1;
    }
    if m > 1 { num_factors += 1; }
    if num_factors % 2 == 0 { 1 } else { -1 }
}

fn euler_phi(n: usize) -> usize {
    let mut result = n;
    let mut m = n;
    let mut d = 2;
    while d * d <= m {
        if m % d == 0 {
            while m % d == 0 { m /= d; }
            result -= result / d;
        }
        d += 1;
    }
    if m > 1 { result -= result / m; }
    result
}

// Ramanujan sum c_q(k) = Σ_{d|gcd(k,q)} μ(q/d) · d
fn ramanujan_sum(q: usize, k: usize) -> f64 {
    let g = gcd(k, q);
    let mut sum = 0.0f64;
    let mut d = 1;
    while d * d <= g {
        if g % d == 0 {
            sum += mobius(q / d) as f64 * d as f64;
            if d != g / d {
                let d2 = g / d;
                sum += mobius(q / d2) as f64 * d2 as f64;
            }
        }
        d += 1;
    }
    sum
}

fn divisors(n: usize) -> Vec<usize> {
    let mut divs = Vec::new();
    let mut d = 1;
    while d * d <= n {
        if n % d == 0 { divs.push(d); if d != n / d { divs.push(n / d); } }
        d += 1;
    }
    divs.sort();
    divs
}

fn num_divisors(n: usize) -> usize { divisors(n).len() }

fn main() {
    println!("═══════════════════════════════════════════════════════════════");
    println!("  RAMANUJAN-FOURIER COEFFICIENT ANALYSIS");
    println!("  Expanding g[k] = ⟨f_k, f_M⟩ in Ramanujan sums c_q(k)");
    println!("═══════════════════════════════════════════════════════════════");

    let n_pts = 500_000;
    let max_k = 500;
    let start = std::time::Instant::now();

    // Test several HC numbers M
    let test_ms: Vec<usize> = vec![60, 120, 180, 240, 360, 420, 480, 720, 840];

    for &m in &test_ms {
        println!("\n\n═══ M = {} (d(M) = {}) ═══\n", m, num_divisors(m));

        // Step 1: Compute cross-correlation g[k] = ∫₀¹ {k/x}{M/x} dx
        let g: Vec<f64> = (2..=max_k).into_par_iter()
            .map(|k| gram_entry(k, m, n_pts))
            .collect();
        let n = g.len(); // max_k - 1

        // Step 2: Coprime baseline
        let coprime_g: Vec<f64> = (0..n).filter(|&i| gcd(i + 2, m) == 1)
            .map(|i| g[i]).collect();
        let c0 = coprime_g.iter().sum::<f64>() / coprime_g.len() as f64;
        println!("  Coprime baseline c₀ = {:.8}", c0);

        // Step 3: Divisors of M (these are the q values)
        let divs = divisors(m);
        println!("  Divisors of {}: {:?}", m, &divs);

        // Step 4: Compute Ramanujan coefficients via orthogonality
        // α̂_q = (1/N) Σ_{k=2}^{N+1} (g[k] - c₀) · c_q(k) / φ(q)
        // (using c_q orthogonality: Σ_k c_q(k)c_r(k) ≈ N·φ(q)·δ_{qr})

        println!("\n  {:>6} {:>6} {:>14} {:>14} {:>10} {:>10}",
            "q", "φ(q)", "α̂_q", "q·|α̂_q|", "μ(q)", "d(q)");

        let mut coeffs: Vec<(usize, f64)> = Vec::new();

        for &q in &divs {
            if q == 1 { continue; } // skip q=1 (that's c₀)

            let phi_q = euler_phi(q);
            let mu_q = mobius(q);

            // Compute Σ_k (g[k]-c₀) · c_q(k)
            let mut sum_gc = 0.0f64;
            for i in 0..n {
                let k = i + 2;
                let cqk = ramanujan_sum(q, k);
                sum_gc += (g[i] - c0) * cqk;
            }

            let alpha_q = sum_gc / (n as f64 * phi_q as f64);
            coeffs.push((q, alpha_q));

            println!("  {:6} {:6} {:14.8} {:14.8} {:10} {:10}",
                q, phi_q, alpha_q, (q as f64 * alpha_q.abs()),
                mu_q, num_divisors(q));
        }

        // Step 5: Verify reconstruction
        println!("\n  Reconstruction verification (selected k):");
        println!("  {:>5} {:>12} {:>12} {:>12} {:>10}",
            "k", "g[k]-c₀", "Σα̂c_q(k)", "error", "gcd(k,M)");

        let mut total_err_sq = 0.0f64;
        let mut total_sig_sq = 0.0f64;

        for &k in &[2, 3, 5, 6, 10, 12, 15, 20, 30, 60,
                     m/6, m/5, m/4, m/3, m/2, m-1] {
            if k < 2 || k > max_k { continue; }
            let actual = g[k - 2] - c0;
            let reconstructed: f64 = coeffs.iter()
                .map(|&(q, aq)| aq * ramanujan_sum(q, k))
                .sum();
            let err = actual - reconstructed;
            total_err_sq += err * err;
            total_sig_sq += actual * actual;

            println!("  {:5} {:12.8} {:12.8} {:12.2e} {:10}",
                k, actual, reconstructed, err, gcd(k, m));
        }

        let rel_err = if total_sig_sq > 0.0 { (total_err_sq / total_sig_sq).sqrt() } else { 0.0 };
        println!("  Relative reconstruction error: {:.6}", rel_err);

        // Step 6: Fit α̂_q ∝ 1/q^β
        println!("\n  Scaling analysis:");
        let fit_data: Vec<(f64, f64)> = coeffs.iter()
            .filter(|(q, a)| *q >= 4 && a.abs() > 1e-12)
            .map(|(q, a)| (*q as f64, a.abs()))
            .collect();

        if fit_data.len() >= 3 {
            let nf = fit_data.len() as f64;
            let slnx: f64 = fit_data.iter().map(|(q, _)| q.ln()).sum();
            let slny: f64 = fit_data.iter().map(|(_, a)| a.ln()).sum();
            let slnx2: f64 = fit_data.iter().map(|(q, _)| q.ln().powi(2)).sum();
            let slnxy: f64 = fit_data.iter().map(|(q, a)| q.ln() * a.ln()).sum();
            let beta = -(nf * slnxy - slnx * slny) / (nf * slnx2 - slnx * slnx);
            let ln_a = (slny + beta * slnx) / nf;

            println!("  Fit: |α̂_q| ≈ {:.6} · q^(-{:.4})", ln_a.exp(), beta);

            // Check if q·|α̂_q| is approximately constant
            let q_alpha: Vec<f64> = coeffs.iter()
                .filter(|(q, _)| *q >= 4)
                .map(|(q, a)| *q as f64 * a.abs()).collect();
            if !q_alpha.is_empty() {
                let mean = q_alpha.iter().sum::<f64>() / q_alpha.len() as f64;
                let std = (q_alpha.iter().map(|x| (x - mean).powi(2)).sum::<f64>() / q_alpha.len() as f64).sqrt();
                println!("  q·|α̂_q|: mean = {:.6}, std = {:.6}, cv = {:.4}",
                    mean, std, std / mean);

                if beta > 0.8 && beta < 1.2 {
                    println!("  ✅ α̂_q ∝ 1/q CONFIRMED (β = {:.4} ≈ 1)", beta);
                } else {
                    println!("  ⚠️  α̂_q ∝ 1/q^{:.2} (not exactly 1/q)", beta);
                }
            }
        }
    }

    // Summary across all M
    println!("\n\n═══════════════════════════════════════════════════════════════");
    println!("  SUMMARY");
    println!("═══════════════════════════════════════════════════════════════");
    println!("  Total time: {:.1}s", start.elapsed().as_secs_f64());
    println!("═══════════════════════════════════════════════════════════════");
}
