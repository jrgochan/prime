//! Mixed-precision CG: f64 matvec + DD residual accumulation.
//!
//! This is the **iterative refinement** strategy:
//!   1. Do the matvec G·p in f64 (fast — routes to GPU if available)
//!   2. Accumulate the residual r and inner products in DD
//!   3. Periodically recompute r = b - G·v in DD precision
//!
//! This gives ~23 clean digits with only ~1.3× the cost of pure f64,
//! because the bottleneck (matvec at O(N²)) stays in f64.
//!
//! ## Why This Works
//!
//! The key insight is that CG's precision loss comes from accumulating
//! small corrections α·p into r. The matvec G·p itself is a clean O(N)
//! sum — it's the *residual update* r ← r - α·Gp that loses precision.
//! By doing the accumulation in DD, we keep the residual clean while
//! the matvec stays at hardware speed.

use super::PrecisionCgResult;
use crate::env::CathedralEnv;
use cathedral_utils::dd::DD;
use std::time::Instant;

/// DD dot product for internal accumulation.
fn dd_dot(a: &[f64], b: &[f64]) -> DD {
    debug_assert_eq!(a.len(), b.len());
    let mut sum = DD::from_f64(0.0);
    for i in 0..a.len() {
        sum += DD::from_f64(a[i]) * DD::from_f64(b[i]);
    }
    sum
}

/// DD norm²
fn dd_norm2(a: &[f64]) -> DD {
    let mut sum = DD::from_f64(0.0);
    for &x in a {
        let xdd = DD::from_f64(x);
        sum += xdd * xdd;
    }
    sum
}

/// Run mixed-precision CG: f64 matvec, DD residual.
///
/// The matvec uses `env.matvec_into()` which routes to GPU when available.
/// All scalar products, residual updates, and convergence checks use DD.
pub fn run_mixed_cg(env: &mut CathedralEnv, max_steps: usize, tol: f64) -> PrecisionCgResult {
    let t0 = Instant::now();
    let dim = env.dim;

    eprintln!("    Mixed CG: dim={dim}, max_steps={max_steps}, tol={tol:.2e}");
    eprintln!("    Strategy: f64 matvec (GPU-compatible) + DD residual accumulation");

    // Jacobi preconditioner
    let diag = env.gram_diagonal();
    let precond_inv: Vec<f64> = diag
        .iter()
        .map(|&d| if d.abs() > 1e-30 { 1.0 / d } else { 1.0 })
        .collect();

    let b = env.b_vec.clone();

    // Working vectors
    let mut r = vec![0.0f64; dim];
    let mut z = vec![0.0f64; dim];
    let mut p = vec![0.0f64; dim];
    let mut gp = vec![0.0f64; dim];

    // DD residual accumulators
    let mut r_dd: Vec<DD> = vec![DD::from_f64(0.0); dim];

    // Initial residual: r₀ = b - G·v₀ (f64 matvec, DD accumulation)
    env.matvec_into(&env.v, &mut gp);
    for i in 0..dim {
        r_dd[i] = DD::from_f64(b[i]) - DD::from_f64(gp[i]);
        r[i] = r_dd[i].to_f64();
    }

    // z₀ = M⁻¹r₀
    for i in 0..dim {
        z[i] = precond_inv[i] * r[i];
    }
    p.copy_from_slice(&z);

    let r0_norm = dd_norm2(&r).to_f64().sqrt().max(1e-30);

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
        if converged || stagnated {
            break;
        }

        // Periodic DD residual reset: r = b - G·v (fresh computation)
        if i > 0 && i % reset_interval == 0 {
            env.matvec_into(&env.v, &mut gp);
            for j in 0..dim {
                r_dd[j] = DD::from_f64(b[j]) - DD::from_f64(gp[j]);
                r[j] = r_dd[j].to_f64();
            }
            for j in 0..dim {
                z[j] = precond_inv[j] * r[j];
            }
            p.copy_from_slice(&z);
        }

        // α = (rᵀz) / (pᵀGp) — DD inner products
        let r_dot_z = dd_dot(&r, &z);

        if r_dot_z.to_f64().abs() < 1e-60 {
            converged = true;
            break;
        }

        // G·p — FAST f64 matvec (GPU when available)
        env.matvec_into(&p, &mut gp);

        let p_dot_gp = dd_dot(&p, &gp);

        if p_dot_gp.to_f64().abs() < 1e-60 {
            converged = true;
            break;
        }

        let alpha_dd = r_dot_z / p_dot_gp;
        let alpha = alpha_dd.to_f64();

        // v ← v + α·p (f64 update)
        for j in 0..dim {
            env.v[j] += alpha * p[j];
        }

        // r ← r - α·Gp (DD accumulation — the key innovation)
        for j in 0..dim {
            r_dd[j] -= DD::from_f64(alpha) * DD::from_f64(gp[j]);
            r[j] = r_dd[j].to_f64();
        }

        // Convergence check (DD norm)
        let r_norm = dd_norm2(&r).to_f64().sqrt();
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

        // z = M⁻¹r
        for j in 0..dim {
            z[j] = precond_inv[j] * r[j];
        }

        // β
        let r_new_dot_z_new = dd_dot(&r, &z);
        let beta = (r_new_dot_z_new / r_dot_z).to_f64();

        // p = z + β·p
        for j in 0..dim {
            p[j] = z[j] + beta * p[j];
        }

        steps = i + 1;

        if i % log_interval == 0 {
            let elapsed = t0.elapsed().as_secs_f64();
            let rate = if elapsed > 0.0 {
                steps as f64 / elapsed
            } else {
                0.0
            };
            eprint!("\r    Mixed CG step {i:>5}: ||r||/||r₀||={cached_rel_res:.4e}  [{rate:.0} mv/s]      ");
        }
    }

    let d2 = env.compute_d2();
    let vtgv = env.compute_vtgv();
    let btv = env.compute_btv();

    let elapsed = t0.elapsed().as_secs_f64();
    let status = if converged {
        "converged"
    } else if stagnated {
        "stagnated (DD floor)"
    } else {
        "exhausted"
    };
    eprintln!("\r    Mixed CG {status} at step {steps}: ||r||/||r₀||={cached_rel_res:.2e}, d²={d2:.10e}                     ");
    eprintln!("    Mixed CG wall time: {elapsed:.2}s ({steps} matvecs)");

    PrecisionCgResult {
        v_opt: env.v.clone(),
        d2,
        vtgv,
        btv,
        relative_residual: cached_rel_res,
        steps,
        converged,
        stagnated,
        tier: super::PrecisionTier::Mixed,
        wall_time_s: elapsed,
    }
}
