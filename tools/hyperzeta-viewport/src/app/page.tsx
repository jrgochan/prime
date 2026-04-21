"use client";

import { Canvas, useFrame, useThree } from "@react-three/fiber";
import { OrbitControls, Stars, Text } from "@react-three/drei";
import { useEffect, useState, useRef, useMemo, useCallback } from "react";
import * as THREE from "three";

import init, { HyperEngine } from "../wasm/core_engine.js";

const PARTICLE_COUNT = 150_000;

/* ═══════════════════════════════════════════════════════
   §1. PARTICLE CLOUD — True Zero-Copy WASM Rendering
   ═══════════════════════════════════════════════════════ */

type ViewMode = "output" | "input";

function LatticePointCloud({
  wasmEngine,
  outputArray,
  inputArray,
  viewMode,
  onMetrics,
  speed,
}: {
  wasmEngine: HyperEngine;
  outputArray: Float32Array;
  inputArray: Float32Array;
  viewMode: ViewMode;
  onMetrics: (collapse: number, lambda: number) => void;
  speed: number;
}) {
  const memoryArray = viewMode === "input" ? inputArray : outputArray;
  const meshRef = useRef<THREE.InstancedMesh>(null);
  const matrix = useMemo(() => new THREE.Matrix4(), []);
  const position = useMemo(() => new THREE.Vector3(), []);
  const frameCount = useRef(0);

  useFrame(() => {
    if (!meshRef.current) return;

    // Execute physics at the selected speed multiplier
    for (let s = 0; s < speed; s++) {
      wasmEngine.tick_physics();
    }
    frameCount.current += 1;

    const collapseMetric = wasmEngine.get_collapse_metric();
    const lambdaFrame = wasmEngine.get_lambda();

    // Report metrics every 6 frames (~10Hz)
    if (frameCount.current % 6 === 0) {
      onMetrics(collapseMetric, lambdaFrame);
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
    }

    meshRef.current.instanceMatrix.needsUpdate = true;
  });

  return (
    <instancedMesh ref={meshRef} args={[undefined, undefined, PARTICLE_COUNT]}>
      <sphereGeometry args={[0.08, 4, 4]} />
      <meshBasicMaterial
        color={viewMode === "input" ? "#00ccff" : "#00ff88"}
        opacity={0.6}
        transparent
        depthWrite={false}
      />
    </instancedMesh>
  );
}

/* ═══════════════════════════════════════════════════════
   §2. 3D AXIS LABELS
   ═══════════════════════════════════════════════════════ */

function AxisLabels() {
  const labelStyle = {
    fontSize: 0.8,
    color: "rgba(255,255,255,0.35)",
    anchorX: "center" as const,
    anchorY: "middle" as const,
  };

  return (
    <>
      {/* Axis lines */}
      <line>
        <bufferGeometry>
          <bufferAttribute
            attach="attributes-position"
            args={[new Float32Array([-20, 0, 0, 20, 0, 0]), 3]}
            count={2}
            itemSize={3}
          />
        </bufferGeometry>
        <lineBasicMaterial color="rgba(0,255,136,0.12)" />
      </line>
      <line>
        <bufferGeometry>
          <bufferAttribute
            attach="attributes-position"
            args={[new Float32Array([0, -20, 0, 0, 20, 0]), 3]}
            count={2}
            itemSize={3}
          />
        </bufferGeometry>
        <lineBasicMaterial color="rgba(0,204,255,0.12)" />
      </line>
      <line>
        <bufferGeometry>
          <bufferAttribute
            attach="attributes-position"
            args={[new Float32Array([0, 0, -20, 0, 0, 20]), 3]}
            count={2}
            itemSize={3}
          />
        </bufferGeometry>
        <lineBasicMaterial color="rgba(255,107,157,0.12)" />
      </line>

      {/* Labels */}
      <Text position={[22, 0, 0]} {...labelStyle} color="#00ff88">
        Im(i)
      </Text>
      <Text position={[0, 22, 0]} {...labelStyle} color="#00ccff">
        Im(j)
      </Text>
      <Text position={[0, 0, 22]} {...labelStyle} color="#ff6b9d">
        Im(k)
      </Text>
    </>
  );
}

/* ═══════════════════════════════════════════════════════
   §3. CAMERA CONTROLLER
   ═══════════════════════════════════════════════════════ */

