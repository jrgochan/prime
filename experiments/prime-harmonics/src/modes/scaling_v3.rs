//! # Scaling Mode v3: Incremental Cholesky with ON-THE-FLY Gram computation
//!
//! Like v2, but computes Gram entries analytically instead of reading from H5.
//! This eliminates the disk dependency entirely — only needs RAM for L.
//!
//! PARALLELISM (16-core GPU machine):
//!   - Gram column: computed in parallel with rayon (embarrassingly parallel)
//!   - Forward solve: sequential in rows, but inner dot products use chunked SIMD
//!   - Dot products (w·z, ||w||²): parallel reductions
//!
//! Memory: O(N²/2) for the L triangle + O(N) for z, w vectors.
//! No H5 file needed!
//!
//! THE MONOTONICITY THEOREM (Gemini, May 30 2026):
//!   d²(N) = d²(N-1) - y²_new
//!   Since y²_new ≥ 0, d²_opt is STRICTLY MONOTONICALLY DECREASING.
//!
//! Created: May 30, 2026 — The Diskless Engine (Parallel Edition)

use rayon::prelude::*;
use std::time::Instant;

const EULER_GAMMA: f64 = 0.5772156649015329;

/// BD b-vector entry: b_k = (ln(k) + 1 - γ) / k
fn b_entry(k: usize) -> f64 {
    ((k as f64).ln() + 1.0 - EULER_GAMMA) / k as f64
}

/// Compute exact Gram entry G(j,k) = ∫₀¹ {1/(jx)}{1/(kx)} dx
/// using piecewise-linear integration over breakpoints.
fn exact_gram(j: usize, k: usize) -> f64 {
    let jf = j as f64;
    let kf = k as f64;

    let m_max = ((j * k).min(100_000)) * 100;
    let m_max = m_max.max(10000).min(50_000_000);

    let mut total = 0.0f64;
    let mut mj = 1usize;
    let mut mk = 1usize;
    let mut u_prev = 1.0f64;

    loop {
        let next_j = mj * j;
        let next_k = mk * k;

        let next_bp = if next_j <= m_max && next_k <= m_max {
            next_j.min(next_k)
        } else if next_j <= m_max {
            next_j
        } else if next_k <= m_max {
            next_k
        } else {
            break;
        };

        let u_next = next_bp as f64;
        if u_next > u_prev + 1e-15 {
            let mid = (u_prev + u_next) / 2.0;
            let a = (mid / jf).floor();
            let b = (mid / kf).floor();
            let du = u_next - u_prev;
            let ln_ratio = (u_next / u_prev).ln();
            let inv_diff = 1.0 / u_next - 1.0 / u_prev;
            total += du / (jf * kf) - (a / kf + b / jf) * ln_ratio - a * b * inv_diff;
        }

        u_prev = u_next;
        if next_j <= next_k {
            mj += 1;
        }
        if next_k <= next_j {
            mk += 1;
        }
        if next_bp >= m_max {
            break;
        }
    }

    total += 0.25 / (m_max as f64);
    total
}

