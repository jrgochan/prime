//! MPFR-precision CG solver for Gv = b.
//!
//! Uses `rug::Float` at arbitrary bit precision for all operations.
//! This is the reference/certification solver — very slow but with
//! no precision limit.
//!
//! ## Typical Usage
//!
//! ```text
//! --precision mpfr --mpfr-bits 256     # 77 decimal digits
//! --precision mpfr --mpfr-bits 512     # 154 decimal digits
//! --precision mpfr --mpfr-bits 1024    # 308 decimal digits
//! ```
//!
//! ## Performance
//!
//! At dim=1000, prec=256: ~100× slower than f64 CG.
//! At dim=5000, prec=256: impractical (use DD or Mixed instead).
//! Best used for small N certification runs (N ≤ 500).

use super::PrecisionCgResult;
use crate::env::CathedralEnv;
use rug::{Assign, Float};
use std::time::Instant;

/// MPFR dot product: Σ a[i]·b[i] at p-bit precision.
fn mpfr_dot(a: &[f64], b: &[f64], p: u32) -> Float {
    let mut sum = Float::with_val(p, 0.0);
    let mut tmp = Float::new(p);
    for i in 0..a.len() {
        tmp.assign(a[i]);
        tmp *= b[i];
        sum += &tmp;
    }
    sum
}

/// MPFR squared norm: Σ a[i]².
fn mpfr_norm2(a: &[f64], p: u32) -> Float {
    let mut sum = Float::with_val(p, 0.0);
    let mut tmp = Float::new(p);
    for &x in a {
        tmp.assign(x);
        tmp *= x;
        sum += &tmp;
    }
    sum
}

/// MPFR matvec: y = G·x (using the f64 Gram matrix with MPFR accumulation).
fn mpfr_matvec(gram: &[f64], x: &[f64], y: &mut [f64], dim: usize, p: u32) {
    for i in 0..dim {
        let row_start = i * dim;
        let dot = mpfr_dot(&gram[row_start..row_start + dim], x, p);
        y[i] = dot.to_f64();
    }
}

/// Run Jacobi-preconditioned CG at MPFR precision.
///
/// All inner products, norms, and scalar computations use `rug::Float`
/// at the specified bit precision. The matrix itself is stored in f64
/// but promoted to MPFR for each matvec.
///
/// For small N (≤ 500), this gives a certified reference solution
/// against which DD and f64 results can be validated.
pub fn run_mpfr_cg(
    env: &mut CathedralEnv,
    max_steps: usize,
    tol: f64,
    prec_bits: u32,
) -> PrecisionCgResult {
    let t0 = Instant::now();
    let dim = env.dim;
    let p = prec_bits;

    let digits = (p as f64 * 0.30103).floor() as u32; // log10(2) ≈ 0.30103
    eprintln!("    MPFR CG: dim={dim}, max_steps={max_steps}, tol={tol:.2e}");
    eprintln!("    Precision: {p}-bit ({digits} decimal digits)");

    let gram = &env.gram_data;
    let b = env.b_vec.clone();

    // Jacobi preconditioner (f64 — applied as scaling)
    let precond_inv: Vec<f64> = (0..dim)
        .map(|i| {
            let d = gram[i * dim + i];
            if d.abs() > 1e-30 {
                1.0 / d
            } else {
                1.0
            }
        })
        .collect();

    // Working vectors
    let mut v = env.v.clone();
    let mut r = vec![0.0f64; dim];
    let mut z = vec![0.0f64; dim];
    let mut pp = vec![0.0f64; dim]; // search direction (named 'pp' to avoid conflict)
    let mut gp = vec![0.0f64; dim];

    // r₀ = b - G·v₀ (MPFR matvec)
    mpfr_matvec(gram, &v, &mut gp, dim, p);
    for i in 0..dim {
        r[i] = b[i] - gp[i];
    }

    // z₀ = M⁻¹r₀, p₀ = z₀
    for i in 0..dim {
        z[i] = precond_inv[i] * r[i];
    }
    pp.copy_from_slice(&z);

    let r0_norm = mpfr_norm2(&r, p).to_f64().sqrt().max(1e-30);

    let reset_interval = (dim as f64).sqrt().ceil() as usize;
    let stagnation_window = reset_interval * 2;
    let mut stagnation_best = 1.0f64;
    let mut stagnation_counter = 0usize;
    let log_interval = ((max_steps as f64).sqrt() as usize).max(5).min(100);

    let mut converged = false;
    let mut stagnated = false;
    let mut steps = 0;
    let mut cached_rel_res = 1.0f64;

    for i in 0..max_steps {
        if converged || stagnated {
            break;
        }

        // Periodic residual reset
        if i > 0 && i % reset_interval == 0 {
            mpfr_matvec(gram, &v, &mut gp, dim, p);
            for j in 0..dim {
                r[j] = b[j] - gp[j];
            }
            for j in 0..dim {
                z[j] = precond_inv[j] * r[j];
            }
            pp.copy_from_slice(&z);
        }

        // α = (rᵀz) / (pᵀGp) — MPFR precision
        let r_dot_z = mpfr_dot(&r, &z, p);

        if r_dot_z.to_f64().abs() < 1e-100 {
            converged = true;
            break;
        }

        mpfr_matvec(gram, &pp, &mut gp, dim, p);

        let p_dot_gp = mpfr_dot(&pp, &gp, p);

        if p_dot_gp.to_f64().abs() < 1e-100 {
            converged = true;
            break;
        }

        let alpha = Float::with_val(p, &r_dot_z / &p_dot_gp).to_f64();

        // v ← v + α·p
        for j in 0..dim {
            v[j] += alpha * pp[j];
        }

        // r ← r - α·Gp
        for j in 0..dim {
            r[j] -= alpha * gp[j];
        }

        // Convergence (MPFR norm)
        let r_norm = mpfr_norm2(&r, p).to_f64().sqrt();
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

        // z = M⁻¹r, β, p update
        for j in 0..dim {
            z[j] = precond_inv[j] * r[j];
        }
        let r_new_z_new = mpfr_dot(&r, &z, p);
        let beta = Float::with_val(p, &r_new_z_new / &r_dot_z).to_f64();
        for j in 0..dim {
            pp[j] = z[j] + beta * pp[j];
        }

        steps = i + 1;

        if i % log_interval == 0 {
            let elapsed = t0.elapsed().as_secs_f64();
            let rate = if elapsed > 0.0 {
                steps as f64 / elapsed
            } else {
                0.0
            };
            eprint!("\r    MPFR CG step {i:>5}: ||r||/||r₀||={cached_rel_res:.4e}  [{rate:.0} mv/s]      ");
        }
    }

    // Apply back
    env.v = v;
    let d2 = env.compute_d2();
    let vtgv = env.compute_vtgv();
    let btv = env.compute_btv();

    let elapsed = t0.elapsed().as_secs_f64();
    let status = if converged {
        "converged"
    } else if stagnated {
        "stagnated (MPFR floor)"
    } else {
        "exhausted"
    };
    eprintln!("\r    MPFR CG {status} at step {steps}: ||r||/||r₀||={cached_rel_res:.2e}, d²={d2:.10e}                     ");
    eprintln!("    MPFR CG wall time: {elapsed:.2}s ({steps} matvecs, {p}-bit)");

    PrecisionCgResult {
        v_opt: env.v.clone(),
        d2,
        vtgv,
        btv,
        relative_residual: cached_rel_res,
        steps,
        converged,
        stagnated,
        tier: super::PrecisionTier::Mpfr(prec_bits),
        wall_time_s: elapsed,
    }
}
