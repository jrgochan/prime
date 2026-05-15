"use client";

import { Canvas, useFrame } from "@react-three/fiber";
import { OrbitControls } from "@react-three/drei";
import { useEffect, useState, useRef, useMemo, useCallback } from "react";
import * as THREE from "three";

import init, { HyperEngine } from "../wasm/core_engine.js";

const DEFAULT_PARTICLE_COUNT = 150_000;

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

// Pre-computed layer color objects (avoid allocation in hot loop)
const LAYER_COLOR_OBJS = LAYER_COLORS.map((c) => new THREE.Color(c));

function ExplorerCloud({
  wasmEngine,
  memoryArray,
  layerArray,
  particleCount,
  mode,
  speed,
  onMetrics,
}: {
  wasmEngine: HyperEngine;
  memoryArray: Float32Array;
  layerArray: Float32Array;
  particleCount: number;
  mode: ViewMode;
  speed: number;
  onMetrics: (c: number, h: number) => void;
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

  useFrame(() => {
    if (!meshRef.current) return;

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

    frameCount.current += 1;

    // Update metrics at ~10Hz
    if (frameCount.current % 6 === 0) {
      const c = wasmEngine.get_collapse_metric();
      const lambda = wasmEngine.get_lambda();
      const t = 10.0 + lambda * 2.0;
      onMetrics(c, t);
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
          // Glass Staircase: color by dominant CD layer
          const layerIdx = Math.min(Math.max(Math.round(layerArray[idx]), 0), 4);
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
        } else {
          // Origin / Teardrop: gradient from core to edge based on distance
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
  const [layerEnergies, setLayerEnergies] = useState([0, 0, 0, 0, 0]);
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

  // Keyboard shortcuts
  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      // Ignore if typing in an input
      if ((e.target as HTMLElement).tagName === "INPUT") return;

      const num = parseInt(e.key);
      if (num >= 1 && num <= 4) {
        setModeIdx(num - 1);
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

  const handleMetrics = useCallback((c: number, h: number) => {
    setCollapse(c);
    setHeight(h);
  }, []);

  const nextZero = KNOWN_ZEROS.find((z) => z > height);
  const speedLabel = SPEED_PRESETS.find((p) => p.value === speed)?.label || `${speed}×`;

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
          {particleCount.toLocaleString()} sedenion lattice points · Rust/WASM · {speedLabel}
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

          {/* Speed control */}
          <div>
            <p className="opacity-50 mb-1.5 text-[10px] tracking-wider">SWEEP SPEED [  ] [ ]</p>
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
        </div>
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
            particleCount={particleCount}
            mode={mode}
            speed={speed}
            onMetrics={handleMetrics}
          />
        )}
      </Canvas>
    </main>
  );
}
