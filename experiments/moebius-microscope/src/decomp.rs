//! Parallel decomposition engine for the Möbius Cancellation Microscope v2.
//!
//! Two modes:
//!  - **On-the-fly** (`run_microscope`): compute Gram entries at f64 precision
//!  - **HPDF** (`run_microscope_hpdf`): load DD-lossless rows from HPDF files
//!
//! Uses rayon to parallelize row computation with per-row buckets + merge.

use cathedral_utils::arith::{self, Kahan};
use cathedral_utils::gram;
use cathedral_utils::mertens;
use rayon::prelude::*;
use std::time::Instant;

// ═══════════════════════════════════════════════
// DECOMPOSITION STATE
// ═══════════════════════════════════════════════

pub struct Decomp {
    pub n: usize,
    pub dim: usize,
    pub precision: String,
    pub total: Kahan,
    pub diagonal: Kahan,
    pub off_diagonal: Kahan,
    pub gcd_buckets: Vec<Kahan>,
    pub max_gcd: usize,
    pub channels: [Kahan; 4],
    pub type_i: Kahan,
    pub type_ii: Kahan,
    pub type_iii: Kahan,
    pub ee: Kahan,
    pub eo: Kahan,
    pub oe: Kahan,
    pub oo: Kahan,
    pub omega_buckets: Vec<Vec<Kahan>>,
    pub max_omega: usize,
    pub dyadic: Vec<Vec<Kahan>>,
    pub max_band: usize,
    pub n_pos: u64,
    pub n_neg: u64,
    pub sum_pos: Kahan,
    pub sum_neg: Kahan,
    pub robin_sigma: Vec<f64>,
    pub trace: Vec<(usize, f64, f64)>,
    // === NEW in v2: Gram bound metrics ===
    pub btv: f64,           // bᵀv
    pub btv_sq: f64,        // (bᵀv)²
    pub vtcv: f64,          // vᵀCv = vᵀGv - (bᵀv)²
    pub d2n: f64,           // d²_N = 1 - 2bᵀv + vᵀGv
    pub ratio: f64,         // (bᵀv)²/vᵀGv
    pub gap: f64,           // 1 - vᵀGv
    pub gap_times_ln: f64,  // (1-vᵀGv) * ln(N)
}

impl Decomp {
    pub fn new(n: usize, precision: &str) -> Self {
        let max_gcd = (n as f64).sqrt() as usize + 1;
        let max_omega = 8;
        let max_band = ((n as f64).log2() as usize) + 1;
        let mut robin_sigma = vec![0.0f64; max_gcd + 1];
        for d in 1..=max_gcd {
            robin_sigma[d] = arith::sigma1(d) as f64 / d as f64;
        }
        Self {
            n, dim: n - 1,
            precision: precision.to_string(),
            total: Kahan::default(), diagonal: Kahan::default(), off_diagonal: Kahan::default(),
            gcd_buckets: vec![Kahan::default(); max_gcd + 1], max_gcd,
            channels: [Kahan::default(); 4],
            type_i: Kahan::default(), type_ii: Kahan::default(), type_iii: Kahan::default(),
            ee: Kahan::default(), eo: Kahan::default(), oe: Kahan::default(), oo: Kahan::default(),
            omega_buckets: vec![vec![Kahan::default(); max_omega + 1]; max_omega + 1], max_omega,
            dyadic: vec![vec![Kahan::default(); max_band + 1]; max_band + 1], max_band,
            n_pos: 0, n_neg: 0, sum_pos: Kahan::default(), sum_neg: Kahan::default(),
            robin_sigma, trace: Vec::new(),
            btv: 0.0, btv_sq: 0.0, vtcv: 0.0, d2n: 0.0, ratio: 0.0, gap: 0.0, gap_times_ln: 0.0,
        }
    }

    /// Compute derived Gram-bound metrics from total = vᵀGv.
    pub fn finalize_gram_metrics(&mut self) {
        let vtgv = self.total.value();
        let mu = arith::mobius_table(self.n);
        let weights = mertens::log_cutoff_weights(self.n, &mu);
        let b_vec = arith::b_vector(self.n);

        // bᵀv = Σ b_k * v_k
        let mut btv = Kahan::default();
        for k in 0..self.dim {
            btv.add(b_vec[k] * weights[k]);
        }
        self.btv = btv.value();
        self.btv_sq = self.btv * self.btv;
        self.vtcv = vtgv - self.btv_sq;
        self.d2n = 1.0 - 2.0 * self.btv + vtgv;
        self.ratio = if vtgv > 1e-15 { self.btv_sq / vtgv } else { 0.0 };
        self.gap = 1.0 - vtgv;
        self.gap_times_ln = self.gap * (self.n as f64).ln();
    }
}

