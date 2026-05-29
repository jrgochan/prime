//! Phase portrait mode — detailed prime-by-prime decomposition at a height.

use cathedral_utils::harmonics::PrimeOscillatorBank;
use crate::display;

pub fn run(bank: &PrimeOscillatorBank, height: f64, top_primes: usize) {
    let n = top_primes.min(bank.len());
    println!("🌀 PHASE PORTRAIT at t = {:.10}", height);
    println!("   Showing {} primes' oscillator phases", n);
    println!();

    let portrait = bank.phase_portrait(height, n);

    println!("    {:>6}  {:>10}  {:>12}  {:>12}  {:>3}  {:>12}  {:>12}",
        "Prime", "1/√p", "Winding", "Frac.Wind", "Dir", "Cumul |Σ|", "Δ|Σ|");
    println!("    {:>6}  {:>10}  {:>12}  {:>12}  {:>3}  {:>12}  {:>12}",
        "──────", "──────────", "────────────", "────────────", "───", "────────────", "────────────");

    for pp in &portrait {
        let arrow = display::phase_arrow(pp.phase_re, pp.phase_im);
        println!("    {:>6}  {:>10.6}  {:>12.4}  {:>12.6}   {}   {:>12.6}  {:>+12.6}",
            pp.p, pp.amplitude, pp.winding, pp.frac_winding, arrow,
            pp.cumulative_norm, pp.delta_norm);
    }

    println!();
    if let Some(last) = portrait.last() {
        println!("    Final |Σ| = {:.10}", last.cumulative_norm);
        let max_possible = bank.max_interference(n);
        println!("    Max possible (t=0): {:.6}", max_possible);
        println!("    Cancellation ratio: {:.4}%",
            (1.0 - last.cumulative_norm / max_possible) * 100.0);
    }
}
