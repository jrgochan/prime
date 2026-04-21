"use client";

import { useRef } from "react";
import { useFrame } from "@react-three/fiber";
import * as THREE from "three";
import { useViewportStore } from "../stores/viewport";
import { PARTICLE_COUNT } from "../engine/types";

import { vertexShader, fragmentShader } from "./shaders/lattice";

// Color palettes per view mode
const COLORS = {
  output: {
    core: new THREE.Color("#00ff88"),
    edge: new THREE.Color("#006644"),
  },
  input: {
    core: new THREE.Color("#00ccff"),
    edge: new THREE.Color("#004466"),
  },
};

/**
 * GPU-accelerated particle cloud using THREE.Points + custom GLSL shaders.
 *
 * - 150K single-vertex points (vs 4.8M vertices with InstancedMesh)
 * - Position data read directly from WASM shared memory
 * - Fragment shader renders circular particles with glow + gradient
 * - All state read from Zustand (no stale closures)
 */
export function LatticeCloud() {
  const pointsRef = useRef<THREE.Points>(null);
  const materialRef = useRef<THREE.ShaderMaterial>(null);
  const frameCount = useRef(0);

  // Stable geometry with pre-allocated position buffer
  const geometryRef = useRef<THREE.BufferGeometry | null>(null);
  if (!geometryRef.current) {
    const geo = new THREE.BufferGeometry();
    const positions = new Float32Array(PARTICLE_COUNT * 3);
    geo.setAttribute("position", new THREE.BufferAttribute(positions, 3));
    geometryRef.current = geo;
  }

  useFrame(() => {
    // Read directly from Zustand store — never stale
    const { hyperSystem, viewMode, speed, collapse, lambda } =
      useViewportStore.getState();
    if (!hyperSystem) return;

    const { engine, outputBuffer, inputBuffer } = hyperSystem;

    // Tick physics at configured speed
    for (let s = 0; s < speed; s++) {
      engine.tick_physics();
    }
    frameCount.current += 1;

    // Update metrics at ~10Hz
    if (frameCount.current % 6 === 0) {
      const c = engine.get_collapse_metric();
      const l = engine.get_lambda();
      useViewportStore.getState().updateMetrics(c, l);
    }

    // Select active buffer based on view mode
    const activeBuffer = viewMode === "input" ? inputBuffer : outputBuffer;

    // Copy WASM buffer into geometry attribute (zero-copy read, single write)
    const posAttr = geometryRef.current!.getAttribute(
      "position"
    ) as THREE.BufferAttribute;
    const posArray = posAttr.array as Float32Array;
    posArray.set(activeBuffer);
    posAttr.needsUpdate = true;

    // Update shader uniforms
    if (materialRef.current) {
      const palette = COLORS[viewMode];
      materialRef.current.uniforms.uCoreColor.value.copy(palette.core);
      materialRef.current.uniforms.uEdgeColor.value.copy(palette.edge);
      materialRef.current.uniforms.uCollapse.value =
        useViewportStore.getState().collapse;
      materialRef.current.uniforms.uTime.value =
        useViewportStore.getState().lambda;
    }
  });

  return (
    <points ref={pointsRef} geometry={geometryRef.current!}>
      <shaderMaterial
        ref={materialRef}
        vertexShader={vertexShader}
        fragmentShader={fragmentShader}
        transparent
        depthWrite={false}
        blending={THREE.AdditiveBlending}
        uniforms={{
          uCoreColor: { value: COLORS.output.core.clone() },
          uEdgeColor: { value: COLORS.output.edge.clone() },
          uCollapse: { value: 1.0 },
          uTime: { value: 0.0 },
        }}
      />
    </points>
  );
}
