"use client";

import { useEffect, useRef } from "react";
import init, { HyperEngine } from "../wasm/core_engine.js";
import { useViewportStore } from "../stores/viewport";

/**
 * WASM lifecycle hook — boots the HyperEngine, binds both buffers,
 * and reboots when particleCount changes.
 */
export function useHyperEngine() {
  const engineRef = useRef<HyperEngine | null>(null);
  const wasmModuleRef = useRef<any>(null);
  const setEngineState = useViewportStore((s) => s.setEngineState);
  const setHyperSystem = useViewportStore((s) => s.setHyperSystem);
  const particleCount = useViewportStore((s) => s.particleCount);

  useEffect(() => {
    let cancelled = false;

    const boot = async () => {
      try {
        setEngineState("booting");

        // Init WASM module (only first time)
        if (!wasmModuleRef.current) {
          wasmModuleRef.current = await init();
        }
        const wasmModule = wasmModuleRef.current;

        if (cancelled) return;
        setEngineState("allocating");

        // Free previous engine if rebooting
        if (engineRef.current) {
          engineRef.current.free();
          engineRef.current = null;
        }

        const engine = new HyperEngine(particleCount);
        engineRef.current = engine;

        const outPtr = engine.get_buffer_pointer();
        const outputBuffer = new Float32Array(
          wasmModule.memory.buffer,
          outPtr,
          particleCount * 3
        );

        const inPtr = engine.get_input_buffer_pointer();
        const inputBuffer = new Float32Array(
          wasmModule.memory.buffer,
          inPtr,
          particleCount * 3
        );

        if (cancelled) {
          engine.free();
          engineRef.current = null;
          return;
        }

        // Re-apply current view mode to new engine
        const { viewMode } = useViewportStore.getState();
        const { VIEW_MODE_WASM } = await import("../engine/types");
        if (viewMode !== "output") {
          engine.set_view_mode(VIEW_MODE_WASM[viewMode]);
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
  }, [particleCount, setEngineState, setHyperSystem]);
}
