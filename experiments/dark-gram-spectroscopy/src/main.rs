#![allow(
    dead_code,
    unused_variables,
    clippy::needless_range_loop,
    clippy::empty_line_after_doc_comments
)]
//! ═══════════════════════════════════════════════════════════════════════════
//!  DARK GRAM SPECTROSCOPY v1
//!  The Antimatter Engine — Bernoulli Basis Spectral Analysis
//!
//!  Computes the Dark Gram matrix G^(n) at Bernoulli order n and compares
//!  its spectral structure against the standard (positive) Gram matrix G^(1).
//!
//!  KEY PREDICTION (Gemini, Comm-Link 13):
//!    "A Gram matrix built from smooth Bernoulli polynomials is a compact
//!     operator with a smooth kernel. Its eigenvalues decay exponentially."
//!
//!  KEY DISCOVERY (Claude, DARK_GRAM_DERIVATION.md):
//!    G^(2)_{j,k} = gcd(j,k)⁴ / (180 · j² · k²)  — EXACT CLOSED FORM
//!
//!  Usage:
//!    cargo run --release --bin dark-gram-spectroscopy
//!    cargo run --release --bin dark-gram-spectroscopy -- --max-dim 2000
//!    cargo run --release --bin dark-gram-spectroscopy -- --orders 2,3,4,6
//! ═══════════════════════════════════════════════════════════════════════════

use clap::Parser;
use std::time::Instant;

use dark_gram_spectroscopy::dark_gram;

#[derive(Parser)]
#[command(
    name = "dark-gram-spectroscopy",
    about = "Dark Gram Matrix spectral analysis"
)]
struct Cli {
    /// Bernoulli orders to test (comma-separated)
    #[arg(long, value_delimiter = ',', default_value = "2,3,4")]
    orders: Vec<usize>,

    /// Matrix dimensions to test (comma-separated)
    #[arg(
        long,
        value_delimiter = ',',
        default_value = "12,24,60,120,240,360,720"
    )]
    dims: Vec<usize>,

    /// Maximum dimension (overrides dims if set)
    #[arg(long)]
    max_dim: Option<usize>,

    /// Directory containing positive-side HPDF cache files
    #[arg(long, default_value = "experiments/cache/hpdf")]
    hpdf_dir: String,

    /// Output TSV file
    #[arg(long, default_value = "dark_gram_spectroscopy.tsv")]
    output: String,

    /// Run cross-verification of closed form vs quadrature
    #[arg(long)]
    verify: bool,
}

fn main() {
    let cli = Cli::parse();
    let t_total = Instant::now();

    eprintln!("═══════════════════════════════════════════════════════════════");
    eprintln!("  🪞 DARK GRAM SPECTROSCOPY v1 — The Antimatter Engine");
    eprintln!("═══════════════════════════════════════════════════════════════");
    eprintln!();

    let dims = if let Some(max_dim) = cli.max_dim {
        // Generate standard HC schedule up to max_dim
        let hc = vec![
            12, 24, 36, 48, 60, 120, 180, 240, 360, 720, 840, 1000, 1260, 1680, 2520, 5040, 7560,
            10080, 15120, 20000,
        ];
        hc.into_iter().filter(|&d| d <= max_dim).collect()
    } else {
        cli.dims.clone()
    };

    eprintln!("  Orders:     {:?}", cli.orders);
    eprintln!("  Dimensions: {:?}", dims);
    eprintln!();

    // ── Cross-verification (if requested) ────────────────────
    if cli.verify {
        verify_closed_form();
    }

    // ── Header ───────────────────────────────────────────────
    println!("order\tdim\tlambda_min\tlambda_max\tkappa\tr_mean\tensemble\tdecay_type\teff_rank\ttrace\tfrobenius\tdiag_min\tdiag_max");

    // ── Main sweep ───────────────────────────────────────────
    for &n in &cli.orders {
        for &dim in &dims {
            // Skip if matrix too large for full eigendecomposition
            if dim > 50000 {
                eprintln!("  ⚠ Skipping dim={dim} (too large for full eigen)");
                continue;
            }

            let result = analyze_dark_gram(n, dim);
            println!(
                "{}\t{}\t{:.6e}\t{:.6e}\t{:.3e}\t{:.4}\t{}\t{}\t{:.1}\t{:.6e}\t{:.6e}\t{:.6e}\t{:.6e}",
                n, dim,
                result.lambda_min, result.lambda_max, result.kappa,
                result.r_mean, result.ensemble, result.decay_type,
                result.eff_rank, result.trace, result.frobenius,
                result.diag_min, result.diag_max,
            );
        }
    }

    eprintln!();
    eprintln!("═══════════════════════════════════════════════════════════════");
    eprintln!(
        "  🪞 Dark Gram Spectroscopy complete ({:.1}s)",
        t_total.elapsed().as_secs_f64()
    );
    eprintln!("═══════════════════════════════════════════════════════════════");
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
}

