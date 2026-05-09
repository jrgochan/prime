//! Multi-precision CG solvers for the Gram system Gv = b.
//!
//! Three precision tiers, all building on `cathedral_utils::dd::DD`:
//!
//! | Tier | Arithmetic | Digits | Speed | Use Case |
//! |------|-----------|--------|-------|----------|
//! | **f64** (existing) | Native f64 | ~15.6 | Fastest | Default, GPU-compatible |
//! | **DD CG** | Double-double (hi+lo) | ~31 | ~2-3× slower | Push past f64 floor |
//! | **Mixed** | f64 matvec + DD residual | ~23 | ~1.3× slower | Best precision/perf |
//! | **MPFR CG** | Arbitrary (rug::Float) | Unlimited | ~100× slower | Reference / certification |
//!
//! All three solvers implement the same Jacobi-preconditioned CG algorithm
//! as `agent::conjugate_gradient`, but with elevated internal precision.

pub mod dd_cg;
pub mod mixed_cg;
pub mod mpfr_cg;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PrecisionTier {
    /// Standard f64 CG (existing agent::conjugate_gradient)
    F64,
    /// Double-double: all inner products and updates in DD (~31 digits)
    DD,
    /// Mixed: f64 matvec + DD residual accumulation (iterative refinement)
    Mixed,
    /// Full MPFR CG at arbitrary bit precision
    Mpfr(u32),
}

impl std::fmt::Display for PrecisionTier {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            PrecisionTier::F64 => write!(f, "f64"),
            PrecisionTier::DD => write!(f, "DD (double-double, ~31 digits)"),
            PrecisionTier::Mixed => write!(f, "Mixed (f64 matvec + DD residual)"),
            PrecisionTier::Mpfr(bits) => write!(f, "MPFR ({bits}-bit)"),
        }
    }
}

/// Result from a precision-elevated CG solve.
#[derive(Debug, Clone)]
pub struct PrecisionCgResult {
    /// Optimal witness vector (always returned as f64)
    pub v_opt: Vec<f64>,
    /// d² at convergence
    pub d2: f64,
    /// vᵀGv at convergence
    pub vtgv: f64,
    /// bᵀv at convergence
    pub btv: f64,
    /// Final relative residual ||r||/||r₀||
    pub relative_residual: f64,
    /// Steps taken
    pub steps: usize,
    /// Whether the solver converged (vs stagnated/exhausted)
    pub converged: bool,
    /// Whether the solver stagnated at the precision floor
    pub stagnated: bool,
    /// Precision tier used
    pub tier: PrecisionTier,
    /// Wall time in seconds
    pub wall_time_s: f64,
}
