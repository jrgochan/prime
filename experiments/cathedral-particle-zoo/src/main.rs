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
mod spectral_bands;
mod prime_core;
mod proof_tree;
mod report;
mod output;
mod susy_sectors;

use cathedral_utils::arith;
use cathedral_utils::fmt as cfmt;

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

    /// Run full eigendecomposition and Scenario B band analysis
    #[arg(long)]
    eigendecompose: bool,

    /// MPFR precision in bits for Jacobi eigensolver [default: 128]
    #[arg(long, default_value = "128")]
    precision: u32,

    /// Use Lanczos for partial eigendecomposition (bottom-k eigenvalues)
    /// Set to 0 for full Jacobi decomposition
    #[arg(long, default_value = "0")]
    lanczos_k: usize,

    /// Use GPU (cuSOLVER dsyevd) for eigendecomposition.
    /// Requires --features gpu and CUDA runtime.
    #[arg(long)]
    gpu: bool,

    /// Batch mode: process all gram_N*.h5 files in this directory
    #[arg(long)]
    batch_dir: Option<String>,

    /// Output directory for results [default: results]
    #[arg(long, default_value = "results")]
    output: String,

    /// Run SUSY sector decomposition at given N values.
    /// Decomposes vᵀGv = D(N) + B_off(N) + F_off(N)
    /// matching GaugeCancellation.lean definitions.
    #[arg(long, value_delimiter = ',')]
    susy: Vec<usize>,
}