// ═══════════════════════════════════════════════
// PER-ROW RESULT (for parallel map-reduce)
// ═══════════════════════════════════════════════

struct RowResult {
    total: Kahan,
    diagonal: Kahan,
    off_diagonal: Kahan,
    gcd_buckets: Vec<Kahan>,
    channels: [Kahan; 4],
    type_i: Kahan,
    type_ii: Kahan,
    type_iii: Kahan,
    ee: Kahan, eo: Kahan, oe: Kahan, oo: Kahan,
    omega_buckets: Vec<Vec<Kahan>>,
    dyadic: Vec<Vec<Kahan>>,
    n_pos: u64, n_neg: u64,
    sum_pos: Kahan, sum_neg: Kahan,
    row_sum: f64, row_abs: f64,
}

impl RowResult {
    fn new(max_gcd: usize, max_omega: usize, max_band: usize) -> Self {
        Self {
            total: Kahan::default(), diagonal: Kahan::default(), off_diagonal: Kahan::default(),
            gcd_buckets: vec![Kahan::default(); max_gcd + 1],
            channels: [Kahan::default(); 4],
            type_i: Kahan::default(), type_ii: Kahan::default(), type_iii: Kahan::default(),
            ee: Kahan::default(), eo: Kahan::default(), oe: Kahan::default(), oo: Kahan::default(),
            omega_buckets: vec![vec![Kahan::default(); max_omega + 1]; max_omega + 1],
            dyadic: vec![vec![Kahan::default(); max_band + 1]; max_band + 1],
            n_pos: 0, n_neg: 0, sum_pos: Kahan::default(), sum_neg: Kahan::default(),
            row_sum: 0.0, row_abs: 0.0,
        }
    }
}

// ═══════════════════════════════════════════════
// SHARED ROW CLASSIFICATION ENGINE
// ═══════════════════════════════════════════════

/// Classify and accumulate a single (j,k) term into all decomposition buckets.
/// This is the shared kernel used by both on-the-fly and HPDF modes.
#[inline]
fn classify_term(
    r: &mut RowResult,
    j: usize, k: usize,
    term: f64,
    liouville: &[i8], omega_tbl: &[u32],
    n13: usize, n23: usize, max_gcd: usize, max_omega: usize, max_band: usize,
) {
    r.total.add(term);

    if j == k { r.diagonal.add(term); } else { r.off_diagonal.add(term); }

    let gcd_val = arith::gcd(j, k);
    if gcd_val <= max_gcd { r.gcd_buckets[gcd_val].add(term); }

    for ch in 0..4 {
        r.channels[ch].add(arith::chi8(ch, j) as f64 * arith::chi8(ch, k) as f64 * term);
    }

    let mn = j.min(k);
    if mn <= n13 { r.type_i.add(term); }
    else if mn <= n23 { r.type_ii.add(term); }
    else { r.type_iii.add(term); }

    match (liouville[j], liouville[k]) {
        (1, 1)   => r.ee.add(term),
        (1, -1)  => r.eo.add(term),
        (-1, 1)  => r.oe.add(term),
        (-1, -1) => r.oo.add(term),
        _ => {},
    }

    let wj = (omega_tbl[j] as usize).min(max_omega);
    let wk = (omega_tbl[k] as usize).min(max_omega);
    r.omega_buckets[wj][wk].add(term);

    let bj = if j >= 2 { (j as f64).log2() as usize } else { 0 }.min(max_band);
    let bk = if k >= 2 { (k as f64).log2() as usize } else { 0 }.min(max_band);
    r.dyadic[bj][bk].add(term);

    if term > 0.0 { r.n_pos += 1; r.sum_pos.add(term); }
    else if term < 0.0 { r.n_neg += 1; r.sum_neg.add(term); }
}

// ═══════════════════════════════════════════════
// MODE 1: ON-THE-FLY (f64 precision)
// ═══════════════════════════════════════════════

