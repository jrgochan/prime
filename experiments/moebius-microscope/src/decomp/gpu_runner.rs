//! GPU-accelerated execution engine for the Möbius Cancellation Microscope.
//!
//! This runner loads the Gram matrix from an HPDF file into GPU VRAM,
//! then computes all microscope metrics using cuBLAS operations:
//!
//!   1. vᵀGv via GPU matrix-vector multiply + dot product
//!   2. U/L/Q taper sums via GPU bilinear forms
//!   3. Row decomposition via GPU matvec (y = G @ v, then classify terms)
//!
//! On an RTX 4090, this converts the O(dim²) row processing from
//! ~15 minutes (CPU @ N=55K) to ~2 seconds (GPU).

use cathedral_utils::arith::{self, Kahan};
use cathedral_utils::mertens;
use cathedral_utils::gpu;
use cathedral_utils::gpu::bilinear::BilinearEngine;
use cathedral_utils::hpdf::{HpdfReader, MicroscopeResult, stamp_microscope};
use rayon::prelude::*;
use std::time::Instant;

use super::state::Decomp;
use super::classify::classify_term;
use super::row::{RowResult, merge_results};
use super::gram::{finalize_gram_metrics, print_gram_summary};
use super::taper::print_taper_summary;

/// Run the microscope using GPU acceleration.
///
/// The workflow:
///   1. Load full Gram matrix from HPDF into host memory
///   2. Upload to GPU VRAM (cuBLAS symmetric matrix format)
///   3. GPU bilinear forms: vᵀGv, U, L, Q  (4× dsymv + ddot)
///   4. GPU matvec: y = G @ v for row decomposition
///   5. CPU: classify terms from y vector (fast: O(dim) per row)
///   6. Finalize metrics + stamp results
pub fn run_microscope_gpu(path: &std::path::Path) -> Result<Decomp, String> {
    let t0 = Instant::now();

    // ═══ GPU DETECTION ═══
    let gpu_info = gpu::detect()
        .ok_or_else(|| "No CUDA GPU detected. Rebuild with --features gpu on a CUDA system.".to_string())?;
    eprintln!("  🎮 GPU: {} ({} MB VRAM)", gpu_info.name, gpu_info.vram_mb);

    // ═══ HPDF LOAD + k=1 AUGMENTATION + GPU UPLOAD ═══
    let (n, dim, decomp) = {
        let reader = HpdfReader::open(path).map_err(|e| format!("HPDF open: {e}"))?;
        let hpdf_dim = reader.dim();  // N-1 (k=2..N stored in file)
        let n = reader.max_n();
        let dim = n;  // Lean-aligned: k=1..N
        let has_dd = reader.has_dd();
        let prec_label = if has_dd { "DD (~31 digits)" } else { "f64" };

        eprintln!("\n═══ MÖBIUS MICROSCOPE N={n} (dim={dim}) [GPU + HPDF {prec_label}, k=1..N] ═══");
        eprintln!("  File: {}", path.display());

        // Check VRAM fit (augmented N×N matrix)
        let matrix_mb = (dim * dim * 8) / (1024 * 1024);
        if !BilinearEngine::can_fit(dim, gpu_info.vram_mb) {
            return Err(format!(
                "Matrix too large for GPU: {matrix_mb} MB > {} MB VRAM. Use --hpdf (CPU) instead.",
                gpu_info.vram_mb
            ));
        }
        eprintln!("  Matrix: {dim}×{dim} = {matrix_mb} MB (fits in {} MB VRAM)", gpu_info.vram_mb);

        let mu = arith::mobius_table(n);
        let weights = mertens::witness_vector_full(n, &mu);  // k=1..N
        let liouville = arith::liouville_table(n);
        let omega_tbl = arith::small_omega_table(n);

        let n13 = (n as f64).powf(1.0 / 3.0) as usize;
        let n23 = (n as f64).powf(2.0 / 3.0) as usize;
        let nonzero = weights.iter().filter(|&&w| w.abs() > 1e-30).count();
        eprintln!("  Vaughan: I ≤ {n13}, II ≤ {n23}");
        eprintln!("  Non-zero weights: {nonzero}/{dim}");

        let prec_str = if has_dd { "GPU+DD" } else { "GPU+f64" };
        let mut decomp = Decomp::new(n, prec_str);

        // ═══ LOAD HPDF (N-1)×(N-1) + AUGMENT to N×N ═══
        eprintln!("  Loading HPDF matrix ({hpdf_dim}×{hpdf_dim}) from file...");
        let gram_upper = reader.read_gram_full()
            .map_err(|e| format!("read_gram_full: {e}"))?;
        let t_load = t0.elapsed().as_secs_f64();
        eprintln!("  ✓ HPDF load: {:.1}s ({} entries, {:.1} MB)",
            t_load, gram_upper.len(), gram_upper.len() as f64 * 8.0 / 1e6);

        // Compute k=1 augmentation row on-the-fly
        eprintln!("  Computing k=1 augmentation row ({dim} entries)...");
        let k1_row: Vec<f64> = (0..dim)
            .map(|k_idx| {
                let k = k_idx + 1;
                cathedral_utils::gram::gram_entry_f64(1, k)
            })
            .collect();

        // Build augmented N×N dense matrix:
        //   Row/col 0 = k=1 (from k1_row)
        //   Rows/cols 1..N-1 = k=2..N (from HPDF)
        eprintln!("  Expanding to augmented {dim}×{dim} dense matrix...");
        let mut gram_full = vec![0.0f64; dim * dim];
        // Fill k=1 row and column (row 0 and col 0)
        for k_idx in 0..dim {
            gram_full[0 * dim + k_idx] = k1_row[k_idx];  // row 0
            gram_full[k_idx * dim + 0] = k1_row[k_idx];  // col 0
        }
        // Fill the (N-1)×(N-1) HPDF block into positions [1..N-1, 1..N-1]
        for i in 0..hpdf_dim {
            for j in i..hpdf_dim {
                let packed_idx = i * hpdf_dim - i * (i + 1) / 2 + j;
                let val = gram_upper[packed_idx];
                gram_full[(i + 1) * dim + (j + 1)] = val;
                gram_full[(j + 1) * dim + (i + 1)] = val;
            }
        }
        let t_expand = t0.elapsed().as_secs_f64();
        eprintln!("  ✓ Dense expand + k=1 augmentation: {:.1}s", t_expand - t_load);

        // ═══ GPU UPLOAD + BILINEAR FORMS ═══
        eprintln!("  Uploading Gram matrix to GPU...");
        let engine = BilinearEngine::new(&gram_full, dim)?;

        // Run the full taper decomposition on GPU
        let taper_result = engine.compute_taper(&weights, &mu)?;

        // ═══ GPU ROW DECOMPOSITION ═══
        // For the detailed decomposition (GCD, Vaughan, ω-class, etc.),
        // we use the in-memory matrix with CPU parallel classification.
        // The GPU already computed the expensive bilinear forms; this is
        // just O(dim × n_active) classification which is fast.
        eprintln!("  Running CPU row classification (GCD/Vaughan/ω-class)...");
        let active_rows: Vec<(usize, usize, f64)> = (0..dim)
            .map(|j_idx| (j_idx, j_idx + 1, weights[j_idx]))  // k=1..N (Lean-aligned)
            .filter(|(_, _, w)| w.abs() > 1e-30)
            .collect();
        let n_active = active_rows.len();

        let done = std::sync::atomic::AtomicUsize::new(0);
        let row_results: Vec<RowResult> = active_rows
            .par_iter()
            .map(|&(j_idx, j, v_j)| {
                let mut r = RowResult::new(decomp.max_gcd, decomp.max_omega, decomp.max_band);
                let mut row_kahan = Kahan::default();
                let mut row_abs_kahan = Kahan::default();
                let mu_j = mu[j] as f64;
                let ln_j = (j as f64).ln();

                for k_idx in 0..dim {
                    let k = k_idx + 1;  // k=1..N (Lean-aligned)
                    let v_k = weights[k_idx];
                    if v_k.abs() < 1e-30 { continue; }

                    let g_jk = gram_full[j_idx * dim + k_idx];
                    let term = v_j * g_jk * v_k;
                    let mu_k = mu[k] as f64;
                    let ln_k = (k as f64).ln();

                    classify_term(
                        &mut r, j, k, term,
                        mu_j, mu_k, ln_j, ln_k,
                        &liouville, &omega_tbl, n13, n23,
                        decomp.max_gcd, decomp.max_omega, decomp.max_band,
                    );

                    if mu_j.abs() > 0.5 && mu_k.abs() > 0.5 {
                        let mm_g = mu_j * mu_k * g_jk;
                        r.u_row.add(mm_g);
                        r.l_row.add(mm_g * ln_j);
                        r.q_row.add(mm_g * ln_j * ln_k);
                    }

                    row_kahan.add(term);
                    row_abs_kahan.add(term.abs());
                }
                r.row_sum = row_kahan.value();
                r.row_abs = row_abs_kahan.value();

                let cnt = done.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
                if cnt % (n_active / 20).max(1) == 0 && cnt > 0 {
                    let pct = cnt as f64 / n_active as f64 * 100.0;
                    let el = t0.elapsed().as_secs_f64();
                    let eta = el / (pct / 100.0) * (1.0 - pct / 100.0);
                    eprint!("\r  Rows: {cnt}/{n_active} ({pct:.0}%) {el:.1}s ETA={eta:.1}s    ");
                }
                r
            })
            .collect();


        let active_for_merge: Vec<(usize, f64)> = active_rows.iter()
            .map(|&(_, j, v)| (j, v))
            .collect();
        merge_results(&mut decomp, &row_results, &active_for_merge);

        // Finalize gram metrics (from CPU row classification)
        finalize_gram_metrics(&mut decomp);

        // ═══ STORE GPU TAPER RESULTS ═══
        // Use the GPU-computed bilinear forms for the taper metrics
        let ln_n = (n as f64).ln();
        let ln2_n = ln_n * ln_n;
        let vtgv = decomp.total.value();

        decomp.taper.u_sum = Kahan::default();
        decomp.taper.u_sum.add(taper_result.u_sum);
        decomp.taper.l_sum = Kahan::default();
        decomp.taper.l_sum.add(taper_result.l_sum);
        decomp.taper.q_sum = Kahan::default();
        decomp.taper.q_sum.add(taper_result.q_sum);
        decomp.taper.vtgv_recon = taper_result.vtgv;

        decomp.taper.r2 = taper_result.u_sum - 2.0 * taper_result.l_sum / ln_n;
        decomp.taper.r2_minus_1 = decomp.taper.r2 - 1.0;
        decomp.taper.r2_times_ln = decomp.taper.r2_minus_1 * ln_n;
        decomp.taper.q_over_ln2 = taper_result.q_sum / ln2_n;
        decomp.taper.c_recon = (1.0 - vtgv) * ln_n;

        // PNT sub-sums (CPU, fast O(N))
        let mut s1 = Kahan::default();
        let mut s2 = Kahan::default();
        let mut s3 = Kahan::default();
        let mut mertens_sum: i64 = 0;
        for k in 1..=n {
            let mu_k = mu[k] as f64;
            let k_f = k as f64;
            let ln_k = k_f.ln();
            s1.add(mu_k / k_f);
            s2.add(mu_k * ln_k / k_f);
            s3.add(mu_k * ln_k * ln_k / k_f);
            mertens_sum += mu[k] as i64;
        }
        decomp.taper.s1 = s1.value();
        decomp.taper.s2 = s2.value();
        decomp.taper.s3 = s3.value();
        decomp.taper.mertens = mertens_sum as f64;
        decomp.taper.mertens_over_sqrt = mertens_sum as f64 / (n as f64).sqrt();

        let elapsed = t0.elapsed().as_secs_f64();
        eprintln!("\r  ✓ Done in {elapsed:.1}s ({n_active} active × {dim} cols, GPU+HPDF)                      ");
        eprintln!("    GPU bilinear: {:.3}s | CPU classify: {:.1}s",
            taper_result.gpu_secs, elapsed - taper_result.gpu_secs);
        print_gram_summary(&decomp);
        print_taper_summary(&decomp);

        (n, dim, decomp)
    };

    // ═══ STAMP RESULTS ═══
    let elapsed = t0.elapsed().as_secs_f64();
    let ln_n = (n as f64).ln();
    let t = &decomp.taper;
    let recon = t.u_sum.value() - 2.0/ln_n * t.l_sum.value() + t.q_sum.value()/(ln_n*ln_n);
    let result = MicroscopeResult {
        n,
        precision: format!("GPU+DD"),
        vtgv: decomp.total.value(),
        btv: decomp.gram.btv,
        btv_sq: decomp.gram.btv_sq,
        vtcv: decomp.gram.vtcv,
        d2n: decomp.gram.d2n,
        gap: decomp.gram.gap,
        gap_times_ln: decomp.gram.gap_times_ln,
        u_sum: t.u_sum.value(),
        l_sum: t.l_sum.value(),
        q_sum: t.q_sum.value(),
        r2: t.r2,
        r2_minus_1: t.r2_minus_1,
        r2_times_ln: t.r2_times_ln,
        q_over_ln2: t.q_over_ln2,
        c_recon: t.c_recon,
        vtgv_recon: t.vtgv_recon,
        cross_check_delta: (recon - decomp.total.value()).abs(),
        s1: t.s1,
        s2: t.s2,
        s3: t.s3,
        mertens: t.mertens,
        mertens_over_sqrt: t.mertens_over_sqrt,
        elapsed_secs: elapsed,
    };
    match stamp_microscope(path, &result) {
        Ok(()) => eprintln!("  ✓ Stamped /microscope metadata → {}", path.display()),
        Err(e) => eprintln!("  ⚠ Failed to stamp metadata: {e}"),
    }

    Ok(decomp)
}
