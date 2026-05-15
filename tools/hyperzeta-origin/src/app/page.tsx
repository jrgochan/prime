"use client";

import { Canvas, useFrame } from "@react-three/fiber";
import { OrbitControls } from "@react-three/drei";
import { useEffect, useState, useRef, useMemo, useCallback } from "react";
import * as THREE from "three";

// True Zero-Copy Compilation Target loaded dynamically
import init, { HyperEngine } from "../wasm/core_engine.js";

const PARTICLE_COUNT = 150_000;

// Known non-trivial zero heights (for reference markers)
const KNOWN_ZEROS = [
  14.134725, 21.022040, 25.010858, 30.424876, 32.935062,
  37.586178, 40.918719, 43.327073, 48.005151, 49.773832,
  52.970321, 56.446248, 59.347044, 60.831779, 65.112544,
  67.079811, 69.546402, 72.067158, 75.704691, 77.144840,
];

function LatticePointCloud({ wasmEngine, memoryArray }: { wasmEngine: HyperEngine, memoryArray: Float32Array }) {
  const meshRef = useRef<THREE.InstancedMesh>(null);
  
  const matrix = useMemo(() => new THREE.Matrix4(), []);
  const position = useMemo(() => new THREE.Vector3(), []);

  useFrame(() => {
    if (!meshRef.current) return;
    wasmEngine.tick_physics();
    
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
      <meshBasicMaterial color="#00ff88" opacity={0.6} transparent depthWrite={false} />
    </instancedMesh>
  );
}

interface DetectedZero {
  index: number;
  height: number;
  minCollapse: number;
}

export default function Home() {
  const [engineStatus, setEngineStatus] = useState("Compiling Rust Mathematics Array...");
  const [hyperSystem, setHyperSystem] = useState<{engine: HyperEngine, memory: Float32Array} | null>(null);
  const [collapse, setCollapse] = useState(0);
  const [height, setHeight] = useState(10.0);
  const [detectedZeros, setDetectedZeros] = useState<DetectedZero[]>([]);
  const inZeroRef = useRef(false);
  const minCollapseRef = useRef(Infinity);
  const minHeightRef = useRef(0);

  useEffect(() => {
    const bootEngine = async () => {
        try {
            const wasmModule = await init();
            setEngineStatus("Allocating 16D Geometry RAM...");
            
            let engine = new HyperEngine(PARTICLE_COUNT);
            let ptr = engine.get_buffer_pointer();
            let memoryArray = new Float32Array(wasmModule.memory.buffer, ptr, PARTICLE_COUNT * 3);
            
            setHyperSystem({ engine, memory: memoryArray });
            setEngineStatus("WASM Core Locked — True Zero-Copy");
        } catch(e) {
            console.error(e);
            setEngineStatus("CRITICAL WASM CORE FAILURE");
        }
    };
    bootEngine();
  }, []);

  // Poll collapse metric + height + detect zeros
  useEffect(() => {
    if (!hyperSystem) return;
    const interval = setInterval(() => {
      const c = hyperSystem.engine.get_collapse_metric();
      const lambda = hyperSystem.engine.get_lambda();
      const t = 10.0 + lambda * 2.0;
      
      setCollapse(c);
      setHeight(t);

      // Zero detection with hysteresis
      const ZERO_THRESHOLD = 0.15;
      const EXIT_THRESHOLD = 0.3;

      if (!inZeroRef.current && c < ZERO_THRESHOLD) {
        // Entering a zero region
        inZeroRef.current = true;
        minCollapseRef.current = c;
        minHeightRef.current = t;
      } else if (inZeroRef.current && c < minCollapseRef.current) {
        // Still in zero, track the minimum
        minCollapseRef.current = c;
        minHeightRef.current = t;
      } else if (inZeroRef.current && c > EXIT_THRESHOLD) {
        // Exiting zero region — record it
        inZeroRef.current = false;
        setDetectedZeros(prev => [...prev, {
          index: prev.length + 1,
          height: minHeightRef.current,
          minCollapse: minCollapseRef.current,
        }]);
        minCollapseRef.current = Infinity;
      }
    }, 50);
    return () => clearInterval(interval);
  }, [hyperSystem]);

  // Find next known zero ahead of current height
  const nextZero = KNOWN_ZEROS.find(z => z > height);

  return (
    <main className="w-screen h-screen flex flex-col items-center justify-center bg-[#050505] text-[#00ff88] font-mono overflow-hidden">
      {/* Left HUD — Original */}
      <div className="absolute top-8 left-8 z-10 pointer-events-none flex flex-col gap-1 drop-shadow-xl max-w-lg">
        <h1 className="text-4xl font-black tracking-widest text-[#00ff88]">PROJECT HYPERZETA</h1>
        <p className={`opacity-90 font-bold border-b pb-2 mb-2 w-max ${engineStatus.includes('Locked') ? 'border-[#00ff88]' : 'border-red-500 text-yellow-300'}`}>Status: {engineStatus}</p>
        <p className="text-sm opacity-75">Matrix Logic: Rust/WASM Sedenion Engine</p>
        <p className="text-sm opacity-75">Transport: WebAssembly Zero-Copy Membrane</p>
        <p className="text-sm opacity-50 mt-4 italic">Rendering {PARTICLE_COUNT.toLocaleString()} sedenion lattice points via WebGPU InstancedMesh.</p>
        <p className="text-lg mt-4 font-bold">Collapse: <span className={collapse < 0.15 ? 'text-red-400 animate-pulse' : collapse < 0.5 ? 'text-red-400' : ''}>{collapse.toFixed(4)}</span></p>
      </div>

      {/* Right HUD — Critical Line Tracker */}
      <div className="absolute top-8 right-8 z-10 pointer-events-none text-right drop-shadow-xl">
        <p className="text-xs opacity-50 mb-1">CRITICAL LINE  σ = ½</p>
        <p className="text-3xl font-black tabular-nums">
          t = <span className="text-[#88ffcc]">{height.toFixed(2)}</span>
        </p>
        {nextZero && (
          <p className="text-xs opacity-40 mt-1">
            next zero ≈ {nextZero.toFixed(2)} ({(nextZero - height).toFixed(1)}↑)
          </p>
        )}

        {/* Detected zeros log */}
        {detectedZeros.length > 0 && (
          <div className="mt-6 text-left">
            <p className="text-xs opacity-50 border-b border-[#00ff8833] pb-1 mb-2">
              ZEROS DETECTED — {detectedZeros.length}
            </p>
            <div className="max-h-64 overflow-hidden">
              {detectedZeros.slice(-10).map((z) => (
                <div key={z.index} className="flex items-center gap-2 text-sm leading-relaxed">
                  <span className="text-[#00ff88] opacity-60 w-6 text-right">#{z.index}</span>
                  <span className="text-[#88ffcc] font-bold tabular-nums">t = {z.height.toFixed(3)}</span>
                  <span className="text-xs opacity-30">|ζ| ≈ {z.minCollapse.toFixed(4)}</span>
                </div>
              ))}
            </div>
          </div>
        )}
      </div>

      {/* Bottom Left — Origin watermark */}
      <div className="absolute bottom-8 left-8 z-10 pointer-events-none text-xs opacity-40">
        <p>March 27, 2026 — The spark that started the Cathedral</p>
        <p>ζ_𝕊(s) = Σ n⁻ˢ  ·  s ∈ 𝕊₁₆  ·  Re(s) = ½</p>
      </div>
      
      <Canvas camera={{ position: [0, 0, 30], fov: 60 }} className="w-full h-full bg-[#000000]">
        <ambientLight intensity={0.5} />
        <OrbitControls autoRotate autoRotateSpeed={2.0} />
        {hyperSystem && <LatticePointCloud wasmEngine={hyperSystem.engine} memoryArray={hyperSystem.memory} />}
      </Canvas>
    </main>
  );
}
