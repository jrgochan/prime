#![allow(unused, dead_code, non_snake_case)]
use rayon::prelude::*;
use std::f64::consts::PI;

// ══════════════════════════════════════════════════════════════════════
// LIOUVILLE PHASE ENRICHMENT EXPERIMENT
//
// The standard Gram matrix G_N is real symmetric → GOE (β=1).
// The zeta zeros are GUE (β=2). Can we bridge this gap?
//
// STRATEGY: Add arithmetic phase structure to the basis functions
// to break time-reversal symmetry, shifting GOE → GUE.
//
// Three enrichment schemes:
//
// 1. FOURIER PHASE:
//    G^ℂ_{jk} = ∫₀¹ {j/x}·{k/x}·e^{iα(j-k)/x} dx
//    → Complex Hermitian. The phase e^{iα(j-k)/x} oscillates differently
//    for different (j,k) pairs, breaking the real structure.
//
// 2. LOG-ARITHMETIC PHASE:
//    G^ℂ_{jk} = ∫₀¹ {j/x}·{k/x}·e^{iα·ln(j/k)·x} dx
//    → Phase depends on the ratio j/k, connecting to the multiplicative
//    structure of integers (Dirichlet characters, Mellin transform).
//
// 3. PRIME-WEIGHTED PHASE:
//    G^ℂ_{jk} = ∫₀¹ {j/x}·{k/x}·e^{iα(Ω(j)-Ω(k))·x} dx
//    → Phase breaks symmetry based on the number of prime factors.
//    Ω(k) connects directly to the Liouville function λ(k)=(-1)^Ω(k).
//
// For each: compute eigenvalues (real, since Hermitian) and test
// the ratio distribution ⟨r⟩ to determine if GUE is achieved.
// ══════════════════════════════════════════════════════════════════════

fn frac_part(x: f64) -> f64 {
    x - x.floor()
}

/// Count prime factors with multiplicity: Ω(n)
fn big_omega(n: usize) -> usize {
    if n <= 1 {
        return 0;
    }
    let mut count = 0;
    let mut m = n;
    let mut p = 2;
    while p * p <= m {
        while m.is_multiple_of(p) {
            count += 1;
            m /= p;
        }
        p += 1;
    }
    if m > 1 {
        count += 1;
    }
    count
}

/// Liouville function λ(n) = (-1)^Ω(n)
fn liouville(n: usize) -> f64 {
    if big_omega(n).is_multiple_of(2) {
        1.0
    } else {
        -1.0
    }
}

// ══════════════════════════════════════════════════════════════════════
// COMPLEX GRAM MATRIX COMPUTATION
// ══════════════════════════════════════════════════════════════════════

