//! ═══════════════════════════════════════════════════════════════════════════
//!  BD WEIGHTS AND RESIDUE CLASS ANALYSIS
//!
//!  Validates: CalcBounds.lean `bd_weights_log_taper`
//!  Physics:   Bartlett window / UV cutoff coefficients
//! ═══════════════════════════════════════════════════════════════════════════

/// Log-cutoff Möbius weights: v_k = -μ(k)·(1 - ln(k)/ln(N))
pub fn bd_weights(n: usize, mu: &[i8]) -> Vec<f64> {
    let log_n = (n as f64).ln();
    (1..n).map(|k| {
        if mu[k] == 0 { return 0.0; }
        let taper = 1.0 - (k as f64).ln() / log_n;
        if taper <= 0.0 { return 0.0; }
        -(mu[k] as f64) * taper
    }).collect()
}

/// Residue class statistics for the 8 classes mod 8
pub struct ResidueStats {
    pub n: usize,
    pub class_energy: [f64; 8],     // Σ v_k² for k ≡ r (mod 8)
    pub class_count: [usize; 8],    // # nonzero v_k in each class
    pub class_fraction: [f64; 8],   // class_energy / total_energy
    pub total_energy: f64,
}

pub fn residue_class_stats(n: usize, weights: &[f64]) -> ResidueStats {
    let mut class_energy = [0.0f64; 8];
    let mut class_count = [0usize; 8];

    for (i, &vk) in weights.iter().enumerate() {
        let k = i + 1;
        let r = k % 8;
        if vk != 0.0 {
            class_energy[r] += vk * vk;
            class_count[r] += 1;
        }
    }

    let total_energy: f64 = class_energy.iter().sum();
    let mut class_fraction = [0.0f64; 8];
    for r in 0..8 {
        class_fraction[r] = if total_energy > 0.0 {
            class_energy[r] / total_energy
        } else { 0.0 };
    }

    ResidueStats { n, class_energy, class_count, class_fraction, total_energy }
}
