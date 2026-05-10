//! §5 Taper Cancellation Tracker — analyzing U(N) - 2L(N)/lnN → 1.
//!
//! This module tracks the taper decomposition of the Gram form:
//!   vᵀGv = U(N) - 2L(N)/lnN + Q(N)/ln²N
//!
//! where:
//!   U(N) = Σ μ(j)μ(k) G(j,k)           (untapered "ground state")
//!   L(N) = Σ μ(j)μ(k) ln(j) G(j,k)     (linear taper)
//!   Q(N) = Σ μ(j)μ(k) ln(j)ln(k) G(j,k) (quadratic taper)
//!
//! The key identity from TaperDecomposition.lean:
//!   R₂(N) ≡ U(N) - 2L(N)/lnN
//!   (R₂ - 1)·lnN → C_recon ≈ -2.87
//!
//! If R₂ → 1, then vᵀGv → 1, which is the Riemann Hypothesis.

use cathedral_utils::arith::Kahan;
use rayon::prelude::*;
use super::state::Decomp;

// ═══════════════════════════════════════════════
// TAPER METRICS STRUCT
// ═══════════════════════════════════════════════

/// A snapshot of taper convergence at a partial cutoff.
#[allow(dead_code)]
pub struct TaperTracePoint {
    pub m: usize,
    pub u_partial: f64,
    pub l_partial: f64,
    pub q_partial: f64,
    pub r2_partial: f64,
}

/// All taper cancellation metrics for a single N.
pub struct TaperMetrics {
    // Raw taper sums (Kahan-compensated)
    pub u_sum: Kahan,           // U(N) = Σ μ(j)μ(k) G(j,k)
    pub l_sum: Kahan,           // L(N) = Σ μ(j)μ(k) ln(j) G(j,k)
    pub q_sum: Kahan,           // Q(N) = Σ μ(j)μ(k) ln(j)ln(k) G(j,k)

    // Independent vᵀGv reconstruction from scratch (cross-check)
    pub vtgv_recon: f64,        // Σ v_j · G(j,k) · v_k  (f64 recomputation)

    // Derived metrics (computed in finalize)
    pub r2: f64,                // R₂ = U - 2L/lnN
    pub r2_minus_1: f64,        // R₂ - 1
    pub r2_times_ln: f64,       // (R₂ - 1) · lnN  ≈ -2.87
    pub q_over_ln2: f64,        // Q / ln²N
    pub c_recon: f64,           // (1 - vᵀGv) · lnN ≈ 2.87

    // GCD-stratified taper
    pub u_by_gcd: Vec<Kahan>,   // U_d: terms with gcd(j,k)=d
    pub l_by_gcd: Vec<Kahan>,   // L_d: linear taper per GCD stratum
    pub q_by_gcd: Vec<Kahan>,   // Q_d: quadratic taper per GCD stratum

    // PNT sub-sums
    pub s1: f64,                // Σ μ(k)/k → 0
    pub s2: f64,                // Σ μ(k)ln(k)/k → -1
    pub s3: f64,                // Σ μ(k)ln²(k)/k → -2γ
    pub mertens: f64,           // M(N) = Σ_{k≤N} μ(k)
    pub mertens_over_sqrt: f64, // M(N)/√N (bounded if RH)

    // Running taper trajectory
    #[allow(dead_code)]
    pub taper_trace: Vec<TaperTracePoint>,
}

impl TaperMetrics {
    pub fn new(max_gcd: usize) -> Self {
        Self {
            u_sum: Kahan::default(),
            l_sum: Kahan::default(),
            q_sum: Kahan::default(),
            vtgv_recon: 0.0,
            r2: 0.0, r2_minus_1: 0.0, r2_times_ln: 0.0,
            q_over_ln2: 0.0, c_recon: 0.0,
            u_by_gcd: vec![Kahan::default(); max_gcd + 1],
            l_by_gcd: vec![Kahan::default(); max_gcd + 1],
            q_by_gcd: vec![Kahan::default(); max_gcd + 1],
            s1: 0.0, s2: 0.0, s3: 0.0,
            mertens: 0.0, mertens_over_sqrt: 0.0,
            taper_trace: Vec::new(),
        }
    }
}

