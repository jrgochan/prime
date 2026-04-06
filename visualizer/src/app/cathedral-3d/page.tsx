"use client";
import { useRef, useState, useMemo } from "react";
import { Canvas, useFrame } from "@react-three/fiber";
import { OrbitControls, Text, Float, RoundedBox } from "@react-three/drei";
import { motion } from "framer-motion";
import * as THREE from "three";

interface BrickProps {
  position: [number, number, number];
  size: [number, number, number];
  color: string;
  label: string;
  emissive?: string;
  onClick?: () => void;
}

function Brick({ position, size, color, label, emissive, onClick }: BrickProps) {
  const ref = useRef<THREE.Mesh>(null);
  const [hovered, setHovered] = useState(false);

  useFrame(() => {
    if (ref.current) {
      ref.current.scale.lerp(
        new THREE.Vector3(hovered ? 1.05 : 1, hovered ? 1.05 : 1, hovered ? 1.05 : 1),
        0.1
      );
    }
  });

  return (
    <group position={position}>
      <RoundedBox ref={ref} args={size} radius={0.03} smoothness={4}
        onPointerOver={() => setHovered(true)} onPointerOut={() => setHovered(false)}
        onClick={onClick}>
        <meshStandardMaterial color={color} emissive={emissive || color}
          emissiveIntensity={hovered ? 0.5 : 0.1} roughness={0.4} metalness={0.3}
          transparent opacity={0.9} />
      </RoundedBox>
      {size[0] > 0.5 && (
        <Text position={[0, 0, size[2] / 2 + 0.01]} fontSize={0.07} color="white"
          anchorX="center" anchorY="middle" maxWidth={size[0] * 0.9}>
          {label}
        </Text>
      )}
    </group>
  );
}

function Pillar({ position, label, color, axiom }: {
  position: [number, number, number]; label: string; color: string; axiom: string;
}) {
  return (
    <group position={position}>
      {/* Column */}
      <mesh position={[0, 1.5, 0]}>
        <cylinderGeometry args={[0.15, 0.2, 3, 16]} />
        <meshStandardMaterial color={color} emissive={color} emissiveIntensity={0.15}
          roughness={0.3} metalness={0.5} transparent opacity={0.85} />
      </mesh>
      {/* Capital */}
      <mesh position={[0, 3.1, 0]}>
        <boxGeometry args={[0.5, 0.15, 0.5]} />
        <meshStandardMaterial color={color} roughness={0.3} metalness={0.5} />
      </mesh>
      {/* Base */}
      <mesh position={[0, -0.05, 0]}>
        <boxGeometry args={[0.5, 0.1, 0.5]} />
        <meshStandardMaterial color={color} roughness={0.3} metalness={0.5} />
      </mesh>
      {/* Label */}
      <Text position={[0, 3.5, 0]} fontSize={0.12} color={color} anchorX="center">
        {label}
      </Text>
      <Text position={[0, -0.3, 0]} fontSize={0.06} color="#94a3b8" anchorX="center" maxWidth={1}>
        {axiom}
      </Text>
    </group>
  );
}

function Foundation() {
  const blocks = useMemo(() => [
    { pos: [-1.5, -0.6, 0] as [number, number, number], label: "Mathlib" },
    { pos: [0, -0.6, 0] as [number, number, number], label: "Real Analysis" },
    { pos: [1.5, -0.6, 0] as [number, number, number], label: "Linear Algebra" },
    { pos: [-0.75, -0.6, 0.7] as [number, number, number], label: "Measure Theory" },
    { pos: [0.75, -0.6, 0.7] as [number, number, number], label: "Complex Analysis" },
  ], []);

  return (
    <group>
      {blocks.map((b, i) => (
        <Brick key={i} position={b.pos} size={[1.3, 0.2, 0.6]} color="#1e3a5f" label={b.label} />
      ))}
    </group>
  );
}

