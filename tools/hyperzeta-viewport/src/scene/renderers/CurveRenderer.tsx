"use client";

import { useRef, useMemo } from "react";
import { useFrame } from "@react-three/fiber";
import * as THREE from "three";
import { useViewportStore } from "../../stores/viewport";
import { VIZ_MAP } from "../../content/visualizations";
import { curveVertexShader, curveFragmentShader } from "../shaders/curves";

/**
 * CurveRenderer — renders glowing animated curves in 3D space.
 * Used for Perron Contour and Enhanced Explicit Formula modes.
 *
 * Features:
 * - Screen-space glow via additive blending
 * - Animated "traveling" dash pattern along the curve
 * - Depth-based fade for 3D perception
 * - Per-vertex color for residue highlights
 * - Animated progress reveal (line draws itself)
 */
export function CurveRenderer() {
  const groupRef = useRef<THREE.Group>(null);
  const materialRef = useRef<THREE.ShaderMaterial>(null);
  const viewMode = useViewportStore((s) => s.viewMode);
  const viz = VIZ_MAP[viewMode];

  // Generate the curve geometry based on the active mode
  const { geometry, glowGeometry } = useMemo(() => {
    const curvePoints = generateCurveData(viewMode);
    return buildCurveGeometry(curvePoints);
  }, [viewMode]);

  useFrame(({ clock }) => {
    if (!materialRef.current) return;
    const t = clock.getElapsedTime();

    materialRef.current.uniforms.uTime.value = t;
    // Animate the reveal over 3 seconds after mode switch
    const progress = Math.min(t * 0.33, 1.0);
    materialRef.current.uniforms.uProgress.value = progress;
  });

  // Build THREE.Line objects directly to avoid SVG <line> type conflict
  const coreLine = useMemo(() => {
    const mat = new THREE.ShaderMaterial({
      vertexShader: curveVertexShader,
      fragmentShader: curveFragmentShader,
      transparent: true,
      depthWrite: false,
      blending: THREE.AdditiveBlending,
      uniforms: {
        uTime: { value: 0 },
        uDashSpeed: { value: 0.3 },
        uDashLength: { value: 0.15 },
        uGlowIntensity: { value: 1.0 },
        uProgress: { value: 0 },
      },
    });
    materialRef.current = mat;
    return new THREE.Line(geometry, mat);
  }, [geometry]);

  const glowLine = useMemo(() => {
    const mat = new THREE.ShaderMaterial({
      vertexShader: curveVertexShader,
      fragmentShader: curveFragmentShader,
      transparent: true,
      depthWrite: false,
      blending: THREE.AdditiveBlending,
      uniforms: {
        uTime: { value: 0 },
        uDashSpeed: { value: 0.3 },
        uDashLength: { value: 0.15 },
        uGlowIntensity: { value: 0.2 },
        uProgress: { value: 0 },
      },
    });
    return new THREE.Line(glowGeometry, mat);
  }, [glowGeometry]);

  const coreColor = viz?.color?.core ?? "#00ccff";

  return (
    <group ref={groupRef}>
      <primitive object={glowLine} />
      <primitive object={coreLine} />
      {viewMode === "perron-contour" && <PerronMarkers />}
    </group>
  );
}

// ── Perron Contour Geometry ─────────────────────────────────

interface CurvePoint {
  position: [number, number, number];
  color: [number, number, number];
  arcLength: number;
}

function generateCurveData(mode: string): CurvePoint[] {
  switch (mode) {
    case "perron-contour":
      return generatePerronContour();
    default:
      return generateDefaultCurve();
  }
}

/**
 * Perron contour integral in the complex plane:
 * Vertical line at Re(s) = c, sweeping from c=2 toward c=1/2+ε
 *
 * The contour is:  c - iT → c + iT  (vertical line)
 * with horizontal segments fading at Im(s) = ±T
 */
