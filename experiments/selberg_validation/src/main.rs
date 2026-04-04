/// Spectral Decomposition of the NB Distance — Overnight Experiment
///
/// Comprehensive analysis of WHY d²_N = O(1/log N) by decomposing
/// the Gram matrix eigenstructure.
///
/// For N = 2, 3, ..., N_MAX:
///   1. Compute Gram matrix G (N-1 × N-1)
///   2. Compute basis inner product vector b
///   3. Eigendecompose G = QΛQᵀ
///   4. Project b: α = Qᵀb
///   5. Compute d²_N = 1 - Σ αᵢ²/λᵢ
///   6. Track spectral quantities vs N
///
/// Output files:
///   results/spectral_summary.csv     — per-N summary
///   results/eigenvalue_spectrum.csv  — all eigenvalues for select N
///   results/mode_contributions.csv   — αᵢ²/λᵢ for each mode
///   results/spectral_report.txt      — human-readable analysis

use nalgebra::{DMatrix, DVector, SymmetricEigen};
use std::fs;
use std::io::Write;
use std::time::Instant;

const N_MAX: usize = 600;
const QUAD_PTS: usize = 50_000;

fn main() {
    let start = Instant::now();

    println!("╔═══════════════════════════════════════════════════════════╗");
    println!("║  Spectral Decomposition of NB Distance — Overnight Run   ║");
    println!("║  N_MAX = {}, Quadrature = {} pts                    ║", N_MAX, QUAD_PTS);
    println!("╚═══════════════════════════════════════════════════════════╝\n");

    fs::create_dir_all("results").unwrap();

    // Precompute basis inner products
    println!("[1/4] Precomputing b_k for k=1..{} ...", N_MAX);
    let basis_ip: Vec<f64> = (0..=N_MAX)
        .map(|k| if k == 0 { 0.0 } else { compute_basis_ip(k) })
        .collect();
    println!("  Done. b_1={:.8}, b_2={:.8}, b_10={:.8}",
        basis_ip[1], basis_ip[2], basis_ip.get(10).unwrap_or(&0.0));

    // Precompute Gram matrix (single-pass)
    println!("[2/4] Precomputing Gram matrix G_{{jk}} for j,k=1..{} ...", N_MAX);
    let gram_raw = compute_gram_matrix_fast(N_MAX);
    println!("  Done. G_{{1,1}}={:.8}, G_{{1,2}}={:.8}", gram_raw[1][1], gram_raw[1][2]);

    // Open output files
    let mut summary = fs::File::create("results/spectral_summary.csv").unwrap();
    writeln!(summary,
        "N,d2,d2_logN,lambda_min,lambda_max,cond,norm_b,\
         b_proj_min_evec,top3_contrib_frac,sum_alpha2,sum_alpha2_over_lambda,\
         lambda_min_logN,logN"
    ).unwrap();

    let mut eigenval_file = fs::File::create("results/eigenvalue_spectrum.csv").unwrap();
    writeln!(eigenval_file, "N,mode_index,eigenvalue,alpha_sq,alpha_sq_over_lambda,cumul_frac").unwrap();

    let mut report = fs::File::create("results/spectral_report.txt").unwrap();
    writeln!(report, "Spectral Decomposition of NB Distance").unwrap();
    writeln!(report, "======================================").unwrap();
    writeln!(report, "N_MAX = {}, QUAD_PTS = {}", N_MAX, QUAD_PTS).unwrap();
    writeln!(report, "Started: {:?}\n", start).unwrap();

    println!("\n[3/4] Running spectral analysis for N=2..{} ...\n", N_MAX);
    println!("{:>4}  {:>10}  {:>8}  {:>10}  {:>10}  {:>8}  {:>10}  {:>8}",
        "N", "d²", "d²·logN", "λ_min", "λ_max", "κ(G)", "λ_min·logN", "|cos θ|");
    println!("{}", "─".repeat(85));

    let mut max_d2_logn = 0.0f64;

    // Detailed eigenvalue output for select N values
    let detail_ns: Vec<usize> = vec![5, 10, 20, 50, 100, 200, 300, 400, 500, N_MAX];

    for n in 2..=N_MAX {
        let dim = n - 1;
        let log_n = (n as f64).ln();

        // Extract sub-matrix and sub-vector
        let b = DVector::from_fn(dim, |i, _| basis_ip[i + 1]);
        let g = DMatrix::from_fn(dim, dim, |i, j| gram_raw[i + 1][j + 1]);

        // Eigendecomposition
        let eigen = SymmetricEigen::new(g.clone());
        let eigenvalues = &eigen.eigenvalues;
        let eigenvectors = &eigen.eigenvectors;

        // Sort eigenvalues (nalgebra doesn't guarantee order)
        let mut eig_pairs: Vec<(f64, usize)> = eigenvalues.iter()
            .enumerate()
            .map(|(i, &v)| (v, i))
            .collect();
        eig_pairs.sort_by(|a, b| a.0.partial_cmp(&b.0).unwrap());

        let lambda_min = eig_pairs.first().map(|p| p.0).unwrap_or(0.0);
        let lambda_max = eig_pairs.last().map(|p| p.0).unwrap_or(1.0);
        let cond = if lambda_min > 1e-15 { lambda_max / lambda_min } else { f64::INFINITY };

        // Project b onto eigenvectors: α = Qᵀb
        let alpha = eigenvectors.transpose() * &b;
        let norm_b = b.norm();

        // Compute d² = 1 - Σ αᵢ²/λᵢ
        let mut sum_a2_over_l = 0.0f64;
        let sum_a2: f64 = alpha.iter().map(|a| a * a).sum();

        // Mode contributions (sorted by eigenvalue)
        let mut mode_contribs: Vec<(f64, f64, f64)> = Vec::new(); // (lambda, alpha², alpha²/lambda)
        for &(lambda, idx) in &eig_pairs {
            let a = alpha[idx];
            let a2 = a * a;
            let contrib = if lambda > 1e-15 { a2 / lambda } else { 0.0 };
            sum_a2_over_l += contrib;
            mode_contribs.push((lambda, a2, contrib));
        }

        let d2 = 1.0 - sum_a2_over_l;
        let d2_logn = d2 * log_n;
        if n >= 10 { max_d2_logn = max_d2_logn.max(d2_logn); }

        // Cosine of angle between b and smallest eigenvector
        let min_evec_idx = eig_pairs[0].1;
        let min_evec = eigenvectors.column(min_evec_idx);
        let cos_theta = (b.dot(&min_evec) / (norm_b * min_evec.norm())).abs();

        // Top 3 mode contributions (sorted by contribution)
        let mut contribs_sorted: Vec<f64> = mode_contribs.iter().map(|c| c.2).collect();
        contribs_sorted.sort_by(|a, b| b.partial_cmp(a).unwrap());
        let top3_frac: f64 = contribs_sorted.iter().take(3).sum::<f64>() / sum_a2_over_l;

        // Write summary
        writeln!(summary, "{},{:.15},{:.10},{:.15},{:.15},{:.6},{:.10},{:.10},{:.6},{:.10},{:.10},{:.10},{:.6}",
            n, d2, d2_logn, lambda_min, lambda_max, cond, norm_b,
            cos_theta, top3_frac, sum_a2, sum_a2_over_l,
            lambda_min * log_n, log_n).unwrap();

        // Write detailed eigenvalue data for select N
        if detail_ns.contains(&n) {
            let mut cumul = 0.0;
            for (mode_idx, &(lambda, _orig_idx)) in eig_pairs.iter().enumerate() {
                let (_, a2, contrib) = mode_contribs[mode_idx];
                cumul += contrib / sum_a2_over_l;
                writeln!(eigenval_file, "{},{},{:.15},{:.15},{:.15},{:.8}",
                    n, mode_idx, lambda, a2, contrib, cumul).unwrap();
            }
        }

        // Print progress
        if n <= 20 || n % 25 == 0 || n == N_MAX {
            println!("{:>4}  {:>10.6}  {:>8.4}  {:>10.2e}  {:>10.6}  {:>8.1}  {:>10.6}  {:>8.4}",
                n, d2, d2_logn, lambda_min, lambda_max, cond, lambda_min * log_n, cos_theta);
        }
    }

    let elapsed = start.elapsed();

    println!("\n{}", "═".repeat(85));
    println!("RESULTS:");
    println!("  max d²·log(N) for N≥10: {:.8}", max_d2_logn);
    println!("  Time elapsed: {:.1}s", elapsed.as_secs_f64());

    writeln!(report, "\nmax d²·log(N) for N≥10: {:.10}", max_d2_logn).unwrap();
    writeln!(report, "Time elapsed: {:.1}s", elapsed.as_secs_f64()).unwrap();

    // Phase 2: Deep analysis of eigenvalue scaling
    println!("\n[4/4] Deep eigenvalue scaling analysis ...\n");

    let mut scaling_file = fs::File::create("results/eigenvalue_scaling.csv").unwrap();
    writeln!(scaling_file, "N,log_N,lambda_1,lambda_2,lambda_3,lambda_4,lambda_5,\
        lambda_median,lambda_N_minus_1,\
        lambda1_times_logN,lambda1_times_logN_sq,\
        b_alpha1_sq,b_alpha_last_sq").unwrap();

    for n in 2..=N_MAX {
        let dim = n - 1;
        let log_n = (n as f64).ln();
        let b = DVector::from_fn(dim, |i, _| basis_ip[i + 1]);
        let g = DMatrix::from_fn(dim, dim, |i, j| gram_raw[i + 1][j + 1]);
        let eigen = SymmetricEigen::new(g);

        let mut eigs: Vec<f64> = eigen.eigenvalues.iter().copied().collect();
        eigs.sort_by(|a, b| a.partial_cmp(b).unwrap());

        let alpha = eigen.eigenvectors.transpose() * &b;
        let mut alpha_sorted: Vec<(f64, f64)> = eigs.iter().zip(alpha.iter())
            .map(|(&l, &a)| (l, a * a))
            .collect();
        alpha_sorted.sort_by(|a, b| a.0.partial_cmp(&b.0).unwrap());

        let get_eig = |i: usize| *eigs.get(i).unwrap_or(&0.0);
        let median_eig = eigs[dim / 2];

        writeln!(scaling_file, "{},{:.6},{:.15},{:.15},{:.15},{:.15},{:.15},{:.15},{:.15},{:.10},{:.10},{:.10},{:.10}",
            n, log_n,
            get_eig(0), get_eig(1), get_eig(2), get_eig(3), get_eig(4),
            median_eig, get_eig(dim - 1),
            get_eig(0) * log_n, get_eig(0) * log_n * log_n,
            alpha_sorted[0].1, alpha_sorted.last().map(|p| p.1).unwrap_or(0.0)
        ).unwrap();
    }

    println!("  Done. Results in results/eigenvalue_scaling.csv");

    // Phase 3: Identify the dominant mode
    println!("\n  Analyzing dominant modes ...");

    let mut dominant_file = fs::File::create("results/dominant_modes.csv").unwrap();
    writeln!(dominant_file, "N,log_N,d2,mode_rank_of_dominant,lambda_dominant,\
        alpha_sq_dominant,contrib_dominant,frac_dominant").unwrap();

    for n in [10, 20, 50, 100, 200, 300, 400, 500, N_MAX].iter() {
        let n = *n;
        if n > N_MAX { continue; }
        let dim = n - 1;
        let log_n = (n as f64).ln();

        let b = DVector::from_fn(dim, |i, _| basis_ip[i + 1]);
        let g = DMatrix::from_fn(dim, dim, |i, j| gram_raw[i + 1][j + 1]);
        let eigen = SymmetricEigen::new(g);
        let alpha = eigen.eigenvectors.transpose() * &b;

        let mut eig_data: Vec<(usize, f64, f64, f64)> = eigen.eigenvalues.iter()
            .enumerate()
            .map(|(i, &l)| {
                let a2 = alpha[i] * alpha[i];
                let c = if l > 1e-15 { a2 / l } else { 0.0 };
                (i, l, a2, c)
            })
            .collect();
        eig_data.sort_by(|a, b| a.1.partial_cmp(&b.1).unwrap());

        let total: f64 = eig_data.iter().map(|d| d.3).sum();
        let d2 = 1.0 - total;

        // Find mode with largest contribution
        let dominant = eig_data.iter()
            .enumerate()
            .max_by(|a, b| a.1.3.partial_cmp(&b.1.3).unwrap())
            .unwrap();

        writeln!(dominant_file, "{},{:.6},{:.10},{},{:.15},{:.10},{:.10},{:.6}",
            n, log_n, d2,
            dominant.0, // rank (0 = smallest eigenvalue)
            dominant.1.1, // lambda
            dominant.1.2, // alpha²
            dominant.1.3, // contribution
            dominant.1.3 / total  // fraction
        ).unwrap();

        // Print the top 5 contributing modes
        let mut by_contrib = eig_data.clone();
        by_contrib.sort_by(|a, b| b.3.partial_cmp(&a.3).unwrap());

        println!("\n  N={}: d²={:.8}, top contributing modes:", n, d2);
        println!("    {:>5}  {:>12}  {:>12}  {:>12}  {:>8}",
            "rank", "λ", "α²", "α²/λ", "% total");
        for (rank_in_contrib, (_orig_idx, lambda, a2, contrib)) in by_contrib.iter().take(5).enumerate() {
            let eig_rank = eig_data.iter().position(|d| (d.1 - lambda).abs() < 1e-15).unwrap_or(0);
            println!("    {:>5}  {:>12.6e}  {:>12.6e}  {:>12.6e}  {:>7.2}%",
                eig_rank, lambda, a2, contrib, contrib / total * 100.0);
            let _ = rank_in_contrib; // suppress warning
        }
    }

    let final_elapsed = start.elapsed();
    println!("\n{}", "═".repeat(85));
    println!("COMPLETE. Total time: {:.1}s", final_elapsed.as_secs_f64());
    println!("Output files in results/:");
    println!("  spectral_summary.csv     — per-N summary (d², λ_min, λ_max, etc)");
    println!("  eigenvalue_spectrum.csv  — all eigenvalues for select N");
    println!("  eigenvalue_scaling.csv   — bottom eigenvalues vs N");
    println!("  dominant_modes.csv       — which mode dominates bᵀG⁻¹b");
    println!("  spectral_report.txt      — summary");

    writeln!(report, "\nTotal time: {:.1}s", final_elapsed.as_secs_f64()).unwrap();
    writeln!(report, "\nKey questions answered:").unwrap();
    writeln!(report, "  1. Does λ_min·logN converge? → check spectral_summary.csv").unwrap();
    writeln!(report, "  2. Which mode dominates bᵀG⁻¹b? → check dominant_modes.csv").unwrap();
    writeln!(report, "  3. How does λ_min scale? → check eigenvalue_scaling.csv").unwrap();
    writeln!(report, "  4. Is d² controlled by one mode or many? → check eigenvalue_spectrum.csv").unwrap();
}

