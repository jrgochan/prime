//! Double-double precision CG solver for Gv = b.
//!
//! Uses `cathedral_utils::dd::DD` for all inner products, updates,
//! and convergence checks. The Gram matrix is loaded from HPDF DD
//! lo-words when available, giving ~31-digit matrix entries.
//!
//! ## Precision Analysis
//!
//! With DD arithmetic (106-bit mantissa):
//!   - Dot products: O(ε_DD) ≈ 10⁻³¹ roundoff per sum
//!   - At κ ≈ 10⁷: 31 - 7 = 24 clean digits in the solution
//!   - Residual floor: ~10⁻²⁴ (vs 10⁻⁸ for f64)

use cathedral_utils::dd::DD;
use crate::env::CathedralEnv;
use super::PrecisionCgResult;
use std::time::Instant;

/// DD dot product: Σ a_hi[i]*b_hi[i] accumulated in DD,
/// optionally using lo-words for the matrix data.
fn dd_dot(a: &[f64], b: &[f64]) -> DD {
    debug_assert_eq!(a.len(), b.len());
    let mut sum = DD::from_f64(0.0);
    for i in 0..a.len() {
        let prod = DD::from_f64(a[i]) * DD::from_f64(b[i]);
        sum += prod;
    }
    sum
}

/// DD dot product using DD-precision matrix data (hi+lo words).
fn dd_dot_hilo(a_hi: &[f64], a_lo: &[f64], b: &[f64]) -> DD {
    debug_assert_eq!(a_hi.len(), b.len());
    debug_assert_eq!(a_lo.len(), b.len());
    let mut sum = DD::from_f64(0.0);
    for i in 0..a_hi.len() {
        let a_dd = DD::new(a_hi[i], a_lo[i]);
        let prod = a_dd * DD::from_f64(b[i]);
        sum += prod;
    }
    sum
}

/// DD squared norm: Σ a[i]² accumulated in DD.
fn dd_norm2(a: &[f64]) -> DD {
    let mut sum = DD::from_f64(0.0);
    for &x in a {
        let xdd = DD::from_f64(x);
        sum += xdd * xdd;
    }
    sum
}

/// DD-precision matvec: y = G·x, where G is stored as (hi, lo) pair.
///
/// If `gram_lo` is None, uses f64-only matrix data with DD accumulation.
/// Parallelized via Rayon — each row's DD dot product is independent.
fn dd_matvec(
    gram_hi: &[f64],
    gram_lo: Option<&[f64]>,
    x: &[f64],
    y: &mut [f64],
    dim: usize,
) {
    use rayon::prelude::*;

    y.par_iter_mut().enumerate().for_each(|(i, yi)| {
        let row_start = i * dim;
        let result = if let Some(lo) = gram_lo {
            dd_dot_hilo(
                &gram_hi[row_start..row_start + dim],
                &lo[row_start..row_start + dim],
                x,
            )
        } else {
            dd_dot(&gram_hi[row_start..row_start + dim], x)
        };
        *yi = result.to_f64();
    });
}

/// Full DD-precision matvec: y_dd = G·x_dd.
///
/// Both input x and output y are DD vectors. The Gram matrix G is stored
/// as (hi, lo) pairs. Each element of the result is a full DD dot product
/// of a DD matrix row with a DD input vector — no precision loss anywhere.
///
/// This is the final piece needed for 10⁻²⁴ Pythagorean precision.
fn dd_matvec_full(
    gram_hi: &[f64],
    gram_lo: Option<&[f64]>,
    x_dd: &[DD],
    y_dd: &mut [DD],
    dim: usize,
) {
    use rayon::prelude::*;

    y_dd.par_iter_mut().enumerate().for_each(|(i, yi)| {
        let row_start = i * dim;
        let mut sum = DD::from_f64(0.0);
        if let Some(lo) = gram_lo {
            for j in 0..dim {
                let g = DD::new(gram_hi[row_start + j], lo[row_start + j]);
                sum += g * x_dd[j];
            }
        } else {
            for j in 0..dim {
                sum += DD::from_f64(gram_hi[row_start + j]) * x_dd[j];
            }
        }
        *yi = sum;
    });
}

