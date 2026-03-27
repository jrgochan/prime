# Project HYPERZETA Data Flow

This diagram illustrates the separation of concerns inside Version 5.0, where heavy UI physics data is mapped instantly across WASM memory walls, while the Python Gateway handles orchestration.

```mermaid
sequenceDiagram
    participant WebGPU as Next.js WebGPU
    participant WASM as Rust-WASM Core
    participant OpenAPI as FastAPI Gateway
    participant RLAgent as ANE Surrogate Model
    participant Lean as Lean 4 Prover

    note over WebGPU,WASM: Phase 1: Exploration
    WebGPU->>WASM: Initialize SharedArrayBuffer
    WASM-->>WASM: Sobol Sequence Monte Carlo Dive
    WASM->>WASM: Lock 16D Coordinates in Shared RAM
    WebGPU-->>WebGPU: Render 32-bit Deltas from RAM Pointer

    note over WebGPU,RLAgent: Phase 2: Agent Alignment
    WebGPU->>OpenAPI: Toggle "Auto-Align"
    OpenAPI->>RLAgent: Spin up Apple Neural Engine
    loop High-Speed Policy Update
        RLAgent->>WASM: Read 256-bit Geometries (Vector DB Check)
        RLAgent-->>RLAgent: ANE Surrogate Betti Entropy Check
        RLAgent->>WASM: Mutate Bivector Rotations
        WASM->>WASM: Overwrite Shared RAM Matrix
        WebGPU-->>WebGPU: Render Updated Frame natively
    end
    RLAgent-->>WebGPU: E8 LATTICE LOCK ACHIEVED

    note over WebGPU,Lean: Phase 3: Formal Verification
    WebGPU->>OpenAPI: Export Hash
    OpenAPI->>WASM: Request Algebraic Bounds (No Traces)
    OpenAPI->>Lean: Stream Symbolic Invariants via LLM
    Lean-->>WebGPU: Return Proof Certificate (Q.E.D)
```
