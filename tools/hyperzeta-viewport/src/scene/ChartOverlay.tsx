"use client";

import { useViewportStore } from "../stores/viewport";
import { VIZ_MAP } from "../content/visualizations";
import { ChartRenderer } from "./renderers/ChartRenderer";
import { GraphRenderer } from "./renderers/GraphRenderer";

/**
 * ChartOverlay — HTML layer positioned above the R3F Canvas.
 * Renders 2D visualization modes (charts, graphs, dual-charts)
 * that don't need THREE.js.
 *
 * When a 3D mode is active, this renders nothing.
 * When a 2D mode is active, the 3D canvas shows a subtle ambient
 * background (Stars) while this overlay displays the chart content.
 */
export function ChartOverlay() {
  const viewMode = useViewportStore((s) => s.viewMode);
  const viz = VIZ_MAP[viewMode];

  if (!viz) return null;

  const rendererType = viz.renderer ?? "particles";

  // Only render for 2D modes
  if (
    rendererType !== "chart" &&
    rendererType !== "graph" &&
    rendererType !== "dual-chart"
  ) {
    return null;
  }

  return (
    <div className="chart-overlay">
      <div className="chart-container">
        {rendererType === "chart" && <ChartRenderer />}
        {rendererType === "dual-chart" && <ChartRenderer />}
        {rendererType === "graph" && <GraphRenderer />}
      </div>
    </div>
  );
}