fn analyze_dark_gram(n: usize, dim: usize) -> SpectralResult {
    eprintln!("  ── G^({n}), dim={dim} ──────────────────────────────");

    // Build the Dark Gram matrix
    let mat = dark_gram::build_dark_gram(n, dim);

    // Structural analysis
    let trace: f64 = (0..dim).map(|i| mat[i * dim + i]).sum();
    let frobenius: f64 = mat.iter().map(|x| x * x).sum::<f64>().sqrt();
    let diag_min = (0..dim).map(|i| mat[i * dim + i]).fold(f64::MAX, f64::min);
    let diag_max = (0..dim).map(|i| mat[i * dim + i]).fold(f64::MIN, f64::max);

    eprintln!("    Trace     = {trace:.6e}");
    eprintln!("    Frobenius = {frobenius:.6e}");
    eprintln!("    Diag      = [{diag_min:.6e}, {diag_max:.6e}]");

    // Full eigendecomposition via faer (parallel on all cores)
    let t_eigen = Instant::now();
    let faer_mat = faer::Mat::from_fn(dim, dim, |i, j| mat[i * dim + j]);
    let eig_vec = faer_mat
        .self_adjoint_eigenvalues(faer::Side::Lower)
        .expect("eigenvalue computation failed");
    let mut eigenvalues: Vec<f64> = eig_vec;
    eigenvalues.sort_by(|a, b| b.partial_cmp(a).unwrap()); // Descending

    eprintln!(
        "    Eigen     = {dim}×{dim} ({:.2}s)",
        t_eigen.elapsed().as_secs_f64()
    );
    eprintln!("    λ_max     = {:.6e}", eigenvalues[0]);
    eprintln!("    λ_min     = {:.6e}", eigenvalues[dim - 1]);

    let lambda_max = eigenvalues[0];
    let lambda_min = eigenvalues[dim - 1].abs().max(1e-300);
    let kappa = lambda_max / lambda_min;

    // Spacing ratio statistics (RMT)
    let mut sorted_asc = eigenvalues.clone();
    sorted_asc.sort_by(|a: &f64, b: &f64| a.partial_cmp(b).unwrap());
    let ratios = cathedral_utils::spectral_stats::spacing_ratios(&sorted_asc);
    let r_mean = if ratios.is_empty() {
        0.0
    } else {
        ratios.iter().sum::<f64>() / ratios.len() as f64
    };
    let (ensemble, _) = cathedral_utils::spectral_stats::classify_ensemble(r_mean);

    // Eigenvalue decay classification
    let decay_type = classify_decay(&eigenvalues);

    // Effective rank (exponential of entropy)
    let total: f64 = eigenvalues.iter().filter(|&&x| x > 0.0).sum();
    let eff_rank = if total > 0.0 {
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
        entropy.exp()
    } else {
        0.0
    };

    eprintln!("    ⟨r⟩       = {r_mean:.4} → {ensemble}");
    eprintln!("    κ         = {kappa:.3e}");
    eprintln!("    Eff. rank = {eff_rank:.1}");
    eprintln!("    Decay     = {decay_type}");

    // Print top-10 eigenvalues
    eprintln!("    Top-10 eigenvalues:");
    for (i, &lam) in eigenvalues.iter().take(10).enumerate() {
        eprintln!("      λ_{i:>3} = {lam:.6e}");
    }
    eprintln!();

    SpectralResult {
        lambda_min,
        lambda_max,
        kappa,
        r_mean,
        ensemble: ensemble.to_string(),
        decay_type,
        eff_rank,
        trace,
        frobenius,
        diag_min,
        diag_max,
    }
}

