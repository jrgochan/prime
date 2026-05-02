//! ╔══════════════════════════════════════════════════════════════════════╗
//! ║  🔭 THE SPECTRAL OBSERVATORY                                       ║
//! ║                                                                     ║
//! ║  Experiment: Quantum Decoupling of the Riemann Vacuum               ║
//! ║                                                                     ║
//! ║  Hypothesis: The macroscopic target vector b must be orthogonal to  ║
//! ║  the low-eigenvalue eigenstates of the Gram matrix G_N.             ║
//! ║                                                                     ║
//! ║    c_k² = |⟨b, v_k⟩|² must decay FASTER than λ_k                   ║
//! ║                                                                     ║
//! ║  so that E_k = c_k²/λ_k → 0 as λ_k → 0.                           ║
//! ║                                                                     ║
//! ║  Key formula:                                                       ║
//! ║    d²_N = 1 - Σ_k c_k² / λ_k                                       ║
//! ║                                                                     ║
//! ║  If the spectral sum → 1 as N → ∞, then d² → 0 and RH holds.       ║
//! ║                                                                     ║
//! ║  Cathedral Core Team — April 30, 2026                               ║
//! ╚══════════════════════════════════════════════════════════════════════╝

use cathedral_utils::arith::{b_vector, EULER_GAMMA};
use cathedral_utils::cache::{self, load_gram};
use nalgebra::DMatrix;
use std::path::PathBuf;
use std::time::Instant;