// ═══════════════════════════════════════════════
// PARALLEL REDUCTION ACCUMULATOR
// ═══════════════════════════════════════════════

/// Per-thread accumulator for the parallel taper reduction.
/// Each thread folds its assigned rows into one of these, then
/// they are merged via `reduce`.
struct TaperAccum {
    u: Kahan,
    l: Kahan,
    q: Kahan,
    vtgv_recon: Kahan,
    // Per-GCD strata
    u_gcd: Vec<Kahan>,
    l_gcd: Vec<Kahan>,
    q_gcd: Vec<Kahan>,
    max_gcd: usize,
}

impl TaperAccum {
    fn identity(max_gcd: usize) -> Self {
        Self {
            u: Kahan::default(),
            l: Kahan::default(),
            q: Kahan::default(),
            vtgv_recon: Kahan::default(),
            u_gcd: vec![Kahan::default(); max_gcd + 1],
            l_gcd: vec![Kahan::default(); max_gcd + 1],
            q_gcd: vec![Kahan::default(); max_gcd + 1],
            max_gcd,
        }
    }

    fn merge(mut self, other: Self) -> Self {
        self.u.add(other.u.value());
        self.l.add(other.l.value());
        self.q.add(other.q.value());
        self.vtgv_recon.add(other.vtgv_recon.value());
        for d in 0..=self.max_gcd {
            self.u_gcd[d].add(other.u_gcd[d].value());
            self.l_gcd[d].add(other.l_gcd[d].value());
            self.q_gcd[d].add(other.q_gcd[d].value());
        }
        self
    }
}

// ═══════════════════════════════════════════════
// FINALIZATION
// ═══════════════════════════════════════════════

/// Compute all derived taper metrics after accumulation is complete.
///
/// Delegates to `finalize_taper_metrics_with_matrix` with no in-memory matrix
/// (recomputes Gram entries from scratch via `gram_entry_f64`).
pub fn finalize_taper_metrics(decomp: &mut Decomp) {
    finalize_taper_metrics_with_matrix(decomp, None);
}

