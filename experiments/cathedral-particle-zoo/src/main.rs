//! Cathedral Particle Zoo v2 — CLI Entry Point
//!
//! Maps Standard Model particles to arithmetic observables in Gram matrix H5 files.
//!
//! ```
//! cathedral-particle-zoo --hpdf experiments/cache/hpdf/gram_N2520.h5
//! cathedral-particle-zoo --coeffs experiments/cache/unconstrained_coeffs_N20000.tsv
//! cathedral-particle-zoo --proof-tree
//! ```

use clap::Parser;
use std::fs;

mod particle_map;
mod rmt_analysis;
mod generation_scan;
mod coupling;
mod seesaw;
mod proof_tree;
mod report;

use cathedral_utils::arith;

#[derive(Parser, Debug)]
#[command(name = "cathedral-particle-zoo")]
#[command(about = "Cathedral Particle Zoo v2 — Standard Model ↔ Arithmetic Mapping")]
#[command(version = "2.0.0")]
struct Cli {
    /// Path to coefficient TSV files (index\tcoefficient)
    #[arg(long)]
    coeffs: Vec<String>,

    /// Path to HPDF H5 files for spectral analysis
    #[cfg(feature = "hpdf")]
    #[arg(long)]
    hpdf: Vec<String>,

    /// Display the proof tree ↔ physics bridge
    #[arg(long)]
    proof_tree: bool,

    /// Display the full Standard Model particle table
    #[arg(long)]
    particles: bool,

    /// Dark sector shield: zero out indices sharing these prime factors
    /// (Antigravity's Liquid Argon Shield)
    #[arg(long, value_delimiter = ',')]
    shield: Vec<u64>,
}

fn main() {
    let cli = Cli::parse();

    println!("╔══════════════════════════════════════════════════════════════════════╗");
    println!("║     CATHEDRAL PARTICLE ZOO v2                                      ║");
    println!("║     Standard Model ↔ Arithmetic Mapping                            ║");
    println!("║     Gemini Upgrades: Axion · See-Saw · Coupling Constants           ║");
    println!("║     Antigravity: Matrix-Free · Liquid Argon · Dynamic Proof Tree    ║");
    println!("╚══════════════════════════════════════════════════════════════════════╝");

    // ── Proof Tree Display ──
    if cli.proof_tree {
        println!();
        proof_tree::display_proof_tree();
    }

    // ── Particle Table Display ──
    if cli.particles {
        println!();
        display_particle_table();
    }

    // ── Coefficient File Analysis ──
    for path in &cli.coeffs {
        if let Ok(contents) = fs::read_to_string(path) {
            let coeffs = parse_coefficients(&contents);
            if coeffs.is_empty() {
                eprintln!("  Warning: {} is empty", path);
                continue;
            }
            let n_max = coeffs.last().map(|(i, _)| *i).unwrap_or(0);
            analyze_coefficients(path, &coeffs, n_max, &cli.shield);
        } else {
            eprintln!("  Error: cannot read {}", path);
        }
    }

    // ── HPDF H5 File Analysis ──
    #[cfg(feature = "hpdf")]
    for path in &cli.hpdf {
        analyze_hpdf(path);
    }

    if cli.coeffs.is_empty() && cli.proof_tree && !cli.particles {
        println!();
        println!("  Tip: use --coeffs <FILE> to analyze coefficient data");
        println!("       use --hpdf <FILE> for H5 spectral analysis");
        println!("       use --particles to see the full SM table");
    }
}

fn parse_coefficients(contents: &str) -> Vec<(usize, f64)> {
    let mut coeffs = Vec::new();
    for line in contents.lines() {
        let line = line.trim();
        if line.is_empty() || line.starts_with('#') { continue; }
        let parts: Vec<&str> = line.split('\t').collect();
        if parts.len() >= 2 {
            if let (Ok(idx), Ok(val)) = (parts[0].parse::<usize>(), parts[1].parse::<f64>()) {
                coeffs.push((idx, val));
            }
        }
    }
    coeffs
}

fn analyze_coefficients(label: &str, coeffs: &[(usize, f64)], n_max: usize, shield: &[u64]) {
    report::banner(n_max);

    // Build b-vector
    let b = arith::b_vector(coeffs.len());

    // Apply dark sector shield if requested (Antigravity's Liquid Argon)
    let effective_coeffs: Vec<(usize, f64)> = if shield.is_empty() {
        coeffs.to_vec()
    } else {
        coeffs.iter().map(|&(n, a)| {
            let shielded = shield.iter().any(|&p| n as u64 % p == 0);
            if shielded { (n, 0.0) } else { (n, a) }
        }).collect()
    };

    if !shield.is_empty() {
        println!();
        println!("  🧊 LIQUID ARGON SHIELD ACTIVE: zeroed indices divisible by {:?}", shield);
        println!("     Exposing the DARK SECTOR (weakly interacting particles only)");
    }

    // ── Generation Scan ──
    println!();
    println!("  ═══ GENERATION DECOMPOSITION ═══");
    let gen_scan = generation_scan::GenerationScan::analyze(&effective_coeffs, &b, n_max);
    gen_scan.display();

    // ── Coupling Constants ──
    println!();
    println!("  ═══ COUPLING CONSTANTS (Gemini's Formula) ═══");
    let couplings = coupling::ArithmeticCouplings::compute(n_max, &effective_coeffs);
    couplings.display();

    // ── See-Saw (placeholder — needs eigenvalues) ──
    println!();
    println!("  ═══ SEE-SAW MECHANISM ═══");
    let d2 = 1.0 - gen_scan.total_energy;
    println!("  d²_N = 1 - E = {:.10}  (neutrino mass sum analog)", d2);
    println!("  Full see-saw analysis requires eigenvalues (use --hpdf)");

    // ── Mass Ratios ──
    println!();
    println!("  ═══ MASS RATIO PREDICTIONS vs SM ═══");
    println!("  ┌──────────────┬──────────┬──────────┬──────────┐");
    println!("  │ Ratio        │  SM      │ Cathedral│ Match?   │");
    println!("  ├──────────────┼──────────┼──────────┼──────────┤");

    if gen_scan.generations.len() >= 2 {
        let e2_e1 = gen_scan.generations[1].mass_ratio;
        println!("  │ E₂/E₁        │  varies  │ {:8.4} │          │", e2_e1);
    }
    if gen_scan.generations.len() >= 3 {
        let e3_e1 = gen_scan.generations[2].mass_ratio;
        println!("  │ E₃/E₁        │  varies  │ {:8.4} │          │", e3_e1);
    }
    for (name, sm_val) in particle_map::MassCalibration::key_ratios() {
        println!("  │ {:12} │ {:8.2} │    ---   │          │", name, sm_val);
    }
    println!("  └──────────────┴──────────┴──────────┴──────────┘");

    println!();
    println!("  Source: {}", label);
}