/// Compute one row using on-the-fly Gram entry computation (f64).
fn compute_row_f64(
    j: usize, v_j: f64, dim: usize,
    weights: &[f64], liouville: &[i8], omega_tbl: &[u32],
    n13: usize, n23: usize, max_gcd: usize, max_omega: usize, max_band: usize,
) -> RowResult {
    let mut r = RowResult::new(max_gcd, max_omega, max_band);
    let mut row_sum = Kahan::default();
    let mut row_abs = Kahan::default();

    for k_idx in 0..dim {
        let k = k_idx + 2;
        let v_k = weights[k_idx];
        if v_k.abs() < 1e-30 { continue; }

        let g_jk = gram::gram_entry_f64(j, k);
        let term = v_j * g_jk * v_k;

        classify_term(
            &mut r, j, k, term,
            liouville, omega_tbl, n13, n23, max_gcd, max_omega, max_band,
        );
        row_sum.add(term);
        row_abs.add(term.abs());
    }
    r.row_sum = row_sum.value();
    r.row_abs = row_abs.value();
    r
}

/// Run the full parallel microscope for a given N using on-the-fly f64 computation.
pub fn run_microscope(n: usize) -> Decomp {
    let t0 = Instant::now();
    let dim = n - 1;
    eprintln!("\n═══ MÖBIUS MICROSCOPE N={n} (dim={dim}) [f64 on-the-fly] ═══");

    let mu = arith::mobius_table(n);
    let weights = mertens::log_cutoff_weights(n, &mu);
    let liouville = arith::liouville_table(n);
    let omega_tbl = arith::small_omega_table(n);

    let n13 = (n as f64).powf(1.0/3.0) as usize;
    let n23 = (n as f64).powf(2.0/3.0) as usize;
    let nonzero = weights.iter().filter(|&&w| w.abs() > 1e-30).count();
    eprintln!("  Vaughan: I ≤ {n13}, II ≤ {n23}");
    eprintln!("  Non-zero weights: {nonzero}/{dim}");
    eprintln!("  Parallelism: {} threads", rayon::current_num_threads());

    let mut decomp = Decomp::new(n, "f64");

    // Collect active rows (non-zero weight)
    let active_rows: Vec<(usize, f64)> = (0..dim)
        .map(|j_idx| (j_idx + 2, weights[j_idx]))
        .filter(|(_, w)| w.abs() > 1e-30)
        .collect();
    let n_active = active_rows.len();
    eprintln!("  Active rows: {n_active} (processing in parallel)");

    // PARALLEL: compute all rows
    let done = std::sync::atomic::AtomicUsize::new(0);
    let row_results: Vec<RowResult> = active_rows
        .par_iter()
        .map(|&(j, v_j)| {
            let r = compute_row_f64(
                j, v_j, dim,
                &weights, &liouville, &omega_tbl,
                n13, n23, decomp.max_gcd, decomp.max_omega, decomp.max_band,
            );
            let cnt = done.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
            if cnt % (n_active / 20).max(1) == 0 && cnt > 0 {
                let pct = cnt as f64 / n_active as f64 * 100.0;
                let el = t0.elapsed().as_secs_f64();
                let eta = el / (cnt as f64 / n_active as f64) * (1.0 - cnt as f64 / n_active as f64);
                eprint!("\r  Rows: {cnt}/{n_active} ({pct:.0}%) {el:.1}s ETA={eta:.1}s    ");
            }
            r
        })
        .collect();

    merge_results(&mut decomp, &row_results, &active_rows);

    // Finalize Gram bound metrics
    decomp.finalize_gram_metrics();

    eprintln!("\r  ✓ Done in {:.1}s ({n_active} rows × {dim} cols, {} threads)                      ",
        t0.elapsed().as_secs_f64(), rayon::current_num_threads());
    print_gram_summary(&decomp);
    decomp
}

// ═══════════════════════════════════════════════
// MODE 2: HPDF BATCH-PARALLEL (DD precision)
// ═══════════════════════════════════════════════

/// Batch size for row reads from HPDF (tuned for L2 cache)
const HPDF_BATCH_SIZE: usize = 64;

