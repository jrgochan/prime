import { HyperEngine } from "../wasm/core_engine.js";

export type ViewMode = "output" | "input";
export type CameraPreset = "orbital" | "zero-focus" | "side";
export type EngineState = "booting" | "allocating" | "running" | "collapsed";

export const PARTICLE_COUNT = 150_000;

export interface HyperSystem {
  engine: HyperEngine;
  outputBuffer: Float32Array;
  inputBuffer: Float32Array;
}
