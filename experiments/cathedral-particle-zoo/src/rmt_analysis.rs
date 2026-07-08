//! RMT Spectral Analysis — Random Matrix Theory diagnostics
//!
//! Wraps cathedral-utils/spectral_stats for GUE/GOE/Poisson classification.

use cathedral_utils::spectral_stats;

/// RMT analysis results for a Gram matrix eigenspectrum.
#[derive(Debug, Clone)]
pub struct RmtAnalysis {
    pub n_eigenvalues: usize,
    pub lambda_min: f64,
    pub lambda_max: f64,
    pub spectral_range: f64,
    pub mean_ratio: f64,
    pub ensemble_name: &'static str,
    pub ensemble_distance: f64,
    pub beta_dyson: f64,
    pub ks_gue: f64,
    pub ks_goe: f64,
    pub ks_poisson: f64,
}

impl RmtAnalysis {
    /// Run full RMT analysis on sorted eigenvalues.
    pub fn analyze(eigenvalues: &[f64]) -> Self {
        let n = eigenvalues.len();
        let lambda_min = eigenvalues[0];
        let lambda_max = eigenvalues[n - 1];

        // Spacing ratios (unfolding-independent)
        let ratios = spectral_stats::spacing_ratios(eigenvalues);
        let mean_ratio = if !ratios.is_empty() {
            ratios.iter().sum::<f64>() / ratios.len() as f64
        } else {
            0.0
        };

        let (ensemble_name, ensemble_distance) = spectral_stats::classify_ensemble(mean_ratio);
        let beta = spectral_stats::estimate_beta(mean_ratio);

        // Unfolded NNSD for KS tests
        let unfolded = spectral_stats::unfold_local(eigenvalues, 0.05);
        let spacings: Vec<f64> = unfolded
            .windows(2)
            .map(|w| (w[1] - w[0]).max(0.0))
            .filter(|&s| s > 1e-15)
            .collect();

        // Normalize spacings to mean 1
        let mean_s = if !spacings.is_empty() {
            spacings.iter().sum::<f64>() / spacings.len() as f64
        } else {
            1.0
        };
        let norm_spacings: Vec<f64> = spacings.iter().map(|s| s / mean_s).collect();

        let ks_gue = spectral_stats::ks_test(&norm_spacings, spectral_stats::cdf_gue);
        let ks_goe = spectral_stats::ks_test(&norm_spacings, spectral_stats::cdf_goe);
        let ks_poisson = spectral_stats::ks_test(&norm_spacings, spectral_stats::cdf_poisson);

        RmtAnalysis {
            n_eigenvalues: n,
            lambda_min,
            lambda_max,
            spectral_range: lambda_max - lambda_min,
            mean_ratio,
            ensemble_name,
            ensemble_distance,
            beta_dyson: beta,
            ks_gue,
            ks_goe,
            ks_poisson,
        }
    }

    /// Display RMT results.
    pub fn display(&self) {
        println!("  ┌─────────────────────────────────────────────────────────────────┐");
        println!("  │ UNIVERSALITY CLASS (Random Matrix Theory)                       │");
        println!("  ├─────────────────────────────────────────────────────────────────┤");
        println!(
            "  │ Eigenvalues: {}                                              │",
            self.n_eigenvalues
        );
        println!(
            "  │ λ_min (mass gap) = {:.8}                                   │",
            self.lambda_min
        );
        println!(
            "  │ λ_max            = {:.8}                                   │",
            self.lambda_max
        );
        println!(
            "  │ Range            = {:.8}                                   │",
            self.spectral_range
        );
        println!("  │                                                                 │");
        println!(
            "  │ ⟨r⟩ = {:.6} → {} (distance = {:.6})         │",
            self.mean_ratio, self.ensemble_name, self.ensemble_distance
        );
        println!(
            "  │ β_Dyson = {:.4}                                               │",
            self.beta_dyson
        );
        println!("  │                                                                 │");
        println!("  │ KS Tests:                                                       │");
        println!(
            "  │   D_GUE     = {:.6}                                          │",
            self.ks_gue
        );
        println!(
            "  │   D_GOE     = {:.6}                                          │",
            self.ks_goe
        );
        println!(
            "  │   D_Poisson = {:.6}                                          │",
            self.ks_poisson
        );
        let verdict = if self.ks_gue < self.ks_goe && self.ks_gue < self.ks_poisson {
            "✓ Montgomery-Dyson conjecture CONSISTENT"
        } else {
            "? Non-GUE behavior detected"
        };
        println!("  │   → {}              │", verdict);
        println!("  └─────────────────────────────────────────────────────────────────┘");
    }
}
