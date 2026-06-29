//! ═══════════════════════════════════════════════════════════════════════════
//!  HEEGNER PROBE — The Deep Lore of the Dark Crystal
//!
//!  Investigates the Dark Gram matrix at the 9 Heegner number dimensions.
//!
//!  BACKGROUND:
//!    The Heegner numbers {1, 2, 3, 7, 11, 19, 43, 67, 163} are the ONLY
//!    values d where Q(√-d) has unique factorization (class number 1).
//!
//!    Euler's prime-generating polynomial E(n) = n² - n + 41 has
//!    discriminant -163 (the largest Heegner number), and shares the exact
//!    same quadratic spine x² - x as our B₂(x) = x² - x + 1/6.
//!
//!  QUESTION:
//!    Does the spectral structure of G^(2)_N exhibit anomalies or special
//!    properties when N is a Heegner number? Does the unique factorization
//!    in the imaginary quadratic field manifest as spectral purity in the
//!    GCD crystal?
//!
//!  MEASUREMENTS:
//!    For each Heegner number h and its neighbors h±1, h±2, we compute:
//!    - Full eigenspectrum (eigenvalues, condition number)
//!    - Determinant (product of eigenvalues)
//!    - Spectral entropy / effective rank
//!    - Euler product ratio: det(G_N) vs ∏_p contribution
//!    - Spacing ratio ⟨r⟩ (Poisson vs GOE vs GUE)
//!    - GCD structure statistics (coprimality fraction)
//!
//!  Usage:
//!    cargo run --release --bin heegner-probe
//! ═══════════════════════════════════════════════════════════════════════════

use std::time::Instant;

use dark_gram_spectroscopy::dark_gram;

/// The nine Heegner numbers — the deepest structural constants in number theory.
const HEEGNER: [usize; 9] = [1, 2, 3, 7, 11, 19, 43, 67, 163];

/// Euler's prime-generating polynomial: n² - n + 41
fn euler_poly(n: i64) -> i64 {
    n * n - n + 41
}

/// Check if a positive integer is prime (trial division, fine for small numbers).
fn is_prime(n: u64) -> bool {
    if n < 2 {
        return false;
    }
    if n < 4 {
        return true;
    }
    if n.is_multiple_of(2) || n.is_multiple_of(3) {
        return false;
    }
    let mut i = 5u64;
    while i * i <= n {
        if n.is_multiple_of(i) || n.is_multiple_of(i + 2) {
            return false;
        }
        i += 6;
    }
    true
}

/// GCD
fn gcd(a: usize, b: usize) -> usize {
    let (mut a, mut b) = (a, b);
    while b != 0 {
        let t = b;
        b = a % b;
        a = t;
    }
    a
}

/// Compute the fraction of coprime pairs in the index set {2, 3, ..., N+1}.
fn coprimality_fraction(dim: usize) -> f64 {
    let mut coprime_count = 0usize;
    let mut total = 0usize;
    for i in 0..dim {
        for j in (i + 1)..dim {
            total += 1;
            if gcd(i + 2, j + 2) == 1 {
                coprime_count += 1;
            }
        }
    }
    if total == 0 {
        return 1.0;
    }
    coprime_count as f64 / total as f64
}

/// Analyze the Dark Gram matrix at a given dimension.
struct HeegnerResult {
    dim: usize,
    is_heegner: bool,
    lambda_min: f64,
    lambda_max: f64,
    kappa: f64,
    log_det: f64,  // log of absolute determinant
    det_sign: i32, // sign of determinant
    trace: f64,
    frobenius: f64,
    spectral_entropy: f64,
    eff_rank: f64,
    r_mean: f64,
    ensemble: String,
    coprime_frac: f64,
    euler_primes: usize, // how many of E(1)..E(dim) are prime
    build_time: f64,
    eigen_time: f64,
}

