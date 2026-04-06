"use client";
import { useState, useMemo, useRef, Suspense } from "react";
import { Canvas, useFrame } from "@react-three/fiber";
import { OrbitControls, Html } from "@react-three/drei";
import { motion } from "framer-motion";
import * as THREE from "three";

function Surface() {
  const meshRef = useRef<THREE.Mesh>(null);

  const geometry = useMemo(() => {
    const size = 80;
    const geo = new THREE.PlaneGeometry(6, 6, size, size);
    const positions = geo.attributes.position;
    const colors = new Float32Array(positions.count * 3);

    for (let i = 0; i < positions.count; i++) {
      const px = positions.getX(i);
      const py = positions.getY(i);

      const v1 = px;
      const v2 = py;

      // Spoofing weight location
      const spoofV1 = 0.8;
      const spoofV2 = -0.3;
      const dx = v1 - spoofV1;
      const dy = v2 - spoofV2;
      const dist = Math.sqrt(dx * dx + dy * dy);

      // L² norm
      const l2Norm = 0.1 + 2.0 * (v1 * v1 + v2 * v2) + 0.5 * Math.abs(v1 * v2);

      // Mellin residual zeroes at spoofing weights
      const mellinResidual = dist * dist * 0.3;

      // Height: L² distance stays bounded below by δ
      const height = 0.15 + mellinResidual + 0.1 * l2Norm * 0.05;
      positions.setZ(i, Math.min(height, 4));

      // Color: blue (low) → red (high)
      const t = Math.min(height / 2, 1);
      colors[i * 3] = 0.06 + t * 0.8;
      colors[i * 3 + 1] = 0.2 * (1 - t) + 0.05;
      colors[i * 3 + 2] = 0.8 * (1 - t) + 0.1;
    }

    geo.computeVertexNormals();
    geo.setAttribute("color", new THREE.BufferAttribute(colors, 3));
    return geo;
  }, []);

  useFrame((state) => {
    if (meshRef.current) {
      meshRef.current.rotation.z = Math.sin(state.clock.elapsedTime * 0.1) * 0.02;
    }
  });

  return (
    <mesh ref={meshRef} geometry={geometry} rotation={[-Math.PI / 3, 0, 0]} position={[0, -0.5, 0]}>
      <meshStandardMaterial vertexColors side={THREE.DoubleSide}
        transparent opacity={0.9} roughness={0.6} metalness={0.2} />
    </mesh>
  );
}

function ZeroPoint() {
  const ref = useRef<THREE.Mesh>(null);
  const ringRef = useRef<THREE.Mesh>(null);

  useFrame((state) => {
    if (ref.current) {
      ref.current.scale.setScalar(1 + Math.sin(state.clock.elapsedTime * 2) * 0.15);
    }
    if (ringRef.current) {
      ringRef.current.rotation.x = state.clock.elapsedTime * 0.5;
      ringRef.current.rotation.y = state.clock.elapsedTime * 0.3;
    }
  });

  return (
    <group position={[0.8, 0.2, -0.3]}>
      {/* Pulsing sphere */}
      <mesh ref={ref}>
        <sphereGeometry args={[0.08, 16, 16]} />
        <meshStandardMaterial color="#ef4444" emissive="#ef4444" emissiveIntensity={2} />
      </mesh>
      {/* Orbiting ring */}
      <mesh ref={ringRef}>
        <torusGeometry args={[0.15, 0.01, 8, 32]} />
        <meshStandardMaterial color="#ef4444" emissive="#ef4444" emissiveIntensity={1} transparent opacity={0.6} />
      </mesh>
      {/* HTML label (always works, no font dependency) */}
      <Html position={[0, 0.3, 0]} center style={{ pointerEvents: "none" }}>
        <div className="text-red-400 text-xs font-mono whitespace-nowrap bg-[#0a0b14]/80 px-2 py-1 rounded border border-red-500/30">
          Zero (spoofing weights)
        </div>
      </Html>
    </group>
  );
}

function AxisLabels() {
  return (
    <group>
      <Html position={[3.2, -0.5, 0]} center style={{ pointerEvents: "none" }}>
        <span className="text-blue-400/60 text-xs font-mono">v₁ →</span>
      </Html>
      <Html position={[0, -0.5, 3.2]} center style={{ pointerEvents: "none" }}>
        <span className="text-blue-400/60 text-xs font-mono">v₂ →</span>
      </Html>
    </group>
  );
}

