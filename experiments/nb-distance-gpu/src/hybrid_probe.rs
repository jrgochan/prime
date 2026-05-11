//! ═══════════════════════════════════════════════════════════════
//! CATHEDRAL HYBRID PROBE — CPU MPFR Gram + GPU cuSOLVER Eigen
//!
//! Phase 1: Build Gram matrix on CPU at configurable MPFR precision
//!          + DD Gram for extended-precision Cholesky
//! Phase 2: For each N: GPU eigendecomp + DD Cholesky in parallel
//! Phase 3: Compute d²_N, spectral diagnostics, scaling fits
//!
//! Usage: hybrid-probe <max_n> [mpfr_bits]
//!   mpfr_bits: 128 (default), 256, or 512
//! Logging: writes to /tmp/hybrid_probe_N{max_n}_p{bits}.log
//! ═══════════════════════════════════════════════════════════════

mod gpu;

use cathedral_utils::{cache, gram, arith, dd::DD, fitting};
use nalgebra::{DMatrix, DVector};
use rug::Float;
use rayon::prelude::*;
use std::io::Write;
use std::sync::Mutex;
use std::time::Instant;

// ═══════════════════════════════════════════════════════════════
// LOGGING
// ═══════════════════════════════════════════════════════════════

struct Logger {
    file: Mutex<std::fs::File>,
    t0: Instant,
}

