//! Per-term classification kernel — the hot inner loop.
//!
//! Called once for every (j,k) pair in the quadratic form.
//! Keep this lean and `#[inline]` for performance.

use super::row::RowResult;
use cathedral_utils::arith;

/// Classify and accumulate a single (j,k) term into all decomposition buckets.
///
/// This is the shared kernel used by both on-the-fly and HPDF modes.
#[inline]
pub fn classify_term(
    r: &mut RowResult,
    j: usize,
    k: usize,
    term: f64,
    mu_j: f64,
    mu_k: f64,
    _ln_j: f64,
    _ln_k: f64,
    liouville: &[i8],
    omega_tbl: &[u32],
    n13: usize,
    n23: usize,
    max_gcd: usize,
    max_omega: usize,
    max_band: usize,
) {
    r.total.add(term);

    if j == k {
        r.diagonal.add(term);
    } else {
        r.off_diagonal.add(term);
    }

    let gcd_val = arith::gcd(j, k);
    if gcd_val <= max_gcd {
        r.gcd_buckets[gcd_val].add(term);
    }

    for ch in 0..4 {
        r.channels[ch].add(arith::chi8(ch, j) as f64 * arith::chi8(ch, k) as f64 * term);
    }

    let mn = j.min(k);
    if mn <= n13 {
        r.type_i.add(term);
    } else if mn <= n23 {
        r.type_ii.add(term);
    } else {
        r.type_iii.add(term);
    }

    match (liouville[j], liouville[k]) {
        (1, 1) => r.ee.add(term),
        (1, -1) => r.eo.add(term),
        (-1, 1) => r.oe.add(term),
        (-1, -1) => r.oo.add(term),
        _ => {}
    }

    let wj = (omega_tbl[j] as usize).min(max_omega);
    let wk = (omega_tbl[k] as usize).min(max_omega);
    r.omega_buckets[wj][wk].add(term);

    let bj = if j >= 2 {
        (j as f64).log2() as usize
    } else {
        0
    }
    .min(max_band);
    let bk = if k >= 2 {
        (k as f64).log2() as usize
    } else {
        0
    }
    .min(max_band);
    r.dyadic[bj][bk].add(term);

    if term > 0.0 {
        r.n_pos += 1;
        r.sum_pos.add(term);
    } else if term < 0.0 {
        r.n_neg += 1;
        r.sum_neg.add(term);
    }

    // §10: Taper accumulation (only for squarefree j,k — μ(j)μ(k) ≠ 0)
    // The caller has already checked μ ≠ 0, so we use the raw G(j,k) = term / (v_j * v_k).
    // Instead, we accumulate μ(j)μ(k)G, μ(j)μ(k)ln(j)G, μ(j)μ(k)ln(j)ln(k)G.
    if mu_j.abs() > 0.5 && mu_k.abs() > 0.5 {
        // We need the raw Gram entry G(j,k). Since term = v_j * G(j,k) * v_k,
        // and v_j = -μ(j)·(1 - ln(j)/ln(N)), the relationship is complex.
        // Instead, we pass μ and ln values and compute the untapered terms directly.
        // The caller must provide the raw Gram entry for taper tracking.
        // For now, we accumulate per-gcd taper if possible.
        if gcd_val <= max_gcd {
            // Track gcd-stratified weighted term contribution
            r.taper_gcd[gcd_val].add(term);
        }
    }
}
