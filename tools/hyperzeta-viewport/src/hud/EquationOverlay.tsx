"use client";

import { useViewportStore } from "../stores/viewport";
import { VIZ_MAP } from "../content/visualizations";

export function EquationOverlay() {
  const viewMode = useViewportStore((s) => s.viewMode);
  const lambda = useViewportStore((s) => s.lambda);
  const hudVisible = useViewportStore((s) => s.hudVisible);
  const height = (10 + lambda * 2).toFixed(1);

  if (!hudVisible) return null;

  const viz = VIZ_MAP[viewMode];

  return (
    <div className="equation-overlay">
      <div className="equation-main">{viz.equation.main}</div>
      <div className="equation-params">
        {viz.equation.sub} · Im(s) ≈ {height}
      </div>
    </div>
  );
}
