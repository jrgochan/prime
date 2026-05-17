//! Parallel execution engines for the Möbius Cancellation Microscope.
//!
//! Two modes:
//!  - `run_microscope`: compute Gram entries on-the-fly at f64 precision
//!  - `run_microscope_hpdf`: load DD-lossless rows from HPDF files

use cathedral_utils::arith::{self, Kahan};
use cathedral_utils::gram;
use cathedral_utils::mertens;
use rayon::prelude::*;
use std::time::Instant;

use super::classify::classify_term;
use super::gram::{finalize_gram_metrics, print_gram_summary};
#[cfg(feature = "hpdf")]
use super::row::merge_single_row;
use super::row::{merge_results, RowResult};
use super::physics::{self, PhysicsRow};
use super::state::Decomp;
#[cfg(feature = "hpdf")]
use super::state::TracePoint;
use super::taper::{finalize_taper_metrics, print_taper_summary};

// ═══════════════════════════════════════════════
// MODE 1: ON-THE-FLY (f64 precision)
// ═══════════════════════════════════════════════

/// Compute one row using on-the-fly Gram entry computation (f64).
fn compute_row_f64(
    j: usize,
    v_j: f64,
    dim: usize,
    _n: usize,
    mu: &[i8],
    weights: &[f64],
    liouville: &[i8],
    omega_tbl: &[u32],
    n13: usize,
    n23: usize,
    max_gcd: usize,
    max_omega: usize,
    max_band: usize,
) -> (RowResult, PhysicsRow) {
    let mut r = RowResult::new(max_gcd, max_omega, max_band);
    let mut pr = PhysicsRow::new();
    let mut row_sum = Kahan::default();
    let mut row_abs = Kahan::default();

    let mu_j = mu[j] as f64;
    let ln_j = (j as f64).ln();

    for k_idx in 0..dim {
        let k = k_idx + 1; // k=1..N (Lean-aligned)
        let v_k = weights[k_idx];
        if v_k.abs() < 1e-30 {
            continue;
        }

        let g_jk = gram::gram_entry_f64(j, k);
        let term = v_j * g_jk * v_k;

        let mu_k = mu[k] as f64;
        let ln_k = (k as f64).ln();

        classify_term(
            &mut r, j, k, term, mu_j, mu_k, ln_j, ln_k, liouville, omega_tbl, n13, n23, max_gcd,
            max_omega, max_band,
        );

        // §11-§16: Physics classification
        physics::classify_physics(&mut pr, j, k, term, v_j, v_k, g_jk);

        // §10: Taper accumulation (raw Möbius-Gram terms)
        if mu_j.abs() > 0.5 && mu_k.abs() > 0.5 {
            let mm_g = mu_j * mu_k * g_jk;
            r.u_row.add(mm_g);
            r.l_row.add(mm_g * ln_j);
            r.q_row.add(mm_g * ln_j * ln_k);
        }

        row_sum.add(term);
        row_abs.add(term.abs());
    }
    r.row_sum = row_sum.value();
    r.row_abs = row_abs.value();
    (r, pr)
}

