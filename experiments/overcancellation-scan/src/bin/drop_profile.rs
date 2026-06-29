#![allow(
    dead_code,
    unused_variables,
    unused_imports,
    unused_assignments,
    clippy::needless_range_loop,
    clippy::doc_lazy_continuation,
    non_snake_case,
    clippy::empty_line_after_doc_comments
)]
//! DROP PROFILE PROBE — Eigenvalue Drop Scaling Analysis
//!
//! Key question: How do eigenvalue drops δ_N = λ_min(G_N) - λ_min(G_{N+1}) scale?
//!
//! If δ_N ~ C/N^α with α ≈ 3, then via the telescoping identity:
//!   λ_min(N) = λ_min(N₀) - Σ_{k=N₀}^{N-1} δ_{k+1}
//!            ≈ const - Σ C/k³ ≈ const - (ζ(3) - C'/N²)
//!            ≈ C''/N²
//!
//! This would EXPLAIN and FORMALIZE the λ_min ~ 1/N² scaling!
//!
//! Uses cathedral-utils gram_entry_f64 for exact BD-basis entries.
//! Parallel eigenvalue computation via rayon + nalgebra.

use cathedral_utils::gram;
use rayon::prelude::*;
use std::time::Instant;

/// Build the Gram matrix G_N (parallel, exact BD formula)
fn build_gram(n: usize) -> Vec<f64> {
    let dim = n - 1;
    let upper_indices: Vec<(usize, usize)> = (0..dim)
        .flat_map(|j| (j..dim).map(move |k| (j, k)))
        .collect();
    let entries: Vec<(usize, usize, f64)> = upper_indices
        .par_iter()
        .map(|&(j, k)| (j, k, gram::gram_entry_f64(j + 1, k + 1)))
        .collect();
    let mut g = vec![0.0f64; dim * dim];
    for (j, k, val) in entries {
        g[j * dim + k] = val;
        g[k * dim + j] = val;
    }
    g
}

/// Compute λ_min via nalgebra eigendecomposition
fn lambda_min(g_flat: &[f64], dim: usize) -> f64 {
    let mat = nalgebra::DMatrix::from_row_slice(dim, dim, g_flat);
    let eig = mat.symmetric_eigen();
    eig.eigenvalues
        .iter()
        .cloned()
        .fold(f64::INFINITY, f64::min)
}

/// Compute λ_min and the min eigenvector
fn lambda_min_with_vec(g_flat: &[f64], dim: usize) -> (f64, Vec<f64>) {
    let mat = nalgebra::DMatrix::from_row_slice(dim, dim, g_flat);
    let eig = mat.symmetric_eigen();
    let mut min_idx = 0;
    let mut min_val = eig.eigenvalues[0];
    for i in 1..dim {
        if eig.eigenvalues[i] < min_val {
            min_val = eig.eigenvalues[i];
            min_idx = i;
        }
    }
    let v: Vec<f64> = (0..dim).map(|r| eig.eigenvectors[(r, min_idx)]).collect();
    (min_val, v)
}

/// Number of divisors of n
fn num_divisors(n: usize) -> usize {
    let mut count = 0;
    let mut d = 1;
    while d * d <= n {
        if n.is_multiple_of(d) {
            count += 1;
            if d != n / d {
                count += 1;
            }
        }
        d += 1;
    }
    count
}

fn is_prime(n: usize) -> bool {
    if n < 2 {
        return false;
    }
    if n < 4 {
        return true;
    }
    if n.is_multiple_of(2) || n.is_multiple_of(3) {
        return false;
    }
    let mut i = 5;
    while i * i <= n {
        if n.is_multiple_of(i) || n.is_multiple_of(i + 2) {
            return false;
        }
        i += 6;
    }
    true
}

