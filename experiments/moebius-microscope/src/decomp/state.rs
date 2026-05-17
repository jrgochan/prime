//! Core state for the Möbius Cancellation Microscope.
//!
//! The `Decomp` struct holds all accumulated metrics from a microscope run.
//! Sub-structs group related fields for clarity.

use cathedral_utils::arith::{self, Kahan};

use super::physics::PhysicsMetrics;
use super::taper::TaperMetrics;

// ═══════════════════════════════════════════════
// TRACE POINT
// ═══════════════════════════════════════════════

/// A single point in the running convergence trace.
pub struct TracePoint {
    pub j: usize,
    pub running_sum: f64,
    pub running_abs: f64,
}

// ═══════════════════════════════════════════════
// GRAM BOUND METRICS
// ═══════════════════════════════════════════════

/// Metrics derived from the Gram form vᵀGv.
#[derive(Default)]
pub struct GramMetrics {
    pub btv: f64,          // bᵀv
    pub btv_sq: f64,       // (bᵀv)²
    pub vtcv: f64,         // vᵀCv = vᵀGv - (bᵀv)²
    pub d2n: f64,          // d²_N = 1 - 2bᵀv + vᵀGv
    pub ratio: f64,        // (bᵀv)²/vᵀGv
    pub gap: f64,          // 1 - vᵀGv
    pub gap_times_ln: f64, // (1-vᵀGv) * ln(N)
}

// ═══════════════════════════════════════════════
// DECOMPOSITION STATE
// ═══════════════════════════════════════════════

/// Full decomposition state for a single N.
pub struct Decomp {
    pub n: usize,
    pub dim: usize,
    pub precision: String,

    // §1: Diagonal / off-diagonal
    pub total: Kahan,
    pub diagonal: Kahan,
    pub off_diagonal: Kahan,

    // §2: GCD decomposition
    pub gcd_buckets: Vec<Kahan>,
    pub max_gcd: usize,
    pub robin_sigma: Vec<f64>,

    // §3: Rotor channels (mod-8 characters)
    pub channels: [Kahan; 4],

    // §4: Vaughan type decomposition
    pub type_i: Kahan,
    pub type_ii: Kahan,
    pub type_iii: Kahan,

    // §5: Liouville parity
    pub ee: Kahan,
    pub eo: Kahan,
    pub oe: Kahan,
    pub oo: Kahan,

    // §6: ω-class matrix
    pub omega_buckets: Vec<Vec<Kahan>>,
    pub max_omega: usize,

    // §7: Dyadic scale bands
    pub dyadic: Vec<Vec<Kahan>>,
    pub max_band: usize,

    // §8: Sign statistics
    pub n_pos: u64,
    pub n_neg: u64,
    pub sum_pos: Kahan,
    pub sum_neg: Kahan,

    // §9: Gram bound analysis
    pub gram: GramMetrics,

    // §10: Taper cancellation tracker
    pub taper: TaperMetrics,

    // §11-§16: Physics metadata (dark sector discoveries)
    pub physics: PhysicsMetrics,

    // Convergence trace
    pub trace: Vec<TracePoint>,
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
            n,
            dim: n, // Lean-aligned: k=1..N basis
            precision: precision.to_string(),
            total: Kahan::default(),
            diagonal: Kahan::default(),
            off_diagonal: Kahan::default(),
            gcd_buckets: vec![Kahan::default(); max_gcd + 1],
            max_gcd,
            robin_sigma,
            channels: [Kahan::default(); 4],
            type_i: Kahan::default(),
            type_ii: Kahan::default(),
            type_iii: Kahan::default(),
            ee: Kahan::default(),
            eo: Kahan::default(),
            oe: Kahan::default(),
            oo: Kahan::default(),
            omega_buckets: vec![vec![Kahan::default(); max_omega + 1]; max_omega + 1],
            max_omega,
            dyadic: vec![vec![Kahan::default(); max_band + 1]; max_band + 1],
            max_band,
            n_pos: 0,
            n_neg: 0,
            sum_pos: Kahan::default(),
            sum_neg: Kahan::default(),
            gram: GramMetrics::default(),
            taper: TaperMetrics::new(max_gcd),
            physics: PhysicsMetrics::default(),
            trace: Vec::new(),
        }
    }
}
