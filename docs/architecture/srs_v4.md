# Software Requirements Specification (SRS)
## Project: Project HYPERZETA
**Date:** March 26, 2026
**Version:** 5.0 (The Ultimate M2 Edge Architecture)

---

## 1. Introduction
Project HYPERZETA V5 is an automated mathematical proof visualization engine targeting the Riemann Hypothesis. It leverages autonomous agents and Lean 4 formalization, engineered specifically to exploit the physical architecture of Apple Silicon (M2 Max) via in-memory SharedArrayBuffers and Core ML Neural steering.

## 2. System Architecture

### 2.1 Backend Orchestration (Rust + Accelerate)
*   **Hyper-Engine Daemon:** A standalone **Rust** application managing arbitrary-precision algebraic calculations (`Arb`) and AMX hardware-accelerated GUE matrices.
*   **Agent Memory (Vector DB):** Hosted Qdrant/Milvus instance where topological states are embedded to grant the RL Agent "memory" across hyper-gradient descent searches.
*   **Python/FastAPI:** Relegated exclusively to external network orchestration (Vector DB queries, remote Lean 4 LLM translation requests, and Core ML bootstrapping).

### 2.2 Frontend Viewport (WASM + Dual-Precision Next.js GPU)
*   **The WASM Shared Memory Bypass:** The Rust hyper-engine projection logic compiles down to WebAssembly (WASM). It lives directly inside the Next.js browser thread. Data transfer occurs via **SharedArrayBuffers** directly mapping Rust variables into the Next.js WebGPU memory space, completely bypassing `localhost` sockets for real-time 16D rotations.
*   **The WebGPU 32-Bit Illusion:** Because WebGPU strictly renders `f32` (32-bit floats), it acts as a **Dual-Precision "Dumb Monitor"**. WebGPU only calculates local *f32 deltas* to render pixels, while the Rust core maintains identical 256-bit spatial coordinates for topological RL steerage.

## 3. Local Deployment Hardware Specification
> [!TIP]
> **Analyzed Host Environment: Apple MacBook Pro (Mac14,6) M2 Max (12-Core CPU, 38-Core GPU, 16-core ANE) with 96 GB RAM.**

*   **Unified Memory (96GB):** Next.js WebGPU shaders and WASM workers have direct, zero-copy access to nearly 96GB of RAM, allowing the engine to cache $10^8$ point lattices natively.
*   **The Apple Neural Engine (ANE):** The RL Agent's Surrogate Betti Estimator (Neural Network) must be exported to `.mlpackage` (Core ML). The M2's 16-Core ANE evaluates the network natively, drawing zero processing power from the 38-core GPU or 12-core CPU.

## 4. The Discovery Pipeline
*   **Zero-Divisor Search**: The WASM/Rust core uses hyper-gradient descent and Sobol sequences to find manifolds where $\mathbb{S} \times \mathbb{S} = 0$.
*   **RL Auto-Align Agent:** An ANE-accelerated auto-steer agent evaluates Betti structural symmetries.
*   **Lean 4 Exporter:** The Rust core dynamically strips massive raw numbers from the state trace before translating purely symbolic geometric invariants into a `.lean` proof file.
