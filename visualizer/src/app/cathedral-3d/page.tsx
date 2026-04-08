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

function Brick({
  position,
  size,
  color,
  label,
  emissive,
  onClick,
}: BrickProps) {
  const ref = useRef<THREE.Mesh>(null);
  const [hovered, setHovered] = useState(false);

  useFrame(() => {
    if (ref.current) {
      ref.current.scale.lerp(
        new THREE.Vector3(
          hovered ? 1.05 : 1,
          hovered ? 1.05 : 1,
          hovered ? 1.05 : 1
        ),
        0.1
      );
    }
  });

  return (
    <group position={position}>
      <RoundedBox
        ref={ref}
        args={size}
        radius={0.03}
        smoothness={4}
        onPointerOver={() => setHovered(true)}
        onPointerOut={() => setHovered(false)}
        onClick={onClick}
      >
        <meshStandardMaterial
          color={color}
          emissive={emissive || color}
          emissiveIntensity={hovered ? 0.5 : 0.1}
          roughness={0.4}
          metalness={0.3}
          transparent
          opacity={0.9}
        />
      </RoundedBox>
      {size[0] > 0.5 && (
        <Text
          position={[0, 0, size[2] / 2 + 0.01]}
          fontSize={0.06}
          color="white"
          anchorX="center"
          anchorY="middle"
          maxWidth={size[0] * 0.9}
        >
          {label}
        </Text>
      )}
    </group>
  );
}

function Pillar({
  position,
  label,
  color,
  axioms,
}: {
  position: [number, number, number];
  label: string;
  color: string;
  axioms: string[];
}) {
  return (
    <group position={position}>
      {/* Column */}
      <mesh position={[0, 1.5, 0]}>
        <cylinderGeometry args={[0.12, 0.18, 3, 16]} />
        <meshStandardMaterial
          color={color}
          emissive={color}
          emissiveIntensity={0.15}
          roughness={0.3}
          metalness={0.5}
          transparent
          opacity={0.85}
        />
      </mesh>
      {/* Capital */}
      <mesh position={[0, 3.1, 0]}>
        <boxGeometry args={[0.45, 0.12, 0.45]} />
        <meshStandardMaterial
          color={color}
          roughness={0.3}
          metalness={0.5}
        />
      </mesh>
      {/* Base */}
      <mesh position={[0, -0.05, 0]}>
        <boxGeometry args={[0.45, 0.1, 0.45]} />
        <meshStandardMaterial
          color={color}
          roughness={0.3}
          metalness={0.5}
        />
      </mesh>
      {/* Label */}
      <Text
        position={[0, 3.45, 0]}
        fontSize={0.1}
        color={color}
        anchorX="center"
        fontWeight="bold"
      >
        {label}
      </Text>
      {/* Axiom labels */}
      {axioms.map((axiom, i) => (
        <Text
          key={axiom}
          position={[0, -0.3 - i * 0.15, 0]}
          fontSize={0.045}
          color="#94a3b8"
          anchorX="center"
          maxWidth={1.2}
        >
          {axiom}
        </Text>
      ))}
    </group>
  );
}

function Foundation() {
  const blocks = useMemo(
    () => [
      {
        pos: [-1.5, -0.6, 0] as [number, number, number],
        label: "Mathlib",
      },
      {
        pos: [0, -0.6, 0] as [number, number, number],
        label: "Real Analysis",
      },
      {
        pos: [1.5, -0.6, 0] as [number, number, number],
        label: "Linear Algebra",
      },
      {
        pos: [-0.75, -0.6, 0.7] as [number, number, number],
        label: "Measure Theory",
      },
      {
        pos: [0.75, -0.6, 0.7] as [number, number, number],
        label: "Complex Analysis",
      },
    ],
    []
  );

  return (
    <group>
      {blocks.map((b, i) => (
        <Brick
          key={i}
          position={b.pos}
          size={[1.3, 0.2, 0.6]}
          color="#1e3a5f"
          label={b.label}
        />
      ))}
    </group>
  );
}