fn main() {
    println!();
    println!("╔══════════════════════════════════════════════════════════════════╗");
    println!("║  🔭 THE SPECTRAL OBSERVATORY                                   ║");
    println!("║  Quantum Decoupling of the Riemann Vacuum                      ║");
    println!("║  Cathedral Core Team — April 30, 2026                          ║");
    println!("╚══════════════════════════════════════════════════════════════════╝");

    // Determine which N values to run
    let args: Vec<String> = std::env::args().skip(1).collect();
    let sizes: Vec<usize> = if args.is_empty() {
        vec![100, 500, 1000, 2000, 5000]
    } else {
        args.iter().filter_map(|s| s.parse().ok()).collect()
    };

    let mut all_results: Vec<SpectralResult> = Vec::new();

    for &n in &sizes {
        if let Some(result) = run_spectral_observatory(n) {
            all_results.push(result);
        } else {
            eprintln!("  ⚠ Skipping N={n} — no cache file found");
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // SCALING SUMMARY
    // ═══════════════════════════════════════════════════════════════════
    if all_results.len() >= 2 {
        println!("\n\n{}", "═".repeat(100));
        println!("  🔭 SCALING SUMMARY ACROSS ALL N");
        println!("{}", "═".repeat(100));
        println!("  {:>6} {:>5} {:>14} {:>14} {:>14} {:>8} {:>14} {:>14}",
            "N", "dim", "λ_min", "|⟨b,v_min⟩|²", "E_0", "β", "d²_N", "Σc²/λ");
        println!("  {} {} {} {} {} {} {} {}",
            "─".repeat(6), "─".repeat(5), "─".repeat(14), "─".repeat(14),
            "─".repeat(14), "─".repeat(8), "─".repeat(14), "─".repeat(14));
        for r in &all_results {
            println!("  {:6} {:5} {:14.8e} {:14.8e} {:14.8e} {:8.4} {:14.10} {:14.10}",
                r.n, r.dim, r.lambda_min, r.c_min_sq, r.e_0, r.beta, r.d_sq, r.s_total);
        }

        // β trend
        let betas: Vec<f64> = all_results.iter().map(|r| r.beta).filter(|b| b.is_finite()).collect();
        if betas.len() >= 2 {
            print!("\n  β trend: ");
            for (i, b) in betas.iter().enumerate() {
                if i > 0 { print!(" → "); }
                print!("{b:.4}");
            }
            println!();
            if *betas.last().unwrap() > 1.0 {
                println!("  ✅ β > 1 at largest N → QUANTUM DECOUPLING CONFIRMED");
            } else if *betas.last().unwrap() > 0.0 {
                println!("  ⚠️  β > 0 but < 1 — MARGINAL decoupling at largest N");
            } else {
                println!("  ❌ β ≤ 0 at largest N — NO decoupling");
            }
        }

        // E_0 trend
        let e0s: Vec<f64> = all_results.iter().map(|r| r.e_0).collect();
        print!("\n  E_0 trend: ");
        for (i, e) in e0s.iter().enumerate() {
            if i > 0 { print!(" → "); }
            print!("{e:.4e}");
        }
        println!();

        // d² trend
        let d_sqs: Vec<f64> = all_results.iter().map(|r| r.d_sq).collect();
        print!("  d²  trend: ");
        for (i, d) in d_sqs.iter().enumerate() {
            if i > 0 { print!(" → "); }
            print!("{d:.8}");
        }
        println!();
    }

    println!("\n  🔭 Observatory complete.");
}


struct SpectralResult {
    n: usize,
    dim: usize,
    lambda_min: f64,
    c_min_sq: f64,
    e_0: f64,
    beta: f64,
    d_sq: f64,
    d_sq_direct: f64,
    s_total: f64,
}

fn run_spectral_observatory(n: usize) -> Option<SpectralResult> {
    println!("\n{}", "═".repeat(72));
    println!("  🔭 SPECTRAL OBSERVATORY — N = {n}");
    println!("{}", "═".repeat(72));

    // ═══════════════════════════════════════════════════════════════════
    // Step 1: Load Gram matrix from cache
    // ═══════════════════════════════════════════════════════════════════
    let t0 = Instant::now();

    // Try standard Gram cache first, then DD cache (hi part only)
    let cache_candidates = [
        cache::gram_cache_path(n, 106),  // MPFR-106 (quad precision)
        cache::gram_cache_path(n, 128),  // MPFR-128
        cache::gram_cache_path(n, 256),  // MPFR-256
        cache::gram_cache_path(n, 0),    // plain f64
    ];

    let (data, dim) = if let Some(gram) = cache_candidates.iter().find_map(|path| {
        if path.exists() {
            eprintln!("  Trying standard: {}", path.display());
            load_gram(path)
        } else {
            None
        }
    }) {
        let dim = gram.max_dim;
        assert_eq!(dim, n - 1, "Gram matrix dimension mismatch");
        (gram.data, dim)
    } else {
        // Try DD cache (use hi part only for f64 eigendecomposition)
        let dd_candidates = [
            cache::dd_gram_cache_path(n, 256),
            cache::dd_gram_cache_path(n, 128),
            cache::dd_gram_cache_path(n, 106),
        ];
        if let Some((hi, _lo, dim)) = dd_candidates.iter().find_map(|path| {
            if path.exists() {
                eprintln!("  Trying DD: {}", path.display());
                cache::load_dd_gram(path)
            } else {
                None
            }
        }) {
            assert_eq!(dim, n - 1, "DD Gram matrix dimension mismatch");
            (hi, dim)
        } else {
            return None;
        }
    };

    let t_load = t0.elapsed().as_secs_f64();
    let mem_mb = (dim * dim * 8) / (1024 * 1024);
    println!("  Gram matrix loaded: dim={dim} ({t_load:.2}s, {mem_mb} MB)");

    // ═══════════════════════════════════════════════════════════════════
    // Step 2: Build b-vector
    // ═══════════════════════════════════════════════════════════════════
    let b = b_vector(dim);
    let b_norm: f64 = b.iter().map(|x| x * x).sum::<f64>().sqrt();
    println!("  ‖b‖ = {b_norm:.8}");

    // ═══════════════════════════════════════════════════════════════════
    // Step 3: Full eigendecomposition
    // ═══════════════════════════════════════════════════════════════════
    let t0 = Instant::now();
    let eig_mem_gb = (dim * dim * 8 * 3) as f64 / (1024.0 * 1024.0 * 1024.0);
    println!("  Computing full eigendecomposition (dim={dim}, ~{eig_mem_gb:.1} GB)...");
    let g_mat = DMatrix::from_row_slice(dim, dim, &data);
    drop(data); // free the raw data to save memory
    let eigen = g_mat.clone().symmetric_eigen();
    let t_eig = t0.elapsed().as_secs_f64();
    println!(" done ({t_eig:.1}s)");

    // Sort eigenvalues ascending and keep track of original indices
    let mut indexed_eigs: Vec<(f64, usize)> = eigen.eigenvalues
        .iter()
        .enumerate()
        .map(|(i, &v)| (v, i))
        .collect();
    indexed_eigs.sort_by(|a, b| a.0.partial_cmp(&b.0).unwrap());

    let eigenvalues: Vec<f64> = indexed_eigs.iter().map(|(v, _)| *v).collect();
    let sorted_indices: Vec<usize> = indexed_eigs.iter().map(|(_, i)| *i).collect();

    let lambda_min = eigenvalues[0];
    let lambda_max = eigenvalues[dim - 1];
    let cond = if lambda_min > 0.0 { lambda_max / lambda_min } else { f64::INFINITY };
    println!("  λ_min = {lambda_min:.8e}");
    println!("  λ_max = {lambda_max:.8e}");
    println!("  cond(G) = {cond:.4e}");

    // ═══════════════════════════════════════════════════════════════════
    // Step 4: Projection amplitudes c_k = ⟨b, v_k⟩
    // ═══════════════════════════════════════════════════════════════════
    let b_vec = nalgebra::DVector::from_row_slice(&b);
    let mut c_sq = vec![0.0f64; dim];
    for (sorted_k, &orig_idx) in sorted_indices.iter().enumerate() {
        let v_k = eigen.eigenvectors.column(orig_idx);
        let c_k = b_vec.dot(&v_k);
        c_sq[sorted_k] = c_k * c_k;
    }

    // ═══════════════════════════════════════════════════════════════════
    // Step 5: Spectral energy distribution E_k = c_k² / λ_k
    // ═══════════════════════════════════════════════════════════════════
    let mut e_k: Vec<f64> = vec![0.0; dim];
    for k in 0..dim {
        if eigenvalues[k] > 1e-30 {
            e_k[k] = c_sq[k] / eigenvalues[k];
        } else {
            e_k[k] = f64::INFINITY;
        }
    }

    // Cumulative spectral sum
    let mut s_cumulative = vec![0.0f64; dim];
    s_cumulative[0] = e_k[0];
    for k in 1..dim {
        s_cumulative[k] = s_cumulative[k - 1] + e_k[k];
    }
    let s_total = s_cumulative[dim - 1];

    // The distance
    let d_sq = 1.0 - s_total;

    // Direct computation for cross-check (skip for large matrices to save memory)
    let d_sq_direct = if dim <= 8000 {
        let lu = g_mat.clone().lu();
        match lu.solve(&b_vec) {
            Some(ginv_b) => 1.0 - b_vec.dot(&ginv_b),
            None => f64::NAN,
        }
    } else {
        f64::NAN // skip for large matrices
    };
    drop(g_mat); // free memory

    println!("\n  ── SPECTRAL DECOMPOSITION ──");
    println!("  Σ c_k²/λ_k = {s_total:.12}");
    println!("  d²_N = 1 - Σ c_k²/λ_k = {d_sq:.12}");
    println!("  d²_N (direct) = {d_sq_direct:.12}");
    println!("  Agreement: {:.4e}", (d_sq - d_sq_direct).abs());

    // ═══════════════════════════════════════════════════════════════════
    // QUANTUM DECOUPLING ANALYSIS
    // ═══════════════════════════════════════════════════════════════════
    println!("\n  ── QUANTUM DECOUPLING ANALYSIS ──");
    println!("  {:>5} {:>14} {:>14} {:>14} {:>12} {:>12}",
        "k", "λ_k", "c_k²", "E_k=c²/λ", "S_cum", "c²/λ² ratio");
    println!("  {} {} {} {} {} {}",
        "─".repeat(5), "─".repeat(14), "─".repeat(14),
        "─".repeat(14), "─".repeat(12), "─".repeat(12));

    // Show bottom 20 eigenvalues (the dangerous ones)
    let n_show_bottom = 20.min(dim);
    for k in 0..n_show_bottom {
        let c_lambda_ratio = if eigenvalues[k] > 1e-30 {
            c_sq[k] / (eigenvalues[k] * eigenvalues[k])
        } else { f64::INFINITY };
        println!("  {:5} {:14.8e} {:14.8e} {:14.8e} {:12.8} {:12.4e}",
            k, eigenvalues[k], c_sq[k], e_k[k], s_cumulative[k], c_lambda_ratio);
    }
    println!("  {:>5}", "...");

    // Show top 5
    let n_top = 5.min(dim);
    for k in (dim - n_top)..dim {
        let c_lambda_ratio = if eigenvalues[k] > 1e-30 {
            c_sq[k] / (eigenvalues[k] * eigenvalues[k])
        } else { f64::INFINITY };
        println!("  {:5} {:14.8e} {:14.8e} {:14.8e} {:12.8} {:12.4e}",
            k, eigenvalues[k], c_sq[k], e_k[k], s_cumulative[k], c_lambda_ratio);
    }

    // ═══════════════════════════════════════════════════════════════════
    // DECOUPLING POWER LAW: log(c_k²) vs log(λ_k)
    // ═══════════════════════════════════════════════════════════════════
    println!("\n  ── DECOUPLING POWER LAW ──");
    println!("  If c_k² ~ λ_k^β with β > 1, then E_k → 0 and sum converges.");

    // Fit over bottom 10%, minimum 20 modes, maximum 200
    let n_fit = (dim / 10).max(20).min(200).min(dim / 2);
    let mut log_lambda = Vec::new();
    let mut log_c_sq = Vec::new();
    for k in 0..n_fit {
        if eigenvalues[k] > 1e-30 && c_sq[k] > 1e-50 {
            log_lambda.push(eigenvalues[k].ln());
            log_c_sq.push(c_sq[k].ln());
        }
    }

    let beta = if log_lambda.len() >= 5 {
        // Simple linear regression: log(c²) = β·log(λ) + intercept
        let n_pts = log_lambda.len() as f64;
        let sum_x: f64 = log_lambda.iter().sum();
        let sum_y: f64 = log_c_sq.iter().sum();
        let sum_xy: f64 = log_lambda.iter().zip(log_c_sq.iter()).map(|(x, y)| x * y).sum();
        let sum_xx: f64 = log_lambda.iter().map(|x| x * x).sum();
        let b = (n_pts * sum_xy - sum_x * sum_y) / (n_pts * sum_xx - sum_x * sum_x);
        println!("  β = {b:.6}  (fit over bottom {n_fit} modes, {}/{n_fit} valid)",
            log_lambda.len());
        if b > 1.0 {
            println!("  ✅ β > 1: QUANTUM DECOUPLING CONFIRMED");
            println!("     c_k² decays faster than λ_k → E_k → 0 → sum converges");
        } else if b > 0.0 {
            println!("  ⚠️  0 < β < 1: MARGINAL — sum may diverge logarithmically");
        } else {
            println!("  ❌ β ≤ 0: NO DECOUPLING — low modes dominate");
        }
        b
    } else {
        println!("  (insufficient data for fit)");
        f64::NAN
    };

    // Also fit over multiple windows to check stability
    if dim >= 100 {
        println!("\n  ── MULTI-WINDOW β STABILITY ──");
        for &window_frac in &[0.05, 0.10, 0.20, 0.33] {
            let win = ((dim as f64 * window_frac) as usize).max(20);
            let mut lx = Vec::new();
            let mut ly = Vec::new();
            for k in 0..win.min(dim/2) {
                if eigenvalues[k] > 1e-30 && c_sq[k] > 1e-50 {
                    lx.push(eigenvalues[k].ln());
                    ly.push(c_sq[k].ln());
                }
            }
            if lx.len() >= 5 {
                let np = lx.len() as f64;
                let sx: f64 = lx.iter().sum();
                let sy: f64 = ly.iter().sum();
                let sxy: f64 = lx.iter().zip(ly.iter()).map(|(x, y)| x * y).sum();
                let sxx: f64 = lx.iter().map(|x| x * x).sum();
                let b = (np * sxy - sx * sy) / (np * sxx - sx * sx);
                let marker = if b > 1.0 { "✅" } else if b > 0.0 { "⚠️ " } else { "❌" };
                println!("  {marker} bottom {:.0}% ({} modes): β = {b:.4}", window_frac * 100.0, lx.len());
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // ORTHOGONALITY SHIELD
    // ═══════════════════════════════════════════════════════════════════
    println!("\n  ── ORTHOGONALITY SHIELD ──");
    println!("  |⟨b, v_min⟩|  = {:.8e}", c_sq[0].sqrt());
    println!("  |⟨b, v_min⟩|² = {:.8e}", c_sq[0]);
    println!("  λ_min          = {:.8e}", eigenvalues[0]);
    println!("  E_0 = c₀²/λ   = {:.8e}", e_k[0]);
    if d_sq > 0.0 {
        println!("  E_0 / d²_N     = {:.8e}", e_k[0] / d_sq);
    }

    // ═══════════════════════════════════════════════════════════════════
    // ENERGY CONCENTRATION
    // ═══════════════════════════════════════════════════════════════════
    println!("\n  ── ENERGY CONCENTRATION ──");
    for &threshold in &[0.50, 0.90, 0.95, 0.99, 0.999] {
        let target = threshold * s_total;
        let idx = s_cumulative.partition_point(|&x| x < target);
        if idx < dim {
            println!("  {:5.1}% of energy in modes 0..{idx} (λ > {:.4e})", threshold * 100.0, eigenvalues[idx]);
        } else {
            println!("  {:5.1}% of energy requires all {dim} modes", threshold * 100.0);
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // Save TSV data
    // ═══════════════════════════════════════════════════════════════════
    let out_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("results");
    std::fs::create_dir_all(&out_dir).ok();
    let out_file = out_dir.join(format!("spectral_N{n}.tsv"));
    let mut tsv = String::new();
    tsv.push_str("k\tlambda_k\tc_k_sq\tE_k\tS_cumulative\n");
    for k in 0..dim {
        tsv.push_str(&format!("{k}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\n",
            eigenvalues[k], c_sq[k], e_k[k], s_cumulative[k]));
    }
    std::fs::write(&out_file, &tsv).ok();
    println!("\n  Data saved to: {}", out_file.display());

    Some(SpectralResult {
        n,
        dim,
        lambda_min,
        c_min_sq: c_sq[0],
        e_0: e_k[0],
        beta,
        d_sq,
        d_sq_direct,
        s_total,
    })
}
