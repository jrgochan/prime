"use client";

import { useViewportStore } from "../stores/viewport";

const STATUS_TEXT = {
  booting: "Compiling Rust WASM Module…",
  allocating: "Allocating 16D Lattice RAM…",
  running: "Lattice Evolving — Live",
  collapsed: "✦ Spectral Singularity Detected",
} as const;

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

  if (!hudVisible) return null;

  const color = paused ? "#ffaa00" : STATUS_COLOR[engineState];
  const text = paused ? "⏸ Paused" : STATUS_TEXT[engineState];

  return (
    <header className="viewport-header">
      <div className="header-left">
        <h1 className="title">PROJECT HYPERZETA</h1>
        <div className="status-badge" style={{ borderColor: color }}>
          <span className="status-dot" style={{ backgroundColor: color }} />
          <span style={{ color }}>{text}</span>
        </div>
      </div>
      <div className="header-right">
        <button
          className="info-toggle"
          onClick={toggleInfo}
          title="Toggle educational info (I)"
        >
          {showInfo ? "✕" : "ℹ"}
        </button>
      </div>
    </header>
  );
}
