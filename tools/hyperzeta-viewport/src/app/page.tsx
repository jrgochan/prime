"use client";

import { useHyperEngine } from "../engine/useHyperEngine";
import { Viewport3D } from "../scene/Viewport3D";
import { Header } from "../hud/Header";
import { ControlsPanel } from "../hud/ControlsPanel";
import { MetricsPanel } from "../hud/MetricsPanel";
import { PhaseTimeline } from "../hud/PhaseTimeline";
import { EquationOverlay } from "../hud/EquationOverlay";
import { CriticalStripMap } from "../hud/CriticalStripMap";
import { Toast, useSingularityDetector } from "../hud/Toast";
import { InfoSidebar } from "../sidebar/InfoSidebar";
import { PARTICLE_COUNT } from "../engine/types";

export default function Home() {
  // Boot WASM engine (handles lifecycle + cleanup)
  useHyperEngine();

  // Watch for singularity events
  useSingularityDetector();

  return (
    <main className="viewport-root">
      <Header />
      <PhaseTimeline />
      <ControlsPanel />
      <MetricsPanel />
      <EquationOverlay />
      <CriticalStripMap />
      <Toast />
      <InfoSidebar />

      <footer className="viewport-footer">
        <span>
          Matrix: Rust/WASM · Renderer: Three.js GLSL Points ·{" "}
          {PARTICLE_COUNT.toLocaleString()} particles
        </span>
        <span>The Cathedral Project</span>
      </footer>

      <Viewport3D />
    </main>
  );
}
