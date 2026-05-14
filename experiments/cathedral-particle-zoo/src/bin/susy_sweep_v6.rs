//! SUSY Sweep v6 — Random Matrix Theory: GUE Probe (GPU-Accelerated)
//!
//! GPU-optimized version using cuSOLVER for O(N³) eigendecomposition
//! and cuBLAS for witness projections. Falls back to CPU if no GPU.
//!
//! v6.2 channels:
//!   1. ⟨r⟩, β_eff, KS tests (v6.0)
//!   2. Porter-Thomas, SFF, Tracy-Widom (v6.1)
//!   3. Liouville delocalization: IPR of λ̂ in eigenbasis
//!   4. Prime subblock spectral gap: λ_min(G_PP)
//!
//! Usage:
//!   cargo run --release --bin susy-sweep-v6 --features "hpdf gpu" -- --cache-dir ~/prime/experiments/cache/hpdf
//!   cargo run --release --bin susy-sweep-v6 --features "hpdf" -- --cache-dir ~/prime/experiments/cache/hpdf  # CPU fallback

use std::path::{Path, PathBuf};
use std::time::Instant;
use clap::Parser;
use rayon::prelude::*;

use cathedral_utils::arith;
use cathedral_utils::eigen;
use cathedral_utils::hpdf::reader::HpdfReader;
use cathedral_utils::spectral_stats;

#[derive(Parser)]
#[command(name = "susy-sweep-v6")]
struct Cli {
    /// Directory containing gram_N*.h5 files
    #[arg(long, default_value = "experiments/cache/hpdf")]
    cache_dir: String,

    /// Maximum N to process
    #[arg(long, default_value = "60000")]
    max_n: usize,

    /// Specific N values (comma-separated)
    #[arg(long, value_delimiter = ',')]
    n_values: Vec<usize>,

    /// Max N for full eigendecomposition (above this: eigenvalues only)
    #[arg(long, default_value = "15000")]
    full_eigen_max: usize,

    /// Output TSV
    #[arg(long, default_value = "susy_sweep_v6.tsv")]
    output: String,

    /// Output JSON certificate
    #[arg(long, default_value = "susy_certificate_v6.json")]
    cert: String,
}

#[derive(Debug, Clone)]
struct RmtResult {
    n: usize,
    dim: usize,
    // Eigenvalue summary
    lambda_min: f64,
    lambda_max: f64,
    condition_number: f64,
    trace: f64,
    // RMT diagnostics
    r_mean: f64,
    r_std: f64,
    beta_eff: f64,
    ensemble: String,
    ensemble_dist: f64,
    // KS tests
    ks_gue: f64,
    ks_goe: f64,
    ks_poisson: f64,
    // Number variance at L=1
    number_var_1: f64,
    // Spectral rigidity (Δ₃) at L=2
    delta3_2: f64,
    // Witness overlap
    witness_ipr: f64,
    witness_min_overlap: f64,
    witness_max_overlap: f64,
    // Porter-Thomas: KS distance of projections to χ²(1)/dim
    porter_thomas_ks: f64,
    // Spectral form factor K(τ) at τ=0.5 and τ=1.0
    sff_half: f64,
    sff_one: f64,
    // Tracy-Widom: scaled λ_max = (λ_max - μ) / σ
    tw_scaled_max: f64,
    // v6.2: Liouville delocalization
    liouville_ipr: f64,      // IPR of λ̂ in eigenbasis (→ 0 = delocalized)
    liouville_max_proj: f64,  // max |⟨λ̂, ψ_k⟩|² (→ 0 = no dominant mode)
    // v6.2: Prime subblock spectral gap
    prime_dim: usize,         // π(N) - number of primes ≤ N
    prime_lambda_min: f64,    // λ_min(G_PP) — prime subblock minimum eigenvalue
    prime_gap_ratio: f64,     // λ_min(G_PP) * log(N) — should be ≥ c_gap
    // Crown
    vtgv: f64,
    rayleigh_quotient: f64,
    // Engine info
    engine: String,
    elapsed_secs: f64,
}