/// Classify eigenvalue decay as "power" or "exponential".
///
/// Fit log(λ_k) vs k and log(λ_k) vs log(k).
/// If the exponential fit (linear in k) has better R² than
/// the power law fit (linear in log k), classify as exponential.
fn classify_decay(eigenvalues: &[f64]) -> String {
    let n = eigenvalues.len().min(50); // Use top 50
    if n < 5 {
        return "unknown".to_string();
    }

    // Filter positive eigenvalues
    let positive: Vec<(usize, f64)> = eigenvalues
        .iter()
        .enumerate()
        .take(n)
        .filter(|(_, &v)| v > 1e-300)
        .map(|(i, &v)| (i, v))
        .collect();

    if positive.len() < 5 {
        return "degenerate".to_string();
    }

    // Exponential fit: log(λ) vs k
    let exp_r2 = r_squared(
        &positive.iter().map(|(i, _)| *i as f64).collect::<Vec<_>>(),
        &positive.iter().map(|(_, v)| v.ln()).collect::<Vec<_>>(),
    );

    // Power law fit: log(λ) vs log(k+1)
    let pow_r2 = r_squared(
        &positive
            .iter()
            .map(|(i, _)| ((*i + 1) as f64).ln())
            .collect::<Vec<_>>(),
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

/// R² (coefficient of determination) for a linear fit.
fn r_squared(x: &[f64], y: &[f64]) -> f64 {
    let n = x.len() as f64;
    let x_mean = x.iter().sum::<f64>() / n;
    let y_mean = y.iter().sum::<f64>() / n;
    let ss_xy: f64 = x
        .iter()
        .zip(y)
        .map(|(xi, yi)| (xi - x_mean) * (yi - y_mean))
        .sum();
    let ss_xx: f64 = x.iter().map(|xi| (xi - x_mean).powi(2)).sum();
    let ss_yy: f64 = y.iter().map(|yi| (yi - y_mean).powi(2)).sum();
    if ss_xx.abs() < 1e-30 || ss_yy.abs() < 1e-30 {
        return 0.0;
    }
    (ss_xy * ss_xy) / (ss_xx * ss_yy)
}

/// Cross-verify the n=2 closed form against quadrature.
fn verify_closed_form() {
    eprintln!("═══════════════════════════════════════════════════════════════");
    eprintln!("  🔬 Cross-Verification: Closed Form vs Quadrature (n=2)");
    eprintln!("═══════════════════════════════════════════════════════════════");

    let mut max_rel_err = 0.0f64;
    let mut tests = 0;

    for j in 2..=50 {
        for k in j..=50 {
            let closed = dark_gram::dark_gram_entry_n2(j, k);
            let quad = dark_gram::dark_gram_entry_quadrature(2, j, k, 100_000);
            let rel_err = (closed - quad).abs() / closed.abs().max(1e-30);
            max_rel_err = max_rel_err.max(rel_err);
            tests += 1;

            if rel_err > 1e-6 {
                eprintln!("  ⚠ ({j},{k}): closed={closed:.6e}, quad={quad:.6e}, err={rel_err:.2e}");
            }
        }
    }

    eprintln!("  ✓ {tests} entries tested");
    eprintln!("  ✓ Max relative error: {max_rel_err:.3e}");

    if max_rel_err < 1e-8 {
        eprintln!("  ✅ PREDICTION 1 CONFIRMED: Closed form matches quadrature");
    } else {
        eprintln!("  ❌ PREDICTION 1 FAILED: Significant discrepancy detected");
    }

    // Verify diagonal constant
    eprintln!();
    eprintln!("  🔬 Prediction 6: Diagonal = 1/180");
    let mut diag_ok = true;
    for j in 2..=1000 {
        let g = dark_gram::dark_gram_entry_n2(j, j);
        if (g - 1.0 / 180.0).abs() > 1e-14 {
            eprintln!("  ⚠ G({j},{j}) = {g}, expected {}", 1.0 / 180.0);
            diag_ok = false;
        }
    }
    if diag_ok {
        eprintln!("  ✅ PREDICTION 6 CONFIRMED: All 999 diagonal entries = 1/180");
    }

    eprintln!();
}
