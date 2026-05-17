//! § Physics Metadata — Dark Sector Discoveries
//!
//! New decomposition channels discovered from the Cathedral/Physics folder:
//!
//! §11: Glass Bridge decomposition (vᵀRv + ¼(Σv)²)
//! §12: Dark Gram vᵀG⁽²⁾v (gcd⁴/(180j²k²) weighted)
//! §13: Coprime diagonal fraction
//! §14: Ward identity (row cancellation metric)
//! §15: Gauge decomposition (U(1)×SU(2)×SU(3) strata)
//! §16: S-duality ratio (positive vs dark energy)

use cathedral_utils::arith::{self, Kahan};

/// Physics metadata computed from the quadratic form decomposition.
#[derive(Default)]
pub struct PhysicsMetrics {
    // §11: Glass Bridge
    pub vt_rv: f64,         // vᵀRv (Ramanujan residual)
    pub rank1_term: f64,    // ¼(Σv)² (rank-1 noise)
    pub sum_v: f64,         // Σ_k v_k

    // §12: Dark Gram
    pub vt_dark_v: f64,     // vᵀG⁽²⁾v  (gcd⁴/(180j²k²) weighted)

    // §13: Coprime diagonal
    pub coprime_pairs: u64, // # of (j,k) with gcd=1
    pub total_pairs: u64,   // total # of active pairs
    pub coprime_energy: f64,// Σ_{gcd(j,k)=1} v_j·G·v_k
    pub non_coprime_energy: f64,

    // §14: Ward identity — row cancellation
    pub max_row_residual: f64,    // max_j |Σ_k G(j,k)·v_k|
    pub mean_row_residual: f64,   // mean |Σ_k G(j,k)·v_k|
    pub ward_violation: f64,      // Σ_j (Σ_k G(j,k)·v_k)²

    // §15: Gauge decomposition
    pub gauge_u1: f64,      // Σ where gcd(j,k) is odd
    pub gauge_su2: f64,     // Σ where 2|gcd(j,k) but not 4
    pub gauge_su3: f64,     // Σ where 3|gcd(j,k)
    pub gauge_other: f64,   // everything else

    // §16: S-duality comparison
    pub positive_energy: f64, // vᵀRv contribution from positive terms
    pub dark_energy: f64,     // vᵀG⁽²⁾v contribution
    pub comparison_ratio: f64,// R(j,k) / G⁽²⁾(j,k) average ratio
}

/// Per-row accumulator for physics channels (added alongside RowResult).
pub struct PhysicsRow {
    pub ramanujan_sum: Kahan,    // Σ_k v_j · R(j,k) · v_k  for this row
    pub dark_sum: Kahan,         // Σ_k v_j · G²(j,k) · v_k  for this row
    pub row_ward: Kahan,         // Σ_k G(j,k) · v_k  (Ward residual)
    pub coprime_sum: Kahan,      // Σ_{gcd=1} v_j · G(j,k) · v_k
    pub coprime_count: u64,
    pub total_count: u64,
    pub gauge_u1: Kahan,
    pub gauge_su2: Kahan,
    pub gauge_su3: Kahan,
    pub gauge_other: Kahan,
    pub positive_r: Kahan,       // positive Ramanujan terms
}

impl PhysicsRow {
    pub fn new() -> Self {
        Self {
            ramanujan_sum: Kahan::default(),
            dark_sum: Kahan::default(),
            row_ward: Kahan::default(),
            coprime_sum: Kahan::default(),
            coprime_count: 0,
            total_count: 0,
            gauge_u1: Kahan::default(),
            gauge_su2: Kahan::default(),
            gauge_su3: Kahan::default(),
            gauge_other: Kahan::default(),
            positive_r: Kahan::default(),
        }
    }
}

/// Classify a (j,k) term into the physics channels.
///
/// `term` = v_j · G(j,k) · v_k (the full weighted Gram contribution)
/// `v_j`, `v_k` = weight vector values (μ(j)/logN, μ(k)/logN)
/// `g_jk` = raw Gram entry G(j,k)
#[inline]
pub fn classify_physics(
    pr: &mut PhysicsRow,
    j: usize,
    k: usize,
    term: f64,
    v_j: f64,
    v_k: f64,
    g_jk: f64,
) {
    let d = arith::gcd(j, k);
    let jf = j as f64;
    let kf = k as f64;
    let df = d as f64;

    // §11: Glass Bridge — decompose into Ramanujan + rank-1
    // R(j,k) = gcd(j,k)²/(12jk)
    let r_jk = df * df / (12.0 * jf * kf);
    let ram_term = v_j * r_jk * v_k;
    pr.ramanujan_sum.add(ram_term);

    // §12: Dark Gram — G⁽²⁾(j,k) = gcd(j,k)⁴/(180·j²·k²)
    let dark_jk = df.powi(4) / (180.0 * jf * jf * kf * kf);
    let dark_term = v_j * dark_jk * v_k;
    pr.dark_sum.add(dark_term);

    // §13: Coprime diagonal
    pr.total_count += 1;
    if d == 1 {
        pr.coprime_count += 1;
        pr.coprime_sum.add(term);
    }

    // §14: Ward identity (row cancellation)
    pr.row_ward.add(g_jk * v_k);

    // §15: Gauge decomposition by gcd structure
    if d % 2 != 0 {
        // odd gcd → U(1) sector
        pr.gauge_u1.add(term);
    } else if d % 4 != 0 {
        // 2|gcd but not 4 → SU(2) sector
        pr.gauge_su2.add(term);
    } else if d % 3 == 0 {
        // 3|gcd → SU(3) sector
        pr.gauge_su3.add(term);
    } else {
        pr.gauge_other.add(term);
    }

    // §16: Track positive Ramanujan energy
    if ram_term > 0.0 {
        pr.positive_r.add(ram_term);
    }
}

/// Merge a PhysicsRow into the global PhysicsMetrics.
pub fn merge_physics_row(pm: &mut PhysicsMetrics, pr: &PhysicsRow, v_j: f64) {
    pm.vt_rv += pr.ramanujan_sum.value();
    pm.vt_dark_v += pr.dark_sum.value();

    pm.coprime_pairs += pr.coprime_count;
    pm.total_pairs += pr.total_count;
    pm.coprime_energy += pr.coprime_sum.value();

    let row_ward = pr.row_ward.value();
    let ward_resid = (row_ward * v_j).abs(); // v_j · Σ_k G·v_k
    pm.ward_violation += row_ward * row_ward;
    if ward_resid > pm.max_row_residual {
        pm.max_row_residual = ward_resid;
    }
    // We'll compute mean after all rows

    pm.gauge_u1 += pr.gauge_u1.value();
    pm.gauge_su2 += pr.gauge_su2.value();
    pm.gauge_su3 += pr.gauge_su3.value();
    pm.gauge_other += pr.gauge_other.value();

    pm.positive_energy += pr.positive_r.value();
    pm.dark_energy += pr.dark_sum.value();
}

/// Finalize physics metrics after all rows have been merged.
pub fn finalize_physics(pm: &mut PhysicsMetrics, n_active: usize, sum_v: f64) {
    pm.sum_v = sum_v;
    pm.rank1_term = 0.25 * sum_v * sum_v;

    if n_active > 0 {
        pm.mean_row_residual = pm.ward_violation.sqrt() / n_active as f64;
    }

    pm.non_coprime_energy = pm.vt_rv + pm.rank1_term - pm.coprime_energy;

    if pm.dark_energy.abs() > 1e-30 {
        pm.comparison_ratio = pm.positive_energy / pm.dark_energy;
    }
}