type CameraPreset = "orbital" | "zero-focus" | "side";

function CameraController({
  preset,
  autoRotate,
}: {
  preset: CameraPreset;
  autoRotate: boolean;
}) {
  const controlsRef = useRef<any>(null);
  const { camera } = useThree();

  useEffect(() => {
    if (!controlsRef.current) return;
    const c = controlsRef.current;

    switch (preset) {
      case "orbital":
        camera.position.set(0, 0, 20);
        c.target.set(0, 0, 0);
        break;
      case "zero-focus":
        camera.position.set(5, 5, 8);
        c.target.set(0, 0, 0);
        break;
      case "side":
        camera.position.set(25, 0, 0);
        c.target.set(0, 0, 0);
        break;
    }
    c.update();
  }, [preset, camera]);

  return (
    <OrbitControls
      ref={controlsRef}
      autoRotate={autoRotate}
      autoRotateSpeed={1.2}
      enableDamping
      dampingFactor={0.05}
      minDistance={5}
      maxDistance={80}
    />
  );
}

/* ═══════════════════════════════════════════════════════
   §4. EDUCATIONAL COMPONENTS
   ═══════════════════════════════════════════════════════ */

const GLOSSARY: Record<string, string> = {
  Sedenion:
    "A 16-dimensional hypercomplex number system. The fourth in the Cayley-Dickson construction: ℝ → ℂ → ℍ → 𝕆 → 𝕊.",
  "Critical Line":
    "The vertical line Re(s) = ½ in the complex plane. The Riemann Hypothesis states all non-trivial zeros of ζ(s) lie here.",
  "Spectral Gap":
    "The smallest eigenvalue of the Gram matrix. A positive spectral gap for all N implies the Riemann Hypothesis.",
  "Dirichlet Series":
    "ζ(s) = Σ n⁻ˢ. The sum converges for Re(s) > 1 and is analytically continued elsewhere.",
  "Collapse Metric":
    "Average |ζ(s)|² across all particles. When it drops, particles cluster near a zero of zeta.",
  "Cathedral":
    "A formal verification framework in Lean 4 that reduces the Riemann Hypothesis to 7 machine-checked axioms.",
};

function Tooltip({ term }: { term: string }) {
  const [show, setShow] = useState(false);
  const def = GLOSSARY[term];
  if (!def) return <span>{term}</span>;
  return (
    <span
      className="glossary-term"
      onMouseEnter={() => setShow(true)}
      onMouseLeave={() => setShow(false)}
    >
      {term}
      {show && <span className="glossary-popup">{def}</span>}
    </span>
  );
}

const EDUCATIONAL_CARDS = [
  {
    title: "What You're Seeing",
    body: (
      <>
        150,000 points representing a <Tooltip term="Sedenion" /> lattice — a
        16-dimensional algebraic structure — projected into 3D. The Rust/WASM
        engine evolves each point along the{" "}
        <Tooltip term="Critical Line" /> of the Riemann zeta function.
      </>
    ),
  },
  {
    title: "The Mathematics",
    body: (
      <>
        Each particle represents an input s in 16D with Re(s) = ½. The engine
        computes the <Tooltip term="Dirichlet Series" /> ζ(s) = Σ n⁻ˢ in full
        sedenion arithmetic. What you see is the <em>output</em> — the value
        of ζ(s) — projected to 3D via its quaternionic components.
      </>
    ),
  },
  {
    title: "Why Particles Collapse",
    body: (
      <>
        When the <Tooltip term="Collapse Metric" /> drops, particles cluster
        near the origin. This means ζ(s) ≈ 0 — the simulation has found a
        zero of zeta on the critical line. The{" "}
        <Tooltip term="Spectral Gap" /> measures how strongly this convergence
        holds.
      </>
    ),
  },
  {
    title: "The Cathedral Connection",
    body: (
      <>
        This viewport was the origin of <Tooltip term="Cathedral" /> — a Lean
        4 formal verification framework. The proof reduces the Riemann
        Hypothesis to 7 crown axioms, all machine-checked. The sedenion
        structure here inspired the octonionic partition used in the spectral
        analysis.
      </>
    ),
  },
];

