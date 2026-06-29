//! # Confinement Mode: Strong Coupling Analysis via HPDF Gram Matrices
//!
//! Reads pre-computed Gram matrices from .h5 files, builds R_true analytically,
//! forms Δ_true = G - R_true, and computes the confinement table:
//!
//! | N | λ_DC(Δ) | ρ(R⁻¹Δ) | d²_opt | Regime |
//!
//! For small matrices (dim ≤ 3000), performs full eigendecomposition.
//! For larger matrices, computes d²_opt via Cholesky solve only.
//!
//! Created: May 30, 2026 — Confinement (Mirror RH Closure)

use cathedral_utils::arith::gcd;
use nalgebra::{DMatrix, DVector};
use std::path::Path;
use std::time::Instant;

const EULER_GAMMA: f64 = 0.5772156649015329;


/// R_true(j,k) = gcd(j,k)²/(12jk) + 1/4
fn r_true(j: usize, k: usize) -> f64 {
    let g = gcd(j, k);
    (g * g) as f64 / (12.0 * j as f64 * k as f64) + 0.25
}

/// BD mean: b_k = (ln(k) + 1 - γ) / k
fn bd_mean(k: usize) -> f64 {
    ((k as f64).ln() + 1.0 - EULER_GAMMA) / k as f64
}

/// Result for one HPDF file
#[derive(Debug)]
struct ConfinementResult {
    max_n: usize,
    dim: usize,
    d2_opt: f64,
    d2_stored: Option<f64>,
    d2_free: f64,
    scattering: f64,
    lambda_dc: Option<f64>,
    lambda_2: Option<f64>,
    spectral_gap: Option<f64>,
    spectral_radius: Option<f64>,
    trace_delta: f64,
}

/// Analyze a single HPDF file
fn analyze_h5(path: &Path) -> Option<ConfinementResult> {
    use cathedral_utils::hpdf::reader::HpdfReader;

    let t0 = Instant::now();
    let reader = match HpdfReader::open(path) {
        Ok(r) => r,
        Err(e) => {
            eprintln!("  ❌ Failed to open {}: {}", path.display(), e);
            return None;
        }
    };

    let dim = reader.dim();
    let max_n = reader.max_n();

    eprintln!("  📂 N={max_n} (dim={dim})");

    // Read stored d² if available
    let d2_stored = reader.read_distance().ok().flatten().map(|d| d.d_squared);

    // For very large matrices, skip eigendecomposition
    let max_eigen_dim = 3000;

    // §1. Load Gram matrix from H5
    let gram_flat = match reader.read_gram_full() {
        Ok(g) => g,
        Err(e) => {
            eprintln!("  ❌ Failed to read Gram: {}", e);
            return None;
        }
    };

    // Convert to nalgebra DMatrix
    let g_mat = DMatrix::from_fn(dim, dim, |i, j| gram_flat[i * dim + j]);

    // §2. Build R_true
    let r_mat = DMatrix::from_fn(dim, dim, |i, j| r_true(i + 2, j + 2));

    // §3. Δ_true = G - R_true
    let delta = &g_mat - &r_mat;
    let trace_delta = delta.trace();

    // §4. Build b vector
    let b = DVector::from_fn(dim, |i, _| bd_mean(i + 2));

    // §5. Solve for d²_opt = 1 - bᵀG⁻¹b
    let g_chol = match g_mat.clone().cholesky() {
        Some(c) => c,
        None => {
            eprintln!("  ❌ Gram not positive definite!");
            return None;
        }
    };
    let v_star = g_chol.solve(&b);
    let d2_opt = 1.0 - b.dot(&v_star);

    // §6. Solve for d²_free = 1 - bᵀR⁻¹b
    let r_chol = match r_mat.clone().cholesky() {
        Some(c) => c,
        None => {
            eprintln!("  ⚠ R_true not positive definite, using LU");
            let r_lu = r_mat.clone().lu();
            let w_star = r_lu.solve(&b).unwrap();
            let d2_free = 1.0 - b.dot(&w_star);
            let scattering = w_star.dot(&(&delta * &v_star));

            // Skip eigendecomposition for non-PD R
            return Some(ConfinementResult {
                max_n,
                dim,
                d2_opt,
                d2_stored,
                d2_free,
                scattering,
                lambda_dc: None,
                lambda_2: None,
                spectral_gap: None,
                spectral_radius: None,
                trace_delta,
            });
        }
    };
    let w_star = r_chol.solve(&b);
    let d2_free = 1.0 - b.dot(&w_star);
    let scattering = w_star.dot(&(&delta * &v_star));

    // §7. Eigendecomposition (if dim small enough)
    let (lambda_dc, lambda_2, spectral_gap, spectral_radius) = if dim <= max_eigen_dim {
        eprintln!("  🔬 Eigendecomposition ({dim}×{dim})...");
        let t_eig = Instant::now();

        let eig = delta.clone().symmetric_eigen();
        let mut eigs: Vec<f64> = eig.eigenvalues.iter().copied().collect();

        // Sort by absolute value (descending)
        eigs.sort_by(|a, b| b.abs().partial_cmp(&a.abs()).unwrap());

        let eig_time = t_eig.elapsed().as_secs_f64();
        eprintln!("  ✓ Eigendecomp in {eig_time:.1}s");

        let ldc = eigs[0];
        let l2 = if eigs.len() > 1 { eigs[1] } else { 0.0 };
        let gap = if l2.abs() > 0.0 {
            ldc.abs() / l2.abs()
        } else {
            f64::INFINITY
        };

        // Spectral radius of R⁻¹Δ via eigendecomposition
        eprintln!("  🔬 Computing ρ(R⁻¹Δ)...");
        let t_sr = Instant::now();
        let r_inv_delta = r_chol.solve(&delta);
        let product_eig = r_inv_delta.symmetric_eigen();
        let rho = product_eig
            .eigenvalues
            .iter()
            .map(|x| x.abs())
            .fold(0.0f64, |a, b| a.max(b));
        eprintln!("  ✓ ρ(R⁻¹Δ) in {:.1}s", t_sr.elapsed().as_secs_f64());

        (Some(ldc), Some(l2), Some(gap), Some(rho))
    } else {
        eprintln!("  ⏭ Skipping eigendecomp (dim={dim} > {max_eigen_dim})");
        (None, None, None, None)
    };

    let elapsed = t0.elapsed().as_secs_f64();
    eprintln!("  ✅ Done in {elapsed:.1}s");

    Some(ConfinementResult {
        max_n,
        dim,
        d2_opt,
        d2_stored,
        d2_free,
        scattering,
        lambda_dc,
        lambda_2,
        spectral_gap,
        spectral_radius,
        trace_delta,
    })
}

