//! Agent runner functions for each strategy.
//!
//! Each function orchestrates a specific agent type against the
//! CathedralEnv, handling progress reporting, convergence detection,
//! and step counting.

use crate::agent::*;
use crate::env::CathedralEnv;
use std::time::Instant;

const DIM: &str = "\x1b[2m";
const GREEN: &str = "\x1b[32m";
const YELLOW: &str = "\x1b[33m";
const RESET: &str = "\x1b[0m";

/// Run Conjugate Gradient with default tolerance.
pub fn run_cg(env: &mut CathedralEnv, max_steps: usize) -> usize {
    run_cg_with_tol(env, max_steps, 1e-12)
}

/// Run Conjugate Gradient with explicit tolerance.
///
/// Progress is reported at adaptive intervals (√budget spacing)
/// to keep output manageable regardless of step count.
pub fn run_cg_with_tol(env: &mut CathedralEnv, max_steps: usize, tol: f64) -> usize {
    let mut cg = ConjugateGradientAgent::new(env.dim);
    cg.tolerance = tol;
    let mut steps = 0;

    eprintln!("    {DIM}CG config: max_steps={max_steps}, tol={tol:.2e}, preconditioner=Jacobi{RESET}");

    let t0 = Instant::now();

    // Adaptive log interval: scales with sqrt(budget) to keep output manageable.
    // For max_steps=200 → log every 10; for max_steps=5000 → log every ~70;
    // for max_steps=50000 → log every ~224. This avoids flooding stderr.
    let log_interval = ((max_steps as f64).sqrt() as usize).max(10).min(500);

    // d² is O(N²) to compute, so we defer it. During iteration we only
    // report the relative residual ||r||/||r₀|| which is O(N) and free
    // from the CG state. d² is computed only at convergence/exhaustion.
    let mut last_d2: Option<f64> = None;

    for i in 0..max_steps {
        let delta = cg.step(env);
        let norm: f64 = delta.iter().map(|x| x * x).sum::<f64>().sqrt();

        // Apply update: v ← v + δ
        for (vi, di) in env.v.iter_mut().zip(delta.iter()) {
            *vi += di;
        }
        steps += 1;

        // Lightweight progress: only relative residual (O(N), no matvec)
        if i % log_interval == 0 {
            let rel_res = cg.relative_residual();
            let elapsed = t0.elapsed().as_secs_f64();
            let matvecs_per_sec = if elapsed > 0.0 { steps as f64 / elapsed } else { 0.0 };
            eprint!("\r    CG step {i:>5}: ||r||/||r₀||={rel_res:.4e}  |δ|={norm:.4e}  [{matvecs_per_sec:.0} mv/s]      ");
        }

        // Convergence check (CG agent's internal tolerance criterion)
        if cg.converged {
            let d2 = env.compute_d2();
            last_d2 = Some(d2);
            let rel_res = cg.relative_residual();
            eprintln!("\r    {GREEN}✓{RESET} CG converged at step {i} (||r||/||r₀||={rel_res:.2e}, d²={d2:.10e})                              ");
            break;
        }

        // Stagnation check — residual stopped improving (f64 precision floor)
        if cg.stagnated {
            let d2 = env.compute_d2();
            last_d2 = Some(d2);
            let rel_res = cg.relative_residual();
            eprintln!("\r    {GREEN}✓{RESET} CG stagnated at step {i} (||r||/||r₀||={rel_res:.2e}, d²={d2:.10e}) — f64 precision floor          ");
            break;
        }
    }

    // Final diagnostics — d² computed exactly once at termination
    if !cg.converged && !cg.stagnated {
        let d2 = env.compute_d2();
        last_d2 = Some(d2);
        let rel_res = cg.relative_residual();
        eprintln!("\r    {YELLOW}⚠{RESET} CG exhausted budget ({max_steps} steps): ||r||/||r₀||={rel_res:.2e}, d²={d2:.10e}                     ");
        eprintln!("      {DIM}Consider increasing --cg-steps or relaxing --cg-tol{RESET}");
    }

    let elapsed = t0.elapsed().as_secs_f64();
    let final_d2_str = last_d2.map_or("(not computed)".to_string(), |d| format!("{d:.10e}"));
    eprintln!("    {DIM}CG wall time: {elapsed:.2}s ({steps} matvecs, final d²={final_d2_str}){RESET}");
    steps
}

/// Run gradient descent with momentum.
pub fn run_gd(env: &mut CathedralEnv, max_steps: usize, lr: f64, momentum: f64) -> usize {
    let mut agent = GradientAgent::new(env.dim, lr, momentum);

    for i in 0..max_steps {
        let delta = agent.act(env);
        env.step_action(&delta);

        if i % 20 == 0 {
            let d2 = env.compute_d2();
            let vtgv = env.compute_vtgv();
            eprint!("\r    GD step {i:>4}: d²={d2:.10e}  vᵀGv={vtgv:.8}      ");
        }
    }
    eprintln!();
    max_steps
}

/// Run evolution strategy.
pub fn run_es(env: &mut CathedralEnv, generations: usize, pop_size: usize, sigma: f64) -> usize {
    let mut es = EvolutionAgent::new(env.dim, pop_size, sigma);

    for g in 0..generations {
        let result = es.evolve(env);

        if g % 10 == 0 || g == generations - 1 {
            eprint!("\r    ES gen {g:>4}: best_d²={:.10e}  σ={:.6}      ", result.best_d2, result.sigma);
        }
    }
    eprintln!();
    generations
}

/// Run hybrid: CG warmup followed by ES exploration.
pub fn run_hybrid(
    env: &mut CathedralEnv,
    cg_steps: usize,
    cg_tol: f64,
    es_gens: usize,
    pop_size: usize,
    sigma: f64,
) -> usize {
    let bold = "\x1b[1m";

    // Phase 1: CG warmup
    println!("    {bold}Phase 1: Conjugate Gradient (analytical optimum)...{RESET}");
    let cg_actual = run_cg_with_tol(env, cg_steps, cg_tol);

    let cg_d2 = env.compute_d2();
    let cg_vtgv = env.compute_vtgv();
    let cg_btv = env.compute_btv();
    println!("    CG result: d²={cg_d2:.10e}  vᵀGv={cg_vtgv:.8}  bᵀv={cg_btv:.8}");
    println!();

    // Phase 2: ES exploration
    println!("    {bold}Phase 2: Evolution Strategy (structural exploration)...{RESET}");
    let es_actual = run_es(env, es_gens, pop_size, sigma);

    cg_actual + es_actual
}
