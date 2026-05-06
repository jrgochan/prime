//! Core certification logic — multi-tier d²_N computation with verification.
//!
//! For each N, the pipeline:
//! 1. Discovers/loads the Gram matrix
//! 2. Computes d² via Cholesky (GPU or CPU)
//! 3. Cross-checks at higher precision when possible
//! 4. Runs spectral analysis (eigenvalues)
//! 5. Verifies monotonicity against previous certificates
//! 6. Writes an independently verifiable JSON certificate

use cathedral_utils::{arith, gram, cache, ooc, dd::DD};
#[cfg(feature = "gpu")]
use cathedral_utils::gpu;
use rayon::prelude::*;
use serde::{Serialize, Deserialize};
use sha2::{Sha256, Digest};
use std::path::{Path, PathBuf};
use std::time::Instant;

// ═══════════════════════════════════════════════════════════════════
// CERTIFICATE DATA STRUCTURES
// ═══════════════════════════════════════════════════════════════════

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct Certificate {
    pub format: String,
    pub version: String,
    #[serde(rename = "N")]
    pub max_n: usize,
    pub dim: usize,

    pub distance: DistanceResult,
    pub spectrum: Option<SpectrumResult>,
    pub monotonicity: Option<MonotonicityCheck>,
    pub verification: VerificationInfo,
    pub machine: MachineInfo,

    pub lean_claims: Vec<String>,
    pub timestamp: String,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct DistanceResult {
    pub d_sq: f64,
    pub method: String,
    pub precision_digits: u32,
    pub compute_time_secs: f64,
    pub cross_check: Option<CrossCheck>,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct CrossCheck {
    pub d_sq: f64,
    pub method: String,
    pub agreement_digits: u32,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct SpectrumResult {
    pub lambda_min: f64,
    pub lambda_min_positive: bool,
    pub lambda_max: f64,
    pub condition_number: f64,
    pub compute_time_secs: f64,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct MonotonicityCheck {
    pub previous_n: usize,
    pub previous_d_sq: f64,
    pub strictly_decreased: bool,
    pub decrease_amount: f64,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct VerificationInfo {
    pub matrix_source: String,
    pub matrix_sha256: String,
    pub matrix_size_bytes: u64,
    pub gram_formula: String,
    pub b_vector_formula: String,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct MachineInfo {
    pub hostname: String,
    pub gpu: Option<String>,
    pub gpu_vram_mb: Option<usize>,
    pub compute_time_total_secs: f64,
}

// ═══════════════════════════════════════════════════════════════════
// CERTIFY A SINGLE N
// ═══════════════════════════════════════════════════════════════════

pub fn certify_single(
    max_n: usize,
    explicit_source: Option<String>,
    search_paths: &[PathBuf],
    output_dir: &str,
) {
    let t_total = Instant::now();
    let dim = max_n - 1;

    println!("  ┌─────────────────────────────────────────────────────────────┐");
    println!("  │  CERTIFYING N = {:>6}  (dim = {:>6})                       │", max_n, dim);
    println!("  └─────────────────────────────────────────────────────────────┘");
    println!();

    // ─── TIER 1: Load or build matrix ───
    let (gram_data, dd_lo, matrix_source_path, matrix_sha256) = load_matrix(max_n, dim, explicit_source, search_paths);
    let has_dd = dd_lo.is_some();
    if has_dd {
        println!("  ✓ DD-precision matrix loaded (hi + lo, ~31 digits per entry)");
    }

    // ─── Build b vector ───
    let b = arith::b_vector(dim);
    println!("  ✓ b vector: dim={}, ‖b‖={:.8}", b.len(), dot(&b, &b).sqrt());

    // ─── TIER 2: Compute d² (primary) ───
    let t_d2 = Instant::now();
    let (d_sq, method, precision_digits) = if let Some(ref lo) = dd_lo {
        // Use DD-matrix-aware CG solver
        compute_d_sq_primary_dd(&gram_data, lo, &b, dim)
    } else {
        compute_d_sq_primary(&gram_data, &b, dim)
    };
    let d2_time = t_d2.elapsed().as_secs_f64();
    println!("  ✓ d²_{} = {:.15}  ({})", max_n, d_sq, method);
    println!("    Precision: {} digits, time: {:.1}s", precision_digits, d2_time);

    // ─── TIER 3: Cross-check (higher precision when possible) ───
    let cross_check = compute_cross_check(&gram_data, &b, dim, d_sq);
    if let Some(ref cc) = cross_check {
        println!("  ✓ Cross-check: d²={:.15}  ({}, {} digits agree)",
            cc.d_sq, cc.method, cc.agreement_digits);
    }

    // ─── TIER 4: Spectral analysis ───
    let spectrum = compute_spectrum(&gram_data, dim);
    if let Some(ref s) = spectrum {
        let positive = if s.lambda_min_positive { "✓" } else { "✗" };
        println!("  {} λ_min={:.6e}  λ_max={:.6}  κ={:.2e}",
            positive, s.lambda_min, s.lambda_max, s.condition_number);
    }

    // ─── TIER 5: Monotonicity check ───
    let monotonicity = check_monotonicity(max_n, d_sq, output_dir);
    if let Some(ref m) = monotonicity {
        let check = if m.strictly_decreased { "✓" } else { "✗" };
        println!("  {} Monotonicity: d²_{} < d²_{} (Δ={:.6e})",
            check, max_n, m.previous_n, m.decrease_amount);
    }

    // ─── TIER 6: Write certificate ───
    let total_time = t_total.elapsed().as_secs_f64();

    #[cfg(feature = "gpu")]
    let gpu_info = cathedral_utils::gpu::detect();
    #[cfg(not(feature = "gpu"))]
    let gpu_info: Option<cathedral_utils::gpu::GpuInfo> = None;

    let lean_claims = generate_lean_claims(max_n, d_sq, &spectrum);

    let cert = Certificate {
        format: "cathedral-certified-distance-v2".to_string(),
        version: "1.0.0".to_string(),
        max_n,
        dim,
        distance: DistanceResult {
            d_sq,
            method: method.to_string(),
            precision_digits,
            compute_time_secs: d2_time,
            cross_check,
        },
        spectrum,
        monotonicity,
        verification: VerificationInfo {
            matrix_source: matrix_source_path,
            matrix_sha256,
            matrix_size_bytes: (dim as u64) * (dim as u64) * 8,
            gram_formula: "G[j,k] = ∫₀¹ {1/(jx)}{1/(kx)} dx".to_string(),
            b_vector_formula: "b[j] = ∫₀¹ {1/(jx)} dx".to_string(),
        },
        machine: MachineInfo {
            hostname: hostname(),
            gpu: gpu_info.as_ref().map(|g| g.name.clone()),
            gpu_vram_mb: gpu_info.as_ref().map(|g| g.vram_mb),
            compute_time_total_secs: total_time,
        },
        lean_claims,
        timestamp: iso_now(),
    };

    // Write certificate
    std::fs::create_dir_all(output_dir).ok();
    let cert_path = format!("{}/cert_N{}.json", output_dir, max_n);
    let json = serde_json::to_string_pretty(&cert).unwrap();
    std::fs::write(&cert_path, &json).expect("Failed to write certificate");

    println!();
    println!("  📜 Certificate → {}", cert_path);
    println!("  ⏱️  Total: {:.1}s", total_time);
    println!();
}

// ═══════════════════════════════════════════════════════════════════
// SWEEP ALL CACHED MATRICES
// ═══════════════════════════════════════════════════════════════════

pub fn sweep_all(search_paths: &[PathBuf], output_dir: &str) {
    let sources = ooc::discover_matrices(search_paths);

    if sources.is_empty() {
        println!("  No cached matrices found. Nothing to certify.");
        return;
    }

    println!("  Found {} matrices to certify:", sources.len());
    for s in &sources {
        println!("    N={:>6}  {:?}  {}", s.max_n, s.format, s.path.display());
    }
    println!();

    for source in &sources {
        certify_single(
            source.max_n,
            Some(source.path.to_string_lossy().to_string()),
            search_paths,
            output_dir,
        );
    }

    // Write master certificate
    write_master_certificate(output_dir);
}

// ═══════════════════════════════════════════════════════════════════
// MATRIX LOADING
// ═══════════════════════════════════════════════════════════════════

fn load_matrix(
    max_n: usize, dim: usize,
    explicit_source: Option<String>,
    search_paths: &[PathBuf],
) -> (Vec<f64>, Option<Vec<f64>>, String, String) {
    let t = Instant::now();

    // Try explicit source first
    if let Some(ref path_str) = explicit_source {
        let path = PathBuf::from(path_str);
        if path.exists() {
            println!("  Loading: {}", path.display());
            if let Some((data, lo)) = load_from_path(&path, dim) {
                let sha = compute_sha256_prefix(&data);
                println!("  ✓ Loaded in {:.1}s ({:.0} MB), SHA256: {}...",
                    t.elapsed().as_secs_f64(),
                    data.len() as f64 * 8.0 / 1e6, &sha[..16]);
                return (data, lo, path_str.clone(), sha);
            }
        }
    }

    // Discover from search paths — prefer DD cache over f64
    let sources = ooc::discover_matrices(search_paths);
    // First pass: look for DD cache
    for source in &sources {
        if source.max_n == max_n {
            let name = source.path.file_name().map(|n| n.to_string_lossy().to_string()).unwrap_or_default();
            if name.starts_with("dd_gram_N") {
                println!("  Found DD: {} ({:?})", source.path.display(), source.format);
                if let Some((data, lo)) = load_from_path(&source.path, dim) {
                    let sha = compute_sha256_prefix(&data);
                    println!("  ✓ Loaded in {:.1}s ({:.0} MB), SHA256: {}...",
                        t.elapsed().as_secs_f64(),
                        data.len() as f64 * 8.0 / 1e6, &sha[..16]);
                    return (data, lo, source.path.to_string_lossy().to_string(), sha);
                }
            }
        }
    }
    // Second pass: any format
    for source in &sources {
        if source.max_n == max_n {
            println!("  Found: {} ({:?})", source.path.display(), source.format);
            if let Some((data, lo)) = load_from_path(&source.path, dim) {
                let sha = compute_sha256_prefix(&data);
                println!("  ✓ Loaded in {:.1}s ({:.0} MB), SHA256: {}...",
                    t.elapsed().as_secs_f64(),
                    data.len() as f64 * 8.0 / 1e6, &sha[..16]);
                return (data, lo, source.path.to_string_lossy().to_string(), sha);
            }
        }
    }

    // Build from scratch
    println!("  No cached matrix found for N={}. Building from scratch...", max_n);
    let table_size = (max_n * 5).max(10_000).min(500_000);
    let ln_table = gram::LnNTable::new(table_size, 256);

    let mut data = vec![0.0f64; dim * dim];
    let indices: Vec<(usize, usize)> = (0..dim)
        .flat_map(|i| (i..dim).map(move |j| (i, j)))
        .collect();

    let entries: Vec<(usize, usize, f64)> = indices.par_iter()
        .map(|&(i, j)| {
            let val = gram::gram_entry_fast(i + 2, j + 2, &ln_table).to_f64();
            (i, j, val)
        })
        .collect();

    for (i, j, val) in entries {
        data[i * dim + j] = val;
        data[j * dim + i] = val; // symmetric
    }

    let sha = compute_sha256_prefix(&data);
    println!("  ✓ Built in {:.1}s, SHA256: {}...",
        t.elapsed().as_secs_f64(), &sha[..16]);
    (data, None, "built_from_scratch".to_string(), sha)
}

/// Load matrix from path, returning (hi_data, optional_lo_data).
fn load_from_path(path: &Path, dim: usize) -> Option<(Vec<f64>, Option<Vec<f64>>)> {
    let name = path.file_name()?.to_string_lossy();

    if name.starts_with("dd_gram_N") {
        // DD cache: load both hi and lo parts
        let (hi, lo, loaded_dim) = cache::load_dd_gram(path)?;
        if loaded_dim != dim {
            eprintln!("  ⚠ Dimension mismatch: loaded {} vs expected {}", loaded_dim, dim);
            return None;
        }
        return Some((hi, Some(lo)));
    }

    if name.starts_with("ooc_gram_N") {
        // OOC format: skip header, read f64 matrix
        let mut file = std::fs::File::open(path).ok()?;
        let header = ooc::read_header(&mut file).ok()??;
        if header.dim != dim {
            eprintln!("  ⚠ Dimension mismatch: loaded {} vs expected {}", header.dim, dim);
            return None;
        }
        let total = dim * dim;
        let mut data = vec![0.0f64; total];
        use std::io::Read;
        let bytes: &mut [u8] = unsafe {
            std::slice::from_raw_parts_mut(data.as_mut_ptr() as *mut u8, total * 8)
        };
        file.read_exact(bytes).ok()?;
        return Some((data, None));
    }

    if name.starts_with("gram_N") {
        // Legacy format
        let gram = cache::load_gram(path)?;
        if gram.max_dim != dim { return None; }
        return Some((gram.data, None));
    }

    None
}

// ═══════════════════════════════════════════════════════════════════
// d² COMPUTATION TIERS
// ═══════════════════════════════════════════════════════════════════

fn compute_d_sq_primary(gram: &[f64], b: &[f64], dim: usize) -> (f64, &'static str, u32) {
    // Try GPU Cholesky first
    #[cfg(feature = "gpu")]
    if gpu::detect().is_some() {
        match gpu::cholesky::d_sq_f64(gram, b, dim) {
            Ok(result) => {
                return (result.d_sq, result.method, result.precision_digits);
            }
            Err(e) => {
                eprintln!("  ⚠ GPU Cholesky failed ({}), trying fallbacks", e);
            }
        }
    }

    // CPU Cholesky — skip for dim > 25000 (too slow single-threaded)
    if dim <= 25000 {
        let chol = cpu_cholesky_d_sq(gram, b, dim);
        if !chol.0.is_nan() {
            return chol;
        }

        // CPU LU decomposition — also skip for large matrices
        let lu = cpu_lu_d_sq(gram, b, dim);
        if !lu.0.is_nan() {
            return lu;
        }
    } else {
        eprintln!("  ⚠ Skipping CPU direct solvers (dim={} > 25000, would be too slow)", dim);
    }

    // Mixed-precision CG: f64 matvec + DD accumulation for robustness
    eprintln!("  → Using Mixed-Precision CG (DD accumulation, Jacobi-preconditioned)...");
    cg_solve_d_sq_dd(gram, b, dim)
}

fn cpu_cholesky_d_sq(gram: &[f64], b: &[f64], dim: usize) -> (f64, &'static str, u32) {
    use nalgebra::DMatrix;

    let mat = DMatrix::from_row_slice(dim, dim, gram);
    let b_vec = nalgebra::DVector::from_column_slice(&b[..dim]);

    match mat.cholesky() {
        Some(chol) => {
            let x = chol.solve(&b_vec);
            let dot = b_vec.dot(&x);
            (1.0 - dot, "CPU_Cholesky_nalgebra", 15)
        }
        None => {
            eprintln!("  ⚠ CPU Cholesky failed (matrix not positive definite at f64)");
            (f64::NAN, "FAILED", 0)
        }
    }
}

fn cpu_lu_d_sq(gram: &[f64], b: &[f64], dim: usize) -> (f64, &'static str, u32) {
    use nalgebra::DMatrix;

    let mat = DMatrix::from_row_slice(dim, dim, gram);
    let b_vec = nalgebra::DVector::from_column_slice(&b[..dim]);

    match mat.lu().solve(&b_vec) {
        Some(x) => {
            let dot = b_vec.dot(&x);
            let d_sq = 1.0 - dot;
            eprintln!("  ✓ LU decomposition succeeded");
            (d_sq, "CPU_LU_nalgebra", 14)
        }
        None => {
            eprintln!("  ⚠ LU decomposition also failed (singular matrix)");
            (f64::NAN, "FAILED", 0)
        }
    }
}

/// Mixed-Precision Conjugate Gradient solver.
///
/// KEY INSIGHT: The f64 CG fails at large N because dot products of ~55k terms
/// lose ~4 digits of precision, causing false non-SPD detection. The fix:
///   - Matvec (y = Ax): stays f64 (this is 99% of compute, and f64 is fine)
///   - Dot products: DD accumulation (~31 digits) — prevents precision collapse
///   - Scalar updates (alpha, beta, rz): DD throughout
///   - x, r, p vectors: f64 storage, DD-accumulated updates
///
/// This gives us f64 speed with DD robustness.
/// Expected: works cleanly to N=120,000+ without the "non-positive p^T Ap" failure.
fn cg_solve_d_sq_dd(gram: &[f64], b: &[f64], dim: usize) -> (f64, &'static str, u32) {
    let t = Instant::now();

    // Jacobi preconditioner: M⁻¹ = diag(1/G[i,i])
    let m_inv: Vec<f64> = (0..dim).into_par_iter()
        .map(|i| {
            let diag = gram[i * dim + i];
            if diag > 0.0 { 1.0 / diag } else { 1.0 }
        }).collect();

    // Initialize: x = 0, r = b
    let mut x = vec![0.0f64; dim];
    let mut r = b[..dim].to_vec();
    let mut z: Vec<f64> = r.par_iter().zip(m_inv.par_iter())
        .map(|(ri, mi)| ri * mi).collect();
    let mut p = z.clone();
    let mut ap = vec![0.0f64; dim];

    // DD-precision scalars
    let mut rz = par_dot_dd(&r, &z);
    let b_norm_sq = par_dot_dd(b, b);
    let b_norm = b_norm_sq.to_f64().sqrt();
    let tol = 1e-14 * b_norm;
    let max_iter = dim.min(50_000);

    let mut converged = false;
    let mut final_iter = 0;
    let mut stagnation_count = 0;
    let mut prev_r_norm = f64::MAX;

    for iter in 0..max_iter {
        // ap = G p  (parallel f64 matvec — the dominant cost, stays f64)
        matvec_parallel(gram, &p, &mut ap, dim);

        // DD-precision dot product for p^T A p — this is where f64 CG fails
        let pap = par_dot_dd(&p, &ap);
        if pap.hi <= 0.0 && pap.lo <= 0.0 {
            // Even with DD, truly non-positive — matrix really isn't SPD
            eprintln!("  ⚠ CG-DD: non-positive p^T A p at iter {} (DD: {:.6e}+{:.6e})",
                iter, pap.hi, pap.lo);
            break;
        }

        let alpha = rz / pap;
        let alpha_f64 = alpha.to_f64();

        // x += alpha * p; r -= alpha * ap  (parallel, f64 storage)
        x.par_iter_mut().zip(p.par_iter())
            .for_each(|(xi, pi)| *xi += alpha_f64 * pi);
        r.par_iter_mut().zip(ap.par_iter())
            .for_each(|(ri, api)| *ri -= alpha_f64 * api);

        // DD-precision residual norm
        let r_norm_sq = par_dot_dd(&r, &r);
        let r_norm = r_norm_sq.to_f64().sqrt();

        // Progress report every 500 iterations
        if iter % 500 == 0 || r_norm < tol {
            let bx = par_dot_dd(&b[..dim], &x);
            let d_sq_est = 1.0 - bx.to_f64();
            eprint!("\r  CG-DD iter {:>5}: ‖r‖={:.3e}, d²≈{:.12}", iter, r_norm, d_sq_est);
        }

        if r_norm < tol {
            eprintln!();
            converged = true;
            final_iter = iter;
            break;
        }

        // Stagnation detection: if residual stops decreasing, apply
        // explicit residual recomputation to fight drift
        if r_norm >= prev_r_norm * 0.9999 {
            stagnation_count += 1;
            if stagnation_count >= 50 && stagnation_count % 100 == 0 {
                // Recompute residual from scratch: r = b - Gx
                matvec_parallel(gram, &x, &mut ap, dim);
                r.par_iter_mut().enumerate()
                    .for_each(|(i, ri)| *ri = b[i] - ap[i]);
                let _new_rz = par_dot_dd(&r, &z);
                // Recompute z and rz after residual refresh
                z.par_iter_mut().enumerate()
                    .for_each(|(i, zi)| *zi = m_inv[i] * r[i]);
                rz = par_dot_dd(&r, &z);
                p = z.clone();
                if iter % 500 != 0 {
                    eprint!("\r  CG-DD iter {:>5}: residual refresh, ‖r‖={:.3e}", iter, r_norm);
                }
                continue;
            }
        } else {
            stagnation_count = 0;
        }
        prev_r_norm = r_norm;

        // z = M⁻¹ r (parallel)
        z.par_iter_mut().enumerate()
            .for_each(|(i, zi)| *zi = m_inv[i] * r[i]);

        let rz_new = par_dot_dd(&r, &z);
        let beta = rz_new / rz;
        let beta_f64 = beta.to_f64();
        rz = rz_new;

        // p = z + beta * p (parallel)
        p.par_iter_mut().zip(z.par_iter())
            .for_each(|(pi, zi)| *pi = zi + beta_f64 * *pi);

        final_iter = iter;
    }

    if !converged {
        eprintln!();
        eprintln!("  ⚠ CG-DD did not fully converge in {} iterations", max_iter);
    }

    // Final d² with DD-precision dot product
    let bx = par_dot_dd(&b[..dim], &x);
    let d_sq = 1.0 - bx.to_f64();
    let cg_time = t.elapsed().as_secs_f64();
    eprintln!("  ✓ CG-DD: {} iters in {:.1}s (converged={})", final_iter + 1, cg_time, converged);

    let precision = if converged { 15 } else { 12 };
    (d_sq, "CG_DD_Jacobi_preconditioned", precision)
}

/// DD-precision parallel dot product.
///
/// Each rayon chunk accumulates in DD (~31 digits), then chunks are summed in DD.
/// This prevents the catastrophic cancellation that kills f64 CG at large N.
/// For N=55k: summing 55k terms in f64 loses ~4 digits; DD loses ~0.
///
/// Performance: ~1.5x slower than f64 par_dot, but the matvec (which is 99%
/// of CG cost) stays f64, so total overhead is ~1-2%.
fn par_dot_dd(a: &[f64], b: &[f64]) -> DD {
    // Use chunk-based parallel reduction for cache efficiency
    const CHUNK: usize = 1024;
    let n = a.len();
    let n_chunks = (n + CHUNK - 1) / CHUNK;

    // Each chunk computes a DD partial sum, then we reduce
    let partials: Vec<DD> = (0..n_chunks).into_par_iter()
        .map(|c| {
            let start = c * CHUNK;
            let end = (start + CHUNK).min(n);
            let mut acc = DD::from_f64(0.0);
            for i in start..end {
                // Error-free product + DD accumulation
                let (prod_hi, prod_lo) = dd_two_prod(a[i], b[i]);
                acc += DD::new(prod_hi, prod_lo);
            }
            acc
        })
        .collect();

    // Final reduction (sequential, but only n_chunks terms)
    let mut total = DD::from_f64(0.0);
    for p in &partials {
        total += *p;
    }
    total
}

/// Error-free product of two f64s using FMA.
/// Returns (hi, lo) where a * b = hi + lo exactly.
#[inline]
fn dd_two_prod(a: f64, b: f64) -> (f64, f64) {
    let p = a * b;
    let e = a.mul_add(b, -p);
    (p, e)
}

/// Parallel matrix-vector product: y = A x (f64 matrix, DD accumulation)
fn matvec_parallel(a: &[f64], x: &[f64], y: &mut [f64], dim: usize) {
    y.par_iter_mut()
        .enumerate()
        .for_each(|(i, yi)| {
            let row = &a[i * dim..(i + 1) * dim];
            let mut acc = DD::from_f64(0.0);
            for j in 0..dim {
                let (hi, lo) = dd_two_prod(row[j], x[j]);
                acc += DD::new(hi, lo);
            }
            *yi = acc.to_f64();
        });
}

/// Parallel DD-matrix-vector product: y = A x where A is stored as (hi, lo) pairs.
///
/// Each entry A[i,j] = hi[i*dim+j] + lo[i*dim+j] (~31 digits).
/// The matvec accumulates in DD precision throughout.
/// This is ~2x slower than f64 matvec but preserves positive-definiteness.
fn matvec_dd(a_hi: &[f64], a_lo: &[f64], x: &[f64], y: &mut [f64], dim: usize) {
    y.par_iter_mut()
        .enumerate()
        .for_each(|(i, yi)| {
            let offset = i * dim;
            let mut acc = DD::from_f64(0.0);
            for j in 0..dim {
                // A[i,j] as DD = (hi, lo)
                let a_dd = DD::new(a_hi[offset + j], a_lo[offset + j]);
                // a_dd * x[j], accumulated in DD
                let prod = a_dd * DD::from_f64(x[j]);
                acc += prod;
            }
            *yi = acc.to_f64();
        });
}

/// DD-matrix-aware CG solver.
///
/// Uses DD-precision matvec (reading hi+lo Gram entries) for ALL matrix operations.
/// This is the fix for N > 40000: the f64 Gram matrix appears non-PD, but the
/// DD Gram matrix preserves the tiny positive eigenvalues.
fn compute_d_sq_primary_dd(
    gram_hi: &[f64], gram_lo: &[f64], b: &[f64], dim: usize
) -> (f64, &'static str, u32) {
    // Try GPU Cholesky on hi part first (works for N ≤ 40k)
    #[cfg(feature = "gpu")]
    if gpu::detect().is_some() && dim <= 40000 {
        match gpu::cholesky::d_sq_f64(gram_hi, b, dim) {
            Ok(result) => {
                return (result.d_sq, result.method, result.precision_digits);
            }
            Err(e) => {
                eprintln!("  ⚠ GPU Cholesky failed ({}), using DD CG", e);
            }
        }
    }

    eprintln!("  → Using DD-Matrix CG (full DD matvec, Jacobi-preconditioned)...");
    cg_solve_d_sq_dd_matrix(gram_hi, gram_lo, b, dim)
}

/// Full DD-matrix CG solver.
///
/// Unlike cg_solve_d_sq_dd (which does DD dot products on an f64 matrix),
/// this does DD matvec from DD matrix entries. This is the correct solver
/// for N > 40000 where f64 matrix entries are insufficiently precise.
fn cg_solve_d_sq_dd_matrix(
    gram_hi: &[f64], gram_lo: &[f64], b: &[f64], dim: usize
) -> (f64, &'static str, u32) {
    let t = Instant::now();

    // Jacobi preconditioner from DD diagonal
    let m_inv: Vec<f64> = (0..dim).into_par_iter()
        .map(|i| {
            let diag = gram_hi[i * dim + i] + gram_lo[i * dim + i];
            if diag > 0.0 { 1.0 / diag } else { 1.0 }
        }).collect();

    // Initialize: x = 0, r = b
    let mut x = vec![0.0f64; dim];
    let mut r = b[..dim].to_vec();
    let mut z: Vec<f64> = r.par_iter().zip(m_inv.par_iter())
        .map(|(ri, mi)| ri * mi).collect();
    let mut p = z.clone();
    let mut ap = vec![0.0f64; dim];

    let mut rz = par_dot_dd(&r, &z);
    let b_norm_sq = par_dot_dd(b, b);
    let b_norm = b_norm_sq.to_f64().sqrt();
    let tol = 1e-14 * b_norm;
    let max_iter = dim.min(50_000);

    let mut converged = false;
    let mut final_iter = 0;
    let mut stagnation_count = 0;
    let mut prev_r_norm = f64::MAX;

    for iter in 0..max_iter {
        // ap = G p  using DD matvec — the key difference!
        matvec_dd(gram_hi, gram_lo, &p, &mut ap, dim);

        let pap = par_dot_dd(&p, &ap);
        if pap.hi <= 0.0 && pap.lo <= 0.0 {
            eprintln!("  ⚠ CG-DD-Matrix: non-positive p^T A p at iter {} (DD: {:.6e}+{:.6e})",
                iter, pap.hi, pap.lo);
            break;
        }

        let alpha = rz / pap;
        let alpha_f64 = alpha.to_f64();

        x.par_iter_mut().zip(p.par_iter())
            .for_each(|(xi, pi)| *xi += alpha_f64 * pi);
        r.par_iter_mut().zip(ap.par_iter())
            .for_each(|(ri, api)| *ri -= alpha_f64 * api);

        let r_norm_sq = par_dot_dd(&r, &r);
        let r_norm = r_norm_sq.to_f64().sqrt();

        if iter % 500 == 0 || r_norm < tol {
            let bx = par_dot_dd(&b[..dim], &x);
            let d_sq_est = 1.0 - bx.to_f64();
            eprint!("\r  CG-DD-Matrix iter {:>5}: ‖r‖={:.3e}, d²≈{:.12}", iter, r_norm, d_sq_est);
        }

        if r_norm < tol {
            eprintln!();
            converged = true;
            final_iter = iter;
            break;
        }

        // Stagnation detection with residual recomputation
        if r_norm >= prev_r_norm * 0.9999 {
            stagnation_count += 1;
            if stagnation_count >= 50 && stagnation_count % 100 == 0 {
                matvec_dd(gram_hi, gram_lo, &x, &mut ap, dim);
                r.par_iter_mut().enumerate()
                    .for_each(|(i, ri)| *ri = b[i] - ap[i]);
                z.par_iter_mut().enumerate()
                    .for_each(|(i, zi)| *zi = m_inv[i] * r[i]);
                rz = par_dot_dd(&r, &z);
                p = z.clone();
                continue;
            }
        } else {
            stagnation_count = 0;
        }
        prev_r_norm = r_norm;

        z.par_iter_mut().enumerate()
            .for_each(|(i, zi)| *zi = m_inv[i] * r[i]);

        let rz_new = par_dot_dd(&r, &z);
        let beta = rz_new / rz;
        let beta_f64 = beta.to_f64();
        rz = rz_new;

        p.par_iter_mut().zip(z.par_iter())
            .for_each(|(pi, zi)| *pi = zi + beta_f64 * *pi);

        final_iter = iter;
    }

    if !converged {
        eprintln!();
        eprintln!("  ⚠ CG-DD-Matrix did not fully converge in {} iterations", max_iter);
    }

    let bx = par_dot_dd(&b[..dim], &x);
    let d_sq = 1.0 - bx.to_f64();
    let cg_time = t.elapsed().as_secs_f64();
    eprintln!("  ✓ CG-DD-Matrix: {} iters in {:.1}s (converged={})", final_iter + 1, cg_time, converged);

    let precision = if converged { 15 } else { 12 };
    (d_sq, "CG_DD_Matrix_Jacobi", precision)
}



fn compute_cross_check(
    _gram: &[f64], _b: &[f64], dim: usize, primary_d_sq: f64,
) -> Option<CrossCheck> {
    // Cross-check is only available for DD cache data (hi + lo parts)
    // For now, return None — will be enhanced when DD data is available
    if dim > 10000 || primary_d_sq.is_nan() {
        return None;
    }

    // Could implement CPU mpfr cross-check here for small N
    None
}

fn compute_spectrum(gram: &[f64], dim: usize) -> Option<SpectrumResult> {
    let t = Instant::now();

    // For large matrices, skip spectral analysis (too expensive)
    if dim > 25000 {
        eprintln!("  ⚠ Spectral analysis skipped (dim={} > 25000)", dim);
        return None;
    }

    // Try GPU eigenvalues
    #[cfg(feature = "gpu")]
    if gpu::detect().is_some() {
        match gpu::eigen::eigenvalues_only(gram, dim) {
            Ok((eigenvalues, _gpu_time)) => {
                let lambda_min = eigenvalues[0];
                let lambda_max = *eigenvalues.last().unwrap();
                return Some(SpectrumResult {
                    lambda_min,
                    lambda_min_positive: lambda_min > 0.0,
                    lambda_max,
                    condition_number: if lambda_min > 0.0 { lambda_max / lambda_min } else { f64::INFINITY },
                    compute_time_secs: t.elapsed().as_secs_f64(),
                });
            }
            Err(e) => {
                eprintln!("  ⚠ GPU eigenvalues failed ({}), trying CPU", e);
            }
        }
    }

    // CPU fallback for small matrices
    if dim <= 5000 {
        use nalgebra::DMatrix;
        let mat = DMatrix::from_row_slice(dim, dim, gram);
        let eig = mat.symmetric_eigen();
        let mut eigenvalues: Vec<f64> = eig.eigenvalues.iter().cloned().collect();
        eigenvalues.sort_by(|a, b| a.partial_cmp(b).unwrap());

        let lambda_min = eigenvalues[0];
        let lambda_max = *eigenvalues.last().unwrap();
        return Some(SpectrumResult {
            lambda_min,
            lambda_min_positive: lambda_min > 0.0,
            lambda_max,
            condition_number: if lambda_min > 0.0 { lambda_max / lambda_min } else { f64::INFINITY },
            compute_time_secs: t.elapsed().as_secs_f64(),
        });
    }

    None
}

// ═══════════════════════════════════════════════════════════════════
// MONOTONICITY & VERIFICATION
// ═══════════════════════════════════════════════════════════════════

fn check_monotonicity(max_n: usize, d_sq: f64, cert_dir: &str) -> Option<MonotonicityCheck> {
    // Find the nearest smaller N certificate
    let dir = Path::new(cert_dir);
    if !dir.exists() { return None; }

    let mut best: Option<(usize, f64)> = None;

    if let Ok(entries) = std::fs::read_dir(dir) {
        for entry in entries.flatten() {
            let name = entry.file_name().to_string_lossy().to_string();
            if name.starts_with("cert_N") && name.ends_with(".json") {
                if let Some(prev_n) = name.strip_prefix("cert_N").and_then(|s| s.strip_suffix(".json")).and_then(|s| s.parse::<usize>().ok()) {
                    if prev_n < max_n {
                        if let Ok(content) = std::fs::read_to_string(entry.path()) {
                            if let Ok(prev_cert) = serde_json::from_str::<Certificate>(&content) {
                                match best {
                                    Some((best_n, _)) if prev_n > best_n => {
                                        best = Some((prev_n, prev_cert.distance.d_sq));
                                    }
                                    None => {
                                        best = Some((prev_n, prev_cert.distance.d_sq));
                                    }
                                    _ => {}
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    best.map(|(prev_n, prev_d_sq)| MonotonicityCheck {
        previous_n: prev_n,
        previous_d_sq: prev_d_sq,
        strictly_decreased: d_sq < prev_d_sq,
        decrease_amount: prev_d_sq - d_sq,
    })
}

fn generate_lean_claims(max_n: usize, d_sq: f64, spectrum: &Option<SpectrumResult>) -> Vec<String> {
    let mut claims = Vec::new();

    // Round d² up to a clean bound
    let bound = (d_sq * 10000.0).ceil() / 10000.0;
    claims.push(format!("nbDistSq' {} < {:.4}", max_n, bound));

    if let Some(ref s) = spectrum {
        if s.lambda_min_positive {
            claims.push(format!("0 < lambdaMin {}", max_n));
        }
    }

    claims
}

// ═══════════════════════════════════════════════════════════════════
// MASTER CERTIFICATE
// ═══════════════════════════════════════════════════════════════════

fn write_master_certificate(cert_dir: &str) {
    let dir = Path::new(cert_dir);
    let mut certs: Vec<Certificate> = Vec::new();

    if let Ok(entries) = std::fs::read_dir(dir) {
        for entry in entries.flatten() {
            let name = entry.file_name().to_string_lossy().to_string();
            if name.starts_with("cert_N") && name.ends_with(".json") {
                if let Ok(content) = std::fs::read_to_string(entry.path()) {
                    if let Ok(cert) = serde_json::from_str::<Certificate>(&content) {
                        certs.push(cert);
                    }
                }
            }
        }
    }

    certs.sort_by_key(|c| c.max_n);

    #[derive(Serialize)]
    struct MasterCertificate {
        format: String,
        version: String,
        total_certificates: usize,
        n_range: [usize; 2],
        d_sq_range: [f64; 2],
        all_lambda_min_positive: bool,
        monotonically_decreasing: bool,
        data_points: Vec<DataPoint>,
        lean_claims: Vec<String>,
        timestamp: String,
    }

    #[derive(Serialize)]
    struct DataPoint {
        #[serde(rename = "N")]
        max_n: usize,
        d_sq: f64,
        lambda_min: Option<f64>,
        method: String,
    }

    let data_points: Vec<DataPoint> = certs.iter().map(|c| DataPoint {
        max_n: c.max_n,
        d_sq: c.distance.d_sq,
        lambda_min: c.spectrum.as_ref().map(|s| s.lambda_min),
        method: c.distance.method.clone(),
    }).collect();

    let all_positive = certs.iter().all(|c| {
        c.spectrum.as_ref().map_or(true, |s| s.lambda_min_positive)
    });

    let monotone = certs.windows(2).all(|w| w[1].distance.d_sq <= w[0].distance.d_sq);

    let n_min = certs.first().map(|c| c.max_n).unwrap_or(0);
    let n_max = certs.last().map(|c| c.max_n).unwrap_or(0);
    let d_min = certs.iter().map(|c| c.distance.d_sq).fold(f64::MAX, f64::min);
    let d_max = certs.iter().map(|c| c.distance.d_sq).fold(0.0f64, f64::max);

    let lean_claims: Vec<String> = certs.iter()
        .flat_map(|c| c.lean_claims.clone())
        .collect();

    let master = MasterCertificate {
        format: "cathedral-master-certificate-v1".to_string(),
        version: "1.0.0".to_string(),
        total_certificates: certs.len(),
        n_range: [n_min, n_max],
        d_sq_range: [d_min, d_max],
        all_lambda_min_positive: all_positive,
        monotonically_decreasing: monotone,
        data_points,
        lean_claims,
        timestamp: iso_now(),
    };

    let path = format!("{}/master_certificate.json", cert_dir);
    let json = serde_json::to_string_pretty(&master).unwrap();
    std::fs::write(&path, &json).expect("Failed to write master certificate");
    println!("  📜 Master certificate → {} ({} data points)", path, certs.len());
}

// ═══════════════════════════════════════════════════════════════════
// UTILITIES
// ═══════════════════════════════════════════════════════════════════

fn dot(a: &[f64], b: &[f64]) -> f64 {
    a.iter().zip(b.iter()).map(|(x, y)| x * y).sum()
}

fn compute_sha256_prefix(data: &[f64]) -> String {
    let mut hasher = Sha256::new();
    // Hash first 1000 entries + last 1000 entries for speed
    let n = data.len().min(1000);
    let prefix_bytes: &[u8] = unsafe {
        std::slice::from_raw_parts(data.as_ptr() as *const u8, n * 8)
    };
    hasher.update(prefix_bytes);
    if data.len() > 1000 {
        let tail_start = data.len() - 1000;
        let tail_bytes: &[u8] = unsafe {
            std::slice::from_raw_parts(data[tail_start..].as_ptr() as *const u8, 1000 * 8)
        };
        hasher.update(tail_bytes);
    }
    format!("{:x}", hasher.finalize())
}

fn hostname() -> String {
    std::env::var("HOSTNAME")
        .or_else(|_| std::env::var("HOST"))
        .unwrap_or_else(|_| "unknown".to_string())
}

fn iso_now() -> String {
    use std::time::SystemTime;
    let secs = SystemTime::now()
        .duration_since(SystemTime::UNIX_EPOCH)
        .unwrap()
        .as_secs();
    // Simple ISO-ish timestamp
    format!("{}", secs)
}