fn main() {
    let t_start = Instant::now();

    println!("╔══════════════════════════════════════════════════════════════╗");
    println!("║   DROP PROFILE PROBE — Eigenvalue Drop Scaling             ║");
    println!("║   δ_N = λ_min(G_N) - λ_min(G_{{N+1}})                       ║");
    println!("║   Testing: δ_N ~ C/N^α → what is α?                       ║");
    println!("║   BD Basis · cathedral-utils · rayon parallel              ║");
    println!("╚══════════════════════════════════════════════════════════════╝");
    println!();

    // ══════════════════════════════════════════════════
    // PHASE 1: Compute λ_min for consecutive N values
    // ══════════════════════════════════════════════════

    // We need consecutive N values to get drops
    // Start at N=3 (dim=2), go up to N=500
    let max_n: usize = 500;
    let start_n: usize = 3;

    println!(
        "  PHASE 1: Computing λ_min(G_N) for N = {}..{}",
        start_n, max_n
    );
    println!(
        "  {:>5} {:>12} {:>12} {:>12} {:>10} {:>5} {:>6}",
        "N", "λ_min", "δ_N", "N³·δ_N", "N²·λ_min", "d(N)", "secs"
    );
    println!("  {}", "─".repeat(75));

    // Pre-build the largest Gram matrix, then extract submatrices
    let t0 = Instant::now();
    let full_gram = build_gram(max_n);
    let full_dim = max_n - 1;
    println!(
        "  [Built {}×{} Gram matrix in {:.1}s]",
        full_dim,
        full_dim,
        t0.elapsed().as_secs_f64()
    );

    let mut lambdas: Vec<(usize, f64)> = Vec::new();
    let mut drops: Vec<(usize, f64, usize)> = Vec::new(); // (N, δ_N, d(N))
    let mut prev_lmin = 0.0f64;

    for n in start_n..=max_n {
        let dim = n - 1;
        let t0 = Instant::now();

        // Extract sub-matrix from the full Gram matrix
        let mut sub = vec![0.0f64; dim * dim];
        for j in 0..dim {
            for k in 0..dim {
                sub[j * dim + k] = full_gram[j * full_dim + k];
            }
        }

        let lmin = lambda_min(&sub, dim);
        let elapsed = t0.elapsed().as_secs_f64();

        let drop = if n > start_n {
            (prev_lmin - lmin).max(0.0)
        } else {
            0.0
        };

        let nd = num_divisors(n);
        let n_cubed_drop = (n as f64).powi(3) * drop;
        let n_sq_lmin = (n as f64).powi(2) * lmin;

        // Print every row for N ≤ 30, then significant ones
        let show = n <= 30
            || n % 50 == 0
            || n == max_n
            || drop > 5e-6
            || nd >= 12
            || is_prime(n) && n <= 100;

        if show {
            println!(
                "  {:5} {:12.6e} {:12.6e} {:10.4} {:10.4} {:5} {:6.1}",
                n, lmin, drop, n_cubed_drop, n_sq_lmin, nd, elapsed
            );
        }

        if n > start_n {
            drops.push((n, drop, nd));
        }
        lambdas.push((n, lmin));
        prev_lmin = lmin;

        // Progress
        if n % 100 == 0 && n > 30 {
            eprintln!(
                "  ... N={} done ({:.0}s total)",
                n,
                t_start.elapsed().as_secs_f64()
            );
        }
    }

    // ══════════════════════════════════════════════════
    // PHASE 2: Drop Scaling Analysis
    // ══════════════════════════════════════════════════

    println!();
    println!("══════════════════════════════════════════════════════════════");
    println!("  PHASE 2: Drop Scaling — Power Law Fit");
    println!("══════════════════════════════════════════════════════════════");

    // Filter to drops > 0 and N ≥ 10 for the fit
    let fit_data: Vec<(f64, f64)> = drops
        .iter()
        .filter(|(n, d, _)| *n >= 10 && *d > 1e-15)
        .map(|(n, d, _)| ((*n as f64).ln(), d.ln()))
        .collect();

    if fit_data.len() >= 5 {
        let n_pts = fit_data.len() as f64;
        let sx: f64 = fit_data.iter().map(|(x, _)| x).sum();
        let sy: f64 = fit_data.iter().map(|(_, y)| y).sum();
        let sxy: f64 = fit_data.iter().map(|(x, y)| x * y).sum();
        let sx2: f64 = fit_data.iter().map(|(x, _)| x * x).sum();
        let alpha = (n_pts * sxy - sx * sy) / (n_pts * sx2 - sx * sx);
        let log_c = (sy - alpha * sx) / n_pts;
        let c_coeff = log_c.exp();
        let mean_y = sy / n_pts;
        let ss_tot: f64 = fit_data.iter().map(|(_, y)| (y - mean_y).powi(2)).sum();
        let ss_res: f64 = fit_data
            .iter()
            .map(|(x, y)| (y - (alpha * x + log_c)).powi(2))
            .sum();
        let r2 = 1.0 - ss_res / ss_tot;

        println!();
        println!(
            "  δ_N ≈ {:.4} · N^({:.4})     R² = {:.6}",
            c_coeff, alpha, r2
        );
        println!();

        if alpha > -3.5 && alpha < -2.5 {
            println!("  ┌─────────────────────────────────────────────────┐");
            println!(
                "  │ α ≈ {:.2} — CONSISTENT WITH δ_N ~ C/N³          │",
                alpha
            );
            println!("  │ This implies λ_min ~ C'/N² via telescoping!    │");
            println!("  │ The graduation path is OPEN.                    │");
            println!("  └─────────────────────────────────────────────────┘");
        } else if alpha > -4.0 && alpha < -2.0 {
            println!("  α ≈ {:.2} — near 1/N³ regime but not exact", alpha);
        } else {
            println!("  α ≈ {:.2} — unexpected scaling", alpha);
        }

        // Also fit just the tail (N > 100) for better asymptotic
        let tail_data: Vec<(f64, f64)> = drops
            .iter()
            .filter(|(n, d, _)| *n >= 100 && *d > 1e-15)
            .map(|(n, d, _)| ((*n as f64).ln(), d.ln()))
            .collect();

        if tail_data.len() >= 5 {
            let n_pts = tail_data.len() as f64;
            let sx: f64 = tail_data.iter().map(|(x, _)| x).sum();
            let sy: f64 = tail_data.iter().map(|(_, y)| y).sum();
            let sxy: f64 = tail_data.iter().map(|(x, y)| x * y).sum();
            let sx2: f64 = tail_data.iter().map(|(x, _)| x * x).sum();
            let alpha_tail = (n_pts * sxy - sx * sy) / (n_pts * sx2 - sx * sx);
            let log_c_tail = (sy - alpha_tail * sx) / n_pts;
            let c_tail = log_c_tail.exp();
            let mean_y = sy / n_pts;
            let ss_tot: f64 = tail_data.iter().map(|(_, y)| (y - mean_y).powi(2)).sum();
            let ss_res: f64 = tail_data
                .iter()
                .map(|(x, y)| (y - (alpha_tail * x + log_c_tail)).powi(2))
                .sum();
            let r2_tail = 1.0 - ss_res / ss_tot;
            println!();
            println!(
                "  Tail fit (N≥100): δ_N ≈ {:.4} · N^({:.4})  R² = {:.6}",
                c_tail, alpha_tail, r2_tail
            );
        }
    }

    // ══════════════════════════════════════════════════
    // PHASE 3: Cumulative Drop Analysis (Windowed)
    // ══════════════════════════════════════════════════

    println!();
    println!("══════════════════════════════════════════════════════════════");
    println!("  PHASE 3: Cumulative Drop Windows");
    println!("══════════════════════════════════════════════════════════════");
    println!();
    println!(
        "  {:>10} {:>12} {:>8} {:>12} {:>10}",
        "window", "Σ drops", "count", "avg drop", "ratio"
    );

    let windows: Vec<(usize, usize)> = vec![
        (3, 50),
        (50, 100),
        (100, 150),
        (150, 200),
        (200, 250),
        (250, 300),
        (300, 350),
        (350, 400),
        (400, 450),
        (450, 500),
    ];

    let mut prev_sum = 0.0f64;
    let mut window_sums: Vec<f64> = Vec::new();
    for (lo, hi) in &windows {
        let in_window: Vec<f64> = drops
            .iter()
            .filter(|(n, d, _)| *n >= *lo && *n < *hi && *d > 0.0)
            .map(|(_, d, _)| *d)
            .collect();
        let sum: f64 = in_window.iter().sum();
        let count = in_window.len();
        let avg = if count > 0 { sum / count as f64 } else { 0.0 };
        let ratio = if prev_sum > 0.0 && *lo >= 100 {
            format!("{:.4}", sum / prev_sum)
        } else {
            "-".to_string()
        };
        println!(
            "  {:>4}-{:<4} {:12.6e} {:8} {:12.6e} {:>10}",
            lo, hi, sum, count, avg, ratio
        );
        window_sums.push(sum);
        prev_sum = sum;
    }

    // ══════════════════════════════════════════════════
    // PHASE 4: Min Eigenvector Geometry (for select N)
    // ══════════════════════════════════════════════════

    println!();
    println!("══════════════════════════════════════════════════════════════");
    println!("  PHASE 4: Min-Eigenvector Geometry");
    println!("══════════════════════════════════════════════════════════════");

    for &n in &[50, 100, 200, 400] {
        let dim = n - 1;
        let mut sub = vec![0.0f64; dim * dim];
        for j in 0..dim {
            for k in 0..dim {
                sub[j * dim + k] = full_gram[j * full_dim + k];
            }
        }

        let (lmin, v_min) = lambda_min_with_vec(&sub, dim);

        // Component analysis
        let mut components: Vec<(usize, f64)> = v_min
            .iter()
            .enumerate()
            .map(|(i, &v)| (i + 1, v * v))
            .collect();
        components.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap());

        // How many components carry 50%, 90%, 99%?
        let total: f64 = components.iter().map(|(_, v)| v).sum();
        let mut cum = 0.0;
        let mut n_50 = 0;
        let mut n_90 = 0;
        let mut n_99 = 0;
        for (i, (_, v)) in components.iter().enumerate() {
            cum += v;
            if n_50 == 0 && cum >= 0.5 * total {
                n_50 = i + 1;
            }
            if n_90 == 0 && cum >= 0.9 * total {
                n_90 = i + 1;
            }
            if n_99 == 0 && cum >= 0.99 * total {
                n_99 = i + 1;
            }
        }

        // Oscillation: how many sign changes?
        let mut sign_changes = 0;
        for i in 1..dim {
            if v_min[i] * v_min[i - 1] < 0.0 {
                sign_changes += 1;
            }
        }

        // Arithmetic correlation: average |v_min[k]|² for primes vs composites
        let prime_energy: f64 = (0..dim)
            .filter(|&i| is_prime(i + 1))
            .map(|i| v_min[i] * v_min[i])
            .sum();
        let prime_count = (0..dim).filter(|&i| is_prime(i + 1)).count();
        let comp_energy: f64 = (0..dim)
            .filter(|&i| !is_prime(i + 1))
            .map(|i| v_min[i] * v_min[i])
            .sum();
        let comp_count = (0..dim).filter(|&i| !is_prime(i + 1)).count();

        println!();
        println!("  ── N = {} (dim = {}, λ_min = {:.6e}) ──", n, dim, lmin);
        println!(
            "  Components for 50% energy: {}/{} ({:.1}%)",
            n_50,
            dim,
            100.0 * n_50 as f64 / dim as f64
        );
        println!(
            "  Components for 90% energy: {}/{} ({:.1}%)",
            n_90,
            dim,
            100.0 * n_90 as f64 / dim as f64
        );
        println!(
            "  Components for 99% energy: {}/{} ({:.1}%)",
            n_99,
            dim,
            100.0 * n_99 as f64 / dim as f64
        );
        println!(
            "  Sign changes: {} ({:.1}% of max)",
            sign_changes,
            100.0 * sign_changes as f64 / (dim - 1) as f64
        );
        println!(
            "  Prime-index energy: {:.4}% ({} primes)",
            100.0 * prime_energy / total,
            prime_count
        );
        println!(
            "  Composite-index energy: {:.4}% ({} composites)",
            100.0 * comp_energy / total,
            comp_count
        );
        if prime_count > 0 && comp_count > 0 {
            let prime_avg = prime_energy / prime_count as f64;
            let comp_avg = comp_energy / comp_count as f64;
            println!(
                "  Prime/composite energy ratio: {:.4}",
                prime_avg / comp_avg
            );
        }

        // Top 10 components
        println!("  Top 10 components (k, |v_min[k]|²/total):");
        for (k, v_sq) in components.iter().take(10) {
            let pct = v_sq / total * 100.0;
            let dv = num_divisors(*k);
            let pr = if is_prime(*k) { " P" } else { "" };
            println!("    k={:4} {:.4}% d({})={}{}", k, pct, k, dv, pr);
        }
    }

    // ══════════════════════════════════════════════════
    // PHASE 5: Telescoping Consistency Check
    // ══════════════════════════════════════════════════

    println!();
    println!("══════════════════════════════════════════════════════════════");
    println!("  PHASE 5: Telescoping Consistency");
    println!("══════════════════════════════════════════════════════════════");

    let lmin_start = lambdas[0].1; // λ_min(G_3)
    let total_drop: f64 = drops.iter().map(|(_, d, _)| d).sum();
    let lmin_end = lambdas.last().unwrap().1;

    println!();
    println!("  λ_min(G_{}) = {:.10}", start_n, lmin_start);
    println!("  Σ drops     = {:.10}", total_drop);
    println!(
        "  λ_min(G_{}) - Σ drops = {:.10}",
        start_n,
        lmin_start - total_drop
    );
    println!("  λ_min(G_{}) (actual)  = {:.10}", max_n, lmin_end);
    println!(
        "  Consistency error: {:.2e}",
        (lmin_start - total_drop - lmin_end).abs()
    );

    // N² · λ_min scaling
    println!();
    println!("  N²·λ_min trend:");
    for &(n, lmin) in lambdas.iter().filter(|(n, _)| {
        *n == 10 || *n == 50 || *n == 100 || *n == 200 || *n == 300 || *n == 400 || *n == 500
    }) {
        println!("    N={:4}  N²·λ_min = {:.4}", n, (n as f64).powi(2) * lmin);
    }

    println!();
    println!("  Total runtime: {:.1}s", t_start.elapsed().as_secs_f64());
    println!();
}
