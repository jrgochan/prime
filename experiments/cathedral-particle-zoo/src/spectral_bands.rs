//! Spectral Band Analysis — ω-class Eigenvector Participation
//!
//! Tests Scenario B: do Gram matrix eigenvectors naturally localize
//! by ω-class (number of prime factors)?
//!
//! If yes → natural spectral bands exist → band median ratios
//! are candidates for SM mass ratios (m_μ/m_e = 206.77).
//!
//! If no → eigenvectors are delocalized → Scenario B is dead.

use cathedral_utils::arith;
use rayon::prelude::*;

/// Per-band statistics.
#[derive(Debug, Clone, serde::Serialize)]
pub struct BandStats {
    pub omega: u32,
    pub count: usize,
    pub eigenvalue_median: f64,
    pub eigenvalue_mean: f64,
    pub eigenvalue_std: f64,
    pub energy_weighted_center: f64,
    pub mean_purity: f64, // Average max-participation in this band
}

/// Per-eigenvalue participation data.
#[derive(Debug, Clone, serde::Serialize)]
pub struct EigenParticipation {
    pub index: usize,
    pub eigenvalue: f64,
    pub dominant_omega: u32,
    pub purity: f64,             // max P(ω,k) — how "clean" the assignment is
    pub participation: Vec<f64>, // P(ω,k) for ω = 0, 1, 2, 3, 4+
}

/// Complete spectral band analysis result.
#[derive(Debug, Clone, serde::Serialize)]
pub struct SpectralBandAnalysis {
    pub n: usize,
    pub dim: usize,
    pub n_eigenvalues: usize,
    pub n_eigenvectors: usize,

    /// Per-eigenvalue participation data
    pub participations: Vec<EigenParticipation>,

    /// Per-band statistics
    pub bands: Vec<BandStats>,

    /// Key mass ratios (the test of Scenario B)
    pub r21: f64, // Band2 median / Band1 median → m_μ/m_e ?
    pub r31: f64, // Band3 median / Band1 median → m_τ/m_e ?
    pub r32: f64, // Band3 median / Band2 median → m_τ/m_μ ?

    /// SM comparison
    pub sm_r21: f64, // 206.768
    pub sm_r31: f64, // 3477.2
    pub sm_r32: f64, // 16.82

    /// Global localization metrics
    pub mean_purity: f64, // Average of max P(ω,k) across all k
    pub localization_fraction: f64, // Fraction of eigenvectors with purity > 0.5
    pub ipr_mean: f64,              // Mean inverse participation ratio

    /// Convergence data (for multi-N comparison)
    pub eigenvectors_localized: bool,
}

