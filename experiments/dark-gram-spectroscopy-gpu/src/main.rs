//! ═══════════════════════════════════════════════════════════════════════════
//!  DARK GRAM SPECTROSCOPY v1 — GPU ACCELERATED
//!  The Antimatter Engine on RTX 4090 / cuSOLVER
//!
//!  Computes the Dark Gram matrix G^(n) at Bernoulli order n and performs
//!  full spectral analysis using GPU-accelerated eigendecomposition.
//!
//!  KEY FORMULA (n=2):
//!    G^(2)_{j,k} = gcd(j,k)⁴ / (180 · j² · k²)
//!
//!  Usage:
//!    cargo run --release --bin dark-gram-spectroscopy-gpu
//!    cargo run --release --bin dark-gram-spectroscopy-gpu -- --max-dim 50000
//!    cargo run --release --bin dark-gram-spectroscopy-gpu -- --orders 2,4 --dims 20000,50000
//! ═══════════════════════════════════════════════════════════════════════════

mod gpu;

use std::time::Instant;
use clap::Parser;
use rayon::prelude::*;

#[derive(Parser)]
#[command(name = "dark-gram-spectroscopy-gpu", about = "Dark Gram Matrix — GPU spectral analysis")]
struct Cli {
    /// Bernoulli orders to test (comma-separated)
    #[arg(long, value_delimiter = ',', default_value = "2")]
    orders: Vec<usize>,

    /// Matrix dimensions to test (comma-separated)
    #[arg(long, value_delimiter = ',', default_value = "5040,10080,20000")]
    dims: Vec<usize>,

    /// Maximum dimension (overrides dims if set)
    #[arg(long)]
    max_dim: Option<usize>,

    /// Output TSV file
    #[arg(long, default_value = "dark_gram_gpu.tsv")]
    output: String,

    /// Use Lanczos OOC mode (matrix-free, no memory limit)
    #[arg(long)]
    lanczos: bool,

    /// Number of extreme eigenvalues to extract via Lanczos (default: 20)
    #[arg(long, default_value = "20")]
    lanczos_k: usize,

    /// Lanczos subspace dimension (default: 200)
    #[arg(long, default_value = "200")]
    lanczos_m: usize,
}

fn main() {
    let cli = Cli::parse();
    let t_total = Instant::now();

    eprintln!("═══════════════════════════════════════════════════════════════");
    eprintln!("  🪞 DARK GRAM SPECTROSCOPY v1 — GPU Antimatter Engine");
    eprintln!("═══════════════════════════════════════════════════════════════");
    eprintln!();

    // Detect GPU
    if let Some(info) = gpu::detect_gpu() {
        eprintln!("  GPU: {} ({} MB VRAM)", info.name, info.vram_mb);
    } else {
        eprintln!("  ⚠ No GPU detected — will use CPU fallback");
    }

    let dims = if let Some(max_dim) = cli.max_dim {
        let hc = vec![
            12, 24, 60, 120, 240, 360, 720, 1000, 2520, 5040,
            10080, 15120, 20000, 25200, 30000, 40000, 50000,
        ];
        hc.into_iter().filter(|&d| d <= max_dim).collect()
    } else {
        cli.dims.clone()
    };

    eprintln!("  Orders:     {:?}", cli.orders);
    eprintln!("  Dimensions: {:?}", dims);
    eprintln!();

    // Header
    println!("order\tdim\tlambda_min\tlambda_max\tkappa\tr_mean\tensemble\tdecay_type\teff_rank\ttrace\tfrobenius\tdiag_min\tdiag_max\tbuild_s\teigen_s");

    // Main sweep
    for &n in &cli.orders {
        for &dim in &dims {
            let result = if cli.lanczos {
                analyze_dark_gram_lanczos(n, dim, cli.lanczos_k, cli.lanczos_m)
            } else {
                analyze_dark_gram_gpu(n, dim)
            };
            println!(
                "{}\t{}\t{:.6e}\t{:.6e}\t{:.3e}\t{:.4}\t{}\t{}\t{:.1}\t{:.6e}\t{:.6e}\t{:.6e}\t{:.6e}\t{:.2}\t{:.2}",
                n, dim,
                result.lambda_min, result.lambda_max, result.kappa,
                result.r_mean, result.ensemble, result.decay_type,
                result.eff_rank, result.trace, result.frobenius,
                result.diag_min, result.diag_max,
                result.build_secs, result.eigen_secs,
            );
        }
    }

    eprintln!();
    eprintln!(
        "═══════════════════════════════════════════════════════════════"
    );
    eprintln!(
        "  🪞 Dark Gram GPU Spectroscopy complete ({:.1}s)",
        t_total.elapsed().as_secs_f64()
    );
    eprintln!(
        "═══════════════════════════════════════════════════════════════"
    );
}

