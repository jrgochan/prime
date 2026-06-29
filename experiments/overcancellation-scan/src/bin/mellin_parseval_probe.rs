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

/// Approximate ζ(1/2 + it) via Euler-Maclaurin partial sums
/// (good enough for |t| < 100 with enough terms)
fn zeta_half_it(t: f64, n_terms: usize) -> (f64, f64) {
    // ζ(s) ≈ Σ_{n=1}^{N} 1/n^s + N^{1-s}/(s-1) + 1/(2·N^s) + ...
    let s_re = 0.5;
    let s_im = t;
    let mut re = 0.0_f64;
    let mut im = 0.0_f64;

    for n in 1..=n_terms {
        let ln_n = (n as f64).ln();
        // n^{-s} = n^{-1/2} · e^{-it·ln(n)}
        let mag = (n as f64).powf(-s_re);
        let phase = -s_im * ln_n;
        re += mag * phase.cos();
        im += mag * phase.sin();
    }

    // Euler-Maclaurin correction: N^{1-s}/(s-1) + 1/(2N^s)
    let n_f = n_terms as f64;
    let ln_n = n_f.ln();

    // N^{1-s} = N^{1/2} · e^{-it·lnN}
    let mag1 = n_f.powf(1.0 - s_re);
    let phase1 = -s_im * ln_n;
    let n1s_re = mag1 * phase1.cos();
    let n1s_im = mag1 * phase1.sin();

    // 1/(s-1) = 1/(-1/2 + it) = (-1/2 - it)/(1/4 + t²)
    let denom = 0.25 + t * t;
    let inv_sm1_re = -0.5 / denom;
    let inv_sm1_im = -t / denom;

    // N^{1-s}/(s-1)
    re += n1s_re * inv_sm1_re - n1s_im * inv_sm1_im;
    im += n1s_re * inv_sm1_im + n1s_im * inv_sm1_re;

    // 1/(2N^s) = N^{-1/2}·e^{-it·lnN} / 2
    let mag2 = n_f.powf(-s_re) / 2.0;
    let phase2 = -s_im * ln_n;
    re += mag2 * phase2.cos();
    im += mag2 * phase2.sin();

    (re, im)
}

/// Complex multiply (a+bi)(c+di)
fn cmul(a: f64, b: f64, c: f64, d: f64) -> (f64, f64) {
    (a * c - b * d, a * d + b * c)
}

/// Complex |a+bi|²
fn cabs2(a: f64, b: f64) -> f64 {
    a * a + b * b
}

