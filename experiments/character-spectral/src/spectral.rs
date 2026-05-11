//! Spectral analysis: DOS, level spacing (with GUE/GOE/GSE discrimination),
//! Van Hove singularity fit, and cross-channel correlations.

use std::f64::consts::PI;

// ═══════════════════════════════════════════════
// DENSITY OF STATES
// ═══════════════════════════════════════════════

pub struct DosResult {
    pub bin_centers: Vec<f64>,
    pub counts: Vec<usize>,
    pub density: Vec<f64>,
    pub n_bins: usize,
}

pub fn compute_dos(eigenvalues: &[f64], n_bins: usize) -> DosResult {
    if eigenvalues.len() < 2 {
        return DosResult {
            bin_centers: vec![],
            counts: vec![],
            density: vec![],
            n_bins: 0,
        };
    }
    let min_e = eigenvalues[0];
    let max_e = eigenvalues[eigenvalues.len() - 1];
    let range = max_e - min_e;
    if range < 1e-30 {
        return DosResult {
            bin_centers: vec![],
            counts: vec![],
            density: vec![],
            n_bins: 0,
        };
    }
    let bin_width = range / n_bins as f64;
    let mut counts = vec![0usize; n_bins];
    let mut bin_centers = vec![0.0f64; n_bins];
    for i in 0..n_bins {
        bin_centers[i] = min_e + (i as f64 + 0.5) * bin_width;
    }
    for &e in eigenvalues {
        let idx = ((e - min_e) / bin_width).floor() as usize;
        counts[idx.min(n_bins - 1)] += 1;
    }
    let n = eigenvalues.len() as f64;
    let density: Vec<f64> = counts.iter().map(|&c| c as f64 / (n * bin_width)).collect();
    DosResult {
        bin_centers,
        counts,
        density,
        n_bins,
    }
}

pub fn compute_kde(eigenvalues: &[f64], n_pts: usize, bandwidth: f64) -> (Vec<f64>, Vec<f64>) {
    if eigenvalues.len() < 2 {
        return (vec![], vec![]);
    }
    let min_e = eigenvalues[0];
    let max_e = eigenvalues[eigenvalues.len() - 1];
    let margin = (max_e - min_e) * 0.1;
    let lo = min_e - margin;
    let hi = max_e + margin;
    let energies: Vec<f64> = (0..n_pts)
        .map(|i| lo + (hi - lo) * i as f64 / (n_pts - 1) as f64)
        .collect();
    let n = eigenvalues.len() as f64;
    let density: Vec<f64> = energies
        .iter()
        .map(|&e| {
            eigenvalues
                .iter()
                .map(|&ei| {
                    let z = (e - ei) / bandwidth;
                    (-0.5 * z * z).exp() / (bandwidth * (2.0 * PI).sqrt())
                })
                .sum::<f64>()
                / n
        })
        .collect();
    (energies, density)
}

// ═══════════════════════════════════════════════
// VAN HOVE SINGULARITY FIT
// ═══════════════════════════════════════════════

/// Fit ρ(E) = A·ln|E - E₀| + B near the edge. Returns (A, E0, B, R²).
pub fn fit_van_hove(eigenvalues: &[f64], fraction: f64) -> (f64, f64, f64, f64) {
    if eigenvalues.len() < 5 {
        return (0.0, 0.0, 0.0, 0.0);
    }
    let n_fit = (eigenvalues.len() as f64 * fraction).ceil() as usize;
    let n_fit = n_fit.max(5).min(eigenvalues.len());
    let e0 = eigenvalues[0] * 0.99;

    let mut xs = Vec::new();
    let mut ys = Vec::new();
    for i in 0..n_fit {
        let e = eigenvalues[i];
        if e - e0 <= 0.0 {
            continue;
        }
        xs.push((e - e0).ln());
        ys.push((i as f64 + 0.5) / eigenvalues.len() as f64);
    }
    if xs.len() < 3 {
        return (0.0, e0, 0.0, 0.0);
    }

    let n = xs.len() as f64;
    let sx: f64 = xs.iter().sum();
    let sy: f64 = ys.iter().sum();
    let sxy: f64 = xs.iter().zip(ys.iter()).map(|(x, y)| x * y).sum();
    let sx2: f64 = xs.iter().map(|x| x * x).sum();
    let denom = n * sx2 - sx * sx;
    if denom.abs() < 1e-30 {
        return (0.0, e0, 0.0, 0.0);
    }

    let a = (n * sxy - sx * sy) / denom;
    let b = (sy - a * sx) / n;
    let y_mean = sy / n;
    let ss_tot: f64 = ys.iter().map(|y| (y - y_mean).powi(2)).sum();
    let ss_res: f64 = xs
        .iter()
        .zip(ys.iter())
        .map(|(x, y)| (y - (a * x + b)).powi(2))
        .sum();
    let r2 = if ss_tot > 1e-30 {
        1.0 - ss_res / ss_tot
    } else {
        0.0
    };
    (a, e0, b, r2)
}

// ═══════════════════════════════════════════════
// LEVEL SPACING — UNIVERSALITY CLASS DISCRIMINATION
// ═══════════════════════════════════════════════

pub struct SpacingResult {
    pub spacings: Vec<f64>,
    pub unfolded: Vec<f64>,
    pub mean_spacing: f64,
    pub gue_fit: f64,     // Wigner surmise (β=2): P(s) = 32s²/π² · exp(-4s²/π)
    pub goe_fit: f64,     // Wigner surmise (β=1): P(s) = πs/2 · exp(-πs²/4)
    pub gse_fit: f64,     // Wigner surmise (β=4): P(s) = 2^18/(3^6·π³)·s⁴·exp(-64s²/(9π))
    pub poisson_fit: f64, // P(s) = exp(-s)
    pub best_class: &'static str,
}