/// Compute all derived taper metrics, optionally using an in-memory Gram matrix.
///
/// When `gram_matrix` is Some, Gram entries are read from the dense N×N array
/// instead of being recomputed via `gram_entry_f64`. This is critical for
/// GPU runs where the 24 GB matrix is already in host memory — it reduces
/// the O(active²) loop from ~90 minutes to ~10 seconds for N=55,440.
///
/// We recompute U/L/Q from scratch here to ensure the identity
///   vᵀGv = U - 2L/lnN + Q/ln²N
/// holds exactly. The taper expansion arises from:
///   v_k = -μ(k)·(1 - ln(k)/ln(N))
///   v_j · v_k = μ(j)μ(k)·(1 - lnj/lnN)·(1 - lnk/lnN)
///             = μμ[1 - (lnj+lnk)/lnN + lnj·lnk/ln²N]
///
/// Uses the full k=1..N Lean-aligned basis.
///
/// The O(active²) double loop is parallelized with rayon fold+reduce.
pub fn finalize_taper_metrics_with_matrix(decomp: &mut Decomp, gram_matrix: Option<&[f64]>) {
    let n = decomp.n;
    let dim = n;  // k=1..N (Lean-aligned)
    let ln_n = (n as f64).ln();
    let ln2_n = ln_n * ln_n;
    let vtgv = decomp.total.value();
    let max_gcd = decomp.max_gcd;

    let mu = cathedral_utils::arith::mobius_table(n);
    let weights = cathedral_utils::mertens::witness_vector_full(n, &mu);

    // Collect active (j_idx, j, v_j) pairs for k=1..N
    let active: Vec<(usize, usize, f64)> = (0..dim)
        .filter(|&i| weights[i].abs() > 1e-30)
        .map(|i| (i, i + 1, weights[i]))  // (j_idx=i, j=i+1, v_j)
        .collect();

    let n_active = active.len();
    let use_matrix = gram_matrix.is_some();
    eprintln!("  Computing per-GCD taper strata ({n_active} active, {})...",
        if use_matrix { "in-memory matrix" } else { "gram_entry_f64" });
    let t0 = std::time::Instant::now();

    // ═══ PARALLEL O(active²) taper + vtgv_recon + per-GCD strata ═══
    let result = active
        .par_iter()
        .fold(
            || TaperAccum::identity(max_gcd),
            |mut acc, &(j_idx, j, v_j)| {
                let mu_j = mu[j] as f64;
                let ln_j = (j as f64).ln();

                for &(k_idx, k, v_k) in &active {
                    let mu_k = mu[k] as f64;
                    let ln_k = (k as f64).ln();

                    // THE KEY OPTIMIZATION: read from in-memory matrix if available
                    let g = match gram_matrix {
                        Some(mat) => mat[j_idx * dim + k_idx],
                        None => cathedral_utils::gram::gram_entry_f64(j, k),
                    };

                    // Independent vᵀGv reconstruction
                    acc.vtgv_recon.add(v_j * g * v_k);

                    // Taper components: raw μμG sums
                    let mm_g = mu_j * mu_k * g;
                    acc.u.add(mm_g);
                    acc.l.add(mm_g * ln_j);
                    acc.q.add(mm_g * ln_j * ln_k);

                    // Per-GCD strata
                    let d = cathedral_utils::arith::gcd(j, k);
                    if d <= max_gcd {
                        acc.u_gcd[d].add(mm_g);
                        acc.l_gcd[d].add(mm_g * ln_j);
                        acc.q_gcd[d].add(mm_g * ln_j * ln_k);
                    }
                }
                acc
            },
        )
        .reduce(|| TaperAccum::identity(max_gcd), TaperAccum::merge);

    let elapsed = t0.elapsed().as_secs_f64();
    eprintln!("  ✓ Per-GCD taper strata: {elapsed:.1}s ({} pairs)", n_active as u64 * n_active as u64);

    // Store the recomputed values
    decomp.taper.u_sum = result.u;
    decomp.taper.l_sum = result.l;
    decomp.taper.q_sum = result.q;
    decomp.taper.vtgv_recon = result.vtgv_recon.value();

    // Store per-GCD strata
    for d in 0..=max_gcd {
        decomp.taper.u_by_gcd[d] = result.u_gcd[d];
        decomp.taper.l_by_gcd[d] = result.l_gcd[d];
        decomp.taper.q_by_gcd[d] = result.q_gcd[d];
    }

    let u = result.u.value();
    let l = result.l.value();
    let q = result.q.value();

    // R₂ = U - 2L/lnN  (the leading two-term partial remainder)
    decomp.taper.r2 = u - 2.0 * l / ln_n;
    decomp.taper.r2_minus_1 = decomp.taper.r2 - 1.0;
    decomp.taper.r2_times_ln = decomp.taper.r2_minus_1 * ln_n;
    decomp.taper.q_over_ln2 = q / ln2_n;
    decomp.taper.c_recon = (1.0 - vtgv) * ln_n;

    // PNT sub-sums: S₁ = Σ μ(k)/k, S₂ = Σ μ(k)ln(k)/k, S₃ = Σ μ(k)ln²(k)/k
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
}

// ═══════════════════════════════════════════════
// DISPLAY
// ═══════════════════════════════════════════════