fn main() {
    let n_max = 20_000;
    let mu = mobius_sieve(n_max);

    println!("═══════════════════════════════════════════════════════════════");
    println!("MELLIN-PARSEVAL SPECTRAL PROBE — ζ(s) on Critical Line");
    println!("═══════════════════════════════════════════════════════════════");

    // ═══ §1: Dirichlet polynomial D_N(1/2+it) ═══
    println!();
    println!("═══ §1: D_N(1/2+it) = Σ v_k / k^{{1/2+it}} ═══");
    println!("  v_k = -μ(k)·(1-lnk/lnN)");
    println!();

    for &n in &[100, 1000, 5000, 10000, 20000] {
        if n > n_max {
            break;
        }
        let ln_n = (n as f64).ln();

        println!("--- N = {} ---", n);
        println!(
            "{:>8} {:>14} {:>14} {:>14} {:>14}",
            "t", "|D_N|²", "|ζ|²", "ζ·D_N (re)", "|ζ·D_N+1/s|²"
        );
        println!("{}", "-".repeat(68));

        for &t in &[
            0.0, 1.0, 2.0, 5.0, 10.0, 14.13, 21.02, 25.01, 30.42, 50.0, 100.0,
        ] {
            // D_N(1/2+it) = Σ v_k / k^{1/2+it}
            let mut dn_re = 0.0_f64;
            let mut dn_im = 0.0_f64;
            for k in 1..n {
                let mu_k = mu[k] as f64;
                if mu_k == 0.0 {
                    continue;
                }
                let w = 1.0 - (k as f64).ln() / ln_n;
                let v_k = -mu_k * w;
                let mag = v_k * (k as f64).powf(-0.5);
                let phase = -t * (k as f64).ln();
                dn_re += mag * phase.cos();
                dn_im += mag * phase.sin();
            }

            // ζ(1/2+it)
            let (z_re, z_im) = zeta_half_it(t, 5000);

            // ζ·D_N
            let (zd_re, zd_im) = cmul(z_re, z_im, dn_re, dn_im);

            // 1/s = 1/(1/2+it) = (1/2-it)/(1/4+t²)
            let s_denom = 0.25 + t * t;
            let inv_s_re = 0.5 / s_denom;
            let inv_s_im = -t / s_denom;

            // Error: ζ·D_N + 1/s (should be small if witness is good)
            let err_re = zd_re + inv_s_re;
            let err_im = zd_im + inv_s_im;

            println!(
                "{:>8.2} {:>14.6} {:>14.6} {:>14.6} {:>14.6e}",
                t,
                cabs2(dn_re, dn_im),
                cabs2(z_re, z_im),
                zd_re,
                cabs2(err_re, err_im)
            );
        }
        println!();
    }

    // ═══ §2: Spectral energy distribution ═══
    println!("═══ §2: Where Does the Spectral Error Live? ═══");
    println!("  Computing ∫₀ᵀ |ζ(1/2+it)·D_N(1/2+it) + 1/(1/2+it)|² dt");
    println!();

    for &n in &[100, 500, 1000, 5000, 10000] {
        if n > n_max {
            break;
        }
        let ln_n = (n as f64).ln();

        // Build weights
        let mut weights: Vec<(usize, f64)> = Vec::new();
        for k in 1..n {
            let mu_k = mu[k] as f64;
            if mu_k == 0.0 {
                continue;
            }
            let w = 1.0 - (k as f64).ln() / ln_n;
            weights.push((k, -mu_k * w));
        }

        // Integrate spectral error
        let dt = 0.1;
        let t_max = 200.0;
        let mut cumul = 0.0;
        let mut milestones = vec![];

        let mut t = 0.1; // avoid t=0 singularity
        while t < t_max {
            let mut dn_re = 0.0;
            let mut dn_im = 0.0;
            for &(k, v_k) in &weights {
                let mag = v_k * (k as f64).powf(-0.5);
                let phase = -t * (k as f64).ln();
                dn_re += mag * phase.cos();
                dn_im += mag * phase.sin();
            }

            let (z_re, z_im) = zeta_half_it(t, 2000.max(n));

            let (zd_re, zd_im) = cmul(z_re, z_im, dn_re, dn_im);

            let s_denom = 0.25 + t * t;
            let inv_s_re = 0.5 / s_denom;
            let inv_s_im = -t / s_denom;

            let err2 = cabs2(zd_re + inv_s_re, zd_im + inv_s_im);

            // Weight by 1/|s(1-s)|² for the Parseval measure
            // |s|² = 1/4 + t², |1-s|² = 1/4 + t²
            // So |s(1-s)|² = (1/4+t²)²
            // The Parseval weight is 1/|s|² = 1/(1/4+t²)
            let parseval_weight = 1.0 / (0.25 + t * t);
            cumul += err2 * parseval_weight * dt;

            if t >= 1.0 && (t * 10.0).round() as i64 % 100 == 0 {
                milestones.push((t, cumul));
            }

            t += dt;
        }

        print!("  N={:>5}: cumul_err = {:.6}, milestones: ", n, cumul);
        for &(t, c) in milestones.iter().take(5) {
            print!("t={:.0}:{:.4} ", t, c);
        }
        println!();
    }

    // ═══ §3: The ζ·D_N product — approaching 1/ζ? ═══
    println!();
    println!("═══ §3: Is D_N(s) ≈ -1/(s·ζ(s))? ═══");
    println!("  If D_N approximates 1/ζ times geometry, the product ζ·D_N → -1/s");
    println!();

    let n = 10000;
    let ln_n = (n as f64).ln();
    let mut weights: Vec<(usize, f64)> = Vec::new();
    for k in 1..n {
        let mu_k = mu[k] as f64;
        if mu_k == 0.0 {
            continue;
        }
        let w = 1.0 - (k as f64).ln() / ln_n;
        weights.push((k, -mu_k * w));
    }

    println!(
        "{:>8} {:>12} {:>12} {:>12} {:>12} {:>12}",
        "t", "ζ·D_N re", "ζ·D_N im", "-1/s re", "-1/s im", "|err|²"
    );
    println!("{}", "-".repeat(72));

    for &t in &[
        0.5, 1.0, 2.0, 3.0, 5.0, 7.0, 10.0, 14.13, 21.02, 25.01, 30.42, 37.59, 40.92, 50.0, 75.0,
        100.0,
    ] {
        let mut dn_re = 0.0;
        let mut dn_im = 0.0;
        for &(k, v_k) in &weights {
            let mag = v_k * (k as f64).powf(-0.5);
            let phase = -t * (k as f64).ln();
            dn_re += mag * phase.cos();
            dn_im += mag * phase.sin();
        }
        let (z_re, z_im) = zeta_half_it(t, n);
        let (zd_re, zd_im) = cmul(z_re, z_im, dn_re, dn_im);

        // Target: -1/s = -(1/2-it)/(1/4+t²)
        let s_denom = 0.25 + t * t;
        let target_re = -0.5 / s_denom;
        let target_im = t / s_denom;

        let err2 = cabs2(zd_re - target_re, zd_im - target_im);

        println!(
            "{:>8.2} {:>12.6} {:>12.6} {:>12.6} {:>12.6} {:>12.4e}",
            t, zd_re, zd_im, target_re, target_im, err2
        );
    }

    // ═══ §4: Connection to zeta zeros ═══
    println!();
    println!("═══ §4: Spectral Error Near Zeta Zeros ═══");
    println!("  First few zeros: 14.13, 21.02, 25.01, 30.42, 32.94, 37.59, 40.92");
    println!("  The error should spike AT zeros (where ζ=0, so ζ·D_N=0 ≠ -1/s)");
    println!();

    // Fine scan around first zero
    println!(
        "{:>8} {:>12} {:>14} {:>14}",
        "t", "|ζ(1/2+it)|", "|ζ·D_N+1/s|²", "spect_err"
    );
    println!("{}", "-".repeat(52));

    let mut t = 13.0;
    while t <= 15.5 {
        let mut dn_re = 0.0;
        let mut dn_im = 0.0;
        for &(k, v_k) in &weights {
            let mag = v_k * (k as f64).powf(-0.5);
            let phase = -t * (k as f64).ln();
            dn_re += mag * phase.cos();
            dn_im += mag * phase.sin();
        }
        let (z_re, z_im) = zeta_half_it(t, n);
        let (zd_re, zd_im) = cmul(z_re, z_im, dn_re, dn_im);

        let s_denom = 0.25 + t * t;
        let inv_s_re = 0.5 / s_denom;
        let inv_s_im = -t / s_denom;

        let err2 = cabs2(zd_re + inv_s_re, zd_im + inv_s_im);
        let z_abs = cabs2(z_re, z_im).sqrt();

        println!(
            "{:>8.3} {:>12.6} {:>14.6e} {:>14.6e}",
            t,
            z_abs,
            err2,
            err2 / (0.25 + t * t)
        );
        t += 0.1;
    }

    println!();
    println!("═══════════════════════════════════════════════════════════════");
    println!("KEY QUESTION: Does D_N(s) ≈ -1/(s·ζ(s)) on the critical line?");
    println!("If so, the error |ζ·D_N + 1/s|² is controlled by how well");
    println!("the FINITE Dirichlet polynomial truncation approximates 1/ζ(s).");
    println!("This is the irreducible content: the Dirichlet series 1/ζ(s)");
    println!("= Σ μ(n)/n^s converges on Re(s) > 1, and extending to Re(s)=1/2");
    println!("IS the Riemann Hypothesis.");
    println!("═══════════════════════════════════════════════════════════════");
}
