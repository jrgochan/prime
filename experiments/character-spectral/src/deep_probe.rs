//! ═══════════════════════════════════════════════════════════════════════════
//!  EXPERIMENTS B+C: Dark Sector Critical Sweep + Eigenvector Localization
//!
//!  B: Fine-grained sweep of N=60..250 in steps of 2, tracking the exact
//!     GOE fit curve for the Dark Sector. Extracts the phase transition
//!     shape: smooth crossover vs sharp step function.
//!
//!  C: Eigenvector localization analysis — do eigenvectors "scar" onto
//!     specific residue classes? Measures participation ratio of the
//!     ground state and bulk eigenvectors across mod-8 classes.
//!
//!  Usage: deep-probe [max_N]
//! ═══════════════════════════════════════════════════════════════════════════

mod spectral;

use cathedral_utils::fmt::*;
use std::time::Instant;

use cathedral_utils::gram::{build_gram_matrix_f64};

fn project_f64(full_mat: &[f64], full_dim: usize, indices: &[usize]) -> Vec<f64> {
    let sub_dim = indices.len();
    let mut sub = vec![0.0f64; sub_dim * sub_dim];
    for (si, &ki) in indices.iter().enumerate() {
        let ri = ki - 2;
        for (sj, &kj) in indices.iter().enumerate() {
            let rj = kj - 2;
            sub[si * sub_dim + sj] = full_mat[ri * full_dim + rj];
        }
    }
    sub
}

// ═══════════════════════════════════════════════════════════════════════
// EXPERIMENT B: DARK SECTOR CRITICAL SWEEP
// ═══════════════════════════════════════════════════════════════════════

