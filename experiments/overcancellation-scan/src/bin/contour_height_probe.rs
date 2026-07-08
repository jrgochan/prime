#![allow(clippy::needless_range_loop, clippy::let_and_return)]

use cathedral_utils::arith::mobius_table;

/// ζ(σ+it) via partial sums + Euler-Maclaurin
fn zeta_at(sigma: f64, t: f64, n_terms: usize) -> (f64, f64) {
    let mut re = 0.0_f64;
    let mut im = 0.0_f64;
    for n in 1..=n_terms {
        let ln_n = (n as f64).ln();
        let mag = (n as f64).powf(-sigma);
        let phase = -t * ln_n;
        re += mag * phase.cos();
        im += mag * phase.sin();
    }
    // Euler-Maclaurin: N^{1-s}/(s-1) + 1/(2N^s)
    let n_f = n_terms as f64;
    let ln_n = n_f.ln();
    let mag1 = n_f.powf(1.0 - sigma);
    let phase1 = -t * ln_n;
    let (n1s_re, n1s_im) = (mag1 * phase1.cos(), mag1 * phase1.sin());
    let denom = (sigma - 1.0).powi(2) + t * t;
    if denom > 1e-20 {
        let inv_re = (sigma - 1.0) / denom;
        let inv_im = t / denom;
        re += n1s_re * inv_re - n1s_im * inv_im;
        im += n1s_re * inv_im + n1s_im * inv_re;
    }
    let mag2 = n_f.powf(-sigma) / 2.0;
    let phase2 = -t * ln_n;
    re += mag2 * phase2.cos();
    im += mag2 * phase2.sin();
    (re, im)
}

fn cmul(a: f64, b: f64, c: f64, d: f64) -> (f64, f64) {
    (a * c - b * d, a * d + b * c)
}
fn cabs2(a: f64, b: f64) -> f64 {
    a * a + b * b
}

