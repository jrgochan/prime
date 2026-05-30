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

    // Eta mode — complete winding analysis, no primes needed
    if let cli::Mode::Eta { n_max, num_zeros, verbose } = config.mode {
        modes::eta::run(n_max, num_zeros, verbose);
        return;
    }

    // Anomaly mode — Bridge 2: Δ = G - R perturbation analysis
    if let cli::Mode::Anomaly { n_max } = config.mode {
        modes::anomaly::run(n_max);
        return;
    }

    // Dyson mode — The Nuclear Option
    if let cli::Mode::Dyson { n_max } = config.mode {
        modes::dyson::run(n_max);
        return;
    }

    // Confinement mode — Strong coupling table from HPDF files
    if let cli::Mode::Confinement { ref h5_dir } = config.mode {
        modes::confinement::run(h5_dir);
        return;
    }

    // Scaling mode — Dense d²_opt sweep from HPDF
    if let cli::Mode::Scaling { ref h5_dir, max_n } = config.mode {
        modes::scaling::run(h5_dir, max_n);
        return;
    }

    // Scaling v2 — Incremental Cholesky (O(N²) per step)
    if let cli::Mode::ScalingV2 { ref h5_dir, max_n } = config.mode {
        modes::scaling_v2::run(h5_dir, max_n);
        return;
    }

    // Scaling v3 — Incremental Cholesky, on-the-fly Gram (no H5)
    if let cli::Mode::ScalingV3 { max_n } = config.mode {
        modes::scaling_v3::run(max_n);
        return;
    }

    // Scaling v4 — Incremental Cholesky from OOC mmap'd Gram
    if let cli::Mode::ScalingV4 { ref ooc_path, max_n } = config.mode {
        modes::scaling_v4::run(ooc_path, max_n);
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
        cli::Mode::Eta { .. } => unreachable!(),
        cli::Mode::Anomaly { .. } => unreachable!(),
        cli::Mode::Dyson { .. } => unreachable!(),
        cli::Mode::Confinement { .. } => unreachable!(),
        cli::Mode::Scaling { .. } => unreachable!(),
        cli::Mode::ScalingV2 { .. } => unreachable!(),
        cli::Mode::ScalingV3 { .. } => unreachable!(),
        cli::Mode::ScalingV4 { .. } => unreachable!(),
    }
}