function InfoCard({
  title,
  body,
  index,
}: {
  title: string;
  body: React.ReactNode;
  index: number;
}) {
  return (
    <div className="info-card" style={{ animationDelay: `${index * 150}ms` }}>
      <h3>{title}</h3>
      <p>{body}</p>
    </div>
  );
}

/* ═══════════════════════════════════════════════════════
   §5. METRICS & TIMELINE
   ═══════════════════════════════════════════════════════ */

function MetricBar({
  label,
  value,
  max,
  color,
}: {
  label: string;
  value: number;
  max: number;
  color: string;
}) {
  const pct = Math.min((value / max) * 100, 100);
  return (
    <div className="metric-row">
      <span className="metric-label">{label}</span>
      <div className="metric-bar-track">
        <div
          className="metric-bar-fill"
          style={{ width: `${pct}%`, backgroundColor: color }}
        />
      </div>
      <span className="metric-value">{value.toFixed(3)}</span>
    </div>
  );
}

function PhaseTimeline({ lambda }: { lambda: number }) {
  const maxLambda = 10;
  const pct = Math.min((lambda / maxLambda) * 100, 100);

  const milestones = [
    { at: 0, label: "Random Init" },
    { at: 15, label: "Spiral Forms" },
    { at: 40, label: "Structure" },
    { at: 70, label: "Convergence" },
    { at: 95, label: "Singularity" },
  ];

  return (
    <div className="phase-timeline">
      <div className="phase-track">
        <div className="phase-fill" style={{ width: `${pct}%` }} />
        {milestones.map((m) => (
          <div
            key={m.label}
            className={`phase-milestone ${pct >= m.at ? "active" : ""}`}
            style={{ left: `${m.at}%` }}
          >
            <div className="phase-dot" />
            <span className="phase-label">{m.label}</span>
          </div>
        ))}
      </div>
    </div>
  );
}

function CriticalStripMiniMap({ lambda }: { lambda: number }) {
  const height = 10 + lambda * 2;
  const maxHeight = 30;
  const yPct = Math.min((height / maxHeight) * 100, 100);

  return (
    <div className="minimap">
      <div className="minimap-title">CRITICAL STRIP</div>
      <div className="minimap-strip">
        {/* The strip Re(s) ∈ [0, 1] */}
        <div className="minimap-critical-line" />
        <div className="minimap-dot" style={{ bottom: `${yPct}%` }} />
        <div className="minimap-label-left">0</div>
        <div className="minimap-label-right">1</div>
        <div className="minimap-label-re">Re(s)</div>
        <div
          className="minimap-label-im"
          style={{ bottom: `${Math.min(yPct + 3, 90)}%` }}
        >
          t={height.toFixed(1)}
        </div>
      </div>
    </div>
  );
}

/* ═══════════════════════════════════════════════════════
   §6. EQUATION OVERLAY
   ═══════════════════════════════════════════════════════ */

function EquationOverlay({ lambda }: { lambda: number }) {
  const height = (10 + lambda * 2).toFixed(1);
  return (
    <div className="equation-overlay">
      <div className="equation-main">
        ζ<sub>𝕊</sub>(s) = Σ<sub>n=1</sub>
        <sup>8</sup> n<sup>−s</sup>
      </div>
      <div className="equation-params">
        s ∈ 𝕊<sub>16</sub> &nbsp;·&nbsp; Re(s) = ½ &nbsp;·&nbsp; Im(s) ≈{" "}
        {height}
      </div>
    </div>
  );
}

/* ═══════════════════════════════════════════════════════
   §7. TOAST NOTIFICATIONS
   ═══════════════════════════════════════════════════════ */

function Toast({
  message,
  visible,
}: {
  message: string;
  visible: boolean;
}) {
  if (!visible) return null;
  return (
    <div className="toast">
      <span className="toast-icon">✦</span>
      <span>{message}</span>
    </div>
  );
}

/* ═══════════════════════════════════════════════════════
   §8. MAIN APP
   ═══════════════════════════════════════════════════════ */

type EngineState = "booting" | "allocating" | "running" | "collapsed";

