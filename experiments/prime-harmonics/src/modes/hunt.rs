//! Zero hunting mode — find zeta zeros via interference minima + Hardy Z cross-validation.

use cathedral_utils::harmonics::{golden_section_min, PrimeOscillatorBank};
use cathedral_utils::riemann_siegel::hardy_z;
use cathedral_utils::zeta_zeros;
use std::time::Instant;

pub fn run(bank: &PrimeOscillatorBank, t_start: f64, t_end: f64, steps: usize) {
    println!("🌀 ZERO HUNTING in [{:.2}, {:.2}]", t_start, t_end);
    println!("   {} primes, {} steps", bank.len(), steps);
    println!();

    let start = Instant::now();
    let minima = bank.find_minima(t_start, t_end, steps, 0.3);
    let elapsed = start.elapsed();

    let dt = (t_end - t_start) / steps as f64;

    println!(
        "    {:>4}  {:>16}  {:>12}  {:>12}  {:>12}  {:>8}",
        "#", "t (refined)", "|Σ| refined", "Z(t)", "Nearest ζ₀", "Quality"
    );
    println!(
        "    {:>4}  {:>16}  {:>12}  {:>12}  {:>12}  {:>8}",
        "────", "────────────────", "────────────", "────────────", "────────────", "────────"
    );

    for (i, &(t_coarse, _n_coarse)) in minima.iter().enumerate() {
        // Golden-section refinement of interference minimum
        let (t_ref, n_ref) = golden_section_min(
            &|t| bank.interference_norm_all(t),
            t_coarse - 2.0 * dt,
            t_coarse + 2.0 * dt,
            1e-12,
        );

        // Cross-validate with Hardy Z-function
        let z_val = hardy_z(t_ref);

        // Find nearest known zero
        let nearest_str = match zeta_zeros::nearest_zero(t_ref) {
            Some((_, z)) if (z - t_ref).abs() < 1.0 => format!("Δ={:.2e}", (z - t_ref).abs()),
            _ => "NEW?".to_string(),
        };

        let star = if n_ref < 0.3 && z_val.abs() < 0.5 {
            "⭐⭐⭐"
        } else if n_ref < 1.0 {
            "⭐⭐ "
        } else if n_ref < 2.0 {
            "⭐  "
        } else {
            "    "
        };

        println!(
            "    {:>4}  {:>16.10}  {:>12.6}  {:>12.6}  {:>12}  {}",
            i + 1,
            t_ref,
            n_ref,
            z_val,
            nearest_str,
            star
        );
    }

    println!();
    println!("  Scanned in {:.2?}", elapsed);
    println!(
        "  N(T) estimate: ~ {:.1} zeros expected in [{:.0}, {:.0}]",
        zeta_zeros::riemann_n_of_t(t_end) - zeta_zeros::riemann_n_of_t(t_start),
        t_start,
        t_end
    );
    println!("  Z(t) = Hardy Z-function (sign change = confirmed zero)");
}
