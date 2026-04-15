/// Spectral Comparison — Ludicrously Parallel Edition 🦀
///
/// Compares Log Cutoff vs Flat Möbius vs Sharp Cutoff witnesses
/// using rayon for embarrassingly parallel spectral computation.
/// Writes results to timestamped log files in results/.

use rayon::prelude::*;
use std::fmt::Write as FmtWrite;
use std::fs;
use std::io::Write;
use std::time::Instant;

const RIEMANN_ZEROS: &[f64] = &[
    14.134725, 21.022040, 25.010858, 30.424876, 32.935062,
    37.586178, 40.918719, 43.327073, 48.005151, 49.773832,
    52.970321, 56.446248, 59.347044, 60.831779, 65.112544,
    67.079811, 69.546402, 72.067158, 75.704691, 77.144840,
    79.337375, 82.910381, 84.735493, 87.425275, 88.809111,
    92.491899, 94.651344, 95.870634, 98.831194, 101.317851,
];

fn mobius_sieve(n: usize) -> Vec<i8> {
    let mut mu = vec![0i8; n + 1];
    mu[1] = 1;
    let mut is_prime = vec![true; n + 1];
    let mut primes = Vec::new();
    for i in 2..=n {
        if is_prime[i] {
            primes.push(i);
            mu[i] = -1;
        }
        for &p in &primes {
            if i * p > n { break; }
            is_prime[i * p] = false;
            if i % p == 0 {
                mu[i * p] = 0;
                break;
            } else {
                mu[i * p] = -mu[i];
            }
        }
    }
    mu
}

#[inline]
fn energy_at_t(coeffs: &[f64], ln_k: &[f64], t: f64) -> f64 {
    let mut re = 0.0f64;
    let mut im = 0.0f64;
    for i in 0..coeffs.len() {
        let phase = -t * unsafe { *ln_k.get_unchecked(i) };
        let (s, c) = phase.sin_cos();
        re += unsafe { *coeffs.get_unchecked(i) } * c;
        im += unsafe { *coeffs.get_unchecked(i) } * s;
    }
    re * re + im * im
}

fn compute_spectrum_parallel(coeffs: &[f64], ln_k: &[f64], t_values: &[f64]) -> Vec<f64> {
    t_values.par_iter()
        .map(|&t| energy_at_t(coeffs, ln_k, t))
        .collect()
}

struct Stats {
    name: String,
    bg_mean: f64,
    bg_std: f64,
    avg_peak: f64,
    avg_snr: f64,
    avg_sigma: f64,
    avg_fwhm: f64,
    dynamic_range: f64,
    peak_energies: Vec<f64>,
}

fn analyze(name: &str, energy: &[f64], t_values: &[f64], t_max: f64) -> Stats {
    let mut bg = Vec::new();
    for (i, &t) in t_values.iter().enumerate() {
        if t <= 10.0 { continue; }
        if RIEMANN_ZEROS.iter().any(|&z| (t - z).abs() < 1.0) { continue; }
        bg.push(energy[i]);
    }
    let bg_mean = bg.iter().sum::<f64>() / bg.len() as f64;
    let bg_var = bg.iter().map(|&x| (x - bg_mean).powi(2)).sum::<f64>() / bg.len() as f64;
    let bg_std = bg_var.sqrt();

    let mut peak_energies = Vec::new();
    let mut fwhms = Vec::new();

    for &z in RIEMANN_ZEROS {
        if z > t_max { break; }
        let mut best_e = 0.0f64;
        let mut local: Vec<(f64, f64)> = Vec::new();
        for (i, &t) in t_values.iter().enumerate() {
            if (t - z).abs() < 0.5 {
                local.push((t, energy[i]));
                if energy[i] > best_e { best_e = energy[i]; }
            }
        }
        peak_energies.push(best_e);
        let half = best_e / 2.0;
        let above: Vec<f64> = local.iter().filter(|(_, e)| *e >= half).map(|(t, _)| *t).collect();
        let fwhm = if above.len() >= 2 { above.last().unwrap() - above.first().unwrap() } else { 0.0 };
        fwhms.push(fwhm);
    }

    let avg_peak = peak_energies.iter().sum::<f64>() / peak_energies.len() as f64;
    let max_p = peak_energies.iter().cloned().fold(0.0f64, f64::max);
    let min_p = peak_energies.iter().cloned().fold(f64::MAX, f64::min);

    Stats {
        name: name.to_string(),
        bg_mean,
        bg_std,
        avg_peak,
        avg_snr: avg_peak / bg_mean,
        avg_sigma: (avg_peak - bg_mean) / bg_std,
        avg_fwhm: fwhms.iter().sum::<f64>() / fwhms.len() as f64,
        dynamic_range: if min_p > 0.0 { max_p / min_p } else { 0.0 },
        peak_energies,
    }
}