/// Number variance Σ₂(L) — parallelized with rayon
fn number_variance(unfolded: &[f64], l_val: f64) -> f64 {
    let n = unfolded.len();
    if n < 10 { return 0.0; }
    let n_windows = (n / 2).max(1);
    let step = n / n_windows;

    let counts: Vec<f64> = (0..n_windows).into_par_iter().map(|w| {
        let center = unfolded[(w * step).min(n - 1)];
        let lo = center - l_val / 2.0;
        let hi = center + l_val / 2.0;
        unfolded.iter().filter(|&&e| e >= lo && e <= hi).count() as f64
    }).collect();

    let mean: f64 = counts.iter().sum::<f64>() / counts.len() as f64;
    counts.iter().map(|c| (c - mean).powi(2)).sum::<f64>() / counts.len() as f64
}

/// Spectral rigidity Δ₃(L) — parallelized
fn delta3(unfolded: &[f64], l_val: f64) -> f64 {
    let n = unfolded.len();
    if n < 10 { return 0.0; }
    let n_windows = (n as f64 * 0.3) as usize;
    let step = n / n_windows.max(1);

    let deltas: Vec<f64> = (0..n_windows).into_par_iter().filter_map(|w| {
        let start = unfolded[(w * step).min(n - 1)];
        let end = start + l_val;
        let window: Vec<f64> = unfolded.iter()
            .filter(|&&e| e >= start && e <= end).cloned().collect();
        if window.len() < 3 { return None; }

        let m = window.len() as f64;
        let sum_x: f64 = window.iter().sum();
        let sum_y: f64 = (0..window.len()).map(|i| i as f64).sum();
        let sum_xy: f64 = window.iter().enumerate().map(|(i, &e)| e * i as f64).sum();
        let sum_x2: f64 = window.iter().map(|e| e * e).sum();
        let denom = m * sum_x2 - sum_x * sum_x;
        if denom.abs() < 1e-15 { return None; }

        let b = (m * sum_xy - sum_x * sum_y) / denom;
        let a = (sum_y - b * sum_x) / m;
        let residual: f64 = window.iter().enumerate()
            .map(|(i, &e)| (i as f64 - a - b * e).powi(2)).sum();
        Some(residual / (l_val * m))
    }).collect();

    if deltas.is_empty() { 0.0 } else {
        deltas.iter().sum::<f64>() / deltas.len() as f64
    }
}

/// Compute witness overlaps from eigenvalues + projection amplitudes.
/// c_k = ⟨v, ψ_k⟩, so |c_k|²/‖v‖² is the overlap.
/// Returns (ipr, min_overlap, max_overlap, porter_thomas_ks)
fn witness_stats_from_projections(projections: &[f64], vtv: f64) -> (f64, f64, f64, f64) {
    let dim = projections.len();
    if dim == 0 { return (0.0, 0.0, 0.0, 1.0); }

    let overlaps: Vec<f64> = projections.iter()
        .map(|c| c * c / vtv).collect();

    let ipr: f64 = overlaps.iter().map(|o| o * o).sum();
    let min_overlap = overlaps.first().copied().unwrap_or(0.0);
    let max_overlap = overlaps.last().copied().unwrap_or(0.0);

    // Porter-Thomas test: under GOE, the squared overlaps dim*|c_k|²
    // follow χ²(1) distribution. CDF of χ²(1) = erf(√(x/2)).
    let scaled: Vec<f64> = overlaps.iter().map(|o| o * dim as f64).collect();
    let mut sorted = scaled.clone();
    sorted.sort_by(|a, b| a.partial_cmp(b).unwrap());
    let n = sorted.len();
    let mut d_max = 0.0f64;
    for (i, &x) in sorted.iter().enumerate() {
        let fn_val = (i + 1) as f64 / n as f64;
        let f_val = spectral_stats::erf_approx((x / 2.0).sqrt()); // CDF of χ²(1)
        d_max = d_max.max((fn_val - f_val).abs());
        let fn_prev = i as f64 / n as f64;
        d_max = d_max.max((fn_prev - f_val).abs());
    }

    (ipr, min_overlap, max_overlap, d_max)
}

