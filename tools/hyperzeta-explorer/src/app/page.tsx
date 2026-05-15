"use client";

import { Canvas, useFrame } from "@react-three/fiber";
import { OrbitControls } from "@react-three/drei";
import { useEffect, useState, useRef, useMemo } from "react";
import * as THREE from "three";

import init, { HyperEngine } from "../wasm/core_engine.js";

const PARTICLE_COUNT = 150_000;

const KNOWN_ZEROS = [
  14.134725, 21.022040, 25.010858, 30.424876, 32.935062,
  37.586178, 40.918719, 43.327073, 48.005151, 49.773832,
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
    formula: "ℝ → ℂ → ℍ → 𝕆 → 𝕊",
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
];

// Layer colors for the Glass Staircase
const LAYER_COLORS = [
  "#ffffff", // ℝ — white (real, pure)
  "#00aaff", // ℂ — blue (complex)
  "#ffaa00", // ℍ — gold (quaternion)
  "#00ff88", // 𝕆 — green (octonion)
  "#ff00aa", // 𝕊 — magenta (sedenion)
];

const LAYER_NAMES = ["ℝ", "ℂ", "ℍ", "𝕆", "𝕊"];

// ═══════════════════════════════════════════════════════
// PARTICLE CLOUD COMPONENT
// ═══════════════════════════════════════════════════════