struct SpectralResult {
    lambda_min: f64,
    lambda_max: f64,
    kappa: f64,
    r_mean: f64,
    ensemble: String,
    decay_type: String,
    eff_rank: f64,
    trace: f64,
    frobenius: f64,
    diag_min: f64,
    diag_max: f64,
    build_secs: f64,
    eigen_secs: f64,
}

// ═══════════════════════════════════════════════════════════════
// LANCZOS OOC MODE — Matrix-Free Dark Gram Spectroscopy
//
// For N > 22,000, we can't fit the matrix + workspace in GPU VRAM,
// and for N > 55,000, we can't fit it in 64GB RAM either.
//
// The Lanczos algorithm only needs matrix-vector products y = G·x,
// which we compute on-the-fly using the closed form:
//   G_{j,k} = gcd(j,k)⁴ / (180 · j² · k²)
//
// Memory: O(m × N) for m Lanczos vectors (~200 × N × 8 bytes)
// For N=100k, m=200: ~160 MB (vs 80 GB for full matrix!)
//
// This is the path to N=1,000,000.
// ═══════════════════════════════════════════════════════════════

/// Matrix-free matvec for Dark Gram G^(2): y = G · x
/// where G_{j,k} = gcd(j+2,k+2)⁴ / (180 · (j+2)² · (k+2)²)
///
/// Parallelized over rows using rayon. Each row computes:
///   y[i] = Σ_k gcd(i+2, k+2)⁴ / (180 · (i+2)² · (k+2)²) · x[k]
fn dark_gram_matvec_n2(x: &[f64], y: &mut [f64]) {
    let dim = x.len();
    y.par_chunks_mut(1).enumerate().for_each(|(i, out)| {
        let j = i + 2;
        let jf = j as f64;
        let j2 = jf * jf;
        let mut sum = 0.0f64;
        for k_idx in 0..dim {
            let k = k_idx + 2;
            let g = gcd(j, k) as f64;
            let kf = k as f64;
            sum += g * g * g * g / (j2 * kf * kf) * x[k_idx];
        }
        out[0] = sum / 180.0;
    });
}

/// Embedded Lanczos tridiagonalization (no external deps).
/// Returns (alpha, beta, basis) where alpha/beta are tridiagonal entries.
fn lanczos_tridiag(
    matvec: &(dyn Fn(&[f64], &mut [f64]) + Sync),
    dim: usize,
    m: usize,
) -> (Vec<f64>, Vec<f64>, Vec<Vec<f64>>) {
    let m = m.min(dim);
    let mut alpha = Vec::with_capacity(m);
    let mut beta = Vec::with_capacity(m);
    let mut basis: Vec<Vec<f64>> = Vec::with_capacity(m + 1);

    // Start vector: uniform 1/√N
    let val = 1.0 / (dim as f64).sqrt();
    let mut v = vec![val; dim];
    let norm: f64 = v.iter().map(|x| x * x).sum::<f64>().sqrt();
    for x in &mut v { *x /= norm; }
    basis.push(v);

    let mut w = vec![0.0f64; dim];

    for j in 0..m {
        matvec(&basis[j], &mut w);

        // α_j = v_j^T · w
        let a_j: f64 = basis[j].iter().zip(w.iter()).map(|(a, b)| a * b).sum();
        alpha.push(a_j);

        // w = w - α_j·v_j - β_{j-1}·v_{j-1}
        for i in 0..dim {
            w[i] -= a_j * basis[j][i];
            if j > 0 {
                w[i] -= beta[j - 1] * basis[j - 1][i];
            }
        }

        // Full reorthogonalization (2 passes)
        for _pass in 0..2 {
            for k in 0..=j {
                let coeff: f64 = w.iter().zip(basis[k].iter()).map(|(a, b)| a * b).sum();
                for i in 0..dim { w[i] -= coeff * basis[k][i]; }
            }
        }

        let b_j: f64 = w.iter().map(|x| x * x).sum::<f64>().sqrt();
        if b_j < 1e-14 {
            beta.push(0.0);
            break;
        }
        beta.push(b_j);

        let v_next: Vec<f64> = w.iter().map(|&x| x / b_j).collect();
        basis.push(v_next);

        if (j + 1) % 50 == 0 {
            eprintln!("    Lanczos step {}/{m} (β = {b_j:.4e})", j + 1);
        }
    }

    (alpha, beta, basis)
}

