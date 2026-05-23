"use client";

import { Canvas, useFrame } from "@react-three/fiber";
import { OrbitControls, Html } from "@react-three/drei";
import { useEffect, useState, useRef, useMemo, useCallback } from "react";
import * as THREE from "three";

import init, { HyperEngine } from "../wasm/core_engine.js";
import { ZETA_ARGS, PI_POWERS, gridValue, MATCHES, CATEGORY_COLORS, getGridMatches } from "./spectrometer-data";
import Heptadecagon from "./heptadecagon";

const DEFAULT_PARTICLE_COUNT = 25_000;

const KNOWN_ZEROS = [
  14.134725, 21.022040, 25.010858, 30.424876, 32.935062,
  37.586178, 40.918719, 43.327073, 48.005151, 49.773832,
];

// ═══════════════════════════════════════════════════════
// PRESETS
// ═══════════════════════════════════════════════════════

const N_PRESETS = [
  { label: "25K", value: 25_000 },
  { label: "50K", value: 50_000 },
  { label: "100K", value: 100_000 },
  { label: "150K", value: 150_000 },
  { label: "250K", value: 250_000 },
];

const SPEED_PRESETS = [
  { label: "¼×", value: 0.25 },
  { label: "½×", value: 0.5 },
  { label: "1×", value: 1 },
  { label: "2×", value: 2 },
  { label: "4×", value: 4 },
  { label: "8×", value: 8 },
];

// ═══════════════════════════════════════════════════════
// MODE DEFINITIONS
// ═══════════════════════════════════════════════════════

interface ViewMode {
  id: number;
  name: string;
  subtitle: string;
  formula: string;
  coreColor: string;
  edgeColor: string;
  hotkey: string;
}

const VIEW_MODES: ViewMode[] = [
  {
    id: 0,
    name: "ORIGIN",
    subtitle: "Classic Sedenion Sweep",
    formula: "ζ_𝕊(s) = Σ n⁻ˢ",
    coreColor: "#00ff88",
    edgeColor: "#006644",
    hotkey: "1",
  },
  {
    id: 1,
    name: "TEARDROP",
    subtitle: "Riemann Sphere · Stereographic",
    formula: "P(z) = (2z/(1+|z|²), (|z|²-1)/(1+|z|²))",
    coreColor: "#8844ff",
    edgeColor: "#220066",
    hotkey: "2",
  },
  {
    id: 2,
    name: "GLASS STAIRCASE",
    subtitle: "Cayley-Dickson Layer Decomposition",
    formula: "ℝ → ℂ → ℍ → 𝕆 → 𝕊 → 𝕋",
    coreColor: "#ff8800",
    edgeColor: "#442200",
    hotkey: "3",
  },
  {
    id: 3,
    name: "DIVISION BY ZERO",
    subtitle: "Möbius Inverse · 1/ζ(s)",
    formula: "1/ζ(s) = Σ μ(n)/nˢ   μ ∈ {-1, 0, +1}",
    coreColor: "#ff0044",
    edgeColor: "#440011",
    hotkey: "4",
  },
  {
    id: 4,
    name: "SPECTROMETER",
    subtitle: "Spectral Lift Grid · π^n / ζ(k)",
    formula: "m_p/m_e = π⁷/ζ(2) = 6π⁵",
    coreColor: "#ffd700",
    edgeColor: "#664400",
    hotkey: "5",
  },
  {
    id: 5,
    name: "PRIME DEMOCRACY",
    subtitle: "S³¹ Zero Distribution · Trigintaduonion",
    formula: "Z(t) = Σ sin(t·ln pₖ)·eₖ  |  31 primes, 31 dimensions",
    coreColor: "#00ffdd",
    edgeColor: "#004444",
    hotkey: "6",
  },
  {
    id: 6,
    name: "HEPTADECAGON",
    subtitle: "Gauss's 17-gon · Cayley-Dickson Folding",
    formula: "16 = 2⁴ → ℝ ← ℂ ← ℍ ← 𝕆 ← 𝕊",
    coreColor: "#aa44ff",
    edgeColor: "#330066",
    hotkey: "7",
  },
];

const LAYER_COLORS = [
  "#ffffff", // ℝ — white (real, pure)
  "#00aaff", // ℂ — blue (complex)
  "#ffaa00", // ℍ — gold (quaternion)
  "#00ff88", // 𝕆 — green (octonion)
  "#ff00aa", // 𝕊 — magenta (sedenion)
  "#00ffdd", // 𝕋 — cyan (trigintaduonion)
  "#ff6600", // 𝕍 — orange (64-nion)
  "#ffffcc", // ∞ — white-gold (glass clears)
];

const LAYER_NAMES = ["ℝ", "ℂ", "ℍ", "𝕆", "𝕊", "𝕋", "𝕍", "∞"];

// ═══════════════════════════════════════════════════════
// SPECTROMETER GRID COMPONENT
// ═══════════════════════════════════════════════════════

const TIER_SCALE = { Star: 0.7, Lightning: 0.5, Dot: 0.3 };

function SpectrometerGrid() {
  const groupRef = useRef<THREE.Group>(null);
  const timeRef = useRef(0);

  const matchMap = useMemo(() => getGridMatches(), []);

  // Build grid points
  const gridPoints = useMemo(() => {
    const pts: { n: number; k: number; val: number; x: number; y: number; z: number; matches: typeof MATCHES }[] = [];
    for (const n of PI_POWERS) {
      for (const k of ZETA_ARGS) {
        const val = gridValue(n, k);
        const x = (n - 5.5) * 2.5;
        const z = (ZETA_ARGS.indexOf(k) - 2.5) * 3;
        const y = Math.log10(Math.max(val, 0.01)) * 2.5 - 5;
        const key = `${n},${k}`;
        pts.push({ n, k, val, x, y, z, matches: matchMap.get(key) || [] });
      }
    }
    return pts;
  }, [matchMap]);

  // Non-grid matches (pure zeta, integers, etc.)
  const offGridMatches = useMemo(() => {
    return MATCHES.filter(m => m.n == null || m.k == null);
  }, []);

  useFrame((_, delta) => {
    timeRef.current += delta;
    if (groupRef.current) {
      groupRef.current.rotation.y = timeRef.current * 0.1;
    }
  });

  // Build grid line objects (avoid <line> SVG type conflicts)
  const gridLines = useMemo(() => {
    const lines: THREE.Line[] = [];
    const mat1 = new THREE.LineBasicMaterial({ color: "#333333", opacity: 0.4, transparent: true });
    const mat2 = new THREE.LineBasicMaterial({ color: "#222222", opacity: 0.3, transparent: true });

    // Lines along π axis
    for (const k of ZETA_ARGS) {
      const kIdx = ZETA_ARGS.indexOf(k);
      const z = (kIdx - 2.5) * 3;
      const pts = PI_POWERS.map(n => {
        const x = (n - 5.5) * 2.5;
        const val = gridValue(n, k);
        const y = Math.log10(Math.max(val, 0.01)) * 2.5 - 5;
        return new THREE.Vector3(x, y, z);
      });
      lines.push(new THREE.Line(new THREE.BufferGeometry().setFromPoints(pts), mat1));
    }

    // Lines along ζ axis
    for (const n of PI_POWERS) {
      const x = (n - 5.5) * 2.5;
      const pts = ZETA_ARGS.map(k => {
        const val = gridValue(n, k);
        const y = Math.log10(Math.max(val, 0.01)) * 2.5 - 5;
        const z = (ZETA_ARGS.indexOf(k) - 2.5) * 3;
        return new THREE.Vector3(x, y, z);
      });
      lines.push(new THREE.Line(new THREE.BufferGeometry().setFromPoints(pts), mat2));
    }

    return lines;
  }, []);

  return (
    <group ref={groupRef}>
      {/* Grid wireframe */}
      {gridLines.map((ln, i) => (
        <primitive key={`gl-${i}`} object={ln} />
      ))}

      {/* Grid spheres */}
      {gridPoints.map((pt, i) => {
        const hasMatch = pt.matches.length > 0;
        const bestMatch = pt.matches[0];
        const scale = hasMatch ? TIER_SCALE[bestMatch.tier] || 0.3 : 0.08;
        const color = hasMatch ? (CATEGORY_COLORS[bestMatch.category] || "#ffffff") : "#444444";
        const pulse = hasMatch && bestMatch.tier === "Star" ? Math.sin(timeRef.current * 3) * 0.15 + 1 : 1;

        return (
          <group key={i} position={[pt.x, pt.y, pt.z]}>
            <mesh scale={scale * pulse}>
              <sphereGeometry args={[1, hasMatch ? 16 : 6, hasMatch ? 16 : 6]} />
              <meshBasicMaterial
                color={color}
                opacity={hasMatch ? 0.9 : 0.15}
                transparent
              />
            </mesh>
            {/* Glow halo for matches */}
            {hasMatch && (
              <mesh scale={scale * 2.5}>
                <sphereGeometry args={[1, 12, 12]} />
                <meshBasicMaterial color={color} opacity={0.08} transparent depthWrite={false} />
              </mesh>
            )}
            {/* Label for top-tier matches */}
            {hasMatch && (bestMatch.tier === "Star" || bestMatch.tier === "Lightning") && (
              <Html distanceFactor={40} style={{ pointerEvents: "none" }}>
                <div style={{
                  color,
                  fontSize: "10px",
                  fontFamily: "monospace",
                  whiteSpace: "nowrap",
                  textShadow: "0 0 8px rgba(0,0,0,0.9)",
                  background: "rgba(0,0,0,0.6)",
                  padding: "2px 6px",
                  borderRadius: "3px",
                  border: `1px solid ${color}33`,
                }}>
                  <div style={{ fontWeight: "bold" }}>{bestMatch.symbol}</div>
                  <div style={{ opacity: 0.7, fontSize: "8px" }}>
                    {bestMatch.formula} ≈ {pt.val.toFixed(1)}
                  </div>
                  <div style={{ opacity: 0.5, fontSize: "8px" }}>
                    err: {bestMatch.error.toFixed(4)}%
                  </div>
                </div>
              </Html>
            )}
          </group>
        );
      })}

      {/* Axis labels */}
      {PI_POWERS.map(n => (
        <Html key={`pi-${n}`} position={[(n - 5.5) * 2.5, -8, -10]} distanceFactor={50} style={{ pointerEvents: "none" }}>
          <span style={{ color: "#666", fontSize: "9px", fontFamily: "monospace" }}>π^{n}</span>
        </Html>
      ))}
      {ZETA_ARGS.map((k, i) => (
        <Html key={`z-${k}`} position={[-15, -8, (i - 2.5) * 3]} distanceFactor={50} style={{ pointerEvents: "none" }}>
          <span style={{ color: "#666", fontSize: "9px", fontFamily: "monospace" }}>ζ({k})</span>
        </Html>
      ))}

      {/* Off-grid matches floating nearby */}
      {offGridMatches.map((m, i) => {
        const angle = (i / offGridMatches.length) * Math.PI * 2;
        const r = 18;
        const x = Math.cos(angle) * r;
        const z = Math.sin(angle) * r;
        const y = Math.log10(Math.max(m.actual, 0.01)) * 2.5 - 5;
        const color = CATEGORY_COLORS[m.category] || "#aaaaaa";
        const scale = TIER_SCALE[m.tier] || 0.3;
        return (
          <group key={`off-${i}`} position={[x, y, z]}>
            <mesh scale={scale * 0.7}>
              <octahedronGeometry args={[1]} />
              <meshBasicMaterial color={color} opacity={0.7} transparent />
            </mesh>
            {(m.tier === "Star" || m.tier === "Lightning") && (
              <Html distanceFactor={45} style={{ pointerEvents: "none" }}>
                <div style={{
                  color, fontSize: "9px", fontFamily: "monospace",
                  whiteSpace: "nowrap", textShadow: "0 0 6px #000",
                  background: "rgba(0,0,0,0.5)", padding: "1px 4px",
                  borderRadius: "2px",
                }}>
                  {m.symbol}: {m.formula}
                </div>
              </Html>
            )}
          </group>
        );
      })}
    </group>
  );
}

