//! §4. Hybrid Agent — CG warmup + ES exploration.
//!
//! First run CG to find the quadratic optimum, then use ES to
//! explore beyond it.
//!
//! The idea: CG finds v* = G⁻¹b (optimal for the quadratic form).
//! But maybe a structurally different v (e.g., one that exploits
//! Möbius cancellation patterns) can achieve lower d².

#![allow(dead_code)]

use crate::env::CathedralEnv;
use super::conjugate_gradient::ConjugateGradientAgent;
use super::evolution::{EvolutionAgent, EvolutionResult};
use serde::{Deserialize, Serialize};

/// Which phase the hybrid agent is currently in.
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum AgentPhase {
    ConjugateGradient,
    Evolution,
}

/// Hybrid agent: CG warmup followed by ES exploration.
pub struct HybridAgent {
    cg: ConjugateGradientAgent,
    es: EvolutionAgent,
    cg_steps: usize,
    max_cg_steps: usize,
    phase: AgentPhase,
}

impl HybridAgent {
    pub fn new(dim: usize, max_cg_steps: usize, es_pop_size: usize, es_sigma: f64) -> Self {
        Self {
            cg: ConjugateGradientAgent::new(dim),
            es: EvolutionAgent::new(dim, es_pop_size, es_sigma),
            cg_steps: 0,
            max_cg_steps,
            phase: AgentPhase::ConjugateGradient,
        }
    }

    pub fn phase(&self) -> AgentPhase {
        self.phase
    }

    /// Run one step: CG during warmup, then ES for exploration.
    pub fn step(&mut self, env: &mut CathedralEnv) -> HybridStepResult {
        match self.phase {
            AgentPhase::ConjugateGradient => {
                let delta = self.cg.step(env);
                let norm: f64 = delta.iter().map(|x| x * x).sum::<f64>().sqrt();

                for (vi, di) in env.v.iter_mut().zip(delta.iter()) {
                    *vi += di;
                }
                self.cg_steps += 1;

                let d2 = env.compute_d2();

                if norm < 1e-12 || self.cg_steps >= self.max_cg_steps {
                    self.phase = AgentPhase::Evolution;
                    self.es.best_v = env.v.clone();
                    self.es.best_d2 = d2;
                }

                HybridStepResult::new(
                    AgentPhase::ConjugateGradient,
                    d2,
                    env.compute_vtgv(),
                    env.compute_btv(),
                    self.cg_steps,
                    None,
                )
            }
            AgentPhase::Evolution => {
                let result = self.es.evolve(env);
                HybridStepResult::new(
                    AgentPhase::Evolution,
                    result.best_d2,
                    env.compute_vtgv(),
                    env.compute_btv(),
                    self.cg_steps + result.generation,
                    Some(result),
                )
            }
        }
    }
}

/// Result of one hybrid agent step.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HybridStepResult {
    pub phase: String,
    pub d2: f64,
    pub vtgv: f64,
    pub btv: f64,
    pub step: usize,
    pub extra: Option<EvolutionResult>,
}

impl HybridStepResult {
    fn new(
        phase: AgentPhase,
        d2: f64,
        vtgv: f64,
        btv: f64,
        step: usize,
        extra: Option<EvolutionResult>,
    ) -> Self {
        Self {
            phase: match phase {
                AgentPhase::ConjugateGradient => "CG".to_string(),
                AgentPhase::Evolution => "ES".to_string(),
            },
            d2, vtgv, btv, step, extra,
        }
    }
}