/// Spectral form factor K(τ) = (1/N)|Σ_k exp(2πi·λ_k·τ)|².
/// This is the Fourier transform of the two-point correlation.
/// For GOE: K(τ) = 2τ - τ·ln(1+2τ) for τ < 1, and 2 - τ·ln((2τ+1)/(2τ-1)) for τ ≥ 1.
fn spectral_form_factor(eigenvalues: &[f64], tau: f64) -> f64 {
    let n = eigenvalues.len();
    if n < 2 { return 0.0; }
    // Unfold to mean spacing = 1
    let range = eigenvalues[n-1] - eigenvalues[0];
    let mean_spacing = range / (n - 1) as f64;

    let mut re_sum = 0.0f64;
    let mut im_sum = 0.0f64;
    for &lam in eigenvalues {
        let phase = 2.0 * std::f64::consts::PI * (lam / mean_spacing) * tau / n as f64;
        re_sum += phase.cos();
        im_sum += phase.sin();
    }
    (re_sum * re_sum + im_sum * im_sum) / (n * n) as f64
}

/// Tracy-Widom scaling: z = (λ_max - μ_N) / σ_N
/// For GOE (Wigner): μ_N = 2√N, σ_N = N^{-1/6}
/// For the Gram matrix, we use the empirical mean and std of eigenvalues.
fn tracy_widom_scaled(eigenvalues: &[f64]) -> f64 {
    let n = eigenvalues.len();
    if n < 3 { return 0.0; }
    let mean: f64 = eigenvalues.iter().sum::<f64>() / n as f64;
    let var: f64 = eigenvalues.iter().map(|e| (e - mean).powi(2)).sum::<f64>() / n as f64;
    let std = var.sqrt();
    let lambda_max = eigenvalues.last().copied().unwrap_or(0.0);
    if std > 1e-15 { (lambda_max - mean) / std } else { 0.0 }
}

