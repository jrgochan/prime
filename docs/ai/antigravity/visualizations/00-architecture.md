# HyperZeta Viewport v2 — Architecture Overview

> **Status**: Planning Phase
> **Branch**: `visualizations`
> **Date**: April 28, 2026

## Vision

The HyperZeta Viewport is an interactive 3D visualization of the Cathedral's
proof architecture. Each visualization maps directly to a Lean module and/or
a Rust experiment, creating a **proof ↔ visualization isomorphism** where
the app's structure mirrors the Cathedral's mathematical structure.

## Current State (v1)

- 11 visualization modes (particle-based, WASM-powered)
- Single monolithic WASM engine (`core_engine.wasm`, 72KB)
- Single renderer (`LatticeCloud.tsx` — `THREE.Points` only)
- Registry-driven: adding a viz = one object in `visualizations.ts`
- Zustand store for global state
- React Three Fiber + custom GLSL shaders
- Full HUD: command palette, keyboard shortcuts, equation overlay

## Target State (v2)

- **22 visualization modes** across 4 proof-mapped groups
- **5 renderer types**: particles, curves, surfaces, charts, graphs
- **3 data tiers**: live (WASM), precomputed (JSON certificates), static (metadata)
- Enhanced registry with proof metadata and Cathedral mapping
- Grouped ModeBar organized by proof module
- Proof breadcrumb showing where each viz sits in the proof chain

## Design Principles

1. **Proof Isomorphism** — Every visualization traces to a Lean file
2. **Renderer Abstraction** — Different math needs different visuals
3. **Registry-Driven** — One entry per viz, zero boilerplate
4. **Progressive Enhancement** — All 11 existing modes work unchanged
5. **Data Pipeline** — Rust experiment certificates feed precomputed modes
6. **Educational** — Every viz teaches the underlying mathematics

## Documentation Index

| Document | Contents |
|----------|----------|
| [00-architecture.md](00-architecture.md) | This file — overview and principles |
| [01-renderer-system.md](01-renderer-system.md) | Renderer abstraction layer, component tree, shader strategy |
| [02-visualization-catalog.md](02-visualization-catalog.md) | All 22 modes with specs, data sources, and visual descriptions |
| [03-data-pipeline.md](03-data-pipeline.md) | Three-tier data architecture, certificate loading, WASM strategy |
| [04-implementation-phases.md](04-implementation-phases.md) | Phase-by-phase build plan with task lists |

## Technology Stack

| Layer | Technology | Role |
|-------|-----------|------|
| Framework | Next.js 16 | App shell, routing |
| 3D Engine | React Three Fiber 9 + Three.js 0.183 | 3D rendering |
| WASM Engine | Rust → wasm-bindgen | Live particle simulation |
| State | Zustand 5 | Global state management |
| Charts | HTML Canvas 2D | 2D convergence plots |
| Graphs | Custom force-directed | Proof tree visualization |
| Shaders | Custom GLSL | GPU-accelerated rendering |
| Styling | Tailwind CSS 4 | UI components |

## Key Decisions

1. **Apps stay separate** — HyperZeta and visualizer remain independent
2. **Hybrid WASM** — Keep existing WASM for live modes, pure TS for precomputed/static
3. **No new WASM compilation** — New modes use JS/TS computation or precomputed data
4. **Backward compatible** — All 11 existing modes work unchanged through the new architecture