/// Standard real Gram entry G[j,k] = ∫₀¹ {j/x}{k/x} dx
fn gram_entry_real(j: usize, k: usize, n_pts: usize) -> f64 {
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

/// Complex Gram entry with Fourier phase:
/// G^ℂ[j,k] = ∫₀¹ {j/x}·{k/x}·e^{iα(j-k)/x} dx
/// Returns (Re, Im)
fn gram_entry_fourier(j: usize, k: usize, alpha: f64, n_pts: usize) -> (f64, f64) {
    let jf = j as f64;
    let kf = k as f64;
    let diff = (j as f64 - k as f64) * alpha;
    let dx = 1.0 / n_pts as f64;
    let mut sum_re = 0.0f64;
    let mut sum_im = 0.0f64;
    for i in 0..n_pts {
        let x = (i as f64 + 0.5) * dx;
        let base = frac_part(jf / x) * frac_part(kf / x);
        let phase = diff / x;
        sum_re += base * phase.cos();
        sum_im += base * phase.sin();
    }
    (sum_re * dx, sum_im * dx)
}

/// Complex Gram entry with log-arithmetic phase:
/// G^ℂ[j,k] = ∫₀¹ {j/x}·{k/x}·e^{iα·ln(j/k)·x} dx
/// Returns (Re, Im)
fn gram_entry_log(j: usize, k: usize, alpha: f64, n_pts: usize) -> (f64, f64) {
    let jf = j as f64;
    let kf = k as f64;
    let log_ratio = (jf / kf).ln() * alpha;
    let dx = 1.0 / n_pts as f64;
    let mut sum_re = 0.0f64;
    let mut sum_im = 0.0f64;
    for i in 0..n_pts {
        let x = (i as f64 + 0.5) * dx;
        let base = frac_part(jf / x) * frac_part(kf / x);
        let phase = log_ratio * x;
        sum_re += base * phase.cos();
        sum_im += base * phase.sin();
    }
    (sum_re * dx, sum_im * dx)
}

/// Complex Gram entry with Ω-phase (prime factor count phase):
/// G^ℂ[j,k] = ∫₀¹ {j/x}·{k/x}·e^{iα(Ω(j)-Ω(k))·{j·k/x}} dx
/// Returns (Re, Im)
fn gram_entry_omega(
    j: usize,
    k: usize,
    omega_j: usize,
    omega_k: usize,
    alpha: f64,
    n_pts: usize,
) -> (f64, f64) {
    let jf = j as f64;
    let kf = k as f64;
    let omega_diff = (omega_j as f64 - omega_k as f64) * alpha;
    let dx = 1.0 / n_pts as f64;
    let mut sum_re = 0.0f64;
    let mut sum_im = 0.0f64;
    for i in 0..n_pts {
        let x = (i as f64 + 0.5) * dx;
        let base = frac_part(jf / x) * frac_part(kf / x);
        let phase = omega_diff * frac_part(jf * kf / x);
        sum_re += base * phase.cos();
        sum_im += base * phase.sin();
    }
    (sum_re * dx, sum_im * dx)
}

// ══════════════════════════════════════════════════════════════════════
// COMPLEX HERMITIAN → 2n×2n REAL SYMMETRIC EMBEDDING
//
// For a complex Hermitian matrix H = A + iB (A symmetric, B antisymmetric):
//   M = [[A, -B], [B, A]]
// M is a 2n×2n real symmetric matrix whose eigenvalues are those of H,
// each with multiplicity 2.
// ══════════════════════════════════════════════════════════════════════

fn embed_hermitian(re: &[Vec<f64>], im: &[Vec<f64>]) -> Vec<Vec<f64>> {
    let n = re.len();
    let m = 2 * n;
    let mut result = vec![vec![0.0; m]; m];

    for i in 0..n {
        for j in 0..n {
            // Top-left: A (real part)
            result[i][j] = re[i][j];
            // Top-right: -B (negative imaginary part)
            result[i][n + j] = -im[i][j];
            // Bottom-left: B (imaginary part)
            result[n + i][j] = im[i][j];
            // Bottom-right: A (real part)
            result[n + i][n + j] = re[i][j];
        }
    }

    result
}

// ══════════════════════════════════════════════════════════════════════
// JACOBI EIGENVALUE ALGORITHM
// ══════════════════════════════════════════════════════════════════════

fn jacobi_eigenvalues_cyclic(mat: &[Vec<f64>], max_sweeps: usize, tol: f64) -> Vec<f64> {
    let n = mat.len();
    let mut a: Vec<Vec<f64>> = mat.to_vec();

    for _sweep in 0..max_sweeps {
        let mut max_off = 0.0f64;
        for i in 0..n {
            for j in (i + 1)..n {
                max_off = max_off.max(a[i][j].abs());
            }
        }
        if max_off < tol {
            break;
        }

        for p in 0..n {
            for q in (p + 1)..n {
                if a[p][q].abs() < tol * 0.01 {
                    continue;
                }

                let app = a[p][p];
                let aqq = a[q][q];
                let apq = a[p][q];

                let theta = if (app - aqq).abs() < 1e-30 {
                    PI / 4.0
                } else {
                    0.5 * (2.0 * apq / (app - aqq)).atan()
                };

                let c = theta.cos();
                let s = theta.sin();

                for i in 0..n {
                    if i != p && i != q {
                        let aip = a[i][p];
                        let aiq = a[i][q];
                        a[i][p] = c * aip + s * aiq;
                        a[p][i] = a[i][p];
                        a[i][q] = -s * aip + c * aiq;
                        a[q][i] = a[i][q];
                    }
                }

                a[p][p] = c * c * app + 2.0 * s * c * apq + s * s * aqq;
                a[q][q] = s * s * app - 2.0 * s * c * apq + c * c * aqq;
                a[p][q] = 0.0;
                a[q][p] = 0.0;
            }
        }
    }

    let mut eigenvalues: Vec<f64> = (0..n).map(|i| a[i][i]).collect();
    eigenvalues.sort_by(|a, b| a.partial_cmp(b).unwrap());
    eigenvalues
}

/// Extract distinct eigenvalues from 2n×2n embedding (removes Kramers pairs)
fn extract_distinct(eigenvalues: &[f64], tol: f64) -> Vec<f64> {
    let mut distinct = Vec::new();
    let mut i = 0;
    while i < eigenvalues.len() {
        distinct.push(eigenvalues[i]);
        // Skip the duplicate
        if i + 1 < eigenvalues.len() && (eigenvalues[i + 1] - eigenvalues[i]).abs() < tol {
            i += 2;
        } else {
            i += 1;
        }
    }
    distinct
}

// ══════════════════════════════════════════════════════════════════════
// RATIO TEST
// ══════════════════════════════════════════════════════════════════════

fn compute_ratios(eigenvalues: &[f64]) -> Vec<f64> {
    let n = eigenvalues.len();
    if n < 3 {
        return vec![];
    }
    let mut ratios = Vec::with_capacity(n - 2);
    for i in 0..(n - 2) {
        let s1 = eigenvalues[i + 1] - eigenvalues[i];
        let s2 = eigenvalues[i + 2] - eigenvalues[i + 1];
        if s1 > 1e-15 && s2 > 1e-15 {
            let r = s1.min(s2) / s1.max(s2);
            ratios.push(r);
        }
    }
    ratios
}

fn ratio_mean(eigenvalues: &[f64]) -> f64 {
    let ratios = compute_ratios(eigenvalues);
    if ratios.is_empty() {
        return 0.0;
    }
    ratios.iter().sum::<f64>() / ratios.len() as f64
}

fn classify_beta(r_mean: f64) -> (&'static str, f64) {
    let fits = [("Poisson", 0.3863),
        ("GOE (β=1)", 0.5307),
        ("GUE (β=2)", 0.5996),
        ("GSE (β=4)", 0.6744)];
    let best = fits
        .iter()
        .min_by(|a, b| {
            (r_mean - a.1)
                .abs()
                .partial_cmp(&(r_mean - b.1).abs())
                .unwrap()
        })
        .unwrap();
    (best.0, (r_mean - best.1).abs())
}

fn estimate_beta(r_mean: f64) -> f64 {
    if r_mean < 0.4 {
        0.0
    } else if r_mean < 0.54 {
        (r_mean - 0.3863) / (0.5307 - 0.3863)
    } else if r_mean < 0.64 {
        1.0 + (r_mean - 0.5307) / (0.5996 - 0.5307)
    } else {
        2.0 + 2.0 * (r_mean - 0.5996) / (0.6744 - 0.5996)
    }
}

// ══════════════════════════════════════════════════════════════════════
// MAIN
// ══════════════════════════════════════════════════════════════════════

fn main() {
    println!("╔══════════════════════════════════════════════════════════════════╗");
    println!("║  LIOUVILLE PHASE ENRICHMENT: Breaking Time-Reversal Symmetry   ║");
    println!("║  Can we shift the Gram matrix from GOE → GUE?                  ║");
    println!("╚══════════════════════════════════════════════════════════════════╝\n");

    let total_start = std::time::Instant::now();
    let n_pts = 150_000;
    let max_n = 150; // Keep moderate for the 2n×2n embedding
    let dim = max_n - 1;

    // Precompute Ω values
    let omegas: Vec<usize> = (0..=max_n + 1).map(big_omega).collect();
    println!("  Liouville signs for k = 2..20:");
    print!("    ");
    for k in 2..=20 {
        print!("λ({})={:+}  ", k, liouville(k) as i32);
    }
    println!("\n");

    // ──── Phase 1: Baseline — Real Gram Matrix (GOE expected) ────
    println!("═══════════════════════════════════════════════════════════════");
    println!("  BASELINE: Real Gram Matrix G_N (N = {})", max_n);
    println!("═══════════════════════════════════════════════════════════════\n");

    print!("  Computing {}×{} real Gram matrix... ", dim, dim);
    let start = std::time::Instant::now();
    let gram_upper: Vec<Vec<f64>> = (0..dim)
        .into_par_iter()
        .map(|j| {
            let mut row = vec![0.0; dim];
            for k in j..dim {
                row[k] = gram_entry_real(j + 2, k + 2, n_pts);
            }
            row
        })
        .collect();
    let mut gram_real = vec![vec![0.0; dim]; dim];
    for j in 0..dim {
        for k in j..dim {
            gram_real[j][k] = gram_upper[j][k];
            gram_real[k][j] = gram_upper[j][k];
        }
    }
    println!("{:.1}s", start.elapsed().as_secs_f64());

    print!("  Computing eigenvalues (Jacobi)... ");
    let start = std::time::Instant::now();
    let eigs_real = jacobi_eigenvalues_cyclic(&gram_real, 200, 1e-12);
    println!("{:.1}s", start.elapsed().as_secs_f64());

    let r_real = ratio_mean(&eigs_real);
    let (class_real, delta_real) = classify_beta(r_real);
    let beta_real = estimate_beta(r_real);
    println!(
        "  ⟨r⟩ = {:.6} → {} (Δ = {:.6}, β ≈ {:.2})",
        r_real, class_real, delta_real, beta_real
    );

    // ──── Phase 2: Fourier Phase Enrichment ────
    println!("\n═══════════════════════════════════════════════════════════════");
    println!("  SCHEME 1: Fourier Phase — G^ℂ[j,k] = ∫ {{j/x}}{{k/x}} e^{{iα(j-k)/x}} dx");
    println!("═══════════════════════════════════════════════════════════════\n");

    let alphas = vec![0.01, 0.05, 0.1, 0.2, 0.5, 1.0, 2.0, PI];

    println!(
        "  {:>8} {:>10} {:>14} {:>10} {:>12}",
        "α", "⟨r⟩", "Classification", "Δ from GOE", "β estimate"
    );
    println!("  {}", "─".repeat(60));

    // Baseline
    println!(
        "  {:>8} {:>10.6} {:>14} {:>10.6} {:>12.3}",
        "0 (real)",
        r_real,
        class_real,
        (r_real - 0.5307).abs(),
        beta_real
    );

    for &alpha in &alphas {
        print!("  Computing α = {:.2}... ", alpha);
        std::io::Write::flush(&mut std::io::stdout()).ok();
        let start = std::time::Instant::now();

        // Compute complex Gram matrix
        let mut gram_re = vec![vec![0.0; dim]; dim];
        let mut gram_im = vec![vec![0.0; dim]; dim];

        // Parallel computation of upper triangle
        let entries: Vec<((usize, usize), (f64, f64))> = (0..dim)
            .into_par_iter()
            .flat_map(|j| {
                (j..dim).into_par_iter().map(move |k| {
                    let (re, im) = gram_entry_fourier(j + 2, k + 2, alpha, n_pts);
                    ((j, k), (re, im))
                })
            })
            .collect();

        for ((j, k), (re, im)) in entries {
            gram_re[j][k] = re;
            gram_re[k][j] = re; // Hermitian: Re symmetric
            gram_im[j][k] = im;
            gram_im[k][j] = -im; // Hermitian: Im antisymmetric
        }

        // Embed as 2n×2n real symmetric
        let embedded = embed_hermitian(&gram_re, &gram_im);
        let eigs_2n = jacobi_eigenvalues_cyclic(&embedded, 200, 1e-12);

        // Extract distinct eigenvalues (remove Kramers pairs)
        let eigs = extract_distinct(&eigs_2n, 1e-8);

        let r_val = ratio_mean(&eigs);
        let (class, delta) = classify_beta(r_val);
        let beta = estimate_beta(r_val);
        let time = start.elapsed().as_secs_f64();

        println!(
            "\r  {:>8.3} {:>10.6} {:>14} {:>10.6} {:>12.3}  ({:.1}s, {} eigvals)",
            alpha,
            r_val,
            class,
            delta,
            beta,
            time,
            eigs.len()
        );
    }

    // ──── Phase 3: Log-Arithmetic Phase ────
    println!("\n═══════════════════════════════════════════════════════════════");
    println!("  SCHEME 2: Log-Arithmetic Phase — e^{{iα·ln(j/k)·x}}");
    println!("  (Connected to Mellin transform & Dirichlet series)");
    println!("═══════════════════════════════════════════════════════════════\n");

    let log_alphas = vec![0.1, 0.5, 1.0, 2.0, 5.0, 10.0];

    println!(
        "  {:>8} {:>10} {:>14} {:>10} {:>12}",
        "α", "⟨r⟩", "Classification", "Δ from GUE", "β estimate"
    );
    println!("  {}", "─".repeat(60));

    for &alpha in &log_alphas {
        print!("  Computing α = {:.1}... ", alpha);
        std::io::Write::flush(&mut std::io::stdout()).ok();
        let start = std::time::Instant::now();

        let entries: Vec<((usize, usize), (f64, f64))> = (0..dim)
            .into_par_iter()
            .flat_map(|j| {
                (j..dim).into_par_iter().map(move |k| {
                    let (re, im) = gram_entry_log(j + 2, k + 2, alpha, n_pts);
                    ((j, k), (re, im))
                })
            })
            .collect();

        let mut gram_re = vec![vec![0.0; dim]; dim];
        let mut gram_im = vec![vec![0.0; dim]; dim];
        for ((j, k), (re, im)) in entries {
            gram_re[j][k] = re;
            gram_re[k][j] = re;
            gram_im[j][k] = im;
            gram_im[k][j] = -im;
        }

        let embedded = embed_hermitian(&gram_re, &gram_im);
        let eigs_2n = jacobi_eigenvalues_cyclic(&embedded, 200, 1e-12);
        let eigs = extract_distinct(&eigs_2n, 1e-8);

        let r_val = ratio_mean(&eigs);
        let (class, delta) = classify_beta(r_val);
        let beta = estimate_beta(r_val);
        let time = start.elapsed().as_secs_f64();

        println!(
            "\r  {:>8.1} {:>10.6} {:>14} {:>10.6} {:>12.3}  ({:.1}s)",
            alpha,
            r_val,
            class,
            (r_val - 0.5996).abs(),
            beta,
            time
        );
    }

    // ──── Phase 4: Ω-Phase (Prime Factor Count) ────
    println!("\n═══════════════════════════════════════════════════════════════");
    println!("  SCHEME 3: Ω-Phase — e^{{iα(Ω(j)-Ω(k))·{{jk/x}}}}");
    println!("  (Liouville-connected: Ω encodes the sign structure)");
    println!("═══════════════════════════════════════════════════════════════\n");

    let omega_alphas = vec![0.1, 0.5, 1.0, PI / 2.0, PI, 2.0 * PI];

    println!(
        "  {:>8} {:>10} {:>14} {:>10} {:>12}",
        "α", "⟨r⟩", "Classification", "Δ from GUE", "β estimate"
    );
    println!("  {}", "─".repeat(60));

    for &alpha in &omega_alphas {
        print!("  Computing α = {:.3}... ", alpha);
        std::io::Write::flush(&mut std::io::stdout()).ok();
        let start = std::time::Instant::now();

        let omegas_ref = &omegas;
        let entries: Vec<((usize, usize), (f64, f64))> = (0..dim)
            .into_par_iter()
            .flat_map(|j| {
                let oj = omegas_ref[j + 2];
                (j..dim).into_par_iter().map(move |k| {
                    let ok = big_omega(k + 2);
                    let (re, im) = gram_entry_omega(j + 2, k + 2, oj, ok, alpha, n_pts);
                    ((j, k), (re, im))
                })
            })
            .collect();

        let mut gram_re = vec![vec![0.0; dim]; dim];
        let mut gram_im = vec![vec![0.0; dim]; dim];
        for ((j, k), (re, im)) in entries {
            gram_re[j][k] = re;
            gram_re[k][j] = re;
            gram_im[j][k] = im;
            gram_im[k][j] = -im;
        }

        let embedded = embed_hermitian(&gram_re, &gram_im);
        let eigs_2n = jacobi_eigenvalues_cyclic(&embedded, 200, 1e-12);
        let eigs = extract_distinct(&eigs_2n, 1e-8);

        let r_val = ratio_mean(&eigs);
        let (class, _delta) = classify_beta(r_val);
        let beta = estimate_beta(r_val);
        let time = start.elapsed().as_secs_f64();

        println!(
            "\r  {:>8.3} {:>10.6} {:>14} {:>10.6} {:>12.3}  ({:.1}s)",
            alpha,
            r_val,
            class,
            (r_val - 0.5996).abs(),
            beta,
            time
        );
    }

    // ──── Phase 5: SPECTRAL GAP COMPARISON ────
    println!("\n═══════════════════════════════════════════════════════════════");
    println!("  SPECTRAL GAP ANALYSIS: λ_min under enrichment");
    println!("═══════════════════════════════════════════════════════════════\n");

    println!("  Does phase enrichment preserve the spectral gap?\n");
    println!(
        "  {:>20} {:>12} {:>12} {:>12}",
        "Scheme", "λ_min", "λ_max", "Gap ratio"
    );
    println!("  {}", "─".repeat(60));

    println!(
        "  {:>20} {:>12.8} {:>12.4} {:>12.6}",
        "Real (baseline)",
        eigs_real[0],
        eigs_real[dim - 1],
        eigs_real[0] / eigs_real[dim - 1]
    );

    // Compute a representative enriched matrix for gap analysis
    for &(name, alpha) in &[
        ("Fourier α=0.1", 0.1f64),
        ("Fourier α=1.0", 1.0),
        ("Log α=1.0", -1.0),
    ] {
        let entries: Vec<((usize, usize), (f64, f64))> = (0..dim)
            .into_par_iter()
            .flat_map(|j| {
                (j..dim).into_par_iter().map(move |k| {
                    if alpha > 0.0 {
                        let (re, im) = gram_entry_fourier(j + 2, k + 2, alpha, n_pts);
                        ((j, k), (re, im))
                    } else {
                        let (re, im) = gram_entry_log(j + 2, k + 2, -alpha, n_pts);
                        ((j, k), (re, im))
                    }
                })
            })
            .collect();

        let mut gre = vec![vec![0.0; dim]; dim];
        let mut gim = vec![vec![0.0; dim]; dim];
        for ((j, k), (re, im)) in entries {
            gre[j][k] = re;
            gre[k][j] = re;
            gim[j][k] = im;
            gim[k][j] = -im;
        }
        let emb = embed_hermitian(&gre, &gim);
        let ev = jacobi_eigenvalues_cyclic(&emb, 200, 1e-12);
        let ev_d = extract_distinct(&ev, 1e-8);

        if !ev_d.is_empty() {
            println!(
                "  {:>20} {:>12.8} {:>12.4} {:>12.6}",
                name,
                ev_d[0],
                ev_d[ev_d.len() - 1],
                ev_d[0] / ev_d[ev_d.len() - 1]
            );
        }
    }

    // ──── Final Verdict ────
    println!("\n╔══════════════════════════════════════════════════════════════════╗");
    println!("║              LIOUVILLE PHASE ENRICHMENT VERDICT                 ║");
    println!("╠══════════════════════════════════════════════════════════════════╣");
    println!("║                                                                ║");
    println!("║  Baseline (real):  GOE (β≈1)   ← time-reversal symmetric      ║");
    println!("║                                                                ║");
    println!("║  Q: Does adding arithmetic phase shift the statistics?         ║");
    println!("║  Q: Is the spectral gap preserved under enrichment?            ║");
    println!("║  Q: Can we reach GUE (β≈2) — the universality class of ζ?     ║");
    println!("║                                                                ║");
    println!("║  If GUE is reached with spectral gap preserved:                ║");
    println!("║    → The enriched Gram matrix is a spectral realization        ║");
    println!("║    → HYPERZETA in the enriched space → RH                      ║");
    println!("║                                                                ║");
    println!("╚══════════════════════════════════════════════════════════════════╝");

    println!(
        "\n  Total computation time: {:.1}s\n",
        total_start.elapsed().as_secs_f64()
    );
}
