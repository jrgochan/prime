import { HyperEngine } from "../wasm/core_engine.js";

// The 6 visualization modes
export type ViewMode =
  | "output"         // ζ(s) output cloud — breathing particles
  | "spiral"         // Riemann zeta spiral — ζ(½+it) rings
  | "partial-sums"   // Cornu spirals — Dirichlet partial sums
  | "landscape"      // Zero landscape — |ζ(σ+it)| height field
  | "euler-rose"     // Euler product rose — prime factor accumulation
  | "tower";         // Cayley-Dickson tower — ℂ → ℍ → 𝕆 → 𝕊

// Maps ViewMode → WASM view_mode u8 (only for input-buffer modes)
export const VIEW_MODE_WASM: Record<ViewMode, number> = {
  output: 0,        // uses geometry_buffer, not input_buffer
  spiral: 0,
  "partial-sums": 1,
  landscape: 2,
  "euler-rose": 3,
  tower: 4,
};

export type CameraPreset = "orbital" | "zero-focus" | "side";
export type EngineState = "booting" | "allocating" | "running" | "collapsed";

export const PARTICLE_COUNT = 50_000;

export interface HyperSystem {
  engine: HyperEngine;
  outputBuffer: Float32Array;
  inputBuffer: Float32Array;
}
