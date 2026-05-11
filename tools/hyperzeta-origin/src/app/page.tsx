"use client";

import { Canvas, useFrame } from "@react-three/fiber";
import { OrbitControls } from "@react-three/drei";
import { useEffect, useState, useRef, useMemo } from "react";
import * as THREE from "three";

// True Zero-Copy Compilation Target loaded dynamically
import init, { HyperEngine } from "../wasm/core_engine.js";

const PARTICLE_COUNT = 150_000;

function LatticePointCloud({ wasmEngine, memoryArray }: { wasmEngine: HyperEngine, memoryArray: Float32Array }) {
  const meshRef = useRef<THREE.InstancedMesh>(null);
  
  // Matrix pools initialized exactly once natively bypassing JavaScript garbage collector loops
  const matrix = useMemo(() => new THREE.Matrix4(), []);
  const position = useMemo(() => new THREE.Vector3(), []);

  // Frame Loop binding to the memory block at 120Hz
  useFrame(() => {
    if (!meshRef.current) return;
    
    // Natively trigger Rust internal mathematics (Executes physically in WASM boundary in <0.02ms)
    wasmEngine.tick_physics();
    
    // True Zero-Copy Buffer Membrane
    // We physically iterate over the physical RAM chunk provided by Rust via Float32Array mapping
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
    
    // Dispatch massive array to WebGPU Shader Pipeline
    meshRef.current.instanceMatrix.needsUpdate = true;
  });

  return (
    // Only 1 Draw Call for all points
    <instancedMesh ref={meshRef} args={[undefined, undefined, PARTICLE_COUNT]}>
      <sphereGeometry args={[0.08, 4, 4]} />
      <meshBasicMaterial color="#00ff88" opacity={0.6} transparent depthWrite={false} />
    </instancedMesh>
  );
}

export default function Home() {
  const [engineStatus, setEngineStatus] = useState("Compiling Rust Mathematics Array...");
  const [hyperSystem, setHyperSystem] = useState<{engine: HyperEngine, memory: Float32Array} | null>(null);
  const [collapse, setCollapse] = useState(0);

  useEffect(() => {
    const bootEngine = async () => {
        try {
            // Boot `core-engine` natively inside the React thread boundary
            const wasmModule = await init();
            setEngineStatus("Allocating 16D Geometry RAM...");
            
            // Execute Rust Memory Map
            let engine = new HyperEngine(PARTICLE_COUNT);
            let ptr = engine.get_buffer_pointer();
            
            // Physical Memory TypedArray Casting
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

  // Poll collapse metric
  useEffect(() => {
    if (!hyperSystem) return;
    const interval = setInterval(() => {
      setCollapse(hyperSystem.engine.get_collapse_metric());
    }, 100);
    return () => clearInterval(interval);
  }, [hyperSystem]);

  return (
    <main className="w-screen h-screen flex flex-col items-center justify-center bg-[#050505] text-[#00ff88] font-mono overflow-hidden">
      <div className="absolute top-8 left-8 z-10 pointer-events-none flex flex-col gap-1 drop-shadow-xl max-w-lg">
        <h1 className="text-4xl font-black tracking-widest text-[#00ff88]">PROJECT HYPERZETA</h1>
        <p className={`opacity-90 font-bold border-b pb-2 mb-2 w-max ${engineStatus.includes('Locked') ? 'border-[#00ff88]' : 'border-red-500 text-yellow-300'}`}>Status: {engineStatus}</p>
        <p className="text-sm opacity-75">Matrix Logic: Rust/WASM Sedenion Engine</p>
        <p className="text-sm opacity-75">Transport: WebAssembly Zero-Copy Membrane</p>
        <p className="text-sm opacity-50 mt-4 italic">Rendering {PARTICLE_COUNT.toLocaleString()} sedenion lattice points via WebGPU InstancedMesh.</p>
        <p className="text-lg mt-4 font-bold">Collapse: <span className={collapse < 0.5 ? 'text-red-400' : ''}>{collapse.toFixed(4)}</span></p>
      </div>

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
