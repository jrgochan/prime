import { HyperEngine } from "../wasm/core_engine.js";

// The 12 visualization modes
export type ViewMode =
  | "output"         // ζ(s) output cloud — breathing particles
  | "spiral"         // Riemann zeta spiral — ζ(½+it) rings
  | "partial-sums"   // Cornu spirals — Dirichlet partial sums
  | "landscape"      // Zero landscape — |ζ(σ+it)| height field
  | "euler-rose"     // Euler product rose — prime factor accumulation
  | "tower"          // Cayley-Dickson tower — ℂ → ℍ → 𝕆 → 𝕊
  | "waves"          // Explicit formula — zero correction waves
  | "mirror"         // Functional equation — ζ(s) ↔ ζ(1-s) mirror
  | "gue"            // GUE random matrix — eigenvalue vs zeros
  | "mertens"        // Mertens turbulence — M(x) random walk
  | "spectral-gap"   // Spectral gap heatmap — Gram eigenvalue surface
  | "harmonics";     // Prime harmonics — log(p) standing waves

// Maps ViewMode → WASM view_mode u8 (only for input-buffer modes)
export const VIEW_MODE_WASM: Record<ViewMode, number> = {
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

export type CameraPreset = "orbital" | "zero-focus" | "side";
export type EngineState = "booting" | "allocating" | "running" | "collapsed";

// Default particle count — user can change at runtime via slider
export const DEFAULT_PARTICLE_COUNT = 50_000;

export interface HyperSystem {
  engine: HyperEngine;
  outputBuffer: Float32Array;
  inputBuffer: Float32Array;
}