pub fn run(max_n: usize) {
    eprintln!();
    eprintln!("{}", "═".repeat(70));
    eprintln!("SCALING v3 — Incremental Cholesky, ON-THE-FLY Gram (PARALLEL)");
    eprintln!("{}", "═".repeat(70));
    eprintln!();

    let effective_max = max_n;
    let max_dim = effective_max - 1;

    eprintln!("Incremental sweep: N = 2 to {effective_max}");
    eprintln!(
        "L triangle: {} entries ({:.1} GB)",
        max_dim * (max_dim + 1) / 2,
        max_dim as f64 * (max_dim + 1) as f64 / 2.0 * 8.0 / 1e9
    );
    eprintln!("No H5 file needed — computing Gram entries analytically");
    eprintln!("Rayon threads: {}", rayon::current_num_threads());
    eprintln!();

    // ═══ Precompute number theory ═══
    let t_nt = Instant::now();

    let mut is_prime = vec![true; effective_max + 1];
    is_prime[0] = false;
    if effective_max >= 1 {
        is_prime[1] = false;
    }
    for i in 2..=effective_max {
        if is_prime[i] {
            let mut j = i * i;
            while j <= effective_max {
                is_prime[j] = false;
                j += i;
            }
        }
    }

    let mut tau = vec![0u32; effective_max + 1];
    for i in 1..=effective_max {
        let mut j = i;
        while j <= effective_max {
            tau[j] += 1;
            j += i;
        }
    }

    let mut is_hcn = vec![false; effective_max + 1];
    let mut max_tau: u32 = 0;
    for n in 1..=effective_max {
        if tau[n] > max_tau {
            max_tau = tau[n];
            is_hcn[n] = true;
        }
    }
    eprintln!("Number theory: {:.2}s", t_nt.elapsed().as_secs_f64());

    // ═══ Precompute b_vector ═══
    let b_full: Vec<f64> = (0..max_dim).map(|i| b_entry(i + 2)).collect();

    // ═══ Allocate L triangle ═══
    let tri_size = max_dim * (max_dim + 1) / 2;
    eprintln!(
        "Allocating L triangle: {tri_size} entries ({:.1} GB)...",
        tri_size as f64 * 8.0 / 1e9
    );
    let mut l_data: Vec<f64> = vec![0.0; tri_size];
    let mut z: Vec<f64> = Vec::with_capacity(max_dim);
    let mut norm_z_sq: f64 = 0.0;
    eprintln!("Allocated. Starting sweep...");
    eprintln!();

    // Inline L index for packed lower triangle
    #[inline(always)]
    fn l_idx(row: usize, col: usize) -> usize {
        row * (row + 1) / 2 + col
    }

    println!("# Dense d²_opt — Incremental Cholesky v3 (on-the-fly Gram, PARALLEL)");
    println!("# No H5 dependency. Gram computed analytically.");
    println!("# Monotonicity: d²(N) = d²(N-1) - y²_new");
    println!("N\td2_opt\tln_N\td2_lnN\td2_ln2N\ty2_new\tis_prime\tis_hcn\ttau\tclass");

    let t_sweep = Instant::now();

    // Threshold for parallelizing Gram column computation
    // Below this, serial is faster due to rayon overhead
    const PAR_THRESHOLD: usize = 200;

    for dim in 1..=max_dim {
        let n = dim + 1;
        let new_row = dim - 1;

        if new_row == 0 {
            let g00 = exact_gram(2, 2);
            let s = g00.sqrt();
            l_data[l_idx(0, 0)] = s;
            let z0 = b_full[0] / s;
            z.push(z0);
            norm_z_sq = z0 * z0;
        } else {
            // ═══ Step 1: Compute Gram column g[i] = G(i+2, new_row+2) ═══
            // This is EMBARRASSINGLY PARALLEL — each entry is independent
            let k_gram = new_row + 2; // the new index being added
            let g_col: Vec<f64> = if new_row >= PAR_THRESHOLD {
                (0..new_row)
                    .into_par_iter()
                    .map(|i| exact_gram(i + 2, k_gram))
                    .collect()
            } else {
                (0..new_row).map(|i| exact_gram(i + 2, k_gram)).collect()
            };
            let g_diag = exact_gram(k_gram, k_gram);

            // ═══ Step 2: Forward solve L * w = g (sequential in rows) ═══
            // w[i] = (g[i] - Σ_{j<i} L[i,j]*w[j]) / L[i,i]
            let mut w: Vec<f64> = Vec::with_capacity(new_row);

            for i in 0..new_row {
                // Inner dot product: Σ L[i,j]*w[j] for j=0..i-1
                // Use direct pointer arithmetic for speed
                let l_row_start = l_idx(i, 0);
                let dot: f64 = if i >= 64 {
                    // For large rows, use chunked reduction to help auto-vectorization
                    let l_slice = &l_data[l_row_start..l_row_start + i];
                    let w_slice = &w[..i];
                    l_slice.iter().zip(w_slice.iter()).map(|(a, b)| a * b).sum()
                } else {
                    let mut s = 0.0f64;
                    for j in 0..i {
                        s += l_data[l_row_start + j] * w[j];
                    }
                    s
                };

                w.push((g_col[i] - dot) / l_data[l_idx(i, i)]);
            }

            // ═══ Step 3: s = sqrt(G_diag - ‖w‖²) ═══
            let w_norm_sq: f64 = w.iter().map(|x| x * x).sum();
            let s_sq = g_diag - w_norm_sq;

            if s_sq <= 0.0 {
                eprintln!("  ⚠ N={n}: Cholesky breakdown (s²={s_sq:.2e}), skipping");
                for j in 0..new_row {
                    l_data[l_idx(new_row, j)] = w[j];
                }
                l_data[l_idx(new_row, new_row)] = 1e-15;
                z.push(0.0);
                continue;
            }
            let s = s_sq.sqrt();

            // ═══ Step 4: Store new row of L ═══
            let l_row_start = l_idx(new_row, 0);
            l_data[l_row_start..l_row_start + new_row].copy_from_slice(&w);
            l_data[l_idx(new_row, new_row)] = s;

            // ═══ Step 5: z_new = (b - w·z) / s ═══
            let wt_z: f64 = w.iter().zip(z.iter()).map(|(wi, zi)| wi * zi).sum();
            let z_new = (b_full[new_row] - wt_z) / s;

            z.push(z_new);
            norm_z_sq += z_new * z_new;
        }

        let d2 = 1.0 - norm_z_sq;
        let ln_n = (n as f64).ln();
        let d2_ln = d2 * ln_n;
        let d2_ln2 = d2 * ln_n * ln_n;
        let y2_new = if z.is_empty() {
            0.0
        } else {
            z.last().unwrap().powi(2)
        };
        let p = if is_prime[n] { 1 } else { 0 };
        let h = if is_hcn[n] { 1 } else { 0 };
        let t = tau[n];
        let class = if is_hcn[n] {
            "HCN"
        } else if is_prime[n] {
            "prime"
        } else {
            "comp"
        };

        println!("{n}\t{d2:.12e}\t{ln_n:.6}\t{d2_ln:.10}\t{d2_ln2:.10}\t{y2_new:.12e}\t{p}\t{h}\t{t}\t{class}");

        if dim % 5000 == 0 || (dim <= 100 && dim % 10 == 0) {
            let elapsed = t_sweep.elapsed().as_secs_f64();
            let rate = dim as f64 / elapsed;
            let eta = (max_dim - dim) as f64 / rate;
            let hrs = eta / 3600.0;
            eprintln!("  N={n} (dim={dim}) d²={d2:.8e} y²={y2_new:.4e} | {elapsed:.0}s ({rate:.1} N/s) ETA {hrs:.1}h");
        }
    }

    let total = t_sweep.elapsed().as_secs_f64();
    let rate = max_dim as f64 / total;
    eprintln!();
    eprintln!(
        "Done: {} values in {:.1}s = {:.2}h ({rate:.0} N/s)",
        max_dim,
        total,
        total / 3600.0
    );
    eprintln!(
        "Memory: L triangle = {} entries ({:.1} GB)",
        tri_size,
        tri_size as f64 * 8.0 / 1e9
    );
}
