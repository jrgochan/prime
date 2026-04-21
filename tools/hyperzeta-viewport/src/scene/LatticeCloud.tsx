"use client";

import { useRef } from "react";
import { useFrame } from "@react-three/fiber";
import * as THREE from "three";
import { useViewportStore } from "../stores/viewport";
import { PARTICLE_COUNT } from "../engine/types";
import { VIZ_MAP } from "../content/visualizations";

import { vertexShader, fragmentShader } from "./shaders/lattice";

// Pre-build Three.js color objects from registry
const colorCache = new Map<string, { core: THREE.Color; edge: THREE.Color }>();
function getColors(modeId: string) {
  if (!colorCache.has(modeId)) {
    const viz = VIZ_MAP[modeId as keyof typeof VIZ_MAP];
    colorCache.set(modeId, {
      core: new THREE.Color(viz.color.core),
      edge: new THREE.Color(viz.color.edge),
    });
  }
  return colorCache.get(modeId)!;
}

/**
 * GPU-accelerated particle cloud using THREE.Points + custom GLSL shaders.
 * All rendering state is read from the Visualization Registry.
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
    const { hyperSystem, viewMode, speed, paused } =
      useViewportStore.getState();
    if (!hyperSystem) return;

    const { engine, outputBuffer, inputBuffer } = hyperSystem;

    // Tick physics (skip when paused)
    if (!paused) {
      for (let s = 0; s < speed; s++) {
        engine.tick_physics();
      }
    }
    frameCount.current += 1;

    // Update metrics at ~10Hz
    if (frameCount.current % 6 === 0) {
      const c = engine.get_collapse_metric();
      const l = engine.get_lambda();
      useViewportStore.getState().updateMetrics(c, l);
    }

    // Select buffer from registry
    const viz = VIZ_MAP[viewMode];
    const activeBuffer = viz.usesOutputBuffer ? outputBuffer : inputBuffer;

    // Copy WASM buffer into geometry attribute
    // Guard: WASM memory may have grown, invalidating the view.
    // Also guard against buffer size mismatch.
    const posAttr = geometryRef.current!.getAttribute(
      "position"
    ) as THREE.BufferAttribute;
    const targetArr = posAttr.array as Float32Array;
    const copyLen = Math.min(targetArr.length, activeBuffer.length);
    try {
      targetArr.set(activeBuffer.subarray(0, copyLen));
    } catch {
      // Buffer detached — views will be refreshed on next engine init
      return;
    }
    posAttr.needsUpdate = true;

    // Update shader uniforms from registry colors
    if (materialRef.current) {
      const palette = getColors(viewMode);
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
          uCoreColor: { value: new THREE.Color("#00ff88") },
          uEdgeColor: { value: new THREE.Color("#006644") },
          uCollapse: { value: 1.0 },
          uTime: { value: 0.0 },
        }}
      />
    </points>
  );
}
