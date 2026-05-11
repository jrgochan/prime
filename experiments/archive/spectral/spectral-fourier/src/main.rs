#![allow(unused, dead_code)]
use std::f64::consts::PI;

// ─── Zero Finding (same as before) ─────────────────────────

fn rs_theta(t: f64) -> f64 {
    let t2 = t / 2.0;
    let mut theta = t2 * (t2 / PI).ln() - t2 - PI / 8.0;
    if t > 1.0 {
        let ti = 1.0 / t;
        theta += ti / 48.0 + 7.0 * ti.powi(3) / 5760.0 + 31.0 * ti.powi(5) / 80640.0;
    }
    theta
}

fn hardy_z(t: f64) -> f64 {
    let n_max = ((t / (2.0 * PI)).sqrt()).floor() as usize;
    if n_max == 0 {
        return 0.0;
    }
    let theta = rs_theta(t);
    let mut sum = 0.0;
    for n in 1..=n_max {
        let nf = n as f64;
        sum += (theta - t * nf.ln()).cos() / nf.sqrt();
    }
    2.0 * sum
}

fn find_zeros(t_start: f64, t_end: f64, dt: f64) -> Vec<f64> {
    let mut zeros = Vec::new();
    let mut t = t_start;
    let mut z_prev = hardy_z(t);
    while t < t_end {
        let t_next = t + dt;
        let z_next = hardy_z(t_next);
        if z_prev * z_next < 0.0 {
            let (mut lo, mut hi) = (t, t_next);
            let mut zlo = z_prev;
            for _ in 0..60 {
                let mid = (lo + hi) / 2.0;
                let zm = hardy_z(mid);
                if zlo * zm < 0.0 {
                    hi = mid;
                } else {
                    lo = mid;
                    zlo = zm;
                }
            }
            zeros.push((lo + hi) / 2.0);
        }
        t = t_next;
        z_prev = z_next;
    }
    zeros
}

// ─── Jacobi Matrix ────────────────────────────────────────

fn inverse_eigenvalue_jacobi(eigs: &[f64]) -> (Vec<f64>, Vec<f64>) {
    let n = eigs.len();
    if n == 0 {
        return (vec![], vec![]);
    }
    if n == 1 {
        return (vec![eigs[0]], vec![]);
    }
    let mut p_prev = vec![0.0; n];
    let mut p_curr = vec![1.0; n];
    let mut diag = Vec::with_capacity(n);
    let mut offdiag = Vec::with_capacity(n - 1);
    for j in 0..n {
        let (mut xpp, mut pp) = (0.0, 0.0);
        for k in 0..n {
            let pk = p_curr[k];
            pp += pk * pk;
            xpp += eigs[k] * pk * pk;
        }
        let a = xpp / pp;
        diag.push(a);
        if j < n - 1 {
            let bp = if j > 0 { offdiag[j - 1] } else { 0.0 };
            let mut p_next = vec![0.0; n];
            for k in 0..n {
                p_next[k] = (eigs[k] - a) * p_curr[k] - bp * p_prev[k];
            }
            let pnp: f64 = p_next.iter().map(|x| x * x).sum();
            let b = (pnp / pp).sqrt();
            offdiag.push(b);
            if b > 1e-15 {
                let s = (pp / pnp).sqrt();
                for k in 0..n {
                    p_next[k] *= s;
                }
            }
            p_prev = p_curr;
            p_curr = p_next;
        }
    }
    (diag, offdiag)
}

// ─── Polynomial Fit ───────────────────────────────────────

fn poly_fit(x: &[f64], y: &[f64], degree: usize) -> Vec<f64> {
    let n = x.len();
    let m = degree + 1;
    let mut xtx = vec![0.0; m * m];
    let mut xty = vec![0.0; m];
    for i in 0..n {
        let mut xp = vec![1.0; m];
        for d in 1..m {
            xp[d] = xp[d - 1] * x[i];
        }
        for r in 0..m {
            xty[r] += xp[r] * y[i];
            for c in 0..m {
                xtx[r * m + c] += xp[r] * xp[c];
            }
        }
    }
    let mut aug = vec![vec![0.0; m + 1]; m];
    for r in 0..m {
        for c in 0..m {
            aug[r][c] = xtx[r * m + c];
        }
        aug[r][m] = xty[r];
    }
    for col in 0..m {
        let mr = (col..m)
            .max_by(|&a, &b| aug[a][col].abs().partial_cmp(&aug[b][col].abs()).unwrap())
            .unwrap();
        aug.swap(col, mr);
        let p = aug[col][col];
        if p.abs() < 1e-30 {
            continue;
        }
        for row in (col + 1)..m {
            let f = aug[row][col] / p;
            for j in col..=m {
                aug[row][j] -= f * aug[col][j];
            }
        }
    }
    let mut c = vec![0.0; m];
    for i in (0..m).rev() {
        c[i] = aug[i][m];
        for j in (i + 1)..m {
            c[i] -= aug[i][j] * c[j];
        }
        c[i] /= aug[i][i];
    }
    c
}