export default function Home() {
  const [engineState, setEngineState] = useState<EngineState>("booting");
  const [hyperSystem, setHyperSystem] = useState<{
    engine: HyperEngine;
    outputMemory: Float32Array;
    inputMemory: Float32Array;
  } | null>(null);

  const [collapse, setCollapse] = useState(1.0);
  const [lambda, setLambda] = useState(0.0);
  const [showInfo, setShowInfo] = useState(false);
  const [singularityCount, setSingularityCount] = useState(0);
  const [speed, setSpeed] = useState(1);
  const [viewMode, setViewMode] = useState<ViewMode>("output");
  const [cameraPreset, setCameraPreset] = useState<CameraPreset>("orbital");
  const [toastMsg, setToastMsg] = useState("");
  const [toastVisible, setToastVisible] = useState(false);

  const singularityTriggered = useRef(false);

  // Boot WASM engine
  useEffect(() => {
    const bootEngine = async () => {
      try {
        const wasmModule = await init();
        setEngineState("allocating");

        const engine = new HyperEngine(PARTICLE_COUNT);

        const outPtr = engine.get_buffer_pointer();
        const outputMemory = new Float32Array(
          wasmModule.memory.buffer,
          outPtr,
          PARTICLE_COUNT * 3
        );

        const inPtr = engine.get_input_buffer_pointer();
        const inputMemory = new Float32Array(
          wasmModule.memory.buffer,
          inPtr,
          PARTICLE_COUNT * 3
        );

        setHyperSystem({ engine, outputMemory, inputMemory });
        setEngineState("running");
      } catch (e) {
        console.error("WASM init failed:", e);
      }
    };
    bootEngine();
  }, []);

  const showToast = useCallback((msg: string) => {
    setToastMsg(msg);
    setToastVisible(true);
    setTimeout(() => setToastVisible(false), 4000);
  }, []);

  const handleMetrics = useCallback(
    (c: number, l: number) => {
      setCollapse(c);
      setLambda(l);

      // Detect singularity
      if (l > 1.0 && c < 0.5 && !singularityTriggered.current) {
        singularityTriggered.current = true;
        setSingularityCount((prev) => prev + 1);
        setEngineState("collapsed");
        showToast(
          "Particles converged — ζ(s) ≈ 0 near the critical line. A spectral singularity!"
        );
        setTimeout(() => {
          setEngineState("running");
          singularityTriggered.current = false;
        }, 5000);
      }
    },
    [showToast]
  );

  const statusText: Record<EngineState, string> = {
    booting: "Compiling Rust WASM Module…",
    allocating: "Allocating 16D Lattice RAM…",
    running: "Lattice Evolving — Live",
    collapsed: "✦ Spectral Singularity Detected",
  };

  const statusColor: Record<EngineState, string> = {
    booting: "#ffaa00",
    allocating: "#ffaa00",
    running: "#00ff88",
    collapsed: "#ff6b9d",
  };

  return (
    <main className="viewport-root">
      {/* ── HEADER ── */}
      <header className="viewport-header">
        <div className="header-left">
          <h1 className="title">PROJECT HYPERZETA</h1>
          <div
            className="status-badge"
            style={{ borderColor: statusColor[engineState] }}
          >
            <span
              className="status-dot"
              style={{ backgroundColor: statusColor[engineState] }}
            />
            <span style={{ color: statusColor[engineState] }}>
              {statusText[engineState]}
            </span>
          </div>
        </div>
        <div className="header-right">
          <button
            className="info-toggle"
            onClick={() => setShowInfo(!showInfo)}
            title="Toggle educational info"
          >
            {showInfo ? "✕" : "ℹ"}
          </button>
        </div>
      </header>

      {/* ── PHASE TIMELINE ── */}
      <div className="timeline-container">
        <PhaseTimeline lambda={lambda} />
      </div>

      {/* ── CONTROLS ── */}
      <div className="controls-panel">
        <div className="controls-title">CONTROLS</div>

        <div className="control-group">
          <label className="control-label">Speed</label>
          <div className="speed-buttons">
            {[1, 2, 4, 8].map((s) => (
              <button
                key={s}
                className={`speed-btn ${speed === s ? "active" : ""}`}
                onClick={() => setSpeed(s)}
              >
                {s}×
              </button>
            ))}
          </div>
        </div>

        <div className="control-group">
          <label className="control-label">View</label>
          <div className="view-buttons">
            <button
              className={`view-btn ${viewMode === "output" ? "active" : ""}`}
              onClick={() => setViewMode("output")}
              title="ζ(s) output values — shows collapse near zeros"
            >
              ζ(s)
            </button>
            <button
              className={`view-btn ${viewMode === "input" ? "active" : ""}`}
              onClick={() => setViewMode("input")}
              title="Input coordinates — shows the 16D spiral structure"
            >
              Spiral
            </button>
          </div>
        </div>

        <div className="control-group">
          <label className="control-label">Camera</label>
          <div className="camera-buttons">
            <button
              className={`cam-btn ${cameraPreset === "orbital" ? "active" : ""}`}
              onClick={() => setCameraPreset("orbital")}
              title="Orbital view — auto-rotating"
            >
              🔭
            </button>
            <button
              className={`cam-btn ${cameraPreset === "zero-focus" ? "active" : ""}`}
              onClick={() => setCameraPreset("zero-focus")}
              title="Zero focus — close-up on origin"
            >
              🎯
            </button>
            <button
              className={`cam-btn ${cameraPreset === "side" ? "active" : ""}`}
              onClick={() => setCameraPreset("side")}
              title="Side view — see spiral structure"
            >
              📐
            </button>
          </div>
        </div>
      </div>

      {/* ── LIVE METRICS ── */}
      <div className="metrics-panel">
        <div className="metrics-title">LIVE TELEMETRY</div>
        <MetricBar
          label="Collapse"
          value={collapse}
          max={2}
          color={collapse < 0.5 ? "#ff6b9d" : "#00ff88"}
        />
        <MetricBar
          label="λ (time)"
          value={lambda}
          max={10}
          color="#00ccff"
        />
        <div className="metric-row" style={{ marginTop: "8px" }}>
          <span className="metric-label">Singularities</span>
          <span className="metric-value singularity-count">
            {singularityCount}
          </span>
        </div>
        <div className="metric-row">
          <span className="metric-label">Particles</span>
          <span className="metric-value">
            {PARTICLE_COUNT.toLocaleString()}
          </span>
        </div>
        <div className="metric-row">
          <span className="metric-label">Engine</span>
          <span className="metric-value">Rust → WASM</span>
        </div>
      </div>

      {/* ── EQUATION OVERLAY ── */}
      <EquationOverlay lambda={lambda} />

      {/* ── MINI-MAP ── */}
      <CriticalStripMiniMap lambda={lambda} />

      {/* ── TOAST ── */}
      <Toast message={toastMsg} visible={toastVisible} />

      {/* ── EDUCATIONAL SIDEBAR ── */}
      {showInfo && (
        <aside className="info-sidebar">
          <h2 className="info-sidebar-title">About This Visualization</h2>
          {EDUCATIONAL_CARDS.map((card, i) => (
            <InfoCard
              key={card.title}
              title={card.title}
              body={card.body}
              index={i}
            />
          ))}
          <div className="info-footer">
            <p>
              Part of{" "}
              <a
                href="https://github.com/jrgochan/prime"
                target="_blank"
                rel="noopener noreferrer"
              >
                The Cathedral
              </a>{" "}
              — A Machine-Verified Reduction of the Riemann Hypothesis
            </p>
          </div>
        </aside>
      )}

      {/* ── FOOTER ── */}
      <footer className="viewport-footer">
        <span>
          Matrix: Rust/WASM · Renderer: Three.js InstancedMesh ·{" "}
          {PARTICLE_COUNT.toLocaleString()} particles
        </span>
        <span>The Cathedral Project</span>
      </footer>

      {/* ── 3D CANVAS ── */}
      <Canvas
        camera={{ position: [0, 0, 20], fov: 60 }}
        className="viewport-canvas"
      >
        <ambientLight intensity={0.3} />
        <pointLight position={[10, 10, 10]} intensity={0.4} color="#00ff88" />
        <Stars
          radius={100}
          depth={60}
          count={2000}
          factor={3}
          saturation={0}
          fade
          speed={0.5}
        />
        <CameraController
          preset={cameraPreset}
          autoRotate={cameraPreset === "orbital"}
        />
        <AxisLabels />
        {hyperSystem && (
          <LatticePointCloud
            wasmEngine={hyperSystem.engine}
            outputArray={hyperSystem.outputMemory}
            inputArray={hyperSystem.inputMemory}
            viewMode={viewMode}
            onMetrics={handleMetrics}
            speed={speed}
          />
        )}
      </Canvas>
    </main>
  );
}