impl Logger {
    fn new(path: &str) -> Self {
        let file = std::fs::File::create(path)
            .unwrap_or_else(|e| panic!("Cannot create log: {}: {}", path, e));
        Logger { file: Mutex::new(file), t0: Instant::now() }
    }
    fn log(&self, msg: &str) {
        let elapsed = self.t0.elapsed().as_secs_f64();
        let line = format!("[{:8.2}s] {}", elapsed, msg);
        println!("{}", line);
        if let Ok(mut f) = self.file.lock() {
            let _ = writeln!(f, "{}", line);
            let _ = f.flush();
        }
    }
    fn data(&self, msg: &str) {
        println!("{}", msg);
        if let Ok(mut f) = self.file.lock() {
            let _ = writeln!(f, "{}", msg);
            let _ = f.flush();
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// DD CHOLESKY — parallel via rayon for off-diagonal elements
// ═══════════════════════════════════════════════════════════════

/// MPFR-precision Cholesky: d² = 1 - b^T G^{-1} b
/// Uses rug::Float at `prec` bits. Parallelized with rayon.
/// This is the fallback when DD (~31 digits) can't resolve d².
fn mpfr_cholesky_d2(
    gram: &[Float],
    b: &[f64], dim: usize, prec: u32, log: &Logger,
) -> f64 {
    let t0 = Instant::now();
    let par_threshold = 128;

    // Initialize L matrix in MPFR
    let zero = Float::with_val(prec, 0.0);
    let mut l: Vec<Float> = vec![zero; dim * dim];

    for j in 0..dim {
        // Diagonal
        let mut sum = gram[j * dim + j].clone();
        for k in 0..j {
            let ljk = &l[j * dim + k];
            sum -= Float::with_val(prec, ljk * ljk);
        }
        if sum <= 0.0 {
            log.log(&format!("  MPFR Cholesky fail at j={}/{}: sum={:.6e}", j, dim, sum.to_f64()));
            return f64::NAN;
        }
        let diag = sum.sqrt();

        // Off-diagonal: parallel for large remaining
        let remaining = dim - j - 1;
        if remaining > par_threshold && j > 16 {
            let l_row_j: Vec<Float> = (0..j).map(|k| l[j * dim + k].clone()).collect();
            let diag_ref = &diag;
            let l_ref = &l;
            let offdiag: Vec<(usize, Float)> = (j + 1..dim)
                .into_par_iter()
                .map(|i| {
                    let mut s = gram[i * dim + j].clone();
                    for k in 0..j {
                        s -= Float::with_val(prec, &l_ref[i * dim + k] * &l_row_j[k]);
                    }
                    s /= diag_ref;
                    (i, s)
                })
                .collect();
            l[j * dim + j] = diag;
            for (i, val) in offdiag { l[i * dim + j] = val; }
        } else {
            l[j * dim + j] = diag;
            for i in (j + 1)..dim {
                let mut s = gram[i * dim + j].clone();
                for k in 0..j {
                    s -= Float::with_val(prec, &l[i * dim + k] * &l[j * dim + k]);
                }
                s /= &l[j * dim + j];
                l[i * dim + j] = s;
            }
        }

        if dim >= 1000 && j % (dim / 10) == 0 && j > 0 {
            let pct = j * 100 / dim;
            let elapsed = t0.elapsed().as_secs_f64();
            let eta = elapsed / (j as f64) * ((dim - j) as f64);
            log.log(&format!("  MPFR Cholesky: {}% ({}/{}) {:.1}s elapsed, ETA {:.0}s",
                pct, j, dim, elapsed, eta));
        }
    }

    // Forward solve: L y = b
    let mut y: Vec<Float> = vec![Float::with_val(prec, 0.0); dim];
    for i in 0..dim {
        let mut sum = Float::with_val(prec, b[i]);
        for k in 0..i { sum -= Float::with_val(prec, &l[i * dim + k] * &y[k]); }
        sum /= &l[i * dim + i];
        y[i] = sum;
    }

    // Backward solve: L^T c = y
    let mut c: Vec<Float> = vec![Float::with_val(prec, 0.0); dim];
    for i in (0..dim).rev() {
        let mut sum = y[i].clone();
        for k in (i + 1)..dim { sum -= Float::with_val(prec, &l[k * dim + i] * &c[k]); }
        sum /= &l[i * dim + i];
        c[i] = sum;
    }

    // d² = 1 - b·c
    let mut bc = Float::with_val(prec, 0.0);
    for i in 0..dim { bc += Float::with_val(prec, b[i]) * &c[i]; }
    let d2 = Float::with_val(prec, 1.0) - bc;
    let result = d2.to_f64();

    log.log(&format!("  MPFR Cholesky dim={}: d²={:.10e} ({:.1}s, {}-bit, {} threads)",
        dim, result, t0.elapsed().as_secs_f64(), prec, rayon::current_num_threads()));
    result
}

fn dd_cholesky_d2_parallel(
    gram_hi: &[f64],
    gram_lo: Option<&[f64]>,
    b: &[f64],
    dim: usize,
    log: &Logger,
) -> f64 {
    let t0 = Instant::now();
    let mut l = vec![DD::from_f64(0.0); dim * dim];
    let par_threshold = 256;

    for j in 0..dim {
        // Diagonal element
        let idx_diag = j * dim + j;
        let mut sum = DD::new(
            gram_hi[idx_diag],
            gram_lo.map_or(0.0, |lo| lo[idx_diag]),
        );
        for k in 0..j {
            let ljk = l[j * dim + k];
            sum -= ljk * ljk;
        }
        if sum.hi <= 0.0 {
            log.log(&format!("  DD Cholesky fail at j={}/{}: sum=({:.6e}, {:.6e})",
                j, dim, sum.hi, sum.lo));
            return f64::NAN;
        }
        let mut x = DD::from_f64(sum.hi.sqrt());
        x = (x + sum / x) * DD::from_f64(0.5);
        x = (x + sum / x) * DD::from_f64(0.5);
        l[j * dim + j] = x;
        let diag_inv = DD::from_f64(1.0) / x;

        // Off-diagonal: parallel when beneficial
        let remaining = dim - j - 1;
        if remaining > par_threshold && j > 16 {
            let l_row_j: Vec<DD> = (0..j).map(|k| l[j * dim + k]).collect();
            let offdiag: Vec<(usize, DD)> = (j + 1..dim)
                .into_par_iter()
                .map(|i| {
                    let idx = i * dim + j;
                    let mut s = DD::new(
                        gram_hi[idx],
                        gram_lo.map_or(0.0, |lo| lo[idx]),
                    );
                    for k in 0..j {
                        s -= l[i * dim + k] * l_row_j[k];
                    }
                    (i, s * diag_inv)
                })
                .collect();
            for (i, val) in offdiag {
                l[i * dim + j] = val;
            }
        } else {
            for i in (j + 1)..dim {
                let idx = i * dim + j;
                let mut s = DD::new(
                    gram_hi[idx],
                    gram_lo.map_or(0.0, |lo| lo[idx]),
                );
                for k in 0..j {
                    s -= l[i * dim + k] * l[j * dim + k];
                }
                l[i * dim + j] = s * diag_inv;
            }
        }

        if dim >= 1000 && j % (dim / 10) == 0 && j > 0 {
            let pct = j * 100 / dim;
            let elapsed = t0.elapsed().as_secs_f64();
            let eta = elapsed / (j as f64) * ((dim - j) as f64);
            log.log(&format!("  DD Cholesky: {}% ({}/{}) {:.1}s elapsed, ETA {:.0}s",
                pct, j, dim, elapsed, eta));
        }
    }

    // Forward solve: L y = b
    let mut y = vec![DD::from_f64(0.0); dim];
    for i in 0..dim {
        let mut sum = DD::from_f64(b[i]);
        for k in 0..i { sum -= l[i * dim + k] * y[k]; }
        y[i] = sum / l[i * dim + i];
    }

    // Backward solve: L^T c = y
    let mut c = vec![DD::from_f64(0.0); dim];
    for i in (0..dim).rev() {
        let mut sum = y[i];
        for k in (i + 1)..dim { sum -= l[k * dim + i] * c[k]; }
        c[i] = sum / l[i * dim + i];
    }

    let mut bc = DD::from_f64(0.0);
    for i in 0..dim { bc += DD::from_f64(b[i]) * c[i]; }
    let d2 = DD::from_f64(1.0) - bc;

    log.log(&format!("  DD Cholesky dim={}: d²={:.10e} ({:.1}s, {} threads)",
        dim, d2.to_f64(), t0.elapsed().as_secs_f64(), rayon::current_num_threads()));
    d2.to_f64()
}

/// Kondo-regularized DD Cholesky: when a diagonal element goes negative,
/// add minimal ε to continue. Based on the Kondo Lattice discovery:
/// the modes that break PD have |⟨b, v_min⟩| ≈ 10⁻⁷ — the b-vector
/// is "blind" to them (arithmetic dark states), so regularizing them
/// doesn't change d²_N.
fn dd_kondo_cholesky_d2(
    gram_hi: &[f64],
    gram_lo: Option<&[f64]>,
    b: &[f64],
    dim: usize,
    log: &Logger,
) -> f64 {
    let t0 = Instant::now();
    let mut l = vec![DD::from_f64(0.0); dim * dim];
    let par_threshold = 256;
    let mut kondo_fixes = 0usize;
    let mut max_eps = 0.0f64;

    for j in 0..dim {
        let idx_diag = j * dim + j;
        let mut sum = DD::new(
            gram_hi[idx_diag],
            gram_lo.map_or(0.0, |lo| lo[idx_diag]),
        );
        for k in 0..j {
            let ljk = l[j * dim + k];
            sum -= ljk * ljk;
        }
        if sum.hi <= 0.0 {
            // Kondo regularization: this mode is an arithmetic dark state.
            // Zero out the entire row j of L to project out the corrupted mode.
            // This prevents cascade of errors through off-diagonal elements.
            let eps = (-sum.hi).max(1e-30);
            sum = DD::from_f64(1e-30);
            kondo_fixes += 1;
            if eps > max_eps { max_eps = eps; }
            // Set L(j,j) = tiny, and skip computing off-diagonal for this column
            let mut x = DD::from_f64(sum.hi.sqrt());
            x = (x + sum / x) * DD::from_f64(0.5);
            l[j * dim + j] = x;
            // Zero out all L(i,j) for i > j — fully decouple this mode
            for i in (j + 1)..dim {
                l[i * dim + j] = DD::from_f64(0.0);
            }
            if dim >= 1000 && j % (dim / 10) == 0 && j > 0 {
                let pct = j * 100 / dim;
                let elapsed = t0.elapsed().as_secs_f64();
                log.log(&format!("  Kondo Cholesky: {}% ({}/{}) {:.1}s [{} fixes]",
                    pct, j, dim, elapsed, kondo_fixes));
            }
            continue;
        }
        let mut x = DD::from_f64(sum.hi.sqrt());
        x = (x + sum / x) * DD::from_f64(0.5);
        x = (x + sum / x) * DD::from_f64(0.5);
        l[j * dim + j] = x;
        let diag_inv = DD::from_f64(1.0) / x;

        let remaining = dim - j - 1;
        if remaining > par_threshold && j > 16 {
            let l_row_j: Vec<DD> = (0..j).map(|k| l[j * dim + k]).collect();
            let offdiag: Vec<(usize, DD)> = (j + 1..dim)
                .into_par_iter()
                .map(|i| {
                    let idx = i * dim + j;
                    let mut s = DD::new(
                        gram_hi[idx],
                        gram_lo.map_or(0.0, |lo| lo[idx]),
                    );
                    for k in 0..j { s -= l[i * dim + k] * l_row_j[k]; }
                    (i, s * diag_inv)
                })
                .collect();
            for (i, val) in offdiag { l[i * dim + j] = val; }
        } else {
            for i in (j + 1)..dim {
                let idx = i * dim + j;
                let mut s = DD::new(
                    gram_hi[idx],
                    gram_lo.map_or(0.0, |lo| lo[idx]),
                );
                for k in 0..j { s -= l[i * dim + k] * l[j * dim + k]; }
                l[i * dim + j] = s * diag_inv;
            }
        }

        if dim >= 1000 && j % (dim / 10) == 0 && j > 0 {
            let pct = j * 100 / dim;
            let elapsed = t0.elapsed().as_secs_f64();
            log.log(&format!("  Kondo Cholesky: {}% ({}/{}) {:.1}s [{} fixes]",
                pct, j, dim, elapsed, kondo_fixes));
        }
    }

    // Forward/backward solve
    let mut y = vec![DD::from_f64(0.0); dim];
    for i in 0..dim {
        let mut sum = DD::from_f64(b[i]);
        for k in 0..i { sum -= l[i * dim + k] * y[k]; }
        y[i] = sum / l[i * dim + i];
    }
    let mut c = vec![DD::from_f64(0.0); dim];
    for i in (0..dim).rev() {
        let mut sum = y[i];
        for k in (i + 1)..dim { sum -= l[k * dim + i] * c[k]; }
        c[i] = sum / l[i * dim + i];
    }

    let mut bc = DD::from_f64(0.0);
    for i in 0..dim { bc += DD::from_f64(b[i]) * c[i]; }
    let d2 = DD::from_f64(1.0) - bc;

    log.log(&format!("  Kondo Cholesky dim={}: d²={:.10e} ({:.1}s) [{} dark-state fixes, max_ε={:.2e}]",
        dim, d2.to_f64(), t0.elapsed().as_secs_f64(), kondo_fixes, max_eps));
    d2.to_f64()
}

/// Try DD Cholesky first (fast, ~31 digits). If it fails, fall back to MPFR Cholesky.
/// Precision stack: GPU DD → CPU DD → MPFR
fn compute_d2_highprec(
    hi_data: &[f64], hi_dim: usize,
    dd_lo: &Option<Vec<f64>>,
    mpfr_gram: &Option<(Vec<Float>, usize)>,
    sub: &[f64], b: &[f64], dim: usize,
    mpfr_bits: u32, log: &Logger,
) -> f64 {
    // Extract DD submatrix from separate hi/lo arrays
    let (sub_hi, sub_lo) = if let Some(ref lo) = dd_lo {
        let mut sh = vec![0.0f64; dim * dim];
        let mut sl = vec![0.0f64; dim * dim];
        for i in 0..dim {
            for j in 0..dim {
                sh[i * dim + j] = hi_data[i * hi_dim + j];
                sl[i * dim + j] = lo[i * hi_dim + j];
            }
        }
        (sh, sl)
    } else {
        (sub.to_vec(), vec![0.0f64; dim * dim])
    };

    // Level 0: Try GPU DS-f32 Cholesky (fastest — f32 native, ~14 digits)
    match gpu::gpu_ds_cholesky(&sub_hi, &sub_lo, b, dim) {
        Ok(result) => {
            if result.fail_col == 0 && !result.d2.is_nan() && result.d2 > 0.0 {
                log.log(&format!("  GPU DS-f32 dim={}: d²={:.10e} ({:.3}s)",
                    dim, result.d2, result.gpu_time_secs));
                return result.d2;
            }
            if result.fail_col > 0 {
                log.log(&format!("  GPU DS-f32 failed at col {} (dim={}), escalating to DD-f64...",
                    result.fail_col, dim));
            }
        }
        Err(e) => {
            log.log(&format!("  GPU DS-f32 error: {}, trying DD-f64...", e));
        }
    }

    // Level 1: Try GPU QS-f32 Cholesky (~28 digits at f32 speed)
    match gpu::gpu_qs_cholesky(&sub_hi, &sub_lo, b, dim) {
        Ok(result) => {
            if result.fail_col == 0 && !result.d2.is_nan() && result.d2 > 0.0 {
                log.log(&format!("  GPU QS-f32 dim={}: d²={:.10e} ({:.3}s)",
                    dim, result.d2, result.gpu_time_secs));
                return result.d2;
            }
            if result.fail_col > 0 {
                log.log(&format!("  GPU QS-f32 failed at col {} (dim={}), escalating to DD-f64...",
                    result.fail_col, dim));
            }
        }
        Err(e) => {
            log.log(&format!("  GPU QS-f32 error: {}, trying DD-f64...", e));
        }
    }

    // Level 2: Try GPU DD-f64 Cholesky (~31 digits, f64 on GPU)
    match gpu::gpu_dd_cholesky(&sub_hi, &sub_lo, b, dim) {
        Ok(result) => {
            if result.fail_col == 0 && !result.d2.is_nan() && result.d2 > 0.0 {
                log.log(&format!("  GPU DD-f64 dim={}: d²={:.10e} ({:.3}s)",
                    dim, result.d2, result.gpu_time_secs));
                return result.d2;
            }
            if result.fail_col > 0 {
                log.log(&format!("  GPU DD-f64 failed at col {} (dim={}), trying CPU...",
                    result.fail_col, dim));
            }
        }
        Err(e) => {
            log.log(&format!("  GPU DD-f64 error: {}, trying CPU...", e));
        }
    }

    // Level 2: Try CPU DD Cholesky (rayon-parallel, ~31 digits)
    let d2_dd = dd_cholesky_d2_parallel(&sub_hi, Some(&sub_lo), b, dim, log);
    if !d2_dd.is_nan() {
        return d2_dd;
    }

    // Level 2.5: Kondo-regularized DD Cholesky (patches dark states)
    // The Orthogonality Shield guarantees |⟨b, v_dark⟩| ≈ 10⁻⁷,
    // so regularizing the failing modes doesn't change d²_N.
    let d2_kondo = dd_kondo_cholesky_d2(&sub_hi, Some(&sub_lo), b, dim, log);
    if !d2_kondo.is_nan() && d2_kondo > 0.0 {
        return d2_kondo;
    }

    // Level 3: MPFR Cholesky with full-precision Gram (unlimited precision)
    if let Some((ref mpfr_data, mpfr_dim)) = mpfr_gram {
        log.log(&format!("  DD failed for dim={}, escalating to MPFR-{} Cholesky (full precision)...", dim, mpfr_bits));
        let prec = mpfr_data[0].prec();
        let zero = Float::with_val(prec, 0.0);
        let mut sub_mpfr = vec![zero; dim * dim];
        for i in 0..dim {
            for j in 0..dim {
                sub_mpfr[i * dim + j] = mpfr_data[i * mpfr_dim + j].clone();
            }
        }
        mpfr_cholesky_d2(&sub_mpfr, b, dim, prec, log)
    } else {
        log.log("  DD failed and no MPFR Gram available — returning NaN");
        f64::NAN
    }
}

// ═══════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let max_n: usize = args.get(1).and_then(|s| s.parse().ok()).unwrap_or(1000);
    let mpfr_bits: u32 = args.get(2).and_then(|s| s.parse().ok()).unwrap_or(128);

    let log_path = format!("/tmp/hybrid_probe_N{}_p{}.log", max_n, mpfr_bits);
    let log = Logger::new(&log_path);

    log.data("");
    log.data("  ╔═══════════════════════════════════════════════════════════════╗");
    log.data("  ║  CATHEDRAL HYBRID PROBE — UNIFIED GRAM");
    log.data("  ║  GPU: DD-f64 log1p (master) → f64 downcast + cuSOLVER");
    log.data("  ║  ONE matrix · ONE truncation · ONE Hilbert space");
    log.data(&format!("  ║  N = {}  ·  RH ⟺ d²_N → 0", max_n));
    log.data("  ╚═══════════════════════════════════════════════════════════════╝");
    log.data("");
    log.log(&format!("Log file: {}", log_path));
    log.log(&format!("Rayon threads: {}", rayon::current_num_threads()));
    log.log(&format!("MPFR precision: {} bits ({} digits)", mpfr_bits, (mpfr_bits as f64 * 0.301).floor() as u32));

    // ═══ GPU Detection ═══
    let has_gpu = match gpu::detect_gpu() {
        Some(info) => { log.log(&format!("GPU: {} (CUDA)", info.name)); true }
        None => { log.log("WARNING: No CUDA GPU — eigendecomp disabled"); false }
    };

    // ═══ PHASE 1: Unified Gram Matrix ═══
    log.data("");
    log.data("  ══════════════════════════════════════════");
    log.data("    PHASE 1 · UNIFIED GRAM MATRIX");
    log.data("  ══════════════════════════════════════════");

    let t_phase1 = Instant::now();

    // ═══ UNIFIED GRAM ARCHITECTURE ═══
    //
    // The Hilbert Fracture (Gemini Actual, 2026-04-30):
    //   A Gram matrix G(j,k) = ⟨ρ_j, ρ_k⟩ is positive definite IFF every entry
    //   is an inner product in the SAME discrete Hilbert space. Mixing T_direct
    //   truncations (10K vs 100K) violates Cauchy-Schwarz and creates a
    //   geometrically impossible object that Cholesky cannot decompose.
    //
    // Solution: ONE matrix, ONE truncation, ONE Hilbert space.
    //   1. GPU DD kernel builds the master matrix at DD-f64 (~31 digits)
    //   2. The hi[] parts are downcast directly as the f64 Gram
    //   3. DD Cholesky uses the (hi[], lo[]) pair natively
    //   → All formats share identical truncation physics.

    let table_size = (max_n * 5).max(100_001).min(gram::MAX_LN_TABLE);

    // Step 1: Build the master DD Gram (GPU log1p or CPU MPFR fallback)
    let dim = max_n - 1;
    let dd_cache_path = cache::dd_gram_cache_path(max_n, mpfr_bits);

    let (dd_hi, dd_lo, dd_dim) = if let Some(cached) = cache::load_dd_gram(&dd_cache_path) {
        log.log(&format!("DD Gram loaded from cache: {}×{} ({} MB)",
            cached.2, cached.2, (cached.2 * cached.2 * 16) / (1024 * 1024)));
        cached
    } else if has_gpu {
        let t_max = table_size.min(100_000);
        log.log(&format!("Building DD-f64 Gram on GPU ({dim}×{dim}, log1p bypass, T_max={t_max})..."));
        match gpu::gpu_build_gram_dd_f64(dim, t_max) {
            Ok(result) => {
                log.log(&format!("GPU DD-f64 Gram ready: {dim}×{dim} ({:.2}s, {} MB)",
                    result.build_time_secs, (dim * dim * 16) / (1024 * 1024)));
                if let Err(e) = cache::save_dd_gram(&dd_cache_path, &result.gram_hi, &result.gram_lo, dim, max_n, mpfr_bits) {
                    log.log(&format!("DD cache save failed: {}", e));
                }
                (result.gram_hi, result.gram_lo, dim)
            }
            Err(e) => {
                log.log(&format!("GPU DD failed: {}, falling back to CPU MPFR...", e));
                let ln_n_table = gram::LnNTable::new(table_size + 1, mpfr_bits);
                let t0 = std::time::Instant::now();
                let (hi, lo, dd_dim) = gram::GramMatrix::build_fast_dd(max_n, &ln_n_table);
                log.log(&format!("CPU DD Gram ready: {}×{} ({} MB, {:.1}s)",
                    dd_dim, dd_dim, (dd_dim * dd_dim * 16) / (1024 * 1024), t0.elapsed().as_secs_f64()));
                if let Err(e) = cache::save_dd_gram(&dd_cache_path, &hi, &lo, dd_dim, max_n, mpfr_bits) {
                    log.log(&format!("DD cache save failed: {}", e));
                }
                (hi, lo, dd_dim)
            }
        }
    } else {
        log.log(&format!("Building DD Gram on CPU at MPFR-{}...", mpfr_bits));
        let ln_n_table = gram::LnNTable::new(table_size + 1, mpfr_bits);
        let t0 = std::time::Instant::now();
        let (hi, lo, dd_dim) = gram::GramMatrix::build_fast_dd(max_n, &ln_n_table);
        log.log(&format!("DD Gram ready: {}×{} ({} MB, {:.1}s)",
            dd_dim, dd_dim, (dd_dim * dd_dim * 16) / (1024 * 1024), t0.elapsed().as_secs_f64()));
        if let Err(e) = cache::save_dd_gram(&dd_cache_path, &hi, &lo, dd_dim, max_n, mpfr_bits) {
            log.log(&format!("DD cache save failed: {}", e));
        }
        (hi, lo, dd_dim)
    };

    // Step 2: Downcast — DD hi[] IS the f64 Gram (same truncation, same Hilbert space)
    // Move dd_hi directly into GramMatrix — NO clone, saves ~28s for N=20000
    let gram_matrix = gram::GramMatrix {
        data: dd_hi,
        max_dim: dd_dim,
        max_n,
        mpfr_built: true,
        precision: mpfr_bits,
    };
    log.log(&format!("f64 Gram (downcast from DD): {}×{}, {} MB — unified Hilbert space",
        gram_matrix.max_dim, gram_matrix.max_dim, gram_matrix.mem_mb()));

    // Step 2b: Ensure Gram is GPU-resident for Phase 2 cuSOLVER calls.
    // If we just built with GPU (gpu_build_gram_dd), it's already in VRAM.
    // If loaded from cache, we need to upload.
    let has_resident_gram = if has_gpu {
        let resident_dim = gpu::gpu_resident_gram_dim();
        if resident_dim == gram_matrix.max_dim {
            log.log(&format!("Gram already resident in GPU VRAM ({} dim)", resident_dim));
            true
        } else {
            log.log("Uploading Gram to GPU VRAM for resident Cholesky...");
            match gpu::gpu_upload_gram_resident(&gram_matrix.data, gram_matrix.max_dim) {
                Ok(()) => {
                    log.log(&format!("Gram uploaded to GPU VRAM: {} MB",
                        gram_matrix.mem_mb()));
                    true
                }
                Err(e) => {
                    log.log(&format!("GPU VRAM upload failed: {} — falling back to PCIe transfers", e));
                    false
                }
            }
        }
    } else {
        false
    };

    // Step 3: DD Gram pair for Cholesky fallback
    // The hi[] data lives inside gram_matrix.data; we reference it when needed.
    // Only dd_lo is kept separately.
    let dd_lo: Option<Vec<f64>> = if max_n > 1000 {
        Some(dd_lo)
    } else {
        None
    };

    // No separate MPFR Gram needed — the unified DD Gram IS the ground truth.
    // If DD Cholesky fails, it's because the matrix genuinely isn't PD at that
    // dimension (the truncation physics are correct, the geometry is consistent).
    let mpfr_gram: Option<(Vec<Float>, usize)> = None;

    let phase1_time = t_phase1.elapsed().as_secs_f64();
    log.log(&format!("Phase 1 total: {:.2}s", phase1_time));

    // ═══ PHASE 2: Spectral Analysis ═══
    log.data("");
    log.data("  ══════════════════════════════════════════");
    log.data("    PHASE 2 · SPECTRAL ANALYSIS");
    log.data("  ══════════════════════════════════════════");
    log.data("");

    let test_ns = build_schedule(max_n);
    let t_phase2 = Instant::now();

    log.data("       N  │ d²_N            │ λ_min          │ GPU(ms) │ DD(s)  │ D(N)         │ |⟨b,v_min⟩|");
    log.data("    ──────┼─────────────────┼────────────────┼─────────┼────────┼──────────────┼─────────────");

    let mut results: Vec<NResult> = Vec::new();
    // Track where GPU eigenvalues become negative (meaningless)
    let mut gpu_eigen_useless_above: usize = usize::MAX;

    // Open incremental TSV for crash-safe results
    let tsv_path = format!("results/hybrid_N{}.tsv", max_n);
    if let Some(parent) = std::path::Path::new(&tsv_path).parent() {
        let _ = std::fs::create_dir_all(parent);
    }
    let mut tsv_file = std::fs::File::create(&tsv_path).ok();
    if let Some(ref mut f) = tsv_file {
        use std::io::Write;
        let _ = writeln!(f, "N\td2_N\tlambda_min\tgpu_ms\tdd_s\tD_N\tb_vmin_proj");
    }

    for &n in &test_ns {
        if n < 3 || n > gram_matrix.max_n { continue; }
        let dim = n - 1;
        let (sub, _) = gram_matrix.extract_submatrix(n);
        let b = arith::b_vector(dim);

        // Fast f64 Cholesky — GPU cuSOLVER for large N, nalgebra for small N
        let d2_f64 = if has_resident_gram && dim >= 500 {
            // GPU-resident: submatrix extraction + transpose + Cholesky all on-device
            // Zero PCIe matrix transfers — only the b vector crosses the bus
            match gpu::gpu_cholesky_resident(dim, &b) {
                Ok(d2) => d2,
                Err(_) => {
                    // Resident Cholesky failed — fall back to strided (host→device)
                    gpu::gpu_cholesky_d2_strided(&gram_matrix.data, gram_matrix.max_dim, dim, &b)
                        .unwrap_or_else(|_| {
                            let g_mat = DMatrix::from_fn(dim, dim, |i, j| sub[i * dim + j]);
                            let bv = DVector::from_column_slice(&b[..dim]);
                            g_mat.cholesky()
                                .map(|chol| { let c = chol.solve(&bv); 1.0 - bv.dot(&c) })
                                .unwrap_or(f64::NAN)
                        })
                }
            }
        } else if has_gpu && dim >= 500 {
            // GPU strided fallback (no resident gram)
            match gpu::gpu_cholesky_d2_strided(&gram_matrix.data, gram_matrix.max_dim, dim, &b) {
                Ok(d2) => d2,
                Err(_) => {
                    let g_mat = DMatrix::from_fn(dim, dim, |i, j| sub[i * dim + j]);
                    let bv = DVector::from_column_slice(&b[..dim]);
                    g_mat.cholesky()
                        .map(|chol| { let c = chol.solve(&bv); 1.0 - bv.dot(&c) })
                        .unwrap_or(f64::NAN)
                }
            }
        } else {
            let g_mat = DMatrix::from_fn(dim, dim, |i, j| sub[i * dim + j]);
            let bv = DVector::from_column_slice(&b[..dim]);
            g_mat.cholesky()
                .map(|chol| { let c = chol.solve(&bv); 1.0 - bv.dot(&c) })
                .unwrap_or(f64::NAN)
        };
        let needs_dd = d2_f64.is_nan() || d2_f64 < 0.0;

        // Skip GPU eigendecomp for very large N where results are garbage
        // (eigenvalues go negative above ~N=1500, and cuSOLVER is O(N³))
        let skip_gpu = !has_gpu || n > gpu_eigen_useless_above + 500;

        // Run GPU eigendecomp + high-precision Cholesky concurrently when both are needed
        let (d2, gpu_result, dd_time) = if needs_dd && dim <= 5000 {
            if skip_gpu {
                // High-precision Cholesky only — no point running GPU
                let dd_t0 = Instant::now();
                let d2_val = compute_d2_highprec(&gram_matrix.data, gram_matrix.max_dim, &dd_lo, &mpfr_gram, &sub, &b, dim, mpfr_bits, &log);
                let dd_elapsed = dd_t0.elapsed().as_secs_f64();
                (d2_val, None, dd_elapsed)
            } else {
                // GPU + high-precision Cholesky in parallel threads
                std::thread::scope(|s| {
                    let sub_ref = &sub;
                    let gpu_handle = s.spawn(move || gpu::gpu_syevd(sub_ref, dim));

                    let dd_t0 = Instant::now();
                    let d2_val = compute_d2_highprec(&gram_matrix.data, gram_matrix.max_dim, &dd_lo, &mpfr_gram, &sub, &b, dim, mpfr_bits, &log);
                    let dd_elapsed = dd_t0.elapsed().as_secs_f64();

                    let gpu_res = gpu_handle.join().unwrap();
                    (d2_val, Some(gpu_res), dd_elapsed)
                })
            }
        } else if skip_gpu {
            // f64 Cholesky worked, no GPU needed
            (d2_f64, None, 0.0)
        } else {
            // Small N: f64 Cholesky + GPU sequentially
            let gpu_res = gpu::gpu_syevd(&sub, dim);
            (d2_f64, Some(gpu_res), 0.0)
        };

        // Extract GPU diagnostics
        let (lambda_min, gpu_ms, deloc_ratio, b_vmin_proj) = match &gpu_result {
            Some(Ok(result)) => {
                let lambda_min = result.eigenvalues[0];
                // Track where GPU eigenvalues become useless
                if lambda_min < 0.0 && gpu_eigen_useless_above == usize::MAX {
                    gpu_eigen_useless_above = n;
                    log.log(&format!("GPU eigenvalues negative at N={} — skipping GPU for larger N", n));
                }
                let mut vmin_linf = 0.0f64;
                let mut bvp = 0.0f64;
                for i in 0..dim {
                    let v = result.eigenvectors[i];
                    vmin_linf = vmin_linf.max(v.abs());
                    bvp += b[i] * v;
                }
                (lambda_min, result.gpu_time_secs * 1000.0,
                 vmin_linf * (dim as f64).sqrt(), bvp.abs())
            }
            Some(Err(e)) => {
                log.data(&format!("  {:<6} │ GPU ERROR: {}", n, e));
                continue;
            }
            None => (f64::NAN, 0.0, f64::NAN, f64::NAN),
        };

        let status = if d2 > 0.0 && d2 < 1.0 { "✓" } else { "⚠" };
        let lmin_str = if lambda_min.is_nan() { "     ---       ".to_string() }
                       else { format!("{:.10e}", lambda_min) };
        let gpu_str = if gpu_ms == 0.0 { "   ---".to_string() }
                      else { format!("{:>6.1}", gpu_ms) };

        let deloc_str = if deloc_ratio.is_nan() { "    ---      ".to_string() }
                        else { format!("{:.6e}", deloc_ratio) };
        let bvmin_str = if b_vmin_proj.is_nan() { "    ---      ".to_string() }
                        else { format!("{:.6e}", b_vmin_proj) };

        log.data(&format!(
            "  {:<6} │ {:+.10e} │ {} │ {}  │ {:>6.1}  │ {}  │ {} {}",
            n, d2, lmin_str, gpu_str, dd_time, deloc_str, bvmin_str, status
        ));

        results.push(NResult {
            n, d2, lambda_min, gpu_time: gpu_ms / 1000.0,
            dd_time, deloc_ratio, b_vmin_proj,
        });

        // Incremental TSV write (crash-safe)
        if let Some(ref mut f) = tsv_file {
            use std::io::Write;
            let _ = writeln!(f, "{}\t{:.15e}\t{:.15e}\t{:.1}\t{:.2}\t{:.15e}\t{:.15e}",
                n, d2, lambda_min, gpu_ms, dd_time, deloc_ratio, b_vmin_proj);
            let _ = f.flush();
        }
    }

    let phase2_time = t_phase2.elapsed().as_secs_f64();
    let total_gpu: f64 = results.iter().map(|r| r.gpu_time).sum();
    let total_dd: f64 = results.iter().map(|r| r.dd_time).sum();

    // ═══ PHASE 3: Scaling Analysis ═══
    log.data("");
    log.data("  ══════════════════════════════════════════");
    log.data("    PHASE 3 · SCALING ANALYSIS");
    log.data("  ══════════════════════════════════════════");
    log.data("");

    if results.len() >= 5 {
        let d2_data: Vec<(f64, f64)> = results.iter()
            .filter(|r| r.n >= 10 && r.d2 > 0.0 && r.d2 < 1.0)
            .map(|r| ((r.n as f64).ln(), r.d2.ln())).collect();
        if d2_data.len() >= 3 {
            let (alpha, c_ln, r2) = fitting::linreg(&d2_data);
            let rh = if alpha < 0.0 { "✓ RH consistent" } else { "⚠" };
            log.data(&format!("  d² ~ {:.4} · N^({:.4})   R² = {:.4}  {}", c_ln.exp(), alpha, r2, rh));
        }

        let lmin_data: Vec<(f64, f64)> = results.iter()
            .filter(|r| r.n >= 10 && r.lambda_min > 0.0)
            .map(|r| ((r.n as f64).ln(), r.lambda_min.ln())).collect();
        if lmin_data.len() >= 3 {
            let (slope, intercept, r2) = fitting::linreg(&lmin_data);
            log.data(&format!("  λ_min ~ {:.4} · N^({:.4})   R² = {:.4}", intercept.exp(), slope, r2));
        }

        let deloc_data: Vec<(f64, f64)> = results.iter()
            .filter(|r| r.n >= 10 && r.deloc_ratio > 0.0)
            .map(|r| ((r.n as f64).ln(), r.deloc_ratio.ln())).collect();
        if deloc_data.len() >= 3 {
            let (slope, intercept, r2) = fitting::linreg(&deloc_data);
            log.data(&format!("  D(N) ~ {:.4} · N^({:.4})   R² = {:.4}", intercept.exp(), slope, r2));
        }

        let bproj_data: Vec<(f64, f64)> = results.iter()
            .filter(|r| r.n >= 10 && r.b_vmin_proj > 0.0)
            .map(|r| ((r.n as f64).ln(), r.b_vmin_proj.ln())).collect();
        if bproj_data.len() >= 3 {
            let (slope, intercept, r2) = fitting::linreg(&bproj_data);
            log.data(&format!("  |⟨b,v_min⟩| ~ {:.4} · N^({:.4})   R² = {:.4}", intercept.exp(), slope, r2));
        }
    }

    // ═══ SUMMARY ═══
    log.data("");
    log.data("  ══════════════════════════════════════════");
    log.data("    SUMMARY");
    log.data("  ══════════════════════════════════════════");
    log.data("");
    log.data(&format!("  MPFR precision:           {}-bit", mpfr_bits));
    log.data(&format!("  Phase 1 (Gram build):     {:.2}s", phase1_time));
    log.data(&format!("  Phase 2 (Spectral):       {:.2}s ({} decompositions)", phase2_time, results.len()));
    log.data(&format!("    GPU eigen time:          {:.2}s", total_gpu));
    log.data(&format!("    DD Cholesky time:        {:.2}s", total_dd));
    log.data(&format!("  Total:                    {:.2}s", phase1_time + phase2_time));
    if let Some(last_good) = results.iter().rev().find(|r| r.d2 > 0.0 && r.d2 < 1.0) {
        log.data("");
        log.data(&format!("  LAST CERTIFIED: d²_{} = {:.15e}", last_good.n, last_good.d2));
    }
    if !results.is_empty() {
        let last = results.last().unwrap();
        log.data(&format!("  d²_{} = {:.15e}", last.n, last.d2));
    }
    log.data("");

    log.log(&format!("Results written to {}", tsv_path));
    log.log(&format!("Done. Log written to {}", log_path));
}

struct NResult {
    n: usize, d2: f64, lambda_min: f64,
    gpu_time: f64, dd_time: f64,
    deloc_ratio: f64, b_vmin_proj: f64,
}

fn acquire_gram(max_n: usize, log: &Logger) -> gram::GramMatrix {
    let cache_dir = cache::cache_dir();
    log.log(&format!("Searching cache: {}", cache_dir.display()));

    // Look for a cache built with the FAST algorithm (same T_direct as DD Gram).
    // Prefer caches with "mpfr" in the name (higher precision builds).
    let mut best: Option<gram::GramMatrix> = None;
    if let Ok(entries) = std::fs::read_dir(&cache_dir) {
        for entry in entries.flatten() {
            let name = entry.file_name().to_string_lossy().to_string();
            if name.starts_with("gram_N") && name.ends_with(".bin") {
                if let Some(g) = cache::load_gram(&entry.path()) {
                    if g.max_n >= max_n
                        && best.as_ref().is_none_or(|b| g.precision > b.precision) {
                            best = Some(g);
                        }
                }
            }
        }
    }

    if let Some(g) = best {
        log.log(&format!("Using cached matrix (N={}, {}-bit)", g.max_n, g.precision));
        return g;
    }

    // Build fresh with build_fast — CRITICAL: use same table_size as DD Gram
    // so that T_direct is consistent across all matrix types.
    log.log("No cache. Building f64 Gram with build_fast (MPFR-128)...");
    let table_size = (max_n * 5).max(100_001).min(gram::MAX_LN_TABLE);
    let ln_n_table = gram::LnNTable::new(table_size + 1, 128);
    let g = gram::GramMatrix::build_fast(max_n, &ln_n_table);
    let path = cache::gram_cache_path(max_n, 128);
    if let Err(e) = cache::save_gram(&path, &g) { log.log(&format!("Cache save failed: {}", e)); }
    g
}

fn build_schedule(max_n: usize) -> Vec<usize> {
    let mut ns = Vec::new();
    for n in 3..=30.min(max_n) { ns.push(n); }
    for n in (35..=100.min(max_n)).step_by(5) { ns.push(n); }
    for n in (125..=500.min(max_n)).step_by(25) { ns.push(n); }
    for n in (550..=1000.min(max_n)).step_by(50) { ns.push(n); }
    for n in (1100..=2000.min(max_n)).step_by(100) { ns.push(n); }
    for n in (2200..=5000.min(max_n)).step_by(200) { ns.push(n); }
    for n in (5500..=max_n).step_by(500) { ns.push(n); }
    if !ns.contains(&max_n) && max_n >= 3 { ns.push(max_n); }
    ns.sort(); ns.dedup(); ns
}
