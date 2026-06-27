// ═══════════════════════════════════════════════════════════════════════════
//  𝔽₁ HODGE EXPLORER v2 — Full HPDF Scale Run
//
//  Scans all available HPDF Gram matrices (N=2 to N=55,440).
//  For each N:
//    1. Loads G from H5 (sub-second for even 55K×55K)
//    2. Computes vᵀGv, vᵀB₁v, vᵀL₁v, deg(v)  [O(N²)]
//    3. For N ≤ EIGEN_THRESHOLD: full eigenvalue analysis of L₁ on degree-0
//    4. Extracts positive L₁ eigenvalues — do they track zeta zeros?
//
//  The zeta zeros hypothesis: the ~log(N) positive eigenvalues of L₁
//  restricted to the degree-0 subspace may correspond to (transforms of)
//  the Riemann zeta zeros.
// ═══════════════════════════════════════════════════════════════════════════

use cathedral_utils::arith;
use nalgebra::{DMatrix, DVector};
use rayon::prelude::*;
use std::path::{Path, PathBuf};

#[cfg(feature = "hpdf")]
use cathedral_utils::hpdf::reader::HpdfReader;

/// Eigenvalue decomposition threshold — above this, only compute witness forms
const EIGEN_THRESHOLD: usize = 10080;

// ═══════════════════════════════════════════════════════════════
// §1. CORE ARITHMETIC
// ═══════════════════════════════════════════════════════════════

/// Build B₁ skeleton matrix: B₁(j,k) = gcd(j,k)² / (12·j·k)
/// Parallelized: each row computed independently via rayon.
fn build_b1_skeleton(n: usize) -> DMatrix<f64> {
    // Compute rows in parallel, then assemble
    let rows: Vec<Vec<f64>> = (0..n).into_par_iter().map(|j| {
        let jj = (j + 1) as f64;
        (0..n).map(|k| {
            let kk = (k + 1) as f64;
            let g = arith::gcd(j + 1, k + 1) as f64;
            g * g / (12.0 * jj * kk)
        }).collect()
    }).collect();
    DMatrix::from_fn(n, n, |j, k| rows[j][k])
}

/// Compute vᵀB₁v analytically without storing B₁ — O(N²)
/// Parallelized: each row's contribution computed independently.
fn compute_vtb1v(v: &DVector<f64>, n: usize) -> f64 {
    let v_slice = v.as_slice();
    (0..n).into_par_iter().map(|j| {
        let vj = v_slice[j];
        if vj.abs() < 1e-20 { return 0.0; }
        let jj = (j + 1) as f64;
        let mut row_sum = 0.0f64;
        for k in 0..n {
            let vk = v_slice[k];
            if vk.abs() < 1e-20 { continue; }
            let kk = (k + 1) as f64;
            let g = arith::gcd(j + 1, k + 1) as f64;
            row_sum += g * g / (12.0 * jj * kk) * vj * vk;
        }
        row_sum
    }).sum()
}

/// Build the Möbius witness vector: v_k = μ(k) · log(N/k) / (k · log(N))
fn build_mobius_witness(n: usize, mu: &[i8]) -> DVector<f64> {
    let ln_n = (n as f64).ln();
    let mut v = DVector::zeros(n);
    for k in 1..=n {
        let mu_k = mu[k] as f64;
        if mu_k != 0.0 {
            v[k - 1] = mu_k * ((n as f64) / (k as f64)).ln() / (k as f64 * ln_n);
        }
    }
    v
}

/// Project matrix to degree-0 subspace: P·M·P where P = I - (1/N)·11ᵀ
fn project_to_degree_zero(m: &DMatrix<f64>) -> DMatrix<f64> {
    let n = m.nrows();
    let ones = DVector::from_element(n, 1.0 / (n as f64).sqrt());
    let proj = DMatrix::identity(n, n) - &ones * ones.transpose();
    &proj * m * &proj
}

// ═══════════════════════════════════════════════════════════════
// §2. HPDF LOADING
// ═══════════════════════════════════════════════════════════════

/// Load Gram matrix from HPDF file.
/// H5 convention: gram_N{X}.h5 stores (X-1)×(X-1) for k=2..X.
/// We augment with k=1 row via gram_entry_f64.
/// Parallelized: row assembly + k=1 row computed via rayon.
#[cfg(feature = "hpdf")]
fn load_gram_hpdf(n: usize, h5_path: &Path) -> Option<DMatrix<f64>> {
    let reader = HpdfReader::open(h5_path).ok()?;
    let h5_dim = reader.dim();
    let data = reader.read_gram_full().ok()?;

    let block_size = (n - 1).min(h5_dim);

    // Build rows in parallel: row 0 = k=1 (computed), rows 1..N = from H5
    let rows: Vec<Vec<f64>> = (0..n).into_par_iter().map(|j| {
        if j == 0 {
            // k=1 row: compute G(1, col+1) for all columns
            (0..n).map(|k| cathedral_utils::gram::gram_entry_f64(1, k + 1)).collect()
        } else {
            // k=j+1 row: copy from H5 data, with k=1 column computed
            let h5_row = j - 1; // H5 row index
            (0..n).map(|k| {
                if k == 0 {
                    // k=1 column: compute G(j+1, 1)
                    cathedral_utils::gram::gram_entry_f64(j + 1, 1)
                } else if h5_row < block_size && (k - 1) < block_size {
                    data[h5_row * h5_dim + (k - 1)]
                } else {
                    0.0
                }
            }).collect()
        }
    }).collect();

    Some(DMatrix::from_fn(n, n, |j, k| rows[j][k]))
}

