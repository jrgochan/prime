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
          fontSize={0.04}
          color="#94a3b8"
          anchorX="center"
          maxWidth={1.4}
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
      // Row 1: Foundations
      {
        pos: [-1.2, 0.1, 0] as [number, number, number],
        label: "Defs",
        color: "#1e4d2e",
        size: [0.7, 0.18, 0.45] as [number, number, number],
      },
      {
        pos: [-0.4, 0.1, 0] as [number, number, number],
        label: "Gram/",
        color: "#1e4d2e",
        size: [0.7, 0.18, 0.45] as [number, number, number],
      },
      {
        pos: [0.4, 0.1, 0] as [number, number, number],
        label: "LinearAlgebra/",
        color: "#1e4d2e",
        size: [0.7, 0.18, 0.45] as [number, number, number],
      },
      {
        pos: [1.2, 0.1, 0] as [number, number, number],
        label: "Vasyunin/",
        color: "#1e4d2e",
        size: [0.7, 0.18, 0.45] as [number, number, number],
      },
      // Row 2: Analytic machinery
      {
        pos: [-1, 0.45, 0] as [number, number, number],
        label: "Perron/",
        color: "#2d5a1e",
        size: [0.8, 0.18, 0.45] as [number, number, number],
      },
      {
        pos: [0, 0.45, 0] as [number, number, number],
        label: "Zeta/",
        color: "#2d5a1e",
        size: [0.8, 0.18, 0.45] as [number, number, number],
      },
      {
        pos: [1, 0.45, 0] as [number, number, number],
        label: "NymanBeurling/",
        color: "#2d5a1e",
        size: [0.8, 0.18, 0.45] as [number, number, number],
      },
      // Row 3: Bridge layers
      {
        pos: [-0.8, 0.8, 0] as [number, number, number],
        label: "Covariance/",
        color: "#3a6b2e",
        size: [0.7, 0.18, 0.45] as [number, number, number],
      },
      {
        pos: [0.1, 0.8, 0] as [number, number, number],
        label: "PNT/",
        color: "#3a6b2e",
        size: [0.7, 0.18, 0.45] as [number, number, number],
      },
      {
        pos: [0.9, 0.8, 0] as [number, number, number],
        label: "AbelTail/",
        color: "#3a6b2e",
        size: [0.7, 0.18, 0.45] as [number, number, number],
      },
      // Row 4: Assembly (capstone)
      {
        pos: [0, 1.2, 0] as [number, number, number],
        label: "Assembly/",
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
          nyman_beurling_equivalence
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
    "Defs":
      "Core definitions: NB distance d\u00B2_N, Gram matrix G_N, bdBasis {1/(kx)}, RiemannHypothesis. The foundation of everything.",
    "Gram/":
      "FractIntegral (diagonal G(k,k) PROVED), Diagonal, OffDiagonal, L2Bridge. 6 files, Gram matrix infrastructure.",
    "LinearAlgebra/":
      "Sherman-Morrison inverse, Sylvester criterion, Variational bounds. 4 files of abstract linear algebra.",
    "Vasyunin/":
      "The largest module (39 files). Cotangent formula, Matrix entries, Proof chain, Augmented witnesses. Contains the off-diagonal convergence axiom.",
    "Perron/":
      "16-file Perron contour formula chain. RH \u2192 |M(x)| = O(x^{\u00BD+\u03B5}). The analytic heart of the forward direction.",
    "Zeta/":
      "8 files: Hadamard product, convexity bounds, Dirichlet series, disk bounds. Contains crown axiom: rh_zeta_lower_bound_from_zero_counting.",
    "NymanBeurling/":
      "The converse direction. BDMellin (Rank-1 Mellin Miracle, PURE MATHLIB), ThetaBound, Separation. Zero axioms.",
    "Covariance/":
      "Gram form bounds, dot product identity, L\u00B2 convergence, Millennium Wall. 8 files. Off-crown since v11 Mellin Crown.",
    "PNT/":
      "Prime Number Theorem bridges. Abel mean, PNTAnd library bridge. Off-crown since v11 Mellin Crown. 3 files.",
    "AbelTail/":
      "Abel summation engine: S\u2081/S\u2082/S\u2083 decay, telescoping, tail assembly. 14 files. All PROVED.",
    "Assembly/":
      "6 capstone files only. MainChain (THE theorem), PerronCrown, OneCrown, DirectL2Crown, CertifiedComputation.",
  };

  return (
    <div className="h-full flex flex-col">
      <div className="p-6 border-b border-[#1e2148]">
        <h2 className="text-2xl font-bold text-slate-200">
          The Cathedral &mdash; 3D Architecture
        </h2>
        <p className="text-sm text-slate-500 mt-1">
          One pillar holds the golden roof: the Converse (pure Mathlib, 0 axioms)
          is free; the Forward uses 1 crown axiom (baez_duarte_forward). 308 files, 78,435 lines.
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
              color="#10b981"
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
              color="#10b981"
              axioms={[
                "0 custom axioms",
                "Rank-1 Mellin Miracle",
                "Cauchy-Schwarz separation",
                "PURE MATHLIB",
              ]}
            />
            <Pillar
              position={[1.5, 0, 0]}
              label="Forward"
              color="#f59e0b"
              axioms={[
                "baez_duarte_forward",
                "(sole crown axiom)",
              ]}
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
            Drag to orbit &middot; Click bricks to inspect &middot; Auto-rotates
          </div>
        </div>

        <div className="w-80 p-4 border-l border-[#1e2148] space-y-4 overflow-auto">
          <div className="p-4 rounded-xl bg-gradient-to-br from-amber-500/10 to-transparent border border-amber-500/20">
            <div className="text-xs font-mono text-amber-400 mb-2">
              STRUCTURE (v16 Observatory)
            </div>
            <p className="text-sm text-slate-300">
              308 Lean files. One-Pillar architecture: baez_duarte_forward
              is the sole crown axiom. 1 axiom on the critical path.
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
              { color: "#f59e0b", label: "Roof: nyman_beurling_equivalence" },
              {
                color: "#10b981",
                label: "Pillar 1: Converse (0 axioms)",
              },
              { color: "#f59e0b", label: "Pillar 2: Forward (1 axiom)" },
              { color: "#4a8b3e", label: "Bricks: Topic directories" },
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