fn main() {
    let cli = Cli::parse();

    println!("╔══════════════════════════════════════════════════════════════════════╗");
    println!("║     CATHEDRAL PARTICLE ZOO v2                                      ║");
    println!("║     Standard Model ↔ Arithmetic Mapping                            ║");
    println!("║     Gemini Upgrades: Axion · See-Saw · Coupling Constants           ║");
    println!("║     Antigravity: Matrix-Free · Liquid Argon · Dynamic Proof Tree    ║");
    println!("╚══════════════════════════════════════════════════════════════════════╝");

    // ── SUSY Sector Decomposition ──
    if !cli.susy.is_empty() {
        println!();
        println!("  ═══ SUSY SECTOR DECOMPOSITION (GaugeCancellation.lean) ═══");
        println!();
        println!("  Computing vᵀGv = D(N) + B_off(N) + F_off(N)");
        println!("  (This may take a while for N > 200 due to O(N²) Gram entries)");

        let mut results = Vec::new();
        for &n in &cli.susy {
            if n < 3 {
                eprintln!("  Skipping N={} (need N ≥ 3)", n);
                continue;
            }
            let t0 = std::time::Instant::now();
            let sectors = susy_sectors::decompose(n);
            let elapsed = t0.elapsed().as_secs_f64();
            sectors.display();
            println!("  Computed in {:.3}s", elapsed);
            println!();
            results.push(sectors);
        }

        // Summary table if multiple N values
        if results.len() > 1 {
            println!("  ┌────────┬──────────────┬──────────────┬──────────────┬──────────────┬──────────────┐");
            println!("  │   N    │    vᵀGv      │     D(N)     │   B_off(N)   │   F_off(N)   │  gap·ln(N)   │");
            println!("  ├────────┼──────────────┼──────────────┼──────────────┼──────────────┼──────────────┤");
            for s in &results {
                println!("  │ {:>6} │ {:>+12.8} │ {:>+12.8} │ {:>+12.8} │ {:>+12.8} │ {:>12.8} │",
                         s.n, s.vtgv, s.diagonal, s.bosonic_off, s.fermionic_off, s.gap_times_ln);
            }
            println!("  └────────┴──────────────┴──────────────┴──────────────┴──────────────┴──────────────┘");
        }
    }

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
    {
        let mut h5_files: Vec<String> = cli.hpdf.clone();

        // Batch mode: glob gram_N*.h5 in batch_dir
        if let Some(ref dir) = cli.batch_dir {
            if let Ok(entries) = std::fs::read_dir(dir) {
                let mut batch: Vec<String> = entries
                    .filter_map(|e| e.ok())
                    .filter_map(|e| {
                        let name = e.file_name().to_string_lossy().to_string();
                        if name.starts_with("gram_N") && name.ends_with(".h5") {
                            Some(e.path().to_string_lossy().to_string())
                        } else {
                            None
                        }
                    })
                    .collect();
                // Sort by N value
                batch.sort_by_key(|p| {
                    p.split("gram_N").last()
                        .and_then(|s| s.strip_suffix(".h5"))
                        .and_then(|s| s.parse::<usize>().ok())
                        .unwrap_or(0)
                });
                eprintln!("  [Batch] Found {} H5 files in {}", batch.len(), dir);
                h5_files.extend(batch);
            }
        }

        for path in &h5_files {
            analyze_hpdf(path, &cli.output, cli.eigendecompose, cli.precision, cli.lanczos_k, cli.gpu);
        }
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
            let shielded = shield.iter().any(|&p| (n as u64).is_multiple_of(p));
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
fn analyze_hpdf(path: &str, output_dir: &str, eigendecompose: bool, precision: u32, lanczos_k: usize, use_gpu: bool) {
    use cathedral_utils::hpdf::reader::HpdfReader;
    use std::path::Path;

    let t0 = std::time::Instant::now();

    println!();
    cfmt::section(&format!("HPDF SPECTRAL ANALYSIS: {}", path));

    let reader = match HpdfReader::open(Path::new(path)) {
        Ok(r) => r,
        Err(e) => {
            eprintln!("  {}Error opening HPDF file: {}", cfmt::RED, cfmt::RESET);
            eprintln!("  {e}");
            return;
        }
    };

    let n = reader.max_n();
    let dim = reader.dim();
    report::banner(n);

    // ── File Metadata ──
    println!();
    println!("  ┌─────────────────────────────────────────────────────────────────┐");
    println!("  │ HPDF FILE METADATA                                             │");
    println!("  ├─────────────────────────────────────────────────────────────────┤");
    println!("  │ N (max_n)      = {:>10}                                     │", n);
    println!("  │ dim (N-1)      = {:>10}                                     │", dim);
    println!("  │ Version        = {:>10}                                     │", reader.version());
    let has_dd = reader.has_dd();
    let dd_str = if has_dd { "✅ DD (~31 digits)" } else { "f64 only (~16 digits)" };
    println!("  │ Precision      = {}                       │", dd_str);
    if let Ok(prec) = reader.precision() {
        println!("  │ MPFR bits      = {:>10}                                     │", prec);
    }
    println!("  └─────────────────────────────────────────────────────────────────┘");

    // ── Structural Scalars ──
    if let Ok(ss) = reader.read_structural_scalars() {
        println!();
        println!("  ┌─────────────────────────────────────────────────────────────────┐");
        println!("  │ STRUCTURAL INVARIANTS                                           │");
        println!("  ├─────────────────────────────────────────────────────────────────┤");
        println!("  │ Trace         = {:.10}                                  │", ss.trace);
        println!("  │ Frobenius     = {:.10}                                  │", ss.frobenius_norm);
        println!("  │ Condition est = {:.6e}                                  │", ss.condition_estimate);
        println!("  │ Diag range    = [{:.8}, {:.8}]                  │", ss.diag_min, ss.diag_max);
        println!("  │ Off-diag max  = {:.10}                                  │", ss.off_diag_max);
        if let Some(g_min) = ss.gershgorin_lambda_min {
            println!("  │ Gershgorin λ_min = {:.10}                               │", g_min);
        }
        if let Some(g_max) = ss.gershgorin_lambda_max {
            println!("  │ Gershgorin λ_max = {:.10}                               │", g_max);
        }
        println!("  └─────────────────────────────────────────────────────────────────┘");

        // Spectral bounds from Gershgorin (mass gap proxy)
        let lambda_min = ss.gershgorin_lambda_min.unwrap_or(ss.diag_min);
        let lambda_max = ss.gershgorin_lambda_max.unwrap_or(ss.diag_max);

        // Mertens product
        let primes = arith::sieve_primes(n);
        let mertens: f64 = (2..=n)
            .filter(|&p| primes[p])
            .map(|p| 1.0 - 1.0 / p as f64)
            .product();

        // Distance result (d²_N)
        let d2 = reader.read_distance()
            .ok()
            .flatten()
            .map(|d| d.d_squared)
            .unwrap_or(0.0);

        report::spectral_header(lambda_min, lambda_max, d2, ss.trace, mertens);

        // ── Mass Calibration (Gemini's W± anchor) ──
        if lambda_min > 1e-15 {
            let cal = particle_map::MassCalibration::from_spectral_gap(lambda_min);
            println!();
            cfmt::section("MASS CALIBRATION (W± anchor — Gemini)");
            println!("  λ_min (Gershgorin) = {:.8}  →  W± = 80,377 MeV", lambda_min);
            println!("  Scale factor = {:.2} MeV / eigenvalue unit", cal.scale_factor);
            println!("  λ_max = {:.8}  →  {:.2} MeV", lambda_max, cal.to_mev(lambda_max));

            // Predict electron mass from diagonal self-energy
            let electron_pred = cal.to_mev(ss.diag_min);
            println!("  Diag min (e⁻ proxy) = {:.8}  →  {:.2} MeV  (SM: 0.511 MeV)",
                     ss.diag_min, electron_pred);
        }
    }

    // ── RMT on Diagonal (spectral proxy) ──
    if let Ok(diag) = reader.read_diagonal() {
        let mut sorted = diag.clone();
        sorted.sort_by(|a, b| a.partial_cmp(b).unwrap());

        println!();
        cfmt::section(&format!("RANDOM MATRIX THEORY (diagonal proxy, {} values)", sorted.len()));
        let rmt = rmt_analysis::RmtAnalysis::analyze(&sorted);
        rmt.display();
    }

    // ── See-Saw Analysis ──
    let seesaw_result = if let Ok(b_vec) = reader.read_b_vector() {
        let d2 = reader.read_distance()
            .ok()
            .flatten()
            .map(|d| d.d_squared)
            .unwrap_or(0.0);

        // Use diagonal as eigenvalue proxy for see-saw
        if let Ok(diag) = reader.read_diagonal() {
            println!();
            cfmt::section("SEE-SAW MECHANISM (Gemini)");
            let ss = seesaw::SeeSawAnalysis::compute(&diag, &b_vec, d2);
            ss.display();
            Some(ss)
        } else {
            None
        }
    } else {
        None
    };

    // ── DD Precision Report ──
    if has_dd {
        println!();
        cfmt::section("DOUBLE-DOUBLE PRECISION");
        println!("  This file contains DD (hi+lo) data (~31 significant digits)");
        println!("  Matrix size: {}×{} = {:.1} GB (hi) + {:.1} GB (lo)",
                 dim, dim,
                 dim as f64 * (dim as f64 + 1.0) / 2.0 * 8.0 / 1e9,
                 dim as f64 * (dim as f64 + 1.0) / 2.0 * 8.0 / 1e9);
        println!("  Total DD entries: {}", dim * (dim + 1) / 2);
    }

    // ── Number Theory ──
    if let Ok(Some(nt)) = reader.read_number_theory_attrs() {
        println!();
        cfmt::section("NUMBER THEORY");
        if !nt.factorization.is_empty() {
            println!("  Factorization: {}", nt.factorization);
        }
        println!("  Divisor count d(N) = {}", nt.divisor_count);
        println!("  Divisor sum σ(N)   = {}", nt.divisor_sum);
        println!("  Highly composite?  = {}", if nt.is_highly_composite { "✅ YES" } else { "no" });
        println!("  Primes ≤ N         = {}", nt.prime_count);
    }

    // ── Coupling Constants ──
    println!();
    cfmt::section("COUPLING CONSTANTS (Gemini's Formula)");
    let couplings = coupling::ArithmeticCouplings::compute(n, &[]);
    couplings.display();

    // ═══ WRITE OUTPUT FILES ═══
    let result = output::ZooResult::from_hpdf(&reader, &couplings, seesaw_result.as_ref(), None);
    match output::write_all(&result, output_dir) {
        Ok(()) => {
            println!();
            println!("  {}{}═══ OUTPUT COMPLETE ({}) ═══{}", cfmt::BOLD, cfmt::GREEN, cfmt::elapsed(t0.elapsed().as_secs_f64()), cfmt::RESET);
            println!("  {}All files → {}/{}", cfmt::DIM, output_dir, cfmt::RESET);
        }
        Err(e) => {
            eprintln!("  {}Error writing output: {}{}", cfmt::RED, e, cfmt::RESET);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  SCENARIO B: EIGENDECOMPOSITION + BAND ANALYSIS
    // ═══════════════════════════════════════════════════════════════════════
    if eigendecompose {
        println!();
        cfmt::section(&format!("SCENARIO B: EIGENDECOMPOSITION (dim={}, prec={}-bit)", dim, precision));

        // Safety check: dim > 10000 with full Jacobi is very expensive
        if dim > 10000 && lanczos_k == 0 {
            eprintln!("  {}WARNING: Full Jacobi on dim={} will be very slow!{}", cfmt::YELLOW, dim, cfmt::RESET);
            eprintln!("  Consider --lanczos-k 500 for partial decomposition.");
        }

        let t_eigen = std::time::Instant::now();

        // Load the full Gram matrix
        println!("  Loading full Gram matrix ({}×{})...", dim, dim);
        let gram_flat = match reader.read_gram_full() {
            Ok(g) => g,
            Err(e) => {
                eprintln!("  {}Error loading Gram matrix: {}{}", cfmt::RED, e, cfmt::RESET);
                return;
            }
        };
        let mem_mb = (gram_flat.len() * 8) as f64 / 1e6;
        println!("  Loaded {:.1} MB ({} entries)", mem_mb, gram_flat.len());

        let (eigenvalues, eigenvectors) = if use_gpu {
            // ── GPU: cuSOLVER dsyevd (fastest for dim > ~2000) ──
            #[cfg(feature = "gpu")]
            {
                println!("  Running GPU eigendecomposition (cuSOLVER dsyevd)...");
                match cathedral_utils::gpu::eigen::syevd(&gram_flat, dim) {
                    Ok(result) => {
                        println!("  GPU time: {:.3}s", result.gpu_time_secs);
                        // Convert column-major eigenvectors to row-of-Vec format
                        let evecs: Vec<Vec<f64>> = (0..dim).map(|k| {
                            (0..dim).map(|i| result.eigenvectors[k * dim + i]).collect()
                        }).collect();
                        (result.eigenvalues, evecs)
                    }
                    Err(e) => {
                        eprintln!("  {}GPU eigen failed: {}. Falling back to CPU.{}",
                                  cfmt::YELLOW, e, cfmt::RESET);
                        let result = cathedral_utils::eigen::eigen_f64(&gram_flat, dim);
                        (result.eigenvalues, result.eigenvectors)
                    }
                }
            }
            #[cfg(not(feature = "gpu"))]
            {
                eprintln!("  {}GPU not compiled in. Falling back to f64 CPU.{}",
                          cfmt::YELLOW, cfmt::RESET);
                let result = cathedral_utils::eigen::eigen_f64(&gram_flat, dim);
                (result.eigenvalues, result.eigenvectors)
            }
        } else if lanczos_k > 0 {
            // ── PARTIAL: Lanczos (matrix-free, Rayon-parallelized matvec) ──
            println!("  Running Lanczos (bottom-{} eigenvalues, {} threads)...",
                     lanczos_k, rayon::current_num_threads());
            let matvec = |v: &[f64], out: &mut [f64]| {
                use rayon::prelude::*;
                out.par_iter_mut().enumerate().for_each(|(i, yi)| {
                    let row = &gram_flat[i * dim..(i + 1) * dim];
                    *yi = row.iter().zip(v.iter()).map(|(a, b)| a * b).sum();
                });
            };

            let m = (4 * lanczos_k).min(dim);
            let result = cathedral_utils::lanczos::lanczos_bottom_k(&matvec, dim, lanczos_k, m);
            println!("  Lanczos: {} iterations, {} eigenvalues extracted",
                     result.iterations, result.eigenvalues.len());
            if !result.residual_norms.is_empty() {
                let max_res = result.residual_norms.iter().cloned().fold(0.0f64, f64::max);
                println!("  Max residual norm: {:.6e}", max_res);
            }
            (result.eigenvalues, result.eigenvectors)
        } else if precision <= 64 {
            // ── FAST PATH: Native f64 via nalgebra ──
            println!("  Running native f64 eigendecomposition ({} threads)...",
                     rayon::current_num_threads());
            let result = cathedral_utils::eigen::eigen_f64(&gram_flat, dim);
            println!("  λ range: [{:.10e}, {:.10e}]",
                     result.eigenvalues[0],
                     result.eigenvalues.last().unwrap_or(&0.0));
            (result.eigenvalues, result.eigenvectors)
        } else {
            // ── HIGH PRECISION: MPFR Jacobi ──
            println!("  Running MPFR Jacobi ({}-bit precision)...", precision);
            let result = cathedral_utils::jacobi::eigen_jacobi_mpfr(&gram_flat, dim, precision);
            println!("  Jacobi: {} sweeps, off-diag = {:.3e}",
                     result.sweeps, result.final_off_norm);
            println!("  λ range: [{:.10e}, {:.10e}]",
                     result.eigenvalues[0],
                     result.eigenvalues.last().unwrap_or(&0.0));
            (result.eigenvalues, result.eigenvectors)
        };


        let eigen_time = t_eigen.elapsed().as_secs_f64();
        println!("  Eigendecomposition: {} eigenvalues + eigenvectors in {}",
                 eigenvalues.len(), cfmt::elapsed(eigen_time));

        // ── Spectral Band Analysis ──
        println!();
        cfmt::section("ω-CLASS BAND ANALYSIS");
        let band_analysis = spectral_bands::SpectralBandAnalysis::analyze(
            &eigenvalues, &eigenvectors, n
        );
        band_analysis.display();

        // Write band output files
        match spectral_bands::write_bands_tsv(&band_analysis, output_dir) {
            Ok(()) => {
                println!();
                println!("  {}{}═══ BAND ANALYSIS COMPLETE ({}) ═══{}",
                         cfmt::BOLD, cfmt::GREEN,
                         cfmt::elapsed(t0.elapsed().as_secs_f64()), cfmt::RESET);
            }
            Err(e) => {
                eprintln!("  {}Error writing band data: {}{}", cfmt::RED, e, cfmt::RESET);
            }
        }

        // ── Prime Core Conjecture Test ──
        println!();
        cfmt::section("PRIME CORE CONJECTURE TEST");
        let pc_result = prime_core::PrimeCoreResult::test(
            &gram_flat, &eigenvalues, &eigenvectors, n, 10
        );
        pc_result.display();

        // Write prime core results
        match prime_core::write_prime_core_json(&pc_result, output_dir) {
            Ok(()) => {}
            Err(e) => {
                eprintln!("  {}Error writing prime core data: {}{}", cfmt::RED, e, cfmt::RESET);
            }
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