function CathedralStructure({
  onSelectBrick,
}: {
  onSelectBrick: (name: string) => void;
}) {
  const bricks = useMemo(
    () => [
      // Row 1: Core definitions
      {
        pos: [-1.2, 0.1, 0] as [number, number, number],
        label: "Defs",
        color: "#1e4d2e",
        size: [0.7, 0.18, 0.45] as [number, number, number],
      },
      {
        pos: [-0.4, 0.1, 0] as [number, number, number],
        label: "FractIntegral",
        color: "#1e4d2e",
        size: [0.7, 0.18, 0.45] as [number, number, number],
      },
      {
        pos: [0.4, 0.1, 0] as [number, number, number],
        label: "NbLinComb",
        color: "#1e4d2e",
        size: [0.7, 0.18, 0.45] as [number, number, number],
      },
      {
        pos: [1.2, 0.1, 0] as [number, number, number],
        label: "GramDiag",
        color: "#1e4d2e",
        size: [0.7, 0.18, 0.45] as [number, number, number],
      },
      // Row 2: Middle layer
      {
        pos: [-1, 0.45, 0] as [number, number, number],
        label: "OrthogonalWitness",
        color: "#2d5a1e",
        size: [0.8, 0.18, 0.45] as [number, number, number],
      },
      {
        pos: [0, 0.45, 0] as [number, number, number],
        label: "MellinBridge",
        color: "#2d5a1e",
        size: [0.8, 0.18, 0.45] as [number, number, number],
      },
      {
        pos: [1, 0.45, 0] as [number, number, number],
        label: "MertensWeightBypass",
        color: "#2d5a1e",
        size: [0.8, 0.18, 0.45] as [number, number, number],
      },
      // Row 3: Bridge / Robin
      {
        pos: [-0.8, 0.8, 0] as [number, number, number],
        label: "Separation",
        color: "#3a6b2e",
        size: [0.7, 0.18, 0.45] as [number, number, number],
      },
      {
        pos: [0.1, 0.8, 0] as [number, number, number],
        label: "MellinSieve",
        color: "#3a6b2e",
        size: [0.7, 0.18, 0.45] as [number, number, number],
      },
      {
        pos: [0.9, 0.8, 0] as [number, number, number],
        label: "Robin/",
        color: "#6b5a1e",
        size: [0.7, 0.18, 0.45] as [number, number, number],
      },
      // Row 4: Assembly
      {
        pos: [0, 1.2, 0] as [number, number, number],
        label: "Assembly",
        color: "#4a8b3e",
        size: [1.6, 0.2, 0.5] as [number, number, number],
      },
    ],
    []
  );

  return (
    <group>
      {bricks.map((b, i) => (
        <Brick
          key={i}
          position={b.pos}
          size={b.size}
          color={b.color}
          label={b.label}
          onClick={() => onSelectBrick(b.label)}
        />
      ))}
    </group>
  );
}

function Roof() {
  return (
    <group position={[0, 3.6, 0]}>
      {/* Triangular roof */}
      <mesh>
        <coneGeometry args={[2.2, 0.8, 4]} />
        <meshStandardMaterial
          color="#f59e0b"
          emissive="#f59e0b"
          emissiveIntensity={0.3}
          roughness={0.2}
          metalness={0.6}
          transparent
          opacity={0.7}
        />
      </mesh>
      <Float speed={1.5} floatIntensity={0.2}>
        <Text
          position={[0, 0.7, 0]}
          fontSize={0.15}
          color="#f59e0b"
          anchorX="center"
          fontWeight="bold"
        >
          riemann_hypothesis
        </Text>
      </Float>
    </group>
  );
}

function Particles() {
  const count = 120;
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
        <bufferAttribute
          attach="attributes-position"
          args={[positions, 3]}
        />
      </bufferGeometry>
      <pointsMaterial
        size={0.02}
        color="#f59e0b"
        transparent
        opacity={0.4}
      />
    </points>
  );
}