/// Find all HPDF files in the cache directory, sorted by N
fn find_hpdf_files(cache_dir: &Path) -> Vec<(usize, PathBuf)> {
    let mut files: Vec<(usize, PathBuf)> = std::fs::read_dir(cache_dir)
        .unwrap()
        .filter_map(|e| e.ok())
        .filter_map(|e| {
            let name = e.file_name().to_string_lossy().to_string();
            if name.starts_with("gram_N") && name.ends_with(".h5") && !name.contains("_p") {
                let n_str = name.strip_prefix("gram_N")?.strip_suffix(".h5")?;
                let n: usize = n_str.parse().ok()?;
                if n >= 6 { Some((n, e.path())) } else { None }
            } else {
                None
            }
        })
        .collect();
    files.sort_by_key(|(n, _)| *n);
    files
}

// ═══════════════════════════════════════════════════════════════
// §3. MAIN
// ═══════════════════════════════════════════════════════════════

fn main() {
    eprintln!("═══════════════════════════════════════════════════════════════════");
    eprintln!("  𝔽₁ HODGE EXPLORER v2 — Full HPDF Scale Run (N → 55,440)");
    eprintln!("═══════════════════════════════════════════════════════════════════");

    let cache_dir = PathBuf::from("experiments/cache/hpdf");
    if !cache_dir.exists() {
        eprintln!("  ❌ HPDF cache not found at {}", cache_dir.display());
        eprintln!("     Run from repo root: cargo run --release -p f1-hodge-explorer");
        return;
    }

    let files = find_hpdf_files(&cache_dir);
    eprintln!("  Found {} HPDF files", files.len());

    // Sieve Möbius table up to max N
    let max_n = files.last().map(|(n, _)| *n).unwrap_or(100);
    eprintln!("  Sieving Möbius table up to N={}...", max_n);
    let mu = arith::mobius_table(max_n + 1);
    eprintln!("  ✅ Möbius table ready\n");

    // Known zeta zeros for comparison (imaginary parts on critical line)
    let zeta_zeros: Vec<f64> = vec![
        14.134725, 21.022040, 25.010858, 30.424876, 32.935062,
        37.586178, 40.918719, 43.327073, 48.005151, 49.773832,
        52.970321, 56.446248, 59.347044, 60.831779, 65.112544,
    ];

    // ═══════════════════════════════════════════════════════════════
    // PASS 1: Summary table for ALL N
    // ═══════════════════════════════════════════════════════════════
    println!("╔══════════════════════════════════════════════════════════════════════════════════════════════╗");
    println!("║  𝔽₁ HODGE EXPLORER — Arakelov Decomposition G = B₁ + L₁                                  ║");
    println!("╠══════════════════════════════════════════════════════════════════════════════════════════════╣");
    println!("║ {:>6} {:>10} {:>10} {:>10} {:>10} {:>8} {:>8} {:>8} {:>10} ║",
        "N", "vᵀGv", "vᵀB₁v", "vᵀL₁v", "deg(v)", "L₁⁺eig", "L₁⁻eig", "margin", "time(s)");
    println!("╠══════════════════════════════════════════════════════════════════════════════════════════════╣");

    let mut all_positive_eigs: Vec<(usize, Vec<f64>)> = Vec::new();

    for (n, h5_path) in &files {
        let n = *n;
        let t0 = std::time::Instant::now();

        // Load from HPDF
        #[cfg(feature = "hpdf")]
        let g_opt = load_gram_hpdf(n, h5_path);
        #[cfg(not(feature = "hpdf"))]
        let g_opt: Option<DMatrix<f64>> = None;

        let g = match g_opt {
            Some(g) => g,
            None => {
                eprintln!("  ⚠ Failed to load N={}", n);
                continue;
            }
        };

        let v = build_mobius_witness(n, &mu);

        // Compute vᵀGv via matrix-vector product
        let gv = &g * &v;
        let vtgv = v.dot(&gv);

        // Compute vᵀB₁v analytically (no B₁ matrix needed)
        let vtb1v = compute_vtb1v(&v, n);
        let vtl1v = vtgv - vtb1v;
        let deg_v: f64 = v.iter().sum();
        let margin = 1.0 - vtgv;

        // Eigenvalue analysis for tractable N
        let (n_pos_str, n_neg_str) = if n <= EIGEN_THRESHOLD {
            let b1 = build_b1_skeleton(n);
            let l1 = &g - &b1;
            let l1_deg0 = project_to_degree_zero(&l1);
            let eigs = l1_deg0.symmetric_eigenvalues();
            let n_pos = eigs.iter().filter(|&&e| e > 1e-10).count();
            let n_neg = eigs.iter().filter(|&&e| e < -1e-10).count();

            // Extract positive eigenvalues for zeta zero comparison
            let mut pos_eigs: Vec<f64> = eigs.iter()
                .filter(|&&e| e > 1e-10)
                .copied()
                .collect();
            pos_eigs.sort_by(|a, b| b.partial_cmp(a).unwrap());
            all_positive_eigs.push((n, pos_eigs));

            (format!("{}", n_pos), format!("{}", n_neg))
        } else {
            // Large N: skip eigendecomp, just report forms
            ("—".to_string(), "—".to_string())
        };

        let elapsed = t0.elapsed().as_secs_f64();

        println!(
            "║ {:>6} {:>10.6} {:>10.6} {:>10.6} {:>10.6} {:>8} {:>8} {:>8.4} {:>10.2} ║",
            n, vtgv, vtb1v, vtl1v, deg_v, n_pos_str, n_neg_str, margin, elapsed
        );
    }

    println!("╚══════════════════════════════════════════════════════════════════════════════════════════════╝");

    // ═══════════════════════════════════════════════════════════════
    // PASS 2: Positive L₁ eigenvalue analysis — zeta zero hypothesis
    // ═══════════════════════════════════════════════════════════════
    println!("\n═══════════════════════════════════════════════════════════════════");
    println!("  POSITIVE L₁ EIGENVALUES vs ZETA ZEROS");
    println!("═══════════════════════════════════════════════════════════════════");
    println!("\n  First 15 zeta zeros (imaginary parts):");
    for (i, z) in zeta_zeros.iter().enumerate() {
        println!("    ζ_{} = {:.6}", i + 1, z);
    }

    for (n, pos_eigs) in &all_positive_eigs {
        if pos_eigs.is_empty() { continue; }

        println!("\n  N = {} — {} positive L₁ eigenvalues on degree-0:", n, pos_eigs.len());
        println!("    {:>4} {:>14} {:>14} {:>14} {:>14}",
            "#", "λ", "λ·N", "λ·N/ln(N)", "λ·N²");

        let ln_n = (*n as f64).ln();
        for (i, &lam) in pos_eigs.iter().enumerate() {
            let lam_n = lam * *n as f64;
            let lam_n_ln = lam_n / ln_n;
            let lam_n2 = lam * (*n as f64) * (*n as f64);
            println!("    {:>4} {:>14.8} {:>14.4} {:>14.4} {:>14.1}",
                i + 1, lam, lam_n, lam_n_ln, lam_n2);
        }

        // Check ratios between consecutive positive eigenvalues
        if pos_eigs.len() >= 3 {
            println!("    Ratios λᵢ/λᵢ₊₁:");
            for i in 0..pos_eigs.len()-1 {
                if pos_eigs[i+1] > 1e-15 {
                    let ratio = pos_eigs[i] / pos_eigs[i+1];
                    println!("      λ_{}/λ_{} = {:.4}", i+1, i+2, ratio);
                }
            }
        }

        // Check if λ·N matches zeta zero spacings
        if pos_eigs.len() >= 2 {
            let scaled: Vec<f64> = pos_eigs.iter().map(|&l| l * *n as f64).collect();
            println!("    λ·N values: {:?}",
                scaled.iter().map(|x| format!("{:.2}", x)).collect::<Vec<_>>());
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // PASS 3: Convergence analysis
    // ═══════════════════════════════════════════════════════════════
    println!("\n═══════════════════════════════════════════════════════════════════");
    println!("  CONVERGENCE ANALYSIS");
    println!("═══════════════════════════════════════════════════════════════════");

    // Track the top positive eigenvalue across N
    println!("\n  Top positive L₁ eigenvalue vs N:");
    println!("  {:>6} {:>14} {:>14} {:>14}", "N", "λ_max(L₁⁺)", "λ_max·N", "λ_max/ln(N)");
    for (n, pos_eigs) in &all_positive_eigs {
        if let Some(&lam_max) = pos_eigs.first() {
            let ln_n = (*n as f64).ln();
            println!("  {:>6} {:>14.8} {:>14.4} {:>14.8}",
                n, lam_max, lam_max * *n as f64, lam_max / ln_n);
        }
    }

    // Track #positive eigenvalues vs log(N)
    println!("\n  Count of positive L₁ eigenvalues vs log(N):");
    println!("  {:>6} {:>6} {:>10} {:>10}", "N", "#pos", "ln(N)", "#pos/ln(N)");
    for (n, pos_eigs) in &all_positive_eigs {
        let ln_n = (*n as f64).ln();
        let count = pos_eigs.len();
        println!("  {:>6} {:>6} {:>10.4} {:>10.4}", n, count, ln_n, count as f64 / ln_n);
    }

    println!("\n═══════════════════════════════════════════════════════════════════");
    println!("  𝔽₁ HODGE EXPLORER v2 — Complete");
    println!("═══════════════════════════════════════════════════════════════════");
}