fn analyze_heegner_dim(dim: usize) -> HeegnerResult {
    let is_heegner = HEEGNER.contains(&dim);
    let tag = if is_heegner { "★ HEEGNER ★" } else { "" };
    eprintln!("  ── N={dim} {tag} ──────────────────────────────");

    // Build the matrix
    let t_build = Instant::now();
    let mat = dark_gram::build_dark_gram(2, dim);
    let build_time = t_build.elapsed().as_secs_f64();

    // Structural stats
    let trace: f64 = (0..dim).map(|i| mat[i * dim + i]).sum();
    let frobenius: f64 = mat.iter().map(|x| x * x).sum::<f64>().sqrt();

    // Full eigendecomposition
    let t_eigen = Instant::now();
    let faer_mat = faer::Mat::from_fn(dim, dim, |i, j| mat[i * dim + j]);
    let eig_vec = faer_mat
        .self_adjoint_eigenvalues(faer::Side::Lower)
        .expect("eigenvalue computation failed");
    let mut eigenvalues: Vec<f64> = eig_vec;
    eigenvalues.sort_by(|a, b| a.partial_cmp(b).unwrap()); // ascending
    let eigen_time = t_eigen.elapsed().as_secs_f64();

    let lambda_min = eigenvalues[0].abs().max(1e-300);
    let lambda_max = eigenvalues[dim - 1];
    let kappa = lambda_max / lambda_min;

    // Log-determinant (sum of log|λ|)
    let mut log_det = 0.0f64;
    let mut det_sign = 1i32;
    for &lam in &eigenvalues {
        if lam.abs() < 1e-300 {
            log_det = f64::NEG_INFINITY;
            break;
        }
        log_det += lam.abs().ln();
        if lam < 0.0 {
            det_sign *= -1;
        }
    }

    // Spectral entropy and effective rank
    let total: f64 = eigenvalues.iter().filter(|&&x| x > 0.0).sum();
    let (spectral_entropy, eff_rank) = if total > 0.0 {
        let entropy: f64 = eigenvalues
            .iter()
            .filter(|&&x| x > 0.0)
            .map(|&x| {
                let p = x / total;
                if p > 1e-30 {
                    -p * p.ln()
                } else {
                    0.0
                }
            })
            .sum();
        (entropy, entropy.exp())
    } else {
        (0.0, 0.0)
    };

    // Spacing ratios
    let ratios = cathedral_utils::spectral_stats::spacing_ratios(&eigenvalues);
    let r_mean = if ratios.is_empty() {
        0.0
    } else {
        ratios.iter().sum::<f64>() / ratios.len() as f64
    };
    let (ensemble, _) = cathedral_utils::spectral_stats::classify_ensemble(r_mean);

    // Coprimality fraction
    let coprime_frac = coprimality_fraction(dim);

    // Euler polynomial primality count
    let euler_primes = (1..=dim as i64)
        .filter(|&n| {
            let e = euler_poly(n);
            e > 0 && is_prime(e as u64)
        })
        .count();

    // Print summary
    eprintln!("    λ_min     = {:.6e}", eigenvalues[0]);
    eprintln!("    λ_max     = {:.6e}", lambda_max);
    eprintln!("    κ         = {:.6e}", kappa);
    eprintln!(
        "    log|det|  = {:.6e} (sign={})",
        log_det,
        if det_sign > 0 { "+" } else { "-" }
    );
    eprintln!("    Tr        = {:.6e}", trace);
    eprintln!("    ‖G‖_F     = {:.6e}", frobenius);
    eprintln!(
        "    S_spec    = {:.4} (eff_rank = {:.1})",
        spectral_entropy, eff_rank
    );
    eprintln!("    ⟨r⟩       = {:.4} → {}", r_mean, ensemble);
    eprintln!("    Coprime%  = {:.2}%", coprime_frac * 100.0);
    eprintln!(
        "    Euler E(1..{dim}) primes: {euler_primes}/{dim} ({:.1}%)",
        euler_primes as f64 / dim as f64 * 100.0
    );

    // Print eigenvalue spectrum (up to 20 values)
    let show = dim.min(20);
    eprintln!("    Eigenvalues (bottom {show}):");
    for (i, _eigenvalue) in eigenvalues.iter().enumerate().take(show) {
        let marker = if i == 0 { " ← min" } else { "" };
        eprintln!("      λ_{i:>3} = {:.10e}{}", eigenvalues[i], marker);
    }
    eprintln!();

    HeegnerResult {
        dim,
        is_heegner,
        lambda_min,
        lambda_max,
        kappa,
        log_det,
        det_sign,
        trace,
        frobenius,
        spectral_entropy,
        eff_rank,
        r_mean,
        ensemble: ensemble.to_string(),
        coprime_frac,
        euler_primes,
        build_time,
        eigen_time,
    }
}