/// Print taper cancellation summary to stderr.
pub fn print_taper_summary(d: &Decomp) {
    let t = &d.taper;
    let ln_n = (d.n as f64).ln();
    eprintln!();
    eprintln!("  ┌─────────────────────────────────────────────────┐");
    eprintln!("  │  §5 TAPER CANCELLATION (N={:>6})                │", d.n);
    eprintln!("  ├─────────────────────────────────────────────────┤");
    eprintln!("  │  U(N)           = {:>16.10}                │", t.u_sum.value());
    eprintln!("  │  L(N)           = {:>16.10}                │", t.l_sum.value());
    eprintln!("  │  Q(N)           = {:>16.10}                │", t.q_sum.value());
    eprintln!("  │  R₂ = U-2L/lnN  = {:>16.10}                │", t.r2);
    eprintln!("  │  R₂ - 1         = {:>16.10}                │", t.r2_minus_1);
    eprintln!("  │  (R₂-1)·lnN     = {:>16.10}  ← const?     │", t.r2_times_ln);
    eprintln!("  │  Q/ln²N         = {:>16.10}                │", t.q_over_ln2);
    eprintln!("  │  C_recon         = {:>16.10}  ← ≈2.87?     │", t.c_recon);
    eprintln!("  ├─────────────────────────────────────────────────┤");
    eprintln!("  │  PNT SUB-SUMS                                  │");
    eprintln!("  │  S₁ = Σμ/k      = {:>16.10}  → 0           │", t.s1);
    eprintln!("  │  S₂ = Σμlnk/k   = {:>16.10}  → -1          │", t.s2);
    eprintln!("  │  S₃ = Σμln²k/k  = {:>16.10}  → -2γ         │", t.s3);
    eprintln!("  │  M(N)           = {:>16.0}                │", t.mertens);
    eprintln!("  │  M(N)/√N        = {:>16.10}                │", t.mertens_over_sqrt);
    eprintln!("  ├─────────────────────────────────────────────────┤");
    eprintln!("  │  CROSS-CHECK                                   │");
    let recon = t.u_sum.value() - 2.0/ln_n * t.l_sum.value() + t.q_sum.value()/(ln_n*ln_n);
    let vtgv = d.total.value();
    eprintln!("  │  vᵀGv (runner)   = {:>16.10}               │", vtgv);
    eprintln!("  │  vᵀGv (recon)    = {:>16.10}               │", t.vtgv_recon);
    eprintln!("  │  U-2L/lnN+Q/ln²N = {:>16.10}               │", recon);
    eprintln!("  │  Δ runner↔recon  = {:>16.2e}               │", (t.vtgv_recon - vtgv).abs());
    eprintln!("  │  Δ runner↔taper  = {:>16.2e}               │", (recon - vtgv).abs());
    eprintln!("  └─────────────────────────────────────────────────┘");

    // GCD-stratified taper with per-stratum R₂
    eprintln!("  ┌───────────────────────────────────────────────────────────────────────────┐");
    eprintln!("  │  GCD-STRATIFIED TAPER DECOMPOSITION                                      │");
    eprintln!("  │  gcd   U_d             L_d             Q_d             R₂_d              │");
    eprintln!("  ├───────────────────────────────────────────────────────────────────────────┤");
    for d_val in 1..=d.max_gcd.min(30) {
        let u_d = d.taper.u_by_gcd[d_val].value();
        let l_d = d.taper.l_by_gcd[d_val].value();
        let q_d = d.taper.q_by_gcd[d_val].value();
        if u_d.abs() > 1e-15 || l_d.abs() > 1e-15 {
            let r2_d = u_d - 2.0 * l_d / ln_n;
            eprintln!("  │  {:>3}  {:>14.8}  {:>14.8}  {:>14.8}  {:>14.8}  │",
                d_val, u_d, l_d, q_d, r2_d);
        }
    }
    // Show sum and verify it matches totals
    let u_sum_gcd: f64 = (1..=d.max_gcd).map(|i| d.taper.u_by_gcd[i].value()).sum();
    let l_sum_gcd: f64 = (1..=d.max_gcd).map(|i| d.taper.l_by_gcd[i].value()).sum();
    let q_sum_gcd: f64 = (1..=d.max_gcd).map(|i| d.taper.q_by_gcd[i].value()).sum();
    let r2_sum = u_sum_gcd - 2.0 * l_sum_gcd / ln_n;
    eprintln!("  ├───────────────────────────────────────────────────────────────────────────┤");
    eprintln!("  │  SUM  {:>14.8}  {:>14.8}  {:>14.8}  {:>14.8}  │",
        u_sum_gcd, l_sum_gcd, q_sum_gcd, r2_sum);
    eprintln!("  │  Δ vs total: U={:.2e}  L={:.2e}  Q={:.2e}                      │",
        (u_sum_gcd - t.u_sum.value()).abs(),
        (l_sum_gcd - t.l_sum.value()).abs(),
        (q_sum_gcd - t.q_sum.value()).abs());
    eprintln!("  └───────────────────────────────────────────────────────────────────────────┘");
}
