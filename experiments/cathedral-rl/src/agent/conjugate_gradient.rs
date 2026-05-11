//! §2. Conjugate Gradient Agent — Jacobi-preconditioned CG.
//!
//! Preconditioned Conjugate Gradient method for solving Gv = b.
//!
//! Since G is (empirically) positive definite, CG converges in at most
//! dim iterations. In practice, converges much faster due to spectral
//! clustering of G's eigenvalues.
//!
//! ## Jacobi Preconditioning
//!
//! We use M = diag(G) as a preconditioner. The preconditioned CG
//! solves M⁻¹G v = M⁻¹b, which clusters the eigenvalues of M⁻¹G
//! much more tightly than G alone. For the Gram matrix (which has
//! dominant diagonal entries that grow logarithmically), this reduces
//! the effective condition number by an estimated 5-10×.
//!
//! ## Adaptive Convergence
//!
//! Uses the relative residual ||r|| / ||r₀|| < ε as the convergence
//! criterion, which is numerically stable and well-defined for CG.
//! The default tolerance is 1e-12.
//!
//! ## GPU Acceleration
//!
//! Routes all matvec operations through `env.matvec()`, which
//! dispatches to the GPU BilinearEngine when available.
//!
//! ## Periodic Residual Reset
//!
//! Every √dim steps, the residual r = b - Gv is recomputed from
//! scratch to correct accumulated floating-point drift. This costs
//! one extra matvec but prevents CG from "wandering" after thousands
//! of iterations.

use super::numerics::{dot_kahan, norm_kahan};
use crate::env::CathedralEnv;

/// Preconditioned Conjugate Gradient solver for the Gram system Gv = b.
pub struct ConjugateGradientAgent {
    /// Residual: r = b - Gv (negative half-gradient)
    r: Vec<f64>,
    /// Preconditioned residual: z = M⁻¹r
    z: Vec<f64>,
    /// Search direction: p
    p: Vec<f64>,
    /// Pre-allocated delta buffer: δv = α·p (reused each step to avoid allocation)
    delta: Vec<f64>,
    /// Pre-allocated buffer for Gp product (eliminates per-step allocation)
    gp: Vec<f64>,
    /// Inverse diagonal preconditioner: M⁻¹ = diag(1/G_ii)
    precond_inv: Vec<f64>,
    /// Whether CG has been initialized
    initialized: bool,
    /// Initial residual norm (for relative convergence check)
    r0_norm: f64,
    /// Convergence tolerance for ||r|| / ||r₀||
    pub tolerance: f64,
    /// Track whether we've converged
    pub converged: bool,
    /// Whether CG stagnated (residual stopped improving)
    pub stagnated: bool,
    /// Convergence step (if converged)
    pub converge_step: Option<usize>,
    /// Step counter
    step_count: usize,
    /// Cached residual norm (updated each step to avoid redundant computation)
    cached_r_norm: f64,
    /// Interval for periodic residual reset (recompute r = b - Gv from scratch)
    /// to correct accumulated floating-point drift. Defaults to sqrt(dim).
    reset_interval: usize,
    /// Stagnation detection: best relative residual seen in the last window
    stagnation_best: f64,
    /// Counter for stagnation detection window
    stagnation_counter: usize,
    /// Window size for stagnation detection (steps without 1% improvement)
    stagnation_window: usize,
}

impl ConjugateGradientAgent {
    pub fn new(dim: usize) -> Self {
        // Residual reset interval: sqrt(dim) keeps accumulated drift
        // below ~ε·sqrt(dim) per epoch. For dim=55,439 this is ~235 steps.
        let reset_interval = (dim as f64).sqrt().ceil() as usize;
        // Stagnation window: 2× the reset interval. If the relative
        // residual hasn't improved by 1% over this many steps, we're stuck.
        let stagnation_window = reset_interval * 2;

        Self {
            r: vec![0.0; dim],
            z: vec![0.0; dim],
            p: vec![0.0; dim],
            delta: vec![0.0; dim],
            gp: vec![0.0; dim],
            precond_inv: vec![1.0; dim], // Identity until initialized
            initialized: false,
            r0_norm: 1.0,
            tolerance: 1e-12,
            converged: false,
            stagnated: false,
            converge_step: None,
            step_count: 0,
            cached_r_norm: 0.0,
            reset_interval,
            stagnation_best: f64::INFINITY,
            stagnation_counter: 0,
            stagnation_window,
        }
    }

    /// Initialize the Jacobi preconditioner from the Gram diagonal.
    /// Call this before the first CG step.
    pub fn init_preconditioner(&mut self, env: &CathedralEnv) {
        let diag = env.gram_diagonal();
        self.precond_inv = diag
            .iter()
            .map(|&d| {
                if d.abs() > 1e-30 {
                    1.0 / d
                } else {
                    1.0 // degenerate diagonal — use identity
                }
            })
            .collect();
    }