function generatePerronContour(): CurvePoint[] {
  const points: CurvePoint[] = [];
  const N = 300;
  const T = 8; // Height of the vertical line
  let arc = 0;

  // Cyan for the main contour
  const cyan: [number, number, number] = [0.0, 0.8, 1.0];
  const white: [number, number, number] = [1.0, 1.0, 1.0];
  const dim: [number, number, number] = [0.2, 0.4, 0.6];

  // 1. Bottom horizontal (fading in from left)
  for (let i = 0; i < 40; i++) {
    const t = i / 39;
    const x = -6 + t * 8; // from x=-6 to x=2
    const y = -T;
    arc += 0.01;
    points.push({
      position: [x, y, 0],
      color: [dim[0] * t, dim[1] * t, dim[2] * t],
      arcLength: arc / (N * 0.01),
    });
  }

  // 2. Main vertical line at c=2
  for (let i = 0; i < N; i++) {
    const t = i / (N - 1);
    const y = -T + t * 2 * T;
    arc += 0.01;

    // Flash white near s=1 (y ≈ 0, x = 2... but we show it at y=0)
    const distToOne = Math.abs(y);
    const isNearPole = distToOne < 0.5;
    const c: [number, number, number] = isNearPole
      ? [
          cyan[0] + (white[0] - cyan[0]) * (1 - distToOne * 2),
          cyan[1] + (white[1] - cyan[1]) * (1 - distToOne * 2),
          cyan[2] + (white[2] - cyan[2]) * (1 - distToOne * 2),
        ]
      : cyan;

    points.push({
      position: [2, y, 0],
      color: c,
      arcLength: arc / (N * 0.01),
    });
  }

  // 3. Top horizontal (fading out to left)
  for (let i = 0; i < 40; i++) {
    const t = i / 39;
    const x = 2 - t * 8;
    const y = T;
    arc += 0.01;
    points.push({
      position: [x, y, 0],
      color: [dim[0] * (1 - t), dim[1] * (1 - t), dim[2] * (1 - t)],
      arcLength: arc / (N * 0.01),
    });
  }

  return points;
}

function generateDefaultCurve(): CurvePoint[] {
  const points: CurvePoint[] = [];
  for (let i = 0; i < 200; i++) {
    const t = i / 199;
    const theta = t * Math.PI * 4;
    points.push({
      position: [
        Math.cos(theta) * (2 + t * 3),
        Math.sin(theta) * (2 + t * 3),
        t * 5 - 2.5,
      ],
      color: [0.0, 1.0 * (1 - t) + 0.5 * t, 0.5 + 0.5 * t],
      arcLength: t,
    });
  }
  return points;
}

// ── Geometry Builder ────────────────────────────────────────

function buildCurveGeometry(points: CurvePoint[]) {
  const positions = new Float32Array(points.length * 3);
  const colors = new Float32Array(points.length * 3);
  const arcLengths = new Float32Array(points.length);

  points.forEach((p, i) => {
    positions[i * 3] = p.position[0];
    positions[i * 3 + 1] = p.position[1];
    positions[i * 3 + 2] = p.position[2];
    colors[i * 3] = p.color[0];
    colors[i * 3 + 1] = p.color[1];
    colors[i * 3 + 2] = p.color[2];
    arcLengths[i] = p.arcLength;
  });

  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute("position", new THREE.BufferAttribute(positions, 3));
  geometry.setAttribute("aColor", new THREE.BufferAttribute(colors, 3));
  geometry.setAttribute("aArcLength", new THREE.BufferAttribute(arcLengths, 1));

  // Glow version uses the same geometry (the shader handles the width)
  const glowGeometry = geometry.clone();

  return { geometry, glowGeometry };
}

// ── Residue Markers ─────────────────────────────────────────

function PerronMarkers() {
  const meshRef = useRef<THREE.Mesh>(null);

  useFrame(({ clock }) => {
    if (!meshRef.current) return;
    const t = clock.getElapsedTime();
    const scale = 1 + 0.3 * Math.sin(t * 3);
    meshRef.current.scale.setScalar(scale);
    (meshRef.current.material as THREE.MeshBasicMaterial).opacity =
      0.6 + 0.4 * Math.sin(t * 3);
  });

  return (
    <mesh ref={meshRef} position={[2, 0, 0]}>
      <sphereGeometry args={[0.15, 16, 16]} />
      <meshBasicMaterial
        color="#ffffff"
        transparent
        opacity={0.8}
        blending={THREE.AdditiveBlending}
      />
    </mesh>
  );
}