fn experiment_b_dark_sector_sweep() {
    println!("\n  {BOLD}{CYAN}╔═══════════════════════════════════════════════════════════════════════╗{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}{WHITE}EXPERIMENT B: DARK SECTOR CRITICAL SWEEP{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {DIM}N = 60..250 step 2 · tracking GOE fit of even-sector{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {DIM}Question: smooth crossover or sharp phase transition?{RESET}");
    println!("  {BOLD}{CYAN}╠═══════════════════════════════════════════════════════════════════════╣{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {DIM}N   │ dim(even)│ GOE_fit  │ Poi_fit  │ best     │ bar{RESET}");

    let mut transition_data: Vec<(usize, f64, f64, &str)> = Vec::new();
    let t0 = Instant::now();

    for n in (60..=250).step_by(2) {
        let (full_mat, full_dim) = build_gram_matrix_f64(n);

        // Even sector (dark)
        let even_idx: Vec<usize> = (2..=n).filter(|&k| k % 2 == 0).collect();
        let even_sub = project_f64(&full_mat, full_dim, &even_idx);
        let even_eigs = eigenvalues_nalgebra(&even_sub, even_idx.len());
        let sp = spectral::compute_spacing(&even_eigs);

        let is_goe = sp.best_class.contains("GOE");
        let bar_len = (sp.goe_fit * 40.0) as usize;
        let bar: String = "█".repeat(bar_len) + &"░".repeat(40 - bar_len);
        let color = if is_goe { GREEN } else { YELLOW };

        println!(
            "  {BOLD}{CYAN}║{RESET}  {:<4}│ {:<8} │ {:.6} │ {:.6} │ {}{:<8}{RESET} │ {color}{bar}{RESET}",
            n, even_idx.len(), sp.goe_fit, sp.poisson_fit,
            color, if is_goe { "GOE" } else { "Poisson" },
        );

        transition_data.push((n, sp.goe_fit, sp.poisson_fit, sp.best_class));
    }

    let elapsed = t0.elapsed().as_secs_f64();
    println!("  {BOLD}{CYAN}╚═══════════════════════════════════════════════════════════════════════╝{RESET}");

    // Analyze the transition
    println!("\n  {BOLD}{WHITE}═══ TRANSITION ANALYSIS ═══{RESET}");

    // Find crossover point (where GOE first exceeds Poisson)
    let crossover_n = transition_data.iter()
        .find(|(_, goe, poi, _)| goe > poi)
        .map(|(n, _, _, _)| *n);

    if let Some(nc) = crossover_n {
        println!("  {GREEN}Critical N_c (GOE > Poisson):{RESET} {BOLD}{WHITE}N = {nc}{RESET}");
    }

    // Compute transition width (N where GOE goes from 0.4 to 0.6 of max)
    let goe_values: Vec<f64> = transition_data.iter().map(|(_, g, _, _)| *g).collect();
    let goe_max = goe_values.iter().cloned().fold(f64::NEG_INFINITY, f64::max);
    let goe_min = goe_values.iter().cloned().fold(f64::INFINITY, f64::min);
    let thresh_lo = goe_min + 0.2 * (goe_max - goe_min);
    let thresh_hi = goe_min + 0.8 * (goe_max - goe_min);

    let n_lo = transition_data.iter()
        .find(|(_, g, _, _)| *g >= thresh_lo)
        .map(|(n, _, _, _)| *n);
    let n_hi = transition_data.iter()
        .find(|(_, g, _, _)| *g >= thresh_hi)
        .map(|(n, _, _, _)| *n);

    if let (Some(lo), Some(hi)) = (n_lo, n_hi) {
        let width = hi - lo;
        println!("  {CYAN}Transition width (20%→80%):{RESET} {BOLD}{WHITE}ΔN = {width} (N={lo}..{hi}){RESET}");
        if width <= 20 {
            println!("  {RED}→ SHARP transition (ΔN ≤ 20): possible quantum phase transition{RESET}");
        } else if width <= 60 {
            println!("  {YELLOW}→ MODERATE transition (ΔN ~ 20-60): crossover with finite-size effects{RESET}");
        } else {
            println!("  {GREEN}→ SMOOTH crossover (ΔN > 60): liquid-like boiling{RESET}");
        }
    }

    // Also sweep the FULL matrix and odd sector for comparison
    println!("\n  {BOLD}{WHITE}═══ COMPARISON: Full Matrix + Odd Sector ═══{RESET}");
    println!("  {DIM}N   │ Full_GOE │ Odd_GOE  │ Dark_GOE{RESET}");

    for n in (60..=200).step_by(10) {
        let (full_mat, full_dim) = build_gram_matrix_f64(n);
        let full_eigs = eigenvalues_nalgebra(&full_mat, full_dim);
        let full_sp = spectral::compute_spacing(&full_eigs);

        let odd_idx: Vec<usize> = (2..=n).filter(|&k| k % 2 == 1).collect();
        let odd_sub = project_f64(&full_mat, full_dim, &odd_idx);
        let odd_eigs = eigenvalues_nalgebra(&odd_sub, odd_idx.len());
        let odd_sp = spectral::compute_spacing(&odd_eigs);

        let even_idx: Vec<usize> = (2..=n).filter(|&k| k % 2 == 0).collect();
        let even_sub = project_f64(&full_mat, full_dim, &even_idx);
        let even_eigs = eigenvalues_nalgebra(&even_sub, even_idx.len());
        let even_sp = spectral::compute_spacing(&even_eigs);

        println!(
            "  {:<4}│ {:.6} │ {:.6} │ {:.6}",
            n, full_sp.goe_fit, odd_sp.goe_fit, even_sp.goe_fit
        );
    }

    println!("\n  {DIM}Experiment B completed in {elapsed:.1}s{RESET}");
}

// ═══════════════════════════════════════════════════════════════════════
// EXPERIMENT C: EIGENVECTOR LOCALIZATION / QUANTUM SCARRING
// ═══════════════════════════════════════════════════════════════════════