fn poly_eval(c: &[f64], x: f64) -> f64 {
    c.iter()
        .enumerate()
        .map(|(d, &co)| co * x.powi(d as i32))
        .sum()
}

// ─── Fourier power at a specific frequency ────────────────

fn fourier_power(residuals: &[f64], omega: f64) -> f64 {
    let (mut re, mut im) = (0.0, 0.0);
    for (k, &r) in residuals.iter().enumerate() {
        re += r * (omega * k as f64).cos();
        im += r * (omega * k as f64).sin();
    }
    re * re + im * im
}

// ─── Main ──────────────────────────────────────────────────

fn main() {
    println!("═══════════════════════════════════════════════════════════");
    println!("  π/4 HARMONIC DEEP DIVE");
    println!("  Testing stability across matrix sizes & harmonic structure");
    println!("═══════════════════════════════════════════════════════════");

    // Find lots of zeros
    println!("\n[1] Finding zeros up to t=1000...");
    let all_zeros = find_zeros(1.0, 1000.0, 0.05);
    println!("  Total zeros found: {}", all_zeros.len());

    // ═══ TEST 1: Stability across matrix sizes ═══
    println!("\n═══ TEST 1: Peak frequencies at different matrix sizes ═══");
    println!("  If π/4 harmonics are real, they should be STABLE as N changes.");
    println!("  If they're artifacts, they'll shift with N.\n");

    let test_sizes = [30, 50, 75, 100, 150, 200];

    // For each candidate harmonic of π/4
    let pi4 = PI / 4.0;
    let candidate_harmonics: Vec<usize> = vec![1, 3, 5, 7, 9, 11, 13];

    println!(
        "  {:>4}  {:>8}  {:>10}  {:>10}  {:>10}  {:>10}  {:>10}  {:>10}",
        "N", "RMS_res", "h=1", "h=3", "h=5", "h=7", "h=9", "h=11"
    );

    for &sz in &test_sizes {
        if sz > all_zeros.len() {
            continue;
        }
        let zeros = &all_zeros[..sz];
        let (_diag, offdiag) = inverse_eigenvalue_jacobi(zeros);
        let nb = offdiag.len();
        let x: Vec<f64> = (0..nb).map(|k| k as f64).collect();
        let coeffs = poly_fit(&x, &offdiag, 4);
        let residuals: Vec<f64> = (0..nb)
            .map(|k| offdiag[k] - poly_eval(&coeffs, k as f64))
            .collect();
        let rms: f64 = (residuals.iter().map(|r| r * r).sum::<f64>() / nb as f64).sqrt();

        // Measure power at each harmonic of π/4
        let mut powers = Vec::new();
        for &h in &candidate_harmonics {
            let omega = h as f64 * pi4;
            // Search ±0.15 around the harmonic for the actual peak
            let n_search = 30;
            let mut max_pow = 0.0f64;
            for i in 0..=n_search {
                let w = omega - 0.15 + 0.30 * i as f64 / n_search as f64;
                let p = fourier_power(&residuals, w);
                max_pow = max_pow.max(p);
            }
            powers.push(max_pow);
        }
        let total_power: f64 = {
            let mut tp = 0.0;
            for fi in 0..200 {
                let w = fi as f64 * 8.0 / 200.0;
                tp += fourier_power(&residuals, w);
            }
            tp
        };

        // Normalize powers as fraction of total
        print!("  {:4}  {:8.3}", sz, rms);
        for &p in &powers {
            print!("  {:9.1}%", p / total_power * 100.0);
        }
        println!();
    }

    // ═══ TEST 2: Is the peak at π/4 or at something else? ═══
    println!("\n═══ TEST 2: Fine frequency scan around dominant peaks ═══");
    println!("  Scanning ω ∈ [0, 8] with resolution 0.001\n");

    let zeros100 = &all_zeros[..100.min(all_zeros.len())];
    let (_diag100, offdiag100) = inverse_eigenvalue_jacobi(zeros100);
    let nb = offdiag100.len();
    let x: Vec<f64> = (0..nb).map(|k| k as f64).collect();
    let coeffs = poly_fit(&x, &offdiag100, 4);
    let residuals: Vec<f64> = (0..nb)
        .map(|k| offdiag100[k] - poly_eval(&coeffs, k as f64))
        .collect();

    // Fine scan
    let n_fine = 8000;
    let mut spectrum: Vec<(f64, f64)> = Vec::with_capacity(n_fine);
    for fi in 0..n_fine {
        let w = fi as f64 * 8.0 / n_fine as f64;
        spectrum.push((w, fourier_power(&residuals, w)));
    }

    // Find top 5 local maxima
    let mut peaks: Vec<(f64, f64)> = Vec::new();
    for i in 2..spectrum.len() - 2 {
        let (w, p) = spectrum[i];
        if p > spectrum[i - 1].1
            && p > spectrum[i + 1].1
            && p > spectrum[i - 2].1
            && p > spectrum[i + 2].1
        {
            peaks.push((w, p));
        }
    }
    peaks.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap());

    println!("  Top 10 local maxima:");
    println!(
        "  {:>4}  {:>10}  {:>12}  {:>12}  {:>12}",
        "rank", "ω_peak", "power", "ω/π", "ω/(π/4)"
    );
    for (i, &(w, p)) in peaks.iter().take(10).enumerate() {
        println!(
            "  {:4}  {:10.4}  {:12.1}  {:12.4}  {:12.4}",
            i + 1,
            w,
            p,
            w / PI,
            w / pi4
        );
    }

    // ═══ TEST 3: Nearest-neighbor spacing of b_k ═══
    println!("\n═══ TEST 3: Nearest-neighbor spacing distribution of b_k ═══");
    println!("  GUE predicts Wigner surmise: P(s) = (π/2)s·exp(-πs²/4)");
    println!("  Poisson (random) predicts: P(s) = exp(-s)\n");

    // Compute spacings Δb_k = |b_{k+1} - b_k|
    let mut spacings: Vec<f64> = Vec::new();
    for k in 0..nb - 1 {
        spacings.push((offdiag100[k + 1] - offdiag100[k]).abs());
    }
    let mean_spacing = spacings.iter().sum::<f64>() / spacings.len() as f64;
    // Normalize spacings
    let norm_spacings: Vec<f64> = spacings.iter().map(|&s| s / mean_spacing).collect();

    // Bin into histogram
    let n_bins = 10;
    let s_max = 4.0;
    let mut hist = vec![0usize; n_bins];
    for &s in &norm_spacings {
        let bin = ((s / s_max) * n_bins as f64).floor() as usize;
        if bin < n_bins {
            hist[bin] += 1;
        }
    }

    println!(
        "  {:>8}  {:>6}  {:>10}  {:>10}  {:>10}",
        "s_range", "count", "observed", "GUE", "Poisson"
    );
    for b in 0..n_bins {
        let s_lo = b as f64 * s_max / n_bins as f64;
        let s_hi = (b + 1) as f64 * s_max / n_bins as f64;
        let s_mid = (s_lo + s_hi) / 2.0;
        let obs = hist[b] as f64 / norm_spacings.len() as f64 / (s_max / n_bins as f64);
        let gue = PI / 2.0 * s_mid * (-PI * s_mid * s_mid / 4.0).exp();
        let poisson = (-s_mid).exp();
        println!(
            "  [{:.1},{:.1})  {:6}  {:10.4}  {:10.4}  {:10.4}",
            s_lo, s_hi, hist[b], obs, gue, poisson
        );
    }

    // ═══ TEST 4: Derivative Δb_k prime correlation ═══
    println!("\n═══ TEST 4: Do jumps in b_k correlate with primes? ═══");
    println!("  If b_k encodes primes, big |Δb_k| should occur near prime k.\n");

    let primes: Vec<usize> = {
        let mut p = Vec::new();
        for n in 2..300 {
            if (2..=(n as f64).sqrt() as usize + 1).all(|d| n % d != 0) {
                p.push(n);
            }
        }
        p
    };

    let mut delta_b: Vec<f64> = Vec::new();
    for k in 0..nb - 1 {
        delta_b.push((offdiag100[k + 1] - offdiag100[k]).abs());
    }

    // Average |Δb_k| at prime k vs composite k
    let mut prime_sum = 0.0;
    let mut prime_count = 0;
    let mut comp_sum = 0.0;
    let mut comp_count = 0;

    for k in 0..delta_b.len() {
        let is_prime = primes.contains(&(k + 2));
        if is_prime {
            prime_sum += delta_b[k];
            prime_count += 1;
        } else {
            comp_sum += delta_b[k];
            comp_count += 1;
        }
    }

    let prime_avg = if prime_count > 0 {
        prime_sum / prime_count as f64
    } else {
        0.0
    };
    let comp_avg = if comp_count > 0 {
        comp_sum / comp_count as f64
    } else {
        0.0
    };

    println!(
        "  Average |Δb_k| at prime k:     {:.4}  (n={})",
        prime_avg, prime_count
    );
    println!(
        "  Average |Δb_k| at composite k:  {:.4}  (n={})",
        comp_avg, comp_count
    );
    println!(
        "  Ratio (prime/composite):         {:.4}",
        prime_avg / comp_avg
    );

    // ═══ TEST 5: Look at actual zero spacings connection ═══
    println!("\n═══ TEST 5: b_k vs local zero spacing ═══");
    println!("  Testing if b_k is proportional to local zero spacing\n");

    let zero_spacings: Vec<f64> = (0..zeros100.len() - 1)
        .map(|k| zeros100[k + 1] - zeros100[k])
        .collect();

    // Correlation between b_k and adjacent zero spacings
    let min_len = nb.min(zero_spacings.len());
    let mean_b: f64 = offdiag100[..min_len].iter().sum::<f64>() / min_len as f64;
    let mean_s: f64 = zero_spacings[..min_len].iter().sum::<f64>() / min_len as f64;
    let cov: f64 = (0..min_len)
        .map(|k| (offdiag100[k] - mean_b) * (zero_spacings[k] - mean_s))
        .sum::<f64>()
        / min_len as f64;
    let std_b: f64 = (offdiag100[..min_len]
        .iter()
        .map(|&b| (b - mean_b).powi(2))
        .sum::<f64>()
        / min_len as f64)
        .sqrt();
    let std_s: f64 = (zero_spacings[..min_len]
        .iter()
        .map(|&s| (s - mean_s).powi(2))
        .sum::<f64>()
        / min_len as f64)
        .sqrt();
    let pearson = if std_b * std_s > 0.0 {
        cov / (std_b * std_s)
    } else {
        0.0
    };

    println!("  Pearson(b_k, Δγ_k):            {:.4}", pearson);

    // Also check b_k vs running average of spacings
    let window = 5;
    let mut smooth_spacing: Vec<f64> = Vec::new();
    for k in 0..min_len {
        let lo = k.saturating_sub(window);
        let hi = (k + window + 1).min(zero_spacings.len());
        let avg: f64 = zero_spacings[lo..hi].iter().sum::<f64>() / (hi - lo) as f64;
        smooth_spacing.push(avg);
    }
    let mean_ss: f64 = smooth_spacing.iter().sum::<f64>() / smooth_spacing.len() as f64;
    let cov2: f64 = (0..min_len)
        .map(|k| (offdiag100[k] - mean_b) * (smooth_spacing[k] - mean_ss))
        .sum::<f64>()
        / min_len as f64;
    let std_ss: f64 = (smooth_spacing
        .iter()
        .map(|&s| (s - mean_ss).powi(2))
        .sum::<f64>()
        / smooth_spacing.len() as f64)
        .sqrt();
    let pearson2 = if std_b * std_ss > 0.0 {
        cov2 / (std_b * std_ss)
    } else {
        0.0
    };
    println!(
        "  Pearson(b_k, smooth Δγ_k):      {:.4}  (window=±{})",
        pearson2, window
    );

    println!("\n═══════════════════════════════════════════════════════════");
    println!("  Analysis complete.");
    println!("═══════════════════════════════════════════════════════════");
}
