//! §1. Gradient Descent Agent — the analytical baseline.
//!
//! Gradient descent on d² = 1 - 2bᵀv + vᵀGv.
//! Since d² is quadratic in v, the gradient is exact:
//!   ∇d² = -2b + 2Gv
//!
//! The optimal v satisfies Gv = b, i.e. v* = G⁻¹b.
//! But G may be ill-conditioned, so we use iterative descent
//! with momentum as a robust fallback.

use crate::env::CathedralEnv;

/// Gradient descent with momentum on d² = 1 - 2bᵀv + vᵀGv.
///
/// Since d² is quadratic in v, the gradient is:
///   ∇d² = -2b + 2Gv
///
/// The optimal v satisfies Gv = b, i.e. v* = G⁻¹b.
/// But G may be ill-conditioned, so we use iterative descent.
pub struct GradientAgent {
    pub learning_rate: f64,
    pub momentum: f64,
    velocity: Vec<f64>,
}

impl GradientAgent {
    pub fn new(dim: usize, learning_rate: f64, momentum: f64) -> Self {
        Self {
            learning_rate,
            momentum,
            velocity: vec![0.0; dim],
        }
    }

    /// Compute the next action (perturbation δv) using gradient descent
    pub fn act(&mut self, env: &CathedralEnv) -> Vec<f64> {
        let grad = env.gradient_d2();
        let dim = env.dim;
        let mut delta = vec![0.0f64; dim];

        for i in 0..dim {
            self.velocity[i] = self.momentum * self.velocity[i] - self.learning_rate * grad[i];
            delta[i] = self.velocity[i];
        }

        delta
    }
}