function CathedralStructure({ onSelectBrick }: { onSelectBrick: (name: string) => void }) {
  const bricks = useMemo(() => [
    // Row 1: Core definitions
    { pos: [-1, 0.1, 0] as [number, number, number], label: "Defs", color: "#1e4d2e", size: [0.8, 0.2, 0.5] as [number, number, number] },
    { pos: [0, 0.1, 0] as [number, number, number], label: "GramBounds", color: "#1e4d2e", size: [0.8, 0.2, 0.5] as [number, number, number] },
    { pos: [1, 0.1, 0] as [number, number, number], label: "FractIntegral", color: "#1e4d2e", size: [0.8, 0.2, 0.5] as [number, number, number] },
    // Row 2: Middle layer
    { pos: [-0.8, 0.5, 0] as [number, number, number], label: "Structural", color: "#2d5a1e", size: [0.7, 0.2, 0.5] as [number, number, number] },
    { pos: [0.2, 0.5, 0] as [number, number, number], label: "ParitySchur", color: "#2d5a1e", size: [0.7, 0.2, 0.5] as [number, number, number] },
    { pos: [1.1, 0.5, 0] as [number, number, number], label: "BilinearSieve", color: "#2d5a1e", size: [0.7, 0.2, 0.5] as [number, number, number] },
    // Row 3: Bridge layer
    { pos: [-0.5, 0.9, 0] as [number, number, number], label: "MellinBridge", color: "#3a6b2e", size: [0.8, 0.2, 0.5] as [number, number, number] },
    { pos: [0.6, 0.9, 0] as [number, number, number], label: "Quantitative", color: "#3a6b2e", size: [0.8, 0.2, 0.5] as [number, number, number] },
    // Row 4: Assembly
    { pos: [0, 1.3, 0] as [number, number, number], label: "Assembly", color: "#4a8b3e", size: [1.2, 0.2, 0.5] as [number, number, number] },
  ], []);

  return (
    <group>
      {bricks.map((b, i) => (
        <Brick key={i} position={b.pos} size={b.size} color={b.color} label={b.label}
          onClick={() => onSelectBrick(b.label)} />
      ))}
    </group>
  );
}

function Roof() {
  return (
    <group position={[0, 3.6, 0]}>
      {/* Triangular roof */}
      <mesh>
        <coneGeometry args={[2, 0.8, 4]} />
        <meshStandardMaterial color="#f59e0b" emissive="#f59e0b" emissiveIntensity={0.3}
          roughness={0.2} metalness={0.6} transparent opacity={0.7} />
      </mesh>
      <Float speed={1.5} floatIntensity={0.2}>
        <Text position={[0, 0.7, 0]} fontSize={0.15} color="#f59e0b" anchorX="center"
          fontWeight="bold">
          riemann_hypothesis
        </Text>
      </Float>
    </group>
  );
}

function Particles() {
  const count = 100;
  const ref = useRef<THREE.Points>(null);

  const positions = useMemo(() => {
    const pos = new Float32Array(count * 3);
    for (let i = 0; i < count; i++) {
      pos[i * 3] = (Math.random() - 0.5) * 8;
      pos[i * 3 + 1] = Math.random() * 6;
      pos[i * 3 + 2] = (Math.random() - 0.5) * 8;
    }
    return pos;
  }, []);

  useFrame((state) => {
    if (ref.current) {
      ref.current.rotation.y = state.clock.elapsedTime * 0.02;
    }
  });

  return (
    <points ref={ref}>
      <bufferGeometry>
        <bufferAttribute attach="attributes-position" args={[positions, 3]} />
      </bufferGeometry>
      <pointsMaterial size={0.02} color="#f59e0b" transparent opacity={0.4} />
    </points>
  );
}