/// Tee: prints to stdout AND appends to log buffer
macro_rules! tee {
    ($log:expr, $($arg:tt)*) => {{
        let line = format!($($arg)*);
        println!("{}", line);
        writeln!($log, "{}", line).unwrap();
    }};
}

fn main() {
    let n: usize = std::env::args()
        .nth(1)
        .and_then(|s| s.replace(['_', ','], "").parse().ok())
        .unwrap_or(200_000);

    let t_min = 0.5f64;
    let t_max = 100.0f64;
    let dt = 0.005f64;
    let num_t = ((t_max - t_min) / dt) as usize;
    let t_values: Vec<f64> = (0..num_t).map(|i| t_min + i as f64 * dt).collect();
    let num_threads = rayon::current_num_threads();

    let mut log = String::new();

    tee!(log, "{}", "=".repeat(80));
    tee!(log, "SPECTRAL COMPARISON — Ludicrously Parallel Edition");
    tee!(log, "N = {:>12}, t in [{}, {}], dt = {}, {} samples",
        n, t_min, t_max, dt, num_t);
    tee!(log, "Threads: {}", num_threads);
    tee!(log, "{}", "=".repeat(80));

    let total_t0 = Instant::now();

    // Sieve
    let t0 = Instant::now();
    let mu = mobius_sieve(n);
    tee!(log, "\nMobius sieve: {:?}", t0.elapsed());

    // Precompute
    let ln_n = (n as f64).ln();
    let mut ln_k = vec![0.0f64; n];
    let mut k_half = vec![0.0f64; n];
    for i in 0..n {
        let k = (i + 1) as f64;
        ln_k[i] = k.ln();
        k_half[i] = k.powf(-0.5);
    }

    // Build witnesses
    let log_coeffs: Vec<f64> = (0..n).map(|i| {
        -(mu[i+1] as f64) * (1.0 - ln_k[i] / ln_n) * k_half[i]
    }).collect();
    let flat_coeffs: Vec<f64> = (0..n).map(|i| {
        -(mu[i+1] as f64) * k_half[i]
    }).collect();
    let sharp_coeffs: Vec<f64> = (0..n).map(|i| {
        if i + 1 <= n / 2 { -(mu[i+1] as f64) * k_half[i] } else { 0.0 }
    }).collect();

    let witnesses: Vec<(&str, &[f64])> = vec![
        ("Log Cutoff (Cathedral)", &log_coeffs),
        ("Flat Mobius (no taper)", &flat_coeffs),
        ("Sharp Cutoff (k<=N/2)", &sharp_coeffs),
    ];

    let mut all_stats: Vec<Stats> = Vec::new();

    for (name, coeffs) in &witnesses {
        tee!(log, "\nComputing: {}...", name);
        let t0 = Instant::now();
        let energy = compute_spectrum_parallel(coeffs, &ln_k, &t_values);
        let elapsed = t0.elapsed();
        tee!(log, "  Done in {:?}", elapsed);
        all_stats.push(analyze(name, &energy, &t_values, t_max));
    }

    let total_elapsed = total_t0.elapsed();
    tee!(log, "\nTotal compute: {:?}", total_elapsed);

    // ============================================================
    // Comparison table
    // ============================================================
    tee!(log, "\n{}", "=".repeat(80));
    tee!(log, "COMPARISON TABLE");
    tee!(log, "{}", "=".repeat(80));

    let names: Vec<String> = all_stats.iter().map(|s| {
        s.name.chars().take(20).collect::<String>()
    }).collect();

    tee!(log, "{:<25} {:>18} {:>18} {:>18}",
        "Metric", &names[0], &names[1], &names[2]);
    tee!(log, "{}", "-".repeat(80));
    tee!(log, "{:<25} {:>18.4} {:>18.4} {:>18.4}", "Background mean",
        all_stats[0].bg_mean, all_stats[1].bg_mean, all_stats[2].bg_mean);
    tee!(log, "{:<25} {:>18.4} {:>18.4} {:>18.4}", "Background std",
        all_stats[0].bg_std, all_stats[1].bg_std, all_stats[2].bg_std);
    tee!(log, "{:<25} {:>18.2} {:>18.2} {:>18.2}", "Avg peak energy",
        all_stats[0].avg_peak, all_stats[1].avg_peak, all_stats[2].avg_peak);
    tee!(log, "{:<25} {:>18.1} {:>18.1} {:>18.1}", "Avg SNR (peak/bg)",
        all_stats[0].avg_snr, all_stats[1].avg_snr, all_stats[2].avg_snr);
    tee!(log, "{:<25} {:>18.1} {:>18.1} {:>18.1}", "Avg significance",
        all_stats[0].avg_sigma, all_stats[1].avg_sigma, all_stats[2].avg_sigma);
    tee!(log, "{:<25} {:>18.4} {:>18.4} {:>18.4}", "Avg FWHM",
        all_stats[0].avg_fwhm, all_stats[1].avg_fwhm, all_stats[2].avg_fwhm);
    tee!(log, "{:<25} {:>18.2} {:>18.2} {:>18.2}", "Dynamic range",
        all_stats[0].dynamic_range, all_stats[1].dynamic_range, all_stats[2].dynamic_range);

    // ============================================================
    // Per-zero comparison
    // ============================================================
    tee!(log, "\n{}", "=".repeat(80));
    tee!(log, "PER-ZERO PEAK ENERGY");
    tee!(log, "{}", "=".repeat(80));
    tee!(log, "{:>8} {:>12} {:>12} {:>12} {:>10}",
        "Zero", "Log Cutoff", "Flat Mobius", "Sharp Cut", "Log/Flat");
    tee!(log, "{}", "-".repeat(60));

    let mut ratio_sum = 0.0f64;
    let mut ratio_count = 0usize;

    for i in 0..all_stats[0].peak_energies.len() {
        let z = RIEMANN_ZEROS[i];
        let le = all_stats[0].peak_energies[i];
        let fe = all_stats[1].peak_energies[i];
        let se = all_stats[2].peak_energies[i];
        let ratio = if fe > 0.0 { le / fe } else { 0.0 };
        ratio_sum += ratio;
        ratio_count += 1;
        tee!(log, "{:>8.3} {:>12.2} {:>12.2} {:>12.2} {:>10.4}x",
            z, le, fe, se, ratio);
    }

    let avg_ratio = ratio_sum / ratio_count as f64;

    // ============================================================
    // Conclusion
    // ============================================================
    let snr_r = all_stats[0].avg_snr / all_stats[1].avg_snr;
    let fwhm_r = if all_stats[1].avg_fwhm > 0.0 {
        all_stats[0].avg_fwhm / all_stats[1].avg_fwhm
    } else { 0.0 };

    tee!(log, "\n{}", "=".repeat(80));
    tee!(log, "SUMMARY");
    tee!(log, "{}", "=".repeat(80));
    tee!(log, "N = {}", n);
    tee!(log, "ln(N) = {:.4}", ln_n);
    tee!(log, "Threads = {}", num_threads);
    tee!(log, "Wall time = {:?}", total_elapsed);
    tee!(log, "");
    tee!(log, "Avg Log/Flat ratio:   {:.5}  (predicted limit: 0.25000)", avg_ratio);
    tee!(log, "Delta from 0.25:      {:.5}", (avg_ratio - 0.25).abs());
    tee!(log, "SNR ratio (log/flat): {:.4}x", snr_r);
    tee!(log, "FWHM ratio:           {:.4}x  (< 1.0 = sharper)", fwhm_r);
    tee!(log, "Log dynamic range:    {:.2}", all_stats[0].dynamic_range);
    tee!(log, "Flat dynamic range:   {:.2}", all_stats[1].dynamic_range);
    tee!(log, "{}", "=".repeat(80));

    // ============================================================
    // Write log file
    // ============================================================
    let log_filename = format!("results/comparison_N{}.log", n);
    let mut file = fs::File::create(&log_filename).expect("Failed to create log file");
    file.write_all(log.as_bytes()).expect("Failed to write log");

    // Also write a CSV for the per-zero data
    let csv_filename = format!("results/per_zero_N{}.csv", n);
    let mut csv = fs::File::create(&csv_filename).expect("Failed to create CSV");
    writeln!(csv, "zero,log_energy,flat_energy,sharp_energy,log_flat_ratio").unwrap();
    for i in 0..all_stats[0].peak_energies.len() {
        let z = RIEMANN_ZEROS[i];
        let le = all_stats[0].peak_energies[i];
        let fe = all_stats[1].peak_energies[i];
        let se = all_stats[2].peak_energies[i];
        let r = if fe > 0.0 { le / fe } else { 0.0 };
        writeln!(csv, "{:.6},{:.6},{:.6},{:.6},{:.6}", z, le, fe, se, r).unwrap();
    }

    println!("\nLogs saved:");
    println!("  {}", log_filename);
    println!("  {}", csv_filename);
}