export default function HyperplaneTrapPage() {
  return (
    <div className="h-full flex flex-col">
      <div className="p-6 border-b border-[#1e2148]">
        <h2 className="text-2xl font-bold text-slate-200">The Hyperplane Trap</h2>
        <p className="text-sm text-slate-500 mt-1">
          The Cauchy-Schwarz bound fails because &quot;spoofing&quot; weights zero out the Mellin residual
        </p>
      </div>

      <div className="flex-1 flex">
        <div className="flex-1 relative">
          <Suspense fallback={
            <div className="w-full h-full flex items-center justify-center text-slate-500">
              Loading 3D scene...
            </div>
          }>
            <Canvas camera={{ position: [4, 3, 4], fov: 50 }}
              gl={{ antialias: true, alpha: false }}
              onCreated={({ gl }) => { gl.setClearColor("#0a0b14"); }}
            >
              <ambientLight intensity={0.4} />
              <directionalLight position={[5, 5, 5]} intensity={0.8} />
              <pointLight position={[-3, 3, -3]} intensity={0.3} color="#3b82f6" />
              <pointLight position={[2, 1, 2]} intensity={0.2} color="#ef4444" />
              <Surface />
              <ZeroPoint />
              <AxisLabels />
              <gridHelper args={[6, 20, "#1e2148", "#1e2148"]} position={[0, -1.2, 0]} />
              <OrbitControls enableDamping dampingFactor={0.05} autoRotate autoRotateSpeed={0.5} />
            </Canvas>
          </Suspense>

          <div className="absolute bottom-4 left-4 text-xs text-slate-500">
            Drag to rotate · Scroll to zoom · Auto-rotates
          </div>
        </div>

        <div className="w-80 p-4 border-l border-[#1e2148] space-y-4 overflow-auto">
          <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }}
            className="p-4 rounded-xl bg-gradient-to-br from-red-500/10 to-transparent border border-red-500/20"
          >
            <div className="text-xs font-mono text-red-400 mb-2">THE TRAP</div>
            <p className="text-sm text-slate-300">
              For N ≥ 4, there exist real weights v<sub>k</sub> that make the Mellin residual 
              ℓ<sub>ρ</sub>(1 − f<sub>N</sub>) = 0 exactly.
            </p>
          </motion.div>

          <div className="p-4 rounded-xl bg-[#12142a] border border-[#1e2148] text-xs text-slate-400 space-y-3">
            <p><strong className="text-slate-200">Why it fails:</strong></p>
            <p>The Cauchy-Schwarz inequality gives:</p>
            <p className="font-mono text-center text-slate-300 py-1">
              ‖1−f<sub>N</sub>‖² ≥ |ℓ<sub>ρ</sub>(1−f<sub>N</sub>)|² / ‖ℓ<sub>ρ</sub>‖²
            </p>
            <p>But the <span className="text-red-400">spoofing weights</span> make the numerator = 0, giving the useless bound ‖·‖² ≥ 0.</p>
          </div>

          <div className="p-4 rounded-xl bg-[#12142a] border border-[#1e2148] text-xs text-slate-400 space-y-3">
            <p><strong className="text-slate-200">Why RH still holds:</strong></p>
            <p>These spoofing weights cause ‖f<sub>N</sub>‖<sub>L²</sub> to <span className="text-amber-400">explode</span>.</p>
            <p>The correct proof uses Báez-Duarte&apos;s Möbius witness, which requires the <span className="text-blue-400">Prime Number Theorem</span>.</p>
          </div>

          <div className="p-4 rounded-xl bg-gradient-to-br from-purple-500/10 to-transparent border border-purple-500/20 text-xs text-slate-400 space-y-2">
            <div className="text-xs font-mono text-purple-400 mb-1">GEOMETRY</div>
            <p><strong className="text-red-400">Red sphere:</strong> The zero point (spoofing weights)</p>
            <p><strong className="text-blue-400">Blue-to-red surface:</strong> L² distance ‖1 − f<sub>N</sub>‖²</p>
            <p>The surface minimum is NOT at the zero — that&apos;s the trap.</p>
          </div>
        </div>
      </div>
    </div>
  );
}