export default function Cathedral3DPage() {
  const [selected, setSelected] = useState<string | null>(null);

  const brickInfo: Record<string, string> = {
    Defs: "Core definitions: NB distance, Gram matrix, fractional parts, functional equation",
    GramBounds: "Gram matrix diagonal/off-diagonal bounds, aggregate excess axiom",
    FractIntegral: "Fractional part integrals: ∫₀¹{j/x}{k/x}dx computation",
    Structural: "Proof chain: positive-definiteness, distance bounds, Schur complements",
    ParitySchur: "Parity decomposition theorem, Schur complement lower bound",
    BilinearSieve: "Bilinear sieve machinery, stable ratio, type II bounds",
    MellinBridge: "Mellin transform infrastructure, Hilbert space setup, L² norms",
    Quantitative: "Quantitative estimates, eigenvalue bridge, distance scaling",
    Assembly: "Final assembly: riemann_hypothesis from all components",
  };

  return (
    <div className="h-full flex flex-col">
      <div className="p-6 border-b border-[#1e2148]">
        <h2 className="text-2xl font-bold text-slate-200">The Cathedral — 3D Architecture</h2>
        <p className="text-sm text-slate-500 mt-1">
          The proof structure rendered as a cathedral. Two pillars hold the roof of RH.
        </p>
      </div>

      <div className="flex-1 flex">
        <div className="flex-1 relative">
          <Canvas camera={{ position: [4, 3, 4], fov: 50 }} gl={{ antialias: true }}>
            <color attach="background" args={["#060710"]} />
            <fog attach="fog" args={["#060710", 8, 18]} />
            <ambientLight intensity={0.3} />
            <directionalLight position={[5, 8, 3]} intensity={0.6} />
            <pointLight position={[-3, 4, -2]} intensity={0.3} color="#3b82f6" />
            <pointLight position={[3, 2, 2]} intensity={0.2} color="#f59e0b" />

            <Foundation />
            <Pillar position={[-1.2, 0, 0]} label="Physics Pillar" color="#ef4444" axiom="offdiag_excess_sum_le" />
            <Pillar position={[1.2, 0, 0]} label="Spectral Pillar" color="#3b82f6" axiom="zeta_zero_separates" />
            <CathedralStructure onSelectBrick={setSelected} />
            <Roof />
            <Particles />
            <OrbitControls enableDamping dampingFactor={0.05} autoRotate autoRotateSpeed={0.3}
              minPolarAngle={Math.PI / 6} maxPolarAngle={Math.PI / 2.2} />
          </Canvas>

          <div className="absolute bottom-4 left-4 text-xs text-slate-500">
            Drag to orbit · Click bricks to inspect · Auto-rotates
          </div>
        </div>

        <div className="w-72 p-4 border-l border-[#1e2148] space-y-4 overflow-auto">
          <div className="p-4 rounded-xl bg-gradient-to-br from-amber-500/10 to-transparent border border-amber-500/20">
            <div className="text-xs font-mono text-amber-400 mb-2">STRUCTURE</div>
            <p className="text-sm text-slate-300">
              44 Lean modules form the bricks. Two axioms are the pillars. RH is the roof.
            </p>
          </div>

          {selected && (
            <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }}
              className="p-4 rounded-xl bg-[#12142a] border border-emerald-500/30"
            >
              <div className="text-xs text-slate-500 mb-1">Selected</div>
              <div className="text-sm font-mono font-bold text-emerald-400">{selected}</div>
              <p className="text-xs text-slate-400 mt-2">{brickInfo[selected] || "Cathedral module"}</p>
            </motion.div>
          )}

          <div className="space-y-2">
            {[
              { color: "#f59e0b", label: "Roof: riemann_hypothesis" },
              { color: "#ef4444", label: "Pillar 1: Physics (offdiag)" },
              { color: "#3b82f6", label: "Pillar 2: Spectral (zeta)" },
              { color: "#4a8b3e", label: "Bricks: Proved theorems" },
              { color: "#1e3a5f", label: "Foundation: Mathlib" },
            ].map((item) => (
              <div key={item.label} className="flex items-center gap-2 text-xs">
                <div className="w-3 h-3 rounded" style={{ background: item.color }} />
                <span className="text-slate-400">{item.label}</span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
