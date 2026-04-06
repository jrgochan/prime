//! λ_eff Linear Growth Experiment
//! ================================
//!
//! Computes λ_eff(m, N) for all 8 octonionic residue classes at various N,
//! testing the `lambdaEff_linear_growth` axiom.
//!
//! Hardware target: Apple M2 Max, 12 cores, 96 GB RAM

mod gram;
mod partition;
mod analysis;

use std::time::Instant;
use indicatif::{ProgressBar, ProgressStyle, MultiProgress};

/// Full result for one value of N
#[derive(Clone, Debug, serde::Serialize)]
struct NResult {
    n: usize,
    total_time_secs: f64,
    gram_time_secs: f64,
    eigen_time_secs: f64,
    lambda_eff_results: Vec<analysis::LambdaEffResult>,
    cross_analyses: Vec<analysis::CrossBlockAnalysis>,
    block_spectra: Vec<analysis::BlockSpectrum>,
    /// Full Gram matrix λ_min (smallest eigenvalue across all blocks)
    global_lambda_min: f64,
    /// Average λ_eff across classes
    avg_lambda_eff: f64,
    /// λ_eff / N ratio (should be ~constant if linear growth holds)
    avg_lambda_eff_over_n: f64,
    /// ¼ · Σ(1/λ_eff) (rank-1 ratio bound)
    rank1_ratio_bound: f64,
}