function ExplorerCloud({
  wasmEngine,
  memoryArray,
  layerArray,
  mode,
  onMetrics,
}: {
  wasmEngine: HyperEngine;
  memoryArray: Float32Array;
  layerArray: Float32Array;
  mode: ViewMode;
  onMetrics: (c: number, h: number) => void;
}) {
  const meshRef = useRef<THREE.InstancedMesh>(null);
  const frameCount = useRef(0);

  const matrix = useMemo(() => new THREE.Matrix4(), []);
  const position = useMemo(() => new THREE.Vector3(), []);
  const color = useMemo(() => new THREE.Color(), []);

  useFrame(() => {
    if (!meshRef.current) return;
    wasmEngine.tick_physics();
    frameCount.current += 1;

    // Update metrics at ~10Hz
    if (frameCount.current % 6 === 0) {
      const c = wasmEngine.get_collapse_metric();
      const lambda = wasmEngine.get_lambda();
      const t = 10.0 + lambda * 2.0;
      onMetrics(c, t);
    }

    for (let i = 0; i < PARTICLE_COUNT; i++) {
      const idx = i * 3;
      position.set(
        memoryArray[idx],
        memoryArray[idx + 1],
        memoryArray[idx + 2]
      );
      matrix.setPosition(position);
      meshRef.current.setMatrixAt(i, matrix);

      // Mode-specific coloring
      if (mode.id === 2) {
        // Glass Staircase: color by CD layer
        const layerIdx = Math.round(layerArray[idx]);
        const layerColor = LAYER_COLORS[Math.min(layerIdx, 4)];
        color.set(layerColor);
        meshRef.current.setColorAt(i, color);
      } else if (mode.id === 3) {
        // Division by Zero: color by Möbius sign
        const sign = layerArray[idx];
        const magnitude = layerArray[idx + 1];
        const brightness = Math.min(magnitude * 0.5, 1.0);
        if (sign > 0) {
          color.setRGB(brightness * 0.2, brightness * 0.5, brightness); // blue = +1
        } else {
          color.setRGB(brightness, brightness * 0.1, brightness * 0.2); // red = -1
        }
        meshRef.current.setColorAt(i, color);
      } else {
        // Origin / Teardrop: use mode color
        const dist = position.length();
        const t = Math.min(dist / 30, 1);
        const core = new THREE.Color(mode.coreColor);
        const edge = new THREE.Color(mode.edgeColor);
        color.lerpColors(core, edge, t);
        meshRef.current.setColorAt(i, color);
      }
    }

    meshRef.current.instanceMatrix.needsUpdate = true;
    if (meshRef.current.instanceColor) {
      meshRef.current.instanceColor.needsUpdate = true;
    }
  });

  return (
    <instancedMesh ref={meshRef} args={[undefined, undefined, PARTICLE_COUNT]}>
      <sphereGeometry args={[0.08, 4, 4]} />
      <meshBasicMaterial
        vertexColors
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
  const [hyperSystem, setHyperSystem] = useState<{
    engine: HyperEngine;
    memory: Float32Array;
    layers: Float32Array;
  } | null>(null);
  const [collapse, setCollapse] = useState(0);
  const [height, setHeight] = useState(10.0);
  const [modeIdx, setModeIdx] = useState(0);
  const [detectedZeros, setDetectedZeros] = useState<DetectedZero[]>([]);
  const [layerEnergies, setLayerEnergies] = useState([0, 0, 0, 0, 0]);
  const inZeroRef = useRef(false);
  const minCollapseRef = useRef(Infinity);
  const minHeightRef = useRef(0);

  const mode = VIEW_MODES[modeIdx];

  // Boot WASM engine
  useEffect(() => {
    const bootEngine = async () => {
      try {
        const wasmModule = await init();
        setEngineStatus("Allocating 16D Geometry RAM...");

        const engine = new HyperEngine(PARTICLE_COUNT);
        const ptr = engine.get_buffer_pointer();
        const memoryArray = new Float32Array(
          wasmModule.memory.buffer,
          ptr,
          PARTICLE_COUNT * 3
        );

        // Layer buffer for auxiliary data
        const layerPtr = engine.get_layer_buffer_pointer();
        const layerArray = new Float32Array(
          wasmModule.memory.buffer,
          layerPtr,
          PARTICLE_COUNT * 3
        );

        setHyperSystem({ engine, memory: memoryArray, layers: layerArray });
        setEngineStatus("WASM Core Locked — True Zero-Copy");
      } catch (e) {
        console.error(e);
        setEngineStatus("CRITICAL WASM CORE FAILURE");
      }
    };
    bootEngine();
  }, []);

  // Sync view mode to engine
  useEffect(() => {
    if (hyperSystem) {
      hyperSystem.engine.set_view_mode(modeIdx);
    }
  }, [modeIdx, hyperSystem]);

  // Keyboard shortcuts
  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      const num = parseInt(e.key);
      if (num >= 1 && num <= 4) {
        setModeIdx(num - 1);
      }
    };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, []);

  // Zero detection + layer energies
  useEffect(() => {
    if (!hyperSystem) return;
    const interval = setInterval(() => {
      const c = hyperSystem.engine.get_collapse_metric();
      const lambda = hyperSystem.engine.get_lambda();
      const t = 10.0 + lambda * 2.0;

      // Update layer energies for Glass Staircase
      if (modeIdx === 2) {
        const energies = [0, 1, 2, 3, 4].map((i) =>
          hyperSystem.engine.get_layer_energy(i)
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
      }
    }, 50);
    return () => clearInterval(interval);
  }, [hyperSystem, modeIdx]);

  const handleMetrics = (c: number, h: number) => {
    setCollapse(c);
    setHeight(h);
  };

  const nextZero = KNOWN_ZEROS.find((z) => z > height);

  return (
    <main className="w-screen h-screen flex flex-col items-center justify-center bg-[#050505] text-[#00ff88] font-mono overflow-hidden">
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
          {PARTICLE_COUNT.toLocaleString()} sedenion lattice points · Rust/WASM
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

        {/* Division by Zero: Möbius legend */}
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
          </div>
        )}
      </div>

      {/* Right HUD — Critical Line Tracker */}
      <div className="absolute top-8 right-8 z-10 pointer-events-none text-right drop-shadow-xl">
        <p className="text-xs opacity-50 mb-1">CRITICAL LINE σ = ½</p>
        <p className="text-3xl font-black tabular-nums">
          t = <span style={{ color: mode.coreColor }}>{height.toFixed(2)}</span>
        </p>
        {nextZero && (
          <p className="text-xs opacity-40 mt-1">
            next zero ≈ {nextZero.toFixed(2)} ({(nextZero - height).toFixed(1)}↑)
          </p>
        )}

        {detectedZeros.length > 0 && (
          <div className="mt-6 text-left">
            <p className="text-xs opacity-50 border-b border-white/10 pb-1 mb-2">
              ZEROS DETECTED — {detectedZeros.length}
            </p>
            <div className="max-h-64 overflow-hidden">
              {detectedZeros.slice(-10).map((z) => (
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
                </div>
              ))}
            </div>
          </div>
        )}
      </div>

      {/* Bottom Left — Watermark */}
      <div className="absolute bottom-8 left-8 z-10 pointer-events-none text-xs opacity-40">
        <p>Project HYPERZETA Explorer — The Cayley-Dickson Tower</p>
        <p>
          {mode.id === 3
            ? "1/ζ(s) = Σ μ(n)/nˢ  ·  Division by zero = the Möbius function"
            : "ζ_𝕊(s) = Σ n⁻ˢ  ·  s ∈ 𝕊₁₆  ·  Re(s) = ½"}
        </p>
      </div>

      <Canvas
        camera={{ position: [0, 0, 30], fov: 60 }}
        className="w-full h-full bg-[#000000]"
      >
        <ambientLight intensity={0.5} />
        <OrbitControls autoRotate autoRotateSpeed={2.0} />
        {hyperSystem && (
          <ExplorerCloud
            wasmEngine={hyperSystem.engine}
            memoryArray={hyperSystem.memory}
            layerArray={hyperSystem.layers}
            mode={mode}
            onMetrics={handleMetrics}
          />
        )}
      </Canvas>
    </main>
  );
}
