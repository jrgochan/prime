"use client";

import { useEffect, useRef } from "react";
import init, { HyperEngine } from "../wasm/core_engine.js";
import { PARTICLE_COUNT } from "./types";
import { useViewportStore } from "../stores/viewport";

/**
 * WASM lifecycle hook — boots the HyperEngine, binds both buffers,
 * and cleans up on unmount to prevent memory leaks.
 */
export function useHyperEngine() {
  const engineRef = useRef<HyperEngine | null>(null);
  const setEngineState = useViewportStore((s) => s.setEngineState);
  const setHyperSystem = useViewportStore((s) => s.setHyperSystem);

  useEffect(() => {
    let cancelled = false;

    const boot = async () => {
      try {
        setEngineState("booting");
        const wasmModule = await init();

        if (cancelled) return;
        setEngineState("allocating");

        const engine = new HyperEngine(PARTICLE_COUNT);
        engineRef.current = engine;

        const outPtr = engine.get_buffer_pointer();
        const outputBuffer = new Float32Array(
          wasmModule.memory.buffer,
          outPtr,
          PARTICLE_COUNT * 3
        );

        const inPtr = engine.get_input_buffer_pointer();
        const inputBuffer = new Float32Array(
          wasmModule.memory.buffer,
          inPtr,
          PARTICLE_COUNT * 3
        );

        if (cancelled) {
          engine.free();
          engineRef.current = null;
          return;
        }

        setHyperSystem({ engine, outputBuffer, inputBuffer });
      } catch (e) {
        console.error("[HyperEngine] WASM boot failed:", e);
        setEngineState("booting");
      }
    };

    boot();

    return () => {
      cancelled = true;
      if (engineRef.current) {
        engineRef.current.free();
        engineRef.current = null;
        console.log("[HyperEngine] WASM memory freed.");
      }
    };
  }, [setEngineState, setHyperSystem]);
}
