"use client";

import { useViewportStore } from "../../stores/viewport";
import { VIZ_MAP } from "../../content/visualizations";
import { ParticleRenderer } from "./ParticleRenderer";
import { CurveRenderer } from "./CurveRenderer";
import { SurfaceRenderer } from "./SurfaceRenderer";

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
      return <CurveRenderer />;

    case "surface":
      return <SurfaceRenderer />;

    case "dual-particles":
      // Phase 5: DualParticleRenderer
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