/// Extract eigenvalues from tridiagonal matrix using faer.
fn tridiag_eigenvalues(alpha: &[f64], beta: &[f64]) -> Vec<f64> {
    let m = alpha.len();
    if m == 0 { return vec![]; }

    let mat = faer::Mat::from_fn(m, m, |i, j| {
        if i == j {
            alpha[i]
        } else if i + 1 == j && i < beta.len() {
            beta[i]
        } else if j + 1 == i && j < beta.len() {
            beta[j]
        } else {
            0.0
        }
    });

    mat.self_adjoint_eigenvalues(faer::Side::Lower)
        .expect("faer tridiag eigenvalue failed")
}

/// Analyze Dark Gram via Lanczos OOC (matrix-free).
fn analyze_dark_gram_lanczos(n: usize, dim: usize, k: usize, m: usize) -> SpectralResult {
    eprintln!("  ── G^({n}), dim={dim} [LANCZOS OOC] ────────────");

    let _t_total = Instant::now();
    let diag_val = match n {
        2 => 1.0 / 180.0,
        _ => 0.0,
    };
    let trace = dim as f64 * diag_val;

    eprintln!("    Trace (exact) = {trace:.6e}");
    eprintln!("    Diag (exact)  = {diag_val:.6e}");
    eprintln!("    Memory: ~{:.0} MB (vs {:.0} MB for full matrix)",
        (m as f64) * (dim as f64) * 8.0 / 1e6,
        (dim as f64) * (dim as f64) * 8.0 / 1e6,
    );

    // Build matvec closure
    let matvec: Box<dyn Fn(&[f64], &mut [f64]) + Sync> = match n {
        2 => Box::new(dark_gram_matvec_n2),
        _ => {
            eprintln!("    ⚠ Lanczos OOC only supports n=2 (closed form)");
            return SpectralResult {
                lambda_min: diag_val, lambda_max: diag_val,
                kappa: 1.0, r_mean: 0.0, ensemble: "N/A".to_string(),
                decay_type: "N/A".to_string(), eff_rank: dim as f64,
                trace, frobenius: 0.0, diag_min: diag_val, diag_max: diag_val,
                build_secs: 0.0, eigen_secs: 0.0,
            };
        }
    };

    // ── Bottom-k eigenvalues (smallest) ──
    eprintln!("    ▸ Lanczos pass 1: bottom-{k} eigenvalues (m={m})...");
    let t_eigen = Instant::now();
    let (alpha, beta, _basis) = lanczos_tridiag(matvec.as_ref(), dim, m);
    let ritz = tridiag_eigenvalues(&alpha, &beta);
    let pass1_secs = t_eigen.elapsed().as_secs_f64();
    eprintln!("    ✓ Pass 1 done in {pass1_secs:.1}s ({} Ritz values)", ritz.len());

    let lambda_min = ritz.first().copied().unwrap_or(0.0).abs().max(1e-300);

    // Print bottom eigenvalues
    eprintln!("    Bottom-{k} Ritz values:");
    for (i, &lam) in ritz.iter().take(k).enumerate() {
        eprintln!("      λ_{i:>3} = {lam:.6e}");
    }

    // ── Top-k eigenvalues (largest) via negated matvec ──
    eprintln!("    ▸ Lanczos pass 2: top-{k} eigenvalues (m={m})...");
    let neg_matvec = |x: &[f64], y: &mut [f64]| {
        matvec(x, y);
        for val in y.iter_mut() { *val = -*val; }
    };
    let t_pass2 = Instant::now();
    let (alpha2, beta2, _basis2) = lanczos_tridiag(&neg_matvec, dim, m);
    let ritz2 = tridiag_eigenvalues(&alpha2, &beta2);
    let pass2_secs = t_pass2.elapsed().as_secs_f64();
    eprintln!("    ✓ Pass 2 done in {pass2_secs:.1}s");

    // Negate back: smallest eigenvalue of -G = -largest of G
    let lambda_max = ritz2.first().map(|&v| -v).unwrap_or(diag_val);

    eprintln!("    Top-{k} eigenvalues:");
    for (i, &lam) in ritz2.iter().take(k).enumerate() {
        eprintln!("      λ_{i:>3} = {:.6e}", -lam);
    }

    let kappa = lambda_max / lambda_min;
    let eigen_secs = t_eigen.elapsed().as_secs_f64();

    eprintln!("    λ_min     = {lambda_min:.6e}");
    eprintln!("    λ_max     = {lambda_max:.6e}");
    eprintln!("    κ         = {kappa:.3e}");
    eprintln!("    Total     = {eigen_secs:.1}s");

    SpectralResult {
        lambda_min,
        lambda_max,
        kappa,
        r_mean: 0.0,                    // Lanczos doesn't give full spectrum for ⟨r⟩
        ensemble: "Lanczos".to_string(),
        decay_type: "Lanczos".to_string(),
        eff_rank: 0.0,                  // Would need full spectrum
        trace,
        frobenius: 0.0,
        diag_min: diag_val,
        diag_max: diag_val,
        build_secs: 0.0,
        eigen_secs,
    }
}