#[cfg(feature = "hpdf")]
fn analyze_hpdf(path: &str) {
    use hdf5::File as H5File;

    println!();
    println!("  ═══ HPDF SPECTRAL ANALYSIS: {} ═══", path);

    match H5File::open(path) {
        Ok(file) => {
            // Infer N from b_vector dimension (dim = N-1, so N = dim+1)
            let n: usize = file.dataset("b_vector")
                .map(|d| d.shape()[0] + 1)
                .or_else(|_| file.group("gram")
                    .and_then(|g| g.dataset("upper_triangle"))
                    .map(|d| {
                        // upper_triangle has dim*(dim+1)/2 entries, dim = N-1
                        let len = d.shape()[0];
                        // dim = (-1 + sqrt(1 + 8*len)) / 2
                        let dim = ((-1.0 + (1.0 + 8.0 * len as f64).sqrt()) / 2.0) as usize;
                        dim + 1
                    }))
                .unwrap_or(0);

            if n == 0 {
                eprintln!("  Cannot determine N from H5 file");
                return;
            }
            report::banner(n);

            // Try to read eigenvalues from various possible locations
            let eigenvalues = file.dataset("eigenvalues")
                .or_else(|_| file.dataset("spectral/eigenvalues"))
                .and_then(|d| d.read_1d::<f64>())
                .map(|a| a.to_vec())
                .ok();

            // Fall back to diagonal as spectral proxy
            let diagonal = file.dataset("structure/diagonal")
                .and_then(|d| d.read_1d::<f64>())
                .map(|a| a.to_vec())
                .ok();

            let spectral_data = eigenvalues.or(diagonal);

            if let Some(ref data) = spectral_data {
                let mut sorted = data.clone();
                sorted.sort_by(|a, b| a.partial_cmp(b).unwrap());

                // RMT Analysis
                println!();
                println!("  ═══ RANDOM MATRIX THEORY ═══");
                let rmt = rmt_analysis::RmtAnalysis::analyze(&sorted);
                rmt.display();

                let lambda_min = sorted[0];
                let lambda_max = sorted[sorted.len() - 1];

                // Mertens product
                let primes = arith::sieve_primes(n);
                let mertens: f64 = (2..=n)
                    .filter(|&p| primes[p])
                    .map(|p| 1.0 - 1.0 / p as f64)
                    .product();

                report::spectral_header(lambda_min, lambda_max, 0.0, 0.0, mertens);

                // Mass calibration (Gemini's W± anchor)
                if lambda_min > 1e-15 {
                    let cal = particle_map::MassCalibration::from_spectral_gap(lambda_min);
                    println!();
                    println!("  ═══ MASS CALIBRATION (W± anchor — Gemini) ═══");
                    println!("  λ_min = {:.8}  →  W± = 80,377 MeV", lambda_min);
                    println!("  Scale factor = {:.2} MeV / eigenvalue unit", cal.scale_factor);

                    // What mass does the SECOND eigenvalue predict?
                    if sorted.len() > 1 {
                        println!("  λ₂ = {:.8}  →  {:.2} MeV", sorted[1], cal.to_mev(sorted[1]));
                    }
                }
            } else {
                println!("  No eigenvalues dataset in H5. Run eigendecomposition first.");
                println!("  Matrix available: {}", file.dataset("gram_matrix").is_ok());
            }
        }
        Err(e) => {
            eprintln!("  Error opening {}: {}", path, e);
        }
    }
}


fn display_particle_table() {
    let particles = particle_map::standard_model_particles();
    println!("  ┌──────────────┬────────┬──────────────┬──────────────────────────────────────────┐");
    println!("  │ Particle     │ Symbol │  Mass (MeV)  │ Cathedral Dual                           │");
    println!("  ├──────────────┼────────┼──────────────┼──────────────────────────────────────────┤");
    for p in &particles {
        let mass_str = if p.mass_mev < 0.001 {
            format!("{:.2e}", p.mass_mev)
        } else if p.mass_mev < 1.0 {
            format!("{:.6}", p.mass_mev)
        } else {
            format!("{:.1}", p.mass_mev)
        };
        println!("  │ {:12} │ {:6} │ {:>12} │ {:40} │",
                 p.name, p.symbol, mass_str,
                 &p.cathedral_dual[..p.cathedral_dual.len().min(40)]);
    }
    println!("  └──────────────┴────────┴──────────────┴──────────────────────────────────────────┘");
}
