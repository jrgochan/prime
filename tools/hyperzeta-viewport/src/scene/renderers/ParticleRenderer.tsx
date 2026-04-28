"use client";

import { useRef } from "react";
import { useFrame } from "@react-three/fiber";
import * as THREE from "three";
import { useViewportStore } from "../../stores/viewport";
import { VIZ_MAP } from "../../content/visualizations";

import { vertexShader, fragmentShader } from "../shaders/lattice";

// Pre-build Three.js color objects from registry
const colorCache = new Map<string, { core: THREE.Color; edge: THREE.Color }>();
function getColors(modeId: string) {
  if (!colorCache.has(modeId)) {
    const viz = VIZ_MAP[modeId as keyof typeof VIZ_MAP];
    if (!viz) return { core: new THREE.Color("#00ff88"), edge: new THREE.Color("#006644") };
    colorCache.set(modeId, {
      core: new THREE.Color(viz.color.core),
      edge: new THREE.Color(viz.color.edge),
    });
  }
  return colorCache.get(modeId)!;
}

/**
 * GPU-accelerated particle cloud using THREE.Points + custom GLSL shaders.
 * Extracted from LatticeCloud.tsx for the renderer abstraction layer.
 * Handles all particle-based visualization modes (Tier 1 / Live).
 */
export function ParticleRenderer() {
  const pointsRef = useRef<THREE.Points>(null);
  const materialRef = useRef<THREE.ShaderMaterial>(null);
  const frameCount = useRef(0);

  // Track geometry size to rebuild when particle count changes
  const geometryRef = useRef<THREE.BufferGeometry | null>(null);
  const lastCountRef = useRef<number>(0);

  useFrame(() => {
    const { hyperSystem, viewMode, speed, paused, particleCount } =
      useViewportStore.getState();
    if (!hyperSystem) return;

    const { engine, outputBuffer, inputBuffer } = hyperSystem;

    // Rebuild geometry if particle count changed
    if (particleCount !== lastCountRef.current) {
      const geo = new THREE.BufferGeometry();
      const positions = new Float32Array(particleCount * 3);
      geo.setAttribute("position", new THREE.BufferAttribute(positions, 3));

      // Replace geometry on the points mesh
      if (pointsRef.current) {
        if (geometryRef.current) geometryRef.current.dispose();
        pointsRef.current.geometry = geo;
      }
      geometryRef.current = geo;
      lastCountRef.current = particleCount;
    }

    if (!geometryRef.current) return;

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
    if (!viz) return;
    const activeBuffer = viz.usesOutputBuffer ? outputBuffer : inputBuffer;

    // Copy WASM buffer into geometry attribute
    const posAttr = geometryRef.current.getAttribute(
      "position"
    ) as THREE.BufferAttribute;
    const targetArr = posAttr.array as Float32Array;
    const copyLen = Math.min(targetArr.length, activeBuffer.length);
    try {
      targetArr.set(activeBuffer.subarray(0, copyLen));
    } catch {
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

  // Initialize geometry on first render
  if (!geometryRef.current) {
    const count = useViewportStore.getState().particleCount;
    const geo = new THREE.BufferGeometry();
    const positions = new Float32Array(count * 3);
    geo.setAttribute("position", new THREE.BufferAttribute(positions, 3));
    geometryRef.current = geo;
    lastCountRef.current = count;
  }

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
