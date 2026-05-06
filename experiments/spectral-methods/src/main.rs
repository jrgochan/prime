//! ╔══════════════════════════════════════════════════════════════════════╗
//! ║  SPECTRAL METHODS COMPARISON                                       ║
//! ║                                                                     ║
//! ║  Compares three approaches for extracting bottom eigenvalues of     ║
//! ║  the Nyman-Beurling Gram matrix:                                    ║
//! ║                                                                     ║
//! ║    §A. Full eigendecomposition (nalgebra — ground truth)            ║
//! ║    §B. Lanczos iteration with full reorthogonalization              ║
//! ║    §C. Randomized SVD (Halko-Martinsson-Tropp)                     ║
//! ║                                                                     ║
//! ║  Tests accuracy, timing, and memory at N = 500..5000.              ║
//! ║                                                                     ║
//! ║  Cathedral Core Team — May 6, 2026                                 ║
//! ╚══════════════════════════════════════════════════════════════════════╝

use cathedral_utils::fmt;
use cathedral_utils::gram::gram_entry_f64;
use cathedral_utils::lanczos;
use cathedral_utils::rsvd;
use rayon::prelude::*;
use std::time::Instant;

/// Build the Gram matrix G_N in f64 (dense, row-major).
fn build_gram(n: usize) -> (Vec<f64>, usize) {
    let dim = n - 1;
    let entries: Vec<((usize, usize), f64)> = (0..dim)
        .into_par_iter()
        .flat_map(|row| {
            (row..dim)
                .map(move |col| ((row, col), gram_entry_f64(row + 2, col + 2)))
                .collect::<Vec<_>>()
        })
        .collect();

    let mut mat = vec![0.0f64; dim * dim];
    for ((r, c), v) in entries {
        mat[r * dim + c] = v;
        mat[c * dim + r] = v;
    }
    (mat, dim)
}

/// Dense matrix-vector product: out = mat · v.
fn dense_matvec(mat: &[f64], dim: usize, v: &[f64], out: &mut [f64]) {
    for i in 0..dim {
        let mut sum = 0.0f64;
        let row_start = i * dim;
        for j in 0..dim {
            sum += mat[row_start + j] * v[j];
        }
        out[i] = sum;
    }
}

/// Shifted matvec: out = (σI - A)·v.
/// This flips the spectrum so the smallest eigenvalues of A become
/// the largest eigenvalues of (σI - A), which Lanczos/RSVD find naturally.
fn shifted_matvec(mat: &[f64], dim: usize, sigma: f64, v: &[f64], out: &mut [f64]) {
    dense_matvec(mat, dim, v, out);
    for i in 0..dim {
        out[i] = sigma * v[i] - out[i];
    }
}

/// Estimate a spectral shift σ > λ_max from the matrix diagonal.
/// Uses the trace as a rough upper bound (sum of eigenvalues).
fn estimate_sigma(mat: &[f64], dim: usize) -> f64 {
    let trace: f64 = (0..dim).map(|i| mat[i * dim + i]).sum();
    // σ = trace works as an upper bound since all eigenvalues are ≤ trace
    // for a PSD matrix. Add small margin.
    trace * 1.1
}

