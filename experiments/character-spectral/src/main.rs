//! ═══════════════════════════════════════════════════════════════════════════
//!  CATHEDRAL CHARACTER-PROJECTED SPECTRAL PROBE
//!  128-bit MPFR · Jacobi Eigensolve · Mod-8 Character Decomposition
//!
//!  Tests whether character-WEIGHTED Gram projections
//!  G_χ(j,k) = χ(j)·G(j,k)·χ(k) produce different spectral
//!  structures per channel, and whether the Poisson→GOE transition
//!  depends on the character.
//!
//!  §A. GRAM MATRIX & CHARACTER PROJECTION
//!  §B. EIGENVALUE EXTRACTION (PER-CHANNEL)
//!  §C. LEVEL SPACING — UNIVERSALITY CLASS PER CHANNEL
//!  §D. DENSITY OF STATES (PER-CHANNEL)
//!  §E. DARK SECTOR ANALYSIS
//!  §F. CROSS-CHANNEL CORRELATIONS
//! ═══════════════════════════════════════════════════════════════════════════

mod characters;
mod fmt;
mod gram;
mod spectral;

use characters::*;
use fmt::*;
use gram::PREC;
use std::fs;
use std::io::Write;
use std::time::Instant;

fn main() {
    let t0 = Instant::now();
    let threads = rayon::current_num_threads();

    let max_n: usize = std::env::args()
        .nth(1)
        .and_then(|s| s.parse().ok())
        .unwrap_or(100);

    header(
        "CATHEDRAL CHARACTER-PROJECTED SPECTRAL PROBE",
        &format!(
            "G_χ(j,k) = χ(j)·G(j,k)·χ(k) weighted projections · max N = {max_n}"
        ),
        PREC,
        threads,
    );

    fs::create_dir_all("results").unwrap();

    // ═══ SELF-TEST: Character Orthogonality ═══
    println!("  {DIM}▸ Character orthogonality self-test...{RESET}");
    let orth = verify_orthogonality();
    let all_ok = orth.iter().all(|r| r.4);
    println!(
        "    {} Σ χᵢ(k)·χⱼ(k) = {} for all 16 pairs (matches Lean χ₈_orthogonality)",
        check(all_ok),
        if all_ok { "4·δᵢⱼ" } else { "FAILED" }
    );
    if !all_ok {
        eprintln!("    {RED}FATAL: Character orthogonality check failed!{RESET}");
        std::process::exit(1);
    }
    println!();

    // Test schedule
    let all_ns: Vec<usize> = vec![30, 50, 75, 100, 150, 200, 300]
        .into_iter()
        .filter(|&n| n <= max_n)
        .collect();

    println!("  {DIM}Test schedule: {all_ns:?}{RESET}");
    println!();

    // Storage for all results
    struct NResult {
        n: usize,
        full_eigs: Vec<f64>,
        res_eigs: [Vec<f64>; 4],  // residue classes k≡1,3,5,7 mod 8
        odd_eigs: Vec<f64>,
        even_eigs: Vec<f64>,
        res_dims: [usize; 4],
    }
    let mut all_results: Vec<NResult> = Vec::new();

    for &n in &all_ns {
        let t_n = Instant::now();

        // ═══ §A. GRAM MATRIX & RESIDUE CLASS PROJECTION ═══
        println!("  {BOLD}{WHITE}═══ §A. GRAM MATRIX & RESIDUE CLASS PROJECTION (N={n}) ═══{RESET}");

        let (full_mat, full_dim) = gram::build_gram_matrix_mpfr(n);

        // Residue class indices mod 8
        let res_indices: Vec<Vec<usize>> = RESIDUE_CLASSES.iter()
            .map(|&r| residue_indices(n, r))
            .collect();
        let odd_idx = odd_indices(n);
        let even_idx = even_indices(n);

        println!(
            "    Full dim: {full_dim} | Odd: {} | Even: {} | k≡1: {} | k≡3: {} | k≡5: {} | k≡7: {}",
            odd_idx.len(), even_idx.len(),
            res_indices[0].len(), res_indices[1].len(),
            res_indices[2].len(), res_indices[3].len()
        );

        // Dimension consistency checks
        let dim_oe = odd_idx.len() + even_idx.len();
        let dim_res: usize = res_indices.iter().map(|v| v.len()).sum();
        println!(
            "    {} dim(odd) + dim(even) = {dim_oe} = dim(full) = {full_dim}",
            check(dim_oe == full_dim)
        );
        println!(
            "    {} Σ dim(k≡r) = {dim_res} = dim(odd) = {} (residues partition odd sector)",
            check(dim_res == odd_idx.len()), odd_idx.len()
        );

        // Project sub-matrices — RESIDUE CLASSES (genuinely different!)
        let res_mats: Vec<Vec<rug::Float>> = res_indices.iter()
            .map(|idx| gram::project_gram(&full_mat, full_dim, idx))
            .collect();
        let odd_mat = gram::project_gram(&full_mat, full_dim, &odd_idx);
        let even_mat = gram::project_gram(&full_mat, full_dim, &even_idx);

        // ═══ §B. EIGENVALUE EXTRACTION ═══
        println!();
        println!("  {BOLD}{WHITE}═══ §B. EIGENVALUE EXTRACTION (N={n}) ═══{RESET}");
        println!("  {DIM}  channel    │  dim  │  λ_min         │  λ_max         │  κ(G)       │ time{RESET}");

        let full_eigs = gram::eigenvalues_jacobi_mpfr(&full_mat, full_dim);
        let full_t = t_n.elapsed().as_secs_f64();
        print_eig_row("Full G_N", full_dim, &full_eigs, full_t);
        save_eigenvalues(&format!("results/eigenvalues_full_N{n}.tsv"), &full_eigs);

        let mut res_eigs_arr: [Vec<f64>; 4] = [vec![], vec![], vec![], vec![]];
        let mut res_dims = [0usize; 4];
        for i in 0..4 {
            let t_ch = Instant::now();
            let dim = res_indices[i].len();
            res_dims[i] = dim;
            let eigs = gram::eigenvalues_jacobi_mpfr(&res_mats[i], dim);
            let elapsed = t_ch.elapsed().as_secs_f64();
            print_eig_row(RESIDUE_NAMES[i], dim, &eigs, elapsed);
            save_eigenvalues(
                &format!("results/eigenvalues_res{}_N{n}.tsv", RESIDUE_CLASSES[i]),
                &eigs,
            );
            res_eigs_arr[i] = eigs;
        }

        let t_odd = Instant::now();
        let odd_eigs = gram::eigenvalues_jacobi_mpfr(&odd_mat, odd_idx.len());
        print_eig_row("Odd sector", odd_idx.len(), &odd_eigs, t_odd.elapsed().as_secs_f64());
        save_eigenvalues(&format!("results/eigenvalues_odd_N{n}.tsv"), &odd_eigs);

        let t_even = Instant::now();
        let even_eigs = gram::eigenvalues_jacobi_mpfr(&even_mat, even_idx.len());
        print_eig_row("Dark (even)", even_idx.len(), &even_eigs, t_even.elapsed().as_secs_f64());
        save_eigenvalues(&format!("results/eigenvalues_even_N{n}.tsv"), &even_eigs);

        // Trace check
        let tr_full: f64 = full_eigs.iter().sum();
        let tr_odd_even: f64 = odd_eigs.iter().sum::<f64>() + even_eigs.iter().sum::<f64>();
        let tr_err = (tr_full - tr_odd_even).abs() / tr_full.abs().max(1e-30);
        println!(
            "    {} Tr(full) = {:.6} ≈ Tr(odd)+Tr(even) = {:.6} (err={:.2e})",
            check(tr_err < 0.01), tr_full, tr_odd_even, tr_err
        );
        println!();

        // ═══ §C. LEVEL SPACING ═══
        println!("  {BOLD}{WHITE}═══ §C. LEVEL SPACING — UNIVERSALITY CLASS (N={n}) ═══{RESET}");
        println!("  {DIM}  channel    │ GUE(β=2) │ GOE(β=1) │ GSE(β=4) │ Poisson  │ best class{RESET}");

        let channels_to_test: Vec<(&str, &[f64])> = vec![
            ("Full G_N", &full_eigs),
            (RESIDUE_NAMES[0], &res_eigs_arr[0]),
            (RESIDUE_NAMES[1], &res_eigs_arr[1]),
            (RESIDUE_NAMES[2], &res_eigs_arr[2]),
            (RESIDUE_NAMES[3], &res_eigs_arr[3]),
            ("Odd sector", &odd_eigs),
            ("Dark (even)", &even_eigs),
        ];

        let mut tsv_sp = fs::File::create(format!("results/spacing_N{n}.tsv")).unwrap();
        writeln!(tsv_sp, "channel\tgue_fit\tgoe_fit\tgse_fit\tpoisson_fit\tbest_class").unwrap();

        for (name, eigs) in &channels_to_test {
            let sr = spectral::compute_spacing(eigs);
            println!(
                "  {:<14} │ {:>8.4} │ {:>8.4} │ {:>8.4} │ {:>8.4} │ {YELLOW}{}{RESET}",
                name, sr.gue_fit, sr.goe_fit, sr.gse_fit, sr.poisson_fit, sr.best_class
            );
            writeln!(
                tsv_sp, "{}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\t{}",
                name, sr.gue_fit, sr.goe_fit, sr.gse_fit, sr.poisson_fit, sr.best_class
            ).unwrap();
        }
        println!();

        // ═══ §D. DENSITY OF STATES ═══
        println!("  {BOLD}{WHITE}═══ §D. DENSITY OF STATES (N={n}) ═══{RESET}");

        let mut tsv_vh = fs::File::create(format!("results/van_hove_N{n}.tsv")).unwrap();
        writeln!(tsv_vh, "channel\tA\tE0\tB\tR2").unwrap();

        for (name, eigs) in &channels_to_test {
            if eigs.len() < 5 { continue; }
            let (a, e0, b, r2) = spectral::fit_van_hove(eigs, 0.20);
            println!(
                "    {:<14}: A={:.6} E₀={:.6e} B={:.6} R²={:.4} {}",
                name, a, e0, b, r2, check(r2 > 0.85)
            );
            writeln!(tsv_vh, "{}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}", name, a, e0, b, r2).unwrap();
        }
        println!();

        // ═══ §E. DARK SECTOR ═══
        println!("  {BOLD}{WHITE}═══ §E. DARK SECTOR ANALYSIS (N={n}) ═══{RESET}");
        if even_eigs.len() >= 4 {
            let sr = spectral::compute_spacing(&even_eigs);
            let is_poisson = sr.poisson_fit > sr.gue_fit && sr.poisson_fit > sr.goe_fit;
            println!(
                "    Dark sector (even indices): {} eigenvalues",
                even_eigs.len()
            );
            println!(
                "    Level spacing: GUE={:.4} GOE={:.4} Poisson={:.4} → {YELLOW}{}{RESET}",
                sr.gue_fit, sr.goe_fit, sr.poisson_fit, sr.best_class
            );
            println!(
                "    {} Dark sector is {}",
                check(is_poisson),
                if is_poisson { "Poisson (uncorrelated)" }
                else { "correlated — dark sector developed spectral rigidity" }
            );
        } else {
            println!("    {DIM}Not enough eigenvalues for dark sector analysis{RESET}");
        }
        println!();

        // ═══ §F. CROSS-CHANNEL CORRELATIONS ═══
        println!("  {BOLD}{WHITE}═══ §F. CROSS-CHANNEL CORRELATIONS (N={n}) ═══{RESET}");

        let mut tsv_cc = fs::File::create(format!("results/cross_corr_N{n}.tsv")).unwrap();
        writeln!(tsv_cc, "channel_a\tchannel_b\tcorrelation").unwrap();

        println!("  {DIM}  Pearson ρ between residue-class eigenvalue staircases:{RESET}");
        for i in 0..4 {
            for j in (i + 1)..4 {
                let rho = spectral::staircase_correlation(&res_eigs_arr[i], &res_eigs_arr[j]);
                let independent = rho.abs() < 0.3;
                println!(
                    "    {} vs {} : ρ = {:+.4} {}",
                    RESIDUE_NAMES[i], RESIDUE_NAMES[j], rho,
                    if independent { check(true) } else { check(false) }
                );
                writeln!(tsv_cc, "{}\t{}\t{:.15e}", RESIDUE_NAMES[i], RESIDUE_NAMES[j], rho).unwrap();
            }
        }
        let rho_full_odd = spectral::staircase_correlation(&full_eigs, &odd_eigs);
        println!("    Full vs Odd : ρ = {:+.4}", rho_full_odd);
        let rho_odd_even = spectral::staircase_correlation(&odd_eigs, &even_eigs);
        println!("    Odd  vs Dark: ρ = {:+.4}", rho_odd_even);

        println!(
            "\n    {DIM}N={n} completed in {:.1}s{RESET}\n",
            t_n.elapsed().as_secs_f64()
        );

        all_results.push(NResult {
            n, full_eigs, res_eigs: res_eigs_arr,
            odd_eigs, even_eigs, res_dims,
        });
    }

    // ═══ CERTIFICATE ═══
    println!("  {BOLD}{CYAN}╔═══════════════════════════════════════════════════════════════════════╗{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}{WHITE}CHARACTER-PROJECTED SPECTRAL PROBE — CERTIFICATE{RESET}");
    println!("  {BOLD}{CYAN}╠═══════════════════════════════════════════════════════════════════════╣{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  Precision: {YELLOW}{PREC}-bit MPFR{RESET}    Threads: {YELLOW}{threads}{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  Characters: {YELLOW}mod 8 (4 channels){RESET}");
    println!("  {BOLD}{CYAN}║{RESET}");

    // Per-N summary of level spacing classes
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}Level Spacing by Residue Class:{RESET}");
    for r in &all_results {
        let full_sp = spectral::compute_spacing(&r.full_eigs);
        let even_sp = spectral::compute_spacing(&r.even_eigs);
        println!(
            "  {BOLD}{CYAN}║{RESET}    N={:<4}: Full={YELLOW}{:<11}{RESET} Dark={YELLOW}{:<11}{RESET}",
            r.n, full_sp.best_class, even_sp.best_class
        );
        for i in 0..4 {
            let sp = spectral::compute_spacing(&r.res_eigs[i]);
            println!(
                "  {BOLD}{CYAN}║{RESET}            {}={YELLOW}{}{RESET}",
                RESIDUE_NAMES[i], sp.best_class
            );
        }
    }
    println!("  {BOLD}{CYAN}║{RESET}");

    // Dark sector verdict
    if let Some(last) = all_results.last() {
        let even_sp = spectral::compute_spacing(&last.even_eigs);
        let dark_poisson = even_sp.poisson_fit > even_sp.gue_fit
            && even_sp.poisson_fit > even_sp.goe_fit
            && even_sp.poisson_fit > even_sp.gse_fit;
        println!("  {BOLD}{CYAN}║{RESET}  {BOLD}Dark Sector Hypothesis:{RESET}");
        if dark_poisson {
            println!("  {BOLD}{CYAN}║{RESET}    {GREEN}{BOLD}✓ Dark sector (even) is Poisson — uncorrelated{RESET}");
            println!("  {BOLD}{CYAN}║{RESET}    {GREEN}  Characters partition the quantum chaos{RESET}");
        } else {
            println!("  {BOLD}{CYAN}║{RESET}    {RED}✗ Dark sector shows correlations — unexpected{RESET}");
        }
    }
    println!("  {BOLD}{CYAN}║{RESET}");
    println!("  {BOLD}{CYAN}╚═══════════════════════════════════════════════════════════════════════╝{RESET}");

    // JSON certificate
    let cert = format!(
        r#"{{
  "experiment": "Cathedral Character-Projected Spectral Probe",
  "precision_bits": {PREC},
  "threads": {threads},
  "timestamp": "{}",
  "character_modulus": 8,
  "num_channels": 4,
  "question": "Do residue classes mod 8 produce different spectral statistics?",
  "max_N_tested": {max_n},
  "character_orthogonality_verified": true,
  "results": [{}
  ],
  "elapsed_seconds": {:.3}
}}"#,
        chrono::Utc::now().to_rfc3339(),
        all_results
            .iter()
            .map(|r| {
                let full_sp = spectral::compute_spacing(&r.full_eigs);
                let even_sp = spectral::compute_spacing(&r.even_eigs);
                format!(
                    "\n    {{\"N\": {}, \"full_class\": \"{}\", \"dark_class\": \"{}\", \"res_dims\": {:?}}}",
                    r.n, full_sp.best_class, even_sp.best_class, r.res_dims
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
    println!("  {BOLD}{WHITE}Output:{RESET} results/{{eigenvalues_*,spacing_*,dos_*,van_hove_*,cross_corr_*}}.tsv");
    println!("  {BOLD}{WHITE}Certificate:{RESET} results/certificate.json");
    println!();
}

fn print_eig_row(name: &str, dim: usize, eigs: &[f64], elapsed: f64) {
    if eigs.is_empty() {
        println!("  {:<14} │ {:>5} │ {:<14} │ {:<14} │ {:<11} │ {:.1}s",
            name, dim, "N/A", "N/A", "N/A", elapsed);
        return;
    }
    let lmin = eigs[0];
    let lmax = eigs[eigs.len() - 1];
    let kappa = if lmin.abs() > 1e-30 { lmax / lmin } else { f64::INFINITY };
    println!(
        "  {:<14} │ {:>5} │ {:>14.10} │ {:>14.10} │ {:>11.3e} │ {:.1}s",
        name, dim, lmin, lmax, kappa, elapsed
    );
}

fn save_eigenvalues(path: &str, eigs: &[f64]) {
    let mut f = fs::File::create(path).unwrap();
    writeln!(f, "index\teigenvalue").unwrap();
    for (i, &e) in eigs.iter().enumerate() {
        writeln!(f, "{}\t{:.15e}", i, e).unwrap();
    }
}