// ═══════════════════════════════════════════════════════════════
// DARK GRAM MATRIX CONSTRUCTION (embedded, no workspace deps)
// ═══════════════════════════════════════════════════════════════

/// Build the Dark Gram matrix at Bernoulli order n, dimension dim×dim.
/// Indices run from j,k = 2..dim+1 (as in the CPU version).
fn build_dark_gram(n: usize, dim: usize) -> Vec<f64> {
    let t = Instant::now();
    eprintln!("  ▸ Building Dark Gram matrix: order n={n}, dim={dim}×{dim}...");

    let mut mat = vec![0.0f64; dim * dim];

    // Parallel row construction
    mat.par_chunks_mut(dim)
        .enumerate()
        .for_each(|(i, row)| {
            let j = i + 2; // j starts at 2
            for k_idx in 0..dim {
                let k = k_idx + 2;
                row[k_idx] = match n {
                    2 => dark_gram_entry_n2(j, k),
                    _ => dark_gram_entry_quadrature(n, j, k, 50_000),
                };
            }
        });

    eprintln!(
        "  ✓ Dark Gram G^({n}) built: {dim}×{dim} ({:.2}s)",
        t.elapsed().as_secs_f64()
    );
    mat
}

/// Exact closed-form entry for n=2:
/// G^(2)_{j,k} = gcd(j,k)^4 / (180 * j^2 * k^2)
fn dark_gram_entry_n2(j: usize, k: usize) -> f64 {
    let g = gcd(j, k) as f64;
    let jf = j as f64;
    let kf = k as f64;
    (g * g * g * g) / (180.0 * jf * jf * kf * kf)
}

/// Quadrature entry for general n (fallback).
fn dark_gram_entry_quadrature(n: usize, j: usize, k: usize, npts: usize) -> f64 {
    let h = 1.0 / npts as f64;
    let mut sum = 0.0;
    for i in 0..npts {
        let x = (i as f64 + 0.5) * h;
        let jx = (j as f64) * x;
        let kx = (k as f64) * x;
        let bj = bernoulli_periodic(n, jx - jx.floor());
        let bk = bernoulli_periodic(n, kx - kx.floor());
        sum += bj * bk;
    }
    sum * h
}

/// Evaluate the n-th Bernoulli polynomial at x ∈ [0,1].
fn bernoulli_periodic(n: usize, x: f64) -> f64 {
    match n {
        1 => x - 0.5,
        2 => x * x - x + 1.0 / 6.0,
        3 => x * x * x - 1.5 * x * x + 0.5 * x,
        4 => {
            let x2 = x * x;
            x2 * x2 - 2.0 * x * x2 + x2 - 1.0 / 30.0
        }
        _ => panic!("Bernoulli order {n} not implemented"),
    }
}

