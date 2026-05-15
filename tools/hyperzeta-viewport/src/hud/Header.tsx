"use client";

import { useViewportStore } from "../stores/viewport";
import { VIZ_MAP } from "../content/visualizations";

const STATUS_COLOR = {
  booting: "#ffaa00",
  allocating: "#ffaa00",
  running: "#00ff88",
  collapsed: "#ff6b9d",
} as const;

export function Header() {
  const engineState = useViewportStore((s) => s.engineState);
  const paused = useViewportStore((s) => s.paused);
  const hudVisible = useViewportStore((s) => s.hudVisible);
  const toggleInfo = useViewportStore((s) => s.toggleInfo);
  const showInfo = useViewportStore((s) => s.showInfo);
  const viewMode = useViewportStore((s) => s.viewMode);

  if (!hudVisible) return null;

  const color = paused ? "#ffaa00" : STATUS_COLOR[engineState];
  const viz = VIZ_MAP[viewMode];

  return (
    <header className="viewport-header">
      <div className="header-row">
        <span className="header-mark">HYPERZETA</span>
        <span className="header-sep">·</span>
        <span className="header-dot" style={{ backgroundColor: color }} />
        <span className="header-status" style={{ color }}>
          {paused ? "Paused" : engineState === "running" ? "Live" : "Booting…"}
        </span>
        <span className="header-sep">·</span>
        <span className="header-mode" style={{ color: viz.color.core }}>
          {viz.icon} {viz.shortLabel}
        </span>
      </div>
      <button
        className="info-toggle"
        onClick={toggleInfo}
        title="Toggle info sidebar (I)"
      >
        {showInfo ? "✕" : "ℹ"}
      </button>
    </header>
  );
}
