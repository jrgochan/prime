//! Fine scan mode — high-resolution analysis around a specific height.

use crate::display;
use cathedral_utils::harmonics::{golden_section_min, PrimeOscillatorBank};
use cathedral_utils::zeta_zeros;

pub fn run(bank: &PrimeOscillatorBank, center: f64, window: f64, steps: usize) {
    println!("🌀 FINE SCAN around t = {:.6} ± {:.4}", center, window);
    println!(
        "   {} primes, {} steps, resolution = {:.2e}",
        bank.len(),
        steps,
        2.0 * window / steps as f64
    );
    println!();

    let t_start = center - window;
    let t_end = center + window;
    let sweep = bank.energy_sweep(t_start, t_end, steps);

    // Find minimum
    let (min_t, min_norm) = sweep
        .iter()
        .copied()
        .min_by(|(_, a), (_, b)| a.partial_cmp(b).unwrap())
        .unwrap_or((center, f64::MAX));

    // Display
    let max_norm = sweep.iter().map(|(_, n)| *n).fold(0.0f64, f64::max);
    let display_steps = 60.min(steps);
    let stride = (steps / display_steps).max(1);
    let dt = (t_end - t_start) / steps as f64;

    for (i, &(t, n)) in sweep.iter().enumerate() {
        if i % stride != 0 && i != steps {
            continue;
        }
        let bar = display::render_bar(n, max_norm, 50);
        let marker = if (t - min_t).abs() < dt {
            " ← MIN"
        } else {
            ""
        };
        println!("  t={:>12.8} |{bar}| {:>8.5}{marker}", t, n);
    }

    println!();
    println!("  ⭐ Minimum: t = {:.12}, |Σ| = {:.12}", min_t, min_norm);

    // Golden-section refinement
    let (refined_t, refined_n) = golden_section_min(
        &|t| bank.interference_norm_all(t),
        min_t - dt,
        min_t + dt,
        1e-14,
    );
    println!(
        "  ⭐ Refined:  t = {:.14}, |Σ| = {:.14}",
        refined_t, refined_n
    );

    // Check against known zeros
    if let Some((idx, closest)) = zeta_zeros::nearest_zero(center) {
        println!("  📍 Nearest known zero #{}: {:.14}", idx + 1, closest);
        println!("     Δ = {:.2e}", (refined_t - closest).abs());
    }
}
