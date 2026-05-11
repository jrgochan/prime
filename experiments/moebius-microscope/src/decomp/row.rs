//! Per-row result struct and merge logic.
//!
//! `RowResult` is the per-thread accumulator used in the parallel map phase.
//! After all rows are computed, results are merged into the global `Decomp`.

use super::state::Decomp;
use cathedral_utils::arith::Kahan;

// ═══════════════════════════════════════════════
// PER-ROW RESULT
// ═══════════════════════════════════════════════

pub struct RowResult {
    pub total: Kahan,
    pub diagonal: Kahan,
    pub off_diagonal: Kahan,
    pub gcd_buckets: Vec<Kahan>,
    pub channels: [Kahan; 4],
    pub type_i: Kahan,
    pub type_ii: Kahan,
    pub type_iii: Kahan,
    pub ee: Kahan,
    pub eo: Kahan,
    pub oe: Kahan,
    pub oo: Kahan,
    pub omega_buckets: Vec<Vec<Kahan>>,
    pub dyadic: Vec<Vec<Kahan>>,
    pub n_pos: u64,
    pub n_neg: u64,
    pub sum_pos: Kahan,
    pub sum_neg: Kahan,
    pub row_sum: f64,
    pub row_abs: f64,

    // §10: Taper per-row accumulators
    pub u_row: Kahan,          // Σ_k μ(j)·μ(k)·G(j,k)
    pub l_row: Kahan,          // Σ_k μ(j)·μ(k)·ln(j)·G(j,k)
    pub q_row: Kahan,          // Σ_k μ(j)·μ(k)·ln(j)·ln(k)·G(j,k)
    pub taper_gcd: Vec<Kahan>, // per-gcd taper contribution (weighted term)
}

impl RowResult {
    pub fn new(max_gcd: usize, max_omega: usize, max_band: usize) -> Self {
        Self {
            total: Kahan::default(),
            diagonal: Kahan::default(),
            off_diagonal: Kahan::default(),
            gcd_buckets: vec![Kahan::default(); max_gcd + 1],
            channels: [Kahan::default(); 4],
            type_i: Kahan::default(),
            type_ii: Kahan::default(),
            type_iii: Kahan::default(),
            ee: Kahan::default(),
            eo: Kahan::default(),
            oe: Kahan::default(),
            oo: Kahan::default(),
            omega_buckets: vec![vec![Kahan::default(); max_omega + 1]; max_omega + 1],
            dyadic: vec![vec![Kahan::default(); max_band + 1]; max_band + 1],
            n_pos: 0,
            n_neg: 0,
            sum_pos: Kahan::default(),
            sum_neg: Kahan::default(),
            row_sum: 0.0,
            row_abs: 0.0,
            u_row: Kahan::default(),
            l_row: Kahan::default(),
            q_row: Kahan::default(),
            taper_gcd: vec![Kahan::default(); max_gcd + 1],
        }
    }
}

// ═══════════════════════════════════════════════
// MERGE HELPERS
// ═══════════════════════════════════════════════

/// Merge a single RowResult into the Decomp.
pub fn merge_single_row(decomp: &mut Decomp, r: &RowResult) {
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

    // §10: Taper merge
    decomp.taper.u_sum.add(r.u_row.value());
    decomp.taper.l_sum.add(r.l_row.value());
    decomp.taper.q_sum.add(r.q_row.value());
    for d in 0..=decomp
        .max_gcd
        .min(decomp.taper.u_by_gcd.len().saturating_sub(1))
    {
        decomp.taper.u_by_gcd[d].add(r.taper_gcd[d].value());
    }
}

/// Merge all parallel RowResults into the Decomp (for f64 on-the-fly mode).
pub fn merge_results(decomp: &mut Decomp, row_results: &[RowResult], active_rows: &[(usize, f64)]) {
    use super::state::TracePoint;
    let mut running_sum = Kahan::default();
    let mut running_abs = Kahan::default();
    let n_active = row_results.len();
    let trace_iv = (n_active / 20).max(1);

    for (idx, r) in row_results.iter().enumerate() {
        merge_single_row(decomp, r);
        running_sum.add(r.row_sum);
        running_abs.add(r.row_abs);

        if (idx + 1) % trace_iv == 0 {
            decomp.trace.push(TracePoint {
                j: active_rows[idx].0,
                running_sum: running_sum.value(),
                running_abs: running_abs.value(),
            });
        }
    }
}