export default function Cathedral3DPage() {
  const [selected, setSelected] = useState<string | null>(null);

  const brickInfo: Record<string, string> = {
    Defs: "Core definitions: NB distance d²_N, Gram matrix G_N, fractional parts, RiemannHypothesis",
    FractIntegral:
      "Fractional part integrals: ∫₀¹{j/x}{k/x}dx computation, basis_entry_lower",
    NbLinComb:
      "Nyman-Beurling linear combination φ_w(x) = Σ wᵢ{(i+1)/x}, L²↔quadform bridge",
    GramDiag:
      "Gram matrix diagonal/off-diagonal bounds, aggregate excess structure",
    OrthogonalWitness:
      "Báez-Duarte Möbius witness h_ρ(x). Cauchy-Schwarz trap-breaker. 7 theorems PROVED.",
    MellinBridge:
      "Mellin transform infrastructure: Floor-Mellin identity, Hilbert space setup",
    MertensWeightBypass:
      "Mertens bound → Abel summation → weight construction. Pole-free theorem PROVED.",
    Separation:
      "Converse direction: ¬RH → defect δ > 0 via off-line zero separation",
    MellinSieve:
      "Forward direction: RH → phase_3_chain → d² ≤ C/log(N). PROVED from rh_weight_construction.",
    "Robin/":
      "Discrete arithmetic front: lagarias_for_primes PROVED!, Robin↔RH↔Lagarias equivalence, BaseCases, PrimeBounds",
    Assembly:
      "Final assembly: nyman_beurling_equivalence, eigenvalue_limit_exists, the Crown of the Cathedral",
  };

  return (
    <div className="h-full flex flex-col">
      <div className="p-6 border-b border-[#1e2148]">
        <h2 className="text-2xl font-bold text-slate-200">
          The Cathedral — 3D Architecture
        </h2>
        <p className="text-sm text-slate-500 mt-1">
          Three pillars hold the roof of RH: Converse (Báez-Duarte), Forward
          (Mertens), and Robin (Discrete).
        </p>
      </div>

      <div className="flex-1 flex">
        <div className="flex-1 relative">
          <Canvas
            camera={{ position: [4, 3, 4], fov: 50 }}
            gl={{ antialias: true }}
          >
            <color attach="background" args={["#060710"]} />
            <fog attach="fog" args={["#060710", 8, 18]} />
            <ambientLight intensity={0.3} />
            <directionalLight position={[5, 8, 3]} intensity={0.6} />
            <pointLight
              position={[-3, 4, -2]}
              intensity={0.3}
              color="#8b5cf6"
            />
            <pointLight
              position={[3, 2, 2]}
              intensity={0.2}
              color="#f59e0b"
            />
            <pointLight
              position={[0, 3, 3]}
              intensity={0.15}
              color="#3b82f6"
            />

            <Foundation />
            <Pillar
              position={[-1.5, 0, 0]}
              label="Converse"
              color="#8b5cf6"
              axioms={[
                "baezDuarte_is_L2",
                "baezDuarte_orthogonal",
                "baezDuarte_inner_one",
                "baezDuarte_inner_residual",
              ]}
            />
            <Pillar
              position={[0, 0, 0.4]}
              label="Forward"
              color="#3b82f6"
              axioms={[
                "mertens_bound_from_rh",
                "abel_summation_l2_bound",
                "rh_weight_construction",
              ]}
            />
            <Pillar
              position={[1.5, 0, 0]}
              label="Robin"
              color="#f59e0b"
              axioms={["robin_iff_rh", "lagarias_iff_rh"]}
            />
            <CathedralStructure onSelectBrick={setSelected} />
            <Roof />
            <Particles />
            <OrbitControls
              enableDamping
              dampingFactor={0.05}
              autoRotate
              autoRotateSpeed={0.3}
              minPolarAngle={Math.PI / 6}
              maxPolarAngle={Math.PI / 2.2}
            />
          </Canvas>

          <div className="absolute bottom-4 left-4 text-xs text-slate-500">
            Drag to orbit · Click bricks to inspect · Auto-rotates
          </div>
        </div>

        <div className="w-80 p-4 border-l border-[#1e2148] space-y-4 overflow-auto">
          <div className="p-4 rounded-xl bg-gradient-to-br from-amber-500/10 to-transparent border border-amber-500/20">
            <div className="text-xs font-mono text-amber-400 mb-2">
              STRUCTURE
            </div>
            <p className="text-sm text-slate-300">
              45 Lean modules form the bricks. Three pillars carry 9 critical
              axioms. RH is the roof.
            </p>
          </div>

          {selected && (
            <motion.div
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              className="p-4 rounded-xl bg-[#12142a] border border-emerald-500/30"
            >
              <div className="text-xs text-slate-500 mb-1">Selected</div>
              <div className="text-sm font-mono font-bold text-emerald-400">
                {selected}
              </div>
              <p className="text-xs text-slate-400 mt-2 leading-relaxed">
                {brickInfo[selected] || "Cathedral module"}
              </p>
            </motion.div>
          )}

          <div className="space-y-2">
            {[
              { color: "#f59e0b", label: "Roof: riemann_hypothesis" },
              {
                color: "#8b5cf6",
                label: "Pillar 1: Converse (Báez-Duarte)",
              },
              { color: "#3b82f6", label: "Pillar 2: Forward (Mertens)" },
              { color: "#f59e0b", label: "Pillar 3: Robin (Discrete)" },
              { color: "#4a8b3e", label: "Bricks: Proved theorems" },
              { color: "#1e3a5f", label: "Foundation: Mathlib" },
            ].map((item) => (
              <div key={item.label} className="flex items-center gap-2 text-xs">
                <div
                  className="w-3 h-3 rounded"
                  style={{ background: item.color }}
                />
                <span className="text-slate-400">{item.label}</span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
