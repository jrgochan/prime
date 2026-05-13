//! Prime Core Lanczos Probe — Matrix-Free N=1M Prime Core Test
//!
//! Tests the Prime Core Conjecture at arbitrary N without storing the
//! full Gram matrix, using matrix-free Lanczos iteration.
//!
//! Algorithm:
//!   1. Build G_P (10×10 prime subblock), eigendecompose → sentinel u
//!   2. Zero-pad u to dim N-1 → starting vector v₀
//!   3. Run Lanczos(G_N, v₀, k=15, m=100) with matrix-free matvec
//!   4. Report overlap between Ritz vectors and G_P eigenvectors
//!
//! Usage:
//!   cargo run --release --bin prime-core-probe -- 100000
//!   cargo run --release --bin prime-core-probe -- 1000000

use cathedral_utils::arith;
use cathedral_utils::lanczos;
use rayon::prelude::*;
use std::time::Instant;

// ═══════════════════════════════════════════════════════════════
// FAST F64 GRAM ENTRY — Kahan-summation with low T
//
// For Lanczos we only need f64 accuracy (~15 digits).
// Truncating at T=5000 gives ~12 correct digits for most entries.
// For j,k > T, we short-circuit with analytic estimate.
// ═══════════════════════════════════════════════════════════════

/// Default truncation horizon for CPU Lanczos matvec.
/// T=5000 gives ~12 digits, T=1000 gives ~10 (sufficient for GPU).
const T_DEFAULT_CPU: usize = 5_000;
const T_DEFAULT_GPU: usize = 1_000;

/// Compute Gram entry G(j,k) for Lanczos matvec.
///
/// Uses Kahan-summation loop truncated at t_max with Euler-Maclaurin
/// tail correction. For entries where j,k >> T, uses asymptotic formula.
#[inline]
fn gram_entry_lanczos(j: usize, k: usize, t_max: usize) -> f64 {
    let jf = j as f64;
    let kf = k as f64;
    let inv_jk = 1.0 / (jf * kf);
    let g = arith::gcd(j, k);

    // Short-circuit for j,k >> T: asymptotic estimate
    if j > t_max && k > t_max {
        // Series is T/(jk) + tail correction
        let d = g as f64;
        let tail_mean = 0.25 + d * d / (12.0 * jf * kf);
        let inv_t = 1.0 / t_max as f64;
        return t_max as f64 * inv_jk
            + tail_mean * inv_t
            + tail_mean * 0.5 * inv_t * inv_t;
    }

    let inv_kf = 1.0 / kf;
    let inv_jf = 1.0 / jf;
    let lcm_jk = (j / g) * k;
    let min_terms = (lcm_jk * 3).max(500).min(t_max);

    let (mut total, mut comp) = (0.0f64, 0.0f64);
    for n in 1..=t_max {
        let nf = n as f64;
        let a_int = n / j;
        let b_int = n / k;

        // ln(1+1/n) approximation
        let ln_term = if n < 32 {
            (1.0 + 1.0 / nf).ln()
        } else {
            let x = 1.0 / nf;
            x * (1.0 - x * (0.5 - x * (1.0 / 3.0 - x * (0.25 - x * (0.2 - x / 6.0)))))
        };

        let ab_coeff = (a_int as f64) * inv_kf + (b_int as f64) * inv_jf;
        let ab_frac = if a_int > 0 && b_int > 0 {
            (a_int as f64) * (b_int as f64) / (nf * (nf + 1.0))
        } else {
            0.0
        };
        let term = inv_jk - ab_coeff * ln_term + ab_frac;

        // Kahan summation
        let y = term - comp;
        let t = total + y;
        comp = (t - total) - y;
        total = t;

        // Early exit if converged
        if n > min_terms && n % 500 == 0 && term.abs() < total.abs() * 1e-14 {
            break;
        }
    }

    // Euler-Maclaurin tail correction
    let d = g as f64;
    let tail_mean = 0.25 + d * d / (12.0 * jf * kf);
    let inv_t = 1.0 / t_max as f64;
    total += tail_mean * inv_t
        + tail_mean * 0.5 * inv_t * inv_t
        + tail_mean * (1.0 / 6.0) * inv_t * inv_t * inv_t;
    total
}

