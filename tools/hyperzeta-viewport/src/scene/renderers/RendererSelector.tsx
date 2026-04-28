"use client";

import { useViewportStore } from "../../stores/viewport";
import { VIZ_MAP } from "../../content/visualizations";
import { ParticleRenderer } from "./ParticleRenderer";

/**
 * RendererSelector — picks the appropriate 3D renderer based on
 * the active visualization mode's `renderer` field.
 *
 * Only 3D renderers go here (inside the R3F Canvas).
 * 2D renderers (chart, graph, dual-chart) render in the ChartOverlay
 * HTML layer above the canvas.
 */
export function RendererSelector() {
  const viewMode = useViewportStore((s) => s.viewMode);
  const viz = VIZ_MAP[viewMode];

  if (!viz) return null;

  const rendererType = viz.renderer ?? "particles";

  switch (rendererType) {
    case "particles":
      return <ParticleRenderer />;

    case "curves":
      // Phase 3: CurveRenderer (THREE.Line with glow)
      // For now, fall back to particles
      return <ParticleRenderer />;

    case "surface":
      // Phase 4: SurfaceRenderer (THREE.Mesh with displacement)
      // For now, fall back to particles
      return <ParticleRenderer />;

    case "dual-particles":
      // Phase 4: DualParticleRenderer
      // For now, fall back to single particle view
      return <ParticleRenderer />;

    // 2D renderers don't render in the 3D canvas — they go in ChartOverlay
    case "chart":
    case "graph":
    case "dual-chart":
      return null;

    default:
      return <ParticleRenderer />;
  }
}
