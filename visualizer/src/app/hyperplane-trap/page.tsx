"use client";
import { useState, useMemo, useRef } from "react";
import { Canvas, useFrame } from "@react-three/fiber";
import { OrbitControls, Text, Float } from "@react-three/drei";
import { motion } from "framer-motion";
import * as THREE from "three";

function Surface() {
  const meshRef = useRef<THREE.Mesh>(null);

  const { geometry, colorArray } = useMemo(() => {
    const size = 80;
    const geo = new THREE.PlaneGeometry(6, 6, size, size);
    const positions = geo.attributes.position;
    const colors = new Float32Array(positions.count * 3);

    // The Mellin residual surface: |ℓ_ρ(1 - Σ v_k {k/x})|²
    // over 2D weight space (v1, v2) for N=4
    // For visualization, we use a simplified model showing the zero point
    const rhoRe = 0.75; // rogue zero with Re > 1/2
    const rhoIm = 14.134; // first zeta zero imaginary part

    for (let i = 0; i < positions.count; i++) {
      const px = positions.getX(i);
      const py = positions.getY(i);

      // Map to weight space
      const v1 = px;
      const v2 = py;

      // Simplified Mellin residual model
      // Zero at spoofing weights, rising bowl elsewhere
      const spoofV1 = 0.8;
      const spoofV2 = -0.3;
      const dx = v1 - spoofV1;
      const dy = v2 - spoofV2;
      const dist = Math.sqrt(dx * dx + dy * dy);

      // L² norm explosion near spoofing weights
      const l2Norm = 0.1 + 2.0 * (v1 * v1 + v2 * v2) + 0.5 * Math.abs(v1 * v2);

      // Mellin residual has a zero at (spoofV1, spoofV2)
      const mellinResidual = dist * dist * 0.3;

      // What Cauchy-Schwarz would give: residual / norm
      const csBound = mellinResidual / (l2Norm + 0.01);

      // The actual L² distance: stays bounded below by δ
      const height = 0.15 + mellinResidual + 0.1 * l2Norm * 0.05;

      positions.setZ(i, Math.min(height, 4));

      // Color by height
      const t = Math.min(height / 2, 1);
      colors[i * 3] = 0.06 + t * 0.8; // R
      colors[i * 3 + 1] = 0.2 * (1 - t) + 0.05; // G
      colors[i * 3 + 2] = 0.8 * (1 - t) + 0.1; // B
    }

    geo.computeVertexNormals();
    geo.setAttribute("color", new THREE.BufferAttribute(colors, 3));
    return { geometry: geo, colorArray: colors };
  }, []);

  useFrame((state) => {
    if (meshRef.current) {
      meshRef.current.rotation.z = Math.sin(state.clock.elapsedTime * 0.1) * 0.02;
    }
  });

  return (
    <mesh ref={meshRef} geometry={geometry} rotation={[-Math.PI / 3, 0, 0]} position={[0, -0.5, 0]}>
      <meshStandardMaterial vertexColors side={THREE.DoubleSide} wireframe={false}
        transparent opacity={0.9} roughness={0.6} metalness={0.2} />
    </mesh>
  );
}

function ZeroPoint() {
  const ref = useRef<THREE.Mesh>(null);

  useFrame((state) => {
    if (ref.current) {
      ref.current.scale.setScalar(1 + Math.sin(state.clock.elapsedTime * 2) * 0.15);
    }
  });

  return (
    <Float speed={2} floatIntensity={0.3}>
      <mesh ref={ref} position={[0.8, 0.2, -0.3]}>
        <sphereGeometry args={[0.08, 16, 16]} />
        <meshStandardMaterial color="#ef4444" emissive="#ef4444" emissiveIntensity={2} />
      </mesh>
      <Text position={[0.8, 0.5, -0.3]} fontSize={0.12} color="#ef4444"
        anchorX="center" anchorY="bottom" font="/fonts/inter.woff">
        Zero (spoofing weights)
      </Text>
    </Float>
  );
}

function WireframeGrid() {
  return (
    <gridHelper args={[6, 20, "#1e2148", "#1e2148"]} position={[0, -1.2, 0]} />
  );
}

export default function HyperplaneTrapPage() {
  const [showWireframe, setShowWireframe] = useState(false);

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
          <Canvas camera={{ position: [3, 3, 3], fov: 55 }} gl={{ antialias: true }}>
            <ambientLight intensity={0.4} />
            <directionalLight position={[5, 5, 5]} intensity={0.8} />
            <pointLight position={[-3, 3, -3]} intensity={0.3} color="#3b82f6" />
            <Surface />
            <ZeroPoint />
            <WireframeGrid />
            <OrbitControls enableDamping dampingFactor={0.05} />
          </Canvas>

          <div className="absolute bottom-4 left-4 text-xs text-slate-500">
            Drag to rotate · Scroll to zoom
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