fn run_for_n(n: usize, multi: &MultiProgress) -> NResult {
    let total_start = Instant::now();

    println!("\n  ╔═══════════════════════════════════════════╗");
    println!("  ║  N = {:>5}                                ║", n);
    println!("  ╚═══════════════════════════════════════════╝");

    // Step 1: Partition indices into 8 classes
    let classes = partition::partition(n);
    let non_empty: Vec<(usize, &Vec<usize>)> = classes
        .iter()
        .enumerate()
        .filter(|(_, c)| c.len() >= 2)
        .collect();

    println!("  Partition: {} non-empty classes", non_empty.len());
    for &(m, ref cls) in &non_empty {
        println!("    {} : |S| = {}", partition::class_name(m), cls.len());
    }

    // Step 2: Compute block Gram matrices
    let gram_start = Instant::now();
    println!("\n  Computing block Gram matrices...");

    let pb_gram = multi.add(ProgressBar::new(100));
    pb_gram.set_style(
        ProgressStyle::default_bar()
            .template("  [{bar:40.cyan/blue}] {pos}/{len} entries ({eta})")
            .unwrap()
            .progress_chars("█▉▊▋▌▍▎▏  "),
    );

    let mut block_matrices: Vec<(usize, Vec<f64>, usize)> = Vec::new();
    for &(m, ref indices) in &non_empty {
        let dim = indices.len();
        if dim < 2 { continue; }
        println!("    Block {} ({} × {})", m, dim, dim);
        pb_gram.set_length((dim * (dim + 1) / 2) as u64);
        pb_gram.set_position(0);
        let mat = gram::compute_block_matrix(indices, Some(&pb_gram));
        block_matrices.push((m, mat, dim));
    }
    pb_gram.finish_and_clear();
    let gram_time = gram_start.elapsed().as_secs_f64();
    println!("  Block Gram matrices computed in {:.1}s", gram_time);

    // Step 3: Eigendecompose each block
    let eigen_start = Instant::now();
    println!("\n  Eigendecomposing blocks...");

    let mut block_results: Vec<(
        usize,                          // class idx
        analysis::BlockSpectrum,
        Vec<f64>,                       // eigenvalues
        nalgebra::DMatrix<f64>,         // eigenvectors
        Vec<usize>,                     // indices
    )> = Vec::new();

    for &(m, ref mat, dim) in &block_matrices {
        let (spectrum, eigenvalues, eigenvectors) = analysis::analyze_block(mat, dim, m);
        println!(
            "    Block {}: λ_min={:.6}, λ_med={:.6}, λ_mean={:.6}",
            m, spectrum.lambda_min, spectrum.lambda_median, spectrum.lambda_mean
        );
        let indices = classes[m].clone();
        block_results.push((m, spectrum, eigenvalues, eigenvectors, indices));
    }

    let eigen_time = eigen_start.elapsed().as_secs_f64();
    println!("  Eigendecomposition completed in {:.1}s", eigen_time);

    // Step 4: Compute cross-block matrices and λ_eff for each class
    println!("\n  Computing cross-block interactions and λ_eff...");

    let mut lambda_eff_results: Vec<analysis::LambdaEffResult> = Vec::new();
    let mut cross_analyses: Vec<analysis::CrossBlockAnalysis> = Vec::new();
    let mut block_spectra: Vec<analysis::BlockSpectrum> = Vec::new();

    for i in 0..block_results.len() {
        let (class_i, ref spectrum_i, ref eigenvalues_i, ref eigenvectors_i, ref indices_i) =
            block_results[i];

        // Compute cross-block matrices for this class against all others
        let mut cross_matrices: Vec<(usize, Vec<f64>, usize, usize)> = Vec::new();

        for j in 0..block_results.len() {
            if i == j { continue; }
            let (class_j, _, _, _, ref indices_j) = block_results[j];

            let cross = gram::compute_cross_matrix(indices_i, indices_j);
            cross_matrices.push((class_j, cross, indices_i.len(), indices_j.len()));
        }

        // Compute λ_eff
        let (leff_result, cross_analysis) = analysis::compute_lambda_eff(
            n,
            class_i,
            eigenvalues_i,
            eigenvectors_i,
            &cross_matrices,
        );

        println!(
            "    Class {} : λ_eff = {:.4}, PR = {:.1}, edge = {:.1}%, bulk = {:.1}%",
            class_i,
            leff_result.lambda_eff,
            leff_result.participation_ratio,
            leff_result.edge_fraction * 100.0,
            leff_result.bulk_fraction * 100.0,
        );
        println!(
            "             bands: [<0.1]={:.1}% [0.1,0.3)={:.1}% [≥0.3]={:.1}%",
            leff_result.band_contributions[0] * 100.0,
            leff_result.band_contributions[1] * 100.0,
            leff_result.band_contributions[2] * 100.0,
        );

        lambda_eff_results.push(leff_result);
        cross_analyses.push(cross_analysis);
        block_spectra.push(spectrum_i.clone());
    }

    // Step 5: Aggregate results
    let global_lambda_min = block_spectra
        .iter()
        .map(|s| s.lambda_min)
        .fold(f64::INFINITY, f64::min);

    let valid_eff: Vec<f64> = lambda_eff_results
        .iter()
        .filter(|r| r.lambda_eff.is_finite() && r.lambda_eff > 0.0)
        .map(|r| r.lambda_eff)
        .collect();

    let avg_lambda_eff = if !valid_eff.is_empty() {
        valid_eff.iter().sum::<f64>() / valid_eff.len() as f64
    } else {
        0.0
    };

    let avg_lambda_eff_over_n = avg_lambda_eff / n as f64;

    let rank1_ratio_bound: f64 = if !valid_eff.is_empty() {
        0.25 * valid_eff.iter().map(|&l| 1.0 / l).sum::<f64>()
    } else {
        f64::INFINITY
    };

    let total_time = total_start.elapsed().as_secs_f64();

    println!("\n  ── Summary for N={} ──────────────────────", n);
    println!("  Global λ_min(G^block) = {:.6}", global_lambda_min);
    println!("  Avg λ_eff             = {:.4}", avg_lambda_eff);
    println!("  Avg λ_eff / N         = {:.6} (should be ~constant)", avg_lambda_eff_over_n);
    println!("  ¼·Σ(1/λ_eff)         = {:.6} (rank-1 ratio bound)", rank1_ratio_bound);
    println!("  Total time            = {:.1}s", total_time);

    NResult {
        n,
        total_time_secs: total_time,
        gram_time_secs: gram_time,
        eigen_time_secs: eigen_time,
        lambda_eff_results,
        cross_analyses,
        block_spectra,
        global_lambda_min,
        avg_lambda_eff,
        avg_lambda_eff_over_n,
        rank1_ratio_bound,
    }
}

