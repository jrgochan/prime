//! Energy sweep mode — scan |interference| over a range with CSV/JSON output.

use cathedral_utils::harmonics::PrimeOscillatorBank;
use cathedral_utils::zeta_zeros::ZETA_ZEROS;
use crate::cli::OutputFormat;
use crate::display;
use serde::Serialize;

#[derive(Serialize)]
struct SweepPoint {
    t: f64,
    re: f64,
    im: f64,
    norm: f64,
}

pub fn run(bank: &PrimeOscillatorBank, t_start: f64, t_end: f64, steps: usize, format: &OutputFormat) {
    match format {
        OutputFormat::Csv => run_csv(bank, t_start, t_end, steps),
        OutputFormat::Json => run_json(bank, t_start, t_end, steps),
        OutputFormat::Terminal => run_terminal(bank, t_start, t_end, steps),
    }
}

fn run_csv(bank: &PrimeOscillatorBank, t_start: f64, t_end: f64, steps: usize) {
    println!("t,re,im,norm");
    let dt = (t_end - t_start) / steps as f64;
    for step in 0..=steps {
        let t = t_start + dt * step as f64;
        let (re, im) = bank.interference(t, bank.len());
        let norm = (re * re + im * im).sqrt();
        println!("{:.10},{:.10},{:.10},{:.10}", t, re, im, norm);
    }
}

fn run_json(bank: &PrimeOscillatorBank, t_start: f64, t_end: f64, steps: usize) {
    let dt = (t_end - t_start) / steps as f64;
    let points: Vec<SweepPoint> = (0..=steps)
        .map(|step| {
            let t = t_start + dt * step as f64;
            let (re, im) = bank.interference(t, bank.len());
            let norm = (re * re + im * im).sqrt();
            SweepPoint { t, re, im, norm }
        })
        .collect();

    println!("{}", serde_json::to_string_pretty(&points).unwrap());
}

fn run_terminal(bank: &PrimeOscillatorBank, t_start: f64, t_end: f64, steps: usize) {
    println!("🌀 ENERGY SWEEP [{:.2}, {:.2}], {} steps", t_start, t_end, steps);
    println!("   {} primes", bank.len());
    println!();

    let sweep = bank.energy_sweep(t_start, t_end, steps);
    let max_norm = sweep.iter().map(|(_, n)| *n).fold(0.0f64, f64::max);

    let display_rows = 100.min(steps);
    let stride = (steps / display_rows).max(1);

    for (i, &(t, n)) in sweep.iter().enumerate() {
        if i % stride != 0 && i != steps { continue; }
        let bar = display::render_bar(n, max_norm, 50);
        let is_zero = ZETA_ZEROS.iter().any(|&z| (t - z).abs() < (t_end - t_start) / steps as f64 * stride as f64 * 0.6);
        let marker = if is_zero { " ← ζ" } else { "" };
        println!("  t={:>8.3} |{bar}| {:>7.4}{marker}", t, n);
    }
}
