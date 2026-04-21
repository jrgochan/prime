"use client";

import { Canvas } from "@react-three/fiber";
import { Stars } from "@react-three/drei";
import { Suspense } from "react";
import { LatticeCloud } from "./LatticeCloud";
import { AxisLabels } from "./AxisLabels";
import { CameraController } from "./CameraController";

export function Viewport3D() {
  return (
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
      <CameraController />
      <AxisLabels />
      <Suspense fallback={null}>
        <LatticeCloud />
      </Suspense>
    </Canvas>
  );
}