impl SpectralBandAnalysis {
    /// Compute spectral band analysis from eigenvalues and eigenvectors.
    ///
    /// `eigenvalues`: sorted ascending, length K
    /// `eigenvectors`: eigenvectors[k] = k-th eigenvector (length dim)
    /// `n`: the N value (for ω-class computation)
    ///
    /// Uses Rayon for parallel participation ratio computation.
    pub fn analyze(eigenvalues: &[f64], eigenvectors: &[Vec<f64>], n: usize) -> Self {
        let dim = if eigenvectors.is_empty() {
            0
        } else {
            eigenvectors[0].len()
        };
        let k = eigenvalues.len();

        // Build ω table: ω(j) for j = 1..N-1 (indices in the Gram matrix)
        let omega_table = arith::small_omega_table(n);

        // Index sets by ω-class (precompute for efficiency)
        // The Gram matrix indices are 1..N-1, so omega_table[j] for j in 1..dim+1
        let max_omega = 4u32; // Bucket ω≥4 together
        let omega_indices: Vec<Vec<usize>> = (0..=max_omega as usize)
            .map(|w| {
                (0..dim)
                    .filter(|&idx| {
                        let j = idx + 1; // Gram matrix index (1-based)
                        if j >= omega_table.len() {
                            return false;
                        }
                        let oj = omega_table[j].min(max_omega);
                        oj as usize == w
                    })
                    .collect()
            })
            .collect();

        // Log index set sizes
        eprintln!("    [Bands] ω-class index sizes:");
        for (w, indices) in omega_indices.iter().enumerate() {
            eprintln!(
                "      ω={}: {} indices ({:.1}%)",
                w,
                indices.len(),
                100.0 * indices.len() as f64 / dim as f64
            );
        }

        // Compute participation ratios in parallel across eigenvectors
        let participations: Vec<EigenParticipation> = (0..k)
            .into_par_iter()
            .map(|ki| {
                let v = &eigenvectors[ki];
                let lambda = eigenvalues[ki];

                // Compute |v_k(j)|² for each ω-class
                let mut p = vec![0.0f64; max_omega as usize + 1];

                for (w, indices) in omega_indices.iter().enumerate() {
                    let weight: f64 = indices.iter().map(|&idx| v[idx] * v[idx]).sum();
                    p[w] = weight;
                }

                // Normalize (should sum to ~1 if eigenvector is unit-norm)
                let total: f64 = p.iter().sum();
                if total > 1e-30 {
                    for x in &mut p {
                        *x /= total;
                    }
                }

                // Find dominant class
                let (dominant_idx, &purity) = p
                    .iter()
                    .enumerate()
                    .max_by(|a, b| a.1.partial_cmp(b.1).unwrap())
                    .unwrap();

                EigenParticipation {
                    index: ki,
                    eigenvalue: lambda,
                    dominant_omega: dominant_idx as u32,
                    purity,
                    participation: p,
                }
            })
            .collect();

        // Compute Inverse Participation Ratio (IPR) for localization
        let ipr_mean: f64 = participations
            .par_iter()
            .map(|ep| {
                let ipr: f64 = ep.participation.iter().map(|p| p * p).sum();
                ipr
            })
            .sum::<f64>()
            / k as f64;

        // Global localization metrics
        let mean_purity = participations.iter().map(|ep| ep.purity).sum::<f64>() / k as f64;

        let localization_fraction =
            participations.iter().filter(|ep| ep.purity > 0.5).count() as f64 / k as f64;

        // Band statistics
        let bands: Vec<BandStats> = (1..=max_omega)
            .map(|w| {
                let mut band_eigenvalues: Vec<f64> = participations
                    .iter()
                    .filter(|ep| ep.dominant_omega == w)
                    .map(|ep| ep.eigenvalue)
                    .collect();

                if band_eigenvalues.is_empty() {
                    return BandStats {
                        omega: w,
                        count: 0,
                        eigenvalue_median: 0.0,
                        eigenvalue_mean: 0.0,
                        eigenvalue_std: 0.0,
                        energy_weighted_center: 0.0,
                        mean_purity: 0.0,
                    };
                }

                band_eigenvalues.sort_by(|a, b| a.partial_cmp(b).unwrap());
                let n_band = band_eigenvalues.len();
                let median = band_eigenvalues[n_band / 2];
                let mean = band_eigenvalues.iter().sum::<f64>() / n_band as f64;
                let std = (band_eigenvalues
                    .iter()
                    .map(|v| (v - mean).powi(2))
                    .sum::<f64>()
                    / n_band as f64)
                    .sqrt();

                // Energy-weighted center: Σ λ_k · P(w,k) / Σ P(w,k)
                let (num, den): (f64, f64) = participations
                    .iter()
                    .map(|ep| {
                        let pw = ep.participation[w as usize];
                        (ep.eigenvalue * pw, pw)
                    })
                    .fold((0.0, 0.0), |(a, b), (x, y)| (a + x, b + y));
                let center = if den > 1e-30 { num / den } else { 0.0 };

                let band_purity: f64 = participations
                    .iter()
                    .filter(|ep| ep.dominant_omega == w)
                    .map(|ep| ep.purity)
                    .sum::<f64>()
                    / n_band as f64;

                BandStats {
                    omega: w,
                    count: n_band,
                    eigenvalue_median: median,
                    eigenvalue_mean: mean,
                    eigenvalue_std: std,
                    energy_weighted_center: center,
                    mean_purity: band_purity,
                }
            })
            .collect();

        // Compute mass ratios
        let m1 = bands
            .iter()
            .find(|b| b.omega == 1)
            .map(|b| b.eigenvalue_median)
            .unwrap_or(0.0);
        let m2 = bands
            .iter()
            .find(|b| b.omega == 2)
            .map(|b| b.eigenvalue_median)
            .unwrap_or(0.0);
        let m3 = bands
            .iter()
            .find(|b| b.omega == 3)
            .map(|b| b.eigenvalue_median)
            .unwrap_or(0.0);

        let r21 = if m1.abs() > 1e-30 { m2 / m1 } else { 0.0 };
        let r31 = if m1.abs() > 1e-30 { m3 / m1 } else { 0.0 };
        let r32 = if m2.abs() > 1e-30 { m3 / m2 } else { 0.0 };

        let eigenvectors_localized = mean_purity > 0.4 && localization_fraction > 0.3;

        SpectralBandAnalysis {
            n,
            dim,
            n_eigenvalues: k,
            n_eigenvectors: eigenvectors.len(),
            participations,
            bands,
            r21,
            r31,
            r32,
            sm_r21: 206.768,
            sm_r31: 3477.2,
            sm_r32: 16.82,
            mean_purity,
            localization_fraction,
            ipr_mean,
            eigenvectors_localized,
        }
    }