// ═══════════════════════════════════════════════════════════════
// MATRIX-FREE MATVEC: y = G_N · x  (Rayon-parallelized)
//
// Each row is independent → trivially parallel.
// With Rayon on 16 cores: ~16× speedup.
// ═══════════════════════════════════════════════════════════════

/// Compute y = G · x where G is the (N-1)×(N-1) Gram matrix.
/// Row i corresponds to index j = i+2 (since Gram matrix rows go 2..N).
fn gram_matvec(x: &[f64], y: &mut [f64], dim: usize, t_max: usize) {
    y.par_iter_mut().enumerate().for_each(|(i, yi)| {
        let j = i + 2;
        let mut sum = 0.0f64;
        for col in 0..dim {
            let k = col + 2;
            let v = x[col];
            if v.abs() > 1e-300 { // skip zero entries (especially early in Lanczos)
                sum += gram_entry_lanczos(j, k, t_max) * v;
            }
        }
        *yi = sum;
    });
}

// ═══════════════════════════════════════════════════════════════
// MAIN: PRIME CORE LANCZOS PROBE
// ═══════════════════════════════════════════════════════════════

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let n: usize = args.get(1)
        .and_then(|s| s.parse().ok())
        .unwrap_or(100_000);

    let k_primes: usize = args.get(2)
        .and_then(|s| s.parse().ok())
        .unwrap_or(10);

    let lanczos_m: usize = args.get(3)
        .and_then(|s| s.parse().ok())
        .unwrap_or(150);

    // Parse --gpu flag to determine T default
    let use_gpu_flag = args.iter().any(|a| a == "--gpu");
    let t_default = if use_gpu_flag { T_DEFAULT_GPU } else { T_DEFAULT_CPU };

    // Parse optional --T=<value>
    let t_max: usize = args.iter()
        .find(|a| a.starts_with("--T="))
        .and_then(|a| a[4..].parse().ok())
        .unwrap_or(t_default);

    let dim = n - 1;

    println!("╔══════════════════════════════════════════════════════════════════════╗");
    println!("║  PRIME CORE LANCZOS PROBE — Matrix-Free                            ║");
    println!("║  N = {:>10}  (dim = {:>10})                                 ║", n, dim);
    println!("║  k_primes = {:>3}   lanczos_m = {:>4}   T = {:>6}                    ║",
             k_primes, lanczos_m, t_max);
    println!("║  Threads: {:>3}                                                      ║",
             rayon::current_num_threads());
    println!("╚══════════════════════════════════════════════════════════════════════╝");
    println!();

    let t0 = Instant::now();

    // ── Step 1: Find the first k primes ≤ N ──
    eprintln!("  [1/5] Sieving primes up to {}...", n);
    let prime_sieve = arith::sieve_primes(n);
    let primes: Vec<usize> = (2..=n)
        .filter(|&p| prime_sieve[p])
        .take(k_primes)
        .collect();
    let k = primes.len();
    eprintln!("    Using {} primes: {:?}", k, primes);

    // Prime indices in the Gram matrix (0-indexed: prime p → row p-2)
    let prime_indices: Vec<usize> = primes.iter().map(|&p| p - 2).collect();

    // ── Step 2: Build G_P (k×k prime subblock) using full-precision ──
    eprintln!("  [2/5] Building G_P ({}×{}) with full-precision gram_entry_f64...", k, k);
    let t_gp = Instant::now();
    let mut gp_flat = vec![0.0f64; k * k];
    for i in 0..k {
        for j in 0..k {
            // Use the full-precision entry for the small G_P subblock
            gp_flat[i * k + j] = cathedral_utils::gram::gram_entry_f64(primes[i], primes[j]);
        }
    }
    eprintln!("    G_P built in {:.3}s", t_gp.elapsed().as_secs_f64());

    // Report G_P diagonal
    println!("  G_P diagonal:");
    for (i, &p) in primes.iter().enumerate() {
        println!("    G({},{}) = {:.12}", p, p, gp_flat[i * k + i]);
    }
    println!();

    // ── Step 3: Eigendecompose G_P ──
    eprintln!("  [3/5] Eigendecomposing G_P...");
    let gp_result = cathedral_utils::eigen::eigen_f64(&gp_flat, k);
    let gp_eigenvalues = &gp_result.eigenvalues;
    let gp_eigenvectors = &gp_result.eigenvectors;

    println!("  G_P eigenvalues:");
    for (i, &lambda) in gp_eigenvalues.iter().enumerate() {
        println!("    λ_GP[{}] = {:.10e}", i, lambda);
    }
    println!();

    // Find the sentinel (largest eigenvalue of G_P)
    let sentinel_gp_idx = gp_eigenvalues.len() - 1;
    let sentinel_u = &gp_eigenvectors[sentinel_gp_idx];
    let sentinel_gp_lambda = gp_eigenvalues[sentinel_gp_idx];
    println!("  SENTINEL: G_P eigenvalue = {:.10e}", sentinel_gp_lambda);
    println!("  SENTINEL components:");
    for (i, &p) in primes.iter().enumerate() {
        println!("    u[{}] (p={}) = {:+.8}", i, p, sentinel_u[i]);
    }
    println!();

    // ── Step 4: Build prime-seeded starting vector ──
    eprintln!("  [4/5] Building prime-seeded starting vector (dim={})...", dim);
    let mut v0 = vec![0.0f64; dim];
    for (i, &pidx) in prime_indices.iter().enumerate() {
        if pidx < dim {
            v0[pidx] = sentinel_u[i];
        }
    }
    let norm: f64 = v0.iter().map(|x| x * x).sum::<f64>().sqrt();
    if norm > 1e-15 {
        for x in &mut v0 { *x /= norm; }
    }
    eprintln!("    Starting vector: ||v0|| = 1.0, {} nonzero entries", k);

    // ── Step 5: Run Lanczos with matrix-free matvec ──
    let lanczos_k = (3 * k).min(dim);
    let m = lanczos_m.min(dim);

    // Check for GPU and parse --gpu flag
    let use_gpu = args.iter().any(|a| a == "--gpu");

    #[cfg(all(feature = "gpu", has_cuda_kernels))]
    let gpu_available = {
        if use_gpu {
            if let Some(info) = cathedral_utils::gpu::detect() {
                eprintln!("  🚀 GPU DETECTED: {} ({} MB VRAM)", info.name, info.vram_mb);
                true
            } else {
                eprintln!("  ⚠ GPU requested but not detected, falling back to CPU");
                false
            }
        } else {
            false
        }
    };
    #[cfg(not(all(feature = "gpu", has_cuda_kernels)))]
    let gpu_available = {
        if use_gpu {
            eprintln!("  ⚠ GPU support not compiled in (need --features gpu), using CPU");
        }
        false
    };

    eprintln!("  [5/5] Running Lanczos (extract={}, m={}, dim={}, {})...",
             lanczos_k, m, dim,
             if gpu_available { "GPU" } else { "CPU" });
    eprintln!("    Estimated matvec cost: {} × {} × {} = {:.2e} FLOPs/iter",
             dim, dim, t_max,
             (dim as f64) * (dim as f64) * (t_max as f64));

    let t_lanczos = Instant::now();

    // ── GPU PATH ──
    #[cfg(all(feature = "gpu", has_cuda_kernels))]
    let (tri, basis) = if gpu_available {
        use std::ffi::c_int;

        // Allocate GPU vectors
        let mut d_x: *mut f64 = std::ptr::null_mut();
        let mut d_y: *mut f64 = std::ptr::null_mut();
        let status = unsafe {
            cathedral_utils::gpu::ffi::gram_matvec_alloc(
                dim as c_int, &mut d_x, &mut d_y
            )
        };
        if status != 0 {
            eprintln!("  ✗ GPU alloc failed, falling back to CPU");
            let matvec = |x: &[f64], y: &mut [f64]| {
                let t_mv = Instant::now();
                gram_matvec(x, y, dim, t_max);
                let elapsed = t_mv.elapsed().as_secs_f64();
                unsafe {
                    MATVEC_COUNT += 1;
                    if MATVEC_COUNT <= 3 || MATVEC_COUNT % 10 == 0 {
                        eprintln!("    matvec #{}: {:.2}s (CPU)", MATVEC_COUNT, elapsed);
                    }
                }
            };
            lanczos::lanczos_tridiag(&matvec, dim, m, Some(&v0))
        } else {
            eprintln!("    GPU vectors allocated ({:.1} MB)",
                     2.0 * dim as f64 * 8.0 / 1e6);

            let gpu_matvec = |x: &[f64], y: &mut [f64]| {
                let t_mv = Instant::now();
                unsafe {
                    cathedral_utils::gpu::ffi::gram_matvec_full(
                        d_x, d_y,
                        x.as_ptr(), y.as_mut_ptr(),
                        dim as c_int, t_max as c_int,
                    );
                }
                let elapsed = t_mv.elapsed().as_secs_f64();
                unsafe {
                    MATVEC_COUNT += 1;
                    if MATVEC_COUNT <= 3 || MATVEC_COUNT % 10 == 0 {
                        eprintln!("    matvec #{}: {:.2}s (GPU 🚀)", MATVEC_COUNT, elapsed);
                    }
                }
            };

            let result = lanczos::lanczos_tridiag(&gpu_matvec, dim, m, Some(&v0));

            // Free GPU vectors
            unsafe {
                cathedral_utils::gpu::ffi::gram_matvec_free(d_x, d_y);
            }
            result
        }
    } else {
        let matvec = |x: &[f64], y: &mut [f64]| {
            let t_mv = Instant::now();
            gram_matvec(x, y, dim, t_max);
            let elapsed = t_mv.elapsed().as_secs_f64();
            unsafe {
                MATVEC_COUNT += 1;
                if MATVEC_COUNT <= 3 || MATVEC_COUNT % 10 == 0 {
                    eprintln!("    matvec #{}: {:.2}s (CPU)", MATVEC_COUNT, elapsed);
                }
            }
        };
        lanczos::lanczos_tridiag(&matvec, dim, m, Some(&v0))
    };

    // ── CPU-only PATH (no GPU feature) ──
    #[cfg(not(all(feature = "gpu", has_cuda_kernels)))]
    let (tri, basis) = {
        let matvec = |x: &[f64], y: &mut [f64]| {
            let t_mv = Instant::now();
            gram_matvec(x, y, dim, t_max);
            let elapsed = t_mv.elapsed().as_secs_f64();
            unsafe {
                MATVEC_COUNT += 1;
                if MATVEC_COUNT <= 3 || MATVEC_COUNT % 10 == 0 {
                    eprintln!("    matvec #{}: {:.2}s (CPU)", MATVEC_COUNT, elapsed);
                }
            }
        };
        lanczos::lanczos_tridiag(&matvec, dim, m, Some(&v0))
    };

    let actual_m = tri.m;

    let lanczos_time = t_lanczos.elapsed().as_secs_f64();
    eprintln!("    Lanczos done: {} iterations in {}", actual_m, format_time(lanczos_time));

    // Eigendecompose the tridiagonal
    let (ritz_values, ritz_vectors) = lanczos::tridiag_eigen(&tri);
    eprintln!("    Ritz values: {} extracted", ritz_values.len());

    // Map Ritz vectors back to original space
    eprintln!("    Mapping Ritz vectors to full space...");
    let t_map = Instant::now();
    let n_extract = lanczos_k.min(ritz_values.len());

    // Extract BOTH bottom and top Ritz vectors (prime core is near top!)
    let bottom_count = n_extract / 2;
    let top_count = n_extract - bottom_count;
    let total_ritz = ritz_values.len();

    // Collect indices to extract
    let mut extract_indices: Vec<usize> = Vec::with_capacity(n_extract);
    for i in 0..bottom_count.min(total_ritz) {
        extract_indices.push(i);
    }
    for i in 0..top_count.min(total_ritz) {
        let ri = total_ritz - 1 - i;
        if !extract_indices.contains(&ri) {
            extract_indices.push(ri);
        }
    }

    // Map selected Ritz vectors in parallel
    let mapped: Vec<(f64, Vec<f64>)> = extract_indices.par_iter().map(|&ri| {
        let mut v = vec![0.0f64; dim];
        let rv = &ritz_vectors[ri];
        let rv_len = rv.len().min(basis.len());
        for j in 0..rv_len {
            let coeff = rv[j];
            if coeff.abs() > 1e-15 {
                for idx in 0..dim {
                    v[idx] += coeff * basis[j][idx];
                }
            }
        }
        (ritz_values[ri], v)
    }).collect();

    let full_eigenvalues: Vec<f64> = mapped.iter().map(|(l, _)| *l).collect();
    let full_eigenvectors: Vec<Vec<f64>> = mapped.into_iter().map(|(_, v)| v).collect();

    eprintln!("    Mapped {} eigenvectors in {:.2}s",
             full_eigenvectors.len(), t_map.elapsed().as_secs_f64());

    println!("  Lanczos complete: {} ({} iterations, {} Ritz values)",
             format_time(lanczos_time), actual_m, ritz_values.len());
    println!();

    // ── Step 6: Find best-matching eigenvectors for each G_P mode ──
    println!("  ┌──────────────────────────────────────────────────────────────────────┐");
    println!("  │ PRIME CORE OVERLAP TEST (N={:>10}, Lanczos m={:>4})              │", n, actual_m);
    println!("  ├──────────┬───────────────┬───────────────┬──────────┬───────────────┤");
    println!("  │ G_P idx  │  λ(G_P)       │  λ(Ritz)      │ overlap  │ prime purity  │");
    println!("  ├──────────┼───────────────┼───────────────┼──────────┼───────────────┤");

    let mut sentinel_overlap = 0.0f64;
    let mut sentinel_full_lambda = 0.0f64;
    let mut sentinel_purity = 0.0f64;

    for gp_idx in 0..k {
        let u = &gp_eigenvectors[gp_idx];
        let gp_lambda = gp_eigenvalues[gp_idx];

        let mut best_overlap = 0.0f64;
        let mut best_full_idx = 0;

        for (fi, full_v) in full_eigenvectors.iter().enumerate() {
            let pi_v: Vec<f64> = prime_indices.iter().map(|&idx| {
                if idx < dim { full_v[idx] } else { 0.0 }
            }).collect();
            let pi_norm: f64 = pi_v.iter().map(|x| x * x).sum::<f64>().sqrt();
            if pi_norm < 1e-15 { continue; }

            let pi_v_norm: Vec<f64> = pi_v.iter().map(|x| x / pi_norm).collect();
            let dot: f64 = u.iter().zip(pi_v_norm.iter()).map(|(a, b)| a * b).sum();
            let overlap = dot * dot;

            if overlap > best_overlap {
                best_overlap = overlap;
                best_full_idx = fi;
            }
        }

        let best_v = &full_eigenvectors[best_full_idx];
        let prime_weight: f64 = prime_indices.iter()
            .filter(|&&idx| idx < dim)
            .map(|&idx| best_v[idx] * best_v[idx])
            .sum();
        let total_weight: f64 = best_v.iter().map(|x| x * x).sum();
        let purity = if total_weight > 1e-30 { prime_weight / total_weight } else { 0.0 };

        let star = if best_overlap > 0.95 { "★★★" }
            else if best_overlap > 0.80 { "★★ " }
            else if best_overlap > 0.50 { "★  " }
            else { "   " };

        println!("  │ {:>7}  │ {:>12.6e} │ {:>12.6e} │ {:>7.4}  │ {:>7.4}       │ {}",
                 gp_idx, gp_lambda, full_eigenvalues[best_full_idx],
                 best_overlap, purity, star);

        if gp_idx == sentinel_gp_idx {
            sentinel_overlap = best_overlap;
            sentinel_full_lambda = full_eigenvalues[best_full_idx];
            sentinel_purity = purity;
        }
    }
    println!("  └──────────┴───────────────┴───────────────┴──────────┴───────────────┘");
    println!();

    // ── Sentinel Summary ──
    println!("  ┌──────────────────────────────────────────────────────────────────────┐");
    println!("  │ SENTINEL SUMMARY                                                     │");
    println!("  ├──────────────────────────────────────────────────────────────────────┤");
    println!("  │   G_P eigenvalue:  {:.10e}                                    │", sentinel_gp_lambda);
    println!("  │   Ritz eigenvalue: {:.10e}                                    │", sentinel_full_lambda);
    println!("  │   Overlap |⟨u,πv⟩|²: {:.6}                                       │", sentinel_overlap);
    println!("  │   Prime purity:     {:.6}                                       │", sentinel_purity);
    println!("  │   λ error:          {:.4}%                                        │",
             if sentinel_gp_lambda.abs() > 1e-30 {
                 ((sentinel_gp_lambda - sentinel_full_lambda) / sentinel_gp_lambda).abs() * 100.0
             } else { 0.0 });

    if sentinel_overlap > 0.95 {
        println!("  │                                                                      │");
        println!("  │   ★★★ PRIME CORE CONJECTURE CONFIRMED at N={:>10} ★★★          │", n);
    } else if sentinel_overlap > 0.80 {
        println!("  │                                                                      │");
        println!("  │   ★★ STRONG EVIDENCE at N={:>10}                               │", n);
    } else if sentinel_overlap > 0.50 {
        println!("  │                                                                      │");
        println!("  │   ★ PARTIAL EVIDENCE at N={:>10}                                │", n);
    } else {
        println!("  │                                                                      │");
        println!("  │   ✗ Conjecture NOT supported at N={:>10}                        │", n);
    }
    println!("  └──────────────────────────────────────────────────────────────────────┘");

    // ── Ritz spectrum summary ──
    println!();
    println!("  Ritz spectrum (bottom 5 + top 5):");
    let nr = ritz_values.len();
    for i in 0..5.min(nr) {
        println!("    λ_Ritz[{}] = {:.10e}", i, ritz_values[i]);
    }
    if nr > 10 { println!("    ..."); }
    for i in (nr.saturating_sub(5))..nr {
        println!("    λ_Ritz[{}] = {:.10e}", i, ritz_values[i]);
    }

    let total_time = t0.elapsed().as_secs_f64();
    println!();
    println!("  ═══════════════════════════════════════════════════════════════");
    println!("  TOTAL TIME: {}", format_time(total_time));
    println!("  ═══════════════════════════════════════════════════════════════");
}

// Global matvec counter (used for progress reporting in the closure)
static mut MATVEC_COUNT: usize = 0;

fn format_time(secs: f64) -> String {
    if secs < 60.0 {
        format!("{:.1}s", secs)
    } else if secs < 3600.0 {
        format!("{}m {:.1}s", (secs / 60.0) as u64, secs % 60.0)
    } else {
        format!("{}h {}m", (secs / 3600.0) as u64, ((secs % 3600.0) / 60.0) as u64)
    }
}
