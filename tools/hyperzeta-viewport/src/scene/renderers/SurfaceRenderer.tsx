"use client";

import { useRef, useMemo } from "react";
import { useFrame } from "@react-three/fiber";
import * as THREE from "three";
import { useViewportStore } from "../../stores/viewport";
import { VIZ_MAP } from "../../content/visualizations";

/**
 * SurfaceRenderer — height-field surface for Gram Heatmap
 * and Spectral Gap visualizations.
 *
 * Renders a PlaneGeometry with vertex displacement driven by
 * a procedurally generated height map. Color mapping via
 * a 3-stop gradient: low → mid → high.
 */
export function SurfaceRenderer() {
  const meshRef = useRef<THREE.Mesh>(null);
  const viewMode = useViewportStore((s) => s.viewMode);
  const viz = VIZ_MAP[viewMode];

  // Generate height data for the surface
  const { geometry, heightTexture } = useMemo(() => {
    const res = 64;
    const geo = new THREE.PlaneGeometry(12, 12, res - 1, res - 1);

    // Generate height data based on mode
    const heights = generateHeightData(viewMode, res);

    // Apply displacement directly to geometry vertices
    const posAttr = geo.getAttribute("position");
    for (let i = 0; i < posAttr.count; i++) {
      const ix = i % res;
      const iy = Math.floor(i / res);
      posAttr.setZ(i, heights[iy * res + ix] * 4);
    }
    posAttr.needsUpdate = true;
    geo.computeVertexNormals();

    // Create DataTexture for height coloring
    const data = new Uint8Array(res * res * 4);
    for (let i = 0; i < res * res; i++) {
      const h = Math.max(0, Math.min(1, heights[i]));
      data[i * 4] = Math.floor(h * 255);
      data[i * 4 + 1] = Math.floor(h * 255);
      data[i * 4 + 2] = Math.floor(h * 255);
      data[i * 4 + 3] = 255;
    }
    const tex = new THREE.DataTexture(data, res, res, THREE.RGBAFormat);
    tex.needsUpdate = true;

    return { geometry: geo, heightTexture: tex };
  }, [viewMode]);

  useFrame(({ clock }) => {
    if (!meshRef.current) return;
    meshRef.current.rotation.x = -Math.PI * 0.35;
    meshRef.current.rotation.z = clock.getElapsedTime() * 0.05;
  });

  // Colors from viz registry
  const coreColor = new THREE.Color(viz?.color?.core ?? "#00ccff");
  const edgeColor = new THREE.Color(viz?.color?.edge ?? "#004466");

  return (
    <mesh ref={meshRef} geometry={geometry} position={[0, 0, -2]}>
      <meshStandardMaterial
        color={coreColor}
        emissive={edgeColor}
        emissiveIntensity={0.3}
        wireframe={false}
        side={THREE.DoubleSide}
        transparent
        opacity={0.85}
        roughness={0.6}
        metalness={0.2}
      />
    </mesh>
  );
}

// ── Height Data Generators ──────────────────────────────────

function generateHeightData(mode: string, res: number): Float32Array {
  switch (mode) {
    case "gram-heatmap":
      return generateGramHeatmap(res);
    case "spectral-gap":
      return generateSpectralGap(res);
    default:
      return generateGramHeatmap(res);
  }
}

/**
 * Gram matrix |G(j,k)| — strong diagonal, decaying off-diagonal
 * with Vasyunin cotangent structure.
 */
function generateGramHeatmap(res: number): Float32Array {
  const data = new Float32Array(res * res);
  for (let j = 0; j < res; j++) {
    for (let k = 0; k < res; k++) {
      const jj = j + 1;
      const kk = k + 1;
      // Diagonal: high values
      const diag = Math.exp(-0.5 * ((j - k) / 3) ** 2);
      // Off-diagonal: 1/(j+k) decay with cotangent oscillation
      const offDiag =
        (0.2 / (jj + kk)) *
        Math.abs(Math.cos((Math.PI * jj) / kk));
      data[j * res + k] = Math.min(1, diag * 0.8 + offDiag);
    }
  }
  return data;
}

/**
 * Spectral gap: eigenvalue floor with variations.
 */
function generateSpectralGap(res: number): Float32Array {
  const data = new Float32Array(res * res);
  for (let j = 0; j < res; j++) {
    for (let k = 0; k < res; k++) {
      const x = (j / res) * 2 - 1;
      const y = (k / res) * 2 - 1;
      const r = Math.sqrt(x * x + y * y);
      // Bowl shape with floor at ~0.3
      const height = 0.3 + 0.7 * r * r + 0.1 * Math.sin(r * 10);
      data[j * res + k] = Math.min(1, height);
    }
  }
  return data;
}
