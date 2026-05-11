//! Spectral analysis: density of states, level spacing, and thermodynamics.

use std::f64::consts::PI;

/// Density of states via histogram binning.
pub struct DosResult {
    pub bin_centers: Vec<f64>,
    pub counts: Vec<usize>,
    pub density: Vec<f64>, // normalized
    pub n_bins: usize,
}

pub fn compute_dos(eigenvalues: &[f64], n_bins: usize) -> DosResult {
    let min_e = eigenvalues[0];
    let max_e = eigenvalues[eigenvalues.len() - 1];
    let range = max_e - min_e;
    let bin_width = range / n_bins as f64;

    let mut counts = vec![0usize; n_bins];
    let mut bin_centers = vec![0.0f64; n_bins];

    for i in 0..n_bins {
        bin_centers[i] = min_e + (i as f64 + 0.5) * bin_width;
    }

    for &e in eigenvalues {
        let idx = ((e - min_e) / bin_width).floor() as usize;
        let idx = idx.min(n_bins - 1);
        counts[idx] += 1;
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

/// Gaussian kernel density estimate for smooth DOS.
pub struct KdeResult {
    pub energies: Vec<f64>,
    pub density: Vec<f64>,
}

pub fn compute_kde(eigenvalues: &[f64], n_pts: usize, bandwidth: f64) -> KdeResult {
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
            let sum: f64 = eigenvalues
                .iter()
                .map(|&ei| {
                    let z = (e - ei) / bandwidth;
                    (-0.5 * z * z).exp() / (bandwidth * (2.0 * PI).sqrt())
                })
                .sum();
            sum / n
        })
        .collect();

    KdeResult { energies, density }
}

/// Van Hove singularity fit: ρ(E) = A·ln|E - E₀| + B
/// near the minimum eigenvalue. Returns (A, E0, B, R²).
pub fn fit_van_hove(eigenvalues: &[f64], fraction: f64) -> (f64, f64, f64, f64) {
    let n_fit = (eigenvalues.len() as f64 * fraction).ceil() as usize;
    let n_fit = n_fit.max(5).min(eigenvalues.len());

    let e0 = eigenvalues[0] * 0.99; // slightly below min

    // Build local DOS near edge: use spacings as proxy for 1/ρ
    let mut xs = Vec::new(); // ln|E - E0|
    let mut ys = Vec::new(); // cumulative density proxy

    for i in 0..n_fit {
        let e = eigenvalues[i];
        let log_diff = (e - e0).ln();
        xs.push(log_diff);
        ys.push((i as f64 + 0.5) / eigenvalues.len() as f64);
    }

    // Linear regression: y = A·x + B
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

    // R²
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

/// Level spacing statistics.
pub struct SpacingResult {
    pub spacings: Vec<f64>, // raw gaps
    pub unfolded: Vec<f64>, // unfolded spacings (normalized by local mean)
    pub mean_spacing: f64,
    pub wigner_surmise_fit: f64, // fit quality to P(s)=π/2·s·exp(-πs²/4)
    pub poisson_fit: f64,        // fit quality to P(s)=exp(-s)
}

pub fn compute_spacing(eigenvalues: &[f64]) -> SpacingResult {
    let n = eigenvalues.len();
    let mut spacings: Vec<f64> = Vec::with_capacity(n - 1);

    for i in 1..n {
        spacings.push(eigenvalues[i] - eigenvalues[i - 1]);
    }

    let mean_s: f64 = spacings.iter().sum::<f64>() / spacings.len() as f64;

    // Unfolded spacings: s_i / <s>_local (using window of 5)
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

    // Histogram of unfolded spacings (20 bins from 0 to 4)
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

    // Fit to Wigner surmise: P(s) = π/2 · s · exp(-πs²/4)
    let mut wigner_err = 0.0;
    let mut poisson_err = 0.0;
    for i in 0..n_bins {
        let s = (i as f64 + 0.5) * bin_w;
        let p_obs = hist[i] as f64 / (n_total * bin_w);
        let p_wigner = PI / 2.0 * s * (-PI * s * s / 4.0).exp();
        let p_poisson = (-s).exp();
        wigner_err += (p_obs - p_wigner).powi(2);
        poisson_err += (p_obs - p_poisson).powi(2);
    }

    SpacingResult {
        spacings,
        unfolded,
        mean_spacing: mean_s,
        wigner_surmise_fit: 1.0 / (1.0 + wigner_err),
        poisson_fit: 1.0 / (1.0 + poisson_err),
    }
}

/// Thermal partition function and specific heat.
pub struct ThermoResult {
    pub betas: Vec<f64>,
    pub free_energy: Vec<f64>,
    pub specific_heat: Vec<f64>,
    pub entropy: Vec<f64>,
}

pub fn compute_thermo(eigenvalues: &[f64], beta_range: (f64, f64), n_pts: usize) -> ThermoResult {
    let log_lo = beta_range.0.ln();
    let log_hi = beta_range.1.ln();

    let betas: Vec<f64> = (0..n_pts)
        .map(|i| (log_lo + (log_hi - log_lo) * i as f64 / (n_pts - 1) as f64).exp())
        .collect();

    let mut free_energy = Vec::with_capacity(n_pts);
    let mut specific_heat = Vec::with_capacity(n_pts);
    let mut entropy = Vec::with_capacity(n_pts);

    for &beta in &betas {
        // Z = Σ exp(-β·λ_k)
        // Use log-sum-exp for numerical stability
        let max_exp = eigenvalues
            .iter()
            .map(|&e| -beta * e)
            .fold(f64::NEG_INFINITY, f64::max);
        let log_z: f64 = max_exp
            + eigenvalues
                .iter()
                .map(|&e| (-beta * e - max_exp).exp())
                .sum::<f64>()
                .ln();

        let f = -log_z / beta;

        // <E> = -∂ln(Z)/∂β = Σ λ_k exp(-βλ_k) / Z
        let mean_e: f64 = eigenvalues
            .iter()
            .map(|&e| e * (-beta * e - max_exp).exp())
            .sum::<f64>()
            / (log_z - max_exp).exp();

        // <E²> = Σ λ_k² exp(-βλ_k) / Z
        let mean_e2: f64 = eigenvalues
            .iter()
            .map(|&e| e * e * (-beta * e - max_exp).exp())
            .sum::<f64>()
            / (log_z - max_exp).exp();

        let cv = beta * beta * (mean_e2 - mean_e * mean_e);
        let s = beta * (mean_e - f);

        free_energy.push(f);
        specific_heat.push(cv);
        entropy.push(s);
    }

    ThermoResult {
        betas,
        free_energy,
        specific_heat,
        entropy,
    }
}
