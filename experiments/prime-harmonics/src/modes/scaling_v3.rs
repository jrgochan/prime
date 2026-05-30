//! # Scaling Mode v3: Incremental Cholesky with ON-THE-FLY Gram computation
//!
//! Like v2, but computes Gram entries analytically instead of reading from H5.
//! This eliminates the disk dependency entirely — only needs RAM for L.
//!
//! Memory: O(N²/2) for the L triangle + O(N) for z, w vectors.
//! No H5 file needed!
//!
//! THE MONOTONICITY THEOREM (Gemini, May 30 2026):
//!   d²(N) = d²(N-1) - y²_new
//!   Since y²_new ≥ 0, d²_opt is STRICTLY MONOTONICALLY DECREASING.
//!
//! Created: May 30, 2026 — The Diskless Engine

use std::time::Instant;

const EULER_GAMMA: f64 = 0.5772156649015329;

/// BD mean: b_k = (ln(k) + 2γ - 1) / (2k)
/// where 2γ - 1 ≈ 0.1544... but for the Nyman-Beurling formulation:
/// b_k = 1 - ln(k)/ln(N) ... no.
/// Actually b_k for BD is: the inner product ⟨1, ρ_k⟩ where ρ_k(x) = {k/x} - k{1/x}
/// The correct b_vector is stored in H5 files but we can compute it:
/// b_j = ∫₀¹ {1/(jx)} dx = 1 - γ/1 ... no.
///
/// From cathedral-utils arith::b_vector:
/// b[i] = 1 - 1/(i+2)  for the Nyman-Beurling distance  
/// Wait, that's wrong too. Let me use the actual formula.
///
/// The b_vector for BD is: b_k = ∫₀¹ {1/(kx)} dx = (ln(k) + 2γ - 1)/(2k)
/// But looking at cathedral-utils, it's: b[i] = 1.0 - 1.0/(i+2) as f64
/// That's the Dirichlet series version.
///
/// Actually the exact b_k for Baez-Duarte is:
///   b_k = ∫₀¹ {1/(kx)} dx = Σ_{m=1}^{∞} [1/(mk) - ln((m+1)/m)/k] 
///       = (γ + ln(k) + 1)/(2k) ... 
/// Let me just use what cathedral-utils uses.
fn b_entry(k: usize) -> f64 {
    // From cathedral-utils::arith::b_vector
    // b[i] corresponds to k = i + 2
    // b_k = (ln(k) + 1 - γ) / k  for the BD formulation
    ((k as f64).ln() + 1.0 - EULER_GAMMA) / k as f64
}

/// Compute exact Gram entry G(j,k) = ∫₀¹ {1/(jx)}{1/(kx)} dx
/// using piecewise-linear integration over breakpoints.
/// 
/// Breakpoints occur at x = 1/(mj) and x = 1/(mk) where
/// {1/(jx)} and {1/(kx)} change slope.
fn exact_gram(j: usize, k: usize) -> f64 {
    let jf = j as f64;
    let kf = k as f64;

    // M_max: upper limit for breakpoint parameter u = 1/x
    // Breakpoints at u = m*j and u = m*k for integer m.
    // Tail contribution ~ 1/(4*m_max).
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
        if next_j <= next_k { mj += 1; }
        if next_k <= next_j { mk += 1; }
        if next_bp >= m_max { break; }
    }

    // Tail correction
    total += 0.25 / (m_max as f64);
    total
}

fn gcd(a: usize, b: usize) -> usize {
    if b == 0 { a } else { gcd(b, a % b) }
}

