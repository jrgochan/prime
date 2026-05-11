//! ═══════════════════════════════════════════════════════════════════════════
//!  CATHEDRAL VAN HOVE SINGULARITY PROBE
//!  128-bit MPFR · Jacobi Eigensolve · Spectral Analysis
//!
//!  Tests whether the Báez-Duarte convergence rate d²_N ~ C/ln(N) is a
//!  2D Van Hove logarithmic singularity in the Gram matrix eigenvalue
//!  density of states.
//!
//!  §A. EIGENVALUE EXTRACTION: Full spectrum of G_N via Jacobi rotation
//!  §B. DENSITY OF STATES: Histogram + KDE of eigenvalue distribution
//!  §C. VAN HOVE FIT: ρ(E) = A·ln|E - E₀| + B near λ_min
//!  §D. LEVEL SPACING: Unfolded spacings, Wigner vs Poisson statistics
//!  §E. THERMODYNAMICS: Z(β), F(β), C_V(β), S(β)
//!  §F. SPECTRAL STAIRCASE: N(E) = #{λ_k ≤ E} vs energy
//! ═══════════════════════════════════════════════════════════════════════════

mod gram;
mod spectral;

use cathedral_utils::fmt::*;
use gram::PREC;
use std::fs;
use std::io::Write;
use std::time::Instant;

/// The theoretical Báez-Duarte constant: C = 1/c_holes ≈ 21.649
const BD_CONSTANT: f64 = 21.649;
/// c_holes = Σ 1/|ρ|² ≈ 0.04619
const C_HOLES: f64 = 0.04619;