/// Run the full parallel microscope for a given N using on-the-fly f64 computation.
pub fn run_microscope(n: usize) -> Decomp {
    let t0 = Instant::now();
    let dim = n; // Lean-aligned: k=1..N
    eprintln!("\n═══ MÖBIUS MICROSCOPE N={n} (dim={dim}) [f64 on-the-fly, k=1..N] ═══");

    let mu = arith::mobius_table(n);
    let weights = mertens::witness_vector_full(n, &mu);
    let liouville = arith::liouville_table(n);
    let omega_tbl = arith::small_omega_table(n);

    let n13 = (n as f64).powf(1.0 / 3.0) as usize;
    let n23 = (n as f64).powf(2.0 / 3.0) as usize;
    let nonzero = weights.iter().filter(|&&w| w.abs() > 1e-30).count();
    eprintln!("  Vaughan: I ≤ {n13}, II ≤ {n23}");
    eprintln!("  Non-zero weights: {nonzero}/{dim}");
    eprintln!("  Parallelism: {} threads", rayon::current_num_threads());

    let mut decomp = Decomp::new(n, "f64");

    // Collect active rows (non-zero weight) — k=1..N
    let active_rows: Vec<(usize, f64)> = (0..dim)
        .map(|j_idx| (j_idx + 1, weights[j_idx])) // j = j_idx+1 (Lean-aligned)
        .filter(|(_, w)| w.abs() > 1e-30)
        .collect();
    let n_active = active_rows.len();
    eprintln!("  Active rows: {n_active} (processing in parallel)");

    // PARALLEL: compute all rows
    let done = std::sync::atomic::AtomicUsize::new(0);
    let row_results: Vec<(RowResult, PhysicsRow)> = active_rows
        .par_iter()
        .map(|&(j, v_j)| {
            let result = compute_row_f64(
                j,
                v_j,
                dim,
                n,
                &mu,
                &weights,
                &liouville,
                &omega_tbl,
                n13,
                n23,
                decomp.max_gcd,
                decomp.max_omega,
                decomp.max_band,
            );
            let cnt = done.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
            if cnt % (n_active / 20).max(1) == 0 && cnt > 0 {
                let pct = cnt as f64 / n_active as f64 * 100.0;
                let el = t0.elapsed().as_secs_f64();
                let eta =
                    el / (cnt as f64 / n_active as f64) * (1.0 - cnt as f64 / n_active as f64);
                eprint!("\r  Rows: {cnt}/{n_active} ({pct:.0}%) {el:.1}s ETA={eta:.1}s    ");
            }
            result
        })
        .collect();

    // Split and merge
    let (rr, pr): (Vec<_>, Vec<_>) = row_results.into_iter().unzip();
    merge_results(&mut decomp, &rr, &active_rows);
    for (i, p) in pr.iter().enumerate() {
        physics::merge_physics_row(&mut decomp.physics, p, active_rows[i].1);
    }
    let sum_v: f64 = weights.iter().sum();
    physics::finalize_physics(&mut decomp.physics, n_active, sum_v);

    // Finalize all metrics
    finalize_gram_metrics(&mut decomp);
    finalize_taper_metrics(&mut decomp);

    eprintln!(
        "\r  ✓ Done in {:.1}s ({n_active} rows × {dim} cols, {} threads)                      ",
        t0.elapsed().as_secs_f64(),
        rayon::current_num_threads()
    );
    print_gram_summary(&decomp);
    print_taper_summary(&decomp);
    decomp
}

// ═══════════════════════════════════════════════
// MODE 2: HPDF BATCH-PARALLEL (DD precision)
// ═══════════════════════════════════════════════

/// Batch size for row reads from HPDF (tuned: 256 rows ≈ good I/O amortization
/// while keeping per-batch working sets in L3 cache for large N)
#[cfg(feature = "hpdf")]
const HPDF_BATCH_SIZE: usize = 256;

