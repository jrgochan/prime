//! See-Saw Mechanism via Schur Complement — Gemini's Theoretical Upgrade #2
//!
//! The Schur complement C = G - bbᵀ is the arithmetic see-saw mechanism.
//! The massive Gram matrix G acts on the mean vector b to produce the
//! tiny vacuum energy d²_N = 1 - bᵀG⁻¹b.
//!
//! In physics: m_ν ≈ m_D² / M_R (Dirac mass² / right-handed mass)
//! In Cathedral: d²_N ≈ ‖b‖⁴ / λ_max(G) (mean norm⁴ / dominant eigenvalue)
//!
//! The neutrino mass sum is the vacuum energy:
//!   Σ m_νᵢ ∝ d²_N → 0 ⟺ RH

/// See-saw analysis results.
#[derive(Debug, Clone)]
pub struct SeeSawAnalysis {
    /// d²_N = 1 - bᵀG⁻¹b — the vacuum energy (neutrino mass sum analog)
    pub d2_n: f64,

    /// ‖b‖² — mean vector norm squared (Dirac mass² analog)
    pub b_norm_sq: f64,

    /// λ_max(G) — largest eigenvalue (right-handed mass analog)
    pub lambda_max: f64,

    /// λ_min(G) — smallest eigenvalue (mass gap)
    pub lambda_min: f64,

    /// See-saw prediction: d² ~ ‖b‖⁴/λ_max
    pub seesaw_prediction: f64,

    /// Ratio: actual d² / seesaw prediction
    pub seesaw_ratio: f64,

    /// Condition number κ = λ_max/λ_min
    pub condition_number: f64,
}

impl SeeSawAnalysis {
    /// Compute see-saw analysis from eigenvalues and mean vector.
    pub fn compute(eigenvalues: &[f64], b_vec: &[f64], d2: f64) -> Self {
        let lambda_min = eigenvalues.iter().cloned().fold(f64::INFINITY, f64::min);
        let lambda_max = eigenvalues
            .iter()
            .cloned()
            .fold(f64::NEG_INFINITY, f64::max);
        let b_norm_sq: f64 = b_vec.iter().map(|x| x * x).sum();

        // See-saw prediction: d² ~ ‖b‖⁴ / λ_max
        let seesaw_pred = b_norm_sq * b_norm_sq / lambda_max;
        let ratio = if seesaw_pred > 1e-30 {
            d2 / seesaw_pred
        } else {
            0.0
        };

        SeeSawAnalysis {
            d2_n: d2,
            b_norm_sq,
            lambda_max,
            lambda_min,
            seesaw_prediction: seesaw_pred,
            seesaw_ratio: ratio,
            condition_number: lambda_max / lambda_min,
        }
    }

    /// Display the see-saw analysis.
    pub fn display(&self) {
        println!("  ┌─────────────────────────────────────────────────────────────────┐");
        println!("  │ SEE-SAW MECHANISM (Schur Complement = Neutrino Mass)            │");
        println!("  ├─────────────────────────────────────────────────────────────────┤");
        println!(
            "  │ Vacuum energy d²_N = {:.10}  (= Σ m_νᵢ analog)       │",
            self.d2_n
        );
        println!(
            "  │ ‖b‖² (Dirac mass²)  = {:.6}                                 │",
            self.b_norm_sq
        );
        println!(
            "  │ λ_max (M_R)          = {:.6}                                 │",
            self.lambda_max
        );
        println!(
            "  │ λ_min (mass gap)     = {:.6}                                 │",
            self.lambda_min
        );
        println!(
            "  │ κ (condition #)       = {:.2}                                │",
            self.condition_number
        );
        println!("  │                                                                 │");
        println!(
            "  │ See-Saw: d² ~ ‖b‖⁴/λ_max = {:.10}                    │",
            self.seesaw_prediction
        );
        println!(
            "  │ Ratio: actual/predicted   = {:.6}                            │",
            self.seesaw_ratio
        );
        println!("  │                                                                 │");
        println!("  │ Physics: C = G - bbᵀ (Schur complement)                        │");
        println!("  │          d²_N = 1 - bᵀG⁻¹b (vacuum screening)                  │");
        println!("  │          Tiny d² from massive G = arithmetic see-saw!            │");
        println!("  └─────────────────────────────────────────────────────────────────┘");
    }
}
