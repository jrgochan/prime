//! # 🌀 Prime Harmonics Explorer
//!
//! **Computational implementation of Cathedral/Spectral/PrimeHarmonics.lean**
//!
//! Each prime p is a clock hand spinning at frequency log(p)/(2π).
//! At height t on the critical line s = ½ + it:
//!   - Phase:     e^{-it·log(p)}     (unit circle)
//!   - Amplitude: 1/√p               (damping at σ = ½)
//!   - Winding:   t·log(p)/(2π)      (complete rotations)
//!
//! A zeta zero at t₀ is where ALL prime oscillators cancel:
//!   Σ_p (1/√p) · e^{-it₀·log(p)} ≈ 0
//!
//! ## Modes
//!
//! - **Full**: Complete analysis (choir, interference, landscape, predictions)
//! - **Fine scan**: High-resolution scan around a height
//! - **Hunt**: Find zeros in a range with Hardy Z cross-validation
//! - **Portrait**: Phase decomposition at a height
//! - **Sweep**: Energy data output (terminal, CSV, JSON)
//! - **Democracy**: Irrationality of log ratios
//!
//! Run `prime-harmonics --help` for usage.

mod cli;
mod display;
mod modes;

use cathedral_utils::harmonics::PrimeOscillatorBank;
use std::io::Write;
use std::time::Instant;

fn main() {
    let config = cli::parse_args();

    // Hardy Z mode doesn't need primes — skip bank creation
    if let cli::Mode::HardyZ {
        t_start,
        t_end,
        refine,
        hd,
    } = config.mode
    {
        use modes::hardy_z::HdMode;
        let label = match hd {
            HdMode::Off => "Hardy Z Mode",
            HdMode::Fast => "Hardy Z HD Mode (DD arg reduction)",
            HdMode::Full => "Hardy Z HD Full Mode (DD everywhere)",
        };
        eprintln!("🌀 Prime Harmonics Explorer — {}", label);
        eprintln!();
        modes::hardy_z::run(t_start, t_end, refine, hd);
        return;
    }

    // Mirror mode doesn't need primes either — uses zeros to reconstruct
    if let cli::Mode::Mirror { x_max } = config.mode {
        eprintln!("🌀 Prime Harmonics Explorer — Mirror Mode");
        eprintln!();
        modes::mirror::run(x_max);
        return;
    }

    eprintln!("🌀 Prime Harmonics Explorer");
    eprintln!("  Prime limit: {}", config.prime_limit);

    let start = Instant::now();
    let bank = PrimeOscillatorBank::new(config.prime_limit);
    let elapsed = start.elapsed();

    eprintln!("  Sieved {} primes in {:.2?}", bank.len(), elapsed);
    eprintln!();
    std::io::stderr().flush().ok();

    match config.mode {
        cli::Mode::Full { num_zeros } => modes::full::run(&bank, num_zeros),
        cli::Mode::FineScan {
            center,
            window,
            steps,
        } => modes::fine_scan::run(&bank, center, window, steps),
        cli::Mode::Hunt {
            t_start,
            t_end,
            steps,
        } => modes::hunt::run(&bank, t_start, t_end, steps),
        cli::Mode::Portrait {
            height,
            top_primes,
        } => modes::portrait::run(&bank, height, top_primes),
        cli::Mode::Sweep {
            t_start,
            t_end,
            steps,
            ref format,
        } => modes::sweep::run(&bank, t_start, t_end, steps, format),
        cli::Mode::Democracy { count } => modes::democracy::run(&bank, count),
        cli::Mode::Bench => modes::bench::run(&bank),
        cli::Mode::HardyZ { .. } => unreachable!(),
        cli::Mode::Mirror { .. } => unreachable!(),
    }
}