fn gcd(mut a: usize, mut b: usize) -> usize {
    while b != 0 {
        let t = b;
        b = a % b;
        a = t;
    }
    a
}

// ═══════════════════════════════════════════════════════════════
// SPECTRAL ANALYSIS
// ═══════════════════════════════════════════════════════════════

fn analyze_dark_gram_gpu(n: usize, dim: usize) -> SpectralResult {
    eprintln!("  ── G^({n}), dim={dim} ──────────────────────────────");

    // Build the Dark Gram matrix (CPU, rayon parallel)
    let t_build = Instant::now();
    let mat = build_dark_gram(n, dim);
    let build_secs = t_build.elapsed().as_secs_f64();

    // Structural analysis
    let trace: f64 = (0..dim).map(|i| mat[i * dim + i]).sum();
    let frobenius: f64 = mat.iter().map(|x| x * x).sum::<f64>().sqrt();
    let diag_min = (0..dim).map(|i| mat[i * dim + i]).fold(f64::MAX, f64::min);
    let diag_max = (0..dim).map(|i| mat[i * dim + i]).fold(f64::MIN, f64::max);

    eprintln!("    Trace     = {trace:.6e}");
    eprintln!("    Frobenius = {frobenius:.6e}");
    eprintln!("    Diag      = [{diag_min:.6e}, {diag_max:.6e}]");

    // GPU eigendecomposition
    let t_eigen = Instant::now();
    let eigenvalues = match gpu::gpu_eigenvalues_only(&mat, dim) {
        Ok((evals, _gpu_time)) => {
            eprintln!("    [GPU] eigendecomposition succeeded");
            evals
        }
        Err(e) => {
            eprintln!("    ⚠ GPU failed: {e}");
            eprintln!("    → Falling back to faer CPU parallel eigensolver...");
            let t_cpu = Instant::now();
            let faer_mat = faer::Mat::from_fn(dim, dim, |i, j| mat[i * dim + j]);
            let eig_vec = faer_mat.self_adjoint_eigenvalues(faer::Side::Lower)
                .expect("faer eigenvalue computation failed");
            eprintln!(
                "    [CPU/faer] eigenvalues computed in {:.2}s",
                t_cpu.elapsed().as_secs_f64()
            );
            eig_vec
        }
    };
    let eigen_secs = t_eigen.elapsed().as_secs_f64();

    // eigenvalues from cuSOLVER are sorted ascending
    let lambda_min_raw = eigenvalues[0];
    let lambda_max_raw = eigenvalues[dim - 1];

    eprintln!(
        "    Eigen     = {dim}×{dim} ({:.2}s)",
        eigen_secs
    );
    eprintln!("    λ_max     = {lambda_max_raw:.6e}");
    eprintln!("    λ_min     = {lambda_min_raw:.6e}");

    let lambda_max = lambda_max_raw;
    let lambda_min = lambda_min_raw.abs().max(1e-300);
    let kappa = lambda_max / lambda_min;

    // Spacing ratio statistics (RMT) — ascending order from cuSOLVER
    let ratios = spacing_ratios(&eigenvalues);
    let r_mean = if ratios.is_empty() {
        0.0
    } else {
        ratios.iter().sum::<f64>() / ratios.len() as f64
    };
    let ensemble = classify_ensemble(r_mean);

    // Eigenvalue decay classification (use descending for this)
    let mut desc = eigenvalues.clone();
    desc.reverse();
    let decay_type = classify_decay(&desc);

    // Effective rank
    let total: f64 = eigenvalues.iter().filter(|&&x| x > 0.0).sum();
    let eff_rank = if total > 0.0 {
        let entropy: f64 = eigenvalues.iter()
            .filter(|&&x| x > 0.0)
            .map(|&x| {
                let p = x / total;
                if p > 1e-30 { -p * p.ln() } else { 0.0 }
            })
            .sum();
        entropy.exp()
    } else {
        0.0
    };

    eprintln!("    ⟨r⟩       = {r_mean:.4} → {ensemble}");
    eprintln!("    κ         = {kappa:.3e}");
    eprintln!("    Eff. rank = {eff_rank:.1}");
    eprintln!("    Decay     = {decay_type}");

    // Print top-10 eigenvalues (descending)
    eprintln!("    Top-10 eigenvalues:");
    for (i, &lam) in desc.iter().take(10).enumerate() {
        eprintln!("      λ_{i:>3} = {lam:.6e}");
    }
    eprintln!();

    SpectralResult {
        lambda_min,
        lambda_max,
        kappa,
        r_mean,
        ensemble,
        decay_type,
        eff_rank,
        trace,
        frobenius,
        diag_min,
        diag_max,
        build_secs,
        eigen_secs,
    }
}