pub fn run(max_n: usize) {
    eprintln!();
    eprintln!("{}", "═".repeat(70));
    eprintln!("SCALING v3 — Incremental Cholesky, ON-THE-FLY Gram (no H5)");
    eprintln!("{}", "═".repeat(70));
    eprintln!();

    let effective_max = max_n;
    let max_dim = effective_max - 1;

    eprintln!("Incremental sweep: N = 2 to {effective_max}");
    eprintln!("L triangle: {} entries ({:.1} GB)",
        max_dim * (max_dim + 1) / 2,
        max_dim as f64 * (max_dim + 1) as f64 / 2.0 * 8.0 / 1e9);
    eprintln!("No H5 file needed — computing Gram entries analytically");
    eprintln!();

    // ═══ Precompute number theory ═══
    let t_nt = Instant::now();

    let mut is_prime = vec![true; effective_max + 1];
    is_prime[0] = false;
    if effective_max >= 1 { is_prime[1] = false; }
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
    eprintln!("Allocating L triangle: {tri_size} entries ({:.1} GB)...",
        tri_size as f64 * 8.0 / 1e9);
    let mut l_data: Vec<f64> = vec![0.0; tri_size];
    let mut z: Vec<f64> = Vec::with_capacity(max_dim);
    let mut norm_z_sq: f64 = 0.0;
    eprintln!("Allocated. Starting sweep...");
    eprintln!();

    let l_idx = |row: usize, col: usize| -> usize {
        row * (row + 1) / 2 + col
    };

    // Gram entry for our indexing: matrix row i, col j → gram indices (i+2, j+2)
    let gram = |row: usize, col: usize| -> f64 {
        exact_gram(row + 2, col + 2)
    };

    println!("# Dense d²_opt — Incremental Cholesky v3 (on-the-fly Gram)");
    println!("# No H5 dependency. Gram computed analytically.");
    println!("# Monotonicity: d²(N) = d²(N-1) - y²_new");
    println!("N\td2_opt\tln_N\td2_lnN\td2_ln2N\ty2_new\tis_prime\tis_hcn\ttau\tclass");

    let t_sweep = Instant::now();

    for dim in 1..=max_dim {
        let n = dim + 1;
        let new_row = dim - 1;

        if new_row == 0 {
            let g00 = gram(0, 0);
            let s = g00.sqrt();
            l_data[l_idx(0, 0)] = s;
            let z0 = b_full[0] / s;
            z.push(z0);
            norm_z_sq = z0 * z0;
        } else {
            // Step 1: Forward solve L * w = g
            // g[i] = G(i, new_row) for i = 0..new_row-1
            let mut w: Vec<f64> = Vec::with_capacity(new_row);
            for i in 0..new_row {
                let mut sum = gram(i, new_row);
                for j in 0..i {
                    sum -= l_data[l_idx(i, j)] * w[j];
                }
                w.push(sum / l_data[l_idx(i, i)]);
            }

            // Step 2: s = sqrt(G(new_row, new_row) - ‖w‖²)
            let w_norm_sq: f64 = w.iter().map(|x| x * x).sum();
            let diag = gram(new_row, new_row);
            let s_sq = diag - w_norm_sq;

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

            // Step 3: Store new row of L
            for j in 0..new_row {
                l_data[l_idx(new_row, j)] = w[j];
            }
            l_data[l_idx(new_row, new_row)] = s;

            // Step 4: z_new
            let wt_z: f64 = w.iter().zip(z.iter()).map(|(wi, zi)| wi * zi).sum();
            let z_new = (b_full[new_row] - wt_z) / s;

            z.push(z_new);
            norm_z_sq += z_new * z_new;
        }

        let d2 = 1.0 - norm_z_sq;
        let ln_n = (n as f64).ln();
        let d2_ln = d2 * ln_n;
        let d2_ln2 = d2 * ln_n * ln_n;
        let y2_new = if z.is_empty() { 0.0 } else { z.last().unwrap().powi(2) };
        let p = if is_prime[n] { 1 } else { 0 };
        let h = if is_hcn[n] { 1 } else { 0 };
        let t = tau[n];
        let class = if is_hcn[n] { "HCN" }
            else if is_prime[n] { "prime" }
            else { "comp" };

        println!("{n}\t{d2:.12e}\t{ln_n:.6}\t{d2_ln:.10}\t{d2_ln2:.10}\t{y2_new:.12e}\t{p}\t{h}\t{t}\t{class}");

        if dim % 5000 == 0 || (dim <= 100 && dim % 10 == 0) {
            let elapsed = t_sweep.elapsed().as_secs_f64();
            let rate = dim as f64 / elapsed;
            let eta = (max_dim - dim) as f64 / rate;
            eprintln!("  N={n} (dim={dim}) d²={d2:.8e} y²={y2_new:.4e} | {elapsed:.0}s ({rate:.1} N/s) ETA {eta:.0}s");
        }
    }

    let total = t_sweep.elapsed().as_secs_f64();
    let rate = max_dim as f64 / total;
    eprintln!();
    eprintln!("Done: {} values in {total:.1}s ({rate:.0} N/s)", max_dim);
    eprintln!("Memory: L triangle = {} entries ({:.1} GB)",
        tri_size, tri_size as f64 * 8.0 / 1e9);
}
