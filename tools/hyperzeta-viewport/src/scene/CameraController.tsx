"use client";

import { useEffect, useRef } from "react";
import { useThree } from "@react-three/fiber";
import { OrbitControls } from "@react-three/drei";
import { useViewportStore } from "../stores/viewport";
import type { CameraPreset } from "../engine/types";

const PRESETS: Record<CameraPreset, { pos: [number, number, number] }> = {
  orbital: { pos: [0, 0, 20] },
  "zero-focus": { pos: [5, 5, 8] },
  side: { pos: [25, 0, 0] },
};

export function CameraController() {
  const controlsRef = useRef<any>(null);
  const { camera } = useThree();
  const cameraPreset = useViewportStore((s) => s.cameraPreset);

  useEffect(() => {
    if (!controlsRef.current) return;
    const { pos } = PRESETS[cameraPreset];
    camera.position.set(...pos);
    controlsRef.current.target.set(0, 0, 0);
    controlsRef.current.update();
  }, [cameraPreset, camera]);

  return (
    <OrbitControls
      ref={controlsRef}
      autoRotate={cameraPreset === "orbital"}
      autoRotateSpeed={1.2}
      enableDamping
      dampingFactor={0.05}
      minDistance={5}
      maxDistance={80}
    />
  );
}
