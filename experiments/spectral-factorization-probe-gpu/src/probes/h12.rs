//! H12: Mellin Transform Critical-Line Residue
//!
//! Tests whether the Mellin transform of f_N(x) = Σ v_k {k/x}
//! evaluated on the critical line Re(s) = 1/2 shows pole-like behavior
//! at Im(s) = 2π/ln(p) for factors p of N.
//!
//! The Parseval Bridge ensures L² norm preservation, so any frequency-domain
//! "resonance" cannot contain factor-specific information not already present
//! in the spatial domain (where H1-H6 found nothing).

use crate::keygen::SemiprimeKey;
use crate::results::*;
use cathedral_utils::arith;

/// Number of frequency samples on the critical line.
const NUM_FREQ_SAMPLES: usize = 2000;
/// Maximum imaginary part to scan.
const T_MAX: f64 = 100.0;

/// Approximate |M[f_N](1/2 + it)| via numerical integration.
/// Uses trapezoidal rule over [ε, 1] (fractional part function support).
fn mellin_on_critical_line(weights: &[f64], t: f64, n_quadrature: usize) -> f64 {
    let eps = 1e-8;
    let dx = (1.0 - eps) / n_quadrature as f64;

    let mut sum_re = 0.0f64;
    let mut sum_im = 0.0f64;

    for i in 0..n_quadrature {
        let x = eps + (i as f64 + 0.5) * dx;
        // f_N(x) = Σ_k v_k * {k/x}
        let mut f_val = 0.0f64;
        for (idx, &w) in weights.iter().enumerate() {
            if w == 0.0 {
                continue;
            }
            let k = (idx + 2) as f64;
            let frac = (k / x).fract();
            f_val += w * frac;
        }

        // x^{s-1} = x^{-1/2} * x^{it} = x^{-1/2} * (cos(t ln x) + i sin(t ln x))
        let x_half_inv = 1.0 / x.sqrt();
        let phase = t * x.ln();
        let re_kernel = x_half_inv * phase.cos();
        let im_kernel = x_half_inv * phase.sin();

        sum_re += f_val * re_kernel * dx;
        sum_im += f_val * im_kernel * dx;
    }

    (sum_re * sum_re + sum_im * sum_im).sqrt()
}

pub fn h12_mellin_critical_line(keys: &[SemiprimeKey]) -> Vec<H12Result> {
    println!("  [H12] Mellin Transform Critical-Line Residue");
    println!("  ─────────────────────────────────────────────");
    let mut results = Vec::new();

    for key in keys.iter().take(3) {
        let p = key.p as usize;
        let m = (p * 3).min(2000).max(50);
        let mu = arith::mobius_table(m);
        let weights = cathedral_utils::mertens::witness_vector(m, &mu);
        let dim = weights.len();

        // Expected resonance frequencies: t = 2πk / ln(p)
        let ln_p = (key.p as f64).ln();
        let expected_freqs: Vec<f64> = (1..=5)
            .map(|k| 2.0 * std::f64::consts::PI * k as f64 / ln_p)
            .collect();

        // Scan the critical line
        let dt = T_MAX / NUM_FREQ_SAMPLES as f64;
        let mut spectrum: Vec<(f64, f64)> = Vec::new();
        let n_quad = 500.min(dim * 2); // quadrature points

        for i in 0..NUM_FREQ_SAMPLES {
            let t = (i as f64 + 0.5) * dt;
            let amplitude = mellin_on_critical_line(&weights, t, n_quad);
            spectrum.push((t, amplitude));
        }

        // Find peaks: local maxima above 1.5× median
        let amplitudes: Vec<f64> = spectrum.iter().map(|(_, a)| *a).collect();
        let mut sorted_amps = amplitudes.clone();
        sorted_amps.sort_by(|a, b| a.partial_cmp(b).unwrap());
        let median_amp = sorted_amps[sorted_amps.len() / 2];

        let mut peaks: Vec<MellinPeakEntry> = Vec::new();
        for i in 1..spectrum.len() - 1 {
            let (t, a) = spectrum[i];
            if a > spectrum[i - 1].1 && a > spectrum[i + 1].1 && a > median_amp * 1.5 {
                // Check if this peak is near an expected resonance
                let near_expected = expected_freqs.iter().any(|&ef| (t - ef).abs() < dt * 3.0);
                peaks.push(MellinPeakEntry {
                    frequency: t,
                    amplitude: a,
                    near_expected_resonance: near_expected,
                });
            }
        }

        // Count peaks near expected vs total
        let near_count = peaks.iter().filter(|p| p.near_expected_resonance).count();
        let total_peaks = peaks.len();
        let resonance_fraction = if total_peaks > 0 {
            near_count as f64 / total_peaks as f64
        } else {
            0.0
        };

        // Under null hypothesis (random peaks), expected fraction ≈ 5 * 6dt / T_MAX
        let expected_fraction = 5.0 * 6.0 * dt / T_MAX;

        println!("    N={} = {}×{}, M={}", key.n, key.p, key.q, m);
        println!("      Expected resonances at t = 2πk/ln({}):", key.p);
        for (k, ef) in expected_freqs.iter().enumerate() {
            println!("        k={}: t={:.4}", k + 1, ef);
        }
        println!(
            "      Scanned {} frequencies, found {} peaks above 1.5× median",
            NUM_FREQ_SAMPLES, total_peaks
        );
        println!(
            "      Peaks near expected resonances: {}/{}",
            near_count, total_peaks
        );
        println!(
            "      Resonance fraction: {:.4} (null expected: {:.4})",
            resonance_fraction, expected_fraction
        );

        // Sort and show top peaks
        peaks.sort_by(|a, b| b.amplitude.partial_cmp(&a.amplitude).unwrap());
        println!("      Top-5 peaks:");
        for (i, p) in peaks.iter().take(5).enumerate() {
            println!(
                "        #{}: t={:.4} amp={:.6e} {}",
                i + 1,
                p.frequency,
                p.amplitude,
                if p.near_expected_resonance {
                    "← NEAR EXPECTED"
                } else {
                    ""
                }
            );
        }

        let signal = if resonance_fraction > expected_fraction * 3.0 && near_count >= 2 {
            "weak 〜"
        } else {
            "null ∅"
        };
        println!("      Signal: {}\n", signal);

        results.push(H12Result {
            n: key.n,
            p: key.p,
            q: key.q,
            dim: m,
            num_freq_samples: NUM_FREQ_SAMPLES,
            t_max: T_MAX,
            total_peaks,
            peaks_near_expected: near_count,
            resonance_fraction,
            expected_null_fraction: expected_fraction,
            top_peaks: peaks.into_iter().take(10).collect(),
        });
    }
    results
}