/// Run the microscope using an HPDF file for DD-lossless Gram entries.
///
/// Architecture:
///   1. Read a batch of HPDF rows (sequential IO — HDF5 is single-threaded)
///   2. Process the batch in parallel using rayon (each row in a separate thread)
///   3. Merge results into the accumulator
///   4. Repeat until all active rows are processed
///
/// For N ≤ 5000, loads the entire upper triangle into RAM for maximum throughput.
/// For N > 5000, uses batched row-streaming to stay within memory bounds.
#[cfg(feature = "hpdf")]
pub fn run_microscope_hpdf(path: &std::path::Path) -> Result<Decomp, String> {
    use cathedral_utils::hpdf::HpdfReader;

    let t0 = Instant::now();
    let reader = HpdfReader::open(path).map_err(|e| format!("HPDF open: {e}"))?;
    let dim = reader.dim();
    let n = reader.max_n();
    let has_dd = reader.has_dd();
    let prec_label = if has_dd { "DD (~31 digits)" } else { "f64" };

    eprintln!("\n═══ MÖBIUS MICROSCOPE N={n} (dim={dim}) [HPDF {prec_label}] ═══");
    eprintln!("  File: {}", path.display());
    eprintln!("  Parallelism: {} threads", rayon::current_num_threads());

    let mu = arith::mobius_table(n);
    let weights = mertens::log_cutoff_weights(n, &mu);
    let liouville = arith::liouville_table(n);
    let omega_tbl = arith::small_omega_table(n);

    let n13 = (n as f64).powf(1.0/3.0) as usize;
    let n23 = (n as f64).powf(2.0/3.0) as usize;
    let nonzero = weights.iter().filter(|&&w| w.abs() > 1e-30).count();
    eprintln!("  Vaughan: I ≤ {n13}, II ≤ {n23}");
    eprintln!("  Non-zero weights: {nonzero}/{dim}");

    let prec_str = if has_dd { "DD" } else { "HPDF-f64" };
    let mut decomp = Decomp::new(n, prec_str);

    // Active rows: those with non-zero Möbius weight
    let active_rows: Vec<(usize, usize, f64)> = (0..dim)
        .map(|j_idx| (j_idx, j_idx + 2, weights[j_idx]))
        .filter(|(_, _, w)| w.abs() > 1e-30)
        .collect();
    let n_active = active_rows.len();

    // Memory estimate: full matrix = dim*dim*8 bytes
    let full_matrix_bytes = (dim as u64) * (dim as u64) * 8;
    let use_full_load = full_matrix_bytes < 2_000_000_000; // 2GB threshold

    if use_full_load {
        eprintln!("  Strategy: FULL MATRIX LOAD ({:.1} MB) + parallel rows",
            full_matrix_bytes as f64 / 1e6);
        run_hpdf_full_parallel(&reader, &mut decomp, &active_rows,
            &weights, &liouville, &omega_tbl, n13, n23, &t0)?;
    } else {
        eprintln!("  Strategy: BATCHED ROW-STREAM (batch={HPDF_BATCH_SIZE}) + parallel cols");
        run_hpdf_batched(&reader, &mut decomp, &active_rows,
            &weights, &liouville, &omega_tbl, n13, n23, &t0)?;
    }

    // Finalize Gram bound metrics
    decomp.finalize_gram_metrics();

    eprintln!("\r  ✓ Done in {:.1}s ({n_active} active rows × {dim} cols, HPDF {prec_str})                      ",
        t0.elapsed().as_secs_f64());
    print_gram_summary(&decomp);
    Ok(decomp)
}