fn experiment_c_eigenvector_localization(max_n: usize) {
    println!("\n  {BOLD}{CYAN}╔═══════════════════════════════════════════════════════════════════════╗{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}{WHITE}EXPERIMENT C: EIGENVECTOR LOCALIZATION / QUANTUM SCARRING{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {DIM}Participation ratio of eigenvectors across mod-8 residue classes{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {DIM}PR = 1/Σ|v_i|⁴ (IPR⁻¹). PR=dim → delocalized, PR=1 → localized{RESET}");
    println!("  {BOLD}{CYAN}╠═══════════════════════════════════════════════════════════════════════╣{RESET}");

    let test_ns: Vec<usize> = vec![100, 150, 200, 300, 400, 500, 750, 1000]
        .into_iter()
        .filter(|&n| n <= max_n)
        .collect();

    let t0 = Instant::now();

    for &n in &test_ns {
        let (full_mat, full_dim) = build_gram_matrix_f64(n);

        // Full eigendecomposition via nalgebra — eigenvectors + eigenvalues
        let m = nalgebra::DMatrix::from_row_slice(full_dim, full_dim, &full_mat);
        let eigen = m.symmetric_eigen();

        // Sort eigenvalues and get permutation
        let mut indexed: Vec<(usize, f64)> = eigen.eigenvalues.iter()
            .enumerate()
            .map(|(i, &v)| (i, v))
            .collect();
        indexed.sort_by(|a, b| a.1.partial_cmp(&b.1).unwrap());

        // Residue class membership for each index k (k=2..=n → row k-2)
        let class_of = |row: usize| -> usize {
            let k = row + 2;
            k % 8
        };

        println!("\n  {BOLD}{WHITE}═══ N={n} (dim={full_dim}) ═══{RESET}");
        println!("  {DIM}eigenstate     │ eigenvalue      │  PR(full)│ k≡0(8) │ k≡1(8) │ k≡2(8) │ k≡3(8) │ k≡4(8) │ k≡5(8) │ k≡6(8) │ k≡7(8) │ scar?{RESET}");

        // Analyze key eigenvectors: ground state, 25%, 50%, 75%, top
        let key_indices = vec![
            (0, "ground (λ_min)"),
            (full_dim / 10, "10th percentile"),
            (full_dim / 4, "25th percentile"),
            (full_dim / 2, "median"),
            (3 * full_dim / 4, "75th percentile"),
            (full_dim - 1, "top (λ_max)"),
        ];

        for &(sorted_idx, label) in &key_indices {
            if sorted_idx >= full_dim { continue; }
            let (orig_col, eigenvalue) = indexed[sorted_idx];

            // Extract eigenvector column
            let eigvec: Vec<f64> = (0..full_dim)
                .map(|row| eigen.eigenvectors[(row, orig_col)])
                .collect();

            // Inverse Participation Ratio (IPR) = Σ|v_i|⁴
            let ipr: f64 = eigvec.iter().map(|&v| v.powi(4)).sum();
            let pr = if ipr > 1e-30 { 1.0 / ipr } else { 0.0 };

            // Weight on each residue class mod 8
            let mut class_weight = [0.0f64; 8];
            for (row, &v) in eigvec.iter().enumerate() {
                let c = class_of(row);
                class_weight[c] += v * v;
            }

            // Expected uniform weight per class
            let class_counts: [usize; 8] = {
                let mut counts = [0usize; 8];
                for row in 0..full_dim {
                    counts[class_of(row)] += 1;
                }
                counts
            };

            // Detect scarring: is any class > 2× its expected weight?
            let total_weight: f64 = class_weight.iter().sum();
            let mut scarred = false;
            let mut scar_class = 0;
            let mut max_excess = 0.0f64;
            for c in 0..8 {
                if class_counts[c] == 0 { continue; }
                let expected = class_counts[c] as f64 / full_dim as f64 * total_weight;
                let excess = class_weight[c] / expected;
                if excess > max_excess {
                    max_excess = excess;
                    scar_class = c;
                }
                if excess > 1.5 {
                    scarred = true;
                }
            }

            let scar_label = if scarred {
                format!("{RED}SCAR k≡{scar_class}(8) ×{max_excess:.2}{RESET}")
            } else {
                format!("{GREEN}uniform ×{max_excess:.2}{RESET}")
            };

            println!(
                "  {:<14} │ {:>15.10} │ {:>8.1} │ {:>6.3} │ {:>6.3} │ {:>6.3} │ {:>6.3} │ {:>6.3} │ {:>6.3} │ {:>6.3} │ {:>6.3} │ {scar_label}",
                label, eigenvalue, pr,
                class_weight[0], class_weight[1], class_weight[2], class_weight[3],
                class_weight[4], class_weight[5], class_weight[6], class_weight[7],
            );
        }

        // Overall localization summary
        println!("\n  {DIM}Localization summary:{RESET}");

        // Compute PR for ALL eigenvectors
        let mut pr_values: Vec<f64> = Vec::with_capacity(full_dim);
        for sorted_idx in 0..full_dim {
            let (orig_col, _) = indexed[sorted_idx];
            let ipr: f64 = (0..full_dim)
                .map(|row| eigen.eigenvectors[(row, orig_col)].powi(4))
                .sum();
            pr_values.push(if ipr > 1e-30 { 1.0 / ipr } else { 0.0 });
        }

        let avg_pr: f64 = pr_values.iter().sum::<f64>() / pr_values.len() as f64;
        let min_pr = pr_values.iter().cloned().fold(f64::INFINITY, f64::min);
        let max_pr = pr_values.iter().cloned().fold(f64::NEG_INFINITY, f64::max);
        let goe_expected_pr = full_dim as f64 / 3.0; // GOE prediction: PR ≈ dim/3

        println!("  PR range: [{min_pr:.1}, {max_pr:.1}]  mean={avg_pr:.1}  GOE_pred={goe_expected_pr:.1}");
        let ratio = avg_pr / goe_expected_pr;
        if ratio > 0.8 && ratio < 1.2 {
            println!("  {GREEN}→ Mean PR consistent with GOE (ratio = {ratio:.3}): DELOCALIZED{RESET}");
        } else if ratio < 0.5 {
            println!("  {RED}→ Mean PR << GOE prediction (ratio = {ratio:.3}): LOCALIZED states present{RESET}");
        } else {
            println!("  {YELLOW}→ Mean PR deviates from GOE (ratio = {ratio:.3}): partial localization{RESET}");
        }

        // Ground state special analysis
        let (orig_col_ground, _) = indexed[0];
        let ground_vec: Vec<f64> = (0..full_dim)
            .map(|row| eigen.eigenvectors[(row, orig_col_ground)])
            .collect();

        // Which indices carry the most weight in the ground state?
        let mut weighted_indices: Vec<(usize, f64)> = ground_vec.iter()
            .enumerate()
            .map(|(row, &v)| (row + 2, v * v))
            .collect();
        weighted_indices.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap());

        println!("\n  {BOLD}Ground state: top 10 weighted indices:{RESET}");
        print!("  ");
        for (k, w) in weighted_indices.iter().take(10) {
            let is_prime = is_prime_simple(*k);
            let marker = if is_prime { format!("{CYAN}P{RESET}") } else { format!("{DIM}C{RESET}") };
            print!("k={k}({marker})={w:.4}  ");
        }
        println!();

        // Count prime vs composite weight
        let prime_weight: f64 = ground_vec.iter()
            .enumerate()
            .filter(|(row, _)| is_prime_simple(row + 2))
            .map(|(_, &v)| v * v)
            .sum();
        let composite_weight = 1.0 - prime_weight;
        println!("  Prime weight: {prime_weight:.4}  Composite weight: {composite_weight:.4}");
    }

    println!("\n  {DIM}Experiment C completed in {:.1}s{RESET}", t0.elapsed().as_secs_f64());
}

