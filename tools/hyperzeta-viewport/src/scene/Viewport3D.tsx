"use client";

import { Canvas } from "@react-three/fiber";
import { Stars } from "@react-three/drei";
import { Suspense } from "react";
import { RendererSelector } from "./renderers/RendererSelector";
import { AxisLabels } from "./AxisLabels";
import { CameraController } from "./CameraController";

/**
 * Viewport3D — the React Three Fiber canvas.
 * Uses RendererSelector to dispatch to the appropriate 3D renderer
 * based on the active visualization mode.
 *
 * 2D modes (chart, graph) render nothing in this canvas —
 * they go in the ChartOverlay HTML layer instead.
 * The Stars background provides subtle ambient life for 2D modes.
 */
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
        <RendererSelector />
      </Suspense>
    </Canvas>
  );
}