// ═══════════════════════════════════════════════════════
// JET DETECTION
// ═══════════════════════════════════════════════════════

interface JetInfo {
  count: number;
  jets: { phi: number; theta: number; energy: number; particles: number }[];
  timestamp: number;
}

const JET_SAMPLE_COUNT = 5000;
const JET_ANGULAR_BINS = 12; // 12 phi × 6 theta = 72 cells
const JET_THETA_BINS = 6;
const JET_THRESHOLD = 3.0; // bin must have 3× average occupancy
const JET_MIN_SPEED = 0.3; // minimum avg radial speed for a jet

function detectJets(
  current: Float32Array,
  previous: Float32Array,
  count: number,
): JetInfo {
  const step = Math.max(1, Math.floor(count / JET_SAMPLE_COUNT));
  const bins: { count: number; speed: number }[][] = [];
  for (let p = 0; p < JET_ANGULAR_BINS; p++) {
    bins[p] = [];
    for (let t = 0; t < JET_THETA_BINS; t++) {
      bins[p][t] = { count: 0, speed: 0 };
    }
  }

  let sampled = 0;
  for (let i = 0; i < count; i += step) {
    const idx = i * 3;
    const dx = current[idx] - previous[idx];
    const dy = current[idx + 1] - previous[idx + 1];
    const dz = current[idx + 2] - previous[idx + 2];
    const spd = Math.sqrt(dx * dx + dy * dy + dz * dz);
    if (spd < 0.001) continue;

    const phi = Math.atan2(dy, dx); // -π to π
    const r = Math.sqrt(dx * dx + dy * dy + dz * dz);
    const theta = Math.acos(Math.max(-1, Math.min(1, dz / r))); // 0 to π

    const pi = Math.floor(((phi + Math.PI) / (2 * Math.PI)) * JET_ANGULAR_BINS) % JET_ANGULAR_BINS;
    const ti = Math.min(Math.floor((theta / Math.PI) * JET_THETA_BINS), JET_THETA_BINS - 1);

    bins[pi][ti].count++;
    bins[pi][ti].speed += spd;
    sampled++;
  }

  if (sampled === 0) return { count: 0, jets: [], timestamp: Date.now() };

  const avgPerBin = sampled / (JET_ANGULAR_BINS * JET_THETA_BINS);
  const jets: JetInfo["jets"] = [];

  for (let p = 0; p < JET_ANGULAR_BINS; p++) {
    for (let t = 0; t < JET_THETA_BINS; t++) {
      const b = bins[p][t];
      if (b.count > avgPerBin * JET_THRESHOLD) {
        const avgSpd = b.speed / b.count;
        if (avgSpd > JET_MIN_SPEED) {
          jets.push({
            phi: ((p + 0.5) / JET_ANGULAR_BINS) * 360 - 180,
            theta: ((t + 0.5) / JET_THETA_BINS) * 180,
            energy: b.speed,
            particles: b.count,
          });
        }
      }
    }
  }

  return { count: jets.length, jets, timestamp: Date.now() };
}

// ═══════════════════════════════════════════════════════
// SHAPE / MORPHOLOGY DETECTION (PCA + VOID + ANGULAR)
// ═══════════════════════════════════════════════════════

type ShapeType = "sphere" | "disc" | "line" | "ring" | "torus" | "cross" | "bipolar" | "unknown";

interface ShapeInfo {
  shape: ShapeType;
  eigenvalues: [number, number, number]; // sorted descending
  flatness: number;    // λ1/λ3 — how far from sphere
  elongation: number;  // λ1/λ2 — line-like
  ringScore: number;   // peak of radial distribution away from center
  voidScore: number;   // center hollowness (0=filled, 1=empty center)
  confidence: number;
}

interface MorphologyInterval {
  zeroIndex: number;      // 0 = before first zero
  tStart: number;
  tEnd: number;
  frames: number;
  shapes: Record<ShapeType, number>;
  jetEvents: number;
  maxJets: number;
  peakFlatness: number;
}

const SHAPE_SAMPLE = 5000;

// Analytical eigenvalues of 3x3 symmetric matrix using Cardano's method
function eigenvalues3x3(
  a: number, b: number, c: number,
  d: number, e: number, f: number,
): [number, number, number] {
  // Matrix: [[a,d,f],[d,b,e],[f,e,c]]
  const p1 = d * d + f * f + e * e;
  if (p1 < 1e-12) {
    // Already diagonal
    const vals = [a, b, c].sort((x, y) => y - x) as [number, number, number];
    return vals;
  }
  const q = (a + b + c) / 3;
  const p2 = (a - q) ** 2 + (b - q) ** 2 + (c - q) ** 2 + 2 * p1;
  const p = Math.sqrt(p2 / 6);
  // B = (1/p) * (A - qI)
  const ba = (a - q) / p, bb = (b - q) / p, bc = (c - q) / p;
  const bd = d / p, be = e / p, bf = f / p;
  const detB = ba * (bb * bc - be * be) - bd * (bd * bc - be * bf) + bf * (bd * be - bb * bf);
  let r = detB / 2;
  r = Math.max(-1, Math.min(1, r));
  const phi = Math.acos(r) / 3;
  const e1 = q + 2 * p * Math.cos(phi);
  const e3 = q + 2 * p * Math.cos(phi + 2 * Math.PI / 3);
  const e2 = 3 * q - e1 - e3;
  const vals = [e1, e2, e3].sort((x, y) => y - x) as [number, number, number];
  return vals;
}

