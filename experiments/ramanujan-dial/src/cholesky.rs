//! Incremental Cholesky d² engine with optional pre-computed Gram file loading.
//!
//! ## Strategy
//!
//! 1. **Try cached Gram matrix** — check `experiments/cache/` for a
//!    pre-built binary (MPFR-512 > DD > MPFR-256 > MPFR-128 > f64).
//! 2. **Fall back to bulk parallel computation** — compute all
//!    G[j,k] entries via `gram::gram_entry_f64()` using rayon.
//! 3. **Incremental Cholesky** — extend L by one row per N step,
//!    giving O(N²) per step instead of O(N³) full factorization.
//!
//! ## Precision Wall
//!
//! Standard f64 Gram entries lose positive-definiteness at N ≈ 541
//! due to the Gram matrix condition number κ(G_N) growing as ~N^4.
//! Beyond this wall, DD-precision pre-computed files are required.

use std::collections::HashSet;
use std::time::Instant;
use rayon::prelude::*;
use cathedral_utils::{arith, cache, gram};
use crate::display;

/// Massively parallel d² computation using:
///   1. Pre-computed Gram cache (if available) or bulk parallel computation
///   2. Incremental Cholesky (O(N²) per step, not O(N³))
pub fn compute_d2_parallel(max_n: usize, hcns: &[usize]) {
    let dim = max_n - 1; // indices 2..=max_n → dim entries
    let hcn_set: HashSet<usize> = hcns.iter().copied().collect();

    // ── Step 1: Load or compute Gram matrix ─────────────────────
    let t0 = Instant::now();

    let gram_flat = try_load_cached_gram(max_n, dim)
        .unwrap_or_else(|| compute_gram_parallel(max_n, dim));

    let gram_time = t0.elapsed().as_secs_f64();

    // ── Step 2: b-vector ────────────────────────────────────────
    let b = arith::b_vector(dim);

    // ── Step 3: Incremental Cholesky ────────────────────────────
    let t0 = Instant::now();
    println!("  Phase 2: Incremental Cholesky (N=2..{})...", max_n);
    println!();
    println!("  {:>6} {:>14} {:>6} {:>6} {:>10} {:>20} {:>3}",
        "N", "d²_N", "d(N)", "ω(N)", "type", "factorization", "");
    println!("  {:>6} {:>14} {:>6} {:>6} {:>10} {:>20} {:>3}",
        "──────", "──────────────", "──────", "──────",
        "──────────", "────────────────────", "───");

    let mut l = vec![0.0f64; dim * dim];
    let mut prev_d2 = f64::MAX;
    let mut anomalies = 0usize;
    let colossal_set = display::COLOSSAL_SET.clone();

    for n in 2..=max_n {
        let cur_dim = n - 1;
        let new_idx = cur_dim - 1;

        // ── Extend L by one row ─────────────────────────────────
        for k in 0..new_idx {
            let mut s = 0.0f64;
            for m in 0..k {
                s += l[new_idx * dim + m] * l[k * dim + m];
            }
            l[new_idx * dim + k] = (gram_flat[new_idx * dim + k] - s) / l[k * dim + k];
        }

        let mut diag_sum = 0.0f64;
        for m in 0..new_idx {
            diag_sum += l[new_idx * dim + m] * l[new_idx * dim + m];
        }
        let diag = gram_flat[new_idx * dim + new_idx] - diag_sum;
        if diag <= 0.0 {
            let type_str = display::classify(n, &hcn_set);
            println!("  {:>6} {:>14} {:>6} {:>6} {:>10} {:>20}",
                n, "CHOL FAIL", display::count_divisors(n),
                arith::small_omega(n), type_str, arith::factorize(n));
            anomalies += 1;
            continue;
        }
        l[new_idx * dim + new_idx] = diag.sqrt();

        // ── Forward solve: L y = b[0..cur_dim] ─────────────────
        let mut y = vec![0.0f64; cur_dim];
        for i in 0..cur_dim {
            let mut s = 0.0f64;
            for jj in 0..i {
                s += l[i * dim + jj] * y[jj];
            }
            y[i] = (b[i] - s) / l[i * dim + i];
        }

        // d² = 1 - ||y||²
        let y_norm_sq: f64 = y.iter().map(|v| v * v).sum();
        let d2 = 1.0 - y_norm_sq;

        let type_str = display::classify(n, &hcn_set);
        let descent = if d2 < prev_d2 { "↓" } else { "↑" };
        if d2 > prev_d2 { anomalies += 1; }

        // Print notable N values; sparse for large N
        let is_notable = hcn_set.contains(&n)
            || display::is_prime(n)
            || n <= 60
            || d2 > prev_d2
            || n % 500 == 0
            || colossal_set.contains(&(n as u64));

        if is_notable {
            println!("  {:>6} {:>14.10} {:>6} {:>6} {:>10} {:>20} {}",
                n, d2, display::count_divisors(n),
                arith::small_omega(n), type_str,
                arith::factorize(n), descent);
        }

        prev_d2 = d2;
    }

    let chol_time = t0.elapsed().as_secs_f64();
    println!();
    println!("  ✓ Incremental Cholesky completed in {:.2}s", chol_time);
    println!("  ✓ Total time: {:.2}s (Gram) + {:.2}s (Cholesky) = {:.2}s",
        gram_time, chol_time, gram_time + chol_time);
    println!("  ✓ Monotonicity anomalies: {} (expected 0 for exact arithmetic)",
        anomalies);
    println!();
}

/// Try to load a pre-computed Gram matrix from the binary cache.
///
/// Searches for the highest-precision available file:
/// MPFR-512 > DD (106) > MPFR-256 > MPFR-128 > f64.
fn try_load_cached_gram(max_n: usize, dim: usize) -> Option<Vec<f64>> {
    let precisions = [512, 106, 256, 128, 0];
    for &p in &precisions {
        let path = cache::gram_cache_path(max_n, p);
        if let Some(g) = cache::load_gram(&path) {
            if g.max_n >= max_n {
                let prec_str = match p {
                    0 => "f64".to_string(),
                    106 => "double-double".to_string(),
                    p => format!("{p}-bit MPFR"),
                };
                println!("  ✓ Loaded cached {} Gram matrix (N={}, {} MB)",
                    prec_str, g.max_n, g.mem_mb());

                // Extract flat row-major submatrix for our dimension
                let mut flat = vec![0.0f64; dim * dim];
                for i in 0..dim {
                    for j in 0..dim {
                        flat[i * dim + j] = g.get(i + 2, j + 2);
                    }
                }
                return Some(flat);
            }
        }
    }
    None
}

/// Compute the full Gram matrix in parallel using rayon.
fn compute_gram_parallel(_max_n: usize, dim: usize) -> Vec<f64> {
    println!("  Phase 1: Bulk Gram matrix ({0}×{0} = {1} unique entries)...",
        dim, dim * (dim + 1) / 2);

    let pairs: Vec<(usize, usize)> = (0..dim)
        .flat_map(|i| (i..dim).map(move |j| (i, j)))
        .collect();

    let gram_values: Vec<((usize, usize), f64)> = pairs.par_iter()
        .map(|&(i, j)| ((i, j), gram::gram_entry_f64(i + 2, j + 2)))
        .collect();

    let mut flat = vec![0.0f64; dim * dim];
    for &((i, j), val) in &gram_values {
        flat[i * dim + j] = val;
        flat[j * dim + i] = val;
    }

    let t_entries = pairs.len();
    println!("  ✓ Gram matrix computed ({} entries)", t_entries);

    flat
}