/// Full matrix load + parallel row processing.
/// Best for N ≤ ~15000 where the matrix fits in RAM.
#[cfg(feature = "hpdf")]
fn run_hpdf_full_parallel(
    reader: &cathedral_utils::hpdf::HpdfReader,
    decomp: &mut Decomp,
    active_rows: &[(usize, usize, f64)],
    weights: &[f64], liouville: &[i8], omega_tbl: &[u32],
    n13: usize, n23: usize,
    t0: &Instant,
) -> Result<(), String> {
    let dim = decomp.dim;
    let n_active = active_rows.len();

    // Load entire upper triangle
    eprintln!("  Loading full matrix from HPDF...");
    let gram_flat = reader.read_gram_full()
        .map_err(|e| format!("read_gram_full: {e}"))?;
    eprintln!("  ✓ Loaded {} entries ({:.1} MB)",
        gram_flat.len(), gram_flat.len() as f64 * 8.0 / 1e6);

    // Helper: get G[i,j] from upper triangle flat storage
    let gram_entry = |i: usize, j: usize| -> f64 {
        let (r, c) = if i <= j { (i, j) } else { (j, i) };
        gram_flat[r * dim - r * (r + 1) / 2 + c]
    };

    // PARALLEL: process all active rows
    let done = std::sync::atomic::AtomicUsize::new(0);
    let row_results: Vec<RowResult> = active_rows
        .par_iter()
        .map(|&(j_idx, j, v_j)| {
            let mut r = RowResult::new(decomp.max_gcd, decomp.max_omega, decomp.max_band);
            let mut row_kahan = Kahan::default();
            let mut row_abs_kahan = Kahan::default();

            for k_idx in 0..dim {
                let k = k_idx + 2;
                let v_k = weights[k_idx];
                if v_k.abs() < 1e-30 { continue; }

                let g_jk = gram_entry(j_idx, k_idx);
                let term = v_j * g_jk * v_k;

                classify_term(
                    &mut r, j, k, term,
                    liouville, omega_tbl, n13, n23,
                    decomp.max_gcd, decomp.max_omega, decomp.max_band,
                );
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

    // Merge
    let active_for_merge: Vec<(usize, f64)> = active_rows.iter()
        .map(|&(_, j, v)| (j, v))
        .collect();
    merge_results(decomp, &row_results, &active_for_merge);
    Ok(())
}

/// Batched row-streaming for large N (N > ~15000).
/// Reads rows in batches, then processes each batch in parallel.
#[cfg(feature = "hpdf")]
fn run_hpdf_batched(
    reader: &cathedral_utils::hpdf::HpdfReader,
    decomp: &mut Decomp,
    active_rows: &[(usize, usize, f64)],
    weights: &[f64], liouville: &[i8], omega_tbl: &[u32],
    n13: usize, n23: usize,
    t0: &Instant,
) -> Result<(), String> {
    let dim = decomp.dim;
    let n_active = active_rows.len();
    let trace_iv = (n_active / 40).max(1);
    let mut running_sum = Kahan::default();
    let mut running_abs = Kahan::default();
    let mut progress = 0usize;

    // Process in batches
    for batch in active_rows.chunks(HPDF_BATCH_SIZE) {
        // Phase 1: Sequential HDF5 reads (IO-bound, single-threaded)
        let batch_rows: Vec<(usize, usize, f64, Vec<f64>)> = batch.iter()
            .map(|&(j_idx, j, v_j)| {
                let row = reader.read_gram_row(j_idx)
                    .unwrap_or_else(|_| vec![0.0; dim]);
                (j_idx, j, v_j, row)
            })
            .collect();

        // Phase 2: Parallel classification (CPU-bound, multi-threaded)
        let batch_results: Vec<RowResult> = batch_rows
            .par_iter()
            .map(|(_, j, v_j, row)| {
                let j = *j;
                let v_j = *v_j;
                let mut r = RowResult::new(decomp.max_gcd, decomp.max_omega, decomp.max_band);
                let mut row_kahan = Kahan::default();
                let mut row_abs_kahan = Kahan::default();

                for k_idx in 0..dim {
                    let k = k_idx + 2;
                    let v_k = weights[k_idx];
                    if v_k.abs() < 1e-30 { continue; }

                    let g_jk = row[k_idx];
                    let term = v_j * g_jk * v_k;

                    classify_term(
                        &mut r, j, k, term,
                        liouville, omega_tbl, n13, n23,
                        decomp.max_gcd, decomp.max_omega, decomp.max_band,
                    );
                    row_kahan.add(term);
                    row_abs_kahan.add(term.abs());
                }
                r.row_sum = row_kahan.value();
                r.row_abs = row_abs_kahan.value();
                r
            })
            .collect();

        // Phase 3: Sequential merge
        for r in &batch_results {
            merge_single_row(decomp, r);
            running_sum.add(r.row_sum);
            running_abs.add(r.row_abs);

            if (progress + 1) % trace_iv == 0 {
                let j = active_rows[progress].1;
                decomp.trace.push((j, running_sum.value(), running_abs.value()));
            }
            progress += 1;
        }

        // Progress report (per batch)
        if progress % (n_active / 20).max(1) < HPDF_BATCH_SIZE {
            let pct = progress as f64 / n_active as f64 * 100.0;
            let el = t0.elapsed().as_secs_f64();
            let eta = if pct > 0.0 { el / (pct / 100.0) * (1.0 - pct / 100.0) } else { 0.0 };
            eprint!("\r  Rows: {progress}/{n_active} ({pct:.0}%) {el:.1}s ETA={eta:.1}s    ");
        }
    }
    Ok(())
}

// ═══════════════════════════════════════════════
// MERGE HELPERS
// ═══════════════════════════════════════════════

/// Merge a single RowResult into the Decomp.
fn merge_single_row(decomp: &mut Decomp, r: &RowResult) {
    decomp.total.add(r.total.value());
    decomp.diagonal.add(r.diagonal.value());
    decomp.off_diagonal.add(r.off_diagonal.value());

    for d in 0..=decomp.max_gcd {
        decomp.gcd_buckets[d].add(r.gcd_buckets[d].value());
    }
    for ch in 0..4 {
        decomp.channels[ch].add(r.channels[ch].value());
    }
    decomp.type_i.add(r.type_i.value());
    decomp.type_ii.add(r.type_ii.value());
    decomp.type_iii.add(r.type_iii.value());
    decomp.ee.add(r.ee.value());
    decomp.eo.add(r.eo.value());
    decomp.oe.add(r.oe.value());
    decomp.oo.add(r.oo.value());

    for wj in 0..=decomp.max_omega {
        for wk in 0..=decomp.max_omega {
            decomp.omega_buckets[wj][wk].add(r.omega_buckets[wj][wk].value());
        }
    }
    for bj in 0..=decomp.max_band {
        for bk in 0..=decomp.max_band {
            decomp.dyadic[bj][bk].add(r.dyadic[bj][bk].value());
        }
    }

    decomp.n_pos += r.n_pos;
    decomp.n_neg += r.n_neg;
    decomp.sum_pos.add(r.sum_pos.value());
    decomp.sum_neg.add(r.sum_neg.value());
}

/// Merge all parallel RowResults into the Decomp (for f64 on-the-fly mode).
fn merge_results(decomp: &mut Decomp, row_results: &[RowResult], active_rows: &[(usize, f64)]) {
    let mut running_sum = Kahan::default();
    let mut running_abs = Kahan::default();
    let n_active = row_results.len();
    let trace_iv = (n_active / 20).max(1);

    for (idx, r) in row_results.iter().enumerate() {
        merge_single_row(decomp, r);
        running_sum.add(r.row_sum);
        running_abs.add(r.row_abs);

        if (idx + 1) % trace_iv == 0 {
            decomp.trace.push((active_rows[idx].0, running_sum.value(), running_abs.value()));
        }
    }
}

// ═══════════════════════════════════════════════
// GRAM BOUND SUMMARY
// ═══════════════════════════════════════════════

fn print_gram_summary(d: &Decomp) {
    let vtgv = d.total.value();
    let ln_n = (d.n as f64).ln();
    eprintln!();
    eprintln!("  ┌─────────────────────────────────────────────┐");
    eprintln!("  │  GRAM BOUND ANALYSIS (N={:>6})              │", d.n);
    eprintln!("  ├─────────────────────────────────────────────┤");
    eprintln!("  │  vᵀGv        = {vtgv:>16.10}              │");
    eprintln!("  │  (bᵀv)²      = {:>16.10}              │", d.btv_sq);
    eprintln!("  │  vᵀCv        = {:>16.10}              │", d.vtcv);
    eprintln!("  │  d²_N        = {:>16.10}              │", d.d2n);
    eprintln!("  │  bᵀv         = {:>16.10}              │", d.btv);
    eprintln!("  │  1 - vᵀGv    = {:>16.10}              │", d.gap);
    eprintln!("  │  gap·ln(N)   = {:>16.10}              │", d.gap_times_ln);
    eprintln!("  │  (bᵀv)²/vᵀGv = {:>16.10}              │", d.ratio);
    eprintln!("  │  vtCv·ln(N)  = {:>16.10}              │", d.vtcv * ln_n);
    eprintln!("  │  d²·ln(N)    = {:>16.10}              │", d.d2n * ln_n);
    eprintln!("  │  Precision   = {:>16}              │", d.precision);
    eprintln!("  └─────────────────────────────────────────────┘");
}
