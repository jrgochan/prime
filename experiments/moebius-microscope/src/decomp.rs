//! Parallel decomposition engine for the Möbius Cancellation Microscope.
//! Uses rayon to parallelize row computation with per-row buckets + merge.

use cathedral_utils::arith::{self, Kahan};
use cathedral_utils::gram;
use rayon::prelude::*;
use std::time::Instant;

// ═══════════════════════════════════════════════
// DECOMPOSITION STATE
// ═══════════════════════════════════════════════

pub struct Decomp {
    pub n: usize,
    pub dim: usize,
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
}

impl Decomp {
    pub fn new(n: usize) -> Self {
        let max_gcd = (n as f64).sqrt() as usize + 1;
        let max_omega = 8;
        let max_band = ((n as f64).log2() as usize) + 1;
        let mut robin_sigma = vec![0.0f64; max_gcd + 1];
        for d in 1..=max_gcd {
            robin_sigma[d] = arith::sigma1(d) as f64 / d as f64;
        }
        Self {
            n, dim: n - 1,
            total: Kahan::default(), diagonal: Kahan::default(), off_diagonal: Kahan::default(),
            gcd_buckets: vec![Kahan::default(); max_gcd + 1], max_gcd,
            channels: [Kahan::default(); 4],
            type_i: Kahan::default(), type_ii: Kahan::default(), type_iii: Kahan::default(),
            ee: Kahan::default(), eo: Kahan::default(), oe: Kahan::default(), oo: Kahan::default(),
            omega_buckets: vec![vec![Kahan::default(); max_omega + 1]; max_omega + 1], max_omega,
            dyadic: vec![vec![Kahan::default(); max_band + 1]; max_band + 1], max_band,
            n_pos: 0, n_neg: 0, sum_pos: Kahan::default(), sum_neg: Kahan::default(),
            robin_sigma, trace: Vec::new(),
        }
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
// PARALLEL MICROSCOPE ENGINE
// ═══════════════════════════════════════════════

/// Compute one row's contribution to all decompositions.
fn compute_row(
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

        r.total.add(term);
        row_sum.add(term);
        row_abs.add(term.abs());

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
    r.row_sum = row_sum.value();
    r.row_abs = row_abs.value();
    r
}

/// Run the full parallel microscope for a given N.
pub fn run_microscope(n: usize) -> Decomp {
    let t0 = Instant::now();
    let dim = n - 1;
    eprintln!("\n═══ MÖBIUS MICROSCOPE N={n} (dim={dim}) ═══");

    let weights = arith::mobius_weights(n);
    let liouville = arith::liouville_table(n);
    let omega_tbl = arith::small_omega_table(n);

    let n13 = (n as f64).powf(1.0/3.0) as usize;
    let n23 = (n as f64).powf(2.0/3.0) as usize;
    let nonzero = weights.iter().filter(|&&w| w.abs() > 1e-30).count();
    eprintln!("  Vaughan: I ≤ {n13}, II ≤ {n23}");
    eprintln!("  Non-zero weights: {nonzero}/{dim}");
    eprintln!("  Parallelism: {} threads", rayon::current_num_threads());

    let mut decomp = Decomp::new(n);

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
            let r = compute_row(
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

    // MERGE: sequential merge of all row results (this is cheap)
    let mut running_sum = Kahan::default();
    let mut running_abs = Kahan::default();
    let trace_iv = (n_active / 20).max(1);

    for (idx, r) in row_results.iter().enumerate() {
        decomp.total.add(r.total.value());
        decomp.diagonal.add(r.diagonal.value());
        decomp.off_diagonal.add(r.off_diagonal.value());
        running_sum.add(r.row_sum);
        running_abs.add(r.row_abs);

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

        // Trace at intervals
        if (idx + 1) % trace_iv == 0 {
            decomp.trace.push((active_rows[idx].0, running_sum.value(), running_abs.value()));
        }
    }

    eprintln!("\r  ✓ Done in {:.1}s ({n_active} rows × {dim} cols, {} threads)                      ",
        t0.elapsed().as_secs_f64(), rayon::current_num_threads());
    decomp
}
