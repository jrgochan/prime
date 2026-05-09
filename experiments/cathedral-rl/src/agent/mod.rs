//! RL Agents for the Cathedral Gram Form Optimization
//!
//! Multiple agent strategies, from simple gradient descent to
//! evolution-based search, all targeting the same objective:
//! minimize d² = 1 - 2bᵀv + vᵀGv.
//!
//! ## Architecture
//!
//! ```text
//!   agent/
//!     mod.rs              ← this file (barrel exports)
//!     numerics.rs         ← Kahan compensated arithmetic
//!     gradient.rs         ← §1 Gradient descent agent
//!     conjugate_gradient.rs ← §2 Jacobi-preconditioned CG
//!     evolution.rs        ← §3 (μ+λ) Evolution Strategy
//!     hybrid.rs           ← §4 CG warmup → ES exploration
//! ```
//!
//! ## Numerical Precision
//!
//! All inner products use Kahan (compensated) summation to prevent
//! precision loss at large N. At N=55,440 (dim=55,439), naive
//! summation of ~55K terms loses ~4 decimal digits; Kahan summation
//! recovers them with negligible overhead (~2 extra FLOPs per term).

pub mod numerics;
pub mod gradient;
pub mod conjugate_gradient;
pub mod evolution;
pub mod hybrid;

// Re-export the public API so callers can `use agent::*`
#[allow(unused_imports)]
pub use gradient::GradientAgent;
#[allow(unused_imports)]
pub use conjugate_gradient::ConjugateGradientAgent;
#[allow(unused_imports)]
pub use evolution::{EvolutionAgent, EvolutionResult};
#[allow(unused_imports)]
pub use hybrid::{HybridAgent, HybridStepResult, AgentPhase};