    /// Display the analysis results.
    pub fn display(&self) {
        use cathedral_utils::fmt as cfmt;

        cfmt::section("SPECTRAL BAND ANALYSIS (Scenario B Test)");

        println!();
        println!("  ┌─────────────────────────────────────────────────────────────────┐");
        println!("  │ EIGENVECTOR LOCALIZATION                                        │");
        println!("  ├─────────────────────────────────────────────────────────────────┤");
        println!(
            "  │ Eigenvalues analyzed: {:>6}                                    │",
            self.n_eigenvalues
        );
        println!(
            "  │ Mean purity:         {:.6}  (1.0 = perfect localization)    │",
            self.mean_purity
        );
        println!(
            "  │ Localized (>0.5):    {:.1}%                                    │",
            100.0 * self.localization_fraction
        );
        println!(
            "  │ Mean IPR:            {:.6}  (1/n_classes = delocalized)     │",
            self.ipr_mean
        );
        let verdict = if self.eigenvectors_localized {
            format!("{}✓ LOCALIZED — bands exist!{}", cfmt::GREEN, cfmt::RESET)
        } else {
            format!(
                "{}✗ DELOCALIZED — Scenario B falsified{}",
                cfmt::RED,
                cfmt::RESET
            )
        };
        println!("  │ Verdict: {}         │", verdict);
        println!("  └─────────────────────────────────────────────────────────────────┘");

        println!();
        println!("  ┌─────┬────────┬────────────────┬────────────────┬──────────┬─────────┐");
        println!("  │  ω  │ count  │     median     │   E-w center   │  std dev │  purity │");
        println!("  ├─────┼────────┼────────────────┼────────────────┼──────────┼─────────┤");
        for b in &self.bands {
            if b.count > 0 {
                println!(
                    "  │  {}  │ {:>6} │ {:>14.8} │ {:>14.8} │ {:>8.6} │ {:>7.4} │",
                    b.omega,
                    b.count,
                    b.eigenvalue_median,
                    b.energy_weighted_center,
                    b.eigenvalue_std,
                    b.mean_purity
                );
            }
        }
        println!("  └─────┴────────┴────────────────┴────────────────┴──────────┴─────────┘");

        println!();
        cfmt::section("MASS RATIO TEST");
        println!("  ┌──────────────────────────────────────────────────────────────────┐");
        println!("  │ Ratio     │ Measured       │ SM Target      │ Match?             │");
        println!("  ├──────────────────────────────────────────────────────────────────┤");
        let check = |measured: f64, target: f64| -> &'static str {
            let pct = ((measured / target) - 1.0).abs() * 100.0;
            if pct < 1.0 {
                "✓ <1%"
            } else if pct < 10.0 {
                "~ <10%"
            } else if pct < 50.0 {
                "≈ rough"
            } else {
                "✗ NO"
            }
        };
        println!(
            "  │ R₂₁=M₂/M₁│ {:>14.6} │ {:>14.6} │ {:>18} │",
            self.r21,
            self.sm_r21,
            check(self.r21, self.sm_r21)
        );
        println!(
            "  │ R₃₁=M₃/M₁│ {:>14.6} │ {:>14.6} │ {:>18} │",
            self.r31,
            self.sm_r31,
            check(self.r31, self.sm_r31)
        );
        println!(
            "  │ R₃₂=M₃/M₂│ {:>14.6} │ {:>14.6} │ {:>18} │",
            self.r32,
            self.sm_r32,
            check(self.r32, self.sm_r32)
        );
        println!("  └──────────────────────────────────────────────────────────────────┘");