function detectShape(positions: Float32Array, count: number): ShapeInfo {
  const step = Math.max(1, Math.floor(count / SHAPE_SAMPLE));
  let cx = 0, cy = 0, cz = 0, n = 0;

  // Pass 1: center of mass
  for (let i = 0; i < count; i += step) {
    const idx = i * 3;
    cx += positions[idx]; cy += positions[idx + 1]; cz += positions[idx + 2];
    n++;
  }
  if (n < 10) return { shape: "unknown", eigenvalues: [0, 0, 0], flatness: 1, elongation: 1, ringScore: 0, voidScore: 0, confidence: 0 };
  cx /= n; cy /= n; cz /= n;

  // Pass 2: covariance matrix + radial histogram + angular histogram
  let cxx = 0, cyy = 0, czz = 0, cxy = 0, cxz = 0, cyz = 0;
  const RADIAL_BINS = 20;
  const radialHist = new Float32Array(RADIAL_BINS);
  // Angular histogram for cross/bipolar detection (8 azimuthal sectors)
  const ANGULAR_BINS = 8;
  const angularHist = new Float32Array(ANGULAR_BINS);
  let maxR = 0;

  for (let i = 0; i < count; i += step) {
    const idx = i * 3;
    const dx = positions[idx] - cx, dy = positions[idx + 1] - cy, dz = positions[idx + 2] - cz;
    cxx += dx * dx; cyy += dy * dy; czz += dz * dz;
    cxy += dx * dy; cxz += dx * dz; cyz += dy * dz;
    const r = Math.sqrt(dx * dx + dy * dy + dz * dz);
    if (r > maxR) maxR = r;
  }
  cxx /= n; cyy /= n; czz /= n; cxy /= n; cxz /= n; cyz /= n;

  // Radial + angular distribution
  if (maxR > 0.01) {
    for (let i = 0; i < count; i += step) {
      const idx = i * 3;
      const dx = positions[idx] - cx, dy = positions[idx + 1] - cy, dz = positions[idx + 2] - cz;
      const r = Math.sqrt(dx * dx + dy * dy + dz * dz);
      const bin = Math.min(Math.floor((r / maxR) * RADIAL_BINS), RADIAL_BINS - 1);
      radialHist[bin]++;
      // Azimuthal angle for cross detection
      const phi = Math.atan2(dy, dx); // -π to π
      const ai = Math.floor(((phi + Math.PI) / (2 * Math.PI)) * ANGULAR_BINS) % ANGULAR_BINS;
      angularHist[ai]++;
    }
  }

  const eigs = eigenvalues3x3(cxx, cyy, czz, cxy, cyz, cxz);
  const [l1, l2, l3] = eigs;
  const safeL3 = Math.max(l3, 0.001);
  const safeL2 = Math.max(l2, 0.001);
  const flatness = l1 / safeL3;
  const elongation = l1 / safeL2;

  // ── Void score: how hollow is the center? ──
  // Compare inner 25% vs outer 75% density (volume-corrected)
  const innerBins = Math.max(1, Math.floor(RADIAL_BINS * 0.25));
  let innerCount = 0, outerCount = 0;
  for (let i = 0; i < RADIAL_BINS; i++) {
    if (i < innerBins) innerCount += radialHist[i];
    else outerCount += radialHist[i];
  }
  // Volume-correct: inner 25% of radius = 1.5% of volume in 3D
  // So if uniform, inner should have ~1.5% of particles
  // If inner has LESS than expected, it's hollow
  const innerFraction = innerCount / (innerCount + outerCount + 1);
  const expectedInnerFraction = 0.016; // (0.25)^3
  const voidScore = Math.max(0, 1 - innerFraction / Math.max(expectedInnerFraction, 0.001));
  // Clamp: if center has < 50% of expected, voidScore > 0.5
  const isHollow = voidScore > 0.3 && innerFraction < 0.05;

  // ── Ring score: peak of radial distribution away from center ──
  let peakBin = 0, peakVal = 0;
  for (let i = 1; i < RADIAL_BINS; i++) {
    if (radialHist[i] > peakVal) { peakVal = radialHist[i]; peakBin = i; }
  }
  const centerMass = radialHist[0] + (radialHist[1] || 0);
  const ringScore = peakVal > 0 ? (peakBin / RADIAL_BINS) * (peakVal / (centerMass + 1)) : 0;

  // ── Cross/bipolar score: angular bimodality ──
  // Cross = particles concentrated in 2-4 opposing angular sectors
  let angMax = 0, angMin = Infinity, angTotal = 0;
  for (let i = 0; i < ANGULAR_BINS; i++) {
    if (angularHist[i] > angMax) angMax = angularHist[i];
    if (angularHist[i] < angMin) angMin = angularHist[i];
    angTotal += angularHist[i];
  }
  const angAvg = angTotal / ANGULAR_BINS;
  const angContrast = angAvg > 0 ? (angMax - angMin) / angAvg : 0;
  // Count how many sectors are "hot" (above average)
  let hotSectors = 0;
  for (let i = 0; i < ANGULAR_BINS; i++) {
    if (angularHist[i] > angAvg * 1.3) hotSectors++;
  }

  // ══════════════════════════════════════
  // CLASSIFICATION — order matters!
  // Check structural signatures first, then fall through to PCA
  // ══════════════════════════════════════
  let shape: ShapeType = "sphere";
  let confidence = 0;

  // 1. TORUS: hollow center + roughly isotropic (ring viewed from any angle)
  if (isHollow && flatness < 3 && ringScore > 0.1) {
    shape = "torus";
    confidence = Math.min(voidScore * 1.5, 1);
  }
  // 2. RING: flat structure with hollow center OR strong radial peak
  else if ((isHollow && flatness > 2) || (ringScore > 0.3 && flatness > 2)) {
    shape = "ring";
    confidence = Math.min((voidScore + ringScore) * 0.8, 1);
  }
  // 3. CROSS: high angular contrast with 2-4 hot sectors, not too flat
  else if (angContrast > 1.5 && hotSectors >= 2 && hotSectors <= 4 && flatness < 3) {
    shape = "cross";
    confidence = Math.min(angContrast / 3, 1);
  }
  // 4. LINE: one eigenvalue dominates
  else if (elongation > 3.5) {
    shape = "line";
    confidence = Math.min(elongation / 8, 1);
  }
  // 5. DISC: two eigenvalues >> third, filled center
  else if (flatness > 3 && elongation < 2.5 && !isHollow) {
    shape = "disc";
    confidence = Math.min(flatness / 8, 1);
  }
  // 6. BIPOLAR: disc + some elongation (accretion disk + jets)
  else if (flatness > 2 && elongation > 1.5 && angContrast > 0.8) {
    shape = "bipolar";
    confidence = Math.min((flatness * elongation) / 12, 1);
  }
  // 7. Default: sphere
  else {
    shape = "sphere";
    confidence = 1 - Math.min(flatness / 3, 0.9);
  }

  return { shape, eigenvalues: eigs, flatness, elongation, ringScore, voidScore, confidence };
}

const SHAPE_LABELS: Record<ShapeType, { icon: string; color: string }> = {
  sphere:  { icon: "◉", color: "#888888" },
  disc:    { icon: "◎", color: "#44aaff" },
  line:    { icon: "│", color: "#ff8844" },
  ring:    { icon: "◯", color: "#44ffaa" },
  torus:   { icon: "⊙", color: "#00ffcc" },
  cross:   { icon: "✕", color: "#ffaa00" },
  bipolar: { icon: "⊥", color: "#ff44aa" },
  unknown: { icon: "?", color: "#444444" },
};

function emptyShapeCounts(): Record<ShapeType, number> {
  return { sphere: 0, disc: 0, line: 0, ring: 0, torus: 0, cross: 0, bipolar: 0, unknown: 0 };
}

// ═══════════════════════════════════════════════════════
// TIMEDOMAIN BRIDGE DATA
// ═══════════════════════════════════════════════════════

interface BridgeData {
  elongation: number;
  flatness: number;
  lambdas: [number, number, number];
  fluctuationEnergy: number;
  peakFluctuation: number;
  gramBound: number;
  collapseMean: number;
}

interface PCAHistoryPoint {
  t: number;
  elongation: number;
  collapse: number;
  fluctuation: number;
}

const PCA_HISTORY_MAX = 200;

// PCA Ratio Sparkline — SVG component showing elongation over time
function PCASparkline({
  history,
  detectedZeros,
  currentHeight,
}: {
  history: PCAHistoryPoint[];
  detectedZeros: DetectedZero[];
  currentHeight: number;
}) {
  if (history.length < 2) return null;

  const W = 280;
  const H = 50;
  const tMin = history[0].t;
  const tMax = history[history.length - 1].t;
  const tRange = Math.max(tMax - tMin, 0.1);

  // Elongation line (clamped to display range)
  const maxElong = Math.min(
    Math.max(...history.map((p) => p.elongation), 2),
    20
  );

  const elongPath = history
    .map((p, i) => {
      const x = ((p.t - tMin) / tRange) * W;
      const y = H - (Math.min(p.elongation, maxElong) / maxElong) * H;
      return `${i === 0 ? "M" : "L"}${x.toFixed(1)},${y.toFixed(1)}`;
    })
    .join(" ");

  // Collapse line (normalized)
  const maxCollapse = Math.max(...history.map((p) => p.collapse), 0.01);
  const collapsePath = history
    .map((p, i) => {
      const x = ((p.t - tMin) / tRange) * W;
      const y = H - (Math.min(p.collapse / maxCollapse, 1) * H);
      return `${i === 0 ? "M" : "L"}${x.toFixed(1)},${y.toFixed(1)}`;
    })
    .join(" ");

  return (
    <svg width={W} height={H + 12} style={{ display: "block" }}>
      {/* Background */}
      <rect x={0} y={0} width={W} height={H} fill="rgba(255,255,255,0.03)" rx={3} />

      {/* Zero markers */}
      {detectedZeros
        .filter((z) => z.height >= tMin && z.height <= tMax)
        .map((z, i) => {
          const x = ((z.height - tMin) / tRange) * W;
          return (
            <line
              key={`z-${i}`}
              x1={x}
              y1={0}
              x2={x}
              y2={H}
              stroke="#ff004444"
              strokeWidth={1.5}
              strokeDasharray="2,2"
            />
          );
        })}

      {/* Collapse metric line (dim cyan) */}
      <path d={collapsePath} fill="none" stroke="#00ffff33" strokeWidth={1} />

      {/* Elongation line (bright) */}
      <path d={elongPath} fill="none" stroke="#ff8844" strokeWidth={1.5} />

      {/* λ₁/λ₂ threshold line at 3.5 (line detection) */}
      <line
        x1={0}
        y1={H - (3.5 / maxElong) * H}
        x2={W}
        y2={H - (3.5 / maxElong) * H}
        stroke="#ff884422"
        strokeWidth={0.5}
        strokeDasharray="4,4"
      />

      {/* Labels */}
      <text x={2} y={H + 10} fill="#ff8844" fontSize={8} fontFamily="monospace">
        λ₁/λ₂
      </text>
      <text x={40} y={H + 10} fill="#00ffff55" fontSize={8} fontFamily="monospace">
        collapse
      </text>
      <text x={W - 45} y={H + 10} fill="#666" fontSize={7} fontFamily="monospace">
        t={currentHeight.toFixed(1)}
      </text>
    </svg>
  );
}