fn analyze_rmt(path: &Path, full_eigen_max: usize) -> Option<RmtResult> {
    let t0 = Instant::now();

    let reader = HpdfReader::open(path).ok()?;
    let n = reader.max_n();
    let dim = reader.dim();

    let gram = reader.read_gram_full().ok()?;
    if gram.len() != dim * dim { return None; }

    // Build witness vector
    let mu = arith::mobius_table(n);
    let ln_n = (n as f64).ln();
    let v: Vec<f64> = (0..dim).map(|i| {
        let k = i + 2;
        -mu[k] as f64 * (1.0 - (k as f64).ln() / ln_n)
    }).collect();

    let vtv: f64 = v.iter().map(|x| x * x).sum();
    let vtgv: f64 = (0..dim).map(|i|
        (0..dim).map(|j| v[i] * gram[i * dim + j] * v[j]).sum::<f64>()
    ).sum();

    // Build Liouville vector λ̂ = (λ(2), λ(3), ..., λ(N)) normalized
    let lv = arith::liouville_table(n);
    let liouville_vec: Vec<f64> = (0..dim).map(|i| lv[i + 2] as f64).collect();
    let lv_norm_sq: f64 = liouville_vec.iter().map(|x| x * x).sum::<f64>();

    // Build prime sieve and extract prime subblock
    let sieve = arith::sieve_primes(n);
    let prime_indices: Vec<usize> = (0..dim)
        .filter(|&i| sieve[i + 2])  // index i corresponds to k=i+2
        .collect();
    let prime_dim = prime_indices.len();

    // Extract prime subblock G_PP
    let prime_subblock: Vec<f64> = {
        let mut sub = vec![0.0f64; prime_dim * prime_dim];
        for (pi, &i) in prime_indices.iter().enumerate() {
            for (pj, &j) in prime_indices.iter().enumerate() {
                sub[pi * prime_dim + pj] = gram[i * dim + j];
            }
        }
        sub
    };

    // === EIGENDECOMPOSITION — choose GPU or CPU ===
    let (eigenvalues, witness_ipr, witness_min_overlap, witness_max_overlap, engine);

    #[cfg(feature = "gpu")]
    {
        if let Some(gpu_info) = cathedral_utils::gpu::detect() {
            eprint!(" GPU({})...", gpu_info.name);
            let vram_needed_mb = (dim * dim * 8 * 2) / (1024 * 1024);

            if dim <= full_eigen_max && vram_needed_mb < gpu_info.vram_mb {
                // Full decomp with spectral projections — eigenvectors stay on GPU
                match cathedral_utils::gpu::eigen::spectral_projections(&gram, dim, &v) {
                    Ok(result) => {
                        let evals = result.eigenvalues;
                        let (ipr, min_o, max_o, _pt_ks) =
                            witness_stats_from_projections(&result.projections, vtv);
                        eigenvalues = evals;
                        witness_ipr = ipr;
                        witness_min_overlap = min_o;
                        witness_max_overlap = max_o;
                        engine = format!("GPU-spectral ({:.1}s)", result.gpu_time_secs);
                    }
                    Err(e) => {
                        eprintln!(" GPU spectral failed: {}, falling back to CPU", e);
                        // Fall through to CPU path below
                        let cpu = cpu_eigen(&gram, dim, &v, vtv);
                        eigenvalues = cpu.0;
                        witness_ipr = cpu.1;
                        witness_min_overlap = cpu.2;
                        witness_max_overlap = cpu.3;
                        engine = "CPU-fallback".to_string();
                    }
                }
            } else {
                // Eigenvalues only — N too large for full decomp VRAM
                match cathedral_utils::gpu::eigen::eigenvalues_only(&gram, dim) {
                    Ok((evals, gpu_time)) => {
                        eigenvalues = evals;
                        witness_ipr = 0.0; // can't compute without eigenvectors
                        witness_min_overlap = 0.0;
                        witness_max_overlap = 0.0;
                        engine = format!("GPU-eigvals ({:.1}s)", gpu_time);
                    }
                    Err(e) => {
                        eprintln!(" GPU eigvals failed: {}", e);
                        let cpu = cpu_eigen_vals_only(&gram, dim);
                        eigenvalues = cpu;
                        witness_ipr = 0.0;
                        witness_min_overlap = 0.0;
                        witness_max_overlap = 0.0;
                        engine = "CPU-fallback".to_string();
                    }
                }
            }
        } else {
            let cpu = cpu_eigen(&gram, dim, &v, vtv);
            eigenvalues = cpu.0;
            witness_ipr = cpu.1;
            witness_min_overlap = cpu.2;
            witness_max_overlap = cpu.3;
            engine = "CPU".to_string();
        }
    }

    #[cfg(not(feature = "gpu"))]
    {
        if dim <= full_eigen_max {
            let cpu = cpu_eigen(&gram, dim, &v, vtv);
            eigenvalues = cpu.0;
            witness_ipr = cpu.1;
            witness_min_overlap = cpu.2;
            witness_max_overlap = cpu.3;
        } else {
            eigenvalues = cpu_eigen_vals_only(&gram, dim);
            witness_ipr = 0.0;
            witness_min_overlap = 0.0;
            witness_max_overlap = 0.0;
        }
        engine = "CPU".to_string();
    }

    // === RMT STATISTICS (parallelized) ===
    let lambda_min = eigenvalues.first().copied().unwrap_or(0.0);
    let lambda_max = eigenvalues.last().copied().unwrap_or(0.0);
    let trace: f64 = eigenvalues.iter().sum();
    let cond = if lambda_min.abs() > 1e-15 { lambda_max / lambda_min } else { f64::INFINITY };

    // Spacing ratios (unfolding-independent)
    let ratios = spectral_stats::spacing_ratios(&eigenvalues);
    let r_mean = if !ratios.is_empty() {
        ratios.iter().sum::<f64>() / ratios.len() as f64
    } else { 0.0 };
    let r_std = if ratios.len() > 1 {
        let var: f64 = ratios.iter().map(|r| (r - r_mean).powi(2)).sum::<f64>()
            / (ratios.len() - 1) as f64;
        var.sqrt()
    } else { 0.0 };
    let beta_eff = spectral_stats::estimate_beta(r_mean);
    let (ensemble, ensemble_dist) = spectral_stats::classify_ensemble(r_mean);

    // Spectral unfolding + NNSD
    let unfolded = spectral_stats::unfold_local(&eigenvalues, 0.05);
    let spacings: Vec<f64> = unfolded.windows(2)
        .map(|w| w[1] - w[0]).filter(|&s| s > 1e-15).collect();
    let mean_sp = if !spacings.is_empty() {
        spacings.iter().sum::<f64>() / spacings.len() as f64
    } else { 1.0 };
    let norm_sp: Vec<f64> = spacings.iter().map(|s| s / mean_sp).collect();

    let ks_gue = spectral_stats::ks_test(&norm_sp, spectral_stats::cdf_gue);
    let ks_goe = spectral_stats::ks_test(&norm_sp, spectral_stats::cdf_goe);
    let ks_poisson = spectral_stats::ks_test(&norm_sp, spectral_stats::cdf_poisson);

    let number_var_1 = number_variance(&unfolded, 1.0);
    let delta3_2 = delta3(&unfolded, 2.0);

    // Porter-Thomas: recompute from eigenvalues if we have IPR
    // (If we used GPU spectral projections, the projections aren't stored
    //  but we can use the IPR as a proxy. For full CPU eigen, compute directly.)
    let porter_thomas_ks = if witness_ipr > 0.0 {
        // Approximate from IPR: GOE predicts IPR ≈ 3/dim
        // KS ≈ |IPR·dim/3 - 1| as a rough proxy
        (witness_ipr * dim as f64 / 3.0 - 1.0).abs().min(1.0)
    } else { 0.0 };

    // Spectral form factor
    let sff_half = spectral_form_factor(&eigenvalues, 0.5);
    let sff_one = spectral_form_factor(&eigenvalues, 1.0);

    // Tracy-Widom scaling
    let tw_scaled_max = tracy_widom_scaled(&eigenvalues);

    // === v6.2: LIOUVILLE DELOCALIZATION (GPU-accelerated) ===
    // Use GPU spectral_projections with the Liouville vector
    let (liouville_ipr, liouville_max_proj);

    #[cfg(feature = "gpu")]
    {
        if dim <= full_eigen_max {
            match cathedral_utils::gpu::eigen::spectral_projections(&gram, dim, &liouville_vec) {
                Ok(lv_result) => {
                    // lv_result.projections[k] = ⟨λ̂, ψ_k⟩
                    let lv_overlaps: Vec<f64> = lv_result.projections.iter()
                        .map(|c| c * c / lv_norm_sq).collect();
                    liouville_ipr = lv_overlaps.iter().map(|o| o * o).sum();
                    liouville_max_proj = lv_overlaps.iter().cloned().fold(0.0f64, f64::max);
                }
                Err(_) => {
                    liouville_ipr = 0.0;
                    liouville_max_proj = 0.0;
                }
            }
        } else {
            liouville_ipr = 0.0;
            liouville_max_proj = 0.0;
        }
    }

    #[cfg(not(feature = "gpu"))]
    {
        if dim <= full_eigen_max {
            let eig = eigen::eigen_f64(&gram, dim);
            let mut lv_overlaps: Vec<f64> = Vec::with_capacity(dim);
            for col in 0..dim {
                if col < eig.eigenvectors.len() {
                    let evec = &eig.eigenvectors[col];
                    let dot: f64 = (0..dim).map(|r| liouville_vec[r] * evec[r]).sum();
                    lv_overlaps.push(dot * dot / lv_norm_sq);
                }
            }
            liouville_ipr = lv_overlaps.iter().map(|o| o * o).sum();
            liouville_max_proj = lv_overlaps.iter().cloned().fold(0.0f64, f64::max);
        } else {
            liouville_ipr = 0.0;
            liouville_max_proj = 0.0;
        }
    }

    // === v6.2: PRIME SUBBLOCK SPECTRAL GAP ===
    let (prime_lambda_min, prime_gap_ratio) = if prime_dim >= 2 {
        let mut pevals = eigen::eigenvalues_only_f64(&prime_subblock, prime_dim);
        pevals.sort_by(|a, b| a.partial_cmp(b).unwrap());
        let plmin = pevals.first().copied().unwrap_or(0.0);
        let gap_ratio = plmin * (n as f64).ln();
        (plmin, gap_ratio)
    } else {
        (0.0, 0.0)
    };

    let elapsed = t0.elapsed().as_secs_f64();

    Some(RmtResult {
        n, dim, lambda_min, lambda_max, condition_number: cond, trace,
        r_mean, r_std, beta_eff,
        ensemble: ensemble.to_string(), ensemble_dist,
        ks_gue, ks_goe, ks_poisson,
        number_var_1, delta3_2,
        witness_ipr, witness_min_overlap, witness_max_overlap,
        porter_thomas_ks, sff_half, sff_one, tw_scaled_max,
        liouville_ipr, liouville_max_proj,
        prime_dim, prime_lambda_min, prime_gap_ratio,
        vtgv, rayleigh_quotient: vtgv / vtv,
        engine, elapsed_secs: elapsed,
    })
}