/// Run the microscope using an HPDF file for DD-lossless Gram entries.
///
/// The HPDF file stores a (N-1)×(N-1) matrix for k=2..N. We augment it
/// with the k=1 row/column (computed on-the-fly) to produce the full
/// N×N Lean-aligned k=1..N basis.
#[cfg(feature = "hpdf")]
pub fn run_microscope_hpdf(path: &std::path::Path) -> Result<Decomp, String> {
    use cathedral_utils::hpdf::{stamp_microscope, HpdfReader, MicroscopeResult};

    let t0 = Instant::now();

    // Scope the reader so it's dropped before we reopen for RW stamping
    let (n, _dim, prec_str, decomp) = {
        let reader = HpdfReader::open(path).map_err(|e| format!("HPDF open: {e}"))?;
        let hpdf_dim = reader.dim(); // N-1 (k=2..N stored in file)
        let n = reader.max_n();
        let dim = n; // Lean-aligned: k=1..N
        let has_dd = reader.has_dd();
        let prec_label = if has_dd { "DD (~31 digits)" } else { "f64" };

        eprintln!("\n═══ MÖBIUS MICROSCOPE N={n} (dim={dim}, HPDF_dim={hpdf_dim}) [HPDF {prec_label}, k=1..N] ═══");
        eprintln!("  File: {}", path.display());
        eprintln!("  Parallelism: {} threads", rayon::current_num_threads());

        let mu = arith::mobius_table(n);
        let weights = mertens::witness_vector_full(n, &mu); // k=1..N
        let liouville = arith::liouville_table(n);
        let omega_tbl = arith::small_omega_table(n);

        let n13 = (n as f64).powf(1.0 / 3.0) as usize;
        let n23 = (n as f64).powf(2.0 / 3.0) as usize;
        let nonzero = weights.iter().filter(|&&w| w.abs() > 1e-30).count();
        eprintln!("  Vaughan: I ≤ {n13}, II ≤ {n23}");
        eprintln!("  Non-zero weights: {nonzero}/{dim}");

        let prec_str = if has_dd { "DD" } else { "HPDF-f64" };
        let mut decomp = Decomp::new(n, prec_str);

        // Active rows: those with non-zero Möbius weight — k=1..N
        // Tuple: (gram_k, v_k) where gram_k is the actual integer index
        let active_rows: Vec<(usize, usize, f64)> = (0..dim)
            .map(|k_idx| (k_idx, k_idx + 1, weights[k_idx])) // k = k_idx+1 (Lean-aligned)
            .filter(|(_, _, w)| w.abs() > 1e-30)
            .collect();
        let n_active = active_rows.len();

        // Memory estimate: full augmented matrix = dim*dim*8 bytes
        let full_matrix_bytes = (dim as u64) * (dim as u64) * 8;
        let use_full_load = full_matrix_bytes < 2_000_000_000; // 2GB threshold

        if use_full_load {
            eprintln!(
                "  Strategy: FULL MATRIX LOAD + k=1 augmentation ({:.1} MB) + parallel rows",
                full_matrix_bytes as f64 / 1e6
            );
            run_hpdf_full_parallel(
                &reader,
                &mut decomp,
                &active_rows,
                &mu,
                &weights,
                &liouville,
                &omega_tbl,
                n13,
                n23,
                &t0,
            )?;
        } else {
            eprintln!(
                "  Strategy: BATCHED ROW-STREAM (batch={HPDF_BATCH_SIZE}) + k=1 augmentation"
            );
            run_hpdf_batched(
                &reader,
                &mut decomp,
                &active_rows,
                &mu,
                &weights,
                &liouville,
                &omega_tbl,
                n13,
                n23,
                &t0,
            )?;
        }

        // Finalize all metrics
        finalize_gram_metrics(&mut decomp);
        finalize_taper_metrics(&mut decomp);

        let elapsed_so_far = t0.elapsed().as_secs_f64();
        eprintln!("\r  ✓ Done in {elapsed_so_far:.1}s ({n_active} active rows × {dim} cols, HPDF {prec_str})                      ");
        print_gram_summary(&decomp);
        print_taper_summary(&decomp);

        (n, dim, prec_str.to_string(), decomp)
    }; // reader dropped here — file handle released

    // Stamp diagnostics back into the HPDF file (requires RW access)
    let elapsed = t0.elapsed().as_secs_f64();
    let ln_n = (n as f64).ln();
    let t = &decomp.taper;
    let recon = t.u_sum.value() - 2.0 / ln_n * t.l_sum.value() + t.q_sum.value() / (ln_n * ln_n);
    let result = MicroscopeResult {
        n,
        precision: prec_str,
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

/// Full matrix load + parallel row processing with k=1 augmentation.
///
/// The HPDF file stores (N-1)×(N-1) entries for k=2..N. We augment
/// with the k=1 row/column computed on-the-fly using gram_entry_f64.
#[cfg(feature = "hpdf")]
fn run_hpdf_full_parallel(
    reader: &cathedral_utils::hpdf::HpdfReader,
    decomp: &mut Decomp,
    active_rows: &[(usize, usize, f64)],
    mu: &[i8],
    weights: &[f64],
    liouville: &[i8],
    omega_tbl: &[u32],
    n13: usize,
    n23: usize,
    t0: &Instant,
) -> Result<(), String> {
    let dim = decomp.dim; // N (Lean-aligned k=1..N)
    let n = decomp.n;
    let hpdf_dim = n - 1; // N-1 (k=2..N stored in file)
    let n_active = active_rows.len();

    // Load the (N-1)×(N-1) HPDF matrix (packed upper triangle)
    eprintln!("  Loading HPDF matrix ({hpdf_dim}×{hpdf_dim}) from file...");
    let gram_flat = reader
        .read_gram_full()
        .map_err(|e| format!("read_gram_full: {e}"))?;
    eprintln!(
        "  ✓ Loaded {} entries ({:.1} MB)",
        gram_flat.len(),
        gram_flat.len() as f64 * 8.0 / 1e6
    );

    // Precompute k=1 row: G(1,k) for k=1..N via on-the-fly f64
    eprintln!("  Computing k=1 augmentation row ({dim} entries)...");
    let k1_row: Vec<f64> = (0..dim)
        .map(|k_idx| {
            let k = k_idx + 1; // k=1..N
            gram::gram_entry_f64(1, k)
        })
        .collect();
    eprintln!(
        "  ✓ k=1 row computed (G(1,1)={:.10}, G(1,2)={:.10})",
        k1_row[0],
        if dim > 1 { k1_row[1] } else { 0.0 }
    );

    // Augmented gram entry: handles both HPDF (k≥2) and k=1 (on-the-fly)
    // In the full k=1..N basis:
    //   k_idx=0 → k=1 (use k1_row or gram_entry_f64)
    //   k_idx≥1 → k=k_idx+1, maps to HPDF index k_idx-1
    let gram_entry_augmented = |j_idx: usize, k_idx: usize| -> f64 {
        let j = j_idx + 1; // actual integer index
        let k = k_idx + 1;
        if j == 1 {
            // j=1: entire row precomputed
            k1_row[k_idx]
        } else if k == 1 {
            // k=1: use symmetry G(j,1) = G(1,j) = k1_row[j_idx]
            k1_row[j_idx]
        } else {
            // Both j,k ≥ 2: look up in HPDF packed upper triangle
            // HPDF indices: hj = j-2, hk = k-2 (0-based in (N-1)×(N-1))
            let hj = j_idx - 1;
            let hk = k_idx - 1;
            let (r, c) = if hj <= hk { (hj, hk) } else { (hk, hj) };
            gram_flat[r * hpdf_dim - r * (r + 1) / 2 + c]
        }
    };

    let done = std::sync::atomic::AtomicUsize::new(0);
    let row_results: Vec<(RowResult, PhysicsRow)> = active_rows
        .par_iter()
        .map(|&(j_idx, j, v_j)| {
            let mut r = RowResult::new(decomp.max_gcd, decomp.max_omega, decomp.max_band);
            let mut pr = PhysicsRow::new();
            let mut row_kahan = Kahan::default();
            let mut row_abs_kahan = Kahan::default();
            let mu_j = mu[j] as f64;
            let ln_j = (j as f64).ln();

            for k_idx in 0..dim {
                let k = k_idx + 1; // k=1..N (Lean-aligned)
                let v_k = weights[k_idx];
                if v_k.abs() < 1e-30 {
                    continue;
                }

                let g_jk = gram_entry_augmented(j_idx, k_idx);
                let term = v_j * g_jk * v_k;
                let mu_k = mu[k] as f64;
                let ln_k = (k as f64).ln();

                classify_term(
                    &mut r,
                    j,
                    k,
                    term,
                    mu_j,
                    mu_k,
                    ln_j,
                    ln_k,
                    liouville,
                    omega_tbl,
                    n13,
                    n23,
                    decomp.max_gcd,
                    decomp.max_omega,
                    decomp.max_band,
                );

                // §11-§16: Physics classification
                physics::classify_physics(&mut pr, j, k, term, v_j, v_k, g_jk);

                // §10: Taper
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
            (r, pr)
        })
        .collect();

    // Split and merge
    let (rr, pr_vec): (Vec<_>, Vec<_>) = row_results.into_iter().unzip();
    let active_for_merge: Vec<(usize, f64)> = active_rows.iter().map(|&(_, j, v)| (j, v)).collect();
    merge_results(decomp, &rr, &active_for_merge);
    for (i, p) in pr_vec.iter().enumerate() {
        physics::merge_physics_row(&mut decomp.physics, p, active_rows[i].2);
    }
    let sum_v: f64 = weights.iter().sum();
    physics::finalize_physics(&mut decomp.physics, active_rows.len(), sum_v);
    Ok(())
}

/// Batched row-streaming for large N with k=1 augmentation.
///
/// Each HPDF row read returns (N-1) entries for k=2..N. We prepend the
/// on-the-fly G(j,1) entry to create an N-entry augmented row for k=1..N.
/// For j=1 (which has no HPDF row), the entire row is computed on-the-fly.
#[cfg(feature = "hpdf")]
fn run_hpdf_batched(
    reader: &cathedral_utils::hpdf::HpdfReader,
    decomp: &mut Decomp,
    active_rows: &[(usize, usize, f64)],
    mu: &[i8],
    weights: &[f64],
    liouville: &[i8],
    omega_tbl: &[u32],
    n13: usize,
    n23: usize,
    t0: &Instant,
) -> Result<(), String> {
    let dim = decomp.dim; // N (Lean-aligned k=1..N)
    let n = decomp.n;
    let hpdf_dim = n - 1; // N-1 (k=2..N in file)
    let n_active = active_rows.len();
    let trace_iv = (n_active / 40).max(1);
    let mut running_sum = Kahan::default();
    let mut running_abs = Kahan::default();
    let mut progress = 0usize;

    for batch in active_rows.chunks(HPDF_BATCH_SIZE) {
        // For each row in the batch, build the augmented N-entry row
        let batch_rows: Vec<(usize, usize, f64, Vec<f64>)> = batch
            .iter()
            .map(|&(j_idx, j, v_j)| {
                let augmented_row = if j == 1 {
                    // j=1: no HPDF row exists, compute entire row on-the-fly
                    (0..dim)
                        .map(|k_idx| {
                            let k = k_idx + 1;
                            gram::gram_entry_f64(1, k)
                        })
                        .collect()
                } else {
                    // j≥2: read (N-1) entries from HPDF, prepend G(j,1)
                    let hpdf_idx = j_idx - 1; // HPDF uses 0-based for k=2..N
                    let hpdf_row = reader
                        .read_gram_row(hpdf_idx)
                        .unwrap_or_else(|_| vec![0.0; hpdf_dim]);
                    // Prepend G(j,1) computed on-the-fly
                    let g_j1 = gram::gram_entry_f64(j, 1);
                    let mut full = Vec::with_capacity(dim);
                    full.push(g_j1);
                    full.extend_from_slice(&hpdf_row);
                    full
                };
                (j_idx, j, v_j, augmented_row)
            })
            .collect();

        let batch_results: Vec<(RowResult, PhysicsRow)> = batch_rows
            .par_iter()
            .map(|(_, j, v_j, row)| {
                let j = *j;
                let v_j = *v_j;
                let mu_j = mu[j] as f64;
                let ln_j = (j as f64).ln();
                let mut r = RowResult::new(decomp.max_gcd, decomp.max_omega, decomp.max_band);
                let mut pr = PhysicsRow::new();
                let mut row_kahan = Kahan::default();
                let mut row_abs_kahan = Kahan::default();

                for k_idx in 0..dim {
                    let k = k_idx + 1; // k=1..N (Lean-aligned)
                    let v_k = weights[k_idx];
                    if v_k.abs() < 1e-30 {
                        continue;
                    }

                    let g_jk = row[k_idx];
                    let term = v_j * g_jk * v_k;
                    let mu_k = mu[k] as f64;
                    let ln_k = (k as f64).ln();

                    classify_term(
                        &mut r,
                        j,
                        k,
                        term,
                        mu_j,
                        mu_k,
                        ln_j,
                        ln_k,
                        liouville,
                        omega_tbl,
                        n13,
                        n23,
                        decomp.max_gcd,
                        decomp.max_omega,
                        decomp.max_band,
                    );

                    // §11-§16: Physics classification
                    physics::classify_physics(&mut pr, j, k, term, v_j, v_k, g_jk);

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
                (r, pr)
            })
            .collect();

        for (idx, (r, pr)) in batch_results.iter().enumerate() {
            merge_single_row(decomp, r);
            physics::merge_physics_row(&mut decomp.physics, pr, batch[idx].2);
            running_sum.add(r.row_sum);
            running_abs.add(r.row_abs);

            if (progress + 1) % trace_iv == 0 {
                let j = active_rows[progress].1;
                decomp.trace.push(TracePoint {
                    j,
                    running_sum: running_sum.value(),
                    running_abs: running_abs.value(),
                });
            }
            progress += 1;
        }

        if progress % (n_active / 20).max(1) < HPDF_BATCH_SIZE {
            let pct = progress as f64 / n_active as f64 * 100.0;
            let el = t0.elapsed().as_secs_f64();
            let eta = if pct > 0.0 {
                el / (pct / 100.0) * (1.0 - pct / 100.0)
            } else {
                0.0
            };
            eprint!("\r  Rows: {progress}/{n_active} ({pct:.0}%) {el:.1}s ETA={eta:.1}s    ");
        }
    }
    let sum_v: f64 = weights.iter().sum();
    physics::finalize_physics(&mut decomp.physics, n_active, sum_v);
    Ok(())
}