fn main() {
    let start = Instant::now();

    println!("╔════════════════════════════════════════════════════════════╗");
    println!("║  λ_eff LINEAR GROWTH EXPERIMENT                          ║");
    println!("║  Testing: ∃ c > 0, ∀ N ≥ 200, ∀ m, c·N ≤ λ_eff(m,N)   ║");
    println!("║  Piecewise-exact Gram computation + Octonionic partition  ║");
    println!("╚════════════════════════════════════════════════════════════╝\n");

    // N values to test: start small for validation, then go high
    let n_values: Vec<usize> = std::env::args()
        .nth(1)
        .map(|arg| {
            if arg == "validate" {
                vec![50, 100, 200, 500]
            } else if arg == "medium" {
                vec![200, 500, 1000, 2000, 3000]
            } else if arg == "high" {
                vec![200, 500, 1000, 2000, 3000, 5000]
            } else if arg == "ultra" {
                vec![200, 500, 1000, 2000, 3000, 5000, 7500, 10000]
            } else if let Ok(n) = arg.parse::<usize>() {
                vec![n]
            } else {
                vec![200, 500, 1000, 2000]
            }
        })
        .unwrap_or_else(|| vec![200, 500, 1000, 2000]);

    println!("  Mode: N = {:?}\n", n_values);

    let multi = MultiProgress::new();
    let mut results: Vec<NResult> = Vec::new();

    for &n in &n_values {
        let result = run_for_n(n, &multi);
        results.push(result);
    }

    // Final summary table
    println!("\n\n╔════════════════════════════════════════════════════════════════════════════════╗");
    println!("║  RESULTS SUMMARY                                                             ║");
    println!("╠════════════════════════════════════════════════════════════════════════════════╣");
    println!("║  {:<6} │ {:<10} │ {:<10} │ {:<10} │ {:<10} │ {:<8} ║",
        "N", "λ_eff avg", "λ_eff/N", "R₁ bound", "λ_min", "Time(s)");
    println!("╠════════════════════════════════════════════════════════════════════════════════╣");

    for r in &results {
        println!("║  {:<6} │ {:<10.4} │ {:<10.6} │ {:<10.6} │ {:<10.6} │ {:<8.1} ║",
            r.n, r.avg_lambda_eff, r.avg_lambda_eff_over_n,
            r.rank1_ratio_bound, r.global_lambda_min, r.total_time_secs);
    }
    println!("╚════════════════════════════════════════════════════════════════════════════════╝");

    // Linear fit: λ_eff ≈ c·N + d
    if results.len() >= 2 {
        let xs: Vec<f64> = results.iter().map(|r| r.n as f64).collect();
        let ys: Vec<f64> = results.iter().map(|r| r.avg_lambda_eff).collect();
        let n_pts = xs.len() as f64;
        let sum_x: f64 = xs.iter().sum();
        let sum_y: f64 = ys.iter().sum();
        let sum_xy: f64 = xs.iter().zip(ys.iter()).map(|(x, y)| x * y).sum();
        let sum_x2: f64 = xs.iter().map(|x| x * x).sum();

        let slope = (n_pts * sum_xy - sum_x * sum_y) / (n_pts * sum_x2 - sum_x * sum_x);
        let intercept = (sum_y - slope * sum_x) / n_pts;

        // R² goodness of fit
        let y_mean = sum_y / n_pts;
        let ss_tot: f64 = ys.iter().map(|y| (y - y_mean).powi(2)).sum();
        let ss_res: f64 = xs.iter().zip(ys.iter())
            .map(|(x, y)| (y - (slope * x + intercept)).powi(2))
            .sum();
        let r_squared = 1.0 - ss_res / ss_tot;

        println!("\n  LINEAR FIT: λ_eff ≈ {:.6}·N + {:.4}", slope, intercept);
        println!("  R² = {:.6}", r_squared);
        println!("  Implied axiom constant c = {:.6}", slope);

        if slope > 0.0 && r_squared > 0.99 {
            println!("  ✅ LINEAR GROWTH CONFIRMED (c = {:.6}, R² = {:.4})", slope, r_squared);
        } else if slope > 0.0 && r_squared > 0.95 {
            println!("  ⚠️  Linear growth plausible but R² = {:.4} < 0.99", r_squared);
        } else {
            println!("  ❌ Linear growth NOT confirmed: slope={:.6}, R²={:.4}", slope, r_squared);
        }
    }

    // Participation ratio trend
    println!("\n  PARTICIPATION RATIO TREND:");
    for r in &results {
        let avg_pr: f64 = r.lambda_eff_results.iter()
            .map(|l| l.participation_ratio)
            .sum::<f64>() / r.lambda_eff_results.len() as f64;
        let block_size_avg: f64 = r.block_spectra.iter()
            .map(|s| s.block_size as f64)
            .sum::<f64>() / r.block_spectra.len() as f64;
        println!("    N={:<6}: PR={:.1}, block_size={:.0}, PR/block_size={:.4}",
            r.n, avg_pr, block_size_avg, avg_pr / block_size_avg);
    }

    // Save results to JSON
    let json = serde_json::to_string_pretty(&results).unwrap();
    let out_path = format!("results/lambda_eff_results.json");
    if let Err(e) = std::fs::write(&out_path, &json) {
        eprintln!("  Warning: Could not write {}: {}", out_path, e);
    } else {
        println!("\n  📊 Full results saved to {}", out_path);
    }

    let total_elapsed = start.elapsed();
    println!("\n╔════════════════════════════════════════════════════════════╗");
    println!("║  EXPERIMENT COMPLETE ({:.1}s total)                     ║",
        total_elapsed.as_secs_f64());
    println!("╚════════════════════════════════════════════════════════════╝");
}