        if self.r21.abs() > 1e-30 {
            let pct = ((self.r21 / self.sm_r21) - 1.0).abs() * 100.0;
            if pct < 1.0 {
                println!();
                println!(
                    "  {}{}  ██████████████████████████████████████████████████{}",
                    cfmt::BOLD,
                    cfmt::GREEN,
                    cfmt::RESET
                );
                println!(
                    "  {}{}  ██  R₂₁ MATCHES m_μ/m_e TO <1%  ██{}",
                    cfmt::BOLD,
                    cfmt::GREEN,
                    cfmt::RESET
                );
                println!(
                    "  {}{}  ██  CALL STOCKHOLM                ██{}",
                    cfmt::BOLD,
                    cfmt::GREEN,
                    cfmt::RESET
                );
                println!(
                    "  {}{}  ██████████████████████████████████████████████████{}",
                    cfmt::BOLD,
                    cfmt::GREEN,
                    cfmt::RESET
                );
            }
        }
    }
}

/// Write spectral band TSV output.
pub fn write_bands_tsv(analysis: &SpectralBandAnalysis, dir: &str) -> std::io::Result<()> {
    use std::io::Write;
    std::fs::create_dir_all(dir)?;

    // Eigenvalue participation TSV
    let p = format!("{dir}/eigenvalues_N{}.tsv", analysis.n);
    let mut f = std::fs::File::create(&p)?;
    writeln!(
        f,
        "k\teigenvalue\tdominant_omega\tpurity\tP_0\tP_1\tP_2\tP_3\tP_4"
    )?;
    for ep in &analysis.participations {
        write!(
            f,
            "{}\t{:.15e}\t{}\t{:.8}",
            ep.index, ep.eigenvalue, ep.dominant_omega, ep.purity
        )?;
        for p in &ep.participation {
            write!(f, "\t{:.8}", p)?;
        }
        writeln!(f)?;
    }
    eprintln!("  ✓ Eigenvalues → {p}");

    // Band statistics TSV
    let p = format!("{dir}/bands_N{}.tsv", analysis.n);
    let mut f = std::fs::File::create(&p)?;
    writeln!(f, "omega\tcount\tmedian\tmean\tstd\tenergy_center\tpurity")?;
    for b in &analysis.bands {
        writeln!(
            f,
            "{}\t{}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.8}",
            b.omega,
            b.count,
            b.eigenvalue_median,
            b.eigenvalue_mean,
            b.eigenvalue_std,
            b.energy_weighted_center,
            b.mean_purity
        )?;
    }
    eprintln!("  ✓ Bands → {p}");

    // Mass ratios JSON
    let p = format!("{dir}/mass_ratios_N{}.json", analysis.n);
    let json = serde_json::json!({
        "N": analysis.n,
        "dim": analysis.dim,
        "n_eigenvalues": analysis.n_eigenvalues,
        "eigenvectors_localized": analysis.eigenvectors_localized,
        "mean_purity": analysis.mean_purity,
        "localization_fraction": analysis.localization_fraction,
        "ipr_mean": analysis.ipr_mean,
        "R21_measured": analysis.r21,
        "R31_measured": analysis.r31,
        "R32_measured": analysis.r32,
        "SM_R21_target": analysis.sm_r21,
        "SM_R31_target": analysis.sm_r31,
        "SM_R32_target": analysis.sm_r32,
        "R21_deviation_pct": ((analysis.r21 / analysis.sm_r21) - 1.0).abs() * 100.0,
        "R31_deviation_pct": ((analysis.r31 / analysis.sm_r31) - 1.0).abs() * 100.0,
        "R32_deviation_pct": ((analysis.r32 / analysis.sm_r32) - 1.0).abs() * 100.0,
        "bands": analysis.bands,
    });
    let json_str = serde_json::to_string_pretty(&json).unwrap();
    std::fs::write(&p, json_str)?;
    eprintln!("  ✓ Mass ratios → {p}");

    Ok(())
}