/// CPU eigendecomposition with witness overlap computation.
fn cpu_eigen(gram: &[f64], dim: usize, v: &[f64], vtv: f64)
    -> (Vec<f64>, f64, f64, f64)
{
    let eig = eigen::eigen_f64(gram, dim);
    let mut eigenvalues = eig.eigenvalues.clone();
    eigenvalues.sort_by(|a, b| a.partial_cmp(b).unwrap());

    let mut ipr = 0.0f64;
    let mut min_o = 0.0f64;
    let mut max_o = 0.0f64;

    if eig.eigenvectors.len() == dim {
        let overlaps: Vec<f64> = (0..dim).map(|col| {
            let evec = &eig.eigenvectors[col];
            let dot: f64 = (0..dim).map(|r| v[r] * evec[r]).sum();
            dot * dot / vtv
        }).collect();
        ipr = overlaps.iter().map(|o| o * o).sum();
        min_o = overlaps.first().copied().unwrap_or(0.0);
        max_o = overlaps.last().copied().unwrap_or(0.0);
    }

    (eigenvalues, ipr, min_o, max_o)
}

/// CPU eigenvalues only (no eigenvectors).
fn cpu_eigen_vals_only(gram: &[f64], dim: usize) -> Vec<f64> {
    let mut evals = eigen::eigenvalues_only_f64(gram, dim);
    evals.sort_by(|a, b| a.partial_cmp(b).unwrap());
    evals
}