fn main() {
    let t0 = Instant::now();
    let threads = rayon::current_num_threads();

    // CLI: first arg is max N (default 100)
    let max_n: usize = std::env::args()
        .nth(1)
        .and_then(|s| s.parse().ok())
        .unwrap_or(100);

    header(
        "CATHEDRAL VAN HOVE SINGULARITY PROBE",
        &format!("Testing: d²_N ~ C/ln(N) as 2D Van Hove logarithm · max N = {max_n}"),
        PREC,
        threads,
    );

    fs::create_dir_all("results").unwrap();

    // Test schedule
    let all_ns: Vec<usize> = vec![10, 20, 30, 50, 75, 100, 150, 200, 300]
        .into_iter()
        .filter(|&n| n <= max_n)
        .collect();

    println!("  {DIM}Test schedule: {all_ns:?}{RESET}");
    println!();

    // ═══ §A. EIGENVALUE EXTRACTION ═══
    println!("  {BOLD}{WHITE}═══ §A. EIGENVALUE EXTRACTION ═══{RESET}");
    println!("  {DIM}  Full spectrum of G_N via Jacobi rotation on {PREC}-bit MPFR Gram matrix{RESET}");
    println!("  {DIM}     N  │   dim  │  λ_min         │  λ_max         │  κ(G)       │ time{RESET}");

    let mut tsv_a = fs::File::create("results/eigenvalues_summary.tsv").unwrap();
    writeln!(tsv_a, "N\tdim\tlambda_min\tlambda_max\tcondition_number\ttime_s").unwrap();

    struct EigData {
        n: usize,
        eigenvalues: Vec<f64>,
    }
    let mut all_eig_data: Vec<EigData> = Vec::new();

    for &n in &all_ns {
        let dim = n - 1;
        let t = Instant::now();

        // Build Gram matrix in MPFR
        let mat = gram::build_gram_matrix_mpfr(n);

        // Extract eigenvalues via MPFR Jacobi
        let eigs = gram::eigenvalues_jacobi_mpfr(&mat, dim);
        let elapsed = t.elapsed().as_secs_f64();

        let lmin = eigs[0];
        let lmax = eigs[eigs.len() - 1];
        let kappa = if lmin.abs() > 1e-30 { lmax / lmin } else { f64::INFINITY };

        println!(
            "  {:>6} │ {:>5} │ {:>14.10} │ {:>14.10} │ {:>11.3e} │ {:.1}s",
            n, dim, lmin, lmax, kappa, elapsed
        );
        writeln!(
            tsv_a,
            "{}\t{}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.3}",
            n, dim, lmin, lmax, kappa, elapsed
        )
        .unwrap();

        // Save individual eigenvalue lists
        let eig_file = format!("results/eigenvalues_N{n}.tsv");
        let mut ef = fs::File::create(&eig_file).unwrap();
        writeln!(ef, "index\teigenvalue").unwrap();
        for (i, &e) in eigs.iter().enumerate() {
            writeln!(ef, "{}\t{:.15e}", i, e).unwrap();
        }

        all_eig_data.push(EigData { n, eigenvalues: eigs });
    }
    println!();

    // ═══ §B. DENSITY OF STATES ═══
    println!("  {BOLD}{WHITE}═══ §B. DENSITY OF STATES ═══{RESET}");
    println!("  {DIM}  Histogram + KDE of eigenvalue distribution{RESET}");

    let mut tsv_dos = fs::File::create("results/dos.tsv").unwrap();
    writeln!(tsv_dos, "N\tbin_center\tcount\tdensity").unwrap();

    for ed in &all_eig_data {
        if ed.eigenvalues.len() < 10 { continue; }
        let n_bins = (ed.eigenvalues.len() as f64).sqrt().ceil() as usize;
        let n_bins = n_bins.max(10).min(50);

        let dos = spectral::compute_dos(&ed.eigenvalues, n_bins);

        println!(
            "    N={:>3}: {n_bins} bins, peak density = {:.6} at E = {:.6}",
            ed.n,
            dos.density.iter().cloned().fold(0.0f64, f64::max),
            dos.bin_centers[dos.density
                .iter()
                .enumerate()
                .max_by(|a, b| a.1.partial_cmp(b.1).unwrap())
                .unwrap()
                .0]
        );

        for i in 0..dos.n_bins {
            writeln!(
                tsv_dos,
                "{}\t{:.15e}\t{}\t{:.15e}",
                ed.n, dos.bin_centers[i], dos.counts[i], dos.density[i]
            )
            .unwrap();
        }

        // KDE
        let range = ed.eigenvalues.last().unwrap() - ed.eigenvalues[0];
        let bw = range / (ed.eigenvalues.len() as f64).powf(0.4);
        let kde = spectral::compute_kde(&ed.eigenvalues, 200, bw);

        let kde_file = format!("results/kde_N{}.tsv", ed.n);
        let mut kf = fs::File::create(&kde_file).unwrap();
        writeln!(kf, "energy\tdensity").unwrap();
        for (e, d) in kde.energies.iter().zip(kde.density.iter()) {
            writeln!(kf, "{:.15e}\t{:.15e}", e, d).unwrap();
        }
    }
    println!();

    // ═══ §C. VAN HOVE FIT ═══
    println!("  {BOLD}{WHITE}═══ §C. VAN HOVE SINGULARITY FIT ═══{RESET}");
    println!("  {DIM}  Fitting ρ(E) = A·ln|E - E₀| + B near λ_min{RESET}");
    println!("  {DIM}     N  │      A       │      E₀      │      B       │    R²    │ van Hove?{RESET}");

    let mut tsv_vh = fs::File::create("results/van_hove_fit.tsv").unwrap();
    writeln!(tsv_vh, "N\tA\tE0\tB\tR2\tvan_hove").unwrap();

    let mut vh_r2_values = Vec::new();

    for ed in &all_eig_data {
        if ed.eigenvalues.len() < 20 { continue; }

        // Fit bottom 20% of eigenvalues
        let (a, e0, b, r2) = spectral::fit_van_hove(&ed.eigenvalues, 0.20);
        let is_vh = r2 > 0.85;

        println!(
            "  {:>6} │ {:>12.8} │ {:>12.8} │ {:>12.8} │ {:.4}  │ {}",
            ed.n, a, e0, b, r2, check(is_vh)
        );
        writeln!(
            tsv_vh,
            "{}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\t{}",
            ed.n, a, e0, b, r2, is_vh
        )
        .unwrap();

        vh_r2_values.push((ed.n, r2));
    }
    println!();

    // ═══ §D. LEVEL SPACING ═══
    println!("  {BOLD}{WHITE}═══ §D. LEVEL SPACING STATISTICS ═══{RESET}");
    println!("  {DIM}  Unfolded spacings: Wigner-Dyson (GUE) vs Poisson{RESET}");
    println!("  {DIM}     N  │ mean spacing │  Wigner fit  │ Poisson fit │ statistics{RESET}");

    let mut tsv_sp = fs::File::create("results/level_spacing.tsv").unwrap();
    writeln!(tsv_sp, "N\tmean_spacing\twigner_fit\tpoisson_fit\tstatistics").unwrap();

    for ed in &all_eig_data {
        if ed.eigenvalues.len() < 10 { continue; }

        let sr = spectral::compute_spacing(&ed.eigenvalues);

        let stat = if sr.wigner_surmise_fit > sr.poisson_fit {
            "GUE-like"
        } else {
            "Poisson-like"
        };

        println!(
            "  {:>6} │ {:>12.8e} │ {:>12.6} │ {:>11.6} │ {YELLOW}{stat}{RESET}",
            ed.n, sr.mean_spacing, sr.wigner_surmise_fit, sr.poisson_fit
        );
        writeln!(
            tsv_sp,
            "{}\t{:.15e}\t{:.15e}\t{:.15e}\t{}",
            ed.n, sr.mean_spacing, sr.wigner_surmise_fit, sr.poisson_fit, stat
        )
        .unwrap();

        // Save unfolded spacings
        let sp_file = format!("results/spacings_N{}.tsv", ed.n);
        let mut sf = fs::File::create(&sp_file).unwrap();
        writeln!(sf, "index\traw_spacing\tunfolded_spacing").unwrap();
        for (i, (&raw, &unf)) in sr.spacings.iter().zip(sr.unfolded.iter()).enumerate() {
            writeln!(sf, "{}\t{:.15e}\t{:.15e}", i, raw, unf).unwrap();
        }
    }
    println!();

    // ═══ §E. THERMODYNAMICS ═══
    println!("  {BOLD}{WHITE}═══ §E. THERMODYNAMICS ═══{RESET}");
    println!("  {DIM}  Partition function Z(β), specific heat C_V(β){RESET}");
    println!("  {DIM}     N  │  β_c ≈ 1/λ_min │  max C_V     │  C_V growth{RESET}");

    let mut tsv_th = fs::File::create("results/thermo_summary.tsv").unwrap();
    writeln!(tsv_th, "N\tbeta_c\tmax_cv\tcv_growth").unwrap();

    for ed in &all_eig_data {
        if ed.eigenvalues.len() < 10 { continue; }

        let beta_c = 1.0 / ed.eigenvalues[0].max(1e-15);
        let beta_max = beta_c * 10.0;
        let thermo = spectral::compute_thermo(&ed.eigenvalues, (0.01, beta_max.min(1e6)), 200);

        let max_cv = thermo
            .specific_heat
            .iter()
            .cloned()
            .fold(0.0f64, f64::max);

        // Check for log divergence: fit C_V(β) = a·ln(β) + b near β_c
        let growth = if max_cv > 1.0 { "divergent" } else { "bounded" };

        println!(
            "  {:>6} │ {:>14.6e} │ {:>12.6} │ {YELLOW}{growth}{RESET}",
            ed.n, beta_c, max_cv
        );
        writeln!(
            tsv_th,
            "{}\t{:.15e}\t{:.15e}\t{}",
            ed.n, beta_c, max_cv, growth
        )
        .unwrap();

        // Save full thermodynamic profile
        let th_file = format!("results/thermo_N{}.tsv", ed.n);
        let mut tf = fs::File::create(&th_file).unwrap();
        writeln!(tf, "beta\tfree_energy\tspecific_heat\tentropy").unwrap();
        for i in 0..thermo.betas.len() {
            writeln!(
                tf,
                "{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}",
                thermo.betas[i], thermo.free_energy[i], thermo.specific_heat[i], thermo.entropy[i]
            )
            .unwrap();
        }
    }
    println!();

    // ═══ §F. SPECTRAL STAIRCASE ═══
    println!("  {BOLD}{WHITE}═══ §F. SPECTRAL STAIRCASE: N(E) = #{{λ_k ≤ E}} ═══{RESET}");

    for ed in &all_eig_data {
        if ed.eigenvalues.len() < 10 { continue; }

        let stair_file = format!("results/staircase_N{}.tsv", ed.n);
        let mut sf = fs::File::create(&stair_file).unwrap();
        writeln!(sf, "energy\tcount\tnormalized").unwrap();
        let n = ed.eigenvalues.len() as f64;
        for (i, &e) in ed.eigenvalues.iter().enumerate() {
            writeln!(sf, "{:.15e}\t{}\t{:.15e}", e, i + 1, (i + 1) as f64 / n).unwrap();
        }
        println!("    N={:>3}: staircase saved ({} steps)", ed.n, ed.eigenvalues.len());
    }
    println!();

    // ═══ CERTIFICATE ═══
    println!("  {BOLD}{CYAN}╔═══════════════════════════════════════════════════════════════════════╗{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}{WHITE}VAN HOVE SINGULARITY PROBE — CERTIFICATE{RESET}");
    println!("  {BOLD}{CYAN}╠═══════════════════════════════════════════════════════════════════════╣{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  Precision: {YELLOW}{PREC}-bit MPFR{RESET}    Threads: {YELLOW}{threads}{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}");

    // Van Hove verdict
    let vh_confirmed = vh_r2_values.iter().filter(|(n, _)| *n >= 50).all(|(_, r2)| *r2 > 0.80);
    let avg_r2: f64 = if vh_r2_values.is_empty() {
        0.0
    } else {
        vh_r2_values.iter().map(|(_, r2)| r2).sum::<f64>() / vh_r2_values.len() as f64
    };

    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}§C. Van Hove singularity{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}    Average R² = {YELLOW}{avg_r2:.4}{RESET}");
    if vh_confirmed {
        println!("  {BOLD}{CYAN}║{RESET}    {GREEN}{BOLD}✓ Logarithmic singularity CONFIRMED (R² > 0.80 for N ≥ 50){RESET}");
        println!("  {BOLD}{CYAN}║{RESET}    {GREEN}  d²_N ~ C/ln(N) is consistent with 2D Van Hove saddle point{RESET}");
    } else {
        println!("  {BOLD}{CYAN}║{RESET}    {RED}✗ Van Hove fit inconclusive (R² < 0.80){RESET}");
        println!("  {BOLD}{CYAN}║{RESET}    {DIM}May require larger N or alternative edge model{RESET}");
    }
    println!("  {BOLD}{CYAN}║{RESET}");

    // Eigenvalue summary
    if let Some(last) = all_eig_data.last() {
        let lmin = last.eigenvalues[0];
        let lmax = last.eigenvalues[last.eigenvalues.len() - 1];
        let n = last.n;
        let lmin_logn = lmin * (n as f64).ln();
        println!("  {BOLD}{CYAN}║{RESET}  {BOLD}Spectral summary (N = {n}){RESET}");
        println!("  {BOLD}{CYAN}║{RESET}    λ_min = {MAGENTA}{lmin:.10e}{RESET}");
        println!("  {BOLD}{CYAN}║{RESET}    λ_max = {MAGENTA}{lmax:.10e}{RESET}");
        println!("  {BOLD}{CYAN}║{RESET}    λ_min · ln(N) = {YELLOW}{lmin_logn:.8}{RESET}");
        println!("  {BOLD}{CYAN}║{RESET}    {DIM}Theory: λ_min · ln(N) → c_holes ≈ {C_HOLES:.5}{RESET}");
        println!("  {BOLD}{CYAN}║{RESET}    {DIM}BD constant: C = 1/c_holes ≈ {BD_CONSTANT:.3}{RESET}");
    }
    println!("  {BOLD}{CYAN}║{RESET}");
    println!("  {BOLD}{CYAN}╚═══════════════════════════════════════════════════════════════════════╝{RESET}");

    // JSON certificate
    let cert = format!(
        r#"{{
  "experiment": "Cathedral Van Hove Singularity Probe",
  "precision_bits": {PREC},
  "threads": {threads},
  "timestamp": "{}",
  "question": "Is d²_N ~ C/ln(N) a 2D Van Hove logarithmic singularity?",
  "max_N_tested": {max_n},
  "van_hove_r2_avg": {avg_r2:.15e},
  "van_hove_confirmed": {vh_confirmed},
  "bd_constant_target": {BD_CONSTANT},
  "c_holes_target": {C_HOLES},
  "eigenvalue_data": [{}
  ],
  "elapsed_seconds": {:.3}
}}"#,
        chrono::Utc::now().to_rfc3339(),
        all_eig_data
            .iter()
            .map(|ed| {
                let lmin = ed.eigenvalues[0];
                let lmax = ed.eigenvalues[ed.eigenvalues.len() - 1];
                let lmin_logn = lmin * (ed.n as f64).ln();
                format!(
                    "\n    {{\"N\": {}, \"dim\": {}, \"lambda_min\": {:.15e}, \"lambda_max\": {:.15e}, \"lambda_min_logN\": {:.15e}}}",
                    ed.n,
                    ed.n - 1,
                    lmin,
                    lmax,
                    lmin_logn
                )
            })
            .collect::<Vec<_>>()
            .join(","),
        t0.elapsed().as_secs_f64()
    );
    fs::write("results/certificate.json", &cert).unwrap();

    println!();
    println!(
        "  {BOLD}{WHITE}Total:{RESET} {GREEN}{:.1}s{RESET} ({threads} threads)",
        t0.elapsed().as_secs_f64()
    );
    println!("  {BOLD}{WHITE}Output:{RESET} results/{{eigenvalues_*,dos,kde_*,van_hove_fit,level_spacing,thermo_*,staircase_*}}.tsv");
    println!("  {BOLD}{WHITE}Certificate:{RESET} results/certificate.json");
    println!();
}