// ═══════════════════════════════════════════════════════
// PARTICLE CLOUD COMPONENT
// ═══════════════════════════════════════════════════════

// Pre-computed layer color objects (avoid allocation in hot loop)
const LAYER_COLOR_OBJS = LAYER_COLORS.map((c) => new THREE.Color(c));

function ExplorerCloud({
  wasmEngine,
  memoryArray,
  layerArray,
  particleCount,
  mode,
  speed,
  paused,
  stepRef,
  onMetrics,
  onJets,
  onShape,
  onBridge,
}: {
  wasmEngine: HyperEngine;
  memoryArray: Float32Array;
  layerArray: Float32Array;
  particleCount: number;
  mode: ViewMode;
  speed: number;
  paused: boolean;
  stepRef: React.MutableRefObject<boolean>;
  onMetrics: (c: number, h: number) => void;
  onJets: (j: JetInfo) => void;
  onShape: (s: ShapeInfo) => void;
  onBridge: (data: BridgeData) => void;
}) {
  const meshRef = useRef<THREE.InstancedMesh>(null);
  const materialRef = useRef<THREE.MeshBasicMaterial>(null);
  const frameCount = useRef(0);
  const colorsInitialized = useRef(false);
  const lastModeId = useRef(-1);

  const matrix = useMemo(() => new THREE.Matrix4(), []);
  const position = useMemo(() => new THREE.Vector3(), []);
  const color = useMemo(() => new THREE.Color(), []);
  const coreColor = useMemo(() => new THREE.Color(), []);
  const edgeColor = useMemo(() => new THREE.Color(), []);

  // Previous positions for velocity computation (jet detection)
  const prevPositions = useRef<Float32Array | null>(null);

  useFrame(() => {
    if (!meshRef.current) return;

    // Pause/step logic
    const doStep = stepRef.current;
    if (doStep) stepRef.current = false;

    if (!paused || doStep) {
      // Speed control: multiple ticks for fast, skip frames for slow
      if (speed >= 1) {
        const ticks = Math.round(speed);
        for (let s = 0; s < ticks; s++) {
          wasmEngine.tick_physics();
        }
      } else {
        const skipFrames = Math.round(1 / speed);
        if (frameCount.current % skipFrames === 0) {
          wasmEngine.tick_physics();
        }
      }
    }

    frameCount.current += 1;

    // Update metrics at ~10Hz
    if (frameCount.current % 6 === 0) {
      const c = wasmEngine.get_collapse_metric();
      const lambda = wasmEngine.get_lambda();
      const t = 10.0 + lambda * 2.0;
      onMetrics(c, t);

      // Jet detection on ALL modes (~10Hz, cheap)
      if (prevPositions.current) {
        const jetInfo = detectJets(memoryArray, prevPositions.current, particleCount);
        if (jetInfo.count > 0) onJets(jetInfo);
      }
      // Shape detection on ALL modes (~10Hz, runs on positions directly)
      const shapeInfo = detectShape(memoryArray, particleCount);
      onShape(shapeInfo);

      // TimeDomainBridge: read Rust-computed PCA + fluctuation data
      onBridge({
        elongation: wasmEngine.get_elongation(),
        flatness: wasmEngine.get_flatness(),
        lambdas: [
          wasmEngine.get_pca_lambda1(),
          wasmEngine.get_pca_lambda2(),
          wasmEngine.get_pca_lambda3(),
        ],
        fluctuationEnergy: wasmEngine.get_fluctuation_energy(),
        peakFluctuation: wasmEngine.get_peak_fluctuation(),
        gramBound: wasmEngine.get_gram_bound(),
        collapseMean: wasmEngine.get_collapse_mean(),
      });

      // Snapshot positions for next velocity computation
      if (!prevPositions.current || prevPositions.current.length !== particleCount * 3) {
        prevPositions.current = new Float32Array(particleCount * 3);
      }
      prevPositions.current.set(memoryArray);
    }

    // Initialize instance colors on first frame or mode change
    const needsColorInit = !colorsInitialized.current || lastModeId.current !== mode.id;
    if (needsColorInit) {
      // Pre-initialize all instance colors so the buffer exists
      color.set(mode.coreColor);
      for (let i = 0; i < particleCount; i++) {
        meshRef.current.setColorAt(i, color);
      }
      if (meshRef.current.instanceColor) {
        meshRef.current.instanceColor.needsUpdate = true;
      }
      colorsInitialized.current = true;
      lastModeId.current = mode.id;
    }

    // Update material color to match mode
    if (materialRef.current) {
      materialRef.current.color.set("#ffffff");
    }

    // Update positions every frame (this is the core rendering)
    for (let i = 0; i < particleCount; i++) {
      const idx = i * 3;
      position.set(
        memoryArray[idx],
        memoryArray[idx + 1],
        memoryArray[idx + 2]
      );
      matrix.setPosition(position);
      meshRef.current.setMatrixAt(i, matrix);
    }
    meshRef.current.instanceMatrix.needsUpdate = true;

    // Update colors at ~10Hz (every 6 frames) — too expensive for 60fps
    if (frameCount.current % 6 === 0 && meshRef.current.instanceColor) {
      coreColor.set(mode.coreColor);
      edgeColor.set(mode.edgeColor);

      for (let i = 0; i < particleCount; i++) {
        const idx = i * 3;

        if (mode.id === 2) {
          // Glass Staircase: color by dominant CD layer (6 layers now)
          const layerIdx = Math.min(Math.max(Math.round(layerArray[idx]), 0), 5);
          color.copy(LAYER_COLOR_OBJS[layerIdx]);
        } else if (mode.id === 3) {
          // Division by Zero: color by Möbius sign
          const sign = layerArray[idx];
          const magnitude = layerArray[idx + 1];
          const brightness = Math.min(Math.max(magnitude * 0.3, 0.15), 1.0);
          if (sign > 0) {
            color.setRGB(brightness * 0.3, brightness * 0.6, brightness); // blue = μ=+1
          } else {
            color.setRGB(brightness, brightness * 0.15, brightness * 0.25); // red = μ=-1
          }
        } else if (mode.id === 5) {
          // Prime Democracy: color by dominant prime direction
          // Map prime index (0-30) to a hue cycle
          const primeIdx = Math.round(layerArray[idx]) % 31;
          const hue = primeIdx / 31.0;
          const energy = Math.min(layerArray[idx + 1], 1.0);
          const realPart = layerArray[idx + 2]; // cos(t·ln2)
          const sat = 0.7 + energy * 0.3;
          const light = 0.4 + Math.abs(realPart) * 0.4;
          color.setHSL(hue, sat, light);
        } else {
          // Origin / Teardrop / Spectrometer: gradient from core to edge
          const x = memoryArray[idx], y = memoryArray[idx + 1], z = memoryArray[idx + 2];
          const dist = Math.sqrt(x * x + y * y + z * z);
          const t = Math.min(dist / 30, 1);
          color.lerpColors(coreColor, edgeColor, t);
        }

        meshRef.current!.setColorAt(i, color);
      }
      meshRef.current.instanceColor.needsUpdate = true;
    }
  });

  return (
    <instancedMesh ref={meshRef} args={[undefined, undefined, particleCount]}>
      <sphereGeometry args={[0.08, 4, 4]} />
      <meshBasicMaterial
        ref={materialRef}
        color="#00ff88"
        opacity={0.6}
        transparent
        depthWrite={false}
      />
    </instancedMesh>
  );
}

// ═══════════════════════════════════════════════════════
// MAIN PAGE
// ═══════════════════════════════════════════════════════

interface DetectedZero {
  index: number;
  height: number;
  minCollapse: number;
}

