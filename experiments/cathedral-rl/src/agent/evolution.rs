//! §3. Evolution Strategy Agent — gradient-free search.
//!
//! A (μ+λ) Evolution Strategy for exploring the weight landscape.

use crate::env::CathedralEnv;
use rand_distr::{Distribution, Normal};
use serde::{Deserialize, Serialize};

/// (μ+λ) Evolution Strategy for exploring the weight landscape.
pub struct EvolutionAgent {
    pub pop_size: usize,
    pub elite_frac: f64,
    pub sigma: f64,
    pub sigma_decay: f64,
    pub min_sigma: f64,
    pub best_v: Vec<f64>,
    pub best_d2: f64,
    generation: usize,
}

impl EvolutionAgent {
    pub fn new(dim: usize, pop_size: usize, sigma: f64) -> Self {
        Self {
            pop_size,
            elite_frac: 0.2,
            sigma,
            sigma_decay: 0.999,
            min_sigma: 1e-6,
            best_v: vec![0.0; dim],
            best_d2: f64::INFINITY,
            generation: 0,
        }
    }

    /// Run one generation of evolution on the environment.
    pub fn evolve(&mut self, env: &mut CathedralEnv) -> EvolutionResult {
        let dim = env.dim;
        let mut rng = rand::thread_rng();
        let normal = Normal::new(0.0, self.sigma).unwrap();

        if self.generation == 0 {
            self.best_v = env.v.clone();
            self.best_d2 = env.compute_d2();
        }

        let mut population: Vec<(Vec<f64>, f64)> = Vec::with_capacity(self.pop_size);

        for _ in 0..self.pop_size {
            let mut candidate = self.best_v.clone();
            for vi in candidate.iter_mut() {
                *vi += normal.sample(&mut rng);
            }
            env.v = candidate.clone();
            let d2 = env.compute_d2();
            population.push((candidate, d2));
        }

        population.sort_by(|a, b| a.1.partial_cmp(&b.1).unwrap_or(std::cmp::Ordering::Equal));

        let n_elite = (self.pop_size as f64 * self.elite_frac).max(1.0) as usize;
        let mut mean_v = vec![0.0f64; dim];
        for (v, _) in population.iter().take(n_elite) {
            for (mi, vi) in mean_v.iter_mut().zip(v.iter()) {
                *mi += vi;
            }
        }
        for mi in mean_v.iter_mut() {
            *mi /= n_elite as f64;
        }

        let (best_candidate, best_candidate_d2) = &population[0];
        if *best_candidate_d2 < self.best_d2 {
            self.best_v = best_candidate.clone();
            self.best_d2 = *best_candidate_d2;
        }

        self.best_v = mean_v;
        env.v = self.best_v.clone();
        let mean_d2 = env.compute_d2();

        self.sigma = (self.sigma * self.sigma_decay).max(self.min_sigma);
        self.generation += 1;

        EvolutionResult {
            generation: self.generation,
            best_d2: self.best_d2,
            mean_d2,
            elite_d2: population.iter().take(n_elite).map(|(_, d)| *d).sum::<f64>() / n_elite as f64,
            sigma: self.sigma,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EvolutionResult {
    pub generation: usize,
    pub best_d2: f64,
    pub mean_d2: f64,
    pub elite_d2: f64,
    pub sigma: f64,
}