fn main() {
    let n_max = 20_000;
    let mu = mobius_table(n_max);

    println!("═══════════════════════════════════════════════════════════════");
    println!("CONTOUR HEIGHT PROBE — Spectral Error vs Re(s)");
    println!("═══════════════════════════════════════════════════════════════");

    // ═══ §1: E_N at various σ for fixed t ═══
    println!();
    println!("═══ §1: |E_N(σ+it)|² at t=5.0 for various σ and N ═══");
    println!("  E_N(s) = ζ(s)·D_N(s) + 1/s");
    println!();
    println!(
        "{:>6} {:>10} {:>10} {:>10} {:>10} {:>10}",
        "σ", "N=100", "N=500", "N=2000", "N=10000", "N=20000"
    );
    println!("{}", "-".repeat(62));

    let t_fixed = 5.0;
    for &sigma in &[
        0.50, 0.55, 0.60, 0.65, 0.70, 0.75, 0.80, 0.85, 0.90, 0.95, 1.00, 1.05, 1.10, 1.20, 1.50,
        2.00,
    ] {
        print!("{:>6.2}", sigma);
        for &n in &[100, 500, 2000, 10000, 20000] {
            if n > n_max {
                print!("{:>10}", "---");
                continue;
            }
            let ln_n = (n as f64).ln();
            let mut dn_re = 0.0;
            let mut dn_im = 0.0;
            for k in 1..n {
                let mu_k = mu[k] as f64;
                if mu_k == 0.0 {
                    continue;
                }
                let w = 1.0 - (k as f64).ln() / ln_n;
                let v_k = -mu_k * w;
                let mag = v_k * (k as f64).powf(-sigma);
                let phase = -t_fixed * (k as f64).ln();
                dn_re += mag * phase.cos();
                dn_im += mag * phase.sin();
            }
            let (z_re, z_im) = zeta_at(sigma, t_fixed, 5000.max(n));
            let (zd_re, zd_im) = cmul(z_re, z_im, dn_re, dn_im);
            let s_denom = sigma * sigma + t_fixed * t_fixed;
            let inv_re = sigma / s_denom;
            let inv_im = -t_fixed / s_denom;
            let err2 = cabs2(zd_re + inv_re, zd_im + inv_im);
            print!("{:>10.4e}", err2);
        }
        println!();
    }

    // ═══ §2: Integrated spectral error at various σ ═══
    println!();
    println!("═══ §2: Integrated Error ∫|E_N(σ+it)|²/(σ²+t²) dt ═══");
    println!("  This is the 'Parseval d²' at height σ");
    println!();
    println!(
        "{:>6} {:>12} {:>12} {:>12} {:>12} {:>12}",
        "σ", "N=100", "N=500", "N=2000", "N=5000", "N=10000"
    );
    println!("{}", "-".repeat(72));

    for &sigma in &[0.50, 0.55, 0.60, 0.70, 0.80, 0.90, 0.95, 1.00, 1.10, 1.50] {
        print!("{:>6.2}", sigma);
        for &n in &[100, 500, 2000, 5000, 10000] {
            if n > n_max {
                print!("{:>12}", "---");
                continue;
            }
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

            let dt = 0.2;
            let t_max = 100.0;
            let mut integral = 0.0;
            let mut t = 0.2;
            while t < t_max {
                let mut dn_re = 0.0;
                let mut dn_im = 0.0;
                for &(k, v_k) in &weights {
                    let mag = v_k * (k as f64).powf(-sigma);
                    let phase = -t * (k as f64).ln();
                    dn_re += mag * phase.cos();
                    dn_im += mag * phase.sin();
                }
                let (z_re, z_im) = zeta_at(sigma, t, 2000.max(n));
                let (zd_re, zd_im) = cmul(z_re, z_im, dn_re, dn_im);
                let s_denom = sigma * sigma + t * t;
                let inv_re = sigma / s_denom;
                let inv_im = -t / s_denom;
                let err2 = cabs2(zd_re + inv_re, zd_im + inv_im);
                integral += err2 / s_denom * dt;
                t += dt;
            }
            print!("{:>12.6}", integral);
        }
        println!();
    }

    // ═══ §3: The Gap: σ=1 vs σ=1/2 ═══
    println!();
    println!("═══ §3: The Critical Strip Gap ═══");
    println!("  Gap = ∫|E_N|² at σ=1/2 minus ∫|E_N|² at σ=1");
    println!("  This gap equals the contribution from zeros with 1/2 < Re(ρ) < 1");
    println!("  Under RH: Gap = 0 (no zeros in strip)");
    println!();

    for &n in &[100, 500, 1000, 5000, 10000] {
        if n > n_max {
            continue;
        }
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

        let dt = 0.2;
        let t_max = 100.0;

        let sigma_zfr = 1.0 - 1.0 / ln_n; // zero-free region boundary

        let sigmas = [0.5, sigma_zfr, 1.0];
        let mut integrals = [0.0_f64; 3];

        let mut t = 0.2;
        while t < t_max {
            for (idx, &sigma) in sigmas.iter().enumerate() {
                let mut dn_re = 0.0;
                let mut dn_im = 0.0;
                for &(k, v_k) in &weights {
                    let mag = v_k * (k as f64).powf(-sigma);
                    let phase = -t * (k as f64).ln();
                    dn_re += mag * phase.cos();
                    dn_im += mag * phase.sin();
                }
                let (z_re, z_im) = zeta_at(sigma, t, 2000.max(n));
                let (zd_re, zd_im) = cmul(z_re, z_im, dn_re, dn_im);
                let s_denom = sigma * sigma + t * t;
                let inv_re = sigma / s_denom;
                let inv_im = -t / s_denom;
                let err2 = cabs2(zd_re + inv_re, zd_im + inv_im);
                integrals[idx] += err2 / s_denom * dt;
            }
            t += dt;
        }

        let int_half = integrals[0];
        let int_zfr = integrals[1];
        let int_one = integrals[2];

        let gap_half_one = int_half - int_one;
        let gap_zfr_one = int_zfr - int_one;
        println!("  N={:>5}: σ=1/2: {:.4}, σ={:.3}: {:.4}, σ=1: {:.4}, gap(1/2→1): {:.4}, gap(zfr→1): {:.4}",
                 n, int_half, sigma_zfr, int_zfr, int_one, gap_half_one, gap_zfr_one);
    }

    // ═══ §4: Convergence rate vs σ ═══
    println!();
    println!("═══ §4: Convergence Rate Analysis ═══");
    println!("  For each σ, compute |E_N| · logN to see if error = O(1/logN)");
    println!();

    let t_test = 5.0;
    println!(
        "{:>6} {:>14} {:>14} {:>14}",
        "σ", "|E|²·logN @1k", "|E|²·logN @5k", "|E|²·logN @20k"
    );
    println!("{}", "-".repeat(52));

    for &sigma in &[0.50, 0.60, 0.70, 0.80, 0.90, 0.95, 1.00, 1.10, 1.50] {
        print!("{:>6.2}", sigma);
        for &n in &[1000, 5000, 20000] {
            let ln_n = (n as f64).ln();
            let mut dn_re = 0.0;
            let mut dn_im = 0.0;
            for k in 1..n {
                let mu_k = mu[k] as f64;
                if mu_k == 0.0 {
                    continue;
                }
                let w = 1.0 - (k as f64).ln() / ln_n;
                let v_k = -mu_k * w;
                let mag = v_k * (k as f64).powf(-sigma);
                let phase = -t_test * (k as f64).ln();
                dn_re += mag * phase.cos();
                dn_im += mag * phase.sin();
            }
            let (z_re, z_im) = zeta_at(sigma, t_test, 5000.max(n));
            let (zd_re, zd_im) = cmul(z_re, z_im, dn_re, dn_im);
            let s_denom = sigma * sigma + t_test * t_test;
            let inv_re = sigma / s_denom;
            let inv_im = -t_test / s_denom;
            let err2 = cabs2(zd_re + inv_re, zd_im + inv_im);
            print!("{:>14.4e}", err2 * ln_n);
        }
        println!();
    }

    println!();
    println!("═══════════════════════════════════════════════════════════════");
    println!("INTERPRETATION:");
    println!("  • σ > 1: Error decays as N^{{1-2σ}} — provable from absolute convergence");
    println!("  • σ ~ 1: Error = O(1/logN) — provable from PNT/zero-free region");
    println!("  • σ = 1/2: Error O(1/logN) ↔ RH");
    println!();
    println!("  The PROVABLE part: everything at σ ≥ 1 (or in the zero-free region).");
    println!("  The GAP: contour shift from σ=1/2 to σ=1.");
    println!("  Under RH: no zeros in strip → contour shift is free → d²=O(1/logN).");
    println!("═══════════════════════════════════════════════════════════════");
}