fn eigenvalues_nalgebra(mat: &[f64], dim: usize) -> Vec<f64> {
    if dim == 0 { return vec![]; }
    let m = nalgebra::DMatrix::from_row_slice(dim, dim, mat);
    let eigen = m.symmetric_eigen();
    let mut eigs: Vec<f64> = eigen.eigenvalues.iter().copied().collect();
    eigs.sort_by(|a, b| a.partial_cmp(b).unwrap());
    eigs
}

fn is_prime_simple(n: usize) -> bool {
    if n < 2 { return false; }
    if n < 4 { return true; }
    if n % 2 == 0 || n % 3 == 0 { return false; }
    let mut i = 5;
    while i * i <= n {
        if n % i == 0 || n % (i + 2) == 0 { return false; }
        i += 6;
    }
    true
}

fn main() {
    let t0 = Instant::now();
    let threads = rayon::current_num_threads();

    let max_n: usize = std::env::args()
        .nth(1)
        .and_then(|s| s.parse().ok())
        .unwrap_or(500);

    header(
        "CATHEDRAL DEEP PROBE — EXPERIMENTS B+C",
        &format!("Dark sector sweep + eigenvector localization · max N = {max_n}"),
        64,
        threads,
    );

    // Experiment B: Dark sector critical sweep
    experiment_b_dark_sector_sweep();

    // Experiment C: Eigenvector localization
    experiment_c_eigenvector_localization(max_n);

    println!(
        "\n  {BOLD}{WHITE}Total:{RESET} {GREEN}{:.1}s{RESET} ({threads} threads, f64/nalgebra)",
        t0.elapsed().as_secs_f64()
    );
    println!();
}