/// Full eigendecomposition via nalgebra (ground truth).
fn full_eigen(mat: &[f64], dim: usize) -> Vec<f64> {
    let m = nalgebra::DMatrix::from_row_slice(dim, dim, mat);
    let eigen = m.symmetric_eigen();
    let mut eigs: Vec<f64> = eigen.eigenvalues.iter().copied().collect();
    eigs.sort_by(|a, b| a.partial_cmp(b).unwrap());
    eigs
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let max_n: usize = args.get(1).and_then(|s| s.parse().ok()).unwrap_or(2000);
    let k: usize = args.get(2).and_then(|s| s.parse().ok()).unwrap_or(20);

    let start = Instant::now();
    let threads = rayon::current_num_threads();

    fmt::header(
        "SPECTRAL METHODS COMPARISON",
        &format!(
            "Lanczos vs RSVD vs Full · bottom-{k} eigenvalues · N_max = {max_n}"
        ),
        64,
        threads,
    );

    // Test schedule
    let sizes: Vec<usize> = vec![200, 500, 1000, 2000, 3000, 5000]
        .into_iter()
        .filter(|&n| n <= max_n)
        .collect();

    println!("  Test schedule: {:?}", sizes);
    println!("  Bottom k = {k} eigenvalues\n");

    // ═══════════════════════════════════════════════════════════
    // Summary collectors
    // ═══════════════════════════════════════════════════════════
    struct SizeResult {
        n: usize,
        dim: usize,
        full_time: f64,
        lanczos_time: f64,
        rsvd_time: f64,
        lanczos_err_max: f64,
        lanczos_err_mean: f64,
        rsvd_err_max: f64,
        rsvd_err_mean: f64,
        lanczos_iters: usize,
        rsvd_matvecs: usize,
        lanczos_residual_max: f64,
    }

    let mut results: Vec<SizeResult> = Vec::new();

    for &n in &sizes {
        println!("  {BOLD}{WHITE}═══ N = {n} ═══{RESET}",
            BOLD = fmt::BOLD, WHITE = fmt::WHITE, RESET = fmt::RESET);

        // Build Gram matrix
        let t0 = Instant::now();
        let (mat, dim) = build_gram(n);
        let build_time = t0.elapsed().as_secs_f64();
        println!("    Gram matrix: {dim}×{dim} ({build_time:.2}s)");

        // ─── §A. Full eigendecomposition ───
        let t0 = Instant::now();
        let full_eigs = full_eigen(&mat, dim);
        let full_time = t0.elapsed().as_secs_f64();
        let full_bottom: Vec<f64> = full_eigs.iter().take(k).copied().collect();
        println!("    §A Full:    λ_min = {:.8e}  ({full_time:.2}s)", full_bottom[0]);

        // ─── §B. Lanczos (with spectral shift for bottom eigenvalues) ───
        let sigma = estimate_sigma(&mat, dim);
        let m_lanczos = (15 * k).min(dim); // 15k subspace for tight clusters
        let mat_ref = &mat;
        let t0 = Instant::now();
        // Use shifted matrix (σI - A): largest eigenvalues of this = smallest of A
        let lanczos_shifted = lanczos::lanczos_bottom_k(
            &|v: &[f64], out: &mut [f64]| shifted_matvec(mat_ref, dim, sigma, v, out),
            dim,
            k,
            m_lanczos,
        );
        // Un-shift: λ_A = σ - λ_shifted (and reverse order since we want ascending)
        let mut lanczos_eigenvalues: Vec<f64> = lanczos_shifted.eigenvalues.iter()
            .map(|&lam| sigma - lam)
            .collect();
        // The shifted Lanczos finds the LARGEST eigenvalues of (σI-A),
        // which correspond to the SMALLEST of A. But lanczos_bottom_k
        // returns the smallest of (σI-A), so we actually want the TOP-k.
        // Let's use a direct approach: get ALL Ritz values and take the right ones.
        drop(lanczos_shifted);

        // Re-run: get the TOP-k of the shifted matrix = BOTTOM-k of A
        let (tri, basis) = lanczos::lanczos_tridiag(
            &|v: &[f64], out: &mut [f64]| shifted_matvec(mat_ref, dim, sigma, v, out),
            dim,
            m_lanczos,
            None,
        );
        let (ritz_values, ritz_vectors) = lanczos::tridiag_eigen(&tri);
        // Take the TOP k (largest of shifted = smallest of A)
        let n_ritz = ritz_values.len();
        let top_start = n_ritz.saturating_sub(k);
        lanczos_eigenvalues = ritz_values[top_start..].iter()
            .map(|&lam| sigma - lam)
            .collect();
        lanczos_eigenvalues.sort_by(|a, b| a.partial_cmp(b).unwrap());

        // Recover eigenvectors for the top-k Ritz vectors
        let mut lanczos_eigenvectors = Vec::with_capacity(k);
        let mut lanczos_residuals = Vec::with_capacity(k);
        for idx in top_start..n_ritz {
            let rv = &ritz_vectors[idx];
            let rv_len = rv.len().min(basis.len());
            let mut v = vec![0.0f64; dim];
            for j in 0..rv_len {
                for ii in 0..dim {
                    v[ii] += rv[j] * basis[j][ii];
                }
            }
            // Residual: ‖A·v - λ·v‖
            let mut av = vec![0.0f64; dim];
            dense_matvec(mat_ref, dim, &v, &mut av);
            let lam = sigma - ritz_values[idx];
            let res: f64 = (0..dim).map(|ii| { let r = av[ii] - lam * v[ii]; r * r }).sum::<f64>().sqrt();
            lanczos_residuals.push(res);
            lanczos_eigenvectors.push(v);
        }
        // Sort eigenvectors to match eigenvalue ordering
        let mut pairs: Vec<(f64, Vec<f64>, f64)> = lanczos_eigenvalues.iter().copied()
            .zip(lanczos_eigenvectors.into_iter())
            .zip(lanczos_residuals.iter().copied())
            .map(|((e, v), r)| (e, v, r))
            .collect();
        pairs.sort_by(|a, b| a.0.partial_cmp(&b.0).unwrap());
        lanczos_eigenvalues = pairs.iter().map(|(e, _, _)| *e).collect();
        let lanczos_residual_norms: Vec<f64> = pairs.iter().map(|(_, _, r)| *r).collect();

        let lanczos_result = lanczos::LanczosResult {
            eigenvalues: lanczos_eigenvalues,
            eigenvectors: pairs.into_iter().map(|(_, v, _)| v).collect(),
            iterations: tri.m,
            residual_norms: lanczos_residual_norms,
        };
        let lanczos_time = t0.elapsed().as_secs_f64();

        // Compute errors vs ground truth
        let lanczos_k = lanczos_result.eigenvalues.len().min(k);
        let mut lanczos_errs: Vec<f64> = Vec::with_capacity(lanczos_k);
        for i in 0..lanczos_k {
            let err = (lanczos_result.eigenvalues[i] - full_bottom[i]).abs();
            lanczos_errs.push(err);
        }
        let lanczos_err_max = lanczos_errs.iter().cloned().fold(0.0f64, f64::max);
        let lanczos_err_mean = lanczos_errs.iter().sum::<f64>() / lanczos_k as f64;
        let lanczos_res_max = lanczos_result.residual_norms.iter().cloned().fold(0.0f64, f64::max);

        println!(
            "    §B Lanczos: λ_min = {:.8e}  ({lanczos_time:.2}s, m={}, err_max={:.2e}, res={:.2e})",
            lanczos_result.eigenvalues[0],
            lanczos_result.iterations,
            lanczos_err_max,
            lanczos_res_max,
        );

        // ─── §C. Randomized SVD (with spectral shift) ───
        let t0 = Instant::now();
        // RSVD on shifted matrix: finds largest of (σI-A) = smallest of A
        let rsvd_shifted = rsvd::rsvd_bottom_k(
            &|v: &[f64], out: &mut [f64]| shifted_matvec(mat_ref, dim, sigma, v, out),
            dim,
            dim.min(k + 20), // get more to pick from the top
            20,              // oversampling
            2,               // power iterations
        );
        let rsvd_time = t0.elapsed().as_secs_f64();
        // Un-shift: take the TOP-k of (σI-A) = smallest of A
        let n_rsvd = rsvd_shifted.eigenvalues.len();
        let rsvd_top_start = n_rsvd.saturating_sub(k);
        let mut rsvd_eigenvalues: Vec<f64> = rsvd_shifted.eigenvalues[rsvd_top_start..].iter()
            .map(|&lam| sigma - lam)
            .collect();
        rsvd_eigenvalues.sort_by(|a, b| a.partial_cmp(b).unwrap());
        let rsvd_result = rsvd::RsvdResult {
            eigenvalues: rsvd_eigenvalues,
            eigenvectors: vec![], // skip eigenvector recovery for RSVD comparison
            oversampling: rsvd_shifted.oversampling,
            matvecs: rsvd_shifted.matvecs,
        };

        let rsvd_k = rsvd_result.eigenvalues.len().min(k);
        let mut rsvd_errs: Vec<f64> = Vec::with_capacity(rsvd_k);
        for i in 0..rsvd_k {
            let err = (rsvd_result.eigenvalues[i] - full_bottom[i]).abs();
            rsvd_errs.push(err);
        }
        let rsvd_err_max = rsvd_errs.iter().cloned().fold(0.0f64, f64::max);
        let rsvd_err_mean = rsvd_errs.iter().sum::<f64>() / rsvd_k as f64;

        println!(
            "    §C RSVD:    λ_min = {:.8e}  ({rsvd_time:.2}s, {} matvecs, err_max={:.2e})",
            rsvd_result.eigenvalues[0],
            rsvd_result.matvecs,
            rsvd_err_max,
        );

        // Detailed comparison of bottom-k
        println!();
        println!("    {DIM}    k │       Full (exact) │         Lanczos │       err(L) │           RSVD │       err(R){RESET}",
            DIM = fmt::DIM, RESET = fmt::RESET);
        for i in 0..k.min(10) {
            let full_val = full_bottom[i];
            let lanczos_val = if i < lanczos_k { lanczos_result.eigenvalues[i] } else { f64::NAN };
            let rsvd_val = if i < rsvd_k { rsvd_result.eigenvalues[i] } else { f64::NAN };
            let l_err = if i < lanczos_k { lanczos_errs[i] } else { f64::NAN };
            let r_err = if i < rsvd_k { rsvd_errs[i] } else { f64::NAN };
            println!(
                "    {:4} │ {:18.12e} │ {:15.12e} │ {:12.4e} │ {:14.12e} │ {:12.4e}",
                i, full_val, lanczos_val, l_err, rsvd_val, r_err,
            );
        }
        if k > 10 {
            println!("    {DIM}  ... ({k} total, showing first 10){RESET}",
                DIM = fmt::DIM, RESET = fmt::RESET);
        }

        // Speedup
        let speedup_lanczos = full_time / lanczos_time;
        let speedup_rsvd = full_time / rsvd_time;
        println!();
        println!("    Speedup: Lanczos = {speedup_lanczos:.1}×, RSVD = {speedup_rsvd:.1}×");
        println!();

        results.push(SizeResult {
            n,
            dim,
            full_time,
            lanczos_time,
            rsvd_time,
            lanczos_err_max,
            lanczos_err_mean,
            rsvd_err_max,
            rsvd_err_mean,
            lanczos_iters: lanczos_result.iterations,
            rsvd_matvecs: rsvd_result.matvecs,
            lanczos_residual_max: lanczos_res_max,
        });
    }

    // ═══════════════════════════════════════════════════════════
    // SUMMARY TABLE
    // ═══════════════════════════════════════════════════════════
    println!("  {BOLD}{CYAN}╔════════════════════════════════════════════════════════════════════════════════════════╗{RESET}",
        BOLD = fmt::BOLD, CYAN = fmt::CYAN, RESET = fmt::RESET);
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}{WHITE}SPECTRAL METHODS COMPARISON — SUMMARY{RESET}",
        BOLD = fmt::BOLD, CYAN = fmt::CYAN, WHITE = fmt::WHITE, RESET = fmt::RESET);
    println!("  {BOLD}{CYAN}╠════════════════════════════════════════════════════════════════════════════════════════╣{RESET}",
        BOLD = fmt::BOLD, CYAN = fmt::CYAN, RESET = fmt::RESET);
    println!("  {BOLD}{CYAN}║{RESET}  {DIM}   N   │  Full(s) │ Lanczos(s) │ RSVD(s) │  L_err_max │  R_err_max │ L_spd │ R_spd{RESET}",
        BOLD = fmt::BOLD, CYAN = fmt::CYAN, DIM = fmt::DIM, RESET = fmt::RESET);

    for r in &results {
        let l_spd = r.full_time / r.lanczos_time;
        let r_spd = r.full_time / r.rsvd_time;
        println!(
            "  {BOLD}{CYAN}║{RESET}  {:5} │ {:8.2} │ {:10.2} │ {:7.2} │ {:10.2e} │ {:10.2e} │ {:5.1}× │ {:5.1}×",
            r.n, r.full_time, r.lanczos_time, r.rsvd_time,
            r.lanczos_err_max, r.rsvd_err_max, l_spd, r_spd,
            BOLD = fmt::BOLD, CYAN = fmt::CYAN, RESET = fmt::RESET,
        );
    }
    println!("  {BOLD}{CYAN}╚════════════════════════════════════════════════════════════════════════════════════════╝{RESET}",
        BOLD = fmt::BOLD, CYAN = fmt::CYAN, RESET = fmt::RESET);

    // JSON certificate
    let cert = serde_json::json!({
        "experiment": "spectral-methods-comparison",
        "bottom_k": k,
        "threads": threads,
        "elapsed_seconds": start.elapsed().as_secs_f64(),
        "results": results.iter().map(|r| {
            serde_json::json!({
                "N": r.n,
                "dim": r.dim,
                "full_time_s": r.full_time,
                "lanczos_time_s": r.lanczos_time,
                "rsvd_time_s": r.rsvd_time,
                "lanczos_err_max": r.lanczos_err_max,
                "lanczos_err_mean": r.lanczos_err_mean,
                "rsvd_err_max": r.rsvd_err_max,
                "rsvd_err_mean": r.rsvd_err_mean,
                "lanczos_iterations": r.lanczos_iters,
                "rsvd_matvecs": r.rsvd_matvecs,
                "lanczos_residual_max": r.lanczos_residual_max,
                "speedup_lanczos": r.full_time / r.lanczos_time,
                "speedup_rsvd": r.full_time / r.rsvd_time,
            })
        }).collect::<Vec<_>>(),
    });

    let out_dir = std::path::Path::new("results");
    std::fs::create_dir_all(out_dir).ok();
    let cert_path = out_dir.join("certificate.json");
    if let Ok(f) = std::fs::File::create(&cert_path) {
        serde_json::to_writer_pretty(f, &cert).ok();
        println!("\n  {GREEN}✓ Wrote {}{RESET}", cert_path.display(),
            GREEN = fmt::GREEN, RESET = fmt::RESET);
    }

    println!(
        "\n  {BOLD}{WHITE}Total:{RESET} {GREEN}{:.1}s{RESET} ({threads} threads)\n",
        start.elapsed().as_secs_f64(),
        BOLD = fmt::BOLD, WHITE = fmt::WHITE, GREEN = fmt::GREEN, RESET = fmt::RESET,
    );
}