pub fn compute_spacing(eigenvalues: &[f64]) -> SpacingResult {
    let empty = SpacingResult {
        spacings: vec![],
        unfolded: vec![],
        mean_spacing: 0.0,
        gue_fit: 0.0,
        goe_fit: 0.0,
        gse_fit: 0.0,
        poisson_fit: 0.0,
        best_class: "N/A",
    };
    if eigenvalues.len() < 4 {
        return empty;
    }

    let n = eigenvalues.len();
    let mut spacings: Vec<f64> = Vec::with_capacity(n - 1);
    for i in 1..n {
        spacings.push(eigenvalues[i] - eigenvalues[i - 1]);
    }
    let mean_s: f64 = spacings.iter().sum::<f64>() / spacings.len() as f64;

    // Unfolded spacings with local window
    let window = 5;
    let unfolded: Vec<f64> = spacings
        .iter()
        .enumerate()
        .map(|(i, &s)| {
            let lo = i.saturating_sub(window);
            let hi = (i + window + 1).min(spacings.len());
            let local_mean: f64 = spacings[lo..hi].iter().sum::<f64>() / (hi - lo) as f64;
            if local_mean > 1e-30 {
                s / local_mean
            } else {
                0.0
            }
        })
        .collect();

    // Histogram (20 bins from 0 to 4)
    let n_bins = 20;
    let s_max = 4.0;
    let bin_w = s_max / n_bins as f64;
    let mut hist = vec![0usize; n_bins];
    for &s in &unfolded {
        let idx = (s / bin_w).floor() as usize;
        if idx < n_bins {
            hist[idx] += 1;
        }
    }
    let n_total = unfolded.len() as f64;

    // Fit all four universality classes
    let mut gue_err = 0.0f64;
    let mut goe_err = 0.0f64;
    let mut gse_err = 0.0f64;
    let mut poisson_err = 0.0f64;

    for i in 0..n_bins {
        let s = (i as f64 + 0.5) * bin_w;
        let p_obs = hist[i] as f64 / (n_total * bin_w);

        // GUE (β=2): P(s) = 32s²/π² · exp(-4s²/π)
        let p_gue = 32.0 * s * s / (PI * PI) * (-4.0 * s * s / PI).exp();

        // GOE (β=1): P(s) = πs/2 · exp(-πs²/4)
        let p_goe = PI / 2.0 * s * (-PI * s * s / 4.0).exp();

        // GSE (β=4): P(s) = 2^18/(3^6·π³) · s⁴ · exp(-64s²/(9π))
        let p_gse =
            262144.0 / (729.0 * PI * PI * PI) * s.powi(4) * (-64.0 * s * s / (9.0 * PI)).exp();

        // Poisson: P(s) = exp(-s)
        let p_poisson = (-s).exp();

        gue_err += (p_obs - p_gue).powi(2);
        goe_err += (p_obs - p_goe).powi(2);
        gse_err += (p_obs - p_gse).powi(2);
        poisson_err += (p_obs - p_poisson).powi(2);
    }

    let gue_fit = 1.0 / (1.0 + gue_err);
    let goe_fit = 1.0 / (1.0 + goe_err);
    let gse_fit = 1.0 / (1.0 + gse_err);
    let poisson_fit = 1.0 / (1.0 + poisson_err);

    let best_class = if gue_fit >= goe_fit && gue_fit >= gse_fit && gue_fit >= poisson_fit {
        "GUE (β=2)"
    } else if goe_fit >= gse_fit && goe_fit >= poisson_fit {
        "GOE (β=1)"
    } else if gse_fit >= poisson_fit {
        "GSE (β=4)"
    } else {
        "Poisson"
    };

    SpacingResult {
        spacings,
        unfolded,
        mean_spacing: mean_s,
        gue_fit,
        goe_fit,
        gse_fit,
        poisson_fit,
        best_class,
    }
}

// ═══════════════════════════════════════════════
// CROSS-CHANNEL CORRELATION
// ═══════════════════════════════════════════════

/// Compute Pearson correlation between two eigenvalue staircases.
/// Both are interpolated to the same energy grid.
pub fn staircase_correlation(eigs_a: &[f64], eigs_b: &[f64]) -> f64 {
    if eigs_a.len() < 3 || eigs_b.len() < 3 {
        return 0.0;
    }

    // Build common energy grid
    let e_min = eigs_a[0].min(eigs_b[0]);
    let e_max = eigs_a[eigs_a.len() - 1].max(eigs_b[eigs_b.len() - 1]);
    let n_pts = 100;
    let de = (e_max - e_min) / n_pts as f64;

    let staircase = |eigs: &[f64], e: f64| -> f64 {
        eigs.iter().filter(|&&ei| ei <= e).count() as f64 / eigs.len() as f64
    };

    let mut xs = Vec::with_capacity(n_pts);
    let mut ys = Vec::with_capacity(n_pts);
    for i in 0..n_pts {
        let e = e_min + (i as f64 + 0.5) * de;
        xs.push(staircase(eigs_a, e));
        ys.push(staircase(eigs_b, e));
    }

    // Pearson correlation
    let n = xs.len() as f64;
    let mx: f64 = xs.iter().sum::<f64>() / n;
    let my: f64 = ys.iter().sum::<f64>() / n;
    let mut sxy = 0.0f64;
    let mut sxx = 0.0f64;
    let mut syy = 0.0f64;
    for i in 0..xs.len() {
        let dx = xs[i] - mx;
        let dy = ys[i] - my;
        sxy += dx * dy;
        sxx += dx * dx;
        syy += dy * dy;
    }
    let denom = (sxx * syy).sqrt();
    if denom < 1e-30 { 0.0 } else { sxy / denom }
}