/// Run Jacobi-preconditioned CG at full DD precision.
///
/// **All working vectors** (v, r, z, p) are stored as `Vec<DD>`,
/// giving ~31-digit precision in the solution. The matvec reads
/// DD lo-words from HPDF when available, and the vector updates
/// accumulate corrections in DD arithmetic.
///
/// This is the "Full DD" tier — the Theorist's predicted 10⁻²⁴
/// Pythagorean precision at κ ≈ 10⁷.
pub fn run_dd_cg(
    env: &mut CathedralEnv,
    max_steps: usize,
    tol: f64,
) -> PrecisionCgResult {
    // Check if GPU is available for accelerated matvec
    #[cfg(feature = "gpu")]
    let use_gpu = env.gpu_engine.is_some() || env.gpu_matvec.is_some();
    #[cfg(not(feature = "gpu"))]
    let use_gpu = false;

    run_dd_cg_inner(env, max_steps, tol, use_gpu)
}

/// Inner DD CG implementation with optional GPU matvec acceleration.
///
/// When `use_gpu` is true, the hot-loop matvec uses `env.matvec_into()` which
/// routes through GPU (full-VRAM BilinearEngine or OOC chunked MatvecState).
/// This is f64-precision matvec, but all working vectors, inner products, and
/// vector updates remain in full DD arithmetic. Periodic residual resets
/// recompute r = b - Gv freshly to correct for f64 matvec drift.
///
/// Final diagnostics (d², vᵀGv, Pythagorean check) always use full DD matvec
/// for maximum precision in the certificate.
fn run_dd_cg_inner(
    env: &mut CathedralEnv,
    max_steps: usize,
    tol: f64,
    use_gpu: bool,
) -> PrecisionCgResult {
    let t0 = Instant::now();
    let dim = env.dim;

    eprintln!("    DD CG: dim={dim}, max_steps={max_steps}, tol={tol:.2e}");

    // Get the Gram matrix (f64 hi-words are always available)
    let gram_hi = &env.gram_data;

    // Try to get DD lo-words from the environment
    let gram_lo: Option<&Vec<f64>> = env.gram_lo.as_ref();
    let has_dd = gram_lo.is_some();
    eprintln!("    DD source: {} matrix entries",
        if has_dd { "~31-digit (hi+lo)" } else { "f64-promoted (hi only)" });
    eprintln!("    DD vectors: full DD working vectors (v, r, z, p)");
    if use_gpu {
        eprintln!("    DD matvec: GPU-accelerated f64 (Mixed Precision Iterative Refinement)");
    } else {
        eprintln!("    DD matvec: full DD on CPU");
    }

    // Build Jacobi preconditioner: M⁻¹ = diag(1/G_ii) in DD
    let precond_inv: Vec<DD> = (0..dim)
        .map(|i| {
            let d = gram_hi[i * dim + i];
            if d.abs() > 1e-30 { DD::from_f64(1.0) / DD::from_f64(d) } else { DD::from_f64(1.0) }
        })
        .collect();

    // b vector in DD
    let b_dd: Vec<DD> = env.b_vec.iter().map(|&x| DD::from_f64(x)).collect();

    // Working vectors — ALL in DD precision
    let mut v_dd: Vec<DD> = env.v.iter().map(|&x| DD::from_f64(x)).collect();
    let mut r_dd: Vec<DD> = vec![DD::from_f64(0.0); dim];
    let mut z_dd: Vec<DD> = vec![DD::from_f64(0.0); dim];
    let mut p_dd: Vec<DD> = vec![DD::from_f64(0.0); dim];

    // DD output buffer for full DD matvec
    let mut gp_dd: Vec<DD> = vec![DD::from_f64(0.0); dim];

    // Scratch buffer for residual reset (needs f64 for initial matvec)
    let mut v_f64: Vec<f64> = vec![0.0; dim];
    let mut gp_f64: Vec<f64> = vec![0.0; dim];

    // Helper: extract f64 hi-words from DD vector
    let extract_f64 = |dd_vec: &[DD], f64_vec: &mut [f64]| {
        for i in 0..dd_vec.len() {
            f64_vec[i] = dd_vec[i].to_f64();
        }
    };

    // DD dot product for DD vectors
    let dd_dot_dd = |a: &[DD], b: &[DD]| -> DD {
        let mut sum = DD::from_f64(0.0);
        for i in 0..a.len() {
            sum += a[i] * b[i];
        }
        sum
    };

    // DD norm² for DD vectors
    let dd_norm2_dd = |a: &[DD]| -> DD {
        let mut sum = DD::from_f64(0.0);
        for i in 0..a.len() {
            sum += a[i] * a[i];
        }
        sum
    };

    // r₀ = b - G·v₀ (DD-precision matvec + DD subtraction)
    extract_f64(&v_dd, &mut v_f64);
    dd_matvec(gram_hi, gram_lo.map(|v| v.as_slice()), &v_f64, &mut gp_f64, dim);
    for i in 0..dim {
        r_dd[i] = b_dd[i] - DD::from_f64(gp_f64[i]);
    }

    // z₀ = M⁻¹r₀
    for i in 0..dim {
        z_dd[i] = precond_inv[i] * r_dd[i];
    }

    // p₀ = z₀
    p_dd.copy_from_slice(&z_dd);

    let r0_norm = dd_norm2_dd(&r_dd).to_f64().sqrt().max(1e-30);

    let reset_interval = (dim as f64).sqrt().ceil() as usize;
    let stagnation_window = reset_interval * 2;
    let mut stagnation_best = 1.0f64;
    let mut stagnation_counter = 0usize;

    let log_interval = ((max_steps as f64).sqrt() as usize).max(10).min(500);
    let mut converged = false;
    let mut stagnated = false;
    let mut steps = 0;
    let mut cached_rel_res = 1.0f64;

    for i in 0..max_steps {
        if converged || stagnated { break; }

        // Periodic residual reset: r = b - G·v (fresh DD computation)
        if i > 0 && i % reset_interval == 0 {
            extract_f64(&v_dd, &mut v_f64);
            dd_matvec(gram_hi, gram_lo.map(|v| v.as_slice()), &v_f64, &mut gp_f64, dim);
            for j in 0..dim {
                r_dd[j] = b_dd[j] - DD::from_f64(gp_f64[j]);
            }
            for j in 0..dim {
                z_dd[j] = precond_inv[j] * r_dd[j];
            }
            p_dd.copy_from_slice(&z_dd);
        }

        // α = (rᵀz) / (pᵀGp) — full DD inner products
        let r_dot_z = dd_dot_dd(&r_dd, &z_dd);

        if r_dot_z.to_f64().abs() < 1e-60 {
            converged = true;
            break;
        }

        // G·p — use GPU if available, otherwise full DD matvec
        if use_gpu {
            // GPU path: extract f64 hi-words, GPU matvec, promote to DD
            extract_f64(&p_dd, &mut v_f64);  // reuse v_f64 scratch as p_f64
            env.matvec_into(&v_f64, &mut gp_f64);
            for j in 0..dim { gp_dd[j] = DD::from_f64(gp_f64[j]); }
        } else {
            // CPU path: full DD matvec (DD matrix × DD vector → DD result)
            dd_matvec_full(gram_hi, gram_lo.map(|v| v.as_slice()), &p_dd, &mut gp_dd, dim);
        }

        // pᵀGp in full DD
        let mut p_dot_gp = DD::from_f64(0.0);
        for j in 0..dim {
            p_dot_gp += p_dd[j] * gp_dd[j];
        }

        if p_dot_gp.to_f64().abs() < 1e-60 {
            converged = true;
            break;
        }

        let alpha_dd = r_dot_z / p_dot_gp;

        // v ← v + α·p  (FULL DD)
        for j in 0..dim { v_dd[j] += alpha_dd * p_dd[j]; }

        // r ← r - α·Gp  (FULL DD — Gp is DD now!)
        for j in 0..dim { r_dd[j] -= alpha_dd * gp_dd[j]; }

        // Convergence check (DD norm)
        let r_norm = dd_norm2_dd(&r_dd).to_f64().sqrt();
        cached_rel_res = r_norm / r0_norm;

        if cached_rel_res < tol {
            converged = true;
        }

        // Stagnation detection
        stagnation_counter += 1;
        if cached_rel_res < stagnation_best * 0.99 {
            stagnation_best = cached_rel_res;
            stagnation_counter = 0;
        } else if stagnation_counter >= stagnation_window {
            stagnated = true;
        }

        // z = M⁻¹r (DD)
        for j in 0..dim { z_dd[j] = precond_inv[j] * r_dd[j]; }

        // β = (r_new·z_new) / (r·z)  (DD)
        let r_new_dot_z_new = dd_dot_dd(&r_dd, &z_dd);
        let beta_dd = r_new_dot_z_new / r_dot_z;

        // p = z + β·p  (DD)
        for j in 0..dim { p_dd[j] = z_dd[j] + beta_dd * p_dd[j]; }

        steps = i + 1;

        if i % log_interval == 0 {
            let elapsed = t0.elapsed().as_secs_f64();
            let rate = if elapsed > 0.0 { steps as f64 / elapsed } else { 0.0 };
            eprint!("\r    DD CG step {i:>5}: ||r||/||r₀||={cached_rel_res:.4e}  [{rate:.0} mv/s]      ");
        }
    }

    // Apply optimized v back to env (extract f64 from DD)
    for j in 0..dim { env.v[j] = v_dd[j].to_f64(); }

    // Compute d², vᵀGv, bᵀv in FULL DD precision
    // bᵀv = Σ b_i · v_i (DD)
    let btv_dd = dd_dot_dd(&b_dd, &v_dd);
    let btv = btv_dd.to_f64();

    // vᵀGv = vᵀ · (G·v) — full DD matvec then DD dot
    dd_matvec_full(gram_hi, gram_lo.map(|v| v.as_slice()), &v_dd, &mut gp_dd, dim);
    let vtgv_dd = dd_dot_dd(&v_dd, &gp_dd);
    let vtgv = vtgv_dd.to_f64();

    // d² = 1 - 2bᵀv + vᵀGv (DD)
    let d2_dd = DD::from_f64(1.0) - DD::from_f64(2.0) * btv_dd + vtgv_dd;
    let d2 = d2_dd.to_f64();

    // DD Pythagorean check: d² + vᵀGv should = 1
    let pyth_dd = d2_dd + vtgv_dd;
    let pyth_res = (pyth_dd - DD::from_f64(1.0)).to_f64().abs();
    eprintln!("    DD Pythagorean: d²+vᵀGv = {:.15e}  |res| = {:.2e}",
        pyth_dd.to_f64(), pyth_res);

    let elapsed = t0.elapsed().as_secs_f64();
    let status = if converged { "converged" } else if stagnated { "stagnated (DD floor)" } else { "exhausted" };
    eprintln!("\r    DD CG {status} at step {steps}: ||r||/||r₀||={cached_rel_res:.2e}, d²={d2:.10e}                     ");
    eprintln!("    DD CG wall time: {elapsed:.2}s ({steps} matvecs)");

    PrecisionCgResult {
        v_opt: env.v.clone(),
        d2,
        vtgv,
        btv,
        relative_residual: cached_rel_res,
        steps,
        converged,
        stagnated,
        tier: super::PrecisionTier::DD,
        wall_time_s: elapsed,
    }
}