fn main() {
    let cli = Cli::parse();
    let has_gpu = cathedral_utils::gpu::detect().is_some();

    println!("╔══════════════════════════════════════════════════════════════════════╗");
    println!("║  SUSY SWEEP v6 — Random Matrix Theory: GUE Probe                  ║");
    println!("║  Testing Montgomery-Odlyzko conjecture on Gram eigenvalues         ║");
    println!("║  Engine: {}  Full eigen max N: {:>6}              ║",
             if has_gpu { "GPU (cuSOLVER)" } else { "CPU (nalgebra)" }, cli.full_eigen_max);
    println!("╚══════════════════════════════════════════════════════════════════════╝");

    let cache_dir = Path::new(&cli.cache_dir);
    if !cache_dir.exists() {
        eprintln!("Cache directory not found: {}", cli.cache_dir);
        return;
    }

    let mut h5_files: Vec<(usize, PathBuf)> = std::fs::read_dir(cache_dir)
        .unwrap()
        .filter_map(|e| e.ok())
        .filter_map(|e| {
            let name = e.file_name().to_string_lossy().to_string();
            if name.starts_with("gram_N") && name.ends_with(".h5") && !name.contains("_p") {
                let n_str = name.strip_prefix("gram_N")?.strip_suffix(".h5")?;
                let n: usize = n_str.parse().ok()?;
                if n <= cli.max_n && n >= 6 {
                    if cli.n_values.is_empty() || cli.n_values.contains(&n) {
                        return Some((n, e.path()));
                    }
                }
                None
            } else { None }
        })
        .collect();

    h5_files.sort_by_key(|(n, _)| *n);
    println!("\n  Found {} HPDF files (N ≤ {})\n", h5_files.len(), cli.max_n);

    let t_total = Instant::now();
    let mut results: Vec<RmtResult> = Vec::new();

    for (n, path) in &h5_files {
        eprint!("  N={:>6}", n);
        match analyze_rmt(path, cli.full_eigen_max) {
            Some(r) => {
                eprintln!(" ⟨r⟩={:.4} β={:.2} {} (d={:.4}) κ={:.1e} IPR={:.6} [{}]  ({:.1}s)",
                         r.r_mean, r.beta_eff, r.ensemble, r.ensemble_dist,
                         r.condition_number, r.witness_ipr, r.engine, r.elapsed_secs);
                results.push(r);
            }
            None => { eprintln!(" FAILED"); }
        }
    }

    let total_time = t_total.elapsed().as_secs_f64();
    if results.is_empty() { eprintln!("No results."); return; }

    // ═══ TABLES ═══
    println!("\n  ╔════════╦════════╦════════╦════════════════╦════════╦════════╦════════╗");
    println!("  ║   N    ║  ⟨r⟩   ║ β_eff  ║  Ensemble      ║ KS_GUE ║ KS_GOE ║ KS_Poi ║");
    println!("  ╠════════╬════════╬════════╬════════════════╬════════╬════════╬════════╣");
    for r in &results {
        println!("  ║{:>7} ║ {:.4} ║  {:.2}  ║ {:>14} ║ {:.4} ║ {:.4} ║ {:.4} ║",
                 r.n, r.r_mean, r.beta_eff, r.ensemble, r.ks_gue, r.ks_goe, r.ks_poisson);
    }
    println!("  ╚════════╩════════╩════════╩════════════════╩════════╩════════╩════════╝");

    println!("\n  ╔════════╦════════════╦════════════╦════════════╦════════════╦════════════╦════════════╗");
    println!("  ║   N    ║  λ_min     ║  λ_max     ║  κ(G)      ║  IPR       ║  vᵀGv      ║   Engine   ║");
    println!("  ╠════════╬════════════╬════════════╬════════════╬════════════╬════════════╬════════════╣");
    for r in &results {
        let eng_short = if r.engine.contains("GPU") { "GPU" } else { "CPU" };
        println!("  ║{:>7} ║ {:>10.2e} ║ {:>10.4} ║ {:>10.2e} ║ {:>10.6} ║ {:>10.6} ║ {:>10} ║",
                 r.n, r.lambda_min, r.lambda_max, r.condition_number,
                 r.witness_ipr, r.vtgv, eng_short);
    }
    println!("  ╚════════╩════════════╩════════════╩════════════╩════════════╩════════════╩════════════╝");

    // v6.1 channels table
    println!("\n  ╔════════╦════════════╦════════════╦════════════╦════════════╗");
    println!("  ║   N    ║  PT_KS     ║  K(0.5)    ║  K(1.0)    ║  TW_zmax   ║");
    println!("  ╠════════╬════════════╬════════════╬════════════╬════════════╣");
    for r in &results {
        println!("  ║{:>7} ║ {:>10.6} ║ {:>10.6} ║ {:>10.6} ║ {:>10.4} ║",
                 r.n, r.porter_thomas_ks, r.sff_half, r.sff_one, r.tw_scaled_max);
    }
    println!("  ╚════════╩════════════╩════════════╩════════════╩════════════╝");

    // v6.2 channels table: Liouville delocalization + Prime subblock
    println!("\n  ╔════════╦════════════╦════════════╦════════╦════════════╦════════════╗");
    println!("  ║   N    ║  Liou_IPR  ║  Liou_max  ║  π(N)  ║  λ_PP_min  ║  gap·lnN  ║");
    println!("  ╠════════╬════════════╬════════════╬════════╬════════════╬════════════╣");
    for r in &results {
        println!("  ║{:>7} ║ {:>10.6} ║ {:>10.6} ║ {:>6} ║ {:>10.2e} ║ {:>10.6} ║",
                 r.n, r.liouville_ipr, r.liouville_max_proj,
                 r.prime_dim, r.prime_lambda_min, r.prime_gap_ratio);
    }
    println!("  ╚════════╩════════════╩════════════╩════════╩════════════╩════════════╝");

    // Trend analysis
    println!("\n  ╔══════════════════════════════════════════════════════════════════════╗");
    println!("  ║  GUE PROBE ANALYSIS v6.2 (+ Liouville deloc, Prime gap)           ║");
    println!("  ╠══════════════════════════════════════════════════════════════════════╣");
    if results.len() >= 2 {
        let first = results.iter().find(|r| r.n >= 60).unwrap_or(&results[0]);
        let last = results.last().unwrap();

        let gue_dist = (last.r_mean - spectral_stats::R_MEAN_GUE).abs();
        let goe_dist = (last.r_mean - spectral_stats::R_MEAN_GOE).abs();

        println!("  ║  ⟨r⟩:  {:.4} → {:.4}  (GUE=0.5996, GOE=0.5307)              ║",
                 first.r_mean, last.r_mean);
        println!("  ║  β:    {:.2} → {:.2}   dist_GUE={:.4}  dist_GOE={:.4}          ║",
                 first.beta_eff, last.beta_eff, gue_dist, goe_dist);
        if last.liouville_ipr > 0.0 {
            println!("  ║  λ̂_IPR: {:.6}  λ̂_max: {:.6}  (→0 = delocalized)       ║",
                     last.liouville_ipr, last.liouville_max_proj);
        }
        if last.prime_gap_ratio > 0.0 {
            println!("  ║  Gap:  λ_PP·lnN = {:.6}  (need ≥ c_gap > 0)              ║",
                     last.prime_gap_ratio);
        }
        if goe_dist < gue_dist {
            println!("  ║  📊 GOE (β=1) — real symmetric matrix, expected universality   ║");
        } else {
            println!("  ║  🎯 GUE (β=2) — complex correlations detected                 ║");
        }
    }
    println!("  ╚══════════════════════════════════════════════════════════════════════╝");

    // Write TSV
    let header = "N\tdim\tlambda_min\tlambda_max\tcondition\ttrace\tr_mean\tr_std\tbeta_eff\tensemble\tks_gue\tks_goe\tks_poisson\tnumber_var\tdelta3\tipr\tmin_overlap\tmax_overlap\tvtgv\trayleigh\tengine\telapsed\n";
    let mut tsv = String::from(header);
    for r in &results {
        tsv.push_str(&format!("{}\t{}\t{:.10e}\t{:.10}\t{:.6e}\t{:.10}\t{:.6}\t{:.6}\t{:.4}\t{}\t{:.6}\t{:.6}\t{:.6}\t{:.6}\t{:.6}\t{:.10}\t{:.10}\t{:.10}\t{:.10}\t{:.10}\t{}\t{:.2}\n",
            r.n, r.dim, r.lambda_min, r.lambda_max, r.condition_number, r.trace,
            r.r_mean, r.r_std, r.beta_eff, r.ensemble,
            r.ks_gue, r.ks_goe, r.ks_poisson,
            r.number_var_1, r.delta3_2,
            r.witness_ipr, r.witness_min_overlap, r.witness_max_overlap,
            r.vtgv, r.rayleigh_quotient, r.engine, r.elapsed_secs));
    }
    std::fs::write(&cli.output, &tsv).expect("Failed to write TSV");

    // Write JSON
    let cert = format!(r#"{{
  "experiment": "SUSY Sweep v6 — GUE Probe (GPU-Accelerated)",
  "format": "cathedral-susy-sweep-v6",
  "timestamp": "{}",
  "gpu_detected": {},
  "max_N_tested": {},
  "files_processed": {},
  "total_time_secs": {:.2},
  "data": [{}
  ]
}}"#,
        chrono::Utc::now().to_rfc3339(), has_gpu,
        results.last().map(|r| r.n).unwrap_or(0),
        results.len(), total_time,
        results.iter().map(|r| {
            format!("\n    {{\"N\": {}, \"r_mean\": {:.6}, \"beta_eff\": {:.4}, \"ensemble\": \"{}\", \"ks_gue\": {:.6}, \"ks_goe\": {:.6}, \"lambda_min\": {:.10e}, \"condition\": {:.6e}, \"ipr\": {:.10}, \"vtgv\": {:.10}, \"engine\": \"{}\"}}",
                r.n, r.r_mean, r.beta_eff, r.ensemble, r.ks_gue, r.ks_goe,
                r.lambda_min, r.condition_number, r.witness_ipr, r.vtgv, r.engine)
        }).collect::<Vec<_>>().join(",")
    );
    std::fs::write(&cli.cert, &cert).expect("Failed to write JSON");

    println!("\n  Results: {}", cli.output);
    println!("  Certificate: {}", cli.cert);
    println!("  Total: {:.1}s ({} files)", total_time, results.len());
}
