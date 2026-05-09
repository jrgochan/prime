//! Gram bound metric finalization and display.

use cathedral_utils::arith::{self, Kahan};
use cathedral_utils::mertens;
use super::state::Decomp;

/// Compute derived Gram-bound metrics from total = vᵀGv.
///
/// Uses the full k=1..N Lean-aligned basis.
pub fn finalize_gram_metrics(decomp: &mut Decomp) {
    let vtgv = decomp.total.value();
    let mu = arith::mobius_table(decomp.n);
    let weights = mertens::witness_vector_full(decomp.n, &mu);
    let b_vec = arith::b_vector_full(decomp.n);

    // bᵀv = Σ b_k * v_k  (k=1..N)
    let mut btv = Kahan::default();
    for k in 0..decomp.dim {
        btv.add(b_vec[k] * weights[k]);
    }
    let btv_val = btv.value();
    decomp.gram.btv = btv_val;
    decomp.gram.btv_sq = btv_val * btv_val;
    decomp.gram.vtcv = vtgv - decomp.gram.btv_sq;
    decomp.gram.d2n = 1.0 - 2.0 * btv_val + vtgv;
    decomp.gram.ratio = if vtgv > 1e-15 { decomp.gram.btv_sq / vtgv } else { 0.0 };
    decomp.gram.gap = 1.0 - vtgv;
    decomp.gram.gap_times_ln = decomp.gram.gap * (decomp.n as f64).ln();
}

/// Print Gram bound summary to stderr.
pub fn print_gram_summary(d: &Decomp) {
    let vtgv = d.total.value();
    let ln_n = (d.n as f64).ln();
    eprintln!();
    eprintln!("  ┌─────────────────────────────────────────────┐");
    eprintln!("  │  GRAM BOUND ANALYSIS (N={:>6})              │", d.n);
    eprintln!("  ├─────────────────────────────────────────────┤");
    eprintln!("  │  vᵀGv        = {:>16.10}              │", vtgv);
    eprintln!("  │  (bᵀv)²      = {:>16.10}              │", d.gram.btv_sq);
    eprintln!("  │  vᵀCv        = {:>16.10}              │", d.gram.vtcv);
    eprintln!("  │  d²_N        = {:>16.10}              │", d.gram.d2n);
    eprintln!("  │  bᵀv         = {:>16.10}              │", d.gram.btv);
    eprintln!("  │  1 - vᵀGv    = {:>16.10}              │", d.gram.gap);
    eprintln!("  │  gap·ln(N)   = {:>16.10}              │", d.gram.gap_times_ln);
    eprintln!("  │  (bᵀv)²/vᵀGv = {:>16.10}              │", d.gram.ratio);
    eprintln!("  │  vtCv·ln(N)  = {:>16.10}              │", d.gram.vtcv * ln_n);
    eprintln!("  │  d²·ln(N)    = {:>16.10}              │", d.gram.d2n * ln_n);
    eprintln!("  │  Precision   = {:>16}              │", d.precision);
    eprintln!("  └─────────────────────────────────────────────┘");
}