pub fn run(h5_dir: &str) {
    eprintln!();
    eprintln!("{}", "=".repeat(80));
    eprintln!("CONFINEMENT TABLE — Strong Coupling in the Prime Number Gas");
    eprintln!("{}", "=".repeat(80));
    eprintln!();

    // Find all gram_N*.h5 files
    let dir = Path::new(h5_dir);
    let mut files: Vec<_> = std::fs::read_dir(dir)
        .expect("Cannot read H5 directory")
        .filter_map(|e| e.ok())
        .filter(|e| {
            let name = e.file_name();
            let name = name.to_string_lossy();
            name.starts_with("gram_N") && name.ends_with(".h5")
        })
        .map(|e| {
            let name = e.file_name();
            let name = name.to_string_lossy().to_string();
            // Extract N from "gram_N12345.h5"
            let n: usize = name
                .strip_prefix("gram_N")
                .unwrap()
                .strip_suffix(".h5")
                .unwrap()
                .parse()
                .unwrap_or(0);
            (n, e.path())
        })
        .collect();

    files.sort_by_key(|(n, _)| *n);

    eprintln!("Found {} HPDF files in {}", files.len(), h5_dir);
    eprintln!();

    let mut results = Vec::new();

    for (n, path) in &files {
        eprintln!("━━━ Processing N={n} ━━━");
        if let Some(result) = analyze_h5(path) {
            results.push(result);
        }
        eprintln!();
    }

    // Print the confinement table
    println!();
    println!("╔══════════╦═══════╦═══════════════╦═══════════╦═══════════╦═══════════╦══════════╗");
    println!("║   N      ║  dim  ║  λ_DC(Δ)      ║ |λ₁|/|λ₂|║ ρ(R⁻¹Δ)   ║  d²_opt   ║  Regime  ║");
    println!("╠══════════╬═══════╬═══════════════╬═══════════╬═══════════╬═══════════╬══════════╣");

    for r in &results {
        let ldc_str = match r.lambda_dc {
            Some(v) => format!("{v:+13.4}"),
            None => "     —       ".to_string(),
        };
        let gap_str = match r.spectral_gap {
            Some(v) => format!("{v:9.1}×"),
            None => "    —    ".to_string(),
        };
        let rho_str = match r.spectral_radius {
            Some(v) => format!("{v:9.4}"),
            None => "    —    ".to_string(),
        };
        let regime = match r.spectral_radius {
            Some(v) if v > 1.0 => " Strong ",
            Some(_) => "  Weak  ",
            None => "   —    ",
        };

        println!(
            "║ {:<8} ║ {:>5} ║ {} ║ {} ║ {} ║ {:9.7} ║ {} ║",
            r.max_n, r.dim, ldc_str, gap_str, rho_str, r.d2_opt, regime
        );
    }

    println!("╚══════════╩═══════╩═══════════════╩═══════════╩═══════════╩═══════════╩══════════╝");

    // Also print Dyson verification
    println!();
    println!("Dyson Equation Verification:");
    println!(
        "{:<10} {:>12} {:>12} {:>12} {:>12}",
        "N", "d²_free", "scattering", "d²_Dyson", "d²_opt"
    );
    for r in &results {
        let dyson = r.d2_free + r.scattering;
        println!(
            "{:<10} {:>12.6} {:>12.6} {:>12.6} {:>12.6}",
            r.max_n, r.d2_free, r.scattering, dyson, r.d2_opt
        );
    }
}