export default function Home() {
  const [engineStatus, setEngineStatus] = useState("Compiling...");
  const [wasmModule, setWasmModule] = useState<{ memory: WebAssembly.Memory } | null>(null);
  const [hyperSystem, setHyperSystem] = useState<{
    engine: HyperEngine;
    memory: Float32Array;
    layers: Float32Array;
  } | null>(null);
  const [collapse, setCollapse] = useState(0);
  const [height, setHeight] = useState(10.0);
  const [modeIdx, setModeIdx] = useState(0);
  const [particleCount, setParticleCount] = useState(DEFAULT_PARTICLE_COUNT);
  const [speed, setSpeed] = useState(1);
  const [detectedZeros, setDetectedZeros] = useState<DetectedZero[]>([]);
  const [layerEnergies, setLayerEnergies] = useState([0, 0, 0, 0, 0, 0, 0, 0]);
  const [towerLevel, setTowerLevel] = useState(5); // 0=ℝ .. 7=∞
  const [paused, setPaused] = useState(false);
  const stepRef = useRef(false);
  const [jetInfo, setJetInfo] = useState<JetInfo | null>(null);
  const [jetLog, setJetLog] = useState<{ t: number; jets: number; height: number }[]>([]);
  // L1 Trigger system
  const [triggerArmed, setTriggerArmed] = useState(true);
  const [triggerThreshold, setTriggerThreshold] = useState(3);
  const [triggerEvents, setTriggerEvents] = useState<{ height: number; jets: number; time: number }[]>([]);
  const [triggerFlash, setTriggerFlash] = useState(false);
  const triggerCooldownRef = useRef(0);
  // Shape / Morphology detection
  const [shapeInfo, setShapeInfo] = useState<ShapeInfo | null>(null);
  const [bridgeData, setBridgeData] = useState<BridgeData | null>(null);
  const [pcaHistory, setPcaHistory] = useState<PCAHistoryPoint[]>([]);
  const [morphologyLog, setMorphologyLog] = useState<MorphologyInterval[]>([]);
  const currentIntervalRef = useRef<MorphologyInterval>({
    zeroIndex: 0, tStart: 10, tEnd: 10, frames: 0,
    shapes: emptyShapeCounts(), jetEvents: 0, maxJets: 0, peakFlatness: 0,
  });
  const inZeroRef = useRef(false);
  const minCollapseRef = useRef(Infinity);
  const minHeightRef = useRef(0);

  const mode = VIEW_MODES[modeIdx];

  // Init WASM module once
  useEffect(() => {
    init().then((mod) => {
      setWasmModule(mod);
    }).catch((e) => {
      console.error(e);
      setEngineStatus("CRITICAL WASM CORE FAILURE");
    });
  }, []);

  // Create/recreate engine when module is ready or N changes
  useEffect(() => {
    if (!wasmModule) return;
    setEngineStatus("Allocating 16D Geometry RAM...");

    // Clean up old engine
    if (hyperSystem) {
      try { hyperSystem.engine.free(); } catch { /* already freed */ }
    }

    const engine = new HyperEngine(particleCount);
    const ptr = engine.get_buffer_pointer();
    const memoryArray = new Float32Array(
      wasmModule.memory.buffer,
      ptr,
      particleCount * 3
    );

    const layerPtr = engine.get_layer_buffer_pointer();
    const layerArray = new Float32Array(
      wasmModule.memory.buffer,
      layerPtr,
      particleCount * 3
    );

    // Sync mode
    engine.set_view_mode(modeIdx);

    setHyperSystem({ engine, memory: memoryArray, layers: layerArray });
    setEngineStatus("WASM Core Locked — True Zero-Copy");

    // Reset zero detection on engine reset
    setDetectedZeros([]);
    setHeight(10.0);
    setCollapse(0);
    inZeroRef.current = false;
    minCollapseRef.current = Infinity;

    return () => {
      try { engine.free(); } catch { /* cleanup */ }
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [wasmModule, particleCount]);

  // Sync view mode to engine
  useEffect(() => {
    if (hyperSystem) {
      hyperSystem.engine.set_view_mode(modeIdx);
    }
  }, [modeIdx, hyperSystem]);

  // Sync tower level to engine
  useEffect(() => {
    if (hyperSystem) {
      hyperSystem.engine.set_tower_level(towerLevel);
    }
  }, [towerLevel, hyperSystem]);

  // Keyboard shortcuts
  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      // Ignore if typing in an input
      if ((e.target as HTMLElement).tagName === "INPUT") return;

      const num = parseInt(e.key);
      if (num >= 1 && num <= 6) {
        setModeIdx(num - 1);
        return;
      }

      // Pause/step controls
      if (e.key === " ") {
        e.preventDefault();
        setPaused((p) => !p);
        return;
      }
      if (e.key === "ArrowRight") {
        e.preventDefault();
        setPaused(true);
        stepRef.current = true;
        return;
      }

      // Speed controls: [ and ] to decrease/increase
      if (e.key === "[" || e.key === "-") {
        setSpeed((s) => {
          const idx = SPEED_PRESETS.findIndex((p) => p.value === s);
          return idx > 0 ? SPEED_PRESETS[idx - 1].value : s;
        });
      } else if (e.key === "]" || e.key === "=") {
        setSpeed((s) => {
          const idx = SPEED_PRESETS.findIndex((p) => p.value === s);
          return idx < SPEED_PRESETS.length - 1 ? SPEED_PRESETS[idx + 1].value : s;
        });
      }
    };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, []);

  // Zero detection + layer energies
  useEffect(() => {
    if (!hyperSystem) return;
    const interval = setInterval(() => {
      try {
      const c = hyperSystem.engine.get_collapse_metric();
      const lambda = hyperSystem.engine.get_lambda();
      const t = 10.0 + lambda * 2.0;

      // Update layer energies for Glass Staircase and Prime Democracy
      if (modeIdx === 2 || modeIdx === 5) {
        const energies = [0, 1, 2, 3, 4, 5, 6, 7].map((i) =>
          i < 6 ? hyperSystem.engine.get_layer_energy(i) : 0
        );
        setLayerEnergies(energies);
      }

      // Zero detection with hysteresis
      const ZERO_THRESHOLD = 0.15;
      const EXIT_THRESHOLD = 0.3;

      if (!inZeroRef.current && c < ZERO_THRESHOLD) {
        inZeroRef.current = true;
        minCollapseRef.current = c;
        minHeightRef.current = t;
      } else if (inZeroRef.current && c < minCollapseRef.current) {
        minCollapseRef.current = c;
        minHeightRef.current = t;
      } else if (inZeroRef.current && c > EXIT_THRESHOLD) {
        inZeroRef.current = false;
        setDetectedZeros((prev) => [
          ...prev,
          {
            index: prev.length + 1,
            height: minHeightRef.current,
            minCollapse: minCollapseRef.current,
          },
        ]);
        minCollapseRef.current = Infinity;

        // Finalize morphology interval and start new one
        const finalized = { ...currentIntervalRef.current, tEnd: t };
        setMorphologyLog((prev) => [...prev, finalized]);
        currentIntervalRef.current = {
          zeroIndex: finalized.zeroIndex + 1,
          tStart: t, tEnd: t, frames: 0,
          shapes: emptyShapeCounts(), jetEvents: 0, maxJets: 0, peakFlatness: 0,
        };
      }
      } catch (_) { /* engine freed during hot reload */ }
    }, 50);
    return () => clearInterval(interval);
  }, [hyperSystem, modeIdx]);

  const handleMetrics = useCallback((c: number, h: number) => {
    setCollapse(c);
    setHeight(h);
  }, []);

  const handleJets = useCallback((j: JetInfo) => {
    setJetInfo(j);
    setJetLog((prev) => [
      ...prev.slice(-19),
      { t: Date.now(), jets: j.count, height },
    ]);

    // L1 Trigger: auto-pause when jet count meets threshold
    const now = Date.now();
    if (triggerArmed && j.count >= triggerThreshold && now - triggerCooldownRef.current > 2000) {
      triggerCooldownRef.current = now;
      setPaused(true);
      setTriggerFlash(true);
      setTriggerEvents((prev) => [
        ...prev.slice(-49),
        { height, jets: j.count, time: now },
      ]);
      setTimeout(() => setTriggerFlash(false), 1500);
    }
  }, [height, triggerArmed, triggerThreshold]);

  const handleShape = useCallback((s: ShapeInfo) => {
    setShapeInfo(s);
    // Accumulate into current interval
    const interval = currentIntervalRef.current;
    interval.frames++;
    interval.tEnd = height;
    interval.shapes[s.shape]++;
    if (s.flatness > interval.peakFlatness) interval.peakFlatness = s.flatness;
  }, [height]);

  const handleBridge = useCallback((data: BridgeData) => {
    setBridgeData(data);
    // Track PCA history for sparkline
    setPcaHistory((prev) => {
      const next = [
        ...prev.slice(-(PCA_HISTORY_MAX - 1)),
        {
          t: height,
          elongation: data.elongation,
          collapse: data.collapseMean,
          fluctuation: data.fluctuationEnergy,
        },
      ];
      return next;
    });
  }, [height]);

  // Also track jet events in morphology interval
  const handleJetsWithMorphology = useCallback((j: JetInfo) => {
    handleJets(j);
    const interval = currentIntervalRef.current;
    interval.jetEvents++;
    if (j.count > interval.maxJets) interval.maxJets = j.count;
  }, [handleJets]);

  // Download morphology log as JSON
  const downloadMorphologyLog = useCallback(() => {
    const finalLog = [
      ...morphologyLog,
      { ...currentIntervalRef.current, tEnd: height },
    ];
    const blob = new Blob([JSON.stringify(finalLog, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `morphology_log_t${height.toFixed(1)}.json`;
    a.click();
    URL.revokeObjectURL(url);
  }, [morphologyLog, height]);

  const nextZero = KNOWN_ZEROS.find((z) => z > height);
  const speedLabel = SPEED_PRESETS.find((p) => p.value === speed)?.label || `${speed}×`;

  return (
    <main className="w-screen h-screen flex flex-col items-center justify-center bg-[#050505] text-[#00ff88] font-mono overflow-hidden">
      {/* TRIGGER FLASH overlay */}
      {triggerFlash && (
        <div className="absolute inset-0 z-50 pointer-events-none animate-pulse" style={{
          background: "radial-gradient(circle, rgba(255,0,68,0.15) 0%, transparent 70%)",
          border: "2px solid #ff0044",
        }}>
          <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 text-center">
            <p className="text-3xl font-black text-red-500 tracking-[0.3em] animate-pulse">☢ L1 TRIGGERED ☢</p>
            <p className="text-sm text-red-400 mt-2 opacity-80">t = {height.toFixed(3)} · {jetInfo?.count || 0} jets detected</p>
          </div>
        </div>
      )}

      {/* Left HUD */}
      <div className="absolute top-8 left-8 z-10 pointer-events-none flex flex-col gap-1 drop-shadow-xl max-w-lg">
        <h1 className="text-4xl font-black tracking-widest" style={{ color: mode.coreColor }}>
          HYPERZETA EXPLORER
        </h1>
        <p
          className={`opacity-90 font-bold border-b pb-2 mb-2 w-max ${
            engineStatus.includes("Locked")
              ? "border-[#00ff88]"
              : "border-red-500 text-yellow-300"
          }`}
        >
          Status: {engineStatus}
        </p>

        {/* Mode indicator */}
        <div className="flex gap-2 mt-2 pointer-events-auto">
          {VIEW_MODES.map((m) => (
            <button
              key={m.id}
              onClick={() => setModeIdx(m.id)}
              className={`px-3 py-1 text-xs font-bold border transition-all duration-200 ${
                m.id === modeIdx
                  ? "border-white bg-white/10 scale-105"
                  : "border-white/20 hover:border-white/50 opacity-60"
              }`}
              style={{ color: m.coreColor, borderColor: m.id === modeIdx ? m.coreColor : undefined }}
            >
              [{m.hotkey}] {m.name}
            </button>
          ))}
        </div>

        <p className="text-sm opacity-75 mt-3" style={{ color: mode.coreColor }}>
          {mode.subtitle}
        </p>
        <p className="text-sm opacity-50 font-mono">{mode.formula}</p>
        <p className="text-xs opacity-40 mt-2 italic">
          {paused && <span className="text-yellow-400"> ⏸ PAUSED </span>}
          {modeIdx === 4
            ? `${MATCHES.length} formula matches · Spectral Lift Grid`
            : `${particleCount.toLocaleString()} sedenion lattice points · Rust/WASM · ${speedLabel}`}
        </p>
        <p className="text-lg mt-4 font-bold">
          Collapse:{" "}
          <span
            className={
              collapse < 0.15
                ? "animate-pulse"
                : ""
            }
            style={{ color: collapse < 0.15 ? "#ff0044" : collapse < 0.5 ? "#ff4444" : mode.coreColor }}
          >
            {collapse.toFixed(4)}
          </span>
        </p>

        {/* ═══════════════════════════════════════════ */}
        {/* TimeDomainBridge Panel — All Modes         */}
        {/* ═══════════════════════════════════════════ */}
        <div className="mt-4 border border-white/10 bg-black/40 backdrop-blur-sm rounded px-3 py-2">
          <p className="text-[10px] opacity-50 tracking-wider border-b border-white/10 pb-1 mb-2">
            TIMEDOMAIN BRIDGE — PCA GEOMETRIC DETECTION
          </p>

          {/* PCA Sparkline */}
          <PCASparkline
            history={pcaHistory}
            detectedZeros={detectedZeros}
            currentHeight={height}
          />

          {/* Shape + Eigenvalues */}
          <div className="flex items-center gap-3 mt-2">
            {shapeInfo && (
              <>
                <span
                  className="text-lg"
                  style={{ color: SHAPE_LABELS[shapeInfo.shape].color }}
                >
                  {SHAPE_LABELS[shapeInfo.shape].icon}
                </span>
                <span
                  className="text-xs font-bold"
                  style={{ color: SHAPE_LABELS[shapeInfo.shape].color }}
                >
                  {shapeInfo.shape.toUpperCase()}
                </span>
                <span className="text-[10px] opacity-30">
                  ({(shapeInfo.confidence * 100).toFixed(0)}%)
                </span>
              </>
            )}
          </div>

          {/* PCA Eigenvalues from Rust (f64 precision) */}
          {bridgeData && (
            <div className="mt-1.5 text-[10px] opacity-50 space-y-0.5">
              <div className="flex gap-4">
                <span>
                  λ₁/λ₂:{" "}
                  <span style={{ color: bridgeData.elongation > 3.5 ? "#ff8844" : "#888" }}>
                    {bridgeData.elongation.toFixed(2)}
                  </span>
                </span>
                <span>
                  λ₁/λ₃:{" "}
                  <span style={{ color: bridgeData.flatness > 5 ? "#44aaff" : "#888" }}>
                    {bridgeData.flatness.toFixed(2)}
                  </span>
                </span>
              </div>
              <p className="opacity-60">
                λ: [{bridgeData.lambdas.map((v) => v.toFixed(1)).join(", ")}]
              </p>
            </div>
          )}

          {/* TimeDomainBridge Quantities */}
          {bridgeData && (
            <div className="mt-2 border-t border-white/10 pt-2 text-[10px]">
              <div className="flex gap-3 items-center">
                <span className="opacity-50">E_S(t):</span>
                <span
                  className="font-bold tabular-nums"
                  style={{
                    color:
                      Math.abs(bridgeData.fluctuationEnergy) < 0.01
                        ? "#00ff88"
                        : "#ff8844",
                  }}
                >
                  {bridgeData.fluctuationEnergy.toFixed(4)}
                </span>
              </div>
              <div className="flex gap-3 items-center mt-0.5">
                <span className="opacity-50">‖E_S‖∞:</span>
                <span className="tabular-nums opacity-70">
                  {bridgeData.peakFluctuation.toFixed(4)}
                </span>
              </div>
              <div className="flex gap-3 items-center mt-0.5">
                <span className="opacity-50">Gram bound:</span>
                <span
                  className="tabular-nums font-bold"
                  style={{
                    color:
                      bridgeData.gramBound < 0.001
                        ? "#00ff88"
                        : bridgeData.gramBound < 0.01
                        ? "#ffaa00"
                        : "#ff4444",
                  }}
                >
                  {bridgeData.gramBound < 0.0001
                    ? bridgeData.gramBound.toExponential(2)
                    : bridgeData.gramBound.toFixed(6)}
                </span>
              </div>
              <p className="opacity-30 mt-1 italic text-[9px]">
                |vᵀGv − asymptotic| ≤ ‖E_S‖∞/T²
              </p>
            </div>
          )}
        </div>

        {/* Glass Staircase: Layer energy bars */}
        {modeIdx === 2 && (
          <div className="mt-4 flex flex-col gap-1">
            <p className="text-xs opacity-50 border-b border-white/10 pb-1 mb-1">
              CAYLEY-DICKSON ENERGY DISTRIBUTION
            </p>
            {LAYER_NAMES.map((name, idx) => {
              const maxE = Math.max(...layerEnergies, 0.001);
              const pct = (layerEnergies[idx] / maxE) * 100;
              return (
                <div key={idx} className="flex items-center gap-2 text-xs">
                  <span className="w-4 font-bold" style={{ color: LAYER_COLORS[idx] }}>
                    {name}
                  </span>
                  <div className="flex-1 h-2 bg-white/5 rounded overflow-hidden">
                    <div
                      className="h-full rounded transition-all duration-300"
                      style={{
                        width: `${pct}%`,
                        backgroundColor: LAYER_COLORS[idx],
                        opacity: 0.8,
                      }}
                    />
                  </div>
                  <span className="opacity-40 w-12 text-right tabular-nums">
                    {layerEnergies[idx].toFixed(2)}
                  </span>
                </div>
              );
            })}
          </div>
        )}

         {/* Prime Democracy: Prime harmonic radar + stats */}
        {modeIdx === 5 && hyperSystem && (
          <div className="mt-4 flex flex-col gap-1">
            <p className="text-xs opacity-50 border-b border-white/10 pb-1 mb-1">
              PRIME DEMOCRACY — {LAYER_NAMES[towerLevel]} LEVEL
            </p>
            {/* Tower Level Slider */}
            <div className="flex flex-col gap-1 mb-2 pointer-events-auto">
              <div className="flex items-center gap-1">
                {LAYER_NAMES.map((name, idx) => {
                  const dims = [1, 2, 4, 8, 16, 32, 64, 128][idx];
                  const primes = [0, 1, 3, 7, 15, 31, 63, 127][idx];
                  const isActive = idx <= towerLevel;
                  return (
                    <button
                      key={idx}
                      onClick={() => setTowerLevel(idx)}
                      className="flex-1 py-1 text-center transition-all duration-300 rounded"
                      style={{
                        backgroundColor: idx === towerLevel
                          ? LAYER_COLORS[idx] + '33'
                          : isActive ? 'rgba(255,255,255,0.05)' : 'transparent',
                        border: idx === towerLevel
                          ? `1px solid ${LAYER_COLORS[idx]}`
                          : '1px solid rgba(255,255,255,0.1)',
                        color: isActive ? LAYER_COLORS[idx] : '#333',
                        fontSize: '10px',
                        fontWeight: idx === towerLevel ? 'bold' : 'normal',
                      }}
                      title={`${name} — dim ${dims}, ${primes} primes`}
                    >
                      <div>{name}</div>
                      <div style={{ fontSize: '7px', opacity: 0.5 }}>{dims}D</div>
                    </button>
                  );
                })}
              </div>
              <p className="text-[10px] opacity-30 text-center">
                {[0, 1, 3, 7, 15, 31, 63, 127][towerLevel]} prime{[0, 1, 3, 7, 15, 31, 63, 127][towerLevel] !== 1 ? 's' : ''} active · dim {[1, 2, 4, 8, 16, 32, 64, 128][towerLevel]} · {['real axis only', 'S¹ circle', 'S³ sphere', 'S⁷ exotic', 'S¹⁵ sedenion', 'S³¹ democracy', 'S⁶³ full democracy', 'S¹²⁷ glass clears'][towerLevel]}
              </p>
            </div>
            {/* SVG Radar chart of prime energies */}
            <div className="flex justify-center">
              <svg width={220} height={220} viewBox="-110 -110 220 220">
                {/* Background circles */}
                {[30, 60, 90].map(r => (
                  <circle key={r} cx={0} cy={0} r={r} fill="none" stroke="rgba(255,255,255,0.06)" strokeWidth={0.5} />
                ))}
                {/* Prime spokes + energy polygon */}
                {(() => {
                  const PRIMES = [2,3,5,7,11,13,17,19,23,29,31,37,41,43,47,53,59,61,67,71,73,79,83,89,97,101,103,107,109,113,127,131,137,139,149,151,157,163,167,173,179,181,191,193,197,199,211,223,227,229,233,239,241,251,257,263,269,271,277,281,283,293,307,311,313,317,331,337,347,349,353,359,367,373,379,383,389,397,401,409,419,421,431,433,439,443,449,457,461,463,467,479,487,491,499,503,509,521,523,541,547,557,563,569,571,577,587,593,599,601,607,613,617,619,631,641,643,647,653,659,661,673,677,683,691,701,709];
                  const activePrimes = [0, 1, 3, 7, 15, 31, 63, 127][towerLevel];
                  const n = 127;
                  const points: string[] = [];
                  const spokes: React.JSX.Element[] = [];
                  for (let k = 0; k < n; k++) {
                    const angle = (k / n) * Math.PI * 2 - Math.PI / 2;
                    const isActive = k < activePrimes;
                    const energy = isActive ? hyperSystem.engine.get_prime_energy(k) : 0;
                    const r = Math.min(energy * activePrimes * 90 / Math.max(activePrimes, 1), 95);
                    const x = Math.cos(angle) * (isActive ? r : 0);
                    const y = Math.sin(angle) * (isActive ? r : 0);
                    points.push(`${x.toFixed(1)},${y.toFixed(1)}`);
                    // Spoke line
                    const sx = Math.cos(angle) * 95;
                    const sy = Math.sin(angle) * 95;
                    const hue = (k / n) * 360;
                    const spokeOpacity = isActive ? 0.2 : 0.04;
                    const labelOpacity = isActive ? (n > 64 ? 0.4 : 0.8) : 0.15;
                    const showLabel = n <= 63 || k % 8 === 0 || k === n - 1;
                    spokes.push(
                      <g key={k}>
                        <line x1={0} y1={0} x2={sx} y2={sy} stroke={`hsla(${hue},60%,50%,${spokeOpacity})`} strokeWidth={isActive ? (n > 64 ? 0.4 : 0.8) : 0.3} />
                        {showLabel && (
                          <text x={sx * 1.12} y={sy * 1.12} fill={`hsla(${hue},70%,65%,${labelOpacity})`}
                            fontSize={k < 10 ? 5 : k < 31 ? 4 : k < 63 ? 3.5 : 3} textAnchor="middle" dominantBaseline="central"
                            fontWeight={isActive ? 'bold' : 'normal'}>
                            {PRIMES[k]}
                          </text>
                        )}
                        {/* Glow dot on active spokes */}
                        {isActive && r > 5 && (
                          <circle cx={x} cy={y} r={n > 64 ? 1.2 : 2} fill={`hsla(${hue},80%,60%,0.7)`} />
                        )}
                      </g>
                    );
                  }
                  const towerColor = LAYER_COLORS[towerLevel];
                  return (
                    <>
                      {spokes}
                      <polygon
                        points={points.join(' ')}
                        fill={towerColor + '1a'}
                        stroke={towerColor}
                        strokeWidth={1.5}
                        strokeLinejoin="round"
                        className="transition-all duration-500"
                      />
                      {/* Uniform reference circle */}
                      <circle cx={0} cy={0} r={90} fill="none" stroke={towerColor + '33'} strokeWidth={0.5} strokeDasharray="3,3" />
                      {/* Center label */}
                      <text x={0} y={0} fill={towerColor} fontSize={14} textAnchor="middle" dominantBaseline="central" fontWeight="bold" opacity={0.4}>
                        {LAYER_NAMES[towerLevel]}
                      </text>
                    </>
                  );
                })()}
              </svg>
            </div>
            {/* Uniformity score */}
            <div className="flex items-center gap-2 text-xs mt-1">
              <span className="opacity-50">UNIFORMITY:</span>
              <div className="flex-1 h-2 bg-white/5 rounded overflow-hidden">
                <div
                  className="h-full rounded transition-all duration-500"
                  style={{
                    width: `${hyperSystem.engine.get_prime_uniformity() * 100}%`,
                    backgroundColor: '#00ffdd',
                    opacity: 0.8,
                  }}
                />
              </div>
              <span style={{ color: '#00ffdd' }} className="tabular-nums w-12 text-right">
                {(hyperSystem.engine.get_prime_uniformity() * 100).toFixed(1)}%
              </span>
            </div>
            <p className="text-[10px] opacity-30 mt-1">
              Each spoke = one of 31 primes ≤ 127. Dashed circle = perfect uniformity (1/31 each).
              The polygon shows actual energy distribution across S³¹.
            </p>
            {/* Layer energy bars (shared with Glass Staircase) */}
            <p className="text-xs opacity-50 border-b border-white/10 pb-1 mb-1 mt-2">
              CAYLEY-DICKSON TOWER ENERGY
            </p>
            {LAYER_NAMES.map((name, idx) => {
              const maxE = Math.max(...layerEnergies, 0.001);
              const pct = (layerEnergies[idx] / maxE) * 100;
              return (
                <div key={idx} className="flex items-center gap-2 text-xs">
                  <span className="w-4 font-bold" style={{ color: LAYER_COLORS[idx] }}>
                    {name}
                  </span>
                  <div className="flex-1 h-2 bg-white/5 rounded overflow-hidden">
                    <div
                      className="h-full rounded transition-all duration-300"
                      style={{
                        width: `${pct}%`,
                        backgroundColor: LAYER_COLORS[idx],
                        opacity: 0.8,
                      }}
                    />
                  </div>
                  <span className="opacity-40 w-12 text-right tabular-nums">
                    {layerEnergies[idx].toFixed(2)}
                  </span>
                </div>
              );
            })}
          </div>
        )}

        {/* Division by Zero: Möbius legend + jet detector */}
        {modeIdx === 3 && (
          <div className="mt-4 text-xs opacity-60">
            <p className="border-b border-white/10 pb-1 mb-2">MÖBIUS FIELD</p>
            <div className="flex gap-4">
              <span>
                <span className="text-blue-400">●</span> μ(n) = +1 (even prime factors)
              </span>
              <span>
                <span className="text-red-400">●</span> μ(n) = -1 (odd prime factors)
              </span>
            </div>
            <p className="mt-1 opacity-50">μ(n) = 0 particles excluded (non-squarefree)</p>

            {/* Jet detector readout */}
            <div className="mt-3 border-t border-white/10 pt-2">
              <p className="font-bold opacity-80" style={{ color: jetInfo && jetInfo.count > 0 ? "#ff4444" : "#666" }}>
                JET DETECTOR: {jetInfo && jetInfo.count > 0 ? `${jetInfo.count} JET${jetInfo.count > 1 ? "S" : ""} ✦` : "scanning..."}
              </p>
              {jetInfo && jetInfo.jets.length > 0 && (
                <div className="mt-1 space-y-0.5">
                  {jetInfo.jets.slice(0, 4).map((j, i) => (
                    <p key={i} className="opacity-50">
                      jet {i+1}: φ={j.phi.toFixed(0)}° θ={j.theta.toFixed(0)}° E={j.energy.toFixed(2)} n={j.particles}
                    </p>
                  ))}
                </div>
              )}
              {/* Trigger status */}
              <div className="mt-2 border-t border-white/10 pt-2 pointer-events-auto">
                <div className="flex items-center gap-2">
                  <span className={`inline-block w-2 h-2 rounded-full ${triggerArmed ? 'bg-red-500 animate-pulse' : 'bg-gray-600'}`} />
                  <span className="font-bold" style={{ color: triggerArmed ? '#ff4444' : '#666' }}>
                    L1 TRIGGER: {triggerArmed ? 'ARMED' : 'DISARMED'}
                  </span>
                </div>
                <p className="opacity-40 mt-1">threshold: ≥{triggerThreshold} jets → auto-pause</p>
                {triggerEvents.length > 0 && (
                  <div className="mt-1">
                    <p className="opacity-30">{triggerEvents.length} trigger event{triggerEvents.length > 1 ? 's' : ''}</p>
                    {triggerEvents.slice(-3).map((ev, i) => (
                      <p key={i} className="opacity-40 text-red-400">
                        ✦ t={ev.height.toFixed(2)} · {ev.jets} jets
                      </p>
                    ))}
                  </div>
                )}
              </div>
              {jetLog.length > 0 && (
                <p className="mt-1 opacity-30">
                  {jetLog.length} jet event{jetLog.length > 1 ? "s" : ""} logged
                </p>
              )}
            </div>

            {/* Shape classifier readout */}
            <div className="mt-3 border-t border-white/10 pt-2">
              <div className="flex items-center gap-2">
                <span className="font-bold" style={{ color: shapeInfo ? SHAPE_LABELS[shapeInfo.shape].color : '#666' }}>
                  {shapeInfo ? SHAPE_LABELS[shapeInfo.shape].icon : '?'} SHAPE: {shapeInfo ? shapeInfo.shape.toUpperCase() : 'detecting...'}
                </span>
                {shapeInfo && (
                  <span className="opacity-30 text-[10px]">
                    ({(shapeInfo.confidence * 100).toFixed(0)}%)
                  </span>
                )}
              </div>
              {shapeInfo && (
                <div className="mt-1 opacity-40 space-y-0.5">
                  <p>λ: [{shapeInfo.eigenvalues.map(v => v.toFixed(2)).join(', ')}]</p>
                  <p>flat: {shapeInfo.flatness.toFixed(1)} · elong: {shapeInfo.elongation.toFixed(1)} · ring: {shapeInfo.ringScore.toFixed(2)} · void: {shapeInfo.voidScore.toFixed(2)}</p>
                </div>
              )}
            </div>

            {/* Morphology interval summary */}
            {morphologyLog.length > 0 && (
              <div className="mt-3 border-t border-white/10 pt-2">
                <div className="flex items-center gap-2">
                  <p className="font-bold opacity-60">MORPHOLOGY LOG</p>
                  <button
                    className="text-[10px] px-1.5 py-0.5 border border-white/20 text-white/50 hover:text-white/80 hover:border-white/40 transition-all pointer-events-auto"
                    onClick={downloadMorphologyLog}
                  >
                    ⤓ Export JSON
                  </button>
                </div>
                <div className="mt-1 max-h-32 overflow-y-auto space-y-1">
                  {morphologyLog.slice(-5).map((interval, i) => {
                    const dominant = (Object.entries(interval.shapes) as [ShapeType, number][])
                      .sort((a, b) => b[1] - a[1])[0];
                    return (
                      <div key={i} className="opacity-40 flex gap-2 items-center">
                        <span className="w-4" style={{ color: SHAPE_LABELS[dominant[0]].color }}>
                          {SHAPE_LABELS[dominant[0]].icon}
                        </span>
                        <span>zero {interval.zeroIndex}:</span>
                        <span className="tabular-nums">t=[{interval.tStart.toFixed(1)},{interval.tEnd.toFixed(1)}]</span>
                        <span style={{ color: SHAPE_LABELS[dominant[0]].color }}>
                          {dominant[0]}×{dominant[1]}
                        </span>
                        {interval.jetEvents > 0 && (
                          <span className="text-red-400">{interval.jetEvents}☢</span>
                        )}
                      </div>
                    );
                  })}
                </div>
              </div>
            )}
          </div>
        )}
      </div>

      {/* Right HUD — Critical Line Tracker + Zeros */}
      <div className="absolute top-8 right-8 z-10 pointer-events-none text-right drop-shadow-xl max-w-xs">
        <p className="text-xs opacity-50 mb-1">CRITICAL LINE σ = ½</p>
        <p className="text-3xl font-black tabular-nums">
          t = <span style={{ color: mode.coreColor }}>{height.toFixed(2)}</span>
        </p>
        {nextZero && (
          <p className="text-xs opacity-40 mt-1">
            next zero ≈ {nextZero.toFixed(2)} ({(nextZero - height).toFixed(1)}↑)
          </p>
        )}

        {/* Zeros log — always visible */}
        <div className="mt-6 text-left">
          <p className="text-xs opacity-50 border-b border-white/10 pb-1 mb-2">
            ZEROS DETECTED — {detectedZeros.length}
          </p>
          {detectedZeros.length === 0 ? (
            <p className="text-xs opacity-25 italic">
              Sweeping... first zero at t ≈ 14.13
            </p>
          ) : (
            <div className="max-h-80 overflow-y-auto">
              {detectedZeros.map((z) => {
                // Compare with known zeros
                const nearest = KNOWN_ZEROS.reduce((best, kz) =>
                  Math.abs(kz - z.height) < Math.abs(best - z.height) ? kz : best
                , KNOWN_ZEROS[0]);
                const error = Math.abs(nearest - z.height);
                const isAccurate = error < 0.5;

                return (
                  <div
                    key={z.index}
                    className="flex items-center gap-2 text-sm leading-relaxed"
                  >
                    <span className="opacity-60 w-6 text-right" style={{ color: mode.coreColor }}>
                      #{z.index}
                    </span>
                    <span className="font-bold tabular-nums" style={{ color: mode.coreColor }}>
                      t = {z.height.toFixed(3)}
                    </span>
                    <span className="text-xs opacity-30">
                      |ζ| ≈ {z.minCollapse.toFixed(4)}
                    </span>
                    {isAccurate && (
                      <span className="text-xs text-green-500 opacity-60">✓</span>
                    )}
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </div>

      {/* Bottom Right — Controls */}
      <div className="absolute bottom-8 right-8 z-10 pointer-events-auto drop-shadow-xl">
        <div className="flex flex-col gap-3 text-xs border border-white/10 bg-black/60 backdrop-blur-sm rounded px-4 py-3">
          {/* Particle count */}
          <div>
            <p className="opacity-50 mb-1.5 text-[10px] tracking-wider">PARTICLES (N)</p>
            <div className="flex gap-1">
              {N_PRESETS.map((p) => (
                <button
                  key={p.value}
                  onClick={() => setParticleCount(p.value)}
                  className={`px-2 py-0.5 border transition-all duration-150 ${
                    particleCount === p.value
                      ? "border-[#00ff88] bg-[#00ff88]/10 text-[#00ff88]"
                      : "border-white/15 text-white/40 hover:border-white/40 hover:text-white/70"
                  }`}
                >
                  {p.label}
                </button>
              ))}
            </div>
          </div>

          {/* Playback control */}
          <div>
            <p className="opacity-50 mb-1.5 text-[10px] tracking-wider">PLAYBACK [Space] [→]</p>
            <div className="flex gap-1">
              <button
                onClick={() => setPaused((p) => !p)}
                className={`px-2 py-0.5 border transition-all duration-150 ${
                  paused
                    ? "border-yellow-400 bg-yellow-400/10 text-yellow-400"
                    : "border-[#00ff88] bg-[#00ff88]/10 text-[#00ff88]"
                }`}
              >
                {paused ? "▶ Play" : "⏸ Pause"}
              </button>
              <button
                onClick={() => { setPaused(true); stepRef.current = true; }}
                className="px-2 py-0.5 border border-white/15 text-white/40 hover:border-white/40 hover:text-white/70 transition-all duration-150"
              >
                →| Step
              </button>
            </div>
          </div>

          {/* Speed control */}
          <div>
            <p className="opacity-50 mb-1.5 text-[10px] tracking-wider">SWEEP SPEED [ ] [ ]</p>
            <div className="flex gap-1">
              {SPEED_PRESETS.map((p) => (
                <button
                  key={p.value}
                  onClick={() => setSpeed(p.value)}
                  className={`px-2 py-0.5 border transition-all duration-150 ${
                    speed === p.value
                      ? "border-[#00ff88] bg-[#00ff88]/10 text-[#00ff88]"
                      : "border-white/15 text-white/40 hover:border-white/40 hover:text-white/70"
                  }`}
                >
                  {p.label}
                </button>
              ))}
            </div>
          </div>

          {/* L1 Trigger control */}
          <div className="border-t border-white/10 pt-3 mt-1">
            <p className="opacity-50 mb-1.5 text-[10px] tracking-wider">L1 JET TRIGGER</p>
            <div className="flex gap-1 items-center">
              <button
                onClick={() => setTriggerArmed((a) => !a)}
                className={`px-2 py-0.5 border transition-all duration-150 ${
                  triggerArmed
                    ? "border-red-500 bg-red-500/10 text-red-400"
                    : "border-white/15 text-white/40 hover:border-white/40"
                }`}
              >
                {triggerArmed ? "☢ Armed" : "○ Disarmed"}
              </button>
              <span className="text-white/30 mx-1">≥</span>
              {[1, 2, 3, 4, 5].map((n) => (
                <button
                  key={n}
                  onClick={() => setTriggerThreshold(n)}
                  className={`px-1.5 py-0.5 border transition-all duration-150 ${
                    triggerThreshold === n
                      ? "border-red-500 bg-red-500/10 text-red-400"
                      : "border-white/15 text-white/40 hover:border-white/40 hover:text-white/70"
                  }`}
                >
                  {n}
                </button>
              ))}
              <span className="text-white/30 ml-1 text-[10px]">jets</span>
            </div>
          </div>
        </div>
      </div>

      {/* Bottom Left — Watermark */}
      <div className="absolute bottom-8 left-8 z-10 pointer-events-none text-xs opacity-40">
        <p>Project HYPERZETA Explorer — The Cayley-Dickson Tower × TimeDomainBridge</p>
        <p>
          {mode.id === 3
            ? "1/ζ(s) = Σ μ(n)/nˢ  ·  Division by zero = the Möbius function"
            : mode.id === 5
            ? "Z(t) = Σ sin(t·ln pₖ)·eₖ  ·  31 primes on S³¹  ·  No prime is special"
            : mode.id === 6
            ? "17-1 = 16 = 2⁴  ·  Constructible by compass & straightedge  ·  Gauss, 1796"
            : "ζ_𝕋(s) = Σ n⁻ˢ  ·  s ∈ 𝕋₃₂  ·  Re(s) = ½  ·  PCA → Gram bound"}
        </p>
      </div>

      {modeIdx === 6 ? (
        <div style={{ width: "100%", height: "100%", display: "flex", alignItems: "center", justifyContent: "center", background: "#000000" }}>
          <Heptadecagon width={700} height={700} interactive={true} />
        </div>
      ) : (
        <Canvas
          camera={{ position: [0, 0, 30], fov: 60 }}
          className="w-full h-full bg-[#000000]"
        >
          <ambientLight intensity={0.5} />
          <OrbitControls autoRotate autoRotateSpeed={2.0} />
          {modeIdx === 4 ? (
            <SpectrometerGrid />
          ) : hyperSystem ? (
            <ExplorerCloud
              wasmEngine={hyperSystem.engine}
              memoryArray={hyperSystem.memory}
              layerArray={hyperSystem.layers}
              particleCount={particleCount}
              mode={mode}
              speed={speed}
              paused={paused}
              stepRef={stepRef}
              onMetrics={handleMetrics}
              onJets={handleJetsWithMorphology}
              onShape={handleShape}
              onBridge={handleBridge}
            />
          ) : null}
        </Canvas>
      )}
    </main>
  );
}