fn main() {
    let t_total = Instant::now();

    eprintln!("═══════════════════════════════════════════════════════════════");
    eprintln!("  🔮 HEEGNER PROBE — The Deep Lore of the Dark Crystal");
    eprintln!("═══════════════════════════════════════════════════════════════");
    eprintln!();
    eprintln!("  The 9 Heegner numbers: {:?}", HEEGNER);
    eprintln!("  Connection: Euler's E(n) = n² - n + 41  (disc = -163)");
    eprintln!("              Dark B₂(x) = x² - x + 1/6   (same spine)");
    eprintln!();

    // ── Part 1: Euler's prime-generating polynomial ────────────
    eprintln!("═══════════════════════════════════════════════════════════════");
    eprintln!("  §1. EULER'S PRIME ENGINE: E(n) = n² - n + 41");
    eprintln!("═══════════════════════════════════════════════════════════════");
    eprintln!();

    let mut prime_streak = 0usize;
    for n in 1..=200i64 {
        let e = euler_poly(n);
        let p = is_prime(e as u64);
        if n <= 45 || HEEGNER.contains(&(n as usize)) {
            let marker = if p { "✓ PRIME" } else { "✗ composite" };
            let heeg = if HEEGNER.contains(&(n as usize)) {
                " ★"
            } else {
                ""
            };
            eprintln!("    E({n:>3}) = {e:>6}  {marker}{heeg}");
        }
        if p && prime_streak == (n as usize - 1) {
            prime_streak = n as usize;
        }
    }
    eprintln!();
    eprintln!("    First composite: E(41) = {} = 41²", euler_poly(41));
    eprintln!("    Longest prime streak from E(1): {prime_streak} consecutive primes");
    eprintln!();

    // ── Part 2: Dark Gram at Heegner dimensions ────────────────
    eprintln!("═══════════════════════════════════════════════════════════════");
    eprintln!("  §2. DARK GRAM SPECTROSCOPY AT HEEGNER DIMENSIONS");
    eprintln!("═══════════════════════════════════════════════════════════════");
    eprintln!();

    // For each Heegner number, probe it and its neighbors
    let mut all_results: Vec<HeegnerResult> = Vec::new();

    // Build dimension schedule: each Heegner number + neighbors
    let mut dims_to_probe: Vec<usize> = Vec::new();
    for &h in &HEEGNER {
        // Skip N=1 (degenerate 1×1 matrix)
        if h < 3 {
            if h >= 2 {
                dims_to_probe.push(h);
            }
            continue;
        }
        for offset in [-2i64, -1, 0, 1, 2] {
            let d = h as i64 + offset;
            if d >= 2 && !dims_to_probe.contains(&(d as usize)) {
                dims_to_probe.push(d as usize);
            }
        }
    }
    dims_to_probe.sort();
    dims_to_probe.dedup();

    eprintln!(
        "  Probing {} dimensions: {:?}",
        dims_to_probe.len(),
        dims_to_probe
    );
    eprintln!();

    // Output TSV header
    println!("dim\theegner\tlambda_min\tlambda_max\tkappa\tlog_det\tdet_sign\ttrace\tfrobenius\tspectral_entropy\teff_rank\tr_mean\tensemble\tcoprime_pct\teuler_primes\teuler_prime_pct\tbuild_s\teigen_s");

    for &dim in &dims_to_probe {
        let result = analyze_heegner_dim(dim);

        println!("{}\t{}\t{:.10e}\t{:.10e}\t{:.6e}\t{:.6e}\t{}\t{:.10e}\t{:.10e}\t{:.6}\t{:.1}\t{:.4}\t{}\t{:.4}\t{}\t{:.4}\t{:.3}\t{:.3}",
            result.dim,
            if result.is_heegner { "YES" } else { "no" },
            result.lambda_min,
            result.lambda_max,
            result.kappa,
            result.log_det,
            result.det_sign,
            result.trace,
            result.frobenius,
            result.spectral_entropy,
            result.eff_rank,
            result.r_mean,
            result.ensemble,
            result.coprime_frac * 100.0,
            result.euler_primes,
            result.euler_primes as f64 / result.dim as f64 * 100.0,
            result.build_time,
            result.eigen_time,
        );

        all_results.push(result);
    }

    // ── Part 3: Comparative Analysis ───────────────────────────
    eprintln!();
    eprintln!("═══════════════════════════════════════════════════════════════");
    eprintln!("  §3. HEEGNER vs NON-HEEGNER COMPARISON");
    eprintln!("═══════════════════════════════════════════════════════════════");
    eprintln!();

    let heegner_results: Vec<&HeegnerResult> =
        all_results.iter().filter(|r| r.is_heegner).collect();
    let non_heegner_results: Vec<&HeegnerResult> =
        all_results.iter().filter(|r| !r.is_heegner).collect();

    if !heegner_results.is_empty() && !non_heegner_results.is_empty() {
        let h_kappa_avg: f64 =
            heegner_results.iter().map(|r| r.kappa).sum::<f64>() / heegner_results.len() as f64;
        let nh_kappa_avg: f64 = non_heegner_results.iter().map(|r| r.kappa).sum::<f64>()
            / non_heegner_results.len() as f64;

        let h_entropy_avg: f64 = heegner_results
            .iter()
            .map(|r| r.spectral_entropy)
            .sum::<f64>()
            / heegner_results.len() as f64;
        let nh_entropy_avg: f64 = non_heegner_results
            .iter()
            .map(|r| r.spectral_entropy)
            .sum::<f64>()
            / non_heegner_results.len() as f64;

        let h_coprime_avg: f64 = heegner_results.iter().map(|r| r.coprime_frac).sum::<f64>()
            / heegner_results.len() as f64;
        let nh_coprime_avg: f64 = non_heegner_results
            .iter()
            .map(|r| r.coprime_frac)
            .sum::<f64>()
            / non_heegner_results.len() as f64;

        eprintln!("  ┌─────────────────────────┬──────────────┬──────────────┐");
        eprintln!("  │ Metric                  │   Heegner    │ Non-Heegner  │");
        eprintln!("  ├─────────────────────────┼──────────────┼──────────────┤");
        eprintln!("  │ Avg κ (condition #)     │ {h_kappa_avg:>12.4e} │ {nh_kappa_avg:>12.4e} │");
        eprintln!("  │ Avg S (spectral entropy)│ {h_entropy_avg:>12.4} │ {nh_entropy_avg:>12.4} │");
        eprintln!(
            "  │ Avg coprime fraction    │ {h_coprime_avg:>11.4}% │ {nh_coprime_avg:>11.4}% │"
        );
        eprintln!("  └─────────────────────────┴──────────────┴──────────────┘");
    }

    // ── Part 4: The 41 Connection ──────────────────────────────
    eprintln!();
    eprintln!("═══════════════════════════════════════════════════════════════");
    eprintln!("  §4. THE 41 CONNECTION — EULER MEETS THE DARK CRYSTAL");
    eprintln!("═══════════════════════════════════════════════════════════════");
    eprintln!();

    // At dim=41, the Euler polynomial breaks. What does the Dark Gram do?
    let dim41 = analyze_heegner_dim(41);
    let dim40 = if all_results.iter().any(|r| r.dim == 40) {
        None // already computed
    } else {
        Some(analyze_heegner_dim(40))
    };
    let dim42 = if all_results.iter().any(|r| r.dim == 42) {
        None
    } else {
        Some(analyze_heegner_dim(42))
    };

    eprintln!("  At N=41 (Euler's breaking point):");
    eprintln!("    κ  = {:.6e}", dim41.kappa);
    eprintln!(
        "    Euler primes: {}/{} ({:.1}%)",
        dim41.euler_primes,
        dim41.dim,
        dim41.euler_primes as f64 / dim41.dim as f64 * 100.0
    );
    if let Some(ref r40) = dim40 {
        eprintln!("  At N=40 (last Euler prime):");
        eprintln!("    κ  = {:.6e}", r40.kappa);
    }
    if let Some(ref r42) = dim42 {
        eprintln!("  At N=42 (post-Euler):");
        eprintln!("    κ  = {:.6e}", r42.kappa);
    }

    // ── Part 5: Ramanujan's Constant ───────────────────────────
    eprintln!();
    eprintln!("═══════════════════════════════════════════════════════════════");
    eprintln!("  §5. RAMANUJAN'S CONSTANT AND THE DARK DETERMINANT");
    eprintln!("═══════════════════════════════════════════════════════════════");
    eprintln!();

    let ramanujan = std::f64::consts::E.powf(std::f64::consts::PI * 163.0_f64.sqrt());
    let ram_nearest_int = ramanujan.round();
    let ram_error = (ramanujan - ram_nearest_int).abs();
    eprintln!("  e^(π√163) = {:.15e}", ramanujan);
    eprintln!("  Nearest integer: {:.0}", ram_nearest_int);
    eprintln!(
        "  |error|   = {:.2e}  (the famous 'almost integer')",
        ram_error
    );
    eprintln!();

    // Check if any eigenvalue ratio relates to 163
    if let Some(h163) = all_results.iter().find(|r| r.dim == 163) {
        eprintln!("  At N=163 (the largest Heegner number):");
        eprintln!("    λ_max/λ_min = {:.6e}", h163.kappa);
        eprintln!("    log|det|    = {:.6e}", h163.log_det);
        eprintln!(
            "    Tr/dim      = {:.10e} (should be 1/180)",
            h163.trace / 163.0
        );
        eprintln!("    Coprime%    = {:.2}%", h163.coprime_frac * 100.0);
    }

    eprintln!();
    eprintln!("═══════════════════════════════════════════════════════════════");
    eprintln!(
        "  🔮 HEEGNER PROBE complete ({:.1}s)",
        t_total.elapsed().as_secs_f64()
    );
    eprintln!("═══════════════════════════════════════════════════════════════");
}
