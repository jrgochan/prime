import { HyperEngine } from "../wasm/core_engine.js";

// ── Renderer Types ──────────────────────────────────────────────
// Each visualization declares which renderer it needs.

export type RendererType =
  | "particles"       // THREE.Points — GPU particle cloud
  | "curves"          // THREE.Line — glowing line geometry
  | "surface"         // THREE.Mesh — displacement-mapped surface
  | "chart"           // HTML Canvas 2D overlay
  | "graph"           // Force-directed graph overlay
  | "dual-chart"      // Split-screen 2D charts
  | "dual-particles"; // Split-screen 3D particle clouds

// ── Data Tiers ──────────────────────────────────────────────────

export type DataTier =
  | "live"            // WASM engine tick_physics() — 60fps
  | "precomputed"     // JSON certificates from Rust experiments
  | "static";         // Hardcoded proof metadata

// ── Visualization Groups ────────────────────────────────────────
// Modes are organized by proof module for the grouped ModeBar.

export type VizGroup =
  | "crown"           // 🏛️ Proof architecture
  | "analysis"        // 🔬 Mathematical engine
  | "arithmetic"      // ⚡ Number theory core
  | "spectral";       // 🎵 Physics layer

// ── View Modes ──────────────────────────────────────────────────
// All visualization mode IDs. New modes are added here.

export type ViewMode =
  // Existing (v1)
  | "output"          // ζ(s) output cloud — breathing particles
  | "spiral"          // Riemann zeta spiral — ζ(½+it) rings
  | "partial-sums"    // Cornu spirals — Dirichlet partial sums
  | "landscape"       // Zero landscape — |ζ(σ+it)| height field
  | "euler-rose"      // Euler product rose — prime factor accumulation
  | "tower"           // Cayley-Dickson tower — ℂ → ℍ → 𝕆 → 𝕊
  | "waves"           // Explicit formula — zero correction waves
  | "mirror"          // Functional equation — ζ(s) ↔ ζ(1-s) mirror
  | "gue"             // GUE random matrix — eigenvalue vs zeros
  | "mertens"         // Mertens turbulence — M(x) random walk
  | "spectral-gap"    // Spectral gap heatmap — Gram eigenvalue surface
  | "harmonics"       // Prime harmonics — log(p) standing waves
  // New (v2) — Crown
  | "crown-theorem"   // Axiom dependency graph
  | "mellin-crown"    // Forward chain animation + L² decay chart
  | "graduation"      // v1 → v12 timeline
  // New (v2) — Analysis
  | "parseval-bridge"  // L² ↔ Mellin isometry
  | "phase-shattering" // Phase coherence vs destruction
  | "hilbert-pi"       // ‖H_N‖ → π convergence
  | "gram-heatmap"     // Gram matrix 3D heatmap
  | "vasyunin-telescope" // Row decomposition convergence
  | "mvt-cert"         // Montgomery-Vaughan certificate
  // New (v2) — Arithmetic
  | "perron-contour"   // Animated contour integral
  | "abel-thermo"      // S₁/S₂/S₃ thermodynamic hierarchy
  | "stained-glass"    // Dirichlet character decomposition
  | "bd-constant";     // Spectral holes + C ≈ 21.65

// ── WASM Mode Map ───────────────────────────────────────────────
// Maps ViewMode → WASM view_mode u8 (only for Tier 1 live modes
// that use the core engine). New chart/graph modes don't need this.

export const VIEW_MODE_WASM: Partial<Record<ViewMode, number>> = {
  output: 0,
  spiral: 0,
  "partial-sums": 1,
  landscape: 2,
  "euler-rose": 3,
  tower: 4,
  waves: 5,
  mirror: 6,
  gue: 7,
  mertens: 8,
  "spectral-gap": 9,
  harmonics: 10,
};

// ── Proof Metadata ──────────────────────────────────────────────
// Cathedral connection for each visualization.

export interface ProofMetadata {
  leanFile: string;
  theoremName?: string;
  axiomDeps?: string[];
  status: "proved" | "axiom" | "sorry";
}

// ── Camera & Engine ─────────────────────────────────────────────

export type CameraPreset = "orbital" | "zero-focus" | "side";
export type EngineState = "booting" | "allocating" | "running" | "collapsed";

// Default particle count — user can change at runtime via slider
export const DEFAULT_PARTICLE_COUNT = 50_000;

export interface HyperSystem {
  engine: HyperEngine;
  outputBuffer: Float32Array;
  inputBuffer: Float32Array;
}