    /// Compute one Preconditioned CG step, writing the update into an
    /// internal buffer. Returns a borrowed slice to avoid per-step allocation.
    ///
    /// Uses env.matvec_into() for zero-allocation matrix-vector products,
    /// dispatching to the GPU BilinearEngine when available.
    ///
    /// ## Algorithm (Preconditioned CG for Gv = b)
    ///
    /// ```text
    /// Initialize: r₀ = b - Gv₀,  z₀ = M⁻¹r₀,  p₀ = z₀
    /// For k = 0, 1, 2, ...:
    ///   αₖ = (rₖᵀzₖ) / (pₖᵀGpₖ)
    ///   vₖ₊₁ = vₖ + αₖpₖ
    ///   rₖ₊₁ = rₖ - αₖGpₖ
    ///   zₖ₊₁ = M⁻¹rₖ₊₁
    ///   βₖ = (rₖ₊₁ᵀzₖ₊₁) / (rₖᵀzₖ)
    ///   pₖ₊₁ = zₖ₊₁ + βₖpₖ
    /// ```
    pub fn step(&mut self, env: &CathedralEnv) -> &[f64] {
        let dim = env.dim;

        if !self.initialized {
            self.initialize(env);
        }

        // Check if already converged or stagnated — return zero delta
        if self.converged || self.stagnated {
            for d in self.delta.iter_mut() {
                *d = 0.0;
            }
            return &self.delta;
        }

        // ─── Periodic residual reset ───────────────────────────────
        // Every `reset_interval` steps, recompute r = b - Gv from
        // scratch to correct accumulated floating-point drift.
        // This costs one extra matvec but prevents CG from "wandering"
        // after thousands of iterations. The search direction p is
        // reset to M⁻¹r (restart) since the old conjugacy is lost.
        if self.step_count > 0 && self.step_count % self.reset_interval == 0 {
            // r = b - G·v_current (v_current is env.v which was updated externally)
            env.matvec_into(&env.v, &mut self.gp);
            for i in 0..dim {
                self.r[i] = env.b_vec[i] - self.gp[i];
            }
            // z = M⁻¹r
            for i in 0..dim {
                self.z[i] = self.precond_inv[i] * self.r[i];
            }
            // Restart: p = z
            self.p.copy_from_slice(&self.z);
            self.cached_r_norm = norm_kahan(&self.r);
        }

        // α = (rᵀz) / (pᵀGp) — Kahan-compensated dot products
        let r_dot_z = dot_kahan(&self.r, &self.z);

        if r_dot_z.abs() < 1e-30 {
            self.converged = true;
            self.converge_step = Some(self.step_count);
            for d in self.delta.iter_mut() {
                *d = 0.0;
            }
            return &self.delta;
        }

        // Gp — zero-allocation matvec (routes to GPU if available)
        env.matvec_into(&self.p, &mut self.gp);

        let p_dot_gp = dot_kahan(&self.p, &self.gp);

        if p_dot_gp.abs() < 1e-30 {
            self.converged = true;
            self.converge_step = Some(self.step_count);
            for d in self.delta.iter_mut() {
                *d = 0.0;
            }
            return &self.delta;
        }

        let alpha = r_dot_z / p_dot_gp;

        // δv = α·p  (write into pre-allocated buffer)
        for i in 0..dim {
            self.delta[i] = alpha * self.p[i];
        }

        // rₖ₊₁ = rₖ - α·Gp
        for i in 0..dim {
            self.r[i] -= alpha * self.gp[i];
        }

        // Check convergence: ||r|| / ||r₀|| < ε
        // Use Kahan-compensated norm to maintain precision at large dim
        self.cached_r_norm = norm_kahan(&self.r);
        let relative_residual = self.cached_r_norm / self.r0_norm;

        if relative_residual < self.tolerance {
            self.converged = true;
            self.converge_step = Some(self.step_count);
        }

        // ─── Stagnation detection ──────────────────────────────────
        // If the relative residual hasn't improved by at least 1% over
        // the stagnation window, declare stagnation. This prevents
        // wasting thousands of GPU matvecs on a stuck solver.
        self.stagnation_counter += 1;
        if relative_residual < self.stagnation_best * 0.99 {
            // Meaningful improvement — reset the window
            self.stagnation_best = relative_residual;
            self.stagnation_counter = 0;
        } else if self.stagnation_counter >= self.stagnation_window {
            self.stagnated = true;
            self.converge_step = Some(self.step_count);
        }

        // zₖ₊₁ = M⁻¹rₖ₊₁
        for i in 0..dim {
            self.z[i] = self.precond_inv[i] * self.r[i];
        }

        // β = (rₖ₊₁ᵀzₖ₊₁) / (rₖᵀzₖ) — Kahan-compensated
        let r_new_dot_z_new = dot_kahan(&self.r, &self.z);

        let beta = r_new_dot_z_new / r_dot_z;

        // pₖ₊₁ = zₖ₊₁ + β·pₖ
        for i in 0..dim {
            self.p[i] = self.z[i] + beta * self.p[i];
        }

        self.step_count += 1;
        &self.delta
    }

    /// Full initialization: preconditioner, initial residual, search direction.
    /// Factored out of step() for clarity.
    fn initialize(&mut self, env: &CathedralEnv) {
        let dim = env.dim;

        // Initialize preconditioner
        self.init_preconditioner(env);

        // r₀ = b - Gv₀ (zero-allocation: write Gv₀ into gp buffer)
        env.matvec_into(&env.v, &mut self.gp);
        for i in 0..dim {
            self.r[i] = env.b_vec[i] - self.gp[i];
        }

        // z₀ = M⁻¹r₀ (apply preconditioner)
        for i in 0..dim {
            self.z[i] = self.precond_inv[i] * self.r[i];
        }

        // p₀ = z₀ (copy, not clone, to avoid allocation)
        self.p.copy_from_slice(&self.z);

        // Record initial residual norm (Kahan-compensated)
        self.r0_norm = norm_kahan(&self.r);
        self.cached_r_norm = self.r0_norm;
        self.stagnation_best = 1.0; // relative residual starts at 1.0
        if self.r0_norm < 1e-30 {
            self.r0_norm = 1.0; // prevent division by zero
        }

        self.initialized = true;
    }

    /// Get the current residual norm ||r|| (uses cached value from last step)
    pub fn residual_norm(&self) -> f64 {
        self.cached_r_norm
    }

    /// Get the relative residual ||r|| / ||r₀|| (uses cached value)
    pub fn relative_residual(&self) -> f64 {
        self.cached_r_norm / self.r0_norm
    }
}