// ═══════════════════════════════════════════════════════════════
// RMT STATISTICS (embedded, no cathedral-utils dependency)
// ═══════════════════════════════════════════════════════════════

/// Compute spacing ratios r_n = min(s_n, s_{n+1}) / max(s_n, s_{n+1})
/// where s_n = λ_{n+1} - λ_n. Expects ascending eigenvalues.
fn spacing_ratios(eigenvalues: &[f64]) -> Vec<f64> {
    if eigenvalues.len() < 3 {
        return vec![];
    }
    let spacings: Vec<f64> = eigenvalues.windows(2).map(|w| w[1] - w[0]).collect();
    spacings
        .windows(2)
        .filter_map(|w| {
            let (s1, s2) = (w[0], w[1]);
            let mx = s1.max(s2);
            if mx < 1e-30 {
                None
            } else {
                let mn = s1.min(s2);
                Some(mn / mx)
            }
        })
        .collect()
}

/// Classify RMT ensemble from mean spacing ratio.
fn classify_ensemble(r_mean: f64) -> String {
    // Theoretical values: Poisson=0.386, GOE=0.531, GUE=0.603, GSE=0.676
    let candidates = [
        ("Poisson", 0.386),
        ("GOE", 0.531),
        ("GUE", 0.603),
        ("GSE", 0.676),
    ];
    let (name, _) = candidates
        .iter()
        .min_by(|a, b| {
            (a.1 - r_mean).abs().partial_cmp(&(b.1 - r_mean).abs()).unwrap()
        })
        .unwrap();
    name.to_string()
}

/// Classify eigenvalue decay as "power" or "exponential".
fn classify_decay(eigenvalues: &[f64]) -> String {
    let n = eigenvalues.len().min(50);
    if n < 5 {
        return "unknown".to_string();
    }

    let positive: Vec<(usize, f64)> = eigenvalues.iter()
        .enumerate()
        .take(n)
        .filter(|(_, &v)| v > 1e-300)
        .map(|(i, &v)| (i, v))
        .collect();

    if positive.len() < 5 {
        return "degenerate".to_string();
    }

    let exp_r2 = r_squared(
        &positive.iter().map(|(i, _)| *i as f64).collect::<Vec<_>>(),
        &positive.iter().map(|(_, v)| v.ln()).collect::<Vec<_>>(),
    );

    let pow_r2 = r_squared(
        &positive.iter().map(|(i, _)| ((*i + 1) as f64).ln()).collect::<Vec<_>>(),
        &positive.iter().map(|(_, v)| v.ln()).collect::<Vec<_>>(),
    );

    if exp_r2 > pow_r2 && exp_r2 > 0.90 {
        format!("exponential (R²={exp_r2:.3})")
    } else if pow_r2 > 0.90 {
        format!("power (R²={pow_r2:.3})")
    } else {
        format!("mixed (exp_R²={exp_r2:.3}, pow_R²={pow_r2:.3})")
    }
}

fn r_squared(x: &[f64], y: &[f64]) -> f64 {
    let n = x.len() as f64;
    let x_mean = x.iter().sum::<f64>() / n;
    let y_mean = y.iter().sum::<f64>() / n;
    let ss_xy: f64 = x.iter().zip(y).map(|(xi, yi)| (xi - x_mean) * (yi - y_mean)).sum();
    let ss_xx: f64 = x.iter().map(|xi| (xi - x_mean).powi(2)).sum();
    let ss_yy: f64 = y.iter().map(|yi| (yi - y_mean).powi(2)).sum();
    if ss_xx.abs() < 1e-30 || ss_yy.abs() < 1e-30 {
        return 0.0;
    }
    (ss_xy * ss_xy) / (ss_xx * ss_yy)
}
