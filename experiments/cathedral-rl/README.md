# cathedral-rl

Reinforcement learning environment for the Gram form inequality.

## The Problem

The Cathedral reduces the Riemann Hypothesis to a matrix optimization:
given the Gram matrix `G_N` (built from GCD structure and logarithms)
and a witness vector `v`, show that `vᵀGv ≤ 1 + K/ln(N)`.

This environment lets an RL agent explore weight perturbations to:

1. **Minimize** `vᵀGv` (the quadratic form)
2. **Maximize** `bᵀv` (target: 1)
3. **Minimize** `d² = 1 - 2bᵀv + vᵀGv` (the Nyman–Beurling distance)

## Architecture

```
src/
├── main.rs         — Entry point and CLI
├── env.rs          — RL environment (state, action, reward)
├── agent/          — Policy implementations
├── precision/      — Multi-precision arithmetic backends
├── certificate.rs  — Export winning vectors as Lean oracle certificates
├── runner.rs       — Training loop
└── output.rs       — Logging and visualization
```

## Running

```bash
cargo run --release
```

GPU-accelerated via CUDA for fast Gram matrix evaluation at large N.
The discovered witness vectors can be exported as JSON certificates
for import into the Lean oracle axioms.