/// b_k = ∫₀¹ {k/x} dx via exact series (converges fast)
fn compute_basis_ip(k: usize) -> f64 {
    let kf = k as f64;
    let mut sum = 0.0;
    for n in k..=(10 * k + 50000) {
        let nf = n as f64;
        sum += kf * ((nf + 1.0) / nf).ln() - kf / (nf + 1.0);
    }
    sum
}

/// Compute full Gram matrix using single-pass quadrature
fn compute_gram_matrix_fast(n_max: usize) -> Vec<Vec<f64>> {
    let mut g = vec![vec![0.0f64; n_max + 1]; n_max + 1];
    let dx = 1.0 / QUAD_PTS as f64;
    for i in 0..QUAD_PTS {
        let x = (i as f64 + 0.5) * dx;
        let fracs: Vec<f64> = (0..=n_max)
            .map(|j| if j == 0 { 0.0 } else { fract(j as f64 / x) })
            .collect();
        for j in 1..=n_max {
            let fj = fracs[j];
            if fj.abs() < 1e-15 { continue; }
            for k in j..=n_max {
                g[j][k] += fj * fracs[k];
            }
        }
    }
    for j in 1..=n_max {
        for k in j..=n_max {
            g[j][k] *= dx;
            g[k][j] = g[j][k];
        }
    }
    g
}

fn fract(x: f64) -> f64 { x - x.floor() }
